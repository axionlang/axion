-- A "view" (a function returning its list's own tail: `tail`, `dropWhile`, `delete`, or a user
-- function of that shape) CONSUMES its list: the caller moves the list in, so the cells and the
-- elements the view skips have no other owner and the view frees them. They used to leak by
-- design ("leak the dropped prefix") — the view's parameter was moved by the caller but owned by
-- nobody. Heap (String) elements make the skipped elements visible to LSan. Leak-gated.
dropShort :: List String -> List String
dropShort xs = case xs of
  Nil -> Nil
  Cons y ys -> if strLen y < 2 then dropShort ys else Cons y ys

short :: String -> Bool
short s = strLen s < 2

main :: IO ()
main = do
  putStrLn (show (tail (Cons (showInt 1) (Cons (showInt 33) Nil))))
  putStrLn (show (dropWhile short (Cons (showInt 1) (Cons (showInt 22) (Cons (showInt 3) Nil)))))
  putStrLn (show (dropShort (Cons (showInt 4) (Cons (showInt 55) Nil))))
  putStrLn (showInt (sum (delete 3 (Cons 1 (Cons 3 (Cons 5 Nil))))))
