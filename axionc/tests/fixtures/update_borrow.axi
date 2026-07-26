-- Reclamação da base de um update por cópia (Auto-Drop §2): `shiftX` empresta o
-- registo (lê os campos para alocar uma cópia com `x` alterado, não o retém),
-- pelo que `main` — que o aloca — o liberta após a chamada. Sem `show`/IO, para
-- o resultado ser um Int puro (sem a string do runtime) e o LSan provar 0 fugas.
-- shiftX (Point 1 2) = Point 99 2;  soma dos campos de ambos = (1+2)+(99+2) = 104.
data Point = Point { x :: Int, y :: Int }

sumP :: Point -> Int
sumP p = x p + y p

shiftX :: Point -> Point
shiftX p = p { x = 99 }

main :: Int
main =
  let p0 = Point { x = 1, y = 2 } in
  let p1 = shiftX p0 in
  sumP p0 + sumP p1
