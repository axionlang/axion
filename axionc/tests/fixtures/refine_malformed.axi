-- Must FAIL: ill-formed refinements (AX0601) and a refined function used without its refined
-- arguments (AX0602).

notInt :: {s:String | 0 <= s} -> Int
notInt s = 0

unknownName :: {x:Int | 0 <= y} -> Int
unknownName x = x

lenOfInt :: n:Int -> {i:Int | i < len n} -> Int
lenOfInt n i = i

idx :: {i:Int | 0 <= i} -> Int
idx i = i

asValue :: List Int -> List Int
asValue xs = map idx xs

main :: IO ()
main = putStrLn (showInt (idx 1))
