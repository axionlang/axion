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
  axionc/tests/fixtures/list_heap_reclaim.axi
  axionc/tests/fixtures/data_heap_field.axi
  axionc/tests/fixtures/record_update_reclaim.axi
  axionc/tests/fixtures/record_update_multi.axi
  axionc/tests/fixtures/record_update_chain.axi
  axionc/tests/fixtures/record_update_escape.axi
  axionc/tests/fixtures/record_update_escape_read.axi
  axionc/tests/fixtures/integer_reclaim.axi
  axionc/tests/fixtures/integer_accumulator.axi
  axionc/tests/fixtures/integer_divmod.axi
  axionc/tests/fixtures/rsa_modexp.axi
  axionc/tests/fixtures/integer_first_class.axi
  axionc/tests/fixtures/stdlib_batch.axi
  axionc/tests/fixtures/stdlib_batch2.axi
  axionc/tests/fixtures/stdlib_sortby.axi
  axionc/tests/fixtures/stdlib_batch3.axi
  axionc/tests/fixtures/closure_consume_lambda.axi
  axionc/tests/fixtures/closure_data_elem.axi
  axionc/tests/fixtures/closure_acc_return.axi
  axionc/tests/fixtures/closure_mono_hof.axi
  axionc/tests/fixtures/closure_foldl.axi
  axionc/tests/fixtures/closure_record_elem.axi
  axionc/tests/fixtures/closure_nested_list.axi
  axionc/tests/fixtures/closure_alias_combiner.axi
  axionc/tests/fixtures/closure_discard_combiner.axi
  axionc/tests/fixtures/closure_heaplist_combiner.axi
  axionc/tests/fixtures/accum_field_alias.axi
  axionc/tests/fixtures/field_alias_return.axi
  axionc/tests/fixtures/escape_local_borrow.axi
  axionc/tests/fixtures/case_extract_escape.axi
  axionc/tests/fixtures/tuple_extract_escape.axi
  axionc/tests/fixtures/hof_unsigned_closure.axi
  axionc/tests/fixtures/hof_lambda_closure.axi
  axionc/tests/fixtures/hof_partial_closure.axi
  axionc/tests/fixtures/curried_caf.axi
  axionc/tests/fixtures/curried_partial.axi
  axionc/tests/fixtures/strings_text.axi
  axionc/tests/fixtures/heap_loop.axi
  axionc/tests/fixtures/linear_move.axi
  axionc/tests/fixtures/borrow_reclaim.axi
  axionc/tests/fixtures/update_borrow.axi
  axionc/tests/fixtures/arena_run.axi
  axionc/tests/fixtures/record_run.axi
  axionc/tests/fixtures/buffer_sum.axi
  axionc/tests/fixtures/array_sum.axi
  axionc/tests/fixtures/single_scope_reclaim.axi
  axionc/tests/fixtures/drift_reductions.axi
  axionc/tests/fixtures/drift_matvec.axi
  axionc/tests/fixtures/drift_codec.axi
  axionc/tests/fixtures/array_thread_let.axi
  axionc/tests/fixtures/array_thread_do.axi
  axionc/tests/fixtures/tritvec_roundtrip.axi
  axionc/tests/fixtures/tritvec_dot.axi
  axionc/tests/fixtures/tritvec_iota.axi
  axionc/tests/fixtures/tritvec_matvec.axi
  axionc/tests/fixtures/tritvec_from_buffer.axi
  axionc/tests/fixtures/i8array_matvec.axi
  axionc/tests/fixtures/i8array_run.axi
  axionc/tests/fixtures/array_reduce.axi
  axionc/tests/fixtures/i8_reduce.axi
  axionc/tests/fixtures/i8_dot_i8.axi
  axionc/tests/fixtures/i32array_run.axi
  axionc/tests/fixtures/i32_reduce.axi
  axionc/tests/fixtures/buffer_linear.axi
  axionc/tests/fixtures/inplace_update.axi
  axionc/tests/fixtures/native_case.axi
  axionc/tests/fixtures/native_closure.axi
  axionc/tests/fixtures/drop_view.axi
  axionc/tests/fixtures/stdlib_delete.axi
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
  axionc/tests/fixtures/poly_nested_list.axi
  axionc/tests/fixtures/session_run_parmap_heap.axi
  axionc/tests/fixtures/land_call_boxed.axi
  axionc/tests/fixtures/land_enum_call.axi
  axionc/tests/fixtures/land_deepdrop_safety.axi
  axionc/tests/fixtures/land_field_split_owned.axi
  axionc/tests/fixtures/land_field_mixed.axi
  axionc/tests/fixtures/land_owned_multi.axi
  axionc/tests/fixtures/make_bound_drop.axi
  axionc/tests/fixtures/make_bound_drop_local.axi
  axionc/tests/fixtures/tuple_owned.axi
  axionc/tests/fixtures/tuple_discard_owned.axi
  axionc/tests/fixtures/tuple_elem_discard.axi
  axionc/tests/fixtures/list_elem_borrow_reclaim.axi
  axionc/tests/fixtures/list_integer_discard.axi
  axionc/tests/fixtures/list_foldl_accum.axi
  axionc/tests/fixtures/embed_param_consume.axi
  axionc/tests/fixtures/filter_discard_reclaim.axi
  axionc/tests/fixtures/tuple_field_borrow_reclaim.axi
  axionc/tests/fixtures/tuple_nested_elem_reclaim.axi
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
  axionc/tests/fixtures/derive_ord.axi
  axionc/tests/fixtures/derive_eq.axi
  axionc/tests/fixtures/eqord_multiparam.axi
  examples/01_hello.axi
  examples/02_fib.axi
)

# PROVEN leak-free subset (heap/arena/borrow memory, no IO). The excluded ones
# leak by known and documented conservative reclamation:
#   · show/putStrLn → the runtime C-string is not reclaimed (heap vs. static
#     indistinguishable at drop): record_run, 01_hello, 02_fib.
#   · closure returned by a function → may be a borrowed param, not fresh;
#     reclaiming it would be unsound: native_closure, lambda_hof.
#   · `drop n xs` is a view — the caller relinquishes `xs` at the call (the
#     result shares its tail), so the dropped prefix leaks: drop_view.
# (integer_first_class + closure_consume_lambda + closure_data_elem + closure_acc_return —
# heap values flowing through a closure in map/foldr — are leak-free, closed by the
# closure-linearity arc: consuming HOFs own their list and the lifted lambda reclaims its
# owned heap params (types from the wrapped callable's signature for an eta lambda, or
# inferred at the `Pat::Var` span for a user lambda like `\x acc -> acc`). In LEAKFREE.)
LEAKFREE=(
  integer_first_class closure_consume_lambda closure_data_elem closure_acc_return closure_mono_hof
  closure_foldl closure_record_elem closure_nested_list closure_alias_combiner closure_discard_combiner closure_heaplist_combiner
  heap_loop linear_move borrow_reclaim update_borrow arena_run
  buffer_sum buffer_linear inplace_update native_case native_fib
  nested_drop sum_payload array_sum single_scope_reclaim array_thread_let array_thread_do tritvec_roundtrip tritvec_dot tritvec_iota tritvec_matvec tritvec_from_buffer i8array_matvec i8array_run array_reduce i8_reduce i8_dot_i8 i32array_run i32_reduce drift_reductions drift_matvec drift_codec
  poly_payload_drop poly_payload_tco poly_payload_borrow_alias
  poly_payload_generic_drop poly_payload_generic_nested poly_payload_generic_compose poly_payload_gap
  land_call_boxed land_enum_call land_deepdrop_safety land_field_split_owned land_field_mixed land_owned_multi make_bound_drop make_bound_drop_local tuple_owned tuple_discard_owned tuple_elem_discard list_elem_borrow_reclaim list_integer_discard list_foldl_accum embed_param_consume filter_discard_reclaim tuple_field_borrow_reclaim tuple_nested_elem_reclaim stdlib_batch stdlib_batch2 stdlib_sortby stdlib_batch3 land_tuple_upd land_owned_poly
  session_run_pingpong session_run_offer session_run_cancel
  session_run_twospawn session_run_choice3 session_run_fib session_run_parfib session_run_server
  poly_nested_list session_run_parmap_heap list_heap_reclaim strings_text data_heap_field
  record_update_reclaim record_update_multi record_update_chain
  record_update_escape record_update_escape_read integer_reclaim integer_accumulator
  field_alias_return integer_divmod rsa_modexp escape_local_borrow
  case_extract_escape tuple_extract_escape hof_unsigned_closure hof_lambda_closure hof_partial_closure curried_caf curried_partial
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
