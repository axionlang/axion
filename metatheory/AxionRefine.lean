/-
  AxionRefine — soundness of the refinement certificate checker (`axionc/src/refine.rs`).

  `refine.rs` proves a refinement by showing that the known facts and the negated goal have no
  integer solution. Its Fourier–Motzkin search records that as a CERTIFICATE: a list of steps,
  each adding a row (a linear constraint `Σ cᵢ·xᵢ + k ≥ 0`) to a growing list:

    * `hyp i`        — the `i`-th input row (a fact or the negated goal);
    * `comb i a j b` — `a·rowᵢ + b·rowⱼ` with `a b : Nat` (a non-negative combination);
    * `tight i g`    — `rowᵢ` with every coefficient divided by `g > 0` (each divisible by it)
                       and the constant divided by `g` rounding down (integer tightening).

  The certificate is accepted when the last row has every coefficient `0` and a negative constant
  (`k ≥ 0` with `k < 0`: impossible). `check` is the executable checker; `sound` proves that an
  accepted certificate means NO integer assignment satisfies all the input rows. `refine.rs`'s
  own checker (`check_cert`) is the same algorithm; `metatheory/refine-trace.sh` re-checks every
  certificate the compiler produces over the corpus with THIS `check`, by `rfl`.

  Rows are dense: coefficient `i` belongs to variable `i`.
-/

namespace AxionRefine

structure Row where
  c : List Int
  k : Int
  deriving Repr

/-- `Σ cᵢ·σ(i + n)` over the coefficient list starting at variable `n`. -/
def dot (σ : Nat → Int) : Nat → List Int → Int
  | _, [] => 0
  | n, a :: as => a * σ n + dot σ (n + 1) as

def holds (σ : Nat → Int) (r : Row) : Prop := 0 ≤ dot σ 0 r.c + r.k

/-- Coefficient-wise sum, the shorter list padded with zeros. -/
def addL : List Int → List Int → List Int
  | [], bs => bs
  | as, [] => as
  | a :: as, b :: bs => (a + b) :: addL as bs

def scaleL (m : Int) (l : List Int) : List Int := l.map (m * ·)

inductive Step where
  | hyp (i : Nat)
  | comb (i : Nat) (a : Nat) (j : Nat) (b : Nat)
  | tight (i : Nat) (g : Nat)
  deriving Repr

def divisible (g : Int) (l : List Int) : Bool := l.all (fun x => x % g == 0)

def stepRow (input rows : List Row) : Step → Option Row
  | .hyp i => input[i]?
  | .comb i a j b =>
      match rows[i]?, rows[j]? with
      | some r, some s => some ⟨addL (scaleL a r.c) (scaleL b s.c), a * r.k + b * s.k⟩
      | _, _ => none
  | .tight i g =>
      match rows[i]? with
      | some r =>
          if 0 < (g : Int) ∧ divisible g r.c = true then
            some ⟨r.c.map (· / (g : Int)), r.k / (g : Int)⟩
          else none
      | none => none

def run (input : List Row) : List Row → List Step → Option (List Row)
  | rows, [] => some rows
  | rows, s :: ss =>
      match stepRow input rows s with
      | some r => run input (rows ++ [r]) ss
      | none => none

def contradiction (r : Row) : Bool := r.c.all (· == 0) && decide (r.k < 0)

/-- The executable certificate checker. -/
def check (input : List Row) (steps : List Step) : Bool :=
  match run input [] steps with
  | some rows =>
      match rows.getLast? with
      | some r => contradiction r
      | none => false
  | none => false

/-! ### Linear algebra of `dot` -/

theorem dot_addL (σ : Nat → Int) : ∀ (n : Nat) (a b : List Int),
    dot σ n (addL a b) = dot σ n a + dot σ n b
  | n, [], bs => by simp [addL, dot]
  | n, a :: as, [] => by simp [addL, dot]
  | n, a :: as, b :: bs => by
      simp only [addL, dot]
      rw [dot_addL σ (n + 1) as bs, Int.add_mul]
      omega

theorem dot_scaleL (σ : Nat → Int) (m : Int) : ∀ (n : Nat) (l : List Int),
    dot σ n (scaleL m l) = m * dot σ n l
  | n, [] => by simp [scaleL, dot]
  | n, a :: as => by
      have ih := dot_scaleL σ m (n + 1) as
      simp only [scaleL, List.map, dot] at *
      rw [ih, Int.mul_add, Int.mul_assoc]

theorem dot_zero (σ : Nat → Int) : ∀ (n : Nat) (l : List Int),
    l.all (· == 0) = true → dot σ n l = 0
  | n, [], _ => by simp [dot]
  | n, a :: as, h => by
      simp only [List.all_cons, Bool.and_eq_true, beq_iff_eq] at h
      simp only [dot, h.1, Int.zero_mul, dot_zero σ (n + 1) as h.2]
      rfl

theorem dot_div (σ : Nat → Int) (g : Int) : ∀ (n : Nat) (l : List Int),
    divisible g l = true → dot σ n l = g * dot σ n (l.map (· / g))
  | n, [], _ => by simp [dot]
  | n, a :: as, h => by
      simp only [divisible, List.all_cons, Bool.and_eq_true, beq_iff_eq] at h
      have ha : g * (a / g) = a := Int.mul_ediv_cancel' (Int.dvd_of_emod_eq_zero h.1)
      have ih := dot_div σ g (n + 1) as h.2
      simp only [List.map, dot]
      rw [ih, Int.mul_add, ← Int.mul_assoc, ha]

/-- Integer tightening: `0 ≤ g·D + k` with `g > 0` gives `0 ≤ D + ⌊k / g⌋`. -/
theorem tighten {g D k : Int} (hg : 0 < g) (h : 0 ≤ g * D + k) : 0 ≤ D + k / g := by
  have hk : g * (k / g) + k % g = k := Int.mul_ediv_add_emod k g
  have hr : k % g < g := Int.emod_lt_of_pos k hg
  have hr0 : 0 ≤ k % g := Int.emod_nonneg k (Int.ne_of_gt hg)
  generalize hq : k / g = q at *
  generalize hrr : k % g = r at *
  -- 0 ≤ g·D + g·q + r with r < g, so g·(D + q) > -g, so D + q > -1
  have hsum : 0 ≤ g * (D + q) + r := by rw [Int.mul_add]; omega
  by_cases hneg : D + q ≤ -1
  · have hm : g * (D + q) ≤ g * (-1) := Int.mul_le_mul_of_nonneg_left hneg (Int.le_of_lt hg)
    generalize g * (D + q) = P at *
    omega
  · omega

/-! ### Soundness -/

theorem stepRow_holds (σ : Nat → Int) (input rows : List Row)
    (hin : ∀ r ∈ input, holds σ r) (hrows : ∀ r ∈ rows, holds σ r) :
    ∀ (s : Step) (r : Row), stepRow input rows s = some r → holds σ r := by
  intro s r hs
  cases s with
  | hyp i =>
      simp only [stepRow] at hs
      exact hin r (List.mem_of_getElem? hs)
  | comb i a j b =>
      simp only [stepRow] at hs
      split at hs
      · rename_i r1 r2 h1 h2
        cases hs
        have p1 := hrows r1 (List.mem_of_getElem? h1)
        have p2 := hrows r2 (List.mem_of_getElem? h2)
        unfold holds at *
        simp only [dot_addL, dot_scaleL]
        have ha : (0 : Int) ≤ a := Int.natCast_nonneg a
        have hb : (0 : Int) ≤ b := Int.natCast_nonneg b
        have m1 : 0 ≤ (a : Int) * (dot σ 0 r1.c + r1.k) := Int.mul_nonneg ha p1
        have m2 : 0 ≤ (b : Int) * (dot σ 0 r2.c + r2.k) := Int.mul_nonneg hb p2
        rw [Int.mul_add] at m1 m2
        omega
      · cases hs
  | tight i g =>
      simp only [stepRow] at hs
      split at hs
      · rename_i r1 h1
        split at hs
        · rename_i hc
          cases hs
          have p1 := hrows r1 (List.mem_of_getElem? h1)
          unfold holds at *
          rw [dot_div σ g 0 r1.c hc.2] at p1
          exact tighten hc.1 p1
        · cases hs
      · cases hs

theorem run_holds (σ : Nat → Int) (input : List Row) (hin : ∀ r ∈ input, holds σ r) :
    ∀ (steps : List Step) (rows out : List Row), (∀ r ∈ rows, holds σ r) →
      run input rows steps = some out → ∀ r ∈ out, holds σ r
  | [], rows, out, hrows, h => by
      simp only [run, Option.some.injEq] at h
      subst h
      exact hrows
  | s :: ss, rows, out, hrows, h => by
      simp only [run] at h
      split at h
      · rename_i r hr
        have hnew := stepRow_holds σ input rows hin hrows s r hr
        apply run_holds σ input hin ss (rows ++ [r]) out _ h
        intro x hx
        rcases List.mem_append.mp hx with hx | hx
        · exact hrows x hx
        · simp only [List.mem_singleton] at hx
          subst hx
          exact hnew
      · cases h

/-- **Soundness.** An accepted certificate means no integer assignment satisfies every input
    row: the facts and the negated goal are contradictory, so the goal follows from the facts. -/
theorem sound (input : List Row) (steps : List Step) (h : check input steps = true) :
    ∀ σ : Nat → Int, (∀ r ∈ input, holds σ r) → False := by
  intro σ hin
  unfold check at h
  split at h
  · rename_i rows hrun
    split at h
    · rename_i r hlast
      have hall := run_holds σ input hin steps [] rows (by simp) hrun
      have hr := hall r (List.mem_of_getLast? hlast)
      unfold contradiction at h
      simp only [Bool.and_eq_true, decide_eq_true_eq] at h
      unfold holds at hr
      rw [dot_zero σ 0 r.c h.1] at hr
      omega
    · cases h
  · cases h

/-! ### Examples -/

-- x ≥ 1 and -x ≥ 0 (x ≤ 0): their sum is 1·x - 1·x + (-1 + 0) ≥ 0, i.e. -1 ≥ 0.
example : check [⟨[1], -1⟩, ⟨[-1], 0⟩] [.hyp 0, .hyp 1, .comb 0 1 1 1] = true := by rfl

-- 2x - 1 ≥ 0 and -2x + 1 ≥ 0 are rationally satisfiable (x = 1/2), not integrally: tightening
-- gives x - 1 ≥ 0 and -x + 0 ≥ 0, whose sum is -1 ≥ 0.
example : check [⟨[2], -1⟩, ⟨[-2], 1⟩]
    [.hyp 0, .hyp 1, .tight 0 2, .tight 1 2, .comb 2 1 3 1] = true := by rfl

-- a satisfiable pair is never accepted
example : check [⟨[1], 0⟩, ⟨[-1], 5⟩] [.hyp 0, .hyp 1, .comb 0 1 1 1] = false := by rfl

end AxionRefine
