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
- [x] **Model-checking de CFSMs** — projeção de cada sessão numa máquina
  comunicante (o estado é a sessão restante; transições `!`/`?`); a dual forma o
  sistema com dois canais FIFO. Exploração **exaustiva** do espaço de estados
  global (`axionc/src/session.rs`): verifica deadlock-freedom, compatibilidade
  (sem receção não-especificada) e ausência de órfãos. Cobertura: **todas** as
  sessões até profundidade 3 (>1000 protocolos) + amostra aleatória de depth 6.
  Não-vacuidade: detetores confirmam que apanha deadlock cíclico, órfão e receção
  não-especificada em pares não-duais. Complementa o teste aleatório com cobertura
  de estados.

## Implementação (depois do trilho)

- [~] **Frontend/typechecker de sessões** — v1 feito: `send`/`recv`/`close`
  tipados no `infer.rs` (permissivos) + consumidos na linearidade; o passe
  `check_sessions` (`check.rs`) verifica a **fidelidade de protocolo** (a operação
  segue o tipo de sessão do endpoint, **AX0300**) e a **completude** (o endpoint
  chega a `close`, **AX0301**), sobre a espinha linear de `do`/`let`. `do`-binds
  com padrão de tuplo (`(x, c) <- recv c`) no parser. Fixtures accept + AX0300 +
  AX0301. **Confinamento do nursery feito** (`check_bound_escapes`): um endpoint
  criado num `bound` (por `newChannel`/`spawn`/`send`/`recv`) não pode ser
  devolvido do bloco — **AX0302**, o análogo do escape de sub-arena (AX0003) mas
  sem escotilha `promote`. É a **deadlock-freedom estrutural** da §9 (o grafo de
  comunicação fica uma árvore) imposta no compilador. Fixtures `bound_ok`
  (aceite) + `bound_escape` (AX0302). **Escolha feita** (`⊕`/`&`): `select L c`
  avança pelo rótulo escolhido de um `Select` (AX0300 se o rótulo não existir);
  `offer c` consome uma escolha externa; e **AX0303** exige que todo o `Offer`
  inclua o ramo `Closed` — a exaustividade do cancelamento (T5/§7). Tipos de
  sessão com ramos rotulados via `Select (L1 S1) (L2 S2) …`. Fixtures
  select_ok/bad + offer_ok/no_closed. **Falta:** exaustividade dos ramos de
  `offer` ao nível do termo (hoje ao nível do tipo); `spawn` a garantir árvore
  estrita; diferencial automático superfície→ASC.
- [~] **Runtime do scheduler (§11)** — 1º corte no interpretador (o fast-path de
  `--dev`): um **scheduler cooperativo single-thread** em `interp.rs` corre
  programas `bound`/`spawn`/canais. As tarefas são «continuações
  defuncionalizadas» — literalmente o `Expr` restante do `do` (a cadeia de
  `case`); o único ponto de suspensão é o `recv` de buffer vazio (troca de
  tarefa); os `Value` (Rc) ficam numa só thread (sem `Send`). `Value::Endpoint`,
  `newChannel`/`spawn`/`send`/`recv`/`select`/`close` executáveis. `session_run_pingpong.axi`
  corre um ping-pong concorrente (21→42). **Escolha e cancelamento a correr:**
  `select L c` envia o rótulo; `case offer c of { L d -> … }` recebe-o e despacha
  (um valor-soma etiquetado `L (Ep …)` transporta o endpoint avançado); `cancel c`
  envia `Closed` ao par, que o `offer` recebe como o ramo de cancelamento (T5/§7
  a executar). `session_run_offer.axi` (→7), `session_run_cancel.axi` (→5).
  **Falta:** M:N real com work-stealing + `io_uring`/`epoll` (arena de nursery, o
  §11 completo) no backend nativo.
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
