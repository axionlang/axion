-- Drift guard: base-243 codec round-trip across byte boundaries. tritVecIota packs
-- weight(i)=(i mod 3)-1; sumTrit reads every trit back via getTritVec; tritDot
-- against an activation. N not a multiple of 5 (partial last byte). --dev==--release.
sumTrit :: TritVec -> Int -> Int -> Int -> Int
sumTrit t i n acc = if i == n then acc else sumTrit t (i + 1) n (acc + getTritVec t i)
main :: Int
main =
  let t = tritVecIota 100003 in
  let acts = arrayIota 100003 in
  (sumTrit t 0 100003 0) + (tritDot t acts) + (lenTritVec t)
