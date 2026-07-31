#!/usr/bin/env bash
# Phase 0 — negative test verification.
#
# Compiles prototype/test/negative/UseTwice.hs (a %1 Buffer used twice) and
# REQUIRES the compilation to FAIL with a multiplicity/linearity error. It is the
# bench analog of the AX0001 diagnostic (use-after-consume).
#
# Run inside the dev shell:  nix develop -c ./scripts/check-negative.sh
set -uo pipefail
cd "$(dirname "$0")/.."

out=$(ghc -fno-code -XLinearTypes -iprototype/src \
        prototype/test/negative/UseTwice.hs 2>&1)
status=$?

if [ "$status" -eq 0 ]; then
  echo "✗ FAILURE: UseTwice.hs COMPILED — linearity is not being enforced!"
  echo "$out"
  exit 1
fi

if echo "$out" | grep -qiE "multiplicit|linear|consumed|used more than once"; then
  echo "✓ OK: double use of 'Buffer %1' rejected by the typechecker (analog of AX0001)."
  exit 0
fi

echo "✗ FAILURE: compilation failed, but not for the expected reason (linearity)."
echo "--- GHC output ---"
echo "$out"
exit 1
