-- Positive: with the constraint `Eq a =>` declared, the method is allowed over a
-- generic type, and resolves to the instance at the concrete use site (Eq Int). → True.
allEq :: Eq a => a -> a -> Bool
allEq x y = eq x y

main :: Bool
main = allEq 42 42
