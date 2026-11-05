-- ffi_struct.axi — `foreign struct` (§18): a C-ABI-laid-out byte record for FFI. The compiler
-- computes each field's offset and the total size per the C ABI (incl. padding), so you name fields
-- instead of counting bytes. Construction `S { f = e, … }` allocates a sized Buffer and pokes each
-- field; a selector `f s` peeks it back. The runtime value is a Buffer (reclaimed as usual).
--
-- `Pad` exercises the ALIGNMENT ENGINE: { a::I8, b::I32, c::I8 } is NOT packed — C pads `b` to
-- offset 4 (and the struct to 12 bytes). Reading `b` back as 777 proves the offset is 4, not 1.

foreign struct SDL_Rect { x :: I32, y :: I32, w :: I32, h :: I32 }
foreign struct Pad { a :: I8, b :: I32, c :: I8 }

main :: IO ()
main = do
  let r = SDL_Rect { x = 10, y = 20, w = 640, h = 480 }
  putStrLn (showInt (x r + y r + w r + h r))   -- 1150
  let p = Pad { a = 1, b = 777, c = 9 }
  putStrLn (showInt (a p))                       -- 1
  putStrLn (showInt (b p))                       -- 777 (offset 4, past the padding)
  putStrLn (showInt (c p))                       -- 9
