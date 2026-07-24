-- Programa-alvo 5/5 — L1 elisão de empréstimos: ler sem consumir (Listagem 2.2).
-- Sucesso da Fase 1: 'checksum' não tem %1 no argumento => o compilador toma-o
-- emprestado como slice; a posse nunca sai do chamador. 'process' lê e a seguir
-- passa a MESMA posse a 'encrypt' — sem cópia, sem AX0001.

checksum :: Buffer U8 -> U32            -- borrow: sem %1, 'buf' NÃO é consumido
checksum buf = foldBytes (+) 0 buf

encrypt :: Buffer U8 %1 -> Buffer U8 %1 -- consome e devolve a posse
encrypt buf = imperative $ do xorInPlace buf 0x5A

process :: Buffer U8 %1 -> (U32, Buffer U8 %1)
process buf =
  let sig = checksum buf   -- empréstimo implícito: 'buf' AINDA é possuído aqui
  in  (sig, encrypt buf)   -- a posse flui para 'encrypt'; sem clone, sem AX0001
