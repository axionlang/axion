# Fase 3 — Concorrência: canais + session types (checklist)

> §17 da spec. Entrega isolada: **race-freedom e deadlock-freedom**. Princípio
> reitor desta fase (§17): **«provar antes de construir»** — o cálculo formaliza-se
> *antes* de qualquer código; a teoria dita o desenho.

## Trilho formal (começa ANTES do código)

- [x] **Cálculo de sessões (ASC)** — sintaxe, dualidade, tipagem, semântica
  operacional assíncrona, e os teoremas T1–T5 (preservação, progresso, fidelidade
  de sessão, deadlock-freedom, cancelamento). Base: *Propositions as Sessions*
  (Wadler) + **GV/EGV** (Fowler et al., POPL 2019, para o pânico). Ver
  [`docs/phase-3-calculus.md`](phase-3-calculus.md). **A eliminação de cortes = a
  árvore acíclica que o `bound` impõe** — deadlock-freedom é corolário da tipagem.
- [x] **Interpretador de configurações** (referência executável do cálculo) +
  **property tests** de T1–T5 sobre protocolos gerados. `axionc/src/session.rs`:
  modela threads (continuações defuncionalizadas) + buffers assíncronos + a árvore
  de `spawn`; um gerador determinístico produz protocolos bem-tipados por
  construção (um lado `S`, o outro `dual S`) em árvore. Testes: T1 (dualidade
  involutiva), T2/T3/T4 (2000 árvores correm sem deadlock, fidelidade intacta),
  T5 (pânico injectado drena via `Closed`, sem órfãos). **Não-vacuidade provada**:
  dois testes-detetor confirmam que o interpretador apanha um deadlock cíclico
  real e uma violação de fidelidade. É o oráculo para o typechecker de produção.
- [ ] **Model-checking de CFSMs** — projeção de cada sessão numa máquina
  comunicante; compatibilidade + ausência de deadlock por exploração de estados.

## Implementação (depois do trilho)

- [ ] **Frontend/typechecker de sessões** — `bound`/`spawn`/`newChan`/`send`/
  `recv`/`close`/`select`/`offer` no parser+Core; regra `(Bound)` com confinamento
  por região fantasma `s`; banda de erros **AX03xx**. Validado por diferencial
  contra o interpretador de configurações.
- [ ] **Runtime do scheduler (§11)** — M:N com work-stealing; tarefas =
  continuações defuncionalizadas na arena da nursery; pontos de suspensão =
  operações de canal; `io_uring`/`epoll` na fronteira de IO.
- [ ] **Cancelamento em pânico (§7)** — Linear Unwinding: `reset` da sub-arena em
  O(1), `Closed` ao par em O(filhos), `@cleanup` uma vez (T5).
- [ ] **Açúcar de superfície (§9)** — `A ~ B`, `A Maybe~ B`, `observe`,
  `makeCoupledPair`, `parMap`, telescópio `|>` — desugar normativo para os
  endpoints lineares do ASC.

## Metateoria (médio prazo)

- [ ] **Iris/Actris** — T1–T5 mecanizados em separation logic.
- [ ] **Verificador de referência** (translation validation) — cross-check das
  decisões do typechecker em compilação; custo de runtime zero.

## Meta da fase

`bound arena $ do …` corre workers concorrentes sem data races nem deadlocks,
provados por tipos; um pânico recupera em O(1) sem fugas nem endpoints órfãos.
