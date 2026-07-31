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
//! Alternative branches (`if`, `case`) count as paths (maximum, not sum).
//!
//! ORDER is also checked: a traversal in evaluation order detects the
//! use of a `%1` **after** ownership has been moved (use-after-move ⇒
//! `AX0004`). `x + sink x` (read before consuming) is accepted; `sink x + x` is not.
//!
//! Regions (§3): the sub-arena escape analysis (`AX0003`) follows the
//! provenance of the values of `withSubArena parent (\sub -> …)` — an
//! `allocateCell sub` value that is returned escapes, unless `promote parent`
//! moves it to the parent arena.

use crate::ast::*;
use crate::diag::{Diagnostic, Diagnostics};
use std::collections::{HashMap, HashSet};

/// Primitive types **without `Drop`** (must-use): forgetting them is an error, not Auto-Drop.
/// `Drop` propagates structurally: a record is must-use if any field is.
/// Everything else is droppable by default (§2).
const MUST_USE_PRIMS: &[&str] = &["Ep", "Token", "Endpoint", "Transaction", "Buffer"];

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
#[derive(Default)]
pub struct Analysis {
    pub drops: Vec<DropPoint>,
    pub inplace: Vec<InPlace>,
    pub arenas: Vec<ArenaReset>,
}

/// Runs the checks and returns the Auto-Drop `free`s and the in-place sites.
pub fn check(module: &Module, diags: &mut Diagnostics) -> Analysis {
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
    let ctx = build_ctx(module);
    let mut out = Analysis::default();
    for f in &module.funcs {
        check_func(f, &globals, &ctx, diags, &mut out);
    }
    check_sessions(module, diags);
    check_bound_escapes(module, diags);
    check_instances(module, diags);
    out
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
        Some("bound") if !args.is_empty() => Some(*args.last().unwrap()),
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
            assigns.iter().for_each(|(_, e)| go(e))
        }
        Expr::Lam(_, body, _) => go(body),
        Expr::Var(_, _) | Expr::Int(_, _) | Expr::Str(_, _) | Expr::Con(_, _) => {}
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
        Some("send") | Some("spawn") => Prod::One,
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
            Some("newChannel") | Some("spawn") | Some("send") | Some("recv") => Some(e.span()),
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
// v1: fragmento send/recv/close sobre a espinha linear de `do`/`let`; escolha
// (⊕/&), `bound`/`spawn` and branches (multi-arm `if`/`case`) are left for later
// increments (there the tracking stops, conservative, no false positives).

#[derive(Clone, Debug, PartialEq)]
enum SessTy {
    End,
    Send(Box<SessTy>),
    Recv(Box<SessTy>),
    Select(Vec<(String, SessTy)>), // ⊕ — chooses a label (internal side)
    Offer(Vec<(String, SessTy)>),  // & — offers all labels (external side)
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
                walk_sess(e, &mut env, &mut tracked, f.span, diags);
                // completude (T-progresso): se seguimos toda a espinha, nenhum
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
/// incompletude. `span` = o local a apontar nas incompletudes por-ramo.
fn walk_sess(
    e: &Expr,
    env: &mut HashMap<String, SessTy>,
    tracked: &mut bool,
    span: Span,
    diags: &mut Diagnostics,
) {
    // `case offer c of { L1 p1 -> N1 ; … }` (&): the external choice. Checks
    // exhaustiveness (all `Offer` branches handled) and follows each branch with
    // its continuation. It is the only multi-arm `case` that is tracked.
    if let Expr::Case(scrut, arms, _) = e {
        if let Some(chan) = offer_chan(scrut) {
            check_offer_case(&chan, arms, env, span, diags);
            return;
        }
    }
    match e {
        Expr::Case(scrut, arms, _) if arms.len() == 1 => {
            if let Some(r) = classify_op(scrut, env, diags) {
                bind_result(&arms[0].0, r, env);
            }
            walk_sess(&arms[0].1, env, tracked, span, diags);
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
            walk_sess(body, env, tracked, span, diags);
        }
        // real branching: not trackable in v1 → stop (conservative, no false+)
        Expr::If(..) | Expr::Case(..) => *tracked = false,
        // leaf: may be the last operation (`close c`)
        other => {
            classify_op(other, env, diags);
        }
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
    diags: &mut Diagnostics,
) {
    let branches = match env.remove(chan) {
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
        walk_sess(body, &mut arm_env, &mut t, span, diags);
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
        return match env.remove(&chan) {
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
    match head {
        "send" if args.len() >= 2 => match env.remove(&chan) {
            Some(SessTy::Send(s)) => Some(OpResult::Advance(*s)),
            Some(other) => {
                session_mismatch(diags, sp, &chan, "send", &other);
                None
            }
            None => None,
        },
        "recv" => match env.remove(&chan) {
            Some(SessTy::Recv(s)) => Some(OpResult::Recv(*s)),
            Some(other) => {
                session_mismatch(diags, sp, &chan, "recv", &other);
                None
            }
            None => None,
        },
        "close" => match env.remove(&chan) {
            Some(SessTy::End) => Some(OpResult::Closed),
            Some(other) => {
                session_mismatch(diags, sp, &chan, "close", &other);
                None
            }
            None => None,
        },
        // `offer c` (&): receives the choice and consumes the endpoint. The exhaustiveness of the
        // branches (incl. `Closed`) is checked in the type (`check_closed_branches`).
        "offer" => match env.remove(&chan) {
            Some(SessTy::Offer(_)) => Some(OpResult::Closed),
            Some(other) => {
                session_mismatch(diags, sp, &chan, "offer", &other);
                None
            }
            None => None,
        },
        // `cancel c` (§7): descarta o endpoint em QUALQUER estado (pode-se sempre
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
fn is_must_use(ty: &Type, must_use_types: &HashSet<String>) -> bool {
    matches!(ty.head_con(), Some(h) if MUST_USE_PRIMS.contains(&h) || must_use_types.contains(h))
}

/// Computes, by fixpoint, the set of `data` types that are *must-use*:
/// a `data` is must-use if some field of some constructor is must-use (a
/// primitive without `Drop`, or another already-marked `data`). `Drop` thus propagates
/// estruturalmente (§2).
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

fn builtins() -> HashSet<String> {
    [
        "putStrLn",
        "putStr",
        "show",
        "otherwise",
        "True",
        "False",
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
        "foldBytes",
        "imperative",
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
    ]
    .iter()
    .map(|s| s.to_string())
    .collect()
}

/// State of a linear resource after analyzing a clause/scope.
struct ResUse {
    consumes: usize,
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
                let class = class_of_type(ty, &ctx.must_use_types);
                let (c, b) = analyze_clause(clause, name, ctx);
                let use_ = ResUse {
                    consumes: c,
                    borrows: b,
                    uam: use_after_move(clause, name, ctx),
                    death: last_occurrence_clause(clause, name),
                };
                report_resource(name, &class, *span, &use_, &f.name, diags, out);
                lin.insert(name.clone(), class);
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
                    borrows: b,
                    uam: walk(sp_scope, &name, Mode::Consume, ctx, MoveState::default()).error,
                    death,
                };
                report_resource(&name, &class, bind_span, &use_, &f.name, diags, out);
            }
        }
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
        diags.push(
            Diagnostic::error(
                "AX0004",
                format!("use of '{name}' after ownership was moved"),
            )
            .label(use_sp.0, use_sp.1, format!("'{name}' used here…"))
            .label(mv.0, mv.1, "…but ownership had already been moved here")
            .with_help(
                "after moving a %1 (consuming), you cannot read or consume it \
                     again — ownership has left this scope (§2).",
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

fn collect_pat_vars(p: &Pat, out: &mut HashSet<String>) {
    match p {
        Pat::Var(n, _) => {
            out.insert(n.clone());
        }
        Pat::Con(_, args, _) | Pat::Tuple(args, _) => {
            for a in args {
                collect_pat_vars(a, out);
            }
        }
        Pat::Wild(_) | Pat::Int(_, _) => {}
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

fn resolve_expr(
    e: &Expr,
    scope: &HashSet<String>,
    globals: &HashSet<String>,
    diags: &mut Diagnostics,
) {
    match e {
        Expr::Var(n, sp) => {
            if !scope.contains(n) && !globals.contains(n) {
                diags.push(
                    Diagnostic::error("AX0101", format!("name not found: '{n}'"))
                        .label(sp.0, sp.1, "not in scope")
                        .with_help(
                            "check the spelling, or whether it is a parameter/local in \
                             scope, or a missing top-level function/import.",
                        ),
                );
            }
        }
        Expr::Int(_, _) | Expr::Str(_, _) | Expr::Con(_, _) => {}
        Expr::App(f, x, _) => {
            resolve_expr(f, scope, globals, diags);
            resolve_expr(x, scope, globals, diags);
        }
        Expr::BinOp(_, l, r, _) => {
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
struct Ctx {
    /// function/constructor → multiplicities of the parameters/fields (in order)
    consumers: HashMap<String, Vec<Mult>>,
    /// field name → declared multiplicity (for records)
    field_mults: HashMap<String, Mult>,
    /// must-use `data` types (because they recursively contain a field without `Drop`)
    must_use_types: HashSet<String>,
}

fn build_ctx(module: &Module) -> Ctx {
    let mut consumers = HashMap::new();
    let mut field_mults = HashMap::new();
    for f in &module.funcs {
        if let Some(sig) = &f.sig {
            consumers.insert(f.name.clone(), sig.param_mults());
        }
    }
    for d in &module.datas {
        for c in &d.cons {
            consumers.insert(c.name.clone(), c.fields.iter().map(|f| f.mult).collect());
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
    // Buffer U8 linear (§4/§5): as ops in-place (bufIota/xorInPlace) e o `free`
    // consume the %1 Buffer (xorInPlace returns a fresh %1 — the linear thread);
    // sumBytes/withBuffer only borrow.
    consumers.insert("bufIota".to_string(), vec![Mult::One]);
    consumers.insert("xorInPlace".to_string(), vec![Mult::One, Mult::Many]);
    consumers.insert("free".to_string(), vec![Mult::One]);
    consumers.insert("sumBytes".to_string(), vec![Mult::Many]);
    consumers.insert("newBuffer".to_string(), vec![Mult::Many]);
    consumers.insert("withBuffer".to_string(), vec![Mult::Many, Mult::Many]);
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
    // FFI imports: the arguments (Int) are borrowed.
    for fo in &module.foreigns {
        let arity = fo.sig.param_mults().len();
        consumers.insert(fo.name.clone(), vec![Mult::Many; arity]);
    }
    Ctx {
        consumers,
        field_mults,
        must_use_types: build_must_use_types(module),
    }
}

type Uses = (usize, usize); // (consumptions, borrows)

fn add(a: Uses, b: Uses) -> Uses {
    (a.0 + b.0, a.1 + b.1)
}

fn alt(a: Uses, b: Uses) -> Uses {
    (a.0.max(b.0), a.1.max(b.1))
}

fn analyze_clause(clause: &Clause, x: &str, ctx: &Ctx) -> Uses {
    // the clause's value is returned ⇒ consumption position
    let mut u = match &clause.body {
        Body::Plain(e) => analyze(e, x, Mode::Consume, ctx),
        Body::Guarded(arms) => arms
            .iter()
            .map(|(g, r)| {
                add(
                    analyze(g, x, Mode::Borrow, ctx),
                    analyze(r, x, Mode::Consume, ctx),
                )
            })
            .fold((0, 0), alt),
    };
    for w in &clause.wher {
        for c in &w.clauses {
            u = add(u, analyze_clause(c, x, ctx));
        }
    }
    u
}

fn analyze(e: &Expr, x: &str, mode: Mode, ctx: &Ctx) -> Uses {
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
        Expr::Int(_, _) | Expr::Str(_, _) | Expr::Con(_, _) => (0, 0),
        // arithmetic/comparison operands are read, not consumed
        Expr::BinOp(_, l, r, _) => add(
            analyze(l, x, Mode::Borrow, ctx),
            analyze(r, x, Mode::Borrow, ctx),
        ),
        Expr::App(_, _, _) => {
            let (head, args) = spine(e);
            let mults = head_mults(head, ctx);
            let mut u = analyze(head, x, Mode::Borrow, ctx);
            for (i, a) in args.iter().enumerate() {
                let m = arg_mode(mults.get(i));
                u = add(u, analyze(a, x, m, ctx));
            }
            u
        }
        // condition read; the branches are alternative paths, in the parent's mode
        Expr::If(c, t, el, _) => add(
            analyze(c, x, Mode::Borrow, ctx),
            alt(analyze(t, x, mode, ctx), analyze(el, x, mode, ctx)),
        ),
        Expr::Case(s, arms, _) => add(
            analyze(s, x, Mode::Borrow, ctx),
            arms.iter()
                .map(|(_, b)| analyze(b, x, mode, ctx))
                .fold((0, 0), alt),
        ),
        Expr::Let(binds, body, _) => {
            let in_binds = binds
                .iter()
                .flat_map(|b| &b.clauses)
                .map(|c| analyze_clause(c, x, ctx))
                .fold((0, 0), add);
            add(in_binds, analyze(body, x, mode, ctx))
        }
        // a returned tuple makes ownership of the components flow outward
        Expr::Tuple(es, _) => es
            .iter()
            .map(|e| analyze(e, x, mode, ctx))
            .fold((0, 0), add),
        Expr::RecordCon(_, assigns, _) => analyze_assigns(assigns, x, ctx),
        Expr::RecordUpd(base, assigns, _) => add(
            analyze(base, x, Mode::Consume, ctx), // the update takes ownership of the base
            analyze_assigns(assigns, x, ctx),
        ),
        // a lambda that shadows x doesn't reference it; otherwise count the body
        Expr::Lam(pats, body, _) => {
            if binds_var(pats, x) {
                (0, 0)
            } else {
                analyze(body, x, mode, ctx)
            }
        }
    }
}

/// True if any of the patterns binds the name `x` (shadowing).
fn binds_var(pats: &[Pat], x: &str) -> bool {
    let mut s = HashSet::new();
    for p in pats {
        collect_pat_vars(p, &mut s);
    }
    s.contains(x)
}

fn analyze_assigns(assigns: &[(String, Expr)], x: &str, ctx: &Ctx) -> Uses {
    assigns
        .iter()
        .map(|(fname, e)| {
            let m = arg_mode(ctx.field_mults.get(fname));
            analyze(e, x, m, ctx)
        })
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
        Expr::Int(_, _) | Expr::Str(_, _) | Expr::Con(_, _) => {}
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
            assigns.iter().for_each(|(_, e)| collect_last(e, x, best))
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
        Expr::Int(_, _) | Expr::Str(_, _) | Expr::Con(_, _) => st,
        Expr::BinOp(_, l, r, _) => {
            st = walk(l, x, Mode::Borrow, ctx, st);
            walk(r, x, Mode::Borrow, ctx, st)
        }
        Expr::App(_, _, _) => {
            let (head, args) = spine(e);
            let mults = head_mults(head, ctx);
            st = walk(head, x, Mode::Borrow, ctx, st);
            for (i, a) in args.iter().enumerate() {
                st = walk(a, x, arg_mode(mults.get(i)), ctx, st);
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
    ty: String,
}

fn class_of_type(ty: &Type, mu: &HashSet<String>) -> Lin {
    Lin {
        must_use: is_must_use(ty, mu),
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
                    let consumed = cur
                        .keys()
                        .find(|w| analyze(rhs, w, Mode::Consume, ctx).0 > 0)
                        .cloned();
                    if let Some(w) = consumed {
                        let class = cur[&w].clone();
                        lets.push((b.name.clone(), class.clone(), body, b.span));
                        cur.insert(b.name.clone(), class);
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
            for (_, b) in arms {
                scan_lets(b, lin, ctx, lets, inplace, func);
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
        Expr::Var(_, _) | Expr::Int(_, _) | Expr::Str(_, _) | Expr::Con(_, _) => {}
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
            assigns.iter().for_each(|(_, e)| go(e))
        }
        Expr::Lam(_, body, _) => go(body),
        Expr::Var(_, _) | Expr::Int(_, _) | Expr::Str(_, _) | Expr::Con(_, _) => {}
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
        Expr::Int(_, _) | Expr::Str(_, _) | Expr::Con(_, _) => None,
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
    let arg0 = args.first();
    match head {
        Expr::Var(n, _) if n == "arena_mark" => match arg0 {
            Some(Expr::Var(a, _)) => MarkOp::OpenMark { arena: a },
            _ => MarkOp::Other,
        },
        Expr::Var(n, _) if n == "allocateCell" => match arg0 {
            Some(Expr::Var(a, _)) => MarkOp::Alloc { arena: a },
            _ => MarkOp::Other,
        },
        Expr::Var(n, _) if n == "arena_release" => match arg0 {
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
        Expr::Int(_, _) | Expr::Str(_, _) | Expr::Con(_, _) => {}
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
            assigns.iter().for_each(|(_, e)| collect_var_refs(e, f))
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
            assigns.iter().for_each(|(_, e)| f(e))
        }
        Expr::Lam(_, body, _) => f(body),
        Expr::Var(_, _) | Expr::Int(_, _) | Expr::Str(_, _) | Expr::Con(_, _) => {}
    }
}
