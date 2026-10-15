#!/usr/bin/env sh
# fff.axi shell wrapper — source this from your shell rc (`. /path/to/fff-wrapper.sh`).
#
# It does two things the Axión binary cannot do for itself:
#   1. cd-on-quit: fff writes its final directory to ~/.cache/fff/fff.d; a running program
#      cannot change its parent shell's cwd, so the wrapper reads that file and cd's for you.
#   2. Safe teardown: fff enters the alt-screen, hides the cursor and sets `stty -echo -icanon`.
#      A clean `q`/EOF restores all of that, but a SIGINT/SIGTERM/kill or a crash would otherwise
#      leave your terminal in the alt-screen with echo off. The `trap` below always restores it.
#
# Point FFF_BIN at the built binary (axionc --release -o fff examples/fff.axi), or put `fff` on PATH.

: "${FFF_BIN:=fff}"

fff() {
	# Restore the terminal no matter how fff exits (clean, signalled, or crashed).
	trap 'stty sane 2>/dev/null; printf "\033[?25h\033[2J\033[?1049l"' INT TERM EXIT

	command "$FFF_BIN" "$@"

	trap - INT TERM EXIT

	# cd to wherever fff left off.
	_fff_d="${HOME:-.}/.cache/fff/fff.d"
	if [ -f "$_fff_d" ]; then
		_fff_dir="$(cat "$_fff_d")"
		[ -d "$_fff_dir" ] && cd "$_fff_dir" || true
	fi
	unset _fff_d _fff_dir
}
