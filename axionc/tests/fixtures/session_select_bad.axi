-- AX0300: selects a label (`Up`) that the `Select` does not offer.
data LR = Left | Right | Up
chooser :: Ep (Select (Left End) (Right End)) %1 -> IO ()
chooser c = do
  c2 <- select Up c
  close c2
