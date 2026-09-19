-- parprimes.axi — a PARALLEL prime counter, and a flagship for Axión's concurrency:
-- compute π(N) (the number of primes below N) by splitting [0, N) into K chunks, running
-- one worker per chunk IN PARALLEL via the `parMap` fork-join combinator, and summing the
-- per-chunk counts.
--
-- What it demonstrates — the whole Axión concurrency thesis on a real workload:
--   * CONCURRENT + GC-FREE: K workers run on the M:N session-scheduler thread pool; every
--     allocation is reclaimed at a static point (no garbage collector).
--   * DEADLOCK-FREE + DATA-RACE-FREE BY CONSTRUCTION: each worker speaks a linear session
--     protocol `Ep (Recv Int (Send Int End))` (receive a chunk start, send back its count),
--     and `parMap` forks them inside an acyclic `bound` nursery — so the type checker rules
--     out both races (linear channels) and deadlock (tree topology) at COMPILE time.
--   * DETERMINISTIC: the workers race on wall-clock, never on the answer — the sum is always
--     π(N). π(10000) = 1229. Identical output on interp, --dev (Cranelift), --release (LLVM);
--     on --release the K chunks run genuinely in parallel (measured speedup grows with N).
--
-- `parMap worker xs` opens its own nursery, forks one `worker` per element of `xs`, sends
-- each element, and collects the replies as a `List Int` in input order; `sum` folds them.

chunks :: Int
chunks = 4

-- N = chunks * chunkSize = 10000, so π(N) = 1229 (a checkable answer).
chunkSize :: Int
chunkSize = 2500

-- Trial division: `n` is prime iff no `d` with 2 ≤ d, d*d ≤ n divides it.
isPrime :: Int -> Bool
isPrime n = if n < 2 then False else noDivFrom n 2
noDivFrom :: Int -> Int -> Bool
noDivFrom n d =
  if d * d > n then True
  else if (n `mod` d) == 0 then False
  else noDivFrom n (d + 1)

-- Count the primes in [lo, hi).
countRange :: Int -> Int -> Int
countRange i hi =
  if i >= hi then 0
  else (if isPrime i then 1 else 0) + countRange (i + 1) hi

-- One chunk's worth of primes, starting at `lo` (width `chunkSize`).
countChunk :: Int -> Int
countChunk lo = countRange lo (lo + chunkSize)

-- The parMap WORKER: a linear session that receives its chunk start, sends back the count,
-- and closes. A named top-level session function (parMap monomorphizes on it natively).
worker :: Ep (Recv Int (Send Int End)) %1 -> IO ()
worker d = do
  (lo, d2) <- recv d
  d3 <- send d2 (countChunk lo)
  close d3

-- The K chunk starts: [0, chunkSize, 2*chunkSize, …] — the parMap inputs.
starts :: Int -> List Int
starts k = startsFrom 0 k
startsFrom :: Int -> Int -> List Int
startsFrom i k = if i >= k then Nil else Cons (i * chunkSize) (startsFrom (i + 1) k)

main :: Int
main = sum (parMap worker (starts chunks))
