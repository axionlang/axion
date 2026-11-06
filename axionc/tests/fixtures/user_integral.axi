-- user_integral.axi — `Integral` (`div`/`mod`) is a real class: a user type gets backtick-infix
-- `` `div` ``/`` `mod` `` by declaring `instance Integral`, dispatched to `div$T`/`mod$T`; the
-- primitive `Int`/`Integer` path (native `div`/`mod`) is untouched.
data M = M Int
unM :: M -> Int
unM m = case m of M n -> n
divM :: M -> M -> M
divM a b = M (unM a `div` unM b)
modM :: M -> M -> M
modM a b = M (unM a `mod` unM b)
instance Integral M where
  div a b = divM a b
  mod a b = modM a b

main :: IO ()
main = do
  putStrLn (showInt (17 `div` 5))              -- 3  (primitive Int)
  putStrLn (showInt (17 `mod` 5))              -- 2
  putStrLn (showInt (unM (M 17 `div` M 5)))    -- 3  (user div$M)
  putStrLn (showInt (unM (M 17 `mod` M 5)))    -- 2
