# Testes diferenciais — `axionc` vs bancada EDSL (oráculo GHC)

> §17: «Typechecker próprio com linearidade — **validado por diferencial contra
> o protótipo EDSL da Fase 0**.»

Cada subpasta é um **cenário de linearidade** com o mesmo veredito esperado em
dois verificadores independentes:

- `prog.axi` — corrido pelo `axionc` (`--check`): aceita (exit 0) ou rejeita
  (exit ≠ 0, com `AX0001`/`AX0002`).
- `Prog.hs` — corrido pelo **GHC** através da bancada EDSL da Fase 0 (importa
  `Axion.Prototype.Buffer`): aceita (compila) ou rejeita (erro de multiplicidade).
- `expected` — o veredito comum: `accept` ou `reject`.

O runner [`../scripts/differential.sh`](../scripts/differential.sh) exige que
**ambos** concordem com `expected`. É isto que ancora o verificador de
linearidade do `axionc` ao oráculo do GHC: o mesmo invariante da linguagem,
duas implementações, um só veredito.

| Cenário | Ideia | Veredito |
|---------|-------|----------|
| `01_consume_once` | recurso `%1` consumido exactamente uma vez | `accept` |
| `02_consume_twice` | contração: `%1` usado duas vezes (`AX0001`) | `reject` |
| `03_drop_unused` | must-use (`Token`) largado sem consumo (`AX0002`) | `reject` |

> **Nota (Auto-Drop, Fase 2).** O cenário `03` usa um tipo **must-use**
> (`Token`) de propósito: um tipo *droppable* seria aceite pelo `axionc` via
> Auto-Drop (o compilador injecta `free`), mas o GHC rejeitá-lo-ia à mesma (o
> `LinearTypes` trata todo o linear como must-use, sem Auto-Drop). Restringir o
> cenário a must-use mantém os dois verificadores concordantes.
