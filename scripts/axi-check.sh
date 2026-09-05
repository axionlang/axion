#!/usr/bin/env bash
# axi-check.sh — the blessed pattern for testing an Axión program (effectful or pure).
#
# Runs FILE.axi on every AVAILABLE backend — interp always; Cranelift (--dev) if it can
# lower the program; LLVM (--release) if clang is present — and asserts they all produce
# IDENTICAL output. Backend agreement (the `runtime_backends_agree` invariant) is the single
# most important property for any Axión program, so this checks it by construction. Optionally
# also asserts the output equals an expected value.
#
# Program args after `--` are forwarded as the program's argv; the caller's environment is
# inherited, so an effectful program runs against whatever throwaway environment the caller set
# up first (a temp dir, env vars, a throwaway GPG keyring — see scripts/pass-test.sh).
#
# Usage:
#   scripts/axi-check.sh [--expect STR | --expect-file F] [--label NAME] FILE.axi [-- ARGS...]
#
# Env:  AXIONC (default axionc/target/debug/axionc), AXION_CLANG (default: clang on PATH).
# Exit: 0 = every available backend agreed (and matched --expect, if given); 1 = a mismatch;
#       2 = usage / build error.
set -uo pipefail
cd "$(dirname "$0")/.."

AXIONC="${AXIONC:-axionc/target/debug/axionc}"
CLANG="${AXION_CLANG:-clang}"

expect="" expect_set=0 label="" file=""
args=()
while [ $# -gt 0 ]; do
  case "$1" in
    --expect)      expect="$2"; expect_set=1; shift 2 ;;
    --expect-file) expect="$(cat "$2")"; expect_set=1; shift 2 ;;
    --label)       label="$2"; shift 2 ;;
    --)            shift; args=("$@"); break ;;
    -*)            echo "axi-check: unknown option $1" >&2; exit 2 ;;
    *)             file="$1"; shift ;;
  esac
done
[ -n "$file" ] || { echo "usage: axi-check.sh [--expect STR|--expect-file F] FILE.axi [-- ARGS]" >&2; exit 2; }
[ -n "$label" ] || label="$(basename "$file")"

if [ ! -x "$AXIONC" ]; then
  echo "building axionc…" >&2
  (cd axionc && cargo build -q) || { echo "axi-check: build failed" >&2; exit 2; }
fi

# Available backends: interp always; Cranelift only if it can lower this program (some use
# features it can't JIT); LLVM only if clang is present.
backends=(interp)
"$AXIONC" --emit clif "$file" >/dev/null 2>&1 && backends+=(cranelift)
"$CLANG" --version >/dev/null 2>&1 && backends+=(llvm)

first_out="" first_be="" fail=0
for be in "${backends[@]}"; do
  out="$("$AXIONC" run --backend "$be" "$file" ${args[@]:+-- "${args[@]}"} 2>/dev/null)"
  if [ -z "$first_be" ]; then
    first_out="$out"; first_be="$be"
  elif [ "$out" != "$first_out" ]; then
    echo "✗ $label: $be disagrees with $first_be" >&2
    echo "    $first_be: $(printf '%q' "$first_out")" >&2
    echo "    $be: $(printf '%q' "$out")" >&2
    fail=1
  fi
done

if [ "$expect_set" -eq 1 ] && [ "$first_out" != "$expect" ]; then
  echo "✗ $label: output does not match --expect" >&2
  echo "    expected: $(printf '%q' "$expect")" >&2
  echo "    actual:   $(printf '%q' "$first_out")" >&2
  fail=1
fi

if [ "$fail" -eq 0 ]; then
  echo "✓ $label: ${backends[*]} agree${expect_set:+ (== expected)}"
fi
exit $fail
