-- Integer literals that EXCEED i64 (§Listing 1.4). `12345678901234567890` does not
-- fit an Int, so the lexer keeps its digits and the parser desugars it to
-- `bignumFromStr "…"` → an arbitrary-precision Integer. Squared, exactly:
-- 152415787532388367501905199875019052100. All three executors agree.
main :: IO ()
main = putStrLn (show (12345678901234567890 * 12345678901234567890))
