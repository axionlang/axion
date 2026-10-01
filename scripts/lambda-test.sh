#!/usr/bin/env bash
# Behavioral test for the Axión `lambda` interpreter (examples/lambda.axi) — the third flagship.
# Feeds a set of source programs on argv and asserts the printed result on EVERY available backend
# (interp always; cranelift if the Int core lowers; llvm if clang is present), so interp == dev ==
# release stays true. Covers arithmetic + precedence, `let`, currying, higher-order application, `if`
# truthiness, and both the parse-error and eval-error paths. Keeps the flagship from silently rotting
# (cf. fff-test.sh / pass-test.sh).
#
#   ./scripts/lambda-test.sh
set -uo pipefail
cd "$(dirname "$0")/.."

AXIONC="${AXIONC:-axionc/target/debug/axionc}"
LAMBDA="examples/lambda.axi"
if [ ! -x "$AXIONC" ]; then
  echo "building axionc…"
  (cd axionc && cargo build -q) || { echo "build failed"; exit 2; }
fi

backends=(interp)
"$AXIONC" --emit clif "$LAMBDA" >/dev/null 2>&1 && backends+=(cranelift)
command -v clang >/dev/null 2>&1 && backends+=(llvm)

fail=0

# programs and their expected printed output (parallel arrays — programs contain '='/'==',
# so a packed "prog=want" string cannot be split reliably).
PROGS=(
  "1 + 2 * 3"
  "10 - 3 - 2"
  "2 * 3 + 4 * 5"
  "let x = 5 in x * x"
  "let add = \\x -> \\y -> x + y in add 3 4"
  "let twice = \\f -> \\x -> f (f x) in twice (\\n -> n * n) 3"
  "(\\f -> f 10) (\\x -> x + x)"
  "let k = \\a -> \\b -> a in k 7 99"
  "if 1 < 2 then 10 else 20"
  "if 5 == 5 then 1 else 0"
  "if 0 then 1 else 2"
  "nope + 1"
  "(1 + 2"
)
WANTS=(
  "7"
  "5"
  "26"
  "25"
  "7"
  "81"
  "20"
  "7"
  "10"
  "1"
  "2"
  "eval error: unbound variable: nope"
  "parse error: expected )"
)

run() { # backend program  → run the interpreter on one program string
  local be="$1" prog="$2"
  local flag="--backend $be"
  [ "$be" = llvm ] && flag="--release"
  "$AXIONC" $flag "$LAMBDA" -- "$prog" 2>/dev/null
}

for be in "${backends[@]}"; do
  for idx in "${!PROGS[@]}"; do
    prog="${PROGS[$idx]}"
    want="${WANTS[$idx]}"
    got="$(run "$be" "$prog")"
    if [ "$got" = "$want" ]; then
      echo "✓ [$be] $prog => $got"
    else
      echo "✗ [$be] $prog => got [$got], want [$want]"
      fail=1
    fi
  done
done

if [ "$fail" -eq 0 ]; then
  echo "OK: lambda interpreter — ${#PROGS[@]} programs × ${#backends[@]} backend(s) all agree"
else
  echo "FAIL: lambda interpreter divergence above"
  exit 1
fi
