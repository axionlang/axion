-- Tipo-soma (multi-construtor) com tag em runtime. `case` compara o tag do
-- valor (offset 0) com o de cada construtor e destructura os campos.
-- val(Pos 7) + val Neg + val Zero = 7 + (-1) + 0 = 6.
data Sig = Neg | Zero | Pos Int

val :: Sig -> Int
val s = case s of
  Neg -> 0 - 1
  Zero -> 0
  Pos n -> n

main :: Int
main = val (Pos 7) + val Neg + val Zero
