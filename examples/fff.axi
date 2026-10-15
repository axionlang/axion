-- fff.axi — a rewrite of `fff` (dylanaraps/fff, "fucking fast file-manager") in Axión.
-- The third flagship: a scrolling, colored, marked-files file manager with a full command line.
-- GC-free + memory-safe by construction; runs identically on interp / --dev / --release.
--
-- Keys (fff defaults): j/k or ↓/↑ move · g/G top/bottom · l/→/Enter open · h/← parent
--   . toggle hidden · e refresh · - previous dir · ~ home · 1-9 favourites (FFF_FAV<n>) · : go dir
--   / search (incremental — jumps as you type; Enter confirm, Esc cancel) · ; / , next / prev match
--   o cycle sort (name/size/mtime) · F filter
--   J/K scroll the preview (text/dir/archive)
--   ! shell · n mkdir · f mkfile · r rename · x attributes(stat) · X chmod±x
--   y/m/s/d mark (cp/mv/ln/trash) · Y/M/S/D mark all · c clear marks · p paste (trash asks y/N)
--   u undo-trash (restore last trashed) · b bulk-rename · q quit
--
-- Live preview: a split pane (right half) previews the SELECTED entry as the cursor moves —
--   directories as an `ls`, text as `head`, binaries as a `file` description. IMAGES render as real
--   pixels via the terminal graphics protocol (`kitten icat`, else `img2sixel`); VIDEOS render an
--   extracted frame (ffmpegthumbnailer, else ffmpeg) the same way. Rendered sixels + video thumbnails
--   are cached under ~/.cache/fff so a revisit is instant. With no graphics tool a textual header +
--   hint is shown instead. The pane drops to a full-width list on a narrow terminal.
-- Usage: source scripts/fff-wrapper.sh from your shell rc and run `fff [DIR]`. The wrapper gives
--   cd-on-quit (fff writes its last dir to ~/.cache/fff/fff.d; a child can't cd its parent shell)
--   AND a `trap` that always restores the terminal — Axión has no signal handlers, so without it a
--   SIGINT/SIGTERM/kill or crash would leave the alt-screen up with echo off (a clean q/EOF resets).
-- Honest scope vs fff: colors are type-based (dir vs file, cursor reverse) not full LS_COLORS;
-- Axión has no SIGWINCH, so a resize is caught by POLLING `stty size` every 500 ms while idle (on a
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
esc = "\e"

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
-- the active filter are read from ~/.cache/fff/{sort,filter} IN THE SAME subshell (no extra fork):
-- $o appends an ls sort flag (""=name, -S=size, -t=mtime), and a non-empty $fq pipes the listing
-- through `grep -iF` so the whole view (and every op derived from it) filters consistently.
lsCmd :: String -> Int -> String
lsCmd cwd hidden =
  strAppend "o=''; [ -r \"$HOME/.cache/fff/sort\" ] && read o < \"$HOME/.cache/fff/sort\" 2>/dev/null; fq=''; [ -r \"$HOME/.cache/fff/filter\" ] && read fq < \"$HOME/.cache/fff/filter\" 2>/dev/null; "
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
drawRows :: List String -> Int -> Int -> Int -> Int -> String -> String -> Int -> Bool -> String
drawRows xs i start endIdx sel marked cwd listW prev = case xs of
  Nil -> ""
  Cons y ys ->
    if (i >= start) && (i < endIdx)
    then strAppend (rowFor y i sel marked cwd listW prev)
           (drawRows ys (i + 1) start endIdx sel marked cwd listW prev)
    else drawRows ys (i + 1) start endIdx sel marked cwd listW prev

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
  else if charAt i s == '\e'
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
spaces :: Int -> String
spaces n = if n <= 0 then "" else strAppend " " (spaces (n - 1))
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

-- SGR color for an entry: dirs blue; else by extension group (image/video magenta, audio cyan,
-- archive red, doc yellow, code green), "" (default) otherwise. LS_COLORS-ish, extend the lists freely.
entryColor :: String -> String
entryColor raw =
  if hasSuffix "/" raw then "1;34" else colorForExt (extOf raw)
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

-- A list row is just its colored fixed-width cell + newline. The pane separator is NOT appended per
-- row (that left gaps on rows with no entry) — it is drawn as one continuous line by `drawSep`.
rowFor :: String -> Int -> Int -> String -> String -> Int -> Bool -> String
rowFor raw i sel marked cwd listW prev =
  colorCell (sizedCell (markChar marked (cwd </> stripSlash raw) ++ " " ++ dup raw) listW prev)
            i sel (entryColor raw)
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
statusLine :: String -> Int -> Int -> String -> String -> Int -> String -> String
statusLine cwd total sel marked prog rows info =
  strAppend (csi (strAppend (showInt (rows - 1)) ";1H"))
    (paint "7"
      (strAppend (posStr sel total)
        (strAppend (markSeg marked prog)
          (strAppend (metaSeg info)
            (strAppend " " cwd)))))

------------------------------------------------------------------- preview pane (pure content)

-- Is a graphics renderer USABLE in this terminal? (Defined below; "" means none → text + hint.)
hasImgTool :: Int -> Bool
hasImgTool d = strLen (pickRenderer 0) > 0

-- The selected entry's PATH derived from an ALREADY-captured `ls` output (pure `lines`, no new fork)
-- — the hot-path twin of selPath, so a frame lists the directory once and reuses it.
selPathOf :: String -> String -> Int -> String
selPathOf cwd raw sel = cwd </> stripSlash (pick sel (lines raw))
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
    "; file -bL --mime-type -- \"$f\" 2>/dev/null; o=$(stat -c '%s|%y' -- \"$f\" 2>/dev/null); s=${o%%|*}; t=${o#*|}; t=${t%%.*}; h=$(printf %s \"$s\" | numfmt --to=iec 2>/dev/null); printf '%s\\n%s\\n' \"${h:-$s}\" \"$t\""))
infoMime :: String -> String
infoMime info = trim (pick 0 (lines info))
infoSize :: String -> String
infoSize info = trim (pick 1 (lines info))
infoMtime :: String -> String
infoMtime info = trim (pick 2 (lines info))

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
  then drawLines (lines (runCapture (strAppend "ls -p --group-directories-first -- "
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

-- Is our stdout a real terminal? (Images are skipped on a pipe — e.g. the headless test harness.)
onTty :: Int -> Bool
onTty d = runStatus "test -t 1" == 0

-- Are we in a kitty-protocol terminal? (kitty sets KITTY_WINDOW_ID; $TERM is usually xterm-kitty.)
isKitty :: Int -> Bool
isKitty d = (strLen (getEnv "KITTY_WINDOW_ID") > 0) || (hasInfix "kitty" (getEnv "TERM"))
-- Is `cmd` on PATH?
have :: String -> Bool
have cmd = runStatus (strAppend "command -v " (strAppend cmd " >/dev/null 2>&1")) == 0

-- Pick a renderer by TERMINAL first, then tool availability (tool-presence ≠ protocol support):
-- kitty's native protocol only inside kitty; otherwise libsixel (sixel works in foot/xterm/wezterm/
-- recent kitty — a safe universal fallback). "" when nothing usable is installed.
pickRenderer :: Int -> String
pickRenderer d =
  if (isKitty 0) && (have "kitten") then "kitten"
  else if have "img2sixel" then "img2sixel"
  else ""

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
-- pwc x phc CELLS times the terminal's actual cell size read from ~/.cache/fff/cell (written once at
-- startup by `\e[14t`; falls back to 7x14 if absent). img2sixel preserves aspect from a SINGLE
-- dimension, so we pick the BINDING one from the image's own WxH (via `identify`, else `file`'s
-- LARGEST NxN — real JPEGs print a bogus `density 1x1` before the true size, so take max-width not
-- first): a portrait photo binds on HEIGHT so it can't overflow downward and scroll the list (the
-- bug), a wide one binds on width. CACHED under ~/.cache/fff/sixel by (src md5, box px) + mtime, so
-- decoding happens once (~200ms) and every revisit `cat`s the ~60K (~3ms); dim/cell probes run only
-- on a cache miss. Box in real px = exact pane rows, so height never exceeds the pane → no scroll.
-- The cache-key + miss-decode core, assuming $src is already set. Emits the cell-size read, the
-- W/H box-px math, k=~/.cache/fff/sixel/<md5(src)>_${W}x${H}.six, and (only on a miss / stale
-- mtime) the img2sixel decode into a PID-unique temp then an atomic `mv`. No `cat`, no cursor
-- move — shared VERBATIM by the foreground sixelRenderSrc and the background prefetch so the key
-- / box px / mtime logic can never drift between warming a neighbour and later reading it.
sixelDecode :: Int -> Int -> String
sixelDecode pwc phc =
  strAppend "cw=7; ch=14; [ -r \"$HOME/.cache/fff/cell\" ] && read cw ch < \"$HOME/.cache/fff/cell\"; W=$(( " (strAppend (showInt pwc)
   (strAppend " * ${cw:-7} )); H=$(( " (strAppend (showInt phc)
   " * ${ch:-14} )); k=\"$HOME/.cache/fff/sixel/$(printf %s \"$src\"|md5sum|cut -c1-32)_${W}x${H}.six\"; mkdir -p \"${k%/*}\"; if [ ! -f \"$k\" ] || [ \"$src\" -nt \"$k\" ]; then dim=$(identify -format '%wx%h' \"$src\"[0] 2>/dev/null); [ -n \"$dim\" ] || dim=$(file -bL -- \"$src\" 2>/dev/null|grep -oE '[0-9]+ ?x ?[0-9]+'|tr -d ' '|sort -t x -k1,1n|tail -1); iw=${dim%x*}; ih=${dim#*x}; if [ -n \"$dim\" ] && [ \"$((iw*H))\" -ge \"$((ih*W))\" ]; then f=\"-w $W\"; else f=\"-h $H\"; fi; [ -n \"$dim\" ] || f=\"-w $W\"; img2sixel $f -- \"$src\" >\"$k.$$.t\" 2>/dev/null && mv \"$k.$$.t\" \"$k\"; fi"
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
-- VIDEO: extract a representative frame (seek 1s) to a cached thumbnail PNG — ffmpegthumbnailer, else
-- ffmpeg — keyed by (path md5) + invalidated by mtime, point $src at it, then render like an image
-- (so the sixel/thumb caches make a revisit instant). No extractor → $src is a missing file and the
-- overlay silently draws nothing (the pane keeps the textual `file` description underneath).
videoCmd :: String -> Int -> Int -> String
videoCmd path cols rows =
  strAppend "th=\"$HOME/.cache/fff/thumb/$(printf %s " (strAppend (shQuote path)
   (strAppend "|md5sum|cut -c1-32).png\"; mkdir -p \"${th%/*}\"; { [ -f \"$th\" ] && [ \"$th\" -nt " (strAppend (shQuote path)
   (strAppend " ]; } || ffmpegthumbnailer -i " (strAppend (shQuote path)
   (strAppend " -o \"$th\" -s 512 2>/dev/null || ffmpeg -y -ss 1 -i " (strAppend (shQuote path)
   (strAppend " -frames:v 1 -vf scale=512:-1 \"$th\" 2>/dev/null; src=\"$th\"; " (renderSrc cols rows)
     ))))))))
-- PDF: render page 1 to a cached PNG via pdftoppm (`-singlefile BASE` writes BASE.png), keyed by
-- (path md5) + mtime-invalidated, point $src at it, then render like an image — reusing the
-- sixel/thumb caches so a revisit is instant. No pdftoppm → $src is missing → draws nothing (the
-- pane keeps the textual `file` description + `[pdf]` header underneath).
pdfCmd :: String -> Int -> Int -> String
pdfCmd path cols rows =
  strAppend "th=\"$HOME/.cache/fff/thumb/$(printf %s " (strAppend (shQuote path)
   (strAppend "|md5sum|cut -c1-32).png\"; mkdir -p \"${th%/*}\"; { [ -f \"$th\" ] && [ \"$th\" -nt " (strAppend (shQuote path)
   (strAppend " ]; } || pdftoppm -png -f 1 -l 1 -r 96 -singlefile " (strAppend (shQuote path)
   (strAppend " \"${th%.png}\" 2>/dev/null; src=\"$th\"; " (renderSrc cols rows)
     ))))))

-- Render the selected IMAGE as pixels into the pane — the only IO the preview adds (pixels can't be
-- part of the pure `render` string). A noop on a pipe, with the pane off, no selection, a non-image
-- selection, or no graphics tool. Spawns once per frame, like the per-frame `ls` (minor flicker).
previewImage :: String -> Int -> Int -> String -> Int -> String -> Int
previewImage cwd sel rows raw cols mime =
  if (onTty 0) && (previewOn cols) && (length (lines raw) > 0) && (hasImgTool 0)
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
  let n = length (lines raw) in
  windowPaths cwd raw (clampSel (sel - 2) n) (clampSel (sel + 4) n)

-- ONE detached background job for the whole window: a trailing `&` so runStatus returns at once
-- and the loop never blocks. A non-interactive shell does not SIGHUP its background jobs, so it
-- outlives the frame that spawned it.
warmLoop :: String -> String -> String
warmLoop paths body =
  strAppend "for src in " (strAppend paths (strAppend "; do " (strAppend body "; done >/dev/null 2>&1 &")))
-- Renderer-aware prefetch body. kitty keeps no fff cache → just warm the OS page cache (a
-- background `cat`), so the next synchronous `kitten icat` reads from RAM; sixel → the full
-- decode-to-cache with the SAME box px as render (paneW cols × maxItems rows). A tail `if` whose
-- branches are warmLoop APPLICATIONS (not a consumed heap conditional).
prefetchCmd :: String -> Int -> Int -> String -> Int -> String
prefetchCmd cwd sel rows raw cols =
  if pickRenderer 0 == "kitten"
  then warmLoop (winPaths cwd sel raw) "cat \"$src\" >/dev/null 2>&1"
  else warmLoop (winPaths cwd sel raw) (sixelDecode (paneW cols) (maxItems rows))
-- Warm the preview cache for a window around the cursor in a detached job so the NEXT j/k is a
-- hit, not a ~200ms decode. Gated CHARACTER-FOR-CHARACTER like previewImage — a strict no-op off
-- a tty (the headless test harness), with the pane off, an empty listing, or no graphics tool.
prefetch :: String -> Int -> Int -> String -> Int -> Int
prefetch cwd sel rows raw cols =
  if (onTty 0) && (previewOn cols) && (length (lines raw) > 0) && (hasImgTool 0)
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
  let total = length (lines raw) in
  let mx = maxItems rows in
  let start = viewStart sel total mx in
  let lw = listWidth cols in
  let prev = previewOn cols && total > 0 in
  imgClearSeq ++ homeClear
    ++ drawRows (lines raw) 0 start (start + mx) sel marked cwd lw prev
    ++ sepSeg lw mx prev
    ++ previewSeg cwd sel raw cols mx prev (infoMime info) poff
    ++ statusLine cwd total sel marked prog rows info
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
  else if charAt 0 k == '\e' then ""
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
errFile d = strAppend (envOr "HOME" ".") "/.cache/fff/err"
-- Shell redirect appended to a command so its stderr lands in errFile (for okOrErr to surface).
errRedir :: String
errRedir = " 2>\"$HOME/.cache/fff/err\""
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

------------------------------------------------------------------- key reading (single byte + arrows)

-- Read one command key; expand an arrow ESC-sequence (ESC [ A/B/C/D) to k/j/l/h. A lone Esc no
-- longer blocks: after ESC the two follow-on bytes are read with `readKeyTimeout 25` (ms), so a
-- bare Esc (no byte within the window) returns "\e" — which `step` treats as quit — immediately.
readMainKey :: Int -> String
readMainKey dummy =
  let k = readKey 0 in
  -- short-circuit: `charAt 0 k` runs only on a non-empty key (ESC starts an arrow sequence).
  if strLen k > 0 && charAt 0 k == '\e'
  then let b1 = readKeyTimeout 25 in
       if strLen b1 == 0 then "\e"                     -- lone Esc: no follow-on byte in the window
       else let b2 = readKeyTimeout 25 in arrowKey b2  -- ESC [ <final> → arrow
  else k
-- Like readMainKey but the first byte is read with a timeout: "" = NO key within `ms` (a poll tick
-- for the resize watcher). A lone Esc still returns "\e". Only used on a tty (interactive).
readMainKeyTO :: Int -> String
readMainKeyTO ms =
  let k = readKeyTimeout ms in
  if strLen k == 0 then ""
  else if charAt 0 k == '\e'
  then let b1 = readKeyTimeout 25 in
       if strLen b1 == 0 then "\e"
       else let b2 = readKeyTimeout 25 in arrowKey b2
  else k
arrowKey :: String -> String
arrowKey b =
  if b == "A" then "k"
  else if b == "B" then "j"
  else if b == "C" then "l"
  else if b == "D" then "h"
  else ""

------------------------------------------------------------------- the event loop + dispatch

-- State: cwd, cursor index, marked (newline-joined paths), pending program, hidden flag, rows,
-- plus a CACHED frame context — `cols` (terminal width) and `raw` (the `ls` output). Navigation
-- (j/k/g/G/mark/search) reuses the cache so a move spawns NO `ls`/`stty` (Yazi-like); only a
-- transition that changes the directory CONTENTS goes through `reloop`, which re-captures both.
-- `main` and every such transition enter via `reloop` (6 args); the worker `loop` has 8.
reloop :: String -> Int -> String -> String -> Int -> Int -> IO ()
reloop cwd sel marked prog hidden rows =
  loop cwd sel marked prog hidden rows (termCols 0) (freshLs cwd hidden)
-- One `ls` capture (the only directory listing per refresh); pure `lines` re-derives the entries.
freshLs :: String -> Int -> String
freshLs cwd hidden = runCapture (lsCmd cwd hidden)

-- `loop` renders at preview-scroll offset 0; `loopAt` carries a non-zero offset for J/K. Any key
-- other than J/K resets the scroll (it goes through `step`, whose branches re-enter via `loop` = 0).
loop :: String -> Int -> String -> String -> Int -> Int -> Int -> String -> IO ()
loop cwd sel marked prog hidden rows cols raw =
  loopAt cwd sel marked prog hidden rows cols raw 0
loopAt :: String -> Int -> String -> String -> Int -> Int -> Int -> String -> Int -> IO ()
loopAt cwd sel marked prog hidden rows cols raw poff = do
  info <- selInfo (selPathOf cwd raw sel)
  putStr (render cwd sel marked prog rows raw cols info poff)
  previewImage cwd sel rows raw cols (infoMime info)
  prefetch cwd sel rows raw cols
  waitKey cwd sel marked prog hidden rows cols raw poff

-- Read the next key. On a TTY, poll with a timeout so a terminal RESIZE is noticed without a
-- keypress (Axión has no SIGWINCH) — a timeout tick re-checks `stty size` and reloops if it changed.
-- Off a tty (headless test / pipe) keep the plain blocking read so EOF still quits as before.
waitKey :: String -> Int -> String -> String -> Int -> Int -> Int -> String -> Int -> IO ()
waitKey cwd sel marked prog hidden rows cols raw poff =
  if onTty 0
  then pollKey cwd sel marked prog hidden rows cols raw poff
  else stepAt cwd sel marked prog hidden rows cols raw poff (readMainKey 0)
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
  else reloop cwd (clampSel sel (length (lines raw))) marked prog hidden (termRows 0)

-- Intercept the preview-scroll keys J/K (re-render the SAME selection at a new offset, no re-list);
-- every other key resets scroll and falls through to the full dispatcher `step` unchanged.
stepAt :: String -> Int -> String -> String -> Int -> Int -> Int -> String -> Int -> String -> IO ()
stepAt cwd sel marked prog hidden rows cols raw poff key =
  if key == "J" then loopAt cwd sel marked prog hidden rows cols raw (scrollDown poff rows)
  else if key == "K" then loopAt cwd sel marked prog hidden rows cols raw (scrollUp poff rows)
  else step cwd sel marked prog hidden rows cols raw key

-- Navigation branches thread `cols raw` forward (no re-listing); directory-changing branches drop
-- the cache and re-enter via `reloop`. Counts/paths come from the cached `raw`, not a fresh `ls`.
step :: String -> Int -> String -> String -> Int -> Int -> Int -> String -> String -> IO ()
step cwd sel marked prog hidden rows cols raw key = case key of
  "j" -> loop cwd (wrapSel (sel + 1) (length (lines raw))) marked prog hidden rows cols raw
  "k" -> loop cwd (wrapSel (sel - 1) (length (lines raw))) marked prog hidden rows cols raw
  "g" -> loop cwd 0 marked prog hidden rows cols raw
  "G" -> loop cwd (clampSel (length (lines raw) - 1) (length (lines raw))) marked prog hidden rows cols raw
  "l" -> open cwd sel marked prog hidden rows raw
  "h" -> reloop (parentDir cwd) 0 marked prog hidden rows
  "." -> reloop cwd 0 marked prog (if hidden == 1 then 0 else 1) rows
  "e" -> reloop cwd (clampSel sel (length (lines raw))) marked prog hidden (termRows 0)
  "~" -> goHome marked prog hidden rows
  "-" -> goPrev marked prog hidden rows
  ":" -> doGoDir cwd sel marked prog hidden rows
  "/" -> doSearch cwd sel marked prog hidden rows cols raw
  "n" -> doMkdir cwd sel marked prog hidden rows
  "f" -> doMkfile cwd sel marked prog hidden rows
  "r" -> doRename cwd sel marked prog hidden rows
  "x" -> doAttr cwd sel marked prog hidden rows
  "X" -> doChmod cwd sel marked prog hidden rows
  "y" -> loop cwd sel (markToggle marked (selPathOf cwd raw sel)) "cp -iR" hidden rows cols raw
  "m" -> loop cwd sel (markToggle marked (selPathOf cwd raw sel)) "mv -i" hidden rows cols raw
  "s" -> loop cwd sel (markToggle marked (selPathOf cwd raw sel)) "ln -s" hidden rows cols raw
  "d" -> loop cwd sel (markToggle marked (selPathOf cwd raw sel)) "trash" hidden rows cols raw
  "Y" -> loop cwd sel (allPathsOf cwd raw) "cp -iR" hidden rows cols raw
  "M" -> loop cwd sel (allPathsOf cwd raw) "mv -i" hidden rows cols raw
  "S" -> loop cwd sel (allPathsOf cwd raw) "ln -s" hidden rows cols raw
  "D" -> loop cwd sel (allPathsOf cwd raw) "trash" hidden rows cols raw
  "c" -> loop cwd sel "" "" hidden rows cols raw
  "p" -> doPaste cwd sel marked prog hidden rows
  "b" -> doBulk cwd sel marked prog hidden rows
  "!" -> doShell cwd sel marked prog hidden rows
  "o" -> doSort cwd sel marked prog hidden rows
  "F" -> doFilter cwd sel marked prog hidden rows
  "u" -> doRestore cwd sel marked prog hidden rows
  ";" -> loop cwd (searchNext raw (readLastQ 0) sel) marked prog hidden rows cols raw
  "," -> loop cwd (searchPrev raw (readLastQ 0) sel) marked prog hidden rows cols raw
  "q" -> quit cwd
  "\e" -> quit cwd
  ""  -> quit cwd
  other -> favOrIgnore cwd sel marked prog hidden rows key

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
  code <- (if strLen nm > 0 then renameFile (selPath cwd hidden sel) (cwd </> nm) else 0)
  okOr code "rename failed" rows
  reloop cwd sel marked prog hidden rows

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
-- ~/.cache/fff/lastq so `;`/`,` can cycle through the other matches.
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
  else if charAt 0 k == '\e' then loop cwd osel marked prog hidden rows cols raw            -- Esc: cancel to original
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

-- Small persisted-state files under ~/.cache/fff (same idiom as the cell-size cache — avoids
-- threading sort/filter/last-query through every loop/reloop/do* signature).
sortFile :: Int -> String
sortFile d = strAppend (envOr "HOME" ".") "/.cache/fff/sort"
filterFile :: Int -> String
filterFile d = strAppend (envOr "HOME" ".") "/.cache/fff/filter"
lastqFile :: Int -> String
lastqFile d = strAppend (envOr "HOME" ".") "/.cache/fff/lastq"
readFileTrim :: String -> String
readFileTrim path = trim (runCapture (strAppend "cat " (strAppend (shQuote path) " 2>/dev/null")))
readLastQ :: Int -> String
readLastQ d = readFileTrim (lastqFile 0)

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
bottomMatch raw q from = clampNeg (matchBefore (lines raw) q 0 (length (lines raw)) (0 - 1)) from
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
  if (prog == "trash") && (markCount marked > 0)
  then pasteIfYes cwd sel marked prog hidden rows (confirm (trashPrompt (markCount marked)) rows)
  else doPasteRun cwd sel marked prog hidden rows
pasteIfYes :: String -> Int -> String -> String -> Int -> Int -> Bool -> IO ()
pasteIfYes cwd sel marked prog hidden rows yes =
  if yes then doPasteRun cwd sel marked prog hidden rows
  else reloop cwd sel marked prog hidden rows
doPasteRun :: String -> Int -> String -> String -> Int -> Int -> IO ()
doPasteRun cwd sel marked prog hidden rows = do
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
         (strAppend "; L=\"$HOME/.cache/fff/trashlog\"; mkdir -p \"$d\" \"${L%/*}\" && for src in " (strAppend (quoteLines marked)
           (strAppend "; do b=${src##*/}; dest=\"$d/$b\"; n=1; while [ -e \"$dest\" ]; do dest=\"$d/$b.$n\"; n=$((n+1)); done; mv -- \"$src\" \"$dest\" && printf '%s\\t%s\\n' \"$dest\" \"$src\" >> \"$L\"; done" errRedir)))))
  else runStatus (strAppend prog (strAppend " -- " (strAppend (quoteLines marked) (strAppend " " (strAppend (shQuote cwd) errRedir)))))
trashDir :: Int -> String
trashDir d = strAppend (envOr "HOME" ".") "/.local/share/fff/trash"

-- `u` undo-trash: restore the most-recently-trashed file to its ORIGINAL location. Trashing appends
-- a `<trash-dest>\t<orig-path>` line to ~/.cache/fff/trashlog; restore reads the LAST line, moves
-- the file back (recreating the parent dir if needed), and pops that line. Nothing to restore (empty
-- log) or an already-gone trash file is a silent no-op (exit 0); only a real `mv` failure flashes.
doRestore :: String -> Int -> String -> String -> Int -> Int -> IO ()
doRestore cwd sel marked prog hidden rows = do
  code <- runStatus (restoreCmd 0)
  okOrErr code "restore failed" rows
  reloop cwd sel marked prog hidden rows
restoreCmd :: Int -> String
restoreCmd d =
  strAppend "l=\"$HOME/.cache/fff/trashlog\"; [ -s \"$l\" ] || exit 0; last=$(tail -n1 \"$l\"); t=$(printf '\\t'); dest=${last%%$t*}; orig=${last#*$t}; rc=0; if [ -e \"$dest\" ]; then mkdir -p \"${orig%/*}\" && mv -- \"$dest\" \"$orig\" || rc=1; fi; sed -i '$ d' \"$l\"; exit $rc" errRedir
-- Shell-quote each newline-joined path and space-join them.
quoteLines :: String -> String
quoteLines m = qlGo (filter nonEmpty (lines m))
qlGo :: List String -> String
qlGo xs = case xs of
  Nil -> ""
  Cons y ys -> strAppend (shQuote y) (strAppend " " (qlGo ys))

-- `b` bulk-rename: write marked basenames to a temp, open $EDITOR, read back, rename each changed.
doBulk :: String -> Int -> String -> String -> Int -> Int -> IO ()
doBulk cwd sel marked prog hidden rows = do
  if markCount marked > 0 then bulkRun cwd marked (bulkTmp 0) else 0
  reloop cwd (clampSel sel (nEntries cwd hidden)) "" "" hidden rows
bulkTmp :: Int -> String
bulkTmp d = strAppend "/tmp/fff-bulk-" (randHex 8)
bulkRun :: String -> String -> String -> Int
bulkRun cwd marked tmp = do
  writeFile tmp (baseNames marked)
  putStr resetSeq
  runStatus (strAppend (editorCmd 0) (strAppend " " (shQuote tmp)))
  bulkApply (filter nonEmpty (lines marked)) (filter nonEmpty (lines (readFile tmp))) cwd
  putStr setupSeq
  removeFile tmp
-- basenames of the marked paths, one per line.
baseNames :: String -> String
baseNames m = bnGo (filter nonEmpty (lines m))
bnGo :: List String -> String
bnGo xs = case xs of
  Nil -> ""
  Cons y ys -> strAppend (baseName y) (strAppend "\n" (bnGo ys))
-- rename olds[i] → cwd/news[i] for each pair where they differ.
bulkApply :: List String -> List String -> String -> Int
bulkApply olds news cwd = case olds of
  Nil -> 0
  Cons o os -> case news of
    Nil -> 0
    Cons n ns -> do
      if o == cwd </> n then 0 else renameFile o (cwd </> n)
      bulkApply os ns cwd

-- `!` spawn $SHELL in cwd.
doShell :: String -> Int -> String -> String -> Int -> Int -> IO ()
doShell cwd sel marked prog hidden rows = do
  putStr resetSeq
  runStatus (strAppend "cd " (strAppend (shQuote cwd) (strAppend " && " (envOr "SHELL" "sh"))))
  putStr setupSeq
  reloop cwd sel marked prog hidden rows

-- `q`: restore the terminal and write cwd to the cd-file (for a shell wrapper's `cd` on exit).
quit :: String -> IO ()
quit cwd = do
  writeFile (cdFile 0) (strAppend cwd "\n")
  runStatus "test -t 0 && stty sane 2>/dev/null"
  putStr resetSeq
cdFile :: Int -> String
cdFile d = strAppend (envOr "HOME" ".") "/.cache/fff/fff.d"

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
-- the real CELL pixel size, and cache "cw ch" in ~/.cache/fff/cell for sixelRenderSrc to size images
-- exactly (no font guessing → tall photos can't overflow the pane). Run ONCE at startup, before the
-- key loop, so the reply is the only pending input (never eats a keystroke); a 0.1s stty timeout and
-- a non-tty/pipe both no-op, leaving the 7x14 fallback. Reads from a fresh /dev/tty fd, not stdin.
queryCell :: Int -> String
queryCell d =
  strAppend "command -v stty >/dev/null 2>&1 || exit 0; { exec 3</dev/tty; } 2>/dev/null || exit 0; "
    (strAppend "old=$(stty -g <&3) || exit 0; stty raw -echo min 0 time 1 <&3; printf '\\033[14t' >/dev/tty; "
      (strAppend "r=$(dd bs=64 count=1 <&3 2>/dev/null); stty \"$old\" <&3; "
        (strAppend "hw=$(printf %s \"$r\"|sed -n 's/.*4;\\([0-9]*\\);\\([0-9]*\\)t.*/\\1 \\2/p'); set -- $hw; "
          (strAppend "[ -n \"${1:-}\" ] && [ -n \"${2:-}\" ] || exit 0; sz=$(stty size <&3 2>/dev/null); rr=${sz%% *}; cc=${sz##* }; "
            "[ \"${rr:-0}\" -gt 0 ] && [ \"${cc:-0}\" -gt 0 ] || exit 0; cw=$(( $2 / cc )); ch=$(( $1 / rr )); [ \"$cw\" -gt 0 ] && [ \"$ch\" -gt 0 ] || exit 0; printf '%s %s' \"$cw\" \"$ch\" > \"$HOME/.cache/fff/cell\""))))

main :: IO ()
main = do
  makeDir (strAppend (envOr "HOME" ".") "/.cache/fff")
  -- Transient view state does not persist across runs: clear any leftover filter / search query so a
  -- new session starts unfiltered (the sort preference IS kept).
  runStatus (strAppend "rm -f " (strAppend (shQuote (filterFile 0)) (strAppend " " (shQuote (lastqFile 0)))))
  runStatus (queryCell 0)
  -- Keep the terminal in -echo -icanon for the WHOLE session: `readKey` saves/restores the current
  -- mode around each read, so with this baseline echo stays OFF between reads too — otherwise keys
  -- typed DURING a render (slower now, with previews) get echoed as `^[[A`/`^[[B` at the bottom.
  runStatus "test -t 0 && stty -echo -icanon 2>/dev/null"
  putStr setupSeq
  reloop (startDir (getArg 0)) 0 "" "" 0 (termRows 0)
