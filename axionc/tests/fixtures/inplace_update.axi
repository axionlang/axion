-- Linear Elision (§2): 'bump' actualiza um Cell %1 na sua última menção viva →
-- o compilador muta o bloco existente (nó `update!` no Core) em vez de
-- alocar+copiar. Resultado 99, com 1 só alocação (o Cell), não 2.
data Cell = Cell { val :: Int }

bump :: Cell %1 -> Cell %1
bump c = c { val = 99 }

main :: Int
main =
  let c0 = Cell { val = 1 } in
  let c1 = bump c0 in
  let r = val c1 in
  r
