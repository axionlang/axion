-- Malformed contracts (AX0603) and predicates outside the refinement language (AX0601).
{-# CONTRACT nosuch requires x > 0 #-}

{-# CONTRACT nosig requires x > 0 #-}
nosig x = x + 1

{-# CONTRACT badname requires y > 0 #-}
badname :: Int -> Int
badname x = x

{-# CONTRACT notint requires s > 0 #-}
notint :: String -> Int
notint s = 1

{-# CONTRACT nokw x > 0 #-}
nokw :: Int -> Int
nokw x = x

{-# CONTRACT badpred requires x > > 0 #-}
badpred :: Int -> Int
badpred x = x

{-# CONTRACT twice requires x > 0 #-}
{-# CONTRACT twice ensures result > 0 #-}
twice :: Int -> Int
twice x = x

main :: IO ()
main = putStrLn "x"
