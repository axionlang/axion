-- Sum type (multi-constructor) with a runtime tag. `case` compares the value's
-- tag (offset 0) with each constructor's and destructures the fields.
-- val(Pos 7) + val Neg + val Zero = 7 + (-1) + 0 = 6.
data Sig = Neg | Zero | Pos Int

val :: Sig -> Int
val s = case s of
  Neg -> 0 - 1
  Zero -> 0
  Pos n -> n

main :: Int
main = val (Pos 7) + val Neg + val Zero
