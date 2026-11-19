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

showSteps :: List Step -> IO ()
showSteps ss = case ss of
  Nil -> putStrLn "end"
  Cons s rest -> do
    putStrLn (showInt (stepAt s) ++ " [" ++ stepAction s ++ "]")
    showSteps rest

srtSample :: String
srtSample = "1\n00:00:01,000 --> 00:00:02,500\nHello\n\n2\n00:00:03,000 --> 00:00:04,250\nTwo\nlines\n\n3\n00:01:02,345 --> 00:01:03,000\nlast"

keymapSample :: String
keymapSample = "dd\t!rm %s\nC-<Right>\tseek_forward_long\n=volume\t70\nS\tscreenshot"

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
  putStrLn (statusLine ((newPlayer 2) { pos = 1234, muted = True }) 99 3)
  putStrLn (tempo 100 ++ " " ++ tempo 110 ++ " " ++ tempo 99 ++ " " ++ tempo 205 ++ " " ++ atempoChain 30 ++ " | " ++ audioCmd "x.mkv" 1500 110)
  putStrLn (keyAction keymapSample "" "d" ++ "|" ++ keyPending keymapSample "" "d" ++ "|" ++ keyAction keymapSample "d" "d" ++ "|" ++ keyAction keymapSample "d" "q" ++ "|" ++ keyAction keymapSample "" "S" ++ "|" ++ keyAction keymapSample "" "m")
  putStrLn (showP (configured "=volume\t70\n=speed\t150\n=fullscreen\tyes\n=subtitles\tno" (newPlayer 1)) ++ " full=" ++ showB (fullscreen (configured "=fullscreen\tyes" (newPlayer 1))))
