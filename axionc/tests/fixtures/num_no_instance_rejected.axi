-- num_no_instance_rejected.axi — coherence intact: `+` over a type with NO `Num` instance is
-- rejected (AX0404), exactly as any other class method would be. Proves making `Num` a real
-- class did not weaken instance checking. (A rejection fixture: interp/native exit non-zero.)
data P = P Int

addP :: P -> P -> P
addP a b = a + b

main :: IO ()
main = putStrLn "unreachable"
