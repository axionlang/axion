-- Internal choice (⊕, §6): the endpoint selects the label `Left` of a `Select` and
-- advances to that branch's continuation (`End`), then closes. Accepted.
data LR = Left | Right
chooser :: Ep (Select (Left End) (Right End)) %1 -> IO ()
chooser c = do
  c2 <- select Left c
  close c2
