{-# LANGUAGE LinearTypes #-}

{- |
Module      : Axion.Prototype.Buffer

Fase 0 — bancada de validação semântica (§17 da spec). NÃO é o compilador.

Modela o recurso central da Axion, o @Buffer U8 %1@ (Listagens 2.1–2.2), como
um EDSL sobre a extensão @LinearTypes@ do GHC. O objectivo único é validar,
em semanas e antes de escrever uma linha de compilador, a /regra da
linearidade/: todo o valor @%1@ é consumido __exactamente uma vez__. A
contracção (usar duas vezes) é rejeitada pelo typechecker — o análogo, na
bancada, do diagnóstico @AX0001@ (uso-após-consumo) do compilador próprio.

Modelo: a posse (@%1@) é imposta pelas /setas/ @%1@ das operações; o suporte
de runtime (um 'V.Vector') é irrelevante para o que se valida aqui — a Fase 0
valida a semântica, não a performance. Borrow-elision, Auto-Drop e mutação
in-place são features do /compilador/ (Fases 1–2), não exprimíveis no
@LinearTypes@ do GHC (multiplicidades só nas setas); aqui a leitura devolve a
posse explicitamente (consumir-e-devolver), à maneira do @linear-base@.
-}
module Axion.Prototype.Buffer (
  Buffer,

  -- * Alocação com âmbito (a posse entra e sai da continuação)
  withBuffer,

  -- * Operações lineares (consomem e devolvem a posse)
  set,
  get,
  checksum,

  -- * Consumo final
  free,
)
where

import Data.Unrestricted.Linear (Ur (..))
import Data.Vector qualified as V
import Data.Word (Word32, Word8)

{- | Um buffer linear de bytes. O construtor é privado: só as operações deste
módulo criam e consomem @Buffer@, garantindo que a disciplina @%1@ é a única
porta de acesso ao recurso.

O /handle/ @Buffer@ é que é linear (imposto pelas setas @%1@ das operações);
o suporte de runtime é dado banal, por isso o vector vive dentro de um 'Ur' —
o embrulho irrestrito do @linear-base@. Assim, ao consumir um @Buffer %1@,
lê-se o vector com as operações normais de "Data.Vector" sem violar a
linearidade do handle.
-}
newtype Buffer = Buffer (Ur (V.Vector Word8))

{- | Alocação com âmbito. A continuação recebe um @Buffer %1@ que __tem de__
consumir exactamente uma vez (encadeando 'set'/'get' e terminando em 'free',
ou devolvendo-o dentro do resultado). É a forma segura de introduzir posse
linear no protótipo.
-}
withBuffer :: Int -> (Buffer %1 -> Ur a) %1 -> Ur a
withBuffer n k = k (Buffer (Ur (V.replicate n 0)))

{- | Escreve um byte. Consome o @Buffer@ e devolve a posse — nunca há duas
referências vivas ao mesmo buffer (Fig. 2.1 da spec).
-}
set :: Int -> Word8 -> Buffer %1 -> Buffer
set i x (Buffer (Ur v)) = Buffer (Ur (v V.// [(i, x)]))

{- | Lê um byte. Na bancada, ler consome e devolve a posse (o @linear-base@ faz
o mesmo); no compilador real isto seria uma /elisão de empréstimo/ invisível.
-}
get :: Int -> Buffer %1 -> (Ur Word8, Buffer)
get i (Buffer (Ur v)) = (Ur (v V.! i), Buffer (Ur v))

-- | Soma de verificação (Listagem 2.2). Lê todos os bytes e devolve a posse.
checksum :: Buffer %1 -> (Ur Word32, Buffer)
checksum (Buffer (Ur v)) =
  (Ur (V.foldl' (\acc b -> acc + fromIntegral b) 0 v), Buffer (Ur v))

{- | Consome o buffer definitivamente. É o análogo, na bancada, do @free@ que o
Auto-Drop injectaria no ponto de morte (Fases 1–2).
-}
free :: Buffer %1 -> ()
free (Buffer (Ur _)) = ()
