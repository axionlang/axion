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
    foreigns: HashMap<String, usize>,   // importações FFI: nome C → aridade
}

#[derive(Clone)]
enum Value {
    Int(i64),
    Str(String),
    Bool(bool),
    #[allow(dead_code)] // `()` — ainda tratado nos matches (main :: (), etc.)
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
    /// Um tuplo (ex.: o resultado de `split`).
    Tuple(Vec<Value>),
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
    /// Uma importação FFI (§18) por aplicar (ABI de Int; resolvida por dlsym).
    Foreign {
        name: String,
        arity: usize,
        args: Vec<Value>,
    },
    /// Um endpoint de sessão (§6): o id do seu buffer no scheduler (§11).
    Endpoint(usize),
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
    let foreigns = module
        .foreigns
        .iter()
        .map(|f| (f.name.clone(), f.sig.param_mults().len()))
        .collect();
    Program {
        funcs,
        cons,
        selectors,
        foreigns,
    }
}

/// Compila o módulo para um `Program` e corre `main`, executando o IO resultante.
pub fn run(module: &Module) -> Result<(), RunError> {
    // FFI (§18): carrega as bibliotecas do utilizador para o espaço global de
    // símbolos, para o `dlsym(RTLD_DEFAULT)` de `call_foreign` as encontrar.
    crate::ffi::load_libs(&module.foreign_libs())?;
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
        // 'main :: Int' / 'main :: Bool' — imprime o resultado, tal como o
        // backend nativo, para os dois caminhos concordarem.
        Value::Int(n) => {
            println!("{n}");
            Ok(())
        }
        Value::Bool(b) => {
            println!("{b}");
            Ok(())
        }
        other => Err(format!(
            "'main' devia ser uma acção IO (ou Int), foi {}",
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
        Value::Record { .. } => "registo",
        Value::Endpoint(_) => "endpoint",
        Value::Closure { .. }
        | Value::Builtin { .. }
        | Value::Ctor { .. }
        | Value::Selector { .. }
        | Value::Foreign { .. } => "função",
    }
}

fn builtin_arity(name: &str) -> usize {
    match name {
        "join" | "mapM_" => 2,
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
            // construtor de `data` (nulário constrói já o registo; senão é um Ctor)
            _ => resolve_var(prog, env, name),
        },
        Expr::Var(name, _) => resolve_var(prog, env, name),
        Expr::App(f, x, _) => {
            // `bound <corpo>` (§9/§11): abre o nursery e corre o scheduler
            // cooperativo de sessões em vez da avaliação normal.
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
            if is_builtin_op(op) {
                eval_binop(op, a, b)
            } else {
                // operador infixo de utilizador (§8): `x `f` y` ≡ `f x y`.
                let f = resolve_var(prog, env, op)?;
                apply(prog, apply(prog, f, a)?, b)
            }
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
        // uma lambda vira uma closure de uma só cláusula, capturando o env
        // actual — reutiliza toda a maquinaria de aplicação das funções.
        Expr::Lam(pats, body, sp) => Ok(Value::Closure {
            def: Rc::new(Func {
                name: "<lambda>".to_string(),
                sig: None,
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
        "mapM_" => Ok(Value::Builtin {
            name: "mapM_",
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
                // `mapM_` precisa do `prog` para aplicar `f` a cada elemento
                if name == "mapM_" {
                    run_mapm(prog, &args[0], &args[1])
                } else {
                    run_builtin(name, args)
                }
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
        other => Err(format!(
            "tentou aplicar algo que não é função: {}",
            type_name(&other)
        )),
    }
}

// FFI (§18): resolve o símbolo C por dlsym e chama-o com a ABI de Int (i64).
extern "C" {
    fn dlsym(
        handle: *mut std::ffi::c_void,
        symbol: *const std::ffi::c_char,
    ) -> *mut std::ffi::c_void;
}

fn call_foreign(name: &str, args: &[Value]) -> Result<Value, RunError> {
    let cname = std::ffi::CString::new(name).map_err(|_| "nome FFI inválido".to_string())?;
    let p = unsafe { dlsym(std::ptr::null_mut(), cname.as_ptr()) };
    if p.is_null() {
        return Err(format!("símbolo FFI não encontrado: '{name}'"));
    }
    let mut a = [0i64; 3];
    for (i, v) in args.iter().enumerate() {
        a[i] = match v {
            Value::Int(n) => *n,
            other => {
                return Err(format!(
                    "FFI '{name}': argumento não-Int ({})",
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
                    "FFI '{name}': aridade {n} não suportada no interp (até 3)"
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
        Pat::Con(name, subpats, _) => match v {
            Value::Bool(b) => (name == "True" && *b) || (name == "False" && !*b),
            // construtor: casa se o nome bate e liga os sub-padrões aos campos
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

/// Os operadores infixos EMBUTIDOS (aritmética/comparação de `Int`). Tudo o que
/// não estiver aqui é um operador infixo de utilizador — uma função nomeada
/// aplicada a dois argumentos (`x `f` y` ≡ `f x y`). O conjunto tem de coincidir
/// com o dos backends nativos (`core::is_builtin_op`) para os três concordarem.
fn is_builtin_op(op: &str) -> bool {
    matches!(op, "+" | "-" | "*" | "mod" | "==" | "<" | ">")
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

/// `mapM_ f xs`: aplica a acção IO `f` a cada elemento da lista (Nil/Cons),
/// concatenando os efeitos (o modelo de IO do interp é `Io(String)`).
fn run_mapm(prog: &Program, f: &Value, list: &Value) -> Result<Value, RunError> {
    let mut out = String::new();
    let mut cur = list.clone();
    loop {
        match cur {
            Value::Record { con, fields } if con == "Nil" => {
                let _ = fields;
                break;
            }
            Value::Record { con, fields } if con == "Cons" => {
                let head = fields[0].1.clone();
                let tail = fields[1].1.clone();
                match apply(prog, f.clone(), head)? {
                    Value::Io(s) => out.push_str(&s),
                    Value::Unit => {}
                    other => {
                        return Err(format!(
                            "mapM_: a função devia dar uma acção IO, deu {}",
                            type_name(&other)
                        ))
                    }
                }
                cur = tail;
            }
            other => {
                return Err(format!(
                    "mapM_: esperava uma lista, obteve {}",
                    type_name(&other)
                ))
            }
        }
    }
    Ok(Value::Io(out))
}

fn run_builtin(name: &str, args: Vec<Value>) -> Result<Value, RunError> {
    match (name, args.as_slice()) {
        ("putStrLn", [Value::Str(s)]) => Ok(Value::Io(format!("{s}\n"))),
        ("show", [Value::Int(n)]) => Ok(Value::Str(n.to_string())),
        ("show", [Value::Bool(b)]) => Ok(Value::Str(b.to_string())),
        // split divide num par de metades de leitura partilhada (partilham o
        // valor); join recombina — semântica trivial no interpretador.
        ("split", [v]) => Ok(Value::Tuple(vec![v.clone(), v.clone()])),
        ("join", [a, _b]) => Ok(a.clone()),
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
        Value::Record { .. } | Value::Tuple(_) => RtType::Record,
        Value::Closure { .. }
        | Value::Builtin { .. }
        | Value::Ctor { .. }
        | Value::Selector { .. }
        | Value::Foreign { .. }
        | Value::Endpoint(_) => RtType::Fun,
    })
}

// --- runtime de sessões: scheduler cooperativo (§11) ---
//
// Dá EXECUÇÃO aos programas de `bound`/`spawn`/canais. Segue a §11: as tarefas
// são «continuações defuncionalizadas» — e a continuação de um `do` é, muito
// literalmente, o `Expr` restante (a cadeia de `case` que o desugar produz).
// Um scheduler cooperativo single-thread corre cada tarefa até ela bloquear num
// `recv` de canal vazio (o único ponto de suspensão, §11), e então troca. Sem
// threads nem `Send` — os `Value` (Rc) ficam sempre numa só thread. A ausência
// de deadlock é garantida pelos tipos (AX0302); o scheduler só executa.

/// Cabeça-nome e argumentos de uma aplicação `f a b …` (para reconhecer os ops).
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
    /// buffer de entrada de cada endpoint (mensagens à espera de serem recebidas
    /// pelo dono deste endpoint); enviar em `e` empurra para o buffer do par.
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
    cont: Expr, // o `do`-corpo restante (cadeia de `case`)
    env: Env,
}

enum StepOut {
    Went(Task),    // avançou (uma operação não-bloqueante); continuar a correr
    Blocked(Task), // recv de buffer vazio → suspender e trocar de tarefa
    Done(Value),   // a tarefa terminou com este valor
}

fn ep_id(v: &Value) -> Result<usize, RunError> {
    match v {
        Value::Endpoint(id) => Ok(*id),
        other => Err(format!("esperava um endpoint, obtive {}", type_name(other))),
    }
}

/// Executa uma operação de canal reconhecida (`head args`) no env dado. Devolve
/// `Some(valor)` (o resultado da operação) ou `None` se bloqueia (recv de buffer
/// vazio). Os `spawn` acrescentam tarefas-filho a `spawned`.
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
                _ => return Err("select: rótulo inválido".into()),
            };
            let ep = ep_id(&eval(prog, env, args[1])?)?;
            sched.send(ep, Value::Str(label));
            Some(Value::Endpoint(ep))
        }
        "close" => {
            eval(prog, env, args[0])?; // consome o endpoint
            Some(Value::Unit)
        }
        "cancel" => {
            // §7: descarta o endpoint e avisa o par com `Closed` (o rótulo que o
            // `offer` do par recebe como o ramo de cancelamento — T5).
            let ep = ep_id(&eval(prog, env, args[0])?)?;
            sched.send(ep, Value::Str("Closed".to_string()));
            Some(Value::Unit)
        }
        "offer" => return Err("`offer` tem de ser o escrutínio de um `case`".into()),
        "recv" => {
            let ep = ep_id(&eval(prog, env, args[0])?)?;
            // buffer vazio → `None` (bloqueia); senão o par (valor, endpoint)
            sched
                .recv(ep)
                .map(|v| Value::Tuple(vec![v, Value::Endpoint(ep)]))
        }
        _ => unreachable!("op de sessão desconhecido: {head}"),
    })
}

/// Se `e` é uma operação de sessão aplicada, devolve `(head, args)`.
fn as_session_op(e: &Expr) -> Option<(&str, Vec<&Expr>)> {
    let (head, args) = app_head(e);
    head.filter(|h| is_session_op(h)).map(|h| (h, args))
}

/// Um passo do scheduler sobre uma tarefa: trata um op de sessão à cabeça (seja
/// escrutínio de `case`, seja a cauda do `do`), ou avalia normalmente.
fn step(
    prog: &Program,
    sched: &mut Sched,
    task: Task,
    spawned: &mut Vec<Task>,
) -> Result<StepOut, RunError> {
    // `case offer c of { L1 e1 -> N1 ; … }` (&): recebe o rótulo e despacha para
    // o ramo correspondente. `offer` é o único op com escrutínio multi-braço.
    if let Expr::Case(scrut, arms, _) = &task.cont {
        if let (Some("offer"), oargs) = app_head(scrut) {
            let ep = ep_id(&eval(prog, &task.env, oargs[0])?)?;
            let label = match sched.recv(ep) {
                None => return Ok(StepOut::Blocked(task)), // rótulo ainda não chegou
                Some(Value::Str(l)) => l,
                Some(other) => {
                    return Err(format!(
                        "offer: esperava um rótulo, veio {}",
                        type_name(&other)
                    ))
                }
            };
            // valor etiquetado que carrega o endpoint avançado: `L (Endpoint c)`.
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
            return Err(format!("offer: nenhum ramo trata o rótulo '{label}'"));
        }
    }
    // `case <op> of pat -> resto` → executa, liga `pat`, continua com `resto`.
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
    // op de sessão como cauda do `do` (ex.: `close c` final) → é o valor do bloco.
    if let Some((head, args)) = as_session_op(&task.cont) {
        return Ok(
            match perform_op(prog, sched, spawned, &task.env, head, &args)? {
                Some(val) => StepOut::Done(val),
                None => StepOut::Blocked(task),
            },
        );
    }
    // folha sem op de sessão → avalia normalmente
    Ok(StepOut::Done(eval(prog, &task.env, &task.cont)?))
}

/// Constrói a tarefa-filho para `spawn f`: aplica a closure `f` ao endpoint,
/// mas em vez de a correr até ao fim, devolve o seu corpo como continuação.
fn fork_child(f: Value, arg: Value) -> Result<Task, RunError> {
    match f {
        Value::Closure { def, env, args } if args.is_empty() => {
            let clause = def.clauses.first().ok_or("spawn: closure sem cláusula")?;
            let child = child_env(&env);
            if let Some(p) = clause.pats.first() {
                match_pat(p, &arg, &child);
            }
            match &clause.body {
                Body::Plain(b) => Ok(Task {
                    cont: b.clone(),
                    env: child,
                }),
                _ => Err("spawn: corpo com guardas não suportado".into()),
            }
        }
        other => Err(format!(
            "spawn espera uma função, obteve {}",
            type_name(&other)
        )),
    }
}

/// O scheduler cooperativo: corre a tarefa raiz (do `bound`) e os seus filhos até
/// a raiz terminar. Round-robin; uma varredura sem progresso com tarefas vivas é
/// deadlock (não deve acontecer — os tipos garantem, AX0302).
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
                    return Err("scheduler de sessões: sem progresso (limite)".into());
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
                            return Ok(v); // a raiz terminou → o valor do `bound`
                        }
                        break; // um filho terminou → descarta
                    }
                }
            }
        }
        if !progressed {
            return Err("deadlock no scheduler (não devia ocorrer — tipos garantem)".into());
        }
    }
}
