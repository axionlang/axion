-- V-1 (docs/call-site-ownership.md): the drop-verifier's SOUND NET for the conditional
-- param-return alias. `condRet` returns its param `x` bare on one branch; `useBoth` reuses
-- `name` after the call. Auto-Drop's copy-normalization makes this safe (the normal build,
-- which this file exercises → verify clean). But with AXION_NO_ALIAS_COPY=1 (copy off), the
-- raw Core is a use-after-free — and the verifier now CATCHES it (DropOfAlias) rather than
-- passing it, so a drop-insertion regression could never ship silently.
condRet :: String -> String -> String
condRet flag x = if strLen flag == 0 then x else strAppend x "!"

useBoth :: String -> String
useBoth name =
  let picked = condRet "" name in
  strAppend "x/" name

main :: IO ()
main = putStrLn (useBoth "ok")
