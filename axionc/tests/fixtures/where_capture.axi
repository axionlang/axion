-- A `where`-local that references an ENCLOSING parameter must capture it. `go`
-- reads `m` from its parent `f`; the native backends lambda-lift `go`, threading
-- `m` in as a leading argument, while the interpreter closes over the parent
-- environment. Both must return 99.
f :: Int -> Int -> Int
f a m = go a
  where
    go x = if x == 0 then m else go (x - 1)

main :: IO ()
main = putStrLn (showInt (f 3 99))
