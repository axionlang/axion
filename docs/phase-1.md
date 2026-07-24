# Fase 1 — Esqueleto ambulante (núcleo L0/L1) (checklist)

> §17 da spec. «O compilador mínimo que corre um programa linear.» Princípio #1:
> não entrega uma feature, mas `parse → typecheck → correr` de ponta a ponta num
> subconjunto mínimo. Tudo cresce daí. O `axionc` é escrito **de raiz em Rust**
> (§18); a bancada EDSL da Fase 0 (`../prototype`) fica como oráculo semântico.

## Passos da Fase 1 (§17)

- [x] **Parser do subconjunto mínimo** (tipos, funções, `let`, `%1`).
  `axionc/src/{lexer,layout,parser}.rs`. Cobre L0/L1: assinaturas com `%1`,
  cláusulas com pattern matching, `where`, `let`/`in`, `case`, `if`, aplicação,
  aritmética. Ver [`grammar.md`](grammar.md).
- [x] **Códigos de erro estáveis + diagnósticos estruturados (JSON)** desde o
  primeiro erro (§8). `axionc/src/diag.rs`; registo em
  [`error-codes.md`](error-codes.md). `--emit json` e `--explain AXnnnn`.
- [x] **Typechecker próprio com linearidade.** `axionc/src/check.rs`: resolução
  de nomes (`AX0101`) + análise de linearidade (`AX0001` uso-após-consumo,
  `AX0002` largado sem consumo). É o mesmo invariante validado na bancada da
  Fase 0 (`../prototype/test/negative/UseTwice.hs`).
  - **Validado por diferencial** contra o oráculo GHC: `differential/` +
    `scripts/differential.sh` correm cada cenário nos dois verificadores e
    exigem o mesmo veredito. Estado: 3 cenários, concordância total.
- [x] **Inferência de tipos (HM / Algoritmo W).** `axionc/src/infer.rs`:
  variáveis de tipo, unificação com occurs-check, esquemas, generalização em
  `let`/`where`, tipos dos builtins, registos (construção/actualização/
  selectores). Corre a par da linearidade; emite `AX0200` (incompatibilidade) e
  `AX0201` (tipo infinito). Funções com assinatura são verificadas em modo de
  *checking* (parâmetros herdam os tipos declarados).
- [x] **Baixar para um backend: interpretador próprio** (o futuro fast-path de
  `--dev`). `axionc/src/interp.rs` (tree-walking). Backend nativo
  (Cranelift/LLVM) fica para a fase seguinte.
- [~] **Meta:** «a Listagem 2.1 compila e corre; um uso-após-consumo é
  rejeitado. Property tests a verificar preservação/progresso.»
  - Rejeição de uso-após-consumo: **feito** (`AX0001`), incl. sobre registos
    (`tests/fixtures/record_use_twice.axi`).
  - Correr programas: **feito** para `examples/01_hello.axi`, `02_fib.axi`, e
    registos (`tests/fixtures/record_run.axi`: construção, actualização, selector).
  - **Listagem 2.1 (`examples/04`) compila** (`--check`): `data`/registos com
    campo linear `%1`, actualização de registo `p { status = ... }`, param
    `Process %1` consumido uma vez. Não *corre* por não ter `main` e usar
    `Buffer` nativo (Fase 2); a semântica de registos está validada por
    `record_run.axi`.
  - **Property tests de preservação/progresso: feito.** `axionc/src/props.rs`
    gera termos bem-tipados por construção (Int/Bool: aritmética, comparações,
    `if`, `let`+variáveis) e verifica, em 4000 termos aleatórios: (1) o
    typechecker aceita-os, (2) avaliam sem encravar (**progresso**), (3) o valor
    tem o tipo estático (**preservação**). Não-vacuidade confirmada por mutação.

## Verificação

```sh
cd axionc
cargo test                                  # 6 testes de integração
cargo run -- ../examples/01_hello.axi        # Hello, Axión!
cargo run -- ../examples/02_fib.axi          # 832040
cargo run -- --check tests/fixtures/use_after_consume.axi   # AX0001, exit 1
cargo run -- --check tests/fixtures/use_once_ok.axi         # OK, exit 0
```

Estado: **esqueleto ambulante ✅** (parse→typecheck→run + rejeição de
linearidade). GHC não é preciso aqui — o `axionc` é Rust puro (`cargo`).

## O que vem a seguir dentro da Fase 1 (crescer o esqueleto)

- `data`/registos + a Listagem 2.1 completa (campo `%1`, mutação in-place).
- Inferência de tipos (HM) para além da checagem de linearidade.
- Property tests de preservação/progresso (o andaime existe na bancada Fase 0).
- Diferencial contra a bancada EDSL: mesmos programas, mesmo veredicto.

## O que fica para fases seguintes (evitar scope creep)

- Auto-Drop, arenas, `%0.5`, benchmarks → **Fase 2**.
- `salsa` (incremental) + `rowan` (CST lossless) + LSP → **Fase 4/8**.
- Backend nativo Cranelift (`--dev`) / LLVM (`--release`) → **Fase 2+**.
