#![allow(clippy::pedantic)]
//! Δ — the single linearity judgment over the ANF Core (§ docs/delta-design.md).
//!
//! Phase Δ-1: the checker runs on the annotated Core produced by `insert_drops`
//! and *reports only* — no behavioral change to lowering/codegen. It proves
//! statically, for every fixture: no double-free, no use-after-free, and no
//! silent leak (the resource discipline of the paper, ported to strict ANF).
//!
//! The judgment `Γ; Δ ⊢ t : Δ′`: Δ is the set of live *resources* (heap objects
//! the function owns: `%1` params and `let`-bound heap values), Γ the bound
//! names. A resource is consumed by a moving position (`Drop`, moved call
//! argument, embedding, `UpdateRecord` base, `axion_free`) — after which any
//! use is a type error (use-after-free). A `Drop` of a non-resource, a second
//! `Drop`, or a deep drop after a payload transfer are type errors (double-free).
//!
//! Generated, hand-managed functions:
//!  - `axion_drop_*` (recursive destructors) are verified with the same
//!    judgment: their `%1` parameter is a resource and `axion_free` moves.
//!  - `sess$*` state machines bypass the drop machinery entirely (scheduler
//!    nursery arena) — trusted by construction (§9.4 of the design doc).

use crate::ast::Span;
use crate::core::{Atom, BorrowArgs, CPat, CoreFn, Op, RecordInfo, Rhs, Term, NO_SPAN};
use std::collections::{HashMap, HashSet};

#[derive(Debug)]
pub struct DeltaErr {
    pub func: String,
    pub msg: String,
    /// The source location of the violation, when the Core node carries one
    /// (Δ-5): `Some(span)` for drop-site and position-coherence violations —
    /// rendered `path:line:col` by the CLI; `None` for set-level disagreements
    /// that have no single site.
    pub span: Option<Span>,
}

/// A live resource: its drop key (`Some(k)` = deep-dropable via `axion_drop_k`,
/// `None` = flat free only), and — for a pattern-bound payload — the scrutinee
/// resource it belongs to.
#[derive(Clone, Debug)]
pub struct Res {
    pub key: Option<String>,
    pub parent: Option<String>,
    /// the constructor slot of the parent the payload came from (per-field
    /// ownership, F-1): lets the `(Drop·skip)` rule prove a remainder drop
    /// skips exactly the transferred slots. `None` = the shell itself.
    pub slot: Option<usize>,
}

/// Δ-3, move 1 (docs §6): the **single multiplicity authority**. Every op's
/// effect on its operands and on the env — consumed by the Δ judgment
/// (`Ck::op`), by the drop insertion (`op_produces_heap`, `scan_op_escapes`,
/// the read positions of `fv_op_in`) and by the annotated dump. Replaces the
/// per-position classifications re-derived in `core.rs`.
pub struct DeltaEffect<'a> {
    /// operands that MOVE: their value changes hands to the callee / into the
    /// produced object — the caller may not free it afterwards
    pub moves: Vec<&'a Atom>,
    /// operands that are only BORROWED (read): the caller retains ownership
    /// and must still free the value after the call
    pub borrows: Vec<&'a Atom>,
    /// `Op::Atom`'s operand: the value becomes ALIASED (shared) — it leaves Δ
    /// (the reclamation analysis treats it as escaped: never freed by us)
    pub alias: Option<&'a Atom>,
    /// the `CallClosure` callee: it moves, but it may be a function address
    /// (session/runtime entry) rather than a variable — the judgment reads it
    /// non-strictly
    pub nonstrict: Option<&'a Atom>,
    /// the op's owned-heap result: `Some` iff the binder owns a heap object
    /// (the Phase A′ annotation, or an always-heap op — `op_produces_heap`)
    pub produces: Option<Res>,
}

pub fn op_delta_effect<'a>(op: &'a Op, ba: &BorrowArgs) -> DeltaEffect<'a> {
    let mut e = DeltaEffect {
        moves: Vec::new(),
        borrows: Vec::new(),
        alias: None,
        nonstrict: None,
        produces: None,
    };
    match op {
        Op::Atom(a) => e.alias = Some(a),
        Op::Prim(_, a, b) | Op::PrimF(_, a, b) => {
            e.borrows.push(a);
            e.borrows.push(b);
        }
        Op::IntToFloat(a) | Op::FloatToInt(a) | Op::FloatUnary(_, a) => e.borrows.push(a),
        Op::CallDirect(g, args, ty) => {
            // borrowed positions (pure-borrow callee args) keep the caller's
            // ownership; everything else moves into the callee
            let bs = ba.get(g);
            for (i, a) in args.iter().enumerate() {
                let borrowed = bs.is_some_and(|set| set.contains(&i));
                if borrowed {
                    e.borrows.push(a);
                } else {
                    e.moves.push(a);
                }
            }
            e.produces = ty.clone().map(|k| Res {
                key: Some(k),
                parent: None,
                slot: None,
            });
        }
        Op::CallClosure(f, args) => {
            e.nonstrict = Some(f);
            e.moves.extend(args.iter());
        }
        Op::MakeClosure { captures, .. } => {
            e.moves.extend(captures.iter());
            e.produces = Some(Res {
                key: None,
                parent: None,
                slot: None,
            });
        }
        Op::MakeTuple(args) => {
            e.moves.extend(args.iter());
            e.produces = Some(Res {
                key: None,
                parent: None,
                slot: None,
            });
        }
        Op::MakeCon { args, ty, .. } => {
            e.moves.extend(args.iter());
            e.produces = ty.clone().map(|k| Res {
                key: Some(k),
                parent: None,
                slot: None,
            });
        }
        Op::MakeRecord { fields, ty, .. } => {
            e.moves.extend(fields.iter().map(|(_, a)| a));
            e.produces = ty.clone().map(|k| Res {
                key: Some(k),
                parent: None,
                slot: None,
            });
        }
        Op::UpdateRecord { base, fields, .. } => {
            // ownership transfer: the base dies here (its resources move into
            // the new record); inplace is a codegen choice, same Δ
            e.moves.push(base);
            e.moves.extend(fields.iter().map(|(_, a)| a));
            e.produces = Some(Res {
                key: None,
                parent: None,
                slot: None,
            });
        }
        Op::Field { rec, .. } => e.borrows.push(rec),
        Op::LoadRaw(a, _) => e.borrows.push(a),
        Op::StoreRaw(p, _, v) => {
            e.borrows.push(p);
            e.borrows.push(v);
        }
        Op::FuncAddr(_) => {}
        Op::PutStrLn(a) | Op::PutStr(a) | Op::ShowInt(a) => e.borrows.push(a),
        Op::WithArena { parent, clos } => {
            if let Some(p) = parent {
                e.borrows.push(p);
            }
            e.borrows.push(clos);
        }
        Op::ArenaAlloc(a) | Op::ArenaMark(a) | Op::ArenaRelease(a) => e.borrows.push(a),
        Op::Promote(target, cell) => {
            e.borrows.push(target);
            e.borrows.push(cell);
        }
        Op::RtCall { func, args, .. }
        | Op::Ffi {
            name: func, args, ..
        } => {
            // runtime/FFI calls own their arguments: the reclamation analysis
            // marks them as escaped, so the caller never frees them — a
            // resource passed here dies here (`axion_free` is the runtime free)
            e.moves.extend(args.iter());
            // `axion_array_new` allocates, and `axion_array_set` CONSUMES the old
            // array (arg 0, already moved above) and returns a new owned handle
            // (same pointer, in-place) — both produce an Array the caller reclaims,
            // so a threaded array is dropped exactly once at its final binding.
            if func == "axion_array_new" || func == "axion_array_set" {
                e.produces = Some(Res {
                    key: Some("Array".into()),
                    parent: None,
                    slot: None,
                });
            } else if func == "axion_par_map" {
                // §9 parMap returns an owned `List` of the workers' replies; the
                // consumer reclaims it via the generic `axion_drop_List` (flat
                // cons-cell free). The input list is moved in (above) and freed by
                // the runtime driver, so it is reclaimed exactly once here too.
                e.produces = Some(Res {
                    key: Some("List".into()),
                    parent: None,
                    slot: None,
                });
            }
        }
        Op::ArrayNew { len, init, elem_ty } => {
            e.moves.push(len);
            e.moves.push(init);
            e.produces = Some(Res {
                key: elem_ty
                    .clone()
                    .map(|et| format!("Array${et}"))
                    .or_else(|| Some("Array".into())),
                parent: None,
                slot: None,
            });
        }
        Op::Unsupported(_) => {}
    }
    e
}

#[derive(Clone, Debug, Default)]
struct Scope {
    /// all names in scope (resources and ordinary vars) — use-after-free detection
    bound: HashSet<String>,
    /// live resources: variable → its drop key
    res: HashMap<String, Res>,
    /// the function's `%1` heap parameters → their drop key, still unused
    /// (lazy resources: they enter `res` at their first moving use / `Drop`;
    /// a name is removed here once it has entered — a second `Drop` of it is
    /// then caught as "not a live resource")
    owned: HashMap<String, Option<String>>,
    /// resources whose payload was moved out / separately freed: a later deep
    /// drop of them would double-free the escaped payload. Per-field ownership
    /// (F-1): the value is the set of SLOTS of the parent that were transferred
    /// out — the `(Drop·skip)` rule accepts a remainder drop iff its skip set
    /// equals this set exactly.
    split: HashMap<String, HashSet<usize>>,
}

pub fn check_all(fns: &[CoreFn], borrow_args: &BorrowArgs, recinfo: &RecordInfo) -> Vec<DeltaErr> {
    let mut out = Vec::new();
    for f in fns {
        // hand-managed, generated: session state machines and their `$step`
        // entry points bypass the drop machinery (scheduler nursery arena)
        if f.name.starts_with("sess$") || f.name.ends_with("$step") {
            continue;
        }
        let mut ck = Ck {
            borrow_args,
            recinfo,
            errs: Vec::new(),
            transfers: HashSet::new(),
        };
        ck.check_fn(f);
        out.extend(ck.errs.into_iter().map(|(msg, span)| DeltaErr {
            func: f.name.clone(),
            msg,
            span,
        }));
    }
    out
}

/// The front-end DropPoints of `fname`, split by classification. Shared by
/// `check_drop_coherence` and the `--emit delta` view (Δ-4).
fn drop_sets(drops: &[crate::check::DropPoint], fname: &str) -> (HashSet<String>, HashSet<String>) {
    let never_used = drops
        .iter()
        .filter(|d| d.func == fname && d.reason == "dies at entry (never used)")
        .map(|d| d.var.clone())
        .collect();
    let used = drops
        .iter()
        .filter(|d| d.func == fname && d.reason == "dies after the last read")
        .map(|d| d.var.clone())
        .collect();
    (never_used, used)
}

/// The Δ-3, move 2 classification cross-check for one function: the `%1` heap
/// parameters the front-end classifies (by `DropPoint` reason) must match how
/// the judgment's `owned` set ended — never-used ⇔ stayed in `owned` to the
/// end; used ⇔ drained by the exit. Returns the disagreement messages.
fn coherence_violations(
    universe: &HashSet<String>,
    never_used: &HashSet<String>,
    used: &HashSet<String>,
    fin: &Scope,
) -> Vec<String> {
    let mut out = Vec::new();
    for v in never_used.intersection(universe) {
        if !fin.owned.contains_key(v) {
            out.push(format!(
                "coherence: `{v}` dies at entry per the front-end analysis but the Core uses it (it entered Δ and was reclaimed)"
            ));
        }
    }
    for v in used.intersection(universe) {
        if fin.owned.contains_key(v) {
            out.push(format!(
                "coherence: `{v}` dies after the last read per the front-end analysis but the Core never uses it (it never entered Δ)"
            ));
        }
    }
    out
}

/// The `DropPoint` death spans of `fname`, by variable (Δ-5): the source
/// location where the front-end says the resource dies ("dies after the last
/// read" — the last-read mention; "dies at entry" — the binding).
fn drop_death_spans(drops: &[crate::check::DropPoint], fname: &str) -> HashMap<String, Span> {
    drops
        .iter()
        .filter(|d| d.func == fname && d.reason == "dies after the last read")
        .map(|d| (d.var.clone(), d.span))
        .collect()
}

/// The `Drop` anchors of a judged function (structural walk, deterministic):
/// `(var, anchor)` for every drop, where the anchor is the span of the node
/// the drop precedes (Δ-5 — `NO_SPAN` for generated code).
fn collect_drop_anchors(t: &Term, out: &mut Vec<(String, Span)>) {
    match t {
        Term::Drop(v, _, _, sp, body) => {
            out.push((v.clone(), *sp));
            collect_drop_anchors(body, out);
        }
        Term::Let(_, rhs, _, body) => {
            match rhs {
                Rhs::If(_, th, el) => {
                    collect_drop_anchors(th, out);
                    collect_drop_anchors(el, out);
                }
                Rhs::Case(_, arms) => {
                    for (_, b) in arms {
                        collect_drop_anchors(b, out);
                    }
                }
                Rhs::Op(_) => {}
            }
            collect_drop_anchors(body, out);
        }
        Term::Ret(rhs, _) => match rhs {
            Rhs::If(_, th, el) => {
                collect_drop_anchors(th, out);
                collect_drop_anchors(el, out);
            }
            Rhs::Case(_, arms) => {
                for (_, b) in arms {
                    collect_drop_anchors(b, out);
                }
            }
            Rhs::Op(_) => {}
        },
    }
}

/// The Δ-5 **absolute position rule** (calibrated against the fixture set):
/// the drop's anchored node must not END before the front-end death point
/// BEGINS — `anchor.1 > death.0`. A drop anchored at a statement that sits
/// entirely before the last read (a hoist to the head, an earlier statement)
/// freed a value the pipeline still reads; a drop anchored at the death's own
/// statement (the tail-op pattern — the death is an operand of the anchored
/// node) or at a later statement is fine. `NO_SPAN` anchors are skipped by the
/// caller.
fn span_matches(anchor: Span, death: Span) -> bool {
    anchor.1 > death.0
}

/// Δ-5 (docs §6): the position dimension of the coherence cross-check — for a
/// `%1` heap parameter the front-end says "dies after the last read" at a
/// known source span, a Core `Drop` that drains it must be anchored at or
/// after that death point. A drop anchored *before* the last read would free
/// a value the pipeline still reads — a use-after-free the classification
/// check cannot see (the drain still happens at the exit). `NO_SPAN` anchors
/// (generated code) are unverifiable and skipped.
fn position_violations(
    universe: &HashSet<String>,
    used: &HashSet<String>,
    death: &HashMap<String, Span>,
    anchors: &[(String, Span)],
) -> Vec<(String, Span)> {
    let mut out = Vec::new();
    for v in used.intersection(universe) {
        let Some(dsp) = death.get(v) else { continue };
        let own: Vec<Span> = anchors
            .iter()
            .filter(|(n, _)| n == v)
            .map(|(_, a)| *a)
            .collect();
        if own.is_empty() {
            // drained by a move, not a Drop — no position to check
            continue;
        }
        if own.iter().all(|a| *a == NO_SPAN) {
            // unverifiable anchors (generated/lowering gaps) — classification only
            continue;
        }
        if let Some(bad) = own.iter().find(|a| !span_matches(**a, *dsp)) {
            out.push((
                format!(
                    "coherence: the drop of `{v}` is anchored before the front-end death point (the drop precedes the last read — use-after-free)"
                ),
                *bad,
            ));
        }
    }
    out
}

/// Δ-3, move 2 (docs §6): cross-check the judgment's view of `%1` heap
/// parameters against the front-end death analysis (`check.rs` `DropPoint`s —
/// the Auto-Drop plan, print-only in codegen). Core terms carry no spans, so
/// the two analyses cannot share death *positions*; they must agree on the
/// *classification* instead, per `%1` heap parameter of every function:
///  - a DropPoint "dies at entry (never used)" ⇒ the parameter must never
///    enter Δ — it stays in `owned` to the end (the Core never touches it);
///  - a DropPoint "dies after the last read" ⇒ the parameter must enter Δ —
///    `owned` must be drained by the exit (a borrow, a `Drop`, or a move).
///
/// A violation is drift between the two liveness engines (the reclamation
/// pipeline frees something the front-end thinks is alive, or vice-versa).
pub fn check_drop_coherence(
    fns: &[CoreFn],
    borrow_args: &BorrowArgs,
    recinfo: &RecordInfo,
    drops: &[crate::check::DropPoint],
) -> Vec<DeltaErr> {
    let mut out = Vec::new();
    for f in fns {
        if f.name.starts_with("sess$") || f.name.ends_with("$step") {
            continue;
        }
        let (never_used, used) = drop_sets(drops, &f.name);
        if never_used.is_empty() && used.is_empty() {
            continue;
        }
        // the judgment's universe: the `%1` heap parameters tracked by the
        // reclamation analysis (let-bound DropPoints are outside Δ's `owned`)
        let universe: HashSet<String> = f.owned_drop_ty.iter().map(|(n, _)| n.clone()).collect();
        let mut ck = Ck {
            borrow_args,
            recinfo,
            errs: Vec::new(),
            transfers: HashSet::new(),
        };
        let fin = ck.check_fn(f);
        out.extend(
            coherence_violations(&universe, &never_used, &used, &fin)
                .into_iter()
                .map(|msg| DeltaErr {
                    func: f.name.clone(),
                    msg,
                    span: None,
                }),
        );
        // Δ-5: the position dimension — the Core drops of a "used" param must
        // be anchored at/after the front-end's death span (same facts and
        // helpers as the `--emit delta` view).
        let mut anchors: Vec<(String, Span)> = Vec::new();
        collect_drop_anchors(&f.body, &mut anchors);
        out.extend(
            position_violations(
                &universe,
                &used,
                &drop_death_spans(drops, &f.name),
                &anchors,
            )
            .into_iter()
            .map(|(msg, sp)| DeltaErr {
                func: f.name.clone(),
                msg,
                span: Some(sp),
            }),
        );
    }
    out
}

/// Δ-2: `core::dump` with the judgment made visible — every `let`/`ret` is/// annotated with the live-resource env entering it (`; Δ{…}`), the resources
/// moved out by the op (`moves{…}`), and what it produces (`makes …`).
/// Deterministic: all sets sorted; the judgment state transitions exactly as
/// in `check_all` (errors are ignored — the verdict channel is unchanged).
pub fn dump_annotated(fns: &[CoreFn], borrow_args: &BorrowArgs, recinfo: &RecordInfo) -> String {
    let mut out = String::new();
    for f in fns {
        if f.name.starts_with("sess$") || f.name.ends_with("$step") {
            continue;
        }
        let hdr = if f.is_closure {
            format!("[env {}]", f.captures.join(" "))
        } else {
            String::new()
        };
        out.push_str(&format!(
            "{} {}{} =\n",
            f.name,
            hdr,
            f.params.iter().map(|p| format!("{p} ")).collect::<String>()
        ));
        let mut ck = Ck {
            borrow_args,
            recinfo,
            errs: Vec::new(),
            transfers: HashSet::new(),
        };
        let mut s = Scope::default();
        for p in &f.params {
            s.bound.insert(p.clone());
        }
        for c in &f.captures {
            s.bound.insert(c.clone());
        }
        s.owned = f.owned_drop_ty.iter().cloned().collect();
        ck.dump_term(&f.body, &s, 1, &mut out);
        out.push('\n');
    }
    out
}

/// The drop sites of a judged function, in a deterministic order (structural
/// walk, arms in source order, then sorted for the summary line).
fn collect_drops(t: &Term, out: &mut Vec<String>) {
    match t {
        Term::Drop(v, _, _, _, body) => {
            out.push(v.clone());
            collect_drops(body, out);
        }
        Term::Let(_, rhs, _, body) => {
            match rhs {
                Rhs::If(_, th, el) => {
                    collect_drops(th, out);
                    collect_drops(el, out);
                }
                Rhs::Case(_, arms) => {
                    for (_, b) in arms {
                        collect_drops(b, out);
                    }
                }
                Rhs::Op(_) => {}
            }
            collect_drops(body, out);
        }
        Term::Ret(rhs, _) => match rhs {
            Rhs::If(_, th, el) => {
                collect_drops(th, out);
                collect_drops(el, out);
            }
            Rhs::Case(_, arms) => {
                for (_, b) in arms {
                    collect_drops(b, out);
                }
            }
            Rhs::Op(_) => {}
        },
    }
}

/// Δ-4: the `--emit delta` debug view — the judgment's per-function verdicts
/// plus the resource-life facts the annotated dump cannot show: the drop
/// sites in the judged Core and the `%1` heap parameters that never entered
/// Δ (never used — they must stay in `owned`, the Δ-3, move 2
/// classification). The coherence cross-check (Δ-3, move 2 + Δ-5 position
/// rule) is summarized per run. Deterministic (structural walk, sorted sets).
/// Report-only: the exit code is unaffected — `--check-delta` is the verdict
/// channel. `lines`/`src` render the violations' anchors (`path:line:col` +
/// the source line, Δ-5).
pub fn dump_delta(
    fns: &[CoreFn],
    borrow_args: &BorrowArgs,
    recinfo: &RecordInfo,
    drops: &[crate::check::DropPoint],
    lines: &crate::lexer::LineMap,
    src: &str,
) -> String {
    let mut out = String::new();
    out.push_str(
        "== Δ: the linearity judgment over the annotated Core (docs/delta-design.md §5)\n",
    );
    out.push_str("   per-function verdicts · drops in the judged Core · never-used %1 params.\n");
    out.push_str("   Report-only: `--check-delta` is the verdict channel (exit code).\n");
    let mut n_ok = 0usize;
    let mut n_viol = 0usize;
    let mut n_skipped = 0usize;
    let mut coh_total = 0usize;
    let mut coh_ok = 0usize;
    for f in fns {
        if f.name.starts_with("sess$") || f.name.ends_with("$step") {
            n_skipped += 1;
            continue;
        }
        let mut ck = Ck {
            borrow_args,
            recinfo,
            errs: Vec::new(),
            transfers: HashSet::new(),
        };
        let fin = ck.check_fn(f);
        // the coherence cross-check totals (Δ-3, move 2 + Δ-5 position rule —
        // same facts and helpers as the `--check-delta` gate): a disagreement
        // counts as a violation of this function, exactly like `--check-delta`
        // reports it
        let (never_dp, used_dp) = drop_sets(drops, &f.name);
        let universe: HashSet<String> = f.owned_drop_ty.iter().map(|(n, _)| n.clone()).collect();
        let mut coh_msgs: Vec<(String, Option<Span>)> =
            coherence_violations(&universe, &never_dp, &used_dp, &fin)
                .into_iter()
                .map(|m| (m, None))
                .collect();
        let mut anchors: Vec<(String, Span)> = Vec::new();
        collect_drop_anchors(&f.body, &mut anchors);
        coh_msgs.extend(
            position_violations(
                &universe,
                &used_dp,
                &drop_death_spans(drops, &f.name),
                &anchors,
            )
            .into_iter()
            .map(|(m, sp)| (m, Some(sp))),
        );
        let total =
            never_dp.intersection(&universe).count() + used_dp.intersection(&universe).count();
        coh_total += total;
        coh_ok += total - coh_msgs.len();
        // the `%1` heap params that never entered Δ: `owned` still holds them
        let mut never_used: Vec<String> = fin.owned.keys().cloned().collect();
        never_used.sort();
        let mut fs_drops: Vec<String> = Vec::new();
        collect_drops(&f.body, &mut fs_drops);
        fs_drops.sort();
        let n_violations = ck.errs.len() + coh_msgs.len();
        let mut line = format!("{} {}", f.name, f.params.join(" "));
        if n_violations == 0 {
            line.push_str(" = ok");
            n_ok += 1;
        } else {
            line.push_str(&format!(" = {n_violations} violation(s)"));
            n_viol += 1;
        }
        let mut facts: Vec<String> = Vec::new();
        if !fs_drops.is_empty() {
            facts.push(format!("drops: {}", fs_drops.join(" ")));
        }
        if !never_used.is_empty() {
            facts.push(format!("never-used %1: {}", never_used.join(" ")));
        }
        if !ck.transfers.is_empty() {
            let mut t: Vec<String> = ck.transfers.iter().cloned().collect();
            t.sort();
            facts.push(format!("transferred %1-heap: {}", t.join(" ")));
        }
        if !facts.is_empty() {
            line.push_str(" — ");
            line.push_str(&facts.join(" · "));
        }
        for (msg, sp) in ck.errs.iter().chain(coh_msgs.iter()) {
            line.push_str(&format!("\n      {msg}{}", render_span(sp, lines, src)));
        }
        out.push_str(&line);
        out.push('\n');
    }
    out.push_str(&format!(
        "\n== verdicts: {n_ok} ok · {n_viol} with violations · {n_skipped} skipped (hand-managed generated)\n"
    ));
    if coh_total > 0 {
        out.push_str(&format!(
            "== coherence (Δ-3, move 2): {coh_ok}/{coh_total} `%1` params agree with the front-end DropPoints\n"
        ));
    }
    out
}

/// Δ-5: renders a violation's anchor as `(at {line}:{col}: {source line})`;
/// `None`/`NO_SPAN` (no single site, or generated code) render nothing.
fn render_span(sp: &Option<Span>, lines: &crate::lexer::LineMap, src: &str) -> String {
    match sp {
        Some(s) if *s != NO_SPAN => {
            let (l, c) = lines.pos(s.0);
            let line = src.lines().nth(l.saturating_sub(1)).unwrap_or("");
            format!("  (at {l}:{c}: {line})")
        }
        _ => String::new(),
    }
}

struct Ck<'a> {
    borrow_args: &'a BorrowArgs,
    recinfo: &'a RecordInfo,
    errs: Vec<(String, Option<Span>)>,
    /// the `%1`-heap fields the current function extracted (per-field
    /// ownership, F-1) — surfaced as a `--emit delta` fact. Cleared per
    /// function by `check_fn`.
    transfers: HashSet<String>,
}

/// A case-binding's payload classification (per-field ownership, F-1):
/// `Some` = the binding owns a heap object of the scrutinee; `key` is its drop
/// key (`Some` for a `%1` field of a concrete `data` type — deep-dropable on
/// its own; `None` for the ordinary conservative payloads), `slot` is the
/// constructor slot it came from.
struct Payload {
    key: Option<String>,
    slot: usize,
}

impl Ck<'_> {
    /// A pattern's bindings: `(name, payload)`. A binding is a *payload* of
    /// the scrutinee (owned heap object, freed by its deep-drop destructor)
    /// when the constructor field transfers heap ownership; a `%1` field of a
    /// `data` type additionally carries the slot's drop key (it owns its own
    /// linear resource — `(Drop·skip)` can reclaim the remainder without it).
    fn pat_binds(&self, pat: &CPat, out: &mut Vec<(String, Option<Payload>)>) {
        match pat {
            CPat::Var(n) => out.push((n.clone(), None)),
            CPat::Int(_) | CPat::Wild => {}
            CPat::Tuple(ps) => ps.iter().for_each(|p| self.pat_binds(p, out)),
            CPat::Con(con, ps) => {
                for (i, p) in ps.iter().enumerate() {
                    if let CPat::Var(n) = p {
                        let payload = if self.recinfo.field_transfers_heap(con, i) {
                            let key = if self.recinfo.field_is_owned(con, i) {
                                self.recinfo.field_drop_slot(con, i).map(|t| t.to_string())
                            } else {
                                None
                            };
                            Some(Payload { key, slot: i })
                        } else {
                            None
                        };
                        out.push((n.clone(), payload));
                    } else {
                        self.pat_binds(p, out);
                    }
                }
            }
        }
    }

    fn check_fn(&mut self, f: &CoreFn) -> Scope {
        self.transfers.clear();
        let mut s = Scope::default();
        for p in &f.params {
            s.bound.insert(p.clone());
        }
        for c in &f.captures {
            s.bound.insert(c.clone());
        }
        // `%1` heap parameters are potential resources. They enter `res`
        // lazily — at their first moving use (moving use or `Drop`) — so a
        // parameter the body never touches is never a resource: the reclamation
        // analysis doesn't free it either (matches `droppable_vars` minus the
        // escaped and the never-read ones). The front-end's "dies at entry"
        // DropPoint is cross-checked by `check_drop_coherence` (Δ-3, move 2).
        s.owned = f.owned_drop_ty.iter().cloned().collect();
        let (fin, carried) = self.term(&f.body, &s);
        // the function's exit: every resource still live must be carried by the
        // returned value — anything else is a silent leak. Payloads (heap fields
        // of a scrutinee, parented) are not owned here: they are freed by the
        // scrutinee's drop or leak with it (the deferred extracted-field gap).
        for v in fin
            .res
            .iter()
            .filter(|(_, r)| r.parent.is_none())
            .map(|(n, _)| n.clone())
            .collect::<Vec<_>>()
        {
            if !carried.contains(&v) {
                self.err(&format!(
                    "resource `{v}` is live at the return of `{}` — neither consumed nor returned",
                    f.name
                ));
            }
        }
        fin
    }

    fn err(&mut self, msg: &str) {
        self.errs.push((msg.to_string(), None));
    }

    /// An error at a specific Core node's source location (Δ-5): the CLI
    /// renders `path:line:col`.
    fn err_at(&mut self, msg: &str, sp: Option<Span>) {
        self.errs.push((msg.to_string(), sp));
    }

    /// Use of an atom: `mv` = moving position (the resource changes owner /
    /// dies) vs borrowing position (it stays live). The caller updates `s`.
    /// `strict` = the atom must be bound (false for function addresses passed
    /// to `CallClosure`, which are not variables).
    fn use_atom(&mut self, a: &Atom, mv: bool, s: &mut Scope) {
        self.use_atom_in(a, mv, true, s);
    }

    fn use_atom_in(&mut self, a: &Atom, mv: bool, strict: bool, s: &mut Scope) {
        let Atom::Var(n) = a else { return };
        if !s.bound.contains(n) {
            if strict {
                self.err(&format!("use of unbound/consumed variable `{n}`"));
            }
            return;
        }
        if !mv {
            return;
        }
        if let Some(r) = s.res.remove(n) {
            if let Some(p) = r.parent {
                // a payload left the scope (moved out or dropped separately):
                // the scrutinee it belongs to must not be deep-dropped later —
                // the slot that left is recorded (per-field ownership, F-1):
                // a `(Drop·skip)` remainder drop may free the rest of the shell
                // without it. `usize::MAX` = unknown slot (conservative: no
                // skip set can prove the exclusion).
                s.split
                    .entry(p)
                    .or_default()
                    .insert(r.slot.unwrap_or(usize::MAX));
            }
        } else if s.owned.remove(n).is_some() {
            // first moving use of a `%1` parameter: it enters Δ and dies here
            // (removed from `owned` so a later `Drop` of it is a double free)
            s.res.remove(n);
        }
        // a use of an already-consumed name is a double-use — the front-end's
        // linearity judgment (AX0001/AX0004) rejects it before lowering; the
        // Δ judgment verifies the Core as the pipeline emits it.
    }

    /// A `Drop` node: `v` must be a live resource; a deep drop additionally
    /// requires no payload of `v` to have escaped, and kills the payloads that
    /// remain (the destructor frees them). `skip` is the **remainder skip set**
    /// (F-1, always empty in lowering today): a remainder drop
    /// `drop v : T skip {…}` frees the shell and every drop slot EXCEPT the
    /// listed ones — which must be EXACTLY the slots that were transferred out
    /// of `v` (`(Drop·skip)`: a skipped slot that did not leave would be freed
    /// by the destructor while its binder still aliases it — UAF; a transferred
    /// slot not skipped would be freed twice — double free). The skipped slots'
    /// bindings survive the drop as independent resources (their parent died).
    /// `sp` = the drop's anchor (the span of the node it precedes — Δ-5) for
    /// the span-ful diagnostics.
    fn do_drop(
        &mut self,
        v: &str,
        ty: &Option<String>,
        skip: &[usize],
        sp: Option<Span>,
        s: &mut Scope,
    ) {
        // a `%1` parameter dropped before any other use enters `res` here
        if !s.res.contains_key(v) {
            if let Some(k) = s.owned.remove(v) {
                s.res.insert(
                    v.to_string(),
                    Res {
                        key: k,
                        parent: None,
                        slot: None,
                    },
                );
            }
        }
        let (is_flat_payload, parent, r_key, r_slot) = {
            let Some(r) = s.res.get(v) else {
                self.err_at(
                    &format!(
                        "drop of `{v}` which is not a live resource (double free or free of a non-owned value)"
                    ),
                    sp,
                );
                return;
            };
            (
                ty.is_none() && r.parent.is_some(),
                r.parent.clone(),
                r.key.clone(),
                r.slot,
            )
        };
        if let (Some(k), Some(k2)) = (ty, &r_key) {
            if k != k2 {
                self.err_at(
                    &format!(
                        "drop of `{v}` with destructor `axion_drop_{k}` but the value is a `{k2}`"
                    ),
                    sp,
                );
            }
        }
        let transferred = s.split.get(v).cloned().unwrap_or_default();
        if ty.is_some() {
            let skip_set: HashSet<usize> = skip.iter().copied().collect();
            if skip_set.is_empty() {
                // a full deep drop: nothing may have been transferred out
                if !transferred.is_empty() {
                    self.err_at(
                        &format!(
                            "deep drop of `{v}` after one of its payloads was moved out / freed separately (double free)"
                        ),
                        sp,
                    );
                }
            } else if transferred != skip_set {
                let mut skipped: Vec<String> = skip_set.iter().map(|i| i.to_string()).collect();
                skipped.sort();
                let mut moved: Vec<String> = transferred.iter().map(|i| i.to_string()).collect();
                moved.sort();
                self.err_at(
                    &format!(
                        "remainder drop of `{v}` skips {{{}}} but the transferred slots are {{{}}} (the skip set must equal the moved-out slots)",
                        skipped.join(" "),
                        moved.join(" "),
                    ),
                    sp,
                );
                return;
            }
        }
        s.res.remove(v);
        if ty.is_some() {
            let skip_set: HashSet<usize> = skip.iter().copied().collect();
            // the destructor frees the shell and every non-skipped slot: the
            // payload bindings of those slots die with it; the skipped slots'
            // bindings survive — they own the moved-out values, now detached
            // from the (dead) parent.
            let mut kept: HashMap<String, Res> = HashMap::with_capacity(s.res.len());
            for (n, q) in s.res.drain() {
                if q.parent.as_ref().is_some_and(|p| p == v) {
                    if q.slot.is_some_and(|i| skip_set.contains(&i)) {
                        kept.insert(
                            n,
                            Res {
                                key: q.key,
                                parent: None,
                                slot: q.slot,
                            },
                        );
                    }
                } else {
                    kept.insert(n, q);
                }
            }
            s.res = kept;
            s.split.remove(v);
        } else if is_flat_payload {
            // flat drop of a payload: it is freed separately from the shell —
            // a deep drop of the shell afterwards would free it twice.
            if let Some(p) = parent {
                s.split
                    .entry(p)
                    .or_default()
                    .insert(r_slot.unwrap_or(usize::MAX));
            }
        }
    }

    /// The live resources the return value carries: a bare variable (a live
    /// resource returned as-is). Everything else returns fresh/ordinary values.
    fn ret_carries(rhs: &Rhs, s: &Scope) -> Vec<String> {
        match rhs {
            Rhs::Op(Op::Atom(Atom::Var(n))) if s.res.contains_key(n) => vec![n.clone()],
            _ => Vec::new(),
        }
    }

    /// A `Term`. Returns the scope after it (the resources the enclosing context
    /// still owns) and the resources carried by the function's exit `Ret` (the
    /// empty list for the branch-internal `Ret`s — those are not the exit).
    fn term(&mut self, t: &Term, s: &Scope) -> (Scope, Vec<String>) {
        match t {
            Term::Let(x, rhs, _, body) => {
                let mut s1 = s.clone();
                match rhs {
                    Rhs::Op(op) => {
                        let produced = self.op(op, &mut s1);
                        if let Some(res) = produced {
                            s1.res.insert(x.clone(), res);
                        }
                    }
                    Rhs::If(c, th, el) => {
                        self.use_atom(c, false, &mut s1);
                        let (sth, _) = self.term(th, &s1);
                        let (sel, _) = self.term(el, &s1);
                        if !Self::same_res(&sth, &sel) {
                            self.err("branches of `if` leave different live resources");
                        }
                        s1 = sth;
                    }
                    Rhs::Case(sc, arms) => {
                        self.case(sc, arms, &mut s1);
                    }
                }
                s1.bound.insert(x.clone());
                self.term(body, &s1)
            }
            Term::Drop(v, ty, skip, sp, body) => {
                let mut s1 = s.clone();
                self.do_drop(v, ty, skip, Some(*sp), &mut s1);
                self.term(body, &s1)
            }
            Term::Ret(rhs, _) => {
                let mut s1 = s.clone();
                match rhs {
                    Rhs::Op(op) => {
                        // the value leaves the function: not a bound resource —
                        // the caller owns it (the produced annotation of its
                        // `CallDirect`, or nothing for scalars)
                        self.op(op, &mut s1);
                    }
                    Rhs::If(c, th, el) => {
                        self.use_atom(c, false, &mut s1);
                        let (sth, _) = self.term(th, &s1);
                        let (sel, _) = self.term(el, &s1);
                        if !Self::same_res(&sth, &sel) {
                            self.err("branches of `if` leave different live resources");
                        }
                        s1 = sth;
                    }
                    Rhs::Case(sc, arms) => {
                        self.case(sc, arms, &mut s1);
                    }
                }
                let carried = Self::ret_carries(rhs, &s1);
                (s1, carried)
            }
        }
    }

    /// Branch/arm balancing: the same *outer* resources must stay live in every
    /// branch (names are the enclosing scope's). Payloads are deliberately not
    /// balanced: they are the scrutinee's sub-objects, freed by its drop (or
    /// leaked with it) — the reclamation analysis never drops a payload on its
    /// own, so a payload alive at the exit of one arm only is not an error.
    fn same_res(a: &Scope, b: &Scope) -> bool {
        let outer_a: HashSet<&String> = a
            .res
            .iter()
            .filter(|(_, r)| r.parent.is_none())
            .map(|(n, _)| n)
            .collect();
        let outer_b: HashSet<&String> = b
            .res
            .iter()
            .filter(|(_, r)| r.parent.is_none())
            .map(|(n, _)| n)
            .collect();
        outer_a == outer_b
    }

    /// A `case` scrutinee is an atom (ANF): the pattern bindings are
    /// Δ-variables — the scrutinee's payloads — and the scrutinee itself is the
    /// implicit case binder (usable/borrowable in every arm, consumed by the
    /// arm's trailing `Drop`, if any). All arms must end with the same live
    /// resources (branch balancing).
    fn case(&mut self, sc: &Atom, arms: &[(CPat, Term)], s: &mut Scope) {
        let sv = match sc {
            Atom::Var(n) => Some(n.clone()),
            _ => None,
        };
        // an owned `%1` scrutinee enters Δ here (it is the implicit case
        // binder, borrowed in every arm): payload tracking and the arm's
        // trailing `Drop` both depend on it being a live resource
        if let Some(n) = &sv {
            if !s.res.contains_key(n) {
                if let Some(k) = s.owned.remove(n) {
                    s.res.insert(
                        n.clone(),
                        Res {
                            key: k,
                            parent: None,
                            slot: None,
                        },
                    );
                }
            }
        }
        let scrut_res = sv.as_ref().and_then(|n| s.res.get(n).cloned());
        let finals: Vec<Scope> = arms
            .iter()
            .map(|(pat, body)| {
                let mut sa = s.clone();
                let mut binds = Vec::new();
                self.pat_binds(pat, &mut binds);
                for (n, payload) in binds {
                    sa.bound.insert(n.clone());
                    if let Some(pl) = payload {
                        if scrut_res.is_some() {
                            let owned = pl.key.is_some();
                            sa.res.insert(
                                n.clone(),
                                Res {
                                    key: pl.key,
                                    parent: sv.clone(),
                                    slot: Some(pl.slot),
                                },
                            );
                            if owned {
                                self.transfers.insert(n.clone());
                                if let Some(ref sv) = sv {
                                    sa.split.entry(sv.clone()).or_default().insert(pl.slot);
                                }
                            }
                        }
                    }
                }
                self.term(body, &sa).0
            })
            .collect();
        for f in finals.iter().skip(1) {
            if !Self::same_res(&finals[0], f) {
                self.err("arms of `case` leave different live resources");
                break;
            }
        }
        if let Some(f) = finals.first() {
            *s = f.clone();
        }
    }

    /// The axiom table (Δ §5): each `Op` consumes (moves) some atoms and
    /// produces a resource (the heap value the binder owns), or not.
    /// Returns `Some(res)` when the op's value is a heap object the binder owns.
    fn op(&mut self, op: &Op, s: &mut Scope) -> Option<Res> {
        if matches!(op, Op::Unsupported(_)) {
            self.err("Unsupported op in the Core — cannot validate");
            return None;
        }
        let e = op_delta_effect(op, self.borrow_args);
        if let Some(Atom::Var(n)) = e.alias {
            // alias: the resource becomes ordinary (freely duplicable) —
            // the reclamation analysis never drops an aliased value
            if s.res.remove(n).is_some() {
                s.bound.insert(n.clone());
                s.owned.remove(n);
            }
        }
        for a in &e.moves {
            self.use_atom(a, true, s);
        }
        for a in &e.borrows {
            self.use_atom(a, false, s);
        }
        if let Some(f) = e.nonstrict {
            // the `CallClosure` callee may be a function address (a
            // session/runtime entry — not a variable): read non-strictly
            self.use_atom_in(f, true, false, s);
        }
        // (Field·owned) — per-field ownership, F-1: a selector read of a `%1`
        // HEAP field of a live record transfers that slot's ownership. The
        // binder owns the moved-out value (a payload of the record, with the
        // slot's drop key — deep-dropable on its own), and the record is split
        // at that slot: a later full deep drop would double-free it, so the
        // pipeline must free the remainder via `(Drop·skip)` (F-2) instead.
        // Borrowed (non-resource) records and non-`%1`/scalar fields are
        // unchanged — the ordinary borrow read.
        if let Op::Field {
            name,
            rec: Atom::Var(rn),
        } = op
        {
            // the record must be a live resource (%1 owned or entered)
            // for the (Field·owned) rule to fire — promotion is only
            // needed when it fires, not for every field read
            if let Some((con, idx)) = self.recinfo.named_field_slot(name) {
                if self.recinfo.field_is_owned(&con, idx)
                    && self.recinfo.field_transfers_heap(&con, idx)
                {
                    let promoted = if s.res.contains_key(rn) {
                        true
                    } else {
                        s.owned.remove(rn).is_some_and(|k| {
                            s.res.insert(
                                rn.clone(),
                                Res {
                                    key: k,
                                    parent: None,
                                    slot: None,
                                },
                            );
                            true
                        })
                    };
                    if promoted {
                        s.split.entry(rn.clone()).or_default().insert(idx);
                        self.transfers.insert(name.clone());
                        let key = self
                            .recinfo
                            .field_drop_slot(&con, idx)
                            .map(|t| t.to_string());
                        return Some(Res {
                            key,
                            parent: Some(rn.clone()),
                            slot: Some(idx),
                        });
                    }
                }
            }
        }
        e.produces
    }

    /// Sorted rendering of a set (deterministic dump output).
    fn sorted<'x>(v: impl Iterator<Item = &'x String>) -> String {
        let mut v: Vec<&String> = v.collect();
        v.sort();
        v.iter().map(|s| s.as_str()).collect::<Vec<_>>().join(" ")
    }

    /// The annotation on a `let`/`ret` line: the live-resource env (Δ) entering
    /// the node, the names moved out by the op, and what it produces.
    fn annot(
        &self,
        delta: &HashSet<String>,
        moved: &HashSet<String>,
        produced: &Option<Res>,
        out: &mut String,
    ) {
        out.push_str(&format!("  ; Δ{{{}}}", Self::sorted(delta.iter())));
        if !moved.is_empty() {
            out.push_str(&format!(" · moves{{{}}}", Self::sorted(moved.iter())));
        }
        if let Some(r) = produced {
            let key = r.key.as_deref().unwrap_or("heap");
            if let Some(p) = &r.parent {
                out.push_str(&format!(
                    " · makes {key} ^{p}[{}]",
                    r.slot.map_or("-".to_string(), |i| i.to_string())
                ));
            } else {
                match &r.key {
                    Some(k) => out.push_str(&format!(" · makes {k}")),
                    None => out.push_str(" · makes heap"),
                }
            }
        }
    }

    /// Δ-2: the annotated Core dump — `core::dump` with the judgment made
    /// visible. Every `let`/`ret` carries the live-resource env (Δ) entering
    /// it, the resources moved out, and the produced value. The judgment state
    /// transitions exactly as in `term`/`case`/`op` (report-only; no errors are
    /// collected — `--check-delta` remains the verdict channel).
    #[allow(clippy::many_single_char_names)]
    fn dump_term(
        &mut self,
        t: &Term,
        s: &Scope,
        n: usize,
        out: &mut String,
    ) -> (Scope, Vec<String>) {
        let mut s1 = s.clone();
        match t {
            Term::Let(x, rhs, _, body) => match rhs {
                Rhs::Op(op) => {
                    let before: HashSet<String> = s1.res.keys().cloned().collect();
                    let produced = self.op(op, &mut s1);
                    let after: HashSet<String> = s1.res.keys().cloned().collect();
                    let moved: HashSet<String> = before.difference(&after).cloned().collect();
                    crate::core::indent(n, out);
                    out.push_str(&format!("let {x} = {}", crate::core::dump_op(op)));
                    self.annot(&before, &moved, &produced, out);
                    out.push('\n');
                    if let Some(res) = produced {
                        s1.res.insert(x.clone(), res);
                    }
                    s1.bound.insert(x.clone());
                    self.dump_term(body, &s1, n, out)
                }
                Rhs::If(c, th, el) => {
                    self.use_atom(c, false, &mut s1);
                    let before: HashSet<String> = s1.res.keys().cloned().collect();
                    crate::core::indent(n, out);
                    out.push_str(&format!("let {x} = if {} then\n", crate::core::atom(c)));
                    self.annot(&before, &HashSet::new(), &None, out);
                    out.push('\n');
                    let (sth, _) = self.dump_term(th, &s1, n + 1, out);
                    crate::core::indent(n, out);
                    out.push_str("else\n");
                    let (sel, _) = self.dump_term(el, &s1, n + 1, out);
                    if !Self::same_res(&sth, &sel) {
                        self.err("branches of `if` leave different live resources");
                    }
                    s1 = sth;
                    s1.bound.insert(x.clone());
                    self.dump_term(body, &s1, n, out)
                }
                Rhs::Case(sc, arms) => {
                    let before: HashSet<String> = s1.res.keys().cloned().collect();
                    crate::core::indent(n, out);
                    out.push_str(&format!("let {x} = case {} of\n", crate::core::atom(sc)));
                    self.annot(&before, &HashSet::new(), &None, out);
                    out.push('\n');
                    self.dump_case(sc, arms, &mut s1, n + 1, out);
                    s1.bound.insert(x.clone());
                    self.dump_term(body, &s1, n, out)
                }
            },
            Term::Drop(v, ty, skip, sp, body) => {
                self.do_drop(v, ty, skip, Some(*sp), &mut s1);
                crate::core::indent(n, out);
                match ty {
                    Some(t) if !skip.is_empty() => {
                        let mut s: Vec<String> = skip.iter().map(|i| i.to_string()).collect();
                        s.sort();
                        out.push_str(&format!("drop {v} : {t} skip{{{}}}\n", s.join(" ")))
                    }
                    Some(t) => out.push_str(&format!("drop {v} : {t}\n")),
                    None => out.push_str(&format!("drop {v}\n")),
                }
                self.dump_term(body, &s1, n, out)
            }
            Term::Ret(rhs, _) => match rhs {
                Rhs::Op(op) => {
                    let before: HashSet<String> = s1.res.keys().cloned().collect();
                    let produced = self.op(op, &mut s1);
                    let after: HashSet<String> = s1.res.keys().cloned().collect();
                    let moved: HashSet<String> = before.difference(&after).cloned().collect();
                    crate::core::indent(n, out);
                    out.push_str(&format!("ret {}", crate::core::dump_op(op)));
                    self.annot(&before, &moved, &produced, out);
                    out.push('\n');
                    let carried = Self::ret_carries(rhs, &s1);
                    (s1, carried)
                }
                Rhs::If(c, th, el) => {
                    self.use_atom(c, false, &mut s1);
                    let before: HashSet<String> = s1.res.keys().cloned().collect();
                    crate::core::indent(n, out);
                    out.push_str(&format!("ret if {} then\n", crate::core::atom(c)));
                    self.annot(&before, &HashSet::new(), &None, out);
                    out.push('\n');
                    let (sth, _) = self.dump_term(th, &s1, n + 1, out);
                    crate::core::indent(n, out);
                    out.push_str("else\n");
                    let (sel, _) = self.dump_term(el, &s1, n + 1, out);
                    if !Self::same_res(&sth, &sel) {
                        self.err("branches of `if` leave different live resources");
                    }
                    s1 = sth;
                    let carried = Self::ret_carries(rhs, &s1);
                    (s1, carried)
                }
                Rhs::Case(sc, arms) => {
                    let before: HashSet<String> = s1.res.keys().cloned().collect();
                    crate::core::indent(n, out);
                    out.push_str(&format!("ret case {} of\n", crate::core::atom(sc)));
                    self.annot(&before, &HashSet::new(), &None, out);
                    out.push('\n');
                    self.dump_case(sc, arms, &mut s1, n + 1, out);
                    let carried = Self::ret_carries(rhs, &s1);
                    (s1, carried)
                }
            },
        }
    }

    fn dump_case(
        &mut self,
        sc: &Atom,
        arms: &[(CPat, Term)],
        s: &mut Scope,
        n: usize,
        out: &mut String,
    ) {
        let sv = match sc {
            Atom::Var(n) => Some(n.clone()),
            _ => None,
        };
        if let Some(n) = &sv {
            if !s.res.contains_key(n) {
                if let Some(k) = s.owned.remove(n) {
                    s.res.insert(
                        n.clone(),
                        Res {
                            key: k,
                            parent: None,
                            slot: None,
                        },
                    );
                }
            }
        }
        let scrut_res = sv.as_ref().and_then(|n| s.res.get(n).cloned());
        let finals: Vec<Scope> = arms
            .iter()
            .map(|(pat, body)| {
                let mut sa = s.clone();
                let mut binds = Vec::new();
                self.pat_binds(pat, &mut binds);
                for (n, payload) in binds {
                    sa.bound.insert(n.clone());
                    if let Some(pl) = payload {
                        if scrut_res.is_some() {
                            let owned = pl.key.is_some();
                            sa.res.insert(
                                n.clone(),
                                Res {
                                    key: pl.key,
                                    parent: sv.clone(),
                                    slot: Some(pl.slot),
                                },
                            );
                            if owned {
                                self.transfers.insert(n.clone());
                                if let Some(ref sv) = sv {
                                    sa.split.entry(sv.clone()).or_default().insert(pl.slot);
                                }
                            }
                        }
                    }
                }
                crate::core::indent(n, out);
                out.push_str(&format!("{} ->\n", crate::core::cpat(pat)));
                self.dump_term(body, &sa, n + 1, out).0
            })
            .collect();
        for f in finals.iter().skip(1) {
            if !Self::same_res(&finals[0], f) {
                self.err("arms of `case` leave different live resources");
                break;
            }
        }
        if let Some(f) = finals.first() {
            *s = f.clone();
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::core::lower_with;
    use crate::diag::Diagnostics;

    /// Front-end (lex → layout → parse → check → infer) + Core lowering.
    pub(super) fn pipeline(src: &str) -> crate::core::Lowered {
        let mut diags = Diagnostics::default();
        let (module, analysis) = crate::compile_front(src, ".", &mut diags);
        let module = module.expect("front-end must compile");
        let inplace: HashSet<(usize, usize)> = analysis.inplace.iter().map(|ip| ip.span).collect();
        lower_with(
            &module,
            &inplace,
            &std::collections::HashMap::new(),
            &std::collections::HashMap::new(),
            &std::collections::HashSet::new(),
            &analysis.consume_native_exempt,
            false,
        )
    }

    /// Runs the Δ judgment over `src` (fresh pipeline), returning the errors.
    fn check_src(src: &str) -> Vec<DeltaErr> {
        let l = pipeline(src);
        check_all(&l.fns, &l.borrow_args, &l.recinfo)
    }

    /// Runs the Δ judgment over `src` after a tamper on the lowered Core.
    fn check_tampered(src: &str, tamper: impl FnOnce(&mut Vec<CoreFn>)) -> Vec<DeltaErr> {
        let l = pipeline(src);
        let mut fns = l.fns.clone();
        tamper(&mut fns);
        check_all(&fns, &l.borrow_args, &l.recinfo)
    }

    /// Δ-3 coherence cross-check with the front-end's DropPoints (`src` fresh).
    fn coherence_src(src: &str) -> Vec<DeltaErr> {
        let mut diags = Diagnostics::default();
        let (module, analysis) = crate::compile_front(src, ".", &mut diags);
        let module = module.expect("front-end must compile");
        let inplace: HashSet<(usize, usize)> = analysis.inplace.iter().map(|ip| ip.span).collect();
        let l = lower_with(
            &module,
            &inplace,
            &std::collections::HashMap::new(),
            &std::collections::HashMap::new(),
            &std::collections::HashSet::new(),
            &analysis.consume_native_exempt,
            false,
        );
        check_drop_coherence(&l.fns, &l.borrow_args, &l.recinfo, &analysis.drops)
    }

    /// Coherence over a tampered Core (the DropPoints stay the front-end's).
    fn coherence_tampered(src: &str, tamper: impl FnOnce(&mut Vec<CoreFn>)) -> Vec<DeltaErr> {
        let mut diags = Diagnostics::default();
        let (module, analysis) = crate::compile_front(src, ".", &mut diags);
        let module = module.expect("front-end must compile");
        let inplace: HashSet<(usize, usize)> = analysis.inplace.iter().map(|ip| ip.span).collect();
        let l = lower_with(
            &module,
            &inplace,
            &std::collections::HashMap::new(),
            &std::collections::HashMap::new(),
            &std::collections::HashSet::new(),
            &analysis.consume_native_exempt,
            false,
        );
        let mut fns = l.fns.clone();
        tamper(&mut fns);
        check_drop_coherence(&fns, &l.borrow_args, &l.recinfo, &analysis.drops)
    }

    fn msgs(errs: &[DeltaErr]) -> Vec<String> {
        errs.iter()
            .map(|e| format!("{}: {}", e.func, e.msg))
            .collect()
    }

    /// Bottom-up walk over every `Term` (through `Let`/`Drop` bodies and the
    /// `If`/`Case` branches of every `Rhs`), then `f` on each term.
    fn map_term(t: &mut Term, f: &mut impl FnMut(&mut Term)) {
        match t {
            Term::Let(_, _, _, b) | Term::Drop(_, _, _, _, b) => map_term(b, f),
            Term::Ret(rhs, _) => match rhs {
                Rhs::Op(_) => {}
                Rhs::If(_, th, el) => {
                    map_term(th, f);
                    map_term(el, f);
                }
                Rhs::Case(_, arms) => {
                    for (_, b) in arms {
                        map_term(b, f);
                    }
                }
            },
        }
        f(t);
    }

    /// Immutable walk over every `Term` — collect information without
    /// mutating.  Calls `f` on each term.
    fn for_each_term(t: &Term, f: &mut impl FnMut(&Term)) {
        f(t);
        match t {
            Term::Let(_, _, _, b) | Term::Drop(_, _, _, _, b) => for_each_term(b, f),
            Term::Ret(rhs, _) => match rhs {
                Rhs::Op(_) => {}
                Rhs::If(_, th, el) => {
                    for_each_term(th, f);
                    for_each_term(el, f);
                }
                Rhs::Case(_, arms) => {
                    for (_, b) in arms {
                        for_each_term(b, f);
                    }
                }
            },
        }
    }

    const OWNED_POLY: &str = include_str!("../tests/fixtures/land_owned_poly.axi");
    const DROP_OK: &str = include_str!("../tests/fixtures/drop_ok.axi");
    const LINEAR_MOVE: &str = include_str!("../tests/fixtures/linear_move.axi");
    const DEEPDROP: &str = include_str!("../tests/fixtures/land_deepdrop_safety.axi");
    const PAYLOAD_RET: &str = include_str!("../tests/fixtures/poly_payload_borrow_return.axi");
    const SESSIONS: &str = include_str!("../tests/fixtures/bound_ok.axi");

    // --- positive guards: the judgment accepts the pipeline's own output ---

    #[test]
    fn accepts_never_used_param() {
        // `makeAndDrop b = 0`: the `%1` parameter is never touched — the
        // reclamation analysis never frees it, so Δ must not call it a leak
        assert_eq!(msgs(&check_src(DROP_OK)), Vec::<String>::new());
    }

    #[test]
    fn accepts_transferred_payload_shallow() {
        // `sum` moves the tail out in the Cons arm and frees the shell there
        // (shallow), deep-drops in the Nil arm — both sound, both accepted
        assert_eq!(msgs(&check_src(OWNED_POLY)), Vec::<String>::new());
    }

    #[test]
    fn accepts_returned_payload_shallow() {
        // `firstInner` returns `inner y` — a heap sub-object of the payload —
        // so the scrutinee gets a shallow free and the payload leaks with it
        assert_eq!(msgs(&check_src(PAYLOAD_RET)), Vec::<String>::new());
    }

    #[test]
    fn accepts_destructors_and_sessions() {
        // the generated destructors (`axion_drop_*`) pass the same judgment;
        // the session state machines are skipped by name
        let src = format!("{DEEPDROP}\n{SESSIONS}\n");
        assert_eq!(msgs(&check_src(&src)), Vec::<String>::new());
    }

    // --- negative guards: the judgment rejects a broken Core ---

    #[test]
    fn rejects_double_drop() {
        let errs = check_tampered(OWNED_POLY, |fns| {
            let f = fns.iter_mut().find(|f| f.name == "sum").unwrap();
            map_term(&mut f.body, &mut |t| {
                if let Term::Drop(v, ty, _, _, body) = t {
                    let inner = std::mem::replace(
                        body,
                        Box::new(Term::Ret(Rhs::Op(Op::Atom(Atom::Int(0))), NO_SPAN)),
                    );
                    *t = Term::Drop(
                        v.clone(),
                        ty.clone(),
                        Vec::new(),
                        NO_SPAN,
                        Box::new(Term::Drop(
                            v.clone(),
                            ty.clone(),
                            Vec::new(),
                            NO_SPAN,
                            inner,
                        )),
                    );
                }
            });
        });
        let m = msgs(&errs);
        assert!(
            m.iter()
                .any(|s| s.contains("drop of `xs` which is not a live resource")),
            "got: {m:?}"
        );
    }

    #[test]
    fn rejects_drop_of_non_resource() {
        let errs = check_tampered(OWNED_POLY, |fns| {
            let f = fns.iter_mut().find(|f| f.name == "sum").unwrap();
            map_term(&mut f.body, &mut |t| {
                if let Term::Drop(_v, ty, _, _, body) = t {
                    let body = std::mem::replace(
                        body,
                        Box::new(Term::Ret(Rhs::Op(Op::Atom(Atom::Int(0))), NO_SPAN)),
                    );
                    *t = Term::Drop("alien".into(), ty.clone(), Vec::new(), NO_SPAN, body);
                }
            });
        });
        let m = msgs(&errs);
        assert!(
            m.iter()
                .any(|s| s.contains("drop of `alien` which is not a live resource")),
            "got: {m:?}"
        );
    }

    #[test]
    fn rejects_deep_drop_after_payload_move() {
        // move the tail (`ys`) out, THEN deep-drop the scrutinee — the
        // destructor would free `ys` twice
        let errs = check_tampered(OWNED_POLY, |fns| {
            let f = fns.iter_mut().find(|f| f.name == "sum").unwrap();
            map_term(&mut f.body, &mut |t| {
                if let Term::Drop(v, None, _, _, body) = t {
                    if let Term::Let(x, rhs, _, rest) = body.as_mut() {
                        let (x2, rhs2) = (x.clone(), rhs.clone());
                        let rest2 = std::mem::replace(
                            rest,
                            Box::new(Term::Ret(Rhs::Op(Op::Atom(Atom::Int(0))), NO_SPAN)),
                        );
                        *t = Term::Let(
                            x2,
                            rhs2,
                            NO_SPAN,
                            Box::new(Term::Drop(
                                v.clone(),
                                Some("List$Int".into()),
                                Vec::new(),
                                NO_SPAN,
                                rest2,
                            )),
                        );
                    }
                }
            });
        });
        let m = msgs(&errs);
        assert!(
            m.iter()
                .any(|s| s.contains("deep drop of `xs` after one of its payloads was moved out")),
            "got: {m:?}"
        );
    }

    #[test]
    fn rejects_leak_at_return() {
        // remove the deep drop from the Nil arm: `xs` survives to the exit
        let errs = check_tampered(OWNED_POLY, |fns| {
            let f = fns.iter_mut().find(|f| f.name == "sum").unwrap();
            map_term(&mut f.body, &mut |t| {
                if let Term::Drop(_, Some(_), _, _, body) = t {
                    let body = std::mem::replace(
                        body,
                        Box::new(Term::Ret(Rhs::Op(Op::Atom(Atom::Int(0))), NO_SPAN)),
                    );
                    *t = *body;
                }
            });
        });
        let m = msgs(&errs);
        assert!(
            m.iter()
                .any(|s| s.contains("resource `xs` is live at the return")),
            "got: {m:?}"
        );
    }

    #[test]
    fn rejects_unbalanced_arms() {
        // a drop in only one arm: the arms leave different live resources
        let errs = check_tampered(OWNED_POLY, |fns| {
            let f = fns.iter_mut().find(|f| f.name == "sum").unwrap();
            let mut seen = false;
            map_term(&mut f.body, &mut |t| {
                if let Term::Drop(_, Some(_), _, _, body) = t {
                    if !seen {
                        seen = true;
                        let body = std::mem::replace(
                            body,
                            Box::new(Term::Ret(Rhs::Op(Op::Atom(Atom::Int(0))), NO_SPAN)),
                        );
                        *t = *body;
                    }
                }
            });
        });
        let m = msgs(&errs);
        assert!(
            m.iter()
                .any(|s| s.contains("arms of `case` leave different live resources")),
            "got: {m:?}"
        );
    }

    #[test]
    fn rejects_drop_key_mismatch() {
        let errs = check_tampered(OWNED_POLY, |fns| {
            let f = fns.iter_mut().find(|f| f.name == "sum").unwrap();
            map_term(&mut f.body, &mut |t| {
                if let Term::Drop(v, Some(_), _, _, body) = t {
                    let body = std::mem::replace(
                        body,
                        Box::new(Term::Ret(Rhs::Op(Op::Atom(Atom::Int(0))), NO_SPAN)),
                    );
                    *t = Term::Drop(v.clone(), Some("Wrong".into()), Vec::new(), NO_SPAN, body);
                }
            });
        });
        let m = msgs(&errs);
        assert!(
            m.iter()
                .any(|s| s.contains("destructor `axion_drop_Wrong` but the value is a `List$Int`")),
            "got: {m:?}"
        );
    }

    #[test]
    fn rejects_unbound_variable() {
        let errs = check_tampered(OWNED_POLY, |fns| {
            let f = fns.iter_mut().find(|f| f.name == "sum").unwrap();
            map_term(&mut f.body, &mut |t| {
                if let Term::Let(_, Rhs::Op(Op::CallDirect(g, args, _)), _, _) = t {
                    if g == "sum" {
                        args[0] = Atom::Var("alien".into());
                    }
                }
            });
        });
        let m = msgs(&errs);
        assert!(
            m.iter()
                .any(|s| s.contains("use of unbound/consumed variable `alien`")),
            "got: {m:?}"
        );
    }

    // --- Δ-2: the annotated dump locks the format (the oracle gate sorts
    //     lines, so it cannot see an annotation on the wrong line) ---

    #[test]
    fn annotated_dump_locks_format() {
        let l = pipeline(DROP_OK);
        let d1 = super::dump_annotated(&l.fns, &l.borrow_args, &l.recinfo);
        let d2 = super::dump_annotated(&l.fns, &l.borrow_args, &l.recinfo);
        assert_eq!(d1, d2, "dump_annotated must be deterministic");
        // the reverse kernel: the recursive `reverse` consumes the tail (`%1`)…
        assert!(d1.contains("      let _t0 = call reverse ys  ; Δ{y ys} · moves{ys} · makes List\n"));
        // …an embedding moves its payload out of Δ…
        assert!(d1.contains("      let _t2 = con Cons y _t1  ; Δ{_t0 y} · moves{y}\n"));
        // …and the tail `append` consumes the carried suffix (aliased result)
        assert!(d1.contains("      ret call append _t0 _t2  ; Δ{_t0} · moves{_t0} · makes List\n"));
        // drop lines stay unannotated — `reverse` now OWNS `xs` and shell-frees it
        assert!(d1.contains("      drop xs\n"));
        assert!(
            !d1.lines()
                .any(|l| l.trim_start().starts_with("drop ") && l.contains("; Δ")),
            "drop lines must not carry annotations"
        );
        // headers stay unannotated
        assert!(d1.contains("reverse xs  =\n"));
    }

    // --- Δ-3, move 2: the coherence cross-check against the front-end's
    //     DropPoints (the two liveness engines must classify %1 params alike) ---

    #[test]
    fn coherence_accepts_never_used_param() {
        // `makeAndDrop b = 0`: check.rs says "dies at entry (never used)";
        // Δ agrees — `b` stays in `owned` to the end (the Core never touches it)
        assert_eq!(msgs(&coherence_src(DROP_OK)), Vec::<String>::new());
    }

    #[test]
    fn coherence_accepts_borrowed_param() {
        // `sum xs = case xs of …`: check.rs says "dies after the last read";
        // Δ agrees — the Nil arm's deep drop (or the Cons shell free) drains
        // `owned` before the exit
        assert_eq!(msgs(&coherence_src(OWNED_POLY)), Vec::<String>::new());
    }

    #[test]
    fn coherence_rejects_core_using_entry_dead_param() {
        // make the Core move `b` (the front-end said it is never used):
        // `ret 0` → `ret call makeAndDrop b` — the param enters Δ, so the
        // two engines now disagree on what dies
        let errs = coherence_tampered(DROP_OK, |fns| {
            let f = fns.iter_mut().find(|f| f.name == "makeAndDrop").unwrap();
            f.body = Term::Ret(
                Rhs::Op(Op::CallDirect(
                    "makeAndDrop".into(),
                    vec![Atom::Var("b".into())],
                    None,
                )),
                NO_SPAN,
            );
        });
        let m = msgs(&errs);
        assert!(
            m.iter().any(
                |s| s.contains("dies at entry per the front-end analysis but the Core uses it")
            ),
            "got: {m:?}"
        );
    }

    #[test]
    fn coherence_rejects_param_never_reclaimed() {
        // a `%1` record param read only via a field selector: check.rs says it
        // "dies after the last read" and the pipeline emits `drop r : Rec`;
        // removing the drop leaves a param that never enters Δ (a field read
        // borrows without pre-inserting) — the engines now disagree
        let src = "data Rec = Rec { f :: Int }\ntakeF :: Rec %1 -> Int\ntakeF r = f r\nmain :: Int\nmain = takeF (Rec 3)\n";
        let errs = coherence_tampered(src, |fns| {
            let f = fns.iter_mut().find(|f| f.name == "takeF").unwrap();
            map_term(&mut f.body, &mut |t| {
                if let Term::Drop(_, _, _, _, body) = t {
                    let body = std::mem::replace(
                        body,
                        Box::new(Term::Ret(Rhs::Op(Op::Atom(Atom::Int(0))), NO_SPAN)),
                    );
                    *t = *body;
                }
            });
        });
        let m = msgs(&errs);
        assert!(
            m.iter().any(|s| s.contains(
                "dies after the last read per the front-end analysis but the Core never uses it"
            )),
            "got: {m:?}"
        );
    }

    // --- Δ-5: the position dimension — a `%1` drain drop must be anchored at
    //     or after the front-end death point (per-statement spans) ---

    #[test]
    fn position_accepts_drop_anchored_after_last_read() {
        // `take b = val b` in linear_move.axi: check.rs says `b` dies after the
        // last read; the pipeline anchors the drain drop at the `val b` read —
        // whose per-statement span covers the argument, so the drop sits after
        // the death point. (This used to fail while `core.rs::expr` rebuilt app
        // exprs with `head.span()`: the anchor ended before the argument, a
        // use-after-free-shaped rejection of a valid program.)
        let errs = coherence_src(LINEAR_MOVE);
        let m = msgs(&errs);
        assert!(m.is_empty(), "got: {m:?}");
    }

    #[test]
    fn position_rejects_anchor_collapsed_to_head_span() {
        // simulate the collapsed-span bug: shrink the anchored drain drop's
        // span to a 1-char window at the statement start — it now ends before
        // the death point (`b` at the end of `val b`) and the position rule
        // fires (use-after-free the classification check cannot see)
        let errs = coherence_tampered(LINEAR_MOVE, |fns| {
            let f = fns.iter_mut().find(|f| f.name == "take").unwrap();
            map_term(&mut f.body, &mut |t| {
                if let Term::Drop(v, _, _, sp, _) = t {
                    if v == "b" && *sp != NO_SPAN {
                        *sp = (sp.0, sp.0 + 1);
                    }
                }
            });
        });
        let m = msgs(&errs);
        assert!(
            m.iter()
                .any(|s| s.contains("anchored before the front-end death point")),
            "got: {m:?}"
        );
    }

    #[test]
    fn position_rule_is_strictly_after_the_death() {
        assert!(span_matches((100, 108), (103, 106)));
        assert!(!span_matches((100, 105), (106, 107)));
        assert!(!span_matches((100, 105), (105, 106)));
    }

    // --- Δ-4: the `--emit delta` debug view ---

    /// The `--emit delta` view over `src` (fresh pipeline + DropPoints).
    fn delta_view(src: &str) -> String {
        let mut diags = Diagnostics::default();
        let (module, analysis) = crate::compile_front(src, ".", &mut diags);
        let module = module.expect("front-end must compile");
        let inplace: HashSet<(usize, usize)> = analysis.inplace.iter().map(|ip| ip.span).collect();
        let l = lower_with(
            &module,
            &inplace,
            &std::collections::HashMap::new(),
            &std::collections::HashMap::new(),
            &std::collections::HashSet::new(),
            &analysis.consume_native_exempt,
            false,
        );
        let lines = crate::lexer::LineMap::new(src);
        super::dump_delta(
            &l.fns,
            &l.borrow_args,
            &l.recinfo,
            &analysis.drops,
            &lines,
            src,
        )
    }

    #[test]
    fn delta_view_reports_verdicts_and_facts() {
        let v = delta_view(DROP_OK);
        // the judgment's per-function conclusions, incl. the resource-life
        // facts the annotated dump cannot show
        assert!(
            v.contains("makeAndDrop b = ok — never-used %1: b\n"),
            "got:\n{v}"
        );
        // `reverse` is now a generic pure-escape consumer (`%1`): it OWNS `xs` and
        // shell-frees each spine cell (one drop per arm) instead of borrowing.
        assert!(v.contains("reverse xs = ok — drops: xs xs\n"), "got:\n{v}");
        assert!(v.contains("axion_drop_List _p = ok\n"), "got:\n{v}");
        assert!(
            v.contains(
                "== verdicts: 58 ok · 0 with violations · 0 skipped (hand-managed generated)\n"
            ),
            "got:\n{v}"
        );
        // 6 owned params agree: makeAndDrop + `unwords` + the generic pure-escape
        // consumers `append`/`reverse`/`concat`/`intersperse` — all coherent with the
        // front-end (`%1` synthesized before the linear checker runs).
        assert!(
            v.contains(
                "== coherence (Δ-3, move 2): 6/6 `%1` params agree with the front-end DropPoints\n"
            ),
            "got:\n{v}"
        );
    }

    #[test]
    fn delta_view_is_deterministic_and_locked() {
        let v = delta_view(DROP_OK);
        assert_eq!(delta_view(DROP_OK), v, "dump_delta must be deterministic");
        // every function line carries the verdict shape `… = ok` (or violations)
        for line in v.lines().filter(|l| l.contains(" = ok")) {
            let body = line.split('=').next().unwrap().trim();
            assert!(body.contains(' '), "verdict line lacks params: {line:?}");
        }
    }

    #[test]
    fn delta_view_borrowed_param_enters_delta() {
        // `sum xs`: the borrowed `%1` param enters Δ (the Nil-arm drop drains
        // `owned`) — so it is NOT never-used, and coherence counts it as used
        let v = delta_view(OWNED_POLY);
        assert!(!v.contains("never-used %1:"), "got:\n{v}");
        // 6 owned params (fixture `sum` + prelude `unwords`/`append`/`reverse`/
        // `concat`/`intersperse`) all agree with the front-end DropPoints.
        assert!(
            v.contains(
                "== coherence (Δ-3, move 2): 6/6 `%1` params agree with the front-end DropPoints\n"
            ),
            "got:\n{v}"
        );
    }

    #[test]
    fn delta_view_surfaces_coherence_violations() {
        // the Δ-3 tamper that makes the Core use an entry-dead param: the view
        // must surface the disagreement as a violation of that function, in
        // sync with the `--check-delta` verdict
        let mut diags = Diagnostics::default();
        let (module, analysis) = crate::compile_front(DROP_OK, ".", &mut diags);
        let module = module.expect("front-end must compile");
        let inplace: HashSet<(usize, usize)> = analysis.inplace.iter().map(|ip| ip.span).collect();
        let l = lower_with(
            &module,
            &inplace,
            &std::collections::HashMap::new(),
            &std::collections::HashMap::new(),
            &std::collections::HashSet::new(),
            &analysis.consume_native_exempt,
            false,
        );
        let mut fns = l.fns.clone();
        let f = fns.iter_mut().find(|f| f.name == "makeAndDrop").unwrap();
        f.body = Term::Ret(
            Rhs::Op(Op::CallDirect(
                "makeAndDrop".into(),
                vec![Atom::Var("b".into())],
                None,
            )),
            NO_SPAN,
        );
        let v = super::dump_delta(
            &fns,
            &l.borrow_args,
            &l.recinfo,
            &analysis.drops,
            &crate::lexer::LineMap::new(DROP_OK),
            DROP_OK,
        );
        assert!(v.contains("makeAndDrop b = 1 violation(s)\n"), "got:\n{v}");
        assert!(
            v.contains(
                "coherence: `b` dies at entry per the front-end analysis but the Core uses it"
            ),
            "got:\n{v}"
        );
        assert!(
            v.contains("== verdicts: 57 ok · 1 with violations · 0 skipped"),
            "got:\n{v}"
        );
        assert!(
            v.contains("== coherence (Δ-3, move 2): 5/6 `%1` params agree"),
            "got:\n{v}"
        );
    }

    // --- F-1: per-field ownership (judgment-first) ---

    const OWNED_HEAP_FIELD: &str = "\
data Box = Box { v :: Int }
data P = P { a :: Box %1, b :: Box %1 }
takeA :: P %1 -> Int
takeA p = v (a p)
main :: Int
main = takeA (P { a = Box { v = 1 }, b = Box { v = 2 } })
";

    const OWNED_SCALAR_FIELD: &str = "\
data Q = Q { f :: Int %1 }
takeF :: Q %1 -> Int
takeF q = f q
main :: Int
main = takeF (Q { f = 1 })
";

    #[test]
    fn owned_heap_field_read_rejects_unsafe_deep_drop() {
        // `takeA p = v (a p)`: reads a `%1` heap field, then the pipeline
        // deep-drops `p` — the destructor would free the already-escaped
        // `a` (UAF).  The (Field·owned) rule classifies the read as a
        // transfer that splits `p`, so the subsequent deep drop is rejected.
        let m = msgs(&check_src(OWNED_HEAP_FIELD));
        assert!(
            m.iter()
                .any(|s| s.contains("deep drop of `p` after one of its payloads was moved out")),
            "got: {m:?}"
        );
    }

    #[test]
    fn remainder_drop_accepts_correct_skip() {
        // tamper the deep drop of `p` into a remainder drop `skip{0}`
        // (skips the extracted slot `a`) — the (Drop·skip) rule accepts it
        // because skip==transferred.  The extracted `Box` binder becomes an
        // independent resource after detach; add a flat drop before return.
        let errs = check_tampered(OWNED_HEAP_FIELD, |fns| {
            let f = fns.iter_mut().find(|f| f.name == "takeA").unwrap();
            let mut binder = None;
            // find the binder of `field a p`
            for_each_term(&f.body, &mut |t| {
                if let Term::Let(x, Rhs::Op(Op::Field { name, .. }), _, _) = t {
                    if name == "a" {
                        binder = Some(x.clone());
                    }
                }
            });
            let binder = binder.expect("takeA must have 'let <x> = field a p'");
            map_term(&mut f.body, &mut |t| {
                if let Term::Drop(v, ty, _, _, _body) = t {
                    if v == "p" && ty.is_some() {
                        let old = std::mem::replace(
                            _body,
                            Box::new(Term::Ret(Rhs::Op(Op::Atom(Atom::Int(0))), NO_SPAN)),
                        );
                        *t = Term::Drop(
                            v.clone(),
                            ty.clone(),
                            vec![0],
                            NO_SPAN,
                            Box::new(Term::Drop(binder.clone(), None, Vec::new(), NO_SPAN, old)),
                        );
                    }
                }
            });
        });
        assert!(msgs(&errs).is_empty(), "got: {:?}", msgs(&errs));
    }

    #[test]
    fn remainder_drop_rejects_wrong_skip() {
        // tamper skip{1} (slot b — NOT transferred) — the (Drop·skip)
        // rule requires skip to equal transferred {0}, so it errors.
        let errs = check_tampered(OWNED_HEAP_FIELD, |fns| {
            let f = fns.iter_mut().find(|f| f.name == "takeA").unwrap();
            map_term(&mut f.body, &mut |t| {
                if let Term::Drop(v, ty, _, _, body) = t {
                    if v == "p" && ty.is_some() {
                        let body = std::mem::replace(
                            body,
                            Box::new(Term::Ret(Rhs::Op(Op::Atom(Atom::Int(0))), NO_SPAN)),
                        );
                        *t = Term::Drop(v.clone(), ty.clone(), vec![1], NO_SPAN, body);
                    }
                }
            });
        });
        let m = msgs(&errs);
        assert!(m.iter().any(|s| s.contains("remainder drop")), "got: {m:?}");
    }

    #[test]
    fn scalar_owned_field_no_false_positive() {
        // `takeF q = f q` with `f :: Int %1`: a scalar `%1` field read is
        // not a transfer (the destructor doesn't touch scalar slots), so the
        // deep drop of `q` is still valid.  (Field·owned) must NOT fire.
        assert_eq!(msgs(&check_src(OWNED_SCALAR_FIELD)), Vec::<String>::new());
    }

    #[test]
    fn owned_field_read_delta_view_facts() {
        // the `--emit delta` view prints a `transferred %1-heap: …` fact
        // for the function that reads a `%1` heap field via selector.
        let v = delta_view(OWNED_HEAP_FIELD);
        assert!(v.contains("transferred %1-heap: a\n"), "got:\n{v}");
    }
}
