# Axión browser playground

A single-page playground that compiles and runs Axión programs **entirely in the
browser** — the compiler front-end (lex → layout → parse → linearity/Auto-Drop →
inference) and the interpreter backend, built to WebAssembly. No server, no native
toolchain at runtime.

The native code-generation backends (Cranelift `--dev`, LLVM `--release`) and the FFI
runtime can't target `wasm32`, so the `wasm` build drops them (`--no-default-features`)
and runs programs through the interpreter. `foreign` calls report an error in the browser.

## Build

Prerequisites: the `wasm32-unknown-unknown` target, a wasm linker (`lld` / `rust-lld`),
and [`wasm-bindgen`](https://github.com/rustwasm/wasm-bindgen) CLI.

```sh
# from the repo root
cargo build --manifest-path axionc/Cargo.toml \
    --target wasm32-unknown-unknown --no-default-features --features wasm --release

wasm-bindgen axionc/target/wasm32-unknown-unknown/release/axionc.wasm \
    --target web --out-dir web/pkg
```

That writes `web/pkg/axionc.js` + `axionc_bg.wasm`, which `web/index.html` imports.

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
