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
  - **simd** — redução vectorizável sobre um array (200 M somas). Na Axión via a
    primitiva `sumBuffer` sobre um `Buffer` (§4) — o *escape-hatch* vectorizável
    (um laço no runtime que o `clang -O2` vectoriza e o `-flto` inlina); em C/Rust
    é o laço idiomático que o `-O2` auto-vectoriza.
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
Tempos (ms, melhor de 2):
  kernel  Ax --dev Ax --rel |   C -O0   C -O2 |  Rs -O0  Rs -O2
  ------  -------- -------- |   -----   ----- |  ------  ------
  fib          582      255 |     597     250 |     816     304
  loop        3096      538 |    2222     543 |    2424     548
  alloc       1544       33 |     328     314 |    1131     502
  simd        2117       34 |     340      33 |     718      35
```

## Leitura

- **Compute e laços — paridade com C.** No `fib` (255 ms) e no `loop` (538 ms), o
  Axión `--release` fica **a par do C `-O2`** (250 / 543) e do Rust `-O2` (304 /
  548). Baixa para o mesmo LLVM, com IR essencialmente igual; o `--release` faz
  TCO da recursão do `loop` num laço real.
- **Alocação — a arena ganha.** O modelo de arenas (§3) reclama em massa: 40 M
  células em **33 ms**, contra `malloc`/`free` do C `-O2` (314 ms, **~9×**) e
  `Box` do Rust `-O2` (502 ms, **~15×**). O `-flto` liga o runtime C na mesma
  compilação e **inlina o bump-allocator** no laço quente. É exactamente o cenário
  onde o modelo de memória da Axión deve brilhar — e onde a escolha de um runtime
  **C com `-flto`** (em vez de um `staticlib` Rust não-inlinável) se paga.
- **SIMD — paridade (buraco fechado).** A primitiva `sumBuffer` sobre um `Buffer`
  (§4) é um laço no runtime que o `clang -O2` **auto-vectoriza** e o `-flto`
  **inlina** no chamador: **34 ms**, a par do C `-O2` (33) e do Rust (35). É assim
  que uma linguagem funcional expõe SIMD — via primitivas vectorizáveis de dados
  em massa (o «escape-hatch imperativo» da §4), não via laços do utilizador.
- **`--dev` é o fast-path, não o veloz.** Sem otimizações nem TCO, paga a
  recursão no `loop` (3096 ms), a chamada opaca ao runtime no `alloc` (1544 ms) e
  o `sumBuffer` **não-vectorizado** do runtime Rust do axionc em debug no `simd`
  (2117 ms). O seu papel é compilar **instantâneo** para o ciclo edit-run; a
  performance vive no `--release`.

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

- O `Buffer` (§4) é por agora um 1.º corte (`iota`/`sumBuffer`/`freeBuffer`,
  irrestrito); o `Buffer %1` linear com `imperative`/`foldBytes`/`xorInPlace`
  (§4/§5) é o passo seguinte.
- Kernels sintéticos; faltam cargas mistas maiores e I/O.
- Números variam por máquina/carga; usar como ordem de grandeza, não absolutos.
