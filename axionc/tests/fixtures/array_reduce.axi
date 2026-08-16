-- Fused Array Int reductions (general primitives): one native pass, no per-element
-- getArray. arraySum(arrayIota 10)=45; arrayDot(iota,iota)=sum i^2=285 → 330.
-- Owned iota results + borrowing readers → reclaimed once.
main :: Int
main = (arraySum (arrayIota 10)) + (arrayDot (arrayIota 10) (arrayIota 10))
