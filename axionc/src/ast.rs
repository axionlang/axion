//! AST do subconjunto L0/L1 da Axión (ver `docs/grammar.md`).

pub type Span = (usize, usize); // (start, end) em offsets de bytes

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum Mult {
    Many, // seta normal
    One,  // %1 — posse linear
    Half, // %0.5 — permissão fraccionária (parseável; não imposta na Fase 1)
}

#[derive(Debug, Clone)]
pub enum Type {
    Con(String),
    Var(String),
    App(Box<Type>, Box<Type>),
    Arrow {
        mult: Mult,
        from: Box<Type>,
        to: Box<Type>,
    },
    Tuple(Vec<Type>),
    Unit,
}

impl Type {
    /// Multiplicidades dos parâmetros, esquerda→direita (a partir das setas de topo).
    pub fn param_mults(&self) -> Vec<Mult> {
        let mut out = Vec::new();
        let mut t = self;
        while let Type::Arrow { mult, to, .. } = t {
            out.push(*mult);
            t = to;
        }
        out
    }

    /// Tipos dos parâmetros, esquerda→direita (o `from` de cada seta de topo).
    pub fn param_types(&self) -> Vec<&Type> {
        let mut out = Vec::new();
        let mut t = self;
        while let Type::Arrow { from, to, .. } = t {
            out.push(from.as_ref());
            t = to;
        }
        out
    }

    /// Nome do construtor de topo do tipo (ex.: `Buffer U8` → "Buffer").
    pub fn head_con(&self) -> Option<&str> {
        match self {
            Type::Con(n) => Some(n),
            Type::App(f, _) => f.head_con(),
            _ => None,
        }
    }
}

#[derive(Debug, Clone)]
pub enum Pat {
    Wild(Span),
    Var(String, Span),
    Int(i64, Span),
    Con(String, Vec<Pat>, Span),
}

#[derive(Debug, Clone)]
pub enum Expr {
    Int(i64, Span),
    Str(String, Span),
    Var(String, Span),
    Con(String, Span),
    App(Box<Expr>, Box<Expr>, Span),
    BinOp(String, Box<Expr>, Box<Expr>, Span),
    If(Box<Expr>, Box<Expr>, Box<Expr>, Span),
    Let(Vec<Func>, Box<Expr>, Span),
    Case(Box<Expr>, Vec<(Pat, Expr)>, Span),
    Tuple(Vec<Expr>, Span),
    /// Construção de registo: `Con { campo = expr, ... }`.
    RecordCon(String, Vec<(String, Expr)>, Span),
    /// Actualização de registo: `base { campo = expr, ... }` (Listagem 2.1).
    RecordUpd(Box<Expr>, Vec<(String, Expr)>, Span),
    /// Abstracção lambda: `\p1 p2 -> corpo` (usada por `withSubArena`, §3).
    Lam(Vec<Pat>, Box<Expr>, Span),
}

impl Expr {
    pub fn span(&self) -> Span {
        match self {
            Expr::Int(_, s)
            | Expr::Str(_, s)
            | Expr::Var(_, s)
            | Expr::Con(_, s)
            | Expr::App(_, _, s)
            | Expr::BinOp(_, _, _, s)
            | Expr::If(_, _, _, s)
            | Expr::Let(_, _, s)
            | Expr::Case(_, _, s)
            | Expr::Tuple(_, s)
            | Expr::RecordCon(_, _, s)
            | Expr::RecordUpd(_, _, s)
            | Expr::Lam(_, _, s) => *s,
        }
    }
}

#[derive(Debug, Clone)]
pub struct Clause {
    pub pats: Vec<Pat>,
    pub body: Body,
    pub wher: Vec<Func>,
    pub span: Span,
}

#[derive(Debug, Clone)]
pub enum Body {
    Plain(Expr),
    Guarded(Vec<(Expr, Expr)>), // (guarda, resultado)
}

#[derive(Debug, Clone)]
pub struct Func {
    pub name: String,
    pub sig: Option<Type>,
    pub clauses: Vec<Clause>,
    pub span: Span,
}

/// Um campo de registo: nome, tipo e multiplicidade (`%1` marca campo linear).
#[derive(Debug, Clone)]
pub struct Field {
    pub name: String,
    pub ty: Type,
    pub mult: Mult,
}

/// Um construtor de dados, com campos nomeados (registo) ou posicionais.
#[derive(Debug, Clone)]
pub struct ConDecl {
    pub name: String,
    pub fields: Vec<Field>, // nome vazio ("") para campos posicionais
}

impl ConDecl {
    pub fn field_names(&self) -> Vec<String> {
        self.fields.iter().map(|f| f.name.clone()).collect()
    }
}

/// `data T = Con { ... } | ...`
#[derive(Debug, Clone)]
pub struct DataDecl {
    pub name: String,
    pub cons: Vec<ConDecl>,
    pub span: Span,
}

#[derive(Debug, Clone)]
pub struct Module {
    pub funcs: Vec<Func>,
    pub datas: Vec<DataDecl>,
}
