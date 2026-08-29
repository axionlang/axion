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
    let mut leak_fps = Vec::new();
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
            // LEAK precision: every leak the verifier reports over the (LSan-clean) corpus
            // must be WHITELISTED (a synthetic session/parmap `*$step` worker — the
            // documented conservative class). A leak in ordinary code would be a gate-worthy
            // false positive (the leak analysis is precise, cross-checked by scripts/
            // sanitize.sh). `Leak: `var` in `func` @span`.
            for l in stdout.lines().filter(|l| l.trim_start().starts_with("Leak:")) {
                let func = l.split(" in `").nth(1).and_then(|s| s.split('`').next()).unwrap_or("");
                if !func.ends_with("$step") {
                    leak_fps.push(format!("{}: {}", path.file_name().unwrap().to_string_lossy(), l.trim()));
                }
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
    assert!(
        leak_fps.is_empty(),
        "the drop-balance verifier reported {} GATE-WORTHY leak(s) on the corpus (leak \
         false-positives, or a real Auto-Drop regression — cross-check scripts/sanitize.sh):\n{}",
        leak_fps.len(),
        leak_fps.join("\n")
    );
}

/// The leak gate whitelists compiler-synthesized session/parmap workers: `session_parmap_
/// integer` genuinely leaks (LSan-confirmed, 296 bytes) but entirely inside its `worker$step`
/// state machine (hand-rolled memory, the documented conservative class). The leak gate must
/// run, detect it, and WHITELIST it — so `--release` still compiles. If the `$step` whitelist
/// regresses, this fixture would start failing AX0911; guards that boundary.
#[test]
fn leak_gate_whitelists_synthetic_worker() {
    let path = format!(
        "{}/tests/fixtures/session_parmap_integer.axi",
        env!("CARGO_MANIFEST_DIR")
    );
    let out = axionc().args(["--release", &path]).output().unwrap();
    let combined = format!(
        "{}{}",
        String::from_utf8_lossy(&out.stdout),
        String::from_utf8_lossy(&out.stderr)
    );
    assert!(
        !combined.contains("AX0911"),
        "the leak gate must whitelist the synthetic worker's leak, got:\n{combined}"
    );
    assert!(out.status.success(), "session_parmap_integer should still compile+run:\n{combined}");
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

/// The dual of the param-borrow-return `grab`: a function projecting a heap field of a
/// FRESH LOCAL and returning it (`mkGrab n = inner (W {..})`) cannot return a borrow (the
/// local dies at exit) — so regions MOVE the projected field out instead. The local's
/// destructor skips the moved-out slot (`drop W skip{inner}`), reclaiming the siblings +
/// shell while the returned field escapes owned. The verifier models the move-out (promotes
/// the skipped-slot projection to owned) and reports clean; the default-on gate compiles it;
/// and it runs leak-free (`main = length (mkGrab 7) = 1`) on every backend.
#[test]
fn escaping_local_field_is_moved_out_not_rejected() {
    let path = format!(
        "{}/tests/fixtures/escape_local_borrow.axi",
        env!("CARGO_MANIFEST_DIR")
    );

    let verify = axionc().args(["--emit", "verify", &path]).output().unwrap();
    let vstdout = String::from_utf8_lossy(&verify.stdout);
    assert!(
        vstdout.contains("ok:") && !vstdout.contains("FAIL:"),
        "the move-out should verify clean (no dangling borrow), got:\n{vstdout}"
    );

    // the default-on gate must now ACCEPT it and every backend agrees on `1`.
    for backend in ["interp", "cranelift", "llvm"] {
        let run = axionc()
            .args(["run", "--backend", backend, &path])
            .output()
            .unwrap();
        assert!(
            run.status.success(),
            "{backend}: the move-out should compile and run, got:\n{}{}",
            String::from_utf8_lossy(&run.stdout),
            String::from_utf8_lossy(&run.stderr)
        );
        assert_eq!(
            String::from_utf8_lossy(&run.stdout).trim(),
            "1",
            "{backend}: mkGrab's moved-out field length should be 1"
        );
    }
}

/// The case-extraction dual of the move-out: a fn that case-extracts a heap field of a
/// FRESH LOCAL scrutinee and returns it, while a SIBLING field is a dead heap discard
/// (`grabBox n = case Box (Cons n Nil) (Cons 9 Nil) of Box x _ -> x`). This was a real
/// reclaim bug — the non-deep arm freed the discarded sibling with `loadraw s+off` but
/// emitted the scrutinee's shell-free BEFORE the load (reading the freed cell → UAF, the
/// gate refused). The fix orders the shell-free LAST so every discarded-field load reads a
/// live scrutinee. Asserts it now verifies clean and runs leak-free (= 1) on every backend.
#[test]
fn case_extracted_local_field_escape_is_reclaimed_in_order() {
    for fixture in ["case_extract_escape", "tuple_extract_escape"] {
        let path = format!("{}/tests/fixtures/{fixture}.axi", env!("CARGO_MANIFEST_DIR"));
        let verify = axionc().args(["--emit", "verify", &path]).output().unwrap();
        let vstdout = String::from_utf8_lossy(&verify.stdout);
        assert!(
            vstdout.contains("ok:") && !vstdout.contains("FAIL:"),
            "{fixture}: the case-extraction move-out should verify clean, got:\n{vstdout}"
        );
        for backend in ["interp", "cranelift", "llvm"] {
            let run = axionc()
                .args(["run", "--backend", backend, &path])
                .output()
                .unwrap();
            assert!(
                run.status.success(),
                "{fixture}/{backend}: should compile and run, got:\n{}{}",
                String::from_utf8_lossy(&run.stdout),
                String::from_utf8_lossy(&run.stderr)
            );
            assert_eq!(
                String::from_utf8_lossy(&run.stdout).trim(),
                "1",
                "{fixture}/{backend}: the moved-out field length should be 1"
            );
        }
    }
}

/// Closure-argument linearity for an UNSIGNED closure: a predicate with no user signature
/// passed to `filter` over a heap element type (`List Integer`). Specialization recovers the
/// closure's concrete type via inference (`infer_unsigned_sigs`), signs it, and specializes
/// `filter$$isBig` — so the element-aliasing double-free (AX0912) cannot arise. Before this
/// the unsigned closure had no type for the type-directed specialization → AX0912-rejected.
/// Asserts the gate now ACCEPTS it (no AX0912) and every backend agrees (= 2).
#[test]
fn unsigned_closure_over_heap_specializes_not_rejected() {
    let path = format!(
        "{}/tests/fixtures/hof_unsigned_closure.axi",
        env!("CARGO_MANIFEST_DIR")
    );
    let gate = axionc().args(["--release", &path]).output().unwrap();
    let combined = format!(
        "{}{}",
        String::from_utf8_lossy(&gate.stdout),
        String::from_utf8_lossy(&gate.stderr)
    );
    assert!(
        !combined.contains("AX0912"),
        "an unsigned closure over a heap type should specialize, not hit AX0912:\n{combined}"
    );
    for backend in ["interp", "cranelift", "llvm"] {
        let run = axionc()
            .args(["run", "--backend", backend, &path])
            .output()
            .unwrap();
        assert_eq!(
            String::from_utf8_lossy(&run.stdout).trim(),
            "2",
            "{backend}: filter isBig should keep 2 elements"
        );
    }
}
