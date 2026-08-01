-- A LINEAR recursive ADT (`L %1`) consumed incrementally: `case xs of LC y ys ->
-- … sumL ys …` transfers the tail `ys` to the recursive call. The scrutinee must
-- be freed SHALLOWLY (its Cons shell only) — a deep-drop would also free the
-- transferred `ys` (double free). Auto-Drop now does this: build 5 → 5 LC cells,
-- consumed to 5 frees (balanced), sum 1..5 = 15.
data L = LN | LC Int L

sumL :: L %1 -> Int
sumL xs = case xs of
  LN -> 0
  LC y ys -> y + sumL ys

build :: Int -> L
build n = if n == 0 then LN else LC n (build (n - 1))

main :: Int
main = sumL (build 5)
