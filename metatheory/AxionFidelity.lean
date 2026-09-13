/-
  AxionFidelity — session fidelity (T3) and cancellation safety (T5) of the Axión Session Calculus
  (docs/phase-3-calculus.md §2, §5, §6). Companion to AxionSession.lean (which did T2/T4 at the
  graph level); this file works at the SESSION-TYPE level.

  T3 — Session Fidelity (§6): every communication follows the channel's type S / dual(S), and the
  two ends NEVER diverge from the protocol. We model session types + duality (§2.1/§2.2) and the
  type-level communication step (§5.1 cut elimination), and prove: duality is INVARIANT under
  communication (the ends stay dual), and a matching communication is always ENABLED between dual
  ends — the ends can neither disagree on the next action nor get out of step. (A1 — single-owner
  endpoints — is the linearity already enforced by `%1`; here we mechanize the protocol-adherence
  half.)

  T5 — Cancellation Safety (§6, EGV §5.4): `Closed` is a first-class label in every external offer
  (§2.1), so a cancelling end (which selects `Closed`) is always matched by the peer's `Closed`
  branch — no endpoint is left un-notified or stuck. And in the rank-witnessed spawn forest, no node
  is its own ancestor, so the downward cancellation traversal (`reset` + one `Closed` per child,
  §5.4) visits each descendant AT MOST once: every `@cleanup` runs exactly once, nothing is
  re-cancelled.
-/

namespace AxionFidelity

abbrev Ty := Nat
abbrev Label := Nat

/-- The distinguished cancellation label present in every external offer (§2.1, EGV). -/
def closedL : Label := 0

/-- Session types (§2.1): send/recv a value then continue, internal selection `⊕`, external offer
    `&`, or termination. Branch lists carry the labelled continuations. -/
inductive SType where
  | done
  | send  (t : Ty) (k : SType)
  | recv  (t : Ty) (k : SType)
  | sel   (bs : List (Label × SType))
  | offer (bs : List (Label × SType))

/- `dual` (§2.2), via an explicit branch-map so the recursion is structural (no `List.map` under a
   lambda). -/
mutual
def dual : SType → SType
  | .done      => .done
  | .send t k  => .recv t (dual k)
  | .recv t k  => .send t (dual k)
  | .sel bs    => .offer (dualBs bs)
  | .offer bs  => .sel (dualBs bs)
def dualBs : List (Label × SType) → List (Label × SType)
  | []            => []
  | (l, s) :: r   => (l, dual s) :: dualBs r
end

/-- Look up a labelled branch. -/
def lookup : Label → List (Label × SType) → Option SType
  | _, []            => none
  | l, (l', s) :: r  => if l = l' then some s else lookup l r

/- Duality is involutive (§2.2). -/
mutual
theorem dual_dual : ∀ s : SType, dual (dual s) = s
  | .done     => rfl
  | .send t k => by rw [dual, dual, dual_dual k]
  | .recv t k => by rw [dual, dual, dual_dual k]
  | .sel bs   => by rw [dual, dual, dualBs_dualBs bs]
  | .offer bs => by rw [dual, dual, dualBs_dualBs bs]
theorem dualBs_dualBs : ∀ bs : List (Label × SType), dualBs (dualBs bs) = bs
  | []          => rfl
  | (l, s) :: r => by rw [dualBs, dualBs, dual_dual s, dualBs_dualBs r]
end

/-- `dualBs` preserves labels and duals each continuation. -/
theorem lookup_dualBs (l : Label) :
    ∀ bs, lookup l (dualBs bs) = (lookup l bs).map dual
  | []          => rfl
  | (l', s) :: r => by
    simp only [dualBs, lookup]
    by_cases h : l = l' <;> simp [h, lookup_dualBs l r]

/-- Type-level communication (§5.1 cut elimination): a matched interaction advances BOTH ends to
    their continuations. `send`↔`recv` on a value; `sel`↔`offer` on a chosen label. -/
inductive Comm : SType → SType → SType → SType → Prop where
  | sr {t k k'} : Comm (.send t k) (.recv t k') k k'
  | rs {t k k'} : Comm (.recv t k) (.send t k') k k'
  | so {l s s' bs bs'} :
      lookup l bs = some s → lookup l bs' = some s' → Comm (.sel bs) (.offer bs') s s'
  | os {l s s' bs bs'} :
      lookup l bs = some s → lookup l bs' = some s' → Comm (.offer bs) (.sel bs') s s'

/-- **T3 — Session Fidelity (preservation).** If the two ends are dual and they communicate, the
    resulting continuations are STILL dual — the ends never diverge from the protocol. -/
theorem fidelity {s1 s2 t1 t2 : SType}
    (hd : s2 = dual s1) (hc : Comm s1 s2 t1 t2) : t2 = dual t1 := by
  cases hc with
  | @sr t k k' =>
    -- hd : recv t k' = dual (send t k) = recv t (dual k) ⟹ k' = dual k
    rw [dual] at hd; simp only [SType.recv.injEq] at hd; exact hd.2
  | @rs t k k' =>
    rw [dual] at hd; simp only [SType.send.injEq] at hd; exact hd.2
  | @so l s s' bs bs' hb hb' =>
    -- hd : offer bs' = dual (sel bs) = offer (dualBs bs) ⟹ bs' = dualBs bs ⟹ s' = dual s
    rw [dual] at hd; injection hd with hbs
    subst hbs
    rw [lookup_dualBs, hb] at hb'
    simp only [Option.map_some] at hb'
    exact (Option.some.inj hb').symm
  | @os l s s' bs bs' hb hb' =>
    rw [dual] at hd; injection hd with hbs
    subst hbs
    rw [lookup_dualBs, hb] at hb'
    simp only [Option.map_some] at hb'
    exact (Option.some.inj hb').symm

/-- **T3 — Progress (enabledness).** Between dual ends, a matching communication is always enabled
    (unless terminated) — the ends agree on the next action, so no protocol stall. (Choices must be
    nonempty, as a well-formed `⊕`/`&` always is.) -/
theorem comm_enabled : ∀ (s1 : SType), s1 ≠ .done →
    (∀ bs, s1 = .sel bs ∨ s1 = .offer bs → bs ≠ []) →
    ∃ t1 t2, Comm s1 (dual s1) t1 t2
  | .done, hne, _ => absurd rfl hne
  | .send t k, _, _ => ⟨k, dual k, Comm.sr⟩
  | .recv t k, _, _ => ⟨k, dual k, Comm.rs⟩
  | .sel bs, _, hne =>
    match bs, hne bs (Or.inl rfl) with
    | (l, s) :: _, _ => by
      refine ⟨s, dual s, Comm.so (l := l) ?_ ?_⟩
      · simp [lookup]
      · rw [lookup_dualBs]; simp [lookup]
  | .offer bs, _, hne =>
    match bs, hne bs (Or.inr rfl) with
    | (l, s) :: _, _ => by
      refine ⟨s, dual s, Comm.os (l := l) ?_ ?_⟩
      · simp [lookup]
      · rw [lookup_dualBs]; simp [lookup]

/-! ## T5 — Cancellation safety. -/

/-- A well-formed external offer carries the `Closed` cancellation branch (§2.1, EGV). -/
def hasClosed (bs : List (Label × SType)) : Prop := (lookup closedL bs).isSome

/-- **T5(a) — cancellation is always receivable.** A well-formed peer offer's DUAL selection also
    has a `Closed` branch, so a cancelling end (`select Closed`) is always matched by the peer's
    `Closed` offer branch — the peer takes it and steps; no endpoint is left un-notified or stuck.
    "Typing forces the receiver to handle cancellation" (§5.4), mechanized. -/
theorem cancellation_receivable {bs' : List (Label × SType)} (hwf : hasClosed bs') :
    ∃ s s', Comm (.sel (dualBs bs')) (.offer bs') s s' := by
  have hdual : (lookup closedL (dualBs bs')).isSome := by
    rw [lookup_dualBs]; simpa using hwf
  obtain ⟨s, hs⟩ := Option.isSome_iff_exists.mp hdual
  obtain ⟨s', hs'⟩ := Option.isSome_iff_exists.mp hwf
  exact ⟨s, s', Comm.so hs hs'⟩

/-- The ancestor closure in the spawn forest (parent edges; §5.2 [SPAWN]). -/
inductive Ancestor (parent : Label → Option Label) : Label → Label → Prop where
  | base {i p} : parent i = some p → Ancestor parent i p
  | step {i p a} : parent i = some p → Ancestor parent p a → Ancestor parent i a

/-- An ancestor has strictly smaller rank (the spawn depth; the forest AX0305 builds). -/
theorem ancestor_rank {parent : Label → Option Label} {rank : Label → Nat}
    (hforest : ∀ i p, parent i = some p → rank p < rank i) :
    ∀ i a, Ancestor parent i a → rank a < rank i := by
  intro i a h
  induction h with
  | base hp => exact hforest _ _ hp
  | step hp _ ih => exact Nat.lt_trans ih (hforest _ _ hp)

/-- **T5(c) — cleanup exactly once (foundation).** In the rank-witnessed spawn forest, no node is
    its own ancestor, so the downward cancellation traversal (`reset` + one `Closed` per live child,
    §5.4) can never revisit a node: every `@cleanup` runs at most once, nothing is re-cancelled.
    (Combined with reaching every descendant, exactly once — no orphaned arena memory.) -/
theorem no_self_ancestor {parent : Label → Option Label} {rank : Label → Nat}
    (hforest : ∀ i p, parent i = some p → rank p < rank i) (i : Label) :
    ¬ Ancestor parent i i := by
  intro hself
  exact Nat.lt_irrefl _ (ancestor_rank hforest i i hself)

/-! ## Axiom audit. -/
#print axioms fidelity
#print axioms comm_enabled
#print axioms cancellation_receivable
#print axioms no_self_ancestor

end AxionFidelity
