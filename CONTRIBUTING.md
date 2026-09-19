# Contributing

## Land changes through a pull request — not a direct push to `main`

CI (`.github/workflows/ci.yml`) runs on **every pull request**, so a PR is checked
*before* it reaches `main`. Pushing straight to `main` skips that and has repeatedly
left `main` red for weeks at a time (toolchain-drift lints that only surface when the
`fmt`/`clippy` steps actually run). Always:

```sh
git checkout -b my-change          # branch off main
# …edit, commit…
git push -u origin my-change
gh pr create --fill                # open the PR — CI runs on it
# wait for all 5 jobs green (delta, axionc, prototype, differential, sanitize)
gh pr merge --merge                # or --squash; merge only once green
```

Do **not** `git push origin main` for feature work. Reserve direct pushes to `main`
for trivial, already-CI-green fast-forwards.

### Enforce it (repo admin, one-time)

The above is convention until GitHub **branch protection** makes it a rule. In
**Settings → Branches → Add rule** for `main`:

- **Require a pull request before merging.**
- **Require status checks to pass:** add `delta`, `axionc`, `prototype`,
  `differential`, `sanitize`.
- (optional) **Require branches to be up to date before merging.**

This can't be set from the CLI without an admin-scoped token, so a maintainer must
toggle it once in the web UI.

## Before you push — the local gate

Run these; a green local run is the best predictor of green CI (caveat below):

```sh
cd axionc
cargo build
cargo test
cargo clippy --all-targets -- -D warnings
cargo fmt --check
```

Plus the corpus/soundness gates (need `clang` / `nix` where noted):

```sh
AXION_CLANG=clang ./scripts/verify-gate.sh   # Δ drop-balance soundness over the corpus
AXION_CLANG=clang ./scripts/sanitize.sh      # ASan/LSan over native fixtures
AXION_CLANG=clang ./scripts/pass-asan.sh     # the pass(1) clone under ASan
AXION_CLANG=clang ./scripts/tsan.sh          # session scheduler concurrency
./scripts/dump-oracle.sh                     # --emit core snapshot (LC_ALL=C, locale-safe)
./metatheory/check.sh                        # Lean metatheory (no sorry; propext/Quot.sound only)
```

### Toolchain caveat (the reason CI is the authority)

CI pins `dtolnay/rust-toolchain@1.98.0`. If your local toolchain differs (the Nix dev
shell here is rustc 1.95 / rustfmt 1.9.0), **`cargo fmt` and `cargo clippy` can diverge
from CI** — 1.98 has lints and formatting rules older versions lack (e.g.
`clippy::drain_collect`), and a newer rustfmt wraps calls an older one leaves alone.
So:

- Do **not** mass-`cargo fmt` the whole tree under a mismatched local rustfmt — it can
  *introduce* diffs CI rejects. CI's rustfmt is the authority; format only what you
  touched and let the PR's `fmt` step confirm.
- A clean local `clippy` at an older version can still fail CI's 1.98 `clippy`. Treat
  the PR's checks as the source of truth, and iterate on the PR — never on `main`.
