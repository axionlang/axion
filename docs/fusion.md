# Stream fusion — automatic list elimination

Stream fusion rewrites `consumer (range lo hi)` into a fused loop that never
allocates list cells. It is enabled by default and runs on **all functions** in
the lowering pipeline — no `--fuse` flag needed.

## How it works

The fusion pass (`fuse_list_ops` in `core.rs`) scans each function's Core IR for
the pattern:

```
let _t0 = call range lo hi       -- producer
ret call sum _t0                  -- consumer
```

And rewrites it to:

```
ret call rangeFusedSum lo hi 0   -- direct arithmetic loop
```

### Producers and consumers

| Producer  | Fuses? | Reason                                          |
|-----------|--------|-------------------------------------------------|
| `range`   | Yes    | Always safe — pure arithmetic without state     |
| `map`     | No     | Would drop the transformation (unsound)         |
| `filter`  | No     | Same — stateful producer                        |
| `take`    | No     | Same — stateful producer                        |
| `drop`    | No     | Same — stateful producer                        |

| Consumer     | Step                | Base   |
|-------------|---------------------|--------|
| `sum`       | Synthesized `(+)`   | 0      |
| `length`    | Synthesized `(+1)`  | 0      |
| `null`      | Synthesized `False` | `True` |
| `foldr f z` | User's closure `f`  | `z`    |
| `foldl f z` | Not implemented     | —      |

### Specializations

**`sum (range lo hi)`** → `rangeFusedSum lo hi 0`

A dedicated prelude function with no closure — pure `+` arithmetic in a
tail-recursive loop. LLVM algebraically reduces this to `N(N+1)/2` at
compile time for constant `N`, or to a tight loop for variable `N`.

**`foldr f z (range lo hi)`** → `rangeFused lo hi f z`

The user's closure `f` is passed through. `rangeFused` calls `f lo (rangeFused (lo+1) hi f z)`
— tail-recursive, each iteration applies the step.

## Pre-fusion vs post-fusion

```
-- Pre-fusion (before this session):
sum (range 1 10_000_000)  →  10M Cons cells allocated → 629 ms

-- Post-fusion (auto-enabled):
sum (range 1 10_000_000)  →  rangeFusedSum 1 10M 0 → <1 ms (LLVM constant-folds)
sum (range 1 200_000_000) →  rangeFusedSum 1 200M 0 → <1 ms (same)
```

## Cross-function fusion

Fusion runs on **all functions**, not just `main`. A helper function:

```haskell
work :: Int -> Int
work n = sum (range 1 n)   -- fused to: rangeFusedSum 1 n 0
```

Is fused independently. When `work` is called from `main`, the fused version is
used — no intermediate list.

## Implementation

| File       | Function             | Purpose                              |
|------------|----------------------|--------------------------------------|
| `core.rs`  | `fuse_list_ops`      | Entry point — called unconditionally |
| `core.rs`  | `fuse_term`          | Recursive traversal of Core IR       |
| `core.rs`  | `matching_consumer`  | Detects `sum`/`length`/`null`/`foldr` |
| `core.rs`  | `build_fused`        | Emits specialized `rangeFusedSum` or `rangeFused` |
| `main.rs`  | `rangeFused`         | Generic closure-based fusion         |
| `main.rs`  | `rangeFusedSum`      | Sum-specific: no closure overhead    |

## Current limitations

- **No `foldl` fusion.** Only `foldr`-based consumers (`sum`, `length`, `null`,
  `foldr f z`) are fused. `foldl` requires a different rewriting strategy.
- **No producer chains.** `sum (filter p (range 1 N))` does not fuse — only
  single-producer, single-consumer patterns.
- **Pre-lowering pass.** Fusion runs on the Core IR after lowering, before
  `insert_drops`. It cannot see through complex control flow or variable
  aliasing.
