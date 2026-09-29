-- fm.axi — a minimal TUI FILE MANAGER, the second Axión flagship (after `pass`). It exercises what
-- a request/response CLI never does: an interactive EVENT LOOP, per-frame screen rendering, and
-- single-keypress input (the new `readKey` primitive — one raw byte, no Enter). GC-free + memory-safe
-- by construction like all Axión; runs identically on interp / --dev / --release.
--
-- Keys:  j/k down/up   l enter dir   h parent   d delete   r rename   m mkdir   c yank   p paste
--        q or EOF quit.  Directory detection is `test -d` (no stat primitive); the selected entry's
-- name is extracted as a FRESH copy (`dup`, a substr) so it never aliases a list element (AX0912).
-- State is threaded explicitly (cwd, selection index, yank buffer); the entry list is rebuilt each
-- frame from `readDir` (a fresh owned list, consumed by a borrowing traversal).

-- POSIX single-quote for safe `sh -c` interpolation (byte 39 = `'`), from pass.axi — injection-proof.
shQuote :: String -> String
shQuote s = "'" ++ shEsc s 0 (strLen s) ++ "'"
shEsc :: String -> Int -> Int -> String
shEsc s i n =
  if i >= n then ""
  else (if charAt i s == 39
        then "'\\''" ++ shEsc s (i + 1) n
        else substr i 1 s ++ shEsc s (i + 1) n)

-- Path join (from pass.axi): avoid a double slash after a trailing "/".
(</>) :: String -> String -> String
(</>) a b
  | hasSuffix "/" a = strAppend a b
  | otherwise       = strAppend a (strAppend "/" b)

-- A FRESH copy of a string: substr allocates a NEW String, so the result can be returned/kept
-- without aliasing the source (the safe way to pull an element out of an owned list).
dup :: String -> String
dup s = substr 0 (strLen s) s

notDot :: String -> Bool
notDot name = not (hasPrefix "." name)

-- The children of `dir`: dotfiles dropped, sorted (readDir is unsorted + includes dotfiles).
entriesOf :: String -> List String
entriesOf dir = sort (filter notDot (lines (readDir dir)))

nEntries :: String -> Int
nEntries dir = length (entriesOf dir)

-- Keep the selection index within [0, n).
clampSel :: Int -> Int -> Int
clampSel i n =
  if n == 0 then 0
  else if i < 0 then 0
  else if i >= n then n - 1
  else i

-- Is `p` a directory? No stat primitive, so ask the shell (path single-quoted → injection-safe).
isDir :: String -> Bool
isDir p = runStatus (strAppend "test -d " (shQuote p)) == 0

-- The `sel`-th entry name as a FRESH copy ("" if out of range) — never an alias of a list element.
pick :: Int -> List String -> String
pick i xs = case xs of
  Nil -> ""
  Cons y ys -> if i == 0 then dup y else pick (i - 1) ys

entryAt :: String -> Int -> String
entryAt cwd sel = pick sel (entriesOf cwd)

-- Render one row: "> name" for the selected line, "  name" otherwise.
rowLine :: String -> Int -> Int -> String
rowLine name i sel = strAppend (if i == sel then "> " else "  ") (strAppend name "\n")

renderRows :: List String -> Int -> Int -> String
renderRows xs i sel = case xs of
  Nil -> ""
  Cons y ys -> strAppend (rowLine y i sel) (renderRows ys (i + 1) sel)

-- The whole frame as one String: header + rows + a help footer.
render :: String -> Int -> String
render cwd sel =
  strAppend (strAppend "== " (strAppend cwd " ==\n"))
    (strAppend (renderRows (entriesOf cwd) 0 sel)
      "-- j/k move  l enter  h up  d del  r rename  m mkdir  c yank  p paste  q quit --\n")

-- The event loop: clear, draw, read one key, dispatch. State = (cwd, selection, yank buffer).
loop :: String -> Int -> String -> IO ()
loop cwd sel clip = do
  runStatus "clear 2>/dev/null || true"
  putStr (render cwd sel)
  k <- readKey 0
  step cwd sel clip k

step :: String -> Int -> String -> String -> IO ()
step cwd sel clip key = case key of
  "j" -> loop cwd (clampSel (sel + 1) (nEntries cwd)) clip
  "k" -> loop cwd (clampSel (sel - 1) (nEntries cwd)) clip
  "l" -> enter cwd sel clip
  "h" -> loop (dirName cwd) 0 clip
  "d" -> doDelete cwd sel clip
  "r" -> doRename cwd sel clip
  "m" -> doMkdir cwd sel clip
  "c" -> loop cwd sel (cwd </> entryAt cwd sel)   -- yank: remember the selected entry's full PATH
  "p" -> doPaste cwd sel clip
  "q" -> putStr "\n"                       -- quit (loop ends)
  ""  -> putStr "\n"                       -- EOF (scripted input exhausted) → quit
  other -> loop cwd sel clip               -- ignore unknown keys

-- `l`: descend into the selected entry if it is a directory, else stay put.
enter :: String -> Int -> String -> IO ()
enter cwd sel clip =
  if isDir (cwd </> entryAt cwd sel)
  then loop (cwd </> entryAt cwd sel) 0 clip
  else loop cwd sel clip

-- `d`: delete the selected entry (recursively; path single-quoted → injection-safe), then refresh.
doDelete :: String -> Int -> String -> IO ()
doDelete cwd sel clip = do
  runStatus (strAppend "rm -rf -- " (shQuote (cwd </> entryAt cwd sel)))
  loop cwd (clampSel sel (nEntries cwd)) clip

-- `r`: prompt (a full line via readLine) and rename the selected entry.
doRename :: String -> Int -> String -> IO ()
doRename cwd sel clip = do
  putStr (strAppend "\nrename " (strAppend (entryAt cwd sel) " to: "))
  newn <- readLine 0
  renameFile (cwd </> entryAt cwd sel) (cwd </> newn)
  loop cwd sel clip

-- `m`: prompt for a name and create a directory under cwd.
doMkdir :: String -> Int -> String -> IO ()
doMkdir cwd sel clip = do
  putStr "\nmkdir: "
  newn <- readLine 0
  makeDir (cwd </> newn)
  loop cwd (clampSel sel (nEntries cwd)) clip

-- `p`: copy the yanked NAME (from a `c`) into cwd. Empty buffer → harmless no-op.
doPaste :: String -> Int -> String -> IO ()
doPaste cwd sel clip = do
  runStatus (strAppend (strAppend "cp -r -- " (shQuote clip)) (strAppend " " (shQuote cwd)))
  loop cwd (clampSel sel (nEntries cwd)) clip

-- Start directory: argv[0] if given, else the current directory. Returns a FRESH string in BOTH
-- branches (`.` literal, or a `dup` copy) so the owned argument never conditionally escapes — it is
-- uniformly dropped, sidestepping the known conditional-owned-return leak residual.
startDir :: String -> String
startDir a = if strLen a == 0 then "." else dup a

main :: IO ()
main = loop (startDir (getArg 0)) 0 ""
