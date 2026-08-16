-- Single-scope reclamation (drop-insertion fix): an owned heap resource in a flat
-- `let`-chain whose last uses are read-only getters (getI8/lenI8) is now reclaimed
-- exactly once — previously the getters were treated as *moving* the resource, so
-- it leaked unless threaded through a helper. i8Iota (owned) → setI8 (consume+
-- produce, in-place) → getI8/lenI8 (borrow) → dropped once.
-- getI8 a 0 = 5 (set); getI8 a 3 = weight(3) = (3 mod 3)-1 = -1; lenI8 = 20 → 24.
main :: Int
main =
  let a = setI8 (i8Iota 20) 0 5 in
  (getI8 a 0) + (getI8 a 3) + (lenI8 a)
