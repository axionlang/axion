//! Tests for the LSP walking skeleton (§8). Exercise the pure `analyze()` core —
//! text → LSP diagnostics — without spinning up the async server. Built only under
//! `--features lsp`.
#![cfg(feature = "lsp")]
#![allow(clippy::unwrap_used, clippy::expect_used)]

use axionc::lsp::analyze;
use tower_lsp::lsp_types::{DiagnosticSeverity, NumberOrString};

fn fixture(name: &str) -> String {
    format!("{}/tests/fixtures/{name}", env!("CARGO_MANIFEST_DIR"))
}

fn code_of(d: &tower_lsp::lsp_types::Diagnostic) -> Option<&str> {
    match &d.code {
        Some(NumberOrString::String(s)) => Some(s.as_str()),
        _ => None,
    }
}

#[test]
fn use_after_consume_surfaces_ax0001() {
    let path = fixture("use_after_consume.axi");
    let src = std::fs::read_to_string(&path).unwrap();
    let found = analyze(&path, &src);
    let d = found
        .iter()
        .find(|a| code_of(&a.diagnostic) == Some("AX0001"))
        .expect("expected an AX0001 diagnostic");
    assert_eq!(d.diagnostic.severity, Some(DiagnosticSeverity::ERROR));
    // A real span, not the 0,0 fallback.
    assert!(
        d.diagnostic.range.end.line > 0 || d.diagnostic.range.end.character > 0,
        "diagnostic should carry a non-empty range"
    );
}

#[test]
fn level_ceiling_surfaces_ax0500() {
    let path = fixture("level_exceeded.axi");
    let src = std::fs::read_to_string(&path).unwrap();
    let found = analyze(&path, &src);
    assert!(
        found
            .iter()
            .any(|a| code_of(&a.diagnostic) == Some("AX0500")),
        "expected an AX0500 diagnostic for an L1 decl under an L0 ceiling"
    );
}

#[test]
fn typo_carries_a_machine_applicable_fix() {
    let path = fixture("typo_suggestion.axi");
    let src = std::fs::read_to_string(&path).unwrap();
    let found = analyze(&path, &src);
    let d = found
        .iter()
        .find(|a| code_of(&a.diagnostic) == Some("AX0101"))
        .expect("expected an AX0101 diagnostic");
    let fix = d.fix.as_ref().expect("AX0101 should carry a quick-fix");
    assert_eq!(fix.new_text, "length", "the fix should rename to `length`");
}
