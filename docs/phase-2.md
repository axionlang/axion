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
  - **Propagação estrutural de `Drop`** (ponto-fixo): um `data` é must-use se
    algum campo (recursivamente) o for — um registo que contém um `Ep`/`Token`
    não pode ser auto-dropped (`AX0002`).
  - **Drops de valores `let`**: um `let v = <e que consome um recurso linear>`
    torna `v` um recurso linear no seu âmbito; se `v` não for consumido,
    Auto-Drop (droppable) ou `AX0002` (must-use) — não só parâmetros.
  - **Mutação in-place (Linear Elision)**: uma actualização de registo cujo base
    é um recurso linear (a sua última menção viva) é marcada como in-place;
    `axionc --emit inplace` mostra-as (ex.: `04` → `p { status = … }`).
  - **Por crescer:** provenance através de retornos de função arbitrários (só o
    move directo é seguido); `where`-binds de valor; a elisão realmente aplicada
    no backend (por agora é análise + relatório, não codegen).
- [~] **Arenas + reset NLL + análise de escape** (`promote`, §3). Listagem 3.3–3.5.
  - **Lambdas** (`\x -> e`) adicionadas (parser, inferência, travessias do
    check); necessárias para `withSubArena parent (\sub -> …)`.
  - Builtins de arena tipados: `withSubArena :: Arena -> (Arena -> a) -> a`,
    `allocateCell :: Arena -> Cell`, `promote :: Arena -> Cell -> Cell` (o arg
    da arena é emprestado — allocateCell/promote lêem-na muitas vezes).
  - **Escape (`AX0003`)** — por **retorno** ou por **captura em closure** (§3C):
    rastreio de proveniência de região; `promote parent v` corta a proveniência.
    `arena_escape.axi` (retorno) e `arena_capture.axi` (closure) → `AX0003`;
    `arena_promote_ok.axi` → aceite.
  - **Reset NLL** (Fig. 3.1): o reset da sub-arena é computado no **ponto de
    morte** da região (a última menção viva de um valor da sub-arena), não no
    fim léxico. `axionc --emit arenas` mostra-o (ex.: `arena_promote_ok` →
    reset após a última menção de `node`, na promoção).
  - **`arena_mark`/`arena_release`** (reclamação intra-escopo, Listagem 3.6):
    `mark = arena_mark arena` guarda o topo do bump-pointer; `arena_release mark`
    recupera tudo o que foi alocado depois. Uma análise ordenada sobre a espinha
    de `let` rejeita usar, **após** o release, um valor alocado sob a marca
    (`AX0005`). `arena_mark_release.axi` → `AX0005`; `arena_mark_ok.axi` (uso
    antes do release) → aceite.
  - **Lambdas correm** no interpretador (`\x -> e` vira uma closure de uma
    cláusula) — funções de ordem superior e currying funcionam
    (`tests/fixtures/lambda_hof.axi`).
  - **Por crescer:** o runtime das arenas em si (`allocateCell`/`withSubArena`/
    `promote`/`arena_mark`/`arena_release` seriam no-ops num interpretador
    tree-walking — a reclamação real só é observável no backend nativo, o mesmo
    pré-requisito dos benchmarks; as arenas continuam validadas estaticamente).
- [ ] **Permissões fracionárias** (`%0.5`): `split` / `join` (§2).
- [ ] **Benchmark vs baseline (C/Rust)** — precisa do backend nativo
  (Cranelift/LLVM), ainda adiado; a «latência zero» tem de ser medida.

## Verificação (Auto-Drop)

```sh
cd axionc
cargo test                                            # 20 testes (inclui Auto-Drop)
cargo run -- --check tests/fixtures/drop_linear.axi   # Token must-use → AX0002
cargo run -- --check tests/fixtures/struct_mustuse.axi # registo com Ep → AX0002 (estrutural)
cargo run -- --check tests/fixtures/let_leak.axi      # let must-use largado → AX0002
cargo run -- --emit drops tests/fixtures/let_drop.axi # free(b2) — drop de valor 'let'
cargo run -- --emit inplace ../examples/04_process_inplace.axi  # 'p' mutado in-place
cargo run -- --check tests/fixtures/use_after_move.axi # sink x + x → AX0004
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
