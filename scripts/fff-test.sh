#!/usr/bin/env bash
# Behavioral test for the Axión `fff` rewrite (examples/axfm.axi) — the third flagship.
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
FFF="examples/axfm.axi"
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
  ok "$be" "$([ ! -e "$S/sub" ] && [ -e "$S/.local/share/axfm/trash/sub" ] && echo Y)" "Y" "trash (d, p, y)"

  # trash confirm DECLINED: answering anything but y/Y keeps the file (n = No)
  seed "$S"; run "$be" "$S" 'dpnq'
  ok "$be" "$([ -e "$S/sub" ] && echo Y)" "Y" "trash cancelled (d, p, n)"


  # y + p: yank a.txt (j to it, y), descend into sub (k to sub, l), paste the copy
  seed "$S"; run "$be" "$S" 'jyklpq'
  ok "$be" "$([ -e "$S/sub/a.txt" ] && [ -e "$S/a.txt" ] && echo Y)" "Y" "copy (y then p)"

  # Y + R: mark all, bulk-rename via the scripted editor (prepends r_)
  seed "$S"; printf 'YRq' | HOME="$S" EDITOR="$ED" "$AXIONC" $([ "$be" = llvm ] && echo --release || echo --backend "$be") "$FFF" -- "$S" >/dev/null 2>&1
  ok "$be" "$([ -e "$S/r_a.txt" ] && [ -e "$S/r_b.txt" ] && [ ! -e "$S/a.txt" ] && echo Y)" "Y" "bulk-rename (Y then R)"

  # Y + b with a FAILING editor (rewrites names into a nonexistent subdir) → renameFile fails →
  # doBulk flashes "bulk-rename: some renames failed"; files stay intact. 'd' dismisses the modal.
  BADED="$WORK/bad-ed.sh"; printf '#!/bin/sh\nsed -i "s#^#no_such_dir/#" "$1"\n' > "$BADED"; chmod +x "$BADED"
  seed "$S"; bout="$(printf 'YRdq' | HOME="$S" EDITOR="$BADED" "$AXIONC" $([ "$be" = llvm ] && echo --release || echo --backend "$be") "$FFF" -- "$S" 2>/dev/null)"
  ok "$be" "$(printf '%s' "$bout" | grep -qaF 'bulk-rename: some renames failed' && [ -e "$S/a.txt" ] && echo Y)" "Y" "bulk-rename failure flashes (files intact)"

  # F: filter to a substring — the filtered frame lists only matches. The cumulative capture also
  # holds the initial (unfiltered) frame, so assert by OCCURRENCE COUNT: a.txt appears once (initial
  # only) while b.txt appears twice (initial + filtered), i.e. the filter really hid a.txt.
  seed "$S"; fout="$(printf 'Fb.txt\nq' | HOME="$S" "$AXIONC" $([ "$be" = llvm ] && echo --release || echo --backend "$be") "$FFF" -- "$S" 2>/dev/null)"
  na="$(printf '%s' "$fout" | grep -oaF 'a.txt' | wc -l | tr -d ' ')"
  nb="$(printf '%s' "$fout" | grep -oaF 'b.txt' | wc -l | tr -d ' ')"
  ok "$be" "$([ "$na" = 1 ] && [ "$nb" -ge 2 ] && echo Y)" "Y" "filter (F hides non-matches)"

  # o: cycle the sort flag → persisted to the sandboxed ~/.cache/axfm/sort (name→size = -S).
  seed "$S"; printf 'oq' | HOME="$S" "$AXIONC" $([ "$be" = llvm ] && echo --release || echo --backend "$be") "$FFF" -- "$S" >/dev/null 2>&1
  ok "$be" "$([ "$(cat "$S/.cache/axfm/sort" 2>/dev/null)" = "-S" ] && echo Y)" "Y" "sort toggle (o)"

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
  ok "$be" "$([ -e "$S/a.txt" ] && [ ! -e "$S/.local/share/axfm/trash/a.txt" ] && echo Y)" "Y" "trash undo (u restores)"

  # $LS_COLORS: dir uses di=, a *.png uses the ext rule. Cursor moved off the dir (j) so sub/ shows
  # its di color (not the reverse cursor). Assert both configured SGR codes appear in the frame.
  seed "$S"; : > "$S/pic.png"
  lcout="$(printf 'jq' | LS_COLORS='di=01;32:*.png=01;31' HOME="$S" "$AXIONC" $beflag "$FFF" -- "$S" 2>/dev/null)"
  ok "$be" "$(printf '%s' "$lcout" | grep -qaF "$(printf '\033[01;32m')" && printf '%s' "$lcout" | grep -qaF "$(printf '\033[01;31m')" && echo Y)" "Y" "LS_COLORS (di + *.png)"

  # config.lua `colors`: HEX #RRGGBB → truecolor SGR (38;2;R;G;B) + config OVERRIDES $LS_COLORS. di=#F54927
  # → 38;2;245;73;39 on the non-cursor dir (j moves off it); a *.png hex rule applies to pic.png. Env sets
  # di=01;32 which the config must beat. Also a raw-SGR value (0;33) passes through on *.txt.
  seed "$S"; mkdir -p "$S/.config/axfm"; : > "$S/pic.png"; : > "$S/note.txt"
  printf 'local colors = {\n  { match = "di", color = "#F54927" },\n  { match = "*.png", color = "#5FA8FF" },\n  { match = "*.txt", color = "0;33" },\n}\n' > "$S/.config/axfm/config.lua"
  hxout="$(printf 'jq' | LS_COLORS='di=01;32' HOME="$S" "$AXIONC" $beflag "$FFF" -- "$S" 2>/dev/null)"
  ok "$be" "$(printf '%s' "$hxout" | grep -qaF "$(printf '\033[38;2;245;73;39m')" && printf '%s' "$hxout" | grep -qaF "$(printf '\033[38;2;95;168;255m')" && printf '%s' "$hxout" | grep -qaF "$(printf '\033[0;33m')" && ! printf '%s' "$hxout" | grep -qaF "$(printf '\033[01;32m')" && echo Y)" "Y" "config colors (hex #RRGGBB + override \$LS_COLORS)"

  # CATEGORY match: "image/*" colours every image extension at once. A .png and a .jpg (no per-ext rule)
  # both get the category colour; cursor parked on a non-image (g=top=sub/) so both images are non-cursor.
  seed "$S"; mkdir -p "$S/.config/axfm"; : > "$S/a.png"; : > "$S/b.jpg"
  printf 'local colors = {\n  { match = "image/*", color = "#F54927" },\n}\n' > "$S/.config/axfm/config.lua"
  ctout="$(printf 'gq' | HOME="$S" "$AXIONC" $beflag "$FFF" -- "$S" 2>/dev/null)"
  ok "$be" "$([ "$(printf '%s' "$ctout" | grep -oaF "$(printf '\033[38;2;245;73;39m')" | wc -l)" -ge 2 ] && echo Y)" "Y" "config colors (category image/*)"

  # symlink target + broken in the status line. Minimal store (ONLY the link) so g/top selects it —
  # not a dir (seed's sub/ sorts first). A broken link shows "-> <target> (broken)".
  rm -rf "$S"; mkdir -p "$S"; ln -s nowhere.xyz "$S/bad.lnk"
  slout="$(printf 'gq' | HOME="$S" "$AXIONC" $beflag "$FFF" -- "$S" 2>/dev/null)"
  ok "$be" "$(printf '%s' "$slout" | grep -qaF -- '-> nowhere.xyz (broken)' && echo Y)" "Y" "symlink target + broken in status"

  # ? help overlay: lists the key bindings; any key closes it.
  seed "$S"; hout="$(printf '?xq' | HOME="$S" "$AXIONC" $beflag "$FFF" -- "$S" 2>/dev/null)"
  ok "$be" "$(printf '%s' "$hout" | grep -qaF 'key bindings' && echo Y)" "Y" "help overlay (?)"

  # P copy path: mock wl-copy writes stdin to a file; assert the selected entry's full path lands.
  seed "$S"; mkdir -p "$WORK/cb"; printf '#!/bin/sh\ncat > "%s/clip.out"\n' "$WORK" > "$WORK/cb/wl-copy"; chmod +x "$WORK/cb/wl-copy"
  printf 'Pq' | PATH="$WORK/cb:$PATH" HOME="$S" "$AXIONC" $beflag "$FFF" -- "$S" >/dev/null 2>&1
  ok "$be" "$([ "$(cat "$WORK/clip.out" 2>/dev/null)" = "$S/sub" ] && echo Y)" "Y" "copy path (P)"

  # rename overwrite confirm: a.txt -> b.txt, decline (n) keeps BOTH; no silent clobber.
  seed "$S"; run "$be" "$S" 'jrb.txt\nnq'
  ok "$be" "$([ -e "$S/a.txt" ] && [ -e "$S/b.txt" ] && echo Y)" "Y" "rename overwrite declined (both kept)"

  # per-entry type coloring: a good symlink (ln) and a broken symlink (or) get their LS_COLORS codes.
  # Minimal store so both links are visible non-cursor rows; G puts the cursor on the last (zzz).
  rm -rf "$S"; mkdir -p "$S"; : > "$S/target"; ln -s target "$S/glink"; ln -s nowhere "$S/hbad"; : > "$S/zzz"
  tcout="$(printf 'Gq' | LS_COLORS='ln=01;36:or=01;31' HOME="$S" "$AXIONC" $beflag "$FFF" -- "$S" 2>/dev/null)"
  ok "$be" "$(printf '%s' "$tcout" | grep -qaF "$(printf '\033[01;36m')" && printf '%s' "$tcout" | grep -qaF "$(printf '\033[01;31m')" && echo Y)" "Y" "per-entry coloring (symlink ln + broken or)"

  # b set bookmark + B jump: set mark m at root (b then a SINGLE key m, no Enter), enter sub (l), jump
  # back with B then a SINGLE key m. Final cwd (the cd-file on quit) is root; the bookmark file records it.
  seed "$S"; run "$be" "$S" 'bmlBmq'
  ok "$be" "$([ "$(cat "$S/.cache/axfm/axfm.d" 2>/dev/null)" = "$S" ] && grep -qF "$S" "$S/.cache/axfm/bookmarks" && echo Y)" "Y" "bookmark set + jump (b then B)"

  # i disk usage: flash the recursive size of the selection (sel 0 = sub/) → "sub: <size>" appears.
  seed "$S"; diout="$(printf 'iq' | HOME="$S" "$AXIONC" $beflag "$FFF" -- "$S" 2>/dev/null)"
  ok "$be" "$(printf '%s' "$diout" | grep -qaF 'sub: ' && echo Y)" "Y" "disk usage flash (i)"

  # count-prefixed motion: 2j from sel 0 lands on sel 2 (of 3 entries) → the status shows (3/3).
  seed "$S"; cnout="$(printf '2jq' | HOME="$S" "$AXIONC" $beflag "$FFF" -- "$S" 2>/dev/null)"
  ok "$be" "$(printf '%s' "$cnout" | grep -qaF '(3/3)' && echo Y)" "Y" "count-prefixed motion (2j)"

  # paste "working…" flash: copy a.txt into sub (j y k l p) → the yellow banner is emitted, copy lands.
  seed "$S"; wkout="$(printf 'jyklpq' | HOME="$S" "$AXIONC" $beflag "$FFF" -- "$S" 2>/dev/null)"
  ok "$be" "$(printf '%s' "$wkout" | grep -qaF 'copying 1 item(s)' && [ -e "$S/sub/a.txt" ] && echo Y)" "Y" "paste working flash"

  # t new tab → the tabs file gains a second line; the status bar shows a 2-tab bar.
  seed "$S"; tnout="$(printf 'tq' | HOME="$S" "$AXIONC" $beflag "$FFF" -- "$S" 2>/dev/null)"
  ok "$be" "$([ "$(wc -l < "$S/.cache/axfm/tabs" 2>/dev/null)" = 2 ] && printf '%s' "$tnout" | grep -qaF '1:' && echo Y)" "Y" "new tab (t)"

  # tab switch: t (2 tabs), l (tab2 → sub), [ (back to tab1 = root) → final cwd is root.
  seed "$S"; run "$be" "$S" 'tl[q'
  ok "$be" "$([ "$(cat "$S/.cache/axfm/axfm.d" 2>/dev/null)" = "$S" ] && echo Y)" "Y" "tab switch (]/[)"

  # tab close: t then T returns to a single tab.
  seed "$S"; printf 'tTq' | HOME="$S" "$AXIONC" $beflag "$FFF" -- "$S" >/dev/null 2>&1
  ok "$be" "$([ "$(wc -l < "$S/.cache/axfm/tabs" 2>/dev/null)" = 1 ] && echo Y)" "Y" "close tab (T)"

  # Lua config remap: ~/.config/axfm/config.lua binds z→doDiskUsage, so z flashes the selection's
  # size (sel 0 = sub) exactly as i would — proving the keymap is parsed and the dispatcher honours it.
  seed "$S"; mkdir -p "$S/.config/axfm"
  printf 'local keys = {\n  { key = "z", action = "doDiskUsage" },\n}\n' > "$S/.config/axfm/config.lua"
  rmout="$(printf 'zq' | HOME="$S" "$AXIONC" $beflag "$FFF" -- "$S" 2>/dev/null)"
  ok "$be" "$(printf '%s' "$rmout" | grep -qaF 'sub: ' && echo Y)" "Y" "lua config remap (z→doDiskUsage)"

  # Multi-key SEQUENCE: config binds "gh" (g leader → h) to home. From inside sub/, l then g then h
  # lands back at $HOME (= the sandboxed $S); the cd-file written on quit proves the final directory.
  seed "$S"; mkdir -p "$S/.config/axfm"
  printf 'local keys = {\n  { key = "gh", action = "home" },\n}\n' > "$S/.config/axfm/config.lua"
  printf 'lghq' | HOME="$S" "$AXIONC" $beflag "$FFF" -- "$S" >/dev/null 2>&1
  ok "$be" "$([ "$(cat "$S/.cache/axfm/axfm.d" 2>/dev/null)" = "$S" ] && echo Y)" "Y" "multi-key sequence (g h → home)"

  # Shell-command binding: `!`-prefixed action runs a shell command (silent). z → !touch marker.
  seed "$S"; mkdir -p "$S/.config/axfm"
  printf 'local keys = {\n  { key = "z", action = "!touch zzz_ran" },\n}\n' > "$S/.config/axfm/config.lua"
  printf 'zq' | HOME="$S" "$AXIONC" $beflag "$FFF" -- "$S" >/dev/null 2>&1
  ok "$be" "$([ -f "$S/zzz_ran" ] && echo Y)" "Y" "shell-command binding (!touch)"

  # %s placeholder → the selected entry's (safely-quoted) path. Cursor on sub (index 0): z writes its
  # basename to a file; assert the file holds "sub" (proves %s substitution + quoting through sh).
  seed "$S"; mkdir -p "$S/.config/axfm"
  printf 'local keys = {\n  { key = "z", action = "!basename %%s > selname" },\n}\n' > "$S/.config/axfm/config.lua"
  printf 'zq' | HOME="$S" "$AXIONC" $beflag "$FFF" -- "$S" >/dev/null 2>&1
  ok "$be" "$([ "$(cat "$S/selname" 2>/dev/null)" = sub ] && echo Y)" "Y" "shell-command %s (selected path)"

  # `!!`-prefixed action runs INTERACTIVELY (on the real terminal, output NOT suppressed) — for commands
  # that prompt (sudo / zfs passphrase / editor). Assert its stdout reaches the captured frame, whereas a
  # plain `!` command's output is swallowed (the preceding tests rely on that suppression).
  seed "$S"; mkdir -p "$S/.config/axfm"
  printf 'local keys = {\n  { key = "z", action = "!!echo TTYPROOF" },\n}\n' > "$S/.config/axfm/config.lua"
  ttyout="$(printf 'zq' | HOME="$S" "$AXIONC" $beflag "$FFF" -- "$S" 2>/dev/null)"
  ok "$be" "$(printf '%s' "$ttyout" | grep -qaF 'TTYPROOF' && echo Y)" "Y" "interactive shell-command (!! not suppressed)"

  # `cd <path>` action navigates into that dir (absolute path). Put a marker inside sub/, bind z to cd
  # there, assert the post-z frame lists the marker (proves the cwd changed into sub/).
  seed "$S"; mkdir -p "$S/.config/axfm"; : > "$S/sub/cdmarker.txt"
  printf 'local keys = {\n  { key = "z", action = "cd %s/sub" },\n}\n' "$S" > "$S/.config/axfm/config.lua"
  cdout="$(printf 'zq' | HOME="$S" "$AXIONC" $beflag "$FFF" -- "$S" 2>/dev/null)"
  ok "$be" "$(printf '%s' "$cdout" | grep -qaF 'cdmarker.txt' && echo Y)" "Y" "cd <path> action (jump into dir)"

  # Multi-action combining an interactive `!!` step THEN a `cd` jump (the unlock-pool-and-open idiom):
  # z makes a dir via !!, then cd's into it; assert the marker file inside is listed after.
  seed "$S"; mkdir -p "$S/.config/axfm"
  printf 'local keys = {\n  { key = "z", action = { "!!mkdir -p %s/pool", "cd %s/pool" } },\n}\n' "$S" "$S" > "$S/.config/axfm/config.lua"
  printf 'zfinside\nq' | HOME="$S" "$AXIONC" $beflag "$FFF" -- "$S" >/dev/null 2>&1
  ok "$be" "$([ -f "$S/pool/inside" ] && echo Y)" "Y" "multi-action !! then cd (ran in new cwd)"

  # Multi-action: a named function AND an inline list both run their items in order. z→named Two,
  # x→inline pair; each touches two markers. Asserts all four exist (both surfaces, sequencing).
  seed "$S"; mkdir -p "$S/.config/axfm"
  printf 'local Two = { "!touch F1", "!touch F2" }\nlocal keys = {\n  { key = "z", action = "Two" },\n  { key = "x", action = { "!touch G1", "!touch G2" } },\n}\n' > "$S/.config/axfm/config.lua"
  printf 'zxq' | HOME="$S" "$AXIONC" $beflag "$FFF" -- "$S" >/dev/null 2>&1
  ok "$be" "$([ -f "$S/F1" ] && [ -f "$S/F2" ] && [ -f "$S/G1" ] && [ -f "$S/G2" ] && echo Y)" "Y" "multi-action (named fn + inline list)"

  # Built-in + shell mix, in order: {"down","!basename %s > out"}. Cursor 0=sub; `down` moves to a.txt
  # BEFORE the shell records the selection → out holds "a.txt" (proves order + the built-in ran).
  seed "$S"; mkdir -p "$S/.config/axfm"
  printf 'local keys = {\n  { key = "z", action = { "down", "!basename %%s > out" } },\n}\n' > "$S/.config/axfm/config.lua"
  printf 'zq' | HOME="$S" "$AXIONC" $beflag "$FFF" -- "$S" >/dev/null 2>&1
  ok "$be" "$([ "$(cat "$S/out" 2>/dev/null)" = a.txt ] && echo Y)" "Y" "multi-action built-in+shell order"
done

if [ "$fail" = 0 ]; then
  echo "OK: axfm.axi navigates + operates correctly, identically on ${backends[*]}"
else
  echo "FAIL: file-manager differences above"
  exit 1
fi
