-- A session task may `case` on a `data` value between channel ops. An owned scrutinee is
-- consumed: each constructor arm frees its cell and owns the fields (a heap field bound to `_`
-- is freed at once); a catch-all arm keeps the value whole and frees it. Arms may run session
-- ops. Before, a task could only branch with `if`, re-parsing in each helper it called.
-- Requests 7, -1, 0 and 1 answer "GET/f7" (6), "err 400" (7), "zero" (4) and "/f1" (3): 20.
data Req = Req String String

parse :: Int -> Either Int Req
parse n = if n < 0 then Left 400 else Right (Req (strAppend "GET" "") (strAppend "/f" (showInt n)))

answer :: Int -> Ep (Send String End) %1 -> IO ()
answer n d = case parse n of
  Left code -> do
    d2 <- send d (strAppend "err " (showInt code))
    close d2
  Right r -> case r of
    Req m p -> if strLen p == 3 && n == 0
      then do
        d2 <- send d "zero"
        close d2
      else do
        d2 <- send d (strAppend m p)
        close d2

pathOnly :: Int -> Ep (Send String End) %1 -> IO ()
pathOnly n d = case parse n of
  Right r -> case r of
    Req _ p -> do
      d2 <- send d p
      close d2
  other -> do
    d2 <- send d "none"
    close d2

worker :: Ep (Recv Int (Send String End)) %1 -> IO ()
worker d = do
  (n, d2) <- recv d
  if n == 1 then pathOnly n d2 else answer n d2

main :: Int
main = bound $ do
  a <- spawn worker
  a2 <- send a 7
  (x, a3) <- recv a2
  close a3
  b <- spawn worker
  b2 <- send b (0 - 1)
  (y, b3) <- recv b2
  close b3
  c <- spawn worker
  c2 <- send c 0
  (z, c3) <- recv c2
  close c3
  e <- spawn worker
  e2 <- send e 1
  (w, e3) <- recv e2
  close e3
  strLen x + strLen y + strLen z + strLen w
