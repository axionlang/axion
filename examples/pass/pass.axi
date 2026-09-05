-- pass.axi — a rewrite of the Linux `pass` (password-store) CLI in Axión.
--
-- Phase B: `show` and `ls`. Entries are GPG-encrypted files under the store
-- directory ($PASSWORD_STORE_DIR, else $HOME/.password-store); `pass` shells out to
-- `gpg` for crypto (ciphertext stays in files — only plaintext crosses into Axión)
-- and to `find` for listing. Dispatch mirrors upstream pass:
--   pass                 → list the whole store
--   pass ls  [subdir]    → list
--   pass show <name>     → decrypt and print <name>
--   pass <name>          → decrypt and print <name> (bare-name shorthand)

-- The store directory: $PASSWORD_STORE_DIR, else $HOME/.password-store. Takes a
-- dummy Int so each use recomputes a fresh String (no shared-CAF aliasing).
storeDir :: Int -> String
storeDir d =
  let sd = getEnv "PASSWORD_STORE_DIR" in
  if strLen sd > 0 then sd else strAppend (getEnv "HOME") "/.password-store"

-- The .gpg file backing entry <name>.
entryPath :: String -> String
entryPath name = strAppend (storeDir 0) (strAppend "/" (strAppend name ".gpg"))

-- `pass show <name>`: decrypt the entry and print it. gpg writes the plaintext to
-- stdout, which runCapture reads; the path is single-quoted (entry names with a
-- literal ' are unsupported for now — see the shell-free-exec TODO).
doShow :: String -> IO ()
doShow name =
  if strLen name > 0
    then
      if fileExists (entryPath name) == 1
        then putStr (runCapture (strAppend "gpg -d --quiet '" (strAppend (entryPath name) "' 2>/dev/null")))
        else putStrLn (strAppend "Error: " (strAppend name " is not in the password store."))
    else putStrLn "Usage: pass show <name>"

-- `pass ls`: list entry names (relative paths, .gpg stripped), sorted.
doLs :: IO ()
doLs =
  putStr (runCapture (strAppend "cd '" (strAppend (storeDir 0) "' 2>/dev/null && find . -name '*.gpg' 2>/dev/null | sed 's#^\\./##;s#\\.gpg$##' | sort")))

main :: IO ()
main =
  let cmd = getArg 0 in
  if cmd == "show" then doShow (getArg 1)
  else if cmd == "ls" then doLs
  else if cmd == "list" then doLs
  else if cmd == "" then doLs
  else doShow cmd
