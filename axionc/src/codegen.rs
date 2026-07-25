//! Backend nativo `--dev` (§11/§18): o «Fast-Path Backend» sobre Cranelift.
//!
//! Baixa o núcleo **Int** do AST para Cranelift IR e JIT-compila. Suporta
//! funções de topo (com assinatura `Int`), **multi-cláusula** com padrões
//! variável/`_`/literal (desugaradas numa cadeia de `if`, exigindo uma cláusula
//! catch-all no fim), **`where`** (os locais são *liftados* para funções nativas
//! com nome mangled), `if`, aritmética (`+ - *`, `mod`), comparações (`== < >`),
//! chamadas (incl. recursão e recursão mútua) e `let`. Strings/IO, registos,
//! tuplos e closures ficam para o interpretador — o codegen recusa com um erro.

use crate::ast::{self, Body, Expr, Pat, Type};
use cranelift::codegen::ir::UserFuncName;
use cranelift::codegen::Context;
use cranelift::prelude::{
    types, AbiParam, Configurable, EntityRef, FunctionBuilder, FunctionBuilderContext, InstBuilder,
    IntCC, Value, Variable,
};
use cranelift_jit::{JITBuilder, JITModule};
use cranelift_module::{FuncId, Linkage, Module};
use std::collections::HashMap;

/// Uma função a compilar nativamente (de topo, ou local de `where` liftado).
struct NativeFn<'a> {
    /// nome único no módulo (mangled para locais de `where`)
    name: String,
    arity: usize,
    clauses: &'a [ast::Clause],
    /// nome-de-chamada → nome-no-módulo (locais de `where` visíveis no corpo)
    locals: HashMap<String, String>,
}

fn is_int(t: &Type) -> bool {
    matches!(t.head_con(), Some("Int"))
}

fn result_type(sig: &Type) -> &Type {
    let mut t = sig;
    while let Type::Arrow { to, .. } = t {
        t = to;
    }
    t
}

/// Uma função de topo é candidata se a sua assinatura for toda `Int`.
fn top_candidate(f: &ast::Func) -> Option<usize> {
    let sig = f.sig.as_ref()?;
    if sig.param_types().iter().any(|t| !is_int(t)) || !is_int(result_type(sig)) {
        return None;
    }
    Some(f.clauses.first().map(|c| c.pats.len()).unwrap_or(0))
}

/// Reúne as funções nativas: as de topo candidatas e, para cada uma, os locais
/// de `where` (liftados com nome mangled, partilhando o mapa de locais).
fn collect_natives(module: &ast::Module) -> Vec<NativeFn<'_>> {
    let mut out = Vec::new();
    for f in &module.funcs {
        let Some(arity) = top_candidate(f) else {
            continue;
        };
        // locais de where (de todas as cláusulas)
        let wheres: Vec<&ast::Func> = f.clauses.iter().flat_map(|c| &c.wher).collect();
        let mut locals = HashMap::new();
        for w in &wheres {
            locals.insert(w.name.clone(), format!("{}${}", f.name, w.name));
        }
        out.push(NativeFn {
            name: f.name.clone(),
            arity,
            clauses: &f.clauses,
            locals: locals.clone(),
        });
        for w in &wheres {
            let warity = w.clauses.first().map(|c| c.pats.len()).unwrap_or(0);
            out.push(NativeFn {
                name: locals[&w.name].clone(),
                arity: warity,
                clauses: &w.clauses,
                locals: locals.clone(),
            });
        }
    }
    out
}

/// Ambiente de compilação: JIT + os `FuncId`/aridade das funções nativas.
struct Cg {
    module: JITModule,
    ids: HashMap<String, (FuncId, usize)>,
}

impl Cg {
    fn new() -> Result<Cg, String> {
        let mut flags = cranelift::codegen::settings::builder();
        let _ = flags.set("opt_level", "none"); // fast-path (§11)
        let isa = cranelift_native::builder()
            .map_err(|e| e.to_string())?
            .finish(cranelift::codegen::settings::Flags::new(flags))
            .map_err(|e| e.to_string())?;
        let builder = JITBuilder::with_isa(isa, cranelift_module::default_libcall_names());
        Ok(Cg {
            module: JITModule::new(builder),
            ids: HashMap::new(),
        })
    }

    fn declare_all(&mut self, natives: &[NativeFn]) -> Result<(), String> {
        for n in natives {
            let mut sig = self.module.make_signature();
            for _ in 0..n.arity {
                sig.params.push(AbiParam::new(types::I64));
            }
            sig.returns.push(AbiParam::new(types::I64));
            let id = self
                .module
                .declare_function(&n.name, Linkage::Export, &sig)
                .map_err(|e| e.to_string())?;
            self.ids.insert(n.name.clone(), (id, n.arity));
        }
        Ok(())
    }

    /// Constrói o corpo da função e devolve o `Context` já preenchido.
    fn build(&mut self, n: &NativeFn) -> Result<Context, String> {
        let (id, arity) = self.ids[&n.name];
        let mut ctx = self.module.make_context();
        for _ in 0..arity {
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
            let mut argvars = Vec::with_capacity(arity);
            for (i, val) in argvals.iter().enumerate() {
                let v = Variable::new(i);
                builder.declare_var(v, types::I64);
                builder.def_var(v, *val);
                argvars.push(v);
            }

            let mut fx = Fx {
                builder,
                vars: HashMap::new(),
                next: arity as u32,
                ids: &self.ids,
                module: &mut self.module,
                locals: &n.locals,
            };
            let ret = fx.clauses(n.clauses, &argvars, 0)?;
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
    locals: &'a HashMap<String, String>,
}

impl Fx<'_, '_> {
    /// Desugar de multi-cláusula numa cadeia de `if`; exige catch-all no fim.
    fn clauses(
        &mut self,
        clauses: &[ast::Clause],
        argvars: &[Variable],
        i: usize,
    ) -> Result<Value, String> {
        let clause = &clauses[i];
        let lits: Vec<(usize, i64)> = clause
            .pats
            .iter()
            .enumerate()
            .filter_map(|(j, p)| match p {
                Pat::Int(n, _) => Some((j, *n)),
                _ => None,
            })
            .collect();

        if lits.is_empty() {
            // catch-all: liga os padrões-variável e emite o corpo
            self.bind_clause(clause, argvars);
            return self.body(clause);
        }
        if i + 1 >= clauses.len() {
            return Err("função sem cláusula catch-all não compila nativamente (ainda)".into());
        }

        // cond = AND(argvars[j] == lit)
        let cond = {
            let mut acc: Option<Value> = None;
            for (j, lit) in &lits {
                let av = self.builder.use_var(argvars[*j]);
                let k = self.builder.ins().iconst(types::I64, *lit);
                let eq = self.builder.ins().icmp(IntCC::Equal, av, k);
                acc = Some(match acc {
                    None => eq,
                    Some(a) => self.builder.ins().band(a, eq),
                });
            }
            acc.unwrap()
        };

        let then_b = self.builder.create_block();
        let else_b = self.builder.create_block();
        let merge_b = self.builder.create_block();
        self.builder.append_block_param(merge_b, types::I64);
        self.builder.ins().brif(cond, then_b, &[], else_b, &[]);

        self.builder.switch_to_block(then_b);
        self.builder.seal_block(then_b);
        self.bind_clause(clause, argvars);
        let tv = self.body(clause)?;
        self.builder.ins().jump(merge_b, &[tv]);

        self.builder.switch_to_block(else_b);
        self.builder.seal_block(else_b);
        let ev = self.clauses(clauses, argvars, i + 1)?;
        self.builder.ins().jump(merge_b, &[ev]);

        self.builder.switch_to_block(merge_b);
        self.builder.seal_block(merge_b);
        Ok(self.builder.block_params(merge_b)[0])
    }

    fn bind_clause(&mut self, clause: &ast::Clause, argvars: &[Variable]) {
        for (j, p) in clause.pats.iter().enumerate() {
            if let Pat::Var(name, _) = p {
                self.vars.insert(name.clone(), argvars[j]);
            }
        }
    }

    fn body(&mut self, clause: &ast::Clause) -> Result<Value, String> {
        match &clause.body {
            Body::Plain(e) => self.expr(e),
            Body::Guarded(_) => Err("guardas ainda não compilam nativamente".into()),
        }
    }

    fn expr(&mut self, e: &Expr) -> Result<Value, String> {
        match e {
            Expr::Int(n, _) => Ok(self.builder.ins().iconst(types::I64, *n)),
            Expr::Var(name, _) => match self.vars.get(name) {
                Some(v) => Ok(self.builder.use_var(*v)),
                None => Err(format!("variável '{name}' não é um Int local")),
            },
            Expr::BinOp(op, l, r, _) => {
                let a = self.expr(l)?;
                let b = self.expr(r)?;
                let ins = self.builder.ins();
                Ok(match op.as_str() {
                    "+" => ins.iadd(a, b),
                    "-" => ins.isub(a, b),
                    "*" => ins.imul(a, b),
                    "mod" => ins.srem(a, b),
                    "==" => ins.icmp(IntCC::Equal, a, b),
                    "<" => ins.icmp(IntCC::SignedLessThan, a, b),
                    ">" => ins.icmp(IntCC::SignedGreaterThan, a, b),
                    other => return Err(format!("operador '{other}' não compila nativamente")),
                })
            }
            Expr::If(c, t, el, _) => {
                let cond = self.expr(c)?;
                let then_b = self.builder.create_block();
                let else_b = self.builder.create_block();
                let merge_b = self.builder.create_block();
                self.builder.append_block_param(merge_b, types::I64);
                self.builder.ins().brif(cond, then_b, &[], else_b, &[]);

                self.builder.switch_to_block(then_b);
                self.builder.seal_block(then_b);
                let tv = self.expr(t)?;
                self.builder.ins().jump(merge_b, &[tv]);

                self.builder.switch_to_block(else_b);
                self.builder.seal_block(else_b);
                let ev = self.expr(el)?;
                self.builder.ins().jump(merge_b, &[ev]);

                self.builder.switch_to_block(merge_b);
                self.builder.seal_block(merge_b);
                Ok(self.builder.block_params(merge_b)[0])
            }
            Expr::Let(binds, body, _) => {
                for b in binds {
                    let rhs = match b.clauses.as_slice() {
                        [c] if c.pats.is_empty() => match &c.body {
                            Body::Plain(e) => e,
                            _ => return Err("let com guardas não compila nativamente".into()),
                        },
                        _ => return Err("let não trivial não compila nativamente".into()),
                    };
                    let val = self.expr(rhs)?;
                    let v = Variable::new(self.next as usize);
                    self.next += 1;
                    self.builder.declare_var(v, types::I64);
                    self.builder.def_var(v, val);
                    self.vars.insert(b.name.clone(), v);
                }
                self.expr(body)
            }
            Expr::App(_, _, _) => {
                let (head, args) = spine(e);
                let name = match head {
                    Expr::Var(n, _) => n,
                    _ => return Err("chamada indirecta não compila nativamente".into()),
                };
                let target = self.locals.get(name).map(String::as_str).unwrap_or(name);
                let (id, arity) = *self
                    .ids
                    .get(target)
                    .ok_or_else(|| format!("função '{name}' não é compilável nativamente"))?;
                if args.len() != arity {
                    return Err(format!("'{name}' chamada com aridade errada"));
                }
                let mut vals = Vec::with_capacity(args.len());
                for a in &args {
                    vals.push(self.expr(a)?);
                }
                let callee = self.module.declare_func_in_func(id, self.builder.func);
                let call = self.builder.ins().call(callee, &vals);
                Ok(self.builder.inst_results(call)[0])
            }
            other => Err(format!(
                "expressão não compila nativamente ({}); usar o interpretador",
                node_kind(other)
            )),
        }
    }
}

fn node_kind(e: &Expr) -> &'static str {
    match e {
        Expr::Str(_, _) => "string",
        Expr::Con(_, _) => "construtor",
        Expr::Case(_, _, _) => "case",
        Expr::Tuple(_, _) => "tuplo",
        Expr::RecordCon(_, _, _) | Expr::RecordUpd(_, _, _) => "registo",
        Expr::Lam(_, _, _) => "lambda",
        _ => "expressão",
    }
}

fn spine(e: &Expr) -> (&Expr, Vec<&Expr>) {
    let mut args = Vec::new();
    let mut cur = e;
    while let Expr::App(f, a, _) = cur {
        args.push(a.as_ref());
        cur = f;
    }
    args.reverse();
    (cur, args)
}

/// JIT-compila o núcleo Int e corre `entry` (função `:: Int`, sem parâmetros).
pub fn run(module: &ast::Module, entry: &str) -> Result<i64, String> {
    let natives = collect_natives(module);
    let entry_ok = natives
        .iter()
        .find(|n| n.name == entry)
        .map(|n| n.arity == 0)
        .unwrap_or(false);
    if !entry_ok {
        return Err(format!(
            "'{entry}' tem de ser uma função nativa 'Int' sem parâmetros"
        ));
    }

    let mut cg = Cg::new()?;
    cg.declare_all(&natives)?;
    for n in &natives {
        let mut ctx = cg.build(n)?;
        let id = cg.ids[&n.name].0;
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
    Ok(f())
}

/// Emite o Cranelift IR (texto) das funções nativas, sem JIT (`--emit clif`).
pub fn emit_ir(module: &ast::Module) -> Result<String, String> {
    let natives = collect_natives(module);
    if natives.is_empty() {
        return Ok("; nenhuma função compilável nativamente (núcleo Int).\n".into());
    }
    let mut cg = Cg::new()?;
    cg.declare_all(&natives)?;
    let mut out = String::new();
    for n in &natives {
        let ctx = cg.build(n)?;
        out.push_str(&format!("{}\n", ctx.func.display()));
    }
    Ok(out)
}
