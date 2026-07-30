-- Runtime de sessões (§11): programa CONCORRENTE que corre. O `bound` abre um
-- nursery; `spawn worker` forka um filho ligado por um canal; o pai envia 21, o
-- worker recebe, dobra (42) e devolve, o pai recebe e devolve 42. O scheduler
-- cooperativo (tarefas = continuações defuncionalizadas) troca no `recv` vazio.
worker :: Ep (Recv Int (Send Int End)) %1 -> IO ()
worker d = do
  (n, d2) <- recv d
  d3 <- send d2 (n + n)
  close d3

main :: Int
main = bound $ do
  c <- spawn worker
  c2 <- send c 21
  (r, c3) <- recv c2
  close c3
  r
