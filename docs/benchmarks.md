# Benchmarks (§13) — nativo vs C/Rust

> A spec é explícita: as garantias de performance são **desenho, não medição** —
> ficam «sob benchmark» (§13, §0). Medem-se agora os **dois** backends: `--dev`
> (Cranelift, fast-path §11) e `--release` (LLVM `-O2`, §18).

## Metodologia

- Micro-benchmark **compute-bound**: `fib(40)` recursivo naive (`bench/fib.axi`,
  `bench/fib.c`, `bench/fib.rs`) — mesmo algoritmo em Axión, C e Rust.
- Harness: [`scripts/bench.sh`](../scripts/bench.sh). Melhor de 3 execuções
  (menor tempo), `date +%s%N`. Verifica que todos produzem `102334155`.
- Baselines: `gcc` `-O0`/`-O2`, `rustc` `-C opt-level=0`/`2`.
- **Dois backends da Axión:** `--dev` = Cranelift `opt_level=none` (compila
  instantâneo, §11); `--release` = baixa o **mesmo Core IR** para LLVM IR textual
  e compila com `clang -O2` (§18). Ambos JIT/nativo, código-máquina real.
- O tempo do Axión inclui parse+typecheck+codegen (~ms), negligível face à
  execução de `fib(40)` (centenas de ms).

## Resultado (uma máquina, 8 cores; indicativo, não definitivo)

```
fib(40) — melhor de 5 execuções:
  variante                                 ms   resultado
  Axión --dev (Cranelift, sem opt)       978   102334155
  Axión --release (LLVM -O2)             433   102334155
  C    -O0 (gcc)                         1140   102334155
  C    -O2 (gcc)                          319   102334155
  Rust -O0 (rustc)                        507   102334155   (rustc -O)
```

E na comparação **mesmo compilador** (o `fib.c` compilado com o *mesmo* clang-18):

```
  Axión --release (LLVM -O2)             424
  C (clang-18 -O2)                       422    ← paridade
```

## Leitura

- O fast-path `--dev` (Cranelift **sem** otimizações) já bate C/Rust `-O0` — o
  codegen base do Cranelift é sólido.
- O **`--release` (LLVM `-O2`)** corta o tempo do `--dev` para ~metade e **entra
  no escalão `-O2`**. Com o *mesmo* compilador (clang), fica **a par do C**
  (424≈422 ms) — como esperado: baixa para o mesmo LLVM, com IR essencialmente
  igual. (O `gcc -O2` gera aqui código um pouco melhor que o `clang -O2` para
  este `fib` — daí o C -O2/gcc parecer à frente; é diferença de compilador, não
  de linguagem.)
- Confirma a premissa dos **dois backends** (§11/§18): Cranelift para o ciclo
  edit-run instantâneo, LLVM para performance **competitiva com C** em release.

## Reproduzir

```sh
./scripts/bench.sh                       # fib(40), --dev vs C/Rust
AXION_CLANG=/caminho/clang RUNS=5 \
  ./scripts/bench.sh                     # inclui a linha --release (LLVM -O2)
```

O `--release` precisa do `clang` (via `AXION_CLANG` ou no PATH; p.ex. `nix shell
nixpkgs#llvmPackages_18.clang`). Sem ele, a linha `--release` é saltada.

## Limitações / a fazer

- Um único micro-benchmark (recursão pura). Faltam: alocação/registos/arenas,
  laços, aritmética vectorizável (onde o `imperative`/SIMD da §4 brilharia).
- O `--release` cobre por agora o **núcleo Int** (suficiente para o `fib`);
  registos/closures/strings/arenas em `--release` crescem a seguir (do mesmo
  Core, com um pequeno runtime C).
- Números variam por máquina/carga; usar como ordem de grandeza.
