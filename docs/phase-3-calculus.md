# Phase 3 — Formal Trail: the Axion Session Calculus (ASC)

> **Status.** This document is the *formal trail* that §17 of the spec requires
> **before** any concurrency code: *"prove before building; for concurrency,
> formalize the calculus before implementing it — the theory dictates the right
> design"*. It fixes the syntax, typing and operational semantics of the session
> core, states the metatheory theorems, and maps the calculus to the runtime (§11)
> and to the surface sugar (§6/§9). It implements **nothing**. It is the artifact
> that the verification ladder (property tests → CFSM model-checking → Iris/Actris
> → reference verifier) later discharges.

---

## 0. Why first, and what it decides

The absence of *deadlocks* and progress **are not a separate analysis**: they are
**corollaries of cut elimination** in linear logic (Wadler, *Propositions as
Sessions*, ICFP 2012; Caires & Pfenning, CONCUR 2010). A cut-free *proof net* is an
**acyclic tree** — and that tree is *exactly* the topology the `bound` block
(structured-concurrency nursery, §9) imposes on the communication graph.

Writing this calculus first decides three things that would be very expensive to
undo once there is a runtime:

1. **The shape of `bound`.** The tree of cuts dictates that `spawn` can only create
   parent↔child edges and that combinators only link siblings in *paths*
   (pipelines), never in cycles. The phantom region parameter `s` (§9) is the
   type-level encoding of the confinement to the tree.
2. **The panic-cancellation semantics** (§7). The design follows *Exceptional
   Asynchronous Session Types* (EGV; Fowler, Lindley, Morris & Decova, POPL 2019):
   an endpoint is never dropped silently — the panic sends `Closed` to the peer,
   which receives it as a normal branch of the protocol. This forces **every**
   session type to implicitly have the cancellation branch — a decision that shapes
   duality and the reduction table.
3. **The runtime↔types boundary** (§11). The suspension points of the M:N scheduler
   are *exactly* the channel operations (visible in the types: `Bound s`, `%1`
   endpoints). There is no `async`/`await` on the surface nor *function coloring*.

Adopted theoretical basis: **GV** (linear λ-calculus with sessions; Gay &
Vasconcelos) in the **EGV** variant (with exceptions/cancellation). GV is chosen,
not pure CP (process calculus), because Axion is *functional* — concurrency lives
in terms, not in a surface π-calculus. GV corresponds to CP (hence inherits
deadlock-freedom), and EGV is the exact extension that §7 cites.

We call the core **ASC — Axion Session Core**. It is a fragment of the Axion Core
(`core.rs`, a strict, linear ANF IR) enriched with channels.

---

## 1. Design axioms (what the calculus MUST satisfy)

Extracted from the spec; every rule and theorem below exists to honor one of these.

- **(A1) Race-freedom by ownership.** Each endpoint belongs to exactly one thread
  (linearity `%1`). Sending **moves** physical ownership; the sender is forbidden by
  the typechecker from touching the pointer from the send on (§6, Fig. 6.1). Zero
  data races is a **corollary of Session Fidelity**, not a separate mechanism.
- **(A2) Deadlock-freedom by construction.** The communication graph is a **forest**
  (acyclic topology); cyclic waiting is *inexpressible*. A corollary of typing (the
  tree of cuts), not of runtime detection (§9).
- **(A3) Cancellation without leaks.** Endpoints **have no `Drop`** (§2). On panic,
  the Linear Unwinding rewinds the sub-arena in O(1) and sends `Closed` to the peer
  — O(children) in cancellation messages (§7).
- **(A4) Zero latency / no monitors.** No safety check runs at runtime; the safety
  net watches the *compiler* (translation validation), not the program (§9, §11).
  Suspension = channel operation; `imperative` never suspends.
- **(A5) One concept, four surfaces.** `imperative`/`using`/`bound`/`susp` all
  desugar to a single Core form: `scope[C] s. e` — a scope that grants a linear
  capability `C`, with a phantom `s` preventing escape (§9.2). Concurrency is the
  instance `C = Nursery s`.

---

## 2. Syntax

### 2.1 Types

```
Value   T, U ::= Int | 1 | T ⊗ U            (linear pair)
              |  T ⊸ U                       (linear function, %1)
              |  !ₘ T                          (Many modality: unrestricted, §2)
              |  S                             (a session endpoint, always %1)
              |  Nursery s                     (nursery capability, region s)

Session S    ::= !T . S                        (send T, continue as S)
              |  ?T . S                        (receive T, continue as S)
              |  ⊕{ lᵢ : Sᵢ }                   (internal selection: choose a label)
              |  &{ lᵢ : Sᵢ }                   (external offer: accept any label)
              |  end                            (termination)
```

`⊕`/`&` are the **additive conjunction/disjunction** of linear logic. The `A & B`
choice of §9 (two potentials, only one used) is the binary case of `&` on the value
side; here it appears as the branch structure of the channel.

**Implicit cancellation branch (EGV).** By (A3), *every* endpoint can receive a
cancellation. Formally, each `S` has a distinguished label `Closed`; we write the
ternary offer of §9 (`Maybe~`) directly:

```
Maybe~ (T, S)  ≜  &{ Live : ?T.S ,  Closed : end ,  Pending : ?T.(Maybe~ (T,S)) }
```

`Live/Closed/Pending` correspond to the three Trits `+1/−1/0` (§9.D). `Pending` is
"not yet arrived" — `observe` is non-blocking and returns the Trit.

### 2.2 Duality

Two ends of a channel have **dual** types. `dual(·)` is involutive:

```
dual(!T.S)      = ?T.dual(S)
dual(?T.S)      = !T.dual(S)
dual(⊕{lᵢ:Sᵢ})  = &{lᵢ:dual(Sᵢ)}
dual(&{lᵢ:Sᵢ})  = ⊕{lᵢ:dual(Sᵢ)}
dual(end)       = end
```

A coupled pair `A ~ B` (§9.D) is exactly `(Ep %1 S) ⊗ (Ep %1 dual(S))`.

### 2.3 Terms

Functional core (already in the Axion Core) + session primitives. The primitives
are **suspension points** (A4) — the scheduler only switches tasks here.

```
M, N ::= x | () | (M, N) | let (x,y) = M in N        (linear core)
      |  λx. M | M N | let x = M in N
      |  bound M  as s { N }                          (opens a nursery; §9)
      |  spawn s M                                     (fork a child in nursery s)
      |  newChan s                                     (: 1 ⊸ S ⊗ dual S, inside s)
      |  send M N | recv M | close M                  (communication)
      |  select lᵢ M | offer M { lᵢ ↦ Nᵢ }            (choice ⊕ / &)
      |  raise | try M catch N                         (panic / recovery, EGV)
      |  cancel M                                      (discards an endpoint → Closed to the peer)
```

The surface sugar reduces to this (normative, §6/§9):

```
makeCoupledPair          ≜  newChan
sendData / send          ≜  send
observe                  ≜  offer  (non-blocking recv returning the Trit)
bound arena $ do …       ≜  bound arena as s { … }        (== scope[Nursery s])
A ~ B                    ≜  (Ep %1 S) ⊗ (Ep %1 dual S)
A Maybe~ B               ≜  Ep %1 (Maybe~ (…))
panic e                  ≜  raise                         (triggers the Linear Unwinding)
```

### 2.4 Runtime configurations (asynchronous semantics)

Communication is **asynchronous with buffers** (EGV; the scheduler is M:N with
queues, §11). A configuration `C` is a parallel composition of threads and channel
buffers:

```
C, D ::= ⟨M⟩_t                    (thread t evaluating M)
      |  c ↦ q                     (buffer of endpoint c with message queue q)
      |  C ∥ D                     (parallel composition)
      |  (ν c c') C                (channel with the two ends c, c' linked)
      |  ✗_t                        (thread t cancelled / zombie until drained)
```

`(ν c c')` is the **cut** of linear logic: it links two dual ends. Cut elimination
is communication (§5).

---

## 3. Typing

Judgment: `Γ ⊢ M : T`, with `Γ` a **linear** context (each `x:T` used exactly once,
except the `!ₘ T` which are unrestricted). The context separation `Γ = Γ₁ , Γ₂`
(disjoint split) is what prevents aliasing — it is the same discipline that
`check.rs` already applies to `%1` (we reuse the existing linearity machinery).

### 3.1 Linear core (summary)

```
────────────         Γ₁⊢M:T   Γ₂⊢N:U            Γ₁⊢M:T⊗U   Γ₂,x:T,y:U⊢N:V
x:T ⊢ x:T            ─────────────────           ──────────────────────────
                     Γ₁,Γ₂ ⊢ (M,N):T⊗U          Γ₁,Γ₂ ⊢ let(x,y)=M in N : V

  Γ,x:T ⊢ M:U                 Γ₁⊢M:T⊸U   Γ₂⊢N:T
─────────────────            ─────────────────────
Γ ⊢ λx.M : T ⊸ U             Γ₁,Γ₂ ⊢ M N : U
```

`!ₘ T` (Many) admits contraction and weakening (use 0..n) — it is the modality that
already exists in Axion for non-linear values; endpoints are **never** `!ₘ`.

### 3.2 Sessions

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

Note on `send` and (A1): the `M:T` being sent is consumed from `Γ₁`; after `send`,
the value is **not** in the context — this is what "freezes" the sender. Ownership
moves to the channel queue and from there to the receiver.

### 3.3 Nursery and channel creation (the heart of §9)

The nursery rule is the `C = Nursery s` instance of `scope[C]` (A5). The region
parameter `s` is **phantom** (rigid, à la Haskell's ST): nothing indexed by `s` can
escape the body, which confines endpoints and children to the nursery.

```
 Γ₁ ⊢ M : Arena %1
 Γ₂ ⊢ N : T                 (s fresh; s ∉ ftv(Γ₂) ∪ ftv(T))     [confinement]
──────────────────────────────────────────────────────────────── (Bound)
 Γ₁,Γ₂ ⊢ bound M as s { N } : T
```

The premise `s ∉ ftv(T)` (the result does not mention the region) is the one that
**prevents the escape** of channels/resources from the nursery — the type-level
encoding of structured concurrency.

```
              (inside a nursery s)                         (inside a nursery s)
 Γ ⊢ M : dual(S) ⊸ end                                ────────────────────────────── (NewChan)
──────────────────────────────── (Spawn)              Γ ⊢ newChan s : S ⊗ dual(S)
 Γ ⊢ spawn s M : S
```

`spawn s M` creates a child that consumes `dual(S)` (one end) and returns the `S`
end to the parent — **exactly** the `fork` of GV. Every new edge is parent↔child:
by induction, the graph is a **tree** rooted at the nursery. `newChan` creates the
two ends to pass to two sibling children (pipeline), which produces **paths**
between siblings — acyclic. A cycle can never form because `s` forbids reintroducing
an end into an already-closed ancestor. → **(A2)**.

### 3.4 Panic and cancellation (EGV, §7)

```
──────────── (Raise)          Γ₁ ⊢ M:T    Γ₂ ⊢ N: T          Γ ⊢ M : S
Γ ⊢ raise : T                 ─────────────────────── (Try)  ──────────────── (Cancel)
                              Γ₁,Γ₂ ⊢ try M catch N : T       Γ ⊢ cancel M : 1
```

`raise` has an arbitrary type `T` (never returns). `cancel` consumes an endpoint
without walking it — the runtime sends it `Closed`. Crucially, **`raise` in a scope
with live endpoints cancels them all** during unwinding (operational rule §5.4) —
this is what guarantees no endpoint is dropped without warning the peer (A3).

---

## 4. Typed example (Listing 6.1, in the calculus)

```
type CryptoService = !(Buffer U8 %1) . end          -- send ONE buffer, terminate

worker : Channel CryptoService %1 ⊸ 1
worker chan =
  let buf  = allocBuffer 4096          -- Γ ∋ buf : Buffer U8 %1
  let chan = send buf chan             -- buf consumed; chan : end
  close chan                           -- : 1     (buf and the old chan: out of context)
```

Any later read of `buf` fails on the context separation (A1) — it is the AX03xx
(channels/session types) that `check.rs` will emit.

---

## 5. Operational semantics (configuration reduction)

Rewriting `C ⟶ C'` over configurations, modulo structural equations (`∥`
commutative/associative, `ν` scope extrudable). Communication is **asynchronous**:
`send` enqueues and continues; `recv/offer` consumes from the queue (or suspends if
empty).

### 5.1 Communication (cut elimination)

```
(ν c c')( ⟨E[send v c]⟩_t ∥ c' ↦ q )      ⟶   (ν c c')( ⟨E[c]⟩_t ∥ c' ↦ q·v )   [SEND]
(ν c c')( ⟨E[recv c']⟩_u ∥ c' ↦ v·q )     ⟶   (ν c c')( ⟨E[(v,c')]⟩_u ∥ c' ↦ q ) [RECV]
(ν c c')( ⟨E[select lⱼ c]⟩_t ∥ c'↦q )     ⟶   (ν c c')( ⟨E[c]⟩_t ∥ c'↦q·lⱼ )     [SEL]
(ν c c')( ⟨E[offer c'{lᵢ↦Nᵢ}]⟩_u ∥ c'↦lⱼ·q ) ⟶ (ν c c')( ⟨E[Nⱼ[c'/x]]⟩_u ∥ c'↦q ) [OFF]
```

`E[·]` is an evaluation context (strict, ANF — matches the Axion Core). A thread
blocked on a `recv/offer` of an empty queue is **suspended** by the scheduler (§11)
— there is no busy waiting.

### 5.2 Fork and channels

```
⟨E[bound a as s {N}]⟩_t   ⟶   (νₛ) ( ⟨E[N]⟩_t )              [BOUND]  (opens the region/arena)
⟨E[spawn s M]⟩_t          ⟶   (ν c c')( ⟨E[c]⟩_t ∥ ⟨M c'⟩_{t'} ) [SPAWN] (t' fresh child)
⟨E[newChan s]⟩_t          ⟶   (ν c c')  ⟨E[(c,c')]⟩_t          [NEWCHAN]
⟨E[close c]⟩_t ∥ c'↦ε     ⟶   ⟨E[()]⟩_t                        [CLOSE]  (queue drained)
```

### 5.3 Functional core

Standard β-reduction, strict, over `E[·]` — inherited from the Axion Core
(`interp`/backends already implement it).

### 5.4 Panic → Linear Unwinding + cancellation (A3)

This is the part EGV gives us and that §7 designs. Let `bound`ₛ be the nearest
nursery on the stack of `t` with live endpoints `c₁..cₖ` and `@cleanup` resources
`r₁..rⱼ`:

```
⟨E[raise]⟩_t   ⟶   ✗_t
                   ∥ (for each endpoint cᵢ with peer cᵢ')  cᵢ' ↦ q·Closed     -- warns the peer
                   ∥ reset(arenaₛ)                                            -- O(1): rewinds the bump-pointer
                   ∥ run(@cleanup r₁) ∥ … ∥ run(@cleanup rⱼ)                  -- external hooks
                                                                     [PANIC]
```

- **O(1) in memory**: `reset(arenaₛ)` is a single instruction (rewinds the pointer);
  all volatile memory of the sub-arena evaporates (§3, §7).
- **O(children) in messages**: one `Closed` message per live endpoint. The peer
  receives it as the `Closed` branch of its `&{…}` — a **normal** branch of the
  protocol, not an out-of-band exception. In `Maybe~`, `observe` returns the Trit
  `−1`.
- `try M catch N` intercepts the `✗` of its sub-region and runs `N` (recovery).

Design consequence: since `Closed` is always a branch of the session type (§2.1),
the receiver is **forced by typing** to handle the cancellation — there is no path
in which a cancellation is silently ignored.

---

## 6. Metatheory (statements to mechanize)

The theorems follow GV/EGV; the mechanization (Iris/Actris) is the final step of
the ladder. They are stated here as the **contract** the implementation and the
reference verifier must satisfy.

- **T1 — Preservation (Subject Reduction).** If `Γ ⊢ C` and `C ⟶ C'` then `Γ ⊢ C'`.
  *(Typing, incl. the duality of channels, is invariant under reduction.)*
- **T2 — Progress.** A closed, well-typed configuration is either terminated (all
  threads at `()` / `close`), or reduces, or is **blocked only on external IO**. It
  never gets stuck in an internal cyclic wait. *(A corollary of acyclicity — cut
  elimination.)*
- **T3 — Session Fidelity.** Every communication on a channel follows its type
  `S`/`dual(S)`; the two ends never diverge from the protocol. **(A1)** ⇒ **zero
  data races**: each endpoint has a single owner (linearity), so there are never two
  concurrent accesses to the same address.
- **T4 — Deadlock-freedom.** Configurations generated by `bound`/`spawn`/`newChan`
  have an **acyclic** communication graph (forest); combined with T2, no well-typed
  configuration deadlocks. **(A2)**, a corollary of typing.
- **T5 — Cancellation safety (EGV).** After a `raise`, (a) no endpoint is left with
  its peer un-notified (`Closed` delivered), (b) no arena memory is orphaned, (c)
  every `@cleanup` runs exactly once. Recovery: O(1) in memory, O(children) in
  messages. **(A3)**.

### Verification ladder (§9, §17) — by order of cost/confidence

1. **Property-based tests** — generators of well-typed protocols; check T1–T5 by
   execution (in the image of `props_mem.rs`, but over session configurations).
2. **CFSM model-checking** — project each session onto a communicating state
   machine (Deniélou & Yoshida, ESOP 2012) and check compatibility + absence of
   deadlock by state exploration.
3. **Mechanized metatheory** — T1–T5 in **Iris/Actris** (Hinrichsen et al., POPL
   2020), which is *tailor-made* for session types in separation logic.
4. **Reference verifier** (translation validation, Pnueli et al., TACAS 1998) — a
   compile-time cross-check of the production typechecker's decisions against the
   semantics. **Runtime cost: zero** (A4).

---

## 7. Mapping to the implementation (what the calculus dictates)

It is not code; it is the contract Phase 3 will materialize, derived from the rules.

- **Runtime (§11).** A nursery **is an arena with a scheduler**. `spawn` = bump in
  the nursery arena (the task is a defunctionalized continuation, the same machinery
  as `Susp`, §3A). The **suspension points are [SEND]/[RECV]/[OFF]** — visible in the
  types, hence no `async/await` nor *function coloring*. The end of the `bound` frees
  everything in one reset ([BOUND]/[PANIC] share the same `reset`). The scheduler is
  M:N with work-stealing and `io_uring`/`epoll` at the IO boundary.
- **Frontend.** The parser expands `bound/using/imperative/susp` into `scope[C] s.`
  (A5); `check.rs` reuses the linear context separation it already has, plus the
  (Bound) rule with the confinement premise `s ∉ ftv(T)`. New codes: the **AX03xx**
  band (channels and session types) — e.g. endpoint use after `send` (A1 violation),
  unhandled `Closed` branch, endpoint escape from the nursery.
- **Core IR.** ASC is the Axion Core + the nodes `bound/spawn/newChan/send/recv/
  close/select/offer/raise/cancel`. The backends (Cranelift/LLVM) lower the session
  nodes to scheduler-runtime calls — just as today they lower `withArena` to the
  arena runtime.
- **Construction order (§17).** (i) this calculus; (ii) property tests + CFSMs over
  a configuration interpreter; (iii) session frontend+typechecker (AX03xx band)
  validated against (ii); (iv) scheduler runtime; (v) Iris/Actris mechanization in
  the medium term. Each step ships in isolation.

---

## 8. Decisions this calculus fixes (and open questions)

**Fixed:**
- `spawn` is GV's `fork` (parent↔child edge) — **not** a free `spawn` in the style
  of `go`/`std::thread`. It is what makes the forest a type invariant, not a
  convention.
- **Asynchronous, buffered** communication (EGV), not synchronous (pure CP) —
  matches the M:N scheduler and `Pending` (the non-blocking `observe` of §9).
- `Closed` is a **first-class session label**, present in every `&{…}` — cancellation
  is a branch of the protocol, handled by typing (T5).
- Confinement is by **phantom region `s`** (not by ad-hoc escape analysis), unifying
  with `imperative/using/susp` (A5).

**Open (to resolve in the mechanization, they don't block Phase 3):**
- **Delegation** (sending an endpoint over a channel): sound in GV, but interacts
  with the `s` confinement — likely restricted to delegating only within the same
  nursery.
- **`Maybe~`/coupling** (§9.D): `Pending` requires a queue semantics with *polling*;
  confirm it preserves T3 (it is non-blocking `offer` — it should).
- **Combinators** (`parMap`, `|>` telescope, §8): prove they only produce
  path-topologies between siblings (acyclicity preserved) — a candidate for a
  dedicated property test.
- **Panic↔delegation interaction**: an endpoint in transit in the queue when a
  `raise` occurs — EGV handles it (the queue is drained with `Closed`); confirm in
  the mechanization.

---

## 9. References (§16)

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
