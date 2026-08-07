-- Textbook RSA over arbitrary-precision Integer, computing the private key in the
-- language itself. Exercises, together: strict `let` sharing (powMod's square step),
-- `where`-locals capturing an enclosing parameter (modInverse's `loop` reads `m`),
-- nullary top-level CAFs referenced by name (p, q, n, phi, e, d), a parameter that
-- SHADOWS a same-named CAF (powMod's `e` vs the CAF `e`), and bignum ×, div, mod, ==.
--   p·q = n = 1000000016000000063; d = e^-1 mod φ = 648946405777194593;
--   decrypt(encrypt(42)) round-trips to 42.
powMod :: Integer -> Integer -> Integer -> Integer
powMod b e m =
  if e == 0 then 1
  else if e `mod` 2 == 0
    then let h = powMod b (e `div` 2) m in (h * h) `mod` m
    else (b * powMod b (e - 1) m) `mod` m

-- modular inverse of a mod m via the iterative extended Euclidean algorithm
modInverse :: Integer -> Integer -> Integer
modInverse a m = loop 0 1 m a
  where
    loop t newt r newr =
      if newr == 0 then (if t < 0 then t + m else t)
      else let q = r `div` newr
           in loop newt (t - q * newt) newr (r - q * newr)

p :: Integer
p = 1000000007
q :: Integer
q = 1000000009
n :: Integer
n = p * q
phi :: Integer
phi = (p - 1) * (q - 1)
e :: Integer
e = 65537
d :: Integer
d = modInverse e phi

main :: IO ()
main = do
  putStrLn (show (modInverse 17 3120))
  putStrLn (show n)
  putStrLn (show d)
  putStrLn (show (powMod (powMod 42 e n) d n))
