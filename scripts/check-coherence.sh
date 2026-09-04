#!/usr/bin/env bash
# Δ-3 COHERENCE guard (docs/delta-design.md §7 + docs/delta-consolidation-plan.md Step 4).
#
# NON-soundness regression guard: the emitted Core's drop classification/anchors must agree
# with the front-end DropPoints (`check.rs`) that the LSP ownership overlay surfaces to users.
# The SOUNDNESS judgment is the drop-balance verifier (scripts/verify-gate.sh, default-on
# AX0910/AX0911) — the legacy Δ judgment (delta.rs::check_all) was retired (Δ-consolidation
# Step 3) after the verifier was proven to subsume it. This guard only cross-checks that the
# front-end liveness the editor shows matches the reclamation actually emitted.
#
# Verdicts (`--check-coherence`):
#   · "Δ ok"            — Core drops agree with the front-end DropPoints
#   · "Δ FAILED: N…"    — a coherence disagreement (GATE FAILURE)
#   · front-end error   — rejection fixture: never reaches Core (coherence doesn't run)
#
# Run:  ./scripts/check-coherence.sh
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
  out=$("$AXIONC" --check-coherence "$f" 2>&1)
  if echo "$out" | grep -q "Δ ok"; then
    ok=$((ok + 1))
  elif echo "$out" | grep -q "Δ FAILED"; then
    echo "✗ $f: coherence violation(s):"
    echo "$out" | grep "^Δ" | head -5
    fail=1
  else
    # rejection fixture (front-end error) — coherence never runs on it
    rejected=$((rejected + 1))
  fi
done

echo "---"
if [ "$fail" -eq 0 ]; then
  echo "OK: $ok fixtures coherent; $rejected front-end rejections (coherence never runs)."
else
  echo "FAILURE: Core drops disagree with the front-end DropPoints."
fi
exit $fail
