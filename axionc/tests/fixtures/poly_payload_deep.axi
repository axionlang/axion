-- Polymorphic-payload DEEP reclamation: a `List a` whose element instantiates to a
-- RECURSIVE heap type (`Expr`, a tree). When the list is consumed one element at a
-- time (`Cons e rest -> len rest`, `e` unused), each extracted element must be
-- deep-dropped via its OWN destructor — resolved from the scrutinee's instantiation
-- key `List$Expr`. A blind flat `free` (the old behaviour) freed the `Add` node but
-- LEAKED its `Lit` children. build → 2 Cons + Lit + Add + 2 Lit = 6 allocs, all freed.
data Expr = Lit Int | Add Expr Expr
data List a = Nil | Cons a (List a)

len :: List Expr %1 -> Int
len xs = case xs of
  Nil -> 0
  Cons e rest -> 1 + len rest

main :: Int
main = len (Cons (Lit 1) (Cons (Add (Lit 2) (Lit 3)) Nil))
