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
| `AX0001` | Linearidade | Contração: um `%1` usado **mais do que uma vez** | validado na bancada (Fase 0) |
| `AX0002` | Linearidade | *Must-use*: um recurso sem `Drop` (`Ep`, `Token`, handle) descartado sem ser consumido | Fase 1 |
| `AX0003` | Regiões | Escape: um valor de sub-arena escapa ao seu escopo (falta `promote`) | Fase 2 |

Alocados mas ainda **não implementados** (reservados aqui para estabilidade):
`AX0002`, `AX0003`. Próximo livre: `AX0004`.

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
como erro de *multiplicidade*; no `axionc` será `AX0001` com o span dos dois usos.

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
