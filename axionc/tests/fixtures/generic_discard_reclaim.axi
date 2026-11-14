-- A generic function whose parameter is a bare type variable (`x :: a`) owns the argument (the
-- caller moves it in) but cannot free it: in the generic body it has no drop key. So the heap
-- value it discards leaked (`pickG True a b` never freed `b`). It is now specialized at each HEAP
-- instantiation (`pickG$String`, `konst$Integer`, `pickG$Pair`), whose Auto-Drop frees what the
-- body drops — also through a generic caller (`choose` → `pickG`). A scalar instantiation stays
-- generic. Same result on every backend, ASan + LSan clean.
data Pair = Pair String Int

pickG :: Bool -> a -> a -> a
pickG b x y = if b then x else y

konst :: a -> a -> a
konst x y = x

choose :: Int -> a -> a -> a
choose n x y = pickG (n > 2) x y

pairLen :: Pair -> Int
pairLen p = case p of
  Pair s n -> strLen s + n

main :: Int
main =
  strLen (pickG True (showInt 12) (showInt 345))
    + strLen (pickG False (showInt 6) (strAppend "a" "b"))
    + strLen (showInteger (konst (fromInt 77) (fromInt 1 * fromInt 2)))
    + pairLen (pickG True (Pair (showInt 9) 1) (Pair (showInt 10) 2))
    + strLen (choose 5 (showInt 1000) (showInt 7))
    + pickG True 1 2
