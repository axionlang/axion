#!/usr/bin/env bash
# Faithfulness bridge (Track 2): the Lean model and the real verifier agree on every canonical
# memory-safety shape. Two machine-checked halves — the Lean proofs (check.sh) and the verifier
# verdicts (cargo test --test bridge) — linked by the manifest in metatheory/bridge.md.
# Exit 0 = both halves pass.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/.." && pwd)"

echo "== Lean side: model soundness proofs =="
"$here/check.sh"

echo
echo "== Code side: verifier agrees with the model (8 canonical shapes) =="
( cd "$repo/axionc" && cargo test --test bridge -- --nocapture )

echo
echo "== Whole-fragment: executable model agrees with the verifier over the corpus =="
"$here/model-trace.sh"

echo
echo "== Bounded-exhaustive (M4): model agrees with the verifier on EVERY program up to size k =="
"$here/exhaustive.sh"

echo
echo "OK: faithfulness bridge holds (Lean proofs ∧ verifier agreement — 8 canonical shapes ∧ the whole in-fragment corpus ∧ the bounded-exhaustive family)"
