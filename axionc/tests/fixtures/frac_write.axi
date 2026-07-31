-- Must FAIL with AX0006: 'a' is a %0.5 half (shared read) and is passed to
-- 'writeCfg' (a %1 parameter) — writing through a half is not allowed; recombine
-- with 'join' to recover write access (§2, Listing 2.3).
data Config = Config { level :: Int }

writeCfg :: Config %1 -> Config
writeCfg c = c

splitBad :: Config %1 -> Config
splitBad cfg = case split cfg of
  (a, b) -> writeCfg a
