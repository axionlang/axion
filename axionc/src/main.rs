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
mod codegen;
mod core;
#[allow(dead_code)]
mod diag;
mod ffi;
mod infer;
mod interp;
mod layout;
mod lexer;
mod llvm;
mod parser;

#[cfg(test)]
mod props;
#[cfg(test)]
mod session;

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
    Core,
    Clif,
    Llvm,
}

#[derive(PartialEq)]
enum Backend {
    Interp,
    Cranelift,
    Llvm,
}

fn main() -> ExitCode {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let mut check_only = false;
    let mut backend = Backend::Interp;
    let mut emit = Emit::Text;
    let mut path: Option<String> = None;

    let mut i = 0;
    while i < args.len() {
        match args[i].as_str() {
            "--check" => check_only = true,
            "--release" => backend = Backend::Llvm,
            "--backend" => {
                i += 1;
                match args.get(i).map(|s| s.as_str()) {
                    Some("cranelift") => backend = Backend::Cranelift,
                    Some("llvm") => backend = Backend::Llvm,
                    Some("interp") => backend = Backend::Interp,
                    _ => {
                        eprintln!("--backend espera 'cranelift', 'llvm' ou 'interp'");
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
                    Some("clif") => emit = Emit::Clif,
                    Some("llvm") => emit = Emit::Llvm,
                    _ => {
                        eprintln!(
                            "--emit espera 'json', 'drops', 'inplace', 'arenas', 'core', 'clif' ou 'llvm'"
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

    // spans dos `RecordUpd` elegíveis a mutação in-place (Linear Elision, §2),
    // que os backends usam para mutar o bloco em vez de alocar+copiar.
    let inplace: std::collections::HashSet<(usize, usize)> =
        analysis.inplace.iter().map(|ip| ip.span).collect();

    // --- Axión Core IR: dump da baixada ANF (partilhada pelos backends) ---
    if emit == Emit::Core {
        print!("{}", core::dump(&core::lower(&module, &inplace)));
        return ExitCode::SUCCESS;
    }

    // --- backend nativo --dev (Cranelift): dump do IR ou JIT+correr main::Int ---
    if emit == Emit::Clif {
        match codegen::emit_ir(&module, &inplace) {
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
        match llvm::emit_ir(&module, &inplace) {
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
        return match codegen::run(&module, "main", &inplace) {
            Ok(Some(n)) => {
                println!("{n}");
                ExitCode::SUCCESS
            }
            Ok(None) => ExitCode::SUCCESS, // main :: IO () — já imprimiu
            Err(e) => {
                eprintln!("backend cranelift: {e}");
                ExitCode::FAILURE
            }
        };
    }
    if backend == Backend::Llvm {
        return match llvm::build_and_run(&module, "main", &inplace) {
            Ok(()) => ExitCode::SUCCESS, // o binário já imprimiu o resultado
            Err(e) => {
                eprintln!("backend llvm (--release): {e}");
                ExitCode::FAILURE
            }
        };
    }

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
    let mut module = match parser::parse_module(&ltokens) {
        Ok(m) => m,
        Err(d) => {
            diags.push(d);
            return (None, check::Analysis::default());
        }
    };
    inject_prelude(&mut module);
    let analysis = check::check(&module, diags);
    infer::infer(&module, diags);
    (Some(module), analysis)
}

/// Prelúdio L0 embutido: o tipo `List` e as funções de lista básicas. É
/// prepended a cada módulo (só os nomes que o utilizador não redefine), para que
/// `[1..100]`/`:`/`.` (que desugaram para `range`/`Cons`/`compose`) e `map`
/// funcionem sem import. `mapM_` é um builtin (precisa do modelo de IO).
const PRELUDE: &str = "\
data List a = Nil | Cons a (List a)
compose :: (b -> c) -> (a -> b) -> a -> c
compose f g x = f (g x)
range :: Int -> Int -> List Int
range lo hi = if lo > hi then Nil else Cons lo (range (lo + 1) hi)
map :: (a -> b) -> List a -> List b
map f xs = case xs of
  Nil -> Nil
  Cons y ys -> Cons (f y) (map f ys)
";

fn inject_prelude(module: &mut ast::Module) {
    let lines = LineMap::new(PRELUDE);
    let tokens = lexer::lex(PRELUDE).expect("prelúdio: lex");
    let lt = layout::layout(&tokens, &lines);
    let prelude = parser::parse_module(&lt).expect("prelúdio: parse");
    let has_data: std::collections::HashSet<String> =
        module.datas.iter().map(|d| d.name.clone()).collect();
    let has_func: std::collections::HashSet<String> =
        module.funcs.iter().map(|f| f.name.clone()).collect();
    // prepend só o que o utilizador não redefine (sem clashes)
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
         axionc --emit arenas <fich.>   pontos de reset NLL das sub-arenas (estático)\n  \
         axionc --emit core <fich.>     Axión Core IR (ANF) — a baixada partilhada\n  \
         axionc --emit clif <fich.>     Cranelift IR do núcleo Int (backend --dev)\n  \
         axionc --emit llvm <fich.>     LLVM IR do núcleo Int (backend --release)\n  \
         axionc --backend cranelift <f> JIT-compila e corre main :: Int (--dev)\n  \
         axionc --release <fich.>       compila com clang -O2 e corre (--release)\n  \
         axionc --explain AX0001        explica um código de erro"
    );
}
