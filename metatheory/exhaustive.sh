#!/usr/bin/env bash
# M4 — bounded-exhaustive verifier==model check (metatheory/GUARANTEE.md §5, roadmap M4).
#
# The corpus bridge (model-trace.sh) samples the hand-written fixtures. This ENUMERATES the fragment:
# it materializes EVERY program in the bounded drop/move/branch family up to size k (the same family
# `axionc/tests/exhaustive.rs` checks against the sanitizers), runs `--emit model-trace` on each, and
# Lean-type-checks the resulting `acceptsL … = <verifier-verdict> := by rfl` examples. Every example
# that holds is one generated program on which the proven-sound executable model AGREES with the real
# verifier. Together with the sanitizer gate (verifier ACCEPT ⇒ runtime-safe), this gives
# model == verifier == runtime exhaustively over the family, not just on samples.
#
# Exit 0 = the model agrees with the verifier on every in-fragment program in the family.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/.." && pwd)"

AX="$repo/axionc/target/debug/axionc"
[ -x "$AX" ] || (cd "$repo/axionc" && cargo build)
LEAN=(nix shell nixpkgs#lean4 --command lean)

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
corpus="$work/corpus"

# Materialize the family from the single generator (the #[ignore]d dump test).
AXION_M4_DUMP="$corpus" \
  cargo test --manifest-path "$repo/axionc/Cargo.toml" --test exhaustive \
    dump_exhaustive_corpus -- --ignored >/dev/null 2>&1
nprog="$(ls "$corpus"/*.axi 2>/dev/null | wc -l | tr -d ' ')"
echo "exhaustive: generated $nprog programs in the bounded fragment"

gen="$work/gen.lean"
cp "$here/AxionDrop.lean" "$gen"
for f in "$corpus"/*.axi; do
  "$AX" --emit model-trace "$f" 2>/dev/null | grep '^example' >> "$gen" || true
done

n="$(grep -c '^example' "$gen" || true)"
echo "exhaustive: $n machine-checked verifier==model examples across the family"

errs="$("${LEAN[@]}" "$gen" 2>&1 | grep -iE 'error|sorry' || true)"
if [ -n "$errs" ]; then
  echo "FAIL: the executable model disagrees with the verifier on a generated program:" >&2
  printf '%s\n' "$errs" | head >&2
  exit 1
fi
echo "OK: model agrees with the verifier on all $n in-fragment programs (bounded-exhaustive)"
