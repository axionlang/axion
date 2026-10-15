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

  # d + p + y: mark sel 0 (sub) for trash, paste, CONFIRM the y/N prompt → moved to sandboxed trash
  seed "$S"; run "$be" "$S" 'dpyq'
  ok "$be" "$([ ! -e "$S/sub" ] && [ -e "$S/.local/share/fff/trash/sub" ] && echo Y)" "Y" "trash (d, p, y)"

  # trash confirm DECLINED: answering anything but y/Y keeps the file (n = No)
  seed "$S"; run "$be" "$S" 'dpnq'
  ok "$be" "$([ -e "$S/sub" ] && echo Y)" "Y" "trash cancelled (d, p, n)"


  # y + p: yank a.txt (j to it, y), descend into sub (k to sub, l), paste the copy
  seed "$S"; run "$be" "$S" 'jyklpq'
  ok "$be" "$([ -e "$S/sub/a.txt" ] && [ -e "$S/a.txt" ] && echo Y)" "Y" "copy (y then p)"

  # Y + b: mark all, bulk-rename via the scripted editor (prepends r_)
  seed "$S"; printf 'Ybq' | HOME="$S" EDITOR="$ED" "$AXIONC" $([ "$be" = llvm ] && echo --release || echo --backend "$be") "$FFF" -- "$S" >/dev/null 2>&1
  ok "$be" "$([ -e "$S/r_a.txt" ] && [ -e "$S/r_b.txt" ] && [ ! -e "$S/a.txt" ] && echo Y)" "Y" "bulk-rename (Y then b)"

  # F: filter to a substring — the filtered frame lists only matches. The cumulative capture also
  # holds the initial (unfiltered) frame, so assert by OCCURRENCE COUNT: a.txt appears once (initial
  # only) while b.txt appears twice (initial + filtered), i.e. the filter really hid a.txt.
  seed "$S"; fout="$(printf 'Fb.txt\nq' | HOME="$S" "$AXIONC" $([ "$be" = llvm ] && echo --release || echo --backend "$be") "$FFF" -- "$S" 2>/dev/null)"
  na="$(printf '%s' "$fout" | grep -oaF 'a.txt' | wc -l | tr -d ' ')"
  nb="$(printf '%s' "$fout" | grep -oaF 'b.txt' | wc -l | tr -d ' ')"
  ok "$be" "$([ "$na" = 1 ] && [ "$nb" -ge 2 ] && echo Y)" "Y" "filter (F hides non-matches)"

  # o: cycle the sort flag → persisted to the sandboxed ~/.cache/fff/sort (name→size = -S).
  seed "$S"; printf 'oq' | HOME="$S" "$AXIONC" $([ "$be" = llvm ] && echo --release || echo --backend "$be") "$FFF" -- "$S" >/dev/null 2>&1
  ok "$be" "$([ "$(cat "$S/.cache/fff/sort" 2>/dev/null)" = "-S" ] && echo Y)" "Y" "sort toggle (o)"

  # J/K scroll the TEXT preview: select a tall file (G = last entry = tall.txt), compare the highest
  # LINE<n> visible with no scroll vs after two J presses — scrolling must reveal higher line numbers.
  # (Pane is on headlessly: stty-size fails on the pipe → 80-col fallback ≥ splitMin.)
  seed "$S"; seq 1 300 | sed 's/^/LINE/' > "$S/tall.txt"
  beflag="$([ "$be" = llvm ] && echo --release || echo --backend "$be")"
  mx() { printf '%s' "$1" | grep -oaE 'LINE[0-9]+' | sed 's/LINE//' | sort -n | tail -1; }
  s1="$(printf 'Gq'   | HOME="$S" "$AXIONC" $beflag "$FFF" -- "$S" 2>/dev/null)"
  s2="$(printf 'GJJq' | HOME="$S" "$AXIONC" $beflag "$FFF" -- "$S" 2>/dev/null)"
  m1="$(mx "$s1")"; m2="$(mx "$s2")"
  ok "$be" "$([ -n "$m1" ] && [ -n "$m2" ] && [ "$m2" -gt "$m1" ] && echo Y)" "Y" "preview scroll (J reveals lower lines)"

  # code preview: a .rs file (code extension) goes through the highlight path; without `bat` on PATH
  # it falls back to sed in-shell, so the source still renders (drawLinesAnsi/clipAnsi on plain text).
  seed "$S"; printf 'fn uniquetoken() {}\n' > "$S/code.rs"
  cout="$(printf 'Gq' | HOME="$S" "$AXIONC" $beflag "$FFF" -- "$S" 2>/dev/null)"
  ok "$be" "$(printf '%s' "$cout" | grep -qaF 'uniquetoken' && echo Y)" "Y" "code preview renders (bat→sed fallback)"

  # incremental search: start on a.txt (sel 0), type /zmark then Enter → cursor jumps to zmark.txt,
  # whose preview shows its content. The jump happens while typing (search renders per keystroke).
  seed "$S"; printf 'ZPREVIEW\n' > "$S/zmark.txt"
  iout="$(printf '/zmark\nq' | HOME="$S" "$AXIONC" $beflag "$FFF" -- "$S" 2>/dev/null)"
  ok "$be" "$(printf '%s' "$iout" | grep -qaF 'ZPREVIEW' && echo Y)" "Y" "incremental search jumps to match"

  # u undo-trash: trash a.txt (g top=sub, j=a.txt, d mark, p paste, y confirm), then u restores it to
  # its original path. One session: trash → listing drops a.txt → u → a.txt back, trash emptied.
  seed "$S"; run "$be" "$S" 'gjdpyuq'
  ok "$be" "$([ -e "$S/a.txt" ] && [ ! -e "$S/.local/share/fff/trash/a.txt" ] && echo Y)" "Y" "trash undo (u restores)"
done

if [ "$fail" = 0 ]; then
  echo "OK: fff.axi navigates + operates correctly, identically on ${backends[*]}"
else
  echo "FAIL: file-manager differences above"
  exit 1
fi
