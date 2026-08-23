//! The drop-balance verifier's validation gate (translation validation, §soundness).
//!
//! The verifier re-derives the linear-resource discipline over the FINAL drop-inserted
//! Core and reports any double-free / use-after-free / unbalanced drop. Its correctness is
//! cross-checked against ground truth: every committed fixture is ASan-clean (see
//! `scripts/sanitize.sh`), so the verifier MUST report zero corruption findings over the
//! whole corpus. `--emit verify` exits 0 iff there are no corruption findings.

use std::process::Command;

fn axionc() -> Command {
    Command::new(env!("CARGO_BIN_EXE_axionc"))
}

/// `--emit verify` over every fixture and example must report NO corruption (exit 0) —
/// the verifier agrees with the ASan corruption gate over the entire clean corpus.
#[test]
fn verifier_reports_no_corruption_over_all_fixtures() {
    let mut checked = 0;
    let mut failures = Vec::new();
    for base in ["tests/fixtures", "../examples"] {
        let dir = format!("{}/{base}", env!("CARGO_MANIFEST_DIR"));
        let Ok(entries) = std::fs::read_dir(&dir) else {
            continue;
        };
        for entry in entries {
            let path = entry.unwrap().path();
            if path.extension().and_then(|e| e.to_str()) != Some("axi") {
                continue;
            }
            // deliberately malformed — it doesn't lower to Core.
            if path.file_name().unwrap() == "recover_partial.axi" {
                continue;
            }
            // known-bad by design: a borrow of a LOCAL that escapes (a dangling reference)
            // that the verifier is SUPPOSED to flag — asserted separately below.
            if path.file_name().unwrap() == "escape_local_borrow.axi" {
                continue;
            }
            let out = axionc()
                .args(["--emit", "verify", path.to_str().unwrap()])
                .output()
                .unwrap();
            let stdout = String::from_utf8_lossy(&out.stdout);
            // Key on an actual corruption finding (`FAIL:`), NOT exit status: a rejection
            // fixture (type error, AX0001, undefined op) fails to compile and never reaches
            // the verify stage — it prints neither `ok:` nor `FAIL:`, so it is skipped.
            if stdout.contains("FAIL:") {
                let detail: Vec<&str> = stdout
                    .lines()
                    .filter(|l| {
                        l.contains("Free") || l.contains("Alias") || l.contains("Unbalanced")
                    })
                    .collect();
                failures.push(format!(
                    "{}: {}",
                    path.file_name().unwrap().to_string_lossy(),
                    detail.join("; ")
                ));
            }
            if stdout.contains("ok:") {
                checked += 1; // only count fixtures that actually lowered + verified
            }
        }
    }
    assert!(checked > 100, "expected many fixtures, verified {checked}");
    assert!(
        failures.is_empty(),
        "the drop-balance verifier flagged {} corruption(s) on ASan-clean fixtures \
         (false positives, or a real regression):\n{}",
        failures.len(),
        failures.join("\n")
    );
}

/// Regions/lifetimes: a borrow-returning function (`grab w = inner w`, an interior heap
/// alias of a param) is now compiled SOUNDLY — the caller does not free the borrow, the
/// argument's owner does. This was the last undefended double-free class; the fix makes it
/// legal instead of merely rejected. Assert the verifier reports NO corruption on it (it is
/// clean, not flagged). Its runtime correctness (output 2, ASan-clean on every backend) is
/// covered by the run oracle + sanitize.sh; this guards the verifier's view of the fix.
#[test]
fn borrow_returning_function_verifies_clean() {
    let path = format!(
        "{}/tests/fixtures/field_alias_return.axi",
        env!("CARGO_MANIFEST_DIR")
    );
    let verify = axionc().args(["--emit", "verify", &path]).output().unwrap();
    let vstdout = String::from_utf8_lossy(&verify.stdout);
    assert!(
        vstdout.contains("ok:") && !vstdout.contains("FAIL:"),
        "the borrow-returning `grab` should verify clean now that lowering makes it sound, got:\n{vstdout}"
    );
}

/// The dual of the above and the escape case regions must keep rejecting: a function
/// returning a BORROW OF A LOCAL (`mkGrab n = inner (W {...})`) dangles — the local is freed
/// at exit. The borrow-return inference is PRECISE (it nulls ownership only for aliases of a
/// PARAMETER, never a local), so the result stays owned and the verifier flags the escaping
/// use-after-free AND the gate refuses (AX0910). Guards against the fix over-nulling.
#[test]
fn verifier_flags_escaping_local_borrow() {
    let path = format!(
        "{}/tests/fixtures/escape_local_borrow.axi",
        env!("CARGO_MANIFEST_DIR")
    );

    let verify = axionc().args(["--emit", "verify", &path]).output().unwrap();
    let vstdout = String::from_utf8_lossy(&verify.stdout);
    assert!(
        vstdout.contains("FAIL:") && vstdout.contains("Free"),
        "verifier should flag the escaping borrow of a local as a use-after-free, got:\n{vstdout}"
    );

    let gate = axionc().args(["--release", &path]).output().unwrap();
    assert!(
        !gate.status.success(),
        "the default-on gate must refuse to compile the escaping-local-borrow to native code"
    );
    let combined = format!(
        "{}{}",
        String::from_utf8_lossy(&gate.stdout),
        String::from_utf8_lossy(&gate.stderr)
    );
    assert!(
        combined.contains("AX0910"),
        "the gate should abort with AX0910, got:\n{combined}"
    );
}
