# Fase 2 — Modelo de memória (o diferenciador) (checklist)

> §17 da spec. «O que torna a Axión ≠ só mais um Haskell»: segurança de memória
> **sem GC**. Construída por incrementos, cada um testado e commitado.

## Pilares (§17)

- [~] **Auto-Drop** — análise de *liveness* que injecta `free` no ponto de morte
  (§2). **Primeiro corte feito** (`axionc/src/check.rs`):
  - Regra refinada: um `%1` **droppable** é consumido *quando muito uma vez*
    (0 usos ⇒ Auto-Drop injecta `free`, sem erro); um `%1` **must-use** (sem
    `Drop`: `Ep`, `Token`, handles) é *exactamente uma vez* (0 usos ⇒ `AX0002`).
    Contracção (>1) continua `AX0001`.
  - Relatório dos `free` injectados: `axionc --emit drops <ficheiro>`.
  - `examples/04` (Listagem 2.1): `p` é consumido (record update), logo **sem**
    drop injectado — como esperado.
  - **Por crescer:** liveness fino (ponto de morte = última utilização, não só
    "à entrada"); drops de valores ligados em `let`/`where` (não só parâmetros);
    propagação estrutural de `Drop` (registo droppable sse todos os campos o
    forem); mutação in-place quando a última menção é uma actualização.
- [ ] **Arenas + reset NLL + análise de escape** (`promote`, §3) — validar que o
  escape é erro de compilação (`AX0003`, já reservado). Listagem 3.3–3.5.
- [ ] **Permissões fracionárias** (`%0.5`): `split` / `join` (§2).
- [ ] **Benchmark vs baseline (C/Rust)** — precisa do backend nativo
  (Cranelift/LLVM), ainda adiado; a «latência zero» tem de ser medida.

## Verificação (Auto-Drop)

```sh
cd axionc
cargo test                                        # 13 testes (inclui Auto-Drop)
cargo run -- --check tests/fixtures/drop_linear.axi  # Token must-use → AX0002
cargo run -- --check tests/fixtures/drop_ok.axi      # Buf droppable → aceite
cargo run -- --emit drops tests/fixtures/drop_ok.axi # mostra free(b) : Buf %1
```

Diferencial: o cenário `differential/03_drop_unused` usa `Token` (must-use) de
propósito — um droppable seria aceite pelo Auto-Drop mas o GHC rejeitá-lo-ia; a
restrição a must-use mantém `axionc` e GHC concordantes.

## Impacto no registo de erros

`AX0002` passou de «qualquer `%1` não consumido» para «apenas **must-use** não
consumido» — tipos droppable são geridos pelo Auto-Drop. Ver
[`error-codes.md`](error-codes.md).
