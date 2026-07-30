//! Verificação estática: resolução de nomes (AX0101) + análise de linearidade
//! **fina** com **Auto-Drop** (§2).
//!
//! Liveness fina distingue duas formas de usar um `%1`:
//! - **empréstimo** (ler sem consumir — a Elisão de Empréstimos, §2): livre e
//!   ilimitado;
//! - **consumo** (a posse flui para fora: argumento de um parâmetro `%1`, campo
//!   `%1`, ou valor de retorno): no máximo **uma** vez.
//!
//! A posição de cada ocorrência decide qual é. Daí a regra:
//! - **consumos > 1** ⇒ `AX0001` (contração — mover a posse duas vezes);
//! - **consumos == 0** e tipo **must-use** (sem `Drop`: `Ep`, `Token`, handles)
//!   ⇒ `AX0002`;
//! - **consumos == 0** e tipo **droppable** ⇒ Auto-Drop injecta `free` no ponto
//!   de morte (a última leitura, ou a entrada se nunca lido); reportado por
//!   `--emit drops`;
//! - **consumos == 1** ⇒ posse transferida, sem drop.
//!
//! Ramos alternativos (`if`, `case`) contam como caminhos (máximo, não soma).
//!
//! A ORDEM também é verificada: uma travessia na ordem de avaliação detecta o
//! uso de um `%1` **depois** de a posse ter sido movida (uso-após-move ⇒
//! `AX0004`). `x + sink x` (ler antes de consumir) é aceite; `sink x + x` não.
//!
//! Regiões (§3): a análise de escape de sub-arena (`AX0003`) segue a
//! proveniência dos valores de `withSubArena parent (\sub -> …)` — um valor
//! `allocateCell sub` que seja devolvido escapa, salvo se `promote parent` o
//! mover à arena-pai.

use crate::ast::*;
use crate::diag::{Diagnostic, Diagnostics};
use std::collections::{HashMap, HashSet};

/// Tipos primitivos **sem `Drop`** (must-use): esquecê-los é erro, não Auto-Drop.
/// `Drop` propaga estruturalmente: um registo é must-use se algum campo o for.
/// Tudo o resto é droppable por omissão (§2).
const MUST_USE_PRIMS: &[&str] = &["Ep", "Token", "Endpoint", "Transaction", "Buffer"];

/// Um `free` injectado pelo Auto-Drop no ponto de morte de um recurso linear.
#[derive(Debug, Clone)]
pub struct DropPoint {
    pub func: String,
    pub var: String,
    pub ty: String,
    pub span: Span,
    /// Porquê morre aqui (nunca usado, ou após a última leitura).
    pub reason: &'static str,
}

/// Uma actualização de registo que o compilador pode fazer **in-place** (§2):
/// o base é um recurso linear e esta é a sua última menção viva.
#[derive(Debug, Clone)]
pub struct InPlace {
    pub func: String,
    pub var: String,
    pub span: Span,
}

/// Um reset de sub-arena injectado no **ponto de morte** da região (reset NLL,
/// §3): a última menção viva de um valor da sub-arena, não o fim léxico.
#[derive(Debug, Clone)]
pub struct ArenaReset {
    pub func: String,
    pub sub: String,
    pub span: Span,
    pub last_var: String,
}

/// Resultado da análise: `free` do Auto-Drop, actualizações in-place, e os
/// pontos de reset NLL das sub-arenas.
#[derive(Default)]
pub struct Analysis {
    pub drops: Vec<DropPoint>,
    pub inplace: Vec<InPlace>,
    pub arenas: Vec<ArenaReset>,
}

/// Corre a verificação e devolve os `free` do Auto-Drop e os sítios in-place.
pub fn check(module: &Module, diags: &mut Diagnostics) -> Analysis {
    let mut globals: HashSet<String> = builtins();
    for f in &module.funcs {
        globals.insert(f.name.clone());
    }
    for fo in &module.foreigns {
        globals.insert(fo.name.clone());
    }
    // construtores e selectores de campo tornam-se nomes globais chamáveis
    for d in &module.datas {
        for c in &d.cons {
            globals.insert(c.name.clone());
            for f in &c.fields {
                if !f.name.is_empty() {
                    globals.insert(f.name.clone());
                }
            }
        }
    }
    // nomes de método de typeclasse são chamáveis (o despacho é dinâmico)
    for class in &module.classes {
        for (m, _) in &class.methods {
            globals.insert(m.clone());
        }
    }
    let ctx = build_ctx(module);
    let mut out = Analysis::default();
    for f in &module.funcs {
        check_func(f, &globals, &ctx, diags, &mut out);
    }
    check_sessions(module, diags);
    check_bound_escapes(module, diags);
    check_instances(module, diags);
    out
}

/// Coerência estática de typeclasses (fatia 2a). Cada `instance`:
/// - refere uma classe declarada (**AX0400**);
/// - implementa TODOS os métodos dessa classe (**AX0401** por método em falta);
/// - não implementa métodos que a classe não declara (**AX0402**);
/// - é única para o seu par (classe, tipo) — sem sobreposição (**AX0403**).
///
/// É a metade estática da fatia 2: apanha em compile-time o que antes só rebentava
/// no despacho em runtime (método em falta, typo no nome, instância a mais).
fn check_instances(module: &Module, diags: &mut Diagnostics) {
    use std::collections::HashMap;
    let class_methods: HashMap<&str, HashSet<&str>> = module
        .classes
        .iter()
        .map(|c| {
            (
                c.name.as_str(),
                c.methods.iter().map(|(m, _)| m.as_str()).collect(),
            )
        })
        .collect();

    let mut seen: HashSet<(String, String)> = HashSet::new();
    for inst in &module.instances {
        if !seen.insert((inst.class_name.clone(), inst.ty_head.clone())) {
            diags.push(
                Diagnostic::error(
                    "AX0403",
                    format!(
                        "instância duplicada de `{}` para `{}`",
                        inst.class_name, inst.ty_head
                    ),
                )
                .label(
                    inst.span.0,
                    inst.span.1,
                    "já existe uma instância para este tipo",
                )
                .with_help(
                    "cada par (classe, tipo) só pode ter UMA instância — a \
                     resolução de método tem de ser inequívoca (coerência).",
                ),
            );
            continue;
        }
        let Some(methods) = class_methods.get(inst.class_name.as_str()) else {
            diags.push(
                Diagnostic::error(
                    "AX0400",
                    format!("instância de classe desconhecida `{}`", inst.class_name),
                )
                .label(inst.span.0, inst.span.1, "esta classe não foi declarada")
                .with_help("declare `class C a where …` antes de a instanciar."),
            );
            continue;
        };
        let impl_names: HashSet<&str> = inst.methods.iter().map(|f| f.name.as_str()).collect();
        for m in methods {
            if !impl_names.contains(m) {
                diags.push(
                    Diagnostic::error(
                        "AX0401",
                        format!(
                            "a instância `{} {}` não implementa o método `{m}`",
                            inst.class_name, inst.ty_head
                        ),
                    )
                    .label(
                        inst.span.0,
                        inst.span.1,
                        "método da classe em falta nesta instância",
                    )
                    .with_help("uma instância tem de implementar todos os métodos da classe."),
                );
            }
        }
        for f in &inst.methods {
            if !methods.contains(f.name.as_str()) {
                diags.push(
                    Diagnostic::error(
                        "AX0402",
                        format!(
                            "`{}` não é um método da classe `{}`",
                            f.name, inst.class_name
                        ),
                    )
                    .label(f.span.0, f.span.1, "método desconhecido nesta classe")
                    .with_help("verifique o nome do método, ou declare-o na `class`."),
                );
            }
        }
    }
}

// --- confinamento do nursery `bound` (§9): deadlock-freedom estrutural ---
//
// A deadlock-freedom «por construção» vem de o grafo de comunicação ser uma
// árvore: os endpoints nascem confinados ao `bound` e não podem escapar (senão
// poderiam ligar nurseries em ciclo). Este passe impõe o confinamento — um
// endpoint criado dentro de um `bound` (por `newChannel`/`spawn`, ou avançado por
// `send`/`recv`) não pode ser o valor de retorno do bloco. **AX0302**. É o análogo
// do escape de sub-arena (AX0003), mas SEM escotilha (não há `promote` de
// endpoints — é esse o ponto). A região é o próprio corpo do `bound`.

/// O que uma expressão produz, em termos de endpoints (para propagar a posse).
enum Prod {
    Both, // `newChannel` → par (Ep, Ep): ambos são endpoints
    Snd,  // `recv` → (valor, Ep): só o 2.º é endpoint
    One,  // `send`/`spawn`/var-endpoint → um endpoint
    No,
}

/// Reconhece `bound <corpo>` (ou `bound arena <corpo>`) e devolve o corpo.
fn as_bound(e: &Expr) -> Option<&Expr> {
    let (head, args) = app_spine(e);
    match head {
        Some("bound") if !args.is_empty() => Some(*args.last().unwrap()),
        _ => None,
    }
}

fn check_bound_escapes(module: &Module, diags: &mut Diagnostics) {
    for f in &module.funcs {
        for c in &f.clauses {
            if let Body::Plain(e) = &c.body {
                find_bounds(e, diags);
            }
        }
    }
}

fn find_bounds(e: &Expr, diags: &mut Diagnostics) {
    if let Some(body) = as_bound(e) {
        check_bound(body, diags);
    }
    let mut go = |e: &Expr| find_bounds(e, diags);
    match e {
        Expr::App(f, a, _) => {
            go(f);
            go(a);
        }
        Expr::BinOp(_, l, r, _) => {
            go(l);
            go(r);
        }
        Expr::If(c, t, el, _) => {
            go(c);
            go(t);
            go(el);
        }
        Expr::Let(binds, body, _) => {
            for cl in binds.iter().flat_map(|b| &b.clauses) {
                if let Body::Plain(e2) = &cl.body {
                    go(e2);
                }
            }
            go(body);
        }
        Expr::Case(s, arms, _) => {
            go(s);
            for (_, b) in arms {
                go(b);
            }
        }
        Expr::Tuple(es, _) => es.iter().for_each(&mut go),
        Expr::RecordCon(_, assigns, _) | Expr::RecordUpd(_, assigns, _) => {
            assigns.iter().for_each(|(_, e)| go(e))
        }
        Expr::Lam(_, body, _) => go(body),
        Expr::Var(_, _) | Expr::Int(_, _) | Expr::Str(_, _) | Expr::Con(_, _) => {}
    }
}

/// Verifica que o corpo de um `bound` não devolve um endpoint criado lá dentro.
fn check_bound(body: &Expr, diags: &mut Diagnostics) {
    let mut eps: HashSet<String> = HashSet::new();
    let tail = peel_bound_spine(body, &mut eps, diags);
    if let Some(sp) = tail_endpoint(tail, &eps) {
        diags.push(
            Diagnostic::error("AX0302", "um endpoint escapa do nursery `bound`")
                .label(
                    sp.0,
                    sp.1,
                    "devolvido daqui — o endpoint sobreviveria ao nursery",
                )
                .with_help(
                    "os endpoints nascem confinados ao `bound` para o grafo de \
                 comunicação ser uma árvore (deadlock-freedom, §9); consome-os \
                 dentro do bloco (`close`/`send`/`recv`), não os devolvas.",
                ),
        );
    }
}

/// Percorre a espinha de `do`/`let`, registando as variáveis ligadas a endpoints
/// criados no nursery; devolve a expressão-cauda (o valor de retorno).
fn peel_bound_spine<'a>(
    e: &'a Expr,
    eps: &mut HashSet<String>,
    diags: &mut Diagnostics,
) -> &'a Expr {
    let mut cur = e;
    loop {
        match cur {
            Expr::Let(binds, body, _) => {
                for b in binds {
                    if let Some(rhs) = simple_bind_rhs(b) {
                        check_spawn_capture(rhs, eps, diags);
                        if let Prod::One | Prod::Both | Prod::Snd = producer(rhs, eps) {
                            eps.insert(b.name.clone());
                        }
                    }
                }
                cur = body;
            }
            Expr::Case(scrut, arms, _) if arms.len() == 1 => {
                check_spawn_capture(scrut, eps, diags);
                bind_prod(&arms[0].0, producer(scrut, eps), eps);
                cur = &arms[0].1;
            }
            _ => return cur,
        }
    }
}

/// §9: a closure passada a `spawn` não pode CAPTURAR um endpoint do exterior — só
/// pode usar o seu parâmetro (a ponta do canal do spawn). Se capturasse, dois
/// filhos podiam partilhar canais e formar um ciclo na topologia → deadlock.
/// Garante que cada `spawn` só cria uma aresta pai↔filho (árvore). **AX0305**.
fn check_spawn_capture(e: &Expr, eps: &HashSet<String>, diags: &mut Diagnostics) {
    let (head, args) = app_spine(e);
    if head != Some("spawn") {
        return;
    }
    if let Some(Expr::Lam(pats, body, sp)) = args.first() {
        let mut bound = HashSet::new();
        for p in pats {
            pat_names(p, &mut bound);
        }
        if let Some(ep) = captured_endpoint(body, &bound, eps) {
            diags.push(
                Diagnostic::error(
                    "AX0305",
                    format!(
                        "a closure de `spawn` captura o endpoint '{ep}' do exterior — \
                         quebraria a topologia em árvore do nursery"
                    ),
                )
                .label(sp.0, sp.1, "captura de endpoint proibida")
                .with_help(
                    "um filho spawnado só comunica com o pai pelo seu endpoint-parâmetro \
                     (aresta pai↔filho); não capture canais do exterior (§9, deadlock-freedom).",
                ),
            );
        }
    }
}

/// Nomes ligados por um padrão (var, construtor, tuplo).
fn pat_names(p: &Pat, out: &mut HashSet<String>) {
    match p {
        Pat::Var(n, _) => {
            out.insert(n.clone());
        }
        Pat::Con(_, subs, _) | Pat::Tuple(subs, _) => subs.iter().for_each(|s| pat_names(s, out)),
        _ => {}
    }
}

/// O primeiro endpoint (de `eps`) usado livre em `e` (não ligado localmente).
fn captured_endpoint(e: &Expr, bound: &HashSet<String>, eps: &HashSet<String>) -> Option<String> {
    match e {
        Expr::Var(n, _) => (eps.contains(n) && !bound.contains(n)).then(|| n.clone()),
        Expr::App(f, x, _) | Expr::BinOp(_, f, x, _) => {
            captured_endpoint(f, bound, eps).or_else(|| captured_endpoint(x, bound, eps))
        }
        Expr::If(c, t, el, _) => captured_endpoint(c, bound, eps)
            .or_else(|| captured_endpoint(t, bound, eps))
            .or_else(|| captured_endpoint(el, bound, eps)),
        Expr::Lam(pats, body, _) => {
            let mut b = bound.clone();
            pats.iter().for_each(|p| pat_names(p, &mut b));
            captured_endpoint(body, &b, eps)
        }
        Expr::Let(binds, body, _) => {
            let mut b = bound.clone();
            for g in binds {
                b.insert(g.name.clone());
            }
            binds
                .iter()
                .flat_map(|g| &g.clauses)
                .find_map(|c| match &c.body {
                    Body::Plain(rhs) => captured_endpoint(rhs, &b, eps),
                    _ => None,
                })
                .or_else(|| captured_endpoint(body, &b, eps))
        }
        Expr::Case(s, arms, _) => captured_endpoint(s, bound, eps).or_else(|| {
            arms.iter().find_map(|(pat, body)| {
                let mut b = bound.clone();
                pat_names(pat, &mut b);
                captured_endpoint(body, &b, eps)
            })
        }),
        Expr::Tuple(es, _) => es.iter().find_map(|x| captured_endpoint(x, bound, eps)),
        Expr::RecordCon(_, fs, _) | Expr::RecordUpd(_, fs, _) => fs
            .iter()
            .find_map(|(_, x)| captured_endpoint(x, bound, eps)),
        _ => None,
    }
}

fn producer(e: &Expr, eps: &HashSet<String>) -> Prod {
    // o nome-builtin primeiro (`newChannel` é um `Var` de 0 args), depois a
    // variável-endpoint já registada.
    match app_spine(e).0 {
        Some("newChannel") => Prod::Both,
        Some("recv") => Prod::Snd,
        Some("send") | Some("spawn") => Prod::One,
        Some(n) if eps.contains(n) => Prod::One,
        _ => Prod::No,
    }
}

fn bind_prod(pat: &Pat, prod: Prod, eps: &mut HashSet<String>) {
    match (prod, pat) {
        (Prod::One, Pat::Var(n, _)) => {
            eps.insert(n.clone());
        }
        (Prod::Both, Pat::Tuple(ps, _)) => {
            for p in ps {
                if let Pat::Var(n, _) = p {
                    eps.insert(n.clone());
                }
            }
        }
        (Prod::Snd, Pat::Tuple(ps, _)) => {
            if let Some(Pat::Var(n, _)) = ps.last() {
                eps.insert(n.clone());
            }
        }
        _ => {}
    }
}

/// Se a cauda devolve um endpoint (var registada, ou uma operação que produz um
/// endpoint), devolve o span do escape.
fn tail_endpoint(e: &Expr, eps: &HashSet<String>) -> Option<Span> {
    match e {
        Expr::Var(n, _) if eps.contains(n) => Some(e.span()),
        Expr::Tuple(es, _) => es.iter().find_map(|x| tail_endpoint(x, eps)),
        _ => match app_spine(e).0 {
            Some("newChannel") | Some("spawn") | Some("send") | Some("recv") => Some(e.span()),
            _ => None,
        },
    }
}

// --- fidelidade de protocolo de sessão (§6, cálculo ASC) ---
//
// A linearidade dos endpoints (`Ep` é must-use %1) já é garantida pelo passe de
// linearidade. Este passe verifica o que o HM não exprime: que cada operação de
// canal segue o tipo de sessão do endpoint (send num `Send`, recv num `Recv`,
// close num `End`) e que o protocolo é levado até ao fim. Banda AX03xx.
// v1: fragmento send/recv/close sobre a espinha linear de `do`/`let`; escolha
// (⊕/&), `bound`/`spawn` e ramos (`if`/`case` multi-braço) ficam para incrementos
// seguintes (aí o tracking pára, conservador, sem falsos positivos).

#[derive(Clone, Debug, PartialEq)]
enum SessTy {
    End,
    Send(Box<SessTy>),
    Recv(Box<SessTy>),
    Select(Vec<(String, SessTy)>), // ⊕ — escolhe um rótulo (lado interno)
    Offer(Vec<(String, SessTy)>),  // & — oferece todos os rótulos (lado externo)
}

/// Decompõe um tipo na sua cabeça e argumentos (a espinha de `App`).
fn ty_spine(t: &Type) -> (Option<&str>, Vec<&Type>) {
    let mut args = Vec::new();
    let mut cur = t;
    loop {
        match cur {
            Type::App(f, a) => {
                args.push(a.as_ref());
                cur = f;
            }
            Type::Con(n) => {
                args.reverse();
                return (Some(n.as_str()), args);
            }
            _ => return (None, vec![]),
        }
    }
}

/// Lê um tipo de sessão a partir de um `Type` (payload ignorado no v1).
fn parse_sess(t: &Type) -> Option<SessTy> {
    let (h, args) = ty_spine(t);
    match (h?, args.len()) {
        ("End", 0) => Some(SessTy::End),
        ("Send", 2) => Some(SessTy::Send(Box::new(parse_sess(args[1])?))),
        ("Recv", 2) => Some(SessTy::Recv(Box::new(parse_sess(args[1])?))),
        // `Select (L1 S1) (L2 S2) …` / `Offer …` — cada ramo é `Rótulo Cont`
        // (rótulo = ConId; um ramo sem continuação = `End`).
        ("Select", n) if n >= 1 => Some(SessTy::Select(parse_branches(&args)?)),
        ("Offer", n) if n >= 1 => Some(SessTy::Offer(parse_branches(&args)?)),
        _ => None,
    }
}

/// Lê os ramos de um `Select`/`Offer`: cada arg é `Label Cont` (ou só `Label`).
fn parse_branches(args: &[&Type]) -> Option<Vec<(String, SessTy)>> {
    let mut out = Vec::new();
    for a in args {
        let (h, bargs) = ty_spine(a);
        let label = h?.to_string();
        let cont = if bargs.is_empty() {
            SessTy::End
        } else {
            parse_sess(bargs[0])?
        };
        out.push((label, cont));
    }
    Some(out)
}

/// Se `t` é um endpoint `Ep S` (ou `Channel`/`Chan`/`Endpoint`), devolve a sessão.
fn endpoint_session(t: &Type) -> Option<SessTy> {
    let (h, args) = ty_spine(t);
    match h? {
        "Ep" | "Channel" | "Chan" | "Endpoint" if args.len() == 1 => parse_sess(args[0]),
        _ => None,
    }
}

/// A cabeça-nome e os argumentos de uma aplicação `f a b …`.
fn app_spine(e: &Expr) -> (Option<&str>, Vec<&Expr>) {
    let mut args = Vec::new();
    let mut cur = e;
    while let Expr::App(f, a, _) = cur {
        args.push(a.as_ref());
        cur = f;
    }
    args.reverse();
    match cur {
        Expr::Var(n, _) | Expr::Con(n, _) => (Some(n.as_str()), args),
        _ => (None, args),
    }
}

/// Resultado de uma operação de canal reconhecida.
enum OpResult {
    Advance(SessTy), // `send` → o endpoint avançado
    Recv(SessTy),    // `recv` → (valor, endpoint avançado)
    Closed,          // `close` → consumido
}

fn check_sessions(module: &Module, diags: &mut Diagnostics) {
    for f in &module.funcs {
        let Some(sig) = &f.sig else { continue };
        let ptys = sig.param_types();
        for c in &f.clauses {
            // ambiente inicial: parâmetros que são endpoints
            let mut env: HashMap<String, SessTy> = HashMap::new();
            for (i, p) in c.pats.iter().enumerate() {
                if let (Pat::Var(n, _), Some(t)) = (p, ptys.get(i)) {
                    if let Some(s) = endpoint_session(t) {
                        // T5: toda a escolha externa (`Offer`/`&`) tem de incluir o
                        // ramo `Closed` — para o cancelamento ser sempre tratável.
                        check_closed_branches(&s, n, f.span, diags);
                        env.insert(n.clone(), s);
                    }
                }
            }
            if env.is_empty() {
                continue; // não há canais → nada a verificar
            }
            if let Body::Plain(e) = &c.body {
                let mut tracked = true;
                walk_sess(e, &mut env, &mut tracked, f.span, diags);
                // completude (T-progresso): se seguimos toda a espinha, nenhum
                // endpoint pode ficar por levar até `close`.
                if tracked {
                    // um endpoint fechado foi removido do env; o que sobra não foi
                    // levado até `close` → protocolo incompleto.
                    for n in env.keys() {
                        diags.push(
                            Diagnostic::error(
                                "AX0301",
                                format!(
                                    "o endpoint '{n}' não completou o seu protocolo de sessão \
                                     (falta consumi-lo até `close`)"
                                ),
                            )
                            .label(f.span.0, f.span.1, "protocolo incompleto aqui")
                            .with_help(
                                "leve o endpoint até `close`, ou consuma-o com `offer`/`cancel`.",
                            ),
                        );
                    }
                }
            }
        }
    }
}

/// Percorre a espinha linear (`do` desugarado = `case` de 1 braço, e `let`),
/// avançando o estado de sessão de cada endpoint. `tracked` fica `false` se
/// encontrar ramificação não-sessão (não rastreável no v1) — aí não se reporta
/// incompletude. `span` = o local a apontar nas incompletudes por-ramo.
fn walk_sess(
    e: &Expr,
    env: &mut HashMap<String, SessTy>,
    tracked: &mut bool,
    span: Span,
    diags: &mut Diagnostics,
) {
    // `case offer c of { L1 p1 -> N1 ; … }` (&): a escolha externa. Verifica a
    // exaustividade (todos os ramos do `Offer` tratados) e segue cada ramo com a
    // sua continuação. É o único `case` multi-braço que se rastreia.
    if let Expr::Case(scrut, arms, _) = e {
        if let Some(chan) = offer_chan(scrut) {
            check_offer_case(&chan, arms, env, span, diags);
            return;
        }
    }
    match e {
        Expr::Case(scrut, arms, _) if arms.len() == 1 => {
            if let Some(r) = classify_op(scrut, env, diags) {
                bind_result(&arms[0].0, r, env);
            }
            walk_sess(&arms[0].1, env, tracked, span, diags);
        }
        Expr::Let(funcs, body, _) => {
            for g in funcs {
                if let Some(cl) = g.clauses.first() {
                    if cl.pats.is_empty() {
                        if let Body::Plain(rhs) = &cl.body {
                            if let Some(r) = classify_op(rhs, env, diags) {
                                bind_named(&g.name, r, env);
                            }
                        }
                    }
                }
            }
            walk_sess(body, env, tracked, span, diags);
        }
        // ramificação real: não rastreável no v1 → pára (conservador, sem falsos+)
        Expr::If(..) | Expr::Case(..) => *tracked = false,
        // folha: pode ser a última operação (`close c`)
        other => {
            classify_op(other, env, diags);
        }
    }
}

/// Se `scrut` é `offer c`, devolve o nome do endpoint `c`.
fn offer_chan(scrut: &Expr) -> Option<String> {
    let (head, args) = app_spine(scrut);
    if head == Some("offer") {
        if let Some(Expr::Var(n, _)) = args.first() {
            return Some(n.clone());
        }
    }
    None
}

/// Verifica a escolha externa `case offer c of {ramos}`: exaustividade dos ramos
/// do `Offer` (AX0304) + fidelidade/completude de cada ramo (com a continuação
/// desse rótulo ligada ao endpoint).
fn check_offer_case(
    chan: &str,
    arms: &[(Pat, Expr)],
    env: &mut HashMap<String, SessTy>,
    span: Span,
    diags: &mut Diagnostics,
) {
    let branches = match env.remove(chan) {
        Some(SessTy::Offer(bs)) => bs,
        Some(other) => {
            session_mismatch(diags, span, chan, "offer", &other);
            return;
        }
        None => return,
    };
    // rótulos tratados pelos ramos (e se há um catch-all `_`/var)
    let mut has_catchall = false;
    for (pat, _) in arms {
        if arm_label(pat).is_none() {
            has_catchall = true;
        }
    }
    // exaustividade: todo o ramo do `Offer` tem de ter um braço (ou um catch-all)
    if !has_catchall {
        let handled: HashSet<&str> = arms.iter().filter_map(|(p, _)| arm_label(p)).collect();
        for (label, _) in &branches {
            if !handled.contains(label.as_str()) {
                diags.push(
                    Diagnostic::error(
                        "AX0304",
                        format!(
                            "o `case offer {chan}` não trata o ramo '{label}' da escolha \
                             externa (a sessão oferece-o)"
                        ),
                    )
                    .label(span.0, span.1, "ramo de sessão não tratado")
                    .with_help(
                        "acrescenta um braço para cada rótulo do `Offer` (incl. `Closed`, \
                         o cancelamento — §7/T5).",
                    ),
                );
            }
        }
    }
    // segue cada braço com o endpoint na continuação do seu rótulo
    for (pat, body) in arms {
        let mut arm_env = env.clone();
        if let (Some(label), Some(binder)) = (arm_label(pat), arm_binder(pat)) {
            if let Some((_, cont)) = branches.iter().find(|(l, _)| l == label) {
                arm_env.insert(binder.to_string(), cont.clone());
            }
        }
        let mut t = true;
        walk_sess(body, &mut arm_env, &mut t, span, diags);
        if t {
            for n in arm_env.keys() {
                diags.push(
                    Diagnostic::error(
                        "AX0301",
                        format!(
                            "o endpoint '{n}' não completou o seu protocolo de sessão \
                             (falta consumi-lo até `close`)"
                        ),
                    )
                    .label(span.0, span.1, "protocolo incompleto neste braço"),
                );
            }
        }
    }
}

/// O rótulo (construtor) tratado por um braço, ou `None` se for catch-all (`_`/var).
fn arm_label(pat: &Pat) -> Option<&str> {
    match pat {
        Pat::Con(name, _, _) => Some(name),
        _ => None,
    }
}

/// O endpoint ligado por um braço `L c2` (a variável do sub-padrão).
fn arm_binder(pat: &Pat) -> Option<&str> {
    match pat {
        Pat::Con(_, subs, _) => match subs.first() {
            Some(Pat::Var(n, _)) => Some(n),
            _ => None,
        },
        _ => None,
    }
}

/// Reconhece e valida uma operação de canal; avança/consome o endpoint no `env`.
/// Emite AX0300 se a operação não seguir o tipo de sessão.
fn classify_op(
    e: &Expr,
    env: &mut HashMap<String, SessTy>,
    diags: &mut Diagnostics,
) -> Option<OpResult> {
    let (head, args) = app_spine(e);
    let head = head?;
    let sp = e.span();
    // `select L c` (⊕): escolhe o rótulo L; o canal é o 2.º argumento.
    if head == "select" && args.len() >= 2 {
        let label = match args[0] {
            Expr::Con(l, _) | Expr::Var(l, _) => l.clone(),
            _ => return None,
        };
        let chan = match args[1] {
            Expr::Var(n, _) => n.clone(),
            _ => return None,
        };
        return match env.remove(&chan) {
            Some(SessTy::Select(branches)) => {
                match branches.into_iter().find(|(bl, _)| *bl == label) {
                    Some((_, cont)) => Some(OpResult::Advance(cont)),
                    None => {
                        diags.push(
                            Diagnostic::error(
                                "AX0300",
                                format!(
                                    "`select {label}` no endpoint '{chan}': o protocolo \
                                     `Select` não oferece o rótulo '{label}'"
                                ),
                            )
                            .label(
                                sp.0,
                                sp.1,
                                "rótulo de escolha inválido",
                            ),
                        );
                        None
                    }
                }
            }
            Some(other) => {
                session_mismatch(diags, sp, &chan, "select", &other);
                None
            }
            None => None,
        };
    }
    let chan = match args.first() {
        Some(Expr::Var(n, _)) => n.clone(),
        _ => return None,
    };
    match head {
        "send" if args.len() >= 2 => match env.remove(&chan) {
            Some(SessTy::Send(s)) => Some(OpResult::Advance(*s)),
            Some(other) => {
                session_mismatch(diags, sp, &chan, "send", &other);
                None
            }
            None => None,
        },
        "recv" => match env.remove(&chan) {
            Some(SessTy::Recv(s)) => Some(OpResult::Recv(*s)),
            Some(other) => {
                session_mismatch(diags, sp, &chan, "recv", &other);
                None
            }
            None => None,
        },
        "close" => match env.remove(&chan) {
            Some(SessTy::End) => Some(OpResult::Closed),
            Some(other) => {
                session_mismatch(diags, sp, &chan, "close", &other);
                None
            }
            None => None,
        },
        // `offer c` (&): recebe a escolha e consome o endpoint. A exaustividade dos
        // ramos (incl. `Closed`) é verificada no tipo (`check_closed_branches`).
        "offer" => match env.remove(&chan) {
            Some(SessTy::Offer(_)) => Some(OpResult::Closed),
            Some(other) => {
                session_mismatch(diags, sp, &chan, "offer", &other);
                None
            }
            None => None,
        },
        // `cancel c` (§7): descarta o endpoint em QUALQUER estado (pode-se sempre
        // cancelar) — consome-o.
        "cancel" => {
            env.remove(&chan);
            Some(OpResult::Closed)
        }
        _ => None,
    }
}

/// T5 (§7): verifica recursivamente que toda a escolha externa (`Offer`/`&`) na
/// sessão inclui o ramo `Closed` — assim o cancelamento (o par em pânico envia
/// `Closed`) é sempre um ramo tratável do protocolo, nunca ignorado em silêncio.
fn check_closed_branches(s: &SessTy, chan: &str, sp: Span, diags: &mut Diagnostics) {
    match s {
        SessTy::End => {}
        SessTy::Send(k) | SessTy::Recv(k) => check_closed_branches(k, chan, sp, diags),
        SessTy::Select(bs) => {
            for (_, k) in bs {
                check_closed_branches(k, chan, sp, diags);
            }
        }
        SessTy::Offer(bs) => {
            if !bs.iter().any(|(l, _)| l == "Closed") {
                diags.push(
                    Diagnostic::error(
                        "AX0303",
                        format!(
                            "a escolha externa (`Offer`) do endpoint '{chan}' não tem o ramo \
                             `Closed` — o cancelamento de um par em pânico ficaria por tratar (§7)"
                        ),
                    )
                    .label(sp.0, sp.1, "falta o ramo `Closed`")
                    .with_help(
                        "acrescenta um ramo `Closed` ao `Offer` (é o rótulo que o \
                         Linear Unwinding envia ao cancelar — T5).",
                    ),
                );
            }
            for (_, k) in bs {
                check_closed_branches(k, chan, sp, diags);
            }
        }
    }
}

fn session_mismatch(diags: &mut Diagnostics, sp: Span, chan: &str, op: &str, got: &SessTy) {
    let expect = match op {
        "send" => "um `Send`",
        "recv" => "um `Recv`",
        "select" => "um `Select`",
        "offer" => "um `Offer`",
        _ => "um `End`",
    };
    let got = match got {
        SessTy::End => "está em `End`",
        SessTy::Send(_) => "está em `Send`",
        SessTy::Recv(_) => "está em `Recv`",
        SessTy::Select(_) => "está em `Select`",
        SessTy::Offer(_) => "está em `Offer`",
    };
    diags.push(
        Diagnostic::error(
            "AX0300",
            format!(
                "`{op}` no endpoint '{chan}' não segue o protocolo: esperava {expect}, mas {got}"
            ),
        )
        .label(sp.0, sp.1, "operação de sessão inválida")
        .with_help(
            "a operação tem de seguir o tipo de sessão do endpoint: `send` num `Send`, \
             `recv` num `Recv`, `close` num `End`, e o rótulo de `select` tem de pertencer \
             ao `Select`.",
        ),
    );
}

fn bind_result(pat: &Pat, r: OpResult, env: &mut HashMap<String, SessTy>) {
    match r {
        OpResult::Advance(s) => {
            if let Pat::Var(n, _) = pat {
                env.insert(n.clone(), s);
            }
        }
        OpResult::Recv(s) => {
            // `(_valor, endpoint) <- recv c` — a última var do tuplo é o endpoint
            if let Pat::Tuple(ps, _) = pat {
                if let Some(Pat::Var(n, _)) = ps.last() {
                    env.insert(n.clone(), s);
                }
            } else if let Pat::Var(n, _) = pat {
                env.insert(n.clone(), s);
            }
        }
        OpResult::Closed => {}
    }
}

fn bind_named(name: &str, r: OpResult, env: &mut HashMap<String, SessTy>) {
    match r {
        OpResult::Advance(s) | OpResult::Recv(s) => {
            env.insert(name.to_string(), s);
        }
        OpResult::Closed => {}
    }
}

/// Um tipo é *must-use* se a sua cabeça é um primitivo sem `Drop`, ou um tipo
/// `data` cuja must-use-ness foi propagada estruturalmente (ver `build_ctx`).
fn is_must_use(ty: &Type, must_use_types: &HashSet<String>) -> bool {
    matches!(ty.head_con(), Some(h) if MUST_USE_PRIMS.contains(&h) || must_use_types.contains(h))
}

/// Calcula, por ponto-fixo, o conjunto de tipos `data` que são *must-use*:
/// um `data` é must-use se algum campo de algum construtor for must-use (um
/// primitivo sem `Drop`, ou outro `data` já marcado). `Drop` propaga assim
/// estruturalmente (§2).
fn build_must_use_types(module: &Module) -> HashSet<String> {
    let mut set: HashSet<String> = HashSet::new();
    loop {
        let mut changed = false;
        for d in &module.datas {
            if set.contains(&d.name) {
                continue;
            }
            let any_mu = d.cons.iter().any(|c| {
                c.fields.iter().any(|f| {
                    matches!(f.ty.head_con(), Some(h) if MUST_USE_PRIMS.contains(&h) || set.contains(h))
                })
            });
            if any_mu {
                set.insert(d.name.clone());
                changed = true;
            }
        }
        if !changed {
            break;
        }
    }
    set
}

fn builtins() -> HashSet<String> {
    [
        "putStrLn",
        "putStr",
        "show",
        "otherwise",
        "True",
        "False",
        // arenas (§3)
        "withArena",
        "withSubArena",
        "allocateCell",
        "promote",
        "arena_mark",
        "arena_release",
        // Buffer U8 linear (§4/§5)
        "newBuffer",
        "withBuffer",
        "bufIota",
        "xorInPlace",
        "sumBytes",
        "free",
        "foldBytes",
        "imperative",
        // permissões fraccionárias (§2)
        "split",
        "join",
        // canais / session types (§6)
        "send",
        "recv",
        "close",
        "newChannel",
        "select",
        "offer",
        "cancel",
        // nursery de concorrência estruturada (§9)
        "bound",
        "spawn",
    ]
    .iter()
    .map(|s| s.to_string())
    .collect()
}

/// Estado de um recurso linear após a análise de uma cláusula/âmbito.
struct ResUse {
    consumes: usize,
    borrows: usize,
    uam: Option<(Span, Span)>, // uso-após-move (uso, move)
    death: Option<Span>,       // última ocorrência (ponto de morte)
}

fn check_func(
    f: &Func,
    globals: &HashSet<String>,
    ctx: &Ctx,
    diags: &mut Diagnostics,
    out: &mut Analysis,
) {
    let mults = f.sig.as_ref().map(|t| t.param_mults()).unwrap_or_default();
    let ptypes = f.sig.as_ref().map(|t| t.param_types()).unwrap_or_default();
    for clause in &f.clauses {
        // --- resolução de nomes ---
        let mut scope: HashSet<String> = HashSet::new();
        for p in &clause.pats {
            collect_pat_vars(p, &mut scope);
        }
        for w in &clause.wher {
            scope.insert(w.name.clone());
        }
        resolve_clause(clause, &scope, globals, diags);

        // --- linearidade fina + Auto-Drop: parâmetros %1 ---
        let mut lin: HashMap<String, Lin> = HashMap::new();
        for (i, p) in clause.pats.iter().enumerate() {
            if mults.get(i).copied() != Some(Mult::One) {
                continue;
            }
            if let (Pat::Var(name, span), Some(ty)) = (p, ptypes.get(i)) {
                let class = class_of_type(ty, &ctx.must_use_types);
                let (c, b) = analyze_clause(clause, name, ctx);
                let use_ = ResUse {
                    consumes: c,
                    borrows: b,
                    uam: use_after_move(clause, name, ctx),
                    death: last_occurrence_clause(clause, name),
                };
                report_resource(name, &class, *span, &use_, &f.name, diags, out);
                lin.insert(name.clone(), class);
            }
        }

        // --- escape de sub-arena (§3) + reset NLL + permissões %0.5 ---
        if let Body::Plain(body) = &clause.body {
            check_arena_escapes(body, &f.name, diags, &mut out.arenas);
            check_arena_marks(body, diags);
            check_fractional(body, ctx, diags);
        }

        // --- linearidade + Auto-Drop de valores 'let' lineares + in-place (§2) ---
        if let Body::Plain(body) = &clause.body {
            let mut lets = Vec::new();
            scan_lets(body, &lin, ctx, &mut lets, &mut out.inplace, &f.name);
            for (name, class, sp_scope, bind_span) in lets {
                let (c, b) = analyze(sp_scope, &name, Mode::Consume, ctx);
                let mut death = None;
                collect_last(sp_scope, &name, &mut death);
                let use_ = ResUse {
                    consumes: c,
                    borrows: b,
                    uam: walk(sp_scope, &name, Mode::Consume, ctx, MoveState::default()).error,
                    death,
                };
                report_resource(&name, &class, bind_span, &use_, &f.name, diags, out);
            }
        }
    }
}

/// Emite o diagnóstico ou regista o drop, aplicando a regra da linearidade a um
/// recurso linear (parâmetro ou valor `let`), dado o resultado da análise.
fn report_resource(
    name: &str,
    class: &Lin,
    label: Span,
    u: &ResUse,
    func: &str,
    diags: &mut Diagnostics,
    out: &mut Analysis,
) {
    if u.consumes > 1 {
        diags.push(
            Diagnostic::error(
                "AX0001",
                format!(
                    "recurso linear '{name}' consumido {} vezes (contração proibida)",
                    u.consumes
                ),
            )
            .label(
                label.0,
                label.1,
                format!("'{name}' é %1: consumível uma só vez"),
            )
            .with_help(
                "ler (emprestar) um %1 é livre e ilimitado; mover a posse (consumir) \
                 só pode acontecer uma vez — para o partilhar por posse, use 'split' \
                 em duas metades %0.5 (§2).",
            ),
        );
    } else if let Some((mv, use_sp)) = u.uam {
        diags.push(
            Diagnostic::error(
                "AX0004",
                format!("uso de '{name}' após a posse ter sido movida"),
            )
            .label(use_sp.0, use_sp.1, format!("'{name}' usado aqui…"))
            .label(mv.0, mv.1, "…mas a posse já tinha sido movida aqui")
            .with_help(
                "depois de mover um %1 (consumir), não se pode voltar a lê-lo nem \
                     a consumi-lo — a posse já saiu deste âmbito (§2).",
            ),
        );
    } else if u.consumes == 0 && class.must_use {
        diags.push(
            Diagnostic::error(
                "AX0002",
                format!("recurso must-use '{name}' largado sem ser consumido"),
            )
            .label(
                label.0,
                label.1,
                format!("'{name}' : {} %1 (sem Drop)", class.ty),
            )
            .with_help(
                "endpoints, Token e handles são must-use (não têm Drop); consuma-o \
                     ou devolva-o (§2).",
            ),
        );
    } else if u.consumes == 0 {
        // droppable, nunca consumido: Auto-Drop no ponto de morte (última
        // leitura, ou a entrada se nunca lido).
        let (death, reason) = match u.death {
            Some(s) if u.borrows > 0 => (s, "morre após a última leitura"),
            _ => (label, "morre à entrada (nunca usado)"),
        };
        out.drops.push(DropPoint {
            func: func.to_string(),
            var: name.to_string(),
            ty: class.ty.clone(),
            span: death,
            reason,
        });
    }
}

fn collect_pat_vars(p: &Pat, out: &mut HashSet<String>) {
    match p {
        Pat::Var(n, _) => {
            out.insert(n.clone());
        }
        Pat::Con(_, args, _) | Pat::Tuple(args, _) => {
            for a in args {
                collect_pat_vars(a, out);
            }
        }
        Pat::Wild(_) | Pat::Int(_, _) => {}
    }
}

fn resolve_clause(
    clause: &Clause,
    scope: &HashSet<String>,
    globals: &HashSet<String>,
    diags: &mut Diagnostics,
) {
    match &clause.body {
        Body::Plain(e) => resolve_expr(e, scope, globals, diags),
        Body::Guarded(arms) => {
            for (g, r) in arms {
                resolve_expr(g, scope, globals, diags);
                resolve_expr(r, scope, globals, diags);
            }
        }
    }
    for w in &clause.wher {
        for c in &w.clauses {
            let mut s = scope.clone();
            for p in &c.pats {
                collect_pat_vars(p, &mut s);
            }
            resolve_clause(c, &s, globals, diags);
        }
    }
}

fn resolve_expr(
    e: &Expr,
    scope: &HashSet<String>,
    globals: &HashSet<String>,
    diags: &mut Diagnostics,
) {
    match e {
        Expr::Var(n, sp) => {
            if !scope.contains(n) && !globals.contains(n) {
                diags.push(
                    Diagnostic::error("AX0101", format!("nome não encontrado: '{n}'"))
                        .label(sp.0, sp.1, "não está em âmbito")
                        .with_help(
                            "verifique a ortografia, ou se é um parâmetro/local em âmbito, \
                             ou uma função de topo/import em falta.",
                        ),
                );
            }
        }
        Expr::Int(_, _) | Expr::Str(_, _) | Expr::Con(_, _) => {}
        Expr::App(f, x, _) => {
            resolve_expr(f, scope, globals, diags);
            resolve_expr(x, scope, globals, diags);
        }
        Expr::BinOp(_, l, r, _) => {
            resolve_expr(l, scope, globals, diags);
            resolve_expr(r, scope, globals, diags);
        }
        Expr::If(c, t, el, _) => {
            resolve_expr(c, scope, globals, diags);
            resolve_expr(t, scope, globals, diags);
            resolve_expr(el, scope, globals, diags);
        }
        Expr::Tuple(es, _) => {
            for e in es {
                resolve_expr(e, scope, globals, diags);
            }
        }
        Expr::Let(binds, body, _) => {
            let mut s = scope.clone();
            for b in binds {
                s.insert(b.name.clone());
            }
            for b in binds {
                for c in &b.clauses {
                    let mut cs = s.clone();
                    for p in &c.pats {
                        collect_pat_vars(p, &mut cs);
                    }
                    resolve_clause(c, &cs, globals, diags);
                }
            }
            resolve_expr(body, &s, globals, diags);
        }
        Expr::Case(scrut, arms, _) => {
            resolve_expr(scrut, scope, globals, diags);
            for (pat, body) in arms {
                let mut s = scope.clone();
                collect_pat_vars(pat, &mut s);
                resolve_expr(body, &s, globals, diags);
            }
        }
        Expr::RecordCon(_, fields, _) => {
            for (_, e) in fields {
                resolve_expr(e, scope, globals, diags);
            }
        }
        Expr::RecordUpd(base, fields, _) => {
            resolve_expr(base, scope, globals, diags);
            for (_, e) in fields {
                resolve_expr(e, scope, globals, diags);
            }
        }
        Expr::Lam(pats, body, _) => {
            let mut s = scope.clone();
            for p in pats {
                collect_pat_vars(p, &mut s);
            }
            resolve_expr(body, &s, globals, diags);
        }
    }
}

// --- análise fina de liveness: empréstimo vs consumo (§2) ---
//
// Um recurso %1 pode ser LIDO (emprestado, sem consumir — a Elisão de
// Empréstimos) muitas vezes, mas CONSUMIDO (posse a fluir para fora) no máximo
// uma. A posição de cada ocorrência decide: argumento de um parâmetro %1,
// campo %1, ou valor de retorno ⇒ consumo; tudo o resto ⇒ empréstimo.
//
// Limitação assumida deste corte: não se verifica a ORDEM (um empréstimo depois
// de um consumo seria uso-após-move; fica para o passo seguinte).

#[derive(Clone, Copy, PartialEq)]
enum Mode {
    Consume,
    Borrow,
}

/// Multiplicidades de parâmetros/campos (funções, construtores) + mult por campo
/// + o conjunto de tipos `data` que são must-use (propagação estrutural).
struct Ctx {
    /// função/construtor → multiplicidades dos parâmetros/campos (por ordem)
    consumers: HashMap<String, Vec<Mult>>,
    /// nome de campo → multiplicidade declarada (para registos)
    field_mults: HashMap<String, Mult>,
    /// tipos `data` must-use (por conterem, recursivamente, um campo sem `Drop`)
    must_use_types: HashSet<String>,
}

fn build_ctx(module: &Module) -> Ctx {
    let mut consumers = HashMap::new();
    let mut field_mults = HashMap::new();
    for f in &module.funcs {
        if let Some(sig) = &f.sig {
            consumers.insert(f.name.clone(), sig.param_mults());
        }
    }
    for d in &module.datas {
        for c in &d.cons {
            consumers.insert(c.name.clone(), c.fields.iter().map(|f| f.mult).collect());
            for f in &c.fields {
                if !f.name.is_empty() {
                    consumers.insert(f.name.clone(), vec![Mult::Many]); // selector: empresta
                    field_mults.insert(f.name.clone(), f.mult);
                }
            }
        }
    }
    // `split` consome o %1 que divide (para o repartir em duas metades %0.5).
    consumers.insert("split".to_string(), vec![Mult::One]);
    // Buffer U8 linear (§4/§5): as ops in-place (bufIota/xorInPlace) e o `free`
    // consomem o Buffer %1 (xorInPlace devolve um novo %1 — o fio linear);
    // sumBytes/withBuffer só emprestam.
    consumers.insert("bufIota".to_string(), vec![Mult::One]);
    consumers.insert("xorInPlace".to_string(), vec![Mult::One, Mult::Many]);
    consumers.insert("free".to_string(), vec![Mult::One]);
    consumers.insert("sumBytes".to_string(), vec![Mult::Many]);
    consumers.insert("newBuffer".to_string(), vec![Mult::Many]);
    consumers.insert("withBuffer".to_string(), vec![Mult::Many, Mult::Many]);
    // foldBytes (f init buf) empresta o buffer (lê sem consumir) — Listagem 2.2.
    consumers.insert(
        "foldBytes".to_string(),
        vec![Mult::Many, Mult::Many, Mult::Many],
    );
    // canais / session types (§6): send/recv/close CONSOMEM o endpoint %1 (a posse
    // move-se; o resultado é o endpoint avançado — o fio linear da sessão). O
    // payload de `send` é emprestado. A fidelidade do protocolo é verificada à
    // parte (`check_sessions`).
    consumers.insert("send".to_string(), vec![Mult::One, Mult::Many]);
    consumers.insert("recv".to_string(), vec![Mult::One]);
    consumers.insert("close".to_string(), vec![Mult::One]);
    // escolha: `select L c` consome o endpoint (arg 1); `offer c` consome-o.
    consumers.insert("select".to_string(), vec![Mult::Many, Mult::One]);
    consumers.insert("offer".to_string(), vec![Mult::One]);
    consumers.insert("cancel".to_string(), vec![Mult::One]);
    // nursery (§9): o corpo do `bound` é emprestado; `spawn` recebe a closure-filho.
    consumers.insert("bound".to_string(), vec![Mult::Many]);
    consumers.insert("spawn".to_string(), vec![Mult::Many]);
    // importações FFI: os argumentos (Int) são emprestados.
    for fo in &module.foreigns {
        let arity = fo.sig.param_mults().len();
        consumers.insert(fo.name.clone(), vec![Mult::Many; arity]);
    }
    Ctx {
        consumers,
        field_mults,
        must_use_types: build_must_use_types(module),
    }
}

type Uses = (usize, usize); // (consumos, empréstimos)

fn add(a: Uses, b: Uses) -> Uses {
    (a.0 + b.0, a.1 + b.1)
}

fn alt(a: Uses, b: Uses) -> Uses {
    (a.0.max(b.0), a.1.max(b.1))
}

fn analyze_clause(clause: &Clause, x: &str, ctx: &Ctx) -> Uses {
    // o valor da cláusula é devolvido ⇒ posição de consumo
    let mut u = match &clause.body {
        Body::Plain(e) => analyze(e, x, Mode::Consume, ctx),
        Body::Guarded(arms) => arms
            .iter()
            .map(|(g, r)| {
                add(
                    analyze(g, x, Mode::Borrow, ctx),
                    analyze(r, x, Mode::Consume, ctx),
                )
            })
            .fold((0, 0), alt),
    };
    for w in &clause.wher {
        for c in &w.clauses {
            u = add(u, analyze_clause(c, x, ctx));
        }
    }
    u
}

fn analyze(e: &Expr, x: &str, mode: Mode, ctx: &Ctx) -> Uses {
    match e {
        Expr::Var(n, _) => {
            if n == x {
                if mode == Mode::Consume {
                    (1, 0)
                } else {
                    (0, 1)
                }
            } else {
                (0, 0)
            }
        }
        Expr::Int(_, _) | Expr::Str(_, _) | Expr::Con(_, _) => (0, 0),
        // operandos de aritmética/comparação são lidos, não consumidos
        Expr::BinOp(_, l, r, _) => add(
            analyze(l, x, Mode::Borrow, ctx),
            analyze(r, x, Mode::Borrow, ctx),
        ),
        Expr::App(_, _, _) => {
            let (head, args) = spine(e);
            let mults = head_mults(head, ctx);
            let mut u = analyze(head, x, Mode::Borrow, ctx);
            for (i, a) in args.iter().enumerate() {
                let m = arg_mode(mults.get(i));
                u = add(u, analyze(a, x, m, ctx));
            }
            u
        }
        // condição lida; os ramos são caminhos alternativos, no modo do pai
        Expr::If(c, t, el, _) => add(
            analyze(c, x, Mode::Borrow, ctx),
            alt(analyze(t, x, mode, ctx), analyze(el, x, mode, ctx)),
        ),
        Expr::Case(s, arms, _) => add(
            analyze(s, x, Mode::Borrow, ctx),
            arms.iter()
                .map(|(_, b)| analyze(b, x, mode, ctx))
                .fold((0, 0), alt),
        ),
        Expr::Let(binds, body, _) => {
            let in_binds = binds
                .iter()
                .flat_map(|b| &b.clauses)
                .map(|c| analyze_clause(c, x, ctx))
                .fold((0, 0), add);
            add(in_binds, analyze(body, x, mode, ctx))
        }
        // um tuplo devolvido faz a posse dos componentes fluir para fora
        Expr::Tuple(es, _) => es
            .iter()
            .map(|e| analyze(e, x, mode, ctx))
            .fold((0, 0), add),
        Expr::RecordCon(_, assigns, _) => analyze_assigns(assigns, x, ctx),
        Expr::RecordUpd(base, assigns, _) => add(
            analyze(base, x, Mode::Consume, ctx), // a actualização toma posse do base
            analyze_assigns(assigns, x, ctx),
        ),
        // uma lambda que sombreie x não o refere; caso contrário conta o corpo
        Expr::Lam(pats, body, _) => {
            if binds_var(pats, x) {
                (0, 0)
            } else {
                analyze(body, x, mode, ctx)
            }
        }
    }
}

/// Verdade se algum dos padrões liga o nome `x` (sombreamento).
fn binds_var(pats: &[Pat], x: &str) -> bool {
    let mut s = HashSet::new();
    for p in pats {
        collect_pat_vars(p, &mut s);
    }
    s.contains(x)
}

fn analyze_assigns(assigns: &[(String, Expr)], x: &str, ctx: &Ctx) -> Uses {
    assigns
        .iter()
        .map(|(fname, e)| {
            let m = arg_mode(ctx.field_mults.get(fname));
            analyze(e, x, m, ctx)
        })
        .fold((0, 0), add)
}

fn arg_mode(mult: Option<&Mult>) -> Mode {
    if mult == Some(&Mult::One) {
        Mode::Consume
    } else {
        Mode::Borrow
    }
}

fn head_mults(head: &Expr, ctx: &Ctx) -> Vec<Mult> {
    match head {
        Expr::Var(n, _) | Expr::Con(n, _) => ctx.consumers.get(n).cloned().unwrap_or_default(),
        _ => Vec::new(),
    }
}

/// Achata a espinha de aplicação: `f a b c` → (`f`, [a, b, c]).
fn spine(e: &Expr) -> (&Expr, Vec<&Expr>) {
    let mut args = Vec::new();
    let mut cur = e;
    while let Expr::App(f, a, _) = cur {
        args.push(a.as_ref());
        cur = f;
    }
    args.reverse();
    (cur, args)
}

/// Span da última ocorrência (maior offset) de `x` na cláusula — o ponto de morte.
fn last_occurrence_clause(clause: &Clause, x: &str) -> Option<Span> {
    let mut best: Option<Span> = None;
    match &clause.body {
        Body::Plain(e) => collect_last(e, x, &mut best),
        Body::Guarded(arms) => {
            for (g, r) in arms {
                collect_last(g, x, &mut best);
                collect_last(r, x, &mut best);
            }
        }
    }
    for w in &clause.wher {
        for c in &w.clauses {
            if let Some(s) = last_occurrence_clause(c, x) {
                if best.is_none_or(|b| s.0 > b.0) {
                    best = Some(s);
                }
            }
        }
    }
    best
}

fn collect_last(e: &Expr, x: &str, best: &mut Option<Span>) {
    match e {
        Expr::Var(n, sp) => {
            if n == x && best.is_none_or(|b| sp.0 > b.0) {
                *best = Some(*sp);
            }
        }
        Expr::Int(_, _) | Expr::Str(_, _) | Expr::Con(_, _) => {}
        Expr::App(f, a, _) => {
            collect_last(f, x, best);
            collect_last(a, x, best);
        }
        Expr::BinOp(_, l, r, _) => {
            collect_last(l, x, best);
            collect_last(r, x, best);
        }
        Expr::If(c, t, el, _) => {
            collect_last(c, x, best);
            collect_last(t, x, best);
            collect_last(el, x, best);
        }
        Expr::Case(s, arms, _) => {
            collect_last(s, x, best);
            for (_, b) in arms {
                collect_last(b, x, best);
            }
        }
        Expr::Let(binds, body, _) => {
            for bnd in binds {
                for c in &bnd.clauses {
                    if let Some(s) = last_occurrence_clause(c, x) {
                        if best.is_none_or(|b| s.0 > b.0) {
                            *best = Some(s);
                        }
                    }
                }
            }
            collect_last(body, x, best);
        }
        Expr::Tuple(es, _) => es.iter().for_each(|e| collect_last(e, x, best)),
        Expr::RecordCon(_, assigns, _) => {
            assigns.iter().for_each(|(_, e)| collect_last(e, x, best))
        }
        Expr::RecordUpd(base, assigns, _) => {
            collect_last(base, x, best);
            assigns.iter().for_each(|(_, e)| collect_last(e, x, best));
        }
        Expr::Lam(pats, body, _) => {
            if !binds_var(pats, x) {
                collect_last(body, x, best);
            }
        }
    }
}

// --- verificação de ORDEM: uso-após-move (AX0004) ---
//
// Percorre o corpo na ordem de avaliação (esquerda→direita) mantendo se a posse
// de `x` já foi movida (consumida). Qualquer ocorrência de `x` depois disso — ler
// ou consumir — é uso-após-move. Ramos (`if`/`case`) são caminhos: cada um parte
// do mesmo estado e o resultado junta-se (movido se algum ramo mover).

#[derive(Clone, Copy, Default)]
struct MoveState {
    moved: Option<Span>,         // onde a posse foi movida (se já foi)
    error: Option<(Span, Span)>, // (onde moveu, onde foi usado depois) — o 1.º
}

/// Devolve `(span do move, span do uso posterior)` se houver uso-após-move.
fn use_after_move(clause: &Clause, x: &str, ctx: &Ctx) -> Option<(Span, Span)> {
    let st = match &clause.body {
        Body::Plain(e) => walk(e, x, Mode::Consume, ctx, MoveState::default()),
        // guardas são caminhos exclusivos: cada uma parte do estado inicial
        Body::Guarded(arms) => arms
            .iter()
            .map(|(g, r)| {
                let s = walk(g, x, Mode::Borrow, ctx, MoveState::default());
                walk(r, x, Mode::Consume, ctx, s)
            })
            .find(|s| s.error.is_some())
            .unwrap_or_default(),
    };
    st.error
}

fn walk(e: &Expr, x: &str, mode: Mode, ctx: &Ctx, mut st: MoveState) -> MoveState {
    match e {
        Expr::Var(n, sp) => {
            if n == x {
                if let Some(mv) = st.moved {
                    if st.error.is_none() {
                        st.error = Some((mv, *sp)); // usado depois de movido
                    }
                } else if mode == Mode::Consume {
                    st.moved = Some(*sp);
                }
            }
            st
        }
        Expr::Int(_, _) | Expr::Str(_, _) | Expr::Con(_, _) => st,
        Expr::BinOp(_, l, r, _) => {
            st = walk(l, x, Mode::Borrow, ctx, st);
            walk(r, x, Mode::Borrow, ctx, st)
        }
        Expr::App(_, _, _) => {
            let (head, args) = spine(e);
            let mults = head_mults(head, ctx);
            st = walk(head, x, Mode::Borrow, ctx, st);
            for (i, a) in args.iter().enumerate() {
                st = walk(a, x, arg_mode(mults.get(i)), ctx, st);
            }
            st
        }
        Expr::If(c, t, el, _) => {
            st = walk(c, x, Mode::Borrow, ctx, st);
            join(walk(t, x, mode, ctx, st), walk(el, x, mode, ctx, st))
        }
        Expr::Case(s, arms, _) => {
            st = walk(s, x, Mode::Borrow, ctx, st);
            arms.iter()
                .map(|(_, b)| walk(b, x, mode, ctx, st))
                .reduce(join)
                .unwrap_or(st)
        }
        Expr::Let(binds, body, _) => {
            for c in binds.iter().flat_map(|b| &b.clauses) {
                if let Some((mv, u)) = use_after_move(c, x, ctx) {
                    if st.error.is_none() {
                        st.error = Some((mv, u));
                    }
                }
                // um bind que consome x deixa a posse movida no corpo
                if analyze_clause(c, x, ctx).0 > 0 {
                    st.moved = st.moved.or(Some(c.span));
                }
            }
            walk(body, x, mode, ctx, st)
        }
        Expr::Tuple(es, _) => {
            for e in es {
                st = walk(e, x, mode, ctx, st);
            }
            st
        }
        Expr::RecordCon(_, assigns, _) => walk_assigns(assigns, x, ctx, st),
        Expr::RecordUpd(base, assigns, _) => {
            st = walk(base, x, Mode::Consume, ctx, st);
            walk_assigns(assigns, x, ctx, st)
        }
        Expr::Lam(pats, body, _) => {
            if binds_var(pats, x) {
                st
            } else {
                walk(body, x, mode, ctx, st)
            }
        }
    }
}

fn walk_assigns(assigns: &[(String, Expr)], x: &str, ctx: &Ctx, mut st: MoveState) -> MoveState {
    for (fname, e) in assigns {
        st = walk(e, x, arg_mode(ctx.field_mults.get(fname)), ctx, st);
    }
    st
}

/// Junta dois caminhos alternativos (ramos): movido se algum mover; 1.º erro.
fn join(a: MoveState, b: MoveState) -> MoveState {
    MoveState {
        moved: a.moved.or(b.moved),
        error: a.error.or(b.error),
    }
}

// --- valores 'let' lineares + mutação in-place (§2) ---

/// A "classe" de um recurso linear: se é must-use e o nome do seu tipo.
#[derive(Clone)]
struct Lin {
    must_use: bool,
    ty: String,
}

fn class_of_type(ty: &Type, mu: &HashSet<String>) -> Lin {
    Lin {
        must_use: is_must_use(ty, mu),
        ty: ty.head_con().unwrap_or("?").to_string(),
    }
}

/// O RHS de um `let v = <e>` simples (um bind sem parâmetros nem guardas).
fn simple_bind_rhs(f: &Func) -> Option<&Expr> {
    match f.clauses.as_slice() {
        [c] if c.pats.is_empty() => match &c.body {
            Body::Plain(e) => Some(e),
            _ => None,
        },
        _ => None,
    }
}

/// Percorre o corpo recolhendo (1) os `let` que recebem posse de um recurso
/// linear — que passam a ser recursos lineares no seu âmbito — e (2) os locais
/// de actualização in-place (RecordUpd cujo base é um recurso linear vivo).
fn scan_lets<'a>(
    e: &'a Expr,
    lin: &HashMap<String, Lin>,
    ctx: &Ctx,
    lets: &mut Vec<(String, Lin, &'a Expr, Span)>,
    inplace: &mut Vec<InPlace>,
    func: &str,
) {
    match e {
        Expr::Let(binds, body, _) => {
            let mut cur = lin.clone();
            for b in binds {
                if let Some(rhs) = simple_bind_rhs(b) {
                    scan_lets(rhs, &cur, ctx, lets, inplace, func);
                    // um bind cujo RHS consome um recurso linear herda a posse
                    let consumed = cur
                        .keys()
                        .find(|w| analyze(rhs, w, Mode::Consume, ctx).0 > 0)
                        .cloned();
                    if let Some(w) = consumed {
                        let class = cur[&w].clone();
                        lets.push((b.name.clone(), class.clone(), body, b.span));
                        cur.insert(b.name.clone(), class);
                    }
                } else {
                    for c in &b.clauses {
                        if let Body::Plain(e2) = &c.body {
                            scan_lets(e2, &cur, ctx, lets, inplace, func);
                        }
                    }
                }
            }
            scan_lets(body, &cur, ctx, lets, inplace, func);
        }
        Expr::RecordUpd(base, assigns, span) => {
            if let Expr::Var(name, _) = base.as_ref() {
                if lin.contains_key(name) {
                    inplace.push(InPlace {
                        func: func.to_string(),
                        var: name.clone(),
                        span: *span,
                    });
                }
            }
            scan_lets(base, lin, ctx, lets, inplace, func);
            for (_, a) in assigns {
                scan_lets(a, lin, ctx, lets, inplace, func);
            }
        }
        Expr::App(f, a, _) => {
            scan_lets(f, lin, ctx, lets, inplace, func);
            scan_lets(a, lin, ctx, lets, inplace, func);
        }
        Expr::BinOp(_, l, r, _) => {
            scan_lets(l, lin, ctx, lets, inplace, func);
            scan_lets(r, lin, ctx, lets, inplace, func);
        }
        Expr::If(c, t, el, _) => {
            scan_lets(c, lin, ctx, lets, inplace, func);
            scan_lets(t, lin, ctx, lets, inplace, func);
            scan_lets(el, lin, ctx, lets, inplace, func);
        }
        Expr::Case(s, arms, _) => {
            scan_lets(s, lin, ctx, lets, inplace, func);
            for (_, b) in arms {
                scan_lets(b, lin, ctx, lets, inplace, func);
            }
        }
        Expr::Tuple(es, _) => es
            .iter()
            .for_each(|e| scan_lets(e, lin, ctx, lets, inplace, func)),
        Expr::RecordCon(_, assigns, _) => {
            for (_, a) in assigns {
                scan_lets(a, lin, ctx, lets, inplace, func);
            }
        }
        Expr::Lam(_, body, _) => scan_lets(body, lin, ctx, lets, inplace, func),
        Expr::Var(_, _) | Expr::Int(_, _) | Expr::Str(_, _) | Expr::Con(_, _) => {}
    }
}

// --- análise de escape de sub-arena (AX0003, §3) ---
//
// Um valor alocado numa sub-arena (`allocateCell sub …`) não pode escapar ao
// escopo do `withSubArena sub … -> corpo` (por ser devolvido). O escape é erro
// de compilação; `promote parent v` re-liga o valor à arena-pai e safa-o.
// Rastreio de proveniência de região, análogo à análise de move.

/// Reconhece `withSubArena <parent> (\sub -> corpo)` e devolve `(sub, corpo)`.
fn as_with_sub_arena(e: &Expr) -> Option<(&str, &Expr)> {
    let (head, args) = spine(e);
    let is_wsa = matches!(head, Expr::Var(n, _) if n == "withSubArena");
    if is_wsa && args.len() >= 2 {
        if let Expr::Lam(pats, body, _) = args[1] {
            if let [Pat::Var(sub, _)] = pats.as_slice() {
                return Some((sub, body));
            }
        }
    }
    None
}

/// Procura recursivamente formas `withSubArena` e verifica o escape em cada uma.
fn check_arena_escapes(
    e: &Expr,
    func: &str,
    diags: &mut Diagnostics,
    arenas: &mut Vec<ArenaReset>,
) {
    if let Some((sub, body)) = as_with_sub_arena(e) {
        check_sub_scope(body, sub, func, diags, arenas);
    }
    let mut go = |e: &Expr| check_arena_escapes(e, func, diags, arenas);
    match e {
        Expr::App(f, a, _) => {
            go(f);
            go(a);
        }
        Expr::BinOp(_, l, r, _) => {
            go(l);
            go(r);
        }
        Expr::If(c, t, el, _) => {
            go(c);
            go(t);
            go(el);
        }
        Expr::Let(binds, body, _) => {
            for c in binds.iter().flat_map(|b| &b.clauses) {
                if let Body::Plain(e2) = &c.body {
                    go(e2);
                }
            }
            go(body);
        }
        Expr::Case(s, arms, _) => {
            go(s);
            for (_, b) in arms {
                go(b);
            }
        }
        Expr::Tuple(es, _) => es.iter().for_each(&mut go),
        Expr::RecordCon(_, assigns, _) | Expr::RecordUpd(_, assigns, _) => {
            assigns.iter().for_each(|(_, e)| go(e))
        }
        Expr::Lam(_, body, _) => go(body),
        Expr::Var(_, _) | Expr::Int(_, _) | Expr::Str(_, _) | Expr::Con(_, _) => {}
    }
}

/// Verifica um corpo de `withSubArena`: (1) nenhum valor ligado à sub-arena pode
/// escapar (por retorno ou captura) — `AX0003`; (2) computa o reset NLL (§3): o
/// ponto de morte da região é a última menção viva de um valor da sub-arena.
fn check_sub_scope(
    body: &Expr,
    sub: &str,
    func: &str,
    diags: &mut Diagnostics,
    arenas: &mut Vec<ArenaReset>,
) {
    let mut sub_bound: HashMap<String, Span> = HashMap::new();
    let tail = peel_arena_lets(body, sub, &mut sub_bound);

    // (1) escape
    if let Some(origin) = region_of(tail, sub, &sub_bound) {
        let esc = tail.span();
        diags.push(
            Diagnostic::error("AX0003", "um valor escapa da sua sub-arena")
                .label(
                    esc.0,
                    esc.1,
                    "devolvido daqui — sobreviveria ao reset da sub-arena",
                )
                .label(origin.0, origin.1, format!("vive na sub-arena '{sub}'"))
                .with_help(
                    "no reset a RAM da sub-arena é recuperada; mova o valor para a \
                     arena-pai antes do reset com 'promote parent valor' (§3).",
                ),
        );
        return; // com escape, o reset é irrelevante
    }

    // (2) reset NLL: a última menção viva de qualquer valor da sub-arena
    let mut reset: Option<(Span, &String)> = None;
    for var in sub_bound.keys() {
        let mut last = None;
        collect_last(body, var, &mut last);
        if let Some(sp) = last {
            if reset.is_none_or(|(r, _)| sp.0 > r.0) {
                reset = Some((sp, var));
            }
        }
    }
    if let Some((span, var)) = reset {
        arenas.push(ArenaReset {
            func: func.to_string(),
            sub: sub.to_string(),
            span,
            last_var: var.clone(),
        });
    }
}

/// Percorre a cadeia de `let`, registando os nomes ligados à sub-arena, e
/// devolve a expressão-cauda (o valor de retorno).
fn peel_arena_lets<'a>(e: &'a Expr, sub: &str, sub_bound: &mut HashMap<String, Span>) -> &'a Expr {
    let mut cur = e;
    while let Expr::Let(binds, body, _) = cur {
        for b in binds {
            if let Some(rhs) = simple_bind_rhs(b) {
                if let Some(sp) = region_of(rhs, sub, sub_bound) {
                    sub_bound.insert(b.name.clone(), sp);
                }
            }
        }
        cur = body;
    }
    cur
}

/// Se `e` produz um valor ligado à sub-arena `sub`, devolve o span da sua
/// origem (a alocação). `promote` re-liga à arena-pai, cortando a proveniência.
fn region_of(e: &Expr, sub: &str, sub_bound: &HashMap<String, Span>) -> Option<Span> {
    match e {
        Expr::Var(n, _) => sub_bound.get(n).copied(),
        Expr::App(_, _, _) => {
            let (head, args) = spine(e);
            match head {
                Expr::Var(n, _) if n == "allocateCell" => {
                    // allocateCell sub … → vive na sub-arena
                    if matches!(args.first(), Some(Expr::Var(a, _)) if a == sub) {
                        Some(e.span())
                    } else {
                        None
                    }
                }
                // promote corta a proveniência: o resultado vive na arena-pai
                Expr::Var(n, _) if n == "promote" => None,
                // outra função: conservador — pode devolver um valor da sub-arena
                _ => args.iter().find_map(|a| region_of(a, sub, sub_bound)),
            }
        }
        Expr::Tuple(es, _) => es.iter().find_map(|e| region_of(e, sub, sub_bound)),
        Expr::RecordCon(_, assigns, _) | Expr::RecordUpd(_, assigns, _) => assigns
            .iter()
            .find_map(|(_, e)| region_of(e, sub, sub_bound)),
        // uma closure que capture um valor da sub-arena carrega-o para fora
        // (§3C: o escape pode ser por retorno OU por captura em closure).
        Expr::Lam(pats, body, _) => {
            let mut shadowed = HashSet::new();
            for p in pats {
                collect_pat_vars(p, &mut shadowed);
            }
            captured_sub_ref(body, sub_bound, &mut shadowed)
        }
        _ => None,
    }
}

/// Procura uma referência **livre** a um valor ligado à sub-arena dentro de `e`
/// (usada para detectar captura em closure). Devolve o span da alocação.
fn captured_sub_ref(
    e: &Expr,
    sub_bound: &HashMap<String, Span>,
    shadowed: &mut HashSet<String>,
) -> Option<Span> {
    match e {
        Expr::Var(n, _) => {
            if shadowed.contains(n) {
                None
            } else {
                sub_bound.get(n).copied()
            }
        }
        Expr::App(f, a, _) => captured_sub_ref(f, sub_bound, shadowed)
            .or_else(|| captured_sub_ref(a, sub_bound, shadowed)),
        Expr::BinOp(_, l, r, _) => captured_sub_ref(l, sub_bound, shadowed)
            .or_else(|| captured_sub_ref(r, sub_bound, shadowed)),
        Expr::If(c, t, el, _) => captured_sub_ref(c, sub_bound, shadowed)
            .or_else(|| captured_sub_ref(t, sub_bound, shadowed))
            .or_else(|| captured_sub_ref(el, sub_bound, shadowed)),
        Expr::Tuple(es, _) => es
            .iter()
            .find_map(|e| captured_sub_ref(e, sub_bound, shadowed)),
        Expr::RecordCon(_, assigns, _) | Expr::RecordUpd(_, assigns, _) => assigns
            .iter()
            .find_map(|(_, e)| captured_sub_ref(e, sub_bound, shadowed)),
        Expr::Case(s, arms, _) => captured_sub_ref(s, sub_bound, shadowed).or_else(|| {
            arms.iter()
                .find_map(|(_, b)| captured_sub_ref(b, sub_bound, shadowed))
        }),
        Expr::Let(binds, body, _) => binds
            .iter()
            .flat_map(|b| &b.clauses)
            .find_map(|c| match &c.body {
                Body::Plain(e2) => captured_sub_ref(e2, sub_bound, shadowed),
                _ => None,
            })
            .or_else(|| captured_sub_ref(body, sub_bound, shadowed)),
        Expr::Lam(pats, body, _) => {
            for p in pats {
                collect_pat_vars(p, shadowed);
            }
            captured_sub_ref(body, sub_bound, shadowed)
        }
        Expr::Int(_, _) | Expr::Str(_, _) | Expr::Con(_, _) => None,
    }
}

// --- marcas de arena: reclamação intra-escopo (AX0005, Listagem 3.6, §3) ---
//
// `mark = arena_mark arena` guarda o topo do bump-pointer; `arena_release mark`
// recua-o, recuperando tudo o que foi alocado depois da marca. Logo, um valor
// alocado após a marca não pode ser usado DEPOIS do release — a sua memória já
// foi recuperada. Análise ordenada sobre a espinha de `let`.

struct Mark {
    name: String,
    arena: String,
    released: Option<Span>,
}

struct BoundCell {
    mark: String,
    alloc: Span,
}

/// Classifica o RHS de um `let` como uma operação de marca de arena.
enum MarkOp<'a> {
    OpenMark { arena: &'a str }, // arena_mark arena
    Alloc { arena: &'a str },    // allocateCell arena
    Release { mark: &'a str },   // arena_release mark
    Other,
}

fn classify_mark_op(e: &Expr) -> MarkOp<'_> {
    let (head, args) = spine(e);
    let arg0 = args.first();
    match head {
        Expr::Var(n, _) if n == "arena_mark" => match arg0 {
            Some(Expr::Var(a, _)) => MarkOp::OpenMark { arena: a },
            _ => MarkOp::Other,
        },
        Expr::Var(n, _) if n == "allocateCell" => match arg0 {
            Some(Expr::Var(a, _)) => MarkOp::Alloc { arena: a },
            _ => MarkOp::Other,
        },
        Expr::Var(n, _) if n == "arena_release" => match arg0 {
            Some(Expr::Var(m, _)) => MarkOp::Release { mark: m },
            _ => MarkOp::Other,
        },
        _ => MarkOp::Other,
    }
}

/// Verifica a disciplina das marcas de arena num corpo de função.
fn check_arena_marks(e: &Expr, diags: &mut Diagnostics) {
    let mut marks: Vec<Mark> = Vec::new();
    let mut bound: HashMap<String, BoundCell> = HashMap::new();
    let mut cur = e;
    loop {
        match cur {
            Expr::Let(binds, body, _) => {
                for b in binds {
                    match simple_bind_rhs(b) {
                        Some(rhs) => {
                            check_released_uses(rhs, &bound, &marks, diags);
                            apply_mark_op(&b.name, rhs, &mut marks, &mut bound);
                            check_nested_marks(rhs, diags);
                        }
                        None => {
                            for c in &b.clauses {
                                if let Body::Plain(e2) = &c.body {
                                    check_arena_marks(e2, diags);
                                }
                            }
                        }
                    }
                }
                cur = body;
            }
            other => {
                check_released_uses(other, &bound, &marks, diags);
                check_nested_marks(other, diags);
                break;
            }
        }
    }
}

fn apply_mark_op(
    name: &str,
    rhs: &Expr,
    marks: &mut Vec<Mark>,
    bound: &mut HashMap<String, BoundCell>,
) {
    match classify_mark_op(rhs) {
        MarkOp::OpenMark { arena } => marks.push(Mark {
            name: name.to_string(),
            arena: arena.to_string(),
            released: None,
        }),
        MarkOp::Alloc { arena } => {
            // liga à marca aberta mais recente da mesma arena
            if let Some(m) = marks
                .iter()
                .rev()
                .find(|m| m.arena == arena && m.released.is_none())
            {
                bound.insert(
                    name.to_string(),
                    BoundCell {
                        mark: m.name.clone(),
                        alloc: rhs.span(),
                    },
                );
            }
        }
        MarkOp::Release { mark } => {
            if let Some(m) = marks.iter_mut().find(|m| m.name == mark) {
                m.released = Some(rhs.span());
            }
        }
        MarkOp::Other => {}
    }
}

/// Reporta usos de valores cuja marca já foi libertada (AX0005).
fn check_released_uses(
    e: &Expr,
    bound: &HashMap<String, BoundCell>,
    marks: &[Mark],
    diags: &mut Diagnostics,
) {
    let released_span = |mark: &str| {
        marks
            .iter()
            .find(|m| m.name == mark)
            .and_then(|m| m.released)
    };
    let mut check = |n: &str, sp: Span| {
        if let Some(bc) = bound.get(n) {
            if let Some(rel) = released_span(&bc.mark) {
                diags.push(
                    Diagnostic::error(
                        "AX0005",
                        format!("'{n}' usado após o 'arena_release' (memória já recuperada)"),
                    )
                    .label(sp.0, sp.1, format!("'{n}' usado aqui…"))
                    .label(
                        rel.0,
                        rel.1,
                        "…mas o arena_release recuperou a memória aqui",
                    )
                    .label(
                        bc.alloc.0,
                        bc.alloc.1,
                        format!("'{n}' foi alocado depois da marca aqui"),
                    )
                    .with_help(
                        "tudo o que é alocado depois de uma marca é recuperado no \
                         arena_release; consuma-o antes, ou promova-o para lá da marca (§3).",
                    ),
                );
            }
        }
    };
    collect_var_refs(e, &mut check);
}

/// Aplica `f` a cada ocorrência de variável em `e`.
fn collect_var_refs(e: &Expr, f: &mut dyn FnMut(&str, Span)) {
    match e {
        Expr::Var(n, sp) => f(n, *sp),
        Expr::Int(_, _) | Expr::Str(_, _) | Expr::Con(_, _) => {}
        Expr::App(a, b, _) | Expr::BinOp(_, a, b, _) => {
            collect_var_refs(a, f);
            collect_var_refs(b, f);
        }
        Expr::If(c, t, el, _) => {
            collect_var_refs(c, f);
            collect_var_refs(t, f);
            collect_var_refs(el, f);
        }
        Expr::Tuple(es, _) => es.iter().for_each(|e| collect_var_refs(e, f)),
        Expr::RecordCon(_, assigns, _) | Expr::RecordUpd(_, assigns, _) => {
            assigns.iter().for_each(|(_, e)| collect_var_refs(e, f))
        }
        Expr::Case(s, arms, _) => {
            collect_var_refs(s, f);
            arms.iter().for_each(|(_, b)| collect_var_refs(b, f));
        }
        Expr::Let(binds, body, _) => {
            binds.iter().flat_map(|b| &b.clauses).for_each(|c| {
                if let Body::Plain(e2) = &c.body {
                    collect_var_refs(e2, f);
                }
            });
            collect_var_refs(body, f);
        }
        Expr::Lam(_, body, _) => collect_var_refs(body, f),
    }
}

/// Recorre a sub-expressões (não a espinha atual) à procura de escopos de marca
/// aninhados, correndo uma análise fresca em cada.
fn check_nested_marks(e: &Expr, diags: &mut Diagnostics) {
    match e {
        Expr::App(a, b, _) | Expr::BinOp(_, a, b, _) => {
            check_arena_marks(a, diags);
            check_arena_marks(b, diags);
        }
        Expr::If(c, t, el, _) => {
            check_arena_marks(c, diags);
            check_arena_marks(t, diags);
            check_arena_marks(el, diags);
        }
        Expr::Tuple(es, _) => es.iter().for_each(|e| check_arena_marks(e, diags)),
        Expr::RecordCon(_, assigns, _) | Expr::RecordUpd(_, assigns, _) => assigns
            .iter()
            .for_each(|(_, e)| check_arena_marks(e, diags)),
        Expr::Case(s, arms, _) => {
            check_arena_marks(s, diags);
            arms.iter().for_each(|(_, b)| check_arena_marks(b, diags));
        }
        Expr::Lam(_, body, _) => check_arena_marks(body, diags),
        // Let é a espinha, já tratada por check_arena_marks; folhas: nada
        Expr::Let(_, _, _)
        | Expr::Var(_, _)
        | Expr::Int(_, _)
        | Expr::Str(_, _)
        | Expr::Con(_, _) => {}
    }
}

// --- permissões fraccionárias %0.5: split/join (AX0006, §2, Listagem 2.3) ---
//
// `split cfg` divide um %1 em duas metades %0.5 de LEITURA PARTILHADA; `join a b`
// recombina-as em %1. Uma metade %0.5 pode ser lida (emprestada) à vontade e
// recombinada por `join`, mas NUNCA escrita: usá-la numa posição de escrita
// (argumento de um parâmetro %1 de uma função, ou base de uma actualização de
// registo, ou campo %1) é AX0006.

fn is_var(e: &Expr, name: &str) -> bool {
    matches!(e, Expr::Var(n, _) if n == name)
}

/// Verdade se `e` é uma chamada a `split` (a origem das metades %0.5).
fn is_split_call(e: &Expr) -> bool {
    matches!(spine(e).0, Expr::Var(n, _) if n == "split")
}

/// Procura `case (split …) of (a, b) -> arm` e verifica que as metades `a`/`b`
/// não são escritas no braço.
fn check_fractional(e: &Expr, ctx: &Ctx, diags: &mut Diagnostics) {
    if let Expr::Case(scrut, arms, _) = e {
        if is_split_call(scrut) {
            for (pat, body) in arms {
                if let Pat::Tuple(ps, _) = pat {
                    for p in ps {
                        if let Pat::Var(half, _) = p {
                            check_half_writes(body, half, ctx, diags);
                        }
                    }
                }
            }
        }
    }
    // recorre a sub-expressões (casos aninhados)
    for_each_child(e, &mut |c| check_fractional(c, ctx, diags));
}

/// Emite o AX0006 de escrita através de uma metade %0.5.
fn push_write(diags: &mut Diagnostics, half: &str, sp: Span, what: &str) {
    diags.push(
        Diagnostic::error("AX0006", format!("escrita através da metade %0.5 '{half}'"))
            .label(
                sp.0,
                sp.1,
                format!("'{half}' é %0.5 (leitura partilhada): {what}"),
            )
            .with_help(
                "uma metade %0.5 só concede leitura; para recuperar a escrita, \
                 recombine as duas metades com 'join a b' (que devolve o %1) (§2).",
            ),
    );
}

/// Reporta escritas através da metade %0.5 `half` em `e` (AX0006).
fn check_half_writes(e: &Expr, half: &str, ctx: &Ctx, diags: &mut Diagnostics) {
    match e {
        Expr::App(_, _, _) => {
            let (head, args) = spine(e);
            let mults = head_mults(head, ctx);
            for (i, a) in args.iter().enumerate() {
                if is_var(a, half) && mults.get(i) == Some(&Mult::One) {
                    push_write(diags, half, a.span(), "passado a um parâmetro %1 (escrita)");
                }
                check_half_writes(a, half, ctx, diags);
            }
            check_half_writes(head, half, ctx, diags);
        }
        Expr::RecordUpd(base, assigns, _) => {
            if is_var(base, half) {
                push_write(
                    diags,
                    half,
                    base.span(),
                    "base de uma actualização de registo (escrita)",
                );
            } else {
                check_half_writes(base, half, ctx, diags);
            }
            check_half_assigns(assigns, half, ctx, diags);
        }
        Expr::RecordCon(_, assigns, _) => check_half_assigns(assigns, half, ctx, diags),
        _ => for_each_child(e, &mut |c| check_half_writes(c, half, ctx, diags)),
    }
}

fn check_half_assigns(assigns: &[(String, Expr)], half: &str, ctx: &Ctx, diags: &mut Diagnostics) {
    for (fname, val) in assigns {
        if is_var(val, half) && ctx.field_mults.get(fname) == Some(&Mult::One) {
            push_write(diags, half, val.span(), "posto num campo %1 (escrita)");
        } else {
            check_half_writes(val, half, ctx, diags);
        }
    }
}

/// Aplica `f` a cada sub-expressão directa de `e`.
fn for_each_child(e: &Expr, f: &mut dyn FnMut(&Expr)) {
    match e {
        Expr::App(a, b, _) | Expr::BinOp(_, a, b, _) => {
            f(a);
            f(b);
        }
        Expr::If(c, t, el, _) => {
            f(c);
            f(t);
            f(el);
        }
        Expr::Let(binds, body, _) => {
            binds.iter().flat_map(|b| &b.clauses).for_each(|c| {
                if let Body::Plain(e2) = &c.body {
                    f(e2);
                }
            });
            f(body);
        }
        Expr::Case(s, arms, _) => {
            f(s);
            arms.iter().for_each(|(_, b)| f(b));
        }
        Expr::Tuple(es, _) => es.iter().for_each(&mut *f),
        Expr::RecordCon(_, assigns, _) | Expr::RecordUpd(_, assigns, _) => {
            assigns.iter().for_each(|(_, e)| f(e))
        }
        Expr::Lam(_, body, _) => f(body),
        Expr::Var(_, _) | Expr::Int(_, _) | Expr::Str(_, _) | Expr::Con(_, _) => {}
    }
}
