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

### F-3 — Array threaded through helpers — FIXED (staged)
An `Array` threaded through helper functions (`fill :: Array Int -> … -> Array Int`
that fills it, `sumArr` that reads it in a recursive loop) now compiles and reclaims
the array **exactly once**, so large arrays are usable natively. `bench/array_loop.axi`
(50 M, `let` form) runs on both backends → `1249999975000000`. Delivered in two staged,
fully-gated commits:

**Stage 1 — the uniquify pass** (the prerequisite). Core violated the unique-binding
invariant (`let a …; let a …` and the `imperative do` `a <- …; a <- …` desugaring both
keep the name `a`), and the string-keyed `droppable_vars`/escape analyses conflated the
successive bindings — freeing the wrong one. A shadow-only alpha-rename pass right after
lowering makes every binding distinct (`a → a$N`). Pure renaming, behavior-preserving;
also a general latent-correctness fix.

**Stage 2 — the borrow model + case collapse.** Three pieces:
1. `native_ty += Array`, `fn_ret_ty += Array` (an `Array`-returning function produces an
   owned array); `axion_array_set` also *produces* the in-place-returned handle
   (`op_delta_effect`), so a threaded array is tracked to its final binding.
2. A **greatest-fixpoint** `compute_borrow_args`: start every `%1`-free param borrowed,
   drop any with a genuine move/alias use under the current assumptions (a dedicated
   `body_moves` that mirrors `occurs_nonborrow` — keeping copy-`UpdateRecord` = borrow,
   so `update_borrow` stays green — but is `ba`-aware for `CallDirect` and treats
   `axion_array_get`/`_len` as borrowing the array). A read-only recursive traversal
   converges to *borrowed*, so its caller keeps ownership and frees it once.
3. A **single-var `case` collapse**: the `imperative do` `a <- e` desugars to `case e of
   a -> …` (Axion's `let` is recursive, so `let` can't be used); the arm var aliases the
   scrutinee, which the reclamation mishandled. In Core the scrutinee is already forced,
   so a single Var-pattern case is a pure rebinding — collapsed to a substitution
   `a := e`, making the imperative-do form lower identically to the `let` form.

**Validation:** all forms (`let`-shadowing, `imperative do`, inline `array_sum`, helper
threading) are **ASan/LSan clean** and agree on both native backends; the two new
fixtures `array_thread_{let,do}.axi` are in the leak-free gate. Full suite green: 157
tests, sanitize 47/39, tsan 8/8, differential 3/3, check-delta 118, oracle 147/147
(regenerated — the collapse simplifies single-var cases and the fixpoint sharpens some
borrow verdicts, both behavior-preserving), bench (all kernels agree, perf unchanged),
clippy/fmt.

*(The interpreter still doesn't run `imperative`/`Array` — native-only by design,
shared with `Buffer`; and it stack-overflows on a self-referential shadowed `let`,
a pre-existing interp bug orthogonal to this work.)*

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
