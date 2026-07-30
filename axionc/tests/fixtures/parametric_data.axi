-- Tipos-soma PARAMÉTRICOS (L0): construtores e selectores generalizam sobre os
-- parâmetros de tipo (`Some :: forall a. a -> Maybe a`). fromMaybe 0 (Some 42) +
-- fromMaybe 7 None = 42 + 7 = 49.
data Maybe a = None | Some a
data Either a b = Left a | Right b

fromMaybe :: Int -> Maybe Int -> Int
fromMaybe d m = case m of
  None -> d
  Some x -> x

main :: Int
main = fromMaybe 0 (Some 42) + fromMaybe 7 None
