#!/usr/bin/env bash
# Formatter safety gate: `axionc fmt` must PRESERVE MEANING, including when it moves columns. Compared
# as sorted `--emit core` (order-nondeterministic, like dump-oracle.sh), for every file that compiles:
#   1. fmt on the file itself, and on a trailing-whitespace + extra-blank-lines variant;
#   2. fmt on the file with all leading indentation scaled ×2 and ×3, which makes fmt actually
#      re-indent. Scaling can break an aligned block (`let s = 1` / `    t = 2`), so a scaled input
#      only counts if it still lowers to the original Core: the input must be valid before fmt runs;
#   3. fmt is idempotent on every output above.
# A file fmt declines to format is reported, not failed.
set -uo pipefail
cd "$(dirname "$0")/.."
AXIONC="${AXIONC:-axionc/target/release/axionc}"
[ -x "$AXIONC" ] || { echo "axionc not found at $AXIONC"; exit 2; }

# stdout also carries warning diagnostics, which quote the path and source text: not part of Core.
core() {
  "$AXIONC" --emit core "$1" 2>/dev/null \
    | grep -vE '^warning\[|^ *-->|^ *[0-9]* *\||^ *= (help|note)' | LC_ALL=C sort
}

# fmt <input> <label>: formats the input and reports one status token per check.
check_fmt() {
  local in="$1" label="$2"
  local out="$tmp/out-$label.axi" again="$tmp/again-$label.axi"
  "$AXIONC" fmt --stdout "$in" > "$out" 2>/dev/null
  if [ ! -s "$out" ]; then echo "declined $label $f"; return; fi
  if [ "$(core "$out")" != "$base" ]; then echo "COREDIFF $label $f"; return; fi
  "$AXIONC" fmt --stdout "$out" > "$again" 2>/dev/null
  if ! cmp -s "$out" "$again"; then echo "NOTIDEMPOTENT $label $f"; return; fi
  if cmp -s "$in" "$out"; then echo "same $label $f"; else echo "reformatted $label $f"; fi
}

if [ "${1:-}" = "--one" ]; then
  f="$2"; tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
  "$AXIONC" --emit core "$f" >/dev/null 2>&1 || { echo "rejected - $f"; exit 0; }
  base="$(core "$f")"
  check_fmt "$f" clean
  sed 's/[[:space:]]*$/   /' "$f" > "$tmp/messy.axi"; printf '\n\n\n' >> "$tmp/messy.axi"
  check_fmt "$tmp/messy.axi" messy
  sed -E 's/^( +)/\1\1/' "$f" > "$tmp/x2.axi"
  sed -E 's/^( +)/\1\1\1/' "$f" > "$tmp/x3.axi"
  for s in x2 x3; do
    if [ "$(core "$tmp/$s.axi")" = "$base" ]; then check_fmt "$tmp/$s.axi" "$s"
    else echo "invalidinput $s $f"; fi
  done
  exit 0
fi

export AXIONC
results="$(ls axionc/tests/fixtures/*.axi examples/*.axi bench/*.axi 2>/dev/null \
  | xargs -P "$(nproc)" -n1 "$0" --one)"
count() { printf '%s\n' "$results" | awk -v s="$1" -v l="${2:-}" '$1==s && (l=="" || $2==l)' | wc -l; }
for l in clean messy x2 x3; do
  printf "%-6s same %4d · reformatted %4d · declined %4d · input-invalid %4d\n" "$l" \
    "$(count same "$l")" "$(count reformatted "$l")" "$(count declined "$l")" "$(count invalidinput "$l")"
done
echo "rejected by the compiler (no Core to compare): $(count rejected)"
# A crashed check must never read as a pass: every compiling file reports exactly 4 results.
total="$(ls axionc/tests/fixtures/*.axi examples/*.axi bench/*.axi 2>/dev/null | wc -l)"
expected=$(( (total - $(count rejected)) * 4 + $(count rejected) ))
got="$(printf '%s\n' "$results" | awk 'NF==3' | wc -l)"
if [ "$got" -ne "$expected" ] || [ "$expected" -le 0 ]; then
  echo "FAIL: expected $expected check results, got $got"
  exit 1
fi
bad="$(printf '%s\n' "$results" | awk '$1=="COREDIFF" || $1=="NOTIDEMPOTENT"')"
if [ -n "$bad" ]; then
  printf '%s\n' "$bad" | sort | head -60
  echo "FAIL: $(printf '%s\n' "$bad" | wc -l) formatter violation(s)"
  exit 1
fi
echo "OK: fmt preserves Core and is idempotent on every input above"
