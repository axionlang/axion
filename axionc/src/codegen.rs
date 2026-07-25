//! Backend nativo `--dev` (§11/§18): o «Fast-Path Backend» sobre Cranelift.
//!
//! Primeiro corte: baixa o núcleo **Int** do AST directamente para Cranelift IR
//! e JIT-compila. Suporta funções de topo de uma só cláusula com parâmetros e
//! retorno `Int`, `if`, aritmética (`+ - *`, `mod`), comparações (`== < >`),
//! chamadas (incl. recursão) e `let`. O que não cabe (multi-cláusula, `where`,
//! strings/IO, registos, closures) fica para o interpretador ou incrementos
//! seguintes — o codegen recusa com um erro claro.

use crate::ast::{self, Body, Expr, Pat, Type};
use cranelift::codegen::ir::UserFuncName;
use cranelift::prelude::{
    types, AbiParam, Configurable, EntityRef, FunctionBuilder, FunctionBuilderContext, InstBuilder,
    IntCC, Variable,
};
use cranelift_jit::{JITBuilder, JITModule};
use cranelift_module::{FuncId, Linkage, Module};
use std::collections::HashMap;

/// Uma função de topo compilável nativamente (todos os tipos `Int`, 1 cláusula,
/// padrões só variáveis/`_`).
struct Native<'a> {
    func: &'a ast::Func,
    params: Vec<String>, // nome de cada parâmetro (Int)
}

fn native_fn(f: &ast::Func) -> Option<Native<'_>> {
    let sig = f.sig.as_ref()?;
    // todos os parâmetros e o retorno têm de ser Int
    if sig.param_types().iter().any(|t| !is_int(t)) || !is_int(result_type(sig)) {
        return None;
    }
    let clause = match f.clauses.as_slice() {
        [c] => c,
        _ => return None, // multi-cláusula: por fazer (desugar em if-chain)
    };
    if !clause.wher.is_empty() {
        return None; // where: por fazer
    }
    let mut params = Vec::new();
    for p in &clause.pats {
        match p {
            Pat::Var(n, _) => params.push(n.clone()),
            Pat::Wild(_) => params.push(format!("_w{}", params.len())),
            _ => return None, // padrões literais: por fazer
        }
    }
    Some(Native { func: f, params })
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

/// Ambiente de compilação: JIT + os `FuncId`/aridade das funções nativas.
struct Cg {
    module: JITModule,
    ids: HashMap<String, (FuncId, usize)>,
}

impl Cg {
    fn new() -> Result<Cg, String> {
        let mut flags = cranelift::codegen::settings::builder();
        // fast-path: sem otimizações agressivas (§11, «zero em dev»)
        let _ = flags.set("opt_level", "none");
        let isa_builder = cranelift_native::builder().map_err(|e| e.to_string())?;
        let isa = isa_builder
            .finish(cranelift::codegen::settings::Flags::new(flags))
            .map_err(|e| e.to_string())?;
        let builder = JITBuilder::with_isa(isa, cranelift_module::default_libcall_names());
        Ok(Cg {
            module: JITModule::new(builder),
            ids: HashMap::new(),
        })
    }

    fn declare_all(&mut self, natives: &[Native]) -> Result<(), String> {
        for n in natives {
            let mut sig = self.module.make_signature();
            for _ in &n.params {
                sig.params.push(AbiParam::new(types::I64));
            }
            sig.returns.push(AbiParam::new(types::I64));
            let id = self
                .module
                .declare_function(&n.func.name, Linkage::Export, &sig)
                .map_err(|e| e.to_string())?;
            self.ids.insert(n.func.name.clone(), (id, n.params.len()));
        }
        Ok(())
    }

    fn define(&mut self, n: &Native) -> Result<(), String> {
        let (id, arity) = self.ids[&n.func.name];
        let mut ctx = self.module.make_context();
        for _ in 0..arity {
            ctx.func.signature.params.push(AbiParam::new(types::I64));
        }
        ctx.func.signature.returns.push(AbiParam::new(types::I64));
        ctx.func.name = UserFuncName::user(0, id.as_u32());

        let mut fbctx = FunctionBuilderContext::new();
        let mut builder = FunctionBuilder::new(&mut ctx.func, &mut fbctx);
        let entry = builder.create_block();
        builder.append_block_params_for_function_params(entry);
        builder.switch_to_block(entry);
        builder.seal_block(entry);

        // liga cada parâmetro a uma Variable
        let mut vars: HashMap<String, Variable> = HashMap::new();
        let mut next = 0u32;
        let block_params: Vec<_> = builder.block_params(entry).to_vec();
        for (i, name) in n.params.iter().enumerate() {
            let v = Variable::new(next as usize);
            next += 1;
            builder.declare_var(v, types::I64);
            builder.def_var(v, block_params[i]);
            vars.insert(name.clone(), v);
        }

        let body = match &n.func.clauses[0].body {
            Body::Plain(e) => e,
            Body::Guarded(_) => return Err("guardas ainda não compilam nativamente".into()),
        };
        let mut fx = Fx {
            builder,
            vars,
            next,
            ids: &self.ids,
            module: &mut self.module,
        };
        let ret = fx.expr(body)?;
        fx.builder.ins().return_(&[ret]);
        fx.builder.finalize();

        self.module
            .define_function(id, &mut ctx)
            .map_err(|e| e.to_string())?;
        self.module.clear_context(&mut ctx);
        Ok(())
    }
}

/// Contexto de emissão de uma função.
struct Fx<'a, 'b> {
    builder: FunctionBuilder<'b>,
    vars: HashMap<String, Variable>,
    next: u32,
    ids: &'a HashMap<String, (FuncId, usize)>,
    module: &'a mut JITModule,
}

impl Fx<'_, '_> {
    fn expr(&mut self, e: &Expr) -> Result<cranelift::prelude::Value, String> {
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
                let (id, arity) = *self
                    .ids
                    .get(name)
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

fn collect_natives(module: &ast::Module) -> Vec<Native<'_>> {
    module.funcs.iter().filter_map(native_fn).collect()
}

/// JIT-compila o núcleo Int e corre `entry` (função `:: Int`, sem parâmetros),
/// devolvendo o resultado.
pub fn run(module: &ast::Module, entry: &str) -> Result<i64, String> {
    let natives = collect_natives(module);
    let entry_ok = natives
        .iter()
        .find(|n| n.func.name == entry)
        .map(|n| n.params.is_empty())
        .unwrap_or(false);
    if !entry_ok {
        return Err(format!(
            "'{entry}' tem de ser uma função nativa 'Int' sem parâmetros"
        ));
    }

    let mut cg = Cg::new()?;
    cg.declare_all(&natives)?;
    for n in &natives {
        cg.define(n)?;
    }
    cg.module
        .finalize_definitions()
        .map_err(|e| e.to_string())?;

    let (id, _) = cg.ids[entry];
    let code = cg.module.get_finalized_function(id);
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
        let ir = build_ir(&mut cg, n)?;
        out.push_str(&ir);
        out.push('\n');
    }
    Ok(out)
}

/// Constrói a função e devolve o seu IR textual (sem a definir no módulo).
fn build_ir(cg: &mut Cg, n: &Native) -> Result<String, String> {
    let (id, arity) = cg.ids[&n.func.name];
    let mut ctx = cg.module.make_context();
    for _ in 0..arity {
        ctx.func.signature.params.push(AbiParam::new(types::I64));
    }
    ctx.func.signature.returns.push(AbiParam::new(types::I64));
    ctx.func.name = UserFuncName::user(0, id.as_u32());

    let mut fbctx = FunctionBuilderContext::new();
    let mut builder = FunctionBuilder::new(&mut ctx.func, &mut fbctx);
    let entry = builder.create_block();
    builder.append_block_params_for_function_params(entry);
    builder.switch_to_block(entry);
    builder.seal_block(entry);

    let mut vars: HashMap<String, Variable> = HashMap::new();
    let mut next = 0u32;
    let block_params: Vec<_> = builder.block_params(entry).to_vec();
    for (i, name) in n.params.iter().enumerate() {
        let v = Variable::new(next as usize);
        next += 1;
        builder.declare_var(v, types::I64);
        builder.def_var(v, block_params[i]);
        vars.insert(name.clone(), v);
    }
    let body = match &n.func.clauses[0].body {
        Body::Plain(e) => e,
        Body::Guarded(_) => return Err("guardas ainda não compilam nativamente".into()),
    };
    let mut fx = Fx {
        builder,
        vars,
        next,
        ids: &cg.ids,
        module: &mut cg.module,
    };
    let ret = fx.expr(body)?;
    fx.builder.ins().return_(&[ret]);
    fx.builder.finalize();
    let ir = format!("{}", ctx.func.display());
    cg.module.clear_context(&mut ctx);
    Ok(ir)
}
