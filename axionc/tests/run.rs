//! Integration tests for the walking skeleton: parse → typecheck → run,
//! and the rejection of use-after-consume (the Phase 1 goal, §17).
//!
//! Test code deliberately uses `unwrap`/`expect` (a failure IS the test failure)
//! and drops process handles with `let _`; the crate-wide restriction lints
//! (`Cargo.toml [lints]`) do not fit integration tests, so relax them here.
#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::string_slice,
    unused_qualifications,
    let_underscore_drop
)]

use std::process::Command;

fn axionc() -> Command {
    Command::new(env!("CARGO_BIN_EXE_axionc"))
}

fn example(name: &str) -> String {
    format!("{}/../examples/{name}", env!("CARGO_MANIFEST_DIR"))
}

fn fixture(name: &str) -> String {
    format!("{}/tests/fixtures/{name}", env!("CARGO_MANIFEST_DIR"))
}

#[test]
fn hello_compiles_and_runs() {
    let out = axionc().arg(example("01_hello.axi")).output().unwrap();
    assert!(out.status.success());
    assert_eq!(String::from_utf8_lossy(&out.stdout), "Hello, Axion!\n");
}

#[test]
fn fib_compiles_and_runs() {
    let out = axionc().arg(example("02_fib.axi")).output().unwrap();
    assert!(out.status.success());
    assert_eq!(String::from_utf8_lossy(&out.stdout), "832040\n");
}

#[test]
fn over_application_runs_on_all_backends() {
    // applying a function beyond its arity (`(f a…) b…`) — a function returning a
    // function that is then applied, for both top-level functions and a `where`-local.
    // The lowering splits it into call-to-arity + apply-the-rest, so interp, cranelift
    // and llvm all agree (→ 150). Previously cranelift errored and `--release`
    // returned garbage (top-level), and the `where`-local case errored natively.
    for backend in [
        vec!["--backend", "interp"],
        vec!["--backend", "cranelift"],
        vec!["--release"],
    ] {
        let fx = fixture("over_application.axi");
        let mut args = backend.clone();
        args.push(&fx);
        let out = axionc().args(&args).output().unwrap();
        assert!(
            out.status.success(),
            "over-application should run ({backend:?}): {}",
            String::from_utf8_lossy(&out.stderr)
        );
        assert_eq!(String::from_utf8_lossy(&out.stdout), "150\n", "{backend:?}");
    }
}

#[test]
fn stdlib_list_functions_run_on_all_backends() {
    // The stdlib-growth batch — takeWhile, dropWhile, span, splitAt, concatMap, product,
    // and, or, lookup, findIndex — produces identical output on interp, cranelift and llvm.
    // (`dropWhile`/`span`/`splitAt` are VIEW functions — their list arg is auto-moved by
    // the borrow analysis so the aliased suffix isn't double-freed.)
    for backend in [
        vec!["--backend", "interp"],
        vec!["--backend", "cranelift"],
        vec!["--release"],
    ] {
        let fx = fixture("stdlib_list.axi");
        let mut args = backend.clone();
        args.push(&fx);
        let out = axionc().args(&args).output().unwrap();
        assert!(
            out.status.success(),
            "stdlib_list should run ({backend:?}): {}",
            String::from_utf8_lossy(&out.stderr)
        );
        assert_eq!(
            String::from_utf8_lossy(&out.stdout),
            "720\n10\n11\n21\n21\n12\ntrue\nfalse\n20\n2\n",
            "{backend:?}"
        );
    }
}

#[test]
fn show_containers_run_on_all_backends() {
    // Show for containers: List gets a manual `[1, 2, 3]` instance; Maybe /
    // Ordering / Trit derive Show. Element `show` keeps nested constructors
    // unparenthesised inside the brackets; nested lists nest their brackets.
    // interp == cranelift == llvm.
    for backend in [
        vec!["--backend", "interp"],
        vec!["--backend", "cranelift"],
        vec!["--release"],
    ] {
        let fx = fixture("show_containers.axi");
        let mut args = backend.clone();
        args.push(&fx);
        let out = axionc().args(&args).output().unwrap();
        assert!(
            out.status.success(),
            "show_containers should run ({backend:?}): {}",
            String::from_utf8_lossy(&out.stderr)
        );
        assert_eq!(
            String::from_utf8_lossy(&out.stdout),
            "[2, 4, 6, 8, 10]\nJust 3\n[Just 1, Nothing]\nLT\nTPlus\n[[1], [2, 3]]\n",
            "{backend:?}"
        );
    }
}

#[test]
fn show_tuples_run_on_all_backends() {
    // Show for tuples: the compiler synthesizes a monomorphic `show$(…)` per
    // concrete tuple shape (components shown at their own concrete types, so no
    // 2-param typeclass machinery). Covers constructor / list components and
    // tuples nested in a list / Maybe / another tuple. interp == cranelift == llvm.
    for backend in [
        vec!["--backend", "interp"],
        vec!["--backend", "cranelift"],
        vec!["--release"],
    ] {
        let fx = fixture("show_tuples.axi");
        let mut args = backend.clone();
        args.push(&fx);
        let out = axionc().args(&args).output().unwrap();
        assert!(
            out.status.success(),
            "show_tuples should run ({backend:?}): {}",
            String::from_utf8_lossy(&out.stderr)
        );
        assert_eq!(
            String::from_utf8_lossy(&out.stdout),
            "(1, 2)\n(1, 2, 3)\n(Just 5, 7)\n(1, [2, 3])\n[(1, 2), (3, 4)]\nJust (1, 2)\n((1, 2), (3, 4))\n",
            "{backend:?}"
        );
    }
}

#[test]
fn show_multiparam_run_on_all_backends() {
    // Show for multi-param derived data (Either + user 2/3-param types): the
    // compiler synthesizes a monomorphic show$Name$T1$T2 from the data decl, each
    // field at its own concrete type — fixing the 2-param dispatch bug (`Right
    // True` used to run showInt on a Bool). interp == cranelift == llvm.
    for backend in [
        vec!["--backend", "interp"],
        vec!["--backend", "cranelift"],
        vec!["--release"],
    ] {
        let fx = fixture("show_multiparam.axi");
        let mut args = backend.clone();
        args.push(&fx);
        let out = axionc().args(&args).output().unwrap();
        assert!(
            out.status.success(),
            "show_multiparam should run ({backend:?}): {}",
            String::from_utf8_lossy(&out.stderr)
        );
        assert_eq!(
            String::from_utf8_lossy(&out.stdout),
            "Right true\n[Left 1, Right false]\nTri 1 false 2\nBoth 9 true\nPair (Right false) (Just 4)\nPair (1, 2) true\n",
            "{backend:?}"
        );
    }
}

#[test]
fn eqord_multiparam_run_on_all_backends() {
    // Eq/Ord over multi-param derived data (Pair, Eit): synthesized monomorphically
    // per instantiation, each field compared at its own concrete type — fixing the
    // 2-param dispatch bug (interp errored on Bool `==`; native compared list
    // pointers). `eq nested1 nested2` = true proves STRUCTURAL (not pointer)
    // equality. interp == cranelift == llvm.
    for backend in [
        vec!["--backend", "interp"],
        vec!["--backend", "cranelift"],
        vec!["--release"],
    ] {
        let fx = fixture("eqord_multiparam.axi");
        let mut args = backend.clone();
        args.push(&fx);
        let out = axionc().args(&args).output().unwrap();
        assert!(
            out.status.success(),
            "eqord_multiparam should run ({backend:?}): {}",
            String::from_utf8_lossy(&out.stderr)
        );
        assert_eq!(
            String::from_utf8_lossy(&out.stdout),
            "false\ntrue\nfalse\ntrue\ntrue\n",
            "{backend:?}"
        );
    }
}

#[test]
fn handwritten_multiparam_instances_run_on_all_backends() {
    // Hand-written (non-derived) `(Show a, Show b) =>` / `(Eq a, Eq b) =>`
    // instances specialize natively now that the monomorphizer keys on a VECTOR of
    // constraint vars. Each method use dispatches at its OWN var's type — including
    // reversed arg order (`Pair Bool Int`) and a parametric field (`List Int`).
    // interp == cranelift == llvm.
    for backend in [
        vec!["--backend", "interp"],
        vec!["--backend", "cranelift"],
        vec!["--release"],
    ] {
        let fx = fixture("handwritten_multiparam.axi");
        let mut args = backend.clone();
        args.push(&fx);
        let out = axionc().args(&args).output().unwrap();
        assert!(
            out.status.success(),
            "handwritten_multiparam should run ({backend:?}): {}",
            String::from_utf8_lossy(&out.stderr)
        );
        assert_eq!(
            String::from_utf8_lossy(&out.stdout),
            "<7 | true>\n<false | 42>\n<[1, 2] | true>\ntrue\nfalse\n",
            "{backend:?}"
        );
    }
}

#[test]
fn recursive_instances_run_on_all_backends() {
    // Recursive hand-written instances that recurse via a direct method call on
    // their own type (`show t` where `t : Bin a`) now specialize natively —
    // including multi-param (`Two a b`) and recursion THROUGH a container (rose
    // tree). Previously interp-only. interp == cranelift == llvm.
    for backend in [
        vec!["--backend", "interp"],
        vec!["--backend", "cranelift"],
        vec!["--release"],
    ] {
        let fx = fixture("recursive_instances.axi");
        let mut args = backend.clone();
        args.push(&fx);
        let out = axionc().args(&args).output().unwrap();
        assert!(
            out.status.success(),
            "recursive_instances should run ({backend:?}): {}",
            String::from_utf8_lossy(&out.stderr)
        );
        assert_eq!(
            String::from_utf8_lossy(&out.stdout),
            "((.1.)2(.3.))\ntrue\nL1-trueL2\n1[2[], 3[4[]]]\n",
            "{backend:?}"
        );
    }
}

#[test]
fn list_deconstruct_runs_on_all_backends() {
    // Safe list deconstruction: uncons/head/tail/last. `uncons` yields head + rest
    // (nothing aliased); head/tail/last drop the unreturned part (`%1`-inferred);
    // `Nothing` on empty; composes with drop/map. interp == cranelift == llvm.
    for backend in [
        vec!["--backend", "interp"],
        vec!["--backend", "cranelift"],
        vec!["--release"],
    ] {
        let fx = fixture("list_deconstruct.axi");
        let mut args = backend.clone();
        args.push(&fx);
        let out = axionc().args(&args).output().unwrap();
        assert!(
            out.status.success(),
            "list_deconstruct should run ({backend:?}): {}",
            String::from_utf8_lossy(&out.stderr)
        );
        assert_eq!(
            String::from_utf8_lossy(&out.stdout),
            "Just (1, [2, 3])\nJust 7\nJust [8, 9]\nJust 6\nNothing\nJust 8\n",
            "{backend:?}"
        );
    }
}

#[test]
fn strings_text_run_on_all_backends() {
    // Char-level string processing: strLen/charAt/substr primitives + words/lines/
    // splitOn + Show String. Byte-oriented; charAt returns the byte codepoint (-1
    // out of bounds). interp == cranelift == llvm.
    for backend in [
        vec!["--backend", "interp"],
        vec!["--backend", "cranelift"],
        vec!["--release"],
    ] {
        let fx = fixture("strings_text.axi");
        let mut args = backend.clone();
        args.push(&fx);
        let out = axionc().args(&args).output().unwrap();
        assert!(
            out.status.success(),
            "strings_text should run ({backend:?}): {}",
            String::from_utf8_lossy(&out.stderr)
        );
        assert_eq!(
            String::from_utf8_lossy(&out.stdout),
            "5\n101\n-1\nworld\n[\"the\", \"quick\", \"brown\"]\n[\"a\", \"b\", \"c\"]\n[\"x\", \"\", \"y\"]\nround trip\n4\n",
            "{backend:?}"
        );
    }
}

#[test]
fn list_heap_reclaim_runs_on_all_backends() {
    // A List of HEAP elements (substr strings; nested lists) is deep-dropped by its
    // specialized destructor (axion_str_drop / the inner destructor) — leak-free.
    // interp == cranelift == llvm.
    for backend in [
        vec!["--backend", "interp"],
        vec!["--backend", "cranelift"],
        vec!["--release"],
    ] {
        let fx = fixture("list_heap_reclaim.axi");
        let mut args = backend.clone();
        args.push(&fx);
        let out = axionc().args(&args).output().unwrap();
        assert!(
            out.status.success(),
            "list_heap_reclaim should run ({backend:?}): {}",
            String::from_utf8_lossy(&out.stderr)
        );
        assert_eq!(String::from_utf8_lossy(&out.stdout), "25\n", "{backend:?}");
    }
}

#[test]
fn data_heap_field_runs_on_all_backends() {
    // A data type with a field whose type has heap elements (List String) deep-drops
    // those elements via the mono destructor (axion_drop_List$String) — leak-free.
    for backend in [
        vec!["--backend", "interp"],
        vec!["--backend", "cranelift"],
        vec!["--release"],
    ] {
        let fx = fixture("data_heap_field.axi");
        let mut args = backend.clone();
        args.push(&fx);
        let out = axionc().args(&args).output().unwrap();
        assert!(
            out.status.success(),
            "data_heap_field should run ({backend:?}): {}",
            String::from_utf8_lossy(&out.stderr)
        );
        assert_eq!(String::from_utf8_lossy(&out.stdout), "10\n", "{backend:?}");
    }
}

#[test]
fn user_operator_runs_on_all_backends() {
    // A user-defined symbolic operator (`(<+>) a b = …`) used infix (`a <+> b`)
    // lowers to a plain function call — like a backtick-infix — so all three backends
    // handle it identically. Exercises an infix chain (left-assoc), a second custom
    // operator (`|>`), and the operator as a first-class value (`applyOp (<+>) …`).
    // `main` = 70.
    for backend in [
        vec!["--backend", "interp"],
        vec!["--backend", "cranelift"],
        vec!["--release"],
    ] {
        let fx = fixture("user_operator.axi");
        let mut args = backend.clone();
        args.push(&fx);
        let out = axionc().args(&args).output().unwrap();
        assert!(
            out.status.success(),
            "user_operator should run ({backend:?}): {}",
            String::from_utf8_lossy(&out.stderr)
        );
        assert_eq!(String::from_utf8_lossy(&out.stdout), "70\n", "{backend:?}");
    }
}

#[test]
fn operator_fixity_runs_on_all_backends() {
    // `infixl 6 <+>` / `infixr 5 <>` declarations drive precedence + associativity in the
    // shared precedence climber: `1 <> 2 <+> 3` groups as `1 <> (2 <+> 3)` and
    // `10 <> 3 <> 2` as `10 <> (3 <> 2)` — result 5 (the default infixl-9 parse would give
    // 7). All three backends agree.
    for backend in [
        vec!["--backend", "interp"],
        vec!["--backend", "cranelift"],
        vec!["--release"],
    ] {
        let fx = fixture("operator_fixity.axi");
        let mut args = backend.clone();
        args.push(&fx);
        let out = axionc().args(&args).output().unwrap();
        assert!(
            out.status.success(),
            "operator_fixity should run ({backend:?}): {}",
            String::from_utf8_lossy(&out.stderr)
        );
        assert_eq!(String::from_utf8_lossy(&out.stdout), "5\n", "{backend:?}");
    }
}

#[test]
fn undefined_operator_is_rejected_ax0101() {
    // A symbolic operator with no definition is an unbound name — the scope check
    // reports AX0101 at compile time (not a runtime "name not found").
    let out = axionc()
        .args(["--check", &fixture("undefined_operator.axi")])
        .output()
        .unwrap();
    assert!(!out.status.success());
    let text = String::from_utf8_lossy(&out.stdout);
    assert!(text.contains("AX0101"), "expected AX0101, output: {text}");
}

#[test]
fn user_view_function_auto_moves_and_runs_on_all_backends() {
    // A USER-defined view function (returns a suffix aliasing its list) is auto-detected
    // by the borrow analysis and its list is MOVED — so it doesn't double-free natively,
    // without any manual registration. Before the auto-move it aborted on
    // cranelift/llvm ("double free detected").
    for backend in [
        vec!["--backend", "interp"],
        vec!["--backend", "cranelift"],
        vec!["--release"],
    ] {
        let fx = fixture("user_view.axi");
        let mut args = backend.clone();
        args.push(&fx);
        let out = axionc().args(&args).output().unwrap();
        assert!(
            out.status.success(),
            "user view function should run ({backend:?}): {}",
            String::from_utf8_lossy(&out.stderr)
        );
        assert_eq!(String::from_utf8_lossy(&out.stdout), "11\n", "{backend:?}");
    }
}

#[test]
fn integer_bignum_factorial_is_exact() {
    // §Listing 1.4: `Integer` is arbitrary-precision — `factorial 50` (65 digits)
    // overflows i64 but is exact with the bignum, on ALL three executors (interp,
    // cranelift, and llvm/--release each with their own runtime bignum). Bare
    // literals default into Integer by type.
    let expect = "30414093201713378043612608166064768844377641568960512000000000000\n";
    for backend in [
        vec!["--backend", "interp"],
        vec!["--backend", "cranelift"],
        vec!["--release"],
    ] {
        let fx = fixture("integer_factorial.axi");
        let mut args = backend.clone();
        args.push(&fx);
        let out = axionc().args(&args).output().unwrap();
        assert!(
            out.status.success(),
            "Integer factorial should run ({backend:?}): {}",
            String::from_utf8_lossy(&out.stderr)
        );
        assert_eq!(String::from_utf8_lossy(&out.stdout), expect, "{backend:?}");
    }
}

#[test]
fn integer_literal_exceeding_i64() {
    // §Listing 1.4: a literal larger than i64 (`12345678901234567890`) lexes as a
    // big literal and desugars to an arbitrary-precision Integer. Squared exactly on
    // all three executors.
    let expect = "152415787532388367501905199875019052100\n";
    for backend in [
        vec!["--backend", "interp"],
        vec!["--backend", "cranelift"],
        vec!["--release"],
    ] {
        let fx = fixture("integer_big_literal.axi");
        let mut args = backend.clone();
        args.push(&fx);
        let out = axionc().args(&args).output().unwrap();
        assert!(
            out.status.success(),
            "big literal should run ({backend:?}): {}",
            String::from_utf8_lossy(&out.stderr)
        );
        assert_eq!(String::from_utf8_lossy(&out.stdout), expect, "{backend:?}");
    }
}

#[test]
fn integer_is_first_class() {
    // Integration: `Integer` builtins as VALUES (`map fromInt`), a `List Integer`
    // through `map`/`foldr`, and the `Show Integer` instance (`show`, not the raw
    // `showInteger`). Sum of squares 1..10 = 385, on all three executors.
    for backend in [
        vec!["--backend", "interp"],
        vec!["--backend", "cranelift"],
        vec!["--release"],
    ] {
        let fx = fixture("integer_first_class.axi");
        let mut args = backend.clone();
        args.push(&fx);
        let out = axionc().args(&args).output().unwrap();
        assert!(
            out.status.success(),
            "Integer first-class should run ({backend:?}): {}",
            String::from_utf8_lossy(&out.stderr)
        );
        assert_eq!(String::from_utf8_lossy(&out.stdout), "385\n", "{backend:?}");
    }
}

#[test]
fn parmap_workers_compute_integer() {
    // Integration: session workers doing arbitrary-precision compute (`Integer`,
    // via the `fromInt` builtin) inside the native session state machine, collected
    // by parMap. 4 × factorial 20 = 9731608032706560000 (overflows i64, exact with
    // Integer). All three executors agree — regression guard for the SessGen builtin
    // support the stress test uncovered.
    let expect = "9731608032706560000\n";
    for backend in [
        vec!["--backend", "interp"],
        vec!["--backend", "cranelift"],
        vec!["--release"],
    ] {
        let fx = fixture("session_parmap_integer.axi");
        let mut args = backend.clone();
        args.push(&fx);
        let out = axionc().args(&args).output().unwrap();
        assert!(
            out.status.success(),
            "parMap+Integer should run ({backend:?}): {}",
            String::from_utf8_lossy(&out.stderr)
        );
        assert_eq!(String::from_utf8_lossy(&out.stdout), expect, "{backend:?}");
    }
}

#[test]
fn integer_bignum_divmod() {
    // §Listing 1.4: `div`/`mod` overloaded (Integral) over Int AND Integer, on all
    // three executors. Integer 10^30 /% 7 (arbitrary precision) + Int 100 /% 7 (the
    // Int `div` that did not exist before). Truncated.
    let expect = "142857142857142857142857142857\n1\n14\n2\n";
    for backend in [
        vec!["--backend", "interp"],
        vec!["--backend", "cranelift"],
        vec!["--release"],
    ] {
        let fx = fixture("integer_divmod.axi");
        let mut args = backend.clone();
        args.push(&fx);
        let out = axionc().args(&args).output().unwrap();
        assert!(
            out.status.success(),
            "Integer divmod should run ({backend:?}): {}",
            String::from_utf8_lossy(&out.stderr)
        );
        assert_eq!(String::from_utf8_lossy(&out.stdout), expect, "{backend:?}");
    }
}

#[test]
fn nested_polymorphic_container_deep_drops() {
    // poly-drop Phase 4: a `List (List Int)` (built by `map (range 1) …`) is dropped
    // at its concrete type so the inner lists are reclaimed (was a leak). This pins
    // the value (10) on interp + cranelift; scripts/sanitize.sh pins leak-freedom.
    for backend in [vec!["--backend", "interp"], vec!["--backend", "cranelift"]] {
        let fx = fixture("poly_nested_list.axi");
        let mut args = backend.clone();
        args.push(&fx);
        let out = axionc().args(&args).output().unwrap();
        assert!(
            out.status.success(),
            "nested container should run ({backend:?}): {}",
            String::from_utf8_lossy(&out.stderr)
        );
        assert_eq!(String::from_utf8_lossy(&out.stdout), "10\n", "{backend:?}");
    }
}

#[test]
fn typo_gets_a_machine_applicable_fix() {
    // Teaching diagnostics (§8): a mis-spelled name yields AX0101 with a "did you
    // mean" suggestion in text, and a machine-applicable `fixes` entry in JSON that
    // an editor can auto-apply.
    let check = axionc()
        .args(["--check", &fixture("typo_suggestion.axi")])
        .output()
        .unwrap();
    assert!(!check.status.success(), "typo should fail --check");
    let text = String::from_utf8_lossy(&check.stdout);
    assert!(text.contains("AX0101"), "expected AX0101, got: {text}");
    assert!(
        text.contains("did you mean `length`?"),
        "expected typo suggestion, got: {text}"
    );
    // JSON carries the fix (span + replacement) for editors to auto-apply.
    let json = axionc()
        .args(["--emit", "json", &fixture("typo_suggestion.axi")])
        .output()
        .unwrap();
    let j = String::from_utf8_lossy(&json.stdout);
    assert!(j.contains("\"fix\""), "expected a `fix` in JSON: {j}");
    assert!(
        j.contains("\"replacement\": \"length\""),
        "expected replacement=length in JSON: {j}"
    );
}

#[test]
fn level_ceiling_enforced_ax0500() {
    // §8 progressive disclosure: `{-# LEVEL Ln #-}` caps what a declaration may
    // WRITE. An L1 decl (`%1` / `Buffer`) under an L0 ceiling is AX0500…
    let bad = axionc()
        .args(["--check", &fixture("level_exceeded.axi")])
        .output()
        .unwrap();
    assert!(!bad.status.success(), "L1 decl under L0 ceiling should fail");
    let text = String::from_utf8_lossy(&bad.stdout);
    assert!(text.contains("AX0500"), "expected AX0500, got: {text}");
    assert!(text.contains("L1"), "diagnostic should name the level, got: {text}");

    // …but the same decl under an L1 ceiling is fine…
    let ok = axionc().args(["--check", &fixture("level_ok.axi")]).output().unwrap();
    assert!(ok.status.success(), "L1 decl under L1 ceiling should pass");

    // …and with no pragma there is no ceiling to enforce…
    let np = axionc()
        .args(["--check", &fixture("level_no_pragma.axi")])
        .output()
        .unwrap();
    assert!(np.status.success(), "no pragma => no ceiling");

    // …and CALLING a user function never raises the caller's level: the ceiling
    // governs what a decl writes, not what it calls (an L0 module may depend on a
    // higher-level library).
    let call = axionc()
        .args(["--check", &fixture("level_call_does_not_raise.axi")])
        .output()
        .unwrap();
    assert!(call.status.success(), "a plain call must not raise the level");
}

#[test]
fn parser_recovers_at_declaration_boundaries() {
    // §8 resilience: a malformed declaration is reported (AX0100), but the parser
    // recovers at the next declaration boundary so a valid sibling is still analysed
    // — here `good`'s use of an unbound name surfaces AX0101. Before recovery the
    // syntax error would have aborted the whole parse and hidden it.
    let out = axionc()
        .args(["--check", &fixture("recover_partial.axi")])
        .output()
        .unwrap();
    assert!(!out.status.success(), "a file with errors should fail --check");
    let text = String::from_utf8_lossy(&out.stdout);
    assert!(text.contains("AX0100"), "expected the syntax error, got: {text}");
    assert!(
        text.contains("AX0101"),
        "the valid sibling must still be analysed past the broken decl, got: {text}"
    );
}

#[test]
fn explain_covers_every_emitted_code() {
    // Every AXnnnn the compiler can emit has an `--explain` entry (§8); an unknown
    // code is rejected. (Regression guard for the newly-added 0202/0203/0411/0500/09xx.)
    for code in [
        "AX0001", "AX0002", "AX0101", "AX0202", "AX0203", "AX0411", "AX0500", "AX0900", "AX0901",
    ] {
        let out = axionc().args(["--explain", code]).output().unwrap();
        assert!(out.status.success(), "--explain {code} should succeed");
        assert!(
            !String::from_utf8_lossy(&out.stdout).trim().is_empty(),
            "--explain {code} should print text"
        );
    }
    let unknown = axionc().args(["--explain", "AX9999"]).output().unwrap();
    assert!(!unknown.status.success(), "--explain of unknown code should fail");
}

#[test]
fn use_after_consume_is_rejected_ax0001() {
    let out = axionc()
        .args(["--check", &fixture("use_after_consume.axi")])
        .output()
        .unwrap();
    assert!(!out.status.success(), "use-after-consume should fail");
    let text = String::from_utf8_lossy(&out.stdout);
    assert!(text.contains("AX0001"), "expected AX0001, output: {text}");
}

#[test]
fn session_well_typed_protocols_are_accepted() {
    // §6: a `Send Int End` protocol (send+close) and a `Recv Int End`
    // (recv+close) follow the session type → accepted by `check_sessions`.
    for fx in ["session_ok.axi", "session_recv_ok.axi"] {
        let out = axionc().args(["--check", &fixture(fx)]).output().unwrap();
        assert!(
            out.status.success(),
            "{fx} should pass: {}",
            String::from_utf8_lossy(&out.stdout)
        );
    }
}

#[test]
fn session_wrong_operation_is_rejected_ax0300() {
    // does `recv` on an endpoint whose protocol is `Send …` → violates fidelity.
    let out = axionc()
        .args(["--check", &fixture("session_bad_op.axi")])
        .output()
        .unwrap();
    assert!(!out.status.success(), "wrong session op should fail");
    let text = String::from_utf8_lossy(&out.stdout);
    assert!(text.contains("AX0300"), "expected AX0300, output: {text}");
}

#[test]
fn session_incomplete_protocol_is_rejected_ax0301() {
    // sends but never `close`s → the endpoint does not complete the protocol.
    let out = axionc()
        .args(["--check", &fixture("session_incomplete.axi")])
        .output()
        .unwrap();
    assert!(!out.status.success(), "incomplete protocol should fail");
    let text = String::from_utf8_lossy(&out.stdout);
    assert!(text.contains("AX0301"), "expected AX0301, output: {text}");
}

#[test]
fn session_program_runs_concurrently() {
    // §11: a session program actually RUNS — the `bound` opens the nursery, the
    // cooperative scheduler forks the worker and does the ping-pong (21 → 42)
    // without deadlock, returning 42.
    let out = axionc()
        .arg(fixture("session_run_pingpong.axi"))
        .output()
        .unwrap();
    assert!(
        out.status.success(),
        "should run: {}",
        String::from_utf8_lossy(&out.stderr)
    );
    assert_eq!(String::from_utf8_lossy(&out.stdout), "42\n");
}

#[test]
fn parmap_matches_hand_unrolled_forkjoin() {
    // §9: `parMap worker (replicate 4 25)` is the structured-concurrency combinator
    // form of the hand-unrolled four-worker fork-join in `session_run_parfib.axi`.
    // Both compute 4 × fib 25 = 300100 on the cooperative interpreter.
    let parmap = axionc()
        .arg(fixture("session_run_parmap.axi"))
        .output()
        .unwrap();
    assert!(
        parmap.status.success(),
        "parMap should run: {}",
        String::from_utf8_lossy(&parmap.stderr)
    );
    assert_eq!(String::from_utf8_lossy(&parmap.stdout), "300100\n");
    // it agrees with the repetitive version it replaces.
    let unrolled = axionc()
        .arg(fixture("session_run_parfib.axi"))
        .output()
        .unwrap();
    assert_eq!(
        String::from_utf8_lossy(&parmap.stdout),
        String::from_utf8_lossy(&unrolled.stdout),
        "parMap diverges from the hand-unrolled fork-join"
    );
}

#[test]
fn parmap_runs_natively_in_parallel() {
    // §9, native M:N: `parMap` lowers each worker to a defunctionalized state machine
    // (`worker$step`) driven by `axion_par_map`, which forks the workers onto the
    // thread pool. Under `--backend cranelift` it agrees with the interpreter (300100)
    // and the hand-unrolled `bound` fork-join — now the workers run on real threads.
    let native = axionc()
        .args(["--backend", "cranelift", &fixture("session_run_parmap.axi")])
        .output()
        .unwrap();
    assert!(
        native.status.success(),
        "parMap should run natively: {}",
        String::from_utf8_lossy(&native.stderr)
    );
    assert_eq!(String::from_utf8_lossy(&native.stdout), "300100\n");
    let interp = axionc()
        .arg(fixture("session_run_parmap.axi"))
        .output()
        .unwrap();
    assert_eq!(
        String::from_utf8_lossy(&native.stdout),
        String::from_utf8_lossy(&interp.stdout),
        "parMap: native and interpreter diverge"
    );
}

#[test]
fn parmap_over_range_and_reduce_run() {
    // §9: parMap over a COMPUTED list of DISTINCT inputs (`range 15 22`), and an
    // inline `foldr` reduce over the replies (so `parMapReduce` needs no prelude
    // entry). Both run native (cranelift) in agreement with the interpreter.
    for (fx, expected) in [
        ("session_run_parmap_range.axi", "45381\n"),  // sum of fib 15..22
        ("session_run_parmap_reduce.axi", "17711\n"), // max of fib 15..22 = fib 22
    ] {
        let native = axionc()
            .args(["--backend", "cranelift", &fixture(fx)])
            .output()
            .unwrap();
        assert!(
            native.status.success(),
            "{fx} should run: {}",
            String::from_utf8_lossy(&native.stderr)
        );
        assert_eq!(String::from_utf8_lossy(&native.stdout), expected, "{fx}");
        let interp = axionc().arg(fixture(fx)).output().unwrap();
        assert_eq!(
            String::from_utf8_lossy(&interp.stdout),
            expected,
            "{fx}: interpreter diverges"
        );
    }
}

#[test]
fn parmap_heap_reply_computes_correctly() {
    // §9 LIMITATION (documented): a worker returning a heap payload (`List Int`)
    // computes the correct VALUE on every executor (45), but the inner reply lists
    // leak — parMap keys its result as the flat `axion_drop_List`. This test pins
    // the correctness; the leak is documented in the fixture header + docs §11b.
    for backend in [vec!["--backend", "cranelift"], vec!["--backend", "interp"]] {
        let mut args = backend.clone();
        let fx = fixture("session_run_parmap_heap.axi");
        args.push(&fx);
        let out = axionc().args(&args).output().unwrap();
        assert!(
            out.status.success(),
            "heap-reply parMap should run ({backend:?}): {}",
            String::from_utf8_lossy(&out.stderr)
        );
        assert_eq!(String::from_utf8_lossy(&out.stdout), "45\n", "{backend:?}");
    }
}

#[test]
fn stateful_server_loop_runs() {
    // §6: a recursive `offer` server that threads accumulator state across the loop
    // (`server (acc + n) d3`) type-checks AND runs. `spawn (server 0)` seeds the
    // accumulator, each `Add` folds a value into it, `Total` returns the running sum
    // (10 + 20 = 30). Native (cranelift) agrees with the interpreter.
    let native = axionc()
        .args(["--backend", "cranelift", &fixture("session_stateful_server.axi")])
        .output()
        .unwrap();
    assert!(
        native.status.success(),
        "stateful server loop should run: {}",
        String::from_utf8_lossy(&native.stderr)
    );
    assert_eq!(String::from_utf8_lossy(&native.stdout), "30\n");
    let interp = axionc()
        .arg(fixture("session_stateful_server.axi"))
        .output()
        .unwrap();
    assert_eq!(
        String::from_utf8_lossy(&interp.stdout),
        "30\n",
        "interpreter diverges from native on the stateful server loop"
    );
}

#[test]
fn session_pingpong_runs_natively() {
    // §11, Layer 2 (native sessions): the ping-pong compiles to a cooperative
    // state machine (`main$step`/`worker$step` over the `axion_sess_*` runtime) and
    // runs under `--backend cranelift`, agreeing with the interpreter (both → 42).
    // `spawn`/`send`/`recv`/`close` lowered to native; the only suspension point is
    // a `recv` on an empty channel (defunctionalized continuation).
    let native = axionc()
        .args([
            "--backend",
            "cranelift",
            &fixture("session_run_pingpong.axi"),
        ])
        .output()
        .unwrap();
    assert!(
        native.status.success(),
        "native session should run: {}",
        String::from_utf8_lossy(&native.stderr)
    );
    assert_eq!(String::from_utf8_lossy(&native.stdout), "42\n");
    let interp = axionc()
        .arg(fixture("session_run_pingpong.axi"))
        .output()
        .unwrap();
    assert_eq!(
        String::from_utf8_lossy(&interp.stdout),
        String::from_utf8_lossy(&native.stdout),
        "native and interpreter diverge on the session ping-pong"
    );
}

#[test]
fn session_choice_and_cancel_run_natively() {
    // §6/§7, Layer 2a (native choice + cancellation): `select`/`case offer` and
    // `cancel` lower to native. `offer` is a label suspension that dispatches to
    // the matching branch (whose body may hold further `recv` suspensions); `cancel`
    // sends the `Closed` label (T5). Both agree with the interpreter under
    // `--backend cranelift`: session_run_offer → 7, session_run_cancel → 5.
    for (fx, expected) in [
        ("session_run_offer.axi", "7\n"),
        ("session_run_cancel.axi", "5\n"),
    ] {
        let native = axionc()
            .args(["--backend", "cranelift", &fixture(fx)])
            .output()
            .unwrap();
        assert!(
            native.status.success(),
            "{fx} native should run: {}",
            String::from_utf8_lossy(&native.stderr)
        );
        assert_eq!(String::from_utf8_lossy(&native.stdout), expected, "{fx}");
        let interp = axionc().arg(fixture(fx)).output().unwrap();
        assert_eq!(
            String::from_utf8_lossy(&interp.stdout),
            String::from_utf8_lossy(&native.stdout),
            "{fx}: native and interpreter diverge"
        );
    }
}

#[test]
fn session_richer_shapes_run_natively() {
    // Broader coverage of the native session generator, agreeing with the interp:
    // - two concurrent children + TWO `recv` suspensions in `main` (the multi-
    //   suspension resume dispatch must save/restore `x` across the second recv) → 42;
    // - a 3-label external choice where the result observes the selected branch
    //   (`Fast`, the middle of three), proving a real 3-way tag dispatch → 2;
    // - a compute-heavy worker calling a native function (`fib n`) in value
    //   position — real work between channel ops → 6765;
    // - four compute-heavy workers whose `fib` calls run in PARALLEL on the --dev
    //   M:N scheduler (deterministic result, session types ⇒ no races) → 300100.
    for (fx, expected) in [
        ("session_run_twospawn.axi", "42\n"),
        ("session_run_choice3.axi", "2\n"),
        ("session_run_fib.axi", "6765\n"),
        ("session_run_parfib.axi", "300100\n"),
    ] {
        let native = axionc()
            .args(["--backend", "cranelift", &fixture(fx)])
            .output()
            .unwrap();
        assert!(
            native.status.success(),
            "{fx} native should run: {}",
            String::from_utf8_lossy(&native.stderr)
        );
        assert_eq!(String::from_utf8_lossy(&native.stdout), expected, "{fx}");
        let interp = axionc().arg(fixture(fx)).output().unwrap();
        assert_eq!(
            String::from_utf8_lossy(&interp.stdout),
            String::from_utf8_lossy(&native.stdout),
            "{fx}: native and interpreter diverge"
        );
    }
}

#[test]
fn recursive_session_server_loop_runs() {
    // §6 recursion (server loops): a worker with a RECURSIVE session type
    // `Rec (Offer (More (Recv Int (Send Int Loop))) (Closed End))` loops via a tail
    // call `worker d'` — the checker accepts it (the recursion continues the
    // protocol instead of reaching `close`, relaxing AX0301), and it runs in ALL
    // three executors: the interpreter re-enters the body as a tail call, and the
    // native backends lower the tail to a re-queue (status 2) that re-dispatches the
    // state machine at the loop head. Three rounds 10/20/30 → 11+21+31 = 63.
    let fx = fixture("session_run_server.axi");
    let check = axionc().args(["--check", &fx]).output().unwrap();
    assert!(
        check.status.success(),
        "recursive session should typecheck: {}",
        String::from_utf8_lossy(&check.stdout)
    );
    let interp = axionc().arg(&fx).output().unwrap();
    assert!(
        interp.status.success(),
        "server loop should run: {}",
        String::from_utf8_lossy(&interp.stderr)
    );
    assert_eq!(String::from_utf8_lossy(&interp.stdout), "63\n");
    let native = axionc()
        .args(["--backend", "cranelift", &fx])
        .output()
        .unwrap();
    assert!(
        native.status.success(),
        "server loop should run natively: {}",
        String::from_utf8_lossy(&native.stderr)
    );
    assert_eq!(
        String::from_utf8_lossy(&native.stdout),
        "63\n",
        "native and interpreter diverge on the server loop"
    );
}

#[test]
fn recursive_session_wrong_state_is_rejected_ax0300() {
    // A recursive tail call must continue the protocol at the function's parameter
    // session state; recursing with an endpoint at the wrong state → AX0300.
    let out = axionc()
        .args(["--check", &fixture("session_rec_mismatch.axi")])
        .output()
        .unwrap();
    assert!(
        !out.status.success(),
        "recursion at the wrong state should fail"
    );
    let text = String::from_utf8_lossy(&out.stdout);
    assert!(text.contains("AX0300"), "expected AX0300, output: {text}");
}

#[test]
fn session_out_of_subset_fails_natively_not_silently() {
    // Graceful-failure contract: sessions bypass the native-candidacy filter, so a
    // session shape outside the native subset must be REJECTED by native codegen,
    // never silently miscompiled. Here the block value is a `case` expression: the
    // interpreter is correct (r=42 → 100), and `--backend cranelift` fails loudly.
    let fx = fixture("session_native_unsupported.axi");
    let interp = axionc().arg(&fx).output().unwrap();
    assert_eq!(
        String::from_utf8_lossy(&interp.stdout),
        "100\n",
        "interpreter should still run the out-of-subset session"
    );
    let native = axionc()
        .args(["--backend", "cranelift", &fx])
        .output()
        .unwrap();
    assert!(
        !native.status.success(),
        "out-of-subset session must fail natively, not miscompile"
    );
    assert!(
        String::from_utf8_lossy(&native.stderr).contains("outside the native subset"),
        "expected a clear 'outside the native subset' message, got: {}",
        String::from_utf8_lossy(&native.stderr)
    );
}

#[test]
fn session_offer_and_cancel_run() {
    // §6/§7: external choice (`offer`) and cancellation (`cancel` → `Closed`)
    // execute. One: `select Live` → the worker dispatches to the Live branch (→7).
    // Other: `cancel` → the worker receives `Closed` and takes the cancel branch (→5).
    for (fx, expected) in [
        ("session_run_offer.axi", "7\n"),
        ("session_run_cancel.axi", "5\n"),
    ] {
        let out = axionc().arg(fixture(fx)).output().unwrap();
        assert!(
            out.status.success(),
            "{fx} should run: {}",
            String::from_utf8_lossy(&out.stderr)
        );
        assert_eq!(String::from_utf8_lossy(&out.stdout), expected, "{fx}");
    }
}

#[test]
fn session_choice_and_closed_exhaustiveness() {
    // §6/§9: internal choice (⊕) and the exhaustiveness of the `Closed` branch (T5).
    let ok = |fx: &str| {
        let out = axionc().args(["--check", &fixture(fx)]).output().unwrap();
        assert!(
            out.status.success(),
            "{fx} should pass: {}",
            String::from_utf8_lossy(&out.stdout)
        );
    };
    let reject = |fx: &str, code: &str| {
        let out = axionc().args(["--check", &fixture(fx)]).output().unwrap();
        assert!(!out.status.success(), "{fx} should fail");
        let text = String::from_utf8_lossy(&out.stdout);
        assert!(text.contains(code), "{fx}: expected {code}, output: {text}");
    };
    ok("session_select_ok.axi"); // select of a valid label (⊕)
    ok("session_offer_ok.axi"); // Offer with a Closed branch (T5)
    reject("session_select_bad.axi", "AX0300"); // nonexistent label
    reject("session_offer_no_closed.axi", "AX0303"); // Offer without Closed in the type (T5)
    reject("session_offer_incomplete.axi", "AX0304"); // case omits an Offer branch
    reject("session_spawn_capture.axi", "AX0305"); // spawn captures an endpoint (tree)
}

#[test]
fn bound_confined_nursery_is_accepted() {
    // §9: a `bound` that creates endpoints and consumes them in there (nothing
    // escapes) is accepted — tree topology, deadlock-free by construction.
    let out = axionc()
        .args(["--check", &fixture("bound_ok.axi")])
        .output()
        .unwrap();
    assert!(
        out.status.success(),
        "confined nursery should pass: {}",
        String::from_utf8_lossy(&out.stdout)
    );
}

#[test]
fn bound_endpoint_escape_is_rejected_ax0302() {
    // returning an endpoint from the `bound` would break the acyclic topology → AX0302.
    let out = axionc()
        .args(["--check", &fixture("bound_escape.axi")])
        .output()
        .unwrap();
    assert!(!out.status.success(), "endpoint escape should fail");
    let text = String::from_utf8_lossy(&out.stdout);
    assert!(text.contains("AX0302"), "expected AX0302, output: {text}");
}

#[test]
fn linear_use_once_is_accepted() {
    let out = axionc()
        .args(["--check", &fixture("use_once_ok.axi")])
        .output()
        .unwrap();
    assert!(out.status.success(), "single use should pass");
}

#[test]
fn dropped_linear_is_rejected_ax0002() {
    let out = axionc()
        .args(["--check", &fixture("drop_linear.axi")])
        .output()
        .unwrap();
    assert!(!out.status.success());
    let text = String::from_utf8_lossy(&out.stdout);
    assert!(text.contains("AX0002"), "expected AX0002, output: {text}");
}

#[test]
fn listing_2_1_typechecks() {
    // 04 (Listing 2.1): record with a linear field + record update,
    // param Process %1 consumed once. No main -> --check only.
    let out = axionc()
        .args(["--check", &example("04_process_inplace.axi")])
        .output()
        .unwrap();
    assert!(
        out.status.success(),
        "04 should compile; output: {}",
        String::from_utf8_lossy(&out.stdout)
    );
}

#[test]
fn records_construct_update_and_select() {
    let out = axionc().arg(fixture("record_run.axi")).output().unwrap();
    assert!(out.status.success());
    assert_eq!(String::from_utf8_lossy(&out.stdout), "99\n");
}

#[test]
fn heap_alias_into_two_records_is_rejected_ax0001() {
    // aliasing a heap value into two owned positions (`let x = …; a = W x; b = W x`)
    // is a contraction — deep-dropping both would double-free. Rejected at compile
    // time (AX0001), so native never runs it.
    let out = axionc()
        .args(["--check", &fixture("heap_alias_rejected.axi")])
        .output()
        .unwrap();
    assert!(!out.status.success());
    let text = String::from_utf8_lossy(&out.stdout);
    assert!(text.contains("AX0001"), "expected AX0001, output: {text}");
}

#[test]
fn linear_record_used_twice_is_rejected_ax0001() {
    let out = axionc()
        .args(["--check", &fixture("record_use_twice.axi")])
        .output()
        .unwrap();
    assert!(!out.status.success());
    let text = String::from_utf8_lossy(&out.stdout);
    assert!(text.contains("AX0001"), "expected AX0001, output: {text}");
}

#[test]
fn indirect_heap_duplication_is_rejected_ax0001() {
    // The parameter contraction check saw only parameters, so a heap value could be
    // laundered past it and double-freed natively: through a `let` ALIAS
    // (`let z = xs in T z z`) or a `case`-EXTRACTED field binder
    // (`Vc y ys -> T (Vc y ys) (Vc y ys)`). Both are now rejected at compile time.
    let out = axionc()
        .args(["--check", &fixture("heap_duplication_indirect.axi")])
        .output()
        .unwrap();
    assert!(!out.status.success());
    let text = String::from_utf8_lossy(&out.stdout);
    assert!(text.contains("AX0001"), "expected AX0001, output: {text}");
}

#[test]
fn heap_value_duplicated_by_ownership_is_rejected_ax0001() {
    // `mk xs = Two xs xs` moves a borrowed HEAP list into two owned fields
    // (contraction) — previously accepted, then double-freed natively. The
    // linearity checker now rejects duplicating a heap value by ownership.
    let out = axionc()
        .args(["--check", &fixture("heap_duplication.axi")])
        .output()
        .unwrap();
    assert!(!out.status.success());
    let text = String::from_utf8_lossy(&out.stdout);
    assert!(text.contains("AX0001"), "expected AX0001, output: {text}");
}

#[test]
fn droppable_linear_unused_is_accepted_by_autodrop() {
    // Buf is droppable: dropping it without consuming is OK (Auto-Drop injects free).
    let out = axionc()
        .args(["--check", &fixture("drop_ok.axi")])
        .output()
        .unwrap();
    assert!(
        out.status.success(),
        "unconsumed droppable should be accepted; output: {}",
        String::from_utf8_lossy(&out.stdout)
    );
}

#[test]
fn autodrop_emits_injected_free() {
    let out = axionc()
        .args(["--emit", "drops", &fixture("drop_ok.axi")])
        .output()
        .unwrap();
    assert!(out.status.success());
    let text = String::from_utf8_lossy(&out.stdout);
    assert!(
        text.contains("free(b)") && text.contains("Buf"),
        "expected an injected free for 'b : Buf', output: {text}"
    );
}

#[test]
fn borrowing_a_linear_twice_is_accepted() {
    // Reading (borrowing) a %1 twice is allowed — it is not a contraction.
    let out = axionc()
        .args(["--check", &fixture("borrow_twice_ok.axi")])
        .output()
        .unwrap();
    assert!(
        out.status.success(),
        "two borrows should be accepted; output: {}",
        String::from_utf8_lossy(&out.stdout)
    );
}

#[test]
fn autodrop_death_point_is_the_last_read() {
    // free injected at the fine death point (after the last read), not at entry.
    let out = axionc()
        .args(["--emit", "drops", &fixture("borrow_twice_ok.axi")])
        .output()
        .unwrap();
    let text = String::from_utf8_lossy(&out.stdout);
    assert!(
        text.contains("free(x)") && text.contains("dies after the last read"),
        "expected drop at the last read, output: {text}"
    );
}

#[test]
fn structural_drop_makes_record_must_use_ax0002() {
    // Sess contains an Ep %1 field → must-use by structural propagation → AX0002.
    let out = axionc()
        .args(["--check", &fixture("struct_mustuse.axi")])
        .output()
        .unwrap();
    assert!(!out.status.success());
    let text = String::from_utf8_lossy(&out.stdout);
    assert!(text.contains("AX0002"), "expected AX0002, output: {text}");
}

#[test]
fn let_bound_droppable_is_autodropped() {
    let out = axionc()
        .args(["--emit", "drops", &fixture("let_drop.axi")])
        .output()
        .unwrap();
    assert!(out.status.success());
    let text = String::from_utf8_lossy(&out.stdout);
    assert!(
        text.contains("free(b2)"),
        "expected free(b2), output: {text}"
    );
}

#[test]
fn let_bound_must_use_is_rejected_ax0002() {
    let out = axionc()
        .args(["--check", &fixture("let_leak.axi")])
        .output()
        .unwrap();
    assert!(!out.status.success());
    let text = String::from_utf8_lossy(&out.stdout);
    assert!(
        text.contains("AX0002") && text.contains("s2"),
        "expected AX0002 on s2, output: {text}"
    );
}

#[test]
fn inplace_update_on_linear_base_reported() {
    // Listing 2.1: 'p { status = ... }' is the last live mention of 'p' (%1) →
    // in-place mutation (Linear Elision).
    let out = axionc()
        .args(["--emit", "inplace", &example("04_process_inplace.axi")])
        .output()
        .unwrap();
    assert!(out.status.success());
    let text = String::from_utf8_lossy(&out.stdout);
    assert!(
        text.contains("'p' mutated in-place"),
        "expected in-place update of p, output: {text}"
    );
}

#[test]
fn arena_escape_is_rejected_ax0003() {
    // A value allocated in a sub-arena, returned from withSubArena → AX0003.
    let out = axionc()
        .args(["--check", &fixture("arena_escape.axi")])
        .output()
        .unwrap();
    assert!(!out.status.success());
    let text = String::from_utf8_lossy(&out.stdout);
    assert!(text.contains("AX0003"), "expected AX0003, output: {text}");
}

#[test]
fn arena_promote_is_accepted() {
    // 'promote parent node' moves the value to the parent arena → it does not escape.
    let out = axionc()
        .args(["--check", &fixture("arena_promote_ok.axi")])
        .output()
        .unwrap();
    assert!(
        out.status.success(),
        "promote should be accepted; output: {}",
        String::from_utf8_lossy(&out.stdout)
    );
}

#[test]
fn arena_closure_capture_escape_is_rejected_ax0003() {
    // A closure that captures a sub-arena value and escapes → AX0003.
    let out = axionc()
        .args(["--check", &fixture("arena_capture.axi")])
        .output()
        .unwrap();
    assert!(!out.status.success());
    let text = String::from_utf8_lossy(&out.stdout);
    assert!(text.contains("AX0003"), "expected AX0003, output: {text}");
}

#[test]
fn arena_use_after_release_is_rejected_ax0005() {
    // A value allocated after a mark and used after arena_release → AX0005.
    let out = axionc()
        .args(["--check", &fixture("arena_mark_release.axi")])
        .output()
        .unwrap();
    assert!(!out.status.success());
    let text = String::from_utf8_lossy(&out.stdout);
    assert!(text.contains("AX0005"), "expected AX0005, output: {text}");
}

#[test]
fn arena_mark_used_before_release_is_accepted() {
    let out = axionc()
        .args(["--check", &fixture("arena_mark_ok.axi")])
        .output()
        .unwrap();
    assert!(
        out.status.success(),
        "use before release should be accepted; output: {}",
        String::from_utf8_lossy(&out.stdout)
    );
}

#[test]
fn arena_reset_nll_point_reported() {
    // NLL reset: the sub-arena's reset is injected after the last live mention
    // ('node', at the promotion), not at the lexical end.
    let out = axionc()
        .args(["--emit", "arenas", &fixture("arena_promote_ok.axi")])
        .output()
        .unwrap();
    assert!(out.status.success());
    let text = String::from_utf8_lossy(&out.stdout);
    assert!(
        text.contains("reset 'sub'") && text.contains("node"),
        "expected NLL reset of 'sub' after 'node', output: {text}"
    );
}

#[test]
fn use_after_move_is_rejected_ax0004() {
    // Reading a %1 after ownership has been moved (consumed) → AX0004.
    let out = axionc()
        .args(["--check", &fixture("use_after_move.axi")])
        .output()
        .unwrap();
    assert!(!out.status.success());
    let text = String::from_utf8_lossy(&out.stdout);
    assert!(text.contains("AX0004"), "expected AX0004, output: {text}");
}

#[test]
fn type_mismatch_is_rejected_ax0200() {
    let out = axionc()
        .args(["--check", &fixture("type_mismatch.axi")])
        .output()
        .unwrap();
    assert!(!out.status.success());
    let text = String::from_utf8_lossy(&out.stdout);
    assert!(text.contains("AX0200"), "expected AX0200, output: {text}");
}

#[test]
fn inference_accepts_where_and_runs() {
    let out = axionc().arg(fixture("type_ok_poly.axi")).output().unwrap();
    assert!(
        out.status.success(),
        "output: {}",
        String::from_utf8_lossy(&out.stdout)
    );
    assert_eq!(String::from_utf8_lossy(&out.stdout), "55\n");
}

#[test]
fn writing_through_a_fractional_half_is_rejected_ax0006() {
    // Writing through a %0.5 half (passing it to a %1 parameter) → AX0006.
    let out = axionc()
        .args(["--check", &fixture("frac_write.axi")])
        .output()
        .unwrap();
    assert!(!out.status.success());
    let text = String::from_utf8_lossy(&out.stdout);
    assert!(text.contains("AX0006"), "expected AX0006, output: {text}");
}

#[test]
fn split_join_reads_and_recombines_and_runs() {
    // split → two %0.5 halves read/recombined by join; runs → 7.
    let out = axionc().arg(fixture("frac_join.axi")).output().unwrap();
    assert!(
        out.status.success(),
        "output: {}",
        String::from_utf8_lossy(&out.stdout)
    );
    assert_eq!(String::from_utf8_lossy(&out.stdout), "7\n");
}

#[test]
fn lambdas_run_higher_order_and_currying() {
    // higher-order functions + currying via chained lambdas → 42.
    let out = axionc().arg(fixture("lambda_hof.axi")).output().unwrap();
    assert!(
        out.status.success(),
        "output: {}",
        String::from_utf8_lossy(&out.stdout)
    );
    assert_eq!(String::from_utf8_lossy(&out.stdout), "42\n");
}

#[test]
fn cranelift_backend_jits_and_runs_fib() {
    // Native --dev backend: JIT-compiles the Int core and runs main :: Int → 6765.
    let out = axionc()
        .args(["--backend", "cranelift", &fixture("native_fib.axi")])
        .output()
        .unwrap();
    assert!(
        out.status.success(),
        "output: {}",
        String::from_utf8_lossy(&out.stderr)
    );
    assert_eq!(String::from_utf8_lossy(&out.stdout), "6765\n");
}

#[test]
fn cranelift_backend_compiles_multiclause_and_where() {
    // fibFast: multi-clause with a literal pattern + where ('go' lifted) → 832040.
    let out = axionc()
        .args(["--backend", "cranelift", &fixture("native_fibfast.axi")])
        .output()
        .unwrap();
    assert!(
        out.status.success(),
        "output: {}",
        String::from_utf8_lossy(&out.stderr)
    );
    assert_eq!(String::from_utf8_lossy(&out.stdout), "832040\n");
}

#[test]
fn cranelift_backend_runs_hello_with_string_io() {
    // 01_hello.axi native: string literal + putStrLn (axion_puts runtime).
    let out = axionc()
        .args(["--backend", "cranelift", &example("01_hello.axi")])
        .output()
        .unwrap();
    assert!(
        out.status.success(),
        "{}",
        String::from_utf8_lossy(&out.stderr)
    );
    assert_eq!(String::from_utf8_lossy(&out.stdout), "Hello, Axion!\n");
}

#[test]
fn cranelift_backend_runs_fib_example_with_show() {
    // 02_fib.axi native: putStrLn (show (fibFast 30)) → 832040, same as interp.
    let out = axionc()
        .args(["--backend", "cranelift", &example("02_fib.axi")])
        .output()
        .unwrap();
    assert!(
        out.status.success(),
        "{}",
        String::from_utf8_lossy(&out.stderr)
    );
    assert_eq!(String::from_utf8_lossy(&out.stdout), "832040\n");
}

#[test]
fn cranelift_backend_runs_records_on_the_heap() {
    // record_run.axi native: Point{x,y} on the heap (axion_alloc), update and selector.
    let out = axionc()
        .args(["--backend", "cranelift", &fixture("record_run.axi")])
        .output()
        .unwrap();
    assert!(
        out.status.success(),
        "{}",
        String::from_utf8_lossy(&out.stderr)
    );
    assert_eq!(String::from_utf8_lossy(&out.stdout), "99\n");
}

#[test]
fn cranelift_backend_compiles_case_and_tuples() {
    // 'case' (chain of if) + tuples on the heap; native and interp agree (200).
    let native = axionc()
        .args(["--backend", "cranelift", &fixture("native_case.axi")])
        .output()
        .unwrap();
    assert!(
        native.status.success(),
        "{}",
        String::from_utf8_lossy(&native.stderr)
    );
    assert_eq!(String::from_utf8_lossy(&native.stdout), "200\n");

    // the same program in the interpreter (main :: Int prints the result)
    let interp = axionc().arg(fixture("native_case.axi")).output().unwrap();
    assert_eq!(
        String::from_utf8_lossy(&interp.stdout),
        String::from_utf8_lossy(&native.stdout),
        "native and interpreter diverge"
    );
}

#[test]
fn cranelift_backend_compiles_closures() {
    // closures: lambda-lifting + capture (addN) + indirect call (apply).
    // main = apply (addN 10) 32 = 42; native and interp agree.
    let native = axionc()
        .args(["--backend", "cranelift", &fixture("native_closure.axi")])
        .output()
        .unwrap();
    assert!(
        native.status.success(),
        "{}",
        String::from_utf8_lossy(&native.stderr)
    );
    assert_eq!(String::from_utf8_lossy(&native.stdout), "42\n");

    let interp = axionc()
        .arg(fixture("native_closure.axi"))
        .output()
        .unwrap();
    assert_eq!(
        String::from_utf8_lossy(&interp.stdout),
        String::from_utf8_lossy(&native.stdout),
        "native and interpreter diverge"
    );
}

#[test]
fn auto_drop_frees_local_heap_at_runtime() {
    // Real reclamation (Auto-Drop §2): each call to 'step' allocates a local
    // tuple and frees it → 300 allocs == 300 frees, constant memory, no GC.
    let out = axionc()
        .args(["--backend", "cranelift", &fixture("heap_loop.axi")])
        .env("AXION_HEAP_STATS", "1")
        .output()
        .unwrap();
    assert!(
        out.status.success(),
        "{}",
        String::from_utf8_lossy(&out.stderr)
    );
    assert_eq!(String::from_utf8_lossy(&out.stdout), "90300\n");
    let stats = String::from_utf8_lossy(&out.stderr);
    assert!(
        stats.contains("300 allocs, 300 frees"),
        "expected total reclamation, stats: {stats}"
    );

    // the same result in the interpreter (cross-check)
    let interp = axionc().arg(fixture("heap_loop.axi")).output().unwrap();
    assert_eq!(String::from_utf8_lossy(&interp.stdout), "90300\n");
}

#[test]
fn cross_function_reclamation_frees_moved_linear_object() {
    // 'make' allocates a Box and returns it; 'take' receives it by %1 and frees
    // it. The object crosses the boundary and is freed exactly once.
    let out = axionc()
        .args(["--backend", "cranelift", &fixture("linear_move.axi")])
        .env("AXION_HEAP_STATS", "1")
        .output()
        .unwrap();
    assert!(
        out.status.success(),
        "{}",
        String::from_utf8_lossy(&out.stderr)
    );
    assert_eq!(String::from_utf8_lossy(&out.stdout), "42\n");
    let stats = String::from_utf8_lossy(&out.stderr);
    assert!(
        stats.contains("1 allocs, 1 frees"),
        "expected cross-function reclamation (1==1), stats: {stats}"
    );
    // the %1 param is freed in the callee (a drop node in Core)
    let core = axionc()
        .args(["--emit", "core", &fixture("linear_move.axi")])
        .output()
        .unwrap();
    assert!(
        String::from_utf8_lossy(&core.stdout).contains("drop b"),
        "expected 'drop b' in the body of 'take'"
    );
}

#[test]
fn borrowed_arg_reclaimed_after_call() {
    // 'dist' only reads the record's fields (a pure borrow), so 'main' — which
    // allocates it — frees it AFTER the call, instead of giving it up for lost: 1==1.
    let out = axionc()
        .args(["--backend", "cranelift", &fixture("borrow_reclaim.axi")])
        .env("AXION_HEAP_STATS", "1")
        .output()
        .unwrap();
    assert!(
        out.status.success(),
        "{}",
        String::from_utf8_lossy(&out.stderr)
    );
    assert_eq!(String::from_utf8_lossy(&out.stdout), "7\n");
    let stats = String::from_utf8_lossy(&out.stderr);
    assert!(
        stats.contains("1 allocs, 1 frees"),
        "expected reclamation of the borrowed argument (1==1), stats: {stats}"
    );
    // the record's drop must come AFTER the call that borrows it
    let core = axionc()
        .args(["--emit", "core", &fixture("borrow_reclaim.axi")])
        .output()
        .unwrap();
    let core = String::from_utf8_lossy(&core.stdout);
    // look only inside the body of `main` (the injected prelude brings other
    // functions with `_tN` temporaries ahead in the dump).
    let main = &core[core.find("main  =").expect("main function in Core")..];
    let call = main.find("call dist").expect("call to dist");
    let drop = main.find("drop _t0").expect("drop of the record");
    assert!(
        drop > call,
        "the drop must come after the borrowed call:\n{main}"
    );
}

#[test]
fn deep_drop_reclaims_nested_objects() {
    // Deep-drop (§2): nested objects (record-in-record and sum-type payload) are
    // reclaimed by generated destructors — allocs == frees, instead of leaking the
    // inner object (flat free).
    for (fx, expected, allocs) in [
        ("nested_drop.axi", "12\n", "2 allocs, 2 frees"),
        // `None` is an unboxed immediate (mixed type), so only `Some (P …)` and
        // the `P` record allocate — deep-drop still reclaims the nested `P`.
        ("sum_payload.axi", "15\n", "2 allocs, 2 frees"),
        // a linear recursive ADT consumed incrementally: the scrutinee is freed
        // shallowly (shell only) as the tail is transferred — 5 LC cells, 5 frees,
        // no double-free, no leak.
        ("linear_recursive_adt.axi", "15\n", "5 allocs, 5 frees"),
        // a generic container of HEAP elements (`List P`) dropped as a whole: the
        // monomorphized destructor `axion_drop_List$P` frees the 3 payloads too,
        // not just the spine — 3 Cons + 3 P = 6 allocs, 6 frees, no leak.
        ("poly_payload_drop.axi", "3\n", "6 allocs, 6 frees"),
        // TCO-compatible deep drop: borrow a scalar field + tail-recurse; the whole
        // list is reclaimed each step (12 objects over build 3/2/1), no leak, and
        // (see the separate assertion below) the tail call stays in tail position.
        ("poly_payload_tco.axi", "0\n", "12 allocs, 12 frees"),
        // payload-alias tracking: a heap sub-object (`inner y`) passed to a tail
        // call must be freed AFTER the call (bind-then-drop); whole list reclaimed.
        ("poly_payload_borrow_alias.axi", "3\n", "9 allocs, 9 frees"),
        // Phase B (generic-owning corner): a GENERIC function owns its `%1`
        // param (`head1 :: List a %1 -> Int`). The template cannot deep-drop
        // (its param's drop-type key is unresolvable), so it is monomorphized
        // per call site: `head1$P` drops `List P %1` via `axion_drop_List$P` —
        // 3 Cons + 3 P = 6 allocs, all freed.
        ("poly_payload_generic_drop.axi", "1\n", "6 allocs, 6 frees"),
        // Phase B, nested element type: `List (Maybe P)` → the spec
        // `head1$Maybe$P` and the doubly-specialized destructor
        // `axion_drop_List$Maybe$P` — 3 Cons + 3 Some + 3 P = 9 allocs, freed.
        (
            "poly_payload_generic_nested.axi",
            "1\n",
            "9 allocs, 9 frees",
        ),
        // Phase B, transitive: `wipe` calls the owning-generic `probe` over the
        // same var — the worklist pulls `probe$P` when `wipe$P` is materialized.
        (
            "poly_payload_generic_compose.axi",
            "1\n",
            "6 allocs, 6 frees",
        ),
        // F-2, per-field ownership: a `%1`-heap field extracted from a linear
        // record — the remainder reclaims the shell and non-extracted fields;
        // the extracted binder's Auto-Drop frees the moved-out payload.
        ("land_field_split_owned.axi", "3\n", "3 allocs, 3 frees"),
        // F-3, mixed transfers: `a :: Box %1` is extracted, `b :: Box` stays
        // with the record — the skip-variant destructor reclaims `b` + shell.
        ("land_field_mixed.axi", "3\n", "3 allocs, 3 frees"),
        // Non-`%1` poly-payload gap: inline remainder reclaims the non-escaped
        // head payload when the tail of a polymorphic list is transferred.
        ("poly_payload_gap.axi", "0\n", "6 allocs, 6 frees"),
        // Poly payload with a DEEP element type (`List Expr`): an extracted element
        // is reclaimed by its own destructor (resolved from `List$Expr`), not a flat
        // free that would leak the tree's children.
        ("poly_payload_deep.axi", "2\n", "6 allocs, 6 frees"),
        // A `where`-local accumulator borrows an owned `%1` list; the parent then
        // deep-drops the whole list after the call (the local was invisible to the
        // borrow analysis before, so nobody reclaimed it).
        ("where_owned_list.axi", "112\n", "12 allocs, 12 frees"),
        // Consume-inference: a monomorphic list-transformer that reuses heap
        // elements in its result gets its `List Box` param inferred `%1`, so it OWNS
        // and reclaims the spine (elements move into the result) instead of being a
        // borrow the caller double-frees.
        ("consume_monomorphic.axi", "6\n", "8 allocs, 8 frees"),
        // GENERIC list-transformers (`append`/`reverse`/`concat`) on `List Box`: a
        // var-carrying `%1` "pure-escape" param compiles natively as a generic
        // shell-freer (exempt from the owning-generic exclusion) — no double-free.
        ("generic_consume_box.axi", "6\n", "13 allocs, 13 frees"),
        // Multi-var owning params: `Tree a b %1` with two type vars specialized
        // to `Int` — the spec name uses a combined mangle `sumTree$Int$Int`.
        ("land_owned_multi.axi", "0\n", "3 allocs, 3 frees"),
        // Phase 4, Make-bound locals: a `List P` constructed via `let` — the
        // lowered MakeCon carries the mangled mono-key `List$P` from inference,
        // routing Auto-Drop to the monomorphized destructor.
        ("make_bound_drop.axi", "3\n", "6 allocs, 6 frees"),
        // Phase 4, Make-bound local drop: a `List P` built in a `let` that does
        // NOT escape the function — Auto-Drop alone must reclaim it.
        ("make_bound_drop_local.axi", "5\n", "4 allocs, 4 frees"),
        // Tuple-owned %1: a `%1` tuple param with heap elements — the generated
        // `axion_drop_tuple$Box$Box` destructor reclaims them.
        ("tuple_owned.axi", "4\n", "3 allocs, 3 frees"),
    ] {
        let out = axionc()
            .args(["--backend", "cranelift", &fixture(fx)])
            .env("AXION_HEAP_STATS", "1")
            .output()
            .unwrap();
        assert!(
            out.status.success(),
            "{fx}: {}",
            String::from_utf8_lossy(&out.stderr)
        );
        assert_eq!(String::from_utf8_lossy(&out.stdout), expected, "{fx}");
        let stats = String::from_utf8_lossy(&out.stderr);
        assert!(
            stats.contains(allocs),
            "{fx}: expected '{allocs}' (deep-drop reclaims the nested one), stats: {stats}"
        );
    }
    // the recursive destructor appears in Core for the nested type
    let core = axionc()
        .args(["--emit", "core", &fixture("nested_drop.axi")])
        .output()
        .unwrap();
    assert!(
        String::from_utf8_lossy(&core.stdout).contains("axion_drop_Box"),
        "expected the generated destructor 'axion_drop_Box' in Core"
    );
    // Phase B: the monomorphized owning-generic spec and its specialized
    // destructor appear in Core; the generic template does not compile natively.
    let core = axionc()
        .args(["--emit", "core", &fixture("poly_payload_generic_drop.axi")])
        .output()
        .unwrap();
    let core = String::from_utf8_lossy(&core.stdout);
    assert!(
        core.contains("head1$P") && core.contains("axion_drop_List$P"),
        "expected the owning-generic spec 'head1$P' and 'axion_drop_List$P' in Core"
    );
    assert!(
        !core
            .lines()
            .any(|l| l.starts_with("head1 ") || l.starts_with("head1  =")),
        "the generic-owning template 'head1' must not be compiled natively"
    );
    // nested instantiation: `List (Maybe P)` → `head1$Maybe$P` + `List$Maybe$P`
    let core = axionc()
        .args([
            "--emit",
            "core",
            &fixture("poly_payload_generic_nested.axi"),
        ])
        .output()
        .unwrap();
    let core = String::from_utf8_lossy(&core.stdout);
    assert!(
        core.contains("head1$Maybe$P") && core.contains("axion_drop_List$Maybe$P"),
        "expected 'head1$Maybe$P' and 'axion_drop_List$Maybe$P' in Core"
    );
    // transitive: `wipe` pulls `probe$P`; the compose spec calls it directly.
    let core = axionc()
        .args([
            "--emit",
            "core",
            &fixture("poly_payload_generic_compose.axi"),
        ])
        .output()
        .unwrap();
    let core = String::from_utf8_lossy(&core.stdout);
    assert!(
        core.contains("wipe$P") && core.contains("probe$P"),
        "expected the transitive specs 'wipe$P' and 'probe$P' in Core"
    );
}

#[test]
fn deep_drop_of_owned_scrutinee_is_skipped_when_result_aliases_payload() {
    // Regression: `case xs of Cons y ys -> inner y` returns a heap sub-object
    // BORROWED out of the owned scrutinee's payload. A deep drop (axion_drop_List$P)
    // would free that returned pointer → double-free. Auto-Drop must fall back to a
    // SHALLOW scrutinee free, so all three executors agree (no native double-free).
    let fx = "poly_payload_borrow_return.axi";
    let interp = axionc().arg(fixture(fx)).output().unwrap();
    assert_eq!(
        String::from_utf8_lossy(&interp.stdout),
        "3\n",
        "{fx} interp"
    );
    for backend in [["--backend", "cranelift"], ["--release", ""]] {
        let args: Vec<&str> = backend.iter().copied().filter(|s| !s.is_empty()).collect();
        let native = axionc().args(&args).arg(fixture(fx)).output().unwrap();
        assert!(
            native.status.success(),
            "{fx} {args:?} crashed (double-free regression): {}",
            String::from_utf8_lossy(&native.stderr)
        );
        assert_eq!(
            String::from_utf8_lossy(&native.stdout),
            "3\n",
            "{fx} {args:?} diverges from interp (=3)"
        );
    }
    // the scrutinee drops must be SHALLOW (`drop xs`, no deep `: List$P` key), or
    // the native backend would deep-drop and double-free the returned sub-object.
    let core = axionc()
        .args(["--emit", "core", &fixture(fx)])
        .output()
        .unwrap();
    let core = String::from_utf8_lossy(&core.stdout);
    assert!(
        !core.contains("drop xs : List"),
        "expected SHALLOW scrutinee drops (no deep `drop xs : List$P`), got:\n{core}"
    );
}

#[test]
fn tco_preserved_when_deep_drop_precedes_a_tail_call() {
    // `loop xs = case xs of Cons y ys -> loop (build (a y - 1))`: the deep drop of
    // the owned scrutinee is placed AFTER the scalar borrow `a y` but BEFORE the
    // tail call, so the call stays in tail position. Regression guard against the
    // exit-placed drop that pushed the recursive call out of tail position.
    let core = axionc()
        .args(["--emit", "core", &fixture("poly_payload_tco.axi")])
        .output()
        .unwrap();
    let core = String::from_utf8_lossy(&core.stdout);
    // the recursive call must remain a bare tail `ret call loop …`, not bound to a
    // temp before a trailing drop (`let _d = call loop …; drop xs; ret _d`).
    assert!(
        core.contains("drop xs : List$P")
            && core
                .lines()
                .any(|l| l.trim_start().starts_with("ret call loop")),
        "expected the deep drop BEFORE a tail `ret call loop` (TCO preserved), got:\n{core}"
    );
    assert!(
        !core.contains("= call loop"),
        "the recursive call was bound to a temp (pushed out of tail position):\n{core}"
    );
}

#[test]
fn arena_runs_natively_with_bulk_reset() {
    // Arena (§3): 'withArena' creates the root, allocN bump-allocates 100 cells,
    // and the arena is reclaimed with a SINGLE reset (not 100 frees). The interpreter
    // does not run arenas (they are --check-only), so only the native path + stats
    // are checked.
    let out = axionc()
        .args(["--backend", "cranelift", &fixture("arena_run.axi")])
        .env("AXION_HEAP_STATS", "1")
        .output()
        .unwrap();
    assert!(
        out.status.success(),
        "{}",
        String::from_utf8_lossy(&out.stderr)
    );
    assert_eq!(String::from_utf8_lossy(&out.stdout), "100\n");
    let stats = String::from_utf8_lossy(&out.stderr);
    assert!(
        stats.contains("1 news, 1 resets, 100 cells"),
        "expected 100 cells and 1 bulk reset, stats: {stats}"
    );
}

#[test]
fn buffer_sum_runs_natively() {
    // U8 Buffer (§4/§5): newBuffer/bufIota/sumBytes/free. sum(0..99)=4950.
    let native = axionc()
        .args(["--backend", "cranelift", &fixture("buffer_sum.axi")])
        .output()
        .unwrap();
    assert!(
        native.status.success(),
        "{}",
        String::from_utf8_lossy(&native.stderr)
    );
    assert_eq!(String::from_utf8_lossy(&native.stdout), "4950\n");
}

#[test]
fn array_sum_runs_natively() {
    // dense Array: newArray/setArray/getArray. [10,20,30,40,50] sum = 150.
    let native = axionc()
        .args(["--backend", "cranelift", &fixture("array_sum.axi")])
        .output()
        .unwrap();
    assert!(
        native.status.success(),
        "{}",
        String::from_utf8_lossy(&native.stderr)
    );
    assert_eq!(String::from_utf8_lossy(&native.stdout), "150\n");
}

#[test]
fn tritvec_base243_roundtrip_reclaims_once() {
    // TritVec (spec §10.B): base-243 packed ternary array. `fillTrit` OWNS the vec
    // (setTritVec in-place), `sumTrit` BORROWS it (getTritVec read loop) — the same
    // threaded pattern as Array. Fill 99 trits with the repeating weight pattern
    // (i mod 3)-1 = -1,0,+1 (33 cycles → sum 0), proving pack→unpack is faithful
    // across byte boundaries. Native-only (like Array); leak-freedom is gated by
    // scripts/sanitize.sh (1 alloc == 1 free).
    for backend in [["--backend", "cranelift"], ["--release", ""]] {
        let args: Vec<&str> = backend.iter().copied().filter(|s| !s.is_empty()).collect();
        let out = axionc()
            .args(&args)
            .arg(fixture("tritvec_roundtrip.axi"))
            .output()
            .unwrap();
        assert!(
            out.status.success(),
            "{args:?}: {}",
            String::from_utf8_lossy(&out.stderr)
        );
        assert_eq!(String::from_utf8_lossy(&out.stdout), "0\n", "{args:?}");
    }
}

#[test]
fn single_scope_owned_resource_reclaims_once() {
    // Drop-insertion fix: an owned heap resource in a flat let-chain whose last uses
    // are read-only getters (getI8/lenI8) is reclaimed exactly once — the getters
    // were previously treated as *moving* the resource, leaking it unless threaded
    // through a helper. 5 (set) + -1 (weight 3) + 20 (len) = 24. Leak-freedom gated
    // by sanitize.sh; here we check the value on both native backends.
    for backend in [["--backend", "cranelift"], ["--release", ""]] {
        let args: Vec<&str> = backend.iter().copied().filter(|s| !s.is_empty()).collect();
        let out = axionc()
            .args(&args)
            .arg(fixture("single_scope_reclaim.axi"))
            .output()
            .unwrap();
        assert!(
            out.status.success(),
            "{args:?}: {}",
            String::from_utf8_lossy(&out.stderr)
        );
        assert_eq!(String::from_utf8_lossy(&out.stdout), "24\n", "{args:?}");
    }
}

#[test]
fn general_dense_array_primitives() {
    // Fused reductions on Array Int (arraySum/arrayDot), I8Array (i8Sum/i8Dot), and
    // the compact I32Array (new/set/get/len/i32Sum/i32Dot/i32MatVecSum) — closure-free
    // one-pass readers, owned/borrow linearity (reclaimed once; sanitize-gated).
    let cases = [
        ("array_reduce.axi", "330\n"),  // 45 + 285
        ("i8_reduce.axi", "-103\n"),    // -1*100 + -3
        ("i8_dot_i8.axi", "7\n"),       // fair int8×int8 dot: sum of squares over 0..9
        ("i32array_run.axi", "4950000\n"), // sum i*1000, 0..99 (int32 range)
        ("i32_reduce.axi", "346\n"),    // 285 + 61
    ];
    for (fx, want) in cases {
        for backend in [["--backend", "cranelift"], ["--release", ""]] {
            let args: Vec<&str> = backend.iter().copied().filter(|s| !s.is_empty()).collect();
            let out = axionc().args(&args).arg(fixture(fx)).output().unwrap();
            assert!(
                out.status.success(),
                "{fx} {args:?}: {}",
                String::from_utf8_lossy(&out.stderr)
            );
            assert_eq!(String::from_utf8_lossy(&out.stdout), want, "{fx} {args:?}");
        }
    }
}

#[test]
fn i8array_compact_signed_byte_array() {
    // I8Array (Phase B): compact 1-byte-per-element signed array. `i8array_run`
    // threads new/setI8/getI8/lenI8 (fillI8 owns, sumI8 borrows) — sum of (i-3)
    // over 0..99 = 4650, confirming signed storage; reclaimed once (sanitize gate).
    // `i8array_matvec` runs the int8 matvec (i8Iota weights, small activation) = -3.
    for (fx, want) in [("i8array_run.axi", "4650\n"), ("i8array_matvec.axi", "-3\n")] {
        for backend in [["--backend", "cranelift"], ["--release", ""]] {
            let args: Vec<&str> = backend.iter().copied().filter(|s| !s.is_empty()).collect();
            let out = axionc().args(&args).arg(fixture(fx)).output().unwrap();
            assert!(
                out.status.success(),
                "{fx} {args:?}: {}",
                String::from_utf8_lossy(&out.stderr)
            );
            assert_eq!(String::from_utf8_lossy(&out.stdout), want, "{fx} {args:?}");
        }
    }
}

#[test]
fn tritvec_from_buffer_wraps_prepacked_bytes() {
    // tritVecFromBuffer (§10): wrap already-packed base-243 bytes from a Buffer into
    // a TritVec (the real weight-loading path). Borrows the buffer (freed explicitly),
    // produces an owned TritVec reclaimed once (sanitize-gated). bufIota bytes 0..4,
    // 25 trits; sum of all decoded weights = -5-4-3-4-3 = -19.
    for backend in [["--backend", "cranelift"], ["--release", ""]] {
        let args: Vec<&str> = backend.iter().copied().filter(|s| !s.is_empty()).collect();
        let out = axionc()
            .args(&args)
            .arg(fixture("tritvec_from_buffer.axi"))
            .output()
            .unwrap();
        assert!(
            out.status.success(),
            "{args:?}: {}",
            String::from_utf8_lossy(&out.stderr)
        );
        assert_eq!(String::from_utf8_lossy(&out.stdout), "-19\n", "{args:?}");
    }
}

#[test]
fn tritvec_matvec_streams_packed_weights() {
    // tritMatVecSum (§10): ternary matvec — M×K packed weights against a small
    // reused K-activation (streams only the packed weights). Borrows both; both
    // Auto-Dropped once (leak-freedom gated by sanitize.sh). N=10, K=4,
    // weight(i)=(i mod 3)-1, act(k)=k → sum_i weight(i)*act(i mod 4) = -3.
    for backend in [["--backend", "cranelift"], ["--release", ""]] {
        let args: Vec<&str> = backend.iter().copied().filter(|s| !s.is_empty()).collect();
        let out = axionc()
            .args(&args)
            .arg(fixture("tritvec_matvec.axi"))
            .output()
            .unwrap();
        assert!(
            out.status.success(),
            "{args:?}: {}",
            String::from_utf8_lossy(&out.stderr)
        );
        assert_eq!(String::from_utf8_lossy(&out.stdout), "-3\n", "{args:?}");
    }
}

#[test]
fn tritvec_bulk_builders_pack_and_reclaim() {
    // Bulk builders (§10): tritVecIota packs weight(i)=(i mod 3)-1 five trits/byte
    // in one native pass (no per-trit read-modify-write); arrayIota fills a[i]=i in
    // one pass. Both are fresh OWNED resources, Auto-Dropped once (leak-freedom
    // gated by sanitize.sh). `tritDot (tritVecIota 10) (arrayIota 10)` = -3.
    for backend in [["--backend", "cranelift"], ["--release", ""]] {
        let args: Vec<&str> = backend.iter().copied().filter(|s| !s.is_empty()).collect();
        let out = axionc()
            .args(&args)
            .arg(fixture("tritvec_iota.axi"))
            .output()
            .unwrap();
        assert!(
            out.status.success(),
            "{args:?}: {}",
            String::from_utf8_lossy(&out.stderr)
        );
        assert_eq!(String::from_utf8_lossy(&out.stdout), "-3\n", "{args:?}");
    }
}

#[test]
fn tritvec_fused_dot_borrows_both_and_reclaims() {
    // tritDot (§10): fused ternary dot product, sum_i weight(i)*acts[i], decoding
    // 5 trits/byte in one pass. Borrows both the packed TritVec and the activation
    // Array (both Auto-Dropped once — leak-freedom gated by sanitize.sh). 10 trits,
    // weight (i mod 3)-1, acts i → sum = -3. Agrees on both native backends.
    for backend in [["--backend", "cranelift"], ["--release", ""]] {
        let args: Vec<&str> = backend.iter().copied().filter(|s| !s.is_empty()).collect();
        let out = axionc()
            .args(&args)
            .arg(fixture("tritvec_dot.axi"))
            .output()
            .unwrap();
        assert!(
            out.status.success(),
            "{args:?}: {}",
            String::from_utf8_lossy(&out.stderr)
        );
        assert_eq!(String::from_utf8_lossy(&out.stdout), "-3\n", "{args:?}");
    }
}

#[test]
fn array_threaded_through_helpers_reclaims_once() {
    // An Array threaded through helper functions: `fill` owns+returns it, `sumArr`
    // BORROWS it (recursive read-only getArray loop). The fixpoint borrow analysis
    // + uniquify (let-shadowing) + single-var-case collapse (imperative-do) make it
    // reclaim exactly once — no double-free, no leak (ASan/LSan-gated separately).
    // Both the `let`-shadowing and `imperative do` forms must give 4950 on both
    // native backends.
    for fx in ["array_thread_let.axi", "array_thread_do.axi"] {
        for backend in [["--backend", "cranelift"], ["--release", ""]] {
            let args: Vec<&str> = backend.iter().copied().filter(|s| !s.is_empty()).collect();
            let out = axionc().args(&args).arg(fixture(fx)).output().unwrap();
            assert!(
                out.status.success(),
                "{fx} {args:?}: {}",
                String::from_utf8_lossy(&out.stderr)
            );
            assert_eq!(
                String::from_utf8_lossy(&out.stdout),
                "4950\n",
                "{fx} {args:?}"
            );
        }
    }
}

#[test]
fn linear_buffer_inplace_runs_natively() {
    // %1 Buffer + in-place XOR (§5): the linear thread runs; encrypt consumes+returns.
    let out = axionc()
        .args(["--backend", "cranelift", &fixture("buffer_linear.axi")])
        .output()
        .unwrap();
    assert!(
        out.status.success(),
        "{}",
        String::from_utf8_lossy(&out.stderr)
    );
    assert_eq!(String::from_utf8_lossy(&out.stdout), "126444\n");
}

#[test]
fn do_and_dollar_and_hex_sugar_runs() {
    // `imperative $ do xorInPlace buf 0x5A` desugars → xorInPlace buf 90 → 126444.
    let out = axionc()
        .args(["--backend", "cranelift", &fixture("do_sugar.axi")])
        .output()
        .unwrap();
    assert!(
        out.status.success(),
        "{}",
        String::from_utf8_lossy(&out.stderr)
    );
    assert_eq!(String::from_utf8_lossy(&out.stdout), "126444\n");
}

#[test]
fn do_block_sequences_io_statements() {
    // `do { putStrLn a; putStrLn b }` runs the two statements in order. Tested on
    // the native backend — the interpreter uses a single-action IO model (it only
    // runs main's final action), it does not sequence (§ assumed limitation).
    let out = axionc()
        .args(["--backend", "cranelift", &fixture("do_io.axi")])
        .output()
        .unwrap();
    assert!(out.status.success());
    assert_eq!(String::from_utf8_lossy(&out.stdout), "one\ntwo\n");
}

#[test]
fn fizzbuzz_runs_l0() {
    // Listing 1.3 of the spec (L0): FizzBuzz with ranges `[1..15]`, composition `.`,
    // `mapM_`, guards and `mod`. A "day 1" example from the spec, running.
    let out = axionc().arg(example("03b_fizzbuzz.axi")).output().unwrap();
    assert!(
        out.status.success(),
        "FizzBuzz should run: {}",
        String::from_utf8_lossy(&out.stderr)
    );
    let text = String::from_utf8_lossy(&out.stdout);
    assert!(
        text.starts_with("1\n2\nFizz\n4\nBuzz\nFizz\n") && text.contains("FizzBuzz"),
        "unexpected output:\n{text}"
    );
}

#[test]
fn list_syntax_and_ops_l0() {
    // §1 (L0): literals `[..]`, cons `:`, `map`, `range` — the `List` type comes
    // from the built-in prelude (no user `data`). Result 26.
    let out = axionc().arg(fixture("list_ops.axi")).output().unwrap();
    assert!(
        out.status.success(),
        "lists should run: {}",
        String::from_utf8_lossy(&out.stderr)
    );
    assert_eq!(String::from_utf8_lossy(&out.stdout), "26\n");
}

#[test]
fn parametric_data_types_work() {
    // §1 (L0): parametric sum types (`Maybe a`, `Either a b`) — the constructors
    // generalize over the type parameters. Runs in all three executors.
    let fx = fixture("parametric_data.axi");
    for args in [
        vec![fx.as_str()],
        vec!["--backend", "cranelift", fx.as_str()],
    ] {
        let out = axionc().args(&args).output().unwrap();
        assert!(
            out.status.success(),
            "{args:?}: {}",
            String::from_utf8_lossy(&out.stderr)
        );
        assert_eq!(String::from_utf8_lossy(&out.stdout), "49\n", "{args:?}");
    }
}

#[test]
fn sum_type_case_matches_on_tag() {
    // Sum type (3 constructors) with a runtime tag; the case compares the tag and
    // destructures. val(Pos 7)+val Neg+val Zero = 6. Same in all three executors.
    let native = axionc()
        .args(["--backend", "cranelift", &fixture("sum_type.axi")])
        .output()
        .unwrap();
    assert!(
        native.status.success(),
        "{}",
        String::from_utf8_lossy(&native.stderr)
    );
    assert_eq!(String::from_utf8_lossy(&native.stdout), "6\n");
    let interp = axionc().arg(fixture("sum_type.axi")).output().unwrap();
    assert_eq!(String::from_utf8_lossy(&interp.stdout), "6\n");
}

#[test]
fn ffi_calls_libc_via_dlsym() {
    // FFI: `foreign labs :: Int -> Int` calls libc's labs() (dlsym). Runs in all
    // three executors; labs(-42) = 42.
    let native = axionc()
        .args(["--backend", "cranelift", &fixture("ffi_labs.axi")])
        .output()
        .unwrap();
    assert!(
        native.status.success(),
        "{}",
        String::from_utf8_lossy(&native.stderr)
    );
    assert_eq!(String::from_utf8_lossy(&native.stdout), "42\n");
    let interp = axionc().arg(fixture("ffi_labs.axi")).output().unwrap();
    assert_eq!(String::from_utf8_lossy(&interp.stdout), "42\n");
}

#[test]
fn constructor_pattern_in_case_destructures() {
    // `case p of Point a b -> a + b` (single-constructor type). interp and native
    // agree (7).
    let native = axionc()
        .args(["--backend", "cranelift", &fixture("con_pattern.axi")])
        .output()
        .unwrap();
    assert!(
        native.status.success(),
        "{}",
        String::from_utf8_lossy(&native.stderr)
    );
    assert_eq!(String::from_utf8_lossy(&native.stdout), "7\n");
    let interp = axionc().arg(fixture("con_pattern.axi")).output().unwrap();
    assert_eq!(String::from_utf8_lossy(&interp.stdout), "7\n");
}

#[test]
fn fold_bytes_runs_with_operator_section() {
    // foldBytes (+) 0 buf: folds the closure over the bytes (indirect call per
    // byte at runtime). sum of bytes 0..99 = 4950.
    let out = axionc()
        .args(["--backend", "cranelift", &fixture("fold_bytes.axi")])
        .output()
        .unwrap();
    assert!(
        out.status.success(),
        "{}",
        String::from_utf8_lossy(&out.stderr)
    );
    assert_eq!(String::from_utf8_lossy(&out.stdout), "4950\n");
}

#[test]
fn guards_compile_and_run() {
    // guards → chain of if; interp and native agree (0).
    let native = axionc()
        .args(["--backend", "cranelift", &fixture("guards.axi")])
        .output()
        .unwrap();
    assert!(
        native.status.success(),
        "{}",
        String::from_utf8_lossy(&native.stderr)
    );
    assert_eq!(String::from_utf8_lossy(&native.stdout), "0\n");
    let interp = axionc().arg(fixture("guards.axi")).output().unwrap();
    assert_eq!(String::from_utf8_lossy(&interp.stdout), "0\n");
}

#[test]
fn linear_elision_updates_record_in_place() {
    // Linear Elision (§2): 'bump c = c { val = 99 }' with c :: Cell %1 mutates the
    // block (an `update!` node in Core) → only 1 allocation, not 2. Result 99.
    let core = axionc()
        .args(["--emit", "core", &fixture("inplace_update.axi")])
        .output()
        .unwrap();
    assert!(
        String::from_utf8_lossy(&core.stdout).contains("update!"),
        "expected the in-place `update!` node in Core"
    );
    let out = axionc()
        .args(["--backend", "cranelift", &fixture("inplace_update.axi")])
        .env("AXION_HEAP_STATS", "1")
        .output()
        .unwrap();
    assert!(
        out.status.success(),
        "{}",
        String::from_utf8_lossy(&out.stderr)
    );
    assert_eq!(String::from_utf8_lossy(&out.stdout), "99\n");
    let stats = String::from_utf8_lossy(&out.stderr);
    assert!(
        stats.contains("1 allocs"),
        "in-place should save the copy's allocation, stats: {stats}"
    );
}

#[test]
fn operator_section_is_a_first_class_value() {
    // `(+)` as a value (section) passed to a HOF: apply2 (+) 3 4 = 7.
    let out = axionc()
        .args(["--backend", "cranelift", &fixture("op_section.axi")])
        .output()
        .unwrap();
    assert!(
        out.status.success(),
        "{}",
        String::from_utf8_lossy(&out.stderr)
    );
    assert_eq!(String::from_utf8_lossy(&out.stdout), "7\n");
}

#[test]
fn example_05_checksum_borrow_typechecks() {
    // Target program 5 (§5, borrow elision) compiles INTACT: foldBytes with the
    // `(+)` section, U8/U32, and the elision (checksum borrows, then encrypt
    // consumes — no AX0001). No main → --check only.
    let out = axionc()
        .args(["--check", &example("05_checksum_borrow.axi")])
        .output()
        .unwrap();
    assert!(
        out.status.success(),
        "05 should compile: {}",
        String::from_utf8_lossy(&out.stdout)
    );
}

#[test]
fn example_03_linear_buffer_compiles_and_runs() {
    // Target program 3 (§5) runs INTACT: U8 %1 Buffer + imperative $ do +
    // withBuffer + \-lambda. main :: IO () (only allocates/xors/frees, no output).
    let out = axionc()
        .args(["--backend", "cranelift", &example("03_linear_buffer.axi")])
        .output()
        .unwrap();
    assert!(
        out.status.success(),
        "03 should run: {}",
        String::from_utf8_lossy(&out.stderr)
    );
}

#[test]
fn linear_buffer_consumed_twice_is_rejected_ax0001() {
    // consuming the %1 Buffer twice (xorInPlace) → contraction → AX0001.
    let out = axionc()
        .args(["--check", &fixture("buffer_use_twice.axi")])
        .output()
        .unwrap();
    assert!(!out.status.success());
    let text = String::from_utf8_lossy(&out.stdout);
    assert!(text.contains("AX0001"), "expected AX0001, output: {text}");
}

#[test]
fn arena_escape_still_rejected_statically_ax0003() {
    // runtime reclamation does not waive the static escape analysis.
    let out = axionc()
        .args(["--check", &fixture("arena_escape.axi")])
        .output()
        .unwrap();
    assert!(!out.status.success());
    assert!(String::from_utf8_lossy(&out.stdout).contains("AX0003"));
}

#[test]
fn auto_drop_inserts_drop_nodes_in_core() {
    // the local tuple of the 'case' is freed at the head of the arm (after destructuring).
    let out = axionc()
        .args(["--emit", "core", &fixture("native_case.axi")])
        .output()
        .unwrap();
    assert!(out.status.success());
    let ir = String::from_utf8_lossy(&out.stdout);
    assert!(ir.contains("drop _t1"), "no drop node in Core:\n{ir}");
}

#[test]
fn emit_core_dumps_anf_ir() {
    // the Core IR (ANF) of the closure: converts the lambda and the indirect application.
    let out = axionc()
        .args(["--emit", "core", &fixture("native_closure.axi")])
        .output()
        .unwrap();
    assert!(out.status.success());
    let ir = String::from_utf8_lossy(&out.stdout);
    // lifted function with a capture environment + indirect call + closure. The
    // lambda index (`lam$N`) is not pinned — the prelude also brings lambdas into
    // the dump; the capture of `n` is what identifies this one.
    assert!(
        ir.contains("[env n]"),
        "no lifted lambda with capture:\n{ir}"
    );
    assert!(ir.contains("callclo"), "no indirect call:\n{ir}");
    assert!(
        ir.contains("closure lam$"),
        "no closure construction:\n{ir}"
    );
    // ANF: call arguments are atoms named by `let`
    assert!(ir.contains("let "), "not in ANF:\n{ir}");
}

#[test]
fn emit_llvm_dumps_llvm_ir() {
    // the --release backend (§18) lowers the SAME Core to textual LLVM IR.
    // The IR is checked without invoking clang (which may not be on CI).
    let out = axionc()
        .args(["--emit", "llvm", &fixture("native_fib.axi")])
        .output()
        .unwrap();
    assert!(out.status.success());
    let ir = String::from_utf8_lossy(&out.stdout);
    assert!(
        ir.contains("define i64 @\"ax_fib\"(i64"),
        "no def of fib:\n{ir}"
    );
    assert!(ir.contains("call i64 @\"ax_fib\""), "no recursion:\n{ir}");
    assert!(ir.contains("phi i64"), "no phi from the if:\n{ir}");
    assert!(
        ir.contains("define i32 @main()") && ir.contains("@printf"),
        "no driver that prints:\n{ir}"
    );
}

#[test]
fn release_backend_compiles_and_runs_when_clang_present() {
    // if clang is available (AXION_CLANG or on PATH), --release compiles and runs, and
    // its output matches --dev's across all of Core (records, closures,
    // strings/IO, case, arenas, drops).
    let clang = std::env::var("AXION_CLANG").unwrap_or_else(|_| "clang".into());
    if std::process::Command::new(&clang)
        .arg("--version")
        .output()
        .is_err()
    {
        return; // no clang in this environment — the IR test above already covers it
    }
    let cases = [
        (fixture("native_fib.axi"), "6765\n"),
        (fixture("native_case.axi"), "200\n"), // case + tuples
        (fixture("native_closure.axi"), "42\n"), // closures
        (fixture("record_run.axi"), "99\n"),   // records on the heap
        (fixture("linear_move.axi"), "42\n"),  // Auto-Drop + free
        (fixture("arena_run.axi"), "100\n"),   // arenas
        (fixture("buffer_sum.axi"), "4950\n"), // U8 Buffer / §4
        (fixture("buffer_linear.axi"), "126444\n"), // %1 Buffer in-place / §5
        (fixture("inplace_update.axi"), "99\n"), // Linear Elision / §2
        (fixture("ffi_labs.axi"), "42\n"),     // FFI via dlsym / §18
        (example("01_hello.axi"), "Hello, Axion!\n"), // strings / IO
        (example("02_fib.axi"), "832040\n"),
        (fixture("mono_typeclass.axi"), "20\n"), // monomorphized typeclasses → native
        (fixture("mono_constrained.axi"), "3\n"), // `Eq a =>` specialized → native
        (fixture("mono_transitive.axi"), "2\n"), // transitive specialization (β-2)
        (fixture("typeclasses.axi"), "125\n"),   // full example (count + eq Shape)
        (fixture("native_io.axi"), "sum=6\n2\n4\n6\n"), // native IO: do + mapM_ + putStr
        (fixture("native_hof.axi"), "56\n"),     // first-class fns: filter/map/foldr + named
        (
            example("03b_fizzbuzz.axi"),
            "1\n2\nFizz\n4\nBuzz\nFizz\n7\n8\nFizz\nBuzz\n11\nFizz\n13\n14\nFizzBuzz\n",
        ), // partial compose + putStrLn as a value → native
        (example("06_typeclasses.axi"), "6\n"),  // monomorphized typeclasses (README example)
        (fixture("session_run_pingpong.axi"), "42\n"), // native sessions (§11): ping-pong
        (fixture("session_run_offer.axi"), "7\n"), // native choice (select/offer)
        (fixture("session_run_cancel.axi"), "5\n"), // native cancellation (cancel/T5)
        (fixture("session_run_twospawn.axi"), "42\n"), // two children + 2 recv suspensions
        (fixture("session_run_choice3.axi"), "2\n"), // 3-way choice dispatch
        (fixture("session_run_fib.axi"), "6765\n"), // compute-heavy worker (value-position call)
        (fixture("session_run_parfib.axi"), "300100\n"), // four compute-heavy workers
        (fixture("session_run_server.axi"), "63\n"), // recursive session (server loop)
    ];
    for (path, expected) in cases {
        let out = axionc().args(["--release", &path]).output().unwrap();
        assert!(
            out.status.success(),
            "{path}: {}",
            String::from_utf8_lossy(&out.stderr)
        );
        assert_eq!(
            String::from_utf8_lossy(&out.stdout),
            expected,
            "--release diverged on {path}"
        );
    }
}

#[test]
fn native_runtime_is_leak_free_under_lsan() {
    // Axion's value proposition is memory safety without a GC. Compiles heap/arena/
    // borrow fixtures with the --release LLVM IR + AddressSanitizer +
    // LeakSanitizer and requires a clean run (0 corruption, 0 leaks). In particular
    // it covers the two closed leaks: the `withArena` closure (arena_run) and the
    // base of a copy-update (update_borrow). Needs clang.
    let clang = std::env::var("AXION_CLANG").unwrap_or_else(|_| "clang".into());
    if std::process::Command::new(&clang)
        .arg("--version")
        .output()
        .is_err()
    {
        return;
    }
    let rt = format!("{}/src/axion_rt.c", env!("CARGO_MANIFEST_DIR"));
    let dir = std::env::temp_dir().join(format!("axion-lsan-{}", std::process::id()));
    std::fs::create_dir_all(&dir).unwrap();

    for name in [
        "borrow_reclaim",
        "update_borrow",
        "arena_run",
        "heap_loop",
        "linear_move",
        "inplace_update",
        // deep-drop of a polymorphic container's recursive-heap elements
        "poly_payload_deep",
        // a where-local borrows an owned list; the parent reclaims it (leak-free)
        "where_owned_list",
        // consume-inferred %1 on a monomorphic list-transformer (element reuse)
        "consume_monomorphic",
        // conditionally-escaping owned heap param (headOr default) reclaimed in the
        // arm where it is dead — no leak, no double-free
        "cond_escape_reclaim",
        // generic container of heap elements (Lst Box) reclaims its ELEMENTS via the
        // monomorphic destructor (axion_drop_Lst$Box), not just the spine
        "poly_element_reclaim",
        // an owned %1 param a function never uses is dropped at entry, not leaked
        "unused_linear_param_reclaim",
        // String reclamation (§tc): tagged heap/literal strings freed via
        // axion_str_drop — literals (zero header) skipped, no double-free, no leak
        "string_reclaim",
        // nested-parametric derived Show allocates/reclaims its intermediate strings
        "derive_show_nested_param",
        // generic pure-escape append/reverse/concat on List Box (native shell-free)
        "generic_consume_box",
        // native sessions (§11): the scheduler's nursery arena reclaims every
        // task state at `axion_sess_run` exit — no leaks, no use-after-free.
        "session_run_pingpong",
        "session_run_offer",
        "session_run_cancel",
        "session_run_twospawn",
        "session_run_choice3",
        "session_run_fib",
        "session_run_parfib",
        "session_run_server",
    ] {
        // lower to LLVM IR
        let ll = dir.join(format!("{name}.ll"));
        let ir = axionc()
            .args(["--emit", "llvm", &fixture(&format!("{name}.axi"))])
            .output()
            .unwrap();
        assert!(ir.status.success(), "{name}: --emit llvm failed");
        std::fs::write(&ll, &ir.stdout).unwrap();
        // compile with ASan + LSan
        let exe = dir.join(format!("{name}.san"));
        let cc = std::process::Command::new(&clang)
            .args(["-fsanitize=address,leak", "-pthread", "-O1", "-w"])
            .arg(&ll)
            .arg(&rt)
            .arg("-o")
            .arg(&exe)
            .status()
            .unwrap();
        assert!(cc.success(), "{name}: clang+sanitizer failed");
        // run with leak detection on — it must exit clean
        let run = std::process::Command::new(&exe)
            .env("ASAN_OPTIONS", "detect_leaks=1")
            .output()
            .unwrap();
        assert!(
            run.status.success(),
            "{name}: ASan/LSan reported an error:\n{}",
            String::from_utf8_lossy(&run.stderr)
        );
    }
    let _ = std::fs::remove_dir_all(&dir);
}

#[test]
fn ffi_calls_user_shared_library() {
    // FFI (§18) to `dlopen`: `foreign "lib.so" name :: …` loads the user's `.so`
    // and calls it in all three executors (interp, --dev, --release).
    // Needs clang to compile the `.so`.
    let clang = std::env::var("AXION_CLANG").unwrap_or_else(|_| "clang".into());
    if std::process::Command::new(&clang)
        .arg("--version")
        .output()
        .is_err()
    {
        return;
    }
    let dir = std::env::temp_dir().join(format!("axion-ffi-test-{}", std::process::id()));
    std::fs::create_dir_all(&dir).unwrap();
    let cfile = dir.join("mymath.c");
    let sofile = dir.join("libmymath.so");
    std::fs::write(
        &cfile,
        "#include <stdint.h>\n\
         int64_t axion_triple(int64_t x) { return x * 3; }\n\
         int64_t axion_add(int64_t a, int64_t b) { return a + b; }\n",
    )
    .unwrap();
    let ok = std::process::Command::new(&clang)
        .args(["-O2", "-shared", "-fPIC"])
        .arg(&cfile)
        .arg("-o")
        .arg(&sofile)
        .status()
        .unwrap()
        .success();
    assert!(ok, "clang did not compile the test .so");

    let axi = dir.join("prog.axi");
    std::fs::write(
        &axi,
        format!(
            "foreign \"{so}\" axion_triple :: Int -> Int\n\
             foreign \"{so}\" axion_add :: Int -> Int -> Int\n\
             main :: Int\n\
             main = axion_add (axion_triple 4) 5\n",
            so = sofile.display()
        ),
    )
    .unwrap();
    let path = axi.to_str().unwrap();

    for args in [
        vec![path],
        vec!["--backend", "cranelift", path],
        vec!["--release", path],
    ] {
        let out = axionc().args(&args).output().unwrap();
        assert!(
            out.status.success(),
            "{args:?}: {}",
            String::from_utf8_lossy(&out.stderr)
        );
        assert_eq!(
            String::from_utf8_lossy(&out.stdout),
            "17\n",
            "FFI to the user's .so diverged on {args:?}"
        );
    }
    let _ = std::fs::remove_dir_all(&dir);
}

#[test]
fn emit_clif_dumps_cranelift_ir() {
    let out = axionc()
        .args(["--emit", "clif", &fixture("native_fib.axi")])
        .output()
        .unwrap();
    assert!(out.status.success());
    let text = String::from_utf8_lossy(&out.stdout);
    assert!(
        text.contains("brif") && text.contains("call") && text.contains("-> i64"),
        "unexpected IR: {text}"
    );
}

#[test]
fn json_diagnostics_are_emitted() {
    let out = axionc()
        .args(["--emit", "json", &fixture("use_after_consume.axi")])
        .output()
        .unwrap();
    let text = String::from_utf8_lossy(&out.stdout);
    assert!(
        text.contains("\"code\": \"AX0001\""),
        "unexpected JSON: {text}"
    );
}

#[test]
fn list_stdlib_functions() {
    // Prelude list library (step 1 → general purpose): length,
    // append, reverse, foldr, foldl, take, drop, filter, null, elem, sum.
    let out = axionc().arg(fixture("list_stdlib.axi")).output().unwrap();
    assert!(
        out.status.success(),
        "stdlib should run: {}",
        String::from_utf8_lossy(&out.stderr)
    );
    assert_eq!(String::from_utf8_lossy(&out.stdout), "414\n");
}

#[test]
fn user_defined_infix_operators() {
    // Step 2: `x `f` y` ≡ `f x y` for a named function. Runs in all three
    // executors (first order → native too): 100 `min` (7 `plus` 5) = 12.
    let interp = axionc().arg(fixture("user_infix.axi")).output().unwrap();
    assert!(
        interp.status.success(),
        "interp: {}",
        String::from_utf8_lossy(&interp.stderr)
    );
    assert_eq!(String::from_utf8_lossy(&interp.stdout), "12\n");

    let dev = axionc()
        .args(["--backend", "cranelift", &fixture("user_infix.axi")])
        .output()
        .unwrap();
    assert!(
        dev.status.success(),
        "cranelift: {}",
        String::from_utf8_lossy(&dev.stderr)
    );
    assert_eq!(String::from_utf8_lossy(&dev.stdout), "12\n");
}

#[test]
fn list_extra_concat_zip() {
    // stdlib step 3: ++ (concatenation), concat, zipWith, zip. Pure Axion over
    // List. 20 + 6 + 140 + 11 = 177.
    let out = axionc().arg(fixture("list_extra.axi")).output().unwrap();
    assert!(
        out.status.success(),
        "list_extra: {}",
        String::from_utf8_lossy(&out.stderr)
    );
    assert_eq!(String::from_utf8_lossy(&out.stdout), "177\n");
}

#[test]
fn concat_operator_agrees_natively() {
    // `++` on lists lowers to `append` (first order) → runs in all three executors.
    // sum ([1,2] ++ [3,4] ++ [10]) = 20 in interp and Cranelift.
    let interp = axionc().arg(fixture("plus_plus.axi")).output().unwrap();
    assert!(interp.status.success());
    assert_eq!(String::from_utf8_lossy(&interp.stdout), "20\n");
    let dev = axionc()
        .args(["--backend", "cranelift", &fixture("plus_plus.axi")])
        .output()
        .unwrap();
    assert!(
        dev.status.success(),
        "cranelift: {}",
        String::from_utf8_lossy(&dev.stderr)
    );
    assert_eq!(String::from_utf8_lossy(&dev.stdout), "20\n");
}

#[test]
fn rich_strings_concat_unwords_unlines() {
    // Richer strings: ++, unwords, unlines, putStr (interp-level, as IO).
    let out = axionc().arg(fixture("rich_strings.axi")).output().unwrap();
    assert!(
        out.status.success(),
        "rich_strings: {}",
        String::from_utf8_lossy(&out.stderr)
    );
    assert_eq!(
        String::from_utf8_lossy(&out.stdout),
        "Hello Axion!\nline 1\nline 2\n"
    );
}

#[test]
fn typeclasses_dispatch_and_constraints() {
    // Typeclasses slice 1: class/instance + dynamic dispatch on the type-head of
    // the 1st argument, and constrained polymorphism `Eq a =>`. Two classes,
    // an instance that reuses methods from another, a generic function `count`.
    // 3 (count) + 10 + 12 (size) + 100 (eq via size) = 125.
    let out = axionc().arg(fixture("typeclasses.axi")).output().unwrap();
    assert!(
        out.status.success(),
        "typeclasses: {}",
        String::from_utf8_lossy(&out.stderr)
    );
    assert_eq!(String::from_utf8_lossy(&out.stdout), "125\n");
}

#[test]
fn generic_prelude_over_typeclasses() {
    // Hardening of slice 1: maxOr/minOr (Ord a =>) and nub (Eq a =>) in the
    // prelude, dispatching to the Eq Int / Ord Int instances. 9 + 1 + 4 = 14.
    let out = axionc()
        .arg(fixture("generic_stdlib.axi"))
        .output()
        .unwrap();
    assert!(
        out.status.success(),
        "generic_stdlib: {}",
        String::from_utf8_lossy(&out.stderr)
    );
    assert_eq!(String::from_utf8_lossy(&out.stdout), "14\n");
    // Native non-regression: the new generic functions (maxOr/nub) call methods
    // → they are interp-only and the native filter excludes them. The proof that
    // the native path still compiles is in the test release_backend_compiles_and_runs_*.
}

#[test]
fn typeclass_coherence_is_checked_statically() {
    // Slice 2a: class and instance coherence/completeness at compile time.
    let reject = |fx: &str, code: &str| {
        let out = axionc().args(["--check", &fixture(fx)]).output().unwrap();
        assert!(!out.status.success(), "{fx} should fail");
        let text = String::from_utf8_lossy(&out.stdout);
        assert!(text.contains(code), "{fx}: expected {code}, output: {text}");
    };
    reject("tc_unknown_class.axi", "AX0400"); // instance of an undeclared class
    reject("tc_missing_method.axi", "AX0401"); // missing class method
    reject("tc_extra_method.axi", "AX0402"); // method outside the class
    reject("tc_dup_instance.axi", "AX0403"); // duplicate instance (incoherence)
}

#[test]
fn first_class_functions_run_natively() {
    // Closing layer 1: higher-order functions (filter/map/foldr) with lambdas AND
    // named functions as values, via eta-expansion. Interp and --dev agree on 56
    // (--release is in the release_backend_* list).
    for args in [
        vec![fixture("native_hof.axi")],
        vec![
            "--backend".into(),
            "cranelift".into(),
            fixture("native_hof.axi"),
        ],
    ] {
        let out = axionc().args(&args).output().unwrap();
        assert!(
            out.status.success(),
            "{args:?}: {}",
            String::from_utf8_lossy(&out.stderr)
        );
        assert_eq!(String::from_utf8_lossy(&out.stdout), "56\n", "{args:?}");
    }
}

#[test]
fn native_io_effects_run_on_interp_and_dev() {
    // 1st slice of the M:N road: native IO/effects. do-blocks sequence (each action's
    // output precedes the next), `mapM_` is a prelude function, `putStr` is runtime.
    // Interp and --dev agree (--release in the release_backend_* list).
    for args in [
        vec![fixture("native_io.axi")],
        vec![
            "--backend".into(),
            "cranelift".into(),
            fixture("native_io.axi"),
        ],
    ] {
        let out = axionc().args(&args).output().unwrap();
        assert!(
            out.status.success(),
            "{args:?}: {}",
            String::from_utf8_lossy(&out.stderr)
        );
        assert_eq!(
            String::from_utf8_lossy(&out.stdout),
            "sum=6\n2\n4\n6\n",
            "{args:?}"
        );
    }
}

#[test]
fn monomorphized_typeclass_runs_on_all_backends() {
    // Slice 2b-ii: a method use over a concrete type is rewritten to a direct
    // call to the impl → compiles natively. Interp and --dev agree on 20
    // (--release is covered by release_backend_compiles_and_runs_*).
    let interp = axionc()
        .arg(fixture("mono_typeclass.axi"))
        .output()
        .unwrap();
    assert!(
        interp.status.success(),
        "interp: {}",
        String::from_utf8_lossy(&interp.stderr)
    );
    assert_eq!(String::from_utf8_lossy(&interp.stdout), "20\n");

    let dev = axionc()
        .args(["--backend", "cranelift", &fixture("mono_typeclass.axi")])
        .output()
        .unwrap();
    assert!(
        dev.status.success(),
        "cranelift: {}",
        String::from_utf8_lossy(&dev.stderr)
    );
    assert_eq!(String::from_utf8_lossy(&dev.stdout), "20\n");
}

#[test]
fn monomorphized_constrained_function_runs_on_all_backends() {
    // Slice 2b-β: `count :: Eq a =>` specialized per type at the call-site
    // (`count 2 [..]` → `count$Int`, `eq → eq$Int`, recursion → `count$Int`).
    // Interp and --dev agree on 3 (--release is in the release_backend_* list).
    for args in [
        vec![fixture("mono_constrained.axi")],
        vec![
            "--backend".into(),
            "cranelift".into(),
            fixture("mono_constrained.axi"),
        ],
    ] {
        let out = axionc().args(&args).output().unwrap();
        assert!(
            out.status.success(),
            "{args:?}: {}",
            String::from_utf8_lossy(&out.stderr)
        );
        assert_eq!(String::from_utf8_lossy(&out.stdout), "3\n", "{args:?}");
    }
}

#[test]
fn transitively_monomorphized_constraints_run_on_all_backends() {
    // Slice 2b-β-2: `countNeq :: Eq a =>` calls `neq :: Eq a =>` (constrained) —
    // the specialization propagates transitively (countNeq$Int → neq$Int →
    // eq$Int). Interp and --dev agree on 2 (--release in the release_backend_* list).
    for args in [
        vec![fixture("mono_transitive.axi")],
        vec![
            "--backend".into(),
            "cranelift".into(),
            fixture("mono_transitive.axi"),
        ],
    ] {
        let out = axionc().args(&args).output().unwrap();
        assert!(
            out.status.success(),
            "{args:?}: {}",
            String::from_utf8_lossy(&out.stderr)
        );
        assert_eq!(String::from_utf8_lossy(&out.stdout), "2\n", "{args:?}");
    }
}

#[test]
fn typeclass_constraints_are_checked_at_use_site() {
    // Slice 2b-i: static checking of constraints at the use site.
    let reject = |fx: &str, code: &str| {
        let out = axionc().args(["--check", &fixture(fx)]).output().unwrap();
        assert!(!out.status.success(), "{fx} should fail");
        let text = String::from_utf8_lossy(&out.stdout);
        assert!(text.contains(code), "{fx}: expected {code}, output: {text}");
    };
    reject("tc_no_instance.axi", "AX0404"); // method over a concrete type with no instance
    reject("tc_unconstrained_method.axi", "AX0405"); // polymorphic use without a constraint

    // Positive: with `Eq a =>` declared, it compiles and resolves to the instance (→ True).
    let out = axionc()
        .arg(fixture("tc_constraint_ok.axi"))
        .output()
        .unwrap();
    assert!(
        out.status.success(),
        "tc_constraint_ok: {}",
        String::from_utf8_lossy(&out.stderr)
    );
    assert_eq!(String::from_utf8_lossy(&out.stdout), "true\n");
}

#[test]
fn float_arithmetic_agrees_across_backends() {
    // §4 (Float): `f64` carried as its bit-pattern in the i64 ABI; the distinct
    // operators `+. -. *. /.` bitcast i64↔f64. The interpreter uses real f64.
    // All three executors must agree.
    for (fx, expected) in [
        ("float_arith.axi", "7.5\n"),
        ("float_divsub.axi", "2\n"),
        // comparisons (`<.`) inside an `if`, and Int↔Float conversions
        // (`toFloat`/`truncate`): all three executors must agree.
        ("float_compare.axi", "1\n"),
        ("float_convert.axi", "3\n"),
    ] {
        let interp = axionc().arg(fixture(fx)).output().unwrap();
        assert!(
            interp.status.success(),
            "{fx} interp: {}",
            String::from_utf8_lossy(&interp.stderr)
        );
        assert_eq!(
            String::from_utf8_lossy(&interp.stdout),
            expected,
            "{fx} interp"
        );

        let cranelift = axionc()
            .args(["--backend", "cranelift", &fixture(fx)])
            .output()
            .unwrap();
        assert!(
            cranelift.status.success(),
            "{fx} cranelift: {}",
            String::from_utf8_lossy(&cranelift.stderr)
        );
        assert_eq!(
            String::from_utf8_lossy(&cranelift.stdout),
            expected,
            "{fx} cranelift"
        );

        let llvm = axionc().args(["--release", &fixture(fx)]).output().unwrap();
        assert!(
            llvm.status.success(),
            "{fx} llvm: {}",
            String::from_utf8_lossy(&llvm.stderr)
        );
        assert_eq!(String::from_utf8_lossy(&llvm.stdout), expected, "{fx} llvm");
    }
}

#[test]
fn float_operators_do_not_apply_to_int() {
    // The distinct float operators are type-directed: `Int +. Int` must be
    // rejected by inference (Float and Int are distinct types).
    let out = axionc()
        .args(["--check", &fixture("float_type_mismatch.axi")])
        .output()
        .unwrap();
    assert!(!out.status.success(), "expected a type error");
    let text = String::from_utf8_lossy(&out.stdout);
    assert!(
        text.contains("Float") && text.contains("Int"),
        "expected a Float/Int mismatch, output: {text}"
    );
}

/// Runs `fx` on all three executors (interp, --backend cranelift, --release)
/// and asserts they all print `expected`.
fn agree_across_backends(fx: &str, expected: &str) {
    let interp = axionc().arg(fixture(fx)).output().unwrap();
    assert!(
        interp.status.success(),
        "{fx} interp: {}",
        String::from_utf8_lossy(&interp.stderr)
    );
    assert_eq!(
        String::from_utf8_lossy(&interp.stdout),
        expected,
        "{fx} interp"
    );
    let cl = axionc()
        .args(["--backend", "cranelift", &fixture(fx)])
        .output()
        .unwrap();
    assert!(
        cl.status.success(),
        "{fx} cranelift: {}",
        String::from_utf8_lossy(&cl.stderr)
    );
    assert_eq!(
        String::from_utf8_lossy(&cl.stdout),
        expected,
        "{fx} cranelift"
    );
    let llvm = axionc().args(["--release", &fixture(fx)]).output().unwrap();
    assert!(
        llvm.status.success(),
        "{fx} llvm: {}",
        String::from_utf8_lossy(&llvm.stderr)
    );
    assert_eq!(String::from_utf8_lossy(&llvm.stdout), expected, "{fx} llvm");
}

/// Drift guard: run `fx` on both NATIVE backends and assert their stdout is
/// identical — the `--dev` Cranelift JIT uses the Rust runtime reimpls
/// (`codegen.rs`), `--release` uses the C runtime (`axion_rt.c`). The two are
/// maintained separately (the price of a C-toolchain-free `--dev`), so any silent
/// divergence must fail loudly. No hardcoded expected value: the guarantee is that
/// the two runtimes *match*, whatever they compute.
fn native_agree(fx: &str) {
    let cl = axionc()
        .args(["--backend", "cranelift", &fixture(fx)])
        .output()
        .unwrap();
    assert!(
        cl.status.success(),
        "{fx} cranelift: {}",
        String::from_utf8_lossy(&cl.stderr)
    );
    let rel = axionc().args(["--release", &fixture(fx)]).output().unwrap();
    assert!(
        rel.status.success(),
        "{fx} release: {}",
        String::from_utf8_lossy(&rel.stderr)
    );
    let (a, b) = (
        String::from_utf8_lossy(&cl.stdout),
        String::from_utf8_lossy(&rel.stdout),
    );
    assert!(!a.trim().is_empty(), "{fx}: empty output");
    assert_eq!(
        a, b,
        "{fx}: RUNTIME DRIFT — --dev (Rust runtime) {a:?} != --release (C runtime) {b:?}"
    );
}

#[test]
fn runtime_backends_agree() {
    // The C (--release, axion_rt.c) and Rust (--dev, codegen.rs) runtimes are
    // duplicated by design; this guards them against silent drift by exercising the
    // drift-prone deterministic compute ops over broad/edge inputs (int reductions
    // crossing the i8DotI8 int32-block boundary, the matvecs with wrapping K, the
    // base-243 codec across byte boundaries) and asserting both backends agree.
    for fx in [
        "drift_reductions.axi",
        "drift_matvec.axi",
        "drift_codec.axi",
    ] {
        native_agree(fx);
    }
}

#[test]
fn strict_let_binding_is_shared_not_re_evaluated() {
    // `let x = e in …` must evaluate `e` once (strict / call-by-value): the fixture
    // doubles through a shared binding, so it is O(n); re-evaluating per use would be
    // O(2^n) and hang the interpreter. 2^20 == 1048576 on all three backends.
    agree_across_backends("let_sharing.axi", "1048576\n");
}

#[test]
fn where_local_captures_enclosing_parameter() {
    // A `where`-local referencing an enclosing parameter is lambda-lifted with that
    // parameter threaded in (native) / closed over (interp). Regression: native used
    // to reject it ("variable 'm' not bound in the Core").
    agree_across_backends("where_capture.axi", "99\n");
}

#[test]
fn nullary_toplevel_caf_is_called_by_reference() {
    // A bare reference to a nullary top-level binding is a zero-arg call, not a free
    // variable. Regression: native used to reject it ("variable 'x' not bound").
    agree_across_backends("toplevel_caf.axi", "42\n");
}

#[test]
fn rsa_modexp_round_trips_on_all_backends() {
    // Capstone: textbook RSA over arbitrary-precision Integer with the private key
    // derived in-language (extended-Euclid modular inverse). Jointly exercises strict
    // `let` sharing, `where`-capture of an enclosing param, nullary CAF references, a
    // param shadowing a same-named CAF, and bignum ×/div/mod/==. Decrypt∘encrypt = 42.
    agree_across_backends(
        "rsa_modexp.axi",
        "2753\n1000000016000000063\n648946405777194593\n42\n",
    );
}

#[test]
fn integer_literal_patterns_match_by_bignum() {
    // Num-polymorphic literal patterns at Integer (`fib 0`/`fib 1`, `case n of 0 ->`)
    // match by arbitrary-precision equality on all backends. Regression: native used
    // to compare the boxed pointer to an i64 (never matched → wrong result / infinite
    // recursion). fib 30 = 832040, classify 0 = 100, classify 21 = 42.
    agree_across_backends("integer_literal_pattern.axi", "832040\n100\n42\n");
}

#[test]
fn derived_show_parenthesizes_compound_arguments() {
    // Derived `Show` wraps a constructor-with-args in parens via the `showArg`
    // method, so nested terms are unambiguous. Regression: previously
    // `Node (Node Leaf 1 Leaf) …` printed as `Node Node Leaf 1 Leaf …`.
    agree_across_backends(
        "derive_show_nested.axi",
        "Node (Node Leaf 1 Leaf) 2 (Node Leaf 3 Leaf)\n",
    );
}

#[test]
fn derived_show_nested_parametric_instantiation_compiles_native() {
    // A derived method used at a NESTED parametric type (`show (Some (Some 3))` at
    // `Option (Option Int)`) monomorphizes natively: the outer spec
    // `show$Option$Option$Int` is seeded with the FULL element-type key (`Option$Int`,
    // not just the head `Option`), and the inner parametric method `showArg$Option$Int`
    // is materialized transitively. Regression: only the flat `show$Option$Int` was
    // seeded, so the outer spec was missing and `main` fell out of the native subset.
    agree_across_backends(
        "derive_show_nested_param.axi",
        "Some (Some 3)\nSome (Some (Some true))\n",
    );
}

#[test]
fn unused_linear_param_is_reclaimed() {
    // An owned `%1` parameter a function never uses is dropped at the function
    // entry (Auto-Drop), not leaked. Regression: the use-driven drop insertion had
    // no last-use to hang the drop on, so `consume xs = 0` left `xs` un-dropped —
    // a total leak (N allocs, 0 frees). Leak-freedom pinned by the LSan gate.
    agree_across_backends("unused_linear_param_reclaim.axi", "0\n");
}

#[test]
fn generic_container_reclaims_heap_elements() {
    // A `case` on a concrete `Lst Box` value reclaims the element and recursive-spine
    // field drops via the monomorphic destructor `axion_drop_Lst$Box` (resolved from
    // the scrutinee's concrete key), not the generic `axion_drop_Lst` that leaked the
    // `Box` payloads. `Lst Int` still does not deep-drop its scalars (no corruption).
    // Leak-freedom pinned by `native_runtime_is_leak_free_under_lsan`.
    agree_across_backends("poly_element_reclaim.axi", "1\n");
}

#[test]
fn refutable_single_clause_head_is_interpreter_only() {
    // A single-clause function with a REFUTABLE head (`fromJust (Just x) = x` — a
    // Con of a multi-constructor type) is a partial function; there is no
    // clause-head exhaustiveness check, so it must be EXCLUDED from native, never
    // destructured (matching `Nothing` as `Just` is memory-unsafe; an Int literal
    // head would drop the comparison). Interpreter runs it; `--backend` fails loudly.
    let fx = fixture("refutable_head_interp_only.axi");
    let interp = axionc().arg(&fx).output().unwrap();
    assert_eq!(String::from_utf8_lossy(&interp.stdout), "5\n");
    let native = axionc()
        .args(["--backend", "cranelift", &fx])
        .output()
        .unwrap();
    assert!(
        !native.status.success(),
        "a refutable single-clause head must fail natively, not miscompile"
    );
}

#[test]
fn multiclause_constructor_head_is_interpreter_only() {
    // A multi-clause function matching constructors in its head (`fj Nothing = 0;
    // fj (Just x) = x`) is the documented `case`-in-body limitation. The if-chain
    // desugar dispatches only on Int literals, not Con tags, so native SILENTLY
    // returned clause 0 (`fj (Just 5)` → 0, a miscompile). It is now excluded from
    // native; the interpreter returns the correct 5, `--backend` fails loudly.
    let fx = fixture("multiclause_con_head_interp_only.axi");
    let interp = axionc().arg(&fx).output().unwrap();
    assert_eq!(String::from_utf8_lossy(&interp.stdout), "5\n");
    let native = axionc()
        .args(["--backend", "cranelift", &fx])
        .output()
        .unwrap();
    assert!(
        !native.status.success(),
        "a multi-clause constructor head must fail natively, not silently return clause 0"
    );
}

#[test]
fn single_clause_head_pattern_destructures_natively() {
    // A single-clause function may destructure a `Con`/`Tuple` parameter in its
    // head (`label (Named s k) = …`); the field variables must be bound in native
    // Core. Regression: the multi-clause `if`-chain desugar bound only `Var` params,
    // so the fields were left unbound → "variable not bound" on cranelift/llvm.
    agree_across_backends("head_pattern_destructure.axi", "hi!\n42\n17\n");
}

#[test]
fn conditionally_escaping_owned_param_is_reclaimed() {
    // A `headOr`/`getOrElse`-shaped function returns its owned heap default in one
    // `case` arm (escapes) but leaves it dead in another, where the main
    // reclamation's branch-insensitive escape set never dropped it (a leak).
    // `reclaim_cond_escape` drops it in the arm where its name is absent — no leak,
    // no double-free. (Leak-freedom pinned by `native_runtime_is_leak_free_under_lsan`.)
    agree_across_backends("cond_escape_reclaim.axi", "1\n8\n");
}

#[test]
fn native_strings_are_reclaimed_not_leaked() {
    // Native strings carry a size-header (§tc): heap strings (show/strAppend, via
    // axion_alloc) have a nonzero header, static literals a zero header, so
    // `axion_str_drop` frees the former and skips the latter — every String
    // reclaimed once, no double-free of a literal's rodata. (Leak-freedom is pinned
    // by `native_runtime_is_leak_free_under_lsan`.)
    agree_across_backends(
        "string_reclaim.axi",
        "literal\nhi bob\n10000\nconst\nyes\nhi 5\nhi 4\nhi 3\nhi 2\nhi 1\n",
    );
}

#[test]
fn consume_inferred_returned_element_is_not_double_freed() {
    // A monomorphic `head`-like function returning an extracted heap element gets
    // its `List Box` param inferred `%1`, so the caller does not free the returned
    // element (which aliases the list). Regression: this double-freed on native
    // (SIGABRT) when the param was treated as a borrow. All backends agree on 5.
    agree_across_backends("consume_returns_element.axi", "5\n");
}

#[test]
fn where_local_aliasing_result_is_not_reclaimed() {
    // Safety: a `where`-local that returns an element of its borrowed argument must
    // NOT be treated as a pure borrow — otherwise the parent frees the list and the
    // returned element is double-freed. The heap result disqualifies it; all
    // backends must agree on 5 (native would abort on a double-free).
    agree_across_backends("where_alias_returns_element.axi", "5\n");
}

#[test]
fn stream_fusion_agrees_across_backends() {
    // `--fuse` rewrites `consume (range lo hi)` → `rangeFused lo hi step base`.
    // Regression: (a) the lifted step is a closure (env-first ABI) — without
    // this the Cranelift JIT reads the env as the first arg and returns
    // garbage; (b) the consumer's binder and continuation survive (the fused
    // call must not clobber the rest of the program); (c) `foldr` passes the
    // user's closure through instead of synthesizing `+`; (d) `null`'s nil
    // base is `True`, so an empty range reads `True`. All backends must agree
    // with the unfused result (804) under `--fuse`.
    let fx = fixture("fuse_consumers.axi");
    let variants: [(&str, &[&str]); 3] = [
        ("interp", &[]),
        ("cranelift", &["--backend", "cranelift"]),
        ("llvm", &["--release"]),
    ];
    for (label, extra) in variants {
        let out = axionc()
            .arg("--fuse")
            .args(extra)
            .arg(&fx)
            .output()
            .unwrap();
        assert!(
            out.status.success(),
            "--fuse {label}: {}",
            String::from_utf8_lossy(&out.stderr)
        );
        assert_eq!(
            String::from_utf8_lossy(&out.stdout),
            "804\n",
            "--fuse {label}"
        );
    }
    // the Δ checker must accept the fused Core (the §7 contract — a pass that
    // rewrites the Core re-validates it under the judgment).
    let out = axionc()
        .args(["--fuse", "--check-delta", &fixture("fuse_consumers.axi")])
        .output()
        .unwrap();
    assert!(
        out.status.success(),
        "--fuse --check-delta: {}",
        String::from_utf8_lossy(&out.stderr)
    );
}

#[test]
fn drop_view_agrees_across_backends() {
    // Regression for the `drop` view aliasing: `drop n xs` returns cells
    // shared with `xs` (the `n < 1` arm returns `Cons y ys`, reusing the
    // input), but the caller used to free the input — `xs` is only case-read
    // in the lowered Core, so it was classified as a pure borrow — and the
    // result's destructor double-freed the shared suffix. The fix moves the
    // view argument at the call (like `append`'s second list, whose `ys`
    // param reaches a recursive call): the caller relinquishes the input,
    // the result's destructor reclaims the shared suffix, and the dropped
    // prefix leaks conservatively. All backends must agree on 180
    // (51 + 63 + 66); the Δ checker must accept the moved argument.
    let fx = fixture("drop_view.axi");
    let variants: [(&str, &[&str]); 3] = [
        ("interp", &[]),
        ("cranelift", &["--backend", "cranelift"]),
        ("llvm", &["--release"]),
    ];
    for (label, extra) in variants {
        let out = axionc().args(extra).arg(&fx).output().unwrap();
        assert!(
            out.status.success(),
            "{label}: {}",
            String::from_utf8_lossy(&out.stderr)
        );
        assert_eq!(String::from_utf8_lossy(&out.stdout), "180\n", "{label}");
    }
    let out = axionc()
        .args(["--check-delta", &fixture("drop_view.axi")])
        .output()
        .unwrap();
    assert!(
        out.status.success(),
        "--check-delta: {}",
        String::from_utf8_lossy(&out.stderr)
    );
}

#[test]
fn num_class_unifies_arithmetic_over_int_and_float() {
    // built-in `Num`: the plain operators `+ - *` work on Float (no `+.`),
    // resolved by inference and rewritten to the dotted form for the backends.
    agree_across_backends("num_float_plain.axi", "7.5\n");
    // a `Num a =>` function specializes to both Int (`sq$Int`) and Float
    // (`sq$Float`, with `*` → `*.`): sq 3.0 + sq 2.0 = 13.
    agree_across_backends("num_poly.axi", "13\n");
}

#[test]
fn float_math_builtins_agree_across_backends() {
    // sqrt/floor/abs (Float -> Float) via Cranelift IEEE instructions / LLVM
    // intrinsics. The irrational `sqrt 2.0` also checks that --release prints the
    // shortest round-tripping decimal (like interp/Cranelift), not lossy `%g`.
    agree_across_backends("float_sqrt.axi", "1.4142135623730951\n");
    // floor 3.7 + abs (0.0 - 5.5) = 3.0 + 5.5 = 8.5
    agree_across_backends("float_floor_abs.axi", "8.5\n");
}

#[test]
fn deriving_eq_and_ord_generate_structural_instances() {
    // `deriving (Eq)` / `deriving (Eq, Ord)` synthesize structural instances
    // (nested `case`), agreeing across interp/cranelift/llvm.
    // eq (Rect 2 3) (Rect 2 3) = True; eq (Circle 1) (Rect 0 0) = False → False.
    agree_across_backends("derive_eq.axi", "false\n");
    // le Red Blue = True; maxOr [..] = Blue; le Blue Blue = True → True.
    agree_across_backends("derive_ord.axi", "true\n");
}

#[test]
fn non_exhaustive_case_is_rejected_ax0202() {
    // a `case` on a data type must cover every constructor (or have a wildcard).
    let out = axionc()
        .args(["--check", &fixture("exhaustive_missing.axi")])
        .output()
        .unwrap();
    assert!(!out.status.success(), "expected AX0202");
    let text = String::from_utf8_lossy(&out.stdout);
    assert!(
        text.contains("AX0202") && text.contains("Blue"),
        "expected AX0202 naming Blue, output: {text}"
    );
    // the exhaustive version compiles.
    let ok = axionc()
        .args(["--check", &fixture("exhaustive_ok.axi")])
        .output()
        .unwrap();
    assert!(
        ok.status.success(),
        "exhaustive_ok should compile: {}",
        String::from_utf8_lossy(&ok.stdout)
    );
}

#[test]
fn redundant_pattern_after_catch_all_warns_ax0203() {
    // an arm after a wildcard is unreachable → AX0203 (a warning, still compiles).
    let out = axionc()
        .args(["--check", &fixture("exhaustive_redundant.axi")])
        .output()
        .unwrap();
    assert!(
        out.status.success(),
        "AX0203 is a warning, should still compile"
    );
    let text = String::from_utf8_lossy(&out.stdout);
    assert!(text.contains("AX0203"), "expected AX0203, output: {text}");
}

#[test]
fn nullary_enum_constructors_are_unboxed() {
    // an all-nullary `data` (a C-like enum) is represented by immediate tags —
    // no heap allocation. The result agrees across the three executors, and the
    // Cranelift heap counters prove zero allocations.
    agree_across_backends("enum_unboxed.axi", "1\n");
    let out = axionc()
        .args(["--backend", "cranelift", &fixture("enum_unboxed.axi")])
        .env("AXION_HEAP_STATS", "1")
        .output()
        .unwrap();
    let stats = String::from_utf8_lossy(&out.stderr);
    assert!(
        stats.contains("0 allocs"),
        "expected zero allocations for an enum program, got: {stats}"
    );
}

#[test]
fn nullary_constructors_of_mixed_types_are_unboxed() {
    // in a mixed sum type (some nullary, some with fields), the nullary
    // constructors are tagged immediates — no allocation — while the others stay
    // heap pointers. `Nothing` here never allocates; the low-bit-guarded free /
    // deep-drop keeps it memory-safe (see the sanitizer gate).
    agree_across_backends("mixed_unboxed.axi", "5\n");
    let out = axionc()
        .args(["--backend", "cranelift", &fixture("mixed_unboxed.axi")])
        .env("AXION_HEAP_STATS", "1")
        .output()
        .unwrap();
    let stats = String::from_utf8_lossy(&out.stderr);
    assert!(
        stats.contains("0 allocs"),
        "expected zero allocations (nullary immediates), got: {stats}"
    );
}

#[test]
fn string_and_list_concat_run_natively() {
    // `++` is type-directed: on String it resolves to native concatenation
    // (`strAppend`/axion_strcat), on lists it stays the prelude's `append`.
    // Both agree across interp/cranelift/llvm (String `++` used to SIGSEGV
    // natively).
    agree_across_backends("str_concat.axi", "n=42!\n");
    agree_across_backends("list_concat.axi", "10\n");
}

#[test]
fn deriving_show_renders_constructors_and_fields() {
    // `deriving (Show)` renders the constructor name then each field via `show`
    // (native string concat `strAppend`), agreeing across the three executors.
    agree_across_backends("derive_show_enum.axi", "Green\n");
    agree_across_backends("derive_show.axi", "Rect 2 3\n");
}

#[test]
fn trit_enum_is_a_prelude_ternary_sum_type() {
    // Trit (spec §10.A) is an ordinary N=3 sum type in the prelude: a
    // value-selecting `case` maps the three variants to their ternary weights
    // (-1/0/+1) and sums to 0, branchless, agreeing across the three executors.
    agree_across_backends("trit_enum.axi", "0\n");
}

#[test]
fn deriving_works_for_parametric_types() {
    // `deriving` on a parametric type generates constrained instances
    // (`instance Eq a => Eq (Maybe a)`); a use at a concrete element specializes
    // the impl (`show$Maybe$Color`, inner `show` → `show$Color`) and runs
    // natively, agreeing across the three executors — including nesting.
    agree_across_backends("derive_parametric.axi", "Some Green\n");
    agree_across_backends("derive_parametric_ord.axi", "true\n");
}

#[test]
fn main_bool_prints_natively() {
    // `main :: Bool` prints `true`/`false` on all three executors (the native
    // backends print an i64 0/1 by selecting the two string constants), matching
    // the interpreter — no `if … then 1 else 0` workaround needed.
    agree_across_backends("bool_true.axi", "true\n");
    agree_across_backends("bool_false.axi", "false\n");
}

#[test]
fn ord_class_unifies_comparisons_over_int_and_float() {
    // built-in `Ord`: the plain comparisons `== < >` work on Float (no `<.`),
    // resolved by inference and rewritten to the dotted form for the backends.
    agree_across_backends("ord_float_compare.axi", "1\n");
    // an `Ord a =>` function specializes to Float (`maxOf$Float`, `<` → `<.`):
    // maxOf 3.0 5.0 + maxOf 1.0 2.0 = 5.0 + 2.0 = 7.
    agree_across_backends("ord_poly.axi", "7\n");
    // the prelude's `Ord` (maxOr / le) now has a Float instance — le is defined
    // via `<`/`==`, which are unified: maxOr 0.0 [3.0,7.0,2.0] = 7.
    agree_across_backends("ord_prelude_float.axi", "7\n");
}

#[test]
fn num_arithmetic_does_not_mix_int_and_float() {
    // `Num` does not coerce: `Int + Float` stays a type error (no implicit
    // conversion — use `toFloat`/`truncate`).
    let out = axionc()
        .args(["--check", &fixture("num_mixed_mismatch.axi")])
        .output()
        .unwrap();
    assert!(!out.status.success(), "expected a type error");
    let text = String::from_utf8_lossy(&out.stdout);
    assert!(
        text.contains("Int") && text.contains("Float"),
        "expected an Int/Float mismatch, output: {text}"
    );
}
