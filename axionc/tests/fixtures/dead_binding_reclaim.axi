-- R-4 (docs/call-site-ownership.md): a DEAD owned let-binding — `let x = <heap producer> in
-- <body that never uses x>`, e.g. an ignored heap-producing value — was leaked (neither the
-- rename source nor the renamed binding was in the droppable set) → AX0911 rejected it. The
-- rename now TRANSFERS ownership to the binding (scan_body) and inherits its drop-type
-- (collect_drop_types), so the dead value is reclaimed. Prints 42.
ignored :: Int -> Int
ignored n =
  let s = strAppend "unused-" (showInt n) in
  n + 1

main :: IO ()
main = putStrLn (showInt (ignored 41))
