#!/usr/bin/env sh
# Run the Axión axmpv video player with SDL2 on the dynamic-loader path.
#
# axmpv's `foreign "libSDL2.so" …` dlopens by soname; on NixOS there is no ldconfig cache, so the
# SDL libraries must be on LD_LIBRARY_PATH. This wrapper resolves them (via nix, unless you pass
# the dirs in AXMPV_SDL_LIBS) and runs the player.
#
#   scripts/axmpv-run.sh video.mkv other.mp4
#   AXMPV_SDL_LIBS=/path/to/SDL2/lib scripts/axmpv-run.sh video.mkv
#
# Set AXMPV_BIN to a prebuilt binary (axionc --release -o axmpv examples/axmpv/axmpv.axi); otherwise this
# runs via the interpreter-less native path with `axionc --backend cranelift`.
set -eu

: "${AXMPV_BIN:=}"
: "${AXIONC:=axionc}"

if [ -z "${AXMPV_SDL_LIBS:-}" ]; then
	# nixpkgs' SDL2 is sdl2-compat, which loads SDL3 at run time: both go on the path
	s2=$(nix build --no-link --print-out-paths nixpkgs#SDL2 2>/dev/null || true)
	s3=$(nix build --no-link --print-out-paths nixpkgs#sdl3.lib 2>/dev/null || true)
	if [ -z "$s2" ]; then
		echo "axmpv-run: could not resolve SDL2 via nix — set AXMPV_SDL_LIBS to its lib dir" >&2
		exit 1
	fi
	AXMPV_SDL_LIBS="$s2/lib${s3:+:$s3/lib}"
fi

export LD_LIBRARY_PATH="${AXMPV_SDL_LIBS}${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

# AXMPV_BUILD=1: build a standalone `-o axmpv` binary first. The linker resolves the `libSDL2.so`
# sonames via LIBRARY_PATH (clang `-l:`), mirroring the LD_LIBRARY_PATH used at runtime.
if [ "${AXMPV_BUILD:-}" = 1 ]; then
	: "${AXMPV_BIN:=./axmpv}"
	LIBRARY_PATH="${AXMPV_SDL_LIBS}${LIBRARY_PATH:+:$LIBRARY_PATH}" \
		"$AXIONC" -o "$AXMPV_BIN" examples/axmpv/axmpv.axi
fi

if [ -n "$AXMPV_BIN" ]; then
	exec "$AXMPV_BIN" -- "$@"
else
	exec "$AXIONC" --backend cranelift examples/axmpv/axmpv.axi -- "$@"
fi
