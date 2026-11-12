-- Layout shapes `axionc fmt` must preserve when it moves columns (scripts/fmt-check.sh re-indents every
-- corpus file). An `else` or `in` after a nested block belongs to the OUTER item; bindings of a multi-line
-- `let` are not siblings of the `do` statements; and alternatives must stay right of the `let` binding
-- they sit in, or the block closes early. Expected output: 7, 30, 12, 9.
data Shape = Small | Big

pick :: Int -> Shape -> Int
pick n s =
  if n > 0 then
    case s of
      Small -> 7
      Big -> 8
  else
    0

deepLet :: Shape -> Int
deepLet s =
  let total = case s of
       Small -> 10
       Big -> 20
      other = 20
  in total + other

letThenCase :: Int -> Int
letThenCase n =
  let a = n + 1
      b = a * 2
  in case b of
    12 ->
      let c = b
      in c
    _ -> 0

main :: IO ()
main = do
  let a = pick 1 Small
      b = deepLet Small
  putStrLn (show a)
  putStrLn (show b)
  putStrLn (show (letThenCase 5))
  case a of
    7 -> do
      let d = a + 2
      putStrLn (show d)
    _ -> putStrLn "no"
