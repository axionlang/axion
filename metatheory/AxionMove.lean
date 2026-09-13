/-
  AxionMove — the move/escape slice of the Axión drop-verifier metatheory (Track 2).

  The earlier slices can only lose ownership of a value by DROPPING it (freeing). But real Core is
  full of MOVES: a value handed into a constructor (`Cons y ys` consumes `y`, `ys`), passed to a
  consuming callee (a `%1` arg), or RETURNED (escaping to the caller). In all of these the value is
  NOT freed by this function — ownership is transferred — so it must not be counted as a leak, and
  it must not be used or dropped afterwards. This is exactly what `verify.rs` models with a value
  leaving Δ (`delta::DeltaEffect.moves` / `.alias`, the escape analysis) rather than being dropped.

  Without this, the model cannot faithfully describe most corpus functions (which return or embed
  owned values), which is why the faithfulness bridge (`bridge.md`) is a curated per-shape pairing
  rather than a whole-corpus translation. This slice adds `Op.moveOut` and proves soundness with it,
  the foundational step toward widening the bridge.

  Correspondence to `verify.rs`:
    * `Op.moveOut n`            ↔ `n` leaves Δ: consumed by a constructor/`%1` call, or returned
                                  (`DeltaEffect.moves` / `.alias`). NOT a `drop`.
    * `Cell.moved`             ↔ a value transferred out — live elsewhere, no longer this frame's
                                  responsibility; not a leak, not usable/droppable here.
    * `leakFree` (no live left) ↔ AX0911, now correctly treating moved-out values as reclaimed
                                  elsewhere.
-/

namespace AxionMove

/-- A cell: unallocated, a live owner, freed, or MOVED OUT (transferred — live elsewhere). -/
inductive Cell where
  | fresh
  | live
  | freed
  | moved
  deriving DecidableEq, Repr

abbrev St := Nat → Cell

def upd (S : St) (n : Nat) (c : Cell) : St := fun m => if m = n then c else S m

/-- Operations. `moveOut n` transfers ownership of `n` away (into a constructor / a consuming call /
    the return value) — `n` is no longer owned here, but is NOT freed. -/
inductive Op where
  | alloc   (n : Nat)
  | use     (n : Nat)
  | drop    (n : Nat)
  | moveOut (n : Nat)
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

/-- The faulting machine. `moveOut` and `drop` both require a live owner and both remove ownership;
    they differ only in the resulting status (`moved` vs `freed`) — a moved value is live elsewhere
    (not freed here), a freed value is reclaimed. Using or dropping either afterwards FAULTS. -/
def rstep (S : St) : Op → Option St
  | .alloc n   => match S n with | .fresh => some (upd S n .live) | _ => none
  | .use n     => match S n with | .live => some S | _ => none
  | .drop n    => match S n with | .live => some (upd S n .freed) | _ => none
  | .moveOut n => match S n with | .live => some (upd S n .moved) | _ => none

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
/-- Leak-free = no live owner remains. A `moved` value is NOT a leak (it was transferred out). -/
def leakFree (S : St) : Prop := ∀ n, S n ≠ .live
def accepts (e : Expr) : Prop := ∃ Sf, Chk sInit e Sf ∧ leakFree Sf

/-! ## Soundness (same progress + preservation skeleton). -/

theorem chk_seq {S Sm Sf : St} {t k : Expr}
    (h1 : Chk S t Sm) (h2 : Chk Sm k Sf) : Chk S (seq t k) Sf := by
  induction h1 with
  | done => exact h2
  | op hs _ ih => exact Chk.op hs (ih h2)
  | brn ha hb _ _ _ ihk => exact Chk.brn ha hb (ihk h2)

theorem preservation {Sf S S' : St} {e e' : Expr}
    (hchk : Chk S e Sf) (hstep : Step (S, e) (S', e')) : Chk S' e' Sf := by
  cases hstep with
  | op hr => cases hchk with | op hr' hk => rw [hr] at hr'; cases hr'; exact hk
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

theorem no_corruption {e : Expr} (hacc : accepts e) :
    ∀ s, Star Step (sInit, e) s → ¬ Stuck s := by
  obtain ⟨Sf, hchk, _⟩ := hacc
  intro s hstar
  exact not_stuck (star_wt (Sf := Sf) hstar hchk)

theorem no_leak {e : Expr} (hacc : accepts e) :
    ∀ Sf', Star Step (sInit, e) (Sf', .done) → ∀ n, Sf' n ≠ .live := by
  obtain ⟨Sf, hchk, hleak⟩ := hacc
  intro Sf' hstar
  have hwt : WT Sf (Sf', .done) := star_wt (Sf := Sf) hstar hchk
  have : Sf' = Sf := chk_done_eq hwt
  rw [this]; exact hleak

theorem sound {e : Expr} (hacc : accepts e) :
    (∀ s, Star Step (sInit, e) s → ¬ Stuck s) ∧
    (∀ Sf', Star Step (sInit, e) (Sf', .done) → ∀ n, Sf' n ≠ .live) :=
  ⟨no_corruption hacc, no_leak hacc⟩

/-! ## The move/escape theorems. -/

private def MA : St := upd sInit 0 .live    -- after `alloc 0`
private def MM : St := upd MA 0 .moved      -- after a further `moveOut 0`

/-- **Escape is not a leak.** `alloc 0; moveOut 0` (allocate, then transfer ownership out — the
    value is returned/embedded, not freed) IS accepted: a moved-out value is reclaimed elsewhere,
    so the frame is leak-free even though it never dropped it. This is the case plain `AxionDrop`
    (no move op) would wrongly call a leak. -/
theorem escape_is_leak_free_accepted : accepts (.op (.alloc 0) (.op (.moveOut 0) .done)) := by
  refine ⟨_, Chk.op rfl (Chk.op rfl Chk.done), ?_⟩
  intro n
  by_cases h0 : n = 0
  · subst h0; decide
  · simp [upd, sInit, h0]

/-- **Use-after-move is rejected.** Reading a value after it has been moved out faults — the frame
    no longer owns it (`n` is `moved`). -/
theorem use_after_move_rejected :
    ¬ accepts (.op (.alloc 0) (.op (.moveOut 0) (.op (.use 0) .done))) := by
  intro hacc
  have hstar : Star Step (sInit, .op (.alloc 0) (.op (.moveOut 0) (.op (.use 0) .done)))
      (MM, .op (.use 0) .done) :=
    .step (Step.op (rfl : rstep sInit (.alloc 0) = some MA))
      (.step (Step.op (rfl : rstep MA (.moveOut 0) = some MM)) .refl)
  refine no_corruption hacc _ hstar ⟨by decide, ?_⟩
  rintro ⟨_, hs⟩
  cases hs with | op hr => rw [(rfl : rstep MM (.use 0) = none)] at hr; contradiction

/-- **Drop-after-move is rejected** (a double reclamation: the recipient owns it now). -/
theorem drop_after_move_rejected :
    ¬ accepts (.op (.alloc 0) (.op (.moveOut 0) (.op (.drop 0) .done))) := by
  intro hacc
  have hstar : Star Step (sInit, .op (.alloc 0) (.op (.moveOut 0) (.op (.drop 0) .done)))
      (MM, .op (.drop 0) .done) :=
    .step (Step.op (rfl : rstep sInit (.alloc 0) = some MA))
      (.step (Step.op (rfl : rstep MA (.moveOut 0) = some MM)) .refl)
  refine no_corruption hacc _ hstar ⟨by decide, ?_⟩
  rintro ⟨_, hs⟩
  cases hs with | op hr => rw [(rfl : rstep MM (.drop 0) = none)] at hr; contradiction

/-- A value neither dropped nor moved out IS a leak — still rejected (the move op doesn't weaken
    leak-freedom). -/
theorem forgotten_owner_is_leak_rejected : ¬ accepts (.op (.alloc 0) .done) := by
  rintro ⟨Sf, hchk, hleak⟩
  cases hchk with
  | op hr hdone =>
    rw [(rfl : rstep sInit (.alloc 0) = some MA)] at hr
    injection hr with hr
    subst hr
    have hSf := chk_done_eq hdone
    subst hSf
    exact (hleak 0) (by decide)

/-! ## Axiom audit. -/
#print axioms sound
#print axioms escape_is_leak_free_accepted
#print axioms use_after_move_rejected
#print axioms drop_after_move_rejected

end AxionMove
