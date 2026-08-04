#!/usr/bin/env bash
# Sanitizers on the native runtime (§2/§11): Axion's value proposition is memory
# safety without a GC, so the runtime must run clean under the LLVM sanitizers.
# Two gates, over the LLVM IR the --release backend emits + the C runtime:
#
#   1. CORRUPTION (AddressSanitizer, all native fixtures): zero
#      use-after-free / double-free. This is the hard guarantee ("no use-after-free").
#   2. LEAKS (LeakSanitizer, proven leak-free subset): allocs == frees.
#      Excludes fixtures whose leak is conservative and known (see LEAKY below).
#
# Run:  AXION_CLANG=<clang> ./scripts/sanitize.sh
set -uo pipefail
cd "$(dirname "$0")/.."

CLANG="${AXION_CLANG:-clang}"
if ! "$CLANG" --version >/dev/null 2>&1; then
  echo "no clang (set AXION_CLANG or put clang on PATH) — skipping sanitizers"
  exit 0
fi

AXIONC="axionc/target/debug/axionc"
if [ ! -x "$AXIONC" ]; then
  echo "building axionc..."
  (cd axionc && cargo build -q) || { echo "build failed"; exit 2; }
fi
RT="axionc/src/axion_rt.c"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Native fixtures (main :: Int/IO) — the corruption gate runs every one the
# --release backend can lower; the --check-only ones skip themselves.
NATIVE=(
  axionc/tests/fixtures/heap_loop.axi
  axionc/tests/fixtures/linear_move.axi
  axionc/tests/fixtures/borrow_reclaim.axi
  axionc/tests/fixtures/update_borrow.axi
  axionc/tests/fixtures/arena_run.axi
  axionc/tests/fixtures/record_run.axi
  axionc/tests/fixtures/buffer_sum.axi
  axionc/tests/fixtures/buffer_linear.axi
  axionc/tests/fixtures/inplace_update.axi
  axionc/tests/fixtures/native_case.axi
  axionc/tests/fixtures/native_closure.axi
  axionc/tests/fixtures/native_fib.axi
  axionc/tests/fixtures/lambda_hof.axi
  axionc/tests/fixtures/nested_drop.axi
  axionc/tests/fixtures/sum_payload.axi
  axionc/tests/fixtures/poly_payload_drop.axi
  axionc/tests/fixtures/poly_payload_borrow_return.axi
  axionc/tests/fixtures/poly_payload_tco.axi
  axionc/tests/fixtures/poly_payload_borrow_alias.axi
  axionc/tests/fixtures/poly_payload_generic_drop.axi
  axionc/tests/fixtures/poly_payload_generic_nested.axi
  axionc/tests/fixtures/poly_payload_generic_compose.axi
  axionc/tests/fixtures/poly_payload_gap.axi
  axionc/tests/fixtures/land_call_boxed.axi
  axionc/tests/fixtures/land_enum_call.axi
  axionc/tests/fixtures/land_deepdrop_safety.axi
  axionc/tests/fixtures/land_field_split_owned.axi
  axionc/tests/fixtures/land_field_mixed.axi
  axionc/tests/fixtures/land_owned_multi.axi
  axionc/tests/fixtures/make_bound_drop.axi
  axionc/tests/fixtures/tuple_owned.axi
  axionc/tests/fixtures/land_tuple_upd.axi
  axionc/tests/fixtures/land_owned_poly.axi
  axionc/tests/fixtures/session_run_pingpong.axi
  axionc/tests/fixtures/session_run_offer.axi
  axionc/tests/fixtures/session_run_cancel.axi
  axionc/tests/fixtures/session_run_twospawn.axi
  axionc/tests/fixtures/session_run_choice3.axi
  axionc/tests/fixtures/session_run_fib.axi
  axionc/tests/fixtures/session_run_parfib.axi
  axionc/tests/fixtures/session_run_server.axi
  examples/01_hello.axi
  examples/02_fib.axi
)

# PROVEN leak-free subset (heap/arena/borrow memory, no IO). The excluded ones
# leak by known and documented conservative reclamation:
#   · show/putStrLn → the runtime C-string is not reclaimed (heap vs. static
#     indistinguishable at drop): record_run, 01_hello, 02_fib.
#   · closure returned by a function → may be a borrowed param, not fresh;
#     reclaiming it would be unsound: native_closure, lambda_hof.
LEAKFREE=(
  heap_loop linear_move borrow_reclaim update_borrow arena_run
  buffer_sum buffer_linear inplace_update native_case native_fib
  nested_drop sum_payload poly_payload_drop poly_payload_tco poly_payload_borrow_alias
  poly_payload_generic_drop poly_payload_generic_nested poly_payload_generic_compose poly_payload_gap
  land_call_boxed land_enum_call land_deepdrop_safety land_field_split_owned land_field_mixed land_owned_multi make_bound_drop tuple_owned land_tuple_upd land_owned_poly
  session_run_pingpong session_run_offer session_run_cancel
  session_run_twospawn session_run_choice3 session_run_fib session_run_parfib session_run_server
)
is_leakfree() { local n; for n in "${LEAKFREE[@]}"; do [ "$n" = "$1" ] && return 0; done; return 1; }

compile() { # <axi> <out> → emits LLVM and compiles with ASan/LSan; 0 if native
  "$AXIONC" --emit llvm "$1" >"$WORK/ir.ll" 2>/dev/null || return 1
  "$CLANG" -fsanitize=address,leak -pthread -O1 -w "$WORK/ir.ll" "$RT" -o "$2" 2>/dev/null
}

fail=0; corr=0; leak=0
for f in "${NATIVE[@]}"; do
  [ -f "$f" ] || continue
  name=$(basename "$f" .axi)
  exe="$WORK/$name.san"
  if ! compile "$f" "$exe"; then
    echo "· $name: not in the native subset (skipped)"
    continue
  fi
  # corruption gate (leaks off)
  if ! ASAN_OPTIONS=detect_leaks=0 "$exe" >/dev/null 2>"$WORK/e"; then
    echo "✗ $name: memory CORRUPTION under ASan"; grep -E 'ERROR|SUMMARY' "$WORK/e" | head -2; fail=1; continue
  fi
  corr=$((corr + 1))
  # leak gate (only on the proven subset)
  if is_leakfree "$name"; then
    if ASAN_OPTIONS=detect_leaks=1 "$exe" >/dev/null 2>"$WORK/e"; then
      echo "✓ $name: ASan + LSan clean"; leak=$((leak + 1))
    else
      echo "✗ $name: LEAK under LSan (should be leak-free)"; grep -E 'SUMMARY' "$WORK/e" | head -1; fail=1
    fi
  else
    echo "✓ $name: ASan clean (known conservative leak — outside the gate)"
  fi
done

echo "---"
if [ "$fail" -eq 0 ]; then
  echo "OK: $corr fixtures without corruption; $leak proven leak-free."
else
  echo "FAILURE: memory regression detected."
fi
exit $fail
