//! Bounds-check elimination for counting loops, by loop versioning.
//!
//! A loop in Axión is a self-tail-recursive function. This pass recognizes the counting shape
//!
//! ```text
//! f … j … =
//!   let c = j > n          (or j >= n, j == n; n a parameter)
//!   ret if c then <exit, no recursion>
//!       else <straight line: getArray/setArray …>; ret call f … (j + 1) …
//! ```
//!
//! (or counting down: `j < 0` exits, the recursion passes `j - 1`), where every parameter other
//! than `j` and the arrays is passed on unchanged, and each array is passed on unchanged or
//! through `setArray` (which keeps its length). An access whose index is `c + s * j`, with `c` and
//! `s` built only from those invariant parameters (inlining small pure Int helpers like gauss's
//! `ix n i j = i * (n + 1) + j`), is in bounds for EVERY iteration when, at entry,
//!
//! ```text
//! s = 0:   0 <= c < len
//! s ≠ 0:   s >= 1,  0 <= c < len,  low >= 0,  high <= (len - 1 - c) / s
//! ```
//!
//! where the counter takes the values `low ..= high` (`j0 ..= n` for `>`, `j0 ..= n-1` for `>=` /
//! `==`, `0 ..= j0` counting down). Then every index lies in `c ..= c + s*high <= len - 1`, and no
//! intermediate overflows (`s*j <= len - 1 - c`). The guard itself cannot overflow or trap: it
//! divides by `max(s, 1)` and only adds small constants to values bounded by `len`. Indices are
//! computed in wrapping arithmetic, but the guard bounds the machine value directly (`c` and `s`
//! are the machine values of the invariant parts; the index is `c + s*j` mod 2^64, and the bound
//! shows no wrap occurs), so the argument holds for the value actually used. `==` additionally
//! needs `j0 <= n` (otherwise the counter would run past `n`).
//!
//! The function's body becomes `if <guard> then <clone> else <original body>`: the clone (`f$bce`)
//! is the same Core — same drops — with the proven accesses unchecked (`axion_array_get_nobc` /
//! `axion_array_set_nobc`) and its recursion into itself. When the guard fails the original,
//! fully checked code runs, so an out-of-bounds access still aborts exactly as before. Runs on the
//! final Core (after drop insertion); the drop verifier and backends see the result.

use crate::ast::Span;
use crate::core::{Atom, CoreFn, Op, Rhs, Term};
use std::collections::{HashMap, HashSet};

pub const GET_NOBC: &str = "axion_array_get_nobc";
pub const SET_NOBC: &str = "axion_array_set_nobc";

/// A symbolic Int expression over the function's parameters.
#[derive(Clone, Debug, PartialEq)]
enum Sym {
    Int(i64),
    Var(String),
    Add(Box<Sym>, Box<Sym>),
    Sub(Box<Sym>, Box<Sym>),
    Mul(Box<Sym>, Box<Sym>),
}

impl Sym {
    fn vars(&self, out: &mut HashSet<String>) {
        match self {
            Sym::Int(_) => {}
            Sym::Var(v) => {
                out.insert(v.clone());
            }
            Sym::Add(a, b) | Sym::Sub(a, b) | Sym::Mul(a, b) => {
                a.vars(out);
                b.vars(out);
            }
        }
    }
}

/// `e` as `coef * j + rest` (wrapping), `coef`/`rest` free of `j` (`coef` `None` = 0); `None` if
/// `j` occurs non-linearly.
fn split_j(e: &Sym, j: &str) -> Option<(Option<Sym>, Sym)> {
    fn add(a: Option<Sym>, b: Option<Sym>) -> Option<Sym> {
        match (a, b) {
            (None, x) | (x, None) => x,
            (Some(a), Some(b)) => Some(Sym::Add(Box::new(a), Box::new(b))),
        }
    }
    match e {
        Sym::Int(_) => Some((None, e.clone())),
        Sym::Var(v) if v == j => Some((Some(Sym::Int(1)), Sym::Int(0))),
        Sym::Var(_) => Some((None, e.clone())),
        Sym::Add(a, b) => {
            let (ca, ra) = split_j(a, j)?;
            let (cb, rb) = split_j(b, j)?;
            Some((add(ca, cb), Sym::Add(Box::new(ra), Box::new(rb))))
        }
        Sym::Sub(a, b) => {
            let (ca, ra) = split_j(a, j)?;
            let (cb, rb) = split_j(b, j)?;
            let coef = match (ca, cb) {
                (x, None) => x,
                (None, Some(b)) => Some(Sym::Sub(Box::new(Sym::Int(0)), Box::new(b))),
                (Some(a), Some(b)) => Some(Sym::Sub(Box::new(a), Box::new(b))),
            };
            Some((coef, Sym::Sub(Box::new(ra), Box::new(rb))))
        }
        Sym::Mul(a, b) => {
            let (ca, ra) = split_j(a, j)?;
            let (cb, rb) = split_j(b, j)?;
            let rest = Sym::Mul(Box::new(ra.clone()), Box::new(rb.clone()));
            match (ca, cb) {
                (None, None) => Some((None, rest)),
                // (ca*j + ra) * rb
                (Some(c), None) => Some((Some(Sym::Mul(Box::new(c), Box::new(rb))), rest)),
                (None, Some(c)) => Some((Some(Sym::Mul(Box::new(ra), Box::new(c))), rest)),
                (Some(_), Some(_)) => None,
            }
        }
    }
}

/// A small pure Int function (`ix n i j = …`): its params and its result as a `Sym`.
fn pure_int_fn(f: &CoreFn) -> Option<Sym> {
    let mut env: HashMap<String, Sym> = HashMap::new();
    let mut t = &f.body;
    loop {
        match t {
            Term::Let(x, Rhs::Op(op), _, b) => {
                env.insert(x.clone(), op_sym(op, &env, &HashMap::new(), 0)?);
                t = b;
            }
            Term::Ret(Rhs::Op(op), _) => return op_sym(op, &env, &HashMap::new(), 0),
            _ => return None,
        }
    }
}

fn atom_sym(a: &Atom, env: &HashMap<String, Sym>) -> Option<Sym> {
    match a {
        Atom::Int(n) => Some(Sym::Int(*n)),
        Atom::Var(v) => Some(env.get(v).cloned().unwrap_or_else(|| Sym::Var(v.clone()))),
        _ => None,
    }
}

/// The `Sym` an Int op computes, inlining calls to pure Int helpers (`pure`, by name).
fn op_sym(
    op: &Op,
    env: &HashMap<String, Sym>,
    pure: &HashMap<String, (Vec<String>, Sym)>,
    depth: usize,
) -> Option<Sym> {
    match op {
        Op::Atom(a) => atom_sym(a, env),
        Op::Prim(p, a, b) => {
            let (a, b) = (Box::new(atom_sym(a, env)?), Box::new(atom_sym(b, env)?));
            match p.as_str() {
                "+" => Some(Sym::Add(a, b)),
                "-" => Some(Sym::Sub(a, b)),
                "*" => Some(Sym::Mul(a, b)),
                _ => None,
            }
        }
        Op::CallDirect(g, args, _) if depth < 4 => {
            let (params, body) = pure.get(g)?;
            if params.len() != args.len() {
                return None;
            }
            let sub: HashMap<String, Sym> = params
                .iter()
                .zip(args)
                .map(|(p, a)| Some((p.clone(), atom_sym(a, env)?)))
                .collect::<Option<_>>()?;
            Some(subst(body, &sub))
        }
        _ => None,
    }
}

fn subst(e: &Sym, sub: &HashMap<String, Sym>) -> Sym {
    match e {
        Sym::Int(_) => e.clone(),
        Sym::Var(v) => sub.get(v).cloned().unwrap_or_else(|| e.clone()),
        Sym::Add(a, b) => Sym::Add(Box::new(subst(a, sub)), Box::new(subst(b, sub))),
        Sym::Sub(a, b) => Sym::Sub(Box::new(subst(a, sub)), Box::new(subst(b, sub))),
        Sym::Mul(a, b) => Sym::Mul(Box::new(subst(a, sub)), Box::new(subst(b, sub))),
    }
}

/// How the loop exits.
#[derive(Clone, Copy, PartialEq)]
enum Exit {
    /// `j > n`: iterations j0 ..= n
    Gt,
    /// `j >= n` / `j == n`: iterations j0 .. n (`==` also needs j0 <= n)
    Ge,
    Eq,
    /// `j < 0`, counting down by 1: iterations 0 ..= j0
    Down,
}

struct Plan {
    j: String,
    /// the bound (`Down`: unused)
    n: Atom,
    exit: Exit,
    /// proven accesses: (array param, invariant stride (`None` = 0), invariant offset)
    guards: Vec<(String, Option<Sym>, Sym)>,
}

/// Analyze `f`; on success the access sites (by position in the else chain) to elide.
fn analyze(
    f: &CoreFn,
    pure: &HashMap<String, (Vec<String>, Sym)>,
    lenpres: &HashMap<String, HashSet<usize>>,
) -> Option<(Plan, HashSet<usize>)> {
    // let c = <test>; ret if c then <exit> else <chain>
    let Term::Let(c, Rhs::Op(test), _, rest) = &f.body else {
        return None;
    };
    let Term::Ret(Rhs::If(Atom::Var(cv), th, el), _) = rest.as_ref() else {
        return None;
    };
    if cv != c {
        return None;
    }
    let bound = |a: &Atom| matches!(a, Atom::Var(_) | Atom::Int(_));
    let (exit, j, n) = match test {
        Op::Prim(p, Atom::Var(j), n) if p == ">" && bound(n) => (Exit::Gt, j, n.clone()),
        Op::Prim(p, Atom::Var(j), n) if p == "==" && bound(n) => (Exit::Eq, j, n.clone()),
        Op::Prim(p, Atom::Var(j), Atom::Int(0)) if p == "<" => (Exit::Down, j, Atom::Int(0)),
        Op::CallDirect(g, args, _) if g == ">=$Int" && args.len() == 2 => {
            match (&args[0], &args[1]) {
                (Atom::Var(j), n) if bound(n) => (Exit::Ge, j, n.clone()),
                _ => return None,
            }
        }
        _ => return None,
    };
    let params: HashSet<&String> = f.params.iter().collect();
    if !params.contains(j) || matches!(&n, Atom::Var(v) if !params.contains(v) || v == j) {
        return None;
    }
    if mentions_call(th, &f.name) {
        return None;
    }
    // walk the straight-line else chain
    let mut env: HashMap<String, Sym> = HashMap::new();
    let mut arr_of: HashMap<String, String> = HashMap::new(); // var → array param it IS
    let mut accesses: Vec<(usize, String, Sym)> = Vec::new(); // (site, array param, index sym)
    let mut site = 0usize;
    let mut t = el.as_ref();
    let rec_args = loop {
        match t {
            Term::Let(x, Rhs::Op(op), _, b) => {
                if let Op::RtCall { func, args, .. } = op {
                    if func == "axion_array_get" || func == "axion_array_set" {
                        let arr = match &args[0] {
                            Atom::Var(a) if params.contains(a) => Some(a.clone()),
                            Atom::Var(a) => arr_of.get(a).cloned(),
                            _ => None,
                        };
                        if let (Some(arr), Some(ix)) =
                            (arr, args.get(1).and_then(|i| atom_sym(i, &env)))
                        {
                            accesses.push((site, arr.clone(), ix));
                            if func == "axion_array_set" {
                                arr_of.insert(x.clone(), arr);
                            }
                        }
                        site += 1;
                    }
                }
                if mentions_call_op(op, &f.name) {
                    return None; // a non-tail recursion
                }
                // a call returning one of its array arguments with the length unchanged
                if let Op::CallDirect(g, args, _) = op {
                    if let Some(ps) = lenpres.get(g) {
                        for &i in ps {
                            let src = match args.get(i) {
                                Some(Atom::Var(a)) if params.contains(a) => Some(a.clone()),
                                Some(Atom::Var(a)) => arr_of.get(a).cloned(),
                                _ => None,
                            };
                            if let Some(src) = src {
                                arr_of.insert(x.clone(), src);
                            }
                        }
                    }
                }
                if let Some(s) = op_sym(op, &env, pure, 0) {
                    env.insert(x.clone(), s);
                }
                t = b;
            }
            // a conditional binding: opaque (its accesses stay checked), but must not recurse
            Term::Let(_, rhs @ (Rhs::If(..) | Rhs::Case(..)), _, b) => {
                if rhs_mentions_call(rhs, &f.name) {
                    return None;
                }
                t = b;
            }
            Term::Drop(_, _, _, _, b) => t = b,
            Term::Ret(Rhs::Op(Op::CallDirect(g, args, _)), _) if g == &f.name => break args,
            _ => return None,
        }
    };
    if rec_args.len() != f.params.len() {
        return None;
    }
    // per parameter: invariant, the counter, or an array threaded through setArray
    let mut invariant: HashSet<String> = HashSet::new();
    let mut arrays: HashSet<String> = HashSet::new();
    for (p, a) in f.params.iter().zip(rec_args) {
        match a {
            Atom::Var(v) if v == p => {
                invariant.insert(p.clone());
                arrays.insert(p.clone());
            }
            Atom::Var(v) if p == j => {
                // j' = j + 1 (counting up) / j - 1 (counting down)
                let jv = || Box::new(Sym::Var(j.clone()));
                let ok = if exit == Exit::Down {
                    env.get(v) == Some(&Sym::Sub(jv(), Box::new(Sym::Int(1))))
                } else {
                    env.get(v) == Some(&Sym::Add(jv(), Box::new(Sym::Int(1))))
                        || env.get(v) == Some(&Sym::Add(Box::new(Sym::Int(1)), jv()))
                };
                if !ok {
                    return None;
                }
            }
            Atom::Var(v) if arr_of.get(v) == Some(p) => {
                arrays.insert(p.clone());
            }
            _ => {}
        }
    }
    if matches!(&n, Atom::Var(v) if !invariant.contains(v)) || invariant.contains(j) {
        return None;
    }
    let mut guards: Vec<(String, Option<Sym>, Sym)> = Vec::new();
    let mut elide: HashSet<usize> = HashSet::new();
    for (site, arr, ix) in accesses {
        if !arrays.contains(&arr) {
            continue;
        }
        let Some((coef, off)) = split_j(&ix, j) else {
            continue;
        };
        let mut vs = HashSet::new();
        off.vars(&mut vs);
        if let Some(c) = &coef {
            c.vars(&mut vs);
        }
        if !vs
            .iter()
            .all(|v| invariant.contains(v) && params.contains(v))
        {
            continue;
        }
        let g = (arr, coef, off);
        if !guards.contains(&g) {
            guards.push(g);
        }
        elide.insert(site);
    }
    if elide.is_empty() {
        return None;
    }
    Some((
        Plan {
            j: j.clone(),
            n,
            exit,
            guards,
        },
        elide,
    ))
}

fn mentions_call(t: &Term, f: &str) -> bool {
    match t {
        Term::Let(_, rhs, _, b) => rhs_mentions_call(rhs, f) || mentions_call(b, f),
        Term::Drop(_, _, _, _, b) => mentions_call(b, f),
        Term::Ret(rhs, _) => rhs_mentions_call(rhs, f),
    }
}

fn rhs_mentions_call(r: &Rhs, f: &str) -> bool {
    match r {
        Rhs::Op(op) => mentions_call_op(op, f),
        Rhs::If(_, a, b) => mentions_call(a, f) || mentions_call(b, f),
        Rhs::Case(_, arms) => arms.iter().any(|(_, b)| mentions_call(b, f)),
    }
}

fn mentions_call_op(op: &Op, f: &str) -> bool {
    match op {
        Op::CallDirect(g, _, _) => g == f,
        Op::FuncAddr(g) => g == f,
        Op::MakeClosure { func, .. } => func == f,
        _ => false,
    }
}

/// The clone's else chain: elided sites renamed, the recursion redirected to the clone.
fn clone_body(t: &Term, f: &str, clone: &str, elide: &HashSet<usize>, site: &mut usize) -> Term {
    match t {
        Term::Let(x, Rhs::Op(op), sp, b) => {
            let mut op = op.clone();
            if let Op::RtCall { func, .. } = &mut op {
                if func == "axion_array_get" || func == "axion_array_set" {
                    if elide.contains(site) {
                        *func = if func == "axion_array_get" {
                            GET_NOBC
                        } else {
                            SET_NOBC
                        }
                        .into();
                    }
                    *site += 1;
                }
            }
            Term::Let(
                x.clone(),
                Rhs::Op(op),
                *sp,
                Box::new(clone_body(b, f, clone, elide, site)),
            )
        }
        Term::Let(x, rhs, sp, b) => Term::Let(
            x.clone(),
            rhs.clone(),
            *sp,
            Box::new(clone_body(b, f, clone, elide, site)),
        ),
        Term::Drop(v, k, s, sp, b) => Term::Drop(
            v.clone(),
            k.clone(),
            s.clone(),
            *sp,
            Box::new(clone_body(b, f, clone, elide, site)),
        ),
        Term::Ret(Rhs::Op(Op::CallDirect(g, args, ty)), sp) if g == f => Term::Ret(
            Rhs::Op(Op::CallDirect(clone.into(), args.clone(), ty.clone())),
            *sp,
        ),
        other => other.clone(),
    }
}

struct Emit {
    lets: Vec<(String, Op)>,
    ctr: usize,
}

impl Emit {
    fn fresh(&mut self) -> String {
        self.ctr += 1;
        format!("$bce{}", self.ctr)
    }
    fn op(&mut self, op: Op) -> Atom {
        let v = self.fresh();
        self.lets.push((v.clone(), op));
        Atom::Var(v)
    }
    fn prim(&mut self, p: &str, a: Atom, b: Atom) -> Atom {
        self.op(Op::Prim(p.into(), a, b))
    }
    fn sym(&mut self, e: &Sym) -> Atom {
        match e {
            Sym::Int(n) => Atom::Int(*n),
            Sym::Var(v) => Atom::Var(v.clone()),
            Sym::Add(a, b) => {
                let (a, b) = (self.sym(a), self.sym(b));
                self.prim("+", a, b)
            }
            Sym::Sub(a, b) => {
                let (a, b) = (self.sym(a), self.sym(b));
                self.prim("-", a, b)
            }
            Sym::Mul(a, b) => {
                let (a, b) = (self.sym(a), self.sym(b));
                self.prim("*", a, b)
            }
        }
    }
}

/// Applies the versioning to every recognized counting loop, appending the clones.
pub fn version_counting_loops(fns: &mut Vec<CoreFn>) {
    let pure: HashMap<String, (Vec<String>, Sym)> = fns
        .iter()
        .filter_map(|f| Some((f.name.clone(), (f.params.clone(), pure_int_fn(f)?))))
        .collect();
    let lenpres = length_preserving(fns);
    let mut clones = Vec::new();
    for f in fns.iter_mut() {
        if f.is_closure || !f.captures.is_empty() || f.name.starts_with("axion_") {
            continue;
        }
        let Some((plan, elide)) = analyze(f, &pure, &lenpres) else {
            continue;
        };
        let Term::Let(_, _, _, rest) = &f.body else {
            continue;
        };
        let Term::Ret(Rhs::If(_, _, el), _) = rest.as_ref() else {
            continue;
        };
        let clone_name = format!("{}$bce", f.name);
        // the clone: same test + exit, checked-free chain
        let mut site = 0;
        let new_el = clone_body(el, &f.name, &clone_name, &elide, &mut site);
        let mut cb = f.body.clone();
        if let Term::Let(_, _, _, r) = &mut cb {
            if let Term::Ret(Rhs::If(_, _, e), _) = r.as_mut() {
                **e = new_el;
            }
        }
        clones.push(CoreFn {
            name: clone_name.clone(),
            params: f.params.clone(),
            captures: Vec::new(),
            is_closure: false,
            owned_params: f.owned_params.clone(),
            owned_drop_ty: f.owned_drop_ty.clone(),
            body: cb,
        });
        // the guard
        let mut em = Emit {
            lets: Vec::new(),
            ctr: 0,
        };
        let j = Atom::Var(plan.j.clone());
        let n = plan.n.clone();
        // the counter's range low ..= high, as guard terms (`low >= 0` checked here; `high` bounds
        // each access below)
        let mut ok = match plan.exit {
            // counting down to 0: low = 0, nothing to check
            Exit::Down => Atom::Int(1),
            _ => em.prim(">", j.clone(), Atom::Int(-1)), // j0 >= 0
        };
        if plan.exit == Exit::Eq {
            // j0 <= n  (n + 1 > j0; n = MAX wraps → false → the checked path)
            let n1 = em.prim("+", n.clone(), Atom::Int(1));
            let le = em.prim(">", n1, j.clone());
            ok = em.prim("band", ok, le);
        }
        let mut lens: HashMap<String, Atom> = HashMap::new();
        for (arr, coef, off) in &plan.guards {
            let len = match lens.get(arr) {
                Some(l) => l.clone(),
                None => {
                    let l = em.op(Op::RtCall {
                        func: "axion_array_len".into(),
                        args: vec![Atom::Var(arr.clone())],
                        returns: true,
                    });
                    lens.insert(arr.clone(), l.clone());
                    l
                }
            };
            // 0 <= c < len
            let c = em.sym(off);
            let c_nonneg = em.prim(">", c.clone(), Atom::Int(-1));
            ok = em.prim("band", ok, c_nonneg);
            let room = em.prim("-", len, c); // len - c: no overflow when 0 <= c
            let c_in = em.prim(">", room.clone(), Atom::Int(0));
            ok = em.prim("band", ok, c_in);
            let Some(coef) = coef else { continue }; // stride 0: the one index is c
                                                     // s >= 1, and high <= q = (len - 1 - c) / max(s, 1)
            let s_ = em.sym(coef);
            let s_pos = em.prim(">", s_.clone(), Atom::Int(0));
            ok = em.prim("band", ok, s_pos.clone());
            let s_scaled = em.prim("*", s_, s_pos.clone()); // s if s > 0, else 0
            let not_pos = em.prim("-", Atom::Int(1), s_pos);
            let s_safe = em.prim("+", s_scaled, not_pos); // s if s > 0, else 1
            let span = em.prim("-", room, Atom::Int(1)); // len - 1 - c >= 0 when c < len
            let q = em.prim("div", span, s_safe);
            let fits = match plan.exit {
                // high = n:      n <= q  ⇔  q + 1 > n
                Exit::Gt => {
                    let q1 = em.prim("+", q, Atom::Int(1));
                    em.prim(">", q1, n.clone())
                }
                // high = n - 1:  n <= q + 1  ⇔  q + 2 > n
                Exit::Ge | Exit::Eq => {
                    let q2 = em.prim("+", q, Atom::Int(2));
                    em.prim(">", q2, n.clone())
                }
                // high = j0:     j0 <= q  ⇔  q + 1 > j0
                Exit::Down => {
                    let q1 = em.prim("+", q, Atom::Int(1));
                    em.prim(">", q1, j.clone())
                }
            };
            ok = em.prim("band", ok, fits);
        }
        if matches!(ok, Atom::Int(1)) {
            continue;
        }
        let sp: Span = crate::core::term_span(&f.body);
        let orig = std::mem::replace(&mut f.body, Term::Ret(Rhs::Op(Op::Atom(Atom::Int(0))), sp));
        let fast = Term::Ret(
            Rhs::Op(Op::CallDirect(
                clone_name,
                f.params.iter().map(|p| Atom::Var(p.clone())).collect(),
                ret_key(&orig, &f.name),
            )),
            sp,
        );
        let Atom::Var(okv) = ok else { continue };
        let mut body = Term::Ret(Rhs::If(Atom::Var(okv), Box::new(fast), Box::new(orig)), sp);
        for (v, op) in em.lets.into_iter().rev() {
            body = Term::Let(v, Rhs::Op(op), sp, Box::new(body));
        }
        f.body = body;
    }
    fns.extend(clones);
}

/// For each function, the parameters it returns with their length unchanged on every path: the
/// parameter itself, a `setArray` of it, or the result of such a call on it (`elimRow` returns
/// its matrix). A greatest fixpoint: assume every array-ish parameter, drop those a path breaks.
fn length_preserving(fns: &[CoreFn]) -> HashMap<String, HashSet<usize>> {
    let mut m: HashMap<String, HashSet<usize>> = fns
        .iter()
        .map(|f| (f.name.clone(), (0..f.params.len()).collect()))
        .collect();
    loop {
        let mut changed = false;
        for f in fns {
            let cur = m[&f.name].clone();
            let keep: HashSet<usize> = cur
                .into_iter()
                .filter(|&i| {
                    let mut alias = HashSet::from([f.params[i].clone()]);
                    preserves(&f.body, &mut alias, &m)
                })
                .collect();
            if keep != m[&f.name] {
                m.insert(f.name.clone(), keep);
                changed = true;
            }
        }
        if !changed {
            break;
        }
    }
    m.retain(|_, s| !s.is_empty());
    m
}

/// Every return path of `t` returns a member of `alias` (same allocation, same length).
fn preserves(t: &Term, alias: &mut HashSet<String>, m: &HashMap<String, HashSet<usize>>) -> bool {
    let is_alias =
        |a: &Atom, alias: &HashSet<String>| matches!(a, Atom::Var(v) if alias.contains(v));
    let op_alias = |op: &Op, alias: &HashSet<String>| match op {
        Op::Atom(a) => is_alias(a, alias),
        Op::RtCall { func, args, .. } => {
            (func == "axion_array_set" || func == SET_NOBC)
                && args.first().is_some_and(|a| is_alias(a, alias))
        }
        Op::CallDirect(g, args, _) => m.get(g).is_some_and(|ps| {
            ps.iter()
                .any(|&i| args.get(i).is_some_and(|a| is_alias(a, alias)))
        }),
        _ => false,
    };
    match t {
        Term::Let(x, Rhs::Op(op), _, b) => {
            if op_alias(op, alias) {
                alias.insert(x.clone());
            }
            preserves(b, alias, m)
        }
        Term::Let(_, _, _, b) | Term::Drop(_, _, _, _, b) => preserves(b, alias, m),
        Term::Ret(Rhs::Op(op), _) => op_alias(op, alias),
        Term::Ret(Rhs::If(_, a, b), _) => {
            preserves(a, &mut alias.clone(), m) && preserves(b, &mut alias.clone(), m)
        }
        Term::Ret(Rhs::Case(_, arms), _) => {
            !arms.is_empty()
                && arms
                    .iter()
                    .all(|(_, b)| preserves(b, &mut alias.clone(), m))
        }
    }
}

/// The produce key the function's own recursive call carries (the clone returns the same).
fn ret_key(t: &Term, f: &str) -> Option<String> {
    match t {
        Term::Let(_, rhs, _, b) => rhs_ret_key(rhs, f).or_else(|| ret_key(b, f)),
        Term::Drop(_, _, _, _, b) => ret_key(b, f),
        Term::Ret(rhs, _) => rhs_ret_key(rhs, f),
    }
}

fn rhs_ret_key(r: &Rhs, f: &str) -> Option<String> {
    match r {
        Rhs::Op(Op::CallDirect(g, _, ty)) if g == f => ty.clone(),
        Rhs::Op(_) => None,
        Rhs::If(_, a, b) => ret_key(a, f).or_else(|| ret_key(b, f)),
        Rhs::Case(_, arms) => arms.iter().find_map(|(_, b)| ret_key(b, f)),
    }
}

#[cfg(test)]
mod tests {
    use crate::diag::Diagnostics;
    use std::collections::HashSet;

    /// The functions that got a check-free clone, for `src` lowered like the compiler does.
    fn versioned(src: &str) -> HashSet<String> {
        let mut diags = Diagnostics::default();
        let (module, analysis) = crate::compile_front(src, ".", &mut diags);
        let module = module.expect("front-end must compile");
        let inplace: HashSet<(usize, usize)> = analysis.inplace.iter().map(|ip| ip.span).collect();
        let l = crate::core::lower_with(
            &module,
            &inplace,
            &analysis.makecon_tys,
            &analysis.array_tys,
            &analysis.integer_lits,
            &analysis.consume_native_exempt,
            &analysis.where_ret_tys,
            &analysis.where_param_tys,
            false,
        );
        l.fns
            .iter()
            .filter_map(|f| f.name.strip_suffix("$bce").map(str::to_string))
            .collect()
    }

    fn prog(loop_fn: &str) -> String {
        format!(
            "{loop_fn}\nmain :: Int\nmain = let a = newArray 10 1 in sumL a 2 0 7 0 + lenArray a\n"
        )
    }

    #[test]
    fn a_counting_loop_with_an_affine_index_is_versioned() {
        let v = versioned(&prog(
            "sumL :: Array Int -> Int -> Int -> Int -> Int -> Int\n\
             sumL a c j n acc = if j > n then acc else sumL a c (j + 1) n (acc + getArray a (c + j))",
        ));
        assert!(v.contains("sumL"), "{v:?}");
    }

    #[test]
    fn unprovable_loops_are_left_checked() {
        for (what, body) in [
            (
                "step 2",
                "if j > n then acc else sumL a c (j + 2) n (acc + getArray a (c + j))",
            ),
            (
                "bound moves",
                "if j > n then acc else sumL a c (j + 1) (n - 1) (acc + getArray a (c + j))",
            ),
            (
                "index not invariant",
                "if j > n then acc else sumL a c (j + 1) n (acc + getArray a acc)",
            ),
            (
                "offset changes",
                "if j > n then acc else sumL a (c + 1) (j + 1) n (acc + getArray a (c + j))",
            ),
            (
                "down, wrong exit",
                "if j < 1 then acc else sumL a c (j - 1) n (acc + getArray a (c + j))",
            ),
            (
                "down, counting up",
                "if j < 0 then acc else sumL a c (j + 1) n (acc + getArray a (c + j))",
            ),
        ] {
            let v = versioned(&prog(&format!(
                "sumL :: Array Int -> Int -> Int -> Int -> Int -> Int\nsumL a c j n acc = {body}"
            )));
            assert!(!v.contains("sumL"), "{what}: versioned {v:?}");
        }
    }

    #[test]
    fn an_array_replaced_by_another_is_not_trusted() {
        // the recursion passes a DIFFERENT array (a fresh, longer one): its length is not the
        // one the guard read, so the loop must stay checked
        let v = versioned(
            "grow :: Array Int -> Int -> Int -> Array Int\n\
             grow a j n = if j > n then a else grow (setArray (newArray (j + 2) 0) j 1) (j + 1) n\n\
             main :: Int\nmain = lenArray (grow (newArray 1 0) 0 5)\n",
        );
        assert!(!v.contains("grow"), "{v:?}");
    }
}
