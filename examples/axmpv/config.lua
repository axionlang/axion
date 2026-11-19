-- axmpv configuration — copy to ~/.config/axmpv/config.lua.
--
-- Read once at start-up. Two kinds of rows, one per line:
--
--   { key = "K", action = "A" }     bind key sequence K to action A
--   { option = "O", value = "V" }   set option O
--
-- KEYS are written as tokens, one after another for a sequence (`gg`): a printable character
-- (`a`, `A`, `<`, `?` — shifted keys as the glyph on a US keyboard), a special key (`<Space>`,
-- `<Enter>`, `<Esc>`, `<Tab>`, `<BS>`, `<Left>`, `<Right>`, `<Up>`, `<Down>`, `<Home>`, `<End>`),
-- optionally after a modifier prefix `C-` (Ctrl) or `M-` (Alt): `C-<Right>`, `M-m`.
-- A key bound here REPLACES its default below; every other key keeps its default.
--
-- ACTIONS are the built-in names
--   pause  seek_forward  seek_backward  seek_forward_long  seek_backward_long
--   volume_up  volume_down  mute  speed_up  speed_down  speed_reset
--   fullscreen  osd  info  screenshot  sub_toggle  sub_delay_up  sub_delay_down
--   ab_loop  loop_file                                  loops: a section (A-B) / the whole file
--   zoom_in  zoom_out  fit  pan_left  pan_right  pan_up  pan_down  rotate  rotate_ccw
--   playlist_next  playlist_prev  quit
-- or `!command`, run by the shell with `%s` = the current file (quoted) and `%t` = the position
-- in seconds; its output is discarded.
--
-- DEFAULT KEYS (mpv's):
--   <Space> p  pause          <Left> <Right>  seek 5 s     <Up> <Down>  seek 60 s
--   9 /  0 *   volume -/+     m  mute         [ ]  speed ×0.9/×1.1      <BS>  speed 1×
--   f  fullscreen   o <Tab>  OSD always on   i  info      s  screenshot
--   l  A-B loop (set A, set B, clear)        L  loop the whole file
--   v  subtitles on/off       z x  subtitle delay -/+100 ms
--   M-<Left> M-<Right> M-<Up> M-<Down>  pan     M-+ M-=  zoom in   M--  zoom out
--   M-<BS>  fit (reset zoom + pan, keep the rotation)                r R  rotate 90° / back
--   < >  playlist prev/next   <Enter>  next   q <Esc>  quit
--
-- OPTIONS:
--   volume      0–130 (percent)                    speed       25–400 (percent)
--   fullscreen  "yes"/"no"                         subtitles   "yes"/"no" (shown at start)
--   osd         "yes"/"no" (status always shown)   loop        "yes"/"no" (loop each file, like L)
--   zoom_step   1–100: percent each zoom press grows/shrinks the picture (default 10: ×1.10)
--   pan_step    1–50: percent of the window each pan press moves it (default 5)

local config = {
  -- options
  { option = "volume", value = "80" },
  { option = "subtitles", value = "yes" },
  { option = "loop", value = "no" },                       -- "yes": every file starts over at its end
  { option = "zoom_step", value = "10" },                  -- zoom: ×1.10 per press
  { option = "pan_step", value = "5" },                    -- pan: 5% of the window per press

  -- seeking, vim-style
  { key = "l",         action = "seek_forward" },
  { key = "h",         action = "seek_backward" },
  { key = "K",         action = "seek_forward_long" },     -- (L stays loop_file)
  { key = "J",         action = "seek_backward_long" },

  -- loops: `a` for the A-B section (`l` is taken above), `L` keeps its default: the whole file
  { key = "a",         action = "ab_loop" },

  -- view: zoom, pan, rotate (aximv's names; these keys are free, so playback keys stay as they are)
  { key = "+",         action = "zoom_in" },
  { key = "-",         action = "zoom_out" },
  { key = "=",         action = "fit" },                   -- reset zoom + pan
  { key = "C-<Left>",  action = "pan_left" },
  { key = "C-<Right>", action = "pan_right" },
  { key = "C-<Up>",    action = "pan_up" },
  { key = "C-<Down>",  action = "pan_down" },
  -- rotation keeps its defaults: r = clockwise, R = anti-clockwise

  -- shell commands
  { key = "gg",        action = "!echo %t >> ~/axmpv-marks.txt" },  -- note the position
  { key = "dd",        action = "!notify-send axmpv %s" },
}

return config
