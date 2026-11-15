-- Two leaks that used to be documented as conservative, now reclaimed:
--   · a PARTIALLY applied built-in passed as a function (`twiceS (strAppend "x") s`) was a
--     generic closure whose String argument leaked; it now goes through the built-in's wrapper
--     (`strAppend$fn "x"`) so the higher-order function is specialized for it;
--   · `fromLeft`/`fromRight` with a heap default: the payload path returns a field of the
--     borrowed Either and the other path the owned default, so the caller could free neither.
--     The field is copied on its path (every path returns an owned value) and the unused default
--     is freed.
-- Same result on every backend, ASan + LSan clean.
twiceS :: (String -> String) -> String -> String
twiceS f s = f (f s)

pickE :: Either String String
pickE = Left (showInt 4242)

main :: Int
main =
  strLen (twiceS (strAppend "x") (showInt 5))
    + strLen (fromLeft (showInt 1) (Left (showInt 123)))
    + strLen (fromLeft (strAppend "z" "z") (Right 5))
    + strLen (fromRight (showInt 77) (Left (showInt 9)))
    + strLen (fromRight "lit" pickE)
    + fromLeft 3 (Left 4)
