# Contributing

This repository works on a single branch: **`main`**. Commit, run the checks below,
and `git push origin main`. That's it.

```sh
git add -A
git commit -m "message"
# run the pre-push checks (below)
git push origin main
```

## Before you push — the local gate

CI runs on every push to `main`, so run these first; a green local run is the best
predictor of green CI (one caveat below):

```sh
cd axionc
cargo build
cargo test
cargo clippy --all-targets -- -D warnings
cargo fmt --check
```

Plus the corpus / soundness gates (need `clang` / `nix` where noted):

```sh
AXION_CLANG=clang ./scripts/verify-gate.sh   # Δ drop-balance soundness over the corpus
AXION_CLANG=clang ./scripts/sanitize.sh      # ASan/LSan over native fixtures
AXION_CLANG=clang ./scripts/pass-asan.sh     # the pass(1) clone under ASan
AXION_CLANG=clang ./scripts/tsan.sh          # session scheduler concurrency
./scripts/dump-oracle.sh                     # --emit core snapshot (LC_ALL=C, locale-safe)
./metatheory/check.sh                        # Lean metatheory (no sorry; propext/Quot.sound only)
```

## Toolchain caveat (why CI can still fail after a clean local run)

CI pins `dtolnay/rust-toolchain@1.98.0`. If your local toolchain differs (the Nix dev
shell here is rustc 1.95 / rustfmt 1.9.0), **`cargo fmt` and `cargo clippy` can diverge
from CI** — 1.98 has lints and formatting rules older versions lack (e.g.
`clippy::drain_collect`), and a newer rustfmt wraps calls an older one leaves alone.
So do **not** mass-`cargo fmt` the whole tree under a mismatched local rustfmt (it can
*introduce* diffs CI rejects) — format only what you touched. If CI goes red on a
`fmt`/`clippy` step, read the CI log for the exact diff/lint and fix just that.
