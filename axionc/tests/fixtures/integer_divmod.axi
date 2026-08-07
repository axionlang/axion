-- Integer division/remainder (§Listing 1.4, Phase 3): `divInteger`/`modInteger`
-- are truncated (quotient toward zero, remainder with the dividend's sign — like
-- Rust/C `/` `%`), so interp and native agree. `10^30 / 7` needs arbitrary
-- precision: quotient 142857142857142857142857142857, remainder 1. Bignum long
-- division base 1e9 (each quotient digit by binary search). All three executors.
tenpow :: Int -> Integer
tenpow k = if k < 1 then fromInt 1 else fromInt 10 * tenpow (k - 1)

main :: IO ()
main = do
  putStrLn (showInteger (divInteger (tenpow 30) (fromInt 7)))
  putStrLn (showInteger (modInteger (tenpow 30) (fromInt 7)))
