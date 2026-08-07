-- Integral `div`/`mod` (§Listing 1.4) — overloaded infix over Int AND Integer,
-- truncated (quotient toward zero, remainder with the dividend's sign, like Rust/C).
-- Integer: 10^30 `div`/`mod` 7 needs arbitrary precision (bignum long division).
-- Int: `div` did not exist before this — now `100 `div` 7` = 14. All three executors
-- agree. Output: the big quotient, then 1, then 14, then 2.
tenpow :: Int -> Integer
tenpow k = if k < 1 then fromInt 1 else fromInt 10 * tenpow (k - 1)

main :: IO ()
main = do
  putStrLn (showInteger (tenpow 30 `div` fromInt 7))
  putStrLn (showInteger (tenpow 30 `mod` fromInt 7))
  putStrLn (showInt (100 `div` 7))
  putStrLn (showInt (100 `mod` 7))
