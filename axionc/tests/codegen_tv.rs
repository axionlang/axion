//! M3 gate — codegen reclamation-preservation translation validation over the corpus.
//!
//! For every fixture that lowers to LLVM IR, `axionc --emit codegen-tv` independently computes the
//! reclamation the Core `Drop` sites require and the reclamation the emitted IR performs, and checks
//! they match 1:1. This test asserts there is NO discrepancy across the corpus — i.e. the trusted
//! Core→IR lowering never drops, duplicates, invents, or mis-keys a free. See
//! `axionc/src/codegen_tv.rs` (the checker + its teeth unit-tests) and `metatheory/GUARANTEE.md` §6.
#![allow(clippy::unwrap_used, clippy::expect_used)]

use std::process::Command;

#[test]
fn codegen_reclamation_matches_core_over_the_corpus() {
    let dir = format!("{}/tests/fixtures", env!("CARGO_MANIFEST_DIR"));
    let mut checked = 0usize;
    let mut validated_calls = 0usize;
    let mut failures = Vec::new();

    for entry in std::fs::read_dir(&dir).unwrap() {
        let path = entry.unwrap().path();
        if path.extension().and_then(|e| e.to_str()) != Some("axi") {
            continue;
        }
        let out = Command::new(env!("CARGO_BIN_EXE_axionc"))
            .args(["--emit", "codegen-tv"])
            .arg(&path)
            .output()
            .unwrap();
        // Fixtures that don't lower to IR (negative tests, unsupported-in-release) are skipped.
        if !out.status.success() && out.stdout.is_empty() {
            continue;
        }
        let s = String::from_utf8_lossy(&out.stdout);
        if s.trim().is_empty() {
            continue;
        }
        checked += 1;
        if let Some(n) = s
            .lines()
            .next()
            .and_then(|l| l.split_whitespace().nth(1))
            .and_then(|n| n.parse::<usize>().ok())
        {
            validated_calls += n;
        }
        if s.contains("MISMATCH") {
            let name = path.file_name().unwrap().to_string_lossy().to_string();
            let detail: Vec<&str> = s.lines().filter(|l| l.contains("MISMATCH")).collect();
            failures.push(format!("{name}:\n    {}", detail.join("\n    ")));
        }
    }

    assert!(
        failures.is_empty(),
        "codegen reclamation-preservation TV found discrepancies:\n{}",
        failures.join("\n")
    );
    // Sanity: the gate actually exercised the corpus (not silently vacuous).
    assert!(
        checked > 100 && validated_calls > 500,
        "expected the TV to validate the corpus; only {checked} fixtures / {validated_calls} calls"
    );
}
