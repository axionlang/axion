-- Programa-alvo 4/5 — L1 Auto-Drop + mutação in-place inferidos (Listagem 2.1).
-- Sucesso da Fase 1: um registo com campo linear embutido; a última menção viva
-- de 'p' vira mutação in-place do campo; se 'p'' não fosse devolvido, o
-- Auto-Drop injectaria free(p'.buffer).

data Process = Process
  { pid    :: Int
  , status :: String
  , buffer :: Buffer U8 %1     -- campo linear embutido no registo
  }

-- 'p' é consumido (%1) e devolvido (%1): a posse entra e sai, nunca clonada.
updateKernel :: Process %1 -> Process %1
updateKernel p =
  let p' = p { status = "Running" }   -- última menção viva de 'p'
  in  p'
  -- 1. O buffer interno nunca é copiado (elisão de empréstimos).
  -- 2. 'p' morre aqui -> o compilador MUTA o campo 'status' in-place.
  -- 3. Se 'p'' não fosse devolvido, o Auto-Drop injectaria free(p'.buffer).
