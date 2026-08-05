-- Internal choice (⊕, §6): the endpoint selects the label `L` of a `Select` and
-- advances to that branch's continuation (`End`), then closes. Accepted.
data LR = L | R
chooser :: Ep (Select (L End) (R End)) %1 -> IO ()
chooser c = do
  c2 <- select L c
  close c2
