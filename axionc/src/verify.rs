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
        )
    }
}

/// `true` if a leak finding should GATE native compilation — a genuine unintended leak in
/// Auto-Drop-governed code. EXEMPT: compiler-synthesized session/parmap state machines
/// (`*$step`), whose memory is hand-rolled (NOT Auto-Drop-driven) and whose residual leaks
/// are the documented conservative session/parmap class — the same rationale as the skipped
/// `axion_drop_*` destructors. (Polymorphic-element leaks are already suppressed upstream via
/// `leak_exempt`, so they never reach here.)
pub fn leak_gates(f: &Finding) -> bool {
    f.cat == Cat::Leak && !f.func.ends_with("$step")
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

fn is_generated(name: &str) -> bool {
    name.starts_with("axion_drop_")
}

/// Verify every function of a lowered module; returns all findings (corruption + leak).
pub fn verify(lowered: &Lowered) -> Vec<Finding> {
    let (summaries, elem_aliases) =
        compute_summaries(&lowered.fns, &lowered.borrow_args, &lowered.recinfo);
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
            PassMode {
                track_fields: true,
                poly_elem: false,
            },
            Some(&mut out),
        );
    }
    out
}

/// The interprocedural alias summary as a REUSABLE analysis over ANY Core (pre- or
/// post-drop — a function's return classification is drop-independent), keyed to the
/// functions that actually return a borrow (non-empty entries only). The lowering pass
/// consumes this to null the ownership annotation on calls to a borrow-returning function,
/// so Auto-Drop stops freeing a borrowed result (the `grab w = inner w` class); the
/// verifier then re-derives its own summary from the emitted Core and CHECKS the outcome.
pub fn borrow_return_summary(fns: &[CoreFn], ba: &BorrowArgs, recinfo: &RecordInfo) -> Summaries {
    let (mut sums, _elem) = compute_summaries(fns, ba, recinfo);
    sums.retain(|_, params| !params.is_empty());
    sums
}

/// Per-function ELEMENT-alias summary: parameter indices whose heap ELEMENT the function's
/// OWNED result shares — it builds a fresh container but embeds a BORROWED element of the
/// param into it (`take`/`drop`/`filter` over a heap element type: `Cons y …` where `y` is a
/// case-extracted element of the borrowed input). The whole-value alias summary discards
/// this (it only records a NON-owned return), yet dropping BOTH the input and such a result
/// double-frees the shared element — the class AX0912 guards and the verifier used to miss.
type ElemAliases = std::collections::HashMap<String, HashSet<usize>>;

/// Fixpoint over the call graph: a function returns a PURE interior alias of param `i` when
/// its `ret` is an interior pointer (`owned == false`) that borrows `i` — which may flow
/// through a call to another alias-returning function, so it iterates to a fixed point
/// (findings suppressed during this dry run).
fn compute_summaries(
    fns: &[CoreFn],
    ba: &BorrowArgs,
    recinfo: &RecordInfo,
) -> (Summaries, ElemAliases) {
    let mut sums: Summaries = HashMap::new();
    let mut elem: ElemAliases = HashMap::new();
    let no_elem: ElemAliases = HashMap::new();
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
            let rv = run_fn(f, ba, recinfo, &sums, &no_elem, pure_mode, None);
            let pure_borrowed = params_borrowed(&rv, f);
            let params = if rv.owned {
                HashSet::new()
            } else {
                pure_borrowed.clone()
            };
            if sums.get(&f.name) != Some(&params) {
                sums.insert(f.name.clone(), params);
                changed = true;
            }
            // ELEM-alias pass: field-tracking ON so a case-extracted borrowed ELEMENT is seen.
            // The params the return borrows ONLY under element-tracking (`P_elem − P_pure`) are
            // the ones shared via a CONSTRUCTOR embed (`take`: `Cons y …` embeds a borrowed
            // element) — as opposed to a pure interior alias (`grab`, already in P_pure).
            // Dropping BOTH the input and such a result double-frees the shared heap element.
            let elem_mode = PassMode {
                track_fields: true,
                poly_elem: true,
            };
            let rve = run_fn(f, ba, recinfo, &sums, &elem, elem_mode, None);
            let elem_params: HashSet<usize> = params_borrowed(&rve, f)
                .difference(&pure_borrowed)
                .copied()
                .collect();
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
fn run_fn(
    f: &CoreFn,
    ba: &BorrowArgs,
    recinfo: &RecordInfo,
    summaries: &Summaries,
    elem_aliases: &ElemAliases,
    mode: PassMode,
    out: Option<&mut Vec<Finding>>,
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
            // borrowing nothing, so using it is always fine.
            st.insert(p.clone(), Val::default());
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
        leak_exempt: HashSet::new(),
        projections: HashMap::new(),
        borrowed_params,
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
    /// The GENUINELY-borrowed params (in `borrow_args`): the caller retains and drops the
    /// whole structure. Distinct from a MOVED-in param modelled the same way here (a view
    /// like `dropWhile` — not in `borrow_args`). `consume` flags freeing an interior of one
    /// of THESE (the owner double-frees), but not of a moved-in/view param (this fn owns it).
    borrowed_params: HashSet<String>,
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
    /// Apply a consuming op's escapes: each moved operand (and an indirect call's `nonstrict`
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
        if let Op::CallDirect(g, args, _) = op {
            let borrowed_pos = self.ba.get(g);
            let alias_ret = self.summaries.get(g);
            for (i, a) in args.iter().enumerate() {
                if let Atom::Var(v) = a {
                    let frees = !borrowed_pos.is_some_and(|s| s.contains(&i))
                        && !alias_ret.is_some_and(|s| s.contains(&i));
                    let borrowed_interior = st.get(v).is_some_and(|val| {
                        !val.owned && val.borrows.iter().any(|w| self.borrowed_params.contains(w))
                    });
                    if frees && borrowed_interior {
                        self.finding(Cat::DropOfAlias, v, sp);
                    }
                }
            }
        }
        // moved operands (and an indirect call's `nonstrict` receiver) escape → mark them dead.
        let e = op_delta_effect(op, self.ba);
        for a in e.moves.iter().chain(e.nonstrict.iter()) {
            if let Atom::Var(v) = a {
                Self::kill(v, Cat::UseAfterFree, st);
            }
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
        if let Some(Atom::Var(src)) = e.alias {
            Self::kill(src, Cat::UseAfterFree, st);
        }
        // moved operands AND the `nonstrict` closure receiver of an indirect call escape
        // (the call consumes them) — same as `scan_op_escapes` in Auto-Drop; `consume` also
        // flags consuming an interior alias of a borrowed resource.
        self.consume(op, sp, st);
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
                let borrows: HashSet<String> = params
                    .iter()
                    .filter_map(|&i| args.get(i))
                    .filter_map(|a| match a {
                        Atom::Var(v) => Some(v.clone()),
                        _ => None,
                    })
                    .collect();
                return Val {
                    owned: false,
                    borrows,
                    dead: None,
                    key: None,
                };
            }
        }
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
                    if !val.owned {
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
            let heap_elem = e
                .produces
                .as_ref()
                .and_then(|r| r.key.as_deref())
                .is_some_and(key_elem_is_heap);
            if heap_elem {
                if let Some(params) = self.elem_aliases.get(g) {
                    for &i in params {
                        if let Some(Atom::Var(v)) = args.get(i) {
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
                };
            }
        }
        if let Some(res) = &e.produces {
            return Val {
                owned: true,
                borrows: inherited,
                dead: None,
                key: res.key.clone(),
            };
        }
        // A constructor with no concrete produce key (a POLYMORPHIC `Cons y ys` in a generic
        // function) still EMBEDS its borrowed operands — keep the inherited borrows so the
        // element-alias summary sees the share (`take` returns a list embedding a borrowed
        // element). Not owned here (unknown key); the concrete call site supplies ownership.
        if self.mode.poly_elem && !inherited.is_empty() && matches!(op, Op::MakeCon { .. } | Op::MakeTuple(_)) {
            return Val {
                owned: false,
                borrows: inherited,
                dead: None,
                key: None,
            };
        }
        Val::default()
    }

    /// `drop x`: `x` must be a live OWNED resource. `key` is the destructor type (`Some` =
    /// a DEEP drop that recurses into `x`'s fields; `None` = a SHELL free of just the cell,
    /// used when the fields were moved out and reused). `skip` lists the slots a deep drop
    /// does NOT free (moved out via a skip-destructor).
    fn do_drop(&mut self, x: &str, key: Option<&String>, skip: &[usize], sp: Span, st: &mut State) {
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
                // A deep drop of an OWNED value that shares a heap element with an
                // already-freed resource (its `borrows` name a dead value — the
                // element-alias class, `take`/`drop` over a heap element type) frees that
                // shared element a SECOND time. Deep only (`key.is_some()`): a shell free
                // touches just the cell, not the shared element.
                if key.is_some() {
                    let dbl = st.get(x).is_some_and(|v| {
                        v.borrows
                            .iter()
                            .any(|w| st.get(w).is_some_and(|wv| wv.dead.is_some()))
                    });
                    if dbl {
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
                if let Some(v) = st.get_mut(x) {
                    v.dead = Some(Cat::DoubleFree);
                }
                // a DEEP drop of `x` (has a destructor key) frees its extracted fields
                // transitively: mark every still-live child whose slot is NOT skipped as
                // freed-via-parent, so it is neither reported as a leak nor droppable again
                // (a later `drop` of it would now be a DoubleFree — a strengthening). A SHELL
                // free (`key = None`) frees only the cell — the fields were moved out and
                // reused (`append`'s `Cons z zs -> drop xs; …`), so it frees no child.
                let kids = key.and(self.children.get(x)).cloned().unwrap_or_default();
                for (child, slot) in kids {
                    if !skip.contains(&slot) {
                        if let Some(cv) = st.get_mut(&child) {
                            if cv.owned && cv.dead.is_none() {
                                cv.dead = Some(Cat::DoubleFree);
                            }
                        }
                    }
                }
                // §move-out: a skipped slot's heap field is MOVED OUT to whoever projected
                // it — transfer ownership so the projection outlives `x`'s shell free (it no
                // longer borrows the now-freed cell; it owns the moved field). Without this
                // the projection would dangle on `x`'s death (a false UseAfterFree).
                if !skip.is_empty() {
                    let promote: Vec<String> = self
                        .projections
                        .iter()
                        .filter(|(_, (src, slot))| src == x && skip.contains(slot))
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
                let ret_val = self.classify(op, st);
                if let Some(Atom::Var(src)) = e.alias {
                    Self::kill(src, Cat::UseAfterFree, st);
                }
                // returned/consumed resources escape → mark moved so they aren't leaks: the
                // moved operands and the `nonstrict` closure receiver of an indirect call.
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
        for a in arms {
            let mut s = st.clone();
            rets.push(self.term(a, &mut s, tail));
            exits.push(s);
        }
        self.merge(&outer, &exits, sp, st);
        merge_vals(&rets)
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
        for (pat, body) in arms {
            let mut s = st.clone();
            self.bind_pattern(pat, scrut_var.as_deref(), scrut_owned, &mut s);
            rets.push(self.term(body, &mut s, tail));
            exits.push(s);
        }
        self.merge(&outer, &exits, sp, st);
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
                        if self.mode.track_fields
                            && (self.mode.poly_elem || self.recinfo.field_drop_slot(con, i).is_some())
                        {
                            st.insert(
                                n.clone(),
                                Val {
                                    owned: false,
                                    borrows: HashSet::from([scrut.to_string()]),
                                    ..Default::default()
                                },
                            );
                        }
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
                    if self.recinfo.field_drop_slot(con, i).is_none() {
                        self.leak_exempt.insert(n.clone());
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
            if st.get(w).is_some_and(|wv| wv.dead.is_some()) {
                self.finding(Cat::UseAfterFree, v, sp); // dangling interior alias
            }
        }
    }

    /// Mark `v` moved-out/consumed. Only an OWNED resource dies on a move — a scalar is
    /// COPIED and an interior alias is a shared pointer (copying it is fine; its target
    /// still governs its validity), so neither is killed.
    fn kill(v: &str, cat: Cat, st: &mut State) {
        if let Some(val) = st.get_mut(v) {
            if val.owned && val.dead.is_none() {
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

    /// A leak inside a compiler-synthesized session/parmap state machine (`*$step`) is NOT
    /// gate-worthy — its memory is hand-rolled (not Auto-Drop-driven) and its residual leaks
    /// are the documented conservative class (see `leak_gates`).
    #[test]
    fn synthetic_worker_leak_is_whitelisted() {
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
        assert!(
            !leak_gates(leak.unwrap()),
            "a $step worker leak must not gate"
        );
    }
}
