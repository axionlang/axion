-- Must PASS: 'b' is consumed into 'b2' (derive b), and 'b2' (a droppable Buf) is
-- dropped without being consumed → Auto-Drop injects 'free(b2)'. Drops of 'let'
-- values, not only of parameters. See `axionc --emit drops`.
data Buf = Buf { size :: Int }

derive :: Buf %1 -> Buf %1
derive b = b

f :: Buf %1 -> Int
f b = let b2 = derive b in 0
