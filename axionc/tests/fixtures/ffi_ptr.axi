-- ffi_ptr.axi — the first-class opaque-handle type `Ptr a` (§18). `Ptr a` is a type-SAFE C handle:
-- distinct from `Int` and from every other `Ptr b` (so a Window* can't be passed where a Renderer*
-- is wanted — a compile error, not a silent raw-Int mix-up). It flows as a raw i64 and is never
-- reclaimed. `intToPtr`/`ptrToInt` are the explicit casts; `nullPtr` is the null handle (C NULL).
-- No FFI call here (so it runs on every backend) — just the Ptr vocabulary and its type discipline.

data Win = MkWin
data Ren = MkRen

-- distinct handle kinds: these two signatures can never be confused by the type-checker.
asWin :: Int -> Ptr Win
asWin n = intToPtr n

asRen :: Int -> Ptr Ren
asRen n = intToPtr n

isNull :: Ptr a -> Bool
isNull p = ptrToInt p == 0

main :: IO ()
main = do
  putStrLn (showInt (ptrToInt (asWin 1000)))
  putStrLn (showInt (ptrToInt (asRen 2000)))
  putStrLn (if isNull nullPtr then "null" else "nonnull")
  putStrLn (if isNull (asWin 7) then "null" else "nonnull")
