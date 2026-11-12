//! `axionc --emit ffi`: every FFI call site in the user's file.
//!
//! Axión's guarantees hold modulo the `foreign` imports (docs/ffi-trust-boundary.md): C code
//! is trusted, not checked. This report turns that caveat into a concrete, diffable list:
//! each import with its C symbol, library, per-argument ownership and effect status, then
//! each place the user's code mentions one, with the enclosing function and how many
//! arguments it is applied to. A reviewer reads the diff of this list to see what changed
//! at the trust boundary.

use crate::ast::{Body, Expr, Foreign, Func, Module, Pat, Span, Type};
use std::collections::{HashMap, HashSet};

/// One mention of a foreign import in user code.
struct Site {
    func: String,
    span: Span,
    name: String,
    /// Number of arguments it is applied to at this site (0 = passed as a value).
    applied: usize,
}

/// Render the report. `user` is the user's file as parsed (no prelude, no desugaring past
/// the parser), so spans and function names are the ones in the source; `foreigns` is every
/// import visible to it, including those from imported modules.
pub fn report(
    user: &Module,
    foreigns: &[Foreign],
    path: &str,
    pos: impl Fn(usize) -> (usize, usize),
) -> String {
    let by_name: HashMap<&str, &Foreign> = foreigns.iter().map(|f| (f.name.as_str(), f)).collect();
    let mut sites = Vec::new();
    for f in &user.funcs {
        walk_func(f, &f.name, &by_name, &mut HashSet::new(), &mut sites);
    }
    sites.sort_by_key(|s| s.span.0);

    let mut counts: HashMap<&str, usize> = HashMap::new();
    for s in &sites {
        *counts.entry(s.name.as_str()).or_default() += 1;
    }
    let mut imports: Vec<&Foreign> = foreigns.iter().collect();
    imports.sort_by(|a, b| a.name.cmp(&b.name));
    let pure = imports.iter().filter(|f| f.pure).count();
    let unused = imports
        .iter()
        .filter(|f| !counts.contains_key(f.name.as_str()))
        .count();

    let mut out = String::new();
    out.push_str(&format!(
        "imports: {} ({} pure, {} never mentioned)\n",
        imports.len(),
        pure,
        unused
    ));
    for f in &imports {
        let lib = f.lib.as_deref().unwrap_or("(already loaded)");
        out.push_str(&format!(
            "  {} = {} from {} :: {}  {}  sites: {}\n",
            f.name,
            f.c_symbol(),
            lib,
            signature(&f.sig),
            if f.pure { "pure" } else { "effect" },
            counts.get(f.name.as_str()).copied().unwrap_or(0)
        ));
    }
    out.push_str(&format!("sites: {}\n", sites.len()));
    for s in &sites {
        let (l, c) = pos(s.span.0);
        let f = by_name[s.name.as_str()];
        let arity = f.sig.param_types().len();
        let how = if s.applied == 0 {
            "passed as a value".to_string()
        } else if s.applied < arity {
            format!("partial {}/{}", s.applied, arity)
        } else {
            "call".to_string()
        };
        out.push_str(&format!(
            "  {path}:{l}:{c}  in {}  {} ({})  {}\n",
            s.func,
            s.name,
            f.c_symbol(),
            how
        ));
    }
    out
}

/// Whether the user's code mentions the import `name` anywhere (shadowing respected).
pub fn mentions(user: &Module, name: &str) -> bool {
    let probe = Foreign {
        name: name.to_string(),
        symbol: None,
        sig: Type::Unit,
        lib: None,
        pure: false,
        span: (0, 0),
    };
    let by_name: HashMap<&str, &Foreign> = HashMap::from([(name, &probe)]);
    let mut sites = Vec::new();
    for f in &user.funcs {
        walk_func(f, &f.name, &by_name, &mut HashSet::new(), &mut sites);
    }
    !sites.is_empty()
}

/// `own String -> borrow (Handle Ren) -> Int -> Int`: each parameter with its ownership
/// spelled out. An unwrapped heap parameter is borrowed (the caller keeps and frees it), so
/// it is printed `borrow` too; scalars (`Int`/`Float`/`Bool`/`Ptr`) carry no ownership.
fn signature(t: &Type) -> String {
    let mut parts = Vec::new();
    let mut t = t;
    while let Type::Arrow { from, to, .. } = t {
        let (own, inner) = from.ffi_ownership();
        let scalar = matches!(inner.head_con(), Some("Int" | "Float" | "Bool" | "Ptr"));
        let ty = fmt_atom(inner);
        parts.push(if scalar {
            ty
        } else if own {
            format!("own {ty}")
        } else {
            format!("borrow {ty}")
        });
        t = to;
    }
    parts.push(fmt_type(t.ffi_ownership().1));
    parts.join(" -> ")
}

fn fmt_type(t: &Type) -> String {
    match t {
        Type::Con(n) | Type::Var(n) => n.clone(),
        Type::Unit => "()".to_string(),
        Type::Tuple(ts) => format!(
            "({})",
            ts.iter().map(fmt_type).collect::<Vec<_>>().join(", ")
        ),
        Type::App(f, x) => format!("{} {}", fmt_type(f), fmt_atom(x)),
        Type::Arrow { from, to, .. } => {
            let from = match **from {
                Type::Arrow { .. } => format!("({})", fmt_type(from)),
                _ => fmt_type(from),
            };
            format!("{from} -> {}", fmt_type(to))
        }
    }
}

fn fmt_atom(t: &Type) -> String {
    match t {
        Type::App(..) | Type::Arrow { .. } => format!("({})", fmt_type(t)),
        _ => fmt_type(t),
    }
}

fn walk_func(
    f: &Func,
    owner: &str,
    ffi: &HashMap<&str, &Foreign>,
    bound: &mut HashSet<String>,
    out: &mut Vec<Site>,
) {
    for c in &f.clauses {
        let mut b = bound.clone();
        for p in &c.pats {
            bind_pat(p, &mut b);
        }
        for w in &c.wher {
            b.insert(w.name.clone());
        }
        for w in &c.wher {
            walk_func(w, &format!("{owner}.{}", w.name), ffi, &mut b.clone(), out);
        }
        match &c.body {
            Body::Plain(e) => walk(e, owner, ffi, &b, out),
            Body::Guarded(arms) => {
                for (g, r) in arms {
                    walk(g, owner, ffi, &b, out);
                    walk(r, owner, ffi, &b, out);
                }
            }
        }
    }
}

fn bind_pat(p: &Pat, b: &mut HashSet<String>) {
    match p {
        Pat::Var(n, _) => {
            b.insert(n.clone());
        }
        Pat::Con(_, ps, _) | Pat::Tuple(ps, _) => {
            for p in ps {
                bind_pat(p, b);
            }
        }
        Pat::Wild(_) | Pat::Int(..) | Pat::Str(..) => {}
    }
}

/// The site for a mention of `name` at `span`, if it names an import not shadowed here.
fn site(
    name: &str,
    span: Span,
    applied: usize,
    owner: &str,
    ffi: &HashMap<&str, &Foreign>,
    bound: &HashSet<String>,
) -> Option<Site> {
    (ffi.contains_key(name) && !bound.contains(name)).then(|| Site {
        func: owner.to_string(),
        span,
        name: name.to_string(),
        applied,
    })
}

fn walk(
    e: &Expr,
    owner: &str,
    ffi: &HashMap<&str, &Foreign>,
    bound: &HashSet<String>,
    out: &mut Vec<Site>,
) {
    match e {
        Expr::Int(..) | Expr::Float(..) | Expr::Str(..) | Expr::Con(..) => {}
        Expr::Var(n, sp) => out.extend(site(n, *sp, 0, owner, ffi, bound)),
        Expr::App(..) => {
            // Flatten the spine so `f a b` is one site applied to two arguments.
            let mut args = Vec::new();
            let mut head = e;
            while let Expr::App(f, a, _) = head {
                args.push(&**a);
                head = f;
            }
            match head {
                Expr::Var(n, sp) => out.extend(site(n, *sp, args.len(), owner, ffi, bound)),
                other => walk(other, owner, ffi, bound, out),
            }
            for a in args {
                walk(a, owner, ffi, bound, out);
            }
        }
        Expr::BinOp(op, l, r, sp) => {
            // a backtick-infix call: ``a `cfoo` b``
            out.extend(site(op, *sp, 2, owner, ffi, bound));
            walk(l, owner, ffi, bound, out);
            walk(r, owner, ffi, bound, out);
        }
        Expr::If(c, t, f, _) => {
            walk(c, owner, ffi, bound, out);
            walk(t, owner, ffi, bound, out);
            walk(f, owner, ffi, bound, out);
        }
        Expr::Let(fs, body, _) => {
            let mut b = bound.clone();
            for f in fs {
                b.insert(f.name.clone());
            }
            for f in fs {
                walk_func(f, owner, ffi, &mut b.clone(), out);
            }
            walk(body, owner, ffi, &b, out);
        }
        Expr::Case(s, alts, _) => {
            walk(s, owner, ffi, bound, out);
            for (p, a) in alts {
                let mut b = bound.clone();
                bind_pat(p, &mut b);
                walk(a, owner, ffi, &b, out);
            }
        }
        Expr::Tuple(es, _) => {
            for x in es {
                walk(x, owner, ffi, bound, out);
            }
        }
        Expr::RecordCon(_, fs, _) => {
            for (_, x) in fs {
                walk(x, owner, ffi, bound, out);
            }
        }
        Expr::RecordUpd(base, fs, _) => {
            walk(base, owner, ffi, bound, out);
            for (_, x) in fs {
                walk(x, owner, ffi, bound, out);
            }
        }
        Expr::Lam(ps, body, _) => {
            let mut b = bound.clone();
            for p in ps {
                bind_pat(p, &mut b);
            }
            walk(body, owner, ffi, &b, out);
        }
    }
}
