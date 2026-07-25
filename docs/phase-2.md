# Fase 2 — Modelo de memória (o diferenciador) (checklist)

> §17 da spec. «O que torna a Axión ≠ só mais um Haskell»: segurança de memória
> **sem GC**. Construída por incrementos, cada um testado e commitado.

## Pilares (§17)

- [~] **Auto-Drop** — análise de *liveness* que injecta `free` no ponto de morte
  (§2). **Liveness fina feita** (`axionc/src/check.rs`):
  - **Empréstimo vs consumo** (Elisão de Empréstimos, §2): *ler* um `%1` é livre
    e ilimitado; *consumir* (arg `%1`, campo `%1`, retorno) é no máximo uma vez.
    A posição de cada ocorrência decide. Daí: consumos >1 ⇒ `AX0001`; consumos
    ==0 e must-use ⇒ `AX0002`; consumos ==0 e droppable ⇒ Auto-Drop; ==1 ⇒
    posse transferida, sem drop.
  - **Ponto de morte fino**: o `free` é injectado na **última leitura** (não "à
    entrada"), ou à entrada se o recurso nunca for lido. `axionc --emit drops`
    mostra o local e a razão (`morre após a última leitura` / `à entrada`).
  - `examples/04` (Listagem 2.1): `p` é consumido (record update) ⇒ **sem** drop.
    `x + x` (duas leituras) ⇒ aceite, drop após o 2.º `x`. `(x, x)` (dois
    consumos) ⇒ `AX0001`.
  - **Ordem verificada** (`AX0004` uso-após-move): uma travessia na ordem de
    avaliação marca quando `x` é movido; qualquer leitura/consumo posterior é
    erro. `x + sink x` (ler antes de consumir) é aceite; `sink x + x` (ler
    depois) é `AX0004`.
  - **Por crescer:** drops de valores ligados em `let`/`where` (não só
    parâmetros); propagação estrutural de `Drop` (registo droppable sse todos
    os campos o forem); mutação in-place (Linear Elision).
- [ ] **Arenas + reset NLL + análise de escape** (`promote`, §3) — validar que o
  escape é erro de compilação (`AX0003`, já reservado). Listagem 3.3–3.5.
- [ ] **Permissões fracionárias** (`%0.5`): `split` / `join` (§2).
- [ ] **Benchmark vs baseline (C/Rust)** — precisa do backend nativo
  (Cranelift/LLVM), ainda adiado; a «latência zero» tem de ser medida.

## Verificação (Auto-Drop)

```sh
cd axionc
cargo test                                            # 16 testes (inclui Auto-Drop)
cargo run -- --check tests/fixtures/drop_linear.axi   # Token must-use → AX0002
cargo run -- --check tests/fixtures/drop_ok.axi       # Buf droppable → aceite
cargo run -- --emit drops tests/fixtures/drop_ok.axi  # free(b) : Buf %1 (à entrada)
cargo run -- --emit drops tests/fixtures/borrow_twice_ok.axi  # free(x) após a última leitura
cargo run -- --check tests/fixtures/use_after_consume.axi     # (x,x): 2 consumos → AX0001
cargo run -- --check tests/fixtures/use_after_move.axi        # sink x + x → AX0004
```

Diferencial: o cenário `differential/02_consume_twice` **move** o `%1` duas
vezes (`(x, x)`), não o lê duas vezes — ler seria aceite. O `03_drop_unused`
usa `Token` (must-use) de propósito: um droppable seria aceite pelo Auto-Drop
mas o GHC rejeitá-lo-ia (não tem Elisão de Empréstimos nem Auto-Drop). Ambas as
restrições mantêm `axionc` e GHC concordantes.

## Impacto no registo de erros

`AX0002` passou de «qualquer `%1` não consumido» para «apenas **must-use** não
consumido» — tipos droppable são geridos pelo Auto-Drop. Ver
[`error-codes.md`](error-codes.md).
