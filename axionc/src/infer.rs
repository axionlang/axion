//! Inferência de tipos — Hindley-Milner (Algoritmo W) para o subconjunto L0/L1.
//!
//! Corre a par da análise de linearidade (`check.rs`): a linearidade cuida do
//! *quantas vezes* um recurso é usado (multiplicidades); a inferência cuida do
//! *que tipo* tem. Emite `AX0200` (incompatibilidade de tipos) e `AX0201`
//! (tipo infinito / occurs-check).
//!
//! Suporta: literais, funções (multi-cláusula, pattern matching), aplicação,
//! `let`/`where` com generalização, `if`, `case`, registos (construção,
//! actualização, selectores) e os builtins. As multiplicidades das setas são
//! ignoradas aqui (são o trabalho do `check.rs`).

use crate::ast::*;
use crate::diag::{Diagnostic, Diagnostics};
use std::collections::{HashMap, HashSet};

#[derive(Clone, Debug)]
enum Ty {
    Var(u32),
    Con(String, Vec<Ty>),
    Fun(Box<Ty>, Box<Ty>),
    Tuple(Vec<Ty>),
}

#[derive(Clone)]
struct Scheme {
    vars: Vec<u32>,
    ty: Ty,
}

type Env = HashMap<String, Scheme>;

struct Infer<'a> {
    subst: HashMap<u32, Ty>,
    counter: u32,
    diags: &'a mut Diagnostics,
    /// construtor → (tipo do registo, campos com tipo)
    cons: HashMap<String, (String, Vec<(String, Ty)>)>,
    /// tipo do registo → campos com tipo (para actualização)
    records: HashMap<String, Vec<(String, Ty)>>,
}

/// Ponto de entrada: infere e verifica os tipos do módulo.
pub fn infer(module: &Module, diags: &mut Diagnostics) {
    let mut inf = Infer {
        subst: HashMap::new(),
        counter: 0,
        diags,
        cons: HashMap::new(),
        records: HashMap::new(),
    };
    let mut env: Env = inf.base_env();

    // tipos dos construtores e selectores a partir das declarações `data`
    for d in &module.datas {
        let result = Ty::Con(d.name.clone(), Vec::new());
        for c in &d.cons {
            let fields: Vec<(String, Ty)> = c
                .fields
                .iter()
                .enumerate()
                .map(|(i, f)| {
                    let name = if f.name.is_empty() {
                        format!("_{i}")
                    } else {
                        f.name.clone()
                    };
                    (name, ty_of_ast(&f.ty))
                })
                .collect();

            // construtor: campo1 -> ... -> T
            let mut cty = result.clone();
            for (_, ft) in fields.iter().rev() {
                cty = Ty::Fun(Box::new(ft.clone()), Box::new(cty));
            }
            env.insert(
                c.name.clone(),
                Scheme {
                    vars: vec![],
                    ty: cty,
                },
            );

            // selectores: T -> tipoDoCampo
            for (fname, ft) in &fields {
                if !fname.starts_with('_') {
                    env.insert(
                        fname.clone(),
                        Scheme {
                            vars: vec![],
                            ty: Ty::Fun(Box::new(result.clone()), Box::new(ft.clone())),
                        },
                    );
                }
            }
            inf.cons
                .insert(c.name.clone(), (d.name.clone(), fields.clone()));
            inf.records.insert(d.name.clone(), fields);
        }
    }

    // esquemas das funções de topo: a partir da assinatura, ou monótipo fresco
    let mut placeholders: HashMap<String, Ty> = HashMap::new();
    for f in &module.funcs {
        match &f.sig {
            Some(sig) => {
                let scheme = inf.scheme_of_sig(sig);
                env.insert(f.name.clone(), scheme);
            }
            None => {
                let v = inf.fresh();
                placeholders.insert(f.name.clone(), v.clone());
                env.insert(
                    f.name.clone(),
                    Scheme {
                        vars: vec![],
                        ty: v,
                    },
                );
            }
        }
    }

    // verifica cada função contra o seu tipo (em modo de checking quando há
    // assinatura: os parâmetros herdam os tipos declarados antes do corpo)
    for f in &module.funcs {
        let declared = env.get(&f.name).cloned().map(|s| inf.instantiate(&s));
        let inferred = inf.infer_func(&env, f, declared.as_ref());
        if let Some(d) = &declared {
            inf.unify(&inferred, d, f.span);
        }
    }
    let _ = placeholders;
}

fn ty_of_ast(t: &Type) -> Ty {
    // converte um tipo da assinatura em Ty, mapeando variáveis por nome
    fn go(t: &Type, vars: &mut HashMap<String, u32>, next: &mut u32) -> Ty {
        match t {
            Type::Con(n) => Ty::Con(n.clone(), Vec::new()),
            Type::Var(n) => {
                let id = *vars.entry(n.clone()).or_insert_with(|| {
                    let v = *next;
                    *next += 1;
                    v
                });
                Ty::Var(id)
            }
            Type::App(_, _) => {
                let (head, args) = flatten_app(t);
                Ty::Con(head, args.iter().map(|a| go(a, vars, next)).collect())
            }
            Type::Arrow { from, to, .. } => {
                Ty::Fun(Box::new(go(from, vars, next)), Box::new(go(to, vars, next)))
            }
            Type::Tuple(ts) => Ty::Tuple(ts.iter().map(|a| go(a, vars, next)).collect()),
            Type::Unit => Ty::Con("()".to_string(), Vec::new()),
        }
    }
    // usa um espaço de nomes local; as variáveis são renumeradas ao instanciar
    let mut vars = HashMap::new();
    let mut next = 1_000_000; // banda separada; scheme_of_sig quantifica-as
    go(t, &mut vars, &mut next)
}

fn flatten_app(t: &Type) -> (String, Vec<Type>) {
    match t {
        Type::App(f, a) => {
            let (head, mut args) = flatten_app(f);
            args.push((**a).clone());
            (head, args)
        }
        Type::Con(n) => (n.clone(), Vec::new()),
        _ => ("?".to_string(), Vec::new()),
    }
}

impl<'a> Infer<'a> {
    fn fresh(&mut self) -> Ty {
        let v = self.counter;
        self.counter += 1;
        Ty::Var(v)
    }

    fn base_env(&mut self) -> Env {
        let io_unit = Ty::Con("IO".into(), vec![Ty::Con("()".into(), vec![])]);
        let int = || Ty::Con("Int".into(), vec![]);
        let string = || Ty::Con("String".into(), vec![]);
        let bool = || Ty::Con("Bool".into(), vec![]);
        let bin = |t: Ty| {
            Ty::Fun(
                Box::new(t.clone()),
                Box::new(Ty::Fun(Box::new(t.clone()), Box::new(t))),
            )
        };
        let mut env = Env::new();
        // putStrLn :: String -> IO ()
        env.insert(
            "putStrLn".into(),
            mono(Ty::Fun(Box::new(string()), Box::new(io_unit))),
        );
        // show :: forall a. a -> String
        env.insert(
            "show".into(),
            Scheme {
                vars: vec![0],
                ty: Ty::Fun(Box::new(Ty::Var(0)), Box::new(string())),
            },
        );
        env.insert("True".into(), mono(bool()));
        env.insert("False".into(), mono(bool()));
        env.insert("otherwise".into(), mono(bool()));
        // aritmética e comparações (monomórficas em Int no subconjunto)
        for op in ["+", "-", "*", "mod"] {
            env.insert(op.into(), mono(bin(int())));
        }
        for op in ["==", "<", ">"] {
            env.insert(
                op.into(),
                mono(Ty::Fun(
                    Box::new(int()),
                    Box::new(Ty::Fun(Box::new(int()), Box::new(bool()))),
                )),
            );
        }
        env
    }

    fn scheme_of_sig(&mut self, sig: &Type) -> Scheme {
        let ty = ty_of_ast(sig);
        // as variáveis da assinatura (banda 1_000_000+) tornam-se quantificadas
        let mut vars = Vec::new();
        collect_sig_vars(&ty, &mut vars);
        // renumera para variáveis frescas normais e quantifica-as
        let mut map = HashMap::new();
        for v in &vars {
            if let Ty::Var(f) = self.fresh() {
                map.insert(*v, f);
            }
        }
        let ty = rename_vars(&ty, &map);
        Scheme {
            vars: map.values().copied().collect(),
            ty,
        }
    }

    // --- substituição / unificação ---
    fn resolve(&self, t: &Ty) -> Ty {
        match t {
            Ty::Var(v) => match self.subst.get(v) {
                Some(u) => self.resolve(u),
                None => t.clone(),
            },
            _ => t.clone(),
        }
    }

    fn apply(&self, t: &Ty) -> Ty {
        match self.resolve(t) {
            Ty::Con(n, args) => Ty::Con(n, args.iter().map(|a| self.apply(a)).collect()),
            Ty::Fun(a, b) => Ty::Fun(Box::new(self.apply(&a)), Box::new(self.apply(&b))),
            Ty::Tuple(ts) => Ty::Tuple(ts.iter().map(|a| self.apply(a)).collect()),
            other => other,
        }
    }

    fn occurs(&self, v: u32, t: &Ty) -> bool {
        match self.resolve(t) {
            Ty::Var(u) => u == v,
            Ty::Con(_, args) => args.iter().any(|a| self.occurs(v, a)),
            Ty::Fun(a, b) => self.occurs(v, &a) || self.occurs(v, &b),
            Ty::Tuple(ts) => ts.iter().any(|a| self.occurs(v, a)),
        }
    }

    fn unify(&mut self, a: &Ty, b: &Ty, span: Span) -> bool {
        let a = self.resolve(a);
        let b = self.resolve(b);
        match (&a, &b) {
            (Ty::Var(x), Ty::Var(y)) if x == y => true,
            (Ty::Var(x), _) => self.bind(*x, &b, span),
            (_, Ty::Var(y)) => self.bind(*y, &a, span),
            (Ty::Con(n1, a1), Ty::Con(n2, a2)) if n1 == n2 && a1.len() == a2.len() => {
                let mut ok = true;
                for (x, y) in a1.iter().zip(a2) {
                    ok &= self.unify(x, y, span);
                }
                ok
            }
            (Ty::Fun(l1, r1), Ty::Fun(l2, r2)) => {
                let ok1 = self.unify(l1, l2, span);
                let ok2 = self.unify(r1, r2, span);
                ok1 && ok2
            }
            (Ty::Tuple(t1), Ty::Tuple(t2)) if t1.len() == t2.len() => {
                let mut ok = true;
                for (x, y) in t1.iter().zip(t2) {
                    ok &= self.unify(x, y, span);
                }
                ok
            }
            _ => {
                self.err_mismatch(&a, &b, span);
                false
            }
        }
    }

    fn bind(&mut self, v: u32, t: &Ty, span: Span) -> bool {
        if let Ty::Var(u) = t {
            if *u == v {
                return true;
            }
        }
        if self.occurs(v, t) {
            self.diags.push(
                Diagnostic::error("AX0201", "tipo infinito (occurs-check falhou)").label(
                    span.0,
                    span.1,
                    "a inferência formaria um tipo recursivo aqui",
                ),
            );
            return false;
        }
        self.subst.insert(v, t.clone());
        true
    }

    fn err_mismatch(&mut self, a: &Ty, b: &Ty, span: Span) {
        let sa = show_ty(&self.apply(a));
        let sb = show_ty(&self.apply(b));
        self.diags.push(
            Diagnostic::error(
                "AX0200",
                format!("incompatibilidade de tipos: {sa} vs {sb}"),
            )
            .label(span.0, span.1, format!("esperava {sa}, encontrei {sb}")),
        );
    }

    fn instantiate(&mut self, s: &Scheme) -> Ty {
        let mut map = HashMap::new();
        for v in &s.vars {
            if let Ty::Var(f) = self.fresh() {
                map.insert(*v, f);
            }
        }
        rename_vars(&s.ty, &map)
    }

    fn generalize(&self, env: &Env, ty: &Ty) -> Scheme {
        let ty = self.apply(ty);
        let mut env_vars = HashSet::new();
        for s in env.values() {
            let applied = self.apply(&s.ty);
            let mut fv = HashSet::new();
            free_vars(&applied, &mut fv);
            for q in &s.vars {
                fv.remove(q);
            }
            env_vars.extend(fv);
        }
        let mut fv = HashSet::new();
        free_vars(&ty, &mut fv);
        let vars: Vec<u32> = fv.difference(&env_vars).copied().collect();
        Scheme { vars, ty }
    }

    // --- inferência ---
    fn peel_fun(&self, ty: &Ty, n: usize) -> (Vec<Ty>, Ty) {
        let mut params = Vec::new();
        let mut cur = self.resolve(ty);
        for _ in 0..n {
            match cur {
                Ty::Fun(a, b) => {
                    params.push(*a);
                    cur = self.resolve(&b);
                }
                other => {
                    cur = other;
                    break;
                }
            }
        }
        (params, cur)
    }

    fn infer_func(&mut self, env: &Env, f: &Func, expected: Option<&Ty>) -> Ty {
        let mut result: Option<Ty> = None;
        for clause in &f.clauses {
            let t = self.infer_clause(env, clause, expected);
            match &result {
                None => result = Some(t),
                Some(r) => {
                    self.unify(r, &t, clause.span);
                }
            }
        }
        result.unwrap_or_else(|| self.fresh())
    }

    fn infer_clause(&mut self, env: &Env, clause: &Clause, expected: Option<&Ty>) -> Ty {
        let mut local = env.clone();
        let n = clause.pats.len();
        let (exp_params, exp_result) = match expected {
            Some(t) => {
                let (p, r) = self.peel_fun(t, n);
                (p, Some(r))
            }
            None => (Vec::new(), None),
        };
        let mut params = Vec::new();
        for (i, p) in clause.pats.iter().enumerate() {
            let pt = self.infer_pat(&mut local, p);
            if let Some(ep) = exp_params.get(i) {
                self.unify(&pt, ep, clause.span);
            }
            params.push(pt);
        }
        // where: grupo de bindings com generalização
        let local = self.infer_group(&local, &clause.wher);
        let body_ty = match &clause.body {
            Body::Plain(e) => self.infer_expr(&local, e),
            Body::Guarded(arms) => {
                let mut rty: Option<Ty> = None;
                for (g, r) in arms {
                    let gt = self.infer_expr(&local, g);
                    self.unify(&gt, &Ty::Con("Bool".into(), vec![]), g.span());
                    let rt = self.infer_expr(&local, r);
                    match &rty {
                        None => rty = Some(rt),
                        Some(x) => {
                            self.unify(x, &rt, r.span());
                        }
                    }
                }
                rty.unwrap_or_else(|| self.fresh())
            }
        };
        if let Some(er) = &exp_result {
            self.unify(&body_ty, er, clause.span);
        }
        let mut ty = body_ty;
        for p in params.into_iter().rev() {
            ty = Ty::Fun(Box::new(p), Box::new(ty));
        }
        ty
    }

    fn infer_pat(&mut self, env: &mut Env, p: &Pat) -> Ty {
        match p {
            Pat::Wild(_) => self.fresh(),
            Pat::Int(_, _) => Ty::Con("Int".into(), vec![]),
            Pat::Var(n, _) => {
                let t = self.fresh();
                env.insert(n.clone(), mono(t.clone()));
                t
            }
            Pat::Con(name, args, span) => {
                // construtor aplicado: instancia o tipo do construtor
                let cty = match env.get(name) {
                    Some(s) => self.instantiate(s),
                    None => return self.fresh(),
                };
                let mut result = cty;
                for a in args {
                    let at = self.infer_pat(env, a);
                    let r = self.fresh();
                    self.unify(&result, &Ty::Fun(Box::new(at), Box::new(r.clone())), *span);
                    result = r;
                }
                result
            }
        }
    }

    /// Infere um grupo de bindings (`let`/`where`) com generalização e
    /// devolve o env estendido.
    fn infer_group(&mut self, env: &Env, funcs: &[Func]) -> Env {
        if funcs.is_empty() {
            return env.clone();
        }
        // fase monomórfica: cada nome recebe uma var fresca
        let mut mono_env = env.clone();
        let mut vars = HashMap::new();
        for f in funcs {
            let v = self.fresh();
            vars.insert(f.name.clone(), v.clone());
            mono_env.insert(f.name.clone(), mono(v));
        }
        for f in funcs {
            let t = self.infer_func(&mono_env, f, None);
            let v = vars[&f.name].clone();
            self.unify(&v, &t, f.span);
        }
        // fase de generalização: rebind com esquemas fechados sobre o env exterior
        let mut out = env.clone();
        for f in funcs {
            let t = self.apply(&vars[&f.name]);
            let scheme = self.generalize(env, &t);
            out.insert(f.name.clone(), scheme);
        }
        out
    }

    fn infer_expr(&mut self, env: &Env, e: &Expr) -> Ty {
        match e {
            Expr::Int(_, _) => Ty::Con("Int".into(), vec![]),
            Expr::Str(_, _) => Ty::Con("String".into(), vec![]),
            Expr::Var(n, _) => match env.get(n) {
                Some(s) => self.instantiate(s),
                None => self.fresh(), // nome não encontrado: reportado pelo check.rs
            },
            Expr::Con(n, _) => match env.get(n) {
                Some(s) => self.instantiate(s),
                None => self.fresh(),
            },
            Expr::App(f, x, span) => {
                let tf = self.infer_expr(env, f);
                let tx = self.infer_expr(env, x);
                let r = self.fresh();
                self.unify(&tf, &Ty::Fun(Box::new(tx), Box::new(r.clone())), *span);
                r
            }
            Expr::BinOp(op, l, r, span) => {
                let top = match env.get(op) {
                    Some(s) => self.instantiate(s),
                    None => self.fresh(),
                };
                let tl = self.infer_expr(env, l);
                let tr = self.infer_expr(env, r);
                let res = self.fresh();
                let want = Ty::Fun(
                    Box::new(tl),
                    Box::new(Ty::Fun(Box::new(tr), Box::new(res.clone()))),
                );
                self.unify(&top, &want, *span);
                res
            }
            Expr::If(c, t, el, span) => {
                let tc = self.infer_expr(env, c);
                self.unify(&tc, &Ty::Con("Bool".into(), vec![]), c.span());
                let tt = self.infer_expr(env, t);
                let te = self.infer_expr(env, el);
                self.unify(&tt, &te, *span);
                tt
            }
            Expr::Let(binds, body, _) => {
                let env2 = self.infer_group(env, binds);
                self.infer_expr(&env2, body)
            }
            Expr::Case(scrut, arms, span) => {
                let ts = self.infer_expr(env, scrut);
                let mut rty: Option<Ty> = None;
                for (pat, body) in arms {
                    let mut local = env.clone();
                    let tp = self.infer_pat(&mut local, pat);
                    self.unify(&tp, &ts, *span);
                    let tb = self.infer_expr(&local, body);
                    match &rty {
                        None => rty = Some(tb),
                        Some(x) => {
                            self.unify(x, &tb, body.span());
                        }
                    }
                }
                rty.unwrap_or_else(|| self.fresh())
            }
            Expr::Tuple(es, _) => Ty::Tuple(es.iter().map(|e| self.infer_expr(env, e)).collect()),
            Expr::RecordCon(con, assigns, span) => {
                let (tyname, fields) = match self.cons.get(con) {
                    Some(x) => x.clone(),
                    None => return self.fresh(),
                };
                for (fname, fexpr) in assigns {
                    let fe = self.infer_expr(env, fexpr);
                    if let Some((_, ft)) = fields.iter().find(|(n, _)| n == fname) {
                        self.unify(&fe, ft, *span);
                    }
                }
                Ty::Con(tyname, vec![])
            }
            Expr::RecordUpd(base, assigns, span) => {
                let tb = self.infer_expr(env, base);
                let resolved = self.apply(&tb);
                if let Ty::Con(tyname, _) = &resolved {
                    if let Some(fields) = self.records.get(tyname).cloned() {
                        for (fname, fexpr) in assigns {
                            let fe = self.infer_expr(env, fexpr);
                            if let Some((_, ft)) = fields.iter().find(|(n, _)| n == fname) {
                                self.unify(&fe, ft, *span);
                            }
                        }
                    }
                } else {
                    // base ainda desconhecida: apenas infere os campos
                    for (_, fexpr) in assigns {
                        self.infer_expr(env, fexpr);
                    }
                }
                tb
            }
        }
    }
}

fn mono(ty: Ty) -> Scheme {
    Scheme { vars: vec![], ty }
}

fn collect_sig_vars(t: &Ty, out: &mut Vec<u32>) {
    match t {
        Ty::Var(v) => {
            if *v >= 1_000_000 && !out.contains(v) {
                out.push(*v);
            }
        }
        Ty::Con(_, args) => args.iter().for_each(|a| collect_sig_vars(a, out)),
        Ty::Fun(a, b) => {
            collect_sig_vars(a, out);
            collect_sig_vars(b, out);
        }
        Ty::Tuple(ts) => ts.iter().for_each(|a| collect_sig_vars(a, out)),
    }
}

fn rename_vars(t: &Ty, map: &HashMap<u32, u32>) -> Ty {
    match t {
        Ty::Var(v) => Ty::Var(*map.get(v).unwrap_or(v)),
        Ty::Con(n, args) => Ty::Con(
            n.clone(),
            args.iter().map(|a| rename_vars(a, map)).collect(),
        ),
        Ty::Fun(a, b) => Ty::Fun(Box::new(rename_vars(a, map)), Box::new(rename_vars(b, map))),
        Ty::Tuple(ts) => Ty::Tuple(ts.iter().map(|a| rename_vars(a, map)).collect()),
    }
}

fn free_vars(t: &Ty, out: &mut HashSet<u32>) {
    match t {
        Ty::Var(v) => {
            out.insert(*v);
        }
        Ty::Con(_, args) => args.iter().for_each(|a| free_vars(a, out)),
        Ty::Fun(a, b) => {
            free_vars(a, out);
            free_vars(b, out);
        }
        Ty::Tuple(ts) => ts.iter().for_each(|a| free_vars(a, out)),
    }
}

fn show_ty(t: &Ty) -> String {
    match t {
        Ty::Var(v) => format!("?{v}"),
        Ty::Con(n, args) if args.is_empty() => n.clone(),
        Ty::Con(n, args) => {
            let inner: Vec<String> = args.iter().map(show_ty).collect();
            format!("{n} {}", inner.join(" "))
        }
        Ty::Fun(a, b) => format!("{} -> {}", show_ty_atom(a), show_ty(b)),
        Ty::Tuple(ts) => {
            let inner: Vec<String> = ts.iter().map(show_ty).collect();
            format!("({})", inner.join(", "))
        }
    }
}

fn show_ty_atom(t: &Ty) -> String {
    match t {
        Ty::Fun(_, _) => format!("({})", show_ty(t)),
        _ => show_ty(t),
    }
}
