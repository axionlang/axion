-- A conditional whose arms mix string literals with a freshly built string ONE LEVEL DOWN, in a
-- nested `if`/`case` (axmpv's OSD status: `if not on then " off" else if d /= 0 then " d" ++ … else
-- ""`). Its non-owned leaves are now copied through the nesting so the value is owned on every path
-- and reclaimed — it was refused natively (AX0911: never freed).
status :: Bool -> Int -> String
status on d = "x" ++ (if not on then " off" else if d /= 0 then " d" ++ showInt d else "")

kind :: Int -> String
kind n = "<" ++ (if n < 0 then "neg" else case n of
  0 -> "zero"
  1 -> "one" ++ showInt n
  _ -> "many") ++ ">"

main :: IO ()
main = do
  putStrLn (status True 5 ++ status False 0 ++ status True 0)
  putStrLn (kind (0 - 3) ++ kind 0 ++ kind 1 ++ kind 7)
