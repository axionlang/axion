# Benchmarks (§13) — Axión vs C vs Rust

> A spec é explícita: as garantias de performance são **desenho, não medição** —
> ficam «sob benchmark» (§13, §0). Medem-se os **dois** backends da Axión: `--dev`
> (Cranelift, fast-path §11) e `--release` (LLVM `-O2 -flto`, §18).

## Metodologia

- Quatro kernels, o mesmo algoritmo em cada linguagem (`bench/<kernel>.{axi,c,rs}`):
  - **fib** — `fib(40)` recursivo naive (compute / ramos).
  - **loop** — 200 M iterações aritméticas com `mod` (não-fechável pelo `-O2`).
    Na Axión é recursão (sem laços na linguagem); em C/Rust é um laço idiomático.
  - **alloc** — 40 M alocações. Na Axión via **arena** (§3, bump + reset em massa);
    em C via `malloc`/`free`, em Rust via `Box` — o idioma de cada linguagem.
  - **simd** — redução vectorizável sobre um array. **Axión N/A**: precisa de
    `Buffer`/`imperative` (§4), ainda por construir no backend.
- Harness: [`scripts/bench.sh`](../scripts/bench.sh) — melhor de 3, `date +%s%N`,
  e verifica que, por kernel, todas as variantes dão o mesmo resultado.
- **Escalão comparável:** o **mesmo `clang` (LLVM)** compila o C e o Axión
  `--release` (ambos `-O2 -flto`); o Rust é `rustc` (também LLVM). O tempo do
  Axión `--dev` inclui parse+typecheck+JIT (~ms), negligível.
- **O `-flto` é justo, não um truque:** medido, o `-flto` **não altera** os tempos
  do C em nenhum kernel (fib/loop são uma só unidade de compilação; no `alloc` o
  `malloc`/`free` vivem na libc, fora de qualquer LTO — logo não inlinam com ou
  sem `-flto`). A vantagem da arena é **estrutural** (bump-allocator inlinável vs
  alocador de heap geral na libc), não um artefacto de flags.

## Resultado (uma máquina, 8 cores; indicativo, não definitivo)

```
Tempos (ms, melhor de 3):
  kernel  Ax --dev Ax --rel |   C -O0   C -O2 |  Rs -O0  Rs -O2
  ------  -------- -------- |   -----   ----- |  ------  ------
  fib          611      270 |     625     258 |     824     304
  loop        3151      545 |    2246     548 |    2485     545
  alloc       1573       35 |     333     319 |    1262     564
  simd         n/a      n/a |    3653     145 |   14782     198
```

## Leitura

- **Compute e laços — paridade com C.** No `fib` (270 ms) e no `loop` (545 ms), o
  Axión `--release` fica **a par do C `-O2`** (258 / 548) e do Rust `-O2` (304 /
  545). Baixa para o mesmo LLVM, com IR essencialmente igual; o `--release` faz
  TCO da recursão do `loop` num laço real.
- **Alocação — a arena ganha.** O modelo de arenas (§3) reclama em massa: 40 M
  células em **35 ms**, contra `malloc`/`free` do C `-O2` (319 ms, **~9×**) e
  `Box` do Rust `-O2` (564 ms, **~16×**). O `-flto` liga o runtime C na mesma
  compilação e **inlina o bump-allocator** no laço quente. É exactamente o cenário
  onde o modelo de memória da Axión deve brilhar — e onde a escolha de um runtime
  **C com `-flto`** (em vez de um `staticlib` Rust não-inlinável) se paga.
- **SIMD — o buraco assumido.** A redução vectorizável é onde o C/Rust `-O2`
  auto-vectorizam (145 / 198 ms) e a Axión não compete: **não há `Buffer`/arrays
  nem `imperative` (§4)** no backend ainda. É trabalho futuro declarado, não uma
  limitação de desenho.
- **`--dev` é o fast-path, não o veloz.** Sem otimizações nem TCO, paga a
  recursão no `loop` (3151 ms) e a chamada opaca ao runtime no `alloc` (1573 ms).
  O seu papel é compilar **instantâneo** para o ciclo edit-run; a performance vive
  no `--release`.

Confirma a premissa dos **dois backends** (§11/§18): Cranelift para o ciclo
edit-run instantâneo, LLVM para performance competitiva com C em release.

## Reproduzir

```sh
AXION_CLANG=/caminho/clang ./scripts/bench.sh        # tabela completa
AXION_CLANG=$(nix eval --raw nixpkgs#llvmPackages_18.clang)/bin/clang \
  RUNS=5 ./scripts/bench.sh
```

O `--release` (e o baseline C) precisam do `clang` — via `AXION_CLANG` ou no PATH
(p.ex. `nix shell nixpkgs#llvmPackages_18.clang`).

## Limitações / a fazer

- **SIMD/vectorização (§4):** falta `Buffer`/arrays e `imperative` no backend —
  o único kernel onde a Axión ainda não compete.
- Kernels sintéticos; faltam cargas mistas maiores e I/O.
- Números variam por máquina/carga; usar como ordem de grandeza, não absolutos.
