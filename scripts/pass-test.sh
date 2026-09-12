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

# `ls` now renders a TREE (upstream shells to tree(1); we render it natively). Root
# entries sorted (LC_ALL=C): email/, github/, wifi.gpg — dotfiles (.gpg-id) hidden.
EXPECT_LS=$'Password Store\n├── email\n│   └── personal\n├── github\n│   └── work\n└── wifi'
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

# fzf picker: `pass show` with NO name pipes the entry list into fzf and shows the pick.
# Mock fzf (first on PATH) selects the first candidate; entries sort to email/personal first.
mkdir -p "$WORK/bin"; printf '#!/bin/sh\nhead -n1\n' > "$WORK/bin/fzf"; chmod +x "$WORK/bin/fzf"
PATH="$WORK/bin:$PATH" check "pass show (fzf pick)" $'hunter2\nuser: me@example.com' -- show

# `show <missing>` is an ERROR: the message goes to stderr and the exit code is non-zero
# (stdout stays empty), so it can't use the stdout-agreement harness above.
AXIONC="${AXIONC:-axionc/target/debug/axionc}"
err="$("$AXIONC" run --backend interp "$PASS" -- show nope 2>&1 >/dev/null)"; code=$?
if [ "$code" -eq 0 ] || ! printf '%s' "$err" | grep -q "is not in the password store"; then
  echo "✗ not found: expected a stderr error + non-zero exit (got code=$code err=$(printf '%q' "$err"))"; fail=1
else
  echo "✓ not found: error on stderr, exit $code"
fi

if [ "$fail" -eq 0 ]; then
  echo "OK: read paths behave correctly, and all backends agree, across ls/show/find/grep"
else
  echo "FAIL: differences above"
  exit 1
fi

# ── Phase C: write paths (rm/mv/cp/generate) ────────────────────────────────────
# These MUTATE the store and `generate` is random, so the all-backends-agree harness
# doesn't fit. Instead run each command on every available backend against its OWN
# freshly-seeded store and assert the on-disk effect (files gone/created, decrypted
# contents), proving each backend actually performs the mutation.
backends=(interp)
"$AXIONC" --emit clif "$PASS" >/dev/null 2>&1 && backends+=(cranelift)
command -v clang >/dev/null 2>&1 && backends+=(llvm)

run_be() { # backend -- args...   → program stdout
  local be="$1"; shift
  [ "${1:-}" = "--" ] && shift
  "$AXIONC" run --backend "$be" "$PASS" ${@:+-- "$@"} 2>/dev/null
}
decrypt() { gpg -d --quiet "$1" 2>/dev/null; }
seed() { # store-dir
  local d="$1"
  rm -rf "$d"; mkdir -p "$d/email"
  echo "pass-test@axion.local" >"$d/.gpg-id"
  printf '%s' 'correcthorsebatterystaple' | gpg --batch --yes --quiet -r pass-test@axion.local -e -o "$d/wifi.gpg" 2>/dev/null
  printf '%s' 'movemenow'                  | gpg --batch --yes --quiet -r pass-test@axion.local -e -o "$d/mvsrc.gpg" 2>/dev/null
  printf '%s' $'hunter2\nuser: me'         | gpg --batch --yes --quiet -r pass-test@axion.local -e -o "$d/email/personal.gpg" 2>/dev/null
}

wfail=0
for be in "${backends[@]}"; do
  S="$WORK/w-$be"; export PASSWORD_STORE_DIR="$S"; seed "$S"

  out="$(run_be "$be" -- rm wifi)"
  if [ -e "$S/wifi.gpg" ] || [ "$out" != "Removed wifi" ]; then
    echo "✗ [$be] rm wifi (out=$(printf '%q' "$out"))"; wfail=1
  else echo "✓ [$be] rm"; fi

  run_be "$be" -- mv mvsrc moved/here >/dev/null
  if [ -e "$S/mvsrc.gpg" ] || [ "$(decrypt "$S/moved/here.gpg")" != "movemenow" ]; then
    echo "✗ [$be] mv mvsrc moved/here"; wfail=1
  else echo "✓ [$be] mv (into a new subdir)"; fi

  run_be "$be" -- cp email/personal email/copy >/dev/null
  if [ "$(decrypt "$S/email/copy.gpg")" != "$(decrypt "$S/email/personal.gpg")" ]; then
    echo "✗ [$be] cp email/personal email/copy"; wfail=1
  else echo "✓ [$be] cp"; fi

  pw="$(run_be "$be" -- generate gen/new 20 | tail -1)"
  dec="$(decrypt "$S/gen/new.gpg")"
  if [ -z "$dec" ] || [ "$pw" != "$dec" ] || [ "${#dec}" -ne 20 ]; then
    echo "✗ [$be] generate (printed=$(printf '%q' "$pw") decrypted=$(printf '%q' "$dec"))"; wfail=1
  else echo "✓ [$be] generate (printed == decrypted, 20 chars)"; fi

  # insert: the passphrase is fed twice on stdin (echo-off degrades to a plain read on
  # a pipe). The secret must round-trip, and never appear in the process's argv.
  printf 'topsecret\ntopsecret\n' | run_be "$be" -- insert web/new >/dev/null
  if [ "$(decrypt "$S/web/new.gpg")" != "topsecret" ]; then
    echo "✗ [$be] insert web/new"; wfail=1
  else echo "✓ [$be] insert (echo-off, round-trips)"; fi
  # a mismatch must abort without writing the entry.
  printf 'aaa\nbbb\n' | run_be "$be" -- insert web/mismatch >/dev/null
  if [ -e "$S/web/mismatch.gpg" ]; then
    echo "✗ [$be] insert mismatch should not write"; wfail=1
  else echo "✓ [$be] insert (mismatch aborts)"; fi
  # the plaintext scratch file must not linger.
  if [ -e "$S/.pass-insert.tmp" ]; then
    echo "✗ [$be] insert left plaintext tmpfile behind"; wfail=1
  else echo "✓ [$be] insert (no plaintext tmpfile left)"; fi

  # injection safety: show/insert are shell-free (execvp), so an entry name full of
  # shell metacharacters is just a filename — a command substitution must NOT run, and
  # the entry must round-trip byte-for-byte.
  inj="a\$(touch $S/PWNED) b'c"
  printf 'sekret\nsekret\n' | run_be "$be" -- insert "$inj" >/dev/null
  got="$(run_be "$be" -- show "$inj")"
  if [ -e "$S/PWNED" ] || [ "$got" != "sekret" ]; then
    echo "✗ [$be] injection-safety (canary=$([ -e "$S/PWNED" ] && echo HIT) got=$(printf '%q' "$got"))"; wfail=1
  else echo "✓ [$be] shell-free: metachar name round-trips, no command injection"; fi

  # insert -m: read a MULTILINE body from stdin until EOF (via `cat` under runCapture) and
  # store it verbatim. The first line is the password; extra lines are metadata.
  printf 'first-line-pw\nuser: bob\nurl: example.com\n' | run_be "$be" -- insert -m multi/entry >/dev/null
  if [ "$(decrypt "$S/multi/entry.gpg")" != $'first-line-pw\nuser: bob\nurl: example.com' ]; then
    echo "✗ [$be] insert -m multi/entry (got=$(printf '%q' "$(decrypt "$S/multi/entry.gpg")"))"; wfail=1
  else echo "✓ [$be] insert -m (multiline body round-trips)"; fi

  # edit: decrypt into $EDITOR (scripted non-interactively here) on a RAMFS temp, then
  # re-encrypt on save. Cover: (1) an existing entry gets new content; (2) a NEW name starts
  # empty and is created; (3) an unchanged edit rewrites nothing; (4) no plaintext temp lingers.
  cat > "$WORK/ed-write" <<'E'
#!/bin/sh
printf 'edited-pw\nmeta: changed\n' > "$1"
E
  chmod +x "$WORK/ed-write"
  EDITOR="$WORK/ed-write" run_be "$be" -- edit email/personal >/dev/null
  if [ "$(decrypt "$S/email/personal.gpg")" != $'edited-pw\nmeta: changed' ]; then
    echo "✗ [$be] edit existing (got=$(printf '%q' "$(decrypt "$S/email/personal.gpg")"))"; wfail=1
  else echo "✓ [$be] edit (existing entry re-encrypts new content)"; fi
  EDITOR="$WORK/ed-write" run_be "$be" -- edit fresh/made >/dev/null
  if [ "$(decrypt "$S/fresh/made.gpg")" != $'edited-pw\nmeta: changed' ]; then
    echo "✗ [$be] edit new"; wfail=1
  else echo "✓ [$be] edit (new entry created from empty)"; fi
  before="$(decrypt "$S/email/personal.gpg")"
  out="$(EDITOR=true run_be "$be" -- edit email/personal)"
  if [ "$(decrypt "$S/email/personal.gpg")" != "$before" ] || ! printf '%s' "$out" | grep -q "unchanged"; then
    echo "✗ [$be] edit unchanged (out=$(printf '%q' "$out"))"; wfail=1
  else echo "✓ [$be] edit (unchanged → no rewrite)"; fi
  if ls /dev/shm/pass-axi-* >/dev/null 2>&1 || ls "${TMPDIR:-/tmp}"/pass-axi-* >/dev/null 2>&1; then
    echo "✗ [$be] edit left a plaintext temp behind"; wfail=1
  else echo "✓ [$be] edit (RAMFS temp cleaned up)"; fi

  # git passthrough: make the store a repo (so mutations auto-commit), do a mutation, then
  # `pass git log` must show that commit — proving the argv is forwarded to git in the store.
  # GIT_* identity is exported so the child git (spawned shell-free by pass) can commit.
  git -C "$S" init -q 2>/dev/null
  export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t.t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t.t
  git -C "$S" add -A >/dev/null 2>&1; git -C "$S" commit -qm seed >/dev/null 2>&1
  run_be "$be" -- generate gitgen 12 >/dev/null      # auto-commits "Generate gitgen"
  if ! run_be "$be" -- git log --oneline 2>/dev/null | grep -q "Generate gitgen"; then
    echo "✗ [$be] git passthrough (log lacks the auto-commit)"; wfail=1
  else echo "✓ [$be] git (passthrough shows the store's own history)"; fi

  # injection safety, shell-STRING paths: find/grep/generate build an `sh -c` pipeline,
  # so every interpolated user value is single-quoted through `shQuote`. A term that
  # closes the quote and runs a command substitution must be treated as a LITERAL
  # pattern — the canary file must never appear on any of the three.
  rm -f "$S/PWNED_FIND" "$S/PWNED_GREP" "$S/PWNED_GEN"
  run_be "$be" -- find   "x'; touch $S/PWNED_FIND; echo '"  >/dev/null 2>&1
  run_be "$be" -- grep   "x'; touch $S/PWNED_GREP; echo '"  >/dev/null 2>&1
  run_be "$be" -- generate "n'; touch $S/PWNED_GEN; echo '" 8 >/dev/null 2>&1
  if [ -e "$S/PWNED_FIND" ] || [ -e "$S/PWNED_GREP" ] || [ -e "$S/PWNED_GEN" ]; then
    echo "✗ [$be] shell-string injection (find=$([ -e "$S/PWNED_FIND" ] && echo HIT) grep=$([ -e "$S/PWNED_GREP" ] && echo HIT) gen=$([ -e "$S/PWNED_GEN" ] && echo HIT))"; wfail=1
  else echo "✓ [$be] shell-string: shQuote blocks find/grep/generate injection"; fi
done

if [ "$wfail" -eq 0 ]; then
  echo "OK: write paths (rm/mv/cp/generate) perform the right effect on every backend"
else
  echo "FAIL: write-path differences above"
  exit 1
fi
