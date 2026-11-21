-- A getter hands back a part of its argument; storing that result in a new list while the
-- input list is the caller's would give the part two owners. Auto-Drop copies it there; without
-- the copy (`AXION_NO_ALIAS_COPY`) the verifier must see the share through the call.
data P = P String Int

nameOf :: P -> String
nameOf p = case p of
  P a _ -> a

names :: List P -> List String
names xs = case xs of
  Nil -> Nil
  Cons y ys -> Cons (nameOf y) (names ys)

lenS :: List String -> Int
lenS xs = case xs of
  Nil -> 0
  Cons _ r -> 1 + lenS r

main :: IO ()
main = do
  let ps = Cons (P ("a" ++ "") 1) (Cons (P ("bb" ++ "") 2) Nil)
  putStrLn (showInt (lenS (names ps) + length ps))
