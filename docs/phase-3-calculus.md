# Fase 3 — Trilho Formal: o Cálculo de Sessões da Axión (ASC)

> **Estatuto.** Este documento é o *trilho formal* que a §17 da spec exige **antes**
> de qualquer código de concorrência: *«provar antes de construir; para a
> concorrência, formalizar o cálculo antes de o implementar — a teoria dita o
> desenho certo»*. Fixa a sintaxe, a tipagem e a semântica operacional do núcleo
> de sessões, enuncia os teoremas de metateoria, e mapeia o cálculo para o
> runtime (§11) e para o açúcar de superfície (§6/§9). **Não** implementa nada.
> É o artefacto que a escada de verificação (property tests → model-checking de
> CFSMs → Iris/Actris → verificador de referência) vem depois descarregar.

---

## 0. Porquê primeiro, e o que decide

A ausência de *deadlocks* e o progresso **não são uma análise à parte**: são
**corolários da eliminação de cortes** da lógica linear (Wadler, *Propositions as
Sessions*, ICFP 2012; Caires & Pfenning, CONCUR 2010). Uma *proof net* sem cortes
é uma **árvore acíclica** — e essa árvore é *exatamente* a topologia que o bloco
`bound` (nursery de concorrência estruturada, §9) impõe ao grafo de comunicação.

Escrever este cálculo primeiro decide três coisas que seria caríssimo desfazer
depois de haver runtime:

1. **A forma do `bound`.** A árvore de cortes dita que `spawn` só pode criar
   arestas pai↔filho e que os combinadores só ligam irmãos em *caminhos*
   (pipelines), nunca em ciclos. O parâmetro-fantasma de região `s` (§9) é a
   codificação, ao nível dos tipos, do confinamento à árvore.
2. **A semântica do cancelamento em pânico** (§7). O desenho segue *Exceptional
   Asynchronous Session Types* (EGV; Fowler, Lindley, Morris & Decova, POPL 2019):
   um endpoint nunca é largado em silêncio — o pânico envia `Closed` ao par, que
   o recebe como um ramo normal do protocolo. Isto obriga a que **todo** tipo de
   sessão tenha, implicitamente, o ramo de cancelamento — uma decisão que molda a
   dualidade e a tabela de redução.
3. **A fronteira runtime↔tipos** (§11). Os pontos de suspensão do scheduler M:N
   são *exatamente* as operações de canal (visíveis nos tipos: `Bound s`,
   endpoints `%1`). Não há `async`/`await` na superfície nem *function coloring*.

Base teórica adotada: **GV** (linear λ-calculus com sessões; Gay & Vasconcelos) na
variante **EGV** (com exceções/cancelamento). Escolhe-se GV, e não CP puro (cálculo
de processos), porque a Axión é *funcional* — a concorrência vive em termos, não
num π-calculus à superfície. GV corresponde a CP (logo herda a deadlock-freedom),
e EGV é a extensão exata que a §7 cita.

Chamamos ao núcleo **ASC — Axión Session Core**. É um fragmento do Axión Core
(`core.rs`, IR estrito e linear em ANF) enriquecido com canais.

---

## 1. Axiomas de desenho (o que o cálculo TEM de satisfazer)

Extraídos da spec; cada regra e teorema abaixo existe para honrar um destes.

- **(A1) Race-freedom por posse.** Cada endpoint pertence a exatamente uma thread
  (linearidade `%1`). Enviar **move** a posse física; o remetente fica proibido
  pelo typechecker de tocar no ponteiro a partir do envio (§6, Fig. 6.1). Zero
  data races é um **corolário da Fidelidade de Sessão**, não um mecanismo à parte.
- **(A2) Deadlock-freedom por construção.** O grafo de comunicação é uma
  **floresta** (topologia acíclica); a espera cíclica é *inexprimível*. Corolário
  da tipagem (árvore de cortes), não de deteção em runtime (§9).
- **(A3) Cancelamento sem fugas.** Endpoints **não têm `Drop`** (§2). No pânico, o
  Linear Unwinding recua a sub-arena em O(1) e envia `Closed` ao par — O(filhos)
  em mensagens de cancelamento (§7).
- **(A4) Latência zero / sem monitores.** Nenhuma verificação de segurança corre
  em runtime; a rede de segurança vigia o *compilador* (translation validation),
  não o programa (§9, §11). Suspensão = operação de canal; `imperative` nunca
  suspende.
- **(A5) Um conceito, quatro superfícies.** `imperative`/`using`/`bound`/`susp`
  desugaram todos para uma única forma de Core: `scope[C] s. e` — um escopo que
  concede uma capacidade linear `C`, com `s` fantasma a impedir o escape (§9.2).
  A concorrência é a instância `C = Nursery s`.

---

## 2. Sintaxe

### 2.1 Tipos

```
Valor   T, U ::= Int | 1 | T ⊗ U            (par linear)
              |  T ⊸ U                       (função linear, %1)
              |  !ₘ T                          (modalidade Many: irrestrito, §2)
              |  S                             (um endpoint de sessão, sempre %1)
              |  Nursery s                     (capacidade de nursery, região s)

Sessão  S    ::= !T . S                        (envia T, continua como S)
              |  ?T . S                        (recebe T, continua como S)
              |  ⊕{ lᵢ : Sᵢ }                   (seleção interna: escolhe um rótulo)
              |  &{ lᵢ : Sᵢ }                   (oferta externa: aceita qualquer rótulo)
              |  end                            (terminação)
```

`⊕`/`&` são a **conjunção/disjunção aditivas** da lógica linear. A escolha `A & B`
da §9 (dois potenciais, um só se usa) é o caso binário de `&` do lado do valor;
aqui aparece como a estrutura de ramos do canal.

**Ramo de cancelamento implícito (EGV).** Por (A3), *todo* endpoint pode receber um
cancelamento. Formalmente, cada `S` tem um rótulo distinguido `Closed`; escrevemos
a oferta ternária da §9 (`Maybe~`) diretamente:

```
Maybe~ (T, S)  ≜  &{ Live : ?T.S ,  Closed : end ,  Pending : ?T.(Maybe~ (T,S)) }
```

`Live/Closed/Pending` correspondem aos três Trits `+1/−1/0` (§9.D). `Pending` é o
«ainda não chegou» — o `observe` é não-bloqueante e devolve o Trit.

### 2.2 Dualidade

Duas pontas de um canal têm tipos **duais**. `dual(·)` é involutivo:

```
dual(!T.S)      = ?T.dual(S)
dual(?T.S)      = !T.dual(S)
dual(⊕{lᵢ:Sᵢ})  = &{lᵢ:dual(Sᵢ)}
dual(&{lᵢ:Sᵢ})  = ⊕{lᵢ:dual(Sᵢ)}
dual(end)       = end
```

Um par acoplado `A ~ B` (§9.D) é exatamente `(Ep %1 S) ⊗ (Ep %1 dual(S))`.

### 2.3 Termos

Núcleo funcional (já no Axión Core) + primitivas de sessão. As primitivas são
**pontos de suspensão** (A4) — o scheduler só troca de tarefa aqui.

```
M, N ::= x | () | (M, N) | let (x,y) = M in N        (núcleo linear)
      |  λx. M | M N | let x = M in N
      |  bound M  as s { N }                          (abre um nursery; §9)
      |  spawn s M                                     (fork um filho no nursery s)
      |  newChan s                                     (: 1 ⊸ S ⊗ dual S, dentro de s)
      |  send M N | recv M | close M                  (comunicação)
      |  select lᵢ M | offer M { lᵢ ↦ Nᵢ }            (escolha ⊕ / &)
      |  raise | try M catch N                         (pânico / recuperação, EGV)
      |  cancel M                                      (descarta um endpoint → Closed ao par)
```

O açúcar de superfície reduz a isto (normativo, §6/§9):

```
makeCoupledPair          ≜  newChan
sendData / send          ≜  send
observe                  ≜  offer  (recv não-bloqueante que devolve o Trit)
bound arena $ do …       ≜  bound arena as s { … }        (== scope[Nursery s])
A ~ B                    ≜  (Ep %1 S) ⊗ (Ep %1 dual S)
A Maybe~ B               ≜  Ep %1 (Maybe~ (…))
panic e                  ≜  raise                         (dispara o Linear Unwinding)
```

### 2.4 Configurações de runtime (semântica assíncrona)

A comunicação é **assíncrona com buffers** (EGV; o scheduler é M:N com filas,
§11). Uma configuração `C` é uma composição paralela de threads e buffers de canal:

```
C, D ::= ⟨M⟩_t                    (thread t a avaliar M)
      |  c ↦ q                     (buffer do endpoint c com fila de mensagens q)
      |  C ∥ D                     (composição paralela)
      |  (ν c c') C                (canal com as duas pontas c, c' ligadas)
      |  ✗_t                        (thread t cancelada / em zombie até drenar)
```

`(ν c c')` é o **corte** (cut) da lógica linear: liga duas pontas duais. A
eliminação de cortes é a comunicação (§5).

---

## 3. Tipagem

Julgamento: `Γ ⊢ M : T`, com `Γ` um contexto **linear** (cada `x:T` usado
exatamente uma vez, salvo os `!ₘ T` que são irrestritos). A separação de contextos
`Γ = Γ₁ , Γ₂` (split disjunto) é o que impede aliasing — é a mesma disciplina que o
`check.rs` já aplica a `%1` (reutilizamos a máquina de linearidade existente).

### 3.1 Núcleo linear (resumo)

```
────────────         Γ₁⊢M:T   Γ₂⊢N:U            Γ₁⊢M:T⊗U   Γ₂,x:T,y:U⊢N:V
x:T ⊢ x:T            ─────────────────           ──────────────────────────
                     Γ₁,Γ₂ ⊢ (M,N):T⊗U          Γ₁,Γ₂ ⊢ let(x,y)=M in N : V

  Γ,x:T ⊢ M:U                 Γ₁⊢M:T⊸U   Γ₂⊢N:T
─────────────────            ─────────────────────
Γ ⊢ λx.M : T ⊸ U             Γ₁,Γ₂ ⊢ M N : U
```

`!ₘ T` (Many) admite contração e enfraquecimento (uso 0..n) — é a modalidade que já
existe na Axión para valores não-lineares; endpoints **nunca** são `!ₘ`.

### 3.2 Sessões

```
 Γ₁ ⊢ M:T     Γ₂ ⊢ N: !T.S                    Γ ⊢ M: ?T.S
──────────────────────────── (Send)         ─────────────────────── (Recv)
 Γ₁,Γ₂ ⊢ send M N : S                         Γ ⊢ recv M : T ⊗ S

 Γ ⊢ M : end                        Γ ⊢ M : Sⱼ        (j ∈ I)
──────────────────── (Close)       ───────────────────────────── (Select)
 Γ ⊢ close M : 1                    Γ ⊢ select lⱼ M : ⊕{lᵢ:Sᵢ}

 Γ₁ ⊢ M : &{lᵢ:Sᵢ}      ∀i.  Γ₂, xᵢ:Sᵢ ⊢ Nᵢ : U
──────────────────────────────────────────────────── (Offer)
 Γ₁,Γ₂ ⊢ offer M { lᵢ ↦ Nᵢ } : U
```

Nota sobre `send` e (A1): o `M:T` enviado é consumido de `Γ₁`; após `send`, o valor
**não está** em contexto — é isto que «congela» o remetente. A posse move-se para a
fila do canal e daí para o recetor.

### 3.3 Nursery e criação de canais (o coração da §9)

A regra do nursery é a instância `C = Nursery s` do `scope[C]` (A5). O parâmetro de
região `s` é **fantasma** (rígido, à la ST do Haskell): nada indexado por `s` pode
escapar do corpo, o que confina endpoints e filhos ao nursery.

```
 Γ₁ ⊢ M : Arena %1
 Γ₂ ⊢ N : T                 (s fresco; s ∉ ftv(Γ₂) ∪ ftv(T))     [confinamento]
──────────────────────────────────────────────────────────────── (Bound)
 Γ₁,Γ₂ ⊢ bound M as s { N } : T
```

A premissa `s ∉ ftv(T)` (o resultado não menciona a região) é a que **impede o
escape** de canais/recursos do nursery — a codificação de tipos da concorrência
estruturada.

```
              (dentro de um nursery s)                    (dentro de um nursery s)
 Γ ⊢ M : dual(S) ⊸ end                                ────────────────────────────── (NewChan)
──────────────────────────────── (Spawn)              Γ ⊢ newChan s : S ⊗ dual(S)
 Γ ⊢ spawn s M : S
```

`spawn s M` cria um filho que consome `dual(S)` (uma ponta) e devolve ao pai a
ponta `S` — **exatamente** o `fork` de GV. Toda a aresta nova é pai↔filho: por
indução, o grafo é uma **árvore** enraizada no nursery. `newChan` cria as duas
pontas para as passar a dois filhos irmãos (pipeline), o que produz **caminhos**
entre irmãos — acíclicos. Nunca se pode formar um ciclo porque `s` proíbe reintroduzir
uma ponta num antecessor já fechado. → **(A2)**.

### 3.4 Pânico e cancelamento (EGV, §7)

```
──────────── (Raise)          Γ₁ ⊢ M:T    Γ₂ ⊢ N: T          Γ ⊢ M : S
Γ ⊢ raise : T                 ─────────────────────── (Try)  ──────────────── (Cancel)
                              Γ₁,Γ₂ ⊢ try M catch N : T       Γ ⊢ cancel M : 1
```

`raise` tem tipo arbitrário `T` (nunca devolve). `cancel` consome um endpoint sem
o percorrer — o runtime envia-lhe `Closed`. Crucialmente, **`raise` num escopo com
endpoints vivos cancela-os todos** durante o unwinding (regra operacional §5.4) —
é isto que garante que nenhum endpoint é largado sem avisar o par (A3).

---

## 4. Exemplo tipado (Listagem 6.1, no cálculo)

```
type CryptoService = !(Buffer U8 %1) . end          -- envia UM buffer, termina

worker : Channel CryptoService %1 ⊸ 1
worker chan =
  let buf  = allocBuffer 4096          -- Γ ∋ buf : Buffer U8 %1
  let chan = send buf chan             -- buf consumido; chan : end
  close chan                           -- : 1     (buf e o chan antigo: fora de contexto)
```

Qualquer leitura posterior de `buf` falha na separação de contextos (A1) — é o
AX03xx (canais/session types) que o `check.rs` emitirá.

---

## 5. Semântica operacional (redução de configurações)

Reescrita `C ⟶ C'` sobre configurações, módulo estruturais (`∥` comutativo/
associativo, escopo `ν` extrusível). A comunicação é **assíncrona**: `send`
enfileira e continua; `recv/offer` consome da fila (ou suspende se vazia).

### 5.1 Comunicação (eliminação de cortes)

```
(ν c c')( ⟨E[send v c]⟩_t ∥ c' ↦ q )      ⟶   (ν c c')( ⟨E[c]⟩_t ∥ c' ↦ q·v )   [SEND]
(ν c c')( ⟨E[recv c']⟩_u ∥ c' ↦ v·q )     ⟶   (ν c c')( ⟨E[(v,c')]⟩_u ∥ c' ↦ q ) [RECV]
(ν c c')( ⟨E[select lⱼ c]⟩_t ∥ c'↦q )     ⟶   (ν c c')( ⟨E[c]⟩_t ∥ c'↦q·lⱼ )     [SEL]
(ν c c')( ⟨E[offer c'{lᵢ↦Nᵢ}]⟩_u ∥ c'↦lⱼ·q ) ⟶ (ν c c')( ⟨E[Nⱼ[c'/x]]⟩_u ∥ c'↦q ) [OFF]
```

`E[·]` é um contexto de avaliação (estrita, ANF — casa com o Axión Core). Uma
thread bloqueada num `recv/offer` de fila vazia é **suspensa** pelo scheduler
(§11) — não há espera ativa.

### 5.2 Fork e canais

```
⟨E[bound a as s {N}]⟩_t   ⟶   (νₛ) ( ⟨E[N]⟩_t )              [BOUND]  (abre a região/arena)
⟨E[spawn s M]⟩_t          ⟶   (ν c c')( ⟨E[c]⟩_t ∥ ⟨M c'⟩_{t'} ) [SPAWN] (t' filho fresco)
⟨E[newChan s]⟩_t          ⟶   (ν c c')  ⟨E[(c,c')]⟩_t          [NEWCHAN]
⟨E[close c]⟩_t ∥ c'↦ε     ⟶   ⟨E[()]⟩_t                        [CLOSE]  (fila drenada)
```

### 5.3 Núcleo funcional

Redução-β padrão, estrita, sobre `E[·]` — herdada do Axión Core (`interp`/backends
já a implementam).

### 5.4 Pânico → Linear Unwinding + cancelamento (A3)

Esta é a parte que EGV nos dá e que a §7 desenha. Seja `bound`ₛ o nursery mais
próximo na stack de `t` com endpoints vivos `c₁..cₖ` e recursos `@cleanup` `r₁..rⱼ`:

```
⟨E[raise]⟩_t   ⟶   ✗_t
                   ∥ (para cada endpoint cᵢ com par cᵢ')  cᵢ' ↦ q·Closed     -- avisa o par
                   ∥ reset(arenaₛ)                                            -- O(1): recua o bump-pointer
                   ∥ run(@cleanup r₁) ∥ … ∥ run(@cleanup rⱼ)                  -- ganchos externos
                                                                     [PANIC]
```

- **O(1) na memória**: `reset(arenaₛ)` é uma única instrução (recua o ponteiro);
  toda a memória volátil da sub-arena evapora (§3, §7).
- **O(filhos) em mensagens**: uma mensagem `Closed` por endpoint vivo. O par
  recebe-a como o ramo `Closed` do seu `&{…}` — um ramo **normal** do protocolo,
  não uma exceção fora-de-banda. Em `Maybe~`, o `observe` devolve o Trit `−1`.
- `try M catch N` intercepta o `✗` da sua sub-região e corre `N` (recuperação).

Consequência de desenho: como `Closed` é sempre um ramo do tipo de sessão
(§2.1), o recetor é **obrigado pela tipagem** a tratar o cancelamento — não há
caminho em que um cancelamento seja ignorado silenciosamente.

---

## 6. Metateoria (enunciados a mecanizar)

Os teoremas seguem GV/EGV; a mecanização (Iris/Actris) é o passo final da escada.
Enunciam-se aqui como o **contrato** que a implementação e o verificador de
referência têm de satisfazer.

- **T1 — Preservação (Subject Reduction).** Se `Γ ⊢ C` e `C ⟶ C'` então `Γ ⊢ C'`.
  *(A tipagem, incl. a dualidade dos canais, é invariante da redução.)*
- **T2 — Progresso.** Uma configuração fechada e bem-tipada ou está terminada
  (todas as threads em `()` / `close`), ou reduz, ou está **bloqueada só em IO
  externo**. Nunca fica presa numa espera cíclica interna. *(Corolário da
  aciclicidade — eliminação de cortes.)*
- **T3 — Fidelidade de Sessão.** Toda a comunicação num canal segue o seu tipo
  `S`/`dual(S)`; as duas pontas nunca divergem do protocolo. **(A1)** ⇒
  **zero data races**: cada endpoint tem um só dono (linearidade), logo nunca há
  dois acessos concorrentes ao mesmo endereço.
- **T4 — Deadlock-freedom.** Configurações geradas por `bound`/`spawn`/`newChan`
  têm grafo de comunicação **acíclico** (floresta); combinado com T2, nenhuma
  configuração bem-tipada faz *deadlock*. **(A2)**, corolário da tipagem.
- **T5 — Segurança do cancelamento (EGV).** Após um `raise`, (a) nenhum endpoint
  fica sem o seu par notificado (`Closed` entregue), (b) nenhuma memória de arena
  fica órfã, (c) todo `@cleanup` corre exatamente uma vez. Recuperação: O(1) em
  memória, O(filhos) em mensagens. **(A3)**.

### Escada de verificação (§9, §17) — por ordem de custo/confiança

1. **Property-based tests** — geradores de protocolos bem-tipados; verificar T1–T5
   por execução (à imagem de `props_mem.rs`, mas sobre configurações de sessão).
2. **Model-checking de CFSMs** — projetar cada sessão numa máquina de estados
   comunicante (Deniélou & Yoshida, ESOP 2012) e verificar compatibilidade +
   ausência de deadlock por exploração de estados.
3. **Metateoria mecanizada** — T1–T5 em **Iris/Actris** (Hinrichsen et al., POPL
   2020), que é *feito à medida* de session types em separation logic.
4. **Verificador de referência** (translation validation, Pnueli et al., TACAS
   1998) — cross-check, em compilação, das decisões do typechecker de produção
   contra a semântica. **Custo de runtime: zero** (A4).

---

## 7. Mapeamento para a implementação (o que o cálculo dita)

Não é código; é o contrato que a Fase 3 vai materializar, derivado das regras.

- **Runtime (§11).** Uma nursery **é uma arena com scheduler**. `spawn` = bump na
  arena da nursery (a tarefa é uma continuação defuncionalizada, a mesma
  maquinaria do `Susp`, §3A). Os **pontos de suspensão são [SEND]/[RECV]/[OFF]** —
  visíveis nos tipos, logo sem `async/await` nem *function coloring*. O fim do
  `bound` liberta tudo num reset ([BOUND]/[PANIC] partilham o mesmo `reset`). O
  scheduler é M:N com work-stealing e `io_uring`/`epoll` na fronteira de IO.
- **Frontend.** O parser expande `bound/using/imperative/susp` para `scope[C] s.`
  (A5); o `check.rs` reutiliza a separação de contextos linear que já tem, mais a
  regra (Bound) com a premissa de confinamento `s ∉ ftv(T)`. Novos códigos: banda
  **AX03xx** (canais e session types) — p.ex. uso de endpoint após `send`
  (violação de A1), ramo `Closed` não tratado, escape de endpoint do nursery.
- **Core IR.** ASC é o Axión Core + os nós `bound/spawn/newChan/send/recv/close/
  select/offer/raise/cancel`. Os backends (Cranelift/LLVM) baixam os nós de sessão
  para chamadas ao runtime do scheduler — tal como hoje baixam `withArena` para o
  runtime de arena.
- **Ordem de construção (§17).** (i) este cálculo; (ii) property tests + CFSMs
  sobre um interpretador de configurações; (iii) frontend+typechecker de sessões
  (banda AX03xx) validado contra (ii); (iv) runtime do scheduler; (v) mecanização
  Iris/Actris a médio prazo. Cada passo entrega isolado.

---

## 8. Decisões que este cálculo fixa (e questões em aberto)

**Fixado:**
- `spawn` é o `fork` de GV (aresta pai↔filho) — **não** um `spawn` livre estilo
  `go`/`std::thread`. É o que torna a floresta um invariante de tipos, não uma
  convenção.
- Comunicação **assíncrona com buffers** (EGV), não síncrona (CP puro) — casa com
  o scheduler M:N e com `Pending` (o `observe` não-bloqueante da §9).
- `Closed` é um **rótulo de sessão de primeira classe**, presente em todo `&{…}`
  — o cancelamento é um ramo do protocolo, tratado pela tipagem (T5).
- O confinamento é por **região fantasma `s`** (não por análise de escape ad-hoc),
  unificando com `imperative/using/susp` (A5).

**Em aberto (a resolver na mecanização, não bloqueiam a Fase 3):**
- **Delegação** (enviar um endpoint por um canal): sã em GV, mas interage com o
  confinamento `s` — provável restrição a delegar só dentro da mesma nursery.
- **`Maybe~`/acoplamento** (§9.D): o `Pending` exige uma semântica de fila com
  *polling*; confirmar que preserva T3 (é `offer` não-bloqueante — deve).
- **Combinadores** (`parMap`, `|>` telescópio, §8): provar que só produzem
  topologias-caminho entre irmãos (aciclicidade preservada) — candidato a
  property test dedicado.
- **Interação pânico↔delegação**: um endpoint em trânsito na fila quando ocorre um
  `raise` — EGV trata-o (a fila é drenada com `Closed`); confirmar na mecanização.

---

## 9. Referências (§16)

- P. Wadler. *Propositions as Sessions.* ICFP 2012.
- L. Caires, F. Pfenning. *Session Types as Intuitionistic Linear Propositions.* CONCUR 2010.
- S. Gay, V. Vasconcelos. *Linear type theory for asynchronous session types.* JFP 2010. (GV)
- S. Fowler, S. Lindley, J. G. Morris, S. Decova. *Exceptional Asynchronous Session Types.* POPL 2019. (EGV — §7)
- K. Honda, V. Vasconcelos, M. Kubo. *Language Primitives and Type Discipline for Structured Communication-Based Programming.* ESOP 1998.
- P.-M. Deniélou, N. Yoshida. *Multiparty Session Types Meet Communicating Automata.* ESOP 2012. (CFSMs)
- N. Kobayashi. *A Type System for Lock-Free Processes.* I&C 2002.
- L. Padovani. *Deadlock and Lock Freedom in the Linear π-Calculus.* CSL-LICS 2014.
- J. K. Hinrichsen, J. Bengtson, R. Krebbers. *Actris: Session-Type Based Reasoning in Separation Logic.* POPL 2020.
- R. Jung et al. *Iris from the Ground Up.* JFP 2018.
- A. Pnueli, M. Siegel, E. Singerman. *Translation Validation.* TACAS 1998.
