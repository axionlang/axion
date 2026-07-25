# Registo de códigos de erro `AXnnnn`

> **Porque já, na Fase 0.** A §8/§17 é explícita: registar **códigos de erro
> estáveis desde o primeiro erro emitido** — «retrofitar um registo depois de
> existirem centenas de erros é doloroso». Este ficheiro é a semente desse
> registo. Cada código é estável e para sempre; nunca se reutiliza um número.

Formato: `AXnnnn`, quatro dígitos, alocados sequencialmente. Cada entrada tem:
o invariante que protege, um exemplo mínimo, e (quando aplicável) o *fix
machine-applicable* que o LSP oferece (§8). Diagnósticos emitidos também em JSON
e explicáveis por `axion --explain AXnnnn`.

| Código | Categoria | Invariante violado | Estado |
|--------|-----------|--------------------|--------|
| `AX0001` | Linearidade | Contração: um `%1` **consumido** >1 vez (ler/emprestar é livre) | **imposto pelo `axionc`** (Fase 1/2) |
| `AX0002` | Linearidade | *Must-use*: um `%1` **sem `Drop`** descartado sem consumo (tipos droppable ⇒ Auto-Drop, não erro) | **imposto pelo `axionc`** (Fase 1/2) |
| `AX0003` | Regiões | Escape: um valor de sub-arena escapa ao seu escopo (falta `promote`) | reservado (Fase 2) |
| `AX0004` | Linearidade | Uso-após-move: ler/consumir um `%1` depois de a posse ter sido movida | **imposto pelo `axionc`** (Fase 2) |
| `AX0100` | Sintaxe | Erro de sintaxe / caractere inesperado | **imposto pelo `axionc`** (Fase 1) |
| `AX0101` | Nomes | Nome não encontrado (fora de âmbito) | **imposto pelo `axionc`** (Fase 1) |
| `AX0200` | Tipos | Incompatibilidade de tipos (unificação falhou) | **imposto pelo `axionc`** (Fase 1) |
| `AX0201` | Tipos | Tipo infinito (occurs-check falhou) | **imposto pelo `axionc`** (Fase 1) |

Reservado mas ainda não implementado: `AX0003`. Próximo livre por banda —
linguagem: `AX0005`; front-end: `AX0102`; tipos: `AX0202`.

> **Nota de bandas.** `AX0001`–`AX0099` para invariantes de *semântica da
> linguagem* (linearidade, regiões, sessões); `AX0100`–`AX0199` para *front-end*
> (sintaxe, resolução de nomes); `AX0200`+ para *tipos* (inferência HM). Os
> códigos são estáveis: um número nunca muda de significado nem é reutilizado.

---

## `AX0001` — contração de um recurso linear (consumido >1 vez)

**Regra (§2), com liveness fina.** *Ler* (emprestar) um `%1` é livre e
ilimitado — a Elisão de Empréstimos. *Consumir* (mover a posse: argumento de um
parâmetro `%1`, campo `%1`, ou valor de retorno) só pode acontecer **uma** vez;
duas é contração.

```axion
process :: Buffer U8 %1 -> (Buffer U8 %1, Buffer U8 %1)
process buf = (encrypt buf, encrypt buf)
--                    ^^^            ^^^  'buf' CONSUMIDO duas vezes -> AX0001
-- (mas  checksum buf + checksum buf  seria OK: são duas LEITURAS/empréstimos)
```

**Bancada (Fase 0).** `prototype/test/negative/UseTwice.hs` falha a compilar; o
GHC manifesta-o como erro de *multiplicidade* (o `LinearTypes` não tem Elisão de
Empréstimos, por isso trata toda a leitura como consumo).

**`axionc` (Fase 1/2).** Imposto pela análise de linearidade fina
(`axionc/src/check.rs`): classifica cada ocorrência do `%1` como empréstimo ou
consumo pela sua posição; **consumos > 1** ⇒ `AX0001`. Ramos de `if`/`case`
contam como caminhos alternativos (máximo, não soma).
Fixture: `axionc/tests/fixtures/use_after_consume.axi`.

```
error[AX0001]: recurso linear 'x' consumido 2 vezes (contração proibida)
  --> tests/fixtures/use_after_consume.axi:5:10
  |
5 | useTwice x = (x, x)
  |          ^ 'x' é %1: consumível uma só vez
```

---

## `AX0002` — recurso *must-use* descartado sem consumo

**Regra (§2).** O enfraquecimento (descartar) só é permitido para tipos com
instância `Drop`. Tipos sem `Drop` — endpoints de sessão (`Ep`), `Token`,
handles de transação — são *must-use*: esquecê-los é erro (disto depende a
Fidelidade de Sessão da §9). Exemplo e forma do diagnóstico na Listagem 2.4.

**`axionc` (Fase 2, Auto-Drop).** A análise de linearidade (`axionc/src/check.rs`)
classifica o tipo do parâmetro `%1`: se for **droppable** (por omissão), largá-lo
sem consumo **não é erro** — o Auto-Drop injecta `free` no ponto de morte
(visível em `axionc --emit drops`). Só um tipo **must-use** (cabeça em
`MUST_USE`: `Ep`, `Token`, …) largado sem consumo emite `AX0002`.

```
error[AX0002]: recurso must-use 'x' largado sem ser consumido
  --> drop_linear.axi:4:8
  |
4 | dropIt x = 0
  |        ^ 'x' : Token %1 (sem Drop)
```

## `AX0003` — escape de sub-arena

**Regra (§3).** Um valor alocado numa sub-arena não pode escapar ao seu escopo;
o escape tem de ser erro de *compilação* (usar `promote` para o mover à
arena-pai antes do reset). Exemplo na Listagem 3.5.

---

## `AX0004` — uso-após-move

**Regra (§2), sensível à ordem.** Depois de a posse de um `%1` ser **movida**
(consumida — passada a um parâmetro `%1`, colocada num campo `%1`, ou devolvida),
não se pode voltar a lê-lo nem a consumi-lo: a posse já saiu do âmbito. Distinto
de `AX0001` (contração = mover duas vezes) e da leitura repetida (empréstimos,
que são livres).

**`axionc` (Fase 2).** Uma travessia na ordem de avaliação (esquerda→direita,
ramos como caminhos) marca quando `x` é movido; qualquer ocorrência posterior é
`AX0004`, com o span do uso e o span do move.

```
error[AX0004]: uso de 'x' após a posse ter sido movida
  --> use_after_move.axi:7:18
  |
7 | bad x = sink x + x
  |                  ^ 'x' usado aqui…
  |
7 | bad x = sink x + x
  |              ^ …mas a posse já tinha sido movida aqui
```

`x + sink x` (ler **antes** de consumir) é aceite; `sink x + x` (ler **depois**)
é `AX0004`. Fixture: `axionc/tests/fixtures/use_after_move.axi`.

---

## `AX0100` — erro de sintaxe

Emitido pelo lexer (caractere inesperado) ou pelo parser (construção não
reconhecida) do `axionc`. Sem recuperação na Fase 1: o primeiro erro pára a
análise. `axionc --explain AX0100`.

## `AX0101` — nome não encontrado

Um identificador que não é parâmetro, local (`where`/`let`), função de topo nem
builtin. Emitido pela resolução de nomes em `axionc/src/check.rs`.

---

## `AX0200` — incompatibilidade de tipos

A inferência Hindley-Milner (`axionc/src/infer.rs`) não conseguiu unificar dois
tipos. Exemplo: `bad :: Int` com corpo `putStrLn "olá"` (que é `IO ()`).

```
error[AX0200]: incompatibilidade de tipos: IO () vs Int
```

## `AX0201` — tipo infinito (occurs-check)

A unificação exigiria um tipo recursivo (uma variável que ocorre dentro do tipo
a que seria ligada), o que a inferência HM rejeita. Emitido por `infer.rs`.
