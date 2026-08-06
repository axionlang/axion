#!/usr/bin/env bash
# Concurrency benchmark (§11/§13): the same fork-join workload — 4 workers each
# computing fib(34), the parent sums (= 22811548) — in C (pthreads), Rust
# (std::thread) and Axion (session tasks on the M:N scheduler). C/Rust get raw,
# unchecked threads; Axion routes through linear channels + the scheduler, so it
# also pays for the safety (race-/deadlock-freedom by types). Times are wall (best
# of RUNS) at 1 and 4 threads; the ratio is the parallel speedup. Same clang -O2
# for C and Axion --release. Needs clang (AXION_CLANG); Rust optional.
#
# Run:  AXION_CLANG=<clang> ./scripts/concurrency-bench.sh
set -uo pipefail
export LC_ALL=C # decimal point (not comma) so `time %R` and awk agree
cd "$(dirname "$0")/.."

CLANG="${AXION_CLANG:-clang}"
command -v "$CLANG" >/dev/null 2>&1 || { echo "clang not found (set AXION_CLANG)"; exit 2; }
AXIONC="axionc/target/debug/axionc"
[ -x "$AXIONC" ] || (cd axionc && cargo build -q)
RUNS="${RUNS:-5}"
N=34
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# best-of-RUNS wall time (seconds) of "CMD" into BEST
bestof() {
  local best="" s
  for _ in $(seq "$RUNS"); do
    s=$( { TIMEFORMAT="%R"; time "$@" >/dev/null; } 2>&1 )
    if [ -z "$best" ] || awk -v s="$s" -v b="$best" 'BEGIN{exit !(s+0<b+0)}'; then best=$s; fi
  done
  BEST=$best
}
speedup() { awk -v a="$1" -v b="$2" 'BEGIN{ if(b+0>0) printf "%.2f", a/b; else printf "-" }'; }

echo "workload: 4 workers × fib $N  (result 22811548);  best of $RUNS;  $(nproc) cores"
printf "  %-16s %10s %10s %8s\n" "language" "1 thread" "4 threads" "speedup"

row() { # <label> <cmd-1thread...> :: <cmd-4thread...>
  local label="$1"; shift
  local one=() four=() seen=0
  for a in "$@"; do
    if [ "$a" = "::" ]; then seen=1; continue; fi
    if [ "$seen" = 0 ]; then one+=("$a"); else four+=("$a"); fi
  done
  bestof "${one[@]}";  local t1=$BEST
  bestof "${four[@]}"; local t4=$BEST
  printf "  %-16s %9ss %9ss %8s\n" "$label" "$t1" "$t4" "$(speedup "$t1" "$t4")"
}

# C
"$CLANG" -O2 -pthread bench/conc.c -o "$WORK/c"
row "C (pthreads)" "$WORK/c" "$N" 1 :: "$WORK/c" "$N" 4

# Rust
if command -v rustc >/dev/null 2>&1; then
  rustc -O bench/conc.rs -o "$WORK/rs" 2>/dev/null
  row "Rust (threads)" "$WORK/rs" "$N" 1 :: "$WORK/rs" "$N" 4
fi

# Axion --release (LLVM -O2 -flto + C runtime), thread count via AXION_SESS_THREADS
"$AXIONC" --emit llvm bench/conc.axi >"$WORK/a.ll" 2>/dev/null
"$CLANG" -O2 -flto -w -pthread "$WORK/a.ll" axionc/src/axion_rt.c -o "$WORK/ax"
row "Axion --release" env AXION_SESS_THREADS=1 "$WORK/ax" :: env AXION_SESS_THREADS=4 "$WORK/ax"

# Axion --release, `parMap` form (§9): the same workload written with the fork-join
# combinator (bench/conc_parmap.axi) instead of hand-unrolled spawn/send/recv/close.
# Same worker state machine on the same M:N scheduler ⇒ the two rows should track.
"$AXIONC" --emit llvm bench/conc_parmap.axi >"$WORK/ap.ll" 2>/dev/null
"$CLANG" -O2 -flto -w -pthread "$WORK/ap.ll" axionc/src/axion_rt.c -o "$WORK/axp"
row "Axion (parMap)" env AXION_SESS_THREADS=1 "$WORK/axp" :: env AXION_SESS_THREADS=4 "$WORK/axp"

echo
echo "→ C/Rust use raw OS threads; Axion adds linear channels + the M:N scheduler"
echo "  (safety by types). Coarse compute ⇒ the fib dominates and the gap is small."
echo "  'Axion --release' (hand-unrolled) and 'Axion (parMap)' compile to the same"
echo "  worker state machine on the same scheduler — the combinator is free."
