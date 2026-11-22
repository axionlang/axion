//! Totality (`{-# TOTAL f g #-}`): a function declared total is checked to return a value for
//! every argument — it terminates, and nothing on any path can abort.
//!
//! * **Termination** by size-change (Lee, Jones & Ben-Amram): every call inside a recursive
//!   group gets a graph saying which measures of the caller the callee's measures are strictly
//!   below, or not above; the group terminates when every idempotent graph of the closure under
//!   composition, from a function to itself, has a strict self-edge. A measure is the structural
//!   size of a parameter (a pattern takes it apart), or an `Int` quantity — a parameter, `b - p`,
//!   `p - b` or `len a - p` — that must be `>= 0` where it strictly decreases. The `Int`
//!   decreases are proven by `refine.rs`'s arithmetic from the facts on the path to the call
//!   (conditions, guards, refinements), each with a certificate `refine::check_cert` accepts.
//! * **No aborts**: every `case`, clause list and lambda pattern covers all values (nested
//!   patterns included), every guard list cannot all fail, each array access and SIMD lane is
//!   proven in range, each division has a divisor proven non-zero, and only built-ins known to
//!   return normally are used (`exitWith`, FFI calls and the like are not).
//! * **Total callees**: everything a total function uses (functions, instance methods) must be
//!   total too; it is checked the same way, prelude included.
//!
//! `Float` arithmetic, `Int` wrap-around and I/O are total (they return). The check runs on the
//! prepared module after a scratch inference (operators resolved to their `Int`/`Float`/
//! `Integer` forms, local functions' parameter types known), in both the batch and the editor
//! pipeline.

use crate::ast::{Body, Expr, Func, Module, Pat, Span};
use crate::diag::{Diagnostic, Diagnostics};
use crate::refine::{Measure, SctCall, TotWalk};
use std::collections::{BTreeMap, BTreeSet, HashMap, HashSet};

/// Why a function is not total.
#[derive(Clone, Debug)]
struct Reason {
    code: &'static str,
    msg: String,
    span: Span,
    /// the original failure a chain of calls leads to
    root: String,
}

/// The top-level function a node belongs to.
fn local_parent(node: &str) -> &str {
    match node.split_once('$') {
        Some((p, l)) if !l.starts_with('$') => p,
        _ => node,
    }
}

/// Strongly connected components (Tarjan), in an order where a component comes after the ones
/// it reaches.
fn sccs(n: usize, succ: &[Vec<usize>]) -> Vec<Vec<usize>> {
    struct St<'a> {
        succ: &'a [Vec<usize>],
        index: Vec<Option<usize>>,
        low: Vec<usize>,
        on: Vec<bool>,
        stack: Vec<usize>,
        next: usize,
        out: Vec<Vec<usize>>,
    }
    fn visit(s: &mut St, v: usize) {
        s.index[v] = Some(s.next);
        s.low[v] = s.next;
        s.next += 1;
        s.stack.push(v);
        s.on[v] = true;
        for &w in &s.succ[v] {
            match s.index[w] {
                None => {
                    visit(s, w);
                    s.low[v] = s.low[v].min(s.low[w]);
                }
                Some(iw) if s.on[w] => s.low[v] = s.low[v].min(iw),
                _ => {}
            }
        }
        if Some(s.low[v]) == s.index[v] {
            let mut comp = Vec::new();
            while let Some(w) = s.stack.pop() {
                s.on[w] = false;
                comp.push(w);
                if w == v {
                    break;
                }
            }
            s.out.push(comp);
        }
    }
    let mut s = St {
        succ,
        index: vec![None; n],
        low: vec![0; n],
        on: vec![false; n],
        stack: Vec::new(),
        next: 0,
        out: Vec::new(),
    };
    for v in 0..n {
        if s.index[v].is_none() {
            visit(&mut s, v);
        }
    }
    s.out
}

// --- size-change termination ---

/// A size-change graph from one function to another: `(caller measure, callee measure, strict)`,
/// at most one edge per pair (a strict one when both exist).
#[derive(Clone, PartialEq, Eq, Hash, PartialOrd, Ord)]
struct Graph {
    from: usize,
    to: usize,
    edges: BTreeSet<(usize, usize, bool)>,
}

fn normalize(
    edges: impl IntoIterator<Item = (usize, usize, bool)>,
) -> BTreeSet<(usize, usize, bool)> {
    let mut best: BTreeMap<(usize, usize), bool> = BTreeMap::new();
    for (i, j, s) in edges {
        let e = best.entry((i, j)).or_insert(false);
        *e |= s;
    }
    best.into_iter().map(|((i, j), s)| (i, j, s)).collect()
}

fn compose(a: &Graph, b: &Graph) -> Graph {
    let mut out = Vec::new();
    for &(i, j, s1) in &a.edges {
        for &(j2, k, s2) in &b.edges {
            if j == j2 {
                out.push((i, k, s1 || s2));
            }
        }
    }
    Graph {
        from: a.from,
        to: b.to,
        edges: normalize(out),
    }
}

/// The size-change principle over one recursive group: `None` when every infinite call
/// sequence would descend some measure forever (so none exists), else the span of a call on a
/// cycle that does not.
fn size_change(calls: &[(Graph, Span)]) -> Result<(), Span> {
    const LIMIT: usize = 20_000;
    let mut all: HashMap<Graph, Span> = HashMap::new();
    let mut work: Vec<Graph> = Vec::new();
    for (g, sp) in calls {
        if !all.contains_key(g) {
            all.insert(g.clone(), *sp);
            work.push(g.clone());
        }
    }
    let base: Vec<Graph> = all.keys().cloned().collect();
    while let Some(g) = work.pop() {
        for b in &base {
            if b.from != g.to {
                continue;
            }
            let c = compose(&g, b);
            if !all.contains_key(&c) {
                let sp = all[&g];
                all.insert(c.clone(), sp);
                work.push(c);
                if all.len() > LIMIT {
                    return Err(sp);
                }
            }
        }
    }
    for (g, sp) in &all {
        if g.from == g.to && compose(g, g) == *g && !g.edges.iter().any(|&(i, j, s)| i == j && s) {
            return Err(*sp);
        }
    }
    Ok(())
}

// --- pattern coverage (Maranget's usefulness) ---

#[derive(Clone, Debug)]
enum P {
    Any,
    Con(String, Vec<P>),
    Tup(Vec<P>),
    Lit(String),
}

fn to_p(p: &Pat) -> P {
    match p {
        Pat::Wild(_) | Pat::Var(..) => P::Any,
        Pat::Int(k, _) => P::Lit(k.to_string()),
        Pat::Str(s, _) => P::Lit(format!("{s:?}")),
        Pat::Con(c, ps, _) => P::Con(c.clone(), ps.iter().map(to_p).collect()),
        Pat::Tuple(ps, _) => P::Tup(ps.iter().map(to_p).collect()),
    }
}

#[derive(Clone, PartialEq, Eq, Hash, Debug)]
enum Ctor {
    Con(String, usize),
    Tup(usize),
    Lit(String),
}

/// Constructor → (its type, arity); type → its constructors.
struct Cons {
    of: HashMap<String, String>,
    all: HashMap<String, Vec<(String, usize)>>,
}

impl Cons {
    fn new(m: &Module) -> Cons {
        let mut of = HashMap::new();
        let mut all: HashMap<String, Vec<(String, usize)>> = HashMap::new();
        for d in &m.datas {
            for c in &d.cons {
                of.insert(c.name.clone(), d.name.clone());
                all.entry(d.name.clone())
                    .or_default()
                    .push((c.name.clone(), c.fields.len()));
            }
        }
        if !all.contains_key("Bool") {
            for c in ["True", "False"] {
                of.insert(c.into(), "Bool".into());
            }
            all.insert("Bool".into(), vec![("True".into(), 0), ("False".into(), 0)]);
        }
        Cons { of, all }
    }
}

fn head(p: &P) -> Option<Ctor> {
    match p {
        P::Any => None,
        P::Con(c, a) => Some(Ctor::Con(c.clone(), a.len())),
        P::Tup(a) => Some(Ctor::Tup(a.len())),
        P::Lit(l) => Some(Ctor::Lit(l.clone())),
    }
}

fn arity(c: &Ctor) -> usize {
    match c {
        Ctor::Con(_, a) | Ctor::Tup(a) => *a,
        Ctor::Lit(_) => 0,
    }
}

fn specialize(rows: &[Vec<P>], c: &Ctor) -> Vec<Vec<P>> {
    let mut out = Vec::new();
    for r in rows {
        let rest = &r[1..];
        let new: Option<Vec<P>> = match &r[0] {
            P::Any => Some(vec![P::Any; arity(c)]),
            p if head(p).as_ref() == Some(c) => match p {
                P::Con(_, a) | P::Tup(a) => Some(a.clone()),
                _ => Some(Vec::new()),
            },
            _ => None,
        };
        if let Some(mut n) = new {
            n.extend(rest.iter().cloned());
            out.push(n);
        }
    }
    out
}

fn useful(rows: &[Vec<P>], q: &[P], cons: &Cons) -> bool {
    let Some(q0) = q.first() else {
        return rows.is_empty();
    };
    if let Some(c) = head(q0) {
        let mut nq = match q0 {
            P::Con(_, a) | P::Tup(a) => a.clone(),
            _ => Vec::new(),
        };
        nq.extend(q[1..].iter().cloned());
        return useful(&specialize(rows, &c), &nq, cons);
    }
    let heads: HashSet<Ctor> = rows.iter().filter_map(|r| head(&r[0])).collect();
    // the constructors of the column's type, when the rows name all of them
    let complete: Option<Vec<Ctor>> = if let Some(Ctor::Tup(n)) = heads.iter().next() {
        Some(vec![Ctor::Tup(*n)])
    } else {
        let tys: HashSet<&String> = heads
            .iter()
            .filter_map(|h| match h {
                Ctor::Con(c, _) => cons.of.get(c),
                _ => None,
            })
            .collect();
        match (tys.len(), heads.is_empty()) {
            (1, false) if heads.iter().all(|h| matches!(h, Ctor::Con(..))) => {
                let ty = tys.into_iter().next().cloned().unwrap_or_default();
                let all: Vec<Ctor> = cons.all[&ty]
                    .iter()
                    .map(|(c, a)| Ctor::Con(c.clone(), *a))
                    .collect();
                all.iter().all(|c| heads.contains(c)).then_some(all)
            }
            _ => None,
        }
    };
    match complete {
        Some(all) => all.iter().any(|c| {
            let mut nq = vec![P::Any; arity(c)];
            nq.extend(q[1..].iter().cloned());
            useful(&specialize(rows, c), &nq, cons)
        }),
        None => {
            let def: Vec<Vec<P>> = rows
                .iter()
                .filter(|r| matches!(r[0], P::Any))
                .map(|r| r[1..].to_vec())
                .collect();
            useful(&def, &q[1..], cons)
        }
    }
}

fn covers(rows: &[Vec<P>], width: usize, cons: &Cons) -> bool {
    !useful(rows, &vec![P::Any; width], cons)
}

/// Every `case` and lambda pattern in a function (its locals included) that may not match.
fn uncovered_cases(f: &Func, cons: &Cons, out: &mut Vec<Span>) {
    fn expr(e: &Expr, cons: &Cons, out: &mut Vec<Span>) {
        match e {
            Expr::Case(s, arms, sp) => {
                let rows: Vec<Vec<P>> = arms.iter().map(|(p, _)| vec![to_p(p)]).collect();
                if !covers(&rows, 1, cons) {
                    out.push(*sp);
                }
                expr(s, cons, out);
                arms.iter().for_each(|(_, b)| expr(b, cons, out));
            }
            Expr::Lam(ps, b, sp) => {
                let rows = vec![ps.iter().map(to_p).collect::<Vec<_>>()];
                if !covers(&rows, ps.len(), cons) {
                    out.push(*sp);
                }
                expr(b, cons, out);
            }
            Expr::App(a, b, _) | Expr::BinOp(_, a, b, _) => {
                expr(a, cons, out);
                expr(b, cons, out);
            }
            Expr::If(c, t, f, _) => {
                expr(c, cons, out);
                expr(t, cons, out);
                expr(f, cons, out);
            }
            Expr::Let(fs, b, _) => {
                fs.iter().for_each(|f| uncovered_cases(f, cons, out));
                expr(b, cons, out);
            }
            Expr::Tuple(es, _) => es.iter().for_each(|x| expr(x, cons, out)),
            Expr::RecordCon(_, fs, _) => fs.iter().for_each(|(_, x)| expr(x, cons, out)),
            Expr::RecordUpd(b, fs, _) => {
                expr(b, cons, out);
                fs.iter().for_each(|(_, x)| expr(x, cons, out));
            }
            Expr::Int(..) | Expr::Float(..) | Expr::Str(..) | Expr::Var(..) | Expr::Con(..) => {}
        }
    }
    for c in &f.clauses {
        match &c.body {
            Body::Plain(e) => expr(e, cons, out),
            Body::Guarded(arms) => arms.iter().for_each(|(g, r)| {
                expr(g, cons, out);
                expr(r, cons, out);
            }),
        }
        c.wher.iter().for_each(|w| uncovered_cases(w, cons, out));
    }
}

/// Do a function's clauses cover every argument? A clause whose guards may all fail does not
/// count (the call would fall through it).
fn clauses_cover(clauses: &[(Span, Vec<Pat>)], open: &HashSet<Span>, cons: &Cons) -> bool {
    let width = clauses.first().map_or(0, |c| c.1.len());
    let rows: Vec<Vec<P>> = clauses
        .iter()
        .filter(|(sp, _)| !open.contains(sp))
        .map(|(_, ps)| ps.iter().map(to_p).collect())
        .collect();
    covers(&rows, width, cons)
}

// --- comparisons ---

/// The comparison an operator name stands for: the built-in ones, and the prelude's `<=`, `>=`
/// and `/=` (functions, so called by name once the prelude is in, and resolved to `<=$Int` …).
fn comparison(name: &str) -> Option<&'static str> {
    let base = name.strip_suffix("$Int").unwrap_or(name);
    ["<=", ">=", "/=", "==", "<", ">"]
        .into_iter()
        .find(|c| *c == base)
}

/// `(<=$Int) a b` → `a <= b`, so the facts a comparison gives are seen (`refine.rs` reads
/// comparisons as operators).
fn restore_comparisons(e: &mut Expr) {
    match e {
        Expr::App(f, b, _) => {
            restore_comparisons(f);
            restore_comparisons(b);
        }
        Expr::BinOp(_, a, b, _) => {
            restore_comparisons(a);
            restore_comparisons(b);
        }
        Expr::If(c, t, f, _) => {
            restore_comparisons(c);
            restore_comparisons(t);
            restore_comparisons(f);
        }
        Expr::Let(fs, b, _) => {
            fs.iter_mut().for_each(restore_comparisons_fn);
            restore_comparisons(b);
        }
        Expr::Case(sc, arms, _) => {
            restore_comparisons(sc);
            arms.iter_mut().for_each(|(_, b)| restore_comparisons(b));
        }
        Expr::Tuple(es, _) => es.iter_mut().for_each(restore_comparisons),
        Expr::RecordCon(_, fs, _) => fs.iter_mut().for_each(|(_, x)| restore_comparisons(x)),
        Expr::RecordUpd(b, fs, _) => {
            restore_comparisons(b);
            fs.iter_mut().for_each(|(_, x)| restore_comparisons(x));
        }
        Expr::Lam(_, b, _) => restore_comparisons(b),
        Expr::Int(..) | Expr::Float(..) | Expr::Str(..) | Expr::Var(..) | Expr::Con(..) => {}
    }
    if let Expr::App(f, b, sp) = e {
        if let Expr::App(g, a, _) = &**f {
            if let Expr::Var(op, _) = &**g {
                if let Some(c) = comparison(op) {
                    *e = Expr::BinOp(c.to_string(), a.clone(), b.clone(), *sp);
                }
            }
        }
    }
}

fn restore_comparisons_fn(f: &mut Func) {
    for c in &mut f.clauses {
        match &mut c.body {
            Body::Plain(e) => restore_comparisons(e),
            Body::Guarded(arms) => arms.iter_mut().for_each(|(g, r)| {
                restore_comparisons(g);
                restore_comparisons(r);
            }),
        }
        c.wher.iter_mut().for_each(restore_comparisons_fn);
    }
}

// --- the check ---

fn display(node: &str) -> String {
    match node.split_once('$') {
        Some((parent, local)) if !local.starts_with('$') => {
            format!(
                "{} (in `{parent}`)",
                local.split('#').next().unwrap_or(local)
            )
        }
        _ => node.to_string(),
    }
}

/// Check every function the module declares total; report each that is not.
pub fn check(module: &Module, diags: &mut Diagnostics) {
    if module.total.is_empty() {
        return;
    }
    let tops: HashSet<&str> = module.funcs.iter().map(|f| f.name.as_str()).collect();
    let mut wanted: Vec<(String, Span)> = Vec::new();
    for (name, sp) in &module.total {
        if tops.contains(name.as_str()) {
            wanted.push((name.clone(), *sp));
        } else {
            diags.push(
                Diagnostic::error(
                    "AX0703",
                    format!("`{name}` in a TOTAL pragma is not a top-level function here"),
                )
                .label(sp.0, sp.1, "no such function")
                .with_help("name a function this module defines: `{-# TOTAL sumTo #-}`"),
            );
        }
    }
    if wanted.is_empty() {
        return;
    }
    // a scratch inference: operators resolved to their typed forms, method uses to their
    // instances, constrained functions specialized; locals' parameter types. Type errors are
    // reported by the real pipeline.
    let mut scratch = Diagnostics::default();
    let mono = crate::infer::infer(module, &mut scratch);
    if scratch.has_errors() {
        return;
    }
    let mut m = module.clone();
    crate::resolve_methods(&mut m, &mono.resolutions);
    crate::materialize_specs(&mut m, &mono.specs);
    for f in &mut m.funcs {
        restore_comparisons_fn(f);
    }
    let cons = Cons::new(&m);

    // top-level call graph and the functions a total one depends on
    let names: Vec<String> = m.funcs.iter().map(|f| f.name.clone()).collect();
    let idx: HashMap<&str, usize> = names
        .iter()
        .enumerate()
        .map(|(i, n)| (n.as_str(), i))
        .collect();
    let mut succ: Vec<Vec<usize>> = vec![Vec::new(); names.len()];
    for (i, f) in m.funcs.iter().enumerate() {
        let mut r = HashSet::new();
        crate::collect_func_refs(f, &mut r);
        let mut v: Vec<usize> = r
            .iter()
            .filter_map(|n| idx.get(n.as_str()).copied())
            .collect();
        v.sort_unstable();
        succ[i] = v;
    }
    let mut needed: HashSet<String> = HashSet::new();
    let mut stack: Vec<usize> = wanted
        .iter()
        .filter_map(|(n, _)| idx.get(n.as_str()).copied())
        .collect();
    while let Some(i) = stack.pop() {
        if needed.insert(names[i].clone()) {
            stack.extend(succ[i].iter().copied());
        }
    }
    let mut top_scc = HashMap::new();
    for (k, comp) in sccs(names.len(), &succ).into_iter().enumerate() {
        for v in comp {
            if needed.contains(&names[v]) {
                top_scc.insert(names[v].clone(), k);
            }
        }
    }
    let tw = crate::refine::total_walk(
        &m,
        &needed,
        TotWalk::new(mono.where_param_tys.clone(), top_scc),
    );

    // the node graph: needed top-level functions and their locals
    let mut nodes: Vec<String> = needed.iter().cloned().collect();
    nodes.extend(tw.locals.keys().cloned());
    nodes.sort();
    let nidx: HashMap<&str, usize> = nodes
        .iter()
        .enumerate()
        .map(|(i, n)| (n.as_str(), i))
        .collect();
    let mut reasons: Vec<Vec<Reason>> = vec![Vec::new(); nodes.len()];
    let mut nsucc: Vec<Vec<usize>> = vec![Vec::new(); nodes.len()];
    for r in &tw.refs {
        let Some(&from) = nidx.get(r.from.as_str()) else {
            continue;
        };
        if let Some(why) = r.to.strip_prefix("partial:") {
            reasons[from].push(Reason {
                code: "AX0701",
                msg: why.to_string(),
                span: r.span,
                root: String::new(),
            });
        } else if let Some(&to) = nidx.get(r.to.as_str()) {
            nsucc[from].push(to);
        }
    }
    for s in &mut nsucc {
        s.sort_unstable();
        s.dedup();
    }

    // coverage
    let by_name: HashMap<&str, &Func> = m.funcs.iter().map(|f| (f.name.as_str(), f)).collect();
    for (i, n) in nodes.iter().enumerate() {
        if let Some(f) = by_name.get(n.as_str()) {
            let cl: Vec<(Span, Vec<Pat>)> =
                f.clauses.iter().map(|c| (c.span, c.pats.clone())).collect();
            if !clauses_cover(&cl, &tw.guards_open, &cons) {
                reasons[i].push(Reason {
                    code: "AX0701",
                    msg: "its clauses (and their guards) do not cover every argument".into(),
                    span: f.span,
                    root: String::new(),
                });
            }
            let mut bad = Vec::new();
            uncovered_cases(f, &cons, &mut bad);
            for sp in bad {
                reasons[i].push(Reason {
                    code: "AX0701",
                    msg:
                        "this pattern match does not cover every value (a nested pattern may fail)"
                            .into(),
                    span: sp,
                    root: String::new(),
                });
            }
        } else if let Some((_, sp, cl)) = tw.locals.get(n) {
            if !clauses_cover(cl, &tw.guards_open, &cons) {
                reasons[i].push(Reason {
                    code: "AX0701",
                    msg: format!(
                        "the clauses of `{}` (and their guards) do not cover every argument",
                        display(n)
                    ),
                    span: *sp,
                    root: String::new(),
                });
            }
        }
    }

    // termination, per recursive group
    for comp in sccs(nodes.len(), &nsucc) {
        let set: HashSet<usize> = comp.iter().copied().collect();
        let recursive = comp.len() > 1 || nsucc[comp[0]].contains(&comp[0]);
        if !recursive {
            continue;
        }
        let mut bad_use = None;
        for r in &tw.refs {
            if let (Some(&a), Some(&b)) = (nidx.get(r.from.as_str()), nidx.get(r.to.as_str())) {
                if set.contains(&a) && set.contains(&b) && !r.saturated {
                    bad_use = Some((a, b, r.span));
                }
            }
        }
        if let Some((a, b, sp)) = bad_use {
            for &v in &comp {
                reasons[v].push(Reason {
                    code: "AX0700",
                    msg: format!(
                        "`{}` is used as a value inside its own recursion, so its calls cannot be \
                         followed",
                        display(&nodes[b])
                    ),
                    span: if v == a { sp } else { (0, 0) },
                    root: String::new(),
                });
            }
            continue;
        }
        let calls: Vec<(Graph, Span)> = tw
            .calls
            .iter()
            .filter_map(|c: &SctCall| {
                let (a, b) = (*nidx.get(c.caller.as_str())?, *nidx.get(c.callee.as_str())?);
                (set.contains(&a) && set.contains(&b)).then(|| {
                    (
                        Graph {
                            from: a,
                            to: b,
                            edges: normalize(c.edges.iter().copied()),
                        },
                        c.span,
                    )
                })
            })
            .collect();
        // every call between members must have been seen (a missing one is an unknown edge)
        let seen: HashSet<(usize, usize)> = calls.iter().map(|(g, _)| (g.from, g.to)).collect();
        let missing = comp.iter().any(|&a| {
            nsucc[a]
                .iter()
                .any(|b| set.contains(b) && !seen.contains(&(a, *b)))
        });
        let verdict = if missing {
            Err((0, 0))
        } else {
            size_change(&calls)
        };
        if let Err(sp) = verdict {
            for &v in &comp {
                let tried: Vec<String> = tw
                    .measures
                    .get(&nodes[v])
                    .map(|ms| {
                        ms.iter()
                            .filter_map(|m| match m {
                                Measure::Int(_, _, d) => Some(format!("`{d}`")),
                                Measure::Struct(_) => None,
                            })
                            .take(6)
                            .collect()
                    })
                    .unwrap_or_default();
                let tried = if tried.is_empty() {
                    String::new()
                } else {
                    format!(
                        " (tried the size of each argument, and {})",
                        tried.join(", ")
                    )
                };
                reasons[v].push(Reason {
                    code: "AX0700",
                    msg: format!(
                        "cannot show that the recursion of `{}` terminates: no argument gets \
                         smaller on every cycle of calls{tried}",
                        display(&nodes[v])
                    ),
                    span: sp,
                    root: String::new(),
                });
            }
        }
    }

    // a function using a non-total one is not total
    let mut changed = true;
    while changed {
        changed = false;
        for a in 0..nodes.len() {
            if !reasons[a].is_empty() {
                continue;
            }
            for r in &tw.refs {
                if r.from != nodes[a] {
                    continue;
                }
                let Some(&b) = nidx.get(r.to.as_str()) else {
                    continue;
                };
                let root = reasons[b]
                    .iter()
                    .find(|x| x.code != "AX0702")
                    .or_else(|| reasons[b].first())
                    .map(|x| {
                        if x.root.is_empty() {
                            x.msg.clone()
                        } else {
                            x.root.clone()
                        }
                    });
                if let Some(root) = root {
                    // name the callee, unless it is one of this function's own locals
                    let same = local_parent(&nodes[a]) == local_parent(&nodes[b]);
                    let msg = if same {
                        root.clone()
                    } else {
                        format!(
                            "it calls `{}`, which is not total: {root}",
                            display(&nodes[b])
                        )
                    };
                    reasons[a].push(Reason {
                        code: if same { "AX0701" } else { "AX0702" },
                        msg,
                        span: r.span,
                        root,
                    });
                    changed = true;
                    break;
                }
            }
        }
    }

    for (name, _) in &wanted {
        let Some(f) = by_name.get(name.as_str()) else {
            continue;
        };
        // the function's own reasons and its locals'
        let mut rs: Vec<&Reason> = Vec::new();
        for (i, n) in nodes.iter().enumerate() {
            let local = n
                .strip_prefix(name.as_str())
                .is_some_and(|rest| rest.starts_with('$') && !rest.starts_with("$$"));
            if n == name || local {
                rs.extend(reasons[i].iter());
            }
        }
        // its own reasons; "calls a function that is not total" only when it has none
        if rs.iter().any(|r| r.code != "AX0702") {
            rs.retain(|r| r.code != "AX0702");
        }
        let mut shown = HashSet::new();
        for r in rs.into_iter().take(6) {
            let sp = if inside(f, r.span) { r.span } else { f.span };
            if !shown.insert((sp, r.msg.clone())) {
                continue;
            }
            let help = match r.code {
                "AX0700" => {
                    "a total function's recursive calls must make some argument smaller: a value \
                     a pattern took apart, or an `Int` that is `>= 0` there and decreases (or \
                     counts up to a bound: `if i < n then go (i + 1) n`). The facts on the path \
                     to the call — `if`/guard conditions and refinements — are what is known."
                }
                "AX0702" => {
                    "everything a total function uses must be total too; declare it total to see \
                     why it is not, or use another function"
                }
                _ => {
                    "a total function must return on every input: cover every pattern, guard \
                     against an out-of-range index or a zero divisor (`if i < lenArray a then …`), \
                     and do not end the program"
                }
            };
            diags.push(
                Diagnostic::error(
                    r.code,
                    format!("`{name}` is declared total, but {}", lower_first(&r.msg)),
                )
                .label(sp.0, sp.1, short(r.code))
                .with_help(help),
            );
        }
    }
}

/// Is `sp` inside function `f`'s text (its signature or a clause)?
fn inside(f: &Func, sp: Span) -> bool {
    let within = |o: Span| o.0 <= sp.0 && sp.1 <= o.1;
    sp.1 > sp.0 && (within(f.span) || f.clauses.iter().any(|c| within(c.span)))
}

fn short(code: &str) -> &'static str {
    match code {
        "AX0700" => "this call may not terminate",
        "AX0702" => "calls a function that is not total",
        _ => "may fail at run time",
    }
}

fn lower_first(s: &str) -> String {
    let mut c = s.chars();
    match c.next() {
        Some(f) if !s.starts_with('`') => f.to_lowercase().collect::<String>() + c.as_str(),
        _ => s.to_string(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn g(from: usize, to: usize, edges: &[(usize, usize, bool)]) -> (Graph, Span) {
        (
            Graph {
                from,
                to,
                edges: normalize(edges.iter().copied()),
            },
            (1, 2),
        )
    }

    #[test]
    fn size_change_accepts_descent_and_lexicographic_orders() {
        // f x = f (x - 1)
        assert!(size_change(&[g(0, 0, &[(0, 0, true)])]).is_ok());
        // ack: (m strict) and (m equal, n strict)
        assert!(size_change(&[
            g(0, 0, &[(0, 0, true)]),
            g(0, 0, &[(0, 0, false), (1, 1, true)]),
        ])
        .is_ok());
        // f x y = f y x with both shrinking across the swap
        assert!(size_change(&[g(0, 0, &[(0, 1, true), (1, 0, true)])]).is_ok());
        // mutual: f → g keeps, g → f shrinks
        assert!(size_change(&[g(0, 1, &[(0, 0, false)]), g(1, 0, &[(0, 0, true)])]).is_ok());
    }

    #[test]
    fn size_change_refuses_cycles_without_descent() {
        assert!(size_change(&[g(0, 0, &[])]).is_err());
        assert!(size_change(&[g(0, 0, &[(0, 0, false)])]).is_err());
        // each call shrinks one argument but grows the other one's partner: merge-like
        // calls that each keep only one edge compose to nothing
        assert!(size_change(&[g(0, 0, &[(0, 0, true)]), g(0, 0, &[(1, 1, true)])]).is_err());
        // a swap that never shrinks
        assert!(size_change(&[g(0, 0, &[(0, 1, false), (1, 0, false)])]).is_err());
    }

    #[test]
    fn coverage_sees_nested_patterns() {
        let Some(m) = crate::parse_source(
            "data Maybe a = Nothing | Just a\ndata List a = Nil | Cons a (List a)\nmain :: Int\nmain = 0\n",
            &mut Diagnostics::default(),
        ) else {
            panic!("parse");
        };
        let cons = Cons::new(&m);
        let sp = (0, 0);
        let just = |p: Pat| Pat::Con("Just".into(), vec![p], sp);
        let cons_ = |a: Pat, b: Pat| Pat::Con("Cons".into(), vec![a, b], sp);
        let nil = Pat::Con("Nil".into(), vec![], sp);
        let any = || Pat::Wild(sp);
        let rows = |ps: Vec<Pat>| ps.into_iter().map(|p| vec![to_p(&p)]).collect::<Vec<_>>();
        assert!(!covers(
            &rows(vec![cons_(just(any()), any()), nil.clone()]),
            1,
            &cons
        ));
        assert!(covers(
            &rows(vec![
                cons_(just(any()), any()),
                cons_(Pat::Con("Nothing".into(), vec![], sp), any()),
                nil
            ]),
            1,
            &cons
        ));
        assert!(!covers(&rows(vec![Pat::Int(0, sp)]), 1, &cons));
        assert!(covers(&rows(vec![Pat::Int(0, sp), any()]), 1, &cons));
    }
}
