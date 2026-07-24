# `axionc` — o compilador da Axión (Fase 1)

O compilador **próprio** da Axión, escrito **de raiz em Rust** (§18). Ao
contrário da bancada EDSL descartável da Fase 0 (`../prototype`, em Haskell),
isto é o produto: cresce daqui até à auto-hospedagem.

Esta é a **Fase 1 — esqueleto ambulante** (§17): não entrega uma feature, mas o
ciclo completo **`parse → typecheck → correr`** num subconjunto mínimo (L0/L1).
Tudo o resto cresce daí.

## Pipeline

```
.axi ─▶ lexer ─▶ layout ─▶ parser ─▶ check ────▶ infer ────▶ interp
       (logos)  (indent.)  (AST)    (nomes +     (tipos HM;  (tree-walking;
                                     linearidade) AX0200)     futuro fast-path --dev)
                                        │           │
                                        ▼           ▼
                              diagnósticos AXnnnn (texto | JSON, §8)
```

| Módulo | Papel |
|--------|-------|
| `src/lexer.rs` | Tokens com `logos` + tabela de linhas para spans. |
| `src/layout.rs` | Regra de layout (indentação → chavetas/`;` virtuais). |
| `src/parser.rs` | Recursivo-descendente → AST (`src/ast.rs`). |
| `src/check.rs` | Resolução de nomes (`AX0101`) + **linearidade** (`AX0001`/`AX0002`). |
| `src/infer.rs` | **Inferência de tipos** HM / Algoritmo W (`AX0200`/`AX0201`). |
| `src/interp.rs` | Interpretador tree-walking. |
| `src/diag.rs` | Diagnósticos `AXnnnn` estáveis: render texto (estilo rustc) e JSON. |

Adiado por decisão (arquitectura "AST enxuto primeiro"): `salsa` (motor
incremental) e `rowan` (CST lossless) entram quando o LSP/incrementalidade
valerem o custo (Fase 4/8); os backends nativos `cranelift`/LLVM vêm depois.

## Usar

```sh
cargo build
cargo run -- ../examples/01_hello.axi      # imprime: Hello, Axión!
cargo run -- ../examples/02_fib.axi        # imprime: 832040
cargo run -- --check <ficheiro.axi>        # só parse + typecheck + linearidade
cargo run -- --emit json <ficheiro.axi>    # diagnósticos em JSON (§8)
cargo run -- --explain AX0001              # explica um código de erro
cargo test                                 # testes de integração
```

## A meta da Fase 1 (§17)

> «A Listagem 2.1 compila e corre; um uso-após-consumo é rejeitado.»

Estado do esqueleto ambulante:
- **Corre** (`examples/01_hello.axi`, `examples/02_fib.axi`): literais, funções
  com múltiplas cláusulas e pattern matching, recursão, aritmética, `where`,
  aplicação, `IO` (`putStrLn`/`show`).
- **Rejeita** uso-após-consumo de um `%1` com `AX0001`
  (`tests/fixtures/use_after_consume.axi`), e um `%1` largado com `AX0002`.

Ainda **não** cobre (crescem a partir daqui): `data`/registos e a Listagem 2.1
completa, inferência de tipos HM, Auto-Drop, arenas, `%0.5`, backend nativo.
