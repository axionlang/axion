-- PARAMETRIC sum types (L0): constructors and selectors generalize over the
-- type parameters (`Just :: forall a. a -> Maybe a`). Uses the prelude's
-- `Maybe`, `Either`, and `fromMaybe`.  fromMaybe 0 (Just 42) + fromMaybe 7
-- Nothing = 42 + 7 = 49.
main :: Int
main = fromMaybe 0 (Just 42) + fromMaybe 7 Nothing
