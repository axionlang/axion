# `axion-lsp` — the Language Server (§8)

A walking-skeleton [Language Server](https://microsoft.github.io/language-server-protocol/)
for Axion. It reuses the compiler front end directly (`compile_front`), so the
editor sees exactly what `axionc --check` sees — the same stable `AXnnnn` codes and
the same machine-applicable fixes the spec promises in §8.

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

## Scope (this increment)

This is the **server layer only**. On every edit it recompiles the whole buffer
and republishes — no incrementality yet. At today's file sizes a full reparse is
sub-perceptible, and it is the honest baseline the later work is measured against.

Deferred to later increments:

- **salsa** — the incremental query engine (per-file invalidation, the sub-ms
  feedback the spec quantifies), layered on top of this server.
- **rowan** — a lossless, error-resilient CST so diagnostics degrade gracefully on
  half-typed code (a `parser.rs` rewrite).
- Completion, go-to-definition, the inline ownership / Auto-Drop topology overlay
  (§8 "draws the graph inline"), and a UTF-16 position remap (positions are ASCII-
  correct today).

## Internals

`src/lsp.rs`. The core is a pure, async-free function:

```rust
pub fn analyze(path: &str, src: &str) -> Vec<Analyzed>
```

which runs `compile_front` (wrapped in `catch_unwind` for robustness) and maps each
`Diagnostic` to an LSP diagnostic plus an optional `FixEdit`. The async
`LanguageServer` impl is a thin shell over it; the unit tests in
`axionc/tests/lsp.rs` exercise `analyze` directly.
