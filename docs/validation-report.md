# Validation report — changes since `985d04c`

**Date:** 2026-08-06. **Scope:** the 21 commits / ~75k insertions since `985d04c`
(Array, Stream Fusion, Network IO, Module system, stdlib, per-field ownership, the
Δ linearity validator). **Method:** run every gate + benchmark, capture the current
ground truth, adversarially probe the new features, and reconcile the docs.

**Environment:** Intel i5-9300HF, 8 cores; clang 21.1.8; rustc/cargo 1.95.0; nix +
GHC present. All external tools available — no gates skipped.

## 1. Headline: the claims hold

- **Performance parity with C — CONFIRMED.** `--release` (LLVM `-O2 -flto`) vs C `-O2`
  (same clang), best of 3:

  | kernel | Ax `--rel` | C `-O2` | Rs `-O2` | verdict |
  |--------|-----------:|--------:|---------:|---------|
  | fib      | 265 | 249 | 299 | ~6% of C |
  | loop     | 536 | 535 | 537 | parity |
  | alloc    |  25 | 310 | 491 | **~12× faster** (arena) |
  | simd     |  34 |  34 |  31 | parity |
  | dispatch | 465 | 464 | 557 | parity |
  | sumtype  | 451 | 430 | 565 | ~5% of C |

  All variants **agree on the result** per kernel (correctness gate). Concurrency
  (fork-join fib34×4): Axion **3.63×** vs C 3.93× / Rust 3.72× — parity. Measured ≈
  documented.

- **Memory & concurrency safety — CONFIRMED.** ASan **45** fixtures corruption-free,
  LSan **37** proven leak-free, ThreadSanitizer **8/8** session fixtures race-free.

- **Correctness gates — GREEN.** `cargo test` **156** (114 integration + 41 unit + 1
  property); dump-oracle **147/147**; check-delta **118** accepted / 29 front-end
  rejections; GHC differential **3/3**; check-negative passes; fusion sound (results
  agree across interp/`--dev`/`--release`).

## 2. Ground-truth gate numbers (supersede the drifted doc figures)

| gate | measured | previously cited (drifted) |
|------|---------:|----------------------------|
| `cargo test` | **156** | 141 / 145 / 148 / 153 |
| dump-oracle | **147** | 132 / 137 |
| check-delta | **118** / 29 | 103 / 108 |
| sanitize (ASan / LSan) | **45 / 37** | 33/27, 38/32 |
| tsan | **8** | (n/a) |
| differential | **3/3** | 3/3 |

The docs cite per-phase snapshots that drifted apart; §5 corrects the primary ones.

## 3. Findings

### F-1 — Clippy gate was RED (FIXED in this pass)
`822e007` ("Cargo rules tightness") added `unwrap_used = "deny"` / `expect_used =
"warn"` to `Cargo.toml [lints]`, which apply to *all* targets, but the test crates
carried no allow header → `cargo clippy --all-targets -- -D warnings` (the exact CI
command) failed with ~210 errors. This contradicted the docs' "clippy clean" and CI
would have failed identically. **Fixed:** allow headers on the integration-test
crates + a test-profile `cfg_attr(test, allow(unwrap_used, expect_used,
redundant_pub_crate))` (production stays strict); 3 real src lints fixed
(interp needless-range-loop, core collapsible-if-let, a justified `cast_ptr_alignment`
allow in `axion_array_new`). Gate is now GREEN; fmt/test still green.

### F-2 — `docs/array.md` substantially overclaims (docs, not safety)
`Array` is **`Int`-valued only**: `newArray :: Int -> Int -> Array a`, `getArray ::
Array a -> Int -> Int`, `setArray :: Array a -> Int -> Int -> Array a` — the element
type `a` is **phantom** (no operation moves a value of type `a` in or out). So:
- The documented `Array (List P)` heap-element story and the ~200-line
  `gen_mono_array_destructors` / `axion_drop_Array$List$P` machinery are **dead code**
  — no well-typed program can set `elem_ty` to a heap type (nothing constrains it, and
  `array_ret_tys` stores un-zonked types), so the array destructor is **always the flat
  `axion_drop_Array` (`axion_array_free`)**. Confirmed by `--emit core` on several
  forced-heap-element attempts.
- The doc example `newArray 100 (Nil :: List P)` **does not parse** (inline `::` is
  unsupported) and would not type-check (init is `Int`).
- OOB claim is wrong: docs say "getArray returns 0 / setArray no-op"; the runtime
  actually **`abort()`s with a bounds message** (`axion_rt.c` `axion_array_get/set`) —
  *safer* than documented, but not what the docs say.

**Safety consequence: none negative** — because heap elements are unreachable and OOB
aborts, Array is memory-safe (Int-only, bounds-checked, flat free; `array_sum.axi`
ASan-clean). The gap is accuracy + dead code, not a hole.

### F-3 — Array can't express large arrays natively (feature gap; root cause found)
`imperative do` has no loops, and a recursive helper over `Array Int` (e.g. `fill ::
Array Int -> Int -> Int -> Array Int`) makes `main` **non-native** on both backends.
`bench/array_loop.axi` had wrong `Int` signatures (didn't type-check) and is orphaned
from `bench.sh`; signatures corrected to `Array Int` here (now type-checks) but it
still cannot run natively.

**Root cause (diagnosed, three layers):**
1. `native_ty` (core.rs) omitted `Array` from the native head-constructor whitelist,
   so any signature mentioning `Array` fails `top_candidate` → interp-only → `main`
   non-native. (One-liner.)
2. `fn_ret_ty`/`op_delta_effect.produces` only tracks `boxed` (user `data`) results,
   so an `Array`-returning function isn't recognized as producing an owned array →
   the returned array is never reclaimed. (Small addition.)
3. **The blocker:** `compute_borrow_args` classifies a param as a pure borrow only if
   it never occurs in a non-borrow position, but a read-only recursive traversal
   (`sumArr a … sumArr a …`) passes the array to its **own recursive call**, which
   `occurs_nonborrow` counts as a move (it cannot yet know the recursive param is
   itself a borrow). So the array is neither borrowed-and-dropped-by-caller nor
   owned-and-dropped-by-callee → **it leaks** (`let` form) or **double-frees** (the
   `imperative do` → nested-`case` form, where the case-var alias also drops the
   moved-in scrutinee). Verified under ASan/LSan.

Applying only layers 1–2 makes `array_loop` compile but **leak/UAF** — worse than
"won't compile" — so those changes were **reverted**; the compiler stays sound
(Array is inline-only). The real fix is a **fixpoint borrow analysis**: a param is a
pure borrow if all its uses are borrows *assuming* the function's own recursive-call
positions are borrows (a greatest fixpoint over `compute_borrow_args`), plus threading
`Array` through `native_ty`/`fn_ret_ty` and propagating case-var-alias escape. That is
memory-safety-critical (a wrong "borrowed" verdict is a double-free), so it needs its
own design + full ASan/LSan/differential validation and Array threading fixtures — a
scoped follow-up, not a one-liner.

### F-4 — Executor coverage (by design, worth stating)
`Array` / `Buffer` / `imperative` and bench-scale fused loops **do not run in the
interpreter** (`newArray`/`imperative` unimplemented there; fusion+TCO are native
only, so `fused_loop.axi` stack-overflows in interp while both native backends agree).
So the "three executors agree" invariant holds for the pure/functional subset; Array
and imperative programs are `--dev` + `--release` only. `land_tuple_upd.axi`'s comment
claims a native "3==3" but it is an interp/Δ-oracle fixture (native-reject) — a comment
inaccuracy.

## 4. Adversarial audit results (the requested depth)
- **Array aliasing / double-free** (the prior `inner y` class): **not reachable** —
  the `Int`-only API means no heap element, and even a phantom `Array (heap)` gets a
  flat free (no Int-as-pointer wild-free). OOB is a clean abort, not an overflow.
- **Generic poly-drop** (`poly_payload_generic_{drop,nested,compose}`): agree across
  all three executors, in the sanitize/leak-free gate.
- **Fusion soundness**: `sum`/`length`/`map` over `range` agree across executors; the
  `101/100` on a `map` chain is the known closure-conservative leak (documented class),
  not new.
- **Per-field ownership** (`land_*`, skip-destructors): agree across native backends,
  in the gates.
No new memory-safety violation was found; the audit's net is F-2/F-3 (Array is safe
but narrower and less runnable than documented).

## 5. Doc reconciliation (applied)
- `docs/array.md`: correct the OOB behavior (abort, not 0), mark the heap-element /
  `axion_drop_Array$…` section as **not implemented / aspirational**, and state the
  native recursive-helper limitation. 
- `docs/benchmarks.md`, `README.md`: refresh the measured table and gate counts to §1–§2.
- `docs/delta-design.md`, `docs/per-field-ownership.md`: the per-phase snapshot numbers
  are historical; a dated note points here for the current ground truth rather than
  rewriting each phase row.

## 6. Reproduce
```sh
cd axionc && cargo test && cargo clippy --all-targets -- -D warnings && cargo fmt --check
AXION_CLANG=clang ./scripts/{dump-oracle,check-delta,sanitize,tsan}.sh
./scripts/{differential,check-negative}.sh          # nix + GHC
AXION_CLANG=clang RUNS=3 ./scripts/bench.sh
AXION_CLANG=clang RUNS=5 ./scripts/concurrency-bench.sh
```
