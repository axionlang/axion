-- axmpv — an mpv-like video player in Axión (flagship). The pure player logic (state, actions, key
-- tokens, subtitles, layout) lives in Core.axi, shared with CoreTest.axi; this file is the effectful
-- shell: SDL2 for the window/renderer/input, libc `popen`/`read` for the media pipes.
--
--   scripts/axmpv-run.sh video.mkv other.mp4
--   axmpv [--config FILE] [--sub FILE.srt] [--script FILE] FILE…
--
-- KEYS (mpv's defaults; a config.lua binding replaces any of them):
--   space/p  pause             ←/→  seek 5 s          ↑/↓  seek 60 s
--   9/0      volume -/+        m    mute              [ ]  speed ×0.9 / ×1.1   backspace  1×
--   f        fullscreen        o    OSD always on     i    info
--   s        screenshot        l    A-B loop (A, B, clear)               L  loop the whole file
--   alt+arrows  pan            alt++ / alt+-  zoom    alt+backspace  fit (reset zoom + pan)
--               (steps: options `zoom_step`, default ×1.10 per press, and `pan_step`, 5% of the window)
--   r / R       rotate 90° clockwise / anti-clockwise
--   v        subtitles on/off  z/x  subtitle delay -/+100 ms
--   < >      playlist prev/next (enter = next)        q/esc  quit
--
-- DECODING is done by ffmpeg, spawned through `popen`: it streams raw BGRA frames on a pipe
-- (`Core.videoCmd`); axmpv reads exactly one frame per `read` loop into a frame-sized `Buffer`,
-- uploads it to a streaming texture and draws it letterboxed. Axión does the timing: the clock
-- advances with the wall time × speed; a frame is shown once the clock reaches its time, a frame
-- that is already late when read is dropped, and between frames the loop waits for input with
-- `SDL_WaitEventTimeout` until the next one is due. A seek or playlist change closes the pipe and
-- spawns a new one (`-ss`).
--
-- The window, renderer, texture and pipe are LINEAR handles (§18): every path through the loop
-- destroys or hands on each exactly once — a leaked texture or an unclosed pipe is a compile error.
--
-- AUDIO is a second ffmpeg pipe (`Core.audioCmd`: s16le stereo 48 kHz, `atempo` for the speed) feeding
-- an SDL audio device in queue mode: each loop iteration tops the queue up to ~250 ms, scaling every
-- sample by the volume in Axión (`Core.scaleSample`). Pause pauses the device; a seek or a speed change
-- clears the queue and respawns the pipe. The clock stays the wall clock (× speed) — the queue is
-- short, so audio and video stay within it of each other.
--
-- SUBTITLES: the `.srt` beside the file (same name) or `--sub FILE`, parsed in Axión (`Core.parseSrt`)
-- into an `Array Cue` searched by time on every redraw; drawn centred above the progress bar in the
-- same font (Latin letters folded to ASCII). `v` toggles them, `z`/`x` shift them by 100 ms.
--
-- The ON-SCREEN DISPLAY is drawn by Axión too: a status line (play state, time, volume, speed) and a
-- progress bar for 2 s after any action (always, after `o`), plus file/stream info after `i`. The
-- text uses axmpv's own 5×7 font (`Core.osdFont`), rasterized into rectangles (`Core.osdLayout`) and
-- drawn with one SDL_RenderFillRects per layer.
--
-- SCREENSHOTS (`s`): the current frame as a binary PPM, `axmpv-shot-NNNN.ppm` in the working
-- directory — BGRA → RGB converted in Axión. The A-B LOOP (`l` sets A, then B, then clears) jumps back
-- to A whenever playback reaches B.
--
-- `--script FILE` (headless tests): lines `<ms> <action>`; each action runs once `ms` of wall time
-- have passed. `key:KEYS` presses keys instead (`1200 key:gg`), resolved through the config keymap
-- like real key presses. On exit axmpv prints a status line (`Core.statusLine`).
--
-- CONFIG: ~/.config/axmpv/config.lua (or `--config FILE`; see examples/axmpv/config.lua) — key
-- bindings, `!command` actions and options, turned into a keymap file once at start-up.
import Core

data Win = Win
data Ren = Ren
data Tex = Tex
data Pipe = Pipe
data Aud = Aud

foreign "libSDL2.so" sdlInit = "SDL_Init" :: Int -> Int
foreign "libSDL2.so" sdlQuit = "SDL_Quit" :: Int -> Int
foreign "libSDL2.so" sdlCreateWindow = "SDL_CreateWindow" :: String -> Int -> Int -> Int -> Int -> Int -> Handle Win
foreign "libSDL2.so" sdlCreateRenderer = "SDL_CreateRenderer" :: Borrow (Handle Win) -> Int -> Int -> Handle Ren
foreign "libSDL2.so" sdlDestroyWindow = "SDL_DestroyWindow" :: Own (Handle Win) -> Int
foreign "libSDL2.so" sdlDestroyRenderer = "SDL_DestroyRenderer" :: Own (Handle Ren) -> Int
foreign "libSDL2.so" sdlCreateTexture = "SDL_CreateTexture" :: Borrow (Handle Ren) -> Int -> Int -> Int -> Int -> Handle Tex
foreign "libSDL2.so" sdlDestroyTexture = "SDL_DestroyTexture" :: Own (Handle Tex) -> Int
foreign "libSDL2.so" sdlUpdateTexture = "SDL_UpdateTexture" :: Borrow (Handle Tex) -> Int -> Int -> Int -> Int
-- (rect, angle in degrees about the rect's centre: the zoom/pan/rotate view, `Core.viewRect`)
foreign "libSDL2.so" sdlRenderCopyEx = "SDL_RenderCopyEx" :: Borrow (Handle Ren) -> Borrow (Handle Tex) -> Int -> Int -> Float -> Int -> Int -> Int
foreign "libSDL2.so" sdlSetDrawColor = "SDL_SetRenderDrawColor" :: Borrow (Handle Ren) -> Int -> Int -> Int -> Int -> Int
foreign "libSDL2.so" sdlRenderClear = "SDL_RenderClear" :: Borrow (Handle Ren) -> Int
foreign "libSDL2.so" sdlFillRects = "SDL_RenderFillRects" :: Borrow (Handle Ren) -> Int -> Int -> Int
foreign "libSDL2.so" sdlSetBlendMode = "SDL_SetRenderDrawBlendMode" :: Borrow (Handle Ren) -> Int -> Int
foreign "libSDL2.so" sdlRenderPresent = "SDL_RenderPresent" :: Borrow (Handle Ren) -> Int
foreign "libSDL2.so" sdlGetOutputSize = "SDL_GetRendererOutputSize" :: Borrow (Handle Ren) -> Int -> Int -> Int
foreign "libSDL2.so" sdlSetTitle = "SDL_SetWindowTitle" :: Borrow (Handle Win) -> String -> Int
foreign "libSDL2.so" sdlSetFullscreen = "SDL_SetWindowFullscreen" :: Borrow (Handle Win) -> Int -> Int
foreign "libSDL2.so" sdlWaitEventTimeout = "SDL_WaitEventTimeout" :: Int -> Int -> Int
-- SDL_GetTicks takes no argument; the extra one is ignored by the C calling convention
foreign "libSDL2.so" sdlGetTicks = "SDL_GetTicks" :: Int -> Int
-- the audio device, in queue mode (no callback): an SDL device id, opened once, closed once
foreign "libSDL2.so" sdlOpenAudio = "SDL_OpenAudioDevice" :: Int -> Int -> Int -> Int -> Int -> Handle Aud
foreign "libSDL2.so" sdlCloseAudio = "SDL_CloseAudioDevice" :: Own (Handle Aud) -> Int
foreign "libSDL2.so" sdlPauseAudio = "SDL_PauseAudioDevice" :: Borrow (Handle Aud) -> Int -> Int
foreign "libSDL2.so" sdlQueueAudio = "SDL_QueueAudio" :: Borrow (Handle Aud) -> Int -> Int -> Int
foreign "libSDL2.so" sdlQueuedSize = "SDL_GetQueuedAudioSize" :: Borrow (Handle Aud) -> Int
foreign "libSDL2.so" sdlClearQueued = "SDL_ClearQueuedAudio" :: Borrow (Handle Aud) -> Int
foreign "libc.so.6" popen = "popen" :: String -> String -> Handle Pipe
foreign "libc.so.6" pclose = "pclose" :: Own (Handle Pipe) -> Int
foreign "libc.so.6" fileno = "fileno" :: Borrow (Handle Pipe) -> Int
foreign "libc.so.6" readFd = "read" :: Int -> Int -> Int -> Int
-- screenshots: plain file descriptors (`creat` → -1 on failure, nothing to free on that path)
foreign "libc.so.6" creatFile = "creat" :: String -> Int -> Int
foreign "libc.so.6" writeFd = "write" :: Int -> Int -> Int -> Int
foreign "libc.so.6" writeStr = "write" :: Int -> String -> Int -> Int
foreign "libc.so.6" closeFd = "close" :: Int -> Int

foreign struct SDL_Rect { x :: I32, y :: I32, w :: I32, h :: I32 }
foreign enum SdlEvent { SDL_QUIT = 256, SDL_KEYDOWN = 768 }

-- SDL_PIXELFORMAT_ARGB8888 (= BGRA bytes in memory, ffmpeg's `bgra`), SDL_TEXTUREACCESS_STREAMING
pixelFormat :: Int
pixelFormat = 372645892

-- ─── per-file playback state ─────────────────────────────────────────────────────────────────────
-- Plain Ints, so the record update every frame stays cheap. `vk` = frames read from the current
-- pipe; `vbase` = the position (ms) the pipe started at, so frame k is due at vbase + frameMs k;
-- `vlast` = the tick the clock last advanced at; `vt0` = the tick playback began (script time);
-- `vafd` = the audio pipe's descriptor, `vaeof` = 1 once it has ended (or the file has no audio);
-- `vosd` = the tick until which the OSD shows after an action (0: hidden), `vdirty` = 1 when the
-- picture must be redrawn although no frame is due (an action or the OSD timing out while paused);
-- `vshots` = screenshots saved so far.
data Vid = Vid
  { vk :: Int, vbase :: Int, vlast :: Int, vt0 :: Int, vshown :: Int, vdropped :: Int
  , vfd :: Int, vw :: Int, vh :: Int, vafd :: Int, vaeof :: Int, vosd :: Int, vdirty :: Int
  , vshots :: Int }

frameBytes :: Vid -> Int
frameBytes v = vw v * vh v * 4

-- Read exactly `n` bytes from `fd` into memory at `p` (a pipe returns them in pieces); the count
-- actually read — less than `n` only at end of stream.
readFull :: Int -> Int -> Int -> Int -> Int
readFull fd p off n =
  if off >= n then off
  else let k = readFd fd (p + off) (n - off) in
       if k <= 0 then off else readFull fd p (off + k) n

-- ─── audio ───────────────────────────────────────────────────────────────────────────────────────
-- Open the default output device for `Core.audioCmd`'s format: an SDL_AudioSpec laid out by hand
-- (freq @0, format @4 = AUDIO_S16LSB, channels @6, samples @8, no callback → queue mode). Its
-- address goes to C through a `borrow` scope, which keeps the buffer alive across the call — a
-- bare `bufPtrN spec 32` would be the buffer's last use, so it was freed before SDL read it.
openAudio :: Int -> Handle Aud
openAudio d =
  let spec = newBuffer 32 in
  let z = pokeU64 spec 0 0 + pokeU64 spec 8 0 + pokeU64 spec 16 0 + pokeU64 spec 24 0 in
  let set = z + pokeU32 spec 0 48000 + pokeU16 spec 4 32784 + pokeU8 spec 6 2 + pokeU16 spec 8 1024 in
  borrow spec as sp in sdlOpenAudio 0 0 (sp + set * 0) 0 0

-- Scale the `n` 16-bit samples in `b` to `pct`% (in place).
scaleChunk :: Buffer Int -> Int -> Int -> Int -> Int
scaleChunk b i n pct =
  if i >= n then 0
  else pokeU16 b (i * 2) (scaleSample (peekU16 b (i * 2)) pct) + scaleChunk b (i + 1) n pct

-- Keep ~250 ms of PCM queued: up to `budget` 4 KiB chunks from the audio pipe, scaled by the
-- volume. 1 once the stream has ended.
feedAudio :: Handle Aud -> Int -> Int -> Int -> Int
feedAudio aud afd pct budget =
  if budget <= 0 || sdlQueuedSize aud >= 250 * pcmBytesPerMs then 0
  else let b = newBuffer 4096 in
       let got = readFull afd (bufPtrN b 4096) 0 4096 in
       if got < 4 then 1
       else let q = (if pct == 100 then 0 else scaleChunk b 0 (got / 2) pct)
                    + (borrow b as bp in sdlQueueAudio aud bp (got - mod got 4)) in
            feedAudio aud afd pct (budget - 1) + q * 0

-- ─── arguments ───────────────────────────────────────────────────────────────────────────────────
argCount :: Int -> Int
argCount i = if strLen (getArg i) == 0 then i else argCount (i + 1)

-- the playlist: every argument that is not an option (or an option's value)
fileArgs :: Int -> Int -> List String
fileArgs i n =
  if i >= n then Nil
  else let a = getArg i in
       if a == "--script" || a == "--config" || a == "--sub" then fileArgs (i + 2) n
       else Cons a (fileArgs (i + 1) n)

-- the value after option `opt`, or ""
optArg :: String -> Int -> Int -> String
optArg opt i n =
  if i + 1 >= n then ""
  else if getArg i == opt then getArg (i + 1) else optArg opt (i + 1) n

fileArray :: List String -> Array String
fileArray fs = faFill (newArray (length fs) "") 0 fs

faFill :: Array String %1 -> Int -> List String -> Array String
faFill a i fs = case fs of
  Nil -> a
  Cons f rest -> faFill (setArray a i f) (i + 1) rest

-- ─── main ────────────────────────────────────────────────────────────────────────────────────────
main :: IO ()
main = do
  let n = argCount 0
  let fs = fileArray (fileArgs 0 n)
  let sf = optArg "--script" 0 n
  let cf = optArg "--config" 0 n
  let steps = if strLen sf > 0 then parseScript (readFile sf) else Nil
  if lenArray fs == 0
    then ePutStrLn "usage: axmpv [--config FILE] [--sub FILE.srt] [--script FILE] FILE…"
    else do
      runStatus (keymapCmd (if strLen cf > 0 then cf else configFile 0) (keymapFile 0))
      let p = configured (readFile (keymapFile 0)) (newPlayer (lenArray fs))
      sdlInit 48                                                    -- SDL_INIT_VIDEO | SDL_INIT_AUDIO
      let win = sdlCreateWindow "axmpv" 805240832 805240832 960 540 36 -- CENTERED, SHOWN|RESIZABLE
      sdlSetFullscreen win (if fullscreen p then 4097 else 0)
      let ren = sdlCreateRenderer win (0 - 1) 0
      let aud = openAudio 0
      sdlPauseAudio aud 0
      openFile win ren aud fs p steps (sdlGetTicks 0) 0 0 0

-- Open playlist entry `idx p`: probe it, create its texture and frame buffer, spawn the video and
-- audio pipes. A file ffprobe cannot read (no video stream) is skipped.
openFile :: Handle Win %1 -> Handle Ren %1 -> Handle Aud %1 -> Array String -> Player -> List Step -> Int -> Int -> Int -> Int -> IO ()
openFile win ren aud fs p steps t0 shown dropped shots = do
  let f = getArray fs (idx p)
  let pr = parseProbe (runCapture (probeCmd f))
  if pw pr <= 0 || ph pr <= 0
    then do
      ePutStrLn ("axmpv: cannot play " ++ f)
      nextOrQuit win ren aud fs p steps t0 shown dropped shots
    else do
      sdlSetTitle win (baseName f ++ (if lenArray fs > 1 then "  (" ++ showInt (idx p + 1) ++ "/" ++ showInt (lenArray fs) ++ ")" else "") ++ " — axmpv")
      let tex = sdlCreateTexture ren pixelFormat 1 (pw pr) (ph pr)
      let pipe = popen (videoCmd f 0) "r"
      let apipe = popen (audioCmd f 0 (speed p)) "r"
      let sub = optArg "--sub" 0 (argCount 0)
      let subs = cueArray (parseSrt (readFile (if strLen sub > 0 then sub else srtPathFor f)))
      let now = sdlGetTicks 0
      let v = Vid { vk = 0, vbase = 0, vlast = now, vt0 = t0, vshown = shown, vdropped = dropped
                  , vfd = fileno pipe, vw = pw pr, vh = ph pr, vafd = fileno apipe, vaeof = 0
                  , vosd = 0, vdirty = 0, vshots = shots }
      loop win ren aud tex pipe apipe (newBuffer (frameBytes v)) fs subs pr (p { pos = 0, dur = durMs pr }) v steps

-- The next playlist entry, or quit after the last one (mpv's default).
nextOrQuit :: Handle Win %1 -> Handle Ren %1 -> Handle Aud %1 -> Array String -> Player -> List Step -> Int -> Int -> Int -> Int -> IO ()
nextOrQuit win ren aud fs p steps t0 shown dropped shots =
  if idx p + 1 < lenArray fs
    then openFile win ren aud fs (p { idx = idx p + 1 }) steps t0 shown dropped shots
    else finish win ren aud p shown dropped shots

finish :: Handle Win %1 -> Handle Ren %1 -> Handle Aud %1 -> Player -> Int -> Int -> Int -> IO ()
finish win ren aud p shown dropped shots = do
  sdlCloseAudio aud
  sdlDestroyRenderer ren
  sdlDestroyWindow win
  sdlQuit 0
  putStrLn (statusLine p shown dropped shots)

-- Close the current file: its texture and both pipes; drop the audio still queued.
closeFile :: Handle Aud -> Handle Tex %1 -> Handle Pipe %1 -> Handle Pipe %1 -> Int
closeFile aud tex pipe apipe = sdlDestroyTexture tex + pclose pipe + pclose apipe + sdlClearQueued aud

-- Restart the audio pipe at `ms` (a seek, or a new speed): the queued audio belongs to the old one.
respawnAudio :: Handle Aud -> Handle Pipe %1 -> String -> Int -> Int -> Handle Pipe
respawnAudio aud apipe f ms spd =
  let c = pclose apipe + sdlClearQueued aud in
  popen (audioCmd f (ms + c * 0) spd) "r"

-- ─── the playback loop ───────────────────────────────────────────────────────────────────────────
-- One iteration: advance the clock, top up the audio queue, run any script step that is due, then
-- either take the next frame from the pipe (it is due) or wait for input until it is.
loop :: Handle Win %1 -> Handle Ren %1 -> Handle Aud %1 -> Handle Tex %1 -> Handle Pipe %1 -> Handle Pipe %1 -> Buffer Int -> Array String -> Array Cue -> Probe -> Player -> Vid -> List Step -> IO ()
loop win ren aud tex pipe apipe buf fs subs pr p v steps = do
  let now = sdlGetTicks 0
  let p1 = if paused p then p else p { pos = pos p + (now - vlast v) * speed p / 100 }
  let ended = if paused p1 || vaeof v == 1 then vaeof v else feedAudio aud (vafd v) (effVolume p1) 8
  let v1 = v { vlast = now, vaeof = ended }
  let p2 = if loopB p1 >= 0 && not (paused p1) then loopCheck p1 else p1
  if effect p2 == effSeek
    then act win ren aud tex pipe apipe buf fs subs pr p2 v1 steps     -- reached B: back to A
    else step win ren aud tex pipe apipe buf fs subs pr p1 v1 steps now

-- Run the next script step if it is due, then go on to the frame/wait decision.
step :: Handle Win %1 -> Handle Ren %1 -> Handle Aud %1 -> Handle Tex %1 -> Handle Pipe %1 -> Handle Pipe %1 -> Buffer Int -> Array String -> Array Cue -> Probe -> Player -> Vid -> List Step -> Int -> IO ()
step win ren aud tex pipe apipe buf fs subs pr p1 v1 steps now =
  case steps of
    Cons s rest ->
      if now - vt0 v1 >= stepAt s
        then (if hasPrefix "key:" (stepAction s)
                then onKey win ren aud tex pipe apipe buf fs subs pr p1 v1 rest (substr 4 (strLen (stepAction s) - 4) (stepAction s))
                else act win ren aud tex pipe apipe buf fs subs pr (runAction (stepAction s) p1) v1 rest)
        else tick win ren aud tex pipe apipe buf fs subs pr p1 v1 steps
    Nil -> tick win ren aud tex pipe apipe buf fs subs pr p1 v1 steps

-- Take the next frame if it is due (paused: only the first frame after opening or seeking), else
-- wait for input until it is.
tick :: Handle Win %1 -> Handle Ren %1 -> Handle Aud %1 -> Handle Tex %1 -> Handle Pipe %1 -> Handle Pipe %1 -> Buffer Int -> Array String -> Array Cue -> Probe -> Player -> Vid -> List Step -> IO ()
tick win ren aud tex pipe apipe buf fs subs pr p v steps =
  let due = vbase v + frameMs pr (vk v) in
  let expired = vosd v > 0 && vlast v >= vosd v in
  if paused p && vk v > 0 && (vdirty v == 1 || expired)
    then do
      present ren tex fs subs pr p v
      waitInput win ren aud tex pipe apipe buf fs subs pr p (v { vdirty = 0, vosd = (if expired then 0 else vosd v) }) steps 50
  else if (paused p && vk v > 0) || (not (paused p) && pos p < due)
    then waitInput win ren aud tex pipe apipe buf fs subs pr p v steps (if paused p then 50 else imin 50 (imax 1 ((due - pos p) * 100 / speed p)))
    else frameStep win ren aud tex pipe apipe buf fs subs pr p v steps

-- Read frame `vk`; show it, or drop it when the clock has already passed the next frame's time.
-- End of stream → the next file. The wait for a new pipe's FIRST frame (ffmpeg starting up, or
-- seeking) is not playback time: the clock restarts once it arrives, so it is never late.
frameStep :: Handle Win %1 -> Handle Ren %1 -> Handle Aud %1 -> Handle Tex %1 -> Handle Pipe %1 -> Handle Pipe %1 -> Buffer Int -> Array String -> Array Cue -> Probe -> Player -> Vid -> List Step -> IO ()
frameStep win ren aud tex pipe apipe buf fs subs pr p0 v0 steps = do
  let n = frameBytes v0
  let got = readFull (vfd v0) (bufPtrN buf n) 0 n
  let first = vk v0 == 0
  let p = if first then p0 { pos = vbase v0 } else p0
  let v = if first then v0 { vlast = sdlGetTicks 0 } else v0
  -- end of the file with `L` (loop-file) on: back to the start through the seek path (both pipes
  -- respawned at 0); a pipe that ended without a single frame does not loop (no endless spin)
  if got < n && loopFile p && vk v > 0
    then act win ren aud tex pipe apipe buf fs subs pr (p { effect = effSeek, seekTo = 0 }) v steps
    else if got < n
    then do
      closeFile aud tex pipe apipe
      nextOrQuit win ren aud fs (settled p) steps (vt0 v) (vshown v) (vdropped v) (vshots v)
    else if not (paused p) && pos p >= vbase v + frameMs pr (vk v + 1)
      then loop win ren aud tex pipe apipe buf fs subs pr p (v { vk = vk v + 1, vdropped = vdropped v + 1 }) steps
      else do
        sdlUpdateTexture tex 0 (bufPtrN buf n) (vw v * 4)
        present ren tex fs subs pr p v
        loop win ren aud tex pipe apipe buf fs subs pr p (v { vk = vk v + 1, vshown = vshown v + 1 }) steps

-- Draw the texture letterboxed into the current output size, the OSD over it when it shows.
present :: Handle Ren -> Handle Tex -> Array String -> Array Cue -> Probe -> Player -> Vid -> Int
present ren tex fs subs pr p v =
  let ob = newBuffer 8 in
  let got = sdlGetOutputSize ren (bufPtrN ob 8) (bufPtrN ob 8 + 4) in
  let ow = peekU32 ob 0 in
  let oh = peekU32 ob 4 in
  let r = viewRect p (vw v) (vh v) ow oh in
  let dst = SDL_Rect { x = rx r, y = ry r, w = rw r, h = rh r } in
  let base = sdlSetDrawColor ren 0 0 0 255 + got + sdlRenderClear ren
               + (borrow dst as d in sdlRenderCopyEx ren tex 0 d (toFloat (rot p)) 0 0) in
  let text = subtitleNow subs p in
  let sub = if strLen text > 0 then drawOsd ren (subLayout text ow oh) else 0 in
  let osd = if osdOn p || vlast v < vosd v || infoOn p
              then drawOsd ren (osdLayout p (infoText fs pr p v) ow oh) else 0 in
  base + sub + osd + sdlRenderPresent ren

-- The `i` block: file name, stream, frame counts.
infoText :: Array String -> Probe -> Player -> Vid -> String
infoText fs pr p v =
  let fps = fpsN pr * 100 / fpsD pr in
  baseName (getArray fs (idx p)) ++ "  (" ++ showInt (idx p + 1) ++ "/" ++ showInt (nfiles p) ++ ")\n"
  ++ showInt (vw v) ++ "x" ++ showInt (vh v) ++ "  " ++ showInt (fps / 100) ++ "." ++ pad2 (mod fps 100)
  ++ " fps  " ++ (if vaeof v == 1 then "no audio" else "audio") ++ "\n"
  ++ "frames " ++ showInt (vshown v) ++ "  dropped " ++ showInt (vdropped v)

-- The OSD layers: a translucent backdrop, the progress bar's fill, the text.
drawOsd :: Handle Ren -> Osd -> Int
drawOsd ren o =
  sdlSetBlendMode ren 1                                            -- SDL_BLENDMODE_BLEND
    + sdlSetDrawColor ren 0 0 0 150 + fillRects ren (osdBack o)
    + sdlSetDrawColor ren 230 230 230 230 + fillRects ren (osdFill o)
    + sdlSetDrawColor ren 255 255 255 255 + fillRects ren (osdText o)
    + sdlSetBlendMode ren 0

-- Draw rectangles in one call: an array of SDL_Rect (4 × int32) in a Buffer.
fillRects :: Handle Ren -> List Rect -> Int
fillRects ren rs =
  let n = length rs in
  if n == 0 then 0
  else let b = newBuffer (n * 16) in
       let z = putRects b rs 0 in
       borrow b as bp in sdlFillRects ren (bp + z * 0) n

putRects :: Buffer Int -> List Rect -> Int -> Int
putRects b rs i = case rs of
  Nil -> 0
  Cons r rest ->
    pokeU32 b i (rx r) + pokeU32 b (i + 4) (ry r) + pokeU32 b (i + 8) (rw r) + pokeU32 b (i + 12) (rh r)
      + putRects b rest (i + 16)

-- Wait up to `ms` for an event: a key runs its action, quit quits; anything else (a resize) redraws.
waitInput :: Handle Win %1 -> Handle Ren %1 -> Handle Aud %1 -> Handle Tex %1 -> Handle Pipe %1 -> Handle Pipe %1 -> Buffer Int -> Array String -> Array Cue -> Probe -> Player -> Vid -> List Step -> Int -> IO ()
waitInput win ren aud tex pipe apipe buf fs subs pr p v steps ms = do
  let ev = newBuffer 64
  let got = sdlWaitEventTimeout (bufPtrN ev 64) ms
  let ty = peekU32 ev 0
  if got == 0
    then loop win ren aud tex pipe apipe buf fs subs pr p v steps
    else case ty of
      SDL_QUIT -> act win ren aud tex pipe apipe buf fs subs pr (p { effect = effQuit }) v steps
      SDL_KEYDOWN -> onKey win ren aud tex pipe apipe buf fs subs pr p v steps (keyToken (peekU32 ev 20) (peekU16 ev 24))
      _ -> do
        present ren tex fs subs pr p v
        loop win ren aud tex pipe apipe buf fs subs pr p v steps

-- A key token: resolve it against the config keymap (sequences wait for their next key), then run
-- the action — a built-in name, or `!cmd` through the shell on the current file.
onKey :: Handle Win %1 -> Handle Ren %1 -> Handle Aud %1 -> Handle Tex %1 -> Handle Pipe %1 -> Handle Pipe %1 -> Buffer Int -> Array String -> Array Cue -> Probe -> Player -> Vid -> List Step -> String -> IO ()
onKey win ren aud tex pipe apipe buf fs subs pr p v steps tok = do
  let km = readFile (keymapFile 0)
  let a = keyAction km (keys p) tok
  let p1 = p { keys = keyPending km (keys p) tok }
  if hasPrefix "!" a
    then do
      runStatus (userCmd (getArray fs (idx p1)) (pos p1) (substr 1 (strLen a - 1) a))
      loop win ren aud tex pipe apipe buf fs subs pr p1 v steps
    else act win ren aud tex pipe apipe buf fs subs pr (runAction a p1) v steps

-- Perform the effect an action left in the player (`Core.effect`), then go on playing. The audio
-- device follows the pause state.
act :: Handle Win %1 -> Handle Ren %1 -> Handle Aud %1 -> Handle Tex %1 -> Handle Pipe %1 -> Handle Pipe %1 -> Buffer Int -> Array String -> Array Cue -> Probe -> Player -> Vid -> List Step -> IO ()
act win ren aud tex pipe apipe buf fs subs pr p v0 steps = do
  sdlPauseAudio aud (if paused p then 1 else 0)
  let v = v0 { vdirty = 1, vosd = (if osdPing p then sdlGetTicks 0 + 2000 else vosd v0) }
  perform win ren aud tex pipe apipe buf fs subs pr p v steps (effect p) (getArray fs (idx p))

perform :: Handle Win %1 -> Handle Ren %1 -> Handle Aud %1 -> Handle Tex %1 -> Handle Pipe %1 -> Handle Pipe %1 -> Buffer Int -> Array String -> Array Cue -> Probe -> Player -> Vid -> List Step -> Int -> String -> IO ()
perform win ren aud tex pipe apipe buf fs subs pr p v steps e f =
  if e == effQuit then do
    closeFile aud tex pipe apipe
    finish win ren aud (settled p) (vshown v) (vdropped v) (vshots v)
  else if e == effSeek then do
    pclose pipe
    let np = popen (videoCmd f (seekTo p)) "r"
    let na = respawnAudio aud apipe f (seekTo p) (speed p)
    loop win ren aud tex np na buf fs subs pr (settled (p { pos = seekTo p }))
      (v { vk = 0, vbase = seekTo p, vfd = fileno np, vafd = fileno na, vaeof = 0 }) steps
  else if e == effRespawn then do
    let na = respawnAudio aud apipe f (pos p) (speed p)
    loop win ren aud tex pipe na buf fs subs pr (settled p) (v { vafd = fileno na, vaeof = 0 }) steps
  else if e == effGoto then do
    closeFile aud tex pipe apipe
    openFile win ren aud fs (settled p) steps (vt0 v) (vshown v) (vdropped v) (vshots v)
  else if e == effShot then do
    let name = saveShot buf (vw v) (vh v) 1
    ePutStrLn (if strLen name > 0 then "axmpv: screenshot " ++ name else "axmpv: could not write a screenshot")
    loop win ren aud tex pipe apipe buf fs subs pr (settled p) (v { vshots = vshots v + (if strLen name > 0 then 1 else 0) }) steps
  else if e == effFull then do
    sdlSetFullscreen win (if fullscreen p then 4097 else 0)        -- SDL_WINDOW_FULLSCREEN_DESKTOP
    loop win ren aud tex pipe apipe buf fs subs pr (settled p) v steps
  else loop win ren aud tex pipe apipe buf fs subs pr (settled p) v steps

-- ─── screenshots ─────────────────────────────────────────────────────────────────────────────────
-- Save the `w`×`h` BGRA frame in `buf` as the first free `axmpv-shot-NNNN.ppm` (from number `k`);
-- the file's name, or "" when it cannot be written.
saveShot :: Buffer Int -> Int -> Int -> Int -> String
saveShot buf w h k =
  if fileExists (shotName k) == 1 then saveShot buf w h (k + 1)
  else let name = shotName k in
       let fd = creatFile name 420 in                                 -- 0644
       if fd < 0 then ""
       else let n = w * h in
            let rgb = newBuffer (n * 3 + 1) in
            let c = bgrToRgb buf rgb 0 n 0 in
            let hd = ppmHeader w h in
            let wrote = writeStr fd hd (strLen hd)
                        + (borrow rgb as rp in writeFd fd (rp + c * 0) (n * 3)) in
            if closeFd fd + wrote * 0 == 0 then name else ""

-- BGRA pixels → RGB bytes, `n` pixels from pixel `i` (an accumulating loop: a tail call per pixel)
bgrToRgb :: Buffer Int -> Buffer Int -> Int -> Int -> Int -> Int
bgrToRgb src dst i n acc =
  if i >= n then acc
  else bgrToRgb src dst (i + 1) n
         (acc + pokeU8 dst (i * 3) (peekU8 src (i * 4 + 2))
              + pokeU8 dst (i * 3 + 1) (peekU8 src (i * 4 + 1))
              + pokeU8 dst (i * 3 + 2) (peekU8 src (i * 4)))
