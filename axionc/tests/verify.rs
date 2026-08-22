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
            // known-bad by design: an interprocedural field-alias return (`grab w = inner w`)
            // that the verifier is SUPPOSED to flag — asserted separately below.
            if path.file_name().unwrap() == "field_alias_return.axi" {
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

/// The interprocedural class the summaries exist for: `grab w = inner w` returns a heap
/// alias of a borrowed param, which the caller then frees (double free at runtime). The
/// per-function analysis can't see it — the call SUMMARIES must. Assert the verifier flags
/// it (`--emit verify` reports a corruption finding) AND the default-on gate refuses to
/// compile it to native code (`--release` exits non-zero with AX0910). Without this test the
/// summaries could silently regress and the last undefended UAF would reopen.
#[test]
fn verifier_flags_interprocedural_field_alias_return() {
    let path = format!(
        "{}/tests/fixtures/field_alias_return.axi",
        env!("CARGO_MANIFEST_DIR")
    );

    let verify = axionc()
        .args(["--emit", "verify", &path])
        .output()
        .unwrap();
    let vstdout = String::from_utf8_lossy(&verify.stdout);
    assert!(
        vstdout.contains("FAIL:") && vstdout.contains("Alias"),
        "verifier should flag the interprocedural field-alias return as a DropOfAlias, got:\n{vstdout}"
    );

    let gate = axionc().args(["--release", &path]).output().unwrap();
    assert!(
        !gate.status.success(),
        "the default-on gate must refuse to compile the field-alias return to native code"
    );
    let gstderr = String::from_utf8_lossy(&gate.stderr);
    let gstdout = String::from_utf8_lossy(&gate.stdout);
    assert!(
        gstderr.contains("AX0910") || gstdout.contains("AX0910"),
        "the gate should abort with AX0910, got stderr:\n{gstderr}\nstdout:\n{gstdout}"
    );
}
