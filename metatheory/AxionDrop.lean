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
  | .alloc n => if h n ≠ .live then some (fun m => if m = n then .live else h m) else none
  | .use   n => if h n = .live  then some h else none
  | .drop  n => if h n = .live  then some (fun m => if m = n then .freed else h m) else none

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

/-- The initial heap: nothing allocated yet. -/
def h0 : Heap := fun _ => .fresh

/-! ## The verifier's judgment (the abstract interpreter of `verify.rs`)

`stepChk` is the per-op accept/reject transition on the owned-set (exactly `Verifier::term`'s
update: `alloc` REJECTS a re-alloc of a still-owned cell, `use`/`drop` require ownership, `drop`
removes it). `Chk o e o'` lifts it to a whole `Expr`, and at a `brn` REQUIRES both arms to reach
the SAME owned-set `om` before the continuation — the sound core of `merge_vals`. -/

def stepChk (o : Owned) : Op → Option Owned
  | .alloc n => if o n then none else some (fun m => if m = n then true else o m)
  | .use   n => if o n then some o else none
  | .drop  n => if o n then some (fun m => if m = n then false else o m) else none

inductive Chk : Owned → Expr → Owned → Prop where
  | done {o} : Chk o .done o
  | op   {o o' of a k} : stepChk o a = some o' → Chk o' k of → Chk o (.op a k) of
  | brn  {o om of t e k} : Chk o t om → Chk o e om → Chk om k of → Chk o (.brn t e k) of

/-- A program is ACCEPTED from the empty state iff the judgment admits it to a final owned-set that
    is empty — no violation on any arm, arms balanced at every join, and leak-free at exit. -/
def accepts (e : Expr) : Prop :=
  ∃ of, Chk (fun _ => false) e of ∧ (∀ n, of n = false)

/-! ## Soundness

The coupling invariant: the abstract owned-set is EXACTLY the set of live heap cells. -/

def Inv (o : Owned) (h : Heap) : Prop := ∀ n, (o n = true ↔ h n = .live)

theorem inv_init : Inv (fun _ => false) h0 := by
  intro n; simp [h0]

/-- The per-op core: an accepted op is a runtime op that preserves the invariant (drops/uses only
    live cells → no double-free / UAF; alloc only over a non-live cell). -/
theorem step_sound {o : Owned} {h : Heap} (hinv : Inv o h) :
    ∀ (a : Op) (o' : Owned), stepChk o a = some o' →
      ∃ h', stepRun h a = some h' ∧ Inv o' h' := by
  intro a o' hchk
  cases a with
  | alloc n =>
    simp only [stepChk] at hchk
    by_cases hn : o n
    · simp [hn] at hchk
    · simp [hn] at hchk
      have hnl : h n ≠ .live := fun hl => by simp [(hinv n).mpr hl] at hn
      refine ⟨fun m => if m = n then .live else h m, ?_, ?_⟩
      · simp [stepRun, hnl]
      · subst hchk
        intro m
        by_cases hm : m = n <;> simp [hm]
        exact hinv m
  | use n =>
    simp only [stepChk] at hchk
    by_cases hn : o n
    · simp [hn] at hchk
      have hlive : h n = .live := (hinv n).mp hn
      refine ⟨h, ?_, ?_⟩
      · simp [stepRun, hlive]
      · subst hchk; exact hinv
    · simp [hn] at hchk
  | drop n =>
    simp only [stepChk] at hchk
    by_cases hn : o n
    · simp [hn] at hchk
      have hlive : h n = .live := (hinv n).mp hn
      refine ⟨fun m => if m = n then .freed else h m, ?_, ?_⟩
      · simp [stepRun, hlive]
      · subst hchk
        intro m
        by_cases hm : m = n <;> simp [hm]
        exact hinv m
    · simp [hn] at hchk

/-- The judgment composes over `seq`: if `t` takes `o` to `om` and `k` takes `om` to `of`, then
    `seq t k` takes `o` to `of`. (Used to type the machine state after a branch enters an arm.) -/
theorem chk_seq {o om of : Owned} {t k : Expr}
    (h1 : Chk o t om) (h2 : Chk om k of) : Chk o (seq t k) of := by
  induction h1 with
  | done => exact h2
  | op hs _ ih => exact Chk.op hs (ih h2)
  | brn ha hb _ _ _ ihk => exact Chk.brn ha hb (ihk h2)

/-- A machine state is WELL-TYPED (for a fixed final owned-set `of`) when some abstract state both
    admits the remaining expression to `of` and is coupled to the current heap. -/
def WT (of : Owned) (s : Heap × Expr) : Prop :=
  ∃ o, Chk o s.2 of ∧ Inv o s.1

/-- **Preservation.** A machine step out of a well-typed state lands in a well-typed state. -/
theorem preservation {of : Owned} {s s' : Heap × Expr}
    (hwt : WT of s) (hstep : Step s s') : WT of s' := by
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
theorem progress {of o : Owned} {h : Heap} {e : Expr}
    (hchk : Chk o e of) (hinv : Inv o h) : e = .done ∨ ∃ s', Step (h, e) s' := by
  cases hchk with
  | done => exact Or.inl rfl
  | op hchks _ =>
    obtain ⟨h', hrun, _⟩ := step_sound hinv _ _ hchks
    exact Or.inr ⟨(h', _), Step.op hrun⟩
  | brn _ _ _ => exact Or.inr ⟨(h, _), Step.brL⟩

/-- A stuck state: not finished, yet unable to step (a memory fault). -/
def Stuck (s : Heap × Expr) : Prop := s.2 ≠ .done ∧ ¬ ∃ s', Step s s'

/-- Well-typed states are never stuck (progress, repackaged). -/
theorem not_stuck {of : Owned} {s : Heap × Expr} (hwt : WT of s) : ¬ Stuck s := by
  obtain ⟨h, e⟩ := s
  obtain ⟨o, hchk, hinv⟩ := hwt
  rcases progress hchk hinv with hdone | hstep
  · rintro ⟨hne, _⟩; exact hne hdone
  · rintro ⟨_, hns⟩; exact hns hstep

/-- Well-typedness is preserved along any run. -/
theorem star_wt {of : Owned} {s s' : Heap × Expr}
    (hwt : WT of s) (hstar : Star Step s s') : WT of s' := by
  induction hstar with
  | refl => exact hwt
  | step hstep _ ih => exact ih (preservation hwt hstep)

/-- **No corruption (on every path).** No state reachable from an accepted program is stuck — i.e.
    execution never double-frees, never uses-after-free, and never faults, whichever branches it
    takes. (Corresponds to the AX0910 hard gate.) -/
theorem no_corruption {e : Expr} (hacc : accepts e) :
    ∀ s, Star Step (h0, e) s → ¬ Stuck s := by
  obtain ⟨of, hchk, _⟩ := hacc
  intro s hstar
  exact not_stuck (star_wt (of := of) ⟨_, hchk, inv_init⟩ hstar)

/-- A finished expression's incoming and final owned-sets coincide (the only `Chk _ done _`). -/
theorem chk_done_eq {o of : Owned} (h : Chk o .done of) : o = of := by cases h; rfl

/-- **No leak (on every path).** Whenever an accepted program reaches a finished state, its heap
    has NO live cell left — every allocated resource was freed. (Corresponds to AX0911.) -/
theorem no_leak {e : Expr} (hacc : accepts e) :
    ∀ hf, Star Step (h0, e) (hf, .done) → ∀ n, hf n ≠ .live := by
  obtain ⟨of, hchk, hempty⟩ := hacc
  intro hf hstar
  obtain ⟨o, hchkd, hinv⟩ := star_wt (of := of) ⟨_, hchk, inv_init⟩ hstar
  have hoeq : o = of := chk_done_eq hchkd
  intro n hln
  have hlive : o n = true := (hinv n).mpr hln
  rw [hoeq, hempty n] at hlive
  simp at hlive

/-- **Full soundness.** Acceptance implies memory safety AND leak freedom on every path — the
    machine-checked statement of what `axionc`'s drop-verifier guarantees, now including branches. -/
theorem sound {e : Expr} (hacc : accepts e) :
    (∀ s, Star Step (h0, e) s → ¬ Stuck s) ∧
    (∀ hf, Star Step (h0, e) (hf, .done) → ∀ n, hf n ≠ .live) :=
  ⟨no_corruption hacc, no_leak hacc⟩

/-! ## Non-vacuity — the judgment actually rejects the bugs (mirrors `verify.rs`'s buggy-Core unit
tests). Rather than fragile relation inversion, each rejection is proved by DOGFOODING the main
theorems: a program that faults or leaks on some path cannot be accepted (contrapositive of
`no_corruption` / `no_leak`). This also witnesses that the theorems have real bite. -/

/-- The heap after `alloc 0` from empty (cell 0 live), and after a further `drop 0` (cell 0 freed).
    Fully concrete, so every runtime transition below is proved by `rfl`. -/
private def hA : Heap := fun m => if m = 0 then .live else h0 m
private def hAD : Heap := fun m => if m = 0 then .freed else hA m
private theorem step_alloc0 : stepRun h0 (.alloc 0) = some hA := rfl
private theorem step_drop0  : stepRun hA (.drop 0)  = some hAD := rfl
private theorem drop0_stuck : stepRun hAD (.drop 0) = none := rfl
private theorem use0_stuck  : stepRun hAD (.use 0)  = none := rfl

/-- A double-free (`alloc 0; drop 0; drop 0`) is REJECTED — the second `drop 0` faults, so
    `no_corruption` forbids acceptance. -/
example : ¬ accepts (.op (.alloc 0) (.op (.drop 0) (.op (.drop 0) .done))) := by
  intro hacc
  have hstar : Star Step (h0, .op (.alloc 0) (.op (.drop 0) (.op (.drop 0) .done)))
      (hAD, .op (.drop 0) .done) :=
    .step (Step.op step_alloc0) (.step (Step.op step_drop0) .refl)
  refine no_corruption hacc _ hstar ⟨by simp, ?_⟩
  rintro ⟨_, hs⟩
  cases hs with | op hr => rw [drop0_stuck] at hr; simp at hr

/-- A use-after-free (`alloc 0; drop 0; use 0`) is REJECTED — the `use 0` faults. -/
example : ¬ accepts (.op (.alloc 0) (.op (.drop 0) (.op (.use 0) .done))) := by
  intro hacc
  have hstar : Star Step (h0, .op (.alloc 0) (.op (.drop 0) (.op (.use 0) .done)))
      (hAD, .op (.use 0) .done) :=
    .step (Step.op step_alloc0) (.step (Step.op step_drop0) .refl)
  refine no_corruption hacc _ hstar ⟨by simp, ?_⟩
  rintro ⟨_, hs⟩
  cases hs with | op hr => rw [use0_stuck] at hr; simp at hr

/-- **The new branch property.** UNBALANCED arms are REJECTED: `alloc 0; if _ then drop 0 else ()`
    frees cell 0 on ONE arm only, so the ELSE path finishes with 0 still live — a leak — and
    `no_leak` forbids acceptance. This is the sound core of `merge_vals` (an imbalance is the
    conditional-param-return alias class V-1 catches; R-5's deep-copy is what makes a real
    container branch balance so both arms leave the same owned-set). -/
example : ¬ accepts (.op (.alloc 0) (.brn (.op (.drop 0) .done) .done .done)) := by
  intro hacc
  -- take the ELSE arm: alloc 0, then brR into `done`, grafted with the `done` continuation.
  have hstar : Star Step (h0, .op (.alloc 0) (.brn (.op (.drop 0) .done) .done .done)) (hA, .done) :=
    .step (Step.op step_alloc0) (.step Step.brR .refl)
  exact (no_leak hacc _ hstar 0) (rfl : hA 0 = .live)

/-- A balanced branching program IS accepted (`alloc 0; if _ then drop 0 else drop 0`): the theorem
    is non-trivially inhabited over branches too. -/
example : accepts (.op (.alloc 0) (.brn (.op (.drop 0) .done) (.op (.drop 0) .done) .done)) := by
  refine ⟨_, Chk.op rfl (Chk.brn (Chk.op rfl Chk.done) (Chk.op rfl Chk.done) Chk.done), fun n => ?_⟩
  by_cases h : n = 0 <;> simp [h]

/-! ## Axiom audit — the soundness theorems depend only on Lean's standard axioms, never on
`sorryAx`. `check.sh` greps this output to gate the build. -/
#print axioms sound
#print axioms no_corruption
#print axioms no_leak
#print axioms preservation
#print axioms progress

end AxionDrop
