-- Teaching diagnostics (§8): a mis-spelled name close to a defined one triggers
-- AX0101 with a machine-applicable fix ("did you mean `length`?" + a suggestion
-- the editor can auto-apply via --emit json).
length :: Int -> Int
length n = n

main :: Int
main = lenght 5
