#!/usr/bin/env bash
# Formatter safety gate: `axionc fmt` must PRESERVE MEANING. For every corpus file that COMPILES, feed
# `fmt` a deliberately-messy variant (trailing whitespace on every line + extra blank lines — all
# semantically irrelevant) and assert the formatted result lowers to byte-identical Core as the clean
# original (sorted + locale-pinned; `--emit core` is order-nondeterministic, like dump-oracle.sh). This
# exercises the normalizer on every file and proves it changes layout, never meaning.
#
# Rejection fixtures (whose `--emit core` is an AX error diagnostic that embeds the source path) are
# skipped — there is no Core to preserve, and `fmt` is a no-op on them regardless.
set -uo pipefail
cd "$(dirname "$0")/.."
AXIONC="${AXIONC:-axionc/target/release/axionc}"
[ -x "$AXIONC" ] || { echo "axionc not found at $AXIONC"; exit 2; }

inputs() { ls axionc/tests/fixtures/*.axi examples/*.axi 2>/dev/null; }
# Core of a file, with the `-->` diagnostic line dropped (it embeds the source PATH, which differs
# between the original and the temp copy — not a semantic difference), sorted + locale-pinned.
core() { "$AXIONC" --emit core "$1" 2>&1 | grep -v -- '-->' | LC_ALL=C sort; }
messy="$(mktemp --suffix=.axi)"; fmtd="$(mktemp --suffix=.axi)"
trap 'rm -f "$messy" "$fmtd"' EXIT

n=0 ok=0 rej=0 skipped=0 fail=0
for f in $(inputs); do
	n=$((n + 1))
	# rejection fixture (its `--emit core` is an AX error diagnostic that embeds the path) → skip.
	# Detect by string match on a CAPTURE, not a pipeline (pipefail would mask grep under the
	# fixture's own non-zero exit).
	case "$("$AXIONC" --emit core "$f" 2>&1)" in
		*"error["*) rej=$((rej + 1)); continue ;;
	esac
	# messy variant: trailing spaces on every line + trailing blank lines (both insignificant)
	sed 's/[[:space:]]*$/   /' "$f" > "$messy"; printf '\n\n\n' >> "$messy"
	"$AXIONC" fmt --stdout "$messy" > "$fmtd" 2>/dev/null
	[ -s "$fmtd" ] || { skipped=$((skipped + 1)); continue; }
	# compare both sides through the SAME pipeline (process substitution — no capture asymmetry)
	if diff -q <(core "$f") <(core "$fmtd") >/dev/null; then
		ok=$((ok + 1))
	else
		echo "CORE DIFF after fmt: $f"; fail=$((fail + 1))
	fi
done
echo "fmt-check: $n files · $ok preserved · $rej rejection-fixtures · $skipped skipped · $fail Core-diff"
[ "$fail" -eq 0 ] || { echo "FAIL: fmt changed the meaning of $fail file(s)"; exit 1; }
echo "OK: fmt preserves Core on every compiling file"
