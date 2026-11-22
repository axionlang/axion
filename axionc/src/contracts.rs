//! Contracts (docs/contracts.md): `{-# CONTRACT f requires P ensures Q #-}`.
//!
//! A contract is a refinement (`refine.rs`) that is allowed to fall back to a run-time check.
//! Its `requires` predicates are proven at each call and its `ensures` predicates at each return,
//! by the same certificate-checked procedure as refinements. What is proven costs nothing; what
//! is not is checked where it is needed:
//!
//! - a `requires` not proven at a call is checked there, before the call;
//! - an `ensures` not proven over the body is checked after each call from outside the function
//!   (a call from inside its own body is not checked, so a loop stays a loop, and the checker
//!   does not assume the `ensures` of such a call: `lib.rs` runs it a second time without);
//! - the function used as a value becomes a lambda that checks both.
//!
//! A failed check aborts with a message naming the function, the predicate, the values, and the
//! caller (`contractFailed`, like a failed bounds check).

use crate::ast::{Body, Clause, Contract, Expr, Func, Module, Pat, RefinePred, Refinement, Span};
use crate::diag::{Diagnostic, Diagnostics};
use std::collections::{HashMap, HashSet};

/// The run-time check of a contract that was not proven: a call to this aborts with its message.
pub const FAIL: &str = "contractFailed";

// ─── the pragma ──────────────────────────────────────────────────────────────────────────────

/// Every `{-# CONTRACT f requires … ensures … #-}` in `src`. A malformed one is AX0603.
pub fn scan(src: &str, diags: &mut Diagnostics) -> Vec<Contract> {
    let mut out = Vec::new();
    let mut at = 0;
    while let Some(rel) = src.get(at..).and_then(|r| r.find("{-#")) {
        let start = at + rel + 3;
        let Some(end) = src
            .get(start..)
            .and_then(|r| r.find("#-}"))
            .map(|e| start + e)
        else {
            break;
        };
        at = end + 3;
        let inner = src.get(start..end).unwrap_or("");
        let lead = inner.len() - inner.trim_start().len();
        if !inner.trim_start().starts_with("CONTRACT")
            || !inner
                .trim_start()
                .get(8..)
                .is_some_and(|r| r.starts_with(char::is_whitespace))
        {
            continue;
        }
        let words = start + lead + 8;
        let bad = |diags: &mut Diagnostics, sp: Span, msg: &str| {
            diags.push(
                Diagnostic::error("AX0603", format!("malformed contract: {msg}"))
                    .label(sp.0, sp.1, "in this pragma")
                    .with_help(
                        "write `{-# CONTRACT f requires <predicate> ensures <predicate> #-}`, with \
                         any number of `requires` and `ensures` clauses (see docs/contracts.md)",
                    ),
            );
        };
        // the function name
        let rest = src.get(words..end).unwrap_or("");
        let name_off = words + (rest.len() - rest.trim_start().len());
        let name: String = src
            .get(name_off..end)
            .unwrap_or("")
            .chars()
            .take_while(|c| c.is_alphanumeric() || *c == '_' || *c == '\'')
            .collect();
        if name.is_empty() {
            bad(
                diags,
                (start - 3, end + 3),
                "no function name after `CONTRACT`",
            );
            continue;
        }
        let name_sp = (name_off, name_off + name.len());
        // the clauses: each keyword up to the next one (or the end)
        let mut kws: Vec<(usize, bool)> = Vec::new(); // (offset of the keyword, is `ensures`)
        let body = name_sp.1;
        let text = src.get(body..end).unwrap_or("");
        for (kw, ens) in [("requires", false), ("ensures", true)] {
            let mut from = 0;
            while let Some(i) = text.get(from..).and_then(|t| t.find(kw)).map(|i| from + i) {
                let before = text.get(..i).and_then(|t| t.chars().last());
                let after = text.get(i + kw.len()..).and_then(|t| t.chars().next());
                let word = |c: Option<char>| c.is_some_and(|c| c.is_alphanumeric() || c == '_');
                if !word(before) && !word(after) {
                    kws.push((body + i, ens));
                }
                from = i + kw.len();
            }
        }
        kws.sort_unstable();
        let lead_text = src
            .get(body..kws.first().map_or(end, |k| k.0))
            .unwrap_or("");
        if kws.is_empty() || !lead_text.trim().is_empty() {
            bad(
                diags,
                name_sp,
                "expected `requires` or `ensures` after the function name",
            );
            continue;
        }
        let mut c = Contract {
            func: name,
            span: name_sp,
            requires: Vec::new(),
            ensures: Vec::new(),
        };
        let mut ok = true;
        for (k, (off, ens)) in kws.iter().enumerate() {
            let from = off + if *ens { 7 } else { 8 };
            let to = kws.get(k + 1).map_or(end, |n| n.0);
            match parse_pred(src, from, to) {
                Some(e) if *ens => c.ensures.push(e),
                Some(e) => c.requires.push(e),
                None => {
                    bad(diags, (*off, to), "this predicate does not parse");
                    ok = false;
                }
            }
        }
        if ok {
            out.push(c);
        }
    }
    out
}

/// Parses `src[from..to]` as an expression, with its spans where they are in `src`: a copy of
/// the source blanked to spaces (byte for byte, lines kept) but for that text, behind a
/// definition head at offset 0.
fn parse_pred(src: &str, from: usize, to: usize) -> Option<Expr> {
    if src.get(from..to)?.trim().is_empty() {
        return None;
    }
    let mut copy: Vec<u8> = src
        .bytes()
        .enumerate()
        .map(|(i, b)| {
            if b == b'\n' || (i >= from && i < to) {
                b
            } else {
                b' '
            }
        })
        .collect();
    let head = b"c__ =";
    if from < head.len() + 1 {
        return None;
    }
    copy[..head.len()].copy_from_slice(head);
    // the predicate must not start a line at column 0 (it would be a new declaration)
    let text = String::from_utf8(copy).ok()?;
    let toks = crate::lexer::lex(&text).ok()?;
    let lines = crate::lexer::LineMap::new(&text);
    let lt = crate::layout::layout(&toks, &lines);
    let m = crate::parser::parse_module(&lt).ok()?;
    let [f] = m.funcs.as_slice() else {
        return None;
    };
    match f.clauses.as_slice() {
        [Clause {
            body: Body::Plain(e),
            pats,
            wher,
            ..
        }] if pats.is_empty() && wher.is_empty() => Some(e.clone()),
        _ => None,
    }
}

// ─── contracts as refinements ────────────────────────────────────────────────────────────────

fn split_sig(t: &crate::ast::Type) -> (Vec<crate::ast::Type>, crate::ast::Type) {
    let mut ps = Vec::new();
    let mut t = t;
    while let crate::ast::Type::Arrow { from, to, .. } = t {
        ps.push((**from).clone());
        t = to;
    }
    (ps, t.clone())
}

/// The parameter names a contract of `f` may use: the names of its signature (`a:Array Int`) and
/// the variables of its first clause, by position.
fn param_names(f: &Func, rf: Option<&Refinement>) -> Vec<(usize, String)> {
    let mut names: Vec<(usize, String)> = rf.map(|r| r.names.clone()).unwrap_or_default();
    if let Some(c) = f.clauses.first() {
        for (i, p) in c.pats.iter().enumerate() {
            if let Pat::Var(v, _) = p {
                if !names.iter().any(|(j, n)| *j == i || n == v) {
                    names.push((i, v.clone()));
                }
            }
        }
    }
    names.sort();
    names
}

fn mentions(e: &Expr, n: &str) -> bool {
    let mut refs = HashSet::new();
    crate::check::collect_refs(e, &mut refs);
    refs.contains(n)
}

/// Adds each contract to the module's refinements, as predicates checked at run time where they
/// are not proven (`RefinePred::dynamic`). AX0603 for a contract on something that is not a
/// top-level function with a signature.
pub fn attach(module: &mut Module, diags: &mut Diagnostics) {
    let contracts = module.contracts.clone();
    let mut seen = HashSet::new();
    for c in &contracts {
        let err = |diags: &mut Diagnostics, msg: String| {
            diags.push(
                Diagnostic::error("AX0603", msg)
                    .label(c.span.0, c.span.1, "this contract")
                    .with_help("see docs/contracts.md"),
            );
        };
        if !seen.insert(c.func.clone()) {
            err(diags, format!("`{}` has more than one contract", c.func));
            continue;
        }
        let Some(f) = module.funcs.iter().find(|f| f.name == c.func) else {
            err(
                diags,
                format!("`{}` is not a top-level function of this module", c.func),
            );
            continue;
        };
        let Some(sig) = &f.sig else {
            err(
                diags,
                format!("`{}` needs a type signature to have a contract", c.func),
            );
            continue;
        };
        let (ps, ret) = split_sig(sig);
        let idx = module.refinements.iter().position(|r| r.func == c.func);
        let names = param_names(f, idx.map(|i| &module.refinements[i]));
        let mut preds = Vec::new();
        for p in &c.requires {
            // attached to the last parameter it mentions (all of them are bound at a call)
            let pos = names
                .iter()
                .filter(|(i, n)| *i < ps.len() && mentions(p, n))
                .map(|(i, _)| *i)
                .max();
            let Some(pos) = pos.or((!ps.is_empty()).then_some(0)) else {
                err(
                    diags,
                    format!("`{}` has no parameters to require anything of", c.func),
                );
                continue;
            };
            let binder = names
                .iter()
                .find(|(i, _)| *i == pos)
                .map_or_else(|| format!("argument {}", pos + 1), |(_, n)| n.clone());
            preds.push(RefinePred {
                pos,
                binder,
                ty: ps[pos].clone(),
                pred: p.clone(),
                span: p.span(),
                dynamic: true,
            });
        }
        for q in &c.ensures {
            preds.push(RefinePred {
                pos: ps.len(),
                binder: "result".into(),
                ty: ret.clone(),
                pred: q.clone(),
                span: q.span(),
                dynamic: true,
            });
        }
        match idx {
            Some(i) => {
                let r = &mut module.refinements[i];
                for n in &names {
                    if !r.names.contains(n) {
                        r.names.push(n.clone());
                    }
                }
                r.preds.extend(preds);
            }
            None => module.refinements.push(Refinement {
                func: c.func.clone(),
                names,
                preds,
            }),
        }
    }
}

// ─── the run-time checks ─────────────────────────────────────────────────────────────────────

/// What `refine` could not prove about contracts (`refine::Outcome`).
#[derive(Default, Clone)]
pub struct Dynamic {
    /// a call (its application's span) → the callee and its `requires` not proven there
    /// (indices into the callee's refinement predicates)
    pub calls: HashMap<Span, (String, Vec<usize>)>,
    /// functions whose `ensures` are not proven over their body
    pub ensures: HashSet<String>,
    /// a contract function used as a value (the name's span)
    pub values: HashSet<Span>,
}

/// A contract obligation and how it is discharged, for `--emit contracts` and `--certified`.
pub struct Obligation {
    pub func: String,
    pub what: String,
    pub span: Span,
    pub proven: bool,
}

/// The obligations in source order, each once.
fn sorted(obs: &[Obligation]) -> Vec<&Obligation> {
    let mut v: Vec<&Obligation> = obs.iter().collect();
    v.sort_by(|a, b| (a.span, &a.what, &a.func).cmp(&(b.span, &b.what, &b.func)));
    v.dedup_by(|a, b| a.span == b.span && a.what == b.what && a.func == b.func);
    v
}

fn totals(v: &[&Obligation]) -> String {
    let dynamic = v.iter().filter(|o| !o.proven).count();
    format!(
        "{} obligation(s): {} proven, {dynamic} checked at run time",
        v.len(),
        v.len() - dynamic
    )
}

/// One line per obligation, in source order: where, what, and how it is discharged.
pub fn report(obs: &[Obligation], lines: &crate::lexer::LineMap) -> String {
    let v = sorted(obs);
    let mut out = String::new();
    for o in &v {
        let (l, c) = lines.pos(o.span.0);
        let how = if o.proven {
            "proven"
        } else {
            "checked at run time"
        };
        out.push_str(&format!("{l}:{c}  `{}` {}  {how}\n", o.func, o.what));
    }
    out.push_str(&totals(&v));
    out.push('\n');
    out
}

/// The `--certified` lines about contracts: each one checked at run time, then the totals.
pub fn certified_summary(obs: &[Obligation], path: &str, lines: &crate::lexer::LineMap) -> String {
    let v = sorted(obs);
    let mut out = String::new();
    for o in v.iter().filter(|o| !o.proven) {
        let (l, c) = lines.pos(o.span.0);
        out.push_str(&format!(
            "axionc: contract checked at run time — {path}:{l}:{c} `{}` {}\n",
            o.func, o.what
        ));
    }
    out.push_str(&format!("axionc: contracts — {}\n", totals(&v)));
    out
}

/// Inserts the run-time checks `dynamic` calls for. Returns how many it inserted.
///
/// Spans are inference keys (a call's result type, a variable's type at a use), so a generated
/// node must not share one with a node of another type. The call keeps its own spans, the `if`
/// around it and the failure call (both of the call's type) take the call's span, and every other
/// generated node gets a span of its own past the end of any source file ([`SYN_BASE`]), which a
/// specialization clone moves into its band like any other.
pub fn instrument(module: &mut Module, dynamic: &Dynamic) -> usize {
    if dynamic.calls.is_empty() && dynamic.ensures.is_empty() && dynamic.values.is_empty() {
        return 0;
    }
    let refs: HashMap<String, Refinement> = module
        .refinements
        .iter()
        .map(|r| (r.func.clone(), r.clone()))
        .collect();
    let param_tys: HashMap<String, Vec<crate::ast::Type>> = module
        .funcs
        .iter()
        .filter_map(|f| f.sig.as_ref().map(|s| (f.name.clone(), split_sig(s).0)))
        .collect();
    let mut rw = Rewriter {
        refs,
        param_tys,
        dynamic,
        fresh: 0,
        syn: SYN_BASE,
        inserted: 0,
        caller: String::new(),
    };
    for f in &mut module.funcs {
        rw.caller = f.name.clone();
        rw.func(f);
    }
    rw.inserted
}

/// Where the spans of generated nodes start: past the end of any source file, inside the band.
const SYN_BASE: usize = crate::diag::CLONE_SPAN_STRIDE / 2;

struct Rewriter<'a> {
    refs: HashMap<String, Refinement>,
    param_tys: HashMap<String, Vec<crate::ast::Type>>,
    dynamic: &'a Dynamic,
    fresh: usize,
    /// the next generated span
    syn: usize,
    inserted: usize,
    /// the top-level function being rewritten
    caller: String,
}

impl Rewriter<'_> {
    fn fresh(&mut self, what: &str) -> String {
        self.fresh += 1;
        format!("contract${what}{}", self.fresh)
    }

    /// A span no other node has.
    fn sp(&mut self) -> Span {
        self.syn += 2;
        (self.syn, self.syn + 1)
    }

    fn var(&mut self, n: &str) -> Expr {
        Expr::Var(n.to_string(), self.sp())
    }

    fn app(&mut self, f: Expr, args: Vec<Expr>) -> Expr {
        args.into_iter().fold(f, |acc, a| {
            let sp = self.sp();
            Expr::App(Box::new(acc), Box::new(a), sp)
        })
    }

    fn str_cat(&mut self, a: Expr, b: Expr) -> Expr {
        let f = self.var("strAppend");
        self.app(f, vec![a, b])
    }

    fn let_in(&mut self, binds: Vec<(String, Expr)>, body: Expr) -> Expr {
        if binds.is_empty() {
            return body;
        }
        let fs = binds
            .into_iter()
            .map(|(n, e)| {
                let sp = self.sp();
                Func {
                    name: n,
                    sig: None,
                    clauses: vec![Clause {
                        pats: Vec::new(),
                        body: Body::Plain(e),
                        wher: Vec::new(),
                        span: sp,
                    }],
                    span: sp,
                    constraints: Vec::new(),
                }
            })
            .collect();
        let sp = self.sp();
        Expr::Let(fs, Box::new(body), sp)
    }

    /// A copy of the predicate `e` with each name of `sub` replaced and `len x` read as
    /// `lenArray x`, every node with a span of its own.
    fn subst(&mut self, e: &Expr, sub: &HashMap<String, String>) -> Expr {
        let sp = self.sp();
        match e {
            Expr::Var(n, _) => Expr::Var(sub.get(n).cloned().unwrap_or_else(|| n.clone()), sp),
            Expr::App(f, a, _) => {
                let f = match &**f {
                    Expr::Var(l, _) if l == "len" => self.var("lenArray"),
                    other => self.subst(other, sub),
                };
                let a = self.subst(a, sub);
                Expr::App(Box::new(f), Box::new(a), sp)
            }
            Expr::BinOp(op, a, b, _) => {
                let (a, b) = (self.subst(a, sub), self.subst(b, sub));
                Expr::BinOp(op.clone(), Box::new(a), Box::new(b), sp)
            }
            Expr::If(c, t, f, _) => {
                let (c, t, f) = (self.subst(c, sub), self.subst(t, sub), self.subst(f, sub));
                Expr::If(Box::new(c), Box::new(t), Box::new(f), sp)
            }
            Expr::Int(k, _) => Expr::Int(*k, sp),
            Expr::Con(c, _) => Expr::Con(c.clone(), sp),
            other => other.clone(),
        }
    }

    fn func(&mut self, f: &mut Func) {
        for c in &mut f.clauses {
            match &mut c.body {
                Body::Plain(e) => self.expr(e),
                Body::Guarded(arms) => {
                    for (g, r) in arms {
                        self.expr(g);
                        self.expr(r);
                    }
                }
            }
            for w in &mut c.wher {
                self.func(w);
            }
        }
    }

    fn expr(&mut self, e: &mut Expr) {
        // a contract function used as a value, maybe partially applied (`map (withdraw 50) xs`):
        // a lambda over the missing parameters, the given arguments bound once outside it
        if let Expr::App(..) | Expr::Var(..) = e {
            let outer = match e {
                Expr::App(_, _, sp) => Some(*sp),
                _ => None,
            };
            let mut args: Vec<Expr> = Vec::new();
            let mut h: &Expr = e;
            while let Expr::App(f, a, _) = h {
                args.push((**a).clone());
                h = f;
            }
            if let Expr::Var(g, hsp) = h {
                // partly applied, with an obligation left for run time: its `requires` may
                // already be checkable here (they mention only the given arguments), but the
                // call happens later, wherever the value goes
                let partial = self
                    .param_tys
                    .get(g)
                    .is_some_and(|ps| !args.is_empty() && args.len() < ps.len())
                    && (outer.is_some_and(|sp| {
                        self.dynamic.calls.get(&sp).is_some_and(|(c, _)| c == g)
                    }) || self.dynamic.ensures.contains(g));
                if self.dynamic.values.contains(hsp) || partial {
                    let (g, hsp) = (g.clone(), *hsp);
                    args.reverse();
                    for a in &mut args {
                        self.expr(a);
                    }
                    *e = self.value(&g, hsp, args);
                    return;
                }
            }
        }
        // children first: an argument may itself be a checked call
        match e {
            Expr::App(f, a, _) => {
                self.expr(f);
                self.expr(a);
            }
            Expr::BinOp(_, a, b, _) => {
                self.expr(a);
                self.expr(b);
            }
            Expr::If(c, t, f, _) => {
                self.expr(c);
                self.expr(t);
                self.expr(f);
            }
            Expr::Let(fs, body, _) => {
                for f in fs {
                    self.func(f);
                }
                self.expr(body);
            }
            Expr::Case(s, arms, _) => {
                self.expr(s);
                for (_, a) in arms {
                    self.expr(a);
                }
            }
            Expr::Tuple(es, _) => es.iter_mut().for_each(|x| self.expr(x)),
            Expr::RecordCon(_, fs, _) => fs.iter_mut().for_each(|(_, x)| self.expr(x)),
            Expr::RecordUpd(b, fs, _) => {
                self.expr(b);
                fs.iter_mut().for_each(|(_, x)| self.expr(x));
            }
            Expr::Lam(_, body, _) => self.expr(body),
            Expr::Var(..) | Expr::Int(..) | Expr::Float(..) | Expr::Str(..) | Expr::Con(..) => {}
        }
        let Expr::App(_, _, sp) = e else {
            return;
        };
        let sp = *sp;
        let (g, nargs) = {
            let mut n = 0;
            let mut h: &Expr = e;
            while let Expr::App(f, _, _) = h {
                n += 1;
                h = f;
            }
            match h {
                Expr::Var(g, _) => (g.clone(), n),
                _ => return,
            }
        };
        if self.param_tys.get(&g).map(Vec::len) != Some(nargs) {
            return;
        }
        let req: Vec<usize> = self
            .dynamic
            .calls
            .get(&sp)
            .filter(|(c, _)| *c == g)
            .map(|(_, r)| r.clone())
            .unwrap_or_default();
        let ens = self.dynamic.ensures.contains(&g) && self.caller != g;
        if req.is_empty() && !ens {
            return;
        }
        let call = std::mem::replace(e, Expr::Int(0, sp));
        *e = self.checked(&g, call, &req, ens, sp);
    }

    /// `g` given only `given` of its arguments, as a value: a lambda over the rest that checks
    /// every contract predicate of the call. `hsp` is the name's own span.
    fn value(&mut self, g: &str, hsp: Span, given: Vec<Expr>) -> Expr {
        let n = self.param_tys.get(g).map_or(0, Vec::len);
        let mut binds = Vec::new();
        let mut args = Vec::new();
        for a in given {
            if let Expr::Var(..) | Expr::Int(..) = a {
                args.push(a);
            } else {
                let v = self.fresh("g");
                binds.push((v.clone(), a));
                args.push(self.var(&v));
            }
        }
        let ps: Vec<String> = (args.len()..n).map(|_| self.fresh("p")).collect();
        for p in &ps {
            let v = self.var(p);
            args.push(v);
        }
        let all: Vec<usize> = self.refs.get(g).map_or(Vec::new(), |r| {
            (0..r.preds.len()).filter(|&i| r.preds[i].dynamic).collect()
        });
        let call = self.app(Expr::Var(g.to_string(), hsp), args);
        let csp = self.sp();
        let call = match call {
            Expr::App(f, a, _) => Expr::App(f, a, csp),
            other => other,
        };
        let body = self.checked(g, call, &all, true, csp);
        let lam = if ps.is_empty() {
            body
        } else {
            let pats = ps
                .iter()
                .map(|p| {
                    let sp = self.sp();
                    Pat::Var(p.clone(), sp)
                })
                .collect();
            let sp = self.sp();
            Expr::Lam(pats, Box::new(body), sp)
        };
        self.let_in(binds, lam)
    }

    /// The call `call` (an application of `g` to all its arguments), with the `requires`
    /// predicates `req` checked before it and, when `ens`, the `ensures` predicates after it.
    /// `sp` is the call's span.
    fn checked(&mut self, g: &str, mut call: Expr, req: &[usize], ens: bool, sp: Span) -> Expr {
        let Some(rf) = self.refs.get(g).cloned() else {
            return call;
        };
        let n = self.param_tys.get(g).map_or(0, Vec::len);
        let used: Vec<RefinePred> = rf
            .preds
            .iter()
            .enumerate()
            .filter(|(i, p)| (req.contains(i) && p.pos < n) || (ens && p.dynamic && p.pos == n))
            .map(|(_, p)| p.clone())
            .collect();
        // the arguments, in the call itself (its spine, last argument first)
        let mut slots: Vec<&mut Expr> = Vec::new();
        {
            let mut h: &mut Expr = &mut call;
            while let Expr::App(f, a, _) = h {
                slots.push(&mut **a);
                h = &mut **f;
            }
        }
        slots.reverse();
        // a predicate's names: a variable argument is used as it is; anything else is bound
        // once before the call and the call uses the binding
        let mut sub: HashMap<String, String> = HashMap::new();
        let mut binds = Vec::new();
        for (i, slot) in slots.into_iter().enumerate() {
            let Some(nm) = rf
                .names
                .iter()
                .find(|(j, _)| *j == i)
                .map(|(_, n)| n.clone())
            else {
                continue;
            };
            if !used.iter().any(|p| mentions(&p.pred, &nm)) {
                continue;
            }
            if let Expr::Var(v, _) = &*slot {
                sub.insert(nm, v.clone());
                continue;
            }
            let v = self.fresh("a");
            let r = self.var(&v);
            let arg = std::mem::replace(slot, r);
            sub.insert(nm, v.clone());
            binds.push((v, arg));
        }
        // what the message shows: each named `Int` argument, and the length of each array one
        let shown: Vec<(String, String, bool)> = rf
            .names
            .iter()
            .filter_map(|(i, nm)| {
                let v = sub.get(nm)?;
                let int = matches!(
                    self.param_tys.get(g).and_then(|t| t.get(*i)),
                    Some(crate::ast::Type::Con(c)) if c == "Int"
                );
                Some(if int {
                    (nm.clone(), v.clone(), false)
                } else {
                    (format!("len {nm}"), v.clone(), true)
                })
            })
            .collect();
        if ens {
            let r = self.fresh("r");
            let mut sub_r = sub.clone();
            sub_r.insert("result".into(), r.clone());
            let mut body = self.var(&r);
            for p in rf.preds.iter().filter(|p| p.dynamic && p.pos == n).rev() {
                let mut vals = shown.clone();
                vals.push(("result".into(), r.clone(), false));
                let cond = self.subst(&p.pred, &sub_r);
                let fail = self.fail(g, "ensures", &p.pred, &vals, sp);
                body = Expr::If(Box::new(cond), Box::new(body), Box::new(fail), sp);
                self.inserted += 1;
            }
            call = self.let_in(vec![(r, call)], body);
        }
        for &i in req.iter().rev() {
            let Some(p) = rf.preds.get(i).filter(|p| p.pos < n) else {
                continue;
            };
            let cond = self.subst(&p.pred, &sub);
            let fail = self.fail(g, "requires", &p.pred, &shown, sp);
            call = Expr::If(Box::new(cond), Box::new(call), Box::new(fail), sp);
            self.inserted += 1;
        }
        self.let_in(binds, call)
    }

    /// `contractFailed "axion: contract violated: `g` requires `p` (x = 3, len a = 2), called
    /// from `h`"`, at the call's span `sp` (it has the call's type).
    fn fail(
        &mut self,
        g: &str,
        kind: &str,
        p: &Expr,
        vals: &[(String, String, bool)],
        sp: Span,
    ) -> Expr {
        let head = format!(
            "axion: contract violated: `{g}` {kind} `{}`",
            crate::refine::show(p)
        );
        let hsp = self.sp();
        let mut msg = Expr::Str(head, hsp);
        let mut first = true;
        for (label, v, is_len) in vals {
            let lead = if first { " (" } else { ", " };
            first = false;
            let lsp = self.sp();
            msg = self.str_cat(msg, Expr::Str(format!("{lead}{label} = "), lsp));
            let mut value = self.var(v);
            if *is_len {
                let l = self.var("lenArray");
                value = self.app(l, vec![value]);
            }
            let show = self.var("showInt");
            let shown = self.app(show, vec![value]);
            msg = self.str_cat(msg, shown);
        }
        let tail = if first { "" } else { ")" };
        let tsp = self.sp();
        let tail = Expr::Str(format!("{tail}, called from `{}`", self.caller), tsp);
        msg = self.str_cat(msg, tail);
        let f = self.var(FAIL);
        Expr::App(Box::new(f), Box::new(msg), sp)
    }
}
