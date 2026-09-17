#!/usr/bin/env bash
# M2 whole-fragment faithfulness bridge (metatheory/bridge.md widening).
#
# For EVERY corpus fixture, `axionc --emit model-trace` translates each function that lies in the
# AxionDrop owned-set fragment (alloc/use/drop/moveOut/branch) into an `AxionDrop.Expr` term and
# emits `example : AxionDrop.acceptsL <T> = <verifier-verdict> := by rfl`. We append all of them to
# a copy of AxionDrop.lean and type-check it: every `by rfl` that holds is one function on which the
# executable model's verdict (== `accepts` by `chk_correct`, hence memory-safe + leak-free by
# `sound`) EQUALS the real verifier's verdict. This widens the bridge from the 8 curated shapes
# (bridge.rs) to the whole in-fragment corpus, and reports coverage.
#
# Exit 0 = the model agrees with the verifier on every in-fragment function.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/.." && pwd)"

AX="$repo/axionc/target/debug/axionc"
if [ ! -x "$AX" ]; then
  AX="$repo/axionc/target/release/axionc"
fi
if [ ! -x "$AX" ]; then
  (cd "$repo/axionc" && cargo build)
  AX="$repo/axionc/target/debug/axionc"
fi
LEAN=(nix shell nixpkgs#lean4 --command lean)

work="$(mktemp -d)"
gen="$work/gen.lean"
cp "$here/AxionDrop.lean" "$gen"

tot=0
inm=0
for f in "$repo"/axionc/tests/fixtures/*.axi; do
  out="$("$AX" --emit model-trace "$f" 2>/dev/null || true)"
  [ -z "$out" ] && continue
  cov="$(printf '%s\n' "$out" | grep -o 'coverage: [0-9]* in-model of [0-9]*' || true)"
  i="$(printf '%s\n' "$cov" | grep -oE 'coverage: [0-9]+' | grep -oE '[0-9]+' || echo 0)"
  t="$(printf '%s\n' "$cov" | sed 's/.*of //' || echo 0)"
  inm=$((inm + ${i:-0}))
  tot=$((tot + ${t:-0}))
  printf '%s\n' "$out" | grep '^example' >> "$gen" || true
done

n="$(grep -c '^example' "$gen" || true)"
echo "model-trace: $inm in-model of $tot corpus functions; $n machine-checked bridge examples"

errs="$("${LEAN[@]}" "$gen" 2>&1 | grep -iE 'error|sorry' || true)"
if [ -n "$errs" ]; then
  echo "FAIL: the executable model disagrees with the verifier on some in-fragment function:" >&2
  printf '%s\n' "$errs" | head >&2
  exit 1
fi
echo "OK: executable model agrees with the verifier on all $n in-fragment functions"
