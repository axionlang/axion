//! `axionc` — the Axion compiler binary.
//!
//! The whole compiler lives in the `axionc` library crate so that both this CLI
//! and the `axion-lsp` server (`--features lsp`) can share it. This binary is a
//! thin shell over [`axionc::run_cli`].

fn main() -> std::process::ExitCode {
    axionc::run_cli()
}
