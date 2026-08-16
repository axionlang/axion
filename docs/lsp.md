# `axion-lsp` — the Language Server (§8)

A [Language Server](https://microsoft.github.io/language-server-protocol/) for
Axion, running the compiler front end through an incremental [salsa](#the-salsa-engine)
query engine. It reuses the same front end as `axionc --check`, so the editor sees
exactly the same stable `AXnnnn` codes and machine-applicable fixes the spec
promises in §8 — with unchanged work memoized across edits.

## What it provides

- **Diagnostics** — every [error code](error-codes.md) as an LSP diagnostic
  (code + span + message + help), republished on open/change/save.
- **Hover** — hovering a diagnostic shows its long-form explanation, the same text
  as `axionc --explain AXnnnn` (single source of truth: `explain_text`).
- **Quick fixes** — where the compiler attaches a machine-applicable `Fix` (e.g. the
  AX0101 "did you mean `length`?" rename), the LSP offers it as a one-click
  `quickfix` code action.

## Building & running

The server lives behind a cargo feature, so the default compiler build — and the
tokio-free `--dev` fast path — stay lean:

```sh
cargo build --features lsp            # builds the `axion-lsp` binary
./target/debug/axion-lsp              # speaks LSP over stdin/stdout
```

### VS Code (minimal client)

Point any generic LSP client at the binary. For example, with a tiny extension:

```js
const serverOptions = {
  command: "/path/to/axion-lsp",
  transport: TransportKind.stdio,
};
const clientOptions = {
  documentSelector: [{ scheme: "file", language: "axion" }],
};
new LanguageClient("axion", "Axion", serverOptions, clientOptions).start();
```

## The salsa engine

The server holds a persistent [salsa](https://github.com/salsa-rs/salsa)
database (`src/db.rs`). Each source file is a salsa **input**; the front end runs
as **tracked queries** split at the natural pipeline boundary:

- `parse(file)` depends only on that file's text (lex → layout → parse →
  `{-# LEVEL #-}` ceiling). Re-querying unchanged text — a hover, a code action, a
  no-op change — reuses the memoized parse instead of re-parsing.
- `file_diagnostics(file)` runs the cross-file downstream (imports + prelude + class
  lowering + linearity/Auto-Drop + HM inference) on top of `parse`.

Both stages call the *same* functions the CLI uses (`parse_source`,
`analyze_module`) — no logic is duplicated. Keeping the database across edits is
what makes it incremental: an edit re-sets one file's text input and salsa
recomputes only what depends on it. The constant prelude is parsed once per process
(a `OnceLock`), so it never re-parses on any edit.

## Scope & what's deferred

This increment memoizes at **file granularity**. Two things are deliberately left
for later increments:

- **Per-declaration invalidation** — editing one function currently re-checks the
  whole file. The finer-grained query graph (the spec's "only the affected AST node
  is invalidated") builds on this foundation.
- **Salsa-tracked cross-file imports** — the downstream still reads imported files
  straight from disk (invisible to salsa), so editing an imported file does not yet
  invalidate its dependents through the engine.

Also deferred: **rowan** (a lossless, error-resilient CST so diagnostics degrade
gracefully on half-typed code — a `parser.rs` rewrite), completion, go-to-def, the
inline ownership / Auto-Drop topology overlay (§8 "draws the graph inline"), and a
UTF-16 position remap (positions are ASCII-correct today).

## Internals

`src/lsp.rs`. The core is a pure, async-free function:

```rust
pub fn analyze(path: &str, src: &str) -> Vec<Analyzed>
```

which runs `compile_front` (wrapped in `catch_unwind` for robustness) and maps each
`Diagnostic` to an LSP diagnostic plus an optional `FixEdit`. The async
`LanguageServer` impl is a thin shell over it; the unit tests in
`axionc/tests/lsp.rs` exercise `analyze` directly.
