# Axion by Example

A guided tour of Axion, with **progressive disclosure** (§8): each step
introduces *one* new concept, with code that runs. Follow in order — you never
see `bound`/sessions before mastering the linear core.

Assumes the compiler is built (`cd axionc && cargo build`). We use the shortcut:

```sh
AX=axionc/target/debug/axionc          # from the repo root
```

`$AX prog.axi` runs in the interpreter; `$AX --check prog.axi` only checks;
`$AX --explain AXnnnn` explains an error code.

---

## L0 — the familiar core (strict Haskell)

Anyone who knows functional programming reads this on day 1. Not a single
linearity annotation.

### 1. Hello World — `putStrLn`, IO

```haskell
main :: IO ()
main = putStrLn "Hello, Axion!"
```
```sh
$AX examples/01_hello.axi          # → Hello, Axion!
```

### 2. Fibonacci — recursion, pattern matching, `where`

```haskell
fib :: Int -> Int
fib 0 = 0
fib 1 = 1
fib n = fib (n - 1) + fib (n - 2)          -- multi-clause
```
```sh
$AX examples/02_fib.axi            # → 832040   (fib 30)
```
`examples/02_fib.axi` also shows `fibFast` with an accumulator in `where` (the
functional "loop", O(n)).

### 3. FizzBuzz — guards, `mod`, ranges, composition, `mapM_`

```haskell
fizzbuzz :: Int -> String
fizzbuzz n
  | n `mod` 15 == 0 = "FizzBuzz"
  | n `mod` 3  == 0 = "Fizz"
  | n `mod` 5  == 0 = "Buzz"
  | otherwise       = show n

main :: IO ()
main = mapM_ (putStrLn . fizzbuzz) [1 .. 15]     -- range, compose (.), mapM_
```
```sh
$AX examples/03b_fizzbuzz.axi      # → 1  2  Fizz  4  Buzz  Fizz … FizzBuzz
```
Lists (`[1..15]`, `:`, `[a,b,c]`) and `List a` come from a built-in prelude — no
need to declare anything.

### 4. Parametric sum types — `Maybe`, `Either`, `case`

```haskell
data Maybe a = None | Some a

fromMaybe :: Int -> Maybe Int -> Int
fromMaybe d m = case m of
  None   -> d
  Some x -> x

main :: Int
main = fromMaybe 0 (Some 42) + fromMaybe 7 None       -- → 49
```
```sh
$AX axionc/tests/fixtures/parametric_data.axi        # → 49
```
Constructors generalize (`Some :: forall a. a -> Maybe a`). Runs on all three
executors: `$AX --backend cranelift …` (Cranelift), `$AX --release …` (LLVM).

---

### 4b. Floating point — `Float` and the `Num` class

```haskell
main :: Float
main = 3.0 * 2.0 + 1.5                                -- → 7.5
```
```sh
$AX axionc/tests/fixtures/num_float_plain.axi         # → 7.5
```
`Float` is `f64`. Arithmetic `+ - *` (built-in **`Num`**) and comparisons
`== < >` (built-in **`Ord`**) are overloaded over `Int` and `Float` — inference
resolves each use by the operand type, and a use over `Float` is rewritten to a
dotted internal operator (`+` → `+.`, `<` → `<.`) that the backends lower directly
(so there is still no type-directed codegen). A `Num a =>` / `Ord a =>` function
specializes per type, Rust-style:

```haskell
sq :: Num a => a -> a
sq x = x * x
main :: Float
main = sq 3.0 + sq 2.0                                -- → 13  (sq$Int / sq$Float)
```

`Num`/`Ord` do **not** coerce: `3 + 2.0` is a type error. Conversions bridge the
two worlds explicitly — `toFloat :: Int -> Float`, `truncate :: Float -> Int`:

```haskell
main :: Int
main = truncate (toFloat 7 /. 2.0)                    -- → 3  (3.5 truncated)
```

Unary math builtins `sqrt`, `floor`, `abs` (`:: Float -> Float`) lower to native
Cranelift IEEE instructions / LLVM intrinsics (`sqrt 2.0` → `1.4142135623730951`
on all three — `--release` prints the shortest round-tripping decimal, not lossy
`%g`).

Division `/.` stays Float-only (`Int` has no `/`); the dotted forms `+. <. …`
remain valid (they are the internal rewrite targets). The class name `Ord` is
distinct from a user's `Eq` (whose methods are identifiers like `eq`), so there
is no collision — and the prelude's `Ord` (`maxOr`/`minOr`, via `le`) now works
on `Float` too. Under the uniform i64 native ABI the `f64` travels as its
bit-pattern; the operators bitcast `i64 ↔ f64` (`toFloat`/`truncate` are
`sitofp`/`fptosi`). All three executors agree bit-for-bit.

---

## L1 — linearity and GC-free memory (the differentiator)

Axion's core: every datum has an owner, and the compiler frees it at exact static
points. No GC, no manual `free`.

### 5. `%1`: consume once — `AX0001`

A linear resource `%1` can be **read** (borrowed) freely, but **consumed** (moving
ownership) only once. Consuming twice is an error:

```sh
$AX --check axionc/tests/fixtures/use_after_consume.axi   # → error[AX0001]
$AX --explain AX0001                                       # the rule and the fix
```
Reading before consuming is free; **using after moving** is `AX0004`.

### 6. *Must-use* vs Auto-Drop — `AX0002`

Types without `Drop` (`Ep`, `Token`, handles) are *must-use*: dropping them is
`AX0002`. *Droppable* types are managed by **Auto-Drop** — the compiler inserts
the `free` at the death point. See where:

```sh
$AX --emit drops axionc/tests/fixtures/heap_loop.axi   # the `free`s and their reasons
```

### 7. Linear buffer — `%1` in action (§4/§5)

`Buffer` is the **linear** byte array: allocate, operate in-place, and free
without leaks. It is **native** runtime (bulk operations live in the C/Rust
runtime, vectorizable), so it runs with `--backend cranelift` or `--release`:

```sh
$AX --backend cranelift axionc/tests/fixtures/buffer_sum.axi   # → 4950   (sum of bytes)
$AX --check examples/03_linear_buffer.axi                       # the §5 target (alloc+op+free)
```
With `AXION_HEAP_STATS=1 $AX --backend cranelift …` you see `allocs == frees`.

### 8. In-place update — Linear Elision (Listing 2.1)

When the base of a record update is linear and dies there, the compiler
**mutates the block** instead of allocating+copying:

```sh
$AX --check examples/04_process_inplace.axi     # typecheck
$AX --emit inplace examples/04_process_inplace.axi   # the in-place updates
```

---

## L2 — regions and arenas (§3)

For data whose lifetime fits in a scope, an **arena** reclaims everything in a
single reset.

### 9. Arena escape — `AX0003`

A value allocated in a sub-arena cannot escape its scope (otherwise it would
outlive the reset). The compiler rejects it and says how to fix (`promote`):

```sh
$AX --check axionc/tests/fixtures/arena_escape.axi   # → error[AX0003] + help
$AX --explain AX0003
```
`arena_promote_ok.axi` shows the correct version (with `promote parent v`).

---

## L3 — concurrency: channels and session types (§6/§9)

Here Axion sets itself apart: communication **free of data races and deadlocks,
proven by types**. A channel moves ownership; `bound` confines endpoints to a tree.

### 10. A typed protocol — session types (§6)

```haskell
worker :: Ep (Send Int End) %1 -> IO ()      -- sends ONE Int and finishes
worker chan = do
  c2 <- send chan 42
  close c2
```
```sh
$AX --check axionc/tests/fixtures/session_ok.axi     # follows the protocol → accepted
```
Doing `recv` where the type says `Send` is `AX0300`; dropping without `close` is
`AX0301`.

### 11. Concurrency ACTUALLY RUNNING — `bound` + `spawn` (§9/§11)

`bound` opens a nursery; `spawn` forks a child linked by a channel. A concurrent
ping-pong that actually computes:

```sh
$AX axionc/tests/fixtures/session_run_pingpong.axi   # → 42   (parent sends 21, worker doubles)
```

### 12. Choice and cancellation — `select`/`offer`/`Closed` (§7)

```sh
$AX axionc/tests/fixtures/session_run_offer.axi      # → 7   (select Live → Live branch)
$AX axionc/tests/fixtures/session_run_cancel.axi     # → 5   (cancel → the peer receives Closed)
```
`Closed` is a normal branch of the protocol — cancellation of a panicking peer is
always handleable (T5, §7).

### 13. The guarantees, enforced

The compiler rejects dangerous topologies *before* running:

```sh
$AX --check axionc/tests/fixtures/bound_escape.axi     # AX0302: endpoint escapes the nursery
$AX --check axionc/tests/fixtures/session_spawn_capture.axi  # AX0305: spawn would capture a cycle
$AX --check axionc/tests/fixtures/exhaustive_missing.axi  # AX0202: `case` misses a constructor
$AX --explain AX0302     # why: the topology must be a tree
```
Pattern matching is checked for **exhaustiveness** (`AX0202`: a `case` must cover
every constructor, or carry a `_`) — so adding a constructor to a `data` surfaces
every `case` that forgot it — and for **redundancy** (`AX0203`, a warning: an arm
after a catch-all is unreachable).

---

## L4 — general-purpose: typeclasses, HOF, IO (all native)

Axion grows toward a Rust/Haskell. These pieces compile **all the way to native**
(`--release`), not just in the interpreter.

### 14. Higher-order + IO — `map`/`filter`/`foldr`, `mapM_`, `compose`

```haskell
main :: IO ()
main = mapM_ (putStrLn . fizzbuzz) [1 .. 15]     -- partial compose, putStrLn as a value
```
```sh
$AX --release examples/03b_fizzbuzz.axi     # the full FizzBuzz, in machine code
```
Top-level functions as values (`mapM_ greet xs`), partial application
(`compose f g`) and the prelude HOFs compile via **eta-expansion + closures**.

### 15. Typeclasses — `class`/`instance`, `Eq a =>`, zero-cost

```haskell
class Eq a where
  eq :: a -> a -> Bool

instance Eq Int where
  eq x y = x == y

count :: Eq a => a -> List a -> Int              -- constrained polymorphism
count x xs = case xs of
  Nil       -> 0
  Cons y ys -> if eq x y then 1 + count x ys else count x ys

main :: Int
main = count 7 [7, 1, 7, 7]                       -- → 3
```
```sh
$AX --release examples/06_typeclasses.axi         # → 6
```
**Monomorphization** specializes `count` per type (`count$Int`) and resolves `eq`
to the instance (`eq$Int`), which LLVM inlines — **zero-cost abstraction, à la
Rust** (measured: the `dispatch` benchmark ≈ C/Rust, [`docs/benchmarks.md`](benchmarks.md)).
Coherence is checked statically: missing instance, extra method, use without an
instance → `AX0400`–`AX0405`.

### 16. `deriving (Eq, Ord, Show)` — instances for free

```haskell
data Color = Red | Green | Blue
  deriving (Eq, Ord, Show)

main :: IO ()
main = putStrLn (show Green)                       -- → Green
```
```sh
$AX axionc/tests/fixtures/derive_show_enum.axi     # → Green
```
The `deriving` clause synthesizes **structural** instances (as Axion source that
is parsed like any other, so it goes through the same monomorphization and
compiles to native): `Eq` compares constructor-then-fields; `Ord` orders by
constructor declaration order, then lexicographically by field; `Show` renders
the constructor name and each field (`show (Rect 2 3)` → `"Rect 2 3"`). `Show` is
a real class now (`show :: Show a => a -> String`) with base instances for
`Int`/`Float`/`Bool`; native string building uses `strAppend`. A hand-written
`instance` always wins over a derived one.

**Parametric types** derive too — `deriving` on `data Maybe a` generates the
constrained instance `instance Eq a => Eq (Maybe a)`, and a use at a concrete
element specializes the impl (`show$Maybe$Color`, with the inner `show` resolving
to `show$Color`) so it compiles natively, nesting included:

```haskell
data Color = Red | Green | Blue deriving (Eq, Ord, Show)
data Maybe a = None | Some a    deriving (Eq, Ord, Show)
main :: IO ()
main = putStrLn (show (Some Green))                -- → Some Green
```
Native specialization currently covers a **single** type parameter (`Maybe`,
`List`, …); multi-parameter types (`Either a b`) derive and run in the
interpreter, but do not yet compile natively.

---

## Where to go next

- **Networking**: [`docs/networking.md`](networking.md) — TCP sockets via FFI.
- **Arrays**: [`docs/array.md`](array.md) — packed mutable arrays with linear ownership.
- **Stream fusion**: [`docs/fusion.md`](fusion.md) — automatic list elimination.
- How the compiler works: [`docs/backend.md`](backend.md).
- The session calculus formalized: [`docs/phase-3-calculus.md`](phase-3-calculus.md).
- All error codes: [`docs/error-codes.md`](error-codes.md) (or `$AX --explain AXnnnn`).
