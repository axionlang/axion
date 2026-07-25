-- Deve FALHAR com AX0006: 'a' é uma metade %0.5 (leitura partilhada) e é
-- passada a 'writeCfg' (parâmetro %1) — escrever através de uma metade não é
-- permitido; recombine com 'join' para recuperar a escrita (§2, Listagem 2.3).
data Config = Config { level :: Int }

writeCfg :: Config %1 -> Config
writeCfg c = c

splitBad :: Config %1 -> Config
splitBad cfg = case split cfg of
  (a, b) -> writeCfg a
