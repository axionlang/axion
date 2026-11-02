#!/usr/bin/env sh
# Run the Axión imv image viewer with SDL2 + SDL2_image on the dynamic-loader path.
#
# imv's `foreign "libSDL2.so" …` dlopens by soname; on NixOS there is no ldconfig cache, so the
# SDL libraries must be on LD_LIBRARY_PATH. This wrapper resolves them (via nix, unless you pass
# the dirs in IMV_SDL_LIBS) and runs the viewer.
#
#   scripts/imv-run.sh *.png
#   IMV_SDL_LIBS=/path/to/SDL2/lib:/path/to/SDL2_image/lib scripts/imv-run.sh pic.jpg
#
# Set IMV_BIN to a prebuilt binary (axionc --release -o imv examples/imv.axi); otherwise this
# runs via the interpreter-less native path with `axionc --backend cranelift`.
set -eu

: "${IMV_BIN:=}"
: "${AXIONC:=axionc}"

if [ -z "${IMV_SDL_LIBS:-}" ]; then
	s2=$(nix build --no-link --print-out-paths nixpkgs#SDL2 2>/dev/null || true)
	si=$(nix build --no-link --print-out-paths nixpkgs#SDL2_image 2>/dev/null || true)
	if [ -z "$s2" ] || [ -z "$si" ]; then
		echo "imv-run: could not resolve SDL2/SDL2_image via nix — set IMV_SDL_LIBS to their lib dirs" >&2
		exit 1
	fi
	IMV_SDL_LIBS="$s2/lib:$si/lib"
fi

export LD_LIBRARY_PATH="${IMV_SDL_LIBS}${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

# IMV_BUILD=1: build a standalone `-o imv` binary first. The linker resolves the `libSDL2.so`
# sonames via LIBRARY_PATH (clang `-l:`), mirroring the LD_LIBRARY_PATH used at runtime.
if [ "${IMV_BUILD:-}" = 1 ]; then
	: "${IMV_BIN:=./imv}"
	LIBRARY_PATH="${IMV_SDL_LIBS}${LIBRARY_PATH:+:$LIBRARY_PATH}" \
		"$AXIONC" -o "$IMV_BIN" examples/imv.axi
fi

if [ -n "$IMV_BIN" ]; then
	exec "$IMV_BIN" -- "$@"
else
	exec "$AXIONC" --backend cranelift examples/imv.axi -- "$@"
fi
