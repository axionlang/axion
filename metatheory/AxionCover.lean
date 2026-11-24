/-
  AxionCover — the pattern-coverage certificates of totality (`axionc/src/total.rs`).

  A function declared `{-# TOTAL f #-}` must not fail a pattern match: its clauses, and every
  `case` and lambda pattern inside it, must cover every value. `total.rs` decides this with
  Maranget's usefulness algorithm ("Warnings for pattern matching", JFP 2007), over the match's
  rows of patterns. Its decision is a COVERAGE TREE, the trace of that algorithm:

  * `leaf`        — some row is all wildcards: it matches whatever is left;
  * `split ty ts` — the first column is of type `ty`, whose constructors all head some row: one
                    subtree per constructor, over the rows specialized to it;
  * `skip t`      — the first column is not covered by constructors (or holds literals): only the
                    rows with a wildcard there can match, so drop the column and keep those.

  This file makes that decision checkable. For each match `total.rs` accepts it emits the rows and
  the tree; `check` re-checks the tree here, and `sound` proves what an accepted tree means: every
  vector of values that agrees with the patterns' types is matched by some row.

  Constructors are numbered by their type: `con ty k` is constructor `k` of type `ty`, and the
  signature `sig` lists, per type, its constructors' arities (a tuple is a type with one
  constructor). Literals are numbered too (`lit n`): they only ever match themselves, and a column
  of literals is never split. "Agrees with the patterns' types" (`agreeList`) and "well formed"
  (`wfList`) are what a well-typed program's values satisfy; reading the rows and the signature off
  the program is total.rs, not modelled here. `metatheory/cover-trace.sh` checks every certificate
  of the corpus.
-/

namespace AxionCover

inductive P where
  | any : P
  | con : Nat → Nat → List P → P
  | lit : Nat → P

inductive V where
  | con : Nat → Nat → List V → V
  | lit : Nat → V

/-- Per type, the arities of its constructors, in order. -/
abbrev Sig := List (List Nat)

mutual
def pmatch : P → V → Bool
  | .any, _ => true
  | .con t k ps, .con u j vs => t == u && k == j && pmatchL ps vs
  | .lit n, .lit m => n == m
  | _, _ => false
def pmatchL : List P → List V → Bool
  | [], [] => true
  | p :: ps, v :: vs => pmatch p v && pmatchL ps vs
  | _, _ => false
end

/- A value meets a pattern at the same type: a constructor pattern meets a constructor of the
same type (and, when it is the same constructor, the fields meet the subpatterns); a literal meets
a literal. The rows of a match and the values it is applied to agree, by typing. -/
mutual
def agree : P → V → Prop
  | .any, _ => True
  | .con t k ps, .con u j vs => t = u ∧ (k = j → agreeL ps vs)
  | .lit _, .lit _ => True
  | _, _ => False
def agreeL : List P → List V → Prop
  | [], [] => True
  | p :: ps, v :: vs => agree p v ∧ agreeL ps vs
  | _, _ => False
end

/- A value has its constructor's number of fields. -/
mutual
def wf (sig : Sig) : V → Prop
  | .con t k vs => (sig[t]? >>= fun ar => ar[k]?) = some vs.length ∧ wfL sig vs
  | .lit _ => True
def wfL (sig : Sig) : List V → Prop
  | [] => True
  | v :: vs => wf sig v ∧ wfL sig vs
end

def isAny : P → Bool
  | .any => true
  | _ => false

/-- A row specialized to constructor `k` (of `n` fields) of type `t`. -/
def specRow (t k n : Nat) : List P → Option (List P)
  | .any :: rest => some (List.replicate n .any ++ rest)
  | .con u j ps :: rest => if u = t ∧ j = k ∧ ps.length = n then some (ps ++ rest) else none
  | _ => none

def specialize (t k n : Nat) (rows : List (List P)) : List (List P) := rows.filterMap (specRow t k n)

def skipRow : List P → Option (List P)
  | .any :: rest => some rest
  | _ => none

def headTy : List P → Option Nat
  | .con t _ _ :: _ => some t
  | _ => none

inductive Tree where
  | leaf : Tree
  | split : Nat → List Tree → Tree
  | skip : Tree → Tree

mutual
def check (sig : Sig) : List (List P) → Tree → Bool
  | rows, .leaf => rows.any (fun r => r.all isAny)
  | rows, .skip t => check sig (rows.filterMap skipRow) t
  | rows, .split ty ts =>
    rows.any (fun r => headTy r == some ty) &&
      match sig[ty]? with
      | some ar => checkAll sig rows ty 0 ar ts
      | none => false
def checkAll (sig : Sig) : List (List P) → Nat → Nat → List Nat → List Tree → Bool
  | _, _, _, [], [] => true
  | rows, ty, k, n :: ns, t :: ts =>
    check sig (specialize ty k n rows) t && checkAll sig rows ty (k + 1) ns ts
  | _, _, _, _, _ => false
end

-- ## Lemmas on rows

theorem agreeL_length : ∀ (ps : List P) (vs : List V), agreeL ps vs → ps.length = vs.length
  | [], [], _ => rfl
  | _ :: ps, _ :: vs, h => by
    simp only [agreeL] at h
    simp [agreeL_length ps vs h.2]
  | [], _ :: _, h => by simp [agreeL] at h
  | _ :: _, [], h => by simp [agreeL] at h

theorem agreeL_append : ∀ (a : List P) (b : List P) (c : List V) (d : List V),
    agreeL a c → agreeL b d → agreeL (a ++ b) (c ++ d)
  | [], _, [], _, _, hbd => by simpa using hbd
  | _ :: a, b, _ :: c, d, hac, hbd => by
    simp only [agreeL] at hac
    simp only [List.cons_append, agreeL]
    exact ⟨hac.1, agreeL_append a b c d hac.2 hbd⟩
  | [], _, _ :: _, _, h, _ => by simp [agreeL] at h
  | _ :: _, _, [], _, h, _ => by simp [agreeL] at h

theorem agreeL_replicate : ∀ (n : Nat) (us : List V), us.length = n →
    agreeL (List.replicate n .any) us
  | 0, [], _ => by simp [agreeL]
  | n + 1, _ :: us, h => by
    simp only [List.length_cons, Nat.add_right_cancel_iff] at h
    simp only [List.replicate_succ, agreeL, agree, true_and]
    exact agreeL_replicate n us h
  | 0, _ :: _, h => by simp at h
  | _ + 1, [], h => by simp at h

theorem wfL_append : ∀ (sig : Sig) (a b : List V), wfL sig a → wfL sig b → wfL sig (a ++ b)
  | _, [], _, _, hb => by simpa using hb
  | sig, _ :: a, b, ha, hb => by
    simp only [wfL] at ha
    simp only [List.cons_append, wfL]
    exact ⟨ha.1, wfL_append sig a b ha.2 hb⟩

/-- Matching a concatenation, cut where the patterns are cut. -/
theorem pmatchL_append : ∀ (a b : List P) (c d : List V), a.length = c.length →
    pmatchL (a ++ b) (c ++ d) = true → pmatchL a c = true ∧ pmatchL b d = true
  | [], _, [], _, _, h => by simpa [pmatchL] using h
  | _ :: a, b, _ :: c, d, hl, h => by
    simp only [List.length_cons, Nat.add_right_cancel_iff] at hl
    simp only [List.cons_append, pmatchL, Bool.and_eq_true] at h
    have := pmatchL_append a b c d hl h.2
    simp only [pmatchL, Bool.and_eq_true]
    exact ⟨⟨h.1, this.1⟩, this.2⟩
  | [], _, _ :: _, _, hl, _ => by simp at hl
  | _ :: _, _, [], _, hl, _ => by simp at hl

/-- A row of wildcards matches every vector of its width. -/
theorem allAny_match : ∀ (r : List P) (vs : List V), r.all isAny = true → r.length = vs.length →
    pmatchL r vs = true
  | [], [], _, _ => rfl
  | p :: r, _ :: vs, h, hl => by
    simp only [List.all_cons, Bool.and_eq_true] at h
    simp only [List.length_cons, Nat.add_right_cancel_iff] at hl
    cases p with
    | any => simp only [pmatchL, pmatch, Bool.true_and]; exact allAny_match r vs h.2 hl
    | con _ _ _ => simp [isAny] at h
    | lit _ => simp [isAny] at h
  | [], _ :: _, _, hl => by simp at hl
  | _ :: _, [], _, hl => by simp at hl

/-- A row of the specialized matrix, matched, gives back a matching row of the original one. -/
theorem specRow_back (t k : Nat) (us rest : List V) :
    ∀ (r r' : List P), specRow t k us.length r = some r' → pmatchL r' (us ++ rest) = true →
      pmatchL r (.con t k us :: rest) = true
  | .any :: rr, r', hs, hm => by
    simp only [specRow, Option.some.injEq] at hs
    subst hs
    have := pmatchL_append _ _ _ _ (by simp) hm
    simp only [pmatchL, pmatch, Bool.true_and]
    exact this.2
  | .con u j ps :: rr, r', hs, hm => by
    simp only [specRow] at hs
    split at hs
    · rename_i hc
      obtain ⟨rfl, rfl, hl⟩ := hc
      simp only [Option.some.injEq] at hs
      subst hs
      have := pmatchL_append _ _ _ _ hl hm
      simp only [pmatchL, pmatch, beq_self_eq_true, Bool.true_and, Bool.and_eq_true]
      exact ⟨this.1, this.2⟩
    · simp at hs
  | .lit _ :: _, _, hs, _ => by simp [specRow] at hs
  | [], _, hs, _ => by simp [specRow] at hs

/-- Specializing to the value's own constructor keeps the rows agreeing with the values. -/
theorem specRow_agree (t k : Nat) (us rest : List V) :
    ∀ (r r' : List P), specRow t k us.length r = some r' → agreeL r (.con t k us :: rest) →
      agreeL r' (us ++ rest)
  | .any :: rr, r', hs, ha => by
    simp only [specRow, Option.some.injEq] at hs
    subst hs
    simp only [agreeL] at ha
    exact agreeL_append _ _ _ _ (agreeL_replicate _ _ rfl) ha.2
  | .con u j ps :: rr, r', hs, ha => by
    simp only [specRow] at hs
    split at hs
    · rename_i hc
      obtain ⟨rfl, rfl, _⟩ := hc
      simp only [Option.some.injEq] at hs
      subst hs
      simp only [agreeL, agree] at ha
      have hps : agreeL ps us := by
        exact ha.1.2 trivial
      exact agreeL_append _ _ _ _ hps ha.2
    · simp at hs
  | .lit _ :: _, _, hs, _ => by simp [specRow] at hs
  | [], _, hs, _ => by simp [specRow] at hs

-- ## Soundness

mutual
/-- What an accepted tree means: every vector of well-formed values agreeing with the rows is
matched by some row. -/
theorem sound (sig : Sig) : ∀ (rows : List (List P)) (tr : Tree), check sig rows tr = true →
    ∀ vs : List V, wfL sig vs → (∀ r ∈ rows, agreeL r vs) → ∃ r ∈ rows, pmatchL r vs = true
  | rows, .leaf, h, vs, _, hag => by
    simp only [check, List.any_eq_true] at h
    obtain ⟨r, hr, hall⟩ := h
    exact ⟨r, hr, allAny_match r vs hall (agreeL_length r vs (hag r hr))⟩
  | rows, .skip t, h, vs, hwf, hag => by
    simp only [check] at h
    cases vs with
    | nil =>
      -- every row has width 0, so none has a wildcard to drop: the tree cannot be accepted
      have hnil : rows.filterMap skipRow = [] := by
        rw [List.filterMap_eq_nil_iff]
        intro r hr
        have := agreeL_length r [] (hag r hr)
        match r, this with
        | [], _ => rfl
      have := sound sig _ t h [] hwf (by simp [hnil])
      simp [hnil] at this
    | cons v rest =>
      simp only [wfL] at hwf
      have hag' : ∀ r' ∈ rows.filterMap skipRow, agreeL r' rest := by
        intro r' hr'
        rw [List.mem_filterMap] at hr'
        obtain ⟨r, hr, hs⟩ := hr'
        match r, hs with
        | .any :: rr, hs =>
          simp only [skipRow, Option.some.injEq] at hs
          subst hs
          have := hag _ hr
          simp only [agreeL] at this
          exact this.2
      obtain ⟨r', hr', hm⟩ := sound sig _ t h rest hwf.2 hag'
      rw [List.mem_filterMap] at hr'
      obtain ⟨r, hr, hs⟩ := hr'
      match r, hs with
      | .any :: rr, hs =>
        simp only [skipRow, Option.some.injEq] at hs
        subst hs
        exact ⟨_, hr, by simpa [pmatchL, pmatch] using hm⟩
  | rows, .split ty ts, h, vs, hwf, hag => by
    simp only [check, Bool.and_eq_true, List.any_eq_true, beq_iff_eq] at h
    obtain ⟨⟨r0, hr0, hty⟩, hall⟩ := h
    -- the row headed by a constructor of `ty` fixes the first value: a constructor of `ty`
    match r0, hty, vs, hag r0 hr0 with
    | .con t0 _ ps :: rr, hty, .con u j us :: rest, ha0 =>
      simp only [headTy, Option.some.injEq] at hty
      subst hty
      have htu : t0 = u := by
        simp only [agreeL, agree] at ha0
        exact ha0.1.1
      subst htu
      simp only [wfL, wf] at hwf
      obtain ⟨⟨har, hwus⟩, hwrest⟩ := hwf
      cases hs : sig[t0]? with
      | none => simp [hs] at har
      | some ar =>
        simp only [hs] at hall
        have har' : ar[j]? = some us.length := by simpa [hs] using har
        have := soundAll sig rows t0 ar ts 0 hall j us.length har' (us ++ rest)
          (wfL_append sig us rest hwus hwrest)
          (by
            intro r' hr'
            simp only [specialize, List.mem_filterMap, Nat.zero_add] at hr'
            obtain ⟨r, hr, hs⟩ := hr'
            exact specRow_agree t0 j us rest r r' hs (hag r hr))
        obtain ⟨r', hr', hm⟩ := this
        simp only [specialize, List.mem_filterMap, Nat.zero_add] at hr'
        obtain ⟨r, hr, hs⟩ := hr'
        exact ⟨r, hr, specRow_back t0 j us rest r r' hs hm⟩
    | .con _ _ _ :: _, _, .lit _ :: _, ha0 => simp [agreeL, agree] at ha0
    | .con _ _ _ :: _, _, [], ha0 => simp [agreeL] at ha0
/-- The subtrees of a split: subtree `i` covers constructor `k + i` (of arity `ar[i]`). -/
theorem soundAll (sig : Sig) (rows : List (List P)) (ty : Nat) :
    ∀ (ar : List Nat) (ts : List Tree) (k : Nat), checkAll sig rows ty k ar ts = true →
      ∀ (i n : Nat), ar[i]? = some n →
      ∀ vs : List V, wfL sig vs → (∀ r ∈ specialize ty (k + i) n rows, agreeL r vs) →
        ∃ r ∈ specialize ty (k + i) n rows, pmatchL r vs = true
  | [], _, _, _, _, _, hn, _, _, _ => by simp at hn
  | n0 :: ns, t :: ts, k, h, i, n, hn, vs, hwf, hag => by
    simp only [checkAll, Bool.and_eq_true] at h
    match i, hn with
    | 0, hn =>
      simp only [List.getElem?_cons_zero, Option.some.injEq] at hn
      subst hn
      exact sound sig _ t h.1 vs hwf hag
    | i + 1, hn =>
      simp only [List.getElem?_cons_succ] at hn
      have e : k + (i + 1) = (k + 1) + i := by omega
      rw [e] at hag ⊢
      exact soundAll sig rows ty ns ts (k + 1) h.2 i n hn vs hwf hag
  | _ :: _, [], _, h, _, _, _, _, _, _ => by simp [checkAll] at h
end

end AxionCover

#print axioms AxionCover.sound

-- `case xs of Nil -> …; Cons _ _ -> …` (List: Nil, Cons/2): split, one leaf per constructor
example : AxionCover.check [[0, 2]] [[.con 0 0 []], [.con 0 1 [.any, .any]]]
    (.split 0 [.leaf, .leaf]) = true := by rfl
-- missing `Nil`: no tree is accepted for it (here, the same tree is refused)
example : AxionCover.check [[0, 2]] [[.con 0 1 [.any, .any]]] (.split 0 [.leaf, .leaf]) = false := by
  rfl
-- literals then a wildcard: the column is skipped, the wildcard row covers
example : AxionCover.check [] [[.lit 0], [.lit 1], [.any]] (.skip .leaf) = true := by rfl
-- literals alone never cover
example : AxionCover.check [] [[.lit 0], [.lit 1]] (.skip .leaf) = false := by rfl
