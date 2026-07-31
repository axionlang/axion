#!/usr/bin/env bash
# ThreadSanitizer gate (§11): the M:N session scheduler runs tasks on a thread
# pool, so — like memory safety (scripts/sanitize.sh) — race-freedom must be
# proven, not asserted. Each concurrent session fixture is compiled (its --release
# LLVM IR + the C runtime) with `-fsanitize=thread` and run; a data race makes the
# gate fail. Session-type linearity makes every channel SPSC and one mutex guards
# the shared state, so a clean run is the expected outcome (a race would be a
# runtime bug). Needs clang.
#
# Run:  AXION_CLANG=<clang> ./scripts/tsan.sh
set -uo pipefail
cd "$(dirname "$0")/.."

CLANG="${AXION_CLANG:-clang}"
if ! "$CLANG" --version >/dev/null 2>&1; then
  echo "no clang (set AXION_CLANG or put clang on PATH) — skipping ThreadSanitizer"
  exit 0
fi

AXIONC="axionc/target/debug/axionc"
if [ ! -x "$AXIONC" ]; then
  echo "building axionc..."
  (cd axionc && cargo build -q) || { echo "build failed"; exit 2; }
fi
RT="axionc/src/axion_rt.c"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# concurrent session fixtures (name → expected output) that drive the scheduler.
CASES=(
  "session_run_pingpong 42"
  "session_run_offer 7"
  "session_run_cancel 5"
  "session_run_twospawn 42"
  "session_run_choice3 2"
  "session_run_fib 6765"
  "session_run_parfib 300100" # four workers in parallel — the real stress
  "session_run_server 63"     # recursive session: a server loop (§6)
)

fail=0
ok=0
for entry in "${CASES[@]}"; do
  name="${entry% *}"
  want="${entry##* }"
  f="axionc/tests/fixtures/$name.axi"
  [ -f "$f" ] || continue
  if ! "$AXIONC" --emit llvm "$f" >"$WORK/ir.ll" 2>/dev/null; then
    echo "· $name: not in the native subset (skipped)"
    continue
  fi
  "$CLANG" -fsanitize=thread -pthread -O1 -w "$WORK/ir.ll" "$RT" -o "$WORK/exe" 2>/dev/null
  # a few repetitions: races are scheduling-dependent, so give TSan chances to see them
  race=0
  bad=0
  for _ in 1 2 3; do
    out=$(TSAN_OPTIONS=halt_on_error=1 "$WORK/exe" 2>"$WORK/err")
    grep -q "WARNING: ThreadSanitizer" "$WORK/err" && race=1
    [ "$out" = "$want" ] || bad=1
  done
  if [ "$race" -ne 0 ]; then
    echo "✗ $name: DATA RACE under ThreadSanitizer"
    grep -A3 "WARNING: ThreadSanitizer" "$WORK/err" | head -4
    fail=1
  elif [ "$bad" -ne 0 ]; then
    echo "✗ $name: wrong result (expected $want)"
    fail=1
  else
    echo "✓ $name: TSan clean, result $want"
    ok=$((ok + 1))
  fi
done

echo "---"
if [ "$fail" -eq 0 ]; then
  echo "OK: $ok concurrent session fixtures race-free under ThreadSanitizer."
else
  echo "FAILURE: a data race (or wrong result) was detected."
fi
exit $fail
