-- Programa-alvo 3/5 — L1 o coração da Fase 1: linearidade end-to-end.
-- Sucesso: 'main' compila e corre; a versão comentada `useTwice` é REJEITADA
-- com AX0001 (uso-após-consumo). É o mesmo invariante que a bancada EDSL da
-- Fase 0 já valida (prototype/src/Axion/Prototype/Buffer.hs).

encrypt :: Buffer U8 %1 -> Buffer U8 %1   -- consome e devolve a posse
encrypt buf = imperative $ do
  xorInPlace buf 0x5A

-- A posse entra (%1) e sai (%1): um único fio, nunca clonado.
run :: Buffer U8 %1 -> Buffer U8 %1
run buf =
  let buf' = encrypt buf     -- 'buf' morre aqui; 'buf'' herda a posse
  in  buf'

-- ERRO ESPERADO (AX0001) — descomentar deve falhar a compilação:
-- useTwice :: Buffer U8 %1 -> (Buffer U8 %1, Buffer U8 %1)
-- useTwice buf = (encrypt buf, encrypt buf)   -- 'buf' consumido duas vezes

main :: IO ()
main = withBuffer 4096 (\buf -> free (run buf))
