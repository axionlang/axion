-- A recursive higher-order function whose closure only READS each element borrows its list once
-- specialized, so the caller can use the list again afterwards. The generic `sumWith` must own
-- `xs` (an unknown `f` may keep each element); its clones used to inherit that, so every
-- `sumWith g v` followed by a use of `v` was refused natively (AX0910). Covers a built-in
-- closure, a named function, and lambdas (one passes the element through a generic identity).
-- Passing the SAME list to `sumWith` twice is still refused (AX0001): callers are checked
-- against the generic `sumWith`, as in the editor (LSP), which does not specialize.
idG :: a -> a
idG x = x

myLen :: String -> Int
myLen s = strLen s

sumWith :: (String -> Int) -> List String -> Int
sumWith f xs = case xs of
  Nil -> 0
  Cons x rest -> f x + sumWith f rest

main :: IO ()
main = do
  let v1 = Cons "ab" (Cons (showInt 123) (Cons "" Nil))
  putStrLn (showInt (sumWith strLen v1 + length v1))
  let v2 = Cons "ab" (Cons (showInt 123) (Cons "" Nil))
  putStrLn (showInt (sumWith myLen v2 + length v2))
  let v3 = Cons "ab" (Cons (showInt 123) (Cons "" Nil))
  putStrLn (showInt (sumWith (\s -> strLen (idG s)) v3 + length v3))
  let v4 = Cons "ab" (Cons (showInt 123) (Cons "" Nil))
  putStrLn (showInt (sumWith (\s -> strLen (strAppend s "!")) v4 + length v4))
