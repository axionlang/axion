//! `axion-lsp` — the Language Server binary (§8). A thin async shell over
//! [`axionc::lsp::run`]; built only under `--features lsp`.

#[tokio::main]
async fn main() {
    axionc::lsp::run().await;
}
