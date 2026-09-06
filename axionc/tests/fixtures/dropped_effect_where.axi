-- AX0920: an effectful value bound in `where` but never used. `where` is
-- demand-evaluated, so `_fx` is dropped and its `runStatus` effect NEVER runs — a
-- silent loss, because effects are typed as ordinary Int/String. The compiler warns
-- and points to a `do`/`let` sequence. (`body` IS used, so it does not warn.)
run :: Int -> Int
run d = body
  where
    body = 7
    _fx  = runStatus "true"

main :: Int
main = run 0
