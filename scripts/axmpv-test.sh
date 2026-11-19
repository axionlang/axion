#!/usr/bin/env bash
# Gate for the axmpv flagship (examples/axmpv/, an mpv-like player in Axión).
#   1. CoreTest.axi — the pure player logic (Core.axi) on fixed inputs — must print IDENTICAL output
#      on the interpreter, `--backend cranelift` and `--release`: any difference is a compiler bug.
#   2. The same program under ASan + LSan (instrumented IR, linked with the Rust runtime): no
#      corruption, no leak.
#   3. `--emit verify` is clean for every axmpv source.
# Skips cleanly without clang (ASan step only). AXMPV_TEST_REQUIRE=1 turns a skip into a failure.
#
#   AXIONC=axionc/target/release/axionc scripts/axmpv-test.sh
set -uo pipefail
cd "$(dirname "$0")/.."

AXIONC="${AXIONC:-axionc/target/debug/axionc}"
DIR=examples/axmpv
CLANG="${AXION_CLANG:-clang}"
fail=0

skip_or_fail() { # message
  if [ -n "${AXMPV_TEST_REQUIRE:-}" ]; then
    echo "FATAL (AXMPV_TEST_REQUIRE): $1" >&2
    exit 1
  fi
  echo "$1 — skipping"
}

if [ ! -x "$AXIONC" ]; then
  echo "building axionc…"
  (cd axionc && cargo build -q) || { echo "build failed"; exit 2; }
fi
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# 1. differential
"$AXIONC" "$DIR/CoreTest.axi" > "$WORK/interp.out" 2>&1 || { echo "✗ CoreTest: interpreter failed"; cat "$WORK/interp.out"; fail=1; }
for b in "--backend cranelift" "--release"; do
  # shellcheck disable=SC2086
  "$AXIONC" $b "$DIR/CoreTest.axi" > "$WORK/native.out" 2>&1
  if diff -u "$WORK/interp.out" "$WORK/native.out" > "$WORK/diff" 2>&1; then
    echo "✓ CoreTest $b == interpreter"
  else
    echo "✗ CoreTest $b differs from the interpreter:"; head -20 "$WORK/diff"; fail=1
  fi
done
[ "$(wc -l < "$WORK/interp.out")" -ge 30 ] || { echo "✗ CoreTest printed too little"; fail=1; }

# 2. ASan + LSan
if command -v "$CLANG" >/dev/null 2>&1; then
  cargo build -q --release --manifest-path axion-rt/Cargo.toml || { echo "axion-rt build failed"; exit 2; }
  if "$AXIONC" --emit llvm "$DIR/CoreTest.axi" > "$WORK/ct.ll" \
     && "$CLANG" -fsanitize=address,leak -pthread -O1 -w "$WORK/ct.ll" axion-rt/target/release/libaxion_rt.a -ldl -lm -o "$WORK/ct"; then
    if "$WORK/ct" > "$WORK/asan.out" 2> "$WORK/asan.err" && diff -q "$WORK/interp.out" "$WORK/asan.out" >/dev/null; then
      echo "✓ CoreTest ASan + LSan clean"
    else
      echo "✗ CoreTest under ASan/LSan:"; grep -E "ERROR|SUMMARY" "$WORK/asan.err" | head; fail=1
    fi
  else
    echo "✗ CoreTest: could not build the ASan binary"; fail=1
  fi
else
  skip_or_fail "no clang (set AXION_CLANG): ASan step"
fi

# 3. verify
for f in "$DIR"/*.axi; do
  if "$AXIONC" --emit verify "$f" 2>&1 | grep -q "no corruption"; then
    echo "✓ verify $(basename "$f")"
  else
    echo "✗ verify $(basename "$f"):"; "$AXIONC" --emit verify "$f" 2>&1 | head -5; fail=1
  fi
done

# 4. the player itself, headless (SDL's dummy video/audio drivers), on generated test media, driven
#    by a `--script`, built with ASan + LSan. Needs ffmpeg/ffprobe, SDL2 (AXMPV_SDL_LIBS, else nix)
#    and clang. The final status line is asserted on.
run_player() {
  if ! command -v ffmpeg >/dev/null 2>&1 || ! command -v ffprobe >/dev/null 2>&1; then
    skip_or_fail "ffmpeg/ffprobe not available: headless player run"; return
  fi
  if ! command -v "$CLANG" >/dev/null 2>&1; then
    skip_or_fail "no clang: headless player run"; return
  fi
  local libs="${AXMPV_SDL_LIBS:-}"
  if [ -z "$libs" ] && command -v nix >/dev/null 2>&1; then
    local s2 s3
    s2=$(nix build --no-link --print-out-paths nixpkgs#SDL2 2>/dev/null || true)
    s3=$(nix build --no-link --print-out-paths nixpkgs#sdl3.lib 2>/dev/null || true)
    [ -n "$s2" ] && libs="$s2/lib${s3:+:$s3/lib}"
  fi
  if [ -z "$libs" ]; then
    skip_or_fail "SDL2 not found (set AXMPV_SDL_LIBS): headless player run"; return
  fi
  local ff="env -u LD_LIBRARY_PATH"
  $ff ffmpeg -hide_banner -loglevel error -y -f lavfi -i testsrc=duration=4:size=320x240:rate=25 \
    -f lavfi -i sine=frequency=440:duration=4 -c:v mpeg4 -q:v 5 -c:a aac -shortest "$WORK/a.mkv" \
    && $ff ffmpeg -hide_banner -loglevel error -y -f lavfi -i testsrc2=duration=2:size=160x120:rate=10 \
    -c:v mpeg4 -q:v 5 "$WORK/b.mkv" || { echo "✗ could not generate test media"; fail=1; return; }
  if ! "$AXIONC" --emit llvm "$DIR/axmpv.axi" > "$WORK/axmpv.ll"; then
    echo "✗ axmpv.axi does not compile natively"; fail=1; return
  fi
  local ldirs=() d
  IFS=: read -r -a ldirs <<< "$libs"
  local lflags=()
  for d in "${ldirs[@]}"; do lflags+=("-L$d"); done
  if ! "$CLANG" -fsanitize=address,leak -pthread -O1 -w "$WORK/axmpv.ll" axion-rt/target/release/libaxion_rt.a \
       "${lflags[@]}" -l:libSDL2.so -l:libc.so.6 -ldl -lm -o "$WORK/axmpv"; then
    echo "✗ could not build the ASan player"; fail=1; return
  fi
  # pause/unpause, a seek back, then quit before the end. (Script times are wall time; ffmpeg's start-up
  # after open and seek is not playback time, so the bounds on frames/pos are loose.)
  printf '600 pause\n1000 pause\n1400 seek_backward\n1900 quit\n' > "$WORK/s1"
  # play both files through to the end (the playlist ends the program)
  printf '' > "$WORK/s2"
  local out1 out2
  out1=$(cd "$WORK" && env -u LD_LIBRARY_PATH LD_LIBRARY_PATH="$libs" SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy \
    timeout 60 ./axmpv --script s1 a.mkv 2> s1.err | tail -1)
  out2=$(cd "$WORK" && env -u LD_LIBRARY_PATH LD_LIBRARY_PATH="$libs" SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy \
    timeout 60 ./axmpv --script s2 a.mkv b.mkv 2> s2.err | tail -1)
  check_status() { # name, status line, error file, awk condition on frames/dropped/pos/idx
    if grep -qE "ERROR: (Address|Leak)Sanitizer" "$3"; then
      echo "✗ $1: sanitizer report:"; grep -E "ERROR|SUMMARY" "$3" | head -5; fail=1
    elif echo "$2" | awk -v cond="$4" '
         { for (i = 1; i <= NF; i++) { split($i, kv, "="); v[kv[1]] = kv[2] } }
         END { f = v["frames"]; d = v["dropped"]; p = v["pos"]; x = v["idx"]
               ok = (cond == "s1") ? (f >= 10 && d <= 5 && p >= 50 && p <= 900) \
                                   : (f >= 110 && d <= 10 && x == 1)
               exit ok ? 0 : 1 }'; then
      echo "✓ $1: $2"
    else
      echo "✗ $1: unexpected status '$2'"; head -5 "$3"; fail=1
    fi
  }
  check_status "player: pause + seek + quit" "$out1" "$WORK/s1.err" s1
  check_status "player: two-file playlist to the end" "$out2" "$WORK/s2.err" s2

  # config.lua + keys + audio: an option row sets the volume, keys go through the keymap (`9` =
  # volume_down by default, `m` mute, `gg` a `!command` binding), a speed change respawns the audio
  # pipe. HOME is sandboxed (the keymap is written under it).
  mkdir -p "$WORK/home"
  cat > "$WORK/cfg.lua" <<'LUA'
-- test config
local config = {
  { option = "volume", value = "60" },
  { key = "gg", action = "!echo %t >> marks.txt" },
  { key = "l",  action = "seek_forward" },
}
return config
LUA
  printf '300 key:9\n500 key:m\n700 speed_up\n900 key:gg\n1300 quit\n' > "$WORK/s3"
  local out3
  out3=$(cd "$WORK" && env -u LD_LIBRARY_PATH LD_LIBRARY_PATH="$libs" HOME="$WORK/home" SDL_VIDEODRIVER=dummy \
    SDL_AUDIODRIVER=dummy timeout 60 ./axmpv --config cfg.lua --script s3 a.mkv 2> s3.err | tail -1)
  if grep -qE "ERROR: (Address|Leak)Sanitizer" "$WORK/s3.err"; then
    echo "✗ player: config + keys + audio: sanitizer report:"; grep -E "ERROR|SUMMARY" "$WORK/s3.err" | head -5; fail=1
  elif echo "$out3" | grep -q "vol=58 muted=1 speed=110" && [ -s "$WORK/marks.txt" ] \
       && grep -qE '^[0-9]+$' "$WORK/marks.txt"; then
    echo "✓ player: config + keys + audio: $out3 (mark at $(cat "$WORK/marks.txt") s)"
  else
    echo "✗ player: config + keys + audio: unexpected status '$out3' (marks: $(cat "$WORK/marks.txt" 2>/dev/null))"
    head -5 "$WORK/s3.err"; fail=1
  fi
}
run_player

[ "$fail" = 0 ] && echo "OK: axmpv gate passed" || echo "FAIL: axmpv gate"
exit "$fail"
