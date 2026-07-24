-- Registo executável: construção, actualização e selector de campo.
-- Exercita o mesmo maquinário da Listagem 2.1 (04), mas sem o Buffer linear
-- (que é território da Fase 2), para poder correr end-to-end.
data Point = Point { x :: Int, y :: Int }

shiftX :: Point -> Point
shiftX p = p { x = 99 }

main :: IO ()
main = putStrLn (show (x (shiftX (Point { x = 1, y = 2 }))))
