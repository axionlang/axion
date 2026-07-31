-- Must PASS: reading a %1 twice is two BORROWS (Borrow Elision, §2), not a
-- contraction. Auto-Drop injects 'free' after the last read (the second 'x').
readTwice :: Int %1 -> Int
readTwice x = x + x
