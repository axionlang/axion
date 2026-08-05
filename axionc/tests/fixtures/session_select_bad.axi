-- AX0300: selects a label (`Up`) that the `Select` does not offer.
data LR = L | R | Up
chooser :: Ep (Select (L End) (R End)) %1 -> IO ()
chooser c = do
  c2 <- select Up c
  close c2
