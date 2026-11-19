-- Shapes axmpv's last milestone hit; each was refused natively before its fix.
data P = P { v :: Int, s :: String }

-- G. A callee that may return its argument whole, called in an arm of a let-bound `if`, with the
--    argument used after the join (`let p2 = if c then bump p1 else p1 in … p1 …`): the reuse is in
--    the `let`'s continuation, so the callee returns a copy — it consumed `p1` (UseAfterFree).
bump :: P -> P
bump p = if v p > 2 then p { v = 0 } else p

g :: P -> Int -> Int
g p1 k = let p2 = if k > 0 then bump p1 else p1 in v p2 + v p1 + strLen (s p1)

-- H. A fresh String read by a foreign call, then returned on one path only: a foreign call's result
--    never aliases Axion memory, so the string stays reclaimable on the other path (it leaked).
foreign "libc.so.6" cStrlen = "strlen" :: String -> Int

h :: Int -> String
h k = let name = "f" ++ showInt k in let n = cStrlen name in if n > 2 then name else ""

-- I. A conditional mixing a built string and a literal, printed to stderr (it leaked).
say :: Int -> IO ()
say k = ePutStrLn (if k > 0 then "n=" ++ showInt k else "none")

-- J. A conditional temporary updated by copy on one branch and handed on, its other fields shared
--    with the update (`p { v = 9 }` keeps `s`): the update is freed leaving `s` to `p`, so `p` must
--    still be freed after it — it leaked on that branch (axmpv's loop-file restart).
use :: P -> Int
use q = v q + strLen (s q)

j :: P -> Int -> Int
j p0 k =
  let p = if k > 1 then p0 { v = k } else p0 in
  if v p > 0 then use (p { v = 9 }) else strLen (s p)

main :: IO ()
main = do
  putStrLn (showInt (g (P { v = 5, s = "ab" }) 1) ++ " " ++ showInt (g (P { v = 1, s = "ab" }) 1) ++ " " ++ showInt (g (P { v = 5, s = "ab" }) 0))
  putStrLn ("[" ++ h 5 ++ "][" ++ h 42 ++ "]")
  say 3
  say 0
  putStrLn (showInt (j (P { v = 0, s = "abc" }) 5) ++ " " ++ showInt (j (P { v = 0, s = "abc" }) 0) ++ " " ++ showInt (j (P { v = 2, s = "abc" }) 0))
