/-
  AxionDrop — mechanized metatheory for the Axión drop-balance verifier (`axionc/src/verify.rs`).

  Track 2 (docs/call-site-ownership.md §6 "Soundness"): the verifier is Axión's compile-time
  soundness ORACLE — it proves, over the final drop-inserted Core, that every heap resource is
  freed EXACTLY once and never used after free. Track 1 established that the verifier CATCHES the
  known bug classes (as findings). Track 2 turns the verifier's *own* judgment into a
  machine-checked theorem: **if the judgment accepts a program, its execution cannot double-free,
  cannot use-after-free, and cannot leak — on EVERY control-flow path.**

  This file mechanizes the judgment over a TREE-structured Core with branches (`if`/`case`): the
  straight-line let-sequence is the branch-free fragment. The soundness proof is the textbook
  progress + preservation over a small-step machine, so it quantifies over *every* branch path,
  not one. It is deliberately dependency-free (no Mathlib): the heap and the ownership set are
  total functions, so the whole development type-checks with a stock `lean` and contains no
  `sorry`/extra axioms.

  Correspondence to `verify.rs`:
    * `Status` / `Heap`            ↔ the runtime a `drop` acts on (a cell is Fresh → Live → Freed).
    * `Owned` (the judgment state) ↔ `Val { owned : bool }` tracked per variable in `Verifier`.
    * `Op.alloc`                   ↔ a producer (`MakeCon`/`RtCall` fresh) — `delta::Res` owned.
    * `Op.use`                     ↔ a borrow/read (`use_atom`) — requires the cell live (UAF check).
    * `Op.drop`                    ↔ `do_drop` — requires the cell live (DoubleFree/UAF check).
    * `Expr.brn`                   ↔ an `if`/`case` with two arms and a continuation.
    * `Chk.brn` (both arms → same `om`) ↔ `merge_vals` reconciling the arms: the merged state can
        soundly stand for BOTH runtime heaps only when the arms leave the same owned-set (the
        balance condition; an imbalance is exactly the conditional-param-return alias V-1 catches,
        and R-5's copy is what makes both arms balance so a real container branch is admitted).
    * `accepts` (final owned = ∅)  ↔ `leak_check` at a true function exit (AX0911 leak gate).
-/

namespace AxionDrop

/-- A heap cell's lifecycle. A resource is allocated once (`Fresh → Live`) and freed once
    (`Live → Freed`); any other transition is the corruption the verifier rules out. -/
inductive Status where
  | fresh   -- never allocated
  | live    -- allocated, not yet freed
  | freed   -- reclaimed
  | moved   -- transferred out (escaped): not this frame's responsibility, not a leak, not usable
  | borrowed -- a BORROWED param: readable, owned by the caller (who keeps it live for the call), so
             -- this frame never frees it and it is not a leak. `use` ok; `alloc`/`drop`/`moveOut` fault
  deriving DecidableEq, Repr

/-- The runtime heap: every variable id maps to the status of its cell. -/
abbrev Heap := Nat → Status

/-- The verifier's abstract state: is variable `n` an owned, still-live resource? Mirrors the
    `owned` bit of `Val` in `verify.rs`, tracked per bound variable. -/
abbrev Owned := Nat → Bool

/-- One operation of the drop-inserted Core, in ANF order. -/
inductive Op where
  | alloc (n : Nat)   -- bind a fresh resource to `n` (a producer)
  | use   (n : Nat)   -- read/borrow `n` (must be live)
  | drop  (n : Nat)   -- reclaim `n` (must be live)
  | moveOut (n : Nat) -- transfer `n` OUT (into a constructor / consuming call / return): it leaves
                      -- the owned-set (like `drop`), but is NOT freed here (`DeltaEffect.moves`)
  deriving Repr

/-- The tree-structured Core: a straight-line op followed by a continuation, a branch with two
    arms and a continuation (the shape `verify.rs` reconciles with `merge_vals`), or a tail. -/
inductive Expr where
  | done                          -- end of a path (a function tail / join leaf)
  | op   (a : Op) (k : Expr)      -- a straight-line op, then `k`
  | brn  (t e : Expr) (k : Expr)  -- branch on two arms `t`/`e`, then `k` from the merged state
  deriving Repr

/-! ## Operational semantics (the ground truth the verifier must approximate)

Single ops transform the heap and get STUCK (`none`) exactly on a memory fault. A branch is
resolved by a small-step machine (below) that may take either arm — so a theorem quantifying over
all reachable states covers every path. -/

def stepRun (h : Heap) : Op → Option Heap
  -- alloc is unsafe ONLY over a still-LIVE cell (that would abandon a live owner — a leak);
  -- allocating into a fresh OR freed cell is fine (a real allocator reuses freed memory).
  | .alloc n => if h n ≠ .live ∧ h n ≠ .borrowed then some (fun m => if m = n then .live else h m) else none
  | .use   n => if h n = .live ∨ h n = .borrowed then some h else none
  | .drop  n => if h n = .live  then some (fun m => if m = n then .freed else h m) else none
  -- moveOut: like drop it needs a live owner and removes ownership, but the cell becomes `moved`
  -- (transferred, live elsewhere) not `freed` — a subsequent use/drop still faults, and it is not a
  -- leak. `alloc` accepts a non-live cell, so a moved cell needs no full-state tracking at a join.
  | .moveOut n => if h n = .live then some (fun m => if m = n then .moved else h m) else none

/-- `seq t k` grafts the continuation `k` onto every tail (`done` leaf) of `t` — sequential
    composition. Running an arm then the continuation is running `seq arm k`. -/
def seq : Expr → Expr → Expr
  | .done,      k => k
  | .op a t',   k => .op a (seq t' k)
  | .brn a b t',k => .brn a b (seq t' k)

/-- Small-step machine over `(heap, remaining-expr)`. `op` runs one op (stuck if it faults); a
    branch nondeterministically enters either arm, grafting the continuation after it. -/
inductive Step : (Heap × Expr) → (Heap × Expr) → Prop where
  | op  {h a k h'} : stepRun h a = some h' → Step (h, .op a k) (h', k)
  | brL {h t e k}  : Step (h, .brn t e k) (h, seq t k)
  | brR {h t e k}  : Step (h, .brn t e k) (h, seq e k)

/-- Reflexive–transitive closure (defined locally to avoid a Mathlib/Batteries dependency). -/
inductive Star {α : Type} (R : α → α → Prop) : α → α → Prop where
  | refl {a} : Star R a a
  | step {a b c} : R a b → Star R b c → Star R a c

/-- The initial heap: the borrowed params (`B`) start `borrowed` (the caller owns them and keeps
    them live for the call), everything else `fresh`. -/
def h0 (B : Owned) : Heap := fun n => if B n then .borrowed else .fresh

/-! ## The verifier's judgment (the abstract interpreter of `verify.rs`)

`stepChk` is the per-op accept/reject transition on the owned-set (exactly `Verifier::term`'s
update: `alloc` REJECTS a re-alloc of a still-owned cell, `use`/`drop` require ownership, `drop`
removes it). `Chk o e o'` lifts it to a whole `Expr`, and at a `brn` REQUIRES both arms to reach
the SAME owned-set `om` before the continuation — the sound core of `merge_vals`. -/

def stepChk (B : Owned) (o : Owned) : Op → Option Owned
  | .alloc n => if o n || B n then none else some (fun m => if m = n then true else o m)
  | .use   n => if o n || B n then some o else none
  | .drop  n => if o n then some (fun m => if m = n then false else o m) else none
  -- moveOut leaves the owned-set exactly as `drop` does (the abstract state tracks ownership, and a
  -- moved value is no longer owned) — the sound core of `DeltaEffect.moves` leaving Δ.
  | .moveOut n => if o n then some (fun m => if m = n then false else o m) else none

inductive Chk (B : Owned) : Owned → Expr → Owned → Prop where
  | done {o} : Chk B o .done o
  | op   {o o' of a k} : stepChk B o a = some o' → Chk B o' k of → Chk B o (.op a k) of
  | brn  {o om of t e k} : Chk B o t om → Chk B o e om → Chk B om k of → Chk B o (.brn t e k) of

/-- A program is ACCEPTED (against a borrowed-param set `B`) iff the judgment admits it to a final
    owned-set that is empty — no violation on any arm, arms balanced at every join, and (owned)
    leak-free at exit. Borrowed cells are the caller's, so they need not be empty. -/
def accepts (B : Owned) (e : Expr) : Prop :=
  ∃ of, Chk B (fun _ => false) e of ∧ (∀ n, of n = false)

/-! ## Soundness

The coupling invariant: owned = exactly the live cells, and `B` = exactly the borrowed cells. -/

def Inv (B : Owned) (o : Owned) (h : Heap) : Prop :=
  (∀ n, o n = true ↔ h n = .live) ∧ (∀ n, B n = true ↔ h n = .borrowed)

theorem inv_init (B : Owned) : Inv B (fun _ => false) (h0 B) := by
  refine ⟨fun n => ?_, fun n => ?_⟩ <;>
    · simp only [h0]; by_cases hb : B n = true <;> simp [hb]

/-- The per-op core: an accepted op is a runtime op that preserves the invariant. `use` now also
    admits a borrowed cell (readable, caller-owned); `alloc` is forbidden over a borrowed cell. -/
theorem step_sound {B o : Owned} {h : Heap} (hinv : Inv B o h) :
    ∀ (a : Op) (o' : Owned), stepChk B o a = some o' →
      ∃ h', stepRun h a = some h' ∧ Inv B o' h' := by
  obtain ⟨hlive, hbor⟩ := hinv
  intro a o' hchk
  cases a with
  | alloc n =>
    simp only [stepChk] at hchk
    by_cases hn : o n || B n
    · simp [hn] at hchk
    · have hf : (o n || B n) = false := by simpa using hn
      obtain ⟨hon, hbn⟩ := Bool.or_eq_false_iff.mp hf
      simp only [hn, Bool.false_eq_true, if_false] at hchk
      have hnl : h n ≠ .live := fun hl => by rw [(hlive n).mpr hl] at hon; simp at hon
      have hnb : h n ≠ .borrowed := fun hl => by rw [(hbor n).mpr hl] at hbn; simp at hbn
      have ho' : o' = (fun m => if m = n then true else o m) := (Option.some.inj hchk).symm
      subst ho'
      refine ⟨fun m => if m = n then .live else h m, by simp [stepRun, hnl, hnb], ?_, ?_⟩
      · intro m; by_cases hm : m = n
        · subst hm; simp
        · simp only [if_neg hm]; exact hlive m
      · intro m; by_cases hm : m = n
        · subst hm; simp [hbn]
        · simp only [if_neg hm]; exact hbor m
  | use n =>
    simp only [stepChk] at hchk
    by_cases hn : o n || B n
    · simp only [hn, if_true] at hchk
      have hreach : h n = .live ∨ h n = .borrowed := by
        rcases Bool.or_eq_true_iff.mp (by simpa using hn) with ho | hb
        · exact Or.inl ((hlive n).mp ho)
        · exact Or.inr ((hbor n).mp hb)
      have ho' : o' = o := (Option.some.inj hchk).symm
      subst ho'
      exact ⟨h, by rcases hreach with h1 | h1 <;> simp [stepRun, h1], hlive, hbor⟩
    · simp [hn] at hchk
  | drop n =>
    simp only [stepChk] at hchk
    by_cases hn : o n
    · rw [if_pos hn] at hchk
      have hlv : h n = .live := (hlive n).mp hn
      have hbnf : B n = false := by
        cases hb : B n with
        | false => rfl
        | true =>
          have hcontra : h n = .borrowed := (hbor n).mp hb
          rw [hlv] at hcontra
          exact absurd hcontra (by simp)
      have ho' : o' = (fun m => if m = n then false else o m) := (Option.some.inj hchk).symm
      subst ho'
      refine ⟨fun m => if m = n then .freed else h m, by simp [stepRun, hlv], ?_, ?_⟩
      · intro m; by_cases hm : m = n
        · subst hm; simp
        · simp only [if_neg hm]; exact hlive m
      · intro m; by_cases hm : m = n
        · subst hm; simp [hbnf]
        · simp only [if_neg hm]; exact hbor m
    · rw [if_neg hn] at hchk; exact absurd hchk (by simp)
  | moveOut n =>
    simp only [stepChk] at hchk
    by_cases hn : o n
    · rw [if_pos hn] at hchk
      have hlv : h n = .live := (hlive n).mp hn
      have hbnf : B n = false := by
        cases hb : B n with
        | false => rfl
        | true =>
          have hcontra : h n = .borrowed := (hbor n).mp hb
          rw [hlv] at hcontra
          exact absurd hcontra (by simp)
      have ho' : o' = (fun m => if m = n then false else o m) := (Option.some.inj hchk).symm
      subst ho'
      refine ⟨fun m => if m = n then .moved else h m, by simp [stepRun, hlv], ?_, ?_⟩
      · intro m; by_cases hm : m = n
        · subst hm; simp
        · simp only [if_neg hm]; exact hlive m
      · intro m; by_cases hm : m = n
        · subst hm; simp [hbnf]
        · simp only [if_neg hm]; exact hbor m
    · rw [if_neg hn] at hchk; exact absurd hchk (by simp)

/-- The judgment composes over `seq`: if `t` takes `o` to `om` and `k` takes `om` to `of`, then
    `seq t k` takes `o` to `of`. (Used to type the machine state after a branch enters an arm.) -/
theorem chk_seq {B o om of : Owned} {t k : Expr}
    (h1 : Chk B o t om) (h2 : Chk B om k of) : Chk B o (seq t k) of := by
  induction h1 with
  | done => exact h2
  | op hs _ ih => exact Chk.op hs (ih h2)
  | brn ha hb _ _ _ ihk => exact Chk.brn ha hb (ihk h2)

/-- A machine state is WELL-TYPED (for a fixed final owned-set `of`) when some abstract state both
    admits the remaining expression to `of` and is coupled to the current heap. -/
def WT (B of : Owned) (s : Heap × Expr) : Prop :=
  ∃ o, Chk B o s.2 of ∧ Inv B o s.1

/-- **Preservation.** A machine step out of a well-typed state lands in a well-typed state. -/
theorem preservation {B of : Owned} {s s' : Heap × Expr}
    (hwt : WT B of s) (hstep : Step s s') : WT B of s' := by
  obtain ⟨o, hchk, hinv⟩ := hwt
  cases hstep with
  | op hrun =>
    -- s = (h, op a k), s' = (h', k); the op both checks and runs, preserving Inv.
    cases hchk with
    | op hchks hk =>
      obtain ⟨h'', hrun', hinv'⟩ := step_sound hinv _ _ hchks
      rw [hrun] at hrun'
      cases hrun'
      exact ⟨_, hk, hinv'⟩
  | brL =>
    -- entering the left arm: heap unchanged; the arm-then-continuation is well-typed via chk_seq.
    cases hchk with
    | brn ht _ hk => exact ⟨o, chk_seq ht hk, hinv⟩
  | brR =>
    cases hchk with
    | brn _ he hk => exact ⟨o, chk_seq he hk, hinv⟩

/-- **Progress.** A well-typed state is either finished (`done`) or can take a step — it is never
    stuck on a memory fault. -/
theorem progress {B of o : Owned} {h : Heap} {e : Expr}
    (hchk : Chk B o e of) (hinv : Inv B o h) : e = .done ∨ ∃ s', Step (h, e) s' := by
  cases hchk with
  | done => exact Or.inl rfl
  | op hchks _ =>
    obtain ⟨h', hrun, _⟩ := step_sound hinv _ _ hchks
    exact Or.inr ⟨(h', _), Step.op hrun⟩
  | brn _ _ _ => exact Or.inr ⟨(h, _), Step.brL⟩

/-- A stuck state: not finished, yet unable to step (a memory fault). -/
def Stuck (s : Heap × Expr) : Prop := s.2 ≠ .done ∧ ¬ ∃ s', Step s s'

/-- Well-typed states are never stuck (progress, repackaged). -/
theorem not_stuck {B of : Owned} {s : Heap × Expr} (hwt : WT B of s) : ¬ Stuck s := by
  obtain ⟨h, e⟩ := s
  obtain ⟨o, hchk, hinv⟩ := hwt
  rcases progress hchk hinv with hdone | hstep
  · rintro ⟨hne, _⟩; exact hne hdone
  · rintro ⟨_, hns⟩; exact hns hstep

/-- Well-typedness is preserved along any run. -/
theorem star_wt {B of : Owned} {s s' : Heap × Expr}
    (hwt : WT B of s) (hstar : Star Step s s') : WT B of s' := by
  induction hstar with
  | refl => exact hwt
  | step hstep _ ih => exact ih (preservation hwt hstep)

/-- **No corruption (on every path).** No state reachable from an accepted program is stuck — i.e.
    execution never double-frees, never uses-after-free, and never faults, whichever branches it
    takes. (Corresponds to the AX0910 hard gate.) -/
theorem no_corruption {B : Owned} {e : Expr} (hacc : accepts B e) :
    ∀ s, Star Step (h0 B, e) s → ¬ Stuck s := by
  obtain ⟨of, hchk, _⟩ := hacc
  intro s hstar
  exact not_stuck (star_wt (of := of) ⟨_, hchk, inv_init B⟩ hstar)

/-- A finished expression's incoming and final owned-sets coincide (the only `Chk _ done _`). -/
theorem chk_done_eq {B o of : Owned} (h : Chk B o .done of) : o = of := by cases h; rfl

/-- **No leak (on every path).** Whenever an accepted program reaches a finished state, its heap
    has NO live cell left — every OWNED resource was freed (a borrowed cell, the caller's, remains
    `borrowed` ≠ `live`, so it is correctly not a leak). (Corresponds to AX0911.) -/
theorem no_leak {B : Owned} {e : Expr} (hacc : accepts B e) :
    ∀ hf, Star Step (h0 B, e) (hf, .done) → ∀ n, hf n ≠ .live := by
  obtain ⟨of, hchk, hempty⟩ := hacc
  intro hf hstar
  obtain ⟨o, hchkd, hinv⟩ := star_wt (of := of) ⟨_, hchk, inv_init B⟩ hstar
  have hoeq : o = of := chk_done_eq hchkd
  intro n hln
  have hlive : o n = true := (hinv.1 n).mpr hln
  rw [hoeq, hempty n] at hlive
  simp at hlive

/-- **Full soundness.** Acceptance implies memory safety AND (owned) leak freedom on every path. -/
theorem sound {B : Owned} {e : Expr} (hacc : accepts B e) :
    (∀ s, Star Step (h0 B, e) s → ¬ Stuck s) ∧
    (∀ hf, Star Step (h0 B, e) (hf, .done) → ∀ n, hf n ≠ .live) :=
  ⟨no_corruption hacc, no_leak hacc⟩

/-! ## Non-vacuity — the judgment actually rejects the bugs (mirrors `verify.rs`'s buggy-Core unit
tests). Rather than fragile relation inversion, each rejection is proved by DOGFOODING the main
theorems: a program that faults or leaks on some path cannot be accepted (contrapositive of
`no_corruption` / `no_leak`). This also witnesses that the theorems have real bite. -/

/-- The heap after `alloc 0` from empty (cell 0 live), and after a further `drop 0` (cell 0 freed).
    Fully concrete, so every runtime transition below is proved by `rfl`. -/
private def emptyB : Owned := fun _ => false
private def hA : Heap := fun m => if m = 0 then .live else h0 emptyB m
private def hAD : Heap := fun m => if m = 0 then .freed else hA m
private theorem step_alloc0 : stepRun (h0 emptyB) (.alloc 0) = some hA := rfl
private theorem step_drop0  : stepRun hA (.drop 0)  = some hAD := rfl
private theorem drop0_stuck : stepRun hAD (.drop 0) = none := rfl
private theorem use0_stuck  : stepRun hAD (.use 0)  = none := rfl

/-- A double-free (`alloc 0; drop 0; drop 0`) is REJECTED — the second `drop 0` faults, so
    `no_corruption` forbids acceptance. -/
example : ¬ accepts emptyB (.op (.alloc 0) (.op (.drop 0) (.op (.drop 0) .done))) := by
  intro hacc
  have hstar : Star Step (h0 emptyB, .op (.alloc 0) (.op (.drop 0) (.op (.drop 0) .done)))
      (hAD, .op (.drop 0) .done) :=
    .step (Step.op step_alloc0) (.step (Step.op step_drop0) .refl)
  refine no_corruption hacc _ hstar ⟨by simp, ?_⟩
  rintro ⟨_, hs⟩
  cases hs with | op hr => rw [drop0_stuck] at hr; simp at hr

/-- A use-after-free (`alloc 0; drop 0; use 0`) is REJECTED — the `use 0` faults. -/
example : ¬ accepts emptyB (.op (.alloc 0) (.op (.drop 0) (.op (.use 0) .done))) := by
  intro hacc
  have hstar : Star Step (h0 emptyB, .op (.alloc 0) (.op (.drop 0) (.op (.use 0) .done)))
      (hAD, .op (.use 0) .done) :=
    .step (Step.op step_alloc0) (.step (Step.op step_drop0) .refl)
  refine no_corruption hacc _ hstar ⟨by simp, ?_⟩
  rintro ⟨_, hs⟩
  cases hs with | op hr => rw [use0_stuck] at hr; simp at hr

/-- **The new branch property.** UNBALANCED arms are REJECTED: `alloc 0; if _ then drop 0 else ()`
    frees cell 0 on ONE arm only, so the ELSE path finishes with 0 still live — a leak. -/
example : ¬ accepts emptyB (.op (.alloc 0) (.brn (.op (.drop 0) .done) .done .done)) := by
  intro hacc
  have hstar : Star Step (h0 emptyB, .op (.alloc 0) (.brn (.op (.drop 0) .done) .done .done)) (hA, .done) :=
    .step (Step.op step_alloc0) (.step Step.brR .refl)
  exact (no_leak hacc _ hstar 0) (rfl : hA 0 = .live)

/-- A balanced branching program IS accepted (`alloc 0; if _ then drop 0 else drop 0`). -/
example : accepts emptyB (.op (.alloc 0) (.brn (.op (.drop 0) .done) (.op (.drop 0) .done) .done)) := by
  refine ⟨_, Chk.op rfl (Chk.brn (Chk.op rfl Chk.done) (Chk.op rfl Chk.done) Chk.done), fun n => ?_⟩
  by_cases h : n = 0 <;> simp [h]

/-- **Borrowed params are usable but not owned.** With `B` marking cell 0 borrowed, `use 0` is
    accepted and 0 need not be freed (the caller owns it) — the shape of a function reading a
    borrowed heap parameter. -/
example : accepts (fun n => n == 0) (.op (.use 0) .done) := by
  refine ⟨fun _ => false, Chk.op ?_ Chk.done, fun _ => rfl⟩
  rfl

/-- **A borrowed param must NOT be dropped** (it is the caller's): `drop 0` on a borrowed 0 is
    rejected — `drop` requires ownership, and 0 is borrowed, not owned. -/
example : ¬ accepts (fun n => n == 0) (.op (.drop 0) .done) := by
  rintro ⟨of, hchk, _⟩
  cases hchk with
  | op hs _ => simp [stepChk] at hs

/-! ## Executable checker (M2 whole-fragment bridge core)

`Chk`/`accepts` are `Prop`s over `Owned = Nat → Bool` with existentials and a "false everywhere"
condition — neither is runnable. To let the faithfulness bridge run the model's *own* judgment on a
real program's Core (the `--emit model-trace` widening), we give an EXECUTABLE checker
`acceptsL : Expr → Bool` over a finite `List Nat` owned-set, and prove it decides `accepts` EXACTLY
(`chk_correct`). Running `acceptsL` is then as trustworthy as `sound`: its verdict provably equals
`accepts`, whose acceptance `sound` proves memory-safe and leak-free. -/

/-- Boolean membership in the executable owned-set (self-contained; no `BEq`-lemma dependence). -/
def memb (q : Nat) : List Nat → Bool
  | [] => false
  | x :: xs => if x = q then true else memb q xs

/-- Reflect an executable owned-list into the relational `Owned` predicate. -/
def toOwned (l : List Nat) : Owned := fun n => memb n l

/-- Remove every occurrence of `q` (the executable analogue of clearing the owned bit). -/
def rm (q : Nat) : List Nat → List Nat
  | [] => []
  | x :: xs => if x = q then rm q xs else x :: rm q xs

theorem memb_rm {m q : Nat} {l : List Nat} :
    memb m (rm q l) = (if m = q then false else memb m l) := by
  induction l with
  | nil => by_cases h : m = q <;> simp [rm, memb, h]
  | cons x xs ih =>
    by_cases hxq : x = q
    · -- rm q (x :: xs) = rm q xs  (drop the head)
      simp only [rm, if_pos hxq]
      rw [ih]
      by_cases hmq : m = q
      · simp only [if_pos hmq]
      · simp only [if_neg hmq, memb]
        have hxm : ¬ x = m := fun h => hmq (hxq.symm.trans h).symm
        rw [if_neg hxm]
    · -- rm q (x :: xs) = x :: rm q xs  (keep the head)
      simp only [rm, if_neg hxq, memb]
      rw [ih]
      by_cases hxm : x = m
      · have hmq : ¬ m = q := fun h => hxq (hxm.trans h)
        simp only [if_pos hxm, if_neg hmq]
      · simp only [if_neg hxm]

theorem toOwned_empty_iff {l : List Nat} : (∀ n, toOwned l n = false) ↔ l = [] := by
  constructor
  · intro h
    cases l with
    | nil => rfl
    | cons x xs =>
      have hx := h x
      simp [toOwned, memb] at hx
  · intro h n; subst h; rfl

/-- The executable owned-set is a set: subset by boolean membership. -/
def subsetL : List Nat → List Nat → Bool
  | [], _ => true
  | x :: xs, b => memb x b && subsetL xs b

def seteqL (a b : List Nat) : Bool := subsetL a b && subsetL b a

theorem subsetL_iff {a b : List Nat} :
    subsetL a b = true ↔ ∀ x, memb x a = true → memb x b = true := by
  induction a with
  | nil => simp [subsetL, memb]
  | cons y ys ih =>
    simp only [subsetL, Bool.and_eq_true, ih]
    constructor
    · rintro ⟨hy, hrest⟩ x hx
      simp only [memb] at hx
      by_cases hyx : y = x
      · rw [← hyx]; exact hy
      · rw [if_neg hyx] at hx; exact hrest x hx
    · intro h
      refine ⟨h y (by simp [memb]), fun x hx => ?_⟩
      apply h x
      simp only [memb]
      by_cases hyx : y = x
      · rw [if_pos hyx]
      · rw [if_neg hyx]; exact hx

theorem seteqL_toOwned {a b : List Nat} : seteqL a b = true ↔ toOwned a = toOwned b := by
  simp only [seteqL, Bool.and_eq_true, subsetL_iff]
  constructor
  · rintro ⟨hab, hba⟩
    funext n
    show memb n a = memb n b
    by_cases hna : memb n a = true
    · rw [hna, hab n hna]
    · simp only [Bool.not_eq_true] at hna
      by_cases hnb : memb n b = true
      · have := hba n hnb; rw [hna] at this; exact absurd this (by simp)
      · simp only [Bool.not_eq_true] at hnb; rw [hna, hnb]
  · intro h
    have hmem : ∀ n, memb n a = memb n b := fun n => by
      have := congrFun h n; simpa [toOwned] using this
    exact ⟨fun x hx => by rw [← hmem x]; exact hx, fun x hx => by rw [hmem x]; exact hx⟩

/-- Executable per-op transition, mirroring `stepChk` on the finite representation. `B` is the
    borrowed-param set: `use` also admits a borrowed cell, `alloc` is forbidden over one. -/
def stepChkL (B : List Nat) (o : List Nat) : Op → Option (List Nat)
  | .alloc n => if memb n o || memb n B then none else some (n :: o)
  | .use   n => if memb n o || memb n B then some o else none
  | .drop  n => if memb n o then some (rm n o) else none
  | .moveOut n => if memb n o then some (rm n o) else none

/-- Executable whole-`Expr` checker: same recursion shape as `Chk` (op → step then k; brn → both
    arms must reach the same owned-set, then k). -/
def chkL (B : List Nat) (o : List Nat) : Expr → Option (List Nat)
  | .done => some o
  | .op a k =>
      match stepChkL B o a with
      | some o' => chkL B o' k
      | none => none
  | .brn t e k =>
      match chkL B o t, chkL B o e with
      | some ot, some oe => if seteqL ot oe then chkL B ot k else none
      | _, _ => none

/-- A program is accepted by the executable checker (against borrowed set `B`) iff it checks from
    `[]` to the empty owned-set. -/
def acceptsL (B : List Nat) (e : Expr) : Bool :=
  match chkL B [] e with
  | some o => o.isEmpty
  | none => false

theorem toOwned_nil : toOwned ([] : List Nat) = (fun _ => false) := by funext n; rfl

theorem memb_cons {n : Nat} {o : List Nat} :
    toOwned (n :: o) = (fun m => if m = n then true else memb m o) := by
  funext m
  show memb m (n :: o) = if m = n then true else memb m o
  simp only [memb]
  by_cases h : m = n
  · subst h; simp
  · rw [if_neg (fun heq : n = m => h heq.symm), if_neg h]

theorem stepChkL_sound {B o o' : List Nat} {a : Op} (h : stepChkL B o a = some o') :
    stepChk (toOwned B) (toOwned o) a = some (toOwned o') := by
  cases a with
  | alloc n =>
    simp only [stepChkL] at h
    by_cases hn : (memb n o || memb n B) = true
    · rw [if_pos hn] at h; exact absurd h (by simp)
    · rw [if_neg hn] at h
      have ho : o' = n :: o := (Option.some.inj h).symm
      subst ho
      simp only [stepChk, toOwned]
      rw [if_neg hn, memb_cons]
  | use n =>
    simp only [stepChkL] at h
    by_cases hn : (memb n o || memb n B) = true
    · rw [if_pos hn] at h
      have ho : o' = o := (Option.some.inj h).symm
      subst ho
      simp only [stepChk, toOwned]; rw [if_pos hn]
    · rw [if_neg hn] at h; exact absurd h (by simp)
  | drop n =>
    simp only [stepChkL] at h
    by_cases hn : memb n o = true
    · rw [if_pos hn] at h
      have ho : o' = rm n o := (Option.some.inj h).symm
      subst ho
      simp only [stepChk]
      rw [if_pos (show toOwned o n = true from hn)]
      congr 1; funext m
      show (if m = n then false else memb m o) = memb m (rm n o)
      rw [memb_rm]
    · rw [if_neg hn] at h; exact absurd h (by simp)
  | moveOut n =>
    simp only [stepChkL] at h
    by_cases hn : memb n o = true
    · rw [if_pos hn] at h
      have ho : o' = rm n o := (Option.some.inj h).symm
      subst ho
      simp only [stepChk]
      rw [if_pos (show toOwned o n = true from hn)]
      congr 1; funext m
      show (if m = n then false else memb m o) = memb m (rm n o)
      rw [memb_rm]
    · rw [if_neg hn] at h; exact absurd h (by simp)

theorem stepChkL_complete {B o : List Nat} {a : Op} {ofn : Owned}
    (h : stepChk (toOwned B) (toOwned o) a = some ofn) :
    ∃ o', stepChkL B o a = some o' ∧ ofn = toOwned o' := by
  cases a with
  | alloc n =>
    simp only [stepChk, toOwned] at h
    by_cases hn : (memb n o || memb n B) = true
    · rw [if_pos hn] at h; exact absurd h (by simp)
    · rw [if_neg hn] at h
      refine ⟨n :: o, by simp only [stepChkL]; rw [if_neg hn], ?_⟩
      have hofn : ofn = (fun m => if m = n then true else memb m o) := (Option.some.inj h).symm
      rw [hofn, memb_cons]
  | use n =>
    simp only [stepChk, toOwned] at h
    by_cases hn : (memb n o || memb n B) = true
    · rw [if_pos hn] at h
      exact ⟨o, by simp only [stepChkL]; rw [if_pos hn], (Option.some.inj h).symm⟩
    · rw [if_neg hn] at h; exact absurd h (by simp)
  | drop n =>
    simp only [stepChk, toOwned] at h
    by_cases hn : memb n o = true
    · rw [if_pos hn] at h
      refine ⟨rm n o, by simp only [stepChkL]; rw [if_pos hn], ?_⟩
      have hofn : ofn = (fun m => if m = n then false else memb m o) := (Option.some.inj h).symm
      rw [hofn]; funext m
      show (if m = n then false else memb m o) = memb m (rm n o)
      rw [memb_rm]
    · rw [if_neg hn] at h; exact absurd h (by simp)
  | moveOut n =>
    simp only [stepChk, toOwned] at h
    by_cases hn : memb n o = true
    · rw [if_pos hn] at h
      refine ⟨rm n o, by simp only [stepChkL]; rw [if_pos hn], ?_⟩
      have hofn : ofn = (fun m => if m = n then false else memb m o) := (Option.some.inj h).symm
      rw [hofn]; funext m
      show (if m = n then false else memb m o) = memb m (rm n o)
      rw [memb_rm]
    · rw [if_neg hn] at h; exact absurd h (by simp)

theorem chkL_sound {B : List Nat} : ∀ {e : Expr} {o o' : List Nat},
    chkL B o e = some o' → Chk (toOwned B) (toOwned o) e (toOwned o') := by
  intro e
  induction e with
  | done =>
    intro o o' h; simp only [chkL] at h
    have : o = o' := Option.some.inj h; subst this; exact Chk.done
  | op a k ih =>
    intro o o' h
    simp only [chkL] at h
    cases hstep : stepChkL B o a with
    | none => rw [hstep] at h; simp at h
    | some o1 =>
      rw [hstep] at h
      exact Chk.op (stepChkL_sound hstep) (ih h)
  | brn t e2 k iht ihe2 ihk =>
    intro o o' h
    simp only [chkL] at h
    cases hct : chkL B o t with
    | none => rw [hct] at h; simp at h
    | some ot =>
      cases hce : chkL B o e2 with
      | none => rw [hct, hce] at h; simp at h
      | some oe =>
        rw [hct, hce] at h
        by_cases hse : seteqL ot oe = true
        · simp only [hse, if_true] at h
          have hteq : toOwned ot = toOwned oe := (seteqL_toOwned).mp hse
          refine Chk.brn (iht hct) ?_ (ihk h)
          rw [hteq]; exact ihe2 hce
        · simp only [hse, Bool.false_eq_true, if_false] at h; simp at h

theorem chkL_complete {B : List Nat} : ∀ {e : Expr} {o : List Nat} {ofn : Owned},
    Chk (toOwned B) (toOwned o) e ofn → ∃ o', chkL B o e = some o' ∧ ofn = toOwned o' := by
  intro e
  induction e with
  | done =>
    intro o ofn h
    cases h
    exact ⟨o, by simp [chkL], rfl⟩
  | op a k ih =>
    intro o ofn h
    cases h with
    | op hs hk =>
      obtain ⟨o1, hstep, ho1⟩ := stepChkL_complete hs
      rw [ho1] at hk
      obtain ⟨o', hck, hof⟩ := ih hk
      exact ⟨o', by simp only [chkL, hstep]; exact hck, hof⟩
  | brn t e2 k iht ihe2 ihk =>
    intro o ofn h
    cases h with
    | brn ht he hk =>
      obtain ⟨ot, hct, hot⟩ := iht ht
      obtain ⟨oe, hce, hoe⟩ := ihe2 he
      have hteq : toOwned ot = toOwned oe := by rw [← hot, ← hoe]
      have hse : seteqL ot oe = true := (seteqL_toOwned).mpr hteq
      rw [hot] at hk
      obtain ⟨o', hck, hof⟩ := ihk hk
      refine ⟨o', ?_, hof⟩
      simp only [chkL, hct, hce, hse, if_true]; exact hck

/-- **The bridge crux.** The executable checker decides `accepts` exactly — so running `acceptsL`
    on a real program's Core is as trustworthy as `sound`, which proves any accepted program
    memory-safe and leak-free. -/
theorem chk_correct {B : List Nat} {e : Expr} : acceptsL B e = true ↔ accepts (toOwned B) e := by
  constructor
  · intro h
    simp only [acceptsL] at h
    cases hc : chkL B [] e with
    | none => rw [hc] at h; simp at h
    | some o =>
      rw [hc] at h
      have ho : o = [] := by cases o with | nil => rfl | cons _ _ => simp [List.isEmpty] at h
      subst ho
      have hchk := chkL_sound hc
      rw [toOwned_nil] at hchk
      exact ⟨fun _ => false, hchk, fun _ => rfl⟩
  · rintro ⟨of, hchk, hempty⟩
    rw [show (fun _ => false) = toOwned ([] : List Nat) from (toOwned_nil).symm] at hchk
    obtain ⟨o', hc, hof⟩ := chkL_complete hchk
    have hall : ∀ n, toOwned o' n = false := fun n => by rw [← hof]; exact hempty n
    have ho : o' = [] := toOwned_empty_iff.mp hall
    simp only [acceptsL, hc, ho, List.isEmpty]

/-- The executable checker genuinely RUNS (decided by `rfl`), now with borrowed params. The `[]`
    borrowed-set cases match the `accepts`-level dogfood examples above; the `[0]` cases show a
    borrowed param 0 is usable but not droppable. -/
example : acceptsL [] (.op (.alloc 0) (.brn (.op (.drop 0) .done) (.op (.drop 0) .done) .done)) = true := rfl
example : acceptsL [] (.op (.alloc 0) (.op (.drop 0) (.op (.drop 0) .done))) = false := rfl
example : acceptsL [] (.op (.alloc 0) (.op (.drop 0) (.op (.use 0) .done))) = false := rfl
-- moveOut (escape) is accepted, and — crucially — a branch whose arms move out DIFFERENT numbers
-- of temporaries still balances (both leave the owned-set empty), matching `verify.rs`'s owned-set
-- merge: the `build n = if _ then LNil else LCons n (build (n-1))` shape.
example : acceptsL [] (.op (.alloc 0) (.op (.moveOut 0) .done)) = true := rfl
example : acceptsL [] (.brn (.op (.alloc 0) (.op (.moveOut 0) .done))
    (.op (.alloc 0) (.op (.moveOut 0) (.op (.alloc 1) (.op (.moveOut 1) .done)))) .done) = true := rfl
-- use-after-move and drop-after-move are still rejected (moved ≠ owned).
example : acceptsL [] (.op (.alloc 0) (.op (.moveOut 0) (.op (.use 0) .done))) = false := rfl
example : acceptsL [] (.op (.alloc 0) (.brn (.op (.drop 0) .done) .done .done)) = false := rfl
-- BORROWED param 0: reading it is accepted (used, never freed); dropping it is rejected.
example : acceptsL [0] (.op (.use 0) .done) = true := rfl
example : acceptsL [0] (.op (.use 0) (.op (.use 0) .done)) = true := rfl
example : acceptsL [0] (.op (.drop 0) .done) = false := rfl
-- a borrowed param plus a local owned temp that IS freed: accepted.
example : acceptsL [0] (.op (.use 0) (.op (.alloc 1) (.op (.drop 1) .done))) = true := rfl

/-! ## Axiom audit — the soundness theorems depend only on Lean's standard axioms, never on
`sorryAx`. `check.sh` greps this output to gate the build. -/
#print axioms sound
#print axioms no_corruption
#print axioms no_leak
#print axioms preservation
#print axioms progress
#print axioms chk_correct

end AxionDrop
