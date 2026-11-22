//! Parallel loops (`parFor`, `docs/parallel.md`): the front-end rules that make a parallel run
//! give the same result as the sequential one.
//!
//! `parFor a k` replaces every element `i` of `a` by `k i a[i]`, the indices split among threads.
//! Each element is written by exactly one thread and the array itself is consumed at the call
//! (the linear checker, like `setArray`), so the kernel cannot see it. What is left to rule out is
//! the kernel doing something whose order shows: an effect (I/O, exiting, a channel or session
//! operation, spawning) or an in-place write to something it captured (a `Buffer` poke, an
//! arena). This module refuses those (AX0800), looking into the kernel's body and, transitively,
//! the functions it calls by name; and it refuses a `parFor` not applied to both of its arguments
//! (AX0801), whose kernel could not be looked at.

use crate::ast::{Body, Expr, Module};
use crate::check::{collect_func_refs, collect_pat_vars, collect_refs, Effects};
use crate::diag::{Diagnostic, Diagnostics};
use std::collections::{HashMap, HashSet};

/// Built-ins a kernel may not use beyond the effects of [`Effects`]: session and channel
/// operations, nested concurrency, and the ones that write in place through a borrow.
const NOT_IN_KERNEL: &[&str] = &[
    "spawn",
    "send",
    "recv",
    "close",
    "newChannel",
    "select",
    "offer",
    "cancel",
    "bound",
    "parMap",
    "connect",
    "pipe3",
    "pokeU8",
    "pokeU16",
    "pokeU32",
    "pokeU64",
    "pokeF64",
    "bufIota",
    "xorInPlace",
    "free",
    "withArena",
    "withSubArena",
    "allocateCell",
    "promote",
    "arena_mark",
    "arena_release",
];

/// For each top-level function that may not run in a kernel: the name it uses that is the
/// reason (a built-in, or the next function on the way to one).
fn unsafe_functions(module: &Module, effects: &Effects) -> HashMap<String, String> {
    let refs: Vec<(&str, HashSet<String>)> = module
        .funcs
        .iter()
        .map(|f| {
            let mut r = HashSet::new();
            collect_func_refs(f, &mut r);
            (f.name.as_str(), r)
        })
        .collect();
    let mut bad: HashMap<String, String> = HashMap::new();
    loop {
        let mut grew = false;
        for (name, r) in &refs {
            if bad.contains_key(*name) {
                continue;
            }
            let mut why: Vec<&String> = r
                .iter()
                .filter(|n| direct(n, effects) || bad.contains_key(n.as_str()))
                .collect();
            why.sort();
            if let Some(w) = why.first() {
                bad.insert((*name).to_string(), (*w).clone());
                grew = true;
            }
        }
        if !grew {
            return bad;
        }
    }
}

/// A built-in or `foreign` import a kernel may not use. (`Effects` also names the module's
/// effectful functions: those are in [`unsafe_functions`] too, which shows the way to the effect.)
fn direct(name: &str, effects: &Effects) -> bool {
    NOT_IN_KERNEL.contains(&name) || effects.contains(name)
}

struct Cx<'a> {
    /// the module's top-level names (a kernel's other free names are captured locals)
    globals: HashSet<String>,
    bad: HashMap<String, String>,
    effects: &'a Effects,
    diags: &'a mut Diagnostics,
}

/// Checks every `parFor` in the module (AX0800, AX0801).
pub fn check(module: &Module, diags: &mut Diagnostics) {
    if !mentions_par_for(module) {
        return;
    }
    let effects = Effects::of(module);
    let mut cx = Cx {
        globals: module.funcs.iter().map(|f| f.name.clone()).collect(),
        bad: unsafe_functions(module, &effects),
        effects: &effects,
        diags,
    };
    for f in &module.funcs {
        cx.func(f);
    }
}

fn mentions_par_for(module: &Module) -> bool {
    module.funcs.iter().any(|f| {
        let mut r = HashSet::new();
        collect_func_refs(f, &mut r);
        r.contains("parFor")
    })
}

impl Cx<'_> {
    fn func(&mut self, f: &crate::ast::Func) {
        for c in &f.clauses {
            self.body(&c.body);
            for w in &c.wher {
                self.func(w);
            }
        }
    }

    fn body(&mut self, b: &Body) {
        match b {
            Body::Plain(e) => self.expr(e, 0),
            Body::Guarded(arms) => {
                for (g, r) in arms {
                    self.expr(g, 0);
                    self.expr(r, 0);
                }
            }
        }
    }

    /// `applied`: how many arguments the enclosing applications give `e`.
    fn expr(&mut self, e: &Expr, applied: usize) {
        match e {
            Expr::Var(n, span) if n == "parFor" && applied < 2 => {
                self.diags.push(
                    Diagnostic::error(
                        "AX0801",
                        "`parFor` must be applied to its array and its kernel".to_string(),
                    )
                    .label(span.0, span.1, "used here without both arguments")
                    .with_help(
                        "write the call out, `parFor a (\\i x -> …)`, so the kernel can be \
                         checked: a kernel must not have effects (see docs/parallel.md)",
                    ),
                );
            }
            Expr::Var(..) | Expr::Int(..) | Expr::Float(..) | Expr::Str(..) | Expr::Con(..) => {}
            Expr::App(f, x, _) => {
                if applied == 0 {
                    let mut args = vec![&**x];
                    let mut head = &**f;
                    while let Expr::App(g, y, _) = head {
                        args.push(y);
                        head = g;
                    }
                    args.reverse();
                    if matches!(head, Expr::Var(n, _) if n == "parFor") && args.len() >= 2 {
                        self.kernel(args[1]);
                    }
                }
                self.expr(f, applied + 1);
                self.expr(x, 0);
            }
            Expr::BinOp(_, a, b, _) => {
                self.expr(a, 0);
                self.expr(b, 0);
            }
            Expr::If(c, t, el, _) => {
                self.expr(c, 0);
                self.expr(t, 0);
                self.expr(el, 0);
            }
            Expr::Let(binds, body, _) => {
                for b in binds {
                    self.func(b);
                }
                self.expr(body, 0);
            }
            Expr::Case(s, arms, _) => {
                self.expr(s, 0);
                for (_, a) in arms {
                    self.expr(a, 0);
                }
            }
            Expr::Tuple(es, _) => es.iter().for_each(|x| self.expr(x, 0)),
            Expr::RecordCon(_, fs, _) => fs.iter().for_each(|(_, x)| self.expr(x, 0)),
            Expr::RecordUpd(base, fs, _) => {
                self.expr(base, 0);
                fs.iter().for_each(|(_, x)| self.expr(x, 0));
            }
            Expr::Lam(_, body, _) => self.expr(body, 0),
        }
    }

    /// A captured array the kernel `k` writes in place: (the array, the writer, where).
    fn writes_capture(&self, k: &Expr) -> Option<(String, String, crate::ast::Span)> {
        let mut bound = HashSet::new();
        binders(k, &mut bound);
        // a `let c = cap` inside the kernel names the captured array too
        let mut renames = Vec::new();
        let_renames(k, &mut renames);
        loop {
            let before = bound.len();
            for (name, of) in &renames {
                if !bound.contains(of) && !self.globals.contains(of) {
                    bound.remove(name);
                }
            }
            if bound.len() == before {
                break;
            }
        }
        find_write(k, &bound, &self.globals)
    }

    /// AX0800: the kernel `k` of a `parFor` uses something whose order would show.
    fn kernel(&mut self, k: &Expr) {
        if let Some((v, w, span)) = self.writes_capture(k) {
            self.diags.push(
                Diagnostic::error(
                    "AX0800",
                    format!(
                        "a `parFor` kernel must not write what it captured: `{w}` writes `{v}` \
                         in place"
                    ),
                )
                .label(
                    span.0,
                    span.1,
                    "every run of the kernel would write the same array",
                )
                .with_help(format!(
                    "the kernel runs once per element, on several threads at once, and every \
                     run sees the same captured `{v}`: writing it in place is a data race. \
                     Read it (`getArray`), or build a fresh array inside the kernel."
                )),
            );
            return;
        }
        let mut refs = HashSet::new();
        collect_refs(k, &mut refs);
        let mut refs: Vec<String> = refs.into_iter().collect();
        refs.sort();
        for r in refs {
            let reason = if direct(&r, self.effects) && !self.bad.contains_key(&r) {
                Some(format!("`{r}`, which {}", describe(&r)))
            } else {
                self.bad.get(&r).map(|_| {
                    let mut chain = vec![r.clone()];
                    let mut at = r.clone();
                    while let Some(next) = self.bad.get(&at) {
                        if chain.contains(next) || chain.len() > 8 {
                            break;
                        }
                        chain.push(next.clone());
                        at = next.clone();
                    }
                    let last = chain.last().cloned().unwrap_or_default();
                    let via = chain
                        .iter()
                        .map(|n| format!("`{n}`"))
                        .collect::<Vec<_>>()
                        .join(" → ");
                    format!("{via}, which {}", describe(&last))
                })
            };
            if let Some(why) = reason {
                let s = k.span();
                self.diags.push(
                    Diagnostic::error(
                        "AX0800",
                        format!("a `parFor` kernel must not have effects: it uses {why}"),
                    )
                    .label(s.0, s.1, "this kernel runs on several threads at once")
                    .with_help(
                        "the kernel runs once per element, on several threads, in no fixed \
                         order: it may compute, allocate and read what it captures, but not do \
                         I/O, exit, use channels or sessions, or write a Buffer or arena in \
                         place. Compute the values with `parFor`, then do the effects after it \
                         (see docs/parallel.md).",
                    ),
                );
                return;
            }
        }
    }
}

/// Built-ins that write their first argument (an array) in place.
fn writes_in_place(name: &str) -> bool {
    matches!(
        name,
        "setArray" | "setI8" | "setI32" | "setTritVec" | "parFor"
    ) || (name.starts_with("store") && crate::simd::builtin(name).is_some())
}

/// Every name bound inside `e`: lambda and `case` patterns, `let` names and their parameters.
fn binders(e: &Expr, out: &mut HashSet<String>) {
    match e {
        Expr::Var(..) | Expr::Int(..) | Expr::Float(..) | Expr::Str(..) | Expr::Con(..) => {}
        Expr::App(a, b, _) | Expr::BinOp(_, a, b, _) => {
            binders(a, out);
            binders(b, out);
        }
        Expr::If(c, t, el, _) => {
            binders(c, out);
            binders(t, out);
            binders(el, out);
        }
        Expr::Let(binds, body, _) => {
            for f in binds {
                out.insert(f.name.clone());
                for c in &f.clauses {
                    c.pats.iter().for_each(|p| collect_pat_vars(p, out));
                    match &c.body {
                        Body::Plain(e) => binders(e, out),
                        Body::Guarded(arms) => arms.iter().for_each(|(g, r)| {
                            binders(g, out);
                            binders(r, out);
                        }),
                    }
                }
            }
            binders(body, out);
        }
        Expr::Case(s, arms, _) => {
            binders(s, out);
            for (p, a) in arms {
                collect_pat_vars(p, out);
                binders(a, out);
            }
        }
        Expr::Tuple(es, _) => es.iter().for_each(|x| binders(x, out)),
        Expr::RecordCon(_, fs, _) => fs.iter().for_each(|(_, x)| binders(x, out)),
        Expr::RecordUpd(base, fs, _) => {
            binders(base, out);
            fs.iter().for_each(|(_, x)| binders(x, out));
        }
        Expr::Lam(pats, body, _) => {
            pats.iter().for_each(|p| collect_pat_vars(p, out));
            binders(body, out);
        }
    }
}

/// Every `let c = v` (a plain rename) in `e`, as `(c, v)`.
fn let_renames(e: &Expr, out: &mut Vec<(String, String)>) {
    let mut each = |x: &Expr| let_renames(x, out);
    match e {
        Expr::Var(..) | Expr::Int(..) | Expr::Float(..) | Expr::Str(..) | Expr::Con(..) => {}
        Expr::App(a, b, _) | Expr::BinOp(_, a, b, _) => {
            each(a);
            each(b);
        }
        Expr::If(c, t, el, _) => {
            each(c);
            each(t);
            each(el);
        }
        Expr::Let(binds, body, _) => {
            for f in binds {
                for c in &f.clauses {
                    match &c.body {
                        Body::Plain(Expr::Var(v, _)) if c.pats.is_empty() => {
                            out.push((f.name.clone(), v.clone()));
                        }
                        Body::Plain(x) => let_renames(x, out),
                        Body::Guarded(arms) => arms.iter().for_each(|(g, r)| {
                            let_renames(g, out);
                            let_renames(r, out);
                        }),
                    }
                }
            }
            let_renames(body, out);
        }
        Expr::Case(s, arms, _) => {
            let_renames(s, out);
            arms.iter().for_each(|(_, a)| let_renames(a, out));
        }
        Expr::Tuple(es, _) => es.iter().for_each(|x| let_renames(x, out)),
        Expr::RecordCon(_, fs, _) => fs.iter().for_each(|(_, x)| let_renames(x, out)),
        Expr::RecordUpd(base, fs, _) => {
            let_renames(base, out);
            fs.iter().for_each(|(_, x)| let_renames(x, out));
        }
        Expr::Lam(_, body, _) => let_renames(body, out),
    }
}

/// The first `w v …` in `e` where `w` writes in place and `v` is not in `bound` or `globals`.
fn find_write<'e>(
    e: &'e Expr,
    bound: &HashSet<String>,
    globals: &HashSet<String>,
) -> Option<(String, String, crate::ast::Span)> {
    if let Expr::App(..) = e {
        let mut args = Vec::new();
        let mut head = e;
        while let Expr::App(g, y, _) = head {
            args.push(&**y);
            head = g;
        }
        if let (Expr::Var(w, _), Some(Expr::Var(v, _))) = (head, args.last()) {
            if writes_in_place(w) && !bound.contains(v) && !globals.contains(v) {
                return Some((v.clone(), w.clone(), e.span()));
            }
        }
    }
    let go = |x: &'e Expr| find_write(x, bound, globals);
    match e {
        Expr::Var(..) | Expr::Int(..) | Expr::Float(..) | Expr::Str(..) | Expr::Con(..) => None,
        Expr::App(a, b, _) | Expr::BinOp(_, a, b, _) => go(a).or_else(|| go(b)),
        Expr::If(c, t, el, _) => go(c).or_else(|| go(t)).or_else(|| go(el)),
        Expr::Let(binds, body, _) => binds
            .iter()
            .flat_map(|f| &f.clauses)
            .find_map(|c| match &c.body {
                Body::Plain(e) => go(e),
                Body::Guarded(arms) => arms.iter().find_map(|(g, r)| go(g).or_else(|| go(r))),
            })
            .or_else(|| go(body)),
        Expr::Case(s, arms, _) => go(s).or_else(|| arms.iter().find_map(|(_, a)| go(a))),
        Expr::Tuple(es, _) => es.iter().find_map(go),
        Expr::RecordCon(_, fs, _) => fs.iter().find_map(|(_, x)| go(x)),
        Expr::RecordUpd(base, fs, _) => go(base).or_else(|| fs.iter().find_map(|(_, x)| go(x))),
        Expr::Lam(_, body, _) => go(body),
    }
}

/// What a built-in a kernel may not use does (completes "…, which ").
fn describe(name: &str) -> &'static str {
    match name {
        "pokeU8" | "pokeU16" | "pokeU32" | "pokeU64" | "pokeF64" | "bufIota" | "xorInPlace"
        | "free" => "writes a Buffer in place",
        "withArena" | "withSubArena" | "allocateCell" | "promote" | "arena_mark"
        | "arena_release" => "is an arena operation",
        n if NOT_IN_KERNEL.contains(&n) => "is a concurrency operation",
        _ => "has effects",
    }
}
