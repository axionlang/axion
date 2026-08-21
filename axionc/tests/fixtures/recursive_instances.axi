-- RECURSIVE hand-written instances that recurse via a direct method call on their
-- OWN type (`show xs` where `xs : Tree a`). Previously interp-only: the recursive
-- method use over the instance's own (cvar-built) type didn't specialize, so native
-- fell back and errored. Now `poly_con_methods` records the dispatch type in
-- cvar-name form and, under specialization, rewrites it to the concrete impl
-- (`show$Tree$Int`, the self spec) — including recursion THROUGH a container
-- (`Rose a` recurses via `List (Rose a)` → `show$List$Rose$Int`).
-- Covers single-param Show + Eq (binary tree), multi-param (Tree a b), and
-- container-mediated recursion (rose tree). interp == cranelift == llvm.
data Bin a = Tip | Node (Bin a) a (Bin a)
data Two a b = Leaf a | Fork (Two a b) b (Two a b)
data Rose a = Rose a (List (Rose a))

instance Show a => Show (Bin a) where
  show t = case t of
    Tip -> "."
    Node l v r -> strAppend (strAppend (strAppend "(" (show l)) (strAppend (showArg v) (show r))) ")"
  showArg t = show t

instance Eq a => Eq (Bin a) where
  eq s t = case s of
    Tip -> case t of
      Tip -> True
      Node l2 v2 r2 -> False
    Node l1 v1 r1 -> case t of
      Tip -> False
      Node l2 v2 r2 -> if eq v1 v2 then if eq l1 l2 then eq r1 r2 else False else False

instance (Show a, Show b) => Show (Two a b) where
  show t = case t of
    Leaf x -> strAppend "L" (showArg x)
    Fork l v r -> strAppend (showArg l) (strAppend (strAppend "-" (showArg v)) (showArg r))
  showArg t = show t

instance Show a => Show (Rose a) where
  show r = case r of
    Rose x kids -> strAppend (showArg x) (show kids)
  showArg r = show r

bin :: Bin Int
bin = Node (Node Tip 1 Tip) 2 (Node Tip 3 Tip)
binEq :: Bin Int
binEq = Node (Node Tip 1 Tip) 2 (Node Tip 3 Tip)
two :: Two Int Bool
two = Fork (Leaf 1) True (Leaf 2)
rose :: Rose Int
rose = Rose 1 (Cons (Rose 2 Nil) (Cons (Rose 3 (Cons (Rose 4 Nil) Nil)) Nil))

main :: IO ()
main = do
  putStrLn (show bin)
  putStrLn (show (eq bin binEq))
  putStrLn (show two)
  putStrLn (show rose)
