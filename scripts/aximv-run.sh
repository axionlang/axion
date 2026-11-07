#!/usr/bin/env sh
# Run the Axión aximv image viewer with SDL2 + SDL2_image on the dynamic-loader path.
#
# aximv's `foreign "libSDL2.so" …` dlopens by soname; on NixOS there is no ldconfig cache, so the
# SDL libraries must be on LD_LIBRARY_PATH. This wrapper resolves them (via nix, unless you pass
# the dirs in AXIMV_SDL_LIBS) and runs the viewer.
#
#   scripts/aximv-run.sh *.png
#   AXIMV_SDL_LIBS=/path/to/SDL2/lib:/path/to/SDL2_image/lib scripts/aximv-run.sh pic.jpg
#
# Set AXIMV_BIN to a prebuilt binary (axionc --release -o aximv examples/aximv.axi); otherwise this
# runs via the interpreter-less native path with `axionc --backend cranelift`.
set -eu

: "${AXIMV_BIN:=}"
: "${AXIONC:=axionc}"

if [ -z "${AXIMV_SDL_LIBS:-}" ]; then
	s2=$(nix build --no-link --print-out-paths nixpkgs#SDL2 2>/dev/null || true)
	si=$(nix build --no-link --print-out-paths nixpkgs#SDL2_image 2>/dev/null || true)
	if [ -z "$s2" ] || [ -z "$si" ]; then
		echo "aximv-run: could not resolve SDL2/SDL2_image via nix — set AXIMV_SDL_LIBS to their lib dirs" >&2
		exit 1
	fi
	AXIMV_SDL_LIBS="$s2/lib:$si/lib"
fi

export LD_LIBRARY_PATH="${AXIMV_SDL_LIBS}${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

# AXIMV_BUILD=1: build a standalone `-o aximv` binary first. The linker resolves the `libSDL2.so`
# sonames via LIBRARY_PATH (clang `-l:`), mirroring the LD_LIBRARY_PATH used at runtime.
if [ "${AXIMV_BUILD:-}" = 1 ]; then
	: "${AXIMV_BIN:=./aximv}"
	LIBRARY_PATH="${AXIMV_SDL_LIBS}${LIBRARY_PATH:+:$LIBRARY_PATH}" \
		"$AXIONC" -o "$AXIMV_BIN" examples/aximv.axi
fi

if [ -n "$AXIMV_BIN" ]; then
	exec "$AXIMV_BIN" -- "$@"
else
	exec "$AXIONC" --backend cranelift examples/aximv.axi -- "$@"
fi
