-- PARAMETRIC sum types (L0): constructors and selectors generalize over the
-- type parameters (`Some :: forall a. a -> Maybe a`). fromMaybe 0 (Some 42) +
-- fromMaybe 7 None = 42 + 7 = 49.
data Maybe a = None | Some a
data Either a b = Left a | Right b

fromMaybe :: Int -> Maybe Int -> Int
fromMaybe d m = case m of
  None -> d
  Some x -> x

main :: Int
main = fromMaybe 0 (Some 42) + fromMaybe 7 None
