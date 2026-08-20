-- A USER-defined VIEW function (not a prelude builtin, not in `core::view_params`):
-- `myDropWhile` returns a suffix that aliases its list argument's spine. The borrow
-- analysis auto-detects this (the recursive `ys` field escapes via `Cons y ys`) and
-- MOVES the list, so it doesn't double-free natively — the same treatment `drop`
-- gets, now automatic for any function. Expected on interp == cranelift == llvm: 11.
myDropWhile :: (a -> Bool) -> List a -> List a
myDropWhile p xs = case xs of
  Nil -> Nil
  Cons y ys -> if p y then myDropWhile p ys else Cons y ys

lt5 :: Int -> Bool
lt5 n = n < 5

main :: IO ()
main = putStrLn (show (sum (myDropWhile lt5 (range 1 6))))
