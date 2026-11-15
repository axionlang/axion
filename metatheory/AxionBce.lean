/-
  AxionBce — soundness of the bounds-check elimination guard (`axionc/src/bce.rs`).

  A counting loop runs a check-free clone when an entry guard holds. This file proves that the
  guard is enough: at EVERY iteration the loop executes, the index the machine computes lies in
  `[0, len)`, and the counter never wraps.

  The model is the pass's own arithmetic, in 64-bit two's complement (`wrap`):
    * `guard` is the conjunction the pass emits, each `+ - *` wrapped exactly as the backends
      compute it (`$bce` lets: `c > -1`, `room = len - c`, `room > 0`, `s > 0`,
      `s_safe = s * (s > 0) + (1 - (s > 0))`, `q = (room - 1) / s_safe`, `q + 1 > n` / …);
    * `Runs e n j0 j` — the loop body runs with counter `j` (it starts at `j0` and steps by one,
      wrapping, until the exit test holds), for the four exit forms the pass recognizes;
    * the access index is `wrap (c + wrap (s * j))` — the machine value of `c + s * j` with `c`
      and `s` the machine values of the invariant parts.
  Inputs are 64-bit values; array lengths are below 2^62 (an allocation of `8 * len` bytes).

  `sound` is the theorem for a stride `s ≠ 0`; `sound_const` covers a stride-0 access (one index,
  `c`). `axionc/src/bce.rs`'s `guard_matches_the_model` test evaluates the emitted guard Core on
  random and edge inputs and checks every index the loop then takes, tying the code to this model.
-/

namespace AxionBce

def M : Int := 9223372036854775808   -- 2^63
def W : Int := 18446744073709551616  -- 2^64
def B : Int := 4611686018427387904   -- 2^62: arrays are shorter than this

/-- Two's-complement wrap to a signed 64-bit value. -/
def wrap (x : Int) : Int := (x + M) % W - M

/-- A 64-bit value. -/
def I64 (x : Int) : Prop := -M ≤ x ∧ x < M

theorem wrap_id {x : Int} (h : I64 x) : wrap x = x := by
  unfold wrap I64 M W at *
  rw [Int.emod_eq_of_lt (by omega) (by omega)]
  omega

/-- The exit forms: `j > n`, `j >= n`, `j == n` (counting up), `j < 0` (counting down). -/
inductive Exit where
  | gt | ge | eq | down

def exits : Exit → Int → Int → Prop
  | .gt, j, n => j > n
  | .ge, j, n => j ≥ n
  | .eq, j, n => j = n
  | .down, j, _ => j < 0

def next : Exit → Int → Int
  | .down, j => wrap (j - 1)
  | _, j => wrap (j + 1)

/-- The loop body runs with counter `j`. -/
inductive Runs (e : Exit) (n j0 : Int) : Int → Prop
  | start : ¬ exits e j0 n → Runs e n j0 j0
  | step {j : Int} : Runs e n j0 j → ¬ exits e (next e j) n → Runs e n j0 (next e j)

/-- `1` if the comparison holds, else `0` (the backends' `zext i1`). -/
def b2i (p : Bool) : Int := if p then 1 else 0

/-- The guard for one access with stride `s` and offset `c`, as `bce.rs` emits it. -/
def guard (e : Exit) (c s len j0 n : Int) : Prop :=
  let room := wrap (len - c)
  let sp := b2i (decide (s > 0))
  let sSafe := wrap (wrap (s * sp) + wrap (1 - sp))
  let q := wrap (room - 1) / sSafe
  (e ≠ .down → j0 > -1) ∧
  (e = .eq → wrap (n + 1) > j0) ∧
  c > -1 ∧ room > 0 ∧ s > 0 ∧
  (match e with
   | .gt => wrap (q + 1) > n
   | .ge | .eq => wrap (q + 2) > n
   | .down => wrap (q + 1) > j0)

/-- The arithmetic core: `0 ≤ c < len`, `s ≥ 1`, `0 ≤ j ≤ (len - 1 - c) / s` put `c + s*j` in
    `[0, len)`, with `0 ≤ s*j ≤ len - 1 - c`. -/
theorem index_bounds {c s len j : Int} (_hc : 0 ≤ c) (_hcl : c < len) (hs : 1 ≤ s)
    (hj0 : 0 ≤ j) (hjq : j ≤ (len - 1 - c) / s) :
    0 ≤ s * j ∧ s * j ≤ len - 1 - c := by
  have h1 : s * j ≤ s * ((len - 1 - c) / s) :=
    Int.mul_le_mul_of_nonneg_left hjq (by omega)
  have h2 : (len - 1 - c) / s * s ≤ len - 1 - c := Int.ediv_mul_le _ (by omega)
  have h3 : 0 ≤ s * j := Int.mul_nonneg (by omega) hj0
  rw [Int.mul_comm] at h2
  omega

/-- What the guard gives, in plain integers. -/
structure Facts (e : Exit) (c s len j0 n q : Int) : Prop where
  c0 : 0 ≤ c
  cl : c < len
  s1 : 1 ≤ s
  qdef : q = (len - 1 - c) / s
  q0 : 0 ≤ q
  ql : q ≤ len
  up : e ≠ .down → 0 ≤ j0
  eqn : e = .eq → j0 ≤ n
  fit : match e with
    | .gt => n ≤ q
    | .ge | .eq => n ≤ q + 1
    | .down => j0 ≤ q

theorem guard_facts {e : Exit} {c s len j0 n : Int} (hl : 0 ≤ len ∧ len < B)
    (hc : I64 c) (hs : I64 s) (hn : I64 n) (hj : I64 j0) (g : guard e c s len j0 n) :
    Facts e c s len j0 n ((len - 1 - c) / s) := by
  unfold guard at g
  obtain ⟨gup, geq, gc, groom, gs, gfit⟩ := g
  unfold I64 M B at *
  have room : wrap (len - c) = len - c := wrap_id (by unfold I64 M; omega)
  rw [room] at groom gfit
  have sp : b2i (decide (s > 0)) = 1 := by simp [b2i, gs]
  rw [sp] at gfit
  have e1 : wrap (s * 1) = s := by rw [Int.mul_one]; exact wrap_id (by unfold I64 M; omega)
  have e2 : wrap (1 - 1) = 0 := by decide
  have e3 : wrap (s + 0) = s := by rw [Int.add_zero]; exact wrap_id (by unfold I64 M; omega)
  have e4 : wrap (len - c - 1) = len - c - 1 := wrap_id (by unfold I64 M; omega)
  rw [e1, e2, e3, e4] at gfit
  have hsub : len - c - 1 = len - 1 - c := by omega
  rw [hsub] at gfit
  have q0 : 0 ≤ (len - 1 - c) / s := Int.ediv_nonneg (by omega) (by omega)
  have qle : (len - 1 - c) / s ≤ len - 1 - c := Int.ediv_le_self _ (by omega)
  have w1 : wrap ((len - 1 - c) / s + 1) = (len - 1 - c) / s + 1 :=
    wrap_id (by unfold I64 M; omega)
  have w2 : wrap ((len - 1 - c) / s + 2) = (len - 1 - c) / s + 2 :=
    wrap_id (by unfold I64 M; omega)
  refine ⟨by omega, by omega, by omega, rfl, q0, by omega, fun h => by have := gup h; omega,
    fun h => ?_, ?_⟩
  · have := geq h
    have w : wrap (n + 1) = n + 1 ∨ n = M - 1 := by
      by_cases hm : n = 9223372036854775807
      · right; unfold M; omega
      · left; exact wrap_id (by unfold I64 M; omega)
    rcases w with w | w
    · rw [w] at this; omega
    · -- n = MAX: n + 1 wraps to MIN, and `MIN > j0` is false
      unfold M at w
      subst w
      have : wrap (9223372036854775807 + 1) = -9223372036854775808 := by decide
      omega
  · cases e with
    | gt => simp only at gfit; rw [w1] at gfit; show n ≤ _; omega
    | ge => simp only at gfit; rw [w2] at gfit; show n ≤ _; omega
    | eq => simp only at gfit; rw [w2] at gfit; show n ≤ _; omega
    | down => simp only at gfit; rw [w1] at gfit; show j0 ≤ _; omega

/-- The counter range for each exit form: `j0 ..= n` (`>`), `j0 .. n` (`>=`, `==`), `0 ..= j0`
    (counting down). -/
def Inv : Exit → Int → Int → Int → Prop
  | .gt, j0, n, j => j0 ≤ j ∧ j ≤ n
  | .ge, j0, n, j => j0 ≤ j ∧ j < n
  | .eq, j0, n, j => j0 ≤ j ∧ j < n
  | .down, j0, _, j => 0 ≤ j ∧ j ≤ j0

/-- Every counter the body runs with is in its range, and stepping never wraps (the bound is
    small: `n ≤ len + 1 < 2^62 + 1`; an `==` loop starts at or below `n`). -/
theorem runs_inv {e : Exit} {n j0 j : Int} (hn : e ≠ .down → n ≤ B) (hj : I64 j0)
    (heq : e = .eq → j0 ≤ n) (r : Runs e n j0 j) : Inv e j0 n j := by
  unfold B at hn
  unfold I64 M at hj
  induction r with
  | start hx =>
    cases e with
    | gt => simp [exits] at hx; exact ⟨Int.le_refl _, by omega⟩
    | ge => simp [exits] at hx; exact ⟨Int.le_refl _, by omega⟩
    | eq => have := heq rfl; simp [exits] at hx; exact ⟨Int.le_refl _, by omega⟩
    | down => simp [exits] at hx; exact ⟨by omega, Int.le_refl _⟩
  | step r hx ih =>
    cases e with
    | gt =>
      have hn := hn (by simp)
      obtain ⟨a, b⟩ := ih
      simp only [next] at hx ⊢
      rw [wrap_id (by unfold I64 M; omega)] at hx ⊢
      simp [exits] at hx; exact ⟨by omega, by omega⟩
    | ge =>
      have hn := hn (by simp)
      obtain ⟨a, b⟩ := ih
      simp only [next] at hx ⊢
      rw [wrap_id (by unfold I64 M; omega)] at hx ⊢
      simp [exits] at hx; exact ⟨by omega, by omega⟩
    | eq =>
      have hn := hn (by simp)
      obtain ⟨a, b⟩ := ih
      simp only [next] at hx ⊢
      rw [wrap_id (by unfold I64 M; omega)] at hx ⊢
      simp [exits] at hx; exact ⟨by omega, by omega⟩
    | down =>
      obtain ⟨a, b⟩ := ih
      simp only [next] at hx ⊢
      rw [wrap_id (by unfold I64 M; omega)] at hx ⊢
      simp [exits] at hx; exact ⟨by omega, by omega⟩

/-- The counters the loop body runs with stay in `[0, (len - 1 - c) / s]`. -/
theorem runs_range {e : Exit} {c s len j0 n j : Int} (hl : 0 ≤ len ∧ len < B)
    (f : Facts e c s len j0 n ((len - 1 - c) / s)) (hj : I64 j0) (r : Runs e n j0 j) :
    0 ≤ j ∧ j ≤ (len - 1 - c) / s := by
  have q0 := f.q0
  have ql := f.ql
  have fit := f.fit
  unfold B at hl
  cases e with
  | gt =>
    simp only at fit
    have hi := runs_inv (fun _ => by unfold B; omega) hj (by simp) r
    have hu := f.up (by simp); simp only [Inv] at hi; omega
  | ge =>
    simp only at fit
    have hi := runs_inv (fun _ => by unfold B; omega) hj (by simp) r
    have hu := f.up (by simp); simp only [Inv] at hi; omega
  | eq =>
    simp only at fit
    have hi := runs_inv (fun _ => by unfold B; omega) hj f.eqn r
    have hu := f.up (by simp); simp only [Inv] at hi; omega
  | down =>
    simp only at fit
    have hi := runs_inv (fun h => absurd rfl h) hj (by simp) r
    simp only [Inv] at hi; omega

/-- **Soundness of the guard (stride `s ≠ 0`).** If the guard holds at entry, then at every
    iteration the loop runs, the machine index `wrap (c + wrap (s * j))` is in `[0, len)`. -/
theorem sound {e : Exit} {c s len j0 n j : Int} (hl : 0 ≤ len ∧ len < B)
    (hc : I64 c) (hs : I64 s) (hn : I64 n) (hj0 : I64 j0)
    (g : guard e c s len j0 n) (r : Runs e n j0 j) :
    0 ≤ wrap (c + wrap (s * j)) ∧ wrap (c + wrap (s * j)) < len := by
  have f := guard_facts hl hc hs hn hj0 g
  obtain ⟨jlo, jhi⟩ := runs_range hl f hj0 r
  obtain ⟨b0, b1⟩ := index_bounds f.c0 f.cl f.s1 jlo jhi
  have := f.c0
  have := f.cl
  unfold B at hl
  rw [wrap_id (x := s * j) (by unfold I64 M; omega)]
  rw [wrap_id (by unfold I64 M; omega)]
  omega

/-- **Stride 0** (`elimBelow`'s `ix n k k`): one index `c`, guarded by `c > -1` and
    `len - c > 0`. -/
theorem sound_const {c len : Int} (hl : 0 ≤ len ∧ len < B) (hc : I64 c)
    (g : c > -1 ∧ wrap (len - c) > 0) : 0 ≤ c ∧ c < len := by
  obtain ⟨g0, g1⟩ := g
  unfold I64 M B at *
  rw [wrap_id (by unfold I64 M; omega)] at g1
  omega

/-! ## Axiom audit. -/
#print axioms sound
#print axioms sound_const

end AxionBce
