//! Interpretador tree-walking do subconjunto L0/L1 — o "correr" do esqueleto
//! ambulante (§17). Será o embrião do fast-path de `--dev`; o backend nativo
//! (Cranelift/LLVM) é alvo das fases seguintes.

use crate::ast::*;
use std::cell::RefCell;
use std::collections::HashMap;
use std::rc::Rc;

type Env = Rc<Scope>;

struct Scope {
    vars: RefCell<HashMap<String, Value>>,
    parent: Option<Env>,
}

/// Tabela de funções de topo (globais), resolvidas por nome durante a execução.
pub struct Program {
    funcs: HashMap<String, Rc<Func>>,
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

/// Compila o módulo para um `Program` e corre `main`, executando o IO resultante.
pub fn run(module: &Module) -> Result<(), RunError> {
    let mut funcs = HashMap::new();
    for f in &module.funcs {
        funcs.insert(f.name.clone(), Rc::new(f.clone()));
    }
    let prog = Program { funcs };

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
        Value::Closure { .. } | Value::Builtin { .. } => "função",
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

/// Força CAFs (funções de aridade 0, como `main`) avaliando o corpo.
fn force(prog: &Program, v: Value) -> Result<Value, RunError> {
    match v {
        Value::Closure { def, env, args } if args.len() >= clause_arity(&def) => {
            run_func(prog, &def, &env, args)
        }
        other => Ok(other),
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
        ("+", Int(x), Int(y)) => Ok(Int(x + y)),
        ("-", Int(x), Int(y)) => Ok(Int(x - y)),
        ("*", Int(x), Int(y)) => Ok(Int(x * y)),
        ("mod", Int(x), Int(y)) => Ok(Int(x.rem_euclid(y))),
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
