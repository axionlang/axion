-- Regression: a `let x = if c then <heap> else <heap>` TEMP whose every arm yields a FRESH owned
-- heap value, consumed downstream, is reclaimed at its (unconditional) death point. This was a leak
-- the reclaimer missed (insert_drops never marked a conditional-producer result owned), which forced
-- the tail-position workaround in the fff renderer. The fix seeds the all-heap-arm temp in
-- reclaim_cond_escape (keys derived from the arms; literals/aliases → left alone, no double-free).
-- Both arms produce a fresh String → dropping the temp is sound. Prints "xHIHI".
up :: String -> String
up s = strAppend s s
dn :: String -> String
dn s = substr 0 (strLen s) s
pick :: Int -> String -> String
pick c s = strAppend "x" (if c == 0 then up s else dn s)
main :: IO ()
main = putStr (pick 0 "HI")
