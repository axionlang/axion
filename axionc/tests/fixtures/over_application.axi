-- Over-application: applying a function BEYOND its arity, i.e. a function that
-- returns a function which is then applied. The lowering splits an over-applied
-- spine `(f a…) b…` into a call-to-arity (yielding a closure) followed by applying
-- the remaining args to it, so all three executors agree.
--   (adder 10) 5        = 15   -- adder returns a lambda, applied to 5
--   (compose inc dbl) 10 = 21  -- prelude `compose` (arity 3) applied to 3 args
--   (mk 1 2) 3          =  6   -- arity-2 fn returning a lambda, applied to a 3rd arg
-- Sum = 42. (A `where`-local that returns a function and is over-applied is not yet
-- lowered — it fails with a clear arity error natively rather than miscompiling.)
inc :: Int -> Int
inc x = x + 1

dbl :: Int -> Int
dbl x = x + x

adder :: Int -> (Int -> Int)
adder x = \y -> x + y

mk :: Int -> Int -> (Int -> Int)
mk a b = \c -> a + b + c

main :: Int
main = (adder 10) 5 + (compose inc dbl) 10 + (mk 1 2) 3
