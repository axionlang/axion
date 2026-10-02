#!/usr/bin/env bash
# Behavioral test for the Axión HM type inferencer (examples/typecheck.axi). Runs the built-in
# demo (hand-built ASTs) on every available backend and asserts the inferred types + the two
# type-error messages, so interp == dev == release. Covers polymorphic identity, curried arithmetic,
# a higher-order `twice`, an `if`, and the apply-a-number / add-a-function rejections.
#
#   ./scripts/typecheck-test.sh
set -uo pipefail
cd "$(dirname "$0")/.."

AXIONC="${AXIONC:-axionc/target/debug/axionc}"
TC="examples/typecheck.axi"
if [ ! -x "$AXIONC" ]; then
  echo "building axionc…"
  (cd axionc && cargo build -q) || { echo "build failed"; exit 2; }
fi

backends=(interp)
"$AXIONC" --emit clif "$TC" >/dev/null 2>&1 && backends+=(cranelift)
command -v clang >/dev/null 2>&1 && backends+=(llvm)

WANT="(t0 -> t0)
(Int -> (Int -> Int))
Int
Int
type error: cannot unify Int with a function type
type error: cannot unify a function type with Int"

fail=0
for be in "${backends[@]}"; do
  flag="--backend $be"
  [ "$be" = llvm ] && flag="--release"
  got="$("$AXIONC" $flag "$TC" 2>/dev/null)"
  if [ "$got" = "$WANT" ]; then
    echo "✓ [$be] inferred types + errors match"
  else
    echo "✗ [$be] mismatch:"; diff <(printf '%s' "$WANT") <(printf '%s' "$got") | head
    fail=1
  fi
done

if [ "$fail" -eq 0 ]; then
  echo "OK: typecheck inferencer — ${#backends[@]} backend(s) agree"
else
  echo "FAIL: typecheck inferencer divergence above"
  exit 1
fi
