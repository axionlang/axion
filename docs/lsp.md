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
- **Document symbols / outline** — top-level declarations, from the CST
  (`textDocument/documentSymbol`).
- **Folding ranges** — each multi-line top-level declaration folds
  (`textDocument/foldingRange`).
- **Selection ranges** — "expand selection" walks the CST from the token under the
  cursor out through its enclosing expression/pattern/declaration nodes
  (`textDocument/selectionRange`).

The last three are built on the lossless [rowan CST](#rowan-cst-stages-12); the
`lsp` feature pulls in `cst`. (The `outline`/`folds`/`selection` cores are pure
functions, unit-tested in `tests/lsp.rs`.)

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

### Per-declaration invalidation

The linearity / Auto-Drop / name-resolution check runs **per declaration**. The key
is that its environment — the callable global names plus the `Ctx` of parameter
multiplicities, `data` shapes and class headers (`check::signature_env`) — is
derived only from *signatures and types*, never function bodies. So:

- `sig_env(file)` is `PartialEq` and salsa **backdates** it across body edits;
- each function is a salsa tracked struct (`DeclItem`, identified by name), and
  `check_decl(item)` depends only on that function's AST and `sig_env`.

Editing one function's body changes only that function's `DeclItem.func`, so **only
its `check_decl` re-runs** — every other declaration's linearity check is reused
(proven by `tests/salsa.rs::editing_one_body_rechecks_only_that_declaration`).

### Per-declaration inference (annotated-function firewall)

HM inference is also **per-declaration for annotated functions**. Axión's top-level
signatures are optional, so unannotated functions share one monomorphic
substitution and must be inferred together — but a function that is **isolated**
(has a full signature *and* references no unannotated top-level function) only ever
unifies against annotated schemes, builtins and constructors, all body-stable. Its
inference therefore reproduces the whole-module result exactly and is memoized per
declaration (`infer_decl`), keyed on its own AST and the body-and-span-normalized
`sig_view`. Unannotated functions and their dependents are inferred together in a
whole-module `infer_residual`.

The soundness of that split — that `{isolated per-decl ∪ residual}` equals
whole-module inference — is guarded by a **differential test** over every fixture
(`tests/salsa.rs::engine_diagnostics_match_whole_module`).

**Position independence.** Each per-decl query is keyed on its function's body with
spans made **relative** to the declaration's start (`normalized` in `db.rs`), so a
declaration's cached body is identical wherever it sits in the file. A
length-*changing* edit to one declaration therefore does NOT invalidate the
declarations after it (which merely shift): only the edited declaration re-runs. The
memoized diagnostics carry relative spans and are re-based to absolute per edit with
each declaration's current base offset — a cheap, non-memoized step in
`diagnostics_of`. Both the per-decl linearity and inference queries benefit.

### Cross-file imports

Imports flow through salsa. Each source file is a `SourceFile` input; a singleton
`Vfs` input maps import paths to those inputs. When a module resolves an import, the
engine looks the path up in the `Vfs` and reads the imported file's `text(db)` — and
*that tracked read* makes the importer's `processed_module` depend on the imported
file. So **editing an imported file (an open buffer) invalidates its importers** and
refreshes their diagnostics (`tests/salsa.rs::editing_an_imported_file_updates_the_importer`).

Before querying, `AxionDb::load_imports` walks the import graph and pulls every
imported file into the database as an input — reading from disk only for files the
editor hasn't opened; open files keep their in-memory buffer. Disk reads happen there
(mutably, setting inputs), never inside a query. The `Vfs` map changes only when a
file is *added*, so ordinary text edits don't invalidate unrelated importers.

### Resilience (half-typed code)

The parser recovers at **declaration boundaries**: a malformed top-level
declaration is reported (AX0100) and skipped, and parsing resumes at the next
declaration, so every other declaration still parses and gets full per-decl
analysis (`parser::parse_module_resilient`, `tests/…parser_recovers_at_declaration_boundaries`).
Editing one declaration therefore no longer blanks out the whole file's
diagnostics. Because signatures and clauses are separate declarations, a broken
clause body keeps the function's *signature* in scope, so references to it from
elsewhere don't spuriously go unresolved.

This is declaration-level recovery on the existing recursive-descent parser.

### Rowan CST (Stages 1–2)

A lossless [rowan](https://github.com/rust-analyzer/rowan) CST is being introduced in
stages (`src/cst.rs`, `--features cst`).

- **Stage 1** — a *lossless* green tree: every byte of source, including whitespace
  and comments, is a leaf, so it round-trips exactly (`cst_round_trips_every_fixture`).
- **Stage 2** — **grammar structure**: top-level declaration nodes with nested
  expression and pattern nodes (`APP_EXPR`, `BINOP_EXPR`, `IF_EXPR`, `CON_PAT`, …),
  plus **ERROR nodes** over declarations the parser could not parse. To avoid a
  second, divergent parser, the structure is derived from the AST the proven
  recursive-descent parser already produces — its `Expr`/`Pat`/`Clause` spans drive
  where nodes open and close, while every token is still emitted, so losslessness
  holds by construction. Powers document symbols and selection/navigation at
  expression granularity.

- **Stage 3a** — the first slice of the pipeline flip: a *token-driven*,
  CST-emitting parser (via rowan checkpoints) that parses tokens DIRECTLY into a
  lossless CST — rather than deriving structure from the AST — plus a CST→AST
  lowering (`lower_expr`). It currently covers a subset of expressions (atoms,
  application, `* + - == < >`, parens) and is proven to produce EXACTLY the same
  `ast::Expr` as the recursive-descent parser by a differential test
  (`token_driven_parser_matches_recursive_descent_over_the_subset`, plus an honest
  `subset_boundary_is_honest`). Later slices extend the grammar (patterns, types,
  declarations, the remaining operators/desugarings); once it covers everything and
  provably agrees over all fixtures, the default pipeline flips onto it and the
  recursive-descent parser is retired.

It is **additive**: the analysis pipeline still runs on `ast::Module` via the
recursive-descent parser; the token-driven parser is validated behind the `cst`
feature and does not drive checking yet. Deferred: extending the token-driven parser
to the full grammar and flipping the pipeline; structuring type signatures and
`data`/`class` internals in the derived CST; intra-*declaration* error recovery. A
full rowan migration is multi-stage by design.

## Scope & what's deferred

- **Whole-module still** (re-run on any edit): the session/`bound`/instance checks,
  and inference of unannotated functions (the residual).
- A rowan lossless CST (intra-declaration recovery, formatting), completion,
  go-to-definition, the inline ownership / Auto-Drop topology overlay, a UTF-16
  position remap, and the WASM playground.

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
