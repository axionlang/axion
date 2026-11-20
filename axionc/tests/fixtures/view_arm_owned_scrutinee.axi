-- An arm that returns its OWNED scrutinee whole (`Just s -> a`) hands the unused field binder
-- on inside it, and a nullary arm (`Nothing -> b`) has an immediate scrutinee with nothing to free.
-- The verifier used to report both as corruption (a false positive for `%1` params, and for
-- params the caller moves in once those were tracked as owned).
keepOr :: Maybe (Int -> Int) %1 -> Maybe (Int -> Int) %1 -> Maybe (Int -> Int)
keepOr a b = case a of
  Just f -> a
  Nothing -> b

keepS :: Maybe String %1 -> Maybe String %1 -> Maybe String
keepS a b = case a of
  Just s -> a
  Nothing -> b

main :: Int
main = let k = keepOr (Just (\x -> x + 1)) Nothing in case k of
  Just g -> let w = keepS (Just "hi") (Just "yo") in case w of
    Just s -> g (strLen s)
    Nothing -> 0
  Nothing -> 0
