//! Verificação estática: resolução de nomes (AX0101) + análise de linearidade
//! com **Auto-Drop** (§2).
//!
//! A regra da linearidade (§2), refinada pelo Auto-Drop:
//! - um `%1` **must-use** (sem `Drop`: `Ep`, `Token`, handles) é consumido
//!   **exactamente uma vez** — 0 usos ⇒ `AX0002`;
//! - um `%1` **droppable** (tem `Drop`) é consumido **quando muito uma vez** —
//!   0 usos ⇒ o compilador injecta `free` no ponto de morte (Auto-Drop), sem
//!   erro; o ponto de drop é reportado (`--emit drops`).
//! - a contracção (usar >1 vez) é sempre `AX0001`.
//!
//! Ramos alternativos (`if`, `case`) contam como caminhos: o uso é o máximo
//! entre ramos, não a soma.

use crate::ast::*;
use crate::diag::{Diagnostic, Diagnostics};
use std::collections::HashSet;

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
    let mut drops = Vec::new();
    for f in &module.funcs {
        check_func(f, &globals, diags, &mut drops);
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

        // --- linearidade + Auto-Drop: parâmetros %1 ---
        for (i, p) in clause.pats.iter().enumerate() {
            if mults.get(i).copied() != Some(Mult::One) {
                continue;
            }
            if let Pat::Var(name, span) = p {
                let n = count_clause(clause, name);
                let must_use = ptypes.get(i).map(|t| is_must_use(t)).unwrap_or(false);
                let ty_name = ptypes
                    .get(i)
                    .and_then(|t| t.head_con())
                    .unwrap_or("?")
                    .to_string();
                if n > 1 {
                    diags.push(
                        Diagnostic::error(
                            "AX0001",
                            format!("recurso linear '{name}' usado {n} vezes (contração proibida)"),
                        )
                        .label(
                            span.0,
                            span.1,
                            format!("'{name}' é %1: consumível uma só vez"),
                        )
                        .with_help(
                            "todo o valor %1 é consumido exactamente uma vez; \
                             divida-o com 'split' se precisa de o ler em dois sítios (§2).",
                        ),
                    );
                } else if n == 0 && must_use {
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
                } else if n == 0 {
                    // droppable e nunca consumido: Auto-Drop injecta 'free' no
                    // ponto de morte (aqui, à entrada — o valor morre logo).
                    drops.push(DropPoint {
                        func: f.name.clone(),
                        var: name.clone(),
                        ty: ty_name,
                        span: *span,
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

// --- contagem de usos (com ramos alternativos = máximo) ---

fn count_clause(clause: &Clause, var: &str) -> usize {
    let mut n = match &clause.body {
        Body::Plain(e) => count_expr(e, var),
        Body::Guarded(arms) => arms
            .iter()
            .map(|(g, r)| count_expr(g, var) + count_expr(r, var))
            .max()
            .unwrap_or(0),
    };
    for w in &clause.wher {
        for c in &w.clauses {
            n += count_clause(c, var);
        }
    }
    n
}

fn count_expr(e: &Expr, var: &str) -> usize {
    match e {
        Expr::Var(n, _) => (n == var) as usize,
        Expr::Int(_, _) | Expr::Str(_, _) | Expr::Con(_, _) => 0,
        Expr::App(f, x, _) => count_expr(f, var) + count_expr(x, var),
        Expr::BinOp(_, l, r, _) => count_expr(l, var) + count_expr(r, var),
        Expr::Tuple(es, _) => es.iter().map(|e| count_expr(e, var)).sum(),
        Expr::If(c, t, el, _) => count_expr(c, var) + count_expr(t, var).max(count_expr(el, var)),
        Expr::Case(s, arms, _) => {
            count_expr(s, var)
                + arms
                    .iter()
                    .map(|(_, b)| count_expr(b, var))
                    .max()
                    .unwrap_or(0)
        }
        Expr::Let(binds, body, _) => {
            let in_binds: usize = binds
                .iter()
                .flat_map(|b| &b.clauses)
                .map(|c| count_clause(c, var))
                .sum();
            in_binds + count_expr(body, var)
        }
        Expr::RecordCon(_, fields, _) => fields.iter().map(|(_, e)| count_expr(e, var)).sum(),
        Expr::RecordUpd(base, fields, _) => {
            count_expr(base, var)
                + fields
                    .iter()
                    .map(|(_, e)| count_expr(e, var))
                    .sum::<usize>()
        }
    }
}
