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
- [x] **Baixar para um backend: interpretador próprio** (o futuro fast-path de
  `--dev`). `axionc/src/interp.rs` (tree-walking). Backend nativo
  (Cranelift/LLVM) fica para a fase seguinte.
- [~] **Meta:** «a Listagem 2.1 compila e corre; um uso-após-consumo é
  rejeitado. Property tests a verificar preservação/progresso.»
  - Rejeição de uso-após-consumo: **feito** (`AX0001`).
  - Correr programas: **feito** para `examples/01_hello.axi` e `02_fib.axi`.
  - Listagem 2.1 *completa* (registos com campo `%1`, mutação in-place): **por
    fazer** — precisa de `data`/registos e mais typechecking; cresce a partir
    do esqueleto.

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
