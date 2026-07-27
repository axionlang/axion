-- AX0300: escolhe um rótulo (`Up`) que o `Select` não oferece.
data LR = Left | Right | Up
chooser :: Ep (Select (Left End) (Right End)) %1 -> IO ()
chooser c = do
  c2 <- select Up c
  close c2
