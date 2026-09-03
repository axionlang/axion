#!/usr/bin/env bash
# Phase A′ regression oracle: the `--emit core` dump is nondeterministic in the
# ORDER of its drop sites and function blocks (HashSet iteration, per-process
# RandomState), so a raw diff is noise. Sorting the lines makes the comparison
# deterministic: if the multiset of lines is unchanged, only ordering moved.
# The sort is pinned to `LC_ALL=C` so the byte ordering is LOCALE-INDEPENDENT — a
# snapshot stored on one machine (e.g. pt_PT.UTF-8) matches the check on another
# (CI runners), which otherwise collate differently and mismatch EVERY fixture.
#
#   ./scripts/dump-oracle.sh             # compare vs the stored snapshot
#   ./scripts/dump-oracle.sh --snapshot  # (re)store the snapshot
#
# Uses the SAME binary for the snapshot and the check; the snapshot records the
# current behavior, so store it at a known-good state, then every change must
# keep the oracle green BEFORE the sanitize/differential gates.
set -uo pipefail
cd "$(dirname "$0")/.."
# note: `pipefail` off below — rejection fixtures exit non-zero BY DESIGN, and
# the comparison is by content, not by the compiler's exit status.
set +o pipefail

AXIONC="${AXIONC:-axionc/target/debug/axionc}"
SNAP="axionc/tests/coresnap"
if [ ! -x "$AXIONC" ]; then
  echo "building axionc…"
  (cd axionc && cargo build -q) || { echo "build failed"; exit 2; }
fi
mkdir -p "$SNAP"

inputs() { ls axionc/tests/fixtures/*.axi examples/*.axi 2>/dev/null; }

if [ "${1:-}" = "--snapshot" ]; then
  n=0
  for f in $(inputs); do
    ./"$AXIONC" --emit core "$f" 2>/dev/null | LC_ALL=C sort > "$SNAP/$(basename "$f")"
    n=$((n + 1))
  done
  echo "snapshot stored: $n fixtures in $SNAP"
  exit 0
fi

fail=0; n=0
for f in $(inputs); do
  n=$((n + 1))
  if ! ./"$AXIONC" --emit core "$f" 2>/dev/null | LC_ALL=C sort | cmp -s - "$SNAP/$(basename "$f")"; then
    echo "DIFF: $f"
    fail=1
  fi
done
if [ "$fail" -eq 0 ]; then
  echo "OK: $n fixtures byte-identical (lines sorted) vs $SNAP"
else
  echo "REGRESSION: differences above — --snapshot only if the change is intended"
  exit 1
fi
