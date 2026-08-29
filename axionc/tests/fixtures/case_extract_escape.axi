-- Regions §move-out (case-extraction dual): a function that case-extracts a heap
-- field of a FRESH LOCAL scrutinee and returns it, while a SIBLING field is a dead
-- heap discard. `grabBox` builds a fresh `Box` with two heap lists, returns the
-- first (`x`, moved out) and discards the second (`Cons 9 Nil`, must be freed).
--
-- This was a REAL reclaim bug (not just a rejection): the non-deep arm freed the
-- discarded sibling via `loadraw _t3+8` but emitted the scrutinee's shell-free
-- BEFORE the load — reading the Box cell after it was freed (use-after-free, the
-- gate correctly refused, AX0910). The fix orders the shell-free LAST (constructed
-- innermost) so every `loadraw s+off` of a wildcard-discarded field reads `s` while
-- it is still live. Now: load sibling → free sibling → shell-free cell → return x.
-- Verifier-clean, compiles + runs (length = 1) on every backend, ASan + LSan clean.
data Box = Box (List Int) (List Int)

grabBox :: Int -> List Int
grabBox n = case Box (Cons n Nil) (Cons 9 Nil) of
  Box x _ -> x

main :: Int
main = length (grabBox 7)
