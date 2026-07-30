# Benchmarks (§13) — Axion vs C vs Rust

> A spec é explícita: as garantias de performance são **desenho, não medição** —
> ficam «sob benchmark» (§13, §0). Medem-se os **dois** backends da Axion: `--dev`
> (Cranelift, fast-path §11) e `--release` (LLVM `-O2 -flto`, §18).

## Metodologia

- Cinco kernels, o mesmo algoritmo em cada linguagem (`bench/<kernel>.{axi,c,rs}`):
  - **fib** — `fib(40)` recursivo naive (compute / ramos).
  - **loop** — 200 M iterações aritméticas com `mod` (não-fechável pelo `-O2`).
    Na Axion é recursão (sem laços na linguagem); em C/Rust é um laço idiomático.
  - **alloc** — 40 M alocações. Na Axion via **arena** (§3, bump + reset em massa);
    em C via `malloc`/`free`, em Rust via `Box` — o idioma de cada linguagem.
  - **simd** — redução vectorizável sobre um array (200 M somas). Na Axion via a
    primitiva `sumBytes` sobre um `Buffer U8` linear (§4/§5) — o *escape-hatch*
    vectorizável (um laço no runtime que o `clang -O2` vectoriza e o `-flto`
    inlina); em C/Rust é o laço idiomático que o `-O2` auto-vectoriza.
  - **dispatch** — 200 M passos em que a operação quente é um **método de
    typeclasse**. Na Axion, `inner :: Stepper a =>` é genérica e a
    **monomorfização** (fatia 2b) especializa-a a `inner$Int` com `step → step$Int`,
    que o LLVM inlina; em **Rust** é genérica via *trait* (o Rust monomorfiza pelo
    mesmo mecanismo); em C é a chamada directa à mão. Mede a **abstração de
    custo-zero** — o genérico paga o mesmo que o escrito à mão?
- Harness: [`scripts/bench.sh`](../scripts/bench.sh) — melhor de 3, `date +%s%N`,
  e verifica que, por kernel, todas as variantes dão o mesmo resultado.
- **Escalão comparável:** o **mesmo `clang` (LLVM)** compila o C e o Axion
  `--release` (ambos `-O2 -flto`); o Rust é `rustc` (também LLVM). O tempo do
  Axion `--dev` inclui parse+typecheck+JIT (~ms), negligível.
- **O `-flto` é justo, não um truque:** medido, o `-flto` **não altera** os tempos
  do C em nenhum kernel (fib/loop são uma só unidade de compilação; no `alloc` o
  `malloc`/`free` vivem na libc, fora de qualquer LTO — logo não inlinam com ou
  sem `-flto`). A vantagem da arena é **estrutural** (bump-allocator inlinável vs
  alocador de heap geral na libc), não um artefacto de flags.

## Resultado (uma máquina, 8 cores; indicativo, não definitivo)

```
Tempos (ms, melhor de 3):
  kernel    Ax --dev Ax --rel |   C -O0   C -O2 |  Rs -O0  Rs -O2
  --------  -------- -------- |   -----   ----- |  ------  ------
  fib            666      252 |     590     252 |     840     323
  loop          3159      542 |    2243     550 |    2440     545
  alloc         1493       32 |     330     316 |    1085     495
  simd          1914       33 |     338      32 |     710      31
  dispatch      3488      563 |    2433     564 |    2485     561
```

## Leitura

- **Compute e laços — paridade com C.** No `fib` (255 ms) e no `loop` (538 ms), o
  Axion `--release` fica **a par do C `-O2`** (250 / 543) e do Rust `-O2` (304 /
  548). Baixa para o mesmo LLVM, com IR essencialmente igual; o `--release` faz
  TCO da recursão do `loop` num laço real.
- **Alocação — a arena ganha.** O modelo de arenas (§3) reclama em massa: 40 M
  células em **33 ms**, contra `malloc`/`free` do C `-O2` (314 ms, **~9×**) e
  `Box` do Rust `-O2` (502 ms, **~15×**). O `-flto` liga o runtime C na mesma
  compilação e **inlina o bump-allocator** no laço quente. É exactamente o cenário
  onde o modelo de memória da Axion deve brilhar — e onde a escolha de um runtime
  **C com `-flto`** (em vez de um `staticlib` Rust não-inlinável) se paga.
- **SIMD — paridade (buraco fechado).** A primitiva `sumBuffer` sobre um `Buffer`
  (§4) é um laço no runtime que o `clang -O2` **auto-vectoriza** e o `-flto`
  **inlina** no chamador: **34 ms**, a par do C `-O2` (33) e do Rust (35). É assim
  que uma linguagem funcional expõe SIMD — via primitivas vectorizáveis de dados
  em massa (o «escape-hatch imperativo» da §4), não via laços do utilizador.
- **Typeclasses — abstração de custo-zero, à Rust.** No `dispatch`, o método de
  classe no laço quente, monomorfizado (fatia 2b) e inlinado pelo LLVM, custa
  **563 ms** — a par do C `-O2` que chama a função à mão (**564 ms**) e do Rust
  `-O2` genérico via *trait* (**561 ms**), a **3 ms** uns dos outros. O genérico
  **não paga nada** por ser genérico: é exactamente a promessa «elegância do
  Haskell, controlo do Rust». A especialização é o mesmo mecanismo do Rust
  (monomorfização), não passagem de dicionários com indirecção.
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

- O `Buffer U8` é **linear** (`%1`, must-use), com in-place (`bufIota`/
  `xorInPlace`), leitura (`sumBytes`) e `free` — imposto pelo typechecker
  (consumir 2× → AX0001; largar → AX0002). Falta a **açúcar** de superfície
  (`imperative $ do`, `$`, `foldBytes (+)` com secções de operador) e o
  `withBuffer` como bracket — para correr o `examples/03`/`05` tal-e-qual.
- Kernels sintéticos; faltam cargas mistas maiores e I/O.
- Números variam por máquina/carga; usar como ordem de grandeza, não absolutos.
