-- fff.axi — a rewrite of `fff` (dylanaraps/fff, "fucking fast file-manager") in Axión.
-- The third flagship: a scrolling, colored, marked-files file manager with a full command line.
-- GC-free + memory-safe by construction; runs identically on interp / --dev / --release.
--
-- Keys (fff defaults): j/k or ↓/↑ move · g/G top/bottom · l/→/Enter open · h/← parent
--   . toggle hidden · e refresh · - previous dir · ~ home · 1-9 favourites (FFF_FAV<n>) · : go dir
--   / search (live filter) · ! shell · n mkdir · f mkfile · r rename · x attributes(stat) · X chmod±x
--   y/m/s/d mark (cp/mv/ln/trash) · Y/M/S/D mark all · c clear marks · p paste · b bulk-rename · q quit
--
-- Honest scope vs fff: no image preview (needs w3m/framebuffer — infeasible); colors are type-based
-- (dir vs file, cursor reverse) not full LS_COLORS; no WINCH signal so resize is manual (e); plain
-- Esc waits for an arrow's remaining bytes (Axión reads block — no timeout). The command line reads
-- keys directly (chr/readKey), so tab-completion and live-search need no readLine.

------------------------------------------------------------------- shell-safety + path helpers

-- POSIX single-quote for safe `sh -c` interpolation (byte 39 = `'`); injection-proof for any input.
shQuote :: String -> String
shQuote s = strAppend "'" (strAppend (shEsc s 0 (strLen s)) "'")
shEsc :: String -> Int -> Int -> String
shEsc s i n =
  if i >= n then ""
  else (if charAt i s == 39
        then strAppend "'\\''" (shEsc s (i + 1) n)
        else strAppend (substr i 1 s) (shEsc s (i + 1) n))

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

------------------------------------------------------------------- ANSI (built from chr, no \e literal)

esc :: String
esc = chr 27

-- CSI sequence: ESC [ <body>.
csi :: String -> String
csi s = strAppend esc (strAppend "[" s)

-- Wrap s in the SGR color `c`, then reset.
paint :: String -> String -> String
paint c s = strAppend (csi (strAppend c "m")) (strAppend s (csi "m"))

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

-- Max list rows in the viewport (leave 2 rows: a header and the status line).
maxItems :: Int -> Int
maxItems rows = if rows - 3 < 1 then 1 else rows - 3

-- One `ls` listing the dir DIRECTORIES-FIRST with a trailing "/" on dirs (no per-entry `test -d`).
-- `hidden`=1 shows dotfiles (-A). One subprocess per frame, not one per entry.
lsCmd :: String -> Int -> String
lsCmd cwd hidden =
  strAppend (if hidden == 1 then "ls -Ap --group-directories-first -- " else "ls -p --group-directories-first -- ")
            (shQuote cwd)
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

-- First visible index so the cursor stays on screen (top / bottom / centered), fff's draw_dir math.
viewStart :: Int -> Int -> Int -> Int
viewStart sel total mx =
  if total <= mx then 0
  else if sel < (mx `div` 2) then 0
  else if total - sel <= (mx `div` 2) then total - mx
  else sel - (mx `div` 2)

-- Render the visible window [start, start+mx) of the list, highlighting `sel`, marking marked paths.
drawRows :: List String -> Int -> Int -> Int -> Int -> String -> String -> String
drawRows xs i start endIdx sel marked cwd = case xs of
  Nil -> ""
  Cons y ys ->
    if (i >= start) && (i < endIdx)
    then strAppend (rowFor y i sel marked cwd) (drawRows ys (i + 1) start endIdx sel marked cwd)
    else drawRows ys (i + 1) start endIdx sel marked cwd

-- "*" if `full` is marked, else " " (a literal — never a let-bound conditional heap value).
markChar :: String -> String -> String
markChar marked full = if markedHas marked full then "*" else " "
-- Directories (trailing "/") are blue; files plain.
colorName :: String -> String
colorName raw = if hasSuffix "/" raw then paint "1;34" raw else dup raw

-- The cursor row is reverse-video; others color dirs blue. The heap-producing `if` can now sit
-- INLINE (consumed by the surrounding strAppend) — the reclaimer reclaims an all-heap-arm
-- conditional temp at its death point, so the earlier tail-position (rowSel/rowUnsel) workaround
-- is no longer needed.
rowFor :: String -> Int -> Int -> String -> String -> String
rowFor raw i sel marked cwd =
  strAppend (csi "K")
    (strAppend
      (if i == sel
       then paint "7" (strAppend (markChar marked (cwd </> stripSlash raw)) (strAppend " " (dup raw)))
       else strAppend (markChar marked (cwd </> stripSlash raw)) (strAppend " " (colorName raw)))
      "\n")

-- Bottom status line: (pos/total), [n] selected (program), cwd — in reverse video, pinned to row.
posStr :: Int -> Int -> String
posStr sel total = strAppend "(" (strAppend (showInt (sel + 1)) (strAppend "/" (strAppend (showInt total) ")")))
markInfo :: String -> String -> String
markInfo marked prog =
  strAppend " [" (strAppend (showInt (markCount marked)) (strAppend "] (" (strAppend prog ")")))
-- the marked-count segment, or "" — a tail `if` in its own helper (not a consumed inline conditional).
markSeg :: String -> String -> String
markSeg marked prog = if markCount marked > 0 then markInfo marked prog else ""
statusLine :: String -> Int -> String -> String -> Int -> Int -> String
statusLine cwd sel marked prog hidden rows =
  strAppend (csi (strAppend (showInt (rows - 1)) ";1H"))
    (paint "7"
      (strAppend (posStr sel (nEntries cwd hidden))
        (strAppend (markSeg marked prog)
          (strAppend " " cwd))))

------------------------------------------------------------------- full-frame render

render :: String -> Int -> String -> String -> Int -> Int -> String
render cwd sel marked prog hidden rows =
  let total = nEntries cwd hidden in
  let mx = maxItems rows in
  let start = viewStart sel total mx in
  strAppend homeClear
    (strAppend (drawRows (entriesRaw cwd hidden) 0 start (start + mx) sel marked cwd)
      (statusLine cwd sel marked prog hidden rows))

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
  else if (charAt 0 k == 13) || (charAt 0 k == 10) then acc
  else if charAt 0 k == 27 then ""
  else if (charAt 0 k == 127) || (charAt 0 k == 8) then cmdGo prompt rows cwd (dropLast acc)
  else if charAt 0 k == 9 then cmdGo prompt rows cwd (dupOrAcc (firstPrefix (entriesRaw cwd 1) acc) acc)
  else cmdGo prompt rows cwd (strAppend acc k)

-- Tab result: use the completion if non-empty, else keep what was typed.
dupOrAcc :: String -> String -> String
dupOrAcc comp acc = if strLen comp > 0 then comp else dup acc

------------------------------------------------------------------- key reading (single byte + arrows)

-- Read one command key; expand an arrow ESC-sequence (ESC [ A/B/C/D) to k/j/l/h. A lone Esc blocks
-- for the two follow-on bytes (Axión reads have no timeout) — a minor wart; hjkl are fff defaults.
readMainKey :: Int -> String
readMainKey dummy =
  let k = readKey 0 in
  if strLen k == 0 then k
  else if charAt 0 k == 27
       then let b1 = readKey 0 in let b2 = readKey 0 in arrowKey b2
       else k
arrowKey :: String -> String
arrowKey b =
  if b == "A" then "k"
  else if b == "B" then "j"
  else if b == "C" then "l"
  else if b == "D" then "h"
  else ""

------------------------------------------------------------------- the event loop + dispatch

-- State: cwd, cursor index, marked (newline-joined paths), pending program, hidden flag, rows.
loop :: String -> Int -> String -> String -> Int -> Int -> IO ()
loop cwd sel marked prog hidden rows = do
  putStr (render cwd sel marked prog hidden rows)
  step cwd sel marked prog hidden rows (readMainKey 0)

step :: String -> Int -> String -> String -> Int -> Int -> String -> IO ()
step cwd sel marked prog hidden rows key = case key of
  "j" -> loop cwd (clampSel (sel + 1) (nEntries cwd hidden)) marked prog hidden rows
  "k" -> loop cwd (clampSel (sel - 1) (nEntries cwd hidden)) marked prog hidden rows
  "g" -> loop cwd 0 marked prog hidden rows
  "G" -> loop cwd (clampSel (nEntries cwd hidden - 1) (nEntries cwd hidden)) marked prog hidden rows
  "l" -> open cwd sel marked prog hidden rows
  "h" -> loop (dirName cwd) 0 marked prog hidden rows
  "." -> loop cwd 0 marked prog (if hidden == 1 then 0 else 1) rows
  "e" -> loop cwd (clampSel sel (nEntries cwd hidden)) marked prog hidden (termRows 0)
  "~" -> goHome marked prog hidden rows
  "-" -> goPrev marked prog hidden rows
  ":" -> doGoDir cwd sel marked prog hidden rows
  "/" -> doSearch cwd sel marked prog hidden rows
  "n" -> doMkdir cwd sel marked prog hidden rows
  "f" -> doMkfile cwd sel marked prog hidden rows
  "r" -> doRename cwd sel marked prog hidden rows
  "x" -> doAttr cwd sel marked prog hidden rows
  "X" -> doChmod cwd sel marked prog hidden rows
  "y" -> loop cwd sel (markToggle marked (selPath cwd hidden sel)) "cp -iR" hidden rows
  "m" -> loop cwd sel (markToggle marked (selPath cwd hidden sel)) "mv -i" hidden rows
  "s" -> loop cwd sel (markToggle marked (selPath cwd hidden sel)) "ln -s" hidden rows
  "d" -> loop cwd sel (markToggle marked (selPath cwd hidden sel)) "trash" hidden rows
  "Y" -> loop cwd sel (allPaths cwd hidden) "cp -iR" hidden rows
  "M" -> loop cwd sel (allPaths cwd hidden) "mv -i" hidden rows
  "S" -> loop cwd sel (allPaths cwd hidden) "ln -s" hidden rows
  "D" -> loop cwd sel (allPaths cwd hidden) "trash" hidden rows
  "c" -> loop cwd sel "" "" hidden rows
  "p" -> doPaste cwd sel marked prog hidden rows
  "b" -> doBulk cwd sel marked prog hidden rows
  "!" -> doShell cwd sel marked prog hidden rows
  "q" -> quit cwd
  ""  -> quit cwd
  other -> favOrIgnore cwd sel marked prog hidden rows key

clampSel :: Int -> Int -> Int
clampSel i n = if n == 0 then 0 else if i < 0 then 0 else if i >= n then n - 1 else i

-- `l`/Enter: descend into a directory, or open a file (text → $EDITOR, else xdg-open backgrounded).
open :: String -> Int -> String -> String -> Int -> Int -> IO ()
open cwd sel marked prog hidden rows =
  if isDirPath (selPath cwd hidden sel)
  then loop (selPath cwd hidden sel) 0 marked prog hidden rows
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
  loop cwd sel marked prog hidden rows

openOther :: String -> Int -> String -> String -> Int -> Int -> IO ()
openOther cwd sel marked prog hidden rows = do
  runStatus (strAppend "nohup xdg-open " (strAppend (shQuote (selPath cwd hidden sel)) " >/dev/null 2>&1 &"))
  loop cwd sel marked prog hidden rows

-- $VISUAL or $EDITOR or vi.
editorCmd :: Int -> String
editorCmd d =
  let v = getEnv "VISUAL" in
  if strLen v > 0 then v
  else let e = getEnv "EDITOR" in if strLen e > 0 then e else "vi"

goHome :: String -> String -> Int -> Int -> IO ()
goHome marked prog hidden rows =
  loop (envOr "HOME" ".") 0 marked prog hidden rows
goPrev :: String -> String -> Int -> Int -> IO ()
goPrev marked prog hidden rows =
  loop (envOr "OLDPWD" ".") 0 marked prog hidden rows

-- getEnv, or a fresh default if unset/empty (never conditionally escapes the argument).
envOr :: String -> String -> String
envOr name dflt = let v = getEnv name in if strLen v > 0 then v else dup dflt

-- Favourites 1-9 → $FFF_FAV<n>; anything else ignored.
favOrIgnore :: String -> Int -> String -> String -> Int -> Int -> String -> IO ()
favOrIgnore cwd sel marked prog hidden rows key =
  let fav = getEnv (strAppend "FFF_FAV" key) in
  if (strLen key > 0) && (charAt 0 key >= 49) && (charAt 0 key <= 57) && (strLen fav > 0)
  then loop fav 0 marked prog hidden rows
  else loop cwd sel marked prog hidden rows

-- All entries of cwd as newline-joined full paths (for mark-all).
allPaths :: String -> Int -> String
allPaths cwd hidden = joinPaths cwd (entriesRaw cwd hidden)
joinPaths :: String -> List String -> String
joinPaths cwd xs = case xs of
  Nil -> ""
  Cons y ys -> strAppend (strAppend (cwd </> stripSlash y) "\n") (joinPaths cwd ys)

------------------------------------------------------------------- operations

-- `n` mkdir, `f` mkfile, `r` rename, `:` go-dir — each prompts via cmdLine, then acts + refreshes.
doMkdir :: String -> Int -> String -> String -> Int -> Int -> IO ()
doMkdir cwd sel marked prog hidden rows = do
  nm <- cmdLine "mkdir: " rows cwd
  if strLen nm > 0 then makeDir (cwd </> nm) else 0
  loop cwd (clampSel sel (nEntries cwd hidden + 1)) marked prog hidden rows

doMkfile :: String -> Int -> String -> String -> Int -> Int -> IO ()
doMkfile cwd sel marked prog hidden rows = do
  nm <- cmdLine "mkfile: " rows cwd
  if strLen nm > 0 then writeFile (cwd </> nm) "" else 0
  loop cwd (clampSel sel (nEntries cwd hidden + 1)) marked prog hidden rows

doRename :: String -> Int -> String -> String -> Int -> Int -> IO ()
doRename cwd sel marked prog hidden rows = do
  nm <- cmdLine (strAppend "rename " (strAppend (selName cwd hidden sel) " to: ")) rows cwd
  if strLen nm > 0 then renameFile (selPath cwd hidden sel) (cwd </> nm) else 0
  loop cwd sel marked prog hidden rows

doGoDir :: String -> Int -> String -> String -> Int -> Int -> IO ()
doGoDir cwd sel marked prog hidden rows = do
  nm <- cmdLine "go to dir: " rows cwd
  gotoDir cwd nm sel marked prog hidden rows
gotoDir :: String -> String -> Int -> String -> String -> Int -> Int -> IO ()
gotoDir cwd nm sel marked prog hidden rows =
  if (strLen nm > 0) && isDirPath nm
  then loop (dup nm) 0 marked prog hidden rows
  else loop cwd sel marked prog hidden rows

-- `/` search: prompt for a substring, jump the cursor to the first matching entry (live redraw of
-- the prompt happens in cmdLine; the match is applied on submit).
doSearch :: String -> Int -> String -> String -> Int -> Int -> IO ()
doSearch cwd sel marked prog hidden rows = do
  q <- cmdLine "/" rows cwd
  loop cwd (if strLen q > 0 then matchIndex (entriesRaw cwd hidden) q 0 sel else sel)
       marked prog hidden rows
-- index of the first entry containing `q` (fallback to `dflt`).
matchIndex :: List String -> String -> Int -> Int -> Int
matchIndex xs q i dflt = case xs of
  Nil -> dflt
  Cons y ys -> if hasInfix q y then i else matchIndex ys q (i + 1) dflt
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
  loop cwd sel marked prog hidden rows

-- `X` toggle the executable bit.
doChmod :: String -> Int -> String -> String -> Int -> Int -> IO ()
doChmod cwd sel marked prog hidden rows = do
  runStatus (strAppend (if isExecPath (selPath cwd hidden sel) then "chmod -x -- " else "chmod +x -- ")
              (shQuote (selPath cwd hidden sel)))
  loop cwd sel marked prog hidden rows
isExecPath :: String -> Bool
isExecPath p = runStatus (strAppend "test -x " (shQuote p)) == 0

-- `p` paste: run the pending program over every marked path into cwd (trash = move to trash dir).
doPaste :: String -> Int -> String -> String -> Int -> Int -> IO ()
doPaste cwd sel marked prog hidden rows = do
  if markCount marked > 0 then runPaste cwd marked prog else 0
  loop cwd (clampSel sel (nEntries cwd hidden + markCount marked)) "" "" hidden rows
runPaste :: String -> String -> String -> Int
runPaste cwd marked prog =
  if prog == "trash"
  then runStatus (strAppend "d=" (strAppend (shQuote (trashDir 0))
         (strAppend "; mkdir -p \"$d\" && mv -f -- " (strAppend (quoteLines marked) " \"$d\""))))
  else runStatus (strAppend prog (strAppend " -- " (strAppend (quoteLines marked) (strAppend " " (shQuote cwd)))))
trashDir :: Int -> String
trashDir d = strAppend (envOr "HOME" ".") "/.local/share/fff/trash"
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
  loop cwd (clampSel sel (nEntries cwd hidden)) "" "" hidden rows
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
  loop cwd sel marked prog hidden rows

-- `q`: restore the terminal and write cwd to the cd-file (for a shell wrapper's `cd` on exit).
quit :: String -> IO ()
quit cwd = do
  writeFile (cdFile 0) (strAppend cwd "\n")
  putStr resetSeq
cdFile :: Int -> String
cdFile d = strAppend (envOr "HOME" ".") "/.cache/fff/fff.d"

------------------------------------------------------------------- entry point

-- Start dir: argv[0] if given else "." (fresh in both branches → no conditional escape).
startDir :: String -> String
startDir a = if strLen a == 0 then "." else dup a

main :: IO ()
main = do
  makeDir (strAppend (envOr "HOME" ".") "/.cache/fff")
  putStr setupSeq
  loop (startDir (getArg 0)) 0 "" "" 0 (termRows 0)
