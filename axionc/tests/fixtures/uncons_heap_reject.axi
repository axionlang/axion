-- `uncons` over a HEAP element type (String). Unlike `head`/`last` (which BORROW the list
-- and alias an element into the result — the AX0912 alias-borrower class), `uncons` MOVES its
-- `%1` list and returns the element in a `(a, List a)` peel tuple, so its Core is SOUND (the
-- drop-verifier passes it). BUT the native backends cannot lower a heap-element tuple payload
-- and would miscompile it to a use-after-free (both LLVM and Cranelift). AX0912 therefore
-- rejects it natively — FAIL CLOSED, not a silent UAF — while the interpreter (Rust Drop)
-- reclaims safely and runs it. Over a SCALAR element (`List Int`) it compiles on every backend
-- (see list_deconstruct.axi). Interp prints `a`.
main :: IO ()
main = case uncons (Cons "a" (Cons "b" Nil)) of
  Nothing -> putStrLn "none"
  Just p -> case p of
    (x, _) -> putStrLn x
