-- Show for tuples. Tuples are anonymous (no nominal instance), so the compiler
-- synthesizes a monomorphic `show$(…)` per concrete tuple shape at its call
-- sites; each COMPONENT is shown at its own concrete type, which is why this
-- works without the general 2-param typeclass machinery. Covers: pairs/triples,
-- a constructor component (Just — uses `show`, no extra parens), a list
-- component, tuples nested in a list / Maybe / another tuple. Element `show`
-- keeps `Just 5` unparenthesised, matching Haskell's `show (Just 5, 7)`.
-- Identical output on interp == cranelift == llvm.
main :: IO ()
main = do
  putStrLn (show (1, 2))
  putStrLn (show (1, 2, 3))
  putStrLn (show (Just 5, 7))
  putStrLn (show (1, Cons 2 (Cons 3 Nil)))
  putStrLn (show (Cons (1, 2) (Cons (3, 4) Nil)))
  putStrLn (show (Just (1, 2)))
  putStrLn (show ((1, 2), (3, 4)))
