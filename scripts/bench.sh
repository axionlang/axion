#!/usr/bin/env bash
# Micro-benchmark suite (§13): compares Axion's TWO backends — --dev
# (Cranelift, no opt) and --release (LLVM -O2 -flto) — against C and Rust at -O0/-O2.
# Kernels: fib (recursion/branches), loop (200M arithmetic iterations), alloc (40M
# allocations — arena in Axion, malloc/Box in C/Rust), simd (vectorizable reduction;
# Axion N/A — §4 to be built). Uses the SAME clang (LLVM) for C and for
# Axion --release, so the tier is comparable. Needs clang (AXION_CLANG
# or on PATH; e.g. `nix shell nixpkgs#llvmPackages_18.clang`).
#
# Measured (2026-08) and verified at the LLVM-IR/assembly level: the C-vs-Axion
# gap on `dispatch` (~20%) and `sumtype` (~28%) was an LLVM shape-dependent
# optimisation — C's while-loop phi enters with a constant range letting LLVM
# lower `mod n 1000000` to `urem` (unsigned magic-multiply, ~5 instrs) while
# Axion's recursion enters from a function argument, opaque to range analysis
# (`srem` + sign fixup, ~8 instrs). The fix emits `urem` for `mod` with small
# positive constant divisors (< 2^30, where the unsigned magic-multiply is
# faster), closing the `dispatch` gap entirely and `sumtype` to 1.6 %. The
# remaining `sumtype` difference is the different loop shape (TCO'd recursion
# vs while), and `srem` is kept for large divisors (e.g. 2147483647 in `loop`)
# where the unsigned path regresses. On `sumtype` the C variant additionally
# benefits from algebraic reduction of the cyclic val/turn sum, a C-loop-shape
# bonus untouched by this change. Benchmarks compare like-for-like.
# `-O3` is byte-identical to `-O2` on all six kernels; TCO already fires.
set -uo pipefail
cd "$(dirname "$0")/.."

AXIONC="${AXIONC:-axionc/target/debug/axionc}"
CLANG="${AXION_CLANG:-clang}"
RT="axionc/src/axion_rt.c"
RUNS="${RUNS:-3}"

# Perf-regression gate (§13): the correctness check below guards RESULTS; this guards SPEED.
# The metric is the machine-RELATIVE ratio  Axion(--release) / C(-O2)  per kernel — a ratio,
# not absolute ms, so it is portable across machines and cancels CPU-speed differences. The
# baseline is stored (like the Core oracle); `--check` fails if any kernel's ratio has
# regressed beyond TOL. Only kernels whose C(-O2) time clears a floor are gated (tiny times are
# timer noise). Usage:  bench.sh [--snapshot | --check]  (no arg = table only, no gate).
MODE="report"
case "${1:-}" in
  --snapshot) MODE="snapshot" ;;
  --check)    MODE="check" ;;
  "")         ;;
  *) echo "usage: bench.sh [--snapshot | --check]"; exit 2 ;;
esac
BASELINE="bench/perf-baseline.txt"
TOL="${PERF_TOL:-25}"        # allowed % regression of the Axion/C ratio before --check fails
FLOOR_MS="${PERF_FLOOR_MS:-20}"  # skip kernels whose C(-O2) time is under this (noise)
# For the gate, take more samples so the best-of is a tighter lower bound.
[ "$MODE" = report ] || RUNS="${RUNS_GATE:-7}"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

echo "Building axionc…"
(cd axionc && cargo build -q) || exit 2
command -v "$CLANG" >/dev/null 2>&1 || { echo "clang not found (set AXION_CLANG)"; exit 2; }
have_rust=1; command -v rustc >/dev/null 2>&1 || have_rust=0

# timeit CMD…  → lowest time (ms) in MS, stdout in OUT (best of RUNS).
timeit() {
  local best="" out t0 t1 ms
  for _ in $(seq "$RUNS"); do
    t0=$(date +%s%N); out=$("$@"); t1=$(date +%s%N)
    ms=$(((t1 - t0) / 1000000))
    if [ -z "$best" ] || [ "$ms" -lt "$best" ]; then best=$ms; fi
  done
  MS=$best; OUT=$out
}

declare -A T R           # T[kernel:variant]=ms   R[kernel:variant]=result
run() { local key="$1"; shift; if [ "$1" = "SKIP" ]; then T[$key]="-"; R[$key]=""; return; fi
        timeit "$@"; T[$key]=$MS; R[$key]=$OUT; }

bench_kernel() {
  local k="$1"
  # Axion --dev (JIT)
  run "$k:dev" "$AXIONC" --backend cranelift "bench/$k.axi"
  # Axion --release (LLVM -O2 -flto)
  if "$AXIONC" --emit llvm "bench/$k.axi" > "$tmp/$k.ll" 2>/dev/null \
     && "$CLANG" -O2 -flto -w -pthread "$tmp/$k.ll" "$RT" -o "$tmp/${k}_rel" 2>/dev/null; then
    run "$k:rel" "$tmp/${k}_rel"
  else run "$k:rel" SKIP; fi
}
bench_c() {
  local k="$1"
  "$CLANG" -O0 "bench/$k.c" -o "$tmp/${k}_c0" 2>/dev/null && run "$k:c0" "$tmp/${k}_c0" || run "$k:c0" SKIP
  "$CLANG" -O2 "bench/$k.c" -o "$tmp/${k}_c2" 2>/dev/null && run "$k:c2" "$tmp/${k}_c2" || run "$k:c2" SKIP
}
bench_rust() {
  local k="$1"; [ "$have_rust" = 1 ] || { run "$k:r0" SKIP; run "$k:r2" SKIP; return; }
  rustc -C opt-level=0 "bench/$k.rs" -o "$tmp/${k}_r0" 2>/dev/null && run "$k:r0" "$tmp/${k}_r0" || run "$k:r0" SKIP
  rustc -C opt-level=2 "bench/$k.rs" -o "$tmp/${k}_r2" 2>/dev/null && run "$k:r2" "$tmp/${k}_r2" || run "$k:r2" SKIP
}

KERNELS="fib loop alloc simd dispatch sumtype tritvec dot_i8 ternmv i8mv i32mv"
for k in $KERNELS; do bench_kernel "$k"; bench_c "$k"; bench_rust "$k"; done

echo
echo "Times (ms, best of $RUNS) — the same clang (LLVM) for C and for Axion --release:"
printf "  %-7s %8s %8s | %7s %7s | %7s %7s\n" "kernel" "Ax --dev" "Ax --rel" "C -O0" "C -O2" "Rs -O0" "Rs -O2"
printf "  %-7s %8s %8s | %7s %7s | %7s %7s\n" "------" "--------" "--------" "-----" "-----" "------" "------"
for k in $KERNELS; do
  printf "  %-7s %8s %8s | %7s %7s | %7s %7s\n" "$k" \
    "${T[$k:dev]}" "${T[$k:rel]}" "${T[$k:c0]}" "${T[$k:c2]}" "${T[$k:r0]}" "${T[$k:r2]}"
done

echo
# checks correctness: per kernel, all present results must match.
ok=1
for k in $KERNELS; do
  ref=""
  for v in dev rel c0 c2 r0 r2; do
    r="${R[$k:$v]:-}"; [ -n "$r" ] || continue
    if [ -z "$ref" ]; then ref="$r"; elif [ "$r" != "$ref" ]; then
      echo "WARNING: $k/$v = '$r' ≠ '$ref'"; ok=0
    fi
  done
done
[ "$ok" = 1 ] && echo "OK: in each kernel, all variants agree on the result." || exit 1

# ---- perf-regression gate ----------------------------------------------------
# Ratio (×100, integer) of Axion --release to C -O2 for a kernel, or "" if either
# side is missing / below the noise floor.
perf_ratio() {
  local k="$1" rel="${T[$1:rel]:-}" c2="${T[$1:c2]:-}"
  [ "$rel" != "-" ] && [ -n "$rel" ] || { echo ""; return; }
  [ "$c2" != "-" ] && [ -n "$c2" ] || { echo ""; return; }
  [ "$c2" -ge "$FLOOR_MS" ] || { echo ""; return; }
  echo $(( rel * 100 / c2 ))
}

if [ "$MODE" = snapshot ]; then
  : > "$BASELINE"
  {
    echo "# Axion(--release) / C(-O2) ratio ×100 per kernel — the perf-regression baseline."
    echo "# Regenerate with: scripts/bench.sh --snapshot   (on a quiet machine). Gate: --check."
    for k in $KERNELS; do
      r=$(perf_ratio "$k"); [ -n "$r" ] && printf "%s %s\n" "$k" "$r"
    done
  } >> "$BASELINE"
  echo "wrote perf baseline → $BASELINE"
  echo "NOTE: commit it from a QUIET machine; the ratio (not ms) is what's stored, so it is portable."
elif [ "$MODE" = check ]; then
  [ -f "$BASELINE" ] || { echo "no $BASELINE — run: scripts/bench.sh --snapshot"; exit 2; }
  regress=0
  printf "\nPerf gate (Axion/C-O2 ratio ×100, tolerance +%s%%):\n" "$TOL"
  printf "  %-8s %8s %8s %8s\n" "kernel" "base" "now" "verdict"
  while read -r k base; do
    case "$k" in ''|\#*) continue ;; esac
    now=$(perf_ratio "$k")
    if [ -z "$now" ]; then printf "  %-8s %8s %8s %8s\n" "$k" "$base" "-" "skip(noise/na)"; continue; fi
    limit=$(( base * (100 + TOL) / 100 ))
    if [ "$now" -gt "$limit" ]; then
      printf "  %-8s %8s %8s %8s\n" "$k" "$base" "$now" "REGRESS"; regress=1
    else
      printf "  %-8s %8s %8s %8s\n" "$k" "$base" "$now" "ok"
    fi
  done < "$BASELINE"
  if [ "$regress" = 1 ]; then
    echo "PERF REGRESSION: a kernel's Axion/C ratio exceeded baseline by >${TOL}%. (Re-run on a quiet machine to rule out noise; --snapshot to rebaseline if intended.)"
    exit 1
  fi
  echo "OK: no kernel regressed beyond +${TOL}% of its baseline Axion/C ratio."
fi
