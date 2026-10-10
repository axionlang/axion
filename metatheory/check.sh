#!/usr/bin/env bash
# Track 2 gate: type-check the Axión drop-verifier metatheory (metatheory/AxionDrop.lean).
# Exit 0 = every theorem proved, NO `sorry`, and the soundness theorems depend only on Lean's
# standard axioms. Uses Lean 4 via nix (no Mathlib), so it needs only a working `nix`.
set -euo pipefail
cd "$(dirname "$0")"

LEAN=(nix shell nixpkgs#lean4 --command lean)
for f in AxionDrop.lean AxionAlias.lean AxionKey.lean AxionMove.lean AxionExtract.lean AxionSession.lean AxionFidelity.lean; do
  # `if ! OUT=…` so `set -e` does NOT abort the script on a lean/nix failure BEFORE we print the
  # captured output — otherwise the real error (e.g. a nix fetch/eval failure) is swallowed and CI
  # shows only a bare exit 1.
  if ! OUT="$("${LEAN[@]}" "$f" 2>&1)"; then
    echo "$OUT"
    echo "FAIL: lean/nix errored on $f" >&2
    exit 1
  fi
  echo "$OUT"
  if echo "$OUT" | grep -qi "sorryAx\|declaration uses 'sorry'"; then
    echo "FAIL: a proof in $f depends on sorry" >&2
    exit 1
  fi
done
echo "OK: AxionDrop + AxionAlias + AxionKey + AxionMove + AxionExtract + AxionSession + AxionFidelity metatheory check (no sorry; axioms = propext/Quot.sound only)"
