# Fase 0 — Decisões e fundações (checklist)

> §17 da spec. «Fixar âmbito e infraestrutura antes de uma linha de compilador.»
> O código Haskell é uma **bancada de validação semântica descartável**, não o
> embrião do compilador. O `axionc` real (Rust) nasce na Fase 1 (§18).

## Passos da Fase 0 (§17)

- [x] **Decisão-chave (estratégia).** EDSL sobre Linear Haskell (`LinearTypes` +
  `linear-base`) para validar a semântica em semanas — protótipo descartável.
  Registada em memória de projecto; ver também [`../README.md`](../README.md).
  - **Limites da bancada** (assumidos): o EDSL só valida o núcleo `%1` (L0/L1).
    `%0.5`, `&`, `~` e session types **não** são exprimíveis no `LinearTypes` do
    GHC (multiplicidades só nas setas) → Fase 3 (trilho formal) + typechecker
    próprio.
- [x] **`git init`, projeto Cabal, CI, formatador, linter.**
  - Repo git inicializado; spec versionada ao lado do código em [`../spec`](../spec).
  - Projeto Cabal: [`../axion-prototype.cabal`](../axion-prototype.cabal) (lib +
    exe + test-suite).
  - Dev shell reprodutível (NixOS): [`../flake.nix`](../flake.nix).
  - CI: [`../.github/workflows/ci.yml`](../.github/workflows/ci.yml).
  - Formatador: `fourmolu` ([`../fourmolu.yaml`](../fourmolu.yaml)).
    Linter: `hlint` ([`../.hlint.yaml`](../.hlint.yaml)).
- [x] **Gramática mínima (L0/L1) + programas-alvo.**
  - Gramática: [`grammar.md`](grammar.md).
  - 5 programas-alvo: [`../examples`](../examples).
- [x] **Spec versionada ao lado do código.** [`../spec`](../spec).

## As primeiras 2 semanas (§17) — estado

- [x] `git init` + projeto Cabal do protótipo EDSL com `LinearTypes` ligado.
- [x] Escrever os 5 programas-alvo Axión que definem «sucesso da Fase 1»
  ([`../examples`](../examples)).
- [x] Protótipo EDSL: um `Buffer %1` que o typechecker recusa usar duas vezes.
  - Positivo: [`../prototype/src/Axion/Prototype/Buffer.hs`](../prototype/src/Axion/Prototype/Buffer.hs)
    + [`Examples.hs`](../prototype/src/Axion/Prototype/Examples.hs) — compila e corre.
  - Negativo: [`../prototype/test/negative/UseTwice.hs`](../prototype/test/negative/UseTwice.hs)
    — **não compila por design**; `scripts/check-negative.sh` exige a falha.
- [x] Montar CI + a estrutura de property tests (o andaime, não os testes ainda).
  - `tasty` + `tasty-quickcheck`: [`../prototype/test/Spec.hs`](../prototype/test/Spec.hs).
- [x] Registo de códigos de erro estáveis semeado (§8, feito cedo de propósito):
  [`error-codes.md`](error-codes.md) — `AX0001`–`AX0003`.

## Verificação (tudo corre no dev shell do flake)

```sh
nix develop --command cabal build all               # compila lib+exe+test
nix develop --command cabal run -v0 axion-prototype # imprime o checksum (42) e o byte (7)
nix develop --command cabal test                    # 3 testes: 2 unidade + 1 propriedade (100 casos)
nix develop --command ./scripts/check-negative.sh   # EXIGE que Buffer %1 usado 2x falhe (AX0001)
nix develop --command fourmolu --mode check prototype
nix develop --command hlint prototype
```

Estado actual: **build ✅ · run ✅ · test ✅ · negativo ✅ · fourmolu ✅ · hlint ✅**
(GHC 9.8.4, `linear-base` 0.4.0).

## O que NÃO pertence à Fase 0 (evitar scope creep)

- Parser / typechecker / backend próprios → **Fase 1** (em Rust, de raiz).
- Auto-Drop, arenas, `%0.5`, benchmarks → **Fase 2**.
- Canais, session types, runtime M:N, trilho formal → **Fase 3**.
- LSP, `--explain`, playground, níveis L0–L3 impostos → **Fase 4**.
- `TritVec` (ternário), `~`/`Maybe~` (topologia avançada) → **Fase 5a/5b**.
