-- A closure given away while still used afterwards — to a callee that keeps it (a generic pair
-- builder, `pick`, the generic identity) or under a new name — is given away as a COPY: the
-- receiver frees its cell while the caller keeps calling the original. These were refused
-- natively (AX0910 UseAfterFree of the closure); found by the fuzzer's closure-value generator.
mkS :: String -> (Int -> Int)
mkS s = \z -> z + strLen s

pairWith :: a -> b -> (a, b)
pairWith x y = (x, y)

usePair :: (Int -> Int) -> Int -> Int
usePair f k = case pairWith f k of
  (g, n) -> g n

pick :: Bool -> (Int -> Int) -> (Int -> Int) -> (Int -> Int)
pick b f g = if b then f else g

idG :: a -> a
idG x = x

main :: IO ()
main = do
  let cs = mkS "abc"
  let cl = mkS "hello"
  putStrLn (showInt (usePair cs 1))
  putStrLn (showInt ((pick False cs cl) 10))
  putStrLn (showInt ((idG cs) 20))
  let f0 = cs
  putStrLn (showInt (f0 30 + cs 0 + cl 0))
