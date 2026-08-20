//! Tests for the LSP walking skeleton (§8). Exercise the pure `analyze()` core —
//! text → LSP diagnostics — without spinning up the async server. Built only under
//! `--features lsp`.
#![cfg(feature = "lsp")]
#![allow(clippy::unwrap_used, clippy::expect_used)]

use axionc::lsp::{
    analyze, completions, definition, definition_at, folds, outline, ownership_hints,
    references_at, references_of, selection, signature_help,
};
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
fn outline_lists_top_level_declarations() {
    let names: Vec<String> = outline("f :: Int\nf = 0\n\ndata Color = Red\n\nmain :: Int\nmain = f\n")
        .into_iter()
        .map(|s| s.name)
        .collect();
    assert!(names.contains(&"f".to_string()), "expected `f` in {names:?}");
    assert!(names.contains(&"main".to_string()), "expected `main` in {names:?}");
}

#[test]
fn folding_ranges_cover_multiline_declarations() {
    // A one-line decl doesn't fold; a multi-line one does.
    let src = "one = 1\n\nbig x =\n  case x of\n    A -> 1\n    B -> 2\n";
    let fs = folds(src);
    assert!(
        fs.iter().any(|f| f.end_line > f.start_line),
        "the multi-line `big` should produce a fold: {fs:?}"
    );
}

#[test]
fn selection_range_expands_through_the_syntax_tree() {
    // Cursor on the `1` inside `x + 1`: the chain must grow (literal ⊂ … ⊂ decl).
    let src = "f x = x + 1\n";
    let offset = src.find('1').unwrap();
    let sel = selection(src, offset);
    // Walk the parent chain; ranges must be strictly non-shrinking and reach beyond
    // the single character.
    let innermost = sel.range;
    let mut widest = sel.range;
    let mut cur = sel.parent;
    while let Some(p) = cur {
        widest = p.range;
        cur = p.parent;
    }
    assert!(
        widest.end > innermost.end || widest.start < innermost.start,
        "selection should expand outward: inner={innermost:?} outer={widest:?}"
    );
}

#[test]
fn goto_definition_jumps_to_the_declaration() {
    // `main = helper 0` — jumping from the use of `helper` lands on `helper`'s
    // defining line (its signature), not the use site.
    let src = "helper :: Int -> Int\nhelper x = x\n\nmain :: Int\nmain = helper 0\n";
    let use_site = src.rfind("helper").unwrap() + 1; // cursor inside the call `helper`
    let def = definition(src, use_site).expect("expected a definition");
    // The signature is on line 0; the use is on line 4.
    assert_eq!(def.start.line, 0, "should jump to the first `helper` decl, got {def:?}");
    // And it points at the name, not the whole line.
    assert_eq!(def.start.character, 0);

    // Data type names resolve too.
    let src2 = "data Color = Red | Green\n\nfirst :: Color -> Color\nfirst c = c\n";
    let at = src2.rfind("Color").unwrap();
    let d2 = definition(src2, at).expect("data type should resolve");
    assert_eq!(d2.start.line, 0, "should jump to the `data Color` line: {d2:?}");

    // A cursor on empty space / a literal resolves to nothing.
    assert!(definition(src, src.find(" 0").unwrap() + 1).is_none());
}

#[test]
fn goto_definition_resolves_locals_and_constructors() {
    // A parameter beats a same-named top-level: cursor on `x` in the body resolves to
    // the PARAMETER on line 1, not the top-level `x` on line 0.
    let src = "x :: Int\nx = 0\n\nf :: Int -> Int\nf x = x + 1\n";
    let body_x = src.rfind("x +").unwrap();
    let def = definition(src, body_x).expect("param should resolve");
    assert_eq!(def.start.line, 4, "should jump to the parameter on line 4, got {def:?}");

    // A `let` binding resolves to itself.
    let src2 = "g :: Int\ng = let y = 1 in y + y\n";
    let use_y = src2.rfind("y +").unwrap();
    let d2 = definition(src2, use_y).expect("let binding should resolve");
    assert_eq!(d2.start.line, 1);
    // and it points at the binding `y`, left of the use.
    assert!(d2.start.character < 15);

    // A constructor resolves to its `data` declaration.
    let src3 = "data List a = Cons a (List a) | Nil\n\nhd :: List a -> a\nhd (Cons x xs) = x\n";
    let use_cons = src3.rfind("Cons").unwrap();
    let d3 = definition(src3, use_cons).expect("constructor should resolve");
    assert_eq!(d3.start.line, 0, "Cons should resolve into the data decl: {d3:?}");
}

#[test]
fn completion_offers_scope_toplevel_builtins_and_keywords() {
    let src = "data Color = Red | Green\n\nhelper :: Int -> Int -> Int\nhelper x y = x + y\n\nmain :: Int\nmain = 0\n";
    // Cursor on `y` in the body — the param `x` (and `y`) and top-level/builtins are
    // in scope. (Completion needs the enclosing clause to parse; it degrades to
    // top-level + builtins + keywords when the code around the cursor is malformed.)
    let offset = src.rfind('y').unwrap();
    let labels: Vec<String> = completions(src, offset).into_iter().map(|c| c.label).collect();

    assert!(labels.contains(&"x".to_string()), "local param `x` should be offered");
    assert!(labels.contains(&"helper".to_string()), "top-level `helper` should be offered");
    assert!(labels.contains(&"Color".to_string()), "the data type should be offered");
    assert!(labels.contains(&"Red".to_string()), "the constructor `Red` should be offered");
    assert!(labels.contains(&"putStrLn".to_string()), "a builtin should be offered");
    assert!(labels.contains(&"case".to_string()), "a keyword should be offered");
    // De-duplicated.
    let mut sorted = labels.clone();
    sorted.sort();
    sorted.dedup();
    assert_eq!(sorted.len(), labels.len(), "labels should be unique");

    // Outside any function, a local param isn't in scope.
    let top = completions(src, src.find("main = 0").unwrap());
    assert!(!top.iter().any(|c| c.label == "x"), "`x` is not in scope at top level of main");
}

#[test]
fn find_references_is_scope_aware() {
    // Top-level `inc` — its signature, its clause, and the call from `main` — three
    // references (with the declaration).
    let src = "inc :: Int -> Int\ninc n = n + 1\n\nmain :: Int\nmain = inc (inc 0)\n";
    let at_def = src.find("inc ::").unwrap();
    let with_decl = references_of(src, at_def, true);
    assert_eq!(with_decl.len(), 4, "sig + clause name + two calls: {with_decl:?}");
    let without = references_of(src, at_def, false);
    assert_eq!(without.len(), 3, "excluding the declaration line's name");

    // Shadowing: a parameter `n` is distinct from a top-level `n`.
    let src2 = "n :: Int\nn = 0\n\nf :: Int -> Int\nf n = n + n\n";
    let param_use = src2.rfind("n + n").unwrap(); // the first `n` in the body
    let refs = references_of(src2, param_use, true);
    // f's clause: the param `n` + two uses = 3, and NOT the top-level `n` (2 more).
    assert_eq!(refs.len(), 3, "only the local `n` occurrences, not the top-level: {refs:?}");
    // All references are on line 4 (f's clause), not line 1 (top-level n).
    assert!(refs.iter().all(|r| r.start.line == 4), "should stay within f: {refs:?}");
}

#[test]
fn positions_are_utf16_code_units() {
    // Non-ASCII before an identifier on the same line: `é` is 2 bytes but 1 UTF-16 unit,
    // the emoji is 4 bytes but 2 units (a surrogate pair). The reported `character` must
    // be the UTF-16 column, not the byte column.
    let src = "g :: Int\ng = 0\n\nmain :: Int\nmain = id \"café😀\" g\n";
    let at = src.find("g ::").unwrap();
    let refs = references_of(src, at, true);
    let use_ref = refs.iter().find(|r| r.start.line == 4).expect("`g` is used on line 4");

    let line = "main = id \"café😀\" g";
    let g_byte = line.rfind('g').unwrap();
    let prefix = line.get(..g_byte).unwrap_or("");
    let expected_u16 = u32::try_from(prefix.encode_utf16().count()).unwrap_or(0);
    assert_eq!(use_ref.start.character, expected_u16, "reference column must be UTF-16");
    // The test only means something if the UTF-16 column differs from the byte column.
    assert!(
        (expected_u16 as usize) < g_byte,
        "prefix must contain multi-byte characters to be meaningful"
    );
}

#[test]
fn signature_help_tracks_the_active_parameter() {
    let src = "add :: Int -> Int -> Int\nadd x y = x + y\n\nmain :: Int\nmain = add 1 2\n";
    let ws: std::collections::HashMap<String, String> = std::collections::HashMap::new();
    let base = src.rfind("add 1 2").unwrap();

    // Writing the first argument → parameter 0 active; the label is the full signature.
    let first = signature_help("t.axi", src, base + 4, &ws).expect("sig help on first arg");
    assert_eq!(first.signatures[0].label, "add :: Int -> Int -> Int");
    assert_eq!(first.active_parameter, Some(0));
    assert_eq!(first.signatures[0].parameters.as_ref().unwrap().len(), 2);

    // After the first argument (a space) → parameter 1 active.
    let second = signature_help("t.axi", src, base + 6, &ws).expect("sig help after first arg");
    assert_eq!(second.active_parameter, Some(1));

    // The callee's signature can come from an imported file.
    let (a, b) = ("/w/A.axi", "/w/B.axi");
    let a_src = "import B\n\nmain :: Int\nmain = twice 5\n";
    let mut ws2: std::collections::HashMap<String, String> = std::collections::HashMap::new();
    ws2.insert(a.to_string(), a_src.to_string());
    ws2.insert(b.to_string(), "twice :: Int -> Int\ntwice n = n\n".to_string());
    let at = a_src.rfind("twice 5").unwrap() + 6;
    let sh = signature_help(a, a_src, at, &ws2).expect("cross-file sig help");
    assert_eq!(sh.signatures[0].label, "twice :: Int -> Int");
    assert_eq!(sh.active_parameter, Some(0));

    // Not applying a named function → nothing.
    assert!(signature_help("t.axi", src, src.find("x + y").unwrap() + 4, &ws).is_none());
}

#[test]
fn completion_survives_a_half_typed_body() {
    // Mid-edit: the body is incomplete (a trailing `+` with no right operand), which the
    // AST parser drops. Intra-declaration recovery keeps the clause, so its parameters
    // are still offered — the case that used to degrade to top-level + builtins only.
    let src = "helper :: Int -> Int -> Int\nhelper x y = x + \n\nmain :: Int\nmain = 0\n";
    let at_hole = src.find("x + ").unwrap() + 4; // right after the hole
    let labels: Vec<String> = completions(src, at_hole).into_iter().map(|c| c.label).collect();
    assert!(labels.contains(&"x".to_string()), "param `x` offered mid-edit: {labels:?}");
    assert!(labels.contains(&"y".to_string()), "param `y` offered mid-edit: {labels:?}");
    // Top-level and builtins are still there too.
    assert!(labels.contains(&"helper".to_string()));
    assert!(labels.contains(&"putStrLn".to_string()));

    // Lexer-level recovery: a stray illegal character in the body no longer clears the
    // buffer — the param and top-level names are still offered.
    let bad = "helper :: Int -> Int\nhelper x = x @ \n\nmain :: Int\nmain = 0\n";
    let at = bad.find("x @").unwrap();
    let l2: Vec<String> = completions(bad, at).into_iter().map(|c| c.label).collect();
    assert!(l2.contains(&"x".to_string()), "param survives an illegal char: {l2:?}");
    assert!(l2.contains(&"helper".to_string()), "top-level survives an illegal char");
}

#[test]
fn cross_file_definition_and_references_follow_imports() {
    // A imports B and uses B's `helper` twice; B defines it. The workspace holds both.
    let a = "/w/A.axi";
    let b = "/w/B.axi";
    let a_src = "import B\n\nmain :: Int\nmain = helper (helper 0)\n";
    let b_src = "helper :: Int -> Int\nhelper x = x\n";
    let mut ws = std::collections::HashMap::new();
    ws.insert(a.to_string(), a_src.to_string());
    ws.insert(b.to_string(), b_src.to_string());

    // Go-to-definition from A's use of `helper` lands in B's signature.
    let use_off = a_src.find("helper (").unwrap() + 1;
    let (def_path, range) = definition_at(a, a_src, use_off, &ws).expect("cross-file def");
    assert_eq!(def_path, b, "helper is defined in B");
    assert_eq!(range.start.line, 0, "B's signature is on line 0: {range:?}");

    // References from B's definition gather A's two calls AND B's sig + clause name.
    let def_off = b_src.find("helper ::").unwrap();
    let refs = references_at(b, b_src, def_off, &ws, true);
    let in_a = refs.iter().filter(|(p, _)| p == a).count();
    let in_b = refs.iter().filter(|(p, _)| p == b).count();
    assert_eq!(in_a, 2, "two calls in A: {refs:?}");
    assert_eq!(in_b, 2, "sig + clause name in B: {refs:?}");

    // A local `x` in B is confined to B — never gathered across files.
    let x_off = b_src.rfind('x').unwrap();
    let xrefs = references_at(b, b_src, x_off, &ws, true);
    assert!(!xrefs.is_empty(), "the local `x` resolves to itself");
    assert!(xrefs.iter().all(|(p, _)| p == b), "local `x` stays in B: {xrefs:?}");

    // With an empty workspace, cross-file resolution degrades to single-file: the use in
    // A resolves to nothing (helper is not defined in A).
    let empty = std::collections::HashMap::new();
    assert!(definition_at(a, a_src, use_off, &empty).is_none(), "no B → no cross-file def");
}

#[test]
fn ownership_hints_draw_the_auto_drop_topology() {
    // `b : Buf` is a linear resource the function never consumes → the compiler injects
    // a `free` at its death point (here: entry). The overlay surfaces that inline.
    let src = "data Buf = Buf { size :: Int }\n\nmakeAndDrop :: Buf %1 -> Int\nmakeAndDrop b = 0\n";
    let hints = ownership_hints("test.axi", src);
    let drop_b = hints
        .iter()
        .find(|h| h.label.contains("drop b"))
        .unwrap_or_else(|| panic!("expected an Auto-Drop hint for `b`: {hints:?}"));
    assert!(drop_b.label.contains("Buf"), "hint names the type: {}", drop_b.label);
    assert!(
        drop_b.tooltip.contains("Auto-Drop"),
        "tooltip explains the drop: {}",
        drop_b.tooltip
    );

    // A program with no linear resources produces no ownership hints.
    let plain = "main :: Int\nmain = 1 + 2\n";
    assert!(ownership_hints("test.axi", plain).is_empty(), "no resources → no hints");

    // A syntactically broken buffer degrades to no hints rather than panicking.
    assert!(ownership_hints("test.axi", "main = = =").is_empty());
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
