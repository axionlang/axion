-- axmpv — an mpv-like video player in Axión (flagship). The pure player logic (state, actions, key
-- tokens, subtitles, layout) lives in Core.axi, shared with CoreTest.axi; this file is the effectful
-- shell: SDL2 for the window/renderer/input, libc `popen`/`read` for the media pipes.
--
--   scripts/axmpv-run.sh video.mkv other.mp4
--   axmpv [--config FILE] [--script FILE] FILE…
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
foreign "libSDL2.so" sdlRenderCopy = "SDL_RenderCopy" :: Borrow (Handle Ren) -> Borrow (Handle Tex) -> Int -> Int -> Int
foreign "libSDL2.so" sdlSetDrawColor = "SDL_SetRenderDrawColor" :: Borrow (Handle Ren) -> Int -> Int -> Int -> Int -> Int
foreign "libSDL2.so" sdlRenderClear = "SDL_RenderClear" :: Borrow (Handle Ren) -> Int
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

foreign struct SDL_Rect { x :: I32, y :: I32, w :: I32, h :: I32 }
foreign enum SdlEvent { SDL_QUIT = 256, SDL_KEYDOWN = 768 }

-- SDL_PIXELFORMAT_ARGB8888 (= BGRA bytes in memory, ffmpeg's `bgra`), SDL_TEXTUREACCESS_STREAMING
pixelFormat :: Int
pixelFormat = 372645892

-- ─── per-file playback state ─────────────────────────────────────────────────────────────────────
-- Plain Ints, so the record update every frame stays cheap. `vk` = frames read from the current
-- pipe; `vbase` = the position (ms) the pipe started at, so frame k is due at vbase + frameMs k;
-- `vlast` = the tick the clock last advanced at; `vt0` = the tick playback began (script time);
-- `vafd` = the audio pipe's descriptor, `vaeof` = 1 once it has ended (or the file has no audio).
data Vid = Vid
  { vk :: Int, vbase :: Int, vlast :: Int, vt0 :: Int, vshown :: Int, vdropped :: Int
  , vfd :: Int, vw :: Int, vh :: Int, vafd :: Int, vaeof :: Int }

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
       if a == "--script" || a == "--config" then fileArgs (i + 2) n
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
    then ePutStrLn "usage: axmpv [--config FILE] [--script FILE] FILE…"
    else do
      runStatus (keymapCmd (if strLen cf > 0 then cf else configFile 0) (keymapFile 0))
      let p = configured (readFile (keymapFile 0)) (newPlayer (lenArray fs))
      sdlInit 48                                                    -- SDL_INIT_VIDEO | SDL_INIT_AUDIO
      let win = sdlCreateWindow "axmpv" 805240832 805240832 960 540 36 -- CENTERED, SHOWN|RESIZABLE
      sdlSetFullscreen win (if fullscreen p then 4097 else 0)
      let ren = sdlCreateRenderer win (0 - 1) 0
      let aud = openAudio 0
      sdlPauseAudio aud 0
      openFile win ren aud fs p steps (sdlGetTicks 0) 0 0

-- Open playlist entry `idx p`: probe it, create its texture and frame buffer, spawn the video and
-- audio pipes. A file ffprobe cannot read (no video stream) is skipped.
openFile :: Handle Win %1 -> Handle Ren %1 -> Handle Aud %1 -> Array String -> Player -> List Step -> Int -> Int -> Int -> IO ()
openFile win ren aud fs p steps t0 shown dropped = do
  let f = getArray fs (idx p)
  let pr = parseProbe (runCapture (probeCmd f))
  if pw pr <= 0 || ph pr <= 0
    then do
      ePutStrLn ("axmpv: cannot play " ++ f)
      nextOrQuit win ren aud fs p steps t0 shown dropped
    else do
      sdlSetTitle win (baseName f ++ " — axmpv")
      let tex = sdlCreateTexture ren pixelFormat 1 (pw pr) (ph pr)
      let pipe = popen (videoCmd f 0) "r"
      let apipe = popen (audioCmd f 0 (speed p)) "r"
      let now = sdlGetTicks 0
      let v = Vid { vk = 0, vbase = 0, vlast = now, vt0 = t0, vshown = shown, vdropped = dropped
                  , vfd = fileno pipe, vw = pw pr, vh = ph pr, vafd = fileno apipe, vaeof = 0 }
      loop win ren aud tex pipe apipe (newBuffer (frameBytes v)) fs pr (p { pos = 0, dur = durMs pr }) v steps

-- The next playlist entry, or quit after the last one (mpv's default).
nextOrQuit :: Handle Win %1 -> Handle Ren %1 -> Handle Aud %1 -> Array String -> Player -> List Step -> Int -> Int -> Int -> IO ()
nextOrQuit win ren aud fs p steps t0 shown dropped =
  if idx p + 1 < lenArray fs
    then openFile win ren aud fs (p { idx = idx p + 1 }) steps t0 shown dropped
    else finish win ren aud p shown dropped

finish :: Handle Win %1 -> Handle Ren %1 -> Handle Aud %1 -> Player -> Int -> Int -> IO ()
finish win ren aud p shown dropped = do
  sdlCloseAudio aud
  sdlDestroyRenderer ren
  sdlDestroyWindow win
  sdlQuit 0
  putStrLn (statusLine p shown dropped)

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
loop :: Handle Win %1 -> Handle Ren %1 -> Handle Aud %1 -> Handle Tex %1 -> Handle Pipe %1 -> Handle Pipe %1 -> Buffer Int -> Array String -> Probe -> Player -> Vid -> List Step -> IO ()
loop win ren aud tex pipe apipe buf fs pr p v steps = do
  let now = sdlGetTicks 0
  let p1 = if paused p then p else p { pos = pos p + (now - vlast v) * speed p / 100 }
  let ended = if paused p1 || vaeof v == 1 then vaeof v else feedAudio aud (vafd v) (effVolume p1) 8
  let v1 = v { vlast = now, vaeof = ended }
  case steps of
    Cons s rest ->
      if now - vt0 v1 >= stepAt s
        then (if hasPrefix "key:" (stepAction s)
                then onKey win ren aud tex pipe apipe buf fs pr p1 v1 rest (substr 4 (strLen (stepAction s) - 4) (stepAction s))
                else act win ren aud tex pipe apipe buf fs pr (runAction (stepAction s) p1) v1 rest)
        else tick win ren aud tex pipe apipe buf fs pr p1 v1 steps
    Nil -> tick win ren aud tex pipe apipe buf fs pr p1 v1 steps

-- Take the next frame if it is due (paused: only the first frame after opening or seeking), else
-- wait for input until it is.
tick :: Handle Win %1 -> Handle Ren %1 -> Handle Aud %1 -> Handle Tex %1 -> Handle Pipe %1 -> Handle Pipe %1 -> Buffer Int -> Array String -> Probe -> Player -> Vid -> List Step -> IO ()
tick win ren aud tex pipe apipe buf fs pr p v steps =
  let due = vbase v + frameMs pr (vk v) in
  if (paused p && vk v > 0) || (not (paused p) && pos p < due)
    then waitInput win ren aud tex pipe apipe buf fs pr p v steps (if paused p then 50 else imin 50 (imax 1 ((due - pos p) * 100 / speed p)))
    else frameStep win ren aud tex pipe apipe buf fs pr p v steps

-- Read frame `vk`; show it, or drop it when the clock has already passed the next frame's time.
-- End of stream → the next file. The wait for a new pipe's FIRST frame (ffmpeg starting up, or
-- seeking) is not playback time: the clock restarts once it arrives, so it is never late.
frameStep :: Handle Win %1 -> Handle Ren %1 -> Handle Aud %1 -> Handle Tex %1 -> Handle Pipe %1 -> Handle Pipe %1 -> Buffer Int -> Array String -> Probe -> Player -> Vid -> List Step -> IO ()
frameStep win ren aud tex pipe apipe buf fs pr p0 v0 steps = do
  let n = frameBytes v0
  let got = readFull (vfd v0) (bufPtrN buf n) 0 n
  let first = vk v0 == 0
  let p = if first then p0 { pos = vbase v0 } else p0
  let v = if first then v0 { vlast = sdlGetTicks 0 } else v0
  if got < n
    then do
      closeFile aud tex pipe apipe
      nextOrQuit win ren aud fs (settled p) steps (vt0 v) (vshown v) (vdropped v)
    else if not (paused p) && pos p >= vbase v + frameMs pr (vk v + 1)
      then loop win ren aud tex pipe apipe buf fs pr p (v { vk = vk v + 1, vdropped = vdropped v + 1 }) steps
      else do
        sdlUpdateTexture tex 0 (bufPtrN buf n) (vw v * 4)
        present ren tex (vw v) (vh v)
        loop win ren aud tex pipe apipe buf fs pr p (v { vk = vk v + 1, vshown = vshown v + 1 }) steps

-- Draw the texture letterboxed into the current output size.
present :: Handle Ren -> Handle Tex -> Int -> Int -> Int
present ren tex fw fh =
  let ob = newBuffer 8 in
  let got = sdlGetOutputSize ren (bufPtrN ob 8) (bufPtrN ob 8 + 4) in
  let r = fitRect fw fh (peekU32 ob 0) (peekU32 ob 4) in
  let dst = SDL_Rect { x = rx r, y = ry r, w = rw r, h = rh r } in
  sdlSetDrawColor ren 0 0 0 255 + got + sdlRenderClear ren
    + (borrow dst as d in sdlRenderCopy ren tex 0 d) + sdlRenderPresent ren

-- Wait up to `ms` for an event: a key runs its action, quit quits; anything else (a resize) redraws.
waitInput :: Handle Win %1 -> Handle Ren %1 -> Handle Aud %1 -> Handle Tex %1 -> Handle Pipe %1 -> Handle Pipe %1 -> Buffer Int -> Array String -> Probe -> Player -> Vid -> List Step -> Int -> IO ()
waitInput win ren aud tex pipe apipe buf fs pr p v steps ms = do
  let ev = newBuffer 64
  let got = sdlWaitEventTimeout (bufPtrN ev 64) ms
  let ty = peekU32 ev 0
  if got == 0
    then loop win ren aud tex pipe apipe buf fs pr p v steps
    else case ty of
      SDL_QUIT -> act win ren aud tex pipe apipe buf fs pr (p { effect = effQuit }) v steps
      SDL_KEYDOWN -> onKey win ren aud tex pipe apipe buf fs pr p v steps (keyToken (peekU32 ev 20) (peekU16 ev 24))
      _ -> do
        present ren tex (vw v) (vh v)
        loop win ren aud tex pipe apipe buf fs pr p v steps

-- A key token: resolve it against the config keymap (sequences wait for their next key), then run
-- the action — a built-in name, or `!cmd` through the shell on the current file.
onKey :: Handle Win %1 -> Handle Ren %1 -> Handle Aud %1 -> Handle Tex %1 -> Handle Pipe %1 -> Handle Pipe %1 -> Buffer Int -> Array String -> Probe -> Player -> Vid -> List Step -> String -> IO ()
onKey win ren aud tex pipe apipe buf fs pr p v steps tok = do
  let km = readFile (keymapFile 0)
  let a = keyAction km (keys p) tok
  let p1 = p { keys = keyPending km (keys p) tok }
  if hasPrefix "!" a
    then do
      runStatus (userCmd (getArray fs (idx p1)) (pos p1) (substr 1 (strLen a - 1) a))
      loop win ren aud tex pipe apipe buf fs pr p1 v steps
    else act win ren aud tex pipe apipe buf fs pr (runAction a p1) v steps

-- Perform the effect an action left in the player (`Core.effect`), then go on playing. The audio
-- device follows the pause state.
act :: Handle Win %1 -> Handle Ren %1 -> Handle Aud %1 -> Handle Tex %1 -> Handle Pipe %1 -> Handle Pipe %1 -> Buffer Int -> Array String -> Probe -> Player -> Vid -> List Step -> IO ()
act win ren aud tex pipe apipe buf fs pr p v steps = do
  sdlPauseAudio aud (if paused p then 1 else 0)
  perform win ren aud tex pipe apipe buf fs pr p v steps (effect p) (getArray fs (idx p))

perform :: Handle Win %1 -> Handle Ren %1 -> Handle Aud %1 -> Handle Tex %1 -> Handle Pipe %1 -> Handle Pipe %1 -> Buffer Int -> Array String -> Probe -> Player -> Vid -> List Step -> Int -> String -> IO ()
perform win ren aud tex pipe apipe buf fs pr p v steps e f =
  if e == effQuit then do
    closeFile aud tex pipe apipe
    finish win ren aud (settled p) (vshown v) (vdropped v)
  else if e == effSeek then do
    pclose pipe
    let np = popen (videoCmd f (seekTo p)) "r"
    let na = respawnAudio aud apipe f (seekTo p) (speed p)
    loop win ren aud tex np na buf fs pr (settled (p { pos = seekTo p }))
      (v { vk = 0, vbase = seekTo p, vfd = fileno np, vafd = fileno na, vaeof = 0 }) steps
  else if e == effRespawn then do
    let na = respawnAudio aud apipe f (pos p) (speed p)
    loop win ren aud tex pipe na buf fs pr (settled p) (v { vafd = fileno na, vaeof = 0 }) steps
  else if e == effGoto then do
    closeFile aud tex pipe apipe
    openFile win ren aud fs (settled p) steps (vt0 v) (vshown v) (vdropped v)
  else if e == effFull then do
    sdlSetFullscreen win (if fullscreen p then 4097 else 0)        -- SDL_WINDOW_FULLSCREEN_DESKTOP
    loop win ren aud tex pipe apipe buf fs pr (settled p) v steps
  else loop win ren aud tex pipe apipe buf fs pr (settled p) v steps
