//! Tree-walking interpreter for the L0/L1 subset — the "run" of the walking
//! skeleton (§17). It is the embryo of the `--dev` fast-path; the native backend
//! (Cranelift/LLVM) is the target of later phases.

use crate::ast::*;
use std::cell::RefCell;
use std::collections::{HashMap, HashSet};
use std::rc::Rc;

type Env = Rc<Scope>;

struct Scope {
    vars: RefCell<HashMap<String, Value>>,
    parent: Option<Env>,
}

/// Table of top-level functions and constructors, resolved by name at runtime.
pub struct Program {
    funcs: HashMap<String, Rc<Func>>,
    cons: HashMap<String, Vec<String>>, // constructor → field names (in order)
    selectors: HashSet<String>,         // field names usable as selectors
    foreigns: HashMap<String, usize>,   // FFI imports: C name → arity
    methods: HashSet<String>,           // typeclass method names (dynamic dispatch)
    con_type: HashMap<String, String>,  // constructor → data type name (for dispatch)
}

#[derive(Clone)]
enum Value {
    Int(i64),
    Str(String),
    Bool(bool),
    #[allow(dead_code)] // `()` — ainda tratado nos matches (main :: (), etc.)
    Unit,
    /// An IO action still to execute (the text to print).
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
    /// A tuple (e.g. the result of `split`).
    Tuple(Vec<Value>),
    /// A record: constructor + fields (in construction order).
    Record {
        con: String,
        fields: Vec<(String, Value)>,
    },
    /// A constructor not yet applied (arity = number of fields).
    Ctor {
        name: String,
        field_names: Vec<String>,
        args: Vec<Value>,
    },
    /// A field selector (`pid`, `status`, …), arity 1.
    Selector {
        field: String,
    },
    /// An FFI import (§18) not yet applied (Int ABI; resolved by dlsym).
    Foreign {
        name: String,
        arity: usize,
        args: Vec<Value>,
    },
    /// A session endpoint (§6): the id of its buffer in the scheduler (§11).
    Endpoint(usize),
    /// An unresolved typeclass method: on receiving the 1st argument, it dispatches
    /// by that argument's type head to the instance implementation.
    Method {
        name: String,
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

/// Builds the top-level table (functions, constructors, selectors) of the module.
fn build_program(module: &Module) -> Program {
    let mut funcs = HashMap::new();
    for f in &module.funcs {
        funcs.insert(f.name.clone(), Rc::new(f.clone()));
    }
    let mut cons = HashMap::new();
    let mut selectors = HashSet::new();
    let mut con_type = HashMap::new();
    for d in &module.datas {
        for c in &d.cons {
            con_type.insert(c.name.clone(), d.name.clone());
            // positional fields get synthetic names "_0", "_1", …
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
    let foreigns = module
        .foreigns
        .iter()
        .map(|f| (f.name.clone(), f.sig.param_mults().len()))
        .collect();
    // method names of all classes (what triggers dynamic dispatch)
    let methods = module
        .classes
        .iter()
        .flat_map(|c| c.methods.iter().map(|(m, _)| m.clone()))
        .collect();
    Program {
        funcs,
        cons,
        selectors,
        methods,
        con_type,
        foreigns,
    }
}

/// Compiles the module into a `Program` and runs `main`, executing the resulting IO.
pub fn run(module: &Module) -> Result<(), RunError> {
    // FFI (§18): loads the user's libraries into the global symbol space,
    // so `call_foreign`'s `dlsym(RTLD_DEFAULT)` finds them.
    crate::ffi::load_libs(&module.foreign_libs())?;
    let prog = build_program(module);
    let main = prog
        .funcs
        .get("main")
        .ok_or_else(|| "there is no 'main' to run".to_string())?
        .clone();
    let base = empty_env();
    let v = run_func(&prog, &main, &base, Vec::new())?;
    match v {
        Value::Io(s) => {
            print!("{s}");
            Ok(())
        }
        Value::Unit => Ok(()),
        // 'main :: Int' / 'main :: Bool' — prints the result, just like the
        // native backend, so the two paths agree.
        Value::Int(n) => {
            println!("{n}");
            Ok(())
        }
        Value::Bool(b) => {
            println!("{b}");
            Ok(())
        }
        other => Err(format!(
            "'main' should be an IO action (or Int), was {}",
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
        Value::Tuple(_) => "tuplo",
        Value::Record { .. } => "record",
        Value::Endpoint(_) => "endpoint",
        Value::Closure { .. }
        | Value::Builtin { .. }
        | Value::Ctor { .. }
        | Value::Selector { .. }
        | Value::Method { .. }
        | Value::Foreign { .. } => "function",
    }
}

/// Type head of a value, to dispatch a typeclass method. Records
/// registos mapeiam-se ao nome do seu tipo de dados (`Some 42` → "Maybe").
fn value_type_head(prog: &Program, v: &Value) -> Option<String> {
    match v {
        Value::Int(_) => Some("Int".into()),
        Value::Bool(_) => Some("Bool".into()),
        Value::Str(_) => Some("String".into()),
        Value::Record { con, .. } => prog.con_type.get(con).cloned(),
        _ => None,
    }
}

fn builtin_arity(name: &str) -> usize {
    match name {
        "join" => 2,
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
        Expr::Con(name, _) => match name.as_str() {
            "True" => Ok(Value::Bool(true)),
            "False" => Ok(Value::Bool(false)),
            // `data` constructor (nullary already builds the record; else a Ctor)
            _ => resolve_var(prog, env, name),
        },
        Expr::Var(name, _) => resolve_var(prog, env, name),
        Expr::App(f, x, _) => {
            // `bound <body>` (§9/§11): opens the nursery and runs the scheduler
            // cooperative session scheduler instead of normal evaluation.
            if let (Some("bound"), args) = app_head(e) {
                if let Some(body) = args.last() {
                    return run_session(prog, body, env);
                }
            }
            let callee = eval(prog, env, f)?;
            let arg = eval(prog, env, x)?;
            apply(prog, callee, arg)
        }
        Expr::BinOp(op, l, r, _) => {
            let a = eval(prog, env, l)?;
            let b = eval(prog, env, r)?;
            match op.as_str() {
                // polymorphic `++`: strings concatenate; lists (or anything
                // else) delegate to the prelude's `append` — a single definition.
                "++" => match (a, b) {
                    (Value::Str(x), Value::Str(y)) => Ok(Value::Str(x + &y)),
                    (a, b) => {
                        let f = resolve_var(prog, env, "append")?;
                        apply(prog, apply(prog, f, a)?, b)
                    }
                },
                o if is_builtin_op(o) => eval_binop(o, a, b),
                // operador infixo de utilizador (§8): `x `f` y` ≡ `f x y`.
                _ => {
                    let f = resolve_var(prog, env, op)?;
                    apply(prog, apply(prog, f, a)?, b)
                }
            }
        }
        Expr::If(c, t, el, _) => match eval(prog, env, c)? {
            Value::Bool(true) => eval(prog, env, t),
            Value::Bool(false) => eval(prog, env, el),
            other => Err(format!(
                "'if' condition should be Bool, was {}",
                type_name(&other)
            )),
        },
        Expr::Tuple(es, _) => {
            let mut vals = Vec::with_capacity(es.len());
            for e in es {
                vals.push(eval(prog, env, e)?);
            }
            Ok(Value::Tuple(vals))
        }
        Expr::Let(binds, body, _) => {
            let child = child_env(env);
            bind_funcs(binds, &child);
            eval(prog, &child, body)
        }
        Expr::Case(scrut, arms, _) => {
            let v = eval(prog, env, scrut)?;
            // IO sequencing: a `do` desugars to `case action of _ -> rest`.
            // If the scrutinee is an IO action, its output PRECEDES the rest's
            // (otherwise it would be lost — the `case` value is only the arm's). The
            // interp's IO model is accumulated `Io(String)`; native prints immediately.
            let io_prefix = match &v {
                Value::Io(s) => Some(s.clone()),
                _ => None,
            };
            for (pat, body) in arms {
                let child = child_env(env);
                if match_pat(pat, &v, &child) {
                    let r = eval(prog, &child, body)?;
                    return Ok(match (io_prefix, r) {
                        (Some(pre), Value::Io(rest)) => Value::Io(pre + &rest),
                        (Some(pre), Value::Unit) => Value::Io(pre),
                        (_, r) => r,
                    });
                }
            }
            Err("no 'case' arm matched".to_string())
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
                    "record update over a {} (not a record)",
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
        // a lambda becomes a one-clause closure, capturing the current
        // env — reusing all the function-application machinery.
        Expr::Lam(pats, body, sp) => Ok(Value::Closure {
            def: Rc::new(Func {
                name: "<lambda>".to_string(),
                sig: None,
                constraints: Vec::new(),
                clauses: vec![Clause {
                    pats: pats.clone(),
                    body: Body::Plain((**body).clone()),
                    wher: Vec::new(),
                    span: *sp,
                }],
                span: *sp,
            }),
            env: env.clone(),
            args: Vec::new(),
        }),
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
    if prog.methods.contains(name) {
        return Ok(Value::Method {
            name: name.to_string(),
        });
    }
    if let Some(&arity) = prog.foreigns.get(name) {
        return Ok(Value::Foreign {
            name: name.to_string(),
            arity,
            args: Vec::new(),
        });
    }
    match name {
        "otherwise" => Ok(Value::Bool(true)),
        "putStrLn" => Ok(Value::Builtin {
            name: "putStrLn",
            args: Vec::new(),
        }),
        "putStr" => Ok(Value::Builtin {
            name: "putStr",
            args: Vec::new(),
        }),
        "show" => Ok(Value::Builtin {
            name: "show",
            args: Vec::new(),
        }),
        "split" => Ok(Value::Builtin {
            name: "split",
            args: Vec::new(),
        }),
        "join" => Ok(Value::Builtin {
            name: "join",
            args: Vec::new(),
        }),
        _ => Err(format!("name not found at runtime: '{name}'")),
    }
}

/// Forces CAFs (arity-0 functions, like `main`, and nullary constructors)
/// evaluating the body / building the record.
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
                .ok_or_else(|| format!("record without the field '{field}'")),
            other => Err(format!(
                "selector '.{field}' applied to a {} (not a record)",
                type_name(&other)
            )),
        },
        Value::Foreign {
            name,
            arity,
            mut args,
        } => {
            args.push(arg);
            if args.len() >= arity {
                call_foreign(&name, &args)
            } else {
                Ok(Value::Foreign { name, arity, args })
            }
        }
        // Typeclass method: dispatches by the 1st argument's type head to
        // the instance implementation (`eq` over an Int → `eq$Int`), and applies.
        Value::Method { name } => {
            let head = value_type_head(prog, &arg).ok_or_else(|| {
                format!("no instance for method '{name}' over a {}", type_name(&arg))
            })?;
            let impl_fn = crate::ast::method_impl_name(&name, &head);
            let def = prog
                .funcs
                .get(&impl_fn)
                .ok_or_else(|| format!("no instance of method '{name}' for type {head}"))?;
            let callee = force(
                prog,
                Value::Closure {
                    def: def.clone(),
                    env: empty_env(),
                    args: Vec::new(),
                },
            )?;
            apply(prog, callee, arg)
        }
        other => Err(format!(
            "tried to apply something that is not a function: {}",
            type_name(&other)
        )),
    }
}

// FFI (§18): resolves the C symbol via dlsym and calls it with the Int ABI (i64).
extern "C" {
    fn dlsym(
        handle: *mut std::ffi::c_void,
        symbol: *const std::ffi::c_char,
    ) -> *mut std::ffi::c_void;
}

fn call_foreign(name: &str, args: &[Value]) -> Result<Value, RunError> {
    let cname = std::ffi::CString::new(name).map_err(|_| "invalid FFI name".to_string())?;
    let p = unsafe { dlsym(std::ptr::null_mut(), cname.as_ptr()) };
    if p.is_null() {
        return Err(format!("FFI symbol not found: '{name}'"));
    }
    let mut a = [0i64; 3];
    for (i, v) in args.iter().enumerate() {
        a[i] = match v {
            Value::Int(n) => *n,
            other => {
                return Err(format!(
                    "FFI '{name}': non-Int argument ({})",
                    type_name(other)
                ))
            }
        };
    }
    type P = *mut std::ffi::c_void;
    let r = unsafe {
        match args.len() {
            0 => std::mem::transmute::<P, extern "C" fn() -> i64>(p)(),
            1 => std::mem::transmute::<P, extern "C" fn(i64) -> i64>(p)(a[0]),
            2 => std::mem::transmute::<P, extern "C" fn(i64, i64) -> i64>(p)(a[0], a[1]),
            3 => std::mem::transmute::<P, extern "C" fn(i64, i64, i64) -> i64>(p)(a[0], a[1], a[2]),
            n => {
                return Err(format!(
                    "FFI '{name}': arity {n} not supported in the interp (up to 3)"
                ))
            }
        }
    };
    Ok(Value::Int(r))
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
    Err(format!("no clause of '{}' matched the arguments", def.name))
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
            Err("no guard was true".to_string())
        }
    }
}

/// Inserts local functions (`where`/`let`) into the env, capturing that same env
/// (for recursion and mutual recursion).
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
        Pat::Con(name, subpats, _) => match v {
            Value::Bool(b) => (name == "True" && *b) || (name == "False" && !*b),
            // constructor: matches if the name matches and binds sub-patterns to fields
            Value::Record { con, fields } => {
                con == name
                    && subpats.len() <= fields.len()
                    && subpats
                        .iter()
                        .zip(fields)
                        .all(|(p, (_, fv))| match_pat(p, fv, env))
            }
            _ => false,
        },
        Pat::Tuple(ps, _) => match v {
            Value::Tuple(vs) if vs.len() == ps.len() => {
                ps.iter().zip(vs).all(|(p, v)| match_pat(p, v, env))
            }
            _ => false,
        },
    }
}

/// The BUILT-IN infix operators (`Int` arithmetic/comparison). Anything
/// not here is a user infix operator — a named function
/// aplicada a dois argumentos (`x `f` y` ≡ `f x y`). O conjunto tem de coincidir
/// with that of the native backends (`core::is_builtin_op`) so the three agree.
fn is_builtin_op(op: &str) -> bool {
    matches!(op, "+" | "-" | "*" | "mod" | "==" | "<" | ">")
}

fn eval_binop(op: &str, a: Value, b: Value) -> Result<Value, RunError> {
    use Value::*;
    match (op, a, b) {
        // Int is fixed-width (§ Listing 1.4): arithmetic wraps,
        // a total semantics that avoids overflow panics.
        ("+", Int(x), Int(y)) => Ok(Int(x.wrapping_add(y))),
        ("-", Int(x), Int(y)) => Ok(Int(x.wrapping_sub(y))),
        ("*", Int(x), Int(y)) => Ok(Int(x.wrapping_mul(y))),
        ("mod", Int(x), Int(y)) if y != 0 => Ok(Int(x.rem_euclid(y))),
        ("mod", Int(_), Int(_)) => Err("mod by zero".to_string()),
        ("==", Int(x), Int(y)) => Ok(Bool(x == y)),
        ("<", Int(x), Int(y)) => Ok(Bool(x < y)),
        (">", Int(x), Int(y)) => Ok(Bool(x > y)),
        (op, x, y) => Err(format!(
            "operator '{op}' does not apply to {} and {}",
            type_name(&x),
            type_name(&y)
        )),
    }
}

fn run_builtin(name: &str, args: Vec<Value>) -> Result<Value, RunError> {
    match (name, args.as_slice()) {
        ("putStrLn", [Value::Str(s)]) => Ok(Value::Io(format!("{s}\n"))),
        ("putStr", [Value::Str(s)]) => Ok(Value::Io(s.clone())),
        ("show", [Value::Int(n)]) => Ok(Value::Str(n.to_string())),
        ("show", [Value::Bool(b)]) => Ok(Value::Str(b.to_string())),
        // split divides into a pair of shared-read halves (they share the
        // value); join recombines — trivial semantics in the interpreter.
        ("split", [v]) => Ok(Value::Tuple(vec![v.clone(), v.clone()])),
        ("join", [a, _b]) => Ok(a.clone()),
        (name, _) => Err(format!("builtin '{name}' received invalid arguments")),
    }
}

/// Runtime type of a value — used by the preservation property tests.
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

/// Evaluates the top-level definition `name` (arity 0) and returns the runtime type
/// of the value. Entry point for the progress/preservation property tests.
#[cfg(test)]
pub(crate) fn eval_binding(module: &Module, name: &str) -> Result<RtType, RunError> {
    let prog = build_program(module);
    let def = prog
        .funcs
        .get(name)
        .ok_or_else(|| format!("no definition '{name}'"))?
        .clone();
    let v = run_func(&prog, &def, &empty_env(), Vec::new())?;
    Ok(match v {
        Value::Int(_) => RtType::Int,
        Value::Bool(_) => RtType::Bool,
        Value::Str(_) => RtType::Str,
        Value::Unit => RtType::Unit,
        Value::Io(_) => RtType::Io,
        Value::Record { .. } | Value::Tuple(_) => RtType::Record,
        Value::Closure { .. }
        | Value::Builtin { .. }
        | Value::Ctor { .. }
        | Value::Selector { .. }
        | Value::Method { .. }
        | Value::Foreign { .. }
        | Value::Endpoint(_) => RtType::Fun,
    })
}

// --- session runtime: cooperative scheduler (§11) ---
//
// Gives EXECUTION to `bound`/`spawn`/channel programs. Follows §11: tasks
// are "defunctionalized continuations" — and the continuation of a `do` is, quite
// literally, the remaining `Expr` (the chain of `case` the desugar produces).
// A single-thread cooperative scheduler runs each task until it blocks on a
// `recv` on an empty channel (the only suspension point, §11), then switches. No
// threads nor `Send` — the `Value`s (Rc) always stay on a single thread. The
// absence of deadlock is guaranteed by types (AX0302); the scheduler only executes.

/// Head name and arguments of an application `f a b …` (to recognize the ops).
fn app_head(e: &Expr) -> (Option<&str>, Vec<&Expr>) {
    let mut args = Vec::new();
    let mut cur = e;
    while let Expr::App(f, a, _) = cur {
        args.push(a.as_ref());
        cur = f;
    }
    args.reverse();
    match cur {
        Expr::Var(n, _) | Expr::Con(n, _) => (Some(n.as_str()), args),
        _ => (None, args),
    }
}

fn is_session_op(name: &str) -> bool {
    matches!(
        name,
        "newChannel" | "spawn" | "send" | "recv" | "close" | "select" | "offer" | "cancel"
    )
}

struct Sched {
    /// input buffer of each endpoint (messages waiting to be received
    /// by this endpoint's owner); sending on `e` pushes to the peer's buffer.
    bufs: Vec<std::collections::VecDeque<Value>>,
    peer: Vec<usize>,
}

impl Sched {
    fn new_channel(&mut self) -> (usize, usize) {
        let a = self.bufs.len();
        self.bufs.push(std::collections::VecDeque::new());
        let b = self.bufs.len();
        self.bufs.push(std::collections::VecDeque::new());
        self.peer.push(b);
        self.peer.push(a);
        (a, b)
    }
    fn send(&mut self, ep: usize, v: Value) {
        let p = self.peer[ep];
        self.bufs[p].push_back(v);
    }
    fn recv(&mut self, ep: usize) -> Option<Value> {
        self.bufs[ep].pop_front()
    }
}

struct Task {
    cont: Expr, // the remaining `do`-body (chain of `case`)
    env: Env,
}

enum StepOut {
    Went(Task),    // advanced (a non-blocking operation); keep running
    Blocked(Task), // recv on an empty buffer → suspend and switch tasks
    Done(Value),   // the task finished with this value
}

fn ep_id(v: &Value) -> Result<usize, RunError> {
    match v {
        Value::Endpoint(id) => Ok(*id),
        other => Err(format!("expected an endpoint, got {}", type_name(other))),
    }
}

/// Executes a recognized channel operation (`head args`) in the given env. Returns
/// `Some(value)` (the operation's result) or `None` if it blocks (recv on an empty
/// buffer). `spawn`s append child tasks to `spawned`.
fn perform_op(
    prog: &Program,
    sched: &mut Sched,
    spawned: &mut Vec<Task>,
    env: &Env,
    head: &str,
    args: &[&Expr],
) -> Result<Option<Value>, RunError> {
    Ok(match head {
        "newChannel" => {
            let (a, b) = sched.new_channel();
            Some(Value::Tuple(vec![Value::Endpoint(a), Value::Endpoint(b)]))
        }
        "spawn" => {
            let f = eval(prog, env, args[0])?;
            let (c, d) = sched.new_channel();
            spawned.push(fork_child(f, Value::Endpoint(d))?);
            Some(Value::Endpoint(c))
        }
        "send" => {
            let ep = ep_id(&eval(prog, env, args[0])?)?;
            let v = eval(prog, env, args[1])?;
            sched.send(ep, v);
            Some(Value::Endpoint(ep))
        }
        "select" => {
            let label = match args[0] {
                Expr::Con(l, _) | Expr::Var(l, _) => l.clone(),
                _ => return Err("select: invalid label".into()),
            };
            let ep = ep_id(&eval(prog, env, args[1])?)?;
            sched.send(ep, Value::Str(label));
            Some(Value::Endpoint(ep))
        }
        "close" => {
            eval(prog, env, args[0])?; // consumes the endpoint
            Some(Value::Unit)
        }
        "cancel" => {
            // §7: discards the endpoint and warns the peer with `Closed` (the label
            // the peer's `offer` receives as the cancellation branch — T5).
            let ep = ep_id(&eval(prog, env, args[0])?)?;
            sched.send(ep, Value::Str("Closed".to_string()));
            Some(Value::Unit)
        }
        "offer" => return Err("`offer` must be the scrutinee of a `case`".into()),
        "recv" => {
            let ep = ep_id(&eval(prog, env, args[0])?)?;
            // empty buffer → `None` (blocks); otherwise the pair (value, endpoint)
            sched
                .recv(ep)
                .map(|v| Value::Tuple(vec![v, Value::Endpoint(ep)]))
        }
        _ => unreachable!("unknown session op: {head}"),
    })
}

/// If `e` is an applied session operation, returns `(head, args)`.
fn as_session_op(e: &Expr) -> Option<(&str, Vec<&Expr>)> {
    let (head, args) = app_head(e);
    head.filter(|h| is_session_op(h)).map(|h| (h, args))
}

/// A scheduler step over a task: handles a session op at the head (whether
/// a `case` scrutinee or the tail of the `do`), or evaluates normally.
fn step(
    prog: &Program,
    sched: &mut Sched,
    task: Task,
    spawned: &mut Vec<Task>,
) -> Result<StepOut, RunError> {
    // `case offer c of { L1 e1 -> N1 ; … }` (&): receives the label and dispatches to
    // the corresponding branch. `offer` is the only op with a multi-arm scrutinee.
    if let Expr::Case(scrut, arms, _) = &task.cont {
        if let (Some("offer"), oargs) = app_head(scrut) {
            let ep = ep_id(&eval(prog, &task.env, oargs[0])?)?;
            let label = match sched.recv(ep) {
                None => return Ok(StepOut::Blocked(task)), // label not arrived yet
                Some(Value::Str(l)) => l,
                Some(other) => {
                    return Err(format!(
                        "offer: expected a label, got {}",
                        type_name(&other)
                    ))
                }
            };
            // tagged value carrying the advanced endpoint: `L (Endpoint c)`.
            let tagged = Value::Record {
                con: label.clone(),
                fields: vec![("_0".to_string(), Value::Endpoint(ep))],
            };
            for (pat, body) in arms {
                let child = child_env(&task.env);
                if match_pat(pat, &tagged, &child) {
                    return Ok(StepOut::Went(Task {
                        cont: body.clone(),
                        env: child,
                    }));
                }
            }
            return Err(format!("offer: no branch handles the label '{label}'"));
        }
    }
    // `case <op> of pat -> rest` → runs, binds `pat`, continues with `rest`.
    if let Expr::Case(scrut, arms, _) = &task.cont {
        if arms.len() == 1 {
            if let Some((head, args)) = as_session_op(scrut) {
                let (pat, rest) = &arms[0];
                return Ok(
                    match perform_op(prog, sched, spawned, &task.env, head, &args)? {
                        Some(val) => {
                            let child = child_env(&task.env);
                            match_pat(pat, &val, &child);
                            StepOut::Went(Task {
                                cont: rest.clone(),
                                env: child,
                            })
                        }
                        None => StepOut::Blocked(task),
                    },
                );
            }
        }
    }
    // session op as the tail of the `do` (e.g. final `close c`) → it is the block's value.
    if let Some((head, args)) = as_session_op(&task.cont) {
        return Ok(
            match perform_op(prog, sched, spawned, &task.env, head, &args)? {
                Some(val) => StepOut::Done(val),
                None => StepOut::Blocked(task),
            },
        );
    }
    // leaf without a session op → evaluates normally
    Ok(StepOut::Done(eval(prog, &task.env, &task.cont)?))
}

/// Builds the child task for `spawn f`: applies the closure `f` to the endpoint,
/// but instead of running it to the end, returns its body as a continuation.
fn fork_child(f: Value, arg: Value) -> Result<Task, RunError> {
    match f {
        Value::Closure { def, env, args } if args.is_empty() => {
            let clause = def.clauses.first().ok_or("spawn: closure with no clause")?;
            let child = child_env(&env);
            if let Some(p) = clause.pats.first() {
                match_pat(p, &arg, &child);
            }
            match &clause.body {
                Body::Plain(b) => Ok(Task {
                    cont: b.clone(),
                    env: child,
                }),
                _ => Err("spawn: guarded body not supported".into()),
            }
        }
        other => Err(format!(
            "spawn expects a function, got {}",
            type_name(&other)
        )),
    }
}

/// The cooperative scheduler: runs the root task (of the `bound`) and its children until
/// the root finishes. Round-robin; a sweep with no progress and live tasks is
/// deadlock (should not happen — the types guarantee it, AX0302).
fn run_session(prog: &Program, body: &Expr, env: &Env) -> Result<Value, RunError> {
    let mut sched = Sched {
        bufs: Vec::new(),
        peer: Vec::new(),
    };
    let mut tasks: Vec<Option<Task>> = vec![Some(Task {
        cont: body.clone(),
        env: child_env(env),
    })];
    let mut budget: u64 = 5_000_000;
    loop {
        let mut progressed = false;
        let n = tasks.len();
        for i in 0..n {
            loop {
                budget -= 1;
                if budget == 0 {
                    return Err("session scheduler: no progress (limit)".into());
                }
                let Some(task) = tasks[i].take() else { break };
                let mut spawned = Vec::new();
                let out = step(prog, &mut sched, task, &mut spawned);
                for t in spawned {
                    tasks.push(Some(t));
                }
                match out? {
                    StepOut::Went(t) => {
                        tasks[i] = Some(t);
                        progressed = true;
                    }
                    StepOut::Blocked(t) => {
                        tasks[i] = Some(t);
                        break;
                    }
                    StepOut::Done(v) => {
                        progressed = true;
                        if i == 0 {
                            return Ok(v); // the root finished → the `bound` value
                        }
                        break; // um filho terminou → descarta
                    }
                }
            }
        }
        if !progressed {
            return Err(
                "deadlock in the scheduler (should not happen — types guarantee it)".into(),
            );
        }
    }
}
