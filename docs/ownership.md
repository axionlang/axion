# The ownership model

Axion is often summarised as "linear". That is true of **resources**, not of data. This page is
the precise version: what is freed for you, what you must consume yourself, what is checked, and
where the checks stop. Every behaviour below is pinned by a test in `axionc/tests/`.

## Three kinds of value

| Kind | Examples | Rule | Who frees it |
|---|---|---|---|
| **Data** | `Int`, `String`, `List a`, tuples, records, `data` types, `Integer`, `Array`, `Buffer` | use freely; *moving* it into an owned position (a constructor, a `%1` argument) happens at most once | the compiler (Auto-Drop), at the last use, on every path |
| **Resources** | `Handle a`, `Sock`, `Listener`, session endpoints `Ep s` | consumed **exactly once on every path** from where it is bound | you, by calling the function that consumes it (`closeD h`, `netClose s`, `close ep`) |
| **`%1` parameters** | `f :: Box %1 -> …` | the callee takes ownership; the caller may not use the argument afterwards | the callee |

So data behaves like Rust: affine, with automatic deterministic cleanup. Resources are linear:
forgetting one is a compile error, not a silent drop. A record or `data` value holding a resource
is itself a resource.

### Data

```haskell
lenK :: (String, Int) -> Int
lenK t = case t of
  (a, b) -> strLen a + b

both :: (String, Int) -> Int
both t = lenK t + lenK t        -- fine: `lenK` only reads its tuple, so it borrows it
```

Parameters are borrowed unless the function needs to own them. The compiler infers that: a
function that returns or embeds part of its argument (`fstS (a, _) = a`) takes ownership; one that
only reads it (`lenK`) borrows it, so the caller keeps it. Passing the same value into two owned
positions (`Pair xs xs`) is **AX0001**, since both owners would free it.

### Resources

```haskell
data Dev = Dev
foreign "libdev.so" openD  = "dev_open"  :: Int -> Handle Dev
foreign "libdev.so" readD  = "dev_read"  :: Borrow (Handle Dev) -> Int
foreign "libdev.so" closeD = "dev_close" :: Own (Handle Dev) -> Int
```

`Own` consumes the handle, `Borrow` reads it. Bound by `let`, by `x <- …` in a `do` block, or as a
`%1` parameter, a resource is checked from that point. A parameter *without* `%1` is a borrow:
the function may read it but not consume it, because its caller still will.

| Mistake | Error |
|---|---|
| never consumed | **AX0002** `must-use resource 'h' dropped without being consumed` |
| consumed on one branch, not the other | **AX0002** `… is not consumed on every path` |
| consumed twice | **AX0001** `linear resource 'h' consumed 2 times` |
| used after it was consumed | **AX0004** `use of 'h' after ownership was moved` |
| discarded (`_ <- netAccept l`, or a bare statement) | **AX0002** |
| consumed through a parameter without `%1` (the caller still owns it) | **AX0007** `borrowed resource 'h' is consumed in 'f'` |

`handleAddr h` reads a handle's address without consuming it, for NULL checks.

## Typestate for free

The phantom parameter of `Handle` can name a protocol state. Each step consumes the handle in one
state and returns it in the next, so calling a step in the wrong state is a type error, and the
exactly-once rule means the protocol cannot be abandoned half way (`tests/fixtures/typestate_handle.axi`):

```haskell
data Disconnected = Disconnected
data Connected = Connected
data Ready = Ready

foreign "libnet.so" openS    = "s_open"    :: Int -> Handle Disconnected
foreign "libnet.so" connectS = "s_connect" :: Own (Handle Disconnected) -> Handle Connected
foreign "libnet.so" authS    = "s_auth"    :: Own (Handle Connected) -> Handle Ready
foreign "libnet.so" sendS    = "s_send"    :: Borrow (Handle Ready) -> Int
foreign "libnet.so" closeS   = "s_close"   :: Own (Handle Ready) -> Int

session :: Int -> Int
session n = let s = authS (connectS (openS n)) in sendS s + sendS s + closeS s
```

| Mistake | Error |
|---|---|
| `sendS` on a handle that is only `Connected` | **AX0200** `type mismatch: Ready vs Connected` |
| no `closeS` | **AX0002** |
| reusing the `Disconnected` handle after `connectS` | **AX0001** |
| `sendS` after `closeS` | **AX0004** |

This is Rust's typestate pattern without the marker-trait plumbing, and unlike Rust an abandoned
session does not compile. For channels between workers, session types do the same with the
protocol written as a type (`Ep s` advances with every `send`/`recv`; see
[`async-sockets.md`](async-sockets.md) and [`phase-3-calculus.md`](phase-3-calculus.md)).

## Error paths

Data on an early-return path is freed automatically, including when a `<-!` (Either) or `<-?`
(Maybe) bind short-circuits:

```haskell
work :: Int -> Either String Int
work n = do
  let s = show n
  x <-! check (strLen s - 2)     -- on `Left`, `s` is freed for you
  Right (x + strLen s)
```

A **resource** is different: it must be consumed on the error path too, and a `<-!` that
short-circuits while one is open leaks it (**AX0002**). Write the `case` out and consume it in
each arm:

```haskell
work :: Int -> Either String Int
work n = let h = openD n in case check (readD h) of
  Left e  -> case closeD h of
    _ -> Left e
  Right x -> Right (x + closeD h)
```

This is the cost of "a resource cannot be silently dropped". Rust's `?` cleans up handles on the
error path because its handles *can* be silently dropped.

The way around it is a **bracket**: one function opens the resource, lends it to your code, and
consumes it whatever your code returns (`tests/fixtures/bracket_handle.axi`):

```haskell
withDev :: Int -> (Handle Dev -> Either String Int) -> Either String Int
withDev n body = let h = openD n in let r = body h in case closeD h of
  _ -> r

work :: Int -> Either String Int
work n = withDev n (\h -> do
  x <-! check (readD h)          -- early returns are fine: withDev closes h
  y <-! check (readD h - 1)
  Right (x + y))
```

The close is written once and runs on every outcome, and the body uses `<-!` freely. Both halves
stay checked: the body is only lent the handle (its type has no `%1`), so closing it there is
**AX0007**, and `withDev` forgetting the close is **AX0002**.

## Effects

Axion has no `IO` type: effects are ordinary values (`putStrLn s :: IO ()`, `runStatus cmd :: Int`).
The compiler knows which calls have effects (the effectful built-ins, every `foreign` import not
declared `foreign pure`, and any function that calls one) and never drops, merges or reorders
them. A `do` block and a `let` in a body are evaluated strictly and in order; a `where` binding is
evaluated on demand, so an effectful `where` binding that is never used would never run, and the
compiler warns (**AX0920**). This is effect tracking by the compiler, not by the type system.

## Where the checks stop

- **FFI.** C code is trusted. `Own`/`Borrow` annotations, buffer sizes and the C function itself
  are your responsibility. `axionc --emit ffi file.axi` lists every import and call site.
  See [`ffi-trust-boundary.md`](ffi-trust-boundary.md).
- **Escape hatches.** `--no-verify` skips the drop-balance verifier; `--allow-leaks` keeps it but
  tolerates leaks. `--certified` refuses both.
- **Known conservative rejections** are listed in [`backend.md`](backend.md) (for example `filter`
  with a predicate that is a runtime closure parameter, AX0912).

## What is proven

Independently of the checks above, every native build passes the **drop-balance verifier**
(`axionc/src/verify.rs`, AX0910 corruption / AX0911 leak): it re-checks the final lowered program
and refuses to emit code that could double-free, use after free, or leak. The verifier's judgment
is mechanized in Lean (`metatheory/`): accepted programs cannot fault or leak on any path, with
separate machine-checked slices for interior aliases, drop keys, moves, extraction and moved-in
heap. See [`metatheory/GUARANTEE.md`](../metatheory/GUARANTEE.md) for exactly what is claimed.

## Compared with Rust

| | Rust | Axion |
|---|---|---|
| Ordinary data | affine, `Drop` at scope end | affine, freed at last use (Auto-Drop) |
| Resources (files, sockets, sessions) | affine: may be silently dropped | linear: must be consumed on every path |
| Typestate | marker types + `PhantomData` + `impl` per state | phantom parameter on `Handle`, no extra code |
| Protocols between threads | library encodings | session types in the language |
| Early-return cleanup of resources | automatic (`?` + `Drop`) | a bracket function, or explicit in each arm |
| Mutation | `&mut T` | in-place when the old value is dead (records, arrays, buffers) |
| Unsafe code | `unsafe` blocks | the FFI boundary |
| Memory-safety argument | type system (RustBelt for the core) | type checks + a verifier over the final program, mechanized in Lean |
