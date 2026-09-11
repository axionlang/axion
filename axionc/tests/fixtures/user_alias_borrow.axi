-- A USER-DEFINED element-aliasing borrower over a heap element type. `grabHead` does NOT mark
-- its list param `%1`, so the list is BORROWED: it destructures `xs` and returns the head `y`
-- embedded in an owned `Just y` WITHOUT consuming the spine. The head therefore aliases an
-- element of the still-owned input — the caller frees the input list AND the aliasing result,
-- double-freeing the shared String. The prelude's own `head`/`take`/`last`/`drop` avoid this by
-- consuming their list (`%1`); this fixture keeps a hand-written offender so both nets still
-- fire: AX0912 REJECTS native compilation, and the drop-balance verifier independently reports
-- the corruption (`FAIL:`). Interp runs it (Rust Drop, no aliasing hazard) → prints `a`.
grabHead :: List a -> Maybe a
grabHead xs = case xs of
  Nil -> Nothing
  Cons y ys -> Just y

main :: IO ()
main = case grabHead (Cons "a" (Cons "b" Nil)) of
  Nothing -> putStrLn "none"
  Just x -> putStrLn x
