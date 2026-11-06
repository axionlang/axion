-- layout_paren_case.axi — a parenthesized `case` as a sub-expression now parses: the closing `)`
-- closes the implicit `of` block (bracket-aware layout). Previously `expected a pattern, found
-- RParen`, which forced extracting a named helper. Covers inline and doubly-nested forms.
data C = C Int Int

-- inline nested case in parens (the shape that used to need `addC`/`mulC` helpers)
add :: C -> C -> C
add a b = case a of C ax ay -> (case b of C bx by -> C (ax + bx) (ay + by))

fstC :: C -> Int
fstC c = case c of C x y -> x
sndC :: C -> Int
sndC c = case c of C x y -> y

-- a (case … (case …)) with a nested paren case in a branch
pick :: Int -> Int -> Int
pick a b = (case a of
  0 -> (case b of 0 -> 10
                  _ -> 11)
  _ -> 12)

main :: IO ()
main = do
  putStrLn (showInt (fstC (add (C 1 2) (C 3 4))))  -- 4
  putStrLn (showInt (sndC (add (C 1 2) (C 3 4))))  -- 6
  putStrLn (showInt (pick 0 0))                    -- 10
  putStrLn (showInt (pick 0 9))                    -- 11
  putStrLn (showInt (pick 5 5))                    -- 12
