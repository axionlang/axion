-- Tier-2 (§): a partial-consumer HOF with a closure param over a HEAP element type now
-- compiles+runs natively (specialization monomorphizes it so the drop-insertion reclaims
-- precisely) instead of the old AX0912 interim rejection. `takeWhile`/`dropWhile` (spine-
-- discarding, previously excluded) now run over `String`; `filter` already did. Scalar Int
-- result → every backend agrees. Expected: 2 + 2 + 3 = 7.
names :: List String
names = Cons "aa" (Cons "bb" (Cons "c" (Cons "dd" Nil)))
main :: Int
main =
  length (takeWhile (\s -> strLen s > 1) names)   -- [aa,bb]        → 2
  + length (dropWhile (\s -> strLen s > 1) names) -- [c,dd]         → 2
  + length (filter (\s -> strLen s > 1) names)    -- [aa,bb,dd]     → 3
