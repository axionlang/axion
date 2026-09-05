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
enc "email/personal" 'hunter2'
enc "github/work" 'ghp_worktoken123'

EXPECT_LS=$'email/personal\ngithub/work\nwifi'
EXPECT_SHOW='correcthorsebatterystaple'

backends="interp"
"$AXIONC" --emit clif "$PASS" >/dev/null 2>&1 && backends="$backends cranelift"
command -v clang >/dev/null 2>&1 && backends="$backends llvm"

fail=0
check() { # name expected actual
  if [ "$2" = "$3" ]; then
    echo "  ✓ $1"
  else
    echo "  ✗ $1"
    echo "    expected: $(printf '%q' "$2")"
    echo "    actual:   $(printf '%q' "$3")"
    fail=1
  fi
}

for b in $backends; do
  echo "backend: $b"
  check "pass ls"        "$EXPECT_LS"   "$("$AXIONC" run --backend "$b" "$PASS" -- ls 2>/dev/null)"
  check "pass (no args)" "$EXPECT_LS"   "$("$AXIONC" run --backend "$b" "$PASS" 2>/dev/null)"
  check "pass show wifi" "$EXPECT_SHOW" "$("$AXIONC" run --backend "$b" "$PASS" -- show wifi 2>/dev/null)"
  check "pass wifi"      "$EXPECT_SHOW" "$("$AXIONC" run --backend "$b" "$PASS" -- wifi 2>/dev/null)"
  check "not found"      "Error: nope is not in the password store." \
                         "$("$AXIONC" run --backend "$b" "$PASS" -- show nope 2>/dev/null)"
done

if [ "$fail" -eq 0 ]; then
  echo "OK: pass ls/show behave correctly across: $backends"
else
  echo "FAIL: differences above"
  exit 1
fi
