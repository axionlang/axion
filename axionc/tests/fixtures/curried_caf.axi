-- Native currying: a point-free curried CAF (`add = \x -> \y -> …`, zero clause params)
-- applied to several args. Its value is an arity-1 closure, so applying it to 2 args
-- over-applies that closure — `callclo` passed BOTH args to the arity-1 lambda and the
-- native backends produced garbage (interp was correct). `absorb_lambda_caf` merges the
-- leading lambdas into the clause (`add x y = x + y`), making it an ordinary two-parameter
-- DIRECT call that lowers correctly everywhere. `nested` chains through `apply` too.
-- add 20 21 = 41; applied under a HOF stays correct. main = 41.
add :: Int -> Int -> Int
add = \x -> \y -> x + y

apply :: (Int -> Int) -> Int -> Int
apply f x = f x

main :: Int
main = add (apply (\n -> n + 1) 20) 20
