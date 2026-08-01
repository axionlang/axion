//! Axion Core IR (§11): the **strict/linear** intermediate representation from which
//! the native backends lower (Cranelift `--dev` and LLVM `--release`),
//! instead of lowering from the AST directly.
//!
//! It is in **A-normal form (ANF)**: every compound subexpression is named by a
//! `let`, and the arguments of operations/calls are **atoms** (literal or
//! variable). Control (`if`/`case`) lives in an `Rhs`, so a `let` can
//! bind the result of a branch (*join-point* style). Multi-clause
//! desugaring (`if` chain), `where` *lifting* and **closure
//! conversion** (lambda → function + capture environment) already happen in this lowering,
//! leaving codegen a plain Core→machine emitter.
//!
//! **Structural Drop** (Auto-Drop §2) is an **explicit node** in the Core: a
//! reclamation analysis (`insert_drops`) inserts `drop x` at the death point of the
//! objects the function owns (locals, call results, `%1` params) and
//! that don't escape; the runtime frees them (`axion_free`). **Arenas** (§3)
//! also have their own Ops (`WithArena`/`ArenaAlloc`/`Promote`/`ArenaMark`/…) and
//! a bump runtime with bulk reset. **In-place** (Linear Elision, §2) is a
//! flag on `Op::UpdateRecord`: if `check.rs` proves the base is linear and dies
//! there, the existing block is mutated instead of allocating+copying.

use crate::ast::{self, Body, Expr, Pat, Span, Type};
use std::collections::HashMap;
use std::collections::HashSet;

/// Atomic value: a literal or a reference to an already-bound variable.
#[derive(Debug, Clone)]
pub enum Atom {
    Int(i64),
    /// Float literal, carried through the uniformly-i64 ABI as its f64 bit
    /// pattern; float arithmetic (`PrimF`) bitcasts to/from f64 (§4).
    Float(f64),
    Str(String),
    Var(String),
}

/// A leaf computation (right-hand side of a `let`, no control).
#[derive(Debug, Clone)]
pub enum Op {
    Atom(Atom),
    /// binary primitive operation: `+ - * mod == < > band`
    Prim(String, Atom, Atom),
    /// binary FLOAT primitive (`+. -. *. /.` and comparisons `<. >. ==.`):
    /// operands are f64 bit patterns in i64; the backend bitcasts to f64 and
    /// computes. Arithmetic bitcasts the f64 result back into i64; a comparison
    /// yields a Bool (i64 0/1).
    PrimF(String, Atom, Atom),
    /// `toFloat :: Int -> Float` — signed i64 → f64, result as its bit pattern.
    IntToFloat(Atom),
    /// `truncate :: Float -> Int` — f64 (bit pattern) → signed i64, truncating.
    FloatToInt(Atom),
    /// unary Float math (`sqrt`/`floor`/`abs`) :: Float -> Float — the operand is
    /// an f64 bit pattern in i64; the backend bitcasts to f64, applies the IEEE
    /// operation (Cranelift instruction / LLVM intrinsic), and bitcasts back.
    FloatUnary(String, Atom),
    /// direct call to a named function (top-level or `where` local, already mangled)
    CallDirect(String, Vec<Atom>),
    /// indirect call through a closure (the atom is the pointer)
    CallClosure(Atom, Vec<Atom>),
    /// build a closure: lifted function + captured values
    MakeClosure {
        func: String,
        captures: Vec<Atom>,
    },
    /// allocate a tuple on the heap (one `i64` per component)
    MakeTuple(Vec<Atom>),
    /// build a record `Con { field = atom, … }`
    MakeRecord {
        con: String,
        fields: Vec<(String, Atom)>,
    },
    /// build a positional `data` value `Con a b …` (sum types included —
    /// carries the tag if the type has >1 constructor).
    MakeCon {
        con: String,
        args: Vec<Atom>,
    },
    /// update a record `base { field = atom, … }`. `inplace` (Linear Elision,
    /// §2): the base is linear and dies here → the existing block is mutated instead of
    /// allocating+copying (`check.rs` proves the safety).
    UpdateRecord {
        base: Atom,
        fields: Vec<(String, Atom)>,
        inplace: bool,
    },
    /// field selector `field rec`
    Field {
        name: String,
        rec: Atom,
    },
    /// raw i64 load at `ptr + offset` (bytes). Only destructor generation
    /// (deep-drop, §2) uses it — accesses fields by offset, including the tag.
    LoadRaw(Atom, i32),
    /// raw i64 store `value` at `ptr + offset` (bytes); evaluates to `value`.
    /// Used by the native session state machines (§11) to save/restore task
    /// locals across a `recv` suspension into the task-state block.
    StoreRaw(Atom, i32, Atom),
    /// address of a top-level function as an i64 — the `step` function pointer a
    /// `spawn` hands to the session scheduler (§11).
    FuncAddr(String),
    /// `putStrLn :: String -> IO ()` (runtime)
    PutStrLn(Atom),
    /// `putStr :: String -> IO ()` (runtime, no newline)
    PutStr(Atom),
    /// `show :: Int -> String` (runtime)
    ShowInt(Atom),
    // --- arenas (§3): `clos` receives the arena; at the end the reset happens ---
    /// `withArena`/`withSubArena`: creates the (sub-)arena, runs `clos` with it, and
    /// **resets it** at the end (bulk reclamation). `parent` only serves `promote`.
    WithArena {
        parent: Option<Atom>,
        clos: Atom,
    },
    /// `allocateCell arena` — bump-allocates a cell in the arena.
    ArenaAlloc(Atom),
    /// `promote target cell` — copies the cell to arena `target` (saves it from the reset).
    Promote(Atom, Atom),
    /// `arena_mark arena` — saves the top of the bump-pointer.
    ArenaMark(Atom),
    /// `arena_release mark` — restores the bump-pointer (reclaims what was allocated since the mark).
    ArenaRelease(Atom),
    /// Call to a named runtime function (`Buffer`/§4 builtins and the like):
    /// `func(args…)`, devolvendo valor sse `returns`.
    RtCall {
        func: String,
        args: Vec<Atom>,
        returns: bool,
    },
    /// FFI call (§18): the C function `name` with the Int ABI (i64), resolved by
    /// `dlsym`. Returns i64.
    Ffi {
        name: String,
        args: Vec<Atom>,
    },
    /// AST shape outside the native subset — codegen rejects with this text
    Unsupported(String),
}

/// Lado direito de um `let` (ou o resultado): folha ou controlo.
#[derive(Debug, Clone)]
pub enum Rhs {
    Op(Op),
    If(Atom, Box<Term>, Box<Term>),
    Case(Atom, Vec<(CPat, Term)>),
}

/// A sequence of `let`s ending in a result.
#[derive(Debug, Clone)]
pub enum Term {
    Let(String, Rhs, Box<Term>),
    /// `drop x; …` — frees the heap object `x` at its death point
    /// (Auto-Drop, §2; inserted by the reclamation analysis, not the lowering).
    /// The `Option<String>` is the `data` type name of `x` (when known): if the
    /// type owns heap fields, the backend calls the recursive destructor
    /// `axion_drop_<T>` (deep-drop); otherwise, a flat `free`.
    Drop(String, Option<String>, Box<Term>),
    Ret(Rhs),
}

/// `case` patterns supported natively.
#[derive(Debug, Clone)]
pub enum CPat {
    Int(i64),
    Var(String),
    Wild,
    Tuple(Vec<CPat>),
    /// constructor + sub-patterns. 1-constructor types destructure without a tag;
    /// sum types compare the value's tag (offset 0) with the constructor's.
    Con(String, Vec<CPat>),
}

/// A function in the Core: top-level, `where` local, or lifted lambda.
#[derive(Debug, Clone)]
pub struct CoreFn {
    pub name: String,
    pub params: Vec<String>,
    /// captured names (empty for non-lambdas); loaded from the env in codegen
    pub captures: Vec<String>,
    pub is_closure: bool,
    /// `%1` heap-typed parameters: the callee **owns them** and frees them at their
    /// death point (cross-function reclamation — Auto-Drop, §2)
    pub owned_params: Vec<String>,
    pub body: Term,
}

// --- native type classification (shared with codegen) ---

/// Types represented by an `i64`: `Int`, `String`, `IO`, a `data`, or a
/// function (pointer to closure `{fn_ptr, captures…}`).
pub fn native_ty(t: &Type, data_types: &HashSet<String>) -> bool {
    // Arrow/Unit/type variable → i64. The native ABI is uniformly i64
    // (Int/Bool/pointers/closures), so a polymorphic position is always
    // i64-representable — which lets parametric/higher-order functions
    // (compose, foldr, …) compile, now that eta-expansion guarantees they are
    // applied at full arity (without the earlier partial-application error).
    if matches!(t, Type::Arrow { .. } | Type::Unit | Type::Var(_)) {
        return true;
    }
    match t.head_con() {
        // Int/Float/String/IO; arena (Arena/Cell/Mark); Buffer (§4); unit-token;
        // fixed-width integers (§4) — i64 in the ABI (Float as its f64 bit pattern)
        Some(
            "Int" | "Float" | "Bool" | "String" | "IO" | "Arena" | "Cell" | "Mark" | "Buffer"
            | "()" | "U8" | "U16" | "U32" | "U64" | "I8" | "I16" | "I32" | "I64" | "Word" | "Byte",
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

/// Type allocated on the heap by `axion_alloc` (record/`data` or tuple). Excludes
/// `Int`/`IO` (pure i64), `String` (a runtime C-string, not ours) and functions
/// (closures are reclaimed conservatively — they may be called).
fn heap_ty(t: &Type, data_types: &HashSet<String>) -> bool {
    match t {
        Type::Tuple(_) => true,
        _ => t.head_con().is_some_and(|h| data_types.contains(h)),
    }
}

pub fn is_int(t: &Type) -> bool {
    matches!(t.head_con(), Some("Int"))
}

pub fn is_float(t: &Type) -> bool {
    matches!(t.head_con(), Some("Float"))
}

pub fn is_bool(t: &Type) -> bool {
    matches!(t.head_con(), Some("Bool"))
}

/// BUILT-IN infix operators (`Int` arithmetic/comparison), which lower to
/// `Op::Prim`. The rest is a user infix operator — a named function
/// applied to two arguments. Matches `interp::is_builtin_op`.
pub fn is_builtin_op(op: &str) -> bool {
    matches!(op, "+" | "-" | "*" | "mod" | "==" | "<" | ">")
}

/// FLOAT infix operators — arithmetic (`+. -. *. /.`) and comparisons
/// (`<. >. ==.`) — all of which lower to `Op::PrimF`.
pub fn is_float_op(op: &str) -> bool {
    is_float_arith(op) || is_float_cmp(op)
}

/// Unary Float math builtins (`Float -> Float`), lowered to `Op::FloatUnary`.
pub fn is_float_unary(name: &str) -> bool {
    matches!(name, "sqrt" | "floor" | "abs")
}

/// FLOAT arithmetic operators (result is `Float`).
pub fn is_float_arith(op: &str) -> bool {
    matches!(op, "+." | "-." | "*." | "/.")
}

/// FLOAT comparison operators (result is `Bool`).
pub fn is_float_cmp(op: &str) -> bool {
    matches!(op, "<." | ">." | "==.")
}

pub fn data_type_names(module: &ast::Module) -> HashSet<String> {
    module.datas.iter().map(|d| d.name.clone()).collect()
}

/// Layout of records/`data` values. A **single**-constructor type has no
/// tag: `[field0][field1]…` (field i at i×8). A **sum** type (multi-constructor)
/// carries a **tag** (the constructor index) at offset 0: `[tag][field0]…` (field
/// i em (1+i)×8). Partilhado pelos backends; um `i64` por slot.
#[derive(Default)]
pub struct RecordInfo {
    con_fields: HashMap<String, Vec<String>>, // named fields
    field_owner: HashMap<String, String>,
    single_con: HashSet<String>, // tagless constructors (single-con type)
    con_tag: HashMap<String, i32>, // constructor index within its type
    con_arity: HashMap<String, usize>, // total number of fields (named or not)
    // --- deep-drop (§2): structural reclamation of nested fields ---
    con_type: HashMap<String, String>, // constructor → name of its type
    type_cons: HashMap<String, Vec<String>>, // type → constructors (in tag order)
    /// constructor → `data`-typed fields it **owns**: (offset, type name).
    /// They are separate allocations that a flat `free` doesn't reclaim → deep-drop.
    con_drop_slots: HashMap<String, Vec<(i32, String)>>,
    /// types that own (somewhere) a `data`-typed field → need a destructor.
    needs_deep: HashSet<String>,
}

impl RecordInfo {
    pub fn build(module: &ast::Module) -> RecordInfo {
        let mut r = RecordInfo::default();
        let data_names: HashSet<String> = module.datas.iter().map(|d| d.name.clone()).collect();
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
                r.con_type.insert(c.name.clone(), d.name.clone());
                r.type_cons
                    .entry(d.name.clone())
                    .or_default()
                    .push(c.name.clone());
                if d.cons.len() == 1 {
                    r.single_con.insert(c.name.clone());
                }
            }
        }
        // second pass: offsets now computable (tag/arity ready) → drop slots.
        for d in &module.datas {
            for c in &d.cons {
                let mut slots = Vec::new();
                for (i, f) in c.fields.iter().enumerate() {
                    // a `data`-typed field is a heap allocation owned by the
                    // record → must be reclaimed when the parent dies. Tuples and
                    // non-heap (Int/String/Buffer/function) are left out (see docs).
                    if let Some(h) = f.ty.head_con() {
                        if data_names.contains(h) {
                            slots.push((r.field_offset(&c.name, i), h.to_string()));
                        }
                    }
                }
                if !slots.is_empty() {
                    r.needs_deep.insert(d.name.clone());
                }
                r.con_drop_slots.insert(c.name.clone(), slots);
            }
        }
        r
    }

    /// `true` if the type (name) owns heap fields → needs a recursive
    /// destructor instead of a flat `free`.
    pub fn needs_deep_drop(&self, ty: &str) -> bool {
        self.needs_deep.contains(ty)
    }

    /// Name of a constructor's type.
    pub fn con_type(&self, con: &str) -> Option<&str> {
        self.con_type.get(con).map(String::as_str)
    }

    /// Constructors of a type, in tag order.
    pub fn type_cons(&self, ty: &str) -> Option<&[String]> {
        self.type_cons.get(ty).map(Vec::as_slice)
    }

    /// `data`-typed fields a constructor owns: (offset, type name).
    pub fn drop_slots(&self, con: &str) -> &[(i32, String)] {
        self.con_drop_slots.get(con).map_or(&[], Vec::as_slice)
    }

    /// Types that need a generated destructor, in deterministic order.
    pub fn deep_drop_types(&self) -> Vec<String> {
        let mut v: Vec<String> = self.needs_deep.iter().cloned().collect();
        v.sort();
        v
    }

    /// `true` if the constructor belongs to a single-constructor type (no tag).
    pub fn is_single_con(&self, con: &str) -> bool {
        self.single_con.contains(con)
    }

    /// The tag (index) of a constructor, if its type is a sum (>1 con).
    pub fn tag(&self, con: &str) -> Option<i32> {
        (!self.is_single_con(con))
            .then(|| self.con_tag.get(con).copied())
            .flatten()
    }

    /// Total arity (named or unnamed fields) of a constructor.
    pub fn con_arity(&self, con: &str) -> Option<usize> {
        self.con_arity.get(con).copied()
    }

    /// Number of slots to allocate for a constructor (fields + optional tag).
    pub fn con_slots(&self, con: &str) -> Option<usize> {
        self.con_arity(con)
            .map(|n| n + usize::from(self.tag(con).is_some()))
    }

    /// Offset of the i-th (positional) field of a constructor (adjusted for the tag).
    pub fn field_offset(&self, con: &str, i: usize) -> i32 {
        let base = usize::from(self.tag(con).is_some());
        (base + i) as i32 * 8
    }

    /// Offset (in bytes) of a named field, and the list of its record's fields.
    pub fn field(&self, name: &str) -> Option<(i32, &[String])> {
        let con = self.field_owner.get(name)?;
        let fields = self.con_fields.get(con)?;
        let idx = fields.iter().position(|f| f == name)?;
        Some((self.field_offset(con, idx), fields))
    }
}

/// Native candidate: all parameters and the return are `i64`-representable,
/// and the body calls no typeclass method (which is interp-only when unresolved
/// — dispatch is dynamic, no native symbol). Without this, generic prelude
/// functions like `maxOr`/`nub` (i64-ok signature, but calling `le`/`eq`)
/// would pass the filter and blow up in codegen with an unbound symbol.
fn top_candidate(
    f: &ast::Func,
    data_types: &HashSet<String>,
    methods: &HashSet<String>,
) -> Option<usize> {
    let sig = f.sig.as_ref()?;
    let ok = sig.param_types().iter().all(|t| native_ty(t, data_types))
        && native_ty(result_type(sig), data_types)
        && !calls_method(f, methods);
    ok.then(|| f.clauses.first().map(|c| c.pats.len()).unwrap_or(0))
}

/// True if some body (clause, guard or `where`) references a typeclass method
/// name — in which case the function is not natively compilable.
fn calls_method(f: &ast::Func, methods: &HashSet<String>) -> bool {
    if methods.is_empty() {
        return false;
    }
    let mut fv = HashSet::new();
    for c in &f.clauses {
        match &c.body {
            Body::Plain(e) => free_vars(e, &HashSet::new(), &mut fv),
            Body::Guarded(arms) => {
                for (g, r) in arms {
                    free_vars(g, &HashSet::new(), &mut fv);
                    free_vars(r, &HashSet::new(), &mut fv);
                }
            }
        }
        for w in &c.wher {
            if calls_method(w, methods) {
                return true;
            }
        }
    }
    fv.iter().any(|n| methods.contains(n))
}

/// All names referenced in `f`'s bodies (clauses, guards, `where`),
/// for the transitive native candidacy — those that are top-level functions must be
/// themselves compilable.
fn body_refs(f: &ast::Func, out: &mut HashSet<String>) {
    for c in &f.clauses {
        match &c.body {
            Body::Plain(e) => free_vars(e, &HashSet::new(), out),
            Body::Guarded(arms) => {
                for (g, r) in arms {
                    free_vars(g, &HashSet::new(), out);
                    free_vars(r, &HashSet::new(), out);
                }
            }
        }
        for w in &c.wher {
            body_refs(w, out);
        }
    }
}

// --- scope utilities (free variables, for closure capture) ---

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
        Expr::Int(_, _) | Expr::Float(_, _) | Expr::Str(_, _) | Expr::Con(_, _) => {}
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

/// Names resolved as globals (not captured nor called by pointer):
/// top-level functions, `where` locals, constructors, selectors and builtins.
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
        "showInt",
        "showFloat",
        "strAppend",
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
        "toFloat",
        "truncate",
        "sqrt",
        "floor",
        "abs",
    ] {
        g.insert(b.to_string());
    }
    g
}

// --- a baixada AST → Core ---

type LamMeta = HashMap<Span, (String, Vec<String>)>;

/// Lowering context: the global names, the field selectors, the mangling of
/// `where` of the current function, and the lambdas' meta-information.
struct Lower<'a> {
    globals: &'a HashSet<String>,
    fields: &'a HashSet<String>,
    lam_meta: &'a LamMeta,
    /// spans of the `RecordUpd`s eligible for in-place mutation (Linear Elision, §2)
    inplace: &'a HashSet<Span>,
    /// names of the FFI imports (§18) — called via `Op::Ffi`
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

    /// Lowers `e` to an atom, pushing intermediate `let`s onto `buf`.
    fn atom(&mut self, e: &Expr, buf: &mut Vec<(String, Rhs)>) -> Atom {
        match e {
            Expr::Int(n, _) => Atom::Int(*n),
            Expr::Float(f, _) => Atom::Float(*f),
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
                // drags the trivial binds into `buf` and continues in the body
                for f in binds {
                    let rhs = match f.clauses.as_slice() {
                        [c] if c.pats.is_empty() => match &c.body {
                            Body::Plain(e) => self.rhs(e, buf),
                            _ => Rhs::Op(Op::Unsupported("let with guards".into())),
                        },
                        _ => Rhs::Op(Op::Unsupported("non-trivial let".into())),
                    };
                    buf.push((f.name.clone(), rhs));
                }
                self.rhs(body, buf)
            }
            _ => Rhs::Op(self.op(e, buf)),
        }
    }

    /// Lowers `e` to a leaf `Op` (the caller guarantees it is not if/case/let).
    fn op(&mut self, e: &Expr, buf: &mut Vec<(String, Rhs)>) -> Op {
        match e {
            Expr::Int(_, _) | Expr::Float(_, _) | Expr::Str(_, _) | Expr::Var(_, _) => {
                Op::Atom(self.atom(e, buf))
            }
            Expr::BinOp(op, l, r, _) => {
                let a = self.atom(l, buf);
                let b = self.atom(r, buf);
                if is_float_op(op) {
                    Op::PrimF(op.clone(), a, b)
                } else if is_builtin_op(op) {
                    Op::Prim(op.clone(), a, b)
                } else if op == "++" {
                    // list concatenation: lowers to the prelude's `append`. (A
                    // `String` `++` is resolved to `++#str` by inference.)
                    self.call_named("append", vec![a, b])
                } else if op == "++#str" {
                    // native String concatenation (`strAppend` → axion_strcat).
                    Op::RtCall {
                        func: "axion_strcat".into(),
                        args: vec![a, b],
                        returns: true,
                    }
                } else {
                    // user infix operator: `x `f` y` ≡ `f x y`. Lowers to a call —
                    // so it works natively too (first-order).
                    self.call_named(op, vec![a, b])
                }
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
                None => Op::Unsupported("lambda not pre-processed".into()),
            },
            Expr::App(_, _, _) => self.app(e, buf),
            Expr::Con(name, _) => match name.as_str() {
                "True" => Op::Atom(Atom::Int(1)),
                "False" => Op::Atom(Atom::Int(0)),
                // nullary constructor (e.g. `Nothing`)
                _ => Op::MakeCon {
                    con: name.clone(),
                    args: Vec::new(),
                },
            },
            Expr::If(_, _, _, _) | Expr::Case(_, _, _) | Expr::Let(_, _, _) => {
                // control in leaf position: name it via `buf`
                Op::Atom(self.atom(e, buf))
            }
        }
    }

    /// Lowers an application, classifying the head (builtin / selector / call
    /// direct / indirect call to a closure).
    fn app(&mut self, e: &Expr, buf: &mut Vec<(String, Rhs)>) -> Op {
        let (head, args) = spine(e);
        // applied constructor `Con a b …` → positional `data` value
        if let Expr::Con(cname, _) = head {
            let vals = args.iter().map(|a| self.atom(a, buf)).collect();
            return Op::MakeCon {
                con: cname.clone(),
                args: vals,
            };
        }
        let Expr::Var(name, _) = head else {
            // compound head (e.g. an applied lambda) → closure
            let clos = self.atom(head, buf);
            let vals = args.iter().map(|a| self.atom(a, buf)).collect();
            return Op::CallClosure(clos, vals);
        };
        if name == "putStrLn" && args.len() == 1 {
            return Op::PutStrLn(self.atom(args[0], buf));
        }
        if name == "putStr" && args.len() == 1 {
            return Op::PutStr(self.atom(args[0], buf));
        }
        if name == "showInt" && args.len() == 1 {
            return Op::ShowInt(self.atom(args[0], buf));
        }
        if name == "showFloat" && args.len() == 1 {
            return self.rtcall("axion_show_float", &args, true, buf);
        }
        if name == "strAppend" && args.len() == 2 {
            return self.rtcall("axion_strcat", &args, true, buf);
        }
        if name == "toFloat" && args.len() == 1 {
            return Op::IntToFloat(self.atom(args[0], buf));
        }
        if name == "truncate" && args.len() == 1 {
            return Op::FloatToInt(self.atom(args[0], buf));
        }
        if is_float_unary(name) && args.len() == 1 {
            return Op::FloatUnary(name.clone(), self.atom(args[0], buf));
        }
        if self.fields.contains(name) && args.len() == 1 {
            let rec = self.atom(args[0], buf);
            return Op::Field {
                name: name.clone(),
                rec,
            };
        }
        // arena builtins (§3)
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
            // linear Buffer U8 (§4/§5): builtins that are runtime calls
            ("newBuffer", 1) => return self.rtcall("axion_buf_new", &args, true, buf),
            ("bufIota", 1) => return self.rtcall("axion_buf_iota", &args, true, buf),
            ("xorInPlace", 2) => return self.rtcall("axion_buf_xor", &args, true, buf),
            ("sumBytes", 1) => return self.rtcall("axion_buf_sum", &args, true, buf),
            ("free", 1) => return self.rtcall("axion_buf_free", &args, false, buf),
            ("foldBytes", 3) => return self.rtcall("axion_fold_bytes", &args, true, buf),
            // `imperative e` = e (the imperative block is identity; §5)
            ("imperative", 1) => return self.op(args[0], buf),
            // withBuffer n f = f (newBuffer n): allocates and passes to the closure (which consumes)
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
        self.call_named(name, vals)
    }

    /// Lowers a call by name (`name` applied to `vals`), resolving whether it is
    /// FFI, a top-level function (direct call, with mangling), or a local variable of
    /// function type (indirect call). Shared between normal application and the
    /// operadores infixos de utilizador.
    fn call_named(&self, name: &str, vals: Vec<Atom>) -> Op {
        if self.foreigns.contains(name) {
            // FFI import (§18): C call with the Int ABI
            Op::Ffi {
                name: name.to_string(),
                args: vals,
            }
        } else if self.globals.contains(name) {
            // top-level function / `where` local (resolves the mangling)
            let target = self
                .locals
                .get(name)
                .cloned()
                .unwrap_or_else(|| name.to_string());
            Op::CallDirect(target, vals)
        } else {
            // local variable of function type → indirect call
            Op::CallClosure(Atom::Var(name.to_string()), vals)
        }
    }

    /// Lowers a builtin that is a runtime call (`Buffer`/§4).
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

    /// Lowers `e` to a `Term` (sequence of `let`s + result).
    fn term(&mut self, e: &Expr) -> Term {
        let mut buf = Vec::new();
        let rhs = self.rhs(e, &mut buf);
        wrap(buf, Term::Ret(rhs))
    }

    /// Desugars multi-clause into an `if` chain (requires a catch-all at the end).
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

        // binds this clause's variable patterns to the parameters and emits the body
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
                "function without a catch-all clause".into(),
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

    /// Guards → chain of `if`: `| g0 = r0 | g1 = r1 | otherwise = rn` becomes
    /// `if g0 then r0 else if g1 then r1 else rn`. `otherwise`/`True` are
    /// unconditional; if no guard covers, it is exhaustion (unsupported).
    fn guarded(&mut self, arms: &[(Expr, Expr)]) -> Term {
        let mut acc = Term::Ret(Rhs::Op(Op::Unsupported("non-exhaustive guards".into())));
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

/// Wraps the `let`s of `buf` (in order) around `tail`.
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

/// Lowers a function (top-level or `where`), returning `(params, body,
/// owned-params)`. Single-clause functions with only variable/`_` patterns
/// name the parameters directly (without the redundant alias `let n = _p0`),
/// which gives a more readable Core and clean names for param reclamation.
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
    // `%1` heap-typed parameters → the callee owns them and frees them
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

/// Lowers the module to the Core: candidate top-level functions, their `where`
/// `where` (mangled) and the lifted lambdas (with capture).
/// Eta-expands the functions/constructors used as a value or partially
/// parcialmente, para o backend nativo (first-class functions via closures).
fn eta_expand(module: &ast::Module) -> ast::Module {
    // arity of each callable name: top-level functions (number of patterns), constructors
    // (field count), and the IO builtins that lower to an `Op`.
    let mut arity: HashMap<String, usize> = HashMap::new();
    for f in &module.funcs {
        arity.insert(
            f.name.clone(),
            f.clauses.first().map(|c| c.pats.len()).unwrap_or(0),
        );
    }
    for d in &module.datas {
        for c in &d.cons {
            arity.insert(c.name.clone(), c.fields.len());
        }
    }
    for b in [
        "putStrLn", "putStr", "showInt", "showFloat", "toFloat", "truncate", "sqrt", "floor",
        "abs",
    ] {
        arity.entry(b.into()).or_insert(1);
    }
    arity.entry("strAppend".into()).or_insert(2);
    let mut e = Eta { arity, counter: 0 };
    let funcs = module.funcs.iter().map(|f| e.func(f)).collect();
    ast::Module {
        funcs,
        datas: module.datas.clone(),
        foreigns: module.foreigns.clone(),
        classes: module.classes.clone(),
        instances: module.instances.clone(),
    }
}

struct Eta {
    arity: HashMap<String, usize>,
    counter: usize,
}

impl Eta {
    /// Unique name + synthetic span (outside the range of real byte offsets).
    fn fresh(&mut self) -> (String, Span) {
        let n = self.counter;
        self.counter += 1;
        (format!("eta${n}"), (1_000_000_000 + n, 1_000_000_000 + n))
    }

    fn func(&mut self, f: &ast::Func) -> ast::Func {
        let clauses = f
            .clauses
            .iter()
            .map(|c| ast::Clause {
                pats: c.pats.clone(),
                body: match &c.body {
                    ast::Body::Plain(e) => ast::Body::Plain(self.expr(e)),
                    ast::Body::Guarded(arms) => ast::Body::Guarded(
                        arms.iter()
                            .map(|(g, r)| (self.expr(g), self.expr(r)))
                            .collect(),
                    ),
                },
                wher: c.wher.iter().map(|w| self.func(w)).collect(),
                span: c.span,
            })
            .collect();
        ast::Func {
            clauses,
            ..f.clone()
        }
    }

    /// Wraps `base` (callable, with `gap` missing arguments) in a lambda that
    /// receives the missing ones: `base` → `\v0 … v_{gap-1} -> base v0 … v_{gap-1}`.
    fn wrap(&mut self, base: Expr, gap: usize) -> Expr {
        let (_, lam_sp) = self.fresh();
        let mut pats = Vec::new();
        let mut body = base;
        for _ in 0..gap {
            let (name, vsp) = self.fresh();
            pats.push(Pat::Var(name.clone(), vsp));
            body = Expr::App(Box::new(body), Box::new(Expr::Var(name, vsp)), lam_sp);
        }
        Expr::Lam(pats, Box::new(body), lam_sp)
    }

    fn name_arity(&self, e: &Expr) -> Option<usize> {
        match e {
            Expr::Var(n, _) | Expr::Con(n, _) => self.arity.get(n).copied(),
            _ => None,
        }
    }

    fn expr(&mut self, e: &Expr) -> Expr {
        match e {
            Expr::Int(_, _) | Expr::Float(_, _) | Expr::Str(_, _) => e.clone(),
            // callable name used as a VALUE → eta-expand.
            Expr::Var(_, _) | Expr::Con(_, _) => match self.name_arity(e) {
                Some(k) if k > 0 => self.wrap(e.clone(), k),
                _ => e.clone(),
            },
            Expr::App(_, _, _) => {
                let (head, args) = spine(e);
                let targs: Vec<Expr> = args.iter().map(|a| self.expr(a)).collect();
                let n = targs.len();
                // the head: if it is a name/constructor it stays; otherwise recurse.
                let head_e = match head {
                    Expr::Var(_, _) | Expr::Con(_, _) => head.clone(),
                    _ => self.expr(head),
                };
                let sp = head.span();
                let applied = targs
                    .into_iter()
                    .fold(head_e, |acc, a| Expr::App(Box::new(acc), Box::new(a), sp));
                match self.name_arity(head) {
                    // PARTIAL application → completed with a lambda.
                    Some(k) if n < k => self.wrap(applied, k - n),
                    _ => applied,
                }
            }
            Expr::BinOp(op, l, r, sp) => Expr::BinOp(
                op.clone(),
                Box::new(self.expr(l)),
                Box::new(self.expr(r)),
                *sp,
            ),
            Expr::If(c, t, el, sp) => Expr::If(
                Box::new(self.expr(c)),
                Box::new(self.expr(t)),
                Box::new(self.expr(el)),
                *sp,
            ),
            Expr::Let(binds, body, sp) => Expr::Let(
                binds.iter().map(|f| self.func(f)).collect(),
                Box::new(self.expr(body)),
                *sp,
            ),
            Expr::Case(s, arms, sp) => Expr::Case(
                Box::new(self.expr(s)),
                arms.iter()
                    .map(|(p, b)| (p.clone(), self.expr(b)))
                    .collect(),
                *sp,
            ),
            Expr::Tuple(es, sp) => Expr::Tuple(es.iter().map(|x| self.expr(x)).collect(), *sp),
            Expr::RecordCon(c, fs, sp) => Expr::RecordCon(
                c.clone(),
                fs.iter().map(|(n, x)| (n.clone(), self.expr(x))).collect(),
                *sp,
            ),
            Expr::RecordUpd(b, fs, sp) => Expr::RecordUpd(
                Box::new(self.expr(b)),
                fs.iter().map(|(n, x)| (n.clone(), self.expr(x))).collect(),
                *sp,
            ),
            Expr::Lam(ps, body, sp) => Expr::Lam(ps.clone(), Box::new(self.expr(body)), *sp),
        }
    }
}

// ---------------- native session lowering (§11) ----------------
//
// Lowers `main = bound $ do …` and its `spawn` targets into cooperative
// state-machine `step` functions + a driver `main`, over the `axion_sess_*`
// runtime (codegen.rs / axion_rt.c). Each task is a defunctionalized
// continuation (§11): the only suspension point is a `recv` on an empty
// endpoint, at which the live locals are saved into a scheduler-owned state
// block (`[result, resume, locals…]`) and re-loaded on resume. Single-thread
// cooperative; M:N is a later layer. Handles the linear do-chain
// (spawn/send/recv/close); choice/cancellation are follow-up slices.

const SESS_SCHED: &str = "sess$sched";
const SESS_STATE: &str = "sess$st";

/// Head name and arguments of an application spine `f a b …`.
fn sess_spine(e: &Expr) -> (Option<&str>, Vec<&Expr>) {
    let mut args = Vec::new();
    let mut cur = e;
    while let Expr::App(f, a, _) = cur {
        args.push(a.as_ref());
        cur = f;
    }
    args.reverse();
    match cur {
        Expr::Var(n, _) | Expr::Con(n, _) => (Some(n.as_str()), args),
        _ => (None, args),
    }
}

/// `bound X` or `bound $ X` → `X`.
fn as_bound(e: &Expr) -> Option<&Expr> {
    match sess_spine(e) {
        (Some("bound"), args) if args.len() == 1 => Some(args[0]),
        _ => None,
    }
}

/// A unique key for a suspension `Case`: the span of its **scrutinee** (the
/// `recv`/`offer` application). The `Case` node's own span is NOT usable — the do
/// desugaring gives every `Case` in a block the same (whole-block) span, so it
/// would collapse distinct suspensions onto one index.
fn susp_key(e: &Expr) -> Span {
    match e {
        Expr::Case(scrut, _, _) => scrut.span(),
        _ => (0, 0),
    }
}

/// The `spawn` targets named anywhere in a session body (including choice arms).
fn spawn_targets(body: &Expr, out: &mut Vec<String>) {
    if let Expr::Case(scrut, arms, _) = body {
        if let (Some("spawn"), args) = sess_spine(scrut) {
            if let (Some(t), _) = sess_spine(args[0]) {
                out.push(t.to_string());
            }
        }
        for (_, b) in arms {
            spawn_targets(b, out);
        }
    }
}

/// All variables bound (by patterns) anywhere in a session body.
fn collect_bound_vars(e: &Expr, out: &mut Vec<String>) {
    if let Expr::Case(_, arms, _) = e {
        for (pat, body) in arms {
            pat_vars(pat, out);
            collect_bound_vars(body, out);
        }
    }
}

/// Collects the suspension points (`recv` value, `offer` label) in DFS order,
/// each with the variables live in scope just before it (params + earlier binds).
fn collect_suspensions<'a>(
    e: &'a Expr,
    scope: &mut Vec<String>,
    out: &mut Vec<(&'a Expr, Vec<String>)>,
) {
    let Expr::Case(scrut, arms, _) = e else {
        return;
    };
    let head = sess_spine(scrut).0;
    let is_offer = head == Some("offer");
    if head == Some("recv") || is_offer {
        out.push((e, scope.clone()));
    }
    if arms.len() == 1 && !is_offer {
        let (pat, rest) = &arms[0];
        let base = scope.len();
        pat_vars(pat, scope);
        collect_suspensions(rest, scope, out);
        scope.truncate(base);
    } else {
        // choice (`offer`): each arm binds its endpoint, then continues
        for (pat, body) in arms {
            let base = scope.len();
            pat_vars(pat, scope);
            collect_suspensions(body, scope, out);
            scope.truncate(base);
        }
    }
}

/// State-block layout of one session task: `[result@0, resume@8, locals@16…]`.
struct SessLayout {
    slot: HashMap<String, i32>, // var → byte offset
    size: i32,                  // block size in bytes
    param_slots: Vec<i32>,      // offsets of the params (filled in by `spawn`)
    step: String,               // step-function name
}

fn sess_layout(pats: &[Pat], body: &Expr, step: String) -> SessLayout {
    let mut slot = HashMap::new();
    let mut off = 16; // 0 = result, 8 = resume
    let mut param_slots = Vec::new();
    let add = |v: &str, off: &mut i32, slot: &mut HashMap<String, i32>| -> i32 {
        let o = *off;
        slot.insert(v.to_string(), o);
        *off += 8;
        o
    };
    let mut params = Vec::new();
    for p in pats {
        pat_vars(p, &mut params);
    }
    for v in &params {
        param_slots.push(add(v, &mut off, &mut slot));
    }
    let mut vars = Vec::new();
    collect_bound_vars(body, &mut vars);
    for v in &vars {
        if !slot.contains_key(v) {
            add(v, &mut off, &mut slot);
        }
    }
    SessLayout {
        slot,
        size: off,
        param_slots,
        step,
    }
}

/// Generator of one task's state machine.
struct SessGen<'a> {
    name: &'a str, // this task's session function name (for self-recursion)
    lay: &'a SessLayout,
    all: &'a HashMap<String, SessLayout>,
    tags: &'a HashMap<String, i64>, // choice label (constructor) → tag
    fns: &'a HashSet<String>,       // top-level functions callable in value position
    susp: HashMap<Span, i32>,       // suspension `Case` span → index (resume = index+1)
    susp_live: Vec<Vec<String>>,    // live vars in scope at each suspension
    tmp: u32,
}

impl SessGen<'_> {
    fn fresh(&mut self) -> String {
        let n = self.tmp;
        self.tmp += 1;
        format!("sess$t{n}")
    }
    fn sched_atom() -> Atom {
        Atom::Var(SESS_SCHED.to_string())
    }
    fn state_atom() -> Atom {
        Atom::Var(SESS_STATE.to_string())
    }
    fn rt(func: &str, args: Vec<Atom>, returns: bool) -> Rhs {
        Rhs::Op(Op::RtCall {
            func: func.to_string(),
            args,
            returns,
        })
    }

    /// Lowers a simple value expression (`Int`/`Var`/arithmetic) to an atom,
    /// pushing any needed `let`s into `binds`.
    fn val(&mut self, e: &Expr, binds: &mut Vec<(String, Rhs)>) -> Atom {
        match e {
            Expr::Int(n, _) => Atom::Int(*n),
            Expr::Var(n, _) => Atom::Var(n.clone()),
            Expr::BinOp(op, a, b, _) => {
                let av = self.val(a, binds);
                let bv = self.val(b, binds);
                let t = self.fresh();
                binds.push((t.clone(), Rhs::Op(Op::Prim(op.clone(), av, bv))));
                Atom::Var(t)
            }
            // a call to a top-level native function (e.g. `fib n`) — lets a worker
            // do real compute between channel ops. The callee is compiled by the
            // normal native path (candidacy filter), so `CallDirect` resolves.
            Expr::App(..) => {
                let (head, args) = sess_spine(e);
                match head.filter(|n| self.fns.contains(*n)) {
                    Some(name) => {
                        let name = name.to_string();
                        let mut atoms = Vec::with_capacity(args.len());
                        for a in &args {
                            atoms.push(self.val(a, binds));
                        }
                        let t = self.fresh();
                        binds.push((t.clone(), Rhs::Op(Op::CallDirect(name, atoms))));
                        Atom::Var(t)
                    }
                    None => self.unsupported(binds),
                }
            }
            _ => self.unsupported(binds),
        }
    }

    /// Outside the native session subset (a recursive/looping worker, delegation,
    /// a non-native call, …). Fail LOUDLY — sessions bypass the native-candidacy
    /// filter, so a silent `0` here would miscompile while the interpreter stays
    /// correct. `Op::Unsupported` makes the native backends reject it clearly.
    fn unsupported(&mut self, binds: &mut Vec<(String, Rhs)>) -> Atom {
        let t = self.fresh();
        binds.push((
            t.clone(),
            Rhs::Op(Op::Unsupported(
                "session value outside the native subset".into(),
            )),
        ));
        Atom::Var(t)
    }

    /// Generates the tail (block value): stores it into `result` and returns done.
    fn gen_tail(&mut self, tail: &Expr) -> Term {
        // self-recursive session tail call `f d` (§6, server loop): store the new
        // endpoint into the parameter slot, reset the resume tag to the loop head,
        // and return status 2 (re-queue) so the scheduler re-dispatches the task.
        let (head, args) = sess_spine(tail);
        if head == Some(self.name) && args.len() == 1 {
            if let Some(&pslot) = self.lay.param_slots.first() {
                let mut binds = Vec::new();
                let ep = self.val(args[0], &mut binds);
                binds.push((
                    self.fresh(),
                    Rhs::Op(Op::StoreRaw(Self::state_atom(), pslot, ep)),
                ));
                binds.push((
                    self.fresh(),
                    Rhs::Op(Op::StoreRaw(Self::state_atom(), 8, Atom::Int(0))),
                ));
                return wrap(binds, Term::Ret(Rhs::Op(Op::Atom(Atom::Int(2)))));
            }
        }
        let mut binds = Vec::new();
        let result = match sess_spine(tail).0 {
            Some("close") | Some("cancel") => Atom::Int(0), // effect as tail → unit
            _ => self.val(tail, &mut binds),
        };
        binds.push((
            self.fresh(),
            Rhs::Op(Op::StoreRaw(Self::state_atom(), 0, result)),
        ));
        wrap(binds, Term::Ret(Rhs::Op(Op::Atom(Atom::Int(1)))))
    }

    /// `store x = <val>` as an anonymous binding.
    fn store(&mut self, off: i32, val: Atom) -> (String, Rhs) {
        (
            self.fresh(),
            Rhs::Op(Op::StoreRaw(Self::state_atom(), off, val)),
        )
    }

    /// The blocked branch of a suspension `idx`: save its live locals, set the
    /// resume tag to `idx+1`, and return 0 (not done).
    fn block(&mut self, idx: i32) -> Term {
        let live = self.susp_live[idx as usize].clone();
        let mut binds = Vec::new();
        for v in &live {
            let s = self.lay.slot[v];
            binds.push(self.store(s, Atom::Var(v.clone())));
        }
        let r = self.store(8, Atom::Int((idx + 1) as i64));
        binds.push(r);
        wrap(binds, Term::Ret(Rhs::Op(Op::Atom(Atom::Int(0)))))
    }

    /// Lowers one session continuation expression (a `Case` chain or a tail).
    fn gen_cont(&mut self, e: &Expr) -> Term {
        let Expr::Case(scrut, arms, _) = e else {
            return self.gen_tail(e);
        };
        let key = scrut.span(); // suspension key = scrutinee span (see susp_key)
        let (head, args) = sess_spine(scrut);
        match head {
            Some("recv") => self.gen_recv(&arms[0].0, &arms[0].1, args[0], key),
            Some("offer") => self.gen_offer(args[0], arms, key),
            Some("spawn") => self.gen_spawn(&arms[0].0, args[0], &arms[0].1),
            Some("send") => self.gen_send(&arms[0].0, &args, &arms[0].1),
            Some("select") => self.gen_select(&arms[0].0, &args, &arms[0].1),
            Some("cancel") => self.gen_cancel(args[0], &arms[0].1),
            Some("close") => self.gen_close(&arms[0].0, &arms[0].1),
            _ => self.gen_tail(e),
        }
    }

    /// `(value, endpoint) <- recv ep; rest` — the only value suspension.
    fn gen_recv(&mut self, pat: &Pat, rest: &Expr, ep_expr: &Expr, span: Span) -> Term {
        let idx = self.susp[&span];
        let mut binds = Vec::new();
        let ep = self.val(ep_expr, &mut binds);
        let pend = self.fresh();
        binds.push((
            pend.clone(),
            Self::rt(
                "axion_sess_pending",
                vec![Self::sched_atom(), ep.clone()],
                true,
            ),
        ));
        let rv = self.fresh();
        let mut pv = Vec::new();
        pat_vars(pat, &mut pv);
        let mut cbinds = vec![(
            rv.clone(),
            Self::rt(
                "axion_sess_recv",
                vec![Self::sched_atom(), ep.clone()],
                true,
            ),
        )];
        if let Some(v0) = pv.first() {
            cbinds.push((v0.clone(), Rhs::Op(Op::Atom(Atom::Var(rv)))));
        }
        if let Some(v1) = pv.get(1) {
            cbinds.push((v1.clone(), Rhs::Op(Op::Atom(ep))));
        }
        let cont = wrap(cbinds, self.gen_cont(rest));
        let blocked = self.block(idx);
        wrap(
            binds,
            Term::Ret(Rhs::If(Atom::Var(pend), Box::new(cont), Box::new(blocked))),
        )
    }

    /// `case offer ep of { L1 d -> B1 ; … }` — a label suspension + dispatch.
    fn gen_offer(&mut self, ep_expr: &Expr, arms: &[(Pat, Expr)], span: Span) -> Term {
        let idx = self.susp[&span];
        let mut binds = Vec::new();
        let ep = self.val(ep_expr, &mut binds);
        let pend = self.fresh();
        binds.push((
            pend.clone(),
            Self::rt(
                "axion_sess_pending",
                vec![Self::sched_atom(), ep.clone()],
                true,
            ),
        ));
        let label = self.fresh();
        let recv_bind = (
            label.clone(),
            Self::rt(
                "axion_sess_recv",
                vec![Self::sched_atom(), ep.clone()],
                true,
            ),
        );
        // one term per arm (binding the branch endpoint = ep), then a tag dispatch
        let mut arm_terms: Vec<(Option<i64>, Term)> = Vec::new();
        for (pat, body) in arms {
            let (tag, mut inner) = match pat {
                Pat::Con(lname, ps, _) => (self.tags.get(lname).copied(), ps.iter().collect()),
                _ => (None, Vec::<&Pat>::new()),
            };
            let mut ab = Vec::new();
            if let Some(p0) = inner.pop() {
                let mut iv = Vec::new();
                pat_vars(p0, &mut iv);
                if let Some(d) = iv.first() {
                    ab.push((d.clone(), Rhs::Op(Op::Atom(ep.clone()))));
                }
            }
            let t = wrap(ab, self.gen_cont(body));
            arm_terms.push((tag, t));
        }
        // fold into nested ifs; the last arm is the (exhaustive) else
        let mut dispatch = arm_terms
            .pop()
            .map(|(_, t)| t)
            .unwrap_or_else(|| Term::Ret(Rhs::Op(Op::Atom(Atom::Int(0)))));
        for (tag, t) in arm_terms.into_iter().rev() {
            let eq = self.fresh();
            dispatch = Term::Let(
                eq.clone(),
                Rhs::Op(Op::Prim(
                    "==".into(),
                    Atom::Var(label.clone()),
                    Atom::Int(tag.unwrap_or(0)),
                )),
                Box::new(Term::Ret(Rhs::If(
                    Atom::Var(eq),
                    Box::new(t),
                    Box::new(dispatch),
                ))),
            );
        }
        let success = wrap(vec![recv_bind], dispatch);
        let blocked = self.block(idx);
        wrap(
            binds,
            Term::Ret(Rhs::If(
                Atom::Var(pend),
                Box::new(success),
                Box::new(blocked),
            )),
        )
    }

    /// `c <- spawn f; rest` — fork a child task on a fresh channel.
    fn gen_spawn(&mut self, pat: &Pat, target_expr: &Expr, rest: &Expr) -> Term {
        let target = sess_spine(target_expr).0.expect("spawn target").to_string();
        let tl = &self.all[&target];
        let (size, pslot, step) = (tl.size, tl.param_slots.first().copied(), tl.step.clone());
        let mut binds = Vec::new();
        let a = self.fresh();
        binds.push((
            a.clone(),
            Self::rt("axion_sess_channel", vec![Self::sched_atom()], true),
        ));
        let cs = self.fresh();
        binds.push((
            cs.clone(),
            Self::rt(
                "axion_sess_alloc",
                vec![Self::sched_atom(), Atom::Int(size as i64)],
                true,
            ),
        ));
        // the child's first parameter is the peer endpoint (a + 1)
        let ap1 = self.fresh();
        binds.push((
            ap1.clone(),
            Rhs::Op(Op::Prim("+".into(), Atom::Var(a.clone()), Atom::Int(1))),
        ));
        if let Some(pslot) = pslot {
            binds.push((
                self.fresh(),
                Rhs::Op(Op::StoreRaw(Atom::Var(cs.clone()), pslot, Atom::Var(ap1))),
            ));
        }
        let fa = self.fresh();
        binds.push((fa.clone(), Rhs::Op(Op::FuncAddr(step))));
        binds.push((
            self.fresh(),
            Self::rt(
                "axion_sess_spawn",
                vec![Self::sched_atom(), Atom::Var(fa), Atom::Var(cs)],
                false,
            ),
        ));
        let mut pv = Vec::new();
        pat_vars(pat, &mut pv);
        if let Some(c) = pv.first() {
            binds.push((c.clone(), Rhs::Op(Op::Atom(Atom::Var(a)))));
        }
        wrap(binds, self.gen_cont(rest))
    }

    /// `c <- send ep v; rest`.
    fn gen_send(&mut self, pat: &Pat, args: &[&Expr], rest: &Expr) -> Term {
        let mut binds = Vec::new();
        let ep = self.val(args[0], &mut binds);
        let v = self.val(args[1], &mut binds);
        binds.push((
            self.fresh(),
            Self::rt(
                "axion_sess_send",
                vec![Self::sched_atom(), ep.clone(), v],
                false,
            ),
        ));
        let mut pv = Vec::new();
        pat_vars(pat, &mut pv);
        if let Some(c) = pv.first() {
            binds.push((c.clone(), Rhs::Op(Op::Atom(ep))));
        }
        wrap(binds, self.gen_cont(rest))
    }

    /// `c <- select Label ep; rest` — send the label's tag (internal choice, ⊕).
    fn gen_select(&mut self, pat: &Pat, args: &[&Expr], rest: &Expr) -> Term {
        let label_tag = match args[0] {
            Expr::Con(n, _) => self.tags.get(n).copied().unwrap_or(0),
            _ => 0,
        };
        let mut binds = Vec::new();
        let ep = self.val(args[1], &mut binds);
        binds.push((
            self.fresh(),
            Self::rt(
                "axion_sess_send",
                vec![Self::sched_atom(), ep.clone(), Atom::Int(label_tag)],
                false,
            ),
        ));
        let mut pv = Vec::new();
        pat_vars(pat, &mut pv);
        if let Some(c) = pv.first() {
            binds.push((c.clone(), Rhs::Op(Op::Atom(ep))));
        }
        wrap(binds, self.gen_cont(rest))
    }

    /// `cancel ep; rest` — send the peer the `Closed` label (§7/T5), then continue.
    fn gen_cancel(&mut self, ep_expr: &Expr, rest: &Expr) -> Term {
        let closed = self.tags.get("Closed").copied().unwrap_or(0);
        let mut binds = Vec::new();
        let ep = self.val(ep_expr, &mut binds);
        binds.push((
            self.fresh(),
            Self::rt(
                "axion_sess_send",
                vec![Self::sched_atom(), ep, Atom::Int(closed)],
                false,
            ),
        ));
        wrap(binds, self.gen_cont(rest))
    }

    /// `_ <- close ep; rest` — a no-op in the cooperative model (consumes ep).
    fn gen_close(&mut self, pat: &Pat, rest: &Expr) -> Term {
        let mut binds = Vec::new();
        let mut pv = Vec::new();
        pat_vars(pat, &mut pv);
        if let Some(x) = pv.first() {
            binds.push((x.clone(), Rhs::Op(Op::Atom(Atom::Int(0)))));
        }
        wrap(binds, self.gen_cont(rest))
    }

    /// Builds the full step function body: resume dispatch → regions, with the
    /// task's parameters loaded from the state block up front.
    fn build_step(&mut self, pats: &[Pat], body: &Expr) -> Term {
        // collect suspensions (recv/offer) in DFS order, with their live-in vars
        let mut scope: Vec<String> = Vec::new();
        for p in pats {
            pat_vars(p, &mut scope);
        }
        let mut susps: Vec<(&Expr, Vec<String>)> = Vec::new();
        collect_suspensions(body, &mut scope, &mut susps);
        self.susp = susps
            .iter()
            .enumerate()
            .map(|(i, (e, _))| (susp_key(e), i as i32))
            .collect();
        self.susp_live = susps.iter().map(|(_, l)| l.clone()).collect();

        let nsusp = susps.len();
        // resume==0 → fresh entry; resume==k → re-enter suspension #(k-1)
        let mut chain = self.region(nsusp, &susps, body);
        for rv in (0..nsusp).rev() {
            let then_t = self.region(rv, &susps, body);
            let eq = self.fresh();
            chain = Term::Let(
                eq.clone(),
                Rhs::Op(Op::Prim(
                    "==".into(),
                    Atom::Var("sess$resume".into()),
                    Atom::Int(rv as i64),
                )),
                Box::new(Term::Ret(Rhs::If(
                    Atom::Var(eq),
                    Box::new(then_t),
                    Box::new(chain),
                ))),
            );
        }
        let dispatch = Term::Let(
            "sess$resume".into(),
            Rhs::Op(Op::LoadRaw(Self::state_atom(), 8)),
            Box::new(chain),
        );
        // load the task's parameters from the state block (the spawner stored them)
        let mut param_loads = Vec::new();
        let mut params = Vec::new();
        for p in pats {
            pat_vars(p, &mut params);
        }
        for v in params {
            param_loads.push((
                v.clone(),
                Rhs::Op(Op::LoadRaw(Self::state_atom(), self.lay.slot[&v])),
            ));
        }
        wrap(param_loads, dispatch)
    }

    /// The region for a resume value: `0` = fresh entry at the body root;
    /// `k>=1` = re-enter suspension #(k-1), loading its live-in locals.
    fn region(&mut self, rv: usize, susps: &[(&Expr, Vec<String>)], body: &Expr) -> Term {
        if rv == 0 {
            return self.gen_cont(body);
        }
        let (case_e, live) = &susps[rv - 1];
        let case_e = *case_e;
        let live = live.clone();
        let mut binds = Vec::new();
        for v in &live {
            binds.push((
                v.clone(),
                Rhs::Op(Op::LoadRaw(Self::state_atom(), self.lay.slot[v])),
            ));
        }
        wrap(binds, self.gen_cont(case_e))
    }
}

/// If `main = bound $ do …`, returns the native session CoreFns: one `step` per
/// task (`main$step`, `<worker>$step`, …) plus the driver `main`. Empty otherwise.
fn sess_clause_body(f: &ast::Func) -> Option<&Expr> {
    match f.clauses.first().map(|c| &c.body) {
        Some(Body::Plain(e)) => Some(e),
        _ => None,
    }
}

fn session_fns(module: &ast::Module, native_fns: &HashSet<String>) -> Vec<CoreFn> {
    let clause_body = sess_clause_body;
    let main = module.funcs.iter().find(|f| f.name == "main");
    let Some(bound_body) = main.and_then(clause_body).and_then(as_bound) else {
        return Vec::new();
    };
    // choice labels (data constructors) → tag = position in their `data` decl
    let mut tags: HashMap<String, i64> = HashMap::new();
    for d in &module.datas {
        for (i, c) in d.cons.iter().enumerate() {
            tags.insert(c.name.clone(), i as i64);
        }
    }
    // collect spawn targets transitively
    let mut workers: Vec<&ast::Func> = Vec::new();
    let mut seen = HashSet::new();
    let mut worklist = Vec::new();
    spawn_targets(bound_body, &mut worklist);
    while let Some(name) = worklist.pop() {
        if !seen.insert(name.clone()) {
            continue;
        }
        if let Some(wf) = module.funcs.iter().find(|f| f.name == name) {
            workers.push(wf);
            if let Some(b) = clause_body(wf) {
                spawn_targets(b, &mut worklist);
            }
        }
    }
    // layouts (needed by `spawn` to fill in a child's params)
    let mut layouts: HashMap<String, SessLayout> = HashMap::new();
    layouts.insert(
        "main".into(),
        sess_layout(&[], bound_body, "main$step".into()),
    );
    for wf in &workers {
        let pats = &wf.clauses[0].pats;
        layouts.insert(
            wf.name.clone(),
            sess_layout(pats, clause_body(wf).unwrap(), format!("{}$step", wf.name)),
        );
    }

    let mut out = Vec::new();
    // one step function per task
    let step_of = |name: &str, pats: &[Pat], body: &Expr, layouts: &HashMap<String, SessLayout>| {
        let lay = &layouts[name];
        let mut g = SessGen {
            name,
            lay,
            all: layouts,
            tags: &tags,
            fns: native_fns,
            susp: HashMap::new(),
            susp_live: Vec::new(),
            tmp: 0,
        };
        CoreFn {
            name: lay.step.clone(),
            params: vec![SESS_SCHED.into(), SESS_STATE.into()],
            captures: Vec::new(),
            is_closure: false,
            owned_params: Vec::new(),
            body: g.build_step(pats, body),
        }
    };
    out.push(step_of("main", &[], bound_body, &layouts));
    for wf in &workers {
        out.push(step_of(
            &wf.name,
            &wf.clauses[0].pats,
            clause_body(wf).unwrap(),
            &layouts,
        ));
    }
    // driver `main`: create scheduler, alloc root state, run, return result
    let size = layouts["main"].size;
    let driver = Term::Let(
        "sess$sched".into(),
        SessGen::rt("axion_sess_new", vec![], true),
        Box::new(Term::Let(
            "sess$root".into(),
            SessGen::rt(
                "axion_sess_alloc",
                vec![Atom::Var("sess$sched".into()), Atom::Int(size as i64)],
                true,
            ),
            Box::new(Term::Let(
                "sess$res".into(),
                Rhs::Op(Op::RtCall {
                    func: "axion_sess_run".into(),
                    args: vec![
                        Atom::Var("sess$sched".into()),
                        Atom::Var("sess$fa".into()),
                        Atom::Var("sess$root".into()),
                    ],
                    returns: true,
                }),
                Box::new(Term::Ret(Rhs::Op(Op::Atom(Atom::Var("sess$res".into()))))),
            )),
        )),
    );
    // materialize the step address before the run call
    let driver = Term::Let(
        "sess$fa".into(),
        Rhs::Op(Op::FuncAddr("main$step".into())),
        Box::new(driver),
    );
    out.push(CoreFn {
        name: "main".into(),
        params: Vec::new(),
        captures: Vec::new(),
        is_closure: false,
        owned_params: Vec::new(),
        body: driver,
    });
    out
}

pub fn lower(module: &ast::Module, inplace: &HashSet<Span>) -> Vec<CoreFn> {
    // native session lowering runs on the ORIGINAL AST (before eta-expansion,
    // which would wrap a bare `spawn worker` target into a lambda). It needs the
    // set of native functions (to resolve value-position calls), so it runs after
    // `native_ok` below; keep the pre-eta module here.
    let orig_module = module;
    // Eta-expansion (native path only): rewrites functions/constructors used
    // as a VALUE or applied PARTIALLY (`f`, `compose g h`) into lambdas
    // (`\v -> f v`), which the closure machinery already compiles. It is semantic
    // identity — the interp already handles partial application, so it stays here.
    let module = &eta_expand(module);
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
    // functions whose return is a heap object → the call result becomes
    // the caller's property (reclaimable when it dies and doesn't escape)
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
    // typeclass method names (interp-only): exclude the function from native
    let methods: HashSet<String> = module
        .classes
        .iter()
        .flat_map(|c| c.methods.iter().map(|(m, _)| m.clone()))
        .collect();

    // TRANSITIVE native candidacy: a function is only compilable if, besides passing
    // `top_candidate`, all top-level functions it calls also are (fixpoint). Closes
    // the hole of a candidate calling a NON-candidate (e.g. a monomorphized spec that
    // calls `foldr`, whose result is a pure type var) — which would otherwise break
    // codegen with an unbound symbol. It excludes it gracefully (falls back to the
    // interp) instead of aborting.
    let func_set: HashSet<&str> = module.funcs.iter().map(|f| f.name.as_str()).collect();
    let mut native_ok: HashMap<String, usize> = module
        .funcs
        .iter()
        .filter_map(|f| top_candidate(f, &data_types, &methods).map(|a| (f.name.clone(), a)))
        .collect();
    loop {
        let mut remove = None;
        for f in &module.funcs {
            if !native_ok.contains_key(&f.name) {
                continue;
            }
            let mut refs = HashSet::new();
            body_refs(f, &mut refs);
            if refs
                .iter()
                .any(|g| func_set.contains(g.as_str()) && !native_ok.contains_key(g))
            {
                remove = Some(f.name.clone());
                break;
            }
        }
        match remove {
            Some(n) => {
                native_ok.remove(&n);
            }
            None => break,
        }
    }

    // native session state machines (§11), now that we know which functions are
    // native (callable in value position from a worker's compute).
    let native_fn_names: HashSet<String> = native_ok.keys().cloned().collect();
    let session = session_fns(orig_module, &native_fn_names);

    // pre-pass: names + computes captures of all lambdas (by span)
    let mut lam_meta: LamMeta = HashMap::new();
    let mut lam_ctr = 0u32;
    let mut lam_sites: Vec<(&Expr, HashMap<String, String>)> = Vec::new();
    for f in &module.funcs {
        if !native_ok.contains_key(&f.name) {
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
        let Some(&arity) = native_ok.get(&f.name) else {
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

    // the lifted lambdas (in the order they were numbered)
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

    // parameter multiplicities of top-level functions with a signature, for
    // borrowed-argument reclamation
    let param_mults: HashMap<String, Vec<ast::Mult>> = module
        .funcs
        .iter()
        .filter_map(|f| f.sig.as_ref().map(|s| (f.name.clone(), s.param_mults())))
        .collect();
    let borrow_args = compute_borrow_args(&out, &param_mults);

    // deep-drop (§2): `data` type of each droppable, so the backend reclaims
    // nested fields via a recursive destructor instead of a flat `free`.
    let recinfo = RecordInfo::build(module);
    let fn_ret_ty: HashMap<String, String> = module
        .funcs
        .iter()
        .filter_map(|f| {
            let rt = result_type(f.sig.as_ref()?);
            rt.head_con()
                .filter(|h| data_types.contains(*h))
                .map(|h| (f.name.clone(), h.to_string()))
        })
        .collect();
    let all_dty = build_all_drop_ty(&out, module, &recinfo, &fn_ret_ty);
    let empty = HashMap::new();

    let mut result: Vec<CoreFn> = out
        .into_iter()
        .map(|f| {
            let dty = all_dty.get(&f.name).unwrap_or(&empty);
            insert_drops(f, &heap_ret, &borrow_args, dty)
        })
        .collect();
    // generated destructors: added AFTER drop insertion (they manage
    // memory by hand, they don't go through the reclamation analysis)
    result.extend(gen_destructors(&recinfo));
    // native session state machines (§11): also hand-managed (task states live in
    // the scheduler's nursery arena), so they bypass the drop analysis too.
    result.extend(session);
    result
}

/// Generates the recursive destructors `axion_drop_<T>` for each type with
/// heap (deep-drop, §2): frees the owned `data`-typed fields (via their
/// destructor, or `free` if they are leaves) and then the block itself;
/// sum types dispatch on the tag.
fn gen_destructors(recinfo: &RecordInfo) -> Vec<CoreFn> {
    let mut out = Vec::new();
    for ty in recinfo.deep_drop_types() {
        let p = "_p".to_string();
        let mut ctr = 0u32;
        let free_ret = free_then_ret(&p);
        let cons: Vec<String> = recinfo.type_cons(&ty).unwrap_or(&[]).to_vec();
        let body = if cons.len() <= 1 {
            match cons.first() {
                Some(con) => drop_con_fields(recinfo, con, &p, &mut ctr, free_ret),
                None => free_ret,
            }
        } else {
            // multi-con: loads the tag and one independent `if` per constructor with
            // fields; only the matching tag fires at runtime.
            let mut chain = free_ret;
            for con in cons.iter().rev() {
                if recinfo.drop_slots(con).is_empty() {
                    continue;
                }
                let tag = recinfo.tag(con).unwrap_or(0) as i64;
                let branch = drop_con_fields(recinfo, con, &p, &mut ctr, unit0());
                let cmp = fresh_dd(&mut ctr);
                let ifstep = Term::Let(
                    fresh_dd(&mut ctr),
                    Rhs::If(Atom::Var(cmp.clone()), Box::new(branch), Box::new(unit0())),
                    Box::new(chain),
                );
                chain = Term::Let(
                    cmp,
                    Rhs::Op(Op::Prim(
                        "==".into(),
                        Atom::Var("_tag".into()),
                        Atom::Int(tag),
                    )),
                    Box::new(ifstep),
                );
            }
            Term::Let(
                "_tag".into(),
                Rhs::Op(Op::LoadRaw(Atom::Var(p.clone()), 0)),
                Box::new(chain),
            )
        };
        out.push(CoreFn {
            name: format!("axion_drop_{ty}"),
            params: vec![p],
            captures: Vec::new(),
            is_closure: false,
            owned_params: Vec::new(),
            body,
        });
    }
    out
}

fn fresh_dd(ctr: &mut u32) -> String {
    let n = format!("_dd{ctr}");
    *ctr += 1;
    n
}

fn unit0() -> Term {
    Term::Ret(Rhs::Op(Op::Atom(Atom::Int(0))))
}

fn free_then_ret(p: &str) -> Term {
    Term::Let(
        "_dfree".into(),
        Rhs::Op(Op::RtCall {
            func: "axion_free".into(),
            args: vec![Atom::Var(p.to_string())],
            returns: false,
        }),
        Box::new(unit0()),
    )
}

/// Frees the `data`-typed fields owned by `con` (loaded by offset one at
/// partir de `p`), antes de `cont`.
fn drop_con_fields(recinfo: &RecordInfo, con: &str, p: &str, ctr: &mut u32, cont: Term) -> Term {
    let mut term = cont;
    for (off, f) in recinfo.drop_slots(con).iter().rev() {
        let fp = fresh_dd(ctr);
        let dropcall = if recinfo.needs_deep_drop(f) {
            Op::CallDirect(format!("axion_drop_{f}"), vec![Atom::Var(fp.clone())])
        } else {
            Op::RtCall {
                func: "axion_free".into(),
                args: vec![Atom::Var(fp.clone())],
                returns: false,
            }
        };
        term = Term::Let(
            fp.clone(),
            Rhs::Op(Op::LoadRaw(Atom::Var(p.to_string()), *off)),
            Box::new(Term::Let(fresh_dd(ctr), Rhs::Op(dropcall), Box::new(term))),
        );
    }
    term
}

/// For each function, the `data` type of each droppable (owned `%1` parameters +
/// results of `Make*`/calls that return heap). Feeds the deep-drop.
fn build_all_drop_ty(
    fns: &[CoreFn],
    module: &ast::Module,
    recinfo: &RecordInfo,
    fn_ret_ty: &HashMap<String, String>,
) -> HashMap<String, HashMap<String, Option<String>>> {
    let mut out = HashMap::new();
    for f in fns {
        let mut dty: HashMap<String, Option<String>> = HashMap::new();
        // owned `%1` parameters → type from the top-level function signature
        if let Some(mf) = module.funcs.iter().find(|m| m.name == f.name) {
            if let Some(sig) = &mf.sig {
                let ptys = sig.param_types();
                for owned in &f.owned_params {
                    let idx = f.params.iter().position(|p| p == owned);
                    let ty = idx
                        .and_then(|i| ptys.get(i))
                        .and_then(|t| t.head_con())
                        .filter(|h| recinfo.type_cons(h).is_some());
                    if let Some(h) = ty {
                        dty.insert(owned.clone(), Some(h.to_string()));
                    }
                }
            }
        }
        collect_drop_types(&f.body, recinfo, fn_ret_ty, &mut dty);
        out.insert(f.name.clone(), dty);
    }
    out
}

/// Records the `data` type of variables bound to `Make*`/heap-calls in `t`.
/// (Results of `if`/`case` bound to `let` are not typed — they get a flat
/// `free`; conservative, safe — see docs/backend.md.)
fn collect_drop_types(
    t: &Term,
    recinfo: &RecordInfo,
    fn_ret_ty: &HashMap<String, String>,
    out: &mut HashMap<String, Option<String>>,
) {
    match t {
        Term::Let(x, rhs, body) => {
            if let Rhs::Op(op) = rhs {
                let ty = match op {
                    Op::MakeRecord { con, .. } | Op::MakeCon { con, .. } => {
                        recinfo.con_type(con).map(str::to_string)
                    }
                    Op::CallDirect(g, _) => fn_ret_ty.get(g).cloned(),
                    _ => None,
                };
                if ty.is_some() {
                    out.insert(x.clone(), ty);
                }
            }
            collect_rhs_drop_types(rhs, recinfo, fn_ret_ty, out);
            collect_drop_types(body, recinfo, fn_ret_ty, out);
        }
        Term::Drop(_, _, body) => collect_drop_types(body, recinfo, fn_ret_ty, out),
        Term::Ret(rhs) => collect_rhs_drop_types(rhs, recinfo, fn_ret_ty, out),
    }
}

fn collect_rhs_drop_types(
    rhs: &Rhs,
    recinfo: &RecordInfo,
    fn_ret_ty: &HashMap<String, String>,
    out: &mut HashMap<String, Option<String>>,
) {
    match rhs {
        Rhs::Op(_) => {}
        Rhs::If(_, th, el) => {
            collect_drop_types(th, recinfo, fn_ret_ty, out);
            collect_drop_types(el, recinfo, fn_ret_ty, out);
        }
        Rhs::Case(_, arms) => {
            for (_, b) in arms {
                collect_drop_types(b, recinfo, fn_ret_ty, out);
            }
        }
    }
}

// --- reclamation analysis: structural Drop (Auto-Drop §2) ---
//
// Inserts `drop` nodes into the Core that free **local** heap objects at their
// death point. An object is *droppable* if it is allocated in the function (via
// `Make{Tuple,Record,Closure}` or `UpdateRecord`) and **never escapes**: it is never
// returned, embedded in another object, passed to a call, nor aliased. As
// its occurrences are then all local reads (`Field`, `case`
// scrutinee), so freeing it after the last read is sound (the linear discipline
// guarantees no aliasing; the object is not reachable by anyone). The
// cases that escape or change owner are left unfreed (conservative — safe),
// like cross-function reclamation and arena reset (later
// seguintes).

/// Borrowed-argument reclamation (§2): map function-name → indices of
/// parameters that are *pure borrows* — `Many` parameters (the caller retains
/// ownership) that the body **only reads locally** (`Field.rec`/`case` scrutinee),
/// nunca os devolvendo, embebendo, aliasing nem passando adiante. Como o callee
/// doesn't retain them, the caller can free the argument **after** the call, instead
/// of giving it up as lost. Conservative: a parameter passed to *any* call
/// (even if that one also borrows it) counts as an escape (no fixpoint between
/// functions); and the multiplicity is only known for top-level functions with a signature.
type BorrowArgs = HashMap<String, HashSet<usize>>;

fn atom_is(v: &str, a: &Atom) -> bool {
    matches!(a, Atom::Var(n) if n == v)
}

/// `true` if `v` appears in some position that is **not** a local read inside
/// of `t` — i.e. it escapes the callee (returned, embedded, aliased, or passed to
/// a call). A `Many` parameter for which this is `false` is a pure borrow.
fn occurs_nonborrow(v: &str, t: &Term) -> bool {
    match t {
        Term::Let(_, rhs, body) => rhs_nonborrow(v, rhs) || occurs_nonborrow(v, body),
        Term::Drop(_, _, body) => occurs_nonborrow(v, body),
        Term::Ret(rhs) => rhs_nonborrow(v, rhs),
    }
}

fn rhs_nonborrow(v: &str, rhs: &Rhs) -> bool {
    match rhs {
        Rhs::Op(op) => op_nonborrow(v, op),
        // `if` condition / `case` scrutinee are local reads (borrow)
        Rhs::If(_, t, e) => occurs_nonborrow(v, t) || occurs_nonborrow(v, e),
        Rhs::Case(_, arms) => arms.iter().any(|(_, b)| occurs_nonborrow(v, b)),
    }
}

fn op_nonborrow(v: &str, op: &Op) -> bool {
    match op {
        Op::Field { .. } => false,    // reading a field is a borrow
        Op::Atom(a) => atom_is(v, a), // alias/return
        Op::FuncAddr(_) => false,
        Op::StoreRaw(ptr, _, val) => atom_is(v, ptr) || atom_is(v, val),
        Op::Prim(_, a, b) | Op::PrimF(_, a, b) => atom_is(v, a) || atom_is(v, b),
        Op::CallDirect(_, xs) | Op::CallClosure(_, xs) => xs.iter().any(|a| atom_is(v, a)),
        Op::MakeTuple(xs) | Op::MakeCon { args: xs, .. } => xs.iter().any(|a| atom_is(v, a)),
        Op::MakeRecord { fields, .. } => fields.iter().any(|(_, a)| atom_is(v, a)),
        Op::UpdateRecord {
            base,
            fields,
            inplace,
        } => {
            // by-copy update reads the base (borrow) and allocates a new record with
            // copies of the fields; in-place mutates the base and returns it (escape). Copying
            // a linear field would be rejected by linearity, so the fields
            // copied ones are non-linear (safe aliasing, no double-free).
            (*inplace && atom_is(v, base)) || fields.iter().any(|(_, a)| atom_is(v, a))
        }
        Op::MakeClosure { captures, .. } => captures.iter().any(|a| atom_is(v, a)),
        Op::WithArena { parent, clos } => parent.iter().any(|a| atom_is(v, a)) || atom_is(v, clos),
        Op::ArenaAlloc(a) | Op::ArenaMark(a) | Op::ArenaRelease(a) => atom_is(v, a),
        Op::Promote(t, c) => atom_is(v, t) || atom_is(v, c),
        Op::RtCall { args, .. } | Op::Ffi { args, .. } => args.iter().any(|a| atom_is(v, a)),
        Op::PutStrLn(a) | Op::PutStr(a) | Op::ShowInt(a) => atom_is(v, a),
        Op::IntToFloat(a) | Op::FloatToInt(a) | Op::FloatUnary(_, a) => atom_is(v, a),
        // only in generated destructors (not analyzed) — a read, like `Field`
        Op::LoadRaw(..) => false,
        Op::Unsupported(_) => false,
    }
}

/// Computes the pure borrows of each top-level function (those with a signature,
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
            // borrowed (not `%1` → the caller retains ownership) and only read locally
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

/// Use of an atom, if it is a **free** droppable variable (not bound by a
/// `let` within the term being analyzed). Excluding the locally-bound ones is essential
/// for branch balancing: a droppable bound inside a branch is local to
/// that branch and cannot be freed in the sibling branch (where it doesn't exist).
fn atom_use(a: &Atom, drp: &HashSet<String>, bound: &HashSet<String>, out: &mut HashSet<String>) {
    if let Atom::Var(n) = a {
        if drp.contains(n) && !bound.contains(n) {
            out.insert(n.clone());
        }
    }
}

/// **Free** droppable variables read in `t` (heap read positions:
/// `Field.rec`, `case` scrutinee, borrowed args, `withArena` closure).
fn fv_drop(t: &Term, drp: &HashSet<String>, ba: &BorrowArgs, out: &mut HashSet<String>) {
    fv_drop_in(t, drp, ba, &mut HashSet::new(), out);
}

fn fv_op(op: &Op, drp: &HashSet<String>, ba: &BorrowArgs, out: &mut HashSet<String>) {
    fv_op_in(op, drp, ba, &HashSet::new(), out);
}

fn fv_drop_in(
    t: &Term,
    drp: &HashSet<String>,
    ba: &BorrowArgs,
    bound: &mut HashSet<String>,
    out: &mut HashSet<String>,
) {
    match t {
        Term::Let(x, rhs, body) => {
            fv_rhs_in(rhs, drp, ba, bound, out);
            // `x` is bound in the body — its mentions there are not free
            let fresh = bound.insert(x.clone());
            fv_drop_in(body, drp, ba, bound, out);
            if fresh {
                bound.remove(x);
            }
        }
        Term::Drop(_, _, body) => fv_drop_in(body, drp, ba, bound, out),
        Term::Ret(rhs) => fv_rhs_in(rhs, drp, ba, bound, out),
    }
}

fn fv_rhs_in(
    rhs: &Rhs,
    drp: &HashSet<String>,
    ba: &BorrowArgs,
    bound: &mut HashSet<String>,
    out: &mut HashSet<String>,
) {
    match rhs {
        Rhs::Op(op) => fv_op_in(op, drp, ba, bound, out),
        Rhs::If(c, t, e) => {
            atom_use(c, drp, bound, out);
            fv_drop_in(t, drp, ba, bound, out);
            fv_drop_in(e, drp, ba, bound, out);
        }
        Rhs::Case(s, arms) => {
            atom_use(s, drp, bound, out);
            for (_, b) in arms {
                fv_drop_in(b, drp, ba, bound, out);
            }
        }
    }
}

fn fv_op_in(
    op: &Op,
    drp: &HashSet<String>,
    ba: &BorrowArgs,
    bound: &HashSet<String>,
    out: &mut HashSet<String>,
) {
    // `Field` reads a droppable (the record). A direct call to a function with
    // pure-borrow parameters **also** counts as a use of the argument (it's
    // freed after the call, not before). The remaining args escape (they move
    // to the callee) → the droppable doesn't appear there. Prim operates on Ints.
    match op {
        Op::Field { rec, .. } => atom_use(rec, drp, bound, out),
        // the closure passed to `withArena` is used during the call and dies
        // follow → counts as a use so the drop falls AFTER (like a borrowed arg)
        Op::WithArena { clos, .. } => atom_use(clos, drp, bound, out),
        Op::CallDirect(g, xs) => {
            if let Some(bs) = ba.get(g) {
                for (i, a) in xs.iter().enumerate() {
                    if bs.contains(&i) {
                        atom_use(a, drp, bound, out);
                    }
                }
            }
        }
        _ => {}
    }
}

/// The droppable set of a function: objects it **owns** — allocated
/// locally (`Make*`), results of calls that return heap (`heap_ret`),
/// and its `%1` heap parameters — minus those that escape.
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
                    // local allocation, or result of a call that returns heap
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
        Term::Drop(_, _, body) => scan_body(body, heap_ret, ba, alloc, esc),
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

/// A direct call to a function that returns heap → the result is the caller's.
fn returns_owned_heap(op: &Op, heap_ret: &HashSet<String>) -> bool {
    matches!(op, Op::CallDirect(name, _) if heap_ret.contains(name))
}

fn is_heap_alloc(op: &Op) -> bool {
    matches!(
        op,
        Op::MakeTuple(_)
            | Op::MakeRecord { .. }
            | Op::MakeCon { .. }
            | Op::UpdateRecord { .. }
            | Op::MakeClosure { .. }
    )
}

/// Names of variables that escape by appearing in an owner position
/// (argumento de chamada, embebimento noutro objecto, alias directo).
fn scan_op_escapes(op: &Op, ba: &BorrowArgs, esc: &mut HashSet<String>) {
    let mut mark = |a: &Atom| {
        if let Atom::Var(n) = a {
            esc.insert(n.clone());
        }
    };
    match op {
        Op::Atom(a) => mark(a), // alias directo `let y = x`
        // a direct call moves the arguments into the callee — except those that
        // it only borrows (pure borrow), which the caller retains and frees
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
        // arenas: their objects (arena/cell/closure) are managed by the arena
        // reset, not by Auto-Drop — they are marked as escape to ignore them.
        // the arena/parent are managed by the reset; the closure, however, is a heap
        // normal heap that `withArena` only *borrows* (calls it and returns) —
        // doesn't escape, is reclaimable after the call (see `fv_op`).
        Op::WithArena { parent, .. } => parent.iter().for_each(&mut mark),
        Op::ArenaAlloc(a) | Op::ArenaMark(a) | Op::ArenaRelease(a) => mark(a),
        Op::Promote(t, c) => {
            mark(t);
            mark(c);
        }
        Op::RtCall { args, .. } | Op::Ffi { args, .. } => args.iter().for_each(&mut mark),
        _ => {}
    }
    // the receiving closure of an indirect call also changes hands
    if let Op::CallClosure(c, _) = op {
        mark(c);
    }
}

fn scan_op_escapes_ret(op: &Op, ba: &BorrowArgs, esc: &mut HashSet<String>) {
    scan_op_escapes(op, ba, esc);
    // the returned value escapes
    if let Op::Atom(Atom::Var(n)) = op {
        esc.insert(n.clone());
    }
}

/// Inserts the `drop`s into a function (structural Drop + cross-function reclamation).
/// `drop_ty` maps each droppable to its `data`-type name (for the deep-drop).
fn insert_drops(
    mut f: CoreFn,
    heap_ret: &HashSet<String>,
    ba: &BorrowArgs,
    drop_ty: &HashMap<String, Option<String>>,
) -> CoreFn {
    let drp = droppable_vars(&f, heap_ret, ba);
    if drp.is_empty() {
        return f;
    }
    let mut e = Elab {
        drp,
        tmp: 1_000_000,
        ba,
        drop_ty,
    };
    let body = std::mem::replace(&mut f.body, Term::Ret(Rhs::Op(Op::Atom(Atom::Int(0)))));
    f.body = e.go(body, &HashSet::new());
    f
}

struct Elab<'a> {
    drp: HashSet<String>,
    tmp: u32,
    ba: &'a BorrowArgs,
    drop_ty: &'a HashMap<String, Option<String>>,
}

impl Elab<'_> {
    fn fresh(&mut self) -> String {
        let n = format!("_d{}", self.tmp);
        self.tmp += 1;
        n
    }

    /// The `data` type name of a droppable (so the backend picks deep-drop
    /// vs. `free` plano), se conhecido.
    fn dty(&self, v: &str) -> Option<String> {
        self.drop_ty.get(v).cloned().flatten()
    }

    /// Elaborates `t`, freeing the droppable variables at their death point.
    /// `live_out` = droppables live *after* `t` (to be freed by the context
    /// enclosing), which `t` must not free.
    fn go(&mut self, t: Term, live_out: &HashSet<String>) -> Term {
        match t {
            Term::Drop(v, ty, body) => {
                let b = self.go(*body, live_out);
                Term::Drop(v, ty, Box::new(b))
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
                    // introduces a temporary, frees the dying ones, returns it
                    let tmp = self.fresh();
                    let mut inner = Term::Ret(Rhs::Op(Op::Atom(Atom::Var(tmp.clone()))));
                    for v in dying {
                        let ty = self.dty(&v);
                        inner = Term::Drop(v, ty, Box::new(inner));
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
                    // `x` freshly allocated and never read → dies immediately
                    if self.drp.contains(&x) && !fvb.contains(&x) && !live_out.contains(&x) {
                        dying.push(x.clone());
                    }
                    let mut inner = body2;
                    for v in dying {
                        let ty = self.dty(&v);
                        inner = Term::Drop(v, ty, Box::new(inner));
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

    /// Elaborates the two branches of an `if`, balancing: a droppable used in only one
    /// branch is freed at the entry of the other (to free once per path).
    fn branches2(&mut self, th: Term, el: Term, live_out: &HashSet<String>) -> (Term, Term) {
        let mut fth = HashSet::new();
        fv_drop(&th, &self.drp, self.ba, &mut fth);
        let mut fel = HashSet::new();
        fv_drop(&el, &self.drp, self.ba, &mut fel);
        let mut th2 = self.go(th, live_out);
        let mut el2 = self.go(el, live_out);
        for v in fth.difference(&fel) {
            if !live_out.contains(v) {
                el2 = Term::Drop(v.clone(), self.dty(v), Box::new(el2));
            }
        }
        for v in fel.difference(&fth) {
            if !live_out.contains(v) {
                th2 = Term::Drop(v.clone(), self.dty(v), Box::new(th2));
            }
        }
        (th2, el2)
    }

    /// Elaborates the arms of a `case`, balancing across arms and freeing the
    /// scrutinee (if droppable and dying) at the head of each arm.
    fn case_arms(
        &mut self,
        scrut: &Atom,
        arms: Vec<(CPat, Term)>,
        live_out: &HashSet<String>,
    ) -> Vec<(CPat, Term)> {
        // free variables of each arm
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
            // cross-arm balancing: droppable used in another arm but not this one
            for v in union.difference(&fvs[i]) {
                if !live_out.contains(v) {
                    b = Term::Drop(v.clone(), self.dty(v), Box::new(b));
                }
            }
            // frees the scrutinee at the head (after destructuring)
            if let Some(s) = &scrut_drop {
                b = Term::Drop(s.clone(), self.dty(s), Box::new(b));
            }
            out.push((pat, b));
        }
        out
    }
}

// --- Core printing (`--emit core`) ---

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
        Term::Drop(v, ty, body) => {
            indent(n, s);
            match ty {
                Some(t) => s.push_str(&format!("drop {v} : {t}\n")),
                None => s.push_str(&format!("drop {v}\n")),
            }
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
        Op::StoreRaw(p, off, val) => format!("store {}[{off}] = {}", atom(p), atom(val)),
        Op::FuncAddr(n) => format!("&{n}"),
        Op::Prim(o, a, b) | Op::PrimF(o, a, b) => format!("{o} {} {}", atom(a), atom(b)),
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
        Op::LoadRaw(a, off) => format!("loadraw {}+{off}", atom(a)),
        Op::PutStrLn(a) => format!("putStrLn {}", atom(a)),
        Op::PutStr(a) => format!("putStr {}", atom(a)),
        Op::ShowInt(a) => format!("showInt {}", atom(a)),
        Op::IntToFloat(a) => format!("toFloat {}", atom(a)),
        Op::FloatToInt(a) => format!("truncate {}", atom(a)),
        Op::FloatUnary(o, a) => format!("{o} {}", atom(a)),
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
        Atom::Float(f) => format!("{f}f"),
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
