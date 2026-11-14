-- A function that returns a pointer INTO its argument (`unboxS`, `getInner`) hands back a
-- borrow. Called on a temporary, the temporary must outlive every use of the borrow, and a
-- borrow moved into a new value (`Just (unboxS …)`) must be copied, or two owners free it.
-- All of these used to be refused natively (AX0910): Auto-Drop freed the temporary right after
-- the call. Same result on every backend, ASan + LSan clean.
data BoxS = BoxS String Int
data W = W { inner :: List Int, other :: List Int }

unboxS :: BoxS -> String
unboxS b = case b of
  BoxS s n -> s

getInner :: W -> List Int
getInner w = inner w

mk :: Int -> W
mk n = W { inner = Cons n (Cons 2 Nil), other = Cons 9 Nil }

-- read through the borrow, then the temporary dies
direct :: Int -> Int
direct n = strLen (unboxS (BoxS (showInt n) 6))

-- `case` on a borrow: the owner dies inside each arm
caseOn :: Int -> Int
caseOn n = case getInner (mk n) of
  Cons x rest -> x + length rest
  Nil -> 0

chained :: Int -> Int
chained n = strLen (unboxS (BoxS (strAppend (showInt n) "!") n)) + length (getInner (mk n))

projected :: Int -> Int
projected n =
  let w = mk n
      i = inner w
  in length i + sum i

-- a borrow moved into a new value is copied
moved :: Int -> Int
moved n = case Just (unboxS (BoxS (showInt n) 1)) of
  Just s -> strLen s
  Nothing -> 0

main :: Int
main = direct 888 + caseOn 5 + chained 42 + projected 3 + moved 77
