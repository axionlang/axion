//! Fuzz gate: a small DETERMINISTIC differential-fuzzer run wired into `cargo test`, so
//! every change is checked against random well-typed programs (interp-vs-native output +
//! ASan corruption when clang is present). It is a regression guard, not the exhaustive
//! sweep — the big campaign is `scripts/fuzz.py --count <large>`. Fixed seed = reproducible.
//!
//! Degrades gracefully: skips if python3 is unavailable; the fuzzer itself skips the ASan
//! leg when clang is absent (the interp-vs-cranelift differential still runs). Opt out of
//! the whole thing with AXION_SKIP_FUZZ=1 (e.g. a sandbox with no subprocess budget).
#![allow(clippy::unwrap_used, clippy::expect_used)]

use std::process::Command;

fn have(bin: &str) -> bool {
    Command::new(bin)
        .arg("--version")
        .output()
        .map(|o| o.status.success())
        .unwrap_or(false)
}

#[test]
fn differential_fuzz_gate() {
    if std::env::var_os("AXION_SKIP_FUZZ").is_some() {
        eprintln!("fuzz gate: skipped (AXION_SKIP_FUZZ set)");
        return;
    }
    let py = ["python3", "python"].into_iter().find(|p| have(p));
    let Some(py) = py else {
        eprintln!("fuzz gate: skipped (no python3)");
        return;
    };
    // scripts/fuzz.py lives at the repo root (one level above the crate manifest dir).
    let script = format!("{}/../scripts/fuzz.py", env!("CARGO_MANIFEST_DIR"));
    let axionc = env!("CARGO_BIN_EXE_axionc");
    let out = Command::new(py)
        .args([
            &script,
            "--count",
            "40",
            "--seed",
            "20240827",
            "--keep-going",
        ])
        .env("AXIONC", axionc)
        .env(
            "AXION_CLANG",
            std::env::var("AXION_CLANG").unwrap_or_else(|_| "clang".into()),
        )
        .output()
        .expect("run fuzz.py");
    let stdout = String::from_utf8_lossy(&out.stdout);
    let stderr = String::from_utf8_lossy(&out.stderr);
    assert!(
        out.status.success(),
        "fuzz gate found a hard result (corruption / divergence / verdict-mismatch) — \
         reproduce with the printed seed via `AXION_CLANG=clang ./scripts/fuzz.py \
         --count 40 --seed 20240827`:\n{stdout}\n{stderr}"
    );
    // sanity: the run actually exercised programs (not an empty/no-op pass).
    assert!(
        stdout.contains("summary"),
        "fuzz gate produced no summary:\n{stdout}\n{stderr}"
    );
}
