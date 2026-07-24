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
| `AX0001` | Linearidade | Contração: um `%1` usado **mais do que uma vez** | **imposto pelo `axionc`** (Fase 1) |
| `AX0002` | Linearidade | *Must-use*: um recurso `%1` descartado sem ser consumido | **imposto pelo `axionc`** (Fase 1) |
| `AX0003` | Regiões | Escape: um valor de sub-arena escapa ao seu escopo (falta `promote`) | reservado (Fase 2) |
| `AX0100` | Sintaxe | Erro de sintaxe / caractere inesperado | **imposto pelo `axionc`** (Fase 1) |
| `AX0101` | Nomes | Nome não encontrado (fora de âmbito) | **imposto pelo `axionc`** (Fase 1) |
| `AX0200` | Tipos | Incompatibilidade de tipos (unificação falhou) | **imposto pelo `axionc`** (Fase 1) |
| `AX0201` | Tipos | Tipo infinito (occurs-check falhou) | **imposto pelo `axionc`** (Fase 1) |

Reservado mas ainda não implementado: `AX0003`. Próximo livre por banda —
linguagem: `AX0004`; front-end: `AX0102`; tipos: `AX0202`.

> **Nota de bandas.** `AX0001`–`AX0099` para invariantes de *semântica da
> linguagem* (linearidade, regiões, sessões); `AX0100`–`AX0199` para *front-end*
> (sintaxe, resolução de nomes); `AX0200`+ para *tipos* (inferência HM). Os
> códigos são estáveis: um número nunca muda de significado nem é reutilizado.

---

## `AX0001` — uso-após-consumo (contração de um recurso linear)

**Regra (§2).** Todo o valor `%1` é consumido *exactamente uma vez*. Usá-lo duas
vezes (contração) é proibido para todo o `%1`, sempre.

```axion
process :: Buffer U8 %1 -> (Buffer U8 %1, Buffer U8 %1)
process buf = (encrypt buf, encrypt buf)
--                    ^^^            ^^^  'buf' consumido duas vezes -> AX0001
```

**Bancada (Fase 0).** Já imposto: `prototype/test/negative/UseTwice.hs` compila
com falha e `scripts/check-negative.sh` exige essa falha. No GHC manifesta-se
como erro de *multiplicidade*.

**`axionc` (Fase 1).** Imposto pela análise de linearidade
(`axionc/src/check.rs`): um parâmetro cuja seta na assinatura é `%1` usado mais
do que uma vez emite `AX0001` com o span do binder. Ramos de `if`/`case` contam
como caminhos alternativos (o uso é o máximo entre ramos, não a soma).
Fixture: `axionc/tests/fixtures/use_after_consume.axi`.

```
error[AX0001]: recurso linear 'x' usado 2 vezes (contração proibida)
  --> tests/fixtures/use_after_consume.axi:3:10
  |
3 | useTwice x = x + x
  |          ^ 'x' é %1: consumível uma só vez
```

---

## `AX0002` — recurso *must-use* descartado sem consumo

**Regra (§2).** O enfraquecimento (descartar) só é permitido para tipos com
instância `Drop`. Tipos sem `Drop` — endpoints de sessão (`Ep`), `Token`,
handles de transação — são *must-use*: esquecê-los é erro (disto depende a
Fidelidade de Sessão da §9). Exemplo e forma do diagnóstico na Listagem 2.4.

```
error[AX0002]: recurso linear sem Drop descartado sem ser consumido
```

## `AX0003` — escape de sub-arena

**Regra (§3).** Um valor alocado numa sub-arena não pode escapar ao seu escopo;
o escape tem de ser erro de *compilação* (usar `promote` para o mover à
arena-pai antes do reset). Exemplo na Listagem 3.5.

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
