-- Over-application: applying a function BEYOND its arity, i.e. a function that
-- returns a function which is then applied. The lowering splits an over-applied
-- spine `(f a…) b…` into a call-to-arity (yielding a closure) followed by applying
-- the remaining args to it, so all three executors agree.
--   (adder 10) 5        = 15   -- top-level fn returns a lambda, applied to 5
--   (compose inc dbl) 10 = 21  -- prelude `compose` (arity 3) applied to 3 args
--   (mk 1 2) 3          =  6   -- arity-2 fn returning a lambda, applied to a 3rd arg
--   (wadd 100) 8        = 108  -- a `where`-local returning a lambda, over-applied
-- Sum = 150. The `where`-local case resolves through the name-mangling map to its
-- `main$wadd` arity, so it lowers the same as a top-level over-application.
inc :: Int -> Int
inc x = x + 1

dbl :: Int -> Int
dbl x = x + x

adder :: Int -> (Int -> Int)
adder x = \y -> x + y

mk :: Int -> Int -> (Int -> Int)
mk a b = \c -> a + b + c

main :: Int
main = (adder 10) 5 + (compose inc dbl) 10 + (mk 1 2) 3 + (wadd 100) 8
  where
    wadd :: Int -> (Int -> Int)
    wadd a = \b -> a + b
