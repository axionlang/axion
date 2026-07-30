-- Monomorfização (fatia 2b-ii): chamadas de método sobre recetores estaticamente
-- concretos são reescritas para chamadas directas à impl (`sz (Box 10)` →
-- `sz$Box (Box 10)`), logo COMPILAM NATIVAMENTE. Corre nos três executores
-- (interp, --dev/Cranelift, --release/LLVM), todos a dar 20.
-- Instâncias escritas com `case`/aritmética (nativa-amigáveis): padrões-construtor
-- em cabeças multi-cláusula ainda são interp-only (limitação nativa ortogonal).
class Sized a where
  sz :: a -> Int

data Box = Box Int

instance Sized Box where
  sz b = case b of
    Box n -> n

instance Sized Int where
  sz x = x * 2

main :: Int
main = sz (Box 10) + sz 5
