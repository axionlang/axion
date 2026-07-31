-- Executable foldBytes: folds the closure over the bytes (indirect call per
-- byte at runtime). checksum with the `(+)` section = sum of the bytes = 4950.
checksum :: Buffer U8 -> Int
checksum buf = foldBytes (+) 0 buf

main :: Int
main =
  let b0 = newBuffer 100 in
  let b1 = bufIota b0 in
  let s = checksum b1 in
  let done = free b1 in
  s
