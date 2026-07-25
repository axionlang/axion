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
//! Limitação assumida deste corte: a ORDEM não é verificada (um empréstimo
//! depois do consumo — uso-após-move — ainda não é detectado).

use crate::ast::*;
use crate::diag::{Diagnostic, Diagnostics};
use std::collections::{HashMap, HashSet};

/// Tipos lineares **sem `Drop`** (must-use): esquecê-los é erro, não Auto-Drop.
/// Tudo o resto é droppable por omissão (§2).
const MUST_USE: &[&str] = &["Ep", "Token", "Endpoint", "Transaction"];

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

/// Corre a verificação e devolve os `free` injectados pelo Auto-Drop.
pub fn check(module: &Module, diags: &mut Diagnostics) -> Vec<DropPoint> {
    let mut globals: HashSet<String> = builtins();
    for f in &module.funcs {
        globals.insert(f.name.clone());
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
    let ctx = build_ctx(module);
    let mut drops = Vec::new();
    for f in &module.funcs {
        check_func(f, &globals, &ctx, diags, &mut drops);
    }
    drops
}

/// Um tipo é *must-use* se o seu construtor de topo não tem `Drop`.
fn is_must_use(ty: &Type) -> bool {
    matches!(ty.head_con(), Some(h) if MUST_USE.contains(&h))
}

fn builtins() -> HashSet<String> {
    ["putStrLn", "show", "otherwise", "True", "False"]
        .iter()
        .map(|s| s.to_string())
        .collect()
}

fn check_func(
    f: &Func,
    globals: &HashSet<String>,
    ctx: &Ctx,
    diags: &mut Diagnostics,
    drops: &mut Vec<DropPoint>,
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
        for (i, p) in clause.pats.iter().enumerate() {
            if mults.get(i).copied() != Some(Mult::One) {
                continue;
            }
            if let Pat::Var(name, span) = p {
                let (consumes, borrows) = analyze_clause(clause, name, ctx);
                let must_use = ptypes.get(i).map(|t| is_must_use(t)).unwrap_or(false);
                let ty_name = ptypes
                    .get(i)
                    .and_then(|t| t.head_con())
                    .unwrap_or("?")
                    .to_string();
                if consumes > 1 {
                    diags.push(
                        Diagnostic::error(
                            "AX0001",
                            format!("recurso linear '{name}' consumido {consumes} vezes (contração proibida)"),
                        )
                        .label(span.0, span.1, format!("'{name}' é %1: consumível uma só vez"))
                        .with_help(
                            "ler (emprestar) um %1 é livre e ilimitado; mover a posse \
                             (consumir) só pode acontecer uma vez — para o partilhar por \
                             posse, use 'split' em duas metades %0.5 (§2).",
                        ),
                    );
                } else if consumes == 0 && must_use {
                    diags.push(
                        Diagnostic::error(
                            "AX0002",
                            format!("recurso must-use '{name}' largado sem ser consumido"),
                        )
                        .label(
                            span.0,
                            span.1,
                            format!("'{name}' : {ty_name} %1 (sem Drop)"),
                        )
                        .with_help(
                            "endpoints, Token e handles são must-use (não têm Drop); \
                             consuma-o ou devolva-o (§2).",
                        ),
                    );
                } else if consumes == 0 {
                    // droppable, nunca consumido: Auto-Drop injecta 'free' no ponto
                    // de morte — a última leitura, ou a entrada se nunca lido.
                    let (death, reason) = if borrows == 0 {
                        (*span, "morre à entrada (nunca usado)")
                    } else {
                        (
                            last_occurrence_clause(clause, name).unwrap_or(*span),
                            "morre após a última leitura",
                        )
                    };
                    drops.push(DropPoint {
                        func: f.name.clone(),
                        var: name.clone(),
                        ty: ty_name,
                        span: death,
                        reason,
                    });
                }
            }
        }
    }
}

fn collect_pat_vars(p: &Pat, out: &mut HashSet<String>) {
    match p {
        Pat::Var(n, _) => {
            out.insert(n.clone());
        }
        Pat::Con(_, args, _) => {
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
                    Diagnostic::error("AX0101", format!("nome não encontrado: '{n}'")).label(
                        sp.0,
                        sp.1,
                        "não está em âmbito",
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

/// Multiplicidades de parâmetros/campos (funções, construtores) + mult por campo.
struct Ctx {
    /// função/construtor → multiplicidades dos parâmetros/campos (por ordem)
    consumers: HashMap<String, Vec<Mult>>,
    /// nome de campo → multiplicidade declarada (para registos)
    field_mults: HashMap<String, Mult>,
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
    Ctx {
        consumers,
        field_mults,
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
    }
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
    }
}
