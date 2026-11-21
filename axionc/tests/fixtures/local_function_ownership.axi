-- Ownership of local functions (found by the fuzzer's `local_fns` generator; all four were
-- native double frees or use-after-frees, or refused by the verifier):
-- * a GENERIC `where`-local (`cp :: List a -> List a`) used at one type is lowered at that type,
--   so it owns the list whose elements it stores (it had no types: it borrowed and stored them);
-- * a `where`-local returning an element OR a fresh value borrows its list (the element is
--   copied on the fresh path), so the caller can read the list again;
-- * a parameter returned whole on one path (`| j < 2 = tag`) is copied there, in a local or in
--   a top-level function of several clauses (whose parameters are bound as `let tag = _p0`);
-- * a several-clause local that only reads a list borrows it.
lenL :: List String -> Int
lenL xs = case xs of
  Nil -> 0
  Cons _ rest -> 1 + lenL rest

catL :: List String -> String
catL xs = case xs of
  Nil -> "."
  Cons a rest -> a ++ "," ++ catL rest

copied :: List String -> Int
copied xs = lenL (cp xs) + 1
  where
    cp ys = case ys of
      Nil -> Nil
      Cons y rest -> Cons y (cp rest)

firstOr :: List String -> String
firstOr xs = pickW xs ++ "/" ++ catL xs
  where
    pickW ys = case ys of
      Nil -> "none"
      Cons y _ -> y

guarded :: String -> Int -> String
guarded tag k =
  let kind 0 = "zero"
      kind j
        | j < 2 = tag
        | otherwise = tag ++ "!"
  in kind 0 ++ kind 1 ++ kind k

kindTop :: String -> Int -> String
kindTop tag 0 = "zero"
kindTop tag j
  | j < 2 = tag
  | otherwise = tag ++ "!"

reads :: List String -> String
reads xs = kind xs 0 ++ kind xs 3 ++ kind xs 7
  where
    kind ys 0 = "z"
    kind ys j
      | j < 5 = "a"
      | otherwise = catL ys

main :: IO ()
main = do
  putStrLn (showInt (copied (words "a bb ccc")))
  putStrLn (firstOr (words "x y"))
  putStrLn (firstOr Nil)
  putStrLn (guarded ("t" ++ "g") 5)
  let t = "q" ++ "r"
  putStrLn (kindTop t 0 ++ kindTop t 1 ++ kindTop t 9)
  putStrLn (reads (words "p q"))
