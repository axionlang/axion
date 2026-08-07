-- `let x = e in …` must evaluate `e` exactly ONCE (Axión is strict / call-by-value).
-- `h` is used twice, so each call DOUBLES via one shared binding: `slow 20` is 2^20
-- computed in 20 steps. If the interpreter re-evaluated the binding on every use it
-- would take 2^20 *evaluations* (exponential) and never finish; the native backends
-- compile `let` to a single shared value. All three must agree — and terminate.
slow :: Integer -> Integer
slow n = if n == 0 then 1 else let h = slow (n - 1) in h + h

main :: IO ()
main = putStrLn (show (slow 20))
