# `axionc` — Axion's compiler (Phase 1)

Axion's **own** compiler, written **from scratch in Rust** (§18). Unlike the
disposable Phase 0 EDSL bench (`../prototype`, in Haskell), this is the product:
it grows from here to self-hosting.

This is **Phase 1 — the walking skeleton** (§17): it does not deliver a single
feature, but the full **`parse → typecheck → run`** cycle over a minimal subset
(L0/L1). Everything else grows from there.

## Pipeline

```
.axi ─▶ lexer ─▶ layout ─▶ parser ─▶ check ────▶ infer ────▶ interp
       (logos)  (indent.)  (AST)    (names +     (HM types;  (tree-walking;
                                     linearity)   AX0200)     future --dev fast-path)
                                        │           │
                                        ▼           ▼
                              AXnnnn diagnostics (text | JSON, §8)
```

| Module | Role |
|--------|------|
| `src/lexer.rs` | Tokens with `logos` + a line table for spans. |
| `src/layout.rs` | Layout rule (indentation → virtual braces/`;`). |
| `src/parser.rs` | Recursive-descent → AST (`src/ast.rs`). |
| `src/check.rs` | Name resolution (`AX0101`) + **linearity** (`AX0001`/`AX0002`) + **Auto-Drop** (§2). |
| `src/infer.rs` | **Type inference** HM / Algorithm W (`AX0200`/`AX0201`). |
| `src/interp.rs` | Tree-walking interpreter (includes lambdas / higher order). |
| `src/codegen.rs` | **Native `--dev` backend** (Cranelift JIT) — Int core (§11/§18). |
| `src/props.rs` | **Preservation/progress** property tests (only in `cargo test`). |
| `src/diag.rs` | Stable `AXnnnn` diagnostics: text render (rustc style) and JSON. |

Deferred by decision ("lean AST first" architecture): `salsa` (incremental
engine) and `rowan` (lossless CST) come in when the LSP/incrementality is worth
the cost (Phase 4/8); the native `cranelift`/LLVM backends come afterwards.

## Usage

```sh
cargo build
cargo run -- ../examples/01_hello.axi      # prints: Hello, Axion!
cargo run -- ../examples/02_fib.axi        # prints: 832040
cargo run -- --check <file.axi>            # parse + typecheck + linearity only
cargo run -- --emit json <file.axi>        # diagnostics in JSON (§8)
cargo run -- --emit drops <file.axi>       # 'free's injected by Auto-Drop (§2)
cargo run -- --emit inplace <file.axi>     # in-place updates (Linear Elision, §2)
cargo run -- --emit arenas <file.axi>      # sub-arena NLL reset points (§3)
cargo run -- --emit clif <file.axi>        # Cranelift IR of the Int core (§11)
cargo run -- --backend cranelift <file.>   # JIT-compiles and runs main :: Int (native, §11)
cargo run -- --explain AX0001              # explains an error code
cargo test                                 # integration tests
```

## The Phase 1 goal (§17)

> "Listing 2.1 compiles and runs; a use-after-consume is rejected."

Walking-skeleton status:
- **Runs** (`examples/01_hello.axi`, `examples/02_fib.axi`): literals, functions
  with multiple clauses and pattern matching, recursion, arithmetic, `where`,
  application, `IO` (`putStrLn`/`show`).
- **Rejects** use-after-consume of a `%1` with `AX0001`
  (`tests/fixtures/use_after_consume.axi`), and a dropped `%1` with `AX0002`.

Not yet covered (they grow from here): `data`/records and the full Listing 2.1,
HM type inference, Auto-Drop, arenas, `%0.5`, native backend.
