-- layout_semi_do.axi — `;` as a do-statement separator on one line. (`;` directly after a do-`let`
-- hits the separate, pre-existing do-`let` layout limitation and is out of scope here.)
greet :: String -> String
greet s = case s of "hi" -> "hello" ; _ -> "?"

main :: IO ()
main = do
  putStrLn "a" ; putStrLn "b" ; putStrLn "c"
  putStrLn (greet "hi") ; putStrLn (greet "x")
