/-
  AxionExtract — SPIKE (feasibility probe) for heap-extracting `case` in the M2 faithfulness bridge.

  The bridge (`--emit model-trace` → `AxionDrop.acceptsL`) excludes `case` patterns that BIND heap
  payloads (`case xs of Cons h t -> …`) — the dominant real idiom. Closing it requires the model to
  distinguish two kinds of extraction, which is exactly `AxionAlias.lean`'s owner/borrow content:

    * OWNED-scrutinee peel (`xs : %1`): the shell is consumed and the payloads become FRESH OWNERS.
      This already lives in `AxionMove`'s vocabulary — `moveOut` the shell, treat each payload as an
      `alloc`'d owner. No new machinery.
    * BORROWED-scrutinee peel: each payload is an INTERIOR ALIAS (`bref`) of the scrutinee. Using it
      is fine WHILE the owner is live; dropping it is a double-free (DropOfAlias); moving/returning it
      is the borrow-escape hazard (the AX0912 class). This IS new machinery.

  `AxionAlias` proves all this — but RELATIONALLY, over `St := Nat → Cell` (a function), which does
  NOT reduce under `by rfl`, so it cannot back a bridge example (`… = verdict := by rfl`).

  THE SPIKE QUESTION (Unknown #1): can the owner/borrow semantics be re-expressed over a FINITE
  assoc-list state (`List (Nat × Cell)`, as `AxionMove.lean` does) and given an executable
  `acceptsL : Expr → Bool` that `rfl`-computes the right verdicts on owned/borrowed peels? If yes,
  heap-extracting `case` is bridgeable and the full merge (soundness proof + AxionKey drop-keys +
  widening `model_trace`) is tractable. This file answers that by construction; the `by rfl` examples
  at the end are the evidence. (Feasibility scope: the relational spec + executable checker + the
  computing examples. The full `chk_correct`/`sound` port is Phase 2.)
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

inductive Chk : St → Expr → St → Prop where
  | done {S} : Chk S .done S
  | op   {S S' Sf a k} : rstep S a = some S' → Chk S' k Sf → Chk S (.op a k) Sf
  | brn  {S Sm Sf t e k} : Chk S t Sm → Chk S e Sm → Chk Sm k Sf → Chk S (.brn t e k) Sf

def sInit : St := fun _ => .fresh
/-- Leak-free = no live OWNER remains. A `bref`/`moved`/`freed` is not a leak. -/
def leakFree (S : St) : Prop := ∀ n, S n ≠ .live
def accepts (e : Expr) : Prop := ∃ Sf, Chk sInit e Sf ∧ leakFree Sf

/-! ## Executable checker over a finite assoc-list state (the bridge core). Mirrors `AxionMove`. -/

def lookupC (n : Nat) : List (Nat × Cell) → Cell
  | [] => .fresh
  | (m, c) :: rest => if m = n then c else lookupC n rest

def toSt (l : List (Nat × Cell)) : St := fun n => lookupC n l
def setC (n : Nat) (c : Cell) (l : List (Nat × Cell)) : List (Nat × Cell) := (n, c) :: l
def keysOf (l : List (Nat × Cell)) : List Nat := l.map Prod.fst

def allC (p : Nat → Bool) : List Nat → Bool
  | [] => true
  | k :: ks => p k && allC p ks

def leakFreeL (l : List (Nat × Cell)) : Bool :=
  allC (fun n => decide (lookupC n l ≠ .live)) (keysOf l)

def stEqL (a b : List (Nat × Cell)) : Bool :=
  allC (fun n => decide (lookupC n a = lookupC n b)) (keysOf a ++ keysOf b)

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

/-- A program is accepted iff it checks from `[]` to a leak-free state. -/
def acceptsL (e : Expr) : Bool :=
  match chkL [] e with
  | some l => leakFreeL l
  | none => false

/-! ## The make-or-break `rfl` probe (Unknown #1).

    Each `acceptsL … = verdict := by rfl` below MUST reduce for the model to back a bridge example.
    They encode the owner/borrow extraction distinction the verifier enforces. -/

-- OWNED peel: consume the shell (`moveOut 0`), payload `1` becomes an owner, then freed. Accepted.
example : acceptsL (.op (.alloc 0) (.op (.moveOut 0) (.op (.alloc 1) (.op (.drop 1) .done)))) = true := by rfl

-- BORROWED peel, read then free the owner: `use` the alias WHILE owner live, then `drop 0`. Accepted.
example : acceptsL (.op (.alloc 0) (.op (.borrow 1 0) (.op (.use 1) (.op (.drop 0) .done)))) = true := by rfl

-- DropOfAlias: dropping the extracted alias `1` is a double-free of owner `0`. REJECTED.
example : acceptsL (.op (.alloc 0) (.op (.borrow 1 0) (.op (.drop 1) .done))) = false := by rfl

-- Borrow-escape: moving/returning the alias `1` (the AX0912 class). REJECTED.
example : acceptsL (.op (.alloc 0) (.op (.borrow 1 0) (.op (.moveOut 1) (.op (.drop 0) .done)))) = false := by rfl

-- UseAfterFree: free the owner `0`, then read the dangling alias `1`. REJECTED.
example : acceptsL (.op (.alloc 0) (.op (.borrow 1 0) (.op (.drop 0) (.op (.use 1) .done)))) = false := by rfl

-- Branch divergence at extraction: one arm frees the owner, the other returns an alias of it →
-- the arms end in different states (freed vs bref), so the join rejects (V-1 conditional-return).
example : acceptsL (.op (.alloc 0) (.brn (.op (.drop 0) .done) (.op (.borrow 1 0) (.op (.moveOut 1) .done)) .done)) = false := by rfl

-- Forgetting the owner is still a leak (a borrowed peel must still dispose the owner). REJECTED.
example : acceptsL (.op (.alloc 0) (.op (.borrow 1 0) (.op (.use 1) .done))) = false := by rfl

end AxionExtract
