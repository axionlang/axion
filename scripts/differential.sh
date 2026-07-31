#!/usr/bin/env bash
# Differential tests (§17): each scenario in differential/ must get the SAME
# verdict (accept/reject) from axionc AND from the GHC oracle (Phase 0 EDSL
# bench). Anchors axionc's linearity checker to the GHC reference.
#
# Run:  ./scripts/differential.sh
set -uo pipefail
cd "$(dirname "$0")/.."

AXIONC="${AXIONC:-axionc/target/debug/axionc}"
if [ ! -x "$AXIONC" ]; then
  echo "building axionc..."
  (cd axionc && cargo build -q) || {
    echo "failed to build axionc"
    exit 2
  }
fi

fail=0
total=0
for dir in differential/*/; do
  [ -f "$dir/expected" ] || continue
  name=$(basename "$dir")
  expected=$(cat "$dir/expected")
  total=$((total + 1))

  # axionc verdict
  if "$AXIONC" --check "$dir/prog.axi" >/dev/null 2>&1; then
    axi=accept
  else
    axi=reject
  fi

  # GHC verdict (EDSL oracle), inside the reproducible dev shell
  if nix develop --command ghc -fno-code -XLinearTypes -iprototype/src \
      "$dir/Prog.hs" >/dev/null 2>&1; then
    ghc=accept
  else
    ghc=reject
  fi

  if [ "$axi" = "$expected" ] && [ "$ghc" = "$expected" ]; then
    echo "✓ $name: axionc=$axi · ghc=$ghc (expected: $expected)"
  else
    echo "✗ $name: axionc=$axi · ghc=$ghc (expected: $expected) — DIVERGES"
    fail=1
  fi
done

echo "---"
if [ "$fail" -eq 0 ]; then
  echo "OK: $total scenarios, axionc and GHC agree on all."
else
  echo "FAILURE: divergence between axionc and the GHC oracle."
fi
exit $fail
