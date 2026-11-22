-- Contracts (docs/contracts.md): `requires`/`ensures` predicates, proven where the compiler can,
-- checked at run time where it cannot. Every contract here holds, so nothing aborts; see
-- `axionc --emit contracts` for which ones are proven.

{-# CONTRACT withdraw
      requires 0 <= amount && amount <= balance
      ensures 0 <= result && result <= balance #-}
withdraw :: Int -> Int -> Int
withdraw balance amount = balance - amount

-- an array access whose contract removes its bounds check
{-# CONTRACT at requires 0 <= i && i < len a #-}
at :: Array Int -> Int -> Int
at a i = getArray a i

-- an `ensures` proven by induction over the recursion
{-# CONTRACT countdown ensures result == 0 #-}
countdown :: Int -> Int
countdown n = if n <= 0 then 0 else countdown (n - 1)

-- an `ensures` that is not proven (the sum could wrap): checked after each outside call, while
-- the loop itself stays a loop
{-# CONTRACT sumTo ensures result >= acc #-}
sumTo :: Int -> Int -> Int
sumTo n acc = if n <= 0 then acc else sumTo (n - 1) (acc + n)

-- a non-zero divisor, used by a total function and inside a parallel loop
{-# CONTRACT safeDiv requires d /= 0 #-}
safeDiv :: Int -> Int -> Int
safeDiv x d = x `div` d

{-# TOTAL third #-}
third :: Int -> Int
third x = safeDiv x 3

-- a value read at run time: its contracts are checked there
digits :: String -> Int
digits s = strLen s

sumL :: List Int -> Int
sumL xs = case xs of
  Nil -> 0
  Cons y rest -> y + sumL rest

sumA :: Array Int -> Int -> Int -> Int
sumA a i acc = if i >= lenArray a then acc else sumA a (i + 1) (acc + getArray a i)

main :: IO ()
main = do
  let a = arrayIota 10
  putStrLn (showInt (withdraw 100 30))
  putStrLn (showInt (at a 3 + countdown 5))
  let k = digits "seven!!"
  putStrLn (showInt (at a k))
  putStrLn (showInt (at (arrayIota 20) (k + 10)))
  putStrLn (showInt (withdraw 50 k))
  putStrLn (showInt (sumL (map (withdraw 50) [1, 2, 3])))
  putStrLn (showInt (sumTo 1000 0))
  putStrLn (showInt (third 30))
  let w = arrayIota 8
  putStrLn (showInt (sumA (parFor (newArray 8 0) (\i _ -> safeDiv 100 (i + 1) + at w i)) 0 0))
  putStrLn (showInt (sumL (map (scale k) [1, 2, 3])))

-- partly applied, with a `requires` not proven: the value checks the contract at each call
{-# CONTRACT scale requires n >= 0 #-}
scale :: Int -> Int -> Int
scale n x = n * x
