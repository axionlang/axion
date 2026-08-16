-- Drift guard: the matvec ops (packed ternary + int8 + int32) against a small
-- reused activation, at two K values that don't divide N evenly (exercises the
-- k-wrap counter + last-partial handling). Asserts --dev == --release.
main :: Int
main =
  let acts = arrayIota 4096 in
  let t = tritVecIota 200003 in
  let w8 = i8Iota 200003 in
  let w32 = i32Iota 200003 in
  (tritMatVecSum t acts 4096)
    + (i8MatVecSum w8 acts 1000)
    + (i32MatVecSum w32 acts 4096)
    + (tritMatVecSum t acts 777)
