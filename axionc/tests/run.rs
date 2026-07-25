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
    // função liftada com ambiente de captura + chamada indirecta + closure
    assert!(ir.contains("lam$0 [env n]"), "sem lambda liftada:\n{ir}");
    assert!(ir.contains("callclo"), "sem chamada indirecta:\n{ir}");
    assert!(
        ir.contains("closure lam$0"),
        "sem construção de closure:\n{ir}"
    );
    // ANF: os argumentos das chamadas são átomos nomeados por `let`
    assert!(ir.contains("let "), "não está em ANF:\n{ir}");
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
