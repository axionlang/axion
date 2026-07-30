# Axión

**Axión** é uma linguagem funcional de sistemas — **estrita, linear, sem GC** —
com sintaxe de Haskell, o determinismo de memória do Rust/C, e concorrência
**sem data races nem deadlocks provada por tipos**. A premissa: unir a elegância
do Haskell ao controlo do C, sem a rede do garbage collector nem os *lifetimes*
manuais.

O compilador (`axionc`) é escrito **de raiz em Rust**. A especificação mestra
está em [`spec/Axion-V0.2.pdf`](spec/Axion-V0.2.pdf) (legível:
[`.html`](spec/Axion-V0.2.html)).

> **Estado: marco publicável — Fases 0–3 do roteiro (§17) concluídas e
> _validadas_.** Memória segura sem GC e concorrência segura por tipos, ambas
> medidas, não afirmadas. Ver [Garantias, com evidência](#garantias-com-evidência).

## O que corre hoje

```sh
cd axionc && cargo build            # compilador puro em cargo (sem deps de LLVM p/ build)
AX=axionc/target/debug/axionc

$AX examples/01_hello.axi           # Hello, Axión!
$AX examples/02_fib.axi             # 832040
$AX examples/03b_fizzbuzz.axi       # 1  2  Fizz  4  Buzz  Fizz … FizzBuzz   (Listagem 1.3 da spec)
$AX --check examples/05_checksum_borrow.axi   # typecheck: linearidade + Auto-Drop

# concorrência a CORRER (sessão + spawn + canais, sem deadlock):
$AX axionc/tests/fixtures/session_run_pingpong.axi   # 42  (ping-pong concorrente 21→42)
```

Três executores para o mesmo programa, todos concordantes:

| Modo | O quê |
|------|-------|
| `axionc prog.axi` | **interpretador** (tree-walking) — o *fast-path* de `--dev` |
| `axionc --backend cranelift prog.axi` | **`--dev`**: JIT Cranelift (código-máquina, sem opt) |
| `axionc --release prog.axi` | **`--release`**: LLVM `-O2 -flto` + runtime C (competitivo com o C) |

Diagnósticos estilo `rustc` (span + label + sugestão de fix + JSON), com códigos
estáveis: `axionc --explain AX0001`.

**Novo aqui?** Segue o percurso guiado [**Axión by Example**](docs/by-example.md)
— L0→L3, um conceito de cada vez, cada passo a correr.

## Garantias, com evidência

Não afirmações — **medições**, sob CI:

| Promessa (spec §0) | Verificado por |
|---|---|
| *Sem uso-após-livre, sem dupla-free* | **AddressSanitizer** limpo em todas as fixtures nativas (`scripts/sanitize.sh`) |
| *Sem fugas de memória* | **LeakSanitizer**: `allocs == frees` no subconjunto provado |
| *Latência zero, controlo de C* | benchmarks: **`--release` ≈ C `-O2`** em fib/loop/simd |
| *Sem GC — libertação em pontos estáticos* | a **arena esmaga o `malloc`** (~10×) e o `Box` do Rust (~16×) no kernel de alocação |
| *Zero data races / deadlocks — por tipos* | linearidade (race-freedom) + topologia em árvore do `bound` (deadlock-freedom); ancorado a um **cálculo formal + model-checking de CFSMs** |
| *Linearidade fiel* | **diferencial contra o GHC** (Linear Haskell) — mesmo veredito em todos os cenários |

Benchmarks (ms, melhor de 5; mesmo `clang` para C e Axión `--release` —
[`docs/benchmarks.md`](docs/benchmarks.md)):

```
kernel  Ax --rel |  C -O2  Rs -O2
fib          250 |    251     298      (paridade / ganha)
loop         538 |    539     539      (paridade)
alloc         31 |    307     494      (arena: ~10× > malloc, ~16× > Box)
simd          33 |     32      31      (paridade)
```

## Como funciona (arquitetura)

Pipeline próprio, de raiz (nenhum estágio reutiliza o GHC):

```
fonte → lexer(logos) → layout → parser → AST
      → check.rs   (linearidade %1, Auto-Drop, arenas, sessões — os invariantes vivem aqui)
      → infer.rs   (HM, Algoritmo W)
      → core.rs    (Axión Core: IR estrito e linear em ANF; injeta o Auto-Drop)
      → interp.rs (--dev fast-path)  |  codegen.rs (Cranelift)  |  llvm.rs (LLVM --release)
```

- **Memória sem GC (§2/§3):** *Auto-Drop* insere `free` em pontos de morte estáticos
  (local, entre funções, empréstimos reclamados, in-place, e **deep-drop** recursivo
  de estruturas aninhadas); *arenas* com reset em massa e análise de escape.
- **Concorrência (§6/§9):** canais lineares + *session types*; o `bound` é um nursery
  cuja topologia acíclica dá deadlock-freedom por construção. O cálculo está
  formalizado em [`docs/phase-3-calculus.md`](docs/phase-3-calculus.md) **antes** do
  código, com um interpretador de referência e model-checking de CFSMs a validá-lo.

Mais detalhe em [`docs/backend.md`](docs/backend.md) e nos docs de fase.

## Estrutura

| Caminho | Papel |
|---------|-------|
| [`axionc/`](axionc/) | **O compilador**, de raiz em Rust. |
| [`spec/`](spec/) | A especificação mestra, versionada ao lado do código. |
| [`examples/`](examples/) | Programas `.axi` (Hello, fib, FizzBuzz, buffer linear, Listagem 2.1, empréstimos). |
| [`docs/by-example.md`](docs/by-example.md) | **Percurso guiado L0→L3** — a melhor porta de entrada para aprender. |
| [`docs/`](docs/) | Gramática, [códigos de erro](docs/error-codes.md), [backend](docs/backend.md), [benchmarks](docs/benchmarks.md), [cálculo de sessões](docs/phase-3-calculus.md), checklists de fase. |
| [`scripts/`](scripts/) | `sanitize.sh` (ASan/LSan), `differential.sh` (oráculo GHC), `bench.sh`. |
| [`prototype/`](prototype/) | Bancada EDSL descartável da Fase 0 (validou a linearidade em Linear Haskell). |
| [`bench/`](bench/), [`differential/`](differential/) | Kernels de benchmark; cenários do diferencial. |

## Testar

```sh
cd axionc && cargo test         # ~89 testes (integração + propriedade + sessões)
cargo clippy --all-targets      # limpo (-D warnings no CI)

# gates que precisam de clang (AXION_CLANG, ou clang no PATH):
AXION_CLANG=clang ../scripts/sanitize.sh      # ASan/LSan sobre o runtime nativo
../scripts/differential.sh                    # axionc vs oráculo GHC (precisa de Nix)
```

## Roteiro (§17)

- **Fase 0 — Fundações** ✅ — estratégia, repo, subconjunto mínimo, bancada EDSL.
- **Fase 1 — Esqueleto ambulante (L0/L1)** ✅ — `parse → typecheck → correr`; três
  executores; registos, tipos-soma (paramétricos), closures, FFI, listas/L0.
- **Fase 2 — Modelo de memória (o diferenciador)** ✅ *e provado* — Auto-Drop,
  arenas, `%0.5`, deep-drop; sanitizers em CI.
- **Fase 3 — Concorrência** ✅ *provada, ancorada e a correr* — cálculo formal →
  interpretador de referência + model-checking → typechecker (`AX0300`–`AX0305`) →
  runtime cooperativo (`bound`/`spawn`/canais/escolha/cancelamento).
- **Fase 4 — Ergonomia (LSP, erros que ensinam)** e **Fase 5 — ternário/topologia
  avançada** — futuro.

**Honestidade sobre o estado.** O núcleo entrega o que promete, mas há dívida
conhecida e documentada: `Integer`/bignum em falta (`factorial 20` corre, `50`
não); as features avançadas (sessões, arenas, listas com IO) correm no
interpretador, não no backend nativo; o scheduler é cooperativo, não M:N; a
metateoria ainda não está mecanizada (Iris/Actris). Nenhum destes é um buraco de
correção — são crescimento.

## Requisitos

- **Rust** (rustc estável) para o `axionc` — compila com `cargo` puro.
- **clang/LLVM** só em *runtime*, para o `--release` e os sanitizers (`AXION_CLANG`
  ou no PATH; p.ex. `nix shell nixpkgs#llvmPackages_18.clang`).
- **Nix** (opcional) para o diferencial GHC e o dev shell reprodutível ([`flake.nix`](flake.nix)).
