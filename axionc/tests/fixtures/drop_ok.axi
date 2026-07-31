-- Must PASS (Auto-Drop): 'Buf' is droppable (has Drop). Dropped without being
-- consumed, the compiler injects 'free' at the death point — it is not an error.
-- `axionc --emit drops drop_ok.axi` shows the injected free.
data Buf = Buf { size :: Int }

makeAndDrop :: Buf %1 -> Int
makeAndDrop b = 0
