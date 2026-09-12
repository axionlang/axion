-- pass.axi — a rewrite of the Linux `pass` (password-store) CLI in Axión.
--
-- Entries are GPG-encrypted files under the store directory ($PASSWORD_STORE_DIR,
-- else $HOME/.password-store); `pass` shells out to `gpg` for crypto (ciphertext
-- stays in files — only plaintext crosses into Axión) and to `find` for listing.
-- Dispatch mirrors upstream pass:
--   pass                    → draw the whole store as a tree
--   pass ls  [subdir]       → tree of the store (or of <subdir>)
--   pass show [-c] [<name>] → decrypt and print <name> (`-c`: copy 1st line to clipboard;
--                             no <name> + fzf installed → pick interactively)
--   pass <name>             → decrypt and print <name> (bare-name shorthand)
--   pass find <term>        → list entries whose path matches <term>
--   pass grep <search>      → search decrypted contents
--   pass rm <name>          → delete an entry
--   pass mv <old> <new>     → rename an entry
--   pass cp <old> <new>     → copy an entry
--   pass generate [-c] <name> [n] → random n-char password (default 25), encrypt it
--   pass insert [-m] <name> → read a passphrase (echo off), or a multiline body (`-m`)
--   pass edit [<name>]      → decrypt into $EDITOR (on RAMFS), re-encrypt on save
--                             (no <name> + fzf installed → pick interactively)
--   pass git <args…>        → run git inside the store (history, push, …)
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
-- decrypts into $EDITOR on a RAMFS temp (removed after) and re-encrypts on save. Still to
-- come: `init`, per-entry clipboard restore.
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

-- A backgrounded shell that clears the clipboard after 45s (upstream's timeout), detached
-- with `&` so `pass` returns immediately. No secret is interpolated (it only sets empty).
clipClearCmd :: String
clipClearCmd
  | hasCmd "wl-copy" == 0 = "( sleep 45; wl-copy --clear >/dev/null 2>&1 ) &"
  | hasCmd "xclip" == 0   = "( sleep 45; printf '' | xclip -selection clipboard >/dev/null 2>&1 ) &"
  | otherwise             = "( sleep 45; printf '' | xsel -b -i >/dev/null 2>&1 ) &"

-- Copy the FIRST LINE of <plaintext> to the clipboard and schedule a 45s clear, then
-- report (to stderr, so a piped stdout stays clean). Aborts if no clipboard tool exists.
clipCopy :: String -> String -> IO ()
clipCopy plaintext name
  | strLen plaintext == 0 = die (strAppend "Error: could not decrypt " name)
  | strLen clipTool == 0  = die "Error: no clipboard tool found (install wl-clipboard, xclip, or xsel)"
  | otherwise             = do
      execStatus clipTool (firstLine plaintext)
      runStatus clipClearCmd
      ePutStrLn (("Copied " ++ name) ++ " to clipboard. Will clear in 45 seconds.")

-- `pass show [-c] [<name>]`: decrypt the entry (gpg via execCapture — explicit argv, no
-- shell) and either print it or (`-c`) copy its first line to the clipboard. With no name,
-- fall back to an fzf picker over the store (if fzf is installed). The name is only ever
-- BORROWED here (never returned from a helper), so the fresh fzf pick and the borrowed argv
-- name both flow into `showFound` without a conditional alias/fresh return (which would
-- desync the interprocedural alias summary → a use-after-free).
showEntry :: Bool -> String -> IO ()
showEntry clip name
  | strLen name > 0   = showFound clip name
  | hasCmd "fzf" == 0 = showFound clip fzfPick
  | otherwise         = die "Usage: pass show [-c] <name>"

showFound :: Bool -> String -> IO ()
showFound clip name
  | fileExists (entryPath name) == 0 =
      die (strAppend "Error: " (strAppend name " is not in the password store."))
  | clip                             = clipCopy (execCapture (decryptArgv (entryPath name)) "") name
  | otherwise                        = putStr (execCapture (decryptArgv (entryPath name)) "")

-- Parse the optional leading `-c` flag of `show` (`pass show -c <name>`); a bare name has
-- no flag. The catch-all `pass <name>` shorthand calls `showEntry False` directly.
doShow :: String -> String -> IO ()
doShow a b
  | a == "-c" = showEntry True b
  | otherwise = showEntry False a

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
-- Join a relative prefix with an entry name (`rel` empty → just the name). The empty arm
-- returns the `name` PARAM while the other returns a fresh string — a CONDITIONAL param/fresh
-- return that `collectNode` compounds by also borrowing `name` in `dir </> name`. That shape
-- used to compile to a use-after-free (the caller dropped the aliased result and freed the
-- still-borrowed `name`); core.rs now copy-normalizes such a bare-param return automatically,
-- so this idiomatic form is sound on every backend (ASan+LSan clean).
relJoin :: String -> String -> String
relJoin rel name = if strLen rel == 0 then name else strAppend (strAppend rel "/") name

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
doRm :: String -> IO ()
doRm name
  | strLen name == 0                 = die "Usage: pass rm <name>"
  | fileExists (entryPath name) == 1 = do
      removeFile (entryPath name)
      gitCommit (strAppend "Remove " name)
      putStrLn (strAppend "Removed " name)
  | otherwise                        =
      die (strAppend "Error: " (strAppend name " is not in the password store."))

-- `pass mv <old> <new>`: rename an entry, creating the new parent dir with the prelude
-- `dirName` + `makeDir` (no shell `$(dirname …)`), then commit. renameFile is a primitive.
doMv :: String -> String -> IO ()
doMv old new
  | strLen old == 0                 = die "Usage: pass mv <old> <new>"
  | strLen new == 0                 = die "Usage: pass mv <old> <new>"
  | fileExists (entryPath old) == 0 =
      die (strAppend "Error: " (strAppend old " is not in the password store."))
  | otherwise                       = do
      makeDir (dirName (entryPath new))
      renameFile (entryPath old) (entryPath new)
      gitCommit (("Rename " ++ old) ++ (" to " ++ new))
      putStrLn ((old ++ " -> ") ++ new)

-- `pass cp <old> <new>`: copy an entry (shell-free `cp` via execStatus with an explicit
-- argv), creating the new parent dir, then commit.
doCp :: String -> String -> IO ()
doCp old new
  | strLen old == 0                 = die "Usage: pass cp <old> <new>"
  | strLen new == 0                 = die "Usage: pass cp <old> <new>"
  | fileExists (entryPath old) == 0 =
      die (strAppend "Error: " (strAppend old " is not in the password store."))
  | otherwise                       = do
      makeDir (dirName (entryPath new))
      execStatus (("cp\n--\n" ++ entryPath old) ++ ("\n" ++ entryPath new)) ""
      gitCommit (("Copy " ++ old) ++ (" to " ++ new))
      putStrLn ((old ++ " -> ") ++ new)

-- The generator runs entirely inside the shell: a random `A-Za-z0-9` password is
-- drawn from /dev/urandom, piped to `gpg` over stdin via the `printf` BUILTIN
-- (never a process argv, so the secret is invisible in `ps`/`/proc`), and only the
-- final printed copy crosses back into Axión. The length is a real Int (parsed by the
-- prelude `readInt`, defaulted to 25), so only a validated number reaches `head -c`.
genCmd :: String -> String -> Int -> String
genCmd entry gpgid len =
  "e=" ++ shQuote entry ++ "; g=" ++ shQuote gpgid ++ "; mkdir -p \"$(dirname \"$e\")\" && pw=$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c " ++ showInt len ++ ") && printf '%s' \"$pw\" | gpg -e --batch --yes -r \"$(head -1 \"$g\")\" -o \"$e\" && printf '%s\\n' \"$pw\""

-- Report the outcome of `generate`: an empty capture means the pipeline failed (most often
-- no `.gpg-id`); otherwise commit and either print the password (header + value) or, with
-- `-c`, copy it to the clipboard instead of echoing it.
genReport :: Bool -> String -> String -> IO ()
genReport clip name out
  | strLen out == 0 =
      die (("Error: could not generate " ++ name) ++ " (is the store initialized with a .gpg-id?)")
  | clip            = do
      gitCommit (strAppend "Generate " name)
      clipCopy out name
  | otherwise       = do
      putStrLn (("The generated password for " ++ name) ++ " is:")
      gitCommit (strAppend "Generate " name)
      putStr out

-- `pass generate [-c] <name> [length]`: create a random password, encrypt it, then print
-- it (or copy it with `-c`). The leading `-c` flag shifts the name/length arguments.
genEntry :: Bool -> String -> String -> IO ()
genEntry clip name lenArg
  | strLen name == 0 = die "Usage: pass generate [-c] <name> [length]"
  | otherwise        = do
      out <- runCapture (genCmd (entryPath name) gpgId (fromMaybe 25 (readInt lenArg)))
      genReport clip name out

doGenerate :: String -> String -> String -> IO ()
doGenerate a1 a2 a3
  | a1 == "-c" = genEntry True a2 a3
  | otherwise  = genEntry False a1 a2

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

-- `pass insert <name>`: read a passphrase twice with echo off, then store it. The
-- prompts go to stderr (ePutStr) — where prompts belong, so they never pollute a piped
-- stdout — and flush immediately before each echo-off read.
doInsert :: String -> IO ()
doInsert name
  | strLen name == 0 = die "Usage: pass insert <name>"
  | otherwise        = do
      ePutStr (strAppend "Enter password for " (strAppend name ": "))
      p1 <- readSecret 0
      ePutStr "Retype password: "
      p2 <- readSecret 0
      insertFinish name p1 p2

-- `pass insert -m <name>`: read a MULTILINE entry from stdin until EOF (Ctrl-D) and store
-- it verbatim. Reading all of stdin is delegated to `cat` under `runCapture` — its child
-- inherits our stdin, so `cat` drains it to EOF (the runtime `readLine`/`readSecret` return
-- "" at EOF, indistinguishable from a blank line, so they cannot read a multiline body — a
-- SURFACED gap: a `readAll`/EOF-sentinel stdin primitive would remove the `cat` shell-out).
doInsertMulti :: String -> IO ()
doInsertMulti name
  | strLen name == 0 = die "Usage: pass insert -m <name>"
  | otherwise        = do
      ePutStrLn (("Enter contents of " ++ name) ++ " and press Ctrl+D when finished:")
      body <- runCapture "cat"
      insertMultiFinish name body

insertMultiFinish :: String -> String -> IO ()
insertMultiFinish name body
  | strLen body == 0 = die "Error: no input, aborting"
  | otherwise        = insertEncrypt name (chomp (readFile (gpgId))) body

-- Parse the optional leading `-m` (multiline) flag of `insert`.
doInsertCmd :: String -> String -> IO ()
doInsertCmd a b
  | a == "-m" = doInsertMulti b
  | otherwise = doInsert a

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

-- Command dispatch on the command word with a string-literal `case` (the catch-all
-- `other` binds the word — a bare `pass <name>` decrypts it). argv is read via indexed
-- `getArg` (fresh copies), not split into a `List String`.
dispatch :: String -> IO ()
dispatch cmd = case cmd of
  "show"     -> doShow (getArg 1) (getArg 2)
  "ls"       -> doLs (getArg 1)
  "list"     -> doLs (getArg 1)
  "find"     -> doFind (getArg 1)
  "search"   -> doFind (getArg 1)
  "grep"     -> doGrep (getArg 1)
  "rm"       -> doRm (getArg 1)
  "remove"   -> doRm (getArg 1)
  "delete"   -> doRm (getArg 1)
  "mv"       -> doMv (getArg 1) (getArg 2)
  "rename"   -> doMv (getArg 1) (getArg 2)
  "cp"       -> doCp (getArg 1) (getArg 2)
  "copy"     -> doCp (getArg 1) (getArg 2)
  "generate" -> doGenerate (getArg 1) (getArg 2) (getArg 3)
  "insert"   -> doInsertCmd (getArg 1) (getArg 2)
  "add"      -> doInsertCmd (getArg 1) (getArg 2)
  "edit"     -> doEdit (getArg 1)
  "git"      -> doGit
  ""         -> doLs ""
  other      -> showEntry False other

main :: IO ()
main = dispatch (getArg 0)
