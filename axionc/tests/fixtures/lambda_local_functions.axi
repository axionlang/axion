-- Lambdas that call local functions (`where` and `let`), and `let` functions inside a lambda.
-- The lambda is converted to a closure that carries what the local captures; a lambda or
-- `case` binder with the same name as one of those captures does not change which value the
-- local sees.

bumpAll :: List Int -> Int -> List Int
bumpAll xs k = map (\x -> bump x) xs
  where
    bump y = y + k

incAll :: List Int -> Int -> List Int
incAll xs k =
  let inc y = y + k
  in map (\x -> inc x) xs

squares :: List Int -> List Int
squares xs = map (\x -> let sq y = y * x in sq 2 + sq 1) xs

shadowed :: List Int -> Int -> List Int
shadowed xs k = map (\k -> bump k) xs
  where
    bump y = y + k

viaSibling :: Maybe Int -> Int -> Int
viaSibling m k = pick m
  where
    bump y = y + k
    pick mm = case mm of
      Just k -> bump k
      Nothing -> 0

tagged :: List String -> String -> List String
tagged ss tag = map (\s -> tagIt s) ss
  where
    tagIt s = tag ++ ":" ++ s

wrapped :: List String -> String -> List String
wrapped ss tag =
  let wrap s = "<" ++ tag ++ s ++ ">"
  in map (\s -> wrap s) ss

orTag :: List String -> String -> List String
orTag ss tag = map (\s -> pickW s) ss
  where
    pickW s = if strLen s > 1 then s else tag

catL :: List String -> String
catL xs = case xs of
  Nil -> "."
  Cons a rest -> a ++ "," ++ catL rest

-- a `let` function whose parameter shadows a parameter a `where`-local captures
letShadow :: String -> Int -> Int
letShadow tag n =
  let g tag = bump tag + n
  in g "xy" + g tag
  where
    bump x = strLen x * 10 + strLen tag

letShadowS :: String -> String
letShadowS tag =
  let wrap tag = tag ++ pad
  in wrap "a" ++ wrap tag
  where
    pad = "<" ++ tag ++ ">"

main :: IO ()
main = do
  putStrLn (showInt (sum (bumpAll [1, 2, 3] 10)))
  putStrLn (showInt (sum (incAll [1, 2, 3] 10)))
  putStrLn (showInt (sum (squares [1, 2, 3])))
  putStrLn (showInt (sum (shadowed [1, 2, 3] 100)))
  putStrLn (showInt (viaSibling (Just 1) 100))
  putStrLn (catL (tagged (words "a bb c") ("t" ++ showInt 1)))
  putStrLn (catL (wrapped (words "a bb c") ("u" ++ showInt 2)))
  putStrLn (catL (orTag (words "a bb c") ("v" ++ showInt 3)))
  putStrLn (showInt (letShadow "abc" 1000))
  putStrLn (letShadowS ("q" ++ ""))
