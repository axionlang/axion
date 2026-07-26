# Backend nativo — o «Fast-Path» de `--dev` (Cranelift)

> §11/§18 da spec. O pipeline baixa o AST para o **Axión Core IR** (ANF,
> estrito/linear — ver `axionc/src/core.rs`) e daí emite código nativo:
> **Cranelift em `--dev`** (compila depressa — «zero otimizações em dev») e
> **LLVM em `--release`** (`axionc --release`; baixa o mesmo Core para LLVM IR
> textual e compila com `clang -O2 -flto` + um pequeno runtime C — a par do C, ver
> [benchmarks](benchmarks.md)). Ambos partilham o mesmo Core e cobrem o **mesmo
> subconjunto** (Int, registos/tuplos, strings/IO, `case`, closures, arenas,
> Auto-Drop). Vê-se o Core com `axionc --emit core` e o LLVM IR com
> `axionc --emit llvm`.

Este backend `--dev`, sobre `cranelift-jit`, é um **mero emissor Core→Cranelift**:
o desugar de multi-cláusula, o *lifting* de `where` e a conversão de closures já
aconteceram na baixada AST→Core, pelo que o codegen só percorre o ANF.

## O que compila (núcleo Int)

- Funções de topo com assinatura `Int` (params + retorno), **multi-cláusula**
  com padrões variável/`_`/**literal** — desugaradas numa cadeia de `if` (exige
  uma cláusula catch-all no fim). Ex.: `fib 0 = 0; fib 1 = 1; fib n = …`.
- **`where`**: os locais (ex.: `go`) são *liftados* para funções nativas com
  nome mangled (`fibFast$go`) e compilados, com recursão e recursão mútua.
- `if … then … else …`, aritmética (`+ - *`, `mod`), comparações (`== < >`).
- Chamadas a outras funções nativas, **incluindo recursão**.
- `let v = <Int> in …`.
- **Strings / IO** (via runtime mínimo): literais de string (objectos de dados,
  C-strings), `show :: Int -> String` (`axion_show_int`), `putStrLn :: String ->
  IO ()` (`axion_puts`). Assim `main :: IO ()` corre nativamente — inclusive os
  **exemplos reais** `examples/01_hello.axi` («Hello, Axión!») e
  `examples/02_fib.axi` («832040»), com o mesmo output do interpretador.
- **Registos** e **tuplos** na heap (`axion_alloc`): construção `Con { f = … }`
  / `(a, b)`, actualização `r { f = … }` (aloca e copia) e selectores `f r`
  (load do offset); cada campo/componente é um `i64`. Funções com params/retorno
  de tipo `data` (ponteiro) compilam. `record_run.axi` corre nativo (→ 99).
- **`case`**: cadeia de `if` sobre o escrutínio; padrões `Int` (compara),
  variável/`_` (catch-all), e tuplo `(a, b)` (destructura por offset). Exige um
  catch-all no fim. `native_case.axi` corre nativo e igual ao interpretador.
- **Closures** (lambdas + funções de ordem superior): cada `\p -> corpo` é
  *liftada* para uma função nativa com ABI `(env, params…)`, que carrega as
  variáveis capturadas de `env`. No local da lambda constrói-se o ambiente
  `{fn_ptr, capturas…}` na heap (`axion_alloc`); tipos-função são o ponteiro para
  esse ambiente. Aplicar um valor-função (um parâmetro `Int -> Int`, ou uma
  lambda aplicada directamente) faz-se por `call_indirect` sobre `env[0]`, com a
  própria closure passada como env. `native_closure.axi` corre nativo (→ 42) e
  igual ao interpretador (incl. capturas múltiplas e aplicação aninhada).

## Como usar

```sh
# despeja o Cranelift IR das funções compiláveis
axionc --emit clif programa.axi

# JIT-compila o núcleo Int e corre 'main :: Int', imprimindo o resultado
axionc --backend cranelift programa.axi
```

Exemplo (`axionc/tests/fixtures/native_fib.axi`):

```
fib :: Int -> Int
fib n = if n < 2 then n else fib (n - 1) + fib (n - 2)

main :: Int
main = fib 20
```

`axionc --backend cranelift native_fib.axi` → `6765` (código-máquina real, via
JIT). `--emit clif` mostra o IR (blocos, `brif`, `call` recursivo).

## O que ainda NÃO compila (recai no interpretador)

- `%1`/arenas em runtime, padrões de construtor no `case`.
- **Referência nua** a uma função de topo como valor (ex.: `apply inc 5`) — falta
  o *thunk* que a embrulha numa closure; usa-se uma lambda (`apply (\x -> inc x)`).
- Funções (e `case`) **sem** catch-all no fim (falta o *trap* de exaustão).
- Strings além de `putStrLn`/`show` (concatenação, `String` como parâmetro, …).

## Auto-Drop no runtime (reclamação, §2)

A heap deixou de ser toda *leaked*: `axion_alloc` prefixa cada bloco com um
cabeçalho de tamanho e `axion_free` liberta-o. A análise de reclamação (em
`core.rs`) insere nós `drop x` no Core que libertam os objectos que a função
**possui** no seu ponto de morte. Um objecto é *droppable* se for **possuído** —
alocado localmente (`MakeTuple`/`MakeRecord`/`UpdateRecord`/`MakeClosure`), o
resultado de uma chamada que devolve heap (`data`/tuplo), ou um parâmetro `%1` de
tipo-heap — e **nunca escapar** (devolvido, embebido, passado a uma chamada, ou
aliased). Os `if`/`case` são equilibrados para libertar uma vez por caminho, e o
escrutínio de um `case` é libertado à cabeça de cada braço.

Isto dá **reclamação entre funções** para valores lineares: quem devolve heap
transfere a posse ao chamador (que o liberta), e um parâmetro `%1` é possuído e
libertado pelo callee. A soberania é a chave da soundness — a disciplina linear
garante ausência de aliasing (`%1` não pode ser duplicado), pelo que libertar
após a última leitura nunca é uso-após-free nem dupla-libertação.

Vê-se com `--emit core` (nós `drop`) e mede-se com `AXION_HEAP_STATS=1` (imprime
`allocs`/`frees`):

- `heap_loop.axi` (300 chamadas que alocam+libertam um tuplo) → **300==300**,
  memória constante, sem GC.
- `linear_move.axi` (`make` aloca um `Box`, `take` recebe-o por `%1`) → **1==1**:
  o objecto atravessa a fronteira e é libertado uma vez.

## Arenas no runtime (§3)

As arenas correm agora nativamente (antes eram `--check`-only). `Arena`/`Cell`/
`Mark` são `i64` (handles). O runtime é um **bump-allocator** por chunks fixos
(ponteiros estáveis): `withArena (\a -> …)` cria a arena-raiz, corre o corpo e
**reseta-a em massa** no fim (larga todos os chunks de uma vez — não há `free`
por célula); `withSubArena` faz o mesmo para uma sub-arena; `allocateCell`
bump-aloca; `promote` copia uma célula para a arena-pai (safa-a do reset);
`arena_mark`/`arena_release` guardam/repõem o bump-pointer (reclamação
intra-escopo). Vê-se com `--emit core` (`withArena`, `allocateCell`, …) e
mede-se com `AXION_HEAP_STATS=1` (linha `arena: N news, M resets, K cells`):
`arena_run.axi` (100 células) → **100 cells, 1 reset**.

A **segurança do reset é grátis**: a análise estática de escape (`AX0003`,
`AX0005`) já rejeita, em tempo de compilação, devolver/capturar um valor que
viva numa arena a ser reclamada (só `promote` o safa), pelo que resetar no fim
do escopo nunca é uso-após-reset.

**Ainda por reclamar (conservador — são):** valores **irrestritos** (`Many`)
passados entre funções — podem ser aliased, logo a posse não basta (precisam de
disciplina linear ou RC/GC); as **closures** (podem ser chamadas). O
interpretador continua a não correr arenas (para elas, o nativo é o único
runner).

O codegen recusa o que não cabe com um erro claro; para esses programas, usa-se
o interpretador (`axionc programa.axi`, sem `--backend`).

## Notas de implementação

- `axionc/src/codegen.rs`: `JITModule` (cranelift-jit) + `FunctionBuilder`.
  Declara todas as funções nativas primeiro (para a recursão/chamadas mútuas
  resolverem), depois define os corpos; `Int` → `i64`; comparações → `icmp`;
  `if` → dois blocos + bloco de junção com parâmetro.
- A baixada AST→Core (`core.rs`) está em **ANF**: cada subexpressão composta é
  nomeada por um `let`, argumentos são átomos, e o controlo (`if`/`case`) vive num
  `Rhs` (um `let` pode ligar o resultado de um ramo). O Drop estrutural já é um
  **nó explícito** do Core (`drop x`); o reset de arena e o in-place ainda ficam
  implícitos (o `check.rs` calcula-os) — próximos incrementos.
- Backend `--release` (LLVM via `inkwell`) baixará do **mesmo Core**, sem duplicar
  a baixada AST→IR — é o que fecha o gap dos benchmarks `-O2`.

## Verificação de memória (sanitizers)

A proposta de valor da Axión é memória segura **sem GC**, por isso o runtime
nativo corre sob os sanitizers do LLVM em CI (`scripts/sanitize.sh`, job
`sanitize`), sobre o LLVM IR do `--release` + o runtime C:

- **Corrupção (AddressSanitizer, todas as fixtures nativas):** zero
  uso-após-livre e zero dupla-free — a garantia dura. Também há um teste `cargo`
  (`native_runtime_is_leak_free_under_lsan`) que corre um subconjunto sob
  ASan+LSan.
- **Fugas (LeakSanitizer, subconjunto provado):** `allocs == frees` na memória de
  heap/arena/empréstimo (sem IO).

### Fugas conservadoras conhecidas (seguras, fora do portão de fugas)

Duas categorias vazam **por opção conservadora** — não são corrupção (o ASan
passa), e reclamá-las seria inseguro ou exigiria uma decisão de design:

1. **C-strings do runtime** (`show`, `putStrLn`): o resultado de `show` é uma
   string alocada no runtime, mas os literais de string são estáticos. No ponto
   de drop não se distingue uma da outra, logo libertar uniformemente rebentaria
   nos literais. Reclamar exige um `String` que marque heap vs. estática.
2. **Closures devolvidas por uma função:** o retorno pode ser uma closure fresca
   (`\k -> …`) **ou** um parâmetro-closure emprestado (`pick b f g = if b then f
   else g`). Tratar o resultado como propriedade do chamador causaria dupla-free
   no segundo caso. Reclamar exige uma análise de escape sobre a closure (como a
   dos argumentos emprestados, `BorrowArgs`).

Já **reclamadas** (eram fugas, agora fechadas): a closure passada a `withArena`
(é emprestada, não um objecto de arena) e a base de um `update` por cópia
(lê-se para alocar a cópia, não se retém → empréstimo).
