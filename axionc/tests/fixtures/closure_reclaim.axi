-- Closures are reclaimed, and keep their captures alive until their last call.
--
-- A closure cell is owned by its binder; calling it BORROWS it (so it can be called again),
-- and Auto-Drop flat-frees the cell after its last call. The cell holds pointers to its
-- captures, so a capture is freed only after the closure's last use — never in between
-- (`viaString` used to free `s` right after building the closure and then read it).
-- Expected: 42 / 21 / 13 / 6 / 16 / 30 / 6
-- (leak-free under ASan + LSan on every line).

once :: Int -> Int
once g = (\y -> g + y) 33

twice :: Int -> Int
twice s = let f = \y -> s + y in f 1 + f 2

viaString :: Int -> Int
viaString n = let s = show n in let g = \z -> strLen s + z in g 1 + g 2

singleCall :: Int -> Int
singleCall n = let s = show n in let g = \z -> strLen s + z in g 1

renamed :: Int -> Int
renamed n = let s = show n in let g = \z -> strLen s + z in let h = g in h 10 + 1

nested :: Int -> Int
nested n =
  let s = show n in
  let g = \z -> strLen s + z in
  let k = \w -> g w + g w in
  k 10

shared :: String -> Int
shared s =
  let a = \z -> strLen s + z in
  let b = \z -> strLen s * z in
  let r = a 1 + b 1 in
  strLen (strAppend s "!!") + r - 6

main :: IO ()
main = do
  putStrLn (show (once 9))
  putStrLn (show (twice 9))
  putStrLn (show (viaString 12345))
  putStrLn (show (singleCall 12345))
  putStrLn (show (renamed 12345))
  putStrLn (show (nested 12345))
  putStrLn (show (shared "abc"))
