/-
  AxionKey — the drop-key cross-check slice of the Axión drop-verifier metatheory (Track 2).

  `verify.rs`'s `do_drop` doesn't only check that a value is freed once — it cross-checks that the
  `Drop(v, key)` reclaimer MATCHES v's type (`WrongDropKey`): a boxed `Integer` must be freed by
  `axion_bignum_free`, a `String` by `axion_str_drop`, a `List$Int` by `axion_drop_List$Int`.
  Freeing a value with the WRONG key is a bad-free — heap corruption ("free on address not
  malloc'd", or a flat free of a structured block). This is the class that caused the multi-param
  mis-key bug (`Either Int Int`, the `cond_elem_key` split) that V-2 was built to catch.

  This slice tags every owned cell with a TYPE and every `drop` with the reclaimer KEY it will use.
  The machine faults on a key/type mismatch; the checker rejects it. As in the alias slice the
  abstraction is exact (the checker tracks the value's type, exactly as `Val`'s drop key does), so
  the content is: the key-match rule ⟹ the machine never bad-frees, on every path — plus the branch
  interaction, where a value of DIFFERENT types on two arms has no single correct reclaimer, so the
  arm-balance rejects any drop of it.

  Correspondence to `verify.rs`:
    * `Cell.live ty`            ↔ an owned value of drop-type `ty` (`Val.key`).
    * `Op.drop n key`           ↔ `Drop(n, key)` — the reclaimer the emitted Core will call.
    * a key/type mismatch fault ↔ `do_drop` flagging `WrongDropKey` (the V-2 scalar/base-key check
                                   and its container generalization `ctor_base`).
    * `Chk.brn` (arms agree)    ↔ `merge_vals`: a value must have the SAME type on both arms to be
                                   soundly droppable after the join.
-/

namespace AxionKey

/-- Type tags (`Val` drop keys), abstract — any number of distinct types. -/
abbrev Ty := Nat

/-- A cell: unallocated, a live owner of a value of type `ty`, or freed. -/
inductive Cell where
  | fresh
  | live (ty : Ty)
  | freed
  deriving DecidableEq, Repr

abbrev St := Nat → Cell

def upd (S : St) (n : Nat) (c : Cell) : St := fun m => if m = n then c else S m

/-- Operations. `alloc n ty` binds a fresh owner of type `ty`; `drop n key` frees `n` using the
    reclaimer `key` — a bad-free if `key` ≠ `n`'s type. -/
inductive Op where
  | alloc (n : Nat) (ty : Ty)
  | use   (n : Nat)
  | drop  (n : Nat) (key : Ty)
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

/-- The faulting machine. `drop n key` succeeds only when `n` is a live owner AND `key` matches its
    type; a wrong key (or dropping a non-owner) FAULTS — the bad-free `WrongDropKey` rules out. -/
def rstep (S : St) : Op → Option St
  | .alloc n ty => match S n with | .fresh => some (upd S n (.live ty)) | _ => none
  | .use n      => match S n with | .live _ => some S | _ => none
  | .drop n key => match S n with
                   | .live ty => if key = ty then some (upd S n .freed) else none
                   | _ => none

inductive Step : (St × Expr) → (St × Expr) → Prop where
  | op  {S a k S'} : rstep S a = some S' → Step (S, .op a k) (S', k)
  | brL {S t e k}  : Step (S, .brn t e k) (S, seq t k)
  | brR {S t e k}  : Step (S, .brn t e k) (S, seq e k)

inductive Star {α : Type} (R : α → α → Prop) : α → α → Prop where
  | refl {a} : Star R a a
  | step {a b c} : R a b → Star R b c → Star R a c

/-- The verifier's judgment (exact abstraction): threads `rstep`, and at a branch requires both
    arms to reach the SAME state — so a value must have the same TYPE on both arms to be droppable
    after the join (the `merge_vals` reconciliation of `Val.key`). -/
inductive Chk : St → Expr → St → Prop where
  | done {S} : Chk S .done S
  | op   {S S' Sf a k} : rstep S a = some S' → Chk S' k Sf → Chk S (.op a k) Sf
  | brn  {S Sm Sf t e k} : Chk S t Sm → Chk S e Sm → Chk Sm k Sf → Chk S (.brn t e k) Sf

def sInit : St := fun _ => .fresh
def leakFree (S : St) : Prop := ∀ n ty, S n ≠ .live ty
def accepts (e : Expr) : Prop := ∃ Sf, Chk sInit e Sf ∧ leakFree Sf

/-! ## Soundness (progress + preservation), identical skeleton to the other slices. -/

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

/-- **No corruption (on every path).** No reachable state is stuck — no double-free, and no
    bad-free from a mismatched reclaimer key (`WrongDropKey`), whichever branches run. -/
theorem no_corruption {e : Expr} (hacc : accepts e) :
    ∀ s, Star Step (sInit, e) s → ¬ Stuck s := by
  obtain ⟨Sf, hchk, _⟩ := hacc
  intro s hstar
  exact not_stuck (star_wt (Sf := Sf) hstar hchk)

/-- **No leak (on every path).** -/
theorem no_leak {e : Expr} (hacc : accepts e) :
    ∀ Sf', Star Step (sInit, e) (Sf', .done) → ∀ n ty, Sf' n ≠ .live ty := by
  obtain ⟨Sf, hchk, hleak⟩ := hacc
  intro Sf' hstar
  have hwt : WT Sf (Sf', .done) := star_wt (Sf := Sf) hstar hchk
  have : Sf' = Sf := chk_done_eq hwt
  rw [this]; exact hleak

theorem sound {e : Expr} (hacc : accepts e) :
    (∀ s, Star Step (sInit, e) s → ¬ Stuck s) ∧
    (∀ Sf', Star Step (sInit, e) (Sf', .done) → ∀ n ty, Sf' n ≠ .live ty) :=
  ⟨no_corruption hacc, no_leak hacc⟩

/-- A successful `drop` step forces the reclaimer key to match the cell's type. -/
theorem drop_ok {S : St} {n key : Nat} {S' : St}
    (h : rstep S (.drop n key) = some S') : ∃ ty, S n = .live ty ∧ key = ty := by
  simp only [rstep] at h
  split at h
  · next ty heq =>
      split at h
      · next hk => exact ⟨ty, heq, hk⟩
      · next hk => exact absurd h (by simp)
  · next => exact absurd h (by simp)

/-- **No bad-free (the `WrongDropKey` guarantee).** Whenever an accepted program reaches a point
    about to `drop n key`, the cell `n` is live and `key` is exactly its type — the emitted
    reclaimer always matches the value's type, on every path. -/
theorem no_bad_free {e : Expr} (hacc : accepts e) :
    ∀ S n key rest, Star Step (sInit, e) (S, .op (.drop n key) rest) →
      ∃ ty, S n = .live ty ∧ key = ty := by
  obtain ⟨Sf, hchk, _⟩ := hacc
  intro S n key rest hstar
  have hwt : WT Sf (S, .op (.drop n key) rest) := star_wt (Sf := Sf) hstar hchk
  cases hwt with
  | op hr _ => exact drop_ok hr

/-! ## Non-vacuity (dogfooding the theorems). Two type tags: `0` and `1`. -/

private def SA : St := upd sInit 0 (.live 0)   -- after `alloc 0 (ty 0)`
private def SB : St := upd sInit 0 (.live 1)   -- after `alloc 0 (ty 1)`

/-- **WrongDropKey is rejected.** `alloc 0 : ty0; drop 0 with key ty1` — the reclaimer doesn't
    match the value's type, so it faults (a bad-free) and cannot be accepted. -/
theorem wrong_key_drop_rejected :
    ¬ accepts (.op (.alloc 0 0) (.op (.drop 0 1) .done)) := by
  intro hacc
  have hstar : Star Step (sInit, .op (.alloc 0 0) (.op (.drop 0 1) .done)) (SA, .op (.drop 0 1) .done) :=
    .step (Step.op (rfl : rstep sInit (.alloc 0 0) = some SA)) .refl
  refine no_corruption hacc _ hstar ⟨by decide, ?_⟩
  rintro ⟨_, hs⟩
  cases hs with | op hr => rw [(rfl : rstep SA (.drop 0 1) = none)] at hr; contradiction

/-- A correctly-keyed program IS accepted (`alloc 0 : ty0; drop 0 with key ty0`). -/
theorem correct_key_accepted : accepts (.op (.alloc 0 0) (.op (.drop 0 0) .done)) := by
  refine ⟨_, Chk.op rfl (Chk.op rfl Chk.done), ?_⟩
  intro n ty
  by_cases h0 : n = 0
  · subst h0; simp [upd]
  · simp [upd, sInit, h0]

/-- **The branch interaction.** A value with DIFFERENT types on the two arms (`if _ then alloc :ty0
    else alloc :ty1`) has no single correct reclaimer, so any `drop` of it after the join is
    rejected: on the arm whose type mismatches the chosen key, the drop bad-frees. -/
theorem heterogeneous_branch_drop_rejected :
    ¬ accepts (.brn (.op (.alloc 0 0) .done) (.op (.alloc 0 1) .done) (.op (.drop 0 0) .done)) := by
  intro hacc
  -- take the ELSE arm (type 1), then the drop uses key 0 → mismatch → fault.
  have hstar : Star Step
      (sInit, .brn (.op (.alloc 0 0) .done) (.op (.alloc 0 1) .done) (.op (.drop 0 0) .done))
      (SB, .op (.drop 0 0) .done) :=
    .step Step.brR (.step (Step.op (rfl : rstep sInit (.alloc 0 1) = some SB)) .refl)
  refine no_corruption hacc _ hstar ⟨by decide, ?_⟩
  rintro ⟨_, hs⟩
  cases hs with | op hr => rw [(rfl : rstep SB (.drop 0 0) = none)] at hr; contradiction

/-! ## Axiom audit. -/
#print axioms sound
#print axioms no_corruption
#print axioms no_bad_free
#print axioms wrong_key_drop_rejected
#print axioms heterogeneous_branch_drop_rejected

end AxionKey
