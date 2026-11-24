//! Integer refinements in top-level signatures (`docs/refinements.md`):
//!
//! ```text
//! get :: a:Array Float -> {i:Int | 0 <= i && i < len a} -> Float
//! ```
//!
//! A refinement is a predicate over a function's `Int` arguments and its arrays' lengths. Every
//! call must prove it for its arguments, from what is known where the call is: the caller's own
//! refinements, the `if`/guard conditions on the path to the call, `case` literals, and `let`s.
//! A refined result (`-> {r:Int | 0 <= r}`) is proven at each return and known after each call.
//!
//! **Semantics.** A predicate is ordinary integer arithmetic over the *machine values* of the
//! names it mentions (no wrapping inside a predicate). Program code wraps (`Int` is 64-bit), so
//! a code expression `i + 1` stands for the integer `i + 1` only when the checker proves it does
//! not overflow; otherwise it is an unknown value. A comparison is used as a fact only when both
//! sides are evidently `Int` (an `Int` parameter, a literal, a `let` of such, `+ - *` of those,
//! an array length, a call to an `Int`-returning function): a `Float` comparison is never read as
//! an integer fact. Dropping a fact can only make a proof fail, never succeed wrongly.
//!
//! **Decision procedure.** "The facts imply the goal" is checked as "the facts and the negated
//! goal have no integer solution": Fourier–Motzkin elimination over linear constraints
//! `Σ c·x + k >= 0`, each normalized by the gcd of its coefficients with the constant rounded
//! down (sound for integers). Products of two unknowns are opaque atoms. A search that grows too
//! large gives up — the proof fails, the program is refused, nothing unsound is accepted.
//! Each refutation is recorded as a certificate (`Cert`: combinations and gcd tightenings of the
//! input rows) and counts only when the independent checker `check_cert` replays it — the same
//! algorithm as `metatheory/AxionRefine.lean`'s `check`, proven sound there. So the arithmetic
//! decision is not trusted; what remains trusted is reading facts and goals off the program.
//!
//! The checker is front-end only: refinements are erased, and every backend runs the program
//! unchanged — except that an array access proven in bounds (`getArray a i` with `0 <= i < len
//! a` proven) is recorded in `proven`, and the native backends emit it without its check.

use crate::ast::{Body, Expr, Func, Module, Pat, RefinePred, Refinement, Span, Type};
use crate::diag::{Diagnostic, Diagnostics};
use std::collections::{BTreeMap, HashMap, HashSet};

const MIN: i128 = i64::MIN as i128;
const MAX: i128 = i64::MAX as i128;
/// An array's length is below 2^61: allocating one whose size does not fit a `usize` is out of
/// memory (`axion-rt`'s `array_bytes`; the interpreter's `Vec` refuses it too). 2^60 is a
/// comfortable, still-sound bound that lets `i + 1` with `i < len a` be proven not to overflow.
const LEN_MAX: i128 = 1 << 60;
/// Fourier–Motzkin gives up (proof fails) beyond this many constraints.
const MAX_ROWS: usize = 4000;
/// …or when a negated goal splits into more cases than this.
const MAX_CASES: usize = 64;

/// A linear term `Σ coef·atom + c`.
#[derive(Clone, Debug, PartialEq, Eq, Hash)]
pub struct Lin {
    c: i128,
    t: BTreeMap<usize, i128>,
}

impl Lin {
    fn konst(c: i128) -> Lin {
        Lin {
            c,
            t: BTreeMap::new(),
        }
    }
    fn atom(a: usize) -> Lin {
        Lin {
            c: 0,
            t: BTreeMap::from([(a, 1)]),
        }
    }
    fn add(&self, o: &Lin) -> Option<Lin> {
        let mut r = self.clone();
        r.c = r.c.checked_add(o.c)?;
        for (a, k) in &o.t {
            let e = r.t.entry(*a).or_insert(0);
            *e = e.checked_add(*k)?;
        }
        r.t.retain(|_, k| *k != 0);
        Some(r)
    }
    fn scale(&self, k: i128) -> Option<Lin> {
        let mut r = Lin::konst(self.c.checked_mul(k)?);
        for (a, c) in &self.t {
            let v = c.checked_mul(k)?;
            if v != 0 {
                r.t.insert(*a, v);
            }
        }
        Some(r)
    }
    fn sub(&self, o: &Lin) -> Option<Lin> {
        self.add(&o.scale(-1)?)
    }
    fn as_const(&self) -> Option<i128> {
        self.t.is_empty().then_some(self.c)
    }
}

/// A predicate as a formula over constraints `lin >= 0`.
#[derive(Clone, Debug)]
enum Formula {
    True,
    False,
    Ge(Lin),
    And(Vec<Formula>),
    Or(Vec<Formula>),
}

fn negate(f: &Formula) -> Option<Formula> {
    Some(match f {
        Formula::True => Formula::False,
        Formula::False => Formula::True,
        // ¬(l >= 0) ⇔ l <= -1 ⇔ -l - 1 >= 0
        Formula::Ge(l) => Formula::Ge(l.scale(-1)?.add(&Lin::konst(-1))?),
        Formula::And(fs) => Formula::Or(fs.iter().map(negate).collect::<Option<_>>()?),
        Formula::Or(fs) => Formula::And(fs.iter().map(negate).collect::<Option<_>>()?),
    })
}

/// Disjunctive normal form: a list of cases, each a conjunction of constraints.
fn dnf(f: &Formula) -> Option<Vec<Vec<Lin>>> {
    match f {
        Formula::True => Some(vec![vec![]]),
        Formula::False => Some(vec![]),
        Formula::Ge(l) => Some(vec![vec![l.clone()]]),
        Formula::Or(fs) => {
            let mut out = Vec::new();
            for g in fs {
                out.extend(dnf(g)?);
                if out.len() > MAX_CASES {
                    return None;
                }
            }
            Some(out)
        }
        Formula::And(fs) => {
            let mut acc = vec![vec![]];
            for g in fs {
                let d = dnf(g)?;
                let mut next = Vec::new();
                for a in &acc {
                    for b in &d {
                        let mut c = a.clone();
                        c.extend(b.iter().cloned());
                        next.push(c);
                    }
                }
                if next.len() > MAX_CASES {
                    return None;
                }
                acc = next;
            }
            Some(acc)
        }
    }
}

/// The constraints a formula guarantees when it holds: those of every case of its normal form
/// (a constraint only some cases have is not guaranteed, so it contributes nothing).
fn conjuncts(f: &Formula, out: &mut Vec<Lin>) {
    let Some(cases) = dnf(f) else {
        return;
    };
    let mut cases = cases.into_iter();
    let Some(first) = cases.next() else {
        // no case at all: the formula is false, so anything holds; add a contradiction
        out.push(Lin::konst(-1));
        return;
    };
    let rest: Vec<Vec<Lin>> = cases.collect();
    for l in first {
        if rest.iter().all(|c| c.contains(&l)) && !out.contains(&l) {
            out.push(l);
        }
    }
}

fn gcd(a: i128, b: i128) -> i128 {
    let (mut a, mut b) = (a.abs(), b.abs());
    while b != 0 {
        (a, b) = (b, a % b);
    }
    a
}

/// The gcd of a row's coefficients (0 for a constant row).
fn coeff_gcd(l: &Lin) -> i128 {
    l.t.values().fold(0, |g, k| gcd(g, *k))
}

/// `l >= 0` over integers, divided by `g > 1` (the gcd of its coefficients) with the constant
/// rounded down: `2x + 3 >= 0` → `x + 1 >= 0` (x >= -1.5 ⇔ x >= -1 for an integer x).
fn tighten(mut l: Lin, g: i128) -> Lin {
    for k in l.t.values_mut() {
        *k /= g;
    }
    l.c = l.c.div_euclid(g);
    l
}

/// A row of a certificate: dense coefficients (variable `i` is coefficient `i`) and a constant,
/// meaning `Σ c[i]·x[i] + k >= 0`.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct CRow {
    pub c: Vec<i128>,
    pub k: i128,
}

/// A certificate step — the same three as `metatheory/AxionRefine.lean`'s `Step`.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum CStep {
    /// input row `i`
    Hyp(usize),
    /// `a·row[i] + b·row[j]`, `a, b >= 0`
    Comb(usize, i128, usize, i128),
    /// `row[i]` divided by `g > 0` (every coefficient divisible), the constant rounded down
    Tight(usize, i128),
}

/// A refutation: `steps`, replayed over `input`, end in a row `0 >= -k` with `k > 0`.
#[derive(Clone, Debug)]
pub struct Cert {
    pub input: Vec<CRow>,
    pub steps: Vec<CStep>,
}

/// The certificate checker — the trusted part of a refinement proof, independent of the search
/// that found it. It replays the steps with the rules of `AxionRefine.check` (proven sound in
/// Lean: an accepted certificate means the input rows have no integer solution); an arithmetic
/// overflow rejects the certificate (Lean's integers are unbounded, so this only refuses more).
pub fn check_cert(cert: &Cert) -> bool {
    fn add_l(a: &[i128], b: &[i128]) -> Option<Vec<i128>> {
        (0..a.len().max(b.len()))
            .map(|i| {
                a.get(i)
                    .copied()
                    .unwrap_or(0)
                    .checked_add(b.get(i).copied().unwrap_or(0))
            })
            .collect()
    }
    fn scale(m: i128, a: &[i128]) -> Option<Vec<i128>> {
        a.iter().map(|x| m.checked_mul(*x)).collect()
    }
    let mut rows: Vec<CRow> = Vec::new();
    for s in &cert.steps {
        let next = match *s {
            CStep::Hyp(i) => cert.input.get(i).cloned(),
            CStep::Comb(i, a, j, b) => (|| {
                if a < 0 || b < 0 {
                    return None;
                }
                let (r, t) = (rows.get(i)?, rows.get(j)?);
                Some(CRow {
                    c: add_l(&scale(a, &r.c)?, &scale(b, &t.c)?)?,
                    k: a.checked_mul(r.k)?.checked_add(b.checked_mul(t.k)?)?,
                })
            })(),
            CStep::Tight(i, g) => rows.get(i).and_then(|r| {
                (g > 0 && r.c.iter().all(|x| x.rem_euclid(g) == 0)).then(|| CRow {
                    c: r.c.iter().map(|x| x.div_euclid(g)).collect(),
                    k: r.k.div_euclid(g),
                })
            }),
        };
        match next {
            Some(r) => rows.push(r),
            None => return false,
        }
    }
    rows.last()
        .is_some_and(|r| r.c.iter().all(|x| *x == 0) && r.k < 0)
}

/// How a row of the search was derived.
#[derive(Clone, Copy)]
enum Origin {
    Hyp(usize),
    Comb(usize, i128, usize, i128),
    Tight(usize, i128),
}

/// Fourier–Motzkin elimination over the constraints (`each >= 0`), recording how each row is
/// derived. `Some(cert)` is a refutation: no integer solution. `None` means a solution exists or
/// the search gave up. Only `check_cert` decides whether the certificate counts.
fn refute(input: &[Lin]) -> Option<Cert> {
    let mut arena: Vec<(Lin, Origin)> = Vec::new();
    // a row, tightened by its gcd (a recorded step) when that is above 1
    fn push_norm(arena: &mut Vec<(Lin, Origin)>, l: Lin, o: Origin) -> usize {
        arena.push((l, o));
        let i = arena.len() - 1;
        let g = coeff_gcd(&arena[i].0);
        if g > 1 {
            let t = tighten(arena[i].0.clone(), g);
            arena.push((t, Origin::Tight(i, g)));
            return arena.len() - 1;
        }
        i
    }
    let mut cur: Vec<usize> = input
        .iter()
        .enumerate()
        .map(|(i, l)| push_norm(&mut arena, l.clone(), Origin::Hyp(i)))
        .collect();
    loop {
        let mut seen: HashSet<Lin> = HashSet::new();
        let mut rows = Vec::new();
        for i in cur.drain(..) {
            match arena[i].0.as_const() {
                Some(c) if c < 0 => return Some(build_cert(input, &arena, i)),
                Some(_) => {}
                None => {
                    if seen.insert(arena[i].0.clone()) {
                        rows.push(i);
                    }
                }
            }
        }
        // the variable whose elimination creates the fewest rows
        let mut count: BTreeMap<usize, (usize, usize)> = BTreeMap::new();
        for &i in &rows {
            for (a, k) in &arena[i].0.t {
                let e = count.entry(*a).or_default();
                if *k > 0 {
                    e.0 += 1;
                } else {
                    e.1 += 1;
                }
            }
        }
        let (&x, _) = count.iter().min_by_key(|(_, (p, n))| p * n)?;
        let (with, mut rest): (Vec<usize>, Vec<usize>) = rows
            .into_iter()
            .partition(|i| arena[*i].0.t.contains_key(&x));
        let (pos, neg): (Vec<usize>, Vec<usize>) =
            with.into_iter().partition(|i| arena[*i].0.t[&x] > 0);
        for &p in &pos {
            for &n in &neg {
                let (a, b) = (arena[p].0.t[&x], -arena[n].0.t[&x]);
                let s = arena[p].0.scale(b)?.add(&arena[n].0.scale(a)?)?;
                rest.push(push_norm(&mut arena, s, Origin::Comb(p, b, n, a)));
            }
        }
        if rest.len() > MAX_ROWS {
            return None;
        }
        cur = rest;
    }
}

/// The certificate for row `target`: its ancestors in derivation order (each refers only to
/// earlier rows), the hypotheses it uses re-indexed densely, and the variables numbered densely.
fn build_cert(input: &[Lin], arena: &[(Lin, Origin)], target: usize) -> Cert {
    let mut need = vec![false; arena.len()];
    let mut stack = vec![target];
    while let Some(i) = stack.pop() {
        if std::mem::replace(&mut need[i], true) {
            continue;
        }
        match arena[i].1 {
            Origin::Hyp(_) => {}
            Origin::Comb(p, _, q, _) => stack.extend([p, q]),
            Origin::Tight(p, _) => stack.push(p),
        }
    }
    let mut vars: Vec<usize> = Vec::new();
    let mut hyps: Vec<usize> = Vec::new();
    for (i, (_, o)) in arena.iter().enumerate() {
        if need[i] {
            if let Origin::Hyp(h) = o {
                hyps.push(*h);
                vars.extend(input[*h].t.keys().copied());
            }
        }
    }
    vars.sort_unstable();
    vars.dedup();
    let dense = |l: &Lin| CRow {
        c: vars
            .iter()
            .map(|v| l.t.get(v).copied().unwrap_or(0))
            .collect(),
        k: l.c,
    };
    let mut at: HashMap<usize, usize> = HashMap::new();
    let mut steps = Vec::new();
    for (i, (_, o)) in arena.iter().enumerate() {
        if !need[i] {
            continue;
        }
        at.insert(i, steps.len());
        steps.push(match *o {
            Origin::Hyp(h) => CStep::Hyp(hyps.iter().position(|x| *x == h).unwrap_or(0)),
            Origin::Comb(p, a, q, b) => CStep::Comb(at[&p], a, at[&q], b),
            Origin::Tight(p, g) => CStep::Tight(at[&p], g),
        });
    }
    Cert {
        input: hyps.iter().map(|h| dense(&input[*h])).collect(),
        steps,
    }
}

/// What a name stands for while a body is checked.
#[derive(Clone, Debug)]
#[allow(variant_size_differences)]
enum Bind {
    /// an `Int` value: this term
    Int(Lin),
    /// an array: its length atom, and whether its elements are `Int`
    Arr(usize, bool),
    /// anything else (it still shadows a top-level function of the same name)
    Other,
    /// (totality) a part of the value of a function's structural parameter `id`: the value
    /// itself, or (`true`) a strict subterm taken apart by a pattern
    Part(usize, bool),
    /// (totality) a local function: its node name
    Local(String),
}

#[derive(Clone, Default)]
struct Cx {
    env: HashMap<String, Bind>,
    facts: Vec<Lin>,
    /// (totality) values known to be non-zero here (`if b == 0 then … else <here>`)
    ne: Vec<Lin>,
}

/// A predicate's names, bound for one use: an `Int` term or an array length atom.
#[derive(Clone)]
#[allow(variant_size_differences)]
enum PVal {
    Int(Lin),
    Len(usize),
}

pub struct Outcome {
    /// spans of `getArray`/`setArray` applications whose index is proven in bounds
    pub proven: HashSet<Span>,
    /// the certificate of every proof, when collected
    pub certs: Vec<Cert>,
    /// what was not proven about contracts, to be checked at run time (`contracts.rs`)
    pub dynamic: crate::contracts::Dynamic,
    /// every contract obligation met, proven or not
    pub obligations: Vec<crate::contracts::Obligation>,
}

struct Checker<'a> {
    refs: HashMap<String, &'a Refinement>,
    /// top-level function → its parameter types and result type
    sigs: HashMap<String, (Vec<Type>, Type)>,
    /// display name and lower bound of each atom (a length's upper bound is `LEN_MAX`)
    atoms: Vec<(String, i128)>,
    diags: &'a mut Diagnostics,
    proven: HashSet<Span>,
    /// the module's own top-level names: a user `lenArray` is not the builtin
    user: HashSet<String>,
    /// every accepted certificate, when collected (`--emit refine-certs`)
    certs: std::cell::RefCell<Option<Vec<Cert>>>,
    /// totality mode (`total.rs`): what the walk records besides refinement checks
    tot: Option<TotWalk>,
    /// the top-level function being checked
    cur_fn: String,
    /// contract obligations not proven (checked at run time instead)
    dynamic: crate::contracts::Dynamic,
    obligations: Vec<crate::contracts::Obligation>,
    /// functions whose contract `ensures` is not assumed after a call from their own body (it
    /// is checked at run time only after calls from outside)
    no_self: HashSet<String>,
}

/// A size-change measure of a function (`total.rs`): an `Int` quantity, which must be `>= 0`
/// where it strictly decreases, or the structural size of a parameter.
#[derive(Clone, Debug)]
#[allow(variant_size_differences)]
pub enum Measure {
    /// `Σ k·v + c` over the function's values, with its display text
    Int(Vec<(i128, MVal)>, i128, String),
    /// the size of structural parameter `i`
    Struct(usize),
}

/// A value an `Int` measure is made of.
#[derive(Clone, Debug)]
#[allow(variant_size_differences)]
pub enum MVal {
    /// `Int` parameter `i`
    Param(usize),
    /// the length of array parameter `i`
    Len(usize),
    /// a captured value, fixed where the (local) function is defined
    Fixed(Lin),
    /// the length of `String` parameter `i`
    StrLen(usize),
}

/// One call inside a recursive group: which measures of the caller relate to which of the
/// callee, `true` for a strict decrease.
#[derive(Clone, Debug)]
pub struct SctCall {
    pub caller: String,
    pub callee: String,
    pub edges: Vec<(usize, usize, bool)>,
    pub span: Span,
}

/// A use of a function or built-in by a node (a top-level function, or a local `parent$name`).
#[derive(Clone, Debug)]
pub struct TRef {
    pub from: String,
    /// a node, or `builtin:<name>` / `partial:<why>`
    pub to: String,
    pub span: Span,
    /// called with at least its parameters (a use as a value otherwise)
    pub saturated: bool,
}

#[derive(Clone, Debug)]
#[allow(variant_size_differences)]
enum FVal {
    Int(Lin),
    Len(usize),
    /// a structural parameter: its part id and the pattern it was matched with
    Struct(usize, Pat),
    None,
}

struct Frame {
    node: String,
    vals: Vec<FVal>,
    measures: Vec<Measure>,
}

/// A local function's arity, definition span, and each clause's span and patterns.
pub type LocalShape = (usize, Span, Vec<(Span, Vec<Pat>)>);

/// The totality walk's inputs, state and findings.
#[derive(Default)]
pub struct TotWalk {
    /// `parent$local` → the local's parameter types (inference)
    pub where_tys: HashMap<String, Vec<Option<Type>>>,
    /// top-level function → the id of its (top-level) recursive group
    pub top_scc: HashMap<String, usize>,
    /// top-level function → number of parameters its clauses take
    pub arity: HashMap<String, usize>,
    /// top-level function → its parameters' names (from its first clause), for messages
    pub pnames: HashMap<String, Vec<String>>,
    pub calls: Vec<SctCall>,
    pub refs: Vec<TRef>,
    /// node → its measures
    pub measures: HashMap<String, Vec<Measure>>,
    /// local node → (arity, definition span, its clauses' patterns)
    pub locals: HashMap<String, LocalShape>,
    /// spans of clauses whose guards may all fail
    pub guards_open: HashSet<Span>,
    frames: Vec<Frame>,
    /// a whole `String` value (its part id) → the atom of its length
    strlen: HashMap<usize, usize>,
    next_id: usize,
    cur_top: String,
    cur_clause: Span,
}

impl TotWalk {
    pub fn new(
        where_tys: HashMap<String, Vec<Option<Type>>>,
        top_scc: HashMap<String, usize>,
    ) -> TotWalk {
        TotWalk {
            where_tys,
            top_scc,
            ..TotWalk::default()
        }
    }
}

fn is_int(t: &Type) -> bool {
    matches!(t, Type::Con(c) if c == "Int")
}

/// `Array Int` → `Some(true)`, `Array t` → `Some(false)`, otherwise `None`.
fn array_elem_int(t: &Type) -> Option<bool> {
    match t {
        Type::App(f, a) if matches!(&**f, Type::Con(c) if c == "Array") => Some(is_int(a)),
        _ => None,
    }
}

fn split_sig(t: &Type) -> (Vec<Type>, Type) {
    let mut ps = Vec::new();
    let mut t = t;
    while let Type::Arrow { from, to, .. } = t {
        ps.push((**from).clone());
        t = to;
    }
    (ps, t.clone())
}

fn spine(e: &Expr) -> (&Expr, Vec<&Expr>) {
    let mut args = Vec::new();
    let mut h = e;
    while let Expr::App(f, a, _) = h {
        args.push(&**a);
        h = f;
    }
    args.reverse();
    (h, args)
}

fn pat_names(p: &Pat, out: &mut Vec<String>) {
    match p {
        Pat::Var(v, _) => out.push(v.clone()),
        Pat::Con(_, ps, _) | Pat::Tuple(ps, _) => ps.iter().for_each(|q| pat_names(q, out)),
        Pat::Wild(_) | Pat::Int(..) | Pat::Str(..) => {}
    }
}

/// Source text of a predicate, for messages.
pub fn show(e: &Expr) -> String {
    match e {
        Expr::Int(n, _) => n.to_string(),
        Expr::Var(v, _) => v.clone(),
        Expr::BinOp(op, a, b, _) => format!("{} {op} {}", show_arg(a), show_arg(b)),
        Expr::App(..) => {
            let (h, args) = spine(e);
            let mut s = show_arg(h);
            for a in args {
                s.push(' ');
                s.push_str(&show_arg(a));
            }
            s
        }
        Expr::If(c, t, e, _) => match (&**t, &**e) {
            (_, Expr::Con(f, _)) if f == "False" => format!("{} && {}", show(c), show(t)),
            (Expr::Con(tr, _), _) if tr == "True" => format!("{} || {}", show_arg(c), show_arg(e)),
            _ => format!("if {} then {} else {}", show(c), show(t), show(e)),
        },
        Expr::Con(c, _) => c.clone(),
        _ => "…".to_string(),
    }
}

fn show_arg(e: &Expr) -> String {
    match e {
        Expr::BinOp(..) | Expr::App(..) | Expr::If(..) => format!("({})", show(e)),
        _ => show(e),
    }
}

impl Checker<'_> {
    fn fresh(&mut self, name: &str, lo: i128) -> usize {
        self.atoms.push((name.to_string(), lo));
        self.atoms.len() - 1
    }

    /// Do `facts` imply `goal`?
    fn prove(&self, facts: &[Lin], goal: &Formula) -> bool {
        let Some(neg) = negate(goal) else {
            return false;
        };
        let Some(cases) = dnf(&neg) else {
            return false;
        };
        // every case must be refuted by a certificate the independent checker accepts
        cases.into_iter().all(|case| {
            let Some(cert) = refute(&self.rows_for(facts, case)) else {
                return false;
            };
            let ok = check_cert(&cert);
            debug_assert!(
                ok,
                "refute produced a certificate check_cert rejects: {cert:?}"
            );
            if ok {
                if let Some(out) = self.certs.borrow_mut().as_mut() {
                    out.push(cert);
                }
            }
            ok
        })
    }

    /// The facts that share atoms (transitively) with `goal`, plus each atom's machine bounds.
    fn rows_for(&self, facts: &[Lin], goal: Vec<Lin>) -> Vec<Lin> {
        let mut atoms: HashSet<usize> = goal.iter().flat_map(|l| l.t.keys().copied()).collect();
        let mut used = vec![false; facts.len()];
        let mut rows = goal;
        // a fact over no atom is a contradiction (an unreachable branch) or trivially true
        for (i, f) in facts.iter().enumerate() {
            if f.t.is_empty() {
                used[i] = true;
                rows.push(f.clone());
            }
        }
        loop {
            let mut grew = false;
            for (i, f) in facts.iter().enumerate() {
                if !used[i] && f.t.keys().any(|a| atoms.contains(a)) {
                    used[i] = true;
                    atoms.extend(f.t.keys().copied());
                    rows.push(f.clone());
                    grew = true;
                }
            }
            if !grew {
                break;
            }
        }
        for a in atoms {
            let lo = self.atoms.get(a).map_or(MIN, |x| x.1);
            // lengths are the atoms bounded below by 0
            let hi = if lo == 0 { LEN_MAX } else { MAX };
            rows.push(Lin {
                c: -lo,
                t: BTreeMap::from([(a, 1)]),
            });
            rows.push(Lin {
                c: hi,
                t: BTreeMap::from([(a, -1)]),
            });
        }
        rows
    }

    fn in_range(&self, facts: &[Lin], l: &Lin) -> bool {
        let (Some(lo), Some(hi)) = (l.sub(&Lin::konst(MIN)), Lin::konst(MAX).sub(l)) else {
            return false;
        };
        self.prove(facts, &Formula::And(vec![Formula::Ge(lo), Formula::Ge(hi)]))
    }

    fn is_global(cx: &Cx, name: &str) -> bool {
        !cx.env.contains_key(name)
    }

    /// Does `name` here mean the builtin of that name (not a local, not a user definition)?
    fn builtin(&self, cx: &Cx, name: &str) -> bool {
        Self::is_global(cx, name) && !self.user.contains(name)
    }

    /// The length atom of an array-valued expression: an array name, or `setArray` of one
    /// (which keeps its length).
    fn arr_len(&self, cx: &Cx, e: &Expr) -> Option<usize> {
        match e {
            Expr::Var(v, _) => match cx.env.get(v) {
                Some(Bind::Arr(l, _)) => Some(*l),
                _ => None,
            },
            Expr::App(..) => {
                let (h, args) = spine(e);
                match (h, args.as_slice()) {
                    (Expr::Var(f, _), [a, _, _]) if f == "setArray" && self.builtin(cx, f) => {
                        self.arr_len(cx, a)
                    }
                    _ => None,
                }
            }
            _ => None,
        }
    }

    /// The length atom of an array-valued expression, as `arr_len`, or a fresh one for a new
    /// array: `newArray n x` has length `max n 0` (every backend clamps a negative length), so
    /// its length is `>= n` and `>= 0`, and `== n` when `n >= 0` is provable; any other call
    /// returning an `Array` has an unknown length `>= 0`.
    fn arr_value(&mut self, cx: &Cx, e: &Expr, side: &mut Vec<Lin>) -> Option<usize> {
        if let Some(l) = self.arr_len(cx, e) {
            return Some(l);
        }
        let (h, args) = spine(e);
        let Expr::Var(g, _) = h else {
            return None;
        };
        // (`arrayIota n` clamps its length the same way)
        if ((g == "newArray" && args.len() == 2) || (g == "arrayIota" && args.len() == 1))
            && self.builtin(cx, g)
        {
            let l = self.fresh(&format!("len ({})", show(e)), 0);
            if let Some(n) = self.term(cx, args[0], side) {
                let ll = Lin::atom(l);
                if let Some(d) = ll.sub(&n) {
                    side.push(d); // len - n >= 0
                    let mut facts = cx.facts.clone();
                    facts.extend(side.iter().cloned());
                    if self.prove(&facts, &Formula::Ge(n.clone())) {
                        if let Some(nd) = n.sub(&ll) {
                            side.push(nd); // n - len >= 0
                        }
                    }
                }
            }
            return Some(l);
        }
        if !Self::is_global(cx, g) {
            return None;
        }
        let (ps, ret) = self.sigs.get(g)?;
        if args.len() == ps.len() && array_elem_int(ret).is_some() {
            return Some(self.fresh(&format!("len ({})", show(e)), 0));
        }
        None
    }

    /// The value of an evidently-`Int` code expression, in machine semantics: `None` when it is
    /// not evidently `Int`. A sum or product that may overflow, a division, or an opaque call
    /// becomes a fresh atom. `side` receives facts known about fresh atoms (a refined result).
    fn term(&mut self, cx: &Cx, e: &Expr, side: &mut Vec<Lin>) -> Option<Lin> {
        match e {
            Expr::Int(n, _) => Some(Lin::konst(i128::from(*n))),
            Expr::Var(v, _) => match cx.env.get(v) {
                Some(Bind::Int(l)) => Some(l.clone()),
                _ => None,
            },
            Expr::BinOp(op, a, b, _) if matches!(op.as_str(), "+" | "-" | "*") => {
                let ta = self.term(cx, a, side)?;
                let tb = self.term(cx, b, side)?;
                let math = match op.as_str() {
                    "+" => ta.add(&tb),
                    "-" => ta.sub(&tb),
                    _ => match (ta.as_const(), tb.as_const()) {
                        (Some(k), _) => tb.scale(k),
                        (_, Some(k)) => ta.scale(k),
                        _ => None,
                    },
                };
                let mut facts = cx.facts.clone();
                facts.extend(side.iter().cloned());
                match math {
                    Some(m) if self.in_range(&facts, &m) => Some(m),
                    _ => Some(Lin::atom(self.fresh(&show(e), MIN))),
                }
            }
            Expr::BinOp(op, a, b, _) if matches!(op.as_str(), "div" | "mod" | "/" | "rem") => {
                let ta = self.term(cx, a, side)?;
                let tb = self.term(cx, b, side)?;
                let q = self.fresh(&show(e), MIN);
                // `x op k` with `x >= 0` and a constant `k > 0`: floor and truncating division
                // agree there (every backend), so `k*q <= x <= k*q + k - 1` for the quotient
                // and `0 <= r <= k - 1` for the remainder
                if let Some(k) = tb.as_const().filter(|k| *k > 0) {
                    let mut facts = cx.facts.clone();
                    facts.extend(side.iter().cloned());
                    if self.prove(&facts, &Formula::Ge(ta.clone())) {
                        let ql = Lin::atom(q);
                        if op == "mod" || op == "rem" {
                            side.push(ql.clone());
                            if let Some(u) = Lin::konst(k - 1).sub(&ql) {
                                side.push(u);
                            }
                        } else if let Some(kq) = ql.scale(k) {
                            if let (Some(lo), Some(hi)) = (
                                ta.sub(&kq),
                                kq.add(&Lin::konst(k - 1)).and_then(|u| u.sub(&ta)),
                            ) {
                                side.push(lo);
                                side.push(hi);
                            }
                        }
                    }
                }
                Some(Lin::atom(q))
            }
            Expr::App(..) => {
                let (h, args) = spine(e);
                let Expr::Var(g, _) = h else {
                    return None;
                };
                if !Self::is_global(cx, g) {
                    return None;
                }
                if g == "strLen" && args.len() == 1 && self.builtin(cx, g) && self.tot.is_some() {
                    if let Expr::Var(v, _) = args[0] {
                        if let Some(Bind::Part(id, false)) = cx.env.get(v) {
                            let id = *id;
                            return Some(Lin::atom(self.str_len_atom(id, v)));
                        }
                    }
                }
                if g == "lenArray" && args.len() == 1 && self.builtin(cx, g) {
                    return self.arr_value(cx, args[0], side).map(Lin::atom);
                }
                if g == "getArray" && args.len() == 2 && self.builtin(cx, g) {
                    if let Expr::Var(a, _) = args[0] {
                        if matches!(cx.env.get(a), Some(Bind::Arr(_, true))) {
                            return Some(Lin::atom(self.fresh(&show(e), MIN)));
                        }
                    }
                    return None;
                }
                let (ps, ret) = self.sigs.get(g)?.clone();
                if args.len() != ps.len() || !is_int(&ret) {
                    return None;
                }
                let r = self.fresh(&show(e), MIN);
                if let Some(rf) = self.refs.get(g.as_str()).copied() {
                    let vals = self.arg_vals(cx, rf, &ps, &args, side);
                    // a contract `ensures` checked at run time only after calls from outside
                    let unchecked = *g == self.cur_fn && self.no_self.contains(g.as_str());
                    for p in rf
                        .preds
                        .iter()
                        .filter(|p| p.pos == ps.len() && !(p.dynamic && unchecked))
                    {
                        let mut vals = vals.clone();
                        vals.insert(p.binder.clone(), PVal::Int(Lin::atom(r)));
                        if let Some(f) = self.formula(&p.pred, &vals) {
                            conjuncts(&f, side);
                        }
                    }
                }
                Some(Lin::atom(r))
            }
            _ => None,
        }
    }

    /// The predicate names of `rf` bound to a call's arguments.
    fn arg_vals(
        &mut self,
        cx: &Cx,
        rf: &Refinement,
        ps: &[Type],
        args: &[&Expr],
        side: &mut Vec<Lin>,
    ) -> HashMap<String, PVal> {
        let mut vals = HashMap::new();
        for (pos, name) in &rf.names {
            let (Some(arg), Some(ty)) = (args.get(*pos), ps.get(*pos)) else {
                continue;
            };
            let v = if array_elem_int(ty).is_some() {
                PVal::Len(
                    self.arr_value(cx, arg, side)
                        .unwrap_or_else(|| self.fresh(&format!("len ({})", show(arg)), 0)),
                )
            } else {
                PVal::Int(
                    self.term(cx, arg, side)
                        .unwrap_or_else(|| Lin::atom(self.fresh(&show(arg), MIN))),
                )
            };
            vals.insert(name.clone(), v);
        }
        vals
    }

    /// A predicate as a formula (mathematical arithmetic), names bound by `vals`. `None` when
    /// the predicate is outside the language (reported by `well_formed`).
    fn formula(&mut self, e: &Expr, vals: &HashMap<String, PVal>) -> Option<Formula> {
        match e {
            Expr::BinOp(op, a, b, _) => match op.as_str() {
                "&&" => Some(Formula::And(vec![
                    self.formula(a, vals)?,
                    self.formula(b, vals)?,
                ])),
                "||" => Some(Formula::Or(vec![
                    self.formula(a, vals)?,
                    self.formula(b, vals)?,
                ])),
                "<" | "<=" | ">" | ">=" | "==" | "/=" => {
                    let ta = self.pterm(a, vals)?;
                    let tb = self.pterm(b, vals)?;
                    cmp(op, &ta, &tb)
                }
                _ => None,
            },
            Expr::Con(c, _) if c == "True" => Some(Formula::True),
            Expr::Con(c, _) if c == "False" => Some(Formula::False),
            // `a && b` / `a || b` are parsed as `if a then b else False` / `if a then True else b`
            Expr::If(c, t, e, _) => {
                let fc = self.formula(c, vals)?;
                let ft = self.formula(t, vals)?;
                let fe = self.formula(e, vals)?;
                Some(Formula::Or(vec![
                    Formula::And(vec![fc.clone(), ft]),
                    Formula::And(vec![negate(&fc)?, fe]),
                ]))
            }
            _ => None,
        }
    }

    /// An arithmetic term of a predicate (mathematical: no wrapping).
    fn pterm(&mut self, e: &Expr, vals: &HashMap<String, PVal>) -> Option<Lin> {
        match e {
            Expr::Int(n, _) => Some(Lin::konst(i128::from(*n))),
            Expr::Var(v, _) => match vals.get(v)? {
                PVal::Int(l) => Some(l.clone()),
                PVal::Len(_) => None,
            },
            Expr::BinOp(op, a, b, _) => {
                let ta = self.pterm(a, vals)?;
                let tb = self.pterm(b, vals)?;
                match op.as_str() {
                    "+" => ta.add(&tb),
                    "-" => ta.sub(&tb),
                    "*" => match (ta.as_const(), tb.as_const()) {
                        (Some(k), _) => tb.scale(k),
                        (_, Some(k)) => ta.scale(k),
                        // a product of two unknowns: an opaque value
                        _ => Some(Lin::atom(self.fresh(&show(e), MIN))),
                    },
                    _ => None,
                }
            }
            Expr::App(f, a, _) => match (&**f, &**a) {
                (Expr::Var(l, _), Expr::Var(x, _)) if l == "len" || l == "lenArray" => {
                    match vals.get(x)? {
                        PVal::Len(n) => Some(Lin::atom(*n)),
                        PVal::Int(_) => None,
                    }
                }
                _ => None,
            },
            _ => None,
        }
    }

    /// Facts from a condition: those that hold when it is true, and when it is false.
    fn cond(&mut self, cx: &Cx, e: &Expr) -> (Vec<Lin>, Vec<Lin>) {
        match e {
            Expr::BinOp(op, a, b, _) if op == "&&" => {
                let (ta, _) = self.cond(cx, a);
                let (tb, _) = self.cond(cx, b);
                (ta.into_iter().chain(tb).collect(), Vec::new())
            }
            Expr::BinOp(op, a, b, _) if op == "||" => {
                let (_, fa) = self.cond(cx, a);
                let (_, fb) = self.cond(cx, b);
                (Vec::new(), fa.into_iter().chain(fb).collect())
            }
            Expr::BinOp(op, a, b, _)
                if matches!(op.as_str(), "<" | "<=" | ">" | ">=" | "==" | "/=") =>
            {
                let mut side = Vec::new();
                let (Some(ta), Some(tb)) =
                    (self.term(cx, a, &mut side), self.term(cx, b, &mut side))
                else {
                    return (Vec::new(), Vec::new());
                };
                let Some(f) = cmp(op, &ta, &tb) else {
                    return (Vec::new(), Vec::new());
                };
                let mut yes = side.clone();
                conjuncts(&f, &mut yes);
                let mut no = side;
                if let Some(n) = negate(&f) {
                    conjuncts(&n, &mut no);
                }
                (yes, no)
            }
            // `a && b` / `a || b` (parsed as these `if`s)
            Expr::If(a, b, f, _) if matches!(&**f, Expr::Con(c, _) if c == "False") => {
                let (ta, _) = self.cond(cx, a);
                let (tb, _) = self.cond(&Self::with_facts(cx, ta.clone()), b);
                (ta.into_iter().chain(tb).collect(), Vec::new())
            }
            Expr::If(a, t, b, _) if matches!(&**t, Expr::Con(c, _) if c == "True") => {
                let (_, fa) = self.cond(cx, a);
                let (_, fb) = self.cond(&Self::with_facts(cx, fa.clone()), b);
                (Vec::new(), fa.into_iter().chain(fb).collect())
            }
            Expr::App(f, a, _) if matches!(&**f, Expr::Var(n, _) if n == "not" && self.builtin(cx, n)) =>
            {
                let (t, f) = self.cond(cx, a);
                (f, t)
            }
            _ => (Vec::new(), Vec::new()),
        }
    }

    fn with_facts(cx: &Cx, more: Vec<Lin>) -> Cx {
        let mut c = cx.clone();
        c.facts.extend(more);
        c
    }

    /// Check every refined call and array access in `e`.
    fn walk(&mut self, cx: &Cx, e: &Expr) {
        match e {
            Expr::Int(..) | Expr::Float(..) | Expr::Str(..) | Expr::Con(..) => {}
            Expr::Var(v, sp) => {
                if Self::is_global(cx, v) {
                    if let Some(rf) = self.refs.get(v.as_str()) {
                        if rf.preds.iter().all(|p| p.dynamic) {
                            self.value_use(v, *sp);
                        } else {
                            self.unsaturated(v, *sp);
                        }
                    }
                }
                if self.tot.is_some() {
                    self.tot_use(cx, v, &[], *sp);
                }
            }
            Expr::App(_, _, sp) => {
                let (h, args) = spine(e);
                if self.tot.is_some() {
                    if let Expr::Var(g, _) = h {
                        self.tot_use(cx, g, &args, *sp);
                    }
                }
                match h {
                    Expr::Var(g, hsp) if Self::is_global(cx, g) => {
                        if let Some(rf) = self.refs.get(g.as_str()).copied() {
                            self.check_call(cx, g, rf, &args, *hsp, *sp);
                        } else if self.builtin(cx, g)
                            && ((g == "getArray" && args.len() == 2)
                                || (g == "setArray" && args.len() == 3))
                        {
                            self.check_access(cx, &args, *sp);
                        }
                    }
                    Expr::Var(..) if self.tot.is_some() => {}
                    _ => self.walk(cx, h),
                }
                // `parFor a (\i x -> …)`: the kernel's index is in `[0, len a)`
                if let (Expr::Var(g, _), [arr, Expr::Lam(ps, body, _)]) = (h, args.as_slice()) {
                    if g == "parFor" && self.builtin(cx, g) {
                        if let Some(Pat::Var(i, _)) = ps.first() {
                            self.walk(cx, arr);
                            let mut side = Vec::new();
                            let len = self.arr_value(cx, arr, &mut side);
                            let mut inner = Self::with_facts(cx, side);
                            let mut names = Vec::new();
                            ps.iter().for_each(|p| pat_names(p, &mut names));
                            for n in names {
                                inner.env.insert(n, Bind::Other);
                            }
                            let at = self.fresh(i, MIN);
                            let ix = Lin::atom(at);
                            inner.facts.push(ix.clone()); // i >= 0
                            if let Some(hi) = len
                                .and_then(|l| Lin::atom(l).sub(&ix))
                                .and_then(|d| d.add(&Lin::konst(-1)))
                            {
                                inner.facts.push(hi); // len a - 1 - i >= 0
                            }
                            inner.env.insert(i.clone(), Bind::Int(ix));
                            self.walk(&inner, body);
                            return;
                        }
                    }
                }
                for a in args {
                    self.walk(cx, a);
                }
            }
            Expr::BinOp(op, a, b, sp) => {
                if self.tot.is_some() {
                    self.tot_binop(cx, op, b, *sp);
                }
                self.walk(cx, a);
                let (t, f) = self.cond(cx, a);
                let cb = match op.as_str() {
                    "&&" => Self::with_facts(cx, t),
                    "||" => Self::with_facts(cx, f),
                    _ => cx.clone(),
                };
                self.walk(&cb, b);
            }
            Expr::If(c, t, f, _) => {
                self.walk(cx, c);
                let (yes, no) = self.cond(cx, c);
                let (mut ct, mut cf) = (Self::with_facts(cx, yes), Self::with_facts(cx, no));
                if self.tot.is_some() {
                    let (ny, nn) = self.ne_of(cx, c);
                    ct.ne.extend(ny);
                    cf.ne.extend(nn);
                }
                self.walk(&ct, t);
                self.walk(&cf, f);
            }
            Expr::Let(fs, body, _) => {
                let inner = self.bind_locals(cx, fs);
                self.walk(&inner, body);
            }
            Expr::Case(scrut, arms, _) => {
                self.walk(cx, scrut);
                let mut side = Vec::new();
                let ts = self.term(cx, scrut, &mut side);
                let part = match &**scrut {
                    Expr::Var(v, _) => match cx.env.get(v) {
                        Some(Bind::Part(id, _)) => Some(*id),
                        _ => None,
                    },
                    _ => None,
                };
                for (p, body) in arms {
                    let mut arm = Self::bind_pat(cx, p, ts.as_ref(), &side);
                    if let (Some(id), true) = (part, self.tot.is_some()) {
                        let mut names = Vec::new();
                        pat_names(p, &mut names);
                        let whole = matches!(p, Pat::Var(..));
                        for n in names {
                            arm.env.insert(n, Bind::Part(id, !whole));
                        }
                    }
                    self.walk(&arm, body);
                }
            }
            Expr::Tuple(es, _) => es.iter().for_each(|x| self.walk(cx, x)),
            Expr::RecordCon(_, fs, _) => fs.iter().for_each(|(_, x)| self.walk(cx, x)),
            Expr::RecordUpd(b, fs, _) => {
                self.walk(cx, b);
                fs.iter().for_each(|(_, x)| self.walk(cx, x));
            }
            Expr::Lam(ps, body, _) => {
                let mut inner = cx.clone();
                let mut names = Vec::new();
                ps.iter().for_each(|p| pat_names(p, &mut names));
                for n in names {
                    inner.env.insert(n, Bind::Other);
                }
                self.walk(&inner, body);
            }
        }
    }

    /// A `case` arm's scope: its pattern's names shadow; an `Int` literal pattern on an `Int`
    /// scrutinee is a fact, and a variable pattern names the scrutinee's value.
    fn bind_pat(cx: &Cx, p: &Pat, scrut: Option<&Lin>, side: &[Lin]) -> Cx {
        let mut arm = Self::with_facts(cx, side.to_vec());
        let mut names = Vec::new();
        pat_names(p, &mut names);
        for n in names {
            arm.env.insert(n, Bind::Other);
        }
        match (p, scrut) {
            (Pat::Int(k, _), Some(t)) => {
                if let Some(f) = cmp("==", t, &Lin::konst(i128::from(*k))) {
                    conjuncts(&f, &mut arm.facts);
                }
            }
            (Pat::Var(v, _), Some(t)) => {
                arm.env.insert(v.clone(), Bind::Int(t.clone()));
            }
            _ => {}
        }
        arm
    }

    /// The scope after `let`/`where` bindings: every name shadows; a value binding of an
    /// evidently-`Int` expression or an array names its value. A local function's body is
    /// checked with `cx`'s facts: a `let` function is callable only inside the `let` (on the
    /// same path), and a `where` one is bound at clause entry, where `cx` holds only the
    /// clause's own refinements, true throughout the clause.
    fn bind_locals(&mut self, cx: &Cx, fs: &[Func]) -> Cx {
        let mut inner = cx.clone();
        let nodes: Vec<Option<String>> = fs.iter().map(|f| self.tot_local(f)).collect();
        for (f, node) in fs.iter().zip(&nodes) {
            let b = match node {
                Some(n) => Bind::Local(n.clone()),
                None => Bind::Other,
            };
            inner.env.insert(f.name.clone(), b);
        }
        for (f, node) in fs.iter().zip(&nodes) {
            let value = f.clauses.len() == 1 && f.clauses[0].pats.is_empty();
            let scope = inner.clone();
            if let Some(n) = node {
                self.tot_measures_local(&scope, f, n);
            }
            for c in &f.clauses {
                let mut cs = scope.clone();
                let mut names = Vec::new();
                c.pats.iter().for_each(|p| pat_names(p, &mut names));
                for n in names {
                    cs.env.insert(n, Bind::Other);
                }
                if let Some(n) = node {
                    let tys = self
                        .tot
                        .as_ref()
                        .and_then(|t| t.where_tys.get(&local_key(n)).cloned())
                        .unwrap_or_default();
                    let tys: Vec<Option<Type>> = (0..c.pats.len())
                        .map(|i| tys.get(i).cloned().flatten())
                        .collect();
                    self.tot_enter(&mut cs, n, &c.pats, &tys, c.span);
                }
                let cs = self.bind_locals(&cs, &c.wher);
                self.walk_body(&cs, &c.body);
                if node.is_some() {
                    if let Some(t) = self.tot.as_mut() {
                        t.frames.pop();
                    }
                }
            }
            if value {
                if let Body::Plain(e) = &f.clauses[0].body {
                    let mut side = Vec::new();
                    if let Some(t) = self.term(&inner, e, &mut side) {
                        inner.facts.extend(side);
                        inner.env.insert(f.name.clone(), Bind::Int(t));
                    } else if let Some(l) = self.arr_value(&inner, e, &mut side) {
                        inner.facts.extend(side);
                        inner.env.insert(f.name.clone(), Bind::Arr(l, false));
                    }
                }
            }
        }
        inner
    }

    fn walk_body(&mut self, cx: &Cx, b: &Body) {
        match b {
            Body::Plain(e) => self.walk(cx, e),
            Body::Guarded(arms) => {
                let mut cur = cx.clone();
                let mut closed = false;
                for (g, r) in arms {
                    self.walk(&cur, g);
                    let (yes, no) = self.cond(&cur, g);
                    let mut arm = Self::with_facts(&cur, yes);
                    if self.tot.is_some() {
                        let (ny, nn) = self.ne_of(&cur, g);
                        arm.ne.extend(ny);
                        cur.ne.extend(nn);
                    }
                    self.walk(&arm, r);
                    cur.facts.extend(no);
                    closed = matches!(g, Expr::Var(n, _) if n == "otherwise")
                        || matches!(g, Expr::Con(c, _) if c == "True");
                }
                // totality: may every guard fail (and the clause fall through)?
                if self.tot.is_some() && !closed && !self.absurd(&cur.facts) {
                    if let Some(t) = self.tot.as_mut() {
                        t.guards_open.insert(t.cur_clause);
                    }
                }
            }
        }
    }

    /// A contract function used as a value: every call through it is checked at run time.
    fn value_use(&mut self, g: &str, sp: Span) {
        self.dynamic.values.insert(sp);
        self.obligations.push(crate::contracts::Obligation {
            func: g.to_string(),
            what: "used as a value (its whole contract)".to_string(),
            span: sp,
            proven: false,
        });
    }

    fn unsaturated(&mut self, g: &str, sp: Span) {
        self.diags.push(
            Diagnostic::error(
                "AX0602",
                format!("`{g}` has refined parameters and must be called with all of them"),
            )
            .label(sp.0, sp.1, "used here without its refined arguments")
            .with_help(
                "a refinement is checked at each call, against the arguments given there; pass \
                 the function to another one through a lambda that calls it in full",
            ),
        );
    }

    fn check_call(
        &mut self,
        cx: &Cx,
        g: &str,
        rf: &Refinement,
        args: &[&Expr],
        hsp: Span,
        sp: Span,
    ) {
        let Some((ps, _)) = self.sigs.get(g).cloned() else {
            return;
        };
        let need = rf
            .preds
            .iter()
            .filter(|p| p.pos < ps.len())
            .flat_map(|p| {
                // every name the predicate mentions must be supplied
                rf.names
                    .iter()
                    .filter(|(_, n)| mentions(&p.pred, n) || *n == p.binder)
                    .map(|(i, _)| *i + 1)
                    .collect::<Vec<_>>()
            })
            .max()
            .unwrap_or(0);
        if args.len() < need {
            if rf.preds.iter().all(|p| p.dynamic) {
                self.value_use(g, hsp);
                return;
            }
            self.unsaturated(g, (hsp.0, sp.1));
            return;
        }
        let mut side = Vec::new();
        let vals = self.arg_vals(cx, rf, &ps, args, &mut side);
        let mut facts = cx.facts.clone();
        facts.extend(side);
        for (k, p) in rf
            .preds
            .iter()
            .enumerate()
            .filter(|(_, p)| p.pos < ps.len())
        {
            let goal = self.formula(&p.pred, &vals);
            if p.dynamic {
                let ok = goal.as_ref().is_some_and(|g| self.prove(&facts, g));
                self.obligations.push(crate::contracts::Obligation {
                    func: g.to_string(),
                    what: format!("requires `{}`", show(&p.pred)),
                    span: sp,
                    proven: ok,
                });
                if !ok {
                    let e = self
                        .dynamic
                        .calls
                        .entry(sp)
                        .or_insert_with(|| (g.to_string(), Vec::new()));
                    e.1.push(k);
                }
                continue;
            }
            let Some(goal) = goal else {
                continue;
            };
            if !self.prove(&facts, &goal) {
                let asp = args[p.pos].span();
                let known = self.known(&facts, &goal);
                let mut d = Diagnostic::error(
                    "AX0600",
                    format!(
                        "cannot prove `{}` for the argument `{}` of `{g}`",
                        show(&p.pred),
                        p.binder
                    ),
                )
                .label(asp.0, asp.1, format!("must satisfy `{}`", show(&p.pred)));
                d = d.with_help(known);
                self.diags.push(d);
            }
        }
    }

    fn check_access(&mut self, cx: &Cx, args: &[&Expr], sp: Span) {
        let mut side = Vec::new();
        let (Some(len), Some(i)) = (
            self.arr_value(cx, args[0], &mut side),
            self.term(cx, args[1], &mut side),
        ) else {
            return;
        };
        let mut facts = cx.facts.clone();
        facts.extend(side);
        let (Some(lo), Some(hi)) = (
            Some(i.clone()),
            Lin::atom(len).sub(&i).and_then(|d| d.add(&Lin::konst(-1))),
        ) else {
            return;
        };
        if self.prove(
            &facts,
            &Formula::And(vec![Formula::Ge(lo), Formula::Ge(hi)]),
        ) {
            self.proven.insert(sp);
        }
    }

    /// A help line listing the facts that bear on a failed goal.
    fn known(&self, facts: &[Lin], goal: &Formula) -> String {
        let mut gl = Vec::new();
        conjuncts(goal, &mut gl);
        if let Formula::Or(fs) = goal {
            fs.iter().for_each(|f| conjuncts(f, &mut gl));
        }
        let rows = self.rows_for(facts, gl.clone());
        // the facts themselves, not the machine bounds `rows_for` adds to every atom
        let shown: Vec<String> = rows
            .iter()
            .filter(|r| !gl.contains(r) && r.c.abs() < (1 << 62))
            .take(8)
            .map(|r| self.show_row(r))
            .collect();
        if shown.is_empty() {
            "nothing is known here about these values; add a condition (`if i < len a then …`) or \
             a refinement on the caller's parameters"
                .to_string()
        } else {
            format!("known here: {}", shown.join(", "))
        }
    }

    fn show_row(&self, r: &Lin) -> String {
        let mut pos = Vec::new();
        let mut neg = Vec::new();
        for (a, k) in &r.t {
            let name = self.atoms.get(*a).map_or("?", |x| x.0.as_str());
            let s = if k.abs() == 1 {
                name.to_string()
            } else {
                format!("{}*{name}", k.abs())
            };
            if *k > 0 {
                pos.push(s);
            } else {
                neg.push(s);
            }
        }
        let lhs = if pos.is_empty() {
            "0".to_string()
        } else {
            pos.join(" + ")
        };
        let mut rhs = neg.join(" + ");
        // Σpos + c >= Σneg  ⇔  Σneg <= Σpos + c
        let c = r.c;
        if rhs.is_empty() {
            rhs = "0".to_string();
        }
        match c.cmp(&0) {
            std::cmp::Ordering::Equal => format!("{rhs} <= {lhs}"),
            std::cmp::Ordering::Greater => format!("{rhs} <= {lhs} + {c}"),
            std::cmp::Ordering::Less => format!("{rhs} <= {lhs} - {}", -c),
        }
    }

    /// Check one top-level function: its body under its own refinements, and its refined
    /// result at each return.
    fn check_func(&mut self, f: &Func) {
        let (ps, ret) = f
            .sig
            .as_ref()
            .map(split_sig)
            .unwrap_or((Vec::new(), Type::Unit));
        let rf = self.refs.get(f.name.as_str()).copied();
        self.cur_fn = f.name.clone();
        for c in &f.clauses {
            let mut cx = Cx::default();
            // each parameter position's value (named or not)
            let mut pvals: HashMap<usize, PVal> = HashMap::new();
            for (i, ty) in ps.iter().enumerate() {
                let pat = c.pats.get(i);
                let label = match pat {
                    Some(Pat::Var(v, _)) => v.clone(),
                    _ => format!("argument {}", i + 1),
                };
                if is_int(ty) {
                    let t = match pat {
                        Some(Pat::Int(k, _)) => Lin::konst(i128::from(*k)),
                        _ => Lin::atom(self.fresh(&label, MIN)),
                    };
                    if let Some(Pat::Var(v, _)) = pat {
                        cx.env.insert(v.clone(), Bind::Int(t.clone()));
                    }
                    pvals.insert(i, PVal::Int(t));
                } else if let Some(int_elems) = array_elem_int(ty) {
                    let l = self.fresh(&format!("len {label}"), 0);
                    if let Some(Pat::Var(v, _)) = pat {
                        cx.env.insert(v.clone(), Bind::Arr(l, int_elems));
                    }
                    pvals.insert(i, PVal::Len(l));
                }
            }
            for p in &c.pats {
                let mut names = Vec::new();
                pat_names(p, &mut names);
                for n in names {
                    cx.env.entry(n).or_insert(Bind::Other);
                }
            }
            let mut vals: HashMap<String, PVal> = HashMap::new();
            if let Some(rf) = rf {
                for (pos, name) in &rf.names {
                    if let Some(v) = pvals.get(pos) {
                        vals.insert(name.clone(), v.clone());
                    }
                }
                for p in rf.preds.iter().filter(|p| p.pos < ps.len()) {
                    if let Some(fm) = self.formula(&p.pred, &vals) {
                        conjuncts(&fm, &mut cx.facts);
                    }
                }
                // a non-zero fact (`requires d /= 0`) is a disjunction, not a row: keep it with
                // the others a division may use (totality)
                if self.tot.is_some() {
                    let mut pcx = Cx::default();
                    for (n, v) in &vals {
                        let b = match v {
                            PVal::Int(l) => Bind::Int(l.clone()),
                            PVal::Len(l) => Bind::Arr(*l, false),
                        };
                        pcx.env.insert(n.clone(), b);
                    }
                    for p in rf.preds.iter().filter(|p| p.pos < ps.len()) {
                        let (yes, _) = self.ne_of(&pcx, &p.pred);
                        cx.ne.extend(yes);
                    }
                }
            }
            if self.tot.is_some() {
                let tys: Vec<Option<Type>> =
                    (0..c.pats.len()).map(|i| ps.get(i).cloned()).collect();
                let mut ints: Vec<Option<Lin>> = vec![None; c.pats.len()];
                let mut lens: Vec<Option<usize>> = vec![None; c.pats.len()];
                for (i, v) in &pvals {
                    match v {
                        PVal::Int(l) if *i < ints.len() => ints[*i] = Some(l.clone()),
                        PVal::Len(l) if *i < lens.len() => lens[*i] = Some(*l),
                        _ => {}
                    }
                }
                self.tot_frame_top(&mut cx, f, &c.pats, &tys, &ints, &lens, c.span);
            }
            let cx = self.bind_locals(&cx, &c.wher);
            self.walk_body(&cx, &c.body);
            if self.tot.is_some() {
                if let Some(t) = self.tot.as_mut() {
                    t.frames.pop();
                }
            }
            if let Some(rf) = rf {
                let res: Vec<&RefinePred> = rf.preds.iter().filter(|p| p.pos == ps.len()).collect();
                if !res.is_empty() && is_int(&ret) {
                    match &c.body {
                        Body::Plain(e) => self.check_returns(&cx, e, &res, &vals),
                        Body::Guarded(arms) => {
                            let mut cur = cx.clone();
                            for (g, r) in arms {
                                let (yes, no) = self.cond(&cur, g);
                                self.check_returns(&Self::with_facts(&cur, yes), r, &res, &vals);
                                cur.facts.extend(no);
                            }
                        }
                    }
                }
            }
        }
    }

    /// Prove a refined result at every return of `e`.
    fn check_returns(
        &mut self,
        cx: &Cx,
        e: &Expr,
        res: &[&RefinePred],
        vals: &HashMap<String, PVal>,
    ) {
        match e {
            Expr::If(c, t, f, _) => {
                let (yes, no) = self.cond(cx, c);
                self.check_returns(&Self::with_facts(cx, yes), t, res, vals);
                self.check_returns(&Self::with_facts(cx, no), f, res, vals);
            }
            Expr::Let(fs, body, _) => {
                let inner = self.bind_locals_quiet(cx, fs);
                self.check_returns(&inner, body, res, vals);
            }
            Expr::Case(scrut, arms, _) => {
                let mut side = Vec::new();
                let ts = self.term(cx, scrut, &mut side);
                for (p, body) in arms {
                    let arm = Self::bind_pat(cx, p, ts.as_ref(), &side);
                    self.check_returns(&arm, body, res, vals);
                }
            }
            _ => {
                let mut side = Vec::new();
                let t = self
                    .term(cx, e, &mut side)
                    .unwrap_or_else(|| Lin::atom(self.fresh(&show(e), MIN)));
                let mut facts = cx.facts.clone();
                facts.extend(side);
                for p in res {
                    let mut v = vals.clone();
                    v.insert(p.binder.clone(), PVal::Int(t.clone()));
                    let goal = self.formula(&p.pred, &v);
                    if p.dynamic {
                        let ok = goal.as_ref().is_some_and(|g| self.prove(&facts, g));
                        self.obligations.push(crate::contracts::Obligation {
                            func: self.cur_fn.clone(),
                            what: format!("ensures `{}`", show(&p.pred)),
                            span: e.span(),
                            proven: ok,
                        });
                        if !ok {
                            self.dynamic.ensures.insert(self.cur_fn.clone());
                        }
                        continue;
                    }
                    let Some(goal) = goal else {
                        continue;
                    };
                    if !self.prove(&facts, &goal) {
                        let sp = e.span();
                        let known = self.known(&facts, &goal);
                        self.diags.push(
                            Diagnostic::error(
                                "AX0600",
                                format!("cannot prove the result refinement `{}`", show(&p.pred)),
                            )
                            .label(
                                sp.0,
                                sp.1,
                                format!("this result must satisfy `{}`", show(&p.pred)),
                            )
                            .with_help(known),
                        );
                    }
                }
            }
        }
    }

    /// `bind_locals` without re-checking the bindings' bodies (already walked).
    fn bind_locals_quiet(&mut self, cx: &Cx, fs: &[Func]) -> Cx {
        let mut quiet = Diagnostics::new();
        std::mem::swap(self.diags, &mut quiet);
        let r = self.bind_locals(cx, fs);
        std::mem::swap(self.diags, &mut quiet);
        r
    }
}

/// The leftmost string literal of a `strAppend` chain (a contract check's message).
fn first_str(e: &Expr) -> Option<&str> {
    match e {
        Expr::Str(s, _) => Some(s),
        Expr::App(..) => spine(e).1.first().and_then(|a| first_str(a)),
        _ => None,
    }
}

/// `a op b` as a formula (mathematical).
fn cmp(op: &str, a: &Lin, b: &Lin) -> Option<Formula> {
    let ge = |x: &Lin, y: &Lin, k: i128| -> Option<Formula> {
        // x - y + k >= 0
        Some(Formula::Ge(x.sub(y)?.add(&Lin::konst(k))?))
    };
    Some(match op {
        "<=" => ge(b, a, 0)?,
        "<" => ge(b, a, -1)?,
        ">=" => ge(a, b, 0)?,
        ">" => ge(a, b, -1)?,
        "==" => Formula::And(vec![ge(a, b, 0)?, ge(b, a, 0)?]),
        "/=" => Formula::Or(vec![ge(a, b, -1)?, ge(b, a, -1)?]),
        _ => return None,
    })
}

fn mentions(e: &Expr, name: &str) -> bool {
    match e {
        Expr::Var(v, _) => v == name,
        Expr::BinOp(_, a, b, _) | Expr::App(a, b, _) => mentions(a, name) || mentions(b, name),
        Expr::If(c, t, e, _) => mentions(c, name) || mentions(t, name) || mentions(e, name),
        _ => false,
    }
}

/// Is the predicate inside the refinement language, over names that exist?
fn well_formed(rf: &Refinement, p: &RefinePred, ps: &[Type], diags: &mut Diagnostics) -> bool {
    let types: HashMap<&str, &Type> = rf
        .names
        .iter()
        .filter_map(|(i, n)| ps.get(*i).map(|t| (n.as_str(), t)))
        .collect();
    let result = p.pos == ps.len();
    let mut err = |sp: Span, msg: String| {
        diags.push(
            Diagnostic::error("AX0601", format!("ill-formed refinement: {msg}"))
                .label(sp.0, sp.1, "here")
                .with_help(
                    "a refinement compares Int expressions (`+ - *`, literals, `len a` of an array \
                     parameter) with `< <= > >= == /=`, joined by `&&`/`||`",
                ),
        );
        false
    };
    if !is_int(&p.ty) {
        return err(p.span, "only `Int` values can be refined".to_string());
    }
    if p.pos > ps.len() {
        return err(p.span, "the signature has fewer parameters".to_string());
    }
    fn walk(
        e: &Expr,
        bool_pos: bool,
        types: &HashMap<&str, &Type>,
        binder: &str,
        result: bool,
        err: &mut dyn FnMut(Span, String) -> bool,
    ) -> bool {
        match e {
            Expr::BinOp(op, a, b, _) if bool_pos && matches!(op.as_str(), "&&" | "||") => {
                walk(a, true, types, binder, result, err)
                    && walk(b, true, types, binder, result, err)
            }
            Expr::BinOp(op, a, b, _)
                if bool_pos && matches!(op.as_str(), "<" | "<=" | ">" | ">=" | "==" | "/=") =>
            {
                walk(a, false, types, binder, result, err)
                    && walk(b, false, types, binder, result, err)
            }
            Expr::BinOp(op, a, b, _) if !bool_pos && matches!(op.as_str(), "+" | "-" | "*") => {
                walk(a, false, types, binder, result, err)
                    && walk(b, false, types, binder, result, err)
            }
            Expr::Con(c, _) if bool_pos && (c == "True" || c == "False") => true,
            Expr::If(c, t, e, _) if bool_pos => {
                walk(c, true, types, binder, result, err)
                    && walk(t, true, types, binder, result, err)
                    && walk(e, true, types, binder, result, err)
            }
            Expr::Int(..) if !bool_pos => true,
            Expr::Var(v, sp) if !bool_pos => {
                if result && v == binder {
                    return true;
                }
                match types.get(v.as_str()) {
                    Some(t) if is_int(t) => true,
                    Some(_) => err(
                        *sp,
                        format!("`{v}` is not an `Int` (use `len {v}` for an array)"),
                    ),
                    None => err(
                        *sp,
                        format!("`{v}` is not a parameter named in this signature"),
                    ),
                }
            }
            Expr::App(f, a, sp) if !bool_pos => match (&**f, &**a) {
                (Expr::Var(l, _), Expr::Var(x, _)) if l == "len" || l == "lenArray" => {
                    match types.get(x.as_str()) {
                        Some(t) if array_elem_int(t).is_some() => true,
                        _ => err(*sp, format!("`{x}` is not an array parameter")),
                    }
                }
                _ => err(
                    *sp,
                    "only `len a` may be applied in a refinement".to_string(),
                ),
            },
            other => err(
                other.span(),
                "this is not part of the refinement language".to_string(),
            ),
        }
    }
    walk(&p.pred, true, &types, &p.binder, result, &mut err)
}

/// `check`, also returning every proof's certificate when `collect`.
pub fn check_with(module: &Module, diags: &mut Diagnostics, collect: bool) -> Outcome {
    check_full(module, diags, collect, &HashSet::new())
}

/// `check_with`, not assuming the contract `ensures` of the functions in `no_self` after their
/// calls from their own bodies.
pub fn check_full(
    module: &Module,
    diags: &mut Diagnostics,
    collect: bool,
    no_self: &HashSet<String>,
) -> Outcome {
    let mut sigs = HashMap::new();
    for f in &module.funcs {
        if let Some(s) = &f.sig {
            sigs.insert(f.name.clone(), split_sig(s));
        }
    }
    let mut refs: HashMap<String, &Refinement> = HashMap::new();
    for rf in &module.refinements {
        let Some((ps, _)) = sigs.get(&rf.func) else {
            continue;
        };
        if rf.preds.iter().all(|p| well_formed(rf, p, ps, diags)) && !rf.preds.is_empty() {
            refs.insert(rf.func.clone(), rf);
        }
    }
    let mut ck = Checker {
        refs,
        sigs,
        atoms: Vec::new(),
        diags,
        proven: HashSet::new(),
        user: module.funcs.iter().map(|f| f.name.clone()).collect(),
        certs: std::cell::RefCell::new(collect.then(Vec::new)),
        tot: None,
        cur_fn: String::new(),
        dynamic: crate::contracts::Dynamic::default(),
        obligations: Vec::new(),
        no_self: no_self.clone(),
    };
    // a program with no refinements still gets its provable array accesses
    for f in &module.funcs {
        ck.check_func(f);
    }
    for inst in &module.instances {
        for m in &inst.methods {
            ck.check_func(m);
        }
    }
    let certs = ck.certs.take().unwrap_or_default();
    Outcome {
        proven: ck.proven,
        certs,
        dynamic: ck.dynamic,
        obligations: ck.obligations,
    }
}

/// Each certificate as a Lean `example` checked by `AxionRefine.check` (`metatheory/refine-trace.sh`).
pub fn certs_lean(certs: &[Cert]) -> String {
    let row = |r: &CRow| {
        let c: Vec<String> = r.c.iter().map(i128::to_string).collect();
        format!("⟨[{}], {}⟩", c.join(", "), r.k)
    };
    let step = |s: &CStep| match *s {
        CStep::Hyp(i) => format!(".hyp {i}"),
        CStep::Comb(i, a, j, b) => format!(".comb {i} {a} {j} {b}"),
        CStep::Tight(i, g) => format!(".tight {i} {g}"),
    };
    let mut out = format!("-- refine-certs: {} certificate(s)\n", certs.len());
    for c in certs {
        let input: Vec<String> = c.input.iter().map(row).collect();
        let steps: Vec<String> = c.steps.iter().map(step).collect();
        out.push_str(&format!(
            "example : AxionRefine.check [{}] [{}] = true := by rfl\n",
            input.join(", "),
            steps.join(", ")
        ));
    }
    out
}

/// Emit each array access `check` proved in bounds without its check: its Core `let` (or tail
/// `ret`) carries the access's source span. Generated functions are left alone, and a span that
/// matches nothing leaves the access checked.
pub fn apply_proven(fns: &mut [crate::core::CoreFn], proven: &[Span]) {
    use crate::core::{Op, Rhs, Term};
    if proven.is_empty() {
        return;
    }
    let set: HashSet<Span> = proven.iter().copied().collect();
    fn op(o: &mut Op, sp: Span, set: &HashSet<Span>) {
        if let Op::RtCall { func, .. } = o {
            if sp.1 > sp.0 && set.contains(&sp) {
                if func == "axion_array_get" {
                    *func = crate::bce::GET_NOBC.to_string();
                } else if func == "axion_array_set" {
                    *func = crate::bce::SET_NOBC.to_string();
                }
            }
        }
    }
    fn rhs(r: &mut Rhs, sp: Span, set: &HashSet<Span>) {
        match r {
            Rhs::Op(o) => op(o, sp, set),
            Rhs::If(_, t, e) => {
                term(t, set);
                term(e, set);
            }
            Rhs::Case(_, arms) => arms.iter_mut().for_each(|(_, b)| term(b, set)),
        }
    }
    fn term(t: &mut Term, set: &HashSet<Span>) {
        match t {
            Term::Let(_, r, sp, k) => {
                rhs(r, *sp, set);
                term(k, set);
            }
            Term::Drop(_, _, _, _, k) => term(k, set),
            Term::Ret(r, sp) => rhs(r, *sp, set),
        }
    }
    for f in fns.iter_mut() {
        if !f.name.starts_with("axion_") {
            term(&mut f.body, &set);
        }
    }
}

// --- totality mode (`total.rs`) ---

/// Built-ins that always return normally: they cannot abort, loop or end the program. Anything
/// else a total function uses must be proven safe at the use (`getArray`, `div`, SIMD lanes …)
/// or is partial.
const TOTAL_BUILTINS: &[&str] = &[
    "parFor",
    "True",
    "False",
    "otherwise",
    "nullPtr",
    "+",
    "-",
    "*",
    "==",
    "<",
    ">",
    "<=",
    ">=",
    "/=",
    "&&",
    "||",
    "not",
    ".&.",
    ".|.",
    "xor",
    "shiftL",
    "shiftR",
    "abs",
    "+.",
    "-.",
    "*.",
    "/.",
    "<.",
    ">.",
    "==.",
    "sqrt",
    "floor",
    "toFloat",
    "truncate",
    "intToPtr",
    "ptrToInt",
    "handleAddr",
    "imperative",
    "showInt",
    "showFloat",
    "showInteger",
    "strAppend",
    "strLen",
    "charAt",
    "substr",
    "strCmp",
    "chr",
    "putStr",
    "putStrLn",
    "ePutStr",
    "ePutStrLn",
    "fromInt",
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
    "randHex",
    "getArgs",
    "getArg",
    "fileOpenRaw",
    "fileErrno",
    "fileSize",
    "fileRead",
    "fileClose",
    "newBuffer",
    "bufIota",
    "sumBytes",
    "bufLen",
    "bufPtr",
    "bufPtrN",
    "free",
    "newArray",
    "lenArray",
    "arrayIota",
    "arraySum",
    "newI8Array",
    "lenI8",
    "i8Iota",
    "i8Sum",
    "newI32Array",
    "lenI32",
    "i32Iota",
    "i32Sum",
    "newTritVec",
    "lenTritVec",
    "tritVecIota",
    "withArena",
    "withSubArena",
    "allocateCell",
    "promote",
    "arena_mark",
    "arena_release",
    "bound",
    "spawn",
    "send",
    "recv",
    "newChannel",
    "select",
    "offer",
    "cancel",
    "close",
    "join",
    "split",
    "connect",
    "pipe3",
    "parMap",
    "++#str",
    "+#I",
    "-#I",
    "*#I",
    "==#I",
    "<#I",
    ">#I",
];

/// The `parent$name` key inference records a local's types under (a node name without the
/// `#k` that tells two same-named locals of one function apart).
fn local_key(node: &str) -> String {
    node.split('#').next().unwrap_or(node).to_string()
}

/// The names a function's clauses mention (an over-approximation of its free variables).
fn mentioned(f: &Func, out: &mut HashSet<String>) {
    fn expr(e: &Expr, out: &mut HashSet<String>) {
        match e {
            Expr::Var(v, _) => {
                out.insert(v.clone());
            }
            Expr::App(a, b, _) | Expr::BinOp(_, a, b, _) => {
                expr(a, out);
                expr(b, out);
            }
            Expr::If(c, t, f, _) => {
                expr(c, out);
                expr(t, out);
                expr(f, out);
            }
            Expr::Let(fs, b, _) => {
                fs.iter().for_each(|f| mentioned(f, out));
                expr(b, out);
            }
            Expr::Case(s, arms, _) => {
                expr(s, out);
                arms.iter().for_each(|(_, b)| expr(b, out));
            }
            Expr::Tuple(es, _) => es.iter().for_each(|x| expr(x, out)),
            Expr::RecordCon(_, fs, _) => fs.iter().for_each(|(_, x)| expr(x, out)),
            Expr::RecordUpd(b, fs, _) => {
                expr(b, out);
                fs.iter().for_each(|(_, x)| expr(x, out));
            }
            Expr::Lam(_, b, _) => expr(b, out),
            Expr::Int(..) | Expr::Float(..) | Expr::Str(..) | Expr::Con(..) => {}
        }
    }
    for c in &f.clauses {
        match &c.body {
            Body::Plain(e) => expr(e, out),
            Body::Guarded(arms) => arms.iter().for_each(|(g, r)| {
                expr(g, out);
                expr(r, out);
            }),
        }
        c.wher.iter().for_each(|w| mentioned(w, out));
    }
}

/// The `Int` measures worth trying for a function: each `Int` parameter `p` (counting down to
/// 0), `b - p` and `p - b` for another `Int` parameter or captured value `b` (counting up to,
/// or down to, a bound), and `len a - p` (counting up to an array's length).
fn int_candidates(ints: &[(usize, String)], bounds: &[(MVal, String)]) -> Vec<Measure> {
    let mut out = Vec::new();
    for (p, pn) in ints {
        out.push(Measure::Int(vec![(1, MVal::Param(*p))], 0, pn.clone()));
    }
    for (p, pn) in ints {
        for (q, qn) in ints {
            if p != q {
                out.push(Measure::Int(
                    vec![(1, MVal::Param(*q)), (-1, MVal::Param(*p))],
                    0,
                    format!("{qn} - {pn}"),
                ));
            }
        }
        for (b, bn) in bounds {
            out.push(Measure::Int(
                vec![(1, b.clone()), (-1, MVal::Param(*p))],
                0,
                format!("{bn} - {pn}"),
            ));
            out.push(Measure::Int(
                vec![(1, MVal::Param(*p)), (-1, b.clone())],
                0,
                format!("{pn} - {bn}"),
            ));
        }
    }
    out.truncate(48);
    out
}

/// What kind of value a parameter of this type is, for measures.
#[derive(Clone, Copy, PartialEq, Eq)]
enum PKind {
    Int,
    Arr,
    Str,
    Struct,
}

fn pkind(t: Option<&Type>) -> PKind {
    match t {
        Some(t) if is_int(t) => PKind::Int,
        Some(t) if array_elem_int(t).is_some() => PKind::Arr,
        Some(Type::Con(c)) if c == "String" => PKind::Str,
        _ => PKind::Struct,
    }
}

fn pat_label(p: Option<&Pat>, i: usize) -> String {
    match p {
        Some(Pat::Var(v, _)) => v.clone(),
        _ => format!("argument {}", i + 1),
    }
}

/// Is `e` the structural parameter `id` rebuilt from the parts its pattern `p` took apart?
fn rebuilds(cx: &Cx, e: &Expr, p: &Pat, id: usize) -> bool {
    match p {
        Pat::Var(v, _) => {
            matches!(e, Expr::Var(w, _) if w == v)
                && matches!(cx.env.get(v), Some(Bind::Part(a, _)) if *a == id)
        }
        Pat::Int(k, _) => matches!(e, Expr::Int(j, _) if j == k),
        Pat::Tuple(ps, _) => match e {
            Expr::Tuple(es, _) => {
                es.len() == ps.len() && es.iter().zip(ps).all(|(x, q)| rebuilds(cx, x, q, id))
            }
            _ => false,
        },
        Pat::Con(c, ps, _) => {
            let (h, args) = spine(e);
            matches!(h, Expr::Con(d, _) if d == c)
                && args.len() == ps.len()
                && args.iter().zip(ps).all(|(x, q)| rebuilds(cx, x, q, id))
        }
        Pat::Wild(_) | Pat::Str(..) => false,
    }
}

impl Checker<'_> {
    /// (totality) The atom of the length of the whole `String` value `id`.
    fn str_len_atom(&mut self, id: usize, name: &str) -> usize {
        if let Some(a) = self.tot.as_ref().and_then(|t| t.strlen.get(&id).copied()) {
            return a;
        }
        let a = self.fresh(&format!("strLen {name}"), 0);
        if let Some(t) = self.tot.as_mut() {
            t.strlen.insert(id, a);
        }
        a
    }

    /// (totality) The values a condition shows to be non-zero when it holds and when it fails:
    /// `a /= b` and the failing `a == b` give `a - b`.
    fn ne_of(&mut self, cx: &Cx, e: &Expr) -> (Vec<Lin>, Vec<Lin>) {
        match e {
            Expr::BinOp(op, a, b, _) if op == "==" || op == "/=" => {
                let mut side = Vec::new();
                let d = match (self.term(cx, a, &mut side), self.term(cx, b, &mut side)) {
                    (Some(x), Some(y)) => x.sub(&y),
                    _ => None,
                };
                match (d, op.as_str()) {
                    (Some(d), "==") => (Vec::new(), vec![d]),
                    (Some(d), _) => (vec![d], Vec::new()),
                    (None, _) => (Vec::new(), Vec::new()),
                }
            }
            Expr::App(f, a, _) if matches!(&**f, Expr::Var(n, _) if n == "not") => {
                let (y, n) = self.ne_of(cx, a);
                (n, y)
            }
            Expr::If(a, b, f, _) if matches!(&**f, Expr::Con(c, _) if c == "False") => {
                let (ya, _) = self.ne_of(cx, a);
                let (yb, _) = self.ne_of(cx, b);
                (ya.into_iter().chain(yb).collect(), Vec::new())
            }
            Expr::If(a, t, b, _) if matches!(&**t, Expr::Con(c, _) if c == "True") => {
                let (_, na) = self.ne_of(cx, a);
                let (_, nb) = self.ne_of(cx, b);
                (Vec::new(), na.into_iter().chain(nb).collect())
            }
            _ => (Vec::new(), Vec::new()),
        }
    }

    /// Facts with no integer solution: the path they hold on is impossible.
    fn absurd(&self, facts: &[Lin]) -> bool {
        if facts.is_empty() {
            return false;
        }
        let rows = self.rows_for(facts, facts.to_vec());
        match refute(&rows) {
            Some(cert) if check_cert(&cert) => {
                if let Some(out) = self.certs.borrow_mut().as_mut() {
                    out.push(cert);
                }
                true
            }
            _ => false,
        }
    }

    fn tot_partial(&mut self, why: &str, sp: Span) {
        if let Some(t) = self.tot.as_mut() {
            if let Some(fr) = t.frames.last() {
                let from = fr.node.clone();
                t.refs.push(TRef {
                    from,
                    to: format!("partial:{why}"),
                    span: sp,
                    saturated: true,
                });
            }
        }
    }

    /// A local function's node name (totality mode), registered with its shape.
    fn tot_local(&mut self, f: &Func) -> Option<String> {
        let t = self.tot.as_mut()?;
        let base = format!("{}${}", t.cur_top, f.name);
        let mut name = base.clone();
        let mut k = 1;
        while t.locals.contains_key(&name) {
            k += 1;
            name = format!("{base}#{k}");
        }
        let arity = f.clauses.first().map_or(0, |c| c.pats.len());
        let clauses = f.clauses.iter().map(|c| (c.span, c.pats.clone())).collect();
        t.locals.insert(name.clone(), (arity, f.span, clauses));
        Some(name)
    }

    /// A local function's measures: over its own parameters (typed by inference) and the
    /// `Int` values and array lengths it captures, fixed where it is defined.
    fn tot_measures_local(&mut self, scope: &Cx, f: &Func, node: &str) {
        let Some(t) = self.tot.as_ref() else {
            return;
        };
        let tys = t
            .where_tys
            .get(&local_key(node))
            .cloned()
            .unwrap_or_default();
        let arity = f.clauses.first().map_or(0, |c| c.pats.len());
        let first = f.clauses.first();
        let mut used = HashSet::new();
        mentioned(f, &mut used);
        let mut ints = Vec::new();
        let mut bounds = Vec::new();
        let mut structs = Vec::new();
        for i in 0..arity {
            let label = pat_label(first.and_then(|c| c.pats.get(i)), i);
            match pkind(tys.get(i).and_then(Option::as_ref)) {
                PKind::Int => ints.push((i, label)),
                PKind::Arr => bounds.push((MVal::Len(i), format!("len {label}"))),
                PKind::Str => {
                    bounds.push((MVal::StrLen(i), format!("strLen {label}")));
                    structs.push(i);
                }
                PKind::Struct => structs.push(i),
            }
        }
        let mut names: Vec<&String> = used.iter().collect();
        names.sort();
        let strlen_used = used.contains("strLen");
        let mut fixed = Vec::new();
        for n in names {
            match scope.env.get(n) {
                Some(Bind::Int(l)) => fixed.push((MVal::Fixed(l.clone()), n.clone())),
                Some(Bind::Arr(l, _)) => {
                    fixed.push((MVal::Fixed(Lin::atom(*l)), format!("len {n}")));
                }
                Some(Bind::Part(id, false)) if strlen_used => {
                    let a = self.str_len_atom(*id, n);
                    fixed.push((MVal::Fixed(Lin::atom(a)), format!("strLen {n}")));
                }
                _ => {}
            }
        }
        bounds.extend(fixed);
        let mut ms = int_candidates(&ints, &bounds);
        ms.extend(structs.into_iter().map(Measure::Struct));
        if let Some(t) = self.tot.as_mut() {
            t.measures.insert(node.to_string(), ms);
        }
    }

    /// A top-level function's measures, from its signature.
    fn tot_top_measures(&mut self, g: &str) -> Vec<Measure> {
        if let Some(ms) = self.tot.as_ref().and_then(|t| t.measures.get(g)) {
            return ms.clone();
        }
        let arity = self
            .tot
            .as_ref()
            .and_then(|t| t.arity.get(g).copied())
            .unwrap_or(0);
        let ps = self
            .sigs
            .get(g)
            .map(|(ps, _)| ps.clone())
            .unwrap_or_default();
        let mut ints = Vec::new();
        let mut bounds = Vec::new();
        let mut structs = Vec::new();
        let pn = self
            .tot
            .as_ref()
            .and_then(|t| t.pnames.get(g).cloned())
            .unwrap_or_default();
        for i in 0..arity {
            let label = pn
                .get(i)
                .cloned()
                .unwrap_or_else(|| format!("argument {}", i + 1));
            match pkind(ps.get(i)) {
                PKind::Int => ints.push((i, label)),
                PKind::Arr => bounds.push((MVal::Len(i), format!("len {label}"))),
                PKind::Str => {
                    bounds.push((MVal::StrLen(i), format!("strLen {label}")));
                    structs.push(i);
                }
                PKind::Struct => structs.push(i),
            }
        }
        let mut ms = int_candidates(&ints, &bounds);
        ms.extend(structs.into_iter().map(Measure::Struct));
        if let Some(t) = self.tot.as_mut() {
            t.measures.insert(g.to_string(), ms.clone());
        }
        ms
    }

    /// Binds a clause's parameters for the totality walk and opens its frame.
    fn tot_enter(&mut self, cs: &mut Cx, node: &str, pats: &[Pat], tys: &[Option<Type>], sp: Span) {
        let mut vals = Vec::new();
        for (i, p) in pats.iter().enumerate() {
            let v = match pkind(tys.get(i).and_then(Option::as_ref)) {
                PKind::Int => {
                    let l = match p {
                        Pat::Int(k, _) => Lin::konst(i128::from(*k)),
                        _ => Lin::atom(self.fresh(&pat_label(Some(p), i), MIN)),
                    };
                    if let Pat::Var(v, _) = p {
                        cs.env.insert(v.clone(), Bind::Int(l.clone()));
                    }
                    FVal::Int(l)
                }
                PKind::Arr => {
                    let l = self.fresh(&format!("len {}", pat_label(Some(p), i)), 0);
                    if let Pat::Var(v, _) = p {
                        let int_elems = tys
                            .get(i)
                            .and_then(Option::as_ref)
                            .and_then(array_elem_int)
                            .unwrap_or(false);
                        cs.env.insert(v.clone(), Bind::Arr(l, int_elems));
                    }
                    FVal::Len(l)
                }
                PKind::Str | PKind::Struct => self.tot_struct_param(cs, p),
            };
            vals.push(v);
        }
        if let Some(t) = self.tot.as_mut() {
            let measures = t.measures.get(node).cloned().unwrap_or_default();
            t.cur_clause = sp;
            t.frames.push(Frame {
                node: node.to_string(),
                vals,
                measures,
            });
        }
    }

    /// A structural parameter: its value is part `id` (itself), and what its pattern takes
    /// apart is a strict part of it.
    fn tot_struct_param(&mut self, cs: &mut Cx, p: &Pat) -> FVal {
        let Some(t) = self.tot.as_mut() else {
            return FVal::None;
        };
        t.next_id += 1;
        let id = t.next_id;
        match p {
            Pat::Var(v, _) => {
                cs.env.insert(v.clone(), Bind::Part(id, false));
            }
            _ => {
                let mut names = Vec::new();
                pat_names(p, &mut names);
                for n in names {
                    cs.env.insert(n, Bind::Part(id, true));
                }
            }
        }
        FVal::Struct(id, p.clone())
    }

    /// Opens a top-level clause's frame (totality mode); `ints`/`lens` are the values
    /// `check_func` already gave its `Int` and array parameters.
    #[allow(clippy::too_many_arguments)]
    fn tot_frame_top(
        &mut self,
        cx: &mut Cx,
        f: &Func,
        pats: &[Pat],
        tys: &[Option<Type>],
        ints: &[Option<Lin>],
        lens: &[Option<usize>],
        sp: Span,
    ) {
        if let Some(t) = self.tot.as_mut() {
            t.cur_top = f.name.clone();
        }
        let measures = self.tot_top_measures(&f.name);
        let mut vals = Vec::new();
        for (i, p) in pats.iter().enumerate() {
            let v = match pkind(tys.get(i).and_then(Option::as_ref)) {
                PKind::Int => ints[i].clone().map_or(FVal::None, FVal::Int),
                PKind::Arr => lens[i].map_or(FVal::None, FVal::Len),
                PKind::Str | PKind::Struct => self.tot_struct_param(cx, p),
            };
            vals.push(v);
        }
        if let Some(t) = self.tot.as_mut() {
            t.cur_clause = sp;
            t.frames.push(Frame {
                node: f.name.clone(),
                vals,
                measures,
            });
        }
    }

    /// A use of `g` (applied to `args`) in totality mode.
    fn tot_use(&mut self, cx: &Cx, g: &str, args: &[&Expr], sp: Span) {
        let Some(t) = self.tot.as_ref() else {
            return;
        };
        let Some(from) = t.frames.last().map(|f| f.node.clone()) else {
            return;
        };
        let (node, arity) = match cx.env.get(g) {
            Some(Bind::Local(n)) => (n.clone(), t.locals.get(n).map_or(0, |l| l.0)),
            Some(_) => return, // a parameter or local value: calling a function argument
            None if self.user.contains(g) => (g.to_string(), t.arity.get(g).copied().unwrap_or(0)),
            None => {
                self.tot_builtin(cx, g, args, sp);
                return;
            }
        };
        let saturated = args.len() >= arity;
        let same_group = node.starts_with(&format!("{}$", t.cur_top))
            || node == t.cur_top
            || match (t.top_scc.get(&node), t.top_scc.get(&t.cur_top)) {
                (Some(a), Some(b)) => a == b,
                _ => false,
            };
        if let Some(t) = self.tot.as_mut() {
            t.refs.push(TRef {
                from,
                to: node.clone(),
                span: sp,
                saturated,
            });
        }
        if saturated && same_group {
            self.tot_edges(cx, &node, &args[..arity], sp);
        }
    }

    /// A built-in used by a total function: always total, total when proven safe here, or
    /// partial.
    fn tot_builtin(&mut self, cx: &Cx, g: &str, args: &[&Expr], sp: Span) {
        if TOTAL_BUILTINS.contains(&g) {
            return;
        }
        if let Some(b) = crate::simd::builtin(g) {
            use crate::simd::{Builtin, VOp};
            let n = crate::simd::builtin_ty(b).n() as i128;
            let ok = match b {
                Builtin::Op(VOp::Lane, _) => {
                    args.len() >= 2 && {
                        let mut side = Vec::new();
                        match self.term(cx, args[1], &mut side) {
                            Some(i) => {
                                let mut facts = cx.facts.clone();
                                facts.extend(side);
                                let hi = Lin::konst(n - 1).sub(&i);
                                hi.is_some_and(|hi| {
                                    self.prove(
                                        &facts,
                                        &Formula::And(vec![Formula::Ge(i), Formula::Ge(hi)]),
                                    )
                                })
                            }
                            None => false,
                        }
                    }
                }
                Builtin::Load(_) | Builtin::Store(_) => {
                    args.len() >= 2 && {
                        let mut side = Vec::new();
                        match (
                            self.arr_value(cx, args[0], &mut side),
                            self.term(cx, args[1], &mut side),
                        ) {
                            (Some(len), Some(i)) => {
                                let mut facts = cx.facts.clone();
                                facts.extend(side);
                                let hi =
                                    Lin::atom(len).sub(&i).and_then(|d| d.add(&Lin::konst(-n)));
                                hi.is_some_and(|hi| {
                                    self.prove(
                                        &facts,
                                        &Formula::And(vec![Formula::Ge(i), Formula::Ge(hi)]),
                                    )
                                })
                            }
                            _ => false,
                        }
                    }
                }
                Builtin::Op(..) => true,
            };
            if !ok {
                self.tot_partial(&format!("`{g}` here may index out of range"), sp);
            }
            return;
        }
        match g {
            "getArray" | "setArray" => {
                let want = if g == "getArray" { 2 } else { 3 };
                if args.len() >= want {
                    self.check_access(cx, args, sp);
                }
                if !self.proven.contains(&sp) {
                    self.tot_partial("this array access may be out of bounds", sp);
                }
            }
            "div" | "mod" | "rem" if args.len() >= 2 => self.tot_nonzero(cx, args[1], sp),
            "exitWith" => self.tot_partial("`exitWith` ends the program", sp),
            crate::contracts::FAIL => {
                // the run-time check of a contract not proven here (`contracts.rs`)
                let what = args
                    .first()
                    .and_then(|a| first_str(a))
                    .and_then(|m| m.strip_prefix("axion: contract violated: "))
                    .map_or_else(|| "a contract".to_string(), str::to_string);
                self.tot_partial(
                    &format!(
                        "the contract {what} is not proven here, so it is checked at run time"
                    ),
                    sp,
                );
            }
            _ => self.tot_partial(&format!("`{g}` is not known to return normally"), sp),
        }
    }

    /// A built-in operator in totality mode: a division must have a non-zero divisor.
    fn tot_binop(&mut self, cx: &Cx, op: &str, b: &Expr, sp: Span) {
        match op {
            "div" | "mod" | "rem" | "/" => self.tot_nonzero(cx, b, sp),
            "div#I" | "mod#I" if !matches!(b, Expr::Int(k, _) if *k != 0) => {
                self.tot_partial("this `Integer` division's divisor may be zero", sp);
            }
            "++" => {
                if let Some(from) = self
                    .tot
                    .as_ref()
                    .and_then(|t| t.frames.last())
                    .map(|f| f.node.clone())
                {
                    if let Some(t) = self.tot.as_mut() {
                        t.refs.push(TRef {
                            from,
                            to: "append".into(),
                            span: sp,
                            saturated: true,
                        });
                    }
                }
            }
            _ => {}
        }
    }

    fn tot_nonzero(&mut self, cx: &Cx, d: &Expr, sp: Span) {
        if matches!(d, Expr::Int(k, _) if *k != 0) {
            return;
        }
        let mut side = Vec::new();
        let ok = match self.term(cx, d, &mut side) {
            Some(t)
                if cx
                    .ne
                    .iter()
                    .any(|n| *n == t || Some(n.clone()) == t.scale(-1)) =>
            {
                true
            }
            Some(t) => {
                let mut facts = cx.facts.clone();
                facts.extend(side);
                let pos = t.add(&Lin::konst(-1));
                let neg = Lin::konst(-1).sub(&t);
                match (pos, neg) {
                    (Some(p), Some(n)) => {
                        self.prove(&facts, &Formula::Or(vec![Formula::Ge(p), Formula::Ge(n)]))
                    }
                    _ => false,
                }
            }
            None => false,
        };
        if !ok {
            self.tot_partial(&format!("the divisor `{}` may be zero", show(d)), sp);
        }
    }

    /// The size-change graph of a call to `callee` (in the caller's recursive group): which
    /// caller measures the callee's measures are below (strictly) or not above.
    fn tot_edges(&mut self, cx: &Cx, callee: &str, args: &[&Expr], sp: Span) {
        let Some(fr) = self.tot.as_ref().and_then(|t| t.frames.last()) else {
            return;
        };
        let from_node = fr.node.clone();
        let caller_vals = fr.vals.clone();
        let caller_ms = fr.measures.clone();
        // the length atoms of the from_node's String parameters
        let mut flens: HashMap<usize, usize> = HashMap::new();
        for (i, v) in caller_vals.iter().enumerate() {
            if let FVal::Struct(id, _) = v {
                let wanted = caller_ms.iter().any(|m| {
                    matches!(m, Measure::Int(ts, _, _) if ts.iter().any(|(_, x)| matches!(x, MVal::StrLen(k) if *k == i)))
                });
                if wanted {
                    flens.insert(i, self.str_len_atom(*id, ""));
                }
            }
        }
        let cms = if callee.contains('$') && !self.user.contains(callee) {
            self.tot
                .as_ref()
                .and_then(|t| t.measures.get(callee).cloned())
                .unwrap_or_default()
        } else {
            self.tot_top_measures(callee)
        };
        let mut side = Vec::new();
        let mut aint: HashMap<usize, Option<Lin>> = HashMap::new();
        let mut alen: HashMap<usize, Option<usize>> = HashMap::new();
        let eval_caller = |m: &[(i128, MVal)], c: i128| -> Option<Lin> {
            let mut acc = Lin::konst(c);
            for (k, v) in m {
                let x = match v {
                    MVal::Param(i) => match caller_vals.get(*i) {
                        Some(FVal::Int(l)) => l.clone(),
                        _ => return None,
                    },
                    MVal::Len(i) => match caller_vals.get(*i) {
                        Some(FVal::Len(l)) => Lin::atom(*l),
                        _ => return None,
                    },
                    MVal::Fixed(l) => l.clone(),
                    MVal::StrLen(i) => Lin::atom(*flens.get(i)?),
                };
                acc = acc.add(&x.scale(*k)?)?;
            }
            Some(acc)
        };
        let mut cvals: Vec<Option<Lin>> = Vec::new();
        for m in &cms {
            let v = match m {
                Measure::Int(terms, c, _) => {
                    let mut acc = Some(Lin::konst(*c));
                    for (k, v) in terms {
                        let x = match v {
                            MVal::Param(i) => {
                                if !aint.contains_key(i) {
                                    let t = args.get(*i).and_then(|a| self.term(cx, a, &mut side));
                                    aint.insert(*i, t);
                                }
                                aint[i].clone()
                            }
                            MVal::Len(i) => {
                                if !alen.contains_key(i) {
                                    let l =
                                        args.get(*i).and_then(|a| self.arr_value(cx, a, &mut side));
                                    alen.insert(*i, l);
                                }
                                alen[i].map(Lin::atom)
                            }
                            MVal::Fixed(l) => Some(l.clone()),
                            MVal::StrLen(i) => match args.get(*i) {
                                Some(Expr::Var(v, _)) => match cx.env.get(v) {
                                    Some(Bind::Part(id, false)) => {
                                        let id = *id;
                                        Some(Lin::atom(self.str_len_atom(id, v)))
                                    }
                                    _ => None,
                                },
                                _ => None,
                            },
                        };
                        acc = match (acc, x) {
                            (Some(a), Some(x)) => x.scale(*k).and_then(|xs| a.add(&xs)),
                            _ => None,
                        };
                    }
                    acc
                }
                Measure::Struct(_) => None,
            };
            cvals.push(v);
        }
        let mut facts = cx.facts.clone();
        facts.extend(side);
        let diagonal = from_node == callee || caller_ms.len() * cms.len() > 400;
        let mut edges = Vec::new();
        for (i, mi) in caller_ms.iter().enumerate() {
            for (j, mj) in cms.iter().enumerate() {
                if diagonal && i != j {
                    continue;
                }
                match (mi, mj) {
                    (Measure::Int(ti, ci, _), Measure::Int(..)) => {
                        let (Some(vi), Some(vj)) = (eval_caller(ti, *ci), cvals[j].clone()) else {
                            continue;
                        };
                        if vi == vj {
                            edges.push((i, j, false));
                            continue;
                        }
                        let strict = vi
                            .sub(&vj)
                            .and_then(|d| d.add(&Lin::konst(-1)))
                            .is_some_and(|d| {
                                self.prove(
                                    &facts,
                                    &Formula::And(vec![Formula::Ge(vi.clone()), Formula::Ge(d)]),
                                )
                            });
                        if strict {
                            edges.push((i, j, true));
                        } else if vi
                            .sub(&vj)
                            .is_some_and(|d| self.prove(&facts, &Formula::Ge(d)))
                        {
                            edges.push((i, j, false));
                        }
                    }
                    (Measure::Struct(pi), Measure::Struct(pj)) => {
                        let Some(FVal::Struct(id, pat)) = caller_vals.get(*pi) else {
                            continue;
                        };
                        let Some(arg) = args.get(*pj) else {
                            continue;
                        };
                        if let Expr::Var(v, _) = arg {
                            if let Some(Bind::Part(aid, strict)) = cx.env.get(v) {
                                if aid == id {
                                    edges.push((i, j, *strict));
                                    continue;
                                }
                            }
                        }
                        // the parameter rebuilt from its own pattern's parts: the same size
                        if rebuilds(cx, arg, pat, *id) {
                            edges.push((i, j, false));
                        }
                    }
                    _ => {}
                }
            }
        }
        if let Some(t) = self.tot.as_mut() {
            t.calls.push(SctCall {
                caller: from_node,
                callee: callee.to_string(),
                edges,
                span: sp,
            });
        }
    }
}

thread_local! {
    /// `--emit refine-certs`: the certificates of totality's own arithmetic (its decreases, bounds
    /// and divisors), kept while `collect_total_certs` has switched collection on.
    static TOTAL_CERTS: std::cell::RefCell<Option<Vec<Cert>>> =
        const { std::cell::RefCell::new(None) };
}

/// Keep the certificates of every proof the totality walk makes, until `take_total_certs`.
pub fn collect_total_certs() {
    TOTAL_CERTS.with(|c| *c.borrow_mut() = Some(Vec::new()));
}

/// The certificates kept since `collect_total_certs`; collection stops.
pub fn take_total_certs() -> Vec<Cert> {
    TOTAL_CERTS.with(|c| c.borrow_mut().take().unwrap_or_default())
}

/// The totality walk (`total.rs`) over the `needed` top-level functions of `module`: every
/// use of a function or built-in, every partial operation, and the size-change graph of every
/// call inside a recursive group.
pub fn total_walk(module: &Module, needed: &HashSet<String>, mut tw: TotWalk) -> TotWalk {
    let mut sigs = HashMap::new();
    for f in &module.funcs {
        if let Some(s) = &f.sig {
            sigs.insert(f.name.clone(), split_sig(s));
        }
        tw.arity.insert(
            f.name.clone(),
            f.clauses.first().map_or(0, |c| c.pats.len()),
        );
        let names = f.clauses.first().map_or(Vec::new(), |c| {
            c.pats
                .iter()
                .enumerate()
                .map(|(i, p)| pat_label(Some(p), i))
                .collect()
        });
        tw.pnames.insert(f.name.clone(), names);
    }
    let mut scratch = Diagnostics::default();
    let mut refs: HashMap<String, &Refinement> = HashMap::new();
    for rf in &module.refinements {
        let Some((ps, _)) = sigs.get(&rf.func) else {
            continue;
        };
        if rf
            .preds
            .iter()
            .all(|p| well_formed(rf, p, ps, &mut scratch))
            && !rf.preds.is_empty()
        {
            refs.insert(rf.func.clone(), rf);
        }
    }
    let mut ck = Checker {
        refs,
        sigs,
        atoms: Vec::new(),
        diags: &mut scratch,
        proven: HashSet::new(),
        user: module.funcs.iter().map(|f| f.name.clone()).collect(),
        certs: std::cell::RefCell::new(TOTAL_CERTS.with(|c| c.borrow().is_some()).then(Vec::new)),
        tot: Some(tw),
        cur_fn: String::new(),
        dynamic: crate::contracts::Dynamic::default(),
        obligations: Vec::new(),
        no_self: HashSet::new(),
    };
    for f in module.funcs.iter().filter(|f| needed.contains(&f.name)) {
        ck.check_func(f);
    }
    if let Some(mine) = ck.certs.borrow_mut().take() {
        TOTAL_CERTS.with(|c| {
            if let Some(all) = c.borrow_mut().as_mut() {
                all.extend(mine);
            }
        });
    }
    ck.tot.take().unwrap_or_default()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn lin(c: i128, t: &[(usize, i128)]) -> Lin {
        Lin {
            c,
            t: t.iter().copied().collect(),
        }
    }

    #[test]
    fn refutations_carry_certificates_the_checker_accepts() {
        // x >= 1, y >= x, 3 >= y + x... x + y <= 3 with x >= 1, y >= x: (1,1),(1,2) satisfy it
        assert!(refute(&[
            lin(-1, &[(0, 1)]),
            lin(0, &[(1, 1), (0, -1)]),
            lin(3, &[(0, -1), (1, -1)])
        ])
        .is_none());
        // ... but adding y >= 3 refutes it
        let rows = [
            lin(-1, &[(0, 1)]),
            lin(0, &[(1, 1), (0, -1)]),
            lin(3, &[(0, -1), (1, -1)]),
            lin(-3, &[(1, 1)]),
        ];
        let cert = refute(&rows).expect("refuted");
        assert!(check_cert(&cert));
        // 2x - 1 >= 0 and 1 - 2x >= 0: rationally x = 1/2, integrally impossible (tightening)
        let cert = refute(&[lin(-1, &[(5, 2)]), lin(1, &[(5, -2)])]).expect("refuted");
        assert!(check_cert(&cert));
        assert!(cert.steps.iter().any(|s| matches!(s, CStep::Tight(..))));
    }

    #[test]
    fn the_checker_rejects_tampered_certificates() {
        let input = vec![CRow { c: vec![1], k: -1 }, CRow { c: vec![-1], k: 0 }];
        let ok = Cert {
            input: input.clone(),
            steps: vec![CStep::Hyp(0), CStep::Hyp(1), CStep::Comb(0, 1, 1, 1)],
        };
        assert!(check_cert(&ok));
        let bad = |steps: Vec<CStep>| {
            check_cert(&Cert {
                input: input.clone(),
                steps,
            })
        };
        // a negative multiplier would let x >= 1 "prove" anything
        assert!(!bad(vec![CStep::Hyp(0), CStep::Comb(0, -1, 0, 0)]));
        // ending on a row that is not a contradiction
        assert!(!bad(vec![CStep::Hyp(0), CStep::Hyp(1)]));
        // a tightening whose divisor does not divide the coefficients
        assert!(!bad(vec![CStep::Hyp(0), CStep::Tight(0, 2)]));
        // a reference to a row not yet derived, or an input that does not exist
        assert!(!bad(vec![CStep::Comb(0, 1, 1, 1)]));
        assert!(!bad(vec![CStep::Hyp(7)]));
        // a satisfiable input is never refuted: x >= 0 and 5 - x >= 0
        assert!(!check_cert(&Cert {
            input: vec![CRow { c: vec![1], k: 0 }, CRow { c: vec![-1], k: 5 }],
            steps: vec![CStep::Hyp(0), CStep::Hyp(1), CStep::Comb(0, 1, 1, 1)],
        }));
    }
}
