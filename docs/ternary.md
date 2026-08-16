# Ternary: `Trit` and `TritVec` (spec §10, roadmap Phase 5a)

Two separable things live here, exactly as the spec separates them:

1. **`Trit`** — an ordinary three-state enum. Always available, zero-cost.
2. **`TritVec`** — the *optional* base-243 packed array. Implemented, correct,
   leak-free — and **off by default**, because the measurement below says a
   *scalar* base-243 codec does not earn a default over the loose forms.

## `Trit` — the balanced-ternary enum (§10.A)

Defined in the prelude as an ordinary N=3 sum type (the ternary analogue of
`Ordering`):

```haskell
data Trit = TMinus | TZero | TPlus   -- weights -1 / 0 / +1
```

A value-selecting `case` over it lowers branchless like any small enum — that
property is the small-enum backend's, not something the ternary adds (§10.A). It
runs on all three executors (interp / Cranelift / LLVM); see
`tests/fixtures/trit_enum.axi`.

## `TritVec` — base-243 packing (§10.B), a native linear resource

`TritVec` packs five balanced trits into one byte (`3^5 = 243 ≤ 256`, 99.1%
density vs 79.2% for a loose 2-bit form). A trit is carried as an `Int` **weight**
`-1/0/+1`. The API mirrors `Array` (a flat, single-allocation linear resource,
auto-dropped via the flat `axion_free` — no destructor):

```haskell
newTritVec :: Int -> Int -> TritVec        -- (len, initWeight)
getTritVec :: TritVec -> Int -> Int         -- borrow, returns the weight
setTritVec :: TritVec -> Int -> Int -> TritVec   -- in-place, consumes+returns
lenTritVec :: TritVec -> Int
```

- **Native-only** (like `Array`): runs on Cranelift `--dev` and LLVM `--release`.
- **Linear + leak-free**: threaded through helpers exactly like `Array`
  (`fillTrit` owns, `sumTrit` borrows). ASan + LSan clean — 1 alloc == 1 free
  (`scripts/sanitize.sh`, `tests/fixtures/tritvec_roundtrip.axi`).
- **Codec**: a **256-entry lookup table** (`TRIT_LUT[byte][k]` → weight), the
  scalar path the spec prescribes (§10.C) — one table load per byte replaces the
  per-trit radix-3 `div/mod`. Both native codecs ship it: `axion_rt.c`
  (`__attribute__((constructor))`-filled) and `codegen.rs` (compile-time `const`).
  PDEP/BMI2 and SIMD (`PSHUFB`/`TBL`) fast paths are **deliberately not built**:
  the spec warns against hard-depending on PEXT/PDEP (microcoded/slow on Zen 1/2),
  and — see below — even the LUT does not quite reach the 1-byte baseline, so the
  SIMD investment stays gated on a workload that is genuinely bandwidth-bound.

## The decision gate — MEASURE before committing (§10.B, §14 #07)

The spec is explicit that base-243 is worth its unpack cost *only* when a workload
is genuinely memory-bandwidth bound — the concrete case being ternary-quantized ML
weight arrays `{-1,0,+1}`. `bench/tritvec_codec.c` measures the identical quantized
dot-product over four representations of the same N weights (all agree on the
result — correctness gate):

| representation | bytes/trit | 64M weights | 512M weights |
|----------------|-----------:|------------:|-------------:|
| base-243, `div/mod` (old) | 0.20 | 116 ms | 939 ms |
| **base-243, LUT-256 (shipped)** | 0.20 | **44 ms** | **359 ms** |
| 2-bit (loose)     | 0.25 |  73 ms |  585 ms |
| 1-byte (`Array Trit`) | 1.00 | **36 ms** | **290 ms** |

(Intel i5-9300HF, clang -O2, best of 3–5.)

**Verdict.** The LUT-256 codec is **~2.6× faster** than the old `div/mod` and now
**beats the loose 2-bit form** (0.60×) at 25% smaller footprint — so base-243 is
the best *packed* representation. It is still **~1.2× behind 1-byte**: on this
machine a plain multiply-accumulate isn't bandwidth-bound enough for the 5× density
to overcome even one table lookup per byte. So:

- base-243 (LUT) ships as the codec, **correct and fast**, but `TritVec` stays
  **off by default** — a program that never calls `newTritVec` pays nothing, and
  where raw speed matters over footprint, `Array Trit` (1-byte) still wins.
- The remaining ~1.2× to 1-byte is the only gap SIMD could close (many bytes
  decoded per instruction, finally exploiting the density when truly
  bandwidth-bound). That stays gated on a real ternary-ML kernel that is
  bandwidth-bound — the spec's "measured exception, not the rule."

This is the Phase 5a gate outcome: the ternary story is real and shipping as an
opt-in library with the spec's prescribed codec, and the honest measurement — not
a claim — decides how far to push it.

### Cross-language reality check (Axion vs C vs Rust)

The same dot product across languages (`bench/{tritvec,dot_i8}.{axi,c,rs}`, N=50M,
`Ax --release` vs `C/Rust -O2`, ms):

| representation | Axion | C | Rust | footprint |
|---|---:|---:|---:|---|
| packed `TritVec` (base-243) | 533 | 456 | 431 | 10 MB |
| dense — natural per language | 416 (`Array`, i64) | **149** (`int8`) | **149** (`Vec<i8>`) | int8 50 MB · Axion `Array` 400 MB |

Two honest conclusions:

- **Axion is slower here, and that's expected.** C/Rust reach for `int8` and finish
  in 149 ms; Axion has no native int8 array (its `Array` is i64, 8 B/elem) so its
  fastest option is 416 ms. On raw throughput, hand-written C/Rust win ~2.8×.
- **But `TritVec` is *Axion's* compact answer, not a speed play.** Packing costs
  speed in every language (C/Rust `int8` is ~3× faster than their own packed form;
  even Axion `Array` beats `TritVec`). Its payoff is footprint — and that payoff is
  ~5× in C/Rust vs **~40×** in Axion (10 MB vs `Array`'s 400 MB). So `TritVec`
  earns its keep only when 50M+ ternary weights must fit in cache/RAM, which is
  precisely why it is **off by default**.

### Faster without giving up footprint or safety — the fused `tritDot`

The per-element `getTritVec` pays a call + bounds check per trit. The fused
`tritDot :: TritVec -> Array Int -> Int` decodes 5 trits/byte via the LUT and
multiply-accumulates against a dense activation `Array` in **one pass** — the
BitNet-style quantized matvec inner loop (`axion_tritvec_dot`, mirroring
`axion_buf_sum`). Measured on the reduce alone (50M trits, fill amortized over 20
passes, `--release`):

| reduce | ms / pass (50M) |
|---|---:|
| per-element `getTritVec` loop | ~166 |
| **fused `tritDot`** | **~53** |

**~3.1× faster**, and near C's own packed-dot cost (~44 ms) — so the fused path
essentially closes the reduce gap to hand-written C. Crucially it costs **nothing**
on the two axes we care about: the packed store is untouched (footprint stays
0.2 B/trit, the op allocates nothing) and it is a pure **borrow** of both operands
(one up-front bounds check, all LUT indices valid, linearity/Auto-Drop unchanged —
ASan + LSan clean, `tests/fixtures/tritvec_dot.axi`).

### The bigger win — bulk builders fix the fill

Once the reduce was fused, the *end-to-end* kernel was **fill**-bound, and profiling
found the real culprit: packing a `TritVec` element-by-element cost **~320 ms for
just 10 MB**, because each `setTritVec` is a read-modify-write into a shared packed
byte (5 trits/byte) — serial, non-vectorizable, one bounds check per trit.

The fix is a bulk builder that writes whole packed bytes in one native pass,
mirroring `axion_buf_iota`:

- **`tritVecIota :: Int -> TritVec`** — packs `weight(i)=(i mod 3)-1`, one write per
  byte: **~320 ms → ~55 ms (~6×)**.
- **`arrayIota :: Int -> Array Int`** — `a[i]=i` in one vectorizable pass.

End-to-end (`bench/tritvec.{axi,c,rs}`, N=50M, `--release` vs `-O2`), the packed
kernel goes from ~671 ms to **308 ms — ~parity with C (271) and faster than Rust
(291)**; `--dev` drops from ~13 s to ~5 s. Both builders are **owned resources**
Auto-Dropped once (ASan + LSan clean, `tests/fixtures/tritvec_iota.axi`), and the
packed store is unchanged (footprint stays 0.2 B/trit — they allocate nothing extra).

What was left is the 400 MB i64 activation array (memory-bound), an artifact of the
microbenchmark using a full-size activation vector — which the realistic matvec
below fixes.

### Where packing finally wins on speed — the ternary matvec

A real BitNet-style matvec doesn't use a 50M activation: weights are `M×K` (huge,
packed), the activation is a *small* `K`-vector reused across all `M` rows. So only
the packed weights stream; the activation stays cache-resident. `tritMatVecSum ::
TritVec -> Array Int -> Int -> Int` (`axion_tritvec_matvec_sum`) does exactly this —
one fused pass, borrows both, `k` wraps by counter. Now the 5× smaller footprint
becomes a **speed** win, because packing moves 10 MB where int8 moves 50 MB:

| matvec (N=50M, K=8192) | Axion `--rel` | C `-O2` | Rust `-O2` |
|---|---:|---:|---:|
| **packed ternary** (`ternmv`, weights 10 MB) | **107** | 85 | 118 |
| int8 (`i8mv`, weights 50 MB) | 139 | 105 | 125 |

Packed beats int8 in **every** language (Axion 107 < 139, C 85 < 105, Rust 118 <
125), and Axion's *packed* matvec (107) beats hand-written **Rust int8** (125) and
essentially ties **C int8** (105). This is the footprint-as-speed payoff the whole
feature is for — and the packed kernel dropped from 308 ms (full activation) to
107 ms (~2.9×) just by using the realistic activation shape. ASan + LSan clean
(`tests/fixtures/tritvec_matvec.axi`).

### Phase B — a compact `I8Array` closes the int8 gap

The dense side was hobbled by Axion's `Array` being i64 (8 B/element), so int8-style
data moved 8× more memory than it should. `I8Array` (Phase B) is a compact
**signed-byte** array — `newI8Array` / `i8Iota` / `getI8` (sign-extended) / `setI8`
(in-place) / `lenI8` / `i8MatVecSum`, wired across all three backends, owned/borrow
linearity, ASan + LSan clean (`tests/fixtures/i8array_{run,matvec}.axi`). It cut
Axion's int8 matvec from **380 ms** (i64 `Array`, 400 MB) to **139 ms** (I8Array,
50 MB) — ~2.7×, now within ~1.3× of hand-written C int8 (105). The general fix for
the root cause: dense narrow-int data no longer pays for 8-byte slots.

**Generalized (the durable payoff).** These patterns were then lifted out of the
ternary corner into reusable primitives, since they help any dense narrow-int
workload: fused closure-free reductions on the workhorse `Array Int` (`arraySum`,
`arrayDot`), the same on `I8Array` (`i8Sum`, `i8Dot`), and a full compact **`I32Array`**
(4 B/element — new/iota/get/set/len + `i32Sum`/`i32Dot`/`i32MatVecSum`). The matvec
now shows a clean memory→speed gradient by width — packed 10 MB (106 ms) < int8
50 MB (144) < int32 200 MB (159) ≪ i64 400 MB (387) — with `I32Array` at parity
with C (159 vs 157). See `docs/benchmarks.md` and
`tests/fixtures/{array_reduce,i8_reduce,i32array_run,i32_reduce}.axi`. (Design note:
three concrete widths is pragmatic; a parametric width-tagged array is the clean
future consolidation.)

Remaining levers (not built): a SIMD `tritMatVecSum` (spec §10.C) and
`tritVecFromBuffer` to load real pre-packed weights.

## When the footprint wins (applications)

The density advantage only converts to value when memory **capacity** or
**bandwidth** is the binding constraint — the case the one-pass microbenchmark
above is *not*, but several real workloads are. Where a 5×–40× smaller ternary
array matters:

- **Ternary-quantized LLMs** (BitNet b1.58, 2024) — weights are literally
  `{-1,0,+1}`. At GB scale, inference is bandwidth-bound (every token streams the
  full weight matrix from RAM), so 5× less data moved is *faster and lower-energy*:
  here density **becomes** speed. A 7B model is ~7 GB at int8 vs ~1.4 GB packed —
  the difference between fitting in RAM/VRAM / on-device and not.
- **Cache residency** — if packing makes a hot array fit in L2/L3 when the loose
  form doesn't, main-memory traffic is eliminated entirely (10 MB fits L3; 50/400
  MB don't). A repeatedly-scanned working set that is cache-resident *only when
  packed* flips the benchmark result.
- **Embedded / edge / real-time — Axion's target niche.** KB–MB of SRAM is a hard
  limit, not a preference; 40× smaller than Axion's i64 `Array` can decide
  ship-vs-not for an on-device ternary model or 3-state buffer.
- **Non-ML 3-state data at scale** — genomics genotype calls
  `{hom-ref, het, hom-alt}` over billions of sites; Kleene / 3-valued logic in
  SAT/CSP/model-checkers (the spec's `observe` → `Trit`: Closed/Pending/Live);
  board-state (Go points empty/black/white); sign-sketches / ternary hashing;
  balanced-ternary numerics.
- **Serialization & transfer** — 5× smaller on-disk model files, mmap'd arrays,
  and over-the-wire size (plus the energy to move them).

Through-line: the win is real **only** when capacity- or bandwidth-bound, it is
~40× for Axion (no native small-int array) vs ~5× for C/Rust, and fully exploiting
it at LLM scale wants the deferred **fused/SIMD bulk decode** — today's
`getTritVec` decodes one trit per call, which leaves the bandwidth win on the table.

## Not built (out of scope, per spec gating)

- SIMD/PDEP base-243 codecs (Phase 5a fast path — gated on the benchmark above).
- Advanced type topology `~` / `Maybe~` (Phase 5b — gated on mechanized metatheory).
- `observe :: Endpoint s %1 -> Trit` (session-topology feature; `Trit` is ready
  as its result type when `observe` is implemented).
