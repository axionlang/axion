//! Drop-balance verifier — translation validation for memory safety (§soundness).
//!
//! Runs over the FINAL drop-inserted Core (`core::Lowered`) and proves, per function and
//! per path, that every heap resource is freed **exactly once** and is never used after it
//! is freed. It is a soundness *net under Auto-Drop*: a drop-insertion bug can't ship,
//! because the compiler can refuse the output. This is the corruption guarantee (double
//! free / use-after-free), mirroring the ASan gate; leaks are collected but soft (Axión
//! has intentional conservative leaks).
//!
//! Model: each tracked variable carries `owned` (an allocation THIS function must free)
//! and `borrows` (the set of resources it holds an INTERIOR pointer into — a `Field`/`get`
//! alias, transitively through constructors). A value is safe to use iff it and every
//! resource it borrows are still live; a `drop` is safe iff its target is a live *owned*
//! resource. The move/borrow/produce classification is delegated to the single authority
//! `delta::op_delta_effect` (the same one Auto-Drop uses), so the verifier checks the
//! emitted drops against that contract.

use crate::ast::Span;
use crate::core::{Atom, BorrowArgs, CPat, CoreFn, Lowered, Op, RecordInfo, Rhs, Term};
use crate::delta::op_delta_effect;
use std::collections::{HashMap, HashSet};

/// The operand a DIRECT interior projection returns a HEAP pointer INTO — reading a HEAP
/// field of a record. Its result aliases that operand's heap, so freeing the operand
/// dangles the result. A SCALAR field read (`field val c :: Int`) is a value copy, not an
/// alias. Array `*_get` yields a scalar element (Int/byte) and `LoadRaw` occurs only in
/// (skipped) destructors, so neither aliases here. A call is NOT an alias — a view MOVES
/// its argument instead (ownership transfers), and a normal call returns a fresh value.
fn alias_target<'a>(op: &'a Op, recinfo: &RecordInfo) -> Option<&'a Atom> {
    match op {
        Op::Field { name, rec } if recinfo.named_field_is_heap(name) => Some(rec),
        _ => None,
    }
}

/// The classification of a value produced on EITHER branch of an `if`/`case`: a resource
/// (owned, or holding interior pointers) iff some branch yields one; the borrow sets union.
fn merge_vals(rets: &[Val]) -> Val {
    Val {
        owned: rets.iter().any(|v| v.owned),
        borrows: rets.iter().flat_map(|v| v.borrows.iter().cloned()).collect(),
        dead: None,
    }
}

/// A verifier finding. The corruption categories are the hard guarantee; `Leak` is soft.
#[derive(Clone, Debug)]
pub struct Finding {
    pub cat: Cat,
    pub func: String,
    pub var: String,
    pub span: Span,
}

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Cat {
    /// `drop x` where `x` was already freed on this path.
    DoubleFree,
    /// a value (or a resource it borrows into) used after it was freed / moved out.
    UseAfterFree,
    /// `drop x` where `x` is an interior alias, not an owned allocation.
    DropOfAlias,
    /// two paths reaching a join disagree on which resources are still live.
    Unbalanced,
    /// an owned resource still live at a `ret` and not returned — a (soft) leak.
    Leak,
}

impl Cat {
    /// The hard guarantee: a corruption finding means Auto-Drop emitted unsafe code.
    pub fn is_corruption(self) -> bool {
        matches!(self, Cat::DoubleFree | Cat::UseAfterFree | Cat::DropOfAlias | Cat::Unbalanced)
    }
}

/// Per-variable resource state.
#[derive(Clone, Default, PartialEq, Eq, Debug)]
struct Val {
    /// this variable names an allocation this function is responsible for freeing.
    owned: bool,
    /// resources it holds an interior pointer into (must outlive every use of it).
    borrows: HashSet<String>,
    /// `Some` once the resource is freed (`DoubleFree` origin) or moved out — using it,
    /// or anything borrowing it, afterwards is a use-after-free.
    dead: Option<Cat>,
}

type State = HashMap<String, Val>;

/// Verify every function of a lowered module; returns all findings (corruption + leak).
pub fn verify(lowered: &Lowered) -> Vec<Finding> {
    let mut out = Vec::new();
    for f in &lowered.fns {
        // generated destructors (`axion_drop_*`) manage memory BY HAND (raw `LoadRaw` +
        // explicit `free`/`axion_drop` calls) — they are not produced by Auto-Drop and do
        // not follow the linear-resource discipline, so the verifier does not judge them.
        if f.name.starts_with("axion_drop_") {
            continue;
        }
        verify_fn(f, &lowered.borrow_args, &lowered.recinfo, &mut out);
    }
    out
}

fn verify_fn(f: &CoreFn, ba: &BorrowArgs, recinfo: &RecordInfo, out: &mut Vec<Finding>) {
    let mut st = State::new();
    let mut owned: HashSet<&String> = f.owned_params.iter().collect();
    // a param DROPPED anywhere in the body is owned by this function (dropping proves
    // ownership) — this captures the `Many` params `reclaim_cond_escape` made droppable,
    // which are absent from `owned_params` (that lists only `%1` params).
    let dropped = dropped_vars(&f.body);
    for p in &f.params {
        if dropped.contains(p) {
            owned.insert(p);
        }
    }
    let borrowed = ba.get(&f.name);
    for (i, p) in f.params.iter().enumerate() {
        // an owned heap param is a live resource; a borrow-arg param and scalars are the
        // caller's to free — untracked (using them is fine, freeing them would be a bug).
        if owned.contains(p) && !borrowed.is_some_and(|s| s.contains(&i)) {
            st.insert(p.clone(), Val { owned: true, ..Default::default() });
        }
    }
    let mut v = Verifier { f: &f.name, ba, recinfo, out };
    v.term(&f.body, &mut st);
}

/// Every variable named by a `Drop` node anywhere in the term.
fn dropped_vars(t: &Term) -> HashSet<String> {
    let mut out = HashSet::new();
    fn walk(t: &Term, out: &mut HashSet<String>) {
        match t {
            Term::Drop(v, _, _, _, b) => {
                out.insert(v.clone());
                walk(b, out);
            }
            Term::Let(_, rhs, _, b) => {
                walk_rhs(rhs, out);
                walk(b, out);
            }
            Term::Ret(rhs, _) => walk_rhs(rhs, out),
        }
    }
    fn walk_rhs(rhs: &Rhs, out: &mut HashSet<String>) {
        match rhs {
            Rhs::Op(_) => {}
            Rhs::If(_, th, el) => {
                walk(th, out);
                walk(el, out);
            }
            Rhs::Case(_, arms) => arms.iter().for_each(|(_, b)| walk(b, out)),
        }
    }
    walk(t, &mut out);
    out
}

struct Verifier<'a> {
    f: &'a str,
    ba: &'a BorrowArgs,
    recinfo: &'a RecordInfo,
    out: &'a mut Vec<Finding>,
}

impl Verifier<'_> {
    fn finding(&mut self, cat: Cat, var: &str, span: Span) {
        self.out.push(Finding {
            cat,
            func: self.f.to_string(),
            var: var.to_string(),
            span,
        });
    }

    /// Verify a term against the incoming state (mutated to the state at its `ret`), and
    /// return the resource classification of the VALUE the term yields at its `ret` — so a
    /// `let`-bound `if`/`case` binder is a resource only when its branches actually return
    /// one (a branch returning a scalar `Int` is not tracked).
    fn term(&mut self, t: &Term, st: &mut State) -> Val {
        match t {
            Term::Let(x, rhs, sp, body) => {
                self.bind(x, rhs, *sp, st);
                self.term(body, st)
            }
            Term::Drop(x, _key, _skip, sp, body) => {
                self.do_drop(x, *sp, st);
                self.term(body, st)
            }
            Term::Ret(rhs, sp) => self.ret(rhs, *sp, st),
        }
    }

    /// A `let x = rhs`: evaluate the rhs's effect on `st`, then classify `x`.
    fn bind(&mut self, x: &str, rhs: &Rhs, sp: Span, st: &mut State) {
        match rhs {
            Rhs::Op(op) => self.bind_op(x, op, sp, st),
            Rhs::If(c, th, el) => {
                self.use_atom(c, sp, st);
                let val = self.branches(&[th, el], sp, st);
                if val.owned || !val.borrows.is_empty() {
                    st.insert(x.to_string(), val); // a resource only if the branches yield one
                }
            }
            Rhs::Case(scrut, arms) => {
                let val = self.case(scrut, arms, sp, st);
                if val.owned || !val.borrows.is_empty() {
                    st.insert(x.to_string(), val);
                }
            }
        }
    }

    /// A `let x = op`: check operand liveness, classify the result, then apply the operands'
    /// escapes (moved/aliased operands leave the state). `x` is tracked only if it is a
    /// resource (owns an allocation or holds an interior pointer into one).
    fn bind_op(&mut self, x: &str, op: &Op, sp: Span, st: &mut State) {
        let e = op_delta_effect(op, self.ba);
        for a in e.borrows.iter().chain(e.moves.iter()) {
            self.use_atom(a, sp, st);
        }
        if let Some(a) = e.alias {
            self.use_atom(a, sp, st);
        }
        let val = self.classify(op, st);
        if let Some(Atom::Var(src)) = e.alias {
            self.kill(src, Cat::UseAfterFree, st);
        }
        for a in &e.moves {
            if let Atom::Var(v) = a {
                self.kill(v, Cat::UseAfterFree, st);
            }
        }
        if val.owned || !val.borrows.is_empty() {
            st.insert(x.to_string(), val);
        }
    }

    /// The resource classification of an `Op`'s result (NO state mutation): a whole-value
    /// alias (`let y = x`) inherits its source; a fresh producer is `owned`, inheriting the
    /// interior pointers of its moved-in operands (the `build`/`grab` class); a direct HEAP
    /// field projection borrows its operand; everything else (a scalar `Prim`, a call
    /// returning an immediate/enum) is untracked.
    fn classify(&self, op: &Op, st: &State) -> Val {
        let e = op_delta_effect(op, self.ba);
        if let Some(Atom::Var(src)) = e.alias {
            return st.get(src).cloned().unwrap_or_default();
        }
        let mut inherited: HashSet<String> = HashSet::new();
        for a in &e.moves {
            if let Atom::Var(v) = a {
                if let Some(val) = st.get(v) {
                    inherited.extend(val.borrows.iter().cloned());
                    if !val.owned {
                        inherited.insert(v.clone());
                    }
                }
            }
        }
        if let Some(Atom::Var(w)) = alias_target(op, self.recinfo) {
            if st.contains_key(w.as_str()) {
                inherited.insert(w.clone());
                return Val { owned: false, borrows: inherited, dead: None };
            }
        }
        if e.produces.is_some() {
            return Val { owned: true, borrows: inherited, dead: None };
        }
        Val::default()
    }

    /// `drop x`: `x` must be a live OWNED resource.
    fn do_drop(&mut self, x: &str, sp: Span, st: &mut State) {
        match st.get(x) {
            Some(v) if v.dead == Some(Cat::DoubleFree) || v.dead.is_some() => {
                let cat = if v.dead == Some(Cat::UseAfterFree) {
                    // dropping something already moved out.
                    Cat::UseAfterFree
                } else {
                    Cat::DoubleFree
                };
                self.finding(cat, x, sp);
            }
            Some(v) if !v.owned => self.finding(Cat::DropOfAlias, x, sp),
            Some(_) => {
                if let Some(v) = st.get_mut(x) {
                    v.dead = Some(Cat::DoubleFree);
                }
            }
            None => {} // dropping an untracked value (a flat free of a non-resource) — inert
        }
    }

    /// A `ret`: the returned value escapes. Returns its resource classification (so a
    /// `let`-bound `if`/`case` learns whether its value is a resource).
    fn ret(&mut self, rhs: &Rhs, sp: Span, st: &mut State) -> Val {
        match rhs {
            Rhs::Op(op) => {
                let e = op_delta_effect(op, self.ba);
                for a in e.borrows.iter().chain(e.moves.iter()) {
                    self.use_atom(a, sp, st);
                }
                if let Some(a) = e.alias {
                    self.use_atom(a, sp, st);
                }
                let ret_val = self.classify(op, st);
                if let Some(Atom::Var(src)) = e.alias {
                    self.kill(src, Cat::UseAfterFree, st);
                }
                // returned resource escapes → mark moved so it isn't reported as a leak.
                for a in &e.moves {
                    if let Atom::Var(v) = a {
                        self.kill(v, Cat::UseAfterFree, st);
                    }
                }
                self.leak_check(sp, st);
                ret_val
            }
            Rhs::If(c, th, el) => {
                self.use_atom(c, sp, st);
                self.branches(&[th, el], sp, st)
            }
            Rhs::Case(scrut, arms) => self.case(scrut, arms, sp, st),
        }
    }

    /// Verify each branch on a clone of `st`, reconcile the live-owned sets at the join
    /// (leaving the merged state in `st`), and return the MERGED classification of the value
    /// the branches yield — owned/alias only if a branch actually returns a resource.
    fn branches(&mut self, arms: &[&Box<Term>], sp: Span, st: &mut State) -> Val {
        let outer: Vec<String> = st.keys().cloned().collect();
        let mut exits: Vec<State> = Vec::new();
        let mut rets: Vec<Val> = Vec::new();
        for a in arms {
            let mut s = st.clone();
            rets.push(self.term(a, &mut s));
            exits.push(s);
        }
        self.merge(&outer, &exits, sp, st);
        merge_vals(&rets)
    }

    fn case(&mut self, scrut: &Atom, arms: &[(CPat, Term)], sp: Span, st: &mut State) -> Val {
        self.use_atom(scrut, sp, st);
        // extracted fields are owned iff the scrutinee is an owned resource (consumed) —
        // the reclamation transfers them out; if the scrutinee is BORROWED, the owner keeps
        // the whole structure, so the fields are borrowed too (untracked).
        let scrut_owned = matches!(scrut, Atom::Var(n) if st.get(n).is_some_and(|v| v.owned && v.dead.is_none()));
        let outer: Vec<String> = st.keys().cloned().collect();
        let mut exits: Vec<State> = Vec::new();
        let mut rets: Vec<Val> = Vec::new();
        for (pat, body) in arms {
            let mut s = st.clone();
            self.bind_pattern(pat, scrut_owned, &mut s);
            rets.push(self.term(body, &mut s));
            exits.push(s);
        }
        self.merge(&outer, &exits, sp, st);
        merge_vals(&rets)
    }

    /// Bind a `case` pattern's field variables: a heap field the pattern names is either a
    /// `%1`-owned slot transferred OUT of the scrutinee (an owned resource) or a borrowed
    /// interior alias of the scrutinee.
    fn bind_pattern(&mut self, pat: &CPat, scrut_owned: bool, st: &mut State) {
        // only when the scrutinee is CONSUMED does a heap field transfer out as an owned
        // resource; a borrowed scrutinee keeps its fields (untracked). v1 does not model a
        // scrutinee DEEP-drop of an extracted field as an alias — a v2 refinement (needs
        // the scrutinee's drop-kind + slot set); it can only miss a bug, never false-flag.
        if !scrut_owned {
            return;
        }
        if let CPat::Con(con, subs) = pat {
            for (i, sp) in subs.iter().enumerate() {
                if let CPat::Var(n) = sp {
                    if self.recinfo.field_transfers_heap(con, i) {
                        st.insert(n.clone(), Val { owned: true, ..Default::default() });
                    }
                }
            }
        }
    }

    /// Reconcile branch exit states into `st`. A resource live (owned, not dead) on one
    /// path but dead on another is `Unbalanced`; the merged state marks it dead so a later
    /// use/drop on the still-live path is caught. Balanced code (every branch leaves the
    /// same live set) merges cleanly with no finding.
    fn merge(&mut self, outer: &[String], exits: &[State], sp: Span, st: &mut State) {
        // reconcile only the resources that existed BEFORE the branch (arm-local bindings
        // go out of scope at the join, so they never need to agree). A tail case whose
        // arms each terminate has no continuation — differing arm-local state is fine.
        st.clear();
        for name in outer {
            let vals: Vec<Val> = exits
                .iter()
                .map(|e| e.get(name).cloned().unwrap_or_default())
                .collect();
            let live = |v: &Val| v.owned && v.dead.is_none();
            let any_live = vals.iter().any(live);
            let all_live = vals.iter().all(live);
            let mut merged = vals[0].clone();
            merged.borrows = vals.iter().flat_map(|v| v.borrows.iter().cloned()).collect();
            if any_live && !all_live {
                self.finding(Cat::Unbalanced, name, sp);
                merged.dead = Some(Cat::Unbalanced); // conservative: catch a later use/drop
            } else if !any_live {
                merged.owned = false;
                merged.dead = vals.iter().find_map(|v| v.dead);
            } else {
                merged.owned = true;
                merged.dead = None;
            }
            st.insert(name.clone(), merged);
        }
    }

    /// Any owned resource still live at a `ret` (and not the returned value) is a leak.
    fn leak_check(&mut self, sp: Span, st: &State) {
        for (name, v) in st {
            if v.owned && v.dead.is_none() {
                self.out.push(Finding {
                    cat: Cat::Leak,
                    func: self.f.to_string(),
                    var: name.clone(),
                    span: sp,
                });
            }
        }
    }

    /// Using `atom` (borrow or move position): it and every resource it borrows must be
    /// live. Reports a `UseAfterFree` otherwise.
    fn use_atom(&mut self, atom: &Atom, sp: Span, st: &mut State) {
        let Atom::Var(v) = atom else { return };
        let (dead, borrows) = match st.get(v) {
            Some(val) => (val.dead, val.borrows.clone()),
            None => return,
        };
        if dead.is_some() {
            self.finding(Cat::UseAfterFree, v, sp);
        }
        for w in &borrows {
            if st.get(w).is_some_and(|wv| wv.dead.is_some()) {
                self.finding(Cat::UseAfterFree, v, sp); // dangling interior alias
            }
        }
    }

    fn kill(&mut self, v: &str, cat: Cat, st: &mut State) {
        if let Some(val) = st.get_mut(v) {
            if val.dead.is_none() {
                val.dead = Some(cat);
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::core::RecordInfo;

    fn one(f: CoreFn) -> Vec<Finding> {
        verify(&Lowered {
            fns: vec![f],
            borrow_args: BorrowArgs::new(),
            recinfo: RecordInfo::default(),
        })
    }

    fn fn_body(body: Term) -> CoreFn {
        CoreFn {
            name: "t".into(),
            params: vec![],
            captures: vec![],
            is_closure: false,
            owned_params: vec![],
            owned_drop_ty: vec![],
            body,
        }
    }

    /// The verifier CATCHES a double-free (the other half of its validation: the fixture
    /// gate proves no false positives, this proves it isn't vacuously silent).
    #[test]
    fn flags_double_free() {
        // let x = (1, 2);  drop x;  drop x;  ret 0
        let body = Term::Let(
            "x".into(),
            Rhs::Op(Op::MakeTuple(vec![Atom::Int(1), Atom::Int(2)])),
            (0, 0),
            Box::new(Term::Drop(
                "x".into(),
                None,
                vec![],
                (0, 0),
                Box::new(Term::Drop(
                    "x".into(),
                    None,
                    vec![],
                    (0, 0),
                    Box::new(Term::Ret(Rhs::Op(Op::Atom(Atom::Int(0))), (0, 0))),
                )),
            )),
        );
        let fs = one(fn_body(body));
        assert!(
            fs.iter().any(|f| f.cat == Cat::DoubleFree),
            "expected a DoubleFree finding, got {fs:?}"
        );
    }

    /// The verifier CATCHES using a value after it is dropped.
    #[test]
    fn flags_use_after_free() {
        // let x = (1, 2);  drop x;  ret (x)   -- x used after free
        let body = Term::Let(
            "x".into(),
            Rhs::Op(Op::MakeTuple(vec![Atom::Int(1), Atom::Int(2)])),
            (0, 0),
            Box::new(Term::Drop(
                "x".into(),
                None,
                vec![],
                (0, 0),
                Box::new(Term::Ret(Rhs::Op(Op::Atom(Atom::Var("x".into()))), (0, 0))),
            )),
        );
        let fs = one(fn_body(body));
        assert!(
            fs.iter().any(|f| f.cat == Cat::UseAfterFree),
            "expected a UseAfterFree finding, got {fs:?}"
        );
    }

    /// A well-balanced function (allocate, use, drop once) produces no corruption finding.
    #[test]
    fn clean_alloc_drop_is_ok() {
        // let x = (1, 2);  drop x;  ret 0
        let body = Term::Let(
            "x".into(),
            Rhs::Op(Op::MakeTuple(vec![Atom::Int(1), Atom::Int(2)])),
            (0, 0),
            Box::new(Term::Drop(
                "x".into(),
                None,
                vec![],
                (0, 0),
                Box::new(Term::Ret(Rhs::Op(Op::Atom(Atom::Int(0))), (0, 0))),
            )),
        );
        let fs = one(fn_body(body));
        assert!(
            !fs.iter().any(|f| f.cat.is_corruption()),
            "unexpected corruption finding: {fs:?}"
        );
    }
}
