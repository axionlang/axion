-- AX0914: a native `Array` stores raw words and owns nothing inside them. `newArray` puts the
-- same pointer in every slot and `getArray` hands it out as a fresh value, so an array of
-- heap values double-frees once two reads consume it (`reverse` frees its list) and leaks
-- otherwise. The native build rejects it, here through a generic wrapper (`fill`) whose
-- element type is fixed only at the call site. The interpreter runs it (prints 4).
mk :: Int -> List Int
mk n = Cons n (Cons (n + 1) Nil)

fill :: Int -> a -> Array a
fill n x = newArray n x

main :: Int
main =
  let a = fill 3 (mk 1)
  in length (reverse (getArray a 0)) + length (reverse (getArray a 1))
