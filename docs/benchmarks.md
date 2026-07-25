# Benchmarks (§13) — nativo vs C/Rust

> A spec é explícita: as garantias de performance são **desenho, não medição** —
> ficam «sob benchmark» (§13, §0). Este é o primeiro ponto de medição, agora que
> o backend nativo `--dev` (Cranelift) corre código-máquina.

## Metodologia

- Micro-benchmark **compute-bound**: `fib(40)` recursivo naive (`bench/fib.axi`,
  `bench/fib.c`, `bench/fib.rs`) — mesmo algoritmo em Axión, C e Rust.
- Harness: [`scripts/bench.sh`](../scripts/bench.sh). Melhor de 3 execuções
  (menor tempo), `date +%s%N`. Verifica que todos produzem `102334155`.
- Baselines: `gcc` `-O0`/`-O2`, `rustc` `-C opt-level=0`/`2`.
- **Honestidade:** o backend `--dev` é o *Fast-Path* — Cranelift com
  `opt_level=none` (compila instantâneo, §11). O caminho otimizado é o
  `--release`/LLVM (§18), **ainda não construído**. Logo compara-se «sem opt vs
  sem opt» (`-O0`) e mede-se o *gap* até `-O2`.
- O tempo do Axión inclui parse+typecheck+JIT (~ms), negligível face à execução
  de `fib(40)` (centenas de ms).

## Resultado (uma máquina, 8 cores; indicativo, não definitivo)

```
fib(40) — melhor de 3 execuções:
  variante                                 ms   resultado
  Axión --dev (Cranelift, sem opt)       591   102334155
  C    -O0 (gcc)                          692   102334155
  C    -O2 (gcc)                          198   102334155
  Rust -O0 (rustc)                        833   102334155
  Rust -O2 (rustc)                        303   102334155
```

## Leitura

- O fast-path `--dev` (Cranelift **sem** otimizações) já é **mais rápido que
  C -O0 (~1.17×) e Rust -O0 (~1.41×)** — o codegen base do Cranelift é sólido.
- Está a **~2–3×** do `-O2` (C 198 ms, Rust 303 ms). Esse é o *gap* que o backend
  **`--release` (LLVM)** existe para fechar — é lá que vivem as afirmações de
  «latência zero», não no `--dev`.
- Não é uma vitória de performance absoluta (nem o pretende ser em `--dev`): é a
  confirmação de que o *fast-path instantâneo* não sacrifica ordens de grandeza,
  ao contrário de um interpretador tree-walking.

## Reproduzir

```sh
./scripts/bench.sh          # fib(40), melhor de 3
RUNS=5 ./scripts/bench.sh   # mais execuções
```

## Limitações / a fazer

- Um único micro-benchmark (recursão pura). Faltam: alocação/registos, laços,
  aritmética vectorizável (onde o `imperative`/SIMD da §4 brilharia).
- Sem `--release` (LLVM) ainda — a comparação justa com `-O2` fica para aí.
- Números variam por máquina/carga; usar como ordem de grandeza.
