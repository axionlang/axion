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
//! O **Drop estrutural** (Auto-Drop §2) é um **nó explícito** do Core: uma
//! análise de reclamação (`insert_drops`) insere `drop x` no ponto de morte dos
//! objectos que a função possui (locais, resultados de chamada, params `%1`) e
//! que não escapam; o runtime liberta-os (`axion_free`). As **arenas** (§3)
//! também têm Ops próprios (`WithArena`/`ArenaAlloc`/`Promote`/`ArenaMark`/…) e
//! um runtime bump com reset em massa. O **in-place** (Linear Elision, §2) é um
//! flag no `Op::UpdateRecord`: se o `check.rs` provar que o base é linear e morre
//! ali, muta-se o bloco existente em vez de alocar+copiar.

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
    /// construir um valor `data` posicional `Con a b …` (tipos-soma incluídos —
    /// leva o tag se o tipo tiver >1 construtor).
    MakeCon {
        con: String,
        args: Vec<Atom>,
    },
    /// actualizar registo `base { campo = átomo, … }`. `inplace` (Linear Elision,
    /// §2): o base é linear e morre aqui → muta-se o bloco existente em vez de
    /// alocar+copiar (o `check.rs` prova a segurança).
    UpdateRecord {
        base: Atom,
        fields: Vec<(String, Atom)>,
        inplace: bool,
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
    // --- arenas (§3): a `clos` recebe a arena; no fim faz-se o reset ---
    /// `withArena`/`withSubArena`: cria a (sub-)arena, corre `clos` com ela, e
    /// **reseta-a** no fim (reclamação em massa). `parent` só serve o `promote`.
    WithArena {
        parent: Option<Atom>,
        clos: Atom,
    },
    /// `allocateCell arena` — bump-alloca uma célula na arena.
    ArenaAlloc(Atom),
    /// `promote target cell` — copia a célula para a arena `target` (safa-a do reset).
    Promote(Atom, Atom),
    /// `arena_mark arena` — guarda o topo do bump-pointer.
    ArenaMark(Atom),
    /// `arena_release mark` — repõe o bump-pointer (reclama o alocado desde a marca).
    ArenaRelease(Atom),
    /// Chamada a uma função de runtime nomeada (builtins de `Buffer`/§4 e afins):
    /// `func(args…)`, devolvendo valor sse `returns`.
    RtCall {
        func: String,
        args: Vec<Atom>,
        returns: bool,
    },
    /// Chamada FFI (§18): a função C `name` com ABI de Int (i64), resolvida por
    /// `dlsym`. Devolve i64.
    Ffi {
        name: String,
        args: Vec<Atom>,
    },
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
    /// `drop x; …` — liberta o objecto de heap `x` no seu ponto de morte
    /// (Auto-Drop, §2; inserido pela análise de reclamação, não pela baixada).
    Drop(String, Box<Term>),
    Ret(Rhs),
}

/// Padrões de `case` suportados nativamente.
#[derive(Debug, Clone)]
pub enum CPat {
    Int(i64),
    Var(String),
    Wild,
    Tuple(Vec<CPat>),
    /// construtor + sub-padrões. Tipos de 1 construtor destructuram sem tag;
    /// tipos-soma comparam o tag (offset 0) do valor com o do construtor.
    Con(String, Vec<CPat>),
}

/// Uma função no Core: de topo, local de `where`, ou lambda liftada.
#[derive(Debug, Clone)]
pub struct CoreFn {
    pub name: String,
    pub params: Vec<String>,
    /// nomes capturados (vazio para não-lambdas); carregados do env em codegen
    pub captures: Vec<String>,
    pub is_closure: bool,
    /// parâmetros `%1` de tipo-heap: o callee **possui-os** e liberta-os no seu
    /// ponto de morte (reclamação entre funções — Auto-Drop, §2)
    pub owned_params: Vec<String>,
    pub body: Term,
}

// --- classificação de tipos nativos (partilhada com o codegen) ---

/// Tipos representados por um `i64`: `Int`, `String`, `IO`, um `data`, ou uma
/// função (ponteiro para closure `{fn_ptr, capturas…}`).
pub fn native_ty(t: &Type, data_types: &HashSet<String>) -> bool {
    if matches!(t, Type::Arrow { .. } | Type::Unit) {
        return true;
    }
    match t.head_con() {
        // Int/String/IO; arena (Arena/Cell/Mark); Buffer (§4); unit-token;
        // inteiros de largura fixa (§4) — i64 na ABI
        Some(
            "Int" | "String" | "IO" | "Arena" | "Cell" | "Mark" | "Buffer" | "()" | "U8" | "U16"
            | "U32" | "U64" | "I8" | "I16" | "I32" | "I64" | "Word" | "Byte",
        ) => true,
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

/// Tipo alocado na heap por `axion_alloc` (registo/`data` ou tuplo). Exclui
/// `Int`/`IO` (i64 puro), `String` (C-string do runtime, não é nossa) e funções
/// (as closures são reclamadas conservadoramente — podem ser chamadas).
fn heap_ty(t: &Type, data_types: &HashSet<String>) -> bool {
    match t {
        Type::Tuple(_) => true,
        _ => t.head_con().is_some_and(|h| data_types.contains(h)),
    }
}

pub fn is_int(t: &Type) -> bool {
    matches!(t.head_con(), Some("Int"))
}

pub fn data_type_names(module: &ast::Module) -> HashSet<String> {
    module.datas.iter().map(|d| d.name.clone()).collect()
}

/// Layout dos registos/valores `data`. Um tipo de **um só** construtor não tem
/// tag: `[campo0][campo1]…` (campo i em i×8). Um tipo-**soma** (multi-construtor)
/// leva um **tag** (o índice do construtor) no offset 0: `[tag][campo0]…` (campo
/// i em (1+i)×8). Partilhado pelos backends; um `i64` por slot.
#[derive(Default)]
pub struct RecordInfo {
    con_fields: HashMap<String, Vec<String>>, // campos com nome
    field_owner: HashMap<String, String>,
    single_con: HashSet<String>,   // construtores sem tag (tipo de 1 con)
    con_tag: HashMap<String, i32>, // índice do construtor no seu tipo
    con_arity: HashMap<String, usize>, // nº total de campos (com ou sem nome)
}

impl RecordInfo {
    pub fn build(module: &ast::Module) -> RecordInfo {
        let mut r = RecordInfo::default();
        for d in &module.datas {
            for (idx, c) in d.cons.iter().enumerate() {
                let fields: Vec<String> = c
                    .fields
                    .iter()
                    .filter(|f| !f.name.is_empty())
                    .map(|f| f.name.clone())
                    .collect();
                for f in &fields {
                    r.field_owner.insert(f.clone(), c.name.clone());
                }
                r.con_fields.insert(c.name.clone(), fields);
                r.con_tag.insert(c.name.clone(), idx as i32);
                r.con_arity.insert(c.name.clone(), c.fields.len());
                if d.cons.len() == 1 {
                    r.single_con.insert(c.name.clone());
                }
            }
        }
        r
    }

    /// `true` se o construtor pertence a um tipo com um só construtor (sem tag).
    pub fn is_single_con(&self, con: &str) -> bool {
        self.single_con.contains(con)
    }

    /// O tag (índice) de um construtor, se o seu tipo for uma soma (>1 con).
    pub fn tag(&self, con: &str) -> Option<i32> {
        (!self.is_single_con(con))
            .then(|| self.con_tag.get(con).copied())
            .flatten()
    }

    /// Aridade total (campos com ou sem nome) de um construtor.
    pub fn con_arity(&self, con: &str) -> Option<usize> {
        self.con_arity.get(con).copied()
    }

    /// Nº de slots a alocar para um construtor (campos + eventual tag).
    pub fn con_slots(&self, con: &str) -> Option<usize> {
        self.con_arity(con)
            .map(|n| n + usize::from(self.tag(con).is_some()))
    }

    /// Offset do i-ésimo campo (posicional) de um construtor (ajustado ao tag).
    pub fn field_offset(&self, con: &str, i: usize) -> i32 {
        let base = usize::from(self.tag(con).is_some());
        (base + i) as i32 * 8
    }

    /// Offset (em bytes) de um campo com nome, e a lista de campos do seu registo.
    pub fn field(&self, name: &str) -> Option<(i32, &[String])> {
        let con = self.field_owner.get(name)?;
        let fields = self.con_fields.get(con)?;
        let idx = fields.iter().position(|f| f == name)?;
        Some((self.field_offset(con, idx), fields))
    }
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
    for b in [
        "putStrLn",
        "show",
        "print",
        "withArena",
        "withSubArena",
        "allocateCell",
        "promote",
        "arena_mark",
        "arena_release",
        "newBuffer",
        "withBuffer",
        "bufIota",
        "xorInPlace",
        "sumBytes",
        "free",
        "imperative",
    ] {
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
    /// spans dos `RecordUpd` elegíveis a mutação in-place (Linear Elision, §2)
    inplace: &'a HashSet<Span>,
    /// nomes das importações FFI (§18) — chamadas via `Op::Ffi`
    foreigns: &'a HashSet<String>,
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
            Expr::RecordUpd(base, assigns, span) => {
                let b = self.atom(base, buf);
                Op::UpdateRecord {
                    base: b,
                    fields: assigns
                        .iter()
                        .map(|(f, x)| (f.clone(), self.atom(x, buf)))
                        .collect(),
                    inplace: self.inplace.contains(span),
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
            Expr::Con(name, _) => match name.as_str() {
                "True" => Op::Atom(Atom::Int(1)),
                "False" => Op::Atom(Atom::Int(0)),
                // construtor nulário (ex.: `Nothing`)
                _ => Op::MakeCon {
                    con: name.clone(),
                    args: Vec::new(),
                },
            },
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
        // construtor aplicado `Con a b …` → valor `data` posicional
        if let Expr::Con(cname, _) = head {
            let vals = args.iter().map(|a| self.atom(a, buf)).collect();
            return Op::MakeCon {
                con: cname.clone(),
                args: vals,
            };
        }
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
        // builtins de arena (§3)
        match (name.as_str(), args.len()) {
            ("withArena", 1) => {
                let clos = self.atom(args[0], buf);
                return Op::WithArena { parent: None, clos };
            }
            ("withSubArena", 2) => {
                let parent = self.atom(args[0], buf);
                let clos = self.atom(args[1], buf);
                return Op::WithArena {
                    parent: Some(parent),
                    clos,
                };
            }
            ("allocateCell", 1) => return Op::ArenaAlloc(self.atom(args[0], buf)),
            ("promote", 2) => {
                let target = self.atom(args[0], buf);
                let cell = self.atom(args[1], buf);
                return Op::Promote(target, cell);
            }
            ("arena_mark", 1) => return Op::ArenaMark(self.atom(args[0], buf)),
            ("arena_release", 1) => return Op::ArenaRelease(self.atom(args[0], buf)),
            // Buffer U8 linear (§4/§5): builtins que são chamadas de runtime
            ("newBuffer", 1) => return self.rtcall("axion_buf_new", &args, true, buf),
            ("bufIota", 1) => return self.rtcall("axion_buf_iota", &args, true, buf),
            ("xorInPlace", 2) => return self.rtcall("axion_buf_xor", &args, true, buf),
            ("sumBytes", 1) => return self.rtcall("axion_buf_sum", &args, true, buf),
            ("free", 1) => return self.rtcall("axion_buf_free", &args, false, buf),
            ("foldBytes", 3) => return self.rtcall("axion_fold_bytes", &args, true, buf),
            // `imperative e` = e (o bloco imperativo é identidade; §5)
            ("imperative", 1) => return self.op(args[0], buf),
            // withBuffer n f = f (newBuffer n): aloca e passa à closure (que consome)
            ("withBuffer", 2) => {
                let n = self.atom(args[0], buf);
                let clos = self.atom(args[1], buf);
                let b = self.fresh();
                buf.push((
                    b.clone(),
                    Rhs::Op(Op::RtCall {
                        func: "axion_buf_new".into(),
                        args: vec![n],
                        returns: true,
                    }),
                ));
                return Op::CallClosure(clos, vec![Atom::Var(b)]);
            }
            _ => {}
        }
        let vals: Vec<Atom> = args.iter().map(|a| self.atom(a, buf)).collect();
        if self.foreigns.contains(name) {
            // importação FFI (§18): chamada C com ABI de Int
            Op::Ffi {
                name: name.clone(),
                args: vals,
            }
        } else if self.globals.contains(name) {
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

    /// Baixa um builtin que é chamada de runtime (`Buffer`/§4).
    fn rtcall(
        &mut self,
        func: &str,
        args: &[&Expr],
        returns: bool,
        buf: &mut Vec<(String, Rhs)>,
    ) -> Op {
        Op::RtCall {
            func: func.to_string(),
            args: args.iter().map(|a| self.atom(a, buf)).collect(),
            returns,
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
            Body::Guarded(arms) => self.guarded(arms),
        }
    }

    /// Guardas → cadeia de `if`: `| g0 = r0 | g1 = r1 | otherwise = rn` vira
    /// `if g0 then r0 else if g1 then r1 else rn`. `otherwise`/`True` são
    /// incondicionais; se nenhuma guarda cobrir, é exaustão (não-suportado).
    fn guarded(&mut self, arms: &[(Expr, Expr)]) -> Term {
        let mut acc = Term::Ret(Rhs::Op(Op::Unsupported("guardas não exaustivas".into())));
        for (g, r) in arms.iter().rev() {
            let uncond = matches!(g, Expr::Var(n, _) if n == "otherwise")
                || matches!(g, Expr::Con(n, _) if n == "True");
            let rterm = self.term(r);
            if uncond {
                acc = rterm;
            } else {
                let mut buf = Vec::new();
                let ga = self.atom(g, &mut buf);
                acc = wrap(buf, Term::Ret(Rhs::If(ga, Box::new(rterm), Box::new(acc))));
            }
        }
        acc
    }
}

fn lower_pat(p: &Pat) -> CPat {
    match p {
        Pat::Wild(_) => CPat::Wild,
        Pat::Var(n, _) => CPat::Var(n.clone()),
        Pat::Int(n, _) => CPat::Int(*n),
        Pat::Tuple(ps, _) => CPat::Tuple(ps.iter().map(lower_pat).collect()),
        Pat::Con(n, ps, _) => CPat::Con(n.clone(), ps.iter().map(lower_pat).collect()),
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

/// Baixa uma função (de topo ou `where`), devolvendo `(params, corpo,
/// params-possuídos)`. Funções de cláusula única com padrões só variável/`_`
/// nomeiam os parâmetros directamente (sem o alias redundante `let n = _p0`),
/// o que dá um Core mais legível e nomes limpos para a reclamação de params.
#[allow(clippy::too_many_arguments)]
fn lower_func(
    f: &ast::Func,
    arity: usize,
    locals: &HashMap<String, String>,
    globals: &HashSet<String>,
    fields: &HashSet<String>,
    lam_meta: &LamMeta,
    inplace: &HashSet<Span>,
    foreigns: &HashSet<String>,
    data_types: &HashSet<String>,
) -> (Vec<String>, Term, Vec<String>) {
    let mut lw = Lower {
        globals,
        fields,
        lam_meta,
        inplace,
        foreigns,
        locals: locals.clone(),
        tmp: 0,
    };
    let single_var = f.clauses.len() == 1
        && f.clauses[0]
            .pats
            .iter()
            .all(|p| matches!(p, Pat::Var(_, _) | Pat::Wild(_)));
    let (params, body) = if single_var {
        let params: Vec<String> = f.clauses[0]
            .pats
            .iter()
            .enumerate()
            .map(|(k, p)| match p {
                Pat::Var(n, _) => n.clone(),
                _ => format!("_w{k}"),
            })
            .collect();
        let body = match &f.clauses[0].body {
            Body::Plain(e) => lw.term(e),
            Body::Guarded(arms) => lw.guarded(arms),
        };
        (params, body)
    } else {
        let params: Vec<String> = (0..arity).map(|k| format!("_p{k}")).collect();
        let body = lw.clauses(&f.clauses, &params, 0);
        (params, body)
    };
    // parâmetros `%1` de tipo-heap → o callee possui-os e liberta-os
    let owned: Vec<String> = match &f.sig {
        Some(sig) => {
            let mults = sig.param_mults();
            let ptypes = sig.param_types();
            (0..params.len())
                .filter(|&i| {
                    mults.get(i) == Some(&ast::Mult::One)
                        && ptypes.get(i).is_some_and(|t| heap_ty(t, data_types))
                })
                .map(|i| params[i].clone())
                .collect()
        }
        None => Vec::new(),
    };
    (params, body, owned)
}

/// Baixa o módulo para o Core: funções de topo candidatas, os seus locais de
/// `where` (mangled) e as lambdas liftadas (com captura).
pub fn lower(module: &ast::Module, inplace: &HashSet<Span>) -> Vec<CoreFn> {
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
    // funções cujo retorno é um objecto de heap → o resultado da chamada passa
    // a ser propriedade do chamador (reclamável quando morre e não escapa)
    let heap_ret: HashSet<String> = module
        .funcs
        .iter()
        .filter(|f| {
            f.sig
                .as_ref()
                .is_some_and(|s| heap_ty(result_type(s), &data_types))
        })
        .map(|f| f.name.clone())
        .collect();
    let foreigns: HashSet<String> = module.foreigns.iter().map(|f| f.name.clone()).collect();

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

        let (params, body, owned) = lower_func(
            f,
            arity,
            &locals,
            &globals,
            &fields,
            &lam_meta,
            inplace,
            &foreigns,
            &data_types,
        );
        out.push(CoreFn {
            name: f.name.clone(),
            params,
            captures: Vec::new(),
            is_closure: false,
            owned_params: owned,
            body,
        });

        for w in &wheres {
            let warity = w.clauses.first().map(|c| c.pats.len()).unwrap_or(0);
            let (wp, wb, wo) = lower_func(
                w,
                warity,
                &locals,
                &globals,
                &fields,
                &lam_meta,
                inplace,
                &foreigns,
                &data_types,
            );
            out.push(CoreFn {
                name: locals[&w.name].clone(),
                params: wp,
                captures: Vec::new(),
                is_closure: false,
                owned_params: wo,
                body: wb,
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
            inplace,
            foreigns: &foreigns,
            locals,
            tmp: 0,
        };
        out.push(CoreFn {
            name,
            params,
            captures,
            is_closure: true,
            owned_params: Vec::new(),
            body: lw.term(body),
        });
    }

    // multiplicidades dos parâmetros das funções de topo com assinatura, para a
    // reclamação de argumentos emprestados
    let param_mults: HashMap<String, Vec<ast::Mult>> = module
        .funcs
        .iter()
        .filter_map(|f| f.sig.as_ref().map(|s| (f.name.clone(), s.param_mults())))
        .collect();
    let borrow_args = compute_borrow_args(&out, &param_mults);

    out.into_iter()
        .map(|f| insert_drops(f, &heap_ret, &borrow_args))
        .collect()
}

// --- análise de reclamação: Drop estrutural (Auto-Drop §2) ---
//
// Insere nós `drop` no Core que libertam objectos de heap **locais** no seu
// ponto de morte. Um objecto é *droppable* se for alocado na função (via
// `Make{Tuple,Record,Closure}` ou `UpdateRecord`) e **nunca escapar**: nunca é
// devolvido, embebido noutro objecto, passado a uma chamada, nem aliased. As
// suas ocorrências são então todas leituras locais (`Field`, escrutínio de
// `case`), pelo que libertá-lo após a última leitura é são (a disciplina linear
// garante ausência de aliasing; o objecto não é alcançável por ninguém). Os
// casos que escapam ou mudam de dono ficam por libertar (conservador — são),
// tal como a reclamação entre funções e o reset de arena (incrementos
// seguintes).

/// Reclamação de argumentos emprestados (§2): mapa nome-de-função → índices de
/// parâmetros que são *empréstimos puros* — parâmetros `Many` (o chamador retém
/// a posse) que o corpo **só lê localmente** (`Field.rec`/escrutínio de `case`),
/// nunca os devolvendo, embebendo, aliasing nem passando adiante. Como o callee
/// não os retém, o chamador pode libertar o argumento **após** a chamada, em vez
/// de o dar por perdido. Conservador: um parâmetro passado a *qualquer* chamada
/// (mesmo que essa a empreste também) conta como escape (sem ponto-fixo entre
/// funções); e só se sabe o multiplicidade de funções de topo com assinatura.
type BorrowArgs = HashMap<String, HashSet<usize>>;

fn atom_is(v: &str, a: &Atom) -> bool {
    matches!(a, Atom::Var(n) if n == v)
}

/// `true` se `v` aparece nalguma posição que **não** seja leitura local dentro
/// de `t` — i.e. escapa do callee (devolvido, embebido, aliased, ou passado a
/// uma chamada). Um parâmetro `Many` para o qual isto é `false` é empréstimo puro.
fn occurs_nonborrow(v: &str, t: &Term) -> bool {
    match t {
        Term::Let(_, rhs, body) => rhs_nonborrow(v, rhs) || occurs_nonborrow(v, body),
        Term::Drop(_, body) => occurs_nonborrow(v, body),
        Term::Ret(rhs) => rhs_nonborrow(v, rhs),
    }
}

fn rhs_nonborrow(v: &str, rhs: &Rhs) -> bool {
    match rhs {
        Rhs::Op(op) => op_nonborrow(v, op),
        // condição de `if`/escrutínio de `case` são leituras locais (empréstimo)
        Rhs::If(_, t, e) => occurs_nonborrow(v, t) || occurs_nonborrow(v, e),
        Rhs::Case(_, arms) => arms.iter().any(|(_, b)| occurs_nonborrow(v, b)),
    }
}

fn op_nonborrow(v: &str, op: &Op) -> bool {
    match op {
        Op::Field { .. } => false,    // ler um campo é empréstimo
        Op::Atom(a) => atom_is(v, a), // alias/retorno
        Op::Prim(_, a, b) => atom_is(v, a) || atom_is(v, b),
        Op::CallDirect(_, xs) | Op::CallClosure(_, xs) => xs.iter().any(|a| atom_is(v, a)),
        Op::MakeTuple(xs) | Op::MakeCon { args: xs, .. } => xs.iter().any(|a| atom_is(v, a)),
        Op::MakeRecord { fields, .. } => fields.iter().any(|(_, a)| atom_is(v, a)),
        Op::UpdateRecord {
            base,
            fields,
            inplace,
        } => {
            // update por cópia lê a base (empréstimo) e aloca um registo novo com
            // cópias dos campos; in-place muta a base e devolve-a (escape). Copiar
            // um campo linear seria rejeitado pela linearidade, logo os campos
            // copiados são não-lineares (aliasing seguro, sem dupla-free).
            (*inplace && atom_is(v, base)) || fields.iter().any(|(_, a)| atom_is(v, a))
        }
        Op::MakeClosure { captures, .. } => captures.iter().any(|a| atom_is(v, a)),
        Op::WithArena { parent, clos } => parent.iter().any(|a| atom_is(v, a)) || atom_is(v, clos),
        Op::ArenaAlloc(a) | Op::ArenaMark(a) | Op::ArenaRelease(a) => atom_is(v, a),
        Op::Promote(t, c) => atom_is(v, t) || atom_is(v, c),
        Op::RtCall { args, .. } | Op::Ffi { args, .. } => args.iter().any(|a| atom_is(v, a)),
        Op::PutStrLn(a) | Op::ShowInt(a) => atom_is(v, a),
        Op::Unsupported(_) => false,
    }
}

/// Calcula os empréstimos puros de cada função de topo (as que têm assinatura,
/// logo multiplicidade conhecida). Ver [`BorrowArgs`].
fn compute_borrow_args(
    fns: &[CoreFn],
    param_mults: &HashMap<String, Vec<ast::Mult>>,
) -> BorrowArgs {
    let mut out = HashMap::new();
    for f in fns {
        let Some(mults) = param_mults.get(&f.name) else {
            continue;
        };
        let mut set = HashSet::new();
        for (i, pname) in f.params.iter().enumerate() {
            // emprestado (não `%1` → o chamador retém a posse) e só lido localmente
            let borrowed = mults.get(i) != Some(&ast::Mult::One);
            if borrowed && !occurs_nonborrow(pname, &f.body) {
                set.insert(i);
            }
        }
        if !set.is_empty() {
            out.insert(f.name.clone(), set);
        }
    }
    out
}

/// Uso de um átomo, se for uma variável droppable.
fn atom_use(a: &Atom, drp: &HashSet<String>, out: &mut HashSet<String>) {
    if let Atom::Var(n) = a {
        if drp.contains(n) {
            out.insert(n.clone());
        }
    }
}

/// Variáveis droppable **lidas** algalgures em `t` (posições de leitura de heap:
/// `Field.rec` e escrutínio de `case`).
fn fv_drop(t: &Term, drp: &HashSet<String>, ba: &BorrowArgs, out: &mut HashSet<String>) {
    match t {
        Term::Let(_, rhs, body) => {
            fv_rhs(rhs, drp, ba, out);
            fv_drop(body, drp, ba, out);
        }
        Term::Drop(_, body) => fv_drop(body, drp, ba, out),
        Term::Ret(rhs) => fv_rhs(rhs, drp, ba, out),
    }
}

fn fv_rhs(rhs: &Rhs, drp: &HashSet<String>, ba: &BorrowArgs, out: &mut HashSet<String>) {
    match rhs {
        Rhs::Op(op) => fv_op(op, drp, ba, out),
        Rhs::If(c, t, e) => {
            atom_use(c, drp, out);
            fv_drop(t, drp, ba, out);
            fv_drop(e, drp, ba, out);
        }
        Rhs::Case(s, arms) => {
            atom_use(s, drp, out);
            for (_, b) in arms {
                fv_drop(b, drp, ba, out);
            }
        }
    }
}

fn fv_op(op: &Op, drp: &HashSet<String>, ba: &BorrowArgs, out: &mut HashSet<String>) {
    // `Field` lê uma droppable (o registo). Uma chamada directa a uma função com
    // parâmetros de empréstimo puro **também** conta como uso do argumento (a
    // liberta-se após a chamada, não antes). Os restantes args escapam (movem-se
    // para o callee) → droppable não aparece lá. Prim opera sobre Ints.
    match op {
        Op::Field { rec, .. } => atom_use(rec, drp, out),
        // a closure passada a `withArena` é usada durante a chamada e morre a
        // seguir → conta como uso para o drop cair DEPOIS (como um arg emprestado)
        Op::WithArena { clos, .. } => atom_use(clos, drp, out),
        Op::CallDirect(g, xs) => {
            if let Some(bs) = ba.get(g) {
                for (i, a) in xs.iter().enumerate() {
                    if bs.contains(&i) {
                        atom_use(a, drp, out);
                    }
                }
            }
        }
        _ => {}
    }
}

/// O conjunto droppable de uma função: objectos que ela **possui** — alocados
/// localmente (`Make*`), resultados de chamadas que devolvem heap (`heap_ret`),
/// e os seus parâmetros `%1` de heap — menos os que escapam.
fn droppable_vars(f: &CoreFn, heap_ret: &HashSet<String>, ba: &BorrowArgs) -> HashSet<String> {
    let mut allocated: HashSet<String> = f.owned_params.iter().cloned().collect();
    let mut escaped = HashSet::new();
    scan_body(&f.body, heap_ret, ba, &mut allocated, &mut escaped);
    allocated.difference(&escaped).cloned().collect()
}

fn scan_body(
    t: &Term,
    heap_ret: &HashSet<String>,
    ba: &BorrowArgs,
    alloc: &mut HashSet<String>,
    esc: &mut HashSet<String>,
) {
    match t {
        Term::Let(x, rhs, body) => {
            match rhs {
                Rhs::Op(op) => {
                    // alocação local, ou resultado de chamada que devolve heap
                    if is_heap_alloc(op) || returns_owned_heap(op, heap_ret) {
                        alloc.insert(x.clone());
                    }
                    scan_op_escapes(op, ba, esc);
                }
                Rhs::If(_, t2, e2) => {
                    scan_body(t2, heap_ret, ba, alloc, esc);
                    scan_body(e2, heap_ret, ba, alloc, esc);
                }
                Rhs::Case(_, arms) => arms
                    .iter()
                    .for_each(|(_, b)| scan_body(b, heap_ret, ba, alloc, esc)),
            }
            scan_body(body, heap_ret, ba, alloc, esc);
        }
        Term::Drop(_, body) => scan_body(body, heap_ret, ba, alloc, esc),
        Term::Ret(rhs) => match rhs {
            Rhs::Op(op) => scan_op_escapes_ret(op, ba, esc),
            Rhs::If(_, t2, e2) => {
                scan_body(t2, heap_ret, ba, alloc, esc);
                scan_body(e2, heap_ret, ba, alloc, esc);
            }
            Rhs::Case(_, arms) => arms
                .iter()
                .for_each(|(_, b)| scan_body(b, heap_ret, ba, alloc, esc)),
        },
    }
}

/// Uma chamada directa a uma função que devolve heap → o resultado é do chamador.
fn returns_owned_heap(op: &Op, heap_ret: &HashSet<String>) -> bool {
    matches!(op, Op::CallDirect(name, _) if heap_ret.contains(name))
}

fn is_heap_alloc(op: &Op) -> bool {
    matches!(
        op,
        Op::MakeTuple(_) | Op::MakeRecord { .. } | Op::UpdateRecord { .. } | Op::MakeClosure { .. }
    )
}

/// Nomes de variáveis que escapam por aparecerem numa posição de dono
/// (argumento de chamada, embebimento noutro objecto, alias directo).
fn scan_op_escapes(op: &Op, ba: &BorrowArgs, esc: &mut HashSet<String>) {
    let mut mark = |a: &Atom| {
        if let Atom::Var(n) = a {
            esc.insert(n.clone());
        }
    };
    match op {
        Op::Atom(a) => mark(a), // alias directo `let y = x`
        // uma chamada directa move os argumentos para o callee — excepto os que
        // ela apenas empresta (empréstimo puro), que o chamador retém e liberta
        Op::CallDirect(g, xs) => {
            let borrow = ba.get(g);
            for (i, a) in xs.iter().enumerate() {
                if borrow.is_none_or(|bs| !bs.contains(&i)) {
                    mark(a);
                }
            }
        }
        Op::CallClosure(_, xs) => xs.iter().for_each(&mut mark),
        Op::MakeTuple(xs) | Op::MakeCon { args: xs, .. } => xs.iter().for_each(&mut mark),
        Op::MakeRecord { fields, .. } | Op::UpdateRecord { fields, .. } => {
            fields.iter().for_each(|(_, a)| mark(a))
        }
        Op::MakeClosure { captures, .. } => captures.iter().for_each(&mut mark),
        // arenas: os seus objectos (arena/célula/closure) são geridos pelo reset
        // da arena, não pelo Auto-Drop — marcam-se como escape para o ignorar.
        // a arena/pai são geridos pelo reset; a closure, porém, é um objecto de
        // heap normal que o `withArena` apenas *empresta* (chama-a e retorna) —
        // não escapa, é reclamável após a chamada (ver `fv_op`).
        Op::WithArena { parent, .. } => parent.iter().for_each(&mut mark),
        Op::ArenaAlloc(a) | Op::ArenaMark(a) | Op::ArenaRelease(a) => mark(a),
        Op::Promote(t, c) => {
            mark(t);
            mark(c);
        }
        Op::RtCall { args, .. } | Op::Ffi { args, .. } => args.iter().for_each(&mut mark),
        _ => {}
    }
    // a closure receptora de uma chamada indirecta também muda de mãos
    if let Op::CallClosure(c, _) = op {
        mark(c);
    }
}

fn scan_op_escapes_ret(op: &Op, ba: &BorrowArgs, esc: &mut HashSet<String>) {
    scan_op_escapes(op, ba, esc);
    // o valor devolvido escapa
    if let Op::Atom(Atom::Var(n)) = op {
        esc.insert(n.clone());
    }
}

/// Insere os `drop`s numa função (Drop estrutural + reclamação entre funções).
fn insert_drops(mut f: CoreFn, heap_ret: &HashSet<String>, ba: &BorrowArgs) -> CoreFn {
    let drp = droppable_vars(&f, heap_ret, ba);
    if drp.is_empty() {
        return f;
    }
    let mut e = Elab {
        drp,
        tmp: 1_000_000,
        ba,
    };
    let body = std::mem::replace(&mut f.body, Term::Ret(Rhs::Op(Op::Atom(Atom::Int(0)))));
    f.body = e.go(body, &HashSet::new());
    f
}

struct Elab<'a> {
    drp: HashSet<String>,
    tmp: u32,
    ba: &'a BorrowArgs,
}

impl Elab<'_> {
    fn fresh(&mut self) -> String {
        let n = format!("_d{}", self.tmp);
        self.tmp += 1;
        n
    }

    /// Elabora `t`, libertando as variáveis droppable no seu ponto de morte.
    /// `live_out` = droppable vivas *depois* de `t` (a libertar pelo contexto
    /// envolvente), que `t` não deve libertar.
    fn go(&mut self, t: Term, live_out: &HashSet<String>) -> Term {
        match t {
            Term::Drop(v, body) => {
                let b = self.go(*body, live_out);
                Term::Drop(v, Box::new(b))
            }
            Term::Ret(rhs) => match rhs {
                Rhs::Op(op) => {
                    let mut u = HashSet::new();
                    fv_op(&op, &self.drp, self.ba, &mut u);
                    let dying: Vec<String> =
                        u.into_iter().filter(|v| !live_out.contains(v)).collect();
                    if dying.is_empty() {
                        return Term::Ret(Rhs::Op(op));
                    }
                    // introduz um temporário, liberta os moribundos, devolve-o
                    let tmp = self.fresh();
                    let mut inner = Term::Ret(Rhs::Op(Op::Atom(Atom::Var(tmp.clone()))));
                    for v in dying {
                        inner = Term::Drop(v, Box::new(inner));
                    }
                    Term::Let(tmp, Rhs::Op(op), Box::new(inner))
                }
                Rhs::If(c, th, el) => {
                    let (th2, el2) = self.branches2(*th, *el, live_out);
                    Term::Ret(Rhs::If(c, Box::new(th2), Box::new(el2)))
                }
                Rhs::Case(s, arms) => {
                    let arms2 = self.case_arms(&s, arms, live_out);
                    Term::Ret(Rhs::Case(s, arms2))
                }
            },
            Term::Let(x, rhs, body) => match rhs {
                Rhs::Op(op) => {
                    let mut fvb = HashSet::new();
                    fv_drop(&body, &self.drp, self.ba, &mut fvb);
                    let body2 = self.go(*body, live_out);
                    let mut u = HashSet::new();
                    fv_op(&op, &self.drp, self.ba, &mut u);
                    let mut dying: Vec<String> = u
                        .into_iter()
                        .filter(|v| !fvb.contains(v) && !live_out.contains(v))
                        .collect();
                    // `x` recém-alocado e nunca lido → morre já
                    if self.drp.contains(&x) && !fvb.contains(&x) && !live_out.contains(&x) {
                        dying.push(x.clone());
                    }
                    let mut inner = body2;
                    for v in dying {
                        inner = Term::Drop(v, Box::new(inner));
                    }
                    Term::Let(x, Rhs::Op(op), Box::new(inner))
                }
                Rhs::If(c, th, el) => {
                    let mut fvb = HashSet::new();
                    fv_drop(&body, &self.drp, self.ba, &mut fvb);
                    let body2 = self.go(*body, live_out);
                    let mut lo = live_out.clone();
                    lo.extend(fvb);
                    let (th2, el2) = self.branches2(*th, *el, &lo);
                    Term::Let(x, Rhs::If(c, Box::new(th2), Box::new(el2)), Box::new(body2))
                }
                Rhs::Case(s, arms) => {
                    let mut fvb = HashSet::new();
                    fv_drop(&body, &self.drp, self.ba, &mut fvb);
                    let body2 = self.go(*body, live_out);
                    let mut lo = live_out.clone();
                    lo.extend(fvb);
                    let arms2 = self.case_arms(&s, arms, &lo);
                    Term::Let(x, Rhs::Case(s, arms2), Box::new(body2))
                }
            },
        }
    }

    /// Elabora os dois ramos de um `if`, equilibrando: uma droppable usada só num
    /// ramo é libertada à entrada do outro (para libertar uma vez por caminho).
    fn branches2(&mut self, th: Term, el: Term, live_out: &HashSet<String>) -> (Term, Term) {
        let mut fth = HashSet::new();
        fv_drop(&th, &self.drp, self.ba, &mut fth);
        let mut fel = HashSet::new();
        fv_drop(&el, &self.drp, self.ba, &mut fel);
        let mut th2 = self.go(th, live_out);
        let mut el2 = self.go(el, live_out);
        for v in fth.difference(&fel) {
            if !live_out.contains(v) {
                el2 = Term::Drop(v.clone(), Box::new(el2));
            }
        }
        for v in fel.difference(&fth) {
            if !live_out.contains(v) {
                th2 = Term::Drop(v.clone(), Box::new(th2));
            }
        }
        (th2, el2)
    }

    /// Elabora os braços de um `case`, equilibrando entre braços e libertando o
    /// escrutínio (se droppable e a morrer) à cabeça de cada braço.
    fn case_arms(
        &mut self,
        scrut: &Atom,
        arms: Vec<(CPat, Term)>,
        live_out: &HashSet<String>,
    ) -> Vec<(CPat, Term)> {
        // variáveis livres de cada braço
        let fvs: Vec<HashSet<String>> = arms
            .iter()
            .map(|(_, b)| {
                let mut s = HashSet::new();
                fv_drop(b, &self.drp, self.ba, &mut s);
                s
            })
            .collect();
        let union: HashSet<String> = fvs.iter().flatten().cloned().collect();

        let scrut_drop = match scrut {
            Atom::Var(n) if self.drp.contains(n) && !live_out.contains(n) => Some(n.clone()),
            _ => None,
        };

        let mut out = Vec::with_capacity(arms.len());
        for (i, (pat, body)) in arms.into_iter().enumerate() {
            let mut b = self.go(body, live_out);
            // equilíbrio entre braços: droppable usada noutro braço mas não neste
            for v in union.difference(&fvs[i]) {
                if !live_out.contains(v) {
                    b = Term::Drop(v.clone(), Box::new(b));
                }
            }
            // liberta o escrutínio à cabeça (após a destructuração)
            if let Some(s) = &scrut_drop {
                b = Term::Drop(s.clone(), Box::new(b));
            }
            out.push((pat, b));
        }
        out
    }
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
        Term::Drop(v, body) => {
            indent(n, s);
            s.push_str(&format!("drop {v}\n"));
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
        Op::UpdateRecord {
            base,
            fields,
            inplace,
        } => format!(
            "{} {} {{{}}}",
            if *inplace { "update!" } else { "update" },
            atom(base),
            fields
                .iter()
                .map(|(f, a)| format!(" {f} = {}", atom(a)))
                .collect::<String>()
        ),
        Op::MakeCon { con, args } => format!("con {con}{}", self::args(args)),
        Op::Field { name, rec } => format!("field {name} {}", atom(rec)),
        Op::PutStrLn(a) => format!("putStrLn {}", atom(a)),
        Op::ShowInt(a) => format!("show {}", atom(a)),
        Op::WithArena { parent: None, clos } => format!("withArena {}", atom(clos)),
        Op::WithArena {
            parent: Some(p),
            clos,
        } => format!("withSubArena {} {}", atom(p), atom(clos)),
        Op::ArenaAlloc(a) => format!("allocateCell {}", atom(a)),
        Op::Promote(t, c) => format!("promote {} {}", atom(t), atom(c)),
        Op::ArenaMark(a) => format!("arena_mark {}", atom(a)),
        Op::ArenaRelease(a) => format!("arena_release {}", atom(a)),
        Op::RtCall { func, args, .. } => format!("rtcall {func}{}", self::args(args)),
        Op::Ffi { name, args } => format!("ffi {name}{}", self::args(args)),
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
        CPat::Con(n, ps) => {
            if ps.is_empty() {
                n.clone()
            } else {
                format!("{n} {}", ps.iter().map(cpat).collect::<Vec<_>>().join(" "))
            }
        }
    }
}
