#!/usr/bin/env bash
# Real-workload ASan gate for the `pass` clone (examples/pass/pass.axi). Both double-frees that
# shipped to `axpass` (the `</>` and `relJoin` borrowed-list-element aliases) only manifested when
# `show` recursed over a store WITH SUBDIRECTORIES via the fzf picker — a path the fixture corpus
# never exercised. This runs every command over a throwaway NESTED store under AddressSanitizer, so
# that class can't regress silently again.
#
# Run:  AXION_CLANG=<clang> ./scripts/pass-asan.sh
set -uo pipefail
cd "$(dirname "$0")/.."

CLANG="${AXION_CLANG:-clang}"
if ! "$CLANG" --version >/dev/null 2>&1; then
  echo "no clang (set AXION_CLANG or put clang on PATH) — skipping pass ASan gate"
  exit 0
fi
AXIONC="axionc/target/debug/axionc"
[ -x "$AXIONC" ] || (cd axionc && cargo build -q) || { echo "build failed"; exit 2; }

W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
# a NESTED throwaway store (subdirectories are what exercised the recursive entry-list path).
S="$W/store"; mkdir -p "$S/web" "$S/email/work"
: > "$S/github.gpg"; : > "$S/web/reddit.gpg"; : > "$S/web/news.gpg"
: > "$S/email/gmail.gpg"; : > "$S/email/work/jira.gpg"
# fzf stub: echo the first candidate (a deterministic "selection") so `show`/`edit` are non-interactive.
mkdir -p "$W/bin"; printf '#!/bin/sh\nhead -n1\n' > "$W/bin/fzf"; chmod +x "$W/bin/fzf"

# Build + link the Rust runtime staticlib (axion-rt: strings/IO + OS-capability, which pass leans on
# heavily) alongside the C runtime. See docs/rust-runtime-port.md.
cargo build -q --release --manifest-path axion-rt/Cargo.toml || { echo "FAIL: axion-rt build"; exit 1; }
"$AXIONC" --emit llvm examples/pass/pass.axi > "$W/ir.ll" 2>/dev/null || { echo "FAIL: pass.axi did not lower"; exit 1; }
"$CLANG" -fsanitize=address -pthread -O1 -w "$W/ir.ll" \
  axion-rt/target/release/libaxion_rt.a -ldl -lm -o "$W/axpass" 2>/dev/null \
  || { echo "FAIL: ASan build failed"; exit 1; }

fail=0
run() { # <cmd...>
  PATH="$W/bin:$PATH" ASAN_OPTIONS=detect_leaks=0 PASSWORD_STORE_DIR="$S" HOME="$W" EDITOR=true \
    "$W/axpass" "$@" >/dev/null 2>"$W/e"
  if grep -qiE "AddressSanitizer: (heap-use-after-free|attempting double-free)|double free" "$W/e"; then
    echo "✗ pass $*: ASan CORRUPTION"; sed -n '1,3p' "$W/e"; fail=1
  else
    echo "✓ pass $*: ASan clean"
  fi
}
run show            # no name → fzf picker → recursive entry list (both crashes lived here)
run show web/reddit
run ls
run ls web
run find red
run grep foo
run edit web/reddit
run git status
run                  # bare = ls
# newer commands: flag parsing (getopt), init, recursive rm -r, directory mv/cp, help/version.
run version
run help
run init TESTKEY     # writes .gpg-id
run cp web webcopy   # directory copy (recursive, shell-free)
run rm -r webcopy    # recursive subtree remove
run mv email mail    # directory rename
run rm -rf ghost     # bundled flags + force on a missing entry (no error)
run show -c2 github  # -c<n> line-select parse + clipCopy/nthLine path
run show -s github   # -s show-all path (print, no clipboard)
run github           # bare shorthand → clipboard the password (line 1)
run -s github        # bare `-s <name>` → print all (name at argv[1])
run generate -i github  # in-place generate parse path

[ "$fail" = 0 ] && echo "OK: pass(1) commands ASan-clean over a nested store" || { echo "pass ASan gate FAILED"; exit 1; }
