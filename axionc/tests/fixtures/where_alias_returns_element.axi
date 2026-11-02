-- A `where`-local that returns a case-extracted ELEMENT of its list argument
-- (`Cons b rest -> b`). Now that heap-consuming `where`-locals own their params
-- like a signed `%1` fn, `go` owns `ys`: destructuring MOVES `b` out, so the tail
-- (`drop rest`) and the spine (`drop ys`, shallow) are reclaimed while the returned
-- `b` survives (`ret b · moves{b}`) — leak-free and double-free-free, where this
-- shape previously leaked conservatively. All backends must agree on 5 (no crash).
data Box = Box Int
data List a = Nil | Cons a (List a)

headBox :: List Box %1 -> Box
headBox xs = go xs
  where
    go ys = case ys of
      Nil -> Box 0
      Cons b rest -> b

main :: Int
main = case headBox (Cons (Box 5) (Cons (Box 6) Nil)) of
  Box n -> n
