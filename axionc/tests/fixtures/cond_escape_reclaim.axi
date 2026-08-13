-- Auto-Drop must reclaim a conditionally-escaping OWNED heap parameter (§2). In a
-- `headOr`/`getOrElse`-shaped function the default `dflt` is RETURNED in one arm
-- (escapes) but is DEAD in the other, where the main reclamation (its
-- branch-insensitive escape set) never drops it — a leak. `reclaim_cond_escape`
-- drops it in the arm where its name is absent (proved dead, so no double-free).
-- Concrete element type (no parametric-container element leak) → allocs == frees.
data Box = Box Int
data V = Vn | Vc Box V

val :: Box -> Int
val b = case b of Box n -> n

-- `dflt` (a heap Box) is returned in the Vn arm, dead in the Vc arm.
headOr :: Box -> V -> Box
headOr dflt xs = case xs of
  Vn -> dflt
  Vc y ys -> y

-- two defaults, each escaping a different arm — both must be reclaimed.
pick :: Box -> Box -> V -> Box
pick a b xs = case xs of
  Vn -> a
  Vc y ys -> b

main :: IO ()
main = do
  putStrLn (show (val (headOr (Box 9) (Vc (Box 1) (Vc (Box 2) Vn)))))
  putStrLn (show (val (pick (Box 7) (Box 8) (Vc (Box 3) Vn))))
