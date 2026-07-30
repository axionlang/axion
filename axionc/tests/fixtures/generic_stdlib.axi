-- Prelúdio genérico sobre typeclasses (solidificação da fatia 1): maxOr/minOr
-- (Ord a =>) e nub (Eq a =>), todos a despachar dinamicamente para as instâncias
-- Eq Int / Ord Int do prelúdio. Não regride o nativo: estas funções chamam
-- métodos, logo são interp-only (o filtro nativo exclui-as; sum/++/fib continuam
-- a compilar). maxOr 0 [..]=9, minOr 100 [..]=1, length(nub [..])=4 → 14.
main :: Int
main =
  maxOr 0 [3, 1, 4, 1, 5, 9, 2, 6]
  + minOr 100 [3, 1, 4, 1, 5]
  + length (nub [1, 1, 2, 3, 3, 3, 4])
