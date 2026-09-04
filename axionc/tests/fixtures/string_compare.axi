-- String Eq/Ord (§text): `== < >` are wired over String (byte-lexicographic via
-- the native axion_str_cmp), so lookup/elemBy also work over String keys. The
-- result is a scalar Int (no heap alias) so it runs on every backend and the
-- three backends must agree. Expected: 1+2+4+8+16 + 2*32 = 95.
tbl :: List (String, Int)
tbl = Cons ("apple", 1) (Cons ("banana", 2) Nil)

main :: Int
main =
  (if "abc" == "abc" then 1 else 0)
  + (if "abc" == "abd" then 0 else 2)
  + (if "apple" < "banana" then 4 else 0)
  + (if "zzz" > "apple" then 8 else 0)
  + (if elemBy "banana" (Cons "apple" (Cons "banana" Nil)) then 16 else 0)
  + fromMaybe 0 (lookup "banana" tbl) * 32
