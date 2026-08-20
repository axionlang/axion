-- Show for MULTI-PARAM derived data (`Either`, and user 2/3-param types). The
-- single-`t` monomorphizer substitutes only the FIRST constraint var, so a
-- 2-param instance used to mis-dispatch (`show (Right True)` ran showInt on a
-- Bool). Fixed by synthesizing a monomorphic show$Name$T1$T2 from the data decl,
-- each field shown at its OWN concrete type. Covers: Either, a user 2-param and
-- 3-param type, a multi-constructor type, nested Either/Maybe/tuple/list fields.
-- Identical output on interp == cranelift == llvm.
data Pair a b = Pair a b deriving (Show)
data Tri a b c = Tri a b c deriving (Show)
data These a b = This a | That b | Both a b deriving (Show)

rgt :: Either Int Bool
rgt = Right True
inList :: List (Either Int Bool)
inList = Cons (Left 1) (Cons (Right False) Nil)
tri :: Tri Int Bool Int
tri = Tri 1 False 2
both :: These Int Bool
both = Both 9 True
nested :: Pair (Either Int Bool) (Maybe Int)
nested = Pair (Right False) (Just 4)
tupField :: Pair (Int, Int) Bool
tupField = Pair (1, 2) True

main :: IO ()
main = do
  putStrLn (show rgt)
  putStrLn (show inList)
  putStrLn (show tri)
  putStrLn (show both)
  putStrLn (show nested)
  putStrLn (show tupField)
