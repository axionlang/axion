//! Tests for the lossless rowan CST (§8, Stage 1). Built only under `--features cst`.
#![cfg(feature = "cst")]
#![allow(clippy::unwrap_used, clippy::expect_used)]

use axionc::cst::{build_cst, document_symbols, SyntaxKind, SyntaxNode};

fn has_kind(root: &SyntaxNode, kind: SyntaxKind) -> bool {
    root.descendants().any(|n| n.kind() == kind)
}

/// The defining property: the CST is LOSSLESS — concatenating its leaves reproduces
/// the source byte-for-byte. Checked over every fixture and example.
#[test]
fn cst_round_trips_every_fixture() {
    let mut checked = 0;
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
            let src = std::fs::read_to_string(&path).unwrap();
            let cst = build_cst(&src);
            assert_eq!(
                cst.text().to_string(),
                src,
                "CST is not lossless for {}",
                path.display()
            );
            checked += 1;
        }
    }
    assert!(checked > 20, "expected many files exercised, got {checked}");
}

#[test]
fn cst_round_trips_comments_and_layout() {
    // Comments and irregular whitespace must survive verbatim.
    let src = "-- a leading comment\nf :: Int   -- trailing\nf  =  0\n\n\ndata T = A | B\n";
    let cst = build_cst(src);
    assert_eq!(cst.text().to_string(), src, "trivia must round-trip");
}

#[test]
fn cst_is_grammar_structured() {
    // Stage 2: expressions and patterns are nested nodes, not a flat token run.
    let cst = build_cst("f x = x + 1\n");
    assert!(has_kind(&cst, SyntaxKind::VAR_PAT), "the parameter `x` should be a VAR_PAT");
    assert!(has_kind(&cst, SyntaxKind::BINOP_EXPR), "`x + 1` should be a BINOP_EXPR");
    assert!(has_kind(&cst, SyntaxKind::LITERAL_EXPR), "`1` should be a LITERAL_EXPR");

    let cst = build_cst("g y = if y then A else B\n");
    assert!(has_kind(&cst, SyntaxKind::IF_EXPR), "should have an IF_EXPR");
}

#[test]
fn broken_declaration_becomes_an_error_node_but_siblings_survive() {
    // A malformed declaration is wrapped in an ERROR node; a valid sibling still gets
    // its grammar structure — CST-level resilience.
    let cst = build_cst("broken = = =\n\ngood :: Int\ngood = h 1\n");
    assert!(has_kind(&cst, SyntaxKind::ERROR), "the broken decl should be an ERROR node");
    assert!(
        has_kind(&cst, SyntaxKind::APP_EXPR),
        "the valid sibling `h 1` should still be a structured APP_EXPR"
    );
    // And it still round-trips.
    assert_eq!(cst.text().to_string(), "broken = = =\n\ngood :: Int\ngood = h 1\n");
}

#[test]
fn document_symbols_lists_top_level_declarations() {
    // Column-1 boundaries split the module into declarations; the first identifier
    // names each. `f`'s signature and clause are separate top-level lines.
    let src = "f :: Int\nf = 0\n\ndata Color = Red | Green\n\nmain :: Int\nmain = f\n";
    let syms: Vec<String> = document_symbols(&build_cst(src))
        .into_iter()
        .map(|(n, _)| n)
        .collect();
    assert!(syms.contains(&"f".to_string()), "expected `f`, got {syms:?}");
    assert!(
        syms.contains(&"data".to_string()) || syms.contains(&"Color".to_string()),
        "expected the data declaration, got {syms:?}"
    );
    assert!(syms.contains(&"main".to_string()), "expected `main`, got {syms:?}");
}
