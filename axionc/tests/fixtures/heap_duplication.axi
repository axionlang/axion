-- Must FAIL with AX0001: duplicating a HEAP value by ownership. `Two xs xs` moves
-- the borrowed list `xs` into BOTH owned fields of `Two` — aliasing it — and the
-- native deep-drop would then free the shared payload twice (a double-free that the
-- linearity checker previously accepted). Sharing by ownership requires `split`
-- into %0.5 halves (§2). `xs` may be READ any number of times; it may be MOVED once.
data Box = Box Int
data Two = Two (List Box) (List Box)

mk :: List Box -> Two
mk xs = Two xs xs
