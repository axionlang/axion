-- axmpv CoreTest — prints the results of the pure player logic (Core.axi) on fixed inputs. Run on the
-- interpreter, `--backend cranelift` and `--release`: the outputs must be identical (scripts/
-- axmpv-test.sh), and the native runs ASan/LSan-clean. Any difference is a compiler bug.
import Core

showB :: Bool -> String
showB b = if b then "T" else "F"

showP :: Player -> String
showP p =
  "pos=" ++ showInt (pos p) ++ " vol=" ++ showInt (vol p) ++ " mute=" ++ showB (muted p)
  ++ " pause=" ++ showB (paused p) ++ " speed=" ++ showInt (speed p)
  ++ " ab=" ++ showInt (loopA p) ++ "/" ++ showInt (loopB p) ++ " sub=" ++ showB (subOn p)
  ++ "/" ++ showInt (subDelay p) ++ " idx=" ++ showInt (idx p) ++ " eff=" ++ showInt (effect p)
  ++ "@" ++ showInt (seekTo p)

showProbe :: Probe -> String
showProbe p =
  showInt (pw p) ++ "x" ++ showInt (ph p) ++ " " ++ showInt (fpsN p) ++ "/" ++ showInt (fpsD p)
  ++ " " ++ showInt (durMs p) ++ "ms"

-- apply a sequence of actions, printing the state after each
runAll :: List String -> Player -> IO ()
runAll names p = case names of
  Nil -> putStrLn ("final " ++ showP p)
  Cons n rest -> do
    let q = settled (runAction n p)
    putStrLn (n ++ ": " ++ showP (runAction n p))
    runAll rest q

showCues :: List Cue -> Int -> IO ()
showCues cs i = case cs of
  Nil -> putStrLn ("cues: " ++ showInt i)
  Cons c rest -> do
    putStrLn ("cue " ++ showInt (cueStart c) ++ "-" ++ showInt (cueEnd c) ++ " [" ++ cueText c ++ "]")
    showCues rest (i + 1)

showRect :: Rect -> String
showRect r = showInt (rx r) ++ "," ++ showInt (ry r) ++ "," ++ showInt (rw r) ++ "x" ++ showInt (rh r)

showRects :: List Rect -> String
showRects rs = case rs of
  Nil -> ""
  Cons r rest -> "[" ++ showRect r ++ "]" ++ showRects rest

showLines :: List String -> String
showLines ls = case ls of
  Nil -> ""
  Cons l rest -> "<" ++ l ++ ">" ++ showLines rest

showSteps :: List Step -> IO ()
showSteps ss = case ss of
  Nil -> putStrLn "end"
  Cons s rest -> do
    putStrLn (showInt (stepAt s) ++ " [" ++ stepAction s ++ "]")
    showSteps rest

-- the text as 7 rows of '#'/'.' art, straight from the font
art :: String -> Int -> String
art t r = if r >= 7 then "" else artRow t 0 r ++ "\n" ++ art t (r + 1)

artRow :: String -> Int -> Int -> String
artRow t i r = if i >= strLen t then "" else artBits (glyphRow (charAt i t) r) 0 ++ "." ++ artRow t (i + 1) r

artBits :: Int -> Int -> String
artBits b c = if c >= 5 then "" else (if mod (b / pow2 (4 - c)) 2 == 1 then "#" else ".") ++ artBits b (c + 1)

-- set pixels of the text (the area textRects must cover at scale 1)
litPixels :: String -> Int -> Int
litPixels t i = if i >= strLen t then 0 else glyphLit (charAt i t) 0 + litPixels t (i + 1)

glyphLit :: Int -> Int -> Int
glyphLit c r = if r >= 7 then 0 else bitCount (glyphRow c r) + glyphLit c (r + 1)

bitCount :: Int -> Int
bitCount b = if b <= 0 then 0 else mod b 2 + bitCount (b / 2)

area :: List Rect -> Int
area rs = case rs of
  Nil -> 0
  Cons r rest -> rw r * rh r + area rest

count :: List Rect -> Int
count rs = case rs of
  Nil -> 0
  Cons _ rest -> 1 + count rest

srtSample :: String
srtSample = "1\n00:00:01,000 --> 00:00:02,500\nHello\n\n2\n00:00:03,000 --> 00:00:04,250\nTwo\nlines\n\n3\n00:01:02,345 --> 00:01:03,000\nlast"

keymapSample :: String
keymapSample = "dd\t!rm %s\nC-<Right>\tseek_forward_long\n\x01volume\t70\nS\tscreenshot"

main :: IO ()
main = do
  putStrLn (fmtTime 0 ++ " " ++ fmtTime 61999 ++ " " ++ fmtTime 3723000 ++ " " ++ fmtTime (0 - 5))
  putStrLn (showInt (parseMs "4.000000") ++ " " ++ showInt (parseMs "12.5") ++ " " ++ showInt (parseMs "N/A"))
  putStrLn (showProbe (parseProbe "320,240,25/1\n4.000000\n"))
  putStrLn (showProbe (parseProbe "1920,1080,30000/1001\n61.250000"))
  putStrLn (showProbe (parseProbe ""))
  let pr = parseProbe "640,360,24/1\n10.0"
  putStrLn (showInt (frameMs pr 0) ++ " " ++ showInt (frameMs pr 24) ++ " " ++ showInt (frameAt pr 1500))
  runAll ["volume_up", "volume_down", "mute", "pause", "speed_up", "speed_down", "speed_reset", "seek_forward", "seek_backward", "ab_loop", "ab_loop", "ab_loop", "sub_toggle", "sub_delay_up", "playlist_next", "playlist_prev", "playlist_prev", "nonsense", "quit"] ((newPlayer 3) { dur = 60000, pos = 2000 })
  putStrLn (showP (loopCheck ((newPlayer 1) { loopA = 1000, loopB = 3000, pos = 3500 })))
  putStrLn (keyToken 1073741903 0 ++ " " ++ keyToken 1073741903 64 ++ " " ++ keyToken 97 1 ++ " " ++ keyToken 44 2 ++ " " ++ keyToken 109 256 ++ "|" ++ keyToken 1 0 ++ "|")
  putStrLn (defaultAction "<Space>" ++ " " ++ defaultAction "]" ++ " " ++ defaultAction "q" ++ " [" ++ defaultAction "Z" ++ "]")
  putStrLn (lookupAction keymapSample "dd" ++ " | " ++ lookupAction keymapSample "C-<Right>" ++ " | " ++ optionOr keymapSample "volume" "100" ++ " | " ++ optionOr keymapSample "speed" "100")
  putStrLn (showB (isProperPrefix keymapSample "d") ++ showB (isProperPrefix keymapSample "dd") ++ showB (isAction "mute") ++ showB (isAction "nope"))
  putStrLn (userCmd "/tmp/it's a.mkv" 61500 "cp %s /x/%t.mkv")
  showCues (parseSrt srtSample) 0
  let cues = cueArray (parseSrt srtSample)
  putStrLn ("[" ++ subtitleAt cues 500 ++ "] [" ++ subtitleAt cues 1000 ++ "] [" ++ subtitleAt cues 3500 ++ "] [" ++ subtitleAt cues 62400 ++ "] [" ++ subtitleAt cues 70000 ++ "]")
  putStrLn (showInt (scaleSample 1000 50) ++ " " ++ showInt (scaleSample 65535 200) ++ " " ++ showInt (scaleSample 30000 130) ++ " " ++ showInt (scaleSample 40000 130) ++ " " ++ showInt (scaleSample 12345 0))
  putStrLn (secs 0 ++ " " ++ secs 1500 ++ " " ++ secs 61005 ++ " | " ++ videoCmd "/a b/c.mkv" 2500)
  putStrLn (showRect (fitRect 320 240 800 600) ++ " " ++ showRect (fitRect 1920 1080 800 600) ++ " " ++ showRect (fitRect 100 400 800 600) ++ " " ++ showRect (fitRect 0 0 800 600))
  showSteps (parseScript "# test\n500 pause\n\n1500  seek_forward \n2000 quit")
  putStrLn (statusLine ((newPlayer 2) { pos = 1234, muted = True }) 99 3 1)
  putStrLn (tempo 100 ++ " " ++ tempo 110 ++ " " ++ tempo 99 ++ " " ++ tempo 205 ++ " " ++ atempoChain 30 ++ " | " ++ audioCmd "x.mkv" 1500 110)
  putStrLn (keyAction keymapSample "" "d" ++ "|" ++ keyPending keymapSample "" "d" ++ "|" ++ keyAction keymapSample "d" "d" ++ "|" ++ keyAction keymapSample "d" "q" ++ "|" ++ keyAction keymapSample "" "S" ++ "|" ++ keyAction keymapSample "" "m")
  putStrLn (showP (configured "\x01volume\t70\n\x01speed\t150\n\x01fullscreen\tyes\n\x01subtitles\tno" (newPlayer 1)) ++ " full=" ++ showB (fullscreen (configured "\x01fullscreen\tyes" (newPlayer 1))))
  putStr (art "axmpv 12:34%" 0)
  let sample = "> 00:01:23 / 00:04:56  vol 70%  1.10x  The quick brown fox {[(@#$&*)]} ~^_|\\"
  putStrLn (showInt (litPixels sample 0) ++ " " ++ showInt (area (textRects sample 0 0 1)) ++ " " ++ showInt (area (textRects sample 10 20 3)) ++ " rects=" ++ showInt (count (textRects sample 0 0 1)))
  let o = osdLayout ((newPlayer 1) { pos = 30000, dur = 120000, vol = 70, speed = 110, infoOn = True }) "clip.mkv\n320x240 25.00 fps" 960 540
  putStrLn (osdStatus ((newPlayer 1) { pos = 61000, dur = 3723000, paused = True, muted = True, loopA = 100 }))
  putStrLn ("back " ++ showRects (osdBack o) ++ " fill " ++ showRects (osdFill o) ++ " text rects=" ++ showInt (count (osdText o)))
  putStrLn (subClean "<i>Ação</i> {\\an8}não, «é» — “sim”… ½ 日本\r")
  putStrLn (showLines (wrapAll (lines "the quick brown fox jumps over the lazy dog\nsecond line") 16))
  let sl = subLayout "Olá, mundo!\nsegunda linha" 960 540
  putStrLn ("sub back " ++ showRects (osdBack sl) ++ " text rects=" ++ showInt (count (osdText sl)) ++ " empty=" ++ showInt (count (osdBack (subLayout "" 960 540))))
  putStrLn ("[" ++ subtitleNow cues ((newPlayer 1) { pos = 3500 }) ++ "] [" ++ subtitleNow cues ((newPlayer 1) { pos = 3500, subDelay = 2600 }) ++ "] [" ++ subtitleNow cues ((newPlayer 1) { pos = 3500, subOn = False }) ++ "]")
  putStrLn (srtPathFor "/a/b.c/movie.mkv" ++ " " ++ srtPathFor "/a/b.c/movie" ++ " " ++ srtPathFor "clip.x.mp4")
  putStrLn (osdStatus ((newPlayer 1) { subDelay = 0 - 300 }) ++ " |" ++ osdStatus ((newPlayer 1) { subOn = False }))
  putStrLn (shotName 1 ++ " " ++ shotName 42 ++ " " ++ shotName 1234 ++ " [" ++ ppmHeader 320 240 ++ "]")
  putStrLn (showP (loopCheck ((newPlayer 1) { loopA = 1000, loopB = 2000, pos = 1500 })) ++ " | " ++ showP (loopCheck ((newPlayer 1) { loopA = 1000, loopB = 2000, pos = 2000 })))
  putStrLn (defaultAction "L" ++ " " ++ defaultAction "l" ++ " " ++ showB (loopFile (runAction "loop_file" (newPlayer 1))) ++ showB (loopFile (runAction "loop_file" (runAction "loop_file" (newPlayer 1)))) ++ " " ++ showB (loopFile (configured "\x01loop\tyes" (newPlayer 1))) ++ showB (loopFile (configured "" (newPlayer 1))))
  putStrLn (osdStatus ((newPlayer 1) { loopFile = True }))
  let zp = runAction "pan_right" (runAction "zoom_in" (runAction "zoom_in" (newPlayer 1)))
  putStrLn (showRect (viewRect (newPlayer 1) 320 240 800 600) ++ " " ++ showRect (viewRect zp 320 240 800 600) ++ " " ++ showRect (viewRect (runAction "rotate" (newPlayer 1)) 320 240 800 600) ++ " " ++ showRect (viewRect (runAction "fit" zp) 320 240 800 600))
  putStrLn (showInt (zoom (runAction "zoom_out" (newPlayer 1))) ++ " " ++ showInt (rot (runAction "rotate_ccw" (newPlayer 1))) ++ " " ++ defaultAction "M-<Left>" ++ " " ++ defaultAction "M-+" ++ " " ++ defaultAction "M-<BS>" ++ " " ++ defaultAction "r" ++ " " ++ defaultAction "R")
  putStrLn (osdStatus zp)
  let cp = configured "\x01zoom_step\t25\n\x01pan_step\t10" (newPlayer 1)
  putStrLn (showInt (zoom (runAction "zoom_in" cp)) ++ " " ++ showInt (zoom (runAction "zoom_out" cp)) ++ " " ++ showRect (viewRect (runAction "pan_right" cp) 320 240 800 600) ++ " " ++ showInt (zoomStep (configured "" (newPlayer 1))) ++ "/" ++ showInt (panStep (configured "" (newPlayer 1))) ++ " " ++ showInt (zoomStep (configured "\x01zoom_step\t999" (newPlayer 1))))
  -- an option row next to a key row for `=`: `=` is an ordinary key (it was taken for the prefix of `=zoom_step`)
  putStrLn ("[" ++ keyAction "\x01zoom_step\t25\n=\tfit" "" "=" ++ "] [" ++ keyPending "\x01zoom_step\t25" "" "=" ++ "] [" ++ keyAction "\x01zoom_step\t25" "" "=" ++ "]")
