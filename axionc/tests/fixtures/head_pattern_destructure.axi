-- A single-clause function may destructure a parameter with a `Con`/`Tuple`
-- pattern directly in its head; the field variables must be bound in native Core
-- (the multi-clause `if`-chain desugar only bound `Var` params, so a head like
-- `label (Named s k) = …` left `s`/`k` unbound → "variable not bound" on the
-- native backends). A single clause is irrefutable, so it lowers to a
-- destructuring `case`. Not String-specific (an Int field failed the same way).
data Named = Named String Int

label :: Named -> String
label (Named s k) = strAppend s "!"

age :: Named -> Int
age (Named s k) = k

swap :: (Int, Int) -> Int
swap (a, b) = a + b

main :: IO ()
main = do
  putStrLn (label (Named "hi" 3))
  putStrLn (show (age (Named "bob" 42)))
  putStrLn (show (swap (7, 10)))
