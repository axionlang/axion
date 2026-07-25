-- Deve PASSAR: 'b' é consumido para 'b2' (derive b), e 'b2' (Buf droppable) é
-- largado sem consumo → o Auto-Drop injecta 'free(b2)'. Drops de valores 'let',
-- não só de parâmetros. Ver `axionc --emit drops`.
data Buf = Buf { size :: Int }

derive :: Buf %1 -> Buf %1
derive b = b

f :: Buf %1 -> Int
f b = let b2 = derive b in 0
