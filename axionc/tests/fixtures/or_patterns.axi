-- Or-patterns: `p1 | p2 -> e` matches either alternative. The parsers expand an arm into one
-- arm per alternative (nested `|` inside parentheses multiplies out), each with the same body;
-- every alternative binds the same variables, at one type. A lambda in the shared body is
-- lifted once.
data Color = Red | Green | Blue | Black

data Shape = Circle Int | Square Int | Rect Int Int | Dot

data Op = Add Int | Sub Int | Mul Int

warm :: Color -> Int
warm c = case c of
  Red | Green -> 1
  _ -> 0

size :: Shape -> Int
size s = case s of
  Circle n | Square n -> n
  Rect w h -> w * h
  Dot -> 0

small :: Maybe Int -> String
small m = case m of
  Just (1 | 2 | 3) -> "small"
  Just _ | Nothing -> "other"

label :: Maybe String -> String
label m = case m of
  Just s -> case s of
    "a" | "b" -> "ab"
    t -> t
  Nothing -> "none"

firstName :: (Maybe String, Maybe String) -> String
firstName p = case p of
  (Just n, _) | (Nothing, Just n) -> n
  (Nothing, Nothing) -> "anon"

grid :: (Int, Int) -> String
grid p = case p of
  (0 | 1, 0 | 1) -> "corner"
  _ -> "far"

apply :: Op -> Int -> Int
apply o v = case o of
  Add k | Sub k -> (\y -> y + k) v
  Mul k -> v * k

pairUp :: Op -> (String, Int)
pairUp o = case o of
  Add k | Sub k | Mul k -> (showInt k, k)

main :: IO ()
main = do
  putStrLn (showInt (warm Red + warm Green + warm Blue))
  putStrLn (showInt (size (Circle 3) + size (Square 4) + size (Rect 2 5) + size Dot))
  putStrLn (small (Just 2))
  putStrLn (small (Just 9))
  putStrLn (small Nothing)
  putStrLn (label (Just "b"))
  putStrLn (label (Just "zz"))
  putStrLn (firstName (Nothing, Just "bo"))
  putStrLn (firstName (Just "al", Just "x"))
  putStrLn (firstName (Nothing, Nothing))
  putStrLn (grid (1, 0))
  putStrLn (grid (2, 0))
  putStrLn (showInt (apply (Add 2) 5 + apply (Sub 3) 5 + apply (Mul 4) 5))
  case pairUp (Sub 7) of
    (s, n) -> putStrLn (s ++ showInt n)
