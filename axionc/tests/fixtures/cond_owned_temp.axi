-- Regression for the #1 flagship gotcha: a heap-producing conditional NOT in tail position
-- used to leak its owned temp (AX0911) — `putStrLn (if c then <heap> else <heap>)`, a
-- `let x = if …`, or a conditional producing a container consumed elsewhere. Now reclaimed via:
-- `putStr`/`putStrLn` classified fresh-wrt-args; the straight-line tail reclaim accepting a
-- CallDirect that returns no param interior (a user-fn consumer); and `MakeCon`'s deep-drop key
-- resolved in `op_owned_key` so a conditional whose arms are `con …` is owned. Must be LSan-clean.
sink :: String -> Int
sink s = strLen s

main :: IO ()
main = do
  putStrLn (if True then strAppend "a" "b" else strAppend "c" "d")
  putStrLn (showInt (sink (if False then strAppend "x" "y" else strAppend "p" "q")))
  putStrLn (showInt (length (if True then Cons "a" Nil else Cons "b" (Cons "c" Nil))))
