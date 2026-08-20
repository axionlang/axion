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
- **Completion** (`textDocument/completion`) — the names in scope at the cursor:
  locals (parameters, `let`/`where`, lambda/`case` binders of the enclosing function),
  the module's top-level declarations (functions, `data` types + constructors, classes
  + methods, foreigns), the builtins, and the keywords — de-duplicated (locals shadow
  the rest). Local suggestions survive a **half-typed body**: the enclosing declaration's
  binders are harvested from the recovered token-driven CST
  ([intra-declaration recovery](#intra-declaration-recovery)), so a clause with an
  incomplete expression still offers its parameters and `let`/`where` names (an
  over-approximation of scope — the client filters by the typed prefix). Even a stray
  illegal character no longer clears the buffer — see
  [intra-declaration recovery](#intra-declaration-recovery).
- **Go to definition** (`textDocument/definition`) — scope-aware and **cross-file**: a
  local binder (parameter, `let`/`where`, lambda or `case` pattern) in the enclosing
  function wins over a top-level name (resolved via the AST's binder spans); otherwise
  the top-level declaration that introduces it — a function, `data` type *or
  constructor*, `class` name *or method*, or `foreign` — is found in the CST, first in
  this file and then in each **imported** file (the definition may live in another file).
- **Find references** (`textDocument/references`) and **rename** (`textDocument/rename`)
  — the inverse of go-to-definition: every occurrence of the name is grouped by the
  *definition* it resolves to (a local binder via the AST, or a top-level declaration
  site via the CST — keyed by `(file, span)`), so a parameter's references stay within
  its function and never bleed into a same-named top-level name (shadowing is handled,
  across files too). A top-level name's references are gathered from **every file in the
  workspace**, which is indexed by scanning the `initialize` workspace roots (falling back
  to the active file's directory) for `.axi` files — so references and rename reach a file
  that **imports** the symbol even when it is *not open* (the reverse import graph), not
  just the active file's forward import closure. Open buffers win over disk (an unsaved
  edit is resolved from its buffer); build/hidden directories are skipped. References
  honour `include_declaration`; rename emits one multi-file `WorkspaceEdit`.
- **Signature help** (`textDocument/signatureHelp`) — while writing a call, the callee's
  type signature with the **active parameter** highlighted. Application is by
  juxtaposition, so the head function and the argument index are recovered by walking the
  token stream left from the cursor (bracket-depth-aware; the spine ends at an operator,
  keyword, `=`, `,`, or the enclosing `(`), and a trailing space advances to the next
  parameter. The signature is the function's declared type (`Func.sig`), found in this
  file or an imported one; the label reuses the source-like type formatting
  (`(a -> b) -> List a -> List b`). Covers functions and `foreign`s with a declared type,
  **data constructors** (the arrow type is built from the field types — `Cons :: a ->
  List a -> List b`), and the built-in **prelude** functions and constructors (`map`,
  `length`, `Just`, …). The few true primitives whose types live only in inference (e.g.
  `putStrLn`) are the remaining gap.
- **Ownership overlay** (`textDocument/inlayHint`) — §8's "draw the graph inline": the
  Auto-Drop / ownership topology the compiler already computes, shown *inline* at each
  source span. Every linear resource's inserted `free` — `⌫ drop x: Ty`, with a tooltip
  saying why it dies here (*at entry, never used* / *after its last read*) — every
  in-place record reuse (`↻ reuse x`), and every sub-arena NLL reset (`⤺ reset s`). This
  is the one editor feature that is uniquely Axión: it makes linearity and Auto-Drop
  *visible* rather than implicit. Hints come from `check::Analysis` (`drops`/`inplace`/
  `arenas`); prelude-owned drops are filtered out (the prelude is compiled in its own
  coordinate space), so only the buffer's own resources are annotated.

The scope-aware features are built on the lossless [rowan CST](#rowan-cst-stages-12); the
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

### Intra-declaration recovery

Declaration-level recovery still drops a *single* malformed declaration whole — and
the mid-edit state (an incomplete expression *inside* the one you're typing) is the
common case. The **token-driven CST parser** (`cst::parse_recover`) recovers *within* a
declaration: an item its block parser cannot start is wrapped in an `ERROR` node and the
block **continues**, so the surrounding declarations keep their structure, and a
half-typed clause keeps its parameter `VAR_PAT`s even when its body has a hole
(`cst::ExprParser::recover_item`, guaranteed to make progress so parsing always
terminates). Recovery marks the parse non-`full`, so the flip's differential gate
(`module_matches_parser`, which requires a fully clean parse) is unaffected — the 205-fixture
equivalence still holds.

Completion consumes this directly: `cst::binders_in_decl(offset)` harvests the binder
names of the declaration under the cursor from the recovered tree, feeding the
half-typed-body completion above.

Recovery reaches the **lexer** too: `lexer::lex_recover` skips an unrecognized character
(collecting its span) and keeps going instead of failing on the first one, so a stray
illegal character no longer clears the token stream — the skipped byte survives in trivia
(the CST still round-trips) and the surrounding declarations keep their structure. Both
CST entry points (`build_cst`, `parse_module_cst`) use it; the compiler's own `lex` still
fails fast and reports the character as AX0100, so the *diagnostic* is unchanged while
the *editor features* stay alive. A lex error keeps the token-driven parse non-`full`, so
the flip's differential gate is unaffected.
(`tests/…token_driven_parser_recovers_within_a_declaration`,
`tests/…completion_survives_a_half_typed_body`,
`tests/…a_stray_illegal_character_does_not_blank_the_cst`.)

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
  lowering (`lower_expr`). It covers the full expression operator ladder with its
  desugarings (`:`→`Cons`, `.`→`compose`, `$`→application, `++`, backtick infix,
  dotted operators), application, tuples, parenthesised expressions, `if`, lambdas
  with patterns, list literals and ranges (`[a, b]`, `[a..b]`), operator sections
  (`(+)`), records (`Con { f = e }`), the layout-block forms `case … of { … }`
  and `let { … } in …`, and `do`-notation (desugared to nested `case`) — in short,
  the **entire expression grammar**. It runs on the real layout tokens (`LTok` with
  virtual `VLBrace`/`VSemi`/`VRBrace`; trivia is woven only for real tokens), and is
  proven to produce EXACTLY the same `ast::Expr` as the recursive-descent parser by a
  differential test (`token_driven_parser_matches_recursive_descent_over_the_subset`).
  The token-driven parser now also handles the **whole module grammar** — types
  (`Con`/`Var`/`App`/`Arrow` with `%mult`/`Tuple`/`Unit` + `C a =>` constraints),
  signatures, function clauses (patterns, plain/guarded bodies, `where`), `data`
  (positional + record constructors, `deriving`), `class`, `instance`, `foreign`, the
  module header, and imports — and lowers to EXACTLY the same `ast::Module` as the
  recursive-descent parser **over every fixture and example**
  (`token_driven_module_matches_over_all_fixtures`, 205 modules; spans normalised).
  `cst::parse_module_full` exposes it as a drop-in parse entry.

  The **flip** — making it the compiler's primary parser — is **done** (the `cst`
  feature is on by default). Spans are *semantic keys* in the pipeline (the
  `array_tys`/`makecon_tys` monomorphisation maps are keyed by span, and diagnostics
  render spans), so structural equivalence wasn't enough — the CST lowering had to
  reproduce the recursive-descent parser's span conventions **byte-for-byte**. It now
  does: `span_to_next_token` for productions whose span runs to the *next* token
  (clauses, compound/bracketed exprs, applied-constructor and tuple patterns, and the
  `data`/`class`/`instance`/`foreign` decls), operand-derived App/BinOp spans (so a
  parenthesised argument is transparent), and a context rule for nullary constructor
  patterns. `cst::first_span_mismatch` pinpoints any divergence;
  `token_driven_module_spans_are_byte_exact_over_all_fixtures` asserts there is none
  over all 205 fixtures, and the oracle confirms a `cst`-built compiler is byte-identical.

`parse_source` routes a fully clean parse through `cst::parse_module_full`; a malformed
file (or a `--no-default-features` build) falls back to the recursive-descent parser for
declaration-level recovery and parse-error diagnostics. Retiring `parser.rs` entirely
needs the CST path to lower a *recovered* tree (with `ERROR` nodes) into a partial AST
plus diagnostics — a follow-up. A full rowan migration is multi-stage by design.

## Scope & what's deferred

- **Whole-module still** (re-run on any edit): the session/`bound`/instance checks,
  and inference of unannotated functions (the residual).
- Signature help for the few true primitives whose types live only in inference
  (`putStrLn`, arithmetic) — functions, `foreign`s, constructors, and prelude built-ins
  are covered — and the WASM playground. The project index re-scans on each references/rename
  request (no persistent, file-watched index yet — fine at this scale). Positions are
  negotiated as UTF-16 only (the LSP default); UTF-8/UTF-32 `positionEncoding` is not
  advertised.

Still deferred: **retiring `parser.rs`** (the CST is the default parser now, but the
recursive-descent parser is still the recovery/`--no-default-features` fallback — deleting
it needs recovered-tree → partial-AST lowering with diagnostics), and the WASM playground.
The token-driven parser *flip*, intra-declaration recovery, completion, go-to-definition,
find-references, rename (all cross-file, over the whole workspace index), signature help,
and the inline ownership / Auto-Drop overlay are **done** (above).

## Internals

`src/lsp.rs`. The core is a pure, async-free function:

```rust
pub fn analyze(path: &str, src: &str) -> Vec<Analyzed>
```

which runs `compile_front` (wrapped in `catch_unwind` for robustness) and maps each
`Diagnostic` to an LSP diagnostic plus an optional `FixEdit`. The async
`LanguageServer` impl is a thin shell over it; the unit tests in
`axionc/tests/lsp.rs` exercise `analyze` directly.

Byte offsets (the compiler's currency) and LSP positions are converted by `Positions`,
which wraps the source with its line table. LSP `character` fields count **UTF-16 code
units** (the default `positionEncoding`), so `Positions::position` measures each line's
prefix with `encode_utf16().count()` and `Positions::byte` walks the line by
`char::len_utf16` — a `café😀` before a token no longer shifts its reported column
(`tests/…positions_are_utf16_code_units`).
