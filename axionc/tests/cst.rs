//! Tests for the lossless rowan CST (§8, Stage 1). Built only under `--features cst`.
#![cfg(feature = "cst")]
#![allow(clippy::unwrap_used, clippy::expect_used)]

use axionc::cst::{
    binders_in_decl, build_cst, document_symbols, expr_matches_parser, module_matches_parser,
    parse_recover, SyntaxKind, SyntaxNode,
};

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
fn token_driven_parser_recovers_within_a_declaration() {
    // Intra-declaration recovery: a half-typed clause keeps its structure (the params
    // survive as VAR_PAT nodes), and lexable garbage between two good declarations is
    // wrapped in an ERROR node without killing the siblings — all still lossless.
    let src = "helper x y = x + \n\n= = =\n\nmain z = z\n";
    let cst = parse_recover(src);
    assert_eq!(cst.text().to_string(), src, "recovery must stay lossless");
    assert!(has_kind(&cst, SyntaxKind::ERROR), "the `= = =` garbage becomes an ERROR node");
    // `helper`'s params survive even though its body has a hole.
    assert!(
        has_kind(&cst, SyntaxKind::VAR_PAT),
        "the half-typed clause keeps its parameter patterns"
    );

    // The binders in scope inside `helper`'s (broken) body: the function + its params.
    let at_hole = src.find("x + ").unwrap() + 4;
    let binders = binders_in_decl(&cst, at_hole);
    assert!(binders.contains(&"x".to_string()), "param x survives: {binders:?}");
    assert!(binders.contains(&"y".to_string()), "param y survives: {binders:?}");

    // The valid sibling after the garbage still parses — its param `z` is a binder.
    let at_z = src.rfind('z').unwrap();
    assert!(
        binders_in_decl(&cst, at_z).contains(&"z".to_string()),
        "the sibling after the ERROR node still parses"
    );
}

#[test]
fn a_stray_illegal_character_does_not_blank_the_cst() {
    // Lexer-level recovery: a single illegal character (`@`) used to make `lex` fail and
    // clear the whole token stream. Now it is skipped (surviving in trivia), so the CST
    // still round-trips AND the surrounding declarations keep their structure — the
    // editor no longer goes dark on one bad keystroke.
    let src = "helper :: Int\nhelper = x @ 1\n\nmain :: Int\nmain = helper\n";
    let cst = build_cst(src);
    assert_eq!(cst.text().to_string(), src, "the illegal char survives in trivia (lossless)");
    // Both declarations are still present (not a single blank MODULE).
    let decls = cst
        .children()
        .filter(|n| matches!(n.kind(), SyntaxKind::DECL | SyntaxKind::ERROR))
        .count();
    assert!(decls >= 4, "sig+clause for helper and main all survive: {decls}");
    // The names are still findable across the illegal character.
    assert!(document_symbols(&cst).iter().any(|(n, _)| n == "main"), "main still named");
}

#[test]
fn token_driven_parser_matches_recursive_descent_over_the_subset() {
    // Stage 3a: the token-driven CST parser + lowering must produce EXACTLY the same
    // AST as the existing recursive-descent parser, over the supported subset. This
    // equivalence is what will gate flipping the pipeline onto the CST.
    for e in [
        "1",
        "42",
        "3.14",
        "\"hi\"",
        "x",
        "Nothing",
        "f x",
        "f x y",
        "g (h x)",
        "1 + 2",
        "1 + 2 * 3",
        "a - b - c",
        "a * b + c",
        "a == b",
        "x < y + 1",
        "1 + 2 == 3",
        "(1 + 2) * 3",
        "f (a + b) c",
        "foo 1 2 + bar 3",
        "map f (g x)",
        // Stage 3b: full operator ladder + desugarings, if, lambda, tuples.
        "x : xs",
        "1 : 2 : xs",
        "xs ++ ys",
        "x : xs ++ ys",
        "a $ f b",
        "f $ g $ x",
        "f . g",
        "f . g . h",
        "f . g $ x",
        "a `div` b",
        "x `mod` y + 1",
        "1.0 +. 2.0 *. 3.0",
        "a ==. b",
        "x <. y",
        "if a then b else c",
        "if x < y then x else y",
        "\\x -> x + 1",
        "\\x y -> f x y",
        "\\_ -> 0",
        "\\(Cons x xs) -> x",
        "(1, 2)",
        "(a, b, c)",
        "(f x, g y)",
        "map (\\x -> x * 2) xs",
        "if p then (\\x -> x) else g",
        // Stage 3c: lists, ranges, operator sections, records.
        "[]",
        "[1, 2, 3]",
        "[a, b, c]",
        "[1 + 2, f x]",
        "[1 .. 10]",
        "[lo .. hi]",
        "1 : [2, 3]",
        "map f [1, 2, 3]",
        "(+)",
        "(*)",
        "(==)",
        "foldr (+) 0 xs",
        "Point { x = 1, y = 2 }",
        "p { x = 5 }",
        "Wrap { inner = f a }",
        "map (+) [1, 2]",
        // Stage 3d: layout blocks — case, let (single-line and multi-line).
        "case x of A -> 1",
        "case xs of Nil -> 0",
        "case m of Just x -> x",
        "let x = 1 in x + 1",
        "let f y = y * 2 in f 3",
        "let a = 1 in let b = 2 in a + b",
        "case n of\n    0 -> True\n    _ -> False",
        "case p of\n    Cons y ys -> y\n    Nil -> 0",
        "let\n    x = 1\n    y = 2\n  in x + y",
        "\\x -> case x of Just y -> y",
        // Stage 3e: do-notation (desugars to nested case).
        "do x",
        "do\n  x <- f\n  g x",
        "do\n  a <- act1\n  b <- act2\n  pure (a + b)",
        "do\n  putLine s\n  x",
        "do\n  (x, y) <- recv c\n  send c x",
    ] {
        assert!(
            expr_matches_parser(e),
            "token-driven parser diverges from the reference for: {e}"
        );
    }
}

#[test]
fn token_driven_module_matches_recursive_descent() {
    // Stage 3f: whole function-only modules (signatures with types + constraints,
    // multi-clause functions, patterns, guards, where) lower to EXACTLY the same
    // `ast::Module` as the recursive-descent parser.
    for m in [
        "main :: Int\nmain = 0\n",
        "id :: a -> a\nid x = x\n",
        "add :: Int -> Int -> Int\nadd x y = x + y\n",
        "const :: a -> b -> a\nconst x _ = x\n",
        "f :: Buffer U8 %1 -> Buffer U8 %1\nf b = b\n",
        "pair :: a -> b -> (a, b)\npair x y = (x, y)\n",
        "eq3 :: Eq a => a -> Bool\neq3 x = x == x\n",
        "cmp :: (Eq a, Ord b) => a -> b -> Int\ncmp x y = 0\n",
        "len :: List a -> Int\nlen Nil = 0\nlen (Cons x xs) = 1 + len xs\n",
        "sign :: Int -> Int\nsign n\n  | n < 0 = 0 - 1\n  | n == 0 = 0\n  | otherwise = 1\n",
        "g :: Int -> Int\ng x = y + z\n  where\n    y = x + 1\n    z = x * 2\n",
        "a :: Int\na = 1\n\nb :: Int\nb = a + 1\n\nmain :: Int\nmain = b\n",
        "unit :: ()\nunit = 0\n",
        "h y = case y of\n    Nil -> 0\n    Cons z zs -> z\n",
    ] {
        assert!(
            module_matches_parser(m),
            "token-driven module parser diverges from the reference for:\n{m}"
        );
    }
}

#[test]
fn token_driven_module_matches_over_all_fixtures() {
    // The flip gate: the token-driven module parser must reproduce the
    // recursive-descent parser's `ast::Module` for EVERY real program.
    let mut failures = Vec::new();
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
            // `recover_partial.axi` is deliberately malformed; the two parsers recover
            // differently by design, so byte-identical ASTs aren't expected there.
            if path.file_name().unwrap() == "recover_partial.axi" {
                continue;
            }
            let src = std::fs::read_to_string(&path).unwrap();
            checked += 1;
            if !module_matches_parser(&src) {
                failures.push(path.file_name().unwrap().to_string_lossy().into_owned());
            }
        }
    }
    assert!(checked > 20, "expected many fixtures, got {checked}");
    assert!(
        failures.is_empty(),
        "{} / {checked} modules diverge from the reference: {failures:?}",
        failures.len()
    );
}

#[test]
fn subset_boundary_is_honest() {
    // Declarations, signatures and types are not yet parsed by the token-driven path
    // (Stage 3f: the module parser). A signature construct isn't a valid expression,
    // so it stays out of the expression subset.
    for e in ["x :: Int", "\\x -> y where y = x"] {
        assert!(!expr_matches_parser(e), "unexpectedly claimed support for: {e}");
    }
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
