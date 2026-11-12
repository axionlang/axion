-- aximv — a real windowed GUI image viewer in Axión, via SDL2 + SDL2_image over the Int-ABI FFI.
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
-- Build & run (SDL2/SDL2_image must be findable at BUILD time; axionc bakes their dirs into the
-- binary's rpath, so it then runs with NO env vars). Simplest, one command:
--   nix develop        # the dev shell puts SDL2 + SDL2_image on LIBRARY_PATH
--   axionc -o aximv examples/aximv.axi
--   ./aximv -- *.png          # self-contained — no LD_LIBRARY_PATH needed
-- On a distro with SDL in the system lib dirs, `axionc -o aximv examples/aximv.axi` works with no shell.
-- For a quick run (cranelift JIT, resolves the libs via nix): `scripts/aximv-run.sh *.png`.
-- (The SDL libs are deliberately NOT static-linked — their X11/wayland/audio deps make that fragile;
-- the rpath makes the dynamic binary portable instead.)
--
-- Keys:  n/→/space next   p/← prev   g/Home first   End last   q/Esc quit
--        +/= zoom in   - zoom out   0 fit   r rotate cw   R rotate ccw   h/j/k/l pan
--
-- Config:  ~/.config/aximv/config.lua — a Lua table of { key, action } rows, like axfm. A key may be
-- a multi-char sequence (press them in order). (imv has no Lua interpreter; a `sed` pass parses the
-- table at startup.) An action is either:
--   · a SHELL command `!cmd` — run on the CURRENT image, where `%s` is its path (shell-quoted); or
--   · a BUILT-IN action NAME, to rebind a default key: zoom_in, zoom_out, fit, rotate, rotate_ccw,
--     pan_left, pan_right, pan_up, pan_down, next, prev, first, last, quit.
-- A `key` is a sequence of TOKENS: a printable char (`d`), a special key `<Right>`/`<Left>`/`<Up>`/
-- `<Down>`/`<Home>`/`<End>`/`<Esc>`/`<Space>`, and/or a modifier prefix `C-` (Ctrl) or `M-` (Alt).
--   local keys = {
--     { key = "dd",      action = "!rm %s" },                    -- dd: delete, then show the next
--     { key = "r",       action = "!convert %s -rotate 90 %s" }, -- r:  rotate in place
--     { key = "<Right>", action = "zoom_in"  },                 -- arrow key → zoom in
--     { key = "<Left>",  action = "zoom_out" },
--     { key = "C-b",     action = "prev" },                     -- Ctrl-b → previous image
--     { key = "C-<Up>",  action = "first" },                    -- Ctrl + arrow
--     { key = "<",       action = "prev" },  { key = ">", action = "next" },  -- shifted glyphs work
--   }
-- Shifted keys are written as the glyph on the cap (`<`, `?`, `A`), assuming a US layout; a bare
-- modifier key alone is ignored, so it never disturbs a pending sequence.

-- The Window* and Renderer* handles are LINEAR must-use resources (§18): `Handle Win` / `Handle Ren`
-- are distinct (a window can't be passed where a renderer is wanted), and the type system forces each
-- to be destroyed EXACTLY ONCE on every path — forgetting is AX0002, double-destroy AX0001, use after
-- destroy AX0004. A creating FFI returns an owned handle; a read-only op `Borrow`s it (keeps the
-- caller's ownership); the destroying FFI `Own`s it (consumes). `Win`/`Ren` are phantom tags.
data Win = Win
data Ren = Ren
-- Textures, surfaces and GIF animations are linear handles too, so their lifetimes are CHECKED rather
-- than managed by hand: every path must destroy each one exactly once. A loader can return NULL (a
-- deleted file); `handleAddr` reads the address without consuming the handle, and the NULL path still
-- hands it to its destroyer (SDL_FreeSurface(NULL) / IMG_FreeAnimation(NULL) are no-ops).
data Tex = Tex
data Surf = Surf
data Anim = Anim

foreign "libSDL2.so" sdlInit = "SDL_Init" :: Int -> Int
foreign "libSDL2.so" sdlQuit = "SDL_Quit" :: Int -> Int
foreign "libSDL2.so" sdlCreateWindow = "SDL_CreateWindow" :: String -> Int -> Int -> Int -> Int -> Int -> Handle Win
foreign "libSDL2.so" sdlCreateRenderer = "SDL_CreateRenderer" :: Borrow (Handle Win) -> Int -> Int -> Handle Ren
foreign "libSDL2.so" sdlDestroyWindow = "SDL_DestroyWindow" :: Own (Handle Win) -> Int
foreign "libSDL2.so" sdlDestroyRenderer = "SDL_DestroyRenderer" :: Own (Handle Ren) -> Int
foreign "libSDL2_image.so" imgLoad = "IMG_Load" :: String -> Handle Surf
foreign "libSDL2.so" sdlTexFromSurf = "SDL_CreateTextureFromSurface" :: Borrow (Handle Ren) -> Borrow (Handle Surf) -> Handle Tex
-- a GIF frame's surface belongs to its IMG_Animation (freed with it), so it stays a raw pointer here
foreign "libSDL2.so" sdlTexFromFrame = "SDL_CreateTextureFromSurface" :: Borrow (Handle Ren) -> Int -> Handle Tex
foreign "libSDL2.so" sdlFreeSurface = "SDL_FreeSurface" :: Own (Handle Surf) -> Int
foreign "libSDL2.so" sdlDestroyTexture = "SDL_DestroyTexture" :: Own (Handle Tex) -> Int
foreign "libSDL2.so" sdlSetDrawColor = "SDL_SetRenderDrawColor" :: Borrow (Handle Ren) -> Int -> Int -> Int -> Int -> Int
foreign "libSDL2.so" sdlRenderClear = "SDL_RenderClear" :: Borrow (Handle Ren) -> Int
-- Render the texture into a dst rect, ROTATED `angle`° clockwise about the rect's centre (the extra
-- args over SDL_RenderCopy: angle, center=NULL, flip=0). One call serves fit, zoom, pan AND rotation.
-- The angle is a C `double` → passed as a `Float` over the double-ABI FFI. (srcrect = 0 = whole texture.)
foreign "libSDL2.so" sdlRenderCopyEx = "SDL_RenderCopyEx" :: Borrow (Handle Ren) -> Borrow (Handle Tex) -> Int -> Int -> Float -> Int -> Int -> Int
foreign "libSDL2.so" sdlRenderPresent = "SDL_RenderPresent" :: Borrow (Handle Ren) -> Int
foreign "libSDL2.so" sdlSetTitle = "SDL_SetWindowTitle" :: Borrow (Handle Win) -> String -> Int
foreign "libSDL2.so" sdlWaitEvent = "SDL_WaitEvent" :: Int -> Int
-- SDL_FlushEvent(type): drop every queued event of `type`. Used to discard the key-REPEAT backlog
-- that a held key piles up while the (reload-per-frame) loop is busy — so releasing the key stops
-- zoom/pan at the next frame instead of draining a queue of stale repeats for seconds afterward.
foreign "libSDL2.so" sdlFlushEvent = "SDL_FlushEvent" :: Int -> Int
foreign "libSDL2.so" sdlQueryTexture = "SDL_QueryTexture" :: Borrow (Handle Tex) -> Int -> Int -> Int -> Int -> Int
foreign "libSDL2.so" sdlGetOutputSize = "SDL_GetRendererOutputSize" :: Borrow (Handle Ren) -> Int -> Int -> Int
-- Animated images (GIF/WEBP). IMG_LoadAnimation returns an `IMG_Animation*` — a C struct we read field
-- by field with `memcpy` (there is no raw-address peek; memcpy copies the bytes into a Buffer we own,
-- then `peek*` reads them). 64-bit layout: { int w@0; int h@4; int count@8; SDL_Surface **frames@16;
-- int *delays@24; } — so count = peekU32 hdr 8, frames-array ptr = peekU64 hdr 16, delays-array ptr =
-- peekU64 hdr 24. IMG_FreeAnimation frees the struct AND every frame surface (so we must NOT free those
-- surfaces ourselves — unlike the IMG_Load path). SDL_WaitEventTimeout waits up to `ms` for an event
-- (returns 1) or times out (returns 0) — that timeout is the frame clock that makes the GIF play.
foreign "libSDL2_image.so" imgLoadAnimation = "IMG_LoadAnimation" :: String -> Handle Anim
foreign "libSDL2_image.so" imgFreeAnimation = "IMG_FreeAnimation" :: Own (Handle Anim) -> Int
foreign "libSDL2.so" sdlWaitEventTimeout = "SDL_WaitEventTimeout" :: Int -> Int -> Int
foreign "libc.so.6" memcpy = "memcpy" :: Int -> Int -> Int -> Int
foreign "libc.so.6" memcpyAnim = "memcpy" :: Int -> Borrow (Handle Anim) -> Int -> Int

argCount :: Int -> Int
argCount i = if strLen (getArg i) == 0 then i else argCount (i + 1)

-- ─── Folder image list ───────────────────────────────────────────────────────────────────────────
-- The images aximv cycles through with next/prev are NOT the command-line args — they are every image
-- in the SEED's directory, sorted. So opening one file (`aximv photo.jpg`) still lets you page through
-- the whole folder, and `aximv` with no arg views the current directory from its first image. At
-- startup `buildImgList` writes that sorted list (one absolute-ish path per line) to a cache file; the
-- loop reads the idx-th line per query (same reload-per-use idiom as the keymap — tiny files, and no
-- long-lived heap List to thread through the already-wide frame signature).
imgListFile :: Int -> String
imgListFile d = envOr "HOME" "." ++ "/.cache/aximv/filelist"
-- Build the list for SEED's directory (SEED may be a file, a directory, or "." for the cwd — resolved
-- in the shell: a dir is used as-is, a file contributes its dirname). `find -maxdepth 1` keeps it to
-- that one folder; the extension set matches what SDL2_image decodes. LC_ALL=C sort = stable order.
buildImgList :: String -> Int
buildImgList seed = runStatus
  ("lf=" ++ shQuote (imgListFile 0) ++ "; mkdir -p \"${lf%/*}\"; s=" ++ shQuote seed ++ "; "
   ++ "if [ -d \"$s\" ]; then d=\"$s\"; else d=$(dirname \"$s\"); fi; "
   ++ "find \"$d\" -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' "
   ++ "-o -iname '*.gif' -o -iname '*.bmp' -o -iname '*.webp' -o -iname '*.tif' -o -iname '*.tiff' "
   ++ "-o -iname '*.avif' -o -iname '*.jxl' -o -iname '*.ppm' -o -iname '*.pgm' \\) "
   ++ "| LC_ALL=C sort > \"$lf\"")
imgLines :: Int -> List String
imgLines d = lines (readFile (imgListFile 0))
imageCount :: Int -> Int
imageCount d = length (imgLines 0)
-- the idx-th image path (a fresh copy, so the rest of the list drops cleanly); "" if out of range.
imagePath :: Int -> String
imagePath idx = nthLine (imgLines 0) idx
nthLine :: List String -> Int -> String
nthLine xs i = case xs of
  Nil -> ""
  Cons y ys -> if i == 0 then dup y else nthLine ys (i - 1)
-- Where SEED sits in the list (so opening a specific file starts there); 0 for a directory/no-arg seed.
-- Matched by basename (the list holds `<dir>/<base>` while SEED may be bare or relative).
startIndex :: String -> Int
startIndex seed = if seed == "." then 0 else findByBase (imgLines 0) (baseName seed) 0
findByBase :: List String -> String -> Int -> Int
findByBase xs b i = case xs of
  Nil -> 0
  Cons y ys -> if baseName y == b then i else findByBase ys b (i + 1)

titleFor :: String -> Int -> Int -> Int -> String
titleFor path idx n z =
  baseName path ++ " (" ++ showInt (idx + 1) ++ "/" ++ showInt n ++ ") "
    ++ (if z == 0 then "fit" else showInt z ++ "%") ++ " — aximv"

-- The SDL_Rect C struct (`SDL_Rect { x, y, w, h }`, four i32s), declared once. `foreign struct`
-- computes the byte offsets and size (§18), so the body below just names the fields — no manual
-- `pokeU32 … 4 …` offsets or `newBuffer 16` size. A struct value is a `Buffer` under the hood.
foreign struct SDL_Rect { x :: I32, y :: I32, w :: I32, h :: I32 }

-- Render image `idx` at zoom `z` (0 = aspect-fit via logical size; else `z`% of real size, panned
-- by px/py). The rect's data pointer goes to C via a `borrow` scope (§18): `borrow dst as p in …`
-- leases dst's address as `p` for the block and keeps dst LIVE across the `sdlRenderCopy` call, then
-- reclaims it — so the verifier can't free the rect before SDL reads it (the use-after-free a raw
-- `bufPtr` invites, since the escaped pointer is opaque to it; that bug once showed as a black frame).
-- Draw the texture at `pct`% of its real size, panned by px/py and rotated `rot`° about the window
-- centre. `dst` is sized for the UNROTATED texture and window-centred, so the rotation pivot is the
-- centre → the image stays centred at any angle. (The caller picks `pct` = fit-scale or the zoom %.)
renderAt :: Handle Ren -> Handle Tex -> Int -> Int -> Int -> Int -> Int -> Int -> Int -> Int -> Int
renderAt ren tex rot pct tw th ow oh px py =
  let dw = (tw * pct) / 100 in
  let dh = (th * pct) / 100 in
  let dst = SDL_Rect { x = ((ow - dw) / 2) + px, y = ((oh - dh) / 2) + py, w = dw, h = dh } in
  borrow dst as p in sdlRenderCopyEx ren tex 0 p (toFloat rot) 0 0

-- Load the image for `idx` into a texture ONCE, query its size, then enter the render/event loop on
-- it. The texture is REUSED across zoom/pan (`frame` loops without reloading) — reloading+decoding
-- from disk every frame was the sluggishness. `tex` is a linear `Handle Tex` threaded through the loop,
-- so the checker proves it is destroyed exactly once on every path out of this image — `reopen`
-- (image change), `runConfigCmd` and `quitTex` (quit). The surface is freed immediately:
-- SDL_CreateTextureFromSurface copies it, so it is dead once the texture exists.
openImage :: Handle Win %1 -> Handle Ren %1 -> Int -> Int -> Int -> Int -> Int -> Int -> IO ()
openImage win ren n idx z px py rot = openTry win ren n idx z px py rot n

-- Load image `idx`, choosing the ANIMATED path (GIF/WEBP) or the static one by extension. The `tries`
-- budget skips indices that fail to load (e.g. a config `!rm %s` just deleted the file), so an
-- all-deleted directory quits rather than spinning.
openTry :: Handle Win %1 -> Handle Ren %1 -> Int -> Int -> Int -> Int -> Int -> Int -> Int -> IO ()
openTry win ren n idx z px py rot tries =
  if isAnim (imagePath idx)
    then animStart win ren n idx (imgLoadAnimation (imagePath idx)) tries
    else staticTry win ren n idx z px py rot tries

-- A GIF/WEBP has these extensions; checked case-insensitively on one lowercased copy.
isAnim :: String -> Bool
isAnim p = isAnimLc (toLower p)
isAnimLc :: String -> Bool
isAnimLc q = hasSuffix ".gif" q || hasSuffix ".webp" q

-- Static image: IMG_Load → one texture, reused across zoom/pan by `frame`. On NULL (bad/deleted file)
-- skip to the next index within the `tries` budget (re-dispatching, so a replacement GIF still animates).
staticTry :: Handle Win %1 -> Handle Ren %1 -> Int -> Int -> Int -> Int -> Int -> Int -> Int -> IO ()
staticTry win ren n idx z px py rot tries = do
  let surf = imgLoad (imagePath idx)
  if handleAddr surf == 0
    then do
      sdlFreeSurface surf                                       -- NULL: a no-op, but it consumes the handle
      if tries > 0 then openTry win ren n ((idx + 1) `mod` n) z px py rot (tries - 1)
        else quitWith win ren
    else do
      let tex = sdlTexFromSurf ren surf
      sdlFreeSurface surf
      let wbuf = newBuffer 4
      let hbuf = newBuffer 4
      sdlQueryTexture tex 0 0 (bufPtrN wbuf 4) (bufPtrN hbuf 4)
      frame win ren n idx tex (peekU32 wbuf 0) (peekU32 hbuf 0) z px py rot ""

-- ─── Animated images (GIF/WEBP) ──────────────────────────────────────────────────────────────────
-- Read the IMG_Animation header (frame count + the frames/delays array pointers) out of its C struct,
-- then play. A NULL load (decode failure / deleted) falls back to the skip-ahead budget; a degenerate
-- single-frame animation is handed to the static path (so zoom/pan/rotate still work on it).
animStart :: Handle Win %1 -> Handle Ren %1 -> Int -> Int -> Handle Anim %1 -> Int -> IO ()
animStart win ren n idx anim tries =
  if handleAddr anim == 0
    then do
      imgFreeAnimation anim                                    -- NULL: a no-op, but it consumes the handle
      if tries > 0 then openTry win ren n ((idx + 1) `mod` n) 0 0 0 0 (tries - 1)
        else quitWith win ren
    else do
      let hdr = newBuffer 32
      memcpyAnim (bufPtrN hdr 32) anim 32                      -- copy the 32-byte struct header to read it
      let nf = peekU32 hdr 8                                   -- IMG_Animation.count
      if nf <= 1
        then do
          imgFreeAnimation anim
          staticTry win ren n idx 0 0 0 0 tries
        else animPlay win ren n idx anim nf (peekU64 hdr 16) (peekU64 hdr 24) 0

-- Show frame `fi`: build its texture from the frame's surface (owned by the animation — never freed
-- here), fit-centre it, present, then wait up to the frame's delay for an event. On timeout advance to
-- the next frame (the animation's clock); on an event hand off to `animAct`. `fp`/`dp` are the C
-- addresses of the frames (SDL_Surface*[]) and delays (int[]) arrays; element `fi` is pulled with memcpy.
animPlay :: Handle Win %1 -> Handle Ren %1 -> Int -> Int -> Handle Anim %1 -> Int -> Int -> Int -> Int -> IO ()
animPlay win ren n idx anim nf fp dp fi = do
  let fb = newBuffer 8
  memcpy (bufPtrN fb 8) (fp + fi * 8) 8                        -- frames[fi] : SDL_Surface*
  let surf = peekU64 fb 0
  let db = newBuffer 4
  memcpy (bufPtrN db 4) (dp + fi * 4) 4                        -- delays[fi] : int (ms)
  let ms = peekU32 db 0
  let tex = sdlTexFromFrame ren surf
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
  let fitPct = if tw > 0 then (if th > 0 then imin ((ow * 100) / tw) ((oh * 100) / th) else 100) else 100
  sdlSetTitle win (titleFor (imagePath idx) idx n 0)
  sdlSetDrawColor ren 0 0 0 255
  sdlRenderClear ren
  renderAt ren tex 0 fitPct tw th ow oh 0 0
  sdlRenderPresent ren
  let ev = newBuffer 128
  let got = sdlWaitEventTimeout (bufPtrN ev 128) (if ms <= 0 then 100 else ms)
  sdlFlushEvent SDL_KEYDOWN
  sdlDestroyTexture tex                                        -- this frame's texture is done
  let ty = peekU32 ev 0
  let key = peekU32 ev 20
  let md = peekU16 ev 24
  if got == 0
    then animPlay win ren n idx anim nf fp dp ((fi + 1) `mod` nf)  -- timeout → next frame
    else animAct win ren n idx anim nf fp dp fi ty key md

-- An event arrived during playback: quit, or a key. A key is looked up in the config keymap first (a
-- `!cmd` runs on the current image, a NAMED action rebinds), else the built-in `keyName`. Only the
-- navigation names (next/prev/first/last/quit) act while animating; zoom/pan/rotate are ignored here
-- (the GIF stays fit) — paging to a still image via `openImage` restores those. No multi-key sequences.
animAct :: Handle Win %1 -> Handle Ren %1 -> Int -> Int -> Handle Anim %1 -> Int -> Int -> Int -> Int -> Int -> Int -> Int -> IO ()
animAct win ren n idx anim nf fp dp fi ty key md =
  if ty == SDL_QUIT then animQuit win ren anim
  else if ty == SDL_KEYDOWN
    then (let cact = lookupAction (readFile (keymapFile 0)) (keyToken key md) in
          if hasPrefix "!" cact then animCmd win ren n idx anim cact
          else animNamed win ren n idx anim nf fp dp fi
                 (if strLen cact > 0 then cact else keyName key md))
  else animPlay win ren n idx anim nf fp dp fi                 -- resize/expose: keep playing same frame

animNamed :: Handle Win %1 -> Handle Ren %1 -> Int -> Int -> Handle Anim %1 -> Int -> Int -> Int -> Int -> String -> IO ()
animNamed win ren n idx anim nf fp dp fi act =
  if      act == "quit"  then animQuit win ren anim
  else if act == "next"  then animReopen win ren anim n ((idx + 1) `mod` n)
  else if act == "prev"  then animReopen win ren anim n ((idx + n - 1) `mod` n)
  else if act == "first" then animReopen win ren anim n 0
  else if act == "last"  then animReopen win ren anim n (n - 1)
  else animPlay win ren n idx anim nf fp dp fi                 -- unmapped / zoom / pan: keep playing

-- Leave a playing animation: free the whole IMG_Animation (struct + every frame surface) FIRST, then
-- the usual exit (quit) or image change (reopen, which re-detects animated vs still at the new index).
animQuit :: Handle Win %1 -> Handle Ren %1 -> Handle Anim %1 -> IO ()
animQuit win ren anim = do
  imgFreeAnimation anim
  quitWith win ren
animReopen :: Handle Win %1 -> Handle Ren %1 -> Handle Anim %1 -> Int -> Int -> IO ()
animReopen win ren anim n idx = do
  imgFreeAnimation anim
  openImage win ren n idx 0 0 0 0
-- Config `!cmd` on the current (animated) image: run it, free the animation, reload this index.
animCmd :: Handle Win %1 -> Handle Ren %1 -> Int -> Int -> Handle Anim %1 -> String -> IO ()
animCmd win ren n idx anim act = do
  runStatus (userCmd (imagePath idx) (substr 1 (strLen act - 1) act))
  imgFreeAnimation anim
  openImage win ren n idx 0 0 0 0

-- Render the CACHED texture at the current zoom/pan, present, then wait for one event and dispatch.
-- A clean do-block: pure values are `let` bindings, SDL side effects are statements. Zoom/pan/redraw
-- loop straight back here (texture reused → one cheap redraw per frame, no disk I/O); only an image
-- change or quit leaves, freeing the texture.
frame :: Handle Win %1 -> Handle Ren %1 -> Int -> Int -> Handle Tex %1 -> Int -> Int -> Int -> Int -> Int -> Int -> String -> IO ()
frame win ren n idx tex tw th z px py rot acc = do
  let owb = newBuffer 4
  let ohb = newBuffer 4
  sdlGetOutputSize ren (bufPtrN owb 4) (bufPtrN ohb 4)
  let ow = peekU32 owb 0
  let oh = peekU32 ohb 0
  -- the % of actual size that FIT currently shows (min of the width/height scale), so the first zoom
  -- step is continuous with the displayed image. ROTATION-aware: at 90/270 the on-screen bounding box
  -- is the swapped dims, so fit against (th,tw) there.
  let ew = if (rot `mod` 180) == 90 then th else tw
  let eh = if (rot `mod` 180) == 90 then tw else th
  let fitPct = if ew > 0 then (if eh > 0 then imin ((ow * 100) / ew) ((oh * 100) / eh) else 100) else 100
  let curPct = if z == 0 then fitPct else z
  sdlSetTitle win (titleFor (imagePath idx) idx n z)
  sdlSetDrawColor ren 0 0 0 255
  sdlRenderClear ren
  renderAt ren tex rot curPct tw th ow oh px py
  sdlRenderPresent ren
  let ev = newBuffer 128
  sdlWaitEvent (bufPtrN ev 128)
  -- this event is already copied into `ev`; drop any further queued key-repeats so a held key
  -- advances at most one step per frame and a release stops immediately (no backlog to drain).
  sdlFlushEvent SDL_KEYDOWN
  let ty = peekU32 ev 0
  let key = peekU32 ev 20
  -- CONFIG keybindings (~/.config/aximv/config.lua → keymap): extend the pending key sequence `acc`
  -- with this printable keydown, then look it up. An exact `!cmd` match runs a shell command on the
  -- current image; a proper-prefix match keeps waiting (redraw with the longer `acc`); anything else
  -- resets the sequence and falls through to the built-in keys below. The keymap is re-read per query
  -- (a builtin, no fork) so each owned copy is consumed exactly once — no shared heap String to alias.
  -- the config TOKEN for this key (char, or `<Right>`/`C-b`/… for special/modified keys), appended to
  -- the pending sequence. A bare modifier (token "") leaves `acc` unchanged — it doesn't abort a chord.
  let md = peekU16 ev 24
  let acc2 = if ty == SDL_KEYDOWN then strAppend acc (keyToken key md) else ""
  let act = lookupAction (readFile (keymapFile 0)) acc2
  if hasPrefix "!" act
    then runConfigCmd win ren n idx tex act                                   -- shell command on %s
    else (if strLen act > 0
          then runNamed win ren n idx tex tw th z px py rot curPct act        -- rebind a built-in
          else (if (strLen acc2 > 0) && isProperPrefix (readFile (keymapFile 0)) acc2
                then frame win ren n idx tex tw th z px py rot acc2           -- partial sequence: wait
                else dispatch win ren n idx tex tw th z px py rot fitPct ty key md)) -- built-in (modifier-aware)

-- Leave the current image: destroy its texture, then load image `idx`. Threads the linear handles on.
reopen :: Handle Win %1 -> Handle Ren %1 -> Handle Tex %1 -> Int -> Int -> IO ()
reopen win ren tex n idx = do
  sdlDestroyTexture tex
  openImage win ren n idx 0 0 0 0

-- Quit path: destroy the current texture, then the renderer + window handles.
quitTex :: Handle Win %1 -> Handle Ren %1 -> Handle Tex %1 -> IO ()
quitTex win ren tex = do
  sdlDestroyTexture tex
  quitWith win ren

-- Run a config `!cmd` action on the current image: `%s` → the shell-quoted path. Then destroy the
-- texture and reload the current image (`openImage` skips to the next if the command deleted it).
userCmd :: String -> String -> String
userCmd path cmd = "f=" ++ shQuote path ++ "; { " ++ substPct cmd "\"$f\"" ++ " ; } >/dev/null 2>&1"
runConfigCmd :: Handle Win %1 -> Handle Ren %1 -> Int -> Int -> Handle Tex %1 -> String -> IO ()
runConfigCmd win ren n idx tex act = do
  runStatus (userCmd (imagePath idx) (substr 1 (strLen act - 1) act))
  sdlDestroyTexture tex
  openImage win ren n idx 0 0 0 0

imin :: Int -> Int -> Int
imin a b = if a < b then a else b

-- ─── Config keybindings (axfm-style) ────────────────────────────────────────────────────────────
-- ~/.config/aximv/config.lua is a Lua table of { key, action } rows. imv has no Lua interpreter, so
-- at startup a `sed` pass parses that table into ~/.cache/aximv/keymap (`key<TAB>action` lines); each
-- pressed key sequence is looked up there BEFORE the built-in keys. An action `!cmd` runs a shell
-- command with `%s` → the current image path. (The quoting/parse helpers are copies of axfm's.)
dup :: String -> String
dup s = substr 0 (strLen s) s
envOr :: String -> String -> String
envOr name dflt = let v = getEnv name in if strLen v > 0 then v else dup dflt
shEsc :: String -> Int -> Int -> String
shEsc s i n =
  if i >= n then ""
  else (if charAt i s == '\'' then "'\\''" ++ shEsc s (i + 1) n
        else substr i 1 s ++ shEsc s (i + 1) n)
shQuote :: String -> String
shQuote s = "'" ++ shEsc s 0 (strLen s) ++ "'"
-- replace every `%s` in a shell command with `rep` (the quoted `"$f"` reference)
isPctS :: String -> Int -> Bool
isPctS cmd i = (i + 1 < strLen cmd) && (charAt i cmd == '%') && (charAt (i + 1) cmd == 's')
substPct :: String -> String -> String
substPct cmd rep = spGo cmd rep 0
spGo :: String -> String -> Int -> String
spGo cmd rep i =
  if i >= strLen cmd then ""
  else if isPctS cmd i then rep ++ spGo cmd rep (i + 2)
  else substr i 1 cmd ++ spGo cmd rep (i + 1)
-- a keymap line is `key<TAB>action`
tabScan :: String -> Int -> Int
tabScan s i = if i >= strLen s then (0 - 1) else if charAt i s == '\t' then i else tabScan s (i + 1)
tabIdx :: String -> Int
tabIdx s = tabScan s 0
kmKey :: String -> String
kmKey line = let i = tabIdx line in if i < 0 then dup line else substr 0 i line
kmVal :: String -> String
kmVal line = let i = tabIdx line in if i < 0 then "" else substr (i + 1) (strLen line - i - 1) line
-- the action bound to key sequence `k`, or "" if unbound
lookupAction :: String -> String -> String
lookupAction km k = laGo (lines km) k
laGo :: List String -> String -> String
laGo xs k = case xs of
  Nil -> ""
  Cons y ys -> if kmKey y == k then kmVal y else laGo ys k
-- is `acc` a PROPER prefix of some binding key (a longer binding starts with it)? → wait for more keys
seqStarts :: String -> String -> Bool
seqStarts b acc = (strLen b > strLen acc) && hasPrefix acc b
isProperPrefix :: String -> String -> Bool
isProperPrefix km acc = ippGo (lines km) acc
ippGo :: List String -> String -> Bool
ippGo xs acc = case xs of
  Nil -> False
  Cons y ys -> if seqStarts (kmKey y) acc then True else ippGo ys acc

-- The config TOKEN for a pressed key: a printable char (`b`), a bracketed name for a special key
-- (`<Right>`/`<Up>`/`<Esc>`/…), each optionally prefixed by held modifiers — `C-` for Ctrl, `M-` for
-- Alt (so `C-b`, `C-<Right>`). "" for an unmappable key (e.g. a bare modifier). Shift is folded into
-- the symbol (config keys use the UNSHIFTED key). `md` is the SDL keysym mod field (offset 24).
ctrlHeld :: Int -> Bool
ctrlHeld md = ((md `div` 64) `mod` 4) > 0       -- KMOD_LCTRL 64 | KMOD_RCTRL 128
altHeld :: Int -> Bool
altHeld md = ((md `div` 256) `mod` 4) > 0       -- KMOD_LALT 256 | KMOD_RALT 512
shiftHeld :: Int -> Bool
shiftHeld md = (md `mod` 4) > 0                 -- KMOD_LSHIFT 1 | KMOD_RSHIFT 2
keyBase :: Int -> String
keyBase key =
  if      key == KeyRight then "<Right>"
  else if key == KeyLeft  then "<Left>"
  else if key == KeyUp    then "<Up>"
  else if key == KeyDown  then "<Down>"
  else if key == KeyHome  then "<Home>"
  else if key == KeyEnd   then "<End>"
  else if key == KeyEsc   then "<Esc>"
  else if key == KeySpace then "<Space>"
  else if (key > 32) && (key < 127) then chr key    -- printable ASCII (the UNSHIFTED symbol)
  else ""
-- The US-layout SHIFTED glyph of a printable base keycode, so a config key is written as it reads on
-- the cap (`<`, `?`, `A`, `+`). Letters a–z → A–Z; the number row and punctuation per US layout. (On a
-- non-US layout the shifted punctuation differs — use the unshifted key, or `C-`/`M-` combos.)
shiftGlyph :: Int -> String
shiftGlyph key =
  if (key >= 97) && (key <= 122) then chr (key - 32)   -- a–z → A–Z
  else if key == 44 then "<" else if key == 46 then ">" else if key == 47 then "?"
  else if key == 45 then "_" else if key == 61 then "+" else if key == 59 then ":"
  else if key == 39 then "\"" else if key == 91 then "{" else if key == 93 then "}"
  else if key == 92 then "|" else if key == 96 then "~"
  else if key == 49 then "!" else if key == 50 then "@" else if key == 51 then "#"
  else if key == 52 then "$" else if key == 53 then "%" else if key == 54 then "^"
  else if key == 55 then "&" else if key == 56 then "*" else if key == 57 then "("
  else if key == 48 then ")" else chr key              -- otherwise the base char
keyToken :: Int -> Int -> String
keyToken key md =
  let base = keyBase key in
  if strLen base == 0 then ""
  -- a single printable char gets its shifted glyph when Shift is held; a special key (e.g. `<Right>`,
  -- length > 1) ignores Shift. Ctrl/Alt are prefixes; Shift is folded into the glyph, not a prefix.
  else let glyph = if (strLen base == 1) && shiftHeld md then shiftGlyph key else base in
       (if ctrlHeld md then "C-" else "") ++ (if altHeld md then "M-" else "") ++ glyph

configFile :: Int -> String
configFile d = envOr "HOME" "." ++ "/.config/aximv/config.lua"
keymapFile :: Int -> String
keymapFile d = envOr "HOME" "." ++ "/.cache/aximv/keymap"
-- Parse config.lua → keymap once at startup (one fork): each `{ key = "K", action = "A" }` row → a
-- `K<TAB>A` line. Comment lines dropped; an empty keymap when there is no config.
buildKeymap :: Int -> Int
buildKeymap d = runStatus
  ("cfg=" ++ shQuote (configFile 0) ++ "; km=" ++ shQuote (keymapFile 0)
   ++ "; mkdir -p \"${km%/*}\"; : > \"$km\"; [ -r \"$cfg\" ] || exit 0; "
   ++ "sed '/^[[:space:]]*--/d' \"$cfg\" | while IFS= read -r line; do case \"$line\" in "
   ++ "*key*action*) k=$(printf '%s\\n' \"$line\" | sed -n 's/.*key[[:space:]]*=[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p'); "
   ++ "[ -n \"$k\" ] || continue; "
   ++ "a=$(printf '%s\\n' \"$line\" | sed -n 's/.*action[[:space:]]*=[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p'); "
   ++ "[ -n \"$a\" ] || continue; printf '%s\\t%s\\n' \"$k\" \"$a\" >> \"$km\" ;; esac; done; true")

-- SDL event types + keycodes as named constants (§18 `foreign enum`): the dispatch below reads as a
-- `case` over `SDL_QUIT`/`KeyQ`/… instead of raw `256`/`113`. (SDL's keycodes are the actual C
-- SDLK_* values.) Each handle must still be consumed once per branch — every arm loops or quits.
foreign enum SdlEvent { SDL_QUIT = 256, SDL_KEYDOWN = 768 }
foreign enum Keycode { KeyEsc = 27, KeySpace = 32, KeyPlus = 43, KeyMinus = 45, KeyEq = 61, Key0 = 48, KeyG = 103, KeyH = 104, KeyJ = 106, KeyK = 107, KeyL = 108, KeyN = 110, KeyP = 112, KeyQ = 113, KeyR = 114, KeyHome = 1073741898, KeyEnd = 1073741901, KeyRight = 1073741903, KeyLeft = 1073741904, KeyUp = 1073741906, KeyDown = 1073741905 }

-- ty = SDL event type; key = SDL keycode (valid only for KEYDOWN). `curPct` = the currently-displayed
-- scale (fitPct in fit mode, else z), so +/- step from what's on screen. Changing image resets
-- zoom/pan; h/j/k/l pan. Every branch consumes the two linear handles exactly once (loop or quit).
dispatch :: Handle Win %1 -> Handle Ren %1 -> Int -> Int -> Handle Tex %1 -> Int -> Int -> Int -> Int -> Int -> Int -> Int -> Int -> Int -> Int -> IO ()
dispatch win ren n idx tex tw th z px py rot fitPct ty key md =
  let curPct = if z == 0 then fitPct else z in
  case ty of
    SDL_QUIT    -> quitTex win ren tex
    SDL_KEYDOWN -> onKey win ren n idx tex tw th z px py rot curPct key md
    _           -> frame win ren n idx tex tw th z px py rot ""               -- resize/expose: redraw

-- The built-in ACTION NAME of a keycode — the same names a config `{ key, action }` row may use, so
-- a built-in key and a config rebinding run through one dispatcher (`runNamed`). An unmapped key is
-- "redraw" (a harmless no-op refresh).
keyName :: Int -> Int -> String
keyName key md = case key of
  KeyQ     -> "quit"
  KeyEsc   -> "quit"
  KeyN     -> "next"
  KeySpace -> "next"
  KeyRight -> "next"
  KeyP     -> "prev"
  KeyLeft  -> "prev"
  KeyG     -> "first"
  KeyHome  -> "first"
  KeyEnd   -> "last"
  KeyPlus  -> "zoom_in"
  KeyEq    -> "zoom_in"
  KeyMinus -> "zoom_out"
  KeyR     -> if shiftHeld md then "rotate_ccw" else "rotate"   -- r = clockwise, Shift-R = anti-clockwise
  Key0     -> "fit"
  KeyH     -> "pan_left"
  KeyL     -> "pan_right"
  KeyK     -> "pan_up"
  KeyJ     -> "pan_down"
  _        -> "redraw"

-- Run a built-in action by NAME. Every arm threads the two linear handles on (`frame`/`reopen`) or
-- consumes them (`quitTex`) exactly once, so must-use linearity holds. `curPct` = the on-screen scale
-- (so +/- step from what's shown); pan from FIT (z == 0) lifts into pixel mode at that scale so px/py
-- take effect without zooming first. Used by BOTH a built-in key (via `keyName`) and a config binding.
runNamed :: Handle Win %1 -> Handle Ren %1 -> Int -> Int -> Handle Tex %1 -> Int -> Int -> Int -> Int -> Int -> Int -> Int -> String -> IO ()
runNamed win ren n idx tex tw th z px py rot curPct act =
  let panZ = if z == 0 then curPct else z in
  if      act == "quit"      then quitTex win ren tex
  else if act == "next"      then reopen win ren tex n ((idx + 1) `mod` n)    -- image change → rot resets
  else if act == "prev"      then reopen win ren tex n ((idx + n - 1) `mod` n)
  else if act == "first"     then reopen win ren tex n 0
  else if act == "last"      then reopen win ren tex n (n - 1)
  else if act == "zoom_in"   then frame win ren n idx tex tw th (curPct + 5) px py rot ""
  else if act == "zoom_out"  then frame win ren n idx tex tw th (if curPct - 5 < 5 then 5 else curPct - 5) px py rot ""
  else if act == "fit"       then frame win ren n idx tex tw th 0 0 0 rot ""  -- re-fit, keep orientation
  else if act == "rotate"     then frame win ren n idx tex tw th z px py ((rot + 90) `mod` 360) ""
  else if act == "rotate_ccw" then frame win ren n idx tex tw th z px py ((rot + 270) `mod` 360) ""
  else if act == "pan_left"  then frame win ren n idx tex tw th panZ (px - 10) py rot ""
  else if act == "pan_right" then frame win ren n idx tex tw th panZ (px + 10) py rot ""
  else if act == "pan_up"    then frame win ren n idx tex tw th panZ px (py - 10) rot ""
  else if act == "pan_down"  then frame win ren n idx tex tw th panZ px (py + 10) rot ""
  else frame win ren n idx tex tw th z px py rot ""                          -- unknown name: redraw

onKey :: Handle Win %1 -> Handle Ren %1 -> Int -> Int -> Handle Tex %1 -> Int -> Int -> Int -> Int -> Int -> Int -> Int -> Int -> Int -> IO ()
onKey win ren n idx tex tw th z px py rot curPct key md =
  runNamed win ren n idx tex tw th z px py rot curPct (keyName key md)

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

-- A SEED (the first CLI arg, or "." when none) selects the folder: `aximv photo.jpg` opens that file
-- but pages through every image beside it; bare `aximv` views the current directory from its first
-- image. `buildImgList` writes the sorted folder list, then we open it at the seed's position.
main :: IO ()
main =
  let ac = argCount 0 in
  do
    buildImgList (if ac == 0 then "." else getArg 0)                  -- ~/.cache/aximv/filelist
    let n = imageCount 0
    if n == 0
      then ePutStrLn "aximv: no images in this folder"
      else do
        buildKeymap 0                                                 -- parse ~/.config/aximv/config.lua
        sdlInit 32                                                    -- SDL_INIT_VIDEO
        let win = sdlCreateWindow "aximv" 805240832 805240832 1000 700 36 -- CENTERED, SHOWN|RESIZABLE
        let ren = sdlCreateRenderer win (0 - 1) 0                     -- borrows win
        openImage win ren n (if ac == 0 then 0 else startIndex (getArg 0)) 0 0 0 0
