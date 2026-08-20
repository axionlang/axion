# tree-sitter-axion

A [tree-sitter](https://tree-sitter.github.io) grammar for the **Axión** language,
for editor syntax highlighting (Helix, Neovim, Zed, …). Helix highlights with
tree-sitter, not the LSP, so this — not `axion-lsp` — is what colours Axión code.

**Scope: highlighting-grade.** It has *no* external C scanner for Haskell-style layout
(indentation → blocks), so the *lexical* layer is exact — keywords, type vs data
constructors (upper/lowercase is lexical), variables, functions, strings, numbers,
comments, and the `%1`/`%0.5` linearity mark all colour correctly — while deeply nested
`where`/`let`/`do`/`case` blocks parse approximately (a few boundary `ERROR` nodes). That
does **not** affect colouring: token captures fire inside `ERROR` nodes too. A fully
structural parse (for tree-sitter text-objects / auto-indent) would need the scanner and
is out of scope.

## Layout

- `grammar.js` — the grammar (mirrors `../docs/grammar.md` and `../axionc/src/lexer.rs`).
- `queries/highlights.scm` — the highlight captures.
- `src/` — the generated parser (`parser.c` + json), **committed** so `hx --grammar build`
  and other consumers work without running `tree-sitter generate`.
- `test/corpus/` — grammar tests (`tree-sitter test`).

## Rebuild (only if you edit `grammar.js`)

Needs the `tree-sitter` CLI, `node`, and a C compiler. On NixOS:
`nix build nixpkgs#tree-sitter nixpkgs#nodejs`.

```sh
tree-sitter generate      # regenerates src/
tree-sitter test          # runs test/corpus
tree-sitter parse FILE.axi
```

## Use in Helix

Add to `~/.config/helix/languages.toml`:

```toml
[[grammar]]
name = "axion"
source = { path = "/home/sorath/Axion/tree-sitter-axion" }
```

The existing `[[language]] name = "axion"` block picks up the grammar by name. Install the
compiled parser and the queries into Helix's runtime:

```sh
# 1. the compiled grammar → runtime/grammars/axion.so
mkdir -p ~/.config/helix/runtime/grammars
clang -O2 -shared -fPIC \
  -I /home/sorath/Axion/tree-sitter-axion/src \
  /home/sorath/Axion/tree-sitter-axion/src/parser.c \
  -o ~/.config/helix/runtime/grammars/axion.so

# 2. the highlight queries → runtime/queries/axion/
mkdir -p ~/.config/helix/runtime/queries/axion
ln -sf /home/sorath/Axion/tree-sitter-axion/queries/highlights.scm \
       ~/.config/helix/runtime/queries/axion/highlights.scm
```

Compiling `axion.so` directly (the grammar has no external scanner, so it's just
`parser.c`) is the recommended path. `hx --grammar build` also works **once
`runtime/grammars/` exists** — but it rebuilds Helix's entire declared grammar set, so it
prints failures for every other grammar whose source you haven't `hx --grammar fetch`ed;
those are unrelated to Axión.

Check with `hx --health axion` — "Tree-sitter parser" and "Highlight queries" should both
be ✓. (Textobject/Indent stay ✘ — highlighting-grade has no layout scanner.) Open an
`.axi` file and it's coloured.
