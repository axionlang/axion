# Axión — Fase 0 (Fundações)

**Axión** é uma linguagem funcional de sistemas — estrita, linear, sem GC —
especificada em [`spec/Axion-V0.2.pdf`](spec/Axion-V0.2.pdf) (versão legível:
[`spec/Axion-V0.2.html`](spec/Axion-V0.2.html)). Este repositório começa pela
**Fase 0** do plano de implementação (§17 da spec).

> **O que a Fase 0 é — e o que não é.** A Fase 0 fixa âmbito e infraestrutura
> *antes de uma linha de compilador*. O código Haskell aqui é uma **bancada de
> validação semântica descartável** (EDSL sobre `LinearTypes` + `linear-base`),
> **não** o embrião do compilador. O `axionc` real nasce na Fase 1, escrito **de
> raiz em Rust** (§18). O Haskell serve só para validar, barato e em semanas, a
> regra da linearidade antes do grande build.

## Estrutura

| Caminho | Papel |
|---------|-------|
| [`spec/`](spec/) | A especificação, versionada ao lado do código (§17). |
| [`axionc/`](axionc/) | **O compilador próprio (Fase 1), de raiz em Rust:** `parse → typecheck → correr`. |
| [`prototype/`](prototype/) | Protótipo EDSL descartável (Fase 0): o `Buffer %1` que o typechecker recusa usar duas vezes. |
| [`examples/`](examples/) | Os **5 programas-alvo** `.axi` que definem «sucesso da Fase 1». |
| [`docs/grammar.md`](docs/grammar.md) | Gramática mínima do subconjunto L0/L1. |
| [`docs/error-codes.md`](docs/error-codes.md) | Registo de códigos de erro `AXnnnn` estáveis (semente). |
| [`docs/phase-0.md`](docs/phase-0.md) | Checklist da Fase 0 e o que fica para a Fase 1. |
| [`flake.nix`](flake.nix) | Dev shell reprodutível (GHC + `linear-base` + tooling) para NixOS/Nix. |

## Como correr (precisa de Nix com flakes)

```sh
# entrar no dev shell (traz GHC, linear-base, cabal, fourmolu, hlint, HLS)
nix develop

# dentro do shell:
cabal build all            # biblioteca + executável + testes
cabal run axion-prototype  # corre o fio linear e imprime o checksum
cabal test                 # unidade + andaime de propriedades (tasty)
./scripts/check-negative.sh  # EXIGE que Buffer %1 usado 2x falhe (AX0001)
```

Ou numa linha, sem entrar no shell: `nix develop --command cabal test`.

## A garantia central desta fase

O ficheiro [`prototype/test/negative/UseTwice.hs`](prototype/test/negative/UseTwice.hs)
**não compila por design**: usa um `Buffer %1` duas vezes e o typechecker
rejeita-o. É o análogo, na bancada, do diagnóstico `AX0001` (uso-após-consumo)
que o compilador próprio emitirá na Fase 1. O CI trata a *não-compilação* deste
ficheiro como um teste que tem de passar.

## Roteiro (§17)

- **Fase 0 — Fundações** ✅: estratégia, repo, subconjunto mínimo, bancada EDSL.
- **Fase 1 — Esqueleto ambulante (L0/L1)** ← *estás aqui*: `axionc` mínimo em
  Rust ([`axionc/`](axionc/)), `parse → typecheck → correr`. **Esqueleto
  ambulante feito**: `examples/01_hello` e `02_fib` correm; uso-após-consumo é
  rejeitado com `AX0001`. A crescer: `data`/registos + Listagem 2.1 completa,
  inferência de tipos, os restantes `examples/`. Ver [`docs/phase-1.md`](docs/phase-1.md).
- **Fase 2 — Modelo de memória** ← *estás aqui*: **Auto-Drop** (fino, estrutural,
  `let`, in-place, uso-após-move), **arenas** (escape `AX0003`, reset NLL, marcas
  `AX0005`), **`%0.5`** (split/join, `AX0006`). Ver [`docs/phase-2.md`](docs/phase-2.md).
- **Backend nativo `--dev`** (§11/§18) ← *começou*: **Cranelift JIT** do núcleo
  Int (`--backend cranelift`, `--emit clif`). Ver [`docs/backend.md`](docs/backend.md).
- **Fase 3 — Concorrência**: canais + session types, com trilho formal.
- **Fase 4+ — Tooling, ternário (`TritVec`), topologia avançada.**
