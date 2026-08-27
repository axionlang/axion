-- Adversarial (closure-linearity arc): heap `data` elements through map/foldr — the
-- non-Integer reclamation path. `map mkP` builds a `List P` of heap records; `map getA`
-- feeds each `P` into the closure `getA`, which BORROWS it (reads its field) and returns
-- a scalar — so the lifted `getA` lambda OWNS each `P` and must reclaim it via the
-- GENERATED `axion_drop_P` destructor (heap_drop_key's `data` branch, distinct from the
-- Integer path). map consumes both lists and shell-frees their spines; every P record +
-- cons cell freed exactly once. Sum 1..5 = 15.
data P = P Int

mkP :: Int -> P
mkP n = P n

getA :: P -> Int
getA p = case p of
  P a -> a

add :: Int -> Int -> Int
add a b = a + b

main :: Int
main = foldr add 0 (map getA (map mkP (range 1 5)))
