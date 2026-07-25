# Backend nativo — o «Fast-Path» de `--dev` (Cranelift)

> §11/§18 da spec. O pipeline baixa o AST para o **Axión Core IR** (ANF,
> estrito/linear — ver `axionc/src/core.rs`) e daí emite código nativo:
> **Cranelift em `--dev`** (compila depressa — «zero otimizações em dev»),
> **LLVM em `--release`** (otimizado, ainda adiado). Ambos os backends partilham
> o mesmo Core; vê-lo com `axionc --emit core <ficheiro>`.

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
`core.rs`) insere nós `drop x` no Core que libertam os objectos de heap **locais**
no seu ponto de morte — um objecto é *droppable* se for alocado na função
(`MakeTuple`/`MakeRecord`/`UpdateRecord`/`MakeClosure`) e **nunca escapar**
(devolvido, embebido, passado a uma chamada, ou aliased). A disciplina linear
garante que libertar após a última leitura é são (sem aliasing → sem
uso-após-free nem dupla-libertação); os `if`/`case` são equilibrados para libertar
uma vez por caminho. Vê-se com `--emit core` (nós `drop`) e mede-se com
`AXION_HEAP_STATS=1` (imprime `allocs`/`frees`): `heap_loop.axi` (300 chamadas que
alocam+libertam um tuplo) dá **300 allocs == 300 frees**, memória constante, sem
GC. **Ainda por reclamar (conservador — são):** objectos que escapam ou mudam de
dono (reclamação **entre funções**), o **reset de arena**, e os `%1`/arenas —
próximos incrementos.

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
