//! `--emit model-trace` — M2 whole-fragment faithfulness bridge (metatheory/bridge.md widening).
//!
//! For each Core function that lies in the **AxionDrop owned-set fragment** (alloc/use/drop/moveOut
//! /branch), this translates its final drop-inserted Core into an `AxionDrop.Expr` term and emits a
//! Lean line
//!
//! ```lean
//! example : AxionDrop.acceptsL (<term>) = <verify-verdict> := by rfl
//! ```
//!
//! `AxionDrop.acceptsL` is the executable checker proven (`AxionDrop.chk_correct`) to decide the
//! relational `accepts`, which `AxionDrop.sound` proves memory-safe + leak-free. Its `brn` compares
//! OWNED-SETS (not full state), matching `verify.rs`'s `merge_vals`, so arms that move out different
//! numbers of temporaries still balance (the `build n = if _ then LNil else LCons n (build (n-1))`
//! shape). So if Lean accepts every emitted `example`, the model's OWN judgment machine-checks to
//! AGREE with the real verifier on every in-fragment function — the whole-fragment upgrade over the
//! 8 curated shapes.
//!
//! An OWNED-scrutinee heap-extracting `case` IS in-fragment: `verify.rs::bind_pattern` transfers each
//! CONCRETE-heap field OUT as a fresh owned resource, modeled here as an `alloc` per extracted field
//! (the arm then drops/moves it). A BORROWED-scrutinee peel (interior-alias fields → `bref`) is NOT —
//! it needs `AxionExtract`.
//!
//! SOUNDNESS OF THE BRIDGE rests on the fragment classification being HONEST: the translator is
//! CONSERVATIVE — any construct outside its vocabulary (a borrowed-scrutinee `case`, a closure, an
//! interior-`Field` alias, an array/arena/session op, a record update, a borrowed-param escape, or a
//! conditional/case bound in a `let`) makes the function OUT of fragment (skipped and counted), never
//! mistranslated. A shrinking in-model fraction is a visible finding, not a silent pass.

use crate::core::{Atom, BorrowArgs, CPat, CoreFn, Lowered, Op, RecordInfo, Rhs, Term};
use crate::delta::op_delta_effect;
use std::collections::{HashMap, HashSet};

/// A model op (mirror of `AxionMove.Op`).
enum MOp {
    Alloc(u32),
    Use(u32),
    Drop(u32),
    MoveOut(u32),
}

/// A model expression (mirror of `AxionMove.Expr`).
enum MExpr {
    Done,
    Op(MOp, Box<MExpr>),
    Brn(Box<MExpr>, Box<MExpr>, Box<MExpr>),
}

/// Same exclusion the verifier uses: hand-written destructors / deep-copiers are not Auto-Drop
/// output, so they are never in the fragment.
fn is_generated(name: &str) -> bool {
    name.starts_with("axion_drop_") || name.starts_with("axion_copy_")
}

struct Tr<'a> {
    ba: &'a BorrowArgs,
    recinfo: &'a RecordInfo,
    /// heap variables currently tracked → their model cell id.
    ids: HashMap<String, u32>,
    /// cell ids of BORROWED heap params (caller-owned, use-only). Moving one OUT (returning/aliasing
    /// a borrow) is the AxionAlias borrow-return class, outside this fragment — so it is rejected.
    borrowed: HashSet<u32>,
    next: u32,
}

impl Tr<'_> {
    fn fresh(&mut self) -> u32 {
        let n = self.next;
        self.next += 1;
        n
    }

    /// Translate one leaf op. `bind = Some(x)` if the result is `let`-bound to `x`; `None` if it is
    /// the returned/escaping result. Emits operand effects (borrow→use, move/alias→moveOut) then
    /// the produced heap result (alloc). `Err(reason)` if the op is outside the fragment.
    fn tr_op(&mut self, op: &Op, bind: Option<&str>) -> Result<Vec<MOp>, &'static str> {
        // Whitelist: only the pure-data / call / build ops map to alloc/use/moveOut. Everything
        // else is out of the AxionDrop fragment — tagged with a reason for the coverage breakdown.
        match op {
            Op::Atom(_)
            | Op::Prim(..)
            | Op::PrimF(..)
            | Op::IntToFloat(_)
            | Op::FloatToInt(_)
            | Op::FloatUnary(..)
            | Op::CallDirect(..)
            | Op::MakeCon { .. }
            | Op::MakeTuple(_)
            | Op::MakeRecord { .. }
            | Op::ShowInt(_)
            | Op::PutStr(_)
            | Op::PutStrLn(_) => {}
            Op::MakeClosure { .. } | Op::CallClosure(..) => return Err("closure"),
            Op::Field { .. } => return Err("field-alias (borrow)"),
            Op::UpdateRecord { .. } => return Err("record-update"),
            Op::ArrayNew { .. } => return Err("array"),
            Op::WithArena { .. }
            | Op::ArenaAlloc(_)
            | Op::Promote(..)
            | Op::ArenaMark(_)
            | Op::ArenaRelease(_) => return Err("arena"),
            Op::RtCall { .. } => return Err("rtcall/session"),
            Op::Ffi { .. } => return Err("ffi"),
            Op::LoadRaw(..) | Op::StoreRaw(..) | Op::FuncAddr(_) | Op::Unsupported(_) => {
                return Err("raw/unsupported")
            }
        }
        let e = op_delta_effect(op, self.ba);
        // A produced result belonging to a PARENT is a case-extracted payload (AxionKey/Alias
        // territory) — out of the AxionDrop fragment.
        if let Some(res) = &e.produces {
            if res.parent.is_some() {
                return Err("payload-extraction (key)");
            }
        }
        let mut ops = Vec::new();
        // borrows → `use` (heap operands only)
        for a in &e.borrows {
            if let Atom::Var(v) = a {
                if let Some(&id) = self.ids.get(v) {
                    ops.push(MOp::Use(id));
                }
            }
        }
        // moves + alias → `moveOut` (ownership leaves this frame)
        for a in e.moves.iter().chain(e.alias.iter()) {
            if let Atom::Var(v) = a {
                if let Some(&id) = self.ids.get(v) {
                    // Moving out a BORROWED param = returning/aliasing a borrow (AxionAlias's
                    // borrow-return class), which this owned-set fragment does not model.
                    if self.borrowed.contains(&id) {
                        return Err("borrowed-param escape (alias-return)");
                    }
                    self.ids.remove(v);
                    ops.push(MOp::MoveOut(id));
                }
            }
        }
        // produced heap result
        if e.produces.is_some() {
            match bind {
                Some(x) => {
                    let id = self.fresh();
                    self.ids.insert(x.to_string(), id);
                    ops.push(MOp::Alloc(id));
                }
                None => {
                    // escaping result: allocate then transfer out (returned to caller).
                    let id = self.fresh();
                    ops.push(MOp::Alloc(id));
                    ops.push(MOp::MoveOut(id));
                }
            }
        }
        Ok(ops)
    }

    fn tr_term(&mut self, t: &Term) -> Result<MExpr, &'static str> {
        match t {
            Term::Let(x, Rhs::Op(op), _, k) => {
                let ops = self.tr_op(op, Some(x))?;
                let rest = self.tr_term(k)?;
                Ok(prepend(ops, rest))
            }
            // A conditional/case bound in a `let` needs result-threading the model does not do here.
            Term::Let(_, Rhs::If(..), _, _) => Err("let-bound if"),
            Term::Let(_, Rhs::Case(..), _, _) => Err("case"),
            Term::Drop(x, _, _, _, k) => {
                let id = self.ids.remove(x).ok_or("drop of untracked var")?;
                let rest = self.tr_term(k)?;
                Ok(MExpr::Op(MOp::Drop(id), Box::new(rest)))
            }
            Term::Ret(Rhs::Op(op), _) => {
                let ops = self.tr_op(op, None)?;
                Ok(prepend(ops, MExpr::Done))
            }
            // Tail branch: both arms run from the SAME incoming state (clone the id map per arm);
            // the join continuation is `done`, so post-branch state is irrelevant.
            Term::Ret(Rhs::If(_, tt, ee), _) => {
                let saved = self.ids.clone();
                let saved_next = self.next;
                let at = self.tr_term(tt)?;
                self.ids = saved.clone();
                self.next = saved_next;
                let ae = self.tr_term(ee)?;
                self.ids = saved;
                Ok(MExpr::Brn(
                    Box::new(at),
                    Box::new(ae),
                    Box::new(MExpr::Done),
                ))
            }
            // A tail `case`. Two in-fragment sub-cases:
            //   (1) all arms NON-EXTRACTING (`Int`/wildcard): pure scalar/tag dispatch → right-nested
            //       `brn` (all arms must reach the same owned-set — the N-way `merge_vals`).
            //   (2) OWNED-scrutinee heap extraction (`case xs of Cons y ys -> …`, `xs` an owned/`%1`
            //       heap value): per `verify.rs::bind_pattern`, each CONCRETE-heap field transfers OUT
            //       as a fresh OWNED resource (a child of the scrutinee) — modeled as `alloc`; the arm
            //       then drops/moves each child and drops the scrutinee shell, exactly balancing.
            //       POLYMORPHIC fields (bare type var, no concrete drop slot) are leak-exempt and left
            //       untracked (matching the verifier). A BORROWED-scrutinee peel makes the fields
            //       interior aliases (`bref`) — that needs `AxionExtract` and stays out of THIS
            //       (AxionDrop owned-set) fragment.
            Term::Ret(Rhs::Case(scrut, arms), _) => {
                if arms.iter().all(|(p, _)| is_trivial_pat(p)) {
                    let saved = self.ids.clone();
                    let saved_next = self.next;
                    let mut arm_exprs = Vec::new();
                    for (i, (_, body)) in arms.iter().enumerate() {
                        if i > 0 {
                            self.ids = saved.clone();
                            self.next = saved_next;
                        }
                        arm_exprs.push(self.tr_term(body)?);
                    }
                    self.ids = saved;
                    return Ok(nest_arms(arm_exprs));
                }
                // (2) heap extraction — require an OWNED tracked heap scrutinee.
                let sid = match scrut {
                    Atom::Var(s) => *self
                        .ids
                        .get(s)
                        .ok_or("case scrutinee not an owned heap value")?,
                    _ => return Err("case scrutinee not a var"),
                };
                if self.borrowed.contains(&sid) {
                    return Err("borrowed-scrutinee extraction");
                }
                let saved = self.ids.clone();
                let saved_next = self.next;
                let mut arm_exprs = Vec::new();
                for (i, (pat, body)) in arms.iter().enumerate() {
                    if i > 0 {
                        self.ids = saved.clone();
                        self.next = saved_next;
                    }
                    // Introduce each CONCRETE-heap extracted field as a fresh owned resource (the arm
                    // body's own drop/move reclaims it; the scrutinee shell is dropped there too).
                    let mut pre = Vec::new();
                    match pat {
                        CPat::Int(_) | CPat::Wild => {}
                        CPat::Con(con, subs) => {
                            for (fi, sub) in subs.iter().enumerate() {
                                match sub {
                                    CPat::Var(v) if self.recinfo.field_is_heap(con, fi) => {
                                        let id = self.fresh();
                                        self.ids.insert(v.clone(), id);
                                        pre.push(MOp::Alloc(id));
                                    }
                                    // poly (no concrete slot) or scalar field: untracked, like the verifier.
                                    CPat::Var(_) | CPat::Wild | CPat::Int(_) => {}
                                    _ => return Err("nested extraction pattern"),
                                }
                            }
                        }
                        _ => return Err("case extraction pattern"),
                    }
                    let arm_body = self.tr_term(body)?;
                    arm_exprs.push(prepend(pre, arm_body));
                }
                self.ids = saved;
                Ok(nest_arms(arm_exprs))
            }
        }
    }
}

/// A pattern that binds no heap payload — pure scalar/tag dispatch, safe for the owned-set fragment.
fn is_trivial_pat(p: &CPat) -> bool {
    matches!(p, CPat::Int(_) | CPat::Wild)
}

/// Fold case arms (each translated from the same incoming state) into a right-nested two-armed
/// `brn`, which requires every arm to reach the same owned-set — the N-way `merge_vals`.
fn nest_arms(arms: Vec<MExpr>) -> MExpr {
    let mut it = arms.into_iter();
    match it.next() {
        None => MExpr::Done,
        Some(first) => {
            let rest: Vec<MExpr> = it.collect();
            if rest.is_empty() {
                first
            } else {
                MExpr::Brn(
                    Box::new(first),
                    Box::new(nest_arms(rest)),
                    Box::new(MExpr::Done),
                )
            }
        }
    }
}

fn prepend(ops: Vec<MOp>, tail: MExpr) -> MExpr {
    let mut e = tail;
    for op in ops.into_iter().rev() {
        e = MExpr::Op(op, Box::new(e));
    }
    e
}

/// Translate a whole function, or `Err(reason)` if it is outside the fragment. Returns the model
/// expression AND the borrowed-param set `B` (cell ids of the heap parameters the caller owns).
/// Owned (`%1`) heap params enter as pre-allocated live cells (they must be dropped or moved out by
/// exit); BORROWED heap params enter in `B` (readable, never freed by this frame — `AxionDrop`'s
/// borrowed-cell modelling, sound by `AxionDrop.sound`).
fn tr_fn(f: &CoreFn, lowered: &Lowered) -> Result<(MExpr, Vec<u32>), &'static str> {
    if is_generated(&f.name) {
        return Err("generated");
    }
    let pkeys = lowered.param_keys.get(&f.name);
    // Conservative: without per-param key info we cannot classify a heap param as owned vs borrowed.
    if pkeys.is_none() && !f.params.is_empty() {
        return Err("no param-key info");
    }
    let owned: HashSet<&String> = f.owned_params.iter().collect();
    let mut tr = Tr {
        ba: &lowered.borrow_args,
        recinfo: &lowered.recinfo,
        ids: HashMap::new(),
        borrowed: HashSet::new(),
        next: 0,
    };
    let mut param_ops = Vec::new();
    let mut borrowed = Vec::new();
    if let Some(keys) = pkeys {
        for (i, p) in f.params.iter().enumerate() {
            let is_heap = keys.get(i).is_some_and(|k| k.is_some());
            if is_heap {
                let id = tr.fresh();
                tr.ids.insert(p.clone(), id);
                if owned.contains(p) {
                    param_ops.push(MOp::Alloc(id)); // owned: starts live, must be freed/moved out
                } else {
                    tr.borrowed.insert(id);
                    borrowed.push(id); // borrowed: caller-owned, use-only, not a leak
                }
            }
        }
    }
    let body = tr.tr_term(&f.body)?;
    Ok((prepend(param_ops, body), borrowed))
}

fn mop_lean(op: &MOp) -> String {
    match op {
        MOp::Alloc(n) => format!(".alloc {n}"),
        MOp::Use(n) => format!(".use {n}"),
        MOp::Drop(n) => format!(".drop {n}"),
        MOp::MoveOut(n) => format!(".moveOut {n}"),
    }
}

fn mexpr_lean(e: &MExpr) -> String {
    match e {
        MExpr::Done => ".done".to_string(),
        MExpr::Op(op, k) => format!(".op ({}) ({})", mop_lean(op), mexpr_lean(k)),
        MExpr::Brn(t, e, k) => format!(
            ".brn ({}) ({}) ({})",
            mexpr_lean(t),
            mexpr_lean(e),
            mexpr_lean(k)
        ),
    }
}

/// Emit the Lean bridge examples for every in-fragment function, plus a coverage summary. The
/// output is appended (by `bridge.sh`) to a copy of `metatheory/AxionMove.lean` and type-checked:
/// every `by rfl` that holds is one function on which the executable model verdict equals the real
/// verifier's verdict.
pub fn emit_model_trace(lowered: &Lowered) -> String {
    let findings = crate::verify::verify(lowered);
    let mut reject: HashSet<String> = HashSet::new();
    for f in &findings {
        if f.cat.is_corruption() || crate::verify::leak_gates(f) {
            reject.insert(f.func.clone());
        }
    }

    let mut body = String::new();
    let mut reasons: HashMap<&'static str, usize> = HashMap::new();
    let mut total = 0usize;
    let mut inmodel = 0usize;

    for f in &lowered.fns {
        if is_generated(&f.name) {
            continue;
        }
        total += 1;
        match tr_fn(f, lowered) {
            Ok((mexpr, borrowed)) => {
                inmodel += 1;
                let accept = !reject.contains(&f.name);
                let blist = borrowed
                    .iter()
                    .map(|b| b.to_string())
                    .collect::<Vec<_>>()
                    .join(", ");
                body.push_str(&format!(
                    "-- fn `{}`: verifier = {}\n",
                    f.name,
                    if accept { "accept" } else { "reject" }
                ));
                body.push_str(&format!(
                    "example : AxionDrop.acceptsL [{}] ({}) = {} := by rfl\n",
                    blist,
                    mexpr_lean(&mexpr),
                    if accept { "true" } else { "false" }
                ));
            }
            Err(reason) => *reasons.entry(reason).or_insert(0) += 1,
        }
    }

    let mut out = String::new();
    out.push_str(&format!(
        "-- model-trace coverage: {inmodel} in-model of {total} corpus function(s)\n"
    ));
    if !reasons.is_empty() {
        let mut rs: Vec<_> = reasons.into_iter().collect();
        rs.sort_by_key(|&(_, n)| std::cmp::Reverse(n));
        out.push_str("-- out of fragment by reason (honestly excluded, not mistranslated):\n");
        for (reason, n) in rs {
            out.push_str(&format!("--   {n:>4}  {reason}\n"));
        }
    }
    out.push_str(&body);
    out
}
