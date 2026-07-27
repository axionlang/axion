-- AX0302: um endpoint criado no nursery é DEVOLVIDO do `bound` — escaparia ao
-- nursery e poderia ligar nurseries em ciclo (deadlock). Rejeitado: os endpoints
-- são confinados ao `bound` (não há `promote` de endpoints).
leak :: Ep a
leak = bound $ do
  (c, d) <- newChannel
  close c
  d
