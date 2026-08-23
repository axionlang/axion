-- Known-bad (the escape case regions must still reject): a function that returns a BORROW
-- of a LOCALLY-allocated value. `mkGrab` builds a fresh `W`, returns an interior pointer
-- into its `inner` field, then the local `W` is freed at function exit — so the returned
-- borrow dangles (use-after-free at the caller). The borrow-return inference is PRECISE:
-- it nulls a call's ownership only when the result aliases a PARAMETER (an outliving
-- borrow the caller's frame keeps alive) — never a LOCAL, whose lifetime ends here. So
-- `mkGrab` is NOT treated as borrow-returning, its result stays owned, and the drop-balance
-- verifier flags the escaping dangling borrow (UseAfterFree) → the default-on gate refuses
-- (AX0910). This is the dual of `field_alias_return.axi` (a param borrow, which IS legal).
data W = W { inner :: List Int, other :: List Int }

mkGrab :: Int -> List Int
mkGrab n = inner (W { inner = Cons n Nil, other = Nil })

main :: Int
main = length (mkGrab 7)
