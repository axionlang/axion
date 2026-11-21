//! Local functions in `let` (`let go k = … in go 3`) become `where`-locals of the enclosing
//! clause, so the native backends compile them like any `where` function (Core lowers only a
//! `let` that binds a value).
//!
//! A `let` function may use variables bound anywhere around it — a `case` binder, a lambda
//! parameter, an earlier `let` — which a `where`-local cannot see. So each one is lifted with
//! those variables as explicit leading parameters (its captures), and every use of it becomes
//! the lifted function applied to them: `go k` → `f$go$let0 h k`. The functions of one `let`
//! share one capture list (the union), so one can call another and pass the captures on.
//!
//! The rewrite runs before type inference and the checks, for every backend: the interpreter
//! runs the same lifted program. A group is left as it was (still interpreter-only) when it
//! cannot be lifted faithfully: a capture name rebound where the function is used, or by the
//! function's own parameters; a `where` inside the local function; a lambda around the `let`
//! or around a use (a lambda body cannot call a `where`-local); or a use as a value or with
//! too few arguments (native code cannot partially apply a `where`-local yet).

use crate::ast::{self, Body, Expr, Func, Pat, Span};
use std::collections::{BTreeSet, HashMap};

/// Lifts the `let` functions of every top-level function into its clauses' `where` lists.
pub fn lift_let_functions(module: &mut ast::Module) {
    for f in &mut module.funcs {
        let mut ctr = 0usize;
        let fname = f.name.clone();
        for clause in &mut f.clauses {
            let mut lifted = Vec::new();
            let mut scope = BTreeSet::new();
            clause
                .pats
                .iter()
                .for_each(|p| ast::pat_vars(p, &mut scope));
            let mut cx = Cx {
                fname: &fname,
                ctr: &mut ctr,
                lifted: &mut lifted,
            };
            lift_body(&mut clause.body, &scope, &mut cx);
            // a `let` inside a `where`-local: its scope is the clause's params and its own
            for w in &mut clause.wher {
                for wc in &mut w.clauses {
                    let mut ws = scope.clone();
                    wc.pats.iter().for_each(|p| ast::pat_vars(p, &mut ws));
                    lift_body(&mut wc.body, &ws, &mut cx);
                }
            }
            clause.wher.extend(lifted);
        }
    }
}

struct Cx<'a> {
    fname: &'a str,
    ctr: &'a mut usize,
    lifted: &'a mut Vec<Func>,
}

fn lift_body(b: &mut Body, scope: &BTreeSet<String>, cx: &mut Cx) {
    match b {
        Body::Plain(e) => lift_expr(e, scope, cx),
        Body::Guarded(arms) => {
            for (g, r) in arms {
                lift_expr(g, scope, cx);
                lift_expr(r, scope, cx);
            }
        }
    }
}

/// `scope`: the LOCAL names bound around `e` (parameters, `case`/lambda binders, `let`s) — the
/// ones a lifted function must take as captures. Module functions and `where`-locals are not in
/// it: a lifted function, itself a `where`-local of the same clause, sees them directly.
fn lift_expr(e: &mut Expr, scope: &BTreeSet<String>, cx: &mut Cx) {
    match e {
        Expr::Int(..) | Expr::Float(..) | Expr::Str(..) | Expr::Var(..) | Expr::Con(..) => {}
        Expr::App(a, b, _) | Expr::BinOp(_, a, b, _) => {
            lift_expr(a, scope, cx);
            lift_expr(b, scope, cx);
        }
        Expr::If(c, t, el, _) => {
            lift_expr(c, scope, cx);
            lift_expr(t, scope, cx);
            lift_expr(el, scope, cx);
        }
        Expr::Tuple(es, _) => es.iter_mut().for_each(|x| lift_expr(x, scope, cx)),
        Expr::RecordCon(_, fs, _) => fs.iter_mut().for_each(|(_, x)| lift_expr(x, scope, cx)),
        Expr::RecordUpd(b, fs, _) => {
            lift_expr(b, scope, cx);
            fs.iter_mut().for_each(|(_, x)| lift_expr(x, scope, cx));
        }
        // a lambda body cannot call a `where`-local (it is lifted out of the clause on its
        // own), so a `let` inside one stays as it is
        Expr::Lam(..) => {}
        Expr::Case(scrut, arms, _) => {
            lift_expr(scrut, scope, cx);
            for (p, body) in arms {
                let mut s = scope.clone();
                ast::pat_vars(p, &mut s);
                lift_expr(body, &s, cx);
            }
        }
        Expr::Let(binds, body, _) => {
            // the binds of one `let` see each other (and themselves)
            let mut inner = scope.clone();
            inner.extend(binds.iter().map(|b| b.name.clone()));
            // inner `let`s first: a nested local function is lifted with its own captures,
            // which then are ordinary variables of this one
            for b in binds.iter_mut() {
                for c in &mut b.clauses {
                    let mut s = inner.clone();
                    c.pats.iter().for_each(|p| ast::pat_vars(p, &mut s));
                    lift_body(&mut c.body, &s, cx);
                }
            }
            lift_expr(body, &inner, cx);
            lift_group(e, &inner, cx);
        }
    }
}

/// A `let` bind that is a function: it takes parameters, or has several clauses or guards.
fn is_function_bind(b: &Func) -> bool {
    !matches!(b.clauses.as_slice(), [c] if c.pats.is_empty() && matches!(c.body, Body::Plain(_)))
}

/// Lifts the function binds of the `let` at `e` (whose binds' names are in `inner`), if it can
/// do so faithfully; otherwise leaves the `let` as it is.
fn lift_group(e: &mut Expr, inner: &BTreeSet<String>, cx: &mut Cx) {
    let Expr::Let(binds, body, _) = e else { return };
    let group: Vec<String> = binds
        .iter()
        .filter(|b| is_function_bind(b))
        .map(|b| b.name.clone())
        .collect();
    if group.is_empty()
        || binds
            .iter()
            .filter(|b| is_function_bind(b))
            .any(|b| b.clauses.iter().any(|c| !c.wher.is_empty()))
    {
        return;
    }
    let group_set: BTreeSet<String> = group.iter().cloned().collect();
    // the captures: the local variables the group's functions use, other than its own names
    let mut caps: BTreeSet<String> = BTreeSet::new();
    for b in binds.iter().filter(|b| group_set.contains(&b.name)) {
        for c in &b.clauses {
            let mut bound = BTreeSet::new();
            c.pats.iter().for_each(|p| ast::pat_vars(p, &mut bound));
            let mut fv = BTreeSet::new();
            body_free_vars(&c.body, &bound, &mut fv);
            caps.extend(
                fv.into_iter()
                    .filter(|n| inner.contains(n) && !group_set.contains(n)),
            );
        }
    }
    let caps: Vec<String> = caps.into_iter().collect();
    // a function's own parameter named like a capture would hide it from the calls it makes
    for b in binds.iter().filter(|b| group_set.contains(&b.name)) {
        for c in &b.clauses {
            let mut own = BTreeSet::new();
            c.pats.iter().for_each(|p| ast::pat_vars(p, &mut own));
            if caps.iter().any(|k| own.contains(k)) {
                return;
            }
        }
    }
    let names: HashMap<String, String> = group
        .iter()
        .map(|g| {
            let n = format!("{}${g}$let{}", cx.fname, *cx.ctr);
            *cx.ctr += 1;
            (g.clone(), n)
        })
        .collect();
    // a local function used as a value (`map addN xs`) or given fewer arguments than it takes
    // would become a partial application of a `where`-local, which native code cannot make yet
    let arity: HashMap<String, usize> = binds
        .iter()
        .filter(|b| group_set.contains(&b.name))
        .map(|b| {
            (
                b.name.clone(),
                b.clauses.first().map_or(0, |c| c.pats.len()),
            )
        })
        .collect();
    let all_saturated = saturated(body, &arity)
        && binds.iter().all(|b| {
            b.clauses.iter().all(|c| {
                let mut own = BTreeSet::new();
                c.pats.iter().for_each(|p| ast::pat_vars(p, &mut own));
                body_saturated(&c.body, &without(&arity, &own))
            })
        });
    if !all_saturated {
        return;
    }
    // rewrite every use, on copies: a capture rebound at a use leaves everything untouched
    let mut new_body = (**body).clone();
    let mut new_binds = binds.clone();
    let mut ok = subst(&mut new_body, &names, &caps);
    for b in &mut new_binds {
        for c in &mut b.clauses {
            // a bind's own parameters shadow a group name they rebind
            let mut own = BTreeSet::new();
            c.pats.iter().for_each(|p| ast::pat_vars(p, &mut own));
            let live: HashMap<String, String> = names
                .iter()
                .filter(|(g, _)| !own.contains(*g))
                .map(|(g, n)| (g.clone(), n.clone()))
                .collect();
            ok &= subst_body(&mut c.body, &live, &caps);
        }
    }
    if !ok {
        return;
    }
    let mut kept = Vec::new();
    for b in new_binds {
        let Some(new_name) = names.get(&b.name) else {
            kept.push(b);
            continue;
        };
        let clauses = b
            .clauses
            .into_iter()
            .map(|c| {
                let mut pats: Vec<Pat> = caps.iter().map(|k| Pat::Var(k.clone(), c.span)).collect();
                pats.extend(c.pats);
                ast::Clause {
                    pats,
                    body: c.body,
                    wher: Vec::new(),
                    span: c.span,
                }
            })
            .collect();
        cx.lifted.push(Func {
            name: new_name.clone(),
            sig: None,
            clauses,
            span: b.span,
            constraints: Vec::new(),
        });
    }
    *e = if kept.is_empty() {
        new_body
    } else {
        let sp = e.span();
        Expr::Let(kept, Box::new(new_body), sp)
    };
}

/// The lifted function applied to its captures, at the span of the use it replaces.
fn applied(new_name: &str, caps: &[String], sp: Span) -> Expr {
    caps.iter()
        .fold(Expr::Var(new_name.to_string(), sp), |acc, k| {
            Expr::App(Box::new(acc), Box::new(Expr::Var(k.clone(), sp)), sp)
        })
}

/// Replaces each free use of a group name (`names`) in `e` by its lifted function applied to
/// `caps`. `false` when a capture is rebound around such a use (the captured variable would
/// not be the one the function saw): the caller then keeps the `let` as it was.
fn subst(e: &mut Expr, names: &HashMap<String, String>, caps: &[String]) -> bool {
    if names.is_empty() {
        return true;
    }
    match e {
        Expr::Var(n, sp) => {
            if let Some(new) = names.get(n.as_str()) {
                *e = applied(new, caps, *sp);
            }
            true
        }
        Expr::Int(..) | Expr::Float(..) | Expr::Str(..) | Expr::Con(..) => true,
        Expr::App(a, b, _) | Expr::BinOp(_, a, b, _) => {
            subst(a, names, caps) & subst(b, names, caps)
        }
        Expr::If(c, t, el, _) => {
            subst(c, names, caps) & subst(t, names, caps) & subst(el, names, caps)
        }
        Expr::Tuple(es, _) => es.iter_mut().fold(true, |ok, x| subst(x, names, caps) & ok),
        Expr::RecordCon(_, fs, _) => fs
            .iter_mut()
            .fold(true, |ok, (_, x)| subst(x, names, caps) & ok),
        Expr::RecordUpd(b, fs, _) => {
            let ok = subst(b, names, caps);
            fs.iter_mut()
                .fold(ok, |ok, (_, x)| subst(x, names, caps) & ok)
        }
        // used inside a lambda, which cannot call the `where`-local it would become
        Expr::Lam(ps, body, _) => {
            let mut bound = BTreeSet::new();
            ps.iter().for_each(|p| ast::pat_vars(p, &mut bound));
            !uses_any(body, &narrowed(names, &bound))
        }
        Expr::Case(scrut, arms, _) => {
            let mut ok = subst(scrut, names, caps);
            for (p, body) in arms {
                let mut bound = BTreeSet::new();
                ast::pat_vars(p, &mut bound);
                ok &= under_binders(body, &bound, names, caps);
            }
            ok
        }
        Expr::Let(binds, body, _) => {
            let bound: BTreeSet<String> = binds.iter().map(|b| b.name.clone()).collect();
            let inner = narrowed(names, &bound);
            let rebinds_cap = caps.iter().any(|k| bound.contains(k));
            let mentions = uses_any(body, &inner)
                || binds
                    .iter()
                    .any(|b| b.clauses.iter().any(|c| body_uses_any(&c.body, &inner)));
            if rebinds_cap && mentions {
                return false;
            }
            let mut ok = true;
            for b in binds.iter_mut() {
                for c in &mut b.clauses {
                    let mut own = BTreeSet::new();
                    c.pats.iter().for_each(|p| ast::pat_vars(p, &mut own));
                    if caps.iter().any(|k| own.contains(k)) && body_uses_any(&c.body, &inner) {
                        return false;
                    }
                    ok &= subst_body(&mut c.body, &narrowed(&inner, &own), caps);
                }
            }
            ok & subst(body, &inner, caps)
        }
    }
}

/// [`subst`] under binders `bound`: they hide the group names they rebind, and rebinding a
/// capture around a use of the group is a conflict.
fn under_binders(
    body: &mut Expr,
    bound: &BTreeSet<String>,
    names: &HashMap<String, String>,
    caps: &[String],
) -> bool {
    let inner = narrowed(names, bound);
    if caps.iter().any(|k| bound.contains(k)) && uses_any(body, &inner) {
        return false;
    }
    subst(body, &inner, caps)
}

fn subst_body(b: &mut Body, names: &HashMap<String, String>, caps: &[String]) -> bool {
    match b {
        Body::Plain(e) => subst(e, names, caps),
        Body::Guarded(arms) => arms.iter_mut().fold(true, |ok, (g, r)| {
            subst(g, names, caps) & subst(r, names, caps) & ok
        }),
    }
}

/// `names` without the ones `bound` rebinds.
fn narrowed(names: &HashMap<String, String>, bound: &BTreeSet<String>) -> HashMap<String, String> {
    names
        .iter()
        .filter(|(g, _)| !bound.contains(*g))
        .map(|(g, n)| (g.clone(), n.clone()))
        .collect()
}

/// `true` if `e` mentions any of `names` (conservatively: shadowing not considered).
fn uses_any(e: &Expr, names: &HashMap<String, String>) -> bool {
    if names.is_empty() {
        return false;
    }
    let mut fv = BTreeSet::new();
    free_vars(e, &BTreeSet::new(), &mut fv);
    fv.iter().any(|n| names.contains_key(n))
}

fn body_uses_any(b: &Body, names: &HashMap<String, String>) -> bool {
    match b {
        Body::Plain(e) => uses_any(e, names),
        Body::Guarded(arms) => arms
            .iter()
            .any(|(g, r)| uses_any(g, names) || uses_any(r, names)),
    }
}

fn body_free_vars(b: &Body, bound: &BTreeSet<String>, out: &mut BTreeSet<String>) {
    match b {
        Body::Plain(e) => free_vars(e, bound, out),
        Body::Guarded(arms) => {
            for (g, r) in arms {
                free_vars(g, bound, out);
                free_vars(r, bound, out);
            }
        }
    }
}

/// The variables `e` uses that are not bound inside it (nor in `bound`).
fn free_vars(e: &Expr, bound: &BTreeSet<String>, out: &mut BTreeSet<String>) {
    match e {
        Expr::Var(n, _) => {
            if !bound.contains(n) {
                out.insert(n.clone());
            }
        }
        Expr::Int(..) | Expr::Float(..) | Expr::Str(..) | Expr::Con(..) => {}
        Expr::App(a, b, _) | Expr::BinOp(_, a, b, _) => {
            free_vars(a, bound, out);
            free_vars(b, bound, out);
        }
        Expr::If(c, t, el, _) => {
            free_vars(c, bound, out);
            free_vars(t, bound, out);
            free_vars(el, bound, out);
        }
        Expr::Tuple(es, _) => es.iter().for_each(|x| free_vars(x, bound, out)),
        Expr::RecordCon(_, fs, _) => fs.iter().for_each(|(_, x)| free_vars(x, bound, out)),
        Expr::RecordUpd(b, fs, _) => {
            free_vars(b, bound, out);
            fs.iter().for_each(|(_, x)| free_vars(x, bound, out));
        }
        Expr::Lam(ps, body, _) => {
            let mut b2 = bound.clone();
            ps.iter().for_each(|p| ast::pat_vars(p, &mut b2));
            free_vars(body, &b2, out);
        }
        Expr::Case(scrut, arms, _) => {
            free_vars(scrut, bound, out);
            for (p, body) in arms {
                let mut b2 = bound.clone();
                ast::pat_vars(p, &mut b2);
                free_vars(body, &b2, out);
            }
        }
        Expr::Let(binds, body, _) => {
            let mut b2 = bound.clone();
            b2.extend(binds.iter().map(|b| b.name.clone()));
            for b in binds {
                for c in &b.clauses {
                    let mut b3 = b2.clone();
                    c.pats.iter().for_each(|p| ast::pat_vars(p, &mut b3));
                    body_free_vars(&c.body, &b3, out);
                }
            }
            free_vars(body, &b2, out);
        }
    }
}

/// `ar` without the names `bound` rebinds.
fn without(ar: &HashMap<String, usize>, bound: &BTreeSet<String>) -> HashMap<String, usize> {
    ar.iter()
        .filter(|(g, _)| !bound.contains(*g))
        .map(|(g, n)| (g.clone(), *n))
        .collect()
}

/// `true` if every use in `e` of a function in `ar` (name → arity) is a call with at least
/// that many arguments.
fn saturated(e: &Expr, ar: &HashMap<String, usize>) -> bool {
    if ar.is_empty() {
        return true;
    }
    match e {
        Expr::Var(n, _) => ar.get(n).is_none_or(|&k| k == 0),
        Expr::Int(..) | Expr::Float(..) | Expr::Str(..) | Expr::Con(..) => true,
        Expr::App(..) => {
            let mut args = Vec::new();
            let mut head = e;
            while let Expr::App(f, a, _) = head {
                args.push(a.as_ref());
                head = f;
            }
            let head_ok = match head {
                Expr::Var(n, _) => ar.get(n).is_none_or(|&k| args.len() >= k),
                other => saturated(other, ar),
            };
            head_ok && args.iter().all(|a| saturated(a, ar))
        }
        Expr::BinOp(_, a, b, _) => saturated(a, ar) && saturated(b, ar),
        Expr::If(c, t, el, _) => saturated(c, ar) && saturated(t, ar) && saturated(el, ar),
        Expr::Tuple(es, _) => es.iter().all(|x| saturated(x, ar)),
        Expr::RecordCon(_, fs, _) => fs.iter().all(|(_, x)| saturated(x, ar)),
        Expr::RecordUpd(b, fs, _) => saturated(b, ar) && fs.iter().all(|(_, x)| saturated(x, ar)),
        Expr::Lam(ps, body, _) => {
            let mut bound = BTreeSet::new();
            ps.iter().for_each(|p| ast::pat_vars(p, &mut bound));
            saturated(body, &without(ar, &bound))
        }
        Expr::Case(scrut, arms, _) => {
            saturated(scrut, ar)
                && arms.iter().all(|(p, body)| {
                    let mut bound = BTreeSet::new();
                    ast::pat_vars(p, &mut bound);
                    saturated(body, &without(ar, &bound))
                })
        }
        Expr::Let(binds, body, _) => {
            let bound: BTreeSet<String> = binds.iter().map(|b| b.name.clone()).collect();
            let inner = without(ar, &bound);
            saturated(body, &inner)
                && binds.iter().all(|b| {
                    b.clauses.iter().all(|c| {
                        let mut own = BTreeSet::new();
                        c.pats.iter().for_each(|p| ast::pat_vars(p, &mut own));
                        body_saturated(&c.body, &without(&inner, &own))
                    })
                })
        }
    }
}

fn body_saturated(b: &Body, ar: &HashMap<String, usize>) -> bool {
    match b {
        Body::Plain(e) => saturated(e, ar),
        Body::Guarded(arms) => arms
            .iter()
            .all(|(g, r)| saturated(g, ar) && saturated(r, ar)),
    }
}
