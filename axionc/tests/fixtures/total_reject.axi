-- Totality refusals (docs/totality.md): each function is declared total and is not.
{-# TOTAL spin upTo firstJust sign quit useSpin half sel selfApply floatGuard floatLoop #-}
data Shape = Circle Int | Square Int | Tri Int

spin :: Int -> Int
spin n = spin (n + 1)

-- wraps at the largest Int: never stops for n = maxBound
upTo :: Int -> Int -> Int
upTo i n = if i <= n then upTo (i + 1) n else i

firstJust :: List (Maybe Int) -> Int
firstJust xs = case xs of
  Cons (Just x) _ -> x
  Nil -> 0

sign :: Int -> Int
sign x
  | x > 0 = 1
  | x < 0 = 0 - 1

quit :: Int -> Int
quit n = if n > 0 then n else die "negative"

useSpin :: Int -> Int
useSpin n = spin n + 1

half :: Int -> Int -> Int
half a b = a `div` b

sel :: Shape -> Int
sel (Circle r) = r
sel (Square s) = s

apply :: (Int -> Int) -> Int -> Int
apply f x = f x

selfApply :: Int -> Int
selfApply n = if n <= 0 then 0 else apply selfApply (n - 1)

-- NaN fails both guards
floatGuard :: Float -> Int
floatGuard x
  | x > 0.0 = 1
  | x <= 0.0 = 0

floatLoop :: Float -> Float
floatLoop x = if x <. 10.0 then floatLoop (x +. 1.0) else x

main :: Int
main = 0
