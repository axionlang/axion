#!/usr/bin/env bash
# Size-change certificates under Lean: for every recursive group a `{-# TOTAL #-}` function belongs
# to, totality (axionc/src/total.rs) computes the closure of the group's size-change graphs and
# accepts it when every idempotent self-graph has a strict self-edge. This script emits each
# accepted group's certificate (`axionc --emit sct-certs`: the call graphs and the closure) and
# has Lean check it with `AxionSct.check`, whose meaning (`AxionSct.sound`: the claimed closure
# holds the composite of every chain of calls, and every idempotent self-graph in it has a strict
# self-edge) is proven in metatheory/AxionSct.lean.
#
# SCOPE: the closure and the decision on it. That these hypotheses imply termination is the
# size-change theorem (Lee, Jones and Ben-Amram, POPL 2001), cited, not proven here; reading the
# graphs off the program (which measures shrink at a call) is total.rs and refine.rs; the
# arithmetic of each such step carries a certificate that refine-trace.sh checks with Lean.
# Exit 0 = Lean accepts every certificate.
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
# the model, then the examples inside its namespace's file (they name `AxionSct.check` fully)
cp "$here/AxionSct.lean" "$gen"

files=0
for f in "$repo"/axionc/tests/fixtures/*.axi "$repo"/examples/*.axi "$repo"/examples/pass/*.axi; do
  [ -f "$f" ] || continue
  out="$("$AX" --emit sct-certs "$f" 2>/dev/null || true)"
  if printf '%s\n' "$out" | grep -q '^example'; then
    files=$((files + 1))
    printf '%s\n' "$out" | grep '^example' >> "$gen"
  fi
done

n="$(grep -c '^example : AxionSct.check \[' "$gen" || true)"
echo "sct-trace: $n certificate(s) from $files file(s)"
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
echo "OK: Lean's AxionSct.check accepts all $n certificates"
