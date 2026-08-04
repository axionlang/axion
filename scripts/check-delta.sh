#!/usr/bin/env bash
# Δ-1 gate: the linearity validator (docs/delta-design.md §8) must accept every
# fixture that reaches the Core. Report-only today (--check-delta runs before
# Emit::Core and prints a verdict without touching lowering/codegen), so this
# gate is the overfitting guard: rejecting a valid program is a checker bug
# (the oracle snapshot is the test); the negative side is covered by sanitize
# (27 proven leak-free) and differential.
#
# Verdicts:
#   · "Δ ok"            — front-end OK, Core reached, validator accepts
#   · "Δ FAILED: N…"    — the validator found a violation (GATE FAILURE)
#   · front-end error   — rejection fixture: never reaches Core (Δ doesn't run)
#
# Run:  ./scripts/check-delta.sh
set -uo pipefail
cd "$(dirname "$0")/.."

AXIONC="axionc/target/release/axionc"
if [ ! -x "$AXIONC" ]; then
  echo "building axionc..."
  (cd axionc && cargo build --release -q) || { echo "build failed"; exit 2; }
fi

inputs() { ls axionc/tests/fixtures/*.axi examples/*.axi 2>/dev/null; }

ok=0; rejected=0; fail=0
for f in $(inputs); do
  out=$("$AXIONC" --check-delta "$f" 2>&1)
  if echo "$out" | grep -q "Δ ok"; then
    ok=$((ok + 1))
  elif echo "$out" | grep -q "Δ FAILED"; then
    echo "✗ $f: Δ violation(s):"
    echo "$out" | grep "^Δ" | head -5
    fail=1
  else
    # rejection fixture (front-end error) — the checker never runs on it
    rejected=$((rejected + 1))
  fi
done

echo "---"
if [ "$fail" -eq 0 ]; then
  echo "OK: $ok fixtures Δ-accepted; $rejected front-end rejections (Δ never runs)."
else
  echo "FAILURE: Δ checker rejected a valid program."
fi
exit $fail
