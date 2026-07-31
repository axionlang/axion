-- Executable record: construction, update and field selector.
-- Exercises the same machinery as Listing 2.1 (04), but without the linear Buffer
-- (which is Phase 2 territory), so it can run end-to-end.
data Point = Point { x :: Int, y :: Int }

shiftX :: Point -> Point
shiftX p = p { x = 99 }

main :: IO ()
main = putStrLn (show (x (shiftX (Point { x = 1, y = 2 }))))
