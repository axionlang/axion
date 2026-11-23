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
/// alias. Array `*_get` yields a scalar element (Int/byte), and a `LoadRaw` either sits in a
/// (skipped) destructor or moves a field OUT of a `case` scrutinee (`bind_raw_field`), so
/// neither aliases here. A call is NOT an alias — a view MOVES
/// its argument instead (ownership transfers), and a normal call returns a fresh value.
fn alias_target<'a>(op: &'a Op, recinfo: &RecordInfo) -> Option<&'a Atom> {
    match op {
        Op::Field { name, rec } if recinfo.named_field_is_heap(name) => Some(rec),
        _ => None,
    }
}

fn union_slots(into: &mut HashMap<String, HashSet<usize>>, from: &HashMap<String, HashSet<usize>>) {
    for (k, v) in from {
        into.entry(k.clone()).or_default().extend(v.iter().copied());
    }
}

/// The classification of a value produced on EITHER branch of an `if`/`case`: a resource
/// (owned, or holding interior pointers) iff some branch yields one; the borrow sets union.
fn merge_vals(rets: &[Val]) -> Val {
    // a key only if every branch agrees on it (else unknown → not cross-checked).
    let key = rets
        .first()
        .and_then(|v| v.key.clone())
        .filter(|k| rets.iter().all(|v| v.key.as_ref() == Some(k)));
    Val {
        owned: rets.iter().any(|v| v.owned),
        borrows: rets
            .iter()
            .flat_map(|v| v.borrows.iter().cloned())
            .collect(),
        dead: None,
        key,
        moved_in: false,
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
    /// `drop x` with a reclaimer that does not match `x`'s type — freeing a boxed `Integer`
    /// or `String` with the wrong key (a flat `free` of a bignum/string, or a mismatched
    /// tagged reclaimer) → a bad-free / leak the balance analysis alone can't see.
    WrongDropKey,
    /// one owned (linear) value handed to two owners at once (`tuple x x`, or a generic
    /// `dup x = (x, x)` instantiated at a heap type) — a double free once both are reclaimed.
    /// A program error, not an Auto-Drop one: a heap value cannot be duplicated without a copy.
    Duplicated,
    /// an owned resource still live at a `ret` and not returned — a (soft) leak.
    Leak,
}

impl Cat {
    /// The hard guarantee: a corruption finding means Auto-Drop emitted unsafe code.
    pub fn is_corruption(self) -> bool {
        matches!(
            self,
            Cat::DoubleFree
                | Cat::UseAfterFree
                | Cat::DropOfAlias
                | Cat::Unbalanced
                | Cat::WrongDropKey
                | Cat::Duplicated
        )
    }
}

/// `true` if a leak finding should GATE native compilation — a heap resource nothing frees.
/// Every function is gated, the compiler-synthesized session/parmap state machines (`*$step`)
/// included: their tasks own and reclaim what they create (`SessOwn`), so a leak there is a bug,
/// not a documented residual. (Polymorphic-element leaks are suppressed upstream via
/// `leak_exempt`, so they never reach here.)
pub fn leak_gates(f: &Finding) -> bool {
    f.cat == Cat::Leak
}

/// The type CONSTRUCTOR of a mono/destructor key: the segment before the first `$` argument
/// separator (`List$Int` → `List`, `Either$Int$Int` → `Either`, `Integer` → `Integer`). Used
/// by the drop-key cross-check so generic-vs-mono naming (`List` ↔ `List$Int`) is not treated
/// as a mismatch — only a genuinely different constructor is.
fn ctor_base(key: &str) -> &str {
    key.split_once('$').map_or(key, |(base, _)| base)
}

/// `true` if a container mono key's ELEMENT is a heap resource — `List$Integer`/`List$String`/
/// `List$List$Int` (nested)/`List$tuple$…` yes, `List$Int`/`List$Bool` (scalar) no. Keys with
/// no element separator (a bare `List`, or a scalar `Integer` itself) are conservatively NOT
/// heap-gated (avoids over-flagging when the concrete element is unknown). Used to apply the
/// element-alias double-free check only where a shared element would actually be freed twice.
fn key_elem_is_heap(key: &str) -> bool {
    match key.split_once('$') {
        Some((_, elem)) => !matches!(elem, "Int" | "Float" | "Bool" | "Char"),
        None => false,
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
    /// the value's DEFINITE reclaim key when known (`Some("Integer")` → `axion_bignum_free`,
    /// `Some("String")` → `axion_str_drop`, a mono destructor key otherwise) — from its producer
    /// (`delta::Res.key`), inherited through aliases, or resolved for a case-extracted field.
    /// Drives the drop-key cross-check (`do_drop`): freeing a value with the wrong reclaimer is a
    /// bad-free / leak the balance analysis alone can't see. `None` = unknown → not cross-checked.
    key: Option<String>,
    /// a heap parameter the caller MOVED in (absent from `ba`, so the caller does not free it)
    /// without a `%1` drop obligation here: this function may hand it on, but only ONCE. A
    /// second move gives two owners the same allocation (a double free).
    moved_in: bool,
}

type State = HashMap<String, Val>;

/// Per-function alias summary: parameter indices whose INTERIOR the function's return
/// holds a pointer into — a PURE interior alias (`grab w = inner w` → `{0}`). A whole-value
/// passthrough (`append xs ys = … ret ys …`) is NOT recorded: it returns ownership, not a
/// borrow, so the caller frees the result once. Consumed at call sites to make a call's
/// result inherit the aliasing of its arguments — the INTERPROCEDURAL alias-escape (`grab`)
/// the per-function analysis can't see alone.
type Summaries = HashMap<String, HashSet<usize>>;

/// Which of the two verifier passes is running, controlling how deeply constructor operands
/// are tracked as interior aliases. `track_fields` = follow a borrowed scrutinee's extracted
/// fields (needed to spot an interior escape); `poly_elem` = additionally propagate borrows
/// through POLYMORPHIC constructors (no concrete drop slot) — used ONLY while computing the
/// element-alias summary, so a generic `take`'s `Cons y ys` records that it embeds a borrowed
/// element. The CHECK pass runs with `poly_elem` off and applies that summary at call sites.
#[derive(Clone, Copy)]
struct PassMode {
    track_fields: bool,
    poly_elem: bool,
}

/// `AXION_LEAK_STRICT=poly` switches off the one remaining leak exemption (a polymorphic field
/// whose type stays unresolved in a generic body): a measurement hook.
fn strict_leaks(class: &str) -> bool {
    std::env::var("AXION_LEAK_STRICT").is_ok_and(|v| v == "all" || v.split(',').any(|c| c == class))
}

fn is_generated(name: &str) -> bool {
    // `axion_drop_*` destructors and `axion_copy_*` deep-copiers (R-5) both manage
    // memory by hand (raw load/store/alloc), outside the Auto-Drop reclamation the
    // verifier checks — so they are skipped, exactly like the hand-written runtime.
    // …and the helpers of an `Array` with heap elements (`axion_arrop_*`), likewise by hand.
    name.starts_with("axion_drop_")
        || name.starts_with("axion_copy_")
        || name.starts_with(crate::core::ARROP)
}

/// Per-function: the param indices the function OWNS-AND-FREES — a `Drop(param, Some key, …)` on a
/// formal parameter anywhere in the body (`insert_drops`' `%1` frees and `reclaim_cond_escape`'s
/// synthesized drops both). `consume` uses this to flag passing a BORROWED container element to a
/// callee that frees it: the owner's later deep-drop of the container then double-frees that
/// element. Keyed on a real free (a `Drop` with a reclaimer), not a move-out (which escapes,
/// never freed), so a callee that merely embeds/returns the arg is not implicated.
pub fn frees_heap_params(fns: &[CoreFn]) -> HashMap<String, HashSet<usize>> {
    fn scan(t: &crate::core::Term, idx: &HashMap<&str, usize>, out: &mut HashSet<usize>) {
        use crate::core::{Rhs, Term};
        let rhs = |r: &Rhs, out: &mut HashSet<usize>| match r {
            Rhs::Op(_) => {}
            Rhs::If(_, a, b) => {
                scan(a, idx, out);
                scan(b, idx, out);
            }
            Rhs::Case(_, arms) => {
                for (_, b) in arms {
                    scan(b, idx, out);
                }
            }
        };
        match t {
            Term::Let(_, r, _, b) => {
                rhs(r, out);
                scan(b, idx, out);
            }
            Term::Drop(v, k, _, _, b) => {
                if k.is_some() {
                    if let Some(&i) = idx.get(v.as_str()) {
                        out.insert(i);
                    }
                }
                scan(b, idx, out);
            }
            Term::Ret(r, _) => rhs(r, out),
        }
    }
    let mut out = HashMap::new();
    for f in fns {
        let idx: HashMap<&str, usize> = f
            .params
            .iter()
            .enumerate()
            .map(|(i, p)| (p.as_str(), i))
            .collect();
        let mut s = HashSet::new();
        scan(&f.body, &idx, &mut s);
        if !s.is_empty() {
            out.insert(f.name.clone(), s);
        }
    }
    out
}

/// The borrow name of the heap fields a by-copy update shares with its base `b`.
fn shared_name(b: &str, slot: usize) -> String {
    format!("{b}#shared{slot}")
}

/// Is borrow `w` dangling? A `b#sharedI` borrow (field slot I of `b`, not yet released) lives
/// exactly as long as `b`.
fn borrow_dead(st: &State, w: &str) -> bool {
    let target = w.split_once("#shared").map_or(w, |(b, _)| b);
    st.get(target).is_some_and(|v| v.dead.is_some())
}

/// The base variable of a record update (empty for anything else).
fn b_of(op: &Op) -> &str {
    match op {
        Op::UpdateRecord {
            base: Atom::Var(b), ..
        } => b,
        _ => "",
    }
}

/// Verify every function of a lowered module; returns all findings (corruption + leak).
pub fn verify(lowered: &Lowered) -> Vec<Finding> {
    // With the signature keys, a borrowed tuple's fields resolve to their types, so a function
    // that returns a SCALAR field (`sndof t = case t of (a, b) -> b`) is not summarized as
    // returning a pointer into its tuple. (The lowering's own summary runs before the keys
    // exist; the difference is only ever a scalar result, which nothing frees.)
    let (summaries, elem_aliases) = compute_summaries(
        &lowered.fns,
        &lowered.borrow_args,
        &lowered.recinfo,
        &lowered.param_keys,
    );
    // R-1/V-1: the whole-value param-return relation, consumed by the CHECK pass so the
    // verifier catches the conditional-param-return alias on its own (a sound net).
    let ret_alias = ret_alias_summary(&lowered.fns);
    let frees_heap = frees_heap_params(&lowered.fns);
    let mut out = Vec::new();
    for f in &lowered.fns {
        if is_generated(&f.name) {
            continue;
        }
        run_fn(
            f,
            &lowered.borrow_args,
            &lowered.recinfo,
            &summaries,
            &elem_aliases,
            &ret_alias,
            &frees_heap,
            &lowered.param_keys,
            &lowered.param_leaf,
            PassMode {
                track_fields: true,
                poly_elem: false,
            },
            Some(&mut out),
            None,
        );
    }
    out
}

/// The DUAL of the `consume` finding, as a reusable analysis over ANY Core (pre- or post-drop — the
/// interior-alias tracking is drop-independent): for each function, the param indices that RECEIVE a
/// borrowed container element at some call site anywhere in the module. `reclaim_cond_escape`'s
/// seeding consults this to never reclaim such a param (whose free would double-free the owner's
/// structure — the `axpass show` / `borrowed_list_elem_consume` class), while still reclaiming every
/// genuinely-owned `String` param (accumulators). Runs the same CHECK-mode pass `verify` uses, in a
/// collection sink; `frees_heap` is empty (the collection records every borrowed interior, not only
/// freed ones, so it does not depend on inserted drops).
pub fn borrowed_elem_params(
    fns: &[CoreFn],
    ba: &BorrowArgs,
    recinfo: &RecordInfo,
) -> HashMap<String, HashSet<usize>> {
    let (summaries, elem_aliases) = compute_summaries(fns, ba, recinfo, &HashMap::new());
    let ret_alias = ret_alias_summary(fns);
    let no_fh: HashMap<String, HashSet<usize>> = HashMap::new();
    let no_pk: HashMap<String, Vec<Option<String>>> = HashMap::new();
    let mut sink: HashMap<String, HashSet<usize>> = HashMap::new();
    for f in fns {
        if is_generated(&f.name) {
            continue;
        }
        run_fn(
            f,
            ba,
            recinfo,
            &summaries,
            &elem_aliases,
            &ret_alias,
            &no_fh,
            &no_pk,
            &no_pk,
            PassMode {
                track_fields: true,
                poly_elem: false,
            },
            None,
            Some(&mut sink),
        );
    }
    sink
}

/// The interprocedural alias summary as a REUSABLE analysis over ANY Core (pre- or
/// post-drop — a function's return classification is drop-independent), keyed to the
/// functions that actually return a borrow (non-empty entries only). The lowering pass
/// consumes this to null the ownership annotation on calls to a borrow-returning function,
/// so Auto-Drop stops freeing a borrowed result (the `grab w = inner w` class); the
/// verifier then re-derives its own summary from the emitted Core and CHECKS the outcome.
pub fn borrow_return_summary(fns: &[CoreFn], ba: &BorrowArgs, recinfo: &RecordInfo) -> Summaries {
    let (mut sums, _elem) = compute_summaries(fns, ba, recinfo, &HashMap::new());
    sums.retain(|_, params| !params.is_empty());
    sums
}

// ---- R-1: whole-value param-return relation (call-site-ownership.md) --------------------
//
// `ret_alias(g)` = the PARAMETER indices whose whole value `g`'s result may BE, on ANY path —
// following var renames, `if`/`case` branches, and direct calls to other alias-returning
// functions (a monotone fixpoint). It is DECOUPLED from ownership: `condRet x = if c then x
// else fresh` → {1} even though the return is "owned" on the fresh branch — the blind spot
// `borrow_return_summary` has via `rv.owned = any(branch owned)` (verify.rs `merge_vals`),
// which is exactly why `condRet` UAF'd but `orDefault` (param-OR-param) did not.
//
// This is the RAW relation (append→{1}, id→{0} are included even though they are consuming
// passthroughs); the call-site pass (R-2) intersects it with caller-side argument LIVENESS to
// copy ONLY on genuine reuse — so an accumulator (never reused) is never copied. R-1 is
// analysis-only: nothing consumes this yet, so it cannot affect codegen (judgment-first).

/// The params a value (an [`Op`]) may BE, given the current per-var alias environment and the
/// in-progress cross-function summary.
fn ra_op(
    op: &Op,
    summary: &HashMap<String, HashSet<usize>>,
    env: &HashMap<String, HashSet<usize>>,
) -> HashSet<usize> {
    match op {
        // a var: whatever it is a param-alias of (a param maps to its own index).
        Op::Atom(Atom::Var(v)) => env.get(v).cloned().unwrap_or_default(),
        // a direct call returns param `i` of ITS args for each `i ∈ ret_alias(callee)`; the
        // result is then whatever THAT arg may be (interprocedural chaining).
        Op::CallDirect(g, args, _) => {
            let mut out = HashSet::new();
            if let Some(callee) = summary.get(g) {
                for &j in callee {
                    if let Some(Atom::Var(a)) = args.get(j) {
                        if let Some(s) = env.get(a) {
                            out.extend(s);
                        }
                    }
                }
            }
            out
        }
        // anything else (fresh producer, constructor, primitive, closure call) is not a
        // whole-value param alias.
        _ => HashSet::new(),
    }
}

/// The params a `Term`'s RESULT may BE. Threads `env` (var → param-alias set) through the
/// `let` spine; unions the branches of a tail/value `if`/`case`.
fn ra_term(
    t: &Term,
    summary: &HashMap<String, HashSet<usize>>,
    env: &mut HashMap<String, HashSet<usize>>,
) -> HashSet<usize> {
    match t {
        Term::Let(x, rhs, _, body) => {
            let xs = ra_rhs(rhs, summary, env);
            env.insert(x.clone(), xs);
            ra_term(body, summary, env)
        }
        Term::Drop(_, _, _, _, body) => ra_term(body, summary, env),
        Term::Ret(rhs, _) => ra_rhs(rhs, summary, env),
    }
}

fn ra_rhs(
    rhs: &Rhs,
    summary: &HashMap<String, HashSet<usize>>,
    env: &mut HashMap<String, HashSet<usize>>,
) -> HashSet<usize> {
    match rhs {
        Rhs::Op(op) => ra_op(op, summary, env),
        Rhs::If(_, a, b) => {
            let mut sa = ra_term(a, summary, env);
            let sb = ra_term(b, summary, env);
            sa.extend(sb);
            sa
        }
        Rhs::Case(_, arms) => {
            let mut out = HashSet::new();
            for (_, arm) in arms {
                out.extend(ra_term(arm, summary, env));
            }
            out
        }
    }
}

/// R-1 of [`docs/call-site-ownership.md`]: compute `ret_alias` for every function (non-empty
/// entries only), to a monotone fixpoint over the call graph.
pub fn ret_alias_summary(fns: &[CoreFn]) -> HashMap<String, HashSet<usize>> {
    let mut summary: HashMap<String, HashSet<usize>> = HashMap::new();
    loop {
        let mut changed = false;
        for f in fns {
            if is_generated(&f.name) {
                continue;
            }
            let mut env: HashMap<String, HashSet<usize>> = HashMap::new();
            for (i, p) in f.params.iter().enumerate() {
                env.insert(p.clone(), HashSet::from([i]));
            }
            let res = ra_term(&f.body, &summary, &mut env);
            if !res.is_empty() && summary.get(&f.name) != Some(&res) {
                // grow monotonically (union with any prior entry).
                let e = summary.entry(f.name.clone()).or_default();
                let before = e.len();
                e.extend(res);
                if e.len() != before {
                    changed = true;
                }
            }
        }
        if !changed {
            break;
        }
    }
    summary
}

/// Per-function ELEMENT-alias summary: parameter indices whose heap ELEMENT the function's
/// OWNED result shares — it builds a fresh container but embeds a BORROWED element of the
/// param into it (`take`/`drop`/`filter` over a heap element type: `Cons y …` where `y` is a
/// case-extracted element of the borrowed input). The whole-value alias summary discards
/// this (it only records a NON-owned return), yet dropping BOTH the input and such a result
/// double-frees the shared element — the class AX0912 guards and the verifier used to miss.
type ElemAliases = std::collections::HashMap<String, HashSet<usize>>;

/// The function's return is, on EVERY path, a BARE variable (`ret a`) rather than a freshly
/// built value (`ret Cons y ys`, `ret strAppend …`). This distinguishes a GRAB — the whole
/// result IS a (possibly case-extracted) interior alias of a parameter, a pure borrow-return —
/// from an EMBED — a fresh OWNED container that merely shares a borrowed element. Field-tracking
/// classifies both as non-owned (a poly `Cons y ys` has no concrete key → `owned == false`), so
/// `owned` alone cannot tell them apart; the structural shape can. Only a grab belongs in the
/// PURE summary (which nulls the call's ownership so Auto-Drop stops freeing the borrowed result);
/// an embed stays in the ELEM summary (the AX0912 double-free-of-shared-element guard).
fn ret_is_bare_var(t: &Term) -> bool {
    match t {
        Term::Ret(Rhs::Op(Op::Atom(Atom::Var(_))), _) => true,
        Term::Ret(Rhs::Op(_), _) => false,
        Term::Ret(Rhs::If(_, a, b), _) => ret_is_bare_var(a) && ret_is_bare_var(b),
        Term::Ret(Rhs::Case(_, arms), _) => arms.iter().all(|(_, a)| ret_is_bare_var(a)),
        Term::Let(_, _, _, b) | Term::Drop(_, _, _, _, b) => ret_is_bare_var(b),
    }
}

/// Fixpoint over the call graph: a function returns a PURE interior alias of param `i` when
/// its `ret` is an interior pointer (`owned == false`) that borrows `i` — which may flow
/// through a call to another alias-returning function, so it iterates to a fixed point
/// (findings suppressed during this dry run).
fn compute_summaries(
    fns: &[CoreFn],
    ba: &BorrowArgs,
    recinfo: &RecordInfo,
    param_keys: &HashMap<String, Vec<Option<String>>>,
) -> (Summaries, ElemAliases) {
    let mut sums: Summaries = HashMap::new();
    let mut elem: ElemAliases = HashMap::new();
    let no_elem: ElemAliases = HashMap::new();
    // the whole-value-alias relation is not needed for the summary dry-runs (it only sharpens
    // the CHECK pass); pass an empty map here.
    let no_ret: HashMap<String, HashSet<usize>> = HashMap::new();
    // summary dry-runs never populate `poly_borrowed` (that happens only in the CHECK pass:
    // track_fields && !poly_elem), so `frees_heap` is unused here — an empty map suffices.
    let no_fh: HashMap<String, HashSet<usize>> = HashMap::new();
    let no_pk: HashMap<String, Vec<Option<String>>> = HashMap::new();
    let params_borrowed = |rv: &Val, f: &CoreFn| -> HashSet<usize> {
        f.params
            .iter()
            .enumerate()
            .filter(|(_, p)| rv.borrows.contains(p.as_str()))
            .map(|(i, _)| i)
            .collect()
    };
    loop {
        let mut changed = false;
        for f in fns {
            if is_generated(&f.name) {
                continue;
            }
            // PURE-alias pass: field-tracking OFF + no elem hook → identical to the original
            // analysis, so the summary that feeds core.rs drop insertion is unchanged. A
            // NON-owned return that borrows a param is a pure interior alias (`grab`).
            let pure_mode = PassMode {
                track_fields: false,
                poly_elem: false,
            };
            let rv = run_fn(
                f, ba, recinfo, &sums, &no_elem, &no_ret, &no_fh, &no_pk, &no_pk, pure_mode, None,
                None,
            );
            let pure_borrowed = params_borrowed(&rv, f);
            let orig_pure = if rv.owned {
                HashSet::new()
            } else {
                pure_borrowed.clone()
            };
            // ELEM-alias pass: field-tracking ON so a case-extracted borrowed ELEMENT is seen.
            // The params the return borrows ONLY under element-tracking (`P_elem − P_pure`) are
            // the ones shared via a CONSTRUCTOR embed (`take`: `Cons y …` embeds a borrowed
            // element) — as opposed to a pure interior alias (`grab`, already in P_pure).
            // Dropping BOTH the input and such a result double-frees the shared heap element.
            let elem_mode = PassMode {
                track_fields: true,
                poly_elem: true,
            };
            let rve = run_fn(
                f, ba, recinfo, &sums, &elem, &no_ret, &no_fh, param_keys, &no_pk, elem_mode, None,
                None,
            );
            let elem_full = params_borrowed(&rve, f);
            // GRAB-VIA-CASE promotion: the track_fields-OFF pure pass cannot see a case-extracted
            // field (`getName r = case r of R a b -> a`), so it classifies the bare-field return as
            // a fresh OWNED value and records NO pure alias — core.rs then drops the call result,
            // double-freeing the borrowed field (a verifier-blind UAF). Field-tracking (`rve`) sees
            // the return IS a borrowed interior (`owned == false`); if the return is also
            // structurally a bare var (a grab, not an embedding constructor) and the pure pass
            // missed it, promote those borrows into the PURE summary. That makes
            // `borrow_return_summary` null the call's ownership (no stray drop) AND lets the CHECK
            // pass see the alias — closing the hole without touching the embed/AX0912 path. A
            // SINGLE insert of the final pure set keeps the fixpoint monotone (two inserts would
            // oscillate orig↔promoted and never converge).
            let grab_via_case = !rve.owned
                && orig_pure.is_empty()
                && !elem_full.is_empty()
                && ret_is_bare_var(&f.body);
            let params = if grab_via_case {
                elem_full.clone()
            } else {
                orig_pure
            };
            if sums.get(&f.name) != Some(&params) {
                sums.insert(f.name.clone(), params.clone());
                changed = true;
            }
            // Embed share (ELEM): the borrows a FRESH-container return carries that the pure
            // relation does not. Non-grab: subtract the original pure set (`P_elem − P_pure`,
            // unchanged). Grab: everything was promoted to pure → empty.
            let elem_sub = if grab_via_case {
                &elem_full
            } else {
                &pure_borrowed
            };
            let elem_params: HashSet<usize> = elem_full.difference(elem_sub).copied().collect();
            if elem.get(&f.name) != Some(&elem_params) {
                elem.insert(f.name.clone(), elem_params);
                changed = true;
            }
        }
        if !changed {
            break;
        }
    }
    (sums, elem)
}

/// Verify one function against the summaries; returns the resource classification of its
/// return value. `out = None` runs it silently (for summary computation).
#[allow(clippy::too_many_arguments)]
fn run_fn(
    f: &CoreFn,
    ba: &BorrowArgs,
    recinfo: &RecordInfo,
    summaries: &Summaries,
    elem_aliases: &ElemAliases,
    ret_alias: &HashMap<String, HashSet<usize>>,
    frees_heap: &HashMap<String, HashSet<usize>>,
    param_keys: &HashMap<String, Vec<Option<String>>>,
    param_leaf: &HashMap<String, Vec<Option<String>>>,
    mode: PassMode,
    out: Option<&mut Vec<Finding>>,
    elem_sink: Option<&mut HashMap<String, HashSet<usize>>>,
) -> Val {
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
    // each `%1` param's mono destructor key (`e :: Either Integer Integer` → `Either$Integer$
    // Integer`), so a param scrutinee resolves its extracted fields' reclaimers — extending the
    // drop-key cross-check to fields extracted from a PARAMETER (not just a locally-produced value).
    let param_key: HashMap<&str, &str> = f
        .owned_drop_ty
        .iter()
        .filter_map(|(n, k)| k.as_deref().map(|k| (n.as_str(), k)))
        .collect();
    for (i, p) in f.params.iter().enumerate() {
        if owned.contains(p) && !borrowed.is_some_and(|s| s.contains(&i)) {
            // an owned heap param is a live resource this fn must free.
            st.insert(
                p.clone(),
                Val {
                    owned: true,
                    key: param_key.get(p.as_str()).map(|k| (*k).to_string()),
                    ..Default::default()
                },
            );
        } else {
            // a borrowed/scalar param: present (so a `Field` read of it is tracked as an
            // interior alias — needed to detect `grab`-style return-of-a-field), owning and
            // borrowing nothing, so using it is always fine. It carries its CONTAINER mono key
            // (from the signature) so a `case` on a borrowed `List String` param resolves its
            // extracted elements to their concrete type — the poly-erasure fix (`field_tagged_key`
            // needs the scrutinee key; a borrowed param has none from `owned_drop_ty`).
            let key = param_keys
                .get(&f.name)
                .and_then(|ks| ks.get(i))
                .cloned()
                .flatten();
            let moved_in = key.is_some() && !borrowed.is_some_and(|s| s.contains(&i));
            // A MOVED-IN (not borrowed) parameter of a heap LEAF type (`String`, `Integer`,
            // `Buffer`, a closure) belongs to this function: track it as owned, so moving it twice
            // — storing one value in two places (`dup$String x = (x, x)`, a generic body
            // specialized at a heap type) — is a use after move, and neither freeing nor returning
            // it is a leak.
            let leaf = param_leaf
                .get(&f.name)
                .and_then(|ks| ks.get(i))
                .cloned()
                .flatten();
            if let Some(leaf) = leaf.filter(|_| !borrowed.is_some_and(|s| s.contains(&i))) {
                st.insert(
                    p.clone(),
                    Val {
                        owned: true,
                        key: Some(leaf),
                        ..Default::default()
                    },
                );
                continue;
            }
            // A moved-in CONTAINER (a `data`/tuple value with heap) is this function's too, as
            // Auto-Drop treats it: owned, so one it neither frees nor hands on is a leak, a second
            // hand-over a use after move, and its drop key is cross-checked. (Tracking it only as
            // `moved_in` missed a use after free once the copies were off: `condUpd` in
            // sharing_regressions.) An unboxed enum is an immediate: nothing to own.
            let imm = key
                .as_deref()
                .is_some_and(|k| recinfo.is_enum_type(k.split('$').next().unwrap_or(k)));
            let own = moved_in && !imm;
            st.insert(
                p.clone(),
                Val {
                    key,
                    moved_in: moved_in && !own,
                    owned: own,
                    ..Default::default()
                },
            );
        }
    }
    let borrowed_params: HashSet<String> = borrowed
        .map(|s| s.iter().filter_map(|&i| f.params.get(i).cloned()).collect())
        .unwrap_or_default();
    let mut sink = Vec::new();
    let mut v = Verifier {
        f: &f.name,
        ba,
        recinfo,
        summaries,
        elem_aliases,
        mode,
        out: out.unwrap_or(&mut sink),
        children: HashMap::new(),
        // (A moved-in String/Integer/Buffer/closure parameter is NOT exempt: one the function
        // neither frees nor returns is a leak like any owned value. It used to be exempt because
        // the borrow analysis read some pure reads — a closure capture, an FFI `Borrow` argument,
        // a runtime call the built-in table says borrows — as moves; it now agrees with Auto-Drop.)
        leak_exempt: HashSet::new(),
        projections: HashMap::new(),
        heap_inside: HashMap::new(),
        arm_con: HashMap::new(),
        binder_of: HashMap::new(),
        consumed_slots: HashMap::new(),
        borrowed_params,
        captures: f.captures.iter().cloned().collect(),
        ret_alias,
        frees_heap,
        poly_borrowed: HashSet::new(),
        elem_sink,
        deep_freed: HashSet::new(),
        shares: HashMap::new(),
    };
    // the whole body is in function-EXIT (tail) position: a `ret` reached here is a real
    // return, so a leak check applies; a `ret` reached inside a let-bound `if`/`case` is a
    // VALUE position (bound to the let), not an exit — see `bind`/`term`.
    v.term(&f.body, &mut st, true)
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
    /// values freed by a FULL keyed (deep) drop — not a shell free, not a skip-destructor that
    /// leaves shared slots alone (see the reverse double-free check in `do_drop`)
    deep_freed: HashSet<String>,
    /// by-copy update result → (its base, the field indices they share) — CHECK pass only
    shares: HashMap<String, (String, Vec<usize>)>,
    f: &'a str,
    ba: &'a BorrowArgs,
    recinfo: &'a RecordInfo,
    summaries: &'a Summaries,
    elem_aliases: &'a ElemAliases,
    /// which pass is running — gates how deeply constructor operands are tracked (`PassMode`).
    mode: PassMode,
    out: &'a mut Vec<Finding>,
    /// scrutinee var → the (extracted-field var, slot index) pairs a `case` bound from it.
    /// A DEEP `drop` of the scrutinee frees these fields transitively, so they must NOT be
    /// reported as separately-leaked (and dropping one after the parent's deep drop is a
    /// double free). Populated by `bind_pattern`, consumed by `do_drop`.
    children: HashMap<String, Vec<(String, usize)>>,
    /// extracted fields whose heap-ness is POLYMORPHIC (a type variable, no concrete drop
    /// slot): heap once instantiated to a `data` type, scalar once instantiated to `Int`.
    /// The verifier can't tell which without the monomorphic type, so it still tracks them
    /// as owned (double-free stays sound) but EXEMPTS them from leak reporting — a poly
    /// element leak is exactly Axión's documented conservative-leak class (not gated).
    leak_exempt: HashSet<String>,
    /// projected-field var → (source record var, slot). A direct heap `field` projection
    /// (`let d = field <fld> src`) records the exact slot it aliases, so a MOVE-OUT
    /// skip-destructor of the source (`drop src : T skip{slot}`, §move-out) can transfer
    /// ownership of that slot to `d` — promoting the borrow to an owned value that outlives
    /// the source's shell free, rather than dangling it. Populated by `bind_op`, consumed by
    /// `do_drop`'s skip handling.
    projections: HashMap<String, (String, usize)>,
    /// For a value built by MOVING owned heap resources into a fresh tuple / constructor /
    /// record (`let t = tuple s 1` with `s` an owned `String`), the slots that hold them; also
    /// for its aliases. Ownership of `s` passes to `t`, so only a DEEP (keyed) drop of `t`
    /// reclaims it; an unkeyed drop is a flat `free` of the cell that leaks `s`, and `do_drop`
    /// reports it as a leak. A slot is cleared when a `case` binds it to a variable (that
    /// variable is then tracked as owned in its own right), or when a raw load inside a `case`
    /// arm reads it (`raw_slot` maps the offset to the slot through the arm's constructor).
    /// Core names are unique per function, so path-insensitive tracking is exact up to `case`
    /// arms, whose clears are unioned (again only an under-report).
    heap_inside: HashMap<String, HashSet<usize>>,
    /// Scrutinee var → the constructor the ENCLOSING `case` arm matched it against (set while that
    /// arm's body is checked). A raw field load `loadraw s+off` inside the arm (Auto-Drop's
    /// per-field drop of a wildcard-discarded heap field, `emit_per_field_drops`) maps its offset to
    /// a slot through it: exactly that slot is cleared from `heap_inside[s]`, and the loaded value
    /// is tracked as an owned child — the same treatment `bind_pattern` gives a named field.
    arm_con: HashMap<String, String>,
    /// A field binder of the `case` arm being checked → (its scrutinee, slot). Scoped to the arm:
    /// binder names are unique along a scope path, not across sibling `case`s.
    binder_of: HashMap<String, (String, usize)>,
    /// Value → the field slots moved out of it or freed separately. A later DEEP drop of the value
    /// that does not skip them frees them a second time (a `case` that did not consume its
    /// scrutinee — it is used after — handing a field to a callee that frees it).
    consumed_slots: HashMap<String, HashSet<usize>>,
    /// The GENUINELY-borrowed params (in `borrow_args`): the caller retains and drops the
    /// whole structure. Distinct from a MOVED-in param modelled the same way here (a view
    /// like `dropWhile` — not in `borrow_args`). `consume` flags freeing an interior of one
    /// of THESE (the owner double-frees), but not of a moved-in/view param (this fn owns it).
    borrowed_params: HashSet<String>,
    /// A closure's captures (`[env …]`): the closure cell holds them across every call, so the
    /// body only ever borrows them.
    captures: HashSet<String>,
    /// The WHOLE-VALUE param-return relation (R-1, `ret_alias_summary`): `ret_alias[g]` = the
    /// param indices `g`'s result may BE. Consumed at call sites (`classify`) to mark a call's
    /// result as aliasing an argument the callee BORROWS and returns whole — the
    /// conditional-param-return class (`condRet`) the interior-alias `summaries` miss (they
    /// exclude whole-value passthroughs). Empty in the summary dry-runs; the real relation is
    /// supplied only for the CHECK pass, so the verifier catches the alias even if Auto-Drop's
    /// copy-normalization is absent (a sound net, not a codegen-dodge).
    ret_alias: &'a HashMap<String, HashSet<usize>>,
    /// Per-callee param indices the callee OWNS-AND-FREES (`frees_heap_params`). Used by `consume`
    /// to decide whether a POLY borrowed container-element passed to a call is actually freed there
    /// (so the owner's later deep-drop double-frees it) — the heap-ness the element itself can't
    /// carry under polymorphism comes from the callee genuinely dropping a value at that position.
    frees_heap: &'a HashMap<String, HashSet<usize>>,
    /// Case-extracted elements of a BORROWED scrutinee whose heap-ness is POLYMORPHIC (a bare type
    /// variable — a `String` element of a generic `List String`, drop-slot `None`). Tracked as
    /// interior aliases of the scrutinee like concrete fields, but their `consume` flag is gated on
    /// the callee actually freeing a heap value there (`frees_heap`), so a poly element that
    /// instantiates to a scalar (`List Int`) is never falsely flagged. Populated by `bind_pattern`.
    poly_borrowed: HashSet<String>,
    /// Collection sink for `borrowed_elem_params` (None in the normal CHECK/summary passes): at each
    /// `CallDirect(g, args)`, every arg that is a BORROWED interior (an element of a borrowed
    /// container) records `(g, arg-index)` — i.e. the callee params that would double-free if a
    /// drop-pass made them reclaim. `reclaim_cond_escape`'s seeding reads this to SKIP reclaiming
    /// such a param — the precise opposite of `consume`'s flag, from the same detection (one authority).
    elem_sink: Option<&'a mut HashMap<String, HashSet<usize>>>,
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
    fn term(&mut self, t: &Term, st: &mut State, tail: bool) -> Val {
        match t {
            Term::Let(x, rhs, sp, body) => {
                self.bind(x, rhs, *sp, st);
                // R-1/V-1 (docs/call-site-ownership.md): a call that may return an argument
                // WHOLE (`ret_alias`) whose arg is LIVE after this call makes `x` an alias of
                // that arg — a borrow, not a fresh owned value. Marking it so lets `do_drop` /
                // use-after-free catch the conditional-param-return UAF (`let picked = condRet
                // "" name; … name …` — dropping `picked` frees the still-used `name`). Gated on
                // per-call-site reuse (arg live in `body`): a consumed/never-reused arg
                // (append, a fold accumulator) is untouched, so `x` stays owned — no false
                // positive on the safe corpus. This is what makes the verifier a SOUND NET: it
                // catches the alias even when Auto-Drop's copy-normalization is absent.
                if let Rhs::Op(Op::CallDirect(g, args, _)) = rhs {
                    if let Some(ra) = self.ret_alias.get(g) {
                        let alias: HashSet<String> = ra
                            .iter()
                            .filter_map(|&i| match args.get(i) {
                                Some(Atom::Var(v)) => Some(v.clone()),
                                _ => None,
                            })
                            .filter(|v| {
                                crate::core::term_mentions_any(body, &HashSet::from([v.clone()]))
                                    // …or an arg this function does not own at all: a borrowed
                                    // param or an element of one (`relJoin rel x` with `x` from a
                                    // borrowed list). Its owner frees it later, so a result that
                                    // may BE it is a borrow even if `v` is never used again.
                                    || self.not_owned_here(v, st)
                            })
                            .collect();
                        if !alias.is_empty() {
                            st.insert(
                                x.clone(),
                                Val {
                                    owned: false,
                                    borrows: alias,
                                    dead: None,
                                    key: None,
                                    moved_in: false,
                                },
                            );
                        }
                    }
                }
                self.term(body, st, tail)
            }
            Term::Drop(x, key, skip, sp, body) => {
                self.do_drop(x, key.as_ref(), skip, *sp, st);
                self.term(body, st, tail)
            }
            Term::Ret(rhs, sp) => self.ret(rhs, *sp, st, tail),
        }
    }

    /// A `let x = rhs`: evaluate the rhs's effect on `st`, then classify `x`.
    fn bind(&mut self, x: &str, rhs: &Rhs, sp: Span, st: &mut State) {
        match rhs {
            Rhs::Op(op) => self.bind_op(x, op, sp, st),
            Rhs::If(c, th, el) => {
                self.use_atom(c, sp, st);
                // value position (bound to `x`), NOT a function exit → no leak check in the
                // arms: a resource consumed AFTER the join is still live here, not leaked.
                let val = self.branches(&[th.as_ref(), el.as_ref()], sp, st, false);
                if val.owned || !val.borrows.is_empty() {
                    st.insert(x.to_string(), val); // a resource only if the branches yield one
                }
            }
            Rhs::Case(scrut, arms) => {
                let val = self.case(scrut, arms, sp, st, false);
                if val.owned || !val.borrows.is_empty() {
                    st.insert(x.to_string(), val);
                }
            }
        }
    }

    /// A `let x = op`: check operand liveness, classify the result, then apply the operands'
    /// escapes (moved/aliased operands leave the state). `x` is tracked only if it is a
    /// resource (owns an allocation or holds an interior pointer into one).
    /// Apply a consuming op's escapes: each moved operand (an indirect call only borrows its
    /// closure receiver) leaves the state. CONSUMING an interior alias of a BORROWED
    /// (externally-owned) resource — moving it into a callee's owning argument or embedding it in
    /// a new structure — frees memory the owner still holds, so the owner's later drop
    /// double-frees; flag it (sound-by-rejection). A bare `Atom` move is the value ESCAPING as the
    /// result (a `grab`-style borrow-return), not a consume, so it is exempt.
    fn consume(&mut self, op: &Op, sp: Span, st: &mut State) {
        // Flag a DIRECT call that FREES a borrowed interior: an argument at a position the
        // callee neither BORROWS (`borrow_args`) nor RETURNS AS AN ALIAS (its summary — a
        // view/borrow-return like `dropWhile`) is one the callee reclaims. If that argument is
        // an interior alias of a BORROWED (externally-owned) resource, the owner still holds it
        // and will drop it → double free (the partial-consumer-over-a-heap-element class, which
        // the analysis previously missed). `MakeCon`/closures/views embed-or-return the value
        // rather than free it, so only `CallDirect` is a definite free.
        // a generated deep-copier (`axion_copy_T`) only reads its argument (see `op_delta_effect`)
        let direct = match op {
            Op::CallDirect(g, args, _) if !g.starts_with("axion_copy_") => Some((g, args)),
            _ => None,
        };
        if let Some((g, args)) = direct {
            let borrowed_pos = self.ba.get(g);
            let alias_ret = self.summaries.get(g);
            let ret_alias_g = self.ret_alias.get(g);
            let frees_h = self.frees_heap.get(g);
            for (i, a) in args.iter().enumerate() {
                if let Atom::Var(v) = a {
                    let borrowed_interior = st.get(v).is_some_and(|val| {
                        !val.owned && val.borrows.iter().any(|w| self.borrowed_params.contains(w))
                    });
                    if !borrowed_interior {
                        continue;
                    }
                    // Record (callee, param-index) for `borrowed_elem_params`: this position receives
                    // a borrowed container element, so a reclaim pass must NOT make the callee free it.
                    // Collected for EVERY borrowed interior (independent of `frees` below) — the point
                    // is to PREVENT introducing the free, not to confirm an existing one.
                    if let Some(sink) = self.elem_sink.as_deref_mut() {
                        sink.entry(g.clone()).or_default().insert(i);
                    }
                    // The callee FREES this arg here (→ double-free of the owner's structure) iff it
                    // genuinely drops a value at this position (`frees_heap`), OR — for a CONCRETE
                    // element — it neither borrows it, returns it as an interior alias
                    // (`summaries`), nor returns it WHOLE (`ret_alias`). Excluding `ret_alias` is
                    // what stops a whole-value passthrough (`relJoin`/`consume` returning the
                    // element) from being mis-read as a free at the call — that value ESCAPES into
                    // the result; a double-free there is a DROP of the result, not this call. A POLY
                    // element (erased heap-ness) relies on `frees_heap` alone.
                    let frees = frees_h.is_some_and(|s| s.contains(&i))
                        || (!self.poly_borrowed.contains(v)
                            && !borrowed_pos.is_some_and(|s| s.contains(&i))
                            && !alias_ret.is_some_and(|s| s.contains(&i))
                            && !ret_alias_g.is_some_and(|s| s.contains(&i)));
                    if frees {
                        self.finding(Cat::DropOfAlias, v, sp);
                    }
                }
            }
        }
        // A structure frees the closures it holds, so embedding a closure this function does NOT
        // own — a borrowed parameter, an element of a borrowed structure — hands that structure
        // a cell its owner frees too: a double free (`store f = Just f` on a borrowed `f`).
        let embedded: &[Atom] = match op {
            Op::MakeCon { args, .. } | Op::MakeTuple(args) => args,
            _ => &[],
        };
        let rec_embedded: Vec<&Atom> = match op {
            Op::MakeRecord { fields, .. } => fields.iter().map(|(_, a)| a).collect(),
            _ => Vec::new(),
        };
        for a in embedded.iter().chain(rec_embedded) {
            if let Atom::Var(v) = a {
                let not_owned_closure = st.get(v).is_some_and(|val| {
                    !val.owned && !val.moved_in && val.key.as_deref() == Some("Closure")
                });
                if not_owned_closure {
                    self.finding(Cat::DropOfAlias, v, sp);
                }
            }
        }
        // moved operands escape → mark them dead (an indirect call's `nonstrict` closure is
        // BORROWED: it survives the call). One op moving the same OWNED value twice (`tuple x
        // x`: one String stored in two slots) hands two owners the same memory — a double free
        // once both are reclaimed.
        let e = op_delta_effect(op, self.ba);
        let mut moved: HashSet<&str> = HashSet::new();
        for a in &e.moves {
            if let Atom::Var(v) = a {
                let owned_live = st.get(v).is_some_and(|val| val.owned && val.dead.is_none());
                if !moved.insert(v.as_str()) && owned_live {
                    self.finding(Cat::Duplicated, v, sp);
                }
            }
        }
        for a in &e.moves {
            if let Atom::Var(v) = a {
                self.note_field_gone(v, st);
                self.kill_whole(v, Cat::UseAfterFree, st);
            }
        }
    }

    /// `v` (owned, live) leaves: if it is a field binder of the current arm, its slot of the
    /// scrutinee is no longer the scrutinee's to free.
    fn note_field_gone(&mut self, v: &str, st: &State) {
        if !st.get(v).is_some_and(|val| val.owned && val.dead.is_none()) {
            return;
        }
        if let Some((p, i)) = self.binder_of.get(v).cloned() {
            self.consumed_slots.entry(p).or_default().insert(i);
        }
    }

    fn bind_op(&mut self, x: &str, op: &Op, sp: Span, st: &mut State) {
        let e = op_delta_effect(op, self.ba);
        for a in e
            .borrows
            .iter()
            .chain(e.moves.iter())
            .chain(e.nonstrict.iter())
        {
            self.use_atom(a, sp, st);
        }
        if let Some(a) = e.alias {
            self.use_atom(a, sp, st);
        }
        let val = self.classify(op, st);
        if let Op::UpdateRecord {
            base: Atom::Var(b),
            fields,
            inplace: false,
            ..
        } = op
        {
            let prefix = format!("{b}#shared");
            if !self.mode.poly_elem && val.borrows.iter().any(|w| w.starts_with(&prefix)) {
                let names: Vec<&str> = fields.iter().map(|(n, _)| n.as_str()).collect();
                let shared = self.recinfo.update_shared_fields(&names);
                self.shares.insert(x.to_string(), (b.clone(), shared));
            }
        }
        // which slots of `x` take ownership of a heap resource moved into them (`heap_inside`)?
        let owns = |a: &Atom| {
            matches!(a, Atom::Var(v) if e.moves.iter().any(|m| matches!(m, Atom::Var(w) if w == v))
                && st.get(v).is_some_and(|w| w.owned && w.dead.is_none())
                && !self.leak_exempt.contains(v))
        };
        let slots: HashSet<usize> = match op {
            Op::MakeTuple(args) | Op::MakeCon { args, .. } => args
                .iter()
                .enumerate()
                .filter(|(_, a)| owns(a))
                .map(|(i, _)| i)
                .collect(),
            Op::MakeRecord { fields, .. } => fields
                .iter()
                .filter(|(_, a)| owns(a))
                .map(|(name, _)| {
                    self.recinfo
                        .named_field_slot(name)
                        .map_or(usize::MAX, |(_, slot)| slot)
                })
                .collect(),
            Op::LoadRaw(Atom::Var(src), off) => {
                // a raw load moves ONE slot out: the one at `off` under the arm's constructor. With
                // no known constructor (a load outside a `case` arm on `src`) nothing is moved out
                // of the tracked slots, so they all stay occupied.
                if let Some(fi) = self.raw_slot(src, *off) {
                    if let Some(slots) = self.heap_inside.get_mut(src) {
                        slots.remove(&fi);
                        if slots.is_empty() {
                            self.heap_inside.remove(src);
                        }
                    }
                }
                HashSet::new()
            }
            _ => match e.alias {
                Some(Atom::Var(src)) => self.heap_inside.get(src).cloned().unwrap_or_default(),
                _ => HashSet::new(),
            },
        };
        if !slots.is_empty() {
            self.heap_inside.insert(x.to_string(), slots);
        }
        if let Some(Atom::Var(src)) = e.alias {
            self.kill_whole(src, Cat::UseAfterFree, st);
        }
        // moved operands escape (the call consumes them) — same as `scan_op_escapes` in
        // Auto-Drop; `consume` also flags consuming an interior alias of a borrowed resource.
        self.consume(op, sp, st);
        // a field projection MOVED into a new value (`Cons 5 (xs p)`, a constructor, an update)
        // travels with it: a later skip-drop of its record leaves that field to the new value,
        // not to the projection (promoting the projection would report a false leak)
        for a in &e.moves {
            if let Atom::Var(v) = a {
                if v != x {
                    self.projections.remove(v);
                }
            }
        }
        if val.owned || !val.borrows.is_empty() {
            // record a direct heap field projection's exact slot, so a move-out skip-drop
            // of the source can transfer that slot's ownership to `x` (§move-out).
            if let Op::Field {
                name,
                rec: Atom::Var(src),
            } = op
            {
                if self.recinfo.named_field_is_heap(name) {
                    if let Some((_, slot)) = self.recinfo.named_field_slot(name) {
                        self.projections.insert(x.to_string(), (src.clone(), slot));
                    }
                }
            }
            st.insert(x.to_string(), val);
        }
        if let Op::LoadRaw(Atom::Var(src), off) = op {
            self.bind_raw_field(x, src, *off, st);
        }
    }

    /// The field index a raw load `loadraw src+off` reads, under the constructor the enclosing
    /// `case` arm matched `src` against (`arm_con`); `None` when there is no such arm or no field
    /// lives at `off`.
    fn raw_slot(&self, src: &str, off: i32) -> Option<usize> {
        let con = self.arm_con.get(src)?;
        let arity = self.recinfo.con_arity(con).unwrap_or(0);
        (0..arity).find(|&fi| self.recinfo.field_offset(con, fi) == off)
    }

    /// A raw load of a HEAP field of an OWNED scrutinee transfers that field out as an owned
    /// resource (Auto-Drop then frees it): track it exactly as `bind_pattern` tracks a named
    /// field of an owned scrutinee — owned, keyed, a child at its slot, leak-exempt when the
    /// field is polymorphic — so its drop is checked (double-free, wrong key) and a missing drop
    /// is a leak.
    fn bind_raw_field(&mut self, x: &str, src: &str, off: i32, st: &mut State) {
        let Some(fi) = self.raw_slot(src, off) else {
            return;
        };
        let Some(con) = self.arm_con.get(src).cloned() else {
            return;
        };
        if !self.recinfo.field_transfers_heap(&con, fi) {
            return;
        }
        let Some(sv) = st.get(src).filter(|v| v.owned && v.dead.is_none()) else {
            return;
        };
        let fkey = sv
            .key
            .as_deref()
            .and_then(|sk| self.recinfo.field_tagged_key(&con, fi, sk));
        // exempt only a field whose type stays UNRESOLVED (a generic body's bare variable): one
        // the scrutinee's key makes heap is reclaimed like any owned value
        let resolved = sv
            .key
            .as_deref()
            .is_some_and(|sk| self.recinfo.field_heap_under(&con, fi, sk));
        st.insert(
            x.to_string(),
            Val {
                owned: true,
                key: fkey,
                ..Default::default()
            },
        );
        self.children
            .entry(src.to_string())
            .or_default()
            .push((x.to_string(), fi));
        if self.recinfo.field_drop_slot(&con, fi).is_none() && !resolved && !strict_leaks("poly") {
            self.leak_exempt.insert(x.to_string());
        }
    }

    /// `v` is a value this function holds but does not own: a genuinely borrowed parameter, or an
    /// interior alias (an element / field) of something else.
    fn not_owned_here(&self, v: &str, st: &State) -> bool {
        st.get(v).is_some_and(|val| {
            !val.owned
                && !val.moved_in
                && (self.borrowed_params.contains(v) || !val.borrows.is_empty())
        })
    }

    /// The resource classification of an `Op`'s result (NO state mutation): a whole-value
    /// alias (`let y = x`) inherits its source; a fresh producer is `owned`, inheriting the
    /// interior pointers of its moved-in operands (the `build`/`grab` class); a direct HEAP
    /// field projection borrows its operand; everything else (a scalar `Prim`, a call
    /// returning an immediate/enum) is untracked.
    fn classify(&self, op: &Op, st: &State) -> Val {
        // a call to a function whose SUMMARY says its return is a pure interior alias of
        // some parameters: the result borrows those arguments' interiors (the `grab` class).
        if let Op::CallDirect(g, args, _) = op {
            if let Some(params) = self.summaries.get(g).filter(|p| !p.is_empty()) {
                // transitively: an argument that is itself a borrow (`y` out of a borrowed
                // list, in `fst y`) hands on what IT borrows, so a constructor embedding the
                // result is seen to share the list's element
                let borrows: HashSet<String> = params
                    .iter()
                    .filter_map(|&i| args.get(i))
                    .filter_map(|a| match a {
                        Atom::Var(v) => Some(v),
                        _ => None,
                    })
                    .flat_map(|v| {
                        let inner = st.get(v).map(|val| val.borrows.clone()).unwrap_or_default();
                        inner.into_iter().chain(std::iter::once(v.clone()))
                    })
                    .collect();
                return Val {
                    owned: false,
                    borrows,
                    dead: None,
                    key: None,
                    moved_in: false,
                };
            }
        }
        let e = op_delta_effect(op, self.ba);
        if let Some(Atom::Var(src)) = e.alias {
            // an alias of a closure capture (untracked: the closure holds it) borrows it
            if !st.contains_key(src) && self.captures.contains(src) {
                return Val {
                    owned: false,
                    borrows: HashSet::from([src.clone()]),
                    dead: None,
                    key: None,
                    moved_in: false,
                };
            }
            return st.get(src).cloned().unwrap_or_default();
        }
        // An array write (`setArray`) stores in place and returns the array it was given. The
        // table reads it as handing the array over for a fresh one, which is right for an array
        // this function holds; but a closure's capture (or an alias of one) stays the closure's:
        // the write's result IS that borrowed array, so freeing it frees what the closure still
        // holds and runs again on — a lambda writing an array it captured (`parFor`, `map`).
        if let Op::RtCall { func, args, .. } = op {
            if func == "axion_array_set" || func == "axion_array_set_nobc" {
                if let Some(Atom::Var(a)) = args.first() {
                    let held = st.get(a).is_some_and(|v| v.owned || v.moved_in);
                    let captured = self.captures.contains(a)
                        || st
                            .get(a)
                            .is_some_and(|v| v.borrows.iter().any(|b| self.captures.contains(b)));
                    if captured && !held {
                        let mut borrows = st.get(a).map(|v| v.borrows.clone()).unwrap_or_default();
                        borrows.insert(a.clone());
                        return Val {
                            owned: false,
                            borrows,
                            dead: None,
                            key: None,
                            moved_in: false,
                        };
                    }
                }
            }
        }
        // A BY-COPY record update shares every heap field it does not set with the record it
        // copies (`b { label = … }` keeps `b`'s `onClick` cell): the result borrows that record,
        // so freeing both is a double free. (Auto-Drop sets each such field to a copy.)
        // Recorded in the ELEMENT-share summary pass only, which callers apply: a function that
        // RETURNS such an update hands its caller a record sharing the argument's heap fields.
        // (Within one function Auto-Drop frees the result with a skip-destructor that leaves the
        // shared slots to the base — checked by the drop balance as usual.)
        // The CHECK pass applies the same sharing to an update of a record OWNED here: the result
        // borrows it until the base is freed with a skip-destructor that leaves the shared fields
        // to the result (`do_drop`) — so a full free of the base while the result lives or escapes
        // (`ret r` after `drop p : P`) is a use-after-free, and a full free of the result followed
        // by one of the base a double free (`dbl_rev`).
        let base_owned_here = |b: &str| {
            !self.mode.poly_elem && st.get(b).is_some_and(|v| v.owned && v.dead.is_none())
        };
        if let (
            Op::UpdateRecord {
                base: Atom::Var(b),
                fields,
                inplace: false,
                ..
            },
            true,
        ) = (
            op,
            self.mode.track_fields && (self.mode.poly_elem || base_owned_here(b_of(op))),
        ) {
            let names: Vec<&str> = fields.iter().map(|(n, _)| n.as_str()).collect();
            if self.recinfo.update_shares_heap(&names) {
                // the check pass borrows `b#sharedI` for each field slot I the result shares with
                // `b` — alive while `b` is, until a skip-drop of `b` leaving slot I releases it
                // (`do_drop`). Of `b`'s own slot borrows (`b` = an update of `b0`) only the slots
                // this update shares too are inherited: `b2 = b1 { t = … }` keeps nothing of `t`.
                let now = self.recinfo.update_shared_fields(&names);
                let mut borrows: HashSet<String> = if self.mode.poly_elem {
                    HashSet::from([b.clone()])
                } else {
                    now.iter().map(|&i| shared_name(b, i)).collect()
                };
                if let Some(bv) = st.get(b) {
                    borrows.extend(
                        bv.borrows
                            .iter()
                            .filter(|w| match w.split_once("#shared") {
                                Some((_, i)) if !self.mode.poly_elem => {
                                    i.parse::<usize>().is_ok_and(|i| now.contains(&i))
                                }
                                _ => true,
                            })
                            .cloned(),
                    );
                }
                return Val {
                    owned: true,
                    borrows,
                    dead: None,
                    key: None,
                    moved_in: false,
                };
            }
        }
        // A closure owns its cell and BORROWS every capture (the cell holds their pointers, the
        // lambda reads them on each call): freeing a capture while the closure can still be
        // called — or letting the closure escape past the capture's free — is a use-after-free.
        // An OWNING closure (it escapes its scope) moved fresh copies of its captures in: it is an
        // owned value that borrows nothing, freed (with them) by its own destructor.
        if let Op::MakeClosure { owns: true, .. } = op {
            return Val {
                owned: true,
                borrows: HashSet::new(),
                dead: None,
                key: Some("Closure".into()),
                moved_in: false,
            };
        }
        if let Op::MakeClosure { captures, .. } = op {
            let mut borrows = HashSet::new();
            for a in captures {
                if let Atom::Var(v) = a {
                    if let Some(val) = st.get(v) {
                        borrows.extend(val.borrows.iter().cloned());
                        if val.owned || val.moved_in || self.borrowed_params.contains(v) {
                            borrows.insert(v.clone());
                        }
                    }
                }
            }
            return Val {
                owned: true,
                borrows,
                dead: None,
                key: Some("Closure".into()),
                moved_in: false,
            };
        }
        let mut inherited: HashSet<String> = HashSet::new();
        for a in &e.moves {
            if let Atom::Var(v) = a {
                if let Some(val) = st.get(v) {
                    inherited.extend(val.borrows.iter().cloned());
                    // a moved-in param is TRANSFERRED, not lent: the result does not borrow it.
                    if !val.owned && !val.moved_in {
                        inherited.insert(v.clone());
                    }
                }
            }
        }
        // A constructor EMBEDS every operand into the fresh value — including a BORROWED
        // element (`Cons y ys` where `y` is a case-extracted element of a borrowed input).
        // So the result shares whatever those borrowed operands borrow. `e.moves` above only
        // captured the OWNED (moved-in) operands, not the borrowed embedded ones.
        // Confined to the ELEM-summary pass (`poly_elem`): there it lets a generic `take`'s
        // poly `Cons y ys` propagate the borrowed element so the summary records the share.
        // In the CHECK pass the heap-gated call-site hook below applies that summary directly,
        // so re-deriving borrows through every concrete constructor here would only over-flag
        // scalar builds (a plain `Cons 1 …`) as aliasing — a false positive.
        let con_args: &[Atom] = match op {
            Op::MakeCon { args, .. } | Op::MakeTuple(args) if self.mode.poly_elem => args,
            _ => &[],
        };
        for a in con_args {
            if let Atom::Var(v) = a {
                if let Some(val) = st.get(v) {
                    inherited.extend(val.borrows.iter().cloned());
                    // a moved-in param is TRANSFERRED, not lent: the result does not borrow it.
                    if !val.owned && !val.moved_in {
                        inherited.insert(v.clone());
                    }
                }
            }
        }
        // A call whose ELEMENT-alias summary says its OWNED result shares a heap element of
        // an argument (`take`/`drop` over a heap element type): the result borrows that arg,
        // so dropping BOTH double-frees the shared element (caught in `do_drop`).
        if let Op::CallDirect(g, args, _) = op {
            // Heap-GATED: apply only when the call's CONCRETE result element is heap
            // (`List$Integer` yes, `List$Int` no) — the generic summary is element-agnostic,
            // but the double-free only happens for a heap element, so a scalar `List Int`
            // result stays clean (no false positive, no regression of take-over-List-Int).
            // (…or a plain record with heap fields: `relabel b = b { label = … }` returns a record
            // sharing `b`'s unset heap fields.)
            let heap_elem = e
                .produces
                .as_ref()
                .and_then(|r| r.key.as_deref())
                .is_some_and(|k| {
                    key_elem_is_heap(k) || (!k.contains('$') && self.recinfo.needs_deep_drop(k))
                });
            if heap_elem {
                if let Some(params) = self.elem_aliases.get(g) {
                    for &i in params {
                        if let Some(Atom::Var(v)) = args.get(i) {
                            // an argument whose own key says every element is an unboxed scalar
                            // (`List$Int` into `map mkP`, `Either$Int$Int`) has no heap element
                            // to share.
                            if st
                                .get(v)
                                .and_then(|val| val.key.as_deref())
                                .is_some_and(|k| {
                                    k.contains('$')
                                        && k.split('$')
                                            .skip(1)
                                            .all(|e| matches!(e, "Int" | "Float" | "Bool" | "Char"))
                                })
                            {
                                continue;
                            }
                            // ONLY when the arg is BORROWED by the call, not MOVED. A moved arg
                            // (`tail`/`last`/`uncons`: `moves{xs}`) transfers ownership to the
                            // callee — the caller no longer frees it, so a result sharing its
                            // interior is a fresh owned transfer, NOT a double-free. The AX0912
                            // class is precisely the BORROWED input (`take`: `Δ{xs}` no move)
                            // that the caller ALSO drops alongside the aliasing result.
                            let moved = e
                                .moves
                                .iter()
                                .any(|m| matches!(m, Atom::Var(mv) if mv == v));
                            if !moved {
                                inherited.insert(v.clone());
                            }
                        }
                    }
                }
            }
        }
        if let Some(Atom::Var(w)) = alias_target(op, self.recinfo) {
            if st.contains_key(w.as_str()) {
                inherited.insert(w.clone());
                return Val {
                    owned: false,
                    borrows: inherited,
                    dead: None,
                    key: None,
                    moved_in: false,
                };
            }
        }
        if let Some(res) = &e.produces {
            return Val {
                owned: true,
                borrows: inherited,
                dead: None,
                key: res.key.clone(),
                moved_in: false,
            };
        }
        // A constructor with no concrete produce key (a POLYMORPHIC `Cons y ys` in a generic
        // function) still EMBEDS its borrowed operands — keep the inherited borrows so the
        // element-alias summary sees the share (`take` returns a list embedding a borrowed
        // element). Not owned here (unknown key); the concrete call site supplies ownership.
        if self.mode.poly_elem
            && !inherited.is_empty()
            && matches!(op, Op::MakeCon { .. } | Op::MakeTuple(_))
        {
            return Val {
                owned: false,
                borrows: inherited,
                dead: None,
                key: None,
                moved_in: false,
            };
        }
        Val::default()
    }

    /// `drop x`: `x` must be a live OWNED resource. `key` is the destructor type (`Some` =
    /// a DEEP drop that recurses into `x`'s fields; `None` = a SHELL free of just the cell,
    /// used when the fields were moved out and reused). `skip` lists the slots a deep drop
    /// does NOT free (moved out via a skip-destructor).
    fn do_drop(&mut self, x: &str, key: Option<&String>, skip: &[usize], sp: Span, st: &mut State) {
        self.note_field_gone(x, st);
        // a base freed with a skip-destructor leaves each skipped slot to whoever shares it (a
        // by-copy update's result, and whatever that moved into): those slot borrows are released
        for &i in skip {
            let name = shared_name(x, i);
            for v in st.values_mut() {
                v.borrows.remove(&name);
            }
        }
        // …and a RESULT freed with a skip-destructor leaving a shared slot to its base does not
        // free that field twice, whatever happened to the base
        let own_skip: HashSet<String> = self
            .shares
            .get(x)
            .map(|(b, idxs)| {
                idxs.iter()
                    .filter(|i| skip.contains(i))
                    .map(|&i| shared_name(b, i))
                    .collect()
            })
            .unwrap_or_default();
        // V-2 (docs/call-site-ownership.md): a deep-drop key whose type CONSTRUCTOR is a
        // primitive SCALAR (`Int$Int` → base `Int`) is ALWAYS a bad-free — you never
        // deep-drop an Int/Float/Bool/Char. This catches the multi-param-sum mis-key
        // class (`cond_elem_key`'s naive `$`-split turned `Either$Int$Int`'s Right
        // payload into the bogus container key `Int$Int`, freeing a scalar) INDEPENDENTLY
        // of the value's tracked key — which was `None` (scalar) there, so the tagged
        // cross-check below was skipped and the bad-free slipped through. Checked whether or not
        // `x` is tracked (a field the scrutinee key makes scalar is not bound at all).
        // 0-false-positive: no legitimate destructor key has a scalar base.
        if let Some(dk) = key {
            if matches!(ctor_base(dk), "Int" | "Float" | "Bool" | "Char") {
                self.finding(Cat::WrongDropKey, x, sp);
            }
        }
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
                // An unkeyed (flat) free of a value that owns a heap resource moved into it
                // reclaims only the cell: the moved-in resource leaks.
                if key.is_none() && skip.is_empty() && self.heap_inside.contains_key(x) {
                    self.finding(Cat::Leak, x, sp);
                }
                // A deep drop of an OWNED value that shares a heap element with an
                // already-freed resource (its `borrows` name a dead value — the
                // element-alias class, `take`/`drop` over a heap element type) frees that
                // shared element a SECOND time. Deep only (`key.is_some()`): a shell free
                // touches just the cell, not the shared element.
                if key.is_some() {
                    let dbl = st.get(x).is_some_and(|v| {
                        v.borrows
                            .iter()
                            .any(|w| !own_skip.contains(w.as_str()) && borrow_dead(st, w))
                    });
                    // …and the other order: an OWNED value sharing `x`'s contents (a by-copy
                    // record update returned from a call, a `take`-style result) was already
                    // deep-freed, so freeing `x` deeply frees the shared part a second time.
                    let dbl_rev = st.iter().any(|(w, wv)| {
                        w != x
                            && wv.owned
                            && wv.dead == Some(Cat::DoubleFree)
                            && self.deep_freed.contains(w)
                            && (wv.borrows.contains(x)
                                || wv
                                    .borrows
                                    .iter()
                                    .any(|w| w.starts_with(&format!("{x}#shared"))))
                    });
                    if dbl || dbl_rev {
                        self.finding(Cat::DoubleFree, x, sp);
                    }
                }
                // drop-key cross-check: a value KNOWN to be a boxed `Integer`/`String` must be
                // freed by its tagged reclaimer (`Some("Integer")`/`Some("String")`). Any other
                // key — a flat `free` (`None`) of a bignum/string, or a mismatched tag — is a
                // bad-free / leak. Only fires when the value's key is DEFINITELY tagged (from its
                // producer or a resolved poly field), so it is 0-false-positive.
                let vkey = st.get(x).and_then(|v| v.key.clone());
                if let Some(vk) = vkey {
                    // `Integer`/`String` are boxed scalars that MUST be freed by their exact
                    // tagged reclaimer — even a shell free (`None`) leaks limbs/bytes, so any
                    // key other than the tag is a bad-free.
                    let bad = if vk == "Integer" || vk == "String" {
                        key != Some(&vk)
                    } else {
                        // Any other keyed value (a container `List$Int`, `Either$..`, …): a DEEP
                        // drop (`Some`) must name the value's own type CONSTRUCTOR. Compare the
                        // base (before `$`) so generic-vs-mono naming (`List` ↔ `List$Int`) is
                        // NOT a mismatch — only a different constructor (`Wrong` ↔ `List`) is a
                        // real bad-free. A SHELL free (`None`) is legitimate (payload moved out,
                        // cell-only free) and never checked. This stays 0-false-positive.
                        key.is_some_and(|dk| ctor_base(dk) != ctor_base(&vk))
                    };
                    if bad {
                        self.finding(Cat::WrongDropKey, x, sp);
                    }
                }
                if key.is_some() && skip.is_empty() {
                    self.deep_freed.insert(x.to_string());
                }
                if let Some(v) = st.get_mut(x) {
                    v.dead = Some(Cat::DoubleFree);
                }
                // a DEEP drop of `x` (has a destructor key) frees its extracted fields
                // transitively: mark every still-live child whose slot is NOT skipped as
                // freed-via-parent, so it is neither reported as a leak nor droppable again
                // (a later `drop` of it would now be a DoubleFree — a strengthening). A SHELL
                // free (`key = None`) frees only the cell — the fields were moved out and
                // reused (`append`'s `Cons z zs -> drop xs; …`), so it frees no child.
                // a DEEP drop of a value whose fields were already moved out or freed (and are not
                // skipped) frees them again
                if key.is_some() {
                    let gone: Vec<usize> = self
                        .consumed_slots
                        .get(x)
                        .map(|s| s.iter().copied().filter(|i| !skip.contains(i)).collect())
                        .unwrap_or_default();
                    if !gone.is_empty() {
                        self.finding(Cat::DoubleFree, x, sp);
                    }
                }
                let kids = key.and(self.children.get(x)).cloned().unwrap_or_default();
                for (child, slot) in kids {
                    if !skip.contains(&slot) {
                        if let Some(cv) = st.get_mut(&child) {
                            if cv.owned && cv.dead.is_none() {
                                cv.dead = Some(Cat::DoubleFree);
                                // a nested field (`case p of (c, n)` under `(a, p)`) goes too
                                self.kill_descendants(&child, Cat::DoubleFree, st);
                            }
                        }
                    }
                }
                // §move-out: a skipped slot's heap field is MOVED OUT to whoever projected
                // it — transfer ownership so the projection outlives `x`'s shell free (it no
                // longer borrows the now-freed cell; it owns the moved field). Without this
                // the projection would dangle on `x`'s death (a false UseAfterFree).
                if !skip.is_empty() {
                    // (a slot skipped because it is SHARED with a by-copy update's base stays
                    // with that base — it is not moved out to a projection)
                    // (as an update's result, or as the base of one)
                    let shared_slots: Vec<usize> = self
                        .shares
                        .iter()
                        .filter(|(r, (b, _))| r.as_str() == x || b == x)
                        .flat_map(|(_, (_, idxs))| idxs.iter().copied())
                        .collect();
                    let promote: Vec<String> = self
                        .projections
                        .iter()
                        .filter(|(_, (src, slot))| {
                            src == x && skip.contains(slot) && !shared_slots.contains(slot)
                        })
                        .map(|(pv, _)| pv.clone())
                        .collect();
                    for pv in promote {
                        if let Some(pval) = st.get_mut(&pv) {
                            if pval.dead.is_none() {
                                pval.owned = true;
                                pval.borrows.remove(x);
                            }
                        }
                    }
                }
            }
            None => {} // dropping an untracked value (a flat free of a non-resource) — inert
        }
    }

    /// A `ret`: the returned value escapes. Returns its resource classification (so a
    /// `let`-bound `if`/`case` learns whether its value is a resource).
    fn ret(&mut self, rhs: &Rhs, sp: Span, st: &mut State, tail: bool) -> Val {
        match rhs {
            Rhs::Op(op) => {
                let e = op_delta_effect(op, self.ba);
                for a in e
                    .borrows
                    .iter()
                    .chain(e.moves.iter())
                    .chain(e.nonstrict.iter())
                {
                    self.use_atom(a, sp, st);
                }
                if let Some(a) = e.alias {
                    self.use_atom(a, sp, st);
                }
                let mut ret_val = self.classify(op, st);
                // a String literal returned from the function is a FRESH heap string the caller
                // owns (and frees) — what `mixed_exit` compares an interior-alias path against
                if tail && matches!(op, Op::Atom(Atom::Str(_))) {
                    ret_val.owned = true;
                }
                if let Some(Atom::Var(src)) = e.alias {
                    self.kill_whole(src, Cat::UseAfterFree, st);
                }
                // returned/consumed resources escape → mark moved so they aren't leaks: the
                // moved operands (an indirect call only borrows its closure).
                // `consume` also flags consuming an interior alias of a borrowed resource.
                self.consume(op, sp, st);
                // a leak is only meaningful at a real function EXIT — an internal branch-ret
                // (the value of a let-bound `if`/`case`) has a continuation that may still
                // consume the resource, so it is not a leak point.
                if tail {
                    self.leak_check(sp, st);
                }
                ret_val
            }
            Rhs::If(c, th, el) => {
                self.use_atom(c, sp, st);
                self.branches(&[th.as_ref(), el.as_ref()], sp, st, tail)
            }
            Rhs::Case(scrut, arms) => self.case(scrut, arms, sp, st, tail),
        }
    }

    /// Verify each branch on a clone of `st`, reconcile the live-owned sets at the join
    /// (leaving the merged state in `st`), and return the MERGED classification of the value
    /// the branches yield — owned/alias only if a branch actually returns a resource.
    fn branches(&mut self, arms: &[&Term], sp: Span, st: &mut State, tail: bool) -> Val {
        let outer: Vec<String> = st.keys().cloned().collect();
        let mut exits: Vec<State> = Vec::new();
        let mut rets: Vec<Val> = Vec::new();
        let before = self.consumed_slots.clone();
        let mut after = before.clone();
        for a in arms {
            let mut s = st.clone();
            self.consumed_slots = before.clone();
            rets.push(self.term(a, &mut s, tail));
            exits.push(s);
            union_slots(&mut after, &self.consumed_slots);
        }
        self.consumed_slots = after;
        self.merge(&outer, &exits, sp, st);
        self.mixed_exit(&rets, sp, tail);
        merge_vals(&rets)
    }

    /// A function EXIT whose paths disagree on what they hand back: one returns an interior of a
    /// value the function does not own (a field of a borrowed parameter — `owned == false` with
    /// borrows), another a fresh value it owns. No caller can reclaim that result correctly: as an
    /// owned value it frees memory the argument's owner frees again (a double free); as a borrow
    /// it leaks the fresh one. The all-interior return (`grab w = inner w`) is a pure borrow
    /// return, summarised for the callers (`borrow_return_summary`); an owned value that shares
    /// fields with a parameter (a record update) is `owned` with borrows, not this.
    fn mixed_exit(&mut self, rets: &[Val], sp: Span, tail: bool) {
        if !tail || !rets.iter().any(|v| v.owned) {
            return;
        }
        let interior = rets
            .iter()
            .filter(|v| !v.owned)
            .flat_map(|v| v.borrows.iter())
            .min()
            .cloned();
        if let Some(root) = interior {
            self.finding(Cat::DoubleFree, &root, sp);
        }
    }

    fn case(
        &mut self,
        scrut: &Atom,
        arms: &[(CPat, Term)],
        sp: Span,
        st: &mut State,
        tail: bool,
    ) -> Val {
        self.use_atom(scrut, sp, st);
        // A slot a `case` binds to a variable is moved out of the value (the variable is tracked
        // as owned from here), so it no longer counts toward `heap_inside`; a wildcard slot stays.
        if let Atom::Var(v) = scrut {
            if let Some(slots) = self.heap_inside.get_mut(v) {
                for (pat, _) in arms {
                    if let CPat::Tuple(subs) | CPat::Con(_, subs) = pat {
                        for (i, sp) in subs.iter().enumerate() {
                            if !matches!(sp, CPat::Wild) {
                                slots.remove(&i);
                            }
                        }
                    }
                }
                if slots.is_empty() {
                    self.heap_inside.remove(v);
                }
            }
        }
        // extracted fields are owned iff the scrutinee is an owned resource (consumed) — the
        // reclamation transfers them out. A BORROWED scrutinee's heap fields are INTERIOR
        // ALIASES of it: reading one is fine, but CONSUMING one (moving it into a callee or a
        // new structure) frees memory the owner still holds — `consume` catches that. `scrut_var`
        // now names any live tracked scrutinee; `scrut_owned` selects the two field treatments.
        let (scrut_var, scrut_owned) = match scrut {
            Atom::Var(n) => match st.get(n) {
                Some(v) if v.dead.is_none() => (Some(n.clone()), v.owned),
                _ => (None, false),
            },
            _ => (None, false),
        };
        let outer: Vec<String> = st.keys().cloned().collect();
        let mut exits: Vec<State> = Vec::new();
        let mut rets: Vec<Val> = Vec::new();
        let slots_before = self.consumed_slots.clone();
        let mut slots_after = slots_before.clone();
        for (pat, body) in arms {
            let mut s = st.clone();
            self.consumed_slots = slots_before.clone();
            self.bind_pattern(pat, scrut_var.as_deref(), scrut_owned, &mut s);
            // the arm's field binders → (scrutinee, slot), while the arm is checked
            let mut saved_binders: Vec<(String, Option<(String, usize)>)> = Vec::new();
            if let (Atom::Var(sv), CPat::Con(_, subs)) = (scrut, pat) {
                for (i, sp) in subs.iter().enumerate() {
                    if let CPat::Var(n) = sp {
                        let old = self.binder_of.insert(n.clone(), (sv.clone(), i));
                        saved_binders.push((n.clone(), old));
                    }
                }
            }
            // the arm's constructor, for raw field loads of the scrutinee inside it (`raw_slot`).
            let prev = match (scrut, pat) {
                (Atom::Var(v), CPat::Con(con, _)) => {
                    Some((v.clone(), self.arm_con.insert(v.clone(), con.clone())))
                }
                _ => None,
            };
            rets.push(self.term(body, &mut s, tail));
            if let Some((v, old)) = prev {
                match old {
                    Some(c) => self.arm_con.insert(v, c),
                    None => self.arm_con.remove(&v),
                };
            }
            for (n, old) in saved_binders {
                match old {
                    Some(o) => self.binder_of.insert(n, o),
                    None => self.binder_of.remove(&n),
                };
            }
            union_slots(&mut slots_after, &self.consumed_slots);
            exits.push(s);
        }
        self.consumed_slots = slots_after;
        self.merge(&outer, &exits, sp, st);
        self.mixed_exit(&rets, sp, tail);
        merge_vals(&rets)
    }

    /// Bind a `case` pattern's field variables: a heap field the pattern names is either a
    /// `%1`-owned slot transferred OUT of the scrutinee (an owned resource) or a borrowed
    /// interior alias of the scrutinee.
    fn bind_pattern(
        &mut self,
        pat: &CPat,
        scrut_var: Option<&str>,
        scrut_owned: bool,
        st: &mut State,
    ) {
        let Some(scrut) = scrut_var else {
            return;
        };
        // the scrutinee's own reclaim key (known only when it was locally PRODUCED — a param has
        // no key here), so a poly field can resolve to its tagged reclaimer for the drop-key check.
        let scrut_key = st.get(scrut).and_then(|v| v.key.clone());
        // The scrutinee's OWN borrow set, so an interior field inherits it transitively: a field `h`
        // of a borrowed tuple `p` that is itself an interior of a borrowed param `m` must carry `m`
        // in its borrows, or `consume`'s `borrowed_params` membership test (which only knows the
        // real borrow param `m`, not the intermediate `p`) would miss the double-free. Also closes
        // the same latent limitation for `Con` fields nested under another borrowed extraction.
        let scrut_borrows = st.get(scrut).map(|v| v.borrows.clone()).unwrap_or_default();
        let interior_borrows = || {
            let mut b = scrut_borrows.clone();
            b.insert(scrut.to_string());
            b
        };
        if let CPat::Con(con, subs) = pat {
            for (i, sp) in subs.iter().enumerate() {
                if let CPat::Var(n) = sp {
                    if !self.recinfo.field_transfers_heap(con, i) {
                        continue;
                    }
                    if !scrut_owned {
                        // BORROWED scrutinee: a CONCRETE heap field is an INTERIOR ALIAS of it —
                        // the owner keeps the whole structure. Reading it is fine; `consume`
                        // flags moving it into a callee that frees it (a double-free of the
                        // owner's memory — the partial-consumer-over-a-heap-element class). A
                        // POLYMORPHIC field (no concrete drop slot) may instantiate to a scalar,
                        // so — like the leak-exempt policy for owned poly fields — it is left
                        // untracked (freeing a scalar is a no-op; only a concrete heap field is a
                        // definite double-free).
                        if self.mode.track_fields {
                            // Resolve the element's CONCRETE type from the scrutinee's mono key
                            // (`List$String` → `String`) — available now that borrowed container
                            // params carry their signature key. A resolved (concrete heap) element is
                            // tracked with its key and NOT marked poly, so `consume` flags it
                            // directly (soundly). Only a genuinely UNRESOLVED element (a truly
                            // polymorphic container, no scrutinee key) falls back to the
                            // `frees_heap`-gated poly path.
                            let fkey = scrut_key
                                .as_deref()
                                .and_then(|sk| self.recinfo.field_tagged_key(con, i, sk));
                            st.insert(
                                n.clone(),
                                Val {
                                    owned: false,
                                    borrows: interior_borrows(),
                                    key: fkey.clone(),
                                    ..Default::default()
                                },
                            );
                            if fkey.is_none()
                                && !self.mode.poly_elem
                                && self.recinfo.field_drop_slot(con, i).is_none()
                            {
                                self.poly_borrowed.insert(n.clone());
                            }
                        }
                        continue;
                    }
                    // A polymorphic field that the scrutinee's key instantiates to a SCALAR (the
                    // `Int` element of a `List$Int` in a specialized clone) is a copied value, not a
                    // resource: moving it (into a closure call) and using it again is fine.
                    if scrut_key
                        .as_deref()
                        .is_some_and(|sk| self.recinfo.field_is_scalar_under(con, i, sk))
                    {
                        continue;
                    }
                    // OWNED (consumed) scrutinee: the heap field transfers OUT as an owned resource.
                    let fkey = scrut_key
                        .as_deref()
                        .and_then(|sk| self.recinfo.field_tagged_key(con, i, sk));
                    st.insert(
                        n.clone(),
                        Val {
                            owned: true,
                            key: fkey,
                            ..Default::default()
                        },
                    );
                    // record the field as a CHILD of its scrutinee at slot `i`: a DEEP
                    // `drop` of the scrutinee frees it transitively (see `do_drop`), so it
                    // is not a separate leak unless the arm moves it out first.
                    self.children
                        .entry(scrut.to_string())
                        .or_default()
                        .push((n.clone(), i));
                    // a POLYMORPHIC field (transfers heap but has NO concrete drop slot —
                    // a bare type variable) may instantiate to a scalar, so exempt it from
                    // leak reporting (see `leak_exempt`); it stays owned for double-free.
                    // …unless the scrutinee's key resolves it to a HEAP type: then its
                    // reclamation is known and a missing drop is a plain leak
                    let resolved = scrut_key
                        .as_deref()
                        .is_some_and(|sk| self.recinfo.field_heap_under(con, i, sk));
                    if self.recinfo.field_drop_slot(con, i).is_none()
                        && !resolved
                        && !strict_leaks("poly")
                    {
                        self.leak_exempt.insert(n.clone());
                    }
                }
            }
        } else if let CPat::Tuple(subs) = pat {
            // Anonymous tuples get the Con arm's BORROWED-scrutinee treatment: a heap field of a
            // borrowed tuple is an INTERIOR ALIAS of it, so `consume` flags moving one into a callee
            // that frees it (the consume-of-borrowed-tuple-field double-free the verifier used to
            // miss — a tuple has no `CPat::Con` so it previously bound NOTHING). Per-field heap-ness
            // and reclaim key come from segmenting the scrutinee's tuple mono-key (`tuple2$String$Int`
            // → ["String","Int"]) rather than a constructor's drop slots. Only the BORROWED case is
            // tracked: an OWNED tuple's fields already reclaim soundly via the Core skip-destructors
            // (the tuple_owned / nested_tuple_extract_escape / tuple_elem_discard fixtures are
            // LSan leak-gated), and tracking them here would risk a scalar-field leak false-positive.
            // …except that a skip-destructor leaves its slot to the binder, which must then be
            // freed or handed on (`let s = case t of (a, _) -> a` once leaked `a` unseen). So an
            // OWNED tuple's heap fields are tracked like a constructor's — owned, children of the
            // scrutinee — when its key segments (a scalar field then is not heap, so no false
            // positive); an unsegmented key leaves them untracked as before.
            if scrut_owned {
                let field_keys = scrut_key
                    .as_deref()
                    .and_then(|k| self.recinfo.split_tuple_key(k, subs.len()));
                if let Some(ks) = field_keys {
                    for (i, sp) in subs.iter().enumerate() {
                        let CPat::Var(n) = sp else { continue };
                        let Some(cls) = ks
                            .get(i)
                            .and_then(|el| self.recinfo.classify_tuple_elem(el))
                        else {
                            continue;
                        };
                        st.insert(
                            n.clone(),
                            Val {
                                owned: true,
                                key: cls,
                                ..Default::default()
                            },
                        );
                        self.children
                            .entry(scrut.to_string())
                            .or_default()
                            .push((n.clone(), i));
                    }
                }
            }
            if !scrut_owned && self.mode.track_fields {
                // segment the tuple key into per-field keys; `None` ⇒ unknown (no scrut key / arity
                // mismatch) ⇒ fields are tracked CONSERVATIVELY (see `track` below).
                let field_keys = scrut_key
                    .as_deref()
                    .and_then(|k| self.recinfo.split_tuple_key(k, subs.len()));
                for (i, sp) in subs.iter().enumerate() {
                    if let CPat::Var(n) = sp {
                        // `classify_tuple_elem`: None ⇒ scalar/non-heap; Some(_) ⇒ heap (inner is the
                        // Option reclaimer key). When the key segmented, track ONLY heap fields; when
                        // it did NOT segment, track every field — soundly, because an unresolved field
                        // is marked `poly_borrowed`, so `consume` only fires for it via `frees_heap`
                        // (a heap-param position), which a scalar field can never occupy in well-typed
                        // Core, so no scalar false-positive arises.
                        let cls = field_keys
                            .as_ref()
                            .and_then(|ks| ks.get(i))
                            .and_then(|el| self.recinfo.classify_tuple_elem(el));
                        let track = if field_keys.is_some() {
                            cls.is_some() // segmented → heap iff classified as droppable
                        } else {
                            true // unsegmented → conservative (poly_borrowed-gated below)
                        };
                        if !track {
                            continue;
                        }
                        // the tagged reclaimer key, matching the Con arm's `field_tagged_key`
                        // semantics (only `Integer`/`String` drive the drop-key cross-check).
                        let fkey = cls.flatten().filter(|k| k == "Integer" || k == "String");
                        st.insert(
                            n.clone(),
                            Val {
                                owned: false,
                                borrows: interior_borrows(),
                                key: fkey.clone(),
                                ..Default::default()
                            },
                        );
                        if fkey.is_none() && !self.mode.poly_elem {
                            self.poly_borrowed.insert(n.clone());
                        }
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
            merged.borrows = vals
                .iter()
                .flat_map(|v| v.borrows.iter().cloned())
                .collect();
            if any_live && !all_live {
                // A POLYMORPHIC extracted field (heap-ness unresolved → `leak_exempt`) that is
                // owned on one path and moved out on another can only LEAK on the still-live
                // path — never a double-free (the `dead` marker below still catches a later
                // use/drop as UAF/DoubleFree). Its heap-ness is unknown here, exactly as at
                // `leak_check`, so a branch imbalance of such a field is a (possibly-scalar)
                // leak, not corruption: suppress the Unbalanced report to match the leak-exempt
                // policy (a `%1`-consumed `filter`/`keepFirst` discards its poly element on the
                // else path — reclamation can't drop a bare type variable without a witness, so
                // the imbalance is the expected poly-drop gap, not unsafe code).
                if !self.leak_exempt.contains(name) {
                    self.finding(Cat::Unbalanced, name, sp);
                }
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

    /// Any owned resource still live at a `ret` (and not the returned value) is a leak —
    /// EXCEPT a polymorphic extracted field, whose heap-ness is unresolved here (see
    /// `leak_exempt`); reporting it would false-flag a scalar instantiation.
    fn leak_check(&mut self, sp: Span, st: &State) {
        for (name, v) in st {
            if v.owned && v.dead.is_none() && !self.leak_exempt.contains(name) {
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
            if borrow_dead(st, w) {
                self.finding(Cat::UseAfterFree, v, sp); // dangling interior alias
            }
        }
    }

    /// `v` leaves WHOLE (moved, returned, aliased into a result): the fields a `case` bound out
    /// of it and never moved travel with it (`Just s -> a` hands `s` on inside `a`), so they
    /// stop being separate owned values here — as a deep `drop` of `v` retires them.
    fn kill_whole(&mut self, v: &str, cat: Cat, st: &mut State) {
        if st.get(v).is_some_and(|val| val.owned && val.dead.is_none()) {
            let gone = self.consumed_slots.get(v).cloned().unwrap_or_default();
            for (child, slot) in self.children.get(v).cloned().unwrap_or_default() {
                if !gone.contains(&slot) && st.get(&child).is_some_and(|c| c.dead.is_none()) {
                    Self::kill(&child, Cat::UseAfterFree, st);
                    self.kill_descendants(&child, Cat::UseAfterFree, st);
                }
            }
        }
        Self::kill(v, cat, st);
    }

    /// The live fields bound out of `v` (and out of those, transitively) that were not moved
    /// on: they die with `v`, which a deep free or a whole move just retired.
    fn kill_descendants(&self, v: &str, cat: Cat, st: &mut State) {
        let gone = self.consumed_slots.get(v).cloned().unwrap_or_default();
        for (child, slot) in self.children.get(v).cloned().unwrap_or_default() {
            if !gone.contains(&slot) && st.get(&child).is_some_and(|c| c.owned && c.dead.is_none())
            {
                Self::kill(&child, cat, st);
                self.kill_descendants(&child, cat, st);
            }
        }
    }

    /// Mark `v` moved-out/consumed. Only an OWNED resource dies on a move — a scalar is
    /// COPIED and an interior alias is a shared pointer (copying it is fine; its target
    /// still governs its validity), so neither is killed.
    fn kill(v: &str, cat: Cat, st: &mut State) {
        if let Some(val) = st.get_mut(v) {
            if (val.owned || val.moved_in) && val.dead.is_none() {
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
            param_keys: std::collections::HashMap::new(),
            param_leaf: std::collections::HashMap::new(),
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

    /// A closure borrows its captures: freeing one before the closure's call is a
    /// use-after-free (the old Auto-Drop placement), and freeing it after is clean — as is
    /// calling the closure twice (a call borrows the closure).
    #[test]
    fn closure_capture_must_outlive_its_calls() {
        let sp = (0, 0);
        let clo = |rest: Term| {
            Term::Let(
                "s".into(),
                Rhs::Op(Op::ShowInt(Atom::Int(7))),
                sp,
                Box::new(Term::Let(
                    "g".into(),
                    Rhs::Op(Op::MakeClosure {
                        func: "lam".into(),
                        captures: vec![Atom::Var("s".into())],
                        owns: false,
                    }),
                    sp,
                    Box::new(rest),
                )),
            )
        };
        let call = |x: &str, rest: Term| {
            Term::Let(
                x.into(),
                Rhs::Op(Op::CallClosure(Atom::Var("g".into()), vec![Atom::Int(1)])),
                sp,
                Box::new(rest),
            )
        };
        let drop = |v: &str, key: Option<&str>, rest: Term| {
            Term::Drop(
                v.into(),
                key.map(str::to_string),
                vec![],
                sp,
                Box::new(rest),
            )
        };
        let ret = || Term::Ret(Rhs::Op(Op::Atom(Atom::Var("r".into()))), sp);
        // drop s; call g  → UAF
        let early = clo(drop("s", Some("String"), call("r", drop("g", None, ret()))));
        let fs = one(fn_body(early));
        assert!(
            fs.iter()
                .any(|f| f.cat == Cat::UseAfterFree && f.var == "g"),
            "expected a UseAfterFree of the closure, got {fs:?}"
        );
        // call g twice; drop g; drop s  → clean
        let ok = clo(call(
            "q",
            call("r", drop("g", None, drop("s", Some("String"), ret()))),
        ));
        let fs = one(fn_body(ok));
        assert!(fs.is_empty(), "expected no findings, got {fs:?}");
    }

    /// `let s = show 7; let t = (s, 1); <tail on t>; ret 0` — `s` (an owned heap String) is
    /// moved into the tuple, so only a keyed (deep) drop of `t` reclaims it.
    fn string_in_tuple(drop_key: Option<String>, destructure_first: bool) -> CoreFn {
        let ret0 = || Box::new(Term::Ret(Rhs::Op(Op::Atom(Atom::Int(0))), (0, 0)));
        let drop_t = Term::Drop("t".into(), drop_key, vec![], (0, 0), ret0());
        let after_t = if destructure_first {
            // case t of (a, b) -> drop a : String ; drop t ; ret 0   (field moved out first)
            Term::Ret(
                Rhs::Case(
                    Atom::Var("t".into()),
                    vec![(
                        CPat::Tuple(vec![CPat::Var("a".into()), CPat::Var("b".into())]),
                        Term::Drop(
                            "a".into(),
                            Some("String".into()),
                            vec![],
                            (0, 0),
                            Box::new(drop_t),
                        ),
                    )],
                ),
                (0, 0),
            )
        } else {
            drop_t
        };
        fn_body(Term::Let(
            "s".into(),
            Rhs::Op(Op::ShowInt(Atom::Int(7))),
            (0, 0),
            Box::new(Term::Let(
                "t".into(),
                Rhs::Op(Op::MakeTuple(vec![Atom::Var("s".into()), Atom::Int(1)])),
                (0, 0),
                Box::new(after_t),
            )),
        ))
    }

    /// A flat (unkeyed) free of a tuple that owns a moved-in String frees only the cell: the
    /// String leaks. The verifier used to accept this (LSan caught it, the verifier did not).
    #[test]
    fn flags_flat_free_of_value_owning_moved_in_heap() {
        let fs = one(string_in_tuple(None, false));
        assert!(
            fs.iter().any(|f| f.cat == Cat::Leak && f.var == "t"),
            "expected a leak on `t`, got {fs:?}"
        );
        // the keyed drop reclaims the String: clean
        let fs = one(string_in_tuple(Some("tuple2$String$Int".into()), false));
        assert!(fs.is_empty(), "keyed drop must be clean, got {fs:?}");
        // a shell free after the field was moved out by a `case` is correct: clean
        let fs = one(string_in_tuple(None, true));
        assert!(
            !fs.iter().any(|f| f.cat == Cat::Leak && f.var == "t"),
            "shell free after move-out flagged: {fs:?}"
        );
    }

    /// `twice xs = let a = call sink xs; let b = call sink xs; ret 0`, where `sink` owns its
    /// argument (frees it) and `twice`'s `xs` is not borrowed (its caller moved it in). Handing
    /// `xs` to `sink` twice frees it twice; the verifier used to accept it because `xs` has no
    /// `%1` and so was treated as a borrow.
    #[test]
    fn flags_a_moved_in_param_handed_over_twice() {
        let ret0 = || Box::new(Term::Ret(Rhs::Op(Op::Atom(Atom::Int(0))), (0, 0)));
        let call = |v: &str, k: Box<Term>| {
            Box::new(Term::Let(
                v.into(),
                Rhs::Op(Op::CallDirect(
                    "sink".into(),
                    vec![Atom::Var("xs".into())],
                    None,
                )),
                (0, 0),
                k,
            ))
        };
        let sink = CoreFn {
            name: "sink".into(),
            params: vec!["xs".into()],
            captures: vec![],
            is_closure: false,
            owned_params: vec!["xs".into()],
            owned_drop_ty: vec![("xs".into(), Some("List$String".into()))],
            body: Term::Drop(
                "xs".into(),
                Some("List$String".into()),
                vec![],
                (0, 0),
                ret0(),
            ),
        };
        let twice = |n: usize| CoreFn {
            name: "twice".into(),
            params: vec!["xs".into()],
            captures: vec![],
            is_closure: false,
            owned_params: vec![],
            owned_drop_ty: vec![],
            body: if n == 2 {
                *call("a", call("b", ret0()))
            } else {
                *call("a", ret0())
            },
        };
        let run = |n: usize| {
            verify(&Lowered {
                fns: vec![sink.clone(), twice(n)],
                borrow_args: BorrowArgs::new(),
                recinfo: RecordInfo::default(),
                param_keys: [("twice".to_string(), vec![Some("List$String".to_string())])]
                    .into_iter()
                    .collect(),
                param_leaf: std::collections::HashMap::new(),
            })
        };
        let fs = run(2);
        assert!(
            fs.iter()
                .any(|f| f.cat == Cat::UseAfterFree && f.var == "xs"),
            "expected the second hand-over of `xs` flagged, got {fs:?}"
        );
        let fs = run(1);
        assert!(
            fs.is_empty(),
            "a single hand-over must be clean, got {fs:?}"
        );
    }

    /// `let s1 = show 1; let s2 = show 2; let t = (s1, s2); case t of (a, <second>) -> drop a :
    /// String; [drop b : String;] drop t; ret 0` — the shell's flat free is correct only once
    /// BOTH slots were moved out.
    fn two_strings(bind_second: bool) -> CoreFn {
        let ret0 = || Box::new(Term::Ret(Rhs::Op(Op::Atom(Atom::Int(0))), (0, 0)));
        let s_drop = |v: &str, k: Box<Term>| {
            Box::new(Term::Drop(
                v.into(),
                Some("String".into()),
                vec![],
                (0, 0),
                k,
            ))
        };
        let drop_t = Box::new(Term::Drop("t".into(), None, vec![], (0, 0), ret0()));
        let (second, arm) = if bind_second {
            (CPat::Var("b".into()), s_drop("a", s_drop("b", drop_t)))
        } else {
            (CPat::Wild, s_drop("a", drop_t))
        };
        let show = |v: &str, n: i64, k: Term| {
            Term::Let(
                v.into(),
                Rhs::Op(Op::ShowInt(Atom::Int(n))),
                (0, 0),
                Box::new(k),
            )
        };
        fn_body(show(
            "s1",
            1,
            show(
                "s2",
                2,
                Term::Let(
                    "t".into(),
                    Rhs::Op(Op::MakeTuple(vec![
                        Atom::Var("s1".into()),
                        Atom::Var("s2".into()),
                    ])),
                    (0, 0),
                    Box::new(Term::Ret(
                        Rhs::Case(
                            Atom::Var("t".into()),
                            vec![(CPat::Tuple(vec![CPat::Var("a".into()), second]), *arm)],
                        ),
                        (0, 0),
                    )),
                ),
            ),
        ))
    }

    /// A `case` that leaves a heap slot as `_` does not move it out: the shell's flat free then
    /// leaks it. Binding every heap slot (each then freed on its own) makes the flat free correct.
    #[test]
    fn flat_free_after_partial_move_out_is_a_leak() {
        let fs = one(two_strings(false));
        assert!(
            fs.iter().any(|f| f.cat == Cat::Leak && f.var == "t"),
            "expected a leak on `t`, got {fs:?}"
        );
        let fs = one(two_strings(true));
        assert!(
            fs.is_empty(),
            "every slot moved out: expected clean, got {fs:?}"
        );
    }

    fn bignum(name: &str, dropkey: Option<String>, body_tail: Term) -> CoreFn {
        // let x = rtcall axion_bignum_from_i64 8 ; drop x [dropkey] ; <tail>
        let body = Term::Let(
            name.into(),
            Rhs::Op(Op::RtCall {
                func: "axion_bignum_from_i64".into(),
                args: vec![Atom::Int(8)],
                returns: true,
            }),
            (0, 0),
            Box::new(Term::Drop(
                name.into(),
                dropkey,
                vec![],
                (0, 0),
                Box::new(body_tail),
            )),
        );
        fn_body(body)
    }

    /// The drop-key cross-check CATCHES a boxed `Integer` freed with the wrong reclaimer —
    /// a flat `free` (`key = None`) instead of `axion_bignum_free` (`Some("Integer")`). This
    /// is the class the multi-param bad-free belonged to; freeing a bignum as a plain cell
    /// leaks its limbs / bad-frees a tagged value.
    #[test]
    fn flags_wrong_drop_key_on_integer() {
        let ret0 = Term::Ret(Rhs::Op(Op::Atom(Atom::Int(0))), (0, 0));
        let fs = one(bignum("x", None, ret0));
        assert!(
            fs.iter().any(|f| f.cat == Cat::WrongDropKey),
            "expected WrongDropKey for a flat-freed Integer, got {fs:?}"
        );
    }

    /// The dual: freeing the same boxed `Integer` with its CORRECT tagged key is clean — the
    /// cross-check is not vacuously firing.
    #[test]
    fn correct_integer_drop_key_is_ok() {
        let ret0 = Term::Ret(Rhs::Op(Op::Atom(Atom::Int(0))), (0, 0));
        let fs = one(bignum("x", Some("Integer".into()), ret0));
        assert!(
            !fs.iter().any(|f| f.cat == Cat::WrongDropKey),
            "a correctly-keyed Integer drop must not flag, got {fs:?}"
        );
    }

    /// The drop-key check reaches a PARAMETER's key too (seeded from `owned_drop_ty`): a `%1`
    /// `Integer` param flat-freed (`key = None`) is a bad-free. Guards the param-key seeding that
    /// extends the cross-check to fields extracted from a param (proven end-to-end on either_discard).
    #[test]
    fn flags_wrong_drop_key_on_integer_param() {
        let f = CoreFn {
            name: "t".into(),
            params: vec!["x".into()],
            captures: vec![],
            is_closure: false,
            owned_params: vec!["x".into()],
            owned_drop_ty: vec![("x".into(), Some("Integer".into()))],
            // drop x (flat free) ; ret 0
            body: Term::Drop(
                "x".into(),
                None,
                vec![],
                (0, 0),
                Box::new(Term::Ret(Rhs::Op(Op::Atom(Atom::Int(0))), (0, 0))),
            ),
        };
        let fs = one(f);
        assert!(
            fs.iter().any(|f| f.cat == Cat::WrongDropKey),
            "expected WrongDropKey for a flat-freed Integer param, got {fs:?}"
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

    /// The verifier CATCHES a leak (an owned resource live at the exit, never freed nor
    /// returned) and it is GATE-WORTHY (`leak_gates`) in ordinary code.
    #[test]
    fn flags_gate_worthy_leak() {
        // let x = (1, 2);  ret 0     -- x allocated, never dropped, not returned → leak
        let body = Term::Let(
            "x".into(),
            Rhs::Op(Op::MakeTuple(vec![Atom::Int(1), Atom::Int(2)])),
            (0, 0),
            Box::new(Term::Ret(Rhs::Op(Op::Atom(Atom::Int(0))), (0, 0))),
        );
        let fs = one(fn_body(body));
        let leak = fs.iter().find(|f| f.cat == Cat::Leak);
        assert!(leak.is_some(), "expected a Leak finding, got {fs:?}");
        assert!(
            leak_gates(leak.unwrap()),
            "the leak should gate native compilation"
        );
    }

    /// A leak inside a compiler-synthesized session/parmap state machine (`*$step`) gates like
    /// any other: its tasks reclaim what they own, so nothing there is a tolerated residual.
    #[test]
    fn synthetic_worker_leak_gates() {
        let body = Term::Let(
            "x".into(),
            Rhs::Op(Op::MakeTuple(vec![Atom::Int(1), Atom::Int(2)])),
            (0, 0),
            Box::new(Term::Ret(Rhs::Op(Op::Atom(Atom::Int(0))), (0, 0))),
        );
        let mut f = fn_body(body);
        f.name = "worker$step".into();
        let fs = one(f);
        let leak = fs.iter().find(|f| f.cat == Cat::Leak);
        assert!(leak.is_some(), "the leak is still detected/reported");
        assert!(leak_gates(leak.unwrap()), "a $step worker leak must gate");
    }
}
