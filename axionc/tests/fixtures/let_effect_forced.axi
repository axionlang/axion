-- Effect consistency (§): Axión is STRICT, so an UNUSED effectful `let` binding still
-- runs and is sequenced before the body — the interpreter used to lazily skip it while
-- the native backends ran it (a backend divergence, e.g. `let _ = writeFile … in …`
-- silently not writing on interp). Here the discarded `putStr "A"` must be emitted
-- before "B" on every backend. Expected: AB
main :: IO ()
main =
  let _ = putStr "A" in
  putStrLn "B"
