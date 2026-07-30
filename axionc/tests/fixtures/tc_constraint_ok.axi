-- Positivo: com o constraint `Eq a =>` declarado, o método é permitido sobre um
-- tipo genérico, e resolve à instância no ponto de uso concreto (Eq Int). → True.
allEq :: Eq a => a -> a -> Bool
allEq x y = eq x y

main :: Bool
main = allEq 42 42
