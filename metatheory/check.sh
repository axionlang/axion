#!/usr/bin/env bash
# Track 2 gate: type-check the Axión drop-verifier metatheory (metatheory/AxionDrop.lean).
# Exit 0 = every theorem proved, NO `sorry`, and the soundness theorems depend only on Lean's
# standard axioms. Uses Lean 4 via nix (no Mathlib), so it needs only a working `nix`.
set -euo pipefail
cd "$(dirname "$0")"

# PINNED lean4 (nixos-25.11 → Lean 4.25.0). The proofs are NOT forward-compatible across Lean minors
# — Lean 4.34 changed `ite`/`Decidable` elaboration and deprecated `if_true`/`if_false`, which turns
# `chk_correct` into a `sorryAx` and errors the build. Floating `nixpkgs#lean4` silently drifted CI to
# a breaking Lean (the metatheory job failed while local was still on 4.29.1). Pinning keeps the gate
# reproducible; bump the rev deliberately (and update the proofs) when moving Lean. Same pin in
# exhaustive.sh and model-trace.sh.
LEAN=(nix shell github:NixOS/nixpkgs/b6018f87da91d19d0ab4cf979885689b469cdd41#lean4 --command lean)
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
