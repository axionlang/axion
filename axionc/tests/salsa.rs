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
