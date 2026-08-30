-- Native currying, non-nullary: a function with parameters whose body is a curried lambda
-- chain (`foo x = \y -> \z -> …`) applied PAST its clause arity (`foo 10 20 30` — 3 args, 1
-- clause param). Its value at arity 1 is an arity-1 closure, so applying 2 more args
-- over-applies it — native `callclo` passed all remaining args to the arity-1 closure and
-- produced garbage (interp correct). `absorb_lambda_caf` now merges ALL leading lambdas into
-- the clause (`foo x y z = …`), a direct three-parameter call that lowers correctly. A
-- PARTIAL use (`foo 10`) still yields a capturing closure via eta-expansion. main = 60.
foo :: Int -> Int -> Int -> Int
foo x = \y -> \z -> x + y + z

main :: Int
main = foo 10 20 30
