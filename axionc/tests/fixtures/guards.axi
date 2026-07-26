-- Guardas: `| g = r` desugar numa cadeia de `if` (com `otherwise` incondicional).
-- sign(-7)+sign(5)+sign(0) = -1 + 1 + 0 = 0.
sign :: Int -> Int
sign n
  | n > 0 = 1
  | n == 0 = 0
  | otherwise = 0 - 1

main :: Int
main = sign (0 - 7) + sign 5 + sign 0
