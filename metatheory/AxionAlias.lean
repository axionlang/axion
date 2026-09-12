/-
  AxionAlias — the interior-alias slice of the Axión drop-verifier metatheory (Track 2).

  `AxionDrop.lean` proved the linear owned-set discipline sound (double-free / UAF / leak),
  including branches. This file adds the piece the whole R-1…R-5 / V-1 arc was actually about: the
  verifier's `borrows` set + `borrow_return_summary` — INTERIOR ALIASES. A value can be an OWNER
  (its own allocation) or a BORROW: an interior pointer INTO another owner's allocation (the `grab
  w = inner w` / `field w` shape). The two hazards interior aliases add, which `verify.rs` rejects:

    * dropping a borrow (`DropOfAlias`)     — frees the owner's cell through an interior pointer,
                                               a double-free when the owner is also freed;
    * using a borrow after its owner is freed (`UseAfterFree`) — a dangling read.

  Modeling note. Once borrows and ABA-safety are in play, the verifier's abstract state must track
  the same owner/borrow/freed structure as the heap, so the abstraction is EXACT for this fragment
  (no fresh-vs-freed coarsening as in the linear slice). The real content therefore lands on the
  BRANCH JOIN: the static check inspects BOTH arms and requires them to agree (same owner/borrow
  state), whereas a run takes ONE arm — so soundness = "all-paths static check ⟹ every dynamic
  path safe" (progress + preservation over the nondeterministic machine). This is exactly the V-1
  conditional-param-return: an arm that returns a borrow of a param cannot balance an arm that
  returns a fresh owner, so the branch is REJECTED — unless a `copy` (R-5's `axion_copy_T`) turns
  the borrow arm into a fresh owner, making the arms agree. Both are theorems below.

  Correspondence to `verify.rs`:
    * `Cell.bref t`      ↔ a `Val` with `owned=false, borrows={t}` — an interior alias of `t`.
    * `Op.borrow b t`    ↔ `let b = field t` / an interior-alias-returning call (the `grab` class).
    * `Op.copy b t`      ↔ `let b = axion_copy_T t` (R-5): read `t`, produce a FRESH owner.
    * `drop` of a `bref` ↔ `do_drop` flagging `DropOfAlias`.
    * `use` of a dangling `bref` ↔ `use_atom` flagging `UseAfterFree`.
    * `Chk.brn` (arms → same state) ↔ `merge_vals` reconciling owner/borrow across arms.
-/

namespace AxionAlias

/-- A cell: never allocated, a live owner, a freed owner, or an interior pointer into owner `t`. -/
inductive Cell where
  | fresh
  | live
  | freed
  | bref (t : Nat)
  deriving DecidableEq, Repr

/-- The state: every variable id maps to its cell. Shared by the machine and the checker — with
    interior aliases the verifier's abstraction is exact (see the header note). -/
abbrev St := Nat → Cell

/-- Point-update. -/
def upd (S : St) (n : Nat) (c : Cell) : St := fun m => if m = n then c else S m

/-- `reach S n` : is the value named `n` safe to READ right now — a live owner, or a borrow whose
    target owner is still live? A freed/fresh cell, or a borrow into a freed owner (dangling), is
    not reachable. -/
def reach (S : St) (n : Nat) : Bool :=
  match S n with
  | .live => true
  | .bref t => match S t with | .live => true | _ => false
  | _ => false

/-- One operation. `borrow b t` binds `b` to an interior pointer into owner `t` (the unsafe alias);
    `copy b t` reads `t` and binds `b` to a FRESH owner (R-5's deep copy). -/
inductive Op where
  | alloc  (n : Nat)      -- n := a fresh owned cell
  | use    (n : Nat)      -- read n (owner or borrow); requires n reachable
  | drop   (n : Nat)      -- free owner n; dropping a borrow/freed/fresh FAULTS
  | borrow (b t : Nat)    -- b := interior pointer into live owner t
  | copy   (b t : Nat)    -- b := fresh owner cloned from reachable t (axion_copy_T)
  deriving Repr, DecidableEq

/-- Tree-structured Core (as in `AxionDrop.lean`). -/
inductive Expr where
  | done
  | op   (a : Op) (k : Expr)
  | brn  (t e : Expr) (k : Expr)
  deriving Repr, DecidableEq

def seq : Expr → Expr → Expr
  | .done,       k => k
  | .op a t',    k => .op a (seq t' k)
  | .brn a b t', k => .brn a b (seq t' k)

/-- The faulting machine: an op transforms the state or gets STUCK (`none`) exactly on a memory
    fault — dropping a non-owner (double-free / drop-of-alias), using an unreachable cell (UAF /
    dangling borrow), re-allocating/re-binding a non-fresh id, or borrowing/copying a non-live/
    unreadable source. Fresh binders (ids used at most once) keep the model ABA-free, faithful to
    the SSA-style unique names of the Core. -/
def rstep (S : St) : Op → Option St
  | .alloc n    => match S n with | .fresh => some (upd S n .live) | _ => none
  | .use n      => if reach S n then some S else none
  | .drop n     => match S n with | .live => some (upd S n .freed) | _ => none
  | .borrow b t => match S b, S t with | .fresh, .live => some (upd S b (.bref t)) | _, _ => none
  | .copy b t   => match S b with | .fresh => if reach S t then some (upd S b .live) else none | _ => none

/-- Small-step machine over `(state, remaining-expr)`; a branch may enter either arm. -/
inductive Step : (St × Expr) → (St × Expr) → Prop where
  | op  {S a k S'} : rstep S a = some S' → Step (S, .op a k) (S', k)
  | brL {S t e k}  : Step (S, .brn t e k) (S, seq t k)
  | brR {S t e k}  : Step (S, .brn t e k) (S, seq e k)

inductive Star {α : Type} (R : α → α → Prop) : α → α → Prop where
  | refl {a} : Star R a a
  | step {a b c} : R a b → Star R b c → Star R a c

/-- The verifier's judgment: it threads the same state (exact abstraction) via `rstep`, and at a
    branch REQUIRES both arms to reach the SAME state `Sm` before the continuation (the sound core
    of `merge_vals` — the merged state must describe both arms). -/
inductive Chk : St → Expr → St → Prop where
  | done {S} : Chk S .done S
  | op   {S S' Sf a k} : rstep S a = some S' → Chk S' k Sf → Chk S (.op a k) Sf
  | brn  {S Sm Sf t e k} : Chk S t Sm → Chk S e Sm → Chk Sm k Sf → Chk S (.brn t e k) Sf

/-- The empty initial state. -/
def sInit : St := fun _ => .fresh

/-- Leak-free = no live owner remains (a leftover `bref` owns nothing, so it is not a leak). -/
def leakFree (S : St) : Prop := ∀ n, S n ≠ .live

/-- A program is ACCEPTED iff the checker admits it to a leak-free final state. -/
def accepts (e : Expr) : Prop := ∃ Sf, Chk sInit e Sf ∧ leakFree Sf

/-! ## Soundness (progress + preservation). Because the abstraction is exact, a well-typed state is
just one the checker admits; the content is that admission implies every path is fault-free. -/

/-- The checker composes over `seq` (arm then continuation). -/
theorem chk_seq {S Sm Sf : St} {t k : Expr}
    (h1 : Chk S t Sm) (h2 : Chk Sm k Sf) : Chk S (seq t k) Sf := by
  induction h1 with
  | done => exact h2
  | op hs _ ih => exact Chk.op hs (ih h2)
  | brn ha hb _ _ _ ihk => exact Chk.brn ha hb (ihk h2)

/-- **Preservation.** A step out of an admitted state lands in an admitted state (same final `Sf`). -/
theorem preservation {Sf S S' : St} {e e' : Expr}
    (hchk : Chk S e Sf) (hstep : Step (S, e) (S', e')) : Chk S' e' Sf := by
  cases hstep with
  | op hr =>
    cases hchk with
    | op hr' hk =>
      rw [hr] at hr'
      cases hr'
      exact hk
  | brL => cases hchk with | brn ht _ hk => exact chk_seq ht hk
  | brR => cases hchk with | brn _ he hk => exact chk_seq he hk

/-- **Progress.** An admitted state is finished or can step — never stuck on a memory fault. -/
theorem progress {Sf S : St} {e : Expr} (hchk : Chk S e Sf) :
    e = .done ∨ ∃ s', Step (S, e) s' := by
  cases hchk with
  | done => exact Or.inl rfl
  | op hr _ => exact Or.inr ⟨_, Step.op hr⟩
  | brn _ _ _ => exact Or.inr ⟨_, Step.brL⟩

def WT (Sf : St) (s : St × Expr) : Prop := Chk s.1 s.2 Sf

def Stuck (s : St × Expr) : Prop := s.2 ≠ .done ∧ ¬ ∃ s', Step s s'

theorem not_stuck {Sf : St} {s : St × Expr} (hwt : WT Sf s) : ¬ Stuck s := by
  obtain ⟨S, e⟩ := s
  rcases progress hwt with hdone | hstep
  · rintro ⟨hne, _⟩; exact hne hdone
  · rintro ⟨_, hns⟩; exact hns hstep

theorem wt_step {Sf : St} {a b : St × Expr} (hwt : WT Sf a) (hab : Step a b) : WT Sf b := by
  obtain ⟨S, e⟩ := a
  obtain ⟨S', e'⟩ := b
  exact preservation hwt hab

theorem star_wt {Sf : St} {s s' : St × Expr}
    (hstar : Star Step s s') : WT Sf s → WT Sf s' := by
  induction hstar with
  | refl => exact id
  | step hab _ ih => exact fun hwt => ih (wt_step hwt hab)

/-- A finished expression's incoming and final states coincide. -/
theorem chk_done_eq {S Sf : St} (h : Chk S .done Sf) : S = Sf := by cases h; rfl

/-- **No corruption (on every path).** No state reachable from an accepted program is stuck — no
    double-free, no drop-of-alias, no use-after-free/dangling-borrow, whichever branches run. -/
theorem no_corruption {e : Expr} (hacc : accepts e) :
    ∀ s, Star Step (sInit, e) s → ¬ Stuck s := by
  obtain ⟨Sf, hchk, _⟩ := hacc
  intro s hstar
  exact not_stuck (star_wt (Sf := Sf) hstar hchk)

/-- **No leak (on every path).** Any finished path leaves no live owner. -/
theorem no_leak {e : Expr} (hacc : accepts e) :
    ∀ Sf', Star Step (sInit, e) (Sf', .done) → ∀ n, Sf' n ≠ .live := by
  obtain ⟨Sf, hchk, hleak⟩ := hacc
  intro Sf' hstar
  have hwt : WT Sf (Sf', .done) := star_wt (Sf := Sf) hstar hchk
  have : Sf' = Sf := chk_done_eq hwt
  rw [this]; exact hleak

/-- **Full soundness with interior aliases.** -/
theorem sound {e : Expr} (hacc : accepts e) :
    (∀ s, Star Step (sInit, e) s → ¬ Stuck s) ∧
    (∀ Sf', Star Step (sInit, e) (Sf', .done) → ∀ n, Sf' n ≠ .live) :=
  ⟨no_corruption hacc, no_leak hacc⟩

/-! ## The interior-alias theorems (dogfooding the soundness results). -/

private def S1 : St := upd sInit 0 .live            -- after `alloc 0`
private def S2 : St := upd S1 1 (.bref 0)            -- after `borrow 1 0`
private def S3 : St := upd S2 0 .freed              -- after a further `drop 0`

/-- **DropOfAlias is rejected.** `alloc 0; borrow 1 0; drop 1` — dropping the interior pointer `1`
    faults (it would free owner 0's cell through an alias), so it cannot be accepted. This is the
    `grab`/field-alias double-free class. -/
theorem drop_of_alias_rejected :
    ¬ accepts (.op (.alloc 0) (.op (.borrow 1 0) (.op (.drop 1) .done))) := by
  intro hacc
  have hstar : Star Step (sInit, .op (.alloc 0) (.op (.borrow 1 0) (.op (.drop 1) .done)))
      (S2, .op (.drop 1) .done) :=
    .step (Step.op (rfl : rstep sInit (.alloc 0) = some S1))
      (.step (Step.op (rfl : rstep S1 (.borrow 1 0) = some S2)) .refl)
  refine no_corruption hacc _ hstar ⟨by decide, ?_⟩
  rintro ⟨_, hs⟩
  cases hs with | op hr => rw [(rfl : rstep S2 (.drop 1) = none)] at hr; contradiction

/-- **Dangling use is rejected.** `alloc 0; borrow 1 0; drop 0; use 1` — reading the borrow after
    its owner is freed faults (use-after-free). -/
theorem dangling_use_rejected :
    ¬ accepts (.op (.alloc 0) (.op (.borrow 1 0) (.op (.drop 0) (.op (.use 1) .done)))) := by
  intro hacc
  have hstar :
      Star Step (sInit, .op (.alloc 0) (.op (.borrow 1 0) (.op (.drop 0) (.op (.use 1) .done))))
        (S3, .op (.use 1) .done) :=
    .step (Step.op (rfl : rstep sInit (.alloc 0) = some S1))
      (.step (Step.op (rfl : rstep S1 (.borrow 1 0) = some S2))
        (.step (Step.op (rfl : rstep S2 (.drop 0) = some S3)) .refl))
  refine no_corruption hacc _ hstar ⟨by decide, ?_⟩
  rintro ⟨_, hs⟩
  cases hs with | op hr => rw [(rfl : rstep S3 (.use 1) = none)] at hr; contradiction

/-- **V-1 (conditional-param-return alias) is rejected.** `w := alloc; if _ then (r := borrow w)
    else (r := fresh owner); drop r; drop w`. The THEN arm makes `r` a borrow of `w`, so `drop r`
    on that path frees `w` through an alias — a fault. So the program is rejected (the arms cannot
    balance: one leaves `r` a borrow, the other an owner). This is exactly what `verify.rs` catches
    before R-5's copy. -/
theorem v1_conditional_alias_return_rejected :
    ¬ accepts (.op (.alloc 0)
        (.brn (.op (.borrow 1 0) .done) (.op (.alloc 1) .done)
              (.op (.drop 1) (.op (.drop 0) .done)))) := by
  intro hacc
  -- take the THEN arm; after grafting the continuation it is `borrow 1 0; drop 1; drop 0`.
  have hstar : Star Step
      (sInit, .op (.alloc 0)
        (.brn (.op (.borrow 1 0) .done) (.op (.alloc 1) .done)
              (.op (.drop 1) (.op (.drop 0) .done))))
      (S2, .op (.drop 1) (.op (.drop 0) .done)) :=
    .step (Step.op (rfl : rstep sInit (.alloc 0) = some S1))
      (.step Step.brL
        (.step (Step.op (rfl : rstep S1 (.borrow 1 0) = some S2)) .refl))
  refine no_corruption hacc _ hstar ⟨by decide, ?_⟩
  rintro ⟨_, hs⟩
  cases hs with | op hr => rw [(rfl : rstep S2 (.drop 1) = none)] at hr; contradiction

/-- **R-5's copy makes it accepted.** Replace the borrow arm with a `copy` (a fresh owner): now
    BOTH arms leave `r` a fresh owner, they balance, and `drop r; drop w` is safe on either path.
    This is the mechanized statement that the deep-copy is exactly what admits a real conditional
    container return. -/
theorem v1_copy_fixed_accepted :
    accepts (.op (.alloc 0)
        (.brn (.op (.copy 1 0) .done) (.op (.alloc 1) .done)
              (.op (.drop 1) (.op (.drop 0) .done)))) := by
  refine ⟨_,
    Chk.op rfl
      (Chk.brn (Chk.op rfl Chk.done) (Chk.op rfl Chk.done)
        (Chk.op rfl (Chk.op rfl Chk.done))),
    ?_⟩
  -- final state: 0 and 1 freed, everything else fresh — no live owner.
  intro n
  by_cases h0 : n = 0
  · subst h0; decide
  · by_cases h1 : n = 1
    · subst h1; decide
    · simp [upd, sInit, h0, h1]

/-- **Borrows are not over-rejected.** A borrow used safely, then its owner freed, IS accepted —
    the checker admits sound aliasing (no `bref` leaks: only live owners count). -/
theorem safe_borrow_accepted :
    accepts (.op (.alloc 0) (.op (.borrow 1 0) (.op (.use 1) (.op (.drop 0) .done)))) := by
  refine ⟨_, Chk.op rfl (Chk.op rfl (Chk.op rfl (Chk.op rfl Chk.done))), ?_⟩
  intro n
  by_cases h0 : n = 0
  · subst h0; decide
  · by_cases h1 : n = 1
    · subst h1; decide
    · simp [upd, sInit, h0, h1]

/-! ## Axiom audit. -/
#print axioms sound
#print axioms no_corruption
#print axioms no_leak
#print axioms drop_of_alias_rejected
#print axioms v1_conditional_alias_return_rejected
#print axioms v1_copy_fixed_accepted

end AxionAlias
