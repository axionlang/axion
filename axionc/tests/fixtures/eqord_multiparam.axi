-- Eq/Ord over MULTI-PARAM derived data. Same 2-param dispatch bug as Show: the
-- single-`t` monomorphizer collapsed every field's `eq`/`le` to the FIRST type,
-- so `eq`/`le` mis-dispatched later fields (interp errored on a Bool `==`; native
-- silently compared list pointers with `==`). Fixed by synthesizing a monomorphic
-- eq$Name$T1$T2 / le$Name$… from the data decl, each field compared at its OWN
-- concrete type. Covers a 2-param product (Pair), a 2-param sum (Eit), and a
-- nested derived field. `nested1`/`nested2` are distinct objects with equal
-- contents → structural eq must be True (pointer eq would be False).
-- Identical output on interp == cranelift == llvm.
data Pair a b = Pair a b deriving (Eq, Ord, Show)
data Eit a b = Lft a | Rgt b deriving (Eq, Ord, Show)

p1 :: Pair Int Bool
p1 = Pair 3 True
p2 :: Pair Int Bool
p2 = Pair 3 False
e1 :: Eit Int Bool
e1 = Rgt True
e2 :: Eit Int Bool
e2 = Lft 9
nested1 :: Pair (Eit Int Bool) Int
nested1 = Pair (Rgt True) 5
nested2 :: Pair (Eit Int Bool) Int
nested2 = Pair (Rgt True) 5

main :: IO ()
main = do
  putStrLn (show (eq p1 p2))
  putStrLn (show (le p2 p1))
  putStrLn (show (eq e1 e2))
  putStrLn (show (le e2 e1))
  putStrLn (show (eq nested1 nested2))
