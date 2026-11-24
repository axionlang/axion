#!/usr/bin/env bash
# Pattern-coverage certificates under Lean: totality (axionc/src/total.rs, docs/totality.md) decides
# that every match of a `{-# TOTAL #-}` function covers every value by building a COVERAGE TREE,
# the trace of Maranget's usefulness algorithm. This script emits every accepted match's rows and
# tree over the corpus (`axionc --emit cover-certs`) and has Lean check each one with
# `AxionCover.check`, whose soundness (`AxionCover.sound`: every vector of values agreeing with the
# rows' types is matched by some row) is proven in metatheory/AxionCover.lean.
#
# SCOPE: the decision on the rows. Reading the rows off the program (which clauses count, given
# their guards) and the signature (each type's constructors) is total.rs. Exit 0 = Lean accepts
# every certificate.
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
# the model, then the examples inside its namespace's file (they name `AxionCover.check` fully)
cp "$here/AxionCover.lean" "$gen"

files=0
for f in "$repo"/axionc/tests/fixtures/*.axi "$repo"/examples/*.axi "$repo"/examples/pass/*.axi; do
  [ -f "$f" ] || continue
  out="$("$AX" --emit cover-certs "$f" 2>/dev/null || true)"
  if printf '%s\n' "$out" | grep -q '^example'; then
    files=$((files + 1))
    printf '%s\n' "$out" | grep '^example' >> "$work/all"
  fi
done
# the same match (all wildcards, most often) recurs: check each certificate once
[ -f "$work/all" ] && sort -u "$work/all" >> "$gen"

n="$(grep -c '^example : AxionCover.check \[' "$gen" || true)"
echo "cover-trace: $n distinct certificate(s) from $files file(s)"
if [ "$n" -eq 0 ]; then
  echo "FAIL: no certificates — the corpus should prove at least the totality fixtures" >&2
  exit 1
fi

errs="$("${LEAN[@]}" "$gen" 2>&1 | grep -iE 'error|sorry' || true)"
if [ -n "$errs" ]; then
  echo "FAIL: Lean rejected a certificate the compiler accepted:" >&2
  printf '%s\n' "$errs" | head >&2
  exit 1
fi
echo "OK: Lean's AxionCover.check accepts all $n certificates"
