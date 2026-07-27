#!/usr/bin/env bash
# Sanitizers no runtime nativo (§2/§11): a proposta de valor da Axión é memória
# segura sem GC, por isso o runtime tem de correr limpo sob os sanitizers do
# LLVM. Dois portões, sobre o LLVM IR que o backend --release emite + o runtime C:
#
#   1. CORRUPÇÃO (AddressSanitizer, todas as fixtures nativas): zero
#      uso-após-livre / dupla-free. É a garantia dura ("sem uso-após-livre").
#   2. FUGAS (LeakSanitizer, subconjunto provado sem-fugas): allocs == frees.
#      Exclui fixtures cuja fuga é conservadora e conhecida (ver LEAKY abaixo).
#
# Correr:  AXION_CLANG=<clang> ./scripts/sanitize.sh
set -uo pipefail
cd "$(dirname "$0")/.."

CLANG="${AXION_CLANG:-clang}"
if ! "$CLANG" --version >/dev/null 2>&1; then
  echo "sem clang (define AXION_CLANG ou põe clang no PATH) — a saltar sanitizers"
  exit 0
fi

AXIONC="axionc/target/debug/axionc"
if [ ! -x "$AXIONC" ]; then
  echo "a compilar o axionc..."
  (cd axionc && cargo build -q) || { echo "falha a compilar"; exit 2; }
fi
RT="axionc/src/axion_rt.c"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Fixtures nativas (main :: Int/IO) — o portão de corrupção corre todas as que
# o backend --release consegue baixar; as --check-only saltam-se sozinhas.
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
  examples/01_hello.axi
  examples/02_fib.axi
)

# Subconjunto PROVADO sem fugas (memória de heap/arena/empréstimo, sem IO). As
# excluídas vazam por reclamação conservadora conhecida e documentada:
#   · show/putStrLn → a C-string do runtime não é reclamada (heap vs. estática
#     indistinguíveis no drop): record_run, 01_hello, 02_fib.
#   · closure devolvida por função → pode ser um param emprestado, não fresca;
#     reclamá-la seria insound: native_closure, lambda_hof.
LEAKFREE=(
  heap_loop linear_move borrow_reclaim update_borrow arena_run
  buffer_sum buffer_linear inplace_update native_case native_fib
  nested_drop sum_payload
)
is_leakfree() { local n; for n in "${LEAKFREE[@]}"; do [ "$n" = "$1" ] && return 0; done; return 1; }

compile() { # <axi> <out> → emite LLVM e compila com ASan/LSan; 0 se nativa
  "$AXIONC" --emit llvm "$1" >"$WORK/ir.ll" 2>/dev/null || return 1
  "$CLANG" -fsanitize=address,leak -O1 -w "$WORK/ir.ll" "$RT" -o "$2" 2>/dev/null
}

fail=0; corr=0; leak=0
for f in "${NATIVE[@]}"; do
  [ -f "$f" ] || continue
  name=$(basename "$f" .axi)
  exe="$WORK/$name.san"
  if ! compile "$f" "$exe"; then
    echo "· $name: não é subconjunto nativo (saltada)"
    continue
  fi
  # portão de corrupção (fugas desligadas)
  if ! ASAN_OPTIONS=detect_leaks=0 "$exe" >/dev/null 2>"$WORK/e"; then
    echo "✗ $name: CORRUPÇÃO de memória sob ASan"; grep -E 'ERROR|SUMMARY' "$WORK/e" | head -2; fail=1; continue
  fi
  corr=$((corr + 1))
  # portão de fugas (só no subconjunto provado)
  if is_leakfree "$name"; then
    if ASAN_OPTIONS=detect_leaks=1 "$exe" >/dev/null 2>"$WORK/e"; then
      echo "✓ $name: ASan + LSan limpo"; leak=$((leak + 1))
    else
      echo "✗ $name: FUGA sob LSan (devia ser sem-fugas)"; grep -E 'SUMMARY' "$WORK/e" | head -1; fail=1
    fi
  else
    echo "✓ $name: ASan limpo (fuga conservadora conhecida — fora do portão)"
  fi
done

echo "---"
if [ "$fail" -eq 0 ]; then
  echo "OK: $corr fixtures sem corrupção; $leak provadas sem fugas."
else
  echo "FALHA: regressão de memória detetada."
fi
exit $fail
