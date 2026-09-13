# Faithfulness bridge — tying the Lean model to `verify.rs`

`AxionDrop.lean` / `AxionAlias.lean` / `AxionKey.lean` prove a hand-written *model* of the
drop-verifier sound. On their own they guarantee only that the **model** is sound — a beautiful
proof of a model that has drifted from the compiler proves little. The bridge closes that gap: for
each canonical memory-safety shape it checks that the **real verifier's verdict** on a real `.axi`
program equals the verdict the **corresponding Lean theorem proves**.

Two machine-checked halves, linked by a manifest:

- **Lean side** — `metatheory/check.sh` proves each theorem below (every verdict is a proof, not a
  claim), all depending on `[propext]` only, no `sorry`.
- **Code side** — `axionc/tests/bridge.rs` runs `axionc --emit verify` on the paired program and
  asserts the verifier's verdict (and, for rejects, the corruption *kind*) matches the theorem's.
  The `lean_theorem` field of each row is the explicit link.

The unsafe shapes are produced with the same default-off hooks Track 1 used to prove the verifier
is a sound net, so the verifier analyses exactly the Core the model's unsafe rules abstract:

- `AXION_NO_ALIAS_COPY=1` regenerates the conditional-param-return alias Core that R-1…R-5's copy
  removes → the verifier sees the `borrow`-into-a-reused-arg shape (`Cell.bref` in the model).
- `AXION_NAIVE_ELEM_KEY=1` regenerates the multi-param mis-key Core the `cond_elem_key` fix removed
  → the verifier sees the wrong-reclaimer shape (`Op.drop n key`, key ≠ type in the model).

## Correspondence table

| Abstract shape | Lean theorem (proved) | verdict | Real program (`+ hook`) | Verifier verdict |
|---|---|---|---|---|
| balanced linear program | *AxionDrop*: balanced program accepted | accept | `list_heap_reclaim.axi` | clean |
| cond. param-return, copy on (R-5) | `AxionAlias.v1_copy_fixed_accepted` | accept | `alias_return_net.axi` | clean |
| cond. container-return, copy on (R-5) | `AxionAlias.v1_copy_fixed_accepted` | accept | `container_copy_reclaim.axi` | clean |
| multi-param sum, correct key | `AxionKey.correct_key_accepted` | accept | `either_map_reclaim.axi` | clean |
| safe borrow then owner freed | `AxionAlias.safe_borrow_accepted` | accept | `dead_binding_reclaim.axi` | clean |
| cond. param-return alias, copy off (V-1) | `AxionAlias.v1_conditional_alias_return_rejected` | reject | `alias_return_net.axi` `+NO_ALIAS_COPY` | `DropOfAlias` |
| cond. container-return alias, copy off (V-1) | `AxionAlias.v1_conditional_alias_return_rejected` | reject | `container_copy_reclaim.axi` `+NO_ALIAS_COPY` | `DropOfAlias` |
| multi-param sum, wrong key (V-2) | `AxionKey.wrong_key_drop_rejected` | reject | `either_map_reclaim.axi` `+NAIVE_ELEM_KEY` | `WrongDropKey` |

Every row is asserted by `bridge.rs`; the accept/reject verdict *and* (for rejects) the corruption
kind must match. This is the machine-checked statement that the model tracks the code on these
shapes, not merely the prose correspondence tables in each file's header.

## Running

```sh
./metatheory/bridge.sh          # Lean proofs (check.sh) + verifier agreement (cargo test bridge)
```

## Scope & honesty

- **Curated, not whole-corpus auto-translation.** The bridge pairs each *canonical* shape (the
  classes AX0910/AX0912/V-1/V-2/R-5 are about) with a real program, rather than mechanically
  translating every corpus function's Core into the model — the model is a deliberately small
  abstraction, and most corpus functions use features outside it (closures, arrays, sessions,
  polymorphic elements). The heavier follow-up is an `--emit model-trace` that lowers each
  in-model function's final Core (via `delta::op_delta_effect`) into a Lean `Expr` and checks it
  with an executable transcription of `Chk`, widening coverage from the canonical shapes to the
  whole in-model fragment.
- **Leak rejection is not paired.** By design no natural `.axi` fires the AX0911 leak gate (leaks
  are safe false-negatives, reclaimed by Auto-Drop); the Lean `no_leak` theorems correspond to the
  gate itself, whose only firing is synthetic. There is thus no real leak-reject program to pair.
