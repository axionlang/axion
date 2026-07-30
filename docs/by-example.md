# Axión by Example

Um percurso guiado pela Axión, com **divulgação progressiva** (§8): cada passo
introduz *um* conceito novo, com código que corre. Segue por ordem — nunca se vê
`bound`/sessões antes de dominar o núcleo linear.

Assume o compilador construído (`cd axionc && cargo build`). Usa-se o atalho:

```sh
AX=axionc/target/debug/axionc          # a partir da raiz do repo
```

`$AX prog.axi` corre no interpretador; `$AX --check prog.axi` só verifica;
`$AX --explain AXnnnn` explica um código de erro.

---

## L0 — o núcleo familiar (Haskell estrito)

Quem sabe programação funcional lê isto no dia 1. Sem uma anotação de linearidade.

### 1. Olá Mundo — `putStrLn`, IO

```haskell
main :: IO ()
main = putStrLn "Hello, Axión!"
```
```sh
$AX examples/01_hello.axi          # → Hello, Axión!
```

### 2. Fibonacci — recursão, pattern matching, `where`

```haskell
fib :: Int -> Int
fib 0 = 0
fib 1 = 1
fib n = fib (n - 1) + fib (n - 2)          -- multi-cláusula
```
```sh
$AX examples/02_fib.axi            # → 832040   (fib 30)
```
`examples/02_fib.axi` mostra também `fibFast` com um acumulador em `where` (o
«loop» funcional, O(n)).

### 3. FizzBuzz — guardas, `mod`, ranges, composição, `mapM_`

```haskell
fizzbuzz :: Int -> String
fizzbuzz n
  | n `mod` 15 == 0 = "FizzBuzz"
  | n `mod` 3  == 0 = "Fizz"
  | n `mod` 5  == 0 = "Buzz"
  | otherwise       = show n

main :: IO ()
main = mapM_ (putStrLn . fizzbuzz) [1 .. 15]     -- range, compose (.), mapM_
```
```sh
$AX examples/03b_fizzbuzz.axi      # → 1  2  Fizz  4  Buzz  Fizz … FizzBuzz
```
As listas (`[1..15]`, `:`, `[a,b,c]`) e o `List a` vêm de um prelúdio embutido —
não é preciso declarar nada.

### 4. Tipos-soma paramétricos — `Maybe`, `Either`, `case`

```haskell
data Maybe a = None | Some a

fromMaybe :: Int -> Maybe Int -> Int
fromMaybe d m = case m of
  None   -> d
  Some x -> x

main :: Int
main = fromMaybe 0 (Some 42) + fromMaybe 7 None       -- → 49
```
```sh
$AX axionc/tests/fixtures/parametric_data.axi        # → 49
```
Os construtores generalizam (`Some :: forall a. a -> Maybe a`). Corre nos três
executores: `$AX --backend cranelift …` (Cranelift), `$AX --release …` (LLVM).

---

## L1 — linearidade e memória sem GC (o diferenciador)

O núcleo da Axión: cada dado tem um dono, e o compilador liberta-o em pontos
estáticos exatos. Sem GC, sem `free` manual.

### 5. `%1`: consumir uma vez — `AX0001`

Um recurso linear `%1` pode ser **lido** (emprestado) à vontade, mas **consumido**
(mover a posse) uma só vez. Consumir duas vezes é erro:

```sh
$AX --check axionc/tests/fixtures/use_after_consume.axi   # → error[AX0001]
$AX --explain AX0001                                       # a regra e o fix
```
Ler antes de consumir é livre; **usar depois de mover** é `AX0004`.

### 6. *Must-use* vs Auto-Drop — `AX0002`

Tipos sem `Drop` (`Ep`, `Token`, handles) são *must-use*: largá-los é `AX0002`.
Os tipos *droppable* são geridos pelo **Auto-Drop** — o compilador injecta o
`free` no ponto de morte. Vê onde:

```sh
$AX --emit drops axionc/tests/fixtures/heap_loop.axi   # os `free` e as razões
```

### 7. Buffer linear — `%1` em ação (§4/§5)

O `Buffer` é o array de bytes **linear**: aloca-se, opera-se in-place e liberta-se
sem fuga. É runtime **nativo** (as operações em massa vivem no runtime C/Rust,
vectorizáveis), por isso corre com `--backend cranelift` ou `--release`:

```sh
$AX --backend cranelift axionc/tests/fixtures/buffer_sum.axi   # → 4950   (soma de bytes)
$AX --check examples/03_linear_buffer.axi                       # o alvo da §5 (aloca+opera+free)
```
Com `AXION_HEAP_STATS=1 $AX --backend cranelift …` vês `allocs == frees`.

### 8. Actualização in-place — Linear Elision (Listagem 2.1)

Quando o base de uma actualização de registo é linear e morre ali, o compilador
**muta o bloco** em vez de alocar+copiar:

```sh
$AX --check examples/04_process_inplace.axi     # typecheck
$AX --emit inplace examples/04_process_inplace.axi   # os updates in-place
```

---

## L2 — regiões e arenas (§3)

Para dados cuja vida cabe num escopo, uma **arena** reclama tudo num só reset.

### 9. Escape de arena — `AX0003`

Um valor alocado numa sub-arena não pode escapar ao seu escopo (senão sobrevivia
ao reset). O compilador rejeita-o e diz como corrigir (`promote`):

```sh
$AX --check axionc/tests/fixtures/arena_escape.axi   # → error[AX0003] + ajuda
$AX --explain AX0003
```
`arena_promote_ok.axi` mostra a versão correta (com `promote parent v`).

---

## L3 — concorrência: canais e session types (§6/§9)

Aqui a Axión distingue-se: comunicação **sem data races nem deadlocks, provada
por tipos**. Um canal move a posse; o `bound` confina os endpoints a uma árvore.

### 10. Um protocolo tipado — session types (§6)

```haskell
worker :: Ep (Send Int End) %1 -> IO ()      -- envia UM Int e termina
worker chan = do
  c2 <- send chan 42
  close c2
```
```sh
$AX --check axionc/tests/fixtures/session_ok.axi     # segue o protocolo → aceite
```
Fazer `recv` onde o tipo diz `Send` é `AX0300`; largar sem `close` é `AX0301`.

### 11. Concorrência a CORRER — `bound` + `spawn` (§9/§11)

O `bound` abre um nursery; `spawn` forka um filho ligado por um canal. Um
ping-pong concorrente que computa de facto:

```sh
$AX axionc/tests/fixtures/session_run_pingpong.axi   # → 42   (pai envia 21, worker dobra)
```

### 12. Escolha e cancelamento — `select`/`offer`/`Closed` (§7)

```sh
$AX axionc/tests/fixtures/session_run_offer.axi      # → 7   (select Live → ramo Live)
$AX axionc/tests/fixtures/session_run_cancel.axi     # → 5   (cancel → o par recebe Closed)
```
O `Closed` é um ramo normal do protocolo — o cancelamento de um par em pânico é
sempre tratável (T5, §7).

### 13. As garantias, impostas

O compilador rejeita as topologias perigosas *antes* de correr:

```sh
$AX --check axionc/tests/fixtures/bound_escape.axi     # AX0302: endpoint escapa do nursery
$AX --check axionc/tests/fixtures/session_spawn_capture.axi  # AX0305: spawn capturaria um ciclo
$AX --explain AX0302     # porquê: a topologia tem de ser uma árvore
```

---

## Onde ir a seguir

- A especificação completa: [`spec/Axion-V0.2.pdf`](../spec/Axion-V0.2.pdf).
- Como o compilador funciona: [`docs/backend.md`](backend.md).
- O cálculo de sessões formalizado: [`docs/phase-3-calculus.md`](phase-3-calculus.md).
- Todos os códigos de erro: [`docs/error-codes.md`](error-codes.md) (ou `$AX --explain AXnnnn`).
