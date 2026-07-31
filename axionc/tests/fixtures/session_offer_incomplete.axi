-- AX0304: the `case offer d` does not handle the `Closed` branch that the external
-- choice offers — a panicking peer's cancellation would go unhandled at runtime.
data Resp = Live (Ep End) | Closed (Ep End)
worker :: Ep (Offer (Live End) (Closed End)) %1 -> IO ()
worker d = case offer d of
  Live d2 -> close d2
