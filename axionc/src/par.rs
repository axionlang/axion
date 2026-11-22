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
    /// every named function (top-level and `where`), for the GPU subset check
    funcs: HashMap<String, &'a crate::ast::Func>,
    bad: HashMap<String, String>,
    effects: &'a Effects,
    diags: &'a mut Diagnostics,
}

/// The built-ins that run a kernel over an array: `parFor` (threads) and `gpuFor` (the GPU).
const LOOPS: &[&str] = &["parFor", "gpuFor"];

/// Checks every `parFor` and `gpuFor` in the module (AX0800, AX0801, AX0802).
pub fn check(module: &Module, diags: &mut Diagnostics) {
    if !mentions_par_for(module) {
        return;
    }
    let effects = Effects::of(module);
    let mut funcs = HashMap::new();
    fn add<'m>(f: &'m crate::ast::Func, out: &mut HashMap<String, &'m crate::ast::Func>) {
        out.entry(f.name.clone()).or_insert(f);
        for c in &f.clauses {
            for w in &c.wher {
                add(w, out);
            }
        }
    }
    for f in &module.funcs {
        add(f, &mut funcs);
    }
    let mut cx = Cx {
        globals: module.funcs.iter().map(|f| f.name.clone()).collect(),
        funcs,
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
        LOOPS.iter().any(|l| r.contains(*l))
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
            Expr::Var(n, span) if LOOPS.contains(&n.as_str()) && applied < 2 => {
                self.diags.push(
                    Diagnostic::error(
                        "AX0801",
                        format!("`{n}` must be applied to its array and its kernel"),
                    )
                    .label(span.0, span.1, "used here without both arguments")
                    .with_help(format!(
                        "write the call out, `{n} a (\\i x -> …)`, so the kernel can be \
                         checked: a kernel must not have effects (see docs/parallel.md)"
                    )),
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
                    if let Expr::Var(n, _) = head {
                        if LOOPS.contains(&n.as_str()) && args.len() >= 2 {
                            let n = n.clone();
                            if self.kernel(&n, args[1]) && n == "gpuFor" {
                                self.gpu_kernel(args[1]);
                            }
                        }
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

    /// AX0800: the kernel `k` of a `parFor`/`gpuFor` (`lp`) uses something whose order would
    /// show. Returns whether it passed.
    fn kernel(&mut self, lp: &str, k: &Expr) -> bool {
        if let Some((v, w, span)) = self.writes_capture(k) {
            self.diags.push(
                Diagnostic::error(
                    "AX0800",
                    format!(
                        "a `{lp}` kernel must not write what it captured: `{w}` writes `{v}` in \
                         place"
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
            return false;
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
                        format!("a `{lp}` kernel must not have effects: it uses {why}"),
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
                return false;
            }
        }
        true
    }

    /// AX0802: the kernel of a `gpuFor` uses something the GPU cannot run.
    fn gpu_kernel(&mut self, k: &Expr) {
        let mut g = Gpu {
            funcs: &self.funcs,
            checked: HashMap::new(),
            builtins: None,
        };
        let locals = HashSet::new();
        let found = match k {
            Expr::Lam(ps, body, _) => g.lambda(ps, body, &locals),
            Expr::Var(f, sp) => g.call(f, *sp),
            other => g.expr(other, &locals),
        };
        if let Some(v) = found {
            let s = k.span();
            let via = if v.via.is_empty() {
                String::new()
            } else {
                let names: Vec<String> = v.via.iter().map(|n| format!("`{n}`")).collect();
                format!(", in {}", names.join(" → "))
            };
            self.diags.push(
                Diagnostic::error(
                    "AX0802",
                    format!(
                        "a `gpuFor` kernel must run on the GPU: it uses {}{via}",
                        v.what
                    ),
                )
                .label(v.span.0, v.span.1, "this cannot run on the GPU")
                .label(s.0, s.1, "in this kernel")
                .with_help(
                    "a GPU kernel computes with `Int`, `Float` and `Bool` values: arithmetic, \
                     comparisons, `if`, `case` on numbers, `let`, `getArray`/`lenArray` on the \
                     arrays it captures, and calls to functions that do the same. It cannot use \
                     strings, lists, tuples, records or other `data` values, or function \
                     values. Use `parFor` for a kernel that needs them (see docs/gpu.md).",
                ),
            );
        }
    }
}

/// What a GPU kernel may not use, and where.
struct Unfit {
    what: String,
    span: crate::ast::Span,
    /// the named functions on the way to it, outermost first
    via: Vec<String>,
}

/// Built-ins a GPU kernel may use (besides arithmetic and comparison operators).
const GPU_BUILTINS: &[&str] = &[
    "getArray",
    "lenArray",
    "toFloat",
    "truncate",
    "sqrt",
    "floor",
    "abs",
    "div",
    "mod",
    "not",
    "otherwise", // the built-in classes' methods: primitive on `Int`/`Float`
    "le",
    "eq",
    "fromInteger",
    // 32-bit numbers (`num32.rs`), but not `showFloat32` (a String)
    "toInt32",
    "fromInt32",
    "toFloat32",
    "fromFloat32",
    "int32ToFloat32",
    "truncateF32",
    "sqrtF32",
];

/// The standard operators: primitive on `Int`, `Float` and `Bool` (the prelude defines some of
/// them through a class, which on a data type the check of the final Core sees, `gpu.rs`).
const STD_OPS: &[&str] = &[
    "+", "-", "*", "/", "==", "/=", "<", "<=", ">", ">=", "&&", "||", "+.", "-.", "*.", "/.", "<.",
    ">.", "<=.", ">=.", "==.", ".&.", ".|.", "xor", "shiftL", "shiftR", "mod", "div",
];

struct Gpu<'a, 'f> {
    funcs: &'a HashMap<String, &'f crate::ast::Func>,
    /// functions already checked: `None` fits (or is being checked), `Some` does not
    checked: HashMap<String, Option<Box<Unfit>>>,
    /// the built-in names, when first needed
    builtins: Option<HashSet<String>>,
}

fn unfit(what: impl Into<String>, span: crate::ast::Span) -> Unfit {
    Unfit {
        what: what.into(),
        span,
        via: Vec::new(),
    }
}

impl Gpu<'_, '_> {
    fn pat(p: &crate::ast::Pat) -> Option<Unfit> {
        use crate::ast::Pat;
        match p {
            Pat::Wild(_) | Pat::Var(..) | Pat::Int(..) => None,
            Pat::Con(c, ps, _) if (c == "True" || c == "False") && ps.is_empty() => None,
            Pat::Con(c, _, sp) => Some(unfit(format!("a pattern on the data value `{c}`"), *sp)),
            Pat::Str(_, sp) => Some(unfit("a String pattern", *sp)),
            Pat::Tuple(_, sp) => Some(unfit("a tuple pattern", *sp)),
        }
    }

    fn lambda(
        &mut self,
        ps: &[crate::ast::Pat],
        body: &Expr,
        locals: &HashSet<String>,
    ) -> Option<Unfit> {
        let mut inner = locals.clone();
        for p in ps {
            if let Some(u) = Self::pat(p) {
                return Some(u);
            }
            collect_pat_vars(p, &mut inner);
        }
        self.expr(body, &inner)
    }

    /// A named function the kernel calls: it must fit too.
    fn call(&mut self, f: &str, sp: crate::ast::Span) -> Option<Unfit> {
        if GPU_BUILTINS.contains(&f) || STD_OPS.contains(&f) {
            return None;
        }
        let Some(func) = self.funcs.get(f).copied() else {
            // a built-in, or a function value the kernel captured
            let builtins = self
                .builtins
                .get_or_insert_with(|| crate::infer::builtin_sigs().into_keys().collect());
            return if builtins.contains(f) {
                Some(unfit(format!("`{f}`, which cannot run on the GPU"), sp))
            } else {
                Some(unfit(
                    format!("a call through the function value `{f}`"),
                    sp,
                ))
            };
        };
        if let Some(r) = self.checked.get(f) {
            return r.as_ref().map(|u| Unfit {
                what: u.what.clone(),
                span: u.span,
                via: std::iter::once(f.to_string())
                    .chain(u.via.clone())
                    .collect(),
            });
        }
        self.checked.insert(f.to_string(), None);
        let mut found = None;
        'clauses: for c in &func.clauses {
            let mut locals = HashSet::new();
            for p in &c.pats {
                if let Some(u) = Self::pat(p) {
                    found = Some(u);
                    break 'clauses;
                }
                collect_pat_vars(p, &mut locals);
            }
            for w in &c.wher {
                locals.insert(w.name.clone());
            }
            let r = match &c.body {
                Body::Plain(e) => self.expr(e, &locals),
                Body::Guarded(arms) => arms
                    .iter()
                    .find_map(|(g, r)| self.expr(g, &locals).or_else(|| self.expr(r, &locals))),
            };
            if r.is_some() {
                found = r;
                break;
            }
            for w in &c.wher {
                if let Some(u) = self.call(&w.name, w.span) {
                    found = Some(u);
                    break 'clauses;
                }
            }
        }
        let found = found.map(|mut u| {
            u.via.insert(0, f.to_string());
            u
        });
        self.checked.insert(
            f.to_string(),
            found.as_ref().map(|u| {
                Box::new(Unfit {
                    what: u.what.clone(),
                    span: u.span,
                    via: u.via[1..].to_vec(),
                })
            }),
        );
        found
    }

    fn expr(&mut self, e: &Expr, locals: &HashSet<String>) -> Option<Unfit> {
        match e {
            Expr::Int(..) | Expr::Float(..) => None,
            Expr::Str(_, sp) => Some(unfit("a String", *sp)),
            Expr::Con(c, sp) => {
                if c == "True" || c == "False" {
                    None
                } else {
                    Some(unfit(format!("the data value `{c}`"), *sp))
                }
            }
            // a local, or a value the kernel captured (what the device then does with it is
            // checked again on the final Core, `gpu.rs`)
            Expr::Var(v, sp) => {
                if !locals.contains(v) && self.funcs.contains_key(v) {
                    Some(unfit(format!("`{v}` as a function value"), *sp))
                } else {
                    None
                }
            }
            Expr::App(..) => {
                let mut args = Vec::new();
                let mut h = e;
                while let Expr::App(f, a, _) = h {
                    args.push(&**a);
                    h = f;
                }
                let head = match h {
                    Expr::Var(f, sp) if locals.contains(f) => Some(unfit(
                        format!("a call through the function value `{f}`"),
                        *sp,
                    )),
                    Expr::Var(f, sp) => self.call(f, *sp),
                    Expr::Con(c, sp) => Some(unfit(format!("the data value `{c}`"), *sp)),
                    other => Some(unfit("a call through a function value", other.span())),
                };
                head.or_else(|| args.iter().rev().find_map(|a| self.expr(a, locals)))
            }
            Expr::BinOp(op, a, b, sp) => {
                // an operator a program defines is a function like any other
                let user = if self.funcs.contains_key(op) && !STD_OPS.contains(&op.as_str()) {
                    self.call(op, *sp)
                } else {
                    None
                };
                user.or_else(|| self.expr(a, locals))
                    .or_else(|| self.expr(b, locals))
            }
            // a contract checked at run time (`contracts.rs`): its failure branch only builds the
            // message and aborts — on the device it traps, and the loop reruns on the CPU
            Expr::If(c, t, f, _) => {
                let fails = matches!(&**f, Expr::App(h, _, _)
                    if matches!(&**h, Expr::Var(n, _) if n == crate::contracts::FAIL));
                self.expr(c, locals)
                    .or_else(|| self.expr(t, locals))
                    .or_else(|| if fails { None } else { self.expr(f, locals) })
            }
            Expr::Let(binds, body, _) => {
                let mut inner = locals.clone();
                for b in binds {
                    inner.insert(b.name.clone());
                }
                for b in binds {
                    for c in &b.clauses {
                        let mut l = inner.clone();
                        for p in &c.pats {
                            if let Some(u) = Self::pat(p) {
                                return Some(u);
                            }
                            collect_pat_vars(p, &mut l);
                        }
                        let r = match &c.body {
                            Body::Plain(e) => self.expr(e, &l),
                            Body::Guarded(arms) => arms
                                .iter()
                                .find_map(|(g, r)| self.expr(g, &l).or_else(|| self.expr(r, &l))),
                        };
                        if r.is_some() {
                            return r;
                        }
                    }
                }
                self.expr(body, &inner)
            }
            Expr::Case(scrut, arms, _) => {
                if let Some(u) = self.expr(scrut, locals) {
                    return Some(u);
                }
                for (p, a) in arms {
                    if let Some(u) = Self::pat(p) {
                        return Some(u);
                    }
                    let mut l = locals.clone();
                    collect_pat_vars(p, &mut l);
                    if let Some(u) = self.expr(a, &l) {
                        return Some(u);
                    }
                }
                None
            }
            Expr::Tuple(_, sp) => Some(unfit("a tuple", *sp)),
            Expr::RecordCon(c, _, sp) => Some(unfit(format!("the record `{c}`"), *sp)),
            Expr::RecordUpd(_, _, sp) => Some(unfit("a record update", *sp)),
            Expr::Lam(_, _, sp) => Some(unfit("a function value (a lambda)", *sp)),
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
