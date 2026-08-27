//! `axionc` — Axion's compiler (§17–18).
//!
//! Pipeline: source `.axi` → lexer (logos) → layout → parser → checking
#![allow(unreachable_pub)]
#![allow(
    clippy::cast_possible_truncation,
    clippy::cast_possible_wrap,
    clippy::cast_sign_loss,
    clippy::multiple_crate_versions,
    clippy::clone_on_ref_ptr,
    clippy::assigning_clones,
    clippy::option_if_let_else,
    let_underscore_drop,
    unused_qualifications
)]
// i64-everywhere ABI: casts are intentional
// `#[cfg(test)]` unit modules use `unwrap`/`expect` (a failing assert IS the test
// result); relax only under the test profile so production code stays strict.
#![cfg_attr(
    test,
    allow(clippy::unwrap_used, clippy::expect_used, clippy::redundant_pub_crate)
)]
// A `--no-default-features` (wasm) build compiles out the CLI + native backends, leaving
// their support code (Emit/Backend, codegen helpers, core IR) legitimately unused. Waive
// dead-code warnings there; the native/default build keeps full checking.
#![cfg_attr(not(feature = "native"), allow(dead_code))]
//! (names + linearity + Auto-Drop) → type inference (HM) → interpreter.
//! Diagnostics with stable `AXnnnn` codes (§8), as text or JSON.
//!
//! Usage:
//!   axionc <file.axi>                compile and run
//!   axionc --check <file.axi>        compile only (parse + typecheck)
//!   axionc --emit json <file>        diagnostics as JSON
//!   axionc --explain AX0001          explain an error code

// The AST model and some diagnostic utilities are deliberately ahead
// of what the walking skeleton consumes (they grow in later phases).
// Compiler internals stay private `mod`: both the `axionc` CLI (`run_cli`) and the
// `axion-lsp` server (`lsp`) live INSIDE this crate and reach them via `crate::`,
// so nothing here is published API — no pub-doc obligations.
#[allow(dead_code)]
mod ast;
mod bigint;
mod check;
#[cfg(feature = "native")]
mod codegen;
mod core;
mod delta;
mod verify;
// `Diagnostic` is re-exported (public API of the engine); its fields carry inline
// comments rather than rustdoc, and its builder methods are used fluently, so waive
// the doc / must-use requirements that only apply now that it is public.
#[allow(dead_code, missing_docs, clippy::return_self_not_must_use)]
mod diag;
#[cfg(feature = "native")]
mod ffi;
mod infer;
mod interp;
mod layout;
mod levels;
mod lexer;
#[cfg(feature = "native")]
mod llvm;
mod parser;
#[cfg(feature = "wasm")]
mod wasm;

/// The salsa incremental query engine (§8), gated behind the `salsa` feature.
#[cfg(feature = "salsa")]
pub mod db;

/// The lossless rowan CST (§8), gated behind the `cst` feature.
#[cfg(feature = "cst")]
pub mod cst;

/// The Language Server (`axion-lsp`), gated behind the `lsp` cargo feature so the
/// default build stays free of the tokio/tower-lsp async dependency tree.
#[cfg(feature = "lsp")]
pub mod lsp;

#[cfg(test)]
mod props;
#[cfg(test)]
mod session;

use diag::Diagnostics;
/// Re-exported so the engine's public `Vec<Diagnostic>` returns are nameable.
pub use diag::Diagnostic;
use lexer::LineMap;
use std::process::ExitCode;

#[derive(PartialEq)]
enum Emit {
    Text,
    Json,
    Drops,
    InPlace,
    Arenas,
    Core,
    Delta,
    Verify,
    Clif,
    Llvm,
}

#[derive(PartialEq)]
enum Backend {
    Interp,
    Cranelift,
    Llvm,
}

/// The `axionc` CLI entry point, living in the library so both the `axionc`
/// binary and the `axion-lsp` binary can share the whole compiler crate. Native
/// only — it drives the Cranelift/LLVM backends and the FFI runtime.
#[cfg(feature = "native")]
pub fn run_cli() -> ExitCode {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let mut check_only = false;
    let mut check_delta = false;
    let mut backend = Backend::Interp;
    let mut emit = Emit::Text;
    let mut path: Option<String> = None;
    let mut fuse = false;
    let mut no_verify = false;
    let mut allow_leaks = false;

    let mut i = 0;
    while i < args.len() {
        match args[i].as_str() {
            "--check" => check_only = true,
            "--check-delta" => check_delta = true,
            "--fuse" => fuse = true,
            "--no-verify" => no_verify = true,
            "--allow-leaks" => allow_leaks = true,
            "--release" => backend = Backend::Llvm,
            "--backend" => {
                i += 1;
                match args.get(i).map(|s| s.as_str()) {
                    Some("cranelift") => backend = Backend::Cranelift,
                    Some("llvm") => backend = Backend::Llvm,
                    Some("interp") => backend = Backend::Interp,
                    _ => {
                        eprintln!("--backend expects 'cranelift', 'llvm' or 'interp'");
                        return ExitCode::from(2);
                    }
                }
            }
            "--emit" => {
                i += 1;
                match args.get(i).map(|s| s.as_str()) {
                    Some("json") => emit = Emit::Json,
                    Some("drops") => emit = Emit::Drops,
                    Some("inplace") => emit = Emit::InPlace,
                    Some("arenas") => emit = Emit::Arenas,
                    Some("core") => emit = Emit::Core,
                    Some("delta") => emit = Emit::Delta,
                    Some("verify") => emit = Emit::Verify,
                    Some("clif") => emit = Emit::Clif,
                    Some("llvm") => emit = Emit::Llvm,
                    _ => {
                        eprintln!(
                            "--emit expects 'json', 'drops', 'inplace', 'arenas', 'core', 'delta', 'clif' or 'llvm'"
                        );
                        return ExitCode::from(2);
                    }
                }
            }
            "--explain" => {
                i += 1;
                let code = args.get(i).cloned().unwrap_or_default();
                return explain(&code);
            }
            "-h" | "--help" => {
                print_usage();
                return ExitCode::SUCCESS;
            }
            other => {
                if other.starts_with('-') {
                    eprintln!("unknown option: {other}");
                    return ExitCode::from(2);
                }
                path = Some(other.to_string());
            }
        }
        i += 1;
    }

    let path = match path {
        Some(p) => p,
        None => {
            print_usage();
            return ExitCode::from(2);
        }
    };

    let src = match std::fs::read_to_string(&path) {
        Ok(s) => s,
        Err(e) => {
            eprintln!("could not read {path}: {e}");
            return ExitCode::from(2);
        }
    };

    let lines = LineMap::new(&src);
    let mut diags = Diagnostics::new();
    let (module, analysis) = compile_front(&src, &path, &mut diags);

    // report diagnostics
    if emit == Emit::Json {
        println!(
            "{}",
            serde_json::to_string_pretty(&diags.items).unwrap_or_default()
        );
    } else {
        for d in &diags.items {
            print!("{}", d.render(&path, &src, &lines));
        }
    }

    if diags.has_errors() {
        return ExitCode::FAILURE;
    }

    if emit == Emit::Drops {
        print_drops(&analysis.drops, &path, &lines);
        return ExitCode::SUCCESS;
    }
    if emit == Emit::InPlace {
        print_inplace(&analysis.inplace, &path, &lines);
        return ExitCode::SUCCESS;
    }
    if emit == Emit::Arenas {
        print_arenas(&analysis.arenas, &path, &lines);
        return ExitCode::SUCCESS;
    }

    let module = match module {
        Some(m) => m,
        None => return ExitCode::FAILURE,
    };

    // spans of the `RecordUpd`s eligible for in-place mutation (Linear Elision, §2),
    // which the backends use to mutate the block instead of alloc+copy.
    let inplace: std::collections::HashSet<(usize, usize)> =
        analysis.inplace.iter().map(|ip| ip.span).collect();

    // --- Axion Core IR: dump da baixada ANF (partilhada pelos backends) ---
    if check_delta {
        // Δ-1 (report-only): the linearity judgment over the annotated Core,
        // plus the Δ-3 coherence cross-check against the front-end DropPoints.
        let lowered = core::lower_with(
            &module,
            &inplace,
            &analysis.makecon_tys,
            &analysis.array_tys,
            &analysis.integer_lits,
            &analysis.consume_native_exempt,
            fuse,
        );
        let mut errs = delta::check_all(&lowered.fns, &lowered.borrow_args, &lowered.recinfo);
        errs.extend(delta::check_drop_coherence(
            &lowered.fns,
            &lowered.borrow_args,
            &lowered.recinfo,
            &analysis.drops,
        ));
        if errs.is_empty() {
            println!("Δ ok: the Core satisfies the linearity judgment.");
            return ExitCode::SUCCESS;
        }
        for e in &errs {
            // Δ-5: span-ful diagnostics — the violation's anchor rendered
            // `path:line:col` plus the source line, like the front-end diags.
            match e.span {
                Some(sp) if sp != core::NO_SPAN => {
                    let (l, c) = lines.pos(sp.0);
                    let line = src.lines().nth(l.saturating_sub(1)).unwrap_or("");
                    eprintln!("Δ {}: {}  @ {path}:{l}:{c}: {line}", e.func, e.msg);
                }
                _ => eprintln!("Δ {}: {}", e.func, e.msg),
            }
        }
        eprintln!("Δ FAILED: {} violation(s).", errs.len());
        return ExitCode::FAILURE;
    }

    if emit == Emit::Core {
        // Δ-2: the annotated dump — `core::dump` plus the live-resource env
        // (Δ) on every `let`/`ret` (report-only; same output shape as `dump`
        // for unannotated lines).
        let lowered = core::lower_with(
            &module,
            &inplace,
            &analysis.makecon_tys,
            &analysis.array_tys,
            &analysis.integer_lits,
            &analysis.consume_native_exempt,
            fuse,
        );
        print!(
            "{}",
            delta::dump_annotated(&lowered.fns, &lowered.borrow_args, &lowered.recinfo)
        );
        return ExitCode::SUCCESS;
    }

    if emit == Emit::Verify {
        // Drop-balance verifier (translation validation): re-derives the linear-resource
        // discipline over the FINAL drop-inserted Core and reports any double-free /
        // use-after-free / unbalanced / leak. A soundness net under Auto-Drop.
        let lowered = core::lower_with(
            &module,
            &inplace,
            &analysis.makecon_tys,
            &analysis.array_tys,
            &analysis.integer_lits,
            &analysis.consume_native_exempt,
            fuse,
        );
        let findings = verify::verify(&lowered);
        let corruption = findings.iter().filter(|f| f.cat.is_corruption()).count();
        let leaks = findings.len() - corruption;
        for f in &findings {
            println!("{:?}: `{}` in `{}` @{}..{}", f.cat, f.var, f.func, f.span.0, f.span.1);
        }
        if corruption == 0 {
            println!("ok: no corruption findings ({leaks} leak note(s))");
        } else {
            println!("FAIL: {corruption} corruption finding(s)");
        }
        return if corruption == 0 {
            ExitCode::SUCCESS
        } else {
            ExitCode::FAILURE
        };
    }

    if emit == Emit::Delta {
        // Δ-4: the judgment's per-function verdicts plus the resource-life
        // facts the annotated dump cannot show (drops in the judged Core,
        // never-used `%1` params, coherence agreement). Report-only: the exit
        // code is unaffected — `--check-delta` is the verdict channel.
        let lowered = core::lower_with(
            &module,
            &inplace,
            &analysis.makecon_tys,
            &analysis.array_tys,
            &analysis.integer_lits,
            &analysis.consume_native_exempt,
            fuse,
        );
        print!(
            "{}",
            delta::dump_delta(
                &lowered.fns,
                &lowered.borrow_args,
                &lowered.recinfo,
                &analysis.drops,
                &lines,
                &src,
            )
        );
        return ExitCode::SUCCESS;
    }

    // Drop-balance verifier (default-on, translation validation): before ANY native
    // backend emits code, prove the Auto-Drop output frees each heap resource exactly once
    // and never after free. A corruption finding is a soundness violation in the
    // reclamation pass — refuse to emit rather than produce a double-free / use-after-free.
    // `--no-verify` bypasses it (an escape hatch for a suspected false positive; it does
    // NOT make the program safe, it only silences the gate). Interp is not gated — it does
    // no manual reclamation. The `--emit core/drops/delta/verify` inspection modes returned
    // earlier, so they are unaffected.
    if !no_verify
        && (emit == Emit::Clif
            || emit == Emit::Llvm
            || backend == Backend::Cranelift
            || backend == Backend::Llvm)
    {
        let lowered = core::lower_with(
            &module,
            &inplace,
            &analysis.makecon_tys,
            &analysis.array_tys,
            &analysis.integer_lits,
            &analysis.consume_native_exempt,
            fuse,
        );
        let all = verify::verify(&lowered);
        let corruption: Vec<_> = all.iter().filter(|f| f.cat.is_corruption()).collect();
        if !corruption.is_empty() {
            for f in &corruption {
                let d = Diagnostic::error(
                    "AX0910",
                    format!("unsound reclamation: {:?} of `{}` in `{}`", f.cat, f.var, f.func),
                )
                .label(f.span.0, f.span.1, "the Auto-Drop-inserted `free`s are not balanced here")
                .with_help(
                    "the drop-balance verifier proved the emitted native code would \
                     double-free or use-after-free (a compiler soundness check). This is \
                     an Auto-Drop bug; pass --no-verify to emit anyway.",
                );
                eprint!("{}", d.render(&path, &src, &lines));
            }
            return ExitCode::FAILURE;
        }
        // Leak gate (second hard guarantee): a heap resource Auto-Drop never frees. Gated
        // unless `--allow-leaks` (keeps corruption checking) or `--no-verify` (bypasses all).
        // Whitelisted synthetic sites (session/parmap `*$step`, polymorphic elements) are
        // excluded by `verify::leak_gates` — those are the documented conservative leaks.
        let leaks: Vec<_> = all.iter().filter(|f| verify::leak_gates(f)).collect();
        if !allow_leaks && !leaks.is_empty() {
            for f in &leaks {
                let d = Diagnostic::error(
                    "AX0911",
                    format!("memory leak: `{}` in `{}` is never freed", f.var, f.func),
                )
                .label(f.span.0, f.span.1, "this heap resource escapes every path without being reclaimed")
                .with_help(
                    "the drop-balance verifier proved the emitted native code leaks this \
                     allocation (an Auto-Drop gap). Pass --allow-leaks to emit anyway (still \
                     checks for corruption), or --no-verify to bypass the verifier entirely.",
                );
                eprint!("{}", d.render(&path, &src, &lines));
            }
            return ExitCode::FAILURE;
        }
    }

    // --- native --dev backend (Cranelift): IR dump or JIT+run main::Int ---
    if emit == Emit::Clif {
        match codegen::emit_ir(&module, &inplace, fuse, &analysis.makecon_tys, &analysis.integer_lits, &analysis.consume_native_exempt) {
            Ok(ir) => {
                print!("{ir}");
                return ExitCode::SUCCESS;
            }
            Err(e) => {
                eprintln!("codegen: {e}");
                return ExitCode::FAILURE;
            }
        }
    }
    // --- backend --release (LLVM): dump do IR ou compilar+correr ---
    if emit == Emit::Llvm {
        match llvm::emit_ir(&module, &inplace, fuse, &analysis.makecon_tys, &analysis.integer_lits, &analysis.consume_native_exempt) {
            Ok(ir) => {
                print!("{ir}");
                return ExitCode::SUCCESS;
            }
            Err(e) => {
                eprintln!("llvm: {e}");
                return ExitCode::FAILURE;
            }
        }
    }
    if backend == Backend::Cranelift {
        return match codegen::run(&module, "main", &inplace, fuse, &analysis.makecon_tys, &analysis.integer_lits, &analysis.consume_native_exempt) {
            Ok(Some(n)) => {
                println!("{n}");
                ExitCode::SUCCESS
            }
            Ok(None) => ExitCode::SUCCESS, // main :: IO () — already printed
            Err(e) => {
                eprintln!("cranelift backend: {e}");
                ExitCode::FAILURE
            }
        };
    }
    if backend == Backend::Llvm {
        return match llvm::build_and_run(&module, "main", &inplace, fuse, &analysis.makecon_tys, &analysis.integer_lits, &analysis.consume_native_exempt) {
            Ok(()) => ExitCode::SUCCESS, // the binary already printed the result
            Err(e) => {
                eprintln!("llvm backend (--release): {e}");
                ExitCode::FAILURE
            }
        };
    }

    if check_only {
        if emit == Emit::Text {
            eprintln!("ok: {path} compiles (parse + typecheck + linearity + Auto-Drop).");
        }
        return ExitCode::SUCCESS;
    }

    // Run the interpreter on a large-stack thread (like the native backends) so
    // deep recursion doesn't overflow the small default stack. The whole run
    // happens inside the thread — its `Rc` values never cross the boundary.
    let result = std::thread::scope(|s| {
        std::thread::Builder::new()
            .stack_size(codegen::EVAL_STACK_SIZE)
            .spawn_scoped(s, || interp::run(&module))
            .map_err(|e| format!("spawn interp thread: {e}"))?
            .join()
            .map_err(|_| "interp thread panicked".to_string())
    });
    match result {
        Ok(Ok(())) => ExitCode::SUCCESS,
        Ok(Err(e)) => {
            eprintln!("runtime error: {e}");
            ExitCode::FAILURE
        }
        Err(_) => {
            eprintln!("interp thread panicked");
            ExitCode::FAILURE
        }
    }
}

/// Runs the front-end (lex → layout → parse → check → infer), accumulating
/// diagnostics and returning the `free`s inserted by Auto-Drop.
/// Scan the raw source for a `{-# LEVEL Ln #-}` pragma (§8) and return the ceiling
/// `n`. A malformed `{-# LEVEL … #-}` yields a warning and is ignored (no ceiling).
/// Done here (not in the grammar) because the lexer skips `{-# … #-}` entirely.
fn scan_level_pragma(src: &str, diags: &mut Diagnostics) -> Option<u8> {
    let start = src.find("{-#")?;
    let rest = src.get(start + 3..)?; // `.get` (not `[..]`) keeps clippy `string_slice` happy
    let end_rel = rest.find("#-}")?;
    let inner = rest.get(..end_rel)?.trim();
    let mut words = inner.split_whitespace();
    if words.next() != Some("LEVEL") {
        return None; // some other pragma — not ours
    }
    let end = start + 3 + end_rel + 3;
    let bad = |diags: &mut Diagnostics| {
        diags.push(
            Diagnostic::warning("AX0500", "malformed `{-# LEVEL … #-}` pragma — ignored")
                .label(start, end, "expected `{-# LEVEL L0 #-}` … `{-# LEVEL L3 #-}`"),
        );
    };
    let Some(tok) = words.next() else {
        bad(diags);
        return None;
    };
    if words.next().is_some() {
        bad(diags);
        return None;
    }
    let digits = tok.strip_prefix('L').unwrap_or(tok);
    match digits.parse::<u8>() {
        Ok(n @ 0..=3) => Some(n),
        _ => {
            bad(diags);
            None
        }
    }
}

/// All whole-module front-end diagnostics for a source. The reference the salsa
/// engine's incremental decomposition (`crate::db`) is differential-tested against.
pub fn compile_diagnostics(src: &str, path: &str) -> Vec<Diagnostic> {
    let mut diags = Diagnostics::new();
    let _ = compile_front(src, path, &mut diags);
    diags.items
}

/// The front end: source → lexer → layout → parser → prelude/imports → class
/// lowering → linearity/Auto-Drop checking → HM inference. Diagnostics are pushed
/// into `diags`; the returned `Module`/`Analysis` are `Some` when the front end got
/// far enough for a backend to consume them. Shared by the CLI and `axion-lsp`.
pub fn compile_front(
    src: &str,
    path: &str,
    diags: &mut Diagnostics,
) -> (Option<ast::Module>, check::Analysis) {
    // Two stages, split so the salsa engine can memoize them independently
    // (`crate::db`): `parse_source` depends only on THIS file's text; the
    // downstream `analyze_module` also depends on the prelude and imports.
    match parse_source(src, diags) {
        Some(module) => {
            let (module, analysis) = analyze_module(module, path, diags);
            (Some(module), analysis)
        }
        None => (None, check::Analysis::default()),
    }
}

/// Stage 1 — the pure, single-file front: lex → layout → parse → `{-# LEVEL #-}`
/// scan + ceiling check. Depends only on `src`, so the salsa `parse` query can
/// memoize it per file text. Returns `None` (with a diagnostic) on lex/parse error.
pub fn parse_source(src: &str, diags: &mut Diagnostics) -> Option<ast::Module> {
    // THE FLIP (§8): the token-driven rowan CST parser is the primary front-end. It is
    // proven BYTE-EXACT with the recursive-descent parser over every fixture — spans
    // included (spans are semantic keys downstream: `array_tys`/`makecon_tys` mono maps,
    // diagnostic rendering), which is what previously blocked the flip. A fully clean
    // parse routes through it; a malformed file (or a build without the `cst` feature)
    // falls through to the recursive-descent parser for declaration-level recovery and
    // parse-error diagnostics.
    #[cfg(feature = "cst")]
    if let Some(mut module) = cst::parse_module_full(src) {
        module.level_ceiling = scan_level_pragma(src, diags);
        levels::check_levels(&module, diags);
        return Some(module);
    }
    let tokens = match lexer::lex(src) {
        Ok(t) => t,
        Err(e) => {
            diags.push(Diagnostic::error("AX0100", "unexpected character").label(
                e.start,
                e.end,
                "not part of any token",
            ));
            return None;
        }
    };
    let lines = LineMap::new(src);
    let ltokens = layout::layout(&tokens, &lines);
    // Declaration-level error recovery (§8): a malformed declaration is reported but
    // the rest of the file still parses. `None` only when nothing at all parsed.
    //
    // NOTE: the token-driven rowan CST parser (`cst::parse_module_full`) is proven
    // structurally equivalent to this parser over every fixture, but the pipeline is
    // NOT yet flipped onto it — spans are SEMANTIC keys here (the `array_tys`/
    // `makecon_tys` mono maps are keyed by span, and diagnostics render spans), so the
    // flip additionally needs the CST lowering to reproduce this parser's span
    // conventions byte-for-byte. That is the remaining work.
    let (mut module, parse_errors) = parser::parse_module_resilient(&ltokens);
    let recovered = !parse_errors.is_empty();
    for d in parse_errors {
        diags.push(d);
    }
    if recovered && module.funcs.is_empty() && module.datas.is_empty() && module.classes.is_empty()
    {
        return None;
    }
    // §8 progressive-disclosure ceiling: scan the raw source for `{-# LEVEL Ln #-}`
    // (the lexer skips the pragma, so the grammar never sees it) and enforce it over
    // the user's *own* declarations — this depends only on this file, so it stays in
    // the memoizable parse stage.
    module.level_ceiling = scan_level_pragma(src, diags);
    levels::check_levels(&module, diags);
    Some(module)
}

/// Stage 2 — the cross-file downstream: imports + prelude + class lowering +
/// linearity/Auto-Drop checking + HM inference. Takes an already-parsed module.
pub fn analyze_module(
    module: ast::Module,
    path: &str,
    diags: &mut Diagnostics,
) -> (ast::Module, check::Analysis) {
    // the user's own top-level functions — the DCE roots. Captured BEFORE the
    // prelude is injected, so everything the prelude/deriving/specialization adds is
    // kept only if reachable from user code.
    let user_fns: std::collections::HashSet<String> =
        module.funcs.iter().map(|f| f.name.clone()).collect();
    let (mut module, consume_exempt) = prepare_for_check(module, path, diags);
    let mut analysis = check::check(&module, diags);
    analysis.consume_native_exempt = consume_exempt;
    // Inference returns the monomorphic method resolutions (use span →
    // concrete instance implementation). We rewrite them as direct
    // calls (`eq 3 3` → `eq$Int 3 3`): monomorphization — the use
    // stops being a method (dynamic dispatch) and now compiles natively.
    let mono = infer::infer(&module, diags);
    resolve_methods(&mut module, &mono.resolutions);
    rewrite_int_lits(&mut module, &mono.integer_lits);
    materialize_specs(&mut module, &mono.specs);
    // Monomorphic `show`/`showArg` synthesized for tuples and multi-param derived
    // data (no usable nominal instance to specialize). Injected after
    // inference/specialization; `insert_drops` (core lowering) reclaims the cell +
    // heap fields.
    module.funcs.extend(mono.synth_shows);
    analysis.makecon_tys = mono.makecon_tys;
    analysis.array_tys = mono.array_tys;
    analysis.integer_lits = mono.integer_lits;
    // Dead-code elimination: drop prelude / generated functions the program never
    // reaches. Runs LAST, so the graph is final (methods resolved, specs + synth
    // materialized, `deriving` lowered). Keeps the emitted Core — and the oracle /
    // Δ-view — to what a program actually uses, so adding an unused prelude function
    // no longer perturbs every fixture.
    dce_functions(&mut module, &user_fns);
    (module, analysis)
}

/// Removes functions unreachable from the user's own top-level functions
/// (`roots`). References are the `Var`s and infix operators in every kept
/// function's body (`++` → `append`; a backtick-infix's operator IS the callee).
/// If `range` survives, the always-on stream-fusion pass may introduce
/// `rangeFused`/`rangeFusedSum` at lowering time, so those are kept too.
fn dce_functions(module: &mut ast::Module, roots: &std::collections::HashSet<String>) {
    use std::collections::HashSet;
    let present: HashSet<&str> = module.funcs.iter().map(|f| f.name.as_str()).collect();
    let refs_of: std::collections::HashMap<String, HashSet<String>> = module
        .funcs
        .iter()
        .map(|f| {
            let mut s = HashSet::new();
            collect_func_refs(f, &mut s);
            (f.name.clone(), s)
        })
        .collect();
    // fixpoint reachability from the roots.
    let mut reachable: HashSet<String> =
        roots.iter().filter(|r| present.contains(r.as_str())).cloned().collect();
    let mut queue: Vec<String> = reachable.iter().cloned().collect();
    // fusion targets become reachable the moment `range` is (see doc comment).
    let mut fusion_added = false;
    while let Some(n) = queue.pop() {
        if let Some(rs) = refs_of.get(&n) {
            for r in rs {
                if reachable.insert(r.clone()) {
                    queue.push(r.clone());
                }
            }
        }
        if !fusion_added && reachable.contains("range") {
            fusion_added = true;
            for t in ["rangeFused", "rangeFusedSum"] {
                if present.contains(t) && reachable.insert(t.into()) {
                    queue.push(t.into());
                }
            }
        }
    }
    module.funcs.retain(|f| reachable.contains(&f.name));
}

/// Collects the top-level function names a function's body references — walking
/// its clauses, guards, `where`/`let` bindings, lambdas and `case` arms. `Var`s
/// and the callee of an infix application (`++` lowers to `append`).
fn collect_func_refs(f: &ast::Func, out: &mut std::collections::HashSet<String>) {
    for c in &f.clauses {
        match &c.body {
            ast::Body::Plain(e) => collect_expr_refs(e, out),
            ast::Body::Guarded(arms) => {
                for (g, r) in arms {
                    collect_expr_refs(g, out);
                    collect_expr_refs(r, out);
                }
            }
        }
        for w in &c.wher {
            collect_func_refs(w, out);
        }
    }
}

fn collect_expr_refs(e: &ast::Expr, out: &mut std::collections::HashSet<String>) {
    use ast::Expr::{App, BinOp, Case, Con, Float, If, Int, Lam, Let, RecordCon, RecordUpd, Str, Tuple, Var};
    match e {
        Var(n, _) => {
            out.insert(n.clone());
        }
        BinOp(op, l, r, _) => {
            // a backtick-infix's operator is its callee; `++` lowers to `append`.
            // builtin operators (`+`, `==`, …) simply match no function name.
            out.insert(if op == "++" { "append".into() } else { op.clone() });
            collect_expr_refs(l, out);
            collect_expr_refs(r, out);
        }
        App(a, b, _) => {
            collect_expr_refs(a, out);
            collect_expr_refs(b, out);
        }
        If(c, t, e2, _) => {
            collect_expr_refs(c, out);
            collect_expr_refs(t, out);
            collect_expr_refs(e2, out);
        }
        Let(fns, body, _) => {
            for f in fns {
                collect_func_refs(f, out);
            }
            collect_expr_refs(body, out);
        }
        Case(scrut, arms, _) => {
            collect_expr_refs(scrut, out);
            for (_, arm) in arms {
                collect_expr_refs(arm, out);
            }
        }
        Tuple(es, _) => es.iter().for_each(|x| collect_expr_refs(x, out)),
        RecordCon(_, fields, _) => fields.iter().for_each(|(_, x)| collect_expr_refs(x, out)),
        RecordUpd(base, fields, _) => {
            collect_expr_refs(base, out);
            fields.iter().for_each(|(_, x)| collect_expr_refs(x, out));
        }
        Lam(_, body, _) => collect_expr_refs(body, out),
        Int(..) | Float(..) | Str(..) | Con(..) => {}
    }
}

/// The stages that turn a freshly-parsed module into the one the checker sees:
/// imports + prelude + `deriving` + class lowering + consumed-ownership inference.
/// Diagnostics (import/derive) are pushed into `diags`; the returned set is the
/// consume-native-exempt names. Shared by [`analyze_module`] and the salsa engine
/// (`crate::db`), which memoizes the derived signature environment on top of it.
pub fn prepare_for_check(
    module: ast::Module,
    path: &str,
    diags: &mut Diagnostics,
) -> (ast::Module, std::collections::HashSet<String>) {
    prepare_for_check_with(module, path, diags, &disk_import_resolver)
}

/// [`prepare_for_check`] with a custom import resolver (the salsa engine passes one
/// backed by tracked inputs, so a dependent is invalidated when an import changes).
pub fn prepare_for_check_with(
    mut module: ast::Module,
    path: &str,
    diags: &mut Diagnostics,
    resolve: &ImportResolver,
) -> (ast::Module, std::collections::HashSet<String>) {
    resolve_imports_with(&mut module, path, diags, resolve);
    inject_prelude(&mut module);
    derive_instances(&mut module, diags);
    lower_classes(&mut module);
    // Infer `%1` (consumed) ownership for a signature param whose extracted heap
    // element escapes via the result (`head`/`append`/`reverse`). Runs BEFORE the
    // linear checker and inference so the whole pipeline (owned_meta / Phase-B
    // specialization / borrow analysis / drop insertion / Δ-coherence) treats it as
    // a hand-written `%1` — otherwise the caller deep-drops a list whose elements
    // the callee reused/returned → double-free (heap elements only).
    let consume_exempt = infer_consumed_ownership(&mut module);
    (module, consume_exempt)
}


/// Materializes the specialized constrained functions: clones each
/// `src` (already rewritten by the direct resolutions), specializes the signature
/// (constraint var → concrete type), rewrites the internal uses (methods→`m$T`,
/// self-recursion→`f$T`), and appends to the module. So constrained polymorphism
/// compiles natively (Rust-style monomorphization).
fn materialize_specs(module: &mut ast::Module, specs: &[infer::SpecPlan]) {
    if specs.is_empty() {
        return;
    }
    let by_name: std::collections::HashMap<&str, ast::Func> = module
        .funcs
        .iter()
        .map(|f| (f.name.as_str(), f.clone()))
        .collect();
    let mut new_funcs = Vec::new();
    for plan in specs {
        let Some(src) = by_name.get(plan.src.as_str()) else {
            continue;
        };
        let mut clone = src.clone();
        clone.name = plan.name.clone();
        clone.constraints = Vec::new();
        // specialized signature: each type var → concrete type, in order
        if let Some(sig) = &clone.sig {
            let mut sig = sig.clone();
            for (var, repl) in &plan.subs {
                let templ = subst_head(&sig, var);
                sig = specialize_with(&templ, repl);
            }
            clone.sig = Some(sig);
        }
        // rewrites the internal uses (span → direct name) in the clone's body
        let mut res: Resolutions = std::collections::HashMap::new();
        for (span, name) in &plan.rewrites {
            res.insert((plan.name.clone(), *span), name.clone());
        }
        rewrite_func(&mut clone, &plan.name.clone(), &res);
        new_funcs.push(clone);
    }
    module.funcs.extend(new_funcs);
}

/// Rewrites the monomorphic method uses to direct calls to the instance
/// impl, per inference's `span → impl-name` map. Walks all
/// bodies (top-level functions, `where`, lambdas, `case` arms, `let`).
type Resolutions = std::collections::HashMap<(String, ast::Span), String>;

/// Consume-inference: synthesize `%1` on a signature parameter whose extracted
/// heap element escapes via the function's result (returned directly, or embedded
/// in a returned constructor/tuple/record — but NOT merely passed to a call, which
/// transforms it). Such a function CONSUMES the list (its result aliases the
/// elements), so it must own+reclaim it rather than borrow it (else the caller
/// double-frees the shared elements). See docs — this fixes the `head`/`append`/
/// `reverse` element-aliasing double-free on native.
fn infer_consumed_ownership(module: &mut ast::Module) -> std::collections::HashSet<String> {
    use std::collections::{HashMap, HashSet};
    let data_names: HashSet<String> = module.datas.iter().map(|d| d.name.clone()).collect();
    // constructor → per-field "carries a heap payload" (a `data`/tuple field, or a
    // bare type variable that may be heap once instantiated).
    let mut con_field_heap: HashMap<String, Vec<bool>> = HashMap::new();
    for d in &module.datas {
        for c in &d.cons {
            let flags = c
                .fields
                .iter()
                .map(|f| is_heap_field_ty(&f.ty, &data_names))
                .collect();
            con_field_heap.insert(c.name.clone(), flags);
        }
    }
    // data types that CARRY a heap payload: some constructor has a heap field. Distinguishes
    // `List` / a record with heap fields (a real reclamation need) from `Box Int` (a heap shell
    // wrapping only scalars — a scalar accessor's arg is a borrow, never consumed).
    let heap_payload_data: HashSet<String> = module
        .datas
        .iter()
        .filter(|d| {
            d.cons.iter().any(|c| {
                con_field_heap
                    .get(&c.name)
                    .is_some_and(|fs| fs.iter().any(|&h| h))
            })
        })
        .map(|d| d.name.clone())
        .collect();
    // `consuming[fn]` = parameter indices that are (or become) `%1`. Seeded from the
    // hand-written `%1`, then grown by Rule A (concrete consumers) and Rule B (generic
    // pure-escape). It is the authority the pure-escape fixpoint consults to decide
    // whether a field "moved into a call" is moved into a CONSUMING position.
    let mut consuming: HashMap<String, HashSet<usize>> = HashMap::new();
    for f in &module.funcs {
        if let Some(sig) = &f.sig {
            let owned: HashSet<usize> = sig
                .param_mults()
                .iter()
                .enumerate()
                .filter(|(_, m)| **m == ast::Mult::One)
                .map(|(i, _)| i)
                .collect();
            if !owned.is_empty() {
                consuming.insert(f.name.clone(), owned);
            }
        }
    }
    // (func idx, param idx) pairs to force `%1`.
    let mut apply: Vec<(usize, usize)> = Vec::new();
    // Rule A — CONCRETE consumers: SOME extracted heap field escapes via the result.
    // Concrete because a var-carrying `%1` becomes an owning-generic (handled by B);
    // a concrete `%1` deep-drops the non-escaping fields via its resolved key.
    for (idx, f) in module.funcs.iter().enumerate() {
        let Some(sig) = &f.sig else { continue };
        if !f.constraints.is_empty() {
            continue;
        }
        let ptypes = sig.param_types();
        for i in consumed_params(f, &con_field_heap) {
            if ptypes
                .get(i)
                .is_some_and(|t| core::is_heap_shaped(t) && !core::ty_has_var(t))
            {
                consuming.entry(f.name.clone()).or_default().insert(i);
                apply.push((idx, i));
            }
        }
    }
    // Rule B — GENERIC pure-escape: a var-carrying param where EVERY extracted heap
    // field escapes (returned/embedded OR moved into a consuming call) and NONE is
    // deep-dropped. Such a function only SHELL-FREES its spine natively (no element
    // key needed), so it can compile as a generic (exempted from the owning-generic
    // native exclusion). Least fixpoint with optimistic self-assumption: append's
    // recursion and concat→append converge across iterations.
    let mut exempt: HashSet<String> = HashSet::new();
    loop {
        let mut changed = false;
        for (idx, f) in module.funcs.iter().enumerate() {
            let Some(sig) = &f.sig else { continue };
            if !f.constraints.is_empty() {
                continue;
            }
            let ptypes = sig.param_types();
            for (i, ty) in ptypes.iter().enumerate() {
                if consuming.get(&f.name).is_some_and(|s| s.contains(&i)) {
                    continue;
                }
                let ty = *ty;
                // A pure-escape candidate: a GENERIC heap param (`List a` — element may be heap)
                // OR a CONCRETE param that CARRIES a heap payload (`List Integer`, `List Box`).
                // The concrete case covers a monomorphic HOF fed element-by-element into a
                // closure: it must shell-free the spine and move each element into the consuming
                // closure — if it stayed borrowed, the lifted lambda's drop of the element would
                // double-free against the caller's drop of the list. A concrete heap param with
                // NO heap payload (`Box Int` — a scalar accessor's arg) must NOT qualify: it is a
                // borrow, and consuming it would double-free a value its owner still frees.
                if !(core::is_heap_shaped(ty) && (core::ty_has_var(ty) || carries_heap_payload(ty, &heap_payload_data)))
                {
                    continue;
                }
                // Optimistically assume this param is consuming, verify, and undo on
                // failure — insert-in-place instead of cloning the whole map per
                // candidate. (`newly` is false if hand-written `%1` already had it.)
                let newly = consuming.entry(f.name.clone()).or_default().insert(i);
                if param_is_pure_escape(f, i, &con_field_heap, &consuming) {
                    exempt.insert(f.name.clone());
                    apply.push((idx, i));
                    changed = true;
                } else if newly {
                    if let Some(s) = consuming.get_mut(&f.name) {
                        s.remove(&i);
                    }
                }
            }
        }
        if !changed {
            break;
        }
    }
    for (fidx, i) in apply {
        if let Some(sig) = &mut module.funcs[fidx].sig {
            set_param_mult_one(sig, i);
        }
    }
    exempt
}

/// `true` if `ty` transitively carries a reclaimable heap payload: a tuple with a heap/var
/// element, or a `data` type one of whose constructors has a heap field (`heap_payload_data`).
/// A heap SHELL wrapping only scalars (`Box Int`) does NOT carry a payload — reading it is a
/// borrow, so its owning param must not be consumed.
fn carries_heap_payload(
    ty: &ast::Type,
    heap_payload_data: &std::collections::HashSet<String>,
) -> bool {
    match ty {
        ast::Type::Tuple(ts) => ts
            .iter()
            .any(|t| core::is_heap_shaped(t) || core::ty_has_var(t)),
        _ => ty
            .head_con()
            .is_some_and(|h| heap_payload_data.contains(h)),
    }
}

/// A constructor field that carries a separately-allocated heap payload once
/// instantiated: a `data`/tuple field, or a bare type variable (poly-heap).
fn is_heap_field_ty(ty: &ast::Type, data_names: &std::collections::HashSet<String>) -> bool {
    match ty {
        ast::Type::Var(_) | ast::Type::Tuple(_) => true,
        _ => ty.head_con().is_some_and(|h| data_names.contains(h)),
    }
}

/// Parameter indices of `f` that are CONSUMED — an extracted heap field of the
/// param escapes via the result. Covers `case <param> of Cons b .. -> <b escapes>`
/// and direct clause destructuring `f (Cons b ..) = <b escapes>`.
fn consumed_params(
    f: &ast::Func,
    con_field_heap: &std::collections::HashMap<String, Vec<bool>>,
) -> std::collections::HashSet<usize> {
    use std::collections::HashSet;
    let mut out = HashSet::new();
    for clause in &f.clauses {
        let bodies: Vec<&ast::Expr> = match &clause.body {
            ast::Body::Plain(e) => vec![e],
            ast::Body::Guarded(arms) => arms.iter().map(|(_, r)| r).collect(),
        };
        // scrutinee variable names consumed by a `case <var> of` inside the bodies
        let mut names: HashSet<String> = HashSet::new();
        for body in &bodies {
            collect_consuming_cases(body, con_field_heap, &mut names);
        }
        for (i, p) in clause.pats.iter().enumerate() {
            match p {
                ast::Pat::Var(n, _) if names.contains(n) => {
                    out.insert(i);
                }
                // direct destructuring in the clause head: `f (Cons b ..) = <b>`
                ast::Pat::Con(con, subs, _)
                    if arm_field_escapes(con, subs, &bodies, con_field_heap) => {
                        out.insert(i);
                    }
                _ => {}
            }
        }
    }
    out
}

/// Records scrutinee var names of a `case <var> of` whose arm extracts a heap
/// field that escapes via that arm's result. Recurses into all subexpressions.
fn collect_consuming_cases(
    e: &ast::Expr,
    con_field_heap: &std::collections::HashMap<String, Vec<bool>>,
    names: &mut std::collections::HashSet<String>,
) {
    if let ast::Expr::Case(scrut, arms, _) = e {
        if let ast::Expr::Var(s, _) = scrut.as_ref() {
            for (pat, body) in arms {
                if let ast::Pat::Con(con, subs, _) = pat {
                    if arm_field_escapes(con, subs, &[body], con_field_heap) {
                        names.insert(s.clone());
                    }
                }
            }
        }
    }
    for_each_subexpr(e, &mut |sub| collect_consuming_cases(sub, con_field_heap, names));
}

/// `true` if some heap field binder of pattern `Con subs` escapes via any of the
/// arm result expressions.
fn arm_field_escapes(
    con: &str,
    subs: &[ast::Pat],
    bodies: &[&ast::Expr],
    con_field_heap: &std::collections::HashMap<String, Vec<bool>>,
) -> bool {
    let Some(heaps) = con_field_heap.get(con) else {
        return false;
    };
    subs.iter().enumerate().any(|(fi, sp)| {
        matches!(sp, ast::Pat::Var(b, _) if heaps.get(fi).copied().unwrap_or(false)
            && bodies.iter().any(|body| escapes_via_result(b, body)))
    })
}

/// `true` if variable `name` reaches the function's RESULT: returned directly, or
/// embedded (directly or nested) in a returned constructor/tuple/record. A value
/// passed to a call is NOT counted — the call transforms/consumes it, its result
/// does not alias the argument (keeps `map`/`filter` as pure borrows).
fn escapes_via_result(name: &str, e: &ast::Expr) -> bool {
    returned_directly(name, e) || embedded_in_ctor(name, e)
}

fn returned_directly(name: &str, e: &ast::Expr) -> bool {
    match e {
        ast::Expr::Var(n, _) => n == name,
        ast::Expr::If(_, t, el, _) => returned_directly(name, t) || returned_directly(name, el),
        ast::Expr::Case(_, arms, _) => arms.iter().any(|(_, b)| returned_directly(name, b)),
        ast::Expr::Let(_, body, _) => returned_directly(name, body),
        _ => false,
    }
}

fn embedded_in_ctor(name: &str, e: &ast::Expr) -> bool {
    let is_var = |x: &ast::Expr| matches!(x, ast::Expr::Var(n, _) if n == name);
    match e {
        ast::Expr::App(_, _, _) => {
            let (head, args) = core::spine(e);
            let here = matches!(head, ast::Expr::Con(_, _)) && args.iter().any(|a| is_var(a));
            here || args.iter().any(|a| embedded_in_ctor(name, a))
        }
        ast::Expr::Tuple(es, _) => es.iter().any(|x| is_var(x) || embedded_in_ctor(name, x)),
        ast::Expr::RecordCon(_, fs, _) => {
            fs.iter().any(|(_, x)| is_var(x) || embedded_in_ctor(name, x))
        }
        ast::Expr::If(_, t, el, _) => embedded_in_ctor(name, t) || embedded_in_ctor(name, el),
        ast::Expr::Case(_, arms, _) => arms.iter().any(|(_, b)| embedded_in_ctor(name, b)),
        ast::Expr::Let(_, body, _) => embedded_in_ctor(name, body),
        _ => false,
    }
}


/// Applies `g` to each immediate sub-expression of `e` (one level).
fn for_each_subexpr(e: &ast::Expr, g: &mut dyn FnMut(&ast::Expr)) {
    match e {
        ast::Expr::App(a, b, _) | ast::Expr::BinOp(_, a, b, _) => {
            g(a);
            g(b);
        }
        ast::Expr::If(c, t, el, _) => {
            g(c);
            g(t);
            g(el);
        }
        ast::Expr::Case(s, arms, _) => {
            g(s);
            arms.iter().for_each(|(_, b)| g(b));
        }
        ast::Expr::Let(binds, body, _) => {
            for f in binds {
                for c in &f.clauses {
                    if let ast::Body::Plain(be) = &c.body {
                        g(be);
                    }
                    if let ast::Body::Guarded(arms) = &c.body {
                        arms.iter().for_each(|(gg, r)| {
                            g(gg);
                            g(r);
                        });
                    }
                }
            }
            g(body);
        }
        ast::Expr::Tuple(es, _) => es.iter().for_each(g),
        ast::Expr::RecordCon(_, fs, _) => fs.iter().for_each(|(_, x)| g(x)),
        ast::Expr::RecordUpd(b, fs, _) => {
            g(b);
            fs.iter().for_each(|(_, x)| g(x));
        }
        ast::Expr::Lam(_, body, _) => g(body),
        _ => {}
    }
}

/// Sets the multiplicity of the `idx`-th parameter arrow in a signature to `One`
/// (`%1`), when the param is heap-shaped (a `data`/tuple — a bare var is an i64 with
/// no owned payload). Eligibility (concrete Rule A vs generic pure-escape Rule B) is
/// decided by the caller; this only writes the annotation.
fn set_param_mult_one(sig: &mut ast::Type, idx: usize) {
    let mut cur = sig;
    let mut i = 0;
    while let ast::Type::Arrow { mult, from, to } = cur {
        if i == idx {
            if core::is_heap_shaped(from) {
                *mult = ast::Mult::One;
            }
            return;
        }
        i += 1;
        cur = to;
    }
}

fn is_var_named(e: &ast::Expr, name: &str) -> bool {
    matches!(e, ast::Expr::Var(n, _) if n == name)
}

/// `true` if `name` is moved into a CONSUMING (`%1`) parameter position of some call
/// in `e` (per `consuming`, `fn → owned param indices`). This is the transitive
/// escape clause: `zs` in `append zs ys` escapes because `append`'s arg0 is `%1`.
fn moved_into_consuming(
    name: &str,
    e: &ast::Expr,
    consuming: &std::collections::HashMap<String, std::collections::HashSet<usize>>,
) -> bool {
    match e {
        ast::Expr::App(_, _, _) => {
            let (head, args) = core::spine(e);
            let here = if let ast::Expr::Var(g, _) = head {
                consuming.get(g).is_some_and(|cp| {
                    args.iter()
                        .enumerate()
                        .any(|(i, a)| cp.contains(&i) && is_var_named(a, name))
                })
            } else {
                false
            };
            here || args.iter().any(|a| moved_into_consuming(name, a, consuming))
        }
        ast::Expr::If(_, t, el, _) => {
            moved_into_consuming(name, t, consuming) || moved_into_consuming(name, el, consuming)
        }
        ast::Expr::Case(_, arms, _) => arms
            .iter()
            .any(|(_, b)| moved_into_consuming(name, b, consuming)),
        ast::Expr::Let(_, body, _) => moved_into_consuming(name, body, consuming),
        ast::Expr::Tuple(es, _) => es.iter().any(|x| moved_into_consuming(name, x, consuming)),
        ast::Expr::RecordCon(_, fs, _) | ast::Expr::RecordUpd(_, fs, _) => {
            fs.iter().any(|(_, x)| moved_into_consuming(name, x, consuming))
        }
        _ => false,
    }
}

/// `true` if `name` is moved as an argument into a CLOSURE application — a spine whose
/// head is a function-typed local (`closures`), i.e. a higher-order parameter like
/// foldr's combiner `f` in `f y acc`. Under the closure consume-ABI the closure OWNS
/// (and reclaims — the lifted lambda's Auto-Drop) the arg, so the field escapes the
/// enclosing function exactly as a return would. Sound because linearity forbids a
/// second use of a consumed value, so the list this element came from is never read
/// again after the consuming HOF.
fn moved_into_closure(
    name: &str,
    e: &ast::Expr,
    closures: &std::collections::HashSet<String>,
) -> bool {
    match e {
        ast::Expr::App(_, _, _) => {
            let (head, args) = core::spine(e);
            let here = matches!(head, ast::Expr::Var(g, _) if closures.contains(g))
                && args.iter().any(|a| is_var_named(a, name));
            here || args.iter().any(|a| moved_into_closure(name, a, closures))
        }
        ast::Expr::If(_, t, el, _) => {
            moved_into_closure(name, t, closures) || moved_into_closure(name, el, closures)
        }
        ast::Expr::Case(_, arms, _) => arms
            .iter()
            .any(|(_, b)| moved_into_closure(name, b, closures)),
        ast::Expr::Let(_, body, _) => moved_into_closure(name, body, closures),
        ast::Expr::Tuple(es, _) => es.iter().any(|x| moved_into_closure(name, x, closures)),
        ast::Expr::RecordCon(_, fs, _) | ast::Expr::RecordUpd(_, fs, _) => {
            fs.iter().any(|(_, x)| moved_into_closure(name, x, closures))
        }
        _ => false,
    }
}

/// `true` if `name` escapes on EVERY control-flow path of `e` — returned/embedded or
/// moved into a consuming call at every `if`/`case` leaf. Distinct from
/// `escapes_via_result`'s "escapes on SOME branch": a PARTIAL consumer (`filter`'s
/// `else` drops the element, `take`'s `n==0` drops the list) fails here, so it is
/// correctly NOT pure-escape (it deep-drops on the discarding path).
fn escapes_every_path(
    name: &str,
    e: &ast::Expr,
    consuming: &std::collections::HashMap<String, std::collections::HashSet<usize>>,
    closures: &std::collections::HashSet<String>,
) -> bool {
    match e {
        ast::Expr::If(_, t, el, _) => {
            escapes_every_path(name, t, consuming, closures)
                && escapes_every_path(name, el, consuming, closures)
        }
        ast::Expr::Case(_, arms, _) => {
            !arms.is_empty()
                && arms
                    .iter()
                    .all(|(_, b)| escapes_every_path(name, b, consuming, closures))
        }
        ast::Expr::Let(_, body, _) => escapes_every_path(name, body, consuming, closures),
        _ => {
            escapes_via_result(name, e)
                || moved_into_consuming(name, e, consuming)
                || moved_into_closure(name, e, closures)
        }
    }
}

/// `true` if parameter `idx` of `f` is PURE-ESCAPE: on EVERY path it is destructured
/// by `case`, EVERY extracted heap field escapes on every path, and the param is
/// never deep-dropped (unused/discarded). Such a param is only SHELL-FREED natively
/// (no element key needed), so the function can compile as a generic shell-freer.
fn param_is_pure_escape(
    f: &ast::Func,
    idx: usize,
    con_field_heap: &std::collections::HashMap<String, Vec<bool>>,
    consuming: &std::collections::HashMap<String, std::collections::HashSet<usize>>,
) -> bool {
    // function-typed params of `f` are the closures its elements may be consumed by
    // (foldr's combiner `f`): an element moved into `f y` escapes into that closure.
    let closures = arrow_typed_params(f);
    let mut saw = false;
    for clause in &f.clauses {
        let bodies: Vec<&ast::Expr> = match &clause.body {
            ast::Body::Plain(e) => vec![e],
            ast::Body::Guarded(arms) => arms.iter().map(|(_, r)| r).collect(),
        };
        match clause.pats.get(idx) {
            Some(ast::Pat::Var(p, _)) => {
                for body in &bodies {
                    if !p_path_ok(p, body, false, con_field_heap, consuming, &closures, &mut saw) {
                        return false;
                    }
                }
            }
            // clause-head destructuring: `f (Cons b ..) = <b escapes>`
            Some(ast::Pat::Con(con, subs, _)) => {
                for body in &bodies {
                    if !arm_heap_escape_every_path(
                        con,
                        subs,
                        body,
                        con_field_heap,
                        consuming,
                        &closures,
                    ) {
                        return false;
                    }
                }
                saw = true;
            }
            _ => return false,
        }
    }
    saw
}

/// The parameter names of `f` whose signature type is a function (arrow) — the
/// higher-order params. Aggregated across clauses (a clause may bind a different name
/// at the same position). Empty when `f` has no signature.
fn arrow_typed_params(f: &ast::Func) -> std::collections::HashSet<String> {
    let mut out = std::collections::HashSet::new();
    let Some(sig) = &f.sig else { return out };
    let ptypes = sig.param_types();
    for clause in &f.clauses {
        for (i, p) in clause.pats.iter().enumerate() {
            if let ast::Pat::Var(n, _) = p {
                if ptypes
                    .get(i)
                    .is_some_and(|t| matches!(t, ast::Type::Arrow { .. }))
                {
                    out.insert(n.clone());
                }
            }
        }
    }
    out
}

/// Flow check for the owned param `p` along one body: on EVERY path, `p` must be
/// consumed EXACTLY once — by a `case p of` whose arms fully escape (then `consumed`
/// holds downstream), or by escaping whole (returned / moved into a consuming call).
/// A path where `p` is neither consumed nor escaped (e.g. `take`'s `n==0 -> Nil`)
/// means `p` is deep-dropped there → NOT pure-escape.
fn p_path_ok(
    p: &str,
    e: &ast::Expr,
    consumed: bool,
    cfh: &std::collections::HashMap<String, Vec<bool>>,
    consuming: &std::collections::HashMap<String, std::collections::HashSet<usize>>,
    closures: &std::collections::HashSet<String>,
    saw: &mut bool,
) -> bool {
    match e {
        // `p` consumed here by destructuring — arms fully escape; downstream `consumed`.
        ast::Expr::Case(scrut, arms, _) if is_var_named(scrut, p) && !consumed => {
            *saw = true;
            !arms.is_empty()
                && arms.iter().all(|(pat, body)| match pat {
                    ast::Pat::Con(con, subs, _) => {
                        arm_heap_escape_every_path(con, subs, body, cfh, consuming, closures)
                            && p_path_ok(p, body, true, cfh, consuming, closures, saw)
                    }
                    _ => p_path_ok(p, body, true, cfh, consuming, closures, saw),
                })
        }
        ast::Expr::If(_, t, el, _) => {
            p_path_ok(p, t, consumed, cfh, consuming, closures, saw)
                && p_path_ok(p, el, consumed, cfh, consuming, closures, saw)
        }
        // a `case` on something OTHER than `p`: `p` must be handled in every arm.
        ast::Expr::Case(_, arms, _) => {
            !arms.is_empty()
                && arms
                    .iter()
                    .all(|(_, body)| p_path_ok(p, body, consumed, cfh, consuming, closures, saw))
        }
        ast::Expr::Let(_, body, _) => p_path_ok(p, body, consumed, cfh, consuming, closures, saw),
        // a tail: OK iff `p` was already consumed upstream, or escapes whole here.
        _ => {
            consumed
                || escapes_via_result(p, e)
                || moved_into_consuming(p, e, consuming)
                || moved_into_closure(p, e, closures)
        }
    }
}

/// `true` if EVERY heap field of `Con subs` (per `cfh`) has a binder that escapes on
/// EVERY path of `body`. A discarded/nested-pattern heap field fails (deep-dropped).
fn arm_heap_escape_every_path(
    con: &str,
    subs: &[ast::Pat],
    body: &ast::Expr,
    cfh: &std::collections::HashMap<String, Vec<bool>>,
    consuming: &std::collections::HashMap<String, std::collections::HashSet<usize>>,
    closures: &std::collections::HashSet<String>,
) -> bool {
    let Some(heaps) = cfh.get(con) else {
        return false;
    };
    subs.iter().enumerate().all(|(fi, sp)| {
        if heaps.get(fi).copied().unwrap_or(false) {
            // A heap field must escape on every path — AND its binder must not be
            // shadowed inside the arm (the escape analysis is name-based; a nested
            // binder reusing the name would make a DROPPED field look escaped).
            matches!(sp, ast::Pat::Var(b, _) if escapes_every_path(b, body, consuming, closures)
                && !is_rebound(b, body))
        } else {
            true
        }
    })
}

/// `true` if `name` is re-bound (shadowed) by any pattern — a `case` arm, lambda,
/// or `let` — anywhere in `e`. Used to bail out of the name-based escape analysis.
fn is_rebound(name: &str, e: &ast::Expr) -> bool {
    let binds_here = match e {
        ast::Expr::Case(_, arms, _) => arms.iter().any(|(pat, _)| pat_binds(pat, name)),
        ast::Expr::Lam(pats, _, _) => pats.iter().any(|p| pat_binds(p, name)),
        ast::Expr::Let(binds, _, _) => binds.iter().any(|f| {
            f.clauses
                .iter()
                .any(|c| c.pats.iter().any(|p| pat_binds(p, name)))
        }),
        _ => false,
    };
    if binds_here {
        return true;
    }
    let mut found = false;
    for_each_subexpr(e, &mut |sub| {
        if is_rebound(name, sub) {
            found = true;
        }
    });
    found
}

fn pat_binds(p: &ast::Pat, name: &str) -> bool {
    match p {
        ast::Pat::Var(n, _) => n == name,
        ast::Pat::Con(_, subs, _) | ast::Pat::Tuple(subs, _) => {
            subs.iter().any(|s| pat_binds(s, name))
        }
        _ => false,
    }
}

/// Phase 1b: wrap each integer literal that inference resolved to `Integer`
/// (`fromInt n`), so the executor builds an arbitrary-precision value. Runs after
/// type inference; only `Integer` literals are touched, so `Int` programs are inert.
fn rewrite_int_lits(module: &mut ast::Module, lits: &std::collections::HashSet<(usize, usize)>) {
    if lits.is_empty() {
        return;
    }
    for f in &mut module.funcs {
        rw_int_lits_func(f, lits);
    }
}

fn rw_int_lits_func(f: &mut ast::Func, lits: &std::collections::HashSet<(usize, usize)>) {
    for c in &mut f.clauses {
        match &mut c.body {
            ast::Body::Plain(e) => rw_int_lits_expr(e, lits),
            ast::Body::Guarded(arms) => {
                for (g, r) in arms {
                    rw_int_lits_expr(g, lits);
                    rw_int_lits_expr(r, lits);
                }
            }
        }
        for w in &mut c.wher {
            rw_int_lits_func(w, lits);
        }
    }
}

fn rw_int_lits_expr(e: &mut ast::Expr, lits: &std::collections::HashSet<(usize, usize)>) {
    use ast::Expr::{App, BinOp, Case, If, Int, Lam, Let, RecordCon, RecordUpd, Tuple, Var};
    // an Integer literal → `fromInt n`; return so the wrapped inner `Int` (same span)
    // is not re-visited.
    if let Int(n, span) = e {
        if lits.contains(span) {
            let (sp, val) = (*span, *n);
            *e = App(
                Box::new(Var("fromInt".into(), sp)),
                Box::new(Int(val, sp)),
                sp,
            );
            return;
        }
    }
    match e {
        App(a, b, _) | BinOp(_, a, b, _) => {
            rw_int_lits_expr(a, lits);
            rw_int_lits_expr(b, lits);
        }
        If(c, t, el, _) => {
            rw_int_lits_expr(c, lits);
            rw_int_lits_expr(t, lits);
            rw_int_lits_expr(el, lits);
        }
        Let(binds, body, _) => {
            for b in binds {
                rw_int_lits_func(b, lits);
            }
            rw_int_lits_expr(body, lits);
        }
        Case(scrut, arms, _) => {
            rw_int_lits_expr(scrut, lits);
            for (_, body) in arms {
                rw_int_lits_expr(body, lits);
            }
        }
        Tuple(es, _) => es.iter_mut().for_each(|x| rw_int_lits_expr(x, lits)),
        RecordCon(_, fs, _) => {
            for (_, x) in fs {
                rw_int_lits_expr(x, lits);
            }
        }
        RecordUpd(base, fs, _) => {
            rw_int_lits_expr(base, lits);
            for (_, x) in fs {
                rw_int_lits_expr(x, lits);
            }
        }
        Lam(_, body, _) => rw_int_lits_expr(body, lits),
        _ => {}
    }
}

fn resolve_methods(module: &mut ast::Module, res: &Resolutions) {
    if res.is_empty() {
        return;
    }
    for f in &mut module.funcs {
        let fname = f.name.clone();
        rewrite_func(f, &fname, res);
    }
}

fn rewrite_func(f: &mut ast::Func, fname: &str, res: &Resolutions) {
    for c in &mut f.clauses {
        match &mut c.body {
            ast::Body::Plain(e) => rewrite_expr(e, fname, res),
            ast::Body::Guarded(arms) => {
                for (g, r) in arms {
                    rewrite_expr(g, fname, res);
                    rewrite_expr(r, fname, res);
                }
            }
        }
        // `where` functions are inferred with the PARENT's name as `cur_fn`
        // (they are part of its body), so they are rewritten with `fname`.
        for w in &mut c.wher {
            rewrite_func_body(w, fname, res);
        }
    }
}

/// Like `rewrite_func`, but keeps the key name (`fname`) — for `where`, whose
/// `cur_fn` in inference is the parent function's.
fn rewrite_func_body(f: &mut ast::Func, fname: &str, res: &Resolutions) {
    for c in &mut f.clauses {
        match &mut c.body {
            ast::Body::Plain(e) => rewrite_expr(e, fname, res),
            ast::Body::Guarded(arms) => {
                for (g, r) in arms {
                    rewrite_expr(g, fname, res);
                    rewrite_expr(r, fname, res);
                }
            }
        }
        for w in &mut c.wher {
            rewrite_func_body(w, fname, res);
        }
    }
}

fn rewrite_expr(e: &mut ast::Expr, fname: &str, res: &Resolutions) {
    use ast::Expr::{
        App, BinOp, Case, Con, Float, If, Int, Lam, Let, RecordCon, RecordUpd, Str, Tuple, Var,
    };
    if let Var(name, span) = e {
        if let Some(impl_name) = res.get(&(fname.to_string(), *span)) {
            *name = impl_name.clone();
        }
        return;
    }
    // built-in `Num` operator resolved to `Float` → rewrite `+` to `+.` (etc.),
    // which the backends already lower. Int uses have no resolution (stay `+`).
    if let BinOp(op, _, _, span) = e {
        if let Some(name) = res.get(&(fname.to_string(), *span)) {
            *op = name.clone();
        }
    }
    match e {
        Int(_, _) | Float(_, _) | Str(_, _) | Con(_, _) => {}
        App(a, b, _) | BinOp(_, a, b, _) => {
            rewrite_expr(a, fname, res);
            rewrite_expr(b, fname, res);
        }
        If(c, t, el, _) => {
            rewrite_expr(c, fname, res);
            rewrite_expr(t, fname, res);
            rewrite_expr(el, fname, res);
        }
        Let(binds, body, _) => {
            for b in binds {
                rewrite_func_body(b, fname, res);
            }
            rewrite_expr(body, fname, res);
        }
        Case(scrut, arms, _) => {
            rewrite_expr(scrut, fname, res);
            for (_, body) in arms {
                rewrite_expr(body, fname, res);
            }
        }
        Tuple(es, _) => es.iter_mut().for_each(|x| rewrite_expr(x, fname, res)),
        RecordCon(_, fs, _) => {
            for (_, x) in fs {
                rewrite_expr(x, fname, res);
            }
        }
        RecordUpd(base, fs, _) => {
            rewrite_expr(base, fname, res);
            for (_, x) in fs {
                rewrite_expr(x, fname, res);
            }
        }
        Lam(_, body, _) => rewrite_expr(body, fname, res),
        Var(_, _) => unreachable!(),
    }
}

/// Built-in L0 prelude: the `List` type and the basic list functions. It is
/// prepended to every module (only the names the user doesn't redefine), so that
/// `[1..100]`/`:`/`.` (which desugar to `range`/`Cons`/`compose`) and `map`
/// they work without import. `mapM_` is a prelude function too.
const PRELUDE: &str = "\
data List a = Nil | Cons a (List a)

-- networking FFI: TCP socket operations (axion_rt.c)
foreign ax_net_connect :: String -> Int -> Int
foreign ax_net_listen :: Int -> Int
foreign ax_net_accept :: Int -> Int
foreign ax_net_send :: Int -> String -> Int
foreign ax_net_recv :: Int -> String
foreign ax_net_close :: Int -> Int

-- dense Buffer FFI: List ↔ Buffer conversion (Buffer ops via imperative blocks)
foreign axion_list_to_buf :: List Int -> Int
foreign axion_buf_to_list :: Int -> List Int

compose :: (b -> c) -> (a -> b) -> a -> c
compose f g x = f (g x)
range :: Int -> Int -> List Int
range lo hi = if lo > hi then Nil else Cons lo (range (lo + 1) hi)
replicate :: Int -> a -> List a
replicate n x = if n < 1 then Nil else Cons x (replicate (n - 1) x)
map :: (a -> b) -> List a -> List b
map f xs = case xs of
  Nil -> Nil
  Cons y ys -> Cons (f y) (map f ys)
length :: List a -> Int
length xs = case xs of
  Nil -> 0
  Cons y ys -> 1 + length ys
append :: List a -> List a -> List a
append xs ys = case xs of
  Nil -> ys
  Cons z zs -> Cons z (append zs ys)
reverse :: List a -> List a
reverse xs = case xs of
  Nil -> Nil
  Cons y ys -> append (reverse ys) (Cons y Nil)
filter :: (a -> Bool) -> List a -> List a
filter p xs = case xs of
  Nil -> Nil
  Cons y ys -> if p y then Cons y (filter p ys) else filter p ys
foldr :: (a -> b -> b) -> b -> List a -> b
foldr f z xs = case xs of
  Nil -> z
  Cons y ys -> f y (foldr f z ys)
foldl :: (b -> a -> b) -> b -> List a -> b
foldl f z xs = case xs of
  Nil -> z
  Cons y ys -> foldl f (f z y) ys
take :: Int -> List a -> List a
take n xs = case xs of
  Nil -> Nil
  Cons y ys -> if n < 1 then Nil else Cons y (take (n - 1) ys)
drop :: Int -> List a -> List a
drop n xs = case xs of
  Nil -> Nil
  Cons y ys -> if n < 1 then Cons y ys else drop (n - 1) ys
null :: List a -> Bool
null xs = case xs of
  Nil -> True
  Cons y ys -> False
-- Safe list deconstruction. The linear way to peel a list: `uncons` yields the
-- head AND the rest, so nothing is aliased or double-freed; `head`/`tail`/`last`
-- drop the part they don't return. The list arg is consumed (inferred `%1`).
-- (Scalar element types across all backends; a heap element type — a list OF
-- lists/strings — hits the poly-payload native limitation, like other generic
-- element-returning functions. The dropped remainder leaks conservatively, like
-- `drop`.)
uncons :: List a -> Maybe (a, List a)
uncons xs = case xs of
  Nil -> Nothing
  Cons y ys -> Just (y, ys)
head :: List a -> Maybe a
head xs = case xs of
  Nil -> Nothing
  Cons y ys -> Just y
tail :: List a -> Maybe (List a)
tail xs = case xs of
  Nil -> Nothing
  Cons y ys -> Just ys
last :: List a -> Maybe a
last xs = case xs of
  Nil -> Nothing
  Cons y ys -> case ys of
    Nil -> Just y
    Cons z zs -> last (Cons z zs)
sum :: List Int -> Int
sum xs = case xs of
  Nil -> 0
  Cons y ys -> y + sum ys
elem :: Int -> List Int -> Bool
elem x xs = case xs of
  Nil -> False
  Cons y ys -> if x == y then True else elem x ys
concat :: List (List a) -> List a
concat xs = case xs of
  Nil -> Nil
  Cons y ys -> append y (concat ys)
zipWith :: (a -> b -> c) -> List a -> List b -> List c
zipWith f xs ys = case xs of
  Nil -> Nil
  Cons a as_ -> case ys of
    Nil -> Nil
    Cons b bs -> Cons (f a b) (zipWith f as_ bs)
zip :: List a -> List b -> List (a, b)
zip xs ys = zipWith (\\a b -> (a, b)) xs ys
unlines :: List String -> String
unlines xs = case xs of
  Nil -> \"\"
  Cons s ss -> s ++ \"\\n\" ++ unlines ss
-- first word with no leading space; `unwordsRest` prefixes \" \" before each of
-- the rest. Split so neither re-uses a cased tail nor binds unused elements — that
-- left the extracted (heap) strings live-and-undropped at the return (a leak with
-- substr-built strings; invisible with literals, whose str_drop skips them).
unwords :: List String -> String
unwords xs = case xs of
  Nil -> \"\"
  Cons s ss -> s ++ unwordsRest ss
unwordsRest :: List String -> String
unwordsRest ss = case ss of
  Nil -> \"\"
  Cons t ts -> \" \" ++ t ++ unwordsRest ts
-- char-level string processing (§text), on the byte primitives strLen/charAt/
-- substr. `isSpace`/char codes are bytes (ASCII): 32 space, 9 tab, 10 \\n, 13 \\r.
isSpace :: Int -> Bool
isSpace c = if c == 32 then True else if c == 9 then True else if c == 10 then True else c == 13
-- index of the first `c` at/after `i` (or `n` if none).
findChar :: Int -> String -> Int -> Int -> Int
findChar c s i n = if i < n then (if charAt i s == c then i else findChar c s (i + 1) n) else n
-- splitOn: break on every occurrence of char `c` (empty fields kept), the
-- inverse of `intercalate`. `splitOn 44 \"a,,b\"` = [\"a\", \"\", \"b\"].
splitOn :: Int -> String -> List String
splitOn c s = splitFrom c s 0 (strLen s)
splitFrom :: Int -> String -> Int -> Int -> List String
splitFrom c s i n = consSplit c s i n (findChar c s i n)
consSplit :: Int -> String -> Int -> Int -> Int -> List String
consSplit c s i n j = Cons (substr i (j - i) s) (if j < n then splitFrom c s (j + 1) n else Nil)
-- lines: split on \\n; a trailing newline does NOT yield a trailing empty
-- (`lines \"a\\nb\\n\"` = [\"a\", \"b\"]), and `lines \"\"` = [].
lines :: String -> List String
lines s = linesFrom s 0 (strLen s)
linesFrom :: String -> Int -> Int -> List String
linesFrom s i n = if i < n then consLine s i n (findChar 10 s i n) else Nil
consLine :: String -> Int -> Int -> Int -> List String
consLine s i n j = Cons (substr i (j - i) s) (linesFrom s (j + 1) n)
-- words: split on runs of whitespace, dropping empty fields
-- (`words \"  a  b \"` = [\"a\", \"b\"], `words \"\"` = []).
words :: String -> List String
words s = wordsFrom s 0 (strLen s)
wordsFrom :: String -> Int -> Int -> List String
wordsFrom s i n = if i < n then wordsStep s i n else Nil
wordsStep :: String -> Int -> Int -> List String
wordsStep s i n = if isSpace (charAt i s) then wordsFrom s (i + 1) n else consWord s i n (wordEnd s i n)
consWord :: String -> Int -> Int -> Int -> List String
consWord s i n j = Cons (substr i (j - i) s) (wordsFrom s j n)
wordEnd :: String -> Int -> Int -> Int
wordEnd s i n = if i < n then (if isSpace (charAt i s) then i else wordEnd s (i + 1) n) else i
class Eq a where
  eq :: a -> a -> Bool
class Ord a where
  le :: a -> a -> Bool
class Show a where
  show :: a -> String
  showArg :: a -> String
instance Show Int where
  show x = showInt x
  showArg x = showInt x
instance Show Float where
  show x = showFloat x
  showArg x = showFloat x
instance Show Integer where
  show x = showInteger x
  showArg x = showInteger x
instance Show Bool where
  show x = if x then \"true\" else \"false\"
  showArg x = if x then \"true\" else \"false\"
-- Show for String: wrap in double quotes (so `show [\"a\", \"b\"]` = `[\"a\", \"b\"]`).
-- No escaping of inner quotes/newlines (ASCII, best-effort — matches the rest of §text).
instance Show String where
  show s = strAppend \"\\\"\" (strAppend s \"\\\"\")
  showArg s = strAppend \"\\\"\" (strAppend s \"\\\"\")
instance Eq Int where
  eq x y = x == y
instance Ord Int where
  le x y = if x < y then True else x == y
instance Eq Float where
  eq x y = x == y
instance Ord Float where
  le x y = if x < y then True else x == y
instance Eq Bool where
  eq x y = if x then y else if y then False else True
instance Ord Bool where
  le x y = if x then y else True
-- Show for lists: `[1, 2, 3]` (bracketed, comma-separated). Elements use
-- `show` (not showArg) so nested constructors aren't parenthesised inside the
-- brackets, matching Haskell's `show [Just 1, Nothing]` = `[Just 1, Nothing]`.
-- showArg is the same as show — brackets are self-delimiting, no outer parens.
instance Show a => Show (List a) where
  show xs = strAppend \"[\" (strAppend (showListElems xs) \"]\")
  showArg xs = strAppend \"[\" (strAppend (showListElems xs) \"]\")
-- first element with no leading comma; `showListRest` prefixes \", \" before each
-- remaining one. Split this way so neither reconstructs a `Cons` cell (a
-- `showListElems (Cons z zs)` rebuild leaked one cell per element).
showListElems :: Show a => List a -> String
showListElems xs = case xs of
  Nil -> \"\"
  Cons y ys -> strAppend (show y) (showListRest ys)
showListRest :: Show a => List a -> String
showListRest ys = case ys of
  Nil -> \"\"
  Cons z zs -> strAppend \", \" (strAppend (show z) (showListRest zs))
maxOr :: Ord a => a -> List a -> a
maxOr d xs = case xs of
  Nil -> d
  Cons y ys -> if le d y then maxOr y ys else maxOr d ys
minOr :: Ord a => a -> List a -> a
minOr d xs = case xs of
  Nil -> d
  Cons y ys -> if le y d then minOr y ys else minOr d ys
nub :: Eq a => List a -> List a
nub xs = case xs of
  Nil -> Nil
  Cons y ys -> Cons y (nub (filter (\\z -> if eq y z then False else True) ys))
mapM_ :: (a -> IO ()) -> List a -> IO ()
mapM_ f xs = case xs of
  Nil -> putStr \"\"
  Cons y ys -> case f y of
    _ -> mapM_ f ys
-- stream-fusion variant (§0): `rangeFused` takes the consumer's
-- step-function `c` (:: Int -> b -> b) and nil `n` (:: b) and applies
-- them directly — no intermediate Cons cells.  The --fuse pass rewrites
-- `consume (range lo hi)` → `rangeFused lo hi step base`.
rangeFused :: Int -> Int -> (Int -> b -> b) -> b -> b
rangeFused lo hi c n = if lo > hi then n else rangeFused (lo + 1) hi c (c lo n)
-- specialized variant for `sum` (foldr (+) 0): no closure, direct arithmetic.
-- Eliminates the indirect-call overhead from the generic rangeFused.
-- `sum (range lo hi)` → `rangeFusedSum lo hi 0`.
rangeFusedSum :: Int -> Int -> Int -> Int
rangeFusedSum lo hi acc = if lo > hi then acc
    else rangeFusedSum (lo + 1) hi (acc + lo)

-- standard library v1 -----------------------------------------------------

data Maybe a = Nothing | Just a deriving (Show)

data Either a b = Left a | Right b deriving (Show)

data Ordering = LT | EQ | GT deriving (Show)

-- Trit: the balanced-ternary three-state enum (spec §10.A). An ordinary N=3
-- sum type (the ternary analogue of `Ordering`): TMinus = -1, TZero = 0,
-- TPlus = +1.  A value-selecting `case` over it lowers branchless like any
-- small enum; `observe` (§9) returns it (Closed/Pending/Live → TMinus/TZero/TPlus).
data Trit = TMinus | TZero | TPlus deriving (Show)

not :: Bool -> Bool
not b = if b then False else True

-- Maybe --------------------------------------------------------------------

maybe :: b -> (a -> b) -> Maybe a -> b
maybe d f m = case m of
  Nothing -> d
  Just x -> f x

fromMaybe :: a -> Maybe a -> a
fromMaybe d m = maybe d (\\x -> x) m

isJust :: Maybe a -> Bool
isJust m = case m of
  Nothing -> False
  Just _ -> True

isNothing :: Maybe a -> Bool
isNothing m = case m of
  Nothing -> True
  Just _ -> False

catMaybes :: List (Maybe a) -> List a
catMaybes xs = case xs of
  Nil -> Nil
  Cons y ys -> case y of
      Nothing -> catMaybes ys
      Just z -> Cons z (catMaybes ys)

-- Either -------------------------------------------------------------------

either :: (a -> c) -> (b -> c) -> Either a b -> c
either f g e = case e of
  Left x -> f x
  Right y -> g y

isLeft :: Either a b -> Bool
isLeft e = case e of
  Left _ -> True
  Right _ -> False

isRight :: Either a b -> Bool
isRight e = case e of
  Left _ -> False
  Right _ -> True

-- List extensions ----------------------------------------------------------

elemBy :: Eq a => a -> List a -> Bool
elemBy x xs = case xs of
  Nil -> False
  Cons y ys -> if eq x y then True else elemBy x ys

any :: (a -> Bool) -> List a -> Bool
any p xs = case xs of
  Nil -> False
  Cons y ys -> if p y then True else any p ys

all :: (a -> Bool) -> List a -> Bool
all p xs = case xs of
  Nil -> True
  Cons y ys -> if p y then all p ys else False

find :: (a -> Bool) -> List a -> Maybe a
find p xs = case xs of
  Nil -> Nothing
  Cons y ys -> if p y then Just y else find p ys

partition :: (a -> Bool) -> List a -> (List a, List a)
partition p xs = case xs of
  Nil -> (Nil, Nil)
  Cons y ys -> case partition p ys of
    (l, r) -> if p y then (Cons y l, r) else (l, Cons y r)

sort :: Ord a => List a -> List a
sort xs = case xs of
  Nil -> Nil
  Cons y ys ->
    let less = filter (\\z -> le z y) ys in
    let greq = filter (\\z -> not (le z y)) ys in
    append (sort less) (Cons y (sort greq))

intersperse :: a -> List a -> List a
intersperse sep xs = case xs of
  Nil -> Nil
  Cons y ys -> Cons y (if null ys then ys else Cons sep (intersperse sep ys))

intercalate :: List a -> List (List a) -> List a
intercalate sep xss = concat (intersperse sep xss)

takeWhile :: (a -> Bool) -> List a -> List a
takeWhile p xs = case xs of
  Nil -> Nil
  Cons y ys -> if p y then Cons y (takeWhile p ys) else Nil

dropWhile :: (a -> Bool) -> List a -> List a
dropWhile p xs = case xs of
  Nil -> Nil
  Cons y ys -> if p y then dropWhile p ys else Cons y ys

consFst :: a -> (List a, List a) -> (List a, List a)
consFst y ab = case ab of
  (a, b) -> (Cons y a, b)

span :: (a -> Bool) -> List a -> (List a, List a)
span p xs = case xs of
  Nil -> (Nil, Nil)
  Cons y ys -> if p y then consFst y (span p ys) else (Nil, Cons y ys)

splitAt :: Int -> List a -> (List a, List a)
splitAt n xs = case xs of
  Nil -> (Nil, Nil)
  Cons y ys -> if n < 1 then (Nil, Cons y ys) else consFst y (splitAt (n - 1) ys)

concatMap :: (a -> List b) -> List a -> List b
concatMap f xs = concat (map f xs)

product :: List Int -> Int
product xs = case xs of
  Nil -> 1
  Cons y ys -> y * product ys

and :: List Bool -> Bool
and xs = case xs of
  Nil -> True
  Cons y ys -> if y then and ys else False

or :: List Bool -> Bool
or xs = case xs of
  Nil -> False
  Cons y ys -> if y then True else or ys

lookup :: Eq k => k -> List (k, v) -> Maybe v
lookup k xs = case xs of
  Nil -> Nothing
  Cons p ps -> case p of
    (a, b) -> if a == k then Just b else lookup k ps

incMaybe :: Maybe Int -> Maybe Int
incMaybe m = case m of
  Nothing -> Nothing
  Just i -> Just (i + 1)

findIndex :: (a -> Bool) -> List a -> Maybe Int
findIndex p xs = case xs of
  Nil -> Nothing
  Cons y ys -> if p y then Just 0 else incMaybe (findIndex p ys)
";

/// Lowers the typeclass instances: each method of each `instance`
/// becomes a top-level function with a mangled name (`eq$Int`), which the
/// interpreter's dynamic dispatch calls by the 1st argument's type head. The
/// `ClassDecl`s stay in the module (they give the overloaded method names to check,
/// infer e interp).
fn lower_classes(module: &mut ast::Module) {
    // (class, method) → template signature (class var marked) to specialize
    let mut sigs: std::collections::HashMap<(String, String), ast::Type> =
        std::collections::HashMap::new();
    for c in &module.classes {
        for (m, ty) in &c.methods {
            sigs.insert((c.name.clone(), m.clone()), subst_head(ty, &c.tyvar));
        }
    }
    let mut impls = Vec::new();
    for inst in &module.instances {
        for m in &inst.methods {
            let mut impl_fn = m.clone();
            impl_fn.name = ast::method_impl_name(&m.name, &inst.ty_head);
            // specialized signature: the class's, with the class var replaced by
            // the FULL instance type (`eq :: a->a->Bool` @ `Maybe a` →
            // `Maybe a -> Maybe a -> Bool`). Without this, the instance body
            // (unsigned) would look polymorphic and its method uses would fire
            // false "no constraint" errors.
            if let Some(tmpl) = sigs.get(&(inst.class_name.clone(), m.name.clone())) {
                impl_fn.sig = Some(specialize_with(tmpl, &inst.head_ty));
            }
            // context constraints (`Eq a =>`) let the method body use methods over
            // the parameter (`eq` on a field of type `a`) without AX0405.
            impl_fn.constraints = inst.constraints.clone();
            impls.push(impl_fn);
        }
    }
    module.funcs.extend(impls);
}

/// Marks the class variable in a type, replacing it with a unique sentinel
/// (`$cls`) so that `specialize` later swaps it for the instance's concrete type.
fn subst_head(ty: &ast::Type, tyvar: &str) -> ast::Type {
    match ty {
        ast::Type::Var(v) if v == tyvar => ast::Type::Var("$cls".to_string()),
        ast::Type::Var(_) | ast::Type::Con(_) | ast::Type::Unit => ty.clone(),
        ast::Type::App(f, a) => ast::Type::App(
            Box::new(subst_head(f, tyvar)),
            Box::new(subst_head(a, tyvar)),
        ),
        ast::Type::Arrow { mult, from, to } => ast::Type::Arrow {
            mult: *mult,
            from: Box::new(subst_head(from, tyvar)),
            to: Box::new(subst_head(to, tyvar)),
        },
        ast::Type::Tuple(ts) => ast::Type::Tuple(ts.iter().map(|t| subst_head(t, tyvar)).collect()),
    }
}

/// Swaps the `$cls` sentinel for the instance's full type (`Maybe a`, `Color`, …).
fn specialize_with(ty: &ast::Type, repl: &ast::Type) -> ast::Type {
    match ty {
        ast::Type::Var(v) if v == "$cls" => repl.clone(),
        ast::Type::Var(_) | ast::Type::Con(_) | ast::Type::Unit => ty.clone(),
        ast::Type::App(f, a) => ast::Type::App(
            Box::new(specialize_with(f, repl)),
            Box::new(specialize_with(a, repl)),
        ),
        ast::Type::Arrow { mult, from, to } => ast::Type::Arrow {
            mult: *mult,
            from: Box::new(specialize_with(from, repl)),
            to: Box::new(specialize_with(to, repl)),
        },
        ast::Type::Tuple(ts) => {
            ast::Type::Tuple(ts.iter().map(|t| specialize_with(t, repl)).collect())
        }
    }
}

/// Desugars `deriving (Eq, Ord, …)` on `data` declarations into synthesized
/// `instance` declarations. Each instance is generated as Axion SOURCE and
/// parsed (like the prelude), so its internal method uses get real, distinct
/// spans (the monomorphization keys on `(function, span)`) and reuse the whole
/// pipeline. Runs after `inject_prelude` (so the prelude's `Eq`/`Ord`/`Show`
/// classes exist) and before `lower_classes`.
fn derive_instances(module: &mut ast::Module, diags: &mut Diagnostics) {
    let mut existing: std::collections::HashSet<(String, String)> = module
        .instances
        .iter()
        .map(|i| (i.class_name.clone(), i.ty_head.clone()))
        .collect();
    let datas = module.datas.clone();
    let mut src = String::new();
    for d in &datas {
        for class in &d.deriving {
            // a user-written instance wins over the derived one (no clash).
            if !existing.insert((class.clone(), d.name.clone())) {
                continue;
            }
            match class.as_str() {
                "Eq" => src.push_str(&derive_eq(d)),
                "Ord" => src.push_str(&derive_ord(d)),
                "Show" => src.push_str(&derive_show(d)),
                other => diags.push(
                    Diagnostic::error(
                        "AX0411",
                        format!("cannot derive `{other}` (unknown or unsupported class)"),
                    )
                    .label(d.span.0, d.span.1, "in this `deriving` clause")
                    .with_help("derivable classes: Eq, Ord, Show."),
                ),
            }
        }
    }
    if src.is_empty() {
        return;
    }
    let lines = LineMap::new(&src);
    let Ok(tokens) = lexer::lex(&src) else {
        return;
    };
    let ltokens = layout::layout(&tokens, &lines);
    let Ok(parsed) = parser::parse_module(&ltokens) else {
        return;
    };
    module.instances.extend(parsed.instances);
}

/// The instance type in a derived header: `Color`, or `(Maybe a)` for parametric.
fn inst_head(d: &ast::DataDecl) -> String {
    if d.params.is_empty() {
        d.name.clone()
    } else {
        format!("({} {})", d.name, d.params.join(" "))
    }
}

/// The context for a derived instance: `` for non-parametric, `C a => ` for one
/// parameter, `(C a, C b) => ` for several (each parameter must also be `C`).
fn deriving_context(class: &str, params: &[String]) -> String {
    match params {
        [] => String::new(),
        [p] => format!("{class} {p} => "),
        _ => format!(
            "({}) => ",
            params
                .iter()
                .map(|p| format!("{class} {p}"))
                .collect::<Vec<_>>()
                .join(", ")
        ),
    }
}

/// The full `instance <context><Class> <head> where` line for a derived class.
fn inst_header(class: &str, d: &ast::DataDecl) -> String {
    format!(
        "instance {}{class} {} where\n",
        deriving_context(class, &d.params),
        inst_head(d)
    )
}

/// A constructor pattern `Con v0 v1 …` binding fresh vars with the given prefix,
/// plus the list of bound var names.
fn con_pattern(con: &ast::ConDecl, prefix: &str) -> (String, Vec<String>) {
    let vars: Vec<String> = (0..con.fields.len())
        .map(|i| format!("{prefix}{i}"))
        .collect();
    let mut pat = con.name.clone();
    for v in &vars {
        pat.push(' ');
        pat.push_str(v);
    }
    (pat, vars)
}

/// A constructor pattern with wildcard fields (`Con _ _`).
fn wildcard_pattern(con: &ast::ConDecl) -> String {
    let mut pat = con.name.clone();
    for _ in &con.fields {
        pat.push_str(" _");
    }
    pat
}

/// `deriving Ord`: lexicographic `le` (≤) via nested `case`. Constructors compare
/// by declaration order (earlier < later); within the same constructor, fields
/// compare lexicographically. Uses only `le` (no `Eq` dependency): for a field,
/// `if le a b then (if le b a then <rest> else True) else False` — equal keeps
/// going, strictly-less is True, strictly-greater is False.
#[allow(clippy::many_single_char_names)]
fn derive_ord(d: &ast::DataDecl) -> String {
    let mut s = format!("{}  le x y = case x of\n", inst_header("Ord", d));
    for (i, ci) in d.cons.iter().enumerate() {
        let (xpat, xs) = con_pattern(ci, "a");
        s.push_str(&format!("    {xpat} -> case y of\n"));
        // y is an earlier constructor → y < x → `x <= y` is False.
        for cj in d.cons.iter().take(i) {
            s.push_str(&format!("      {} -> False\n", wildcard_pattern(cj)));
        }
        // same constructor → lexicographic compare of the fields.
        let (ypat, ys) = con_pattern(ci, "b");
        let n = xs.len();
        let mut lexi = "True".to_string();
        for k in (0..n).rev() {
            let (a, b) = (&xs[k], &ys[k]);
            lexi = if k == n - 1 {
                format!("le {a} {b}")
            } else {
                format!("if le {a} {b} then (if le {b} {a} then {lexi} else True) else False")
            };
        }
        s.push_str(&format!("      {ypat} -> {lexi}\n"));
        // y is a later constructor → x < y → `x <= y` is True.
        s.push_str("      _ -> True\n");
    }
    s
}

/// `deriving Show`: `show x = case x of Con … -> "Con" `strAppend` " " `strAppend`
/// show f0 …`. Nullary constructors show as just the name; fields are separated by
/// spaces and shown recursively (`show`, so field types must be `Show`).
fn derive_show(d: &ast::DataDecl) -> String {
    // Two methods: `show` (top level, no outer parens) and `showArg` (argument
    // position — wraps a constructor-WITH-ARGS in parens so nested terms are
    // unambiguous: `Some (Some 3)`, not `Some Some 3`). Both build the same
    // "Con field field" body; the FIELDS recurse via `showArg`, and `showArg`
    // wraps the whole body in parens when the constructor is not nullary.
    let body = |c: &ast::ConDecl, vars: &[String]| -> String {
        let mut expr = format!("\"{}\"", c.name);
        for v in vars {
            expr = format!("strAppend (strAppend ({expr}) \" \") (showArg {v})");
        }
        expr
    };
    let mut s = format!("{}  show x = case x of\n", inst_header("Show", d));
    for c in &d.cons {
        let (pat, vars) = con_pattern(c, "a");
        s.push_str(&format!("    {pat} -> {}\n", body(c, &vars)));
    }
    s.push_str("  showArg x = case x of\n");
    for c in &d.cons {
        let (pat, vars) = con_pattern(c, "a");
        let e = body(c, &vars);
        // a nullary constructor needs no parens (an atom); one with fields does.
        let wrapped = if vars.is_empty() {
            e
        } else {
            format!("strAppend (strAppend \"(\" ({e})) \")\"")
        };
        s.push_str(&format!("    {pat} -> {wrapped}\n"));
    }
    s
}

/// `deriving Eq`: structural equality via nested `case` (outer on `x`, inner on
/// `y`), field-by-field `eq` (conjunction as `if … then … else False`).
fn derive_eq(d: &ast::DataDecl) -> String {
    let mut s = format!("{}  eq x y = case x of\n", inst_header("Eq", d));
    let multi = d.cons.len() > 1;
    for c in &d.cons {
        let (xpat, xs) = con_pattern(c, "a");
        let (ypat, ys) = con_pattern(c, "b");
        // conjunction of `eq ai bi` (right-folded), `True` when nullary.
        let mut conj = "True".to_string();
        for (a, b) in xs.iter().zip(&ys).rev() {
            conj = if conj == "True" {
                format!("eq {a} {b}")
            } else {
                format!("if eq {a} {b} then {conj} else False")
            };
        }
        s.push_str(&format!(
            "    {xpat} -> case y of\n      {ypat} -> {conj}\n"
        ));
        if multi {
            s.push_str("      _ -> False\n");
        }
    }
    s
}

/// The import declarations of a source (lex + layout + parse; empty on any error).
/// Used to walk the import graph when loading files into the salsa engine.
pub fn module_imports(src: &str) -> Vec<ast::ImportDecl> {
    let Ok(tokens) = lexer::lex(src) else {
        return Vec::new();
    };
    let lines = LineMap::new(src);
    let lt = layout::layout(&tokens, &lines);
    parser::parse_module(&lt)
        .map(|m| m.imports)
        .unwrap_or_default()
}

/// The `.axi` file an import names, relative to the importer's directory.
pub fn import_target_path(dir: &std::path::Path, import: &ast::ImportDecl) -> std::path::PathBuf {
    let mod_path = import
        .module
        .iter()
        .fold(std::path::PathBuf::new(), |p, seg| p.join(seg))
        .with_extension("axi");
    dir.join(mod_path)
}

/// Lex + layout + parse an imported module's source. Import lex/parse errors are
/// reported at the IMPORT site (`AX0901` / the parser's own error). Shared by the
/// disk (CLI) and salsa (LSP) import resolvers so both surface identical
/// diagnostics.
pub fn parse_import_text(
    src: &str,
    import: &ast::ImportDecl,
    diags: &mut Diagnostics,
) -> Option<ast::Module> {
    let tokens = match lexer::lex(src) {
        Ok(t) => t,
        Err(e) => {
            diags.push(
                Diagnostic::error("AX0901", "lex error in imported module").label(
                    import.span.0,
                    import.span.1,
                    format!("lex: {e:?}"),
                ),
            );
            return None;
        }
    };
    let lines = LineMap::new(src);
    let lt = layout::layout(&tokens, &lines);
    match parser::parse_module(&lt) {
        Ok(m) => Some(m),
        Err(e) => {
            diags.push(e);
            None
        }
    }
}

/// Resolves one import to its parsed module and the filesystem path to resolve ITS
/// (transitive) imports against. Returns `None` after pushing a diagnostic when the
/// file is missing or malformed. The CLI reads the file from disk; the salsa engine
/// reads it from a tracked input so dependents are invalidated when it changes.
pub type ImportResolver<'a> =
    dyn Fn(&std::path::Path, &ast::ImportDecl, &mut Diagnostics) -> Option<(ast::Module, String)>
        + 'a;

/// Disk-backed import resolution (the CLI path): read the file, then parse it.
pub fn disk_import_resolver(
    dir: &std::path::Path,
    import: &ast::ImportDecl,
    diags: &mut Diagnostics,
) -> Option<(ast::Module, String)> {
    let file = import_target_path(dir, import);
    let src = match std::fs::read_to_string(&file) {
        Ok(s) => s,
        Err(e) => {
            diags.push(
                Diagnostic::error("AX0900", "could not import module").label(
                    import.span.0,
                    import.span.1,
                    format!("{e}"),
                ),
            );
            return None;
        }
    };
    let module = parse_import_text(&src, import, diags)?;
    Some((module, file.to_str().unwrap_or("").to_string()))
}

/// Import resolution parameterized over how a module is fetched (disk vs. salsa
/// input). The merge logic — dedup, qualified prefixing, "skip locally defined",
/// transitive recursion — is identical for both.
pub fn resolve_imports_with(
    module: &mut ast::Module,
    path: &str,
    diags: &mut Diagnostics,
    resolve: &ImportResolver,
) {
    if module.imports.is_empty() {
        return;
    }
    let dir = std::path::Path::new(path)
        .parent()
        .unwrap_or(std::path::Path::new("."));

    let has_data: std::collections::HashSet<String> =
        module.datas.iter().map(|d| d.name.clone()).collect();
    let has_func: std::collections::HashSet<String> =
        module.funcs.iter().map(|f| f.name.clone()).collect();
    let has_class: std::collections::HashSet<String> =
        module.classes.iter().map(|c| c.name.clone()).collect();
    let has_inst: std::collections::HashSet<(String, String)> = module
        .instances
        .iter()
        .map(|i| (i.class_name.clone(), i.ty_head.clone()))
        .collect();

    let mut seen: std::collections::HashSet<Vec<String>> = std::collections::HashSet::new();
    for import in std::mem::take(&mut module.imports) {
        let key = import.module.clone();
        if !seen.insert(key.clone()) {
            continue;
        }
        let Some((mut imported, resolved_path)) = resolve(dir, &import, diags) else {
            continue;
        };
        resolve_imports_with(&mut imported, &resolved_path, diags, resolve);
        // prepend imported definitions, skipping those already defined locally.
        // qualified imports: prefix names with the alias (or last module component).
        let prefix = if import.qualified {
            import
                .alias
                .clone()
                .or_else(|| import.module.last().cloned())
                .map(|a| format!("{a}_"))
        } else {
            None
        };
        for d in imported.datas.into_iter().rev() {
            let name = if let Some(ref p) = prefix {
                p.clone() + &d.name
            } else {
                d.name.clone()
            };
            if !has_data.contains(&name) {
                let mut d = d;
                d.name = name;
                module.datas.insert(0, d);
            }
        }
        for mut f in imported.funcs.into_iter().rev() {
            let name = if let Some(ref p) = prefix {
                p.clone() + &f.name
            } else {
                f.name.clone()
            };
            if !has_func.contains(&name) {
                f.name = name;
                // rename self-references in where-bindings too
                for w in &mut f.clauses {
                    for wf in &mut w.wher {
                        if let Some(ref p) = prefix {
                            wf.name = p.clone() + &wf.name;
                        }
                    }
                }
                module.funcs.insert(0, f);
            }
        }
        for c in imported.classes.into_iter().rev() {
            if !has_class.contains(&c.name) {
                module.classes.insert(0, c);
            }
        }
        for i in imported.instances.into_iter().rev() {
            let key = (i.class_name.clone(), i.ty_head.clone());
            if !has_inst.contains(&key) {
                module.instances.insert(0, i);
            }
        }
        for f in imported.foreigns.into_iter().rev() {
            module.foreigns.insert(0, f);
        }
    }
}

/// The parsed prelude, lexed+parsed once per process. The prelude is a compile-time
/// constant, so `inject_prelude` re-parsing it on every `compile_front` was pure
/// waste; cloning the cached AST is far cheaper (and helps the salsa path too).
fn prelude_module() -> &'static ast::Module {
    static PRELUDE_AST: std::sync::OnceLock<ast::Module> = std::sync::OnceLock::new();
    PRELUDE_AST.get_or_init(|| {
        let lines = LineMap::new(PRELUDE);
        let tokens = lexer::lex(PRELUDE).unwrap_or_else(|e| panic!("prelude: lex: {e:?}"));
        let lt = layout::layout(&tokens, &lines);
        parser::parse_module(&lt).unwrap_or_else(|e| panic!("prelude: parse: {e:?}"))
    })
}

fn inject_prelude(module: &mut ast::Module) {
    let prelude = prelude_module().clone();
    let has_data: std::collections::HashSet<String> =
        module.datas.iter().map(|d| d.name.clone()).collect();
    let has_func: std::collections::HashSet<String> =
        module.funcs.iter().map(|f| f.name.clone()).collect();
    // prepend only what the user doesn't redefine (no clashes)
    for d in prelude.datas.into_iter().rev() {
        if !has_data.contains(&d.name) {
            module.datas.insert(0, d);
        }
    }
    for f in prelude.funcs.into_iter().rev() {
        if !has_func.contains(&f.name) {
            module.funcs.insert(0, f);
        }
    }
    // prelude classes and instances: inject only those the user doesn't
    // redefine — a class by name, an instance by the (class, type) pair —
    // so redeclaring `class Eq` or `instance Eq Int` replaces the prelude's
    // without clashing (duplicate method/impl names).
    let has_class: std::collections::HashSet<String> =
        module.classes.iter().map(|c| c.name.clone()).collect();
    let has_inst: std::collections::HashSet<(String, String)> = module
        .instances
        .iter()
        .map(|i| (i.class_name.clone(), i.ty_head.clone()))
        .collect();
    for c in prelude.classes.into_iter().rev() {
        if !has_class.contains(&c.name) {
            module.classes.insert(0, c);
        }
    }
    for i in prelude.instances.into_iter().rev() {
        if !has_inst.contains(&(i.class_name.clone(), i.ty_head.clone())) {
            module.instances.insert(0, i);
        }
    }
    for f in prelude.foreigns.into_iter().rev() {
        if !module.foreigns.iter().any(|u| u.name == f.name) {
            module.foreigns.insert(0, f);
        }
    }
}

/// Prints the Auto-Drop report (`--emit drops`).
fn print_drops(drops: &[check::DropPoint], path: &str, lines: &LineMap) {
    if drops.is_empty() {
        println!("Auto-Drop: no 'free' inserted.");
        return;
    }
    println!("Auto-Drop — {} 'free'(s) inserted:", drops.len());
    for d in drops {
        let (l, c) = lines.pos(d.span.0);
        println!(
            "  free({}) : {} %1  @ {path}:{l}:{c}  (in '{}', {})",
            d.var, d.ty, d.func, d.reason
        );
    }
}

/// Prints the record updates eligible for in-place mutation (`--emit inplace`).
fn print_inplace(sites: &[check::InPlace], path: &str, lines: &LineMap) {
    if sites.is_empty() {
        println!("Linear Elision: no in-place update.");
        return;
    }
    println!("Linear Elision — {} in-place update(s):", sites.len());
    for s in sites {
        let (l, c) = lines.pos(s.span.0);
        println!(
            "  '{}' mutated in-place  @ {path}:{l}:{c}  (in '{}': last live mention)",
            s.var, s.func
        );
    }
}

/// Prints the NLL reset points of sub-arenas (`--emit arenas`).
fn print_arenas(resets: &[check::ArenaReset], path: &str, lines: &LineMap) {
    if resets.is_empty() {
        println!("NLL reset: no sub-arena.");
        return;
    }
    println!("NLL reset — {} sub-arena(s):", resets.len());
    for r in resets {
        let (l, c) = lines.pos(r.span.0);
        println!(
            "  reset '{}' @ {path}:{l}:{c}  (in '{}': after the last mention of '{}')",
            r.sub, r.func, r.last_var
        );
    }
}

/// CLI `--explain`: print the long-form explanation of an `AXnnnn` code.
fn explain(code: &str) -> ExitCode {
    match explain_text(code) {
        Some(text) => {
            println!("{text}");
            ExitCode::SUCCESS
        }
        None => {
            eprintln!("unknown code: {code}");
            ExitCode::from(2)
        }
    }
}

/// The long-form text for an `AXnnnn` code (§8), or `None` if unknown. One source
/// of truth for both the CLI `--explain` and the LSP's hover.
pub fn explain_text(code: &str) -> Option<&'static str> {
    let text = match code.to_uppercase().as_str() {
        "AX0001" => {
            "AX0001 — contraction of a linear resource (consumed more than once).\n\
             READING (borrowing) a %1 is free and unlimited — Borrow Elision.\n\
             CONSUMING (moving ownership: a %1 argument, %1 field, or return) may\n\
             only happen once. To share it by ownership, use 'split' into two\n\
             %0.5 halves (§2)."
        }
        "AX0002" => {
            "AX0002 — must-use resource dropped without being consumed.\n\
             Types WITHOUT Drop (Ep, Token, handles) are must-use: they must be\n\
             consumed or returned. Droppable types, by contrast, are managed by\n\
             Auto-Drop (the compiler inserts 'free' at the death point). Only\n\
             forgetting a must-use is an error (§2)."
        }
        "AX0100" => {
            "AX0100 — syntax error. The parser could not recognize the\n\
             construct. Check parentheses, '=' and indentation."
        }
        "AX0003" => {
            "AX0003 — sub-arena escape. A value allocated in a sub-arena\n\
             (allocateCell sub) cannot be returned from withSubArena — on reset\n\
             the sub-arena's RAM is reclaimed and the value would dangle. Move it\n\
             to the parent arena before the reset with 'promote parent value' (§3)."
        }
        "AX0004" => {
            "AX0004 — use-after-move. Once you move ownership of a %1 (consume:\n\
             a %1 argument, %1 field, or return), you cannot read or consume it\n\
             again. Reading BEFORE consuming is free; reading AFTER is an error (§2)."
        }
        "AX0005" => {
            "AX0005 — use-after-release of an arena mark. 'arena_release mark'\n\
             reclaims everything allocated after 'arena_mark'; using one of those\n\
             values after the release is an error (the memory is already reclaimed).\n\
             Consume it before the release, or don't allocate it under the mark\n\
             (§3, Listing 3.6)."
        }
        "AX0006" => {
            "AX0006 — write through a %0.5 half. 'split' divides a %1 into two\n\
             shared-read %0.5 halves; a half can only be read, never written. To\n\
             recover write access, recombine the two halves with 'join a b' (which\n\
             returns the %1) (§2, Listing 2.3)."
        }
        "AX0101" => {
            "AX0101 — name not found. The identifier is not in scope\n\
             (not a parameter, local, top-level function, nor a builtin)."
        }
        "AX0200" => {
            "AX0200 — type mismatch. Unification (HM inference, Algorithm W)\n\
             failed: two types that would have to be equal are not. Check the\n\
             signatures and the arguments of applications (§16)."
        }
        "AX0201" => {
            "AX0201 — infinite type (occurs-check). Unification would require a\n\
             recursive type (a variable occurring inside the type it would be bound\n\
             to), which HM inference rejects."
        }
        "AX0300" => {
            "AX0300 — channel operation does not follow the session type. 'send'\n\
             requires an endpoint at 'Send', 'recv' at 'Recv', 'close' at 'End', and\n\
             the label of 'select' must belong to the 'Select'. Protocol fidelity is\n\
             checked statically (§6)."
        }
        "AX0301" => {
            "AX0301 — incomplete session protocol. An endpoint must be carried all\n\
             the way to 'close' (or consumed by 'offer'/'cancel'); dropping it\n\
             midway leaves the protocol unfinished (§6)."
        }
        "AX0302" => {
            "AX0302 — endpoint escape from the 'bound' nursery. Endpoints are born\n\
             confined to the 'bound' so the communication graph is a tree\n\
             (deadlock-freedom, §9); they cannot be returned from the block. Consume\n\
             them inside (close/send/recv). It is the analog of arena escape (AX0003)."
        }
        "AX0303" => {
            "AX0303 — external choice ('Offer') without the 'Closed' branch. Every\n\
             '&' must offer 'Closed' — the label that Linear Unwinding sends when\n\
             cancelling (§7); without it, cancellation of a panicking peer would go\n\
             unhandled."
        }
        "AX0304" => {
            "AX0304 — non-exhaustive 'case offer c'. A 'case' over an external choice\n\
             must handle ALL branches the 'Offer' provides (including 'Closed').\n\
             Add an arm for each label (§6/§7)."
        }
        "AX0305" => {
            "AX0305 — the 'spawn' closure captures an endpoint from outside. A\n\
             spawned child communicates with the parent only through its endpoint\n\
             parameter (parent↔child edge); capturing outside channels could form a\n\
             cycle → deadlock. The topology must be a tree (§9)."
        }
        "AX0400" => {
            "AX0400 — instance of an unknown class. 'instance C T' requires class\n\
             'C' to have been declared with 'class C a where …'. Check the spelling\n\
             of the class name."
        }
        "AX0401" => {
            "AX0401 — incomplete instance: a class method is not implemented.\n\
             An 'instance C T' must implement ALL methods declared in 'class C'\n\
             (there are no default methods yet)."
        }
        "AX0402" => {
            "AX0402 — the instance implements a method the class does not declare.\n\
             Only the methods of 'class C' may appear in an 'instance C T'. Check\n\
             the name, or add the method signature to the class."
        }
        "AX0403" => {
            "AX0403 — duplicate instance (incoherence). There can be only ONE\n\
             'instance C T' for each (class, type) pair, otherwise method resolution\n\
             would be ambiguous. Remove the repeated instance."
        }
        "AX0404" => {
            "AX0404 — method over a concrete type without an instance. A class\n\
             method used over a type T requires 'instance C T'. Declare the missing\n\
             instance, or use a type that already has one (use-site constraint\n\
             checking)."
        }
        "AX0405" => {
            "AX0405 — method used over a polymorphic type without a constraint. If a\n\
             function applies a class-C method to a value of generic type 'a', its\n\
             signature must declare 'C a =>' (otherwise there is no guarantee an\n\
             instance exists at the call site)."
        }
        "AX0202" => {
            "AX0202 — non-exhaustive patterns. A `case` does not cover every\n\
             constructor of the scrutinee's type (or lacks a catch-all `_` for an\n\
             open/large domain like Int). Add the missing arms, or a wildcard\n\
             `_ -> …`. Non-exhaustiveness is an error: there is no runtime\n\
             'pattern match failure' fallback (§ exhaustiveness)."
        }
        "AX0203" => {
            "AX0203 — unreachable pattern (warning). An arm can never match because\n\
             an earlier arm (a catch-all `_`, or a subsuming/duplicate pattern)\n\
             already covers it. Remove it or reorder the arms."
        }
        "AX0411" => {
            "AX0411 — cannot derive that class. `deriving (…)` named a class the\n\
             compiler cannot derive (only Eq, Ord, Show — incl. 1-parameter\n\
             parametric types natively). Write the instance by hand, or drop it\n\
             from the `deriving` list."
        }
        "AX0500" => {
            "AX0500 — declaration exceeds the module's LEVEL ceiling. `{-# LEVEL Ln #-}`\n\
             caps what each declaration may WRITE (its own multiplicities, level-\n\
             defining types, and builtins), on the L0–L3 progressive-disclosure scale\n\
             (§8): L0 plain strict-Haskell, L1 linear resources/arenas, L2 channels/\n\
             session types, L3 Trit/coupling. The ceiling only TIGHTENS and governs\n\
             what a decl writes, NOT what it calls — an L0 module may still depend on\n\
             an L3 library. Raise the ceiling, or drop the higher-level feature."
        }
        "AX0900" => {
            "AX0900 — could not import module. The imported module file was not\n\
             found or could not be read. Check the module name, the file path, and\n\
             the search roots."
        }
        "AX0901" => {
            "AX0901 — lex error in an imported module. The imported file itself does\n\
             not tokenize (a stray character or malformed literal there). Fix the\n\
             imported module; the error location points into it."
        }
        _ => return None,
    };
    Some(text)
}

fn print_usage() {
    eprintln!(
        "axionc — the Axion compiler\n\n\
         usage:\n  \
         axionc <file.axi>              compile and run\n  \
         axionc --check <file>          compile only (parse + typecheck + Auto-Drop)\n  \
         axionc --emit json <file>      diagnostics as JSON\n  \
         axionc --emit drops <file>     'free's inserted by Auto-Drop\n  \
         axionc --emit inplace <file>   in-place updates (Linear Elision)\n  \
         axionc --emit arenas <file>    NLL reset points of sub-arenas (static)\n  \
         axionc --emit core <file>      Axion Core IR (ANF) — the shared lowering\n  \
         axionc --emit verify <file>    drop-balance verifier: prove no double-free/UAF\n  \
         axionc --emit clif <file>      Cranelift IR of the Int core (--dev backend)\n  \
         axionc --emit llvm <file>      LLVM IR of the Int core (--release backend)\n  \
         axionc --backend cranelift <f> JIT-compile and run main :: Int (--dev)\n  \
         axionc --release <file>        compile with clang -O2 and run (--release)\n  \
         axionc --no-verify <file>      skip the default-on drop-balance safety gate\n  \
         axionc --allow-leaks <file>    permit leaks (AX0911); still gate on corruption\n  \
         axionc --explain AX0001        explain an error code"
    );
}
