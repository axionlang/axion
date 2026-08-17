//! Tests for the salsa incremental engine (§8). Built only under `--features salsa`.
#![cfg(feature = "salsa")]
#![allow(clippy::unwrap_used, clippy::expect_used, let_underscore_drop)]

use std::sync::{Arc, Mutex};

use axionc::db::{self, AxionDb};

/// How many times the `parse` query actually executed (a `WillExecute` event for
/// the `parse` tracked fn), per the event log.
fn parse_runs(log: &Arc<Mutex<Vec<String>>>) -> usize {
    log.lock()
        .unwrap()
        .iter()
        .filter(|e| e.contains("WillExecute") && e.contains("parse"))
        .count()
}

#[test]
fn unchanged_text_reuses_the_memoized_parse() {
    let log = Arc::new(Mutex::new(Vec::new()));
    let mut db = AxionDb::with_event_logger(Arc::clone(&log));

    let file = db.set_file("/mem.axi", "main :: Int\nmain = 0\n".to_string());
    let _ = db::diagnostics_of(&db, file);
    let after_first = parse_runs(&log);
    assert_eq!(after_first, 1, "first query should parse once");

    // Re-setting IDENTICAL text is a no-op (set_file skips it), so re-querying must
    // NOT re-parse — this is the memoization.
    let file = db.set_file("/mem.axi", "main :: Int\nmain = 0\n".to_string());
    let _ = db::diagnostics_of(&db, file);
    assert_eq!(
        parse_runs(&log),
        after_first,
        "unchanged text must reuse the memoized parse"
    );

    // Editing the text bumps the input revision, so parse re-executes.
    let file = db.set_file("/mem.axi", "main :: Int\nmain = 1\n".to_string());
    let _ = db::diagnostics_of(&db, file);
    assert!(
        parse_runs(&log) > after_first,
        "a real edit must re-run parse"
    );
}

fn fixture(name: &str) -> String {
    format!("{}/tests/fixtures/{name}", env!("CARGO_MANIFEST_DIR"))
}

/// How many times the per-declaration `check_decl` query executed.
fn check_runs(log: &Arc<Mutex<Vec<String>>>) -> usize {
    log.lock()
        .unwrap()
        .iter()
        .filter(|e| e.contains("WillExecute") && e.contains("check_decl"))
        .count()
}

#[test]
fn editing_one_body_rechecks_only_that_declaration() {
    let log = Arc::new(Mutex::new(Vec::new()));
    let mut db = AxionDb::with_event_logger(Arc::clone(&log));

    // Three declarations; g is in the MIDDLE.
    let v1 = "f :: Int -> Int\nf x = x\n\ng :: Int -> Int\ng y = y\n\nmain :: Int\nmain = 0\n";
    let file = db.set_file("/two.axi", v1.to_string());
    let _ = db::diagnostics_of(&db, file);
    let after_first = check_runs(&log);
    assert!(
        after_first >= 2,
        "first run should check every declaration (>=2 incl. prelude), got {after_first}"
    );

    // Edit g's body with a LENGTH-CHANGING edit. Thanks to the relative-offset
    // normalization, `main` (which shifts in the file) has an unchanged normalized
    // body and is reused; `f` (before g) is unchanged. Only g re-checks.
    let v2 = "f :: Int -> Int\nf x = x\n\ng :: Int -> Int\ng y = y + 1234\n\nmain :: Int\nmain = 0\n";
    let file = db.set_file("/two.axi", v2.to_string());
    let _ = db::diagnostics_of(&db, file);
    let delta = check_runs(&log) - after_first;
    assert_eq!(
        delta, 1,
        "a length-changing edit to a middle declaration must re-check exactly one, re-checked {delta}"
    );
}

/// How many times the per-declaration `infer_decl` query executed.
fn infer_runs(log: &Arc<Mutex<Vec<String>>>) -> usize {
    log.lock()
        .unwrap()
        .iter()
        .filter(|e| e.contains("WillExecute") && e.contains("infer_decl"))
        .count()
}

#[test]
fn editing_one_isolated_body_reinfers_only_that_declaration() {
    let log = Arc::new(Mutex::new(Vec::new()));
    let mut db = AxionDb::with_event_logger(Arc::clone(&log));

    // Two isolated functions: annotated, calling only builtins.
    let v1 = "f :: Int -> Int\nf x = x + 1\n\ng :: Int -> Int\ng y = y + 2\n\nmain :: Int\nmain = 0\n";
    let file = db.set_file("/iso.axi", v1.to_string());
    let _ = db::diagnostics_of(&db, file);
    let after_first = infer_runs(&log);
    assert!(after_first >= 2, "first run infers each isolated decl, got {after_first}");

    // Edit g's body with a LENGTH-CHANGING edit. The relative-offset normalization
    // keeps `main`'s normalized body identical despite its shift in the file, so it
    // is reused; only g re-infers.
    let v2 = "f :: Int -> Int\nf x = x + 1\n\ng :: Int -> Int\ng y = y + 999999\n\nmain :: Int\nmain = 0\n";
    let file = db.set_file("/iso.axi", v2.to_string());
    let _ = db::diagnostics_of(&db, file);
    assert_eq!(
        infer_runs(&log) - after_first,
        1,
        "a length-changing edit to a middle isolated body must re-infer exactly one declaration"
    );
}

/// A stable, order-independent key for one diagnostic: (code, first-label span,
/// message). Lets us compare the engine's diagnostic SET to whole-module's.
fn keys(diags: &[axionc::Diagnostic]) -> Vec<(String, usize, usize, String)> {
    let mut out: Vec<_> = diags
        .iter()
        .map(|d| {
            let (s, e) = d.labels.first().map_or((0, 0), |l| (l.start, l.end));
            (d.code.clone(), s, e, d.message.clone())
        })
        .collect();
    out.sort();
    out
}

#[test]
fn engine_diagnostics_match_whole_module() {
    // The correctness gate for per-declaration inference: for every fixture, the
    // salsa engine's diagnostics (isolated per-decl inference + residual + per-decl
    // linearity + whole-module checks) must equal whole-module `compile_front`
    // EXACTLY — otherwise the isolation predicate is unsound.
    let dir = format!("{}/tests/fixtures", env!("CARGO_MANIFEST_DIR"));
    let mut checked = 0;
    for entry in std::fs::read_dir(&dir).unwrap() {
        let path = entry.unwrap().path();
        if path.extension().and_then(|e| e.to_str()) != Some("axi") {
            continue;
        }
        let p = path.to_str().unwrap();
        let src = std::fs::read_to_string(&path).unwrap();

        let whole = axionc::compile_diagnostics(&src, p);

        let mut db = AxionDb::default();
        let file = db.set_file(p, src.clone());
        let engine = db::diagnostics_of(&db, file);

        assert_eq!(
            keys(&whole),
            keys(&engine),
            "engine diagnostics diverge from whole-module for {p}"
        );
        checked += 1;
    }
    assert!(checked > 20, "expected to exercise many fixtures, got {checked}");
}

#[test]
fn diagnostics_flow_through_the_engine() {
    let mut db = AxionDb::default();

    // A well-formed program: the engine reports nothing.
    let clean = db.set_file("/ok.axi", "main :: Int\nmain = 0\n".to_string());
    assert!(
        db::diagnostics_of(&db, clean).is_empty(),
        "well-formed program should have no diagnostics"
    );

    // A use-after-consume surfaces AX0001, same as a direct compile.
    let path = fixture("use_after_consume.axi");
    let src = std::fs::read_to_string(&path).unwrap();
    let file = db.set_file(&path, src);
    let diags = db::diagnostics_of(&db, file);
    assert!(
        diags.iter().any(|d| d.code == "AX0001"),
        "expected AX0001 through the engine, got: {diags:?}"
    );
}
