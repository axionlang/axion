-- Short-circuit `&&`/`||`: the RHS is evaluated only when the LHS doesn't decide the result (they
-- desugar to a lazy `if`). As prelude FUNCTIONS they were strict (both args forced), so `100 div 0`
-- on the dead branch here would be a runtime error; short-circuit skips it. Also checks the truth
-- table. Prints "ok".
guardDiv :: Int -> Bool
guardDiv x = (x > 0) && (100 `div` x > 5)
orDiv :: Int -> Bool
orDiv x = (x == 0) || (100 `div` x > 5)
truth :: Bool
truth = (True && True) && not (True && False) && not (False && True)
        && (True || False) && (False || True) && not (False || False)
main :: IO ()
main = putStrLn (if not (guardDiv 0) && orDiv 0 && truth then "ok" else "bad")
