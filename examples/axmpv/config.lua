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
-- A key bound here replaces mpv's default for it; every other key keeps its default.
--
-- ACTIONS are the built-in names
--   pause  seek_forward  seek_backward  seek_forward_long  seek_backward_long
--   volume_up  volume_down  mute  speed_up  speed_down  speed_reset
--   fullscreen  osd  info  screenshot  ab_loop  sub_toggle  sub_delay_up  sub_delay_down
--   playlist_next  playlist_prev  quit
-- or `!command`, run by the shell with `%s` = the current file (quoted) and `%t` = the position
-- in seconds; its output is discarded.
--
-- OPTIONS: volume (0–150), speed (25–400, percent), fullscreen / subtitles / osd ("yes"/"no").

local config = {
  { option = "volume", value = "80" },
  { option = "subtitles", value = "yes" },

  { key = "l",         action = "seek_forward" },          -- vim-style seeking
  { key = "h",         action = "seek_backward" },
  { key = "L",         action = "seek_forward_long" },
  { key = "H",         action = "seek_backward_long" },
  { key = "C-<Right>", action = "playlist_next" },
  { key = "C-<Left>",  action = "playlist_prev" },
  { key = "a",         action = "ab_loop" },               -- `l` is taken above
  { key = "gg",        action = "!echo %t >> ~/axmpv-marks.txt" },  -- note the position
  { key = "dd",        action = "!notify-send axmpv %s" },
}

return config
