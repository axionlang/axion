//! Integration tests for the walking skeleton: parse → typecheck → run,
//! and the rejection of use-after-consume (the Phase 1 goal, §17).

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
        ("sum_payload.axi", "15\n", "3 allocs, 3 frees"),
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
