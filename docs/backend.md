# Backend nativo — o «Fast-Path» de `--dev` (Cranelift)

> §11/§18 da spec. O pipeline baixa para um IR estrito/linear (Axión Core) e
> emite código nativo: **Cranelift em `--dev`** (compila depressa — «zero
> otimizações em dev»), **LLVM em `--release`** (otimizado, ainda adiado).

Este é o **primeiro corte** do backend `--dev`, sobre `cranelift-jit`. Baixa o
**núcleo Int** do AST directamente para Cranelift IR e JIT-compila.

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

- `case`, lambdas/closures, **registos**, tuplos, `%1`/arenas em runtime.
- Funções multi-cláusula **sem** catch-all no fim (falta o *trap* de exaustão).
- Strings além de `putStrLn`/`show` (concatenação, `String` como parâmetro, …).

O codegen recusa o que não cabe com um erro claro; para esses programas, usa-se
o interpretador (`axionc programa.axi`, sem `--backend`).

## Notas de implementação

- `axionc/src/codegen.rs`: `JITModule` (cranelift-jit) + `FunctionBuilder`.
  Declara todas as funções nativas primeiro (para a recursão/chamadas mútuas
  resolverem), depois define os corpos; `Int` → `i64`; comparações → `icmp`;
  `if` → dois blocos + bloco de junção com parâmetro.
- Backend `--release` (LLVM via `inkwell`) e o Axión Core IR intermédio ficam
  para incrementos seguintes; por agora baixa-se do AST directamente.
