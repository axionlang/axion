-- REJECT (AX0204): a string-literal pattern nested inside another pattern (was a native
-- internal error).
label :: Maybe String -> String
label m = case m of
  Just ("a") -> "ab"
  Just s -> s
  Nothing -> "none"

main :: IO ()
main = putStrLn (label (Just ("a")))
