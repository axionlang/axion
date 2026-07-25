//! Axión Core IR (§11): a representação intermédia **estrita/linear** de onde os
//! backends nativos baixam (hoje o Cranelift `--dev`; amanhã o LLVM `--release`),
//! em vez de baixar do AST directamente.
//!
//! Está em **A-normal form (ANF)**: toda a subexpressão composta é nomeada por um
//! `let`, e os argumentos de operações/chamadas são **átomos** (literal ou
//! variável). O controlo (`if`/`case`) vive num `Rhs`, pelo que um `let` pode
//! ligar o resultado de um ramo (estilo *join-point*). O desugar de
//! multi-cláusula (cadeia de `if`), o *lifting* de `where` e a **conversão de
//! closures** (lambda → função + ambiente de captura) acontecem já nesta baixada,
//! ficando o codegen um mero emissor Core→máquina.
//!
//! A reclamação (Auto-Drop / reset de arena / in-place) fica **implícita** neste
//! primeiro corte — o `check.rs` já a calcula como metadados laterais; torná-la
//! nós explícitos do Core é o incremento seguinte, emparelhado com o runtime que
//! liberta de facto.

use crate::ast::{self, Body, Expr, Pat, Span, Type};
use std::collections::HashMap;
use std::collections::HashSet;

/// Valor atómico: literal ou referência a uma variável já ligada.
#[derive(Debug, Clone)]
pub enum Atom {
    Int(i64),
    Str(String),
    Var(String),
}

/// Uma computação-folha (lado direito de um `let`, sem controlo).
#[derive(Debug, Clone)]
pub enum Op {
    Atom(Atom),
    /// operação primitiva binária: `+ - * mod == < > band`
    Prim(String, Atom, Atom),
    /// chamada directa a função nomeada (topo ou local de `where` já mangled)
    CallDirect(String, Vec<Atom>),
    /// chamada indirecta através de uma closure (o átomo é o ponteiro)
    CallClosure(Atom, Vec<Atom>),
    /// construir closure: função liftada + valores capturados
    MakeClosure {
        func: String,
        captures: Vec<Atom>,
    },
    /// alocar tuplo na heap (um `i64` por componente)
    MakeTuple(Vec<Atom>),
    /// construir registo `Con { campo = átomo, … }`
    MakeRecord {
        con: String,
        fields: Vec<(String, Atom)>,
    },
    /// actualizar registo `base { campo = átomo, … }`
    UpdateRecord {
        base: Atom,
        fields: Vec<(String, Atom)>,
    },
    /// selector de campo `campo rec`
    Field {
        name: String,
        rec: Atom,
    },
    /// `putStrLn :: String -> IO ()` (runtime)
    PutStrLn(Atom),
    /// `show :: Int -> String` (runtime)
    ShowInt(Atom),
    /// forma do AST fora do subconjunto nativo — o codegen recusa com este texto
    Unsupported(String),
}

/// Lado direito de um `let` (ou o resultado): folha ou controlo.
#[derive(Debug, Clone)]
pub enum Rhs {
    Op(Op),
    If(Atom, Box<Term>, Box<Term>),
    Case(Atom, Vec<(CPat, Term)>),
}

/// Sequência de `let`s terminada num resultado.
#[derive(Debug, Clone)]
pub enum Term {
    Let(String, Rhs, Box<Term>),
    Ret(Rhs),
}

/// Padrões de `case` suportados nativamente.
#[derive(Debug, Clone)]
pub enum CPat {
    Int(i64),
    Var(String),
    Wild,
    Tuple(Vec<CPat>),
    Con(String), // construtor — o codegen recusa (ainda)
}

/// Uma função no Core: de topo, local de `where`, ou lambda liftada.
#[derive(Debug, Clone)]
pub struct CoreFn {
    pub name: String,
    pub params: Vec<String>,
    /// nomes capturados (vazio para não-lambdas); carregados do env em codegen
    pub captures: Vec<String>,
    pub is_closure: bool,
    pub body: Term,
}

// --- classificação de tipos nativos (partilhada com o codegen) ---

/// Tipos representados por um `i64`: `Int`, `String`, `IO`, um `data`, ou uma
/// função (ponteiro para closure `{fn_ptr, capturas…}`).
pub fn native_ty(t: &Type, data_types: &HashSet<String>) -> bool {
    if matches!(t, Type::Arrow { .. }) {
        return true;
    }
    match t.head_con() {
        Some("Int" | "String" | "IO") => true,
        Some(h) => data_types.contains(h),
        None => false,
    }
}

pub fn result_type(sig: &Type) -> &Type {
    let mut t = sig;
    while let Type::Arrow { to, .. } = t {
        t = to;
    }
    t
}

pub fn is_int(t: &Type) -> bool {
    matches!(t.head_con(), Some("Int"))
}

pub fn data_type_names(module: &ast::Module) -> HashSet<String> {
    module.datas.iter().map(|d| d.name.clone()).collect()
}

/// Candidata a nativa: todos os parâmetros e o retorno são `i64`-representáveis.
fn top_candidate(f: &ast::Func, data_types: &HashSet<String>) -> Option<usize> {
    let sig = f.sig.as_ref()?;
    let ok = sig.param_types().iter().all(|t| native_ty(t, data_types))
        && native_ty(result_type(sig), data_types);
    ok.then(|| f.clauses.first().map(|c| c.pats.len()).unwrap_or(0))
}

// --- utilitários de âmbito (variáveis livres, para a captura de closures) ---

fn pat_vars(p: &Pat, out: &mut Vec<String>) {
    match p {
        Pat::Var(n, _) => out.push(n.clone()),
        Pat::Con(_, ps, _) | Pat::Tuple(ps, _) => ps.iter().for_each(|q| pat_vars(q, out)),
        _ => {}
    }
}

fn free_vars(e: &Expr, bound: &HashSet<String>, out: &mut HashSet<String>) {
    match e {
        Expr::Var(n, _) => {
            if !bound.contains(n) {
                out.insert(n.clone());
            }
        }
        Expr::Int(_, _) | Expr::Str(_, _) | Expr::Con(_, _) => {}
        Expr::App(f, a, _) | Expr::BinOp(_, f, a, _) => {
            free_vars(f, bound, out);
            free_vars(a, bound, out);
        }
        Expr::If(c, t, el, _) => {
            free_vars(c, bound, out);
            free_vars(t, bound, out);
            free_vars(el, bound, out);
        }
        Expr::Tuple(es, _) => es.iter().for_each(|x| free_vars(x, bound, out)),
        Expr::RecordCon(_, fs, _) => fs.iter().for_each(|(_, x)| free_vars(x, bound, out)),
        Expr::RecordUpd(b, fs, _) => {
            free_vars(b, bound, out);
            fs.iter().for_each(|(_, x)| free_vars(x, bound, out));
        }
        Expr::Lam(ps, body, _) => {
            let mut b2 = bound.clone();
            let mut vs = Vec::new();
            ps.iter().for_each(|p| pat_vars(p, &mut vs));
            b2.extend(vs);
            free_vars(body, &b2, out);
        }
        Expr::Case(scrut, arms, _) => {
            free_vars(scrut, bound, out);
            for (pat, body) in arms {
                let mut b2 = bound.clone();
                let mut vs = Vec::new();
                pat_vars(pat, &mut vs);
                b2.extend(vs);
                free_vars(body, &b2, out);
            }
        }
        Expr::Let(binds, body, _) => {
            let mut b2 = bound.clone();
            b2.extend(binds.iter().map(|f| f.name.clone()));
            for f in binds {
                for c in &f.clauses {
                    let mut b3 = b2.clone();
                    let mut vs = Vec::new();
                    c.pats.iter().for_each(|p| pat_vars(p, &mut vs));
                    b3.extend(vs);
                    if let Body::Plain(e) = &c.body {
                        free_vars(e, &b3, out);
                    }
                }
            }
            free_vars(body, &b2, out);
        }
    }
}

fn find_lams<'a>(e: &'a Expr, out: &mut Vec<&'a Expr>) {
    if matches!(e, Expr::Lam(_, _, _)) {
        out.push(e);
    }
    match e {
        Expr::App(f, a, _) | Expr::BinOp(_, f, a, _) => {
            find_lams(f, out);
            find_lams(a, out);
        }
        Expr::If(c, t, el, _) => {
            find_lams(c, out);
            find_lams(t, out);
            find_lams(el, out);
        }
        Expr::Tuple(es, _) => es.iter().for_each(|x| find_lams(x, out)),
        Expr::RecordCon(_, fs, _) => fs.iter().for_each(|(_, x)| find_lams(x, out)),
        Expr::RecordUpd(b, fs, _) => {
            find_lams(b, out);
            fs.iter().for_each(|(_, x)| find_lams(x, out));
        }
        Expr::Case(s, arms, _) => {
            find_lams(s, out);
            arms.iter().for_each(|(_, body)| find_lams(body, out));
        }
        Expr::Let(binds, body, _) => {
            for f in binds {
                for c in &f.clauses {
                    if let Body::Plain(e) = &c.body {
                        find_lams(e, out);
                    }
                }
            }
            find_lams(body, out);
        }
        Expr::Lam(_, body, _) => find_lams(body, out),
        _ => {}
    }
}

/// Nomes resolvidos como globais (não capturados nem chamados por ponteiro):
/// funções de topo, locais de `where`, construtores, selectores e builtins.
fn global_names(module: &ast::Module) -> HashSet<String> {
    let mut g = HashSet::new();
    for f in &module.funcs {
        g.insert(f.name.clone());
        for c in &f.clauses {
            for w in &c.wher {
                g.insert(w.name.clone());
            }
        }
    }
    for d in &module.datas {
        for c in &d.cons {
            g.insert(c.name.clone());
            for fld in &c.fields {
                if !fld.name.is_empty() {
                    g.insert(fld.name.clone());
                }
            }
        }
    }
    for b in ["putStrLn", "show", "print"] {
        g.insert(b.to_string());
    }
    g
}

// --- a baixada AST → Core ---

type LamMeta = HashMap<Span, (String, Vec<String>)>;

/// Contexto de baixada: os nomes globais, os selectores de campo, o mangling de
/// `where` da função corrente, e a meta-informação das lambdas.
struct Lower<'a> {
    globals: &'a HashSet<String>,
    fields: &'a HashSet<String>,
    lam_meta: &'a LamMeta,
    locals: HashMap<String, String>,
    tmp: u32,
}

impl Lower<'_> {
    fn fresh(&mut self) -> String {
        let n = format!("_t{}", self.tmp);
        self.tmp += 1;
        n
    }

    /// Baixa `e` a um átomo, empilhando `let`s intermédios em `buf`.
    fn atom(&mut self, e: &Expr, buf: &mut Vec<(String, Rhs)>) -> Atom {
        match e {
            Expr::Int(n, _) => Atom::Int(*n),
            Expr::Str(s, _) => Atom::Str(s.clone()),
            Expr::Var(n, _) => Atom::Var(n.clone()),
            _ => {
                let rhs = self.rhs(e, buf);
                let name = self.fresh();
                buf.push((name.clone(), rhs));
                Atom::Var(name)
            }
        }
    }

    /// Baixa `e` a um `Rhs` (folha ou controlo), empilhando `let`s em `buf`.
    fn rhs(&mut self, e: &Expr, buf: &mut Vec<(String, Rhs)>) -> Rhs {
        match e {
            Expr::If(c, t, el, _) => {
                let ca = self.atom(c, buf);
                Rhs::If(ca, Box::new(self.term(t)), Box::new(self.term(el)))
            }
            Expr::Case(s, arms, _) => {
                let sa = self.atom(s, buf);
                let carms = arms
                    .iter()
                    .map(|(p, body)| (lower_pat(p), self.term(body)))
                    .collect();
                Rhs::Case(sa, carms)
            }
            Expr::Let(binds, body, _) => {
                // arrasta os binds triviais para `buf` e continua no corpo
                for f in binds {
                    let rhs = match f.clauses.as_slice() {
                        [c] if c.pats.is_empty() => match &c.body {
                            Body::Plain(e) => self.rhs(e, buf),
                            _ => Rhs::Op(Op::Unsupported("let com guardas".into())),
                        },
                        _ => Rhs::Op(Op::Unsupported("let não trivial".into())),
                    };
                    buf.push((f.name.clone(), rhs));
                }
                self.rhs(body, buf)
            }
            _ => Rhs::Op(self.op(e, buf)),
        }
    }

    /// Baixa `e` a um `Op`-folha (o chamador garante que não é if/case/let).
    fn op(&mut self, e: &Expr, buf: &mut Vec<(String, Rhs)>) -> Op {
        match e {
            Expr::Int(_, _) | Expr::Str(_, _) | Expr::Var(_, _) => Op::Atom(self.atom(e, buf)),
            Expr::BinOp(op, l, r, _) => {
                let a = self.atom(l, buf);
                let b = self.atom(r, buf);
                Op::Prim(op.clone(), a, b)
            }
            Expr::Tuple(es, _) => Op::MakeTuple(es.iter().map(|x| self.atom(x, buf)).collect()),
            Expr::RecordCon(con, assigns, _) => Op::MakeRecord {
                con: con.clone(),
                fields: assigns
                    .iter()
                    .map(|(f, x)| (f.clone(), self.atom(x, buf)))
                    .collect(),
            },
            Expr::RecordUpd(base, assigns, _) => {
                let b = self.atom(base, buf);
                Op::UpdateRecord {
                    base: b,
                    fields: assigns
                        .iter()
                        .map(|(f, x)| (f.clone(), self.atom(x, buf)))
                        .collect(),
                }
            }
            Expr::Lam(_, _, span) => match self.lam_meta.get(span) {
                Some((name, caps)) => Op::MakeClosure {
                    func: name.clone(),
                    captures: caps.iter().map(|c| Atom::Var(c.clone())).collect(),
                },
                None => Op::Unsupported("lambda não pré-processada".into()),
            },
            Expr::App(_, _, _) => self.app(e, buf),
            Expr::Con(name, _) => Op::CallDirect(name.clone(), Vec::new()),
            Expr::If(_, _, _, _) | Expr::Case(_, _, _) | Expr::Let(_, _, _) => {
                // controlo em posição de folha: nomeia-o via `buf`
                Op::Atom(self.atom(e, buf))
            }
        }
    }

    /// Baixa uma aplicação, classificando a cabeça (builtin / selector / chamada
    /// directa / chamada indirecta a closure).
    fn app(&mut self, e: &Expr, buf: &mut Vec<(String, Rhs)>) -> Op {
        let (head, args) = spine(e);
        let Expr::Var(name, _) = head else {
            // cabeça composta (ex.: lambda aplicada) → closure
            let clos = self.atom(head, buf);
            let vals = args.iter().map(|a| self.atom(a, buf)).collect();
            return Op::CallClosure(clos, vals);
        };
        if name == "putStrLn" && args.len() == 1 {
            return Op::PutStrLn(self.atom(args[0], buf));
        }
        if name == "show" && args.len() == 1 {
            return Op::ShowInt(self.atom(args[0], buf));
        }
        if self.fields.contains(name) && args.len() == 1 {
            let rec = self.atom(args[0], buf);
            return Op::Field {
                name: name.clone(),
                rec,
            };
        }
        let vals: Vec<Atom> = args.iter().map(|a| self.atom(a, buf)).collect();
        if self.globals.contains(name) {
            // função de topo / local de `where` (resolve o mangling)
            let target = self
                .locals
                .get(name)
                .cloned()
                .unwrap_or_else(|| name.clone());
            Op::CallDirect(target, vals)
        } else {
            // variável local de tipo-função → chamada indirecta
            Op::CallClosure(Atom::Var(name.clone()), vals)
        }
    }

    /// Baixa `e` a um `Term` (sequência de `let`s + resultado).
    fn term(&mut self, e: &Expr) -> Term {
        let mut buf = Vec::new();
        let rhs = self.rhs(e, &mut buf);
        wrap(buf, Term::Ret(rhs))
    }

    /// Desugar de multi-cláusula numa cadeia de `if` (exige catch-all no fim).
    fn clauses(&mut self, clauses: &[ast::Clause], params: &[String], i: usize) -> Term {
        let clause = &clauses[i];
        let lits: Vec<(usize, i64)> = clause
            .pats
            .iter()
            .enumerate()
            .filter_map(|(j, p)| match p {
                Pat::Int(n, _) => Some((j, *n)),
                _ => None,
            })
            .collect();

        // liga os padrões-variável desta cláusula aos parâmetros e emite o corpo
        let body_term = |me: &mut Self| -> Term {
            let mut inner = me.clause_body(clause);
            for (j, p) in clause.pats.iter().enumerate() {
                if let Pat::Var(n, _) = p {
                    inner = Term::Let(
                        n.clone(),
                        Rhs::Op(Op::Atom(Atom::Var(params[j].clone()))),
                        Box::new(inner),
                    );
                }
            }
            inner
        };

        if lits.is_empty() {
            return body_term(self);
        }
        if i + 1 >= clauses.len() {
            return Term::Ret(Rhs::Op(Op::Unsupported(
                "função sem cláusula catch-all".into(),
            )));
        }

        // cond = band(param_j == lit, …)
        let mut buf: Vec<(String, Rhs)> = Vec::new();
        let mut cond: Option<Atom> = None;
        for (j, lit) in &lits {
            let c = self.fresh();
            buf.push((
                c.clone(),
                Rhs::Op(Op::Prim(
                    "==".into(),
                    Atom::Var(params[*j].clone()),
                    Atom::Int(*lit),
                )),
            ));
            cond = Some(match cond {
                None => Atom::Var(c),
                Some(prev) => {
                    let a = self.fresh();
                    buf.push((
                        a.clone(),
                        Rhs::Op(Op::Prim("band".into(), prev, Atom::Var(c))),
                    ));
                    Atom::Var(a)
                }
            });
        }
        let then_t = body_term(self);
        let else_t = self.clauses(clauses, params, i + 1);
        wrap(
            buf,
            Term::Ret(Rhs::If(cond.unwrap(), Box::new(then_t), Box::new(else_t))),
        )
    }

    fn clause_body(&mut self, clause: &ast::Clause) -> Term {
        match &clause.body {
            Body::Plain(e) => self.term(e),
            Body::Guarded(_) => Term::Ret(Rhs::Op(Op::Unsupported("guardas".into()))),
        }
    }
}

fn lower_pat(p: &Pat) -> CPat {
    match p {
        Pat::Wild(_) => CPat::Wild,
        Pat::Var(n, _) => CPat::Var(n.clone()),
        Pat::Int(n, _) => CPat::Int(*n),
        Pat::Tuple(ps, _) => CPat::Tuple(ps.iter().map(lower_pat).collect()),
        Pat::Con(n, _, _) => CPat::Con(n.clone()),
    }
}

/// Enrola os `let`s de `buf` (na ordem) à volta de `tail`.
fn wrap(buf: Vec<(String, Rhs)>, tail: Term) -> Term {
    let mut term = tail;
    for (name, rhs) in buf.into_iter().rev() {
        term = Term::Let(name, rhs, Box::new(term));
    }
    term
}

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

/// Baixa o módulo para o Core: funções de topo candidatas, os seus locais de
/// `where` (mangled) e as lambdas liftadas (com captura).
pub fn lower(module: &ast::Module) -> Vec<CoreFn> {
    let data_types = data_type_names(module);
    let globals = global_names(module);
    let mut fields = HashSet::new();
    for d in &module.datas {
        for c in &d.cons {
            for fld in &c.fields {
                if !fld.name.is_empty() {
                    fields.insert(fld.name.clone());
                }
            }
        }
    }

    // pré-passo: nomeia + calcula capturas de todas as lambdas (por span)
    let mut lam_meta: LamMeta = HashMap::new();
    let mut lam_ctr = 0u32;
    let mut lam_sites: Vec<(&Expr, HashMap<String, String>)> = Vec::new();
    for f in &module.funcs {
        if top_candidate(f, &data_types).is_none() {
            continue;
        }
        let wheres: Vec<&ast::Func> = f.clauses.iter().flat_map(|c| &c.wher).collect();
        let mut locals = HashMap::new();
        for w in &wheres {
            locals.insert(w.name.clone(), format!("{}${}", f.name, w.name));
        }
        let mut nodes = Vec::new();
        for c in &f.clauses {
            if let Body::Plain(e) = &c.body {
                find_lams(e, &mut nodes);
            }
        }
        for w in &wheres {
            for c in &w.clauses {
                if let Body::Plain(e) = &c.body {
                    find_lams(e, &mut nodes);
                }
            }
        }
        for lam in nodes {
            let Expr::Lam(_, _, span) = lam else { continue };
            let mut fv = HashSet::new();
            free_vars(lam, &HashSet::new(), &mut fv);
            let mut captures: Vec<String> =
                fv.into_iter().filter(|n| !globals.contains(n)).collect();
            captures.sort();
            let name = format!("lam${lam_ctr}");
            lam_ctr += 1;
            lam_meta.insert(*span, (name, captures));
            lam_sites.push((lam, locals.clone()));
        }
    }

    let mut out = Vec::new();
    for f in &module.funcs {
        let Some(arity) = top_candidate(f, &data_types) else {
            continue;
        };
        let wheres: Vec<&ast::Func> = f.clauses.iter().flat_map(|c| &c.wher).collect();
        let mut locals = HashMap::new();
        for w in &wheres {
            locals.insert(w.name.clone(), format!("{}${}", f.name, w.name));
        }

        let mut lw = Lower {
            globals: &globals,
            fields: &fields,
            lam_meta: &lam_meta,
            locals: locals.clone(),
            tmp: 0,
        };
        let params: Vec<String> = (0..arity).map(|k| format!("_p{k}")).collect();
        out.push(CoreFn {
            name: f.name.clone(),
            params: params.clone(),
            captures: Vec::new(),
            is_closure: false,
            body: lw.clauses(&f.clauses, &params, 0),
        });

        for w in &wheres {
            let warity = w.clauses.first().map(|c| c.pats.len()).unwrap_or(0);
            let wparams: Vec<String> = (0..warity).map(|k| format!("_p{k}")).collect();
            let mut lw = Lower {
                globals: &globals,
                fields: &fields,
                lam_meta: &lam_meta,
                locals: locals.clone(),
                tmp: 0,
            };
            out.push(CoreFn {
                name: locals[&w.name].clone(),
                params: wparams.clone(),
                captures: Vec::new(),
                is_closure: false,
                body: lw.clauses(&w.clauses, &wparams, 0),
            });
        }
    }

    // as lambdas liftadas (na ordem em que foram numeradas)
    for (lam, locals) in lam_sites {
        let Expr::Lam(pats, body, span) = lam else {
            continue;
        };
        let (name, captures) = lam_meta[span].clone();
        let params: Vec<String> = pats
            .iter()
            .enumerate()
            .map(|(k, p)| match p {
                Pat::Var(n, _) => n.clone(),
                _ => format!("_w{k}"),
            })
            .collect();
        let mut lw = Lower {
            globals: &globals,
            fields: &fields,
            lam_meta: &lam_meta,
            locals,
            tmp: 0,
        };
        out.push(CoreFn {
            name,
            params,
            captures,
            is_closure: true,
            body: lw.term(body),
        });
    }

    out
}

// --- impressão do Core (`--emit core`) ---

pub fn dump(fns: &[CoreFn]) -> String {
    let mut s = String::new();
    for f in fns {
        let hdr = if f.is_closure {
            format!("[env {}]", f.captures.join(" "))
        } else {
            String::new()
        };
        s.push_str(&format!(
            "{} {}{} =\n",
            f.name,
            hdr,
            f.params.iter().map(|p| format!("{p} ")).collect::<String>()
        ));
        dump_term(&f.body, 1, &mut s);
        s.push('\n');
    }
    s
}

fn indent(n: usize, s: &mut String) {
    for _ in 0..n {
        s.push_str("  ");
    }
}

fn dump_term(t: &Term, n: usize, s: &mut String) {
    match t {
        Term::Let(name, rhs, body) => {
            indent(n, s);
            s.push_str(&format!("let {name} = "));
            dump_rhs(rhs, n, s);
            s.push('\n');
            dump_term(body, n, s);
        }
        Term::Ret(rhs) => {
            indent(n, s);
            s.push_str("ret ");
            dump_rhs(rhs, n, s);
            s.push('\n');
        }
    }
}

fn dump_rhs(rhs: &Rhs, n: usize, s: &mut String) {
    match rhs {
        Rhs::Op(op) => s.push_str(&dump_op(op)),
        Rhs::If(c, t, e) => {
            s.push_str(&format!("if {} then\n", atom(c)));
            dump_term(t, n + 1, s);
            indent(n, s);
            s.push_str("else\n");
            dump_term(e, n + 1, s);
        }
        Rhs::Case(sc, arms) => {
            s.push_str(&format!("case {} of\n", atom(sc)));
            for (p, body) in arms {
                indent(n + 1, s);
                s.push_str(&format!("{} ->\n", cpat(p)));
                dump_term(body, n + 2, s);
            }
        }
    }
}

fn dump_op(op: &Op) -> String {
    match op {
        Op::Atom(a) => atom(a),
        Op::Prim(o, a, b) => format!("{o} {} {}", atom(a), atom(b)),
        Op::CallDirect(f, xs) => format!("call {f}{}", args(xs)),
        Op::CallClosure(c, xs) => format!("callclo {}{}", atom(c), args(xs)),
        Op::MakeClosure { func, captures } => format!("closure {func}{}", args(captures)),
        Op::MakeTuple(xs) => format!("tuple{}", args(xs)),
        Op::MakeRecord { con, fields } => format!(
            "record {con} {{{}}}",
            fields
                .iter()
                .map(|(f, a)| format!(" {f} = {}", atom(a)))
                .collect::<String>()
        ),
        Op::UpdateRecord { base, fields } => format!(
            "update {} {{{}}}",
            atom(base),
            fields
                .iter()
                .map(|(f, a)| format!(" {f} = {}", atom(a)))
                .collect::<String>()
        ),
        Op::Field { name, rec } => format!("field {name} {}", atom(rec)),
        Op::PutStrLn(a) => format!("putStrLn {}", atom(a)),
        Op::ShowInt(a) => format!("show {}", atom(a)),
        Op::Unsupported(m) => format!("<unsupported: {m}>"),
    }
}

fn args(xs: &[Atom]) -> String {
    xs.iter().map(|a| format!(" {}", atom(a))).collect()
}

fn atom(a: &Atom) -> String {
    match a {
        Atom::Int(n) => n.to_string(),
        Atom::Str(s) => format!("{s:?}"),
        Atom::Var(n) => n.clone(),
    }
}

fn cpat(p: &CPat) -> String {
    match p {
        CPat::Int(n) => n.to_string(),
        CPat::Var(n) => n.clone(),
        CPat::Wild => "_".into(),
        CPat::Tuple(ps) => format!("({})", ps.iter().map(cpat).collect::<Vec<_>>().join(", ")),
        CPat::Con(n) => n.clone(),
    }
}
