-- HAND-WRITTEN (non-derived) multi-param instances with CUSTOM logic. These
-- can't use the monomorphic re-derivation that covers `deriving` — they must go
-- through the real specializer, which now keys on a VECTOR of constraint vars
-- (one concrete type per `(Show a, Show b) =>` var) instead of a single `t`.
-- Each method use rewrites at ITS OWN constraint var's type, so `show`/`eq`
-- dispatch each field correctly — including when the type args are in the
-- OPPOSITE order (`Pair Bool Int`) or a field is parametric (`List Int`).
-- Identical output on interp == cranelift == llvm.
data Pair a b = Pair a b

instance (Show a, Show b) => Show (Pair a b) where
  show p = case p of
    Pair x y -> strAppend (strAppend (strAppend "<" (show x)) (strAppend " | " (show y))) ">"
  showArg p = show p

instance (Eq a, Eq b) => Eq (Pair a b) where
  eq p q = case p of
    Pair x1 y1 -> case q of
      Pair x2 y2 -> if eq x1 x2 then eq y1 y2 else False

ib :: Pair Int Bool
ib = Pair 7 True
bi :: Pair Bool Int
bi = Pair False 42
withList :: Pair (List Int) Bool
withList = Pair (Cons 1 (Cons 2 Nil)) True
same :: Pair Int Bool
same = Pair 7 True
diff :: Pair Int Bool
diff = Pair 7 False

main :: IO ()
main = do
  putStrLn (show ib)
  putStrLn (show bi)
  putStrLn (show withList)
  putStrLn (show (eq ib same))
  putStrLn (show (eq ib diff))
