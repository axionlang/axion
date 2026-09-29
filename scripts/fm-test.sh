#!/usr/bin/env bash
# Behavioral test for the Axión TUI file manager (examples/fm.axi) — the second flagship.
# Drives it HEADLESSLY: pipes a scripted key stream at a throwaway directory tree on every available
# backend and asserts the on-disk effects + that a rendered frame lists the entries. Because `readKey`
# reads ONE byte (raw, degrading to a plain 1-byte read on a pipe) and `readLine` reads to '\n', a
# script mixes single keys and typed names precisely, e.g. 'mnewdir\nq' = mkdir → readLine "newdir" →
# quit. This is the gate that keeps the flagship from silently rotting (cf. scripts/pass-test.sh).
#
#   ./scripts/fm-test.sh
set -uo pipefail
cd "$(dirname "$0")/.."

AXIONC="${AXIONC:-axionc/target/debug/axionc}"
FM="examples/fm.axi"
if [ ! -x "$AXIONC" ]; then
  echo "building axionc…"
  (cd axionc && cargo build -q) || { echo "build failed"; exit 2; }
fi

# interp always; cranelift if it lowers; llvm if clang is present.
backends=(interp)
"$AXIONC" --emit clif "$FM" >/dev/null 2>&1 && backends+=(cranelift)
command -v clang >/dev/null 2>&1 && backends+=(llvm)

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
fail=0

seed() { # dir  → a known tree: a.txt, b.txt, sub/ (sorted: a.txt, b.txt, sub)
  local d="$1"
  rm -rf "$d"
  mkdir -p "$d/sub"
  : >"$d/a.txt"
  : >"$d/b.txt"
}
run() { # backend dir keyscript  → drive fm rooted at dir with the scripted keys
  local be="$1" d="$2" keys="$3"
  local flag="--backend $be"
  [ "$be" = llvm ] && flag="--release"
  printf '%b' "$keys" | "$AXIONC" $flag "$FM" -- "$d" 2>/dev/null
}
ok() { # backend got want label
  if [ "$2" = "$3" ]; then echo "✓ [$1] $4"; else echo "✗ [$1] $4 (got '$2' want '$3')"; fail=1; fi
}

for be in "${backends[@]}"; do
  S="$WORK/$be"

  # a rendered frame lists the directory entries
  seed "$S"; out="$(run "$be" "$S" 'q')"
  if printf '%s' "$out" | grep -qaF "a.txt" && printf '%s' "$out" | grep -qaF "sub"; then
    echo "✓ [$be] frame lists the entries"
  else
    echo "✗ [$be] frame did not list the entries"; fail=1
  fi

  # m: mkdir a new directory (name typed via readLine)
  seed "$S"; run "$be" "$S" 'mnewdir\nq' >/dev/null
  ok "$be" "$([ -d "$S/newdir" ] && echo Y)" "Y" "mkdir (m + typed name)"

  # d: delete the selected entry (sel 0 = a.txt)
  seed "$S"; run "$be" "$S" 'dq' >/dev/null
  ok "$be" "$([ -e "$S/a.txt" ] || echo gone)" "gone" "delete (d)"

  # r: rename the selected entry a.txt → r.txt
  seed "$S"; run "$be" "$S" 'rr.txt\nq' >/dev/null
  ok "$be" "$([ -e "$S/r.txt" ] && [ ! -e "$S/a.txt" ] && echo Y)" "Y" "rename (r)"

  # c/p: yank a.txt (sel 0), descend into sub (j j l), paste there
  seed "$S"; run "$be" "$S" 'cjjlpq' >/dev/null
  ok "$be" "$([ -e "$S/sub/a.txt" ] && echo Y)" "Y" "yank + paste (c/p) across dirs"
done

if [ "$fail" = 0 ]; then
  echo "OK: fm.axi navigates + operates correctly, identically on ${backends[*]}"
else
  echo "FAIL: file-manager differences above"
  exit 1
fi
