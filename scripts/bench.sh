#!/usr/bin/env bash
# Micro-benchmark (§13): fib(40) recursivo no backend nativo --dev (Cranelift,
# sem otimizações) vs C e Rust em -O0 e -O2. Honesto: o backend --dev é o
# fast-path SEM otimizações (§11) — o objectivo é situá-lo (par com -O0) e medir
# o gap que o backend --release (LLVM) terá de fechar.
set -uo pipefail
cd "$(dirname "$0")/.."

AXIONC="${AXIONC:-axionc/target/debug/axionc}"
RUNS="${RUNS:-3}"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

echo "A compilar o axionc e os baselines (C/Rust)…"
(cd axionc && cargo build -q) || exit 2
gcc -O0 -o "$tmp/c_o0" bench/fib.c || exit 2
gcc -O2 -o "$tmp/c_o2" bench/fib.c || exit 2
rustc -C opt-level=0 -o "$tmp/rs_o0" bench/fib.rs 2>/dev/null || exit 2
rustc -C opt-level=2 -o "$tmp/rs_o2" bench/fib.rs 2>/dev/null || exit 2

OUT=""
MS=""
# corre o comando RUNS vezes; deixa o menor tempo (ms) em MS e a stdout em OUT.
# (sem subshell, para os globais propagarem.)
timeit() {
  local best="" out="" t0 t1 ms
  for _ in $(seq "$RUNS"); do
    t0=$(date +%s%N)
    out=$("$@")
    t1=$(date +%s%N)
    ms=$(((t1 - t0) / 1000000))
    if [ -z "$best" ] || [ "$ms" -lt "$best" ]; then best=$ms; fi
  done
  MS=$best
  OUT=$out
}

declare -A T R
bench() {
  local key="$1"
  shift
  timeit "$@"
  T[$key]=$MS
  R[$key]=$OUT
}

bench axion "$AXIONC" --backend cranelift bench/fib.axi
bench c0 "$tmp/c_o0"
bench c2 "$tmp/c_o2"
bench r0 "$tmp/rs_o0"
bench r2 "$tmp/rs_o2"

echo
echo "fib(40) — melhor de $RUNS execuções:"
printf "  %-34s %8s   %s\n" "variante" "ms" "resultado"
printf "  %-34s %8s   %s\n" "Axión --dev (Cranelift, sem opt)" "${T[axion]}" "${R[axion]}"
printf "  %-34s %8s   %s\n" "C    -O0 (gcc)"                    "${T[c0]}"    "${R[c0]}"
printf "  %-34s %8s   %s\n" "C    -O2 (gcc)"                    "${T[c2]}"    "${R[c2]}"
printf "  %-34s %8s   %s\n" "Rust -O0 (rustc)"                  "${T[r0]}"    "${R[r0]}"
printf "  %-34s %8s   %s\n" "Rust -O2 (rustc)"                  "${T[r2]}"    "${R[r2]}"

echo
same=1
for k in c0 c2 r0 r2; do [ "${R[$k]}" = "${R[axion]}" ] || same=0; done
if [ "$same" -eq 1 ]; then
  echo "OK: todos os variantes produzem ${R[axion]} (fib 40)."
else
  echo "AVISO: os resultados divergem!"
  exit 1
fi
