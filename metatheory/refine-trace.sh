#!/usr/bin/env bash
# Refinement certificates under Lean: every proof the refinement checker (axionc/src/refine.rs)
# makes over the corpus — each refined call, each refined result, each array access proven in
# bounds, each "this sum does not overflow", and totality's decreases, divisors and in-range
# proofs (docs/totality.md) — carries a certificate. This script emits them all
# (`axionc --emit refine-certs`) and has Lean check each one with `AxionRefine.check`, whose
# soundness (`AxionRefine.sound`: an accepted certificate means the facts and the negated goal
# have no integer solution) is proven in metatheory/AxionRefine.lean. So no arithmetic decision
# the compiler relies on is trusted to Rust: each is re-checked by Lean's kernel.
#
# SCOPE: the certificate covers the ARITHMETIC (facts ⟹ goal). Reading the facts and the goal off
# the program (which comparisons count, overflow, lengths) is refine.rs, exercised by the fuzzer
# (`scripts/fuzz.py --only refine`). Exit 0 = Lean accepts every certificate.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/.." && pwd)"

# the NEWER of the two builds (as model-trace.sh: never trace a stale compiler); `AXIONC` overrides
AX="${AXIONC:-}"
if [ -z "$AX" ]; then
  dbg="$repo/axionc/target/debug/axionc"
  rel="$repo/axionc/target/release/axionc"
  if [ -x "$dbg" ] && { [ ! -x "$rel" ] || [ "$dbg" -nt "$rel" ]; }; then
    AX="$dbg"
  else
    AX="$rel"
  fi
fi
if [ ! -x "$AX" ]; then
  (cd "$repo/axionc" && cargo build)
  AX="$repo/axionc/target/debug/axionc"
fi
# the same pinned Lean as check.sh / model-trace.sh
LEAN=(nix shell github:NixOS/nixpkgs/b6018f87da91d19d0ab4cf979885689b469cdd41#lean4 --command lean)

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
gen="$work/gen.lean"
# the model, then the examples inside its namespace's file (they name `AxionRefine.check` fully)
cp "$here/AxionRefine.lean" "$gen"

files=0
for f in "$repo"/axionc/tests/fixtures/*.axi "$repo"/examples/*.axi "$repo"/examples/pass/*.axi; do
  [ -f "$f" ] || continue
  out="$("$AX" --emit refine-certs "$f" 2>/dev/null || true)"
  if printf '%s\n' "$out" | grep -q '^example'; then
    files=$((files + 1))
    printf '%s\n' "$out" | grep '^example' >> "$gen"
  fi
done

n="$(grep -c '^example : AxionRefine.check \[' "$gen" || true)"
echo "refine-trace: $n certificate(s) from $files file(s)"
if [ "$n" -eq 0 ]; then
  echo "FAIL: no certificates — the corpus should prove at least the refinement fixtures" >&2
  exit 1
fi

errs="$("${LEAN[@]}" "$gen" 2>&1 | grep -iE 'error|sorry' || true)"
if [ -n "$errs" ]; then
  echo "FAIL: Lean rejected a certificate the compiler accepted:" >&2
  printf '%s\n' "$errs" | head >&2
  exit 1
fi
echo "OK: Lean's AxionRefine.check accepts all $n certificates"
