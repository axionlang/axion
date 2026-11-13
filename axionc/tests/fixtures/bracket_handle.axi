-- `bracket` for resources: `withDev` opens a handle, lends it to `body`, and closes it whatever
-- `body` returns, so `body` can bail out early with `<-!` without closing anything itself. The
-- lent handle is borrowed (its type has no `%1`), so `body` cannot close it (AX0007), and
-- `withDev` must still close it on every path (AX0002). See docs/ownership.md "Error paths".
-- Compile-checked (the C symbols are stand-ins); `bracket_closes_on_every_outcome` plants both
-- mistakes.
data Dev = Dev

foreign "libc.so.6" openD = "abs" :: Int -> Handle Dev
foreign "libc.so.6" readD = "abs" :: Borrow (Handle Dev) -> Int
foreign "libc.so.6" closeD = "abs" :: Own (Handle Dev) -> Int

check :: Int -> Either String Int
check n = if n > 0 then Right n else Left "bad"

withDev :: Int -> (Handle Dev -> Either String Int) -> Either String Int
withDev n body = let h = openD n in let r = body h in case closeD h of
  _ -> r

work :: Int -> Either String Int
work n = withDev n (\h -> do
  x <-! check (readD h)
  y <-! check (readD h - 1)
  Right (x + y))

main :: Int
main = 0
