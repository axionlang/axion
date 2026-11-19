-- axmpv Core — the PURE part of the player: no FFI, so it runs on the interpreter as well as the
-- native backends (CoreTest.axi prints its results on all three; any difference is a compiler bug).
-- The player (axmpv.axi) imports it for: time formatting, ffprobe parsing, the player state and its
-- actions, key tokens + mpv's default bindings, config keymap lookup, `.srt` subtitles, audio volume
-- scaling and the OSD layout.

-- ─── small helpers ───────────────────────────────────────────────────────────────────────────────
dup :: String -> String
dup s = substr 0 (strLen s) s

intOr :: Int -> String -> Int
intOr d s = fromMaybe d (readInt (trim s))

imax :: Int -> Int -> Int
imax a b = if a > b then a else b

imin :: Int -> Int -> Int
imin a b = if a < b then a else b

clamp :: Int -> Int -> Int -> Int
clamp lo hi x = imax lo (imin hi x)

-- ─── time ────────────────────────────────────────────────────────────────────────────────────────
pad2 :: Int -> String
pad2 n = if n < 10 then strAppend "0" (showInt n) else showInt n

-- milliseconds → "HH:MM:SS" (mpv's OSD format)
fmtTime :: Int -> String
fmtTime ms =
  let s = (if ms < 0 then 0 else ms) / 1000 in
  pad2 (s / 3600) ++ ":" ++ pad2 (mod (s / 60) 60) ++ ":" ++ pad2 (mod s 60)

-- "4.000000" (seconds, as ffprobe prints them) → 4000 ms; "N/A" or junk → 0
parseMs :: String -> Int
parseMs s = case splitOn '.' (trim s) of
  Cons whole rest -> intOr 0 whole * 1000 + fracMs rest
  Nil -> 0

fracMs :: List String -> Int
fracMs rest = case rest of
  Cons f _ -> intOr 0 (substr 0 3 (strAppend f "000"))
  Nil -> 0

-- ─── ffprobe ─────────────────────────────────────────────────────────────────────────────────────
-- `ffprobe -show_entries stream=width,height,r_frame_rate:format=duration -of csv=p=0` prints the
-- stream line `320,240,25/1` and then the format line `4.000000`.
data Probe = Probe { pw :: Int, ph :: Int, fpsN :: Int, fpsD :: Int, durMs :: Int }

parseProbe :: String -> Probe
parseProbe out = probeLines (lines out)

probeLines :: List String -> Probe
probeLines ls = case ls of
  Cons l1 rest -> probeFrom (splitOn ',' l1) (durOf rest)
  Nil -> noProbe 0

durOf :: List String -> Int
durOf ls = case ls of
  Cons l _ -> parseMs l
  Nil -> 0

noProbe :: Int -> Probe
noProbe d = Probe { pw = 0, ph = 0, fpsN = 25, fpsD = 1, durMs = d }

-- (Nested constructor patterns such as `Cons w (Cons h (Cons r _))` run on the interpreter but do
-- not compile natively yet — "nested pattern in a constructor" — so the list is taken apart one
-- `case` at a time.)
probeFrom :: List String -> Int -> Probe
probeFrom fs d = case fs of
  Cons w r1 -> case r1 of
    Cons h r2 -> case r2 of
      Cons r _ -> withRate (intOr 0 w) (intOr 0 h) (splitOn '/' r) d
      Nil -> noProbe d
    Nil -> noProbe d
  Nil -> noProbe d

withRate :: Int -> Int -> List String -> Int -> Probe
withRate w h rate d = case rate of
  Cons n r1 -> case r1 of
    Cons dn _ ->
      let fn = intOr 25 n in
      let fd = intOr 1 dn in
      Probe { pw = w, ph = h, fpsN = (if fn > 0 then fn else 25), fpsD = (if fd > 0 then fd else 1), durMs = d }
    Nil -> Probe { pw = w, ph = h, fpsN = 25, fpsD = 1, durMs = d }
  Nil -> Probe { pw = w, ph = h, fpsN = 25, fpsD = 1, durMs = d }

-- the presentation time of frame `k` (ms)
frameMs :: Probe -> Int -> Int
frameMs p k = k * 1000 * fpsD p / fpsN p

-- the frame due at time `ms`
frameAt :: Probe -> Int -> Int
frameAt p ms = ms * fpsN p / (1000 * fpsD p)

-- ─── player state ────────────────────────────────────────────────────────────────────────────────
-- `effect` tells the loop what the last action needs beyond the state change itself.
effNone :: Int
effNone = 0
effSeek :: Int
effSeek = 1        -- restart the pipes at `seekTo`
effRespawn :: Int
effRespawn = 2     -- restart the pipes at the current position (speed changed)
effShot :: Int
effShot = 3        -- save a screenshot
effQuit :: Int
effQuit = 4
effGoto :: Int
effGoto = 5        -- open playlist entry `idx`
effFull :: Int
effFull = 6        -- toggle fullscreen

data Player = Player
  { pos :: Int, dur :: Int, vol :: Int, muted :: Bool, paused :: Bool, speed :: Int
  , loopA :: Int, loopB :: Int, subOn :: Bool, subDelay :: Int, osdOn :: Bool, osdPing :: Bool
  , infoOn :: Bool, fullscreen :: Bool, idx :: Int, nfiles :: Int, effect :: Int, seekTo :: Int
  , keys :: String, loopFile :: Bool, zoom :: Int, panX :: Int, panY :: Int, rot :: Int
  , zoomStep :: Int, panStep :: Int }

newPlayer :: Int -> Player
newPlayer n = Player
  { pos = 0, dur = 0, vol = 100, muted = False, paused = False, speed = 100
  , loopA = 0 - 1, loopB = 0 - 1, subOn = True, subDelay = 0, osdOn = False, osdPing = False
  , infoOn = False, fullscreen = False, idx = 0, nfiles = n, effect = 0, seekTo = 0, keys = "", loopFile = False
  , zoom = 100, panX = 0, panY = 0, rot = 0, zoomStep = 10, panStep = 5 }

-- the effect has been performed
settled :: Player -> Player
settled p = p { effect = effNone, osdPing = False }

ping :: Player -> Player
ping p = p { osdPing = True }

seekBy :: Int -> Player -> Player
seekBy d p = ping (p { effect = effSeek, seekTo = clamp 0 (imax 0 (dur p - 1)) (pos p + d) })

togglePause :: Player -> Player
togglePause p = ping (p { paused = not (paused p) })

volumeBy :: Int -> Player -> Player
volumeBy d p = ping (p { vol = clamp 0 130 (vol p + d), muted = False })

toggleMute :: Player -> Player
toggleMute p = ping (p { muted = not (muted p) })

-- mpv's `[` / `]` multiply the speed by 0.9 / 1.1; kept in percent, within 25%..400%
speedTimes :: Int -> Player -> Player
speedTimes pct p = ping (p { speed = clamp 25 400 (speed p * pct / 100), effect = effRespawn })

speedReset :: Player -> Player
speedReset p = ping (p { speed = 100, effect = effRespawn })

gotoBy :: Int -> Player -> Player
gotoBy d p =
  let j = idx p + d in
  if (j < 0) || (j >= nfiles p) then p else p { idx = j, effect = effGoto }

-- `l`: set A, then B, then clear
abLoop :: Player -> Player
abLoop p =
  if loopA p < 0 then ping (p { loopA = pos p })
  else if loopB p < 0 then ping (p { loopB = imax (pos p) (loopA p + 100) })
  else ping (p { loopA = 0 - 1, loopB = 0 - 1 })

-- after the clock advanced: past the B point of an A-B loop → seek back to A
loopCheck :: Player -> Player
loopCheck p =
  if (loopB p >= 0) && (pos p >= loopB p) && (effect p == effNone)
  then p { effect = effSeek, seekTo = loopA p } else p

data Action = Action String (Player -> Player)

-- The built-in actions — the same names a config.lua `{ key, action }` row may use.
actions :: List Action
actions =
  [ Action "pause" togglePause
  , Action "seek_forward" (seekBy 5000)
  , Action "seek_backward" (seekBy (0 - 5000))
  , Action "seek_forward_long" (seekBy 60000)
  , Action "seek_backward_long" (seekBy (0 - 60000))
  , Action "volume_up" (volumeBy 2)
  , Action "volume_down" (volumeBy (0 - 2))
  , Action "mute" toggleMute
  , Action "speed_up" (speedTimes 110)
  , Action "speed_down" (speedTimes 90)
  , Action "speed_reset" speedReset
  , Action "fullscreen" (\p -> p { effect = effFull, fullscreen = not (fullscreen p) })
  , Action "osd" (\p -> p { osdOn = not (osdOn p) })
  , Action "info" (\p -> p { infoOn = not (infoOn p) })
  , Action "screenshot" (\p -> ping (p { effect = effShot }))
  , Action "ab_loop" abLoop
  , Action "loop_file" (\p -> ping (p { loopFile = not (loopFile p) }))
  , Action "zoom_in" (\p -> ping (p { zoom = clamp 10 1600 (imax (zoom p + 1) (zoom p * (100 + zoomStep p) / 100)) }))
  , Action "zoom_out" (\p -> ping (p { zoom = clamp 10 1600 (zoom p * 100 / (100 + zoomStep p)) }))
  , Action "fit" (\p -> ping (p { zoom = 100, panX = 0, panY = 0 }))
  , Action "pan_left" (\p -> ping (p { panX = panX p - 1 }))
  , Action "pan_right" (\p -> ping (p { panX = panX p + 1 }))
  , Action "pan_up" (\p -> ping (p { panY = panY p - 1 }))
  , Action "pan_down" (\p -> ping (p { panY = panY p + 1 }))
  , Action "rotate" (\p -> ping (p { rot = mod (rot p + 90) 360 }))
  , Action "rotate_ccw" (\p -> ping (p { rot = mod (rot p + 270) 360 }))
  , Action "sub_toggle" (\p -> ping (p { subOn = not (subOn p) }))
  , Action "sub_delay_up" (\p -> ping (p { subDelay = subDelay p + 100 }))
  , Action "sub_delay_down" (\p -> ping (p { subDelay = subDelay p - 100 }))
  , Action "playlist_next" (gotoBy 1)
  , Action "playlist_prev" (gotoBy (0 - 1))
  , Action "quit" (\p -> p { effect = effQuit })
  ]

-- Run the named action; an unknown name leaves the player unchanged.
runAction :: String -> Player -> Player
runAction name p = raGo actions name p

raGo :: List Action -> String -> Player -> Player
raGo acts name p = case acts of
  Nil -> p
  Cons a rest -> case a of
    Action n f -> if n == name then f p else raGo rest name p

isAction :: String -> Bool
isAction name = iaGo actions name

iaGo :: List Action -> String -> Bool
iaGo acts name = case acts of
  Nil -> False
  Cons a rest -> case a of
    Action n _ -> if n == name then True else iaGo rest name

-- ─── keys ────────────────────────────────────────────────────────────────────────────────────────
-- SDL keycodes (SDLK_*) of the special keys
keyRight :: Int
keyRight = 1073741903
keyLeft :: Int
keyLeft = 1073741904
keyUp :: Int
keyUp = 1073741906
keyDown :: Int
keyDown = 1073741905
keyHome :: Int
keyHome = 1073741898
keyEnd :: Int
keyEnd = 1073741901

ctrlHeld :: Int -> Bool
ctrlHeld md = (mod (md / 64) 4) > 0       -- KMOD_LCTRL 64 | KMOD_RCTRL 128
altHeld :: Int -> Bool
altHeld md = (mod (md / 256) 4) > 0       -- KMOD_LALT 256 | KMOD_RALT 512
shiftHeld :: Int -> Bool
shiftHeld md = (mod md 4) > 0             -- KMOD_LSHIFT 1 | KMOD_RSHIFT 2

-- A pressed key → its config TOKEN: a printable char, `<Right>`/`<Space>`/…, optionally prefixed
-- with `C-` (Ctrl) / `M-` (Alt); Shift is folded into the glyph (US layout). "" for a bare modifier.
keyBase :: Int -> String
keyBase key =
  if      key == keyRight then "<Right>"
  else if key == keyLeft  then "<Left>"
  else if key == keyUp    then "<Up>"
  else if key == keyDown  then "<Down>"
  else if key == keyHome  then "<Home>"
  else if key == keyEnd   then "<End>"
  else if key == 27 then "<Esc>"
  else if key == 32 then "<Space>"
  else if key == 13 then "<Enter>"
  else if key == 8 then "<BS>"
  else if key == 9 then "<Tab>"
  else if (key > 32) && (key < 127) then chr key
  else ""

shiftGlyph :: Int -> String
shiftGlyph key =
  if (key >= 97) && (key <= 122) then chr (key - 32)
  else if key == 44 then "<" else if key == 46 then ">" else if key == 47 then "?"
  else if key == 45 then "_" else if key == 61 then "+" else if key == 59 then ":"
  else if key == 39 then "\"" else if key == 91 then "{" else if key == 93 then "}"
  else if key == 92 then "|" else if key == 96 then "~"
  else if key == 49 then "!" else if key == 50 then "@" else if key == 51 then "#"
  else if key == 52 then "$" else if key == 53 then "%" else if key == 54 then "^"
  else if key == 55 then "&" else if key == 56 then "*" else if key == 57 then "("
  else if key == 48 then ")" else chr key

keyToken :: Int -> Int -> String
keyToken key md =
  let base = keyBase key in
  if strLen base == 0 then ""
  else let glyph = if (strLen base == 1) && shiftHeld md then shiftGlyph key else base in
       (if ctrlHeld md then "C-" else "") ++ (if altHeld md then "M-" else "") ++ glyph

-- mpv's default bindings: key token → action name ("" when unbound)
defaultAction :: String -> String
defaultAction t =
  if t == "<Space>" || t == "p" then "pause"
  else if t == "<Right>" then "seek_forward"
  else if t == "<Left>" then "seek_backward"
  else if t == "<Up>" then "seek_forward_long"
  else if t == "<Down>" then "seek_backward_long"
  else if t == "0" || t == "*" then "volume_up"
  else if t == "9" || t == "/" then "volume_down"
  else if t == "m" then "mute"
  else if t == "]" then "speed_up"
  else if t == "[" then "speed_down"
  else if t == "<BS>" then "speed_reset"
  else if t == "f" then "fullscreen"
  else if t == "o" || t == "<Tab>" then "osd"
  else if t == "i" then "info"
  else if t == "s" then "screenshot"
  else if t == "l" then "ab_loop"
  else if t == "L" then "loop_file"
  else if t == "M-<Left>" then "pan_left"
  else if t == "M-<Right>" then "pan_right"
  else if t == "M-<Up>" then "pan_up"
  else if t == "M-<Down>" then "pan_down"
  else if t == "M-+" || t == "M-=" then "zoom_in"
  else if t == "M--" then "zoom_out"
  else if t == "M-<BS>" then "fit"
  else if t == "r" then "rotate"
  else if t == "R" then "rotate_ccw"
  else if t == "v" then "sub_toggle"
  else if t == "x" then "sub_delay_up"
  else if t == "z" then "sub_delay_down"
  else if t == ">" || t == "<Enter>" then "playlist_next"
  else if t == "<" then "playlist_prev"
  else if t == "q" || t == "<Esc>" then "quit"
  else ""

-- ─── config keymap (`key<TAB>action` lines, built from config.lua by a sed pass) ─────────────────
tabScan :: String -> Int -> Int
tabScan s i = if i >= strLen s then (0 - 1) else if charAt i s == '\t' then i else tabScan s (i + 1)

kmKey :: String -> String
kmKey line = let i = tabScan line 0 in if i < 0 then dup line else substr 0 i line

kmVal :: String -> String
kmVal line = let i = tabScan line 0 in if i < 0 then "" else substr (i + 1) (strLen line - i - 1) line

-- the action bound to the key sequence `k` in keymap text `km`, or ""
lookupAction :: String -> String -> String
lookupAction km k = laGo (lines km) k

laGo :: List String -> String -> String
laGo xs k = case xs of
  Nil -> ""
  Cons y ys -> if kmKey y == k then kmVal y else laGo ys k

-- is `acc` a PROPER prefix of some bound sequence (wait for more keys)?
isProperPrefix :: String -> String -> Bool
isProperPrefix km acc = ippGo (lines km) acc

ippGo :: List String -> String -> Bool
ippGo xs acc = case xs of
  Nil -> False
  Cons y ys ->
    let b = kmKey y in
    if (strLen b > strLen acc) && hasPrefix acc b then True else ippGo ys acc

-- an option row's value (`{ option = "volume", value = "70" }` → the line `\x01volume<TAB>70`; the
-- control character keeps option rows apart from key rows — a key may well be `=`)
optionOr :: String -> String -> String -> String
optionOr km name dflt =
  let v = lookupAction km (strAppend "\x01" name) in
  if strLen v > 0 then v else dup dflt

-- The action for key token `tok` arriving after the `pending` keys of an unfinished sequence: the
-- config binding of the whole sequence, else "" while it is still the prefix of a longer binding,
-- else (the sequence went nowhere) the token on its own — config first, then mpv's default.
keyAction :: String -> String -> String -> String
keyAction km pending tok =
  let acc = pending ++ tok in
  let a = lookupAction km acc in
  if strLen a > 0 then a
  else if isProperPrefix km acc then ""
  else if strLen pending > 0 then keyAction km "" tok
  else defaultAction tok

-- the keys still pending after `tok` (the start of a longer binding), or ""
keyPending :: String -> String -> String -> String
keyPending km pending tok =
  let acc = pending ++ tok in
  if strLen (lookupAction km acc) == 0 && isProperPrefix km acc then acc
  else if strLen pending > 0 && strLen (lookupAction km tok) == 0 && isProperPrefix km tok then dup tok
  else ""

envOr :: String -> String -> String
envOr name dflt = let v = getEnv name in if strLen v > 0 then v else dup dflt

configFile :: Int -> String
configFile d = envOr "HOME" "." ++ "/.config/axmpv/config.lua"

keymapFile :: Int -> String
keymapFile d = envOr "HOME" "." ++ "/.cache/axmpv/keymap"

-- The config: ~/.config/axmpv/config.lua → the keymap file, once at start-up (one `sh`). Each
-- `{ key = "K", action = "A" }` row becomes a `K<TAB>A` line and each `{ option = "O", value = "V" }`
-- row a `\x01O<TAB>V` line; `--` comment lines are skipped. No config → an empty keymap.
keymapCmd :: String -> String -> String
keymapCmd cfg km =
  "cfg=" ++ shQuote cfg ++ "; km=" ++ shQuote km
  ++ "; mkdir -p \"${km%/*}\"; : > \"$km\"; [ -r \"$cfg\" ] || exit 0; "
  ++ "sed '/^[[:space:]]*--/d' \"$cfg\" | while IFS= read -r line; do case \"$line\" in "
  ++ "*key*action*) k=$(printf '%s\\n' \"$line\" | sed -n 's/.*key[[:space:]]*=[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p'); "
  ++ "a=$(printf '%s\\n' \"$line\" | sed -n 's/.*action[[:space:]]*=[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p'); "
  ++ "[ -n \"$k\" ] && [ -n \"$a\" ] && printf '%s\\t%s\\n' \"$k\" \"$a\" >> \"$km\" ;; "
  ++ "*option*value*) o=$(printf '%s\\n' \"$line\" | sed -n 's/.*option[[:space:]]*=[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p'); "
  ++ "v=$(printf '%s\\n' \"$line\" | sed -n 's/.*value[[:space:]]*=[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p'); "
  ++ "[ -n \"$o\" ] && printf '\\001%s\\t%s\\n' \"$o\" \"$v\" >> \"$km\" ;; esac; done; true"

-- The player as the config's options set it up: volume, speed (percent), fullscreen, subtitles,
-- OSD, loop (the whole file; "yes"/"no"), zoom_step (percent per zoom press), pan_step (percent of
-- the window per pan press).
configured :: String -> Player -> Player
configured km p =
  p { vol = clamp 0 130 (intOr 100 (optionOr km "volume" "100"))
    , speed = clamp 25 400 (intOr 100 (optionOr km "speed" "100"))
    , fullscreen = optionOr km "fullscreen" "no" == "yes"
    , subOn = optionOr km "subtitles" "yes" == "yes"
    , osdOn = optionOr km "osd" "no" == "yes"
    , loopFile = optionOr km "loop" "no" == "yes"
    , zoomStep = clamp 1 100 (intOr 10 (optionOr km "zoom_step" "10"))
    , panStep = clamp 1 50 (intOr 5 (optionOr km "pan_step" "5")) }

-- ─── shell commands (`!cmd` actions): %s → the file, %t → the position in seconds ─────────────────
shEsc :: String -> Int -> Int -> String
shEsc s i n =
  if i >= n then ""
  else (if charAt i s == '\'' then "'\\''" ++ shEsc s (i + 1) n
        else substr i 1 s ++ shEsc s (i + 1) n)

shQuote :: String -> String
shQuote s = "'" ++ shEsc s 0 (strLen s) ++ "'"

substCmd :: String -> String -> String -> String
substCmd cmd file secs = scGo cmd file secs 0

scGo :: String -> String -> String -> Int -> String
scGo cmd file secs i =
  if i >= strLen cmd then ""
  else if (i + 1 < strLen cmd) && (charAt i cmd == '%') && (charAt (i + 1) cmd == 's')
    then file ++ scGo cmd file secs (i + 2)
  else if (i + 1 < strLen cmd) && (charAt i cmd == '%') && (charAt (i + 1) cmd == 't')
    then secs ++ scGo cmd file secs (i + 2)
  else substr i 1 cmd ++ scGo cmd file secs (i + 1)

-- the shell line for `!cmd` on `path` at `ms` (output suppressed, like aximv/axfm)
userCmd :: String -> Int -> String -> String
userCmd path ms cmd =
  "f=" ++ shQuote path ++ "; { " ++ substCmd cmd "\"$f\"" (showInt (ms / 1000)) ++ " ; } >/dev/null 2>&1"

-- ─── subtitles (.srt) ────────────────────────────────────────────────────────────────────────────
data Cue = Cue Int Int String

cueStart :: Cue -> Int
cueStart c = case c of
  Cue a _ _ -> a

cueEnd :: Cue -> Int
cueEnd c = case c of
  Cue _ b _ -> b

cueText :: Cue -> String
cueText c = case c of
  Cue _ _ t -> dup t

-- "00:01:02,345" → 62345 ms
srtTime :: String -> Int
srtTime s = case splitOn ',' (trim s) of
  Cons hms rest -> hmsMs (splitOn ':' hms) + fracMs rest
  Nil -> 0

hmsMs :: List String -> Int
hmsMs xs = case xs of
  Cons h r1 -> case r1 of
    Cons m r2 -> case r2 of
      Cons sec _ -> ((intOr 0 h * 60 + intOr 0 m) * 60 + intOr 0 sec) * 1000
      Nil -> 0
    Nil -> 0
  Nil -> 0

-- "00:00:01,000 --> 00:00:02,500"?
isTiming :: String -> Bool
isTiming l = arrowAt l 0 >= 0

-- the two sides of a timing line
timingFrom :: String -> Int
timingFrom l = let i = arrowAt l 0 in if i < 0 then 0 else srtTime (substr 0 i l)

timingTo :: String -> Int
timingTo l = let i = arrowAt l 0 in if i < 0 then 0 else srtTime (substr (i + 3) (strLen l - i - 3) l)

arrowAt :: String -> Int -> Int
arrowAt s i =
  if i + 3 > strLen s then (0 - 1)
  else if substr i 3 s == "-->" then i else arrowAt s (i + 1)

-- Parse an .srt file into cues, in file order: a block is an index line, a timing line and text
-- lines up to a blank line. Lines are joined with "\n"; a malformed block is skipped.
parseSrt :: String -> List Cue
parseSrt src = srtGo (lines src)

srtGo :: List String -> List Cue
srtGo ls = case ls of
  Nil -> Nil
  Cons l rest ->
    if isTiming l then srtText (timingFrom l) (timingTo l) rest ""
    else srtGo rest

srtText :: Int -> Int -> List String -> String -> List Cue
srtText a b ls acc = case ls of
  Nil -> if strLen acc > 0 then Cons (Cue a b acc) Nil else Nil
  Cons l rest ->
    let t = trim l in
    if strLen t == 0
      then (if strLen acc > 0 then Cons (Cue a b acc) (srtGo rest) else srtGo rest)
      else srtText a b rest (if strLen acc == 0 then t else acc ++ "\n" ++ t)

-- the cues in an Array (binary search by time)
cueArray :: List Cue -> Array Cue
cueArray cs = caFill (newArray (length cs) (Cue 0 0 "")) 0 cs

caFill :: Array Cue %1 -> Int -> List Cue -> Array Cue
caFill a i cs = case cs of
  Nil -> a
  Cons c rest -> caFill (setArray a i c) (i + 1) rest

-- the index of the cue showing at `ms`, or -1 (cues sorted by start, non-overlapping)
cueAt :: Array Cue -> Int -> Int
cueAt a ms = caFind a ms 0 (lenArray a - 1)

caFind :: Array Cue -> Int -> Int -> Int -> Int
caFind a ms lo hi =
  if lo > hi then (0 - 1)
  else let mid = (lo + hi) / 2 in
       let c = getArray a mid in
       if ms < cueStart c then caFind a ms lo (mid - 1)
       else if ms >= cueEnd c then caFind a ms (mid + 1) hi
       else mid

-- the subtitle text at `ms`, or ""
subtitleAt :: Array Cue -> Int -> String
subtitleAt a ms = let i = cueAt a ms in if i < 0 then "" else cueText (getArray a i)

-- ─── audio ───────────────────────────────────────────────────────────────────────────────────────
-- one signed 16-bit sample, stored little-endian as an unsigned 0..65535, scaled by `pct`% and
-- clamped — back as unsigned
scaleSample :: Int -> Int -> Int
scaleSample u pct =
  let s = if u >= 32768 then u - 65536 else u in
  let v = clamp (0 - 32768) 32767 (s * pct / 100) in
  if v < 0 then v + 65536 else v

-- the effective volume in percent (mute → 0)
effVolume :: Player -> Int
effVolume p = if muted p then 0 else vol p

-- ─── media commands ──────────────────────────────────────────────────────────────────────────────
-- The ffmpeg/ffprobe command lines (run through `sh -c` by `popen`/`runCapture`). `env -u
-- LD_LIBRARY_PATH`: the player runs with SDL's libraries on that path (scripts/axmpv-run.sh), which
-- can carry a C library ffmpeg's own dependencies do not match.
secs :: Int -> String
secs ms = showInt (ms / 1000) ++ "." ++ pad3 (ms - (ms / 1000) * 1000)

pad3 :: Int -> String
pad3 n = if n < 10 then "00" ++ showInt n else if n < 100 then "0" ++ showInt n else showInt n

probeCmd :: String -> String
probeCmd f =
  "env -u LD_LIBRARY_PATH ffprobe -v error -select_streams v:0 "
  ++ "-show_entries stream=width,height,r_frame_rate:format=duration -of csv=p=0 "
  ++ shQuote f ++ " 2>/dev/null"

-- raw BGRA frames of the first video stream, from `seekMs` on (`-ss` before `-i`: an accurate seek;
-- the output's frame 0 is the first frame at or after `seekMs`)
videoCmd :: String -> Int -> String
videoCmd f seekMs =
  "env -u LD_LIBRARY_PATH ffmpeg -nostdin -v error -ss " ++ secs seekMs ++ " -i " ++ shQuote f
  ++ " -an -f rawvideo -pix_fmt bgra - 2>/dev/null"

-- ─── layout ──────────────────────────────────────────────────────────────────────────────────────
data Rect = Rect Int Int Int Int

rx :: Rect -> Int
rx r = case r of
  Rect a _ _ _ -> a

ry :: Rect -> Int
ry r = case r of
  Rect _ b _ _ -> b

rw :: Rect -> Int
rw r = case r of
  Rect _ _ c _ -> c

rh :: Rect -> Int
rh r = case r of
  Rect _ _ _ d -> d

-- Where the `vw`×`vh` video goes in an `ow`×`oh` output, as the UNROTATED rectangle that SDL then
-- turns by `rot p` degrees about its centre: fitted with its rotated shape (90°/270° swap the
-- sides), scaled by `zoom p` percent, its centre moved by the pan steps (`panStep p`% of the output
-- each).
viewRect :: Player -> Int -> Int -> Int -> Int -> Rect
viewRect p vw vh ow oh =
  let side = rot p == 90 || rot p == 270 in
  let f = if side then fitRect vh vw ow oh else fitRect vw vh ow oh in
  let bw = rw f * zoom p / 100 in
  let bh = rh f * zoom p / 100 in
  let w = if side then bh else bw in
  let h = if side then bw else bh in
  let cx = ow / 2 + panX p * panStep p * ow / 100 in
  let cy = oh / 2 + panY p * panStep p * oh / 100 in
  Rect (cx - w / 2) (cy - h / 2) w h

-- the largest `vw`×`vh` rectangle with the video's aspect ratio inside an `ow`×`oh` output,
-- centred (letterboxed or pillarboxed)
fitRect :: Int -> Int -> Int -> Int -> Rect
fitRect vw vh ow oh =
  if vw <= 0 || vh <= 0 then Rect 0 0 ow oh
  else if ow * vh <= oh * vw
    then (let h = vh * ow / vw in Rect 0 ((oh - h) / 2) ow h)
    else (let w = vw * oh / vh in Rect ((ow - w) / 2) 0 w oh)

-- ─── test script ─────────────────────────────────────────────────────────────────────────────────
-- `--script F`: lines `<ms> <action>` — the action runs once `ms` of wall-clock time have passed
-- since playback began (headless tests drive the player with it). Blank and `#` lines are skipped.
data Step = Step Int String

stepAt :: Step -> Int
stepAt s = case s of
  Step t _ -> t

stepAction :: Step -> String
stepAction s = case s of
  Step _ a -> a

parseScript :: String -> List Step
parseScript src = psGo (splitOn '\n' src)

psGo :: List String -> List Step
psGo ls = case ls of
  Nil -> Nil
  Cons l rest ->
    let t = trim l in
    if strLen t == 0 || hasPrefix "#" t then psGo rest
    else Cons (psLine t (spaceAt t 0)) (psGo rest)

psLine :: String -> Int -> Step
psLine t i =
  if i < 0 then Step 0 t
  else Step (intOr 0 (substr 0 i t)) (trim (substr (i + 1) (strLen t - i - 1) t))

spaceAt :: String -> Int -> Int
spaceAt s i = if i >= strLen s then (0 - 1) else if charAt i s == ' ' then i else spaceAt s (i + 1)

-- the final status line (the headless tests assert on it)
statusLine :: Player -> Int -> Int -> Int -> String
statusLine p shown dropped shots =
  "frames=" ++ showInt shown ++ " dropped=" ++ showInt dropped ++ " shots=" ++ showInt shots ++ " pos=" ++ showInt (pos p)
  ++ " vol=" ++ showInt (vol p) ++ " muted=" ++ (if muted p then "1" else "0")
  ++ " speed=" ++ showInt (speed p) ++ " idx=" ++ showInt (idx p)
  ++ " sub=" ++ (if subOn p then "1" else "0") ++ " subdelay=" ++ showInt (subDelay p)
  ++ " loop=" ++ (if loopFile p then "1" else "0")
  ++ " zoom=" ++ showInt (zoom p) ++ " pan=" ++ showInt (panX p) ++ "," ++ showInt (panY p) ++ " rot=" ++ showInt (rot p)

-- ─── audio stream ────────────────────────────────────────────────────────────────────────────────
-- The PCM the player queues: signed 16-bit little-endian, stereo, 48 kHz → 192 bytes per ms.
pcmBytesPerMs :: Int
pcmBytesPerMs = 192

-- `speed` (percent) as an `atempo` factor: 110 → "1.10"
tempo :: Int -> String
tempo s = showInt (s / 100) ++ "." ++ pad2 (s - (s / 100) * 100)

-- the first audio stream as raw PCM from `seekMs` on, played at `speed`% (pitch kept). A file with
-- no audio makes ffmpeg exit at once: the pipe is empty and the player plays silently.
audioCmd :: String -> Int -> Int -> String
audioCmd f seekMs speed =
  "env -u LD_LIBRARY_PATH ffmpeg -nostdin -v error -ss " ++ secs seekMs ++ " -i " ++ shQuote f
  ++ " -vn -af " ++ atempoChain speed ++ " -f s16le -ac 2 -ar 48000 - 2>/dev/null"

-- `atempo` takes 0.5…100: a slower speed (down to 25%) is two filters in a row
atempoChain :: Int -> String
atempoChain s = if s < 50 then "atempo=0.50,atempo=" ++ tempo (s * 2) else "atempo=" ++ tempo s

-- ─── on-screen display ───────────────────────────────────────────────────────────────────────────
-- axmpv's own 5×7 font for printable ASCII: 7 characters per glyph, one per row, each row's 5 bits
-- (bit 4 = the leftmost column) stored as the character code 48 + bits.
osdFont :: String
osdFont = "00000004444404::00000:O:::O:4?D>5N4HI248C3<BD8EB=44000002488842842224804E>E40044O4400000<48000O00000000<<01248@0>ACEIA>4<4444>>A1248OO2421A>26:BO22O@N11A>68@NAA>O124888>AA>AA>>AA?12<0<<0<<00<<0<48248@84200O0O008421248>A12404>A1=EE>>AAOAAANAANAAN>A@@@A>LBAAABLO@@N@@OO@@N@@@>A@GAA?AAAOAAA>44444>72222B<ABDHDBA@@@@@@OAKEEAAAAAIECAA>AAAAA>NAAN@@@>AAAEB=NAANDBA?@@>11NO444444AAAAAA>AAAAA:4AAAEEE:AA:4:AAAA:4444O1248@O>88888>0@84210>22222>4:A0000000000O840000000>1?A?@@FIAAN00>@@A>11=CAA?00>AO@>698L8880?AA?1>@@FIAAA40<444>20622B<@@BDHDB<44444>00JEEAA00FIAAA00>AAA>00NAN@@00=C?1100FI@@@00?@>1N88L889600AAAC=00AAA:400AAEE:00A:4:A00AA?1>00O248O244844244444448442448008E200"

-- the 5 bits of row `r` (0 = top) of character code `c`; anything else draws as '?'
glyphRow :: Int -> Int -> Int
glyphRow c r = let k = if c >= 32 && c <= 126 then c - 32 else 31 in charAt (k * 7 + r) osdFont - 48

pow2 :: Int -> Int
pow2 n = if n <= 0 then 1 else 2 * pow2 (n - 1)

-- Text at (x, y) in `s`×`s` pixels: one rectangle per horizontal run of set pixels, so a line of
-- text is a few hundred rectangles drawn in one call. Glyphs advance 6 pixels (1 of spacing).
textRects :: String -> Int -> Int -> Int -> List Rect
textRects t x y s = trGo t 0 x y s

trGo :: String -> Int -> Int -> Int -> Int -> List Rect
trGo t i x y s =
  if i >= strLen t then Nil
  else glyphRects (charAt i t) 0 x y s (trGo t (i + 1) (x + 6 * s) y s)

glyphRects :: Int -> Int -> Int -> Int -> Int -> List Rect -> List Rect
glyphRects c r x y s acc =
  if r >= 7 then acc
  else runRects (glyphRow c r) 0 (0 - 1) x (y + r * s) s (glyphRects c (r + 1) x y s acc)

-- the runs of row bits `b` from column `col`; `start` = where the current run began (-1: none)
runRects :: Int -> Int -> Int -> Int -> Int -> Int -> List Rect -> List Rect
runRects b col start x y s acc =
  if col >= 5 then (if start >= 0 then Cons (Rect (x + start * s) y ((5 - start) * s) s) acc else acc)
  else if mod (b / pow2 (4 - col)) 2 == 1
    then runRects b (col + 1) (if start >= 0 then start else col) x y s acc
  else if start >= 0
    then Cons (Rect (x + start * s) y ((col - start) * s) s) (runRects b (col + 1) (0 - 1) x y s acc)
  else runRects b (col + 1) start x y s acc

textWidth :: String -> Int -> Int
textWidth t s = if strLen t == 0 then 0 else strLen t * 6 * s - s

-- the status line: play state, position / duration, volume, speed, the A-B loop
osdStatus :: Player -> String
osdStatus p =
  (if paused p then "||  " else ">   ") ++ fmtTime (pos p) ++ " / " ++ fmtTime (dur p)
  ++ "   " ++ (if muted p then "mute" else "vol " ++ showInt (vol p) ++ "%")
  ++ "   " ++ tempo (speed p) ++ "x"
  ++ (if loopB p >= 0 then "   A-B" else if loopA p >= 0 then "   A-" else "")
  ++ (if loopFile p then "   loop" else "")
  ++ (if zoom p /= 100 then "   zoom " ++ showInt (zoom p) ++ "%" else "")
  ++ (if panX p /= 0 || panY p /= 0 then "   pan" else "")
  ++ (if rot p /= 0 then "   rot " ++ showInt (rot p) else "")
  ++ (if not (subOn p) then "   sub off" else if subDelay p /= 0 then "   sub " ++ showInt (subDelay p) ++ "ms" else "")

-- the OSD's layers: a translucent backdrop (text box + bar track), the bar's fill, the text
-- (record fields: their selectors only read the value, so one Osd feeds all three draws)
data Osd = Osd { osdBack :: List Rect, osdFill :: List Rect, osdText :: List Rect }

-- The OSD for an `ow`×`oh` output: the status line (and, with `info` on, the `info` lines under
-- it) in a box at the top left, the progress bar along the bottom. Scaled with the output height.
osdLayout :: Player -> String -> Int -> Int -> Osd
osdLayout p info ow oh =
  let s = imax 2 (oh / 270) in
  let m = 4 * s in
  let ls = Cons (osdStatus p) (if infoOn p then lines info else Nil) in
  let boxW = linesWidth ls s + 2 * m in
  let boxH = length ls * 9 * s + 2 * m - 2 * s in
  let bh = 3 * s in
  let bw = imax 0 (ow - 4 * m) in
  let by = oh - 2 * m - bh in
  let fill = if dur p > 0 then clamp 0 bw (pos p * bw / dur p) else 0 in
  Osd { osdBack = Cons (Rect m m boxW boxH) (Cons (Rect (2 * m) by bw bh) Nil)
      , osdFill = (if fill > 0 then Cons (Rect (2 * m) by fill bh) Nil else Nil)
      , osdText = linesRects ls (2 * m) (2 * m) s }

linesWidth :: List String -> Int -> Int
linesWidth ls s = case ls of
  Nil -> 0
  Cons l rest -> imax (textWidth l s) (linesWidth rest s)

linesRects :: List String -> Int -> Int -> Int -> List Rect
linesRects ls x y s = case ls of
  Nil -> Nil
  Cons l rest -> rcat (textRects l x y s) (linesRects rest x (y + 9 * s) s)

rcat :: List Rect -> List Rect -> List Rect
rcat a b = case a of
  Nil -> b
  Cons r rest -> Cons r (rcat rest b)

-- ─── subtitle display ────────────────────────────────────────────────────────────────────────────
-- The font is ASCII, subtitles are UTF-8 with markup: drop `<i>`/`</b>`/`{\an8}`-style tags, fold the
-- Latin-1 letters to their base letter (`ação` → `acao`), typographic quotes/dashes/ellipsis to
-- ASCII, anything else to `?`.
subClean :: String -> String
subClean t = scClean t 0 (strLen t)

scClean :: String -> Int -> Int -> String
scClean t i n =
  if i >= n then ""
  else let c = charAt i t in
       if c == '<' then scClean t (closeAt t (i + 1) n '>' + 1) n
       else if c == '{' then scClean t (closeAt t (i + 1) n '}' + 1) n
       else if c == '\r' then scClean t (i + 1) n
       else if c < 128 then chr c ++ scClean t (i + 1) n
       else if c == 195 && i + 1 < n then latin1 (charAt (i + 1) t) ++ scClean t (i + 2) n
       else if c == 194 && i + 1 < n then latinPunct (charAt (i + 1) t) ++ scClean t (i + 2) n
       else if c == 226 && i + 2 < n then generalPunct (charAt (i + 1) t) (charAt (i + 2) t) ++ scClean t (i + 3) n
       else if c >= 240 then "?" ++ scClean t (i + 4) n
       else if c >= 224 then "?" ++ scClean t (i + 3) n
       else if c >= 192 then "?" ++ scClean t (i + 2) n
       else scClean t (i + 1) n                                      -- a stray continuation byte

-- the index of the first `close` from `i` (or the end)
closeAt :: String -> Int -> Int -> Int -> Int
closeAt t i n close = if i >= n then n else if charAt i t == close then i else closeAt t (i + 1) n close

-- U+00C0..U+00FF (UTF-8 C3 80..BF) → ASCII
latin1 :: Int -> String
latin1 b =
  let k = b - 128 in
  if k < 0 || k > 63 then "?"
  else substr k 1 "AAAAAAACEEEEIIIIDNOOOOOxOUUUUYTsaaaaaaaceeeeiiiidnooooo/ouuuuyty"

-- U+00A0..U+00BF (C2 A0..BF): «» → ", ° → o, a no-break space → space
latinPunct :: Int -> String
latinPunct b =
  if b == 171 || b == 187 then "\"" else if b == 176 then "o" else if b == 160 then " " else "?"

-- U+2013/2014 dashes, U+2018/2019 and U+201C/201D quotes, U+2026 ellipsis (E2 80 xx)
generalPunct :: Int -> Int -> String
generalPunct b1 b2 =
  if b1 /= 128 then "?"
  else if b2 == 147 || b2 == 148 then "-"
  else if b2 == 152 || b2 == 153 then "'"
  else if b2 == 156 || b2 == 157 then "\""
  else if b2 == 166 then "..."
  else "?"

-- Lines wrapped at `n` characters, on spaces (a longer single word stays whole).
wrapAll :: List String -> Int -> List String
wrapAll ls n = case ls of
  Nil -> Nil
  Cons l rest -> rcatS (wrapWords (splitOn ' ' (trim l)) "" n) (wrapAll rest n)

wrapWords :: List String -> String -> Int -> List String
wrapWords ws cur n = case ws of
  Nil -> if strLen cur > 0 then Cons cur Nil else Nil
  Cons w rest ->
    if strLen w == 0 then wrapWords rest cur n
    else if strLen cur == 0 then wrapWords rest (dup w) n
    else if strLen cur + 1 + strLen w <= n then wrapWords rest (cur ++ " " ++ w) n
    else Cons cur (wrapWords rest (dup w) n)

rcatS :: List String -> List String -> List String
rcatS a b = case a of
  Nil -> b
  Cons s rest -> Cons s (rcatS rest b)

-- The subtitle `text` for an `ow`×`oh` output: its lines wrapped and centred in a translucent box
-- above the progress bar, larger than the OSD.
subLayout :: String -> Int -> Int -> Osd
subLayout text ow oh =
  let s = imax 2 (oh / 200) in
  let m = 4 * s in
  let ls = wrapAll (lines (subClean text)) (imax 8 ((ow - 8 * m) / (6 * s))) in
  let n = length ls in
  let lh = 9 * s in
  let top = oh - 8 * m - n * lh in
  let wmax = linesWidth ls s in
  Osd { osdBack = (if n == 0 then Nil else Cons (Rect ((ow - wmax) / 2 - m) (top - m) (wmax + 2 * m) (n * lh + 2 * m - 2 * s)) Nil)
      , osdFill = Nil
      , osdText = centredRects ls ow top s }

centredRects :: List String -> Int -> Int -> Int -> List Rect
centredRects ls ow y s = case ls of
  Nil -> Nil
  Cons l rest -> rcat (textRects l ((ow - textWidth l s) / 2) y s) (centredRects rest ow (y + 9 * s) s)

-- the text showing at position `ms` with the player's delay (mpv: a positive delay shows each
-- subtitle later), "" when subtitles are off
subtitleNow :: Array Cue -> Player -> String
subtitleNow cues p = if subOn p then subtitleAt cues (pos p - subDelay p) else ""

-- the `.srt` beside a video: its extension replaced (or appended when it has none)
srtPathFor :: String -> String
srtPathFor f =
  let d = lastDot f (strLen f - 1) in
  if d < 0 then f ++ ".srt" else substr 0 d f ++ ".srt"

lastDot :: String -> Int -> Int
lastDot f i = if i < 0 then (0 - 1) else if charAt i f == '/' then (0 - 1) else if charAt i f == '.' then i else lastDot f (i - 1)

-- ─── screenshots ─────────────────────────────────────────────────────────────────────────────────
-- `axmpv-shot-0001.ppm`, `…0002.ppm`, …: the screenshot files, numbered from 1 in the working
-- directory (the player takes the first that does not exist yet)
shotName :: Int -> String
shotName k = "axmpv-shot-" ++ pad4 k ++ ".ppm"

pad4 :: Int -> String
pad4 n = if n < 1000 then "0" ++ pad3 n else showInt n

-- the binary PPM header of a `w`×`h` RGB image
ppmHeader :: Int -> Int -> String
ppmHeader w h = "P6\n" ++ showInt w ++ " " ++ showInt h ++ "\n255\n"
