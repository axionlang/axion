-- pass.axi — a rewrite of the Linux `pass` (password-store) CLI in Axión.
--
-- Entries are GPG-encrypted files under the store directory ($PASSWORD_STORE_DIR,
-- else $HOME/.password-store); `pass` shells out to `gpg` for crypto (ciphertext
-- stays in files — only plaintext crosses into Axión) and to `find` for listing.
-- Dispatch mirrors upstream pass:
--   pass                    → list the whole store
--   pass ls  [subdir]       → list
--   pass show <name>        → decrypt and print <name>
--   pass <name>             → decrypt and print <name> (bare-name shorthand)
--   pass find <term>        → list entries whose path matches <term>
--   pass grep <search>      → search decrypted contents
--   pass rm <name>          → delete an entry
--   pass mv <old> <new>     → rename an entry
--   pass cp <old> <new>     → copy an entry
--   pass generate <name> [n]→ make a random n-char password (default 25), encrypt it
--   pass insert <name>      → read a passphrase (echo off) and encrypt it
--
-- Phase B (read paths) + Phase C write paths above. Mutations auto-commit when the
-- store is a git repo. `show` and `insert` invoke gpg SHELL-FREE via execCapture /
-- execStatus (explicit argv, no quoting or injection); `insert` streams the passphrase
-- to gpg over stdin, so the secret is never on a command line and no plaintext tmpfile
-- is created; `mv`/`cp` build the parent dir with the prelude `dirName`/`makeDir` (no
-- shell `$(dirname …)`). (`ls`/`find`/`grep` remain shell pipelines; `generate` keeps
-- its secret in-shell.) Every user value interpolated into a shell string goes through
-- `shQuote` (POSIX single-quoting), so those pipelines are injection-proof too. Still
-- to come: `edit`, `git` passthrough.
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

-- `pass show <name>`: decrypt the entry and print it. execCapture runs gpg with an
-- explicit argv (no shell) and returns its stdout — the plaintext.
doShow :: String -> IO ()
doShow name
  | strLen name == 0                 = die "Usage: pass show <name>"
  | fileExists (entryPath name) == 1 =
      putStr (execCapture (decryptArgv (entryPath name)) "")
  | otherwise                        =
      die (strAppend "Error: " (strAppend name " is not in the password store."))

-- `pass ls`: list entry names (relative paths, .gpg stripped), sorted.
doLs :: IO ()
doLs =
  putStr (runCapture ("cd " ++ shQuote storeDir ++ " 2>/dev/null && find . -name '*.gpg' 2>/dev/null | sed 's#^\\./##;s#\\.gpg$##' | sort"))

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

-- Report the outcome of `generate`: an empty capture means the pipeline failed
-- (most often no `.gpg-id` in the store), otherwise echo the header + password.
genReport :: String -> String -> IO ()
genReport name out
  | strLen out == 0 =
      die (("Error: could not generate " ++ name) ++ " (is the store initialized with a .gpg-id?)")
  | otherwise       = do
      putStrLn (("The generated password for " ++ name) ++ " is:")
      gitCommit (strAppend "Generate " name)
      putStr out

-- `pass generate <name> [length]`: create a random password, encrypt it, print it.
doGenerate :: String -> String -> IO ()
doGenerate name lenArg
  | strLen name == 0 = die "Usage: pass generate <name> [length]"
  | otherwise        = do
      out <- runCapture (genCmd (entryPath name) gpgId (fromMaybe 25 (readInt lenArg)))
      genReport name out

-- Build a shell-free argv for `gpg -e` to <entry> for <recipient>. gpg reads the
-- plaintext from stdin (execStatus's second argument) — so the secret never appears
-- on a command line, and no plaintext tmpfile is ever created.
encryptArgv :: String -> String -> String
encryptArgv recipient entry =
  ("gpg\n-e\n--batch\n--yes\n-r\n" ++ recipient) ++ ("\n-o\n" ++ entry)

-- Encrypt <secret> to <name> for <recipient>: create the parent dir, run gpg with the
-- secret on stdin, then commit. All shell-free.
insertEncrypt :: String -> String -> String -> IO ()
insertEncrypt name recipient secret = do
  makeDir (dirName (entryPath name))
  execStatus (encryptArgv recipient (entryPath name)) secret
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

-- Command dispatch on the command word with a string-literal `case` (the catch-all
-- `other` binds the word — a bare `pass <name>` decrypts it). argv is read via indexed
-- `getArg` (fresh copies), not split into a `List String`.
dispatch :: String -> IO ()
dispatch cmd = case cmd of
  "show"     -> doShow (getArg 1)
  "ls"       -> doLs
  "list"     -> doLs
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
  "generate" -> doGenerate (getArg 1) (getArg 2)
  "insert"   -> doInsert (getArg 1)
  "add"      -> doInsert (getArg 1)
  ""         -> doLs
  other      -> doShow other

main :: IO ()
main = dispatch (getArg 0)
