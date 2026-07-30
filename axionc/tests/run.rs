//! Testes de integração do esqueleto ambulante: parse → typecheck → correr,
//! e a rejeição de uso-após-consumo (a meta da Fase 1, §17).

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
    assert_eq!(String::from_utf8_lossy(&out.stdout), "Hello, Axión!\n");
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
    assert!(!out.status.success(), "uso-após-consumo devia falhar");
    let text = String::from_utf8_lossy(&out.stdout);
    assert!(text.contains("AX0001"), "esperava AX0001, saída: {text}");
}

#[test]
fn session_well_typed_protocols_are_accepted() {
    // §6: um protocolo `Send Int End` (envia+fecha) e um `Recv Int End`
    // (recebe+fecha) seguem o tipo de sessão → aceites por `check_sessions`.
    for fx in ["session_ok.axi", "session_recv_ok.axi"] {
        let out = axionc().args(["--check", &fixture(fx)]).output().unwrap();
        assert!(
            out.status.success(),
            "{fx} devia passar: {}",
            String::from_utf8_lossy(&out.stdout)
        );
    }
}

#[test]
fn session_wrong_operation_is_rejected_ax0300() {
    // faz `recv` num endpoint cujo protocolo é `Send …` → viola a fidelidade.
    let out = axionc()
        .args(["--check", &fixture("session_bad_op.axi")])
        .output()
        .unwrap();
    assert!(!out.status.success(), "op de sessão errada devia falhar");
    let text = String::from_utf8_lossy(&out.stdout);
    assert!(text.contains("AX0300"), "esperava AX0300, saída: {text}");
}

#[test]
fn session_incomplete_protocol_is_rejected_ax0301() {
    // envia mas nunca `close` → o endpoint não completa o protocolo.
    let out = axionc()
        .args(["--check", &fixture("session_incomplete.axi")])
        .output()
        .unwrap();
    assert!(!out.status.success(), "protocolo incompleto devia falhar");
    let text = String::from_utf8_lossy(&out.stdout);
    assert!(text.contains("AX0301"), "esperava AX0301, saída: {text}");
}

#[test]
fn session_program_runs_concurrently() {
    // §11: um programa de sessão CORRE de facto — o `bound` abre o nursery, o
    // scheduler cooperativo forka o worker e faz o ping-pong (21 → 42) sem
    // deadlock, devolvendo 42.
    let out = axionc()
        .arg(fixture("session_run_pingpong.axi"))
        .output()
        .unwrap();
    assert!(
        out.status.success(),
        "devia correr: {}",
        String::from_utf8_lossy(&out.stderr)
    );
    assert_eq!(String::from_utf8_lossy(&out.stdout), "42\n");
}

#[test]
fn session_offer_and_cancel_run() {
    // §6/§7: a escolha externa (`offer`) e o cancelamento (`cancel` → `Closed`)
    // executam. Um: `select Live` → o worker despacha para o ramo Live (→7).
    // Outro: `cancel` → o worker recebe `Closed` e toma o ramo de cancelamento (→5).
    for (fx, expected) in [
        ("session_run_offer.axi", "7\n"),
        ("session_run_cancel.axi", "5\n"),
    ] {
        let out = axionc().arg(fixture(fx)).output().unwrap();
        assert!(
            out.status.success(),
            "{fx} devia correr: {}",
            String::from_utf8_lossy(&out.stderr)
        );
        assert_eq!(String::from_utf8_lossy(&out.stdout), expected, "{fx}");
    }
}

#[test]
fn session_choice_and_closed_exhaustiveness() {
    // §6/§9: escolha interna (⊕) e a exaustividade do ramo `Closed` (T5).
    let ok = |fx: &str| {
        let out = axionc().args(["--check", &fixture(fx)]).output().unwrap();
        assert!(
            out.status.success(),
            "{fx} devia passar: {}",
            String::from_utf8_lossy(&out.stdout)
        );
    };
    let reject = |fx: &str, code: &str| {
        let out = axionc().args(["--check", &fixture(fx)]).output().unwrap();
        assert!(!out.status.success(), "{fx} devia falhar");
        let text = String::from_utf8_lossy(&out.stdout);
        assert!(text.contains(code), "{fx}: esperava {code}, saída: {text}");
    };
    ok("session_select_ok.axi"); // select de um rótulo válido (⊕)
    ok("session_offer_ok.axi"); // Offer com ramo Closed (T5)
    reject("session_select_bad.axi", "AX0300"); // rótulo inexistente
    reject("session_offer_no_closed.axi", "AX0303"); // Offer sem Closed no tipo (T5)
    reject("session_offer_incomplete.axi", "AX0304"); // case omite um ramo do Offer
    reject("session_spawn_capture.axi", "AX0305"); // spawn captura endpoint (árvore)
}

#[test]
fn bound_confined_nursery_is_accepted() {
    // §9: um `bound` que cria endpoints e os consome lá dentro (nada escapa) é
    // aceite — topologia em árvore, deadlock-free por construção.
    let out = axionc()
        .args(["--check", &fixture("bound_ok.axi")])
        .output()
        .unwrap();
    assert!(
        out.status.success(),
        "nursery confinado devia passar: {}",
        String::from_utf8_lossy(&out.stdout)
    );
}

#[test]
fn bound_endpoint_escape_is_rejected_ax0302() {
    // devolver um endpoint do `bound` quebraria a topologia acíclica → AX0302.
    let out = axionc()
        .args(["--check", &fixture("bound_escape.axi")])
        .output()
        .unwrap();
    assert!(!out.status.success(), "escape de endpoint devia falhar");
    let text = String::from_utf8_lossy(&out.stdout);
    assert!(text.contains("AX0302"), "esperava AX0302, saída: {text}");
}

#[test]
fn linear_use_once_is_accepted() {
    let out = axionc()
        .args(["--check", &fixture("use_once_ok.axi")])
        .output()
        .unwrap();
    assert!(out.status.success(), "uso único devia passar");
}

#[test]
fn dropped_linear_is_rejected_ax0002() {
    let out = axionc()
        .args(["--check", &fixture("drop_linear.axi")])
        .output()
        .unwrap();
    assert!(!out.status.success());
    let text = String::from_utf8_lossy(&out.stdout);
    assert!(text.contains("AX0002"), "esperava AX0002, saída: {text}");
}

#[test]
fn listing_2_1_typechecks() {
    // 04 (Listagem 2.1): registo com campo linear + actualização de registo,
    // param Process %1 consumido uma vez. Sem main -> só --check.
    let out = axionc()
        .args(["--check", &example("04_process_inplace.axi")])
        .output()
        .unwrap();
    assert!(
        out.status.success(),
        "04 devia compilar; saída: {}",
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
    assert!(text.contains("AX0001"), "esperava AX0001, saída: {text}");
}

#[test]
fn droppable_linear_unused_is_accepted_by_autodrop() {
    // Buf é droppable: largá-lo sem consumo é OK (Auto-Drop injecta free).
    let out = axionc()
        .args(["--check", &fixture("drop_ok.axi")])
        .output()
        .unwrap();
    assert!(
        out.status.success(),
        "droppable não consumido devia ser aceite; saída: {}",
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
        "esperava um free injectado para 'b : Buf', saída: {text}"
    );
}

#[test]
fn borrowing_a_linear_twice_is_accepted() {
    // Ler (emprestar) um %1 duas vezes é permitido — não é contração.
    let out = axionc()
        .args(["--check", &fixture("borrow_twice_ok.axi")])
        .output()
        .unwrap();
    assert!(
        out.status.success(),
        "dois empréstimos deviam ser aceites; saída: {}",
        String::from_utf8_lossy(&out.stdout)
    );
}

#[test]
fn autodrop_death_point_is_the_last_read() {
    // free injectado no ponto de morte fino (após a última leitura), não à entrada.
    let out = axionc()
        .args(["--emit", "drops", &fixture("borrow_twice_ok.axi")])
        .output()
        .unwrap();
    let text = String::from_utf8_lossy(&out.stdout);
    assert!(
        text.contains("free(x)") && text.contains("após a última leitura"),
        "esperava drop na última leitura, saída: {text}"
    );
}

#[test]
fn structural_drop_makes_record_must_use_ax0002() {
    // Sess contém um campo Ep %1 → must-use por propagação estrutural → AX0002.
    let out = axionc()
        .args(["--check", &fixture("struct_mustuse.axi")])
        .output()
        .unwrap();
    assert!(!out.status.success());
    let text = String::from_utf8_lossy(&out.stdout);
    assert!(text.contains("AX0002"), "esperava AX0002, saída: {text}");
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
        "esperava free(b2), saída: {text}"
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
        "esperava AX0002 em s2, saída: {text}"
    );
}

#[test]
fn inplace_update_on_linear_base_reported() {
    // Listagem 2.1: 'p { status = ... }' é a última menção viva de 'p' (%1) →
    // mutação in-place (Linear Elision).
    let out = axionc()
        .args(["--emit", "inplace", &example("04_process_inplace.axi")])
        .output()
        .unwrap();
    assert!(out.status.success());
    let text = String::from_utf8_lossy(&out.stdout);
    assert!(
        text.contains("'p' mutado in-place"),
        "esperava in-place de p, saída: {text}"
    );
}

#[test]
fn arena_escape_is_rejected_ax0003() {
    // Um valor alocado numa sub-arena, devolvido do withSubArena → AX0003.
    let out = axionc()
        .args(["--check", &fixture("arena_escape.axi")])
        .output()
        .unwrap();
    assert!(!out.status.success());
    let text = String::from_utf8_lossy(&out.stdout);
    assert!(text.contains("AX0003"), "esperava AX0003, saída: {text}");
}

#[test]
fn arena_promote_is_accepted() {
    // 'promote parent node' move o valor para a arena-pai → não escapa.
    let out = axionc()
        .args(["--check", &fixture("arena_promote_ok.axi")])
        .output()
        .unwrap();
    assert!(
        out.status.success(),
        "promote devia ser aceite; saída: {}",
        String::from_utf8_lossy(&out.stdout)
    );
}

#[test]
fn arena_closure_capture_escape_is_rejected_ax0003() {
    // Uma closure que captura um valor da sub-arena e escapa → AX0003.
    let out = axionc()
        .args(["--check", &fixture("arena_capture.axi")])
        .output()
        .unwrap();
    assert!(!out.status.success());
    let text = String::from_utf8_lossy(&out.stdout);
    assert!(text.contains("AX0003"), "esperava AX0003, saída: {text}");
}

#[test]
fn arena_use_after_release_is_rejected_ax0005() {
    // Um valor alocado após uma marca e usado após o arena_release → AX0005.
    let out = axionc()
        .args(["--check", &fixture("arena_mark_release.axi")])
        .output()
        .unwrap();
    assert!(!out.status.success());
    let text = String::from_utf8_lossy(&out.stdout);
    assert!(text.contains("AX0005"), "esperava AX0005, saída: {text}");
}

#[test]
fn arena_mark_used_before_release_is_accepted() {
    let out = axionc()
        .args(["--check", &fixture("arena_mark_ok.axi")])
        .output()
        .unwrap();
    assert!(
        out.status.success(),
        "uso antes do release devia ser aceite; saída: {}",
        String::from_utf8_lossy(&out.stdout)
    );
}

#[test]
fn arena_reset_nll_point_reported() {
    // Reset NLL: o reset da sub-arena é injectado após a última menção viva
    // ('node', na promoção), não no fim léxico.
    let out = axionc()
        .args(["--emit", "arenas", &fixture("arena_promote_ok.axi")])
        .output()
        .unwrap();
    assert!(out.status.success());
    let text = String::from_utf8_lossy(&out.stdout);
    assert!(
        text.contains("reset 'sub'") && text.contains("node"),
        "esperava reset NLL de 'sub' após 'node', saída: {text}"
    );
}

#[test]
fn use_after_move_is_rejected_ax0004() {
    // Ler um %1 depois de a posse ter sido movida (consumida) → AX0004.
    let out = axionc()
        .args(["--check", &fixture("use_after_move.axi")])
        .output()
        .unwrap();
    assert!(!out.status.success());
    let text = String::from_utf8_lossy(&out.stdout);
    assert!(text.contains("AX0004"), "esperava AX0004, saída: {text}");
}

#[test]
fn type_mismatch_is_rejected_ax0200() {
    let out = axionc()
        .args(["--check", &fixture("type_mismatch.axi")])
        .output()
        .unwrap();
    assert!(!out.status.success());
    let text = String::from_utf8_lossy(&out.stdout);
    assert!(text.contains("AX0200"), "esperava AX0200, saída: {text}");
}

#[test]
fn inference_accepts_where_and_runs() {
    let out = axionc().arg(fixture("type_ok_poly.axi")).output().unwrap();
    assert!(
        out.status.success(),
        "saída: {}",
        String::from_utf8_lossy(&out.stdout)
    );
    assert_eq!(String::from_utf8_lossy(&out.stdout), "55\n");
}

#[test]
fn writing_through_a_fractional_half_is_rejected_ax0006() {
    // Escrever através de uma metade %0.5 (passá-la a um parâmetro %1) → AX0006.
    let out = axionc()
        .args(["--check", &fixture("frac_write.axi")])
        .output()
        .unwrap();
    assert!(!out.status.success());
    let text = String::from_utf8_lossy(&out.stdout);
    assert!(text.contains("AX0006"), "esperava AX0006, saída: {text}");
}

#[test]
fn split_join_reads_and_recombines_and_runs() {
    // split → duas metades %0.5 lidas/recombinadas por join; corre → 7.
    let out = axionc().arg(fixture("frac_join.axi")).output().unwrap();
    assert!(
        out.status.success(),
        "saída: {}",
        String::from_utf8_lossy(&out.stdout)
    );
    assert_eq!(String::from_utf8_lossy(&out.stdout), "7\n");
}

#[test]
fn lambdas_run_higher_order_and_currying() {
    // funções de ordem superior + currying via lambdas encadeadas → 42.
    let out = axionc().arg(fixture("lambda_hof.axi")).output().unwrap();
    assert!(
        out.status.success(),
        "saída: {}",
        String::from_utf8_lossy(&out.stdout)
    );
    assert_eq!(String::from_utf8_lossy(&out.stdout), "42\n");
}

#[test]
fn cranelift_backend_jits_and_runs_fib() {
    // Backend nativo --dev: JIT-compila o núcleo Int e corre main :: Int → 6765.
    let out = axionc()
        .args(["--backend", "cranelift", &fixture("native_fib.axi")])
        .output()
        .unwrap();
    assert!(
        out.status.success(),
        "saída: {}",
        String::from_utf8_lossy(&out.stderr)
    );
    assert_eq!(String::from_utf8_lossy(&out.stdout), "6765\n");
}

#[test]
fn cranelift_backend_compiles_multiclause_and_where() {
    // fibFast: multi-cláusula com padrão literal + where ('go' liftado) → 832040.
    let out = axionc()
        .args(["--backend", "cranelift", &fixture("native_fibfast.axi")])
        .output()
        .unwrap();
    assert!(
        out.status.success(),
        "saída: {}",
        String::from_utf8_lossy(&out.stderr)
    );
    assert_eq!(String::from_utf8_lossy(&out.stdout), "832040\n");
}

#[test]
fn cranelift_backend_runs_hello_with_string_io() {
    // 01_hello.axi nativo: literal de string + putStrLn (runtime axion_puts).
    let out = axionc()
        .args(["--backend", "cranelift", &example("01_hello.axi")])
        .output()
        .unwrap();
    assert!(
        out.status.success(),
        "{}",
        String::from_utf8_lossy(&out.stderr)
    );
    assert_eq!(String::from_utf8_lossy(&out.stdout), "Hello, Axión!\n");
}

#[test]
fn cranelift_backend_runs_fib_example_with_show() {
    // 02_fib.axi nativo: putStrLn (show (fibFast 30)) → 832040, igual ao interp.
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
    // record_run.axi nativo: Point{x,y} na heap (axion_alloc), update e selector.
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
    // 'case' (cadeia de if) + tuplos na heap; nativo e interp concordam (200).
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

    // o mesmo programa no interpretador (main :: Int imprime o resultado)
    let interp = axionc().arg(fixture("native_case.axi")).output().unwrap();
    assert_eq!(
        String::from_utf8_lossy(&interp.stdout),
        String::from_utf8_lossy(&native.stdout),
        "nativo e interpretador divergem"
    );
}

#[test]
fn cranelift_backend_compiles_closures() {
    // closures: lambda-lifting + captura (addN) + chamada indirecta (apply).
    // main = apply (addN 10) 32 = 42; nativo e interp concordam.
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
        "nativo e interpretador divergem"
    );
}

#[test]
fn auto_drop_frees_local_heap_at_runtime() {
    // Reclamação real (Auto-Drop §2): cada chamada de 'step' aloca um tuplo
    // local e liberta-o → 300 allocs == 300 frees, memória constante, sem GC.
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
        "esperava reclamação total, stats: {stats}"
    );

    // o mesmo resultado no interpretador (cross-check)
    let interp = axionc().arg(fixture("heap_loop.axi")).output().unwrap();
    assert_eq!(String::from_utf8_lossy(&interp.stdout), "90300\n");
}

#[test]
fn cross_function_reclamation_frees_moved_linear_object() {
    // 'make' aloca um Box e devolve-o; 'take' recebe-o por %1 e liberta-o. O
    // objecto atravessa a fronteira e é libertado exactamente uma vez.
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
        "esperava reclamação entre funções (1==1), stats: {stats}"
    );
    // o param %1 é libertado no callee (nó de drop no Core)
    let core = axionc()
        .args(["--emit", "core", &fixture("linear_move.axi")])
        .output()
        .unwrap();
    assert!(
        String::from_utf8_lossy(&core.stdout).contains("drop b"),
        "esperava 'drop b' no corpo de 'take'"
    );
}

#[test]
fn borrowed_arg_reclaimed_after_call() {
    // 'dist' só lê os campos do registo (empréstimo puro), pelo que 'main' — que
    // o aloca — o liberta APÓS a chamada, em vez de o dar por perdido: 1==1.
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
        "esperava reclamação do argumento emprestado (1==1), stats: {stats}"
    );
    // o drop do registo tem de vir DEPOIS da chamada que o empresta
    let core = axionc()
        .args(["--emit", "core", &fixture("borrow_reclaim.axi")])
        .output()
        .unwrap();
    let core = String::from_utf8_lossy(&core.stdout);
    // procura só dentro do corpo de `main` (o prelúdio injectado traz outras
    // funções com temporários `_tN` à frente no dump).
    let main = &core[core.find("main  =").expect("função main no Core")..];
    let call = main.find("call dist").expect("chamada a dist");
    let drop = main.find("drop _t0").expect("drop do registo");
    assert!(
        drop > call,
        "o drop tem de vir depois da chamada emprestada:\n{main}"
    );
}

#[test]
fn deep_drop_reclaims_nested_objects() {
    // Deep-drop (§2): objectos aninhados (registo-em-registo e payload de
    // tipo-soma) são reclamados por destrutores gerados — allocs == frees, em vez
    // de perder o objecto interno (free plano).
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
            "{fx}: esperava '{allocs}' (deep-drop reclama o aninhado), stats: {stats}"
        );
    }
    // o destrutor recursivo aparece no Core para o tipo aninhado
    let core = axionc()
        .args(["--emit", "core", &fixture("nested_drop.axi")])
        .output()
        .unwrap();
    assert!(
        String::from_utf8_lossy(&core.stdout).contains("axion_drop_Box"),
        "esperava o destrutor gerado 'axion_drop_Box' no Core"
    );
}

#[test]
fn arena_runs_natively_with_bulk_reset() {
    // Arena (§3): 'withArena' cria a raiz, allocN bump-aloca 100 células, e a
    // arena é reclamada com UM só reset (não 100 frees). O interpretador não
    // corre arenas (são --check-only), logo verifica-se só o nativo + stats.
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
        "esperava 100 células e 1 reset em massa, stats: {stats}"
    );
}

#[test]
fn buffer_sum_runs_natively() {
    // Buffer U8 (§4/§5): newBuffer/bufIota/sumBytes/free. sum(0..99)=4950.
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
    // Buffer %1 + XOR in-place (§5): o fio linear corre; encrypt consome+devolve.
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
    // `imperative $ do xorInPlace buf 0x5A` desugar → xorInPlace buf 90 → 126444.
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
    // `do { putStrLn a; putStrLn b }` corre as duas instruções em ordem. Testa-se
    // no backend nativo — o interpretador usa um modelo de IO de acção única
    // (só corre a acção final de main), não sequencia (§ limitação assumida).
    let out = axionc()
        .args(["--backend", "cranelift", &fixture("do_io.axi")])
        .output()
        .unwrap();
    assert!(out.status.success());
    assert_eq!(String::from_utf8_lossy(&out.stdout), "um\ndois\n");
}

#[test]
fn fizzbuzz_runs_l0() {
    // Listagem 1.3 da spec (L0): FizzBuzz com ranges `[1..15]`, composição `.`,
    // `mapM_`, guardas e `mod`. Um exemplo "dia 1" da spec, a correr.
    let out = axionc().arg(example("03b_fizzbuzz.axi")).output().unwrap();
    assert!(
        out.status.success(),
        "FizzBuzz devia correr: {}",
        String::from_utf8_lossy(&out.stderr)
    );
    let text = String::from_utf8_lossy(&out.stdout);
    assert!(
        text.starts_with("1\n2\nFizz\n4\nBuzz\nFizz\n") && text.contains("FizzBuzz"),
        "saída inesperada:\n{text}"
    );
}

#[test]
fn list_syntax_and_ops_l0() {
    // §1 (L0): literais `[..]`, cons `:`, `map`, `range` — o tipo `List` vem do
    // prelúdio embutido (sem `data` do utilizador). Resultado 26.
    let out = axionc().arg(fixture("list_ops.axi")).output().unwrap();
    assert!(
        out.status.success(),
        "listas deviam correr: {}",
        String::from_utf8_lossy(&out.stderr)
    );
    assert_eq!(String::from_utf8_lossy(&out.stdout), "26\n");
}

#[test]
fn parametric_data_types_work() {
    // §1 (L0): tipos-soma paramétricos (`Maybe a`, `Either a b`) — os construtores
    // generalizam sobre os parâmetros de tipo. Corre nos três executores.
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
    // Tipo-soma (3 construtores) com tag em runtime; o case compara o tag e
    // destructura. val(Pos 7)+val Neg+val Zero = 6. Igual nos três executores.
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
    // FFI: `foreign labs :: Int -> Int` chama a labs() da libc (dlsym). Corre
    // nos três executores; labs(-42) = 42.
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
    // `case p of Point a b -> a + b` (tipo de um só construtor). interp e nativo
    // concordam (7).
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
    // foldBytes (+) 0 buf: dobra a closure sobre os bytes (chamada indirecta por
    // byte no runtime). soma dos bytes 0..99 = 4950.
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
    // guardas → cadeia de if; interp e nativo concordam (0).
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
    // Linear Elision (§2): 'bump c = c { val = 99 }' com c :: Cell %1 muta o
    // bloco (nó `update!` no Core) → 1 só alocação, não 2. Resultado 99.
    let core = axionc()
        .args(["--emit", "core", &fixture("inplace_update.axi")])
        .output()
        .unwrap();
    assert!(
        String::from_utf8_lossy(&core.stdout).contains("update!"),
        "esperava o nó in-place `update!` no Core"
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
        "in-place devia poupar a alocação da cópia, stats: {stats}"
    );
}

#[test]
fn operator_section_is_a_first_class_value() {
    // `(+)` como valor (secção) passada a uma HOF: apply2 (+) 3 4 = 7.
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
    // O programa-alvo 5 (§5, elisão de empréstimos) compila INTACTO: foldBytes
    // com a secção `(+)`, U8/U32, e a elisão (checksum empresta, depois encrypt
    // consome — sem AX0001). Sem main → só --check.
    let out = axionc()
        .args(["--check", &example("05_checksum_borrow.axi")])
        .output()
        .unwrap();
    assert!(
        out.status.success(),
        "05 devia compilar: {}",
        String::from_utf8_lossy(&out.stdout)
    );
}

#[test]
fn example_03_linear_buffer_compiles_and_runs() {
    // O programa-alvo 3 (§5) corre INTACTO: Buffer U8 %1 + imperative $ do +
    // withBuffer + \-lambda. main :: IO () (só aloca/xor/liberta, sem output).
    let out = axionc()
        .args(["--backend", "cranelift", &example("03_linear_buffer.axi")])
        .output()
        .unwrap();
    assert!(
        out.status.success(),
        "03 devia correr: {}",
        String::from_utf8_lossy(&out.stderr)
    );
}

#[test]
fn linear_buffer_consumed_twice_is_rejected_ax0001() {
    // consumir o Buffer %1 duas vezes (xorInPlace) → contração → AX0001.
    let out = axionc()
        .args(["--check", &fixture("buffer_use_twice.axi")])
        .output()
        .unwrap();
    assert!(!out.status.success());
    let text = String::from_utf8_lossy(&out.stdout);
    assert!(text.contains("AX0001"), "esperava AX0001, saída: {text}");
}

#[test]
fn arena_escape_still_rejected_statically_ax0003() {
    // a reclamação em runtime não dispensa a análise estática de escape.
    let out = axionc()
        .args(["--check", &fixture("arena_escape.axi")])
        .output()
        .unwrap();
    assert!(!out.status.success());
    assert!(String::from_utf8_lossy(&out.stdout).contains("AX0003"));
}

#[test]
fn auto_drop_inserts_drop_nodes_in_core() {
    // o tuplo local do 'case' é libertado à cabeça do braço (após destructuração).
    let out = axionc()
        .args(["--emit", "core", &fixture("native_case.axi")])
        .output()
        .unwrap();
    assert!(out.status.success());
    let ir = String::from_utf8_lossy(&out.stdout);
    assert!(ir.contains("drop _t1"), "sem nó de drop no Core:\n{ir}");
}

#[test]
fn emit_core_dumps_anf_ir() {
    // o Core IR (ANF) da closure: converte a lambda e a aplicação indirecta.
    let out = axionc()
        .args(["--emit", "core", &fixture("native_closure.axi")])
        .output()
        .unwrap();
    assert!(out.status.success());
    let ir = String::from_utf8_lossy(&out.stdout);
    // função liftada com ambiente de captura + chamada indirecta + closure. O
    // índice da lambda (`lam$N`) não é fixado — o prelúdio também traz lambdas
    // ao dump; a captura de `n` é que identifica esta.
    assert!(
        ir.contains("[env n]"),
        "sem lambda liftada com captura:\n{ir}"
    );
    assert!(ir.contains("callclo"), "sem chamada indirecta:\n{ir}");
    assert!(
        ir.contains("closure lam$"),
        "sem construção de closure:\n{ir}"
    );
    // ANF: os argumentos das chamadas são átomos nomeados por `let`
    assert!(ir.contains("let "), "não está em ANF:\n{ir}");
}

#[test]
fn emit_llvm_dumps_llvm_ir() {
    // o backend --release (§18) baixa o MESMO Core para LLVM IR textual.
    // Verifica-se o IR sem invocar o clang (que pode não estar no CI).
    let out = axionc()
        .args(["--emit", "llvm", &fixture("native_fib.axi")])
        .output()
        .unwrap();
    assert!(out.status.success());
    let ir = String::from_utf8_lossy(&out.stdout);
    assert!(
        ir.contains("define i64 @\"ax_fib\"(i64"),
        "sem def de fib:\n{ir}"
    );
    assert!(ir.contains("call i64 @\"ax_fib\""), "sem recursão:\n{ir}");
    assert!(ir.contains("phi i64"), "sem phi do if:\n{ir}");
    assert!(
        ir.contains("define i32 @main()") && ir.contains("@printf"),
        "sem driver que imprime:\n{ir}"
    );
}

#[test]
fn release_backend_compiles_and_runs_when_clang_present() {
    // se houver clang (AXION_CLANG ou no PATH), o --release compila e corre, e
    // o seu output coincide com o do --dev em todo o Core (registos, closures,
    // strings/IO, case, arenas, drops).
    let clang = std::env::var("AXION_CLANG").unwrap_or_else(|_| "clang".into());
    if std::process::Command::new(&clang)
        .arg("--version")
        .output()
        .is_err()
    {
        return; // sem clang neste ambiente — o teste de IR acima já cobre
    }
    let cases = [
        (fixture("native_fib.axi"), "6765\n"),
        (fixture("native_case.axi"), "200\n"), // case + tuplos
        (fixture("native_closure.axi"), "42\n"), // closures
        (fixture("record_run.axi"), "99\n"),   // registos na heap
        (fixture("linear_move.axi"), "42\n"),  // Auto-Drop + free
        (fixture("arena_run.axi"), "100\n"),   // arenas
        (fixture("buffer_sum.axi"), "4950\n"), // Buffer U8 / §4
        (fixture("buffer_linear.axi"), "126444\n"), // Buffer %1 in-place / §5
        (fixture("inplace_update.axi"), "99\n"), // Linear Elision / §2
        (fixture("ffi_labs.axi"), "42\n"),     // FFI via dlsym / §18
        (example("01_hello.axi"), "Hello, Axión!\n"), // strings / IO
        (example("02_fib.axi"), "832040\n"),
        (fixture("mono_typeclass.axi"), "20\n"), // typeclasses monomorfizadas → nativo
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
            "--release divergiu em {path}"
        );
    }
}

#[test]
fn native_runtime_is_leak_free_under_lsan() {
    // A proposta de valor da Axión é memória segura sem GC. Compila fixtures de
    // heap/arena/empréstimo com o LLVM IR do --release + AddressSanitizer +
    // LeakSanitizer e exige execução limpa (0 corrupção, 0 fugas). Cobre em
    // particular as duas fugas fechadas: a closure do `withArena` (arena_run) e
    // a base de um update por cópia (update_borrow). Precisa de clang.
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
    ] {
        // baixa para LLVM IR
        let ll = dir.join(format!("{name}.ll"));
        let ir = axionc()
            .args(["--emit", "llvm", &fixture(&format!("{name}.axi"))])
            .output()
            .unwrap();
        assert!(ir.status.success(), "{name}: --emit llvm falhou");
        std::fs::write(&ll, &ir.stdout).unwrap();
        // compila com ASan + LSan
        let exe = dir.join(format!("{name}.san"));
        let cc = std::process::Command::new(&clang)
            .args(["-fsanitize=address,leak", "-O1", "-w"])
            .arg(&ll)
            .arg(&rt)
            .arg("-o")
            .arg(&exe)
            .status()
            .unwrap();
        assert!(cc.success(), "{name}: clang+sanitizer falhou");
        // corre com deteção de fugas ligada — tem de sair limpo
        let run = std::process::Command::new(&exe)
            .env("ASAN_OPTIONS", "detect_leaks=1")
            .output()
            .unwrap();
        assert!(
            run.status.success(),
            "{name}: ASan/LSan reportou erro:\n{}",
            String::from_utf8_lossy(&run.stderr)
        );
    }
    let _ = std::fs::remove_dir_all(&dir);
}

#[test]
fn ffi_calls_user_shared_library() {
    // FFI (§18) a `dlopen`: `foreign "lib.so" nome :: …` carrega a `.so` do
    // utilizador e chama-a nos três executores (interp, --dev, --release).
    // Precisa de clang para compilar a `.so`.
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
    assert!(ok, "clang não compilou a .so de teste");

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
            "FFI a .so do utilizador divergiu em {args:?}"
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
        "IR inesperado: {text}"
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
        "JSON inesperado: {text}"
    );
}

#[test]
fn list_stdlib_functions() {
    // Biblioteca de listas do prelúdio (degrau 1 → propósito geral): length,
    // append, reverse, foldr, foldl, take, drop, filter, null, elem, sum.
    let out = axionc().arg(fixture("list_stdlib.axi")).output().unwrap();
    assert!(
        out.status.success(),
        "stdlib devia correr: {}",
        String::from_utf8_lossy(&out.stderr)
    );
    assert_eq!(String::from_utf8_lossy(&out.stdout), "414\n");
}

#[test]
fn user_defined_infix_operators() {
    // Degrau 2: `x `f` y` ≡ `f x y` para uma função nomeada. Corre nos três
    // executores (1ª ordem → também nativo): 100 `min` (7 `plus` 5) = 12.
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
    // Degrau 3 da stdlib: ++ (concatenação), concat, zipWith, zip. Puro Axión
    // sobre List. 20 + 6 + 140 + 11 = 177.
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
    // `++` sobre listas baixa a `append` (1ª ordem) → corre nos três executores.
    // sum ([1,2] ++ [3,4] ++ [10]) = 20 em interp e Cranelift.
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
    // Strings mais ricas: ++, unwords, unlines, putStr (nível-interp, como IO).
    let out = axionc().arg(fixture("rich_strings.axi")).output().unwrap();
    assert!(
        out.status.success(),
        "rich_strings: {}",
        String::from_utf8_lossy(&out.stderr)
    );
    assert_eq!(
        String::from_utf8_lossy(&out.stdout),
        "Olá Axión!\nlinha 1\nlinha 2\n"
    );
}

#[test]
fn typeclasses_dispatch_and_constraints() {
    // Fatia 1 das typeclasses: class/instance + despacho dinâmico pela cabeça-de-
    // tipo do 1º argumento, e polimorfismo restrito `Eq a =>`. Duas classes,
    // instância que reutiliza métodos de outra, função genérica `count`.
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
    // Solidificação da fatia 1: maxOr/minOr (Ord a =>) e nub (Eq a =>) no
    // prelúdio, a despachar para as instâncias Eq Int / Ord Int. 9 + 1 + 4 = 14.
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
    // Não-regressão nativa: as novas funções genéricas (maxOr/nub) chamam métodos
    // → são interp-only e o filtro nativo exclui-as. A prova de que o nativo
    // continua a compilar está no teste release_backend_compiles_and_runs_*.
}

#[test]
fn typeclass_coherence_is_checked_statically() {
    // Fatia 2a: coerência/completude de classes e instâncias em compile-time.
    let reject = |fx: &str, code: &str| {
        let out = axionc().args(["--check", &fixture(fx)]).output().unwrap();
        assert!(!out.status.success(), "{fx} devia falhar");
        let text = String::from_utf8_lossy(&out.stdout);
        assert!(text.contains(code), "{fx}: esperava {code}, saída: {text}");
    };
    reject("tc_unknown_class.axi", "AX0400"); // instância de classe não declarada
    reject("tc_missing_method.axi", "AX0401"); // método da classe em falta
    reject("tc_extra_method.axi", "AX0402"); // método fora da classe
    reject("tc_dup_instance.axi", "AX0403"); // instância duplicada (incoerência)
}

#[test]
fn monomorphized_typeclass_runs_on_all_backends() {
    // Fatia 2b-ii: um uso de método sobre um tipo concreto é reescrito para uma
    // chamada directa à impl → compila nativamente. Interp e --dev concordam em
    // 20 (o --release está coberto por release_backend_compiles_and_runs_*).
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
fn typeclass_constraints_are_checked_at_use_site() {
    // Fatia 2b-i: verificação estática de constraints no ponto de uso.
    let reject = |fx: &str, code: &str| {
        let out = axionc().args(["--check", &fixture(fx)]).output().unwrap();
        assert!(!out.status.success(), "{fx} devia falhar");
        let text = String::from_utf8_lossy(&out.stdout);
        assert!(text.contains(code), "{fx}: esperava {code}, saída: {text}");
    };
    reject("tc_no_instance.axi", "AX0404"); // método sobre tipo concreto sem instância
    reject("tc_unconstrained_method.axi", "AX0405"); // uso polimórfico sem constraint

    // Positivo: com `Eq a =>` declarado, compila e resolve à instância (→ True).
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
