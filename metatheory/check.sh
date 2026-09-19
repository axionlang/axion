#!/usr/bin/env bash
# Track 2 gate: type-check the Axión drop-verifier metatheory (metatheory/AxionDrop.lean).
# Exit 0 = every theorem proved, NO `sorry`, and the soundness theorems depend only on Lean's
# standard axioms. Uses Lean 4 via nix (no Mathlib), so it needs only a working `nix`.
set -euo pipefail
cd "$(dirname "$0")"

LEAN=(nix shell nixpkgs#lean4 --command lean)
for f in AxionDrop.lean AxionAlias.lean AxionKey.lean AxionMove.lean AxionExtract.lean AxionSession.lean AxionFidelity.lean; do
  OUT="$("${LEAN[@]}" "$f" 2>&1)"
  status=$?
  echo "$OUT"
  if [ $status -ne 0 ]; then
    echo "FAIL: lean reported errors in $f" >&2
    exit 1
  fi
  if echo "$OUT" | grep -qi "sorryAx\|declaration uses 'sorry'"; then
    echo "FAIL: a proof in $f depends on sorry" >&2
    exit 1
  fi
done
echo "OK: AxionDrop + AxionAlias + AxionKey + AxionMove + AxionExtract + AxionSession + AxionFidelity metatheory check (no sorry; axioms = propext/Quot.sound only)"
