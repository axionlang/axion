-- Bounds safety (§2 memory safety): out-of-bounds array indexing must be a CONTROLLED abort,
-- never a silent OOB read/write (UB). `getArray a 10` on a length-5 array aborts on the native
-- backends (the runtime bounds-check) — a safe crash, the same model as Rust's panic. The
-- interpreter reads via Rust indexing (also bounds-checked). Guards against a future codegen
-- "fast path" inlining an unchecked load.
main :: Int
main = imperative $ do
  a <- newArray 5 0
  a <- setArray a 0 10
  getArray a 10
