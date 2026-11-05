-- ffi_enum.axi — `foreign enum` (§18): named C-integer constants. A member is a global Int constant
-- usable as a value (`SDL_QUIT` → 256) and as a `case` pattern (matched by equality), turning
-- `if ty == 256 …` chains into readable `case`s. `Color` tests AUTO-INCREMENT: an omitted value is
-- previous+1 (C semantics), the first is 0 — so Red=0, Green=1, Blue=5 (explicit), Alpha=6.

foreign enum SdlEvent { SDL_QUIT = 256, SDL_KEYDOWN = 768 }
foreign enum Color { Red, Green, Blue = 5, Alpha }

name :: Int -> String
name ty = case ty of
  SDL_QUIT    -> "quit"
  SDL_KEYDOWN -> "key"
  _           -> "other"

main :: IO ()
main = do
  putStrLn (name SDL_QUIT)          -- quit   (member as pattern)
  putStrLn (name SDL_KEYDOWN)       -- key
  putStrLn (name 5)                 -- other
  putStrLn (showInt SDL_KEYDOWN)    -- 768    (member as value)
  putStrLn (showInt (Red + Green))  -- 1      (0 + 1, auto-increment)
  putStrLn (showInt Blue)           -- 5      (explicit)
  putStrLn (showInt Alpha)          -- 6      (auto-increment after explicit)
