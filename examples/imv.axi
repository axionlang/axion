-- imv — a real windowed GUI image viewer in Axión, via SDL2 + SDL2_image over the Int-ABI FFI.
--
-- This is a DEMO OF REACH, not a safe-by-construction artifact: everything across the FFI is an
-- UNSAFE island (SDL windows/textures/surfaces are manually-managed C resources the verifier and
-- linearity cannot track). The Axión side stays verify-clean; the C side is on us.
--
-- How it works on the Int-ABI FFI (every value is an i64):
--   · a `String` passes straight through as a `char*` (its NUL-terminated buffer pointer);
--   · a C-returned pointer (SDL_Window*/Renderer*/Texture*/Surface*) is an opaque `Int` handle;
--   · SDL writes a struct into a buffer we pass (the event, the texture/output sizes) and we read
--     the bytes back with `charAt`; we build an SDL_Rect by writing ints with `pokeU32` (strAppend
--     can't — it truncates at the NUL bytes a rect contains);
--   · FFI symbol aliasing (`sdlInit = "SDL_Init"`) binds SDL's uppercase C symbols.
-- A user FFI call BORROWS its pointer args (Axión keeps ownership and frees them once).
--
-- Runs NATIVE only (cranelift `--dev` / llvm `--release`): the interpreter copies String args, so a
-- C write-back / `pokeU32` isn't visible there, and it caps FFI arity at 3.
--
-- Run (NixOS has no ldconfig, so dlopen needs SDL2/SDL2_image on LD_LIBRARY_PATH): the
-- scripts/imv-run.sh wrapper resolves the libs (via nix) and runs via the cranelift JIT —
--   scripts/imv-run.sh *.png
--
-- Keys:  n/→/space next   p/← prev   g/Home first   End last   q/Esc quit
--        +/= zoom in   - zoom out   0 fit   h/j/k/l pan (when zoomed)

foreign "libSDL2.so" sdlInit = "SDL_Init" :: Int -> Int
foreign "libSDL2.so" sdlQuit = "SDL_Quit" :: Int -> Int
foreign "libSDL2.so" sdlCreateWindow = "SDL_CreateWindow" :: String -> Int -> Int -> Int -> Int -> Int -> Int
foreign "libSDL2.so" sdlCreateRenderer = "SDL_CreateRenderer" :: Int -> Int -> Int -> Int
foreign "libSDL2_image.so" imgLoad = "IMG_Load" :: String -> Int
foreign "libSDL2.so" sdlTexFromSurf = "SDL_CreateTextureFromSurface" :: Int -> Int -> Int
foreign "libSDL2.so" sdlFreeSurface = "SDL_FreeSurface" :: Int -> Int
foreign "libSDL2.so" sdlDestroyTexture = "SDL_DestroyTexture" :: Int -> Int
foreign "libSDL2.so" sdlSetDrawColor = "SDL_SetRenderDrawColor" :: Int -> Int -> Int -> Int -> Int -> Int
foreign "libSDL2.so" sdlRenderClear = "SDL_RenderClear" :: Int -> Int
foreign "libSDL2.so" sdlRenderCopy = "SDL_RenderCopy" :: Int -> Int -> Int -> Int -> Int
-- a second alias of the SAME C symbol whose dst-rect arg is a String buffer (the zoom path);
-- src stays NULL (0). Symbol aliasing lets two Axión names bind one C function at different types.
foreign "libSDL2.so" sdlRenderCopyD = "SDL_RenderCopy" :: Int -> Int -> Int -> String -> Int
foreign "libSDL2.so" sdlRenderPresent = "SDL_RenderPresent" :: Int -> Int
foreign "libSDL2.so" sdlSetTitle = "SDL_SetWindowTitle" :: Int -> String -> Int
foreign "libSDL2.so" sdlWaitEvent = "SDL_WaitEvent" :: String -> Int
foreign "libSDL2.so" sdlQueryTexture = "SDL_QueryTexture" :: Int -> Int -> Int -> String -> String -> Int
foreign "libSDL2.so" sdlSetLogicalSize = "SDL_RenderSetLogicalSize" :: Int -> Int -> Int -> Int
foreign "libSDL2.so" sdlGetOutputSize = "SDL_GetRendererOutputSize" :: Int -> String -> String -> Int

-- Non-NUL filler buffer C can write into and `charAt` reads back (an embedded NUL would truncate
-- construction; SDL / pokeU32 overwrite it anyway).
fillBuf :: Int -> String
fillBuf n = if n == 0 then "" else strAppend (chr 1) (fillBuf (n - 1))

-- little-endian u32 at byte offset `o` of buffer `s`
u32 :: String -> Int -> Int
u32 s o = charAt o s + charAt (o + 1) s * 256 + charAt (o + 2) s * 65536 + charAt (o + 3) s * 16777216

-- a 16-byte SDL_Rect {x,y,w,h as i32 LE}, built with pokeU32 (the `if` forces all four writes
-- strictly before the buffer is returned; both arms yield the same owned buffer).
mkRect :: Int -> Int -> Int -> Int -> String
mkRect x y w h =
  let b = fillBuf 16 in
  let t = pokeU32 b 0 x + pokeU32 b 4 y + pokeU32 b 8 w + pokeU32 b 12 h in
  if t < 1 then b else b

argCount :: Int -> Int
argCount i = if strLen (getArg i) == 0 then i else argCount (i + 1)

titleFor :: String -> Int -> Int -> Int -> String
titleFor path idx n z =
  baseName path ++ " (" ++ showInt (idx + 1) ++ "/" ++ showInt n ++ ") "
    ++ (if z == 0 then "fit" else showInt z ++ "%") ++ " — imv"

-- Render image `idx` at zoom `z` (0 = aspect-fit via logical size; else `z`% of real size, panned
-- by px/py), set the title, BLOCK for one event, dispatch. All render FFI results thread into `ty`
-- (× 0) so strict `let` runs them in order before the event read.
loop :: Int -> Int -> Int -> Int -> Int -> Int -> Int -> IO ()
loop win ren n idx z px py =
  let path = getArg idx in
  let surf = imgLoad path in
  let tex  = sdlTexFromSurf ren surf in
  let wbuf = fillBuf 4 in
  let hbuf = fillBuf 4 in
  let qt = sdlQueryTexture tex 0 0 wbuf hbuf in
  let tw = u32 wbuf 0 in
  let th = u32 hbuf 0 in
  let owb = fillBuf 4 in
  let ohb = fillBuf 4 in
  let gos = sdlGetOutputSize ren owb ohb in
  let ow = u32 owb 0 in
  let oh = u32 ohb 0 in
  let a0 = sdlSetTitle win (titleFor path idx n z) in
  -- fit: logical size = image size (SDL letterboxes). zoom: disable logical size (window pixels).
  let aL = if z == 0 then sdlSetLogicalSize ren tw th else sdlSetLogicalSize ren 0 0 in
  let a1 = sdlSetDrawColor ren 0 0 0 255 in
  let a2 = sdlRenderClear ren in
  let a3 = if z == 0 then sdlRenderCopy ren tex 0 0
           else (let dw = (tw * z) `div` 100 in
                 let dh = (th * z) `div` 100 in
                 let dst = mkRect (((ow - dw) `div` 2) + px) (((oh - dh) `div` 2) + py) dw dh in
                 sdlRenderCopyD ren tex 0 dst) in
  let a4 = sdlRenderPresent ren in
  let a5 = sdlDestroyTexture tex in
  let a6 = sdlFreeSurface surf in
  let ev = fillBuf 128 in
  let we = sdlWaitEvent ev in
  let tok = (qt + gos + a0 + aL + a1 + a2 + a3 + a4 + a5 + a6 + we) * 0 in
  let ty = u32 ev 0 + tok in
  dispatch win ren n idx z px py ty (u32 ev 20)

-- entering zoom from fit starts at 100%; otherwise step by 25%, floor 25%.
zoomIn :: Int -> Int
zoomIn z = if z == 0 then 100 else z + 25
zoomOut :: Int -> Int
zoomOut z = if z == 0 then 75 else (if z - 25 < 25 then 25 else z - 25)

-- ty = SDL event type (0x100 QUIT, 0x300 KEYDOWN); key = SDL keycode (valid only for KEYDOWN).
-- Changing image resets zoom/pan (a fresh image starts fit); +/-/0 keep the index; h/j/k/l pan.
dispatch :: Int -> Int -> Int -> Int -> Int -> Int -> Int -> Int -> Int -> IO ()
dispatch win ren n idx z px py ty key =
  if ty == 256 then quitWith (sdlQuit 0)
  else if ty == 768 then
    (if key == 113 then quitWith (sdlQuit 0)                                  -- q
     else if key == 27 then quitWith (sdlQuit 0)                              -- Esc
     else if key == 110 then loop win ren n ((idx + 1) `mod` n) 0 0 0         -- n
     else if key == 32 then loop win ren n ((idx + 1) `mod` n) 0 0 0          -- space
     else if key == 1073741903 then loop win ren n ((idx + 1) `mod` n) 0 0 0  -- Right
     else if key == 112 then loop win ren n ((idx + n - 1) `mod` n) 0 0 0     -- p
     else if key == 1073741904 then loop win ren n ((idx + n - 1) `mod` n) 0 0 0 -- Left
     else if key == 103 then loop win ren n 0 0 0 0                           -- g (first)
     else if key == 1073741898 then loop win ren n 0 0 0 0                    -- Home
     else if key == 1073741901 then loop win ren n (n - 1) 0 0 0              -- End
     else if key == 43 then loop win ren n idx (zoomIn z) px py              -- +
     else if key == 61 then loop win ren n idx (zoomIn z) px py              -- =
     else if key == 45 then loop win ren n idx (zoomOut z) px py             -- -
     else if key == 48 then loop win ren n idx 0 0 0                          -- 0 (fit)
     else if key == 104 then loop win ren n idx z (px + 60) py                -- h
     else if key == 108 then loop win ren n idx z (px - 60) py                -- l
     else if key == 107 then loop win ren n idx z px (py + 60)                -- k
     else if key == 106 then loop win ren n idx z px (py - 60)                -- j
     else loop win ren n idx z px py)                                         -- other: redraw
  else loop win ren n idx z px py                                             -- resize/expose

quitWith :: Int -> IO ()
quitWith q = putStrLn (strAppend "bye " (showInt (q * 0)))

main :: IO ()
main =
  let n = argCount 0 in
  if n == 0 then putStrLn "usage: imv -- <image>..."
  else
    let i = sdlInit 32 in                                              -- SDL_INIT_VIDEO
    let win = sdlCreateWindow "imv" 805240832 805240832 1000 700 36 in -- CENTERED, SHOWN|RESIZABLE
    let ren = sdlCreateRenderer win (0 - 1) 0 in
    loop (win + i * 0) ren n 0 0 0 0
