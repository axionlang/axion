-- imv — a real windowed GUI image viewer in Axión, via SDL2 + SDL2_image over the Int-ABI FFI.
--
-- This is a DEMO OF REACH, not a safe-by-construction artifact: everything across the FFI is an
-- UNSAFE island (SDL windows/textures/surfaces are manually-managed C resources the verifier and
-- linearity cannot track). The Axión side stays verify-clean; the C side is on us.
--
-- How it works on the Int-ABI FFI (every value is an i64):
--   · a `String` passes straight through as a `char*` (its NUL-terminated buffer pointer);
--   · a C-returned pointer (SDL_Window*/Renderer*/Texture*/Surface*) is an opaque `Int` handle;
--   · for structs SDL reads or writes (the event, the texture/output sizes, an SDL_Rect) we use a
--     first-class `Buffer`: `newBuffer n` allocates it, `pokeU32`/`peekU32` write/read little-endian
--     ints at a byte offset, and `bufPtrN buf minBytes` hands its data address to C after checking
--     the buffer is at least `minBytes` (so an under-sized buffer aborts instead of letting C scribble
--     past the end — e.g. the 128-byte SDL event, the 16-byte rect). A Buffer is a linear resource
--     — auto-freed (axion_buf_free) when it dies, so each frame's scratch buffers reclaim cleanly;
--   · FFI symbol aliasing (`sdlInit = "SDL_Init"`) binds SDL's uppercase C symbols.
-- A user FFI call BORROWS its pointer args (Axión keeps ownership and frees them once).
--
-- Runs NATIVE only (cranelift `--dev` / llvm `--release`): the interpreter models a Buffer but does
-- no C write-back, and it caps FFI arity at 3.
--
-- Run (NixOS has no ldconfig, so dlopen needs SDL2/SDL2_image on LD_LIBRARY_PATH): the
-- scripts/imv-run.sh wrapper resolves the libs (via nix) and runs via the cranelift JIT —
--   scripts/imv-run.sh *.png
-- For a standalone binary, set LIBRARY_PATH to the SDL lib dirs at BUILD time — axionc resolves the
-- sonames and bakes their dirs into the binary's rpath, so it then runs with NO env vars.
-- `IMV_BUILD=1 scripts/imv-run.sh …` does this for you; by hand:
--   LIBRARY_PATH=<SDL2/lib>:<SDL2_image/lib> axionc -o imv examples/imv.axi
--   ./imv -- *.png          # self-contained — no LD_LIBRARY_PATH needed
--
-- Keys:  n/→/space next   p/← prev   g/Home first   End last   q/Esc quit
--        +/= zoom in   - zoom out   0 fit   h/j/k/l pan (when zoomed)

-- The Window* and Renderer* handles are LINEAR must-use resources (§18): `Handle Win` / `Handle Ren`
-- are distinct (a window can't be passed where a renderer is wanted), and the type system forces each
-- to be destroyed EXACTLY ONCE on every path — forgetting is AX0002, double-destroy AX0001, use after
-- destroy AX0004. A creating FFI returns an owned handle; a read-only op `Borrow`s it (keeps the
-- caller's ownership); the destroying FFI `Own`s it (consumes). `Win`/`Ren` are phantom tags.
data Win = Win
data Ren = Ren

foreign "libSDL2.so" sdlInit = "SDL_Init" :: Int -> Int
foreign "libSDL2.so" sdlQuit = "SDL_Quit" :: Int -> Int
foreign "libSDL2.so" sdlCreateWindow = "SDL_CreateWindow" :: String -> Int -> Int -> Int -> Int -> Int -> Handle Win
foreign "libSDL2.so" sdlCreateRenderer = "SDL_CreateRenderer" :: Borrow (Handle Win) -> Int -> Int -> Handle Ren
foreign "libSDL2.so" sdlDestroyWindow = "SDL_DestroyWindow" :: Own (Handle Win) -> Int
foreign "libSDL2.so" sdlDestroyRenderer = "SDL_DestroyRenderer" :: Own (Handle Ren) -> Int
foreign "libSDL2_image.so" imgLoad = "IMG_Load" :: String -> Int
foreign "libSDL2.so" sdlTexFromSurf = "SDL_CreateTextureFromSurface" :: Borrow (Handle Ren) -> Int -> Int
foreign "libSDL2.so" sdlFreeSurface = "SDL_FreeSurface" :: Int -> Int
foreign "libSDL2.so" sdlDestroyTexture = "SDL_DestroyTexture" :: Int -> Int
foreign "libSDL2.so" sdlSetDrawColor = "SDL_SetRenderDrawColor" :: Borrow (Handle Ren) -> Int -> Int -> Int -> Int -> Int
foreign "libSDL2.so" sdlRenderClear = "SDL_RenderClear" :: Borrow (Handle Ren) -> Int
-- dst-rect arg is NULL (0) for aspect-fit, or the SDL_Rect struct's data pointer for zoom.
foreign "libSDL2.so" sdlRenderCopy = "SDL_RenderCopy" :: Borrow (Handle Ren) -> Int -> Int -> Int -> Int
foreign "libSDL2.so" sdlRenderPresent = "SDL_RenderPresent" :: Borrow (Handle Ren) -> Int
foreign "libSDL2.so" sdlSetTitle = "SDL_SetWindowTitle" :: Borrow (Handle Win) -> String -> Int
foreign "libSDL2.so" sdlWaitEvent = "SDL_WaitEvent" :: Int -> Int
foreign "libSDL2.so" sdlQueryTexture = "SDL_QueryTexture" :: Int -> Int -> Int -> Int -> Int -> Int
foreign "libSDL2.so" sdlSetLogicalSize = "SDL_RenderSetLogicalSize" :: Borrow (Handle Ren) -> Int -> Int -> Int
foreign "libSDL2.so" sdlGetOutputSize = "SDL_GetRendererOutputSize" :: Borrow (Handle Ren) -> Int -> Int -> Int

argCount :: Int -> Int
argCount i = if strLen (getArg i) == 0 then i else argCount (i + 1)

titleFor :: String -> Int -> Int -> Int -> String
titleFor path idx n z =
  baseName path ++ " (" ++ showInt (idx + 1) ++ "/" ++ showInt n ++ ") "
    ++ (if z == 0 then "fit" else showInt z ++ "%") ++ " — imv"

-- The SDL_Rect C struct (`SDL_Rect { x, y, w, h }`, four i32s), declared once. `foreign struct`
-- computes the byte offsets and size (§18), so the body below just names the fields — no manual
-- `pokeU32 … 4 …` offsets or `newBuffer 16` size. A struct value is a `Buffer` under the hood.
foreign struct SDL_Rect { x :: I32, y :: I32, w :: I32, h :: I32 }

-- Render image `idx` at zoom `z` (0 = aspect-fit via logical size; else `z`% of real size, panned
-- by px/py). The rect's data pointer goes to C via a `borrow` scope (§18): `borrow dst as p in …`
-- leases dst's address as `p` for the block and keeps dst LIVE across the `sdlRenderCopy` call, then
-- reclaims it — so the verifier can't free the rect before SDL reads it (the use-after-free a raw
-- `bufPtr` invites, since the escaped pointer is opaque to it; that bug once showed as a black frame).
renderAt :: Handle Ren -> Int -> Int -> Int -> Int -> Int -> Int -> Int -> Int -> Int
renderAt ren tex z tw th ow oh px py =
  if z == 0 then sdlRenderCopy ren tex 0 0
  else let dw = (tw * z) `div` 100 in
       let dh = (th * z) `div` 100 in
       let dst = SDL_Rect { x = ((ow - dw) `div` 2) + px, y = ((oh - dh) `div` 2) + py, w = dw, h = dh } in
       borrow dst as p in sdlRenderCopy ren tex 0 p

-- A clean do-block: pure values are `let` bindings, SDL side effects are statements (each
-- desugars to `case <call> of _ -> rest`, so it runs in order and is never elided). No token-
-- threading, no reliance on there being no dead-binding pass — the sequencing is structural.
loop :: Handle Win %1 -> Handle Ren %1 -> Int -> Int -> Int -> Int -> Int -> IO ()
loop win ren n idx z px py = do
  let path = getArg idx
  let surf = imgLoad path
  let tex  = sdlTexFromSurf ren surf
  let wbuf = newBuffer 4
  let hbuf = newBuffer 4
  sdlQueryTexture tex 0 0 (bufPtrN wbuf 4) (bufPtrN hbuf 4)
  let tw = peekU32 wbuf 0
  let th = peekU32 hbuf 0
  let owb = newBuffer 4
  let ohb = newBuffer 4
  sdlGetOutputSize ren (bufPtrN owb 4) (bufPtrN ohb 4)
  let ow = peekU32 owb 0
  let oh = peekU32 ohb 0
  -- the % of actual size that FIT currently shows (min of the width/height scale), so the first
  -- zoom step is continuous with the displayed image instead of snapping to a fixed 100%.
  let fitPct = if tw > 0 then (if th > 0 then imin ((ow * 100) `div` tw) ((oh * 100) `div` th) else 100) else 100
  sdlSetTitle win (titleFor path idx n z)
  -- fit: logical size = image size (SDL letterboxes). zoom: disable logical size (window pixels).
  if z == 0 then sdlSetLogicalSize ren tw th else sdlSetLogicalSize ren 0 0
  sdlSetDrawColor ren 0 0 0 255
  sdlRenderClear ren
  renderAt ren tex z tw th ow oh px py
  sdlRenderPresent ren
  sdlDestroyTexture tex
  sdlFreeSurface surf
  let ev = newBuffer 128
  sdlWaitEvent (bufPtrN ev 128)
  dispatch win ren n idx z px py fitPct (peekU32 ev 0) (peekU32 ev 20)

imin :: Int -> Int -> Int
imin a b = if a < b then a else b

-- SDL event types + keycodes as named constants (§18 `foreign enum`): the dispatch below reads as a
-- `case` over `SDL_QUIT`/`KeyQ`/… instead of raw `256`/`113`. (SDL's keycodes are the actual C
-- SDLK_* values.) Each handle must still be consumed once per branch — every arm loops or quits.
foreign enum SdlEvent { SDL_QUIT = 256, SDL_KEYDOWN = 768 }
foreign enum Keycode { KeyEsc = 27, KeySpace = 32, KeyPlus = 43, KeyMinus = 45, KeyEq = 61, Key0 = 48, KeyG = 103, KeyH = 104, KeyJ = 106, KeyK = 107, KeyL = 108, KeyN = 110, KeyP = 112, KeyQ = 113, KeyHome = 1073741898, KeyEnd = 1073741901, KeyRight = 1073741903, KeyLeft = 1073741904 }

-- ty = SDL event type; key = SDL keycode (valid only for KEYDOWN). `curPct` = the currently-displayed
-- scale (fitPct in fit mode, else z), so +/- step from what's on screen. Changing image resets
-- zoom/pan; h/j/k/l pan. Every branch consumes the two linear handles exactly once (loop or quit).
dispatch :: Handle Win %1 -> Handle Ren %1 -> Int -> Int -> Int -> Int -> Int -> Int -> Int -> Int -> IO ()
dispatch win ren n idx z px py fitPct ty key =
  let curPct = if z == 0 then fitPct else z in
  case ty of
    SDL_QUIT    -> quitWith win ren
    SDL_KEYDOWN -> onKey win ren n idx z px py curPct key
    _           -> loop win ren n idx z px py                                 -- resize/expose

-- Handle one KEYDOWN. Factored out of `dispatch` so the keycode `case` isn't nested (a layout
-- quirk rejects a parenthesised `case` inside another `case` arm). Each arm threads the handles on
-- (`loop`) or consumes them (`quitWith`) — exactly once, so the must-use linearity holds.
onKey :: Handle Win %1 -> Handle Ren %1 -> Int -> Int -> Int -> Int -> Int -> Int -> Int -> IO ()
onKey win ren n idx z px py curPct key =
  case key of
    KeyQ     -> quitWith win ren
    KeyEsc   -> quitWith win ren
    KeyN     -> loop win ren n ((idx + 1) `mod` n) 0 0 0
    KeySpace -> loop win ren n ((idx + 1) `mod` n) 0 0 0
    KeyRight -> loop win ren n ((idx + 1) `mod` n) 0 0 0
    KeyP     -> loop win ren n ((idx + n - 1) `mod` n) 0 0 0
    KeyLeft  -> loop win ren n ((idx + n - 1) `mod` n) 0 0 0
    KeyG     -> loop win ren n 0 0 0 0
    KeyHome  -> loop win ren n 0 0 0 0
    KeyEnd   -> loop win ren n (n - 1) 0 0 0
    KeyPlus  -> loop win ren n idx (curPct + 2) px py
    KeyEq    -> loop win ren n idx (curPct + 2) px py
    KeyMinus -> loop win ren n idx (if curPct - 2 < 2 then 2 else curPct - 2) px py
    Key0     -> loop win ren n idx 0 0 0
    KeyH     -> loop win ren n idx z (px - 10) py
    KeyL     -> loop win ren n idx z (px + 10) py
    KeyK     -> loop win ren n idx z px (py - 10)
    KeyJ     -> loop win ren n idx z px (py + 10)
    _        -> loop win ren n idx z px py                                    -- other: redraw

-- Quit: destroy the renderer then the window (consuming both linear handles — the ONLY way out of
-- the loop that satisfies must-use), then SDL_Quit. The destroys are do-STATEMENTS (not `let`s): a
-- `let d = sdlDestroy… h` would make the drop-analysis treat `d` as inheriting the consumed handle
-- (AX0002); a statement consumes the handle and discards the Int result cleanly, in order.
quitWith :: Handle Win %1 -> Handle Ren %1 -> IO ()
quitWith win ren = do
  sdlDestroyRenderer ren
  sdlDestroyWindow win
  sdlQuit 0
  putStrLn "bye"

main :: IO ()
main =
  let n = argCount 0 in
  if n == 0 then putStrLn "usage: imv -- <image>..."
  else do
    sdlInit 32                                                        -- SDL_INIT_VIDEO
    let win = sdlCreateWindow "imv" 805240832 805240832 1000 700 36   -- CENTERED, SHOWN|RESIZABLE
    let ren = sdlCreateRenderer win (0 - 1) 0                         -- borrows win
    loop win ren n 0 0 0 0
