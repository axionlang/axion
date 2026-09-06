-- The effect model's core guarantee: each syntactic occurrence of an effectful call
-- performs the effect — occurrences are never coalesced (no CSE) or dropped. `tick` is
-- referenced twice, so the command runs twice: the file gets two bytes. (runStatus of a
-- successful printf is 0, so main prints 0 on every backend.) The test counts the bytes.
tick :: Int
tick = runStatus "printf x >> \"$AXION_EFF_FILE\""

main :: Int
main = tick + tick
