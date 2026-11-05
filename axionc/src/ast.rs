//! AST of Axion's L0/L1 subset (see `docs/grammar.md`).

pub type Span = (usize, usize); // (start, end) em offsets de bytes

#[derive(Debug, Clone, Copy, PartialEq)]
#[cfg_attr(feature = "salsa", derive(salsa::SalsaValue))] // already PartialEq above
pub enum Mult {
    Many, // seta normal
    One,  // %1 — linear ownership
    Half, // %0.5 — fractional permission (parseable; not enforced in Phase 1)
}

#[derive(Debug, Clone)]
#[cfg_attr(feature = "salsa", derive(salsa::SalsaValue))]
#[cfg_attr(any(feature = "salsa", feature = "cst"), derive(PartialEq))]
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

    /// Strip a leading FFI ownership wrapper (§18): `Own T` → `(true, T)` (ownership transfers
    /// to C — the arg is consumed and Axión must NOT free it); `Borrow T` → `(false, T)` (the
    /// default — Axión keeps ownership and frees once). Anything else → `(false, self)`.
    pub fn ffi_ownership(&self) -> (bool, &Type) {
        if let Type::App(f, a) = self {
            match f.head_con() {
                Some("Own") => return (true, a),
                Some("Borrow") => return (false, a),
                _ => {}
            }
        }
        (false, self)
    }

    /// `true` iff this type is `Float` (an f64 in the C ABI — passed in an FP register, not an
    /// integer register). Used to drive the FFI float-ABI lowering.
    pub fn is_ffi_float(&self) -> bool {
        self.head_con() == Some("Float")
    }

    /// Rebuild this type with every FFI ownership wrapper (`Own`/`Borrow`) stripped, so the
    /// type-checker and the rest of the pipeline see the clean underlying type. Walks the
    /// top-level arrow chain (strips each arg and the result).
    pub fn strip_ffi_wrappers(&self) -> Type {
        match self {
            Type::Arrow { mult, from, to } => Type::Arrow {
                mult: *mult,
                from: Box::new(from.ffi_ownership().1.clone()),
                to: Box::new(to.strip_ffi_wrappers()),
            },
            other => other.ffi_ownership().1.clone(),
        }
    }
}

#[derive(Debug, Clone)]
#[cfg_attr(feature = "salsa", derive(salsa::SalsaValue))]
#[cfg_attr(any(feature = "salsa", feature = "cst"), derive(PartialEq))]
pub enum Pat {
    Wild(Span),
    Var(String, Span),
    Int(i64, Span),
    /// String-literal pattern (`case cmd of "show" -> …`). Desugared to an `if`-chain
    /// over String `==` before check/inference/lowering, so only the parsers and that
    /// desugaring construct/inspect it.
    Str(String, Span),
    Con(String, Vec<Pat>, Span),
    Tuple(Vec<Pat>, Span),
}

#[derive(Debug, Clone)]
#[cfg_attr(feature = "salsa", derive(salsa::SalsaValue))]
#[cfg_attr(any(feature = "salsa", feature = "cst"), derive(PartialEq))]
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

/// Which monad a `do`-block bind (`pat <- e`) short-circuits over. Chosen
/// SYNTACTICALLY by the bind arrow — `<-` (IO, no short-circuit), `<-?` (Maybe),
/// `<-!` (Either) — so the desugar needs no type inference (§ error-handling
/// ergonomics). Each lowers to the exact `case` a hand-written version would write.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum BindKind {
    /// `x <- e` — sequential IO; binds the whole value, no short-circuit.
    Io,
    /// `x <-? e` — Maybe-bind; `Nothing` short-circuits the block.
    Maybe,
    /// `x <-! e` — Either-bind; `Left err` short-circuits the block (re-wrapped).
    Either,
}

/// Desugar one `do` statement `pat <arrow> scrut` with continuation `cont` into a
/// `case`. IO binds the whole value (`case scrut of pat -> cont`); Maybe/Either add a
/// short-circuit arm (`Nothing -> Nothing` / `Left e -> Left e`). Shared by both
/// parsers so the two front-ends can never diverge on the desugaring.
pub fn desugar_bind(kind: BindKind, pat: Pat, scrut: Expr, cont: Expr, sp: Span) -> Expr {
    // A COMPOUND bind pattern over Maybe/Either (`(l, p1) <-! e`) would otherwise sit NESTED
    // inside the monad constructor — `Right (l, p1)` — which the native backends reject, and
    // whose extraction of an escaping field leaves the intermediate tuple shell unreclaimed.
    // Bind a fresh intermediate whole, then destructure it in a SEPARATE `case`: the two
    // single-level extractions (con then tuple/con) are each soundly reclaimed, and no pattern
    // is nested in a constructor. The `$`-prefixed name is unwritable in source, so it captures
    // nothing; the span keys it uniquely so nested binds don't collide. NOT for plain `<-` (Io):
    // that lowers to `case scrut of pat -> cont` with NO constructor wrapping, so a compound
    // pattern is already single-level — and wrapping it would hide a session endpoint behind the
    // intermediate, tripping the protocol-completion check (AX0301).
    let (pat, cont) = match (kind, pat) {
        (BindKind::Io, p) | (_, p @ (Pat::Var(_, _) | Pat::Wild(_))) => (p, cont),
        (_, compound) => {
            let tmp = format!("$bind{}", sp.0);
            let inner = Expr::Case(
                Box::new(Expr::Var(tmp.clone(), sp)),
                vec![(compound, cont)],
                sp,
            );
            (Pat::Var(tmp, sp), inner)
        }
    };
    let case = |arms| Expr::Case(Box::new(scrut), arms, sp);
    match kind {
        BindKind::Io => case(vec![(pat, cont)]),
        BindKind::Maybe => case(vec![
            (Pat::Con("Just".into(), vec![pat], sp), cont),
            (
                Pat::Con("Nothing".into(), Vec::new(), sp),
                Expr::Con("Nothing".into(), sp),
            ),
        ]),
        BindKind::Either => {
            // `$bindErr` cannot be written in source (the lexer forbids `$` in an
            // identifier), so it can never capture a user binding; it is bound and
            // re-wrapped within its own arm and never referenced elsewhere.
            let err = "$bindErr".to_string();
            let rewrap = Expr::App(
                Box::new(Expr::Con("Left".into(), sp)),
                Box::new(Expr::Var(err.clone(), sp)),
                sp,
            );
            case(vec![
                (Pat::Con("Right".into(), vec![pat], sp), cont),
                (Pat::Con("Left".into(), vec![Pat::Var(err, sp)], sp), rewrap),
            ])
        }
    }
}

/// Desugar a `borrow buf as p in body` FFI scope (§18). `p` is bound to the buffer's data pointer
/// (`bufPtr buf`), valid for `body`; the buffer is kept LIVE across `body` and then reclaimed when
/// the block ends. Lowers to:
///
/// ```text
///   let p = bufPtr buf in
///   case body of $brres -> case free buf of _ -> $brres
/// ```
///
/// The trailing `free buf` is the buffer's single consume, placed AFTER `body` — so the
/// drop-balance analysis cannot free it mid-call, which is the use-after-free a raw `bufPtr`
/// handed to C otherwise invites (the escaped pointer is opaque to the verifier). `case … of _ ->`
/// is the same strict sequencing a `do` statement uses, so `free` runs after `body` and is never
/// elided. `buf` is referenced twice, so when it is not already a variable it is let-bound once to
/// a `$`-temp (unwritable in source, span-keyed) to evaluate it a single time.
pub fn desugar_borrow(buf: Expr, ptr: String, body: Expr, sp: Span) -> Expr {
    let bind = |name: String, rhs: Expr| Func {
        name,
        sig: None,
        clauses: vec![Clause {
            pats: Vec::new(),
            body: Body::Plain(rhs),
            wher: Vec::new(),
            span: sp,
        }],
        span: sp,
        constraints: Vec::new(),
    };
    let var = |n: &str| Expr::Var(n.to_string(), sp);
    let app = |f: Expr, x: Expr| Expr::App(Box::new(f), Box::new(x), sp);
    let resn = format!("$brres{}", sp.0);

    let build = |bufref: Expr| -> Expr {
        // case free buf of _ -> $brres   (consume buf AFTER body, return body's result)
        let after = Expr::Case(
            Box::new(app(var("free"), bufref)),
            vec![(Pat::Wild(sp), var(&resn))],
            sp,
        );
        // case body of $brres -> after
        Expr::Case(Box::new(body), vec![(Pat::Var(resn.clone(), sp), after)], sp)
    };

    match buf {
        // `buf` is already a variable: reference it directly (bufPtr then free) — no alias temp.
        Expr::Var(ref bn, _) => {
            let seq = build(var(bn));
            Expr::Let(
                vec![bind(ptr, app(var("bufPtr"), var(bn)))],
                Box::new(seq),
                sp,
            )
        }
        // otherwise bind it once so it is evaluated a single time.
        other => {
            let bufn = format!("$brbuf{}", sp.0);
            let seq = build(var(&bufn));
            let letp = Expr::Let(
                vec![bind(ptr, app(var("bufPtr"), var(&bufn)))],
                Box::new(seq),
                sp,
            );
            Expr::Let(vec![bind(bufn, other)], Box::new(letp), sp)
        }
    }
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
#[cfg_attr(feature = "salsa", derive(salsa::SalsaValue))]
#[cfg_attr(any(feature = "salsa", feature = "cst"), derive(PartialEq))]
pub struct Clause {
    pub pats: Vec<Pat>,
    pub body: Body,
    pub wher: Vec<Func>,
    pub span: Span,
}

#[derive(Debug, Clone)]
#[cfg_attr(feature = "salsa", derive(salsa::SalsaValue))]
#[cfg_attr(any(feature = "salsa", feature = "cst"), derive(PartialEq))]
pub enum Body {
    Plain(Expr),
    Guarded(Vec<(Expr, Expr)>), // (guard, result)
}

#[derive(Debug, Clone)]
#[cfg_attr(feature = "salsa", derive(salsa::SalsaValue))]
#[cfg_attr(any(feature = "salsa", feature = "cst"), derive(PartialEq))]
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
#[cfg_attr(feature = "salsa", derive(salsa::SalsaValue))]
#[cfg_attr(any(feature = "salsa", feature = "cst"), derive(PartialEq))]
pub struct Field {
    pub name: String,
    pub ty: Type,
    pub mult: Mult,
}

/// A `foreign struct Name { f: T, ... }` (§18): a C-ABI-laid-out byte record for FFI interop.
/// Expanded in the front-end into a buffer-allocating constructor + per-field `peek` selectors
/// (offsets from [`ForeignStruct::c_layout`]); the runtime value is a `Buffer` of the struct size.
#[derive(Debug, Clone)]
#[cfg_attr(feature = "salsa", derive(salsa::SalsaValue))]
#[cfg_attr(any(feature = "salsa", feature = "cst"), derive(PartialEq))]
pub struct ForeignStruct {
    pub name: String,
    pub fields: Vec<Field>,
    pub span: Span,
}

/// Size and alignment (bytes) of a fixed-width FFI field type under the System V LP64 C ABI.
/// `None` for anything not a valid v1 struct-field type (the fixed-width ints, `F64`/`Float`, `Ptr`).
pub fn ffi_type_size_align(t: &Type) -> Option<(usize, usize)> {
    Some(match t.head_con()? {
        "I8" | "U8" | "Byte" => (1, 1),
        "I16" | "U16" => (2, 2),
        "I32" | "U32" => (4, 4),
        "I64" | "U64" | "Word" | "Int" => (8, 8),
        "F64" | "Float" => (8, 8),
        "Ptr" => (8, 8),
        _ => return None,
    })
}

impl ForeignStruct {
    /// Field byte offsets (left→right) and the total struct size, per the C ABI: each field goes at
    /// the next offset that is a multiple of its alignment (inserting padding); the size is the
    /// final offset rounded up to the max field alignment (trailing pad). `None` on a bad field type.
    pub fn c_layout(&self) -> Option<(Vec<usize>, usize)> {
        let mut off = 0usize;
        let mut max_align = 1usize;
        let mut offsets = Vec::with_capacity(self.fields.len());
        for f in &self.fields {
            let (size, align) = ffi_type_size_align(&f.ty)?;
            off = off.div_ceil(align) * align; // pad up to the field's alignment
            offsets.push(off);
            off += size;
            max_align = max_align.max(align);
        }
        Some((offsets, off.div_ceil(max_align) * max_align))
    }
}

/// A `foreign enum Name { M = v, M2, … }` (§18): named C-integer constants. Each member is a
/// global `Int` constant usable as a value (`SDL_QUIT` → 256) and as a `case` pattern (matched by
/// equality). An omitted value auto-increments from the previous (C semantics); the first is 0.
#[derive(Debug, Clone)]
#[cfg_attr(feature = "salsa", derive(salsa::SalsaValue))]
#[cfg_attr(any(feature = "salsa", feature = "cst"), derive(PartialEq))]
pub struct ForeignEnum {
    pub name: String,
    pub members: Vec<(String, i64)>,
    pub span: Span,
}

/// A data constructor, with named (record) or positional fields.
#[derive(Debug, Clone)]
#[cfg_attr(feature = "salsa", derive(salsa::SalsaValue))]
#[cfg_attr(any(feature = "salsa", feature = "cst"), derive(PartialEq))]
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
#[cfg_attr(feature = "salsa", derive(salsa::SalsaValue))]
#[cfg_attr(any(feature = "salsa", feature = "cst"), derive(PartialEq))]
pub struct DataDecl {
    pub name: String,
    pub params: Vec<String>, // type parameters (e.g. `a` in `data List a`)
    pub cons: Vec<ConDecl>,
    /// classes to auto-derive: `deriving (Eq, Ord, Show)`. Desugared into
    /// synthesized `instance` declarations before class lowering (`main.rs`).
    pub deriving: Vec<String>,
    pub span: Span,
}

/// `class C a where <method signatures>` (§ typeclasses). A class declares
/// overloaded method names; each `instance` provides the implementations.
#[derive(Debug, Clone)]
#[cfg_attr(feature = "salsa", derive(salsa::SalsaValue))]
#[cfg_attr(any(feature = "salsa", feature = "cst"), derive(PartialEq))]
pub struct ClassDecl {
    pub name: String,                 // ex.: "Eq"
    pub tyvar: String,                // the class type variable (e.g. "a")
    pub methods: Vec<(String, Type)>, // signature of each method
    pub span: Span,
}

/// `instance C T where <clauses>` — the implementations of class `C`'s methods
/// for the type whose head is `ty_head` (e.g. "Int", "Maybe").
#[derive(Debug, Clone)]
#[cfg_attr(feature = "salsa", derive(salsa::SalsaValue))]
#[cfg_attr(any(feature = "salsa", feature = "cst"), derive(PartialEq))]
pub struct InstanceDecl {
    pub class_name: String,
    pub ty_head: String,
    /// the full instance type, e.g. `Maybe a` (`Con "Maybe"` for non-parametric).
    pub head_ty: Type,
    /// context constraints, e.g. `Eq a =>` in `instance Eq a => Eq (Maybe a)`.
    pub constraints: Vec<(String, String)>,
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
#[cfg_attr(feature = "salsa", derive(salsa::SalsaValue))]
#[cfg_attr(any(feature = "salsa", feature = "cst"), derive(PartialEq))]
pub struct Module {
    pub name: Option<Vec<String>>,
    pub imports: Vec<ImportDecl>,
    pub funcs: Vec<Func>,
    pub datas: Vec<DataDecl>,
    pub foreigns: Vec<Foreign>,
    /// `foreign struct` declarations (§18); expanded to constructor + selector `funcs` in the
    /// front-end, so downstream stages see ordinary functions.
    pub foreign_structs: Vec<ForeignStruct>,
    /// `foreign enum` declarations (§18): named C-integer constants, rewritten to `Int` literals /
    /// patterns in the front-end, so downstream stages see plain integers.
    pub foreign_enums: Vec<ForeignEnum>,
    pub classes: Vec<ClassDecl>,
    pub instances: Vec<InstanceDecl>,
    /// `{-# LEVEL Ln #-}` ceiling (§8), scanned off the raw source in `main.rs`.
    /// `None` when absent — no ceiling to enforce. Only tightens what a decl may
    /// *write* (its own multiplicities/types/builtins), never what it calls.
    pub level_ceiling: Option<u8>,
}

#[derive(Debug, Clone)]
#[cfg_attr(feature = "salsa", derive(salsa::SalsaValue))]
#[cfg_attr(any(feature = "salsa", feature = "cst"), derive(PartialEq))]
pub struct ImportDecl {
    pub module: Vec<String>,
    pub qualified: bool,
    pub alias: Option<String>,
    pub span: Span,
}

impl Module {
    /// Paths of `.so` libraries to load for the FFI (§18), without repetitions
    /// and in order of first mention.
    pub fn foreign_libs(&self) -> Vec<String> {
        self.foreign_libs_filtered(|_| true)
    }

    /// Libraries the INTERPRETER needs: only those used by an interp-safe foreign (§18 #4). A
    /// native-only foreign's lib is skipped — its calls are refused at the call site, so a missing
    /// `.so` must not block the interpreter from running the rest of the program (or from reaching
    /// that clean native-only refusal).
    pub fn foreign_libs_interp(&self) -> Vec<String> {
        self.foreign_libs_filtered(Foreign::interp_safe)
    }

    fn foreign_libs_filtered(&self, keep: impl Fn(&Foreign) -> bool) -> Vec<String> {
        let mut out: Vec<String> = Vec::new();
        for f in &self.foreigns {
            if let Some(lib) = &f.lib {
                if keep(f) && !out.contains(lib) {
                    out.push(lib.clone());
                }
            }
        }
        out
    }
}

/// An FFI import: `foreign ["lib.so"] name [= "C_symbol"] :: Int -> … -> Int`. The Axión
/// binding is the lowercase `name`; the C function resolved by `dlsym` (§18) is `symbol`
/// when given, else `name`. The alias lets a lowercase Axión name bind an uppercase/CamelCase
/// C symbol (`sdlInit = "SDL_Init"`), which Axión identifiers cannot spell directly. With the
/// optional library path, that `.so` is loaded before resolving the symbols. Int/i64 ABI.
#[derive(Debug, Clone)]
#[cfg_attr(feature = "salsa", derive(salsa::SalsaValue))]
#[cfg_attr(any(feature = "salsa", feature = "cst"), derive(PartialEq))]
pub struct Foreign {
    pub name: String,
    /// The C symbol to `dlsym`, if it differs from `name` (the `= "SDL_Init"` alias).
    pub symbol: Option<String>,
    pub sig: Type,
    pub lib: Option<String>,
    pub span: Span,
}

impl Foreign {
    /// The C symbol to resolve via `dlsym` — the explicit alias, else the Axión name.
    pub fn c_symbol(&self) -> String {
        self.symbol.clone().unwrap_or_else(|| self.name.clone())
    }

    /// The signature as the type-checker should see it — FFI ownership wrappers stripped
    /// (`Own String -> Int` type-checks as `String -> Int`).
    pub fn clean_sig(&self) -> Type {
        self.sig.strip_ffi_wrappers()
    }

    /// Per-argument FFI kinds, left→right — `(own, float)` for each top-level arrow param — plus
    /// whether the RESULT is a float. Drives the float-ABI lowering (which args/result go in FP
    /// registers) and the per-arg ownership (which args are consumed vs borrowed).
    pub fn ffi_kinds(&self) -> (Vec<(bool, bool)>, bool) {
        let mut args = Vec::new();
        let mut t = &self.sig;
        while let Type::Arrow { from, to, .. } = t {
            let (own, inner) = from.ffi_ownership();
            args.push((own, inner.is_ffi_float()));
            t = to;
        }
        (args, t.ffi_ownership().1.is_ffi_float())
    }

    /// `true` iff the interpreter can call this FFI import with FULL FIDELITY to the native
    /// backends (§18, item #4 — no silent divergence). The interp passes/returns i64 by value and
    /// cannot faithfully model: the `double`/FP-register float ABI, C reading or writing through a
    /// `String`/`Buffer`/`Ptr` pointer (the interp's copy is not what C sees), or arities beyond 3.
    /// So only an all-scalar (`Int`/`Bool`) signature of arity ≤ 3 is interp-safe; everything else
    /// is native-only and the interp refuses it explicitly rather than diverging.
    pub fn interp_safe(&self) -> bool {
        fn scalar(t: &Type) -> bool {
            matches!(t.head_con(), Some("Int" | "Bool"))
        }
        let clean = self.clean_sig();
        let mut t = &clean;
        let mut arity = 0usize;
        while let Type::Arrow { from, to, .. } = t {
            if !scalar(from) {
                return false;
            }
            arity += 1;
            t = to;
        }
        arity <= 3 && scalar(t)
    }
}

#[cfg(test)]
mod layout_tests {
    use super::*;

    fn fs(fields: &[(&str, &str)]) -> ForeignStruct {
        ForeignStruct {
            name: "S".into(),
            fields: fields
                .iter()
                .map(|(n, t)| Field {
                    name: (*n).into(),
                    ty: Type::Con((*t).into()),
                    mult: Mult::Many,
                })
                .collect(),
            span: (0, 0),
        }
    }

    #[test]
    fn c_layout_packs_and_pads_per_the_c_abi() {
        // four i32s: packed, offsets 0/4/8/12, size 16.
        assert_eq!(
            fs(&[("x", "I32"), ("y", "I32"), ("w", "I32"), ("h", "I32")]).c_layout(),
            Some((vec![0, 4, 8, 12], 16))
        );
        // { i8, i32, i8 }: i32 is padded to offset 4; struct rounded up to 12 (align 4).
        assert_eq!(
            fs(&[("a", "I8"), ("b", "I32"), ("c", "I8")]).c_layout(),
            Some((vec![0, 4, 8], 12))
        );
        // { i64, i8 }: trailing pad to the max alignment (8) → size 16.
        assert_eq!(
            fs(&[("p", "I64"), ("q", "I8")]).c_layout(),
            Some((vec![0, 8], 16))
        );
        // { i8, i16 }: i16 padded to offset 2; size 4.
        assert_eq!(
            fs(&[("a", "U8"), ("b", "U16")]).c_layout(),
            Some((vec![0, 2], 4))
        );
        // a non-FFI field type is rejected.
        assert_eq!(fs(&[("s", "String")]).c_layout(), None);
    }
}
