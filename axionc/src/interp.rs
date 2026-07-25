//! Interpretador tree-walking do subconjunto L0/L1 — o "correr" do esqueleto
//! ambulante (§17). Será o embrião do fast-path de `--dev`; o backend nativo
//! (Cranelift/LLVM) é alvo das fases seguintes.

use crate::ast::*;
use std::cell::RefCell;
use std::collections::{HashMap, HashSet};
use std::rc::Rc;

type Env = Rc<Scope>;

struct Scope {
    vars: RefCell<HashMap<String, Value>>,
    parent: Option<Env>,
}

/// Tabela de funções e construtores de topo, resolvidos por nome em execução.
pub struct Program {
    funcs: HashMap<String, Rc<Func>>,
    cons: HashMap<String, Vec<String>>, // construtor → nomes dos campos (por ordem)
    selectors: HashSet<String>,         // nomes de campo usáveis como selectores
}

#[derive(Clone)]
enum Value {
    Int(i64),
    Str(String),
    Bool(bool),
    Unit,
    /// Acção de IO ainda por executar (o texto a imprimir).
    Io(String),
    Closure {
        def: Rc<Func>,
        env: Env,
        args: Vec<Value>,
    },
    Builtin {
        name: &'static str,
        args: Vec<Value>,
    },
    /// Um registo: construtor + campos (por ordem de construção).
    Record {
        con: String,
        fields: Vec<(String, Value)>,
    },
    /// Um construtor por aplicar (aridade = nº de campos).
    Ctor {
        name: String,
        field_names: Vec<String>,
        args: Vec<Value>,
    },
    /// Um selector de campo (`pid`, `status`, …), aridade 1.
    Selector {
        field: String,
    },
}

pub type RunError = String;

fn empty_env() -> Env {
    Rc::new(Scope {
        vars: RefCell::new(HashMap::new()),
        parent: None,
    })
}

fn child_env(parent: &Env) -> Env {
    Rc::new(Scope {
        vars: RefCell::new(HashMap::new()),
        parent: Some(parent.clone()),
    })
}

fn lookup(env: &Env, name: &str) -> Option<Value> {
    let mut cur = Some(env.clone());
    while let Some(e) = cur {
        if let Some(v) = e.vars.borrow().get(name) {
            return Some(v.clone());
        }
        cur = e.parent.clone();
    }
    None
}

/// Constrói a tabela de topo (funções, construtores, selectores) do módulo.
fn build_program(module: &Module) -> Program {
    let mut funcs = HashMap::new();
    for f in &module.funcs {
        funcs.insert(f.name.clone(), Rc::new(f.clone()));
    }
    let mut cons = HashMap::new();
    let mut selectors = HashSet::new();
    for d in &module.datas {
        for c in &d.cons {
            // campos posicionais recebem nomes sintéticos "_0", "_1", …
            let names: Vec<String> = c
                .fields
                .iter()
                .enumerate()
                .map(|(i, f)| {
                    if f.name.is_empty() {
                        format!("_{i}")
                    } else {
                        f.name.clone()
                    }
                })
                .collect();
            for f in &c.fields {
                if !f.name.is_empty() {
                    selectors.insert(f.name.clone());
                }
            }
            cons.insert(c.name.clone(), names);
        }
    }
    Program {
        funcs,
        cons,
        selectors,
    }
}

/// Compila o módulo para um `Program` e corre `main`, executando o IO resultante.
pub fn run(module: &Module) -> Result<(), RunError> {
    let prog = build_program(module);
    let main = prog
        .funcs
        .get("main")
        .ok_or_else(|| "não há 'main' para correr".to_string())?
        .clone();
    let base = empty_env();
    let v = run_func(&prog, &main, &base, Vec::new())?;
    match v {
        Value::Io(s) => {
            print!("{s}");
            Ok(())
        }
        Value::Unit => Ok(()),
        other => Err(format!(
            "'main' devia ser uma acção IO, foi {}",
            type_name(&other)
        )),
    }
}

fn type_name(v: &Value) -> &'static str {
    match v {
        Value::Int(_) => "Int",
        Value::Str(_) => "String",
        Value::Bool(_) => "Bool",
        Value::Unit => "()",
        Value::Io(_) => "IO",
        Value::Record { .. } => "registo",
        Value::Closure { .. }
        | Value::Builtin { .. }
        | Value::Ctor { .. }
        | Value::Selector { .. } => "função",
    }
}

fn builtin_arity(name: &str) -> usize {
    match name {
        "putStrLn" | "show" => 1,
        _ => 1,
    }
}

fn clause_arity(def: &Func) -> usize {
    def.clauses.first().map(|c| c.pats.len()).unwrap_or(0)
}

fn eval(prog: &Program, env: &Env, e: &Expr) -> Result<Value, RunError> {
    match e {
        Expr::Int(n, _) => Ok(Value::Int(*n)),
        Expr::Str(s, _) => Ok(Value::Str(s.clone())),
        Expr::Con(name, _) => Ok(match name.as_str() {
            "True" => Value::Bool(true),
            "False" => Value::Bool(false),
            _ => Value::Unit,
        }),
        Expr::Var(name, _) => resolve_var(prog, env, name),
        Expr::App(f, x, _) => {
            let callee = eval(prog, env, f)?;
            let arg = eval(prog, env, x)?;
            apply(prog, callee, arg)
        }
        Expr::BinOp(op, l, r, _) => {
            let a = eval(prog, env, l)?;
            let b = eval(prog, env, r)?;
            eval_binop(op, a, b)
        }
        Expr::If(c, t, el, _) => match eval(prog, env, c)? {
            Value::Bool(true) => eval(prog, env, t),
            Value::Bool(false) => eval(prog, env, el),
            other => Err(format!(
                "condição de 'if' devia ser Bool, foi {}",
                type_name(&other)
            )),
        },
        Expr::Tuple(es, _) => {
            // tuplos não têm representação de runtime dedicada na Fase 1;
            // avaliam-se os componentes (efeitos) e devolve-se Unit.
            for e in es {
                eval(prog, env, e)?;
            }
            Ok(Value::Unit)
        }
        Expr::Let(binds, body, _) => {
            let child = child_env(env);
            bind_funcs(binds, &child);
            eval(prog, &child, body)
        }
        Expr::Case(scrut, arms, _) => {
            let v = eval(prog, env, scrut)?;
            for (pat, body) in arms {
                let child = child_env(env);
                if match_pat(pat, &v, &child) {
                    return eval(prog, &child, body);
                }
            }
            Err("nenhum ramo do 'case' encaixou".to_string())
        }
        Expr::RecordCon(con, fields, _) => {
            let mut vals = Vec::with_capacity(fields.len());
            for (name, e) in fields {
                vals.push((name.clone(), eval(prog, env, e)?));
            }
            Ok(Value::Record {
                con: con.clone(),
                fields: vals,
            })
        }
        Expr::RecordUpd(base, updates, _) => {
            let base = eval(prog, env, base)?;
            let Value::Record { con, mut fields } = base else {
                return Err(format!(
                    "actualização de registo sobre um {} (não é registo)",
                    type_name(&base)
                ));
            };
            for (name, e) in updates {
                let v = eval(prog, env, e)?;
                match fields.iter_mut().find(|(f, _)| f == name) {
                    Some(slot) => slot.1 = v,
                    None => fields.push((name.clone(), v)),
                }
            }
            Ok(Value::Record { con, fields })
        }
        // lambdas surgem em programas de arena (§3), verificados com --check;
        // o interpretador ainda não as executa.
        Expr::Lam(_, _, _) => Err("lambdas ainda não são executáveis (usar --check)".to_string()),
    }
}

fn resolve_var(prog: &Program, env: &Env, name: &str) -> Result<Value, RunError> {
    if let Some(v) = lookup(env, name) {
        return force(prog, v);
    }
    if let Some(def) = prog.funcs.get(name) {
        let v = Value::Closure {
            def: def.clone(),
            env: empty_env(),
            args: Vec::new(),
        };
        return force(prog, v);
    }
    if let Some(field_names) = prog.cons.get(name) {
        let v = Value::Ctor {
            name: name.to_string(),
            field_names: field_names.clone(),
            args: Vec::new(),
        };
        return force(prog, v);
    }
    if prog.selectors.contains(name) {
        return Ok(Value::Selector {
            field: name.to_string(),
        });
    }
    match name {
        "putStrLn" | "show" => Ok(Value::Builtin {
            name: if name == "putStrLn" {
                "putStrLn"
            } else {
                "show"
            },
            args: Vec::new(),
        }),
        _ => Err(format!("nome não encontrado em runtime: '{name}'")),
    }
}

/// Força CAFs (funções de aridade 0, como `main`, e construtores nulários)
/// avaliando o corpo / construindo o registo.
fn force(prog: &Program, v: Value) -> Result<Value, RunError> {
    match v {
        Value::Closure { def, env, args } if args.len() >= clause_arity(&def) => {
            run_func(prog, &def, &env, args)
        }
        Value::Ctor {
            name,
            field_names,
            args,
        } if args.len() >= field_names.len() => Ok(build_record(name, field_names, args)),
        other => Ok(other),
    }
}

fn build_record(con: String, field_names: Vec<String>, args: Vec<Value>) -> Value {
    Value::Record {
        con,
        fields: field_names.into_iter().zip(args).collect(),
    }
}

fn apply(prog: &Program, callee: Value, arg: Value) -> Result<Value, RunError> {
    match callee {
        Value::Closure { def, env, mut args } => {
            args.push(arg);
            if args.len() >= clause_arity(&def) {
                run_func(prog, &def, &env, args)
            } else {
                Ok(Value::Closure { def, env, args })
            }
        }
        Value::Builtin { name, mut args } => {
            args.push(arg);
            if args.len() >= builtin_arity(name) {
                run_builtin(name, args)
            } else {
                Ok(Value::Builtin { name, args })
            }
        }
        Value::Ctor {
            name,
            field_names,
            mut args,
        } => {
            args.push(arg);
            if args.len() >= field_names.len() {
                Ok(build_record(name, field_names, args))
            } else {
                Ok(Value::Ctor {
                    name,
                    field_names,
                    args,
                })
            }
        }
        Value::Selector { field } => match arg {
            Value::Record { fields, .. } => fields
                .into_iter()
                .find(|(f, _)| *f == field)
                .map(|(_, v)| v)
                .ok_or_else(|| format!("registo sem o campo '{field}'")),
            other => Err(format!(
                "selector '.{field}' aplicado a um {} (não é registo)",
                type_name(&other)
            )),
        },
        other => Err(format!(
            "tentou aplicar algo que não é função: {}",
            type_name(&other)
        )),
    }
}

fn run_func(
    prog: &Program,
    def: &Rc<Func>,
    captured: &Env,
    args: Vec<Value>,
) -> Result<Value, RunError> {
    for clause in &def.clauses {
        let child = child_env(captured);
        if match_pats(&clause.pats, &args, &child) {
            bind_funcs(&clause.wher, &child);
            return eval_body(prog, &child, &clause.body);
        }
    }
    Err(format!(
        "nenhuma cláusula de '{}' encaixou nos argumentos",
        def.name
    ))
}

fn eval_body(prog: &Program, env: &Env, body: &Body) -> Result<Value, RunError> {
    match body {
        Body::Plain(e) => eval(prog, env, e),
        Body::Guarded(arms) => {
            for (guard, res) in arms {
                match eval(prog, env, guard)? {
                    Value::Bool(true) => return eval(prog, env, res),
                    _ => continue,
                }
            }
            Err("nenhuma guarda foi verdadeira".to_string())
        }
    }
}

/// Insere funções locais (`where`/`let`) no env, capturando esse mesmo env
/// (para recursão e recursão mútua).
fn bind_funcs(funcs: &[Func], env: &Env) {
    for f in funcs {
        env.vars.borrow_mut().insert(
            f.name.clone(),
            Value::Closure {
                def: Rc::new(f.clone()),
                env: env.clone(),
                args: Vec::new(),
            },
        );
    }
}

fn match_pats(pats: &[Pat], args: &[Value], env: &Env) -> bool {
    if pats.len() > args.len() {
        return false;
    }
    pats.iter().zip(args).all(|(p, v)| match_pat(p, v, env))
}

fn match_pat(pat: &Pat, v: &Value, env: &Env) -> bool {
    match pat {
        Pat::Wild(_) => true,
        Pat::Var(name, _) => {
            env.vars.borrow_mut().insert(name.clone(), v.clone());
            true
        }
        Pat::Int(n, _) => matches!(v, Value::Int(m) if m == n),
        Pat::Con(name, _, _) => matches!(
            (name.as_str(), v),
            ("True", Value::Bool(true)) | ("False", Value::Bool(false))
        ),
    }
}

fn eval_binop(op: &str, a: Value, b: Value) -> Result<Value, RunError> {
    use Value::*;
    match (op, a, b) {
        // Int é de largura fixa (§ Listagem 1.4): a aritmética faz wrapping,
        // semântica total que evita panics de overflow.
        ("+", Int(x), Int(y)) => Ok(Int(x.wrapping_add(y))),
        ("-", Int(x), Int(y)) => Ok(Int(x.wrapping_sub(y))),
        ("*", Int(x), Int(y)) => Ok(Int(x.wrapping_mul(y))),
        ("mod", Int(x), Int(y)) if y != 0 => Ok(Int(x.rem_euclid(y))),
        ("mod", Int(_), Int(_)) => Err("mod por zero".to_string()),
        ("==", Int(x), Int(y)) => Ok(Bool(x == y)),
        ("<", Int(x), Int(y)) => Ok(Bool(x < y)),
        (">", Int(x), Int(y)) => Ok(Bool(x > y)),
        (op, x, y) => Err(format!(
            "operador '{op}' não se aplica a {} e {}",
            type_name(&x),
            type_name(&y)
        )),
    }
}

fn run_builtin(name: &str, args: Vec<Value>) -> Result<Value, RunError> {
    match (name, args.as_slice()) {
        ("putStrLn", [Value::Str(s)]) => Ok(Value::Io(format!("{s}\n"))),
        ("show", [Value::Int(n)]) => Ok(Value::Str(n.to_string())),
        ("show", [Value::Bool(b)]) => Ok(Value::Str(b.to_string())),
        (name, _) => Err(format!("builtin '{name}' recebeu argumentos inválidos")),
    }
}

/// Tipo de runtime de um valor — usado pelos property tests de preservação.
#[cfg(test)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum RtType {
    Int,
    Bool,
    Str,
    Unit,
    Io,
    Record,
    Fun,
}

/// Avalia a definição de topo `name` (aridade 0) e devolve o tipo de runtime do
/// valor. Ponto de entrada para os property tests de progresso/preservação.
#[cfg(test)]
pub(crate) fn eval_binding(module: &Module, name: &str) -> Result<RtType, RunError> {
    let prog = build_program(module);
    let def = prog
        .funcs
        .get(name)
        .ok_or_else(|| format!("sem definição '{name}'"))?
        .clone();
    let v = run_func(&prog, &def, &empty_env(), Vec::new())?;
    Ok(match v {
        Value::Int(_) => RtType::Int,
        Value::Bool(_) => RtType::Bool,
        Value::Str(_) => RtType::Str,
        Value::Unit => RtType::Unit,
        Value::Io(_) => RtType::Io,
        Value::Record { .. } => RtType::Record,
        Value::Closure { .. }
        | Value::Builtin { .. }
        | Value::Ctor { .. }
        | Value::Selector { .. } => RtType::Fun,
    })
}
