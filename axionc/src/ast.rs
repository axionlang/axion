//! AST of Axion's L0/L1 subset (see `docs/grammar.md`).

pub type Span = (usize, usize); // (start, end) em offsets de bytes

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum Mult {
    Many, // seta normal
    One,  // %1 — linear ownership
    Half, // %0.5 — fractional permission (parseable; not enforced in Phase 1)
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
    /// Parameter multiplicities, left→right (from the top-level arrows).
    pub fn param_mults(&self) -> Vec<Mult> {
        let mut out = Vec::new();
        let mut t = self;
        while let Type::Arrow { mult, to, .. } = t {
            out.push(*mult);
            t = to;
        }
        out
    }

    /// Parameter types, left→right (the `from` of each top-level arrow).
    pub fn param_types(&self) -> Vec<&Type> {
        let mut out = Vec::new();
        let mut t = self;
        while let Type::Arrow { from, to, .. } = t {
            out.push(from.as_ref());
            t = to;
        }
        out
    }

    /// Head constructor name of the type (e.g. `Buffer U8` → "Buffer").
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
    Tuple(Vec<Pat>, Span),
}

#[derive(Debug, Clone)]
pub enum Expr {
    Int(i64, Span),
    Float(f64, Span),
    Str(String, Span),
    Var(String, Span),
    Con(String, Span),
    App(Box<Expr>, Box<Expr>, Span),
    BinOp(String, Box<Expr>, Box<Expr>, Span),
    If(Box<Expr>, Box<Expr>, Box<Expr>, Span),
    Let(Vec<Func>, Box<Expr>, Span),
    Case(Box<Expr>, Vec<(Pat, Expr)>, Span),
    Tuple(Vec<Expr>, Span),
    /// Record construction: `Con { field = expr, ... }`.
    RecordCon(String, Vec<(String, Expr)>, Span),
    /// Record update: `base { field = expr, ... }` (Listing 2.1).
    RecordUpd(Box<Expr>, Vec<(String, Expr)>, Span),
    /// Lambda abstraction: `\p1 p2 -> body` (used by `withSubArena`, §3).
    Lam(Vec<Pat>, Box<Expr>, Span),
}

impl Expr {
    pub fn span(&self) -> Span {
        match self {
            Expr::Int(_, s)
            | Expr::Float(_, s)
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
    Guarded(Vec<(Expr, Expr)>), // (guard, result)
}

#[derive(Debug, Clone)]
pub struct Func {
    pub name: String,
    pub sig: Option<Type>,
    pub clauses: Vec<Clause>,
    pub span: Span,
    /// Class context of the signature: `(class, var)` of each `C a =>`
    /// Empty when there are no constraints. Used to discharge the
    /// method obligations (a polymorphic method use must be covered by
    /// a declared constraint).
    pub constraints: Vec<(String, String)>,
}

/// A record field: name, type and multiplicity (`%1` marks a linear field).
#[derive(Debug, Clone)]
pub struct Field {
    pub name: String,
    pub ty: Type,
    pub mult: Mult,
}

/// A data constructor, with named (record) or positional fields.
#[derive(Debug, Clone)]
pub struct ConDecl {
    pub name: String,
    pub fields: Vec<Field>, // empty name ("") for positional fields
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
    pub params: Vec<String>, // type parameters (e.g. `a` in `data List a`)
    pub cons: Vec<ConDecl>,
    pub span: Span,
}

/// `class C a where <method signatures>` (§ typeclasses). A class declares
/// overloaded method names; each `instance` provides the implementations.
#[derive(Debug, Clone)]
pub struct ClassDecl {
    pub name: String,                 // ex.: "Eq"
    pub tyvar: String,                // the class type variable (e.g. "a")
    pub methods: Vec<(String, Type)>, // signature of each method
    pub span: Span,
}

/// `instance C T where <clauses>` — the implementations of class `C`'s methods
/// for the type whose head is `ty_head` (e.g. "Int", "Maybe").
#[derive(Debug, Clone)]
pub struct InstanceDecl {
    pub class_name: String,
    pub ty_head: String,
    pub methods: Vec<Func>,
    pub span: Span,
}

/// Mangled name of a method implementation for a concrete type: `eq$Int`.
/// Single source of truth — used both in lowering (`lower_classes`) and in
/// the interpreter's dynamic dispatch.
pub fn method_impl_name(method: &str, ty_head: &str) -> String {
    format!("{method}${ty_head}")
}

#[derive(Debug, Clone)]
pub struct Module {
    pub funcs: Vec<Func>,
    pub datas: Vec<DataDecl>,
    pub foreigns: Vec<Foreign>,
    pub classes: Vec<ClassDecl>,
    pub instances: Vec<InstanceDecl>,
}

impl Module {
    /// Paths of `.so` libraries to load for the FFI (§18), without repetitions
    /// and in order of first mention.
    pub fn foreign_libs(&self) -> Vec<String> {
        let mut out: Vec<String> = Vec::new();
        for f in &self.foreigns {
            if let Some(lib) = &f.lib {
                if !out.contains(lib) {
                    out.push(lib.clone());
                }
            }
        }
        out
    }
}

/// An FFI import: `foreign ["lib.so"] name :: Int -> … -> Int` calls the
/// C function `name` (Int/i64 ABI), resolved by `dlsym` (§18). With the optional
/// library path, that `.so` is loaded before resolving the symbols.
#[derive(Debug, Clone)]
pub struct Foreign {
    pub name: String,
    pub sig: Type,
    pub lib: Option<String>,
    pub span: Span,
}
