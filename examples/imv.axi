-- imv — a real windowed GUI image viewer in Axión, via SDL2 + SDL2_image over the Int-ABI FFI.
--
-- This is a DEMO OF REACH, not a safe-by-construction artifact: everything across the FFI is an
-- UNSAFE island (SDL windows/textures/surfaces are manually-managed C resources the verifier and
-- linearity cannot track). The Axión side stays verify-clean; the C side is on us.
--
-- How it works on the Int-ABI FFI (every value is an i64):
--   · a `String` passes straight through as a `char*` (its NUL-terminated buffer pointer) — window
--     title, image path;
--   · a C-returned pointer (SDL_Window*/Renderer*/Texture*/Surface*) is held as an opaque `Int`
--     handle and passed back to other calls;
--   · SDL writes a struct into a buffer we pass (SDL_WaitEvent's event, SDL_QueryTexture's w/h) and
--     we read the bytes back with `charAt` — proven to work on the native backends;
--   · FFI symbol aliasing (`sdlInit = "SDL_Init"`) lets lowercase Axión names bind SDL's
--     uppercase C symbols.
-- A user FFI call BORROWS its pointer args (Axión keeps ownership and frees them once), so a passed
-- buffer stays readable after the call and is reclaimed normally.
--
-- Runs NATIVE only (cranelift `--dev` / llvm `--release`): the interpreter copies String args, so a
-- C write-back isn't visible there, and it caps FFI arity at 3.
--
-- Run (NixOS has no ldconfig, so dlopen needs SDL2/SDL2_image on LD_LIBRARY_PATH): the
-- scripts/imv-run.sh wrapper resolves the libs (via nix) and runs via the cranelift JIT —
--   scripts/imv-run.sh *.png
-- A standalone `--release -o imv` binary also works, but clang must find libSDL2.so at LINK time
-- (put the SDL2/SDL2_image lib dirs on LIBRARY_PATH for the build; LD_LIBRARY_PATH for the run).
--
-- Keys:  n / → / space  next    p / ←  prev    g / Home  first    End  last    q / Esc  quit

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
foreign "libSDL2.so" sdlRenderPresent = "SDL_RenderPresent" :: Int -> Int
foreign "libSDL2.so" sdlSetTitle = "SDL_SetWindowTitle" :: Int -> String -> Int
foreign "libSDL2.so" sdlWaitEvent = "SDL_WaitEvent" :: String -> Int
foreign "libSDL2.so" sdlQueryTexture = "SDL_QueryTexture" :: Int -> Int -> Int -> String -> String -> Int
foreign "libSDL2.so" sdlSetLogicalSize = "SDL_RenderSetLogicalSize" :: Int -> Int -> Int -> Int

-- Non-NUL filler buffer C can write into and `charAt` reads back (an embedded NUL would
-- truncate construction; SDL overwrites it anyway).
fillBuf :: Int -> String
fillBuf n = if n == 0 then "" else strAppend (chr 1) (fillBuf (n - 1))

-- little-endian u32 at byte offset `o` of buffer `s`
u32 :: String -> Int -> Int
u32 s o = charAt o s + charAt (o + 1) s * 256 + charAt (o + 2) s * 65536 + charAt (o + 3) s * 16777216

-- number of argv entries (image paths), reading by index until the first empty one
argCount :: Int -> Int
argCount i = if strLen (getArg i) == 0 then i else argCount (i + 1)

titleFor :: String -> Int -> Int -> String
titleFor path idx n =
  baseName path ++ " (" ++ showInt (idx + 1) ++ "/" ++ showInt n ++ ") — imv"

-- Render image `idx` ASPECT-FIT to the window, set the title, then BLOCK for one event and
-- dispatch. Every render FFI result is threaded into `ty` (× 0) so strict `let` evaluates them all,
-- in order, before the event read — no reorder/elision.
loop :: Int -> Int -> Int -> Int -> IO ()
loop win ren n idx =
  let path = getArg idx in
  let surf = imgLoad path in
  let tex  = sdlTexFromSurf ren surf in
  -- aspect-fit: query the texture's real WxH (SDL writes them into our buffers; charAt reads them
  -- back), then set the renderer's LOGICAL size to the image size so SDL letterbox-scales the image
  -- to the window preserving aspect (black bars) — no SDL_Rect construction needed.
  let wbuf = fillBuf 4 in
  let hbuf = fillBuf 4 in
  let qt = sdlQueryTexture tex 0 0 wbuf hbuf in
  let tw = u32 wbuf 0 in
  let th = u32 hbuf 0 in
  let a0 = sdlSetTitle win (titleFor path idx n) in
  let aL = if tw > 0 then sdlSetLogicalSize ren tw th else 0 in
  let a1 = sdlSetDrawColor ren 0 0 0 255 in
  let a2 = sdlRenderClear ren in
  let a3 = sdlRenderCopy ren tex 0 0 in
  let a4 = sdlRenderPresent ren in
  let a5 = sdlDestroyTexture tex in
  let a6 = sdlFreeSurface surf in
  let ev = fillBuf 128 in
  let we = sdlWaitEvent ev in
  let tok = (qt + a0 + aL + a1 + a2 + a3 + a4 + a5 + a6 + we) * 0 in
  let ty = u32 ev 0 + tok in
  dispatch win ren n idx ty (u32 ev 20)

-- ty = SDL event type (0x100 QUIT, 0x300 KEYDOWN); key = SDL keycode (valid only for KEYDOWN).
dispatch :: Int -> Int -> Int -> Int -> Int -> Int -> IO ()
dispatch win ren n idx ty key =
  if ty == 256 then quitWith (sdlQuit 0)
  else if ty == 768 then
    (if key == 113 then quitWith (sdlQuit 0)          -- q
     else if key == 27 then quitWith (sdlQuit 0)      -- Esc
     else if key == 110 then loop win ren n ((idx + 1) `mod` n)        -- n
     else if key == 32 then loop win ren n ((idx + 1) `mod` n)         -- space
     else if key == 1073741903 then loop win ren n ((idx + 1) `mod` n) -- Right
     else if key == 112 then loop win ren n ((idx + n - 1) `mod` n)    -- p
     else if key == 1073741904 then loop win ren n ((idx + n - 1) `mod` n) -- Left
     else if key == 103 then loop win ren n 0                        -- g (first)
     else if key == 1073741898 then loop win ren n 0                 -- Home
     else if key == 1073741901 then loop win ren n (n - 1)           -- End (last)
     else loop win ren n idx)                                        -- other key: redraw
  else loop win ren n idx                                            -- resize/expose: redraw

quitWith :: Int -> IO ()
quitWith q = putStrLn (strAppend "bye " (showInt (q * 0)))

main :: IO ()
main =
  let n = argCount 0 in
  if n == 0 then putStrLn "usage: imv -- <image>..."
  else
    let i = sdlInit 32 in                                            -- SDL_INIT_VIDEO
    let win = sdlCreateWindow "imv" 805240832 805240832 1000 700 36 in -- CENTERED, SHOWN|RESIZABLE
    let ren = sdlCreateRenderer win (0 - 1) 0 in
    loop (win + i * 0) ren n 0
