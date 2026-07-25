-- Açúcar de superfície (§5): `imperative $ do`, `$`, literal hex `0x5A`=90.
-- `imperative $ do xorInPlace buf 0x5A` desugar → `xorInPlace buf 90`.
encrypt :: Buffer U8 %1 -> Buffer U8 %1
encrypt buf = imperative $ do
  xorInPlace buf 0x5A

main :: Int
main =
  let b0 = newBuffer 1000 in
  let b1 = bufIota b0 in
  let b2 = encrypt b1 in
  let s = sumBytes b2 in
  let done = free b2 in
  s
