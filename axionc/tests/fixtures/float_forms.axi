-- Scientific and leading-dot float literals in the lexer: `1e9`, `2.0E10`, `1.5e-3`,
-- `.5`, `.5e2`. The `[-+]` in an exponent is consumed inside the token, so it never
-- conflicts with binary `-`. A bare trailing-dot `3.` is deliberately NOT a float literal
-- (it would collide with the compose operator `.` under longest-match); `3.0` is canonical.
main :: IO ()
main = do
  putStrLn (showFloat 1e9)
  putStrLn (showFloat 2.0E10)
  putStrLn (showFloat 1.5e-3)
  putStrLn (showFloat .5)
  putStrLn (showFloat (.5 +. .25))
