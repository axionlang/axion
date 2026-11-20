-- A part of a BORROWED parameter, brought out two levels down by a nested pattern, stored in a NEW
-- value (`Cons s Nil`, `Just inner`, `Cons "k" rest`): the caller keeps its value, so the part has
-- an owner already — the compiler copies it into the new value (was AX0910). And two `case`s in one
-- function binding the same name at different types (`s :: Sh`, `s :: String`) are freed each with
-- its own destructor (was a leak: one name, one drop type).
data Sh = Dot | Tag String Sh

rSh :: Sh -> String
rSh s = case s of
  Dot -> "dot"
  Tag t inner -> t ++ "<" ++ rSh inner ++ ">"

mk :: Int -> String
mk n = "n" ++ showInt n

second :: List String -> List String
second xs = case xs of
  Cons _ (Cons s _) -> Cons s Nil
  _ -> Nil

wrapSh :: Maybe Sh -> Maybe Sh
wrapSh m = case m of
  Just (Tag _ inner) -> Just inner
  _ -> Nothing

tailOf :: Maybe (List String) -> List String
tailOf m = case m of
  Just (Cons _ rest) -> Cons "k" rest
  _ -> Nil

main :: IO ()
main = do
  let l = [mk 1, mk 2, mk 3]
  putStrLn (showInt (length (second l)))
  putStrLn (showInt (length l))
  let m = Just (Tag (mk 4) (Tag (mk 5) Dot))
  putStrLn (case wrapSh m of
    Just s -> rSh s
    Nothing -> "-")
  putStrLn (case m of
    Just s -> rSh s
    Nothing -> "-")
  let t = Just [mk 6, mk 7]
  putStrLn (showInt (length (tailOf t)))
  let p = (mk 8, 8)
  putStrLn (case p of
    (s, k) -> s ++ showInt k)
