//! `axionc` — o compilador da Axión (§17–18).
//!
//! Pipeline: fonte `.axi` → lexer (logos) → layout → parser → verificação
//! (nomes + linearidade + Auto-Drop) → inferência de tipos (HM) → interpretador.
//! Diagnósticos com códigos `AXnnnn` estáveis (§8), em texto ou JSON.
//!
//! Uso:
//!   axionc <ficheiro.axi>            compila e corre
//!   axionc --check <ficheiro.axi>    só compila (parse + typecheck)
//!   axionc --emit json <ficheiro>    diagnósticos em JSON
//!   axionc --explain AX0001          explica um código de erro

// O modelo AST e alguns utilitários de diagnóstico estão deliberadamente à
// frente do que o esqueleto ambulante já consome (crescem nas fases seguintes).
#[allow(dead_code)]
mod ast;
mod check;
#[allow(dead_code)]
mod diag;
mod infer;
mod interp;
mod layout;
mod lexer;
mod parser;

#[cfg(test)]
mod props;

use diag::{Diagnostic, Diagnostics};
use lexer::LineMap;
use std::process::ExitCode;

#[derive(PartialEq)]
enum Emit {
    Text,
    Json,
    Drops,
}

fn main() -> ExitCode {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let mut check_only = false;
    let mut emit = Emit::Text;
    let mut path: Option<String> = None;

    let mut i = 0;
    while i < args.len() {
        match args[i].as_str() {
            "--check" => check_only = true,
            "--emit" => {
                i += 1;
                match args.get(i).map(|s| s.as_str()) {
                    Some("json") => emit = Emit::Json,
                    Some("drops") => emit = Emit::Drops,
                    _ => {
                        eprintln!("--emit espera 'json' ou 'drops'");
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
                    eprintln!("opção desconhecida: {other}");
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
            eprintln!("não consegui ler {path}: {e}");
            return ExitCode::from(2);
        }
    };

    let lines = LineMap::new(&src);
    let mut diags = Diagnostics::new();
    let (module, drops) = compile_front(&src, &mut diags);

    // reporta diagnósticos
    if emit == Emit::Json {
        println!("{}", serde_json::to_string_pretty(&diags.items).unwrap());
    } else {
        for d in &diags.items {
            print!("{}", d.render(&path, &src, &lines));
        }
    }

    if diags.has_errors() {
        return ExitCode::FAILURE;
    }

    if emit == Emit::Drops {
        print_drops(&drops, &path, &lines);
        return ExitCode::SUCCESS;
    }

    let module = match module {
        Some(m) => m,
        None => return ExitCode::FAILURE,
    };

    if check_only {
        if emit == Emit::Text {
            eprintln!("ok: {path} compila (parse + typecheck + linearidade + Auto-Drop).");
        }
        return ExitCode::SUCCESS;
    }

    match interp::run(&module) {
        Ok(()) => ExitCode::SUCCESS,
        Err(e) => {
            eprintln!("erro em runtime: {e}");
            ExitCode::FAILURE
        }
    }
}

/// Corre o front-end (lex → layout → parse → check → infer), acumulando
/// diagnósticos e devolvendo os `free` injectados pelo Auto-Drop.
fn compile_front(
    src: &str,
    diags: &mut Diagnostics,
) -> (Option<ast::Module>, Vec<check::DropPoint>) {
    let tokens = match lexer::lex(src) {
        Ok(t) => t,
        Err(e) => {
            diags.push(Diagnostic::error("AX0100", "caractere inesperado").label(
                e.start,
                e.end,
                "não faz parte de nenhum token",
            ));
            return (None, Vec::new());
        }
    };
    let lines = LineMap::new(src);
    let ltokens = layout::layout(&tokens, &lines);
    let module = match parser::parse_module(&ltokens) {
        Ok(m) => m,
        Err(d) => {
            diags.push(d);
            return (None, Vec::new());
        }
    };
    let drops = check::check(&module, diags);
    infer::infer(&module, diags);
    (Some(module), drops)
}

/// Imprime o relatório de Auto-Drop (`--emit drops`).
fn print_drops(drops: &[check::DropPoint], path: &str, lines: &LineMap) {
    if drops.is_empty() {
        println!("Auto-Drop: nenhum 'free' injectado.");
        return;
    }
    println!("Auto-Drop — {} 'free' injectado(s):", drops.len());
    for d in drops {
        let (l, c) = lines.pos(d.span.0);
        println!(
            "  free({}) : {} %1  @ {path}:{l}:{c}  (em '{}', morre à entrada — nunca consumido)",
            d.var, d.ty, d.func
        );
    }
}

fn explain(code: &str) -> ExitCode {
    let text = match code.to_uppercase().as_str() {
        "AX0001" => {
            "AX0001 — uso-após-consumo (contração de um recurso linear).\n\
             Todo o valor %1 é consumido exactamente uma vez. Usá-lo duas vezes é\n\
             proibido. Se precisa de o ler em dois sítios, use 'split' para obter\n\
             duas metades %0.5 (§2)."
        }
        "AX0002" => {
            "AX0002 — recurso must-use largado sem ser consumido.\n\
             Tipos SEM Drop (Ep, Token, handles) são must-use: têm de ser\n\
             consumidos ou devolvidos. Tipos droppable, ao contrário, são geridos\n\
             pelo Auto-Drop (o compilador injecta 'free' no ponto de morte). Só o\n\
             esquecimento de um must-use é erro (§2)."
        }
        "AX0100" => {
            "AX0100 — erro de sintaxe. O parser não conseguiu reconhecer\n\
             a construção. Verifique parênteses, '=' e indentação."
        }
        "AX0101" => {
            "AX0101 — nome não encontrado. O identificador não está em\n\
             âmbito (nem parâmetro, nem local, nem função de topo, nem builtin)."
        }
        other => {
            eprintln!("código desconhecido: {other}");
            return ExitCode::from(2);
        }
    };
    println!("{text}");
    ExitCode::SUCCESS
}

fn print_usage() {
    eprintln!(
        "axionc — compilador da Axión\n\n\
         uso:\n  \
         axionc <ficheiro.axi>          compila e corre\n  \
         axionc --check <ficheiro>      só compila (parse + typecheck + Auto-Drop)\n  \
         axionc --emit json <ficheiro>  diagnósticos em JSON\n  \
         axionc --emit drops <ficheiro> mostra os 'free' injectados pelo Auto-Drop\n  \
         axionc --explain AX0001        explica um código de erro"
    );
}
