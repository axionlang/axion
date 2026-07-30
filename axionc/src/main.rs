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
    lower_classes(&mut module);
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
  Cons a as -> case ys of
    Nil -> Nil
    Cons b bs -> Cons (f a b) (zipWith f as bs)
zip :: List a -> List b -> List (a, b)
zip xs ys = zipWith (\\a b -> (a, b)) xs ys
unlines :: List String -> String
unlines xs = case xs of
  Nil -> \"\"
  Cons s ss -> s ++ \"\\n\" ++ unlines ss
unwords :: List String -> String
unwords xs = case xs of
  Nil -> \"\"
  Cons s ss -> case ss of
    Nil -> s
    Cons t ts -> s ++ \" \" ++ unwords ss
class Eq a where
  eq :: a -> a -> Bool
class Ord a where
  le :: a -> a -> Bool
instance Eq Int where
  eq x y = x == y
instance Ord Int where
  le x y = if x < y then True else x == y
instance Eq Bool where
  eq x y = if x then y else if y then False else True
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
";

/// Baixa as instâncias de typeclasse (fatia 1): cada método de cada `instance`
/// torna-se uma função de topo com nome mangled (`eq$Int`), a que o despacho
/// dinâmico do interpretador chama pela cabeça-de-tipo do 1º argumento. As
/// `ClassDecl` ficam no módulo (dão os nomes de método sobrecarregados ao check,
/// infer e interp).
fn lower_classes(module: &mut ast::Module) {
    // (classe, método) → assinatura-molde (var da classe marcada) p/ especializar
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
            // assinatura especializada: a da classe com a var substituída pelo
            // tipo da instância (`eq :: a->a->Bool` @ Shape → `Shape->Shape->Bool`).
            // Sem isto, o corpo da instância (sem assinatura) pareceria polimórfico
            // e os seus usos de método disparariam falsos "sem constraint".
            if let Some(tmpl) = sigs.get(&(inst.class_name.clone(), m.name.clone())) {
                impl_fn.sig = Some(specialize(tmpl, &inst.ty_head));
            }
            impls.push(impl_fn);
        }
    }
    module.funcs.extend(impls);
}

/// Marca a variável da classe num tipo, substituindo-a por um sentinela único
/// (`$cls`) para depois a `specialize` a trocar pelo tipo concreto da instância.
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

/// Troca o sentinela `$cls` pela cabeça-de-tipo concreta da instância.
fn specialize(ty: &ast::Type, ty_head: &str) -> ast::Type {
    match ty {
        ast::Type::Var(v) if v == "$cls" => ast::Type::Con(ty_head.to_string()),
        ast::Type::Var(_) | ast::Type::Con(_) | ast::Type::Unit => ty.clone(),
        ast::Type::App(f, a) => ast::Type::App(
            Box::new(specialize(f, ty_head)),
            Box::new(specialize(a, ty_head)),
        ),
        ast::Type::Arrow { mult, from, to } => ast::Type::Arrow {
            mult: *mult,
            from: Box::new(specialize(from, ty_head)),
            to: Box::new(specialize(to, ty_head)),
        },
        ast::Type::Tuple(ts) => {
            ast::Type::Tuple(ts.iter().map(|t| specialize(t, ty_head)).collect())
        }
    }
}

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
    // classes e instâncias do prelúdio: injecta só as que o utilizador não
    // redefine — uma classe pelo nome, uma instância pelo par (classe, tipo) —
    // para que redeclarar `class Eq` ou `instance Eq Int` substitua a do prelúdio
    // sem colidir (nomes de método/impl duplicados).
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
        "AX0200" => {
            "AX0200 — incompatibilidade de tipos. A unificação (inferência HM,\n\
             Algoritmo W) falhou: dois tipos que teriam de ser iguais não o são.\n\
             Verifique as assinaturas e os argumentos das aplicações (§16)."
        }
        "AX0201" => {
            "AX0201 — tipo infinito (occurs-check). A unificação exigiria um tipo\n\
             recursivo (uma variável que ocorre dentro do tipo a que seria ligada),\n\
             o que a inferência HM rejeita."
        }
        "AX0300" => {
            "AX0300 — operação de canal não segue o tipo de sessão. 'send' exige\n\
             um endpoint em 'Send', 'recv' em 'Recv', 'close' em 'End', e o rótulo\n\
             de 'select' tem de pertencer ao 'Select'. A fidelidade de protocolo é\n\
             verificada estaticamente (§6)."
        }
        "AX0301" => {
            "AX0301 — protocolo de sessão incompleto. Um endpoint tem de ser levado\n\
             até 'close' (ou consumido por 'offer'/'cancel'); largá-lo a meio deixa\n\
             o protocolo por terminar (§6)."
        }
        "AX0302" => {
            "AX0302 — escape de endpoint do nursery 'bound'. Os endpoints nascem\n\
             confinados ao 'bound' para o grafo de comunicação ser uma árvore\n\
             (deadlock-freedom, §9); não podem ser devolvidos do bloco. Consuma-os\n\
             dentro (close/send/recv). É o análogo do escape de arena (AX0003)."
        }
        "AX0303" => {
            "AX0303 — escolha externa ('Offer') sem o ramo 'Closed'. Todo o '&' tem\n\
             de oferecer 'Closed' — o rótulo que o Linear Unwinding envia ao cancelar\n\
             (§7); sem ele, o cancelamento de um par em pânico ficaria por tratar."
        }
        "AX0304" => {
            "AX0304 — 'case offer c' não exaustivo. O 'case' sobre uma escolha externa\n\
             tem de tratar TODOS os ramos que o 'Offer' oferece (incluindo 'Closed').\n\
             Acrescente um braço para cada rótulo (§6/§7)."
        }
        "AX0305" => {
            "AX0305 — a closure de 'spawn' captura um endpoint do exterior. Um filho\n\
             spawnado só comunica com o pai pelo seu endpoint-parâmetro (aresta\n\
             pai↔filho); capturar canais do exterior podia formar um ciclo → deadlock.\n\
             A topologia tem de ser uma árvore (§9)."
        }
        "AX0400" => {
            "AX0400 — instância de uma classe desconhecida. 'instance C T' exige que\n\
             a classe 'C' tenha sido declarada com 'class C a where …'. Verifique a\n\
             ortografia do nome da classe."
        }
        "AX0401" => {
            "AX0401 — instância incompleta: falta implementar um método da classe.\n\
             Uma 'instance C T' tem de implementar TODOS os métodos declarados em\n\
             'class C' (na fatia 1 ainda não há métodos por omissão)."
        }
        "AX0402" => {
            "AX0402 — a instância implementa um método que a classe não declara.\n\
             Só os métodos de 'class C' podem aparecer numa 'instance C T'. Verifique\n\
             o nome, ou acrescente a assinatura do método à classe."
        }
        "AX0403" => {
            "AX0403 — instância duplicada (incoerência). Só pode haver UMA 'instance\n\
             C T' para cada par (classe, tipo), senão a resolução de método seria\n\
             ambígua. Remova a instância repetida."
        }
        "AX0404" => {
            "AX0404 — método sobre um tipo concreto sem instância. Um método de\n\
             classe usado sobre um tipo T exige 'instance C T'. Declare a instância\n\
             em falta, ou use um tipo que já a tenha (fatia 2b: verificação de\n\
             constraints no ponto de uso)."
        }
        "AX0405" => {
            "AX0405 — método usado sobre um tipo polimórfico sem constraint. Se uma\n\
             função aplica um método de classe C a um valor de tipo genérico 'a', a\n\
             sua assinatura tem de declarar 'C a =>' (senão não há garantia de que\n\
             exista instância no ponto de chamada)."
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
