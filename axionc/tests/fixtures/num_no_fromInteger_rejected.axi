-- num_no_fromInteger_rejected.axi — coherence intact: `fromInteger` is a required `Num` method,
-- so an instance that omits it is incomplete (AX0401), exactly like omitting `+`. (A rejection
-- fixture: every backend must refuse it, not compile.)
data P = P Int

addP :: P -> P -> P
addP a b = a

instance Num P where
  (+) a b = addP a b
  (-) a b = addP a b
  (*) a b = addP a b

main :: IO ()
main = putStrLn "unreachable"
