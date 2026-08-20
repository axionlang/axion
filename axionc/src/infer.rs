#![allow(clippy::pedantic)]
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
    /// uses of the polymorphic `++`, with the operand type — resolved at the end:
    /// a `String` use is rewritten to native `strAppend` (`++#str`), otherwise it
    /// stays `++` (the prelude's list `append`).
    concat_uses: Vec<(String, Span, Ty)>,
    /// data type → its constructor names, for exhaustiveness checking.
    data_cons: HashMap<String, Vec<String>>,
    /// `case` sites (scrutinee type, patterns, span), checked for exhaustiveness
    /// at the end (once the scrutinee type is fully resolved).
    case_uses: Vec<(Ty, Vec<Pat>, Span)>,
    /// uses of constrained functions, for monomorphization.
    spec_obligations: Vec<SpecObl>,
    /// constrained function → one entry per constraint `(constraint var, dispatch)`,
    /// in constraint order. The dispatch is the param index carrying the constraint
    /// var and whether the var is NESTED (`Maybe a` → the element is the param's
    /// type argument) vs the param itself. A MULTI-constraint function (a
    /// `(Show a, Show b) =>` instance) specializes on the whole vector, keyed by the
    /// joined mangle (`$Int$Bool`); each method use rewrites via its own cvar (see
    /// `cvar_ivars`). Single-constraint is the length-1 case (unchanged behaviour).
    constrained_meta: HashMap<String, Vec<(String, Option<(usize, bool)>)>>,
    /// constrained function → the inference var each constraint var was instantiated
    /// to while checking its body (constraint order). Used to tell WHICH constraint a
    /// polymorphic method use dispatches over, so a 2-param instance rewrites each
    /// field at the right type. Only consulted for multi-constraint functions.
    cvar_ivars: HashMap<String, Vec<Ty>>,
    /// functions that reference an unspecializable constrained function (constraint
    /// var not a direct parameter) — they cannot be specialized.
    refs_unspec: HashSet<String>,
    /// generic-owning function → its owned `%1` params (Phase B): (param index,
    /// type var name, positional path of the var inside the param type). Only
    /// UNCONSTRAINED functions (the constrained ones are already specialized
    /// by the typeclass pipeline).
    owned_meta: HashMap<String, OwnedParamMeta>,
    /// uses of generic-owning functions, for monomorphization.
    own_obligations: Vec<OwnObl>,
    /// classes with a declared constraint in the scope of the function being inferred.
    cur_constraints: Vec<String>,
    /// name of the function being inferred (key of the resolutions, with the span).
    cur_fn: String,
    /// Phase 4: constructor call-site return types (span → concrete Ty).
    /// Recorded at `Expr::Con` / `Expr::App` with a constructor head / `Expr::RecordCon`
    /// and threaded to the lowering so `MakeCon.ty` carries the mangled concrete key
    /// (`List$P`) instead of just the type head (`List`).
    con_ret_tys: HashMap<Span, Ty>,
    /// `newArray` call span → the inferred element type (for monomorphized
    /// array destructor generation, analog to `con_ret_tys`).
    array_ret_tys: HashMap<Span, Ty>,
    /// Phase 4: result type at each application span (for the concrete drop key of
    /// a call/rtcall-bound local of a parametric heap type).
    call_ret_tys: HashMap<Span, Ty>,
    /// Phase 1b: each integer-literal expression's fresh type var (span → var), so a
    /// literal resolved to `Integer` by context is rewritten `fromInt n`, and an
    /// unconstrained one defaults to `Int`.
    int_lit_vars: Vec<(Span, Ty)>,
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

/// A use of a GENERIC-OWNING function (`f :: … List a %1 …`, UNCONSTRAINED) —
/// collected for Phase B monomorphization (the generic-owning corner): if the
/// owned parameter's type var resolves to a concrete type at the call-site, `f`
/// is specialized to that type, so the parameter's drop-type key resolves and
/// Per-parameter type-variable info: `(param_index, [(var_name, path)])`.
type OwnedParamMeta = Vec<(usize, Vec<(String, Vec<usize>)>)>;

/// the body deep-drops through the monomorphized destructor.
struct OwnObl {
    target: String,                  // the generic-owning function called
    vars: Vec<(String, Vec<usize>)>, // (var_name, path) for each type var
    param_ty: Ty,                    // the inferred type of the owned `%1` parameter at this use
    span: Span,
    func: String, // function where the use occurs (caller)
}

/// The inference result for monomorphization: the direct rewrites
/// (`(function, span) → name`) and the plan of specialized functions to materialize.
pub struct Mono {
    pub resolutions: HashMap<(String, Span), String>,
    pub specs: Vec<SpecPlan>,
    /// Phase 4: constructor call-site return types (span → concrete AST Type)
    pub makecon_tys: HashMap<Span, Type>,
    /// Phase 2c: `newArray` call-site return types (span → Array element type)
    pub array_tys: HashMap<Span, Type>,
    /// Phase 1b: integer-literal spans that resolved to `Integer` (rewritten `fromInt n`).
    pub integer_lits: std::collections::HashSet<Span>,
    /// Monomorphic `show`/`showArg` functions synthesized for shapes with no
    /// usable nominal instance: TUPLES (`show$(Int,Int)`) and MULTI-PARAM derived
    /// data (`show$Either$Int$Bool`). Injected after inference (see
    /// `analyze_module`). Each component/field is shown at its OWN concrete type,
    /// so the single-`t` monomorphizer never holds two type vars at once — the
    /// reason this sidesteps the 2-param dispatch limit.
    pub synth_shows: Vec<Func>,
}

/// Instruction to clone `src` into a monomorphic function `name`, substituting
/// the type variable `tyvar` by the concrete type `repl` in the signature, and
/// rewriting the internal uses (span → direct name: methods→`m$T`,
/// self-recursion→`name`, owning-generic calls→`g$T`). Used by the typeclass
/// pipeline (where `repl` is the class type, e.g. `Eq a` resolved to `Int`)
/// and by Phase B's owning-generic pipeline (where `subs` maps each type var to
/// its concrete replacement type, e.g. `[(a, P), (b, Q)]` for multi-var).
pub struct SpecPlan {
    pub src: String,
    pub name: String,
    pub subs: Vec<(String, Type)>,
    pub rewrites: HashMap<Span, String>,
}

/// Entry point: infers and checks the module's types. Returns the monomorphic
/// method resolutions (`(function, use span) → impl name`), so that
/// monomorphization rewrites the uses as direct calls. The
/// key includes the function because the prelude's and the user's spans collide.
/// Whole-module type inference (§16): the setup + every function body + the
/// post-passes. Unchanged in behavior; the body is now split into [`setup`],
/// [`Infer::check_body`] and [`Infer::finish`] so the salsa engine can run
/// inference for a SUBSET of functions (`crate::db`).
pub fn infer(module: &Module, diags: &mut Diagnostics) -> Mono {
    let (mut inf, env) = setup(module, diags);
    for f in &module.funcs {
        inf.check_body(&env, f);
    }
    inf.finish(module)
}

/// Diagnostics from inferring ONLY `funcs`, against `module`'s (body-independent)
/// signature environment. For a function that is ISOLATED — annotated and calling
/// only annotated/builtin/constructor names — this reproduces its whole-module
/// diagnostics exactly, because its inference never touches another function's
/// placeholder type var. The salsa engine memoizes this per declaration; a
/// differential test (`tests/salsa.rs`) guards the "reproduces exactly" claim.
#[cfg_attr(not(feature = "salsa"), allow(dead_code))]
pub fn infer_partial(module: &Module, funcs: &[&Func], diags: &mut Diagnostics) {
    let (mut inf, env) = setup(module, diags);
    for f in funcs {
        inf.check_body(&env, f);
    }
    let _ = inf.finish(module);
}

/// Top-level functions WITHOUT a signature. In inference these get a monomorphic
/// placeholder var shared across the whole module, so any function that references
/// one has its inference tied to that function's body — the reason such callers are
/// NOT isolated. Derived from signatures only (body-independent).
#[cfg_attr(not(feature = "salsa"), allow(dead_code))]
pub fn unannotated_funcs(module: &Module) -> HashSet<String> {
    module
        .funcs
        .iter()
        .filter(|f| f.sig.is_none())
        .map(|f| f.name.clone())
        .collect()
}

/// Whether `f`'s inference is independent of every other function's body: it has a
/// full signature AND references no unannotated top-level function (so it only ever
/// unifies against annotated schemes / builtins / constructors — all body-stable).
/// For such a function, per-declaration inference reproduces its whole-module
/// diagnostics exactly. The name check over-approximates (it counts shadowing local
/// binders too), which only makes MORE functions residual — always safe.
#[cfg_attr(not(feature = "salsa"), allow(dead_code))]
pub fn is_isolated(f: &Func, unannotated: &HashSet<String>) -> bool {
    if f.sig.is_none() || unannotated.is_empty() {
        return f.sig.is_some();
    }
    !f.clauses.iter().any(|c| clause_refs_any(c, unannotated))
}

fn clause_refs_any(c: &Clause, set: &HashSet<String>) -> bool {
    let body_hit = match &c.body {
        Body::Plain(e) => expr_refs_any(e, set),
        Body::Guarded(arms) => arms
            .iter()
            .any(|(g, r)| expr_refs_any(g, set) || expr_refs_any(r, set)),
    };
    body_hit || c.wher.iter().any(|w| func_refs_any(w, set))
}

fn func_refs_any(f: &Func, set: &HashSet<String>) -> bool {
    f.clauses.iter().any(|c| clause_refs_any(c, set))
}

fn expr_refs_any(e: &Expr, set: &HashSet<String>) -> bool {
    match e {
        Expr::Var(n, _) | Expr::Con(n, _) => set.contains(n),
        Expr::Int(..) | Expr::Float(..) | Expr::Str(..) => false,
        Expr::App(a, b, _) | Expr::BinOp(_, a, b, _) => {
            expr_refs_any(a, set) || expr_refs_any(b, set)
        }
        Expr::If(a, b, c, _) => {
            expr_refs_any(a, set) || expr_refs_any(b, set) || expr_refs_any(c, set)
        }
        Expr::Let(funcs, body, _) => {
            funcs.iter().any(|f| func_refs_any(f, set)) || expr_refs_any(body, set)
        }
        Expr::Case(scrut, arms, _) => {
            expr_refs_any(scrut, set) || arms.iter().any(|(_, e)| expr_refs_any(e, set))
        }
        Expr::Tuple(es, _) => es.iter().any(|e| expr_refs_any(e, set)),
        Expr::RecordCon(_, fs, _) => fs.iter().any(|(_, e)| expr_refs_any(e, set)),
        Expr::RecordUpd(b, fs, _) => {
            expr_refs_any(b, set) || fs.iter().any(|(_, e)| expr_refs_any(e, set))
        }
        Expr::Lam(_, b, _) => expr_refs_any(b, set),
    }
}

/// Setup shared by whole-module and partial inference: the type environment
/// (constructor/selector/method/function schemes) and inference metadata, all
/// derived from signatures, `data` and class headers — never function bodies.
fn setup<'a>(module: &Module, diags: &'a mut Diagnostics) -> (Infer<'a>, Env) {
    let mut inf = Infer {
        subst: HashMap::new(),
        counter: 0,
        diags,
        cons: HashMap::new(),
        records: HashMap::new(),
        method_meta: HashMap::new(),
        obligations: Vec::new(),
        concat_uses: Vec::new(),
        data_cons: HashMap::new(),
        case_uses: Vec::new(),
        spec_obligations: Vec::new(),
        constrained_meta: HashMap::new(),
        cvar_ivars: HashMap::new(),
        refs_unspec: HashSet::new(),
        owned_meta: HashMap::new(),
        own_obligations: Vec::new(),
        cur_constraints: Vec::new(),
        cur_fn: String::new(),
        con_ret_tys: HashMap::new(),
        array_ret_tys: HashMap::new(),
        call_ret_tys: HashMap::new(),
        int_lit_vars: Vec::new(),
    };
    let mut env: Env = inf.base_env();

    // constructor sets per data type (for exhaustiveness). `Bool` is built in.
    for d in &module.datas {
        inf.data_cons.insert(
            d.name.clone(),
            d.cons.iter().map(|c| c.name.clone()).collect(),
        );
    }
    inf.data_cons
        .insert("Bool".into(), vec!["True".into(), "False".into()]);

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
    // `Integral` (`div`/`mod`) over Int or Integer — infix truncated division and
    // remainder (§Listing 1.4). Kept separate from `Num` because `Float` has no
    // instance (a `div`/`mod` over `Float` is correctly rejected AX0404).
    for op in ["div", "mod"] {
        inf.method_meta
            .insert(op.to_string(), ("Integral".to_string(), Some(0)));
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

    // metadata of the constrained functions: for EACH constraint var, the index of
    // the 1st parameter whose type is (or nests) that var — the specialization
    // "dispatch". Multiple entries make a `(Show a, Show b) =>` instance specialize
    // on the whole vector.
    for f in &module.funcs {
        if f.constraints.is_empty() {
            continue;
        }
        let meta: Vec<(String, Option<(usize, bool)>)> = f
            .constraints
            .iter()
            .map(|(_, cvar)| {
                let idx = f.sig.as_ref().and_then(|s| {
                    s.param_types().iter().enumerate().find_map(|(i, p)| {
                        if matches!(p, Type::Var(v) if v == cvar) {
                            Some((i, false)) // the parameter IS the constraint var
                        } else if type_contains_var(p, cvar) {
                            Some((i, true)) // nested, e.g. `Maybe a` / `List a`
                        } else {
                            None
                        }
                    })
                });
                (cvar.clone(), idx)
            })
            .collect();
        inf.constrained_meta.insert(f.name.clone(), meta);
    }

    // metadata of the GENERIC-OWNING functions (Phase B): an unconstrained
    // function with an owned `%1` parameter whose type carries exactly ONE type
    // variable (`dropList :: List a %1 -> Int`). The param's drop-type key is
    // unresolvable at lowering (the element is a var), so the function is
    // monomorphized per concrete call-site type (`dropList$P`). Multi-var
    // params and constrained functions are excluded (see `owned_meta`).
    for f in &module.funcs {
        if !f.constraints.is_empty() {
            continue;
        }
        let Some(sig) = &f.sig else { continue };
        let mults = sig.param_mults();
        let ptypes = sig.param_types();
        let mut owned = Vec::new();
        for (i, p) in ptypes.iter().enumerate() {
            if mults.get(i) != Some(&Mult::One) {
                continue;
            }
            // a bare var param is not heap (i64 ABI) — no key to resolve;
            // only heap-shaped (`App`/`Tuple`) owned params can leak payloads.
            if matches!(p, Type::Var(_)) {
                continue;
            }
            let vars = var_paths(p);
            if !vars.is_empty() {
                owned.push((i, vars));
            }
        }
        if !owned.is_empty() {
            inf.owned_meta.insert(f.name.clone(), owned);
        }
    }

    let _ = placeholders; // built above for the (now-removed) vestigial use
    (inf, env)
}

impl Infer<'_> {
    /// Infer one function's body against `env` (checking mode when it has a
    /// signature). Emits that function's type diagnostics and accumulates its
    /// obligations (discharged in [`Infer::finish`]).
    fn check_body(&mut self, env: &Env, f: &Func) {
        let declared = env.get(&f.name).cloned().map(|s| self.instantiate(&s));
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
        self.cur_constraints = f.constraints.iter().map(|(c, _)| c.clone()).collect();
        self.cur_fn = f.name.clone();
        // for a MULTI-constraint function, record which inference var each
        // constraint var was instantiated to, by walking the signature alongside
        // the instantiated `declared` type. Lets discharge tell which constraint a
        // polymorphic method use dispatches over. (Single-constraint doesn't need
        // it — the sole cvar is index 0 — so skip the work.)
        if f.constraints.len() > 1 {
            if let (Some(sig), Some(decl)) = (&f.sig, &declared) {
                let mut binding = HashMap::new();
                bind_sig_vars(sig, decl, &mut binding);
                let ivars = f
                    .constraints
                    .iter()
                    .map(|(_, v)| binding.get(v).cloned().unwrap_or_else(|| self.fresh()))
                    .collect();
                self.cvar_ivars.insert(f.name.clone(), ivars);
            }
        }
        let inferred = self.infer_func(env, f, expected);
        if let Some(d) = &declared {
            self.unify(&inferred, d, f.span);
        }
    }

    /// The post-passes: integer-literal defaulting, exhaustiveness, obligation
    /// discharge, and the monomorphization artifacts. Runs over whatever bodies
    /// were checked (all of them for [`infer`], one for a per-decl partial).
    fn finish(&mut self, module: &Module) -> Mono {
        let inf = self;
    // Phase 1b: resolve each integer literal. If context unified it to `Integer`,
    // mark it for the `fromInt` rewrite; otherwise unify it with `Int` — this both
    // defaults an unconstrained literal and re-raises the original error if a literal
    // was forced to a non-`Int` type (e.g. `Int` vs `Float`).
    let lit_vars = std::mem::take(&mut inf.int_lit_vars);
    let mut integer_lits: std::collections::HashSet<Span> = std::collections::HashSet::new();
    for (span, v) in lit_vars {
        if matches!(inf.apply(&v), Ty::Con(ref n, _) if n == "Integer") {
            integer_lits.insert(span);
        } else {
            inf.unify(&v, &Ty::Con("Int".into(), vec![]), span);
        }
    }
    inf.check_exhaustiveness();
    let mut mono = inf.discharge_obligations(module);
    mono.integer_lits = integer_lits;
    // Phase B (generic-owning corner): the owning-generic specializations
    // (`dropList$P`), merged with the typeclass ones.
    let owning = inf.discharge_owning();
    mono.resolutions.extend(owning.resolutions);
    mono.specs.extend(owning.specs);
    // Phase 4: resolve + convert constructor return types before passing on
    let con_tys = std::mem::take(&mut inf.con_ret_tys);
    mono.makecon_tys = con_tys
        .into_iter()
        .filter_map(|(sp, ty)| {
            let resolved = inf.apply(&ty);
            ty_to_ast(&resolved).map(|ast| (sp, ast))
        })
        .collect();
    // Phase 2c array: resolve + convert `newArray` return types for mono
    // destructor generation (Array$List$P, etc.)
    let array_tys = std::mem::take(&mut inf.array_ret_tys);
    mono.array_tys = array_tys
        .into_iter()
        .filter_map(|(sp, ty)| {
            let resolved = inf.apply(&ty);
            ty_to_ast(&resolved).map(|ast| (sp, ast))
        })
        .collect();
    // Phase 4: merge call-site result types into `makecon_tys` (a shared span→Type
    // map, already threaded to every backend). Call spans are disjoint from
    // constructor spans, and the `MakeCon` lowering only looks up constructor spans,
    // so this is safe and needs no extra plumbing — the lowering reads the same map
    // for a `CallDirect`'s concrete drop key.
    let call_tys = std::mem::take(&mut inf.call_ret_tys);
    for (sp, ty) in call_tys {
        let resolved = inf.apply(&ty);
        if let Some(ast) = ty_to_ast(&resolved) {
            mono.makecon_tys.entry(sp).or_insert(ast);
        }
    }
        mono
    }
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

/// The built-in `Integral` operators (`div`/`mod`) — overloaded over Int/Integer.
pub fn is_integral_method(op: &str) -> bool {
    matches!(op, "div" | "mod")
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

/// Integer (§ Listing 1.4) counterparts, resolved like the Float ones — the
/// executors lower `#I` operators to the arbitrary-precision runtime (`axion_bignum_*`).
pub fn builtin_op_integer(op: &str) -> &'static str {
    match op {
        "+" => "+#I",
        "-" => "-#I",
        "*" => "*#I",
        "==" => "==#I",
        "<" => "<#I",
        ">" => ">#I",
        "div" => "div#I",
        "mod" => "mod#I",
        _ => unreachable!("not a built-in overloaded operator: {op}"),
    }
}

/// Whether the type variable `var` occurs anywhere in the (surface) type `t`.
fn type_contains_var(t: &Type, var: &str) -> bool {
    match t {
        Type::Var(v) => v == var,
        Type::App(f, a) => type_contains_var(f, var) || type_contains_var(a, var),
        Type::Arrow { from, to, .. } => type_contains_var(from, var) || type_contains_var(to, var),
        Type::Tuple(ts) => ts.iter().any(|x| type_contains_var(x, var)),
        _ => false,
    }
}

/// The type variables (by name) occurring in the surface type `t`.
fn type_vars(t: &Type, out: &mut HashSet<String>) {
    match t {
        Type::Var(v) => {
            out.insert(v.clone());
        }
        Type::App(f, a) => {
            type_vars(f, out);
            type_vars(a, out);
        }
        Type::Arrow { from, to, .. } => {
            type_vars(from, out);
            type_vars(to, out);
        }
        Type::Tuple(ts) => ts.iter().for_each(|x| type_vars(x, out)),
        _ => {}
    }
}

/// All type-variable occurrences in `t`, each with its positional path.
/// Multi-var owning params (e.g. `Tree a b`) return both vars' paths.
fn var_paths(t: &Type) -> Vec<(String, Vec<usize>)> {
    fn walk(t: &Type, var: &str, acc: &mut Vec<usize>) -> Option<Vec<usize>> {
        match t {
            Type::Var(v) if v == var => Some(acc.clone()),
            Type::App(f, a) => {
                // search the argument (as before — it matches the `Ty::Con`
                // argument list), and then the head for nested vars.
                acc.push(0);
                if let Some(r) = walk(a, var, acc) {
                    acc.pop();
                    return Some(r);
                }
                acc.pop();
                walk(f, var, acc)
            }
            Type::Tuple(ts) => {
                for (i, x) in ts.iter().enumerate() {
                    acc.push(i);
                    if let Some(r) = walk(x, var, acc) {
                        return Some(r);
                    }
                    acc.pop();
                }
                None
            }
            _ => None,
        }
    }
    let mut vars = HashSet::new();
    type_vars(t, &mut vars);
    let mut out = Vec::new();
    for var in &vars {
        if let Some(path) = walk(t, var, &mut Vec::new()) {
            out.push((var.clone(), path));
        }
    }
    // stable order so mangle is deterministic
    out.sort_by(|a, b| a.0.cmp(&b.0));
    out
}

/// The AST form of a fully-concrete inferred type (the Phase B signature
/// substitution): `Ty::Con("P", [])` → `P`, `Ty::Con("Maybe", [P])` →
/// `Maybe P`. None if any part is unresolved (a var or a function) — the seed
/// then stays generic.
fn ty_to_ast(t: &Ty) -> Option<Type> {
    match t {
        Ty::Con(n, args) => {
            let mut x = Type::Con(n.clone());
            for a in args {
                x = Type::App(Box::new(x), Box::new(ty_to_ast(a)?));
            }
            Some(x)
        }
        Ty::Tuple(ts) => Some(Type::Tuple(
            ts.iter().map(ty_to_ast).collect::<Option<Vec<_>>>()?,
        )),
        Ty::Var(_) | Ty::Fun(..) => None,
    }
}

/// The spec-name mangle of a substitution type: `P` → `P`, `Maybe P` →
/// `Maybe$P`. Matches the destructor-key mangling (`mono_key`, core.rs) so the
/// names stay readable (`dropList$Maybe$P` ↔ `axion_drop_List$Maybe$P`).
fn ty_mangle(t: &Type) -> String {
    match t {
        Type::Con(n) => n.clone(),
        Type::App(f, a) => format!("{}${}", ty_mangle(f), ty_mangle(a)),
        Type::Tuple(ts) => format!(
            "({})",
            ts.iter().map(ty_mangle).collect::<Vec<_>>().join(",")
        ),
        _ => String::new(),
    }
}

// --- monomorphic `Show` synthesis (see `Mono::synth_shows`) ------------------
//
// Two kinds of type have no usable nominal `Show` instance the single-`t`
// monomorphizer can specialize: TUPLES (anonymous — no instance at all) and
// MULTI-PARAM derived data (`Either a b` — the machinery only substitutes the
// FIRST constraint var, so `show (Right True)` mis-dispatches the `b` field).
// For both, we synthesize a monomorphic `show$<mangle>` / `showArg$<mangle>` per
// concrete shape, resolving each component/field at its OWN concrete type. Every
// name keys on `ty_mangle`, so it matches whatever the surrounding specialization
// machinery rewrites an internal `show`/`showArg` to (`show$List$(Int,Int)`'s
// body calls `show$(Int,Int)`), which is what makes composition connect.

/// The `show`/`showArg` impl name for a concrete type: `show$Int`,
/// `showArg$List$Int`, `show$(Int,Int)`, `showArg$Either$Int$Bool` — always
/// `<method>$<ty_mangle>`.
fn show_impl_name(method: &str, t: &Type) -> String {
    format!("{method}${}", ty_mangle(t))
}

/// Head constructor + concrete arguments of an applied type
/// (`App(App(Con Either, Int), Bool)` → `("Either", [Int, Bool])`).
fn flatten_app_ty(t: &Type) -> (Option<&str>, Vec<Type>) {
    match t {
        Type::Con(n) => (Some(n.as_str()), Vec::new()),
        Type::App(f, a) => {
            let (h, mut args) = flatten_app_ty(f);
            args.push((**a).clone());
            (h, args)
        }
        _ => (None, Vec::new()),
    }
}

/// A data type with 2+ parameters that derives `Show` — the case the single-`t`
/// specializer gets wrong, so we synthesize it monomorphically instead.
fn is_multi_derived_show(name: &str, nargs: usize, decls: &HashMap<&str, &DataDecl>) -> bool {
    decls.get(name).is_some_and(|d| {
        d.params.len() == nargs && nargs >= 2 && d.deriving.iter().any(|c| c == "Show")
    })
}

/// Whether `ty` needs monomorphic synthesis anywhere inside it (a tuple, or a
/// multi-param derived-`Show` data type). Keeps ordinary programs off this path.
fn type_needs_synth(t: &Type, decls: &HashMap<&str, &DataDecl>) -> bool {
    match t {
        Type::Tuple(_) => true,
        _ => {
            let (head, args) = flatten_app_ty(t);
            (matches!(head, Some(h) if is_multi_derived_show(h, args.len(), decls)))
                || args.iter().any(|a| type_needs_synth(a, decls))
        }
    }
}

fn subst_type(t: &Type, sub: &HashMap<String, Type>) -> Type {
    match t {
        Type::Var(v) => sub.get(v).cloned().unwrap_or_else(|| t.clone()),
        Type::Con(_) | Type::Unit => t.clone(),
        Type::App(f, a) => Type::App(Box::new(subst_type(f, sub)), Box::new(subst_type(a, sub))),
        Type::Arrow { mult, from, to } => Type::Arrow {
            mult: *mult,
            from: Box::new(subst_type(from, sub)),
            to: Box::new(subst_type(to, sub)),
        },
        Type::Tuple(ts) => Type::Tuple(ts.iter().map(|x| subst_type(x, sub)).collect()),
    }
}

/// The mangle key of a data instantiation (`Either$Int$Bool`).
fn data_show_key(name: &str, args: &[Type]) -> String {
    let parts: Vec<String> = args.iter().map(ty_mangle).collect();
    format!("{name}${}", parts.join("$"))
}

/// The applied AST type of a data instantiation (`Either Int Bool`).
fn applied_ty(name: &str, args: &[Type]) -> Type {
    args.iter().fold(Type::Con(name.into()), |acc, a| {
        Type::App(Box::new(acc), Box::new(a.clone()))
    })
}

/// The method a derived instance calls on each FIELD: `Show`→`showArg` (nesting
/// parens), `Eq`→`eq`, `Ord`→`le`.
fn class_field_method(class: &str) -> &'static str {
    match class {
        "Eq" => "eq",
        "Ord" => "le",
        _ => "showArg",
    }
}

/// Collects the concrete tuple / multi-param-data shapes a program derives
/// `Show`/`Eq`/`Ord` over, plus the extra spec seeds their parametric sub-parts
/// need. Owns its accumulators (merged into the discharge locals afterward) to
/// stay out of the loop's borrows. Tuples are `Show`-only (no tuple Eq/Ord).
#[derive(Default)]
struct SynthNeeds {
    tuples: Vec<Vec<Type>>,                    // tuple shapes → `show$(…)`
    datas: Vec<(String, String, Vec<Type>)>,   // (class, data, args) → `<m>$Name$…`
    seeds: Vec<(String, Span, String, String)>, // extra method_seeds (parametric parts)
    key_types: Vec<(String, Type)>,            // extra key_types entries
    missing: Vec<(String, Type, Span)>,        // (class, field type, span) → AX0404
}

impl SynthNeeds {
    // --- Show (tuples + multi-param data; container-composition aware) --------

    /// Ensure `show`/`showArg` for `ty` (and everything it transitively needs)
    /// will exist after synthesis + specialization.
    fn note_show(&mut self, ty: &Type, decls: &HashMap<&str, &DataDecl>) {
        if let Type::Tuple(inner) = ty {
            self.note_tuple(inner, decls);
            return;
        }
        let (head, args) = flatten_app_ty(ty);
        let Some(h) = head else { return };
        if args.is_empty() {
            return; // nullary `Con` (Int/Bool/…): `show$Con` already exists.
        }
        if is_multi_derived_show(h, args.len(), decls) {
            self.note_show_data(h, &args, decls);
            return;
        }
        // 1-param parametric container (`List a`/`Maybe a`): seed its
        // `show`/`showArg` spec at the element key so the existing machinery
        // materializes it, then recurse to catch tuples/multi-data deeper. The
        // bogus caller/span only forces the spec; no real site rewrites to it.
        for arg in &args {
            let ak = ty_mangle(arg);
            if matches!(arg, Type::App(..) | Type::Tuple(_)) {
                self.key_types.push((ak.clone(), arg.clone()));
            }
            for m in ["show", "showArg"] {
                let base = crate::ast::method_impl_name(m, h);
                self.seeds.push(("$show_synth_seed".into(), (0, 0), base, ak.clone()));
            }
            self.note_show(arg, decls);
        }
    }

    fn note_tuple(&mut self, comps: &[Type], decls: &HashMap<&str, &DataDecl>) {
        if self.tuples.iter().any(|c| c == comps) {
            return;
        }
        self.tuples.push(comps.to_vec());
        for c in comps {
            self.note_show(c, decls);
        }
    }

    fn note_show_data(&mut self, name: &str, args: &[Type], decls: &HashMap<&str, &DataDecl>) {
        if self.has_data("Show", name, args) {
            return;
        }
        self.datas.push(("Show".into(), name.to_string(), args.to_vec()));
        if let Some(d) = decls.get(name) {
            let sub = data_subst(d, args);
            for con in &d.cons {
                for f in &con.fields {
                    self.note_show(&subst_type(&f.ty, &sub), decls);
                }
            }
        }
    }

    // --- Eq / Ord (multi-param data; every field must have the instance) ------

    /// Ensure `eq`/`le` for a multi-param derived `class` instantiation exists.
    /// Returns whether it is synthesizable (every field has the instance) — a
    /// missing field is recorded for an AX0404, and nothing is synthesized.
    fn note_eqord_data(
        &mut self,
        class: &str,
        name: &str,
        args: &[Type],
        span: Span,
        decls: &HashMap<&str, &DataDecl>,
        instances: &std::collections::HashSet<(String, String)>,
    ) -> bool {
        if self.has_data(class, name, args) {
            return true; // already validated (also breaks recursive-type cycles)
        }
        let Some(d) = decls.get(name) else {
            return false;
        };
        // optimistic insert so a recursive field re-enters as already-known.
        self.datas.push((class.into(), name.to_string(), args.to_vec()));
        let sub = data_subst(d, args);
        let mut ok = true;
        for con in &d.cons {
            for f in &con.fields {
                if !self.note_eqord_field(class, &subst_type(&f.ty, &sub), span, decls, instances) {
                    ok = false;
                }
            }
        }
        if !ok {
            self.datas.retain(|(c, n, a)| !(c == class && n == name && a == args));
        }
        ok
    }

    /// Whether `class`'s method exists for a field of type `ty`, seeding any
    /// parametric spec it needs. A field with no instance is recorded (AX0404).
    fn note_eqord_field(
        &mut self,
        class: &str,
        ty: &Type,
        span: Span,
        decls: &HashMap<&str, &DataDecl>,
        instances: &std::collections::HashSet<(String, String)>,
    ) -> bool {
        let (head, args) = flatten_app_ty(ty);
        let Some(h) = head else {
            // a tuple (or bare var): no Eq/Ord instance exists for it.
            self.missing.push((class.into(), ty.clone(), span));
            return false;
        };
        if !instances.contains(&(class.into(), h.to_string())) {
            self.missing.push((class.into(), ty.clone(), span));
            return false;
        }
        if args.is_empty() {
            return true; // base con with instance (`eq$Int`, `le$Bool`, …).
        }
        if is_multi_derived_show(h, args.len(), decls) {
            return self.note_eqord_data(class, h, &args, span, decls, instances);
        }
        // 1-param parametric WITH the instance (`Opt a` derives Eq): seed its
        // spec at the element key, then validate the element too.
        let m = class_field_method(class);
        let mut ok = true;
        for arg in &args {
            let ak = ty_mangle(arg);
            if matches!(arg, Type::App(..) | Type::Tuple(_)) {
                self.key_types.push((ak.clone(), arg.clone()));
            }
            let base = crate::ast::method_impl_name(m, h);
            self.seeds.push(("$eqord_synth_seed".into(), (0, 0), base, ak.clone()));
            if !self.note_eqord_field(class, arg, span, decls, instances) {
                ok = false;
            }
        }
        ok
    }

    fn has_data(&self, class: &str, name: &str, args: &[Type]) -> bool {
        self.datas
            .iter()
            .any(|(c, n, a)| c == class && n == name && a == args)
    }

    /// Names every synthesized function will exist under. The spec-validity check
    /// consults these (the functions are injected AFTER inference, so
    /// `func_names` doesn't list them).
    fn names(&self) -> std::collections::HashSet<String> {
        let mut s = std::collections::HashSet::new();
        for c in &self.tuples {
            let k = ty_mangle(&Type::Tuple(c.clone()));
            s.insert(format!("show${k}"));
            s.insert(format!("showArg${k}"));
        }
        for (class, n, a) in &self.datas {
            let k = data_show_key(n, a);
            if class == "Show" {
                s.insert(format!("show${k}"));
                s.insert(format!("showArg${k}"));
            } else {
                s.insert(format!("{}${k}", class_field_method(class)));
            }
        }
        s
    }
}

fn data_subst(d: &DataDecl, args: &[Type]) -> HashMap<String, Type> {
    d.params.iter().cloned().zip(args.iter().cloned()).collect()
}

/// Builds every synthesized `ast::Func`: `show`/`showArg` per tuple shape and per
/// multi-param `Show` data, and `eq`/`le` per multi-param `Eq`/`Ord` data — each
/// component/field call already resolved to its concrete `<method>$<mangle>` impl.
fn synth_show_funcs(needs: &SynthNeeds, decls: &HashMap<&str, &DataDecl>) -> Vec<Func> {
    const SP: Span = (0, 0);
    let sapp = |f: Expr, a: Expr| Expr::App(Box::new(f), Box::new(a), SP);
    let sapp2 = move |f: &str, a: Expr, b: Expr| sapp(sapp(Expr::Var(f.into(), SP), a), b);
    let strcat = move |a: Expr, b: Expr| sapp2("strAppend", a, b);
    let var = |n: &str| Expr::Var(n.into(), SP);
    let mk = |name: String, params: Vec<&str>, sig: Type, body: Expr| Func {
        name,
        sig: Some(sig),
        clauses: vec![Clause {
            pats: params.iter().map(|p| Pat::Var((*p).into(), SP)).collect(),
            body: Body::Plain(body),
            wher: Vec::new(),
            span: SP,
        }],
        span: SP,
        constraints: Vec::new(),
    };
    let arrow = |from: Type, to: Type| Type::Arrow {
        mult: Mult::Many,
        from: Box::new(from),
        to: Box::new(to),
    };
    let mut out = Vec::new();

    // tuples: `f p = case p of (c0, …) -> "(" ++ show c0 ++ ", " ++ … ++ ")"`.
    for comps in &needs.tuples {
        let vars: Vec<String> = (0..comps.len()).map(|i| format!("c{i}")).collect();
        let mut body = Expr::Str(")".into(), SP);
        for i in (0..comps.len()).rev() {
            // components use `show` (not showArg): no extra parens inside a tuple.
            let comp = sapp(var(&show_impl_name("show", &comps[i])), var(&vars[i]));
            body = strcat(comp, body);
            if i > 0 {
                body = strcat(Expr::Str(", ".into(), SP), body);
            }
        }
        body = strcat(Expr::Str("(".into(), SP), body);
        let tuple_pat = Pat::Tuple(vars.iter().map(|v| Pat::Var(v.clone(), SP)).collect(), SP);
        let case = Expr::Case(Box::new(var("p")), vec![(tuple_pat, body)], SP);
        let from = Type::Tuple(comps.clone());
        let sig = arrow(from.clone(), Type::Con("String".into()));
        let k = ty_mangle(&from);
        // a tuple is always parenthesised → show == showArg (same body).
        out.push(mk(format!("show${k}"), vec!["p"], sig.clone(), case.clone()));
        out.push(mk(format!("showArg${k}"), vec!["p"], sig, case));
    }

    // multi-param data, re-derived monomorphically from the data decl with each
    // field's method call resolved at its concrete type.
    for (class, name, args) in &needs.datas {
        let Some(d) = decls.get(name.as_str()) else {
            continue;
        };
        let sub = data_subst(d, args);
        let key = data_show_key(name, args);
        let from = applied_ty(name, args);
        // field vars + concrete field types for a constructor, prefixed a/b.
        let con_fields = |con: &ConDecl, prefix: &str| -> (Vec<String>, Vec<Type>) {
            let vs = (0..con.fields.len()).map(|i| format!("{prefix}{i}")).collect();
            let ts = con.fields.iter().map(|f| subst_type(&f.ty, &sub)).collect();
            (vs, ts)
        };
        let con_pat = |con: &ConDecl, vs: &[String]| {
            Pat::Con(con.name.clone(), vs.iter().map(|v| Pat::Var(v.clone(), SP)).collect(), SP)
        };
        let wild_pat = |con: &ConDecl| {
            Pat::Con(con.name.clone(), con.fields.iter().map(|_| Pat::Wild(SP)).collect(), SP)
        };

        match class.as_str() {
            "Show" => {
                let arm = |wrap: bool| -> Vec<(Pat, Expr)> {
                    d.cons
                        .iter()
                        .map(|con| {
                            let (vs, ts) = con_fields(con, "a");
                            let mut body = Expr::Str(con.name.clone(), SP);
                            for (v, ft) in vs.iter().zip(&ts) {
                                let call = sapp(var(&show_impl_name("showArg", ft)), var(v));
                                body = strcat(strcat(body, Expr::Str(" ".into(), SP)), call);
                            }
                            if wrap && !con.fields.is_empty() {
                                body = strcat(strcat(Expr::Str("(".into(), SP), body), Expr::Str(")".into(), SP));
                            }
                            (con_pat(con, &vs), body)
                        })
                        .collect()
                };
                let sig = arrow(from.clone(), Type::Con("String".into()));
                let mk_case = |wrap: bool| Expr::Case(Box::new(var("x")), arm(wrap), SP);
                out.push(mk(format!("show${key}"), vec!["x"], sig.clone(), mk_case(false)));
                out.push(mk(format!("showArg${key}"), vec!["x"], sig, mk_case(true)));
            }
            // `eq x y = case x of Con a.. -> case y of Con b.. -> eq a0 b0 && …
            //                                          [_ -> False]`.
            "Eq" => {
                let multi = d.cons.len() > 1;
                let arms: Vec<(Pat, Expr)> = d
                    .cons
                    .iter()
                    .map(|con| {
                        let (avs, ts) = con_fields(con, "a");
                        let (bvs, _) = con_fields(con, "b");
                        let mut conj = Expr::Con("True".into(), SP);
                        for k in (0..con.fields.len()).rev() {
                            let call = sapp2(&show_impl_name("eq", &ts[k]), var(&avs[k]), var(&bvs[k]));
                            conj = if k == con.fields.len() - 1 {
                                call
                            } else {
                                Expr::If(Box::new(call), Box::new(conj), Box::new(Expr::Con("False".into(), SP)), SP)
                            };
                        }
                        let mut inner = vec![(con_pat(con, &bvs), conj)];
                        if multi {
                            inner.push((Pat::Wild(SP), Expr::Con("False".into(), SP)));
                        }
                        (con_pat(con, &avs), Expr::Case(Box::new(var("y")), inner, SP))
                    })
                    .collect();
                let sig = arrow(from.clone(), arrow(from, Type::Con("Bool".into())));
                let body = Expr::Case(Box::new(var("x")), arms, SP);
                out.push(mk(format!("eq${key}"), vec!["x", "y"], sig, body));
            }
            // `le x y` — lexicographic ≤ (constructors by declaration order).
            "Ord" => {
                let arms: Vec<(Pat, Expr)> = d
                    .cons
                    .iter()
                    .enumerate()
                    .map(|(i, con)| {
                        let (avs, ts) = con_fields(con, "a");
                        let (bvs, _) = con_fields(con, "b");
                        let mut inner: Vec<(Pat, Expr)> = d
                            .cons
                            .iter()
                            .take(i)
                            .map(|cj| (wild_pat(cj), Expr::Con("False".into(), SP)))
                            .collect();
                        let mut lexi = Expr::Con("True".into(), SP);
                        for k in (0..con.fields.len()).rev() {
                            let le_ab = sapp2(&show_impl_name("le", &ts[k]), var(&avs[k]), var(&bvs[k]));
                            lexi = if k == con.fields.len() - 1 {
                                le_ab
                            } else {
                                let le_ba = sapp2(&show_impl_name("le", &ts[k]), var(&bvs[k]), var(&avs[k]));
                                let inner_if = Expr::If(Box::new(le_ba), Box::new(lexi), Box::new(Expr::Con("True".into(), SP)), SP);
                                Expr::If(Box::new(le_ab), Box::new(inner_if), Box::new(Expr::Con("False".into(), SP)), SP)
                            };
                        }
                        inner.push((con_pat(con, &bvs), lexi));
                        inner.push((Pat::Wild(SP), Expr::Con("True".into(), SP)));
                        (con_pat(con, &avs), Expr::Case(Box::new(var("y")), inner, SP))
                    })
                    .collect();
                let sig = arrow(from.clone(), arrow(from, Type::Con("Bool".into())));
                let body = Expr::Case(Box::new(var("x")), arms, SP);
                out.push(mk(format!("le${key}"), vec!["x", "y"], sig, body));
            }
            _ => {}
        }
    }
    out
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

/// The id of an inference variable, if `t` is one (else `None`).
fn var_id(t: &Ty) -> Option<u32> {
    match t {
        Ty::Var(v) => Some(*v),
        _ => None,
    }
}

/// Walks an AST signature alongside its instantiated inference type, recording the
/// inference var each named type var maps to (first occurrence wins). Positions
/// line up because `declared` came from instantiating this same signature.
fn bind_sig_vars(ast: &Type, ty: &Ty, out: &mut HashMap<String, Ty>) {
    match ast {
        Type::Var(n) => {
            out.entry(n.clone()).or_insert_with(|| ty.clone());
        }
        Type::App(..) => {
            let (_, args) = flatten_app(ast);
            if let Ty::Con(_, targs) = ty {
                for (a, t) in args.iter().zip(targs) {
                    bind_sig_vars(a, t, out);
                }
            }
        }
        Type::Arrow { from, to, .. } => {
            if let Ty::Fun(f, t) = ty {
                bind_sig_vars(from, f, out);
                bind_sig_vars(to, t, out);
            }
        }
        Type::Tuple(ts) => {
            if let Ty::Tuple(tts) = ty {
                for (a, t) in ts.iter().zip(tts) {
                    bind_sig_vars(a, t, out);
                }
            }
        }
        Type::Con(_) | Type::Unit => {}
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
        // Show primitives (the `class Show` base instances live in the prelude):
        // showInt :: Int -> String, showFloat :: Float -> String.
        env.insert(
            "showInt".into(),
            mono(Ty::Fun(Box::new(int()), Box::new(string()))),
        );
        env.insert(
            "showFloat".into(),
            mono(Ty::Fun(
                Box::new(Ty::Con("Float".into(), vec![])),
                Box::new(string()),
            )),
        );
        // Integer (§ Listing 1.4): fromInt :: Int -> Integer, showInteger :: Integer -> String.
        let integer = || Ty::Con("Integer".into(), vec![]);
        env.insert(
            "fromInt".into(),
            mono(Ty::Fun(Box::new(int()), Box::new(integer()))),
        );
        // bignumFromStr :: String -> Integer — the desugaring of a literal > i64.
        env.insert(
            "bignumFromStr".into(),
            mono(Ty::Fun(Box::new(string()), Box::new(integer()))),
        );
        env.insert(
            "showInteger".into(),
            mono(Ty::Fun(Box::new(integer()), Box::new(string()))),
        );
        // Integer truncated division / remainder :: Integer -> Integer -> Integer.
        let int_binop = || {
            mono(Ty::Fun(
                Box::new(integer()),
                Box::new(Ty::Fun(Box::new(integer()), Box::new(integer()))),
            ))
        };
        env.insert("divInteger".into(), int_binop());
        env.insert("modInteger".into(), int_binop());
        // strAppend :: String -> String -> String (native string concatenation)
        env.insert(
            "strAppend".into(),
            mono(Ty::Fun(
                Box::new(string()),
                Box::new(Ty::Fun(Box::new(string()), Box::new(string()))),
            )),
        );
        env.insert("True".into(), mono(bool()));
        env.insert("False".into(), mono(bool()));
        env.insert("otherwise".into(), mono(bool()));
        // `+ - *` (Num) and `div`/`mod` (Integral) are built-in overloaded operators
        // (`a -> a -> a`), resolved per use over Int/Integer — see `discharge_obligations`.
        for op in ["+", "-", "*", "div", "mod"] {
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
            env.insert(
                f.into(),
                mono(Ty::Fun(Box::new(float()), Box::new(float()))),
            );
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
        // parMap :: forall a b c d. (Ep a -> b) -> List c -> List d
        // structured fork-join (§9): spawns one worker per input, sends inputs[i]
        // to worker i, recvs result[i], returns the results as a List — its own
        // self-contained nursery (no `bound` needed). HM is permissive like
        // `spawn`: the payloads are erased at the endpoint, so inputs/outputs are
        // not tied to the worker's protocol here (that is `check_sessions`'s job).
        let list = |v: u32| Ty::Con("List".into(), vec![Ty::Var(v)]);
        env.insert(
            "parMap".into(),
            Scheme {
                vars: vec![0, 1, 2, 3],
                ty: Ty::Fun(
                    Box::new(Ty::Fun(Box::new(ep(0)), Box::new(Ty::Var(1)))),
                    Box::new(Ty::Fun(Box::new(list(2)), Box::new(list(3)))),
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
        // linear dense Array (§A): all ops on raw i64 Array pointers.
        let arra_ty = || Ty::Con("Array".into(), vec![Ty::Var(0)]);
        // newArray :: Int -> Int -> Array a
        env.insert(
            "newArray".into(),
            Scheme {
                vars: vec![0],
                ty: Ty::Fun(
                    Box::new(int()),
                    Box::new(Ty::Fun(Box::new(int()), Box::new(arra_ty()))),
                ),
            },
        );
        // getArray :: Array a -> Int -> Int
        env.insert(
            "getArray".into(),
            Scheme {
                vars: vec![0],
                ty: Ty::Fun(
                    Box::new(arra_ty()),
                    Box::new(Ty::Fun(Box::new(int()), Box::new(int()))),
                ),
            },
        );
        // setArray :: Array a -> Int -> Int -> Array a
        env.insert(
            "setArray".into(),
            Scheme {
                vars: vec![0],
                ty: Ty::Fun(
                    Box::new(arra_ty()),
                    Box::new(Ty::Fun(
                        Box::new(int()),
                        Box::new(Ty::Fun(Box::new(int()), Box::new(arra_ty()))),
                    )),
                ),
            },
        );
        // lenArray :: Array a -> Int
        env.insert(
            "lenArray".into(),
            Scheme {
                vars: vec![0],
                ty: Ty::Fun(Box::new(arra_ty()), Box::new(int())),
            },
        );
        // TritVec (§10): base-243 packed balanced-ternary array. Monomorphic (the
        // element is a ternary WEIGHT -1/0/+1 carried as Int); `newTritVec` takes
        // (len, initWeight).  A linear resource like Array (setTritVec is in-place).
        let tvec_ty = || Ty::Con("TritVec".into(), vec![]);
        // newTritVec :: Int -> Int -> TritVec
        env.insert(
            "newTritVec".into(),
            Scheme {
                vars: vec![],
                ty: Ty::Fun(
                    Box::new(int()),
                    Box::new(Ty::Fun(Box::new(int()), Box::new(tvec_ty()))),
                ),
            },
        );
        // getTritVec :: TritVec -> Int -> Int
        env.insert(
            "getTritVec".into(),
            Scheme {
                vars: vec![],
                ty: Ty::Fun(
                    Box::new(tvec_ty()),
                    Box::new(Ty::Fun(Box::new(int()), Box::new(int()))),
                ),
            },
        );
        // setTritVec :: TritVec -> Int -> Int -> TritVec
        env.insert(
            "setTritVec".into(),
            Scheme {
                vars: vec![],
                ty: Ty::Fun(
                    Box::new(tvec_ty()),
                    Box::new(Ty::Fun(
                        Box::new(int()),
                        Box::new(Ty::Fun(Box::new(int()), Box::new(tvec_ty()))),
                    )),
                ),
            },
        );
        // lenTritVec :: TritVec -> Int
        env.insert(
            "lenTritVec".into(),
            Scheme {
                vars: vec![],
                ty: Ty::Fun(Box::new(tvec_ty()), Box::new(int())),
            },
        );
        // tritMatVecSum :: TritVec -> Array Int -> Int -> Int — ternary matvec (§10),
        // borrows both; the 3rd arg is the row width K (a small reused activation).
        env.insert(
            "tritMatVecSum".into(),
            Scheme {
                vars: vec![],
                ty: Ty::Fun(
                    Box::new(tvec_ty()),
                    Box::new(Ty::Fun(
                        Box::new(Ty::Con("Array".into(), vec![int()])),
                        Box::new(Ty::Fun(Box::new(int()), Box::new(int()))),
                    )),
                ),
            },
        );
        // tritVecIota :: Int -> TritVec — bulk builder, weight(i)=(i mod 3)-1.
        env.insert(
            "tritVecIota".into(),
            Scheme {
                vars: vec![],
                ty: Ty::Fun(Box::new(int()), Box::new(tvec_ty())),
            },
        );
        // arrayIota :: Int -> Array Int — bulk builder, a[i]=i.
        env.insert(
            "arrayIota".into(),
            Scheme {
                vars: vec![],
                ty: Ty::Fun(Box::new(int()), Box::new(Ty::Con("Array".into(), vec![int()]))),
            },
        );
        // I8Array (Phase B): compact signed-byte array. Monomorphic (elements are
        // signed bytes carried as Int).
        let i8a_ty = || Ty::Con("I8Array".into(), vec![]);
        // newI8Array :: Int -> Int -> I8Array
        env.insert(
            "newI8Array".into(),
            Scheme {
                vars: vec![],
                ty: Ty::Fun(
                    Box::new(int()),
                    Box::new(Ty::Fun(Box::new(int()), Box::new(i8a_ty()))),
                ),
            },
        );
        // i8Iota :: Int -> I8Array  (bulk builder, a[i]=(i mod 3)-1)
        env.insert(
            "i8Iota".into(),
            Scheme {
                vars: vec![],
                ty: Ty::Fun(Box::new(int()), Box::new(i8a_ty())),
            },
        );
        // getI8 :: I8Array -> Int -> Int
        env.insert(
            "getI8".into(),
            Scheme {
                vars: vec![],
                ty: Ty::Fun(
                    Box::new(i8a_ty()),
                    Box::new(Ty::Fun(Box::new(int()), Box::new(int()))),
                ),
            },
        );
        // setI8 :: I8Array -> Int -> Int -> I8Array
        env.insert(
            "setI8".into(),
            Scheme {
                vars: vec![],
                ty: Ty::Fun(
                    Box::new(i8a_ty()),
                    Box::new(Ty::Fun(
                        Box::new(int()),
                        Box::new(Ty::Fun(Box::new(int()), Box::new(i8a_ty()))),
                    )),
                ),
            },
        );
        // lenI8 :: I8Array -> Int
        env.insert(
            "lenI8".into(),
            Scheme {
                vars: vec![],
                ty: Ty::Fun(Box::new(i8a_ty()), Box::new(int())),
            },
        );
        // i8MatVecSum :: I8Array -> Array Int -> Int -> Int — int8 matvec, borrows both.
        env.insert(
            "i8MatVecSum".into(),
            Scheme {
                vars: vec![],
                ty: Ty::Fun(
                    Box::new(i8a_ty()),
                    Box::new(Ty::Fun(
                        Box::new(Ty::Con("Array".into(), vec![int()])),
                        Box::new(Ty::Fun(Box::new(int()), Box::new(int()))),
                    )),
                ),
            },
        );
        // --- general dense-array primitives ---
        let arr_int = || Ty::Con("Array".into(), vec![int()]);
        let fun2 = |a: Ty, b: Ty, c: Ty| Ty::Fun(Box::new(a), Box::new(Ty::Fun(Box::new(b), Box::new(c))));
        let fun3 = |a: Ty, b: Ty, c: Ty, d: Ty| {
            Ty::Fun(
                Box::new(a),
                Box::new(Ty::Fun(Box::new(b), Box::new(Ty::Fun(Box::new(c), Box::new(d))))),
            )
        };
        let mono = |ty: Ty| Scheme { vars: vec![], ty };
        // Array Int fused reductions
        env.insert("arraySum".into(), mono(Ty::Fun(Box::new(arr_int()), Box::new(int()))));
        env.insert("arrayDot".into(), mono(fun2(arr_int(), arr_int(), int())));
        // I8Array reductions
        env.insert("i8Sum".into(), mono(Ty::Fun(Box::new(i8a_ty()), Box::new(int()))));
        env.insert("i8Dot".into(), mono(fun2(i8a_ty(), arr_int(), int())));
        env.insert("i8DotI8".into(), mono(fun2(i8a_ty(), i8a_ty(), int())));
        // I32Array: compact int32 array
        let i32a_ty = || Ty::Con("I32Array".into(), vec![]);
        env.insert("newI32Array".into(), mono(fun2(int(), int(), i32a_ty())));
        env.insert("i32Iota".into(), mono(Ty::Fun(Box::new(int()), Box::new(i32a_ty()))));
        env.insert("getI32".into(), mono(fun2(i32a_ty(), int(), int())));
        env.insert("setI32".into(), mono(fun3(i32a_ty(), int(), int(), i32a_ty())));
        env.insert("lenI32".into(), mono(Ty::Fun(Box::new(i32a_ty()), Box::new(int()))));
        env.insert("i32Sum".into(), mono(Ty::Fun(Box::new(i32a_ty()), Box::new(int()))));
        env.insert("i32Dot".into(), mono(fun2(i32a_ty(), arr_int(), int())));
        env.insert("i32MatVecSum".into(), mono(fun3(i32a_ty(), arr_int(), int(), int())));
        // tritDot :: TritVec -> Array Int -> Int — fused ternary dot product (§10),
        // borrows both, returns the scalar sum_i weight(i) * acts[i].
        env.insert(
            "tritDot".into(),
            Scheme {
                vars: vec![],
                ty: Ty::Fun(
                    Box::new(tvec_ty()),
                    Box::new(Ty::Fun(
                        Box::new(Ty::Con("Array".into(), vec![int()])),
                        Box::new(int()),
                    )),
                ),
            },
        );
        // tritVecFromBuffer :: forall a. Buffer a -> Int -> TritVec — wrap pre-packed
        // base-243 bytes; borrows the buffer, produces an owned TritVec.
        env.insert(
            "tritVecFromBuffer".into(),
            Scheme {
                vars: vec![0],
                ty: Ty::Fun(
                    Box::new(Ty::Con("Buffer".into(), vec![Ty::Var(0)])),
                    Box::new(Ty::Fun(Box::new(int()), Box::new(tvec_ty()))),
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
        // parametric instances (`instance Eq a => Eq (Maybe a)`): their impl is a
        // constrained function that must be specialized on the element type.
        let parametric_inst: Set<(String, String)> = module
            .instances
            .iter()
            .filter(|i| !i.constraints.is_empty())
            .map(|i| (i.class_name.clone(), i.ty_head.clone()))
            .collect();

        let mut resolutions: Map<(String, Span), String> = Map::new();
        // method uses that resolve to a parametric instance: (caller, span,
        // impl_base, element_type). Appended to `seeds` so the specialized
        // `impl$Elem` is materialized and the use rewritten to it.
        let mut method_seeds: Vec<(String, Span, String, String)> = Vec::new();
        // mangle-key → the substitution type(s) for that key, one per constraint
        // var (a length-1 vector for the single-constraint case; `[Int, Bool]` for a
        // `(Show a, Show b) =>` instance keyed `$Int$Bool`). A key absent here (a
        // bare concrete type name) falls back to a single nullary `Type::Con`.
        let mut key_types: HashMap<String, Vec<Type>> = HashMap::new();
        // per constrained function: polymorphic method uses (span, method, cvar
        // index — WHICH constraint the use dispatches over, 0 unless multi) and
        // polymorphic calls to constrained functions (span → function, including
        // self-recursion) — the points specialization rewrites to `$T`.
        let mut poly_methods: Map<String, Vec<(Span, String, usize)>> = Map::new();
        let mut poly_calls: Map<String, Vec<(Span, String)>> = Map::new();
        // data decls by name, and the accumulator of concrete tuple / multi-param
        // shapes the program shows (each synthesized monomorphically post-inference).
        let decls: HashMap<&str, &DataDecl> =
            module.datas.iter().map(|d| (d.name.as_str(), d)).collect();
        let mut show_needs = SynthNeeds::default();

        let obls = std::mem::take(&mut self.obligations);
        for o in obls {
            match self.resolve(&o.ty) {
                // built-in Num/Ord operator over Float → rewrite to the dotted form
                // the backends already lower.
                Ty::Con(name, _) if is_builtin_op_method(&o.method) && name == "Float" => {
                    resolutions
                        .insert((o.func.clone(), o.span), builtin_op_float(&o.method).into());
                }
                // built-in Num/Ord operator over Integer → resolve to the `#I`
                // operator, lowered to the arbitrary-precision runtime (§Listing 1.4).
                Ty::Con(name, _) if is_builtin_op_method(&o.method) && name == "Integer" => {
                    resolutions
                        .insert((o.func.clone(), o.span), builtin_op_integer(&o.method).into());
                }
                // built-in Num/Ord operator over Int → keep the operator (native
                // iadd/imul; the interpreter's Int path).
                Ty::Con(name, _) if is_builtin_op_method(&o.method) && name == "Int" => {}
                // built-in Integral `div`/`mod` over Integer → the `#I` runtime op;
                // over Int → keep (native sdiv/srem). (No Float instance → AX0404.)
                Ty::Con(name, _) if is_integral_method(&o.method) && name == "Integer" => {
                    resolutions
                        .insert((o.func.clone(), o.span), builtin_op_integer(&o.method).into());
                }
                Ty::Con(name, _) if is_integral_method(&o.method) && name == "Int" => {}
                // MULTI-PARAM derived `Show`/`Eq`/`Ord` (`Either Int Bool`): the
                // single-`t` machinery only substitutes the FIRST constraint var,
                // so it mis-dispatches the rest (`show (Right True)` → showInt on a
                // Bool; `eq` compares list pointers with `==`). Synthesize a
                // monomorphic `<method>$Either$Int$Bool` from the data decl instead,
                // each field at its concrete type.
                Ty::Con(name, args)
                    if matches!(o.class.as_str(), "Show" | "Eq" | "Ord")
                        && is_multi_derived_show(&name, args.len(), &decls)
                        && instances.contains(&(o.class.clone(), name.clone())) =>
                {
                    let comps: Option<Vec<Type>> =
                        args.iter().map(|a| ty_to_ast(&self.apply(a))).collect();
                    if let Some(comps) = comps {
                        // Show composes into containers unconditionally; Eq/Ord need
                        // every field to have the instance (else AX0404, no synth).
                        let ok = if o.class == "Show" {
                            show_needs.note_show_data(&name, &comps, &decls);
                            true
                        } else {
                            show_needs.note_eqord_data(
                                &o.class, &name, &comps, o.span, &decls, &instances,
                            )
                        };
                        if ok {
                            let key = data_show_key(&name, &comps);
                            resolutions
                                .insert((o.func.clone(), o.span), format!("{}${key}", o.method));
                        }
                    }
                }
                // concrete type WITH instance → resolves to the direct impl.
                Ty::Con(name, args) if instances.contains(&(o.class.clone(), name.clone())) => {
                    let base = crate::ast::method_impl_name(&o.method, &name);
                    // parametric instance: resolve to the element-specialized impl
                    // (`eq$Maybe` → `eq$Maybe$Int`) and seed that specialization.
                    // The fallback resolution (base) keeps the interpreter working
                    // even if the native spec turns out invalid.
                    if parametric_inst.contains(&(o.class.clone(), name.clone())) {
                        resolutions.insert((o.func.clone(), o.span), base.clone());
                        // seed the impl's specialization over the type's arguments,
                        // one per constraint var (`Option Int` → `[Int]`; a
                        // hand-written `Pair a b` instance → `[Int, Bool]`, keyed
                        // `$Int$Bool`). An arg may itself be parametric (`Option Int`
                        // in `show (Some (Some 3))`) — its mangle keys the OUTER spec
                        // and remembers the real type for the substitution.
                        let comps: Option<Vec<Type>> =
                            args.iter().map(|a| ty_to_ast(&self.apply(a))).collect();
                        if let Some(comps) = comps {
                            // a TUPLE or multi-param-derived arg (`show [(1,2)]`,
                            // `show [Left 1]`) has no directly-usable instance:
                            // synthesize it so the specialized impl's internal
                            // `show` resolves. Guarded so ordinary programs are
                            // completely unaffected.
                            for c in &comps {
                                if o.class == "Show" && type_needs_synth(c, &decls) {
                                    show_needs.note_show(c, &decls);
                                }
                            }
                            let key = comps.iter().map(ty_mangle).collect::<Vec<_>>().join("$");
                            key_types.insert(key.clone(), comps);
                            method_seeds.push((o.func.clone(), o.span, base, key));
                        }
                    } else {
                        resolutions.insert((o.func.clone(), o.span), base);
                    }
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
                // polymorphic covered by a constraint → specializable use. Record
                // WHICH constraint it dispatches over (0 unless the enclosing
                // function is multi-constraint), by matching the dispatch var to the
                // function's captured `cvar_ivars`.
                Ty::Var(_) if o.scope.contains(&o.class) => {
                    let ivars = self.cvar_ivars.get(&o.func).filter(|v| v.len() > 1).cloned();
                    let cvar_idx = match ivars {
                        Some(ivars) => {
                            let d = var_id(&self.resolve(&o.ty));
                            ivars
                                .iter()
                                .position(|iv| d.is_some() && var_id(&self.resolve(iv)) == d)
                                .unwrap_or(0)
                        }
                        None => 0,
                    };
                    poly_methods
                        .entry(o.func.clone())
                        .or_default()
                        .push((o.span, o.method.clone(), cvar_idx));
                }
                // built-in Num over an unconstrained (monomorphic) type variable:
                // default to Int (à la Haskell), so `g x = x + x` is `Int -> Int`.
                // The var is monomorphic (unsignatured function), so binding it is
                // safe — nothing has been generalized over it. No rewrite needed:
                // the operator keeps its Int form.
                Ty::Var(v) if is_builtin_op_method(&o.method) || is_integral_method(&o.method) => {
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
                // `show`/`showArg` over a TUPLE → synthesize a monomorphic
                // `show$(…)` for the concrete component types (both names — a tuple
                // is always parenthesised, so `show` == `showArg`).
                Ty::Tuple(ts) if o.class == "Show" => {
                    let comps: Option<Vec<Type>> =
                        ts.iter().map(|t| ty_to_ast(&self.apply(t))).collect();
                    if let Some(comps) = comps {
                        resolutions.insert(
                            (o.func.clone(), o.span),
                            show_impl_name(&o.method, &Type::Tuple(comps.clone())),
                        );
                        show_needs.note_tuple(&comps, &decls);
                    }
                }
                _ => {}
            }
        }

        // merge the synthesis accumulators into the discharge locals: the parametric
        // sub-part seeds/key_types join the worklist, and the synthesized names feed
        // the validity check (the functions are injected post-inference, so
        // `func_names` doesn't list them — a `show$List$(Int,Int)` spec must not be
        // rejected for a not-yet-existing `show$(…)`).
        method_seeds.extend(show_needs.seeds.iter().cloned());
        for (k, t) in &show_needs.key_types {
            key_types.entry(k.clone()).or_insert_with(|| vec![t.clone()]);
        }
        // a multi-param `Eq`/`Ord` field whose type has no instance of that class:
        // report it (instead of silently mis-dispatching to `==`/`<`).
        for (class, ty, span) in std::mem::take(&mut show_needs.missing) {
            let name = flatten_app_ty(&ty).0.unwrap_or("?");
            self.diags.push(
                Diagnostic::error(
                    "AX0404",
                    format!("no instance of `{class}` for `{name}`"),
                )
                .label(span.0, span.1, "derived here, over a field of this type")
                .with_help(format!(
                    "a field of a `deriving ({class})` type needs `{class} {name}` \
                     — declare it, or drop `{class}` from the deriving clause.",
                )),
            );
        }
        let synth_tuple_names: Set<String> = show_needs.names();

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
        // method uses over a parametric instance seed the impl's specialization.
        seeds.extend(method_seeds);

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
            // transitive: `(f, T)` pulls `(g, T)` for each constrained call in `f`
            // (single-constraint / self-recursion → same key; a multi-constraint
            // function's non-self calls are rejected as unspecializable in validity).
            for (_, g) in poly_calls.get(&f).into_iter().flatten() {
                let node = (g.clone(), t.clone());
                if cands.insert(node.clone()) {
                    queue.push(node);
                }
            }
            // a parametric ARG type (`Option Int` in `show$Option$Option$Int`, or a
            // field of a hand-written multi-param instance): each method use at that
            // constraint var dispatches to the arg's OWN parametric instance
            // (`showArg$Option` at `Int`), so seed that nested spec too.
            let types = key_types.get(&t).cloned().unwrap_or_default();
            let uses: Vec<(String, usize)> = poly_methods
                .get(&f)
                .into_iter()
                .flatten()
                .map(|(_, m, ci)| (m.clone(), *ci))
                .collect();
            for (m, ci) in uses {
                if is_builtin_op_method(&m) {
                    continue;
                }
                if let Some(Type::App(head, arg)) = types.get(ci) {
                    if let Type::Con(hname) = head.as_ref() {
                        let ak = ty_mangle(arg);
                        key_types
                            .entry(ak.clone())
                            .or_insert_with(|| vec![(**arg).clone()]);
                        let node = (crate::ast::method_impl_name(&m, hname), ak);
                        if cands.insert(node.clone()) {
                            queue.push(node);
                        }
                    }
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
                let ncvars = self.constrained_meta.get(f).map_or(0, |v| v.len());
                let types = key_types
                    .get(t)
                    .cloned()
                    .unwrap_or_else(|| vec![Type::Con(t.clone())]);
                // can't specialize: no constraint vars, or the key's type vector
                // doesn't match the arity (a multi-constraint fn we couldn't seed a
                // full vector for), or a multi-constraint fn makes a non-self
                // constrained call (whose cvar mapping we don't track).
                let cannot = ncvars == 0 || ncvars != types.len();
                let multi_bad_call = ncvars > 1
                    && poly_calls
                        .get(f)
                        .into_iter()
                        .flatten()
                        .any(|(_, g)| g != f);
                let bad = self.refs_unspec.contains(f)
                    || cannot
                    || multi_bad_call
                    || poly_methods.get(f).into_iter().flatten().any(|(_, m, ci)| {
                        // built-in Num operators are always available (Int/Float).
                        if is_builtin_op_method(m) {
                            return false;
                        }
                        let cty = types.get(*ci);
                        // parametric arg (`Option Int`): the method dispatches to the
                        // arg's own parametric instance spec (`showArg$Option` at
                        // `Int`, a cand) — available unless that nested spec is invalid.
                        if let Some(Type::App(head, arg)) = cty {
                            if let Type::Con(hname) = head.as_ref() {
                                let base = crate::ast::method_impl_name(m, hname);
                                let ak = ty_mangle(arg);
                                let full = crate::ast::method_impl_name(&base, &ak);
                                let cand_ok = cands.contains(&(base.clone(), ak.clone()))
                                    && !invalid.contains(&(base, ak));
                                return !(func_names.contains(full.as_str())
                                    || synth_tuple_names.contains(&full)
                                    || cand_ok);
                            }
                        }
                        let ti = cty.map(ty_mangle).unwrap_or_else(|| t.clone());
                        let impl_name = crate::ast::method_impl_name(m, &ti);
                        !(func_names.contains(impl_name.as_str())
                            || synth_tuple_names.contains(&impl_name))
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
            let types = key_types
                .get(t)
                .cloned()
                .unwrap_or_else(|| vec![Type::Con(t.clone())]);
            let mut rewrites: HashMap<Span, String> = HashMap::new();
            for (sp, m, ci) in poly_methods.get(f).into_iter().flatten() {
                // each use rewrites at ITS constraint var's concrete type.
                let ti = types.get(*ci).map(ty_mangle).unwrap_or_else(|| t.clone());
                if is_builtin_op_method(m) {
                    // built-in Num: only Float needs a rewrite (`+` → `+.`); the
                    // Int specialization keeps the operator the source already has.
                    if ti == "Float" {
                        rewrites.insert(*sp, builtin_op_float(m).into());
                    }
                } else {
                    rewrites.insert(*sp, crate::ast::method_impl_name(m, &ti));
                }
            }
            for (sp, g) in poly_calls.get(f).into_iter().flatten() {
                // only self-recursion / same-cvar calls reach here (validity rejected
                // the rest) → the callee takes the same key.
                rewrites.insert(*sp, crate::ast::method_impl_name(g, t));
            }
            let cvars: Vec<String> = self
                .constrained_meta
                .get(f)
                .map(|v| v.iter().map(|(cv, _)| cv.clone()).collect())
                .unwrap_or_default();
            specs.push(SpecPlan {
                src: f.clone(),
                name,
                subs: cvars.into_iter().zip(types).collect(),
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

        // polymorphic `++`: a `String` operand → native `strAppend` (marker
        // `++#str`, which `core`/`interp` lower to `axion_strcat`). Other operand
        // types keep `++` (the prelude's list `append`).
        let concat_uses = std::mem::take(&mut self.concat_uses);
        for (func, span, ty) in concat_uses {
            if matches!(self.resolve(&ty), Ty::Con(n, _) if n == "String") {
                resolutions.insert((func, span), "++#str".into());
            }
        }

        Mono {
            resolutions,
            specs,
            makecon_tys: HashMap::new(),
            array_tys: HashMap::new(),
            integer_lits: std::collections::HashSet::new(),
            synth_shows: synth_show_funcs(&show_needs, &decls),
        }
    }

    /// Phase B — closes the generic-owning corner. An UNCONSTRAINED generic
    /// function with an owned `%1` parameter whose type carries a type variable
    /// (`dropList :: List a %1 -> Int`) cannot deep-drop that parameter: its
    /// drop-type key is unresolvable at lowering (the element is a var), so the
    /// parameter is flat-freed and the payloads leak. Fix: monomorphize the
    /// function per concrete call-site type (Rust-style, mirroring the
    /// constrained-function pipeline): `dropList$P` has the concrete parameter
    /// `List P %1`, whose key resolves to the specialized destructor
    /// `axion_drop_List$P`.
    fn discharge_owning(&mut self) -> Mono {
        use std::collections::{HashMap as Map, HashSet as Set};
        // per caller: polymorphic owning calls (span → target) — rewritten to
        // `$T` when the caller is specialized.
        let mut poly_owns: Map<String, Vec<(Span, String)>> = Map::new();
        // seeds: (caller, span, fn, replacement types) — one seed per concrete
        // call site.  The combined mangle of all repl types is the spec name.
        let mut seeds: Vec<(String, Span, String, Vec<Type>)> = Vec::new();
        let obls = std::mem::take(&mut self.own_obligations);
        for o in obls {
            // resolve each type var along its positional path → concrete Ty
            let mut concrete = true;
            let mut repls: Vec<Type> = Vec::new();
            let mut mangle_parts: Vec<String> = Vec::new();
            for (_var, path) in &o.vars {
                let mut sub: Option<Ty> = Some(self.resolve(&o.param_ty));
                for idx in path {
                    sub = match sub {
                        Some(Ty::Con(_, args)) => args.get(*idx).cloned(),
                        Some(Ty::Tuple(ts)) => ts.get(*idx).cloned(),
                        _ => None,
                    };
                }
                let Some(sub) = sub else {
                    concrete = false;
                    break;
                };
                match self.resolve(&sub) {
                    Ty::Con(..) => {
                        if let Some(ast) = ty_to_ast(&self.resolve(&sub)) {
                            mangle_parts.push(ty_mangle(&ast));
                            repls.push(ast);
                        } else {
                            concrete = false;
                            break;
                        }
                    }
                    Ty::Var(_) => {
                        concrete = false;
                        break;
                    }
                    _ => {
                        concrete = false;
                        break;
                    }
                }
            }
            if concrete && !repls.is_empty() {
                seeds.push((o.func.clone(), o.span, o.target.clone(), repls));
            } else {
                poly_owns
                    .entry(o.func.clone())
                    .or_default()
                    .push((o.span, o.target.clone()));
            }
        }

        // combined mangle for a Vec of replacement types
        let mangled = |repls: &[Type]| -> String {
            repls.iter().map(ty_mangle).collect::<Vec<_>>().join("$")
        };

        // expands the set of required specializations by worklist: a `(f, [T₀,T₁])`
        // pulls `(g, [T₀,T₁])` for each polymorphic owning call in `f`.
        let mut cands: Set<(String, String)> = Set::new();
        let mut all_repls: Map<String, Vec<Type>> = Map::new();
        let mut queue: Vec<(String, Vec<Type>)> = Vec::new();
        for (_, _, f, repls) in &seeds {
            let m = mangled(repls);
            if cands.insert((f.clone(), m.clone())) {
                all_repls.insert(m, repls.clone());
                queue.push((f.clone(), repls.clone()));
            }
        }
        while let Some((f, repls)) = queue.pop() {
            for (_, g) in poly_owns.get(&f).into_iter().flatten() {
                let m = mangled(&repls);
                if cands.insert((g.clone(), m.clone())) {
                    all_repls.insert(m, repls.clone());
                    queue.push((g.clone(), repls.clone()));
                }
            }
        }

        // materializes each specialization.
        let mut resolutions: Map<(String, Span), String> = Map::new();
        let mut specs: Vec<SpecPlan> = Vec::new();
        for (f, m) in &cands {
            let mut rewrites: Map<Span, String> = Map::new();
            for (sp, g) in poly_owns.get(f).into_iter().flatten() {
                rewrites.insert(*sp, format!("{g}${m}"));
            }
            let subs = self
                .owned_meta
                .get(f)
                .and_then(|v| v.first())
                .map(|(_, vars)| vars.as_slice())
                .unwrap_or(&[]) // line 1375 area, will be fixed
                .iter()
                .zip(all_repls.get(m).into_iter().flat_map(|r| r.iter()))
                .map(|((var, _), repl)| (var.clone(), repl.clone()))
                .collect();
            specs.push(SpecPlan {
                src: f.clone(),
                name: format!("{f}${m}"),
                subs,
                rewrites,
            });
        }
        // rewrites the seed call-sites whose specializations exist.
        for (caller, span, f, repls) in seeds {
            let m = mangled(&repls);
            if cands.contains(&(f.clone(), m.clone())) {
                resolutions.insert((caller, span), format!("{f}${m}"));
            }
        }

        Mono {
            resolutions,
            specs,
            makecon_tys: HashMap::new(),
            array_tys: HashMap::new(),
            integer_lits: std::collections::HashSet::new(),
            synth_shows: Vec::new(),
        }
    }

    /// Exhaustiveness/redundancy for `case`, on the resolved scrutinee type:
    /// a data/`Bool` scrutinee must cover every constructor (or have a
    /// wildcard/variable); `Int`/`Float`/`String` need a wildcard. An arm after a
    /// catch-all (or a repeated constructor) is redundant (warning).
    fn check_exhaustiveness(&mut self) {
        let cases = std::mem::take(&mut self.case_uses);
        for (ts, pats, span) in cases {
            let ty = self.apply(&ts);
            let head = match &ty {
                Ty::Con(n, _) => n.as_str(),
                // a tuple has a single "constructor": a tuple pattern (or a
                // wildcard) is exhaustive — nothing to check at the top level.
                _ => continue,
            };
            let finite = self.data_cons.get(head).cloned();
            let infinite = matches!(
                head,
                "Int"
                    | "Float"
                    | "String"
                    | "U8"
                    | "U16"
                    | "U32"
                    | "U64"
                    | "I8"
                    | "I16"
                    | "I32"
                    | "I64"
                    | "Word"
                    | "Byte"
                    | "Char"
            );
            if finite.is_none() && !infinite {
                continue; // not a matchable scrutinee we reason about (IO, Arena, …)
            }

            let mut covered: HashSet<String> = HashSet::new();
            let mut catch_all = false;
            for pat in &pats {
                if catch_all {
                    self.diags.push(
                        Diagnostic::warning("AX0203", "unreachable pattern after a catch-all")
                            .label(span.0, span.1, "this arm can never match")
                            .with_help("remove the redundant arm, or the earlier wildcard."),
                    );
                    break;
                }
                match pat {
                    Pat::Wild(_) | Pat::Var(_, _) | Pat::Tuple(_, _) => catch_all = true,
                    Pat::Con(cn, _, _) => {
                        covered.insert(cn.clone());
                    }
                    Pat::Int(_, _) => {}
                }
            }
            if catch_all {
                continue;
            }
            if let Some(all) = finite {
                let missing: Vec<String> = all
                    .iter()
                    .filter(|c| !covered.contains(*c))
                    .cloned()
                    .collect();
                if !missing.is_empty() {
                    self.diags.push(
                        Diagnostic::error(
                            "AX0202",
                            format!(
                                "non-exhaustive patterns: {} not covered",
                                missing.join(", ")
                            ),
                        )
                        .label(
                            span.0,
                            span.1,
                            "this `case` does not cover every constructor",
                        )
                        .with_help(
                            "add the missing constructor arm(s), or a `_` wildcard catch-all.",
                        ),
                    );
                }
            } else {
                // infinite type without a catch-all → cannot be exhaustive.
                self.diags.push(
                    Diagnostic::error(
                        "AX0202",
                        format!("non-exhaustive patterns: `{head}` needs a wildcard"),
                    )
                    .label(span.0, span.1, "this `case` has no catch-all")
                    .with_help("add a `_` wildcard arm to cover the remaining values."),
                );
            }
        }
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
            // Num-polymorphic literal pattern — like an `Expr::Int`, a fresh var
            // resolved at the end of inference to `Integer` (matched by bignum `==`)
            // or defaulted to `Int`. Lets `factorial 0 = 1` type at `Integer`.
            Pat::Int(_, span) => {
                let v = self.fresh();
                self.int_lit_vars.push((*span, v.clone()));
                v
            }
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
            // Phase 1b: Num-polymorphic literal — a fresh var resolved at the end of
            // inference to `Integer` (→ rewritten `fromInt n`) or defaulted to `Int`.
            Expr::Int(_, span) => {
                let v = self.fresh();
                self.int_lit_vars.push((*span, v.clone()));
                v
            }
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
                // obligation over the type of the constraint var. Only for
                // SINGLE-constraint functions — a multi-constraint one is
                // specialized only as an instance method (via the parametric-instance
                // arm over its whole type-arg vector), so a bare call here can't
                // determine the vector; leave it generic (interp handles it).
                if let Some(disp) = self
                    .constrained_meta
                    .get(n)
                    .filter(|m| m.len() == 1)
                    .map(|m| m[0].1)
                {
                    match disp {
                        Some((i, nested)) => {
                            // the dispatch type is the param (`a`) or, when nested,
                            // its type argument (`Maybe a` → `a`).
                            let dispatch = nth_param(&ty, i).and_then(|p| {
                                if nested {
                                    match self.resolve(&p) {
                                        Ty::Con(_, args) => args.into_iter().next(),
                                        _ => None,
                                    }
                                } else {
                                    Some(p)
                                }
                            });
                            if let Some(d) = dispatch {
                                self.spec_obligations.push(SpecObl {
                                    target: n.clone(),
                                    ty: d,
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
                // use of a GENERIC-OWNING function (Phase B): collect the owning
                // specialization obligation over its owned `%1` parameter type.
                if let Some(owned) = self.owned_meta.get(n).cloned() {
                    for (i, vars) in owned {
                        if let Some(pt) = nth_param(&ty, i) {
                            self.own_obligations.push(OwnObl {
                                target: n.clone(),
                                vars,
                                param_ty: pt,
                                span: *span,
                                func: self.cur_fn.clone(),
                            });
                        }
                    }
                }
                ty
            }
            Expr::Con(n, s) => match env.get(n) {
                Some(sch) => {
                    let ty = self.instantiate(sch);
                    // Phase 4: record the constructor's return type.
                    // Walk the Fun chain to the final result type.
                    let mut ret = ty.clone();
                    while let Ty::Fun(_, body) = &ret {
                        ret = body.as_ref().clone();
                    }
                    self.con_ret_tys.insert(*s, ret);
                    ty
                }
                None => self.fresh(),
            },
            Expr::App(f, x, span) => {
                let tf = self.infer_expr(env, f);
                let tx = self.infer_expr(env, x);
                let r = self.fresh();
                self.unify(&tf, &Ty::Fun(Box::new(tx), Box::new(r.clone())), *span);
                // Phase 4: record constructor return types for MakeCon lowering
                if let Expr::Con(n, _s) = &**f {
                    if self.cons.contains_key(n) {
                        self.con_ret_tys.insert(*span, r.clone());
                    }
                }
                // Phase 2c array: record `newArray` return types for mono
                // destructor generation (Array$List$P, etc.)
                if let Expr::Var(n, _) = &**f {
                    if n == "newArray" {
                        self.array_ret_tys.insert(*span, r.clone());
                    }
                }
                // Phase 4: record every application's result type; at resolution the
                // ones that are concrete parametric heap types become the drop key of
                // a call/rtcall-bound local (partial-application arrows resolve to a
                // function type and are dropped by `ty_to_ast`/`mono_key`).
                self.call_ret_tys.insert(*span, r.clone());
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
                // polymorphic `++`: record the operand type so a `String` use is
                // later rewritten to native `strAppend` (see `discharge`).
                if op == "++" {
                    self.concat_uses
                        .push((self.cur_fn.clone(), *span, res.clone()));
                }
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
                // deferred exhaustiveness check (needs the resolved scrutinee type).
                self.case_uses
                    .push((ts, arms.iter().map(|(p, _)| p.clone()).collect(), *span));
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
                let ty = Ty::Con(tyname, vec![]);
                // Phase 4: record record-constructor return type
                self.con_ret_tys.insert(*span, ty.clone());
                ty
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
