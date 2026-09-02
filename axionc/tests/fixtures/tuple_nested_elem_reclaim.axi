-- Nested-parametric tuple element reclamation. A `%1`-consumed tuple whose FIRST element is a
-- nested-parametric heap value (`List Integer`) that is DISCARDED (`case t of (xs, n) -> n`).
-- The tuple mono-key `tuple$List$Integer$Integer` is ambiguous under a flat `$`-split (3 tokens,
-- arity 2), so the old `tuple_elem_drops` bailed to a shell-only free → the discarded `List
-- Integer` (spine + bignums) LEAKED (120 B). Now `split_tuple_key` segments the key with
-- constructor arities (`List` arity 1 consumes one following element key) into `["List$Integer",
-- "Integer"]`, and the dead `xs` is freed via its mono destructor `axion_drop_List$Integer`
-- (seeded alongside the tuple). `n` escapes untouched. sndOf = 7 on every backend, LSan clean.
sndOf :: (List Integer, Integer) -> Integer
sndOf t = case t of
  (xs, n) -> n

main :: IO ()
main = putStrLn (showInteger (sndOf (Cons (fromInt 1) (Cons (fromInt 2) Nil), fromInt 7)))
