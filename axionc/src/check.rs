//! Static checking: name resolution (AX0101) + **fine** linearity analysis
//! with **Auto-Drop** (§2).
//!
//! Fine liveness distinguishes two ways of using a `%1`:
//! - **borrow** (read without consuming — Borrow Elision, §2): free and
//!   unlimited;
//! - **consumption** (ownership flows out: argument of a `%1` parameter, `%1`
//!   field, or return value): at most **once**.
//!
//! The position of each occurrence decides which it is. Hence the rule:
//! - **consumptions > 1** ⇒ `AX0001` (contraction — moving ownership twice);
//! - **consumptions == 0** and a **must-use** type (no `Drop`: `Ep`, `Token`, handles)
//!   ⇒ `AX0002`;
//! - **consumptions == 0** and a **droppable** type ⇒ Auto-Drop inserts `free` at the
//!   death point (the last read, or entry if never read); reported by
//!   `--emit drops`;
//! - **consumptions == 1** ⇒ ownership transferred, no drop.
//!
//! Alternative branches (`if`, `case`) count as paths (maximum, not sum); a **must-use** value must
//! also be consumed on EVERY path (the minimum over paths is ≥ 1), else `AX0002` — the maximum alone
//! hid a branch that leaked it (Auto-Drop covers that for droppable values, not for handles).
//!
//! ORDER is also checked: a traversal in evaluation order detects the
//! use of a `%1` **after** ownership has been moved (use-after-move ⇒
//! `AX0004`). `x + sink x` (read before consuming) is accepted; `sink x + x` is not.
//!
//! Regions (§3): the sub-arena escape analysis (`AX0003`) follows the
//! provenance of the values of `withSubArena parent (\sub -> …)` — an
//! `allocateCell sub` value that is returned escapes, unless `promote parent`
//! moves it to the parent arena.

use crate::ast::{Body, Clause, Expr, Func, Module, Mult, Pat, Span, Type};
use crate::diag::{Diagnostic, Diagnostics};
use std::collections::{HashMap, HashSet};

/// Primitive types **without `Drop`** (must-use): forgetting them is an error, not Auto-Drop.
/// `Drop` propagates structurally: a record is must-use if any field is.
/// Everything else is droppable by default (§2).
const MUST_USE_PRIMS: &[&str] = &[
    "Ep",
    "Token",
    "Endpoint",
    "Transaction",
    "Buffer",
    "Sock",
    "Listener",
    // an open (or failed-to-open) file: closed exactly once with `fileClose`
    "File",
    // §18: a linear FFI resource handle (`Handle a`, e.g. an SDL Window*/Renderer*). Must-use so a
    // handle can't be dropped (leaked), double-destroyed, or used after destroy — enforced when it
    // is threaded as a `%1` parameter; consumed by an `Own`-annotated destroyer FFI.
    "Handle",
];

/// A `free` injected by Auto-Drop at the death point of a linear resource.
#[derive(Debug, Clone)]
pub struct DropPoint {
    pub func: String,
    pub var: String,
    pub ty: String,
    pub span: Span,
    /// Why it dies here (never used, or after the last read).
    pub reason: &'static str,
}

/// A record update the compiler can do **in-place** (§2):
/// the base is a linear resource and this is its last live mention.
#[derive(Debug, Clone)]
pub struct InPlace {
    pub func: String,
    pub var: String,
    pub span: Span,
}

/// A sub-arena reset inserted at the region's **death point** (NLL reset,
/// §3): the last live mention of a sub-arena value, not the lexical end.
#[derive(Debug, Clone)]
pub struct ArenaReset {
    pub func: String,
    pub sub: String,
    pub span: Span,
    pub last_var: String,
}

/// Analysis result: Auto-Drop `free`s, in-place updates, and the
/// NLL reset points of the sub-arenas.
#[derive(Debug, Default)]
pub struct Analysis {
    pub drops: Vec<DropPoint>,
    pub inplace: Vec<InPlace>,
    pub arenas: Vec<ArenaReset>,
    /// Phase 4: constructor return types (span → concrete AST Type) for MakeCon
    pub makecon_tys: HashMap<Span, Type>,
    /// Phase 2c: `newArray` call-site types for mono array destructors
    pub array_tys: HashMap<Span, Type>,
    /// Spans where a HEAP value is put into an `Array` (rejected natively, AX0914).
    pub heap_array_elems: Vec<(Span, String)>,
    /// Literal patterns inference resolved to `Integer` (matched by bignum `==`).
    pub integer_lits: HashSet<Span>,
    /// Generic pure-escape functions (consume-inferred `%1` on a var-carrying param
    /// that only shell-frees) — EXEMPT from the owning-generic native exclusion.
    pub consume_native_exempt: HashSet<String>,
    /// `where`-local return types (mangled `parent$local` → concrete RESULT AST Type),
    /// merged into the lowering's `fn_ret_ty` so a call to a heap-returning `where`-local
    /// carries a produce key (Auto-Drop reclaims it; the drop-verifier sees the ownership).
    pub where_ret_tys: HashMap<String, Type>,
    /// `where`-local PARAM types (mangled `parent$local` → per-position `Some(concrete AST Type)`),
    /// so the lowering can reclaim a move-consumer `where`-local's owned heap params (it has no
    /// signature). Closes the AX0911 false-negative where such a local leaked silently.
    pub where_param_tys: HashMap<String, Vec<Option<Type>>>,
}

/// Runs the checks and returns the Auto-Drop `free`s and the in-place sites. `caller_view`
/// replaces the multiplicities CALLERS of some functions are checked against (a higher-order clone is checked at its call sites as the generic function it
/// came from, while its own body keeps its own signature; see `lib::make_hof_spec`).
pub fn check_with(
    module: &Module,
    diags: &mut Diagnostics,
    caller_view: &HashMap<String, Vec<Mult>>,
) -> Analysis {
    let mut env = signature_env(module);
    for (name, mults) in caller_view {
        env.ctx.consumers.insert(name.clone(), mults.clone());
    }
    let mut out = Analysis::default();
    for f in &module.funcs {
        check_func(f, &env.globals, &env.ctx, diags, &mut out);
    }
    check_sessions(module, diags);
    check_bound_escapes(module, diags);
    check_instances(module, diags);
    warn_dropped_effects(module, diags);
    out
}

/// The single source of truth for "this built-in performs a side effect" — a command
/// run, a filesystem mutation, a stream read/write, or process exit. Because these
/// values are typed as ordinary `String`/`Int` (Axión has no `IO` type), the compiler
/// must treat them specially: an optimization must never COALESCE two effectful calls
/// (each occurrence is one effect — see the `effects_run_per_occurrence` test), never
/// REORDER them, and never DROP one whose result is unused. There is no common-subexpr
/// pass today, so this predicate is the contract any future one must consult. The pure
/// capability *reads* (`getEnv`/`readFile`/`fileExists`/`readDir`/`randHex`/`getArg`)
/// are excluded: dropping them changes nothing observable. User `foreign` imports and
/// the functions that call them are added per module by [`Effects`].
pub fn is_effectful(name: &str) -> bool {
    matches!(
        name,
        "runCapture"
            | "runStatus"
            | "execCapture"
            | "execStatus"
            | "writeFile"
            | "makeDir"
            | "removeFile"
            | "renameFile"
            | "readLine"
            | "readSecret"
            | "readKey"
            | "readKeyTimeout"
            | "resized"
            | "exitWith"
            | "putStr"
            | "putStrLn"
            | "ePutStr"
            | "ePutStrLn"
            // networking FFI (§): every socket op performs IO
            | "ax_net_connect"
            | "ax_net_listen"
            | "ax_net_accept"
            | "ax_net_send"
            | "ax_net_recv"
            | "ax_net_close"
            // typed async-socket ops (docs/async-sockets.md): also every-occurrence effects
            | "netConnect"
            | "netListen"
            | "netAccept"
            | "netSend"
            | "netRecv"
            | "netClose"
            | "netCloseL"
            | "netSendBuf"
            // files: opening, reading and closing are effects (the size can change between calls)
            | "fileOpenRaw"
            | "fileSize"
            | "fileRead"
            | "fileClose"
    )
}

/// Everything whose call performs a side effect in one module: the built-ins of
/// [`is_effectful`], every `foreign` import not declared `foreign pure` (C code is assumed
/// to have effects unless the declaration says otherwise), and, transitively, every
/// top-level function whose body references one of those. This is the module-aware form
/// of the [`is_effectful`] contract: no optimization may drop, merge or reorder a call to
/// any of these names.
#[derive(Debug, Clone, PartialEq)]
pub struct Effects {
    names: HashSet<String>,
}

impl Effects {
    pub fn of(module: &Module) -> Self {
        let mut names: HashSet<String> = module
            .foreigns
            .iter()
            .filter(|f| !f.pure)
            .map(|f| f.name.clone())
            .collect();
        let refs: Vec<(&str, HashSet<String>)> = module
            .funcs
            .iter()
            .map(|f| {
                let mut r = HashSet::new();
                collect_func_refs(f, &mut r);
                (f.name.as_str(), r)
            })
            .collect();
        loop {
            let mut grew = false;
            for (name, r) in &refs {
                if !names.contains(*name) && r.iter().any(|n| is_effectful(n) || names.contains(n))
                {
                    names.insert((*name).to_string());
                    grew = true;
                }
            }
            if !grew {
                return Effects { names };
            }
        }
    }

    pub fn contains(&self, name: &str) -> bool {
        is_effectful(name) || self.names.contains(name)
    }
}

/// Every name a function references: its clause bodies and, recursively, its `where`s.
pub fn collect_func_refs(f: &Func, out: &mut HashSet<String>) {
    for c in &f.clauses {
        collect_body_refs(&c.body, out);
        for w in &c.wher {
            collect_func_refs(w, out);
        }
    }
}

/// Warn (AX0920) when an effectful value is bound in a `where` clause but never used:
/// `where` bindings are demand-evaluated, so — unlike a strict `let` in the body — an
/// unreferenced one is dropped on every backend and its effect NEVER RUNS. That silent
/// loss is exactly the footgun of typing effects as pure values; the fix is to move the
/// call into a `do` block (or a `let` in the body), which Axión evaluates strictly.
fn warn_dropped_effects(module: &Module, diags: &mut Diagnostics) {
    let effects = Effects::of(module);
    for f in &module.funcs {
        warn_dropped_in_func(f, &effects, diags);
    }
}

fn warn_dropped_in_func(f: &Func, effects: &Effects, diags: &mut Diagnostics) {
    for c in &f.clauses {
        // Everything referenced by the clause body, its guards, and every where-binding
        // body — a where-binding whose name is absent here is genuinely unused.
        let mut used: HashSet<String> = HashSet::new();
        collect_body_refs(&c.body, &mut used);
        for w in &c.wher {
            for wc in &w.clauses {
                collect_body_refs(&wc.body, &mut used);
            }
        }
        for w in &c.wher {
            let is_value = w.clauses.first().is_some_and(|cl| cl.pats.is_empty());
            if is_value && !used.contains(&w.name) && where_body_is_effectful(w, effects) {
                diags.push(
                    Diagnostic::warning(
                        "AX0920",
                        format!(
                            "effectful binding `{}` in `where` is never used — its effect will not run",
                            w.name
                        ),
                    )
                    .label(
                        w.span.0,
                        w.span.1,
                        "move it into a `do` block or a `let` in the body to sequence the effect",
                    ),
                );
            }
        }
        // Nested `where`s (a where-binding may have its own).
        for w in &c.wher {
            warn_dropped_in_func(w, effects, diags);
        }
    }
}

fn where_body_is_effectful(w: &Func, effects: &Effects) -> bool {
    let mut refs = HashSet::new();
    for c in &w.clauses {
        collect_body_refs(&c.body, &mut refs);
    }
    refs.iter().any(|n| effects.contains(n))
}

pub fn collect_body_refs(body: &Body, out: &mut HashSet<String>) {
    match body {
        Body::Plain(e) => collect_refs(e, out),
        Body::Guarded(arms) => {
            for (g, r) in arms {
                collect_refs(g, out);
                collect_refs(r, out);
            }
        }
    }
}

/// Collect every `Var` name referenced in `e` (over-approximate: no shadowing/bound
/// tracking, which only ever marks a name as *used* — never a false "unused" warning).
pub fn collect_refs(e: &Expr, out: &mut HashSet<String>) {
    match e {
        Expr::Var(n, _) => {
            out.insert(n.clone());
        }
        Expr::Int(_, _) | Expr::Float(_, _) | Expr::Str(_, _) | Expr::Con(_, _) => {}
        Expr::App(a, b, _) | Expr::BinOp(_, a, b, _) => {
            collect_refs(a, out);
            collect_refs(b, out);
        }
        Expr::If(c, t, el, _) => {
            collect_refs(c, out);
            collect_refs(t, out);
            collect_refs(el, out);
        }
        Expr::Let(binds, body, _) => {
            for b in binds {
                for c in &b.clauses {
                    collect_body_refs(&c.body, out);
                }
            }
            collect_refs(body, out);
        }
        Expr::Case(s, arms, _) => {
            collect_refs(s, out);
            for (_, body) in arms {
                collect_refs(body, out);
            }
        }
        Expr::Tuple(es, _) => es.iter().for_each(|x| collect_refs(x, out)),
        Expr::RecordCon(_, fs, _) => fs.iter().for_each(|(_, x)| collect_refs(x, out)),
        Expr::RecordUpd(base, fs, _) => {
            collect_refs(base, out);
            fs.iter().for_each(|(_, x)| collect_refs(x, out));
        }
        Expr::Lam(_, body, _) => collect_refs(body, out),
    }
}

/// The body-independent environment for the per-function linearity/Auto-Drop
/// check: the set of callable global names + the [`Ctx`] built from signatures,
/// `data`, and class headers. It never inspects a function's BODY, so it is stable
/// across body edits — which is what lets the salsa engine memoize
/// [`check_one_func`] per declaration (`crate::db`). The one exception is `effects`,
/// which follows calls through bodies; it is a set of names, so an edit that does not
/// change which functions have effects still compares equal and is backdated.
#[derive(Debug, Clone)]
#[cfg_attr(feature = "salsa", derive(salsa::SalsaValue, PartialEq))]
pub struct SigEnv {
    globals: HashSet<String>,
    ctx: Ctx,
    effects: Effects,
}

/// Build the [`SigEnv`] for a module — the same globals + `Ctx` that whole-module
/// [`check`] uses.
pub fn signature_env(module: &Module) -> SigEnv {
    let mut globals: HashSet<String> = builtins();
    for f in &module.funcs {
        globals.insert(f.name.clone());
    }
    for fo in &module.foreigns {
        globals.insert(fo.name.clone());
    }
    // constructors and field selectors become callable global names
    for d in &module.datas {
        for c in &d.cons {
            globals.insert(c.name.clone());
            for f in &c.fields {
                if !f.name.is_empty() {
                    globals.insert(f.name.clone());
                }
            }
        }
    }
    // typeclass method names are callable (dispatch is dynamic)
    for class in &module.classes {
        for (m, _) in &class.methods {
            globals.insert(m.clone());
        }
    }
    SigEnv {
        globals,
        ctx: build_ctx(module),
        effects: Effects::of(module),
    }
}

/// Run the linearity/Auto-Drop/name-resolution check for ONE function against a
/// precomputed [`SigEnv`], returning just its diagnostics. This is the per-decl
/// unit the salsa engine memoizes: its inputs are the function's own AST and the
/// (body-independent) `SigEnv`, so editing another function's body cannot affect it.
#[cfg_attr(not(feature = "salsa"), allow(dead_code))] // only the salsa engine calls it
pub fn check_one_func(f: &Func, env: &SigEnv) -> Vec<Diagnostic> {
    let mut diags = Diagnostics::new();
    let mut out = Analysis::default();
    check_func(f, &env.globals, &env.ctx, &mut diags, &mut out);
    // AX0920 (dropped `where` effect) depends on this function's own body +
    // where-clauses and on which names are effectful (`env.effects`), matching the
    // whole-module `check` which runs `warn_dropped_effects` over every function.
    warn_dropped_in_func(f, &env.effects, &mut diags);
    diags.items
}

/// The whole-module checks that are NOT per-function: session-type fidelity,
/// `bound` nursery escapes, and instance coherence.
#[cfg_attr(not(feature = "salsa"), allow(dead_code))]
pub fn check_non_func(module: &Module) -> Vec<Diagnostic> {
    let mut diags = Diagnostics::new();
    check_sessions(module, &mut diags);
    check_bound_escapes(module, &mut diags);
    check_instances(module, &mut diags);
    diags.items
}

/// Static typeclass coherence. Each `instance`:
/// - refers to a declared class (**AX0400**);
/// - implements ALL methods of that class (**AX0401** per missing method);
/// - does not implement methods the class doesn't declare (**AX0402**);
/// - is unique for its (class, type) pair — no overlap (**AX0403**).
///
/// It is the static half: it catches at compile time what previously only blew up
/// at runtime dispatch (missing method, typo in the name, extra instance).
fn check_instances(module: &Module, diags: &mut Diagnostics) {
    use std::collections::HashMap;
    let class_methods: HashMap<&str, HashSet<&str>> = module
        .classes
        .iter()
        .map(|c| {
            (
                c.name.as_str(),
                c.methods.iter().map(|(m, _)| m.as_str()).collect(),
            )
        })
        .collect();

    let mut seen: HashSet<(String, String)> = HashSet::new();
    for inst in &module.instances {
        if !seen.insert((inst.class_name.clone(), inst.ty_head.clone())) {
            diags.push(
                Diagnostic::error(
                    "AX0403",
                    format!(
                        "duplicate instance of `{}` for `{}`",
                        inst.class_name, inst.ty_head
                    ),
                )
                .label(
                    inst.span.0,
                    inst.span.1,
                    "an instance for this type already exists",
                )
                .with_help(
                    "each (class, type) pair may have only ONE instance — method \
                     resolution must be unambiguous (coherence).",
                ),
            );
            continue;
        }
        let Some(methods) = class_methods.get(inst.class_name.as_str()) else {
            diags.push(
                Diagnostic::error(
                    "AX0400",
                    format!("instance of unknown class `{}`", inst.class_name),
                )
                .label(inst.span.0, inst.span.1, "this class was not declared")
                .with_help("declare `class C a where …` before instantiating it."),
            );
            continue;
        };
        let impl_names: HashSet<&str> = inst.methods.iter().map(|f| f.name.as_str()).collect();
        for m in methods {
            if !impl_names.contains(m) {
                diags.push(
                    Diagnostic::error(
                        "AX0401",
                        format!(
                            "instance `{} {}` does not implement method `{m}`",
                            inst.class_name, inst.ty_head
                        ),
                    )
                    .label(
                        inst.span.0,
                        inst.span.1,
                        "class method missing in this instance",
                    )
                    .with_help("an instance must implement all methods of the class."),
                );
            }
        }
        for f in &inst.methods {
            if !methods.contains(f.name.as_str()) {
                diags.push(
                    Diagnostic::error(
                        "AX0402",
                        format!(
                            "`{}` is not a method of class `{}`",
                            f.name, inst.class_name
                        ),
                    )
                    .label(f.span.0, f.span.1, "method unknown in this class")
                    .with_help("check the method name, or declare it in the `class`."),
                );
            }
        }
    }
}

// --- confinamento do nursery `bound` (§9): deadlock-freedom estrutural ---
//
// Deadlock-freedom "by construction" comes from the communication graph being a
// tree: endpoints are born confined to the `bound` and cannot escape (otherwise
// they could link nurseries in a cycle). This pass enforces the confinement — an
// endpoint created inside a `bound` (by `newChannel`/`spawn`, or advanced by
// `send`/`recv`) cannot be the block's return value. **AX0302**. It is the analog
// of sub-arena escape (AX0003), but WITHOUT an escape hatch (there is no `promote` of
// endpoints — that is the point). The region is the `bound`'s body itself.

/// What an expression produces, in terms of endpoints (to propagate ownership).
enum Prod {
    Both, // `newChannel` → pair (Ep, Ep): both are endpoints
    Snd,  // `recv` → (value, Ep): only the 2nd is an endpoint
    One,  // `send`/`spawn`/var-endpoint → um endpoint
    No,
}

/// Recognizes `bound <body>` (or `bound arena <body>`) and returns the body.
fn as_bound(e: &Expr) -> Option<&Expr> {
    let (head, args) = app_spine(e);
    match head {
        Some("bound") if !args.is_empty() => args.last().copied(),
        _ => None,
    }
}

fn check_bound_escapes(module: &Module, diags: &mut Diagnostics) {
    for f in &module.funcs {
        for c in &f.clauses {
            if let Body::Plain(e) = &c.body {
                find_bounds(e, diags);
            }
        }
    }
}

fn find_bounds(e: &Expr, diags: &mut Diagnostics) {
    if let Some(body) = as_bound(e) {
        check_bound(body, diags);
    }
    let mut go = |e: &Expr| find_bounds(e, diags);
    match e {
        Expr::App(f, a, _) => {
            go(f);
            go(a);
        }
        Expr::BinOp(_, l, r, _) => {
            go(l);
            go(r);
        }
        Expr::If(c, t, el, _) => {
            go(c);
            go(t);
            go(el);
        }
        Expr::Let(binds, body, _) => {
            for cl in binds.iter().flat_map(|b| &b.clauses) {
                if let Body::Plain(e2) = &cl.body {
                    go(e2);
                }
            }
            go(body);
        }
        Expr::Case(s, arms, _) => {
            go(s);
            for (_, b) in arms {
                go(b);
            }
        }
        Expr::Tuple(es, _) => es.iter().for_each(&mut go),
        Expr::RecordCon(_, assigns, _) | Expr::RecordUpd(_, assigns, _) => {
            assigns.iter().for_each(|(_, e)| go(e));
        }
        Expr::Lam(_, body, _) => go(body),
        Expr::Var(_, _)
        | Expr::Int(_, _)
        | Expr::Float(_, _)
        | Expr::Str(_, _)
        | Expr::Con(_, _) => {}
    }
}

/// Checks that a `bound`'s body doesn't return an endpoint created inside it.
fn check_bound(body: &Expr, diags: &mut Diagnostics) {
    let mut eps: HashSet<String> = HashSet::new();
    let tail = peel_bound_spine(body, &mut eps, diags);
    if let Some(sp) = tail_endpoint(tail, &eps) {
        diags.push(
            Diagnostic::error("AX0302", "an endpoint escapes the `bound` nursery")
                .label(
                    sp.0,
                    sp.1,
                    "returned from here — the endpoint would outlive the nursery",
                )
                .with_help(
                    "endpoints are born confined to the `bound` so the communication \
                 graph is a tree (deadlock-freedom, §9); consume them inside the \
                 block (`close`/`send`/`recv`), don't return them.",
                ),
        );
    }
}

/// Walks the `do`/`let` spine, recording the variables bound to endpoints
/// created in the nursery; returns the tail expression (the return value).
fn peel_bound_spine<'a>(
    e: &'a Expr,
    eps: &mut HashSet<String>,
    diags: &mut Diagnostics,
) -> &'a Expr {
    let mut cur = e;
    loop {
        match cur {
            Expr::Let(binds, body, _) => {
                for b in binds {
                    if let Some(rhs) = simple_bind_rhs(b) {
                        check_spawn_capture(rhs, eps, diags);
                        if let Prod::One | Prod::Both | Prod::Snd = producer(rhs, eps) {
                            eps.insert(b.name.clone());
                        }
                    }
                }
                cur = body;
            }
            Expr::Case(scrut, arms, _) if arms.len() == 1 => {
                check_spawn_capture(scrut, eps, diags);
                bind_prod(&arms[0].0, producer(scrut, eps), eps);
                cur = &arms[0].1;
            }
            _ => return cur,
        }
    }
}

/// §9: the closure passed to `spawn` cannot CAPTURE an endpoint from outside — it can only
/// use its parameter (the spawn's channel end). If it captured, two
/// children could share channels and form a cycle in the topology → deadlock.
/// Ensures each `spawn` only creates a parent↔child edge (tree). **AX0305**.
fn check_spawn_capture(e: &Expr, eps: &HashSet<String>, diags: &mut Diagnostics) {
    let (head, args) = app_spine(e);
    if head != Some("spawn") {
        return;
    }
    if let Some(Expr::Lam(pats, body, sp)) = args.first() {
        let mut bound = HashSet::new();
        for p in pats {
            pat_names(p, &mut bound);
        }
        if let Some(ep) = captured_endpoint(body, &bound, eps) {
            diags.push(
                Diagnostic::error(
                    "AX0305",
                    format!(
                        "the `spawn` closure captures endpoint '{ep}' from outside — \
                         it would break the nursery's tree topology"
                    ),
                )
                .label(sp.0, sp.1, "endpoint capture forbidden")
                .with_help(
                    "a spawned child communicates with the parent only through its \
                     endpoint parameter (parent↔child edge); don't capture outside \
                     channels (§9, deadlock-freedom).",
                ),
            );
        }
    }
}

/// Names bound by a pattern (var, constructor, tuple).
fn pat_names(p: &Pat, out: &mut HashSet<String>) {
    match p {
        Pat::Var(n, _) => {
            out.insert(n.clone());
        }
        Pat::Con(_, subs, _) | Pat::Tuple(subs, _) => subs.iter().for_each(|s| pat_names(s, out)),
        _ => {}
    }
}

/// The first endpoint (of `eps`) used free in `e` (not bound locally).
fn captured_endpoint(e: &Expr, bound: &HashSet<String>, eps: &HashSet<String>) -> Option<String> {
    match e {
        Expr::Var(n, _) => (eps.contains(n) && !bound.contains(n)).then(|| n.clone()),
        Expr::App(f, x, _) | Expr::BinOp(_, f, x, _) => {
            captured_endpoint(f, bound, eps).or_else(|| captured_endpoint(x, bound, eps))
        }
        Expr::If(c, t, el, _) => captured_endpoint(c, bound, eps)
            .or_else(|| captured_endpoint(t, bound, eps))
            .or_else(|| captured_endpoint(el, bound, eps)),
        Expr::Lam(pats, body, _) => {
            let mut b = bound.clone();
            pats.iter().for_each(|p| pat_names(p, &mut b));
            captured_endpoint(body, &b, eps)
        }
        Expr::Let(binds, body, _) => {
            let mut b = bound.clone();
            for g in binds {
                b.insert(g.name.clone());
            }
            binds
                .iter()
                .flat_map(|g| &g.clauses)
                .find_map(|c| match &c.body {
                    Body::Plain(rhs) => captured_endpoint(rhs, &b, eps),
                    _ => None,
                })
                .or_else(|| captured_endpoint(body, &b, eps))
        }
        Expr::Case(s, arms, _) => captured_endpoint(s, bound, eps).or_else(|| {
            arms.iter().find_map(|(pat, body)| {
                let mut b = bound.clone();
                pat_names(pat, &mut b);
                captured_endpoint(body, &b, eps)
            })
        }),
        Expr::Tuple(es, _) => es.iter().find_map(|x| captured_endpoint(x, bound, eps)),
        Expr::RecordCon(_, fs, _) | Expr::RecordUpd(_, fs, _) => fs
            .iter()
            .find_map(|(_, x)| captured_endpoint(x, bound, eps)),
        _ => None,
    }
}

fn producer(e: &Expr, eps: &HashSet<String>) -> Prod {
    // the builtin name first (`newChannel` is a 0-arg `Var`), then the
    // already-recorded endpoint variable.
    match app_spine(e).0 {
        Some("newChannel") => Prod::Both,
        Some("recv") => Prod::Snd,
        Some("send" | "spawn") => Prod::One,
        Some(n) if eps.contains(n) => Prod::One,
        _ => Prod::No,
    }
}

fn bind_prod(pat: &Pat, prod: Prod, eps: &mut HashSet<String>) {
    match (prod, pat) {
        (Prod::One, Pat::Var(n, _)) => {
            eps.insert(n.clone());
        }
        (Prod::Both, Pat::Tuple(ps, _)) => {
            for p in ps {
                if let Pat::Var(n, _) = p {
                    eps.insert(n.clone());
                }
            }
        }
        (Prod::Snd, Pat::Tuple(ps, _)) => {
            if let Some(Pat::Var(n, _)) = ps.last() {
                eps.insert(n.clone());
            }
        }
        _ => {}
    }
}

/// If the tail returns an endpoint (a recorded var, or an operation producing one
/// endpoint), returns the escape's span.
fn tail_endpoint(e: &Expr, eps: &HashSet<String>) -> Option<Span> {
    match e {
        Expr::Var(n, _) if eps.contains(n) => Some(e.span()),
        Expr::Tuple(es, _) => es.iter().find_map(|x| tail_endpoint(x, eps)),
        _ => match app_spine(e).0 {
            Some("newChannel" | "spawn" | "send" | "recv") => Some(e.span()),
            _ => None,
        },
    }
}

// --- session protocol fidelity (§6, ASC calculus) ---
//
// Endpoint linearity (`Ep` is must-use %1) is already guaranteed by the linearity
// pass. This pass checks what HM does not express: that each channel operation
// follows the endpoint's session type (send on a `Send`, recv on a `Recv`,
// close on an `End`) and that the protocol is carried to the end. AX03xx band.
// v1: the send/recv/close fragment over the linear spine of `do`/`let`; choice
// (⊕/&), `bound`/`spawn` and branches (multi-arm `if`/`case`) are left for later
// increments (there the tracking stops, conservative, no false positives).

#[derive(Clone, Debug, PartialEq)]
enum SessTy {
    End,
    Send(Box<SessTy>),
    Recv(Box<SessTy>),
    Select(Vec<(String, SessTy)>), // ⊕ — chooses a label (internal side)
    Offer(Vec<(String, SessTy)>),  // & — offers all labels (external side)
    // recursive session types (§6, server loops): `Rec S` binds, `Loop` refers
    // back to the nearest enclosing `Rec` (single level, de Bruijn 0).
    Rec(Box<SessTy>),
    Var,
}

/// Substitutes the recursion variable `Loop`/`Var` with `r` (does not descend
/// into a nested `Rec`, which binds its own variable).
fn subst(t: &SessTy, r: &SessTy) -> SessTy {
    match t {
        SessTy::Var => r.clone(),
        SessTy::Rec(_) => t.clone(),
        SessTy::End => SessTy::End,
        SessTy::Send(s) => SessTy::Send(Box::new(subst(s, r))),
        SessTy::Recv(s) => SessTy::Recv(Box::new(subst(s, r))),
        SessTy::Select(bs) => {
            SessTy::Select(bs.iter().map(|(l, s)| (l.clone(), subst(s, r))).collect())
        }
        SessTy::Offer(bs) => {
            SessTy::Offer(bs.iter().map(|(l, s)| (l.clone(), subst(s, r))).collect())
        }
    }
}

/// One-level unfold of a `Rec`: `Rec B` → `B[Loop := Rec B]`. Idempotent on
/// non-`Rec` types. Applied wherever an endpoint's session is inspected.
fn unfold(t: SessTy) -> SessTy {
    match &t {
        SessTy::Rec(body) => subst(body, &t),
        _ => t,
    }
}

/// Structural equality up to one `Rec` unfold on either side (enough to close a
/// single-level recursion: the folded `Rec B` and its unfolding are equal).
fn sess_eq(a: &SessTy, b: &SessTy) -> bool {
    a == b || unfold(a.clone()) == unfold(b.clone())
}

/// Decomposes a type into its head and arguments (the `App` spine).
fn ty_spine(t: &Type) -> (Option<&str>, Vec<&Type>) {
    let mut args = Vec::new();
    let mut cur = t;
    loop {
        match cur {
            Type::App(f, a) => {
                args.push(a.as_ref());
                cur = f;
            }
            Type::Con(n) => {
                args.reverse();
                return (Some(n.as_str()), args);
            }
            _ => return (None, vec![]),
        }
    }
}

/// Reads a session type from a `Type` (payload ignored in v1).
fn parse_sess(t: &Type) -> Option<SessTy> {
    let (h, args) = ty_spine(t);
    match (h?, args.len()) {
        ("End", 0) => Some(SessTy::End),
        ("Send", 2) => Some(SessTy::Send(Box::new(parse_sess(args[1])?))),
        ("Recv", 2) => Some(SessTy::Recv(Box::new(parse_sess(args[1])?))),
        // `Select (L1 S1) (L2 S2) …` / `Offer …` — each branch is `Label Cont`
        // (label = ConId; a branch without a continuation = `End`).
        ("Select", n) if n >= 1 => Some(SessTy::Select(parse_branches(&args)?)),
        ("Offer", n) if n >= 1 => Some(SessTy::Offer(parse_branches(&args)?)),
        // recursion (§6): `Rec S` and the back-reference `Loop`
        ("Rec", 1) => Some(SessTy::Rec(Box::new(parse_sess(args[0])?))),
        ("Loop", 0) => Some(SessTy::Var),
        _ => None,
    }
}

/// Reads the branches of a `Select`/`Offer`: each arg is `Label Cont` (or just `Label`).
fn parse_branches(args: &[&Type]) -> Option<Vec<(String, SessTy)>> {
    let mut out = Vec::new();
    for a in args {
        let (h, bargs) = ty_spine(a);
        let label = h?.to_string();
        let cont = if bargs.is_empty() {
            SessTy::End
        } else {
            parse_sess(bargs[0])?
        };
        out.push((label, cont));
    }
    Some(out)
}

/// If `t` is an endpoint `Ep S` (or `Channel`/`Chan`/`Endpoint`), returns the session.
fn endpoint_session(t: &Type) -> Option<SessTy> {
    let (h, args) = ty_spine(t);
    match h? {
        "Ep" | "Channel" | "Chan" | "Endpoint" if args.len() == 1 => parse_sess(args[0]),
        _ => None,
    }
}

/// The head name and arguments of an application `f a b …`.
fn app_spine(e: &Expr) -> (Option<&str>, Vec<&Expr>) {
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

/// Result of a recognized channel operation.
enum OpResult {
    Advance(SessTy), // `send` → the advanced endpoint
    Recv(SessTy),    // `recv` → (value, advanced endpoint)
    Closed,          // `close` → consumido
}

fn check_sessions(module: &Module, diags: &mut Diagnostics) {
    // session functions → their endpoint parameter's session type, for closing a
    // recursive tail call (`server d'` continues the protocol; §6, server loops).
    let sess_fns: HashMap<String, SessTy> = module
        .funcs
        .iter()
        .filter_map(|f| {
            let ptys = f.sig.as_ref()?.param_types();
            let s = ptys.iter().find_map(|t| endpoint_session(t))?;
            Some((f.name.clone(), s))
        })
        .collect();
    for f in &module.funcs {
        let Some(sig) = &f.sig else { continue };
        let ptys = sig.param_types();
        for c in &f.clauses {
            // initial environment: parameters that are endpoints
            let mut env: HashMap<String, SessTy> = HashMap::new();
            for (i, p) in c.pats.iter().enumerate() {
                if let (Pat::Var(n, _), Some(t)) = (p, ptys.get(i)) {
                    if let Some(s) = endpoint_session(t) {
                        // T5: every external choice (`Offer`/`&`) must include the
                        // `Closed` branch — so cancellation is always handleable.
                        check_closed_branches(&s, n, f.span, diags);
                        env.insert(n.clone(), s);
                    }
                }
            }
            if env.is_empty() {
                continue; // no channels → nothing to check
            }
            if let Body::Plain(e) = &c.body {
                let mut tracked = true;
                walk_sess(e, &mut env, &mut tracked, f.span, &sess_fns, diags);
                // completeness (T-progress): if we followed the whole spine, no
                // endpoint may be left uncarried to `close`.
                if tracked {
                    // a closed endpoint was removed from the env; what remains was not
                    // carried to `close` → incomplete protocol.
                    for n in env.keys() {
                        diags.push(
                            Diagnostic::error(
                                "AX0301",
                                format!(
                                    "endpoint '{n}' did not complete its session protocol \
                                     (it must be consumed up to `close`)"
                                ),
                            )
                            .label(f.span.0, f.span.1, "incomplete protocol here")
                            .with_help(
                                "carry the endpoint to `close`, or consume it with `offer`/`cancel`.",
                            ),
                        );
                    }
                }
            }
        }
    }
}

/// Walks the linear spine (desugared `do` = 1-arm `case`, and `let`),
/// advancing each endpoint's session state. `tracked` becomes `false` if
/// it hits non-session branching (not trackable in v1) — there nothing is reported
/// as incomplete. `span` = where to point in the per-branch incompleteness errors.
fn walk_sess(
    e: &Expr,
    env: &mut HashMap<String, SessTy>,
    tracked: &mut bool,
    span: Span,
    sess_fns: &HashMap<String, SessTy>,
    diags: &mut Diagnostics,
) {
    // `case offer c of { L1 p1 -> N1 ; … }` (&): the external choice. Checks
    // exhaustiveness (all `Offer` branches handled) and follows each branch with
    // its continuation. It is the only multi-arm `case` that is tracked.
    if let Expr::Case(scrut, arms, _) = e {
        if let Some(chan) = offer_chan(scrut) {
            check_offer_case(&chan, arms, env, span, sess_fns, diags);
            return;
        }
    }
    match e {
        Expr::Case(scrut, arms, _) if arms.len() == 1 => {
            if let Some(r) = classify_op(scrut, env, diags) {
                bind_result(&arms[0].0, r, env);
            }
            walk_sess(&arms[0].1, env, tracked, span, sess_fns, diags);
        }
        Expr::Let(funcs, body, _) => {
            for g in funcs {
                if let Some(cl) = g.clauses.first() {
                    if cl.pats.is_empty() {
                        if let Body::Plain(rhs) = &cl.body {
                            if let Some(r) = classify_op(rhs, env, diags) {
                                bind_named(&g.name, r, env);
                            }
                        }
                    }
                }
            }
            walk_sess(body, env, tracked, span, sess_fns, diags);
        }
        // real branching: not trackable in v1 → stop (conservative, no false+)
        Expr::If(..) | Expr::Case(..) => *tracked = false,
        // leaf: a session op (`close c`), or a recursive tail call `f d'` that
        // continues the protocol (§6, server loops).
        other => {
            if let Some((fname, chan)) = sess_tail_call(other) {
                if let (Some(param_ty), Some(cur)) = (sess_fns.get(&fname), env.get(&chan)) {
                    if sess_eq(cur, param_ty) {
                        env.remove(&chan); // the recursion consumes it (loops)
                        return;
                    }
                    let got = cur.clone();
                    env.remove(&chan);
                    diags.push(
                        Diagnostic::error(
                            "AX0300",
                            format!(
                                "recursive call `{fname} {chan}` does not continue the session \
                                 protocol of '{chan}' (its type here is not `{fname}`'s parameter type)"
                            ),
                        )
                        .label(span.0, span.1, "session recursion type mismatch")
                        .with_help("the endpoint passed to the recursive call must be at the \
                                    same session state as the function's parameter."),
                    );
                    drop(got);
                    return;
                }
            }
            classify_op(other, env, diags);
        }
    }
}

/// If `e` is a call `f a… d` whose LAST argument is a plain endpoint variable,
/// returns `(f, d)` — a candidate recursive session tail call. The endpoint is
/// always the last parameter (a session worker is spawned as `spawn (f a…)`, which
/// partial-applies the leading args and leaves the endpoint for `spawn`), so any
/// preceding args are accumulator state threaded across the loop (`server (acc+n) d`).
/// Whether it truly continues the protocol is decided by the caller (`f` must be a
/// session fn and `d`'s session state must match `f`'s endpoint param).
fn sess_tail_call(e: &Expr) -> Option<(String, String)> {
    let (head, args) = app_spine(e);
    match (head, args.split_last()) {
        (Some(f), Some((Expr::Var(d, _), _rest))) => Some((f.to_string(), d.clone())),
        _ => None,
    }
}

/// If `scrut` is `offer c`, returns the name of the endpoint `c`.
fn offer_chan(scrut: &Expr) -> Option<String> {
    let (head, args) = app_spine(scrut);
    if head == Some("offer") {
        if let Some(Expr::Var(n, _)) = args.first() {
            return Some(n.clone());
        }
    }
    None
}

/// Checks the external choice `case offer c of {branches}`: exhaustiveness of the branches
/// of the `Offer` (AX0304) + fidelity/completeness of each branch (with the
/// that label's continuation bound to the endpoint).
fn check_offer_case(
    chan: &str,
    arms: &[(Pat, Expr)],
    env: &mut HashMap<String, SessTy>,
    span: Span,
    sess_fns: &HashMap<String, SessTy>,
    diags: &mut Diagnostics,
) {
    let branches = match env.remove(chan).map(unfold) {
        Some(SessTy::Offer(bs)) => bs,
        Some(other) => {
            session_mismatch(diags, span, chan, "offer", &other);
            return;
        }
        None => return,
    };
    // labels handled by the branches (and whether there is a catch-all `_`/var)
    let mut has_catchall = false;
    for (pat, _) in arms {
        if arm_label(pat).is_none() {
            has_catchall = true;
        }
    }
    // exhaustiveness: every branch of the `Offer` must have an arm (or a catch-all)
    if !has_catchall {
        let handled: HashSet<&str> = arms.iter().filter_map(|(p, _)| arm_label(p)).collect();
        for (label, _) in &branches {
            if !handled.contains(label.as_str()) {
                diags.push(
                    Diagnostic::error(
                        "AX0304",
                        format!(
                            "the `case offer {chan}` does not handle branch '{label}' of the \
                             external choice (the session offers it)"
                        ),
                    )
                    .label(span.0, span.1, "unhandled session branch")
                    .with_help(
                        "add an arm for each label of the `Offer` (incl. `Closed`, the \
                         cancellation — §7/T5).",
                    ),
                );
            }
        }
    }
    // follows each arm with the endpoint in its label's continuation
    for (pat, body) in arms {
        let mut arm_env = env.clone();
        if let (Some(label), Some(binder)) = (arm_label(pat), arm_binder(pat)) {
            if let Some((_, cont)) = branches.iter().find(|(l, _)| l == label) {
                arm_env.insert(binder.to_string(), cont.clone());
            }
        }
        let mut t = true;
        walk_sess(body, &mut arm_env, &mut t, span, sess_fns, diags);
        if t {
            for n in arm_env.keys() {
                diags.push(
                    Diagnostic::error(
                        "AX0301",
                        format!(
                            "endpoint '{n}' did not complete its session protocol \
                             (it must be consumed up to `close`)"
                        ),
                    )
                    .label(span.0, span.1, "incomplete protocol in this arm"),
                );
            }
        }
    }
}

/// The label (constructor) handled by an arm, or `None` if it is a catch-all (`_`/var).
fn arm_label(pat: &Pat) -> Option<&str> {
    match pat {
        Pat::Con(name, _, _) => Some(name),
        _ => None,
    }
}

/// The endpoint bound by an arm `L c2` (the sub-pattern variable).
fn arm_binder(pat: &Pat) -> Option<&str> {
    match pat {
        Pat::Con(_, subs, _) => match subs.first() {
            Some(Pat::Var(n, _)) => Some(n),
            _ => None,
        },
        _ => None,
    }
}

/// Recognizes and validates a channel operation; advances/consumes the endpoint in `env`.
/// Emits AX0300 if the operation doesn't follow the session type.
fn classify_op(
    e: &Expr,
    env: &mut HashMap<String, SessTy>,
    diags: &mut Diagnostics,
) -> Option<OpResult> {
    let (head, args) = app_spine(e);
    let head = head?;
    let sp = e.span();
    // `select L c` (⊕): chooses the label L; the channel is the 2nd argument.
    if head == "select" && args.len() >= 2 {
        let label = match args[0] {
            Expr::Con(l, _) | Expr::Var(l, _) => l.clone(),
            _ => return None,
        };
        let chan = match args[1] {
            Expr::Var(n, _) => n.clone(),
            _ => return None,
        };
        return match env.remove(&chan).map(unfold) {
            Some(SessTy::Select(branches)) => {
                match branches.into_iter().find(|(bl, _)| *bl == label) {
                    Some((_, cont)) => Some(OpResult::Advance(cont)),
                    None => {
                        diags.push(
                            Diagnostic::error(
                                "AX0300",
                                format!(
                                    "`select {label}` on endpoint '{chan}': the `Select` \
                                     protocol does not offer the label '{label}'"
                                ),
                            )
                            .label(sp.0, sp.1, "invalid choice label"),
                        );
                        None
                    }
                }
            }
            Some(other) => {
                session_mismatch(diags, sp, &chan, "select", &other);
                None
            }
            None => None,
        };
    }
    let chan = match args.first() {
        Some(Expr::Var(n, _)) => n.clone(),
        _ => return None,
    };
    // unfold a top-level `Rec` so the op can match the exposed Send/Recv/Offer.
    let cur = env.remove(&chan).map(unfold);
    match head {
        "send" if args.len() >= 2 => match cur {
            Some(SessTy::Send(s)) => Some(OpResult::Advance(*s)),
            Some(other) => {
                session_mismatch(diags, sp, &chan, "send", &other);
                None
            }
            None => None,
        },
        "recv" => match cur {
            Some(SessTy::Recv(s)) => Some(OpResult::Recv(*s)),
            Some(other) => {
                session_mismatch(diags, sp, &chan, "recv", &other);
                None
            }
            None => None,
        },
        "close" => match cur {
            Some(SessTy::End) => Some(OpResult::Closed),
            Some(other) => {
                session_mismatch(diags, sp, &chan, "close", &other);
                None
            }
            None => None,
        },
        // `offer c` (&): receives the choice and consumes the endpoint. The exhaustiveness of the
        // branches (incl. `Closed`) is checked in the type (`check_closed_branches`).
        "offer" => match cur {
            Some(SessTy::Offer(_)) => Some(OpResult::Closed),
            Some(other) => {
                session_mismatch(diags, sp, &chan, "offer", &other);
                None
            }
            None => None,
        },
        // `cancel c` (§7): discards the endpoint in ANY state (you can always
        // cancel) — consumes it.
        "cancel" => {
            env.remove(&chan);
            Some(OpResult::Closed)
        }
        _ => None,
    }
}

/// T5 (§7): recursively checks that every external choice (`Offer`/`&`) in the
/// session includes the `Closed` branch — so cancellation (the panicking peer sends
/// `Closed`) is always a handleable branch of the protocol, never silently ignored.
fn check_closed_branches(s: &SessTy, chan: &str, sp: Span, diags: &mut Diagnostics) {
    match s {
        SessTy::End => {}
        SessTy::Send(k) | SessTy::Recv(k) => check_closed_branches(k, chan, sp, diags),
        SessTy::Select(bs) => {
            for (_, k) in bs {
                check_closed_branches(k, chan, sp, diags);
            }
        }
        SessTy::Offer(bs) => {
            if !bs.iter().any(|(l, _)| l == "Closed") {
                diags.push(
                    Diagnostic::error(
                        "AX0303",
                        format!(
                            "the external choice (`Offer`) of endpoint '{chan}' has no \
                             `Closed` branch — cancellation of a panicking peer would go unhandled (§7)"
                        ),
                    )
                    .label(sp.0, sp.1, "missing the `Closed` branch")
                    .with_help(
                        "add a `Closed` branch to the `Offer` (it is the label that \
                         Linear Unwinding sends when cancelling — T5).",
                    ),
                );
            }
            for (_, k) in bs {
                check_closed_branches(k, chan, sp, diags);
            }
        }
        SessTy::Rec(k) => check_closed_branches(k, chan, sp, diags),
        SessTy::Var => {} // back-reference: its body is checked at the enclosing `Rec`
    }
}

fn session_mismatch(diags: &mut Diagnostics, sp: Span, chan: &str, op: &str, got: &SessTy) {
    let expect = match op {
        "send" => "a `Send`",
        "recv" => "a `Recv`",
        "select" => "a `Select`",
        "offer" => "an `Offer`",
        _ => "an `End`",
    };
    let got = match got {
        SessTy::End => "it is at `End`",
        SessTy::Send(_) => "it is at `Send`",
        SessTy::Recv(_) => "it is at `Recv`",
        SessTy::Select(_) => "it is at `Select`",
        SessTy::Offer(_) => "it is at `Offer`",
        SessTy::Rec(_) => "it is at `Rec`",
        SessTy::Var => "it is at `Loop`",
    };
    diags.push(
        Diagnostic::error(
            "AX0300",
            format!(
                "`{op}` on endpoint '{chan}' does not follow the protocol: expected {expect}, but {got}"
            ),
        )
        .label(sp.0, sp.1, "invalid session operation")
        .with_help(
            "the operation must follow the endpoint's session type: `send` on a `Send`, \
             `recv` on a `Recv`, `close` on an `End`, and the label of `select` must belong \
             to the `Select`.",
        ),
    );
}

fn bind_result(pat: &Pat, r: OpResult, env: &mut HashMap<String, SessTy>) {
    match r {
        OpResult::Advance(s) => {
            if let Pat::Var(n, _) = pat {
                env.insert(n.clone(), s);
            }
        }
        OpResult::Recv(s) => {
            // `(_value, endpoint) <- recv c` — the last var of the tuple is the endpoint
            if let Pat::Tuple(ps, _) = pat {
                if let Some(Pat::Var(n, _)) = ps.last() {
                    env.insert(n.clone(), s);
                }
            } else if let Pat::Var(n, _) = pat {
                env.insert(n.clone(), s);
            }
        }
        OpResult::Closed => {}
    }
}

fn bind_named(name: &str, r: OpResult, env: &mut HashMap<String, SessTy>) {
    match r {
        OpResult::Advance(s) | OpResult::Recv(s) => {
            env.insert(name.to_string(), s);
        }
        OpResult::Closed => {}
    }
}

/// A type is *must-use* if its head is a primitive without `Drop`, or a
/// `data` cuja must-use-ness foi propagada estruturalmente (ver `build_ctx`).
/// `true` for a must-use type with NO destructor (not a `Buffer`, nor a record holding only those).
fn is_no_drop(ty: &Type, no_drop_types: &HashSet<String>) -> bool {
    matches!(ty.head_con(), Some(h)
        if (MUST_USE_PRIMS.contains(&h) && !AUTO_DROPPED_PRIMS.contains(&h))
            || no_drop_types.contains(h))
}

fn is_must_use(ty: &Type, must_use_types: &HashSet<String>) -> bool {
    matches!(ty.head_con(), Some(h) if MUST_USE_PRIMS.contains(&h) || must_use_types.contains(h))
}

/// Computes, by fixpoint, the set of `data` types that are *must-use*:
/// a `data` is must-use if some field of some constructor is must-use (a
/// primitive without `Drop`, or another already-marked `data`). `Drop` thus propagates
/// estruturalmente (§2).
/// Must-use primitives that nonetheless HAVE a destructor: a `Buffer` is freed by Auto-Drop
/// (`axion_buf_free`) wherever it is not consumed. Only types with no destructor at all get the
/// stricter rules — tracked from a `let` binding, and consumed on every path.
const AUTO_DROPPED_PRIMS: &[&str] = &["Buffer"];

/// Built-ins that return a FRESH no-destructor resource, with its type. A `let` or `do`
/// bind of one is tracked from its binding like a user function's (`Ctx.fn_ret_must_use`).
/// Built-ins that return an advanced endpoint (`send`/`recv`) consume an existing one
/// and are covered by ownership inheritance instead.
const BUILTIN_MUST_USE_RESULTS: &[(&str, &str)] = &[
    ("netConnect", "Sock"),
    ("netListen", "Listener"),
    ("netAccept", "Sock"),
    ("fileOpenRaw", "File"),
];

/// The must-use types with NO destructor (handles, sockets, endpoints…), propagated through `data`
/// fields like [`build_must_use_types`] but without [`AUTO_DROPPED_PRIMS`].
fn build_no_drop_types(module: &Module) -> HashSet<String> {
    let prim = |h: &str| MUST_USE_PRIMS.contains(&h) && !AUTO_DROPPED_PRIMS.contains(&h);
    let mut set: HashSet<String> = HashSet::new();
    loop {
        let mut changed = false;
        for d in &module.datas {
            if set.contains(&d.name) {
                continue;
            }
            let any = d.cons.iter().any(|c| {
                c.fields
                    .iter()
                    .any(|f| matches!(f.ty.head_con(), Some(h) if prim(h) || set.contains(h)))
            });
            if any {
                set.insert(d.name.clone());
                changed = true;
            }
        }
        if !changed {
            break;
        }
    }
    set
}

fn build_must_use_types(module: &Module) -> HashSet<String> {
    let mut set: HashSet<String> = HashSet::new();
    loop {
        let mut changed = false;
        for d in &module.datas {
            if set.contains(&d.name) {
                continue;
            }
            let any_mu = d.cons.iter().any(|c| {
                c.fields.iter().any(|f| {
                    matches!(f.ty.head_con(), Some(h) if MUST_USE_PRIMS.contains(&h) || set.contains(h))
                })
            });
            if any_mu {
                set.insert(d.name.clone());
                changed = true;
            }
        }
        if !changed {
            break;
        }
    }
    set
}

pub fn builtins() -> HashSet<String> {
    [
        "putStrLn",
        "putStr",
        "ePutStrLn",
        "ePutStr",
        "showInt",
        "showFloat",
        "strAppend",
        "strLen",
        "charAt",
        "pokeU32",
        "strCmp",
        "substr",
        // OS capability layer (§pass)
        "getEnv",
        "runCapture",
        "runStatus",
        "execCapture",
        "execStatus",
        "readFile",
        "writeFile",
        "fileExists",
        "makeDir",
        "removeFile",
        "renameFile",
        "readDir",
        "readDirTyped",
        "readDirListing",
        "readLine",
        "readSecret",
        "readKey",
        "readKeyTimeout",
        "resized",
        "chr",
        "randHex",
        "exitWith",
        "getArgs",
        "getArg",
        // typed async-socket ops (docs/async-sockets.md)
        "netConnect",
        "netListen",
        "netAccept",
        "netRecv",
        "netSend",
        "netClose",
        "netCloseL",
        "netSendBuf",
        "fileOpenRaw",
        "fileErrno",
        "fileSize",
        "fileRead",
        "fileClose",
        "bufLen",
        "otherwise",
        "True",
        "False",
        // Float conversions + math (§4)
        "toFloat",
        "truncate",
        "sqrt",
        "floor",
        "abs",
        // arenas (§3)
        "withArena",
        "withSubArena",
        "allocateCell",
        "promote",
        "arena_mark",
        "arena_release",
        // Buffer U8 linear (§4/§5)
        "newBuffer",
        "withBuffer",
        "bufIota",
        "xorInPlace",
        "sumBytes",
        "free",
        "peekU8",
        "peekU16",
        "peekU32",
        "peekU64",
        "peekF64",
        "pokeU8",
        "pokeU16",
        "pokeU64",
        "pokeF64",
        "bufPtr",
        "bufPtrN",
        "foldBytes",
        "imperative",
        "intToPtr",
        "ptrToInt",
        "handleAddr",
        "nullPtr",
        // linear dense Array
        "newArray",
        "getArray",
        "setArray",
        "parFor",
        "lenArray",
        // TritVec: base-243 packed ternary array (§10)
        "newTritVec",
        "getTritVec",
        "setTritVec",
        "lenTritVec",
        "tritDot",
        "tritMatVecSum",
        "tritVecFromBuffer",
        "tritVecIota",
        "arrayIota",
        // I8Array: compact signed-byte array (Phase B)
        "newI8Array",
        "i8Iota",
        "getI8",
        "setI8",
        "lenI8",
        "i8MatVecSum",
        "i8Sum",
        "i8Dot",
        "i8DotI8",
        // general dense-array primitives
        "arraySum",
        "arrayDot",
        "newI32Array",
        "i32Iota",
        "getI32",
        "setI32",
        "lenI32",
        "i32Sum",
        "i32Dot",
        "i32MatVecSum",
        // fractional permissions (§2)
        "split",
        "join",
        // channels / session types (§6)
        "send",
        "recv",
        "close",
        "newChannel",
        "select",
        "offer",
        "cancel",
        // structured-concurrency nursery (§9)
        "bound",
        "spawn",
        "parMap",
        "connect",
        "pipe3",
        // arbitrary-precision Integer (§ Listing 1.4)
        "fromInt",
        "showInteger",
        "bignumFromStr",
        "divInteger",
        "modInteger",
    ]
    .iter()
    .copied()
    .chain(crate::simd::names())
    .map(|s| s.to_string())
    .collect()
}

/// State of a linear resource after analyzing a clause/scope.
struct ResUse {
    consumes: usize,
    /// consumptions on the LEAST-consuming path (a must-use value needs >= 1 on every path)
    min_consumes: usize,
    borrows: usize,
    uam: Option<(Span, Span)>, // use-after-move (use, move)
    death: Option<Span>,       // last occurrence (death point)
}

fn check_func(
    f: &Func,
    globals: &HashSet<String>,
    ctx: &Ctx,
    diags: &mut Diagnostics,
    out: &mut Analysis,
) {
    let mults = f.sig.as_ref().map(|t| t.param_mults()).unwrap_or_default();
    let ptypes = f.sig.as_ref().map(|t| t.param_types()).unwrap_or_default();
    for clause in &f.clauses {
        // --- name resolution ---
        let mut scope: HashSet<String> = HashSet::new();
        for p in &clause.pats {
            collect_pat_vars(p, &mut scope);
        }
        for w in &clause.wher {
            scope.insert(w.name.clone());
        }
        resolve_clause(clause, &scope, globals, diags);

        // --- fine linearity + Auto-Drop: %1 parameters ---
        let mut lin: HashMap<String, Lin> = HashMap::new();
        for (i, p) in clause.pats.iter().enumerate() {
            if mults.get(i).copied() != Some(Mult::One) {
                continue;
            }
            if let (Pat::Var(name, span), Some(ty)) = (p, ptypes.get(i)) {
                let class = class_of_type(ty, ctx);
                let (c, b) = analyze_clause(clause, name, ctx);
                let use_ = ResUse {
                    consumes: c,
                    min_consumes: analyze_clause_with(clause, name, ctx, alt_min).0,
                    borrows: b,
                    uam: use_after_move(clause, name, ctx),
                    death: last_occurrence_clause(clause, name),
                };
                report_resource(name, &class, *span, &use_, &f.name, diags, out);
                lin.insert(name.clone(), class);
            }
        }

        // --- contraction for BORROWED heap params (the %1 loop above skips them) ---
        // A `Many` (borrowed) param may be READ any number of times, but a heap
        // value (a `data`/tuple that is deep-dropped) may not be CONSUMED — moved
        // into an owned position — more than once: `mk xs = Two xs xs` aliases `xs`
        // into two owned slots, and native deep-drop then double-frees it. (Sharing
        // by ownership requires `split` into %0.5 halves — §2.)
        for (i, p) in clause.pats.iter().enumerate() {
            if mults.get(i).copied() == Some(Mult::One) {
                continue; // %1 handled above
            }
            if let (Pat::Var(name, span), Some(ty)) = (p, ptypes.get(i)) {
                // A borrowed (non-`%1`) RESOURCE parameter: the caller keeps it and consumes it
                // itself, so giving it away here too would consume it twice (a double close).
                if class_of_type(ty, ctx).no_drop && analyze_clause(clause, name, ctx).0 > 0 {
                    diags.push(borrowed_resource_consumed(
                        name, *span, &f.name, clause, ctx,
                    ));
                }
                let heap = is_heap_ty(ty, ctx);
                let consumes = if heap {
                    analyze_clause(clause, name, ctx).0
                } else {
                    0
                };
                if consumes > 1 {
                    diags.push(contraction_diag(
                        name,
                        *span,
                        consumes,
                        &clause_exprs(clause),
                        ctx,
                    ));
                }
            }
        }

        // --- contraction of `case`-extracted / `let`-aliased heap binders ---
        // The two loops above only see PARAMETERS; a heap value bound by a `case`
        // field pattern (`case xs of C y ys -> Q (C y ys) (C y ys)`) or aliased by
        // a `let` (`let z = xs in T z z`) evaded them and double-freed natively.
        {
            let mut heap: HashSet<String> = HashSet::new();
            // declared types of the parameters (and, below, of binders whose type follows)
            let tys: HashMap<String, Type> = clause
                .pats
                .iter()
                .zip(&ptypes)
                .filter_map(|(p, t)| match p {
                    Pat::Var(n, _) => Some((n.clone(), (*t).clone())),
                    _ => None,
                })
                .collect();
            for (i, p) in clause.pats.iter().enumerate() {
                // MANY heap params only — `%1` sources are handled by `scan_lets`
                // below (avoid a double AX0001 on the same alias).
                if mults.get(i).copied() != Some(Mult::One) {
                    if let (Pat::Var(name, _), Some(ty)) = (p, ptypes.get(i)) {
                        if is_heap_ty(ty, ctx) {
                            heap.insert(name.clone());
                        }
                    }
                }
            }
            // heap-return summary of this clause's `where`-locals, so a
            // `let z = local xs` heap-returning call is not laundered past the check.
            let locals = build_local_heap(&clause.wher, ctx);
            // `where`-bound heap aliases obey the same rule as `let` aliases
            // (`mk xs = T z z where z = xs`); count uses across the whole clause
            // (`analyze_clause` spans the body and any guards).
            for w in &clause.wher {
                if let [c] = w.clauses.as_slice() {
                    if c.pats.is_empty() {
                        if let Body::Plain(rhs) = &c.body {
                            if rhs_is_heap(rhs, &heap, ctx, &locals) {
                                let n = analyze_clause(clause, &w.name, ctx).0;
                                if n > 1 {
                                    push_contraction(
                                        &w.name,
                                        rhs.span(),
                                        n,
                                        &clause_exprs(clause),
                                        ctx,
                                        diags,
                                    );
                                }
                                heap.insert(w.name.clone());
                            }
                        }
                    }
                }
            }
            // walk the clause body (Plain, or each guarded result) + `where` bodies
            match &clause.body {
                Body::Plain(body) => check_contraction(body, &heap, &tys, ctx, &locals, diags),
                Body::Guarded(arms) => {
                    for (_, r) in arms {
                        check_contraction(r, &heap, &tys, ctx, &locals, diags);
                    }
                }
            }
            for w in &clause.wher {
                for c in &w.clauses {
                    if let Body::Plain(rhs) = &c.body {
                        check_contraction(rhs, &heap, &tys, ctx, &locals, diags);
                    }
                }
            }
        }

        // --- sub-arena escape (§3) + NLL reset + %0.5 permissions ---
        if let Body::Plain(body) = &clause.body {
            check_arena_escapes(body, &f.name, diags, &mut out.arenas);
            check_arena_marks(body, diags);
            check_fractional(body, ctx, diags);
        }

        // --- linearidade + Auto-Drop de valores 'let' lineares + in-place (§2) ---
        if let Body::Plain(body) = &clause.body {
            let mut lets = Vec::new();
            scan_lets(body, &lin, ctx, &mut lets, &mut out.inplace, &f.name);
            for (name, class, sp_scope, bind_span) in lets {
                let (c, b) = analyze(sp_scope, &name, Mode::Consume, ctx);
                let mut death = None;
                collect_last(sp_scope, &name, &mut death);
                let use_ = ResUse {
                    consumes: c,
                    min_consumes: analyze_with(sp_scope, &name, Mode::Consume, ctx, alt_min).0,
                    borrows: b,
                    uam: walk(sp_scope, &name, Mode::Consume, ctx, MoveState::default()).error,
                    death,
                };
                report_resource(&name, &class, bind_span, &use_, &f.name, diags, out);
            }
            // An ordinary `let` value is not a linear resource, but handing it to a `%1` HEAP
            // parameter moves it all the same (the callee frees it): any later use reads freed
            // memory. Same rule, same error as for a parameter (AX0004).
            let tracked: HashSet<String> = lets_names(body, &lin, ctx);
            check_plain_lets(body, &tracked, ctx, diags);
        }
    }
}

/// The `let` binders `scan_lets` already tracks as linear resources (checked above).
fn lets_names(body: &Expr, lin: &HashMap<String, Lin>, ctx: &Ctx) -> HashSet<String> {
    let mut lets = Vec::new();
    let mut inplace = Vec::new();
    scan_lets(body, lin, ctx, &mut lets, &mut inplace, "");
    lets.into_iter().map(|(n, ..)| n).collect()
}

/// Checks every simple `let x = e` in `e` (a `do`-block `let` included) that is not already a
/// tracked resource: once moved into a `%1` heap parameter, it may not be used again.
fn check_plain_lets(e: &Expr, tracked: &HashSet<String>, ctx: &Ctx, diags: &mut Diagnostics) {
    if let Expr::Let(binds, scope, _) = e {
        for b in binds {
            if simple_bind_rhs(b).is_none()
                || tracked.contains(&b.name)
                || !moved_into_heap_param(scope, &b.name, ctx)
            {
                continue;
            }
            if let Some((mv, use_sp)) =
                walk(scope, &b.name, Mode::Consume, ctx, MoveState::default()).error
            {
                diags.push(use_after_move_diag(&b.name, mv, use_sp));
            }
        }
    }
    crate::for_each_subexpr(e, &mut |sub| check_plain_lets(sub, tracked, ctx, diags));
}

/// `true` if `x` is passed bare to a `%1` parameter of a known function whose declared type is
/// a heap type — a position that takes ownership and frees it. A higher-order function (one
/// taking a closure) and its specialized clones are skipped: whether they take ownership
/// depends on the clone (one that only reads its list borrows it), and the editor checks the
/// generic function while the batch compiler checks the clone, so neither may decide here. The
/// drop verifier still checks those calls natively.
fn moved_into_heap_param(e: &Expr, x: &str, ctx: &Ctx) -> bool {
    if let Expr::App(..) = e {
        let (head, args) = spine(e);
        if let Expr::Var(f, _) = head {
            if let Some(sig) = ctx.fn_sigs.get(f).filter(|sig| {
                !f.contains("$$")
                    && !sig
                        .param_types()
                        .iter()
                        .any(|t| matches!(t, Type::Arrow { .. }))
            }) {
                let mults = sig.param_mults();
                let tys = sig.param_types();
                for (i, a) in args.iter().enumerate() {
                    if matches!(a, Expr::Var(v, _) if v == x)
                        && mults.get(i) == Some(&Mult::One)
                        && tys.get(i).is_some_and(|t| owns_heap(t, ctx))
                    {
                        return true;
                    }
                }
            }
        }
    }
    let mut found = false;
    crate::for_each_subexpr(e, &mut |sub| {
        found = found || moved_into_heap_param(sub, x, ctx);
    });
    found
}

/// A type whose value is a heap allocation its owner frees: a `data`/tuple, or a
/// `String`/`Integer`/`Buffer`.
fn owns_heap(t: &Type, ctx: &Ctx) -> bool {
    is_heap_ty(t, ctx) || matches!(t.head_con(), Some("String" | "Integer" | "Buffer"))
}

fn use_after_move_diag(name: &str, mv: Span, use_sp: Span) -> Diagnostic {
    Diagnostic::error(
        "AX0004",
        format!("use of '{name}' after ownership was moved"),
    )
    .label(use_sp.0, use_sp.1, format!("'{name}' used here…"))
    .label(mv.0, mv.1, "…but ownership had already been moved here")
    .with_help(
        "after moving a %1 (consuming), you cannot read or consume it \
             again — ownership has left this scope (§2).",
    )
}

/// Rejects CONTRACTION (double consumption) of a heap value bound by a `case`
/// field pattern or aliased by a `let` — the gap the parameter/`%1` contraction
/// checks (which only see parameters) miss. `case xs of C y ys -> Q (C y ys) (C y ys)`
/// and `let z = xs in T z z` both compiled clean but double-freed natively: the
/// heap binder is moved into two owned slots and the native deep-drop frees it
/// twice. `heap` carries the in-scope MANY heap binders (params + those bound
/// deeper). Bare polymorphic binders are never flagged (see `is_heap_ty`).
fn check_contraction(
    e: &Expr,
    heap: &HashSet<String>,
    tys: &HashMap<String, Type>,
    ctx: &Ctx,
    locals: &LocalHeap,
    diags: &mut Diagnostics,
) {
    match e {
        Expr::Case(scrut, arms, _) => {
            check_contraction(scrut, heap, tys, ctx, locals, diags);
            let sty = scrut_type(scrut, tys, ctx);
            for (pat, body) in arms {
                let mut heap = heap.clone();
                let mut tys = tys.clone();
                let mut shadowed = HashSet::new();
                pat_names(pat, &mut shadowed);
                tys.retain(|n, _| !shadowed.contains(n));
                for (name, span) in pat_heap_binders(pat, sty.as_ref(), ctx, &mut tys) {
                    let n = analyze(body, &name, Mode::Consume, ctx).0;
                    if n > 1 {
                        push_contraction(&name, span, n, &[body], ctx, diags);
                    }
                    heap.insert(name);
                }
                check_contraction(body, &heap, &tys, ctx, locals, diags);
            }
        }
        Expr::Let(binds, body, _) => {
            let mut heap = heap.clone();
            let mut tys = tys.clone();
            for f in binds {
                if let [c] = f.clauses.as_slice() {
                    if let (true, Body::Plain(rhs)) = (c.pats.is_empty(), &c.body) {
                        if let Some(t) = scrut_type(rhs, &tys, ctx) {
                            tys.insert(f.name.clone(), t);
                        }
                    }
                }
                for c in &f.clauses {
                    if let Body::Plain(rhs) = &c.body {
                        check_contraction(rhs, &heap, &tys, ctx, locals, diags);
                    }
                }
                // a plain `let name = rhs` (no params) whose RHS is a heap value:
                // `name` aliases/owns it, so a double consume double-frees. Count
                // consumes across the SIBLING bindings' RHS too, not just `body` —
                // `let x = …; a = W x; b = W x` aliases `x` into two records there.
                if let [c] = f.clauses.as_slice() {
                    if c.pats.is_empty() {
                        if let Body::Plain(rhs) = &c.body {
                            if rhs_is_heap(rhs, &heap, ctx, locals) {
                                let mut n = analyze(body, &f.name, Mode::Consume, ctx).0;
                                for g in binds {
                                    if g.name != f.name {
                                        for gc in &g.clauses {
                                            n += analyze_clause(gc, &f.name, ctx).0;
                                        }
                                    }
                                }
                                if n > 1 {
                                    let mut scope = vec![body.as_ref()];
                                    for g in binds {
                                        if g.name != f.name {
                                            for gc in &g.clauses {
                                                scope.extend(clause_exprs(gc));
                                            }
                                        }
                                    }
                                    push_contraction(&f.name, rhs.span(), n, &scope, ctx, diags);
                                }
                                heap.insert(f.name.clone());
                            }
                        }
                    }
                }
            }
            check_contraction(body, &heap, &tys, ctx, locals, diags);
        }
        Expr::App(a, b, _) | Expr::BinOp(_, a, b, _) => {
            check_contraction(a, heap, tys, ctx, locals, diags);
            check_contraction(b, heap, tys, ctx, locals, diags);
        }
        Expr::If(a, b, c, _) => {
            check_contraction(a, heap, tys, ctx, locals, diags);
            check_contraction(b, heap, tys, ctx, locals, diags);
            check_contraction(c, heap, tys, ctx, locals, diags);
        }
        Expr::Tuple(es, _) => es
            .iter()
            .for_each(|e| check_contraction(e, heap, tys, ctx, locals, diags)),
        Expr::RecordCon(_, fs, _) => {
            fs.iter()
                .for_each(|(_, e)| check_contraction(e, heap, tys, ctx, locals, diags));
        }
        Expr::RecordUpd(base, fs, _) => {
            check_contraction(base, heap, tys, ctx, locals, diags);
            fs.iter()
                .for_each(|(_, e)| check_contraction(e, heap, tys, ctx, locals, diags));
        }
        Expr::Lam(_, b, _) => check_contraction(b, heap, tys, ctx, locals, diags),
        Expr::Int(..) | Expr::Float(..) | Expr::Str(..) | Expr::Var(..) | Expr::Con(..) => {}
    }
}

/// Heap-typed `Var` binders introduced by a constructor pattern (`C y ys` →
/// those of `y`/`ys` whose field type is a `data`/tuple). Recurses into nested
/// constructor patterns; tuple sub-patterns are skipped (element types unknown
/// here — conservative, never a false positive).
fn pat_heap_binders(
    pat: &Pat,
    sty: Option<&Type>,
    ctx: &Ctx,
    tys: &mut HashMap<String, Type>,
) -> Vec<(String, Span)> {
    let mut out = Vec::new();
    collect_pat_heap(pat, sty, ctx, tys, &mut out);
    out
}

fn collect_pat_heap(
    pat: &Pat,
    sty: Option<&Type>,
    ctx: &Ctx,
    tys: &mut HashMap<String, Type>,
    out: &mut Vec<(String, Span)>,
) {
    if let Pat::Con(c, subpats, _) = pat {
        if let Some(ftys) = con_field_types(c, sty, ctx) {
            for (sp, fty) in subpats.iter().zip(&ftys) {
                match sp {
                    Pat::Var(name, span) => {
                        if is_heap_ty(fty, ctx) {
                            out.push((name.clone(), *span));
                        }
                        tys.insert(name.clone(), fty.clone());
                    }
                    Pat::Con(..) => collect_pat_heap(sp, Some(fty), ctx, tys, out),
                    _ => {}
                }
            }
        }
    }
}

/// The field types of constructor `c`, with its `data` type's parameters replaced by the
/// scrutinee type's arguments when that type is known (`Right` at `Either Int (List String)` →
/// `[List String]`); otherwise the declared (possibly polymorphic) field types.
fn con_field_types(c: &str, sty: Option<&Type>, ctx: &Ctx) -> Option<Vec<Type>> {
    let ftys = ctx.con_fields.get(c)?;
    let params = ctx.con_params.get(c);
    let mut args = Vec::new();
    let mut t = sty;
    while let Some(Type::App(f, a)) = t {
        args.push(a.as_ref().clone());
        t = Some(f.as_ref());
    }
    args.reverse();
    match params {
        Some(ps) if !ps.is_empty() && ps.len() == args.len() => {
            let sub: HashMap<&str, &Type> =
                ps.iter().map(String::as_str).zip(args.iter()).collect();
            Some(ftys.iter().map(|f| subst_ty(f, &sub)).collect())
        }
        _ => Some(ftys.clone()),
    }
}

fn subst_ty(t: &Type, sub: &HashMap<&str, &Type>) -> Type {
    match t {
        Type::Var(v) => sub
            .get(v.as_str())
            .map_or_else(|| t.clone(), |r| (*r).clone()),
        Type::App(f, a) => Type::App(Box::new(subst_ty(f, sub)), Box::new(subst_ty(a, sub))),
        Type::Arrow { mult, from, to } => Type::Arrow {
            mult: *mult,
            from: Box::new(subst_ty(from, sub)),
            to: Box::new(subst_ty(to, sub)),
        },
        Type::Tuple(ts) => Type::Tuple(ts.iter().map(|x| subst_ty(x, sub)).collect()),
        Type::Con(_) | Type::Unit => t.clone(),
    }
}

/// The type of a `case` scrutinee (or `let` right-hand side) when it is evident without
/// inference: a binder of known type, or a saturated call of a function whose declared
/// result type is closed (no type variables — a polymorphic result is left unknown).
fn scrut_type(e: &Expr, tys: &HashMap<String, Type>, ctx: &Ctx) -> Option<Type> {
    match e {
        Expr::Var(v, _) => tys.get(v).cloned(),
        Expr::App(..) => {
            let (head, args) = spine(e);
            let Expr::Var(f, _) = head else { return None };
            if tys.contains_key(f) {
                return None; // a local shadows the top-level function
            }
            let sig = ctx.fn_sigs.get(f)?;
            if sig.param_types().len() != args.len() {
                return None;
            }
            let rt = crate::core::result_type(sig);
            (!has_ty_var(rt)).then(|| rt.clone())
        }
        _ => None,
    }
}

fn has_ty_var(t: &Type) -> bool {
    match t {
        Type::Var(_) => true,
        Type::App(f, a) => has_ty_var(f) || has_ty_var(a),
        Type::Arrow { from, to, .. } => has_ty_var(from) || has_ty_var(to),
        Type::Tuple(ts) => ts.iter().any(has_ty_var),
        Type::Con(_) | Type::Unit => false,
    }
}

/// Per-clause summary of `where`-local functions, so a `let z = local xs`
/// heap-returning call is not laundered past the contraction check (the
/// module-level `fn_ret_heap` sees only top-level functions). `always` = returns a
/// heap value regardless of args; `proj[g] = i` = returns its i-th parameter (so
/// `local xs` is heap iff `xs` is).
#[derive(Default)]
struct LocalHeap {
    always: HashSet<String>,
    proj: HashMap<String, usize>,
}

/// Builds the [`LocalHeap`] summary for a clause's `where`-locals.
fn build_local_heap(wher: &[Func], ctx: &Ctx) -> LocalHeap {
    let mut lh = LocalHeap::default();
    for w in wher {
        let [c] = w.clauses.as_slice() else { continue };
        let Body::Plain(body) = &c.body else { continue };
        // projection: the body returns one of the parameters directly.
        if let Expr::Var(n, _) = body {
            if let Some(i) = c
                .pats
                .iter()
                .position(|p| matches!(p, Pat::Var(pn, _) if pn == n))
            {
                lh.proj.insert(w.name.clone(), i);
                continue;
            }
        }
        if expr_structurally_heap(body, ctx, &lh) {
            lh.always.insert(w.name.clone());
        }
    }
    lh
}

/// `true` if `e` STRUCTURALLY yields a heap value regardless of its inputs: a
/// tuple, a constructor application, a call to a heap-returning function, or an
/// `if`/`case`/`let` whose result is such. (No heap-binder set needed — used to
/// classify a `where`-local's body.)
fn expr_structurally_heap(e: &Expr, ctx: &Ctx, lh: &LocalHeap) -> bool {
    match e {
        Expr::Tuple(..) => true,
        Expr::If(_, t, el, _) => {
            expr_structurally_heap(t, ctx, lh) || expr_structurally_heap(el, ctx, lh)
        }
        Expr::Case(_, arms, _) => arms.iter().any(|(_, b)| expr_structurally_heap(b, ctx, lh)),
        Expr::Let(_, body, _) => expr_structurally_heap(body, ctx, lh),
        _ => {
            let (head, args) = spine(e);
            match head {
                Expr::Con(c, _) => !args.is_empty() && ctx.con_fields.contains_key(c),
                Expr::Var(f, _) => {
                    !args.is_empty() && (ctx.fn_ret_heap.contains(f) || lh.always.contains(f))
                }
                _ => false,
            }
        }
    }
}

/// `true` if `rhs` can evaluate to a heap value the `let`/`where` binder
/// owns/aliases — so contracting the binder (moving it into two owned slots)
/// double-frees. Covers an alias of an in-scope heap binder, a fresh tuple, a
/// constructor application (a boxed `data` value — nullary constructors are
/// immediate), a call to a heap-returning function (top-level or a `where`-local,
/// including a projection), and `if`/`case`/`let` whose result can be heap.
/// Conservative toward heap (may reject a genuinely-unsafe contraction; never a
/// copyable value — `is_heap_ty` gates on `data`/tuple).
fn rhs_is_heap(rhs: &Expr, heap: &HashSet<String>, ctx: &Ctx, lh: &LocalHeap) -> bool {
    match rhs {
        Expr::Var(n, _) => heap.contains(n),
        Expr::Tuple(..) => true,
        Expr::If(_, t, e, _) => rhs_is_heap(t, heap, ctx, lh) || rhs_is_heap(e, heap, ctx, lh),
        Expr::Case(_, arms, _) => arms.iter().any(|(_, b)| rhs_is_heap(b, heap, ctx, lh)),
        Expr::Let(_, body, _) => rhs_is_heap(body, heap, ctx, lh),
        _ => {
            let (callee, args) = spine(rhs);
            match callee {
                // a boxed constructor value (nullary constructors are immediate)
                Expr::Con(c, _) => !args.is_empty() && ctx.con_fields.contains_key(c),
                Expr::Var(f, _) => {
                    // a call to a heap-returning function (top-level or where-local)…
                    if !args.is_empty() && (ctx.fn_ret_heap.contains(f) || lh.always.contains(f)) {
                        return true;
                    }
                    // …or a projection `local xs` → heap iff the projected arg is.
                    if let Some(&i) = lh.proj.get(f) {
                        return args.get(i).is_some_and(|a| rhs_is_heap(a, heap, ctx, lh));
                    }
                    false
                }
                _ => false,
            }
        }
    }
}

fn push_contraction(
    name: &str,
    span: Span,
    n: usize,
    scope: &[&Expr],
    ctx: &Ctx,
    diags: &mut Diagnostics,
) {
    diags.push(contraction_diag(name, span, n, scope, ctx));
}

/// AX0001 for a heap value given away more than once, labelling each place it is given away
/// (`scope` = the expressions it is used in) and naming the function or constructor that takes it.
fn contraction_diag(name: &str, span: Span, n: usize, scope: &[&Expr], ctx: &Ctx) -> Diagnostic {
    let mut d = Diagnostic::error(
        "AX0001",
        format!("heap value '{name}' consumed {n} times (contraction forbidden)"),
    )
    .label(
        span.0,
        span.1,
        format!("'{name}' is moved into an owned position more than once"),
    );
    let mut sites = Vec::new();
    for e in scope {
        consume_sites(name, e, ctx, &mut sites);
    }
    sites.sort_by_key(|(_, sp)| *sp);
    for (what, sp) in &sites {
        d = d.label(sp.0, sp.1, format!("given to {what} here"));
    }
    d.with_help(
        "a heap value may be READ any number of times, but given away (to a constructor, a \
         tuple, or a function that takes ownership of the argument) only once. A function takes \
         ownership when its parameter is `%1`, or when it keeps or passes on part of the argument \
         — the compiler infers that, e.g. a function passing a field to `filter` owns the value, \
         because `filter` consumes the list it is given. To use the value twice, make those \
         calls only read it, compute both results in one call, or 'split' it into two %0.5 \
         halves (§2).",
    )
}

/// AX0007: a resource parameter without `%1` (borrowed: the caller still owns it) is given
/// away — passed to a function that takes ownership (`Own`, `%1`) or stored.
fn borrowed_resource_consumed(
    name: &str,
    span: Span,
    func: &str,
    clause: &Clause,
    ctx: &Ctx,
) -> Diagnostic {
    // a lifted lambda (`hoflamN`, `hoflamcapN`) has no name the user wrote
    let func = if func.starts_with("hoflam") {
        "this lambda"
    } else {
        func
    };
    let mut d = Diagnostic::error(
        "AX0007",
        format!("borrowed resource '{name}' is consumed in '{func}'"),
    )
    .label(
        span.0,
        span.1,
        format!("'{name}' is borrowed: its type has no `%1`"),
    );
    let mut sites = Vec::new();
    for e in clause_exprs(clause) {
        consume_sites(name, e, ctx, &mut sites);
    }
    sites.sort_by_key(|(_, sp)| *sp);
    for (what, sp) in &sites {
        d = d.label(sp.0, sp.1, format!("given to {what} here"));
    }
    d.with_help(
        "a parameter without `%1` is borrowed: the caller keeps ownership and consumes the \
         resource itself, so consuming it here as well would consume it twice (a double close). \
         To take ownership, mark the parameter `%1` in the signature (e.g. `Handle Dev %1 -> \
         Int`; for a lambda, in the function type it is passed as); the caller then gives it up. To only use it here, call \
         functions that borrow it (`Borrow` in a foreign signature)."
    )
}

/// Every place `name` is given away in `e`: an argument in a position the callee takes `%1`
/// (declared or inferred), a constructor field, or a tuple component.
fn consume_sites(name: &str, e: &Expr, ctx: &Ctx, out: &mut Vec<(String, Span)>) {
    let is_name = |x: &Expr| matches!(x, Expr::Var(v, _) if v == name);
    match e {
        Expr::App(..) => {
            let (head, args) = spine(e);
            let mults = head_mults(head, ctx);
            // a constructor stores every field by ownership; a call only its `%1` arguments
            let is_con = matches!(head, Expr::Con(..));
            for (i, a) in args.iter().enumerate() {
                if is_name(a) && (is_con || mults.get(i) == Some(&Mult::One)) {
                    let what = match head {
                        Expr::Var(g, _) => format!("`{g}`"),
                        Expr::Con(c, _) => format!("the constructor `{c}`"),
                        _ => "a call".to_string(),
                    };
                    out.push((what, a.span()));
                }
            }
            consume_sites(name, head, ctx, out);
            for a in args {
                consume_sites(name, a, ctx, out);
            }
        }
        Expr::Tuple(es, _) => {
            for x in es {
                if is_name(x) {
                    out.push(("a tuple".to_string(), x.span()));
                }
                consume_sites(name, x, ctx, out);
            }
        }
        Expr::BinOp(_, l, r, _) => {
            consume_sites(name, l, ctx, out);
            consume_sites(name, r, ctx, out);
        }
        Expr::If(c, t, el, _) => {
            for x in [c, t, el] {
                consume_sites(name, x, ctx, out);
            }
        }
        Expr::Let(binds, body, _) => {
            for b in binds {
                for c in &b.clauses {
                    if let Body::Plain(x) = &c.body {
                        consume_sites(name, x, ctx, out);
                    }
                }
            }
            consume_sites(name, body, ctx, out);
        }
        Expr::Case(scrut, arms, _) => {
            consume_sites(name, scrut, ctx, out);
            for (_, b) in arms {
                consume_sites(name, b, ctx, out);
            }
        }
        Expr::RecordCon(_, fs, _) => fs
            .iter()
            .for_each(|(_, x)| consume_sites(name, x, ctx, out)),
        Expr::RecordUpd(base, fs, _) => {
            consume_sites(name, base, ctx, out);
            fs.iter()
                .for_each(|(_, x)| consume_sites(name, x, ctx, out));
        }
        Expr::Lam(_, body, _) => consume_sites(name, body, ctx, out),
        Expr::Var(..) | Expr::Int(..) | Expr::Float(..) | Expr::Str(..) | Expr::Con(..) => {}
    }
}

/// The expressions of a clause (body, guards).
fn clause_exprs(c: &Clause) -> Vec<&Expr> {
    match &c.body {
        Body::Plain(e) => vec![e],
        Body::Guarded(arms) => arms.iter().flat_map(|(g, r)| [g, r]).collect(),
    }
}

/// Emits the diagnostic or records the drop, applying the linearity rule to a
/// linear resource (parameter or `let` value), given the analysis result.
fn report_resource(
    name: &str,
    class: &Lin,
    label: Span,
    u: &ResUse,
    func: &str,
    diags: &mut Diagnostics,
    out: &mut Analysis,
) {
    if u.consumes > 1 {
        diags.push(
            Diagnostic::error(
                "AX0001",
                format!(
                    "linear resource '{name}' consumed {} times (contraction forbidden)",
                    u.consumes
                ),
            )
            .label(
                label.0,
                label.1,
                format!("'{name}' is %1: consumable only once"),
            )
            .with_help(
                "reading (borrowing) a %1 is free and unlimited; moving ownership \
                 (consuming) may happen only once — to share it by ownership, use \
                 'split' into two %0.5 halves (§2).",
            ),
        );
    } else if let Some((mv, use_sp)) = u.uam {
        diags.push(use_after_move_diag(name, mv, use_sp));
    } else if u.min_consumes == 0 && u.consumes > 0 && class.no_drop {
        diags.push(
            Diagnostic::error(
                "AX0002",
                format!("must-use resource '{name}' is not consumed on every path"),
            )
            .label(
                label.0,
                label.1,
                format!("'{name}' : {} %1 (no Drop)", class.ty),
            )
            .with_help(
                "some `if`/`case` branch consumes it and another does not, so that path leaks \
                     it: consume it (or pass it on) in every branch (§2).",
            ),
        );
    } else if u.consumes == 0 && class.must_use {
        diags.push(
            Diagnostic::error(
                "AX0002",
                format!("must-use resource '{name}' dropped without being consumed"),
            )
            .label(
                label.0,
                label.1,
                format!("'{name}' : {} %1 (no Drop)", class.ty),
            )
            .with_help(
                "endpoints, Token and handles are must-use (they have no Drop); \
                     consume it or return it (§2).",
            ),
        );
    } else if u.consumes == 0 {
        // droppable, never consumed: Auto-Drop at the death point (last
        // leitura, ou a entrada se nunca lido).
        let (death, reason) = match u.death {
            Some(s) if u.borrows > 0 => (s, "dies after the last read"),
            _ => (label, "dies at entry (never used)"),
        };
        out.drops.push(DropPoint {
            func: func.to_string(),
            var: name.to_string(),
            ty: class.ty.clone(),
            span: death,
            reason,
        });
    }
}

pub fn collect_pat_vars(p: &Pat, out: &mut HashSet<String>) {
    match p {
        Pat::Var(n, _) => {
            out.insert(n.clone());
        }
        Pat::Con(_, args, _) | Pat::Tuple(args, _) => {
            for a in args {
                collect_pat_vars(a, out);
            }
        }
        Pat::Wild(_) | Pat::Int(_, _) | Pat::Str(_, _) => {}
    }
}

fn resolve_clause(
    clause: &Clause,
    scope: &HashSet<String>,
    globals: &HashSet<String>,
    diags: &mut Diagnostics,
) {
    match &clause.body {
        Body::Plain(e) => resolve_expr(e, scope, globals, diags),
        Body::Guarded(arms) => {
            for (g, r) in arms {
                resolve_expr(g, scope, globals, diags);
                resolve_expr(r, scope, globals, diags);
            }
        }
    }
    for w in &clause.wher {
        for c in &w.clauses {
            let mut s = scope.clone();
            for p in &c.pats {
                collect_pat_vars(p, &mut s);
            }
            resolve_clause(c, &s, globals, diags);
        }
    }
}

/// Levenshtein edit distance (small strings; used only for typo suggestions).
fn edit_distance(a: &str, b: &str) -> usize {
    let (a, b): (Vec<char>, Vec<char>) = (a.chars().collect(), b.chars().collect());
    let mut prev: Vec<usize> = (0..=b.len()).collect();
    let mut cur = vec![0usize; b.len() + 1];
    for (i, ca) in a.iter().enumerate() {
        cur[0] = i + 1;
        for (j, cb) in b.iter().enumerate() {
            let cost = usize::from(ca != cb);
            cur[j + 1] = (prev[j] + cost).min(cur[j] + 1).min(prev[j + 1] + 1);
        }
        std::mem::swap(&mut prev, &mut cur);
    }
    prev[b.len()]
}

/// The closest in-scope name to `n` (a mis-spelling), if one is within edit
/// distance 2 — the source of the AX0101 "did you mean" suggestion. Skips very
/// short candidates (len < 3) to avoid noisy 1-2 char coincidences.
fn nearest_name(n: &str, scope: &HashSet<String>, globals: &HashSet<String>) -> Option<String> {
    if n.len() < 3 {
        return None;
    }
    scope
        .iter()
        .chain(globals.iter())
        .filter(|c| c.len() >= 3)
        .map(|c| (edit_distance(n, c), c))
        .filter(|(d, _)| *d <= 2)
        .min_by_key(|(d, c)| (*d, c.len(), (*c).clone()))
        .map(|(_, c)| c.clone())
}

fn resolve_expr(
    e: &Expr,
    scope: &HashSet<String>,
    globals: &HashSet<String>,
    diags: &mut Diagnostics,
) {
    match e {
        Expr::Var(n, sp) => {
            if !scope.contains(n) && !globals.contains(n) {
                let mut d = Diagnostic::error("AX0101", format!("name not found: '{n}'")).label(
                    sp.0,
                    sp.1,
                    "not in scope",
                );
                // machine-applicable fix: suggest the closest in-scope name (§8).
                match nearest_name(n, scope, globals) {
                    Some(best) => {
                        d = d.with_help(format!("did you mean `{best}`?")).with_fix(
                            sp.0,
                            sp.1,
                            best.clone(),
                            format!("`{n}` → `{best}`"),
                        );
                    }
                    None => {
                        d = d.with_help(
                            "check the spelling, or whether it is a parameter/local in \
                             scope, or a missing top-level function/import.",
                        );
                    }
                }
                diags.push(d);
            }
        }
        Expr::Int(_, _) | Expr::Float(_, _) | Expr::Str(_, _) | Expr::Con(_, _) => {}
        Expr::App(f, x, _) => {
            resolve_expr(f, scope, globals, diags);
            resolve_expr(x, scope, globals, diags);
        }
        Expr::BinOp(op, l, r, sp) => {
            // A user operator (`a <+> b`) or backtick function (`` a `f` b ``) names a
            // plain function that must be in scope — resolve it like a `Var`. The
            // built-in symbolic operators are lowered directly by codegen, so they are
            // always valid and skipped here. (`:`/`.`/`$` never reach `BinOp` — the
            // parser desugars them to `Cons`/`compose`/application.)
            const BUILTIN_OPS: &[&str] = &[
                "+", "-", "*", "/", "==", "<", ">", "++", "+.", "-.", "*.", "/.", "==.", "<.",
                ">.", ".&.", ".|.",
            ];
            // Only SYMBOLIC operators (`<+>`) are resolved: an alphabetic backtick name
            // (`` `mod` ``, `` `div` ``) may be a builtin that lives outside `globals`, so
            // it keeps its prior (unchecked) treatment rather than a false positive.
            let symbolic = op
                .chars()
                .next()
                .is_some_and(|c| !c.is_alphabetic() && c != '_');
            if symbolic
                && !BUILTIN_OPS.contains(&op.as_str())
                && !scope.contains(op)
                && !globals.contains(op)
            {
                let mut d = Diagnostic::error("AX0101", format!("name not found: '{op}'")).label(
                    sp.0,
                    sp.1,
                    "operator not in scope",
                );
                d = match nearest_name(op, scope, globals) {
                    Some(best) => d.with_help(format!("did you mean `{best}`?")),
                    None => d.with_help(
                        "define it — `(<op>) x y = …` — or import it, or check the spelling.",
                    ),
                };
                diags.push(d);
            }
            resolve_expr(l, scope, globals, diags);
            resolve_expr(r, scope, globals, diags);
        }
        Expr::If(c, t, el, _) => {
            resolve_expr(c, scope, globals, diags);
            resolve_expr(t, scope, globals, diags);
            resolve_expr(el, scope, globals, diags);
        }
        Expr::Tuple(es, _) => {
            for e in es {
                resolve_expr(e, scope, globals, diags);
            }
        }
        Expr::Let(binds, body, _) => {
            let mut s = scope.clone();
            for b in binds {
                s.insert(b.name.clone());
            }
            for b in binds {
                for c in &b.clauses {
                    let mut cs = s.clone();
                    for p in &c.pats {
                        collect_pat_vars(p, &mut cs);
                    }
                    resolve_clause(c, &cs, globals, diags);
                }
            }
            resolve_expr(body, &s, globals, diags);
        }
        Expr::Case(scrut, arms, _) => {
            resolve_expr(scrut, scope, globals, diags);
            for (pat, body) in arms {
                let mut s = scope.clone();
                collect_pat_vars(pat, &mut s);
                resolve_expr(body, &s, globals, diags);
            }
        }
        Expr::RecordCon(_, fields, _) => {
            for (_, e) in fields {
                resolve_expr(e, scope, globals, diags);
            }
        }
        Expr::RecordUpd(base, fields, _) => {
            resolve_expr(base, scope, globals, diags);
            for (_, e) in fields {
                resolve_expr(e, scope, globals, diags);
            }
        }
        Expr::Lam(pats, body, _) => {
            let mut s = scope.clone();
            for p in pats {
                collect_pat_vars(p, &mut s);
            }
            resolve_expr(body, &s, globals, diags);
        }
    }
}

// --- fine liveness analysis: borrow vs consumption (§2) ---
//
// A %1 resource can be READ (borrowed, without consuming — Borrow
// Elision) many times, but CONSUMED (ownership flowing out) at most
// once. The position of each occurrence decides: argument of a %1 parameter,
// %1 field, or return value ⇒ consumption; everything else ⇒ borrow.
//
// Assumed limitation of this cut: ORDER is not checked (a borrow after
// a consumption would be use-after-move; left for the next step).

#[derive(Clone, Copy, PartialEq)]
enum Mode {
    Consume,
    Borrow,
}

/// Multiplicities of parameters/fields (functions, constructors) + mult per field
/// + the set of `data` types that are must-use (structural propagation).
#[derive(Debug, Clone)]
#[cfg_attr(feature = "salsa", derive(salsa::SalsaValue, PartialEq))]
struct Ctx {
    /// function/constructor → multiplicities of the parameters/fields (in order)
    consumers: HashMap<String, Vec<Mult>>,
    /// field name → declared multiplicity (for records)
    field_mults: HashMap<String, Mult>,
    /// must-use `data` types (because they recursively contain a field without `Drop`)
    must_use_types: HashSet<String>,
    /// user `data` type names — a heap allocation that is deep-dropped (so it may
    /// not be duplicated by ownership: contraction is a double-free, AX0001).
    data_names: HashSet<String>,
    /// constructor name → its field types (positional), for classifying the heap-ness
    /// of `case`-extracted field binders in the contraction check.
    con_fields: HashMap<String, Vec<Type>>,
    /// constructor name → its `data` type's parameters, to instantiate polymorphic field
    /// types (`Right b`) with the scrutinee's type arguments (`Either Int (List String)`).
    con_params: HashMap<String, Vec<String>>,
    /// function → declared signature (user functions with one), to type a `case` scrutinee
    /// that is a saturated call.
    fn_sigs: HashMap<String, Type>,
    /// functions whose RESULT is a heap value (`data`/tuple) — so `let z = f a`
    /// binds a heap value that must not be contracted (moved into two owned slots).
    fn_ret_heap: HashSet<String>,
    /// user and foreign functions whose declared RESULT has no destructor (`Handle a`, an
    /// endpoint…) → that type's head, so `let h = openDev 7` is tracked like a `%1` parameter.
    fn_ret_must_use: HashMap<String, String>,
    /// must-use types with no destructor at all (see [`build_no_drop_types`])
    no_drop_types: HashSet<String>,
    /// user and foreign functions whose declared RESULT is a plain scalar (`Int`, `Float`, `Bool`,
    /// `Char`, `()`): a value that cannot carry a linear resource it consumed (`pclose h` → Int).
    fn_ret_scalar: HashSet<String>,
}

/// A value of this type is a HEAP allocation that gets deep-dropped, so moving it
/// into an owned position more than once double-frees (AX0001). A bare type var is
/// NOT heap here — its heap-ness is unknown until monomorphization (conservative:
/// no false positive on a copyable `Int` element).
fn is_heap_ty(ty: &Type, ctx: &Ctx) -> bool {
    matches!(ty, Type::Tuple(_)) || ty.head_con().is_some_and(|h| ctx.data_names.contains(h))
}

fn build_ctx(module: &Module) -> Ctx {
    let mut consumers = HashMap::new();
    let mut field_mults = HashMap::new();
    for f in &module.funcs {
        if let Some(sig) = &f.sig {
            consumers.insert(f.name.clone(), sig.param_mults());
        }
    }
    let mut con_fields = HashMap::new();
    let mut con_params = HashMap::new();
    for d in &module.datas {
        for c in &d.cons {
            con_params.insert(c.name.clone(), d.params.clone());
            consumers.insert(c.name.clone(), c.fields.iter().map(|f| f.mult).collect());
            con_fields.insert(
                c.name.clone(),
                c.fields.iter().map(|f| f.ty.clone()).collect(),
            );
            for f in &c.fields {
                if !f.name.is_empty() {
                    consumers.insert(f.name.clone(), vec![Mult::Many]); // selector: borrows
                    field_mults.insert(f.name.clone(), f.mult);
                }
            }
        }
    }
    // `split` consumes the %1 it divides (to split it into two %0.5 halves).
    consumers.insert("split".to_string(), vec![Mult::One]);
    // Async sockets (docs/async-sockets.md): `Sock`/`Listener` are linear fd resources.
    // recv/send/accept BORROW the socket (Many — repeatable reads/writes, like a Buffer read);
    // close CONSUMES it (One), so linearity enforces close-exactly-once. The String/Int args are
    // inert (Many). Constructors (connect/listen) take inert args and return a fresh owned resource.
    consumers.insert("netConnect".to_string(), vec![Mult::Many, Mult::Many]);
    consumers.insert("netListen".to_string(), vec![Mult::Many]);
    consumers.insert("netAccept".to_string(), vec![Mult::Many]);
    consumers.insert("netRecv".to_string(), vec![Mult::Many]);
    consumers.insert("netSend".to_string(), vec![Mult::Many, Mult::Many]);
    consumers.insert("netClose".to_string(), vec![Mult::One]);
    consumers.insert("netCloseL".to_string(), vec![Mult::One]);
    consumers.insert(
        "netSendBuf".to_string(),
        vec![Mult::Many, Mult::Many, Mult::Many, Mult::Many],
    );
    // a `File` is borrowed by every op but `fileClose`, which consumes it (close exactly once)
    consumers.insert("fileOpenRaw".to_string(), vec![Mult::Many]);
    consumers.insert("fileErrno".to_string(), vec![Mult::Many]);
    consumers.insert("fileSize".to_string(), vec![Mult::Many]);
    consumers.insert("fileRead".to_string(), vec![Mult::Many, Mult::Many]);
    consumers.insert("fileClose".to_string(), vec![Mult::One]);
    consumers.insert("bufLen".to_string(), vec![Mult::Many]);
    // Buffer U8 linear (§4/§5): as ops in-place (bufIota/xorInPlace) e o `free`
    // consume the %1 Buffer (xorInPlace returns a fresh %1 — the linear thread);
    // sumBytes/withBuffer only borrow.
    consumers.insert("bufIota".to_string(), vec![Mult::One]);
    consumers.insert("xorInPlace".to_string(), vec![Mult::One, Mult::Many]);
    consumers.insert("free".to_string(), vec![Mult::One]);
    consumers.insert("sumBytes".to_string(), vec![Mult::Many]);
    consumers.insert("newBuffer".to_string(), vec![Mult::Many]);
    consumers.insert("withBuffer".to_string(), vec![Mult::Many, Mult::Many]);
    // Buffer peek/poke + bufPtr all BORROW the buffer (read/write in place, no consume), so the
    // same buffer stays usable across many ops — every arg is Mult::Many.
    for n in [
        "peekU8", "peekU16", "peekU32", "peekU64", "peekF64", "bufPtr", "bufPtrN",
    ] {
        consumers.insert(n.to_string(), vec![Mult::Many, Mult::Many]);
    }
    for n in ["pokeU8", "pokeU16", "pokeU32", "pokeU64", "pokeF64"] {
        consumers.insert(n.to_string(), vec![Mult::Many, Mult::Many, Mult::Many]);
    }
    // Array (§A Phase 2): setArray consumes the array (in-place), others borrow.
    consumers.insert("newArray".to_string(), vec![Mult::Many, Mult::Many]);
    consumers.insert("getArray".to_string(), vec![Mult::Many, Mult::Many]);
    consumers.insert(
        "setArray".to_string(),
        vec![Mult::One, Mult::Many, Mult::Many],
    );
    consumers.insert("lenArray".to_string(), vec![Mult::Many]);
    // parFor consumes the array (written in place, like `setArray`) and borrows the kernel
    consumers.insert("parFor".to_string(), vec![Mult::One, Mult::Many]);
    // SIMD (`simd.rs`): a vector store consumes the array (in place, like `setArray`); a load
    // borrows it; vectors and lanes are plain values.
    for name in crate::simd::names() {
        let m = match crate::simd::builtin(name) {
            Some(crate::simd::Builtin::Store(_)) => vec![Mult::One, Mult::Many, Mult::Many],
            Some(b) => vec![Mult::Many; crate::simd::arity(b)],
            None => continue,
        };
        consumers.insert(name.to_string(), m);
    }
    // TritVec (§10): like Array — setTritVec consumes the vec (in-place, returns
    // the same linear thread), the others borrow.
    consumers.insert("newTritVec".to_string(), vec![Mult::Many, Mult::Many]);
    consumers.insert("getTritVec".to_string(), vec![Mult::Many, Mult::Many]);
    consumers.insert(
        "setTritVec".to_string(),
        vec![Mult::One, Mult::Many, Mult::Many],
    );
    consumers.insert("lenTritVec".to_string(), vec![Mult::Many]);
    // tritDot borrows both the vec and the activation array (reads, returns Int).
    consumers.insert("tritDot".to_string(), vec![Mult::Many, Mult::Many]);
    // tritMatVecSum borrows the vec + activation; the K arg is inert.
    consumers.insert(
        "tritMatVecSum".to_string(),
        vec![Mult::Many, Mult::Many, Mult::Many],
    );
    // tritVecFromBuffer borrows the buffer (caller frees it); the Int is inert.
    consumers.insert(
        "tritVecFromBuffer".to_string(),
        vec![Mult::Many, Mult::Many],
    );
    // bulk builders: the Int arg is inert; the result is a fresh owned resource.
    consumers.insert("tritVecIota".to_string(), vec![Mult::Many]);
    consumers.insert("arrayIota".to_string(), vec![Mult::Many]);
    // I8Array (Phase B): setI8 consumes the array (in-place), others borrow;
    // constructors take inert Ints.
    consumers.insert("newI8Array".to_string(), vec![Mult::Many, Mult::Many]);
    consumers.insert("i8Iota".to_string(), vec![Mult::Many]);
    consumers.insert("getI8".to_string(), vec![Mult::Many, Mult::Many]);
    consumers.insert("setI8".to_string(), vec![Mult::One, Mult::Many, Mult::Many]);
    consumers.insert("lenI8".to_string(), vec![Mult::Many]);
    consumers.insert(
        "i8MatVecSum".to_string(),
        vec![Mult::Many, Mult::Many, Mult::Many],
    );
    // general dense-array primitives: readers borrow; setI32 consumes arg 0.
    consumers.insert("i8Sum".to_string(), vec![Mult::Many]);
    consumers.insert("i8Dot".to_string(), vec![Mult::Many, Mult::Many]);
    consumers.insert("i8DotI8".to_string(), vec![Mult::Many, Mult::Many]);
    consumers.insert("arraySum".to_string(), vec![Mult::Many]);
    consumers.insert("arrayDot".to_string(), vec![Mult::Many, Mult::Many]);
    consumers.insert("newI32Array".to_string(), vec![Mult::Many, Mult::Many]);
    consumers.insert("i32Iota".to_string(), vec![Mult::Many]);
    consumers.insert("getI32".to_string(), vec![Mult::Many, Mult::Many]);
    consumers.insert(
        "setI32".to_string(),
        vec![Mult::One, Mult::Many, Mult::Many],
    );
    consumers.insert("lenI32".to_string(), vec![Mult::Many]);
    consumers.insert("i32Sum".to_string(), vec![Mult::Many]);
    consumers.insert("i32Dot".to_string(), vec![Mult::Many, Mult::Many]);
    consumers.insert(
        "i32MatVecSum".to_string(),
        vec![Mult::Many, Mult::Many, Mult::Many],
    );
    // foldBytes (f init buf) borrows the buffer (reads without consuming) — Listing 2.2.
    consumers.insert(
        "foldBytes".to_string(),
        vec![Mult::Many, Mult::Many, Mult::Many],
    );
    // channels / session types (§6): send/recv/close CONSUME the %1 endpoint (ownership
    // it moves; the result is the advanced endpoint — the session's linear thread). The
    // `send` payload is borrowed. Protocol fidelity is checked
    // parte (`check_sessions`).
    consumers.insert("send".to_string(), vec![Mult::One, Mult::Many]);
    consumers.insert("recv".to_string(), vec![Mult::One]);
    consumers.insert("close".to_string(), vec![Mult::One]);
    // choice: `select L c` consumes the endpoint (arg 1); `offer c` consumes it.
    consumers.insert("select".to_string(), vec![Mult::Many, Mult::One]);
    consumers.insert("offer".to_string(), vec![Mult::One]);
    consumers.insert("cancel".to_string(), vec![Mult::One]);
    // nursery (§9): the `bound`'s body is borrowed; `spawn` receives the child closure.
    consumers.insert("bound".to_string(), vec![Mult::Many]);
    consumers.insert("spawn".to_string(), vec![Mult::Many]);
    // structured fork-join (§9): `parMap w xs` borrows the worker closure and the
    // input list. The N endpoints live inside the primitive's own nursery — they
    // never enter the caller's linear environment — so the result `List` is a plain
    // value with no must-use obligations.
    consumers.insert("parMap".to_string(), vec![Mult::Many, Mult::Many]);
    // worker↔worker (§9): `connect prod cons` borrows both worker closures (inert Many).
    consumers.insert("connect".to_string(), vec![Mult::Many, Mult::Many]);
    consumers.insert(
        "pipe3".to_string(),
        vec![Mult::Many, Mult::Many, Mult::Many],
    );
    // FFI imports (§18): each arg is borrowed by default (Axión keeps + frees it once), except an
    // `Own T` arg whose ownership transfers to C — that one is CONSUMED (Mult::One), so reusing it
    // after the call is AX0001 and Axión does not also free it.
    for fo in &module.foreigns {
        let (kinds, _) = fo.ffi_kinds();
        let mults = kinds
            .iter()
            .map(|&(own, _)| if own { Mult::One } else { Mult::Many })
            .collect();
        consumers.insert(fo.name.clone(), mults);
    }
    let data_names: HashSet<String> = module.datas.iter().map(|d| d.name.clone()).collect();
    // functions whose result type is a heap value (`data`/tuple) — a `let z = f a`
    // then binds a heap value that must not be contracted.
    let fn_ret_heap: HashSet<String> = module
        .funcs
        .iter()
        .filter(|f| {
            f.sig.as_ref().is_some_and(|s| {
                let rt = crate::core::result_type(s);
                matches!(rt, Type::Tuple(_))
                    || rt.head_con().is_some_and(|h| data_names.contains(h))
            })
        })
        .map(|f| f.name.clone())
        .collect();
    let must_use_types = build_must_use_types(module);
    let no_drop_types = build_no_drop_types(module);
    let sigs = module
        .funcs
        .iter()
        .filter_map(|f| Some((f.name.clone(), f.sig.clone()?)))
        .chain(
            module
                .foreigns
                .iter()
                .map(|fo| (fo.name.clone(), fo.sig.strip_ffi_wrappers())),
        );
    let fn_ret_scalar: HashSet<String> = sigs
        .clone()
        .filter(|(_, sig)| {
            let rt = crate::core::result_type(sig);
            matches!(rt, Type::Unit)
                || matches!(rt.head_con(), Some("Int" | "Float" | "Bool" | "Char"))
        })
        .map(|(name, _)| name)
        .collect();
    let user_names: HashSet<&str> = module
        .funcs
        .iter()
        .map(|f| f.name.as_str())
        .chain(module.foreigns.iter().map(|f| f.name.as_str()))
        .collect();
    let fn_ret_must_use = BUILTIN_MUST_USE_RESULTS
        .iter()
        .filter(|(name, _)| !user_names.contains(name))
        .map(|(name, ty)| (name.to_string(), ty.to_string()))
        .chain(sigs.filter_map(|(name, sig)| {
            let rt = crate::core::result_type(&sig);
            let head = rt.head_con()?.to_string();
            is_no_drop(rt, &no_drop_types).then_some((name, head))
        }))
        .collect();
    Ctx {
        consumers,
        field_mults,
        must_use_types,
        data_names,
        con_fields,
        con_params,
        fn_sigs: module
            .funcs
            .iter()
            .filter_map(|f| Some((f.name.clone(), f.sig.clone()?)))
            .collect(),
        fn_ret_heap,
        fn_ret_must_use,
        no_drop_types,
        fn_ret_scalar,
    }
}

type Uses = (usize, usize); // (consumptions, borrows)

fn add(a: Uses, b: Uses) -> Uses {
    (a.0 + b.0, a.1 + b.1)
}

fn alt(a: Uses, b: Uses) -> Uses {
    (a.0.max(b.0), a.1.max(b.1))
}

/// Like [`alt`], but keeps the FEWEST consumptions over alternative paths. A must-use value needs at
/// least one on EVERY path: the maximum alone hides a path that silently leaks it.
fn alt_min(a: Uses, b: Uses) -> Uses {
    (a.0.min(b.0), a.1.max(b.1))
}

/// Combines the alternatives of an `if`/`case`/guard set with `pick` ([`alt`] or [`alt_min`]).
fn alts(us: impl Iterator<Item = Uses>, pick: fn(Uses, Uses) -> Uses) -> Uses {
    us.reduce(pick).unwrap_or((0, 0))
}

fn analyze_clause(clause: &Clause, x: &str, ctx: &Ctx) -> Uses {
    analyze_clause_with(clause, x, ctx, alt)
}

fn analyze_clause_with(clause: &Clause, x: &str, ctx: &Ctx, pick: fn(Uses, Uses) -> Uses) -> Uses {
    // the clause's value is returned ⇒ consumption position
    let mut u = match &clause.body {
        Body::Plain(e) => analyze_with(e, x, Mode::Consume, ctx, pick),
        Body::Guarded(arms) => alts(
            arms.iter().map(|(g, r)| {
                add(
                    analyze_with(g, x, Mode::Borrow, ctx, pick),
                    analyze_with(r, x, Mode::Consume, ctx, pick),
                )
            }),
            pick,
        ),
    };
    for w in &clause.wher {
        for c in &w.clauses {
            u = add(u, analyze_clause_with(c, x, ctx, pick));
        }
    }
    u
}

/// (consumptions, borrows) of `x` in `e`, taking the MOST consuming alternative path.
fn analyze(e: &Expr, x: &str, mode: Mode, ctx: &Ctx) -> Uses {
    analyze_with(e, x, mode, ctx, alt)
}

fn analyze_with(e: &Expr, x: &str, mode: Mode, ctx: &Ctx, pick: fn(Uses, Uses) -> Uses) -> Uses {
    let analyze = |e: &Expr, x: &str, mode: Mode, ctx: &Ctx| analyze_with(e, x, mode, ctx, pick);
    match e {
        Expr::Var(n, _) => {
            if n == x {
                if mode == Mode::Consume {
                    (1, 0)
                } else {
                    (0, 1)
                }
            } else {
                (0, 0)
            }
        }
        Expr::Int(_, _) | Expr::Float(_, _) | Expr::Str(_, _) | Expr::Con(_, _) => (0, 0),
        // arithmetic/comparison operands are read, not consumed
        Expr::BinOp(_, l, r, _) => add(
            analyze(l, x, Mode::Borrow, ctx),
            analyze(r, x, Mode::Borrow, ctx),
        ),
        Expr::App(_, _, _) => {
            let (head, args) = spine(e);
            // A CONSTRUCTOR application takes OWNERSHIP of every field (the value is
            // deep-dropped with the structure), so each arg is CONSUMED — not
            // borrowed as `arg_mode` would say for a non-`%1` field. This is what
            // makes `Two xs xs` count `xs` as consumed twice (contraction, AX0001).
            let is_ctor = matches!(head, Expr::Con(_, _));
            let mults = head_mults(head, ctx);
            // an applied lambda `(\p -> b) a` runs once: its body is counted as is
            let mut u = match head {
                Expr::Lam(pats, body, _) if !binds_var(pats, x) => analyze(body, x, mode, ctx),
                _ => analyze(head, x, Mode::Borrow, ctx),
            };
            let once =
                matches!(head, Expr::Var(f, _) if RUNS_ITS_LAMBDA_ONCE.contains(&f.as_str()));
            for (i, a) in args.iter().enumerate() {
                let m = if is_ctor {
                    Mode::Consume
                } else {
                    arg_mode(mults.get(i))
                };
                u = add(
                    u,
                    match a {
                        Expr::Lam(pats, body, _) if once && !binds_var(pats, x) => {
                            analyze(body, x, m, ctx)
                        }
                        _ => analyze(a, x, m, ctx),
                    },
                );
            }
            u
        }
        // condition read; the branches are alternative paths, in the parent's mode
        Expr::If(c, t, el, _) => add(
            analyze(c, x, Mode::Borrow, ctx),
            pick(analyze(t, x, mode, ctx), analyze(el, x, mode, ctx)),
        ),
        Expr::Case(s, arms, _) => add(
            analyze(s, x, Mode::Borrow, ctx),
            alts(arms.iter().map(|(_, b)| analyze(b, x, mode, ctx)), pick),
        ),
        Expr::Let(binds, body, _) => {
            let in_binds = binds
                .iter()
                .flat_map(|b| &b.clauses)
                .map(|c| analyze_clause_with(c, x, ctx, pick))
                .fold((0, 0), add);
            add(in_binds, analyze(body, x, mode, ctx))
        }
        // a returned tuple makes ownership of the components flow outward
        Expr::Tuple(es, _) => es
            .iter()
            .map(|e| analyze(e, x, mode, ctx))
            .fold((0, 0), add),
        Expr::RecordCon(_, assigns, _) => analyze_assigns(assigns, x, ctx, pick),
        Expr::RecordUpd(base, assigns, _) => add(
            analyze(base, x, Mode::Consume, ctx), // the update takes ownership of the base
            analyze_assigns(assigns, x, ctx, pick),
        ),
        // a lambda that shadows x doesn't reference it; otherwise count the body. A lambda may
        // run any number of times (`map`, `parFor`, a `let`-bound function called twice): if it
        // gives away a value it captured, each run gives it away again — so that counts as more
        // than once (AX0001), unless the lambda provably runs once (applied on the spot, or the
        // argument of a built-in in `RUNS_ITS_LAMBDA_ONCE`: the `App` case above).
        Expr::Lam(pats, body, _) => {
            if binds_var(pats, x) {
                (0, 0)
            } else {
                let (c, b) = analyze(body, x, mode, ctx);
                (if c > 0 { c.max(2) } else { 0 }, b)
            }
        }
    }
}

/// Built-ins that call the lambda they are given exactly once, so it may give away what it
/// captured (`withBuffer n (\b -> …)`, a `spawn`ed task, a nursery body, an arena scope).
const RUNS_ITS_LAMBDA_ONCE: &[&str] = &[
    "withBuffer",
    "withArena",
    "withSubArena",
    "spawn",
    "bound",
    "imperative",
];

/// True if any of the patterns binds the name `x` (shadowing).
fn binds_var(pats: &[Pat], x: &str) -> bool {
    let mut s = HashSet::new();
    for p in pats {
        collect_pat_vars(p, &mut s);
    }
    s.contains(x)
}

fn analyze_assigns(
    assigns: &[(String, Expr)],
    x: &str,
    ctx: &Ctx,
    pick: fn(Uses, Uses) -> Uses,
) -> Uses {
    // a record constructor (like any constructor — see the `App`/`is_ctor` case)
    // takes OWNERSHIP of every field: the value is deep-dropped with the record, so
    // storing it CONSUMES it. Counting a `Many`-field store as a mere borrow let
    // `B { f = x }; B { f = x }` alias a heap `x` into two owned records → native
    // double-free.
    assigns
        .iter()
        .map(|(_, e)| analyze_with(e, x, Mode::Consume, ctx, pick))
        .fold((0, 0), add)
}

fn arg_mode(mult: Option<&Mult>) -> Mode {
    if mult == Some(&Mult::One) {
        Mode::Consume
    } else {
        Mode::Borrow
    }
}

fn head_mults(head: &Expr, ctx: &Ctx) -> Vec<Mult> {
    match head {
        Expr::Var(n, _) | Expr::Con(n, _) => ctx.consumers.get(n).cloned().unwrap_or_default(),
        _ => Vec::new(),
    }
}

/// Flattens the application spine: `f a b c` → (`f`, [a, b, c]).
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

/// Span of the last occurrence (largest offset) of `x` in the clause — the death point.
fn last_occurrence_clause(clause: &Clause, x: &str) -> Option<Span> {
    let mut best: Option<Span> = None;
    match &clause.body {
        Body::Plain(e) => collect_last(e, x, &mut best),
        Body::Guarded(arms) => {
            for (g, r) in arms {
                collect_last(g, x, &mut best);
                collect_last(r, x, &mut best);
            }
        }
    }
    for w in &clause.wher {
        for c in &w.clauses {
            if let Some(s) = last_occurrence_clause(c, x) {
                if best.is_none_or(|b| s.0 > b.0) {
                    best = Some(s);
                }
            }
        }
    }
    best
}

fn collect_last(e: &Expr, x: &str, best: &mut Option<Span>) {
    match e {
        Expr::Var(n, sp) => {
            if n == x && best.is_none_or(|b| sp.0 > b.0) {
                *best = Some(*sp);
            }
        }
        Expr::Int(_, _) | Expr::Float(_, _) | Expr::Str(_, _) | Expr::Con(_, _) => {}
        Expr::App(f, a, _) => {
            collect_last(f, x, best);
            collect_last(a, x, best);
        }
        Expr::BinOp(_, l, r, _) => {
            collect_last(l, x, best);
            collect_last(r, x, best);
        }
        Expr::If(c, t, el, _) => {
            collect_last(c, x, best);
            collect_last(t, x, best);
            collect_last(el, x, best);
        }
        Expr::Case(s, arms, _) => {
            collect_last(s, x, best);
            for (_, b) in arms {
                collect_last(b, x, best);
            }
        }
        Expr::Let(binds, body, _) => {
            for bnd in binds {
                for c in &bnd.clauses {
                    if let Some(s) = last_occurrence_clause(c, x) {
                        if best.is_none_or(|b| s.0 > b.0) {
                            *best = Some(s);
                        }
                    }
                }
            }
            collect_last(body, x, best);
        }
        Expr::Tuple(es, _) => es.iter().for_each(|e| collect_last(e, x, best)),
        Expr::RecordCon(_, assigns, _) => {
            assigns.iter().for_each(|(_, e)| collect_last(e, x, best));
        }
        Expr::RecordUpd(base, assigns, _) => {
            collect_last(base, x, best);
            assigns.iter().for_each(|(_, e)| collect_last(e, x, best));
        }
        Expr::Lam(pats, body, _) => {
            if !binds_var(pats, x) {
                collect_last(body, x, best);
            }
        }
    }
}

// --- ORDER check: use-after-move (AX0004) ---
//
// Walks the body in evaluation order (left→right) tracking whether ownership
// of `x` has been moved (consumed). Any occurrence of `x` after that — reading
// or consuming — is use-after-move. Branches (`if`/`case`) are paths: each starts
// do mesmo estado e o resultado junta-se (movido se algum ramo mover).

#[derive(Clone, Copy, Default)]
struct MoveState {
    moved: Option<Span>,         // where ownership was moved (if it was)
    error: Option<(Span, Span)>, // (onde moveu, onde foi usado depois) — o 1.º
}

/// Returns `(move span, later use span)` if there is a use-after-move.
fn use_after_move(clause: &Clause, x: &str, ctx: &Ctx) -> Option<(Span, Span)> {
    let st = match &clause.body {
        Body::Plain(e) => walk(e, x, Mode::Consume, ctx, MoveState::default()),
        // guards are exclusive paths: each starts from the initial state
        Body::Guarded(arms) => arms
            .iter()
            .map(|(g, r)| {
                let s = walk(g, x, Mode::Borrow, ctx, MoveState::default());
                walk(r, x, Mode::Consume, ctx, s)
            })
            .find(|s| s.error.is_some())
            .unwrap_or_default(),
    };
    st.error
}

fn walk(e: &Expr, x: &str, mode: Mode, ctx: &Ctx, mut st: MoveState) -> MoveState {
    match e {
        Expr::Var(n, sp) => {
            if n == x {
                if let Some(mv) = st.moved {
                    if st.error.is_none() {
                        st.error = Some((mv, *sp)); // usado depois de movido
                    }
                } else if mode == Mode::Consume {
                    st.moved = Some(*sp);
                }
            }
            st
        }
        Expr::Int(_, _) | Expr::Float(_, _) | Expr::Str(_, _) | Expr::Con(_, _) => st,
        Expr::BinOp(_, l, r, _) => {
            st = walk(l, x, Mode::Borrow, ctx, st);
            walk(r, x, Mode::Borrow, ctx, st)
        }
        Expr::App(_, _, _) => {
            let (head, args) = spine(e);
            let mults = head_mults(head, ctx);
            st = walk(head, x, Mode::Borrow, ctx, st);
            // Every argument is evaluated before the call, and `x` given BARE to a consuming
            // position moves only at the call itself: `unifyR sub (resolve sub a)` reads `sub` in
            // the inner call first. So such a hand-over is walked after the other arguments.
            // Not when an argument holds a lambda: a closure capturing `x` may run after the
            // callee has taken (and freed) it.
            let handed = |i: usize, a: &Expr| {
                arg_mode(mults.get(i)) == Mode::Consume && matches!(a, Expr::Var(v, _) if v == x)
            };
            let reorder = !args.iter().any(|a| contains_lambda(a));
            for (i, a) in args.iter().enumerate() {
                if !(reorder && handed(i, a)) {
                    st = walk(a, x, arg_mode(mults.get(i)), ctx, st);
                }
            }
            if reorder {
                for (i, a) in args.iter().enumerate() {
                    if handed(i, a) {
                        st = walk(a, x, Mode::Consume, ctx, st);
                    }
                }
            }
            st
        }
        Expr::If(c, t, el, _) => {
            st = walk(c, x, Mode::Borrow, ctx, st);
            join(walk(t, x, mode, ctx, st), walk(el, x, mode, ctx, st))
        }
        Expr::Case(s, arms, _) => {
            st = walk(s, x, Mode::Borrow, ctx, st);
            arms.iter()
                .map(|(_, b)| walk(b, x, mode, ctx, st))
                .reduce(join)
                .unwrap_or(st)
        }
        Expr::Let(binds, body, _) => {
            for c in binds.iter().flat_map(|b| &b.clauses) {
                if let Some((mv, u)) = use_after_move(c, x, ctx) {
                    if st.error.is_none() {
                        st.error = Some((mv, u));
                    }
                }
                // a bind that consumes x leaves ownership moved in the body
                if analyze_clause(c, x, ctx).0 > 0 {
                    st.moved = st.moved.or(Some(c.span));
                }
            }
            walk(body, x, mode, ctx, st)
        }
        Expr::Tuple(es, _) => {
            for e in es {
                st = walk(e, x, mode, ctx, st);
            }
            st
        }
        Expr::RecordCon(_, assigns, _) => walk_assigns(assigns, x, ctx, st),
        Expr::RecordUpd(base, assigns, _) => {
            st = walk(base, x, Mode::Consume, ctx, st);
            walk_assigns(assigns, x, ctx, st)
        }
        Expr::Lam(pats, body, _) => {
            if binds_var(pats, x) {
                st
            } else {
                walk(body, x, mode, ctx, st)
            }
        }
    }
}

/// `true` if `e` contains a lambda anywhere.
fn contains_lambda(e: &Expr) -> bool {
    match e {
        Expr::Lam(..) => true,
        Expr::App(a, b, _) | Expr::BinOp(_, a, b, _) => contains_lambda(a) || contains_lambda(b),
        Expr::If(c, t, el, _) => contains_lambda(c) || contains_lambda(t) || contains_lambda(el),
        Expr::Case(sc, arms, _) => {
            contains_lambda(sc) || arms.iter().any(|(_, b)| contains_lambda(b))
        }
        Expr::Let(binds, body, _) => {
            contains_lambda(body)
                || binds
                    .iter()
                    .flat_map(|b| &b.clauses)
                    .any(|c| match &c.body {
                        Body::Plain(x) => contains_lambda(x),
                        Body::Guarded(arms) => arms
                            .iter()
                            .any(|(g, r)| contains_lambda(g) || contains_lambda(r)),
                    })
        }
        Expr::Tuple(es, _) => es.iter().any(contains_lambda),
        Expr::RecordCon(_, fs, _) => fs.iter().any(|(_, x)| contains_lambda(x)),
        Expr::RecordUpd(b, fs, _) => {
            contains_lambda(b) || fs.iter().any(|(_, x)| contains_lambda(x))
        }
        Expr::Var(..) | Expr::Int(..) | Expr::Float(..) | Expr::Str(..) | Expr::Con(..) => false,
    }
}

fn walk_assigns(assigns: &[(String, Expr)], x: &str, ctx: &Ctx, mut st: MoveState) -> MoveState {
    for (fname, e) in assigns {
        st = walk(e, x, arg_mode(ctx.field_mults.get(fname)), ctx, st);
    }
    st
}

/// Joins two alternative paths (branches): moved if either moves; 1st error.
fn join(a: MoveState, b: MoveState) -> MoveState {
    MoveState {
        moved: a.moved.or(b.moved),
        error: a.error.or(b.error),
    }
}

// --- linear 'let' values + in-place mutation (§2) ---

/// The "class" of a linear resource: whether it is must-use and its type name.
#[derive(Clone)]
struct Lin {
    must_use: bool,
    /// no destructor at all: must be consumed on EVERY path (a `Buffer` is must-use but auto-dropped)
    no_drop: bool,
    ty: String,
}

fn class_of_type(ty: &Type, ctx: &Ctx) -> Lin {
    Lin {
        must_use: is_must_use(ty, &ctx.must_use_types),
        no_drop: is_no_drop(ty, &ctx.no_drop_types),
        ty: ty.head_con().unwrap_or("?").to_string(),
    }
}

/// The RHS of a simple `let v = <e>` (a bind without parameters or guards).
fn simple_bind_rhs(f: &Func) -> Option<&Expr> {
    match f.clauses.as_slice() {
        [c] if c.pats.is_empty() => match &c.body {
            Body::Plain(e) => Some(e),
            _ => None,
        },
        _ => None,
    }
}

/// The number of arguments a signature takes (its top-level arrows).
fn sig_arity(t: &Type) -> usize {
    match t {
        Type::Arrow { to, .. } => 1 + sig_arity(to),
        _ => 0,
    }
}

/// Is `e` certainly a plain scalar — arithmetic/comparison, or a saturated call of a function
/// whose declared result is one (`fn_ret_scalar`)?
fn scalar_valued(e: &Expr, ctx: &Ctx) -> bool {
    match e {
        Expr::Int(..) | Expr::Float(..) => true,
        Expr::BinOp(op, _, _, _) => matches!(
            op.as_str(),
            "+" | "-"
                | "*"
                | "/"
                | "div"
                | "mod"
                | "+."
                | "-."
                | "*."
                | "/."
                | "=="
                | "/="
                | "<"
                | ">"
                | "<="
                | ">="
                | "&&"
                | "||"
                | ".&."
                | ".|."
                | "xor"
                | "shiftL"
                | "shiftR"
        ),
        _ => match spine(e) {
            (Expr::Var(f, _), args) => {
                ctx.fn_ret_scalar.contains(f)
                    && ctx
                        .fn_sigs
                        .get(f)
                        .is_none_or(|s| sig_arity(s) == args.len())
            }
            _ => false,
        },
    }
}

/// Walks the body collecting (1) the `let`s that take ownership of a linear
/// linear — which become linear resources in their scope — and (2) the sites
/// of in-place update (RecordUpd whose base is a live linear resource).
fn scan_lets<'a>(
    e: &'a Expr,
    lin: &HashMap<String, Lin>,
    ctx: &Ctx,
    lets: &mut Vec<(String, Lin, &'a Expr, Span)>,
    inplace: &mut Vec<InPlace>,
    func: &str,
) {
    match e {
        Expr::Let(binds, body, _) => {
            let mut cur = lin.clone();
            for b in binds {
                if let Some(rhs) = simple_bind_rhs(b) {
                    scan_lets(rhs, &cur, ctx, lets, inplace, func);
                    // a bind whose RHS consumes a linear resource inherits ownership
                    // …unless the value is a plain scalar, which cannot carry the resource on (the
                    // callee consumed it: `let c = pclose h + 1`)
                    let consumed = cur
                        .keys()
                        .find(|w| analyze(rhs, w, Mode::Consume, ctx).0 > 0)
                        .filter(|_| !scalar_valued(rhs, ctx))
                        .cloned();
                    if let Some(w) = consumed {
                        let class = cur[&w].clone();
                        lets.push((b.name.clone(), class.clone(), body, b.span));
                        cur.insert(b.name.clone(), class);
                    } else if let (Expr::Var(f, _), _) = spine(rhs) {
                        // a fresh must-use value (`let h = openDev 7`): track it from its binding
                        if let Some(ty) = ctx.fn_ret_must_use.get(f) {
                            let class = Lin {
                                must_use: true,
                                no_drop: true,
                                ty: ty.clone(),
                            };
                            lets.push((b.name.clone(), class.clone(), body, b.span));
                            cur.insert(b.name.clone(), class);
                        }
                    }
                } else {
                    for c in &b.clauses {
                        if let Body::Plain(e2) = &c.body {
                            scan_lets(e2, &cur, ctx, lets, inplace, func);
                        }
                    }
                }
            }
            scan_lets(body, &cur, ctx, lets, inplace, func);
        }
        Expr::RecordUpd(base, assigns, span) => {
            if let Expr::Var(name, _) = base.as_ref() {
                if lin.contains_key(name) {
                    inplace.push(InPlace {
                        func: func.to_string(),
                        var: name.clone(),
                        span: *span,
                    });
                }
            }
            scan_lets(base, lin, ctx, lets, inplace, func);
            for (_, a) in assigns {
                scan_lets(a, lin, ctx, lets, inplace, func);
            }
        }
        Expr::App(f, a, _) => {
            scan_lets(f, lin, ctx, lets, inplace, func);
            scan_lets(a, lin, ctx, lets, inplace, func);
        }
        Expr::BinOp(_, l, r, _) => {
            scan_lets(l, lin, ctx, lets, inplace, func);
            scan_lets(r, lin, ctx, lets, inplace, func);
        }
        Expr::If(c, t, el, _) => {
            scan_lets(c, lin, ctx, lets, inplace, func);
            scan_lets(t, lin, ctx, lets, inplace, func);
            scan_lets(el, lin, ctx, lets, inplace, func);
        }
        Expr::Case(s, arms, _) => {
            scan_lets(s, lin, ctx, lets, inplace, func);
            // `x <- f a` in a `do` block is `case f a of x -> rest`: a fresh must-use value
            // bound (or discarded by `_`) there is tracked from its binding, like a `let`.
            let mut cur = lin.clone();
            if let ([(pat, rest)], (Expr::Var(f, _), _)) = (arms.as_slice(), spine(s)) {
                if let Some(ty) = ctx.fn_ret_must_use.get(f) {
                    let class = Lin {
                        must_use: true,
                        no_drop: true,
                        ty: ty.clone(),
                    };
                    match pat {
                        Pat::Var(x, sp) => {
                            lets.push((x.clone(), class.clone(), rest, *sp));
                            cur.insert(x.clone(), class);
                        }
                        // a name no expression can mention: it is never consumed → AX0002
                        Pat::Wild(sp) => lets.push((format!("result of {f}"), class, rest, *sp)),
                        _ => {}
                    }
                }
            }
            for (_, b) in arms {
                scan_lets(b, &cur, ctx, lets, inplace, func);
            }
        }
        Expr::Tuple(es, _) => es
            .iter()
            .for_each(|e| scan_lets(e, lin, ctx, lets, inplace, func)),
        Expr::RecordCon(_, assigns, _) => {
            for (_, a) in assigns {
                scan_lets(a, lin, ctx, lets, inplace, func);
            }
        }
        Expr::Lam(_, body, _) => scan_lets(body, lin, ctx, lets, inplace, func),
        Expr::Var(_, _)
        | Expr::Int(_, _)
        | Expr::Float(_, _)
        | Expr::Str(_, _)
        | Expr::Con(_, _) => {}
    }
}

// --- sub-arena escape analysis (AX0003, §3) ---
//
// A value allocated in a sub-arena (`allocateCell sub …`) cannot escape the
// scope of `withSubArena sub … -> body` (by being returned). The escape is a
// compile error; `promote parent v` rebinds the value to the parent arena and saves it.
// Region provenance tracking, analogous to the move analysis.

/// Recognizes `withSubArena <parent> (\sub -> body)` and returns `(sub, body)`.
fn as_with_sub_arena(e: &Expr) -> Option<(&str, &Expr)> {
    let (head, args) = spine(e);
    let is_wsa = matches!(head, Expr::Var(n, _) if n == "withSubArena");
    if is_wsa && args.len() >= 2 {
        if let Expr::Lam(pats, body, _) = args[1] {
            if let [Pat::Var(sub, _)] = pats.as_slice() {
                return Some((sub, body));
            }
        }
    }
    None
}

/// Recursively looks for `withSubArena` forms and checks the escape in each one.
fn check_arena_escapes(
    e: &Expr,
    func: &str,
    diags: &mut Diagnostics,
    arenas: &mut Vec<ArenaReset>,
) {
    if let Some((sub, body)) = as_with_sub_arena(e) {
        check_sub_scope(body, sub, func, diags, arenas);
    }
    let mut go = |e: &Expr| check_arena_escapes(e, func, diags, arenas);
    match e {
        Expr::App(f, a, _) => {
            go(f);
            go(a);
        }
        Expr::BinOp(_, l, r, _) => {
            go(l);
            go(r);
        }
        Expr::If(c, t, el, _) => {
            go(c);
            go(t);
            go(el);
        }
        Expr::Let(binds, body, _) => {
            for c in binds.iter().flat_map(|b| &b.clauses) {
                if let Body::Plain(e2) = &c.body {
                    go(e2);
                }
            }
            go(body);
        }
        Expr::Case(s, arms, _) => {
            go(s);
            for (_, b) in arms {
                go(b);
            }
        }
        Expr::Tuple(es, _) => es.iter().for_each(&mut go),
        Expr::RecordCon(_, assigns, _) | Expr::RecordUpd(_, assigns, _) => {
            assigns.iter().for_each(|(_, e)| go(e));
        }
        Expr::Lam(_, body, _) => go(body),
        Expr::Var(_, _)
        | Expr::Int(_, _)
        | Expr::Float(_, _)
        | Expr::Str(_, _)
        | Expr::Con(_, _) => {}
    }
}

/// Checks a `withSubArena` body: (1) no value bound to the sub-arena may
/// escapar (por retorno ou captura) — `AX0003`; (2) computa o reset NLL (§3): o
/// death point of the region is the last live mention of a sub-arena value.
fn check_sub_scope(
    body: &Expr,
    sub: &str,
    func: &str,
    diags: &mut Diagnostics,
    arenas: &mut Vec<ArenaReset>,
) {
    let mut sub_bound: HashMap<String, Span> = HashMap::new();
    let tail = peel_arena_lets(body, sub, &mut sub_bound);

    // (1) escape
    if let Some(origin) = region_of(tail, sub, &sub_bound) {
        let esc = tail.span();
        diags.push(
            Diagnostic::error("AX0003", "a value escapes its sub-arena")
                .label(
                    esc.0,
                    esc.1,
                    "returned from here — it would outlive the sub-arena reset",
                )
                .label(origin.0, origin.1, format!("lives in sub-arena '{sub}'"))
                .with_help(
                    "on reset the sub-arena's RAM is reclaimed; move the value to the \
                     parent arena before the reset with 'promote parent value' (§3).",
                ),
        );
        return; // with an escape, the reset is irrelevant
    }

    // (2) NLL reset: the last live mention of any sub-arena value
    let mut reset: Option<(Span, &String)> = None;
    for var in sub_bound.keys() {
        let mut last = None;
        collect_last(body, var, &mut last);
        if let Some(sp) = last {
            if reset.is_none_or(|(r, _)| sp.0 > r.0) {
                reset = Some((sp, var));
            }
        }
    }
    if let Some((span, var)) = reset {
        arenas.push(ArenaReset {
            func: func.to_string(),
            sub: sub.to_string(),
            span,
            last_var: var.clone(),
        });
    }
}

/// Walks the `let` chain, recording the names bound to the sub-arena, and
/// returns the tail expression (the return value).
fn peel_arena_lets<'a>(e: &'a Expr, sub: &str, sub_bound: &mut HashMap<String, Span>) -> &'a Expr {
    let mut cur = e;
    while let Expr::Let(binds, body, _) = cur {
        for b in binds {
            if let Some(rhs) = simple_bind_rhs(b) {
                if let Some(sp) = region_of(rhs, sub, sub_bound) {
                    sub_bound.insert(b.name.clone(), sp);
                }
            }
        }
        cur = body;
    }
    cur
}

/// If `e` produces a value bound to the sub-arena `sub`, returns the span of its
/// origin (the allocation). `promote` rebinds to the parent arena, cutting the provenance.
fn region_of(e: &Expr, sub: &str, sub_bound: &HashMap<String, Span>) -> Option<Span> {
    match e {
        Expr::Var(n, _) => sub_bound.get(n).copied(),
        Expr::App(_, _, _) => {
            let (head, args) = spine(e);
            match head {
                Expr::Var(n, _) if n == "allocateCell" => {
                    // allocateCell sub … → vive na sub-arena
                    if matches!(args.first(), Some(Expr::Var(a, _)) if a == sub) {
                        Some(e.span())
                    } else {
                        None
                    }
                }
                // promote cuts the provenance: the result lives in the parent arena
                Expr::Var(n, _) if n == "promote" => None,
                // another function: conservative — it may return a sub-arena value
                _ => args.iter().find_map(|a| region_of(a, sub, sub_bound)),
            }
        }
        Expr::Tuple(es, _) => es.iter().find_map(|e| region_of(e, sub, sub_bound)),
        Expr::RecordCon(_, assigns, _) | Expr::RecordUpd(_, assigns, _) => assigns
            .iter()
            .find_map(|(_, e)| region_of(e, sub, sub_bound)),
        // a closure that captures a sub-arena value carries it outward
        // (§3C: the escape can be by return OR by capture in a closure).
        Expr::Lam(pats, body, _) => {
            let mut shadowed = HashSet::new();
            for p in pats {
                collect_pat_vars(p, &mut shadowed);
            }
            captured_sub_ref(body, sub_bound, &mut shadowed)
        }
        _ => None,
    }
}

/// Looks for a **free** reference to a sub-arena-bound value inside `e`
/// (used to detect closure capture). Returns the allocation span.
fn captured_sub_ref(
    e: &Expr,
    sub_bound: &HashMap<String, Span>,
    shadowed: &mut HashSet<String>,
) -> Option<Span> {
    match e {
        Expr::Var(n, _) => {
            if shadowed.contains(n) {
                None
            } else {
                sub_bound.get(n).copied()
            }
        }
        Expr::App(f, a, _) => captured_sub_ref(f, sub_bound, shadowed)
            .or_else(|| captured_sub_ref(a, sub_bound, shadowed)),
        Expr::BinOp(_, l, r, _) => captured_sub_ref(l, sub_bound, shadowed)
            .or_else(|| captured_sub_ref(r, sub_bound, shadowed)),
        Expr::If(c, t, el, _) => captured_sub_ref(c, sub_bound, shadowed)
            .or_else(|| captured_sub_ref(t, sub_bound, shadowed))
            .or_else(|| captured_sub_ref(el, sub_bound, shadowed)),
        Expr::Tuple(es, _) => es
            .iter()
            .find_map(|e| captured_sub_ref(e, sub_bound, shadowed)),
        Expr::RecordCon(_, assigns, _) | Expr::RecordUpd(_, assigns, _) => assigns
            .iter()
            .find_map(|(_, e)| captured_sub_ref(e, sub_bound, shadowed)),
        Expr::Case(s, arms, _) => captured_sub_ref(s, sub_bound, shadowed).or_else(|| {
            arms.iter()
                .find_map(|(_, b)| captured_sub_ref(b, sub_bound, shadowed))
        }),
        Expr::Let(binds, body, _) => binds
            .iter()
            .flat_map(|b| &b.clauses)
            .find_map(|c| match &c.body {
                Body::Plain(e2) => captured_sub_ref(e2, sub_bound, shadowed),
                _ => None,
            })
            .or_else(|| captured_sub_ref(body, sub_bound, shadowed)),
        Expr::Lam(pats, body, _) => {
            for p in pats {
                collect_pat_vars(p, shadowed);
            }
            captured_sub_ref(body, sub_bound, shadowed)
        }
        Expr::Int(_, _) | Expr::Float(_, _) | Expr::Str(_, _) | Expr::Con(_, _) => None,
    }
}

// --- arena marks: intra-scope reclamation (AX0005, Listing 3.6, §3) ---
//
// `mark = arena_mark arena` guarda o topo do bump-pointer; `arena_release mark`
// rolls it back, reclaiming everything allocated after the mark. Hence, a value
// allocated after the mark cannot be used AFTER the release — its memory has
// already been reclaimed. Ordered analysis over the `let` spine.

struct Mark {
    name: String,
    arena: String,
    released: Option<Span>,
}

struct BoundCell {
    mark: String,
    alloc: Span,
}

/// Classifies the RHS of a `let` as an arena-mark operation.
enum MarkOp<'a> {
    OpenMark { arena: &'a str }, // arena_mark arena
    Alloc { arena: &'a str },    // allocateCell arena
    Release { mark: &'a str },   // arena_release mark
    Other,
}

fn classify_mark_op(e: &Expr) -> MarkOp<'_> {
    let (head, args) = spine(e);
    let first = args.first();
    match head {
        Expr::Var(n, _) if n == "arena_mark" => match first {
            Some(Expr::Var(a, _)) => MarkOp::OpenMark { arena: a },
            _ => MarkOp::Other,
        },
        Expr::Var(n, _) if n == "allocateCell" => match first {
            Some(Expr::Var(a, _)) => MarkOp::Alloc { arena: a },
            _ => MarkOp::Other,
        },
        Expr::Var(n, _) if n == "arena_release" => match first {
            Some(Expr::Var(m, _)) => MarkOp::Release { mark: m },
            _ => MarkOp::Other,
        },
        _ => MarkOp::Other,
    }
}

/// Checks the arena-mark discipline in a function body.
fn check_arena_marks(e: &Expr, diags: &mut Diagnostics) {
    let mut marks: Vec<Mark> = Vec::new();
    let mut bound: HashMap<String, BoundCell> = HashMap::new();
    let mut cur = e;
    loop {
        match cur {
            Expr::Let(binds, body, _) => {
                for b in binds {
                    match simple_bind_rhs(b) {
                        Some(rhs) => {
                            check_released_uses(rhs, &bound, &marks, diags);
                            apply_mark_op(&b.name, rhs, &mut marks, &mut bound);
                            check_nested_marks(rhs, diags);
                        }
                        None => {
                            for c in &b.clauses {
                                if let Body::Plain(e2) = &c.body {
                                    check_arena_marks(e2, diags);
                                }
                            }
                        }
                    }
                }
                cur = body;
            }
            other => {
                check_released_uses(other, &bound, &marks, diags);
                check_nested_marks(other, diags);
                break;
            }
        }
    }
}

fn apply_mark_op(
    name: &str,
    rhs: &Expr,
    marks: &mut Vec<Mark>,
    bound: &mut HashMap<String, BoundCell>,
) {
    match classify_mark_op(rhs) {
        MarkOp::OpenMark { arena } => marks.push(Mark {
            name: name.to_string(),
            arena: arena.to_string(),
            released: None,
        }),
        MarkOp::Alloc { arena } => {
            // binds to the most recent open mark of the same arena
            if let Some(m) = marks
                .iter()
                .rev()
                .find(|m| m.arena == arena && m.released.is_none())
            {
                bound.insert(
                    name.to_string(),
                    BoundCell {
                        mark: m.name.clone(),
                        alloc: rhs.span(),
                    },
                );
            }
        }
        MarkOp::Release { mark } => {
            if let Some(m) = marks.iter_mut().find(|m| m.name == mark) {
                m.released = Some(rhs.span());
            }
        }
        MarkOp::Other => {}
    }
}

/// Reports uses of values whose mark has already been released (AX0005).
fn check_released_uses(
    e: &Expr,
    bound: &HashMap<String, BoundCell>,
    marks: &[Mark],
    diags: &mut Diagnostics,
) {
    let released_span = |mark: &str| {
        marks
            .iter()
            .find(|m| m.name == mark)
            .and_then(|m| m.released)
    };
    let mut check = |n: &str, sp: Span| {
        if let Some(bc) = bound.get(n) {
            if let Some(rel) = released_span(&bc.mark) {
                diags.push(
                    Diagnostic::error(
                        "AX0005",
                        format!("'{n}' used after 'arena_release' (memory already reclaimed)"),
                    )
                    .label(sp.0, sp.1, format!("'{n}' used here…"))
                    .label(rel.0, rel.1, "…but arena_release reclaimed the memory here")
                    .label(
                        bc.alloc.0,
                        bc.alloc.1,
                        format!("'{n}' was allocated after the mark here"),
                    )
                    .with_help(
                        "everything allocated after a mark is reclaimed on \
                         arena_release; consume it before, or promote it past the mark (§3).",
                    ),
                );
            }
        }
    };
    collect_var_refs(e, &mut check);
}

/// Applies `f` to each variable occurrence in `e`.
fn collect_var_refs(e: &Expr, f: &mut dyn FnMut(&str, Span)) {
    match e {
        Expr::Var(n, sp) => f(n, *sp),
        Expr::Int(_, _) | Expr::Float(_, _) | Expr::Str(_, _) | Expr::Con(_, _) => {}
        Expr::App(a, b, _) | Expr::BinOp(_, a, b, _) => {
            collect_var_refs(a, f);
            collect_var_refs(b, f);
        }
        Expr::If(c, t, el, _) => {
            collect_var_refs(c, f);
            collect_var_refs(t, f);
            collect_var_refs(el, f);
        }
        Expr::Tuple(es, _) => es.iter().for_each(|e| collect_var_refs(e, f)),
        Expr::RecordCon(_, assigns, _) | Expr::RecordUpd(_, assigns, _) => {
            assigns.iter().for_each(|(_, e)| collect_var_refs(e, f));
        }
        Expr::Case(s, arms, _) => {
            collect_var_refs(s, f);
            arms.iter().for_each(|(_, b)| collect_var_refs(b, f));
        }
        Expr::Let(binds, body, _) => {
            binds.iter().flat_map(|b| &b.clauses).for_each(|c| {
                if let Body::Plain(e2) = &c.body {
                    collect_var_refs(e2, f);
                }
            });
            collect_var_refs(body, f);
        }
        Expr::Lam(_, body, _) => collect_var_refs(body, f),
    }
}

/// Recurses into sub-expressions (not the current spine) looking for nested mark
/// scopes, running a fresh analysis in each.
fn check_nested_marks(e: &Expr, diags: &mut Diagnostics) {
    match e {
        Expr::App(a, b, _) | Expr::BinOp(_, a, b, _) => {
            check_arena_marks(a, diags);
            check_arena_marks(b, diags);
        }
        Expr::If(c, t, el, _) => {
            check_arena_marks(c, diags);
            check_arena_marks(t, diags);
            check_arena_marks(el, diags);
        }
        Expr::Tuple(es, _) => es.iter().for_each(|e| check_arena_marks(e, diags)),
        Expr::RecordCon(_, assigns, _) | Expr::RecordUpd(_, assigns, _) => assigns
            .iter()
            .for_each(|(_, e)| check_arena_marks(e, diags)),
        Expr::Case(s, arms, _) => {
            check_arena_marks(s, diags);
            arms.iter().for_each(|(_, b)| check_arena_marks(b, diags));
        }
        Expr::Lam(_, body, _) => check_arena_marks(body, diags),
        // Let is the spine, already handled by check_arena_marks; leaves: nothing
        Expr::Let(_, _, _)
        | Expr::Var(_, _)
        | Expr::Int(_, _)
        | Expr::Float(_, _)
        | Expr::Str(_, _)
        | Expr::Con(_, _) => {}
    }
}

// --- fractional permissions %0.5: split/join (AX0006, §2, Listing 2.3) ---
//
// `split cfg` divides a %1 into two %0.5 SHARED-READ halves; `join a b`
// recombines them into %1. A %0.5 half can be read (borrowed) freely and
// recombined by `join`, but NEVER written: using it in a write position
// (argument of a function's %1 parameter, or base of a record
// update, or %1 field) is AX0006.

fn is_var(e: &Expr, name: &str) -> bool {
    matches!(e, Expr::Var(n, _) if n == name)
}

/// True if `e` is a call to `split` (the origin of the %0.5 halves).
fn is_split_call(e: &Expr) -> bool {
    matches!(spine(e).0, Expr::Var(n, _) if n == "split")
}

/// Looks for `case (split …) of (a, b) -> arm` and checks that the halves `a`/`b`
/// are not written in the arm.
fn check_fractional(e: &Expr, ctx: &Ctx, diags: &mut Diagnostics) {
    if let Expr::Case(scrut, arms, _) = e {
        if is_split_call(scrut) {
            for (pat, body) in arms {
                if let Pat::Tuple(ps, _) = pat {
                    for p in ps {
                        if let Pat::Var(half, _) = p {
                            check_half_writes(body, half, ctx, diags);
                        }
                    }
                }
            }
        }
    }
    // recurses into sub-expressions (nested cases)
    for_each_child(e, &mut |c| check_fractional(c, ctx, diags));
}

/// Emits the AX0006 for a write through a %0.5 half.
fn push_write(diags: &mut Diagnostics, half: &str, sp: Span, what: &str) {
    diags.push(
        Diagnostic::error("AX0006", format!("write through the %0.5 half '{half}'"))
            .label(
                sp.0,
                sp.1,
                format!("'{half}' is %0.5 (shared read): {what}"),
            )
            .with_help(
                "a %0.5 half grants read only; to recover write access, recombine \
                 the two halves with 'join a b' (which returns the %1) (§2).",
            ),
    );
}

/// Reports writes through the %0.5 half `half` in `e` (AX0006).
fn check_half_writes(e: &Expr, half: &str, ctx: &Ctx, diags: &mut Diagnostics) {
    match e {
        Expr::App(_, _, _) => {
            let (head, args) = spine(e);
            let mults = head_mults(head, ctx);
            for (i, a) in args.iter().enumerate() {
                if is_var(a, half) && mults.get(i) == Some(&Mult::One) {
                    push_write(diags, half, a.span(), "passed to a %1 parameter (write)");
                }
                check_half_writes(a, half, ctx, diags);
            }
            check_half_writes(head, half, ctx, diags);
        }
        Expr::RecordUpd(base, assigns, _) => {
            if is_var(base, half) {
                push_write(diags, half, base.span(), "base of a record update (write)");
            } else {
                check_half_writes(base, half, ctx, diags);
            }
            check_half_assigns(assigns, half, ctx, diags);
        }
        Expr::RecordCon(_, assigns, _) => check_half_assigns(assigns, half, ctx, diags),
        _ => for_each_child(e, &mut |c| check_half_writes(c, half, ctx, diags)),
    }
}

fn check_half_assigns(assigns: &[(String, Expr)], half: &str, ctx: &Ctx, diags: &mut Diagnostics) {
    for (fname, val) in assigns {
        if is_var(val, half) && ctx.field_mults.get(fname) == Some(&Mult::One) {
            push_write(diags, half, val.span(), "placed in a %1 field (write)");
        } else {
            check_half_writes(val, half, ctx, diags);
        }
    }
}

/// Applies `f` to each direct sub-expression of `e`.
fn for_each_child(e: &Expr, f: &mut dyn FnMut(&Expr)) {
    match e {
        Expr::App(a, b, _) | Expr::BinOp(_, a, b, _) => {
            f(a);
            f(b);
        }
        Expr::If(c, t, el, _) => {
            f(c);
            f(t);
            f(el);
        }
        Expr::Let(binds, body, _) => {
            binds.iter().flat_map(|b| &b.clauses).for_each(|c| {
                if let Body::Plain(e2) = &c.body {
                    f(e2);
                }
            });
            f(body);
        }
        Expr::Case(s, arms, _) => {
            f(s);
            arms.iter().for_each(|(_, b)| f(b));
        }
        Expr::Tuple(es, _) => es.iter().for_each(&mut *f),
        Expr::RecordCon(_, assigns, _) | Expr::RecordUpd(_, assigns, _) => {
            assigns.iter().for_each(|(_, e)| f(e));
        }
        Expr::Lam(_, body, _) => f(body),
        Expr::Var(_, _)
        | Expr::Int(_, _)
        | Expr::Float(_, _)
        | Expr::Str(_, _)
        | Expr::Con(_, _) => {}
    }
}
