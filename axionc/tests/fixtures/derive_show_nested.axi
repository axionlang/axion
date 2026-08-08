-- Derived `Show` must PARENTHESIZE compound constructor arguments so nested terms
-- are unambiguous (`Node (Node Leaf 1 Leaf) …`, not `Node Node Leaf 1 Leaf …`).
-- Done via a second `Show` method `showArg` that wraps a constructor-with-args in
-- parens; atoms and nullary constructors are left bare. All three backends agree.
data Tree = Leaf | Node Tree Int Tree
  deriving (Show)

main :: IO ()
main = putStrLn (show (Node (Node Leaf 1 Leaf) 2 (Node Leaf 3 Leaf)))
