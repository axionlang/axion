-- An operator may contain `$` (e.g. the functor map `<$>`), while a bare `$` still
-- lexes as the application operator. Here `<$>` is plain application and the inner
-- `$` sequences application: inc <$> (inc $ 40) = inc (inc 40) = 42.
(<$>) :: (Int -> Int) -> Int -> Int
(<$>) f x = f x

inc :: Int -> Int
inc n = n + 1

main :: Int
main = inc <$> (inc $ 40)
