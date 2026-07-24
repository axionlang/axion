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
