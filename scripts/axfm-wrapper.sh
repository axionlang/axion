#!/usr/bin/env sh
# axfm.axi shell wrapper — source this from your shell rc (`. /path/to/axfm-wrapper.sh`).
#
# It does two things the Axión binary cannot do for itself:
#   1. cd-on-quit: axfm writes its final directory to ~/.cache/axfm/axfm.d; a running program
#      cannot change its parent shell's cwd, so the wrapper reads that file and cd's for you.
#   2. Safe teardown: axfm enters the alt-screen, hides the cursor and sets `stty -echo -icanon`.
#      A clean `q`/EOF restores all of that, but a SIGINT/SIGTERM/kill or a crash would otherwise
#      leave your terminal in the alt-screen with echo off. The `trap` below always restores it.
#
# Point AXFM_BIN at the built binary (axionc --release -o axfm examples/axfm.axi), or put `axfm` on PATH.
# Keybindings are configurable in ~/.config/axfm/config.lua (see examples/axfm-config.lua).

: "${AXFM_BIN:=axfm}"

axfm() {
	# Restore the terminal no matter how axfm exits (clean, signalled, or crashed).
	trap 'stty sane 2>/dev/null; printf "\033[?25h\033[2J\033[?1049l"' INT TERM EXIT

	command "$AXFM_BIN" "$@"

	trap - INT TERM EXIT

	# cd to wherever axfm left off.
	_axfm_d="${HOME:-.}/.cache/axfm/axfm.d"
	if [ -f "$_axfm_d" ]; then
		_axfm_dir="$(cat "$_axfm_d")"
		[ -d "$_axfm_dir" ] && cd "$_axfm_dir" || true
	fi
	unset _axfm_d _axfm_dir
}
