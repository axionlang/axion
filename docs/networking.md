# Networking (§FFI) — TCP sockets via foreign imports

Axion provides a set of FFI functions for TCP networking, declared in the prelude:

```haskell
foreign ax_net_connect :: String -> Int -> Int
foreign ax_net_listen  :: Int -> Int
foreign ax_net_accept  :: Int -> Int
foreign ax_net_send    :: Int -> String -> Int
foreign ax_net_recv    :: Int -> String
foreign ax_net_close   :: Int -> Int
```

These call C functions in `axion_rt.c` (the same runtime used by `--release`) and
have Rust reimplementations for the `--dev` (Cranelift JIT) backend. The
interpreter falls back to raw POSIX socket calls via `libc` when the C symbols
are not in the process.

## Backend support

| Backend          | Status                                             |
|------------------|----------------------------------------------------|
| `--release`      | Full — compiled with `axion_rt.c` via `clang -flto` |
| `--backend cranelift` | Full — Rust reimplementations in `codegen.rs`  |
| Interpreter      | Full — POSIX fallback in `net_call_foreign`         |

## TCP client

```haskell
-- examples/echo.axi — single-shot TCP client
main :: IO ()
main =
  case ax_net_connect "example.com" 80 of
    sock ->
      case ax_net_send sock "GET / HTTP/1.0\nHost: example.com\n\n" of
        _ ->
          case ax_net_recv sock of
            resp ->
              case ax_net_close sock of
                _ -> putStrLn resp
```

> **Important:** Axion's `let` bindings are **lazy**. FFI calls have side effects
> (connecting, sending, receiving) that must be **forced** via `case` chains.
> `let _ = ax_net_send sock msg in rest` never sends because `_` is never used.
> Always use `case e of x -> ...` or `case e of _ -> ...` to force FFI calls.

## TCP echo server

```haskell
-- examples/echo_server.axi — infinite-loop echo server
echoLoop :: Int -> IO ()
echoLoop sock =
  case ax_net_accept sock of
    client ->
      case ax_net_recv client of
        msg ->
          case ax_net_send client msg of
            _ ->
              case ax_net_close client of
                _ -> echoLoop sock

main :: IO ()
main =
  case ax_net_listen 8080 of
    sock ->
      case putStrLn "listening on :8080" of
        _ -> echoLoop sock
```

The recursive `echoLoop` is tail-recursive — TCO compiles it to a native loop.
The server blocks on `accept` and `recv` (blocking the calling thread; there is
no M:N scheduler integration for sockets yet). It handles one connection at a
time, echoing each message back and closing before accepting the next.

## String escapes

Axion strings support `\n`, `\r`, `\t`, `\\`, and `\"`. For HTTP, use
`\r\n` line endings:

```haskell
ax_net_send sock "GET / HTTP/1.1\r\nHost: example.com\r\n\r\n"
```

## Runtime implementation

The C implementations live in `axion_rt.c` (linked with `--release` via
`clang -O2 -flto`). The Rust implementations live in `codegen.rs` (registered
with the Cranelift JIT). The interpreter's fallback lives in `interp.rs:net_call_foreign`
and uses raw `extern "C"` declarations for POSIX socket functions.

| C function            | Axion type            | Purpose                       |
|-----------------------|-----------------------|-------------------------------|
| `ax_net_connect`      | `String -> Int -> Int` | Resolve hostname + connect TCP |
| `ax_net_listen`       | `Int -> Int`          | Bind + listen on port          |
| `ax_net_accept`       | `Int -> Int`          | Accept connection (blocks)     |
| `ax_net_send`         | `Int -> String -> Int` | Send string data               |
| `ax_net_recv`         | `Int -> String`       | Receive string data (blocks)   |
| `ax_net_close`        | `Int -> Int`          | Close socket                   |

## ⚠️ Safety boundary

`foreign` declarations call C functions directly via `dlsym`. These functions are
**outside Axion's safety guarantees** — the C code can corrupt memory, double-free,
or return garbage. Every `foreign` import is the Axion equivalent of Rust's
`unsafe { }` block.

The prelude's networking functions (`ax_net_*`) and runtime functions
(`axion_array_*`, `axion_buf_*`) are **trusted wrappers**: they are audited and
covered by the `sanitize.sh` gate (AddressSanitizer + LeakSanitizer).

When declaring your own `foreign` imports:
1. Audit the C code — assume it can corrupt anything.
2. Keep FFI wrappers small and well-tested.
3. Run `scripts/sanitize.sh` against any program using custom FFI.

## Limitations

- **Blocking only.** `accept` and `recv` block the calling thread. There is no
  integration with the M:N session scheduler (no `epoll`/`io_uring` yet). For
  coarse compute workloads this is fine; for many small messages, session
  integration is needed.
- **`String` type for data.** No `Buffer` or byte-array type for binary data.
  `ax_net_recv` returns a null-terminated `String` allocated by `axion_alloc`.
- **Single-connection at a time.** The echo server loops sequentially — one
  connection at a time. Concurrent connections need session types or OS threads.
