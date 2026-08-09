-- Nested-PARAMETRIC instantiation of a derived method must compile natively.
-- `show (Some (Some 3))` dispatches `show` at `Option (Option Int)`: the OUTER
-- specialization `show$Option$Option$Int` calls `showArg$Option$Int`, which calls
-- `showArg$Int`. Regression: only the flat `show$Option$Int` was ever seeded, so
-- the nested outer spec was missing and `main` fell out of the native subset
-- (cranelift/llvm: "'main' must be a native function"). The element-type key is
-- now the FULL mangle (`Option$Int`, not just the head `Option`), and the inner
-- parametric method spec is seeded transitively. All three backends agree.
data Option a = None | Some a
  deriving (Show)

main :: IO ()
main = do
  putStrLn (show (Some (Some 3)))
  putStrLn (show (Some (Some (Some (5 < 6)))))
