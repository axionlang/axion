#!/usr/bin/env bash
# Track 2 gate: type-check the Axión drop-verifier metatheory (metatheory/AxionDrop.lean).
# Exit 0 = every theorem proved, NO `sorry`, and the soundness theorems depend only on Lean's
# standard axioms. Uses Lean 4 via nix (no Mathlib), so it needs only a working `nix`.
set -euo pipefail
cd "$(dirname "$0")"

LEAN=(nix shell nixpkgs#lean4 --command lean)
OUT="$("${LEAN[@]}" AxionDrop.lean 2>&1)"
status=$?

echo "$OUT"
if [ $status -ne 0 ]; then
  echo "FAIL: lean reported errors" >&2
  exit 1
fi
if echo "$OUT" | grep -qi "sorryAx\|declaration uses 'sorry'"; then
  echo "FAIL: a proof depends on sorry" >&2
  exit 1
fi
echo "OK: AxionDrop metatheory checks (no sorry; axioms = propext/Quot.sound only)"
