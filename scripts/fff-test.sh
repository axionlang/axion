#!/usr/bin/env bash
# Behavioral test for the Axión `fff` rewrite (examples/fff.axi) — the third flagship.
# Drives it HEADLESSLY: pipes a scripted key stream at a throwaway directory tree on every available
# backend and asserts the on-disk effects + that a rendered frame lists the entries. `readKey` reads
# one byte (raw, degrading to a plain read on a pipe) and the command line reads to '\n', so a script
# mixes single keys and typed names precisely, e.g. 'nnewdir\nq' = mkdir → type "newdir" → submit →
# quit. HOME is sandboxed to a temp dir so trash/cache/cd-file writes never touch the real home.
# This gate keeps the flagship (and readKey/chr) from silently rotting (cf. pass-test.sh).
#
#   ./scripts/fff-test.sh
set -uo pipefail
cd "$(dirname "$0")/.."

AXIONC="${AXIONC:-axionc/target/debug/axionc}"
FFF="examples/fff.axi"
if [ ! -x "$AXIONC" ]; then
  echo "building axionc…"
  (cd axionc && cargo build -q) || { echo "build failed"; exit 2; }
fi

backends=(interp)
"$AXIONC" --emit clif "$FFF" >/dev/null 2>&1 && backends+=(cranelift)
command -v clang >/dev/null 2>&1 && backends+=(llvm)

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
fail=0

seed() { # dir  → a known tree (dirs-first sort: sub/, a.txt, b.txt)
  local d="$1"
  rm -rf "$d"
  mkdir -p "$d/sub"
  : >"$d/a.txt"
  : >"$d/b.txt"
}
run() { # backend dir keyscript  → drive fff rooted at dir with the scripted keys (HOME sandboxed)
  local be="$1" d="$2" keys="$3"
  local flag="--backend $be"
  [ "$be" = llvm ] && flag="--release"
  printf '%b' "$keys" | HOME="$d" "$AXIONC" $flag "$FFF" -- "$d" >/dev/null 2>&1
}
ok() { # backend got want label
  if [ "$2" = "$3" ]; then echo "✓ [$1] $4"; else echo "✗ [$1] $4 (got '$2' want '$3')"; fail=1; fi
}

# A scripted $EDITOR for bulk-rename: prepend "r_" to every line of the file it's given.
ED="$WORK/ed.sh"
printf '#!/bin/sh\nsed -i "s/^/r_/" "$1"\n' > "$ED"
chmod +x "$ED"

for be in "${backends[@]}"; do
  S="$WORK/$be"

  # a rendered frame lists the entries (ANSI interspersed; grep the plain names)
  seed "$S"; out="$(printf 'q' | HOME="$S" "$AXIONC" $([ "$be" = llvm ] && echo --release || echo --backend "$be") "$FFF" -- "$S" 2>/dev/null)"
  if printf '%s' "$out" | grep -qaF "a.txt" && printf '%s' "$out" | grep -qaF "sub"; then
    echo "✓ [$be] frame lists the entries (dirs-first)"
  else
    echo "✗ [$be] frame did not list the entries"; fail=1
  fi

  # n: mkdir (name typed at the command line)
  seed "$S"; run "$be" "$S" 'nnewdir\nq'
  ok "$be" "$([ -d "$S/newdir" ] && echo Y)" "Y" "mkdir (n)"

  # f: mkfile
  seed "$S"; run "$be" "$S" 'fnewfile\nq'
  ok "$be" "$([ -f "$S/newfile" ] && echo Y)" "Y" "mkfile (f)"

  # r: rename the selection (sel 0 = sub/) → renamed
  seed "$S"; run "$be" "$S" 'rrenamed\nq'
  ok "$be" "$([ -e "$S/renamed" ] && [ ! -e "$S/sub" ] && echo Y)" "Y" "rename (r)"

  # d + p: mark sel 0 (sub) for trash, paste → moved to the sandboxed trash dir
  seed "$S"; run "$be" "$S" 'dpq'
  ok "$be" "$([ ! -e "$S/sub" ] && [ -e "$S/.local/share/fff/trash/sub" ] && echo Y)" "Y" "trash (d then p)"

  # y + p: yank a.txt (j to it, y), descend into sub (k to sub, l), paste the copy
  seed "$S"; run "$be" "$S" 'jyklpq'
  ok "$be" "$([ -e "$S/sub/a.txt" ] && [ -e "$S/a.txt" ] && echo Y)" "Y" "copy (y then p)"

  # Y + b: mark all, bulk-rename via the scripted editor (prepends r_)
  seed "$S"; printf 'Ybq' | HOME="$S" EDITOR="$ED" "$AXIONC" $([ "$be" = llvm ] && echo --release || echo --backend "$be") "$FFF" -- "$S" >/dev/null 2>&1
  ok "$be" "$([ -e "$S/r_a.txt" ] && [ -e "$S/r_b.txt" ] && [ ! -e "$S/a.txt" ] && echo Y)" "Y" "bulk-rename (Y then b)"
done

if [ "$fail" = 0 ]; then
  echo "OK: fff.axi navigates + operates correctly, identically on ${backends[*]}"
else
  echo "FAIL: file-manager differences above"
  exit 1
fi
