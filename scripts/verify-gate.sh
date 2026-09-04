#!/usr/bin/env bash
# Δ SOUNDNESS GATE (the blocking linearity judgment, docs/delta-consolidation-plan.md).
#
# The drop-balance verifier (src/verify.rs, default-on AX0910/AX0911) is the AUTHORITATIVE
# linearity judgment: an abstract interpretation over the FINAL drop-inserted Core that
# proves no double-free / use-after-free / bad-free (corruption) and no gate-worthy leak,
# cross-checked against ASan (scripts/sanitize.sh). This is the script form of the in-crate
# `tests/verify.rs::verifier_reports_no_corruption_over_all_fixtures` gate, promoted to a
# BLOCKING CI step in the `delta` job — the sound successor to the advisory Δ checker
# (scripts/check-delta.sh, delta.rs::check_all), which it was proven to subsume (the
# `delta::tests::subsumes_*` cross-check).
#
# `--emit verify` prints, per fixture:
#   · "ok: …"    — lowered to Core and verified clean (counted)
#   · "FAIL: …"  — a corruption finding (GATE FAILURE)
#   · "Leak: `v` in `f` @span" — a leak; gate-worthy unless `f` is a synthetic `*$step`
#   · (nothing)  — rejection fixture (front-end error): never reaches the verifier, skipped
#
# Keyed on OUTPUT, not exit status: rejection fixtures exit non-zero BY DESIGN.
#
# Run:  ./scripts/verify-gate.sh
set -uo pipefail
cd "$(dirname "$0")/.."
# rejection fixtures exit non-zero by design; compare by content, not exit status.
set +o pipefail

AXIONC="${AXIONC:-axionc/target/debug/axionc}"
if [ ! -x "$AXIONC" ]; then
  echo "building axionc…"
  (cd axionc && cargo build -q) || { echo "build failed"; exit 2; }
fi

inputs() { ls axionc/tests/fixtures/*.axi examples/*.axi 2>/dev/null; }

ok=0; skipped=0; fail=0
for f in $(inputs); do
  # recover_partial.axi is deliberately malformed — it never lowers to Core.
  case "$(basename "$f")" in recover_partial.axi) skipped=$((skipped + 1)); continue ;; esac

  out=$("$AXIONC" --emit verify "$f" 2>&1)
  if echo "$out" | grep -q "^FAIL:"; then
    echo "✗ $f: corruption:"
    echo "$out" | grep -E "Free|Alias|Unbalanced|WrongDropKey|^FAIL:" | head -5
    fail=1
  elif echo "$out" | grep -q "^ok:"; then
    ok=$((ok + 1))
    # a leak in ordinary code is gate-worthy; only synthetic `*$step` workers are exempt.
    while IFS= read -r l; do
      func=$(echo "$l" | sed -n 's/.* in `\([^`]*\)`.*/\1/p')
      case "$func" in
        *'$step') ;; # whitelisted (hand-rolled session/parmap memory)
        *) echo "✗ $f: gate-worthy leak: $l"; fail=1 ;;
      esac
    done < <(echo "$out" | grep "^Leak:")
  else
    # rejection fixture (front-end error) — the verifier never runs on it.
    skipped=$((skipped + 1))
  fi
done

echo "---"
if [ "$fail" -eq 0 ]; then
  if [ "$ok" -lt 100 ]; then
    echo "FAILURE: only $ok fixtures verified — expected >100 (build/corpus problem?)."
    exit 1
  fi
  echo "OK: $ok fixtures verify clean (no corruption, no gate-worthy leak); $skipped skipped (rejections/malformed)."
else
  echo "FAILURE: the drop-balance verifier found corruption or a gate-worthy leak."
fi
exit $fail
