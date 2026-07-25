//! Backend nativo `--dev` (§11/§18): o «Fast-Path Backend» sobre Cranelift.
//!
//! Emite código nativo a partir do **Axión Core IR** (ver `core.rs`), não do AST:
//! o Core já está em ANF (cada subexpressão nomeada), com o desugar de
//! multi-cláusula, o *lifting* de `where` e a conversão de closures resolvidos,
//! pelo que este ficheiro é um mero emissor Core→Cranelift. JIT-compila via
//! `cranelift-jit`. Todos os valores são `i64` (Int, ponteiros, tokens de IO).
//! Strings/IO e alocação (registos, tuplos, closures) via um runtime mínimo
//! (`axion_puts`/`axion_show_int`/`axion_alloc`). O mesmo Core servirá o backend
//! LLVM `--release` (incremento seguinte).

use crate::ast;
use crate::core::{self, is_int, result_type, Atom, CPat, CoreFn, Op, Rhs, Term};
use cranelift::codegen::ir::UserFuncName;
use cranelift::codegen::Context;
use cranelift::prelude::{
    types, AbiParam, Configurable, EntityRef, FunctionBuilder, FunctionBuilderContext, InstBuilder,
    IntCC, MemFlags, Value, Variable,
};
use cranelift_jit::{JITBuilder, JITModule};
use cranelift_module::{DataDescription, DataId, FuncId, Linkage, Module};
use std::collections::HashMap;

// --- runtime nativo mínimo (registado como símbolos no JIT) ---

/// `putStrLn`: imprime uma C-string com nova-linha.
extern "C" fn axion_puts(ptr: *const u8) {
    let s = unsafe { std::ffi::CStr::from_ptr(ptr as *const std::ffi::c_char) };
    println!("{}", s.to_string_lossy());
}

/// `show :: Int -> String`: formata um inteiro e devolve uma C-string (leaked;
/// vive até ao fim do processo — aceitável para um único `run`).
extern "C" fn axion_show_int(n: i64) -> *const u8 {
    let s = std::ffi::CString::new(n.to_string()).unwrap();
    s.into_raw() as *const u8
}

// Contadores de heap (§13): quantas alocações e libertações ocorreram. Com
// `AXION_HEAP_STATS=1` o `run` imprime-os no fim — evidência de que o Auto-Drop
// reclama de facto (não é só análise estática).
static HEAP_ALLOCS: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(0);
static HEAP_FREES: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(0);

/// Aloca `size` bytes de *payload* na heap. Prefixa um cabeçalho de 8 bytes com
/// o tamanho total, para que `axion_free` reconstrua o `Layout`; devolve o
/// ponteiro para o payload (a seguir ao cabeçalho).
extern "C" fn axion_alloc(size: i64) -> *mut u8 {
    let total = size.max(1) as usize + 8;
    let layout = std::alloc::Layout::from_size_align(total, 8).unwrap();
    unsafe {
        let base = std::alloc::alloc(layout);
        *(base as *mut u64) = total as u64; // cabeçalho: tamanho total
        HEAP_ALLOCS.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
        base.add(8) // payload
    }
}

/// Liberta um objecto alocado por `axion_alloc` (lê o tamanho do cabeçalho).
extern "C" fn axion_free(ptr: *mut u8) {
    unsafe {
        let base = ptr.sub(8);
        let total = *(base as *const u64) as usize;
        let layout = std::alloc::Layout::from_size_align(total, 8).unwrap();
        std::alloc::dealloc(base, layout);
        HEAP_FREES.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
    }
}

/// Layout dos registos: campos por construtor (na ordem declarada).
#[derive(Default)]
struct RecordInfo {
    con_fields: HashMap<String, Vec<String>>, // construtor → campos (ordem)
    field_owner: HashMap<String, String>,     // nome de campo → construtor
}

impl RecordInfo {
    fn build(module: &ast::Module) -> RecordInfo {
        let mut r = RecordInfo::default();
        for d in &module.datas {
            for c in &d.cons {
                let fields: Vec<String> = c
                    .fields
                    .iter()
                    .filter(|f| !f.name.is_empty())
                    .map(|f| f.name.clone())
                    .collect();
                for f in &fields {
                    r.field_owner.insert(f.clone(), c.name.clone());
                }
                r.con_fields.insert(c.name.clone(), fields);
            }
        }
        r
    }

    /// Offset (em bytes) de um campo, e a lista de campos do seu registo.
    fn field(&self, name: &str) -> Option<(i32, &[String])> {
        let con = self.field_owner.get(name)?;
        let fields = self.con_fields.get(con)?;
        let idx = fields.iter().position(|f| f == name)?;
        Some((idx as i32 * 8, fields))
    }
}

/// Ambiente de compilação: JIT + os `FuncId`/aridade das funções do Core.
struct Cg {
    module: JITModule,
    ids: HashMap<String, (FuncId, usize)>,
    strings: HashMap<String, DataId>,
    str_counter: u32,
    puts_id: FuncId,
    show_id: FuncId,
    alloc_id: FuncId,
    free_id: FuncId,
    records: RecordInfo,
}

impl Cg {
    fn new(records: RecordInfo) -> Result<Cg, String> {
        let mut flags = cranelift::codegen::settings::builder();
        let _ = flags.set("opt_level", "none"); // fast-path (§11)
        let isa = cranelift_native::builder()
            .map_err(|e| e.to_string())?
            .finish(cranelift::codegen::settings::Flags::new(flags))
            .map_err(|e| e.to_string())?;
        let mut builder = JITBuilder::with_isa(isa, cranelift_module::default_libcall_names());
        builder.symbol("axion_puts", axion_puts as *const u8);
        builder.symbol("axion_show_int", axion_show_int as *const u8);
        builder.symbol("axion_alloc", axion_alloc as *const u8);
        builder.symbol("axion_free", axion_free as *const u8);
        let mut module = JITModule::new(builder);

        let import = |module: &mut JITModule, name: &str, nparams: usize, ret: bool| {
            let mut sig = module.make_signature();
            for _ in 0..nparams {
                sig.params.push(AbiParam::new(types::I64));
            }
            if ret {
                sig.returns.push(AbiParam::new(types::I64));
            }
            module
                .declare_function(name, Linkage::Import, &sig)
                .map_err(|e| e.to_string())
        };
        let puts_id = import(&mut module, "axion_puts", 1, false)?;
        let show_id = import(&mut module, "axion_show_int", 1, true)?;
        let alloc_id = import(&mut module, "axion_alloc", 1, true)?;
        let free_id = import(&mut module, "axion_free", 1, false)?;

        Ok(Cg {
            module,
            ids: HashMap::new(),
            strings: HashMap::new(),
            str_counter: 0,
            puts_id,
            show_id,
            alloc_id,
            free_id,
            records,
        })
    }

    fn declare_all(&mut self, fns: &[CoreFn]) -> Result<(), String> {
        for f in fns {
            let mut sig = self.module.make_signature();
            // closures recebem o ponteiro de env como 1.º parâmetro
            let nparams = f.params.len() + usize::from(f.is_closure);
            for _ in 0..nparams {
                sig.params.push(AbiParam::new(types::I64));
            }
            sig.returns.push(AbiParam::new(types::I64));
            let id = self
                .module
                .declare_function(&f.name, Linkage::Export, &sig)
                .map_err(|e| e.to_string())?;
            self.ids.insert(f.name.clone(), (id, f.params.len()));
        }
        Ok(())
    }

    /// Constrói o corpo de uma função do Core e devolve o `Context` preenchido.
    fn build(&mut self, f: &CoreFn) -> Result<Context, String> {
        let (id, _) = self.ids[&f.name];
        let nparams = f.params.len() + usize::from(f.is_closure);
        let mut ctx = self.module.make_context();
        for _ in 0..nparams {
            ctx.func.signature.params.push(AbiParam::new(types::I64));
        }
        ctx.func.signature.returns.push(AbiParam::new(types::I64));
        ctx.func.name = UserFuncName::user(0, id.as_u32());

        let mut fbctx = FunctionBuilderContext::new();
        {
            let mut builder = FunctionBuilder::new(&mut ctx.func, &mut fbctx);
            let entry = builder.create_block();
            builder.append_block_params_for_function_params(entry);
            builder.switch_to_block(entry);
            builder.seal_block(entry);
            let argvals: Vec<Value> = builder.block_params(entry).to_vec();

            let mut fx = Fx {
                builder,
                vars: HashMap::new(),
                next: 0,
                ids: &self.ids,
                module: &mut self.module,
                strings: &mut self.strings,
                str_counter: &mut self.str_counter,
                puts_id: self.puts_id,
                show_id: self.show_id,
                alloc_id: self.alloc_id,
                free_id: self.free_id,
                records: &self.records,
            };

            if f.is_closure {
                let env = argvals[0];
                for (i, cap) in f.captures.iter().enumerate() {
                    let v =
                        fx.builder
                            .ins()
                            .load(types::I64, MemFlags::new(), env, (i as i32 + 1) * 8);
                    fx.bind_val(cap, v);
                }
                for (j, p) in f.params.iter().enumerate() {
                    fx.bind_val(p, argvals[j + 1]);
                }
            } else {
                for (j, p) in f.params.iter().enumerate() {
                    fx.bind_val(p, argvals[j]);
                }
            }

            let ret = fx.emit_term(&f.body)?;
            fx.builder.ins().return_(&[ret]);
            fx.builder.finalize();
        }
        Ok(ctx)
    }
}

/// Contexto de emissão de uma função.
struct Fx<'a, 'b> {
    builder: FunctionBuilder<'b>,
    vars: HashMap<String, Variable>,
    next: u32,
    ids: &'a HashMap<String, (FuncId, usize)>,
    module: &'a mut JITModule,
    strings: &'a mut HashMap<String, DataId>,
    str_counter: &'a mut u32,
    puts_id: FuncId,
    show_id: FuncId,
    alloc_id: FuncId,
    free_id: FuncId,
    records: &'a RecordInfo,
}

impl Fx<'_, '_> {
    /// Interna um literal de string como objecto de dados (C-string).
    fn intern(&mut self, s: &str) -> Result<DataId, String> {
        if let Some(id) = self.strings.get(s) {
            return Ok(*id);
        }
        let name = format!("str{}", self.str_counter);
        *self.str_counter += 1;
        let id = self
            .module
            .declare_data(&name, Linkage::Local, false, false)
            .map_err(|e| e.to_string())?;
        let mut desc = DataDescription::new();
        let mut bytes = s.as_bytes().to_vec();
        bytes.push(0);
        desc.define(bytes.into_boxed_slice());
        self.module
            .define_data(id, &desc)
            .map_err(|e| e.to_string())?;
        self.strings.insert(s.to_string(), id);
        Ok(id)
    }

    /// Cria uma `Variable` fresca já definida com `val`.
    fn fresh_var(&mut self, val: Value) -> Variable {
        let v = Variable::new(self.next as usize);
        self.next += 1;
        self.builder.declare_var(v, types::I64);
        self.builder.def_var(v, val);
        v
    }

    fn bind_val(&mut self, name: &str, val: Value) {
        let v = self.fresh_var(val);
        self.vars.insert(name.to_string(), v);
    }

    /// Aloca um bloco de `nslots` campos (i64 cada) e devolve o ponteiro.
    fn alloc(&mut self, nslots: usize) -> Value {
        let size = self.builder.ins().iconst(types::I64, nslots as i64 * 8);
        let callee = self
            .module
            .declare_func_in_func(self.alloc_id, self.builder.func);
        let call = self.builder.ins().call(callee, &[size]);
        self.builder.inst_results(call)[0]
    }

    /// Chamada indirecta através de uma closure: `fn_ptr = clos[0]`, depois
    /// `fn_ptr(clos, args…)` (a closure é passada como env).
    fn call_closure(&mut self, clos: Value, args: &[Value]) -> Value {
        let fn_ptr = self
            .builder
            .ins()
            .load(types::I64, MemFlags::new(), clos, 0);
        let mut sig = self.module.make_signature();
        sig.params.push(AbiParam::new(types::I64)); // env
        for _ in args {
            sig.params.push(AbiParam::new(types::I64));
        }
        sig.returns.push(AbiParam::new(types::I64));
        let sigref = self.builder.import_signature(sig);
        let mut call_args = Vec::with_capacity(args.len() + 1);
        call_args.push(clos);
        call_args.extend_from_slice(args);
        let call = self.builder.ins().call_indirect(sigref, fn_ptr, &call_args);
        self.builder.inst_results(call)[0]
    }

    /// Valor de um átomo (literal ou variável ligada).
    fn atom(&mut self, a: &Atom) -> Result<Value, String> {
        match a {
            Atom::Int(n) => Ok(self.builder.ins().iconst(types::I64, *n)),
            Atom::Str(s) => {
                let data = self.intern(s)?;
                let gv = self.module.declare_data_in_func(data, self.builder.func);
                Ok(self.builder.ins().global_value(types::I64, gv))
            }
            Atom::Var(name) => match self.vars.get(name) {
                Some(v) => Ok(self.builder.use_var(*v)),
                None => Err(format!("variável '{name}' não ligada no Core")),
            },
        }
    }

    fn atoms(&mut self, xs: &[Atom]) -> Result<Vec<Value>, String> {
        xs.iter().map(|a| self.atom(a)).collect()
    }

    fn emit_term(&mut self, t: &Term) -> Result<Value, String> {
        match t {
            Term::Let(name, rhs, body) => {
                let v = self.emit_rhs(rhs)?;
                self.bind_val(name, v);
                self.emit_term(body)
            }
            Term::Drop(name, body) => {
                // Auto-Drop: liberta o objecto de heap no seu ponto de morte.
                let v = self
                    .vars
                    .get(name)
                    .copied()
                    .ok_or_else(|| format!("drop de variável '{name}' não ligada"))?;
                let ptr = self.builder.use_var(v);
                let callee = self
                    .module
                    .declare_func_in_func(self.free_id, self.builder.func);
                self.builder.ins().call(callee, &[ptr]);
                self.emit_term(body)
            }
            Term::Ret(rhs) => self.emit_rhs(rhs),
        }
    }

    fn emit_rhs(&mut self, rhs: &Rhs) -> Result<Value, String> {
        match rhs {
            Rhs::Op(op) => self.emit_op(op),
            Rhs::If(cond, t, e) => {
                let c = self.atom(cond)?;
                let then_b = self.builder.create_block();
                let else_b = self.builder.create_block();
                let merge_b = self.builder.create_block();
                self.builder.append_block_param(merge_b, types::I64);
                self.builder.ins().brif(c, then_b, &[], else_b, &[]);

                self.builder.switch_to_block(then_b);
                self.builder.seal_block(then_b);
                let tv = self.emit_term(t)?;
                self.builder.ins().jump(merge_b, &[tv]);

                self.builder.switch_to_block(else_b);
                self.builder.seal_block(else_b);
                let ev = self.emit_term(e)?;
                self.builder.ins().jump(merge_b, &[ev]);

                self.builder.switch_to_block(merge_b);
                self.builder.seal_block(merge_b);
                Ok(self.builder.block_params(merge_b)[0])
            }
            Rhs::Case(scrut, arms) => {
                let s = self.atom(scrut)?;
                self.emit_case(s, arms, 0)
            }
        }
    }

    fn emit_op(&mut self, op: &Op) -> Result<Value, String> {
        match op {
            Op::Atom(a) => self.atom(a),
            Op::Prim(o, l, r) => {
                let a = self.atom(l)?;
                let b = self.atom(r)?;
                // comparações devolvem I8; estende-se a I64 para que todo valor
                // do Core seja uniformemente i64 (ligável a uma Variable I64).
                let cmp = |me: &mut Self, cc| {
                    let c = me.builder.ins().icmp(cc, a, b);
                    me.builder.ins().uextend(types::I64, c)
                };
                Ok(match o.as_str() {
                    "+" => self.builder.ins().iadd(a, b),
                    "-" => self.builder.ins().isub(a, b),
                    "*" => self.builder.ins().imul(a, b),
                    "mod" => self.builder.ins().srem(a, b),
                    "band" => self.builder.ins().band(a, b),
                    "==" => cmp(self, IntCC::Equal),
                    "<" => cmp(self, IntCC::SignedLessThan),
                    ">" => cmp(self, IntCC::SignedGreaterThan),
                    other => return Err(format!("operador '{other}' não compila nativamente")),
                })
            }
            Op::CallDirect(name, args) => {
                let (id, arity) = *self
                    .ids
                    .get(name)
                    .ok_or_else(|| format!("função '{name}' não é compilável nativamente"))?;
                if args.len() != arity {
                    return Err(format!("'{name}' chamada com aridade errada"));
                }
                let vals = self.atoms(args)?;
                let callee = self.module.declare_func_in_func(id, self.builder.func);
                let call = self.builder.ins().call(callee, &vals);
                Ok(self.builder.inst_results(call)[0])
            }
            Op::CallClosure(clos, args) => {
                let c = self.atom(clos)?;
                let vals = self.atoms(args)?;
                Ok(self.call_closure(c, &vals))
            }
            Op::MakeClosure { func, captures } => {
                let (lam_id, _) = *self
                    .ids
                    .get(func)
                    .ok_or_else(|| format!("lambda '{func}' não declarada"))?;
                let env = self.alloc(1 + captures.len());
                let fref = self.module.declare_func_in_func(lam_id, self.builder.func);
                let faddr = self.builder.ins().func_addr(types::I64, fref);
                self.builder.ins().store(MemFlags::new(), faddr, env, 0);
                for (i, cap) in captures.iter().enumerate() {
                    let cv = self.atom(cap)?;
                    self.builder
                        .ins()
                        .store(MemFlags::new(), cv, env, (i as i32 + 1) * 8);
                }
                Ok(env)
            }
            Op::MakeTuple(xs) => {
                let ptr = self.alloc(xs.len());
                for (i, a) in xs.iter().enumerate() {
                    let v = self.atom(a)?;
                    self.builder
                        .ins()
                        .store(MemFlags::new(), v, ptr, i as i32 * 8);
                }
                Ok(ptr)
            }
            Op::MakeRecord { con, fields } => {
                let nfields = self
                    .records
                    .con_fields
                    .get(con)
                    .ok_or_else(|| format!("construtor '{con}' desconhecido"))?
                    .len();
                let ptr = self.alloc(nfields);
                for (fname, a) in fields {
                    let off = self
                        .records
                        .field(fname)
                        .map(|(o, _)| o)
                        .ok_or_else(|| format!("campo '{fname}' desconhecido"))?;
                    let v = self.atom(a)?;
                    self.builder.ins().store(MemFlags::new(), v, ptr, off);
                }
                Ok(ptr)
            }
            Op::UpdateRecord { base, fields } => {
                let base_ptr = self.atom(base)?;
                let first = &fields
                    .first()
                    .ok_or_else(|| "actualização de registo vazia".to_string())?
                    .0;
                let nfields = self
                    .records
                    .field(first)
                    .map(|(_, fs)| fs.len())
                    .ok_or_else(|| format!("campo '{first}' desconhecido"))?;
                let newptr = self.alloc(nfields);
                for i in 0..nfields {
                    let off = i as i32 * 8;
                    let v = self
                        .builder
                        .ins()
                        .load(types::I64, MemFlags::new(), base_ptr, off);
                    self.builder.ins().store(MemFlags::new(), v, newptr, off);
                }
                for (fname, a) in fields {
                    let off = self
                        .records
                        .field(fname)
                        .map(|(o, _)| o)
                        .ok_or_else(|| format!("campo '{fname}' desconhecido"))?;
                    let v = self.atom(a)?;
                    self.builder.ins().store(MemFlags::new(), v, newptr, off);
                }
                Ok(newptr)
            }
            Op::Field { name, rec } => {
                let off = self
                    .records
                    .field(name)
                    .map(|(o, _)| o)
                    .ok_or_else(|| format!("campo '{name}' desconhecido"))?;
                let r = self.atom(rec)?;
                Ok(self.builder.ins().load(types::I64, MemFlags::new(), r, off))
            }
            Op::PutStrLn(a) => {
                let v = self.atom(a)?;
                let callee = self
                    .module
                    .declare_func_in_func(self.puts_id, self.builder.func);
                self.builder.ins().call(callee, &[v]);
                Ok(self.builder.ins().iconst(types::I64, 0)) // IO () → token
            }
            Op::ShowInt(a) => {
                let v = self.atom(a)?;
                let callee = self
                    .module
                    .declare_func_in_func(self.show_id, self.builder.func);
                let call = self.builder.ins().call(callee, &[v]);
                Ok(self.builder.inst_results(call)[0])
            }
            Op::Unsupported(m) => Err(format!("{m} não compila nativamente (ainda)")),
        }
    }

    /// `case s of arms` — cadeia de `if` sobre o escrutínio. Padrões: `Int`
    /// (compara), variável/`_` (catch-all), tuplo `(a, b)` (destructura por
    /// offset). Exige um catch-all no fim.
    fn emit_case(&mut self, sval: Value, arms: &[(CPat, Term)], i: usize) -> Result<Value, String> {
        let (pat, body) = &arms[i];
        match pat {
            CPat::Wild => self.emit_term(body),
            CPat::Var(n) => {
                self.bind_val(n, sval);
                self.emit_term(body)
            }
            CPat::Tuple(ps) => {
                for (j, p) in ps.iter().enumerate() {
                    match p {
                        CPat::Wild => {}
                        CPat::Var(n) => {
                            let v = self.builder.ins().load(
                                types::I64,
                                MemFlags::new(),
                                sval,
                                j as i32 * 8,
                            );
                            self.bind_val(n, v);
                        }
                        _ => return Err("padrão de tuplo aninhado não compila nativamente".into()),
                    }
                }
                self.emit_term(body)
            }
            CPat::Int(lit) => {
                if i + 1 >= arms.len() {
                    return Err("case sem catch-all não compila nativamente (ainda)".into());
                }
                let k = self.builder.ins().iconst(types::I64, *lit);
                let cond = self.builder.ins().icmp(IntCC::Equal, sval, k);
                let then_b = self.builder.create_block();
                let else_b = self.builder.create_block();
                let merge_b = self.builder.create_block();
                self.builder.append_block_param(merge_b, types::I64);
                self.builder.ins().brif(cond, then_b, &[], else_b, &[]);

                self.builder.switch_to_block(then_b);
                self.builder.seal_block(then_b);
                let tv = self.emit_term(body)?;
                self.builder.ins().jump(merge_b, &[tv]);

                self.builder.switch_to_block(else_b);
                self.builder.seal_block(else_b);
                let ev = self.emit_case(sval, arms, i + 1)?;
                self.builder.ins().jump(merge_b, &[ev]);

                self.builder.switch_to_block(merge_b);
                self.builder.seal_block(merge_b);
                Ok(self.builder.block_params(merge_b)[0])
            }
            CPat::Con(_) => {
                Err("padrão de construtor no case não compila nativamente (ainda)".into())
            }
        }
    }
}

/// JIT-compila o Core e corre `entry` (função sem parâmetros). Devolve `Some(n)`
/// se `entry :: Int` (o chamador imprime `n`); `None` se `:: IO ()` (os efeitos
/// já foram executados durante a corrida).
pub fn run(module: &ast::Module, entry: &str) -> Result<Option<i64>, String> {
    let fns = core::lower(module);
    let entry_ok = fns
        .iter()
        .find(|f| f.name == entry)
        .map(|f| f.params.is_empty())
        .unwrap_or(false);
    if !entry_ok {
        return Err(format!(
            "'{entry}' tem de ser uma função nativa (Int/IO) sem parâmetros"
        ));
    }

    let mut cg = Cg::new(RecordInfo::build(module))?;
    cg.declare_all(&fns)?;
    for f in &fns {
        let mut ctx = cg.build(f)?;
        let id = cg.ids[&f.name].0;
        cg.module
            .define_function(id, &mut ctx)
            .map_err(|e| e.to_string())?;
        cg.module.clear_context(&mut ctx);
    }
    cg.module
        .finalize_definitions()
        .map_err(|e| e.to_string())?;

    let code = cg.module.get_finalized_function(cg.ids[entry].0);
    let f: extern "C" fn() -> i64 = unsafe { std::mem::transmute(code) };
    let val = f();

    if std::env::var("AXION_HEAP_STATS").is_ok() {
        use std::sync::atomic::Ordering::Relaxed;
        eprintln!(
            "heap: {} allocs, {} frees",
            HEAP_ALLOCS.load(Relaxed),
            HEAP_FREES.load(Relaxed)
        );
    }

    let returns_int = module
        .funcs
        .iter()
        .find(|f| f.name == entry)
        .and_then(|f| f.sig.as_ref())
        .map(|s| is_int(result_type(s)))
        .unwrap_or(true);
    Ok(returns_int.then_some(val))
}

/// Emite o Cranelift IR (texto) das funções do Core, sem JIT (`--emit clif`).
pub fn emit_ir(module: &ast::Module) -> Result<String, String> {
    let fns = core::lower(module);
    if fns.is_empty() {
        return Ok("; nenhuma função compilável nativamente (núcleo Int).\n".into());
    }
    let mut cg = Cg::new(RecordInfo::build(module))?;
    cg.declare_all(&fns)?;
    let mut out = String::new();
    for f in &fns {
        let ctx = cg.build(f)?;
        out.push_str(&format!("{}\n", ctx.func.display()));
    }
    Ok(out)
}
