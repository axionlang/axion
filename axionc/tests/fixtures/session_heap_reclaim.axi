-- Heap values held by a session task are reclaimed. `worker` receives a count and hands the task
-- over (a tail call) to `loop`, which keeps a `String` accumulator built by native calls: a fresh
-- value each round, the previous one dying at the loop back-edge. A temporary passed to a reading
-- call dies after it, and the last accumulator dies when the task ends. Session tasks used to free
-- none of these, so every round leaked.
-- seed 9 = "s9"; three rounds → "s9321"; the reply is strLen (5) + digit sum of "s93210" (15) = 20.
seed :: Int -> String
seed n = grow "s" n

grow :: String -> Int -> String
grow s n = strAppend s (showInt n)

isDigit :: Int -> Bool
isDigit c = c >= 48 && c <= 57

digits :: String -> Int -> Int
digits s i = if i >= strLen s then 0 else (if isDigit (charAt i s) then charAt i s - 48 else 0) + digits s (i + 1)

loop :: Int -> String -> Ep (Send Int End) %1 -> IO ()
loop n acc d =
  if n == 0
    then do
      d2 <- send d (strLen acc + digits (grow acc 0) 0)
      close d2
    else loop (n - 1) (grow acc n) d

worker :: Ep (Recv Int (Send Int End)) %1 -> IO ()
worker d = do
  (n, d2) <- recv d
  loop n (seed 9) d2

main :: Int
main = bound $ do
  c <- spawn worker
  c2 <- send c 3
  (r, c3) <- recv c2
  close c3
  r
