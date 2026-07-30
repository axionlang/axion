-- AX0405: uso polimórfico de um método sem declarar o constraint na assinatura.
bad :: a -> Bool
bad x = eq x x

main :: Bool
main = bad 3
