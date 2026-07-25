-- Deve PASSAR (Auto-Drop): 'Buf' é droppable (tem Drop). Largado sem consumo,
-- o compilador injecta 'free' no ponto de morte — não é erro.
-- `axionc --emit drops drop_ok.axi` mostra o free injectado.
data Buf = Buf { size :: Int }

makeAndDrop :: Buf %1 -> Int
makeAndDrop b = 0
