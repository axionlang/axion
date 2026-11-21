#!/usr/bin/env bash
# Sanitizers on the native runtime (§2/§11): Axion's value proposition is memory
# safety without a GC, so the runtime must run clean under the LLVM sanitizers.
# Two gates, over the LLVM IR the --release backend emits + the C runtime:
#
#   1. CORRUPTION (AddressSanitizer, all native fixtures): zero
#      use-after-free / double-free. This is the hard guarantee ("no use-after-free").
#   2. LEAKS (LeakSanitizer, every native fixture): allocs == frees. There is no exempt
#      subset: a fixture that leaks fails the gate.
#
# Run:  AXION_CLANG=<clang> ./scripts/sanitize.sh [fixture.axi …]
#
# With arguments, only those files are checked (each must be on the NATIVE list below, so a
# file that is not leak-gated cannot be passed in by mistake); without, every native fixture.
set -uo pipefail
cd "$(dirname "$0")/.."

CLANG="${AXION_CLANG:-clang}"
if ! "$CLANG" --version >/dev/null 2>&1; then
  echo "no clang (set AXION_CLANG or put clang on PATH) — skipping sanitizers"
  exit 0
fi

AXIONC="${AXIONC:-axionc/target/debug/axionc}"
if [ ! -x "$AXIONC" ]; then
  echo "building axionc..."
  (cd axionc && cargo build -q) || { echo "build failed"; exit 2; }
fi
# The Rust runtime staticlib (axion-rt: bignum + strings/IO + OS-capability, growing as the C→Rust
# port proceeds); build + link it so the moved symbols resolve. See docs/rust-runtime-port.md.
cargo build -q --release --manifest-path axion-rt/Cargo.toml || { echo "axion-rt build failed"; exit 2; }
RT_A="axion-rt/target/release/libaxion_rt.a"
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
  axionc/tests/fixtures/record_update_base_dies_first.axi
  axionc/tests/fixtures/axmpv_regressions.axi
  axionc/tests/fixtures/ffi_consumed_handle_scalar_let.axi
  axionc/tests/fixtures/layout_paren_in.axi
  axionc/tests/fixtures/buffer_borrow_one_branch.axi
  axionc/tests/fixtures/nested_mixed_cond.axi
  axionc/tests/fixtures/axmpv_m7_regressions.axi
  axionc/tests/fixtures/sharing_regressions.axi
  axionc/tests/fixtures/closure_live_moves.axi
  axionc/tests/fixtures/bitwise.axi
  axionc/tests/fixtures/bitwise_user_xor.axi
  axionc/tests/fixtures/nested_patterns_native.axi
  axionc/tests/fixtures/nested_borrowed_embed.axi
  axionc/tests/fixtures/view_arm_owned_scrutinee.axi
  axionc/tests/fixtures/or_patterns.axi
  axionc/tests/fixtures/accessor_keeps_arg.axi
  axionc/tests/fixtures/let_local_functions.axi
  axionc/tests/fixtures/bits_complement_popcount.axi
  axionc/tests/fixtures/bits_user_complement.axi
  axionc/tests/fixtures/bits_user_ops_prelude.axi
  axionc/tests/fixtures/borrowed_tuple_field_consume.axi
  axionc/tests/fixtures/uncons_peel_tuple_reject.axi
  axionc/tests/fixtures/integer_reclaim.axi
  axionc/tests/fixtures/integer_accumulator.axi
  axionc/tests/fixtures/integer_divmod.axi
  axionc/tests/fixtures/rsa_modexp.axi
  axionc/tests/fixtures/integer_first_class.axi
  axionc/tests/fixtures/num_user_instance.axi
  axionc/tests/fixtures/num_constrained_poly.axi
  axionc/tests/fixtures/num_literal_overload.axi
  axionc/tests/fixtures/user_eq_ord.axi
  axionc/tests/fixtures/user_integral.axi
  axionc/tests/fixtures/layout_paren_case.axi
  axionc/tests/fixtures/layout_paren_case_multiline.axi
  axionc/tests/fixtures/layout_paren_let.axi
  axionc/tests/fixtures/layout_paren_do.axi
  axionc/tests/fixtures/layout_semi_case.axi
  axionc/tests/fixtures/layout_semi_do.axi
  examples/rational.axi
  axionc/tests/fixtures/stdlib_batch.axi
  axionc/tests/fixtures/stdlib_batch2.axi
  axionc/tests/fixtures/stdlib_sortby.axi
  axionc/tests/fixtures/stdlib_batch3.axi
  axionc/tests/fixtures/stdlib_unzip.axi
  axionc/tests/fixtures/either_discard.axi
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
  axionc/tests/fixtures/grab_case_field.axi
  axionc/tests/fixtures/tuple_cond_return_reuse.axi
  axionc/tests/fixtures/nested_tuple_extract_escape.axi
  axionc/tests/fixtures/escape_local_borrow.axi
  axionc/tests/fixtures/case_extract_escape.axi
  axionc/tests/fixtures/land_cond_owned_temp.axi
  axionc/tests/fixtures/basename_borrowed_elem.axi
  axionc/tests/fixtures/tuple_extract_escape.axi
  axionc/tests/fixtures/land_borrowing_copier.axi
  axionc/tests/fixtures/clause_param_borrow.axi
  axionc/tests/fixtures/view_case_in_branch.axi
  axionc/tests/fixtures/tuple_param_borrow.axi
  axionc/tests/fixtures/filter_in_case_scrutinee.axi
  axionc/tests/fixtures/hof_closure_param.axi
  axionc/tests/fixtures/hof_unsigned_closure.axi
  axionc/tests/fixtures/hof_lambda_closure.axi
  axionc/tests/fixtures/hof_partial_closure.axi
  axionc/tests/fixtures/curried_caf.axi
  axionc/tests/fixtures/curried_partial.axi
  axionc/tests/fixtures/strings_text.axi
  axionc/tests/fixtures/string_compare.axi
  axionc/tests/fixtures/capability_sanitize.axi
  axionc/tests/fixtures/readline_sanitize.axi
  axionc/tests/fixtures/readkey_sanitize.axi
  axionc/tests/fixtures/readkeytimeout_sanitize.axi
  axionc/tests/fixtures/chr_sanitize.axi
  axionc/tests/fixtures/cond_temp_reclaim.axi
  examples/axfm.axi
  examples/lambda.axi
  examples/typecheck.axi
  examples/gauss.axi
  examples/json.axi
  axionc/tests/fixtures/hello_cli.axi
  axionc/tests/fixtures/cond_escape_let.axi
  axionc/tests/fixtures/heap_loop.axi
  axionc/tests/fixtures/linear_move.axi
  axionc/tests/fixtures/borrow_reclaim.axi
  axionc/tests/fixtures/update_borrow.axi
  axionc/tests/fixtures/arena_run.axi
  axionc/tests/fixtures/record_run.axi
  axionc/tests/fixtures/buffer_sum.axi
  axionc/tests/fixtures/buffer_roundtrip.axi
  axionc/tests/fixtures/ffi_ptr.axi
  axionc/tests/fixtures/division_operator.axi
  axionc/tests/fixtures/buffer_ptr_checked.axi
  axionc/tests/fixtures/buffer_borrow.axi
  axionc/tests/fixtures/ffi_struct.axi
  axionc/tests/fixtures/ffi_enum.axi
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
  axionc/tests/fixtures/float_array_dot.axi
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
  axionc/tests/fixtures/peel_heap_reclaim.axi
  axionc/tests/fixtures/structural_borrowers_reclaim.axi
  axionc/tests/fixtures/take_heap_reclaim.axi
  axionc/tests/fixtures/tuple_element_extract_reclaim.axi
  axionc/tests/fixtures/uncons_safe_tuple_read.axi
  axionc/tests/fixtures/do_monad_bind.axi
  axionc/tests/fixtures/either_map_reclaim.axi
  axionc/tests/fixtures/mixed_param_return_reclaim.axi
  axionc/tests/fixtures/mixed_param_return_integer.axi
  axionc/tests/fixtures/container_copy_reclaim.axi
  axionc/tests/fixtures/borrowed_list_elem_consume.axi
  axionc/tests/fixtures/dead_binding_reclaim.axi
  axionc/tests/fixtures/sort_heap_reclaim.axi
  axionc/tests/fixtures/where_local_unlines.axi
  axionc/tests/fixtures/neg_literals.axi
  axionc/tests/fixtures/neg_nonbreaking.axi
  axionc/tests/fixtures/float_forms.axi
  axionc/tests/fixtures/prelude_either_batch.axi
  axionc/tests/fixtures/cond_owned_temp.axi
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
  axionc/tests/fixtures/session_heap_reclaim.axi
  axionc/tests/fixtures/session_let_stmt.axi
  axionc/tests/fixtures/session_channel_heap.axi
  axionc/tests/fixtures/session_case_data.axi
  axionc/tests/fixtures/borrowed_result_lifetime.axi
  axionc/tests/fixtures/let_case_field_or_literal.axi
  axionc/tests/fixtures/generic_discard_reclaim.axi
  axionc/tests/fixtures/partial_type_con_reclaim.axi
  axionc/tests/fixtures/residual_leak_reclaim.axi
  axionc/tests/fixtures/borrowed_passthrough_reclaim.axi
  axionc/tests/fixtures/record_update_shared_fields.axi
  axionc/tests/fixtures/hof_clone_borrows_list.axi
  axionc/tests/fixtures/integer_field_reclaim.axi
  axionc/tests/fixtures/view_consumes_reclaim.axi
  axionc/tests/fixtures/closure_reclaim.axi
  axionc/tests/fixtures/tuple_scalar_reader.axi
  axionc/tests/fixtures/eq_constraint_dispatch.axi
  axionc/tests/fixtures/constrained_closures.axi
  axionc/tests/fixtures/array_heap_elems.axi
  axionc/tests/fixtures/closure_escape_owned.axi
  axionc/tests/fixtures/closure_in_structures.axi
  axionc/tests/fixtures/closure_fuzz_regressions.axi
  axionc/tests/fixtures/closure_fields.axi
  axionc/tests/fixtures/file_read_chunks.axi
  axionc/tests/fixtures/not_equal.axi
  axionc/tests/fixtures/field_handoff_consume.axi
  axionc/tests/fixtures/cond_branch_drop_reclaim.axi
  axionc/tests/fixtures/derive_ord.axi
  axionc/tests/fixtures/derive_eq.axi
  axionc/tests/fixtures/eqord_multiparam.axi
  examples/01_hello.axi
  examples/02_fib.axi
)


compile() { # <axi> <out> → emits LLVM and compiles with ASan/LSan; 0 if native
  "$AXIONC" --emit llvm "$1" >"$WORK/ir.ll" 2>/dev/null || return 1
  "$CLANG" -fsanitize=address,leak -pthread -O1 -w "$WORK/ir.ll" "$RT_A" -ldl -lm -o "$2" 2>/dev/null
}

# fff is an INTERACTIVE TUI: run bare, it reads EOF and quits immediately, so the gate would only
# ever test startup. Drive it with a key stream over a seeded, sandboxed HOME so the ASan corruption
# gate actually exercises the operational paths (nav, scroll, search, mkdir/mkfile/rename/chmod, go-
# dir, mark+paste, attributes). Exact outcomes don't matter here — we only assert NO corruption; a
# failed op's modal just eats the next key / EOF. The same drive runs the leak gate.
FFF_DRIVE='jkgG.oJK/note\n;,nMADE\nfTOUCHED\nrRENAMED\nX:sub\nypxgdpyui.bbt][T3jBb'
run_asan() { # <name> <exe> <detect_leaks 0|1> → run under ASan; stderr→$WORK/e; return exit code
  if [ "$1" = axfm ]; then
    local H="$WORK/fffhome"; rm -rf "$H"; mkdir -p "$H/sub"
    : >"$H/a.txt"; : >"$H/b.txt"; printf 'line1\nline2\nline3\n' >"$H/note.txt"
    printf '%b' "$FFF_DRIVE" | HOME="$H" ASAN_OPTIONS=detect_leaks=$3 "$2" "$H" >/dev/null 2>"$WORK/e"
  else
    ASAN_OPTIONS=detect_leaks=$3 "$2" </dev/null >/dev/null 2>"$WORK/e"
  fi
}

if [ "$#" -gt 0 ]; then
  only=()
  for a in "$@"; do
    for f in "${NATIVE[@]}"; do
      if [ "$f" = "$a" ]; then only+=("$f"); fi
    done
  done
  NATIVE=("${only[@]+"${only[@]}"}")
fi

fail=0; corr=0; leak=0
for f in "${NATIVE[@]}"; do
  [ -f "$f" ] || continue
  name=$(basename "$f" .axi)
  exe="$WORK/$name.san"
  if ! compile "$f" "$exe"; then
    echo "· $name: not in the native subset (skipped)"
    continue
  fi
  # corruption gate (leaks off) — fff is driven with a key stream (see run_asan)
  if ! run_asan "$name" "$exe" 0; then
    echo "✗ $name: memory CORRUPTION under ASan"; grep -E 'ERROR|SUMMARY' "$WORK/e" | head -2; fail=1; continue
  fi
  corr=$((corr + 1))
  # leak gate (every fixture)
  if run_asan "$name" "$exe" 1; then
    echo "✓ $name: ASan + LSan clean"; leak=$((leak + 1))
  else
    echo "✗ $name: LEAK under LSan"; grep -E 'SUMMARY' "$WORK/e" | head -1; fail=1
  fi
done

echo "---"
if [ "$fail" -eq 0 ]; then
  echo "OK: $corr fixtures without corruption; $leak leak-free (every native fixture is leak-gated)."
else
  echo "FAILURE: memory regression detected."
fi
exit $fail
