# `pass` in Axión

A rewrite of the Linux [`pass`](https://www.passwordstore.org/) (password-store) CLI
in Axión, at `examples/pass/pass.axi`. It exercises the OS capability layer (§pass) —
subprocess, environment, filesystem, argv — that makes Axión able to write a real CLI
while keeping its memory-safety-by-construction guarantees.

## Design

Like upstream `pass`, this shells out to `gpg` for crypto (via `runCapture`), so
**ciphertext never enters Axión** — only decrypted plaintext, which gpg writes to
stdout, crosses the boundary. Store layout is the standard one: GPG-encrypted `*.gpg`
files under `$PASSWORD_STORE_DIR` (default `$HOME/.password-store`).

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

Verified across all three backends (interp / Cranelift / LLVM) by
`scripts/pass-test.sh`, which stands up a throwaway GnuPG keyring + store (never
touching your real `~/.gnupg` / `~/.password-store`) and checks the output.

**Not yet implemented:** `insert`, `generate`, `edit`, `rm`, `mv`, `cp`, `git`,
clipboard. `insert`/`generate`/`edit` need the stdin/tty primitives
(`readLine`/`readSecret`) still to be added.

## Try it

```sh
export PASSWORD_STORE_DIR=~/.password-store   # or wherever your store is
axionc run --backend llvm examples/pass/pass.axi -- ls
axionc run --backend llvm examples/pass/pass.axi -- show github/work
```

Or run the self-contained behavioral test:

```sh
./scripts/pass-test.sh
```

## Security notes

- Secrets are never placed on a command line or in the environment (visible in
  `ps`/`/proc`); `gpg` writes plaintext to a pipe that `runCapture` reads.
- Entry-name paths are single-quoted for the shell. A shell-free exec primitive (so a
  name containing a literal `'` is safe, and to remove all injection surface) is
  planned for the hardening pass.
- The decrypted secret is a linear `String` reclaimed exactly once (drop-verifier +
  leak gate stay green), so it is not left lingering in freed memory.
