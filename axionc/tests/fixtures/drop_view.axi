-- `drop` is a VIEW: its result shares the input's tail cells (the `n < 1`
-- arm returns `Cons y ys`, reusing the input). Regression: the caller used
-- to free the input — `xs` is only case-read in the lowered Core, so it was
-- classified as a pure borrow — and the result's destructor double-freed the
-- shared suffix. The fix moves the view argument at the call (like
-- `append`'s second list, whose `ys` param reaches a recursive call): the
-- caller relinquishes the input, the result's destructor reclaims the shared
-- suffix, and the dropped prefix leaks conservatively.
-- Expected: sum(drop 5 [1..11]) + sum(drop 2 [1..11]) + sum(drop 0 [1..11])
--         = 51 + 63 + 66 = 180.
main :: Int
main = (sum (drop 5 (range 1 11))) + (sum (drop 2 (range 1 11))) + (sum (drop 0 (range 1 11)))
