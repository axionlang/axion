# `pass` in Axión

A rewrite of the Linux [`pass`](https://www.passwordstore.org/) (password-store) CLI
in Axión, at `examples/pass/pass.axi`. It exercises the OS capability layer (§pass) —
subprocess, environment, filesystem, argv — that makes Axión able to write a real CLI
while keeping its memory-safety-by-construction guarantees.

## Design

Like upstream `pass`, this invokes `gpg` for crypto, so **ciphertext never enters
Axión** — only decrypted plaintext crosses the boundary. Store layout is the standard
one: GPG-encrypted `*.gpg` files under `$PASSWORD_STORE_DIR` (default
`$HOME/.password-store`).

The secret-touching commands (`show`, `insert`) run `gpg` **shell-free** through the
`execCapture` / `execStatus` primitives: an explicit argv (elements `\n`-joined, handed
straight to `execvp`) with the child's stdin available for input. Nothing is quoted or
word-split, so entry names are injection-proof, and `insert` streams the passphrase to
`gpg` over stdin rather than a tmpfile or command line. The listing commands
(`ls`/`find`/`grep`) remain genuine shell pipelines (`find | sed | sort | grep`).

Command dispatch is a string-literal `case` (`case cmd of "show" -> …; other -> …`).
`mv`/`cp` build the destination's parent directory with the prelude `dirName` + `makeDir`
(no shell `$(dirname …)`), and `generate`'s length is parsed by the prelude `readInt`
(defaulted to 25) rather than coerced in the shell.

Argv is read with the indexed `getArg` (a fresh copy per index), not by splitting into
a `List String` — the latter would trip a native heap-element aliasing issue.

## Status

**Phase B — read paths (done):**

| Command | Behavior |
|---|---|
| `pass` / `pass ls` | list entry names (relative paths, `.gpg` stripped), sorted |
| `pass show <name>` | decrypt `<name>.gpg` and print it |
| `pass <name>` | bare-name shorthand for `show` |
| `pass find <term>` (alias `search`) | list entries whose path matches `<term>` (case-insensitive) |
| `pass grep <search>` | decrypt every entry, print those whose content matches, with the matching lines |

**Phase C — write paths (done):**

| Command | Behavior |
|---|---|
| `pass rm <name>` (alias `remove`/`delete`) | delete an entry |
| `pass mv <old> <new>` (alias `rename`) | rename an entry, creating the new parent dir |
| `pass cp <old> <new>` (alias `copy`) | copy an entry |
| `pass generate <name> [length]` | generate a random `A-Za-z0-9` password (default 25), encrypt it, and print it |
| `pass insert <name>` (alias `add`) | read a passphrase twice with **terminal echo off**, then encrypt it |

Every mutation **auto-commits** the store when it is a git repo (silent and
non-fatal otherwise), mirroring upstream `pass`.

`insert` reads the passphrase with the `readSecret` primitive (terminal echo
disabled via `termios` on the C backend, `stty` on the Rust backends; both degrade
to a plain read on a pipe, so it stays testable). Because the secret originates from
the user rather than the shell, it reaches `gpg` through a **mode-0600 tmpfile that
is unlinked immediately after** — never on a command line.

Verified across all three backends (interp / Cranelift / LLVM) by
`scripts/pass-test.sh`, which stands up a throwaway GnuPG keyring + store (never
touching your real `~/.gnupg` / `~/.password-store`). Read paths are checked for
output + backend agreement via `axi-check.sh`; the mutating write paths are checked
per backend against a freshly-seeded store by asserting the on-disk effect (files
created/removed, decrypted contents).

**Not yet implemented:** `edit`, `git` passthrough, clipboard. `edit` needs a
decrypt → `$EDITOR` → re-encrypt round-trip over a shredded 0600 tmpfile.

## Try it

```sh
export PASSWORD_STORE_DIR=~/.password-store   # or wherever your store is
axionc run --backend llvm examples/pass/pass.axi -- ls
axionc run --backend llvm examples/pass/pass.axi -- show github/work
```

Or build a standalone `axpass` executable (`-o` implies `--release`) and run it directly:

```sh
axionc -o axpass examples/pass/pass.axi
./axpass show github/work            # prompts for your gpg passphrase via pinentry
```

If pinentry can't find your terminal, set `export GPG_TTY=$(tty)` in your shell profile
(a standard gpg requirement).

Or run the self-contained behavioral test:

```sh
./scripts/pass-test.sh
```

### Testing effectful programs

`scripts/axi-check.sh` is the reusable pattern for testing any Axión program: it runs the
file on every available backend (interp / Cranelift / LLVM), asserts they all produce
**identical** output (the `runtime_backends_agree` invariant), and optionally checks the
output. Program args pass through after `--`, and the caller's environment is inherited — so
an effectful program runs against whatever throwaway setup the caller arranges:

```sh
scripts/axi-check.sh --expect "95" axionc/tests/fixtures/string_compare.axi
HELLO_HOME=/h scripts/axi-check.sh --expect $'cmd=greet\n…' examples/pass/pass.axi -- greet x
```

`pass-test.sh` builds a throwaway GnuPG keyring + store, then drives each `pass` command
through `axi-check.sh`.

## Security notes

- Secrets are never placed on a command line or in the environment (visible in
  `ps`/`/proc`). `insert` streams the passphrase to `gpg` over stdin via the shell-free
  `execStatus` primitive — no argv, no environment, no tmpfile.
- `show`/`insert` are **shell-free** (`execvp` with an explicit argv), so an entry name
  containing shell metacharacters (`$(…)`, quotes, spaces) is treated as a literal
  filename — there is no command-injection surface (`pass-test.sh` proves this with a
  `$(touch …)` name that must not execute).
- `generate` draws its password from `/dev/urandom` and feeds it to `gpg` over
  **stdin via the shell `printf` builtin** (not a separate process), so the new
  secret never appears on any argv; only the final printed copy crosses into Axión,
  reclaimed once like any other decrypted secret.
- The listing commands (`ls`/`find`/`grep`) still single-quote paths for the shell
  pipeline; moving those to the shell-free primitive (or a pure Axión store walk) is a
  future hardening step. The secret-touching paths (`show`/`insert`) are already
  shell-free. An argv element handed to `execvp` may not contain a newline (the argv
  delimiter) — not a limitation for entry names or gpg flags.
- The decrypted secret is a linear `String` reclaimed exactly once (drop-verifier +
  leak gate stay green), so it is not left lingering in freed memory.
- Errors and prompts go to **stderr** (`die` / `ePutStr`), leaving stdout for real
  output; a failed command (`show` of a missing entry, a usage error, a passphrase
  mismatch) exits **non-zero** via `die`, so scripts can tell success from failure.
