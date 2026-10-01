-- Landing fixture for the pure-escape ANCHOR GATE (lib.rs `param_has_genuine_escape`),
-- the fix that unblocked the `lambda.axi` flagship. Two shapes the consuming-inference
-- must classify correctly:
--
--  (1) a SELF-RECURSIVE deep-copier used in a BORROWING position. `copyT` reads a value
--      and rebuilds a FRESH copy; it must stay `Many` (borrow) so a value can be copied
--      while the original stays live (`dupT` copies AND measures the same `t`). Before the
--      gate, the fixpoint justified `copyT` circularly — it optimistically marked the param
--      `%1`, then read the self-call `copyT a` as "escaping into a consuming callee" (itself)
--      and confirmed `%1`. A borrowing copier mis-inferred as consuming turns `copyT x` on a
--      borrowed interior into a double-free (DropOfAlias). The gate withdraws that self-
--      justification: a copier has NO genuine escape (its fields flow only into itself).
--
--  (2) a TUPLE-slot return (`fstStr`) — the opposite case. It returns a borrowed tuple slot
--      directly, a GENUINE escape, so it MUST stay `%1`: consume the pair, move the kept slot
--      out via a skip-destructor, and free the dropped `String` slot. The gate must detect the
--      anchor through a TUPLE pattern, not only a `data` constructor.
--
-- Runs identically on interp/cranelift/llvm; verify- and leak-clean.

data T = L String | B T T

copyT :: T -> T
copyT t = case t of
  L s -> L (strAppend s "")
  B a b -> B (copyT a) (copyT b)

sizeT :: T -> Int
sizeT t = case t of
  L s -> strLen s
  B a b -> sizeT a + sizeT b

-- borrow `t`: copy it AND measure the still-live original (both read `t`) → the use that
-- is only sound if `copyT` BORROWS. `5 + 3 + 2` doubled = 20.
dupT :: T -> Int
dupT t = sizeT (copyT t) + sizeT t

-- returns a borrowed tuple slot → must consume the pair (free the dropped slot, move the kept).
fstStr :: (String, String) -> String
fstStr p = case p of
  (a, b) -> a

sample :: T
sample = B (L "hello") (B (L "wor") (L "ld"))

main :: IO ()
main = putStrLn (strAppend (fstStr ("A", "B")) (showInt (dupT sample)))
