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

/-! ## Executable checker (M2 whole-fragment bridge core, move/escape fragment)

`Chk`/`accepts` are `Prop`s over `St = Nat → Cell` with existentials and a "no live cell" condition —
not runnable. To run the model's OWN judgment on a real function's Core (the `--emit model-trace`
bridge, now covering functions that MOVE/return owned values), we give an executable checker
`acceptsL : Expr → Bool` over a finite assoc-list state (default `fresh`), and prove it decides
`accepts` EXACTLY (`chk_move_correct`). -/

/-- Effective cell of `n`: the first binding in the assoc list, else `fresh` (untouched). -/
def lookupC (n : Nat) : List (Nat × Cell) → Cell
  | [] => .fresh
  | (m, c) :: rest => if m = n then c else lookupC n rest

/-- Reflect the finite state into the total `St`. -/
def toSt (l : List (Nat × Cell)) : St := fun n => lookupC n l

/-- Update = shadowing prepend (`lookupC` takes the first match). -/
def setC (n : Nat) (c : Cell) (l : List (Nat × Cell)) : List (Nat × Cell) := (n, c) :: l

theorem toSt_nil : toSt [] = sInit := rfl

theorem setC_toSt {n : Nat} {c : Cell} {l : List (Nat × Cell)} :
    toSt (setC n c l) = upd (toSt l) n c := by
  funext m
  show lookupC m ((n, c) :: l) = (if m = n then c else lookupC m l)
  simp only [lookupC]
  by_cases h : m = n
  · subst h; simp
  · rw [if_neg (fun heq : n = m => h heq.symm), if_neg h]

def keysOf (l : List (Nat × Cell)) : List Nat := l.map Prod.fst

theorem lookupC_notMem {n : Nat} {l : List (Nat × Cell)} (h : n ∉ keysOf l) :
    lookupC n l = .fresh := by
  induction l with
  | nil => rfl
  | cons x xs ih =>
    obtain ⟨m, c⟩ := x
    simp only [keysOf, List.map_cons, List.mem_cons, not_or] at h
    obtain ⟨hm, hrest⟩ := h
    simp only [lookupC, if_neg (fun heq : m = n => hm heq.symm)]
    exact ih hrest

/-- A boolean ∀ over a key list (self-contained; no `List.all`-lemma dependence). -/
def allC (p : Nat → Bool) : List Nat → Bool
  | [] => true
  | k :: ks => p k && allC p ks

theorem allC_iff {p : Nat → Bool} {ks : List Nat} :
    allC p ks = true ↔ ∀ k ∈ ks, p k = true := by
  induction ks with
  | nil => simp [allC]
  | cons k ks ih =>
    simp only [allC, Bool.and_eq_true, ih, List.mem_cons]
    constructor
    · rintro ⟨hk, hrest⟩ x (rfl | hx)
      · exact hk
      · exact hrest x hx
    · intro h; exact ⟨h k (Or.inl rfl), fun x hx => h x (Or.inr hx)⟩

def leakFreeL (l : List (Nat × Cell)) : Bool :=
  allC (fun n => decide (lookupC n l ≠ .live)) (keysOf l)

theorem leakFreeL_iff {l : List (Nat × Cell)} : leakFreeL l = true ↔ ∀ n, toSt l n ≠ .live := by
  simp only [leakFreeL, allC_iff]
  constructor
  · intro h n
    by_cases hn : n ∈ keysOf l
    · have := h n hn; simpa using this
    · show lookupC n l ≠ .live
      rw [lookupC_notMem hn]; decide
  · intro h k _; simpa using h k

def stEqL (a b : List (Nat × Cell)) : Bool :=
  allC (fun n => decide (lookupC n a = lookupC n b)) (keysOf a ++ keysOf b)

theorem stEqL_toSt {a b : List (Nat × Cell)} : stEqL a b = true ↔ toSt a = toSt b := by
  simp only [stEqL, allC_iff]
  constructor
  · intro h
    funext n
    show lookupC n a = lookupC n b
    by_cases hn : n ∈ keysOf a ++ keysOf b
    · have := h n hn; simpa using this
    · rw [List.mem_append, not_or] at hn
      rw [lookupC_notMem hn.1, lookupC_notMem hn.2]
  · intro h k _
    have hk : lookupC k a = lookupC k b := by have := congrFun h k; simpa [toSt] using this
    simpa using hk

/-- Executable per-op transition, mirroring `rstep` on the finite representation. -/
def rstepL (l : List (Nat × Cell)) : Op → Option (List (Nat × Cell))
  | .alloc n   => match lookupC n l with | .fresh => some (setC n .live l)  | _ => none
  | .use n     => match lookupC n l with | .live  => some l                 | _ => none
  | .drop n    => match lookupC n l with | .live  => some (setC n .freed l) | _ => none
  | .moveOut n => match lookupC n l with | .live  => some (setC n .moved l) | _ => none

theorem rstepL_sound {l l' : List (Nat × Cell)} {a : Op} (h : rstepL l a = some l') :
    rstep (toSt l) a = some (toSt l') := by
  have hlk : toSt l = fun n => lookupC n l := rfl
  cases a with
  | alloc n =>
    simp only [rstepL] at h
    cases hc : lookupC n l with
    | fresh =>
      rw [hc] at h; have hl : l' = setC n .live l := (Option.some.inj h).symm
      subst hl; simp only [rstep, hlk, hc, setC_toSt]
    | live => rw [hc] at h; simp at h
    | freed => rw [hc] at h; simp at h
    | moved => rw [hc] at h; simp at h
  | use n =>
    simp only [rstepL] at h
    cases hc : lookupC n l with
    | live => rw [hc] at h; have : l' = l := (Option.some.inj h).symm; subst this; simp only [rstep, hlk, hc]
    | fresh => rw [hc] at h; simp at h
    | freed => rw [hc] at h; simp at h
    | moved => rw [hc] at h; simp at h
  | drop n =>
    simp only [rstepL] at h
    cases hc : lookupC n l with
    | live =>
      rw [hc] at h; have hl : l' = setC n .freed l := (Option.some.inj h).symm
      subst hl; simp only [rstep, hlk, hc, setC_toSt]
    | fresh => rw [hc] at h; simp at h
    | freed => rw [hc] at h; simp at h
    | moved => rw [hc] at h; simp at h
  | moveOut n =>
    simp only [rstepL] at h
    cases hc : lookupC n l with
    | live =>
      rw [hc] at h; have hl : l' = setC n .moved l := (Option.some.inj h).symm
      subst hl; simp only [rstep, hlk, hc, setC_toSt]
    | fresh => rw [hc] at h; simp at h
    | freed => rw [hc] at h; simp at h
    | moved => rw [hc] at h; simp at h

theorem rstepL_complete {l : List (Nat × Cell)} {a : Op} {Sf : St}
    (h : rstep (toSt l) a = some Sf) : ∃ l', rstepL l a = some l' ∧ Sf = toSt l' := by
  have hlk : toSt l = fun n => lookupC n l := rfl
  cases a with
  | alloc n =>
    simp only [rstep, hlk] at h
    cases hc : lookupC n l with
    | fresh =>
      rw [hc] at h
      refine ⟨setC n .live l, by simp only [rstepL, hc], ?_⟩
      rw [← Option.some.inj h, setC_toSt, hlk]
    | live => rw [hc] at h; simp at h
    | freed => rw [hc] at h; simp at h
    | moved => rw [hc] at h; simp at h
  | use n =>
    simp only [rstep, hlk] at h
    cases hc : lookupC n l with
    | live => rw [hc] at h; exact ⟨l, by simp only [rstepL, hc], (Option.some.inj h).symm⟩
    | fresh => rw [hc] at h; simp at h
    | freed => rw [hc] at h; simp at h
    | moved => rw [hc] at h; simp at h
  | drop n =>
    simp only [rstep, hlk] at h
    cases hc : lookupC n l with
    | live =>
      rw [hc] at h
      refine ⟨setC n .freed l, by simp only [rstepL, hc], ?_⟩
      rw [← Option.some.inj h, setC_toSt, hlk]
    | fresh => rw [hc] at h; simp at h
    | freed => rw [hc] at h; simp at h
    | moved => rw [hc] at h; simp at h
  | moveOut n =>
    simp only [rstep, hlk] at h
    cases hc : lookupC n l with
    | live =>
      rw [hc] at h
      refine ⟨setC n .moved l, by simp only [rstepL, hc], ?_⟩
      rw [← Option.some.inj h, setC_toSt, hlk]
    | fresh => rw [hc] at h; simp at h
    | freed => rw [hc] at h; simp at h
    | moved => rw [hc] at h; simp at h

/-- Executable whole-`Expr` checker: same recursion shape as `Chk`. -/
def chkL (l : List (Nat × Cell)) : Expr → Option (List (Nat × Cell))
  | .done => some l
  | .op a k =>
      match rstepL l a with
      | some l' => chkL l' k
      | none => none
  | .brn t e k =>
      match chkL l t, chkL l e with
      | some lt, some le => if stEqL lt le then chkL lt k else none
      | _, _ => none

theorem chkL_sound : ∀ {e : Expr} {l l' : List (Nat × Cell)},
    chkL l e = some l' → Chk (toSt l) e (toSt l') := by
  intro e
  induction e with
  | done =>
    intro l l' h; simp only [chkL] at h
    have : l = l' := Option.some.inj h; subst this; exact Chk.done
  | op a k ih =>
    intro l l' h; simp only [chkL] at h
    cases hstep : rstepL l a with
    | none => rw [hstep] at h; simp at h
    | some l1 => rw [hstep] at h; exact Chk.op (rstepL_sound hstep) (ih h)
  | brn t e2 k iht ihe2 ihk =>
    intro l l' h; simp only [chkL] at h
    cases hct : chkL l t with
    | none => rw [hct] at h; simp at h
    | some lt =>
      cases hce : chkL l e2 with
      | none => rw [hct, hce] at h; simp at h
      | some le =>
        rw [hct, hce] at h
        by_cases hse : stEqL lt le = true
        · simp only [hse, if_true] at h
          have hteq : toSt lt = toSt le := (stEqL_toSt).mp hse
          refine Chk.brn (iht hct) ?_ (ihk h)
          rw [hteq]; exact ihe2 hce
        · simp only [hse, Bool.false_eq_true, if_false] at h; simp at h

theorem chkL_complete : ∀ {e : Expr} {l : List (Nat × Cell)} {Sf : St},
    Chk (toSt l) e Sf → ∃ l', chkL l e = some l' ∧ Sf = toSt l' := by
  intro e
  induction e with
  | done => intro l Sf h; cases h; exact ⟨l, by simp [chkL], rfl⟩
  | op a k ih =>
    intro l Sf h
    cases h with
    | op hs hk =>
      obtain ⟨l1, hstep, hl1⟩ := rstepL_complete hs
      rw [hl1] at hk
      obtain ⟨l', hck, hsf⟩ := ih hk
      exact ⟨l', by simp only [chkL, hstep]; exact hck, hsf⟩
  | brn t e2 k iht ihe2 ihk =>
    intro l Sf h
    cases h with
    | brn ht he hk =>
      obtain ⟨lt, hct, hlt⟩ := iht ht
      obtain ⟨le, hce, hle⟩ := ihe2 he
      have hteq : toSt lt = toSt le := by rw [← hlt, ← hle]
      have hse : stEqL lt le = true := (stEqL_toSt).mpr hteq
      rw [hlt] at hk
      obtain ⟨l', hck, hsf⟩ := ihk hk
      exact ⟨l', by simp only [chkL, hct, hce, hse, if_true]; exact hck, hsf⟩

/-- A program is accepted by the executable checker iff it checks from `[]` to a leak-free state. -/
def acceptsL (e : Expr) : Bool :=
  match chkL [] e with
  | some l => leakFreeL l
  | none => false

/-- **The bridge crux (move/escape fragment).** The executable checker decides `accepts` exactly. -/
theorem chk_move_correct {e : Expr} : acceptsL e = true ↔ accepts e := by
  constructor
  · intro h
    simp only [acceptsL] at h
    cases hc : chkL [] e with
    | none => rw [hc] at h; simp at h
    | some l =>
      rw [hc] at h
      have hchk := chkL_sound hc
      rw [toSt_nil] at hchk
      exact ⟨toSt l, hchk, (leakFreeL_iff).mp h⟩
  · rintro ⟨Sf, hchk, hleak⟩
    rw [show sInit = toSt ([] : List (Nat × Cell)) from toSt_nil.symm] at hchk
    obtain ⟨l', hc, hsf⟩ := chkL_complete hchk
    have hlf : leakFreeL l' = true := (leakFreeL_iff).mpr (by rw [← hsf]; exact hleak)
    simp only [acceptsL, hc, hlf]

/-- The checker RUNS (decided by `rfl`): escape is accepted; forgotten owner / use-after-move /
    drop-after-move / heterogeneous branch are rejected; a balanced drop-branch is accepted. -/
example : acceptsL (.op (.alloc 0) (.op (.moveOut 0) .done)) = true := rfl
example : acceptsL (.op (.alloc 0) .done) = false := rfl
example : acceptsL (.op (.alloc 0) (.op (.moveOut 0) (.op (.use 0) .done))) = false := rfl
example : acceptsL (.op (.alloc 0) (.op (.moveOut 0) (.op (.drop 0) .done))) = false := rfl
example : acceptsL (.op (.alloc 0) (.brn (.op (.drop 0) .done) (.op (.moveOut 0) .done) .done)) = false := rfl
example : acceptsL (.op (.alloc 0) (.brn (.op (.drop 0) .done) (.op (.drop 0) .done) .done)) = true := rfl

/-! ## Axiom audit. -/
#print axioms sound
#print axioms chk_move_correct
#print axioms escape_is_leak_free_accepted
#print axioms use_after_move_rejected
#print axioms drop_after_move_rejected

end AxionMove
