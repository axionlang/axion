#!/usr/bin/env bash
# Suíte de micro-benchmarks (§13): compara os DOIS backends da Axion — --dev
# (Cranelift, sem opt) e --release (LLVM -O2 -flto) — contra C e Rust em -O0/-O2.
# Kernels: fib (recursão/ramos), loop (200M iterações aritméticas), alloc (40M
# alocações — arena na Axion, malloc/Box em C/Rust), simd (redução vectorizável;
# Axion N/A — §4 por construir). Usa o MESMO clang (LLVM) para o C e para o
# Axion --release, para o escalão ser comparável. Precisa de clang (AXION_CLANG
# ou no PATH; p.ex. `nix shell nixpkgs#llvmPackages_18.clang`).
set -uo pipefail
cd "$(dirname "$0")/.."

AXIONC="${AXIONC:-axionc/target/debug/axionc}"
CLANG="${AXION_CLANG:-clang}"
RT="axionc/src/axion_rt.c"
RUNS="${RUNS:-3}"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

echo "A compilar o axionc…"
(cd axionc && cargo build -q) || exit 2
command -v "$CLANG" >/dev/null 2>&1 || { echo "clang não encontrado (define AXION_CLANG)"; exit 2; }
have_rust=1; command -v rustc >/dev/null 2>&1 || have_rust=0

# timeit CMD…  → menor tempo (ms) em MS, stdout em OUT (melhor de RUNS).
timeit() {
  local best="" out t0 t1 ms
  for _ in $(seq "$RUNS"); do
    t0=$(date +%s%N); out=$("$@"); t1=$(date +%s%N)
    ms=$(((t1 - t0) / 1000000))
    if [ -z "$best" ] || [ "$ms" -lt "$best" ]; then best=$ms; fi
  done
  MS=$best; OUT=$out
}

declare -A T R           # T[kernel:variante]=ms   R[kernel:variante]=resultado
run() { local key="$1"; shift; if [ "$1" = "SKIP" ]; then T[$key]="-"; R[$key]=""; return; fi
        timeit "$@"; T[$key]=$MS; R[$key]=$OUT; }

bench_kernel() {
  local k="$1"
  # Axion --dev (JIT)
  run "$k:dev" "$AXIONC" --backend cranelift "bench/$k.axi"
  # Axion --release (LLVM -O2 -flto)
  if "$AXIONC" --emit llvm "bench/$k.axi" > "$tmp/$k.ll" 2>/dev/null \
     && "$CLANG" -O2 -flto -w "$tmp/$k.ll" "$RT" -o "$tmp/${k}_rel" 2>/dev/null; then
    run "$k:rel" "$tmp/${k}_rel"
  else run "$k:rel" SKIP; fi
}
bench_c() {
  local k="$1"
  "$CLANG" -O0 "bench/$k.c" -o "$tmp/${k}_c0" 2>/dev/null && run "$k:c0" "$tmp/${k}_c0" || run "$k:c0" SKIP
  "$CLANG" -O2 "bench/$k.c" -o "$tmp/${k}_c2" 2>/dev/null && run "$k:c2" "$tmp/${k}_c2" || run "$k:c2" SKIP
}
bench_rust() {
  local k="$1"; [ "$have_rust" = 1 ] || { run "$k:r0" SKIP; run "$k:r2" SKIP; return; }
  rustc -C opt-level=0 "bench/$k.rs" -o "$tmp/${k}_r0" 2>/dev/null && run "$k:r0" "$tmp/${k}_r0" || run "$k:r0" SKIP
  rustc -C opt-level=2 "bench/$k.rs" -o "$tmp/${k}_r2" 2>/dev/null && run "$k:r2" "$tmp/${k}_r2" || run "$k:r2" SKIP
}

KERNELS="fib loop alloc simd dispatch"
for k in $KERNELS; do bench_kernel "$k"; bench_c "$k"; bench_rust "$k"; done

echo
echo "Tempos (ms, melhor de $RUNS) — o mesmo clang (LLVM) para C e para Axion --release:"
printf "  %-7s %8s %8s | %7s %7s | %7s %7s\n" "kernel" "Ax --dev" "Ax --rel" "C -O0" "C -O2" "Rs -O0" "Rs -O2"
printf "  %-7s %8s %8s | %7s %7s | %7s %7s\n" "------" "--------" "--------" "-----" "-----" "------" "------"
for k in fib loop alloc simd dispatch; do
  printf "  %-7s %8s %8s | %7s %7s | %7s %7s\n" "$k" \
    "${T[$k:dev]}" "${T[$k:rel]}" "${T[$k:c0]}" "${T[$k:c2]}" "${T[$k:r0]}" "${T[$k:r2]}"
done

echo
# verifica correção: por kernel, todos os resultados presentes têm de coincidir.
ok=1
for k in fib loop alloc simd dispatch; do
  ref=""
  for v in dev rel c0 c2 r0 r2; do
    r="${R[$k:$v]:-}"; [ -n "$r" ] || continue
    if [ -z "$ref" ]; then ref="$r"; elif [ "$r" != "$ref" ]; then
      echo "AVISO: $k/$v = '$r' ≠ '$ref'"; ok=0
    fi
  done
done
[ "$ok" = 1 ] && echo "OK: em cada kernel, todas as variantes concordam no resultado." || exit 1
