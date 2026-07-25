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
    InPlace,
    Arenas,
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
                    Some("inplace") => emit = Emit::InPlace,
                    Some("arenas") => emit = Emit::Arenas,
                    _ => {
                        eprintln!("--emit espera 'json', 'drops', 'inplace' ou 'arenas'");
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
    let (module, analysis) = compile_front(&src, &mut diags);

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
fn compile_front(src: &str, diags: &mut Diagnostics) -> (Option<ast::Module>, check::Analysis) {
    let tokens = match lexer::lex(src) {
        Ok(t) => t,
        Err(e) => {
            diags.push(Diagnostic::error("AX0100", "caractere inesperado").label(
                e.start,
                e.end,
                "não faz parte de nenhum token",
            ));
            return (None, check::Analysis::default());
        }
    };
    let lines = LineMap::new(src);
    let ltokens = layout::layout(&tokens, &lines);
    let module = match parser::parse_module(&ltokens) {
        Ok(m) => m,
        Err(d) => {
            diags.push(d);
            return (None, check::Analysis::default());
        }
    };
    let analysis = check::check(&module, diags);
    infer::infer(&module, diags);
    (Some(module), analysis)
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
            "  free({}) : {} %1  @ {path}:{l}:{c}  (em '{}', {})",
            d.var, d.ty, d.func, d.reason
        );
    }
}

/// Imprime as actualizações de registo elegíveis a mutação in-place (`--emit inplace`).
fn print_inplace(sites: &[check::InPlace], path: &str, lines: &LineMap) {
    if sites.is_empty() {
        println!("Linear Elision: nenhuma actualização in-place.");
        return;
    }
    println!(
        "Linear Elision — {} actualização(ões) in-place:",
        sites.len()
    );
    for s in sites {
        let (l, c) = lines.pos(s.span.0);
        println!(
            "  '{}' mutado in-place  @ {path}:{l}:{c}  (em '{}': última menção viva)",
            s.var, s.func
        );
    }
}

/// Imprime os pontos de reset NLL das sub-arenas (`--emit arenas`).
fn print_arenas(resets: &[check::ArenaReset], path: &str, lines: &LineMap) {
    if resets.is_empty() {
        println!("Reset NLL: nenhuma sub-arena.");
        return;
    }
    println!("Reset NLL — {} sub-arena(s):", resets.len());
    for r in resets {
        let (l, c) = lines.pos(r.span.0);
        println!(
            "  reset '{}' @ {path}:{l}:{c}  (em '{}': após a última menção de '{}')",
            r.sub, r.func, r.last_var
        );
    }
}

fn explain(code: &str) -> ExitCode {
    let text = match code.to_uppercase().as_str() {
        "AX0001" => {
            "AX0001 — contração de um recurso linear (consumido mais de uma vez).\n\
             LER (emprestar) um %1 é livre e ilimitado — a Elisão de Empréstimos.\n\
             CONSUMIR (mover a posse: argumento %1, campo %1, ou retorno) só pode\n\
             acontecer uma vez. Para o partilhar por posse, use 'split' em duas\n\
             metades %0.5 (§2)."
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
        "AX0003" => {
            "AX0003 — escape de sub-arena. Um valor alocado numa sub-arena\n\
             (allocateCell sub) não pode ser devolvido do withSubArena — no reset\n\
             a RAM da sub-arena é recuperada e o valor ficaria pendurado. Mova-o\n\
             para a arena-pai antes do reset com 'promote parent valor' (§3)."
        }
        "AX0004" => {
            "AX0004 — uso-após-move. Depois de mover a posse de um %1 (consumir:\n\
             argumento %1, campo %1, ou retorno), não se pode voltar a lê-lo nem\n\
             a consumi-lo. Ler ANTES de consumir é livre; ler DEPOIS é erro (§2)."
        }
        "AX0005" => {
            "AX0005 — uso-após-release de marca de arena. 'arena_release mark'\n\
             recupera tudo o que foi alocado depois de 'arena_mark'; usar um desses\n\
             valores após o release é erro (a memória já foi reclamada). Consuma-o\n\
             antes do release, ou não o aloque sob a marca (§3, Listagem 3.6)."
        }
        "AX0006" => {
            "AX0006 — escrita através de uma metade %0.5. 'split' divide um %1 em\n\
             duas metades %0.5 de leitura partilhada; uma metade só pode ser lida,\n\
             nunca escrita. Para recuperar a escrita, recombine as duas metades com\n\
             'join a b' (que devolve o %1) (§2, Listagem 2.3)."
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
         axionc --emit drops <ficheiro> 'free' injectados pelo Auto-Drop\n  \
         axionc --emit inplace <fich.>  actualizações in-place (Linear Elision)\n  \
         axionc --emit arenas <fich.>   pontos de reset NLL das sub-arenas\n  \
         axionc --explain AX0001        explica um código de erro"
    );
}
