-- Landing fixture for the deleted `is_heap_alloc`/`enum_con_names` heuristics
-- (Phase A′): an unboxed enum constructor is an immediate tag, not an allocation —
-- both as a literal `MakeCon` and as the result of a call (`colorOf`). The
-- variable `c` must NOT be droppable (no `drop c` in the dump); the allocation
-- decision comes from the annotation (`ty: None` on the enum `MakeCon`/call).
data Color = Red | Green | Blue

colorOf :: Int -> Color
colorOf n = if n == 0 then Red else Green

main :: Int
main =
  let c = colorOf 1
  in 42
