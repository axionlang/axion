#!/usr/bin/env bash
# Session M:N scaling benchmark (§11): objective data for the work-stealing
# decision (Layer 2b-3). Two measurements on this machine:
#
#   1. COMPUTE-BOUND (bench/sess_compute.axi): four workers each computing fib 34,
#      one channel exchange each. Wall time vs AXION_SESS_THREADS should fall
#      near-linearly up to the worker count — the thread pool doing its job.
#   2. MUTEX CEILING (bench/sess_mutex.c): the scheduler's single global lock
#      hammered by N threads with a tiny op each — the contended ops/sec above
#      which a channel-bound workload would be capped (and where 1→2 threads
#      already slows down from contention).
#
# Interpretation: work-stealing raises (2); it only matters once a workload can
# SUSTAIN channel-op rates near that ceiling. Today none can — the session subset
# has no recursion (so no channel loops) and the generator's resume-region
# duplication is O(N^2) in the suspension count (a 60-worker fan-in already blows
# up to >1M lines of IR), so any expressible program does only a few hundred
# channel ops in microseconds. See docs/session-scaling.md.
#
# Run:  AXION_CLANG=<clang> ./scripts/session-scaling.sh
set -uo pipefail
cd "$(dirname "$0")/.."

CLANG="${AXION_CLANG:-clang}"
if ! "$CLANG" --version >/dev/null 2>&1; then
  echo "no clang (set AXION_CLANG or put clang on PATH) — skipping"
  exit 0
fi
AXIONC="axionc/target/debug/axionc"
[ -x "$AXIONC" ] || (cd axionc && cargo build -q)
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

cores=$(nproc 2>/dev/null || echo '?')
echo "machine: ${cores} cores"
echo

echo "1) compute-bound (bench/sess_compute.axi: 4× fib 34) — wall time vs threads:"
"$AXIONC" --emit llvm bench/sess_compute.axi >"$WORK/c.ll" 2>/dev/null
"$CLANG" -O2 -flto -w -pthread "$WORK/c.ll" axionc/src/axion_rt.c -o "$WORK/compute"
for t in 1 2 4 8; do
  best=""
  for _ in 1 2 3; do
    s=$( { TIMEFORMAT="%R"; time AXION_SESS_THREADS="$t" "$WORK/compute" >/dev/null; } 2>&1 )
    if [ -z "$best" ] || awk -v s="$s" -v b="$best" 'BEGIN{exit !(s+0<b+0)}'; then best=$s; fi
  done
  echo "   threads=$t  wall=${best}s"
done
echo

echo "2) global-mutex ceiling (bench/sess_mutex.c) — contended channel-op rate:"
"$CLANG" -O2 -pthread bench/sess_mutex.c -o "$WORK/mb"
for t in 1 2 4 8; do "$WORK/mb" "$t" 5000000; done
echo
echo "→ compute-bound scales with threads; the mutex ceiling (~tens of M ops/s,"
echo "  worse under contention) is unreachable by any expressible session today."
