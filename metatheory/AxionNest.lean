/-
  AxionNest — the moved-in-heap slice of the Axión drop-verifier metatheory (Track 2).

  Moving an owned heap value into a fresh tuple / constructor / record (`let t = tuple s 1`, `s` an
  owned `String`) hands its ownership to the container: from then on only the container's DEEP
  drop (a keyed destructor) reclaims `s`. A FLAT drop (`drop t`, no key) frees the container's own
  cell and leaves `s` allocated with nothing pointing at it — a leak. `verify.rs` tracks, per
  container, which slots hold moved-in heap (`heap_inside`), clears a slot when a `case` binds it
  to a variable (moving it back out), and reports a flat drop of a container with an occupied slot
  as a leak (AX0911).

  This slice gives the machine a notion of containment: a cell may be `inside c i` (slot `i` of
  container `c`). It proves the usual soundness (accepted ⟹ no fault, no leak — counting cells left
  inside a freed container as leaked) and, specifically, that the verifier's DROP-TIME report is
  justified: once a container with an occupied slot is flat-freed, the program can never be
  accepted, because nothing can reclaim that cell any more (`flat_drop_with_contents_rejected`).

  Correspondence to `verify.rs`:
    * `Op.pack c i n`   ↔ a `MakeTuple`/`MakeCon`/`MakeRecord` moving owned `n` into slot `i` of `c`.
    * `Op.unpack c i n` ↔ a `case c of …` binding slot `i` to a variable (now owned on its own), or
                          a raw load `loadraw c+off` inside that `case` arm, where `off` is slot
                          `i`'s offset under the arm's constructor.
    * `Op.dropDeep c`   ↔ `Drop(c, Some key)` — the destructor frees the contents too.
    * `Op.dropFlat c`   ↔ `Drop(c, None)` — a flat `free` of the cell only.
    * `Cell.inside c i` ↔ an entry `i ∈ heap_inside[c]`.
  As in the key and alias slices, the checker is the exact abstraction (it threads the machine), so
  the content is the theorems: what the machine rules out, and that the drop-time report never
  rejects a program the end-of-function leak check would have accepted.
-/

namespace AxionNest

/-- A cell: unallocated, a live owner, held in slot `i` of container `c`, or freed. -/
inductive Cell where
  | fresh
  | live
  | inside (c i : Nat)
  | freed
  deriving DecidableEq, Repr

abbrev St := Nat → Cell

def upd (S : St) (n : Nat) (x : Cell) : St := fun m => if m = n then x else S m

/-- Free container `c` and every cell held inside it (the keyed destructor). -/
def freeDeep (S : St) (c : Nat) : St := fun m =>
  if m = c then .freed
  else match S m with
    | .inside c' _ => if c' = c then .freed else S m
    | x => x

inductive Op where
  | alloc    (n : Nat)
  | use      (n : Nat)
  | pack     (c i n : Nat)
  | unpack   (c i n : Nat)
  | dropFlat (c : Nat)
  | dropDeep (c : Nat)
  deriving Repr, DecidableEq

inductive Expr where
  | done
  | op   (a : Op) (k : Expr)
  | brn  (t e : Expr) (k : Expr)
  deriving Repr, DecidableEq

def seq : Expr → Expr → Expr
  | .done,       k => k
  | .op a t',    k => .op a (seq t' k)
  | .brn a b t', k => .brn a b (seq t' k)

/-- The faulting machine. A flat drop is NOT a fault: it silently orphans whatever the container
    still holds, which surfaces as a leak at the end of the run. -/
def rstep (S : St) : Op → Option St
  | .alloc n      => match S n with | .fresh => some (upd S n .live) | _ => none
  | .use n        => match S n with | .live => some S | _ => none
  | .pack c i n   => match S c, S n with
                     | .live, .live => if n = c then none else some (upd S n (.inside c i))
                     | _, _ => none
  | .unpack c i n => match S c, S n with
                     | .live, .inside c' i' => if c' = c ∧ i' = i then some (upd S n .live) else none
                     | _, _ => none
  | .dropFlat c   => match S c with | .live => some (upd S c .freed) | _ => none
  | .dropDeep c   => match S c with | .live => some (freeDeep S c) | _ => none

inductive Step : (St × Expr) → (St × Expr) → Prop where
  | op  {S a k S'} : rstep S a = some S' → Step (S, .op a k) (S', k)
  | brL {S t e k}  : Step (S, .brn t e k) (S, seq t k)
  | brR {S t e k}  : Step (S, .brn t e k) (S, seq e k)

inductive Star {α : Type} (R : α → α → Prop) : α → α → Prop where
  | refl {a} : Star R a a
  | step {a b c} : R a b → Star R b c → Star R a c

inductive Chk : St → Expr → St → Prop where
  | done {S} : Chk S .done S
  | op   {S S' Sf a k} : rstep S a = some S' → Chk S' k Sf → Chk S (.op a k) Sf
  | brn  {S Sm Sf t e k} : Chk S t Sm → Chk S e Sm → Chk Sm k Sf → Chk S (.brn t e k) Sf

def sInit : St := fun _ => .fresh

/-- Leak-free: every cell is either never allocated or freed — none live, none stranded inside a
    container. -/
def leakFree (S : St) : Prop := ∀ n, S n = .fresh ∨ S n = .freed

def accepts (e : Expr) : Prop := ∃ Sf, Chk sInit e Sf ∧ leakFree Sf

/-! ## Soundness (progress + preservation), the same skeleton as the other slices. -/

theorem chk_seq {S Sm Sf : St} {t k : Expr}
    (h1 : Chk S t Sm) (h2 : Chk Sm k Sf) : Chk S (seq t k) Sf := by
  induction h1 with
  | done => exact h2
  | op hs _ ih => exact Chk.op hs (ih h2)
  | brn ha hb _ _ _ ihk => exact Chk.brn ha hb (ihk h2)

theorem preservation {Sf S S' : St} {e e' : Expr}
    (hchk : Chk S e Sf) (hstep : Step (S, e) (S', e')) : Chk S' e' Sf := by
  cases hstep with
  | op hr =>
    cases hchk with
    | op hr' hk => rw [hr] at hr'; cases hr'; exact hk
  | brL => cases hchk with | brn ht _ hk => exact chk_seq ht hk
  | brR => cases hchk with | brn _ he hk => exact chk_seq he hk

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
  obtain ⟨S, e⟩ := a; obtain ⟨S', e'⟩ := b; exact preservation hwt hab

theorem star_wt {Sf : St} {s s' : St × Expr} (hstar : Star Step s s') : WT Sf s → WT Sf s' := by
  induction hstar with
  | refl => exact id
  | step hab _ ih => exact fun hwt => ih (wt_step hwt hab)

theorem chk_done_eq {S Sf : St} (h : Chk S .done Sf) : S = Sf := by cases h; rfl

/-- **No corruption (on every path).** -/
theorem no_corruption {e : Expr} (hacc : accepts e) :
    ∀ s, Star Step (sInit, e) s → ¬ Stuck s := by
  obtain ⟨Sf, hchk, _⟩ := hacc
  intro s hstar
  exact not_stuck (star_wt (Sf := Sf) hstar hchk)

/-- **No leak (on every path)** — including a cell stranded inside a flat-freed container. -/
theorem no_leak {e : Expr} (hacc : accepts e) :
    ∀ Sf', Star Step (sInit, e) (Sf', .done) → leakFree Sf' := by
  obtain ⟨Sf, hchk, hleak⟩ := hacc
  intro Sf' hstar
  have hwt : WT Sf (Sf', .done) := star_wt (Sf := Sf) hstar hchk
  have : Sf' = Sf := chk_done_eq hwt
  rw [this]; exact hleak

theorem sound {e : Expr} (hacc : accepts e) :
    (∀ s, Star Step (sInit, e) s → ¬ Stuck s) ∧
    (∀ Sf', Star Step (sInit, e) (Sf', .done) → leakFree Sf') :=
  ⟨no_corruption hacc, no_leak hacc⟩

/-! ## The drop-time report is justified

A cell stranded inside a freed container stays stranded: no operation can reclaim it. `unpack`
needs the container live, `dropDeep` needs it live, and `alloc` cannot reuse a freed container. -/

theorem rstep_keeps_orphan {S S' : St} {a : Op} {c i n : Nat}
    (hr : rstep S a = some S') (hc : S c = .freed) (hn : S n = .inside c i) :
    S' c = .freed ∧ S' n = .inside c i := by
  cases a with
  | alloc m =>
    simp only [rstep] at hr
    split at hr
    · next hm =>
      cases hr
      have hmc : c ≠ m := fun h => by rw [h] at hc; rw [hc] at hm; cases hm
      have hmn : n ≠ m := fun h => by rw [h] at hn; rw [hn] at hm; cases hm
      exact ⟨by simp [upd, hmc, hc], by simp [upd, hmn, hn]⟩
    · cases hr
  | use m =>
    simp only [rstep] at hr
    split at hr
    · cases hr; exact ⟨hc, hn⟩
    · cases hr
  | pack c' i' m =>
    simp only [rstep] at hr
    split at hr
    · next hc' hm =>
      split at hr
      · cases hr
      · cases hr
        have hmc : c ≠ m := fun h => by rw [h] at hc; rw [hc] at hm; cases hm
        have hmn : n ≠ m := fun h => by rw [h] at hn; rw [hn] at hm; cases hm
        exact ⟨by simp [upd, hmc, hc], by simp [upd, hmn, hn]⟩
    · cases hr
  | unpack c' i' m =>
    simp only [rstep] at hr
    split at hr
    · next c'' i'' hc' hm =>
      split at hr
      · next hci =>
        cases hr
        have hmc : c ≠ m := fun h => by rw [h] at hc; rw [hc] at hm; cases hm
        have hmn : n ≠ m := by
          intro h
          rw [h] at hn; rw [hn] at hm
          cases hm
          rw [hci.1] at hc; rw [hc] at hc'; cases hc'
        exact ⟨by simp [upd, hmc, hc], by simp [upd, hmn, hn]⟩
      · cases hr
    · cases hr
  | dropFlat c' =>
    simp only [rstep] at hr
    split at hr
    · next hc' =>
      cases hr
      have hcc : c ≠ c' := fun h => by rw [h] at hc; rw [hc] at hc'; cases hc'
      have hnc : n ≠ c' := fun h => by rw [h] at hn; rw [hn] at hc'; cases hc'
      exact ⟨by simp [upd, hcc, hc], by simp [upd, hnc, hn]⟩
    · cases hr
  | dropDeep c' =>
    simp only [rstep] at hr
    split at hr
    · next hc' =>
      cases hr
      have hcc : c ≠ c' := fun h => by rw [h] at hc; rw [hc] at hc'; cases hc'
      have hnc : n ≠ c' := fun h => by rw [h] at hn; rw [hn] at hc'; cases hc'
      exact ⟨by simp [freeDeep, hcc, hc], by simp [freeDeep, hnc, hn, hcc]⟩
    · cases hr

theorem chk_keeps_orphan {S Sf : St} {e : Expr} {c i n : Nat}
    (hchk : Chk S e Sf) (hc : S c = .freed) (hn : S n = .inside c i) :
    Sf c = .freed ∧ Sf n = .inside c i := by
  induction hchk with
  | done => exact ⟨hc, hn⟩
  | op hr _ ih =>
    obtain ⟨hc', hn'⟩ := rstep_keeps_orphan hr hc hn
    exact ih hc' hn'
  | brn _ _ _ iht _ ihk =>
    obtain ⟨hc', hn'⟩ := iht hc hn
    exact ihk hc' hn'

/-- **Flat-freeing a container that still holds a moved-in cell is never accepted** — whatever
    the rest of the program does. So `verify.rs` reporting the leak AT the flat drop (rather than
    waiting for the function exit) rejects nothing the end-of-function leak check would accept. -/
theorem flat_drop_with_contents_rejected {e k : Expr} {S : St} {c i n : Nat}
    (hreach : Star Step (sInit, e) (S, .op (.dropFlat c) k)) (hn : S n = .inside c i) :
    ¬ accepts e := by
  rintro ⟨Sf, hchk, hleak⟩
  have hwt : WT Sf (S, .op (.dropFlat c) k) := star_wt (Sf := Sf) hreach hchk
  cases hwt with
  | op hr hk =>
    simp only [rstep] at hr
    split at hr
    · next hcl =>
      cases hr
      have hnc : n ≠ c := fun h => by rw [h] at hn; rw [hn] at hcl; cases hcl
      have hc' : upd S c .freed c = .freed := by simp [upd]
      have hn' : upd S c .freed n = .inside c i := by simp [upd, hnc, hn]
      have := (chk_keeps_orphan hk hc' hn').2
      rcases hleak n with h | h <;> rw [this] at h <;> cases h
    · cases hr

/-- **A raw field load reads exactly one slot.** `verify.rs` maps a `loadraw c+off` inside a `case`
    arm to the slot `off` names under the arm's constructor — an `unpack c j n`. If the cell `n` it
    claims sits in a DIFFERENT slot `i ≠ j`, the program is never accepted: a load cannot move out a
    cell that is not at its offset. (A load at an offset with no constructor in scope moves nothing
    out, so the slots stay occupied and a flat drop is caught by `flat_drop_with_contents_rejected`.) -/
theorem unpack_wrong_slot_rejected {e k : Expr} {S : St} {c i j n : Nat}
    (hreach : Star Step (sInit, e) (S, .op (.unpack c j n) k)) (hn : S n = .inside c i)
    (hij : j ≠ i) : ¬ accepts e := by
  rintro ⟨Sf, hchk, _⟩
  have hwt : WT Sf (S, .op (.unpack c j n) k) := star_wt (Sf := Sf) hreach hchk
  cases hwt with
  | op hr _ =>
    simp only [rstep, hn] at hr
    cases hc : S c <;> simp [hc, Ne.symm hij] at hr

/-! ## Non-vacuity. Container `0`, a heap value `1` moved into its slot `0`. -/

private def P (tail : Expr) : Expr :=
  .op (.alloc 0) (.op (.alloc 1) (.op (.pack 0 0 1) tail))

private def S3 : St := upd (upd (upd sInit 0 .live) 1 .live) 1 (.inside 0 0)

private theorem reach_tail (tail : Expr) : Star Step (sInit, P tail) (S3, tail) :=
  .step (Step.op rfl) (.step (Step.op rfl) (.step (Step.op rfl) .refl))

/-- `t = (s)`; flat `drop t` — the moved-in `s` leaks: rejected. -/
theorem flat_drop_rejected : ¬ accepts (P (.op (.dropFlat 0) .done)) :=
  flat_drop_with_contents_rejected (n := 1) (i := 0) (reach_tail _) (by rfl)

/-- The keyed (deep) drop reclaims both: accepted. -/
theorem deep_drop_accepted : accepts (P (.op (.dropDeep 0) .done)) := by
  refine ⟨_, Chk.op rfl (Chk.op rfl (Chk.op rfl (Chk.op rfl Chk.done))), ?_⟩
  intro n
  by_cases h0 : n = 0
  · subst h0; simp [freeDeep]
  · by_cases h1 : n = 1
    · subst h1; simp [freeDeep, upd]
    · simp [freeDeep, upd, sInit, h0, h1]

/-- `case t of (s) -> drop s`, then the flat `drop t` of the emptied shell: accepted. -/
theorem flat_drop_after_unpack_accepted :
    accepts (P (.op (.unpack 0 0 1) (.op (.dropDeep 1) (.op (.dropFlat 0) .done)))) := by
  refine ⟨_, Chk.op rfl (Chk.op rfl (Chk.op rfl (Chk.op rfl (Chk.op rfl (Chk.op rfl Chk.done))))), ?_⟩
  intro n
  by_cases h0 : n = 0
  · subst h0; simp [upd]
  · by_cases h1 : n = 1
    · subst h1; simp [freeDeep, upd, h0]
    · simp [freeDeep, upd, sInit, h0, h1]

/-! ## Raw field loads (`grabBox`): container `0` holds `1` in slot `0` and `2` in slot `1`. The
    arm binds slot `0` (`Box x _`) and Auto-Drop raw-loads slot `1` to free it. -/

private def Q (tail : Expr) : Expr :=
  .op (.alloc 0) (.op (.alloc 1) (.op (.alloc 2) (.op (.pack 0 0 1) (.op (.pack 0 1 2) tail))))

private def T5 : St := upd (upd (upd (upd (upd sInit 0 .live) 1 .live) 2 .live) 1 (.inside 0 0)) 2 (.inside 0 1)

private theorem reach_q (tail : Expr) : Star Step (sInit, Q tail) (T5, tail) :=
  .step (Step.op rfl) (.step (Step.op rfl) (.step (Step.op rfl)
    (.step (Step.op rfl) (.step (Step.op rfl) .refl))))

/-- `x` bound (slot 0) and freed, slot 1 raw-loaded and freed, then the emptied shell flat-freed:
    accepted. -/
theorem raw_load_per_slot_accepted :
    accepts (Q (.op (.unpack 0 0 1) (.op (.dropDeep 1)
      (.op (.unpack 0 1 2) (.op (.dropDeep 2) (.op (.dropFlat 0) .done)))))) := by
  refine ⟨_, Chk.op rfl (Chk.op rfl (Chk.op rfl (Chk.op rfl (Chk.op rfl (Chk.op rfl
    (Chk.op rfl (Chk.op rfl (Chk.op rfl (Chk.op rfl Chk.done))))))))), ?_⟩
  intro n
  by_cases h0 : n = 0
  · subst h0; simp [upd]
  · by_cases h1 : n = 1
    · subst h1; simp [freeDeep, upd]
    · by_cases h2 : n = 2
      · subst h2; simp [freeDeep, upd]
      · simp [freeDeep, upd, sInit, h0, h1, h2]

/-- Raw-loading slot `0` (already moved out) as if it held `2` (which sits in slot `1`): rejected. -/
theorem raw_load_wrong_slot_rejected :
    ¬ accepts (Q (.op (.unpack 0 0 2) (.op (.dropDeep 2) (.op (.dropFlat 0) .done)))) :=
  unpack_wrong_slot_rejected (i := 1) (reach_q _) (by rfl) (by decide)

/-! ## Axiom audit. -/
#print axioms sound
#print axioms flat_drop_with_contents_rejected
#print axioms flat_drop_rejected
#print axioms deep_drop_accepted
#print axioms flat_drop_after_unpack_accepted
#print axioms unpack_wrong_slot_rejected
#print axioms raw_load_per_slot_accepted
#print axioms raw_load_wrong_slot_rejected

end AxionNest
