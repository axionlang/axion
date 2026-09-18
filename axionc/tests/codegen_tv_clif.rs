//! M3 gate (Cranelift `--dev` backend) — codegen reclamation-preservation translation validation.
//!
//! The sibling of `codegen_tv.rs`, for the OTHER native backend. For every fixture that lowers,
//! `axionc --emit codegen-tv-clif` independently computes the reclamation the Core `Drop` sites
//! require and the reclamation the emitted Cranelift CLIF performs, and checks they match 1:1 — so
//! the trusted Core→CLIF lowering never drops, duplicates, invents, or mis-keys a free. Now that
//! both native backends link the SAME runtime (`axion-rt`), this closes the last "Cranelift
//! reclamation not yet TV'd" trusted item. See `axionc/src/codegen_tv.rs` and
//! `metatheory/GUARANTEE.md` §6.
#![allow(clippy::unwrap_used, clippy::expect_used)]

use std::process::Command;

#[test]
fn cranelift_codegen_reclamation_matches_core_over_the_corpus() {
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
            .args(["--emit", "codegen-tv-clif"])
            .arg(&path)
            .output()
            .unwrap();
        // Fixtures that don't lower to CLIF (negative tests, unsupported-in-native) are skipped.
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
        "Cranelift codegen reclamation-preservation TV found discrepancies:\n{}",
        failures.join("\n")
    );
    // Sanity: the gate actually exercised the corpus (not silently vacuous).
    assert!(
        checked > 100 && validated_calls > 500,
        "expected the TV to validate the corpus; only {checked} fixtures / {validated_calls} calls"
    );
}
