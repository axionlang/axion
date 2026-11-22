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
//! A heap-extracting `case` IS in-fragment (both scrutinee kinds), mirroring `verify.rs::bind_pattern`:
//! for an OWNED scrutinee each CONCRETE-heap field transfers OUT as a fresh owned resource (`alloc`;
//! the arm then drops/moves it); for a BORROWED scrutinee each is an interior ALIAS, modeled as an
//! extra `borrowed` (B) cell — use OK, move/drop rejected, never a leak (sound because a borrowed
//! param's owner is never freed in-frame). POLYMORPHIC fields (no concrete drop slot) are left
//! untracked, exactly as the verifier's leak-exempt policy.
//!
//! SOUNDNESS OF THE BRIDGE rests on the fragment classification being HONEST: the translator is
//! CONSERVATIVE — any construct outside its vocabulary (a closure, an interior-`Field` alias, an
//! array/arena/session op, a record update, a borrowed-value ESCAPE (move-out of a borrow), or an
//! owned-tuple pattern) makes the function OUT of fragment (skipped and counted), never
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
    name.starts_with("axion_drop_")
        || name.starts_with("axion_copy_")
        || name.starts_with(crate::core::ARROP)
}

struct Tr<'a> {
    ba: &'a BorrowArgs,
    recinfo: &'a RecordInfo,
    /// heap variables currently tracked → their model cell id.
    ids: HashMap<String, u32>,
    /// cell ids of BORROWED heap cells (caller-owned, use-only): borrowed params AND fields extracted
    /// from a borrowed scrutinee (interior aliases — use OK, move/drop rejected, never a leak). They
    /// seed `AxionDrop.acceptsL [B]` as `borrowed`. Moving one OUT is the AxionAlias borrow-return
    /// class, outside this fragment — so it is rejected.
    borrowed: HashSet<u32>,
    /// cell ids bound from a CALL (`CallDirect`/`CallClosure`): a callee may return an interior
    /// alias of an arg (`grabHead xs = Just (head-of-xs)`), which the owned-set model cannot verify
    /// as alias-free. So `case`-extracting fields from a call-result scrutinee is out of fragment
    /// (the `user_alias_borrow` interprocedural double-free). A param or locally-built scrutinee
    /// (foldl's `xs`) is NOT suspect — its ownership is manifest.
    alias_suspect: HashSet<u32>,
    next: u32,
    /// a SEPARATE high id space for borrowed extracted fields, so their ids never collide with the
    /// per-arm-reused owned `next` ids (an id can't be both owned-`alloc`ed and seeded `borrowed`).
    borrow_next: u32,
    /// OWNED scrutinee var → the constructor of the `case` arm being translated. A raw field load
    /// `loadraw s+off` inside the arm is Auto-Drop's per-field drop of a wildcard-discarded heap
    /// field (`emit_per_field_drops`): it extracts that one slot, exactly as a pattern variable
    /// would (`verify.rs::bind_raw_field`), so it translates to the same `alloc` of an owned child.
    arm_con: HashMap<String, String>,
    /// the highest owned id handed out so far, so the code after a join never reuses an id an arm
    /// allocated (arms each restart `next` from the same point).
    hi: u32,
    /// while translating the arms of a `let x = if …`/`let x = case …`: where each arm's result
    /// goes (see `ResultSink`).
    result: Option<ResultSink>,
    /// params the verifier seeds as owning nothing (not `%1`, never freed, no heap key: a generic
    /// `List a` param): a `case` on one binds its heap fields as interior aliases, exactly as a
    /// borrowed scrutinee — so it becomes a borrowed (B) cell when first scrutinized.
    lent_params: HashSet<String>,
    /// each param's container key (`tuple2$String$Int`), as the verifier seeds it.
    keys: HashMap<String, String>,
}

/// The arms of a `let`-bound conditional each end in a result. A heap result is the cell `rid`
/// in every arm, so the join compares like for like and the code after it owns `x` = `rid`.
/// `heap` records, per arm leaf, whether that leaf's result is heap; mixed arms are out of
/// fragment (a scalar arm and a heap arm cannot both be modeled as one cell).
struct ResultSink {
    rid: u32,
    heap: Vec<bool>,
    /// some arm's result came from a call (a possible interprocedural alias, as for a `let`).
    suspect: bool,
}

impl Tr<'_> {
    fn fresh(&mut self) -> u32 {
        let n = self.next;
        self.next += 1;
        self.hi = self.hi.max(self.next);
        n
    }

    /// The result of a `let`-bound conditional's arm, in place of a return: a produced heap value,
    /// or an owned variable handed on as the result (`if c then y else …`), becomes the shared
    /// result cell; a scalar result becomes nothing.
    fn tr_result_leaf(&mut self, op: &Op) -> Result<MExpr, &'static str> {
        let e = op_delta_effect(op, self.ba);
        let produced = e.produces.is_some();
        let owned_alias = matches!(e.alias, Some(Atom::Var(v))
            if self.ids.get(v).is_some_and(|id| !self.borrowed.contains(id)));
        let mut ops = self.tr_op(op, None)?;
        let sink = self.result.as_mut().ok_or("result outside a branch")?;
        if produced {
            // `tr_op` emitted `alloc k; moveOut k` for an escaping result: it is `rid` instead.
            match (ops.pop(), ops.pop()) {
                (Some(MOp::MoveOut(a)), Some(MOp::Alloc(b))) if a == b => {}
                _ => return Err("let-bound branch result"),
            }
            ops.push(MOp::Alloc(sink.rid));
            sink.suspect |= matches!(op, Op::CallDirect(..) | Op::CallClosure(..));
        } else if owned_alias {
            ops.push(MOp::Alloc(sink.rid)); // after `tr_op`'s `moveOut` of the variable
        }
        sink.heap.push(produced || owned_alias);
        Ok(prepend(ops, MExpr::Done))
    }

    /// `let x = <if/case> in k`: the arms, each ending in the result cell, joined, then `k`.
    fn tr_let_branch(&mut self, x: &str, rhs: &Rhs, k: &Term) -> Result<MExpr, &'static str> {
        let rid = self.fresh();
        let outer = self.result.replace(ResultSink {
            rid,
            heap: Vec::new(),
            suspect: false,
        });
        let branch = self.tr_branch(rhs);
        let sink = std::mem::replace(&mut self.result, outer).ok_or("let-bound branch")?;
        let branch = branch?;
        self.next = self.hi;
        match (sink.heap.iter().all(|h| *h), sink.heap.iter().any(|h| *h)) {
            (true, true) => {
                self.ids.insert(x.to_string(), rid);
                if sink.suspect {
                    self.alias_suspect.insert(rid);
                }
            }
            (_, false) => {}
            _ => return Err("let-bound branch with mixed results"),
        }
        let rest = self.tr_term(k)?;
        Ok(seq(branch, rest))
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
            | Op::Vec(..)
            | Op::CallDirect(..)
            | Op::MakeCon { .. }
            | Op::MakeTuple(_)
            | Op::MakeRecord { .. }
            | Op::ShowInt(_)
            | Op::PutStr(_)
            | Op::PutStrLn(_)
            // A closure CALL moves its args (→ `moveOut`) and BORROWS the closure (→ `use`).
            | Op::CallClosure(..) => {}
            // A closure produces its cell (→ `alloc`), dropped by Auto-Drop after its last call or
            // moved out when it escapes. A closure over a TRACKED heap value borrows it until its
            // last call — an interior borrow the owned-set fragment does not model (AxionAlias).
            Op::MakeClosure { captures, .. } => {
                if captures
                    .iter()
                    .any(|a| matches!(a, Atom::Var(v) if self.ids.contains_key(v)))
                {
                    return Err("closure-borrow (alias)");
                }
            }
            Op::Field { .. } => return Err("field-alias (borrow)"),
            Op::UpdateRecord { .. } => return Err("record-update"),
            Op::ArrayNew { .. } => return Err("array"),
            Op::WithArena { .. }
            | Op::ArenaAlloc(_)
            | Op::Promote(..)
            | Op::ArenaMark(_)
            | Op::ArenaRelease(_) => return Err("arena"),
            // Session/socket/concurrency runtime ops model channel/fd state, not heap ownership —
            // genuinely out of the drop fragment. EVERY other rtcall (string/IO/capability builtin:
            // axion_strcat/getenv/read_file/exec/…) has a clean heap-drop effect that
            // `op_delta_effect` already classifies — the SAME authority verify.rs uses — so it
            // translates generically below, exactly like a `CallDirect`.
            Op::RtCall { func, .. }
                if func.starts_with("axion_sess_")
                    || func.starts_with("ax_net_")
                    || func == "axion_par_map" =>
            {
                return Err("session/socket op")
            }
            Op::RtCall { .. } => {}
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
        // borrows (and an indirect call's closure) → `use` (heap operands only)
        for a in e.borrows.iter().chain(e.nonstrict.iter()) {
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
        // produced heap result (a closure cell included: it is reclaimed like any allocation).
        if e.produces.is_some() {
            match bind {
                Some(x) => {
                    let id = self.fresh();
                    self.ids.insert(x.to_string(), id);
                    ops.push(MOp::Alloc(id));
                    // A call result may carry an interior alias of an arg — mark it so a later `case`
                    // on it does not mistake its extracted fields for owned (the owned-set model
                    // cannot see interprocedural aliasing; the verifier's summaries can).
                    if matches!(op, Op::CallDirect(..) | Op::CallClosure(..)) {
                        self.alias_suspect.insert(id);
                    }
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
            // a raw load of a field of an owned scrutinee inside its `case` arm: per-slot extraction.
            Term::Let(x, Rhs::Op(Op::LoadRaw(Atom::Var(src), off)), _, k)
                if self.arm_con.contains_key(src) =>
            {
                let con = self.arm_con[src].clone();
                let arity = self.recinfo.con_arity(&con).unwrap_or(0);
                let fi = (0..arity)
                    .find(|&fi| self.recinfo.field_offset(&con, fi) == *off)
                    .ok_or("raw/unsupported")?;
                let mut pre = Vec::new();
                if self.recinfo.field_is_heap(&con, fi) || dropped_within(x, k) {
                    let id = self.fresh();
                    self.ids.insert(x.clone(), id);
                    pre.push(MOp::Alloc(id));
                }
                let rest = self.tr_term(k)?;
                Ok(prepend(pre, rest))
            }
            Term::Let(x, Rhs::Op(op), _, k) => {
                let ops = self.tr_op(op, Some(x))?;
                let rest = self.tr_term(k)?;
                Ok(prepend(ops, rest))
            }
            // A conditional/case bound in a `let`: its arms deliver one result cell (`ResultSink`).
            Term::Let(x, rhs @ (Rhs::If(..) | Rhs::Case(..)), _, k) => {
                self.tr_let_branch(x, rhs, k)
            }
            Term::Drop(x, _, _, _, k) => {
                let id = self.ids.remove(x).ok_or("drop of untracked var")?;
                let rest = self.tr_term(k)?;
                Ok(MExpr::Op(MOp::Drop(id), Box::new(rest)))
            }
            Term::Ret(Rhs::Op(op), _) if self.result.is_some() => self.tr_result_leaf(op),
            Term::Ret(Rhs::Op(op), _) => {
                let ops = self.tr_op(op, None)?;
                Ok(prepend(ops, MExpr::Done))
            }
            Term::Ret(rhs, _) => self.tr_branch(rhs),
        }
    }

    fn tr_branch(&mut self, rhs: &Rhs) -> Result<MExpr, &'static str> {
        match rhs {
            Rhs::Op(_) => Err("not a branch"),
            // Tail branch: both arms run from the SAME incoming state (clone the id map per arm);
            // the join continuation is `done`, so post-branch state is irrelevant.
            Rhs::If(_, tt, ee) => {
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
            Rhs::Case(scrut, arms) => {
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
                // (2) heap extraction. `scrut_borrowed` selects the two field treatments, EXACTLY as
                // `verify.rs::bind_pattern`: an OWNED scrutinee transfers each concrete-heap field out
                // as a fresh OWNED resource (`alloc`); a BORROWED scrutinee makes each an interior
                // ALIAS — modeled as an additional `borrowed` (B) cell (use OK, move/drop rejected,
                // never a leak — sound because a borrowed PARAM's owner is never freed in-frame, so
                // there is no dangling-alias hazard that `bref` would otherwise guard).
                let sid = match scrut {
                    Atom::Var(s) => match self.ids.get(s) {
                        Some(id) => *id,
                        None if self.lent_params.contains(s) => {
                            let id = self.borrow_next;
                            self.borrow_next += 1;
                            self.ids.insert(s.clone(), id);
                            self.borrowed.insert(id);
                            id
                        }
                        None => return Err("case scrutinee not an owned heap value"),
                    },
                    _ => return Err("case scrutinee not a var"),
                };
                // An alias-carrying scrutinee (from a ret-alias call): its extracted fields are
                // interprocedural aliases the owned-set model cannot represent — out of fragment.
                if self.alias_suspect.contains(&sid) {
                    return Err("case on an interprocedural alias");
                }
                let scrut_borrowed = self.borrowed.contains(&sid);
                let saved = self.ids.clone();
                let saved_next = self.next;
                let mut arm_exprs = Vec::new();
                for (i, (pat, body)) in arms.iter().enumerate() {
                    if i > 0 {
                        self.ids = saved.clone();
                        self.next = saved_next;
                    }
                    let mut pre = Vec::new();
                    match pat {
                        CPat::Int(_) | CPat::Wild => {}
                        CPat::Con(con, subs) => {
                            for (fi, sub) in subs.iter().enumerate() {
                                match sub {
                                    CPat::Var(v) => {
                                        let field_heap = self.recinfo.field_is_heap(con, fi);
                                        if scrut_borrowed {
                                            // interior alias of a borrowed scrutinee → a B cell (high
                                            // id space; accumulated across arms into the final B). A
                                            // borrowed poly field stays untracked (AxionExtract
                                            // territory), as before.
                                            if field_heap {
                                                let id = self.borrow_next;
                                                self.borrow_next += 1;
                                                self.ids.insert(v.clone(), id);
                                                self.borrowed.insert(id);
                                            }
                                        } else if field_heap || dropped_within(v, body) {
                                            // Owned child transferred out of the scrutinee: heap by
                                            // static type, OR a polymorphic field the SPECIALIZED arm
                                            // actually consumes as a concrete heap resource (`drop y :
                                            // Integer`) — exactly what the verifier tracks. A poly
                                            // field instantiated to a SCALAR is not consumed → stays
                                            // untracked (leak-exempt), matching the verifier.
                                            let id = self.fresh();
                                            self.ids.insert(v.clone(), id);
                                            pre.push(MOp::Alloc(id));
                                        }
                                    }
                                    // scalar field / unconsumed poly: untracked, like the verifier.
                                    CPat::Wild | CPat::Int(_) => {}
                                    _ => return Err("nested extraction pattern"),
                                }
                            }
                        }
                        // A BORROWED tuple, as `verify.rs::bind_pattern`: when its key segments, each
                        // heap field is an interior alias (a B cell) and a scalar one untracked;
                        // when it does not, every field is tracked as an alias. (An OWNED tuple's
                        // fields are freed by the tuple's deep drop — not modeled here.)
                        CPat::Tuple(subs) if scrut_borrowed => {
                            let field_keys = match scrut {
                                Atom::Var(sv) => self
                                    .keys
                                    .get(sv)
                                    .and_then(|k| self.recinfo.split_tuple_key(k, subs.len())),
                                _ => None,
                            };
                            for (fi, sub) in subs.iter().enumerate() {
                                match sub {
                                    CPat::Var(v) => {
                                        let track = field_keys.as_ref().is_none_or(|ks| {
                                            ks.get(fi).is_some_and(|el| {
                                                self.recinfo.classify_tuple_elem(el).is_some()
                                            })
                                        });
                                        if track {
                                            let id = self.borrow_next;
                                            self.borrow_next += 1;
                                            self.ids.insert(v.clone(), id);
                                            self.borrowed.insert(id);
                                        }
                                    }
                                    CPat::Wild => {}
                                    _ => return Err("nested extraction pattern"),
                                }
                            }
                        }
                        _ => return Err("case extraction pattern"),
                    }
                    // the arm's constructor, for raw field loads of an OWNED scrutinee inside it.
                    let raw_ctx = match (scrut, pat) {
                        (Atom::Var(sv), CPat::Con(con, _)) if !scrut_borrowed => {
                            self.arm_con.insert(sv.clone(), con.clone());
                            Some(sv.clone())
                        }
                        _ => None,
                    };
                    let arm_body = self.tr_term(body);
                    if let Some(sv) = raw_ctx {
                        self.arm_con.remove(&sv);
                    }
                    let arm_body = arm_body?;
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

/// Is `v` FREED by a `drop` somewhere in `t`? A `drop` is Auto-Drop's reclaim of an owned HEAP
/// resource — scalars are NEVER dropped — so a `drop v` is a reliable signal that `v` is an owned
/// heap cell this frame must account for, even when `v`'s STATIC type is polymorphic (`foldl`'s
/// accumulator `b`, a `Cons` element in `List a`) but the SPECIALIZED Core drops it as a concrete
/// heap value (`drop z : Integer`). `field_is_heap` (concrete-only) misses that; the drop does not.
///
/// We deliberately do NOT treat a MOVE as the signal — that was unsound: a SCALAR operand also
/// "moves" into a constructor/recursive call (`Cons lo …`, `range (lo+1) hi`), so keying on moves
/// alloc'd scalars as heap and leaked them on branches that don't re-move them. And an owned heap
/// value that is only moved OUT (never dropped) needs no model cell at all — leaving it untracked is
/// already balanced (no alloc, no free), and `tr_op` skips the move of an untracked var. Sound either
/// way: miss a drop → the later `drop v` bails the function out of fragment (never mistranslated); a
/// spurious alloc → an un-freed cell leaks in the model → the `by rfl` fails and model-trace.sh
/// reports it (never a silent unsound pass).
fn dropped_within(v: &str, t: &Term) -> bool {
    match t {
        Term::Drop(x, _, _, _, k) => x == v || dropped_within(v, k),
        Term::Let(_, rhs, _, k) => rhs_drops(v, rhs) || dropped_within(v, k),
        Term::Ret(rhs, _) => rhs_drops(v, rhs),
    }
}

fn rhs_drops(v: &str, rhs: &Rhs) -> bool {
    match rhs {
        Rhs::Op(_) => false,
        Rhs::If(_, tt, ee) => dropped_within(v, tt) || dropped_within(v, ee),
        Rhs::Case(_, arms) => arms.iter().any(|(_, b)| dropped_within(v, b)),
    }
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

/// `e` then `k` (Lean's `AxionDrop.seq`): `k` replaces `e`'s final `done`, after any join.
fn seq(e: MExpr, k: MExpr) -> MExpr {
    match e {
        MExpr::Done => k,
        MExpr::Op(op, r) => MExpr::Op(op, Box::new(seq(*r, k))),
        MExpr::Brn(t, f, r) => MExpr::Brn(t, f, Box::new(seq(*r, k))),
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
    let owned: HashSet<&String> = f.owned_params.iter().collect();
    let mut tr = Tr {
        ba: &lowered.borrow_args,
        recinfo: &lowered.recinfo,
        ids: HashMap::new(),
        borrowed: HashSet::new(),
        alias_suspect: HashSet::new(),
        next: 0,
        borrow_next: 1_000_000,
        arm_con: HashMap::new(),
        hi: 0,
        result: None,
        lent_params: HashSet::new(),
        keys: HashMap::new(),
    };
    let mut param_ops = Vec::new();
    if pkeys.is_none() {
        // No signature (a lifted lambda, a generated worker): the verifier then knows no param's
        // type, and seeds a param as an OWNED resource iff it is `%1` or freed in the body, and
        // the caller does not lend it (`verify.rs` param seeding); any other param owns and
        // borrows nothing, so any use of it is fine — modeled by leaving it untracked.
        let lent = lowered.borrow_args.get(&f.name);
        for (i, p) in f.params.iter().enumerate() {
            let owns = f.owned_params.contains(p) || dropped_within(p, &f.body);
            if owns && !lent.is_some_and(|s| s.contains(&i)) {
                let id = tr.fresh();
                tr.ids.insert(p.clone(), id);
                param_ops.push(MOp::Alloc(id));
            }
        }
    }
    if let Some(keys) = pkeys {
        for (p, k) in f.params.iter().zip(keys) {
            if let Some(k) = k {
                tr.keys.insert(p.clone(), k.clone());
            }
        }
        for (i, p) in f.params.iter().enumerate() {
            let is_heap = keys.get(i).is_some_and(|k| k.is_some());
            if is_heap {
                let id = tr.fresh();
                tr.ids.insert(p.clone(), id);
                if owned.contains(p) {
                    param_ops.push(MOp::Alloc(id)); // owned: starts live, must be freed/moved out
                } else {
                    tr.borrowed.insert(id); // borrowed: caller-owned, use-only, not a leak
                }
            } else if dropped_within(p, &f.body) {
                // A POLYMORPHIC param (static key erased to a type variable — `foldl`'s accumulator
                // `b`) that the SPECIALIZED body consumes as a concrete heap resource (`drop z :
                // Integer`, or moves it out) is an OWNED heap param, exactly as the verifier treats
                // it. A poly param instantiated to a scalar is not consumed → stays untracked. Sound
                // by the same self-gating as the field case: a mis-guess makes the emitted `by rfl`
                // fail, never a silent pass.
                let id = tr.fresh();
                tr.ids.insert(p.clone(), id);
                param_ops.push(MOp::Alloc(id));
            }
        }
    }
    for p in &f.params {
        if !tr.ids.contains_key(p) && !owned.contains(p) && !dropped_within(p, &f.body) {
            tr.lent_params.insert(p.clone());
        }
    }
    let body = tr.tr_term(&f.body)?;
    // The FINAL borrowed set = borrowed params + any fields extracted from a borrowed scrutinee
    // (accumulated during translation) — all seed `AxionDrop.acceptsL [B]` as `borrowed`.
    let mut borrowed: Vec<u32> = tr.borrowed.iter().copied().collect();
    borrowed.sort_unstable();
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
            Err(reason) => {
                *reasons.entry(reason).or_insert(0) += 1;
                body.push_str(&format!("-- out of fragment: `{}`: {reason}\n", f.name));
            }
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
