-- AX0302: an endpoint created in the nursery is RETURNED from the `bound` — it
-- would escape the nursery and could link nurseries in a cycle (deadlock). Rejected:
-- endpoints are confined to the `bound` (there is no `promote` for endpoints).
leak :: Ep a
leak = bound $ do
  (c, d) <- newChannel
  close c
  d
