-- division_operator.axi — the `/` operator (§4 ergonomics). `/` is a single overloaded division
-- that resolves per operand type to the right primitive: `Int` → truncated integer division
-- (`div`), `Float` → `/.`, `Integer` → `div#I`. It has fixity `infixl 7` (same as `*`), so it
-- composes and associates correctly without parentheses. All three backends must agree.

sq :: Int -> Int
sq x = x * x

main :: IO ()
main = do
  putStrLn (showInt (7 / 2))              -- 3  (truncated)
  putStrLn (showInt (2 * 10 / 4))         -- 5  (left-assoc, same precedence as *)
  putStrLn (showInt (100 / 10 / 2))       -- 5  (left-assoc)
  putStrLn (showInt (sq 6 / 4 + 1))       -- 10 (36/4=9, +1)
  putStrLn (showFloat (7.0 / 2.0))        -- 3.5
  putStrLn (showFloat (1.0 / 4.0 +. 0.5)) -- 0.75
  putStrLn (showInteger (fromInt 1000000000000 / fromInt 7)) -- 142857142857
