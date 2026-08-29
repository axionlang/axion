-- Regions §move-out: a function that projects a heap field of a FRESH LOCAL and returns
-- it. `mkGrab` builds a fresh `W`, returns its `inner` field; the local `W` dies at exit,
-- so `inner` cannot be a borrow (it would dangle). Instead regions MOVE the field out: the
-- local's destructor SKIPS the projected slot (`drop W skip{inner}`), reclaiming the
-- siblings (`other`) + the shell while the returned field escapes OWNED to the caller. This
-- is the LOCAL-interior dual of `field_alias_return.axi` (a PARAM borrow, which outlives the
-- frame and stays a borrow): a local's field cannot outlive as a borrow, so it is moved.
-- The verifier models the move-out (promotes the skipped-slot projection from borrow to
-- owned) → clean; the default-on gate compiles it; ASan+LSan clean.
data W = W { inner :: List Int, other :: List Int }

mkGrab :: Int -> List Int
mkGrab n = inner (W { inner = Cons n Nil, other = Nil })

main :: Int
main = length (mkGrab 7)
