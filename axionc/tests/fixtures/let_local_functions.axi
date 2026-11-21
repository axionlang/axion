-- Local functions in `let` compile natively: each is lifted to a `where`-local that takes the
-- variables it uses from around it (a `case` binder, a lambda parameter, an earlier `let`) as
-- extra parameters, and every use passes them on.
data Shape = Circle Int | Rect Int Int

-- captures a parameter; two functions of one `let`, one calling the other
f :: Int -> Int
f n =
  let sq x = x * x
      add a b = sq a + b + n
  in add n 1

-- recursive, capturing a `case` binder
g :: List Int -> Int
g xs = case xs of
  Nil -> 0
  Cons h _ ->
    let go k = if k == 0 then h else go (k - 1) + 1
    in go 3

-- mutually recursive, capturing a heap value (a String)
parity :: String -> Int -> String
parity tag n =
  let ev k = if k == 0 then tag ++ ":even" else od (k - 1)
      od k = if k == 0 then tag ++ ":odd" else ev (k - 1)
  in ev n

-- guards and several clauses
classify :: Int -> String
classify base =
  let kind 0 = "zero"
      kind k
        | k < base = "small"
        | otherwise = "big"
  in kind 0 ++ "," ++ kind 3 ++ "," ++ kind 40

-- a local function over a data value, used twice on the same value
area :: Shape -> Int
area s =
  let scale k = case s of
        Circle r -> 3 * r * r * k
        Rect w h -> w * h * k
  in scale 1 + scale 2

-- nested: an inner local function capturing the outer one's parameter
nested :: Int -> Int
nested n =
  let outer a = (let inner b = a * 10 + b in inner n)
  in outer 4

-- inside a `where`-local, capturing its parameter and the clause's
viaWhere :: Int -> Int
viaWhere n = helper 5
  where
    helper m = let twice k = k + k + n in twice m

-- given all its arguments inside a call's argument
passed :: Int -> List Int
passed n =
  let addN k = k + n
  in Cons (addN 1) (Cons (addN 2) Nil)

-- a captured parameter also used next to the call
shadowed :: Int -> Int
shadowed n = (let plus k = k + n in plus 1) + n

showList :: List Int -> String
showList xs = case xs of
  Nil -> ""
  Cons y rest -> showInt y ++ " " ++ showList rest

main :: IO ()
main = do
  putStrLn (showInt (f 3))
  putStrLn (showInt (g (Cons 10 Nil)))
  putStrLn (parity "p" 7)
  putStrLn (parity "q" 4)
  putStrLn (classify 10)
  putStrLn (showInt (area (Circle 2)))
  putStrLn (showInt (area (Rect 2 5)))
  putStrLn (showInt (nested 7))
  putStrLn (showInt (viaWhere 3))
  putStrLn (showList (passed 10))
  putStrLn (showInt (shadowed 4))
  let twice h = h + h
  putStrLn (showInt (twice 21))
