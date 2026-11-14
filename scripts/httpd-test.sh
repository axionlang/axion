#!/usr/bin/env bash
# Behavioral + memory gate for the HTTP/1.1 static file server (examples/httpd.axi). Builds it under
# ASan/LSan, serves a throwaway site, and drives it with curl: status codes, MIME types, HEAD, a
# multi-chunk binary file (byte-identical), path traversal refused (`..`, `%2e%2e`), a NUL escape,
# an unsupported method, HTTP/1.0, and 20 concurrent downloads. The server stops by itself after
# AXHTTPD_MAX connections, so LeakSanitizer gets a clean exit to check. Native only (the
# interpreter cannot run a socket server).
#
#   AXION_CLANG=clang ./scripts/httpd-test.sh
set -uo pipefail
cd "$(dirname "$0")/.."

AXIONC="${AXIONC:-axionc/target/debug/axionc}"
CLANG="${AXION_CLANG:-clang}"
PORT="${AXHTTPD_TEST_PORT:-18431}"
if [ ! -x "$AXIONC" ]; then
  echo "building axionc…"
  (cd axionc && cargo build -q) || { echo "build failed"; exit 2; }
fi
command -v curl >/dev/null || { echo "SKIP: curl not found"; exit 0; }
command -v "$CLANG" >/dev/null || { echo "SKIP: clang not found"; exit 0; }

W="$(mktemp -d)"; trap 'kill "${srv:-}" 2>/dev/null; rm -rf "$W"' EXIT
cargo build -q --release --manifest-path axion-rt/Cargo.toml || { echo "FAIL: axion-rt build"; exit 1; }
"$AXIONC" --emit llvm examples/httpd.axi > "$W/ir.ll" || { echo "FAIL: httpd.axi did not lower"; exit 1; }
"$CLANG" -fsanitize=address,leak -pthread -O1 -w "$W/ir.ll" \
  axion-rt/target/release/libaxion_rt.a -ldl -lm -o "$W/httpd" || { echo "FAIL: ASan build"; exit 1; }

# the site, and a file beside it that must stay out of reach
mkdir -p "$W/site/sub"
printf '<h1>hi</h1>\n' > "$W/site/index.html"
printf 'body{}\n' > "$W/site/sub/a.css"
printf 'plain\n' > "$W/site/sub/index.html"
head -c 200000 /dev/urandom > "$W/site/big.bin"
printf 'secret\n' > "$W/secret.txt"

PAR=20
CONNS=$((1 + 13 + PAR))   # readiness probe + the single requests below + the concurrent ones
AXHTTPD_ROOT="$W/site" AXHTTPD_PORT="$PORT" AXHTTPD_MAX="$CONNS" ASAN_OPTIONS=detect_leaks=1 \
  timeout 120 "$W/httpd" >"$W/out" 2>"$W/err" &
srv=$!
up=0
for _ in $(seq 100); do
  curl -s -o /dev/null "http://127.0.0.1:$PORT/" && { up=1; break; }
  sleep 0.1
done
[ "$up" = 1 ] || { echo "FAIL: server did not come up"; cat "$W/err"; exit 1; }

fail=0
U="http://127.0.0.1:$PORT"
check() { # <label> <expected "code type"> <curl args...>
  local label=$1 want=$2; shift 2
  local got
  got=$(curl -s -o "$W/body" -w '%{http_code} %{content_type}' "$@")
  if [ "$got" = "$want" ]; then echo "✓ $label"; else echo "✗ $label: got '$got', want '$want'"; fail=1; fi
}
body() { # <label> <expected body file>
  if cmp -s "$W/body" "$2"; then echo "✓ $1 body"; else echo "✗ $1 body differs"; fail=1; fi
}
check "GET /"               "200 text/html; charset=utf-8" "$U/";                         body "GET /" "$W/site/index.html"
check "GET /sub/a.css"      "200 text/css"                 "$U/sub/a.css";                body "GET /sub/a.css" "$W/site/sub/a.css"
check "GET /sub/ (index)"   "200 text/html; charset=utf-8" "$U/sub/";                     body "GET /sub/" "$W/site/sub/index.html"
check "GET /big.bin"        "200 application/octet-stream" "$U/big.bin";                  body "GET /big.bin" "$W/site/big.bin"
check "GET /x?q=1#f"        "200 text/html; charset=utf-8" "$U/index.html?q=1"
check "HEAD /"              "200 text/html; charset=utf-8" -I "$U/"
check "GET /missing"        "404 text/plain; charset=utf-8" "$U/missing"
check "GET /sub (a dir)"    "404 text/plain; charset=utf-8" "$U/sub"
check "GET /../secret.txt"  "403 text/plain; charset=utf-8" --path-as-is "$U/../secret.txt"
check "GET /%2e%2e/secret"  "403 text/plain; charset=utf-8" --path-as-is "$U/%2e%2e/secret.txt"
check "GET /a%00b"          "400 text/plain; charset=utf-8" --path-as-is "$U/a%00b"
check "POST /"              "405 text/plain; charset=utf-8" -X POST "$U/"
check "HTTP/1.0 GET /"      "200 text/html; charset=utf-8" -0 "$U/"
pids=()
for i in $(seq "$PAR"); do curl -s -o "$W/par$i" "$U/big.bin" & pids+=($!); done
wait "${pids[@]}"
same=0
for i in $(seq "$PAR"); do cmp -s "$W/par$i" "$W/site/big.bin" && same=$((same + 1)); done
if [ "$same" = "$PAR" ]; then echo "✓ $PAR concurrent downloads byte-identical"; else echo "✗ only $same/$PAR concurrent downloads intact"; fail=1; fi

wait "$srv"; rc=$?; srv=
if [ "$rc" != 0 ]; then echo "✗ server exited $rc"; fail=1; else echo "✓ server exited cleanly"; fi
if grep -qE "ERROR: (AddressSanitizer|LeakSanitizer)" "$W/err"; then
  echo "✗ sanitizer report:"; grep -E "ERROR|SUMMARY" "$W/err" | head -5; fail=1
else
  echo "✓ ASan/LSan clean"
fi
[ "$fail" = 0 ] && echo "OK: httpd serves correctly and leak-free" || echo "FAIL: httpd"
exit "$fail"
