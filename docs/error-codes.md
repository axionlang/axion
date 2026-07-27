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
| `AX0003` | Regiões | Escape: um valor de sub-arena escapa ao seu escopo (falta `promote`) | **imposto pelo `axionc`** (Fase 2) |
| `AX0004` | Linearidade | Uso-após-move: ler/consumir um `%1` depois de a posse ter sido movida | **imposto pelo `axionc`** (Fase 2) |
| `AX0005` | Regiões | Uso-após-release: valor alocado após `arena_mark` usado depois do `arena_release` | **imposto pelo `axionc`** (Fase 2) |
| `AX0006` | Linearidade | Escrita através de uma metade `%0.5` (leitura partilhada) | **imposto pelo `axionc`** (Fase 2) |
| `AX0100` | Sintaxe | Erro de sintaxe / caractere inesperado | **imposto pelo `axionc`** (Fase 1) |
| `AX0101` | Nomes | Nome não encontrado (fora de âmbito) | **imposto pelo `axionc`** (Fase 1) |
| `AX0200` | Tipos | Incompatibilidade de tipos (unificação falhou) | **imposto pelo `axionc`** (Fase 1) |
| `AX0201` | Tipos | Tipo infinito (occurs-check falhou) | **imposto pelo `axionc`** (Fase 1) |
| `AX0300` | Sessões | Operação de canal não segue o tipo de sessão do endpoint (`send`/`recv`/`close` no estado errado) | **imposto pelo `axionc`** (Fase 3) |
| `AX0301` | Sessões | Protocolo de sessão incompleto: um endpoint não é levado até `close` | **imposto pelo `axionc`** (Fase 3) |
| `AX0302` | Sessões | Escape de endpoint: um endpoint criado num `bound` é devolvido do nursery (quebra a topologia acíclica → risco de deadlock) | **imposto pelo `axionc`** (Fase 3) |
| `AX0303` | Sessões | Escolha externa (`Offer`/`&`) sem o ramo `Closed`: o cancelamento de um par em pânico ficaria por tratar (T5, §7) | **imposto pelo `axionc`** (Fase 3) |

Próximo livre por banda — linguagem: `AX0007`; front-end: `AX0102`;
tipos: `AX0202`; canais/sessões: `AX0304`.

**`AX03xx` canais e session types (Fase 3).** Banda da §17 para o cálculo de
sessões (ver [`docs/phase-3-calculus.md`](phase-3-calculus.md)). Impostos:
`AX0300` (fidelidade — `send`/`recv`/`close`/`select` seguem o tipo de sessão,
incl. o rótulo escolhido pertencer ao `Select`), `AX0301` (completude — o
protocolo chega a `close`), `AX0302` (confinamento do nursery — os endpoints não
escapam do `bound`; deadlock-freedom estrutural, §9, análogo ao escape de arena
`AX0003` mas sem `promote`), `AX0303` (exaustividade do cancelamento — toda a
escolha externa `Offer`/`&` inclui o ramo `Closed`, T5/§7). A posse linear `%1` do
endpoint é coberta por `AX00xx` (must-use/uso-após-move). Ainda por implementar:
exaustividade dos ramos de `offer` ao nível do termo (hoje só ao nível do tipo), e
o `spawn` a exigir topologia estritamente em árvore entre irmãos.

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
classifica o tipo do recurso `%1`: se for **droppable** (por omissão), largá-lo
sem consumo **não é erro** — o Auto-Drop injecta `free` no ponto de morte
(visível em `axionc --emit drops`). Só um tipo **must-use** largado emite
`AX0002`. Must-use = cabeça em `MUST_USE_PRIMS` (`Ep`, `Token`, …) **ou** um
`data` que contenha (recursivamente) um campo must-use — `Drop` propaga
estruturalmente (ponto-fixo). Aplica-se a **parâmetros e a valores `let`**: um
`let v = <consome recurso linear>` de tipo must-use, largado, é `AX0002`.

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

**`axionc` (Fase 2).** Um rastreio de proveniência de região
(`axionc/src/check.rs`) segue os valores ligados à sub-arena de um
`withSubArena parent (\sub -> …)`: `allocateCell sub …` liga o valor à sub-arena;
`promote parent v` re-liga-o à arena-pai (corta a proveniência). O escape é
detectado quer **por retorno** (o valor de retorno ainda ligado à sub-arena)
quer **por captura em closure** (uma lambda devolvida que capture um valor da
sub-arena, §3C) → `AX0003`, com o span do escape e o da alocação.

```
error[AX0003]: um valor escapa da sua sub-arena
  --> arena_escape.axi:4:78
  |
4 | escapes parent = withSubArena parent (\sub -> let node = allocateCell sub in node)
  |                                                          ^^^^^^^^^^^^^^^^ vive na sub-arena 'sub'
  |                                        (…)                                     ^^^^ devolvido daqui
```

Fixtures: `arena_escape.axi` (escapa → `AX0003`), `arena_promote_ok.axi`
(`promote` → aceite).

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

## `AX0005` — uso-após-release de marca de arena

**Regra (§3, Listagem 3.6).** `mark = arena_mark arena` guarda o topo do
bump-pointer; `arena_release mark` recua-o, recuperando **tudo o que foi alocado
depois da marca**. Logo, um valor `allocateCell arena` alocado após a marca não
pode ser usado **depois** do `arena_release` — a sua memória já foi reclamada.
Reclamação intra-escopo, sem sub-arena.

**`axionc` (Fase 2).** Uma análise ordenada sobre a espinha de `let`
(`axionc/src/check.rs`) segue as marcas abertas, os valores alocados sob cada
marca, e o `arena_release`; qualquer uso de um valor cuja marca já foi libertada
é `AX0005`, com o span do uso, do release e da alocação.

```
error[AX0005]: 'tmp' usado após o 'arena_release' (memória já recuperada)
  --> arena_mark_release.axi:8:3
  |
8 |   tmp
  |   ^^^ 'tmp' usado aqui…
  |
7 |   let done = arena_release mark in
  |              ^^^^^^^^^^^^^^^^^^ …mas o arena_release recuperou a memória aqui
```

Fixtures: `arena_mark_release.axi` (→ `AX0005`), `arena_mark_ok.axi` (uso antes
do release → aceite).

---

## `AX0006` — escrita através de uma metade `%0.5`

**Regra (§2, Listagem 2.3).** `split` divide um `%1` em duas metades `%0.5` de
**leitura partilhada** (estilo Boyland); `join a b` recombina-as em `%1`,
recuperando a escrita. Uma metade `%0.5` pode ser **lida** (emprestada) à
vontade, mas **nunca escrita** — usá-la numa posição de escrita é `AX0006`.

**`axionc` (Fase 2).** Ao encontrar `case (split …) of (a, b) -> braço`, a
análise (`axionc/src/check.rs`) marca `a`/`b` como metades `%0.5` e rejeita, no
braço, usá-las numa **posição de escrita**: argumento de um parâmetro `%1` de
uma função, base de uma actualização de registo, ou campo `%1`.

```
error[AX0006]: escrita através da metade %0.5 'a'
  --> frac_write.axi:10:22
   |
10 |   (a, b) -> writeCfg a
   |                      ^ 'a' é %0.5 (leitura partilhada): passado a um parâmetro %1 (escrita)
```

Fixtures: `frac_write.axi` (escrita → `AX0006`), `frac_join.axi` (leituras +
`join` → aceite, e corre).

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
