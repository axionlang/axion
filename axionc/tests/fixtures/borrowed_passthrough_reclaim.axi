-- A function that may return a parameter WHOLE (`relJoin rel name = if … then name else …`),
-- called with a value the caller does not own — an element of a borrowed list — whose result the
-- caller then drops: that frees the list's element, and the list frees it again (a double free).
-- The verifier did not see it (it gated the alias on the argument being used again, and a
-- borrowed element never is), and Auto-Drop's copy of such returns only fired when the argument
-- was reused. Now the verifier treats the result as a borrow of the element (dropping it is
-- reported), and Auto-Drop copies the return wherever a caller passes a borrowed value — also
-- through a generic body specialized at a heap type (`idG$String`), and for a field bound by a
-- `case` whose scrutinee is used afterwards (`liveCase`, found by the `gen_ownership` fuzzer:
-- the verifier also missed the deep drop of a value whose field had been handed away).
-- Same result on every backend, ASan + LSan clean.
relJoin :: String -> String -> String
relJoin rel name = if strLen rel == 0 then name else strAppend (strAppend rel "/") name

joinAll :: String -> List String -> Int
joinAll rel xs = case xs of
  Nil -> 0
  Cons x rest -> strLen (relJoin rel x) + joinAll rel rest

idG :: a -> a
idG x = x

firstLen :: List String -> Int
firstLen xs = case xs of
  Nil -> 0
  Cons x _ -> strLen (idG x)

-- a borrowed PARAMETER passed through
viaParam :: String -> Int
viaParam s = strLen (relJoin "" s)

-- `orDefault` frees `s` on one path and returns it on the other; `x` belongs to `v0`, used after
orDefault :: String -> String -> String
orDefault d s = if strLen s == 0 then d else s

liveCase :: Int -> Int
liveCase n =
  let v0 = Cons (showInt n) Nil in
  (case v0 of
     Nil -> 0
     Cons x _ -> strLen (orDefault "d" x)) + length v0

main :: Int
main =
  let l = Cons (showInt 77) (Cons (showInt 8) Nil) in
  joinAll "" l + joinAll "d" l + firstLen l + viaParam (showInt 12345) + length l + liveCase 225
