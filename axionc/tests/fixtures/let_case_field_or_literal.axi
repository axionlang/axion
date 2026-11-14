-- A `let` bound to a `case` whose arms return a String FIELD the arm bound (moved out of the
-- consumed scrutinee) or a literal was never freed: no arm was a recognized owned producer, so
-- the conditional-temp reclaim skipped it and the drop verifier refused it (AX0911). The field's
-- type now comes from the scrutinee's mono key (`Maybe$String`), and every arm is copied to an
-- owned String, freed after the `let`'s last use. Same result on every backend, ASan + LSan clean.
data Tagged = Tagged String Int | Untagged

fromMaybe :: Int -> Int
fromMaybe n =
  let s = (case Just (showInt n) of
        Just v -> v
        Nothing -> "")
  in strLen s + strLen s

fromEither :: Int -> Int
fromEither n =
  let s = (case (if n > 3 then Left (showInt n) else Right n) of
        Left v -> v
        Right k -> "none")
  in strLen s

fromData :: Int -> Int
fromData n =
  let s = (case Tagged (strAppend "t" (showInt n)) n of
        Tagged v k -> v
        Untagged -> "-")
  in strLen s + charAt 0 s

-- two sibling `case`s binding the same name `v`: each arm's binder is local to that arm (an arm
-- that did not bind `v` used to get a `drop v` of the other case's `v` — invalid code)
nested :: Int
nested = strLen (case Just ((case Just ("s1") of
    Just v -> v
    Nothing -> "")) of
    Just v -> v
    Nothing -> "")

main :: Int
main = fromMaybe 1234 + fromEither 7 + fromEither 2 + fromData 42 + nested
