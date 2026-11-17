-- `data` types with FUNCTION fields — callback records: `data Handler = Handler String (Int ->
-- Int)`, `data Btn = Btn { label :: String, onClick :: Int -> Int, clicks :: Int }`. Both parsers
-- accept a function-typed field (positional `(a -> b)` or record `f :: a -> b`); the field is a
-- closure cell the record owns: freed through `axion_closure_drop` when the record dies, copied
-- through `axion_closure_copy` when the record is copied (a by-copy update `b { label = … }` gives
-- the result its own copy of `onClick` — it used to share the cell: a native double free). An
-- accessor applied further (`onClick b x`) reads the field and calls it (it used to be lowered
-- as a call to a nonexistent function `onClick`, refused AX0910).
-- Expected: inc / 40 / 28 / 21 / 12 / 15 / ok* / 16 / 17 / 8 / 13
-- (leak-free under ASan + LSan).

data Handler = Handler String (Int -> Int)

data Op = Unary (Int -> Int) | Binary (Int -> Int -> Int) | Named String (Int -> Int)

hname :: Handler -> String
hname h = case h of
  Handler n _ -> n

runH :: Handler -> Int -> Int
runH h x = case h of
  Handler _ f -> f x

mkH :: String -> Int -> Handler
mkH n k = let tag = strAppend n "!" in Handler n (\z -> z + k + strLen tag)

runAll :: List Handler -> Int -> Int
runAll hs x = case hs of
  Nil -> 0
  Cons h r -> runH h x + runAll r x

apply :: Op -> Int -> Int
apply op x = case op of
  Unary f -> f x
  Binary g -> g x x
  Named s f -> strLen s + f x

data Btn = Btn { label :: String, onClick :: Int -> Int, clicks :: Int }

press :: Btn -> Int -> Int
press b x = onClick b x + clicks b

relabel :: Btn -> Btn
relabel b = b { label = strAppend (label b) "*" }

rewire :: Btn -> Int -> Btn
rewire b k = b { onClick = \z -> z * k }

wrapBtn :: String -> (Int -> Int) -> Btn
wrapBtn s f = Btn { label = s, onClick = f, clicks = 0 }

pressAll :: List Btn -> Int -> Int
pressAll bs x = case bs of
  Nil -> 0
  Cons b r -> press b x + pressAll r x

main :: IO ()
main = do
  let h = mkH "inc" 1
  putStrLn (hname h)
  putStrLn (show (runH h 10 + runH h 20))
  let hs = [mkH "a" 1, Handler "dbl" (\z -> z * 2), h]
  putStrLn (show (runAll hs 5))
  putStrLn (show (apply (Unary (\z -> z - 1)) 7 + apply (Binary (\a b -> a * b)) 3 + apply (Named "nm" (\z -> z)) 4))
  putStrLn (show (runAll [mkH "x" 2, mkH "yy" 3] 1))
  let nn = show 1234
  let b = Btn { label = "ok", onClick = \z -> z + strLen nn, clicks = 2 }
  putStrLn (show (press b 1 + press b 2))
  let b2 = relabel b
  putStrLn (label b2)
  putStrLn (show (press b2 10))
  let b3 = rewire b2 3
  putStrLn (show (press b3 5))
  let w = wrapBtn "w" (\z -> z - 1)
  putStrLn (show (press w 9))
  putStrLn (show (pressAll [wrapBtn "a" (\z -> z), Btn { label = "c", onClick = \z -> z * 2, clicks = 1 }] 4))
