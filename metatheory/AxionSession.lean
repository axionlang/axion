/-
  AxionSession — the deadlock-freedom slice of the Axión concurrency metatheory (Track 2 / the
  Axión Session Calculus, docs/phase-3-calculus.md §6).

  The session runtime is implemented and runs (the `session_run_*` fixtures: bound/spawn/send/recv/
  offer/cancel over the M:N scheduler, all leak-free), and the frontend enforces the calculus's
  structural invariants:
    * `AX0302` — an endpoint may not escape its `bound` nursery (CONFINEMENT), and
    * `AX0305` — `spawn` only creates a parent↔child edge (a FOREST, not a free `go`),
  so the communication graph is acyclic by construction (§9: the tree of cuts). But the §6
  metatheory theorems are stated as a contract, not mechanized. This file discharges the reachable,
  graph-structural rung of that ladder — **T2 (Progress) + T4 (Deadlock-freedom)** — in stock Lean
  (no Iris/Actris, which §6 defers to the medium term for the separation-logic theorems T1/T3/T5).

  The claim (calculus §0, §6-T4): "deadlock-freedom is a corollary of acyclicity / cut-elimination."
  We model a configuration's WAITS-FOR graph and prove: an acyclic waits-for graph over active
  threads always has a RUNNABLE thread — so the configuration can step (T2) and can never be
  deadlocked (T4). Acyclicity is witnessed by a rank (a topological order of the cut-tree; the
  depth `spawn` assigns), exactly the forest the confinement checks guarantee.
-/

namespace AxionSession

abbrev Tid := Nat

/-- A configuration: the currently ACTIVE (non-terminated) threads. Each is RUNNABLE (`waits i =
    none` — it can take a step) or BLOCKED on a peer's dual action (`waits i = some peer`). `rank`
    witnesses acyclicity of the waits-for graph: a blocked thread's peer has strictly smaller rank
    (a topological order of the forest `bound`/`spawn` build). `peer_live` is session fidelity: a
    blocked thread waits on a still-active peer (its endpoint's owner hasn't vanished). -/
structure Config where
  live      : List Tid
  waits     : Tid → Option Tid
  rank      : Tid → Nat
  acyclic   : ∀ i j, waits i = some j → rank j < rank i
  peer_live : ∀ i j, i ∈ live → waits i = some j → j ∈ live

/-- A thread can take a step iff it is not blocked. -/
def runnable (c : Config) (i : Tid) : Prop := c.waits i = none

/-- DEADLOCK: active work remains, yet NO thread is runnable (all blocked, waiting on each other).
    Deadlock-freedom is the statement that an acyclic configuration is never in this state. -/
def deadlocked (c : Config) : Prop := c.live ≠ [] ∧ ∀ i ∈ c.live, ¬ runnable c i

/-- A nonempty list has an element of minimal `rank` (stock Lean, no Mathlib). -/
theorem exists_min_rank (r : Tid → Nat) :
    ∀ (l : List Tid), l ≠ [] → ∃ m, m ∈ l ∧ ∀ x ∈ l, r m ≤ r x := by
  intro l
  induction l with
  | nil => intro h; exact absurd rfl h
  | cons a t ih =>
    intro _
    cases t with
    | nil =>
      refine ⟨a, List.mem_cons_self, ?_⟩
      intro x hx
      rcases List.mem_cons.mp hx with rfl | hx
      · exact Nat.le_refl _
      · exact absurd hx (List.not_mem_nil)
    | cons b t' =>
      obtain ⟨m, hm, hmin⟩ := ih (by simp)
      by_cases h : r a ≤ r m
      · refine ⟨a, List.mem_cons_self, ?_⟩
        intro x hx
        rcases List.mem_cons.mp hx with rfl | hx
        · exact Nat.le_refl _
        · exact Nat.le_trans h (hmin x hx)
      · refine ⟨m, List.mem_cons_of_mem _ hm, ?_⟩
        intro x hx
        rcases List.mem_cons.mp hx with rfl | hx
        · exact Nat.le_of_lt (Nat.lt_of_not_le h)
        · exact hmin x hx

/-- **Progress (T2) + Deadlock-freedom core (T4).** An acyclic configuration with any active thread
    always has a RUNNABLE one: the minimal-rank active thread cannot be blocked, because its peer
    would then be active (fidelity) with strictly smaller rank — contradicting minimality. So the
    configuration can always step until every thread terminates; it never gets internally stuck. -/
theorem progress (c : Config) (hne : c.live ≠ []) : ∃ i ∈ c.live, runnable c i := by
  obtain ⟨m, hm, hmin⟩ := exists_min_rank c.rank c.live hne
  refine ⟨m, hm, ?_⟩
  unfold runnable
  cases h : c.waits m with
  | none => rfl
  | some j =>
    exfalso
    have hjl : j ∈ c.live := c.peer_live m j hm h
    have hlt : c.rank j < c.rank m := c.acyclic m j h
    have hle : c.rank m ≤ c.rank j := hmin j hjl
    omega

/-- **Deadlock-freedom (T4).** No acyclic configuration is ever deadlocked. -/
theorem no_deadlock (c : Config) : ¬ deadlocked c := by
  rintro ⟨hne, hall⟩
  obtain ⟨i, hi, hrun⟩ := progress c hne
  exact hall i hi hrun

/-! ## Acyclicity is essential, and the forest built by `spawn` satisfies it. -/

/-- A 2-cycle in the waits-for graph admits NO rank witness — so it can never be a `Config`. This is
    why deadlock-freedom rests on the confinement/forest invariants (`AX0302`/`AX0305`): drop them,
    and a cyclic wait is expressible and genuinely deadlocks. -/
theorem two_cycle_has_no_rank (rank : Tid → Nat)
    (h01 : rank 1 < rank 0) (h10 : rank 0 < rank 1) : False := by omega

/-- …and a raw 2-cycle IS a graph-level deadlock (both blocked, neither runnable) — the state
    acyclicity rules out. -/
example :
    let waits : Tid → Option Tid := fun i => if i = 0 then some 1 else some 0
    waits 0 ≠ none ∧ waits 1 ≠ none := by decide

/-- A forest configuration — thread 0 a root (runnable), thread 1 its child blocked on 0, ranked by
    depth (what `spawn` assigns) — is a valid `Config`, and `progress` finds the runnable root. -/
def forestEx : Config where
  live := [0, 1]
  waits := fun i => if i = 1 then some 0 else none
  rank := id
  acyclic := by
    intro i j h
    by_cases hi : i = 1
    · subst hi; injection h with h; subst h; decide
    · simp only [if_neg hi] at h; exact absurd h (by simp)
  peer_live := by
    intro i j _ h
    by_cases hi : i = 1
    · subst hi; injection h with h; subst h; decide
    · simp only [if_neg hi] at h; exact absurd h (by simp)

/-- The forest configuration is never deadlocked, and `progress` exhibits the runnable root. -/
example : ¬ deadlocked forestEx := no_deadlock forestEx
example : ∃ i ∈ forestEx.live, runnable forestEx i := progress forestEx (by decide)

/-! ## `spawn` preserves acyclicity (deadlock-freedom BY CONSTRUCTION). -/

/-- Forking a fresh child `k` (a new, higher rank than every existing thread) that is either
    runnable or blocked on an EXISTING thread preserves the rank-witnessed acyclicity — the forest
    grows a leaf, never a cycle. This is the invariant the `spawn`/`bound` confinement maintains. -/
theorem spawn_preserves_acyclic
    (waits : Tid → Option Tid) (rank : Tid → Nat) (k : Tid)
    (hac : ∀ i j, waits i = some j → rank j < rank i)
    (hfresh : ∀ i, waits i ≠ some k)                 -- nobody already waits on the fresh child
    (peer : Option Tid)                              -- who the child blocks on (none = runnable)
    (hpeer : ∀ p, peer = some p → rank p < rank k)   -- …an existing, lower-ranked thread
    : ∀ i j, (fun t => if t = k then peer else waits t) i = some j → rank j < rank i := by
  intro i j h
  by_cases hi : i = k
  · subst hi; dsimp only at h; rw [if_pos rfl] at h; exact hpeer j h
  · simp only [if_neg hi] at h; exact hac i j h

/-! ## Axiom audit. -/
#print axioms progress
#print axioms no_deadlock
#print axioms spawn_preserves_acyclic

end AxionSession
