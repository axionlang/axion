# Axión browser playground

A single-page playground that compiles and runs Axión programs **entirely in the
browser** — the compiler front-end (lex → layout → parse → linearity/Auto-Drop →
inference) and the interpreter backend, built to WebAssembly. No server, no native
toolchain at runtime.

The native code-generation backends (Cranelift `--dev`, LLVM `--release`) and the FFI
runtime can't target `wasm32`, so the `wasm` build drops them (`--no-default-features`)
and runs programs through the interpreter. `foreign` calls report an error in the browser.

## Build

Prerequisites: the `wasm32-unknown-unknown` target, a wasm linker (`lld` — rustc looks
for `lld` on `PATH` here), and the [`wasm-bindgen`](https://github.com/rustwasm/wasm-bindgen)
CLI. The `wasm-bindgen` crate is pinned in `Cargo.toml` to match the CLI version (they must
agree). On NixOS, `lld` is `nix build nixpkgs#lld`.

```sh
# from the repo root — put lld on PATH (NixOS example)
export PATH="$(nix build --no-link --print-out-paths nixpkgs#lld)/bin:$PATH"

cargo build --manifest-path axionc/Cargo.toml \
    --target wasm32-unknown-unknown --no-default-features --features wasm --release

wasm-bindgen axionc/target/wasm32-unknown-unknown/release/axionc.wasm \
    --target web --out-dir web/pkg
```

That writes `web/pkg/axionc.js` + `axionc_bg.wasm` (git-ignored), which `web/index.html`
imports. The lib is a `cdylib` (see `[lib] crate-type` in `Cargo.toml`) so the build emits
a `.wasm`.

## Run

Serve `web/` over HTTP (ES-module + wasm need a real origin, not `file://`):

```sh
python3 -m http.server -d web 8080   # then open http://localhost:8080
```

## The entry point

`axionc/src/wasm.rs` exposes one function:

```rust
compile_and_run(src: &str) -> String   // JSON
```

returning `{ "output": string, "diagnostics": [{code,severity,message,line,col}],
"error": string|null }` — the program's captured stdout (via `interp::run_capture`, which
reifies the whole run's IO into a string), the compiler's `AXnnnn` findings, and any
runtime error. The page in `index.html` renders it.
