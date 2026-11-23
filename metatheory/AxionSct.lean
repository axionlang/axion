/-
  AxionSct — the size-change certificates of totality (`axionc/src/total.rs`).

  A function declared `{-# TOTAL f #-}` is proven to terminate by the size-change principle
  (Lee, Jones and Ben-Amram, "The size-change principle for program termination", POPL 2001).
  For each recursive group, `total.rs` reads one SIZE-CHANGE GRAPH per call between members: an
  edge `i → j` says the callee's measure `j` is at most the caller's measure `i`, strictly smaller
  when the edge is strict. It then computes the CLOSURE of these graphs under composition and
  accepts the group when every IDEMPOTENT graph from a function to itself (`g ; g = g`) has a
  strict edge `i → i`. By the theorem (their Theorem 4), no infinite sequence of calls can then
  exist: each would descend some measure infinitely often, and measures are well-founded.

  This file makes `total.rs`'s own computation checkable. For each group it emits a CERTIFICATE:
  the call graphs and the closure it computed. `check` re-checks it here, and `sound` proves what
  an accepted certificate means: the claimed closure contains the composite of EVERY chain of
  calls (so it covers the true closure), and every idempotent self-graph in it has a strict
  self-edge — exactly the hypothesis of the theorem. The theorem itself is cited, not proven here
  (it needs Ramsey's theorem). `metatheory/sct-trace.sh` checks every certificate of the corpus.

  Graphs are canonical: their edges sorted by `(i, j)`, one per pair (a strict edge when there
  were both), as `total.rs`'s `normalize` builds them. So two graphs with the same edges are
  equal, and membership in the closure is plain equality.
-/

namespace AxionSct

structure Edge where
  i : Nat
  j : Nat
  s : Bool
  deriving DecidableEq, Repr

structure Graph where
  src : Nat
  dst : Nat
  es : List Edge
  deriving DecidableEq, Repr

/-- Insert an edge into a canonical list: sorted by `(i, j)`, one edge per pair, strict wins. -/
def ins (e : Edge) : List Edge → List Edge
  | [] => [e]
  | f :: fs =>
    if e.i = f.i ∧ e.j = f.j then ⟨f.i, f.j, f.s || e.s⟩ :: fs
    else if e.i < f.i ∨ (e.i = f.i ∧ e.j < f.j) then e :: f :: fs
    else f :: ins e fs

def normalize (l : List Edge) : List Edge := l.foldl (fun acc e => ins e acc) []

/-- Every path `i → j → k` through the two graphs, strict if either step is. -/
def composeEdges (a b : List Edge) : List Edge :=
  a.flatMap (fun e => b.filterMap (fun f => if e.j = f.i then some ⟨e.i, f.j, e.s || f.s⟩ else none))

/-- `a` then `b`: from `a`'s function to `b`'s callee. -/
def compose (a b : Graph) : Graph := ⟨a.src, b.dst, normalize (composeEdges a.es b.es)⟩

def strictLoop (g : Graph) : Bool := g.es.any (fun e => e.i == e.j && e.s)

/-- A certificate: the group's call graphs and a claimed closure. Accepted when every call is in
the closure, the closure is closed under composing with a call, and every idempotent graph from a
function to itself has a strict self-edge. -/
def check (calls clos : List Graph) : Bool :=
  calls.all (fun c => clos.contains c) &&
  clos.all (fun g => calls.all (fun b => b.src != g.dst || clos.contains (compose g b))) &&
  clos.all (fun g => !(g.src == g.dst && compose g g == g) || strictLoop g)

/-- The composite of `g` followed by a chain of graphs. -/
def comp : Graph → List Graph → Graph
  | g, [] => g
  | g, b :: bs => comp (compose g b) bs

/-- `bs` continues `g`: each graph starts where the composite so far ends. -/
def chains : Graph → List Graph → Prop
  | _, [] => True
  | g, b :: bs => b.src = g.dst ∧ chains (compose g b) bs

theorem contains_mem {l : List Graph} {g : Graph} (h : l.contains g = true) : g ∈ l := by
  simpa using h

theorem mem_contains {l : List Graph} {g : Graph} (h : g ∈ l) : l.contains g = true := by
  simpa using h

/-- Every composite of a chain of calls starting in the closure stays in the closure. -/
theorem comp_mem (calls clos : List Graph)
    (closed : ∀ g ∈ clos, ∀ b ∈ calls, b.src = g.dst → compose g b ∈ clos) :
    ∀ (bs : List Graph) (g : Graph), g ∈ clos → (∀ b ∈ bs, b ∈ calls) → chains g bs →
      comp g bs ∈ clos := by
  intro bs
  induction bs with
  | nil => intro g hg _ _; simpa [comp] using hg
  | cons b bs ih =>
    intro g hg hcalls hch
    simp only [chains] at hch
    simp only [comp]
    apply ih
    · exact closed g hg b (hcalls b (by simp)) hch.1
    · intro x hx; exact hcalls x (by simp [hx])
    · exact hch.2

/-- What an accepted certificate means: the composite of every chain of calls (starting with a
call) is in the claimed closure, and every idempotent self-graph in it has a strict self-edge —
the hypothesis of the size-change theorem. -/
theorem sound (calls clos : List Graph) (h : check calls clos = true) :
    (∀ c ∈ calls, ∀ bs : List Graph, (∀ b ∈ bs, b ∈ calls) → chains c bs → comp c bs ∈ clos) ∧
    (∀ g ∈ clos, g.src = g.dst → compose g g = g → strictLoop g = true) := by
  simp only [check, Bool.and_eq_true, List.all_eq_true] at h
  obtain ⟨⟨hcalls, hclosed⟩, hidem⟩ := h
  have closed : ∀ g ∈ clos, ∀ b ∈ calls, b.src = g.dst → compose g b ∈ clos := by
    intro g hg b hb heq
    have := hclosed g hg b hb
    simp only [Bool.or_eq_true, bne_iff_ne, ne_eq] at this
    rcases this with hne | hc
    · exact absurd heq hne
    · exact contains_mem hc
  refine ⟨?_, ?_⟩
  · intro c hc bs hbs hch
    exact comp_mem calls clos closed bs c (contains_mem (hcalls c hc)) hbs hch
  · intro g hg hsd hid
    have := hidem g hg
    simp only [Bool.or_eq_true, Bool.not_eq_true', Bool.and_eq_false_iff, beq_eq_false_iff_ne,
      ne_eq] at this
    rcases this with (hne | hne) | hs
    · exact absurd hsd hne
    · exact absurd hid hne
    · exact hs

#print axioms AxionSct.comp_mem
#print axioms AxionSct.sound

-- `f x = f (x - 1)`: one strict self-edge; the closure is the call itself
example : check [⟨0, 0, [⟨0, 0, true⟩]⟩] [⟨0, 0, [⟨0, 0, true⟩]⟩] = true := by rfl
-- `ack`: lexicographic, its closure accepted
example : check [⟨0, 0, [⟨0, 0, true⟩]⟩, ⟨0, 0, [⟨0, 0, false⟩, ⟨1, 1, true⟩]⟩]
    [⟨0, 0, [⟨0, 0, true⟩]⟩, ⟨0, 0, [⟨0, 0, false⟩, ⟨1, 1, true⟩]⟩] = true := by rfl
-- `f x = f x`: an idempotent self-graph with no strict edge is refused
example : check [⟨0, 0, [⟨0, 0, false⟩]⟩] [⟨0, 0, [⟨0, 0, false⟩]⟩] = false := by rfl
-- a claimed closure missing a composite is refused (`f → g`, `g → f`: `f → f` is absent)
example : check [⟨0, 1, [⟨0, 0, true⟩]⟩, ⟨1, 0, [⟨0, 0, true⟩]⟩]
    [⟨0, 1, [⟨0, 0, true⟩]⟩, ⟨1, 0, [⟨0, 0, true⟩]⟩] = false := by rfl

end AxionSct
