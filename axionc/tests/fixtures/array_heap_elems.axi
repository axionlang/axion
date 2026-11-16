-- Native arrays of heap elements. The array owns its elements: `newArray`/`setArray` store a
-- COPY of the value (the caller keeps and frees its own), `getArray` returns a copy the caller
-- owns, `setArray` frees the element it replaces, and dropping the array frees every element.
-- Each operation at a concrete heap element type `K` calls a generated helper
-- (`axion_arrop_new$K`/`get$K`/`set$K`) and the array is dropped by `axion_drop_Array$K`.
-- Also: a `%1` array parameter is reclaimed (it leaked, even with Int elements), and an array a
-- function returns carries its element-freeing destructor key.
-- Expected: xhello / 3 / 1000007 / 36 / qp / 2 / 014916 / 49 / 42 / 4 / 70 / 4
-- (leak-free under ASan + LSan).

data P = P String Int

nameOf :: P -> String
nameOf p = case p of
  P s _ -> s

sumL :: List Int -> Int
sumL xs = case xs of
  Nil -> 0
  Cons y r -> y + sumL r

fill :: Array String %1 -> Int -> Int -> Array String
fill a i n = if i >= n then a else fill (setArray a i (showInt (i * i))) (i + 1) n

joinAll :: Array String -> Int -> Int -> String
joinAll a i n = if i >= n then "" else strAppend (getArray a i) (joinAll a (i + 1) n)

firstOr :: Array (Maybe Integer) -> Integer
firstOr a = case getArray a 0 of
  Just v -> v
  Nothing -> fromInt 0

consume :: Array (List String) %1 -> Int
consume a = lenArray a

consumeInts :: Array Int %1 -> Int
consumeInts a = lenArray a

main :: IO ()
main = do
  let a = newArray 3 "x"
  let b = setArray a 1 "hello"
  putStrLn (strAppend (getArray b 0) (getArray b 1))
  putStrLn (show (lenArray b))
  let c = newArray 2 (fromInt 7)
  let d = setArray c 0 (fromInt 1000 * fromInt 1000)
  putStrLn (showInteger (getArray d 0 + getArray d 1))
  let e = newArray 2 [1, 2, 3]
  let f = setArray e 1 [10, 20]
  putStrLn (show (sumL (getArray f 0) + sumL (getArray f 1)))
  let g = newArray 2 (P "p" 1)
  let h = setArray g 0 (P "q" 2)
  putStrLn (strAppend (nameOf (getArray h 0)) (nameOf (getArray h 1)))
  let t = newArray 2 ("a", 5)
  let u = setArray t 1 ("b", 6)
  putStrLn (show (lenArray u))
  let s = fill (newArray 5 "") 0 5
  putStrLn (joinAll s 0 5)
  putStrLn (joinAll s 2 4)
  let m = setArray (newArray 3 Nothing) 0 (Just (fromInt 41 + fromInt 1))
  putStrLn (showInteger (firstOr m))
  putStrLn (show (consume (newArray 4 ["a", "b"])))
  let big = fill (newArray 2000 "z") 0 2000
  putStrLn (show (strLen (joinAll big 1990 2000)))
  putStrLn (show (consumeInts (newArray 4 7)))
