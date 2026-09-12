-- R-1 fixture (docs/call-site-ownership.md): exercises the whole-value param-return relation
-- `ret_alias`. `ident` returns its param bare (rename/tail); `orDefault` returns one of two
-- params across an `if` (branch union); `app` returns the tail param on its base case; `plusOne`
-- returns a fresh scalar (NOT a param). Expected ret_alias: ident{0}, orDefault{0,1}, app{1};
-- plusOne absent. (String param-OR-fresh functions like condRet are copy-normalized before this
-- runs today; R-2 moves the analysis ahead of that pass.)
ident :: String -> String
ident x = x

orDefault :: String -> String -> String
orDefault d s = if strLen s == 0 then d else s

app :: List Int -> List Int -> List Int
app xs ys = case xs of
  Nil -> ys
  Cons z zs -> Cons z (app zs ys)

plusOne :: Int -> Int
plusOne x = x + 1

main :: IO ()
main = do
  putStrLn (ident "ok")
  putStrLn (orDefault "" "x")
  putStrLn (showInt (plusOne 1))
  putStrLn (showInt (length (app (Cons 1 Nil) (Cons 2 Nil))))
