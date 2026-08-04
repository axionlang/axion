-- Landing fixture for the un-annotated always-heap ops of `op_produces_heap`
-- (Phase A′): `MakeTuple` and `UpdateRecord` allocate, so their bindings are
-- droppable (flat `free` — no destructor route); `MakeRecord` carries the type
-- annotation (deep `drop … : Rec`). 3 allocs (tuple, Rec, updated Rec) == 3 frees.
data Rec = Rec { f :: Int, g :: Int }

main :: Int
main =
  let t = (1, 2)
      r = Rec { f = 3, g = 4 }
      r2 = r { g = 5 }
  in f r2
