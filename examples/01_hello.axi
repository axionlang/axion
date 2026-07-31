-- Target program 1/5 — L0 "Hello World" (Listing 1.1 of the spec).
-- Phase 1 success: parse -> typecheck -> run, without any linearity
-- annotation. Anyone who knows FP reads this on day 1.

main :: IO ()
main = putStrLn "Hello, Axion!"
