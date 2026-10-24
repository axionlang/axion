-- axfm.axi — a rewrite of `fff` (dylanaraps/fff, "fucking fast file-manager") in Axión.
-- The third flagship: a scrolling, colored, marked-files file manager with a full command line.
-- GC-free + memory-safe by construction; runs identically on interp / --dev / --release.
--
-- Keys (fff defaults): j/k or ↓/↑ move · g/G top/bottom · l/→/Enter open · h/← parent
--   . toggle hidden · e refresh · - previous dir · ~ home · 1-9 favourites (FFF_FAV<n>) · : go dir
--   b set bookmark · B jump to bookmark · i size (du) · <N>j/<N>k/<N>G count-prefixed motion
--   t new tab · T close tab · ] / [ next / prev tab (tabs persist only within a session)
--   / search (incremental — jumps as you type; Enter confirm, Esc cancel) · ; / , next / prev match
--   o cycle sort (name/size/mtime) · F filter
--   J/K scroll the preview (text/dir/archive)
--   ! shell · n mkdir · f mkfile · r rename · x attributes(stat) · X chmod±x
--   y/m/s/d mark (cp/mv/ln/trash) · Y/M/S/D mark all · c clear marks · p paste (trash asks y/N)
--   u undo-trash (restore last trashed) · R bulk-rename · P copy path to clipboard · ? help · q quit
--
-- Live preview: a split pane (right half) previews the SELECTED entry as the cursor moves —
--   directories as an `ls`, text as `head`, binaries as a `file` description. IMAGES render as real
--   pixels via the terminal graphics protocol (`kitten icat`, else `img2sixel`); VIDEOS render an
--   extracted frame (ffmpegthumbnailer, else ffmpeg) the same way. Rendered sixels + video thumbnails
--   are cached under ~/.cache/axfm so a revisit is instant. With no graphics tool a textual header +
--   hint is shown instead. The pane drops to a full-width list on a narrow terminal.
-- Usage: source scripts/axfm-wrapper.sh from your shell rc (nushell: axfm-wrapper.nu) and run `axfm
--   [DIR]`. The wrapper gives
--   cd-on-quit (axfm writes its last dir to ~/.cache/axfm/axfm.d; a child can't cd its parent shell)
--   AND a `trap` that always restores the terminal — Axión has no signal handlers, so without it a
--   SIGINT/SIGTERM/kill or crash would leave the alt-screen up with echo off (a clean q/EOF resets).
-- Honest scope vs fff: list colors honour $LS_COLORS — dirs (`di`), symlinks (`ln`), broken links
-- (`or`), executables (`ex`), and extensions (`*.ext`) — with a built-in palette fallback; per-entry
-- types for the visible window are classified in one bounded shell fork per frame (visTypes), and
-- the SELECTED symlink's target (+ broken state) is shown in the status line. Axión has no SIGWINCH,
-- so a resize is caught by POLLING `stty size` every 500 ms while idle (on a
-- tty) and redrawing when it changes — not instant, but automatic (`e` still forces a refresh). A
-- plain Esc resolves at once — follow-on arrow bytes are read with readKeyTimeout (25 ms). The
-- command line reads keys directly (chr/readKey), so tab-completion and live-search need no readLine.

------------------------------------------------------------------- shell-safety + path helpers

-- POSIX single-quote for safe `sh -c` interpolation (byte 39 = `'`); injection-proof for any input.
shQuote :: String -> String
shQuote s = strAppend "'" (strAppend (shEsc s 0 (strLen s)) "'")
shEsc :: String -> Int -> Int -> String
shEsc s i n =
  if i >= n then ""
  else (if charAt i s == '\''
        then "'\\''" ++ shEsc s (i + 1) n
        else substr i 1 s ++ shEsc s (i + 1) n)

-- Path join: avoid a double slash after a trailing "/".
(</>) :: String -> String -> String
(</>) a b
  | hasSuffix "/" a = strAppend a b
  | otherwise       = strAppend a (strAppend "/" b)

-- A FRESH copy (substr allocates) — the safe way to pull a value out of an owned list (no alias).
dup :: String -> String
dup s = substr 0 (strLen s) s

-- Drop the trailing "/" that `ls -p` puts on directories (fresh copy either way).
stripSlash :: String -> String
stripSlash s = if hasSuffix "/" s then substr 0 (strLen s - 1) s else dup s

------------------------------------------------------------------- ANSI (the `\e` escape is ESC)

esc :: String
esc = "\x1b"

-- CSI sequence: ESC [ <body>.
csi :: String -> String
csi s = esc ++ "[" ++ s

-- Wrap s in the SGR color `c`, then reset.
paint :: String -> String -> String
paint c s = csi (c ++ "m") ++ s ++ csi "m"

-- Alt screen + hide cursor + clear (setup); undo it all (reset). Line-wrap left on (harmless).
setupSeq :: String
setupSeq = strAppend (csi "?1049h") (strAppend (csi "?25l") (csi "2J"))
resetSeq :: String
resetSeq = strAppend (csi "?25h") (strAppend (csi "2J") (csi "?1049l"))
-- Home the cursor + clear the whole screen (each frame).
homeClear :: String
homeClear = strAppend (csi "2J") (csi "H")

------------------------------------------------------------------- terminal size + directory listing

-- Terminal rows via `stty size` ("LINES COLS"); default 24 on a pipe (non-tty) where stty fails.
firstWord :: String -> String
firstWord s = pick 0 (words s)
termRows :: Int -> Int
termRows dummy = fromMaybe 24 (readInt (firstWord (runCapture "stty size")))
-- Terminal columns: the SECOND word of `stty size`; default 80 on a pipe (non-tty) where stty fails.
termCols :: Int -> Int
termCols dummy = colsOf (runCapture "stty size")
-- Parse COLS from an already-captured `stty size` string ("LINES COLS") — pure, no subprocess, so a
-- frame can `stty` once and reuse the result. 80 if absent.
colsOf :: String -> Int
colsOf sz = fromMaybe 80 (readInt (pick 1 (words sz)))

-- Max list rows in the viewport (leave 2 rows: a header and the status line).
maxItems :: Int -> Int
maxItems rows = if rows - 3 < 1 then 1 else rows - 3

------------------------------------------------------------------- split-pane geometry

-- Below this width there is no room for a preview pane — the list stays full-width (as classic fff).
splitMin :: Int
splitMin = 60
-- Left list column width: half the screen when wide enough, else the whole width (preview off).
listWidth :: Int -> Int
listWidth cols = if cols >= splitMin then cols `div` 2 else cols
-- 1-based start column of the preview pane (just right of the "│" separator at listWidth + 1).
paneX :: Int -> Int
paneX cols = listWidth cols + 2
-- Preview content width (columns paneX..cols); non-positive when the list is full-width.
paneW :: Int -> Int
paneW cols = cols - paneX cols + 1
-- Is the pane wide enough to be worth drawing?
previewOn :: Int -> Bool
previewOn cols = paneW cols > 4

-- One `ls` listing the dir DIRECTORIES-FIRST with a trailing "/" on dirs (no per-entry `test -d`).
-- `hidden`=1 shows dotfiles (-A). One subprocess per frame, not one per entry. The sort flag and
-- the active filter are read from ~/.cache/axfm/{sort,filter} IN THE SAME subshell (no extra fork):
-- $o appends an ls sort flag (""=name, -S=size, -t=mtime), and a non-empty $fq pipes the listing
-- through `grep -iF` so the whole view (and every op derived from it) filters consistently.
lsCmd :: String -> Int -> String
lsCmd cwd hidden =
  strAppend "o=''; [ -r \"$HOME/.cache/axfm/sort\" ] && read o < \"$HOME/.cache/axfm/sort\" 2>/dev/null; fq=''; [ -r \"$HOME/.cache/axfm/filter\" ] && read fq < \"$HOME/.cache/axfm/filter\" 2>/dev/null; "
    (strAppend (if hidden == 1 then "ls -Ap --group-directories-first $o -- " else "ls -p --group-directories-first $o -- ")
      (strAppend (shQuote cwd)
        " 2>/dev/null | { if [ -n \"$fq\" ]; then grep -iF -- \"$fq\"; else cat; fi; }"))
entriesRaw :: String -> Int -> List String
entriesRaw cwd hidden = lines (runCapture (lsCmd cwd hidden))
nEntries :: String -> Int -> Int
nEntries cwd hidden = length (entriesRaw cwd hidden)

-- The sel-th raw entry (still with any trailing "/") as a FRESH copy; "" if out of range.
pick :: Int -> List String -> String
pick i xs = case xs of
  Nil -> ""
  Cons y ys -> if i == 0 then dup y else pick (i - 1) ys

-- WINDOWED line access over the cached `ls` string, so a frame touches only the ~screenful it shows
-- instead of re-parsing all N lines into a fresh list every keystroke (the 5000-file freeze: `lines`
-- allocates one String per entry, and `countLines raw` walked them all — O(N) ALLOCS per key).
-- `countLines` counts newlines with NO allocation; `windowLines`/`lineAt` scan to the wanted line
-- offset (no alloc) and materialise only the lines asked for. All O(offset)-scan + O(count)-alloc.
countLines :: String -> Int
countLines s = clGo s 0 (strLen s)
clGo :: String -> Int -> Int -> Int
clGo s i n = if i >= n then 0 else let j = findChar 10 s i n in 1 + (if j + 1 >= n then 0 else clGo s (j + 1) n)
-- Byte offset where line `idx` begins (strLen when past the end).
lineOffset :: String -> Int -> Int
lineOffset s idx = loGo s idx 0 (strLen s)
loGo :: String -> Int -> Int -> Int -> Int
loGo s idx i n = if idx <= 0 || i >= n then i else loGo s (idx - 1) (findChar 10 s i n + 1) n
-- Up to `count` lines starting at line `start`, as a fresh List (aligned so head = entry `start`).
windowLines :: String -> Int -> Int -> List String
windowLines s start count = wlGo s (lineOffset s start) (strLen s) count
wlGo :: String -> Int -> Int -> Int -> List String
wlGo s i n left =
  if left <= 0 || i >= n then Nil
  else let j = findChar 10 s i n in Cons (substr i (j - i) s) (wlGo s (j + 1) n (left - 1))
-- The single line at index `idx` (fresh copy), "" if past the end — the windowed twin of `pick`.
lineAt :: String -> Int -> String
lineAt s idx = let i = lineOffset s idx in if i >= strLen s then "" else substr i (findChar 10 s i (strLen s) - i) s

-- The selected entry's NAME (slash stripped) and full PATH.
selName :: String -> Int -> Int -> String
selName cwd hidden sel = stripSlash (pick sel (entriesRaw cwd hidden))
selPath :: String -> Int -> Int -> String
selPath cwd hidden sel = cwd </> selName cwd hidden sel

------------------------------------------------------------------- marked files (newline-joined paths)

-- Is `p` one of the newline-joined lines of `m`?
markedHas :: String -> String -> Bool
markedHas m p = elemBy p (lines m)

-- Toggle `p` in the marked set: drop it if present, else append a line.
markToggle :: String -> String -> String
markToggle m p =
  if markedHas m p
  then unlines (filter (neStr p) (lines m))
  else strAppend m (strAppend p "\n")

neStr :: String -> String -> Bool
neStr a b = not (a == b)

-- Count of marked paths.
markCount :: String -> Int
markCount m = length (filter nonEmpty (lines m))
nonEmpty :: String -> Bool
nonEmpty s = strLen s > 0

------------------------------------------------------------------- scroll viewport

-- First visible index. EDGE scrolling (not centered): the top stays anchored through the whole first
-- screenful (so the top entry doesn't scroll off at the midpoint), then once the cursor would leave the
-- bottom it scrolls one row at a time, pinning the cursor to the last visible row.
viewStart :: Int -> Int -> Int -> Int
viewStart sel total mx =
  if total <= mx then 0
  else if sel < mx then 0
  else sel - mx + 1

-- Render the visible window [start, start+mx) of the list, each row clipped/padded to `listW` cells
-- and followed by the "│" separator when `prev` (a preview pane sits to the right). homeClear wipes
-- the whole screen each frame, so no per-row clear-to-EOL is needed (it would eat the preview).
-- Draws the visible rows [start,endIdx). `tys` carries the type chars for JUST that window (from
-- visTypes, aligned so its head = the entry at index `start`): consumed only inside the window, left
-- untouched while skipping rows before it. If `tys` runs short (e.g. a stale/empty types cache) the row
-- is still drawn with a default file type — the ENTRY is never dropped, only its colour defaults.
-- `win` is ALREADY the visible window (lines [start, start+mx) from `windowLines`), aligned with `tys`;
-- `row` is the entry index of win's head (= start), used only for the cursor-highlight (`row == sel`).
-- No skip-walk over the whole list — O(window). `lsc` = $LS_COLORS, read once per frame and threaded in.
drawRows :: String -> String -> List String -> List String -> Int -> Int -> String -> String -> Int -> Bool -> String
drawRows lsc icfg win tys row sel marked cwd listW prev = case win of
  Nil -> ""
  Cons y ys -> case tys of
    Nil -> strAppend (rowFor lsc icfg y (fallbackTy y) row sel marked cwd listW prev)
                      (drawRows lsc icfg ys Nil (row + 1) sel marked cwd listW prev)
    Cons ty tyss -> strAppend (rowFor lsc icfg y ty row sel marked cwd listW prev)
                      (drawRows lsc icfg ys tyss (row + 1) sel marked cwd listW prev)
-- When the background type classifier hasn't landed yet (no cached types), colour by what the listing
-- already tells us for free: a trailing `/` (from `ls -p`) ⇒ a directory, everything else a plain file.
fallbackTy :: String -> String
fallbackTy y = if hasSuffix "/" y then "d" else "f"

-- "*" if `full` is marked, else " " (a literal — never a let-bound conditional heap value).
markChar :: String -> String -> String
markChar marked full = if markedHas marked full then "*" else " "

-- Clip to at most w cells (ASCII), right-pad with spaces to exactly w — a fixed-width cell. Sizing
-- the PLAIN text before coloring keeps ANSI escapes out of the width count.
clip :: String -> Int -> String
clip s w = if strLen s > w then substr 0 w s else dup s
-- Clip to at most `w` VISIBLE columns, passing ANSI escape sequences through UNCOUNTED — so a
-- syntax-highlighted line is cut by its visible width, not its color bytes, and a cut never lands
-- mid-escape. Trailing escapes (a line-end reset) still pass even past `w`. For code previews.
clipAnsi :: String -> Int -> String
clipAnsi s w = clipGo s 0 (strLen s) 0 w
clipGo :: String -> Int -> Int -> Int -> Int -> String
clipGo s i n vis w =
  if i >= n then ""
  else if charAt i s == 27
  then let j = escEnd s (i + 1) n in strAppend (substr i (j - i) s) (clipGo s j n vis w)
  else if vis >= w then clipGo s (i + 1) n vis w
  else strAppend (substr i 1 s) (clipGo s (i + 1) n (vis + 1) w)
-- Index just past an ANSI escape that starts at ESC: a CSI (ESC[) runs to a final byte @..~ (64..126);
-- any other escape consumes one following byte.
escEnd :: String -> Int -> Int -> Int
escEnd s i n =
  if i >= n then n
  else if charAt i s == '[' then escFinal s (i + 1) n
  else i + 1
escFinal :: String -> Int -> Int -> Int
escFinal s i n =
  if i >= n then n
  else if (charAt i s >= 64) && (charAt i s <= 126) then i + 1
  else escFinal s (i + 1) n
-- `n` spaces in O(n): double a seed string up to length (O(n) total copies), then clip — NOT the old
-- `" " ++ spaces (n-1)` which re-copied the tail each step (O(n²), and this runs per cell per frame).
spaces :: Int -> String
spaces n = if n <= 0 then "" else substr 0 n (grow " " n)
grow :: String -> Int -> String
grow s need = if strLen s >= need then s else grow (strAppend s s) need
fit :: String -> Int -> String
fit s w = let c = clip s w in strAppend c (spaces (w - strLen c))
-- In split mode pad to the column so the "│" separator lines up; full-width just clips (original look).
sizedCell :: String -> Int -> Bool -> String
sizedCell plain listW prev = if prev then fit plain listW else clip plain listW

-- Color a fixed-width cell: reverse-video for the cursor row, else the SGR `col` (a dir/extension
-- color, "" = default). Both arms consume `cell` via `paint` (empty SGR = reset) → no mixed return.
colorCell :: String -> Int -> Int -> String -> String
colorCell cell i sel col =
  if i == sel then paint "7" cell
  else paint col cell

------------------------------------------------------------------- type / extension colors

-- The extension (after the LAST '.'), lowercased via the prelude's `toLower`/`lastIndex`;
-- "" if the name has no dot. (.JPG and .jpg land in the same bucket.)
extOf :: String -> String
extOf s =
  let k = lastIndex '.' s 0 (0 - 1) in
  if k < 0 then "" else toLower (substr (k + 1) (strLen s - k - 1) s)

-- The user's $LS_COLORS (a `key=val:key=val:…` string; "" if unset). Read per lookup — getEnv is a
-- cheap env read (no subprocess), not the per-frame `ls` fork.
-- Config colours (from config.lua's `colors` table, cached by `buildColors`) PREPENDED to the shell's
-- $LS_COLORS. Config wins: `lscScan` matches a `key=` only at index 0 or just after a `:`, so the
-- config fragment (which comes first) is found before any same-named env entry; the env still supplies
-- anything the config omits. Leading/double/trailing `:` are harmless empty segments.
lsColors :: Int -> String
lsColors d = strAppend (readFile (colorsFile 0)) (strAppend ":" (getEnv "LS_COLORS"))
-- The SGR value for `key` (e.g. "di" or "*.png") in an LS_COLORS string, or "" if absent. A key
-- matches only at a boundary (index 0 or right after ':'), so "di" never matches inside "*.di=…".
lscVal :: String -> String -> String
lscVal lsc key = let pat = strAppend key "=" in lscScan lsc pat 0 (strLen lsc) (strLen pat)
lscScan :: String -> String -> Int -> Int -> Int -> String
lscScan s pat i n plen =
  if i + plen > n then ""
  else if ((i == 0) || (charAt (i - 1) s == ':')) && (substr i plen s == pat)
       then lscTake s (i + plen) n
       else lscScan s pat (i + 1) n plen
-- The value from index j up to the next ':' (or end).
lscTake :: String -> Int -> Int -> String
lscTake s j n = substr j (lscEnd s j n - j) s
lscEnd :: String -> Int -> Int -> Int
lscEnd s j n = if j >= n then n else if charAt j s == ':' then j else lscEnd s (j + 1) n

-- SGR color for an entry, from its TYPE CHAR (typesCmd) + name: honour $LS_COLORS (`di`/`ln`/`or`/
-- `ex`, and `*.<ext>` for plain files), else a built-in fallback. `dup`/literal keep each owned temp
-- borrow-only (no conditionally-moved String — the rootIfEmpty idiom; avoids the AX0911 gotcha).
entryColor :: String -> String -> String -> String
entryColor lsc ty raw =
  if ty == "d" then dirColor lsc
  else if ty == "l" then lnColor lsc
  else if ty == "b" then orColor lsc
  else if ty == "x" then exColor lsc
  else fileColor lsc (extOf raw)
dirColor :: String -> String
dirColor lsc = let c = lscVal lsc "di" in if strLen c > 0 then dup c else "1;34"
lnColor :: String -> String
lnColor lsc = let c = lscVal lsc "ln" in if strLen c > 0 then dup c else "1;36"
orColor :: String -> String
orColor lsc = let c = lscVal lsc "or" in if strLen c > 0 then dup c else "1;31"
exColor :: String -> String
exColor lsc = let c = lscVal lsc "ex" in if strLen c > 0 then dup c else "1;32"
-- Colour for a plain file by extension, most-specific first: an exact `*.ext` config/LS_COLORS rule →
-- a CATEGORY rule `image/*`/`video/*`/`audio/*`/`archive/*`/`doc/*`/`code/*` (colours every extension in
-- that built-in bucket at once) → the built-in palette. The dup/literal keeps each owned temp borrow-only.
fileColor :: String -> String -> String
fileColor lsc ext =
  let c = lscVal lsc (strAppend "*." ext) in
  if strLen c > 0 then dup c else catOrBuiltin lsc ext
catOrBuiltin :: String -> String -> String
catOrBuiltin lsc ext =
  let cc = catColor lsc ext in
  if strLen cc > 0 then dup cc else colorForExt ext
-- The config/LS_COLORS value for this extension's CATEGORY key (`<cat>/*`), or "" — a non-categorised
-- extension yields `/*`, which is never a configured key, so the lookup is empty and we fall through.
catColor :: String -> String -> String
catColor lsc ext = lscVal lsc (strAppend (catOf ext) "/*")
-- The category of an extension (via the same buckets `colorForExt` uses), "" if none.
catOf :: String -> String
catOf e =
  if elemBy e imageExts then "image"
  else if elemBy e videoExts then "video"
  else if elemBy e audioExts then "audio"
  else if elemBy e archiveExts then "archive"
  else if elemBy e docExts then "doc"
  else if elemBy e codeExts then "code"
  else ""
colorForExt :: String -> String
colorForExt e =
  if elemBy e imageExts then "1;35"
  else if elemBy e videoExts then "1;35"
  else if elemBy e audioExts then "0;36"
  else if elemBy e archiveExts then "1;31"
  else if elemBy e docExts then "0;33"
  else if elemBy e codeExts then "1;32"
  else ""
imageExts :: List String
imageExts = ["jpg", "jpeg", "png", "gif", "bmp", "webp", "svg", "tiff", "ico", "heic"]
videoExts :: List String
videoExts = ["mp4", "mkv", "webm", "mov", "avi", "flv", "wmv", "m4v", "mpg", "mpeg"]
audioExts :: List String
audioExts = ["mp3", "flac", "wav", "ogg", "opus", "m4a", "aac"]
archiveExts :: List String
archiveExts = ["zip", "tar", "gz", "xz", "bz2", "7z", "rar", "zst", "tgz"]
docExts :: List String
docExts = ["pdf", "epub", "djvu", "doc", "docx", "odt", "md"]
-- Extensions routed to the syntax highlighter. Whether a given one actually COLORS depends on the
-- highlighter's syntax set (bat's `--list-languages`); unknowns render plain. `nu` is listed so a
-- nushell file reaches bat — add a nushell `.sublime-syntax` to ~/.config/bat/syntaxes + `bat cache
-- --build` to make it color (bat ships no nushell syntax by default).
codeExts :: List String
codeExts = ["c", "h", "cpp", "hpp", "cc", "rs", "py", "js", "ts", "jsx", "tsx", "go", "hs", "sh",
            "bash", "zsh", "fish", "nu", "java", "rb", "lua", "pl", "php", "kt", "swift", "scala",
            "clj", "ex", "exs", "jl", "r", "dart", "zig", "ml", "vim", "el", "sql", "toml", "yaml",
            "yml", "json", "html", "css", "scss", "xml", "tf", "hcl", "ini", "cfg", "conf", "diff",
            "patch", "nix", "axi"]

------------------------------------------------------------------- type / extension icons
-- Nerd-font GLYPH for an entry (a folder on dirs, a photo on images, …), the icon twin of `entryColor`
-- (same inputs: the type char + the extension). Resolution mirrors the colour pipeline: a config
-- override from config.lua's `icons` table — keyed `di`/`ln`/`or`/`ex`, `*.<ext>`, or a category `image/*`
-- — wins over the built-in set (`iconForExt`). `icfg` is the icons-config string (`buildIcons` cache);
-- `rowCell` only calls this when icons are ON (`icfg` non-empty), so — like `entryColor` — there is no
-- emptiness branch here. Each glyph is ONE display column but a multi-byte UTF-8 literal (like the `│`
-- separator); `rowCell` keeps it OUT of the byte-based width math. `dup`/literal keep each lookup borrow-only.
-- Glyphs are Nerd Font codepoints written as explicit UTF-8 BYTE escapes (`\xNN\xNN\xNN`) — robust and
-- self-documenting, no reliance on source-file glyph encoding. Each is 3 bytes / 1 display column (private-
-- use area); `rowCell` reserves exactly 1 column for it, keeping it out of the byte-based width math.
entryIcon :: String -> String -> String -> String
entryIcon icfg ty raw =
  if ty == "d" then dirIcon icfg
  else if ty == "l" then lnIcon icfg
  else if ty == "b" then orIcon icfg
  else if ty == "x" then exIcon icfg
  else fileIcon icfg (extOf raw)
dirIcon :: String -> String                                  -- U+F07B folder
dirIcon icfg = let c = lscVal icfg "di" in if strLen c > 0 then dup c else ""
lnIcon :: String -> String                                   -- U+F0C1 link
lnIcon icfg = let c = lscVal icfg "ln" in if strLen c > 0 then dup c else ""
orIcon :: String -> String                                   -- U+F127 broken chain
orIcon icfg = let c = lscVal icfg "or" in if strLen c > 0 then dup c else ""
exIcon :: String -> String                                   -- U+F489 terminal
exIcon icfg = let c = lscVal icfg "ex" in if strLen c > 0 then dup c else ""
-- Glyph for a plain file by extension, most-specific first (mirrors `fileColor`): exact `*.ext` override
-- → category override `<cat>/*` → the built-in per-bucket glyph.
fileIcon :: String -> String -> String
fileIcon icfg ext =
  let c = lscVal icfg (strAppend "*." ext) in
  if strLen c > 0 then dup c else catOrBuiltinIcon icfg ext
catOrBuiltinIcon :: String -> String -> String
catOrBuiltinIcon icfg ext =
  let cc = lscVal icfg (strAppend (catOf ext) "/*") in
  if strLen cc > 0 then dup cc else iconForExt ext
-- The built-in default glyphs, keyed by the SAME buckets as `colorForExt`/`catOf`. Edit here to change the
-- defaults (or override per-entry in config.lua). Nerd Font codepoints (require a Nerd Font, as yazi does).
iconForExt :: String -> String
iconForExt e =
  if elemBy e imageExts then ""          -- U+F1C5 image
  else if elemBy e videoExts then ""     -- U+F1C8 video
  else if elemBy e audioExts then ""     -- U+F1C7 audio
  else if elemBy e archiveExts then ""   -- U+F1C6 archive
  else if elemBy e docExts then ""       -- U+F0F6 file-text
  else if elemBy e codeExts then ""      -- U+F1C9 file-code
  else ""                                -- U+F15B file

-- The sized cell for a row, with an optional leading file-type ICON. Layout is `[mark][…][name]`: the
-- mark column (`*`/space), then either a space (icons OFF) or `glyph + space` (icons ON) right before the
-- name, so the glyph sits snug against it. Icons OFF (`icfg` empty) → today's exact behavior
-- (`sizedCell (mark " " name) listW`). Icons ON → `mark ++ glyph ++ " " ++ name` with the name sized to
-- `listW - 3` (mark + glyph + space = the 3 reserved columns), so the row is still exactly `listW` VISIBLE
-- columns and the absolutely-positioned `│` separator stays aligned. The glyph (1 display column but a
-- multi-byte literal) NEVER enters `sizedCell`/`clip` (byte-based), so it can't be sliced mid-codepoint.
-- The conditional is in TAIL position (a helper, never a `let x = if… heap`) — the #1 axfm reclamation gotcha.
rowCell :: String -> String -> String -> String -> String -> Int -> Bool -> String
rowCell icfg ty raw mark name listW prev =
  if strLen icfg == 0 then sizedCell (mark ++ " " ++ name) listW prev
  else mark ++ entryIcon icfg ty raw ++ " " ++ sizedCell name (listW - 3) prev

-- A list row is just its colored fixed-width cell + newline. The pane separator is NOT appended per
-- row (that left gaps on rows with no entry) — it is drawn as one continuous line by `drawSep`.
rowFor :: String -> String -> String -> String -> Int -> Int -> String -> String -> Int -> Bool -> String
rowFor lsc icfg raw ty i sel marked cwd listW prev =
  colorCell (rowCell icfg ty raw (markChar marked (cwd </> stripSlash raw)) (dup raw) listW prev)
            i sel (entryColor lsc ty raw)
  ++ "\n"

-- A CONTINUOUS thin gray (SGR 90) vertical divider down column `col`, rows 1..mx — no gaps even where
-- the list has no entry. A separate pass (absolute cursor positioning) so it's independent of the
-- rows; drawn only when a preview pane follows.
drawSep :: Int -> Int -> String
drawSep col mx = sepGo col 1 mx
sepGo :: Int -> Int -> Int -> String
sepGo col r mx =
  if r > mx then ""
  else csi (showInt r ++ ";" ++ showInt col ++ "H") ++ paint "90" "│" ++ sepGo col (r + 1) mx

-- Bottom status line: (pos/total), [n] selected (program), cwd — in reverse video, pinned to row.
posStr :: Int -> Int -> String
posStr sel total = strAppend "(" (strAppend (showInt (sel + 1)) (strAppend "/" (strAppend (showInt total) ")")))
markInfo :: String -> String -> String
markInfo marked prog =
  strAppend " [" (strAppend (showInt (markCount marked)) (strAppend "] (" (strAppend prog ")")))
-- the marked-count segment, or "" — a tail `if` in its own helper (not a consumed inline conditional).
markSeg :: String -> String -> String
markSeg marked prog = if markCount marked > 0 then markInfo marked prog else ""
-- The selected entry's size + mtime, or "" when unknown — a tail `if` in its own helper (mirrors
-- markSeg: no let-bound heap conditionally dropped).
metaSeg :: String -> String
metaSeg info = if strLen (infoSize info) > 0 then metaShow info else ""
metaShow :: String -> String
metaShow info = strAppend "  " (strAppend (infoSize info) (strAppend "  " (infoMtime info)))
-- The selected symlink's "-> target [(broken)]" segment, or "" — shown textually (the status bar is
-- reverse-video, so a nested color would need a reverse-restoring reset; the text is the signal).
linkSeg :: String -> String
linkSeg info = let l = infoLink info in if strLen l == 0 then "" else strAppend "  " l
-- The tab-bar segment, or "" at a single tab — a tail `if` in its own helper (mirrors linkSeg).
tabSeg :: String -> String
tabSeg info = let tb = infoTabs info in if strLen tb == 0 then "" else strAppend "  " tb
statusLine :: String -> Int -> Int -> String -> String -> Int -> String -> String
statusLine cwd total sel marked prog rows info =
  strAppend (csi (strAppend (showInt (rows - 1)) ";1H"))
    (paint "7"
      (strAppend (posStr sel total)
        (strAppend (tabSeg info)
          (strAppend (markSeg marked prog)
            (strAppend (metaSeg info)
              (strAppend (linkSeg info)
                (strAppend " " cwd)))))))

------------------------------------------------------------------- preview pane (pure content)

-- Is a graphics renderer USABLE in this terminal? (Defined below; "" means none → text + hint.)
hasImgTool :: Int -> Bool
hasImgTool d = strLen (pickRenderer 0) > 0

-- The selected entry's PATH derived from an ALREADY-captured `ls` output (pure `lines`, no new fork)
-- — the hot-path twin of selPath, so a frame lists the directory once and reuses it.
selPathOf :: String -> String -> Int -> String
selPathOf cwd raw sel = cwd </> stripSlash (lineAt raw sel)
-- The mime type of a path (trimmed) — one `file` fork; drives the preview branch.
selMimeOf :: String -> String
selMimeOf path =
  trim (runCapture (strAppend "file -bL --mime-type -- "
          (strAppend (shQuote path) " 2>/dev/null")))
selMime :: String -> Int -> Int -> String
selMime cwd hidden sel = selMimeOf (selPath cwd hidden sel)
-- ONE fork per frame for the whole selected-entry probe: mime (drives the preview branch) + human
-- size + mtime, newline-separated. Size/mtime come from a SINGLE `stat` — crucially NOT `du`, which
-- RECURSES a directory's whole tree (seconds on a big dir → laggy previews on every cursor move);
-- `stat -c %s` is the entry's own size, instant. The byte count is humanised with `numfmt` when
-- present (raw bytes otherwise). Folding size/mtime into the mime fork keeps it at one spawn/frame.
selInfo :: String -> String
selInfo path =
  runCapture (strAppend "f=" (strAppend (shQuote path)
    (strAppend "; file -bL --mime-type -- \"$f\" 2>/dev/null; o=$(stat -c '%s|%y' -- \"$f\" 2>/dev/null); s=${o%%|*}; t=${o#*|}; t=${t%%.*}; h=$(printf %s \"$s\" | numfmt --to=iec 2>/dev/null); if [ -L \"$f\" ]; then r=$(readlink \"$f\"); if [ -e \"$f\" ]; then l=\"-> $r\"; else l=\"-> $r (broken)\"; fi; else l=\"\"; fi; printf '%s\\n%s\\n%s\\n' \"${h:-$s}\" \"$t\" \"$l\"; " tabBarCmd)))
-- The tab-bar line appended to selInfo's fork (so it costs no extra per-frame subprocess): " 1:foo
-- [2:bar] 3:baz" with the active tab bracketed, or "" at a single tab (then the status bar is clean).
tabBarCmd :: String
tabBarCmd =
  "tb=''; tf=" ++ shQuote (tabsFile 0) ++ "; ti=" ++ shQuote (tabiFile 0)
  ++ "; if [ -s \"$tf\" ]; then n=$(grep -c '' \"$tf\"); if [ \"$n\" -gt 1 ]; then ai=0; [ -r \"$ti\" ] && read ai < \"$ti\"; [ -z \"$ai\" ] && ai=0; k=0; "
  ++ "while IFS= read -r d; do b=${d##*/}; [ -z \"$b\" ] && b=/; if [ \"$k\" = \"$ai\" ]; then tb=\"$tb [$((k+1)):$b]\"; else tb=\"$tb $((k+1)):$b\"; fi; k=$((k+1)); done < \"$tf\"; fi; fi; printf '%s\\n' \"$tb\""
-- The tab-bar segment of the status line, or "" (single tab / absent). pick 4 = selInfo's 5th line.
infoTabs :: String -> String
infoTabs info = trim (pick 4 (lines info))
infoMime :: String -> String
infoMime info = trim (pick 0 (lines info))
infoSize :: String -> String
infoSize info = trim (pick 1 (lines info))
infoMtime :: String -> String
infoMtime info = trim (pick 2 (lines info))
-- The selected entry's symlink target as "-> target" (or "-> target (broken)"), "" if not a symlink.
infoLink :: String -> String
infoLink info = trim (pick 3 (lines info))

-- Image/video pane text: NOTHING when a graphics tool will paint pixels over it (the header would
-- just peek around the image) — only a `<label> name  mime` header + install hint when pixels can't
-- be drawn, so the pane isn't blank. A tail `if` in its own helper (not a consumed heap/"" branch).
pixHeader :: String -> String -> String -> Int -> Int -> Int -> String
pixHeader label path mime px pw ph =
  if hasImgTool 0 then ""
  else drawLines (Cons (strAppend label (strAppend (baseName path) (strAppend "  " (dup mime))))
                   (Cons "(install kitty or img2sixel for a pixel preview)" Nil)) 1 px pw ph

-- Position each line at (r, px) and clip it to pw cells, up to row maxRow; rows beyond it are
-- consumed but not drawn (so the whole list is reclaimed — cf. drawRows' skip branch).
drawLines :: List String -> Int -> Int -> Int -> Int -> String
drawLines xs r px pw maxRow = case xs of
  Nil -> ""
  Cons y ys ->
    if r > maxRow then drawLines ys (r + 1) px pw maxRow
    else strAppend
           (strAppend (csi (strAppend (showInt r) (strAppend ";" (strAppend (showInt px) "H")))) (clip y pw))
           (drawLines ys (r + 1) px pw maxRow)
-- Like drawLines but ANSI-aware (clipAnsi) + a trailing reset per line so a cut highlighted line
-- can't bleed color into the separator / list. For the syntax-highlighted code preview only.
drawLinesAnsi :: List String -> Int -> Int -> Int -> Int -> String
drawLinesAnsi xs r px pw maxRow = case xs of
  Nil -> ""
  Cons y ys ->
    if r > maxRow then drawLinesAnsi ys (r + 1) px pw maxRow
    else strAppend
           (strAppend (csi (strAppend (showInt r) (strAppend ";" (strAppend (showInt px) "H"))))
             (strAppend (clipAnsi y pw) (csi "0m")))
           (drawLinesAnsi ys (r + 1) px pw maxRow)

-- Does the mime name an archive libarchive/tar/unzip can list? (substring match — "zip" also
-- catches gzip/bzip2, all of which the listing command handles.)
isArchiveMime :: String -> Bool
isArchiveMime m =
  hasInfix "zip" m || hasInfix "tar" m || hasInfix "x-7z" m || hasInfix "rar" m
    || hasInfix "gzip" m || hasInfix "bzip" m || hasInfix "xz" m || hasInfix "compress" m
-- List an archive's members (bsdtar/libarchive handles every format; tar / unzip -l are fallbacks).
-- Emits the FULL listing; drawPreview appends the scroll window (scrollPipe).
archiveList :: String -> String
archiveList path =
  strAppend "{ bsdtar -tf " (strAppend (shQuote path)
   (strAppend " || tar -tf " (strAppend (shQuote path)
   (strAppend " || unzip -l " (strAppend (shQuote path)
   "; } 2>/dev/null")))))
-- The scroll window as a shell pipe: skip the first `poff` lines, then take `ph` — appended to a
-- preview generator's output so J/K page through dir/archive/file-desc listings. At poff 0 it's just
-- `| tail -n +1 | head -n ph` (= head -n ph), so scrolling adds NO cost until you actually scroll.
scrollPipe :: Int -> Int -> String
scrollPipe poff ph =
  strAppend " | tail -n +" (strAppend (showInt (poff + 1)) (strAppend " | head -n " (showInt ph)))
-- Draw the preview for `path` into columns [px..], rows [1..ph]: directory → ls, text → head,
-- image/video/pdf → a header (pixels are an IO overlay in previewImage/previewPix), archive →
-- member listing, else a `file` description. `poff` scrolls the TEXTUAL previews (J/K): text reads
-- from line poff+1 via `tail`, the others append scrollPipe. Image/video/pdf headers ignore poff.
drawPreview :: String -> Int -> Int -> Int -> String -> Int -> String
drawPreview path px pw ph mime poff =
  if hasPrefix "inode/directory" mime
  then drawLines (lines (runCapture (strAppend "ls -Up -- "
         (strAppend (shQuote path) (strAppend " 2>/dev/null" (scrollPipe poff ph)))))) 1 px pw ph
  else if hasPrefix "image/" mime
  then pixHeader "[image] " path mime px pw ph
  else if hasPrefix "video/" mime
  then pixHeader "[video] " path mime px pw ph
  else if hasPrefix "application/pdf" mime
  then pixHeader "[pdf] " path mime px pw ph
  else if isArchiveMime mime
  then drawLines (lines (runCapture (strAppend (archiveList path) (scrollPipe poff ph)))) 1 px pw ph
  else if (hasPrefix "text/" mime) || (hasPrefix "inode/x-empty" mime)
  then textPreview path px pw ph poff
  else drawLines (lines (runCapture (strAppend "file -bL -- "
         (strAppend (shQuote path) (strAppend " 2>/dev/null" (scrollPipe poff ph)))))) 1 px pw ph

-- A code extension OR NO extension → syntax-highlighted window via bat (drawn ANSI-aware); other
-- text (named .txt/.log/.md/… — an extension not in codeExts) → plain `tail | head`. Extensionless
-- files (a shell script named `build`, `Makefile`, `Dockerfile`, a dotfile's config) are routed to
-- bat too, which detects the language from the shebang / filename / content — the common case the
-- extension gate alone missed. `extOf (baseName …)` so a dot in a PARENT dir can't fake an extension.
-- A tail `if` whose branches are both drawLines* applications (no consumed heap conditional).
textPreview :: String -> Int -> Int -> Int -> Int -> String
textPreview path px pw ph poff =
  let e = extOf (baseName path) in
  if (strLen e == 0) || elemBy e codeExts
  then drawLinesAnsi (lines (runCapture (codePreviewCmd path poff ph))) 1 px pw ph
  else drawLines (lines (runCapture (strAppend "tail -n +" (strAppend (showInt (poff + 1))
         (strAppend " -- " (strAppend (shQuote path) (strAppend " 2>/dev/null | head -n " (showInt ph)))))))) 1 px pw ph
-- Syntax-highlighted window [poff+1 .. poff+ph] via `bat` (ANSI), falling back to a plain `sed`
-- range when bat is absent/fails — ALL in ONE shell (the `||` runs inside the single runCapture, so
-- no extra fork vs plain text). bat gets the real filename for language detection; --style=plain and
-- --paging=never strip its chrome and `--line-range` bounds how much it reads.
codePreviewCmd :: String -> Int -> Int -> String
codePreviewCmd path poff ph =
  let rng = strAppend (showInt (poff + 1)) (strAppend ":" (showInt (poff + ph))) in
  let sed = strAppend (showInt (poff + 1)) (strAppend "," (strAppend (showInt (poff + ph)) "p")) in
  strAppend "bat --color=always --style=plain --paging=never --line-range " (strAppend rng
    (strAppend " -- " (strAppend (shQuote path)
      (strAppend " 2>/dev/null || sed -n " (strAppend (shQuote sed)
        (strAppend " -- " (strAppend (shQuote path) " 2>/dev/null")))))))

-- The preview segment, or "" when the pane is off — a tail `if` in its own helper (not a consumed
-- inline heap/"" conditional).
previewSeg :: String -> Int -> String -> Int -> Int -> Bool -> String -> Int -> String
previewSeg cwd sel raw cols mx prev mime poff =
  if prev
  then drawPreview (selPathOf cwd raw sel) (paneX cols) (paneW cols) mx mime poff
  else ""

------------------------------------------------------------------- image overlay (terminal graphics)

-- Session CAPABILITIES — stdout-is-a-tty + the pixel renderer — are CONSTANT for a run, but each probe
-- (`test -t 1`, `command -v …`) forks. `writeCaps` computes them ONCE at startup into ~/.cache/axfm/caps
-- (line 1 = onTty 0/1, line 2 = renderer: kitten inside kitty, else img2sixel, else ""); `onTty` and
-- `pickRenderer` then just READ that file (a builtin — no fork). Crucial: `onTty` is consulted on EVERY
-- keystroke (the frame-path decision), so this removes a per-keystroke fork.
capsFile :: Int -> String
capsFile d = strAppend (envOr "HOME" ".") "/.cache/axfm/caps"
writeCapsCmd :: String
writeCapsCmd =
  "t=0; test -t 1 && t=1; r=''; k=0; case \"$TERM\" in *kitty*) k=1 ;; esac; [ -n \"$KITTY_WINDOW_ID\" ] && k=1; "
  ++ "if [ \"$k\" = 1 ] && command -v kitten >/dev/null 2>&1; then r=kitten; elif command -v img2sixel >/dev/null 2>&1; then r=img2sixel; fi; "
  ++ "printf '%s\\n%s\\n' \"$t\" \"$r\" > " ++ shQuote (capsFile 0)
writeCaps :: Int -> Int
writeCaps d = runStatus writeCapsCmd
capLine :: Int -> String
capLine n = trim (pick n (lines (readFile (capsFile 0))))
-- Is our stdout a real terminal? (Cached; images/the poll are skipped on a pipe — e.g. the test harness.)
onTty :: Int -> Bool
onTty d = capLine 0 == "1"
-- The pixel renderer chosen at startup ("kitten"/"img2sixel"/""), read fork-free from the caps file.
pickRenderer :: Int -> String
pickRenderer d = capLine 1

-- The renderers operate on a shell var $src (already set to the file to display), so IMAGE and VIDEO
-- (whose $src is an extracted thumbnail) share one render path. `kitten icat --place` keeps kitty from
-- scrolling / moving the cursor (pw x ph cells at 0-based @col x row), then re-hide the cursor.
kittenRenderSrc :: Int -> Int -> Int -> Int -> String
kittenRenderSrc pw ph px py =
  strAppend "kitten icat --clear --stdin=no --scale-up --place="
    (strAppend (showInt pw) (strAppend "x" (strAppend (showInt ph)
      (strAppend "@" (strAppend (showInt px) (strAppend "x" (strAppend (showInt py)
        " -- \"$src\"; printf '\\033[?25l'")))))))
-- libsixel: home to the pane origin, then emit sixels for $src FIT to the pane box in REAL pixels —
-- pwc x phc CELLS times the terminal's actual cell size read from ~/.cache/axfm/cell (written once at
-- startup by `\e[14t`; falls back to 7x14 if absent). img2sixel preserves aspect from a SINGLE
-- dimension, so we pick the BINDING one from the image's own WxH (via `identify`, else `file`'s
-- LARGEST NxN — real JPEGs print a bogus `density 1x1` before the true size, so take max-width not
-- first): a portrait photo binds on HEIGHT so it can't overflow downward and scroll the list (the
-- bug), a wide one binds on width. CACHED under ~/.cache/axfm/sixel by (src md5, box px) + mtime, so
-- decoding happens once (~200ms) and every revisit `cat`s the ~60K (~3ms); dim/cell probes run only
-- on a cache miss. Box in real px = exact pane rows, so height never exceeds the pane → no scroll.
-- The cache-key + miss-decode core, assuming $src is already set. Emits the cell-size read, the
-- W/H box-px math, k=~/.cache/axfm/sixel/<md5(src)>_${W}x${H}.six, and (only on a miss / stale
-- mtime) the img2sixel decode into a PID-unique temp then an atomic `mv`. No `cat`, no cursor
-- move — shared VERBATIM by the foreground sixelRenderSrc and the background prefetch so the key
-- / box px / mtime logic can never drift between warming a neighbour and later reading it.
-- `-S`/--static renders an animated GIF as a SINGLE frame: without it img2sixel decodes EVERY frame
-- (a 60-frame GIF pinned the CPU and froze the preview — and the background prefetch would too).
-- `-d none` disables dithering (like yazi): fewer colour transitions → longer RLE runs → a SMALLER
-- `.six` blob, so foot re-parses less on every emit (quality stays fine at 256 colours).
sixelDecode :: Int -> Int -> String
sixelDecode pwc phc =
  strAppend "cw=7; ch=14; [ -r \"$HOME/.cache/axfm/cell\" ] && read cw ch < \"$HOME/.cache/axfm/cell\"; W=$(( " (strAppend (showInt pwc)
   (strAppend " * ${cw:-7} )); H=$(( " (strAppend (showInt phc)
   " * ${ch:-14} )); k=\"$HOME/.cache/axfm/sixel/$(printf %s \"$src\"|md5sum|cut -c1-32)_${W}x${H}.six\"; mkdir -p \"${k%/*}\"; if [ ! -f \"$k\" ] || [ \"$src\" -nt \"$k\" ]; then dim=$(identify -format '%wx%h' \"$src\"[0] 2>/dev/null); [ -n \"$dim\" ] || dim=$(file -bL -- \"$src\" 2>/dev/null|grep -oE '[0-9]+ ?x ?[0-9]+'|tr -d ' '|sort -t x -k1,1n|tail -1); iw=${dim%x*}; ih=${dim#*x}; if [ -n \"$dim\" ] && [ \"$((iw*H))\" -ge \"$((ih*W))\" ]; then f=\"-w $W\"; else f=\"-h $H\"; fi; [ -n \"$dim\" ] || f=\"-w $W\"; img2sixel -S -d none $f -- \"$src\" >\"$k.$$.t\" 2>/dev/null && mv \"$k.$$.t\" \"$k\"; fi"
     )))
sixelRenderSrc :: Int -> Int -> Int -> String
sixelRenderSrc px pwc phc =
  strAppend "printf '\\033[1;" (strAppend (showInt px)
   (strAppend "H'; " (strAppend (sixelDecode pwc phc)
   "; cat \"$k\" 2>/dev/null; printf '\\033[?25l'")))
-- Render whatever $src points at via the renderer pickRenderer chose (guarded by hasImgTool).
renderSrc :: Int -> Int -> String
renderSrc cols rows =
  if pickRenderer 0 == "kitten"
  then kittenRenderSrc (paneW cols) (maxItems rows) (paneX cols - 1) 0
  else sixelRenderSrc (paneX cols) (paneW cols) (maxItems rows)

-- IMAGE: $src is the file itself.
icatCmd :: String -> Int -> Int -> String
icatCmd path cols rows =
  strAppend "src=" (strAppend (shQuote path) (strAppend "; " (renderSrc cols rows)))
-- Extract a VIDEO frame (seek 1s) for the file in $src into a cached thumbnail PNG — ffmpegthumbnailer,
-- else ffmpeg — keyed by md5($src) + mtime-invalidated, leaving the thumb path in $th. Operates on the
-- shell var $src (NOT a baked path) so it is shared VERBATIM by the foreground render AND the background
-- prefetch — identical md5($src) key, so a prewarmed thumb is a true foreground cache hit. The extract
-- writes a PID-unique temp then an ATOMIC `mv`, so a concurrent foreground+prefetch extract of the same
-- video can't corrupt the PNG. No extractor → $th stays missing and the overlay silently draws nothing.
videoThumbVar :: String
videoThumbVar =
  "th=\"$HOME/.cache/axfm/thumb/$(printf %s \"$src\"|md5sum|cut -c1-32).png\"; mkdir -p \"${th%/*}\"; { [ -f \"$th\" ] && [ \"$th\" -nt \"$src\" ]; } || { ffmpegthumbnailer -i \"$src\" -o \"$th.$$.png\" -s 512 2>/dev/null || ffmpeg -y -ss 1 -i \"$src\" -frames:v 1 -vf scale=512:-1 \"$th.$$.png\" 2>/dev/null; mv \"$th.$$.png\" \"$th\" 2>/dev/null; }; "
-- Like videoThumbVar but renders PDF page 1 via pdftoppm (`-singlefile BASE` → BASE.png), same $src /
-- $th / atomic-mv contract.
pdfThumbVar :: String
pdfThumbVar =
  "th=\"$HOME/.cache/axfm/thumb/$(printf %s \"$src\"|md5sum|cut -c1-32).png\"; mkdir -p \"${th%/*}\"; { [ -f \"$th\" ] && [ \"$th\" -nt \"$src\" ]; } || { pdftoppm -png -f 1 -l 1 -r 96 -singlefile \"$src\" \"${th%.png}.$$\" 2>/dev/null; mv \"${th%.png}.$$.png\" \"$th\" 2>/dev/null; }; "
-- VIDEO / PDF foreground: set $src to the file, extract its thumbnail (prewarmed by the prefetch in the
-- common case → a `[ -f $th ]` skip), repoint $src at the thumb, render like an image.
videoCmd :: String -> Int -> Int -> String
videoCmd path cols rows =
  strAppend "src=" (strAppend (shQuote path) (strAppend "; " (strAppend videoThumbVar
    (strAppend "src=\"$th\"; " (renderSrc cols rows)))))
pdfCmd :: String -> Int -> Int -> String
pdfCmd path cols rows =
  strAppend "src=" (strAppend (shQuote path) (strAppend "; " (strAppend pdfThumbVar
    (strAppend "src=\"$th\"; " (renderSrc cols rows)))))

-- Render the selected IMAGE as pixels into the pane — the only IO the preview adds (pixels can't be
-- part of the pure `render` string). A noop on a pipe, with the pane off, no selection, a non-image
-- selection, or no graphics tool. Spawns once per frame, like the per-frame `ls` (minor flicker).
previewImage :: String -> Int -> Int -> String -> Int -> String -> Int
previewImage cwd sel rows raw cols mime =
  if (onTty 0) && (previewOn cols) && (countLines raw > 0) && (hasImgTool 0)
  then previewPix (selPathOf cwd raw sel) cols rows mime
  else 0
-- Dispatch on mime: images render directly, videos via an extracted frame; anything else is a noop
-- (the pane keeps its textual preview). A tail `if` per branch (no consumed heap conditional).
previewPix :: String -> Int -> Int -> String -> Int
previewPix path cols rows mime =
  if hasPrefix "image/" mime then runStatus (icatCmd path cols rows)
  else if hasPrefix "video/" mime then runStatus (videoCmd path cols rows)
  else if hasPrefix "application/pdf" mime then runStatus (pdfCmd path cols rows)
  else 0

------------------------------------------------------------------- preview prefetch (Yazi-like)

-- Space-separated, shell-quoted paths of the entries [lo..hi] (inclusive), for the background
-- prefetch's `for src in …`. Tail-recurses with an accumulator and reuses selPathOf, so a warmed
-- md5(src) is byte-identical to what the foreground render later reads (→ cache hit, not a decode).
windowPaths :: String -> String -> Int -> Int -> String
windowPaths cwd raw lo hi = windowGo cwd raw lo hi ""
windowGo :: String -> String -> Int -> Int -> String -> String
windowGo cwd raw i hi acc =
  if i > hi then acc
  else windowGo cwd raw (i + 1) hi (strAppend acc (strAppend (shQuote (selPathOf cwd raw i)) " "))
-- The window [sel-2 .. sel+4] clamped to the listing (always includes sel, so the list is never
-- empty; the already-cached sel is a free `[ -f "$k" ]` skip).
winPaths :: String -> Int -> String -> String
winPaths cwd sel raw =
  let n = countLines raw in
  windowPaths cwd raw (clampSel (sel - 2) n) (clampSel (sel + 4) n)

-- ONE detached background job for the whole window: a trailing `&` so runStatus returns at once
-- and the loop never blocks. A non-interactive shell does not SIGHUP its background jobs, so it
-- outlives the frame that spawned it.
warmLoop :: String -> String -> String
warmLoop paths body =
  strAppend "for src in " (strAppend paths (strAppend "; do " (strAppend body "; done >/dev/null 2>&1 &")))
-- Renderer-aware prefetch body, now TYPE-AWARE (mirrors previewPix in the background): per window
-- entry it `file`-probes the mime and, for a video/pdf, extracts the thumbnail FIRST (videoThumbVar/
-- pdfThumbVar — same $th key the foreground reads) before warming — so landing on a video is a hit,
-- not a synchronous ffmpeg extract. Images skip straight to the warm as before. kitty warms the OS
-- page cache of whatever $src ends up pointing at (the thumb for video/pdf); sixel does the full
-- decode-to-cache. The per-entry `file` fork is in the detached background job, off the hot path.
prefetchBodySixel :: Int -> Int -> String
prefetchBodySixel pwc phc =
  "m=$(file -bL --mime-type \"$src\" 2>/dev/null); case \"$m\" in video/*) "
  ++ videoThumbVar ++ "src=\"$th\"; " ++ sixelDecode pwc phc
  ++ " ;; application/pdf) " ++ pdfThumbVar ++ "src=\"$th\"; " ++ sixelDecode pwc phc
  ++ " ;; *) " ++ sixelDecode pwc phc ++ " ;; esac"
prefetchBodyKitten :: String
prefetchBodyKitten =
  "m=$(file -bL --mime-type \"$src\" 2>/dev/null); case \"$m\" in video/*) "
  ++ videoThumbVar ++ "cat \"$th\" >/dev/null 2>&1 ;; application/pdf) " ++ pdfThumbVar
  ++ "cat \"$th\" >/dev/null 2>&1 ;; *) cat \"$src\" >/dev/null 2>&1 ;; esac"
prefetchCmd :: String -> Int -> Int -> String -> Int -> String
prefetchCmd cwd sel rows raw cols =
  if pickRenderer 0 == "kitten"
  then warmLoop (winPaths cwd sel raw) prefetchBodyKitten
  else warmLoop (winPaths cwd sel raw) (prefetchBodySixel (paneW cols) (maxItems rows))
-- Warm the preview cache for a window around the cursor in a detached job so the NEXT j/k is a
-- hit, not a ~200ms decode. Gated CHARACTER-FOR-CHARACTER like previewImage — a strict no-op off
-- a tty (the headless test harness), with the pane off, an empty listing, or no graphics tool.
prefetch :: String -> Int -> Int -> String -> Int -> Int
prefetch cwd sel rows raw cols =
  if (onTty 0) && (previewOn cols) && (countLines raw > 0) && (hasImgTool 0)
  then runStatus (prefetchCmd cwd sel rows raw cols)
  else 0

------------------------------------------------------------------- full-frame render

-- Kitty graphics delete-all (ESC _ G a=d,d=A ESC \): wipes any prior image so moving off one clears
-- it. Other terminals ignore the APC sequence. Emitted at the top of every frame.
imgClearSeq :: String
imgClearSeq = strAppend esc (strAppend "_Ga=d,d=A" (strAppend esc "\\"))

-- `raw` = the frame's ONE captured `ls` output, `cols` = the frame's ONE `stty` width. Everything
-- derives from them with pure `lines`/parsing — no per-helper subprocess re-spawn (the old hot path
-- re-ran `ls` ~70× and `stty` ~36× per frame; cf. the per-frame dedup in `loop`).
render :: String -> Int -> String -> String -> Int -> String -> Int -> String -> Int -> String
render cwd sel marked prog rows raw cols info poff =
  let total = countLines raw in
  let mx = maxItems rows in
  let start = viewStart sel total mx in
  let tys = frameTys cwd start mx in
  let lw = listWidth cols in
  let prev = previewOn cols && total > 0 in
  imgClearSeq ++ homeClear
    ++ drawRows (lsColors 0) (iconsOf 0) (windowLines raw start mx) tys start sel marked cwd lw prev
    ++ sepSeg lw mx prev
    ++ previewSeg cwd sel raw cols mx prev (infoMime info) poff
    ++ statusLine cwd total sel marked prog rows info

-- The FORK-FREE fast frame for cursor movement: list + cursor + separator + a MINIMAL status line
-- (position, marks, cwd), all from the cached `raw` with no subprocess. Per-entry colours (incl.
-- executables, symlinks) come from the cached `frameTys` — SAME types the settled render uses, so the
-- colour never flips while scrolling. The preview pane is blank and the size/mtime/link status + the
-- pixel image fill in on the settled full render. `homeClear` wipes any prior sixel image.
listFrame :: String -> Int -> String -> String -> Int -> String -> Int -> Int -> String
listFrame cwd sel marked prog rows raw cols poff =
  let total = countLines raw in
  let mx = maxItems rows in
  let start = viewStart sel total mx in
  let tys = frameTys cwd start mx in
  let lw = listWidth cols in
  let prev = previewOn cols && total > 0 in
  imgClearSeq ++ homeClear
    ++ drawRows (lsColors 0) (iconsOf 0) (windowLines raw start mx) tys start sel marked cwd lw prev
    ++ sepSeg lw mx prev
    ++ listStatus cwd total sel marked prog rows
-- Minimal status: (pos/total) [marks] cwd — the segments that need no `selInfo` fork.
listStatus :: String -> Int -> Int -> String -> String -> Int -> String
listStatus cwd total sel marked prog rows =
  strAppend (csi (strAppend (showInt (rows - 1)) ";1H"))
    (paint "7" (strAppend (posStr sel total) (strAppend (markSeg marked prog) (strAppend " " cwd))))

-- Type chars (d/l/b/x/f) for JUST the VISIBLE window [start, start+mx), classified in ONE shell
-- Per-entry type chars (d/l/b/x/f) for the WHOLE directory, computed ONCE per directory change (in
-- `reloop`) into ~/.cache/axfm/types, aligned line-for-line with the `ls` listing. Classification is a
-- single shell loop of `[` BUILTINS (no per-entry fork), atomic temp→mv so a frame never reads a torn
-- file. Both the fast list frame and the full render then read these fork-free (`frameTys`), so an
-- executable is green whether the cursor is moving or settled — no more colour flip, and no per-frame
-- classification fork at all (the old per-frame `visTypes` is gone).
typesFile :: Int -> String
typesFile d = strAppend (envOr "HOME" ".") "/.cache/axfm/types"
-- Per-entry type classification (d/l/b/x/f), run in a DETACHED BACKGROUND job (trailing `&`) so entering
-- a big directory does NOT block: the names listing (`raw`) is captured instantly, drawn with dir/file
-- colours derived for free from the `ls -p` trailing `/`, and the richer exec/symlink/broken colours
-- fill in a moment later when this job finishes (yazi-style). It classifies the SAME `lsCmd` listing
-- (same dirs-first + sort + filter order → aligned with `raw`) with a `[`-builtin loop (the `[ -L ] && [
-- -e ]` split is what tells a LIVE symlink `l` from a BROKEN one `b`/`or` — a batched `stat` can't), and
-- writes the types to an atomic temp → `mv`. LINE 1 is a STAMP = the directory this file describes; a
-- frame uses the cached types only when the stamp matches the current `cwd` (`frameTys`), so a stale
-- file from the previous directory never mis-colours — it just falls back to dir/file until this lands.
classifyBody :: String -> Int -> String
classifyBody cwd hidden =
  "d=" ++ shQuote cwd ++ "; t=" ++ shQuote (typesFile 0) ++ "; tmp=\"$t.$$\"; { printf '%s\\n' "
  ++ shQuote cwd ++ "; ("
  ++ lsCmd cwd hidden
  ++ ") | while IFS= read -r n; do p=\"$d/${n%/}\"; if [ -L \"$p\" ]; then { [ -e \"$p\" ] && printf 'l\\n' || printf 'b\\n'; }; elif [ -d \"$p\" ]; then printf 'd\\n'; elif [ -x \"$p\" ]; then printf 'x\\n'; else printf 'f\\n'; fi; done; } > \"$tmp\" 2>/dev/null; mv \"$tmp\" \"$t\""
-- Run the type classifier: DETACHED (`&`) on a real terminal, so entering a big directory never blocks
-- (colours fill in a beat later); SYNCHRONOUS off a tty (the headless gates — no interactivity to block,
-- and a deterministic types file the colour assertions can read on the first frame). Int (a do-stmt).
classifyNow :: String -> Int -> Int
classifyNow cwd hidden =
  if onTty 0
  then runStatus (strAppend "( " (strAppend (classifyBody cwd hidden) " ) &"))
  else runStatus (classifyBody cwd hidden)
-- The window slice [start, start+mx) of the cached per-entry types — fork-free, aligned so its head is
-- the type of the entry at `start` (what drawRows consumes).
-- The window slice of the cached types — but ONLY if the file's line-1 stamp matches `cwd` (i.e. the
-- background classifier for THIS directory has landed); otherwise Nil, and `drawRows` falls back to
-- dir/file colours derived from each name's trailing `/`.
frameTys :: String -> Int -> Int -> List String
frameTys cwd start mx =
  let c = readFile (typesFile 0) in
  if strCmp (firstLine c) cwd == 0 then windowLines (dropFirstLine c) start mx else Nil

-- ─── native directory listing (readDirTyped, no `ls`/`stat` fork) ────────────────────────────────
-- Used for the DEFAULT name sort. `readDirTyped` returns name-sorted `<code><name>` lines; we filter
-- (hidden + the active substring filter), partition dirs-first, and build BOTH `raw` (names, dirs with
-- a trailing `/` — the `ls -p` format every consumer expects) AND the stamped `types` from the SAME
-- entries, re-derived per pass so their order can never diverge. Size/mtime sort keeps the shell path.
rdtIsDir :: String -> Bool
rdtIsDir ln = charAt 0 ln == 100                              -- 'd'
rdtName :: String -> String
rdtName ln = substr 1 (strLen ln - 1) ln                     -- strip the leading type code
-- keep an entry? hidden shows dotfiles; a non-empty filter keeps names containing it (case-insensitive)
rdtVisible :: Int -> String -> String -> Bool
rdtVisible hidden fq ln =
  let nm = rdtName ln in
  (if hidden == 1 then True else (if hasPrefix "." nm then False else True))
    && (if strLen fq == 0 then True else hasInfix (toLower fq) (toLower nm))
-- explicit recursive filter (no closure capture of the owned `fq` String — safer than `filter (f fq)`)
rdtKeep :: Int -> String -> List String -> List String
rdtKeep hidden fq xs = case xs of
  Nil -> Nil
  Cons y ys -> if rdtVisible hidden fq y
               then Cons y (rdtKeep hidden fq ys)
               else rdtKeep hidden fq ys
rdtApp :: List String -> List String -> List String
rdtApp xs ys = case xs of
  Nil -> ys
  Cons z zs -> Cons z (rdtApp zs ys)
rdtRev :: List String -> List String -> List String
rdtRev xs acc = case xs of
  Nil -> acc
  Cons z zs -> rdtRev zs (Cons z acc)
-- single pass → dirs (in name order) ++ non-dirs (in name order); avoids consuming the list twice
rdtPartGo :: List String -> List String -> List String -> List String
rdtPartGo xs ds fs = case xs of
  Nil -> rdtApp (rdtRev ds Nil) (rdtRev fs Nil)
  Cons y ys -> if rdtIsDir y then rdtPartGo ys (Cons y ds) fs else rdtPartGo ys ds (Cons y fs)
-- the ordered (filtered + dirs-first) `<code><name>` lines of `cwd`
rdtEntries :: String -> Int -> String -> List String
rdtEntries rdt hidden fq = rdtPartGo (rdtKeep hidden fq (lines rdt)) Nil Nil
rdtRawName :: String -> String
rdtRawName ln = if rdtIsDir ln then strAppend (rdtName ln) "/" else rdtName ln
rdtCode :: String -> String
rdtCode ln = substr 0 1 ln
-- `raw` (names, dirs with trailing `/`) and the cwd-stamped `types`, from the SAME re-derived entries.
rdtRaw :: String -> Int -> String -> String
rdtRaw rdt hidden fq = unlines (map rdtRawName (rdtEntries rdt hidden fq))
rdtTypes :: String -> String -> Int -> String -> String
rdtTypes cwd rdt hidden fq = strAppend cwd (strAppend "\n" (unlines (map rdtCode (rdtEntries rdt hidden fq))))

-- The divider, or "" when the pane is off — a tail `if` in its own helper (not a consumed heap/"").
sepSeg :: Int -> Int -> Bool -> String
sepSeg lw mx prev = if prev then drawSep (lw + 1) mx else ""

------------------------------------------------------------------- command line (readKey accumulator)

dropLast :: String -> String
dropLast s = if strLen s > 0 then substr 0 (strLen s - 1) s else ""

-- The first entry of `cwd` having `q` as a prefix (for Tab-completion); "" if none.
firstPrefix :: List String -> String -> String
firstPrefix xs q = case xs of
  Nil -> ""
  Cons y ys -> if hasPrefix q (stripSlash y) then stripSlash y else firstPrefix ys q

-- Read a command-line entry: draw "prompt<acc>" at the bottom row, read keys until Enter (→acc),
-- Esc (→""), handling Backspace and Tab (prefix-complete against cwd). Returns the typed String.
cmdLine :: String -> Int -> String -> String
cmdLine prompt rows cwd = cmdGo prompt rows cwd ""
cmdGo :: String -> Int -> String -> String -> String
cmdGo prompt rows cwd acc = do
  putStr (strAppend (csi (strAppend (showInt rows) ";1H"))
            (strAppend (csi "?25h") (strAppend (csi "K") (strAppend prompt acc))))
  cmdKey prompt rows cwd acc (readKey 0)
cmdKey :: String -> Int -> String -> String -> String -> String
cmdKey prompt rows cwd acc k =
  if k == "" then acc
  else if (charAt 0 k == '\r') || (charAt 0 k == '\n') then acc
  else if charAt 0 k == 27 then ""
  else if (charAt 0 k == 127) || (charAt 0 k == 8) then cmdGo prompt rows cwd (dropLast acc)  -- DEL / BS
  else if charAt 0 k == '\t' then cmdGo prompt rows cwd (dupOrAcc (firstPrefix (entriesRaw cwd 1) acc) acc)
  else cmdGo prompt rows cwd (strAppend acc k)

-- Tab result: use the completion if non-empty, else keep what was typed.
dupOrAcc :: String -> String -> String
dupOrAcc comp acc = if strLen comp > 0 then comp else dup acc

-- A y/N confirmation at the bottom row (same draw path as cmdLine): show `prompt`, read ONE key,
-- True iff it's y/Y. Any other key — including Enter and Esc — is a safe No (default-deny). A
-- pure-typed effect (reads a key, returns Bool), so it binds directly in a do-block or as an arg.
confirm :: String -> Int -> Bool
confirm prompt rows = confirmYes (confirmKey prompt rows)
confirmYes :: String -> Bool
confirmYes k = (k == "y") || (k == "Y")
confirmKey :: String -> Int -> String
confirmKey prompt rows = do
  putStr (strAppend (csi (strAppend (showInt rows) ";1H"))
            (strAppend (csi "?25h") (strAppend (csi "K") prompt)))
  readKey 0

------------------------------------------------------------------- operation feedback (failures)

-- A mutating op that SILENTLY failed is a trust problem. On a non-zero exit we flash a red message on
-- the bottom row and wait for a key (the same modal pattern `x`/attributes uses), so a failed
-- copy/move/trash/mkdir is impossible to miss; a clean op stays silent. `okOr` is for builtins that
-- expose only an exit code; `okOrErr` also shows the first stderr line captured via `errRedir`.
errFile :: Int -> String
errFile d = strAppend (envOr "HOME" ".") "/.cache/axfm/err"
-- Shell redirect appended to a command so its stderr lands in errFile (for okOrErr to surface).
errRedir :: String
errRedir = " 2>\"$HOME/.cache/axfm/err\""
-- First line of the last captured stderr (trimmed), or "".
errDetail :: Int -> String
errDetail d = trim (pick 0 (lines (readFileTrim (errFile 0))))
-- Draw `msg` in red on the bottom row, wait for any key, return 0 (chains as a bare do-statement).
flashFail :: String -> Int -> Int
flashFail msg rows = do
  putStr (strAppend (csi (strAppend (showInt rows) ";1H"))
            (strAppend (csi "?25h") (strAppend (csi "K") (strAppend (paint "1;31" msg) "  —  any key"))))
  readKey 0
  0
okOr :: Int -> String -> Int -> Int
okOr code label rows = if code == 0 then 0 else flashFail label rows
okOrErr :: Int -> String -> Int -> Int
okOrErr code label rows =
  if code == 0 then 0 else flashFail (strAppend label (strAppend ": " (errDetail 0))) rows

-- A NEUTRAL (non-error) flash on the bottom row — same modal pattern as flashFail, cyan not red —
-- for on-demand info (the `i` disk-usage readout). Waits for a key, returns 0 (chains as a stmt).
flashInfo :: String -> Int -> Int
flashInfo msg rows = do
  putStr (strAppend (csi (strAppend (showInt rows) ";1H"))
            (strAppend (csi "?25h") (strAppend (csi "K") (strAppend (paint "1;36" msg) "  —  any key"))))
  readKey 0
  0

-- `i` on-demand recursive size: ONE `du -sh` fork (only when asked — never per frame, which is why
-- the live preview uses the instant `stat` size instead). The basename + size are formatted in the
-- SAME shell so `path` is interpolated once (no owned-String duplication). Dirs recurse; files report
-- their own size. "—" when du fails (e.g. a broken symlink).
duOf :: String -> String
duOf path =
  trim (runCapture (strAppend "f=" (strAppend (shQuote path)
    "; printf '%s: ' \"$(basename -- \"$f\")\"; du -sh -- \"$f\" 2>/dev/null | cut -f1 | grep . || printf '%s' '—'")))

-- A verb for the paste "working…" flash, by pending program.
progVerb :: String -> String
progVerb prog =
  if prog == "trash" then "trashing"
  else if prog == "mv" then "moving"
  else if prog == "ln -s" then "linking"
  else if prog == "cp -R" then "copying"
  else "working"
-- The "working…" banner shown BEFORE a (blocking) paste so a large cp -R/mv isn't a silent freeze;
-- "" (a harmless empty putStr) when there is nothing to paste. `putStr` flushes, so it paints first.
workMsg :: String -> Int -> Int -> String
workMsg prog n rows = if n > 0 then workShow prog n rows else ""
workShow :: String -> Int -> Int -> String
workShow prog n rows =
  strAppend (csi (strAppend (showInt rows) ";1H"))
    (strAppend (csi "K")
      (paint "1;33" (strAppend (progVerb prog) (strAppend " " (strAppend (showInt n) " item(s)…")))))

------------------------------------------------------------------- key reading (single byte + arrows)

-- Read one command key; expand an arrow ESC-sequence (ESC [ A/B/C/D) to k/j/l/h. A lone Esc no
-- longer blocks: after ESC the two follow-on bytes are read with `readKeyTimeout 25` (ms), so a
-- bare Esc (no byte within the window) returns "\x1b" — which `step` treats as quit — immediately.
readMainKey :: Int -> String
readMainKey dummy =
  let k = readKey 0 in
  -- short-circuit: `charAt 0 k` runs only on a non-empty key (ESC starts an arrow sequence).
  if strLen k > 0 && charAt 0 k == 27
  then let b1 = readKeyTimeout 25 in
       if strLen b1 == 0 then "\x1b"                     -- lone Esc: no follow-on byte in the window
       else let b2 = readKeyTimeout 25 in arrowKey b2  -- ESC [ <final> → arrow
  else k
-- Like readMainKey but the first byte is read with a timeout: "" = NO key within `ms` (a poll tick
-- for the resize watcher). A lone Esc still returns "\x1b". Only used on a tty (interactive).
readMainKeyTO :: Int -> String
readMainKeyTO ms =
  let k = readKeyTimeout ms in
  if strLen k == 0 then ""
  else if charAt 0 k == 27
  then let b1 = readKeyTimeout 25 in
       if strLen b1 == 0 then "\x1b"
       else let b2 = readKeyTimeout 25 in arrowKey b2
  else k
arrowKey :: String -> String
arrowKey b =
  if b == "A" then "k"
  else if b == "B" then "j"
  else if b == "C" then "l"
  else if b == "D" then "h"
  else ""

------------------------------------------------------------------- key remapping (Lua config)

-- Keybindings are remappable via ~/.config/axfm/config.lua, a Lua TABLE of {key, action} rows:
--   local keys = {
--     { key = "z", action = "doDiskUsage" },   -- z now does what i does
--     { key = "w", action = "doTabClose"  },
--   }
-- axfm does NOT embed a Lua interpreter (it has no C FFI) — at startup it parses that specific table
-- shape with `sed` into ~/.cache/axfm/keymap as `<physical-key>\t<action-name>` lines, and the main
-- dispatcher translates each pressed key through it (physical → the action's CANONICAL key) before
-- the `case`. A remap is ADDITIVE: the default key still works unless it too is remapped. Only the
-- top-level single-key dispatch is remapped — digits (counts), the command line, and search read
-- their keys literally, so a remapped letter is still typeable in a filename / query.
configFile :: Int -> String
configFile d = strAppend (envOr "HOME" ".") "/.config/axfm/config.lua"
keymapFile :: Int -> String
keymapFile d = strAppend (envOr "HOME" ".") "/.cache/axfm/keymap"
-- Parse config.lua → keymap (one fork, at startup), as `key<TAB>item1<TAB>item2…` lines. A scalar
-- `action = "X"` is one item; an inline list `action = { "a", "b" }` is several; a `local NAME = {…}`
-- definition referenced by `action = "NAME"` expands to its items. Single line per definition/binding.
-- Always (re)creates the keymap (empty when no config) so the resolver's readFile never misses.
-- Pass 1 collects `local NAME = {…}` defs; pass 2 writes each binding, expanding a name to its items.
buildKeymapCmd :: String
buildKeymapCmd =
  "cfg=" ++ shQuote (configFile 0) ++ "; km=" ++ shQuote (keymapFile 0)
  ++ "; defs=\"$km.defs\"; src=\"$km.src\"; T=$(printf '\\t'); mkdir -p \"${km%/*}\"; : > \"$km\"; : > \"$defs\"; [ -r \"$cfg\" ] || { rm -f \"$defs\"; exit 0; }; sed '/^[[:space:]]*--/d' \"$cfg\" > \"$src\"; "
  ++ "while IFS= read -r line; do case \"$line\" in *local*=*{*}*) name=$(printf '%s\\n' \"$line\" | sed -n 's/.*local[[:space:]]\\{1,\\}\\([A-Za-z_][A-Za-z0-9_]*\\)[[:space:]]*=.*/\\1/p'); [ -n \"$name\" ] || continue; body=$(printf '%s\\n' \"$line\" | sed -n 's/.*{\\(.*\\)}.*/\\1/p'); items=$(printf '%s\\n' \"$body\" | grep -o '\"[^\"]*\"' | sed 's/^\"//; s/\"$//' | paste -sd \"$T\" -); [ -n \"$items\" ] && printf '%s\\t%s\\n' \"$name\" \"$items\" >> \"$defs\" ;; esac; done < \"$src\"; "
  ++ "while IFS= read -r line; do case \"$line\" in *key*action*) k=$(printf '%s\\n' \"$line\" | sed -n 's/.*key[[:space:]]*=[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p'); [ -n \"$k\" ] || continue; ap=${line#*action}; case \"$ap\" in *{*) body=$(printf '%s\\n' \"$ap\" | sed -n 's/.*{\\(.*\\)}.*/\\1/p'); items=$(printf '%s\\n' \"$body\" | grep -o '\"[^\"]*\"' | sed 's/^\"//; s/\"$//' | paste -sd \"$T\" -) ;; *) x=$(printf '%s\\n' \"$ap\" | sed -n 's/[^\"]*\"\\([^\"]*\\)\".*/\\1/p'); d=$(grep \"^$x$T\" \"$defs\" 2>/dev/null | head -n1); if [ -n \"$d\" ]; then items=${d#*$T}; else items=\"$x\"; fi ;; esac; [ -n \"$items\" ] && printf '%s\\t%s\\n' \"$k\" \"$items\" >> \"$km\" ;; esac; done < \"$src\"; rm -f \"$src\" \"$defs\"; true"

colorsFile :: Int -> String
colorsFile d = strAppend (envOr "HOME" ".") "/.cache/axfm/colors"
iconsFile :: Int -> String
iconsFile d = strAppend (envOr "HOME" ".") "/.cache/axfm/icons"
-- The icons-config string (`buildIcons` cache), read fork-free per frame and threaded as `icfg`. Unlike
-- `lsColors` there is no env to merge (LS_COLORS has no icons). EMPTY ⇒ icons OFF; a non-empty cache (a
-- leading ":" marker + any `{match,icon}` overrides) ⇒ icons ON, with built-in glyphs for the rest.
iconsOf :: Int -> String
iconsOf d = readFile (iconsFile 0)
-- Parse config.lua's `colors` table → ~/.cache/axfm/colors as an LS_COLORS fragment (`key=sgr:…`), at
-- startup. A `{ match = "K", color = "V" }` row: K is an LS_COLORS key (a type `di`/`ex`/`ln`/`or` or an
-- extension glob `*.ext`); V is a `#RRGGBB` hex colour (→ the truecolor SGR `38;2;R;G;B`, which foot and
-- any 24-bit terminal render as that exact colour) or a raw SGR string (passed through — 256-colour/
-- bold/etc.). Extraction is by FIELD NAME (`match`/`color`), so a keybinding row that merely CONTAINS
-- "color" in a value (e.g. action="!color-foo") yields no `match=` → is skipped. Always (re)creates the
-- file (empty when no config/no colours) so `lsColors`' read never misses. Atomic temp→mv.
buildColorsCmd :: String
buildColorsCmd =
  "cfg=" ++ shQuote (configFile 0) ++ "; cf=" ++ shQuote (colorsFile 0)
  ++ "; tmp=\"$cf.$$\"; mkdir -p \"${cf%/*}\"; : > \"$tmp\"; [ -r \"$cfg\" ] && sed '/^[[:space:]]*--/d' \"$cfg\" | while IFS= read -r line; do case \"$line\" in *color*=*) m=$(printf '%s\\n' \"$line\" | sed -n 's/.*match[[:space:]]*=[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p'); v=$(printf '%s\\n' \"$line\" | sed -n 's/.*color[[:space:]]*=[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p'); [ -n \"$m\" ] || continue; case \"$v\" in \\#[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]) r=$((0x$(printf %s \"$v\"|cut -c2-3))); g=$((0x$(printf %s \"$v\"|cut -c4-5))); b=$((0x$(printf %s \"$v\"|cut -c6-7))); v=\"38;2;$r;$g;$b\" ;; esac; printf '%s=%s:' \"$m\" \"$v\" >> \"$tmp\" ;; esac; done; mv \"$tmp\" \"$cf\"; true"
-- Parse config.lua ONCE at startup in a SINGLE fork: run the colours pass then the keymap pass in one
-- `sh -c` (colours FIRST — it never `exit`s; the keymap pass's no-config `exit 0` is harmless as the last
-- statement). Same two cache files as before, one fork instead of two. CACHED: a leading freshness guard
-- `exit 0`s when both caches already exist and are newer than config.lua (or there is no config.lua) — so
-- an unchanged config is NOT re-parsed on every launch; editing config.lua makes it newer → re-parse.
-- Parse config.lua's `icons` table → ~/.cache/axfm/icons (`match=glyph:…`), the icon twin of
-- `buildColorsCmd`. A `{ match = "K", icon = "V" }` row: K is a `di`/`ln`/`or`/`ex` type key, an `*.ext`
-- glob, or a category `image/*`; V is the glyph (passed through raw — no hex conversion). Icons are ON by
-- DEFAULT: the cache is seeded with a single ":" (non-empty ⇒ `iconsOf` enables icons; the ":" also makes
-- the first real entry sit at a `:`-boundary for `lscVal`), and built-in glyphs fill anything unconfigured.
-- A top-level `icons = false` line DISABLES: the cache is left EMPTY ⇒ `rowCell` emits no glyph. Atomic.
buildIconsCmd :: String
buildIconsCmd =
  "cfg=" ++ shQuote (configFile 0) ++ "; icf=" ++ shQuote (iconsFile 0)
  ++ "; tmp=\"$icf.$$\"; mkdir -p \"${icf%/*}\"; : > \"$tmp\"; if [ -r \"$cfg\" ] && sed '/^[[:space:]]*--/d' \"$cfg\" | grep -qE 'icons[[:space:]]*=[[:space:]]*false'; then :; else printf ':' > \"$tmp\"; [ -r \"$cfg\" ] && sed '/^[[:space:]]*--/d' \"$cfg\" | while IFS= read -r line; do case \"$line\" in *icon*=*) m=$(printf '%s\\n' \"$line\" | sed -n 's/.*match[[:space:]]*=[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p'); v=$(printf '%s\\n' \"$line\" | sed -n 's/.*icon[[:space:]]*=[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p'); [ -n \"$m\" ] || continue; printf '%s=%s:' \"$m\" \"$v\" >> \"$tmp\" ;; esac; done; fi; mv \"$tmp\" \"$icf\"; true"
buildConfig :: Int -> Int
buildConfig d = runStatus (strAppend buildConfigGuard (strAppend buildColorsCmd (strAppend "; " (strAppend buildIconsCmd (strAppend "; " buildKeymapCmd)))))
buildConfigGuard :: String
buildConfigGuard =
  "km=" ++ shQuote (keymapFile 0) ++ "; cf=" ++ shQuote (colorsFile 0) ++ "; ic=" ++ shQuote (iconsFile 0) ++ "; cg=" ++ shQuote (configFile 0)
  ++ "; [ -f \"$km\" ] && [ -f \"$cf\" ] && [ -f \"$ic\" ] && { [ ! -f \"$cg\" ] || { [ \"$km\" -nt \"$cg\" ] && [ \"$cf\" -nt \"$cg\" ] && [ \"$ic\" -nt \"$cg\" ]; }; } && exit 0; "

-- The CANONICAL (default) key for an action name — the single source of truth for action→key, used
-- both to resolve a remap and (implicitly) documenting every bindable action. "" = unknown action.
actionKey :: String -> String
actionKey a =
  if a == "down" then "j" else if a == "up" then "k"
  else if a == "top" then "g" else if a == "bottom" then "G"
  else if a == "open" then "l" else if a == "parent" then "h"
  else if a == "toggleHidden" then "." else if a == "refresh" then "e"
  else if a == "home" then "~" else if a == "prev" then "-"
  else if a == "doGoDir" then ":" else if a == "doSearch" then "/"
  else if a == "searchNext" then ";" else if a == "searchPrev" then ","
  else if a == "doMkdir" then "n" else if a == "doMkfile" then "f"
  else if a == "doRename" then "r" else if a == "doAttr" then "x"
  else if a == "doChmod" then "X" else if a == "doBulk" then "R"
  else if a == "markCopy" then "y" else if a == "markMove" then "m"
  else if a == "markLink" then "s" else if a == "markTrash" then "d"
  else if a == "markAllCopy" then "Y" else if a == "markAllMove" then "M"
  else if a == "markAllLink" then "S" else if a == "markAllTrash" then "D"
  else if a == "clearMarks" then "c" else if a == "doPaste" then "p"
  else if a == "doShell" then "!" else if a == "doSort" then "o"
  else if a == "doFilter" then "F" else if a == "doRestore" then "u"
  else if a == "doCopyPath" then "P" else if a == "doDiskUsage" then "i"
  else if a == "doSetMark" then "b" else if a == "doJumpMark" then "B"
  else if a == "doTabNew" then "t" else if a == "doTabClose" then "T"
  else if a == "doTabNext" then "]" else if a == "doTabPrev" then "["
  else if a == "doHelp" then "?" else if a == "quit" then "q"
  else if a == "scrollDown" then "J" else if a == "scrollUp" then "K"
  else ""

-- Split a `key<TAB>action` keymap line on the tab (byte 9).
tabIdx :: String -> Int
tabIdx s = tabScan s 0
tabScan :: String -> Int -> Int
tabScan s i = if i >= strLen s then (0 - 1) else if charAt i s == 9 then i else tabScan s (i + 1)
kmKey :: String -> String
kmKey line = let i = tabIdx line in if i < 0 then dup line else substr 0 i line
kmVal :: String -> String
kmVal line = let i = tabIdx line in if i < 0 then "" else substr (i + 1) (strLen line - i - 1) line
-- The action bound to physical key `k` in the keymap text, or "" if unbound.
lookupAction :: String -> String -> String
lookupAction content k = laGo (lines content) k
laGo :: List String -> String -> String
laGo xs k = case xs of
  Nil -> ""
  Cons y ys -> if kmKey y == k then kmVal y else laGo ys k
-- MULTI-KEY SEQUENCES: a binding key may be more than one character (`{ key = "gh", action = "home" }`
-- makes `g` a LEADER — press g then h → home, ranger-style). Does `acc` PROPERLY begin some binding
-- (a longer key starts with it)? Then more keys are needed to complete a sequence.
isProperPrefix :: String -> String -> Bool
isProperPrefix km acc = ippGo (lines km) acc
ippGo :: List String -> String -> Bool
ippGo xs acc = case xs of
  Nil -> False
  Cons y ys -> if seqStarts (kmKey y) acc then True else ippGo ys acc
-- `b` is a binding longer than `acc` that begins with `acc` (so `acc` can still grow into `b`).
seqStarts :: String -> String -> Bool
seqStarts b acc = (strLen b > strLen acc) && hasPrefix acc b

-- Grow the pressed key by reading follow-on keys while it is a proper prefix of some binding; stop at
-- the first complete-or-dead-end (or at EOF / no key). Returns the full typed sequence.
resolveSeq :: String -> String -> String
resolveSeq km acc = if isProperPrefix km acc then seqNext km acc (readKey 0) else acc
seqNext :: String -> String -> String -> String
seqNext km acc k = if strLen k == 0 then acc else resolveSeq km (strAppend acc k)

-- The CANONICAL dispatch key for a pressed key: read any follow-on keys, look the whole sequence up,
-- and map a bound action to its default key. "" means "no-op" (an unknown multi-key chord); an
-- unconfigured single key passes through unchanged (default behaviour); a remap to an unknown action
-- name also passes through. readFile of the keymap is a builtin (no fork) — once per keypress.
seqKey :: String -> String
seqKey key =
  let km = readFile (keymapFile 0) in
  if strLen km == 0 then dup key          -- no config → skip all resolve work (the common case)
  else seqResolve km (resolveSeq km key)
seqResolve :: String -> String -> String
seqResolve km s =
  let a = lookupAction km s in
  if strLen a == 0 then (if strLen s == 1 then dup s else "")
  else if hasInfix "\t" a then dup a                 -- a multi-action list (tab-joined items): carry through
  else if hasPrefix "!" a then dup a                 -- a shell-command action (`!cmd`/`!!cmd`): carry through
  else if hasPrefix "cd " a then dup a               -- a `cd <path>` navigate action: carry it through
  else actionPick s (actionKey a)
-- A bound action → its canonical key `kc` (actionKey), or the raw sequence back for an unknown action
-- name. `kc` is a PARAM (not an inline `let`) so this is the `dupOrAcc`-shaped mixed return the drop
-- verifier accepts — an inline `let kc = actionKey a in …` trips AX0910 (literal-vs-dup imbalance).
actionPick :: String -> String -> String
actionPick s kc = if strLen kc == 0 then dup s else kc

-- Replace every `%s` in a shell-command action with `rep` (the quoted selected-file reference). `rep`
-- is passed as the literal `"$f"`, so it is drop-trivial even when the command has several `%s`.
substPct :: String -> String -> String
substPct cmd rep = spGo cmd rep 0
isPctS :: String -> Int -> Bool
isPctS cmd i = (i + 1 < strLen cmd) && (charAt i cmd == '%') && (charAt (i + 1) cmd == 's')
spGo :: String -> String -> Int -> String
spGo cmd rep i =
  if i >= strLen cmd then ""
  else if isPctS cmd i then strAppend rep (spGo cmd rep (i + 2))
  else strAppend (substr i 1 cmd) (spGo cmd rep (i + 1))

------------------------------------------------------------------- the event loop + dispatch

-- State: cwd, cursor index, marked (newline-joined paths), pending program, hidden flag, rows,
-- plus a CACHED frame context — `cols` (terminal width) and `raw` (the `ls` output). Navigation
-- (j/k/g/G/mark/search) reuses the cache so a move spawns NO `ls`/`stty` (Yazi-like); only a
-- transition that changes the directory CONTENTS goes through `reloop`, which re-captures both.
-- `main` and every such transition enter via `reloop` (6 args); the worker `loop` has 8.
-- The DEFAULT (name) sort takes the native path: one `readDirTyped` syscall builds both `raw` and the
-- stamped `types` in pure Axión — no `ls` fork, no per-entry `stat` classify loop (the old startup cost).
-- Size/mtime sort (a non-empty `sort` file) still needs `ls -S`/`-t`, so it keeps the shell path.
reloop :: String -> Int -> String -> String -> Int -> Int -> IO ()
reloop cwd sel marked prog hidden rows = do
  syncTab cwd
  reloopDispatch cwd sel marked prog hidden rows (trim (readFile (sortFile 0)))
reloopDispatch :: String -> Int -> String -> String -> Int -> Int -> String -> IO ()
reloopDispatch cwd sel marked prog hidden rows sortf =
  if strLen sortf == 0 then reloopNative cwd sel marked prog hidden rows
                       else reloopShell cwd sel marked prog hidden rows
reloopNative :: String -> Int -> String -> String -> Int -> Int -> IO ()
reloopNative cwd sel marked prog hidden rows = do
  rdt <- readDirTyped cwd
  writeFile (typesFile 0) (rdtTypes cwd rdt hidden (trim (readFile (filterFile 0))))
  loop cwd sel marked prog hidden rows (termCols 0) (rdtRaw rdt hidden (trim (readFile (filterFile 0))))
reloopShell :: String -> Int -> String -> String -> Int -> Int -> IO ()
reloopShell cwd sel marked prog hidden rows = do
  classifyNow cwd hidden
  loop cwd sel marked prog hidden rows (termCols 0) (runCapture (lsCmd cwd hidden))
-- Like `reloop`, but after listing `cwd` it places the cursor on the entry named `child`
-- (slash-stripped exact match) instead of the top — so going UP to a parent re-selects the
-- directory you just came out of (`ranger`/`yazi`-style), not entry 0. Falls back to 0 if the
-- child is absent (e.g. came out of a hidden dir with hidden display off).
reloopInto :: String -> String -> String -> String -> Int -> Int -> IO ()
reloopInto cwd child marked prog hidden rows = do
  syncTab cwd
  reloopIntoDispatch cwd child marked prog hidden rows (trim (readFile (sortFile 0)))
reloopIntoDispatch :: String -> String -> String -> String -> Int -> Int -> String -> IO ()
reloopIntoDispatch cwd child marked prog hidden rows sortf =
  if strLen sortf == 0 then reloopIntoNative cwd child marked prog hidden rows
                       else reloopIntoShell cwd child marked prog hidden rows
reloopIntoNative :: String -> String -> String -> String -> Int -> Int -> IO ()
reloopIntoNative cwd child marked prog hidden rows = do
  rdt <- readDirTyped cwd
  writeFile (typesFile 0) (rdtTypes cwd rdt hidden (trim (readFile (filterFile 0))))
  loopSel cwd child marked prog hidden rows (rdtRaw rdt hidden (trim (readFile (filterFile 0))))
reloopIntoShell :: String -> String -> String -> String -> Int -> Int -> IO ()
reloopIntoShell cwd child marked prog hidden rows = do
  classifyNow cwd hidden
  loopSel cwd child marked prog hidden rows (runCapture (lsCmd cwd hidden))
-- Resolve `child` to its index in the freshly-captured `raw` and enter `loop` there. `raw` is
-- reused for both the index lookup and the frame cache (one `ls`, no re-list).
loopSel :: String -> String -> String -> String -> Int -> Int -> String -> IO ()
loopSel cwd child marked prog hidden rows raw =
  loop cwd (indexOfName (lines raw) child 0 0) marked prog hidden rows (termCols 0) raw
-- First index whose entry name (slash-stripped) EXACTLY equals `target`, else `dflt`. Exact
-- (not infix like search's `matchIndex`) so "Downloads" can't land on "Downloads (old)".
indexOfName :: List String -> String -> Int -> Int -> Int
indexOfName xs target i dflt = case xs of
  Nil -> dflt
  Cons y ys -> if strCmp (stripSlash y) target == 0 then i else indexOfName ys target (i + 1) dflt
-- One `ls` fork per refresh now also classifies types (freshLsAndTypes); pure `lines` re-derives entries.
-- `loop` renders at preview-scroll offset 0; `loopAt` carries a non-zero offset for J/K. Any key
-- other than J/K resets the scroll (it goes through `step`, whose branches re-enter via `loop` = 0).
loop :: String -> Int -> String -> String -> Int -> Int -> Int -> String -> IO ()
loop cwd sel marked prog hidden rows cols raw =
  loopAt cwd sel marked prog hidden rows cols raw 0
loopAt :: String -> Int -> String -> String -> Int -> Int -> Int -> String -> Int -> IO ()
-- FAST PATH: draw a FORK-FREE list frame (entries + cursor + minimal status, all from the cached `raw`
-- — no `selInfo`, no `visTypes`, no text `previewSeg`, no image), so moving the cursor costs zero
-- subprocesses (yazi-fast scrolling). The full frame (preview pane, LS_COLORS types, size/mtime/link
-- status, pixel overlay, prefetch) is deferred to `settledFull`, run only once the cursor SETTLES.
-- A multi-action binding (an action LIST / named function) queues items in `pendingFile`; drain the
-- next one FIRST (its own handler re-enters the loop) in BOTH tty/headless modes. Otherwise pick the
-- frame path: a tty gets the fork-free fast list + settle debounce; headless gets ONE full render
-- (so the gates see the preview/colours/status, and occurrence counts aren't doubled) + a blocking read.
loopAt cwd sel marked prog hidden rows cols raw poff =
  if strLen (readFile (pendingFile 0)) > 0
  then runItem cwd sel marked prog hidden rows cols raw (popItem 0)
  else frameWait cwd sel marked prog hidden rows cols raw poff
frameWait :: String -> Int -> String -> String -> Int -> Int -> Int -> String -> Int -> IO ()
frameWait cwd sel marked prog hidden rows cols raw poff =
  if onTty 0
  then settleStart cwd sel marked prog hidden rows cols raw poff
  else fullWait cwd sel marked prog hidden rows cols raw poff

-- Settle debounce (~yazi's image_delay): draw the fast list, then wait up to `imageDelayMs` for the next
-- key. A key within the window (still moving — `readMainKeyTO` returns buffered keys instantly, so held
-- scroll never waits) → dispatch it, staying on the cheap list; a settle (no key) → the FULL frame
-- (preview/colours/info/image) + prefetch, then poll.
imageDelayMs :: Int
imageDelayMs = 40
settleStart :: String -> Int -> String -> String -> Int -> Int -> Int -> String -> Int -> IO ()
settleStart cwd sel marked prog hidden rows cols raw poff = do
  putStr (listFrame cwd sel marked prog rows raw cols poff)
  settleKey cwd sel marked prog hidden rows cols raw poff (readMainKeyTO imageDelayMs)
settleKey :: String -> Int -> String -> String -> Int -> Int -> Int -> String -> Int -> String -> IO ()
settleKey cwd sel marked prog hidden rows cols raw poff key =
  if strLen key == 0
  then settledFull cwd sel marked prog hidden rows cols raw poff
  else stepAt cwd sel marked prog hidden rows cols raw poff key
-- Settled (on a tty): the full frame + pixel overlay + background prefetch, then the resize poll.
settledFull :: String -> Int -> String -> String -> Int -> Int -> Int -> String -> Int -> IO ()
settledFull cwd sel marked prog hidden rows cols raw poff = do
  info <- selInfo (selPathOf cwd raw sel)
  putStr (render cwd sel marked prog rows raw cols info poff)
  previewImage cwd sel rows raw cols (infoMime info)
  prefetch cwd sel rows raw cols
  pollKey cwd sel marked prog hidden rows cols raw poff
-- Off a tty (headless gates): the full frame (no image — gated off), then the blocking read so EOF quits.
fullWait :: String -> Int -> String -> String -> Int -> Int -> Int -> String -> Int -> IO ()
fullWait cwd sel marked prog hidden rows cols raw poff = do
  info <- selInfo (selPathOf cwd raw sel)
  putStr (render cwd sel marked prog rows raw cols info poff)
  prefetch cwd sel rows raw cols
  stepAt cwd sel marked prog hidden rows cols raw poff (readMainKey 0)
-- TTY poll: a real key dispatches at once; a timeout tick ("") falls to the resize check. Recurses
-- here on no-resize so `onTty` is forked once per frame, not once per tick.
pollKey :: String -> Int -> String -> String -> Int -> Int -> Int -> String -> Int -> IO ()
pollKey cwd sel marked prog hidden rows cols raw poff =
  dispatchWait cwd sel marked prog hidden rows cols raw poff (readMainKeyTO 500)
dispatchWait :: String -> Int -> String -> String -> Int -> Int -> Int -> String -> Int -> String -> IO ()
dispatchWait cwd sel marked prog hidden rows cols raw poff key =
  if strLen key == 0
  then resizeCheck cwd sel marked prog hidden rows cols raw poff
  else stepAt cwd sel marked prog hidden rows cols raw poff key
-- Terminal size unchanged → keep polling; changed → re-list + redraw at the new size (same as `e`).
resizeCheck :: String -> Int -> String -> String -> Int -> Int -> Int -> String -> Int -> IO ()
resizeCheck cwd sel marked prog hidden rows cols raw poff =
  if (termCols 0 == cols) && (termRows 0 == rows)
  then pollKey cwd sel marked prog hidden rows cols raw poff
  else reloop cwd (clampSel sel (countLines raw)) marked prog hidden (termRows 0)

-- Intercept the preview-scroll keys J/K (re-render the SAME selection at a new offset, no re-list);
-- every other key resets scroll and falls through to the full dispatcher `step` unchanged.
stepAt :: String -> Int -> String -> String -> Int -> Int -> Int -> String -> Int -> String -> IO ()
stepAt cwd sel marked prog hidden rows cols raw poff key =
  if key == ""
  then step cwd sel marked prog hidden rows cols raw key           -- EOF (empty read) → step quits
  else stepCanon cwd sel marked prog hidden rows cols raw poff (seqKey key)
-- Dispatch the CANONICAL key (after the config remap + any multi-key sequence): "" here = an unknown
-- chord (seqKey gave up) → just redraw; J/K scroll the preview; else fall through to the full `step`.
stepCanon :: String -> Int -> String -> String -> Int -> Int -> Int -> String -> Int -> String -> IO ()
stepCanon cwd sel marked prog hidden rows cols raw poff key =
  if key == "" then loop cwd sel marked prog hidden rows cols raw
  else if hasInfix "\t" key                              -- a multi-action binding (tab-joined items)
    then doRunList cwd sel marked prog hidden rows cols raw key
  else if (strLen key > 2) && (charAt 0 key == '!') && (charAt 1 key == '!')  -- `!!cmd` = INTERACTIVE
    then doUserCmdTty cwd sel marked prog hidden rows raw (substr 2 (strLen key - 2) key)
  else if (strLen key > 1) && (charAt 0 key == '!')      -- a config `!cmd` binding (bare `!` = shell key)
    then doUserCmd cwd sel marked prog hidden rows cols raw (substr 1 (strLen key - 1) key)
  else if hasPrefix "cd " key                            -- a config `cd <path>` binding → navigate there
    then gotoDir cwd (substr 3 (strLen key - 3) key) sel marked prog hidden rows
  else if key == "J" then loopAt cwd sel marked prog hidden rows cols raw (scrollDown poff rows)
  else if key == "K" then loopAt cwd sel marked prog hidden rows cols raw (scrollUp poff rows)
  else step cwd sel marked prog hidden rows cols raw key

-- Navigation branches thread `cols raw` forward (no re-listing); directory-changing branches drop
-- the cache and re-enter via `reloop`. Counts/paths come from the cached `raw`, not a fresh `ls`.
step :: String -> Int -> String -> String -> Int -> Int -> Int -> String -> String -> IO ()
step cwd sel marked prog hidden rows cols raw key = case key of
  "j" -> loop cwd (wrapSel (sel + 1) (countLines raw)) marked prog hidden rows cols raw
  "k" -> loop cwd (wrapSel (sel - 1) (countLines raw)) marked prog hidden rows cols raw
  "g" -> loop cwd 0 marked prog hidden rows cols raw
  "G" -> loop cwd (clampSel (countLines raw - 1) (countLines raw)) marked prog hidden rows cols raw
  "l" -> open cwd sel marked prog hidden rows raw
  "h" -> reloopInto (parentDir cwd) (baseName cwd) marked prog hidden rows
  "." -> reloop cwd 0 marked prog (if hidden == 1 then 0 else 1) rows
  "e" -> reloop cwd (clampSel sel (countLines raw)) marked prog hidden (termRows 0)
  "~" -> goHome marked prog hidden rows
  "-" -> goPrev marked prog hidden rows
  ":" -> doGoDir cwd sel marked prog hidden rows
  "/" -> doSearch cwd sel marked prog hidden rows cols raw
  "n" -> doMkdir cwd sel marked prog hidden rows
  "f" -> doMkfile cwd sel marked prog hidden rows
  "r" -> doRename cwd sel marked prog hidden rows
  "x" -> doAttr cwd sel marked prog hidden rows
  "X" -> doChmod cwd sel marked prog hidden rows
  "y" -> loop cwd sel (markToggle marked (selPathOf cwd raw sel)) "cp -R" hidden rows cols raw
  "m" -> loop cwd sel (markToggle marked (selPathOf cwd raw sel)) "mv" hidden rows cols raw
  "s" -> loop cwd sel (markToggle marked (selPathOf cwd raw sel)) "ln -s" hidden rows cols raw
  "d" -> loop cwd sel (markToggle marked (selPathOf cwd raw sel)) "trash" hidden rows cols raw
  "Y" -> loop cwd sel (allPathsOf cwd raw) "cp -R" hidden rows cols raw
  "M" -> loop cwd sel (allPathsOf cwd raw) "mv" hidden rows cols raw
  "S" -> loop cwd sel (allPathsOf cwd raw) "ln -s" hidden rows cols raw
  "D" -> loop cwd sel (allPathsOf cwd raw) "trash" hidden rows cols raw
  "c" -> loop cwd sel "" "" hidden rows cols raw
  "p" -> doPaste cwd sel marked prog hidden rows
  "R" -> doBulk cwd sel marked prog hidden rows
  "!" -> doShell cwd sel marked prog hidden rows
  "o" -> doSort cwd sel marked prog hidden rows
  "F" -> doFilter cwd sel marked prog hidden rows
  "u" -> doRestore cwd sel marked prog hidden rows
  "P" -> doCopyPath cwd sel marked prog hidden rows cols raw
  "i" -> doDiskUsage cwd sel marked prog hidden rows cols raw
  "b" -> doSetMark cwd sel marked prog hidden rows
  "B" -> doJumpMark cwd sel marked prog hidden rows
  "t" -> doTabNew cwd sel marked prog hidden rows
  "T" -> doTabClose cwd sel marked prog hidden rows
  "]" -> doTabNext cwd sel marked prog hidden rows
  "[" -> doTabPrev cwd sel marked prog hidden rows
  "?" -> doHelp cwd sel marked prog hidden rows
  ";" -> loop cwd (searchNext raw (readLastQ 0) sel) marked prog hidden rows cols raw
  "," -> loop cwd (searchPrev raw (readLastQ 0) sel) marked prog hidden rows cols raw
  "q" -> quit cwd
  "\x1b" -> quit cwd
  ""  -> quit cwd
  other -> if digitStart key
           then countLoop cwd sel marked prog hidden rows cols raw key
           else favOrIgnore cwd sel marked prog hidden rows key

-- `i` disk usage: flash the recursive size of the SELECTED entry (one du fork), then redraw. On the
-- cached `raw`/`cols` (no re-list), so it returns to the exact same frame.
doDiskUsage :: String -> Int -> String -> String -> Int -> Int -> Int -> String -> IO ()
doDiskUsage cwd sel marked prog hidden rows cols raw = do
  flashInfo (duOf (selPathOf cwd raw sel)) rows
  loop cwd sel marked prog hidden rows cols raw

-- Numeric count prefix (vim-style): a digit 1-9 starts a count shown on the bottom row, more digits
-- extend it, then a motion (j/k down/up, g/G to line N) repeats/addresses by it. Enter applies the
-- count as a favourite (so a bare favourite still works as `<n>` Enter); Esc cancels; any other key
-- is dispatched normally with the count discarded. Mirrors the cmdLine / search accumulator loops.
digitStart :: String -> Bool
digitStart k = (strLen k > 0) && (charAt 0 k >= '1') && (charAt 0 k <= '9')
isDigitK :: String -> Bool
isDigitK k = (strLen k > 0) && (charAt 0 k >= '0') && (charAt 0 k <= '9')
countPrompt :: Int -> String -> String
countPrompt rows acc =
  strAppend (csi (strAppend (showInt rows) ";1H"))
    (strAppend (csi "?25h") (strAppend (csi "K") (strAppend "count: " acc)))
countLoop :: String -> Int -> String -> String -> Int -> Int -> Int -> String -> String -> IO ()
countLoop cwd sel marked prog hidden rows cols raw acc = do
  putStr (countPrompt rows acc)
  countKey cwd sel marked prog hidden rows cols raw acc (readKey 0)
countKey :: String -> Int -> String -> String -> Int -> Int -> Int -> String -> String -> String -> IO ()
countKey cwd sel marked prog hidden rows cols raw acc k =
  if isDigitK k then countLoop cwd sel marked prog hidden rows cols raw (strAppend acc k)
  else applyCount cwd sel marked prog hidden rows cols raw k (fromMaybe 1 (readInt acc))
-- `k` = the terminating key, `n` = the parsed count (acc already consumed by readInt — only `n` and
-- the key reach here, so no owned-String is used twice). Every branch is a tail call.
applyCount :: String -> Int -> String -> String -> Int -> Int -> Int -> String -> String -> Int -> IO ()
applyCount cwd sel marked prog hidden rows cols raw k n =
  let total = countLines raw in
  if k == "" then loop cwd sel marked prog hidden rows cols raw
  else if k == "j" then loop cwd (wrapSel (sel + n) total) marked prog hidden rows cols raw
  else if k == "k" then loop cwd (wrapSel (sel - n) total) marked prog hidden rows cols raw
  else if (k == "G") || (k == "g") then loop cwd (clampSel (n - 1) total) marked prog hidden rows cols raw
  else if (charAt 0 k == '\r') || (charAt 0 k == '\n') then favOrIgnore cwd sel marked prog hidden rows (showInt n)
  else if charAt 0 k == 27 then loop cwd sel marked prog hidden rows cols raw
  else step cwd sel marked prog hidden rows cols raw k

-- Preview scroll (J/K): half a pane per press. Clamped at the top (0); NO bottom clamp — scrolling
-- past EOF shows blank rows and K scrolls back, which avoids a per-scroll `wc -l` fork on huge files.
scrollStep :: Int -> Int
scrollStep rows = let h = maxItems rows in if h > 2 then h `div` 2 else 1
scrollDown :: Int -> Int -> Int
scrollDown poff rows = poff + scrollStep rows
scrollUp :: Int -> Int -> Int
scrollUp poff rows = let p = poff - scrollStep rows in if p < 0 then 0 else p

clampSel :: Int -> Int -> Int
clampSel i n = if n == 0 then 0 else if i < 0 then 0 else if i >= n then n - 1 else i
-- Like clampSel but WRAPS: past the bottom → first, before the top → last (for j/k cursor movement).
wrapSel :: Int -> Int -> Int
wrapSel i n = if n == 0 then 0 else if i < 0 then n - 1 else if i >= n then 0 else i

-- `l`/Enter: descend into a directory, or open a file (text → $EDITOR, else xdg-open backgrounded).
open :: String -> Int -> String -> String -> Int -> Int -> String -> IO ()
open cwd sel marked prog hidden rows raw =
  if isDirPath (selPathOf cwd raw sel)
  then reloop (selPathOf cwd raw sel) 0 marked prog hidden rows
  else openFile cwd sel marked prog hidden rows

isDirPath :: String -> Bool
isDirPath p = runStatus (strAppend "test -d " (shQuote p)) == 0
-- Does `p` NOT exist (any type, symlinks followed)? `test -e` exits non-zero when absent.
pathMissing :: String -> Bool
pathMissing p = runStatus (strAppend "test -e " (shQuote p)) > 0
-- OK to write to `dest` (renaming from `src`)? Yes if it is the same path, or does not exist, or the
-- user confirms the overwrite. `||` short-circuits so the confirm is asked ONLY on a real collision.
okToClobber :: String -> String -> Int -> Bool
okToClobber dest src rows =
  (dest == src)
    || pathMissing dest
    || confirm (strAppend "overwrite " (strAppend (baseName dest) "? [y/N] ")) rows

isTextPath :: String -> Bool
isTextPath p = runStatus (strAppend "file -bL --mime-type " (strAppend (shQuote p)
                 " 2>/dev/null | grep -q '^text/\\|^inode/x-empty'")) == 0

openFile :: String -> Int -> String -> String -> Int -> Int -> IO ()
openFile cwd sel marked prog hidden rows =
  if isTextPath (selPath cwd hidden sel)
  then openText cwd sel marked prog hidden rows
  else openOther cwd sel marked prog hidden rows

openText :: String -> Int -> String -> String -> Int -> Int -> IO ()
openText cwd sel marked prog hidden rows = do
  putStr resetSeq
  runStatus (strAppend (editorCmd 0) (strAppend " " (shQuote (selPath cwd hidden sel))))
  putStr setupSeq
  reloop cwd sel marked prog hidden rows

openOther :: String -> Int -> String -> String -> Int -> Int -> IO ()
openOther cwd sel marked prog hidden rows = do
  runStatus (strAppend "nohup xdg-open " (strAppend (shQuote (selPath cwd hidden sel)) " >/dev/null 2>&1 &"))
  reloop cwd sel marked prog hidden rows

-- $VISUAL or $EDITOR or vi.
editorCmd :: Int -> String
editorCmd d =
  let v = getEnv "VISUAL" in
  if strLen v > 0 then v
  else let e = getEnv "EDITOR" in if strLen e > 0 then e else "vi"

goHome :: String -> String -> Int -> Int -> IO ()
goHome marked prog hidden rows =
  reloop (envOr "HOME" ".") 0 marked prog hidden rows
goPrev :: String -> String -> Int -> Int -> IO ()
goPrev marked prog hidden rows =
  reloop (envOr "OLDPWD" ".") 0 marked prog hidden rows

-- getEnv, or a fresh default if unset/empty (never conditionally escapes the argument).
envOr :: String -> String -> String
envOr name dflt = let v = getEnv name in if strLen v > 0 then v else dup dflt

-- Favourites 1-9 → $FFF_FAV<n>; anything else ignored.
favOrIgnore :: String -> Int -> String -> String -> Int -> Int -> String -> IO ()
favOrIgnore cwd sel marked prog hidden rows key =
  let fav = getEnv (strAppend "FFF_FAV" key) in
  if (strLen key > 0) && (charAt 0 key >= '1') && (charAt 0 key <= '9') && (strLen fav > 0)
  then reloop fav 0 marked prog hidden rows
  else reloop cwd sel marked prog hidden rows

-- All entries of cwd as newline-joined full paths (for mark-all).
allPaths :: String -> Int -> String
allPaths cwd hidden = joinPaths cwd (entriesRaw cwd hidden)
-- Mark-all over an ALREADY-captured listing (no fresh `ls`) — the cached twin of allPaths.
allPathsOf :: String -> String -> String
allPathsOf cwd raw = joinPaths cwd (lines raw)
joinPaths :: String -> List String -> String
joinPaths cwd xs = case xs of
  Nil -> ""
  Cons y ys -> strAppend (strAppend (cwd </> stripSlash y) "\n") (joinPaths cwd ys)

------------------------------------------------------------------- operations

-- `n` mkdir, `f` mkfile, `r` rename, `:` go-dir — each prompts via cmdLine, then acts + refreshes.
doMkdir :: String -> Int -> String -> String -> Int -> Int -> IO ()
doMkdir cwd sel marked prog hidden rows = do
  nm <- cmdLine "mkdir: " rows cwd
  code <- (if strLen nm > 0 then makeDir (cwd </> nm) else 0)
  okOr code "mkdir failed" rows
  reloop cwd (clampSel sel (nEntries cwd hidden + 1)) marked prog hidden rows

doMkfile :: String -> Int -> String -> String -> Int -> Int -> IO ()
doMkfile cwd sel marked prog hidden rows = do
  nm <- cmdLine "mkfile: " rows cwd
  code <- (if strLen nm > 0 then writeFile (cwd </> nm) "" else 0)
  okOr code "mkfile failed" rows
  reloop cwd (clampSel sel (nEntries cwd hidden + 1)) marked prog hidden rows

doRename :: String -> Int -> String -> String -> Int -> Int -> IO ()
doRename cwd sel marked prog hidden rows = do
  nm <- cmdLine (strAppend "rename " (strAppend (selName cwd hidden sel) " to: ")) rows cwd
  code <- renameMaybe cwd hidden sel nm rows
  okOr code "rename failed" rows
  reloop cwd sel marked prog hidden rows
-- Rename unless the name is empty or the target exists and the user declines to overwrite it.
-- Returns the renameFile exit (0 when skipped/declined) for doRename's failure flash.
renameMaybe :: String -> Int -> Int -> String -> Int -> Int
renameMaybe cwd hidden sel nm rows =
  if strLen nm == 0 then 0
  else if okToClobber (cwd </> nm) (selPath cwd hidden sel) rows
       then renameFile (selPath cwd hidden sel) (cwd </> nm)
       else 0

doGoDir :: String -> Int -> String -> String -> Int -> Int -> IO ()
doGoDir cwd sel marked prog hidden rows = do
  nm <- cmdLine "go to dir: " rows cwd
  gotoDir cwd nm sel marked prog hidden rows
-- `:` go-to-dir, path-aware like `h`: expand a leading ~ (or ~/…) to $HOME, resolve a RELATIVE name
-- against the dir being browsed (not fff's process cwd), leave an absolute path as-is, then
-- canonicalise with `absPath` (so `..`/symlinks collapse and the new cwd can itself be ascended).
gotoDir :: String -> String -> Int -> String -> String -> Int -> Int -> IO ()
gotoDir cwd nm sel marked prog hidden rows =
  if strLen nm == 0
  then reloop cwd sel marked prog hidden rows
  else gotoTo cwd sel marked prog hidden rows (absPath (expandDir cwd nm))
-- cd to `dest` if it's a directory, else stay. `dup dest` in the then-arm keeps `dest` borrow-only
-- (no conditional move — the idiom the old gotoDir used with `nm`).
gotoTo :: String -> Int -> String -> String -> Int -> Int -> String -> IO ()
gotoTo cwd sel marked prog hidden rows dest =
  if isDirPath dest
  then reloop (dup dest) 0 marked prog hidden rows
  else reloop cwd sel marked prog hidden rows
-- The raw path to resolve: ~ / ~/… → $HOME[…]; /… → absolute as typed; anything else → relative to
-- the browse dir `cwd`. All three arms return a fresh owned String in tail position.
expandDir :: String -> String -> String
expandDir cwd nm =
  if (nm == "~") || hasPrefix "~/" nm then tildeExpand nm
  else if hasPrefix "/" nm then dup nm
  else cwd </> nm
tildeExpand :: String -> String
tildeExpand nm = strAppend (envOr "HOME" ".") (substr 1 (strLen nm - 1) nm)

-- `/` search: prompt for a substring, jump the cursor to the first matching entry (live redraw of
-- the prompt happens in cmdLine; the match is applied on submit). The query is remembered in
-- ~/.cache/axfm/lastq so `;`/`,` can cycle through the other matches.
-- `/` INCREMENTAL search: as each key is typed, jump the cursor to the first entry containing the
-- query so far and redraw the WHOLE frame live (cursor + text preview), with `/query` on the bottom
-- row. Enter confirms at the match (remembered in lastq for `;`/`,`); Esc cancels to the original
-- selection. Operates on the cached `raw` — no re-listing per keystroke. The image overlay is NOT
-- drawn while typing (render's clear wipes any prior image); it returns when the normal loop resumes.
doSearch :: String -> Int -> String -> String -> Int -> Int -> Int -> String -> IO ()
doSearch cwd sel marked prog hidden rows cols raw =
  searchLoop cwd sel marked prog hidden rows cols raw sel ""
searchLoop :: String -> Int -> String -> String -> Int -> Int -> Int -> String -> Int -> String -> IO ()
searchLoop cwd sel marked prog hidden rows cols raw osel acc =
  let msel = searchSel (lines raw) acc osel in do
    info <- selInfo (selPathOf cwd raw msel)
    putStr (render cwd msel marked prog rows raw cols info 0)
    putStr (searchPrompt rows acc)
    searchKey cwd sel marked prog hidden rows cols raw osel acc (readKey 0)
-- First entry containing `acc`, or `dflt` when the query is empty / nothing matches.
searchSel :: List String -> String -> Int -> Int
searchSel xs acc dflt = if strLen acc == 0 then dflt else matchIndex xs acc 0 dflt
-- The "/query" line at the bottom row, cursor shown (mirrors cmdGo's prompt draw).
searchPrompt :: Int -> String -> String
searchPrompt rows acc =
  strAppend (csi (strAppend (showInt rows) ";1H"))
    (strAppend (csi "?25h") (strAppend (csi "K") (strAppend "/" acc)))
searchKey :: String -> Int -> String -> String -> Int -> Int -> Int -> String -> Int -> String -> String -> IO ()
searchKey cwd sel marked prog hidden rows cols raw osel acc k =
  if k == "" then endSearch cwd marked prog hidden rows cols raw acc (searchSel (lines raw) acc osel)
  else if (charAt 0 k == '\r') || (charAt 0 k == '\n') then endSearch cwd marked prog hidden rows cols raw acc (searchSel (lines raw) acc osel)
  else if charAt 0 k == 27 then loop cwd osel marked prog hidden rows cols raw            -- Esc: cancel to original
  else if (charAt 0 k == 127) || (charAt 0 k == 8) then searchLoop cwd sel marked prog hidden rows cols raw osel (dropLast acc)
  else searchLoop cwd sel marked prog hidden rows cols raw osel (strAppend acc k)
-- Confirm: remember the query for `;`/`,`, resume the normal loop at the matched entry (cached raw).
endSearch :: String -> String -> String -> Int -> Int -> Int -> String -> String -> Int -> IO ()
endSearch cwd marked prog hidden rows cols raw acc msel = do
  writeFile (lastqFile 0) (strAppend acc "\n")
  loop cwd msel marked prog hidden rows cols raw
-- index of the first entry containing `q` (fallback to `dflt`).
matchIndex :: List String -> String -> Int -> Int -> Int
matchIndex xs q i dflt = case xs of
  Nil -> dflt
  Cons y ys -> if hasInfix q y then i else matchIndex ys q (i + 1) dflt

------------------------------------------------------------------- sort / filter / search-cycle state

-- Small persisted-state files under ~/.cache/axfm (same idiom as the cell-size cache — avoids
-- threading sort/filter/last-query through every loop/reloop/do* signature).
sortFile :: Int -> String
sortFile d = strAppend (envOr "HOME" ".") "/.cache/axfm/sort"
filterFile :: Int -> String
filterFile d = strAppend (envOr "HOME" ".") "/.cache/axfm/filter"
lastqFile :: Int -> String
lastqFile d = strAppend (envOr "HOME" ".") "/.cache/axfm/lastq"
readFileTrim :: String -> String
readFileTrim path = trim (runCapture (strAppend "cat " (strAppend (shQuote path) " 2>/dev/null")))
readLastQ :: Int -> String
readLastQ d = readFileTrim (lastqFile 0)

------------------------------------------------------------------- runtime bookmarks (`\`` set, `'` jump)

-- Named directory bookmarks persisted to ~/.cache/axfm/bookmarks as `<letter>\t<path>` lines — the
-- runtime complement to the static env favourites (FFF_FAV1-9). All parsing stays in the shell (a
-- while-read over the file) so Axión never juggles the owned key/path split (no leak surface).
bookmarkFile :: Int -> String
bookmarkFile d = strAppend (envOr "HOME" ".") "/.cache/axfm/bookmarks"
-- Set bookmark `letter` → `cwd`: rewrite the file without any prior line for `letter`, then append
-- the new mapping (atomic via a temp + mv). `letter`/`cwd` are shQuoted; the key compare is literal.
markSetCmd :: String -> String -> String
markSetCmd letter cwd =
  strAppend "L=" (strAppend (shQuote letter) (strAppend "; P=" (strAppend (shQuote cwd)
    (strAppend "; f=" (strAppend (shQuote (bookmarkFile 0))
      "; mkdir -p \"${f%/*}\"; t=$(printf '\\t'); tmp=\"$f.$$\"; : > \"$tmp\"; [ -f \"$f\" ] && while IFS=\"$t\" read -r k v; do [ \"$k\" = \"$L\" ] || printf '%s\\t%s\\n' \"$k\" \"$v\"; done < \"$f\" >> \"$tmp\"; printf '%s\\t%s\\n' \"$L\" \"$P\" >> \"$tmp\" && mv \"$tmp\" \"$f\"")))))
markSet :: String -> String -> Int
markSet letter cwd = if strLen letter == 0 then 0 else runStatus (markSetCmd letter cwd)
-- The path bookmarked under `letter`, or "" (empty letter, or no such mark) — the whole lookup is one
-- shell while-read, so the result is a single fresh String (no conditional owned-value move).
markPath :: String -> String
markPath letter =
  if strLen letter == 0 then ""
  else trim (runCapture (strAppend "L=" (strAppend (shQuote letter)
    (strAppend "; f=" (strAppend (shQuote (bookmarkFile 0))
      "; t=$(printf '\\t'); [ -f \"$f\" ] && while IFS=\"$t\" read -r k v; do [ \"$k\" = \"$L\" ] && { printf '%s' \"$v\"; break; }; done < \"$f\"")))))

-- `b` set: prompt, then read ONE key (no Enter) as the mark letter and store cwd under it. An empty
-- key (Esc / EOF) cancels (markSet is a no-op on "").
doSetMark :: String -> Int -> String -> String -> Int -> Int -> IO ()
doSetMark cwd sel marked prog hidden rows = do
  k <- confirmKey "set mark (letter): " rows
  code <- markSet k cwd
  okOr code "set mark failed" rows
  reloop cwd sel marked prog hidden rows
-- `B` jump: prompt, then read ONE key (no Enter) and cd straight to that bookmark — `confirmKey`
-- draws the prompt and returns a single keypress. gotoTo no-ops safely on "" / a non-dir (stale mark
-- or Esc), so a wrong key just stays put.
doJumpMark :: String -> Int -> String -> String -> Int -> Int -> IO ()
doJumpMark cwd sel marked prog hidden rows = do
  k <- confirmKey "jump to mark: " rows
  gotoTo cwd sel marked prog hidden rows (absPath (markPath k))

------------------------------------------------------------------- tabs (`t` new · `T` close · `]`/`[` switch)

-- Multiple working directories, one active at a time — stored OUTSIDE the linear event-loop state (so
-- no extra param threads through every dispatch arm): ~/.cache/axfm/tabs holds the tab cwds one-per-
-- line, ~/.cache/axfm/tabi the 0-based active index. `reloop` (the one choke point for a directory
-- change) rewrites the active tab's line to the new cwd, so a tab always remembers where it was; the
-- tab BAR is folded into the per-frame `selInfo` fork (no new per-frame subprocess). All list surgery
-- stays in POSIX shell — Axión only triggers it and reads back the cwd to cd into.
tabsFile :: Int -> String
tabsFile d = strAppend (envOr "HOME" ".") "/.cache/axfm/tabs"
tabiFile :: Int -> String
tabiFile d = strAppend (envOr "HOME" ".") "/.cache/axfm/tabi"

-- Rewrite the ACTIVE tab's line to `cwd` (creating the file with a single tab when absent). Called
-- by reloop on every directory change — idempotent on a same-dir refresh (resize / post-op redraw).
syncTabCmd :: String -> String
syncTabCmd cwd =
  "P=" ++ shQuote cwd ++ "; f=" ++ shQuote (tabsFile 0) ++ "; i=" ++ shQuote (tabiFile 0)
  ++ "; mkdir -p \"${f%/*}\"; ai=0; [ -r \"$i\" ] && read ai < \"$i\" 2>/dev/null; [ -z \"$ai\" ] && ai=0; "
  ++ "if [ ! -s \"$f\" ]; then printf '%s\\n' \"$P\" > \"$f\"; printf 0 > \"$i\"; else "
  ++ "tmp=\"$f.$$\"; n=0; while IFS= read -r d; do if [ \"$n\" = \"$ai\" ]; then printf '%s\\n' \"$P\"; else printf '%s\\n' \"$d\"; fi; n=$((n+1)); done < \"$f\" > \"$tmp\"; "
  ++ "mv \"$tmp\" \"$f\"; fi"
syncTab :: String -> Int
syncTab cwd = runStatus (syncTabCmd cwd)

-- `t` new tab: duplicate the current dir as a fresh tab and make it active (reloop stays in cwd).
tabNewCmd :: String -> String
tabNewCmd cwd =
  "P=" ++ shQuote cwd ++ "; f=" ++ shQuote (tabsFile 0) ++ "; i=" ++ shQuote (tabiFile 0)
  ++ "; mkdir -p \"${f%/*}\"; [ -s \"$f\" ] || printf '%s\\n' \"$P\" > \"$f\"; "
  ++ "printf '%s\\n' \"$P\" >> \"$f\"; n=$(grep -c '' \"$f\"); printf '%s' \"$((n-1))\" > \"$i\""
doTabNew :: String -> Int -> String -> String -> Int -> Int -> IO ()
doTabNew cwd sel marked prog hidden rows = do
  runStatus (tabNewCmd cwd)
  reloop cwd sel marked prog hidden rows

-- `T` close: drop the active tab (a no-op at one tab), make the previous one active, PRINT its cwd.
tabCloseCmd :: Int -> String
tabCloseCmd d =
  "f=" ++ shQuote (tabsFile 0) ++ "; i=" ++ shQuote (tabiFile 0)
  ++ "; [ -s \"$f\" ] || exit 0; n=$(grep -c '' \"$f\"); [ \"$n\" -le 1 ] && exit 0; "
  ++ "ai=0; [ -r \"$i\" ] && read ai < \"$i\"; [ -z \"$ai\" ] && ai=0; "
  ++ "tmp=\"$f.$$\"; k=0; while IFS= read -r dd; do [ \"$k\" = \"$ai\" ] || printf '%s\\n' \"$dd\"; k=$((k+1)); done < \"$f\" > \"$tmp\"; mv \"$tmp\" \"$f\"; "
  ++ "ni=$ai; [ \"$ni\" -ge \"$((n-1))\" ] && ni=$((n-2)); printf '%s' \"$ni\" > \"$i\"; sed -n \"$((ni+1))p\" \"$f\""
doTabClose :: String -> Int -> String -> String -> Int -> Int -> IO ()
doTabClose cwd sel marked prog hidden rows = do
  dest <- runCapture (tabCloseCmd 0)
  gotoTo cwd sel marked prog hidden rows (absPath (trim dest))

-- `]`/`[` switch: rotate the active index by `delta` (wrapping), PRINT the newly-active tab's cwd.
tabGoCmd :: String -> String
tabGoCmd delta =
  "f=" ++ shQuote (tabsFile 0) ++ "; i=" ++ shQuote (tabiFile 0)
  ++ "; [ -s \"$f\" ] || exit 0; n=$(grep -c '' \"$f\"); ai=0; [ -r \"$i\" ] && read ai < \"$i\"; [ -z \"$ai\" ] && ai=0; "
  ++ "ni=$(( (ai + " ++ delta ++ " + n) % n )); printf '%s' \"$ni\" > \"$i\"; sed -n \"$((ni+1))p\" \"$f\""
tabSwitch :: String -> Int -> String -> String -> Int -> Int -> String -> IO ()
tabSwitch cwd sel marked prog hidden rows delta = do
  dest <- runCapture (tabGoCmd delta)
  gotoTo cwd sel marked prog hidden rows (absPath (trim dest))
doTabNext :: String -> Int -> String -> String -> Int -> Int -> IO ()
doTabNext cwd sel marked prog hidden rows = tabSwitch cwd sel marked prog hidden rows "1"
doTabPrev :: String -> Int -> String -> String -> Int -> Int -> IO ()
doTabPrev cwd sel marked prog hidden rows = tabSwitch cwd sel marked prog hidden rows "-1"

-- `o` cycles the ls sort flag name → size → mtime → name, re-lists via reloop.
nextSort :: String -> String
nextSort s = if s == "-S" then "-t" else if s == "-t" then "" else "-S"
doSort :: String -> Int -> String -> String -> Int -> Int -> IO ()
doSort cwd sel marked prog hidden rows = do
  writeFile (sortFile 0) (strAppend (nextSort (readFileTrim (sortFile 0))) "\n")
  reloop cwd sel marked prog hidden rows
-- `F` prompts for a filter substring (empty clears it), re-lists so only matches show.
doFilter :: String -> Int -> String -> String -> Int -> Int -> IO ()
doFilter cwd sel marked prog hidden rows = do
  q <- cmdLine "filter> " rows cwd
  writeFile (filterFile 0) (strAppend q "\n")
  reloop cwd 0 marked prog hidden rows

-- First index >= lo whose entry matches `q`, else -1 (linear, matchIndex-style). stripSlash so a
-- dir "foo/" matches "foo". `lines raw` is re-split fresh per pass → each list is owned+consumed.
matchFrom :: List String -> String -> Int -> Int -> Int
matchFrom xs q i lo = case xs of
  Nil -> 0 - 1
  Cons y ys -> if i >= lo && hasInfix q (stripSlash y) then i else matchFrom ys q (i + 1) lo
-- Highest matching index < hi, else -1 (tracks the best match in one forward pass).
matchBefore :: List String -> String -> Int -> Int -> Int -> Int
matchBefore xs q i hi best = case xs of
  Nil -> best
  Cons y ys -> matchBefore ys q (i + 1) hi (if i < hi && hasInfix q (stripSlash y) then i else best)
-- `;` next match (after sel, wrapping to the top); `,` previous (before sel, wrapping to the
-- bottom). Operate on the cached `raw` — no re-list. Empty query (no prior `/`) → stay put.
searchNext :: String -> String -> Int -> Int
searchNext raw q from =
  if strLen q == 0 then from
  else nextOrTop raw q from (matchFrom (lines raw) q 0 (from + 1))
nextOrTop :: String -> String -> Int -> Int -> Int
nextOrTop raw q from a = if a >= 0 then a else topMatch raw q from
topMatch :: String -> String -> Int -> Int
topMatch raw q from = clampNeg (matchFrom (lines raw) q 0 0) from
searchPrev :: String -> String -> Int -> Int
searchPrev raw q from =
  if strLen q == 0 then from
  else prevOrBottom raw q from (matchBefore (lines raw) q 0 from (0 - 1))
prevOrBottom :: String -> String -> Int -> Int -> Int
prevOrBottom raw q from a = if a >= 0 then a else bottomMatch raw q from
bottomMatch :: String -> String -> Int -> Int
bottomMatch raw q from = clampNeg (matchBefore (lines raw) q 0 (countLines raw) (0 - 1)) from
-- a match index, or `from` when there was none (-1).
clampNeg :: Int -> Int -> Int
clampNeg a from = if a >= 0 then a else from
-- does `s` contain `q` as a substring?
hasInfix :: String -> String -> Bool
hasInfix q s = infixGo q s 0 (strLen s - strLen q)
infixGo :: String -> String -> Int -> Int -> Bool
infixGo q s i lim =
  if i > lim then False
  else if q == substr i (strLen q) s then True
  else infixGo q s (i + 1) lim

-- `x` attributes: run stat, show it, wait for a key, redraw.
doAttr :: String -> Int -> String -> String -> Int -> Int -> IO ()
doAttr cwd sel marked prog hidden rows = do
  putStr resetSeq
  putStr (runCapture (strAppend "stat -- " (shQuote (selPath cwd hidden sel))))
  putStr "\n[any key]"
  readKey 0
  putStr setupSeq
  reloop cwd sel marked prog hidden rows

-- `X` toggle the executable bit.
doChmod :: String -> Int -> String -> String -> Int -> Int -> IO ()
doChmod cwd sel marked prog hidden rows = do
  code <- runStatus (strAppend (if isExecPath (selPath cwd hidden sel) then "chmod -x -- " else "chmod +x -- ")
              (strAppend (shQuote (selPath cwd hidden sel)) errRedir))
  okOrErr code "chmod failed" rows
  reloop cwd sel marked prog hidden rows
isExecPath :: String -> Bool
isExecPath p = runStatus (strAppend "test -x " (shQuote p)) == 0

-- `p` paste: run the pending program over every marked path into cwd (trash = move to trash dir).
-- TRASH is irreversible, so it asks y/N first (covers the D-then-p "trash the whole dir" mistake);
-- a No keeps the marks + redraws. cp/mv/ln are non-destructive (and -i guards overwrites) → no
-- prompt. The y/N answer is threaded as a Bool param (not an effect inside the `if` condition).
doPaste :: String -> Int -> String -> String -> Int -> Int -> IO ()
doPaste cwd sel marked prog hidden rows =
  if markCount marked == 0
  then doPasteRun cwd sel marked prog hidden rows
  else pasteIfYes cwd sel marked prog hidden rows (pasteConfirmed cwd marked prog rows)
-- Whether to proceed with the paste: trash always asks (irreversible); cp/mv ask ONLY when a marked
-- name would OVERWRITE an existing entry in cwd (the -i flags were dropped — they prompt invisibly
-- in the TUI); ln and a collision-free cp/mv proceed silently. Returns a Bool threaded into pasteIfYes.
pasteConfirmed :: String -> String -> String -> Int -> Bool
pasteConfirmed cwd marked prog rows =
  if prog == "trash" then confirm (trashPrompt (markCount marked)) rows
  else if anyCollide cwd marked then confirm "overwrite existing file(s)? [y/N] " rows
  else True
-- Does any marked entry's basename already exist in cwd? (one fork — a shell loop; exit 0 on the
-- first collision). cp -R / mv would clobber it, so pasteConfirmed asks first.
anyCollide :: String -> String -> Bool
anyCollide cwd marked =
  runStatus (strAppend "d=" (strAppend (shQuote cwd)
    (strAppend "; for src in " (strAppend (quoteLines marked)
      "; do [ -e \"$d/$(basename -- \"$src\")\" ] && exit 0; done; exit 1")))) == 0
pasteIfYes :: String -> Int -> String -> String -> Int -> Int -> Bool -> IO ()
pasteIfYes cwd sel marked prog hidden rows yes =
  if yes then doPasteRun cwd sel marked prog hidden rows
  else reloop cwd sel marked prog hidden rows
doPasteRun :: String -> Int -> String -> String -> Int -> Int -> IO ()
doPasteRun cwd sel marked prog hidden rows = do
  putStr (workMsg prog (markCount marked) rows)
  code <- (if markCount marked > 0 then runPaste cwd marked prog else 0)
  okOrErr code "paste failed" rows
  reloop cwd (clampSel sel (nEntries cwd hidden + markCount marked)) "" "" hidden rows
trashPrompt :: Int -> String
trashPrompt n = strAppend "trash " (strAppend (showInt n) " item(s)? [y/N] ")
-- trash = move each marked path into the trash dir with a COLLISION-SAFE name: if `$d/<base>`
-- exists, try `<base>.1`, `.2`, … so trashing two files of the same name never silently overwrites
-- (the old `mv -f` did). No `-f`; each source keeps a distinct, recoverable name.
runPaste :: String -> String -> String -> Int
runPaste cwd marked prog =
  if prog == "trash"
  then runStatus (strAppend "d=" (strAppend (shQuote (trashDir 0))
         (strAppend "; L=\"$HOME/.cache/axfm/trashlog\"; mkdir -p \"$d\" \"${L%/*}\" && for src in " (strAppend (quoteLines marked)
           (strAppend "; do b=${src##*/}; dest=\"$d/$b\"; n=1; while [ -e \"$dest\" ]; do dest=\"$d/$b.$n\"; n=$((n+1)); done; mv -- \"$src\" \"$dest\" && printf '%s\\t%s\\n' \"$dest\" \"$src\" >> \"$L\"; done" errRedir)))))
  else runStatus (strAppend prog (strAppend " -- " (strAppend (quoteLines marked) (strAppend " " (strAppend (shQuote cwd) errRedir)))))
trashDir :: Int -> String
trashDir d = strAppend (envOr "HOME" ".") "/.local/share/axfm/trash"

-- `u` undo-trash: restore the most-recently-trashed file to its ORIGINAL location. Trashing appends
-- a `<trash-dest>\t<orig-path>` line to ~/.cache/axfm/trashlog; restore reads the LAST line, moves
-- the file back (recreating the parent dir if needed), and pops that line. Nothing to restore (empty
-- log) or an already-gone trash file is a silent no-op (exit 0); only a real `mv` failure flashes.
doRestore :: String -> Int -> String -> String -> Int -> Int -> IO ()
doRestore cwd sel marked prog hidden rows = do
  code <- runStatus (restoreCmd 0)
  okOrErr code "restore failed" rows
  reloop cwd sel marked prog hidden rows
restoreCmd :: Int -> String
restoreCmd d =
  strAppend "l=\"$HOME/.cache/axfm/trashlog\"; [ -s \"$l\" ] || exit 0; last=$(tail -n1 \"$l\"); t=$(printf '\\t'); dest=${last%%$t*}; orig=${last#*$t}; rc=0; if [ -e \"$dest\" ]; then mkdir -p \"${orig%/*}\" && mv -- \"$dest\" \"$orig\" || rc=1; fi; sed -i '$ d' \"$l\"; exit $rc" errRedir
-- Shell-quote each newline-joined path and space-join them.
quoteLines :: String -> String
quoteLines m = qlGo (filter nonEmpty (lines m))
qlGo :: List String -> String
qlGo xs = case xs of
  Nil -> ""
  Cons y ys -> strAppend (shQuote y) (strAppend " " (qlGo ys))

-- `R` bulk-rename: write marked basenames to a temp, open $EDITOR, read back, rename each changed.
doBulk :: String -> Int -> String -> String -> Int -> Int -> IO ()
doBulk cwd sel marked prog hidden rows = do
  fails <- (if markCount marked > 0 then bulkRun cwd marked (bulkTmp 0) else 0)
  okOr fails "bulk-rename: some renames failed" rows
  reloop cwd (clampSel sel (nEntries cwd hidden)) "" "" hidden rows
bulkTmp :: Int -> String
bulkTmp d = strAppend "/tmp/axfm-bulk-" (randHex 8)
-- Returns the number of renames that FAILED (0 = all ok), surfaced by doBulk.
bulkRun :: String -> String -> String -> Int
bulkRun cwd marked tmp = do
  writeFile tmp (baseNames marked)
  putStr resetSeq
  runStatus (strAppend (editorCmd 0) (strAppend " " (shQuote tmp)))
  fails <- bulkApply (filter nonEmpty (lines marked)) (filter nonEmpty (lines (readFile tmp))) cwd
  putStr setupSeq
  removeFile tmp
  fails
-- basenames of the marked paths, one per line.
baseNames :: String -> String
baseNames m = bnGo (filter nonEmpty (lines m))
bnGo :: List String -> String
bnGo xs = case xs of
  Nil -> ""
  Cons y ys -> strAppend (baseName y) (strAppend "\n" (bnGo ys))
-- rename olds[i] → cwd/news[i] for each pair where they differ; returns the count of FAILED
-- renames (a non-zero renameFile exit) so doBulk can report partial failure.
bulkApply :: List String -> List String -> String -> Int
bulkApply olds news cwd = case olds of
  Nil -> 0
  Cons o os -> case news of
    Nil -> 0
    Cons n ns -> do
      rc <- (if o == cwd </> n then 0 else renameFile o (cwd </> n))
      (if rc == 0 then 0 else 1) + bulkApply os ns cwd

-- `!` spawn $SHELL in cwd.
doShell :: String -> Int -> String -> String -> Int -> Int -> IO ()
doShell cwd sel marked prog hidden rows = do
  putStr resetSeq
  runStatus (strAppend "cd " (strAppend (shQuote cwd) (strAppend " && " (envOr "SHELL" "sh"))))
  putStr setupSeq
  reloop cwd sel marked prog hidden rows

-- A config `!cmd` binding: run `cmd` SILENTLY in cwd (output suppressed so it can't corrupt the TUI),
-- then re-list (the command may have changed the directory). `%s` → the selected entry's path. The
-- path is bound once to shell var `f` (shQuoted); `%s` is rewritten to `"$f"` so spaces are safe and
-- the config value needs no quotes. The `{ …; }` group lets a redirect inside the command still work.
doUserCmd :: String -> Int -> String -> String -> Int -> Int -> Int -> String -> String -> IO ()
doUserCmd cwd sel marked prog hidden rows cols raw cmd = do
  runStatus (userCmd cwd raw sel cmd)
  reloop cwd sel marked prog hidden rows
userCmd :: String -> String -> Int -> String -> String
userCmd cwd raw sel cmd =
  strAppend "cd " (strAppend (shQuote cwd)
    (strAppend " && f=" (strAppend (shQuote (selPathOf cwd raw sel))
      (strAppend "; { " (strAppend (substPct cmd "\"$f\"") " ; } >/dev/null 2>&1")))))

-- A config `!!cmd` binding: run `cmd` INTERACTIVELY, on the real terminal, for commands that PROMPT
-- (e.g. `sudo`, a `zfs`/`zpool` passphrase, `ssh`). Unlike the silent `!cmd`, this leaves the alt-screen
-- (`resetSeq`) so the command's stdin/stdout/stderr are the terminal — the password/passphrase prompt
-- shows and you can type it — then redraws (`setupSeq` + reloop). `%s` → the selected path as before.
doUserCmdTty :: String -> Int -> String -> String -> Int -> Int -> String -> String -> IO ()
doUserCmdTty cwd sel marked prog hidden rows raw cmd = do
  putStr resetSeq
  runStatus (userCmdTty cwd raw sel cmd)
  putStr setupSeq
  reloop cwd sel marked prog hidden rows
-- Like `userCmd` but NO `>/dev/null 2>&1` redirect (and no `{ }` wrapper) — the child inherits the tty.
userCmdTty :: String -> String -> Int -> String -> String
userCmdTty cwd raw sel cmd =
  strAppend "cd " (strAppend (shQuote cwd)
    (strAppend " && f=" (strAppend (shQuote (selPathOf cwd raw sel))
      (strAppend "; " (substPct cmd "\"$f\"")))))

------------------------------------------------------------------- multi-action bindings (lists / named functions)

-- The pending-actions queue: a newline-separated list of action items (built-in NAMES or `!cmd`). A
-- multi-action binding queues its items here; `drainOrWait` pops one per event-loop frame. Lives
-- OUTSIDE the tail-recursive loop state (same file-backed pattern as the keymap / tabs).
pendingFile :: Int -> String
pendingFile d = strAppend (envOr "HOME" ".") "/.cache/axfm/pending"

-- Text up to (not incl.) the first newline, and the remainder after it.
firstLine :: String -> String
firstLine s = let i = nlIdx s in if i < 0 then dup s else substr 0 i s
dropFirstLine :: String -> String
dropFirstLine s = let i = nlIdx s in if i < 0 then "" else substr (i + 1) (strLen s - i - 1) s
nlIdx :: String -> Int
nlIdx s = nlScan s 0
nlScan :: String -> Int -> Int
nlScan s i = if i >= strLen s then (0 - 1) else if charAt i s == '\n' then i else nlScan s (i + 1)

-- Pop the first queued item: rewrite the file without it (the write runs — strict arg — before the
-- popped item is returned), and return that item.
popItem :: Int -> String
popItem d =
  let q = readFile (pendingFile 0) in
  forceWrite (writeFile (pendingFile 0) (dropFirstLine q)) (firstLine q)
forceWrite :: Int -> String -> String
forceWrite d s = s

-- Run one queued item: a `!cmd` shell command, or a built-in action by NAME (resolved to its canonical
-- key and dispatched). An unknown name is skipped (just redraw so the drain continues).
runItem :: String -> Int -> String -> String -> Int -> Int -> Int -> String -> String -> IO ()
runItem cwd sel marked prog hidden rows cols raw item =
  if hasPrefix "!!" item                                          -- `!!cmd` = interactive shell command
  then doUserCmdTty cwd sel marked prog hidden rows raw (substr 2 (strLen item - 2) item)
  else if hasPrefix "!" item                                      -- `!cmd` = silent shell command
  then doUserCmd cwd sel marked prog hidden rows cols raw (substr 1 (strLen item - 1) item)
  else if hasPrefix "cd " item                                    -- `cd <path>` = navigate to that dir
  then gotoDir cwd (substr 3 (strLen item - 3) item) sel marked prog hidden rows
  else runBuiltin cwd sel marked prog hidden rows cols raw (actionKey item)
runBuiltin :: String -> Int -> String -> String -> Int -> Int -> Int -> String -> String -> IO ()
runBuiltin cwd sel marked prog hidden rows cols raw k =
  if strLen k == 0 then loop cwd sel marked prog hidden rows cols raw
  else step cwd sel marked prog hidden rows cols raw k

-- A multi-action binding fired: PREPEND its items (the tab-joined keymap value, converted to one item
-- per line) to the queue, then re-enter the loop so `drainOrWait` runs them in order. The length cap
-- stops a self/cyclic-referential function from growing the queue without bound.
doRunList :: String -> Int -> String -> String -> Int -> Int -> Int -> String -> String -> IO ()
doRunList cwd sel marked prog hidden rows cols raw items = do
  writeFile (pendingFile 0) (enqueueItems (tabToNl items) (readFile (pendingFile 0)))
  loop cwd sel marked prog hidden rows cols raw
enqueueItems :: String -> String -> String
enqueueItems new old = if strLen old > 4096 then dup old else strAppend new (strAppend "\n" old)
-- Replace every tab (the keymap's item separator) with a newline (the queue's).
tabToNl :: String -> String
tabToNl s = t2n s 0
t2n :: String -> Int -> String
t2n s i =
  if i >= strLen s then ""
  else if charAt i s == '\t' then strAppend "\n" (t2n s (i + 1))
  else strAppend (substr i 1 s) (t2n s (i + 1))

-- `?` help: clear the screen, list the key bindings, wait for any key, redraw. Kept in-app (no
-- $EDITOR/pager) so it works everywhere; imgClearSeq wipes any kitty image under it first.
helpText :: String
helpText =
  "  axfm — key bindings\n\n"
  ++ "  j k  (or arrows)  move cursor        g / G   top / bottom\n"
  ++ "  l  Enter  (or ->) open               h  (or <-)  parent dir\n"
  ++ "  J / K             scroll preview      .       toggle hidden\n"
  ++ "  /  search (live)   ; / ,  next / prev match    o  cycle sort\n"
  ++ "  F  filter          :  go to dir       ~ home    -  previous dir\n"
  ++ "  n  mkdir           f  mkfile          r  rename   e  refresh\n"
  ++ "  x  attributes      X  toggle +x       i  size (du)\n"
  ++ "  b  set bookmark      B  jump to bookmark        1-9  favourites\n"
  ++ "  t  new tab           T  close tab      ] / [  next / prev tab\n"
  ++ "  <N> j/k/G  repeat / go to line N (count prefix)\n"
  ++ "  y m s d  mark for cp / mv / ln / trash           c  clear marks\n"
  ++ "  Y M S D  mark ALL for the same        p  paste    u  undo trash\n"
  ++ "  P  copy path        R  bulk-rename     !  shell    q  quit\n\n"
  ++ "  keys are remappable in ~/.config/axfm/config.lua\n\n"
  ++ "  press any key to close"
doHelp :: String -> Int -> String -> String -> Int -> Int -> IO ()
doHelp cwd sel marked prog hidden rows = do
  putStr (strAppend imgClearSeq (strAppend homeClear helpText))
  readKey 0
  reloop cwd sel marked prog hidden rows

-- `P` copy the selected entry's FULL PATH to the clipboard (wl-copy, else xclip, else xsel). The
-- path is not a secret → shQuoted into the command and fed on stdin via `printf %s` (no trailing
-- newline). Returns non-zero only if NO clipboard tool exists (→ a flash); success is silent.
copyToClip :: String -> Int
copyToClip path =
  runStatus (strAppend "p=" (strAppend (shQuote path)
    "; printf %s \"$p\" | { wl-copy 2>/dev/null || xclip -selection clipboard 2>/dev/null || xsel -b 2>/dev/null; }"))
doCopyPath :: String -> Int -> String -> String -> Int -> Int -> Int -> String -> IO ()
doCopyPath cwd sel marked prog hidden rows cols raw = do
  code <- copyToClip (selPathOf cwd raw sel)
  okOr code "no clipboard tool (install wl-clipboard, xclip, or xsel)" rows
  loop cwd sel marked prog hidden rows cols raw

-- `q`: restore the terminal and write cwd to the cd-file (for a shell wrapper's `cd` on exit).
quit :: String -> IO ()
quit cwd = do
  writeFile (cdFile 0) (strAppend cwd "\n")
  runStatus "test -t 0 && stty sane 2>/dev/null"
  putStr resetSeq
cdFile :: Int -> String
cdFile d = strAppend (envOr "HOME" ".") "/.cache/axfm/axfm.d"

------------------------------------------------------------------- entry point

-- Start dir, resolved to an ABSOLUTE path. Without this, launching with no arg leaves cwd = "."
-- (relative) and `h` computes `dirName "." = "."` forever — you can never ascend to the parent /
-- home. `cd -- "$d" && pwd` canonicalises "." or any relative arg to absolute (falling back in-shell
-- to the original if `cd` fails), so `dirName` can walk all the way up.
-- Parent directory, root-aware: the prelude `dirName` returns "" at depth 1 ("/home" → ""), which
-- would list the empty path; keep you at "/" instead. "/" → "/" (can't go above root). `rootIfEmpty`
-- returns a FRESH copy in the else arm (dup, not the bare param) so nothing is conditionally moved.
parentDir :: String -> String
parentDir s = rootIfEmpty (dirName s)
rootIfEmpty :: String -> String
rootIfEmpty d = if strLen d == 0 then "/" else dup d
startDir :: String -> String
startDir a = absPath (startDirRaw a)
startDirRaw :: String -> String
startDirRaw a = if strLen a == 0 then "." else dup a
absPath :: String -> String
absPath d =
  trim (runCapture (strAppend "cd -- " (strAppend (shQuote d)
    (strAppend " 2>/dev/null && pwd || printf %s " (shQuote d)))))

-- Ask the terminal its text-area pixel size (`\e[14t` → `\e[4;H;Wt`), divide by `stty size` to get
-- the real CELL pixel size, and cache "cw ch" in ~/.cache/axfm/cell for sixelRenderSrc to size images
-- exactly (no font guessing → tall photos can't overflow the pane). Run ONCE at startup, before the
-- key loop, so the reply is the only pending input (never eats a keystroke); a 0.1s stty timeout and
-- a non-tty/pipe both no-op, leaving the 7x14 fallback. Reads from a fresh /dev/tty fd, not stdin.
queryCell :: Int -> String
queryCell d =
  -- CACHED: the cell size is constant for a terminal, so probe only when ~/.cache/axfm/cell is missing/
  -- empty. Every later launch skips the `\e[14t` round-trip + the two `stty` toggles + the `dd` read.
  strAppend "[ -s \"$HOME/.cache/axfm/cell\" ] && exit 0; "
   (strAppend "command -v stty >/dev/null 2>&1 || exit 0; { exec 3</dev/tty; } 2>/dev/null || exit 0; "
    (strAppend "old=$(stty -g <&3) || exit 0; stty raw -echo min 0 time 1 <&3; printf '\\033[14t' >/dev/tty; "
      (strAppend "r=$(dd bs=64 count=1 <&3 2>/dev/null); stty \"$old\" <&3; "
        (strAppend "hw=$(printf %s \"$r\"|sed -n 's/.*4;\\([0-9]*\\);\\([0-9]*\\)t.*/\\1 \\2/p'); set -- $hw; "
          (strAppend "[ -n \"${1:-}\" ] && [ -n \"${2:-}\" ] || exit 0; sz=$(stty size <&3 2>/dev/null); rr=${sz%% *}; cc=${sz##* }; "
            "[ \"${rr:-0}\" -gt 0 ] && [ \"${cc:-0}\" -gt 0 ] || exit 0; cw=$(( $2 / cc )); ch=$(( $1 / rr )); [ \"$cw\" -gt 0 ] && [ \"$ch\" -gt 0 ] || exit 0; printf '%s %s' \"$cw\" \"$ch\" > \"$HOME/.cache/axfm/cell\"")))))

main :: IO ()
main = do
  makeDir (strAppend (envOr "HOME" ".") "/.cache/axfm")
  -- Probe stdout-tty + the pixel renderer ONCE (constant for the run); onTty/pickRenderer then read
  -- the cached result fork-free (onTty is on the per-keystroke frame-path).
  writeCaps 0
  -- Parse ~/.config/axfm/config.lua into the keymap + colours caches — ONE fork (buildConfig) instead of
  -- two (fewer startup forks → faster launch); empty caches when there is no config.
  buildConfig 0
  -- ONE fork for the independent startup side-effects: clear transient view state (leftover filter/search/
  -- tabs/pending — a new session starts unfiltered, though the sort preference IS kept) AND put the
  -- terminal in -echo -icanon for the session (readKey saves/restores around each read; keeps echo OFF
  -- between reads so keys typed during a render aren't echoed as `^[[A`).
  runStatus (strAppend "rm -f " (strAppend (shQuote (filterFile 0)) (strAppend " " (strAppend (shQuote (lastqFile 0)) (strAppend " " (strAppend (shQuote (tabsFile 0)) (strAppend " " (strAppend (shQuote (tabiFile 0)) (strAppend " " (strAppend (shQuote (pendingFile 0)) "; test -t 0 && stty -echo -icanon 2>/dev/null"))))))))))
  runStatus (queryCell 0)
  putStr setupSeq
  reloop (startDir (getArg 0)) 0 "" "" 0 (termRows 0)
