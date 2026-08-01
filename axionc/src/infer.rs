//! Type inference — Hindley-Milner (Algorithm W) for the L0/L1 subset.
//!
//! Runs alongside the linearity analysis (`check.rs`): linearity handles
//! *how many times* a resource is used (multiplicities); inference handles
//! *what type* it has. Emits `AX0200` (type mismatch) and `AX0201`
//! (infinite type / occurs-check).
//!
//! Supports: literals, functions (multi-clause, pattern matching), application,
//! `let`/`where` with generalization, `if`, `case`, records (construction,
//! update, selectors) and the builtins. The arrow multiplicities are
//! ignored here (they are `check.rs`'s job).

use crate::ast::*;
use crate::diag::{Diagnostic, Diagnostics};
use std::collections::{HashMap, HashSet};

#[derive(Clone, Debug)]
enum Ty {
    Var(u32),
    Con(String, Vec<Ty>),
    Fun(Box<Ty>, Box<Ty>),
    Tuple(Vec<Ty>),
}

#[derive(Clone)]
struct Scheme {
    vars: Vec<u32>,
    ty: Ty,
}

type Env = HashMap<String, Scheme>;

struct Infer<'a> {
    subst: HashMap<u32, Ty>,
    counter: u32,
    diags: &'a mut Diagnostics,
    /// constructor → (record type, typed fields)
    cons: HashMap<String, (String, Vec<(String, Ty)>)>,
    /// record type → typed fields (for update)
    records: HashMap<String, Vec<(String, Ty)>>,
    /// typeclass method → (class, dispatch parameter index). The index
    /// is the position of the 1st parameter whose type is the class variable.
    method_meta: HashMap<String, (String, Option<usize>)>,
    /// instance obligations collected at method uses, discharged at the end.
    obligations: Vec<Obl>,
    /// uses of constrained functions, for monomorphization.
    spec_obligations: Vec<SpecObl>,
    /// constrained function → (constraint var, dispatch param index).
    constrained_meta: HashMap<String, (String, Option<usize>)>,
    /// functions that reference an unspecializable constrained function (constraint
    /// var not a direct parameter) — they cannot be specialized.
    refs_unspec: HashSet<String>,
    /// classes with a declared constraint in the scope of the function being inferred.
    cur_constraints: Vec<String>,
    /// name of the function being inferred (key of the resolutions, with the span).
    cur_fn: String,
}

/// An obligation `class C over type T`, collected at a method use and
/// discharged at the end (with the substitution resolved): T concrete → there must be
/// an instance; T variable → must be covered by a constraint in scope.
struct Obl {
    class: String,
    method: String,
    ty: Ty,
    span: Span,
    scope: Vec<String>,
    /// function where the use occurs — part of the resolution key, because the spans
    /// (byte offsets) of the prelude and the user file collide.
    func: String,
}

/// A use of a CONSTRAINED FUNCTION (`f :: C a => …`) — collected for
/// monomorphization: if the constraint var resolves to a concrete type at the
/// call-site, `f` is specialized to that type.
struct SpecObl {
    target: String, // the constrained function called
    ty: Ty,         // the type of the constraint var at this use
    span: Span,
    func: String, // function where the use occurs (caller)
}

/// The inference result for monomorphization: the direct rewrites
/// (`(function, span) → name`) and the plan of specialized functions to materialize.
pub struct Mono {
    pub resolutions: HashMap<(String, Span), String>,
    pub specs: Vec<SpecPlan>,
}

/// Instruction to clone `src` into a monomorphic function `name`, substituting the
/// the constraint var `tyvar` by the type `ty_head` in the signature, and rewriting the
/// internal uses (span → direct name: methods→`m$T`, self-recursion→`name`).
pub struct SpecPlan {
    pub src: String,
    pub name: String,
    pub tyvar: String,
    pub ty_head: String,
    pub rewrites: HashMap<Span, String>,
}

/// Entry point: infers and checks the module's types. Returns the monomorphic
/// method resolutions (`(function, use span) → impl name`), so that
/// monomorphization rewrites the uses as direct calls. The
/// key includes the function because the prelude's and the user's spans collide.
pub fn infer(module: &Module, diags: &mut Diagnostics) -> Mono {
    let mut inf = Infer {
        subst: HashMap::new(),
        counter: 0,
        diags,
        cons: HashMap::new(),
        records: HashMap::new(),
        method_meta: HashMap::new(),
        obligations: Vec::new(),
        spec_obligations: Vec::new(),
        constrained_meta: HashMap::new(),
        refs_unspec: HashSet::new(),
        cur_constraints: Vec::new(),
        cur_fn: String::new(),
    };
    let mut env: Env = inf.base_env();

    // types of constructors and selectors from the `data` declarations. A
    // vars map SHARED per decl links the type parameters (`a` in
    // `data List a`) to the same `Ty::Var` in the result (`List a`) and in the fields,
    // e o esquema generaliza-os (`Cons :: forall a. a -> List a -> List a`).
    for d in &module.datas {
        let mut vars: HashMap<String, u32> = HashMap::new();
        let mut next = 2_000_000u32; // band of type parameters
        let param_args: Vec<Ty> = d
            .params
            .iter()
            .map(|p| ast_ty(&Type::Var(p.clone()), &mut vars, &mut next))
            .collect();
        let result = Ty::Con(d.name.clone(), param_args);
        for c in &d.cons {
            let fields: Vec<(String, Ty)> = c
                .fields
                .iter()
                .enumerate()
                .map(|(i, f)| {
                    let name = if f.name.is_empty() {
                        format!("_{i}")
                    } else {
                        f.name.clone()
                    };
                    (name, ast_ty(&f.ty, &mut vars, &mut next))
                })
                .collect();

            // constructor: field1 -> ... -> T params, quantified over the vars
            let mut cty = result.clone();
            for (_, ft) in fields.iter().rev() {
                cty = Ty::Fun(Box::new(ft.clone()), Box::new(cty));
            }
            let mut gvars = Vec::new();
            free_ty_vars(&cty, &mut gvars);
            env.insert(
                c.name.clone(),
                Scheme {
                    vars: gvars,
                    ty: cty,
                },
            );

            // selectores: T params -> tipoDoCampo (quantificado)
            for (fname, ft) in &fields {
                if !fname.starts_with('_') {
                    let sty = Ty::Fun(Box::new(result.clone()), Box::new(ft.clone()));
                    let mut svars = Vec::new();
                    free_ty_vars(&sty, &mut svars);
                    env.insert(
                        fname.clone(),
                        Scheme {
                            vars: svars,
                            ty: sty,
                        },
                    );
                }
            }
            inf.cons
                .insert(c.name.clone(), (d.name.clone(), fields.clone()));
            inf.records.insert(d.name.clone(), fields);
        }
    }

    // typeclass methods: each method is a polymorphic function whose scheme is
    // its signature generalized over the class variable (`eq :: forall a.
    // a -> a -> Bool`). Dispatch to the concrete instance is dynamic (interp);
    // here the method types like any polymorphic function (the
    // `Eq a =>` constraints are parsed and used for discharge).
    for class in &module.classes {
        for (m, ty) in &class.methods {
            let scheme = inf.scheme_of_sig(ty);
            env.insert(m.clone(), scheme);
            // dispatch parameter index = 1st whose type is the class var
            let idx = ty
                .param_types()
                .iter()
                .position(|p| matches!(p, Type::Var(v) if *v == class.tyvar));
            inf.method_meta.insert(m.clone(), (class.name.clone(), idx));
        }
    }
    // built-in classes, dispatching on the first operand (idx 0):
    // `Num` (`+ - *`) and `Ord` (`== < >`). The class name `Ord` is distinct
    // from a user's `Eq` (whose methods are identifiers like `eq`, not these
    // operators), so there is no collision — the operator names never clash
    // with user method names.
    for op in ["+", "-", "*"] {
        inf.method_meta
            .insert(op.to_string(), ("Num".to_string(), Some(0)));
    }
    for op in ["==", "<", ">"] {
        inf.method_meta
            .insert(op.to_string(), ("Ord".to_string(), Some(0)));
    }

    // schemes of the top-level functions: from the signature, or a fresh monotype
    let mut placeholders: HashMap<String, Ty> = HashMap::new();
    // FFI imports (§18): typed by their declared signature
    for fo in &module.foreigns {
        let scheme = inf.scheme_of_sig(&fo.sig);
        env.insert(fo.name.clone(), scheme);
    }
    for f in &module.funcs {
        match &f.sig {
            Some(sig) => {
                let scheme = inf.scheme_of_sig(sig);
                env.insert(f.name.clone(), scheme);
            }
            None => {
                let v = inf.fresh();
                placeholders.insert(f.name.clone(), v.clone());
                env.insert(
                    f.name.clone(),
                    Scheme {
                        vars: vec![],
                        ty: v,
                    },
                );
            }
        }
    }

    // metadata of the constrained functions: constraint var and
    // index of the 1st parameter whose type is that var (the specialization "dispatch").
    for f in &module.funcs {
        if let Some((_, cvar)) = f.constraints.first() {
            let idx = f.sig.as_ref().and_then(|s| {
                s.param_types()
                    .iter()
                    .position(|p| matches!(p, Type::Var(v) if v == cvar))
            });
            inf.constrained_meta
                .insert(f.name.clone(), (cvar.clone(), idx));
        }
    }

    // checks each function against its type (in checking mode when there is a
    // signature: parameters inherit the declared types before the body)
    for f in &module.funcs {
        let declared = env.get(&f.name).cloned().map(|s| inf.instantiate(&s));
        // Checking mode (parameters inherit the declared types) ONLY when there is a
        // signature. Without a signature, `declared` is a `Var` placeholder that
        // `peel_fun` cannot split into arrows — infer freely and unify the
        // result with the placeholder (this ties monomorphic recursion and is what
        // instance methods, without a signature, need).
        let expected = if f.sig.is_some() {
            declared.as_ref()
        } else {
            None
        };
        // constraints in scope of this function (to discharge polymorphic uses)
        inf.cur_constraints = f.constraints.iter().map(|(c, _)| c.clone()).collect();
        inf.cur_fn = f.name.clone();
        let inferred = inf.infer_func(&env, f, expected);
        if let Some(d) = &declared {
            inf.unify(&inferred, d, f.span);
        }
    }
    let mono = inf.discharge_obligations(module);
    let _ = placeholders;
    mono
}

/// Built-in overloaded operators — arithmetic `+ - *` (`Num`, `a -> a -> a`)
/// and comparisons `== < >` (`Ord`, `a -> a -> Bool`), both over `Int` and
/// `Float`. At each use inference resolves `a`, and the AST rewrite
/// (`main::resolve_methods`) leaves the `Int` operator as-is and rewrites the
/// `Float` one to its dotted form (`+` → `+.`, `<` → `<.`), which the backends
/// already lower. (`mod` and `/` stay monomorphic: `Int` has no `/`.)
pub fn is_builtin_op_method(op: &str) -> bool {
    matches!(op, "+" | "-" | "*" | "==" | "<" | ">")
}

/// The dotted (`Float`) form of a built-in overloaded operator — the rewrite
/// target when a use resolves to `Float`.
pub fn builtin_op_float(op: &str) -> &'static str {
    match op {
        "+" => "+.",
        "-" => "-.",
        "*" => "*.",
        "==" => "==.",
        "<" => "<.",
        ">" => ">.",
        _ => unreachable!("not a built-in overloaded operator: {op}"),
    }
}

/// The `idx`-th parameter type of an arrow chain (`a -> b -> c` @ 1 → b).
fn nth_param(ty: &Ty, idx: usize) -> Option<Ty> {
    let mut cur = ty;
    for _ in 0..idx {
        match cur {
            Ty::Fun(_, b) => cur = b,
            _ => return None,
        }
    }
    match cur {
        Ty::Fun(a, _) => Some((**a).clone()),
        _ => None,
    }
}

/// The fixed-width integers (§4) collapse to `Int` in this type system,
/// simplified (arithmetic is all `Int`); e.g. `U8`, `U32` → `Int`.
fn normalize_num(n: &str) -> String {
    match n {
        "U8" | "U16" | "U32" | "U64" | "I8" | "I16" | "I32" | "I64" | "Word" | "Byte" => {
            "Int".to_string()
        }
        _ => n.to_string(),
    }
}

/// Converts an AST `Type` into `Ty`, mapping variables by name via `vars`
/// (shared, so the same name — e.g. the `a` of `data List a` — gives the same
/// `Ty::Var` in the result and in the fields). Fresh vars take ids starting from `next`.
fn ast_ty(t: &Type, vars: &mut HashMap<String, u32>, next: &mut u32) -> Ty {
    match t {
        Type::Con(n) => Ty::Con(normalize_num(n), Vec::new()),
        Type::Var(n) => {
            let id = *vars.entry(n.clone()).or_insert_with(|| {
                let v = *next;
                *next += 1;
                v
            });
            Ty::Var(id)
        }
        Type::App(_, _) => {
            let (head, args) = flatten_app(t);
            Ty::Con(
                normalize_num(&head),
                args.iter().map(|a| ast_ty(a, vars, next)).collect(),
            )
        }
        Type::Arrow { from, to, .. } => Ty::Fun(
            Box::new(ast_ty(from, vars, next)),
            Box::new(ast_ty(to, vars, next)),
        ),
        Type::Tuple(ts) => Ty::Tuple(ts.iter().map(|a| ast_ty(a, vars, next)).collect()),
        Type::Unit => Ty::Con("()".to_string(), Vec::new()),
    }
}

fn ty_of_ast(t: &Type) -> Ty {
    // local namespace; the variables are quantified by `scheme_of_sig`
    let mut vars = HashMap::new();
    let mut next = 1_000_000; // banda separada
    ast_ty(t, &mut vars, &mut next)
}

/// Collects the ids of the type variables occurring in `ty` (to generalize).
fn free_ty_vars(ty: &Ty, out: &mut Vec<u32>) {
    match ty {
        Ty::Var(v) => {
            if !out.contains(v) {
                out.push(*v);
            }
        }
        Ty::Con(_, args) => args.iter().for_each(|a| free_ty_vars(a, out)),
        Ty::Fun(a, b) => {
            free_ty_vars(a, out);
            free_ty_vars(b, out);
        }
        Ty::Tuple(ts) => ts.iter().for_each(|t| free_ty_vars(t, out)),
    }
}

fn flatten_app(t: &Type) -> (String, Vec<Type>) {
    match t {
        Type::App(f, a) => {
            let (head, mut args) = flatten_app(f);
            args.push((**a).clone());
            (head, args)
        }
        Type::Con(n) => (n.clone(), Vec::new()),
        _ => ("?".to_string(), Vec::new()),
    }
}

impl<'a> Infer<'a> {
    fn fresh(&mut self) -> Ty {
        let v = self.counter;
        self.counter += 1;
        Ty::Var(v)
    }

    fn base_env(&mut self) -> Env {
        let io_unit = Ty::Con("IO".into(), vec![Ty::Con("()".into(), vec![])]);
        let int = || Ty::Con("Int".into(), vec![]);
        let string = || Ty::Con("String".into(), vec![]);
        let bool = || Ty::Con("Bool".into(), vec![]);
        let bin = |t: Ty| {
            Ty::Fun(
                Box::new(t.clone()),
                Box::new(Ty::Fun(Box::new(t.clone()), Box::new(t))),
            )
        };
        let mut env = Env::new();
        // putStrLn / putStr :: String -> IO ()
        env.insert(
            "putStrLn".into(),
            mono(Ty::Fun(Box::new(string()), Box::new(io_unit.clone()))),
        );
        env.insert(
            "putStr".into(),
            mono(Ty::Fun(Box::new(string()), Box::new(io_unit))),
        );
        // show :: forall a. a -> String
        env.insert(
            "show".into(),
            Scheme {
                vars: vec![0],
                ty: Ty::Fun(Box::new(Ty::Var(0)), Box::new(string())),
            },
        );
        env.insert("True".into(), mono(bool()));
        env.insert("False".into(), mono(bool()));
        env.insert("otherwise".into(), mono(bool()));
        // `mod` stays monomorphic in Int; `+ - *` are `Num a => a -> a -> a`
        // (built-in Num, resolved per use — see `discharge_obligations`).
        env.insert("mod".into(), mono(bin(int())));
        for op in ["+", "-", "*"] {
            env.insert(
                op.into(),
                Scheme {
                    vars: vec![0],
                    ty: bin(Ty::Var(0)),
                },
            );
        }
        // float arithmetic (§4): `+. -. *. /.` :: Float -> Float -> Float
        let float = || Ty::Con("Float".into(), vec![]);
        for op in ["+.", "-.", "*.", "/."] {
            env.insert(op.into(), mono(bin(float())));
        }
        // float comparisons (§4): `<. >. ==.` :: Float -> Float -> Bool
        let bin_pred = |t: Ty| {
            Ty::Fun(
                Box::new(t.clone()),
                Box::new(Ty::Fun(Box::new(t), Box::new(bool()))),
            )
        };
        for op in ["<.", ">.", "==."] {
            env.insert(op.into(), mono(bin_pred(float())));
        }
        // conversions (§4): toFloat :: Int -> Float, truncate :: Float -> Int
        env.insert(
            "toFloat".into(),
            mono(Ty::Fun(Box::new(int()), Box::new(float()))),
        );
        env.insert(
            "truncate".into(),
            mono(Ty::Fun(Box::new(float()), Box::new(int()))),
        );
        // unary Float math (§4): sqrt / floor / abs :: Float -> Float
        for f in ["sqrt", "floor", "abs"] {
            env.insert(f.into(), mono(Ty::Fun(Box::new(float()), Box::new(float()))));
        }
        // ++ :: forall a. a -> a -> a  (polymorphic concatenation; without typeclasses
        // yet, the Semigroup-ish type only forces both sides to match —
        // lists and strings both pass, `"x" ++ [1]` does not).
        env.insert(
            "++".into(),
            Scheme {
                vars: vec![0],
                ty: bin(Ty::Var(0)),
            },
        );
        // `== < >` are `Ord a => a -> a -> Bool` (built-in Ord, resolved per use;
        // Float uses rewrite to `==. <. >.`). Unconstrained uses default to Int.
        for op in ["==", "<", ">"] {
            env.insert(
                op.into(),
                Scheme {
                    vars: vec![0],
                    ty: Ty::Fun(
                        Box::new(Ty::Var(0)),
                        Box::new(Ty::Fun(Box::new(Ty::Var(0)), Box::new(bool()))),
                    ),
                },
            );
        }
        // arenas (§3). The arena arg is borrowed (not %1): allocateCell and
        // promote read the arena to bump-allocate, many times.
        let arena = || Ty::Con("Arena".into(), vec![]);
        let cell = || Ty::Con("Cell".into(), vec![]);
        // allocateCell :: Arena -> Cell
        env.insert(
            "allocateCell".into(),
            mono(Ty::Fun(Box::new(arena()), Box::new(cell()))),
        );
        // promote :: Arena -> Cell -> Cell
        env.insert(
            "promote".into(),
            mono(Ty::Fun(
                Box::new(arena()),
                Box::new(Ty::Fun(Box::new(cell()), Box::new(cell()))),
            )),
        );
        // withSubArena :: forall a. Arena -> (Arena -> a) -> a
        env.insert(
            "withSubArena".into(),
            Scheme {
                vars: vec![0],
                ty: Ty::Fun(
                    Box::new(arena()),
                    Box::new(Ty::Fun(
                        Box::new(Ty::Fun(Box::new(arena()), Box::new(Ty::Var(0)))),
                        Box::new(Ty::Var(0)),
                    )),
                ),
            },
        );
        // channels / session types (§6). HM does not express session progress — protocol
        // fidelity is checked in the `check_sessions` pass; here the
        // types are permissive (the endpoint is `Ep S`, the session advances `a`→`c`).
        let ep = |v: u32| Ty::Con("Ep".into(), vec![Ty::Var(v)]);
        // send :: forall a b c. Ep a -> b -> Ep c
        env.insert(
            "send".into(),
            Scheme {
                vars: vec![0, 1, 2],
                ty: Ty::Fun(
                    Box::new(ep(0)),
                    Box::new(Ty::Fun(Box::new(Ty::Var(1)), Box::new(ep(2)))),
                ),
            },
        );
        // recv :: forall a b c. Ep a -> (b, Ep c)
        env.insert(
            "recv".into(),
            Scheme {
                vars: vec![0, 1, 2],
                ty: Ty::Fun(
                    Box::new(ep(0)),
                    Box::new(Ty::Tuple(vec![Ty::Var(1), ep(2)])),
                ),
            },
        );
        // close :: forall a. Ep a -> IO ()  (closing is an effect → fits with `do`)
        env.insert(
            "close".into(),
            Scheme {
                vars: vec![0],
                ty: Ty::Fun(
                    Box::new(ep(0)),
                    Box::new(Ty::Con("IO".into(), vec![Ty::Con("()".into(), vec![])])),
                ),
            },
        );
        // structured-concurrency nursery (§9). `bound` opens a nursery whose
        // body is confined (endpoints don't escape — `check_bound_escapes`);
        // `newChannel` creates a dual endpoint pair; `spawn` forks a child that
        // consumes an endpoint and returns the dual to the parent. Permissive types (HM does not
        // exprime a dualidade nem o confinamento).
        // bound :: forall a. a -> a
        env.insert(
            "bound".into(),
            Scheme {
                vars: vec![0],
                ty: Ty::Fun(Box::new(Ty::Var(0)), Box::new(Ty::Var(0))),
            },
        );
        // newChannel :: forall a b. (Ep a, Ep b)
        env.insert(
            "newChannel".into(),
            Scheme {
                vars: vec![0, 1],
                ty: Ty::Tuple(vec![ep(0), ep(1)]),
            },
        );
        // spawn :: forall a b c. (Ep a -> b) -> Ep c
        env.insert(
            "spawn".into(),
            Scheme {
                vars: vec![0, 1, 2],
                ty: Ty::Fun(
                    Box::new(Ty::Fun(Box::new(ep(0)), Box::new(Ty::Var(1)))),
                    Box::new(ep(2)),
                ),
            },
        );
        // session choice (§6/§9): `select L c` chooses the label `L` (⊕) and
        // advances; `offer c` receives the choice (&) and consumes the endpoint. Permissive
        // types — fidelity/exhaustiveness is `check_sessions`'s job.
        // select :: forall a b c. b -> Ep a -> Ep c
        env.insert(
            "select".into(),
            Scheme {
                vars: vec![0, 1, 2],
                ty: Ty::Fun(
                    Box::new(Ty::Var(1)),
                    Box::new(Ty::Fun(Box::new(ep(0)), Box::new(ep(2)))),
                ),
            },
        );
        // offer :: forall a b. Ep a -> b  (receives the external choice; the result is
        // um valor-soma etiquetado — `L (Ep Cont)` — sobre o qual se faz `case`;
        // a generic return because the labels/continuations are the program's)
        env.insert(
            "offer".into(),
            Scheme {
                vars: vec![0, 1],
                ty: Ty::Fun(Box::new(ep(0)), Box::new(Ty::Var(1))),
            },
        );
        // cancel :: forall a. Ep a -> IO ()  (§7: descarta o endpoint, avisa o par)
        env.insert(
            "cancel".into(),
            Scheme {
                vars: vec![0],
                ty: Ty::Fun(
                    Box::new(ep(0)),
                    Box::new(Ty::Con("IO".into(), vec![Ty::Con("()".into(), vec![])])),
                ),
            },
        );
        // `mapM_` is no longer a builtin — it is a prelude function (pure Axion
        // over `case`), to compile natively like any HOF (native IO).
        // withArena :: forall a. (Arena -> a) -> a — creates the root arena, runs the
        // body and reclaims everything at the end (the entry point to run arena programs).
        env.insert(
            "withArena".into(),
            Scheme {
                vars: vec![0],
                ty: Ty::Fun(
                    Box::new(Ty::Fun(Box::new(arena()), Box::new(Ty::Var(0)))),
                    Box::new(Ty::Var(0)),
                ),
            },
        );
        // arena marks (Listing 3.6): intra-scope reclamation
        let mark = || Ty::Con("Mark".into(), vec![]);
        let unit = || Ty::Con("()".into(), vec![]);
        // arena_mark :: Arena -> Mark
        env.insert(
            "arena_mark".into(),
            mono(Ty::Fun(Box::new(arena()), Box::new(mark()))),
        );
        // arena_release :: Mark -> ()
        env.insert(
            "arena_release".into(),
            mono(Ty::Fun(Box::new(mark()), Box::new(unit()))),
        );
        // Buffer polymorphic in the element (`Buffer a`, e.g. `Buffer U8`). The
        // linearity (%1) is enforced by check.rs (`consumers` map + must-use);
        // here it's just the HM types. `a`=var 0, `b`=var 1 (result of withBuffer).
        let bufa = || Ty::Con("Buffer".into(), vec![Ty::Var(0)]);
        let int = || Ty::Con("Int".into(), vec![]);
        let io_unit = || Ty::Con("IO".into(), vec![unit()]);
        // newBuffer :: forall a. Int -> Buffer a
        env.insert(
            "newBuffer".into(),
            Scheme {
                vars: vec![0],
                ty: Ty::Fun(Box::new(int()), Box::new(bufa())),
            },
        );
        // withBuffer :: forall a b. Int -> (Buffer a -> b) -> b
        env.insert(
            "withBuffer".into(),
            Scheme {
                vars: vec![0, 1],
                ty: Ty::Fun(
                    Box::new(int()),
                    Box::new(Ty::Fun(
                        Box::new(Ty::Fun(Box::new(bufa()), Box::new(Ty::Var(1)))),
                        Box::new(Ty::Var(1)),
                    )),
                ),
            },
        );
        // bufIota/xorInPlace :: forall a. Buffer a -> … -> Buffer a (in-place)
        env.insert(
            "bufIota".into(),
            Scheme {
                vars: vec![0],
                ty: Ty::Fun(Box::new(bufa()), Box::new(bufa())),
            },
        );
        env.insert(
            "xorInPlace".into(),
            Scheme {
                vars: vec![0],
                ty: Ty::Fun(
                    Box::new(bufa()),
                    Box::new(Ty::Fun(Box::new(int()), Box::new(bufa()))),
                ),
            },
        );
        // sumBytes :: forall a. Buffer a -> Int; free :: forall a. Buffer a -> IO ()
        env.insert(
            "sumBytes".into(),
            Scheme {
                vars: vec![0],
                ty: Ty::Fun(Box::new(bufa()), Box::new(int())),
            },
        );
        env.insert(
            "free".into(),
            Scheme {
                vars: vec![0],
                ty: Ty::Fun(Box::new(bufa()), Box::new(io_unit())),
            },
        );
        // foldBytes :: forall a e. (a -> Int -> a) -> a -> Buffer e -> a
        // — folds over the bytes (borrows the buffer). The byte is `Int`.
        env.insert(
            "foldBytes".into(),
            Scheme {
                vars: vec![0, 1],
                ty: Ty::Fun(
                    Box::new(Ty::Fun(
                        Box::new(Ty::Var(0)),
                        Box::new(Ty::Fun(Box::new(int()), Box::new(Ty::Var(0)))),
                    )),
                    Box::new(Ty::Fun(
                        Box::new(Ty::Var(0)),
                        Box::new(Ty::Fun(Box::new(bufa()), Box::new(Ty::Var(0)))),
                    )),
                ),
            },
        );
        // imperative :: forall a. a -> a — the imperative block (§5) is identity.
        env.insert(
            "imperative".into(),
            Scheme {
                vars: vec![0],
                ty: Ty::Fun(Box::new(Ty::Var(0)), Box::new(Ty::Var(0))),
            },
        );
        // fractional permissions (§2). split :: forall a. a -> (a, a);
        // join :: forall a. a -> a -> a. The multiplicities (%1/%0.5) are
        // tracked separately, by the analysis in check.rs.
        env.insert(
            "split".into(),
            Scheme {
                vars: vec![0],
                ty: Ty::Fun(
                    Box::new(Ty::Var(0)),
                    Box::new(Ty::Tuple(vec![Ty::Var(0), Ty::Var(0)])),
                ),
            },
        );
        env.insert(
            "join".into(),
            Scheme {
                vars: vec![0],
                ty: Ty::Fun(
                    Box::new(Ty::Var(0)),
                    Box::new(Ty::Fun(Box::new(Ty::Var(0)), Box::new(Ty::Var(0)))),
                ),
            },
        );
        env
    }

    fn scheme_of_sig(&mut self, sig: &Type) -> Scheme {
        let ty = ty_of_ast(sig);
        // the signature variables (band 1_000_000+) become quantified
        let mut vars = Vec::new();
        collect_sig_vars(&ty, &mut vars);
        // renumbers to normal fresh variables and quantifies them
        let mut map = HashMap::new();
        for v in &vars {
            if let Ty::Var(f) = self.fresh() {
                map.insert(*v, f);
            }
        }
        let ty = rename_vars(&ty, &map);
        Scheme {
            vars: map.values().copied().collect(),
            ty,
        }
    }

    // --- substitution / unification ---
    fn resolve(&self, t: &Ty) -> Ty {
        match t {
            Ty::Var(v) => match self.subst.get(v) {
                Some(u) => self.resolve(u),
                None => t.clone(),
            },
            _ => t.clone(),
        }
    }

    /// Discharges the collected instance obligations. For each method
    /// use: if the dispatch type resolved to a CONCRETE type without an
    /// instance → **AX0404**; if it stayed POLYMORPHIC and the class is not covered
    /// by a constraint in the function's scope → **AX0405**. (Fun/Tuple: conservative,
    /// does not report.)
    fn discharge_obligations(&mut self, module: &Module) -> Mono {
        use std::collections::{HashMap as Map, HashSet as Set};
        // Note: built-in Num/Ord instances are NOT added here on purpose — they are
        // handled by `is_builtin_op_method` over the Int/Float operand type (see the
        // match below). Adding them would pollute non-operator methods of a
        // user/prelude class of the same name (e.g. the prelude's `Ord`'s `le`,
        // which has no Float instance).
        let instances: Set<(String, String)> = module
            .instances
            .iter()
            .map(|i| (i.class_name.clone(), i.ty_head.clone()))
            .collect();
        let func_names: Set<&str> = module.funcs.iter().map(|f| f.name.as_str()).collect();

        let mut resolutions: Map<(String, Span), String> = Map::new();
        // per constrained function: polymorphic method uses (span → method) and
        // polymorphic calls to constrained functions (span → function, including
        // self-recursion) — the points specialization rewrites to `$T`.
        let mut poly_methods: Map<String, Vec<(Span, String)>> = Map::new();
        let mut poly_calls: Map<String, Vec<(Span, String)>> = Map::new();

        let obls = std::mem::take(&mut self.obligations);
        for o in obls {
            match self.resolve(&o.ty) {
                // built-in Num/Ord operator over Float → rewrite to the dotted form
                // the backends already lower.
                Ty::Con(name, _) if is_builtin_op_method(&o.method) && name == "Float" => {
                    resolutions
                        .insert((o.func.clone(), o.span), builtin_op_float(&o.method).into());
                }
                // built-in Num/Ord operator over Int → keep the operator (no rewrite).
                Ty::Con(name, _) if is_builtin_op_method(&o.method) && name == "Int" => {}
                // concrete type WITH instance → resolves to the direct impl.
                Ty::Con(name, _) if instances.contains(&(o.class.clone(), name.clone())) => {
                    resolutions.insert(
                        (o.func.clone(), o.span),
                        crate::ast::method_impl_name(&o.method, &name),
                    );
                }
                Ty::Con(name, _) => {
                    self.diags.push(
                        Diagnostic::error(
                            "AX0404",
                            format!("no instance of `{}` for `{name}`", o.class),
                        )
                        .label(o.span.0, o.span.1, "method used here, over this type")
                        .with_help(format!(
                            "declare `instance {} {name} where …`, or use a type \
                             that has an instance of this class.",
                            o.class
                        )),
                    );
                }
                // polymorphic covered by a constraint → specializable use.
                Ty::Var(_) if o.scope.contains(&o.class) => {
                    poly_methods
                        .entry(o.func.clone())
                        .or_default()
                        .push((o.span, o.method.clone()));
                }
                // built-in Num over an unconstrained (monomorphic) type variable:
                // default to Int (à la Haskell), so `g x = x + x` is `Int -> Int`.
                // The var is monomorphic (unsignatured function), so binding it is
                // safe — nothing has been generalized over it. No rewrite needed:
                // the operator keeps its Int form.
                Ty::Var(v) if is_builtin_op_method(&o.method) => {
                    self.unify(&Ty::Var(v), &Ty::Con("Int".into(), vec![]), o.span);
                }
                Ty::Var(_) => {
                    self.diags.push(
                        Diagnostic::error(
                            "AX0405",
                            format!(
                                "class `{}` method used over a polymorphic type \
                                 without a constraint",
                                o.class
                            ),
                        )
                        .label(o.span.0, o.span.1, "generic type here")
                        .with_help(format!(
                            "add `{} a =>` to the function signature to allow \
                             the method over a generic type.",
                            o.class
                        )),
                    );
                }
                _ => {}
            }
        }

        // uses of constrained functions → specialization seeds (concrete)
        // and polymorphic calls (transitive, for the constraint var).
        let mut seeds: Vec<(String, Span, String, String)> = Vec::new(); // caller,span,fn,T
        let specs_obls = std::mem::take(&mut self.spec_obligations);
        for s in specs_obls {
            match self.resolve(&s.ty) {
                // called at a concrete type → seed `(fn, T)` + call-site.
                Ty::Con(t, _) => seeds.push((s.func.clone(), s.span, s.target.clone(), t)),
                // call over the generic var → rewritten to `$T` when the
                // caller is specialized (self-recursion is the `g == f` case).
                Ty::Var(_) => poly_calls
                    .entry(s.func.clone())
                    .or_default()
                    .push((s.span, s.target.clone())),
                _ => {}
            }
        }

        // expands the set of required specializations by worklist: a
        // `(f, T)` pulls `(g, T)` for each polymorphic constrained call in `f`
        // (`g`'s constraint var is the same as `f`'s, hence the same `T`). Closes
        // TRANSITIVE specialization.
        let mut cands: Set<(String, String)> = Set::new();
        let mut queue: Vec<(String, String)> = Vec::new();
        for (_, _, f, t) in &seeds {
            if cands.insert((f.clone(), t.clone())) {
                queue.push((f.clone(), t.clone()));
            }
        }
        while let Some((f, t)) = queue.pop() {
            for (_, g) in poly_calls.get(&f).into_iter().flatten() {
                let node = (g.clone(), t.clone());
                if cands.insert(node.clone()) {
                    queue.push(node);
                }
            }
        }

        // fixpoint validity: `(f, T)` is valid unless `f` is
        // unspecializable, the dispatch var is missing, some method impl
        // `m$T` is missing, or some dependency `(g, T)` is invalid.
        let mut invalid: Set<(String, String)> = Set::new();
        loop {
            let mut changed = false;
            for (f, t) in &cands {
                if invalid.contains(&(f.clone(), t.clone())) {
                    continue;
                }
                let no_spec_var = self
                    .constrained_meta
                    .get(f)
                    .is_none_or(|(_, idx)| idx.is_none());
                let bad = self.refs_unspec.contains(f)
                    || no_spec_var
                    || poly_methods.get(f).into_iter().flatten().any(|(_, m)| {
                        // built-in Num operators are always available (Int/Float).
                        !is_builtin_op_method(m)
                            && !func_names.contains(crate::ast::method_impl_name(m, t).as_str())
                    })
                    || poly_calls
                        .get(f)
                        .into_iter()
                        .flatten()
                        .any(|(_, g)| invalid.contains(&(g.clone(), t.clone())));
                if bad {
                    invalid.insert((f.clone(), t.clone()));
                    changed = true;
                }
            }
            if !changed {
                break;
            }
        }

        // materializes each valid specialization.
        let mut specs: Vec<SpecPlan> = Vec::new();
        for (f, t) in &cands {
            if invalid.contains(&(f.clone(), t.clone())) {
                continue;
            }
            let name = crate::ast::method_impl_name(f, t);
            let mut rewrites: HashMap<Span, String> = HashMap::new();
            for (sp, m) in poly_methods.get(f).into_iter().flatten() {
                if is_builtin_op_method(m) {
                    // built-in Num: only Float needs a rewrite (`+` → `+.`); the
                    // Int specialization keeps the operator the source already has.
                    if t == "Float" {
                        rewrites.insert(*sp, builtin_op_float(m).into());
                    }
                } else {
                    rewrites.insert(*sp, crate::ast::method_impl_name(m, t));
                }
            }
            for (sp, g) in poly_calls.get(f).into_iter().flatten() {
                rewrites.insert(*sp, crate::ast::method_impl_name(g, t));
            }
            let tyvar = self
                .constrained_meta
                .get(f)
                .map(|(v, _)| v.clone())
                .unwrap_or_default();
            specs.push(SpecPlan {
                src: f.clone(),
                name,
                tyvar,
                ty_head: t.clone(),
                rewrites,
            });
        }
        // rewrites the seed call-sites whose specializations are valid.
        for (caller, span, f, t) in seeds {
            if cands.contains(&(f.clone(), t.clone())) && !invalid.contains(&(f.clone(), t.clone()))
            {
                resolutions.insert((caller, span), crate::ast::method_impl_name(&f, &t));
            }
        }

        Mono { resolutions, specs }
    }

    fn apply(&self, t: &Ty) -> Ty {
        match self.resolve(t) {
            Ty::Con(n, args) => Ty::Con(n, args.iter().map(|a| self.apply(a)).collect()),
            Ty::Fun(a, b) => Ty::Fun(Box::new(self.apply(&a)), Box::new(self.apply(&b))),
            Ty::Tuple(ts) => Ty::Tuple(ts.iter().map(|a| self.apply(a)).collect()),
            other => other,
        }
    }

    fn occurs(&self, v: u32, t: &Ty) -> bool {
        match self.resolve(t) {
            Ty::Var(u) => u == v,
            Ty::Con(_, args) => args.iter().any(|a| self.occurs(v, a)),
            Ty::Fun(a, b) => self.occurs(v, &a) || self.occurs(v, &b),
            Ty::Tuple(ts) => ts.iter().any(|a| self.occurs(v, a)),
        }
    }

    fn unify(&mut self, a: &Ty, b: &Ty, span: Span) -> bool {
        let a = self.resolve(a);
        let b = self.resolve(b);
        match (&a, &b) {
            (Ty::Var(x), Ty::Var(y)) if x == y => true,
            (Ty::Var(x), _) => self.bind(*x, &b, span),
            (_, Ty::Var(y)) => self.bind(*y, &a, span),
            (Ty::Con(n1, a1), Ty::Con(n2, a2)) if n1 == n2 && a1.len() == a2.len() => {
                let mut ok = true;
                for (x, y) in a1.iter().zip(a2) {
                    ok &= self.unify(x, y, span);
                }
                ok
            }
            (Ty::Fun(l1, r1), Ty::Fun(l2, r2)) => {
                let ok1 = self.unify(l1, l2, span);
                let ok2 = self.unify(r1, r2, span);
                ok1 && ok2
            }
            (Ty::Tuple(t1), Ty::Tuple(t2)) if t1.len() == t2.len() => {
                let mut ok = true;
                for (x, y) in t1.iter().zip(t2) {
                    ok &= self.unify(x, y, span);
                }
                ok
            }
            _ => {
                self.err_mismatch(&a, &b, span);
                false
            }
        }
    }

    fn bind(&mut self, v: u32, t: &Ty, span: Span) -> bool {
        if let Ty::Var(u) = t {
            if *u == v {
                return true;
            }
        }
        if self.occurs(v, t) {
            self.diags.push(
                Diagnostic::error("AX0201", "infinite type (occurs-check failed)").label(
                    span.0,
                    span.1,
                    "inference would form a recursive type here",
                ),
            );
            return false;
        }
        self.subst.insert(v, t.clone());
        true
    }

    fn err_mismatch(&mut self, a: &Ty, b: &Ty, span: Span) {
        let sa = show_ty(&self.apply(a));
        let sb = show_ty(&self.apply(b));
        self.diags.push(
            Diagnostic::error("AX0200", format!("type mismatch: {sa} vs {sb}"))
                .label(span.0, span.1, format!("expected {sa}, found {sb}"))
                .with_help(
                    "inference required these two types to be equal; check the signature and the \
                 arguments of the application.",
                ),
        );
    }

    fn instantiate(&mut self, s: &Scheme) -> Ty {
        let mut map = HashMap::new();
        for v in &s.vars {
            if let Ty::Var(f) = self.fresh() {
                map.insert(*v, f);
            }
        }
        rename_vars(&s.ty, &map)
    }

    fn generalize(&self, env: &Env, ty: &Ty) -> Scheme {
        let ty = self.apply(ty);
        let mut env_vars = HashSet::new();
        for s in env.values() {
            let applied = self.apply(&s.ty);
            let mut fv = HashSet::new();
            free_vars(&applied, &mut fv);
            for q in &s.vars {
                fv.remove(q);
            }
            env_vars.extend(fv);
        }
        let mut fv = HashSet::new();
        free_vars(&ty, &mut fv);
        let vars: Vec<u32> = fv.difference(&env_vars).copied().collect();
        Scheme { vars, ty }
    }

    // --- inference ---
    fn peel_fun(&self, ty: &Ty, n: usize) -> (Vec<Ty>, Ty) {
        let mut params = Vec::new();
        let mut cur = self.resolve(ty);
        for _ in 0..n {
            match cur {
                Ty::Fun(a, b) => {
                    params.push(*a);
                    cur = self.resolve(&b);
                }
                other => {
                    cur = other;
                    break;
                }
            }
        }
        (params, cur)
    }

    fn infer_func(&mut self, env: &Env, f: &Func, expected: Option<&Ty>) -> Ty {
        let mut result: Option<Ty> = None;
        for clause in &f.clauses {
            let t = self.infer_clause(env, clause, expected);
            match &result {
                None => result = Some(t),
                Some(r) => {
                    self.unify(r, &t, clause.span);
                }
            }
        }
        result.unwrap_or_else(|| self.fresh())
    }

    fn infer_clause(&mut self, env: &Env, clause: &Clause, expected: Option<&Ty>) -> Ty {
        let mut local = env.clone();
        let n = clause.pats.len();
        let (exp_params, exp_result) = match expected {
            Some(t) => {
                let (p, r) = self.peel_fun(t, n);
                (p, Some(r))
            }
            None => (Vec::new(), None),
        };
        let mut params = Vec::new();
        for (i, p) in clause.pats.iter().enumerate() {
            let pt = self.infer_pat(&mut local, p);
            if let Some(ep) = exp_params.get(i) {
                self.unify(&pt, ep, clause.span);
            }
            params.push(pt);
        }
        // where: a group of bindings with generalization
        let local = self.infer_group(&local, &clause.wher);
        let body_ty = match &clause.body {
            Body::Plain(e) => self.infer_expr(&local, e),
            Body::Guarded(arms) => {
                let mut rty: Option<Ty> = None;
                for (g, r) in arms {
                    let gt = self.infer_expr(&local, g);
                    self.unify(&gt, &Ty::Con("Bool".into(), vec![]), g.span());
                    let rt = self.infer_expr(&local, r);
                    match &rty {
                        None => rty = Some(rt),
                        Some(x) => {
                            self.unify(x, &rt, r.span());
                        }
                    }
                }
                rty.unwrap_or_else(|| self.fresh())
            }
        };
        if let Some(er) = &exp_result {
            self.unify(&body_ty, er, clause.span);
        }
        let mut ty = body_ty;
        for p in params.into_iter().rev() {
            ty = Ty::Fun(Box::new(p), Box::new(ty));
        }
        ty
    }

    fn infer_pat(&mut self, env: &mut Env, p: &Pat) -> Ty {
        match p {
            Pat::Wild(_) => self.fresh(),
            Pat::Int(_, _) => Ty::Con("Int".into(), vec![]),
            Pat::Var(n, _) => {
                let t = self.fresh();
                env.insert(n.clone(), mono(t.clone()));
                t
            }
            Pat::Con(name, args, span) => {
                // applied constructor: instantiates the constructor's type
                let cty = match env.get(name) {
                    Some(s) => self.instantiate(s),
                    None => return self.fresh(),
                };
                let mut result = cty;
                for a in args {
                    let at = self.infer_pat(env, a);
                    let r = self.fresh();
                    self.unify(&result, &Ty::Fun(Box::new(at), Box::new(r.clone())), *span);
                    result = r;
                }
                result
            }
            Pat::Tuple(ps, _) => Ty::Tuple(ps.iter().map(|p| self.infer_pat(env, p)).collect()),
        }
    }

    /// Infers a group of bindings (`let`/`where`) with generalization and
    /// returns the extended env.
    fn infer_group(&mut self, env: &Env, funcs: &[Func]) -> Env {
        if funcs.is_empty() {
            return env.clone();
        }
        // monomorphic phase: each name gets a fresh var
        let mut mono_env = env.clone();
        let mut vars = HashMap::new();
        for f in funcs {
            let v = self.fresh();
            vars.insert(f.name.clone(), v.clone());
            mono_env.insert(f.name.clone(), mono(v));
        }
        for f in funcs {
            let t = self.infer_func(&mono_env, f, None);
            let v = vars[&f.name].clone();
            self.unify(&v, &t, f.span);
        }
        // generalization phase: rebind with schemes closed over the outer env
        let mut out = env.clone();
        for f in funcs {
            let t = self.apply(&vars[&f.name]);
            let scheme = self.generalize(env, &t);
            out.insert(f.name.clone(), scheme);
        }
        out
    }

    fn infer_expr(&mut self, env: &Env, e: &Expr) -> Ty {
        match e {
            Expr::Int(_, _) => Ty::Con("Int".into(), vec![]),
            Expr::Float(_, _) => Ty::Con("Float".into(), vec![]),
            Expr::Str(_, _) => Ty::Con("String".into(), vec![]),
            Expr::Var(n, span) => {
                let ty = match env.get(n) {
                    Some(s) => self.instantiate(s),
                    None => self.fresh(), // name not found: reported by check.rs
                };
                // method use: collects the instance obligation over the type of the
                // dispatch parameter (resolved at the end).
                if let Some((class, Some(idx))) = self.method_meta.get(n).cloned() {
                    if let Some(dispatch) = nth_param(&ty, idx) {
                        self.obligations.push(Obl {
                            class,
                            method: n.clone(),
                            ty: dispatch,
                            span: *span,
                            scope: self.cur_constraints.clone(),
                            func: self.cur_fn.clone(),
                        });
                    }
                }
                // use of a constrained function: collects the specialization
                // obligation over the type of the constraint var.
                if let Some((_, idx)) = self.constrained_meta.get(n).cloned() {
                    match idx {
                        Some(i) => {
                            if let Some(dispatch) = nth_param(&ty, i) {
                                self.spec_obligations.push(SpecObl {
                                    target: n.clone(),
                                    ty: dispatch,
                                    span: *span,
                                    func: self.cur_fn.clone(),
                                });
                            }
                        }
                        // constrained without a dispatch parameter → not capturable:
                        // the function that uses it cannot be specialized.
                        None => {
                            self.refs_unspec.insert(self.cur_fn.clone());
                        }
                    }
                }
                ty
            }
            Expr::Con(n, _) => match env.get(n) {
                Some(s) => self.instantiate(s),
                None => self.fresh(),
            },
            Expr::App(f, x, span) => {
                let tf = self.infer_expr(env, f);
                let tx = self.infer_expr(env, x);
                let r = self.fresh();
                self.unify(&tf, &Ty::Fun(Box::new(tx), Box::new(r.clone())), *span);
                r
            }
            Expr::BinOp(op, l, r, span) => {
                let top = match env.get(op) {
                    Some(s) => self.instantiate(s),
                    None => self.fresh(),
                };
                // method use (built-in `Num` operator, or a user infix method):
                // collect the instance obligation over the dispatch operand type,
                // resolved at the end (`discharge_obligations`).
                if let Some((class, Some(idx))) = self.method_meta.get(op).cloned() {
                    if let Some(dispatch) = nth_param(&top, idx) {
                        self.obligations.push(Obl {
                            class,
                            method: op.clone(),
                            ty: dispatch,
                            span: *span,
                            scope: self.cur_constraints.clone(),
                            func: self.cur_fn.clone(),
                        });
                    }
                }
                let tl = self.infer_expr(env, l);
                let tr = self.infer_expr(env, r);
                let res = self.fresh();
                let want = Ty::Fun(
                    Box::new(tl),
                    Box::new(Ty::Fun(Box::new(tr), Box::new(res.clone()))),
                );
                self.unify(&top, &want, *span);
                res
            }
            Expr::If(c, t, el, span) => {
                let tc = self.infer_expr(env, c);
                self.unify(&tc, &Ty::Con("Bool".into(), vec![]), c.span());
                let tt = self.infer_expr(env, t);
                let te = self.infer_expr(env, el);
                self.unify(&tt, &te, *span);
                tt
            }
            Expr::Let(binds, body, _) => {
                let env2 = self.infer_group(env, binds);
                self.infer_expr(&env2, body)
            }
            Expr::Case(scrut, arms, span) => {
                let ts = self.infer_expr(env, scrut);
                let mut rty: Option<Ty> = None;
                for (pat, body) in arms {
                    let mut local = env.clone();
                    let tp = self.infer_pat(&mut local, pat);
                    self.unify(&tp, &ts, *span);
                    let tb = self.infer_expr(&local, body);
                    match &rty {
                        None => rty = Some(tb),
                        Some(x) => {
                            self.unify(x, &tb, body.span());
                        }
                    }
                }
                rty.unwrap_or_else(|| self.fresh())
            }
            Expr::Tuple(es, _) => Ty::Tuple(es.iter().map(|e| self.infer_expr(env, e)).collect()),
            Expr::RecordCon(con, assigns, span) => {
                let (tyname, fields) = match self.cons.get(con) {
                    Some(x) => x.clone(),
                    None => return self.fresh(),
                };
                for (fname, fexpr) in assigns {
                    let fe = self.infer_expr(env, fexpr);
                    if let Some((_, ft)) = fields.iter().find(|(n, _)| n == fname) {
                        self.unify(&fe, ft, *span);
                    }
                }
                Ty::Con(tyname, vec![])
            }
            Expr::RecordUpd(base, assigns, span) => {
                let tb = self.infer_expr(env, base);
                let resolved = self.apply(&tb);
                if let Ty::Con(tyname, _) = &resolved {
                    if let Some(fields) = self.records.get(tyname).cloned() {
                        for (fname, fexpr) in assigns {
                            let fe = self.infer_expr(env, fexpr);
                            if let Some((_, ft)) = fields.iter().find(|(n, _)| n == fname) {
                                self.unify(&fe, ft, *span);
                            }
                        }
                    }
                } else {
                    // base still unknown: only infers the fields
                    for (_, fexpr) in assigns {
                        self.infer_expr(env, fexpr);
                    }
                }
                tb
            }
            Expr::Lam(pats, body, _) => {
                let mut local = env.clone();
                let params: Vec<Ty> = pats.iter().map(|p| self.infer_pat(&mut local, p)).collect();
                let mut ty = self.infer_expr(&local, body);
                for p in params.into_iter().rev() {
                    ty = Ty::Fun(Box::new(p), Box::new(ty));
                }
                ty
            }
        }
    }
}

fn mono(ty: Ty) -> Scheme {
    Scheme { vars: vec![], ty }
}

fn collect_sig_vars(t: &Ty, out: &mut Vec<u32>) {
    match t {
        Ty::Var(v) => {
            if *v >= 1_000_000 && !out.contains(v) {
                out.push(*v);
            }
        }
        Ty::Con(_, args) => args.iter().for_each(|a| collect_sig_vars(a, out)),
        Ty::Fun(a, b) => {
            collect_sig_vars(a, out);
            collect_sig_vars(b, out);
        }
        Ty::Tuple(ts) => ts.iter().for_each(|a| collect_sig_vars(a, out)),
    }
}

fn rename_vars(t: &Ty, map: &HashMap<u32, u32>) -> Ty {
    match t {
        Ty::Var(v) => Ty::Var(*map.get(v).unwrap_or(v)),
        Ty::Con(n, args) => Ty::Con(
            n.clone(),
            args.iter().map(|a| rename_vars(a, map)).collect(),
        ),
        Ty::Fun(a, b) => Ty::Fun(Box::new(rename_vars(a, map)), Box::new(rename_vars(b, map))),
        Ty::Tuple(ts) => Ty::Tuple(ts.iter().map(|a| rename_vars(a, map)).collect()),
    }
}

fn free_vars(t: &Ty, out: &mut HashSet<u32>) {
    match t {
        Ty::Var(v) => {
            out.insert(*v);
        }
        Ty::Con(_, args) => args.iter().for_each(|a| free_vars(a, out)),
        Ty::Fun(a, b) => {
            free_vars(a, out);
            free_vars(b, out);
        }
        Ty::Tuple(ts) => ts.iter().for_each(|a| free_vars(a, out)),
    }
}

fn show_ty(t: &Ty) -> String {
    match t {
        Ty::Var(v) => format!("?{v}"),
        Ty::Con(n, args) if args.is_empty() => n.clone(),
        Ty::Con(n, args) => {
            let inner: Vec<String> = args.iter().map(show_ty).collect();
            format!("{n} {}", inner.join(" "))
        }
        Ty::Fun(a, b) => format!("{} -> {}", show_ty_atom(a), show_ty(b)),
        Ty::Tuple(ts) => {
            let inner: Vec<String> = ts.iter().map(show_ty).collect();
            format!("({})", inner.join(", "))
        }
    }
}

fn show_ty_atom(t: &Ty) -> String {
    match t {
        Ty::Fun(_, _) => format!("({})", show_ty(t)),
        _ => show_ty(t),
    }
}
