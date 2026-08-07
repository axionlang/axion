-- A bare reference to a nullary top-level binding (a CAF) is a zero-argument call,
-- not a free variable — the native backends must lower it as a call (the
-- interpreter forces the thunk). `answer` reads two CAFs and must print 42.
base :: Int
base = 40
bonus :: Int
bonus = 2
answer :: Int
answer = base + bonus

main :: IO ()
main = putStrLn (showInt answer)
