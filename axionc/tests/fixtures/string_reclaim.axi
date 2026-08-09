-- String reclamation (§tc): native strings carry an 8-byte size-header — heap
-- strings (from show/strAppend, via axion_alloc) have a NONZERO header; static
-- literals are emitted with a ZERO header. `axion_str_drop` frees the former and
-- skips the latter, so every String is reclaimed exactly once with no double-free
-- of a literal's rodata. Exercises: literals, strAppend/++, show, a String-param
-- helper (borrow → caller reclaims the argument), a function returning a literal
-- (drop skips it), and a loop (repeated alloc). ASan+LSan must run clean.
greet :: String -> String
greet name = strAppend "hi " name

constMsg :: Int -> String
constMsg x = "const"

loop :: Int -> IO ()
loop n = if n < 1 then putStr "" else do
  putStrLn (greet (show n))
  loop (n - 1)

main :: IO ()
main = do
  putStrLn "literal"
  putStrLn (greet "bob")
  putStrLn (show (100 * 100))
  putStrLn (constMsg 0)
  putStrLn (if 3 < 5 then "yes" else "no")
  loop 5
