-- Escolha interna (⊕, §6): o endpoint escolhe o rótulo `Left` de um `Select` e
-- avança para a continuação desse ramo (`End`), depois fecha. Aceite.
data LR = Left | Right
chooser :: Ep (Select (Left End) (Right End)) %1 -> IO ()
chooser c = do
  c2 <- select Left c
  close c2
