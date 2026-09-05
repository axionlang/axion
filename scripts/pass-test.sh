#!/usr/bin/env bash
# Behavioral test for the Axión `pass` rewrite (examples/pass/pass.axi), Phase B:
# `ls` and `show`. Stands up a THROWAWAY GnuPG keyring + password store (never
# touches the user's real ~/.gnupg or ~/.password-store), encrypts a few entries to a
# passphraseless test key, then checks the tool's output on every available backend.
# Skips cleanly if gpg/find are missing (e.g. a minimal CI image).
#
#   ./scripts/pass-test.sh
set -uo pipefail
cd "$(dirname "$0")/.."

AXIONC="${AXIONC:-axionc/target/debug/axionc}"
PASS="examples/pass/pass.axi"

if ! command -v gpg >/dev/null 2>&1 || ! command -v find >/dev/null 2>&1; then
  echo "gpg/find not available — skipping pass-test"
  exit 0
fi
if [ ! -x "$AXIONC" ]; then
  echo "building axionc…"
  (cd axionc && cargo build -q) || { echo "build failed"; exit 2; }
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
export GNUPGHOME="$WORK/gnupg"
mkdir -p "$GNUPGHOME"
chmod 700 "$GNUPGHOME"
export PASSWORD_STORE_DIR="$WORK/store"

# A throwaway passphraseless key, so decryption is non-interactive.
cat >"$WORK/keygen" <<'EOF'
%no-protection
Key-Type: eddsa
Key-Curve: ed25519
Subkey-Type: ecdh
Subkey-Curve: cv25519
Name-Real: Axion Pass Test
Name-Email: pass-test@axion.local
Expire-Date: 0
%commit
EOF
if ! gpg --batch --quiet --gen-key "$WORK/keygen" 2>/dev/null; then
  echo "could not generate a test gpg key — skipping pass-test"
  exit 0
fi

mkdir -p "$PASSWORD_STORE_DIR/github" "$PASSWORD_STORE_DIR/email"
echo "pass-test@axion.local" >"$PASSWORD_STORE_DIR/.gpg-id"
enc() { printf '%s' "$2" | gpg --batch --yes --quiet -r pass-test@axion.local -e -o "$PASSWORD_STORE_DIR/$1.gpg" 2>/dev/null; }
enc "wifi" 'correcthorsebatterystaple'
enc "email/personal" $'hunter2\nuser: me@example.com'
enc "github/work" $'ghp_worktoken123\nuser: workacct'

EXPECT_LS=$'email/personal\ngithub/work\nwifi'
EXPECT_SHOW='correcthorsebatterystaple'
EXPECT_FIND='github/work'
EXPECT_GREP=$'github/work:\n  user: workacct'

# Drive each command through scripts/axi-check.sh (the blessed pattern): it runs the program
# on every available backend, asserts they AGREE, and checks the output — all against the
# throwaway GNUPGHOME/PASSWORD_STORE_DIR exported above, which it inherits.
fail=0
check() { # label expected -- prog args...
  local label="$1" expect="$2"
  shift 2
  [ "${1:-}" = "--" ] && shift
  ./scripts/axi-check.sh --label "$label" --expect "$expect" "$PASS" -- "$@" || fail=1
}

check "pass ls"        "$EXPECT_LS"   -- ls
check "pass (no args)" "$EXPECT_LS"   --
check "pass show wifi" "$EXPECT_SHOW" -- show wifi
check "pass wifi"      "$EXPECT_SHOW" -- wifi
check "pass find git"  "$EXPECT_FIND" -- find git
check "pass grep acct" "$EXPECT_GREP" -- grep workacct
check "not found"      "Error: nope is not in the password store." -- show nope

if [ "$fail" -eq 0 ]; then
  echo "OK: pass behaves correctly, and all backends agree, across ls/show/find/grep"
else
  echo "FAIL: differences above"
  exit 1
fi
