#![allow(clippy::pedantic)]
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
    /// `ty` (Phase A′): the `data`-type name of the result for deep-drop routing,
    /// read off the callee's signature at lowering (None when unknown/non-boxed).
    CallDirect(String, Vec<Atom>, Option<String>),
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
        /// Phase A′: the `data`-type name of the value (deep-drop routing), read
        /// off the constructor's declaration at lowering.
        ty: Option<String>,
    },
    /// build a positional `data` value `Con a b …` (sum types included —
    /// carries the tag if the type has >1 constructor).
    MakeCon {
        con: String,
        args: Vec<Atom>,
        /// Phase A′: the `data`-type name of the value (deep-drop routing), read
        /// off the constructor's declaration at lowering.
        ty: Option<String>,
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
    /// Allocate a packed array of n elements, each initialised to init.
    /// `elem_ty` is the mangled monomorphic element-type key for deep-drop
    /// routing (`None` = primitive/unknown → generic destructor).
    ArrayNew {
        len: Atom,
        init: Atom,
        elem_ty: Option<String>,
    },
}

/// Lado direito de um `let` (ou o resultado): folha ou controlo.
#[derive(Debug, Clone)]
pub enum Rhs {
    Op(Op),
    If(Atom, Box<Term>, Box<Term>),
    Case(Atom, Vec<(CPat, Term)>),
}

/// The marker for Core nodes with no source location (generated code: the
/// destructors, the session state machines, the `Elab` temporaries).
pub const NO_SPAN: Span = (0, 0);

/// The span of a Core node — `NO_SPAN` for generated code.
pub fn term_span(t: &Term) -> Span {
    match t {
        Term::Let(_, _, sp, _) | Term::Drop(_, _, _, sp, _) | Term::Ret(_, sp) => *sp,
    }
}

/// A sequence of `let`s ending in a result.
///
/// Every node carries the source `Span` of the AST expression it was lowered
/// from (Δ-5): `NO_SPAN` for generated code. A `Drop` inserted by the
/// reclamation analysis inherits the span of the node it precedes — the
/// position-level coherence cross-check (Δ-3, move 2 + Δ-5) matches those
/// anchors against the front-end's `DropPoint` spans.
#[derive(Debug, Clone)]
pub enum Term {
    Let(String, Rhs, Span, Box<Term>),
    /// `drop x; …` — frees the heap object `x` at its death point
    /// (Auto-Drop, §2; inserted by the reclamation analysis, not the lowering).
    /// The `Option<String>` is the `data` type name of `x` (when known): if the
    /// type owns heap fields, the backend calls the recursive destructor
    /// `axion_drop_<T>` (deep-drop); otherwise, a flat `free`.
    /// The `Vec<usize>` is the **remainder skip set** (per-field ownership,
    /// docs/per-field-ownership.md §3): a `deep` drop whose destructor PROVABLY
    /// does not free the listed slot indices — the `%1` fields that were moved
    /// out of `x` before the drop (`drop x : T skip {0}` frees the shell and
    /// every heap slot except slot 0, which left). `F-1` (checker-only) leaves
    /// lowering always emitting the empty set — the `(Drop·skip)` judgment rule
    /// is added first and unit-tested; lowering fills it in `F-2`.
    Drop(String, Option<String>, Vec<usize>, Span, Box<Term>),
    Ret(Rhs, Span),
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
    /// Phase A′: drop-type key of each owned `%1` param (mangled destructor key,
    /// `List$P`), resolved at lowering — the drop-type walk reads it instead of
    /// re-reading the signature. `None` = unknown → flat `free` (conservative).
    pub owned_drop_ty: Vec<(String, Option<String>)>,
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
    // tuples are heap pointers (allocated i64[] → i64)
    if matches!(t, Type::Tuple(_)) {
        return true;
    }
    match t.head_con() {
        // Int/Float/String/IO; arena (Arena/Cell/Mark); Buffer (§4); Array (§A);
        // unit-token; fixed-width integers (§4) — i64 in the ABI (Float as its f64
        // bit pattern; Buffer/Array/arena as heap pointers). `Array` threaded through
        // helpers is reclaimed by the uniquify pass + the fixpoint borrow analysis
        // (`compute_borrow_args`) + the array read-op borrow spec (`body_moves`).
        Some(
            "Int" | "Float" | "Bool" | "String" | "IO" | "Arena" | "Cell" | "Mark" | "Buffer"
            | "Array" | "()" | "U8" | "U16" | "U32" | "U64" | "I8" | "I16" | "I32" | "I64" | "Word"
            | "Byte",
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

/// `true` if `f` calls **itself** in tail position (the last thing it does on some
/// path). Such a function is compiled as a loop (TCO) — no call/return overhead
/// per iteration, no stack growth — by the backends and the interpreter. Axion has
/// no surface loops, so tail recursion → loop is a natural lowering, not an
/// optimization pass.
pub fn has_tail_self_call(f: &CoreFn) -> bool {
    fn term(t: &Term, name: &str) -> bool {
        match t {
            Term::Let(_, _, _, body) | Term::Drop(_, _, _, _, body) => term(body, name),
            Term::Ret(rhs, _) => rhs_tail(rhs, name),
        }
    }
    fn rhs_tail(rhs: &Rhs, name: &str) -> bool {
        match rhs {
            Rhs::Op(Op::CallDirect(g, _, _)) => g == name,
            Rhs::If(_, t, e) => term(t, name) || term(e, name),
            Rhs::Case(_, arms) => arms.iter().any(|(_, b)| term(b, name)),
            Rhs::Op(_) => false,
        }
    }
    term(&f.body, &f.name)
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

/// `true` if every constructor of `d` is nullary (a C-like enum). Such a type is
/// **unboxed**: its values are immediate tags (the constructor index), never heap
/// pointers — so they cost no allocation and are never `drop`ped.
pub fn is_enum_data(d: &ast::DataDecl) -> bool {
    d.cons.iter().all(|c| c.fields.is_empty())
}

/// Data types that are actually **heap-allocated** (at least one constructor with
/// fields). Excludes unboxed enums — used for every heap/drop decision.
pub fn boxed_data_names(module: &ast::Module) -> HashSet<String> {
    module
        .datas
        .iter()
        .filter(|d| !is_enum_data(d))
        .map(|d| d.name.clone())
        .collect()
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
    /// unboxed enum types (all constructors nullary): values are immediate tags.
    enum_types: HashSet<String>,
    /// mixed sum types (some nullary, some with fields): nullary constructors are
    /// tagged immediates `(idx<<1)|1`, others are heap pointers (low bit 0).
    mixed_types: HashSet<String>,
    /// constructor → field indices whose declared type is a bare type variable
    /// (`a` in `Cons a (List a)`). Under a heap instantiation these fields hold
    /// heap payloads a generic destructor cannot see, so when such a field is
    /// EXTRACTED and escapes, the scrutinee must be freed shallowly (as with a
    /// concrete heap field) to avoid double-freeing the escaped payload.
    con_poly_fields: HashMap<String, HashSet<usize>>,
    /// constructor → field indices declared `%1` (linear — per-field ownership,
    /// docs/per-field-ownership.md): each such slot owns its own linear resource,
    /// so a remainder drop may skip the moved-out ones (`Term::Drop` skip set).
    con_owned_fields: HashMap<String, HashSet<usize>>,
}

impl RecordInfo {
    pub fn build(module: &ast::Module) -> RecordInfo {
        let mut r = RecordInfo::default();
        // heap fields exclude unboxed enums (immediate tags, not allocations).
        let data_names = boxed_data_names(module);
        for d in &module.datas {
            if is_enum_data(d) {
                r.enum_types.insert(d.name.clone());
            } else if d.cons.iter().any(|c| c.fields.is_empty()) {
                // has both nullary and field-carrying constructors → mixed.
                r.mixed_types.insert(d.name.clone());
            }
        }
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
                let mut poly = HashSet::new();
                let mut owned = HashSet::new();
                for (i, f) in c.fields.iter().enumerate() {
                    // a `data`-typed field is a heap allocation owned by the
                    // record → must be reclaimed when the parent dies. Tuples and
                    // non-heap (Int/String/Buffer/function) are left out (see docs).
                    if let Some(h) = f.ty.head_con() {
                        if data_names.contains(h) {
                            slots.push((r.field_offset(&c.name, i), h.to_string()));
                        }
                    } else if matches!(f.ty, Type::Var(_)) {
                        // a bare type variable: possibly-heap once instantiated.
                        poly.insert(i);
                    }
                    if f.mult == ast::Mult::One {
                        owned.insert(i);
                    }
                }
                if !slots.is_empty() {
                    r.needs_deep.insert(d.name.clone());
                }
                r.con_drop_slots.insert(c.name.clone(), slots);
                if !poly.is_empty() {
                    r.con_poly_fields.insert(c.name.clone(), poly);
                }
                if !owned.is_empty() {
                    r.con_owned_fields.insert(c.name.clone(), owned);
                }
            }
        }
        r
    }

    /// `true` if the type (name) owns heap fields → needs a recursive
    /// destructor instead of a flat `free`.
    pub fn needs_deep_drop(&self, ty: &str) -> bool {
        self.needs_deep.contains(ty)
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

    /// `true` if the constructor's type is an unboxed enum (all nullary): its
    /// values are immediate tags (the constructor index), not heap pointers.
    pub fn is_enum_con(&self, con: &str) -> bool {
        self.con_type
            .get(con)
            .is_some_and(|t| self.enum_types.contains(t))
    }

    pub fn is_enum_type(&self, ty: &str) -> bool {
        self.enum_types.contains(ty)
    }

    /// The constructor index within its type (its immediate value when unboxed).
    pub fn con_index(&self, con: &str) -> i32 {
        self.con_tag.get(con).copied().unwrap_or(0)
    }

    /// `true` if the constructor's type is a **mixed** sum (some nullary, some
    /// with fields): nullary values are tagged immediates, others are pointers.
    pub fn is_mixed_con(&self, con: &str) -> bool {
        self.con_type
            .get(con)
            .is_some_and(|t| self.mixed_types.contains(t))
    }

    /// `true` if `con` is a nullary constructor of a mixed type — its value is the
    /// tagged immediate `(index<<1)|1` (distinguishable from a heap pointer).
    pub fn is_tagged_nullary(&self, con: &str) -> bool {
        self.is_mixed_con(con) && self.con_arity(con) == Some(0)
    }

    /// `true` if the type `ty` is a mixed sum (values may be immediate or pointer).
    pub fn is_mixed_type(&self, ty: &str) -> bool {
        self.mixed_types.contains(ty)
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

    /// `true` if field `i` of `con` is a separately-allocated heap object (a
    /// `data`/tuple the value owns) — i.e. one the deep-drop destructor would free.
    pub fn field_is_heap(&self, con: &str, i: usize) -> bool {
        let off = self.field_offset(con, i);
        self.drop_slots(con).iter().any(|(o, _)| *o == off)
    }

    /// `true` if field `i` of `con` has a bare type-variable type (`a`). Under a
    /// heap instantiation it holds a payload that a specialized (monomorphized)
    /// destructor frees, so — like a concrete heap field — extracting it out of
    /// the scrutinee transfers ownership and forces a shallow scrutinee free.
    pub fn field_is_poly(&self, con: &str, i: usize) -> bool {
        self.con_poly_fields
            .get(con)
            .is_some_and(|s| s.contains(&i))
    }

    /// `true` if extracting field `i` of `con` out of a value transfers HEAP
    /// ownership — a concrete heap field OR a polymorphic one (heap once
    /// instantiated). The single predicate the ownership/aliasing decisions use,
    /// so neither can silently forget the polymorphic case (which would
    /// reintroduce the mono-destructor double-free — docs/polymorphic-drop-plan.md).
    pub fn field_transfers_heap(&self, con: &str, i: usize) -> bool {
        self.field_is_heap(con, i) || self.field_is_poly(con, i)
    }

    /// `true` if field `i` of `con` is declared `%1` — a linear field with its
    /// own resource (per-field ownership, docs/per-field-ownership.md F-1).
    pub fn field_is_owned(&self, con: &str, i: usize) -> bool {
        self.con_owned_fields
            .get(con)
            .is_some_and(|s| s.contains(&i))
    }

    /// The drop slot of field `i` of `con`, if it is a `data`-typed heap field:
    /// `Some((type name))` — the key the deep-drop destructor uses for it.
    pub fn field_drop_slot(&self, con: &str, i: usize) -> Option<&str> {
        let off = self.field_offset(con, i);
        self.drop_slots(con)
            .iter()
            .find(|(o, _)| *o == off)
            .map(|(_, t)| t.as_str())
    }

    /// `Some((con, idx))` for the named field `name` (its owning constructor),
    /// or the field's index — used to resolve an `Op::Field` read to its slot.
    pub fn named_field_slot(&self, name: &str) -> Option<(String, usize)> {
        let con = self.field_owner.get(name)?;
        let fields = self.con_fields.get(con)?;
        let idx = fields.iter().position(|f| f == name)?;
        Some((con.clone(), idx))
    }

    /// Offset (in bytes) of a named field, and the list of its record's fields.
    pub fn field(&self, name: &str) -> Option<(i32, &[String])> {
        let con = self.field_owner.get(name)?;
        let fields = self.con_fields.get(con)?;
        let idx = fields.iter().position(|f| f == name)?;
        Some((self.field_offset(con, idx), fields))
    }

    /// `true` if the named field `name` holds a separately-allocated heap object.
    /// Used to tell a scalar field-read (`a q :: Int`, safe to free the owner
    /// after) from a heap-pointer field-read (`inner q`, which aliases into the
    /// owner and must NOT outlive a deep drop of it).
    pub fn named_field_is_heap(&self, name: &str) -> bool {
        let Some(con) = self.field_owner.get(name) else {
            return false;
        };
        let Some(fields) = self.con_fields.get(con) else {
            return false;
        };
        fields
            .iter()
            .position(|f| f == name)
            .is_some_and(|i| self.field_is_heap(con, i))
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

/// True if the type contains a type variable anywhere.
fn ty_has_var(t: &Type) -> bool {
    match t {
        Type::Var(_) => true,
        Type::App(f, a) => ty_has_var(f) || ty_has_var(a),
        Type::Arrow { from, to, .. } => ty_has_var(from) || ty_has_var(to),
        Type::Tuple(ts) => ts.iter().any(ty_has_var),
        _ => false,
    }
}

/// The name of a Phase B generic-owning TEMPLATE, if `f` is one: an
/// unconstrained function with an owned `%1` parameter of a var-carrying
/// heap-shaped (parametric `data` or tuple) type (`dropList :: List a %1 ->
/// Int`). Such functions cannot compile natively (their param's drop-type key
/// is unresolvable — the lowering flat-frees and leaks payloads); only the
/// monomorphized specializations (`dropList$P`) are natively compilable.
/// Mirrors the owning-generic detection in `infer` (`owned_meta`).
fn owning_generic_var(f: &ast::Func) -> Option<String> {
    if !f.constraints.is_empty() {
        return None;
    }
    let sig = f.sig.as_ref()?;
    let mults = sig.param_mults();
    for (i, p) in sig.param_types().iter().enumerate() {
        if mults.get(i) != Some(&ast::Mult::One) {
            continue;
        }
        // heap-shaped owned params only (bare vars/arrows are i64, not owned)
        let heap_shape = matches!(p, Type::Tuple(_)) || p.head_con().is_some();
        if heap_shape && ty_has_var(p) {
            return Some(f.name.clone());
        }
    }
    None
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

/// Worker names used as a `parMap <worker> <xs>` target anywhere in `e` (the
/// worker must be a bare name — a top-level session function). Mirrors the
/// `find_lams` traversal.
fn parmap_targets(e: &Expr, out: &mut Vec<String>) {
    if let (Some("parMap"), args) = sess_spine(e) {
        if let Some(Expr::Var(n, _)) = args.first().copied() {
            out.push(n.clone());
        }
    }
    match e {
        Expr::App(f, a, _) | Expr::BinOp(_, f, a, _) => {
            parmap_targets(f, out);
            parmap_targets(a, out);
        }
        Expr::If(c, t, el, _) => {
            parmap_targets(c, out);
            parmap_targets(t, out);
            parmap_targets(el, out);
        }
        Expr::Tuple(es, _) => es.iter().for_each(|x| parmap_targets(x, out)),
        Expr::RecordCon(_, fs, _) => fs.iter().for_each(|(_, x)| parmap_targets(x, out)),
        Expr::RecordUpd(b, fs, _) => {
            parmap_targets(b, out);
            fs.iter().for_each(|(_, x)| parmap_targets(x, out));
        }
        Expr::Case(s, arms, _) => {
            parmap_targets(s, out);
            arms.iter().for_each(|(_, body)| parmap_targets(body, out));
        }
        Expr::Let(binds, body, _) => {
            for f in binds {
                for c in &f.clauses {
                    if let Body::Plain(e) = &c.body {
                        parmap_targets(e, out);
                    }
                }
            }
            parmap_targets(body, out);
        }
        Expr::Lam(_, body, _) => parmap_targets(body, out),
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
        "newArray",
        "getArray",
        "setArray",
        "lenArray",
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
    /// Phase A′: constructor → `data`-type name of its value (None for unboxed
    /// enum constructors — immediate tags, never dropped). Attached to `Make*`.
    con_ty: &'a HashMap<String, Option<String>>,
    /// Phase A′: function → `data`-type name of its result (boxed only). Attached
    /// to `CallDirect`.
    fn_ret_ty: &'a HashMap<String, String>,
    locals: HashMap<String, String>,
    tmp: u32,
    /// Phase 4: concrete constructor return types (span → AST type) from inference
    makecon_tys: &'a HashMap<Span, Type>,
    /// data types with type parameters (need mono-key mangling for MakeCon)
    parametric_data: &'a HashSet<String>,
    /// Phase 4 mono-destructor seeds: concrete parametric types found at
    /// MakeCon sites that need specialized destructors.
    mono_seeds: &'a mut Vec<Type>,
    /// Phase 2c: `newArray` call-site types (span → Array element type)
    array_tys: &'a HashMap<Span, Type>,
    /// §9 structured fork-join: worker name → (step-fn name, state size, endpoint
    /// param slot) for every `parMap` target, so a `parMap` call lowers to the
    /// `axion_par_map` runtime driver.
    parmap_workers: &'a HashMap<String, (String, i32, i32)>,
}

impl Lower<'_> {
    fn fresh(&mut self) -> String {
        let n = format!("_t{}", self.tmp);
        self.tmp += 1;
        n
    }

    /// Phase 4: resolves the concrete `MakeCon` type annotation for a
    /// constructor call at the given span.  If the inferred concrete return
    /// type is a parametric instantiation (e.g., `List P`), returns the
    /// mangled mono-key (`List$P`); otherwise returns the type head (e.g.,
    /// `"P"` or `None` for enums). Falls back to the `con_ty` static head
    /// when no inference info is available (prelude/spans not recorded).
    fn makecon_ty(&mut self, con: &str, span: Span) -> Option<String> {
        let head = self.con_ty.get(con)?.clone()?;
        if !self.parametric_data.contains(&head) {
            return Some(head);
        }
        let inferred = self.makecon_tys.get(&span)?;
        let key = mono_key(inferred)?;
        self.mono_seeds.push(inferred.clone());
        Some(key)
    }

    /// Lowers `e` to an atom, pushing intermediate `let`s onto `buf`.
    fn atom(&mut self, e: &Expr, buf: &mut Vec<(String, Rhs, Span)>) -> Atom {
        match e {
            Expr::Int(n, _) => Atom::Int(*n),
            Expr::Float(f, _) => Atom::Float(*f),
            Expr::Str(s, _) => Atom::Str(s.clone()),
            Expr::Var(n, _) => Atom::Var(n.clone()),
            _ => {
                let rhs = self.rhs(e, buf);
                let name = self.fresh();
                buf.push((name.clone(), rhs, e.span()));
                Atom::Var(name)
            }
        }
    }

    /// Baixa `e` a um `Rhs` (folha ou controlo), empilhando `let`s em `buf`.
    fn rhs(&mut self, e: &Expr, buf: &mut Vec<(String, Rhs, Span)>) -> Rhs {
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
                // drags the trivial binds into `buf` and continues in the body.
                // Each bind's `let` carries the span of its own binding expr
                // (Δ-5): the position-level coherence check reads per-statement
                // anchors (a whole-chain span would contain every death point).
                for f in binds {
                    let (sp, rhs) = match f.clauses.as_slice() {
                        [c] if c.pats.is_empty() => match &c.body {
                            Body::Plain(e) => (e.span(), self.rhs(e, buf)),
                            _ => (NO_SPAN, Rhs::Op(Op::Unsupported("let with guards".into()))),
                        },
                        _ => (NO_SPAN, Rhs::Op(Op::Unsupported("non-trivial let".into()))),
                    };
                    buf.push((f.name.clone(), rhs, sp));
                }
                self.rhs(body, buf)
            }
            _ => Rhs::Op(self.op(e, buf)),
        }
    }

    #[allow(clippy::many_single_char_names)]
    /// Lowers `e` to a leaf `Op` (the caller guarantees it is not if/case/let).
    fn op(&mut self, e: &Expr, buf: &mut Vec<(String, Rhs, Span)>) -> Op {
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
            Expr::RecordCon(con, assigns, span) => Op::MakeRecord {
                con: con.clone(),
                fields: assigns
                    .iter()
                    .map(|(f, x)| (f.clone(), self.atom(x, buf)))
                    .collect(),
                ty: self.makecon_ty(con, *span),
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
            Expr::Con(name, span) => match name.as_str() {
                "True" => Op::Atom(Atom::Int(1)),
                "False" => Op::Atom(Atom::Int(0)),
                // nullary constructor (e.g. `Nothing`)
                _ => Op::MakeCon {
                    con: name.clone(),
                    args: Vec::new(),
                    ty: self.makecon_ty(name, *span),
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
    fn app(&mut self, e: &Expr, buf: &mut Vec<(String, Rhs, Span)>) -> Op {
        let (head, args) = spine(e);
        // applied constructor `Con a b …` → positional `data` value
        if let Expr::Con(cname, span) = head {
            let vals = args.iter().map(|a| self.atom(a, buf)).collect();
            return Op::MakeCon {
                con: cname.clone(),
                args: vals,
                ty: self.makecon_ty(cname, *span),
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
            ("free", 1) => return self.rtcall("axion_buf_free", &args, true, buf),
            ("foldBytes", 3) => return self.rtcall("axion_fold_bytes", &args, true, buf),
            // linear dense Array: imperative operations
            ("newArray", 2) => {
                let len = self.atom(args[0], buf);
                let init = self.atom(args[1], buf);
                let elem_ty = self
                    .array_tys
                    .get(&e.span())
                    .and_then(|t| {
                        let (head, a) = ty_head_args(t);
                        if head == Some("Array") {
                            a.first().copied()
                        } else {
                            None
                        }
                    })
                    .and_then(mono_key);
                return Op::ArrayNew { len, init, elem_ty };
            }
            ("getArray", 2) => return self.rtcall("axion_array_get", &args, true, buf),
            ("setArray", 3) => return self.rtcall("axion_array_set", &args, true, buf),
            ("lenArray", 1) => return self.rtcall("axion_array_len", &args, true, buf),
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
                    NO_SPAN,
                ));
                return Op::CallClosure(clos, vec![Atom::Var(b)]);
            }
            // §9 structured fork-join: `parMap worker xs` → the `axion_par_map`
            // runtime driver. The worker's state machine (`worker$step`) and its
            // layout (state size, endpoint slot) were resolved pre-eta; here we
            // materialize the step address and pass the input list. The N endpoints
            // live inside the driver's own scheduler, never in the linear world.
            ("parMap", 2) => {
                if let Expr::Var(wname, _) = args[0] {
                    if let Some((step, size, ep_slot)) = self.parmap_workers.get(wname).cloned() {
                        let xs = self.atom(args[1], buf);
                        let fa = self.fresh();
                        buf.push((fa.clone(), Rhs::Op(Op::FuncAddr(step)), NO_SPAN));
                        return Op::RtCall {
                            func: "axion_par_map".into(),
                            args: vec![
                                Atom::Var(fa),
                                Atom::Int(size as i64),
                                Atom::Int(ep_slot as i64),
                                xs,
                            ],
                            returns: true,
                        };
                    }
                }
                return Op::Unsupported(
                    "parMap: the worker must be a named top-level session function".into(),
                );
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
            Op::CallDirect(target.clone(), vals, self.fn_ret_ty.get(&target).cloned())
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
        buf: &mut Vec<(String, Rhs, Span)>,
    ) -> Op {
        Op::RtCall {
            func: func.to_string(),
            args: args.iter().map(|a| self.atom(a, buf)).collect(),
            returns,
        }
    }

    /// Lowers `e` to a `Term` (sequence of `let`s + result). Every node carries
    /// its own source span (Δ-5): the tail `Ret` carries the whole expression's
    /// span, each `let` the span of its binding expr. Drop-insertion anchors
    /// and the position-level coherence cross-check read them.
    fn term(&mut self, e: &Expr) -> Term {
        let mut buf = Vec::new();
        let rhs = self.rhs(e, &mut buf);
        wrap_spanned(buf, Term::Ret(rhs, e.span()))
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
                if let Pat::Var(n, sp) = p {
                    inner = Term::Let(
                        n.clone(),
                        Rhs::Op(Op::Atom(Atom::Var(params[j].clone()))),
                        *sp,
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
            return Term::Ret(
                Rhs::Op(Op::Unsupported(
                    "function without a catch-all clause".into(),
                )),
                NO_SPAN,
            );
        }

        // cond = band(param_j == lit, …)
        let mut buf: Vec<(String, Rhs, Span)> = Vec::new();
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
                NO_SPAN,
            ));
            cond = Some(match cond {
                None => Atom::Var(c),
                Some(prev) => {
                    let a = self.fresh();
                    buf.push((
                        a.clone(),
                        Rhs::Op(Op::Prim("band".into(), prev, Atom::Var(c))),
                        NO_SPAN,
                    ));
                    Atom::Var(a)
                }
            });
        }
        let then_t = body_term(self);
        let else_t = self.clauses(clauses, params, i + 1);
        wrap_spanned(
            buf,
            Term::Ret(
                Rhs::If(
                    cond.unwrap_or_else(|| panic!("no condition")),
                    Box::new(then_t),
                    Box::new(else_t),
                ),
                NO_SPAN,
            ),
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
        let mut acc = Term::Ret(
            Rhs::Op(Op::Unsupported("non-exhaustive guards".into())),
            NO_SPAN,
        );
        for (g, r) in arms.iter().rev() {
            let uncond = matches!(g, Expr::Var(n, _) if n == "otherwise")
                || matches!(g, Expr::Con(n, _) if n == "True");
            let rterm = self.term(r);
            if uncond {
                acc = rterm;
            } else {
                let mut buf = Vec::new();
                let ga = self.atom(g, &mut buf);
                acc = wrap_spanned(
                    buf,
                    Term::Ret(Rhs::If(ga, Box::new(rterm), Box::new(acc)), NO_SPAN),
                );
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

/// Wraps the `let`s of `buf` (in order) around `tail`. Every wrapper carries
/// its own source span (Δ-5): the span of the expression its binding was
/// lowered from, or `NO_SPAN` for generated chains. The tail keeps its own.
fn wrap_spanned(buf: Vec<(String, Rhs, Span)>, tail: Term) -> Term {
    let mut term = tail;
    for (name, rhs, sp) in buf.into_iter().rev() {
        term = Term::Let(name, rhs, sp, Box::new(term));
    }
    term
}

/// Wraps the `let`s of `buf` (in order) around `tail` — every wrapper carries
/// the shared `span` (generated code: the session state machines).
fn wrap(buf: Vec<(String, Rhs)>, tail: Term, span: Span) -> Term {
    let mut term = tail;
    for (name, rhs) in buf.into_iter().rev() {
        term = Term::Let(name, rhs, span, Box::new(term));
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
#[allow(clippy::too_many_arguments, clippy::type_complexity)]
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
    con_ty: &HashMap<String, Option<String>>,
    fn_ret_ty: &HashMap<String, String>,
    parametric_data: &HashSet<String>,
    makecon_tys: &HashMap<Span, Type>,
    array_tys: &HashMap<Span, Type>,
    parmap_workers: &HashMap<String, (String, i32, i32)>,
) -> (
    Vec<String>,
    Term,
    Vec<String>,
    Vec<(String, Option<String>)>,
    Vec<Type>,
) {
    let mut mono_seeds: Vec<Type> = Vec::new();
    let mut lw = Lower {
        globals,
        fields,
        lam_meta,
        inplace,
        foreigns,
        con_ty,
        fn_ret_ty,
        locals: locals.clone(),
        tmp: 0,
        makecon_tys,
        array_tys,
        parametric_data,
        mono_seeds: &mut mono_seeds,
        parmap_workers,
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
    // `%1` heap-typed parameters → the callee owns them and frees them.
    // Phase A′: the drop-type key of each is resolved HERE, at lowering, and
    // carried on the function — the drop-type walk reads it instead of
    // re-reading the signature (the last source-reconstruction in the path).
    let mut owned: Vec<String> = Vec::new();
    let mut owned_drop_ty: Vec<(String, Option<String>)> = Vec::new();
    if let Some(sig) = &f.sig {
        let mults = sig.param_mults();
        let ptypes = sig.param_types();
        for (i, p) in params.iter().enumerate() {
            if mults.get(i) != Some(&ast::Mult::One) {
                continue;
            }
            let Some(t) = ptypes.get(i) else { continue };
            if !heap_ty(t, data_types) {
                continue;
            }
            owned.push(p.clone());
            // a concrete instantiation of a parametric type (`List P`, fully
            // monomorphic) → the mangled key of its specialized destructor, and
            // seed its generation; otherwise the type head. A tuple whose
            // elements include heap-typed `data` also gets a mangled key and
            // a generated destructor — it is no longer a flat `free`.
            let key = if matches!(t, Type::Tuple(_)) {
                let k = mono_key(t);
                if k.is_some() {
                    mono_seeds.push((**t).clone());
                }
                k
            } else {
                t.head_con().and_then(|h| {
                    if parametric_data.contains(h) {
                        mono_key(t).inspect(|_| mono_seeds.push((*t).clone()))
                    } else {
                        Some(h.to_string())
                    }
                })
            };
            owned_drop_ty.push((params[i].clone(), key));
        }
    }
    (params, body, owned, owned_drop_ty, mono_seeds)
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
        "putStrLn",
        "putStr",
        "showInt",
        "showFloat",
        "toFloat",
        "truncate",
        "sqrt",
        "floor",
        "abs",
    ] {
        arity.entry(b.into()).or_insert(1);
    }
    arity.entry("strAppend".into()).or_insert(2);
    let mut e = Eta { arity, counter: 0 };
    let funcs = module.funcs.iter().map(|f| e.func(f)).collect();
    ast::Module {
        name: module.name.clone(),
        imports: module.imports.clone(),
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
                    Body::Plain(e) => Body::Plain(self.expr(e)),
                    Body::Guarded(arms) => Body::Guarded(
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
                // `parMap worker xs`: keep the worker argument as a bare name (do NOT
                // eta-wrap it into `\v -> worker v`), so the native lowering can
                // resolve it to the worker's state machine — mirrors why session
                // lowering runs pre-eta.
                let is_parmap = matches!(head, Expr::Var(n, _) if n == "parMap");
                let targs: Vec<Expr> = args
                    .iter()
                    .enumerate()
                    .map(|(i, a)| {
                        if is_parmap && i == 0 {
                            (*a).clone()
                        } else {
                            self.expr(a)
                        }
                    })
                    .collect();
                let n = targs.len();
                // the head: if it is a name/constructor it stays; otherwise recurse.
                let head_e = match head {
                    Expr::Var(_, _) | Expr::Con(_, _) => head.clone(),
                    _ => self.expr(head),
                };
                let sp = head.span();
                let applied = targs.into_iter().fold(head_e, |acc, a| {
                    let s2 = (sp.0, a.span().1);
                    Expr::App(Box::new(acc), Box::new(a), s2)
                });
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
                        binds.push((t.clone(), Rhs::Op(Op::CallDirect(name, atoms, None))));
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
                return wrap(
                    binds,
                    Term::Ret(Rhs::Op(Op::Atom(Atom::Int(2))), NO_SPAN),
                    NO_SPAN,
                );
            }
        }
        let mut binds = Vec::new();
        let result = match sess_spine(tail).0 {
            Some("close" | "cancel") => Atom::Int(0), // effect as tail → unit
            _ => self.val(tail, &mut binds),
        };
        binds.push((
            self.fresh(),
            Rhs::Op(Op::StoreRaw(Self::state_atom(), 0, result)),
        ));
        wrap(
            binds,
            Term::Ret(Rhs::Op(Op::Atom(Atom::Int(1))), NO_SPAN),
            NO_SPAN,
        )
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
        wrap(
            binds,
            Term::Ret(Rhs::Op(Op::Atom(Atom::Int(0))), NO_SPAN),
            NO_SPAN,
        )
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
        let cont = wrap(cbinds, self.gen_cont(rest), NO_SPAN);
        let blocked = self.block(idx);
        wrap(
            binds,
            Term::Ret(
                Rhs::If(Atom::Var(pend), Box::new(cont), Box::new(blocked)),
                NO_SPAN,
            ),
            NO_SPAN,
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
            let t = wrap(ab, self.gen_cont(body), NO_SPAN);
            arm_terms.push((tag, t));
        }
        // fold into nested ifs; the last arm is the (exhaustive) else
        let mut dispatch = arm_terms
            .pop()
            .map(|(_, t)| t)
            .unwrap_or_else(|| Term::Ret(Rhs::Op(Op::Atom(Atom::Int(0))), NO_SPAN));
        for (tag, t) in arm_terms.into_iter().rev() {
            let eq = self.fresh();
            dispatch = Term::Let(
                eq.clone(),
                Rhs::Op(Op::Prim(
                    "==".into(),
                    Atom::Var(label.clone()),
                    Atom::Int(tag.unwrap_or(0)),
                )),
                NO_SPAN,
                Box::new(Term::Ret(
                    Rhs::If(Atom::Var(eq), Box::new(t), Box::new(dispatch)),
                    NO_SPAN,
                )),
            );
        }
        let success = wrap(vec![recv_bind], dispatch, NO_SPAN);
        let blocked = self.block(idx);
        wrap(
            binds,
            Term::Ret(
                Rhs::If(Atom::Var(pend), Box::new(success), Box::new(blocked)),
                NO_SPAN,
            ),
            NO_SPAN,
        )
    }

    /// `c <- spawn f; rest` — fork a child task on a fresh channel.
    fn gen_spawn(&mut self, pat: &Pat, target_expr: &Expr, rest: &Expr) -> Term {
        let target = sess_spine(target_expr)
            .0
            .unwrap_or_else(|| panic!("spawn target"))
            .to_string();
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
        wrap(binds, self.gen_cont(rest), NO_SPAN)
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
        wrap(binds, self.gen_cont(rest), NO_SPAN)
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
        wrap(binds, self.gen_cont(rest), NO_SPAN)
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
        wrap(binds, self.gen_cont(rest), NO_SPAN)
    }

    /// `_ <- close ep; rest` — a no-op in the cooperative model (consumes ep).
    fn gen_close(&mut self, pat: &Pat, rest: &Expr) -> Term {
        let mut binds = Vec::new();
        let mut pv = Vec::new();
        pat_vars(pat, &mut pv);
        if let Some(x) = pv.first() {
            binds.push((x.clone(), Rhs::Op(Op::Atom(Atom::Int(0)))));
        }
        wrap(binds, self.gen_cont(rest), NO_SPAN)
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
                NO_SPAN,
                Box::new(Term::Ret(
                    Rhs::If(Atom::Var(eq), Box::new(then_t), Box::new(chain)),
                    NO_SPAN,
                )),
            );
        }
        let dispatch = Term::Let(
            "sess$resume".into(),
            Rhs::Op(Op::LoadRaw(Self::state_atom(), 8)),
            NO_SPAN,
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
        wrap(param_loads, dispatch, NO_SPAN)
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
        wrap(binds, self.gen_cont(case_e), NO_SPAN)
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
            sess_layout(
                pats,
                clause_body(wf).unwrap_or_else(|| panic!("where body")),
                format!("{}$step", wf.name),
            ),
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
            owned_drop_ty: Vec::new(),
            body: g.build_step(pats, body),
        }
    };
    out.push(step_of("main", &[], bound_body, &layouts));
    for wf in &workers {
        out.push(step_of(
            &wf.name,
            &wf.clauses[0].pats,
            clause_body(wf).unwrap_or_else(|| panic!("where body")),
            &layouts,
        ));
    }
    // driver `main`: create scheduler, alloc root state, run, return result
    let size = layouts["main"].size;
    let driver = Term::Let(
        "sess$sched".into(),
        SessGen::rt("axion_sess_new", vec![], true),
        NO_SPAN,
        Box::new(Term::Let(
            "sess$root".into(),
            SessGen::rt(
                "axion_sess_alloc",
                vec![Atom::Var("sess$sched".into()), Atom::Int(size as i64)],
                true,
            ),
            NO_SPAN,
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
                NO_SPAN,
                Box::new(Term::Ret(
                    Rhs::Op(Op::Atom(Atom::Var("sess$res".into()))),
                    NO_SPAN,
                )),
            )),
        )),
    );
    // materialize the step address before the run call
    let driver = Term::Let(
        "sess$fa".into(),
        Rhs::Op(Op::FuncAddr("main$step".into())),
        NO_SPAN,
        Box::new(driver),
    );
    out.push(CoreFn {
        name: "main".into(),
        params: Vec::new(),
        captures: Vec::new(),
        is_closure: false,
        owned_params: Vec::new(),
        owned_drop_ty: Vec::new(),
        body: driver,
    });
    out
}

/// §9 structured fork-join: generates the worker state machine (`<worker>$step`)
/// for every `parMap <worker> <xs>` in the module, reusing the same defunctionalized
/// `SessGen` as `spawn` targets. Returns the step `CoreFn`s plus a map
/// `worker → (step name, state size, endpoint-param slot)` the lowering reads to
/// emit `axion_par_map`. Runs on the ORIGINAL (pre-eta) AST so the worker is a bare
/// name. Empty if the module uses no `parMap`.
/// `parMap` worker name → (step-fn name, state size, endpoint-param byte offset).
type ParmapWorkers = HashMap<String, (String, i32, i32)>;

fn parmap_worker_steps(
    module: &ast::Module,
    native_fns: &HashSet<String>,
) -> (Vec<CoreFn>, ParmapWorkers) {
    let clause_body = sess_clause_body;
    // collect worker names from every function body (incl. `where` clauses)
    let mut names = Vec::new();
    for f in &module.funcs {
        for c in &f.clauses {
            if let Body::Plain(e) = &c.body {
                parmap_targets(e, &mut names);
            }
            for w in &c.wher {
                for wc in &w.clauses {
                    if let Body::Plain(e) = &wc.body {
                        parmap_targets(e, &mut names);
                    }
                }
            }
        }
    }
    let mut seen = HashSet::new();
    let workers: Vec<&ast::Func> = names
        .into_iter()
        .filter(|n| seen.insert(n.clone()))
        .filter_map(|n| module.funcs.iter().find(|f| f.name == n))
        .collect();
    if workers.is_empty() {
        return (Vec::new(), HashMap::new());
    }
    // choice labels → tags (parity with `session_fns`; a worker may use offer/select)
    let mut tags: HashMap<String, i64> = HashMap::new();
    for d in &module.datas {
        for (i, c) in d.cons.iter().enumerate() {
            tags.insert(c.name.clone(), i as i64);
        }
    }
    let mut layouts: HashMap<String, SessLayout> = HashMap::new();
    for wf in &workers {
        let pats = &wf.clauses[0].pats;
        let body = clause_body(wf).unwrap_or_else(|| panic!("parMap worker body"));
        layouts.insert(
            wf.name.clone(),
            sess_layout(pats, body, format!("{}$step", wf.name)),
        );
    }
    let mut fns = Vec::new();
    let mut map = HashMap::new();
    for wf in &workers {
        let lay = &layouts[&wf.name];
        let mut g = SessGen {
            name: wf.name.as_str(),
            lay,
            all: &layouts,
            tags: &tags,
            fns: native_fns,
            susp: HashMap::new(),
            susp_live: Vec::new(),
            tmp: 0,
        };
        let body = clause_body(wf).unwrap_or_else(|| panic!("parMap worker body"));
        let step_body = g.build_step(&wf.clauses[0].pats, body);
        fns.push(CoreFn {
            name: lay.step.clone(),
            params: vec![SESS_SCHED.into(), SESS_STATE.into()],
            captures: Vec::new(),
            is_closure: false,
            owned_params: Vec::new(),
            owned_drop_ty: Vec::new(),
            body: step_body,
        });
        let ep_slot = lay.param_slots.first().copied().unwrap_or(16);
        map.insert(wf.name.clone(), (lay.step.clone(), lay.size, ep_slot));
    }
    (fns, map)
}

/// The lowering plus the analysis inputs the Δ checker reads (Δ-1):
/// `borrow_args` (pure-borrow call positions) and `recinfo` (field ownership).
pub struct Lowered {
    pub fns: Vec<CoreFn>,
    pub borrow_args: BorrowArgs,
    pub recinfo: RecordInfo,
}

/// Stream-fusion pass: rewrites producer→consumer chains on `List`
/// operations into a single fused call that never allocates intermediate
/// `Cons` cells.
fn fuse_list_ops(fns: &mut Vec<CoreFn>) {
    let mut helpers: Vec<CoreFn> = Vec::new();
    for f in fns.iter_mut() {
        fuse_term(&mut f.body, &mut helpers);
    }
    fns.extend(helpers);
}

/// Helper index for generating unique lifted-function names.
static FUSE_CTR: std::sync::atomic::AtomicU32 = std::sync::atomic::AtomicU32::new(0);
fn fuse_fresh() -> String {
    format!(
        "fuse${}",
        FUSE_CTR.fetch_add(1, std::sync::atomic::Ordering::Relaxed)
    )
}

/// Try to fuse a producer→consumer chain occurring in `t`.
fn fuse_term(t: &mut Term, helpers: &mut Vec<CoreFn>) {
    match t {
        Term::Let(x, rhs, _, body) => {
            if let Rhs::Op(Op::CallDirect(prod, prod_args, _)) = rhs {
                if let Some(consume) = matching_consumer(prod, body, x) {
                    if let Some(fused) = build_fused(prod, prod_args, &consume, helpers) {
                        *t = fused;
                        // the fused term preserves the consumer's binder and
                        // continuation — keep fusing the rest of the chain.
                        // Shape: `let <clo?>; let <binder> = fused; REST`.
                        if let Term::Let(_, clo_rhs, _, b1) = t {
                            if matches!(clo_rhs, Rhs::Op(Op::MakeClosure { .. })) {
                                if let Term::Let(_, _, _, b2) = b1.as_mut() {
                                    fuse_term(b2, helpers);
                                }
                            } else {
                                // foldr passes its own closure through — b1
                                // is the binder-let and its body is REST
                                fuse_term(b1, helpers);
                            }
                        }
                        return;
                    }
                }
            }
            fuse_term(body, helpers);
        }
        Term::Drop(_, _, _, _, body) => fuse_term(body, helpers),
        Term::Ret(rhs, _) => match rhs {
            Rhs::If(_, th, el) => {
                fuse_term(th, helpers);
                fuse_term(el, helpers);
            }
            Rhs::Case(_, arms) => {
                for (_, b) in arms {
                    fuse_term(b, helpers);
                }
            }
            Rhs::Op(_) => {}
        },
    }
}

/// Information about a matched consumer of a fused list.
struct FuseConsumer {
    name: String,
    base: Atom,
    /// The user's step closure for `foldr` — passed through to the fused
    /// call; `None` for consumers whose step is synthesized.
    step: Option<Atom>,
    /// The binder holding the consumer's result and the continuation after
    /// the consumer (`None` when the consumer is the function's tail call).
    rest: Option<(String, Term)>,
}

/// Checks whether the variable `x` is consumed by a recognized fusion
/// consumer in `body`.  Returns the consumer's step/base info if found.
fn matching_consumer(_prod: &str, body: &Term, x: &str) -> Option<FuseConsumer> {
    // extract the `CallDirect` consumer from either a `Let` binder or a
    // tail-position `Ret`
    let (cons, args, rest) = match body {
        Term::Let(b, Rhs::Op(Op::CallDirect(c, a, _)), _, cont) => {
            (c, a, Some((b.clone(), (**cont).clone())))
        }
        Term::Ret(Rhs::Op(Op::CallDirect(c, a, _)), _) => (c, a, None),
        Term::Drop(_, _, _, _, b) => return matching_consumer(_prod, b, x),
        _ => return None,
    };
    if !args.last().is_some_and(|a| atom_is(x, a)) {
        return None;
    }
    match cons.as_str() {
        "sum" => Some(FuseConsumer {
            name: "sum".into(),
            base: Atom::Int(0),
            step: None,
            rest,
        }),
        "length" => Some(FuseConsumer {
            name: "length".into(),
            base: Atom::Int(0),
            step: None,
            rest,
        }),
        // `foldr` is its own step: the fused call reuses the user's closure
        // and nil, so the result is exactly `foldr step base (range lo hi)`.
        "foldr" if args.len() >= 2 => Some(FuseConsumer {
            name: "foldr".into(),
            base: args[1].clone(),
            step: Some(args[0].clone()),
            rest,
        }),
        // `null (range lo hi)` = empty list = `lo > hi` → the nil base must
        // be `True`; the step (applied to any non-empty range) returns `False`.
        "null" => Some(FuseConsumer {
            name: "null".into(),
            base: Atom::Int(1),
            step: None,
            rest,
        }),
        _ => None,
    }
}

/// Builds a fused replacement term for `consumer (range lo hi)`.
fn build_fused(
    prod: &str,
    prod_args: &[Atom],
    consume: &FuseConsumer,
    helpers: &mut Vec<CoreFn>,
) -> Option<Term> {
    // only `range` producers fuse soundly: `consume (range lo hi)` becomes
    // `rangeFused lo hi step base`, which never allocates the list.  The
    // other producers (`map`/`filter`/`take`/`drop`) would need their
    // transformation composed into the step (stateful for `take`/`drop`) —
    // a plain `foldr` over the input would silently drop it.
    if prod != "range" || prod_args.len() < 2 {
        return None;
    }
    // specialized sum: direct arithmetic, no closure overhead
    if consume.name == "sum" && consume.step.is_none() {
        let fused_rhs = Rhs::Op(Op::CallDirect(
            "rangeFusedSum".into(),
            vec![
                prod_args[0].clone(),
                prod_args[1].clone(),
                consume.base.clone(),
            ],
            None,
        ));
        let fused = match &consume.rest {
            Some((binder, cont)) => {
                Term::Let(binder.clone(), fused_rhs, NO_SPAN, Box::new(cont.clone()))
            }
            None => Term::Ret(fused_rhs, NO_SPAN),
        };
        return Some(fused);
    }
    // the step closure: `foldr`'s own closure passes through; the others get
    // a synthesized helper wrapped in a `MakeClosure` let-binding.
    let step_name = lift_step(consume, helpers);
    let clo_name = format!("{step_name}_clo");
    let (closure_arg, clo_bind) = match &consume.step {
        Some(step) => (step.clone(), None),
        None => (
            Atom::Var(clo_name.clone()),
            Some((
                clo_name,
                Rhs::Op(Op::MakeClosure {
                    func: step_name,
                    captures: Vec::new(),
                }),
            )),
        ),
    };
    let fused_rhs = Rhs::Op(Op::CallDirect(
        "rangeFused".into(),
        vec![
            prod_args[0].clone(),
            prod_args[1].clone(),
            closure_arg,
            consume.base.clone(),
        ],
        None,
    ));
    // the fused call replaces the consumer in its original position: bound to
    // the consumer's binder with the rest of the function as the body, or as
    // the tail call when the consumer was one.
    let fused = match &consume.rest {
        Some((binder, cont)) => {
            Term::Let(binder.clone(), fused_rhs, NO_SPAN, Box::new(cont.clone()))
        }
        None => Term::Ret(fused_rhs, NO_SPAN),
    };
    // wrap with `let _clo = closure stepName; <fused>`
    match clo_bind {
        Some((clo, make_clo)) => Some(Term::Let(clo, make_clo, term_span(&fused), Box::new(fused))),
        None => Some(fused),
    }
}

/// Lifts the synthesized step function into a top-level `CoreFn` and
/// returns its name.  Called only for consumers without a user closure
/// (`foldr` passes its own through); `null`'s step returns `False` — the
/// nil base `True` covers the empty-range case.
fn lift_step(consume: &FuseConsumer, helpers: &mut Vec<CoreFn>) -> String {
    let name = fuse_fresh();
    let body = match consume.name.as_str() {
        "sum" => {
            // \x acc -> x + acc
            Term::Ret(
                Rhs::Op(Op::Prim(
                    "+".into(),
                    Atom::Var("x".into()),
                    Atom::Var("acc".into()),
                )),
                NO_SPAN,
            )
        }
        "length" => {
            // \x acc -> 1 + acc
            Term::Ret(
                Rhs::Op(Op::Prim("+".into(), Atom::Int(1), Atom::Var("acc".into()))),
                NO_SPAN,
            )
        }
        _ => Term::Ret(Rhs::Op(Op::Atom(Atom::Int(0))), NO_SPAN),
    };
    helpers.push(CoreFn {
        name: name.clone(),
        params: vec!["x".into(), "acc".into()],
        captures: Vec::new(),
        // the step is reached through `MakeClosure` + `CallClosure`, whose ABI
        // passes the env pointer as the 1st argument — it must be a closure.
        is_closure: true,
        owned_params: Vec::new(),
        owned_drop_ty: Vec::new(),
        body,
    });
    name
}

pub fn lower_with(
    module: &ast::Module,
    inplace: &HashSet<Span>,
    makecon_tys: &HashMap<Span, Type>,
    array_tys: &HashMap<Span, Type>,
    _fuse: bool, // kept for API compatibility, auto-fusion always runs now
) -> Lowered {
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
    // heap/drop decisions exclude unboxed enums (immediate tags, not allocations).
    let boxed = boxed_data_names(module);
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
    let foreigns: HashSet<String> = module.foreigns.iter().map(|f| f.name.clone()).collect();
    // Phase A′: constructor → `data`-type name of its value (None for unboxed enum
    // constructors — immediate tags, never dropped). Attached to `MakeCon`/`MakeRecord`
    // at lowering so the drop machinery reads the type off the node instead of
    // reconstructing it.
    let con_ty: HashMap<String, Option<String>> = module
        .datas
        .iter()
        .flat_map(|d| {
            let ty = if is_enum_data(d) {
                None
            } else {
                Some(d.name.clone())
            };
            d.cons.iter().map(move |c| (c.name.clone(), ty.clone()))
        })
        .collect();
    // Phase A′: function → `data`-type name of its (boxed) result, from the
    // signature. Attached to `CallDirect` at lowering. (Used to live only in the
    // drop-type walk; now the node itself carries it.)
    let fn_ret_ty: HashMap<String, String> = module
        .funcs
        .iter()
        .filter_map(|f| {
            let rt = result_type(f.sig.as_ref()?);
            let h = rt.head_con()?;
            // `Array` is a native heap resource freed by the flat `axion_drop_Array`
            // (element type phantom), so a function returning it produces an owned
            // array the caller reclaims — keyed flat, like `ArrayNew`.
            if h == "Array" {
                Some((f.name.clone(), "Array".to_string()))
            } else if boxed.contains(h) {
                let key = mono_key(rt).unwrap_or_else(|| h.to_string());
                Some((f.name.clone(), key))
            } else {
                None
            }
        })
        .collect();
    // parametric data types (`data List a = …`): a dropped CONCRETE instantiation
    // (`List P`) routes to a specialized destructor. Shared by the lowering
    // (owned `%1` param keys) and the destructor generation.
    let parametric_data: HashSet<String> = module
        .datas
        .iter()
        .filter(|d| !d.params.is_empty())
        .map(|d| d.name.clone())
        .collect();
    // typeclass method names (interp-only): exclude the function from native
    let methods: HashSet<String> = module
        .classes
        .iter()
        .flat_map(|c| c.methods.iter().map(|(m, _)| m.clone()))
        .collect();
    // Phase B generic-owning TEMPLATES (interp-only): an unconstrained generic
    // function with an owned `%1` parameter of a var-carrying parametric type
    // (`dropList :: List a %1 -> Int`). Its param's drop-type key is
    // unresolvable (flat free → payload leak), so it must not compile natively
    // — only the monomorphized specializations (`dropList$P`, materialized
    // before lowering) have concrete parameters and deep-drop.
    let owning_generics: HashSet<String> =
        module.funcs.iter().filter_map(owning_generic_var).collect();

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
        .filter_map(|f| {
            if owning_generics.contains(&f.name) {
                return None;
            }
            top_candidate(f, &data_types, &methods).map(|a| (f.name.clone(), a))
        })
        .collect();
    // §9: `parMap` worker names are compiled to their own state machines
    // (`<worker>$step`), not as normal native functions — so a reference to one does
    // NOT disqualify the referring function from native candidacy.
    let parmap_worker_names: HashSet<String> = {
        let mut v = Vec::new();
        for f in &module.funcs {
            for c in &f.clauses {
                if let Body::Plain(e) = &c.body {
                    parmap_targets(e, &mut v);
                }
                for w in &c.wher {
                    for wc in &w.clauses {
                        if let Body::Plain(e) = &wc.body {
                            parmap_targets(e, &mut v);
                        }
                    }
                }
            }
        }
        v.into_iter().collect()
    };
    loop {
        let mut remove = None;
        for f in &module.funcs {
            if !native_ok.contains_key(&f.name) {
                continue;
            }
            let mut refs = HashSet::new();
            body_refs(f, &mut refs);
            if refs.iter().any(|g| {
                func_set.contains(g.as_str())
                    && !native_ok.contains_key(g)
                    && !parmap_worker_names.contains(g)
            }) {
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
    // §9 structured fork-join: worker state machines for every `parMap` target,
    // plus the map the lowering uses to emit `axion_par_map`. Runs pre-eta.
    let (parmap_steps, parmap_map) = parmap_worker_steps(orig_module, &native_fn_names);

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
    // Phase A′: seeds for the specialized destructors of parametric instantiations
    // dropped as owned values — collected at lowering, where the keys are resolved.
    let mut mono_seeds: Vec<Type> = Vec::new();
    for f in &module.funcs {
        let Some(&arity) = native_ok.get(&f.name) else {
            continue;
        };
        let wheres: Vec<&ast::Func> = f.clauses.iter().flat_map(|c| &c.wher).collect();
        let mut locals = HashMap::new();
        for w in &wheres {
            locals.insert(w.name.clone(), format!("{}${}", f.name, w.name));
        }

        let (params, body, owned, owned_drop_ty, seeds) = lower_func(
            f,
            arity,
            &locals,
            &globals,
            &fields,
            &lam_meta,
            inplace,
            &foreigns,
            &boxed,
            &con_ty,
            &fn_ret_ty,
            &parametric_data,
            makecon_tys,
            array_tys,
            &parmap_map,
        );
        mono_seeds.extend(seeds);
        out.push(CoreFn {
            name: f.name.clone(),
            params,
            captures: Vec::new(),
            is_closure: false,
            owned_params: owned,
            owned_drop_ty,
            body,
        });

        for w in &wheres {
            let warity = w.clauses.first().map(|c| c.pats.len()).unwrap_or(0);
            let (wp, wb, wo, wot, wseeds) = lower_func(
                w,
                warity,
                &locals,
                &globals,
                &fields,
                &lam_meta,
                inplace,
                &foreigns,
                &boxed,
                &con_ty,
                &fn_ret_ty,
                &parametric_data,
                makecon_tys,
                array_tys,
                &parmap_map,
            );
            mono_seeds.extend(wseeds);
            out.push(CoreFn {
                name: locals[&w.name].clone(),
                params: wp,
                captures: Vec::new(),
                is_closure: false,
                owned_params: wo,
                owned_drop_ty: wot,
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
            con_ty: &con_ty,
            fn_ret_ty: &fn_ret_ty,
            locals,
            tmp: 0,
            makecon_tys,
            array_tys,
            parametric_data: &parametric_data,
            mono_seeds: &mut Vec::new(),
            parmap_workers: &parmap_map,
        };
        out.push(CoreFn {
            name,
            params,
            captures,
            is_closure: true,
            owned_params: Vec::new(),
            owned_drop_ty: Vec::new(),
            body: lw.term(body),
        });
    }

    // Uniquify: alpha-rename shadowed local bindings so every binding in a
    // function has a distinct name. The reclamation analyses (`droppable_vars`,
    // escape, `compute_borrow_args`) are string-keyed, so a shadowed name
    // (`let a = …; let a = …`, or the `imperative do` `a <- …; a <- …`
    // desugaring) would otherwise conflate two distinct bindings and free the
    // wrong one. See docs/validation-report.md F-3.
    for f in &mut out {
        uniquify_fn(f);
    }

    // Collapse trivial single-var `case` bindings (`case s of a -> body`, from the
    // `imperative do` `a <- …` desugaring) into a substitution `a := s`. The
    // scrutinee is an already-forced value, so this is a pure rebinding; keeping
    // the `case` makes the reclamation analysis mishandle the scrutinee (the arm
    // var aliases it), double-freeing a threaded resource. See validation-report.md.
    for f in &mut out {
        let body = std::mem::replace(
            &mut f.body,
            Term::Ret(Rhs::Op(Op::Atom(Atom::Int(0))), NO_SPAN),
        );
        f.body = collapse_var_cases(body);
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
    let all_dty = build_all_drop_ty(&out);
    let empty = HashMap::new();

    let mut result: Vec<CoreFn> = Vec::with_capacity(out.len());
    let mut skip_seeds: Vec<(String, Vec<usize>)> = Vec::new();
    // stream-fusion pass: fuse producer→consumer chains on List operations
    fuse_list_ops(&mut out);
    for f in out {
        let dty = all_dty.get(&f.name).unwrap_or(&empty);
        let (f, seeds) = insert_drops(f, &borrow_args, dty, &recinfo);
        result.push(f);
        skip_seeds.extend(seeds);
    }
    // generated destructors: added AFTER drop insertion (they manage
    // memory by hand, they don't go through the reclamation analysis)
    result.extend(gen_destructors(&recinfo));
    // Phase 2a array destructor: calls axion_array_free (generic, no per-element deep drop)
    result.push(CoreFn {
        name: "axion_drop_Array".into(),
        params: vec!["_p".into()],
        captures: Vec::new(),
        is_closure: false,
        owned_params: Vec::new(),
        owned_drop_ty: Vec::new(),
        body: Term::Ret(
            Rhs::Op(Op::RtCall {
                func: "axion_array_free".into(),
                args: vec![Atom::Var("_p".into())],
                returns: false,
            }),
            NO_SPAN,
        ),
    });
    // Phase 4: push seeds for any function whose return type is a concrete
    // parametric instantiation (e.g. `build :: Int -> List P`).
    for f in &module.funcs {
        if let Some(sig) = &f.sig {
            let rt = result_type(sig);
            if let Some(h) = rt.head_con() {
                if parametric_data.contains(h) && mono_key(rt).is_some() {
                    mono_seeds.push(rt.clone());
                }
            }
        }
    }
    // specialized destructors for concrete instantiations of parametric types
    // dropped as owned values (`List P` → `axion_drop_List$P`): they also free
    // the polymorphic payloads a generic destructor cannot see.
    // Separate tuple seeds from `data`-type seeds — tuples get their own
    // per-element destructors.
    let (data_seeds, tuple_seeds): (Vec<_>, Vec<_>) = mono_seeds
        .iter()
        .cloned()
        .partition(|t| !matches!(t, Type::Tuple(_)));
    result.extend(gen_mono_destructors(
        module,
        &recinfo,
        &parametric_data,
        data_seeds,
    ));
    // tuple-owned %1: destructors for tuple types that contain heap elements
    result.extend(gen_tuple_destructors(&tuple_seeds, &recinfo));
    // Phase 2c array mono destructors: scan for parametric ArrayNew ops and
    // generate per-element deep-drop destructors (axion_drop_Array$List$P, etc.)
    {
        let array_seeds = collect_array_seeds(&result);
        result.extend(gen_mono_array_destructors(
            &array_seeds,
            &recinfo,
            &parametric_data,
        ));
    }
    // F-3 skip-variant destructors: `axion_drop_T_skip_0` — reclaim all slots
    // except the listed ones (transferred `%1` fields).
    result.extend(gen_skip_destructors(&skip_seeds, &recinfo));
    // native session state machines (§11): also hand-managed (task states live in
    // the scheduler's nursery arena), so they bypass the drop analysis too.
    result.extend(session);
    // §9 structured fork-join worker state machines (same hand-managed nursery
    // arena as the session steps — they bypass the drop analysis too).
    result.extend(parmap_steps);
    Lowered {
        fns: result,
        borrow_args,
        recinfo,
    }
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
        // each constructor's tag and the (offset, way) of the heap fields it owns:
        // a concrete `data` field with heap → its destructor, else a flat free.
        let cons: Vec<(i64, Vec<(i32, DropWay)>)> = recinfo
            .type_cons(&ty)
            .unwrap_or(&[])
            .iter()
            .map(|con| {
                let tag = recinfo.tag(con).unwrap_or(0) as i64;
                let slots = recinfo
                    .drop_slots(con)
                    .iter()
                    .map(|(off, f)| (*off, drop_way_named(f, recinfo)))
                    .collect();
                (tag, slots)
            })
            .collect();
        let single = cons.len() <= 1;
        let body = destructor_body(&cons, single, recinfo.is_mixed_type(&ty), &p, &mut ctr);
        out.push(CoreFn {
            name: format!("axion_drop_{ty}"),
            params: vec![p],
            captures: Vec::new(),
            is_closure: false,
            owned_params: Vec::new(),
            owned_drop_ty: Vec::new(),
            body,
        });
    }
    out
}

/// The drop way of a concrete `data`-typed field: its own destructor when the
/// type owns heap fields, otherwise a flat `free`.
fn drop_way_named(tyname: &str, recinfo: &RecordInfo) -> DropWay {
    if recinfo.needs_deep_drop(tyname) {
        DropWay::Deep(tyname.to_string())
    } else {
        DropWay::Flat
    }
}

/// The shared destructor-body shape (generic `gen_destructors` and monomorphized
/// `gen_mono_destructors` differ only in how they resolve each field's `DropWay`).
/// `cons` lists each constructor's tag and its heap-field `(offset, way)` slots;
/// `single` marks a tagless 1-constructor type; `mixed` marks a type whose nullary
/// constructors are tagged immediates (guard the whole body on the low bit so a
/// non-pointer is never dereferenced/freed). `p` is the block pointer parameter.
fn destructor_body(
    cons: &[(i64, Vec<(i32, DropWay)>)],
    single: bool,
    mixed: bool,
    p: &str,
    ctr: &mut u32,
) -> Term {
    let free_ret = free_then_ret(p);
    let body = if single {
        match cons.first() {
            Some((_, slots)) => emit_field_drops(slots, p, ctr, free_ret),
            None => free_ret,
        }
    } else {
        // multi-con: load the tag and one independent `if` per constructor with
        // fields; only the matching tag fires at runtime.
        let mut chain = free_ret;
        for (tag, slots) in cons.iter().rev() {
            if slots.is_empty() {
                continue;
            }
            let branch = emit_field_drops(slots, p, ctr, unit0());
            let cmp = fresh_dd(ctr);
            let ifstep = Term::Let(
                fresh_dd(ctr),
                Rhs::If(Atom::Var(cmp.clone()), Box::new(branch), Box::new(unit0())),
                NO_SPAN,
                Box::new(chain),
            );
            chain = Term::Let(
                cmp,
                Rhs::Op(Op::Prim(
                    "==".into(),
                    Atom::Var("_tag".into()),
                    Atom::Int(*tag),
                )),
                NO_SPAN,
                Box::new(ifstep),
            );
        }
        Term::Let(
            "_tag".into(),
            Rhs::Op(Op::LoadRaw(Atom::Var(p.to_string()), 0)),
            NO_SPAN,
            Box::new(chain),
        )
    };
    if mixed {
        let bit = fresh_dd(ctr);
        let res = fresh_dd(ctr);
        Term::Let(
            bit.clone(),
            Rhs::Op(Op::Prim(
                "band".into(),
                Atom::Var(p.to_string()),
                Atom::Int(1),
            )),
            NO_SPAN,
            Box::new(Term::Let(
                res,
                Rhs::If(Atom::Var(bit), Box::new(unit0()), Box::new(body)),
                NO_SPAN,
                Box::new(unit0()),
            )),
        )
    } else {
        body
    }
}

/// Frees a constructor's owned heap fields (loaded by offset from `p`) before
/// `cont`: each field's destructor (`Deep`) or a flat `free` (`Flat`); non-heap
/// slots (`None`) are skipped. Folded in reverse so earlier fields free first.
fn emit_field_drops(slots: &[(i32, DropWay)], p: &str, ctr: &mut u32, cont: Term) -> Term {
    let mut term = cont;
    for (off, way) in slots.iter().rev() {
        let fp = fresh_dd(ctr);
        let call = match way {
            DropWay::Deep(name) => Op::CallDirect(
                format!("axion_drop_{name}"),
                vec![Atom::Var(fp.clone())],
                None,
            ),
            DropWay::Flat => Op::RtCall {
                func: "axion_free".into(),
                args: vec![Atom::Var(fp.clone())],
                returns: false,
            },
            // non-heap fields are filtered out before this point; skip defensively
            // so a stray `None` never emits a wild `free`.
            DropWay::None => continue,
        };
        term = Term::Let(
            fp.clone(),
            Rhs::Op(Op::LoadRaw(Atom::Var(p.to_string()), *off)),
            NO_SPAN,
            Box::new(Term::Let(
                fresh_dd(ctr),
                Rhs::Op(call),
                NO_SPAN,
                Box::new(term),
            )),
        );
    }
    term
}

fn fresh_dd(ctr: &mut u32) -> String {
    let n = format!("_dd{ctr}");
    *ctr += 1;
    n
}

fn unit0() -> Term {
    Term::Ret(Rhs::Op(Op::Atom(Atom::Int(0))), NO_SPAN)
}

fn free_then_ret(p: &str) -> Term {
    Term::Let(
        "_dfree".into(),
        Rhs::Op(Op::RtCall {
            func: "axion_free".into(),
            args: vec![Atom::Var(p.to_string())],
            returns: false,
        }),
        NO_SPAN,
        Box::new(unit0()),
    )
}

// --- monomorphized destructors (§ polymorphic-payload reclamation) ---
//
// A generic `List a` destructor cannot free the element field `a` (its type is a
// variable; at runtime an i64 is indistinguishable pointer-vs-Int). So a dropped
// `List P` leaks its `P` payloads. Fix: for each concrete instantiation dropped
// (`List P`), generate a specialized `axion_drop_List$P` that also frees the
// element via `P`'s drop, recursing on the tail via `axion_drop_List$P`.

/// The head constructor and applied arguments of a type: `List P` → ("List", [P]).
fn ty_head_args(t: &Type) -> (Option<&str>, Vec<&Type>) {
    let mut args = Vec::new();
    let mut cur = t;
    while let Type::App(f, a) = cur {
        args.push(a.as_ref());
        cur = f;
    }
    args.reverse();
    (cur.head_con(), args)
}

/// The monomorphic mangle key of a fully-concrete type: `List P` → `"List$P"`,
/// `List (Maybe P)` → `"List$Maybe$P"`. `None` if any part is a type variable.
fn mono_key(t: &Type) -> Option<String> {
    match t {
        Type::Tuple(ts) => {
            let parts: Vec<String> = ts.iter().map(mono_key).collect::<Option<Vec<_>>>()?;
            Some(format!("tuple${}", parts.join("$")))
        }
        _ => {
            let (head, args) = ty_head_args(t);
            let mut key = head?.to_string();
            for a in args {
                key.push('$');
                key.push_str(&mono_key(a)?);
            }
            Some(key)
        }
    }
}

/// Substitutes type parameters (by name) in a field type.
fn subst_ty(t: &Type, subst: &HashMap<String, Type>) -> Type {
    match t {
        Type::Var(v) => subst.get(v).cloned().unwrap_or_else(|| t.clone()),
        Type::Con(_) | Type::Unit => t.clone(),
        Type::App(f, a) => Type::App(Box::new(subst_ty(f, subst)), Box::new(subst_ty(a, subst))),
        Type::Arrow { mult, from, to } => Type::Arrow {
            mult: *mult,
            from: Box::new(subst_ty(from, subst)),
            to: Box::new(subst_ty(to, subst)),
        },
        Type::Tuple(ts) => Type::Tuple(ts.iter().map(|x| subst_ty(x, subst)).collect()),
    }
}

/// How to free a value of a (concrete) field type.
enum DropWay {
    Flat,         // heap object with no owned heap fields → a flat `free`
    Deep(String), // needs the destructor `axion_drop_<key>`
    None,         // not a heap object (Int/String/function/tuple) → nothing to do
}

/// How to drop a (concrete) field type; pushes any parametric instantiation it
/// references onto the worklist so its specialized destructor is generated too.
fn drop_way(
    t: &Type,
    recinfo: &RecordInfo,
    parametric_data: &HashSet<String>,
    work: &mut Vec<Type>,
) -> DropWay {
    let (head, args) = ty_head_args(t);
    let Some(head) = head else {
        return DropWay::None;
    };
    if recinfo.type_cons(head).is_none() {
        return DropWay::None; // not a `data` type (Int/String/Buffer/function/tuple)
    }
    // a PARAMETRIC data type instantiated with a concrete arg (List P) → the
    // specialized destructor (and it may reference further instantiations).
    if !args.is_empty() && parametric_data.contains(head) {
        if let Some(key) = mono_key(t) {
            work.push(t.clone());
            return DropWay::Deep(key);
        }
    }
    // monomorphic data type: its generic destructor, or a flat free.
    // Unboxed enums (all constructors nullary) hold immediate tags — skip.
    if recinfo.is_enum_type(head) {
        return DropWay::None;
    }
    if recinfo.needs_deep_drop(head) {
        DropWay::Deep(head.to_string())
    } else {
        DropWay::Flat
    }
}

/// Generates a specialized destructor per concrete parametric instantiation
/// dropped (`List P`, `List (Maybe P)`, …), transitively. Reuses the same body
/// shape as `gen_destructors` (mixed low-bit guard + tag dispatch), but the drop
/// slots are the con fields resolved under the instantiation's substitution — so
/// the (formerly polymorphic) element field is now a concrete, freed slot.
fn gen_mono_destructors(
    module: &ast::Module,
    recinfo: &RecordInfo,
    parametric_data: &HashSet<String>,
    seeds: Vec<Type>,
) -> Vec<CoreFn> {
    let datas: HashMap<&str, &ast::DataDecl> =
        module.datas.iter().map(|d| (d.name.as_str(), d)).collect();
    let mut out = Vec::new();
    let mut done: HashSet<String> = HashSet::new();
    let mut work = seeds;
    while let Some(t) = work.pop() {
        let Some(key) = mono_key(&t) else { continue };
        if !done.insert(key.clone()) {
            continue;
        }
        let (head, args) = ty_head_args(&t);
        let Some(head) = head else { continue };
        let Some(d) = datas.get(head).copied() else {
            continue;
        };
        let subst: HashMap<String, Type> = d
            .params
            .iter()
            .cloned()
            .zip(args.iter().map(|a| (*a).clone()))
            .collect();

        // per-constructor drop slots, resolved under the substitution. Computed
        // eagerly (up front) so `work` is only borrowed here, not while the body
        // is built. `all_slots[i]` are the drop slots of `d.cons[i]`.
        let all_slots: Vec<Vec<(i32, DropWay)>> = d
            .cons
            .iter()
            .map(|con| {
                con.fields
                    .iter()
                    .enumerate()
                    .filter_map(|(i, f)| {
                        let rty = subst_ty(&f.ty, &subst);
                        match drop_way(&rty, recinfo, parametric_data, &mut work) {
                            DropWay::None => None,
                            way => Some((recinfo.field_offset(&con.name, i), way)),
                        }
                    })
                    .collect()
            })
            .collect();
        // tag each constructor's (already substituted) slots and build the body
        // with the shared destructor shape — identical to the generic destructor
        // but for the concrete-under-substitution slots.
        let cons: Vec<(i64, Vec<(i32, DropWay)>)> = d
            .cons
            .iter()
            .zip(all_slots)
            .map(|(c, slots)| (recinfo.tag(&c.name).unwrap_or(0) as i64, slots))
            .collect();
        let p = "_p".to_string();
        let mut ctr = 0u32;
        let body = destructor_body(
            &cons,
            d.cons.len() <= 1,
            recinfo.is_mixed_type(head),
            &p,
            &mut ctr,
        );
        out.push(CoreFn {
            name: format!("axion_drop_{key}"),
            params: vec![p],
            captures: Vec::new(),
            is_closure: false,
            owned_params: Vec::new(),
            owned_drop_ty: Vec::new(),
            body,
        });
    }
    out
}

/// Scans the Core IR for `ArrayNew` ops whose `elem_ty` is set, returning
/// the element types as synthetic `Array (<elem>)` seeds.
fn collect_array_seeds(fns: &[CoreFn]) -> Vec<Type> {
    let mut seeds = Vec::new();
    for f in fns {
        scan_body_array_seeds(&f.body, &mut seeds);
    }
    seeds
}

fn scan_body_array_seeds(t: &Term, out: &mut Vec<Type>) {
    match t {
        Term::Let(_, rhs, _, body) => {
            if let Rhs::Op(Op::ArrayNew {
                elem_ty: Some(et), ..
            }) = rhs
            {
                out.push(Type::App(
                    Box::new(Type::Con("Array".into())),
                    Box::new(Type::Con(et.clone())),
                ));
            }
            scan_body_array_seeds(body, out);
        }
        Term::Drop(_, _, _, _, body) => scan_body_array_seeds(body, out),
        Term::Ret(rhs, _) => {
            if let Rhs::If(_, t, e) = rhs {
                scan_body_array_seeds(t, out);
                scan_body_array_seeds(e, out);
            }
            if let Rhs::Case(_, arms) = rhs {
                for (_, b) in arms {
                    scan_body_array_seeds(b, out);
                }
            }
        }
    }
}

/// Generates monomorphized array destructors: for each concrete element type
/// (`List$P`), emits `axion_drop_Array$List$P` that deep-drops each element
/// and then frees the array shell.
fn gen_mono_array_destructors(
    seeds: &[Type],
    recinfo: &RecordInfo,
    parametric_data: &HashSet<String>,
) -> Vec<CoreFn> {
    let mut out = Vec::new();
    let mut done: HashSet<String> = HashSet::new();
    for t in seeds {
        let (head, args) = ty_head_args(t);
        if head != Some("Array") || args.is_empty() {
            continue;
        }
        let elem_t = args[0];
        let Some(elem_key) = mono_key(elem_t) else {
            continue;
        };
        let key = format!("Array${elem_key}");
        if !done.insert(key.clone()) {
            continue;
        }
        let dw = drop_way(elem_t, recinfo, parametric_data, &mut Vec::new());
        let body = match dw {
            DropWay::Deep(dk) => {
                let p = "_p".to_string();
                let mut ctr = 0u32;
                array_deep_drop_body(&p, &format!("axion_drop_{dk}"), &mut ctr)
            }
            _ => Term::Ret(
                Rhs::Op(Op::RtCall {
                    func: "axion_array_free".into(),
                    args: vec![Atom::Var("_p".into())],
                    returns: false,
                }),
                NO_SPAN,
            ),
        };
        out.push(CoreFn {
            name: format!("axion_drop_{key}"),
            params: vec!["_p".into()],
            captures: Vec::new(),
            is_closure: false,
            owned_params: Vec::new(),
            owned_drop_ty: Vec::new(),
            body,
        });
    }
    out
}

/// Loop body for array deep-drop: for i = n-1 down to 0, load elem[i],
/// drop it via `elem_dtor`, then free the array shell.
fn array_deep_drop_body(ptr: &str, elem_dtor: &str, ctr: &mut u32) -> Term {
    let fresh = |ctr: &mut u32| -> String {
        let n = *ctr;
        *ctr += 1;
        format!("_ad{n}")
    };
    let n = fresh(ctr);
    let i = fresh(ctr);
    let cond = fresh(ctr);
    let elem = fresh(ctr);
    let free_shell = || {
        Term::Ret(
            Rhs::Op(Op::RtCall {
                func: "axion_array_free".into(),
                args: vec![Atom::Var(ptr.into())],
                returns: false,
            }),
            NO_SPAN,
        )
    };
    let loop_body = Term::Let(
        elem.clone(),
        Rhs::Op(Op::RtCall {
            func: "axion_array_get".into(),
            args: vec![Atom::Var(ptr.into()), Atom::Var(i.clone())],
            returns: true,
        }),
        NO_SPAN,
        Box::new(Term::Drop(
            elem,
            Some(elem_dtor.to_string()),
            Vec::new(),
            NO_SPAN,
            Box::new(Term::Let(
                i.clone(),
                Rhs::Op(Op::Prim("-".into(), Atom::Var(i.clone()), Atom::Int(1))),
                NO_SPAN,
                Box::new(free_shell()),
            )),
        )),
    );
    let loop_check = Term::Let(
        cond.clone(),
        Rhs::Op(Op::Prim(">=".into(), Atom::Var(i.clone()), Atom::Int(0))),
        NO_SPAN,
        Box::new(Term::Ret(
            Rhs::If(Atom::Var(cond), Box::new(loop_body), Box::new(free_shell())),
            NO_SPAN,
        )),
    );
    Term::Let(
        n.clone(),
        Rhs::Op(Op::RtCall {
            func: "axion_array_len".into(),
            args: vec![Atom::Var(ptr.into())],
            returns: true,
        }),
        NO_SPAN,
        Box::new(Term::Let(
            i,
            Rhs::Op(Op::Prim("-".into(), Atom::Var(n), Atom::Int(1))),
            NO_SPAN,
            Box::new(loop_check),
        )),
    )
}

/// Tuple-owned %1: generates a destructor for a concrete tuple type whose
/// elements include heap-typed `data` objects.  The destructor deep-drops
/// each `data`-typed element and flat-frees the rest, then frees the shell.
/// Named `axion_drop_tuple$<mangle>` (matching the key from `mono_key`).
fn gen_tuple_destructors(seeds: &[Type], recinfo: &RecordInfo) -> Vec<CoreFn> {
    let mut seen: HashSet<String> = HashSet::new();
    let mut out = Vec::new();
    for t in seeds {
        let key = match mono_key(t) {
            Some(k) => k,
            None => continue,
        };
        if !seen.insert(key.clone()) {
            continue;
        }
        let name = format!("axion_drop_{key}");
        let p = "_p".to_string();
        let mut ctr = 0u32;
        // for each element: if it's a heap `data` type → deep-drop via its
        // destructor; otherwise flat-free.  Then free the tuple shell.
        let mut body = free_then_ret(&p);
        if let Type::Tuple(ts) = t {
            for (i, el) in ts.iter().enumerate().rev() {
                let off = i as i32 * 8;
                let way = if let Some(h) = el.head_con() {
                    if recinfo.type_cons(h).is_some() {
                        if recinfo.needs_deep_drop(h) {
                            DropWay::Deep(h.to_string())
                        } else {
                            DropWay::Flat
                        }
                    } else {
                        continue; // scalar, not a `data` type → no free needed
                    }
                } else {
                    continue;
                };
                let fp = fresh_dd(&mut ctr);
                let call = match way {
                    DropWay::Deep(dn) => Op::CallDirect(
                        format!("axion_drop_{dn}"),
                        vec![Atom::Var(fp.clone())],
                        None,
                    ),
                    DropWay::Flat => Op::RtCall {
                        func: "axion_free".into(),
                        args: vec![Atom::Var(fp.clone())],
                        returns: false,
                    },
                    DropWay::None => continue,
                };
                body = Term::Let(
                    fp.clone(),
                    Rhs::Op(Op::LoadRaw(Atom::Var(p.clone()), off)),
                    NO_SPAN,
                    Box::new(Term::Let(
                        fresh_dd(&mut ctr),
                        Rhs::Op(call),
                        NO_SPAN,
                        Box::new(body),
                    )),
                );
            }
        }
        out.push(CoreFn {
            name,
            params: vec![p],
            captures: Vec::new(),
            is_closure: false,
            owned_params: Vec::new(),
            owned_drop_ty: Vec::new(),
            body,
        });
    }
    out
}

/// F-3 per-field ownership: skip-variant destructors `axion_drop_T_skip_0`.
/// Each `(type_name, skip_set)` seed produces one destructor that reclaims
/// every heap field of the type EXCEPT the listed slots (the transferred
/// `%1` fields).  Skips are per-constructor: the destructor dispatches on
/// the tag (same body shape as `gen_destructors`) but fires only the
/// non-skipped field drops.  A seed whose skip covers all heap slots is
/// dropped — the remaining work is just a shell free (flat).
fn gen_skip_destructors(seeds: &[(String, Vec<usize>)], recinfo: &RecordInfo) -> Vec<CoreFn> {
    let mut out = Vec::new();
    let mut seen: HashSet<(String, Vec<usize>)> = HashSet::new();
    for (ty, skip) in seeds {
        let mut sorted_skip = skip.clone();
        sorted_skip.sort();
        sorted_skip.dedup();
        if sorted_skip.is_empty() || !seen.insert((ty.clone(), sorted_skip.clone())) {
            continue;
        }
        // collect skipped field OFFSETS per constructor
        let cons: Vec<(i64, Vec<(i32, DropWay)>)> = recinfo
            .type_cons(ty)
            .unwrap_or(&[])
            .iter()
            .map(|con| {
                let tag = recinfo.tag(con).unwrap_or(0) as i64;
                let skip_offs: HashSet<i32> = sorted_skip
                    .iter()
                    .map(|&i| recinfo.field_offset(con, i))
                    .collect();
                let remaining: Vec<(i32, DropWay)> = recinfo
                    .drop_slots(con)
                    .iter()
                    .filter(|(off, _)| !skip_offs.contains(off))
                    .map(|(off, f)| (*off, drop_way_named(f, recinfo)))
                    .collect();
                (tag, remaining)
            })
            .collect();
        // if every constructor has zero remaining slots → pure shell free,
        // same as flat `drop` — skip the destructor
        if cons.iter().all(|(_, s)| s.is_empty()) {
            continue;
        }
        let skip_name: String = sorted_skip
            .iter()
            .map(|i| i.to_string())
            .collect::<Vec<_>>()
            .join("_");
        let name = format!("axion_drop_{ty}_skip_{skip_name}");
        let p = "_p".to_string();
        let mut ctr = 0u32;
        let single = cons.len() <= 1;
        let body = destructor_body(&cons, single, recinfo.is_mixed_type(ty), &p, &mut ctr);
        out.push(CoreFn {
            name,
            params: vec![p],
            captures: Vec::new(),
            is_closure: false,
            owned_params: Vec::new(),
            owned_drop_ty: Vec::new(),
            body,
        });
    }
    out
}

/// For each function, the `data` type of each droppable (owned `%1` parameters +
/// results of `Make*`/calls that return heap). Feeds the deep-drop.
/// The `data`-type name a value carries for deep-drop routing: the Phase A′
/// annotation attached to the node that creates the value (`Make*`/call result)
/// or, for owned `%1` parameters, resolved on the function at lowering.
/// `None` = unknown/non-boxed → the backend emits a flat `free` (conservative).
fn build_all_drop_ty(fns: &[CoreFn]) -> HashMap<String, HashMap<String, Option<String>>> {
    let mut out = HashMap::new();
    for f in fns {
        let mut dty: HashMap<String, Option<String>> = f.owned_drop_ty.iter().cloned().collect();
        collect_drop_types(&f.body, &mut dty);
        out.insert(f.name.clone(), dty);
    }
    out
}

/// The Phase A′ drop-type annotation of a value-producing `Op`: the `data`-type
/// name attached at lowering (`MakeCon`/`MakeRecord` from the constructor's
/// declaration, `CallDirect` from the callee's signature). `None` = unknown or
/// non-boxed → the backend emits a flat `free` (conservative).
impl Op {
    fn drop_ty(&self) -> Option<String> {
        match self {
            Op::MakeRecord { ty, .. } | Op::MakeCon { ty, .. } => ty.clone(),
            Op::CallDirect(_, _, ty) => ty.clone(),
            Op::RtCall { func, .. } if func == "axion_array_new" => Some("Array".into()),
            // §9 parMap returns an owned `List` of the workers' replies — reclaimed by
            // the generic `axion_drop_List` (flat cons-cell free), like `replicate`'s
            // polymorphic-List result. LIMITATION: scalar replies (Int/Float) reclaim
            // exactly, but heap reply payloads (List/record) leak — same as any
            // polymorphic `List`. Fix when needed: thread the inferred reply type here
            // and key `List$<elem>` so the existing `axion_drop_List$T` mono-destructor
            // deep-drops the elements. See docs/by-example.md §11b.
            Op::RtCall { func, .. } if func == "axion_par_map" => Some("List".into()),
            Op::ArrayNew { elem_ty, .. } => elem_ty
                .clone()
                .map(|et| format!("Array${et}"))
                .or_else(|| Some("Array".into())),
            _ => None,
        }
    }
}

/// Records the `data` type of variables bound to `Make*`/heap-calls in `t` —
/// now a plain READ of the Phase A′ annotation on each node (no reconstruction).
/// (Results of `if`/`case` bound to `let` are not typed — they get a flat
/// `free`; conservative, safe — see docs/backend.md.)
fn collect_drop_types(t: &Term, out: &mut HashMap<String, Option<String>>) {
    match t {
        Term::Let(x, rhs, _, body) => {
            if let Rhs::Op(op) = rhs {
                let ty = op.drop_ty();
                if ty.is_some() {
                    out.insert(x.clone(), ty);
                }
            }
            collect_rhs_drop_types(rhs, out);
            collect_drop_types(body, out);
        }
        Term::Drop(_, _, _, _, body) => collect_drop_types(body, out),
        Term::Ret(rhs, _) => collect_rhs_drop_types(rhs, out),
    }
}

fn collect_rhs_drop_types(rhs: &Rhs, out: &mut HashMap<String, Option<String>>) {
    match rhs {
        Rhs::Op(_) => {}
        Rhs::If(_, th, el) => {
            collect_drop_types(th, out);
            collect_drop_types(el, out);
        }
        Rhs::Case(_, arms) => {
            for (_, b) in arms {
                collect_drop_types(b, out);
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
pub type BorrowArgs = HashMap<String, HashSet<usize>>;

pub fn atom_is(v: &str, a: &Atom) -> bool {
    matches!(a, Atom::Var(n) if n == v)
}

/// `true` if `v` appears in some position that is **not** a local read inside
/// of `t` — i.e. it escapes the callee (returned, embedded, aliased, or passed to
/// a call). A `Many` parameter for which this is `false` is a pure borrow.
fn occurs_nonborrow(v: &str, t: &Term) -> bool {
    match t {
        Term::Let(_, rhs, _, body) => rhs_nonborrow(v, rhs) || occurs_nonborrow(v, body),
        Term::Drop(_, _, _, _, body) => occurs_nonborrow(v, body),
        Term::Ret(rhs, _) => rhs_nonborrow(v, rhs),
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
        Op::CallDirect(_, xs, _) | Op::CallClosure(_, xs) => xs.iter().any(|a| atom_is(v, a)),
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
        Op::ArrayNew { .. } => false,
        Op::Unsupported(_) => false,
    }
}

/// Parameter indices of a prelude function whose RESULT shares cells with the
/// parameter (a "view" — `drop n xs` returns the input's tail from the
/// `n < 1` arm). A view parameter is never a pure borrow: the call moves it
/// (the caller relinquishes the value, so the reclamation side never frees
/// it) and the RESULT's destructor reclaims the shared suffix, while cells
/// the result never reaches (the dropped prefix) leak conservatively. This
/// mirrors how `append`'s second list already behaves — its `ys` param
/// appears in the recursive call, so `occurs_nonborrow` already moves it.
fn view_params(name: &str) -> &'static [usize] {
    match name {
        "drop" => &[1],
        _ => &[],
    }
}

// --- uniquify: alpha-rename shadowed local bindings (unique-binding invariant) ---
//
// Runs right after lowering, before every reclamation analysis. Shadow-only: a
// binding keeps its readable source name unless it shadows one already in scope,
// in which case it gets a fresh `name$N` (the lexer forbids `$`, so no collision).
// Uses are substituted consistently; `if`/`case` branches get their own scope
// (a cloned env), so a binding in one arm never leaks to a sibling.

fn uniquify_fn(f: &mut CoreFn) {
    // params and closure captures are the function's interface — kept as-is and
    // seeded so a local that shadows a param is renamed.
    let mut env: HashMap<String, String> =
        f.params.iter().map(|p| (p.clone(), p.clone())).collect();
    for c in &f.captures {
        env.insert(c.clone(), c.clone());
    }
    let mut ctr = 0u32;
    uq_term(&mut f.body, &mut env, &mut ctr);
}

/// Renames the binder `x` (in place) to a fresh `x$N` iff it shadows a name
/// already in scope, and records the mapping so later uses resolve to it.
fn uq_bind(x: &mut String, env: &mut HashMap<String, String>, ctr: &mut u32) {
    let x2 = if env.contains_key(x.as_str()) {
        *ctr += 1;
        format!("{x}${ctr}")
    } else {
        x.clone()
    };
    env.insert(x.clone(), x2.clone());
    *x = x2;
}

fn uq_atom(a: &mut Atom, env: &HashMap<String, String>) {
    if let Atom::Var(v) = a {
        if let Some(n) = env.get(v) {
            v.clone_from(n);
        }
    }
}

fn uq_term(t: &mut Term, env: &mut HashMap<String, String>, ctr: &mut u32) {
    match t {
        Term::Let(x, rhs, _, body) => {
            // the rhs is evaluated BEFORE `x` is bound (ANF), so rename its uses
            // under the outer scope, then bind `x`, then descend into the body.
            uq_rhs(rhs, env, ctr);
            uq_bind(x, env, ctr);
            uq_term(body, env, ctr);
        }
        Term::Drop(v, _, _, _, body) => {
            // no Drop nodes exist yet at uniquify time, but handle them for safety.
            if let Some(n) = env.get(v) {
                v.clone_from(n);
            }
            uq_term(body, env, ctr);
        }
        Term::Ret(rhs, _) => uq_rhs(rhs, env, ctr),
    }
}

fn uq_rhs(rhs: &mut Rhs, env: &mut HashMap<String, String>, ctr: &mut u32) {
    match rhs {
        Rhs::Op(op) => uq_op(op, env),
        Rhs::If(c, t, e) => {
            uq_atom(c, env);
            let mut te = env.clone();
            uq_term(t, &mut te, ctr);
            let mut ee = env.clone();
            uq_term(e, &mut ee, ctr);
        }
        Rhs::Case(s, arms) => {
            uq_atom(s, env);
            for (pat, body) in arms.iter_mut() {
                let mut ae = env.clone();
                uq_pat(pat, &mut ae, ctr);
                uq_term(body, &mut ae, ctr);
            }
        }
    }
}

fn uq_pat(pat: &mut CPat, env: &mut HashMap<String, String>, ctr: &mut u32) {
    match pat {
        CPat::Var(x) => uq_bind(x, env, ctr),
        CPat::Con(_, subs) | CPat::Tuple(subs) => {
            subs.iter_mut().for_each(|p| uq_pat(p, env, ctr));
        }
        CPat::Int(_) | CPat::Wild => {}
    }
}

/// Renames every variable OPERAND of `op` (exhaustive, so a new `Op` variant
/// forces a decision here rather than silently escaping the renaming).
fn uq_op(op: &mut Op, env: &HashMap<String, String>) {
    match op {
        Op::Atom(a)
        | Op::IntToFloat(a)
        | Op::FloatToInt(a)
        | Op::FloatUnary(_, a)
        | Op::Field { rec: a, .. }
        | Op::LoadRaw(a, _)
        | Op::PutStrLn(a)
        | Op::PutStr(a)
        | Op::ShowInt(a)
        | Op::ArenaAlloc(a)
        | Op::ArenaMark(a)
        | Op::ArenaRelease(a) => uq_atom(a, env),
        Op::Prim(_, a, b) | Op::PrimF(_, a, b) | Op::StoreRaw(a, _, b) | Op::Promote(a, b) => {
            uq_atom(a, env);
            uq_atom(b, env);
        }
        Op::CallDirect(_, xs, _)
        | Op::MakeTuple(xs)
        | Op::MakeCon { args: xs, .. }
        | Op::RtCall { args: xs, .. }
        | Op::Ffi { args: xs, .. }
        | Op::MakeClosure { captures: xs, .. } => xs.iter_mut().for_each(|a| uq_atom(a, env)),
        Op::CallClosure(f, xs) => {
            uq_atom(f, env);
            xs.iter_mut().for_each(|a| uq_atom(a, env));
        }
        Op::MakeRecord { fields, .. } => fields.iter_mut().for_each(|(_, a)| uq_atom(a, env)),
        Op::UpdateRecord { base, fields, .. } => {
            uq_atom(base, env);
            fields.iter_mut().for_each(|(_, a)| uq_atom(a, env));
        }
        Op::WithArena { parent, clos } => {
            if let Some(p) = parent {
                uq_atom(p, env);
            }
            uq_atom(clos, env);
        }
        Op::ArrayNew { len, init, .. } => {
            uq_atom(len, env);
            uq_atom(init, env);
        }
        Op::FuncAddr(_) | Op::Unsupported(_) => {}
    }
}

// --- collapse trivial single-var `case` bindings into substitutions ---

/// `case (Var s) of a -> body` → `body` with every use of `a` renamed to `s`.
/// Recurses so nested binds collapse too. Only a single Var-pattern arm over a
/// variable scrutinee qualifies (an already-forced value that the arm merely
/// re-binds); everything else is traversed unchanged.
fn collapse_var_cases(t: Term) -> Term {
    match t {
        Term::Let(x, Rhs::Case(Atom::Var(s), arms), sp, body)
            if matches!(arms.as_slice(), [(CPat::Var(_), _)]) =>
        {
            let (a, inner) = single_var_arm(arms);
            let inner = renamed(inner, &a, &s);
            splice_value(collapse_var_cases(inner), x, sp, collapse_var_cases(*body))
        }
        Term::Ret(Rhs::Case(Atom::Var(s), arms), _)
            if matches!(arms.as_slice(), [(CPat::Var(_), _)]) =>
        {
            let (a, inner) = single_var_arm(arms);
            collapse_var_cases(renamed(inner, &a, &s))
        }
        Term::Let(x, rhs, sp, body) => Term::Let(
            x,
            collapse_rhs(rhs),
            sp,
            Box::new(collapse_var_cases(*body)),
        ),
        Term::Drop(v, ty, a, sp, body) => {
            Term::Drop(v, ty, a, sp, Box::new(collapse_var_cases(*body)))
        }
        Term::Ret(rhs, sp) => Term::Ret(collapse_rhs(rhs), sp),
    }
}

fn collapse_rhs(rhs: Rhs) -> Rhs {
    match rhs {
        Rhs::Op(op) => Rhs::Op(op),
        Rhs::If(c, t, e) => Rhs::If(
            c,
            Box::new(collapse_var_cases(*t)),
            Box::new(collapse_var_cases(*e)),
        ),
        Rhs::Case(s, arms) => Rhs::Case(
            s,
            arms.into_iter()
                .map(|(p, b)| (p, collapse_var_cases(b)))
                .collect(),
        ),
    }
}

/// The (var name, arm body) of a `[(CPat::Var(a), body)]` arm list.
fn single_var_arm(arms: Vec<(CPat, Term)>) -> (String, Term) {
    match arms.into_iter().next() {
        Some((CPat::Var(a), body)) => (a, body),
        _ => unreachable!("caller guards a single CPat::Var arm"),
    }
}

/// Renames every USE of `from` to `to` in `t` (bindings are untouched — after
/// uniquify names are distinct, so `from` is never re-bound inside `t`).
fn renamed(mut t: Term, from: &str, to: &str) -> Term {
    let env: HashMap<String, String> =
        std::iter::once((from.to_string(), to.to_string())).collect();
    rename_term(&mut t, &env);
    t
}

fn rename_term(t: &mut Term, env: &HashMap<String, String>) {
    match t {
        Term::Let(_, rhs, _, body) => {
            rename_rhs(rhs, env);
            rename_term(body, env);
        }
        Term::Drop(v, _, _, _, body) => {
            if let Some(n) = env.get(v) {
                v.clone_from(n);
            }
            rename_term(body, env);
        }
        Term::Ret(rhs, _) => rename_rhs(rhs, env),
    }
}

fn rename_rhs(rhs: &mut Rhs, env: &HashMap<String, String>) {
    match rhs {
        Rhs::Op(op) => uq_op(op, env),
        Rhs::If(c, t, e) => {
            uq_atom(c, env);
            rename_term(t, env);
            rename_term(e, env);
        }
        Rhs::Case(s, arms) => {
            uq_atom(s, env);
            for (_, b) in arms.iter_mut() {
                rename_term(b, env);
            }
        }
    }
}

/// Splices `inner` (a Term producing a value) so its result is bound to `x`,
/// followed by `cont`: each tail `Ret(rhs)` becomes `Let(x, rhs, cont)`.
fn splice_value(inner: Term, x: String, sp: Span, cont: Term) -> Term {
    match inner {
        Term::Ret(rhs, _) => Term::Let(x, rhs, sp, Box::new(cont)),
        Term::Let(y, rhs, s, body) => {
            Term::Let(y, rhs, s, Box::new(splice_value(*body, x, sp, cont)))
        }
        Term::Drop(v, ty, a, s, body) => {
            Term::Drop(v, ty, a, s, Box::new(splice_value(*body, x, sp, cont)))
        }
    }
}

/// Computes the pure borrows of each top-level function (those with a signature,
/// logo multiplicidade conhecida). Ver [`BorrowArgs`].
///
/// GREATEST FIXPOINT. Whether a use `g a` moves `a` depends on whether `g`'s
/// parameter is itself a borrow — a chicken-and-egg for (mutual) recursion. So
/// start by assuming EVERY `%1`-free param is borrowed, then drop any param with a
/// genuine move/alias use under the current assumptions, until stable. A read-only
/// recursive traversal (`sumArr a … sumArr a …`) converges to borrowed, so its
/// caller keeps ownership and frees it exactly once.
fn compute_borrow_args(
    fns: &[CoreFn],
    param_mults: &HashMap<String, Vec<ast::Mult>>,
) -> BorrowArgs {
    let mut ba: BorrowArgs = HashMap::new();
    for f in fns {
        let Some(mults) = param_mults.get(&f.name) else {
            continue;
        };
        let set: HashSet<usize> = (0..f.params.len())
            .filter(|&i| {
                mults.get(i) != Some(&ast::Mult::One) && !view_params(&f.name).contains(&i)
            })
            .collect();
        if !set.is_empty() {
            ba.insert(f.name.clone(), set);
        }
    }
    loop {
        let mut changed = false;
        for f in fns {
            let Some(idxs) = ba.get(&f.name).cloned() else {
                continue;
            };
            let keep: HashSet<usize> = idxs
                .iter()
                .copied()
                .filter(|&i| !body_moves(&f.params[i], &f.body, &ba))
                .collect();
            if keep.len() != idxs.len() {
                changed = true;
                if keep.is_empty() {
                    ba.remove(&f.name);
                } else {
                    ba.insert(f.name.clone(), keep);
                }
            }
        }
        if !changed {
            break;
        }
    }
    ba
}

/// `true` if `v` appears in a MOVE or ALIAS position anywhere in `t`, under the
/// current borrow assumptions `ba`. Mirrors [`occurs_nonborrow`] (so it inherits
/// the copy-vs-inplace `UpdateRecord` distinction, etc.) but with two refinements
/// the fixpoint needs: a `CallDirect` arg at a currently-borrowed position is a
/// READ, not a move (lets a self-recursive borrow converge); and `axion_array_get`
/// /`_len` BORROW their array (arg 0) — a read-only traversal does not consume it.
fn body_moves(v: &str, t: &Term, ba: &BorrowArgs) -> bool {
    match t {
        Term::Let(_, rhs, _, body) => rhs_moves(v, rhs, ba) || body_moves(v, body, ba),
        Term::Drop(_, _, _, _, body) => body_moves(v, body, ba),
        Term::Ret(rhs, _) => rhs_moves(v, rhs, ba),
    }
}

fn rhs_moves(v: &str, rhs: &Rhs, ba: &BorrowArgs) -> bool {
    match rhs {
        Rhs::Op(op) => op_moves(v, op, ba),
        // `if`/`case` heads are local reads (borrows) → only the branches move.
        Rhs::If(_, t, e) => body_moves(v, t, ba) || body_moves(v, e, ba),
        Rhs::Case(_, arms) => arms.iter().any(|(_, b)| body_moves(v, b, ba)),
    }
}

fn op_moves(v: &str, op: &Op, ba: &BorrowArgs) -> bool {
    match op {
        // ba-aware: an arg at a borrowed position is a read, not a move.
        Op::CallDirect(g, xs, _) => {
            let bs = ba.get(g);
            xs.iter()
                .enumerate()
                .any(|(i, a)| !bs.is_some_and(|s| s.contains(&i)) && atom_is(v, a))
        }
        // read-only array access borrows the array (arg 0); the rest are inert Ints.
        Op::RtCall { func, args, .. } if func == "axion_array_get" || func == "axion_array_len" => {
            args.iter()
                .enumerate()
                .any(|(i, a)| i != 0 && atom_is(v, a))
        }
        // --- the rest mirrors `occurs_nonborrow`'s `op_nonborrow` exactly ---
        Op::Field { .. }
        | Op::FuncAddr(_)
        | Op::LoadRaw(..)
        | Op::ArrayNew { .. }
        | Op::Unsupported(_) => false,
        Op::Atom(a)
        | Op::IntToFloat(a)
        | Op::FloatToInt(a)
        | Op::FloatUnary(_, a)
        | Op::PutStrLn(a)
        | Op::PutStr(a)
        | Op::ShowInt(a)
        | Op::ArenaAlloc(a)
        | Op::ArenaMark(a)
        | Op::ArenaRelease(a) => atom_is(v, a),
        Op::StoreRaw(a, _, b) | Op::Prim(_, a, b) | Op::PrimF(_, a, b) | Op::Promote(a, b) => {
            atom_is(v, a) || atom_is(v, b)
        }
        Op::CallClosure(_, xs)
        | Op::MakeTuple(xs)
        | Op::MakeCon { args: xs, .. }
        | Op::RtCall { args: xs, .. }
        | Op::Ffi { args: xs, .. }
        | Op::MakeClosure { captures: xs, .. } => xs.iter().any(|a| atom_is(v, a)),
        Op::MakeRecord { fields, .. } => fields.iter().any(|(_, a)| atom_is(v, a)),
        Op::UpdateRecord {
            base,
            fields,
            inplace,
        } => (*inplace && atom_is(v, base)) || fields.iter().any(|(_, a)| atom_is(v, a)),
        Op::WithArena { parent, clos } => parent.iter().any(|a| atom_is(v, a)) || atom_is(v, clos),
    }
}

/// Use of an atom, if it is a **free** droppable variable (not bound by a
/// `let` within the term being analyzed). Excluding the locally-bound ones is essential
/// for branch balancing: a droppable bound inside a branch is local to
/// that branch and cannot be freed in the sibling branch (where it doesn't exist).
pub fn atom_use(
    a: &Atom,
    drp: &HashSet<String>,
    bound: &HashSet<String>,
    out: &mut HashSet<String>,
) {
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
        Term::Let(x, rhs, _, body) => {
            fv_rhs_in(rhs, drp, ba, bound, out);
            // `x` is bound in the body — its mentions there are not free
            let fresh = bound.insert(x.clone());
            fv_drop_in(body, drp, ba, bound, out);
            if fresh {
                bound.remove(x);
            }
        }
        Term::Drop(_, _, _, _, body) => fv_drop_in(body, drp, ba, bound, out),
        Term::Ret(rhs, _) => fv_rhs_in(rhs, drp, ba, bound, out),
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
    // the BORROW positions of the single authority: `Field` reads a droppable
    // (the record), the closure passed to `withArena` is used during the call
    // and dies after, and a direct call's pure-borrow parameters are freed by
    // the caller after the call — each counts as a use, so the drop falls
    // AFTER. The remaining positions move (escape) → the droppable doesn't
    // appear there. Prim operates on Ints.
    let e = crate::delta::op_delta_effect(op, ba);
    for a in &e.borrows {
        atom_use(a, drp, bound, out);
    }
}

/// The droppable set of a function: objects it **owns** — allocated
/// locally (the Phase A′ annotation on `Make*`/heap-returning calls),
/// and its `%1` heap parameters — minus those that escape.
fn droppable_vars(f: &CoreFn, ba: &BorrowArgs) -> HashSet<String> {
    let mut allocated: HashSet<String> = f.owned_params.iter().cloned().collect();
    let mut escaped = HashSet::new();
    scan_body(&f.body, ba, &mut allocated, &mut escaped);
    allocated.difference(&escaped).cloned().collect()
}

fn scan_body(t: &Term, ba: &BorrowArgs, alloc: &mut HashSet<String>, esc: &mut HashSet<String>) {
    let recur = |b, alloc: &mut HashSet<String>, esc: &mut HashSet<String>| {
        scan_body(b, ba, alloc, esc);
    };
    match t {
        Term::Let(x, rhs, _, body) => {
            match rhs {
                Rhs::Op(op) => {
                    // local allocation (Phase A′ annotation, or an always-heap op)
                    if op_produces_heap(op) {
                        alloc.insert(x.clone());
                    }
                    scan_op_escapes(op, ba, esc);
                }
                Rhs::If(_, t2, e2) => {
                    recur(t2, alloc, esc);
                    recur(e2, alloc, esc);
                }
                Rhs::Case(_, arms) => arms.iter().for_each(|(_, b)| recur(b, alloc, esc)),
            }
            recur(body, alloc, esc);
        }
        Term::Drop(_, _, _, _, body) => recur(body, alloc, esc),
        Term::Ret(rhs, _) => match rhs {
            Rhs::Op(op) => scan_op_escapes(op, ba, esc),
            Rhs::If(_, t2, e2) => {
                recur(t2, alloc, esc);
                recur(e2, alloc, esc);
            }
            Rhs::Case(_, arms) => arms.iter().for_each(|(_, b)| recur(b, alloc, esc)),
        },
    }
}

/// `true` if the op's result is a heap object the caller owns. The Phase A′
/// annotation (`MakeCon`/`MakeRecord`/`CallDirect`) carries the allocation
/// decision from lowering; the un-annotated always-heap ops are the rest.
/// Δ-3: reads the single authority (`delta::op_delta_effect.produces`).
fn op_produces_heap(op: &Op) -> bool {
    crate::delta::op_delta_effect(op, &BorrowArgs::new())
        .produces
        .is_some()
}

/// Names of variables that escape by appearing in an owner position
/// (argumento de chamada, embebimento noutro objecto, alias directo).
/// Δ-3: the move/alias positions come from the single authority
/// (`delta::op_delta_effect`); the arena operands are a reclamation-side
/// caveat — arena-managed objects are freed by the arena reset, not by
/// Auto-Drop (the Δ judgment borrows them; only `sess$*` code has them, and
/// Δ skips those by name).
fn scan_op_escapes(op: &Op, ba: &BorrowArgs, esc: &mut HashSet<String>) {
    let mut mark = |a: &Atom| {
        if let Atom::Var(n) = a {
            esc.insert(n.clone());
        }
    };
    let e = crate::delta::op_delta_effect(op, ba);
    for a in &e.moves {
        mark(a);
    }
    if let Some(a) = e.alias {
        mark(a); // alias directo `let y = x`
    }
    if let Some(a) = e.nonstrict {
        mark(a); // the receiving closure of an indirect call changes hands
    }
    match op {
        // arenas: arena/cell/closure objects are managed by the arena reset —
        // they are marked as escape to ignore them (see the Δ-3 note above)
        Op::WithArena { parent, .. } => parent.iter().for_each(&mut mark),
        Op::ArenaAlloc(a) | Op::ArenaMark(a) | Op::ArenaRelease(a) => mark(a),
        Op::Promote(t, c) => {
            mark(t);
            mark(c);
        }
        _ => {}
    }
}

/// Inserts the `drop`s into a function (structural Drop + cross-function reclamation).
/// `drop_ty` maps each droppable to its `data`-type name (for the deep-drop).
fn insert_drops(
    mut f: CoreFn,
    ba: &BorrowArgs,
    drop_ty: &HashMap<String, Option<String>>,
    recinfo: &RecordInfo,
) -> (CoreFn, Vec<(String, Vec<usize>)>) {
    let drp = droppable_vars(&f, ba);
    if drp.is_empty() {
        return (f, Vec::new());
    }
    let mut e = Elab {
        drp,
        tmp: 1_000_000,
        ba,
        drop_ty,
        recinfo,
        skip_seeds: Vec::new(),
    };
    let body = std::mem::replace(
        &mut f.body,
        Term::Ret(Rhs::Op(Op::Atom(Atom::Int(0))), NO_SPAN),
    );
    f.body = e.go(body, &HashSet::new());
    (f, e.skip_seeds)
}

struct Elab<'a> {
    drp: HashSet<String>,
    tmp: u32,
    ba: &'a BorrowArgs,
    drop_ty: &'a HashMap<String, Option<String>>,
    recinfo: &'a RecordInfo,
    /// F-3 skip-variant destructors to generate: `(type_key, skip_slots)`.
    /// Populated by `case_arms` for each remainder drop.
    skip_seeds: Vec<(String, Vec<usize>)>,
}

/// `true` if any tail exit of `t` yields a value that could be a HEAP pointer
/// (as opposed to a proven scalar: Int/Bool/Float, an enum immediate, a
/// unit-returning effect, or a read of a non-heap field). Conservative: anything
/// not provably scalar counts as heap. Used to decide whether a deep drop of the
/// scrutinee is safe — a heap result may ALIAS into the scrutinee's payload (e.g.
/// `case xs of Cons y ys -> inner y`, returning a heap sub-object of the borrowed
/// `y`), and deep-dropping the scrutinee would then free a value that escapes.
fn result_may_be_heap(t: &Term, recinfo: &RecordInfo) -> bool {
    match t {
        Term::Ret(rhs, _) => match rhs {
            Rhs::Op(op) => op_result_may_be_heap(op, recinfo),
            Rhs::If(_, th, el) => {
                result_may_be_heap(th, recinfo) || result_may_be_heap(el, recinfo)
            }
            Rhs::Case(_, arms) => arms.iter().any(|(_, b)| result_may_be_heap(b, recinfo)),
        },
        Term::Let(_, _, _, body) | Term::Drop(_, _, _, _, body) => {
            result_may_be_heap(body, recinfo)
        }
    }
}

/// `true` if any variable in `set` appears as an operand of `op`. Exhaustive
/// (no wildcard) so a newly-added `Op` variant forces a decision here rather than
/// silently escaping the payload-alias analysis.
fn op_mentions_any(op: &Op, set: &HashSet<String>) -> bool {
    let hit = |at: &Atom| matches!(at, Atom::Var(v) if set.contains(v));
    match op {
        Op::Atom(x)
        | Op::IntToFloat(x)
        | Op::FloatToInt(x)
        | Op::FloatUnary(_, x)
        | Op::Field { rec: x, .. }
        | Op::LoadRaw(x, _)
        | Op::PutStrLn(x)
        | Op::PutStr(x)
        | Op::ShowInt(x)
        | Op::ArenaAlloc(x)
        | Op::ArenaMark(x)
        | Op::ArenaRelease(x) => hit(x),
        Op::Prim(_, x, y) | Op::PrimF(_, x, y) | Op::StoreRaw(x, _, y) | Op::Promote(x, y) => {
            hit(x) || hit(y)
        }
        Op::CallDirect(_, xs, _)
        | Op::MakeTuple(xs)
        | Op::MakeCon { args: xs, .. }
        | Op::RtCall { args: xs, .. }
        | Op::Ffi { args: xs, .. }
        | Op::MakeClosure { captures: xs, .. } => xs.iter().any(hit),
        Op::CallClosure(f, xs) => hit(f) || xs.iter().any(hit),
        Op::MakeRecord { fields, .. } => fields.iter().any(|(_, x)| hit(x)),
        Op::UpdateRecord { base, fields, .. } => hit(base) || fields.iter().any(|(_, x)| hit(x)),
        Op::WithArena { parent, clos } => parent.as_ref().is_some_and(hit) || hit(clos),
        Op::ArrayNew { len, init, .. } => hit(len) || hit(init),
        Op::FuncAddr(_) | Op::Unsupported(_) => false,
    }
}

/// `true` if any variable in `set` is referenced anywhere in `t`.
fn term_mentions_any(t: &Term, set: &HashSet<String>) -> bool {
    match t {
        Term::Let(_, rhs, _, body) => rhs_mentions_any(rhs, set) || term_mentions_any(body, set),
        Term::Drop(v, _, _, _, body) => set.contains(v) || term_mentions_any(body, set),
        Term::Ret(rhs, _) => rhs_mentions_any(rhs, set),
    }
}

fn rhs_mentions_any(rhs: &Rhs, set: &HashSet<String>) -> bool {
    let atom_hit = |at: &Atom| matches!(at, Atom::Var(v) if set.contains(v));
    match rhs {
        Rhs::Op(op) => op_mentions_any(op, set),
        Rhs::If(c, th, el) => {
            atom_hit(c) || term_mentions_any(th, set) || term_mentions_any(el, set)
        }
        Rhs::Case(s, arms) => atom_hit(s) || arms.iter().any(|(_, b)| term_mentions_any(b, set)),
    }
}

/// The scalar-proving half of `result_may_be_heap`: returns `false` only for ops
/// whose result is definitely NOT a heap pointer. Default is `true` (heap).
fn op_result_may_be_heap(op: &Op, recinfo: &RecordInfo) -> bool {
    match op {
        // proven scalars (an i64 value, never a pointer into the scrutinee):
        Op::Atom(Atom::Int(_))
        | Op::Prim(..)
        | Op::PrimF(..)
        | Op::IntToFloat(_)
        | Op::FloatToInt(_)
        | Op::FloatUnary(..)
        // effects returning unit; `StoreRaw` evaluates to the (i64) value stored.
        | Op::PutStrLn(_)
        | Op::PutStr(_)
        | Op::StoreRaw(..) => false,
        // a field read is scalar iff the field itself is not a heap object.
        Op::Field { name, .. } => recinfo.named_field_is_heap(name),
        // Phase A′: the lowering annotation decides — `Some` = a boxed `data`
        // value (a pointer); `None` = an unboxed enum immediate (a tagged i64).
        Op::MakeCon { ty, .. } => ty.is_some(),
        // Phase A′: a call is scalar iff the callee's result was not annotated
        // as heap at lowering (borrowed args do not retain, so a scalar result
        // cannot alias the scrutinee).
        Op::CallDirect(_, _, ty) => ty.is_some(),
        // everything else (Atom(Var) of unknown origin, allocations, closures,
        // raw loads, indirect/runtime/FFI calls, arenas) → conservatively heap.
        _ => true,
    }
}

/// `true` if a `case` arm binds a **heap** field of the scrutinee to a variable
/// that is **used** (live) in the arm — i.e. that field's ownership was transferred
/// out. When so, the scrutinee must be freed SHALLOWLY (shell only), not
/// deep-dropped, or the deep-drop would double-free the transferred field
/// (`case xs of Cons y ys -> … ys …`). A field bound-but-unused (or a wildcard)
/// stays owned by the scrutinee, so a deep drop still (correctly) frees it.
/// Replaced by the per-slot `transferred_slots` (F-2 per-field ownership) —
/// kept for the non-`%1`-field residual (polymorphic-drop-plan.md §8).
#[allow(dead_code)]
fn transfers_heap_field(pat: &CPat, body: &Term, recinfo: &RecordInfo) -> bool {
    if let CPat::Con(con, subpats) = pat {
        subpats.iter().enumerate().any(|(i, sp)| {
            let CPat::Var(n) = sp else { return false };
            // a heap field whose binding ESCAPES the arm (is consumed/moved out,
            // not merely borrowed) had its ownership transferred → the scrutinee
            // must be freed shallowly.
            recinfo.field_transfers_heap(con, i) && occurs_nonborrow(n, body)
        })
    } else {
        false
    }
}

/// F-2 (per-field ownership): the `%1`-heap fields whose extraction from a
/// linear scrutinee transferred ownership — their slot left the record.
/// The transfer happens at BINDING time (the extraction itself moves the
/// slot), so ALL `%1`-heap Var binders are transferred.  The binder's
/// reclamation is handled by Auto-Drop (the binder enters `drp`); the
/// remainder only reclaims non-`%1` fields and the shell.
fn transferred_slots(pat: &CPat, recinfo: &RecordInfo) -> HashSet<usize> {
    let mut out = HashSet::new();
    if let CPat::Con(con, subpats) = pat {
        for (i, sp) in subpats.iter().enumerate() {
            if let CPat::Var(_) = sp {
                if recinfo.field_is_owned(con, i) && recinfo.field_transfers_heap(con, i) {
                    out.insert(i);
                }
            }
        }
    }
    out
}

/// `true` if a non-`%1` heap (or poly) field binding ESCAPES the arm —
/// ownership transferred the old way (used in a non-borrowing position).
/// When the transferred slots are `%1` (handled by `transferred_slots`),
/// this predicate returns `false` — they are kept separate.
/// Replaced by `ArmInfo::compute` (per-slot precision) — kept for
/// reference.
#[allow(dead_code)]
fn has_non_owning_transfer(pat: &CPat, body: &Term, recinfo: &RecordInfo) -> bool {
    if let CPat::Con(con, subpats) = pat {
        subpats.iter().enumerate().any(|(i, sp)| {
            let CPat::Var(n) = sp else { return false };
            // non-`%1` transfer: the field could be heap/poly but NOT `%1`-heap,
            // AND the binding escapes (non-borrow use).
            recinfo.field_transfers_heap(con, i)
                && !recinfo.field_is_owned(con, i)
                && occurs_nonborrow(n, body)
        })
    } else {
        false
    }
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

    /// Places the deep drop of the scrutinee `s` just before each tail `Ret`.
    /// Every `let`/`drop` in the spine precedes the drop, so any borrowed field
    /// read (`a y`) or payload-aliasing local (`inner y`) is used before `s` is
    /// freed. Only the tail op itself can still read the payload — when it does
    /// (`alias` contains one of its operands) the value is bound first, then `s`
    /// is dropped, then returned; when it does NOT (`ret loop (build …)`), `s` is
    /// dropped BEFORE the tail op, keeping a tail call in tail position (TCO).
    fn place_deep_drop(
        &mut self,
        t: Term,
        s: &str,
        ty: &Option<String>,
        alias: &HashSet<String>,
    ) -> Term {
        // the drop anchors at the node it precedes (Δ-5): the position-level
        // coherence cross-check reads the anchor against the front-end's
        // `DropPoint` span (NO_SPAN anchors are unverifiable).
        let sp = term_span(&t);
        match t {
            Term::Ret(rhs, _) => match rhs {
                Rhs::Op(op) => {
                    if op_mentions_any(&op, alias) {
                        // the tail op reads the payload → compute it, then drop.
                        let tmp = self.fresh();
                        Term::Let(
                            tmp.clone(),
                            Rhs::Op(op),
                            sp,
                            Box::new(Term::Drop(
                                s.to_string(),
                                ty.clone(),
                                Vec::new(),
                                sp,
                                Box::new(Term::Ret(Rhs::Op(Op::Atom(Atom::Var(tmp))), sp)),
                            )),
                        )
                    } else {
                        // independent of the payload → drop first (preserves a
                        // tail call: `drop s; ret f args`).
                        Term::Drop(
                            s.to_string(),
                            ty.clone(),
                            Vec::new(),
                            sp,
                            Box::new(Term::Ret(Rhs::Op(op), sp)),
                        )
                    }
                }
                // the exits live in the branches → recurse into each.
                Rhs::If(c, th, el) => {
                    let th = self.place_deep_drop(*th, s, ty, alias);
                    let el = self.place_deep_drop(*el, s, ty, alias);
                    Term::Ret(Rhs::If(c, Box::new(th), Box::new(el)), sp)
                }
                Rhs::Case(sc, arms) => {
                    let arms = arms
                        .into_iter()
                        .map(|(p, b)| (p, self.place_deep_drop(b, s, ty, alias)))
                        .collect();
                    Term::Ret(Rhs::Case(sc, arms), sp)
                }
            },
            // `let`/`drop` sequence a value into the continuation — not an exit;
            // recurse into the continuation only (the rhs flows into `x`/past it).
            Term::Let(x, rhs, _, body) => Term::Let(
                x,
                rhs,
                sp,
                Box::new(self.place_deep_drop(*body, s, ty, alias)),
            ),
            Term::Drop(v, ty2, _, _, body) => Term::Drop(
                v,
                ty2,
                Vec::new(),
                sp,
                Box::new(self.place_deep_drop(*body, s, ty, alias)),
            ),
        }
    }

    /// The locals that ALIAS the scrutinee's payload: seeded with the scrutinee's
    /// heap/poly field bindings, then closed forward over every `let x = op` whose
    /// `op` may yield a heap pointer AND reads an already-aliasing var (`inner y`,
    /// `getInner y`). A value NOT in this set is a fresh allocation or a scalar
    /// copy, so it survives the deep drop of the scrutinee — the drop may precede
    /// its use. A sound OVER-approximation: unclear ops are counted as aliasing.
    fn collect_payload_aliases(&self, t: &Term, alias: &mut HashSet<String>) {
        match t {
            Term::Let(x, rhs, _, body) => {
                let (heapish, mentions) = match rhs {
                    Rhs::Op(op) => (
                        op_result_may_be_heap(op, self.recinfo),
                        op_mentions_any(op, alias),
                    ),
                    Rhs::If(_, th, el) => {
                        self.collect_payload_aliases(th, alias);
                        self.collect_payload_aliases(el, alias);
                        (
                            result_may_be_heap(th, self.recinfo)
                                || result_may_be_heap(el, self.recinfo),
                            term_mentions_any(th, alias) || term_mentions_any(el, alias),
                        )
                    }
                    Rhs::Case(_, arms) => {
                        for (_, b) in arms {
                            self.collect_payload_aliases(b, alias);
                        }
                        (
                            arms.iter()
                                .any(|(_, b)| result_may_be_heap(b, self.recinfo)),
                            arms.iter().any(|(_, b)| term_mentions_any(b, alias)),
                        )
                    }
                };
                if heapish && mentions {
                    alias.insert(x.clone());
                }
                self.collect_payload_aliases(body, alias);
            }
            Term::Drop(_, _, _, _, body) => self.collect_payload_aliases(body, alias),
            Term::Ret(rhs, _) => match rhs {
                Rhs::Op(_) => {}
                Rhs::If(_, th, el) => {
                    self.collect_payload_aliases(th, alias);
                    self.collect_payload_aliases(el, alias);
                }
                Rhs::Case(_, arms) => {
                    for (_, b) in arms {
                        self.collect_payload_aliases(b, alias);
                    }
                }
            },
        }
    }

    /// Elaborates `t`, freeing the droppable variables at their death point.
    /// `live_out` = droppables live *after* `t` (to be freed by the context
    /// enclosing), which `t` must not free.
    fn go(&mut self, t: Term, live_out: &HashSet<String>) -> Term {
        let sp = term_span(&t);
        match t {
            Term::Drop(v, ty, _, _, body) => {
                let b = self.go(*body, live_out);
                Term::Drop(v, ty, Vec::new(), sp, Box::new(b))
            }
            Term::Ret(rhs, _) => match rhs {
                Rhs::Op(op) => {
                    let mut u = HashSet::new();
                    fv_op(&op, &self.drp, self.ba, &mut u);
                    let dying: Vec<String> =
                        u.into_iter().filter(|v| !live_out.contains(v)).collect();
                    if dying.is_empty() {
                        return Term::Ret(Rhs::Op(op), sp);
                    }
                    // introduces a temporary, frees the dying ones, returns it
                    let tmp = self.fresh();
                    let mut inner = Term::Ret(Rhs::Op(Op::Atom(Atom::Var(tmp.clone()))), sp);
                    for v in dying {
                        let ty = self.dty(&v);
                        inner = Term::Drop(v, ty, Vec::new(), term_span(&inner), Box::new(inner));
                    }
                    Term::Let(tmp, Rhs::Op(op), sp, Box::new(inner))
                }
                Rhs::If(c, th, el) => {
                    let (th2, el2) = self.branches2(*th, *el, live_out);
                    Term::Ret(Rhs::If(c, Box::new(th2), Box::new(el2)), sp)
                }
                Rhs::Case(s, arms) => {
                    let arms2 = self.case_arms(&s, arms, live_out);
                    Term::Ret(Rhs::Case(s, arms2), sp)
                }
            },
            Term::Let(x, rhs, _, body) => match rhs {
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
                        inner = Term::Drop(v, ty, Vec::new(), term_span(&inner), Box::new(inner));
                    }
                    Term::Let(x, Rhs::Op(op), sp, Box::new(inner))
                }
                Rhs::If(c, th, el) => {
                    let mut fvb = HashSet::new();
                    fv_drop(&body, &self.drp, self.ba, &mut fvb);
                    let body2 = self.go(*body, live_out);
                    let mut lo = live_out.clone();
                    lo.extend(fvb);
                    let (th2, el2) = self.branches2(*th, *el, &lo);
                    Term::Let(
                        x,
                        Rhs::If(c, Box::new(th2), Box::new(el2)),
                        sp,
                        Box::new(body2),
                    )
                }
                Rhs::Case(s, arms) => {
                    let mut fvb = HashSet::new();
                    fv_drop(&body, &self.drp, self.ba, &mut fvb);
                    let body2 = self.go(*body, live_out);
                    let mut lo = live_out.clone();
                    lo.extend(fvb);
                    let arms2 = self.case_arms(&s, arms, &lo);
                    Term::Let(x, Rhs::Case(s, arms2), sp, Box::new(body2))
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
                let sp = term_span(&el2);
                el2 = Term::Drop(v.clone(), self.dty(v), Vec::new(), sp, Box::new(el2));
            }
        }
        for v in fel.difference(&fth) {
            if !live_out.contains(v) {
                let sp = term_span(&th2);
                th2 = Term::Drop(v.clone(), self.dty(v), Vec::new(), sp, Box::new(th2));
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
        // --- precomputation (single pass) ---
        let infos: Vec<ArmInfo> = arms
            .iter()
            .map(|(pat, body)| ArmInfo::compute(pat, body, self.recinfo))
            .collect();
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
            let info = &infos[i];

            // make %1-heap binders droppable; collect unused ones for pre-drop
            let mut unused = Vec::new();
            if let CPat::Con(con, subs) = &pat {
                for (fi, sp) in subs.iter().enumerate() {
                    if let CPat::Var(n) = sp {
                        if self.recinfo.field_is_owned(con, fi)
                            && self.recinfo.field_transfers_heap(con, fi)
                        {
                            self.drp.insert(n.clone());
                            if !term_mentions_any(&body, &[n.clone()].into_iter().collect()) {
                                let key =
                                    self.recinfo.field_drop_slot(con, fi).map(|t| t.to_string());
                                unused.push((n.clone(), key));
                            }
                        }
                    }
                }
            }

            let result_heap = result_may_be_heap(&body, self.recinfo);
            // the set of non-`%1` heap field bindings that are actually USED
            // (mentioned) in the arm body.  Only these need alias protection;
            // unused bindings can be safely deep-dropped.
            let mut mentioned_heap: HashSet<String> = HashSet::new();
            if let CPat::Con(con, subs) = &pat {
                for (fi, sp) in subs.iter().enumerate() {
                    if let CPat::Var(n) = sp {
                        if self.recinfo.field_transfers_heap(con, fi)
                            && !self.recinfo.field_is_owned(con, fi)
                            && term_mentions_any(&body, &HashSet::from([n.clone()]))
                        {
                            mentioned_heap.insert(n.clone());
                        }
                    }
                }
            }
            let mut b = self.go(body, live_out);
            for (n, key) in unused {
                b = Term::Drop(n, key, Vec::new(), term_span(&b), Box::new(b));
            }

            if let Some(s) = &scrut_drop {
                let deep_safe = !info.non_owning && !result_heap;
                let decision = scrut_decision(deep_safe, info);
                match decision {
                    ScrutDrop::Remainder { skip } => {
                        let ty = if let CPat::Con(con, _) = &pat {
                            Some(con.clone())
                        } else {
                            self.dty(s)
                        };
                        let sp = term_span(&b);
                        let skip_vec: Vec<usize> = skip.iter().copied().collect();
                        if !skip_vec.is_empty() {
                            if let Some(ty) = &ty {
                                self.skip_seeds.push((ty.clone(), skip_vec.clone()));
                            }
                        }
                        b = Term::Drop(s.clone(), ty, skip_vec, sp, Box::new(b));
                    }
                    ScrutDrop::Deep => {
                        let ty = self.dty(s);
                        let mut alias = HashSet::from([s.clone()]);
                        // only USED heap field bindings start in the alias set;
                        // unused ones are dead and safe to deep-drop.
                        alias.extend(mentioned_heap.iter().cloned());
                        self.collect_payload_aliases(&b, &mut alias);
                        b = self.place_deep_drop(b, s, &ty, &alias);
                    }
                    ScrutDrop::Inline { non_own } => {
                        if let CPat::Con(con, subs) = &pat {
                            b = Self::emit_per_field_drops(b, con, subs, s, non_own, self);
                            b = Term::Drop(s.clone(), None, Vec::new(), term_span(&b), Box::new(b));
                        }
                    }
                    ScrutDrop::Shallow => {
                        // Build the alias set (same as `Deep` path): field bindings
                        // whose heap/poly payload may alias into the arm result.
                        // Skip those from deep-drop; reclaim all other heap fields.
                        let mut alias = HashSet::from([s.clone()]);
                        // only USED heap field bindings start in the alias set;
                        // unused ones are dead and safe to deep-drop.
                        alias.extend(mentioned_heap.iter().cloned());
                        if let CPat::Con(con, subs) = &pat {
                            self.collect_payload_aliases(&b, &mut alias);
                            // compute the skip set: field indices whose binding
                            // name appears in the alias set (the result may
                            // reference them — must NOT deep-drop).
                            let skip: HashSet<usize> = subs
                                .iter()
                                .enumerate()
                                .filter_map(|(fi, sp)| {
                                    if let CPat::Var(n) = sp {
                                        alias.contains(n).then_some(fi)
                                    } else {
                                        None
                                    }
                                })
                                .collect();
                            b = Self::emit_per_field_drops(b, con, subs, s, &skip, self);
                        }
                        b = Term::Drop(s.clone(), None, Vec::new(), term_span(&b), Box::new(b));
                    }
                }
            }

            for v in union.difference(&fvs[i]) {
                if !live_out.contains(v) {
                    let sp = term_span(&b);
                    b = Term::Drop(v.clone(), self.dty(v), Vec::new(), sp, Box::new(b));
                }
            }
            out.push((pat, b));
        }
        out
    }

    /// Emits inline per-field deep drops for non-skipped heap slots of `pat`.
    /// Used for the non-`%1` transfer path (`Inline`) and the now-leak-free
    /// `Shallow` path (empty skip set — all heap fields reclaimed).
    fn emit_per_field_drops(
        mut b: Term,
        con: &str,
        subs: &[CPat],
        s: &str,
        skip: &HashSet<usize>,
        elab: &mut Elab,
    ) -> Term {
        let arity = elab.recinfo.con_arity(con).unwrap_or(0);
        for fi in (0..arity).rev() {
            if !elab.recinfo.field_transfers_heap(con, fi) || skip.contains(&fi) {
                continue;
            }
            let key = elab.recinfo.field_drop_slot(con, fi).map(|t| t.to_string());
            let off = elab.recinfo.field_offset(con, fi);
            if let Some(n) = subs.get(fi).and_then(|sp| {
                if let CPat::Var(n) = sp {
                    Some(n.clone())
                } else {
                    None
                }
            }) {
                b = Term::Drop(n, key, Vec::new(), term_span(&b), Box::new(b));
            } else {
                let tmp = elab.fresh();
                b = Term::Drop(tmp.clone(), key, Vec::new(), term_span(&b), Box::new(b));
                b = Term::Let(
                    tmp,
                    Rhs::Op(Op::LoadRaw(Atom::Var(s.to_string()), off)),
                    term_span(&b),
                    Box::new(b),
                );
            }
        }
        b
    }
}

/// Per-arm precomputed data for `case_arms`.
struct ArmInfo {
    /// `%1`-heap field indices that transferred
    owned: HashSet<usize>,
    /// whether ANY non-`%1` heap/poly field escaped
    non_owning: bool,
    /// indices of non-`%1` heap/poly fields that escaped
    non_owning_slots: HashSet<usize>,
}

impl ArmInfo {
    fn compute(pat: &CPat, body: &Term, recinfo: &RecordInfo) -> ArmInfo {
        let owned = transferred_slots(pat, recinfo);
        let mut non_owning = false;
        let mut non_owning_slots = HashSet::new();
        if let CPat::Con(con, subs) = pat {
            for (fi, sp) in subs.iter().enumerate() {
                if let CPat::Var(n) = sp {
                    if recinfo.field_transfers_heap(con, fi)
                        && !recinfo.field_is_owned(con, fi)
                        && occurs_nonborrow(n, body)
                    {
                        non_owning = true;
                        non_owning_slots.insert(fi);
                    }
                }
            }
        }
        ArmInfo {
            owned,
            non_owning,
            non_owning_slots,
        }
    }
}

/// What kind of scrutinee drop to emit for a `case` arm.
enum ScrutDrop<'a> {
    /// Full destructor (no transferred fields) — `place_deep_drop`
    Deep,
    /// F-3 remainder drop via skip-variant destructor (`Term::Drop` with skip)
    Remainder { skip: &'a HashSet<usize> },
    /// Inline per-field drops + shell free (non-`%1` transfer fallback).
    /// The non-`%1` fields in `non_own` are excluded (transferred out);
    /// all other heap fields are deep-dropped inline before the shell free.
    Inline { non_own: &'a HashSet<usize> },
    /// Inline per-field drops + shell free with empty skip set — same as
    /// `Inline` but nothing was extracted, so all heap fields are reclaimed.
    /// Formerly a flat/shallow free (shell only, payloads leaked).
    Shallow,
}

/// Classifies the scrutinee-drop method for an arm given its precomputed info.
fn scrut_decision(deep_safe: bool, info: &ArmInfo) -> ScrutDrop<'_> {
    if deep_safe {
        if info.owned.is_empty() {
            ScrutDrop::Deep
        } else {
            ScrutDrop::Remainder { skip: &info.owned }
        }
    } else if info.non_owning {
        ScrutDrop::Inline {
            non_own: &info.non_owning_slots,
        }
    } else {
        ScrutDrop::Shallow
    }
}

pub fn indent(n: usize, s: &mut String) {
    for _ in 0..n {
        s.push_str("  ");
    }
}

pub fn dump_op(op: &Op) -> String {
    match op {
        Op::Atom(a) => atom(a),
        Op::StoreRaw(p, off, val) => format!("store {}[{off}] = {}", atom(p), atom(val)),
        Op::FuncAddr(n) => format!("&{n}"),
        Op::Prim(o, a, b) | Op::PrimF(o, a, b) => format!("{o} {} {}", atom(a), atom(b)),
        Op::CallDirect(f, xs, _) => format!("call {f}{}", args(xs)),
        Op::CallClosure(c, xs) => format!("callclo {}{}", atom(c), args(xs)),
        Op::MakeClosure { func, captures } => format!("closure {func}{}", args(captures)),
        Op::MakeTuple(xs) => format!("tuple{}", args(xs)),
        Op::MakeRecord { con, fields, .. } => format!(
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
        Op::MakeCon { con, args, .. } => format!("con {con}{}", self::args(args)),
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
        Op::ArrayNew { len, init, .. } => {
            format!("newArray {} {}", atom(len), atom(init))
        }
        Op::Unsupported(m) => format!("<unsupported: {m}>"),
    }
}

pub fn args(xs: &[Atom]) -> String {
    xs.iter().map(|a| format!(" {}", atom(a))).collect()
}

pub fn atom(a: &Atom) -> String {
    match a {
        Atom::Int(n) => n.to_string(),
        Atom::Float(f) => format!("{f}f"),
        Atom::Str(s) => format!("{s:?}"),
        Atom::Var(n) => n.clone(),
    }
}

pub fn cpat(p: &CPat) -> String {
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
