-- pass.axi — a rewrite of the Linux `pass` (password-store) CLI in Axión.
--
-- Entries are GPG-encrypted files under the store directory ($PASSWORD_STORE_DIR,
-- else $HOME/.password-store); `pass` shells out to `gpg` for crypto (ciphertext
-- stays in files — only plaintext crosses into Axión) and to `find` for listing.
-- Dispatch mirrors upstream pass:
--   pass init <gpg-id>      → create the store, write its .gpg-id recipient, and `git init`
--   pass                    → `show` with no name: fzf-pick an entry, then clip its login line
--   pass ls  [subdir]       → tree of the store (or of <subdir>)
--   pass show [<name>]      → copy the LOGIN line (line 2, the email) to the clipboard (default);
--                             `-c[n]` copies line n instead (default 1 = the password); `-s` prints
--                             the whole entry to stdout; no <name> + fzf → pick interactively
--   pass <name>             → bare shorthand: copy the PASSWORD (line 1) to the clipboard
--                             (`pass -s <name>` prints the whole entry instead)
--   pass find <term>        → list entries whose path matches <term>
--   pass grep <search>      → search decrypted contents
--   pass rm [-r] [-f] <name>→ delete an entry, or a whole subtree with `-r`
--   pass mv <old> <new>     → rename an entry OR a subdirectory
--   pass cp <old> <new>     → copy an entry OR a subdirectory (`-r` implied for dirs)
--   pass generate [-c] [-n] [-f] [-i] <name> [n] → random n-char password (default 25); `-n` = no
--                             symbols, `-c` = to clipboard, `-f` = overwrite w/o asking, `-i` =
--                             in-place (replace only line 1, keep metadata)
--   pass insert [-m|-e] [-f] <name> → read a passphrase (echo off), a multiline body (`-m`),
--                             or an echoed line (`-e`)
--   pass edit [<name>]      → decrypt into $EDITOR (on RAMFS), re-encrypt on save
--                             (no <name> + fzf installed → pick interactively)
--   pass git <args…>        → run git inside the store (history, push, …)
--   pass help | version     → usage / version
--
-- Flags are parsed getopt-style: single-char options in the leading run before the first
-- positional, with bundling (`-rf`) and a `--` terminator (`hasOpt`/`posArg`).
--
-- Phase B (read paths) + Phase C write paths above. Mutations auto-commit when the
-- store is a git repo. `show` and `insert` invoke gpg SHELL-FREE via execCapture /
-- execStatus (explicit argv, no quoting or injection); `insert` streams the passphrase
-- to gpg over stdin, so the secret is never on a command line and no plaintext tmpfile
-- is created; `mv`/`cp` build the parent dir with the prelude `dirName`/`makeDir` (no
-- shell `$(dirname …)`); `ls` renders the tree natively (recursion over `readDir`); `git`
-- forwards its argv shell-free with the terminal inherited. (`find`/`grep` remain shell
-- pipelines; `generate` keeps its secret in-shell; the clipboard tool receives the secret
-- on STDIN, never argv.) Every user value interpolated into a shell string goes through
-- `shQuote` (POSIX single-quoting), so those pipelines are injection-proof too. `edit`
-- decrypts into $EDITOR on a RAMFS temp (removed after) and re-encrypts on save. The `-c`
-- clipboard path SAVES the prior clipboard and RESTORES it after 45s (if still ours), rather
-- than blanking it — the secret is compared/copied inside one backgrounded `sh -c` that reads
-- it on stdin (never argv). Recursive `rm -r` / directory `mv`/`cp` shell out to `rm`/`cp`
-- SHELL-FREE (explicit argv). Overwriting an existing entry asks first unless `-f`.
--
-- Command dispatch is a string-literal `case`; other branches use guards + `otherwise`.
-- Path/length handling uses the prelude Str helpers (`dirName`, `chomp`, `readInt`).

-- The store directory: $PASSWORD_STORE_DIR, else $HOME/.password-store. A 0-arg CAF:
-- each reference re-runs `getEnv` and yields a fresh String (top-level CAFs are not
-- memoized across uses), so no dummy argument is needed to avoid shared-CAF aliasing.
storeDir :: String
storeDir = resolveStore (getEnv "PASSWORD_STORE_DIR")

-- Resolve the store dir from the (already-read) $PASSWORD_STORE_DIR value: use it if
-- non-empty, else fall back to $HOME/.password-store. `sd` is a PARAMETER (evaluated
-- exactly once by the caller), so `getEnv` runs once and the borrowed-then-moved value
-- is not re-materialized. A `where sd = getEnv …` binding instead re-runs the effectful
-- CAF per reference (`strLen sd` + the returned `sd`), which both double-read the env
-- AND leaked the guard-test copy — a real leak the drop-verifier modelled as one shared
-- value and so missed.
resolveStore :: String -> String
resolveStore sd
  | strLen sd > 0 = sd
  | otherwise     = strAppend (getEnv "HOME") "/.password-store"

-- Path join, like Haskell's System.FilePath `</>`: join with a single '/', collapsing a
-- separator when the left already ends in one. A pure `String -> String -> String`; an
-- infix `a </> b` lowers to the ordinary call `(</>) a b`, i.e. the SAME `axion_strcat`
-- sequence a hand-written `strAppend` emits — zero abstraction cost. NB: both arms consume
-- `b` only THROUGH `strAppend` (a borrow), never returning it bare — so `b` stays a borrowed
-- param the caller reclaims. A `| … = b` arm (Haskell's "absolute right wins") would instead
-- make `b` an owned param returned on one path but only borrowed at the `strAppend` tail of
-- the others, where reclaim_cond_escape leaves a documented conservative leak. Entry names
-- are never absolute here, so dropping that case is both leak-free AND safer.
infixr 5 </>
(</>) :: String -> String -> String
(</>) a b
  | hasSuffix "/" a = strAppend a b
  | otherwise       = strAppend a (strAppend "/" b)

-- The .gpg file backing entry <name>.
entryPath :: String -> String
entryPath name = storeDir </> (name ++ ".gpg")

-- `chomp` (drop a trailing newline) and `dirName` (parent directory) come from the
-- prelude's Str helpers now — no local copies needed.

-- Build a shell-free argv (elements '\n'-joined) for `gpg -d` of one entry. The path is
-- passed to execvp verbatim — no quoting, no shell, so a name with any character is safe.
decryptArgv :: String -> String
decryptArgv entry = "gpg\n-d\n--quiet\n" ++ entry

-- POSIX single-quote a string for safe `sh -c` interpolation: wrap in '…' and
-- rewrite every embedded ' as '\'' (close-quote, escaped-quote, reopen-quote).
-- Inside single quotes the shell treats every other byte literally, so the result
-- is injection-proof for ARBITRARY input — the `ls`/`find`/`grep`/`generate`/commit
-- pipelines below interpolate user argv only through this. (byte 39 is `'`.)
shQuote :: String -> String
shQuote s = "'" ++ shEsc s 0 (strLen s) ++ "'"
shEsc :: String -> Int -> Int -> String
shEsc s i n =
  if i >= n then ""
  else (if charAt i s == 39
        then "'\\''" ++ shEsc s (i + 1) n
        else substr i 1 s ++ shEsc s (i + 1) n)

-- The first line of a decrypted entry (up to, not including, the first '\n') — the
-- password, for the `-c` clipboard path. Built char-by-char (byte 10 is '\n').
firstLine :: String -> String
firstLine s = firstLineGo s 0 (strLen s)
firstLineGo :: String -> Int -> Int -> String
firstLineGo s i n =
  if i >= n then ""
  else (if charAt i s == 10 then "" else substr i 1 s ++ firstLineGo s (i + 1) n)

-- The n-th line (1-indexed) of a decrypted entry — the `pass show -c<n>` selector (upstream
-- copies line <n>, default 1). `skipLines` advances past (n-1) newlines, then `firstLineGo`
-- reads that line to its end. Out of range → "".
skipLines :: String -> Int -> Int -> Int -> Int
skipLines s i n k =
  if k <= 0 then i
  else if i >= n then i
  else if charAt i s == 10 then skipLines s (i + 1) n (k - 1)
  else skipLines s (i + 1) n k
nthLine :: Int -> String -> String
nthLine ln s = firstLineGo s (skipLines s 0 (strLen s) (ln - 1)) (strLen s)

-- Is command `c` on PATH? (0 = yes.) A shell probe with no user input — injection-safe.
hasCmd :: String -> Int
hasCmd c = runStatus (("command -v " ++ shQuote c) ++ " >/dev/null 2>&1")

-- The clipboard COPY tool as a shell-free argv (newline-joined), or "" if none is
-- installed. Wayland (wl-copy) is preferred, then X11 (xclip, xsel). The secret is fed on
-- the tool's STDIN (never argv), so it is invisible in ps/proc.
clipTool :: String
clipTool
  | hasCmd "wl-copy" == 0 = "wl-copy"
  | hasCmd "xclip" == 0   = "xclip\n-selection\nclipboard"
  | hasCmd "xsel" == 0    = "xsel\n-b\n-i"
  | otherwise             = ""

-- The matching clipboard READ (paste) and shell COPY commands (used by the restore pipeline).
-- `clipPaste` reads the current clipboard to stdout; `clipCopyCmd` sets it from stdin.
clipPaste :: String
clipPaste
  | hasCmd "wl-copy" == 0 = "wl-paste --no-newline"
  | hasCmd "xclip" == 0   = "xclip -selection clipboard -o"
  | hasCmd "xsel" == 0    = "xsel -b -o"
  | otherwise             = "true"
clipCopyCmd :: String
clipCopyCmd
  | hasCmd "wl-copy" == 0 = "wl-copy"
  | hasCmd "xclip" == 0   = "xclip -selection clipboard"
  | hasCmd "xsel" == 0    = "xsel -b -i"
  | otherwise             = "cat >/dev/null"

-- The per-entry SAVE-and-RESTORE clipboard pipeline (upstream's `clip()` behaviour), as ONE
-- `sh -c` line (no embedded newline — that is execStatus's argv separator). It (1) saves the
-- current clipboard base64, (2) reads the secret from STDIN (`pw=$(cat)` — never argv) and puts
-- it on the clipboard, then (3) backgrounds a 45s timer that restores the saved content IFF the
-- clipboard is still our secret (so a later copy is not clobbered). Only shell builtins + the
-- clip tools appear; the secret never reaches a process argument.
clipWithRestore :: String
clipWithRestore =
  "save=$(" ++ clipPaste ++ " 2>/dev/null | base64 | tr -d '\\n'); pw=$(cat); printf '%s' \"$pw\" | "
  ++ clipCopyCmd ++ " >/dev/null 2>&1; ( sleep 45; cur=$(" ++ clipPaste
  ++ " 2>/dev/null | base64 | tr -d '\\n'); if [ \"$cur\" = \"$(printf '%s' \"$pw\" | base64 | tr -d '\\n')\" ]; then printf '%s' \"$save\" | base64 -d | "
  ++ clipCopyCmd ++ " >/dev/null 2>&1; fi ) &"

-- Copy the FIRST LINE of <plaintext> to the clipboard (saving/restoring the prior contents after
-- 45s), then report (to stderr, so a piped stdout stays clean). Aborts if no clipboard tool exists.
-- The secret is fed on the pipeline's STDIN via `execStatus … (firstLine plaintext)`.
clipCopy :: Int -> String -> String -> IO ()
clipCopy ln plaintext name
  | strLen plaintext == 0 = die (strAppend "Error: could not decrypt " name)
  | strLen clipTool == 0  = die "Error: no clipboard tool found (install wl-clipboard, xclip, or xsel)"
  | strLen (nthLine ln plaintext) == 0 =
      die (((("Error: " ++ name) ++ " has no line ") ++ showInt ln) ++ " to copy")
  | otherwise             = do
      execStatus (strAppend "sh\n-c\n" clipWithRestore) (nthLine ln plaintext)
      ePutStrLn (((("Copied " ++ name) ++ " (line ") ++ showInt ln) ++ ") to clipboard. Will clear in 45 seconds.")

-- `pass show`: by DEFAULT copy the LOGIN line (line 2 — the email/username) to the clipboard;
-- `-c[n]` copies line n instead (default 1 = the password); `-s` prints the WHOLE entry to stdout
-- with no clipboard. gpg runs shell-free via execCapture (explicit argv). With no <name>, fall back
-- to an fzf picker (if installed). The name is only ever BORROWED here (never returned from a
-- helper), so the fresh fzf pick and the borrowed argv name both flow into `showFound` without a
-- conditional alias/fresh return (which would desync the interprocedural alias summary → a UAF).
-- `showAll` = the `-s` mode (print everything); otherwise clip line `ln`.
showEntry :: Bool -> Int -> String -> IO ()
showEntry showAll ln name
  | strLen name > 0   = showFound showAll ln name
  | hasCmd "fzf" == 0 = showFound showAll ln fzfPick
  | otherwise         = die "Usage: pass show [-c[n]|-s] <name>"

showFound :: Bool -> Int -> String -> IO ()
showFound showAll ln name
  | fileExists (entryPath name) == 0 =
      die (strAppend "Error: " (strAppend name " is not in the password store."))
  | showAll                          = putStr (execCapture (decryptArgv (entryPath name)) "")
  | otherwise                        = clipCopy ln (execCapture (decryptArgv (entryPath name)) "") name

-- Flag dispatch for `show`: `-s` → print all; `-c[n]` → clip line n (default 1 = password);
-- neither → clip line 2 (the login email — the default).
doShow :: IO ()
doShow
  | hasFlag "s" = showEntry True 0 (posArg 0)
  | hasFlag "c" = showEntry False (optNum "c" 1) (posArg 0)
  | otherwise   = showEntry False 2 (posArg 0)

-- `pass ls [subdir]` / bare `pass`: draw the store as an indented TREE (upstream shells
-- out to tree(1); we render it natively). Each directory level lists its entries sorted,
-- `.gpg` stripped, dotfiles (`.git`, `.gpg-id`) hidden, with the ├──/└──/│ box glyphs and
-- an indent that recurses into subdirectories. The whole subtree is built as one String on
-- the heap (recursion over the prelude `List String` from `lines`), which the linear
-- reclaimer frees soundly — ASan + LSan clean on every backend.
notDot :: String -> Bool
notDot name = not (hasPrefix "." name)

-- Strip a trailing ".gpg" (4 bytes) from an entry file name.
stripGpg :: String -> String
stripGpg name = substr 0 (strLen name - 4) name

-- The child entries of `dir`, dotfiles removed, sorted — NATIVELY: `readDir` reads the
-- directory in-process and the prelude `sort` (partition quicksort, byte order via `Ord
-- String`) runs in-process, so listing the tree spawns ZERO subprocesses (the previous
-- `ls -1a | sort` per directory forked sh+ls+sort for EVERY level — dozens of processes on a
-- real store; this is what made `ls` slower than upstream `pass`, which spawns `tree` once).
-- `sort` over a heap element type used to be rejected by AX0912 (its old quicksort filtered
-- the tail twice — a heap duplication); it now consumes its `%1` list once and reclaims
-- soundly, so this is just the prelude `sort`. `filter` gets its `%1` via closure specialization.
entriesOf :: String -> List String
entriesOf dir = sort (filter notDot (lines (readDir dir)))

glyph :: Bool -> String
glyph isLast = if isLast then "└── " else "├── "

childPrefix :: String -> Bool -> String
childPrefix prefix isLast = strAppend prefix (if isLast then "    " else "│   ")

-- Render `dir`'s subtree, every line carrying `prefix` (the ancestors' │/space columns).
renderTree :: String -> String -> String
renderTree dir prefix = renderList dir prefix (entriesOf dir)

renderList :: String -> String -> List String -> String
renderList dir prefix es = case es of
  Nil -> ""
  Cons e rest ->
    let isLast = null rest in
    strAppend (renderNode dir prefix isLast e) (renderList dir prefix rest)

renderNode :: String -> String -> Bool -> String -> String
renderNode dir prefix isLast name =
  if hasSuffix ".gpg" name
  then strAppend (strAppend (strAppend prefix (glyph isLast)) (stripGpg name)) "\n"
  else strAppend (strAppend (strAppend (strAppend prefix (glyph isLast)) name) "\n")
                 (renderTree (dir </> name) (childPrefix prefix isLast))

-- The FLAT list of entry names under `dir` (relative to `rel`, `.gpg` stripped), '\n'-joined
-- and sorted per level — the candidate list for the fzf picker. Recurses natively via
-- `entriesOf` (readDir), so it too spawns no subprocesses.
-- Join a relative prefix with an entry name (`rel` empty → just the name). `name` here is a
-- BORROWED element of the caller's entry `List String` (which `allEntries` deep-drops), and
-- `collectNode` drops this result — so returning `name` BARE would alias the borrowed element and
-- double-free it (the reuse-gated copy-normalization does NOT fire, because no caller reuses `name`
-- AFTER the call). The empty arm therefore returns a FRESH copy (`strAppend name ""`), keeping the
-- element owned by its list — sound on every backend (ASan+LSan clean). (The verifier does not yet
-- catch this whole-value-passthrough-of-a-borrowed-element class without over-flagging legit
-- closure/HOF views — an interprocedural/monomorphization limitation — so the copy is explicit.)
relJoin :: String -> String -> String
relJoin rel name =
  if strLen rel == 0 then strAppend name "" else strAppend (strAppend rel "/") name

allEntries :: String -> String -> String
allEntries dir rel = collectList dir rel (entriesOf dir)

collectList :: String -> String -> List String -> String
collectList dir rel es = case es of
  Nil -> ""
  Cons e rest -> strAppend (collectNode dir rel e) (collectList dir rel rest)

collectNode :: String -> String -> String -> String
collectNode dir rel name =
  if hasSuffix ".gpg" name
  then strAppend (relJoin rel (stripGpg name)) "\n"
  else allEntries (dir </> name) (relJoin rel name)

-- Interactive entry picker: pipe the store's entry list into fzf and return the chosen name
-- ("" if fzf is cancelled). fzf reads the candidates from the pipe and drives its UI on
-- /dev/tty, writing only the selection to stdout — which runCapture captures. The fresh pick,
-- borrowed by showFound/editEntry, is reclaimed after the call — every path (pick included)
-- is ASan+LSan clean.
fzfPick :: String
fzfPick = chomp (runCapture (strAppend "printf '%s' " (strAppend (shQuote (allEntries storeDir "")) " | fzf --reverse --prompt='pass> '")))

-- `pass` / `pass ls [subdir]`: print the header then the tree (of the whole store, or of
-- <subdir> under it). Mirrors upstream's "Password Store" root label.
doLs :: String -> IO ()
doLs sub
  | strLen sub == 0 = do
      putStrLn "Password Store"
      putStr (renderTree storeDir "")
  | otherwise       = do
      putStrLn sub
      putStr (renderTree (storeDir </> sub) "")

-- `pass find <term>`: list entry names whose path matches <term> (case-insensitive).
doFind :: String -> IO ()
doFind term
  | strLen term == 0 = die "Usage: pass find <term>"
  | otherwise        = putStr (runCapture ("cd " ++ shQuote storeDir ++ " 2>/dev/null && find . -name '*.gpg' 2>/dev/null | sed 's#^\\./##;s#\\.gpg$##' | sort | grep -i -- " ++ shQuote term))

-- `pass grep <search>`: decrypt every entry and print those whose CONTENT matches
-- <search> (case-insensitive), each followed by its indented matching lines. gpg
-- writes plaintext to a pipe grep reads — it never touches disk.
doGrep :: String -> IO ()
doGrep search
  | strLen search == 0 = die "Usage: pass grep <search>"
  | otherwise          = putStr (runCapture ("cd " ++ shQuote storeDir ++ " 2>/dev/null && find . -name '*.gpg' 2>/dev/null | sort | while read f; do m=$(gpg -d --quiet \"$f\" 2>/dev/null | grep -i -- " ++ shQuote search ++ "); if [ -n \"$m\" ]; then echo \"${f#./}\" | sed 's#\\.gpg$#:#'; echo \"$m\" | sed 's/^/  /'; fi; done"))

-- The store's recipient file (holds the GPG key id entries are encrypted to).
gpgId :: String
gpgId = storeDir </> ".gpg-id"

-- Auto-commit the store when it is a git repo — silent and non-fatal, mirroring
-- upstream pass, which commits after every mutation under version control. The
-- trailing `; true` makes the status 0 whether or not the store is a repo.
gitCommit :: String -> Int
gitCommit msg =
  runStatus (("d=" ++ shQuote storeDir ++ "; test -d \"$d/.git\" && git -C \"$d\" add -A && git -C \"$d\" commit -q -m ") ++ (shQuote msg ++ " >/dev/null 2>&1; true"))

-- `pass rm <name>`: delete an entry, then commit. removeFile returns 0/-1 (its
-- result is forced then discarded by the `do` sequencing).
-- `pass rm [-r] [-f] <name>`: delete a single entry, or (with `-r`) a whole subtree. A subtree
-- is removed SHELL-FREE via `rm -rf` (explicit argv — no shell, injection-safe). `-f` suppresses
-- the "not in the store" error (like `rm -f`).
doRm :: String -> IO ()
doRm name
  | strLen name == 0                 = die "Usage: pass rm [-r] <name>"
  | fileExists (entryPath name) == 1 = do
      removeFile (entryPath name)
      gitCommit (strAppend "Remove " name)
      putStrLn (strAppend "Removed " name)
  | (hasFlag "r") && (fileExists (storeDir </> name) == 1) = do
      execStatus (strAppend "rm\n-rf\n--\n" (storeDir </> name)) ""
      gitCommit (strAppend "Remove " name)
      putStrLn (strAppend "Removed " name)
  | hasFlag "f"                      = skip
  | otherwise                        =
      die (strAppend "Error: " (strAppend name " is not in the password store."))

-- `pass mv <old> <new>`: rename an entry, creating the new parent dir with the prelude
-- `dirName` + `makeDir` (no shell `$(dirname …)`), then commit. renameFile is a primitive.
doMv :: String -> String -> IO ()
doMv old new
  | strLen old == 0                 = die "Usage: pass mv <old> <new>"
  | strLen new == 0                 = die "Usage: pass mv <old> <new>"
  | fileExists (entryPath old) == 1 = do   -- a single .gpg entry
      makeDir (dirName (entryPath new))
      renameFile (entryPath old) (entryPath new)
      gitCommit (("Rename " ++ old) ++ (" to " ++ new))
      putStrLn ((old ++ " -> ") ++ new)
  | fileExists (storeDir </> old) == 1 = do   -- a subdirectory (rename(2) works on dirs)
      makeDir (dirName (storeDir </> new))
      renameFile (storeDir </> old) (storeDir </> new)
      gitCommit (("Rename " ++ old) ++ (" to " ++ new))
      putStrLn ((old ++ " -> ") ++ new)
  | otherwise                       =
      die (strAppend "Error: " (strAppend old " is not in the password store."))

-- `pass cp <old> <new>`: copy an entry (shell-free `cp` via execStatus with an explicit
-- argv), creating the new parent dir, then commit.
doCp :: String -> String -> IO ()
doCp old new
  | strLen old == 0                 = die "Usage: pass cp <old> <new>"
  | strLen new == 0                 = die "Usage: pass cp <old> <new>"
  | fileExists (entryPath old) == 1 = do   -- a single .gpg entry
      makeDir (dirName (entryPath new))
      execStatus (("cp\n--\n" ++ entryPath old) ++ ("\n" ++ entryPath new)) ""
      gitCommit (("Copy " ++ old) ++ (" to " ++ new))
      putStrLn ((old ++ " -> ") ++ new)
  | fileExists (storeDir </> old) == 1 = do   -- a subdirectory (recursive copy, shell-free)
      makeDir (dirName (storeDir </> new))
      execStatus (("cp\n-r\n--\n" ++ (storeDir </> old)) ++ ("\n" ++ (storeDir </> new))) ""
      gitCommit (("Copy " ++ old) ++ (" to " ++ new))
      putStrLn ((old ++ " -> ") ++ new)
  | otherwise                       =
      die (strAppend "Error: " (strAppend old " is not in the password store."))

-- The generator runs entirely inside the shell: a random `A-Za-z0-9` password is
-- drawn from /dev/urandom, piped to `gpg` over stdin via the `printf` BUILTIN
-- (never a process argv, so the secret is invisible in `ps`/`/proc`), and only the
-- final printed copy crosses back into Axión. The length is a real Int (parsed by the
-- prelude `readInt`, defaulted to 25), so only a validated number reaches `head -c`.
-- The character class for the random draw: `[:alnum:]` with `-n` (no symbols), else the full
-- printable-punctuation + alphanumeric set (upstream's default). A `tr` class in single quotes —
-- no user input — so it is injection-safe.
genCharset :: Bool -> String
genCharset noSym = if noSym then "'[:alnum:]'" else "'[:punct:][:alnum:]'"

genCmd :: String -> String -> Int -> String -> String
genCmd entry gpgid len charset =
  "e=" ++ shQuote entry ++ "; g=" ++ shQuote gpgid ++ "; mkdir -p \"$(dirname \"$e\")\" && pw=$(LC_ALL=C tr -dc " ++ charset ++ " </dev/urandom | head -c " ++ showInt len ++ ") && printf '%s' \"$pw\" | gpg -e --batch --yes -r \"$(head -1 \"$g\")\" -o \"$e\" && printf '%s\\n' \"$pw\""

-- `generate -i` (in-place): replace ONLY the first line of an EXISTING entry with the new
-- password, keeping any subsequent metadata lines. Decrypts the entry, swaps line 1 for the
-- fresh password (`tail -n +2` keeps the rest), re-encrypts, and prints the new password. The
-- secret never touches a process argv (piped to gpg via a shell group). Fails if the entry does
-- not exist (empty decrypt → the `&&` chain aborts → `genReport` reports the error).
genInPlaceCmd :: String -> String -> Int -> String -> String
genInPlaceCmd entry gpgid len charset =
  "e=" ++ shQuote entry ++ "; g=" ++ shQuote gpgid ++ "; pw=$(LC_ALL=C tr -dc " ++ charset ++ " </dev/urandom | head -c " ++ showInt len ++ ") && old=$(gpg -d --quiet \"$e\" 2>/dev/null) && { printf '%s\\n' \"$pw\"; printf '%s' \"$old\" | tail -n +2; } | gpg -e --batch --yes -r \"$(head -1 \"$g\")\" -o \"$e\" && printf '%s\\n' \"$pw\""

-- Report the outcome of `generate`: an empty capture means the pipeline failed (most often
-- no `.gpg-id`); otherwise commit and either print the password (header + value) or, with
-- `-c`, copy it to the clipboard instead of echoing it.
genReport :: Bool -> String -> String -> IO ()
genReport clip name out
  | strLen out == 0 =
      die (("Error: could not generate " ++ name) ++ " (is the store initialized with a .gpg-id?)")
  | clip            = do
      gitCommit (strAppend "Generate " name)
      clipCopy 1 out name
  | otherwise       = do
      putStrLn (("The generated password for " ++ name) ++ " is:")
      gitCommit (strAppend "Generate " name)
      putStr out

-- `pass generate [-c] [-n] [-f] <name> [length]`: create a random password, encrypt it, then
-- print it (or copy it with `-c`). `-n` drops symbols; `-f` overwrites an existing entry without
-- asking. Flags are parsed by `hasFlag`; the name/length are the positionals (`posArg`).
genEntry :: Bool -> Bool -> Bool -> Bool -> String -> String -> IO ()
genEntry clip noSym force inPlace name lenArg
  | strLen name == 0 = die "Usage: pass generate [-c] [-n] [-i] <name> [length]"
  | inPlace          = do   -- replace only the first line of an existing entry
      out <- runCapture (genInPlaceCmd (entryPath name) gpgId (fromMaybe 25 (readInt lenArg)) (genCharset noSym))
      genReport clip name out
  | otherwise        = do
      ensureOverwrite force name
      out <- runCapture (genCmd (entryPath name) gpgId (fromMaybe 25 (readInt lenArg)) (genCharset noSym))
      genReport clip name out

doGenerate :: IO ()
doGenerate = genEntry (hasFlag "c") (hasFlag "n") (hasFlag "f") (hasFlag "i") (posArg 0) (posArg 1)

-- Build a shell-free argv for `gpg -e` to <entry> for <recipient>. gpg reads the
-- plaintext from stdin (execStatus's second argument) — so the secret never appears
-- on a command line, and no plaintext tmpfile is ever created.
encryptArgv :: String -> String -> String
encryptArgv recipient entry =
  ("gpg\n-e\n--batch\n--yes\n-r\n" ++ recipient) ++ ("\n-o\n" ++ entry)

-- Encrypt <secret> to <name>'s .gpg for <recipient>: create the parent dir, then run gpg
-- with the plaintext on stdin (never argv, no tmpfile). Shared by `insert` and `edit`.
encryptTo :: String -> String -> String -> IO ()
encryptTo name recipient secret = do
  makeDir (dirName (entryPath name))
  execStatus (encryptArgv recipient (entryPath name)) secret
  skip

-- Encrypt <secret> to <name> for <recipient>, then commit and report (the `insert` path).
insertEncrypt :: String -> String -> String -> IO ()
insertEncrypt name recipient secret = do
  encryptTo name recipient secret
  gitCommit (strAppend "Add " name)
  putStrLn (strAppend "Added " name)

-- Finish `insert` once both reads are in: reject an empty or mismatched entry, else
-- encrypt. The recipient key id is read from the store's .gpg-id (newline chomped).
insertFinish :: String -> String -> String -> IO ()
insertFinish name p1 p2
  | strLen p1 == 0 = die "Error: no password entered, aborting"
  | p1 == p2       = insertEncrypt name (chomp (readFile (gpgId))) p1
  | otherwise      = die "Error: the entered passwords do not match, aborting"

-- Read one prompted line, echo-OFF by default, echo-ON with `-e` (`readLine`). Both are
-- effectful String producers (`:: Int -> String`), so either can be bound with `<-`.
readOne :: Bool -> String
readOne echo = if echo then readLine 0 else readSecret 0

-- `pass insert [-e] <name>`: read a passphrase twice (echo off, or on with `-e`), then store
-- it. The prompts go to stderr (ePutStr) — where prompts belong, so they never pollute a piped
-- stdout — and flush immediately before each read.
doInsert :: Bool -> Bool -> String -> IO ()
doInsert echo force name
  | strLen name == 0 = die "Usage: pass insert [-e|-m] <name>"
  | otherwise        = do
      ensureOverwrite force name
      ePutStr (strAppend "Enter password for " (strAppend name ": "))
      p1 <- readOne echo
      ePutStr "Retype password: "
      p2 <- readOne echo
      insertFinish name p1 p2

-- `pass insert -m <name>`: read a MULTILINE entry from stdin until EOF (Ctrl-D) and store
-- it verbatim. Reading all of stdin is delegated to `cat` under `runCapture` — its child
-- inherits our stdin, so `cat` drains it to EOF (the runtime `readLine`/`readSecret` return
-- "" at EOF, indistinguishable from a blank line, so they cannot read a multiline body — a
-- SURFACED gap: a `readAll`/EOF-sentinel stdin primitive would remove the `cat` shell-out).
doInsertMulti :: Bool -> String -> IO ()
doInsertMulti force name
  | strLen name == 0 = die "Usage: pass insert -m <name>"
  | otherwise        = do
      ensureOverwrite force name
      ePutStrLn (("Enter contents of " ++ name) ++ " and press Ctrl+D when finished:")
      body <- runCapture "cat"
      insertMultiFinish name body

insertMultiFinish :: String -> String -> IO ()
insertMultiFinish name body
  | strLen body == 0 = die "Error: no input, aborting"
  | otherwise        = insertEncrypt name (chomp (readFile (gpgId))) body

-- `pass insert [-m|-e] [-f] <name>`: route to the multiline reader (`-m`) or the passphrase
-- reader (echo per `-e`). `-f` overwrites an existing entry without asking (via `ensureOverwrite`).
doInsertCmd :: IO ()
doInsertCmd
  | hasFlag "m" = doInsertMulti (hasFlag "f") (posArg 0)
  | otherwise   = doInsert (hasFlag "e") (hasFlag "f") (posArg 0)

-- The current plaintext of <name> ("" if the entry does not yet exist — `edit` of a new
-- name starts empty, like upstream). Decrypts shell-free via execCapture.
currentPlain :: String -> String
currentPlain name =
  if fileExists (entryPath name) == 1
  then execCapture (decryptArgv (entryPath name)) ""
  else ""

-- The directory to hold the transient plaintext while editing. Upstream prefers a RAMFS
-- (`/dev/shm`) so the cleartext never touches persistent disk; fall back to $TMPDIR, then
-- /tmp. (Editors may still leave swap/undo files — the standard `pass edit` caveat.)
editDir :: String
editDir
  | fileExists "/dev/shm" == 1 = "/dev/shm"
  | strLen (getEnv "TMPDIR") > 0 = getEnv "TMPDIR"
  | otherwise = "/tmp"

-- A unique temp path for editing <name>: a randomly-named file (so concurrent edits don't
-- clash) placed FLAT in editDir, so a single removeFile fully cleans it up (no lingering
-- subdir). Computed ONCE by the caller and threaded — randHex re-runs per reference.
editTmp :: String -> String
editTmp name =
  editDir </> strAppend "pass-axi-" (strAppend (randHex 8) (strAppend "-" (strAppend (baseName name) ".txt")))

-- `pass edit <name>`: decrypt (or start empty) into a transient RAMFS file, open $EDITOR
-- (default vi) on it — interactive, the terminal is inherited — then re-encrypt the result.
-- The editor runs through the shell so `$EDITOR` may carry its own flags (e.g. `emacs -nw`);
-- only the temp PATH is interpolated, via shQuote, so it is injection-safe.
-- With no name, fall back to an fzf picker over the store (if fzf is installed). As with
-- `show`, the name is only borrowed — the fresh pick and the given name flow into `editEntry`
-- directly, never returned from a helper (which would alias the param → a use-after-free).
doEdit :: String -> IO ()
doEdit name
  | strLen name > 0   = editEntry name
  | hasCmd "fzf" == 0 = editEntry fzfPick
  | otherwise         = die "Usage: pass edit <name>"

editEntry :: String -> IO ()
editEntry name = runEdit name (editTmp name) (currentPlain name)

runEdit :: String -> String -> String -> IO ()
runEdit name tmp orig = do
  makeDir (dirName tmp)
  writeFile tmp orig
  runStatus (strAppend "${EDITOR:-vi} " (shQuote tmp))
  finishEdit name tmp orig

finishEdit :: String -> String -> String -> IO ()
finishEdit name tmp orig = do
  new <- readFile tmp
  removeFile tmp
  editDecide name orig new

-- Commit the edit only if the content actually changed and is non-empty (mirroring
-- upstream, which skips the re-encrypt/commit when the file is unchanged or emptied).
editDecide :: String -> String -> String -> IO ()
editDecide name orig new
  | new == orig     = putStrLn (strAppend "Password for " (strAppend name " unchanged."))
  | strLen new == 0 = die "Edit aborted: empty content, not saving."
  | otherwise       = do
      encryptTo name (chomp (readFile (gpgId))) new
      gitCommit (strAppend "Edit " name)
      putStrLn (strAppend "Edited " name)

-- `pass git <args…>`: run git inside the store, forwarding ALL trailing arguments verbatim.
-- Shell-free (execStatus with an explicit argv) and stdio-inherited, so the pager, colours
-- and prompts of `git log`/`git push`/… work exactly as under a real terminal.
doGit :: IO ()
doGit = do
  execStatus (gitArgv storeDir (argvFrom 1)) ""
  skip

-- The git argv (newline-joined): `git -C <store> <rest…>`; omit the trailing field when
-- there are no forwarded args (a lone empty argv element would confuse git).
gitArgv :: String -> String -> String
gitArgv store rest
  | strLen rest == 0 = ("git\n-C\n" ++ store)
  | otherwise        = (("git\n-C\n" ++ store) ++ "\n") ++ rest

-- The program arguments from index `i` onward, '\n'-joined (the shell-free argv tail for a
-- passthrough). Reads argv by index (`getArg` yields "" past the end) rather than splitting
-- a `List String`, avoiding the heap-element aliasing that a split would introduce.
argvFrom :: Int -> String
argvFrom i
  | strLen (getArg i) == 0 = ""
  | otherwise              = joinFrom i
joinFrom :: Int -> String
joinFrom i =
  let rest = argvFrom (i + 1) in
  if strLen rest == 0 then getArg i else (getArg i ++ "\n") ++ rest

-- A no-op `IO ()` used to discard an `Int`-returning capability call at the tail of a `do`
-- (Axión has no `pure ()`; `putStr ""` is the unit action — it only flushes).
skip :: IO ()
skip = putStr ""

-- ─── argv flag parsing (getopt-style over the indexed `getArg`) ──────────────────────────
-- Flags are single-char `-x` tokens in the LEADING run of the command's arguments (before the
-- first positional); bundling (`-rf` = `-r -f`) and a `--` terminator are honoured, as in real
-- getopt. `getArg` is a pure capability read (fresh copies, not effectful), so these stay pure.

-- Is byte `c` present in `s[i..n)`?
charInStr :: Int -> String -> Int -> Int -> Bool
charInStr c s i n =
  if i >= n then False
  else if charAt i s == c then True
  else charInStr c s (i + 1) n

-- Is the single-char option byte `c` set among the leading flag tokens from argv index `i`?
optFrom :: Int -> Int -> Bool
optFrom c i =
  let a = getArg i in
  if strLen a == 0 then False
  else if a == "--" then False
  else if hasPrefix "-" a then charInStr c a 1 (strLen a) || optFrom c (i + 1)
  else False

-- Is the single-char option in `f` (its first byte) set in the command's leading flags?
hasFlag :: String -> Bool
hasFlag f = optFrom (charAt 0 f) 1

-- Index of the first positional argument (past the leading flag run and one optional `--`).
posBase :: Int -> Int
posBase i =
  let a = getArg i in
  if strLen a == 0 then i
  else if a == "--" then i + 1
  else if hasPrefix "-" a then posBase (i + 1)
  else i

-- The r-th (0-based) POSITIONAL argument of the command (argv past its flags); "" if absent.
posArg :: Int -> String
posArg r = getArg (posBase 1 + r)

-- Index of byte `c` in `s[i..n)`, or -1.
idxOf :: Int -> String -> Int -> Int -> Int
idxOf c s i n =
  if i >= n then 0 - 1
  else if charAt i s == c then i
  else idxOf c s (i + 1) n

-- The numeric suffix ATTACHED to a single-char option (getopt optional-arg style: `-c3` → 3),
-- scanning the leading flag tokens; `dflt` if the flag is absent or bare (`-c`). Used for
-- `show -c[n]` (copy the n-th line).
optNumFrom :: Int -> Int -> Int -> Int
optNumFrom c dflt i =
  let a = getArg i in
  if strLen a == 0 then dflt
  else if a == "--" then dflt
  else if hasPrefix "-" a
       then optNumTok c dflt a (idxOf c a 1 (strLen a)) i
       else dflt
optNumTok :: Int -> Int -> String -> Int -> Int -> Int
optNumTok c dflt a k i =
  if k < 0 then optNumFrom c dflt (i + 1)
  else fromMaybe dflt (readInt (substr (k + 1) (strLen a - (k + 1)) a))
optNum :: String -> Int -> Int
optNum f dflt = optNumFrom (charAt 0 f) dflt 1

-- `pass init <gpg-id>`: create the store directory and write its `.gpg-id` recipient file,
-- then commit. New entries encrypt to this key id (see `insertFinish`/`genCmd`/`encryptTo`).
doInit :: String -> IO ()
doInit gid
  | strLen gid == 0 = die "Usage: pass init <gpg-id>"
  | otherwise       = do
      makeDir storeDir
      writeFile gpgId (strAppend gid "\n")
      runStatus (("d=" ++ shQuote storeDir) ++ "; test -d \"$d/.git\" || git -C \"$d\" init -q >/dev/null 2>&1; true")
      gitCommit (strAppend "Set GPG id to " gid)
      putStrLn (strAppend "Password store initialized for " gid)

-- Before an `insert`/`generate` would OVERWRITE an existing entry, ask (unless `-f`). A "no"
-- (the default, and what a non-interactive empty stdin yields) aborts via `die`.
ensureOverwrite :: Bool -> String -> IO ()
ensureOverwrite force name
  | force                            = skip
  | fileExists (entryPath name) == 0 = skip
  | otherwise                        = do
      ePutStr (("An entry already exists for " ++ name) ++ ". Overwrite it? [y/N] ")
      ans <- readLine 0
      confirmOverwrite ans
confirmOverwrite :: String -> IO ()
confirmOverwrite ans
  | (ans == "y") || (ans == "Y") = skip
  | otherwise                    = die "Not overwriting."

doVersion :: IO ()
doVersion = putStrLn "pass-axi — a password-store (pass) clone in Axión, v0.1"

doHelp :: IO ()
doHelp = putStr usageText
usageText :: String
usageText =
  "Usage:\n" ++
  "  pass init <gpg-id>            initialize the store for a GPG key id\n" ++
  "  pass [ls] [subdir]            list entries as a tree\n" ++
  "  pass show [-c[n]|-s] [name]  clip the login line (2) by default; -c[n] clips line n (1=pw); -s prints all\n" ++
  "  pass find <term>              list entry names matching term\n" ++
  "  pass grep <text>              search decrypted contents\n" ++
  "  pass insert [-e|-m] [-f] name add an entry (-e echo, -m multiline, -f force)\n" ++
  "  pass edit [name]              edit an entry in $EDITOR\n" ++
  "  pass generate [-c][-n][-f][-i] name [len]  make a random password (-i: in-place, keep metadata)\n" ++
  "  pass rm [-r] [-f] <name>      remove an entry or subtree\n" ++
  "  pass mv <old> <new>           rename an entry or subdir\n" ++
  "  pass cp <old> <new>           copy an entry or subdir\n" ++
  "  pass git <args...>            run git in the store\n" ++
  "  pass help | version\n"

-- Command dispatch on the command word with a string-literal `case` (the catch-all `other`
-- binds the word — a bare `pass <name>` decrypts it). Flags are parsed by `hasFlag`, positional
-- arguments by `posArg` (both over the indexed `getArg`, fresh copies, never a `List String`).
dispatch :: String -> IO ()
dispatch cmd = case cmd of
  "init"      -> doInit (posArg 0)
  "show"      -> doShow
  "ls"        -> doLs (posArg 0)
  "list"      -> doLs (posArg 0)
  "find"      -> doFind (posArg 0)
  "search"    -> doFind (posArg 0)
  "grep"      -> doGrep (posArg 0)
  "rm"        -> doRm (posArg 0)
  "remove"    -> doRm (posArg 0)
  "delete"    -> doRm (posArg 0)
  "mv"        -> doMv (posArg 0) (posArg 1)
  "rename"    -> doMv (posArg 0) (posArg 1)
  "cp"        -> doCp (posArg 0) (posArg 1)
  "copy"      -> doCp (posArg 0) (posArg 1)
  "generate"  -> doGenerate
  "insert"    -> doInsertCmd
  "add"       -> doInsertCmd
  "edit"      -> doEdit (posArg 0)
  "git"       -> doGit
  "help"      -> doHelp
  "--help"    -> doHelp
  "-h"        -> doHelp
  "version"   -> doVersion
  "--version" -> doVersion
  -- bare `axpass -s <name>` == `axpass show -s <name>` (print the whole entry). The flag is
  -- argv[0] here (no subcommand), so the name is argv[1].
  "-s"        -> showEntry True 0 (getArg 1)
  -- bare `axpass` (no args) == `axpass show` (no name): fzf-pick an entry, then clip its login
  -- line. `axpass ls` still draws the tree.
  ""          -> doShow
  -- bare `axpass <name>` == `axpass show -c <name>`: copy the PASSWORD (line 1) to the clipboard.
  -- (`show` WITHOUT the bare shorthand defaults to the login line instead — see doShow.)
  other       -> showEntry False 1 other

main :: IO ()
main = dispatch (getArg 0)
