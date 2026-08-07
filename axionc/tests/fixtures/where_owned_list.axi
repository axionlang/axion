-- A `where`-local accumulator loop (`go`) consumes an OWNED `%1` list passed from
-- its parent, reading each element. The lifted local has no signature, so the
-- borrow analysis used to treat `go xs` as a MOVE — neither the ownerless local nor
-- the parent reclaimed the list (leak). Now the local is registered as a borrower
-- (its result is a non-heap Int, so it cannot alias the argument), and the parent
-- deep-drops the whole `List Expr` after the call. build 3 → 3 Cons + 3·(Add+2 Lit)
-- = 12 allocs, all freed; sum of 2·k for k=1..3 = 12, plus base 100 = 112.
data Expr = Lit Int | Add Expr Expr
data List a = Nil | Cons a (List a)

eval :: Expr -> Int
eval e = case e of
  Lit n -> n
  Add a b -> eval a + eval b

build :: Int -> List Expr
build n = if n == 0 then Nil else Cons (Add (Lit n) (Lit n)) (build (n - 1))

sumEval :: Int -> List Expr %1 -> Int
sumEval base xs = go xs 0
  where
    go ys acc = case ys of
      Nil -> acc + base
      Cons e rest -> go rest (acc + eval e)

main :: Int
main = sumEval 100 (build 3)
