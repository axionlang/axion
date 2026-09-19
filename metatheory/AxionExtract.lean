/-
  AxionExtract — heap-extracting `case` for the M2 faithfulness bridge (owner/borrow extraction).

  The bridge (`--emit model-trace` → executable `acceptsL`) previously excluded `case` that BINDS
  heap payloads (`case xs of Cons h t -> …`) — the dominant real idiom. Closing it needs the model
  to distinguish two kinds of extraction, which is `AxionAlias.lean`'s owner/borrow content:

    * OWNED-scrutinee peel (`xs : %1`): the shell is consumed and the payloads become FRESH OWNERS —
      already `AxionMove`'s vocabulary (`moveOut` the shell, `alloc` each payload). No new machinery.
    * BORROWED-scrutinee peel: each payload is an INTERIOR ALIAS (`bref t`) of the scrutinee `t`.
      Using it is fine WHILE `t` is live; dropping it is a double-free (DropOfAlias); moving/returning
      it is the borrow-escape hazard (the AX0912 class); using it after `t` is freed is a UAF.

  `AxionAlias` proves this RELATIONALLY over `St := Nat → Cell` (a function) — which does NOT reduce
  under `by rfl`, so it cannot back a bridge example. This file re-expresses the SAME semantics over a
  FINITE assoc-list state (as `AxionMove.lean` does), giving an executable `acceptsL : Expr → Bool`
  proven to decide `accepts` EXACTLY (`chk_correct`), so `acceptsL … = ⟨verifier-verdict⟩ := by rfl`
  bridge examples reduce. Soundness (`sound`): an accepted program never gets stuck (no double-free /
  bad extraction / UAF) and leaves no live owner (no leak) on every path.

  Correspondence to `verify.rs`:
    * `Cell.bref t`     ↔ a `Val` with `owned=false, borrows={t}` (a case-extracted field of a
                          borrowed scrutinee, or a `Field`/interior alias).
    * `Op.borrow b t`   ↔ binding `b` from extracting a borrowed scrutinee `t` (owner not consumed).
    * `drop`/`moveOut` of a `bref` FAULT ↔ `do_drop`'s `DropOfAlias` / the borrow-return rejection.
    * `use` of a `bref t` with `t` freed ↔ `UseAfterFree`.
    * owned peel (`moveOut` shell + `alloc` payloads) ↔ the consume-inferred `%1` peel Auto-Drop lowers.
-/

namespace AxionExtract

/-- A cell: unallocated; a live owner; freed; moved out (transferred); or `bref t`, an interior
    alias INTO owner `t` (a payload extracted from a BORROWED scrutinee). -/
inductive Cell where
  | fresh
  | live
  | freed
  | moved
  | bref (t : Nat)
  deriving DecidableEq, Repr

abbrev St := Nat → Cell

def upd (S : St) (n : Nat) (c : Cell) : St := fun m => if m = n then c else S m

/-- Operations. `borrow b t` binds `b` as an interior alias of the live owner `t` (extracting a
    payload from a borrowed scrutinee `t`). Owned-scrutinee extraction needs no new op — it is
    `moveOut` of the shell + `alloc` of each now-owned payload. -/
inductive Op where
  | alloc   (n : Nat)
  | use     (n : Nat)
  | drop    (n : Nat)
  | moveOut (n : Nat)
  | borrow  (b t : Nat)
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

/-- The faulting machine.
    * `use n`: `n` live, OR `n = bref t` with `t` still live (else UseAfterFree).
    * `drop n`: only a live OWNER; dropping a `bref` FAULTS (DropOfAlias — double-free of the owner).
    * `moveOut n`: only a live OWNER; moving/returning a `bref` FAULTS (borrow-escape).
    * `borrow b t`: `b` fresh and `t` a live owner ⇒ `b := bref t`. -/
def rstep (S : St) : Op → Option St
  | .alloc n    => match S n with | .fresh => some (upd S n .live) | _ => none
  | .use n      => match S n with
                     | .live   => some S
                     | .bref t => match S t with | .live => some S | _ => none
                     | _       => none
  | .drop n     => match S n with | .live => some (upd S n .freed) | _ => none
  | .moveOut n  => match S n with | .live => some (upd S n .moved) | _ => none
  | .borrow b t => match S b, S t with | .fresh, .live => some (upd S b (.bref t)) | _, _ => none

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
/-- Leak-free = no live OWNER remains. A `bref`/`moved`/`freed` is not a leak. -/
def leakFree (S : St) : Prop := ∀ n, S n ≠ .live
def accepts (e : Expr) : Prop := ∃ Sf, Chk sInit e Sf ∧ leakFree Sf

/-! ## Soundness — same progress + preservation skeleton as `AxionMove` (op-generic). -/

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

/-- **Soundness.** An accepted program, on EVERY path: never gets stuck (no double-free, no drop /
    move / use of a `bref`, no use-after-free, no re-alloc), and ends with no live owner (no leak). -/
theorem sound {e : Expr} (hacc : accepts e) :
    (∀ s, Star Step (sInit, e) s → ¬ Stuck s) ∧
    (∀ Sf', Star Step (sInit, e) (Sf', .done) → ∀ n, Sf' n ≠ .live) :=
  ⟨no_corruption hacc, no_leak hacc⟩

/-! ## Executable checker over a finite assoc-list state (the bridge core). Mirrors `AxionMove`. -/

def lookupC (n : Nat) : List (Nat × Cell) → Cell
  | [] => .fresh
  | (m, c) :: rest => if m = n then c else lookupC n rest

def toSt (l : List (Nat × Cell)) : St := fun n => lookupC n l
def setC (n : Nat) (c : Cell) (l : List (Nat × Cell)) : List (Nat × Cell) := (n, c) :: l
def keysOf (l : List (Nat × Cell)) : List Nat := l.map Prod.fst

theorem toSt_nil : toSt [] = sInit := rfl

theorem setC_toSt {n : Nat} {c : Cell} {l : List (Nat × Cell)} :
    toSt (setC n c l) = upd (toSt l) n c := by
  funext m
  show lookupC m ((n, c) :: l) = (if m = n then c else lookupC m l)
  simp only [lookupC]
  by_cases h : m = n
  · subst h; simp
  · rw [if_neg (fun heq : n = m => h heq.symm), if_neg h]

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
  | .alloc n    => match lookupC n l with | .fresh => some (setC n .live l) | _ => none
  | .use n      => match lookupC n l with
                     | .live   => some l
                     | .bref t => match lookupC t l with | .live => some l | _ => none
                     | _       => none
  | .drop n     => match lookupC n l with | .live => some (setC n .freed l) | _ => none
  | .moveOut n  => match lookupC n l with | .live => some (setC n .moved l) | _ => none
  | .borrow b t => match lookupC b l, lookupC t l with
                     | .fresh, .live => some (setC b (.bref t) l)
                     | _, _ => none

/-- The one bridge lemma: the finite step mirrors the abstract step, reflected through `toSt`.
    `use`'s nested match and `borrow`'s two-cell match are handled uniformly by `simp` case-splits
    (`toSt l n` is definitionally `lookupC n l`, so the equations `hc`/`ht`/`hb` rewrite both). -/
theorem rstep_map {l : List (Nat × Cell)} {a : Op} :
    rstep (toSt l) a = (rstepL l a).map toSt := by
  have e : ∀ n, toSt l n = lookupC n l := fun _ => rfl
  cases a with
  | alloc n => cases hc : lookupC n l <;> simp [rstep, rstepL, e, hc, Option.map, setC_toSt]
  | use n =>
    cases hc : lookupC n l with
    | bref t => cases ht : lookupC t l <;> simp [rstep, rstepL, e, hc, ht, Option.map]
    | live => simp [rstep, rstepL, e, hc, Option.map]
    | fresh => simp [rstep, rstepL, e, hc, Option.map]
    | freed => simp [rstep, rstepL, e, hc, Option.map]
    | moved => simp [rstep, rstepL, e, hc, Option.map]
  | drop n => cases hc : lookupC n l <;> simp [rstep, rstepL, e, hc, Option.map, setC_toSt]
  | moveOut n => cases hc : lookupC n l <;> simp [rstep, rstepL, e, hc, Option.map, setC_toSt]
  | borrow b t =>
    cases hb : lookupC b l <;> cases ht : lookupC t l <;>
      simp [rstep, rstepL, e, hb, ht, Option.map, setC_toSt]

theorem rstepL_sound {l l' : List (Nat × Cell)} {a : Op} (h : rstepL l a = some l') :
    rstep (toSt l) a = some (toSt l') := by
  rw [rstep_map, h]; rfl

theorem rstepL_complete {l : List (Nat × Cell)} {a : Op} {Sf : St}
    (h : rstep (toSt l) a = some Sf) : ∃ l', rstepL l a = some l' ∧ Sf = toSt l' := by
  rw [rstep_map] at h
  cases hrs : rstepL l a with
  | none => rw [hrs] at h; simp at h
  | some l' => rw [hrs] at h; simp only [Option.map_some] at h; exact ⟨l', rfl, (Option.some.inj h).symm⟩

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

/-- A program is accepted iff it checks from `[]` to a leak-free state. -/
def acceptsL (e : Expr) : Bool :=
  match chkL [] e with
  | some l => leakFreeL l
  | none => false

/-- **The bridge crux (extraction fragment).** The executable checker decides `accepts` exactly. -/
theorem chk_correct {e : Expr} : acceptsL e = true ↔ accepts e := by
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

/-! ## The extraction theorems — RUN by `rfl` (both `= true` and `= false` compute, so the checker
    genuinely discriminates), and each is memory-safe/leak-free by `chk_correct`+`sound`. -/

-- OWNED peel: consume the shell (`moveOut 0`), payload `1` becomes an owner, then freed. Accepted.
example : acceptsL (.op (.alloc 0) (.op (.moveOut 0) (.op (.alloc 1) (.op (.drop 1) .done)))) = true := rfl

-- BORROWED peel, read then free the owner: `use` the alias WHILE owner live, then `drop 0`. Accepted.
example : acceptsL (.op (.alloc 0) (.op (.borrow 1 0) (.op (.use 1) (.op (.drop 0) .done)))) = true := rfl

-- DropOfAlias: dropping the extracted alias `1` is a double-free of owner `0`. REJECTED.
example : acceptsL (.op (.alloc 0) (.op (.borrow 1 0) (.op (.drop 1) .done))) = false := rfl

-- Borrow-escape: moving/returning the alias `1` (the AX0912 class). REJECTED.
example : acceptsL (.op (.alloc 0) (.op (.borrow 1 0) (.op (.moveOut 1) (.op (.drop 0) .done)))) = false := rfl

-- UseAfterFree: free the owner `0`, then read the dangling alias `1`. REJECTED.
example : acceptsL (.op (.alloc 0) (.op (.borrow 1 0) (.op (.drop 0) (.op (.use 1) .done)))) = false := rfl

-- Branch divergence at extraction: one arm frees the owner, the other returns an alias of it →
-- the arms end in different states (freed vs bref), so the join rejects (V-1 conditional-return).
example : acceptsL (.op (.alloc 0) (.brn (.op (.drop 0) .done) (.op (.borrow 1 0) (.op (.moveOut 1) .done)) .done)) = false := rfl

-- Forgetting the owner is still a leak (a borrowed peel must still dispose the owner). REJECTED.
example : acceptsL (.op (.alloc 0) (.op (.borrow 1 0) (.op (.use 1) .done))) = false := rfl

/-! ## Axiom audit. -/
#print axioms sound
#print axioms chk_correct

end AxionExtract
