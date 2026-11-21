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

/// Per-argument descriptor for an FFI call (§18): `float` = passed/returned as an f64 in an FP
/// register (an Axión `Float`, whose runtime i64 is its f64 bit-pattern); `own` = ownership
/// transfers to C (the arg is consumed and Axión must not free it — the `Own T` annotation).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FfiArg {
    pub float: bool,
    pub own: bool,
}

/// What a `foreign` import resolves to at lowering: the `dlsym` C symbol plus the per-arg kinds
/// and result-float flag derived from its (wrapper-stripped) signature.
#[derive(Debug, Clone)]
pub struct ForeignInfo {
    pub symbol: String,
    pub arg_kinds: Vec<FfiArg>,
    pub ret_float: bool,
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
    /// build a closure: lifted function + captured values. `owns`: the captures are fresh copies
    /// the closure MOVES in and its generated destructor (`axion_drop_clo$<func>`) frees — set
    /// for a closure that escapes the scope it is made in (`own_escaping_closures`); otherwise
    /// the closure BORROWS its captures from that scope.
    MakeClosure {
        func: String,
        captures: Vec<Atom>,
        owns: bool,
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
        /// the record's type name (non-parametric records; `None` otherwise) — a by-copy update
        /// makes a fresh value of it, like `MakeRecord { ty }`
        ty: Option<String>,
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
    /// FFI call (§18): the C function `name`, resolved by `dlsym`. Each arg passes as i64
    /// (pointers/handles/Int) or f64 (`Float`, in an FP register) per `arg_kinds`; the result is
    /// i64 unless `ret_float`. `arg_kinds[i].own` marks an arg whose ownership transfers to C.
    Ffi {
        name: String,
        args: Vec<Atom>,
        arg_kinds: Vec<FfiArg>,
        ret_float: bool,
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
            "Int" | "Integer" | "Float" | "Bool" | "String" | "IO" | "Arena" | "Cell" | "Mark"
            | "Buffer" | "Array" | "TritVec" | "I8Array" | "I32Array" | "()" | "U8" | "U16" | "U32"
            | "U64" | "I8" | "I16" | "I32" | "I64" | "Word" | "Byte"
            // `Ptr a` (§18): an opaque, type-safe C handle — a raw i64 pointer, never reclaimed
            // (absent from the heap/drop lists), so functions over `Ptr` lower like any scalar.
            | "Ptr"
            // `Handle a` (§18): a linear FFI resource handle — a raw i64, destroyed via an FFI
            // (never `axion_free`), so like `Ptr` it lowers as a scalar and is not auto-reclaimed.
            | "Handle"
            // `File`: a linear file (an fd, or -errno), closed by `fileClose` — a scalar like `Handle`.
            | "File",
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

/// The `fn_ret_ty` produce key for a function whose RESULT type is `rt`: the reclamation
/// key the caller uses to drop the owned heap value the call returns, or `None` for a
/// non-heap / polymorphic result (no drop needed / no concrete key). A TUPLE keys by its
/// mono tuple key (`tuple$A$B`) so a `case t of (x,y)` destructure reclaims cell + fields;
/// the flat native resources (`Array`/`TritVec`/`I8Array`/`I32Array`) key flat; `String`
/// and `Integer` key by name; a boxed `data` keys by its mono instantiation. Shared by the
/// signature-derived map and the `where`-local merge so both classify results identically.
/// The destructor key of an `Array T`: `Array$K` when `T` is a concrete heap element (the array
/// owns its elements and `axion_drop_Array$K` frees each one), `Array` otherwise (a flat block).
fn array_drop_key(t: &Type, boxed: &HashSet<String>) -> String {
    let (_, a) = ty_head_args(t);
    let heap = a.first().is_some_and(|el| match el {
        Type::Tuple(_) => true,
        _ => {
            matches!(el.head_con(), Some("String" | "Integer"))
                || el.head_con().is_some_and(|h| boxed.contains(h))
        }
    });
    match (heap, mono_key(t)) {
        (true, Some(k)) if !type_has_var_or_fun(t) => k,
        _ => "Array".to_string(),
    }
}

fn ret_ty_key(rt: &Type, boxed: &HashSet<String>) -> Option<String> {
    if matches!(rt, Type::Tuple(_)) {
        return mono_key(rt);
    }
    let h = rt.head_con()?;
    match h {
        "Array" => Some(array_drop_key(rt, boxed)),
        "TritVec" | "I8Array" | "I32Array" | "String" | "Integer" | "Buffer" => Some(h.to_string()),
        _ if boxed.contains(h) => Some(mono_key(rt).unwrap_or_else(|| h.to_string())),
        _ => None,
    }
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

/// BUILT-IN infix operators (`Int` arithmetic/comparison, and the bitwise `.&. .|. xor shiftL
/// shiftR`), which lower to `Op::Prim`. The rest is a user infix operator — a named function
/// applied to two arguments. Matches `interp::is_builtin_op`.
pub fn is_builtin_op(op: &str) -> bool {
    matches!(op, "+" | "-" | "*" | "div" | "mod" | "==" | "<" | ">") || is_bitwise_op(op)
}

/// The bitwise `Int` operators: `.&.` `.|.` `xor` `shiftL` `shiftR` (Haskell's `Data.Bits`
/// names). A shift amount is taken modulo 64 on every backend (`shiftR` is arithmetic).
pub fn is_bitwise_op(op: &str) -> bool {
    matches!(op, ".&." | ".|." | "xor" | "shiftL" | "shiftR")
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

/// The arbitrary-precision runtime function for an Integer `#I` operator (§Listing
/// 1.4), or `None`. Comparisons return a tagged `Bool` immediate.
pub fn integer_op_rt(op: &str) -> Option<&'static str> {
    Some(match op {
        "+#I" => "axion_bignum_add",
        "-#I" => "axion_bignum_sub",
        "*#I" => "axion_bignum_mul",
        "==#I" => "axion_bignum_eq",
        "<#I" => "axion_bignum_lt",
        ">#I" => "axion_bignum_gt",
        "div#I" => "axion_bignum_div",
        "mod#I" => "axion_bignum_mod",
        _ => return None,
    })
}

/// The Int predicate a String comparison marker (`==#str`/`<#str`/`>#str`) reduces
/// to, applied to `axion_str_cmp a b` against `0` (the cmp is -1/0/1). `Some` only
/// for the three String comparisons (§text).
pub fn str_cmp_int_op(op: &str) -> Option<&'static str> {
    Some(match op {
        "==#str" => "==",
        "<#str" => "<",
        ">#str" => ">",
        _ => return None,
    })
}

/// A bignum runtime call that allocates and returns a fresh owned `Integer` (the
/// result the caller must reclaim via `axion_bignum_free`). Comparisons
/// (`eq`/`lt`/`gt`) and `to_string` are NOT producers (they return a scalar/String).
pub fn is_bignum_producer(func: &str) -> bool {
    matches!(
        func,
        "axion_bignum_add"
            | "axion_bignum_sub"
            | "axion_bignum_mul"
            | "axion_bignum_div"
            | "axion_bignum_mod"
            | "axion_bignum_from_i64"
            | "axion_bignum_from_str"
            | "axion_bignum_copy"
    )
}

/// A runtime call that allocates and returns a FRESH owned heap `String` (reclaimed by
/// the tagged `axion_str_drop`). All read (borrow) their operands, so the result never
/// aliases them. The String builtins + the §pass OS capability layer's producers.
pub fn is_string_producer(func: &str) -> bool {
    matches!(
        func,
        "axion_strcat"
            | "axion_show_float"
            | "axion_bignum_to_string"
            | "axion_substr"
            | "axion_getenv"
            | "axion_run"
            | "axion_exec_capture"
            | "axion_read_file"
            | "axion_readdir"
            | "axion_readdir_typed"
            | "axion_readdir_listing"
            | "axion_read_line"
            | "axion_read_secret"
            | "axion_read_key"
            | "axion_read_key_timeout"
            | "axion_chr"
            | "axion_rand_hex"
            | "axion_getargs"
            | "axion_getarg"
    )
}

/// The drop key of a FRESH owned heap value a `let` binding allocates — a String or
/// Integer producer whose result cannot alias its args, so it is safe to reclaim
/// branch-sensitively when it conditionally escapes (`let s = getEnv…; if c then s
/// else "d"` → drop `s` on the `else`). `None` for scalars, in-place setters (a
/// threaded handle, already owned), and calls/getters (may return an interior alias).
fn fresh_let_producer_key(op: &Op) -> Option<String> {
    match op {
        Op::ShowInt(_) => Some("String".into()),
        Op::RtCall { func, .. } if is_string_producer(func) => Some("String".into()),
        Op::RtCall { func, .. } if is_bignum_producer(func) => Some("Integer".into()),
        // a fresh `newBuffer` (freed by `axion_buf_free` under the `Buffer` key)
        Op::RtCall { func, .. } if func == "axion_buf_new" => Some("Buffer".into()),
        _ => None,
    }
}

/// `true` if the op returns a value that CANNOT alias its (heap) operands — a fresh
/// scalar or a freshly-allocated result. Used by `reclaim_cond_escape` to decide whether
/// an owned param stays reclaimable across a binding that reads it: a fresh-producing op
/// (bignum arithmetic/comparison, scalar `Prim`/`PrimF`) is safe; a `Field`/`get`/call may
/// return a pointer INTO the operand (an escaping interior alias), so it is NOT fresh and
/// the param must leave the owned set (else its drop frees a value the alias still uses).
fn op_is_fresh_wrt_args(op: &Op) -> bool {
    match op {
        Op::Prim(..) | Op::PrimF(..) => true,
        // `putStr`/`putStrLn` BORROW their String arg (print it) and return IO unit — the
        // result cannot alias the arg, so an owned operand stays reclaimable across them. This
        // lets an all-heap conditional temp consumed by a print (`putStrLn (if c then a else b)`,
        // the #1 flagship gotcha) be dropped after the print instead of leaking.
        Op::PutStr(..) | Op::PutStrLn(..) => true,
        // Reads its (heap) operands and returns a fresh value that cannot alias them:
        // bignum arith → a fresh `Integer`; a String producer → a fresh copy; a scalar
        // reader (strLen/strCmp/…, §pass capability Int-returners) → a fresh Int.
        Op::RtCall { func, .. } => {
            is_bignum_borrower(func)
                || is_string_producer(func)
                || is_scalar_reader(func)
                // `ePutStr`/`ePutStrLn`: print to stderr, like `putStr`/`putStrLn` above
                || func == "axion_eput"
                || func == "axion_eputs"
        }
        // a generated deep copier (`axion_copy_T`) reads its argument and returns a fresh copy
        Op::CallDirect(g, _, _) if g.starts_with("axion_copy_") => true,
        // A foreign call: C returns a scalar or an opaque handle, never a value Axión owns or a
        // pointer into one in Axión's model (an `Own` argument is a MOVE, which `rhs_moves` sees
        // first) — so a borrowed argument (`creat name 420`) stays reclaimable.
        Op::Ffi { .. } => true,
        _ => false,
    }
}

/// A runtime call whose result is a fresh scalar that READS (borrows) its String/array
/// operands — it cannot alias them, so an owned operand stays reclaimable across it. The
/// String readers (strLen/charAt/strCmp) and the §pass capability Int-returning
/// primitives (subprocess status, filesystem ops, exit).
pub fn is_scalar_reader(func: &str) -> bool {
    matches!(
        func,
        "axion_str_len"
            | "axion_str_at"
            | "axion_poke_u32"
            | "axion_poke_u8"
            | "axion_poke_u16"
            | "axion_poke_u64"
            | "axion_poke_f64"
            | "axion_peek_u8"
            | "axion_peek_u16"
            | "axion_peek_u32"
            | "axion_peek_u64"
            | "axion_peek_f64"
            | "axion_buf_ptr"
            | "axion_buf_ptr_n"
            | "axion_buf_sum"
            | "axion_buf_len"
            | "axion_file_errno"
            | "axion_file_size"
            | "axion_file_open"
            | "axion_file_close"
            | "ax_net_send_buf"
            | "axion_fold_bytes"
            | "axion_str_cmp"
            | "axion_system"
            | "axion_exec_status"
            | "axion_file_exists"
            | "axion_mkdir_p"
            | "axion_unlink"
            | "axion_rename"
            | "axion_exit"
    )
}

/// A bignum runtime call that BORROWS its heap operand(s) (reads without freeing), so
/// the operand stays owned by the caller. The arithmetic/comparison ops (heap `Integer`
/// args) and `from_str` (a `String` arg); NOT `from_i64` (a scalar `Int`). `to_string`
/// also borrows but is handled explicitly alongside the other String producers.
pub fn is_bignum_borrower(func: &str) -> bool {
    matches!(
        func,
        "axion_bignum_add"
            | "axion_bignum_sub"
            | "axion_bignum_mul"
            | "axion_bignum_div"
            | "axion_bignum_mod"
            | "axion_bignum_eq"
            | "axion_bignum_lt"
            | "axion_bignum_gt"
            | "axion_bignum_from_str"
            | "axion_bignum_copy"
    )
}

/// Runtime builtins usable in a session worker's value position (compute between
/// channel ops): name → (runtime function, arity). Mirrors the normal `app`
/// lowering for the builtins that are plain `RtCall`s.
fn sess_builtin_rt(name: &str) -> Option<(&'static str, usize)> {
    Some(match name {
        "fromInt" => ("axion_bignum_from_i64", 1),
        "showInteger" => ("axion_bignum_to_string", 1),
        "divInteger" => ("axion_bignum_div", 2),
        "modInteger" => ("axion_bignum_mod", 2),
        "showFloat" => ("axion_show_float", 1),
        "strAppend" => ("axion_strcat", 2),
        "strLen" => ("axion_str_len", 1),
        "charAt" => ("axion_str_at", 2),
        "pokeU32" => ("axion_poke_u32", 3),
        "pokeU8" => ("axion_poke_u8", 3),
        "pokeU16" => ("axion_poke_u16", 3),
        "pokeU64" => ("axion_poke_u64", 3),
        "pokeF64" => ("axion_poke_f64", 3),
        "peekU8" => ("axion_peek_u8", 2),
        "peekU16" => ("axion_peek_u16", 2),
        "peekU32" => ("axion_peek_u32", 2),
        "peekU64" => ("axion_peek_u64", 2),
        "peekF64" => ("axion_peek_f64", 2),
        "bufPtr" => ("axion_buf_ptr", 1),
        "bufPtrN" => ("axion_buf_ptr_n", 2),
        "strCmp" => ("axion_str_cmp", 2),
        "substr" => ("axion_substr", 3),
        "getEnv" => ("axion_getenv", 1),
        "runCapture" => ("axion_run", 1),
        "runStatus" => ("axion_system", 1),
        "execCapture" => ("axion_exec_capture", 2),
        "execStatus" => ("axion_exec_status", 2),
        "readFile" => ("axion_read_file", 1),
        "fileOpenRaw" => ("axion_file_open", 1),
        "fileErrno" => ("axion_file_errno", 1),
        "fileSize" => ("axion_file_size", 1),
        "fileRead" => ("axion_file_read", 2),
        "fileClose" => ("axion_file_close", 1),
        "bufLen" => ("axion_buf_len", 1),
        "writeFile" => ("axion_write_file", 2),
        "fileExists" => ("axion_file_exists", 1),
        "makeDir" => ("axion_mkdir_p", 1),
        "removeFile" => ("axion_unlink", 1),
        "renameFile" => ("axion_rename", 2),
        "readDir" => ("axion_readdir", 1),
        "readDirTyped" => ("axion_readdir_typed", 1),
        "readDirListing" => ("axion_readdir_listing", 3),
        "readLine" => ("axion_read_line", 1),
        "readSecret" => ("axion_read_secret", 1),
        "readKey" => ("axion_read_key", 1),
        "readKeyTimeout" => ("axion_read_key_timeout", 1),
        "resized" => ("axion_resized", 1),
        "chr" => ("axion_chr", 1),
        "randHex" => ("axion_rand_hex", 1),
        "exitWith" => ("axion_exit", 1),
        "getArgs" => ("axion_getargs", 1),
        "getArg" => ("axion_getarg", 1),
        // async sockets (docs/async-sockets.md): the non-suspending ops, for value/arg position
        // (e.g. `netAccept (netListen p)`). The suspending ops (netRecv/netAccept/netSend) are NOT
        // here on purpose — they must be case-scrutinee suspension points (see gen_netsusp).
        "netConnect" => ("ax_net_connect", 2),
        "netListen" => ("ax_net_listen", 1),
        "netClose" | "netCloseL" => ("ax_net_close", 1),
        _ => return None,
    })
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
    type_arity: HashMap<String, usize>, // type → number of type parameters (`List a` → 1)
    /// constructor → `data`-typed fields it **owns**: (offset, type name).
    /// They are separate allocations that a flat `free` doesn't reclaim → deep-drop.
    con_drop_slots: HashMap<String, Vec<(i32, Type)>>,
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
    /// constructor → (bare-type-var field index → its type-PARAMETER index in the data decl).
    /// `data Either a b = Left a | Right b` → Left{0→0}, Right{0→1}. Lets a poly field be
    /// resolved to the RIGHT argument of a multi-param instantiation's mono key
    /// (`Either$Integer$String` field of `Left` → arg 0 = Integer), not the leaky/unsound
    /// single-param `split_once('$')` assumption (`List$Elem`).
    con_field_param: HashMap<String, HashMap<usize, usize>>,
    /// constructor → field indices declared `%1` (linear — per-field ownership,
    /// docs/per-field-ownership.md): each such slot owns its own linear resource,
    /// so a remainder drop may skip the moved-out ones (`Term::Drop` skip set).
    con_owned_fields: HashMap<String, HashSet<usize>>,
    /// constructor → field indices declared with a plain scalar type (`Int`/`Float`/`Bool`/
    /// `Char`): immediates, never a pointer into the value.
    con_scalar_fields: HashMap<String, HashSet<usize>>,
}

impl RecordInfo {
    pub fn build(module: &ast::Module) -> RecordInfo {
        let mut r = RecordInfo::default();
        // heap fields exclude unboxed enums (immediate tags, not allocations).
        let data_names = boxed_data_names(module);
        for d in &module.datas {
            r.type_arity.insert(d.name.clone(), d.params.len());
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
                let mut field_param: HashMap<usize, usize> = HashMap::new();
                for (i, f) in c.fields.iter().enumerate() {
                    if matches!(f.ty.head_con(), Some("Int" | "Float" | "Bool" | "Char"))
                        && !matches!(f.ty, Type::Arrow { .. } | Type::Tuple(_))
                    {
                        r.con_scalar_fields
                            .entry(c.name.clone())
                            .or_default()
                            .insert(i);
                    }
                    // A heap-owning field is a separate allocation a flat `free` would leave
                    // behind → it must be reclaimed when the record dies (its `drop_way`
                    // picks the right reclaimer: a `data` destructor or the tagged
                    // `axion_str_drop`/`axion_bignum_free`). `String` and `Integer` are heap
                    // (`strAppend`/`substr`/bignum arithmetic allocate), so a constructor that
                    // owns one — `Var String`, `R Integer` — must free it; the tagged string
                    // reclaimer is safe on a static literal too. Bare `Int` and `Buffer` are
                    // left out. A FUNCTION field (`Handler String (Int -> Int)`) is a closure cell:
                    // freed through `axion_closure_drop` (its own destructor, when it owns its
                    // captures). (An extracted field is MOVED out: the container then frees only
                    // the remainder — skip destructors, a shell-free after a `case`, or a copy
                    // where the field is read twice.)
                    if let Type::Arrow { .. } = &f.ty {
                        slots.push((r.field_offset(&c.name, i), f.ty.clone()));
                    } else if let Some(h) = f.ty.head_con() {
                        if data_names.contains(h) || h == "String" || h == "Integer" {
                            // store the FULL field type (not just the head), so the
                            // destructor generator can key a parametric field on its
                            // mono key (`List String` → `axion_drop_List$String`,
                            // which deep-drops the heap elements — the head-only
                            // `axion_drop_List` frees the spine and leaks them).
                            slots.push((r.field_offset(&c.name, i), f.ty.clone()));
                        }
                    } else if let Type::Var(v) = &f.ty {
                        // a bare type variable: possibly-heap once instantiated. Record which
                        // type PARAMETER of the data decl it is, so a multi-param instantiation
                        // resolves the field to the correct mono-key argument.
                        poly.insert(i);
                        if let Some(pi) = d.params.iter().position(|p| p == v) {
                            field_param.insert(i, pi);
                        }
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
                if !field_param.is_empty() {
                    r.con_field_param.insert(c.name.clone(), field_param);
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

    /// For a concrete tuple mono-key (`tuple$Integer$Integer`) of `arity` elements,
    /// the per-element reclamation of a `%1`-consumed tuple: `None` = no drop (a
    /// scalar/unboxed element); `Some(k)` = a `Term::Drop` with key `k` (`k = None` →
    /// a flat `axion_free`, `Some` → the keyed destructor / `axion_bignum_free`).
    /// Returns `None` overall unless the key is a FLAT tuple of `arity` single-token
    /// elements — a nested element (`tuple$List$Int`) makes the `$`-split ambiguous, so
    /// bail to the conservative shell-only free (the prior tuple-discard leak).
    pub fn tuple_elem_drops(&self, key: &str, arity: usize) -> Option<Vec<Option<Option<String>>>> {
        let elems = self.split_tuple_key(key, arity)?;
        Some(
            elems
                .iter()
                .map(|el| self.classify_tuple_elem(el))
                .collect(),
        )
    }

    /// Segments a tuple mono-key (`tuple2$List$Integer$Integer`) into its `arity` element sub-keys
    /// (`["List$Integer", "Integer"]`), using constructor arities (and the arity encoded in each
    /// `tupleN` head) to walk the `$`-joined token stream. A NESTED TUPLE element now segments
    /// unambiguously (`tuple2$tuple2$String$String$tuple2$String$String` → two `tuple2$String$String`
    /// elements), closing the former nested-tuple-in-tuple residual. `None` if the head is not a
    /// `tupleN` of the expected arity, or the stream can't be segmented into exactly `arity` elements.
    pub fn split_tuple_key(&self, key: &str, arity: usize) -> Option<Vec<String>> {
        let mut it = key.split('$');
        let head = it.next()?;
        let enc = head
            .strip_prefix("tuple")
            .and_then(|s| s.parse::<usize>().ok())?;
        if enc != arity {
            return None; // key arity disagrees with the pattern arity — bail (never mis-free)
        }
        let toks: Vec<&str> = it.collect();
        let mut pos = 0usize;
        let mut out = Vec::with_capacity(arity);
        for _ in 0..arity {
            out.push(self.consume_one_key(&toks, &mut pos)?);
        }
        (pos == toks.len()).then_some(out) // leftover tokens ⇒ mis-segmented → bail
    }

    /// Consumes one full mono sub-key from `toks` at `pos`, recursing for a constructor's arguments
    /// (`List` arity 1 → one following sub-key). A `tupleN` token encodes its arity N (see
    /// `mono_key`), so it consumes exactly N sub-keys and recurses — a NESTED tuple anywhere in the
    /// stream now segments unambiguously (the previous arity-less `tuple` token could only be the
    /// final remainder).
    fn consume_one_key(&self, toks: &[&str], pos: &mut usize) -> Option<String> {
        let head = *toks.get(*pos)?;
        *pos += 1;
        if let Some(arity) = head
            .strip_prefix("tuple")
            .and_then(|s| s.parse::<usize>().ok())
        {
            let mut key = head.to_string(); // "tupleN"
            for _ in 0..arity {
                key.push('$');
                key.push_str(&self.consume_one_key(toks, pos)?);
            }
            return Some(key);
        }
        let n = self.type_arity.get(head).copied().unwrap_or(0);
        let mut key = head.to_string();
        for _ in 0..n {
            key.push('$');
            key.push_str(&self.consume_one_key(toks, pos)?);
        }
        Some(key)
    }

    /// Classifies one tuple element mono sub-key for reclamation (see `tuple_elem_drops`). The key
    /// may be MULTI-TOKEN — a nested container instantiation (`List$Integer`) routes to its own
    /// mono destructor (`axion_drop_List$Integer`, seeded alongside the tuple), which frees the
    /// element's payloads too, not just the spine.
    pub fn classify_tuple_elem(&self, el: &str) -> Option<Option<String>> {
        match el {
            "Integer" => Some(Some("Integer".into())), // bignum → axion_bignum_free
            "String" => Some(Some("String".into())),   // heap string → axion_str_drop
            "Closure" => Some(Some("Closure".into())), // closure cell → axion_closure_drop
            _ if el.contains('$') => Some(Some(el.to_string())), // nested container → its mono destructor
            _ if self.needs_deep_drop(el) => Some(Some(el.to_string())), // deep data destructor
            _ if self.enum_types.contains(el) => None,           // unboxed enum immediate → no drop
            _ if self.type_arity.contains_key(el) => Some(None), // boxed data, no heap → flat free
            _ => None,                                           // Int/Float/Bool/unknown → no drop
        }
    }

    /// Splits a container mono-key into (head, per-parameter argument keys) using type arities:
    /// `Either$Integer$String` → ("Either", ["Integer","String"]); `List$tuple$Int$Int` →
    /// ("List", ["tuple$Int$Int"]). Arity 1 takes the whole remainder (so a tuple arg is kept
    /// intact); arity ≥ 2 segments arg-by-arg (bailing `None` on a nested tuple arg, whose arity
    /// is not encoded — conservative). `None` if the key has no `$` (a nullary/scalar type).
    fn split_mono_key(&self, key: &str) -> Option<(String, Vec<String>)> {
        let (head, rest) = key.split_once('$')?;
        let n = self.type_arity.get(head).copied().unwrap_or(0);
        if n <= 1 {
            return Some((head.to_string(), vec![rest.to_string()]));
        }
        let toks: Vec<&str> = rest.split('$').collect();
        let mut pos = 0usize;
        let mut args = Vec::with_capacity(n);
        for _ in 0..n {
            args.push(self.consume_one_key(&toks, &mut pos)?);
        }
        (pos == toks.len()).then_some((head.to_string(), args))
    }

    /// Reclamation for a polymorphic field `fi` of constructor `con`, given the SCRUTINEE's mono
    /// key: resolves the field's own type PARAMETER to the matching argument of the instantiation
    /// (`Left`'s field of `Either$Integer$String` → arg 0 = Integer → `axion_bignum_free`), then
    /// classifies it. Handles MULTI-PARAM types correctly — the old `split_once('$')` took the
    /// whole tail as one element (`Integer$String`), mis-freeing it. Outer `None` = do not make
    /// droppable (unresolved / scalar → never a wrong free); `Some(None)` = flat free; `Some(k)` =
    /// keyed reclaimer.
    /// `true` if polymorphic field `fi` of `con` is, under the scrutinee's instantiation
    /// `scrut_key`, definitely a HEAP value (a keyed container, `String`, a boxed `data` value):
    /// its reclamation is then known, so a missing drop is a leak, not an unresolved type.
    pub fn field_heap_under(&self, con: &str, fi: usize, scrut_key: &str) -> bool {
        self.poly_field_elem_key(con, fi, scrut_key).is_some()
    }

    fn poly_field_elem_key(&self, con: &str, fi: usize, scrut_key: &str) -> Option<Option<String>> {
        let param_idx = *self.con_field_param.get(con)?.get(&fi)?;
        let (_, args) = self.split_mono_key(scrut_key)?;
        let elem = args.get(param_idx)?;
        self.classify_tuple_elem(elem)
    }

    /// `true` if polymorphic field `fi` of `con` is, under the scrutinee's instantiation
    /// `scrut_key`, definitely a SCALAR (`Int`/`Float`/`Bool`/`Char` or an unboxed enum): a value
    /// that is copied, never owned (`Cons y` of a `List$Int`).
    pub fn field_is_scalar_under(&self, con: &str, fi: usize, scrut_key: &str) -> bool {
        let Some(&idx) = self.con_field_param.get(con).and_then(|m| m.get(&fi)) else {
            return false;
        };
        self.split_mono_key(scrut_key)
            .and_then(|(_, args)| args.get(idx).cloned())
            .is_some_and(|e| {
                matches!(e.as_str(), "Int" | "Float" | "Bool" | "Char")
                    || self.enum_types.contains(&e)
            })
    }

    /// The TAGGED reclaimer (`"Integer"` → `axion_bignum_free`, `"String"` → `axion_str_drop`) a
    /// polymorphic field `fi` of `con` resolves to under the scrutinee's instantiation `scrut_key`,
    /// or `None` if it is not definitely one of those. Used by the drop-balance verifier's
    /// drop-key cross-check — freeing such a field with any other key is a bad-free / leak.
    pub fn field_tagged_key(&self, con: &str, fi: usize, scrut_key: &str) -> Option<String> {
        match self.poly_field_elem_key(con, fi, scrut_key) {
            Some(Some(k)) if k == "Integer" || k == "String" || k == "Closure" => Some(k),
            _ => None,
        }
    }

    /// `true` if field `fi` of constructor `con` is declared with a function type (a closure
    /// cell the value owns).
    pub fn field_is_closure(&self, con: &str, fi: usize) -> bool {
        let off = self.field_offset(con, fi);
        self.drop_slots(con)
            .iter()
            .any(|(o, t)| *o == off && matches!(t, Type::Arrow { .. }))
    }

    /// `data`-typed fields a constructor owns: (offset, type name).
    pub fn drop_slots(&self, con: &str) -> &[(i32, Type)] {
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
    /// `true` if a BY-COPY record update with these assignments returns a block that holds no
    /// pointer of its base: every field it does not overwrite is a plain scalar. The base may
    /// then be freed right after the update (it is only read).
    pub fn update_is_fresh(&self, fields: &[(String, Atom)]) -> bool {
        let Some(con) = fields.first().and_then(|(n, _)| self.field_owner.get(n)) else {
            return false;
        };
        let (Some(names), Some(arity)) = (self.con_fields.get(con), self.con_arity(con)) else {
            return false;
        };
        let scalar = self.con_scalar_fields.get(con);
        (0..arity).all(|i| {
            names
                .get(i)
                .is_some_and(|n| fields.iter().any(|(f, _)| f == n))
                || scalar.is_some_and(|s| s.contains(&i))
        })
    }

    /// `true` if the named record field is declared with a plain scalar type: reading it
    /// yields an immediate, never a pointer into the record.
    pub fn named_field_is_scalar(&self, name: &str) -> bool {
        let Some(con) = self.field_owner.get(name) else {
            return false;
        };
        let Some(i) = self
            .con_fields
            .get(con)
            .and_then(|ns| ns.iter().position(|n| n == name))
        else {
            return false;
        };
        self.con_scalar_fields
            .get(con)
            .is_some_and(|s| s.contains(&i))
    }

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

    /// The drop key of field `i` of `con`, if it is a `data`-typed heap field —
    /// the MONO key its deep-drop destructor uses (`List String` →
    /// `List$String`, so extracting/dropping it reclaims the heap elements too).
    pub fn field_drop_slot(&self, con: &str, i: usize) -> Option<String> {
        let off = self.field_offset(con, i);
        self.drop_slots(con)
            .iter()
            .find(|(o, _)| *o == off)
            .and_then(|(_, t)| mono_key(t).or_else(|| t.head_con().map(str::to_string)))
    }

    /// The name of the `data` type a constructor belongs to (`Bar` → `Foo` for
    /// `data Foo = Bar {…}`; for the common single-constructor record they coincide).
    pub fn con_type_name(&self, con: &str) -> Option<&str> {
        self.con_type.get(con).map(String::as_str)
    }

    /// `Some((con, idx))` for the named field `name` (its owning constructor),
    /// or the field's index — used to resolve an `Op::Field` read to its slot.
    pub fn named_field_slot(&self, name: &str) -> Option<(String, usize)> {
        let con = self.field_owner.get(name)?;
        let fields = self.con_fields.get(con)?;
        let idx = fields.iter().position(|f| f == name)?;
        Some((con.clone(), idx))
    }

    /// `true` if a by-copy update of a record setting only `updated` (field names) leaves a HEAP
    /// field of the record unset — a field the result then SHARES with the updated record.
    pub fn update_shares_heap(&self, updated: &[&str]) -> bool {
        let Some(con) = updated.first().and_then(|n| self.field_owner.get(*n)) else {
            return false;
        };
        let set: HashSet<i32> = updated
            .iter()
            .filter_map(|n| self.field(n).map(|(o, _)| o))
            .collect();
        self.drop_slots(con).iter().any(|(o, _)| !set.contains(o))
    }

    /// The field indices a BY-COPY update with these assignments SHARES with its base: every
    /// heap (or type-variable) field it does not overwrite.
    pub fn update_shared_fields(&self, updated: &[&str]) -> Vec<usize> {
        let Some(con) = updated.first().and_then(|n| self.field_owner.get(*n)) else {
            return Vec::new();
        };
        let Some(names) = self.con_fields.get(con) else {
            return Vec::new();
        };
        (0..names.len())
            .filter(|&i| !updated.contains(&names[i].as_str()))
            .filter(|&i| self.field_transfers_heap(con, i))
            .collect()
    }

    /// The indices of the heap (or type-variable) fields of the record these fields belong to.
    pub fn record_heap_fields(&self, some_field: &str) -> HashSet<usize> {
        let Some(con) = self.field_owner.get(some_field) else {
            return HashSet::new();
        };
        let n = self.con_fields.get(con).map_or(0, Vec::len);
        (0..n)
            .filter(|&i| self.field_transfers_heap(con, i))
            .collect()
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
pub fn ty_has_var(t: &Type) -> bool {
    match t {
        Type::Var(_) => true,
        Type::App(f, a) => ty_has_var(f) || ty_has_var(a),
        Type::Arrow { from, to, .. } => ty_has_var(from) || ty_has_var(to),
        Type::Tuple(ts) => ts.iter().any(ty_has_var),
        _ => false,
    }
}

/// A type that denotes a heap allocation the owning machinery reclaims: a
/// parametric/`data` application or a tuple (a bare var/arrow is an unboxed i64).
/// Shared by `owning_generic_var` and the front-end consume-inference.
pub fn is_heap_shaped(t: &Type) -> bool {
    matches!(t, Type::Tuple(_)) || t.head_con().is_some()
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
        if is_heap_shaped(p) && ty_has_var(p) {
            return Some(f.name.clone());
        }
    }
    None
}

/// All names referenced in `f`'s bodies (clauses, guards, `where`),
/// for the transitive native candidacy — those that are top-level functions must be
/// themselves compilable.
fn body_refs(f: &ast::Func, out: &mut HashSet<String>) {
    body_refs_bound(f, &HashSet::new(), out);
}

/// The top-level/`where` function names a clause body REFERENCES — used for native
/// candidacy (a reference to a non-native function disqualifies the referrer). The clause's
/// own parameters and its `where`-local names MUST be treated as bound, or a param whose
/// name collides with a prelude/top-level function (e.g. a param literally named `take`,
/// `drop`, `lookup`) is miscounted as a reference to that function: the referrer — and
/// transitively `main` — is then wrongly pruned from native lowering (codegen can no longer
/// find `main`). Same scope-unaware class as the `eta_expand`/capture bugs. `outer` carries
/// the enclosing clause's binders into `where`-locals so a `where`-body reference to a parent
/// param is likewise not miscounted.
fn body_refs_bound(f: &ast::Func, outer: &HashSet<String>, out: &mut HashSet<String>) {
    for c in &f.clauses {
        let mut bound = outer.clone();
        for p in &c.pats {
            let mut v = Vec::new();
            pat_vars(p, &mut v);
            bound.extend(v);
        }
        for w in &c.wher {
            bound.insert(w.name.clone());
        }
        match &c.body {
            Body::Plain(e) => free_vars(e, &bound, out),
            Body::Guarded(arms) => {
                for (g, r) in arms {
                    free_vars(g, &bound, out);
                    free_vars(r, &bound, out);
                }
            }
        }
        for w in &c.wher {
            body_refs_bound(w, &bound, out);
        }
    }
}

// --- scope utilities (free variables, for closure capture) ---

/// The variables a `where`-local captures from its enclosing scope: names its
/// bodies reference that are neither its own parameters (nor a nested `where`'s
/// name) nor module globals. Used to lambda-lift the local for the native
/// backends (the interpreter captures the parent env directly).
fn where_free_vars(
    w: &ast::Func,
    globals: &HashSet<String>,
    shadow: &HashSet<String>,
) -> HashSet<String> {
    let mut out = HashSet::new();
    for c in &w.clauses {
        let mut bound: HashSet<String> = HashSet::new();
        for p in &c.pats {
            let mut vs = Vec::new();
            pat_vars(p, &mut vs);
            bound.extend(vs);
        }
        for iw in &c.wher {
            bound.insert(iw.name.clone());
        }
        match &c.body {
            Body::Plain(e) => free_vars(e, &bound, &mut out),
            Body::Guarded(arms) => {
                for (g, r) in arms {
                    free_vars(g, &bound, &mut out);
                    free_vars(r, &bound, &mut out);
                }
            }
        }
        for iw in &c.wher {
            for n in where_free_vars(iw, globals, shadow) {
                if !bound.contains(&n) {
                    out.insert(n);
                }
            }
        }
    }
    // A builtin that lowers to a runtime call (`getEnv`/`runCapture`/… — `sess_builtin_rt`)
    // is resolved directly at that call site, never captured; capturing its NAME leaves an
    // unbound `getEnv` in the native IR (`where s = getEnv "HOME"`). Excluded here in
    // addition to module globals. (Kept narrow — NOT the whole builtin set, whose session
    // ops resolve through a different path and must stay out of the global name resolver.)
    //
    // EXCEPT a name in `shadow` (an enclosing-function param/`let`/`case` binder): it must
    // stay a capture even when it collides with a module global, since the `where`-local's
    // reference is to that lexical local, not the global — dropping it resolved the global
    // instead (a silent miscompile, `where h = g + 1` capturing a param `g` that shadows a
    // global CAF `g`). Same shadow rule as `atom`/`call_named`/the lambda-lift captures.
    // `otherwise` (a guard's catch-all, a built-in constant) is never captured either, unless a
    // local of that name shadows it.
    out.retain(|n| {
        (!globals.contains(n) || shadow.contains(n))
            && sess_builtin_rt(n).is_none()
            && (n != "otherwise" || shadow.contains(n))
    });
    out
}

/// Every name bound *inside* an expression: `let` binders, lambda parameters and
/// `case` pattern variables (recursively). With the clause parameters, this is the
/// set of names that shadow same-named nullary globals during native lowering.
fn collect_bound_names(e: &Expr, out: &mut HashSet<String>) {
    match e {
        Expr::Lam(pats, body, _) => {
            for p in pats {
                let mut v = Vec::new();
                pat_vars(p, &mut v);
                out.extend(v);
            }
            collect_bound_names(body, out);
        }
        Expr::Let(binds, body, _) => {
            for f in binds {
                out.insert(f.name.clone());
                for c in &f.clauses {
                    for p in &c.pats {
                        let mut v = Vec::new();
                        pat_vars(p, &mut v);
                        out.extend(v);
                    }
                    match &c.body {
                        Body::Plain(b) => collect_bound_names(b, out),
                        Body::Guarded(arms) => {
                            for (g, r) in arms {
                                collect_bound_names(g, out);
                                collect_bound_names(r, out);
                            }
                        }
                    }
                }
            }
            collect_bound_names(body, out);
        }
        Expr::Case(s, arms, _) => {
            collect_bound_names(s, out);
            for (p, body) in arms {
                let mut v = Vec::new();
                pat_vars(p, &mut v);
                out.extend(v);
                collect_bound_names(body, out);
            }
        }
        Expr::App(f, a, _) => {
            collect_bound_names(f, out);
            collect_bound_names(a, out);
        }
        Expr::BinOp(_, l, r, _) => {
            collect_bound_names(l, out);
            collect_bound_names(r, out);
        }
        Expr::If(c, t, el, _) => {
            collect_bound_names(c, out);
            collect_bound_names(t, out);
            collect_bound_names(el, out);
        }
        Expr::Tuple(es, _) => es.iter().for_each(|x| collect_bound_names(x, out)),
        Expr::RecordCon(_, fs, _) => fs.iter().for_each(|(_, x)| collect_bound_names(x, out)),
        Expr::RecordUpd(b, fs, _) => {
            collect_bound_names(b, out);
            fs.iter().for_each(|(_, x)| collect_bound_names(x, out));
        }
        _ => {}
    }
}

/// The locally-bound names of a whole function body (clause params + everything
/// `collect_bound_names` finds), for shadowing-aware CAF lowering.
fn func_bound_names(f: &ast::Func) -> HashSet<String> {
    let mut out = HashSet::new();
    for c in &f.clauses {
        for p in &c.pats {
            let mut v = Vec::new();
            pat_vars(p, &mut v);
            out.extend(v);
        }
        match &c.body {
            Body::Plain(e) => collect_bound_names(e, &mut out),
            Body::Guarded(arms) => {
                for (g, r) in arms {
                    collect_bound_names(g, &mut out);
                    collect_bound_names(r, &mut out);
                }
            }
        }
    }
    out
}

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
    // worker↔worker `connect prod cons`: both workers get a `<name>$step` state machine, exactly
    // like a parMap worker (single endpoint), so collect both named args.
    if let (Some("connect"), args) = sess_spine(e) {
        for a in args.iter().take(2) {
            if let Expr::Var(n, _) = a {
                out.push(n.clone());
            }
        }
    }
    // worker↔worker chain `pipe3 s1 s2 s3`: each of the three stages gets a `<name>$step` state
    // machine (the middle stage is two-endpoint, resolved from its layout), so collect all three.
    if let (Some("pipe3"), args) = sess_spine(e) {
        for a in args.iter().take(3) {
            if let Expr::Var(n, _) = a {
                out.push(n.clone());
            }
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
        "intToPtr",
        "ptrToInt",
        "handleAddr",
        "newBuffer",
        "withBuffer",
        "bufIota",
        "xorInPlace",
        "sumBytes",
        "free",
        "fileOpenRaw",
        "fileErrno",
        "fileSize",
        "fileRead",
        "fileClose",
        "bufLen",
        "imperative",
        "newArray",
        "getArray",
        "setArray",
        "lenArray",
        "newTritVec",
        "getTritVec",
        "setTritVec",
        "lenTritVec",
        "tritDot",
        "tritMatVecSum",
        "tritVecFromBuffer",
        "tritVecIota",
        "arrayIota",
        "newI8Array",
        "i8Iota",
        "getI8",
        "setI8",
        "lenI8",
        "i8MatVecSum",
        "i8Sum",
        "i8Dot",
        "i8DotI8",
        "arraySum",
        "arrayDot",
        "newI32Array",
        "i32Iota",
        "getI32",
        "setI32",
        "lenI32",
        "i32Sum",
        "i32Dot",
        "i32MatVecSum",
        "toFloat",
        "truncate",
        "sqrt",
        "floor",
        "abs",
        "fromInt",
        "showInteger",
        "divInteger",
        "modInteger",
        "bignumFromStr",
        "strLen",
        "charAt",
        "pokeU32",
        "pokeU8",
        "pokeU16",
        "pokeU64",
        "pokeF64",
        "peekU8",
        "peekU16",
        "peekU32",
        "peekU64",
        "peekF64",
        "bufPtr",
        "bufPtrN",
        "substr",
    ] {
        g.insert(b.to_string());
    }
    g
}

// --- a baixada AST → Core ---

type LamMeta = HashMap<Span, (String, Vec<String>)>;

/// Prefix of the generated helpers of an `Array` with heap elements (`axion_arrop_new$String`,
/// `get$…`, `set$…`, `fill$…`): they copy elements in and out and free replaced ones, managing
/// memory by hand like the destructors and copiers. Their call-site ownership is fixed by
/// [`arrop_borrows`].
pub const ARROP: &str = "axion_arrop_";

/// The argument positions a generated array helper only READS (see [`ARROP`]): `new n x` and
/// `get a i` borrow everything (the result is fresh), `set a i x` consumes the array and returns
/// it, and borrows the element (it stores a copy).
fn arrop_borrows(name: &str) -> Option<HashSet<usize>> {
    let rest = name.strip_prefix(ARROP)?;
    if rest.starts_with("new$") || rest.starts_with("get$") {
        Some(HashSet::from([0, 1]))
    } else if rest.starts_with("set$") {
        Some(HashSet::from([1, 2]))
    } else {
        None
    }
}

/// Calls `g` on every `Op` of a term (let right-hand sides and tail results, all branches).
fn for_each_op(t: &Term, g: &mut dyn FnMut(&Op)) {
    fn rhs(r: &Rhs, g: &mut dyn FnMut(&Op)) {
        match r {
            Rhs::Op(op) => g(op),
            Rhs::If(_, a, b) => {
                for_each_op(a, g);
                for_each_op(b, g);
            }
            Rhs::Case(_, arms) => arms.iter().for_each(|(_, b)| for_each_op(b, g)),
        }
    }
    match t {
        Term::Let(_, r, _, body) => {
            rhs(r, g);
            for_each_op(body, g);
        }
        Term::Drop(_, _, _, _, body) => for_each_op(body, g),
        Term::Ret(r, _) => rhs(r, g),
    }
}

/// `true` if an AST type still has a type variable or a function type in it.
fn type_has_var_or_fun(t: &Type) -> bool {
    match t {
        Type::Var(_) | Type::Arrow { .. } => true,
        Type::App(f, a) => type_has_var_or_fun(f) || type_has_var_or_fun(a),
        Type::Tuple(ts) => ts.iter().any(type_has_var_or_fun),
        _ => false,
    }
}

/// Lowering context: the global names, the field selectors, the mangling of
/// `where` of the current function, and the lambdas' meta-information.
struct Lower<'a> {
    globals: &'a HashSet<String>,
    fields: &'a HashSet<String>,
    lam_meta: &'a LamMeta,
    /// spans of the `RecordUpd`s eligible for in-place mutation (Linear Elision, §2)
    inplace: &'a HashSet<Span>,
    /// FFI imports (§18): Axión name → resolved target (C `dlsym` symbol + per-arg kinds +
    /// result-float flag). Called via `Op::Ffi`, which carries the C SYMBOL (so an aliased
    /// `sdlInit = "SDL_Init"` resolves `SDL_Init`) and the arg kinds for the float/own ABI.
    foreigns: &'a HashMap<String, ForeignInfo>,
    /// Phase A′: constructor → `data`-type name of its value (None for unboxed
    /// enum constructors — immediate tags, never dropped). Attached to `Make*`.
    con_ty: &'a HashMap<String, Option<String>>,
    /// record field → its (non-parametric) record type's name. Attached to `UpdateRecord`.
    field_ty: &'a HashMap<String, String>,
    /// Phase A′: function → `data`-type name of its result (boxed only). Attached
    /// to `CallDirect`.
    fn_ret_ty: &'a HashMap<String, String>,
    /// Top-level function → parameter count, to split an OVER-applied spine
    /// (`(f a…) b…`) into a call-to-arity + an application of the returned closure.
    fn_arity: &'a HashMap<String, usize>,
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
    parmap_workers: &'a HashMap<String, (String, i32, i32, i32)>,
    /// Names bound locally in the function being lowered (params, `let`s, lambda
    /// params, `case` pattern vars). A bare reference to one of these is a local
    /// variable even if a same-named nullary global (CAF) exists — it shadows it.
    local_names: HashSet<String>,
    /// Spans of literal patterns that inference resolved to `Integer` (not `Int`):
    /// they must match by arbitrary-precision `axion_bignum_eq`, not an i64 compare.
    integer_pats: &'a HashSet<Span>,
    /// `where`-local (mangled `parent$w`) → the enclosing variables it captures,
    /// lifted to leading parameters. At each direct call these are prepended as
    /// arguments (in this order) so the lifted function receives its free vars.
    where_captures: &'a HashMap<String, Vec<String>>,
}

impl Lower<'_> {
    /// The element type of the `Array` operation at `span` and its mono key, when it is a
    /// concrete HEAP type (`String`, `Integer`, a tuple, a `data` type with fields). Such arrays
    /// own their elements: the operation is a generated `axion_arrop_*$K` helper.
    fn heap_array_elem(&self, span: Span) -> Option<(Type, String)> {
        let t = self.array_tys.get(&span)?;
        let (head, a) = ty_head_args(t);
        if head != Some("Array") {
            return None;
        }
        let el = (*a.first()?).clone();
        let heap = match &el {
            Type::Tuple(_) => true,
            _ => match el.head_con() {
                Some("Int" | "Float" | "Bool" | "Char") | None => false,
                Some("String" | "Integer") => true,
                Some(h) => self.con_ty.values().any(|d| d.as_deref() == Some(h)),
            },
        };
        if !heap || type_has_var_or_fun(&el) {
            return None;
        }
        let k = mono_key(&el)?;
        Some((el, k))
    }

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
            Expr::Var(n, _) => {
                // `nullPtr` (§18) is the null opaque handle — a compile-time constant 0 (the C
                // NULL), not a CAF; lowering it to an immediate avoids a polymorphic nullary CAF.
                if n == "nullPtr" {
                    return Atom::Int(0);
                }
                // A bare reference to a nullary global — a top-level CAF (`x = 5`) or a
                // captured `where`-local thunk — is a zero-arg call, not a local
                // variable. Route it through call_named so the mangling and any
                // captured arguments are applied, then bind the result.
                let key = self.locals.get(n).map_or(n.as_str(), String::as_str);
                if self.globals.contains(n)
                    && !self.foreigns.contains_key(n)
                    && !self.local_names.contains(n)
                    && self.fn_arity.get(key) == Some(&0)
                {
                    let op = self.call_named(n, Vec::new());
                    let t = self.fresh();
                    buf.push((t.clone(), Rhs::Op(op), e.span()));
                    Atom::Var(t)
                } else {
                    Atom::Var(n.clone())
                }
            }
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
                // An Integer literal arm compares by bignum equality — the CPat switch
                // would test the boxed scrutinee pointer against an i64 and never match,
                // so desugar the whole `case` to an if-chain (like function clauses).
                if arms
                    .iter()
                    .any(|(p, _)| matches!(p, Pat::Int(_, sp) if self.integer_pats.contains(sp)))
                {
                    return self.integer_case_rhs(sa, arms, buf);
                }
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
            Expr::BinOp(op, l, r, sp) => {
                let a = self.atom(l, buf);
                let b = self.atom(r, buf);
                if let Some(int_op) = str_cmp_int_op(op) {
                    // String comparison (§text): `axion_str_cmp a b` yields -1/0/1;
                    // compare that against 0 with the matching Int predicate. Reuses
                    // the one native compare for `== < >` — no dedicated runtime fns.
                    let cmp = self.fresh();
                    buf.push((
                        cmp.clone(),
                        Rhs::Op(Op::RtCall {
                            func: "axion_str_cmp".into(),
                            args: vec![a, b],
                            returns: true,
                        }),
                        *sp,
                    ));
                    return Op::Prim(int_op.into(), Atom::Var(cmp), Atom::Int(0));
                }
                if is_float_op(op) {
                    Op::PrimF(op.clone(), a, b)
                } else if let Some(func) = integer_op_rt(op) {
                    // Integer (§ Listing 1.4): `#I` operators → arbitrary-precision runtime.
                    Op::RtCall {
                        func: func.into(),
                        args: vec![a, b],
                        returns: true,
                    }
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
                    ty: assigns
                        .first()
                        .and_then(|(f, _)| self.field_ty.get(f).cloned()),
                }
            }
            Expr::Lam(_, _, span) => match self.lam_meta.get(span) {
                Some((name, caps)) => Op::MakeClosure {
                    func: name.clone(),
                    captures: caps.iter().map(|c| Atom::Var(c.clone())).collect(),
                    owns: false,
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
        if name == "ePutStrLn" && args.len() == 1 {
            return self.rtcall("axion_eputs", &args, false, buf);
        }
        if name == "ePutStr" && args.len() == 1 {
            return self.rtcall("axion_eput", &args, false, buf);
        }
        if name == "showInt" && args.len() == 1 {
            return Op::ShowInt(self.atom(args[0], buf));
        }
        if name == "showFloat" && args.len() == 1 {
            return self.rtcall("axion_show_float", &args, true, buf);
        }
        // Integer (§ Listing 1.4): construct from an Int / render to a String.
        if name == "fromInt" && args.len() == 1 {
            return self.rtcall("axion_bignum_from_i64", &args, true, buf);
        }
        if name == "bignumFromStr" && args.len() == 1 {
            return self.rtcall("axion_bignum_from_str", &args, true, buf);
        }
        if name == "showInteger" && args.len() == 1 {
            return self.rtcall("axion_bignum_to_string", &args, true, buf);
        }
        if name == "divInteger" && args.len() == 2 {
            return self.rtcall("axion_bignum_div", &args, true, buf);
        }
        if name == "modInteger" && args.len() == 2 {
            return self.rtcall("axion_bignum_mod", &args, true, buf);
        }
        if name == "strAppend" && args.len() == 2 {
            return self.rtcall("axion_strcat", &args, true, buf);
        }
        // char-level string primitives (§text)
        if name == "strLen" && args.len() == 1 {
            return self.rtcall("axion_str_len", &args, true, buf);
        }
        if name == "charAt" && args.len() == 2 {
            return self.rtcall("axion_str_at", &args, true, buf);
        }
        if name == "pokeU32" && args.len() == 3 {
            return self.rtcall("axion_poke_u32", &args, true, buf);
        }
        // Buffer peek/poke family + the FFI data-pointer accessor (see sess_builtin_rt map).
        if args.len() == 3 {
            if let Some(f) = match name.as_str() {
                "pokeU8" => Some("axion_poke_u8"),
                "pokeU16" => Some("axion_poke_u16"),
                "pokeU64" => Some("axion_poke_u64"),
                "pokeF64" => Some("axion_poke_f64"),
                _ => None,
            } {
                return self.rtcall(f, &args, true, buf);
            }
        }
        if args.len() == 2 {
            if let Some(f) = match name.as_str() {
                "peekU8" => Some("axion_peek_u8"),
                "peekU16" => Some("axion_peek_u16"),
                "peekU32" => Some("axion_peek_u32"),
                "peekU64" => Some("axion_peek_u64"),
                "peekF64" => Some("axion_peek_f64"),
                _ => None,
            } {
                return self.rtcall(f, &args, true, buf);
            }
        }
        if name == "bufPtr" && args.len() == 1 {
            return self.rtcall("axion_buf_ptr", &args, true, buf);
        }
        if name == "bufPtrN" && args.len() == 2 {
            return self.rtcall("axion_buf_ptr_n", &args, true, buf);
        }
        if name == "strCmp" && args.len() == 2 {
            return self.rtcall("axion_str_cmp", &args, true, buf);
        }
        if name == "substr" && args.len() == 3 {
            return self.rtcall("axion_substr", &args, true, buf);
        }
        // OS capability layer (§pass)
        if name == "getEnv" && args.len() == 1 {
            return self.rtcall("axion_getenv", &args, true, buf);
        }
        if name == "runCapture" && args.len() == 1 {
            return self.rtcall("axion_run", &args, true, buf);
        }
        if name == "runStatus" && args.len() == 1 {
            return self.rtcall("axion_system", &args, true, buf);
        }
        if name == "execCapture" && args.len() == 2 {
            return self.rtcall("axion_exec_capture", &args, true, buf);
        }
        if name == "execStatus" && args.len() == 2 {
            return self.rtcall("axion_exec_status", &args, true, buf);
        }
        if name == "readFile" && args.len() == 1 {
            return self.rtcall("axion_read_file", &args, true, buf);
        }
        if name == "writeFile" && args.len() == 2 {
            return self.rtcall("axion_write_file", &args, true, buf);
        }
        if name == "fileExists" && args.len() == 1 {
            return self.rtcall("axion_file_exists", &args, true, buf);
        }
        if name == "makeDir" && args.len() == 1 {
            return self.rtcall("axion_mkdir_p", &args, true, buf);
        }
        if name == "removeFile" && args.len() == 1 {
            return self.rtcall("axion_unlink", &args, true, buf);
        }
        if name == "renameFile" && args.len() == 2 {
            return self.rtcall("axion_rename", &args, true, buf);
        }
        if name == "readDir" && args.len() == 1 {
            return self.rtcall("axion_readdir", &args, true, buf);
        }
        if name == "readDirTyped" && args.len() == 1 {
            return self.rtcall("axion_readdir_typed", &args, true, buf);
        }
        if name == "readDirListing" && args.len() == 3 {
            return self.rtcall("axion_readdir_listing", &args, true, buf);
        }
        if name == "readLine" && args.len() == 1 {
            return self.rtcall("axion_read_line", &args, true, buf);
        }
        if name == "readSecret" && args.len() == 1 {
            return self.rtcall("axion_read_secret", &args, true, buf);
        }
        if name == "readKey" && args.len() == 1 {
            return self.rtcall("axion_read_key", &args, true, buf);
        }
        if name == "readKeyTimeout" && args.len() == 1 {
            return self.rtcall("axion_read_key_timeout", &args, true, buf);
        }
        if name == "resized" && args.len() == 1 {
            return self.rtcall("axion_resized", &args, true, buf);
        }
        if name == "chr" && args.len() == 1 {
            return self.rtcall("axion_chr", &args, true, buf);
        }
        if name == "randHex" && args.len() == 1 {
            return self.rtcall("axion_rand_hex", &args, true, buf);
        }
        if name == "exitWith" && args.len() == 1 {
            return self.rtcall("axion_exit", &args, true, buf);
        }
        if name == "getArgs" && args.len() == 1 {
            return self.rtcall("axion_getargs", &args, true, buf);
        }
        if name == "getArg" && args.len() == 1 {
            return self.rtcall("axion_getarg", &args, true, buf);
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
        // an accessor of a FUNCTION field applied further (`onClick b x`): read the field, then
        // call the closure it holds with the remaining arguments
        if self.fields.contains(name) && args.len() > 1 {
            let rec = self.atom(args[0], buf);
            let f = self.fresh();
            buf.push((
                f.clone(),
                Rhs::Op(Op::Field {
                    name: name.clone(),
                    rec,
                }),
                e.span(),
            ));
            let rest: Vec<Atom> = args[1..].iter().map(|a| self.atom(a, buf)).collect();
            return Op::CallClosure(Atom::Var(f), rest);
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
            // files (linear `File`, an fd or -errno) and the byte Buffers read from them
            ("fileOpenRaw", 1) => return self.rtcall("axion_file_open", &args, true, buf),
            ("fileErrno", 1) => return self.rtcall("axion_file_errno", &args, true, buf),
            ("fileSize", 1) => return self.rtcall("axion_file_size", &args, true, buf),
            ("fileRead", 2) => return self.rtcall("axion_file_read", &args, true, buf),
            ("fileClose", 1) => return self.rtcall("axion_file_close", &args, true, buf),
            ("bufLen", 1) => return self.rtcall("axion_buf_len", &args, true, buf),
            ("free", 1) => return self.rtcall("axion_buf_free", &args, true, buf),
            ("foldBytes", 3) => return self.rtcall("axion_fold_bytes", &args, true, buf),
            // linear dense Array: imperative operations
            ("newArray", 2) if self.heap_array_elem(e.span()).is_some() => {
                // a heap element: every slot gets its own copy of the initial value
                let k = self
                    .heap_array_elem(e.span())
                    .map(|(_, k)| k)
                    .unwrap_or_default();
                let a: Vec<Atom> = args.iter().map(|x| self.atom(x, buf)).collect();
                return Op::CallDirect(format!("{ARROP}new${k}"), a, Some(format!("Array${k}")));
            }
            ("newArray", 2) => {
                let len = self.atom(args[0], buf);
                let init = self.atom(args[1], buf);
                // scalar elements: a flat block (heap elements took the helper path above)
                return Op::ArrayNew {
                    len,
                    init,
                    elem_ty: None,
                };
            }
            ("getArray", 2) => {
                // a heap element is read out as a fresh copy the caller owns
                if let Some((_, k)) = self.heap_array_elem(e.span()) {
                    let a: Vec<Atom> = args.iter().map(|x| self.atom(x, buf)).collect();
                    return Op::CallDirect(format!("{ARROP}get${k}"), a, Some(k));
                }
                return self.rtcall("axion_array_get", &args, true, buf);
            }
            ("setArray", 3) => {
                // a heap element: free the replaced one, store a copy of the new one
                if let Some((_, k)) = self.heap_array_elem(e.span()) {
                    let a: Vec<Atom> = args.iter().map(|x| self.atom(x, buf)).collect();
                    return Op::CallDirect(
                        format!("{ARROP}set${k}"),
                        a,
                        Some(format!("Array${k}")),
                    );
                }
                return self.rtcall("axion_array_set", &args, true, buf);
            }
            ("lenArray", 1) => return self.rtcall("axion_array_len", &args, true, buf),
            // TritVec (§10): base-243 packed ternary array. A flat block (packed
            // bytes inline, no nested heap) → Auto-Drop's flat `axion_free`
            // reclaims it; `drop_ty` marks the `newTritVec` binding as owned.
            ("newTritVec", 2) => return self.rtcall("axion_tritvec_new", &args, true, buf),
            ("getTritVec", 2) => return self.rtcall("axion_tritvec_get", &args, true, buf),
            ("setTritVec", 3) => return self.rtcall("axion_tritvec_set", &args, true, buf),
            ("lenTritVec", 1) => return self.rtcall("axion_tritvec_len", &args, true, buf),
            // fused ternary dot product (§10): borrows both, returns a scalar Int.
            ("tritDot", 2) => return self.rtcall("axion_tritvec_dot", &args, true, buf),
            // ternary matvec (§10): borrows both, K inert, returns a scalar Int.
            ("tritMatVecSum", 3) => {
                return self.rtcall("axion_tritvec_matvec_sum", &args, true, buf)
            }
            // wrap pre-packed base-243 bytes into a TritVec (borrows the buffer).
            ("tritVecFromBuffer", 2) => {
                return self.rtcall("axion_tritvec_from_buffer", &args, true, buf)
            }
            // bulk builders (§10): construct a packed vec / dense array in one
            // native pass — owned results, reclaimed like newTritVec / newArray.
            ("tritVecIota", 1) => return self.rtcall("axion_tritvec_iota", &args, true, buf),
            ("arrayIota", 1) => return self.rtcall("axion_array_iota", &args, true, buf),
            // I8Array (Phase B): compact signed-byte array.
            ("newI8Array", 2) => return self.rtcall("axion_i8_new", &args, true, buf),
            ("i8Iota", 1) => return self.rtcall("axion_i8_iota", &args, true, buf),
            ("getI8", 2) => return self.rtcall("axion_i8_get", &args, true, buf),
            ("setI8", 3) => return self.rtcall("axion_i8_set", &args, true, buf),
            ("lenI8", 1) => return self.rtcall("axion_i8_len", &args, true, buf),
            ("i8MatVecSum", 3) => return self.rtcall("axion_i8_matvec_sum", &args, true, buf),
            ("i8Sum", 1) => return self.rtcall("axion_i8_sum", &args, true, buf),
            ("i8Dot", 2) => return self.rtcall("axion_i8_dot", &args, true, buf),
            ("i8DotI8", 2) => return self.rtcall("axion_i8_dot_i8", &args, true, buf),
            // Array Int fused reductions (general primitives).
            ("arraySum", 1) => return self.rtcall("axion_array_sum", &args, true, buf),
            ("arrayDot", 2) => return self.rtcall("axion_array_dot", &args, true, buf),
            // I32Array (compact int32 array).
            ("newI32Array", 2) => return self.rtcall("axion_i32_new", &args, true, buf),
            ("i32Iota", 1) => return self.rtcall("axion_i32_iota", &args, true, buf),
            ("getI32", 2) => return self.rtcall("axion_i32_get", &args, true, buf),
            ("setI32", 3) => return self.rtcall("axion_i32_set", &args, true, buf),
            ("lenI32", 1) => return self.rtcall("axion_i32_len", &args, true, buf),
            ("i32Sum", 1) => return self.rtcall("axion_i32_sum", &args, true, buf),
            ("i32Dot", 2) => return self.rtcall("axion_i32_dot", &args, true, buf),
            ("i32MatVecSum", 3) => return self.rtcall("axion_i32_matvec_sum", &args, true, buf),
            // `imperative e` = e (the imperative block is identity; §5)
            ("imperative", 1) => return self.op(args[0], buf),
            // Ptr casts (§18): `Ptr a` is a reinterpreted i64, so intToPtr/ptrToInt are identity.
            ("intToPtr", 1) | ("ptrToInt", 1) | ("handleAddr", 1) => return self.op(args[0], buf),
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
                    if let Some((step, size, ep_slot, _)) = self.parmap_workers.get(wname).cloned()
                    {
                        let xs = self.atom(args[1], buf);
                        let fa = self.fresh();
                        buf.push((fa.clone(), Rhs::Op(Op::FuncAddr(step)), NO_SPAN));
                        // Phase 4 (deep-drop): the reply `List` may carry heap payloads
                        // (`List (List Int)`); seed its specialized destructor so the
                        // element lists are reclaimed. The drop is keyed concretely in
                        // `collect_drop_types` (the RtCall has no key field).
                        if let Some(ty) = self.makecon_tys.get(&e.span()) {
                            if ty_head_args(ty)
                                .0
                                .is_some_and(|h| self.parametric_data.contains(h))
                                && mono_key(ty).is_some_and(|k| k.contains('$'))
                            {
                                self.mono_seeds.push(ty.clone());
                            }
                        }
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
            // §9 worker↔worker: `connect prod cons` → the `axion_connect` runtime driver. Both
            // workers' state machines + layouts (size, endpoint slot) were resolved pre-eta (via
            // `parmap_targets`); materialize both step addresses and hand the runtime the (step,
            // size, ep_slot) triple for each. The channel lives inside the driver's own scheduler.
            ("connect", 2) => {
                if let (Expr::Var(pname, _), Expr::Var(cname, _)) = (args[0], args[1]) {
                    if let (Some((ps, psz, pep, _)), Some((cs, csz, cep, _))) = (
                        self.parmap_workers.get(pname).cloned(),
                        self.parmap_workers.get(cname).cloned(),
                    ) {
                        let pfa = self.fresh();
                        buf.push((pfa.clone(), Rhs::Op(Op::FuncAddr(ps)), NO_SPAN));
                        let cfa = self.fresh();
                        buf.push((cfa.clone(), Rhs::Op(Op::FuncAddr(cs)), NO_SPAN));
                        return Op::RtCall {
                            func: "axion_connect".into(),
                            args: vec![
                                Atom::Var(pfa),
                                Atom::Int(psz as i64),
                                Atom::Int(pep as i64),
                                Atom::Var(cfa),
                                Atom::Int(csz as i64),
                                Atom::Int(cep as i64),
                            ],
                            returns: true,
                        };
                    }
                }
                return Op::Unsupported(
                    "connect: both workers must be named top-level session functions".into(),
                );
            }
            // §9 worker↔worker chain: `pipe3 s1 s2 s3` → the `axion_pipe3` runtime driver — a
            // producer→relay→consumer pipeline (the N=3 generalization of `connect`). The relay
            // `s2` holds TWO endpoints (recv-from-`s1`, send-to-`s3`), so it contributes both its
            // up- and down-slots; `s1`/`s3` are single-endpoint like connect's prod/cons. Data
            // flows worker→worker→worker; the driver returns `s3`'s result. Deadlock-free by
            // construction: a linear chain is rank-ordered (rank = position).
            ("pipe3", 3) => {
                if let (Expr::Var(n1, _), Expr::Var(n2, _), Expr::Var(n3, _)) =
                    (args[0], args[1], args[2])
                {
                    if let (Some(w1), Some(w2), Some(w3)) = (
                        self.parmap_workers.get(n1).cloned(),
                        self.parmap_workers.get(n2).cloned(),
                        self.parmap_workers.get(n3).cloned(),
                    ) {
                        let (s1, sz1, down1, _) = w1; // producer: down-endpoint only
                        let (s2, sz2, up2, down2) = w2; // relay: recv up2, send down2
                        let (s3, sz3, up3, _) = w3; // consumer: up-endpoint only
                        let a1 = self.fresh();
                        buf.push((a1.clone(), Rhs::Op(Op::FuncAddr(s1)), NO_SPAN));
                        let a2 = self.fresh();
                        buf.push((a2.clone(), Rhs::Op(Op::FuncAddr(s2)), NO_SPAN));
                        let a3 = self.fresh();
                        buf.push((a3.clone(), Rhs::Op(Op::FuncAddr(s3)), NO_SPAN));
                        return Op::RtCall {
                            func: "axion_pipe3".into(),
                            args: vec![
                                Atom::Var(a1),
                                Atom::Int(sz1 as i64),
                                Atom::Int(down1 as i64),
                                Atom::Var(a2),
                                Atom::Int(sz2 as i64),
                                Atom::Int(up2 as i64),
                                Atom::Int(down2 as i64),
                                Atom::Var(a3),
                                Atom::Int(sz3 as i64),
                                Atom::Int(up3 as i64),
                            ],
                            returns: true,
                        };
                    }
                }
                return Op::Unsupported(
                    "pipe3: all three stages must be named top-level session functions".into(),
                );
            }
            _ => {}
        }
        let mut vals: Vec<Atom> = args.iter().map(|a| self.atom(a, buf)).collect();
        // over-application: `(f a…) b…` applies a function beyond its arity. Call `f`
        // to its arity (yielding a closure), then apply the remaining args to it.
        // Without this the spine is lowered as one over-long direct call, which the
        // backends mishandle (cranelift errors, LLVM emits garbage). `f` may be a
        // top-level function (looked up by name) or a `where`-local (resolved through
        // the mangling map to its `parent$w` key).
        //
        // `local_names` MUST shadow the global arity table here, exactly as the CAF
        // check in `atom` does (and for the same reason as the scope-aware `eta_expand`
        // fix): a function-typed LOCAL (param/`let`/`case` binder) whose name collides
        // with a top-level function would otherwise be split using the GLOBAL's arity —
        // `call_named` would then call the wrong (global) function and apply the real
        // local's extra args to its result (a silent miscompile). A bare local is never
        // over-applied against the global; it stays a single `call_named` (closure call).
        if !self.foreigns.contains_key(name) && !self.local_names.contains(name) {
            let key = self.locals.get(name).map_or(name.as_str(), String::as_str);
            if let Some(&arity) = self.fn_arity.get(key) {
                if vals.len() > arity {
                    let rest = vals.split_off(arity);
                    let base = self.call_named(name, vals);
                    let t = self.fresh();
                    buf.push((t.clone(), Rhs::Op(base), NO_SPAN));
                    return Op::CallClosure(Atom::Var(t), rest);
                }
            }
        }
        let mut op = self.call_named(name, vals);
        // Phase 4 (deep-drop): if this call's result is a concrete parametric heap
        // type (`List (List Int)`, `List P`, …), key its drop at that concrete type
        // and seed the specialized destructor, instead of the callee's generic result
        // head — so a call-bound local reclaims its heap ELEMENT payloads, not just
        // the spine. Bare/monomorphic heads (`List$Int`, whose element is unboxed) are
        // harmless; a plain `Int`/function result (no `$`) is left untouched.
        if let Op::CallDirect(_, _, key) = &mut op {
            if let Some(ty) = self.makecon_tys.get(&e.span()) {
                // only parametric `data` types (List/Maybe/user) have generated
                // mono-destructors — NOT native builtins like `Array` (freed flat).
                let head = ty_head_args(ty).0;
                if head.is_some_and(|h| self.parametric_data.contains(h)) {
                    if let Some(mk) = mono_key(ty).filter(|k| k.contains('$')) {
                        self.mono_seeds.push(ty.clone());
                        *key = Some(mk);
                    }
                } else if key.is_none() && matches!(ty, Type::Tuple(_)) {
                    // A generic callee returning a tuple (`unzip`) instantiated concretely
                    // here: key the result so its owner deep-drops it. A reader that only
                    // borrows the tuple no longer frees it on the caller's behalf.
                    if let Some(mk) = mono_key(ty) {
                        self.mono_seeds.push(ty.clone());
                        *key = Some(mk);
                    }
                } else if key.is_none() && matches!(head, Some("Integer") | Some("String")) {
                    // A POLYMORPHIC callee (declared return a type-variable `b`, so no
                    // `fn_ret_ty` key) instantiated at a SCALAR heap type at THIS call
                    // site — `foldr addI 0 xs :: Integer`. Key the result at the concrete
                    // type so Auto-Drop reclaims the returned bignum; without this a
                    // poly-heap call result leaks (integer_first_class `_t7`). Safe: the
                    // callee returns a fresh/owned value here — an alias-returning callee
                    // has its key nulled downstream by `null_borrow_result_keys`. Same for a
                    // String (`idG s`); its reclaimer skips a literal.
                    *key = head.map(str::to_string);
                }
            }
        }
        op
    }

    /// Lowers a call by name (`name` applied to `vals`), resolving whether it is
    /// FFI, a top-level function (direct call, with mangling), or a local variable of
    /// function type (indirect call). Shared between normal application and the
    /// operadores infixos de utilizador.
    fn call_named(&self, name: &str, vals: Vec<Atom>) -> Op {
        if let Some(info) = self.foreigns.get(name) {
            // FFI import (§18): C call. Emit the C SYMBOL (the `dlsym` target), not the Axión
            // binding name, so an alias `sdlInit = "SDL_Init"` works; carry the per-arg kinds
            // (float/own) so the backends pick the right ABI and the verifier the right ownership.
            // Pad/truncate the kinds to the actual arg count (exact-arity FFI calls align 1:1).
            let mut arg_kinds = info.arg_kinds.clone();
            arg_kinds.resize(
                vals.len(),
                FfiArg {
                    float: false,
                    own: false,
                },
            );
            Op::Ffi {
                name: info.symbol.clone(),
                args: vals,
                arg_kinds,
                ret_float: info.ret_float,
            }
        } else if self.globals.contains(name) && !self.local_names.contains(name) {
            // top-level function / `where` local (resolves the mangling). `local_names`
            // shadows the global table (same rule as `atom`'s bare-`Var` CAF check and
            // the over-application split): a function-typed LOCAL (param/`let`/`case`
            // binder) that collides with a top-level function name is an indirect
            // closure call, NOT a direct call to the global — otherwise it would call
            // the wrong function (and at the global's arity). `where`-locals are resolved
            // through the `locals` mangling map and are NOT in `local_names` (which only
            // holds clause params + `let`/lambda/`case` binders), so they stay here.
            let target = self
                .locals
                .get(name)
                .cloned()
                .unwrap_or_else(|| name.to_string());
            // A `where`-local lifted with captured enclosing variables receives them
            // as leading arguments (same order as its lifted leading parameters).
            let args = match self.where_captures.get(&target) {
                Some(caps) if !caps.is_empty() => caps
                    .iter()
                    .map(|c| Atom::Var(c.clone()))
                    .chain(vals)
                    .collect(),
                _ => vals,
            };
            Op::CallDirect(target.clone(), args, self.fn_ret_ty.get(&target).cloned())
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

    /// Lowers a `case` over an `Integer` to an if-chain: the first arm's test
    /// (bignum `==` for a literal, unconditional for a var/wildcard) is emitted into
    /// `buf`; the remaining arms become the nested else-Term.
    fn integer_case_rhs(
        &mut self,
        scrut: Atom,
        arms: &[(Pat, Expr)],
        buf: &mut Vec<(String, Rhs, Span)>,
    ) -> Rhs {
        let Some((p0, body0)) = arms.first() else {
            return Rhs::Op(Op::Unsupported("non-exhaustive Integer case".into()));
        };
        match p0 {
            // a var/wildcard arm is irrefutable — it ends the chain
            Pat::Wild(_) => self.rhs(body0, buf),
            Pat::Var(n, sp) => {
                buf.push((n.clone(), Rhs::Op(Op::Atom(scrut)), *sp));
                self.rhs(body0, buf)
            }
            Pat::Int(k, _) => {
                let boxed = self.fresh();
                buf.push((
                    boxed.clone(),
                    Rhs::Op(Op::RtCall {
                        func: "axion_bignum_from_i64".into(),
                        args: vec![Atom::Int(*k)],
                        returns: true,
                    }),
                    NO_SPAN,
                ));
                let c = self.fresh();
                buf.push((
                    c.clone(),
                    Rhs::Op(Op::RtCall {
                        func: "axion_bignum_eq".into(),
                        args: vec![scrut.clone(), Atom::Var(boxed)],
                        returns: true,
                    }),
                    NO_SPAN,
                ));
                let then_t = self.term(body0);
                let else_t = self.integer_case_term(scrut, &arms[1..]);
                Rhs::If(Atom::Var(c), Box::new(then_t), Box::new(else_t))
            }
            // Integer scrutinees only carry literal/var/wildcard patterns
            _ => self.rhs(body0, buf),
        }
    }

    fn integer_case_term(&mut self, scrut: Atom, arms: &[(Pat, Expr)]) -> Term {
        let mut buf = Vec::new();
        let rhs = self.integer_case_rhs(scrut, arms, &mut buf);
        wrap_spanned(buf, Term::Ret(rhs, NO_SPAN))
    }

    /// Desugars multi-clause into an `if` chain (requires a catch-all at the end).
    fn clauses(&mut self, clauses: &[ast::Clause], params: &[String], i: usize) -> Term {
        let clause = &clauses[i];
        let lits: Vec<(usize, i64, Span)> = clause
            .pats
            .iter()
            .enumerate()
            .filter_map(|(j, p)| match p {
                Pat::Int(n, sp) => Some((j, *n, *sp)),
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
        for (j, lit, sp) in &lits {
            let c = self.fresh();
            if self.integer_pats.contains(sp) {
                // Integer literal pattern: box the literal and compare by bignum
                // equality (the scrutinee is a boxed BigInt pointer, not an i64).
                let boxed = self.fresh();
                buf.push((
                    boxed.clone(),
                    Rhs::Op(Op::RtCall {
                        func: "axion_bignum_from_i64".into(),
                        args: vec![Atom::Int(*lit)],
                        returns: true,
                    }),
                    NO_SPAN,
                ));
                buf.push((
                    c.clone(),
                    Rhs::Op(Op::RtCall {
                        func: "axion_bignum_eq".into(),
                        args: vec![Atom::Var(params[*j].clone()), Atom::Var(boxed)],
                        returns: true,
                    }),
                    NO_SPAN,
                ));
            } else {
                buf.push((
                    c.clone(),
                    Rhs::Op(Op::Prim(
                        "==".into(),
                        Atom::Var(params[*j].clone()),
                        Atom::Int(*lit),
                    )),
                    NO_SPAN,
                ));
            }
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
        Pat::Str(_, _) => unreachable!("string patterns are desugared to `if`-chains before core"),
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

pub fn spine(e: &Expr) -> (&Expr, Vec<&Expr>) {
    let mut args = Vec::new();
    let mut cur = e;
    while let Expr::App(f, a, _) = cur {
        args.push(a.as_ref());
        cur = f;
    }
    args.reverse();
    (cur, args)
}

/// `true` if the pattern always matches: a `Var`/`Wild`, a `Tuple` whose
/// sub-patterns are irrefutable, or a `Con` of a SINGLE-constructor type with
/// irrefutable fields. A literal (`Int`) or a `Con` of a multi-constructor type is
/// REFUTABLE. Decides whether a single-clause function head may be destructured
/// natively; a refutable single-clause head is a partial function (no clause-head
/// exhaustiveness check exists) and must stay interpreter-only.
fn pat_irrefutable(p: &Pat, single_con: &HashSet<String>) -> bool {
    match p {
        Pat::Var(_, _) | Pat::Wild(_) => true,
        Pat::Tuple(subs, _) => subs.iter().all(|q| pat_irrefutable(q, single_con)),
        Pat::Con(c, subs, _) => {
            single_con.contains(c) && subs.iter().all(|q| pat_irrefutable(q, single_con))
        }
        Pat::Int(_, _) | Pat::Str(_, _) => false,
    }
}

/// The drop key for a heap-typed value of `t` — Integer / boxed `data` / tuple, the
/// types with a destructor. Mirrors the owned-`%1` key logic in `lower_func`, extended
/// with `Integer` (its own `axion_bignum_free`, not a `heap_ty`). None for a scalar /
/// function / non-owned type. Pushes a mono-seed for a parametric instantiation so its
/// specialized destructor is generated. `String`/`Buffer` are intentionally NOT keyed: a String
/// or Buffer returned by a generic function is untracked by the caller, which may pass it into a
/// generic higher-order function and read it again afterwards, so a closure freeing it would be a
/// use-after-free the verifier cannot see (`app1 strLen v + strLen v`, v = `idG s`). Such an
/// argument leaks instead (the documented conservative closure leak); a closure argument that is
/// specialized (`app1$$f`) is reclaimed exactly.
fn heap_drop_key(
    t: &Type,
    data_types: &HashSet<String>,
    parametric_data: &HashSet<String>,
    mono_seeds: &mut Vec<Type>,
) -> Option<String> {
    if matches!(t, Type::Tuple(_)) {
        let k = mono_key(t);
        if k.is_some() {
            mono_seeds.push(t.clone());
        }
        return k;
    }
    match t.head_con() {
        Some("Integer") => Some("Integer".to_string()),
        Some(h) if parametric_data.contains(h) => {
            mono_key(t).inspect(|_| mono_seeds.push(t.clone()))
        }
        Some(h) if data_types.contains(h) => Some(h.to_string()),
        _ => None,
    }
}

/// Owned heap params of a LIFTED lambda under the closure consume-ABI: a closure owns
/// every heap arg passed to it (`callclo` moves them in — delta.rs), so the lambda owns
/// each param whose type is a heap type. `droppable_vars`/Auto-Drop then drops exactly
/// those the body does NOT move out (a borrowing wrapped call → dropped here; a
/// consuming call or a `Con` result → moved out, not dropped). Param types come from two
/// sources: a USER lambda's params carry an inferred type in `makecon_tys` (keyed by the
/// `Pat::Var` span); an ETA lambda `\v.. -> base v..` (synthesized post-inference, so its
/// params are absent from `makecon_tys`) instead reads the WRAPPED callable's signature,
/// aligning arg position `i` of the body's application spine with the callable's param `i`.
fn lifted_lambda_owned(
    pats: &[Pat],
    body: &Expr,
    fn_param_types: &HashMap<String, Vec<Type>>,
    makecon_tys: &HashMap<Span, Type>,
    data_types: &HashSet<String>,
    parametric_data: &HashSet<String>,
    mono_seeds: &mut Vec<Type>,
) -> (Vec<String>, Vec<(String, Option<String>)>) {
    // eta-lambda source: the wrapped callable's signature, aligned by the body's spine.
    let mut spine_ty: HashMap<&str, &Type> = HashMap::new();
    let (head, args) = spine(body);
    if let Expr::Var(base, _) = head {
        if let Some(ptypes) = fn_param_types.get(base) {
            for (i, a) in args.iter().enumerate() {
                if let (Expr::Var(n, _), Some(t)) = (a, ptypes.get(i)) {
                    spine_ty.insert(n.as_str(), t);
                }
            }
        }
    }
    let mut owned = Vec::new();
    let mut owned_drop_ty = Vec::new();
    for p in pats {
        let Pat::Var(n, sp) = p else { continue };
        // user-lambda inferred type (makecon_tys) takes precedence; else the eta spine type.
        let Some(t) = makecon_tys
            .get(sp)
            .or_else(|| spine_ty.get(n.as_str()).copied())
        else {
            continue;
        };
        // a String is moved in like any heap value (`callclo` hands it over)
        let key = if t.head_con() == Some("String") {
            Some("String".to_string())
        } else {
            heap_drop_key(t, data_types, parametric_data, mono_seeds)
        };
        if let Some(key) = key {
            owned.push(n.clone());
            owned_drop_ty.push((n.clone(), Some(key)));
        }
    }
    (owned, owned_drop_ty)
}

/// Lowers a function (top-level or `where`), returning `(params, body,
/// owned-params)`. Single-clause functions with only variable/`_` patterns
/// name the parameters directly (without the redundant alias `let n = _p0`),
/// which gives a more readable Core and clean names for param reclamation.
#[allow(clippy::too_many_arguments, clippy::type_complexity)]
fn lower_func(
    f: &ast::Func,
    arity: usize,
    extra_locals: &HashSet<String>,
    locals: &HashMap<String, String>,
    globals: &HashSet<String>,
    fields: &HashSet<String>,
    lam_meta: &LamMeta,
    inplace: &HashSet<Span>,
    foreigns: &HashMap<String, ForeignInfo>,
    data_types: &HashSet<String>,
    single_con: &HashSet<String>,
    con_ty: &HashMap<String, Option<String>>,
    field_ty: &HashMap<String, String>,
    fn_ret_ty: &HashMap<String, String>,
    parametric_data: &HashSet<String>,
    makecon_tys: &HashMap<Span, Type>,
    array_tys: &HashMap<Span, Type>,
    parmap_workers: &HashMap<String, (String, i32, i32, i32)>,
    fn_arity: &HashMap<String, usize>,
    where_captures: &HashMap<String, Vec<String>>,
    integer_pats: &HashSet<Span>,
    // For a `where`-local (no `f.sig`): its INFERRED param types (position-indexed, `None` when
    // non-ground), so its owned heap params are reclaimed exactly like a signed top-level function.
    inferred_param_tys: Option<&[Option<Type>]>,
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
        field_ty,
        fn_ret_ty,
        locals: locals.clone(),
        tmp: 0,
        makecon_tys,
        array_tys,
        parametric_data,
        mono_seeds: &mut mono_seeds,
        parmap_workers,
        fn_arity,
        where_captures,
        // A lifted `where`-local receives its captured enclosing variables as leading
        // params; they must count as locals in its body too, or a capture whose name
        // collides with a module global would resolve the global (silent miscompile —
        // the body half of the `where h = g + 1` shadow bug; the lambda path does the
        // same via its explicit `local_names.extend(captures)`).
        local_names: {
            let mut ln = func_bound_names(f);
            ln.extend(extra_locals.iter().cloned());
            ln
        },
        integer_pats,
    };
    // A single clause with an IRREFUTABLE head (every param is a `Var`/`Wild`, or a
    // `Con` of a single-constructor type / a `Tuple` whose sub-patterns are also
    // irrefutable) binds unconditionally: `Var` directly, and a `Con`/`Tuple` by
    // DESTRUCTURING the parameter through a one-arm `case` (which binds the field
    // variables — the multi-clause `if`-chain desugar below only binds `Var`
    // params, so `label (Named s k) = …` left `s`/`k` unbound → native "variable
    // not bound"). A REFUTABLE single-clause head (a `Con` of a MULTI-constructor
    // type, or a literal) is a PARTIAL function — there is NO exhaustiveness check
    // on clause heads (AX0202 covers only `case`) — so it must NOT be destructured
    // natively (matching a mismatched constructor is memory-unsafe, and a dropped
    // literal test is a miscompile). It is excluded from native (`Unsupported`), so
    // the interpreter reports the no-match at runtime.
    let single_irrefutable = f.clauses.len() == 1
        && f.clauses[0]
            .pats
            .iter()
            .all(|p| pat_irrefutable(p, single_con));
    let (params, body) = if single_irrefutable {
        let clause = &f.clauses[0];
        let params: Vec<String> = clause
            .pats
            .iter()
            .enumerate()
            .map(|(k, p)| match p {
                Pat::Var(n, _) => n.clone(),
                _ => format!("_p{k}"),
            })
            .collect();
        let mut body = match &clause.body {
            Body::Plain(e) => lw.term(e),
            Body::Guarded(arms) => lw.guarded(arms),
        };
        for (k, p) in clause.pats.iter().enumerate() {
            if matches!(p, Pat::Con(..) | Pat::Tuple(..)) {
                let cpat = lower_pat(p);
                body = Term::Ret(
                    Rhs::Case(Atom::Var(params[k].clone()), vec![(cpat, body)]),
                    NO_SPAN,
                );
            }
        }
        (params, body)
    } else if f.clauses.len() == 1 {
        // partial single clause (refutable head) → interp-only.
        let params: Vec<String> = (0..arity).map(|k| format!("_p{k}")).collect();
        let body = Term::Ret(
            Rhs::Op(Op::Unsupported(
                "partial single-clause head pattern (refutable) — interpreter only".into(),
            )),
            NO_SPAN,
        );
        (params, body)
    } else if f.clauses.iter().any(|c| {
        c.pats
            .iter()
            .any(|p| matches!(p, Pat::Con(..) | Pat::Tuple(..)))
    }) {
        // multi-clause with a constructor/tuple head pattern: the `if`-chain desugar
        // (`lw.clauses`) dispatches only on Int literals, NOT on Con tags — it would
        // select clause 0 unconditionally (a silent miscompile: `fj Nothing = 0;
        // fj (Just x) = x` returns 0 for `fj (Just 5)`) or leave a field binder
        // unbound. Exclude from native (interpreter only) — the documented "write
        // the match with `case`" limitation, now SAFE instead of a miscompile.
        let params: Vec<String> = (0..arity).map(|k| format!("_p{k}")).collect();
        let body = Term::Ret(
            Rhs::Op(Op::Unsupported(
                "constructor pattern in a multi-clause function head — interpreter only".into(),
            )),
            NO_SPAN,
        );
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
    // The per-param "this is an owned heap param → reclaim it" step, shared by the signed path
    // (below) and the `where`-local inferred path. `t` is the param's type, `p` its lowered name.
    let push_owned = |p: &str,
                      t: &Type,
                      owned: &mut Vec<String>,
                      owned_drop_ty: &mut Vec<(String, Option<String>)>,
                      mono_seeds: &mut Vec<Type>| {
        // an owned `Array` frees its block (and, with heap elements, each element)
        if t.head_con() == Some("Array") {
            owned.push(p.to_string());
            owned_drop_ty.push((p.to_string(), Some(array_drop_key(t, data_types))));
            return;
        }
        if matches!(t, Type::Arrow { .. }) {
            owned.push(p.to_string());
            owned_drop_ty.push((p.to_string(), Some("Closure".into())));
            return;
        }
        if !heap_ty(t, data_types) {
            return;
        }
        owned.push(p.to_string());
        let key = if matches!(t, Type::Tuple(_)) {
            let k = mono_key(t);
            if k.is_some() {
                mono_seeds.push(t.clone());
            }
            k
        } else {
            t.head_con().and_then(|h| {
                if parametric_data.contains(h) {
                    mono_key(t).inspect(|_| mono_seeds.push(t.clone()))
                } else {
                    Some(h.to_string())
                }
            })
        };
        owned_drop_ty.push((p.to_string(), key));
    };
    if f.sig.is_none() {
        // A `where`-local (no signature): `inferred_param_tys` is `Some` ONLY when the caller
        // determined this local is a MOVE-CONSUMER (its result is heap, so it is NOT a borrower the
        // parent reclaims) — then it owns + reclaims each of its concrete heap params, exactly like a
        // signed top-level `%1` function. Borrowers (non-heap result) get `None` here → owned stays
        // empty → the parent still deep-drops (unchanged). Lifted capture params precede the local's
        // own params, so align `inferred_param_tys` to the tail.
        if let Some(ptys) = inferred_param_tys {
            let offset = params.len().saturating_sub(ptys.len());
            for (i, pt) in ptys.iter().enumerate() {
                if let Some(t) = pt {
                    push_owned(
                        &params[offset + i],
                        t,
                        &mut owned,
                        &mut owned_drop_ty,
                        &mut mono_seeds,
                    );
                }
            }
        }
    } else if let Some(sig) = &f.sig {
        let mults = sig.param_mults();
        let ptypes = sig.param_types();
        for (i, p) in params.iter().enumerate() {
            if mults.get(i) != Some(&ast::Mult::One) {
                continue;
            }
            let Some(t) = ptypes.get(i) else { continue };
            // an owned `Array` frees its block (and, with heap elements, each element): it was
            // never reclaimed — a `%1` array a function only read leaked
            if t.head_con() == Some("Array") {
                owned.push(p.clone());
                owned_drop_ty.push((p.clone(), Some(array_drop_key(t, data_types))));
                continue;
            }
            // an owned function value: a closure cell (and the captures it owns)
            if matches!(t, Type::Arrow { .. }) {
                owned.push(p.clone());
                owned_drop_ty.push((p.clone(), Some("Closure".into())));
                continue;
            }
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
/// Absorbs the leading lambdas of a definition into the clause parameters: `add = \x -> \y
/// -> x + y` → `add x y = x + y`, and `foo x = \y -> \z -> …` → `foo x y z = …`. A
/// single-clause binding whose (Plain) body is a `\…` chain evaluates, at its declared
/// clause arity, to a curried closure; applying it PAST that arity (`add 21 21`, `foo 10 20
/// 30`) over-applies the returned arity-1 closure — `callclo` passes all remaining args at
/// once and the native backends mishandle it (garbage), because `call_closure` issues one
/// indirect call for every arg regardless of the closure's real arity. Merging the leading
/// lambda params makes it an ordinary multi-parameter function (a DIRECT call), which lowers
/// correctly on every backend. A non-lambda body (a real value-CAF, preserving its single
/// evaluation) or a multi-clause/guarded function is left untouched; a PARTIAL use of the
/// now-wider function (`addN 10`, `foo 10`) is re-expanded to a closure by `eta_expand`
/// below — so a deliberate closure factory still yields a closure, just at the use site.
fn absorb_lambda_caf(mut f: ast::Func) -> ast::Func {
    if f.clauses.len() != 1 || !matches!(f.clauses[0].body, ast::Body::Plain(ast::Expr::Lam(..))) {
        return f;
    }
    let c = &mut f.clauses[0];
    let ast::Body::Plain(mut body) =
        std::mem::replace(&mut c.body, ast::Body::Plain(ast::Expr::Int(0, NO_SPAN)))
    else {
        unreachable!("guarded by the matches! above")
    };
    while let ast::Expr::Lam(pats, lbody, _) = body {
        c.pats.extend(pats);
        body = *lbody;
    }
    c.body = ast::Body::Plain(body);
    f
}

/// Eta-expands the functions/constructors used as a value or partially
/// parcialmente, para o backend nativo (first-class functions via closures).
/// Built-ins with their own lowering (sessions, sockets, arenas, control forms): never wrapped
/// in a lambda (`eta_expand`) or a top-level wrapper (`lib::wrap_builtin_closure_args`).
pub const NOT_ETA: &[&str] = &[
    "bound",
    "spawn",
    "send",
    "recv",
    "newChannel",
    "select",
    "offer",
    "cancel",
    "close",
    "join",
    "split",
    "parMap",
    "connect",
    "pipe3",
    "netListen",
    "netAccept",
    "netConnect",
    "netRecv",
    "netSend",
    "netSendBuf",
    "netClose",
    "netCloseL",
    "withArena",
    "withSubArena",
    "allocateCell",
    "promote",
    "arena_mark",
    "arena_release",
    "imperative",
    "withBuffer",
    "foldBytes",
];

fn eta_expand(module: &ast::Module) -> ast::Module {
    // absorb point-free curried lambdas into clause params first (`add = \x -> \y -> …`
    // → `add x y = …`), so the arities below and the whole lowering see a proper
    // multi-parameter function rather than a nullary CAF over an arity-1 closure.
    let funcs0: Vec<ast::Func> = module
        .funcs
        .iter()
        .cloned()
        .map(absorb_lambda_caf)
        .collect();
    // arity of each callable name: top-level functions (number of patterns), constructors
    // (field count), and the IO builtins that lower to an `Op`.
    let mut arity: HashMap<String, usize> = HashMap::new();
    for f in &funcs0 {
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
    // every built-in function used as a value (`map strLen xs`, `twice (strAppend "x")`) is
    // wrapped in a lambda like a user function — except the ones with their own lowering:
    // sessions, sockets, arenas and the control forms, whose arguments are not plain values.

    for (b, n) in crate::infer::builtin_arities() {
        let symbolic = !b.chars().next().is_some_and(|c| c.is_alphabetic());
        if n > 0 && !symbolic && !NOT_ETA.contains(&b.as_str()) {
            arity.entry(b).or_insert(n);
        }
    }
    let mut e = Eta {
        arity,
        counter: 0,
        bound: std::collections::HashSet::new(),
    };
    let funcs = funcs0.iter().map(|f| e.func(f)).collect();
    ast::Module {
        name: module.name.clone(),
        imports: module.imports.clone(),
        funcs,
        datas: module.datas.clone(),
        foreigns: module.foreigns.clone(),
        foreign_structs: module.foreign_structs.clone(),
        foreign_enums: module.foreign_enums.clone(),
        classes: module.classes.clone(),
        instances: module.instances.clone(),
        level_ceiling: module.level_ceiling,
    }
}

struct Eta {
    arity: HashMap<String, usize>,
    counter: usize,
    /// Names bound in the current lexical scope (function/lambda parameters, `let`
    /// bindings, `case` pattern binders). A bound name SHADOWS the global `arity`
    /// map, so a local variable whose name collides with a top-level/prelude
    /// function (e.g. a parameter `count` vs the prelude's `count`) is NOT mistaken
    /// for that function and eta-expanded into a closure (which silently turned the
    /// value into an arity-N thunk — a miscompile that only bit when the shadowed
    /// name was used as a plain value / argument).
    bound: std::collections::HashSet<String>,
}

/// Collect the variable binders a pattern introduces (recursing into con/tuple
/// sub-patterns). Constructor and literal heads bind nothing.
fn eta_pat_vars(p: &Pat, out: &mut Vec<String>) {
    match p {
        Pat::Var(n, _) => out.push(n.clone()),
        Pat::Con(_, subs, _) | Pat::Tuple(subs, _) => {
            subs.iter().for_each(|s| eta_pat_vars(s, out));
        }
        Pat::Wild(_) | Pat::Int(_, _) | Pat::Str(_, _) => {}
    }
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
            .map(|c| {
                // This clause's parameter binders + its `where` function names are in
                // scope for the body and the where-clauses (which may be mutually
                // recursive) — bind them so none is mistaken for a global callable.
                let mut names = Vec::new();
                for p in &c.pats {
                    eta_pat_vars(p, &mut names);
                }
                names.extend(c.wher.iter().map(|w| w.name.clone()));
                let added = self.push_scope(names);
                let body = match &c.body {
                    Body::Plain(e) => Body::Plain(self.expr(e)),
                    Body::Guarded(arms) => Body::Guarded(
                        arms.iter()
                            .map(|(g, r)| (self.expr(g), self.expr(r)))
                            .collect(),
                    ),
                };
                let wher = c.wher.iter().map(|w| self.func(w)).collect();
                self.pop_scope(added);
                ast::Clause {
                    pats: c.pats.clone(),
                    body,
                    wher,
                    span: c.span,
                }
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
            // A locally-bound variable shadows any same-named global callable, so it
            // is a plain value here — never eta-expand it.
            Expr::Var(n, _) if self.bound.contains(n) => None,
            Expr::Var(n, _) | Expr::Con(n, _) => self.arity.get(n).copied(),
            _ => None,
        }
    }

    /// Enter a scope binding `names`: insert those not already bound, returning the
    /// ones actually added (to `pop_scope` afterwards). Handles shadowing correctly
    /// — a name already bound by an outer scope is left in place.
    fn push_scope(&mut self, names: Vec<String>) -> Vec<String> {
        names
            .into_iter()
            .filter(|n| self.bound.insert(n.clone()))
            .collect()
    }
    fn pop_scope(&mut self, added: Vec<String>) {
        for n in added {
            self.bound.remove(&n);
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
                // `parMap worker xs` / `connect prod cons`: keep the worker argument(s) as bare
                // names (do NOT eta-wrap into `\v -> worker v`), so the native lowering can resolve
                // each to its state machine — mirrors why session lowering runs pre-eta.
                let is_parmap = matches!(head, Expr::Var(n, _) if n == "parMap");
                let is_connect = matches!(head, Expr::Var(n, _) if n == "connect");
                let is_pipe3 = matches!(head, Expr::Var(n, _) if n == "pipe3");
                let targs: Vec<Expr> = args
                    .iter()
                    .enumerate()
                    .map(|(i, a)| {
                        if (is_parmap && i == 0) || (is_connect && i < 2) || (is_pipe3 && i < 3) {
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
            Expr::Let(binds, body, sp) => {
                // let-bound names are in scope for every binding (recursive lets) and
                // the body — bind them so a let name can't be read as a global callable.
                let added = self.push_scope(binds.iter().map(|f| f.name.clone()).collect());
                let nb = binds.iter().map(|f| self.func(f)).collect();
                let body = self.expr(body);
                self.pop_scope(added);
                Expr::Let(nb, Box::new(body), *sp)
            }
            Expr::Case(s, arms, sp) => {
                let scrut = self.expr(s);
                let arms = arms
                    .iter()
                    .map(|(p, b)| {
                        let mut names = Vec::new();
                        eta_pat_vars(p, &mut names);
                        let added = self.push_scope(names);
                        let b = self.expr(b);
                        self.pop_scope(added);
                        (p.clone(), b)
                    })
                    .collect();
                Expr::Case(Box::new(scrut), arms, *sp)
            }
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
            Expr::Lam(ps, body, sp) => {
                let mut names = Vec::new();
                for p in ps {
                    eta_pat_vars(p, &mut names);
                }
                let added = self.push_scope(names);
                let body = self.expr(body);
                self.pop_scope(added);
                Expr::Lam(ps.clone(), Box::new(body), *sp)
            }
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
    match body {
        Expr::Case(scrut, arms, _) => {
            if let (Some("spawn"), args) = sess_spine(scrut) {
                if let (Some(t), _) = sess_spine(args[0]) {
                    out.push(t.to_string());
                }
            }
            for (_, b) in arms {
                spawn_targets(b, out);
            }
        }
        // a branch of the session spine (keep-alive handlers) may spawn too
        Expr::If(_, t, el, _) => {
            spawn_targets(t, out);
            spawn_targets(el, out);
        }
        Expr::Let(_, body, _) => spawn_targets(body, out),
        _ => {}
    }
}

/// A head `gen_cont` lowers as a session operation of its own (a channel or socket op), not as
/// a value to compute.
fn is_sess_op(h: &str) -> bool {
    matches!(
        h,
        "recv"
            | "offer"
            | "spawn"
            | "send"
            | "select"
            | "cancel"
            | "close"
            | "netRecv"
            | "netAccept"
            | "netSend"
            | "netSendBuf"
            | "netListen"
            | "netConnect"
            | "netClose"
            | "netCloseL"
    )
}

/// For every function a session task calls, the argument positions given a variable (the
/// tasks' bodies: `main`'s `bound` block and every worker it reaches).
fn session_call_var_args(module: &ast::Module) -> HashMap<String, HashSet<usize>> {
    fn walk(e: &Expr, out: &mut HashMap<String, HashSet<usize>>) {
        match e {
            Expr::App(..) => {
                let (head, args) = sess_spine(e);
                if let Some(h) = head {
                    for (i, a) in args.iter().enumerate() {
                        if matches!(a, Expr::Var(..)) {
                            out.entry(h.to_string()).or_default().insert(i);
                        }
                    }
                }
                for a in args {
                    walk(a, out);
                }
            }
            Expr::Case(sc, arms, _) => {
                walk(sc, out);
                arms.iter().for_each(|(_, b)| walk(b, out));
            }
            Expr::If(c, t, el, _) => {
                walk(c, out);
                walk(t, out);
                walk(el, out);
            }
            Expr::Let(binds, body, _) => {
                for b in binds {
                    for c in &b.clauses {
                        if let Body::Plain(x) = &c.body {
                            walk(x, out);
                        }
                    }
                }
                walk(body, out);
            }
            Expr::BinOp(_, a, b, _) => {
                walk(a, out);
                walk(b, out);
            }
            Expr::Tuple(es, _) => es.iter().for_each(|x| walk(x, out)),
            _ => {}
        }
    }
    let mut out = HashMap::new();
    let Some(bound) = module
        .funcs
        .iter()
        .find(|f| f.name == "main")
        .and_then(sess_clause_body)
        .and_then(as_bound)
    else {
        return out;
    };
    walk(bound, &mut out);
    for w in session_workers(module, bound) {
        if let Some(b) = sess_clause_body(w) {
            walk(b, &mut out);
        }
    }
    out
}

/// `let x = e` with one parameterless, unguarded binding: `(x, e, body)`. The only `let` shape a
/// session task supports (it lowers to a local, saved across a suspension like any other).
fn sess_let(e: &Expr) -> Option<(&str, &Expr, &Expr)> {
    let Expr::Let(binds, body, _) = e else {
        return None;
    };
    let [b] = binds.as_slice() else { return None };
    let [c] = b.clauses.as_slice() else {
        return None;
    };
    match (&c.body, c.pats.is_empty()) {
        (Body::Plain(rhs), true) => Some((b.name.as_str(), rhs, body)),
        _ => None,
    }
}

/// The heads of the session spine's TAIL calls (`… ; sendAll s msg 0`), through `case`
/// continuations and `if` branches.
fn sess_tail_calls(body: &Expr, out: &mut Vec<String>) {
    match body {
        Expr::Case(_, arms, _) => arms.iter().for_each(|(_, b)| sess_tail_calls(b, out)),
        Expr::If(_, t, el, _) => {
            sess_tail_calls(t, out);
            sess_tail_calls(el, out);
        }
        Expr::Let(_, body, _) => sess_tail_calls(body, out),
        _ => {
            if let (Some(h), _) = sess_spine(body) {
                out.push(h.to_string());
            }
        }
    }
}

/// `true` if `f` takes a socket, listener or channel endpoint: a function that can only run as a
/// session task (its socket ops suspend), never as an ordinary native call.
fn takes_session_resource(f: &ast::Func) -> bool {
    f.sig.as_ref().is_some_and(|s| {
        s.param_types()
            .iter()
            .any(|t| matches!(t.head_con(), Some("Sock" | "Listener" | "Ep")))
    })
}

/// Every function that runs as a session task under `main`'s `bound` body: the transitive `spawn`
/// targets, plus each function a task TAIL-calls that takes a session resource (`handler s = do
/// … ; sendAll s msg 0`). Such a tail call hands the task over (see `SessGen::gen_tail`).
fn session_workers<'m>(module: &'m ast::Module, bound_body: &Expr) -> Vec<&'m ast::Func> {
    let mut workers: Vec<&ast::Func> = Vec::new();
    let mut seen = HashSet::new();
    let mut worklist = Vec::new();
    let push_from = |b: &Expr, worklist: &mut Vec<String>| {
        spawn_targets(b, worklist);
        let mut tails = Vec::new();
        sess_tail_calls(b, &mut tails);
        for t in tails {
            if module
                .funcs
                .iter()
                .any(|f| f.name == t && takes_session_resource(f))
            {
                worklist.push(t);
            }
        }
    };
    push_from(bound_body, &mut worklist);
    while let Some(name) = worklist.pop() {
        if !seen.insert(name.clone()) {
            continue;
        }
        if let Some(wf) = module.funcs.iter().find(|f| f.name == name) {
            workers.push(wf);
            if let Some(b) = sess_clause_body(wf) {
                push_from(b, &mut worklist);
            }
        }
    }
    workers
}

/// All variables bound (by patterns) anywhere in a session body.
fn collect_bound_vars(e: &Expr, out: &mut Vec<String>) {
    if let Expr::Case(_, arms, _) = e {
        for (pat, body) in arms {
            pat_vars(pat, out);
            collect_bound_vars(body, out);
        }
    } else if let Expr::If(_, t, el, _) = e {
        collect_bound_vars(t, out);
        collect_bound_vars(el, out);
    } else if let Some((x, _, body)) = sess_let(e) {
        out.push(x.to_string());
        collect_bound_vars(body, out);
    }
}

/// Collects the suspension points (`recv` value, `offer` label) in DFS order,
/// each with the variables live in scope just before it (params + earlier binds).
fn collect_suspensions<'a>(
    e: &'a Expr,
    scope: &mut Vec<String>,
    out: &mut Vec<(&'a Expr, Vec<String>)>,
) {
    // Descend both arms of an `if` in the session spine (they bind no new vars at the `if` itself),
    // so suspensions inside a branch (e.g. `netSend` in a keep-alive loop) get resume indices.
    if let Expr::If(_, then_e, else_e, _) = e {
        collect_suspensions(then_e, scope, out);
        collect_suspensions(else_e, scope, out);
        return;
    }
    if let Some((x, _, body)) = sess_let(e) {
        scope.push(x.to_string());
        collect_suspensions(body, scope, out);
        scope.pop();
        return;
    }
    let Expr::Case(scrut, arms, _) = e else {
        return;
    };
    let head = sess_spine(scrut).0;
    let is_offer = head == Some("offer");
    // Async sockets (docs/async-sockets.md): netRecv/netAccept/netSend can yield the would-block
    // sentinel, so they are suspension points too (park on the fd, resume on readiness).
    let is_netsusp = matches!(
        head,
        Some("netRecv" | "netAccept" | "netSend" | "netSendBuf")
    );
    if head == Some("recv") || is_offer || is_netsusp {
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
    /// Heap reclamation inside the task (`None` = untracked, the parMap workers).
    own: Option<SessOwn<'a>>,
}

/// A session task's ownership state at one point: its owned heap locals (with drop keys) and
/// the locals it has given away.
type OwnState = (Vec<(String, String)>, HashSet<String>);

/// What a session task needs to reclaim the heap values it owns: who owns which parameter, which
/// calls return fresh values, and the per-path ownership state while generating.
struct SessOwn<'a> {
    funcs: &'a HashMap<String, &'a ast::Func>,
    ret_alias: &'a HashMap<String, HashSet<usize>>,
    /// worker parameters that some call site fills with a value the caller does not own: never
    /// freed by the worker (`(worker, index)`; grown to a fixpoint by `session_fns`).
    demoted: &'a std::cell::RefCell<HashSet<(String, usize)>>,
    /// heap locals this task owns on the current path, with their drop key
    owned: Vec<(String, String)>,
    /// fresh heap temporaries of the operation being generated, freed once it has run
    pending: Vec<(String, String)>,
    /// heap locals given away on the current path (a later read would be a use after free)
    moved: HashSet<String>,
    /// the ownership state on entry to each suspension, for its resume region
    at_susp: HashMap<i32, OwnState>,
    /// inferred types by span: a `send` payload at its expression's span, a `recv` payload at the
    /// `recv` name's span (see `infer`), plus every call's result type
    tys: &'a HashMap<Span, Type>,
    /// payload types read off the task's protocols (same keys; preferred over `tys`, which
    /// leaves an unused received value's type open)
    proto: HashMap<Span, Type>,
    /// constructor → its `data` type's parameters and field types (for a `case` on data)
    cons: &'a HashMap<String, (Vec<String>, Vec<Type>)>,
    /// per native function, the parameters it only borrows (the rest it consumes)
    borrow: &'a BorrowArgs,
    /// per native function, the parameters it frees on some path (it owns them, whatever
    /// `borrow` says — e.g. a conditionally-escaping parameter freed on the other branch)
    frees: &'a HashMap<String, HashSet<usize>>,
    /// `data` types with a constructor that has fields (their values are heap cells)
    boxed: &'a HashSet<String>,
    /// the known type of a local (parameter, `let`, constructor field)
    var_tys: HashMap<String, Type>,
    /// parametric `data` instances a task frees whole (`List$String`): their destructors are
    /// generated after the session steps
    drop_seeds: &'a std::cell::RefCell<Vec<Type>>,
}

/// A session protocol at some point of a task: the current type, and the enclosing `Rec` a
/// `Loop` stands for.
type Proto = (Type, Option<Type>);

fn ty_apply(head: &str, args: Vec<Type>) -> Type {
    args.into_iter().fold(Type::Con(head.to_string()), |f, a| {
        Type::App(Box::new(f), Box::new(a))
    })
}

/// Unfolds `Rec S` (remembering it for `Loop`) and `Loop` until a protocol step shows. Bounded:
/// a degenerate `Rec Loop` has no step, and gives `None`.
fn proto_norm((mut t, mut rec): Proto) -> Option<Proto> {
    for _ in 0..8 {
        let next = match ty_head_args(&t) {
            (Some("Rec"), a) if a.len() == 1 => a[0].clone(),
            (Some("Loop"), a) if a.is_empty() => rec.clone()?,
            _ => return Some((t, rec)),
        };
        if matches!(ty_head_args(&t).0, Some("Rec")) {
            rec = Some(t);
        }
        t = next;
    }
    None
}

/// The other end's protocol: sends and receives swap, as do `Select` and `Offer`.
fn proto_dual(t: &Type) -> Type {
    let (h, a) = ty_head_args(t);
    match h {
        Some("Send") if a.len() == 2 => ty_apply("Recv", vec![a[0].clone(), proto_dual(a[1])]),
        Some("Recv") if a.len() == 2 => ty_apply("Send", vec![a[0].clone(), proto_dual(a[1])]),
        Some(sel @ ("Select" | "Offer")) => {
            let other = if sel == "Select" { "Offer" } else { "Select" };
            let branches = a
                .iter()
                .map(|b| match ty_head_args(b) {
                    (Some(l), ba) if ba.len() == 1 => ty_apply(l, vec![proto_dual(ba[0])]),
                    _ => (*b).clone(),
                })
                .collect();
            ty_apply(other, branches)
        }
        Some("Rec") if a.len() == 1 => ty_apply("Rec", vec![proto_dual(a[0])]),
        _ => t.clone(),
    }
}

/// The protocol of an endpoint type `Ep P`.
fn ep_proto(t: &Type) -> Option<Type> {
    match ty_head_args(t) {
        (Some("Ep" | "Channel" | "Chan" | "Endpoint"), a) if a.len() == 1 => Some(a[0].clone()),
        _ => None,
    }
}

/// The type of every channel payload in a task body, read off its endpoints' protocols: a `recv`
/// payload keyed by the `recv` name's span, a `send` payload by the sent expression's span (the
/// keys `infer` uses). Endpoints start from the task's `Ep` parameters and from `spawn` (the dual
/// of the worker's endpoint parameter); each operation advances its endpoint's protocol.
fn sess_payload_types(
    pats: &[Pat],
    sig: Option<&Type>,
    body: &Expr,
    funcs: &HashMap<String, &ast::Func>,
) -> HashMap<Span, Type> {
    let mut env: HashMap<String, Proto> = HashMap::new();
    if let Some(sig) = sig {
        for (p, t) in pats.iter().zip(sig.param_types()) {
            if let (Pat::Var(n, _), Some(pr)) = (p, ep_proto(t)) {
                env.insert(n.clone(), (pr, None));
            }
        }
    }
    let mut out = HashMap::new();
    payload_walk(body, &mut env, funcs, &mut out);
    out
}

fn payload_walk(
    e: &Expr,
    env: &mut HashMap<String, Proto>,
    funcs: &HashMap<String, &ast::Func>,
    out: &mut HashMap<Span, Type>,
) {
    if let Expr::If(_, t, el, _) = e {
        payload_walk(t, env, funcs, out);
        payload_walk(el, env, funcs, out);
        return;
    }
    if let Some((_, _, body)) = sess_let(e) {
        payload_walk(body, env, funcs, out);
        return;
    }
    let Expr::Case(scrut, arms, _) = e else {
        return;
    };
    let (head, args) = sess_spine(scrut);
    let ep_of = |a: &Expr, env: &HashMap<String, Proto>| match a {
        Expr::Var(n, _) => env.get(n).cloned().and_then(proto_norm),
        _ => None,
    };
    let bind = |p: &Pat, pr: Proto, env: &mut HashMap<String, Proto>| {
        if let Pat::Var(n, _) = p {
            env.insert(n.clone(), pr);
        }
    };
    match (head, arms.as_slice()) {
        (Some("recv"), [(pat, _)]) if !args.is_empty() => {
            if let Some((t, rec)) = ep_of(args[0], env) {
                if let (Some("Recv"), a) = ty_head_args(&t) {
                    if a.len() == 2 {
                        if let Some(sp) = spine_head_span(scrut) {
                            out.insert(sp, a[0].clone());
                        }
                        if let Pat::Tuple(ps, _) = pat {
                            if let Some(p) = ps.get(1) {
                                bind(p, (a[1].clone(), rec), env);
                            }
                        }
                    }
                }
            }
        }
        (Some("send"), [(pat, _)]) if args.len() >= 2 => {
            if let Some((t, rec)) = ep_of(args[0], env) {
                if let (Some("Send"), a) = ty_head_args(&t) {
                    if a.len() == 2 {
                        out.insert(args[1].span(), a[0].clone());
                        bind(pat, (a[1].clone(), rec), env);
                    }
                }
            }
        }
        (Some("select"), [(pat, _)]) if args.len() >= 2 => {
            if let (Expr::Con(label, _), Some((t, rec))) = (args[0], ep_of(args[1], env)) {
                if let (Some("Select"), bs) = ty_head_args(&t) {
                    for b in bs {
                        if let (Some(l), ba) = ty_head_args(b) {
                            if l == label {
                                let cont =
                                    ba.first().map_or(Type::Con("End".into()), |c| (*c).clone());
                                bind(pat, (cont, rec.clone()), env);
                            }
                        }
                    }
                }
            }
        }
        (Some("offer"), _) if !args.is_empty() => {
            if let Some((t, rec)) = ep_of(args[0], env) {
                if let (Some("Offer"), bs) = ty_head_args(&t) {
                    for (pat, _) in arms {
                        if let Pat::Con(label, sub, _) = pat {
                            for b in &bs {
                                if let (Some(l), ba) = ty_head_args(b) {
                                    if l == label {
                                        let cont = ba
                                            .first()
                                            .map_or(Type::Con("End".into()), |c| (*c).clone());
                                        if let Some(p) = sub.first() {
                                            bind(p, (cont, rec.clone()), env);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        (Some("spawn"), [(pat, _)]) if !args.is_empty() => {
            // the parent's end of a spawned worker's channel: the dual of its endpoint parameter
            let target = sess_spine(args[0]).0.and_then(|w| funcs.get(w));
            let proto = target
                .and_then(|f| f.sig.as_ref())
                .and_then(|s| s.param_types().into_iter().rev().find_map(ep_proto));
            if let Some(pr) = proto {
                bind(pat, (proto_dual(&pr), None), env);
            }
        }
        _ => {}
    }
    for (_, b) in arms {
        payload_walk(b, env, funcs, out);
    }
}

/// The span of the head name of an application spine (`recv` in `recv c`).
fn spine_head_span(e: &Expr) -> Option<Span> {
    match e {
        Expr::App(f, _, _) => spine_head_span(f),
        Expr::Var(_, sp) => Some(*sp),
        _ => None,
    }
}

/// The drop key of a session-held heap value whose destructor needs no per-instance seed.
/// Other heap types are left unreclaimed inside a task (they are not tracked).
fn sess_drop_key(t: &Type) -> Option<String> {
    match t.head_con() {
        Some(h @ ("String" | "Integer" | "Buffer")) => Some(h.to_string()),
        _ => None,
    }
}

/// The result type of a signature: what is left after its top-level arrows.
fn sig_result(t: &Type) -> &Type {
    match t {
        Type::Arrow { to, .. } => sig_result(to),
        _ => t,
    }
}

/// The drop key of a built-in's freshly allocated result (its arguments are only read): a `String`
/// producer, or `fileRead`'s `Buffer`. `None` for a scalar or borrowed result.
fn sess_fresh_builtin(name: &str) -> Option<&'static str> {
    if name == "fileRead" {
        return Some("Buffer");
    }
    sess_fresh_string_builtin(name).then_some("String")
}

/// Built-ins whose `String` result is freshly allocated and whose arguments are only read.
fn sess_fresh_string_builtin(name: &str) -> bool {
    matches!(
        name,
        "strAppend"
            | "substr"
            | "showFloat"
            | "showInteger"
            | "getEnv"
            | "runCapture"
            | "execCapture"
            | "readFile"
            | "readDir"
            | "readDirTyped"
            | "readDirListing"
            | "readLine"
            | "readSecret"
            | "chr"
            | "randHex"
            | "getArg"
    )
}

impl SessGen<'_> {
    fn fresh(&mut self) -> String {
        let n = self.tmp;
        self.tmp += 1;
        format!("sess$t{n}")
    }

    /// Stops tracking `v` (moved, or given to an owner we cannot follow). `true` if it was owned.
    fn take_var(&mut self, v: &str) -> bool {
        let Some(o) = self.own.as_mut() else {
            return false;
        };
        let before = o.owned.len() + o.pending.len();
        o.owned.retain(|(n, _)| n != v);
        o.pending.retain(|(n, _)| n != v);
        before != o.owned.len() + o.pending.len()
    }

    /// The drop key of parameter `i` of session worker `w`, if the worker owns (and frees) it.
    fn worker_param_key(&self, w: &str, i: usize) -> Option<String> {
        let o = self.own.as_ref()?;
        if o.demoted.borrow().contains(&(w.to_string(), i)) {
            return None;
        }
        let f = o.funcs.get(w)?;
        self.owned_key(f.sig.as_ref()?.param_types().get(i)?)
    }

    /// The drop key of a heap value of type `t` a task can own: a String/Integer/Buffer, or a
    /// `data` value with a heap cell (freed by its destructor; a parametric one is seeded).
    fn owned_key(&self, t: &Type) -> Option<String> {
        if let Some(k) = sess_drop_key(t) {
            return Some(k);
        }
        let o = self.own.as_ref()?;
        let head = t.head_con()?;
        if !o.boxed.contains(head) {
            return None;
        }
        let key = mono_key(t)?;
        if key.contains('$') {
            o.drop_seeds.borrow_mut().push(t.clone());
        }
        Some(key)
    }

    /// The type of a session expression, when known: a local's, or a call's inferred result.
    fn expr_ty(&self, e: &Expr) -> Option<Type> {
        let o = self.own.as_ref()?;
        match e {
            Expr::Var(n, _) => o.var_tys.get(n).cloned(),
            Expr::App(..) => o.tys.get(&e.span()).cloned(),
            _ => None,
        }
    }

    /// `case v of C x y -> … ; D -> … ; _ -> …` on a `data` value (constructor arms with variable
    /// or `_` fields, then an optional catch-all). An owned scrutinee is consumed: each arm frees
    /// the cell and owns the fields (a heap field bound to `_` is freed at once); a catch-all arm
    /// keeps it whole. A scrutinee the task does not own is only read.
    fn gen_case(&mut self, scrut: &Expr, arms: &[(Pat, Expr)]) -> Term {
        let mut binds = Vec::new();
        let sty = self.expr_ty(scrut);
        let a = self.val(scrut, &mut binds);
        let owned_key = match &a {
            Atom::Var(v) => {
                let key = self.own.as_ref().and_then(|o| {
                    o.owned
                        .iter()
                        .chain(o.pending.iter())
                        .find(|(n, _)| n == v)
                        .map(|(_, k)| k.clone())
                });
                if key.is_some() {
                    self.take_var(v);
                }
                key
            }
            _ => None,
        };
        let tmps = self.take_pending();
        let st = self.save_own();
        let mut carms = Vec::new();
        for (pat, body) in arms {
            self.restore_own(&st);
            let mut pre = Vec::new(); // frees at the arm's entry
            let cpat = match pat {
                Pat::Con(c, subs, _) => {
                    let ftys = self.con_field_tys(c, sty.as_ref());
                    let mut csubs = Vec::new();
                    for (i, sp) in subs.iter().enumerate() {
                        let fty = ftys.as_ref().and_then(|f| f.get(i)).cloned();
                        let key = match (&owned_key, &fty) {
                            (Some(_), Some(t)) => self.owned_key(t),
                            _ => None,
                        };
                        match sp {
                            Pat::Var(n, _) => {
                                if let (Some(t), Some(o)) = (&fty, self.own.as_mut()) {
                                    o.var_tys.insert(n.clone(), t.clone());
                                }
                                if let (Some(k), Some(o)) = (key, self.own.as_mut()) {
                                    o.owned.push((n.clone(), k));
                                }
                                csubs.push(CPat::Var(n.clone()));
                            }
                            _ => match key {
                                Some(k) => {
                                    let n = self.fresh();
                                    pre.push((n.clone(), k));
                                    csubs.push(CPat::Var(n));
                                }
                                None => csubs.push(CPat::Wild),
                            },
                        }
                    }
                    // the consumed cell itself (a nullary constructor is no cell)
                    if let (Some(_), Atom::Var(v), false) = (&owned_key, &a, subs.is_empty()) {
                        let t = Self::drop_all(pre, self.gen_cont(body));
                        carms.push((
                            CPat::Con(c.clone(), csubs),
                            Term::Drop(v.clone(), None, Vec::new(), NO_SPAN, Box::new(t)),
                        ));
                        continue;
                    }
                    CPat::Con(c.clone(), csubs)
                }
                Pat::Var(n, _) => {
                    // catch-all binding the whole value: it owns what the scrutinee owned
                    if let (Some(k), Some(o)) = (&owned_key, self.own.as_mut()) {
                        o.owned.push((n.clone(), k.clone()));
                    }
                    if let (Some(t), Some(o)) = (&sty, self.own.as_mut()) {
                        o.var_tys.insert(n.clone(), t.clone());
                    }
                    CPat::Var(n.clone())
                }
                _ => {
                    if let (Some(k), Atom::Var(v)) = (&owned_key, &a) {
                        pre.push((v.clone(), k.clone()));
                    }
                    CPat::Wild
                }
            };
            carms.push((cpat, Self::drop_all(pre, self.gen_cont(body))));
        }
        self.restore_own(&st);
        wrap(
            binds,
            Self::drop_all(tmps, Term::Ret(Rhs::Case(a, carms), NO_SPAN)),
            NO_SPAN,
        )
    }

    /// Constructor `c`'s field types at the scrutinee type `sty` (its `data` parameters replaced
    /// by `sty`'s arguments).
    fn con_field_tys(&self, c: &str, sty: Option<&Type>) -> Option<Vec<Type>> {
        let o = self.own.as_ref()?;
        let (params, fields) = o.cons.get(c)?;
        let args: Vec<Type> = sty
            .map(|t| ty_head_args(t).1.into_iter().cloned().collect())
            .unwrap_or_default();
        if params.is_empty() {
            return Some(fields.clone());
        }
        if params.len() != args.len() {
            return None;
        }
        let sub: HashMap<String, Type> = params.iter().cloned().zip(args).collect();
        Some(fields.iter().map(|f| subst_ty(f, &sub)).collect())
    }

    /// Hands argument `a` to parameter `i` of worker `w` (a spawn, a hand-off, a loop). An owned
    /// value moves with it; a value we do not own cannot become the worker's to free, so that
    /// parameter is demoted (never freed by the worker) and generation is redone.
    /// Returns the atom to store in the parameter. A value this task does not own (an alias of
    /// one it does, a field of a value it only reads) may be freed by this task once the call
    /// is made — the hand-off ends it, a loop's back-edge frees the old iteration's values — so
    /// the worker gets a copy of a String/Integer/Buffer; a `data` value it cannot copy is
    /// outside the native subset.
    fn give_to_worker(
        &mut self,
        w: &str,
        i: usize,
        a: &Atom,
        binds: &mut Vec<(String, Rhs)>,
    ) -> Atom {
        let Atom::Var(v) = a else { return a.clone() };
        if self.own.is_none() {
            return a.clone();
        }
        if self.take_var(v) {
            // moved: the worker frees it (or, when it does not own the parameter, nobody does)
            if let Some(o) = self.own.as_mut() {
                o.moved.insert(v.clone());
            }
            return a.clone();
        }
        let pty = self
            .own
            .as_ref()
            .and_then(|o| o.funcs.get(w))
            .and_then(|f| f.sig.as_ref())
            .and_then(|s| s.param_types().get(i).map(|t| (*t).clone()));
        match pty.as_ref() {
            Some(t) if sess_drop_key(t).is_some() => {
                let key = sess_drop_key(t).unwrap_or_default();
                self.copy_of(&key, a, binds)
            }
            Some(t) if self.owned_key(t).is_some() => self.unsupported(binds),
            _ => a.clone(),
        }
    }

    /// A fresh copy of a String/Integer/Buffer value (keyed by `key`).
    fn copy_of(&mut self, key: &str, a: &Atom, binds: &mut Vec<(String, Rhs)>) -> Atom {
        let (func, extra) = match key {
            "Integer" => ("axion_bignum_copy", None),
            "Buffer" => ("axion_buf_copy", None),
            _ => ("axion_strcat", Some(Atom::Str(String::new()))),
        };
        let mut cargs = vec![a.clone()];
        cargs.extend(extra);
        let c = self.fresh();
        binds.push((c.clone(), Self::rt(func, cargs, true)));
        Atom::Var(c)
    }

    /// The drop key of a channel payload whose type inference recorded at `sp`, when the task
    /// tracks ownership and the type is one it reclaims.
    fn payload_key(&self, sp: Option<Span>) -> Option<String> {
        let o = self.own.as_ref()?;
        let sp = sp?;
        sess_drop_key(o.proto.get(&sp).or_else(|| o.tys.get(&sp))?)
    }

    /// `drop` every listed value, then `k`.
    fn drop_all(list: Vec<(String, String)>, k: Term) -> Term {
        list.into_iter().rev().fold(k, |acc, (v, key)| {
            Term::Drop(v, Some(key), Vec::new(), NO_SPAN, Box::new(acc))
        })
    }

    /// The pending temporaries of the operation just generated.
    fn take_pending(&mut self) -> Vec<(String, String)> {
        self.own
            .as_mut()
            .map(|o| std::mem::take(&mut o.pending))
            .unwrap_or_default()
    }

    /// Everything the task still owns on this path (its terminal: done, loop or hand-off).
    fn take_all_owned(&mut self) -> Vec<(String, String)> {
        let Some(o) = self.own.as_mut() else {
            return Vec::new();
        };
        let mut all = std::mem::take(&mut o.owned);
        all.append(&mut o.pending);
        all
    }

    fn save_own(&self) -> Option<OwnState> {
        self.own
            .as_ref()
            .map(|o| (o.owned.clone(), o.moved.clone()))
    }

    fn restore_own(&mut self, st: &Option<OwnState>) {
        if let (Some(o), Some((ow, mv))) = (self.own.as_mut(), st) {
            o.owned = ow.clone();
            o.moved = mv.clone();
            o.pending.clear();
        }
    }

    /// Records the ownership state on entry to suspension `idx` (its resume region starts there).
    fn note_susp(&mut self, idx: i32) {
        if let Some(o) = self.own.as_mut() {
            o.at_susp
                .entry(idx)
                .or_insert_with(|| (o.owned.clone(), o.moved.clone()));
        }
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
            // a static literal: never freed (the String drop skips literals), copied when sent
            Expr::Str(s, _) => Atom::Str(s.clone()),
            Expr::Con(c, _) if c == "True" => Atom::Int(1),
            Expr::Con(c, _) if c == "False" => Atom::Int(0),
            // a value-position `if` (`a && b` desugars to one): each branch computes its value; a
            // branch that makes a heap temporary would own it on one path only — unsupported
            Expr::If(c, t, el, _) => {
                let cv = self.val(c, binds);
                let before = self.own.as_ref().map(|o| (o.pending.len(), o.owned.len()));
                let mut arms = Vec::new();
                for e in [t, el] {
                    let mut b = Vec::new();
                    let v = self.val(e, &mut b);
                    arms.push(wrap(b, Term::Ret(Rhs::Op(Op::Atom(v)), NO_SPAN), NO_SPAN));
                }
                // a branch that makes or gives away a heap value would change ownership on one
                // path only
                if self.own.as_ref().map(|o| (o.pending.len(), o.owned.len())) != before {
                    return self.unsupported(binds);
                }
                let (et, tt) = (arms.pop(), arms.pop());
                let (Some(tt), Some(et)) = (tt, et) else {
                    return self.unsupported(binds);
                };
                let r = self.fresh();
                binds.push((r.clone(), Rhs::If(cv, Box::new(tt), Box::new(et))));
                Atom::Var(r)
            }
            Expr::Var(n, _) => {
                if self.own.as_ref().is_some_and(|o| o.moved.contains(n)) {
                    // read after it was handed to another task or an owning call
                    return self.unsupported(binds);
                }
                Atom::Var(n.clone())
            }
            Expr::BinOp(op, a, b, _) => {
                let av = self.val(a, binds);
                let bv = self.val(b, binds);
                let t = self.fresh();
                // Float (`+.`) and arbitrary-precision Integer (`#I`) operators lower
                // like they do on the normal path, not as an integer `Prim`.
                let rhs = if is_float_op(op) {
                    Rhs::Op(Op::PrimF(op.clone(), av, bv))
                } else if let Some(func) = integer_op_rt(op) {
                    Rhs::Op(Op::RtCall {
                        func: func.into(),
                        args: vec![av, bv],
                        returns: true,
                    })
                } else {
                    Rhs::Op(Op::Prim(op.clone(), av, bv))
                };
                binds.push((t.clone(), rhs));
                Atom::Var(t)
            }
            // a call to a top-level native function (e.g. `fib n`), or a runtime
            // builtin (e.g. `fromInt` — §Listing 1.4) — lets a worker do real compute
            // between channel ops. Named callees compile by the normal native path.
            Expr::App(..) => {
                let (head, args) = sess_spine(e);
                if let Some(name) = head.filter(|n| self.fns.contains(*n)) {
                    let name = name.to_string();
                    let mut atoms: Vec<Atom> = args.iter().map(|a| self.val(a, binds)).collect();
                    let t = self.fresh();
                    // ownership across the call, as the native code decided it (`borrow_args`,
                    // not only the written `%1`): a parameter the callee consumes takes the
                    // argument — an owned value moves, one this task does not own is passed as
                    // a copy (else the callee would free what another owner frees).
                    let sig = self
                        .own
                        .as_ref()
                        .and_then(|o| o.funcs.get(&name))
                        .and_then(|f| f.sig.clone());
                    let mut consumed: HashSet<usize> = HashSet::new();
                    if let Some(sig) = &sig {
                        let mults = sig.param_mults();
                        let ptys: Vec<Type> = sig.param_types().into_iter().cloned().collect();
                        let borrowed = self.own.as_ref().and_then(|o| o.borrow.get(&name)).cloned();
                        let frees = self.own.as_ref().and_then(|o| o.frees.get(&name)).cloned();
                        for (i, atom) in atoms.iter_mut().enumerate() {
                            let takes = frees.as_ref().is_some_and(|f| f.contains(&i))
                                || match &borrowed {
                                    Some(b) => !b.contains(&i),
                                    None => mults.get(i) == Some(&ast::Mult::One),
                                };
                            let heap = ptys.get(i).and_then(|t| self.owned_key(t));
                            if !takes || heap.is_none() {
                                continue;
                            }
                            consumed.insert(i);
                            let Atom::Var(v) = atom.clone() else {
                                continue;
                            };
                            if self.take_var(&v) {
                                if let Some(o) = self.own.as_mut() {
                                    o.moved.insert(v);
                                }
                            } else {
                                let pk = ptys.get(i).and_then(sess_drop_key);
                                *atom = match pk {
                                    Some(k) => self.copy_of(&k, atom, binds),
                                    None => self.unsupported(binds),
                                };
                            }
                        }
                    }
                    binds.push((
                        t.clone(),
                        Rhs::Op(Op::CallDirect(name.clone(), atoms.clone(), None)),
                    ));
                    if let Some(sig) = &sig {
                        // fresh unless it may return a parameter it only borrowed (one it took
                        // and hands back is still the caller's to free)
                        let fresh = self.own.as_ref().is_some_and(|o| {
                            o.ret_alias
                                .get(&name)
                                .is_none_or(|s| s.iter().all(|i| consumed.contains(i)))
                        });
                        if let Some(key) = self.owned_key(sig_result(sig)).filter(|_| fresh) {
                            if let Some(o) = self.own.as_mut() {
                                o.pending.push((t.clone(), key));
                            }
                        } else if let Some(o) = self.own.as_mut() {
                            // the result may BE a borrowed argument (`idI (fromInt n)`): a fresh
                            // temporary passed there is owned by the result from now on, so it is
                            // freed (or moved on) once, through the result — not after the call.
                            let alias: Vec<usize> = o
                                .ret_alias
                                .get(&name)
                                .map(|s| {
                                    s.iter()
                                        .copied()
                                        .filter(|i| !consumed.contains(i))
                                        .collect()
                                })
                                .unwrap_or_default();
                            for i in alias {
                                let Some(Atom::Var(v)) = atoms.get(i) else {
                                    continue;
                                };
                                if let Some(at) = o.pending.iter().position(|(p, _)| p == v) {
                                    let (_, key) = o.pending.remove(at);
                                    o.pending.push((t.clone(), key));
                                }
                            }
                        }
                    }
                    Atom::Var(t)
                } else if let (Some(h @ ("showInt" | "putStrLn" | "putStr")), [x]) =
                    (head, args.as_slice())
                {
                    // built-ins with their own Core op: `showInt` makes a fresh String; the
                    // writes only read theirs
                    let a = self.val(x, binds);
                    let t = self.fresh();
                    let op = match h {
                        "showInt" => Op::ShowInt(a),
                        "putStrLn" => Op::PutStrLn(a),
                        _ => Op::PutStr(a),
                    };
                    binds.push((t.clone(), Rhs::Op(op)));
                    if h == "showInt" {
                        if let Some(o) = self.own.as_mut() {
                            o.pending.push((t.clone(), "String".into()));
                        }
                    }
                    Atom::Var(t)
                } else if let Some((func, arity)) = head.and_then(sess_builtin_rt) {
                    if args.len() == arity {
                        let atoms: Vec<Atom> = args.iter().map(|a| self.val(a, binds)).collect();
                        let t = self.fresh();
                        binds.push((
                            t.clone(),
                            Rhs::Op(Op::RtCall {
                                func: func.into(),
                                args: atoms,
                                returns: true,
                            }),
                        ));
                        // a fresh heap result the task owns: per the runtime ownership table (the
                        // one authority — `fromInt`'s Integer, `strAppend`'s String, …) when the
                        // call only reads its arguments, else the session's own list.
                        let table = crate::builtins::rt_entry(func).and_then(|e| match e {
                            crate::builtins::RtEntry {
                                args: crate::builtins::ArgOwn::Borrow,
                                out: crate::builtins::Out::Owned(k),
                                ..
                            } => Some(*k),
                            _ => None,
                        });
                        if let Some(key) = table.or_else(|| head.and_then(sess_fresh_builtin)) {
                            if let Some(o) = self.own.as_mut() {
                                o.pending.push((t.clone(), key.into()));
                            }
                        }
                        Atom::Var(t)
                    } else {
                        self.unsupported(binds)
                    }
                } else {
                    self.unsupported(binds)
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
        // self-recursive session tail call `f a… d` (§6, server loop): store each
        // new argument into its parameter slot — the endpoint AND any accumulator
        // state threaded across the loop (`server (acc + n) d`) — reset the resume
        // tag to the loop head, and return status 2 (re-queue) so the scheduler
        // re-dispatches the task.
        let (head, args) = sess_spine(tail);
        let slots: Vec<i32> = self.lay.param_slots.clone();
        if head == Some(self.name) && !slots.is_empty() && args.len() == slots.len() {
            let mut binds = Vec::new();
            // compute all new values first (they read the current locals), then write
            // each into its slot, so an accumulator's update can't clobber a later read.
            let mut vals = Vec::with_capacity(args.len());
            for a in &args {
                vals.push(self.val(a, &mut binds));
            }
            let me = self.name.to_string();
            let vals: Vec<Atom> = vals
                .iter()
                .enumerate()
                .map(|(i, v)| self.give_to_worker(&me, i, v, &mut binds))
                .collect();
            for (slot, v) in slots.iter().zip(vals) {
                binds.push((
                    self.fresh(),
                    Rhs::Op(Op::StoreRaw(Self::state_atom(), *slot, v)),
                ));
            }
            binds.push((
                self.fresh(),
                Rhs::Op(Op::StoreRaw(Self::state_atom(), 8, Atom::Int(0))),
            ));
            // the previous iteration's values that were not passed on die here
            let dead = self.take_all_owned();
            return wrap(
                binds,
                Self::drop_all(dead, Term::Ret(Rhs::Op(Op::Atom(Atom::Int(2))), NO_SPAN)),
                NO_SPAN,
            );
        }
        // Hand-off: a tail call to ANOTHER session task (`handler s = do … ; sendAll s msg 0`).
        // Nothing runs after a tail call, so spawning the callee as a fresh task with every
        // parameter seeded and finishing this one is the same computation; the linear socket
        // moves to the new task with its argument.
        if let Some(h) = head.filter(|h| *h != self.name) {
            if let Some(tl) = self.all.get(h) {
                if !tl.param_slots.is_empty() && args.len() == tl.param_slots.len() {
                    let (size, step, slots) = (tl.size, tl.step.clone(), tl.param_slots.clone());
                    let mut binds = Vec::new();
                    let cs = self.fresh();
                    binds.push((
                        cs.clone(),
                        Self::rt(
                            "axion_sess_alloc",
                            vec![Self::sched_atom(), Atom::Int(size as i64)],
                            true,
                        ),
                    ));
                    let target = h.to_string();
                    for (i, (slot, arg)) in slots.iter().zip(args.iter()).enumerate() {
                        let v = self.val(arg, &mut binds);
                        let v = self.give_to_worker(&target, i, &v, &mut binds);
                        binds.push((
                            self.fresh(),
                            Rhs::Op(Op::StoreRaw(Atom::Var(cs.clone()), *slot, v)),
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
                    binds.push((
                        self.fresh(),
                        Rhs::Op(Op::StoreRaw(Self::state_atom(), 0, Atom::Int(0))),
                    ));
                    let dead = self.take_all_owned();
                    return wrap(
                        binds,
                        Self::drop_all(dead, Term::Ret(Rhs::Op(Op::Atom(Atom::Int(1))), NO_SPAN)),
                        NO_SPAN,
                    );
                }
            }
        }
        let mut binds = Vec::new();
        let result = match sess_spine(tail).0 {
            Some("close" | "cancel") => Atom::Int(0), // effect as tail → unit
            _ => self.val(tail, &mut binds),
        };
        // the task's result leaves with it (read by the scheduler/parent), not freed here
        if let Atom::Var(v) = &result {
            self.take_var(v);
        }
        binds.push((
            self.fresh(),
            Rhs::Op(Op::StoreRaw(Self::state_atom(), 0, result)),
        ));
        let dead = self.take_all_owned();
        wrap(
            binds,
            Self::drop_all(dead, Term::Ret(Rhs::Op(Op::Atom(Atom::Int(1))), NO_SPAN)),
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
        // a value already given away (sent, moved into a call) is not this task's to park; its
        // slot is never read again on resume (a read after the move is unsupported)
        let moved = self
            .own
            .as_ref()
            .map(|o| o.moved.clone())
            .unwrap_or_default();
        for v in live.iter().filter(|v| !moved.contains(*v)) {
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

    /// Lowers one session continuation expression (a `Case` chain, an `if` branch, or a tail).
    fn gen_cont(&mut self, e: &Expr) -> Term {
        // A branch in the session spine (e.g. a keep-alive handler: `if empty then netClose s else
        // …; handler s`). Evaluate the condition, then dispatch — each arm is itself a continuation
        // that may suspend, self-recurse, or close. Suspensions inside the arms are collected by
        // `collect_suspensions` (which descends `If`), so their resume indices are already assigned.
        if let Expr::If(cond, then_e, else_e, _) = e {
            let mut binds = Vec::new();
            let c = self.val(cond, &mut binds);
            let tmps = self.take_pending();
            let st = self.save_own();
            let t = self.gen_cont(then_e);
            self.restore_own(&st);
            let el = self.gen_cont(else_e);
            self.restore_own(&st);
            return wrap(
                binds,
                Self::drop_all(
                    tmps,
                    Term::Ret(Rhs::If(c, Box::new(t), Box::new(el)), NO_SPAN),
                ),
                NO_SPAN,
            );
        }
        // `let x = v` / `x <- v` / a plain statement `v; rest`, where `v` is a native call or a
        // runtime builtin (no session op): compute it, bind it, continue.
        if let Some((x, rhs, body)) = sess_let(e) {
            return self.gen_local(Some(x), rhs, body);
        }
        if let Expr::Case(scrut, arms, _) = e {
            let data_case = !sess_spine(scrut).0.is_some_and(is_sess_op)
                && arms.iter().any(|(p, _)| matches!(p, Pat::Con(..)))
                && arms.iter().all(|(p, _)| match p {
                    Pat::Con(_, subs, _) => subs
                        .iter()
                        .all(|q| matches!(q, Pat::Var(..) | Pat::Wild(_))),
                    Pat::Var(..) | Pat::Wild(_) => true,
                    _ => false,
                });
            if data_case && self.own.is_some() {
                return self.gen_case(scrut, arms);
            }
            if let [(pat @ (Pat::Var(..) | Pat::Wild(_)), rest)] = arms.as_slice() {
                if !sess_spine(scrut).0.is_some_and(is_sess_op) {
                    let x = match pat {
                        Pat::Var(x, _) => Some(x.as_str()),
                        _ => None,
                    };
                    return self.gen_local(x, scrut, rest);
                }
            }
        }
        let Expr::Case(scrut, arms, _) = e else {
            return self.gen_tail(e);
        };
        let key = scrut.span(); // suspension key = scrutinee span (see susp_key)
        let (head, args) = sess_spine(scrut);
        match head {
            Some("recv") => {
                let payload = spine_head_span(scrut);
                self.gen_recv(&arms[0].0, &arms[0].1, args[0], key, payload)
            }
            Some("offer") => self.gen_offer(args[0], arms, key),
            Some("spawn") => self.gen_spawn(&arms[0].0, args[0], &arms[0].1),
            Some("send") => self.gen_send(&arms[0].0, &args, &arms[0].1),
            Some("select") => self.gen_select(&arms[0].0, &args, &arms[0].1),
            Some("cancel") => self.gen_cancel(args[0], &arms[0].1),
            Some("close") => self.gen_close(&arms[0].0, &arms[0].1),
            // async-socket suspension points (docs/async-sockets.md): attempt the non-blocking op,
            // and on the would-block sentinel park the fd + suspend; otherwise bind + continue.
            Some("netRecv") => {
                self.gen_netsusp("ax_net_recv", 0, false, &arms[0].0, &arms[0].1, &args, key)
            }
            // an accepted socket is set non-blocking so its own recv/send can yield.
            Some("netAccept") => {
                self.gen_netsusp("ax_net_accept", 0, true, &arms[0].0, &arms[0].1, &args, key)
            }
            Some("netSend") => {
                self.gen_netsusp("ax_net_send", 1, false, &arms[0].0, &arms[0].1, &args, key)
            }
            Some("netSendBuf") => self.gen_netsusp(
                "ax_net_send_buf",
                1,
                false,
                &arms[0].0,
                &arms[0].1,
                &args,
                key,
            ),
            // non-suspending socket ops: a plain runtime call, then continue. The listen/connect fd
            // is set non-blocking (true) so accept/recv on it yield instead of blocking a pool thread.
            Some("netListen") => {
                self.gen_netplain("ax_net_listen", true, &arms[0].0, &arms[0].1, &args)
            }
            Some("netConnect") => {
                self.gen_netplain("ax_net_connect", true, &arms[0].0, &arms[0].1, &args)
            }
            Some("netClose" | "netCloseL") => {
                self.gen_netplain("ax_net_close", false, &arms[0].0, &arms[0].1, &args)
            }
            _ => self.gen_tail(e),
        }
    }

    /// Binds `x` (if any) to the value of `rhs`, frees the temporaries it left, then continues
    /// with `rest`. A fresh heap result becomes `x`'s to free; one nobody binds (a plain
    /// statement's) is freed at once. An owned value bound to a new name moves to that name.
    fn gen_local(&mut self, x: Option<&str>, rhs: &Expr, rest: &Expr) -> Term {
        if let (Some(x), Some(t)) = (x, self.expr_ty(rhs)) {
            if let Some(o) = self.own.as_mut() {
                o.var_tys.insert(x.to_string(), t);
            }
        }
        let mut binds = Vec::new();
        let a = self.val(rhs, &mut binds);
        if let (Some(x), Atom::Var(v), Some(o)) = (x, &a, self.own.as_mut()) {
            if let Some(i) = o.pending.iter().position(|(n, _)| n == v) {
                let (_, key) = o.pending.remove(i);
                o.owned.push((x.to_string(), key));
            } else if let Some(i) = o.owned.iter().position(|(n, _)| n == v) {
                o.owned[i].0 = x.to_string();
                o.moved.insert(v.clone());
            }
        }
        let tmps = self.take_pending();
        if let Some(x) = x {
            binds.push((x.to_string(), Rhs::Op(Op::Atom(a))));
        }
        wrap(binds, Self::drop_all(tmps, self.gen_cont(rest)), NO_SPAN)
    }

    /// `(value, endpoint) <- recv ep; rest` — the only value suspension.
    fn gen_recv(
        &mut self,
        pat: &Pat,
        rest: &Expr,
        ep_expr: &Expr,
        span: Span,
        payload: Option<Span>,
    ) -> Term {
        let idx = self.susp[&span];
        self.note_susp(idx);
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
        // `(value, endpoint)`: either side may be `_`, so read the two positions, not the names
        let pv: Vec<Option<String>> = match pat {
            Pat::Tuple(ps, _) => ps
                .iter()
                .map(|p| match p {
                    Pat::Var(n, _) => Some(n.clone()),
                    _ => None,
                })
                .collect(),
            Pat::Var(n, _) => vec![Some(n.clone())],
            _ => Vec::new(),
        };
        let mut cbinds = vec![(
            rv.clone(),
            Self::rt(
                "axion_sess_recv",
                vec![Self::sched_atom(), ep.clone()],
                true,
            ),
        )];
        if let Some(Some(v0)) = pv.first() {
            cbinds.push((v0.clone(), Rhs::Op(Op::Atom(Atom::Var(rv.clone())))));
        }
        if let Some(Some(v1)) = pv.get(1) {
            cbinds.push((v1.clone(), Rhs::Op(Op::Atom(ep))));
        }
        // A received heap value is this task's: every sender hands over a value it owned (or a
        // copy, see `gen_send`). Bound to nothing, it is freed at once.
        let st = self.save_own();
        let key = self.payload_key(payload);
        let mut drop_now = Vec::new();
        if let (Some(key), Some(o)) = (key, self.own.as_mut()) {
            match pv.first() {
                Some(Some(v0)) => o.owned.push((v0.clone(), key)),
                _ => drop_now.push((rv, key)),
            }
        }
        let cont = wrap(
            cbinds,
            Self::drop_all(drop_now, self.gen_cont(rest)),
            NO_SPAN,
        );
        self.restore_own(&st);
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

    /// Async-socket suspension point (docs/async-sockets.md): `x <- netRecv s`, `s <- netAccept l`,
    /// or `_ <- netSend s v`. Attempt the non-blocking op; if it returns the would-block sentinel,
    /// register the fd with the scheduler (`axion_sess_park_fd`, `want_write` for a send) and suspend
    /// (save live locals, resume=idx+1, return 0); otherwise bind the result and continue. On resume
    /// the region re-runs from here, so the op is simply retried against the now-ready fd.
    #[allow(clippy::too_many_arguments)]
    fn gen_netsusp(
        &mut self,
        op_ax: &str,
        want_write: i64,
        nb_result: bool,
        pat: &Pat,
        rest: &Expr,
        args: &[&Expr],
        span: Span,
    ) -> Term {
        let idx = self.susp[&span];
        self.note_susp(idx);
        let mut binds = Vec::new();
        let fd = self.val(args[0], &mut binds);
        let mut rt_args = vec![fd.clone()];
        for a in &args[1..] {
            rt_args.push(self.val(a, &mut binds));
        }
        // the op only reads its arguments: its temporaries die once it ran, or before the task
        // parks (the region re-runs on resume and computes them again)
        let tmps = self.take_pending();
        let rv = self.fresh();
        binds.push((rv.clone(), Self::rt(op_ax, rt_args, true)));
        let wb = self.fresh();
        binds.push((wb.clone(), Self::rt("ax_net_wouldblock", vec![], true)));
        let is_wb = self.fresh();
        binds.push((
            is_wb.clone(),
            Rhs::Op(Op::Prim("==".into(), Atom::Var(rv.clone()), Atom::Var(wb))),
        ));
        // continue: bind the result to the pattern's (single) var, then continue. An accepted
        // socket is made non-blocking so its own recv/send yield (rather than block a pool thread).
        let mut pv = Vec::new();
        pat_vars(pat, &mut pv);
        let mut cbinds = Vec::new();
        if let Some(v0) = pv.first() {
            cbinds.push((v0.clone(), Rhs::Op(Op::Atom(Atom::Var(rv.clone())))));
        }
        if nb_result {
            cbinds.push((
                self.fresh(),
                Self::rt("ax_net_set_nonblocking", vec![Atom::Var(rv)], true),
            ));
        }
        let st = self.save_own();
        // a received String is the task's to free
        if op_ax == "ax_net_recv" {
            if let (Some(v0), Some(o)) = (pv.first(), self.own.as_mut()) {
                o.owned.push((v0.clone(), "String".into()));
            }
        }
        let cont = wrap(
            cbinds,
            Self::drop_all(tmps.clone(), self.gen_cont(rest)),
            NO_SPAN,
        );
        self.restore_own(&st);
        // blocked: park the fd (read=0 / write=1), then suspend.
        let park = (
            self.fresh(),
            Self::rt(
                "axion_sess_park_fd",
                vec![Self::sched_atom(), fd, Atom::Int(want_write)],
                false,
            ),
        );
        let blocked = Self::drop_all(tmps, wrap(vec![park], self.block(idx), NO_SPAN));
        wrap(
            binds,
            Term::Ret(
                Rhs::If(Atom::Var(is_wb), Box::new(blocked), Box::new(cont)),
                NO_SPAN,
            ),
            NO_SPAN,
        )
    }

    /// A non-suspending socket op (`netListen`/`netConnect`/`netClose`/`netCloseL`): a plain runtime
    /// call whose result is bound to the pattern's var (if any), then continue.
    fn gen_netplain(
        &mut self,
        op_ax: &str,
        set_nb: bool,
        pat: &Pat,
        rest: &Expr,
        args: &[&Expr],
    ) -> Term {
        let mut binds = Vec::new();
        let atoms: Vec<Atom> = args.iter().map(|a| self.val(a, &mut binds)).collect();
        let rv = self.fresh();
        binds.push((rv.clone(), Self::rt(op_ax, atoms, true)));
        let tmps = self.take_pending();
        // set the created listener/socket non-blocking so accept/recv on it yield (async sockets).
        if set_nb {
            binds.push((
                self.fresh(),
                Self::rt("ax_net_set_nonblocking", vec![Atom::Var(rv.clone())], true),
            ));
        }
        let mut pv = Vec::new();
        pat_vars(pat, &mut pv);
        if let Some(v0) = pv.first() {
            binds.push((v0.clone(), Rhs::Op(Op::Atom(Atom::Var(rv)))));
        }
        wrap(binds, Self::drop_all(tmps, self.gen_cont(rest)), NO_SPAN)
    }

    /// `case offer ep of { L1 d -> B1 ; … }` — a label suspension + dispatch.
    fn gen_offer(&mut self, ep_expr: &Expr, arms: &[(Pat, Expr)], span: Span) -> Term {
        let idx = self.susp[&span];
        self.note_susp(idx);
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
            let st = self.save_own();
            let t = wrap(ab, self.gen_cont(body), NO_SPAN);
            self.restore_own(&st);
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

    /// `c <- spawn f; rest` — fork a child task on a fresh channel. `f` may be a
    /// partially-applied worker (`spawn (server 0)`): the leading args are the child's
    /// accumulator state, and its endpoint parameter is the peer endpoint (always last).
    fn gen_spawn(&mut self, pat: &Pat, target_expr: &Expr, rest: &Expr) -> Term {
        let (head, target_args) = sess_spine(target_expr);
        let target = head.unwrap_or_else(|| panic!("spawn target")).to_string();
        let (size, step, slots) = {
            let tl = &self.all[&target];
            (tl.size, tl.step.clone(), tl.param_slots.clone())
        };
        // Socket-spawn (async sockets, docs/async-sockets.md Stage 4): a `Sock`/`Listener` worker has
        // NO channel endpoint — `spawn (handler s)` provides a value for EVERY param (args == slots),
        // so seed every param slot directly and DON'T create a channel. (A session worker instead
        // leaves its LAST param — the peer endpoint — for the channel, i.e. args < slots.)
        if target_args.len() == slots.len() && !slots.is_empty() {
            let mut binds = Vec::new();
            let cs = self.fresh();
            binds.push((
                cs.clone(),
                Self::rt(
                    "axion_sess_alloc",
                    vec![Self::sched_atom(), Atom::Int(size as i64)],
                    true,
                ),
            ));
            for (i, (slot, arg)) in slots.iter().zip(target_args.iter()).enumerate() {
                let v = self.val(arg, &mut binds);
                let v = self.give_to_worker(&target, i, &v, &mut binds);
                binds.push((
                    self.fresh(),
                    Rhs::Op(Op::StoreRaw(Atom::Var(cs.clone()), *slot, v)),
                ));
            }
            let tmps = self.take_pending();
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
            // fire-and-forget: no channel back to the parent, so the bind (usually `_`) is unit.
            let mut pv = Vec::new();
            pat_vars(pat, &mut pv);
            if let Some(c) = pv.first() {
                binds.push((c.clone(), Rhs::Op(Op::Atom(Atom::Int(0)))));
            }
            return wrap(binds, Self::drop_all(tmps, self.gen_cont(rest)), NO_SPAN);
        }
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
        // the child's endpoint parameter (the LAST param) is the peer endpoint (a + 1)
        let ap1 = self.fresh();
        binds.push((
            ap1.clone(),
            Rhs::Op(Op::Prim("+".into(), Atom::Var(a.clone()), Atom::Int(1))),
        ));
        if let Some(&ep_slot) = slots.last() {
            binds.push((
                self.fresh(),
                Rhs::Op(Op::StoreRaw(Atom::Var(cs.clone()), ep_slot, Atom::Var(ap1))),
            ));
        }
        // already-applied leading args → the accumulator param slots (in order)
        for (i, (slot, arg)) in slots.iter().zip(target_args.iter()).enumerate() {
            let v = self.val(arg, &mut binds);
            let v = self.give_to_worker(&target, i, &v, &mut binds);
            binds.push((
                self.fresh(),
                Rhs::Op(Op::StoreRaw(Atom::Var(cs.clone()), *slot, v)),
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
        let tmps = self.take_pending();
        wrap(binds, Self::drop_all(tmps, self.gen_cont(rest)), NO_SPAN)
    }

    /// `c <- send ep v; rest`.
    fn gen_send(&mut self, pat: &Pat, args: &[&Expr], rest: &Expr) -> Term {
        let mut binds = Vec::new();
        let ep = self.val(args[0], &mut binds);
        let mut v = self.val(args[1], &mut binds);
        // the value leaves on the channel and the receiver frees it (`gen_recv`): an owned value
        // moves, one this task does not own is copied first
        let key = self.payload_key(Some(args[1].span()));
        if let Atom::Var(x) = &v {
            if self.take_var(x) {
                if let Some(o) = self.own.as_mut() {
                    o.moved.insert(x.clone());
                }
            } else if let (Some(key), true) = (key, self.own.is_some()) {
                v = self.copy_of(&key, &v, &mut binds);
            }
        }
        let tmps = self.take_pending();
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
        wrap(binds, Self::drop_all(tmps, self.gen_cont(rest)), NO_SPAN)
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
        // the task owns its heap parameters (its spawner moved them in), unless demoted
        let mut ps = Vec::new();
        for p in pats {
            pat_vars(p, &mut ps);
        }
        let me = self.name.to_string();
        let init: Vec<(String, String)> = ps
            .iter()
            .enumerate()
            .filter_map(|(i, v)| self.worker_param_key(&me, i).map(|k| (v.clone(), k)))
            .collect();
        // region 0 (fresh entry) first: it records the ownership state at every suspension,
        // which the resume regions start from
        let ptys: Vec<Type> = self
            .own
            .as_ref()
            .and_then(|o| o.funcs.get(me.as_str()))
            .and_then(|f| f.sig.as_ref())
            .map(|s| s.param_types().into_iter().cloned().collect())
            .unwrap_or_default();
        if let Some(o) = self.own.as_mut() {
            o.owned = init;
            for (v, t) in ps.iter().zip(ptys) {
                o.var_tys.insert(v.clone(), t);
            }
        }
        let mut regions: Vec<Option<Term>> = (0..=nsusp).map(|_| None).collect();
        regions[0] = Some(self.region(0, &susps, body));
        for (rv, slot) in regions.iter_mut().enumerate().skip(1) {
            *slot = Some(self.region(rv, &susps, body));
        }
        let mut take = |rv: usize| regions[rv].take().unwrap_or_else(|| panic!("region {rv}"));
        // resume==0 → fresh entry; resume==k → re-enter suspension #(k-1)
        let mut chain = take(nsusp);
        for rv in (0..nsusp).rev() {
            let then_t = take(rv);
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
        if let Some(o) = self.own.as_mut() {
            let (owned, moved) = o
                .at_susp
                .get(&((rv - 1) as i32))
                .cloned()
                .unwrap_or_default();
            o.owned = owned;
            o.moved = moved;
            o.pending.clear();
        }
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

fn session_fns(
    module: &ast::Module,
    native_fns: &HashSet<String>,
    ret_alias: &HashMap<String, HashSet<usize>>,
    tys: &HashMap<Span, Type>,
    drop_seeds: &std::cell::RefCell<Vec<Type>>,
    borrow_args: &BorrowArgs,
    frees: &HashMap<String, HashSet<usize>>,
) -> Vec<CoreFn> {
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
    // spawn targets and session hand-off targets, transitively
    let workers = session_workers(module, bound_body);
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

    let funcs: HashMap<String, &ast::Func> =
        module.funcs.iter().map(|f| (f.name.clone(), f)).collect();
    let demoted: std::cell::RefCell<HashSet<(String, usize)>> = Default::default();
    let mut cons: HashMap<String, (Vec<String>, Vec<Type>)> = HashMap::new();
    let mut boxed: HashSet<String> = HashSet::new();
    for d in &module.datas {
        for c in &d.cons {
            cons.insert(
                c.name.clone(),
                (
                    d.params.clone(),
                    c.fields.iter().map(|f| f.ty.clone()).collect(),
                ),
            );
            if !c.fields.is_empty() {
                boxed.insert(d.name.clone());
            }
        }
    }
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
            own: Some(SessOwn {
                funcs: &funcs,
                ret_alias,
                demoted: &demoted,
                owned: Vec::new(),
                pending: Vec::new(),
                moved: HashSet::new(),
                at_susp: HashMap::new(),
                tys,
                proto: sess_payload_types(
                    pats,
                    funcs.get(name).and_then(|f| f.sig.as_ref()),
                    body,
                    &funcs,
                ),
                cons: &cons,
                boxed: &boxed,
                borrow: borrow_args,
                frees,
                var_tys: HashMap::new(),
                drop_seeds,
            }),
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
    // Generate until no worker parameter is newly demoted (a call site passing a value its task
    // does not own): a demotion changes what that worker frees, and what its callers may move.
    let mut out;
    loop {
        let before = demoted.borrow().len();
        out = vec![step_of("main", &[], bound_body, &layouts)];
        for wf in &workers {
            out.push(step_of(
                &wf.name,
                &wf.clauses[0].pats,
                clause_body(wf).unwrap_or_else(|| panic!("where body")),
                &layouts,
            ));
        }
        if demoted.borrow().len() == before {
            break;
        }
    }
    // driver `main`: create scheduler, alloc root state, run, return result. A socket server (a
    // worker takes a `Sock`/`Listener` — spawned fire-and-forget, no channel back) runs in PAR mode
    // so the `bound` nursery waits for every per-connection handler, not just the root (Stage 4).
    let is_socket_server = workers.iter().any(|wf| {
        wf.sig.as_ref().is_some_and(|s| {
            s.param_types()
                .iter()
                .any(|t| matches!(t.head_con(), Some("Sock" | "Listener")))
        })
    });
    let run_fn = if is_socket_server {
        "axion_sess_run_par"
    } else {
        "axion_sess_run"
    };
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
                    func: run_fn.into(),
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
// worker name → (step-fn name, state size, up/first-endpoint slot, down/second-endpoint slot).
// Single-endpoint workers (parMap/connect) leave down == up; a `pipe3` relay stage has two
// endpoints (recv-from-upstream, send-to-downstream), so it reads both slots.
type ParmapWorkers = HashMap<String, (String, i32, i32, i32)>;

/// The `parMap` workers of the module and their state layouts. The layout alone fixes the
/// `worker → (step, size, slots)` map the lowering of `main` needs, so it is computed early
/// (`parmap_worker_map`); the step BODIES are generated late (`parmap_worker_steps`), once the
/// native functions exist, so a worker can reclaim the heap values it owns like a session task.
fn parmap_worker_layouts(module: &ast::Module) -> (Vec<&ast::Func>, HashMap<String, SessLayout>) {
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
    let mut layouts: HashMap<String, SessLayout> = HashMap::new();
    for wf in &workers {
        let pats = &wf.clauses[0].pats;
        let body = clause_body(wf).unwrap_or_else(|| panic!("parMap worker body"));
        layouts.insert(
            wf.name.clone(),
            sess_layout(pats, body, format!("{}$step", wf.name)),
        );
    }
    (workers, layouts)
}

/// `worker → (step name, state size, endpoint slots)` for every `parMap` target (empty if none).
fn parmap_worker_map(module: &ast::Module) -> ParmapWorkers {
    let (workers, layouts) = parmap_worker_layouts(module);
    let mut map = HashMap::new();
    for wf in &workers {
        let lay = &layouts[&wf.name];
        let up_slot = lay.param_slots.first().copied().unwrap_or(16);
        let down_slot = lay.param_slots.get(1).copied().unwrap_or(up_slot);
        map.insert(
            wf.name.clone(),
            (lay.step.clone(), lay.size, up_slot, down_slot),
        );
    }
    map
}

/// The `parMap` workers' state machines (`<worker>$step`). Like a `spawn`ed session task, a
/// worker OWNS the heap values it creates (`fromInt n`, a call's fresh result) and frees each once
/// it is no longer needed, so its temporaries do not leak. (They used to be generated untracked —
/// `own: None` — and every heap temporary of a worker leaked.)
#[allow(clippy::too_many_arguments)]
fn parmap_worker_steps(
    module: &ast::Module,
    native_fns: &HashSet<String>,
    ret_alias: &HashMap<String, HashSet<usize>>,
    tys: &HashMap<Span, Type>,
    drop_seeds: &std::cell::RefCell<Vec<Type>>,
    borrow_args: &BorrowArgs,
    frees: &HashMap<String, HashSet<usize>>,
) -> Vec<CoreFn> {
    let (workers, layouts) = parmap_worker_layouts(module);
    if workers.is_empty() {
        return Vec::new();
    }
    // choice labels → tags (parity with `session_fns`; a worker may use offer/select)
    let mut tags: HashMap<String, i64> = HashMap::new();
    let mut cons: HashMap<String, (Vec<String>, Vec<Type>)> = HashMap::new();
    let mut boxed: HashSet<String> = HashSet::new();
    for d in &module.datas {
        for (i, c) in d.cons.iter().enumerate() {
            tags.insert(c.name.clone(), i as i64);
            cons.insert(
                c.name.clone(),
                (
                    d.params.clone(),
                    c.fields.iter().map(|f| f.ty.clone()).collect(),
                ),
            );
            if !c.fields.is_empty() {
                boxed.insert(d.name.clone());
            }
        }
    }
    let funcs: HashMap<String, &ast::Func> =
        module.funcs.iter().map(|f| (f.name.clone(), f)).collect();
    // a parMap worker is only ever started by the runtime with its endpoint: no call site can
    // pass it a value it does not own, so nothing is demoted.
    let demoted: std::cell::RefCell<HashSet<(String, usize)>> = Default::default();
    let mut fns = Vec::new();
    for wf in &workers {
        let lay = &layouts[&wf.name];
        let pats = &wf.clauses[0].pats;
        let body = sess_clause_body(wf).unwrap_or_else(|| panic!("parMap worker body"));
        let mut g = SessGen {
            name: wf.name.as_str(),
            lay,
            all: &layouts,
            tags: &tags,
            fns: native_fns,
            susp: HashMap::new(),
            susp_live: Vec::new(),
            tmp: 0,
            own: Some(SessOwn {
                funcs: &funcs,
                ret_alias,
                demoted: &demoted,
                owned: Vec::new(),
                pending: Vec::new(),
                moved: HashSet::new(),
                at_susp: HashMap::new(),
                tys,
                proto: sess_payload_types(pats, wf.sig.as_ref(), body, &funcs),
                cons: &cons,
                boxed: &boxed,
                borrow: borrow_args,
                frees,
                var_tys: HashMap::new(),
                drop_seeds,
            }),
        };
        let step_body = g.build_step(pats, body);
        fns.push(CoreFn {
            name: lay.step.clone(),
            params: vec![SESS_SCHED.into(), SESS_STATE.into()],
            captures: Vec::new(),
            is_closure: false,
            owned_params: Vec::new(),
            owned_drop_ty: Vec::new(),
            body: step_body,
        });
    }
    fns
}

/// The lowering plus the analysis inputs the Δ checker reads (Δ-1):
/// `borrow_args` (pure-borrow call positions) and `recinfo` (field ownership).
pub struct Lowered {
    pub fns: Vec<CoreFn>,
    pub borrow_args: BorrowArgs,
    pub recinfo: RecordInfo,
    /// Per-function, the monomorphic reclaim key of each parameter position (from the signature —
    /// `List String` → `Some("List$String")`, a scalar → `None`). The verifier seeds EVERY param's
    /// scrutinee key from this (not just `%1` params via `owned_drop_ty`), so a `case` on a BORROWED
    /// container param resolves its extracted elements to their concrete type (`String`) via
    /// `field_tagged_key` instead of the generic-constructor poly-erasure. Closes the poly-element
    /// blind spot behind the `axpass` borrowed-list-element double-frees (docs/call-site-ownership).
    pub param_keys: HashMap<String, Vec<Option<String>>>,
    /// Per-function, each parameter's type when it is a heap LEAF (`String`, `Integer`, `Buffer`),
    /// else `None`. The verifier tracks a MOVED-IN parameter of such a type as owned, so storing
    /// it twice (`dup$String x = (x, x)`, a generic body specialized at a heap type) is caught.
    pub param_leaf: HashMap<String, Vec<Option<String>>>,
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
                    owns: false,
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

#[allow(clippy::too_many_arguments)]
pub fn lower_with(
    module: &ast::Module,
    inplace: &HashSet<Span>,
    makecon_tys: &HashMap<Span, Type>,
    array_tys: &HashMap<Span, Type>,
    integer_pats: &HashSet<Span>,
    consume_exempt: &HashSet<String>,
    where_ret_tys: &HashMap<String, Type>,
    where_param_tys: &HashMap<String, Vec<Option<Type>>>,
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
    // constructors of SINGLE-constructor `data` types — an irrefutable `Con`
    // pattern (matching one always succeeds). See `pat_irrefutable`.
    let single_con: HashSet<String> = module
        .datas
        .iter()
        .filter(|d| d.cons.len() == 1)
        .flat_map(|d| d.cons.iter().map(|c| c.name.clone()))
        .collect();
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
    let foreigns: HashMap<String, ForeignInfo> = module
        .foreigns
        .iter()
        .map(|f| {
            let (kinds, ret_float) = f.ffi_kinds();
            (
                f.name.clone(),
                ForeignInfo {
                    symbol: f.c_symbol(),
                    arg_kinds: kinds
                        .into_iter()
                        .map(|(own, float)| FfiArg { float, own })
                        .collect(),
                    ret_float,
                },
            )
        })
        .collect();
    // Phase A′: constructor → `data`-type name of its value (None for unboxed enum
    // constructors — immediate tags, never dropped). Attached to `MakeCon`/`MakeRecord`
    // at lowering so the drop machinery reads the type off the node instead of
    // reconstructing it.
    let field_ty: HashMap<String, String> = module
        .datas
        .iter()
        .filter(|d| d.params.is_empty() && !is_enum_data(d))
        .flat_map(|d| {
            d.cons.iter().flat_map(move |c| {
                c.fields
                    .iter()
                    .filter(|f| !f.name.is_empty())
                    .map(move |f| (f.name.clone(), d.name.clone()))
            })
        })
        .collect();
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
    let mut fn_ret_ty: HashMap<String, String> = module
        .funcs
        .iter()
        .filter_map(|f| {
            let sig = f.sig.as_ref()?;
            // fewer clause parameters than the signature has: the result is a function value
            let arity = f.clauses.first().map_or(0, |c| c.pats.len());
            if arity > 0 && sig.param_types().len() > arity {
                return Some((f.name.clone(), "Closure".to_string()));
            }
            let rt = result_type(sig);
            ret_ty_key(rt, &boxed).map(|k| (f.name.clone(), k))
        })
        .collect();
    // `where`-locals have no signature, so the map above (built from sigs) missed them: a
    // call to a heap-returning local (`where sd = getEnv …`) got NO produce key, so
    // Auto-Drop inserted no drop and the drop-verifier saw no ownership — a re-materialized
    // copy borrowed-then-abandoned leaked, unseen (an AX0911 false-negative). Their RESULT
    // types come from inference (`where_ret_tys`, mangled `parent$local`, the same key the
    // lowering resolves a call through). Merge them the same way so those calls carry a key.
    for (name, rt) in where_ret_tys {
        if let Some(k) = ret_ty_key(rt, &boxed) {
            fn_ret_ty.entry(name.clone()).or_insert(k);
        }
    }
    // Phase B (closure-linearity): function → its declared param types. A lifted
    // eta-lambda `\v.. -> base v..` owns each heap-typed `v` (the closure consume-ABI
    // — `callclo` moves its args in); its drop keys come from the WRAPPED callable's
    // signature (the eta vars are the trailing args of the body's application spine).
    let mut fn_param_types: HashMap<String, Vec<Type>> = module
        .funcs
        .iter()
        .filter_map(|f| {
            let ps = f.sig.as_ref()?.param_types();
            Some((f.name.clone(), ps.into_iter().cloned().collect()))
        })
        .collect();
    // built-ins too (a user definition of the same name wins): an eta lambda wrapping one
    // (`twice (strAppend "x") s`) owns its heap params like any closure, and must free those
    // the built-in only reads
    for (name, ps) in crate::infer::builtin_param_types() {
        fn_param_types.entry(name).or_insert(ps);
    }
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
    // A generic owning param is EXCLUDED from native (unresolvable element key) —
    // UNLESS it is a consume-inferred "pure-escape" function (`append`/`reverse`/
    // `concat`): those only shell-free the spine (every element escapes), so they
    // need no key and compile natively as generic shell-freers.
    // ASSUMPTION (whole-function granularity): a function in `consume_exempt` has NO
    // deep-dropping owned generic param — consume-inference only marks a var-carrying
    // param `%1` when it is pure-escape, so a single exempt function cannot mix a
    // pure-escape and a deep-dropping generic owned param (which would leak its
    // element under the lifted exclusion). Safe today (no prelude/user fn has two
    // owning generic params); revisit as per-param if a future rule broadens `%1`.
    let owning_generics: HashSet<String> = module
        .funcs
        .iter()
        .filter_map(owning_generic_var)
        .filter(|n| !consume_exempt.contains(n))
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
    // §9 structured fork-join: worker state machines for every `parMap` target,
    // plus the map the lowering uses to emit `axion_par_map`. Runs pre-eta.
    let parmap_map = parmap_worker_map(orig_module);
    // Session source functions (main's `bound` body + its transitive `spawn` targets) are compiled
    // to state machines by `session_fns` above; drop them from normal native lowering so they are
    // not emitted twice. For an `Ep`-typed worker the transitive-candidacy loop already removes it
    // via its non-native `Ep` param, but a net-only session `main` or a `Sock`/`Listener` worker has
    // no such non-native tell, so prune explicitly (async sockets, docs/async-sockets.md Stage 3).
    if let Some(bound_body) = orig_module
        .funcs
        .iter()
        .find(|f| f.name == "main")
        .and_then(sess_clause_body)
        .and_then(as_bound)
    {
        native_ok.remove("main");
        for wf in session_workers(orig_module, bound_body) {
            native_ok.remove(&wf.name);
        }
    }
    // function arities, to split over-applied spines (`(f a) b`): top-level functions
    // by name, and `where`-locals by their mangled `parent$w` key (the lowering
    // resolves a call's name through the same mangling before looking up here).
    let mut fn_arity: HashMap<String, usize> = HashMap::new();
    for f in &module.funcs {
        fn_arity.insert(
            f.name.clone(),
            f.clauses.first().map_or(0, |c| c.pats.len()),
        );
        for w in f.clauses.iter().flat_map(|c| &c.wher) {
            let arity = w.clauses.first().map_or(0, |c| c.pats.len());
            fn_arity.insert(format!("{}${}", f.name, w.name), arity);
        }
    }

    // pre-pass: lambda-lift captures for `where`-locals that reference enclosing
    // variables. Each local's `parent$w` maps to the leading capture parameters it
    // needs; the set is the UNION of every sibling's captures (minus that local's
    // own params), so any local can forward captures when it calls a sibling. The
    // parent body and every sibling have all these names in scope.
    let mut where_captures: HashMap<String, Vec<String>> = HashMap::new();
    for f in &module.funcs {
        if !native_ok.contains_key(&f.name) {
            continue;
        }
        let wheres: Vec<&ast::Func> = f.clauses.iter().flat_map(|c| &c.wher).collect();
        if wheres.is_empty() {
            continue;
        }
        // the parent's own binders (params/`let`/`case`) shadow same-named globals, so a
        // `where`-local that references one must capture it rather than resolve the global.
        let shadow = func_bound_names(f);
        let mut union: HashSet<String> = HashSet::new();
        for w in &wheres {
            union.extend(where_free_vars(w, &globals, &shadow));
        }
        if union.is_empty() {
            continue;
        }
        for w in &wheres {
            let mut own: HashSet<String> = HashSet::new();
            for c in &w.clauses {
                for p in &c.pats {
                    let mut vs = Vec::new();
                    pat_vars(p, &mut vs);
                    own.extend(vs);
                }
            }
            let mut extra: Vec<String> = union
                .iter()
                .filter(|n| !own.contains(*n))
                .cloned()
                .collect();
            extra.sort();
            where_captures.insert(format!("{}${}", f.name, w.name), extra);
        }
    }

    // pre-pass: names + computes captures of all lambdas, per enclosing top-level function (by
    // span within it). A class-specialized clone (`countEq$P`) keeps its source's spans, so the
    // same lambda occurs once per clone — each a different function (`==` at `P` vs `Integer`).
    let mut lam_by_fn: HashMap<String, LamMeta> = HashMap::new();
    let no_lams: LamMeta = HashMap::new();
    let mut lam_ctr = 0u32;
    let mut lam_sites: Vec<(&Expr, HashMap<String, String>, String)> = Vec::new();
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
        // A free var that is a LOCAL of the enclosing function (param / `let` / `case`
        // binder) must be captured even when its name collides with a module global:
        // the lambda's reference is to the local (lexical shadowing), so resolving it as
        // the global would be a silent miscompile (`\y -> g + y` capturing a param `g`
        // that shadows a global CAF `g` once read the global). Mirrors the shadow rule in
        // `atom`/`call_named`. Conservative (flat over-approximation of f's binders): a
        // pathological same-name binder in a sibling scope at worst over-captures into a
        // loud unbound-variable error, never a silent wrong-value.
        let shadow = func_bound_names(f);
        for lam in nodes {
            let Expr::Lam(_, _, span) = lam else { continue };
            // the copies of one body an or-pattern expanded to (`A k | B k -> \y -> y + k`)
            // hold the same lambda at the same span: lift it once, every copy calls it
            if lam_by_fn.get(&f.name).is_some_and(|m| m.contains_key(span)) {
                continue;
            }
            let mut fv = HashSet::new();
            free_vars(lam, &HashSet::new(), &mut fv);
            // a `where` function the lambda calls takes the enclosing variables it captures
            // as leading arguments, so the lambda captures those in its place
            let via_locals: Vec<String> = fv
                .iter()
                .filter(|n| !shadow.contains(*n))
                .filter_map(|n| locals.get(n))
                .filter_map(|m| where_captures.get(m))
                .flatten()
                .cloned()
                .collect();
            fv.extend(via_locals);
            let mut captures: Vec<String> = fv
                .into_iter()
                .filter(|n| !globals.contains(n) || shadow.contains(n))
                .collect();
            captures.sort();
            let name = format!("lam${lam_ctr}");
            lam_ctr += 1;
            lam_by_fn
                .entry(f.name.clone())
                .or_default()
                .insert(*span, (name, captures));
            lam_sites.push((lam, locals.clone(), f.name.clone()));
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
            &HashSet::new(), // top-level func: no lifted captures
            &locals,
            &globals,
            &fields,
            lam_by_fn.get(&f.name).unwrap_or(&no_lams),
            inplace,
            &foreigns,
            &boxed,
            &single_con,
            &con_ty,
            &field_ty,
            &fn_ret_ty,
            &parametric_data,
            makecon_tys,
            array_tys,
            &parmap_map,
            &fn_arity,
            &where_captures,
            integer_pats,
            None, // a signed top-level function → owned params come from `f.sig`
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
            // the lifted captures become leading params — count them as locals in the body
            // too (so a capture named like a global resolves the capture, not the global).
            let wcaps: HashSet<String> = where_captures
                .get(&locals[&w.name])
                .map(|v| v.iter().cloned().collect())
                .unwrap_or_default();
            // A `where`-local reclaims its own heap params (Auto-Drop like a signed `%1` fn): pass its
            // inferred param types so `push_owned` owns each genuinely-heap one (`List`/`data`/tuple;
            // `String`/`Int`/`Float` are per-param non-owning, exactly as for a signed top-level fn).
            // This is symmetric with top-level ownership and sound by the same argument: owning the
            // container makes a destructure MOVE the element out, so even returning an interior element
            // (`case ys of Cons a _ -> a` → `drop r; drop ys; ret a`) is leak-free, not a borrow; any
            // genuinely unsound shape is caught by the drop-verifier (AX0910) or the partial-consumer
            // floor (AX0912). (Was previously — wrongly — gated on the RESULT type being `heap_ty`,
            // which misclassified a `String`-returning consumer like `ulBal` as a borrower → it leaked
            // its `List` param while the verifier reported balanced: the leak false-negative.)
            let wmangled = locals[&w.name].clone();
            let wptys: Option<&[Option<Type>]> =
                where_param_tys.get(&wmangled).map(|v| v.as_slice());
            let (wp, wb, wo, wot, wseeds) = lower_func(
                w,
                warity,
                &wcaps,
                &locals,
                &globals,
                &fields,
                lam_by_fn.get(&f.name).unwrap_or(&no_lams),
                inplace,
                &foreigns,
                &boxed,
                &single_con,
                &con_ty,
                &field_ty,
                &fn_ret_ty,
                &parametric_data,
                makecon_tys,
                array_tys,
                &parmap_map,
                &fn_arity,
                &where_captures,
                integer_pats,
                wptys,
            );
            mono_seeds.extend(wseeds);
            // A lifted `where`-local receives its captured enclosing variables as
            // LEADING parameters (matching the arg order call_named prepends).
            let mangled = locals[&w.name].clone();
            let mut wparams = where_captures.get(&mangled).cloned().unwrap_or_default();
            wparams.extend(wp);
            out.push(CoreFn {
                name: mangled,
                params: wparams,
                captures: Vec::new(),
                is_closure: false,
                owned_params: wo,
                owned_drop_ty: wot,
                body: wb,
            });
        }
    }

    // the lifted lambdas (in the order they were numbered)
    for (lam, locals, owner) in lam_sites {
        let Expr::Lam(pats, body, span) = lam else {
            continue;
        };
        let lam_meta = lam_by_fn.get(&owner).unwrap_or(&no_lams);
        let Some((name, captures)) = lam_meta.get(span).cloned() else {
            continue;
        };
        let params: Vec<String> = pats
            .iter()
            .enumerate()
            .map(|(k, p)| match p {
                Pat::Var(n, _) => n.clone(),
                _ => format!("_w{k}"),
            })
            .collect();
        let mut local_names: HashSet<String> = params.iter().cloned().collect();
        local_names.extend(captures.iter().cloned());
        collect_bound_names(body, &mut local_names);
        // Phase B: the lambda owns its heap params (consume-ABI); Auto-Drop reclaims
        // those the body does not move out. Keys from the wrapped callable's signature.
        // a body calling a `where` function: that local's own (inferred) parameter types
        let local_tys: Option<HashMap<String, Vec<Type>>> = match spine(body).0 {
            Expr::Var(h, _) => locals
                .get(h)
                .and_then(|m| where_param_tys.get(m))
                .map(|tys| {
                    let tys = tys
                        .iter()
                        .map(|t| t.clone().unwrap_or_else(|| Type::Var("_".into())))
                        .collect();
                    HashMap::from([(h.clone(), tys)])
                }),
            _ => None,
        };
        let (lam_owned, lam_owned_dty) = lifted_lambda_owned(
            pats,
            body,
            local_tys.as_ref().unwrap_or(&fn_param_types),
            makecon_tys,
            &data_types,
            &parametric_data,
            &mut mono_seeds,
        );
        let mut lam_seeds: Vec<Type> = Vec::new();
        let mut lw = Lower {
            globals: &globals,
            fields: &fields,
            lam_meta,
            inplace,
            foreigns: &foreigns,
            con_ty: &con_ty,
            field_ty: &field_ty,
            fn_ret_ty: &fn_ret_ty,
            locals,
            tmp: 0,
            makecon_tys,
            array_tys,
            parametric_data: &parametric_data,
            // a destructor this lambda's body needs (`drop xs : List$Int` of a list it builds)
            // must be generated: these seeds were discarded, so such a drop freed one cell
            mono_seeds: &mut lam_seeds,
            parmap_workers: &parmap_map,
            fn_arity: &fn_arity,
            where_captures: &where_captures,
            local_names,
            integer_pats,
        };
        out.push(CoreFn {
            name,
            params,
            captures,
            is_closure: true,
            owned_params: lam_owned,
            owned_drop_ty: lam_owned_dty,
            body: lw.term(body),
        });
        mono_seeds.append(&mut lam_seeds);
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

    // Nested patterns (`Just (Rect w h)`, `Cons a (Cons b _)`, `Just 0`) become nested
    // single-level cases, so every later pass and both backends see only the flat shapes they
    // handle; the duplicated fall-through rows are re-uniquified.
    for f in &mut out {
        if flatten_nested_patterns(f) {
            uniquify_fn(f);
        }
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

    // Call-site-driven conditional param-return normalization (R-2, docs/call-site-ownership.md;
    // fixes the `condRet`/`relJoin` UAF class): a non-`%1` heap-String param returned BARE makes
    // the result alias the arg, so a caller that REUSES the arg after the call — and drops the
    // result — frees the still-live arg (use-after-free). Copy the bare return (`strAppend x ""`)
    // so it is uniformly owned and the param a borrow, and the EXISTING borrow/summary/drop
    // analysis below is then correct. The copy fires ONLY where a caller actually reuses the arg
    // (`ret_alias(g) ∩ reused(g)`), so never-reused returns (`chomp`) and every fold accumulator
    // (its `acc` occurs once in `foldl`) keep their zero-cost move — the key difference from the
    // old mixed-heuristic that copied unconditionally. Runs before `compute_borrow_args`, so the
    // relations are read off the RAW (pre-copy) Core and every downstream pass sees the result.
    // AXION_NO_ALIAS_COPY (test hook): skip this copy so the RAW unsafe Core is emitted, to
    // prove the drop-verifier CATCHES the conditional-param-return alias on its own (a sound
    // net), rather than only being dodged by the copy. Never set in production.
    // R-5: container copy targets seeded here (their param types), so the deep-copier
    // generator below emits `axion_copy_<key>` only for the types a real reused
    // container-return needs — absent one, no copier is emitted (oracle-neutral).
    let mut copy_seeds: Vec<Type> = Vec::new();
    if std::env::var_os("AXION_NO_ALIAS_COPY").is_none() {
        // pure-enum type names (all constructors nullary): unboxed immediates that are
        // value-copied, so a bare-returned-then-reused enum never double-frees → no copier.
        let enum_types: HashSet<String> = module
            .datas
            .iter()
            .filter(|d| d.cons.iter().all(|c| c.fields.is_empty()))
            .map(|d| d.name.clone())
            .collect();
        let ret_alias = crate::verify::ret_alias_summary(&out);
        let mut reused = reused_after_call(&out, &ret_alias);
        // session tasks are generated later, so count their calls here: a variable passed from a
        // task may well be read again after the call (conservatively, every one)
        for (g, idx) in session_call_var_args(orig_module) {
            reused.entry(g).or_default().extend(idx);
        }
        let mut copy_ctr = 0usize;
        for f in &mut out {
            let Some(ptys) = fn_param_types
                .get(&f.name)
                .filter(|p| p.len() == f.params.len())
            else {
                continue;
            };
            let (Some(ra), Some(ru)) = (ret_alias.get(&f.name), reused.get(&f.name)) else {
                continue;
            };
            let copy_params: HashSet<usize> = ra.intersection(ru).copied().collect();
            if !copy_params.is_empty() {
                normalize_alias_returns(
                    f,
                    ptys,
                    &copy_params,
                    &mut copy_ctr,
                    &data_types,
                    &enum_types,
                    &mut copy_seeds,
                );
            }
        }
    }

    // A function returning a field of a BORROWED param on some paths (`fromLeft d e = case e of
    // Left x -> x; Right _ -> d`) and an owned value on others has a result the caller can
    // neither own (it may be the borrow) nor leave (it may be `d`): copy the field on those
    // paths, so every path returns an owned value the caller frees. A function returning only
    // such fields is a pure accessor (a borrow-returning function) and is left alone.
    if std::env::var_os("AXION_NO_ALIAS_COPY").is_none() {
        for f in &mut out {
            copy_mixed_returns(f, &fn_ret_ty, module, where_ret_tys, &mut copy_seeds, 0);
        }
    }

    // A by-copy record update (`r { name = n }`) SHARES the unchanged heap fields with its base.
    // Within one function the skip-destructors (`collect_update_skips`) decide which side frees
    // them; but when the base is not owned here (a parameter, a field bound by a pattern), the
    // base's owner frees them while the new record — returned or dropped — frees them too (a
    // double free across the call). Give the new record its OWN copies of those fields.
    if std::env::var_os("AXION_NO_ALIAS_COPY").is_none() {
        let fields_of = record_field_types(module);
        let enum_types: HashSet<String> = module
            .datas
            .iter()
            .filter(|d| d.cons.iter().all(|c| c.fields.is_empty()))
            .map(|d| d.name.clone())
            .collect();
        for f in &mut out {
            let mut lets = HashSet::new();
            let_bound_names(&f.body, &mut lets);
            // a base bound to a CONDITIONAL (`let p = if c then p0 { … } else p0`) is a temp that
            // no skip-destructor handles: an update of it that is moved away (`bumpIf (p { s = … })`)
            // would share fields `p` also frees — give the update its own copies instead
            let mut conds = HashSet::new();
            cond_bound_names(&f.body, &mut conds);
            lets.retain(|n| !conds.contains(n));
            let owned: HashSet<String> = f.owned_params.iter().cloned().collect();
            let mut ctr = 0usize;
            copy_shared_update_fields(
                &mut f.body,
                &owned,
                &lets,
                &fields_of,
                &data_types,
                &enum_types,
                &mut copy_seeds,
                &mut ctr,
            );
        }
    }

    // deep-drop (§2): `data` type of each droppable, so the backend reclaims
    // nested fields via a recursive destructor instead of a flat `free`.
    let recinfo = RecordInfo::build(module);

    // parameter multiplicities of top-level functions with a signature, for
    // borrowed-argument reclamation
    let mut param_mults: HashMap<String, Vec<ast::Mult>> = module
        .funcs
        .iter()
        .filter_map(|f| f.sig.as_ref().map(|s| (f.name.clone(), s.param_mults())))
        .collect();
    // `where`-locals have no signature, so they were invisible to the borrow
    // analysis — a call passing an OWNED value to a local that only READS it was
    // treated as a move, so neither the (ownerless) local nor the parent reclaimed
    // it (leak). Register each lifted local with all-`Many` params so the fixpoint
    // analyzes it: a param it genuinely moves is dropped from the borrow set, and a
    // param it only borrows lets the parent reclaim the argument after the call.
    // GUARD: only when the local's result is not an INTERIOR ALIAS of a parameter — such a
    // result (return a heap field of a borrowed arg, `grab w = inner w`) would double-free
    // if the parent reclaimed it. This used to exclude ALL heap-returning where-locals
    // (`!result_may_be_heap`), which needlessly starved accumulator-style tail-recursive
    // locals (`modInverse`'s Euclid `loop`) of borrow analysis → they leaked their threaded
    // Integers, unlike their leak-free top-level equivalents. Now only the genuine
    // interior-alias class is excluded (the regions `null_borrow_result_keys` pass, below,
    // additionally nulls a call's ownership when the callee returns a param alias).
    let where_names: HashSet<String> = module
        .funcs
        .iter()
        .flat_map(|f| {
            let fname = f.name.clone();
            f.clauses
                .iter()
                .flat_map(|c| &c.wher)
                .map(move |w| format!("{fname}${}", w.name))
        })
        .collect();
    // A parameter a `where`-local only READS (the borrow analysis keeps it borrowable with every
    // local's params unmarked) is borrowed, like a top-level function's: the caller keeps and
    // frees its argument, and may pass it again (`scale s 1 + scale s 2`). Owning it made each
    // call free the caller's value — a use after free the verifier refused. The local still
    // owns the params it moves, as below.
    {
        // Fixpoint: start with every local's params borrowable, then mark `One` those a local
        // keeps (a part stored) — a local storing a part of what another local hands it (`ulBal`
        // passing its tail to the consuming `ulPairs`) only sees that once `ulPairs` is `One`.
        let where_captures_ref = &where_captures;
        let mut kept: HashMap<String, HashSet<usize>> = HashMap::new();
        // analyzed with each clause binder of a parameter (`let ys = _p0`) collapsed into it, as
        // the borrowed ones are below — the alias would read as a move
        let mut tout = out.clone();
        for f in tout.iter_mut().filter(|f| where_names.contains(&f.name)) {
            let all: HashSet<String> = f.params.iter().cloned().collect();
            let body = std::mem::replace(
                &mut f.body,
                Term::Ret(Rhs::Op(Op::Atom(Atom::Int(0))), NO_SPAN),
            );
            f.body = collapse_param_aliases(body, &all);
        }
        let ba0 = loop {
            let mut trial = param_mults.clone();
            for f in &tout {
                if where_names.contains(&f.name) {
                    let k = kept.get(&f.name);
                    trial.entry(f.name.clone()).or_insert_with(|| {
                        (0..f.params.len())
                            .map(|i| {
                                if k.is_some_and(|k| k.contains(&i)) {
                                    ast::Mult::One
                                } else {
                                    ast::Mult::Many
                                }
                            })
                            .collect()
                    });
                }
            }
            let ba0 = compute_borrow_args(&tout, &trial, &con_recursive_fields(&module.datas));
            let mut changed = false;
            for f in &tout {
                let Some(set) = ba0.get(&f.name).filter(|_| where_names.contains(&f.name)) else {
                    continue;
                };
                // one with a part the local moves (into a new value, a consuming call) stays
                // owned, like a top-level function that stores a part of its argument (front-end
                // Rule A): destructuring an owned container moves the part out, where a borrowed
                // one would give away part of the caller's value. A RETURNED part is a borrow,
                // copied on the paths that also return a fresh value (the mixed-return pass).
                for &i in set {
                    let Some(p) = f.params.get(i) else { continue };
                    let mut parts = HashSet::new();
                    interior_binders(&f.body, p, &mut parts);
                    if f.owned_params.contains(p)
                        && parts.iter().any(|b| body_stores(b, &f.body, &ba0))
                        && kept.entry(f.name.clone()).or_default().insert(i)
                    {
                        changed = true;
                    }
                }
            }
            if !changed {
                break ba0;
            }
        };
        // a parameter the local returns whole (`kind j | j < 2 = tag | otherwise = tag ++ "!"`)
        // while a caller reuses the argument: copied there, as for a top-level function
        let ret_alias = crate::verify::ret_alias_summary(&out);
        let reused = reused_after_call(&out, &ret_alias);
        let enum_types: HashSet<String> = module
            .datas
            .iter()
            .filter(|d| d.cons.iter().all(|c| c.fields.is_empty()))
            .map(|d| d.name.clone())
            .collect();
        let none = HashSet::new();
        for f in out.iter_mut().filter(|f| where_names.contains(&f.name)) {
            let set = ba0.get(&f.name).unwrap_or(&none);
            let k = kept.get(&f.name);
            let read_only: HashSet<String> = set
                .iter()
                .filter(|i| !k.is_some_and(|k| k.contains(i)))
                .filter_map(|&i| f.params.get(i).cloned())
                .collect();
            f.owned_params.retain(|p| !read_only.contains(p));
            f.owned_drop_ty.retain(|(p, _)| !read_only.contains(p));
            if std::env::var_os("AXION_NO_ALIAS_COPY").is_some() {
                continue;
            }
            // a borrowed parameter returned whole: the first copy pass skipped `where`-locals
            // (no declared types) and saw these still owned
            let ptys = where_local_param_types(f, module, where_captures_ref, where_param_tys);
            // a String param is never owned by a local, so returning it on one exit and a
            // fresh value on another leaks it unless it is copied (an Integer one is owned
            // later and dropped on the other exits instead)
            let is_str = |i: usize| {
                ptys.as_ref()
                    .and_then(|p| p.get(i))
                    .is_some_and(|t| ty_head_args(t).0 == Some("String"))
            };
            let returned: HashSet<usize> = ret_alias
                .get(&f.name)
                .into_iter()
                .flatten()
                .copied()
                .filter(|&i| f.params.get(i).is_some_and(|p| !f.owned_params.contains(p)))
                .filter(|&i| {
                    reused.get(&f.name).is_some_and(|r| r.contains(&i))
                        || (is_str(i) && returns_other(&f.body, &f.params[i]))
                })
                .collect();
            if let Some(ptys) = ptys.filter(|p| p.len() == f.params.len() && !returned.is_empty()) {
                let mut ctr = 2000usize;
                normalize_alias_returns(
                    f,
                    &ptys,
                    &returned,
                    &mut ctr,
                    &data_types,
                    &enum_types,
                    &mut copy_seeds,
                );
            }
            // the mixed-return copy ran while these were still owned
            if !read_only.is_empty() {
                copy_mixed_returns(f, &fn_ret_ty, module, where_ret_tys, &mut copy_seeds, 1000);
            }
        }
    }
    for f in &out {
        if where_names.contains(&f.name) {
            // A `where`-local now owns its heap params exactly like a signed top-level `%1` fn
            // (`lower_func` computed `owned_params` from the inferred param types), so its
            // call-sites must MOVE those params (`Once`), not borrow+drop them — otherwise a
            // self-recursive call would be seen as borrowing its own owned arg and both the
            // callee's drop and the caller's post-call drop fire → double-free. Params it only
            // borrows stay `Many` (the fixpoint then lets the parent reclaim them after the
            // call). Returning an interior element is NOT a borrow here: owning the container
            // makes destructuring MOVE the element out (`drop r; drop ys; ret a`, leak-free —
            // symmetric with the top-level case), and any genuinely unsound shape is caught by
            // the drop-verifier (AX0910) or the partial-consumer floor (AX0912), never shipped.
            let owned: HashSet<&String> = f.owned_params.iter().collect();
            param_mults.entry(f.name.clone()).or_insert_with(|| {
                f.params
                    .iter()
                    .map(|p| {
                        if owned.contains(p) {
                            ast::Mult::One
                        } else {
                            ast::Mult::Many
                        }
                    })
                    .collect()
            });
        }
    }
    // Uniformize MIXED conditional-owned temps (`let x = if c then <fresh heap> else s`) by
    // copying the non-owned arms — BEFORE borrow analysis, so the copied arm reads its source as a
    // borrow and every downstream pass (borrow-args, call annotations, drops) stays consistent.
    // Closes the mixed conditional-owned-temp leak (the #1 flagship gotcha); the all-heap case was
    // already handled by `reclaim_cond_escape`'s seeding.
    for f in &mut out {
        let body = std::mem::replace(
            &mut f.body,
            Term::Ret(Rhs::Op(Op::Atom(Atom::Int(0))), NO_SPAN),
        );
        f.body = normalize_mixed_cond_lets(body, &recinfo, &mut HashMap::new());
        // the record copiers it called (`axion_copy_T` for an arm copied to a `T`) are generated
        let mut called = HashSet::new();
        copier_calls(&f.body, &mut called);
        copy_seeds.extend(called.into_iter().map(Type::Con));
        // Clause-form functions bind patterns as `let buf = _p1`. Removing that alias BEFORE borrow
        // analysis lets every pass see the parameter itself: otherwise it read as a move, so the
        // caller gave up ownership while the callee never freed (a leak), and a later use by the
        // caller was a false AX0910. Owned `%1` params keep their existing alias handling.
        let borrowable: HashSet<String> = f
            .params
            .iter()
            .filter(|p| !f.owned_params.contains(p))
            .cloned()
            .collect();
        let body = std::mem::replace(
            &mut f.body,
            Term::Ret(Rhs::Op(Op::Atom(Atom::Int(0))), NO_SPAN),
        );
        f.body = collapse_param_aliases(body, &borrowable);
    }
    // A closure that ESCAPES the scope it is made in (returned, stored, handed on) owns COPIES of
    // its heap captures, freed by its own destructor; a call to a function returning a fresh
    // closure gives the caller an owned `Closure`. See `own_escaping_closures`.
    let owning_closures = {
        let pre_ba = compute_borrow_args(&out, &param_mults, &con_recursive_fields(&module.datas));
        let fn_result_types: HashMap<String, Type> = module
            .funcs
            .iter()
            .filter_map(|f| Some((f.name.clone(), result_type(f.sig.as_ref()?).clone())))
            .collect();
        let mut type_by_key: HashMap<String, Type> = HashMap::new();
        for t in fn_param_types
            .values()
            .flatten()
            .chain(fn_result_types.values())
            .chain(makecon_tys.values())
            .chain(array_tys.values())
        {
            register_type_keys(t, &mut type_by_key);
        }
        let cx = ClosureOwnCx {
            by_ret: false,
            ba: &pre_ba,
            fn_param_types: &fn_param_types,
            fn_result_types: &fn_result_types,
            boxed: &boxed,
            recinfo: &recinfo,
            type_by_key: &type_by_key,
        };
        let owning = own_escaping_closures(&mut out, &cx, &mut copy_seeds, &mut mono_seeds);
        copy_closure_call_params(&mut out, &cx, &mut copy_seeds, &mut mono_seeds);
        key_fresh_closure_calls(&mut out);
        // AXION_NO_CLOSURE_COPIES (test hook): leave out the closure copies below, to check that the
        // drop verifier refuses the double frees they prevent
        if std::env::var_os("AXION_NO_CLOSURE_COPIES").is_none() {
            copy_embedded_closures(&mut out, &recinfo, makecon_tys, &fn_param_types);
            copy_returned_closure_params(&mut out, &fn_param_types);
        }
        owning
    };
    let mut borrow_args =
        compute_borrow_args(&out, &param_mults, &con_recursive_fields(&module.datas));
    // A function that may return a parameter WHOLE (`consume n = if … then n else …`) hands the
    // caller that very value. When some caller passes it a value it does not OWN — an element of a
    // borrowed list, or its own borrowed parameter — and then drops the result, the owner's later
    // free is a double free (the verifier reports it, AX0910). Copy those returns, so the result is
    // always fresh and the parameter only read; then recompute the borrow analysis (the parameter
    // is now borrowed, so callers keep and free their own values). The reuse-gated copy above
    // cannot see this: it runs before ownership is known.
    if std::env::var_os("AXION_NO_ALIAS_COPY").is_none() {
        let enum_types: HashSet<String> = module
            .datas
            .iter()
            .filter(|d| d.cons.iter().all(|c| c.fields.is_empty()))
            .map(|d| d.name.clone())
            .collect();
        let mut ctr = 0usize;
        for _ in 0..4 {
            let ret_alias = crate::verify::ret_alias_summary(&out);
            if ret_alias.is_empty() {
                break;
            }
            let mut fed_borrowed =
                crate::verify::borrowed_elem_params(&out, &borrow_args, &recinfo);
            for (g, idx) in live_scrutinee_field_args(&out) {
                fed_borrowed.entry(g).or_default().extend(idx);
            }
            // A parameter that receives a borrowed value passes a borrowed value on: `hoflam s =
            // strLen (idG s)` called on a borrowed element feeds `idG` that element. Least
            // fixpoint over the call graph (bounded by the finite set of positions).
            loop {
                let mut grew = false;
                for (g, idx) in borrowed_param_args(&out, &borrow_args, &fed_borrowed) {
                    let e = fed_borrowed.entry(g).or_default();
                    for i in idx {
                        grew |= e.insert(i);
                    }
                }
                if !grew {
                    break;
                }
            }
            let mut changed = false;
            for f in &mut out {
                let (Some(ra), Some(fb)) = (ret_alias.get(&f.name), fed_borrowed.get(&f.name))
                else {
                    continue;
                };
                let copy: HashSet<usize> = ra
                    .intersection(fb)
                    .copied()
                    .filter(|i| !borrow_args.get(&f.name).is_some_and(|b| b.contains(i)))
                    .collect();
                let Some(ptys) = fn_param_types
                    .get(&f.name)
                    .filter(|p| p.len() == f.params.len())
                else {
                    continue;
                };
                if copy.is_empty() {
                    continue;
                }
                let before = ctr;
                normalize_alias_returns(
                    f,
                    ptys,
                    &copy,
                    &mut ctr,
                    &data_types,
                    &enum_types,
                    &mut copy_seeds,
                );
                changed |= ctr != before; // a copy was inserted
            }
            if !changed {
                break;
            }
            borrow_args =
                compute_borrow_args(&out, &param_mults, &con_recursive_fields(&module.datas));
        }
    }

    // Regions/lifetimes (§): a function whose return is, on EVERY path, a pure interior heap
    // alias of a (borrowed) parameter (`grab w = inner w`) hands back a BORROW, not a fresh
    // allocation. Null the ownership annotation on every call to one so Auto-Drop does not
    // free the borrowed result — the argument's owner frees it once. This makes the
    // interprocedural field-alias-return SOUND (previously the verifier could only reject
    // it). Reuses the drop-balance verifier's alias summary (return classification is
    // drop-independent); the verifier then re-derives it from the emitted Core and checks
    // the drops. Idempotent + a no-op for programs with no borrow-returning function.
    let borrow_ret = crate::verify::borrow_return_summary(&out, &borrow_args, &recinfo);
    let mut borrow_kinds: HashMap<String, CopyKind> = HashMap::new();
    if !borrow_ret.is_empty() {
        // A borrow MOVED into a new owned value (`Just (unboxS b)`, a consuming call) would end
        // up with two owners: copy it there (its type is the callee's declared result).
        let mut kinds: HashMap<String, CopyKind> = HashMap::new();
        for g in borrow_ret.keys() {
            let Some(k) = fn_ret_ty.get(g) else { continue };
            let kind = match k.as_str() {
                "String" => Some(CopyKind::Str),
                "Integer" => Some(CopyKind::Int),
                _ => module
                    .funcs
                    .iter()
                    .find(|f| &f.name == g)
                    .and_then(|f| f.sig.as_ref())
                    .map(result_type)
                    .filter(|t| {
                        matches!(t, Type::Tuple(_))
                            || t.head_con().is_some_and(|h| {
                                module.datas.iter().any(|d| {
                                    d.name == h && d.cons.iter().any(|c| !c.fields.is_empty())
                                })
                            })
                    })
                    .and_then(|t| {
                        mono_key(t).map(|key| {
                            copy_seeds.push(t.clone());
                            CopyKind::Container(key)
                        })
                    }),
            };
            if let Some(kind) = kind {
                kinds.insert(g.clone(), kind);
            }
        }
        for f in &mut out {
            null_borrow_result_keys(&mut f.body, &borrow_ret);
        }
        borrow_kinds = kinds;
    }
    // A part of a BORROWED parameter that a pattern brings out (`case xs of Cons _ (Cons s _)`)
    // belongs to the caller too: moved into a new value or a consuming call it would have two
    // owners. Copy it there, like a borrow handed back by a call (one walk does both).
    // `AXION_NO_ALIAS_COPY` turns both off (the verifier's tests see the uncopied shape).
    let no_alias_copy = std::env::var_os("AXION_NO_ALIAS_COPY").is_some();
    let mut copied_interior = false;
    for f in &mut out {
        // per function: the generated names must not depend on the order functions come in
        let mut ctr = 0usize;
        let mut bv = HashMap::new();
        let mut pending: HashMap<String, Type> = HashMap::new();
        if let Some(ptys) = fn_param_types
            .get(&f.name)
            .filter(|p| p.len() == f.params.len() && !no_alias_copy)
        {
            let mut tys: HashMap<String, Type> = f
                .params
                .iter()
                .zip(ptys)
                .filter(|(p, _)| !f.owned_params.contains(p))
                .map(|(p, t)| (p.clone(), t.clone()))
                .collect();
            let borrowed: HashSet<String> = tys.keys().cloned().collect();
            interior_binder_types(&f.body, &module.datas, &mut tys);
            for (n, t) in tys {
                if borrowed.contains(&n) {
                    continue;
                }
                if let Some(k) = copy_kind_of(&t, &module.datas) {
                    if let CopyKind::Container(key) = &k {
                        pending.entry(key.clone()).or_insert(t);
                    }
                    bv.insert(n, k);
                }
            }
        }
        let kinds_here = if no_alias_copy {
            HashMap::new()
        } else {
            borrow_kinds.clone()
        };
        if !kinds_here.is_empty() || !bv.is_empty() {
            copy_moved_borrows(&mut f.body, &kinds_here, &borrow_args, &mut bv, &mut ctr);
            copied_interior |= ctr > 0;
        }
        // a copier is generated only for the types actually copied
        if ctr > 0 && !pending.is_empty() {
            let mut called = HashSet::new();
            direct_callees(&f.body, &mut called);
            for (key, t) in pending.drain() {
                if called.contains(&format!("axion_copy_{key}")) {
                    copy_seeds.push(t);
                }
            }
        }
        pending.clear();
    }
    // a parameter whose part was moved (`Just v3`) read as consumed; with a copy moved instead
    // it is only read, and its callers keep (and free) their argument
    if copied_interior {
        borrow_args = compute_borrow_args(&out, &param_mults, &con_recursive_fields(&module.datas));
    }
    let mut all_dty = build_all_drop_ty(&out, makecon_tys, &recinfo);
    let empty = HashMap::new();

    // Concrete heap parameter types (from signatures), for reclaiming a
    // conditionally-escaping OWNED heap param — `headOr`'s default: returned in one
    // arm, dead in another where the branch-insensitive `escaped` set never drops
    // it (a leak). See `reclaim_cond_escape`.
    let param_types: HashMap<String, Vec<Type>> = module
        .funcs
        .iter()
        .filter_map(|f| {
            f.sig.as_ref().map(|s| {
                (
                    f.name.clone(),
                    s.param_types().into_iter().cloned().collect(),
                )
            })
        })
        .collect();

    // A NON-`%1` param of a concrete PARAMETRIC type (`Lst Box`) carries its
    // monomorphic key (`Lst$Box`) too, so a `case` on it resolves the element/spine
    // field drops to the mono destructor (`axion_drop_Lst$Box`) instead of the leaky
    // generic `axion_drop_Lst`. `%1` params already have theirs (`owned_drop_ty`).
    // Safe: an absent mono destructor routes to a flat free (leak), never a crash,
    // and the scrutinee's deep-vs-shell choice is by escape analysis, not this key.
    for f in &out {
        let Some(ptys) = param_types
            .get(&f.name)
            .filter(|p| p.len() == f.params.len())
        else {
            continue;
        };
        let dty = all_dty.entry(f.name.clone()).or_default();
        for (name, ty) in f.params.iter().zip(ptys) {
            if !dty.contains_key(name) {
                if let Some(k) = mono_key(ty).filter(|k| k.contains('$')) {
                    dty.insert(name.clone(), Some(k));
                }
            }
        }
    }

    let mut result: Vec<CoreFn> = Vec::with_capacity(out.len());
    let mut skip_seeds: Vec<(String, Vec<usize>)> = Vec::new();
    let mut tuple_skip_seeds: Vec<(String, usize, Vec<usize>)> = Vec::new();
    // stream-fusion pass: fuse producer→consumer chains on List operations
    fuse_list_ops(&mut out);
    // Params that receive a BORROWED container element at some call site (the `consume e` /
    // `axpass show` class): reclaiming such a String param would free the owner's element → a
    // double-free the verifier would reject. Excluded from String reclaim below so owned-String
    // reclamation (accumulators) is enabled safely. Drop-independent → computed on the pre-drop Core.
    let bep = crate::verify::borrowed_elem_params(&out, &borrow_args, &recinfo);
    // ESCAPE HATCH (tests only): AXION_STRING_RECLAIM=1 BYPASSES the `bep` exclusion, forcing the
    // unsound blanket owned-String reclaim (the reverted 16ceefb behaviour). Used by
    // `verifier_catches_borrowed_list_element_double_free` to prove the verifier is the backstop —
    // with the exclusion off, `work` frees a borrowed list element and the verifier must AX0910 it.
    let force_unsafe_string_reclaim = std::env::var_os("AXION_STRING_RECLAIM").is_some();
    copy_live_closure_moves(&mut out, &borrow_args, &param_types);
    for f in out {
        let dty = all_dty.get(&f.name).unwrap_or(&empty);
        let (mut f, seeds, tuple_seeds_skip) =
            insert_drops(f, &borrow_args, dty, &recinfo, &borrow_ret);
        // AXION_NO_UPDATE_SKIP_FIX (test hook): leave both update-skip fixes out, to check that
        // the verifier refuses the Core they correct
        if std::env::var_os("AXION_NO_UPDATE_SKIP_FIX").is_none() {
            swap_update_skip_owner(&mut f.body, &recinfo);
        }
        // A2: reclaim a conditionally-escaping owned heap param in a tail case/if.
        // Guard: only when the Core params line up 1:1 with the signature arrows
        // (a captured/synthetic param would otherwise pick the WRONG destructor key
        // for a slot and free a differently-shaped value → heap corruption).
        let owned: Vec<(String, Option<String>)> = if let Some(ptys) = param_types
            .get(&f.name)
            .filter(|p| p.len() == f.params.len())
        {
            let ba_set = borrow_args.get(&f.name);
            let drp = droppable_vars(&f, &borrow_args);
            f.params
                .iter()
                .zip(ptys)
                .enumerate()
                // a heap `data`/tuple with a concrete monomorphic key (so its destructor
                // exists), or a boxed `Integer` (reclaimed by `axion_bignum_free`) — NOT a
                // scalar (`is_heap_shaped` is true for Int, which would free a raw integer);
                // NOT a borrow-arg (the caller moves it in → this fn owns it); and NOT
                // already reclaimed by `insert_drops`.
                .filter(|(i, (name, ty))| {
                    // a real heap POINTER (a boxed `data`/tuple with a concrete
                    // destructor, or a boxed `Integer`) — NOT a pure enum, whose values
                    // are unboxed immediate tags with no destructor (freeing one corrupts).
                    let is_enum = ty.head_con().is_some_and(|h| recinfo.is_enum_type(h));
                    // Owned `String` params ARE reclaimed now (the accumulator-leak fix) — SOUNDLY,
                    // because a param that receives a borrowed container element (`bep`, the fzf-path
                    // `axpass show` / `borrowed_list_elem_consume` class) is excluded below, so its
                    // free is never introduced. The blanket reclaim was reverted in 16ceefb; `bep` is
                    // the precise exclusion that makes it safe (the verifier remains the backstop).
                    let string_reclaim = ty.head_con() == Some("String");
                    let reclaimable =
                        (heap_ty(ty, &data_types) && mono_key(ty).is_some() && !is_enum)
                            || ty.head_con() == Some("Integer")
                            || string_reclaim;
                    reclaimable
                        && !ba_set.is_some_and(|s| s.contains(i))
                        && !drp.contains(name.as_str())
                        && (force_unsafe_string_reclaim
                            || !bep.get(&f.name).is_some_and(|s| s.contains(i)))
                })
                .map(|(_, (name, ty))| {
                    let key = match ty.head_con() {
                        Some("Integer") => Some("Integer".to_string()),
                        Some("String") => Some("String".to_string()),
                        _ => mono_key(ty),
                    };
                    (name.clone(), key)
                })
                .collect()
        } else if where_names.contains(&f.name) {
            // A signature-less `where`-local: reclaim its owned Integer accumulators (the
            // Euclid `loop` of `modInverse`). The "Integer" key is uniform, so the slot
            // misalignment that guards the type-keyed branch above does not apply. Integer
            // params are inferred from usage (`where_integer_params`); an owned one is a param
            // the caller MOVES in (not in `borrow_args`) that `insert_drops` did not reclaim.
            let ba_set = borrow_args.get(&f.name);
            let drp = droppable_vars(&f, &borrow_args);
            let ints = where_integer_params(&f);
            f.params
                .iter()
                .enumerate()
                .filter(|(i, name)| {
                    ints.contains(name.as_str())
                        && !ba_set.is_some_and(|s| s.contains(i))
                        && !drp.contains(name.as_str())
                })
                .map(|(_, name)| (name.clone(), Some("Integer".to_string())))
                .collect()
        } else {
            Vec::new()
        };
        // Always run: even with no owned PARAM to carry, the pass DISCOVERS conditionally-
        // escaping case-extracted heap elements (`filter`/`keepBig`) and reclaims them
        // branch-sensitively. A no-op when there is nothing to reclaim.
        {
            let body = std::mem::replace(
                &mut f.body,
                Term::Ret(Rhs::Op(Op::Atom(Atom::Int(0))), NO_SPAN),
            );
            f.body = reclaim_cond_escape(body, owned, &borrow_args, &borrow_ret, &recinfo, dty);
        }
        // the skip drops it emitted (a field move-out) need their skip destructors too
        collect_drop_skips(&f.body, &mut skip_seeds);
        result.push(f);
        skip_seeds.extend(seeds);
        tuple_skip_seeds.extend(tuple_seeds_skip);
    }
    // the helpers of the arrays with heap elements (`axion_arrop_*$K`), and the `Array T`
    // types whose element-freeing destructor they need. Seeded here, before the destructors
    // and copiers below are generated, so each element type gets both.
    let heap_arrays = gen_array_helpers(&mut result, array_tys, &mut copy_seeds, &mut mono_seeds);
    // the destructors of the closures that own their (copied) heap captures
    result.extend(gen_closure_dtors(&owning_closures));
    // generated destructors: added AFTER drop insertion (they manage
    // memory by hand, they don't go through the reclamation analysis)
    result.extend(gen_destructors(&recinfo, &parametric_data, &mut mono_seeds));
    // R-5: per-type deep-copiers `axion_copy_<key>` for the container-return copy
    // targets seeded above (and, transitively, their heap fields). Emitted only when
    // a reused container-return actually needs one, so the whole existing corpus is
    // oracle-neutral. Managed by hand (skipped by Auto-Drop and the verifier), exactly
    // like the destructors, and added AFTER drop insertion for the same reason.
    if !copy_seeds.is_empty() {
        result.extend(gen_copiers(
            std::mem::take(&mut copy_seeds),
            module,
            &recinfo,
            &parametric_data,
        ));
    }
    // F-3 skip-variant destructors (`axion_drop_T_skip_0`) — before the mono
    // generation below, so a skipped remainder's parametric field (`List String`)
    // seeds and gets its `axion_drop_List$String`.
    result.extend(gen_skip_destructors(
        &skip_seeds,
        &recinfo,
        &parametric_data,
        &mut mono_seeds,
    ));
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
    // A tuple literal whose drop is keyed from its inferred type (`collect_drop_types`) needs that
    // tuple's destructor, or the keyed drop falls back to a flat free and leaks the components.
    {
        let used: HashSet<&str> = all_dty
            .values()
            .flat_map(|m| m.values())
            .filter_map(|k| k.as_deref())
            .filter(|k| k.starts_with("tuple"))
            .collect();
        let mut tys: Vec<&Type> = makecon_tys
            .values()
            .filter(|t| matches!(t, Type::Tuple(_)))
            .filter(|t| mono_key(t).is_some_and(|k| used.contains(k.as_str())))
            .collect();
        tys.sort_by_key(|t| mono_key(t));
        mono_seeds.extend(tys.into_iter().cloned());
    }
    // Seed every TUPLE and CONTAINER sub-type appearing in a seed, so each gets its concrete mono
    // destructor even when it only ever appears NESTED: a `List (Int,Int)` seeds `(Int,Int)` (its
    // tuple element, else the list frees only its spine and leaks every tuple cell); a
    // `(List Integer, _)` seeds `List Integer`. `gen_tuple_destructors` emits the tuples,
    // `gen_mono_destructors` the containers; both dedup by key, so duplicates are harmless, and the
    // recursion walks strict sub-components so it terminates.
    fn collect_droppable_subtypes(t: &Type, out: &mut Vec<Type>) {
        match t {
            Type::Tuple(ts) => {
                if mono_key(t).is_some() {
                    out.push(t.clone());
                }
                ts.iter().for_each(|e| collect_droppable_subtypes(e, out));
            }
            Type::App(f, a) => {
                if mono_key(t).is_some() {
                    out.push(t.clone());
                }
                collect_droppable_subtypes(f, out);
                collect_droppable_subtypes(a, out);
            }
            Type::Arrow { from, to, .. } => {
                collect_droppable_subtypes(from, out);
                collect_droppable_subtypes(to, out);
            }
            _ => {}
        }
    }
    {
        let mut extra = Vec::new();
        for t in &mono_seeds {
            collect_droppable_subtypes(t, &mut extra);
        }
        mono_seeds.extend(extra);
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
    result.extend(gen_tuple_destructors(
        &tuple_seeds,
        &recinfo,
        &parametric_data,
    ));
    // tuple skip-variant destructors (`axion_drop_tuple$…_skip_0`): reclaim every heap
    // element EXCEPT the moved-out slot(s), for a peel deconstructor (`uncons`) whose head
    // is moved out of the result tuple while the tail (or a wildcard sibling) is discarded.
    result.extend(gen_tuple_skip_destructors(&tuple_skip_seeds, &recinfo));
    // Phase 2c array mono destructors: scan for parametric ArrayNew ops and
    // generate per-element deep-drop destructors (axion_drop_Array$List$P, etc.)
    {
        let mut array_seeds = collect_array_seeds(&result);
        array_seeds.extend(heap_arrays);
        result.extend(gen_mono_array_destructors(
            &array_seeds,
            &recinfo,
            &parametric_data,
        ));
    }
    // native session state machines (§11): also hand-managed (task states live in
    // the scheduler's nursery arena), so they bypass the drop analysis too. Generated after the
    // native functions so a task knows which calls may return one of their arguments (a result it
    // must not free).
    let ret_alias = crate::verify::ret_alias_summary(&result);
    let sess_seeds = std::cell::RefCell::new(Vec::new());
    let frees = crate::verify::frees_heap_params(&result);
    let sess = session_fns(
        orig_module,
        &native_fn_names,
        &ret_alias,
        makecon_tys,
        &sess_seeds,
        &borrow_args,
        &frees,
    );
    // §9 structured fork-join worker state machines: same nursery arena and the same ownership
    // tracking as the session steps.
    let parmap_steps = parmap_worker_steps(
        orig_module,
        &native_fn_names,
        &ret_alias,
        makecon_tys,
        &sess_seeds,
        &borrow_args,
        &frees,
    );
    result.extend(sess);
    // destructors for the parametric `data` instances only session tasks free (`List$String`)
    {
        let have: HashSet<String> = result.iter().map(|f| f.name.clone()).collect();
        let seeds: Vec<Type> = sess_seeds
            .into_inner()
            .into_iter()
            .filter(|t| mono_key(t).is_some_and(|k| !have.contains(&format!("axion_drop_{k}"))))
            .collect();
        if !seeds.is_empty() {
            let extra = gen_mono_destructors(orig_module, &recinfo, &parametric_data, seeds);
            result.extend(extra.into_iter().filter(|f| !have.contains(&f.name)));
        }
    }
    // §9 structured fork-join worker state machines (same hand-managed nursery
    // arena as the session steps — they bypass the drop analysis too).
    result.extend(parmap_steps);
    // Per-param mono reclaim key, seeded ONLY for heap CONTAINER params (a `data`/`List`/tuple with
    // a concrete key) — the ones whose extracted elements need concrete resolution. Scalars,
    // `String`/`Integer` leaves, and polymorphic containers stay `None` (unchanged), keeping the
    // blast radius to container scrutinees.
    let param_keys: HashMap<String, Vec<Option<String>>> = fn_param_types
        .iter()
        .map(|(name, tys)| {
            let keys = tys
                .iter()
                .map(|ty| {
                    // a function-typed param is a closure cell (key `Closure`)
                    if heap_ty(ty, &data_types) || matches!(ty, Type::Arrow { .. }) {
                        mono_key(ty)
                    } else {
                        None
                    }
                })
                .collect();
            (name.clone(), keys)
        })
        .collect();
    // bounds-check elimination by loop versioning (`bce.rs`): a counting loop whose accesses are
    // provably in bounds for every iteration runs a check-free clone `f$bce` (same Core, same
    // drops); its parameter ownership is `f`'s. `AXION_NO_BCE` turns it off (measurement/tests).
    let mut borrow_args = borrow_args;
    let mut param_keys = param_keys;
    let mut param_leaf: HashMap<String, Vec<Option<String>>> = fn_param_types
        .iter()
        .map(|(name, tys)| {
            let leaf = tys
                .iter()
                .map(|t| match t {
                    Type::Con(h) if matches!(h.as_str(), "String" | "Integer") => Some(h.clone()),
                    // a moved-in closure is this function's: storing it twice is a duplication
                    Type::Arrow { .. } => Some("Closure".to_string()),
                    t if t.head_con() == Some("Buffer") => Some("Buffer".to_string()),
                    _ => None,
                })
                .collect();
            (name.clone(), leaf)
        })
        .collect();
    if std::env::var_os("AXION_NO_BCE").is_none() {
        let before: HashSet<String> = result.iter().map(|f| f.name.clone()).collect();
        crate::bce::version_counting_loops(&mut result);
        for f in &result {
            if before.contains(&f.name) {
                continue;
            }
            if let Some(orig) = f.name.strip_suffix("$bce") {
                if let Some(b) = borrow_args.get(orig).cloned() {
                    borrow_args.insert(f.name.clone(), b);
                }
                if let Some(k) = param_keys.get(orig).cloned() {
                    param_keys.insert(f.name.clone(), k);
                }
                if let Some(k) = param_leaf.get(orig).cloned() {
                    param_leaf.insert(f.name.clone(), k);
                }
            }
        }
    }
    Lowered {
        fns: result,
        borrow_args,
        recinfo,
        param_keys,
        param_leaf,
    }
}

/// Generates the recursive destructors `axion_drop_<T>` for each type with
/// heap (deep-drop, §2): frees the owned `data`-typed fields (via their
/// destructor, or `free` if they are leaves) and then the block itself;
/// sum types dispatch on the tag.
fn gen_destructors(
    recinfo: &RecordInfo,
    parametric_data: &HashSet<String>,
    mono_seeds: &mut Vec<Type>,
) -> Vec<CoreFn> {
    let mut out = Vec::new();
    for ty in recinfo.deep_drop_types() {
        let p = "_p".to_string();
        let mut ctr = 0u32;
        // each constructor's tag and the (offset, way) of the heap fields it owns:
        // a concrete `data` field with heap → its destructor, else a flat free.
        // `drop_way` keys a parametric field on its mono destructor (`List String`
        // → `axion_drop_List$String`) and seeds it, so the heap ELEMENTS are freed.
        let mut cons: Vec<(i64, Vec<(i32, DropWay)>)> = Vec::new();
        for con in recinfo.type_cons(&ty).unwrap_or(&[]) {
            let tag = recinfo.tag(con).unwrap_or(0) as i64;
            let mut slots = Vec::new();
            for (off, fty) in recinfo.drop_slots(con) {
                slots.push((*off, drop_way(fty, recinfo, parametric_data, mono_seeds)));
            }
            cons.push((tag, slots));
        }
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
            DropWay::Str => Op::RtCall {
                func: "axion_str_drop".into(),
                args: vec![Atom::Var(fp.clone())],
                returns: false,
            },
            DropWay::Bignum => Op::RtCall {
                func: "axion_bignum_free".into(),
                args: vec![Atom::Var(fp.clone())],
                returns: false,
            },
            DropWay::Buf => Op::RtCall {
                func: "axion_buf_free".into(),
                args: vec![Atom::Var(fp.clone())],
                returns: false,
            },
            DropWay::Closure => Op::RtCall {
                func: "axion_closure_drop".into(),
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

/// R-5 deep-copier (docs/call-site-ownership.md): generate a per-type `axion_copy_<key>`
/// for each seed (and, transitively, for every heap-field type reached through
/// `drop_way`). Mirrors `gen_mono_destructors` — same per-constructor `(offset, DropWay)`
/// slot resolution under the type-argument substitution, so mono containers (`List$Integer`)
/// and concrete `data` types are handled uniformly — but emits `copier_body` instead of
/// `destructor_body`. Managed by hand, so skipped by Auto-Drop and the verifier.
fn gen_copiers(
    seeds: Vec<Type>,
    module: &ast::Module,
    recinfo: &RecordInfo,
    parametric_data: &HashSet<String>,
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
        // TUPLE copier: a tuple has no `data` decl — one implicit constructor (tag 0) whose
        // heap slots sit at `i*8`. Build its slots (threading `work` so a container/`data`
        // element gets its own `axion_copy_<elem>` too) and reuse the single-con `copier_body`
        // (shell-copy + per-heap-slot fixup). A nested-tuple element is `DropWay::None` (the
        // documented nested-tuple-in-tuple residual, shared not freed by its destructor → a
        // leak, never a double-free). Mirrors `gen_tuple_destructors`.
        if let Type::Tuple(ts) = &t {
            let slots: Vec<(i32, DropWay)> = ts
                .iter()
                .enumerate()
                .filter_map(
                    |(i, el)| match drop_way(el, recinfo, parametric_data, &mut work) {
                        DropWay::None => None,
                        way => {
                            // a plain `data` element needs its own copier too (see below)
                            if matches!(way, DropWay::Deep(_)) && matches!(el, Type::Con(_)) {
                                work.push(el.clone());
                            }
                            Some((i as i32 * 8, way))
                        }
                    },
                )
                .collect();
            let p = "_p".to_string();
            let mut ctr = 0u32;
            let body = copier_body(&[(0i64, slots)], true, false, &p, &mut ctr);
            out.push(CoreFn {
                name: format!("axion_copy_{key}"),
                params: vec![p],
                captures: Vec::new(),
                is_closure: false,
                owned_params: Vec::new(),
                owned_drop_ty: Vec::new(),
                body,
            });
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
        // per-constructor heap slots under the substitution; each Deep field type is
        // pushed onto `work`, so its own `axion_copy_<field>` is generated too.
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
                            way => {
                                // `drop_way` queues parametric/tuple types only (plain `data`
                                // DESTRUCTORS always exist); a plain `data` field needs its own
                                // COPIER generated too (`axion_copy_Act` for a `List Act`)
                                if matches!(way, DropWay::Deep(_)) && matches!(rty, Type::Con(_)) {
                                    work.push(rty.clone());
                                }
                                Some((recinfo.field_offset(&con.name, i), way))
                            }
                        }
                    })
                    .collect()
            })
            .collect();
        let cons: Vec<(i64, Vec<(i32, DropWay)>)> = d
            .cons
            .iter()
            .zip(all_slots)
            .map(|(c, slots)| (recinfo.tag(&c.name).unwrap_or(0) as i64, slots))
            .collect();
        let p = "_p".to_string();
        let mut ctr = 0u32;
        let body = copier_body(
            &cons,
            d.cons.len() <= 1,
            recinfo.is_mixed_type(head),
            &p,
            &mut ctr,
        );
        out.push(CoreFn {
            name: format!("axion_copy_{key}"),
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

/// The copier body (R-5): shell-copy the block, then overwrite each heap slot with a
/// fresh recursive copy. `axion_block_copy` duplicates the whole block byte-for-byte
/// (tag + scalar fields correct; heap-child pointers SHARED), then `emit_field_copies`
/// replaces every heap slot of the matching constructor with a fresh deep copy — so no
/// child is ever shared across the original and the copy. Symmetric to `destructor_body`.
fn copier_body(
    cons: &[(i64, Vec<(i32, DropWay)>)],
    single: bool,
    mixed: bool,
    p: &str,
    ctr: &mut u32,
) -> Term {
    let q = "_q".to_string();
    let ret_q = Term::Ret(Rhs::Op(Op::Atom(Atom::Var(q.clone()))), NO_SPAN);
    let fixups = if single {
        match cons.first() {
            Some((_, slots)) => emit_field_copies(slots, p, &q, ctr, ret_q),
            None => ret_q,
        }
    } else {
        // multi-con: load the tag and one independent `if` per constructor with heap
        // fields; only the matching tag's slots are deep-copied, the rest already
        // correct from the shell copy. Falls through to `ret q`.
        let mut chain = ret_q;
        for (tag, slots) in cons.iter().rev() {
            if slots.is_empty() {
                continue;
            }
            let branch = emit_field_copies(slots, p, &q, ctr, unit0());
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
    let alloc_and_fix = Term::Let(
        q.clone(),
        Rhs::Op(Op::RtCall {
            func: "axion_block_copy".into(),
            args: vec![Atom::Var(p.to_string())],
            returns: true,
        }),
        NO_SPAN,
        Box::new(fixups),
    );
    if mixed {
        // a tagged immediate (low bit) is a value, not a heap block: return it as-is,
        // never dereferencing it for the tag/field fixup.
        let bit = fresh_dd(ctr);
        Term::Let(
            bit.clone(),
            Rhs::Op(Op::Prim(
                "band".into(),
                Atom::Var(p.to_string()),
                Atom::Int(1),
            )),
            NO_SPAN,
            Box::new(Term::Ret(
                Rhs::If(
                    Atom::Var(bit),
                    Box::new(Term::Ret(
                        Rhs::Op(Op::Atom(Atom::Var(p.to_string()))),
                        NO_SPAN,
                    )),
                    Box::new(alloc_and_fix),
                ),
                NO_SPAN,
            )),
        )
    } else {
        alloc_and_fix
    }
}

/// Overwrite each heap slot of `q` (the shell copy) with a fresh recursive copy of the
/// corresponding slot read from `p` (the original): `Deep` → `axion_copy_<name>`, `Flat`
/// → `axion_block_copy` (a pointerless payload), `Str` → `strAppend x ""`, `Bignum` →
/// `axion_bignum_copy`. See [`copier_body`].
fn emit_field_copies(
    slots: &[(i32, DropWay)],
    p: &str,
    q: &str,
    ctr: &mut u32,
    cont: Term,
) -> Term {
    let mut term = cont;
    for (off, way) in slots.iter().rev() {
        let child = fresh_dd(ctr);
        let fresh = fresh_dd(ctr);
        let copy = match way {
            DropWay::Deep(name) => Op::CallDirect(
                format!("axion_copy_{name}"),
                vec![Atom::Var(child.clone())],
                Some(name.clone()),
            ),
            DropWay::Flat => Op::RtCall {
                func: "axion_block_copy".into(),
                args: vec![Atom::Var(child.clone())],
                returns: true,
            },
            DropWay::Str => Op::RtCall {
                func: "axion_strcat".into(),
                args: vec![Atom::Var(child.clone()), Atom::Str(String::new())],
                returns: true,
            },
            DropWay::Bignum => Op::RtCall {
                func: "axion_bignum_copy".into(),
                args: vec![Atom::Var(child.clone())],
                returns: true,
            },
            DropWay::Buf => Op::RtCall {
                func: "axion_buf_copy".into(),
                args: vec![Atom::Var(child.clone())],
                returns: true,
            },
            DropWay::Closure => Op::RtCall {
                func: "axion_closure_copy".into(),
                args: vec![Atom::Var(child.clone())],
                returns: true,
            },
            DropWay::None => continue,
        };
        term = Term::Let(
            child.clone(),
            Rhs::Op(Op::LoadRaw(Atom::Var(p.to_string()), *off)),
            NO_SPAN,
            Box::new(Term::Let(
                fresh.clone(),
                Rhs::Op(copy),
                NO_SPAN,
                Box::new(Term::Let(
                    fresh_dd(ctr),
                    Rhs::Op(Op::StoreRaw(
                        Atom::Var(q.to_string()),
                        *off,
                        Atom::Var(fresh),
                    )),
                    NO_SPAN,
                    Box::new(term),
                )),
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
        // every function value is a closure cell with the same runtime reclaimer
        Type::Arrow { .. } => Some("Closure".to_string()),
        Type::Tuple(ts) => {
            let parts: Vec<String> = ts.iter().map(mono_key).collect::<Option<Vec<_>>>()?;
            // Encode the ARITY in the head token (`tuple2$A$B`, `tuple3$A$B$C`) so a NESTED
            // tuple key is unambiguously segmentable: `consume_one_key` reads N from `tupleN`
            // and consumes exactly N sub-keys, recursing. Without the count, `tuple$tuple$…`
            // could not be split (the inner arities were lost), forcing a conservative
            // shell-free/leak for every nested-tuple reclamation.
            if parts.is_empty() {
                Some("tuple0".to_string())
            } else {
                Some(format!("tuple{}${}", parts.len(), parts.join("$")))
            }
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
    Str,          // a `String` field → `axion_str_drop` (frees a heap string, skips a literal)
    Bignum,       // an `Integer` field → `axion_bignum_free` (frees the boxed BigNum + limbs)
    Buf,          // a `Buffer a` → `axion_buf_free` (frees the libc-malloc'd header pointer)
    Closure,      // a function value → `axion_closure_drop` / `axion_closure_copy`
    None,         // not a heap object (Int/function/tuple) → nothing to do
}

/// How to drop a (concrete) field type; pushes any parametric instantiation it
/// references onto the worklist so its specialized destructor is generated too.
fn drop_way(
    t: &Type,
    recinfo: &RecordInfo,
    parametric_data: &HashSet<String>,
    work: &mut Vec<Type>,
) -> DropWay {
    // A TUPLE field/element (`(Int,Int)` in a `List (Int,Int)`, a record field, or a nested
    // tuple) owns a heap cell → its per-arity destructor `axion_drop_tuple$…` (which shell-frees
    // the cell and deep-drops any heap elements). Without this a container of tuples freed only
    // its spine, leaking every tuple cell. Seed the tuple so `gen_tuple_destructors` emits it.
    if let Type::Tuple(_) = t {
        return match mono_key(t) {
            Some(key) => {
                work.push(t.clone());
                DropWay::Deep(key)
            }
            None => DropWay::None,
        };
    }
    // a function value: a closure cell (`axion_closure_drop` runs its destructor, if it owns
    // captures, then frees it)
    if let Type::Arrow { .. } = t {
        return DropWay::Closure;
    }
    let (head, args) = ty_head_args(t);
    let Some(head) = head else {
        return DropWay::None;
    };
    // a `String` field owns a heap C-string (or a static literal) → the tagged
    // `axion_str_drop` reclaims it. Otherwise a `List String` / record-of-String
    // frees its spine but leaks the elements.
    if head == "String" {
        return DropWay::Str;
    }
    // an `Integer` field owns a boxed BigNum → the tagged `axion_bignum_free` reclaims it
    // (so a `List Integer` / record-of-Integer frees its elements, not just the spine).
    if head == "Integer" {
        return DropWay::Bignum;
    }
    // a `Buffer a` is a linear byte buffer (libc-malloc, header-pointer layout) → axion_buf_free.
    // This makes `newBuffer` results (and `withBuffer`'s internal buffer) auto-reclaimed.
    if head == "Buffer" {
        return DropWay::Buf;
    }
    if recinfo.type_cons(head).is_none() {
        return DropWay::None; // not a `data` type (Int/function/tuple)
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

/// Every mono key a type (and each of its sub-terms) is known by → the type, so a copy at a
/// key can seed its generated copier (`copy_seeds` hold types).
fn register_type_keys(t: &Type, out: &mut HashMap<String, Type>) {
    if let Some(k) = mono_key(t) {
        out.entry(k).or_insert_with(|| t.clone());
    }
    match t {
        Type::App(f, a) => {
            register_type_keys(f, out);
            register_type_keys(a, out);
        }
        Type::Tuple(ts) => ts.iter().for_each(|x| register_type_keys(x, out)),
        Type::Arrow { from, to, .. } => {
            register_type_keys(from, out);
            register_type_keys(to, out);
        }
        _ => {}
    }
}

/// What [`own_escaping_closures`] reads about the module.
#[derive(Clone, Copy)]
struct ClosureOwnCx<'a> {
    /// the function being rewritten returns a fresh closure on every path (its caller owns what
    /// it returns), so a closure it returns may own its captures
    by_ret: bool,
    ba: &'a BorrowArgs,
    fn_param_types: &'a HashMap<String, Vec<Type>>,
    fn_result_types: &'a HashMap<String, Type>,
    boxed: &'a HashSet<String>,
    recinfo: &'a RecordInfo,
    type_by_key: &'a HashMap<String, Type>,
}

/// An owning closure's lambda → the destructor key of each capture (`None`: a scalar, nothing to
/// free), in capture order.
type OwningClosures = Vec<(String, Vec<Option<String>>)>;

/// How a value of type `t` is captured: `Some(None)` a scalar, `Some(Some(k))` a copyable heap
/// value with destructor key `k`, `None` unknown or not copyable (a closure, an array, a handle,
/// a type variable).
fn capture_kind_of_type(t: &Type, cx: &ClosureOwnCx) -> Option<Option<String>> {
    match t {
        Type::Tuple(_) => mono_key(t).filter(|_| !type_has_var_or_fun(t)).map(Some),
        _ => match t.head_con()? {
            "Int" | "Float" | "Bool" | "Char" => Some(None),
            "String" => Some(Some("String".into())),
            "Integer" => Some(Some("Integer".into())),
            h if cx.recinfo.type_cons(h).is_some() && !type_has_var_or_fun(t) => {
                if cx.boxed.contains(h) {
                    mono_key(t).map(Some)
                } else {
                    Some(None) // an enum: an immediate tag
                }
            }
            _ => None,
        },
    }
}

/// The concrete type of variable `v` in function `f`, when Core says it: a parameter's declared
/// type, the type behind a value's destructor key, or a tuple rebuilt from its components.
fn capture_type(
    v: &str,
    f: &CoreFn,
    lets: &HashMap<String, Op>,
    cx: &ClosureOwnCx,
) -> Option<Type> {
    if let Some(i) = f.params.iter().position(|p| p == v) {
        let tys = cx.fn_param_types.get(&f.name)?;
        // a function returning a closure declares more types than it has params (the leading
        // ones line up); lifted `where` captures lead the params (align to the tail then)
        let off = f.params.len().saturating_sub(tys.len());
        return tys.get(i.checked_sub(off)?).cloned();
    }
    let op = lets.get(v)?;
    if let Op::MakeTuple(xs) = op {
        let parts = xs
            .iter()
            .map(|a| match a {
                Atom::Var(w) => capture_type(w, f, lets, cx),
                Atom::Int(_) => Some(Type::Con("Int".into())),
                Atom::Str(_) => Some(Type::Con("String".into())),
                _ => None,
            })
            .collect::<Option<Vec<_>>>()?;
        return Some(Type::Tuple(parts));
    }
    let e = crate::delta::op_delta_effect(op, cx.ba);
    let k = e.produces.as_ref()?.key.clone()?;
    if let Some(t) = cx.type_by_key.get(&k) {
        return Some(t.clone());
    }
    // a plain (non-parametric) `data` type, String or Integer: the key is the type's name
    let plain =
        !k.contains('$') && (cx.recinfo.type_cons(&k).is_some() || k == "String" || k == "Integer");
    plain.then_some(Type::Con(k))
}

/// The capture kind (see [`capture_kind_of_type`]) of variable `v` in function `f`.
fn capture_kind(
    v: &str,
    f: &CoreFn,
    lets: &HashMap<String, Op>,
    cx: &ClosureOwnCx,
) -> Option<Option<String>> {
    if let Some(t) = capture_type(v, f, lets, cx) {
        return capture_kind_of_type(&t, cx);
    }
    // a let-bound scalar computation (no type recorded, but nothing to own)
    let op = lets.get(v)?;
    if crate::delta::op_delta_effect(op, cx.ba).produces.is_some() {
        return None;
    }
    match op {
        Op::Prim(..) | Op::IntToFloat(_) | Op::FloatToInt(_) | Op::FloatUnary(..) => Some(None),
        Op::Atom(Atom::Int(_) | Atom::Float(_)) => Some(None),
        Op::RtCall { func, .. } => crate::builtins::rt_entry(func)
            .filter(|r| r.out == crate::builtins::Out::Scalar)
            .map(|_| None),
        Op::CallDirect(g, _, None) => {
            let rt = cx.fn_result_types.get(g)?;
            capture_kind_of_type(rt, cx).filter(Option::is_none)
        }
        _ => None,
    }
}

/// `true` if the closure bound to `x` can outlive the scope it is made in: it is returned,
/// stored in a structure or another closure, or handed to a position that keeps it.
fn closure_escapes(x: &str, t: &Term, ba: &BorrowArgs) -> bool {
    closure_escapes_by(x, t, ba, true, true)
}

/// [`closure_escapes`], counting a `ret` of the closure as an escape only if `by_ret`, and a
/// constructor/tuple/record embedding it only if `by_con`.
fn closure_escapes_by(x: &str, t: &Term, ba: &BorrowArgs, by_ret: bool, by_con: bool) -> bool {
    fn op_keeps(x: &str, op: &Op, ba: &BorrowArgs, by_con: bool) -> bool {
        let is = |a: &Atom| matches!(a, Atom::Var(v) if v == x);
        match op {
            // a structure that frees its closure fields (key `…$Closure…`) owns the closure
            Op::MakeCon { args, .. } | Op::MakeTuple(args) if !by_con => {
                !args.iter().any(is) && op_mentions(op, x)
            }
            Op::MakeRecord { fields, .. } if !by_con => {
                !fields.iter().any(|(_, a)| is(a)) && op_mentions(op, x)
            }
            Op::CallClosure(_, args) => args.iter().any(is),
            Op::CallDirect(g, args, _) => args
                .iter()
                .enumerate()
                .any(|(i, a)| is(a) && !ba.get(g).is_some_and(|s| s.contains(&i))),
            Op::RtCall { func, args, .. } => {
                args.iter().any(is)
                    && !crate::builtins::rt_entry(func)
                        .is_some_and(|r| r.args == crate::builtins::ArgOwn::Borrow)
            }
            Op::Atom(_) => false, // an alias: followed by the caller
            _ => op_mentions(op, x),
        }
    }
    // `tail`: the rhs is a `ret` (a bare `x` there is the closure being returned)
    fn rhs_keeps(x: &str, r: &Rhs, ba: &BorrowArgs, by: (bool, bool), tail: bool) -> bool {
        match r {
            Rhs::Op(Op::Atom(Atom::Var(v))) => v == x && (by.0 || !tail),
            Rhs::Op(op) => op_keeps(x, op, ba, by.1),
            Rhs::If(_, a, b) => {
                closure_escapes_by(x, a, ba, by.0, by.1) || closure_escapes_by(x, b, ba, by.0, by.1)
            }
            Rhs::Case(_, arms) => arms
                .iter()
                .any(|(_, b)| closure_escapes_by(x, b, ba, by.0, by.1)),
        }
    }
    let by = (by_ret, by_con);
    match t {
        Term::Let(y, rhs, _, body) => {
            if let Rhs::Op(Op::Atom(Atom::Var(v))) = rhs {
                if v == x && closure_escapes_by(y, body, ba, by_ret, by_con) {
                    return true;
                }
            } else if rhs_keeps(x, rhs, ba, by, false) {
                return true;
            }
            closure_escapes_by(x, body, ba, by_ret, by_con)
        }
        Term::Drop(_, _, _, _, body) => closure_escapes_by(x, body, ba, by_ret, by_con),
        Term::Ret(rhs, _) => rhs_keeps(x, rhs, ba, by, true),
    }
}

/// `true` if `op` mentions variable `x` anywhere.
fn op_mentions(op: &Op, x: &str) -> bool {
    op_mentions_any(op, &HashSet::from([x.to_string()]))
}

/// Makes each ESCAPING closure own its heap captures: before the `closure` op, each heap capture
/// is copied (`axion_copy_<k>`, `strAppend s ""`, `axion_bignum_copy`) and the copy captured
/// instead; the op is marked `owns`, so the copies MOVE into the cell and its generated
/// destructor (`axion_drop_clo$<lambda>`, see [`gen_closure_dtors`]) frees them when the closure is
/// dropped. The scope keeps and frees its own values as for a closure that does not escape. A
/// closure with a capture whose type is unknown or not copyable (a closure, an array, a handle) is
/// left as is: it then keeps its captures alive by escaping with them, which the native gate
/// reports as a leak (AX0911) — never a use after free.
fn own_escaping_closures(
    out: &mut [CoreFn],
    cx: &ClosureOwnCx,
    copy_seeds: &mut Vec<Type>,
    mono_seeds: &mut Vec<Type>,
) -> OwningClosures {
    let mut owning: OwningClosures = Vec::new();
    let mut ctr = 0usize;
    // A closure that escapes only into a structure (which frees its closure fields: key
    // `…$Closure…`), or by being RETURNED from a function that returns a fresh closure on every
    // path (whose caller owns it, key `Closure`). A closure handed to a consuming parameter or to
    // another closure has no such owner, so it is left as is (it keeps its captures alive by
    // escaping with them: AX0911).
    let fresh = fresh_closure_fns(out);
    for f in out.iter_mut() {
        let cx = &ClosureOwnCx {
            by_ret: fresh.contains(&f.name),
            ..*cx
        };
        let mut lets: HashMap<String, Op> = HashMap::new();
        collect_let_ops(&f.body, &mut lets);
        let snapshot = f.clone();
        let body = std::mem::replace(
            &mut f.body,
            Term::Ret(Rhs::Op(Op::Atom(Atom::Int(0))), NO_SPAN),
        );
        f.body = own_in_term(
            body,
            &snapshot,
            &lets,
            cx,
            &mut owning,
            &mut ctr,
            copy_seeds,
            mono_seeds,
        );
    }
    owning
}

fn collect_let_ops(t: &Term, out: &mut HashMap<String, Op>) {
    match t {
        Term::Let(x, rhs, _, body) => {
            match rhs {
                Rhs::Op(op) => {
                    out.insert(x.clone(), op.clone());
                }
                Rhs::If(_, a, b) => {
                    collect_let_ops(a, out);
                    collect_let_ops(b, out);
                }
                Rhs::Case(_, arms) => arms.iter().for_each(|(_, b)| collect_let_ops(b, out)),
            }
            collect_let_ops(body, out);
        }
        Term::Drop(_, _, _, _, body) => collect_let_ops(body, out),
        Term::Ret(rhs, _) => match rhs {
            Rhs::If(_, a, b) => {
                collect_let_ops(a, out);
                collect_let_ops(b, out);
            }
            Rhs::Case(_, arms) => arms.iter().for_each(|(_, b)| collect_let_ops(b, out)),
            Rhs::Op(_) => {}
        },
    }
}

/// The copies an owning closure needs: `Some((lets, new captures, capture keys))`, or `None` if a
/// capture cannot be owned (see [`own_escaping_closures`]).
#[allow(clippy::type_complexity)]
fn owning_copies(
    captures: &[Atom],
    f: &CoreFn,
    lets: &HashMap<String, Op>,
    cx: &ClosureOwnCx,
    ctr: &mut usize,
    copy_seeds: &mut Vec<Type>,
    mono_seeds: &mut Vec<Type>,
) -> Option<(Vec<(String, Op)>, Vec<Atom>, Vec<Option<String>>)> {
    let mut copies = Vec::new();
    let mut caps = Vec::new();
    let mut keys = Vec::new();
    let mut seeds: Vec<(Type, bool)> = Vec::new();
    for a in captures {
        let Atom::Var(v) = a else {
            caps.push(a.clone());
            keys.push(None);
            continue;
        };
        match capture_kind(v, f, lets, cx)? {
            None => {
                caps.push(a.clone());
                keys.push(None);
            }
            Some(k) => {
                let kind = match k.as_str() {
                    "String" => CopyKind::Str,
                    "Integer" => CopyKind::Int,
                    _ => {
                        let t = capture_type(v, f, lets, cx)?;
                        seeds.push((t, true));
                        CopyKind::Container(k.clone())
                    }
                };
                let c = format!("$clocopy{ctr}");
                *ctr += 1;
                copies.push((c.clone(), alias_copy_op(v, &kind)));
                caps.push(Atom::Var(c));
                keys.push(Some(k));
            }
        }
    }
    for (t, _) in seeds {
        if matches!(t, Type::Tuple(_) | Type::App(..)) {
            mono_seeds.push(t.clone());
        }
        copy_seeds.push(t);
    }
    Some((copies, caps, keys))
}

#[allow(clippy::too_many_arguments)]
fn own_in_term(
    t: Term,
    f: &CoreFn,
    lets: &HashMap<String, Op>,
    cx: &ClosureOwnCx,
    owning: &mut OwningClosures,
    ctr: &mut usize,
    copy_seeds: &mut Vec<Type>,
    mono_seeds: &mut Vec<Type>,
) -> Term {
    let wrap = |copies: Vec<(String, Op)>, sp: Span, inner: Term| {
        copies.into_iter().rev().fold(inner, |acc, (c, op)| {
            Term::Let(c, Rhs::Op(op), sp, Box::new(acc))
        })
    };
    match t {
        Term::Let(x, rhs, sp, body) => {
            let body = own_in_term(*body, f, lets, cx, owning, ctr, copy_seeds, mono_seeds);
            let rhs = own_in_rhs(rhs, f, lets, cx, owning, ctr, copy_seeds, mono_seeds);
            if let Rhs::Op(Op::MakeClosure {
                func,
                captures,
                owns: false,
            }) = &rhs
            {
                // it escapes, and only where an owner frees it with its captures
                if closure_escapes(&x, &body, cx.ba)
                    && !closure_escapes_by(&x, &body, cx.ba, !cx.by_ret, false)
                {
                    if let Some((copies, caps, keys)) =
                        owning_copies(captures, f, lets, cx, ctr, copy_seeds, mono_seeds)
                    {
                        owning.push((func.clone(), keys));
                        let op = Op::MakeClosure {
                            func: func.clone(),
                            captures: caps,
                            owns: true,
                        };
                        return wrap(copies, sp, Term::Let(x, Rhs::Op(op), sp, Box::new(body)));
                    }
                }
            }
            Term::Let(x, rhs, sp, Box::new(body))
        }
        Term::Drop(x, k, skip, sp, body) => Term::Drop(
            x,
            k,
            skip,
            sp,
            Box::new(own_in_term(
                *body, f, lets, cx, owning, ctr, copy_seeds, mono_seeds,
            )),
        ),
        Term::Ret(rhs, sp) => {
            // a closure made right at the return escapes (to a caller that owns it)
            if let (
                Rhs::Op(Op::MakeClosure {
                    func,
                    captures,
                    owns: false,
                }),
                true,
            ) = (&rhs, cx.by_ret)
            {
                if let Some((copies, caps, keys)) =
                    owning_copies(captures, f, lets, cx, ctr, copy_seeds, mono_seeds)
                {
                    owning.push((func.clone(), keys));
                    let op = Op::MakeClosure {
                        func: func.clone(),
                        captures: caps,
                        owns: true,
                    };
                    return wrap(copies, sp, Term::Ret(Rhs::Op(op), sp));
                }
            }
            Term::Ret(
                own_in_rhs(rhs, f, lets, cx, owning, ctr, copy_seeds, mono_seeds),
                sp,
            )
        }
    }
}

#[allow(clippy::too_many_arguments)]
fn own_in_rhs(
    r: Rhs,
    f: &CoreFn,
    lets: &HashMap<String, Op>,
    cx: &ClosureOwnCx,
    owning: &mut OwningClosures,
    ctr: &mut usize,
    copy_seeds: &mut Vec<Type>,
    mono_seeds: &mut Vec<Type>,
) -> Rhs {
    match r {
        Rhs::If(c, a, b) => Rhs::If(
            c,
            Box::new(own_in_term(
                *a, f, lets, cx, owning, ctr, copy_seeds, mono_seeds,
            )),
            Box::new(own_in_term(
                *b, f, lets, cx, owning, ctr, copy_seeds, mono_seeds,
            )),
        ),
        Rhs::Case(s, arms) => Rhs::Case(
            s,
            arms.into_iter()
                .map(|(p, b)| {
                    (
                        p,
                        own_in_term(b, f, lets, cx, owning, ctr, copy_seeds, mono_seeds),
                    )
                })
                .collect(),
        ),
        other => other,
    }
}

/// A closure call CONSUMES its arguments (the closure ABI: the lambda owns and frees them). A
/// parameter the function does not own (`run name p = … f p …`, `p :: Player`) handed to one is
/// therefore passed as a COPY, so the function only borrows it and its caller may keep using the
/// value — as for a parameter returned whole (`normalize_alias_returns`). Without it the function
/// silently consumed the parameter: the type checker (which sees `Player`, not `%1`) accepted
/// a second use the native verifier then refused. Only declared, copyable heap types.
fn copy_closure_call_params(
    out: &mut [CoreFn],
    cx: &ClosureOwnCx,
    copy_seeds: &mut Vec<Type>,
    mono_seeds: &mut Vec<Type>,
) {
    let mut ctr = 0usize;
    for f in out.iter_mut() {
        let Some(tys) = cx.fn_param_types.get(&f.name) else {
            continue;
        };
        if tys.len() < f.params.len() {
            continue; // lifted `where` captures lead the params
        }
        // param → how to copy it
        let mut kinds: HashMap<String, CopyKind> = HashMap::new();
        for (p, t) in f.params.iter().zip(tys) {
            if f.owned_params.contains(p) {
                continue;
            }
            let Some(Some(k)) = capture_kind_of_type(t, cx) else {
                continue;
            };
            let kind = match k.as_str() {
                "String" => CopyKind::Str,
                "Integer" => CopyKind::Int,
                _ => {
                    if matches!(t, Type::Tuple(_) | Type::App(..)) {
                        mono_seeds.push(t.clone());
                    }
                    copy_seeds.push(t.clone());
                    CopyKind::Container(k)
                }
            };
            kinds.insert(p.clone(), kind);
        }
        if kinds.is_empty() {
            continue;
        }
        let body = std::mem::replace(
            &mut f.body,
            Term::Ret(Rhs::Op(Op::Atom(Atom::Int(0))), NO_SPAN),
        );
        f.body = copy_callclo_args(body, &kinds, &mut ctr);
    }
}

fn copy_callclo_args(t: Term, kinds: &HashMap<String, CopyKind>, ctr: &mut usize) -> Term {
    let fix = |op: &mut Op, ctr: &mut usize| -> Vec<(String, Op)> {
        let mut copies = Vec::new();
        if let Op::CallClosure(_, args) = op {
            for a in args.iter_mut() {
                if let Atom::Var(v) = a {
                    if let Some(kind) = kinds.get(v) {
                        let c = format!("$clargcopy{ctr}");
                        *ctr += 1;
                        copies.push((c.clone(), alias_copy_op(v, kind)));
                        *a = Atom::Var(c);
                    }
                }
            }
        }
        copies
    };
    let wrap = |copies: Vec<(String, Op)>, sp: Span, inner: Term| {
        copies.into_iter().rev().fold(inner, |acc, (c, op)| {
            Term::Let(c, Rhs::Op(op), sp, Box::new(acc))
        })
    };
    let sub = |r: Rhs, ctr: &mut usize| -> Rhs {
        match r {
            Rhs::If(c, a, b) => Rhs::If(
                c,
                Box::new(copy_callclo_args(*a, kinds, ctr)),
                Box::new(copy_callclo_args(*b, kinds, ctr)),
            ),
            Rhs::Case(s, arms) => Rhs::Case(
                s,
                arms.into_iter()
                    .map(|(p, b)| (p, copy_callclo_args(b, kinds, ctr)))
                    .collect(),
            ),
            other => other,
        }
    };
    match t {
        Term::Let(x, rhs, sp, body) => {
            let body = copy_callclo_args(*body, kinds, ctr);
            match rhs {
                Rhs::Op(mut op) => {
                    let copies = fix(&mut op, ctr);
                    wrap(copies, sp, Term::Let(x, Rhs::Op(op), sp, Box::new(body)))
                }
                other => Term::Let(x, sub(other, ctr), sp, Box::new(body)),
            }
        }
        Term::Drop(x, k, skip, sp, body) => Term::Drop(
            x,
            k,
            skip,
            sp,
            Box::new(copy_callclo_args(*body, kinds, ctr)),
        ),
        Term::Ret(rhs, sp) => match rhs {
            Rhs::Op(mut op) => {
                let copies = fix(&mut op, ctr);
                wrap(copies, sp, Term::Ret(Rhs::Op(op), sp))
            }
            other => Term::Ret(sub(other, ctr), sp),
        },
    }
}

/// The functions that return a FRESH closure on every path (`mk n = … \z -> …`), directly or
/// through a call to another such function.
fn fresh_closure_fns(out: &[CoreFn]) -> HashSet<String> {
    fn fresh(t: &Term, lets: &HashMap<String, Op>, set: &HashSet<String>) -> bool {
        let op_fresh = |op: &Op| match op {
            Op::MakeClosure { .. } => true,
            Op::CallDirect(g, _, _) => set.contains(g),
            _ => false,
        };
        let rhs = |r: &Rhs| match r {
            Rhs::Op(Op::Atom(Atom::Var(v))) => lets.get(v).is_some_and(op_fresh),
            Rhs::Op(op) => op_fresh(op),
            Rhs::If(_, a, b) => fresh(a, lets, set) && fresh(b, lets, set),
            Rhs::Case(_, arms) => !arms.is_empty() && arms.iter().all(|(_, b)| fresh(b, lets, set)),
        };
        match t {
            Term::Let(_, _, _, body) | Term::Drop(_, _, _, _, body) => fresh(body, lets, set),
            Term::Ret(r, _) => rhs(r),
        }
    }
    let lets_of: Vec<HashMap<String, Op>> = out
        .iter()
        .map(|f| {
            let mut m = HashMap::new();
            collect_let_ops(&f.body, &mut m);
            m
        })
        .collect();
    let mut set: HashSet<String> = HashSet::new();
    loop {
        let before = set.len();
        for (f, lets) in out.iter().zip(&lets_of) {
            if !f.is_closure && fresh(&f.body, lets, &set) {
                set.insert(f.name.clone());
            }
        }
        if set.len() == before {
            break;
        }
    }
    set
}

/// Gives a call to a function that returns a fresh closure on every path the result key
/// `Closure`, so the caller owns the closure and frees it after its last call.
fn key_fresh_closure_calls(out: &mut [CoreFn]) {
    let set = fresh_closure_fns(out);
    if set.is_empty() {
        return;
    }
    fn rekey(t: &mut Term, set: &HashSet<String>) {
        let fix = |r: &mut Rhs| {
            if let Rhs::Op(Op::CallDirect(g, _, key @ None)) = r {
                if set.contains(g) {
                    *key = Some("Closure".into());
                }
            }
        };
        match t {
            Term::Let(_, r, _, body) => {
                fix(r);
                match r {
                    Rhs::If(_, a, b) => {
                        rekey(a, set);
                        rekey(b, set);
                    }
                    Rhs::Case(_, arms) => arms.iter_mut().for_each(|(_, b)| rekey(b, set)),
                    Rhs::Op(_) => {}
                }
                rekey(body, set);
            }
            Term::Drop(_, _, _, _, body) => rekey(body, set),
            Term::Ret(r, _) => {
                fix(r);
                match r {
                    Rhs::If(_, a, b) => {
                        rekey(a, set);
                        rekey(b, set);
                    }
                    Rhs::Case(_, arms) => arms.iter_mut().for_each(|(_, b)| rekey(b, set)),
                    Rhs::Op(_) => {}
                }
            }
        }
    }
    for f in out.iter_mut() {
        rekey(&mut f.body, &set);
    }
}

/// A structure frees the closures it holds, so it must own each one: a closure put into a
/// constructor, tuple or record is MOVED in only if it is a fresh closure (a lambda, a call
/// returning a fresh one, a copy) used nowhere else in the function; any other — a borrowed
/// parameter, an element of a borrowed structure, one embedded twice (`twice f = Cons f (Cons f
/// Nil)`) — is embedded as a COPY (`axion_closure_copy`). Otherwise two owners free one cell.
fn copy_embedded_closures(
    out: &mut [CoreFn],
    recinfo: &RecordInfo,
    makecon_tys: &HashMap<Span, Type>,
    fn_param_types: &HashMap<String, Vec<Type>>,
) {
    for f in out.iter_mut() {
        let mut lets: HashMap<String, Op> = HashMap::new();
        collect_let_ops(&f.body, &mut lets);
        // the variables known to hold a closure: a parameter declared with a function type (a
        // generic body specialized at one, `dupL$Closure`, has no keyed constructor to tell),
        // or a value whose key is `Closure`
        let mut closure_vars: HashSet<String> = HashSet::new();
        if let Some(tys) = fn_param_types.get(&f.name) {
            let off = f.params.len().saturating_sub(tys.len());
            for (i, p) in f.params.iter().enumerate() {
                if i >= off && matches!(tys.get(i - off), Some(Type::Arrow { .. })) {
                    closure_vars.insert(p.clone());
                }
            }
        }
        for (x, op) in &lets {
            let k = crate::delta::op_delta_effect(op, &HashMap::new())
                .produces
                .and_then(|r| r.key);
            if k.as_deref() == Some("Closure") {
                closure_vars.insert(x.clone());
            }
        }
        let mut uses: HashMap<String, usize> = HashMap::new();
        count_var_uses(&f.body, &mut uses);
        let fresh = |a: &str| {
            uses.get(a).copied().unwrap_or(0) == 1
                && lets.get(a).is_some_and(|op| match op {
                    Op::MakeClosure { .. } => true,
                    Op::CallDirect(_, _, Some(k)) => k == "Closure",
                    Op::RtCall { func, .. } => func == "axion_closure_copy",
                    _ => false,
                })
        };
        let mut ctr = 0usize;
        let body = std::mem::replace(
            &mut f.body,
            Term::Ret(Rhs::Op(Op::Atom(Atom::Int(0))), NO_SPAN),
        );
        let cx = EmbedCx {
            recinfo,
            makecon_tys,
            closure_vars: &closure_vars,
            fresh: &fresh,
        };
        f.body = copy_closures_in(body, &cx, &mut ctr);
    }
}

/// A function returning a closure gives its caller an owned one (key `Closure`), so a function-
/// typed parameter it does not own, returned whole (`pick b f g = if b then f else g`), is returned
/// as a COPY: else the caller and the argument's owner both free one cell. (The general
/// alias-return copy skips these functions: their declared types outnumber their parameters.)
fn copy_returned_closure_params(out: &mut [CoreFn], fn_param_types: &HashMap<String, Vec<Type>>) {
    let mut ctr = 0usize;
    for f in out.iter_mut() {
        let Some(tys) = fn_param_types.get(&f.name) else {
            continue;
        };
        if tys.len() < f.params.len() {
            continue; // lifted `where` captures lead: not a signed function's own params
        }
        let targets: HashMap<String, CopyKind> = f
            .params
            .iter()
            .zip(tys)
            .filter(|(p, t)| matches!(t, Type::Arrow { .. }) && !f.owned_params.contains(p))
            .map(|(p, _)| (p.clone(), CopyKind::Closure))
            .collect();
        if !targets.is_empty() {
            rewrite_alias_tails(&mut f.body, &targets, false, &mut ctr);
        }
    }
}

/// How many times each variable is mentioned in a term (as an operand anywhere).
fn count_var_uses(t: &Term, out: &mut HashMap<String, usize>) {
    let mut bump = |a: &Atom| {
        if let Atom::Var(v) = a {
            *out.entry(v.clone()).or_default() += 1;
        }
    };
    fn rhs(r: &Rhs, out: &mut HashMap<String, usize>) {
        match r {
            Rhs::Op(op) => {
                let e = crate::delta::op_delta_effect(op, &HashMap::new());
                for a in e
                    .borrows
                    .iter()
                    .chain(e.moves.iter())
                    .chain(e.nonstrict.iter())
                    .chain(e.alias.iter())
                {
                    if let Atom::Var(v) = a {
                        *out.entry(v.clone()).or_default() += 1;
                    }
                }
            }
            Rhs::If(c, a, b) => {
                if let Atom::Var(v) = c {
                    *out.entry(v.clone()).or_default() += 1;
                }
                count_var_uses(a, out);
                count_var_uses(b, out);
            }
            Rhs::Case(sc, arms) => {
                if let Atom::Var(v) = sc {
                    *out.entry(v.clone()).or_default() += 1;
                }
                arms.iter().for_each(|(_, b)| count_var_uses(b, out));
            }
        }
    }
    match t {
        Term::Let(_, r, _, body) => {
            rhs(r, out);
            count_var_uses(body, out);
        }
        Term::Drop(x, _, _, _, body) => {
            bump(&Atom::Var(x.clone()));
            count_var_uses(body, out);
        }
        Term::Ret(r, _) => rhs(r, out),
    }
}

/// What [`copy_closures_in`] reads.
struct EmbedCx<'a> {
    recinfo: &'a RecordInfo,
    makecon_tys: &'a HashMap<Span, Type>,
    closure_vars: &'a HashSet<String>,
    fresh: &'a dyn Fn(&str) -> bool,
}

/// The argument positions of a structure-building op that hold a closure: by the constructor's
/// key and field, the tuple's recorded type, or the operand being a known closure variable.
fn closure_slots(op: &Op, sp: Span, cx: &EmbedCx) -> Vec<usize> {
    let (args, by_type): (&[Atom], Vec<usize>) = match op {
        Op::MakeCon { con, args, ty } => (
            args,
            (0..args.len())
                .filter(|&i| {
                    cx.recinfo.field_is_closure(con, i)
                        || ty.as_ref().is_some_and(|k| {
                            cx.recinfo.poly_field_elem_key(con, i, k)
                                == Some(Some("Closure".to_string()))
                        })
                })
                .collect(),
        ),
        Op::MakeTuple(args) => (
            args,
            match cx.makecon_tys.get(&sp) {
                Some(Type::Tuple(ts)) if ts.len() == args.len() => ts
                    .iter()
                    .enumerate()
                    .filter(|(_, t)| matches!(t, Type::Arrow { .. }))
                    .map(|(i, _)| i)
                    .collect(),
                _ => Vec::new(),
            },
        ),
        _ => return Vec::new(),
    };
    (0..args.len())
        .filter(|i| {
            by_type.contains(i) || matches!(&args[*i], Atom::Var(v) if cx.closure_vars.contains(v))
        })
        .collect()
}

fn copy_closures_in(t: Term, cx: &EmbedCx, ctr: &mut usize) -> Term {
    // rewrites the closure operands of `op` that must be copied; returns the copy lets
    let fix = |op: &mut Op, sp: Span, ctr: &mut usize| -> Vec<(String, Op)> {
        let slots = closure_slots(op, sp, cx);
        let mut copies = Vec::new();
        let args = match op {
            Op::MakeCon { args, .. } | Op::MakeTuple(args) => args,
            _ => return copies,
        };
        for i in slots {
            if let Some(Atom::Var(a)) = args.get(i).cloned() {
                if (cx.fresh)(&a) {
                    continue;
                }
                let c = format!("$clocp{ctr}");
                *ctr += 1;
                copies.push((
                    c.clone(),
                    Op::RtCall {
                        func: "axion_closure_copy".into(),
                        args: vec![Atom::Var(a)],
                        returns: true,
                    },
                ));
                args[i] = Atom::Var(c);
            }
        }
        copies
    };
    let wrap = |copies: Vec<(String, Op)>, sp: Span, inner: Term| {
        copies.into_iter().rev().fold(inner, |acc, (c, op)| {
            Term::Let(c, Rhs::Op(op), sp, Box::new(acc))
        })
    };
    let sub = |r: Rhs, ctr: &mut usize| -> Rhs {
        match r {
            Rhs::If(c, a, b) => Rhs::If(
                c,
                Box::new(copy_closures_in(*a, cx, ctr)),
                Box::new(copy_closures_in(*b, cx, ctr)),
            ),
            Rhs::Case(s, arms) => Rhs::Case(
                s,
                arms.into_iter()
                    .map(|(p, b)| (p, copy_closures_in(b, cx, ctr)))
                    .collect(),
            ),
            other => other,
        }
    };
    match t {
        Term::Let(x, rhs, sp, body) => {
            let body = copy_closures_in(*body, cx, ctr);
            match rhs {
                Rhs::Op(mut op) => {
                    let copies = fix(&mut op, sp, ctr);
                    wrap(copies, sp, Term::Let(x, Rhs::Op(op), sp, Box::new(body)))
                }
                other => Term::Let(x, sub(other, ctr), sp, Box::new(body)),
            }
        }
        Term::Drop(x, k, skip, sp, body) => {
            Term::Drop(x, k, skip, sp, Box::new(copy_closures_in(*body, cx, ctr)))
        }
        Term::Ret(rhs, sp) => match rhs {
            Rhs::Op(mut op) => {
                let copies = fix(&mut op, sp, ctr);
                wrap(copies, sp, Term::Ret(Rhs::Op(op), sp))
            }
            other => Term::Ret(sub(other, ctr), sp),
        },
    }
}

/// A closure is a value: giving one away — to a call parameter the callee does not only borrow,
/// to a closure call, or under a new name (`let f0 = cs`) — while the original is still used
/// afterwards (`usePair cs 0` … `cs 0`) gives away a COPY (`axion_closure_copy`). Otherwise the
/// receiver frees the cell the caller still calls (the type checker allows the reuse: closures
/// are not linear). "Afterwards" is the rest of the function after the op, including the
/// continuation of every enclosing `let x = if/case`.
fn copy_live_closure_moves(
    out: &mut [CoreFn],
    ba: &BorrowArgs,
    fn_param_types: &HashMap<String, Vec<Type>>,
) {
    for f in out.iter_mut() {
        let mut lets: HashMap<String, Op> = HashMap::new();
        collect_let_ops(&f.body, &mut lets);
        let mut closure_vars: HashSet<String> = HashSet::new();
        if let Some(tys) = fn_param_types.get(&f.name) {
            let off = f.params.len().saturating_sub(tys.len());
            for (i, p) in f.params.iter().enumerate() {
                if i >= off && matches!(tys.get(i - off), Some(Type::Arrow { .. })) {
                    closure_vars.insert(p.clone());
                }
            }
        }
        for (x, op) in &lets {
            let k = crate::delta::op_delta_effect(op, &HashMap::new())
                .produces
                .and_then(|r| r.key);
            if k.as_deref() == Some("Closure") {
                closure_vars.insert(x.clone());
            }
        }
        if closure_vars.is_empty() {
            continue;
        }
        let mut ctr = 0usize;
        let body = std::mem::replace(
            &mut f.body,
            Term::Ret(Rhs::Op(Op::Atom(Atom::Int(0))), NO_SPAN),
        );
        f.body = clo_moves(body, &closure_vars, ba, &[], &mut ctr);
    }
}

fn clo_moves(
    t: Term,
    cv: &HashSet<String>,
    ba: &BorrowArgs,
    conts: &[&Term],
    ctr: &mut usize,
) -> Term {
    // the positions of `op` that take ownership of a closure variable still live in `after`
    let fix = |op: &mut Op, after: &[&Term], ctr: &mut usize| -> Vec<(String, Op)> {
        let live = |v: &str| {
            let set = HashSet::from([v.to_string()]);
            after.iter().any(|t| term_mentions_any(t, &set))
        };
        let mut copies = Vec::new();
        let mut copy = |a: &mut Atom, ctr: &mut usize| {
            if let Atom::Var(v) = a {
                if cv.contains(v.as_str()) && live(v) {
                    let c = format!("$clomv{ctr}");
                    *ctr += 1;
                    copies.push((
                        c.clone(),
                        Op::RtCall {
                            func: "axion_closure_copy".into(),
                            args: vec![Atom::Var(v.clone())],
                            returns: true,
                        },
                    ));
                    *a = Atom::Var(c);
                }
            }
        };
        match op {
            Op::CallDirect(g, args, _) if !g.starts_with("axion_") => {
                let borrowed = ba.get(g.as_str());
                for (j, a) in args.iter_mut().enumerate() {
                    if !borrowed.is_some_and(|s| s.contains(&j)) {
                        copy(a, ctr);
                    }
                }
            }
            Op::CallClosure(_, args) => args.iter_mut().for_each(|a| copy(a, ctr)),
            Op::Atom(a) => copy(a, ctr),
            _ => {}
        }
        copies
    };
    let wrap = |copies: Vec<(String, Op)>, sp: Span, inner: Term| {
        copies.into_iter().rev().fold(inner, |acc, (c, op)| {
            Term::Let(c, Rhs::Op(op), sp, Box::new(acc))
        })
    };
    match t {
        Term::Let(x, rhs, sp, body) => match rhs {
            Rhs::Op(mut op) => {
                let mut after: Vec<&Term> = vec![body.as_ref()];
                after.extend_from_slice(conts);
                let copies = fix(&mut op, &after, ctr);
                let body = clo_moves(*body, cv, ba, conts, ctr);
                wrap(copies, sp, Term::Let(x, Rhs::Op(op), sp, Box::new(body)))
            }
            Rhs::If(c, a, e) => {
                let rhs = {
                    let mut inner: Vec<&Term> = vec![body.as_ref()];
                    inner.extend_from_slice(conts);
                    Rhs::If(
                        c,
                        Box::new(clo_moves(*a, cv, ba, &inner, ctr)),
                        Box::new(clo_moves(*e, cv, ba, &inner, ctr)),
                    )
                };
                let body = clo_moves(*body, cv, ba, conts, ctr);
                Term::Let(x, rhs, sp, Box::new(body))
            }
            Rhs::Case(sc, arms) => {
                let rhs = {
                    let mut inner: Vec<&Term> = vec![body.as_ref()];
                    inner.extend_from_slice(conts);
                    Rhs::Case(
                        sc,
                        arms.into_iter()
                            .map(|(p, a)| (p, clo_moves(a, cv, ba, &inner, ctr)))
                            .collect(),
                    )
                };
                let body = clo_moves(*body, cv, ba, conts, ctr);
                Term::Let(x, rhs, sp, Box::new(body))
            }
        },
        Term::Drop(x, k, sk, sp, body) => {
            Term::Drop(x, k, sk, sp, Box::new(clo_moves(*body, cv, ba, conts, ctr)))
        }
        Term::Ret(rhs, sp) => match rhs {
            Rhs::Op(mut op) => {
                let copies = fix(&mut op, conts, ctr);
                wrap(copies, sp, Term::Ret(Rhs::Op(op), sp))
            }
            Rhs::If(c, a, e) => Term::Ret(
                Rhs::If(
                    c,
                    Box::new(clo_moves(*a, cv, ba, conts, ctr)),
                    Box::new(clo_moves(*e, cv, ba, conts, ctr)),
                ),
                sp,
            ),
            Rhs::Case(sc, arms) => Term::Ret(
                Rhs::Case(
                    sc,
                    arms.into_iter()
                        .map(|(p, a)| (p, clo_moves(a, cv, ba, conts, ctr)))
                        .collect(),
                ),
                sp,
            ),
        },
    }
}

/// The destructor and copier of each owning closure. `axion_drop_clo$<lambda> p` frees every heap
/// capture (at `p + (i+3)*8`, after `fn_ptr`, `dtor` and `copier`) with its key, then the cell;
/// `axion_copy_clo$<lambda> p` copies the cell and each heap capture. Called through the cell's
/// `dtor`/`copier` words by `axion_closure_drop`/`axion_closure_copy`.
fn gen_closure_dtors(owning: &OwningClosures) -> Vec<CoreFn> {
    let mut out = Vec::new();
    let mut done = HashSet::new();
    for (func, keys) in owning {
        if !done.insert(func.clone()) {
            continue;
        }
        let mut body = Term::Ret(
            Rhs::Op(Op::RtCall {
                func: "axion_free".into(),
                args: vec![Atom::Var("_p".into())],
                returns: false,
            }),
            NO_SPAN,
        );
        for (i, k) in keys.iter().enumerate().rev() {
            if let Some(k) = k {
                let c = format!("_c{i}");
                body = Term::Let(
                    c.clone(),
                    Rhs::Op(Op::LoadRaw(Atom::Var("_p".into()), (i as i32 + 3) * 8)),
                    NO_SPAN,
                    Box::new(Term::Drop(
                        c,
                        Some(k.clone()),
                        Vec::new(),
                        NO_SPAN,
                        Box::new(body),
                    )),
                );
            }
        }
        out.push(CoreFn {
            name: format!("axion_drop_clo${func}"),
            params: vec!["_p".into()],
            captures: Vec::new(),
            is_closure: false,
            owned_params: Vec::new(),
            owned_drop_ty: Vec::new(),
            body,
        });
        let slots: Vec<(i32, DropWay)> = keys
            .iter()
            .enumerate()
            .filter_map(|(i, k)| Some(((i as i32 + 3) * 8, drop_way_of_key(k.as_deref()?))))
            .collect();
        let mut ctr = 0u32;
        out.push(CoreFn {
            name: format!("axion_copy_clo${func}"),
            params: vec!["_p".into()],
            captures: Vec::new(),
            is_closure: false,
            owned_params: Vec::new(),
            owned_drop_ty: Vec::new(),
            body: copier_body(&[(0, slots)], true, false, "_p", &mut ctr),
        });
    }
    out
}

/// How a value with destructor key `k` is freed and copied (see [`DropWay`]).
fn drop_way_of_key(k: &str) -> DropWay {
    match k {
        "String" => DropWay::Str,
        "Integer" => DropWay::Bignum,
        "Buffer" => DropWay::Buf,
        "Closure" => DropWay::Closure,
        _ => DropWay::Deep(k.to_string()),
    }
}

/// The helpers behind an `Array` of heap elements (see [`ARROP`]), one set per element type `K`
/// the lowered code uses: `new$K n x` (every slot a copy of `x`, via the recursive `fill$K`),
/// `get$K a i` (a copy of the slot), `set$K a i x` (frees the replaced element, stores a copy
/// of `x`). Seeds the element copiers (`copy_seeds`) and destructors (`mono_seeds`), and returns
/// the `Array T` types whose element-freeing destructor is needed.
fn gen_array_helpers(
    result: &mut Vec<CoreFn>,
    array_tys: &HashMap<Span, Type>,
    copy_seeds: &mut Vec<Type>,
    mono_seeds: &mut Vec<Type>,
) -> Vec<Type> {
    let mut used: HashSet<String> = HashSet::new();
    for f in result.iter() {
        for_each_op(&f.body, &mut |op| {
            if let Op::CallDirect(g, _, _) = op {
                if let Some(rest) = g.strip_prefix(ARROP) {
                    if let Some((_, k)) = rest.split_once('$') {
                        used.insert(k.to_string());
                    }
                }
            }
        });
    }
    if used.is_empty() {
        return Vec::new();
    }
    // element key → element type, from the array types inference recorded
    let mut elem_of: HashMap<String, Type> = HashMap::new();
    for t in array_tys.values() {
        let (head, a) = ty_head_args(t);
        if head == Some("Array") {
            if let Some(el) = a.first() {
                if let Some(k) = mono_key(el) {
                    elem_of.entry(k).or_insert_with(|| (*el).clone());
                }
            }
        }
    }
    let mut keys: Vec<String> = used.into_iter().collect();
    keys.sort();
    let v = |n: &str| Atom::Var(n.to_string());
    let rt = |func: &str, args: Vec<Atom>| {
        Rhs::Op(Op::RtCall {
            func: func.to_string(),
            args,
            returns: true,
        })
    };
    let let_ = |x: &str, r: Rhs, body: Term| Term::Let(x.to_string(), r, NO_SPAN, Box::new(body));
    let ret = |r: Rhs| Term::Ret(r, NO_SPAN);
    let mut arrays = Vec::new();
    for k in keys {
        let Some(el) = elem_of.get(&k).cloned() else {
            continue;
        };
        let kind = match el.head_con() {
            Some("String") if !matches!(el, Type::Tuple(_)) => CopyKind::Str,
            Some("Integer") if !matches!(el, Type::Tuple(_)) => CopyKind::Int,
            _ => {
                copy_seeds.push(el.clone());
                CopyKind::Container(k.clone())
            }
        };
        // a parametric instance or a tuple needs its own destructor generated; a plain `data`
        // type always has one, and String/Integer use the runtime's
        if matches!(el, Type::Tuple(_) | Type::App(..)) {
            mono_seeds.push(el.clone());
        }
        arrays.push(Type::App(Box::new(Type::Con("Array".into())), Box::new(el)));
        let arr_key = Some(format!("Array${k}"));
        let fill = format!("{ARROP}fill${k}");
        let mk = |name: String, params: &[&str], body: Term| CoreFn {
            name,
            params: params.iter().map(|p| p.to_string()).collect(),
            captures: Vec::new(),
            is_closure: false,
            owned_params: Vec::new(),
            owned_drop_ty: Vec::new(),
            body,
        };
        // new$K n x = fill$K (axion_array_new n 0) 0 n x
        result.push(mk(
            format!("{ARROP}new${k}"),
            &["_n", "_x"],
            let_(
                "_a",
                rt("axion_array_new", vec![v("_n"), Atom::Int(0)]),
                ret(Rhs::Op(Op::CallDirect(
                    fill.clone(),
                    vec![v("_a"), Atom::Int(0), v("_n"), v("_x")],
                    arr_key.clone(),
                ))),
            ),
        ));
        // fill$K a i n x = if i < n then fill$K (set a i (copy x)) (i + 1) n x else a
        result.push(mk(
            fill.clone(),
            &["_a", "_i", "_n", "_x"],
            let_(
                "_c",
                Rhs::Op(Op::Prim("<".into(), v("_i"), v("_n"))),
                ret(Rhs::If(
                    v("_c"),
                    Box::new(let_(
                        "_y",
                        Rhs::Op(alias_copy_op("_x", &kind)),
                        let_(
                            "_b",
                            rt("axion_array_set", vec![v("_a"), v("_i"), v("_y")]),
                            let_(
                                "_j",
                                Rhs::Op(Op::Prim("+".into(), v("_i"), Atom::Int(1))),
                                ret(Rhs::Op(Op::CallDirect(
                                    fill.clone(),
                                    vec![v("_b"), v("_j"), v("_n"), v("_x")],
                                    arr_key.clone(),
                                ))),
                            ),
                        ),
                    )),
                    Box::new(ret(Rhs::Op(Op::Atom(v("_a"))))),
                )),
            ),
        ));
        // get$K a i = copy (axion_array_get a i)
        result.push(mk(
            format!("{ARROP}get${k}"),
            &["_a", "_i"],
            let_(
                "_w",
                rt("axion_array_get", vec![v("_a"), v("_i")]),
                ret(Rhs::Op(alias_copy_op("_w", &kind))),
            ),
        ));
        // set$K a i x = drop (axion_array_get a i); axion_array_set a i (copy x)
        result.push(mk(
            format!("{ARROP}set${k}"),
            &["_a", "_i", "_x"],
            let_(
                "_o",
                rt("axion_array_get", vec![v("_a"), v("_i")]),
                Term::Drop(
                    "_o".into(),
                    Some(k.clone()),
                    Vec::new(),
                    NO_SPAN,
                    Box::new(let_(
                        "_y",
                        Rhs::Op(alias_copy_op("_x", &kind)),
                        ret(rt("axion_array_set", vec![v("_a"), v("_i"), v("_y")])),
                    )),
                ),
            ),
        ));
    }
    arrays
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
        let free_shell = || {
            Term::Ret(
                Rhs::Op(Op::RtCall {
                    func: "axion_array_free".into(),
                    args: vec![Atom::Var("_p".into())],
                    returns: false,
                }),
                NO_SPAN,
            )
        };
        let body =
            if matches!(dw, DropWay::None | DropWay::Flat) && !matches!(elem_t, Type::Tuple(_)) {
                free_shell()
            } else {
                // free every element (last to first), then the block: `axion_arrop_dropfrom$K p i`
                // loops by recursion (Core has no loops).
                let go = format!("{ARROP}dropfrom${elem_key}");
                let v = |n: &str| Atom::Var(n.to_string());
                out.push(CoreFn {
                    name: go.clone(),
                    params: vec!["_p".into(), "_i".into()],
                    captures: Vec::new(),
                    is_closure: false,
                    owned_params: Vec::new(),
                    owned_drop_ty: Vec::new(),
                    body: Term::Let(
                        "_c".into(),
                        // `i >= 0`, as `-1 < i` (the backends lower `<`)
                        Rhs::Op(Op::Prim("<".into(), Atom::Int(-1), v("_i"))),
                        NO_SPAN,
                        Box::new(Term::Ret(
                            Rhs::If(
                                v("_c"),
                                Box::new(Term::Let(
                                    "_e".into(),
                                    Rhs::Op(Op::RtCall {
                                        func: "axion_array_get".into(),
                                        args: vec![v("_p"), v("_i")],
                                        returns: true,
                                    }),
                                    NO_SPAN,
                                    Box::new(Term::Drop(
                                        "_e".into(),
                                        Some(elem_key.clone()),
                                        Vec::new(),
                                        NO_SPAN,
                                        Box::new(Term::Let(
                                            "_j".into(),
                                            Rhs::Op(Op::Prim("-".into(), v("_i"), Atom::Int(1))),
                                            NO_SPAN,
                                            Box::new(Term::Ret(
                                                Rhs::Op(Op::CallDirect(
                                                    go.clone(),
                                                    vec![v("_p"), v("_j")],
                                                    None,
                                                )),
                                                NO_SPAN,
                                            )),
                                        )),
                                    )),
                                )),
                                Box::new(free_shell()),
                            ),
                            NO_SPAN,
                        )),
                    ),
                });
                Term::Let(
                    "_n".into(),
                    Rhs::Op(Op::RtCall {
                        func: "axion_array_len".into(),
                        args: vec![v("_p")],
                        returns: true,
                    }),
                    NO_SPAN,
                    Box::new(Term::Let(
                        "_i".into(),
                        Rhs::Op(Op::Prim("-".into(), v("_n"), Atom::Int(1))),
                        NO_SPAN,
                        Box::new(Term::Ret(
                            Rhs::Op(Op::CallDirect(go, vec![v("_p"), v("_i")], None)),
                            NO_SPAN,
                        )),
                    )),
                )
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

/// Tuple-owned %1: generates a destructor for a concrete tuple type whose
/// elements include heap-typed `data` objects.  The destructor deep-drops
/// each `data`-typed element and flat-frees the rest, then frees the shell.
/// Named `axion_drop_tuple$<mangle>` (matching the key from `mono_key`).
fn gen_tuple_destructors(
    seeds: &[Type],
    recinfo: &RecordInfo,
    parametric_data: &HashSet<String>,
) -> Vec<CoreFn> {
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
        // for each element, its reclamation via `drop_way` — a PARAMETRIC element (`List Integer`)
        // routes to its MONO destructor (`axion_drop_List$Integer`, seeded above), not the leaky
        // generic head (`axion_drop_List`), so the element's payloads (bignums/strings) are freed
        // too. Then free the tuple shell. (A nested TUPLE element yields `DropWay::None` → skipped,
        // the documented nested-tuple-in-tuple residual.)
        let mut body = free_then_ret(&p);
        if let Type::Tuple(ts) = t {
            for (i, el) in ts.iter().enumerate().rev() {
                let off = i as i32 * 8;
                let way = drop_way(el, recinfo, parametric_data, &mut Vec::new());
                if matches!(way, DropWay::None) {
                    continue; // scalar / nested tuple → no per-element free here
                }
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
                    DropWay::Str => Op::RtCall {
                        func: "axion_str_drop".into(),
                        args: vec![Atom::Var(fp.clone())],
                        returns: false,
                    },
                    DropWay::Bignum => Op::RtCall {
                        func: "axion_bignum_free".into(),
                        args: vec![Atom::Var(fp.clone())],
                        returns: false,
                    },
                    DropWay::Buf => Op::RtCall {
                        func: "axion_buf_free".into(),
                        args: vec![Atom::Var(fp.clone())],
                        returns: false,
                    },
                    DropWay::Closure => Op::RtCall {
                        func: "axion_closure_drop".into(),
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

/// Tuple SKIP-variant destructors: `axion_drop_tuple$…_skip_N` reclaims every heap element
/// of a concrete tuple type EXCEPT the listed (moved-out) slots, then frees the shell. The
/// twin of [`gen_skip_destructors`] for TUPLES, which are not registered `type_cons` so they
/// cannot go through that generator. Used when a peel deconstructor (`uncons`) moves the head
/// out of its `(a, List a)` result tuple while the tail (or a wildcard sibling) is discarded:
/// the moved-out slot must NOT be freed (it escaped into the caller), the rest must be. Seeds
/// are `(tuple_key, arity, skip_slots)`; the per-element reclamation is resolved from the
/// mono-key via [`RecordInfo::tuple_elem_drops`] (`String` → `axion_str_drop`, `Integer` →
/// `axion_bignum_free`, a nested container → its own mono destructor, a boxed no-heap data →
/// flat free, a scalar/nested-tuple → skipped). A seed whose non-skipped slots are all
/// no-drop yields nothing — `emit_drop` then falls back to the plain shell `axion_free`.
fn gen_tuple_skip_destructors(seeds: &[TupleSkipSeed], recinfo: &RecordInfo) -> Vec<CoreFn> {
    let mut seen: HashSet<(String, Vec<usize>)> = HashSet::new();
    let mut out = Vec::new();
    for (key, arity, skip) in seeds {
        let mut sorted_skip = skip.clone();
        sorted_skip.sort_unstable();
        sorted_skip.dedup();
        if sorted_skip.is_empty() || !seen.insert((key.clone(), sorted_skip.clone())) {
            continue;
        }
        let Some(elems) = recinfo.tuple_elem_drops(key, *arity) else {
            continue;
        };
        let p = "_p".to_string();
        let mut ctr = 0u32;
        let mut body = free_then_ret(&p);
        let mut any = false;
        for (i, el) in elems.iter().enumerate().rev() {
            if sorted_skip.contains(&i) {
                continue; // moved out of the result tuple → survives, do not free
            }
            // `None` = scalar/nested tuple → no per-element free; `Some(None)` = flat free;
            // `Some(Some(k))` = a tagged drop (`String`/`Integer`) or a mono destructor key.
            let Some(inner) = el else { continue };
            let fp = fresh_dd(&mut ctr);
            let arg = vec![Atom::Var(fp.clone())];
            let call = match inner.as_deref() {
                Some("String") => Op::RtCall {
                    func: "axion_str_drop".into(),
                    args: arg,
                    returns: false,
                },
                Some("Integer") => Op::RtCall {
                    func: "axion_bignum_free".into(),
                    args: arg,
                    returns: false,
                },
                Some(k) => Op::CallDirect(format!("axion_drop_{k}"), arg, None),
                None => Op::RtCall {
                    func: "axion_free".into(),
                    args: arg,
                    returns: false,
                },
            };
            any = true;
            let off = i as i32 * 8;
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
        if !any {
            continue; // all non-skipped slots are no-drop → shell-only free (emit_drop fallback)
        }
        let skip_name: String = sorted_skip
            .iter()
            .map(|i| i.to_string())
            .collect::<Vec<_>>()
            .join("_");
        out.push(CoreFn {
            name: format!("axion_drop_{key}_skip_{skip_name}"),
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
fn gen_skip_destructors(
    seeds: &[(String, Vec<usize>)],
    recinfo: &RecordInfo,
    parametric_data: &HashSet<String>,
    mono_seeds: &mut Vec<Type>,
) -> Vec<CoreFn> {
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
        let mut cons: Vec<(i64, Vec<(i32, DropWay)>)> = Vec::new();
        for con in recinfo.type_cons(ty).unwrap_or(&[]) {
            let tag = recinfo.tag(con).unwrap_or(0) as i64;
            let skip_offs: HashSet<i32> = sorted_skip
                .iter()
                .map(|&i| recinfo.field_offset(con, i))
                .collect();
            let mut remaining: Vec<(i32, DropWay)> = Vec::new();
            for (off, fty) in recinfo.drop_slots(con) {
                if !skip_offs.contains(off) {
                    remaining.push((*off, drop_way(fty, recinfo, parametric_data, mono_seeds)));
                }
            }
            cons.push((tag, remaining));
        }
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
fn build_all_drop_ty(
    fns: &[CoreFn],
    makecon_tys: &HashMap<Span, Type>,
    recinfo: &RecordInfo,
) -> HashMap<String, HashMap<String, Option<String>>> {
    let mut out = HashMap::new();
    for f in fns {
        let mut dty: HashMap<String, Option<String>> = f.owned_drop_ty.iter().cloned().collect();
        collect_drop_types(&f.body, makecon_tys, &mut dty);
        tuple_binder_keys(&f.body, recinfo, &mut dty);
        out.insert(f.name.clone(), dty);
    }
    out
}

/// The drop key of each heap field a `case` binds out of a TUPLE whose key is known
/// (`tuple2$Maybe$String$Int` → its first binder is a `Maybe$String`), so the field can be reclaimed
/// like any keyed value — in particular a payload it holds that one branch moves out and another
/// drops (`(m, k) -> case m of Just s -> if k == 1 then "a" else s`: without the key `s` leaked
/// on the `"a"` path). Forward walk, so keys chain through nested tuples.
fn tuple_binder_keys(t: &Term, recinfo: &RecordInfo, out: &mut HashMap<String, Option<String>>) {
    fn rhs_keys(rhs: &Rhs, recinfo: &RecordInfo, out: &mut HashMap<String, Option<String>>) {
        match rhs {
            Rhs::Op(_) => {}
            Rhs::If(_, a, b) => {
                tuple_binder_keys(a, recinfo, out);
                tuple_binder_keys(b, recinfo, out);
            }
            Rhs::Case(sc, arms) => {
                let key = match sc {
                    Atom::Var(s) => out.get(s).cloned().flatten(),
                    _ => None,
                };
                for (p, b) in arms {
                    if let (CPat::Tuple(subs), Some(k)) = (p, key.as_deref()) {
                        if let Some(elems) = recinfo.split_tuple_key(k, subs.len()) {
                            for (sp, el) in subs.iter().zip(elems) {
                                if let (CPat::Var(n), Some(Some(ek))) =
                                    (sp, recinfo.classify_tuple_elem(&el))
                                {
                                    out.entry(n.clone()).or_insert(Some(ek));
                                }
                            }
                        }
                    }
                    tuple_binder_keys(b, recinfo, out);
                }
            }
        }
    }
    match t {
        Term::Let(_, rhs, _, body) => {
            rhs_keys(rhs, recinfo, out);
            tuple_binder_keys(body, recinfo, out);
        }
        Term::Drop(_, _, _, _, body) => tuple_binder_keys(body, recinfo, out),
        Term::Ret(rhs, _) => rhs_keys(rhs, recinfo, out),
    }
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
            // String producers → reclaimed by the tagged `axion_str_drop` (§tc):
            // frees a heap string, skips a static literal (zero size-header).
            Op::ShowInt(_) => Some("String".into()),
            Op::RtCall { func, .. } if is_string_producer(func) => Some("String".into()),
            // Integer producers → reclaimed by `axion_bignum_free` (frees the boxed
            // BigNum struct + its limbs). Args are borrowed (see `delta`), so an Integer
            // value's owner drops it at its death.
            Op::RtCall { func, .. } if is_bignum_producer(func) => Some("Integer".into()),
            Op::RtCall { func, .. } if func == "axion_array_new" => Some("Array".into()),
            // in-place setters return the SAME owned resource (threaded handle) —
            // it carries the resource type so a flat-scope final binding is dropped
            // with the right free (a bare `drop` would flat-free a raw-malloc Array).
            Op::RtCall { func, .. } if func == "axion_array_set" => Some("Array".into()),
            Op::RtCall { func, .. } if func == "axion_tritvec_set" => Some("TritVec".into()),
            Op::RtCall { func, .. } if func == "axion_i8_set" => Some("I8Array".into()),
            Op::RtCall { func, .. } if func == "axion_i32_set" => Some("I32Array".into()),
            // TritVec (§10) is a flat block — no generated `axion_drop_TritVec`
            // exists, so `emit_drop` falls back to the flat `axion_free`, which is
            // exactly right (the packed bytes are inline). Returning `Some` here is
            // what marks the binding owned+droppable at its liveness death point.
            Op::RtCall { func, .. } if func == "axion_tritvec_new" => Some("TritVec".into()),
            // tritVecFromBuffer produces a fresh owned TritVec (borrows the buffer).
            Op::RtCall { func, .. } if func == "axion_tritvec_from_buffer" => {
                Some("TritVec".into())
            }
            // Buffer (§4): `newBuffer` allocates a fresh owned byte buffer, reclaimed by
            // `axion_buf_free` (see the `Some("Buffer")` arm in `emit_drop`). `bufIota`/
            // `xorInPlace` thread the SAME buffer through (in-place), so the threaded result
            // stays the one owned binding, like `axion_tritvec_set`.
            Op::RtCall { func, .. }
                if func == "axion_buf_new"
                    || func == "axion_file_read"
                    || func == "axion_buf_iota"
                    || func == "axion_buf_xor" =>
            {
                Some("Buffer".into())
            }
            // bulk builders: fresh owned resources reclaimed like their _new kin.
            Op::RtCall { func, .. } if func == "axion_tritvec_iota" => Some("TritVec".into()),
            Op::RtCall { func, .. } if func == "axion_array_iota" => Some("Array".into()),
            // I8Array constructors: fresh owned flat blocks, flat-freed like TritVec.
            Op::RtCall { func, .. } if func == "axion_i8_new" || func == "axion_i8_iota" => {
                Some("I8Array".into())
            }
            // I32Array constructors: likewise flat owned blocks.
            Op::RtCall { func, .. } if func == "axion_i32_new" || func == "axion_i32_iota" => {
                Some("I32Array".into())
            }
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
fn collect_drop_types(
    t: &Term,
    makecon_tys: &HashMap<Span, Type>,
    out: &mut HashMap<String, Option<String>>,
) {
    match t {
        Term::Let(x, rhs, span, body) => {
            if let Rhs::Op(op) = rhs {
                let mut ty = op.drop_ty();
                // R-4: a pure rename `let x = src` inherits `src`'s drop-type, so the
                // ownership the rename transfers (see `scan_body`) is reclaimed with the
                // RIGHT reclaimer (`drop x : String` → axion_str_drop, not a flat free that
                // the verifier flags as a WrongDropKey bad-free). `out` is built forward, so
                // `src`'s type is already recorded.
                if ty.is_none() {
                    if let Op::Atom(Atom::Var(src)) = op {
                        ty = out.get(src).cloned().flatten();
                    }
                }
                // Phase 4: `parMap`'s reply `List` element type is only known from
                // inference (this binding's span) — the RtCall carries no key field,
                // so key its drop concretely here for deep element reclamation.
                if let Op::RtCall { func, .. } = op {
                    if func == "axion_par_map" {
                        if let Some(mk) = makecon_tys
                            .get(span)
                            .and_then(mono_key)
                            .filter(|k| k.contains('$'))
                        {
                            ty = Some(mk);
                        }
                    }
                }
                // A tuple literal carries no key in its op; inference records its type at
                // the binding's span. Only a fully concrete key (every component resolved).
                if ty.is_none() && matches!(op, Op::MakeTuple(_)) {
                    ty = makecon_tys
                        .get(span)
                        .and_then(mono_key)
                        .filter(|k| k.starts_with("tuple"));
                }
                if ty.is_some() {
                    out.insert(x.clone(), ty);
                }
            }
            collect_rhs_drop_types(rhs, makecon_tys, out);
            collect_drop_types(body, makecon_tys, out);
        }
        Term::Drop(_, _, _, _, body) => collect_drop_types(body, makecon_tys, out),
        Term::Ret(rhs, _) => collect_rhs_drop_types(rhs, makecon_tys, out),
    }
}

fn collect_rhs_drop_types(
    rhs: &Rhs,
    makecon_tys: &HashMap<Span, Type>,
    out: &mut HashMap<String, Option<String>>,
) {
    match rhs {
        Rhs::Op(_) => {}
        Rhs::If(_, th, el) => {
            collect_drop_types(th, makecon_tys, out);
            collect_drop_types(el, makecon_tys, out);
        }
        Rhs::Case(_, arms) => {
            for (_, b) in arms {
                collect_drop_types(b, makecon_tys, out);
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

/// `true` if `v` is MOVED (consumed) by some op in `t`, per the single authority
/// (`delta::op_delta_effect`, which is `ba`-aware). A borrowing call (`addI z y` where `addI`
/// borrows both) is NOT a move — unlike the purely-syntactic `occurs_nonborrow`, which counts
/// every call argument as an escape. Used to recognise a heap value passed only to BORROWING
/// calls (a `foldl`/`sumV` accumulator or element) as borrowed-then-dead, hence reclaimable.
fn body_moves_var(v: &str, t: &Term, ba: &BorrowArgs) -> bool {
    fn op_moves_v(v: &str, op: &Op, ba: &BorrowArgs) -> bool {
        let e = crate::delta::op_delta_effect(op, ba);
        e.moves.iter().chain(e.alias.iter()).any(|a| atom_is(v, a))
    }
    fn in_rhs(v: &str, rhs: &Rhs, ba: &BorrowArgs) -> bool {
        match rhs {
            Rhs::Op(op) => op_moves_v(v, op, ba),
            Rhs::If(_, a, b) => body_moves_var(v, a, ba) || body_moves_var(v, b, ba),
            Rhs::Case(_, arms) => arms.iter().any(|(_, b)| body_moves_var(v, b, ba)),
        }
    }
    match t {
        Term::Let(_, rhs, _, body) => in_rhs(v, rhs, ba) || body_moves_var(v, body, ba),
        Term::Drop(_, _, _, _, body) => body_moves_var(v, body, ba),
        Term::Ret(rhs, _) => in_rhs(v, rhs, ba),
    }
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
        // an `if` CONDITION is a scalar read (borrow); a `case` SCRUTINEE, however,
        // is a consuming use of a heap value — the inner `case` deep/shell-frees it and
        // moves its fields out. So a heap field of a consumed scrutinee that flows into
        // an inner `case` ESCAPES (into that case), and the parent must NOT reclaim it as
        // part of its own scrutinee drop (that would free it before the inner case reads
        // it — the `mapFst … case t of (a,b) -> …` UAF). Counting it as a nonborrow use
        // excludes it from the parent's deep-drop (worst case a conservative leak, never a
        // double-free); the inner case owns and reclaims it.
        Rhs::If(_, t, e) => occurs_nonborrow(v, t) || occurs_nonborrow(v, e),
        Rhs::Case(scrut, arms) => {
            atom_is(v, scrut) || arms.iter().any(|(_, b)| occurs_nonborrow(v, b))
        }
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
            ..
        } => {
            // by-copy update reads the base (borrow) and allocates a new record with
            // copies of the fields; in-place mutates the base and returns it (escape). Copying
            // a linear field would be rejected by linearity, so the fields
            // copied ones are non-linear (safe aliasing, no double-free).
            (*inplace && atom_is(v, base)) || fields.iter().any(|(_, a)| atom_is(v, a))
        }
        Op::MakeClosure { owns: false, .. } => false, // borrows its captures
        Op::MakeClosure { captures, .. } => captures.iter().any(|a| atom_is(v, a)),
        Op::WithArena { parent, clos } => parent.iter().any(|a| atom_is(v, a)) || atom_is(v, clos),
        Op::ArenaAlloc(a) | Op::ArenaMark(a) | Op::ArenaRelease(a) => atom_is(v, a),
        Op::Promote(t, c) => atom_is(v, t) || atom_is(v, c),
        // String builtins READ their operands (return a fresh String), so the
        // operand is borrowed, not moved — matches `op_moves`/delta (§tc).
        Op::RtCall { func, .. }
            if func == "axion_strcat"
                || func == "axion_show_float"
                || func == "axion_bignum_to_string"
                // dot/matvec/sum readers read their operands, return a scalar — borrows.
                || func == "axion_tritvec_dot"
                || func == "axion_tritvec_matvec_sum"
                || func == "axion_i8_matvec_sum"
                || func == "axion_i8_sum"
                || func == "axion_i8_dot"
                || func == "axion_i8_dot_i8"
                || func == "axion_array_sum"
                || func == "axion_array_dot"
                || func == "axion_i32_sum"
                || func == "axion_i32_dot"
                || func == "axion_i32_matvec_sum"
                // tritVecFromBuffer reads the buffer, produces a fresh TritVec — borrow.
                || func == "axion_tritvec_from_buffer" =>
        {
            false
        }
        // Integer arithmetic/comparison READS its Integer/String operands — borrows,
        // like the String builtins (kept in sync with `op_moves`/delta).
        Op::RtCall { func, .. } if is_bignum_borrower(func) => false,
        // copying a closure cell only reads it
        Op::RtCall { func, .. } if func == "axion_closure_copy" => false,
        // an FFI argument is consumed only if declared `Own`; a runtime call follows the table
        Op::Ffi {
            args, arg_kinds, ..
        } => args
            .iter()
            .enumerate()
            .any(|(i, a)| atom_is(v, a) && arg_kinds.get(i).is_some_and(|k| k.own)),
        Op::RtCall { func, args, .. } => {
            crate::builtins::rt_entry(func)
                .is_none_or(|r| r.args != crate::builtins::ArgOwn::Borrow)
                && args.iter().any(|a| atom_is(v, a))
        }
        Op::PutStrLn(a) | Op::PutStr(a) | Op::ShowInt(a) => atom_is(v, a),
        Op::IntToFloat(a) | Op::FloatToInt(a) | Op::FloatUnary(_, a) => atom_is(v, a),
        // only in generated destructors (not analyzed) — a read, like `Field`
        Op::LoadRaw(..) => false,
        Op::ArrayNew { .. } => false,
        Op::Unsupported(_) => false,
    }
}

// --- view detection (spine-aliasing suffix returns) -----------------------------
//
// A "view" returns a suffix that ALIASES its list argument's spine (`case xs of
// Cons y ys -> … Cons y ys …`, e.g. `drop`/`dropWhile`/`span`/`splitAt` and any user
// function shaped like them). If such a param is BORROWED rather than moved, the result
// and the argument share cells and both get freed → double-free on the native backends.
//
// `compute_borrow_args` calls `destructures_and_embeds_recursive` to detect this and
// MOVE the param instead — automatically, for ANY function (no manual registry). Sound:
// embedding a borrowed-extracted spine field is unconditionally unsound-to-borrow, so the
// move is always correct (a would-be runtime double-free becomes a compile-time move; a
// caller that reused the input was already buggy). Precise: `filter` passes the tail to a
// *call* (not embedded) and only embeds the non-recursive *element*, so it is NOT a view.
// `unregistered_views` + its test guard the auto-move's completeness (it must move every
// view, so no borrowed param may still be one).

/// For each constructor, the field indices whose type is the SELF-type (the recursive
/// spine — e.g. field 1 of `Cons a (List a)`). Built from the module's `data` decls.
pub fn con_recursive_fields(datas: &[ast::DataDecl]) -> HashMap<String, Vec<usize>> {
    let mut out = HashMap::new();
    for d in datas {
        for c in &d.cons {
            let recs: Vec<usize> = c
                .fields
                .iter()
                .enumerate()
                .filter(|(_, f)| f.ty.head_con() == Some(d.name.as_str()))
                .map(|(i, _)| i)
                .collect();
            if !recs.is_empty() {
                out.insert(c.name.clone(), recs);
            }
        }
    }
    out
}

/// Names of functions that are STILL borrowed VIEWS: a borrowed param whose recursive
/// (spine) field is embedded into a constructor → a latent double-free. Empty is the
/// invariant the auto-move in `compute_borrow_args` must maintain (it should have moved
/// every view). A non-empty result means the auto-move missed one.
#[cfg(test)]
pub fn unregistered_views(
    fns: &[CoreFn],
    borrow_args: &BorrowArgs,
    con_recursive: &HashMap<String, Vec<usize>>,
) -> Vec<String> {
    let mut out = Vec::new();
    for f in fns {
        let Some(borrowed) = borrow_args.get(&f.name) else {
            continue;
        };
        let is_view = borrowed.iter().any(|&i| {
            f.params
                .get(i)
                .is_some_and(|p| destructures_and_embeds_recursive(p, &f.body, con_recursive))
        });
        if is_view {
            out.push(f.name.clone());
        }
    }
    out.sort();
    out
}

/// `true` if `p` is destructured by a `case p of Con(..)` whose RECURSIVE field binder
/// is embedded into a constructor within the arm — the aliasing view pattern.
fn destructures_and_embeds_recursive(
    p: &str,
    t: &Term,
    con_rec: &HashMap<String, Vec<usize>>,
) -> bool {
    match t {
        Term::Let(_, rhs, _, body) => {
            rhs_view(p, rhs, con_rec) || destructures_and_embeds_recursive(p, body, con_rec)
        }
        Term::Drop(_, _, _, _, body) => destructures_and_embeds_recursive(p, body, con_rec),
        Term::Ret(rhs, _) => rhs_view(p, rhs, con_rec),
    }
}

fn rhs_view(p: &str, rhs: &Rhs, con_rec: &HashMap<String, Vec<usize>>) -> bool {
    match rhs {
        Rhs::Op(_) => false,
        Rhs::If(_, t, e) => {
            destructures_and_embeds_recursive(p, t, con_rec)
                || destructures_and_embeds_recursive(p, e, con_rec)
        }
        Rhs::Case(scrut, arms) if atom_is(p, scrut) => arms.iter().any(|(pat, body)| {
            let CPat::Con(con, subs) = pat else {
                return false;
            };
            con_rec.get(con).is_some_and(|recs| {
                recs.iter().any(|&r| {
                    // A recursive (spine) field of a borrowed param is a VIEW when it escapes via
                    // the result — either EMBEDDED in a fresh con (`drop`'s `Cons y ys`) OR
                    // RETURNED DIRECTLY (`deleteBy`'s `Cons y ys -> ys`). Both alias the borrowed
                    // param's spine, so the caller freeing the param AND the result double-frees
                    // the shared tail; the auto-move relinquishes the param (leak the prefix, never
                    // a double-free). Direct return was missed before (only `embedded_in_con`).
                    matches!(subs.get(r), Some(CPat::Var(f))
                        if embedded_in_con(f, body) || returns_var_directly(f, body))
                })
            })
        }),
        Rhs::Case(_, arms) => arms
            .iter()
            .any(|(_, b)| destructures_and_embeds_recursive(p, b, con_rec)),
    }
}

/// `true` if `name` is RETURNED DIRECTLY at some tail position of `t` — as the returned atom,
/// through an `if`/`case`, or via an alias let (`let x = name` then `x` returned). This is the
/// direct-return counterpart of `embedded_in_con`: returning a borrowed param's recursive spine
/// field aliases it just as much as embedding it in a fresh con (`deleteBy`'s `Cons y ys -> ys`).
fn returns_var_directly(name: &str, t: &Term) -> bool {
    match t {
        // alias binding `let x = name`: `x` now aliases the field too.
        Term::Let(x, Rhs::Op(Op::Atom(Atom::Var(v))), _, body) if v == name => {
            returns_var_directly(x, body) || returns_var_directly(name, body)
        }
        Term::Let(_, _, _, body) => returns_var_directly(name, body),
        Term::Drop(_, _, _, _, body) => returns_var_directly(name, body),
        Term::Ret(Rhs::Op(Op::Atom(Atom::Var(v))), _) => v == name,
        Term::Ret(Rhs::If(_, t, e), _) => {
            returns_var_directly(name, t) || returns_var_directly(name, e)
        }
        Term::Ret(Rhs::Case(_, arms), _) => arms.iter().any(|(_, b)| returns_var_directly(name, b)),
        Term::Ret(_, _) => false,
    }
}

/// `true` if `name` is a direct atom argument of a `MakeCon`/`MakeTuple`/`MakeRecord`
/// anywhere in `t` — i.e. embedded into a heap value (that may escape).
fn embedded_in_con(name: &str, t: &Term) -> bool {
    match t {
        Term::Let(_, rhs, _, body) => rhs_embeds(name, rhs) || embedded_in_con(name, body),
        Term::Drop(_, _, _, _, body) => embedded_in_con(name, body),
        Term::Ret(rhs, _) => rhs_embeds(name, rhs),
    }
}

fn rhs_embeds(name: &str, rhs: &Rhs) -> bool {
    match rhs {
        Rhs::Op(op) => op_embeds(name, op),
        Rhs::If(_, t, e) => embedded_in_con(name, t) || embedded_in_con(name, e),
        Rhs::Case(_, arms) => arms.iter().any(|(_, b)| embedded_in_con(name, b)),
    }
}

fn op_embeds(name: &str, op: &Op) -> bool {
    match op {
        Op::MakeCon { args, .. } | Op::MakeTuple(args) => args.iter().any(|a| atom_is(name, a)),
        Op::MakeRecord { fields, .. } => fields.iter().any(|(_, a)| atom_is(name, a)),
        _ => false,
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
    let mut ctr = Uq {
        n: 0,
        seen: env.keys().cloned().collect(),
    };
    uq_term(&mut f.body, &mut env, &mut ctr);
}

/// The source name of a binder: `s$3` (a renamed `s`, see [`uq_bind`]) → `s`; any other name
/// as is (compiler temporaries such as `$nf1`, `_t3` keep theirs).
pub fn source_name(x: &str) -> &str {
    match x.rsplit_once('$') {
        Some((base, n))
            if !n.is_empty()
                && n.bytes().all(|b| b.is_ascii_digit())
                && base.chars().next().is_some_and(|c| c.is_alphabetic())
                && !base.contains('$') =>
        {
            base
        }
        _ => x,
    }
}

/// The renaming state of one function: a counter for fresh names, and every name bound so far.
struct Uq {
    n: u32,
    seen: HashSet<String>,
}

/// Renames the binder `x` (in place) to a fresh `x$N` iff the function already binds that name —
/// in scope (shadowing) or in a sibling scope (`Just s` in two `case`s) — and records the mapping
/// so later uses resolve to it. Every binder of a function ends up with its own name: the
/// drop types and the verifier key values by name, and two binders of different types sharing
/// one would be freed with the wrong destructor.
fn uq_bind(x: &mut String, env: &mut HashMap<String, String>, ctr: &mut Uq) {
    let x2 = if env.contains_key(x.as_str()) || ctr.seen.contains(x.as_str()) {
        loop {
            ctr.n += 1;
            let c = format!("{x}${}", ctr.n);
            if !ctr.seen.contains(&c) {
                break c;
            }
        }
    } else {
        x.clone()
    };
    ctr.seen.insert(x.clone());
    ctr.seen.insert(x2.clone());
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

fn uq_term(t: &mut Term, env: &mut HashMap<String, String>, ctr: &mut Uq) {
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

fn uq_rhs(rhs: &mut Rhs, env: &mut HashMap<String, String>, ctr: &mut Uq) {
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

fn uq_pat(pat: &mut CPat, env: &mut HashMap<String, String>, ctr: &mut Uq) {
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

/// Removes every `let x = p` where `p` is in `params`, renaming uses of `x` to `p`. Relies on the
/// uniquify invariant (see [`renamed`]), so neither name is re-bound in the body.
fn collapse_param_aliases(t: Term, params: &HashSet<String>) -> Term {
    fn in_rhs(rhs: Rhs, params: &HashSet<String>) -> Rhs {
        match rhs {
            Rhs::If(c, a, b) => Rhs::If(
                c,
                Box::new(collapse_param_aliases(*a, params)),
                Box::new(collapse_param_aliases(*b, params)),
            ),
            Rhs::Case(s, arms) => Rhs::Case(
                s,
                arms.into_iter()
                    .map(|(p, b)| (p, collapse_param_aliases(b, params)))
                    .collect(),
            ),
            op => op,
        }
    }
    match t {
        Term::Let(x, Rhs::Op(Op::Atom(Atom::Var(p))), _, body) if params.contains(&p) => {
            collapse_param_aliases(renamed(*body, &x, &p), params)
        }
        Term::Let(x, rhs, sp, body) => Term::Let(
            x,
            in_rhs(rhs, params),
            sp,
            Box::new(collapse_param_aliases(*body, params)),
        ),
        Term::Drop(v, ty, skip, sp, body) => Term::Drop(
            v,
            ty,
            skip,
            sp,
            Box::new(collapse_param_aliases(*body, params)),
        ),
        Term::Ret(rhs, sp) => Term::Ret(in_rhs(rhs, params), sp),
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

// --- nested patterns → nested single-level cases (match compilation) ---

/// Is `p` a sub-pattern the backends destructure directly (a variable or `_`)?
fn flat_sub(p: &CPat) -> bool {
    matches!(p, CPat::Var(_) | CPat::Wild)
}

/// Does `p` (an arm's pattern) nest a refutable or destructuring pattern under a constructor or
/// tuple — the shape the native backends do not compile?
fn nests(p: &CPat) -> bool {
    match p {
        CPat::Con(_, ps) | CPat::Tuple(ps) => ps.iter().any(|q| !flat_sub(q)),
        _ => false,
    }
}

/// One row of a pattern matrix: the patterns for the current columns, and the arm body.
struct MRow {
    pats: Vec<CPat>,
    body: Term,
}

/// `p` with every variable replaced by `_` (a pattern that only tests the shape).
fn strip_vars(p: &CPat) -> CPat {
    match p {
        CPat::Var(_) => CPat::Wild,
        CPat::Con(c, ps) => CPat::Con(c.clone(), ps.iter().map(strip_vars).collect()),
        CPat::Tuple(ps) => CPat::Tuple(ps.iter().map(strip_vars).collect()),
        q => q.clone(),
    }
}

/// Compiles nested patterns into nested single-level `case`s — the code a programmer writes by
/// hand (`Cons a rest -> case rest of …`), which the backends, Auto-Drop and the drop-balance
/// verifier already handle. Classic match compilation over a pattern matrix: pick the first
/// refutable column of the first row, group the rows by its constructor (or literal), expand
/// sub-patterns into new columns, and send rows with a variable there to every group and to the
/// default arm. Order is preserved within each group, so the first matching arm still wins; a
/// row reachable from several groups is duplicated (in disjoint branches). Returns whether
/// anything changed (the caller re-runs `uniquify_fn`).
fn flatten_nested_patterns(f: &mut CoreFn) -> bool {
    fn term(t: Term, ctr: &mut u32, changed: &mut bool) -> Term {
        match t {
            Term::Let(x, Rhs::Case(Atom::Var(sc), arms), sp, body)
                if arms.iter().any(|(p, _)| nests(p)) =>
            {
                *changed = true;
                let compiled = term(compile_case(&sc, arms, sp, ctr), ctr, changed);
                splice_value(compiled, x, sp, term(*body, ctr, changed))
            }
            Term::Ret(Rhs::Case(Atom::Var(sc), arms), sp) if arms.iter().any(|(p, _)| nests(p)) => {
                *changed = true;
                term(compile_case(&sc, arms, sp, ctr), ctr, changed)
            }
            Term::Let(x, rhs, sp, body) => Term::Let(
                x,
                rhs_(rhs, ctr, changed),
                sp,
                Box::new(term(*body, ctr, changed)),
            ),
            Term::Drop(v, ty, skip, sp, body) => {
                Term::Drop(v, ty, skip, sp, Box::new(term(*body, ctr, changed)))
            }
            Term::Ret(rhs, sp) => Term::Ret(rhs_(rhs, ctr, changed), sp),
        }
    }
    fn rhs_(rhs: Rhs, ctr: &mut u32, changed: &mut bool) -> Rhs {
        // a variable arm beside other arms (`Nil -> ""; ys -> render ys`) names the scrutinee
        // itself: read it as the scrutinee, under a `_` arm, so Auto-Drop sees one value (an arm
        // reading its scrutinee whole is a view arm) instead of an alias of it
        let rhs = match rhs {
            Rhs::Case(Atom::Var(sc), arms)
                if arms.len() > 1 && arms.iter().any(|(p, _)| matches!(p, CPat::Var(_))) =>
            {
                *changed = true;
                Rhs::Case(
                    Atom::Var(sc.clone()),
                    arms.into_iter()
                        .map(|(p, b)| match p {
                            CPat::Var(v) => (CPat::Wild, renamed(b, &v, &sc)),
                            p => (p, b),
                        })
                        .collect(),
                )
            }
            rhs => rhs,
        };
        match rhs {
            Rhs::If(c, a, b) => Rhs::If(
                c,
                Box::new(term(*a, ctr, changed)),
                Box::new(term(*b, ctr, changed)),
            ),
            Rhs::Case(s, arms) => Rhs::Case(
                s,
                arms.into_iter()
                    .map(|(p, b)| (p, term(b, ctr, changed)))
                    .collect(),
            ),
            op => op,
        }
    }
    let mut ctr = 0;
    let mut changed = false;
    let body = std::mem::replace(
        &mut f.body,
        Term::Ret(Rhs::Op(Op::Atom(Atom::Int(0))), NO_SPAN),
    );
    f.body = term(body, &mut ctr, &mut changed);
    changed
}

fn compile_case(sc: &str, arms: Vec<(CPat, Term)>, sp: Span, ctr: &mut u32) -> Term {
    let rows = arms
        .iter()
        .map(|(p, body)| MRow {
            pats: vec![p.clone()],
            body: body.clone(),
        })
        .collect();
    let mut viewed = false;
    let direct = compile_matrix(sc, vec![sc.to_string()], rows, sp, ctr, &mut viewed);
    if !viewed {
        return direct;
    }
    // A row reached by falling through reads the matched value WHOLE (its catch-all variable,
    // or the scrutinee itself) inside an arm that has already taken the value apart — a shape
    // that cannot both move a payload out and keep the value. Match row by row instead: test
    // each row's SHAPE without binding anything (a scalar result; the scrutinee stays owned,
    // since both branches use it), then re-match the row that matched to bind its variables in
    // an ordinary consuming case.
    sequential(sc, &arms, sp, ctr)
}

/// `if <arm 0 matches> then <arm 0> else if <arm 1 matches> … else <the first catch-all arm>`.
fn sequential(sc: &str, arms: &[(CPat, Term)], sp: Span, ctr: &mut u32) -> Term {
    let Some(((pat, body), rest)) = arms.split_first() else {
        return Term::Ret(Rhs::Op(Op::Atom(Atom::Int(0))), sp);
    };
    let bind = |ctr: &mut u32| {
        let row = MRow {
            pats: vec![pat.clone()],
            body: body.clone(),
        };
        compile_matrix(sc, vec![sc.to_string()], vec![row], sp, ctr, &mut false)
    };
    if flat_sub(pat) || rest.is_empty() {
        return bind(ctr);
    }
    // the shape test: 1 when `pat` (variables stripped) matches, else 0
    let test_rows = vec![
        MRow {
            pats: vec![strip_vars(pat)],
            body: Term::Ret(Rhs::Op(Op::Atom(Atom::Int(1))), sp),
        },
        MRow {
            pats: vec![CPat::Wild],
            body: Term::Ret(Rhs::Op(Op::Atom(Atom::Int(0))), sp),
        },
    ];
    let test = compile_matrix(sc, vec![sc.to_string()], test_rows, sp, ctr, &mut false);
    *ctr += 1;
    let ok = format!("$nfok{ctr}");
    let then = bind(ctr);
    let other = sequential(sc, rest, sp, ctr);
    let branch = Term::Ret(
        Rhs::If(Atom::Var(ok.clone()), Box::new(then), Box::new(other)),
        sp,
    );
    splice_value(test, ok, sp, branch)
}

fn compile_matrix(
    top: &str,
    cols: Vec<String>,
    rows: Vec<MRow>,
    sp: Span,
    ctr: &mut u32,
    viewed: &mut bool,
) -> Term {
    let Some(first) = rows.first() else {
        // unreachable for an exhaustive `case` (AX0202 guarantees one): no group is built for a
        // constructor no row names, and the default arm exists only with catch-all rows
        return Term::Ret(Rhs::Op(Op::Atom(Atom::Int(0))), sp);
    };
    let Some(j) = first.pats.iter().position(|p| !flat_sub(p)) else {
        // the first row matches: bind its variables to their columns
        let Some(MRow { pats, mut body, .. }) = rows.into_iter().next() else {
            return Term::Ret(Rhs::Op(Op::Atom(Atom::Int(0))), sp);
        };
        for (p, c) in pats.iter().zip(&cols) {
            if let CPat::Var(v) = p {
                body = renamed(body, v, c);
            }
        }
        return body;
    };
    let col = cols[j].clone();
    let rest_cols = |extra: &[String]| -> Vec<String> {
        let mut c: Vec<String> = cols
            .iter()
            .enumerate()
            .filter(|(i, _)| *i != j)
            .map(|(_, c)| c.clone())
            .collect();
        c.extend_from_slice(extra);
        c
    };
    // a row whose column-j pattern is a variable or `_`, with that column removed (the variable
    // renamed to the column) and `width` `_`s appended for the group's new columns
    let catch_all = |r: &MRow, width: usize| -> Option<MRow> {
        let body = match &r.pats[j] {
            CPat::Var(v) => renamed(r.body.clone(), v, &col),
            CPat::Wild => r.body.clone(),
            _ => return None,
        };
        let mut pats: Vec<CPat> = r
            .pats
            .iter()
            .enumerate()
            .filter(|(i, _)| *i != j)
            .map(|(_, p)| p.clone())
            .collect();
        pats.extend(std::iter::repeat_n(CPat::Wild, width));
        Some(MRow { pats, body })
    };
    // the arm's binders for a constructor/tuple group whose rows give `subs` (one sub-pattern
    // vector per row that names the constructor; `None` for a catch-all row): a field every row
    // binds with the same variable keeps it (no rename, no new column); one nobody uses is `_`;
    // anything else gets a fresh binder and becomes a new column
    let group = |subs: &[Option<Vec<CPat>>],
                 arity: usize,
                 ctr: &mut u32|
     -> (Vec<CPat>, Vec<usize>, Vec<String>) {
        let mut binders = Vec::new();
        let mut new_cols_at = Vec::new();
        let mut new_cols = Vec::new();
        for i in 0..arity {
            let at_i: Vec<&CPat> = subs.iter().flatten().map(|ps| &ps[i]).collect();
            let names: HashSet<&str> = at_i
                .iter()
                .filter_map(|p| match p {
                    CPat::Var(v) => Some(v.as_str()),
                    _ => None,
                })
                .collect();
            let all_flat = at_i.iter().all(|p| flat_sub(p));
            if all_flat && names.is_empty() {
                binders.push(CPat::Wild);
            } else if let (true, [only]) = (all_flat, names.iter().collect::<Vec<_>>().as_slice()) {
                binders.push(CPat::Var(only.to_string()));
            } else {
                *ctr += 1;
                // rows that bind the same source name (`a`, `a$1` after renaming) keep it for the
                // reports; a fresh `a$N` (renamed again later if it clashes) still reads as `a`
                let bases: HashSet<&str> = names.iter().map(|n| source_name(n)).collect();
                let b = match bases.iter().next() {
                    Some(base) if bases.len() == 1 && source_name(base) == *base => {
                        format!("{base}${}", 1000 + *ctr)
                    }
                    _ => format!("$nf{ctr}"),
                };
                binders.push(CPat::Var(b.clone()));
                new_cols_at.push(i);
                new_cols.push(b);
            }
        }
        (binders, new_cols_at, new_cols)
    };
    let mut arms: Vec<(CPat, Term)> = Vec::new();
    match &first.pats[j] {
        CPat::Con(..) | CPat::Tuple(_) => {
            // the constructors in order of first appearance (a tuple is its one "constructor")
            let mut heads: Vec<(Option<String>, usize)> = Vec::new();
            for r in &rows {
                let h = match &r.pats[j] {
                    CPat::Con(k, ps) => (Some(k.clone()), ps.len()),
                    CPat::Tuple(ps) => (None, ps.len()),
                    _ => continue,
                };
                if !heads.iter().any(|(k, _)| *k == h.0) {
                    heads.push(h);
                }
            }
            for (k, arity) in heads {
                // a catch-all row of this group reads the matched value whole (its variable, the
                // original scrutinee or a column) after the arm took it apart: `compile_case`
                // then matches row by row instead (`sequential`)
                let mut watched: HashSet<String> = cols.iter().cloned().collect();
                watched.insert(top.to_string());
                let view = rows.iter().any(|r| match &r.pats[j] {
                    CPat::Var(v) => {
                        let mut w = watched.clone();
                        w.insert(v.clone());
                        term_mentions_any(&r.body, &w)
                    }
                    CPat::Wild => term_mentions_any(&r.body, &watched),
                    _ => false,
                });
                if view {
                    *viewed = true;
                }
                let subs: Vec<Option<Vec<CPat>>> = rows
                    .iter()
                    .filter_map(|r| match (&r.pats[j], &k) {
                        (CPat::Con(c, ps), Some(k)) if c == k => Some(Some(ps.clone())),
                        (CPat::Tuple(ps), None) => Some(Some(ps.clone())),
                        (CPat::Var(_) | CPat::Wild, _) => Some(None),
                        _ => None,
                    })
                    .collect();
                let (binders, at, new_cols) = group(&subs, arity, ctr);
                let mut grows = Vec::new();
                for r in &rows {
                    let ps = match (&r.pats[j], &k) {
                        (CPat::Con(c, ps), Some(k)) if c == k => ps,
                        (CPat::Tuple(ps), None) => ps,
                        (CPat::Var(_) | CPat::Wild, _) => {
                            grows.extend(catch_all(r, at.len()));
                            continue;
                        }
                        _ => continue,
                    };
                    // a field kept as the group's shared variable needs no rename; a variable at
                    // a fresh-binder field is renamed when its column is matched
                    let body = r.body.clone();
                    let mut pats: Vec<CPat> = r
                        .pats
                        .iter()
                        .enumerate()
                        .filter(|(i, _)| *i != j)
                        .map(|(_, p)| p.clone())
                        .collect();
                    for &i in &at {
                        pats.push(ps[i].clone());
                    }
                    grows.push(MRow { pats, body });
                }
                let pat = match &k {
                    Some(k) => CPat::Con(k.clone(), binders),
                    None => CPat::Tuple(binders),
                };
                arms.push((
                    pat,
                    compile_matrix(top, rest_cols(&new_cols), grows, sp, ctr, viewed),
                ));
            }
        }
        CPat::Int(_) => {
            let mut lits: Vec<i64> = Vec::new();
            for r in &rows {
                if let CPat::Int(n) = r.pats[j] {
                    if !lits.contains(&n) {
                        lits.push(n);
                    }
                }
            }
            for n in lits {
                let mut grows = Vec::new();
                for r in &rows {
                    match &r.pats[j] {
                        CPat::Int(m) if *m == n => {
                            let mut pats = r.pats.clone();
                            pats[j] = CPat::Wild;
                            let lit = MRow {
                                pats,
                                body: r.body.clone(),
                            };
                            grows.extend(catch_all(&lit, 0));
                        }
                        CPat::Var(_) | CPat::Wild => grows.extend(catch_all(r, 0)),
                        _ => {}
                    }
                }
                arms.push((
                    CPat::Int(n),
                    compile_matrix(top, rest_cols(&[]), grows, sp, ctr, viewed),
                ));
            }
        }
        CPat::Var(_) | CPat::Wild => unreachable!("column j is refutable"),
    }
    // the default arm: the rows with a variable or `_` in column j (for a tuple there is none
    // needed: the tuple arm matches everything)
    let tuple = matches!(first.pats[j], CPat::Tuple(_));
    let defaults: Vec<MRow> = rows.iter().filter_map(|r| catch_all(r, 0)).collect();
    if !tuple && !defaults.is_empty() {
        arms.push((
            CPat::Wild,
            compile_matrix(top, rest_cols(&[]), defaults, sp, ctr, viewed),
        ));
    } else if let Some((p @ CPat::Int(_), _)) = arms.last_mut() {
        // literals with no catch-all row: reached only when one of them matches (a re-match of
        // a row known to match, or exhaustiveness), and the backends need a final catch-all
        *p = CPat::Wild;
    }
    Term::Ret(Rhs::Case(Atom::Var(col), arms), sp)
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
    con_recursive: &HashMap<String, Vec<usize>>,
) -> BorrowArgs {
    let mut ba: BorrowArgs = HashMap::new();
    // the generated array helpers (not in `fns` yet: emitted after drop insertion) have fixed
    // ownership; the fixpoint below only revisits real functions, so these entries stay.
    for f in fns {
        for_each_op(&f.body, &mut |op| {
            if let Op::CallDirect(g, _, _) = op {
                if let Some(set) = arrop_borrows(g) {
                    ba.insert(g.clone(), set);
                }
            }
        });
    }
    for f in fns {
        let Some(mults) = param_mults.get(&f.name) else {
            continue;
        };
        // A param that is destructured and whose recursive (spine) field escapes via a
        // constructor is a VIEW — its result ALIASES the argument, so it must be MOVED,
        // not borrowed (else caller-drop + result-drop double-free). Auto-detected for
        // ANY function; see `destructures_and_embeds_recursive` and the view-soundness docs.
        let set: HashSet<usize> = (0..f.params.len())
            .filter(|&i| {
                mults.get(i) != Some(&ast::Mult::One)
                    && !destructures_and_embeds_recursive(&f.params[i], &f.body, con_recursive)
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
        // a generated `axion_copy_T` deep-copier (R-5) BORROWS every arg (it reads the
        // value to clone it, frees nothing) — so a param handed to it stays owned by the
        // caller and is NOT consumed here (matches delta::op_delta_effect).
        Op::CallDirect(g, _, _) if g.starts_with("axion_copy_") => false,
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
        // get/len/sum BORROW the resource (arg 0), same as the array read ops — a
        // read-only traversal does not consume it.
        Op::RtCall { func, args, .. }
            if func == "axion_tritvec_get"
                || func == "axion_tritvec_len"
                || func == "axion_i8_get"
                || func == "axion_i8_len"
                || func == "axion_i8_sum"
                || func == "axion_array_sum"
                || func == "axion_i32_get"
                || func == "axion_i32_len"
                || func == "axion_i32_sum"
                // tritVecFromBuffer READS the buffer (arg 0); produces a fresh TritVec.
                || func == "axion_tritvec_from_buffer" =>
        {
            args.iter()
                .enumerate()
                .any(|(i, a)| i != 0 && atom_is(v, a))
        }
        // Dot/matvec readers READ both operands and return a scalar — neither is
        // moved, like the String read builtins; the caller reclaims both.
        Op::RtCall { func, .. }
            if func == "axion_tritvec_dot"
                || func == "axion_tritvec_matvec_sum"
                || func == "axion_i8_matvec_sum"
                || func == "axion_i8_dot"
                || func == "axion_i8_dot_i8"
                || func == "axion_array_dot"
                || func == "axion_i32_dot"
                || func == "axion_i32_matvec_sum" =>
        {
            false
        }
        // String builtins + §pass capability primitives READ their operands and return
        // a fresh String or scalar — the operand stays owned by the caller (matches
        // delta::op_delta_effect, §tc), so a read-only String arg is a borrow-arg the
        // caller reclaims. Keeps `op_moves` in sync with the borrow effect.
        Op::RtCall { func, .. } if is_string_producer(func) || is_scalar_reader(func) => false,
        // Integer arithmetic/comparison READS its operands (borrows) and returns a
        // fresh Integer/Bool — the operands stay owned by the caller (matches
        // `delta::op_delta_effect`), so a read-only Integer param is a borrow-arg the
        // caller reclaims. Keeps `op_moves` in sync with the bignum borrow effect.
        Op::RtCall { func, .. } if is_bignum_borrower(func) => false,
        // copying a closure cell only reads it (the built-in table says `Borrow`)
        Op::RtCall { func, .. } if func == "axion_closure_copy" => false,
        // --- the rest mirrors `occurs_nonborrow`'s `op_nonborrow` exactly ---
        Op::Field { .. }
        | Op::FuncAddr(_)
        | Op::LoadRaw(..)
        | Op::ArrayNew { .. }
        | Op::Unsupported(_) => false,
        // putStr/putStrLn (axion_put/axion_puts) only PRINT their String arg — they never
        // free it (matches `delta::op_delta_effect` and the runtime). Treating them as a move
        // desynced `compute_borrow_args` (this fn) from `insert_drops` (delta): a param passed
        // only to putStrLn was judged consumed here → the caller relinquished it, yet the callee
        // (seeing a borrow) never dropped it → a leak on every guarded/`if` body that prints a
        // param (`pass`'s `doLs sub`). A borrow: the owner reclaims it.
        Op::PutStrLn(_) | Op::PutStr(_) => false,
        Op::Atom(a)
        | Op::IntToFloat(a)
        | Op::FloatToInt(a)
        | Op::FloatUnary(_, a)
        | Op::ShowInt(a)
        | Op::ArenaAlloc(a)
        | Op::ArenaMark(a)
        | Op::ArenaRelease(a) => atom_is(v, a),
        // `Prim`/`PrimF` (arithmetic/comparison) READ their operands and return a fresh
        // scalar — they BORROW, matching `delta::op_delta_effect`. Treating them as a MOVE
        // (the old behavior) made any `f x = x <op> …` drop `x` from its borrow set, so a
        // caller passing an OWNED value that is then reused (a `%1` list element used by a
        // predicate AND embedded in the output) was flagged as a double-move by the verifier.
        Op::Prim(_, _, _) | Op::PrimF(_, _, _) => false,
        Op::StoreRaw(a, _, b) | Op::Promote(a, b) => atom_is(v, a) || atom_is(v, b),
        // as `delta::op_delta_effect` reads them: a closure that does not own its captures
        // BORROWS them; an FFI argument is moved only if declared `Own`; a runtime call follows
        // the built-in ownership table. (Reading these as moves made the caller hand over a
        // value the callee only read — and nobody freed it: a leak the verifier exempted.)
        Op::MakeClosure { owns: false, .. } => false,
        Op::Ffi {
            args, arg_kinds, ..
        } => args
            .iter()
            .enumerate()
            .any(|(i, a)| atom_is(v, a) && arg_kinds.get(i).is_some_and(|k| k.own)),
        Op::RtCall { func, args, .. } => {
            crate::builtins::rt_entry(func)
                .is_none_or(|r| r.args != crate::builtins::ArgOwn::Borrow)
                && args.iter().any(|a| atom_is(v, a))
        }
        Op::CallClosure(_, xs)
        | Op::MakeTuple(xs)
        | Op::MakeCon { args: xs, .. }
        | Op::MakeClosure { captures: xs, .. } => xs.iter().any(|a| atom_is(v, a)),
        Op::MakeRecord { fields, .. } => fields.iter().any(|(_, a)| atom_is(v, a)),
        Op::UpdateRecord {
            base,
            fields,
            inplace,
            ..
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
            for (p, b) in arms {
                // a pattern's binders are bound in its arm. Binder names are unique only along a
                // scope path, not across sibling `case`s: without this, a droppable `v` of one
                // `case` looked free in another `case` binding its own `v`, whose arm balancing
                // then dropped a `v` that arm never bound.
                let mut binders = Vec::new();
                cpat_binders(p, &mut binders);
                let fresh: Vec<String> = binders
                    .into_iter()
                    .filter(|n| bound.insert(n.clone()))
                    .collect();
                fv_drop_in(b, drp, ba, bound, out);
                for n in fresh {
                    bound.remove(&n);
                }
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
    // An alias operand (`let h = g`) is a use too: never of a droppable (aliasing one marks
    // it escaped), but of a BORROWER (`Elab::fv_op` widens `drp` with them) — the rename
    // reads the same owners, so they must outlive it.
    let e = crate::delta::op_delta_effect(op, ba);
    for a in e
        .borrows
        .iter()
        .chain(e.nonstrict.iter())
        .chain(e.alias.iter())
    {
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
    // A closure that ESCAPES (returned, stored, handed to a callee that keeps it) carries
    // pointers to its captures out of this frame, so none of them may be freed here: they
    // escape with it (and so does anything they in turn capture or alias).
    // A rename `let h = g` marks `g` escaped, but when `h` takes over the allocation (R-4) the
    // value has not left the frame: only `h`'s own escape carries the captures out (the
    // rename edge `h → g` in `closure_deps`).
    let deps = closure_deps(&f.body);
    let transferred = renamed_into_owner(&f.body, &allocated);
    let mut work: Vec<String> = escaped
        .iter()
        .filter(|v| !transferred.contains(*v))
        .cloned()
        .collect();
    work.push(RET_CLOSURE.to_string()); // a closure built in `ret` position escapes
    let mut seen: HashSet<String> = work.iter().cloned().collect();
    while let Some(v) = work.pop() {
        for c in deps.get(&v).into_iter().flatten() {
            escaped.insert(c.clone());
            if seen.insert(c.clone()) {
                work.push(c.clone());
            }
        }
    }
    allocated.difference(&escaped).cloned().collect()
}

/// Sources of a rename `let x = src` whose target `x` takes over the allocation (R-4).
fn renamed_into_owner(t: &Term, allocated: &HashSet<String>) -> HashSet<String> {
    fn walk(t: &Term, allocated: &HashSet<String>, out: &mut HashSet<String>) {
        match t {
            Term::Let(x, rhs, _, body) => {
                match rhs {
                    Rhs::Op(Op::Atom(Atom::Var(src))) if allocated.contains(x) => {
                        out.insert(src.clone());
                    }
                    Rhs::Op(_) => {}
                    Rhs::If(_, a, b) => {
                        walk(a, allocated, out);
                        walk(b, allocated, out);
                    }
                    Rhs::Case(_, arms) => arms.iter().for_each(|(_, b)| walk(b, allocated, out)),
                }
                walk(body, allocated, out);
            }
            Term::Drop(_, _, _, _, body) => walk(body, allocated, out),
            Term::Ret(rhs, _) => match rhs {
                Rhs::Op(_) => {}
                Rhs::If(_, a, b) => {
                    walk(a, allocated, out);
                    walk(b, allocated, out);
                }
                Rhs::Case(_, arms) => arms.iter().for_each(|(_, b)| walk(b, allocated, out)),
            },
        }
    }
    let mut out = HashSet::new();
    walk(t, allocated, &mut out);
    out
}

/// The `closure_deps` key of the closures a function builds directly in `ret` position.
const RET_CLOSURE: &str = "$ret-closure";

/// Closure binder → the variables it holds pointers to: its captures, and for a rename
/// `let y = x` of such a binder, `x` (whose captures follow transitively). Closures built in
/// `ret` position are collected under `RET_CLOSURE`.
fn closure_deps(t: &Term) -> HashMap<String, Vec<String>> {
    fn walk(t: &Term, out: &mut HashMap<String, Vec<String>>) {
        match t {
            Term::Let(x, rhs, _, body) => {
                match rhs {
                    // an owning closure moved its (copied) captures in: nothing to keep alive
                    Rhs::Op(Op::MakeClosure { owns: true, .. }) => {}
                    Rhs::Op(Op::MakeClosure { captures, .. }) => {
                        let cs = captures
                            .iter()
                            .filter_map(|a| match a {
                                Atom::Var(v) => Some(v.clone()),
                                _ => None,
                            })
                            .collect();
                        out.insert(x.clone(), cs);
                    }
                    Rhs::Op(Op::Atom(Atom::Var(y))) => {
                        out.entry(x.clone()).or_default().push(y.clone());
                    }
                    Rhs::Op(_) => {}
                    Rhs::If(_, a, b) => {
                        walk(a, out);
                        walk(b, out);
                    }
                    Rhs::Case(_, arms) => arms.iter().for_each(|(_, b)| walk(b, out)),
                }
                walk(body, out);
            }
            Term::Drop(_, _, _, _, body) => walk(body, out),
            Term::Ret(rhs, _) => match rhs {
                Rhs::Op(Op::MakeClosure { owns: true, .. }) => {}
                Rhs::Op(Op::MakeClosure { captures, .. }) => {
                    out.entry(RET_CLOSURE.to_string()).or_default().extend(
                        captures.iter().filter_map(|a| match a {
                            Atom::Var(v) => Some(v.clone()),
                            _ => None,
                        }),
                    );
                }
                Rhs::Op(_) => {}
                Rhs::If(_, a, b) => {
                    walk(a, out);
                    walk(b, out);
                }
                Rhs::Case(_, arms) => arms.iter().for_each(|(_, b)| walk(b, out)),
            },
        }
    }
    let mut out = HashMap::new();
    walk(t, &mut out);
    out
}

// --- ExtractOp tags (docs/safety-model-spike.md, Option B, Step 1) -------------------------
//
// The explicit Ownership-IR move toward a verifier that CHECKS an ownership decision instead of
// RE-DERIVING it. This first slice is READ-ONLY: it classifies every heap-field `case`-extraction
// by the intra-procedural container-liveness rule and reports the tags (via `--emit extract-tags`),
// so we can measure, on the real corpus, how many sites the intra rule can tag confidently vs. how
// many hinge on a callee's consume/borrow behaviour (the interprocedural summary, Step 3). It does
// NOT gate and does NOT change lowering. Scoped to `Con` (record/`data`) heap fields — the live
// frontier (grab-via-case, Integer-in-data); tuple scrutinees are the immediate follow-up.

/// How a heap field leaves (or does not leave) its container at a `case`-extraction site.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ExtractOp {
    /// Ownership transfers out of a DYING (owned) container; its destructor must SKIP the slot.
    MoveOut,
    /// An interior alias of a LIVE container; the container still owns it and frees it once.
    BorrowRef,
    /// The value escapes a surviving container, so it needs a fresh owned duplicate.
    ExplicitCopy,
}

impl ExtractOp {
    pub fn as_str(self) -> &'static str {
        match self {
            ExtractOp::MoveOut => "MoveOut",
            ExtractOp::BorrowRef => "BorrowRef",
            ExtractOp::ExplicitCopy => "ExplicitCopy",
        }
    }
}

/// One classified heap-field extraction. `interproc` marks a tag whose soundness hinges on whether
/// the callee the field escapes INTO consumes or borrows it — i.e. the intra-procedural rule had to
/// guess and the real decision needs the Step-3 per-function summary.
#[derive(Debug, Clone)]
pub struct ExtractFact {
    pub func: String,
    pub con: String,
    pub scrut: String,
    pub field: String,
    pub slot: usize,
    pub tag: ExtractOp,
    pub interproc: bool,
    /// the field IS the whole result of its function on this path (a grab) — so a `BorrowRef`
    /// here means the function returns a borrow of the scrutinee (the tag-based borrow-return).
    pub bare: bool,
    /// (meaningful when `interproc`) every call the field escapes into is a `CallDirect` to a known
    /// user function, so the existing `BorrowArgs` already decides borrow-vs-consume — the deep
    /// lever can resolve this site by WIRING an existing fact, no new analysis. `false` ⇒ it escapes
    /// into a closure/builtin and genuinely needs more.
    pub ba_resolvable: bool,
}

/// Classify every `Con` heap-field extraction in the lowered module by the intra-procedural
/// container-liveness rule (read-only; see the section header). `module` supplies the constructors'
/// declared field TYPES, so heap-ness is judged by TYPE rather than by `con_drop_slots` (which
/// once excluded `Integer` and would have blinded the analysis exactly where a bug lived).
pub fn classify_extractions(
    fns: &[CoreFn],
    module: &ast::Module,
    recinfo: &RecordInfo,
    ba: &BorrowArgs,
    param_keys: &HashMap<String, Vec<Option<String>>>,
) -> Vec<ExtractFact> {
    // con → declared field types, for a type-based heap test independent of drop_slots.
    let field_tys: HashMap<String, Vec<Type>> = module
        .datas
        .iter()
        .flat_map(|d| {
            d.cons.iter().map(|c| {
                (
                    c.name.clone(),
                    c.fields.iter().map(|f| f.ty.clone()).collect(),
                )
            })
        })
        .collect();
    // user function names, for the deep-lever interprocedural-resolvability measurement: a
    // CallDirect to one of these has a `ba` borrow/consume verdict; a builtin/closure does not.
    let fn_names: HashSet<String> = fns.iter().map(|f| f.name.clone()).collect();
    let mut out = Vec::new();
    for f in fns {
        // generated destructors/copiers manage memory by hand — not Auto-Drop extractions.
        if f.name.starts_with("axion_") {
            continue;
        }
        // a scrutinee is OWNED by this fn iff this fn reclaims it (a `%1` param, a droppable local
        // producer, OR — the fix the Phase-A tag-lower-check surfaced — a param DROPPED anywhere in
        // the body). Mirrors `verify.rs::run_fn`'s owned set: dropping proves ownership. Without the
        // dropped-param clause a specialized/lifted consumer (`map$$getV xs = case xs of Cons y ys
        // -> drop xs; …`) whose list param is not in `owned_params` looked BORROWED, so its moved-out
        // element `y` was mis-tagged `BorrowRef` while the lowering (correctly) owns-and-drops it.
        let mut owned: HashSet<String> = f.owned_params.iter().cloned().collect();
        owned.extend(droppable_vars(f, ba));
        // "dropping proves ownership" for ANY var, not just params — a case-binder that is dropped
        // (`case res of (st,i) -> … drop st; case st of St store sub …`) is owned, so the fields it
        // yields moved out of it. (Params-only missed nested extractions like typecheck's `typeOf`.)
        collect_dropped_vars(&f.body, &mut owned);
        // param name → its mono reclaim key (tuple scrutinee element types are recovered from this
        // via `tuple_elem_drops` — available now that tuple keys encode arity).
        let pkey: HashMap<String, String> = param_keys
            .get(&f.name)
            .map(|ks| {
                f.params
                    .iter()
                    .zip(ks)
                    .filter_map(|(p, k)| k.clone().map(|k| (p.clone(), k)))
                    .collect()
            })
            .unwrap_or_default();
        extract_walk(
            &f.body, &f.name, &field_tys, &pkey, &fn_names, recinfo, ba, &owned, &mut out,
        );
    }
    out
}

/// A field's declared type needs heap reclamation — `Integer`/`String`/`data`/`List`/tuple/poly,
/// but not `Int`/`Float`/`Bool`/`Char`/`Buffer`/function or an unboxed enum. Type-based so it is
/// NOT gated on `con_drop_slots`.
fn field_ty_heap(ty: &Type, recinfo: &RecordInfo) -> bool {
    match ty {
        Type::Var(_) => true,   // polymorphic — may instantiate to heap
        Type::Tuple(_) => true, // heap cell
        _ => match ty.head_con() {
            Some("Int" | "Float" | "Bool" | "Char" | "Buffer") => false,
            Some(h) if recinfo.is_enum_type(h) => false, // unboxed immediate
            Some(_) => true,
            None => false, // function / unknown
        },
    }
}

#[allow(clippy::too_many_arguments)]
fn extract_walk(
    t: &Term,
    func: &str,
    field_tys: &HashMap<String, Vec<Type>>,
    pkey: &HashMap<String, String>,
    fn_names: &HashSet<String>,
    recinfo: &RecordInfo,
    ba: &BorrowArgs,
    owned: &HashSet<String>,
    out: &mut Vec<ExtractFact>,
) {
    match t {
        Term::Let(_, rhs, _, body) => {
            extract_rhs(
                rhs, func, field_tys, pkey, fn_names, recinfo, ba, owned, out,
            );
            extract_walk(
                body, func, field_tys, pkey, fn_names, recinfo, ba, owned, out,
            );
        }
        Term::Drop(_, _, _, _, body) => extract_walk(
            body, func, field_tys, pkey, fn_names, recinfo, ba, owned, out,
        ),
        Term::Ret(rhs, _) => extract_rhs(
            rhs, func, field_tys, pkey, fn_names, recinfo, ba, owned, out,
        ),
    }
}

/// Emit one `ExtractFact` for a mentioned heap field binder `n` at `slot` of `con`/tuple scrutinee
/// `s`, applying the intra-procedural container-liveness tag rule. Shared by the `Con` and `Tuple`
/// arms so both use identical logic.
#[allow(clippy::too_many_arguments)]
fn push_extract_fact(
    func: &str,
    con: &str,
    scrut: &str,
    n: &str,
    slot: usize,
    owned_scrut: bool,
    body: &Term,
    fn_names: &HashSet<String>,
    ba: &BorrowArgs,
    out: &mut Vec<ExtractFact>,
) {
    if !term_mentions_any(body, &HashSet::from([n.to_string()])) {
        return; // dead discard → reclaimed by the destructor, not an extract-and-use
    }
    let escapes = body_moves_var(n, body, ba);
    // The WHOLE result IS the field (grab) vs the field EMBEDDED into a new structure / handed to a
    // consuming call. A grab out of a borrowed container is a borrow-return, not a copy.
    let bare = returns_var_bare(n, body);
    let embedded = embedded_in_builder(n, body);
    // Deep lever (Step 3): consult the existing BorrowArgs for calls the field escapes into.
    let call = escape_call_verdict(n, body, fn_names, ba);
    // Container-liveness rule (Option B). OWNED scrutinee FIRST, but only when the field is genuinely
    // MOVED OUT: a consumed container dies here, so a field that escapes (`body_moves_var`) OR is
    // reclaimed locally by its OWN drop (`body_drops_var` — e.g. `map$$getV`'s `y`, borrowed by `getV`
    // then `drop y`, so `escapes` is false yet it is owned since the list was shell-freed) is now this
    // fn's to own → `MoveOut`, and the container's drop skips its slot. A field of an owned container
    // that is merely READ (`useTuple`'s `a`/`b` via the `v` getter) is NOT moved out — the container's
    // deep drop frees it — so it falls through to `BorrowRef`. Both halves are what the MoveOut and
    // BorrowRef tag-lower-checks verify against the lowering's skip-set.
    // A field of a LIVE (borrowed) container stays a `BorrowRef` — the caller's container still owns
    // it, its owner frees it once — in three shapes: (a) `!escapes`, a read-only alias; (b) a bare
    // non-embedded grab, the caller's container owns the grabbed field; (c) it escapes ONLY into
    // callees that borrow its position (`ba`-wired, replacing the old blanket `ExplicitCopy`).
    // Otherwise it escapes a SURVIVING container (consumed / embedded / unresolvable) → `ExplicitCopy`.
    let tag = if owned_scrut && (escapes || body_drops_var(n, body)) {
        ExtractOp::MoveOut
    } else if !escapes || (!embedded && (bare || call == EscapeCall::AllBorrow)) {
        ExtractOp::BorrowRef
    } else {
        ExtractOp::ExplicitCopy
    };
    // "hinges on a callee" = escapes into some call; `ba_resolvable` = that hinge is decided by the
    // existing BorrowArgs (AllBorrow/HasConsume), vs a closure/builtin that genuinely needs more.
    let interproc = escapes && call != EscapeCall::None;
    let ba_resolvable = matches!(call, EscapeCall::AllBorrow | EscapeCall::HasConsume);
    out.push(ExtractFact {
        func: func.to_string(),
        con: con.to_string(),
        scrut: scrut.to_string(),
        field: n.to_string(),
        slot,
        tag,
        interproc,
        bare,
        ba_resolvable,
    });
}

#[allow(clippy::too_many_arguments)]
fn extract_rhs(
    rhs: &Rhs,
    func: &str,
    field_tys: &HashMap<String, Vec<Type>>,
    pkey: &HashMap<String, String>,
    fn_names: &HashSet<String>,
    recinfo: &RecordInfo,
    ba: &BorrowArgs,
    owned: &HashSet<String>,
    out: &mut Vec<ExtractFact>,
) {
    match rhs {
        Rhs::Op(_) => {}
        Rhs::If(_, a, b) => {
            extract_walk(a, func, field_tys, pkey, fn_names, recinfo, ba, owned, out);
            extract_walk(b, func, field_tys, pkey, fn_names, recinfo, ba, owned, out);
        }
        Rhs::Case(scrut, arms) => {
            if let Atom::Var(s) = scrut {
                let owned_scrut = owned.contains(s);
                for (pat, body) in arms {
                    match pat {
                        CPat::Con(con, subs) => {
                            let tys = field_tys.get(con);
                            for (i, sub) in subs.iter().enumerate() {
                                if let CPat::Var(n) = sub {
                                    let is_heap = tys.and_then(|t| t.get(i)).is_some_and(|ty| {
                                        // A POLYMORPHIC field (`Cons`'s `a`) is heap-or-not only
                                        // once instantiated: resolve it through the scrutinee's mono
                                        // key (`List$Int` → `Int`, scalar → not heap; `List$Integer`
                                        // → `Integer`, heap). Unkeyed scrutinee ⇒ stay conservative
                                        // (`Var → true`); a concrete field type ⇒ decide directly.
                                        if matches!(ty, Type::Var(_)) {
                                            match pkey.get(s) {
                                                Some(k) => {
                                                    recinfo.poly_field_elem_key(con, i, k).is_some()
                                                }
                                                None => true,
                                            }
                                        } else {
                                            field_ty_heap(ty, recinfo)
                                        }
                                    });
                                    if is_heap {
                                        push_extract_fact(
                                            func,
                                            con,
                                            s,
                                            n,
                                            i,
                                            owned_scrut,
                                            body,
                                            fn_names,
                                            ba,
                                            out,
                                        );
                                    }
                                }
                            }
                        }
                        CPat::Tuple(subs) => {
                            // Element heap-ness from the scrutinee's mono key (recoverable for a
                            // param; arity-encoded tuple keys segment unambiguously). A non-param
                            // or unkeyed tuple scrutinee stays untagged for now (follow-up: thread
                            // local tuple keys) — honest under-coverage, never a wrong tag.
                            let elem_heap: Option<Vec<bool>> = pkey.get(s).and_then(|k| {
                                recinfo
                                    .tuple_elem_drops(k, subs.len())
                                    .map(|ds| ds.iter().map(Option::is_some).collect())
                            });
                            for (i, sub) in subs.iter().enumerate() {
                                if let CPat::Var(n) = sub {
                                    let is_heap = elem_heap
                                        .as_ref()
                                        .and_then(|v| v.get(i))
                                        .copied()
                                        .unwrap_or(false);
                                    if is_heap {
                                        let con = format!("tuple{}", subs.len());
                                        push_extract_fact(
                                            func,
                                            &con,
                                            s,
                                            n,
                                            i,
                                            owned_scrut,
                                            body,
                                            fn_names,
                                            ba,
                                            out,
                                        );
                                    }
                                }
                            }
                        }
                        _ => {}
                    }
                    // nested extractions inside the arm
                    extract_walk(
                        body, func, field_tys, pkey, fn_names, recinfo, ba, owned, out,
                    );
                }
            }
        }
    }
}

/// `true` if `v` is, on some path, the WHOLE result of `t` (a bare `ret v`) — the grab shape.
fn returns_var_bare(v: &str, t: &Term) -> bool {
    match t {
        Term::Ret(Rhs::Op(Op::Atom(Atom::Var(x))), _) => x == v,
        Term::Ret(Rhs::Op(_), _) => false,
        Term::Ret(Rhs::If(_, a, b), _) => returns_var_bare(v, a) || returns_var_bare(v, b),
        Term::Ret(Rhs::Case(_, arms), _) => arms.iter().any(|(_, a)| returns_var_bare(v, a)),
        Term::Let(_, _, _, b) | Term::Drop(_, _, _, _, b) => returns_var_bare(v, b),
    }
}

/// `true` if `v` is embedded into a freshly built structure (`MakeCon`/`MakeTuple`/`MakeRecord`)
/// anywhere in `t` — a genuine escape into a value that can outlive the container.
fn embedded_in_builder(v: &str, t: &Term) -> bool {
    fn op_has(v: &str, op: &Op) -> bool {
        let hit = |a: &Atom| matches!(a, Atom::Var(x) if x == v);
        match op {
            Op::MakeTuple(args) | Op::MakeCon { args, .. } => args.iter().any(hit),
            Op::MakeRecord { fields, .. } => fields.iter().any(|(_, a)| hit(a)),
            _ => false,
        }
    }
    fn rhs_has(v: &str, rhs: &Rhs) -> bool {
        match rhs {
            Rhs::Op(op) => op_has(v, op),
            Rhs::If(_, a, b) => embedded_in_builder(v, a) || embedded_in_builder(v, b),
            Rhs::Case(_, arms) => arms.iter().any(|(_, a)| embedded_in_builder(v, a)),
        }
    }
    match t {
        Term::Let(_, rhs, _, body) => rhs_has(v, rhs) || embedded_in_builder(v, body),
        Term::Drop(_, _, _, _, body) => embedded_in_builder(v, body),
        Term::Ret(rhs, _) => rhs_has(v, rhs),
    }
}

// --- Step 2: the tag-checker (docs/safety-model-spike.md) ---------------------------------
//
// A SECOND OPINION that validates the ExtractOp tags against linear scope, independent of how they
// were chosen. Non-gating (Step 3 flips it to the sole authority). The one check it realizes now:
// a value the tags prove is a BORROW (a call to a function that bare-returns a `BorrowRef` of a
// parameter) must not be DROPPED as owned — doing so double-frees against the container's owner.
// Because the borrow-return summary is sourced from the TYPE-based tags, it sees `Integer` fields
// the drop_slots-gated interior-alias summary misses → it is strictly STRONGER than AX0910 today
// (it rejects the Integer grab-via-case reuse the current verifier reports clean).

/// A tag-check violation: the field `callee` bare-returns as a borrow of `scrut` is extracted and
/// DROPPED more than once from the SAME `scrut` — the same heap cell freed twice (a double-free the
/// drop_slots-gated verifier is blind to over `Integer`). A SINGLE extract-and-drop is sound under
/// the current extractor-ownership model (the field is freed exactly once), so only the repeat is
/// flagged — which is precisely why it is 0-false-positive on the ASan-clean corpus.
#[derive(Debug, Clone)]
pub struct TagViolation {
    pub func: String,
    pub scrut: String,
    pub callee: String,
    pub count: usize,
    /// the span of one of the offending drops, for the diagnostic anchor.
    pub span: Span,
}

/// `f -> {param indices whose field f bare-returns as a BorrowRef}`, from the ExtractOp tags.
fn tag_borrow_returns(fns: &[CoreFn], facts: &[ExtractFact]) -> HashMap<String, HashSet<usize>> {
    let param_idx: HashMap<&str, HashMap<&str, usize>> = fns
        .iter()
        .map(|f| {
            (
                f.name.as_str(),
                f.params
                    .iter()
                    .enumerate()
                    .map(|(i, p)| (p.as_str(), i))
                    .collect(),
            )
        })
        .collect();
    let mut out: HashMap<String, HashSet<usize>> = HashMap::new();
    for ff in facts {
        if ff.tag == ExtractOp::BorrowRef && ff.bare {
            if let Some(idx) = param_idx
                .get(ff.func.as_str())
                .and_then(|m| m.get(ff.scrut.as_str()))
            {
                out.entry(ff.func.clone()).or_default().insert(*idx);
            }
        }
    }
    out
}

/// Step 2 tag-checker (second opinion, NON-gating): every site that DROPS a `BorrowRef`-returning
/// call result. Empty on the ASan-clean corpus (faithful); fires on the Integer grab-via-case reuse
/// (strictly stronger than AX0910). See the section header.
pub fn tag_check(fns: &[CoreFn], facts: &[ExtractFact]) -> Vec<TagViolation> {
    let borrow_ret = tag_borrow_returns(fns, facts);
    let mut out = Vec::new();
    for f in fns {
        if f.name.starts_with("axion_") {
            continue;
        }
        // var → (scrutinee it borrows, callee); then tally DROPS per (scrutinee, callee).
        let mut borrows: HashMap<String, (String, String)> = HashMap::new();
        let mut dropped: HashMap<(String, String), (usize, Span)> = HashMap::new();
        tag_walk(&f.body, &borrow_ret, &mut borrows, &mut dropped);
        for ((scrut, callee), (count, span)) in dropped {
            if count >= 2 {
                out.push(TagViolation {
                    func: f.name.clone(),
                    scrut,
                    callee,
                    count,
                    span,
                });
            }
        }
    }
    out
}

fn tag_walk(
    t: &Term,
    borrow_ret: &HashMap<String, HashSet<usize>>,
    borrows: &mut HashMap<String, (String, String)>,
    dropped: &mut HashMap<(String, String), (usize, Span)>,
) {
    match t {
        Term::Let(x, rhs, _, body) => {
            if let Rhs::Op(Op::CallDirect(g, args, _)) = rhs {
                // the result borrows the arg at the (first) returned-param index.
                if let Some(idx) = borrow_ret.get(g).and_then(|s| s.iter().min().copied()) {
                    if let Some(Atom::Var(scrut)) = args.get(idx) {
                        borrows.insert(x.clone(), (scrut.clone(), g.clone()));
                    }
                }
            }
            match rhs {
                Rhs::If(_, a, b) => {
                    tag_walk(a, borrow_ret, borrows, dropped);
                    tag_walk(b, borrow_ret, borrows, dropped);
                }
                Rhs::Case(_, arms) => {
                    for (_, arm) in arms {
                        tag_walk(arm, borrow_ret, borrows, dropped);
                    }
                }
                Rhs::Op(_) => {}
            }
            tag_walk(body, borrow_ret, borrows, dropped);
        }
        Term::Drop(x, _, _, sp, body) => {
            if let Some(key) = borrows.get(x).cloned() {
                let e = dropped.entry(key).or_insert((0, *sp));
                e.0 += 1;
                e.1 = *sp;
            }
            tag_walk(body, borrow_ret, borrows, dropped);
        }
        Term::Ret(rhs, _) => match rhs {
            Rhs::If(_, a, b) => {
                tag_walk(a, borrow_ret, borrows, dropped);
                tag_walk(b, borrow_ret, borrows, dropped);
            }
            Rhs::Case(_, arms) => {
                for (_, arm) in arms {
                    tag_walk(arm, borrow_ret, borrows, dropped);
                }
            }
            Rhs::Op(_) => {}
        },
    }
}

// --- Phase A: tag-vs-lowering consistency (docs/safety-model-spike.md) -----------------------
//
// Before lowering is rewired to CONSUME the ExtractOp tags, prove the tags are FAITHFUL to what the
// `case_arms` heuristics ALREADY emit — the "build in parallel, prove equal, then flip" migration.
// Read-only, non-gating. First and cleanest invariant: a `BorrowRef` field is an alias of its
// (live) container, so the owner frees it — the lowering must NOT drop the field independently. A
// divergence means either the tag is wrong or the lowering double-frees; both are findings to
// resolve before the flip. (MoveOut/ExplicitCopy consistency are later increments.)

/// A tag the emitted reclamation does not match.
#[derive(Debug, Clone)]
pub struct TagLowerDivergence {
    pub func: String,
    pub field: String,
    pub tag: ExtractOp,
    pub reason: &'static str,
}

/// Collect every var `Drop`ped anywhere in `t` — "dropping proves ownership" (mirrors
/// `verify.rs::run_fn`'s owned set, generalized from params to all binders).
fn collect_dropped_vars(t: &Term, out: &mut HashSet<String>) {
    match t {
        Term::Drop(x, _, _, _, body) => {
            out.insert(x.clone());
            collect_dropped_vars(body, out);
        }
        Term::Let(_, rhs, _, body) => {
            collect_dropped_vars_rhs(rhs, out);
            collect_dropped_vars(body, out);
        }
        Term::Ret(rhs, _) => collect_dropped_vars_rhs(rhs, out),
    }
}
fn collect_dropped_vars_rhs(rhs: &Rhs, out: &mut HashSet<String>) {
    match rhs {
        Rhs::Op(_) => {}
        Rhs::If(_, a, b) => {
            collect_dropped_vars(a, out);
            collect_dropped_vars(b, out);
        }
        Rhs::Case(_, arms) => {
            for (_, a) in arms {
                collect_dropped_vars(a, out);
            }
        }
    }
}

/// `true` if `t` contains a `Drop(v, …)` of `v`.
fn body_drops_var(v: &str, t: &Term) -> bool {
    match t {
        Term::Drop(x, _, _, _, body) => x == v || body_drops_var(v, body),
        Term::Let(_, rhs, _, body) => rhs_drops_var(v, rhs) || body_drops_var(v, body),
        Term::Ret(rhs, _) => rhs_drops_var(v, rhs),
    }
}
fn rhs_drops_var(v: &str, rhs: &Rhs) -> bool {
    match rhs {
        Rhs::Op(_) => false,
        Rhs::If(_, a, b) => body_drops_var(v, a) || body_drops_var(v, b),
        Rhs::Case(_, arms) => arms.iter().any(|(_, a)| body_drops_var(v, a)),
    }
}

/// `true` if the `con`-arm that binds `field` at `slot` (scrutinee `s`) deep-drops `s` without
/// skipping `slot` — the MoveOut violation, scoped to the extraction's OWN arm. The scrutinee is a
/// live binder in every sibling arm and is reclaimed DIFFERENTLY in each (shell where fields moved
/// out, deep where none did), so a whole-body scan would false-positive on a sibling's deep drop
/// (e.g. `Nil -> drop xs : List$Int`); only the arm that actually extracts the field is relevant.
fn moveout_violation(s: &str, con: &str, field: &str, slot: usize, t: &Term) -> bool {
    match t {
        Term::Drop(_, _, _, _, body) => moveout_violation(s, con, field, slot, body),
        Term::Let(_, rhs, _, body) => {
            moveout_violation_rhs(s, con, field, slot, rhs)
                || moveout_violation(s, con, field, slot, body)
        }
        Term::Ret(rhs, _) => moveout_violation_rhs(s, con, field, slot, rhs),
    }
}
fn moveout_violation_rhs(s: &str, con: &str, field: &str, slot: usize, rhs: &Rhs) -> bool {
    match rhs {
        Rhs::Op(_) => false,
        Rhs::If(_, a, b) => {
            moveout_violation(s, con, field, slot, a) || moveout_violation(s, con, field, slot, b)
        }
        Rhs::Case(scrut, arms) => arms.iter().any(|(pat, body)| {
            // The arm that binds `field` at `slot` of `con` on THIS scrutinee: check only its body.
            let binds_field = match pat {
                CPat::Con(c, subs) => {
                    c == con && matches!(subs.get(slot), Some(CPat::Var(n)) if n == field)
                }
                CPat::Tuple(subs) => {
                    con.starts_with("tuple")
                        && matches!(subs.get(slot), Some(CPat::Var(n)) if n == field)
                }
                _ => false,
            };
            let is_extract_arm = matches!(scrut, Atom::Var(v) if v == s) && binds_field;
            if is_extract_arm {
                scrut_deep_drops_unskipped(s, slot, body)
            } else {
                moveout_violation(s, con, field, slot, body)
            }
        }),
    }
}

/// `true` if `t` contains a DEEP `Drop(s, Some(_), skip)` of scrutinee `s` whose destructor does NOT
/// skip `slot` — i.e. the container's drop FREES that field. Contradicts a `MoveOut` tag (the field
/// was supposed to have left the container). A shell free (`key = None`) frees no slots, and a deep
/// drop with `slot ∈ skip` spares it — both consistent, so neither is a violation.
fn scrut_deep_drops_unskipped(s: &str, slot: usize, t: &Term) -> bool {
    match t {
        Term::Drop(x, key, skip, _, body) => {
            (x == s && key.is_some() && !skip.contains(&slot))
                || scrut_deep_drops_unskipped(s, slot, body)
        }
        Term::Let(_, rhs, _, body) => {
            scrut_deep_drops_unskipped_rhs(s, slot, rhs)
                || scrut_deep_drops_unskipped(s, slot, body)
        }
        Term::Ret(rhs, _) => scrut_deep_drops_unskipped_rhs(s, slot, rhs),
    }
}
fn scrut_deep_drops_unskipped_rhs(s: &str, slot: usize, rhs: &Rhs) -> bool {
    match rhs {
        Rhs::Op(_) => false,
        Rhs::If(_, a, b) => {
            scrut_deep_drops_unskipped(s, slot, a) || scrut_deep_drops_unskipped(s, slot, b)
        }
        Rhs::Case(_, arms) => arms
            .iter()
            .any(|(_, a)| scrut_deep_drops_unskipped(s, slot, a)),
    }
}

/// Phase A consistency check: the ExtractOp tags must agree with what the `case_arms` lowering
/// already emits, per invariant. Empty ⇒ the checked tags are faithful — the green light to let the
/// tag DRIVE this decision.
///   · `BorrowRef`: the field must NOT be independently dropped (the container's owner frees it).
///   · `MoveOut`: the container's drop must SHELL-free or SKIP the field's slot (the field left it);
///     a deep drop that frees the slot contradicts the move-out.
/// (`ExplicitCopy` consistency — a copy op is present — is the next increment.)
pub fn tag_lowering_check(fns: &[CoreFn], facts: &[ExtractFact]) -> Vec<TagLowerDivergence> {
    let by_name: HashMap<&str, &CoreFn> = fns.iter().map(|f| (f.name.as_str(), f)).collect();
    let mut out = Vec::new();
    for ff in facts {
        let Some(f) = by_name.get(ff.func.as_str()) else {
            continue;
        };
        match ff.tag {
            ExtractOp::BorrowRef => {
                if body_drops_var(&ff.field, &f.body) {
                    out.push(TagLowerDivergence {
                        func: ff.func.clone(),
                        field: ff.field.clone(),
                        tag: ff.tag,
                        reason: "BorrowRef field is independently dropped by the lowering",
                    });
                }
            }
            ExtractOp::MoveOut => {
                if moveout_violation(&ff.scrut, &ff.con, &ff.field, ff.slot, &f.body) {
                    out.push(TagLowerDivergence {
                        func: ff.func.clone(),
                        field: ff.field.clone(),
                        tag: ff.tag,
                        reason: "MoveOut field's slot is freed by the container's deep drop (not skipped)",
                    });
                }
            }
            ExtractOp::ExplicitCopy => {}
        }
    }
    out
}

/// How a field `v` that escapes into CALLS is treated by those callees, via the existing
/// `BorrowArgs` (docs/safety-model-spike.md, Step 3 — the deep lever is ~96% wiring THIS in):
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum EscapeCall {
    /// `v` never appears in a call arg (it escapes, if at all, via return/embed only).
    None,
    /// every call `v` flows into is a `CallDirect` to a known user fn that BORROWS that position —
    /// so the callee only reads `v`; it stays a borrow of the scrutinee.
    AllBorrow,
    /// resolvable, but at least one callee CONSUMES `v` at its position — a genuine move/copy.
    HasConsume,
    /// `v` flows into a `CallClosure` (opaque) or a builtin (effect in `op_delta_effect`, not `ba`)
    /// — genuinely beyond what `ba` decides.
    Unresolvable,
}

/// Classify how the callees `v` escapes into treat it, consulting `ba`.
fn escape_call_verdict(
    v: &str,
    t: &Term,
    fn_names: &HashSet<String>,
    ba: &BorrowArgs,
) -> EscapeCall {
    // (any call escape seen, any unresolvable target, any consuming position)
    let (mut any, mut unres, mut consume) = (false, false, false);
    fn op(
        v: &str,
        o: &Op,
        fns: &HashSet<String>,
        ba: &BorrowArgs,
        any: &mut bool,
        unres: &mut bool,
        consume: &mut bool,
    ) {
        match o {
            Op::CallDirect(g, args, _) => {
                for (pos, a) in args.iter().enumerate() {
                    if matches!(a, Atom::Var(x) if x == v) {
                        *any = true;
                        if !fns.contains(g) {
                            *unres = true; // builtin / unknown callee — ba has no verdict
                        } else if !ba.get(g).is_some_and(|s| s.contains(&pos)) {
                            *consume = true; // known user fn that does NOT borrow this position
                        }
                    }
                }
            }
            Op::CallClosure(_, args)
                if args.iter().any(|a| matches!(a, Atom::Var(x) if x == v)) =>
            {
                *any = true;
                *unres = true; // opaque closure target
            }
            _ => {}
        }
    }
    fn walk(
        v: &str,
        t: &Term,
        fns: &HashSet<String>,
        ba: &BorrowArgs,
        any: &mut bool,
        unres: &mut bool,
        consume: &mut bool,
    ) {
        let rhs = |r: &Rhs, any: &mut bool, unres: &mut bool, consume: &mut bool| match r {
            Rhs::Op(o) => op(v, o, fns, ba, any, unres, consume),
            Rhs::If(_, a, b) => {
                walk(v, a, fns, ba, any, unres, consume);
                walk(v, b, fns, ba, any, unres, consume);
            }
            Rhs::Case(_, arms) => {
                for (_, arm) in arms {
                    walk(v, arm, fns, ba, any, unres, consume);
                }
            }
        };
        match t {
            Term::Let(_, r, _, body) => {
                rhs(r, any, unres, consume);
                walk(v, body, fns, ba, any, unres, consume);
            }
            Term::Drop(_, _, _, _, body) => walk(v, body, fns, ba, any, unres, consume),
            Term::Ret(r, _) => rhs(r, any, unres, consume),
        }
    }
    walk(v, t, fn_names, ba, &mut any, &mut unres, &mut consume);
    if !any {
        EscapeCall::None
    } else if unres {
        EscapeCall::Unresolvable
    } else if consume {
        EscapeCall::HasConsume
    } else {
        EscapeCall::AllBorrow
    }
}

/// Reclaims a conditionally-escaping OWNED heap parameter in a tail-position
/// `case`/`if` — `headOr dflt xs = case xs of Vn -> dflt; Vc y ys -> y`, where the
/// owned default `dflt` is RETURNED in one arm (escapes) but DEAD in another, in
/// which the main reclamation never drops it (its branch-insensitive `escaped`
/// set excludes it on all paths) → leak. For each such param this drops it at the
/// head of every arm/branch where its name is PROVABLY ABSENT (so it is neither
/// consumed nor read there — the drop cannot double-free; worst case is a residual
/// leak). Descends past leading `let`/`drop`, dropping a param from the working set
/// as soon as a binding mentions it (it may be consumed before the case → then we
/// conservatively leave it to leak rather than risk a double free).
/// Branch-sensitive reclamation of conditionally-escaping OWNED params (heap or Integer):
/// a param may be returned/embedded (escape) on ONE control path yet be dead on another.
/// A single liveness walk carrying the still-owned params:
///   · `let x = rhs`: a param the binding MOVES/consumes leaves the owned set (it escapes
///     or is transferred here); a param only BORROWED stays live into the continuation.
///     A pure alias `let x = ownedParam` with the source dead afterwards TRANSFERS
///     ownership to `x` (the multi-clause lowering renames the param to its clause var).
///   · `if`/`case`: recurse per branch/arm (each drops the params dead on its path) —
///     the scrutinee/condition is a scalar/borrow, and the scrutinee + pattern-bound names
///     are excluded. Exactly one branch runs, so a param is freed once per path.
///   · tail `ret op`: drop every carried param the op does NOT mention (dead here); one it
///     MOVES is the result (escapes → keep), one it merely BORROWS would need a post-`ret`
///     drop we don't synthesize (left conservative → a residual leak, never a double free).
/// Only ever ADDS a drop for a param proven dead on that path and never moved past it, so
/// it cannot double-free; `insert_drops` never dropped these (they are excluded from `drp`).
/// The parameters of a (signature-less) `where`-local that are Integer-typed, inferred from
/// usage: a param appearing as an operand of a bignum arithmetic/comparison rtcall (which
/// borrow heap `Integer` operands). Lets `reclaim_cond_escape` reclaim a where-local's owned
/// Integer accumulators — their drop key is uniformly "Integer", so no signature/param-slot
/// alignment is needed (that alignment is exactly why the type-keyed reclaim is guarded to
/// signatured functions: a captured/synthetic param would misalign a `data` destructor key).
fn where_integer_params(f: &CoreFn) -> HashSet<String> {
    let params: HashSet<&str> = f.params.iter().map(String::as_str).collect();
    let mut out = HashSet::new();
    fn go(t: &Term, params: &HashSet<&str>, out: &mut HashSet<String>) {
        match t {
            Term::Let(_, r, _, b) => {
                rhs(r, params, out);
                go(b, params, out);
            }
            Term::Drop(_, _, _, _, b) => go(b, params, out),
            Term::Ret(r, _) => rhs(r, params, out),
        }
    }
    fn rhs(r: &Rhs, params: &HashSet<&str>, out: &mut HashSet<String>) {
        match r {
            Rhs::Op(Op::RtCall { func, args, .. }) if is_bignum_borrower(func) => {
                for a in args {
                    if let Atom::Var(v) = a {
                        if params.contains(v.as_str()) {
                            out.insert(v.clone());
                        }
                    }
                }
            }
            Rhs::Op(_) => {}
            Rhs::If(_, t, e) => {
                go(t, params, out);
                go(e, params, out);
            }
            Rhs::Case(_, arms) => {
                for (_, b) in arms {
                    go(b, params, out);
                }
            }
        }
    }
    go(&f.body, &params, &mut out);
    out
}

/// The concrete drop key of a heap field `fi` of `con` extracted from a scrutinee whose mono
/// key is `scrut_key` — the free-function twin of `Elab::consumed_elem_key`, for
/// `reclaim_cond_escape`. Outer `None` = do NOT reclaim (scalar / unresolvable — poly leak,
/// exempt); `Some(k)` = reclaim with key `k` (`None` inner = flat free, `Some` = keyed).
fn cond_elem_key(
    con: &str,
    fi: usize,
    scrut_key: Option<&str>,
    recinfo: &RecordInfo,
) -> Option<Option<String>> {
    if let Some(k) = recinfo.field_drop_slot(con, fi) {
        return Some(match scrut_key {
            Some(sk) if sk.contains('$') && sk.split('$').next() == Some(k.as_str()) => {
                Some(sk.to_string())
            }
            _ => Some(k),
        });
    }
    // AXION_NAIVE_ELEM_KEY (test hook): the OLD buggy `split_once('$')` that took the whole tail
    // as one element (`Either$Int$Int` → `Int$Int`). Reproduces the multi-param-sum mis-key
    // unsafe Core so the drop-verifier's V-2 scalar-base-key check can be proven to catch it.
    if std::env::var_os("AXION_NAIVE_ELEM_KEY").is_some() {
        let (_, elem) = scrut_key?.split_once('$')?;
        return Some(Some(elem.to_string()));
    }
    // Polymorphic field: resolve the field's own type PARAMETER to the matching argument of the
    // scrutinee's instantiation before classifying — the multi-param-correct path, identical to
    // the `Elab::consumed_elem_key` twin. The old `split_once('$')` took the WHOLE tail as one
    // element (`Either$Int$Int` → `Int$Int`), so `Right`'s scalar `Int` payload was dropped as a
    // bogus `Int$Int` container = a bad free / double-free on the native backends (interp, which
    // reclaims via Rust `Drop`, was unaffected — hence the verifier missed it too).
    recinfo.poly_field_elem_key(con, fi, scrut_key?)
}

/// `true` if `t`'s leading `let`/`drop` spine (NOT descending into `if`/`case` branches)
/// SHELL-frees `scrut` — a `Drop(scrut, None, …)` (no destructor key). A shell free reclaims
/// only the cell and TRANSFERS the fields out (they become owned here); a DEEP drop
/// (`Drop(scrut, Some(k), …)`) instead reclaims the fields transitively, so they must NOT be
/// discovered as owned (that would double-free — `firstOr`'s deep-dropped tail).
fn arm_shell_frees_scrut(scrut: &str, t: &Term) -> bool {
    match t {
        Term::Drop(v, key, _, _, b) => {
            (v == scrut && key.is_none()) || arm_shell_frees_scrut(scrut, b)
        }
        Term::Let(_, _, _, b) => arm_shell_frees_scrut(scrut, b),
        Term::Ret(_, _) => false,
    }
}

/// Classify a function's TAIL returns for alias-return normalization: does it return a
/// target (non-`%1` String) param BARE (`has_param`), and does it ALSO return a fresh/owned
/// value (`has_fresh`)? Only tail positions (real function returns) are inspected — a
/// let-bound `if`/`case` is a value, not a return. See [`normalize_alias_returns`].
/// R-2 (docs/call-site-ownership.md): the per-function set of parameter indices that some
/// CALLER reuses after passing them to a `ret_alias` position — the call-site liveness that
/// decides whether the callee's bare-param return actually needs a copy. For each call
/// `let r = g(… aⱼ …); body` where `j ∈ ret_alias(g)` and `aⱼ` is a var, `aⱼ` is "reused" iff
/// it is mentioned in the continuation `body` (which also catches a rename `let b = aⱼ; … b`,
/// since the binding mentions `aⱼ`) — a sound over-approximation of live-after. A TAIL call
/// (`ret g(…)`) has no continuation, so its args are never reused-after. This is what makes the
/// copy accumulator-safe: a fold combiner's accumulator occurs once in `foldl` (passed to the
/// combiner, result rebound) and is never mentioned after → never copied.
fn reused_after_call(
    fns: &[CoreFn],
    ret_alias: &HashMap<String, HashSet<usize>>,
) -> HashMap<String, HashSet<usize>> {
    let mut reused: HashMap<String, HashSet<usize>> = HashMap::new();
    for f in fns {
        scan_reuse(&f.body, ret_alias, &[], &mut reused);
    }
    reused
}

/// `conts`: what runs after `t` returns — the bodies of the enclosing `let x = if/case …` whose arm
/// `t` is. A call in an arm's TAIL (`let p2 = if c then g p1 else …; … p1 …`) is not a function
/// return: its value flows into the `let`, and `p1` is reused if a continuation mentions it.
fn scan_reuse(
    t: &Term,
    ret_alias: &HashMap<String, HashSet<usize>>,
    conts: &[&Term],
    reused: &mut HashMap<String, HashSet<usize>>,
) {
    let mut note = |g: &String, args: &[Atom], after: &[&Term]| {
        if let Some(ra) = ret_alias.get(g) {
            for &j in ra {
                if let Some(Atom::Var(a)) = args.get(j) {
                    let set = HashSet::from([a.clone()]);
                    if after.iter().any(|c| term_mentions_any(c, &set)) {
                        reused.entry(g.clone()).or_default().insert(j);
                    }
                }
            }
        }
    };
    match t {
        Term::Let(_, Rhs::Op(Op::CallDirect(g, args, _)), _, body) => {
            let mut after: Vec<&Term> = vec![body.as_ref()];
            after.extend_from_slice(conts);
            note(g, args, &after);
            scan_reuse(body, ret_alias, conts, reused);
        }
        Term::Let(_, Rhs::If(_, a, b), _, body) => {
            let mut inner: Vec<&Term> = vec![body.as_ref()];
            inner.extend_from_slice(conts);
            scan_reuse(a, ret_alias, &inner, reused);
            scan_reuse(b, ret_alias, &inner, reused);
            scan_reuse(body, ret_alias, conts, reused);
        }
        Term::Let(_, Rhs::Case(_, arms), _, body) => {
            let mut inner: Vec<&Term> = vec![body.as_ref()];
            inner.extend_from_slice(conts);
            for (_, arm) in arms {
                scan_reuse(arm, ret_alias, &inner, reused);
            }
            scan_reuse(body, ret_alias, conts, reused);
        }
        Term::Let(_, Rhs::Op(_), _, body) | Term::Drop(_, _, _, _, body) => {
            scan_reuse(body, ret_alias, conts, reused);
        }
        Term::Ret(Rhs::If(_, a, b), _) => {
            scan_reuse(a, ret_alias, conts, reused);
            scan_reuse(b, ret_alias, conts, reused);
        }
        Term::Ret(Rhs::Case(_, arms), _) => {
            for (_, arm) in arms {
                scan_reuse(arm, ret_alias, conts, reused);
            }
        }
        // a tail call: reused only if a continuation (an enclosing let-bound arm's) mentions it;
        // a real function return (no continuation) never reuses.
        Term::Ret(Rhs::Op(Op::CallDirect(g, args, _)), _) => note(g, args, conts),
        Term::Ret(Rhs::Op(_), _) => {}
    }
}

/// For each callee, the parameter positions some caller fills with a field bound by a `case` whose
/// scrutinee is used AFTER the `case` (`let n = case v of Cons x _ -> f x in … v …`): the `case`
/// does not consume `v`, so `x` is a borrow of it.
fn live_scrutinee_field_args(fns: &[CoreFn]) -> HashMap<String, HashSet<usize>> {
    fn calls(t: &Term, xs: &HashSet<String>, out: &mut HashMap<String, HashSet<usize>>) {
        let op = |o: &Op, out: &mut HashMap<String, HashSet<usize>>| {
            if let Op::CallDirect(g, args, _) = o {
                for (i, a) in args.iter().enumerate() {
                    if matches!(a, Atom::Var(v) if xs.contains(v)) {
                        out.entry(g.clone()).or_default().insert(i);
                    }
                }
            }
        };
        match t {
            Term::Let(_, rhs, _, b) => {
                match rhs {
                    Rhs::Op(o) => op(o, out),
                    Rhs::If(_, a, c) => {
                        calls(a, xs, out);
                        calls(c, xs, out);
                    }
                    Rhs::Case(_, arms) => arms.iter().for_each(|(_, a)| calls(a, xs, out)),
                }
                calls(b, xs, out);
            }
            Term::Drop(_, _, _, _, b) => calls(b, xs, out),
            Term::Ret(Rhs::Op(o), _) => op(o, out),
            Term::Ret(Rhs::If(_, a, c), _) => {
                calls(a, xs, out);
                calls(c, xs, out);
            }
            Term::Ret(Rhs::Case(_, arms), _) => arms.iter().for_each(|(_, a)| calls(a, xs, out)),
        }
    }
    fn walk(t: &Term, out: &mut HashMap<String, HashSet<usize>>) {
        match t {
            Term::Let(_, rhs, _, b) => {
                if let Rhs::Case(Atom::Var(sv), arms) = rhs {
                    if term_mentions_any(b, &HashSet::from([sv.clone()])) {
                        for (p, a) in arms {
                            let mut bs = Vec::new();
                            cpat_binders(p, &mut bs);
                            calls(a, &bs.into_iter().collect(), out);
                        }
                    }
                }
                match rhs {
                    Rhs::If(_, a, c) => {
                        walk(a, out);
                        walk(c, out);
                    }
                    Rhs::Case(_, arms) => arms.iter().for_each(|(_, a)| walk(a, out)),
                    Rhs::Op(_) => {}
                }
                walk(b, out);
            }
            Term::Drop(_, _, _, _, b) => walk(b, out),
            Term::Ret(Rhs::If(_, a, c), _) => {
                walk(a, out);
                walk(c, out);
            }
            Term::Ret(Rhs::Case(_, arms), _) => arms.iter().for_each(|(_, a)| walk(a, out)),
            Term::Ret(Rhs::Op(_), _) => {}
        }
    }
    let mut out = HashMap::new();
    for f in fns {
        walk(&f.body, &mut out);
    }
    out
}

/// For each callee, the parameter positions some caller fills with one of ITS OWN borrowed
/// parameters, or with a parameter that itself receives a borrowed value (`fed`, not a `%1`
/// one): either way the caller does not own the value it passes.
fn borrowed_param_args(
    fns: &[CoreFn],
    ba: &BorrowArgs,
    fed: &HashMap<String, HashSet<usize>>,
) -> HashMap<String, HashSet<usize>> {
    fn walk(t: &Term, mine: &HashSet<&str>, out: &mut HashMap<String, HashSet<usize>>) {
        let op = |op: &Op, out: &mut HashMap<String, HashSet<usize>>| {
            if let Op::CallDirect(g, args, _) = op {
                for (i, a) in args.iter().enumerate() {
                    if matches!(a, Atom::Var(v) if mine.contains(v.as_str())) {
                        out.entry(g.clone()).or_default().insert(i);
                    }
                }
            }
        };
        match t {
            Term::Let(_, rhs, _, b) => {
                match rhs {
                    Rhs::Op(o) => op(o, out),
                    Rhs::If(_, a, c) => {
                        walk(a, mine, out);
                        walk(c, mine, out);
                    }
                    Rhs::Case(_, arms) => arms.iter().for_each(|(_, a)| walk(a, mine, out)),
                }
                walk(b, mine, out);
            }
            Term::Drop(_, _, _, _, b) => walk(b, mine, out),
            Term::Ret(Rhs::Op(o), _) => op(o, out),
            Term::Ret(Rhs::If(_, a, c), _) => {
                walk(a, mine, out);
                walk(c, mine, out);
            }
            Term::Ret(Rhs::Case(_, arms), _) => arms.iter().for_each(|(_, a)| walk(a, mine, out)),
        }
    }
    let mut out = HashMap::new();
    for f in fns {
        let fed_here = fed
            .get(&f.name)
            .into_iter()
            .flatten()
            .filter(|&&i| f.params.get(i).is_some_and(|p| !f.owned_params.contains(p)));
        let mine: HashSet<&str> = ba
            .get(&f.name)
            .into_iter()
            .flatten()
            .chain(fed_here)
            .filter_map(|&i| f.params.get(i).map(String::as_str))
            .collect();
        if !mine.is_empty() {
            walk(&f.body, &mine, &mut out);
        }
    }
    out
}

/// Each named record field → every field (name, type) of its constructor, in order.
fn record_field_types(module: &ast::Module) -> HashMap<String, Vec<(String, Type)>> {
    let mut out = HashMap::new();
    for d in &module.datas {
        for c in &d.cons {
            if c.fields.iter().all(|f| !f.name.is_empty()) {
                let all: Vec<(String, Type)> = c
                    .fields
                    .iter()
                    .map(|f| (f.name.clone(), f.ty.clone()))
                    .collect();
                for f in &c.fields {
                    out.insert(f.name.clone(), all.clone());
                }
            }
        }
    }
    out
}

/// The names bound by `let x = if/case …`.
fn cond_bound_names(t: &Term, out: &mut HashSet<String>) {
    let sub = |r: &Rhs, out: &mut HashSet<String>| match r {
        Rhs::If(_, a, c) => {
            cond_bound_names(a, out);
            cond_bound_names(c, out);
        }
        Rhs::Case(_, arms) => arms.iter().for_each(|(_, a)| cond_bound_names(a, out)),
        Rhs::Op(_) => {}
    };
    match t {
        Term::Let(x, rhs, _, b) => {
            if matches!(rhs, Rhs::If(..) | Rhs::Case(..)) {
                out.insert(x.clone());
            }
            sub(rhs, out);
            cond_bound_names(b, out);
        }
        Term::Drop(_, _, _, _, b) => cond_bound_names(b, out),
        Term::Ret(r, _) => sub(r, out),
    }
}

fn let_bound_names(t: &Term, out: &mut HashSet<String>) {
    match t {
        Term::Let(x, rhs, _, b) => {
            out.insert(x.clone());
            match rhs {
                Rhs::If(_, a, c) => {
                    let_bound_names(a, out);
                    let_bound_names(c, out);
                }
                Rhs::Case(_, arms) => arms.iter().for_each(|(_, a)| let_bound_names(a, out)),
                Rhs::Op(_) => {}
            }
            let_bound_names(b, out);
        }
        Term::Drop(_, _, _, _, b) => let_bound_names(b, out),
        Term::Ret(Rhs::If(_, a, c), _) => {
            let_bound_names(a, out);
            let_bound_names(c, out);
        }
        Term::Ret(Rhs::Case(_, arms), _) => arms.iter().for_each(|(_, a)| let_bound_names(a, out)),
        Term::Ret(Rhs::Op(_), _) => {}
    }
}

/// See the call site in `lower_with`: a by-copy update whose base this function does not own (a
/// parameter not consumed here, or a pattern binder — anything not `let`-bound) gets fresh copies
/// of every unchanged heap field. Left alone when a field's type cannot be copied (a type
/// variable, a Buffer).
#[allow(clippy::too_many_arguments)]
fn copy_shared_update_fields(
    t: &mut Term,
    owned: &HashSet<String>,
    lets: &HashSet<String>,
    fields_of: &HashMap<String, Vec<(String, Type)>>,
    data_types: &HashSet<String>,
    enum_types: &HashSet<String>,
    copy_seeds: &mut Vec<Type>,
    ctr: &mut usize,
) {
    // the copies to add to an update, or None when it must be left alone
    #[allow(clippy::too_many_arguments)]
    fn plan(
        op: &Op,
        ctr: &mut usize,
        owned: &HashSet<String>,
        lets: &HashSet<String>,
        fields_of: &HashMap<String, Vec<(String, Type)>>,
        data_types: &HashSet<String>,
        enum_types: &HashSet<String>,
        copy_seeds: &mut Vec<Type>,
    ) -> Option<Vec<(String, String, Op)>> {
        let Op::UpdateRecord {
            base: Atom::Var(b),
            fields,
            inplace: false,
            ..
        } = op
        else {
            return None;
        };
        // a base owned here (`let`-bound, or a consumed `%1` param) is handled by the skips
        if lets.contains(b) || owned.contains(b) {
            return None;
        }
        let all = fields_of.get(&fields.first()?.0)?;
        let updated: HashSet<&String> = fields.iter().map(|(n, _)| n).collect();
        let mut out = Vec::new();
        for (fname, ty) in all {
            if updated.contains(fname) {
                continue;
            }
            let kind = match ty.head_con() {
                Some("Int" | "Float" | "Bool" | "Char") => continue,
                Some(h) if enum_types.contains(h) => continue,
                Some("String") => CopyKind::Str,
                Some("Integer") => CopyKind::Int,
                Some(h) if data_types.contains(h) || matches!(ty, Type::Tuple(_)) => {
                    let k = mono_key(ty)?;
                    copy_seeds.push(ty.clone());
                    CopyKind::Container(k)
                }
                _ if matches!(ty, Type::Tuple(_)) => {
                    let k = mono_key(ty)?;
                    copy_seeds.push(ty.clone());
                    CopyKind::Container(k)
                }
                // a function field: its own copy of the closure cell (and owned captures)
                _ if matches!(ty, Type::Arrow { .. })
                    && std::env::var_os("AXION_NO_CLOSURE_COPIES").is_none() =>
                {
                    CopyKind::Closure
                }
                _ => return None, // a type variable, Buffer: cannot copy
            };
            *ctr += 1;
            let fv = format!("$updfield{ctr}");
            out.push((fv.clone(), fname.clone(), alias_copy_op(&fv, &kind)));
        }
        Some(out)
    }
    fn wrap(t: Term, copies: Vec<(String, String, Op)>, b: &str, sp: Span) -> Term {
        let mut t = t;
        for (i, (fv, fname, cop)) in copies.into_iter().enumerate().rev() {
            let cv = format!("{fv}c{i}");
            // rename the copy's target in the update's field list
            fn set_field(t: &mut Term, fname: &str, cv: &str) {
                if let Term::Let(_, Rhs::Op(Op::UpdateRecord { fields, .. }), _, _)
                | Term::Ret(Rhs::Op(Op::UpdateRecord { fields, .. }), _) = t
                {
                    fields.push((fname.to_string(), Atom::Var(cv.to_string())));
                } else if let Term::Let(_, _, _, b) = t {
                    set_field(b, fname, cv);
                }
            }
            set_field(&mut t, &fname, &cv);
            t = Term::Let(cv, Rhs::Op(cop), sp, Box::new(t));
            t = Term::Let(
                fv,
                Rhs::Op(Op::Field {
                    name: fname,
                    rec: Atom::Var(b.to_string()),
                }),
                sp,
                Box::new(t),
            );
        }
        t
    }
    match t {
        Term::Let(_, Rhs::Op(op), sp, b) => {
            let base = match op {
                Op::UpdateRecord {
                    base: Atom::Var(v), ..
                } => Some(v.clone()),
                _ => None,
            };
            copy_shared_update_fields(
                b, owned, lets, fields_of, data_types, enum_types, copy_seeds, ctr,
            );
            if let (Some(base), Some(copies)) = (
                base,
                plan(
                    op, ctr, owned, lets, fields_of, data_types, enum_types, copy_seeds,
                ),
            ) {
                if !copies.is_empty() {
                    let sp = *sp;
                    let cur =
                        std::mem::replace(t, Term::Ret(Rhs::Op(Op::Atom(Atom::Int(0))), NO_SPAN));
                    *t = wrap(cur, copies, &base, sp);
                }
            }
        }
        Term::Let(_, rhs, _, b) => {
            match rhs {
                Rhs::If(_, a, c) => {
                    copy_shared_update_fields(
                        a, owned, lets, fields_of, data_types, enum_types, copy_seeds, ctr,
                    );
                    copy_shared_update_fields(
                        c, owned, lets, fields_of, data_types, enum_types, copy_seeds, ctr,
                    );
                }
                Rhs::Case(_, arms) => {
                    for (_, a) in arms {
                        copy_shared_update_fields(
                            a, owned, lets, fields_of, data_types, enum_types, copy_seeds, ctr,
                        );
                    }
                }
                Rhs::Op(_) => {}
            }
            copy_shared_update_fields(
                b, owned, lets, fields_of, data_types, enum_types, copy_seeds, ctr,
            );
        }
        Term::Drop(_, _, _, _, b) => copy_shared_update_fields(
            b, owned, lets, fields_of, data_types, enum_types, copy_seeds, ctr,
        ),
        Term::Ret(Rhs::Op(op), sp) => {
            let base = match op {
                Op::UpdateRecord {
                    base: Atom::Var(v), ..
                } => Some(v.clone()),
                _ => None,
            };
            if let (Some(base), Some(copies)) = (
                base,
                plan(
                    op, ctr, owned, lets, fields_of, data_types, enum_types, copy_seeds,
                ),
            ) {
                if !copies.is_empty() {
                    let sp = *sp;
                    let cur =
                        std::mem::replace(t, Term::Ret(Rhs::Op(Op::Atom(Atom::Int(0))), NO_SPAN));
                    *t = wrap(cur, copies, &base, sp);
                }
            }
        }
        Term::Ret(Rhs::If(_, a, c), _) => {
            copy_shared_update_fields(
                a, owned, lets, fields_of, data_types, enum_types, copy_seeds, ctr,
            );
            copy_shared_update_fields(
                c, owned, lets, fields_of, data_types, enum_types, copy_seeds, ctr,
            );
        }
        Term::Ret(Rhs::Case(_, arms), _) => {
            for (_, a) in arms {
                copy_shared_update_fields(
                    a, owned, lets, fields_of, data_types, enum_types, copy_seeds, ctr,
                );
            }
        }
    }
}

/// How to copy a bare-returned heap param so its return is owned, not an alias.
#[derive(Clone, PartialEq)]
enum CopyKind {
    /// `String` → `strAppend x ""` (a fresh `axion_strcat` copy).
    Str,
    /// `Integer` → `axion_bignum_copy x` (a fresh bignum clone).
    Int,
    /// A container/`data`/tuple (mono key `k`) → `axion_copy_<k> x`, a generated
    /// per-type deep-copier (R-5). The `CallDirect` result is owned (key `k`), the
    /// arg borrowed — see `gen_copiers`.
    Container(String),
    /// A function value → `axion_closure_copy x` (the cell, and the captures it owns).
    Closure,
}

/// The copy op for a target param of the given kind.
fn alias_copy_op(v: &str, kind: &CopyKind) -> Op {
    match kind {
        CopyKind::Str => Op::RtCall {
            func: "axion_strcat".into(),
            args: vec![Atom::Var(v.to_string()), Atom::Str(String::new())],
            returns: true,
        },
        CopyKind::Int => Op::RtCall {
            func: "axion_bignum_copy".into(),
            args: vec![Atom::Var(v.to_string())],
            returns: true,
        },
        CopyKind::Container(k) if k == "Closure" => Op::RtCall {
            func: "axion_closure_copy".into(),
            args: vec![Atom::Var(v.to_string())],
            returns: true,
        },
        CopyKind::Container(k) => Op::CallDirect(
            format!("axion_copy_{k}"),
            vec![Atom::Var(v.to_string())],
            Some(k.clone()),
        ),
        CopyKind::Closure => Op::RtCall {
            func: "axion_closure_copy".into(),
            args: vec![Atom::Var(v.to_string())],
            returns: true,
        },
    }
}

/// Replace each TAIL `ret <targetParam>` with `let t = <copy param>; ret t` (a fresh copy —
/// String via strAppend, Integer via axion_bignum_copy), so the return is owned and the param
/// is borrowed. See [`normalize_alias_returns`].
fn rewrite_alias_tails(
    t: &mut Term,
    targets: &HashMap<String, CopyKind>,
    through_calls: bool,
    ctr: &mut usize,
) {
    match t {
        Term::Ret(Rhs::Op(Op::Atom(Atom::Var(v))), sp) if targets.contains_key(v) => {
            let (sp, kind) = (*sp, targets[v].clone());
            let v = v.clone();
            let tmp = format!("$aliascopy{ctr}");
            *ctr += 1;
            let copy = alias_copy_op(&v, &kind);
            *t = Term::Let(
                tmp.clone(),
                Rhs::Op(copy),
                sp,
                Box::new(Term::Ret(Rhs::Op(Op::Atom(Atom::Var(tmp))), sp)),
            );
        }
        // …and a tail CALL that may return the target whole (`run name p = go acts name p`, `go`
        // returning `p` on a path): a target is one this function may return and its caller
        // reuses, so the callee gets a copy and this function only reads the parameter.
        Term::Ret(Rhs::Op(Op::CallDirect(_, args, _)), sp)
            if through_calls
                && args
                    .iter()
                    .any(|a| matches!(a, Atom::Var(v) if targets.contains_key(v))) =>
        {
            let sp = *sp;
            let mut copies = Vec::new();
            if let Term::Ret(Rhs::Op(Op::CallDirect(_, args, _)), _) = t {
                for a in args.iter_mut() {
                    if let Atom::Var(v) = a {
                        if let Some(kind) = targets.get(v) {
                            let tmp = format!("$aliascopy{ctr}");
                            *ctr += 1;
                            copies.push((tmp.clone(), alias_copy_op(v, kind)));
                            *a = Atom::Var(tmp);
                        }
                    }
                }
            }
            let inner = std::mem::replace(t, Term::Ret(Rhs::Op(Op::Atom(Atom::Int(0))), sp));
            *t = copies.into_iter().rev().fold(inner, |acc, (c, op)| {
                Term::Let(c, Rhs::Op(op), sp, Box::new(acc))
            });
        }
        Term::Ret(Rhs::If(_, a, b), _) => {
            rewrite_alias_tails(a, targets, through_calls, ctr);
            rewrite_alias_tails(b, targets, through_calls, ctr);
        }
        Term::Ret(Rhs::Case(_, arms), _) => {
            for (_, arm) in arms {
                rewrite_alias_tails(arm, targets, through_calls, ctr);
            }
        }
        Term::Ret(Rhs::Op(_), _) => {}
        // a clause binder naming a target (`tag$1 = _p0`, a multi-clause function's parameter)
        // is that target too
        Term::Let(x, Rhs::Op(Op::Atom(Atom::Var(v))), _, body) if targets.contains_key(v) => {
            let mut more = targets.clone();
            more.insert(x.clone(), targets[v].clone());
            rewrite_alias_tails(body, &more, through_calls, ctr);
        }
        Term::Let(_, _, _, body) | Term::Drop(_, _, _, _, body) => {
            rewrite_alias_tails(body, targets, through_calls, ctr);
        }
    }
}

/// The types of the binders that `case`s on a borrowed parameter (or on a binder brought out of
/// one) bring into scope, at every depth, derived from the parameter's declared type. `tys`
/// starts with the borrowed parameters and gains each binder whose type is known; a binder
/// under a constructor of an unknown data type, or of a type that is not concrete, is skipped
/// (no copy: the verifier still guards it).
fn interior_binder_types(t: &Term, datas: &[ast::DataDecl], tys: &mut HashMap<String, Type>) {
    match t {
        Term::Let(_, rhs, _, b) => {
            interior_rhs(rhs, datas, tys);
            interior_binder_types(b, datas, tys);
        }
        Term::Drop(_, _, _, _, b) => interior_binder_types(b, datas, tys),
        Term::Ret(rhs, _) => interior_rhs(rhs, datas, tys),
    }
    fn interior_rhs(rhs: &Rhs, datas: &[ast::DataDecl], tys: &mut HashMap<String, Type>) {
        match rhs {
            Rhs::Op(_) => {}
            Rhs::If(_, a, b) => {
                interior_binder_types(a, datas, tys);
                interior_binder_types(b, datas, tys);
            }
            Rhs::Case(sc, arms) => {
                let st = match sc {
                    Atom::Var(s) => tys.get(s).cloned(),
                    _ => None,
                };
                for (p, b) in arms {
                    if let Some(st) = &st {
                        for (n, ft) in pattern_field_types(p, st, datas) {
                            tys.insert(n, ft);
                        }
                    }
                    interior_binder_types(b, datas, tys);
                }
            }
        }
    }
}

/// The `Var` sub-patterns of a one-level pattern on a value of type `st`, with their types.
fn pattern_field_types(p: &CPat, st: &Type, datas: &[ast::DataDecl]) -> Vec<(String, Type)> {
    let mut out = Vec::new();
    match p {
        CPat::Tuple(subs) => {
            if let Type::Tuple(ts) = st {
                for (sp, t) in subs.iter().zip(ts) {
                    if let CPat::Var(n) = sp {
                        out.push((n.clone(), t.clone()));
                    }
                }
            }
        }
        CPat::Con(c, subs) => {
            let Some(head) = st.head_con() else {
                return out;
            };
            let Some(d) = datas.iter().find(|d| d.name == head) else {
                return out;
            };
            let Some(con) = d.cons.iter().find(|k| &k.name == c) else {
                return out;
            };
            // the type arguments of `st` (`D a1 … an`), left to right
            let mut args = Vec::new();
            let mut cur = st;
            while let Type::App(f, a) = cur {
                args.push((**a).clone());
                cur = f;
            }
            args.reverse();
            if args.len() != d.params.len() {
                return out;
            }
            let subst: HashMap<String, Type> = d.params.iter().cloned().zip(args).collect();
            for (sp, fl) in subs.iter().zip(&con.fields) {
                if let CPat::Var(n) = sp {
                    out.push((n.clone(), subst_ty(&fl.ty, &subst)));
                }
            }
        }
        _ => {}
    }
    out
}

/// The names of the functions `t` calls directly.
fn direct_callees(t: &Term, out: &mut HashSet<String>) {
    fn rhs(r: &Rhs, out: &mut HashSet<String>) {
        match r {
            Rhs::Op(Op::CallDirect(g, _, _)) => {
                out.insert(g.clone());
            }
            Rhs::Op(_) => {}
            Rhs::If(_, a, b) => {
                direct_callees(a, out);
                direct_callees(b, out);
            }
            Rhs::Case(_, arms) => {
                for (_, b) in arms {
                    direct_callees(b, out);
                }
            }
        }
    }
    match t {
        Term::Let(_, r, _, b) => {
            rhs(r, out);
            direct_callees(b, out);
        }
        Term::Drop(_, _, _, _, b) => direct_callees(b, out),
        Term::Ret(r, _) => rhs(r, out),
    }
}

/// How to copy a value of type `t` (`None` = not a heap value, or no copier for it).
fn copy_kind_of(t: &Type, datas: &[ast::DataDecl]) -> Option<CopyKind> {
    match t.head_con() {
        Some("String") => return Some(CopyKind::Str),
        Some("Integer") => return Some(CopyKind::Int),
        _ => {}
    }
    if matches!(t, Type::Arrow { .. }) {
        return Some(CopyKind::Closure);
    }
    let container = matches!(t, Type::Tuple(_))
        || t.head_con().is_some_and(|h| {
            datas
                .iter()
                .any(|d| d.name == h && d.cons.iter().any(|c| !c.fields.is_empty()))
        });
    if !container {
        return None;
    }
    mono_key(t).map(CopyKind::Container)
}

/// The kind of borrow `t` returns on every path (`ret a` with `a` a known borrow), if one.
fn tail_borrow_kind(t: &Term, bv: &HashMap<String, CopyKind>) -> Option<CopyKind> {
    match t {
        Term::Let(_, _, _, b) | Term::Drop(_, _, _, _, b) => tail_borrow_kind(b, bv),
        Term::Ret(Rhs::Op(Op::Atom(Atom::Var(v))), _) => bv.get(v).cloned(),
        Term::Ret(Rhs::Op(_), _) => None,
        Term::Ret(Rhs::If(_, a, b), _) => {
            let k = tail_borrow_kind(a, bv)?;
            (tail_borrow_kind(b, bv)? == k).then_some(k)
        }
        Term::Ret(Rhs::Case(_, arms), _) => {
            let mut ks = arms.iter().map(|(_, b)| tail_borrow_kind(b, bv));
            let k = ks.next()??;
            ks.all(|o| o.as_ref() == Some(&k)).then_some(k)
        }
    }
}

/// Copies a borrow (the result of a borrow-returning call, or an alias of one) at each op that
/// MOVES it into something new — a constructor, a tuple, a consuming call — so the new value
/// owns a copy instead of sharing memory with the borrow's owner (who frees it). A `ret` of the
/// bare borrow is left as is: that is how a borrow-returning function hands its borrow on.
fn copy_moved_borrows(
    t: &mut Term,
    kinds: &HashMap<String, CopyKind>,
    ba: &BorrowArgs,
    bv: &mut HashMap<String, CopyKind>,
    ctr: &mut usize,
) {
    // the copies an op needs (borrows it moves), and the op with them substituted
    fn plan(
        op: &Op,
        ba: &BorrowArgs,
        bv: &HashMap<String, CopyKind>,
        ctr: &mut usize,
    ) -> Vec<(String, String, CopyKind)> {
        if matches!(op, Op::Atom(_)) {
            return Vec::new();
        }
        let e = crate::delta::op_delta_effect(op, ba);
        let mut out: Vec<(String, String, CopyKind)> = Vec::new();
        for a in &e.moves {
            if let Atom::Var(v) = a {
                if let Some(k) = bv.get(v) {
                    if !out.iter().any(|(w, _, _)| w == v) {
                        let c = format!("$borrowcopy{ctr}");
                        *ctr += 1;
                        out.push((v.clone(), c, k.clone()));
                    }
                }
            }
        }
        out
    }
    fn wrap(mut t: Term, copies: Vec<(String, String, CopyKind)>, sp: Span) -> Term {
        for (v, c, k) in copies.into_iter().rev() {
            t = Term::Let(c, Rhs::Op(alias_copy_op(&v, &k)), sp, Box::new(t));
        }
        t
    }
    match t {
        Term::Let(x, rhs, sp, body) => {
            if let Rhs::Op(op) = rhs {
                match op {
                    Op::CallDirect(g, _, _) if kinds.contains_key(g) => {
                        bv.insert(x.clone(), kinds[g].clone());
                    }
                    Op::Atom(Atom::Var(y)) if bv.contains_key(y) => {
                        let k = bv[y].clone();
                        bv.insert(x.clone(), k);
                    }
                    _ => {}
                }
                let copies = plan(op, ba, bv, ctr);
                if !copies.is_empty() {
                    let env: HashMap<String, String> = copies
                        .iter()
                        .map(|(v, c, _)| (v.clone(), c.clone()))
                        .collect();
                    uq_op(op, &env);
                    let sp0 = *sp;
                    copy_moved_borrows(body, kinds, ba, bv, ctr);
                    let cur =
                        std::mem::replace(t, Term::Ret(Rhs::Op(Op::Atom(Atom::Int(0))), NO_SPAN));
                    *t = wrap(cur, copies, sp0);
                    return;
                }
            } else {
                copy_rhs(rhs, kinds, ba, bv, ctr);
                // a `let`-bound `case`/`if` whose every branch hands back the same kind of
                // borrow (`let s = case p of (a, _) -> a`) is that borrow too
                let tails = match &*rhs {
                    Rhs::If(_, a, b) => vec![tail_borrow_kind(a, bv), tail_borrow_kind(b, bv)],
                    Rhs::Case(_, arms) => {
                        arms.iter().map(|(_, b)| tail_borrow_kind(b, bv)).collect()
                    }
                    Rhs::Op(_) => Vec::new(),
                };
                if let Some(Some(k)) = tails.first() {
                    if tails.iter().all(|t| t.as_ref() == Some(k)) {
                        bv.insert(x.clone(), k.clone());
                    }
                }
            }
            copy_moved_borrows(body, kinds, ba, bv, ctr);
        }
        Term::Drop(_, _, _, _, body) => copy_moved_borrows(body, kinds, ba, bv, ctr),
        Term::Ret(rhs, sp) => {
            if let Rhs::Op(op) = rhs {
                let copies = plan(op, ba, bv, ctr);
                if !copies.is_empty() {
                    let env: HashMap<String, String> = copies
                        .iter()
                        .map(|(v, c, _)| (v.clone(), c.clone()))
                        .collect();
                    uq_op(op, &env);
                    let sp0 = *sp;
                    let cur =
                        std::mem::replace(t, Term::Ret(Rhs::Op(Op::Atom(Atom::Int(0))), NO_SPAN));
                    *t = wrap(cur, copies, sp0);
                }
            } else {
                copy_rhs(rhs, kinds, ba, bv, ctr);
            }
        }
    }
    fn copy_rhs(
        rhs: &mut Rhs,
        kinds: &HashMap<String, CopyKind>,
        ba: &BorrowArgs,
        bv: &mut HashMap<String, CopyKind>,
        ctr: &mut usize,
    ) {
        match rhs {
            Rhs::Op(_) => {}
            Rhs::If(_, a, b) => {
                copy_moved_borrows(a, kinds, ba, bv, ctr);
                copy_moved_borrows(b, kinds, ba, bv, ctr);
            }
            Rhs::Case(_, arms) => {
                for (_, b) in arms {
                    copy_moved_borrows(b, kinds, ba, bv, ctr);
                }
            }
        }
    }
}

/// Counts the tail returns of `t`: `alias` = returns of a field a `case` bound out of a borrowed
/// param (`fields` holds those binders in scope), `other` = every other return.
fn count_field_tails(
    t: &Term,
    borrowed: &HashSet<String>,
    fields: &mut HashSet<String>,
    alias: &mut usize,
    other: &mut usize,
) {
    match t {
        Term::Let(_, _, _, b) | Term::Drop(_, _, _, _, b) => {
            count_field_tails(b, borrowed, fields, alias, other)
        }
        Term::Ret(Rhs::Op(Op::Atom(Atom::Var(v))), _) if fields.contains(v) => *alias += 1,
        Term::Ret(Rhs::If(_, a, b), _) => {
            count_field_tails(a, borrowed, fields, alias, other);
            count_field_tails(b, borrowed, fields, alias, other);
        }
        Term::Ret(Rhs::Case(sc, arms), _) => {
            for (p, b) in arms {
                let added = case_param_binders(sc, p, borrowed, fields);
                count_field_tails(b, borrowed, fields, alias, other);
                for n in added {
                    fields.remove(&n);
                }
            }
        }
        Term::Ret(..) => *other += 1,
    }
}

/// The binders a `case` on a borrowed param brings into scope (added to `fields`; returned so
/// the caller can remove them after the arm).
fn case_param_binders(
    sc: &Atom,
    p: &CPat,
    borrowed: &HashSet<String>,
    fields: &mut HashSet<String>,
) -> Vec<String> {
    let Atom::Var(s) = sc else { return Vec::new() };
    // a case on a borrowed param, or on a binder one brought out (`Just p -> case p of (k, s)`,
    // the nested patterns' inner cases): every level is an interior of the borrowed param
    if !borrowed.contains(s) && !fields.contains(s) {
        return Vec::new();
    }
    let mut bs = Vec::new();
    if let CPat::Con(_, subs) | CPat::Tuple(subs) = p {
        for sp in subs {
            if let CPat::Var(n) = sp {
                if fields.insert(n.clone()) {
                    bs.push(n.clone());
                }
            }
        }
    }
    bs
}

/// Rewrites each tail `ret field` counted as `alias` by `count_field_tails` into a fresh copy.
fn copy_field_tails(
    t: &mut Term,
    borrowed: &HashSet<String>,
    fields: &mut HashSet<String>,
    kind: &CopyKind,
    ctr: &mut usize,
) {
    match t {
        Term::Let(_, _, _, b) | Term::Drop(_, _, _, _, b) => {
            copy_field_tails(b, borrowed, fields, kind, ctr)
        }
        Term::Ret(Rhs::Op(Op::Atom(Atom::Var(v))), sp) if fields.contains(v) => {
            let (v, sp) = (v.clone(), *sp);
            let tmp = format!("$fieldcopy{ctr}");
            *ctr += 1;
            *t = Term::Let(
                tmp.clone(),
                Rhs::Op(alias_copy_op(&v, kind)),
                sp,
                Box::new(Term::Ret(Rhs::Op(Op::Atom(Atom::Var(tmp))), sp)),
            );
        }
        Term::Ret(Rhs::If(_, a, b), _) => {
            copy_field_tails(a, borrowed, fields, kind, ctr);
            copy_field_tails(b, borrowed, fields, kind, ctr);
        }
        Term::Ret(Rhs::Case(sc, arms), _) => {
            let sc = sc.clone();
            for (p, b) in arms {
                let added = case_param_binders(&sc, p, borrowed, fields);
                copy_field_tails(b, borrowed, fields, kind, ctr);
                for n in added {
                    fields.remove(&n);
                }
            }
        }
        Term::Ret(..) => {}
    }
}

/// Copy the bare-param returns that a caller actually reuses (R-2/R-3, docs/call-site-ownership.md):
/// for each parameter index in `copy_params` (= `ret_alias(f) ∩ reused(f)`, precomputed by the
/// caller) that is a non-`%1` heap **String** or **Integer**, rewrite `ret param` → `let t =
/// copy param; ret t`. A bare-param return is copied only when some caller keeps the arg alive
/// past the call — so a never-reused return (`chomp`, and every fold ACCUMULATOR, whose `acc`
/// is never reused by `foldl`) keeps its zero-cost move, while a genuinely-reused one
/// (`condRet`/`relJoin`) is made owned. The reuse gate is what lets Integer join safely: the
/// per-iteration bignum clone that regressed the first (ungated) Integer attempt never fires,
/// because accumulators are not reused. Containers (R-5) need a deep-copy generator — excluded.
fn normalize_alias_returns(
    f: &mut CoreFn,
    ptys: &[Type],
    copy_params: &HashSet<usize>,
    ctr: &mut usize,
    data_types: &HashSet<String>,
    enum_types: &HashSet<String>,
    copy_seeds: &mut Vec<Type>,
) {
    let owned: HashSet<&String> = f.owned_params.iter().collect();
    let targets: HashMap<String, CopyKind> = f
        .params
        .iter()
        .zip(ptys)
        .enumerate()
        .filter(|(i, (p, _))| copy_params.contains(i) && !owned.contains(p))
        .filter_map(|(_, (p, ty))| {
            if let Some("String") = ty.head_con() {
                return Some((p.clone(), CopyKind::Str));
            }
            if let Some("Integer") = ty.head_con() {
                return Some((p.clone(), CopyKind::Int));
            }
            // a function value returned whole: a copy of the closure cell
            if matches!(ty, Type::Arrow { .. }) {
                return Some((p.clone(), CopyKind::Closure));
            }
            // R-5 TUPLE copier: a reused tuple param-return (`pickT c t = if … else t`, caller
            // reuses `t`) needs a fresh owned copy `axion_copy_tuple$…`. Concrete mono key only
            // (`mono_key` `None` for a poly element → fail-closed); `gen_copiers` emits the
            // tuple copier (single implicit con, `i*8` slots) + transitively its element copiers.
            if matches!(ty, Type::Tuple(_)) {
                return mono_key(ty).map(|k| {
                    copy_seeds.push((*ty).clone());
                    (p.clone(), CopyKind::Container(k))
                });
            }
            // R-5: a `data` container with a CONCRETE mono destructor key gets a generated
            // per-type deep-copier `axion_copy_<key>`; seed its type so the copier (and,
            // transitively, its heap fields') is emitted. Restricted to a `data`-decl head
            // (`gen_copiers` needs the declaration): a pure enum (unboxed immediate,
            // value-copied) stays fail-closed → no copier. A polymorphic key (`mono_key`
            // `None`) also stays fail-closed.
            if ty
                .head_con()
                .is_some_and(|h| data_types.contains(h) && !enum_types.contains(h))
            {
                return mono_key(ty).map(|k| {
                    copy_seeds.push((*ty).clone());
                    (p.clone(), CopyKind::Container(k))
                });
            }
            None
        })
        .collect();
    if !targets.is_empty() {
        rewrite_alias_tails(&mut f.body, &targets, true, ctr);
    }
}

/// The drop key of an op whose result is a FRESH OWNED heap value that cannot alias an operand —
/// a String/Integer producer, `ShowInt`, or a direct call to a function that returns NO interior
/// alias of its args (`g ∉ br`) carrying a known heap return key. `None` for scalars, literals
/// (`Atom(Str/Int)`), bare var returns (a possible param alias), `Field`/getters, and alias-
/// returning calls — so an arm that could alias an owned value never gets reclaimed here.
fn op_owned_key(
    op: &Op,
    br: &HashMap<String, HashSet<usize>>,
    recinfo: &RecordInfo,
) -> Option<String> {
    match op {
        Op::CallDirect(g, _, Some(k)) if !br.contains_key(g) => Some(k.clone()),
        Op::ShowInt(_) => Some("String".into()),
        Op::RtCall { .. } => fresh_let_producer_key(op),
        // a constructor builds a FRESH owned value; its deep-drop key (set at lowering) lets a
        // conditional whose arms are `con …` be recognized as an owned temp (so a `let x = if …`
        // producing a `List`/`data`/… is reclaimed instead of leaking the spine).
        Op::MakeCon { ty: Some(k), .. } => Some(k.clone()),
        // …and so do a record literal and a BY-COPY record update (an in-place one reuses its base)
        Op::MakeRecord { ty: Some(k), .. } => Some(k.clone()),
        // (only when it shares no heap field with its base — a base's shared fields are copied
        // first unless the base is owned here)
        Op::UpdateRecord {
            inplace: false,
            ty: Some(k),
            fields,
            ..
        } if recinfo.update_is_fresh(fields) => Some(k.clone()),
        _ => None,
    }
}

/// The owned-heap key produced at the TAIL of an `if`/`case` arm. The arm is ANF — a chain of
/// `let`s ending in `ret <var>` — so we thread a binding→key env: at `ret v` the key is whatever
/// `v` was bound with (`None` for a borrowed param / non-producer). A direct `ret <op>` or a nested
/// conditional tail resolves inline. `None` unless the arm provably yields a fresh owned heap value.
fn arm_owned_key(
    t: &Term,
    br: &HashMap<String, HashSet<usize>>,
    recinfo: &RecordInfo,
) -> Option<String> {
    arm_owned_key_env(t, br, recinfo, &mut HashMap::new())
}
fn arm_owned_key_env(
    t: &Term,
    br: &HashMap<String, HashSet<usize>>,
    recinfo: &RecordInfo,
    env: &mut HashMap<String, Option<String>>,
) -> Option<String> {
    match t {
        Term::Let(x, rhs, _, b) => {
            let k = match rhs {
                Rhs::Op(op) => op_owned_key(op, br, recinfo),
                Rhs::If(..) | Rhs::Case(..) => cond_temp_key(rhs, br, recinfo),
            };
            env.insert(x.clone(), k);
            arm_owned_key_env(b, br, recinfo, env)
        }
        Term::Drop(_, _, _, _, b) => arm_owned_key_env(b, br, recinfo, env),
        Term::Ret(Rhs::Op(Op::Atom(Atom::Var(v))), _) => env.get(v).cloned().flatten(),
        Term::Ret(Rhs::Op(op), _) => op_owned_key(op, br, recinfo),
        Term::Ret(rhs @ (Rhs::If(..) | Rhs::Case(..)), _) => cond_temp_key(rhs, br, recinfo),
    }
}

/// A `case` whose every arm frees its scrutinee except one slot and returns that slot's binder
/// (`case t of (a, _) -> drop t skip{0}; ret a`): the field was moved out, so the result owns it.
/// Its key, when the arms agree on one (the binders' drop types).
fn moveout_case_key(rhs: &Rhs, dty: &HashMap<String, Option<String>>) -> Option<String> {
    fn skip_of(s: &str, t: &Term) -> Option<usize> {
        match t {
            Term::Drop(v, _, skip, _, _) if v == s => match skip.as_slice() {
                [i] => Some(*i),
                _ => None,
            },
            Term::Drop(_, _, _, _, b) | Term::Let(_, Rhs::Op(_), _, b) => skip_of(s, b),
            _ => None,
        }
    }
    fn returns(v: &str, t: &Term) -> bool {
        match t {
            Term::Drop(w, _, _, _, b) => w != v && returns(v, b),
            Term::Let(y, Rhs::Op(_), _, b) => y != v && returns(v, b),
            Term::Ret(Rhs::Op(Op::Atom(Atom::Var(w))), _) => w == v,
            _ => false,
        }
    }
    let Rhs::Case(Atom::Var(s), arms) = rhs else {
        return None;
    };
    let mut key: Option<String> = None;
    for (pat, arm) in arms {
        let subs = match pat {
            CPat::Tuple(subs) | CPat::Con(_, subs) => subs,
            _ => return None,
        };
        let i = skip_of(s, arm)?;
        let CPat::Var(v) = subs.get(i)? else {
            return None;
        };
        if !returns(v, arm) {
            return None;
        }
        let k = dty.get(v).cloned().flatten()?;
        if key.get_or_insert_with(|| k.clone()) != &k {
            return None;
        }
    }
    key
}

/// If `rhs` is a conditional whose EVERY arm yields a fresh owned heap value of the SAME key, that
/// key — so a `let x = if/case … (all heap arms)` result is a genuinely-owned temp that must be
/// reclaimed at its (unconditional) death point, exactly as the verifier already scores it. Returns
/// `None` when any arm is a literal/scalar/alias (the MIXED case needs branch-sensitive handling and
/// is left to the tail-position idiom), so this never introduces a double-free.
fn cond_temp_key(
    rhs: &Rhs,
    br: &HashMap<String, HashSet<usize>>,
    recinfo: &RecordInfo,
) -> Option<String> {
    match rhs {
        Rhs::If(_, th, el) => {
            let k = arm_owned_key(th, br, recinfo)?;
            (arm_owned_key(el, br, recinfo) == Some(k.clone())).then_some(k)
        }
        Rhs::Case(_, arms) => {
            let mut it = arms.iter();
            let first = arm_owned_key(&it.next()?.1, br, recinfo)?;
            it.all(|(_, a)| arm_owned_key(a, br, recinfo) == Some(first.clone()))
                .then_some(first)
        }
        Rhs::Op(_) => None,
    }
}

/// For a `let x = if/case` whose arms MIX an owned-heap value (key `String`/`Integer`) with a
/// non-owned ATOM tail (a literal or borrowed param — `if c then strAppend … else s`), COPY the
/// non-owned arms (`ret s` → `ret strAppend s ""`, or `axion_bignum_copy` for `Integer`) so EVERY
/// arm is uniformly owned. Then `x` is a genuinely-owned temp the all-heap reclaim already seeds —
/// closing the MIXED conditional-owned-temp leak (the #1 flagship gotcha) without a branch-
/// sensitive drop. Returns the rewritten `rhs` + its uniform key, or `None` when not a cleanly-
/// copyable mixed case (a disagreeing key, a non-`String`/`Integer` key, or a non-atom tail) —
/// left conservative (still a leak, never a double free).
fn copy_mixed_cond_arms(
    rhs: &Rhs,
    br: &HashMap<String, HashSet<usize>>,
    recinfo: &RecordInfo,
    hint: Option<String>,
) -> Option<(Rhs, String)> {
    let arms: Vec<&Term> = match rhs {
        Rhs::If(_, th, el) => vec![th, el],
        Rhs::Case(_, arms) => arms.iter().map(|(_, a)| a).collect(),
        Rhs::Op(_) => return None,
    };
    let mut key: Option<String> = None;
    let mut any_nonowned = false;
    for a in &arms {
        match arm_owned_key(a, br, recinfo) {
            Some(k) => {
                if key.get_or_insert_with(|| k.clone()) != &k {
                    return None; // arms yield different owned keys — not uniform
                }
            }
            None => any_nonowned = true,
        }
    }
    // at least one arm must be a recognized owned heap producer — or the arms' type is known
    // otherwise (`hint`: a `case` arm returning a String/Integer field it bound), or an owned leaf
    // of a nested conditional names it (`if a then "x" else if b then s ++ t else ""`)
    let key = key
        .or(hint)
        .or_else(|| arms.iter().find_map(|a| leaf_owned_key(a, br, recinfo)))?;
    if !any_nonowned {
        return None; // all owned → the existing all-heap path handles it
    }
    // the heap primitives' stock copiers, or a plain (non-parametric, boxed) `data` type's
    // generated deep copier `axion_copy_T` (requested by `copier_calls` after this pass)
    let plain_data = !key.contains('$')
        && recinfo.type_cons(&key).is_some()
        && !recinfo.is_enum_type(&key)
        && !recinfo.is_mixed_type(&key);
    if key != "String" && key != "Integer" && !plain_data {
        return None;
    }
    let rewrite = |a: Term, br: &HashMap<String, HashSet<usize>>| -> Option<Term> {
        if arm_owned_key(&a, br, recinfo).is_some() {
            Some(a) // owned arm: already the key, keep as-is
        } else {
            // copy each non-owned leaf, through nested conditionals too
            copy_leaves(a, &key, br, recinfo, &mut HashMap::new())
        }
    };
    let new_rhs = match rhs.clone() {
        Rhs::If(c, th, el) => Rhs::If(c, Box::new(rewrite(*th, br)?), Box::new(rewrite(*el, br)?)),
        Rhs::Case(s, arms) => Rhs::Case(
            s,
            arms.into_iter()
                .map(|(p, a)| rewrite(a, br).map(|a| (p, a)))
                .collect::<Option<Vec<_>>>()?,
        ),
        Rhs::Op(_) => return None,
    };
    Some((new_rhs, key))
}

/// Pre-pass (BEFORE borrow analysis): uniformize a `let x = if/case` whose arms MIX an owned-heap
/// producer with a bare-atom tail (`let x = if c then strAppend … else s`) by COPYING the non-owned
/// arms. Must run before `compute_borrow_args`: the copied arm merely READS its source (a borrow),
/// so the caller reclaims the argument and `x` becomes a uniformly-owned temp the all-heap reclaim
/// seeds. (Running it later would change a param consumed→borrowed after the caller's call-site
/// annotation was already fixed as a move → the argument freed by neither → a leak.) Only non-tail
/// `let` conditionals; a TAIL `ret if/case` escapes and is the caller's / ret-alias pass's domain.
fn normalize_mixed_cond_lets(
    t: Term,
    recinfo: &RecordInfo,
    env: &mut HashMap<String, String>,
) -> Term {
    let empty: HashMap<String, HashSet<usize>> = HashMap::new();
    fn norm_rhs(rhs: Rhs, recinfo: &RecordInfo, env: &mut HashMap<String, String>) -> Rhs {
        match rhs {
            Rhs::If(c, th, el) => Rhs::If(
                c,
                Box::new(normalize_mixed_cond_lets(*th, recinfo, env)),
                Box::new(normalize_mixed_cond_lets(*el, recinfo, env)),
            ),
            Rhs::Case(s, arms) => Rhs::Case(
                s,
                arms.into_iter()
                    .map(|(p, a)| (p, normalize_mixed_cond_lets(a, recinfo, env)))
                    .collect(),
            ),
            other => other,
        }
    }
    match t {
        Term::Let(x, rhs, sp, b) => {
            let rhs = if matches!(&rhs, Rhs::If(..) | Rhs::Case(..))
                && cond_temp_key(&rhs, &empty, recinfo).is_none()
            {
                let hint = case_field_ret_key(&rhs, recinfo, env);
                copy_mixed_cond_arms(&rhs, &empty, recinfo, hint)
                    .map(|(r, _)| r)
                    .unwrap_or(rhs)
            } else {
                rhs
            };
            // the mono key of a fresh owned value (a constructor, a keyed call, a conditional of
            // them), for a later `case` on it
            let k = match &rhs {
                Rhs::Op(op) => op_owned_key(op, &empty, recinfo),
                _ => cond_temp_key(&rhs, &empty, recinfo),
            };
            if let Some(k) = k {
                env.insert(x.clone(), k);
            }
            Term::Let(
                x,
                norm_rhs(rhs, recinfo, env),
                sp,
                Box::new(normalize_mixed_cond_lets(*b, recinfo, env)),
            )
        }
        Term::Drop(v, k, sk, sp, b) => Term::Drop(
            v,
            k,
            sk,
            sp,
            Box::new(normalize_mixed_cond_lets(*b, recinfo, env)),
        ),
        Term::Ret(rhs, sp) => Term::Ret(norm_rhs(rhs, recinfo, env), sp),
    }
}

/// The type (`String`/`Integer`) of a `case` whose arm returns a field it bound
/// (`case m of Just v -> v; Nothing -> ""`), from the scrutinee's mono key (`Maybe$String`) —
/// the key `copy_mixed_cond_arms` needs when no arm is a recognized owned producer.
fn case_field_ret_key(
    rhs: &Rhs,
    recinfo: &RecordInfo,
    env: &HashMap<String, String>,
) -> Option<String> {
    let Rhs::Case(Atom::Var(s), arms) = rhs else {
        return None;
    };
    let sk = env.get(s)?;
    arms.iter().find_map(|(p, a)| {
        let CPat::Con(con, subs) = p else { return None };
        let ret = tail_ret_var(a)?;
        let fi = subs
            .iter()
            .position(|sp| matches!(sp, CPat::Var(n) if n == ret))?;
        recinfo.field_tagged_key(con, fi, sk).or_else(|| {
            // a concretely-typed field (`Tagged String Int`)
            recinfo
                .field_drop_slot(con, fi)
                .filter(|k| k == "String" || k == "Integer")
        })
    })
}

/// The variable a straight-line arm returns (`… ret v`), if it returns a bare variable.
fn tail_ret_var(t: &Term) -> Option<&String> {
    match t {
        Term::Let(_, _, _, b) | Term::Drop(_, _, _, _, b) => tail_ret_var(b),
        Term::Ret(Rhs::Op(Op::Atom(Atom::Var(v))), _) => Some(v),
        Term::Ret(..) => None,
    }
}

/// Descend to the TAIL `ret <atom>` of an arm and wrap the atom in a copy so the arm yields an
/// OWNED heap value (`strAppend a ""` for a `String`, `axion_bignum_copy a` for an `Integer`).
/// `None` if the tail is not a simple atom return (a nested conditional / op) — left conservative.
/// The plain `data` types whose generated copier `axion_copy_T` a body calls.
fn copier_calls(t: &Term, out: &mut HashSet<String>) {
    let op = |op: &Op, out: &mut HashSet<String>| {
        if let Op::CallDirect(g, _, _) = op {
            if let Some(k) = g.strip_prefix("axion_copy_") {
                if !k.contains('$') && !k.starts_with("clo") {
                    out.insert(k.to_string());
                }
            }
        }
    };
    let rhs = |r: &Rhs, out: &mut HashSet<String>| match r {
        Rhs::Op(o) => op(o, out),
        Rhs::If(_, a, b) => {
            copier_calls(a, out);
            copier_calls(b, out);
        }
        Rhs::Case(_, arms) => arms.iter().for_each(|(_, a)| copier_calls(a, out)),
    };
    match t {
        Term::Let(_, r, _, b) => {
            rhs(r, out);
            copier_calls(b, out);
        }
        Term::Drop(_, _, _, _, b) => copier_calls(b, out),
        Term::Ret(r, _) => rhs(r, out),
    }
}

/// The owned key of some leaf of `t` (a tail value of it, through nested conditionals).
fn leaf_owned_key(
    t: &Term,
    br: &HashMap<String, HashSet<usize>>,
    recinfo: &RecordInfo,
) -> Option<String> {
    if let Some(k) = arm_owned_key(t, br, recinfo) {
        return Some(k);
    }
    match t {
        Term::Let(_, _, _, b) | Term::Drop(_, _, _, _, b) => leaf_owned_key(b, br, recinfo),
        Term::Ret(Rhs::If(_, a, b), _) => {
            leaf_owned_key(a, br, recinfo).or_else(|| leaf_owned_key(b, br, recinfo))
        }
        Term::Ret(Rhs::Case(_, arms), _) => arms
            .iter()
            .find_map(|(_, a)| leaf_owned_key(a, br, recinfo)),
        Term::Ret(Rhs::Op(_), _) => None,
    }
}

/// `t` with every leaf (tail value, through nested conditionals) an owned `key` value: an owned
/// leaf of that key is kept, a bare atom is copied; anything else gives up (`None`).
fn copy_leaves(
    t: Term,
    key: &str,
    br: &HashMap<String, HashSet<usize>>,
    recinfo: &RecordInfo,
    env: &mut HashMap<String, Option<String>>,
) -> Option<Term> {
    match t {
        Term::Let(x, r, sp, b) => {
            let k = match &r {
                Rhs::Op(op) => op_owned_key(op, br, recinfo),
                Rhs::If(..) | Rhs::Case(..) => cond_temp_key(&r, br, recinfo),
            };
            env.insert(x.clone(), k);
            Some(Term::Let(
                x,
                r,
                sp,
                Box::new(copy_leaves(*b, key, br, recinfo, env)?),
            ))
        }
        Term::Drop(v, k, sk, sp, b) => Some(Term::Drop(
            v,
            k,
            sk,
            sp,
            Box::new(copy_leaves(*b, key, br, recinfo, env)?),
        )),
        Term::Ret(Rhs::Op(Op::Atom(Atom::Var(v))), sp)
            if env.get(&v).cloned().flatten().as_deref() == Some(key) =>
        {
            Some(Term::Ret(Rhs::Op(Op::Atom(Atom::Var(v))), sp))
        }
        Term::Ret(Rhs::Op(Op::Atom(a)), sp) => {
            wrap_tail_copy(Term::Ret(Rhs::Op(Op::Atom(a)), sp), key)
        }
        Term::Ret(Rhs::Op(op), sp) => (op_owned_key(&op, br, recinfo).as_deref() == Some(key))
            .then_some(Term::Ret(Rhs::Op(op), sp)),
        Term::Ret(Rhs::If(c, a, b), sp) => {
            let a = copy_leaves(*a, key, br, recinfo, &mut env.clone())?;
            let b = copy_leaves(*b, key, br, recinfo, &mut env.clone())?;
            Some(Term::Ret(Rhs::If(c, Box::new(a), Box::new(b)), sp))
        }
        Term::Ret(Rhs::Case(sc, arms), sp) => {
            let arms = arms
                .into_iter()
                .map(|(p, a)| copy_leaves(a, key, br, recinfo, &mut env.clone()).map(|a| (p, a)))
                .collect::<Option<Vec<_>>>()?;
            Some(Term::Ret(Rhs::Case(sc, arms), sp))
        }
    }
}

fn wrap_tail_copy(t: Term, key: &str) -> Option<Term> {
    match t {
        Term::Let(x, r, sp, b) => Some(Term::Let(x, r, sp, Box::new(wrap_tail_copy(*b, key)?))),
        Term::Drop(v, k, sk, sp, b) => {
            Some(Term::Drop(v, k, sk, sp, Box::new(wrap_tail_copy(*b, key)?)))
        }
        Term::Ret(Rhs::Op(Op::Atom(a)), sp) => {
            let op = if key != "Integer" && key != "String" {
                Op::CallDirect(format!("axion_copy_{key}"), vec![a], Some(key.to_string()))
            } else if key == "Integer" {
                Op::RtCall {
                    func: "axion_bignum_copy".into(),
                    args: vec![a],
                    returns: true,
                }
            } else {
                Op::RtCall {
                    func: "axion_strcat".into(),
                    args: vec![a, Atom::Str(String::new())],
                    returns: true,
                }
            };
            Some(Term::Ret(Rhs::Op(op), sp))
        }
        Term::Ret(_, _) => None,
    }
}

/// The FIELD MOVE-OUT candidate of `op` for [`reclaim_cond_escape`]: `field f v` reading a heap
/// field of an OWNED record `v` (in `owned`, keyed by its plain type name) — a single-constructor,
/// non-parametric record whose field `f` is not `%1`. Returns `(v, T, slot(f), key of f)`. The
/// caller adds the liveness condition (`v` not mentioned afterwards).
fn field_moveout(
    op: &Op,
    owned: &[(String, Option<String>)],
    recinfo: &RecordInfo,
) -> Option<(String, String, usize, String)> {
    let Op::Field {
        name,
        rec: Atom::Var(src),
    } = op
    else {
        return None;
    };
    let ty = owned
        .iter()
        .find(|(v, _)| v == src)
        .and_then(|(_, k)| k.clone())?;
    if !recinfo.named_field_is_heap(name) {
        return None;
    }
    let (con, slot) = recinfo.named_field_slot(name)?;
    let fkey = recinfo.field_drop_slot(&con, slot)?;
    (recinfo.is_single_con(&con)
        && !recinfo.field_is_owned(&con, slot)
        && recinfo.con_type_name(&con) == Some(ty.as_str()))
    .then(|| (src.clone(), ty, slot, fkey))
}

/// Every `drop v : T skip{…}` in `t` as a skip-destructor seed `(T, slots)` (deduplicated).
fn collect_drop_skips(t: &Term, out: &mut Vec<SkipSeed>) {
    match t {
        Term::Let(_, rhs, _, b) => {
            match rhs {
                Rhs::Op(_) => {}
                Rhs::If(_, th, el) => {
                    collect_drop_skips(th, out);
                    collect_drop_skips(el, out);
                }
                Rhs::Case(_, arms) => arms.iter().for_each(|(_, a)| collect_drop_skips(a, out)),
            }
            collect_drop_skips(b, out);
        }
        Term::Drop(_, Some(ty), skip, _, b) => {
            if !skip.is_empty() && !out.iter().any(|(t, s)| t == ty && s == skip) {
                out.push((ty.clone(), skip.clone()));
            }
            collect_drop_skips(b, out);
        }
        Term::Drop(_, None, _, _, b) => collect_drop_skips(b, out),
        Term::Ret(Rhs::If(_, th, el), _) => {
            collect_drop_skips(th, out);
            collect_drop_skips(el, out);
        }
        Term::Ret(Rhs::Case(_, arms), _) => {
            arms.iter().for_each(|(_, a)| collect_drop_skips(a, out));
        }
        Term::Ret(Rhs::Op(_), _) => {}
    }
}

fn reclaim_cond_escape(
    body: Term,
    owned: Vec<(String, Option<String>)>,
    ba: &BorrowArgs,
    br: &HashMap<String, HashSet<usize>>,
    recinfo: &RecordInfo,
    dty: &HashMap<String, Option<String>>,
) -> Term {
    match body {
        Term::Let(x, rhs, sp, b) => {
            // an owned String/Integer handed out by some arms of a let-bound conditional and dead
            // on the others (`let r = if c then v else ""`): freed on those arms, their literal
            // values copied, and the conditional's result owned from here on
            let (rhs, absorbed) = match rhs {
                Rhs::If(..) | Rhs::Case(..) => absorb_owned_escape(rhs, &b, &owned, br, recinfo),
                other => (other, None),
            };
            let owned: Vec<(String, Option<String>)> = match &absorbed {
                Some((v, _)) => owned.into_iter().filter(|(n, _)| n != v).collect(),
                None => owned,
            };
            // pure alias `let x = ownedParam`, source unused afterwards → transfer to `x`.
            let alias_key = if let Rhs::Op(Op::Atom(Atom::Var(src))) = &rhs {
                (x != *src && !term_mentions_any(&b, &HashSet::from([src.clone()])))
                    .then(|| owned.iter().find(|(v, _)| v == src).map(|(_, k)| k.clone()))
                    .flatten()
            } else {
                None
            };
            // FIELD MOVE-OUT: `let x = field f v` reads a heap field of an owned record `v` that is
            // never mentioned again. The read is then a MOVE: free `v` at once except that slot
            // (`drop v : T skip{slot}` — the shell and the sibling fields), and `x` owns the field
            // from here on (reclaimed where it dies, kept where it escapes). The same per-field
            // move-out an owned `case` scrutinee gets for its extracted fields; without it `v`
            // left the owned set (a `Field` may alias) and its shell leaked — the accumulator
            // `build (k - 1) (Box { items = Cons k (items acc) })`. Single-constructor,
            // non-parametric records only (the skip destructor is keyed by the plain type name).
            // (…or mentioned again only by the drops `insert_drops` placed for it — skip-drops
            // leaving at most this slot, `let v = s (mk k) in if c then v else ""`: those are
            // replaced by the move-out's own drop, and `v` is reclaimed where it is dead)
            let field_moveout = match &rhs {
                Rhs::Op(op) => field_moveout(op, &owned, recinfo).filter(|(src, _, slot, _)| {
                    x != *src
                        && (!term_mentions_any(&b, &HashSet::from([src.clone()]))
                            || only_dropped(&b, src, *slot))
                }),
                _ => None,
            };
            let b = match &field_moveout {
                Some((src, ..)) => Box::new(strip_drops(*b, src)),
                None => b,
            };
            if let Some((src, ty, slot, fkey)) = field_moveout {
                let owned: Vec<_> = owned
                    .into_iter()
                    .filter(|(v, _)| v != &src && v != &x)
                    .chain(std::iter::once((x.clone(), Some(fkey))))
                    .collect();
                let rest = reclaim_cond_escape(*b, owned, ba, br, recinfo, dty);
                return Term::Let(
                    x,
                    rhs,
                    sp,
                    Box::new(Term::Drop(src, Some(ty), vec![slot], sp, Box::new(rest))),
                );
            }
            let mut owned: Vec<_> = owned
                .into_iter()
                .filter(|(v, _)| {
                    if v == &x || rhs_moves(v, &rhs, ba) {
                        return false; // moved/consumed here, or its name rebound
                    }
                    // a conditional whose branches already free v (`insert_drops` dropped it at
                    // its last use inside each branch): it is gone after the `let`, so freeing
                    // it again at a later death point would be a double free.
                    if rhs_drops_var(v, &rhs) {
                        return false;
                    }
                    // a binding that READS v must produce a FRESH value to keep v
                    // reclaimable — a `Field`/`get`/call may return a pointer INTO v (an
                    // escaping interior alias), and dropping v later would free it. A direct
                    // call to a function that returns NO interior alias of its params (absent
                    // from the `borrow_return_summary` `br`) is fresh w.r.t. v, so v (borrowed
                    // by the call — `rhs_moves` was false above) stays owned and is reclaimed at
                    // its death point: the `foldl` accumulator `addI z y` where `addI` returns a
                    // fresh `Integer`.
                    match &rhs {
                        // a field read whose alias is only ever READ by fresh producers (the
                        // by-copy record update's `$updfield = field s p` → `strcat $updfield ""`)
                        // never outlives v's use as a pointer: v stays reclaimable
                        Rhs::Op(Op::Field {
                            rec: Atom::Var(r),
                            name,
                        }) if r == v
                            && (recinfo.named_field_is_scalar(name)
                                || alias_only_read_fresh(&x, &b)) =>
                        {
                            true
                        }
                        // a by-copy update of v whose result is freed later on this path with a
                        // skip-destructor leaving the shared fields to v: v still frees them, so
                        // it stays owned (dropped at the end of the path, after the result)
                        Rhs::Op(Op::UpdateRecord {
                            base: Atom::Var(bv),
                            fields,
                            inplace: false,
                            ..
                        }) if bv == v && {
                            let names: Vec<&str> = fields.iter().map(|(n, _)| n.as_str()).collect();
                            result_skip_dropped(&b, &x, &recinfo.update_shared_fields(&names))
                        } =>
                        {
                            true
                        }
                        Rhs::Op(op) if op_mentions_any(op, &HashSet::from([v.clone()])) => {
                            op_is_fresh_wrt_args(op)
                                || matches!(op, Op::CallDirect(g, _, _) if !br.contains_key(g))
                                // a call that may return a pointer into v, whose result is only
                                // read by fresh producers right away (`snd p > 0`) while v is
                                // still used after: v outlives every read, so it stays owned
                                || matches!(op, Op::CallDirect(..)
                                    if borrow_read_then_dead(&x, v, &b))
                                || matches!(op, Op::UpdateRecord { inplace: false, fields, .. }
                                    if recinfo.update_is_fresh(fields))
                        }
                        _ => true,
                    }
                })
                .collect();
            if let Some((_, key)) = &absorbed {
                owned.push((x.clone(), Some(key.clone()))); // the conditional now yields an owned value
            } else if let Some(key) = alias_key {
                owned.push((x.clone(), key));
            } else if let Rhs::Op(op) = &rhs {
                // A fresh let-bound heap producer (`let s = getEnv…`) that CONDITIONALLY
                // escapes — returned in one `if`/`case` arm, dead in another — must be
                // dropped on the dead paths. `insert_drops` leaves it (it sees the escape
                // and never drops it → the sibling arm is Unbalanced), so seed it here and
                // let the branch-sensitive tail logic reclaim it. Fresh-producer-only, so
                // the result never aliases an arg; if it is consumed/dropped downstream the
                // `Drop`/move handling removes it before any second free.
                // …and a direct call to a user function whose result is keyed and holds no
                // interior alias of its arguments (absent from `br`): a fresh owned value too
                // (`let v = lookupAction km k in if … then v else dflt` left `v` unfreed on the
                // `else` path — refused AX0910 Unbalanced).
                // …and a constructor, a record literal, and a by-copy record update that shares
                // nothing with its base (`let p1 = p { keys = … }`, moved on one path, only read
                // on the other): `op_owned_key` names every such fresh producer.
                if let Some(key) = op_owned_key(op, br, recinfo) {
                    if !owned.iter().any(|(v, _)| v == &x) {
                        owned.push((x.clone(), Some(key)));
                    }
                }
            } else if matches!(&rhs, Rhs::If(..) | Rhs::Case(..)) {
                // A `let x = if/case … in …` whose EVERY arm yields a fresh owned heap value: x is a
                // genuinely-owned temp consumed (unconditionally) downstream, but `insert_drops`
                // never marked it (its producer is a conditional, not a recognized op) → a leak the
                // verifier flags. Seed it here so the tail logic reclaims it at its death point —
                // removing the tail-position workaround for all-heap-arm conditionals (fff's rows).
                // MIXED arms are uniformized to all-owned by `normalize_mixed_cond_lets` (a pre-pass
                // before borrow analysis), so by here they reach `cond_temp_key` as all-heap.
                if let Some(key) =
                    cond_temp_key(&rhs, br, recinfo).or_else(|| moveout_case_key(&rhs, dty))
                {
                    if !owned.iter().any(|(v, _)| v == &x) {
                        owned.push((x.clone(), Some(key)));
                    }
                }
            }
            Term::Let(
                x,
                rhs,
                sp,
                Box::new(reclaim_cond_escape(*b, owned, ba, br, recinfo, dty)),
            )
        }
        Term::Drop(v, k, sk, sp, b) => {
            let owned: Vec<_> = owned.into_iter().filter(|(n, _)| n != &v).collect();
            Term::Drop(
                v,
                k,
                sk,
                sp,
                Box::new(reclaim_cond_escape(*b, owned, ba, br, recinfo, dty)),
            )
        }
        Term::Ret(Rhs::If(c, th, el), sp) => Term::Ret(
            Rhs::If(
                c,
                Box::new(reclaim_cond_escape(
                    *th,
                    owned.clone(),
                    ba,
                    br,
                    recinfo,
                    dty,
                )),
                Box::new(reclaim_cond_escape(*el, owned, ba, br, recinfo, dty)),
            ),
            sp,
        ),
        Term::Ret(Rhs::Case(scrut, arms), sp) => {
            let scrut_name = match &scrut {
                Atom::Var(n) => Some(n.clone()),
                _ => None,
            };
            let scrut_key = scrut_name
                .as_deref()
                .and_then(|s| dty.get(s).cloned().flatten());
            // The arms below skip the scrutinee on the assumption that `insert_drops` frees it. That
            // only holds for a DROPPABLE scrutinee; one owned here escapes on some other path (`bump 0
            // xs = case xs of …` beside `bump k xs = bump (k - 1) xs`), so nobody freed the consumed
            // cell. Free it in each arm, when that is provably right; otherwise leave it as before.
            let scrut_owned_here = scrut_name
                .as_deref()
                .and_then(|s| owned.iter().find(|(v, _)| v == s))
                .is_some();
            // All arms or none: freeing in some arms only would unbalance the paths.
            let arms = match scrut_name.as_deref() {
                Some(s) if scrut_owned_here => {
                    let freed: Option<Vec<(CPat, Term)>> = arms
                        .iter()
                        .map(|(pat, arm)| {
                            free_owned_scrutinee(s, pat, arm.clone(), scrut_key.as_deref(), recinfo)
                                .map(|a| (pat.clone(), a))
                        })
                        .collect();
                    freed.unwrap_or(arms)
                }
                _ => arms,
            };
            let arms = arms
                .into_iter()
                .map(|(pat, arm)| {
                    // exclude the scrutinee (reclaimed by the scrutinee drop) and any
                    // param the pattern re-binds (shadowed).
                    let mut owned_arm: Vec<_> = owned
                        .iter()
                        .filter(|(v, _)| Some(v) != scrut_name.as_ref() && !cpat_binds(&pat, v))
                        .cloned()
                        .collect();
                    // DISCOVER case-extracted OWNED heap elements: when this arm CONSUMES the
                    // scrutinee (shell-frees it), its heap fields are transferred out and owned.
                    // Add each with its resolved CONCRETE element key so the branch-sensitive
                    // logic below frees it on paths where it is DEAD and keeps it where it is
                    // moved out (`filter`/`keepBig`: `y` dropped on the else, kept in `Cons y`).
                    // This is the branch-sensitive twin of the notion-2 pass, which cannot handle
                    // a CONDITIONALLY-moved element (`go`'s borrow-only liveness would drop it
                    // before its move). Poly/scalar elements do not resolve → left (exempt leak).
                    if let (Some(s), CPat::Con(con, subs)) = (scrut_name.as_deref(), &pat) {
                        if arm_shell_frees_scrut(s, &arm) {
                            for (fi, sp) in subs.iter().enumerate() {
                                if let CPat::Var(n) = sp {
                                    if recinfo.field_transfers_heap(con, fi)
                                        && !recinfo.field_is_owned(con, fi)
                                        && !owned_arm.iter().any(|(v, _)| v == n)
                                    {
                                        if let Some(key) =
                                            cond_elem_key(con, fi, scrut_key.as_deref(), recinfo)
                                        {
                                            owned_arm.push((n.clone(), key));
                                        }
                                    }
                                }
                            }
                        }
                    }
                    (
                        pat,
                        reclaim_cond_escape(arm, owned_arm, ba, br, recinfo, dty),
                    )
                })
                .collect();
            Term::Ret(Rhs::Case(scrut, arms), sp)
        }
        Term::Ret(Rhs::Op(op), sp) if field_moveout(&op, &owned, recinfo).is_some() => {
            // a tail `ret field f v` of an owned record: the FIELD MOVE-OUT above in tail form —
            // `let t = field f v; drop v : T skip{slot}; <the other owned die here>; ret t`.
            let tmp = format!(
                "_rcl{}",
                RECL_TMP.fetch_add(1, std::sync::atomic::Ordering::Relaxed)
            );
            let tail = Term::Let(
                tmp.clone(),
                Rhs::Op(op),
                sp,
                Box::new(Term::Ret(Rhs::Op(Op::Atom(Atom::Var(tmp))), sp)),
            );
            reclaim_cond_escape(tail, owned, ba, br, recinfo, dty)
        }
        Term::Ret(Rhs::Op(op), sp) => {
            // An owned param dies at this tail `ret` in one of two ways:
            //   · the op does NOT mention it → dead already → drop BEFORE the ret.
            //   · the op BORROWS it (mentions but does not move it out) and the op's result
            //     is FRESH (does not alias it) → dead AFTER the op runs → synthesize a
            //     post-`ret` drop via a temp: `let t = op; drop v…; ret t`. This closes the
            //     tail-op-borrows-param leak (`ret add t newt`, the Euclid accumulators).
            // A param the op MOVES out escapes (the result), and one a NON-fresh op mentions
            // may be aliased by the result (a `Field`/`get` view) — both are kept (the latter
            // a conservative leak, never a double free).
            let e = crate::delta::op_delta_effect(&op, ba);
            let moved: HashSet<String> = e
                .moves
                .iter()
                .chain(e.alias.iter())
                .filter_map(|a| match a {
                    Atom::Var(v) => Some(v.clone()),
                    _ => None,
                })
                .collect();
            let fresh = op_is_fresh_wrt_args(&op)
                || matches!(&op, Op::UpdateRecord { inplace: false, fields, .. }
                    if recinfo.update_is_fresh(fields));
            let mut before = Vec::new();
            let mut after = Vec::new();
            for (v, key) in owned {
                if !op_mentions_any(&op, &HashSet::from([v.clone()])) {
                    before.push((v, key));
                } else if (fresh || matches!(&op, Op::CallDirect(g, _, _) if !br.contains_key(g)))
                    && !moved.contains(&v)
                {
                    // the op BORROWS v and its result does not alias v (a fresh producer, or a
                    // direct call that returns no param interior — absent from `br`) → v is dead
                    // AFTER the op → reclaim it post-`ret`. Mirrors the let-binding filter above.
                    after.push((v, key));
                }
                // else: escapes (moved) or alias-risk (non-fresh op) → keep, conservative.
            }
            let mut t = if after.is_empty() {
                Term::Ret(Rhs::Op(op), sp)
            } else {
                let tmp = format!(
                    "_rcl{}",
                    RECL_TMP.fetch_add(1, std::sync::atomic::Ordering::Relaxed)
                );
                let mut inner = Term::Ret(Rhs::Op(Op::Atom(Atom::Var(tmp.clone()))), sp);
                for (v, key) in after {
                    inner = Term::Drop(v, key, Vec::new(), sp, Box::new(inner));
                }
                Term::Let(tmp, Rhs::Op(op), sp, Box::new(inner))
            };
            for (v, key) in before {
                t = Term::Drop(v, key, Vec::new(), sp, Box::new(t));
            }
            t
        }
    }
}

/// Frees the owned scrutinee `s` at the head of one `case` arm, for [`reclaim_cond_escape`]. A
/// constructor arm frees only the cell (its heap fields are moved out into the pattern binders, which
/// the caller then reclaims where they are dead); a wildcard arm frees the whole value; an arm that
/// already frees `s` is kept as is. `None` when that is not provably right: the arm still reads `s`,
/// a heap field is unnamed or nested (it would leak or need a skip destructor), or is `%1`-owned.
fn free_owned_scrutinee(
    s: &str,
    pat: &CPat,
    arm: Term,
    key: Option<&str>,
    recinfo: &RecordInfo,
) -> Option<Term> {
    fn frees(s: &str, t: &Term) -> bool {
        match t {
            Term::Drop(v, _, _, _, b) => v == s || frees(s, b),
            Term::Let(_, rhs, _, b) => {
                frees(s, b)
                    || match rhs {
                        Rhs::If(_, x, y) => frees(s, x) || frees(s, y),
                        Rhs::Case(_, arms) => arms.iter().any(|(_, a)| frees(s, a)),
                        Rhs::Op(_) => false,
                    }
            }
            Term::Ret(Rhs::If(_, x, y), _) => frees(s, x) || frees(s, y),
            Term::Ret(Rhs::Case(_, arms), _) => arms.iter().any(|(_, a)| frees(s, a)),
            Term::Ret(_, _) => false,
        }
    }
    // the arm hands the scrutinee on WHOLE (`Just v -> m`): it is the result's, not freed here
    fn returns_whole(s: &str, t: &Term) -> bool {
        let only = HashSet::from([s.to_string()]);
        match t {
            Term::Drop(v, _, _, _, b) => v != s && returns_whole(s, b),
            Term::Let(x, rhs, _, b) => {
                x != s && !rhs_mentions_any(rhs, &only) && returns_whole(s, b)
            }
            Term::Ret(Rhs::Op(Op::Atom(Atom::Var(v))), _) => v == s,
            Term::Ret(Rhs::If(_, x, y), _) => returns_whole(s, x) && returns_whole(s, y),
            Term::Ret(..) => false,
        }
    }
    if frees(s, &arm) || returns_whole(s, &arm) {
        return Some(arm);
    }
    if term_mentions_any(&arm, &HashSet::from([s.to_string()])) {
        return None;
    }
    let drop_key = match pat {
        CPat::Con(con, subs) => {
            let fields_ok = subs.iter().enumerate().all(|(fi, sub)| {
                !recinfo.field_transfers_heap(con, fi)
                    || (matches!(sub, CPat::Var(_)) && !recinfo.field_is_owned(con, fi))
            });
            if !fields_ok {
                return None;
            }
            None // cell only: the heap fields now belong to the binders
        }
        CPat::Wild => Some(key?.to_string()),
        _ => return None,
    };
    let sp = term_span(&arm);
    Some(Term::Drop(
        s.to_string(),
        drop_key,
        Vec::new(),
        sp,
        Box::new(arm),
    ))
}

/// Unique-temp counter for `reclaim_cond_escape`'s post-`ret` drops. Based at 2_000_000 to
/// stay clear of `insert_drops`' 1_000_000 range; global monotonic → no name collisions.
static RECL_TMP: std::sync::atomic::AtomicU32 = std::sync::atomic::AtomicU32::new(2_000_000);

/// `true` if the Core pattern binds `name` (so it shadows an outer binder).
fn cpat_binds(pat: &CPat, name: &str) -> bool {
    match pat {
        CPat::Var(n) => n == name,
        CPat::Con(_, subs) | CPat::Tuple(subs) => subs.iter().any(|p| cpat_binds(p, name)),
        _ => false,
    }
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
                    // R-4 (docs/call-site-ownership.md): a pure rename `let x = src` MOVES an
                    // allocated `src` into `x` (delta annotates it `moves{src}`, so `src` is not
                    // reused afterward). Transfer ownership to `x` so it is droppable — otherwise
                    // `src` is marked escaped (by the alias below) while `x` is never allocated,
                    // so NEITHER is in `drp` and an unused binding leaks (`let x = producer in
                    // body-without-x` → AX0911 rejected). With the transfer, `x` is reclaimed at
                    // its death point (dropped if dead, or dropped by whoever consumes it).
                    if let Op::Atom(Atom::Var(src)) = op {
                        if alloc.contains(src) {
                            alloc.insert(x.clone());
                        }
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

/// A by-copy update `let r = update b {…}` shares b's non-updated heap fields with `r`; the
/// skip-destructors (`collect_update_skips`) make exactly one holder free each. That holder must be
/// the one freed LAST: when `b` is fully freed BEFORE `r`'s skip-drop on the same path
/// (`drop b : Box` … `lenYs r` … `drop r : Box skip{1}`), `r` reads fields `b` already freed. So per
/// shared field slot (linked across a chain of updates — `b1 = b0 {xs}`, `b2 = b1 {ys}`), the
/// holder dropped last frees it and every other holder skips it. Applied only when every holder
/// is dropped (keyed) on this straight path and skips nothing else; otherwise the drops are left as
/// they are (and the verifier, which models the sharing, refuses a wrong order).
fn swap_update_skip_owner(t: &mut Term, recinfo: &RecordInfo) {
    // the chain's updates (result, base, shared field indices) and its drops, in order
    let mut updates: Vec<(String, String, Vec<usize>)> = Vec::new();
    let mut heap_of: HashMap<String, HashSet<usize>> = HashMap::new(); // holder → its heap fields
    let mut drops: Vec<(String, bool, Vec<usize>)> = Vec::new(); // (name, keyed, skip)
    let mut cur: &Term = t;
    loop {
        match cur {
            Term::Let(r, rhs, _, body) => {
                if let Rhs::Op(Op::UpdateRecord {
                    base: Atom::Var(b),
                    fields,
                    inplace: false,
                    ..
                }) = rhs
                {
                    let names: Vec<&str> = fields.iter().map(|(n, _)| n.as_str()).collect();
                    let shared = recinfo.update_shared_fields(&names);
                    if !shared.is_empty() {
                        let heap = recinfo.record_heap_fields(names[0]);
                        heap_of.insert(r.clone(), heap.clone());
                        heap_of.insert(b.clone(), heap);
                        updates.push((r.clone(), b.clone(), shared));
                    }
                }
                cur = body;
            }
            Term::Drop(x, k, skip, _, body) => {
                drops.push((x.clone(), k.is_some(), skip.clone()));
                cur = body;
            }
            Term::Ret(..) => break,
        }
    }
    let mut new_skips: HashMap<String, Vec<usize>> = HashMap::new();
    if !updates.is_empty() {
        // every holder: its shared slots, and its (single, keyed) drop on this path
        let mut slots_of: HashMap<&str, HashSet<usize>> = HashMap::new();
        for (r, b, idxs) in &updates {
            slots_of.entry(r).or_default().extend(idxs);
            slots_of.entry(b).or_default().extend(idxs);
        }
        let drop_at: HashMap<&str, usize> = drops
            .iter()
            .enumerate()
            .filter(|(_, (_, keyed, _))| *keyed)
            .map(|(i, (x, _, _))| (x.as_str(), i))
            .collect();
        // (a skipped SCALAR field is a no-op — Auto-Drop skips every non-updated field — so only
        // the heap entries of a skip have to come from the sharing)
        // A holder not dropped on this path escapes (moved into a call, a structure, returned):
        // whoever receives it frees all it holds, so for every field it shares it is the LAST
        // holder. Holders dropped here must be dropped once, keyed, skipping only shared slots.
        let applicable = drop_at.keys().any(|x| slots_of.contains_key(x))
            && slots_of.iter().all(|(x, slots)| {
                let heap = heap_of.get(*x);
                match drops.iter().filter(|(d, _, _)| d == x).count() {
                    0 => true,
                    1 => {
                        drop_at.contains_key(x)
                            && drops[drop_at[x]]
                                .2
                                .iter()
                                .all(|i| slots.contains(i) || heap.is_some_and(|h| !h.contains(i)))
                    }
                    _ => false,
                }
            });
        if applicable {
            // union-find over (holder, slot): a slot is the same pointer across an update
            let mut parent: HashMap<(String, usize), (String, usize)> = HashMap::new();
            fn find(
                p: &mut HashMap<(String, usize), (String, usize)>,
                k: (String, usize),
            ) -> (String, usize) {
                let next = p.get(&k).cloned().unwrap_or_else(|| k.clone());
                if next == k {
                    return k;
                }
                let root = find(p, next);
                p.insert(k, root.clone());
                root
            }
            for (r, b, idxs) in &updates {
                for &i in idxs {
                    let (ra, rb) = (
                        find(&mut parent, (r.clone(), i)),
                        find(&mut parent, (b.clone(), i)),
                    );
                    if ra != rb {
                        parent.insert(ra, rb);
                    }
                }
            }
            // each class's owner: the holder dropped last
            let mut owner: HashMap<(String, usize), (usize, String)> = HashMap::new();
            for (x, slots) in &slots_of {
                for &i in slots {
                    let root = find(&mut parent, (x.to_string(), i));
                    let at = drop_at.get(x).copied().unwrap_or(usize::MAX);
                    let e = owner.entry(root).or_insert((at, x.to_string()));
                    if at > e.0 {
                        *e = (at, x.to_string());
                    }
                }
            }
            for (x, slots) in &slots_of {
                if !drop_at.contains_key(x) {
                    continue; // an escaping holder: no drop here to rewrite
                }
                let mut skip: Vec<usize> = slots
                    .iter()
                    .copied()
                    .filter(|&i| {
                        let root = find(&mut parent, (x.to_string(), i));
                        owner.get(&root).is_some_and(|(_, o)| o != x)
                    })
                    .collect();
                skip.sort_unstable();
                new_skips.insert(x.to_string(), skip);
            }
        }
    }
    // apply, and recurse into the nested chains of the branches
    let recurse = |rhs: &mut Rhs| match rhs {
        Rhs::If(_, a, b) => {
            swap_update_skip_owner(a, recinfo);
            swap_update_skip_owner(b, recinfo);
        }
        Rhs::Case(_, arms) => {
            for (_, a) in arms {
                swap_update_skip_owner(a, recinfo);
            }
        }
        Rhs::Op(_) => {}
    };
    let mut cur: &mut Term = t;
    loop {
        match cur {
            Term::Let(_, rhs, _, body) => {
                recurse(rhs);
                cur = body;
            }
            Term::Drop(x, _, skip, _, body) => {
                if let Some(new) = new_skips.get(x.as_str()) {
                    *skip = new.clone();
                }
                cur = body;
            }
            Term::Ret(rhs, _) => {
                recurse(rhs);
                break;
            }
        }
    }
}

/// Inserts the `drop`s into a function (structural Drop + cross-function reclamation).
/// `drop_ty` maps each droppable to its `data`-type name (for the deep-drop).
/// Maps a variable to the `(type, non-updated field indices)` skip-destructor that
/// reclaims a by-copy `UpdateRecord` leak-free. A by-copy update shallow-copies: the
/// non-updated fields ALIAS the base while the updated fields are genuinely-owned new
/// values. The shared (non-updated) fields must be freed exactly once — by whichever of
/// {result, base} outlives the other:
///   · result DROPPED-as-whole (`v ∈ drp`)  → the RESULT skip-drops (skip non-updated):
///     it frees its owned new values; the base deep-drops the shared fields.
///   · result ESCAPES (`v ∉ drp`, e.g. `Cons v …`) → the BASE skip-drops (skip
///     non-updated): the shared fields now belong to the escaped result (freed by whatever
///     contains it), and the base frees only the updated fields' OLD values + its shell.
///     Without this the base's deep-drop AND the container's deep-drop of the escaped
///     result both free the shared field → double free.
/// `inplace` updates mutate the base (no copy, no alias). Indices are sorted (the
/// destructor name is order-sensitive — see `gen_skip_destructors` vs `emit_drop`).
fn collect_update_skips(
    t: &Term,
    recinfo: &RecordInfo,
    drp: &HashSet<String>,
) -> HashMap<String, (String, Vec<usize>)> {
    let mut out = HashMap::new();
    fn walk(
        t: &Term,
        recinfo: &RecordInfo,
        drp: &HashSet<String>,
        out: &mut HashMap<String, (String, Vec<usize>)>,
    ) {
        match t {
            Term::Let(
                v,
                Rhs::Op(Op::UpdateRecord {
                    base,
                    fields,
                    inplace: false,
                    ..
                }),
                _,
                body,
            ) => {
                if let Some((name0, _)) = fields.first() {
                    if let (Some((_, all_fields)), Some((con, _))) =
                        (recinfo.field(name0), recinfo.named_field_slot(name0))
                    {
                        if let Some(ty) = recinfo.con_type_name(&con) {
                            let updated: HashSet<usize> = fields
                                .iter()
                                .filter_map(|(n, _)| all_fields.iter().position(|f| f == n))
                                .collect();
                            let mut non_updated: Vec<usize> = (0..all_fields.len())
                                .filter(|i| !updated.contains(i))
                                .collect();
                            non_updated.sort_unstable();
                            // whichever side survives owns (and frees) the shared fields.
                            let owner = if drp.contains(v) {
                                Some(v.clone()) // result dropped as a whole → result skips
                            } else if let Atom::Var(b) = base {
                                drp.contains(b).then(|| b.clone()) // result escaped → base skips
                            } else {
                                None
                            };
                            if let Some(owner) = owner {
                                out.insert(owner, (ty.to_string(), non_updated));
                            }
                        }
                    }
                }
                walk(body, recinfo, drp, out);
            }
            Term::Let(_, rhs, _, body) => {
                walk_rhs(rhs, recinfo, drp, out);
                walk(body, recinfo, drp, out);
            }
            Term::Drop(_, _, _, _, body) => walk(body, recinfo, drp, out),
            // a TAIL by-copy update (`ret p { v = … }`, a closure body owning `p`): the result
            // escapes, so the base — freed after the `ret` — skips the fields it shares with it
            Term::Ret(
                Rhs::Op(Op::UpdateRecord {
                    base: Atom::Var(b),
                    fields,
                    inplace: false,
                    ..
                }),
                _,
            ) if drp.contains(b) && std::env::var_os("AXION_NO_UPDATE_SKIP_FIX").is_none() => {
                if let Some((name0, _)) = fields.first() {
                    if let (Some((_, all_fields)), Some((con, _))) =
                        (recinfo.field(name0), recinfo.named_field_slot(name0))
                    {
                        if let Some(ty) = recinfo.con_type_name(&con) {
                            let mut non_updated: Vec<usize> = (0..all_fields.len())
                                .filter(|i| !fields.iter().any(|(n, _)| &all_fields[*i] == n))
                                .collect();
                            non_updated.sort_unstable();
                            out.insert(b.clone(), (ty.to_string(), non_updated));
                        }
                    }
                }
            }
            Term::Ret(rhs, _) => walk_rhs(rhs, recinfo, drp, out),
        }
    }
    fn walk_rhs(
        rhs: &Rhs,
        recinfo: &RecordInfo,
        drp: &HashSet<String>,
        out: &mut HashMap<String, (String, Vec<usize>)>,
    ) {
        match rhs {
            Rhs::Op(_) => {}
            Rhs::If(_, th, el) => {
                walk(th, recinfo, drp, out);
                walk(el, recinfo, drp, out);
            }
            Rhs::Case(_, arms) => arms.iter().for_each(|(_, b)| walk(b, recinfo, drp, out)),
        }
    }
    walk(t, recinfo, drp, &mut out);
    out
}

/// Regions/lifetimes (§move-out): make a projected heap field of a fresh OWNED local
/// escape by MOVE. When `let d = field <fld> <src>` reads a heap field of a local `src`
/// that this frame deep-drops (`src ∈ drp`) and `d` is subsequently **moved** (returned,
/// embedded into a returned structure, or handed to a consuming callee — anything that
/// transfers ownership out of the frame), `src`'s destructor must NOT free that slot: some
/// other owner now frees `d`. Otherwise the two owners double-free (the `mkGrab n = inner
/// (W {..})` shape — the projected `inner` escapes while the local `W` is deep-dropped).
///
/// The fix reuses the skip-destructor machinery: record `src → (typeName, skip{slot(fld)})`
/// so `drop_target(src)` emits `drop src : T skip{fld_slot}` — freeing the siblings + shell
/// but moving the projected field out, owned. This is the LOCAL-interior dual of
/// `borrow_return_summary` (which handles PARAM-interior borrow-returns): a param alias
/// outlives the frame and stays a borrow, but a fresh LOCAL's field cannot be borrowed past
/// the frame — it must be MOVED out, and its siblings reclaimed here.
///
/// Only fires when `d` is genuinely moved (`body_moves`, Prim-reads excluded): a
/// borrowed-then-dead projection leaves `src` the sole owner, which correctly frees the
/// whole record — no skip.
fn collect_projection_skips(
    t: &Term,
    recinfo: &RecordInfo,
    drp: &HashSet<String>,
    ba: &BorrowArgs,
) -> HashMap<String, (String, Vec<usize>)> {
    use std::collections::BTreeSet;
    let mut acc: HashMap<String, (String, BTreeSet<usize>)> = HashMap::new();
    fn walk(
        t: &Term,
        recinfo: &RecordInfo,
        drp: &HashSet<String>,
        ba: &BorrowArgs,
        acc: &mut HashMap<String, (String, BTreeSet<usize>)>,
    ) {
        match t {
            Term::Let(
                d,
                Rhs::Op(Op::Field {
                    name,
                    rec: Atom::Var(src),
                }),
                _,
                body,
            ) => {
                if drp.contains(src) && recinfo.named_field_is_heap(name) && body_moves(d, body, ba)
                {
                    if let Some((con, slot)) = recinfo.named_field_slot(name) {
                        if let Some(ty) = recinfo.con_type_name(&con) {
                            acc.entry(src.clone())
                                .or_insert_with(|| (ty.to_string(), BTreeSet::new()))
                                .1
                                .insert(slot);
                        }
                    }
                }
                walk(body, recinfo, drp, ba, acc);
            }
            Term::Let(_, rhs, _, body) => {
                walk_rhs(rhs, recinfo, drp, ba, acc);
                walk(body, recinfo, drp, ba, acc);
            }
            Term::Drop(_, _, _, _, body) => walk(body, recinfo, drp, ba, acc),
            // a projected heap field returned directly IS the move-out (the Elab binds it
            // to a temp and deep-drops `src` before the tail — so `src` must skip it).
            Term::Ret(
                Rhs::Op(Op::Field {
                    name,
                    rec: Atom::Var(src),
                }),
                _,
            ) => {
                if drp.contains(src) && recinfo.named_field_is_heap(name) {
                    if let Some((con, slot)) = recinfo.named_field_slot(name) {
                        if let Some(ty) = recinfo.con_type_name(&con) {
                            acc.entry(src.clone())
                                .or_insert_with(|| (ty.to_string(), BTreeSet::new()))
                                .1
                                .insert(slot);
                        }
                    }
                }
            }
            Term::Ret(rhs, _) => walk_rhs(rhs, recinfo, drp, ba, acc),
        }
    }
    fn walk_rhs(
        rhs: &Rhs,
        recinfo: &RecordInfo,
        drp: &HashSet<String>,
        ba: &BorrowArgs,
        acc: &mut HashMap<String, (String, BTreeSet<usize>)>,
    ) {
        match rhs {
            Rhs::Op(_) => {}
            Rhs::If(_, th, el) => {
                walk(th, recinfo, drp, ba, acc);
                walk(el, recinfo, drp, ba, acc);
            }
            Rhs::Case(_, arms) => arms
                .iter()
                .for_each(|(_, b)| walk(b, recinfo, drp, ba, acc)),
        }
    }
    walk(t, recinfo, drp, ba, &mut acc);
    acc.into_iter()
        .map(|(k, (ty, slots))| (k, (ty, slots.into_iter().collect())))
        .collect()
}

/// Regions/lifetimes (§): null the ownership annotation on every `CallDirect` to a
/// BORROW-RETURNING function (one whose result is a pure interior heap alias of a
/// parameter — `grab w = inner w`). Its result is a BORROW, not a fresh allocation, so the
/// caller must not free it; the argument's owner frees it exactly once. Turns the
/// interprocedural field-alias-return from a double free into sound code. The callee's own
/// destructor is unaffected (nulling a call's result key changes only who reclaims THAT
/// result, not the type universe), so the argument's deep-drop still frees the shared field.
fn null_borrow_result_keys(t: &mut Term, borrow_ret: &HashMap<String, HashSet<usize>>) {
    match t {
        Term::Let(_, rhs, _, body) => {
            null_borrow_result_in_rhs(rhs, borrow_ret);
            null_borrow_result_keys(body, borrow_ret);
        }
        Term::Drop(_, _, _, _, body) => null_borrow_result_keys(body, borrow_ret),
        Term::Ret(rhs, _) => null_borrow_result_in_rhs(rhs, borrow_ret),
    }
}

fn null_borrow_result_in_rhs(rhs: &mut Rhs, borrow_ret: &HashMap<String, HashSet<usize>>) {
    match rhs {
        Rhs::Op(Op::CallDirect(g, _, key)) if borrow_ret.contains_key(g) => *key = None,
        Rhs::Op(_) => {}
        Rhs::If(_, th, el) => {
            null_borrow_result_keys(th, borrow_ret);
            null_borrow_result_keys(el, borrow_ret);
        }
        Rhs::Case(_, arms) => {
            for (_, b) in arms {
                null_borrow_result_keys(b, borrow_ret);
            }
        }
    }
}

/// The borrows of a function body and their owners (see `Elab::aliases`). Core names are unique
/// per function, so one forward pass sees every binding before its uses. A borrow that is itself
/// droppable (owned) is not an alias.
fn borrow_aliases(
    body: &Term,
    borrow_ret: &HashMap<String, HashSet<usize>>,
    recinfo: &RecordInfo,
    drp: &HashSet<String>,
) -> HashMap<String, HashSet<String>> {
    fn owners_of(v: &Atom, m: &HashMap<String, HashSet<String>>) -> HashSet<String> {
        match v {
            Atom::Var(n) => {
                let mut o = m.get(n).cloned().unwrap_or_default();
                o.insert(n.clone());
                o
            }
            _ => HashSet::new(),
        }
    }
    fn walk(
        t: &Term,
        br: &HashMap<String, HashSet<usize>>,
        ri: &RecordInfo,
        drp: &HashSet<String>,
        m: &mut HashMap<String, HashSet<String>>,
    ) {
        match t {
            Term::Let(x, rhs, _, k) => {
                // A closure BORROWS its captures (the cell stores their pointers; the lambda
                // reads them on every call): a use of the closure is a use of each capture's
                // owners, so no capture is dropped before the closure's last call. The closure
                // itself may be droppable (its own cell) — it is a borrower all the same.
                if let Rhs::Op(Op::MakeClosure {
                    captures,
                    owns: false,
                    ..
                }) = rhs
                {
                    let o: HashSet<String> =
                        captures.iter().flat_map(|a| owners_of(a, m)).collect();
                    if !o.is_empty() {
                        m.insert(x.clone(), o);
                    }
                } else if let (Rhs::Op(Op::Atom(Atom::Var(y))), true) = (rhs, drp.contains(x)) {
                    // a droppable rename (`let h = g`, R-4) of a borrower — a closure — keeps
                    // its owners: `h` reads the same captures.
                    if let Some(o) = m.get(y).cloned() {
                        m.insert(x.clone(), o);
                    }
                } else if !drp.contains(x) {
                    let owners = match rhs {
                        Rhs::Op(Op::CallDirect(g, args, _)) => br.get(g).map(|ps| {
                            ps.iter()
                                .filter_map(|&i| args.get(i))
                                .flat_map(|a| owners_of(a, m))
                                .collect::<HashSet<_>>()
                        }),
                        Rhs::Op(Op::Field { name, rec }) if ri.named_field_is_heap(name) => {
                            Some(owners_of(rec, m))
                        }
                        Rhs::Op(Op::Atom(Atom::Var(y))) => m.get(y).cloned(),
                        _ => None,
                    };
                    if let Some(o) = owners.filter(|o| !o.is_empty()) {
                        m.insert(x.clone(), o);
                    }
                }
                walk_rhs(rhs, br, ri, drp, m);
                walk(k, br, ri, drp, m);
            }
            Term::Drop(_, _, _, _, k) => walk(k, br, ri, drp, m),
            Term::Ret(rhs, _) => walk_rhs(rhs, br, ri, drp, m),
        }
    }
    fn walk_rhs(
        rhs: &Rhs,
        br: &HashMap<String, HashSet<usize>>,
        ri: &RecordInfo,
        drp: &HashSet<String>,
        m: &mut HashMap<String, HashSet<String>>,
    ) {
        match rhs {
            Rhs::Op(_) => {}
            Rhs::If(_, a, b) => {
                walk(a, br, ri, drp, m);
                walk(b, br, ri, drp, m);
            }
            Rhs::Case(s, arms) => {
                // fields bound out of a borrow point into the same owners
                let owners = match s {
                    Atom::Var(b) => m.get(b).cloned(),
                    _ => None,
                };
                for (p, b) in arms {
                    if let Some(o) = &owners {
                        let mut binders = Vec::new();
                        cpat_binders(p, &mut binders);
                        for n in binders {
                            if !drp.contains(&n) {
                                m.insert(n, o.clone());
                            }
                        }
                    }
                    walk(b, br, ri, drp, m);
                }
            }
        }
    }
    let mut m = HashMap::new();
    walk(body, borrow_ret, recinfo, drp, &mut m);
    m
}

fn cpat_binders(p: &CPat, out: &mut Vec<String>) {
    match p {
        CPat::Var(n) => out.push(n.clone()),
        CPat::Con(_, subs) | CPat::Tuple(subs) => subs.iter().for_each(|s| cpat_binders(s, out)),
        _ => {}
    }
}

/// A `(type_key, skip_slots)` seed for a `data`/record skip-variant destructor.
type SkipSeed = (String, Vec<usize>);
/// A `(tuple_key, arity, skip_slots)` seed for a TUPLE skip-variant destructor.
type TupleSkipSeed = (String, usize, Vec<usize>);

fn insert_drops(
    mut f: CoreFn,
    ba: &BorrowArgs,
    drop_ty: &HashMap<String, Option<String>>,
    recinfo: &RecordInfo,
    borrow_ret: &HashMap<String, HashSet<usize>>,
) -> (CoreFn, Vec<SkipSeed>, Vec<TupleSkipSeed>) {
    let drp = droppable_vars(&f, ba);
    if drp.is_empty() {
        return (f, Vec::new(), Vec::new());
    }
    let aliases = borrow_aliases(&f.body, borrow_ret, recinfo, &drp);
    let mut update_skip = collect_update_skips(&f.body, recinfo, &drp);
    // §move-out: fold in projected-heap-field escapes (a fresh local's field moved out
    // while the local is deep-dropped → the local's destructor skips that slot). Union
    // slots when a var already carries update skips.
    for (src, (ty, slots)) in collect_projection_skips(&f.body, recinfo, &drp, ba) {
        match update_skip.get_mut(&src) {
            Some((_, existing)) => {
                for s in slots {
                    if !existing.contains(&s) {
                        existing.push(s);
                    }
                }
                existing.sort_unstable();
            }
            None => {
                update_skip.insert(src, (ty, slots));
            }
        }
    }
    let mut e = Elab {
        drp,
        aliases,
        tmp: 1_000_000,
        ba,
        drop_ty: drop_ty.clone(),
        recinfo,
        skip_seeds: Vec::new(),
        tuple_skip_seeds: Vec::new(),
        update_skip,
    };
    let body = std::mem::replace(
        &mut f.body,
        Term::Ret(Rhs::Op(Op::Atom(Atom::Int(0))), NO_SPAN),
    );
    let mut body = e.go(body, &HashSet::new());
    // A NEVER-USED owned (`%1`) param is missed by the use-driven insertion above
    // (it drops at a value's last use, and an unused param has none — `consume xs =
    // 0` left `xs` un-dropped → total leak). It is in `drp` (so it does not escape)
    // and absent from the body, so dropping it at the entry reclaims it and cannot
    // double-free. Local `let`-bound droppables are already handled inside `go`.
    for v in &f.owned_params {
        if e.drp.contains(v) && !term_mentions_any(&body, &HashSet::from([v.clone()])) {
            let ty = e.dty(v);
            let sp = term_span(&body);
            body = Term::Drop(v.clone(), ty, Vec::new(), sp, Box::new(body));
        }
    }
    f.body = body;
    (f, e.skip_seeds, e.tuple_skip_seeds)
}

struct Elab<'a> {
    drp: HashSet<String>,
    /// A borrowed value (not itself droppable) → the variables whose memory it points into:
    /// the result of a call to a borrow-returning function (`unboxS b`), a heap field projection,
    /// an alias of either, or a field a `case` binds out of one. A use of the borrow is a use of
    /// its owners, so an owner is dropped only after the borrow's last use (`fv_drop`/`fv_op`).
    aliases: HashMap<String, HashSet<String>>,
    tmp: u32,
    ba: &'a BorrowArgs,
    /// Owned (not borrowed) so `case_arms` can REGISTER the resolved element key of a
    /// consumed-scrutinee heap field it makes droppable (a `case`-pattern binder that
    /// the pre-built map does not cover) — the notion-2 reclamation of `mapFst`'s `t`.
    drop_ty: HashMap<String, Option<String>>,
    recinfo: &'a RecordInfo,
    /// F-3 skip-variant destructors to generate: `(type_key, skip_slots)`.
    /// Populated by `case_arms` for each remainder drop and by `drop_target` for each
    /// by-copy record-update result.
    skip_seeds: Vec<(String, Vec<usize>)>,
    /// TUPLE skip-variant destructors to generate: `(tuple_key, arity, skip_slots)`.
    /// Populated by `case_arms` when a heap TUPLE field is MOVED OUT of an owned tuple
    /// scrutinee — the remaining heap slots are reclaimed by `axion_drop_{key}_skip_{N}`
    /// while the moved-out slot survives (the `uncons`/peel-deconstructor case). Kept
    /// separate from `skip_seeds` because tuples are not registered `type_cons`, so they
    /// need a bespoke generator (`gen_tuple_skip_destructors`) keyed off the mono-key.
    tuple_skip_seeds: Vec<(String, usize, Vec<usize>)>,
    /// By-copy `UpdateRecord` result → `(type, non-updated field indices)`: its drop
    /// reclaims only the genuinely-owned updated heap slots (see `collect_update_skips`).
    update_skip: HashMap<String, (String, Vec<usize>)>,
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
/// `absorb` for a let-bound conditional (see `reclaim_cond_escape`): an owned String/Integer `v`
/// that some arms RETURN (directly, or through a plain alias) and the others do not mention, and
/// that the continuation `b` never mentions. Those other arms get `drop v` and — when their value
/// is a literal — a copy of it, so every arm yields an owned value of `v`'s key. Returns the new
/// conditional and `(v, key)`; the conditional unchanged and `None` when the shape is not this.
fn absorb_owned_escape(
    rhs: Rhs,
    b: &Term,
    owned: &[(String, Option<String>)],
    br: &HashMap<String, HashSet<usize>>,
    recinfo: &RecordInfo,
) -> (Rhs, Option<(String, String)>) {
    fn returns_var(t: &Term, aliases: &mut HashSet<String>) -> bool {
        match t {
            Term::Let(y, Rhs::Op(Op::Atom(Atom::Var(z))), _, body) if aliases.contains(z) => {
                aliases.insert(y.clone());
                returns_var(body, aliases)
            }
            Term::Let(_, Rhs::Op(_), _, body) | Term::Drop(_, _, _, _, body) => {
                returns_var(body, aliases)
            }
            Term::Ret(Rhs::Op(Op::Atom(Atom::Var(w))), _) => aliases.contains(w),
            _ => false,
        }
    }
    let arms: Vec<&Term> = match &rhs {
        Rhs::If(_, a, c) => vec![a, c],
        Rhs::Case(_, arms) => arms.iter().map(|(_, a)| a).collect(),
        Rhs::Op(_) => return (rhs, None),
    };
    let found = owned.iter().find_map(|(v, key)| {
        let key = key.as_deref()?;
        if key != "String" && key != "Integer" {
            return None;
        }
        let set = HashSet::from([v.clone()]);
        if term_mentions_any(b, &set) {
            return None;
        }
        let ret: Vec<bool> = arms
            .iter()
            .map(|a| returns_var(a, &mut HashSet::from([v.clone()])))
            .collect();
        let ok = ret.iter().any(|r| *r)
            && arms
                .iter()
                .zip(&ret)
                .all(|(a, r)| *r || !term_mentions_any(a, &set));
        ok.then(|| (v.clone(), key.to_string()))
    });
    let Some((v, key)) = found else {
        return (rhs, None);
    };
    let set = HashSet::from([v.clone()]);
    let fix = |a: Term| -> Option<Term> {
        if term_mentions_any(&a, &set) {
            return Some(a); // the arm that hands `v` out
        }
        let a = if arm_owned_key(&a, br, recinfo).as_deref() == Some(key.as_str()) {
            a
        } else {
            wrap_tail_copy(a, &key)?
        };
        Some(Term::Drop(
            v.clone(),
            Some(key.clone()),
            Vec::new(),
            NO_SPAN,
            Box::new(a),
        ))
    };
    let new = match rhs.clone() {
        Rhs::If(c, a, e) => match (fix(*a), fix(*e)) {
            (Some(a), Some(e)) => Some(Rhs::If(c, Box::new(a), Box::new(e))),
            _ => None,
        },
        Rhs::Case(sc, arms) => arms
            .into_iter()
            .map(|(p, a)| fix(a).map(|a| (p, a)))
            .collect::<Option<Vec<_>>>()
            .map(|arms| Rhs::Case(sc, arms)),
        Rhs::Op(_) => None,
    };
    match new {
        Some(r) => (r, Some((v, key))),
        None => (rhs, None),
    }
}

/// Is every mention of `v` in `t` a keyed drop of it whose skip is at most `{slot}`?
fn only_dropped(t: &Term, v: &str, slot: usize) -> bool {
    let set = HashSet::from([v.to_string()]);
    let rhs_ok = |r: &Rhs| match r {
        Rhs::Op(op) => !op_mentions_any(op, &set),
        Rhs::If(c, a, b) => {
            !matches!(c, Atom::Var(n) if n == v)
                && only_dropped(a, v, slot)
                && only_dropped(b, v, slot)
        }
        Rhs::Case(sc, arms) => {
            !matches!(sc, Atom::Var(n) if n == v)
                && arms.iter().all(|(_, a)| only_dropped(a, v, slot))
        }
    };
    match t {
        Term::Let(_, r, _, b) => rhs_ok(r) && only_dropped(b, v, slot),
        Term::Drop(y, k, skip, _, b) => {
            (y != v || (k.is_some() && skip.iter().all(|i| *i == slot))) && only_dropped(b, v, slot)
        }
        Term::Ret(r, _) => rhs_ok(r),
    }
}

/// `t` without its drops of `v`.
fn strip_drops(t: Term, v: &str) -> Term {
    let sub = |r: Rhs| match r {
        Rhs::If(c, a, b) => Rhs::If(
            c,
            Box::new(strip_drops(*a, v)),
            Box::new(strip_drops(*b, v)),
        ),
        Rhs::Case(sc, arms) => Rhs::Case(
            sc,
            arms.into_iter()
                .map(|(p, a)| (p, strip_drops(a, v)))
                .collect(),
        ),
        other => other,
    };
    match t {
        Term::Let(x, r, sp, b) => Term::Let(x, sub(r), sp, Box::new(strip_drops(*b, v))),
        Term::Drop(y, _, _, _, b) if y == v => strip_drops(*b, v),
        Term::Drop(y, k, sk, sp, b) => Term::Drop(y, k, sk, sp, Box::new(strip_drops(*b, v))),
        Term::Ret(r, sp) => Term::Ret(sub(r), sp),
    }
}

/// Is `x` freed further down this straight path (not inside a branch) by a keyed drop whose skip
/// covers `shared` — i.e. it leaves those fields to someone else?
fn result_skip_dropped(t: &Term, x: &str, shared: &[usize]) -> bool {
    match t {
        Term::Drop(y, Some(_), skip, _, b) => {
            (y == x && !skip.is_empty() && shared.iter().all(|i| skip.contains(i)))
                || result_skip_dropped(b, x, shared)
        }
        Term::Drop(_, _, _, _, b) | Term::Let(_, _, _, b) => result_skip_dropped(b, x, shared),
        Term::Ret(..) => false,
    }
}

/// `true` if every use of `x` in `t` is an operand of an op whose result cannot alias it
/// (`op_is_fresh_wrt_args`) — `x` is never returned, stored, scrutinized, passed on or dropped.
/// `x` (a value that may point into `v`) is read only by fresh-producing ops in the straight-line
/// `let` prefix of `t`, and `v` is still mentioned after `x`'s last read: whatever frees `v` does
/// so after every read of `x`.
fn borrow_read_then_dead(x: &str, v: &str, t: &Term) -> bool {
    let xs = HashSet::from([x.to_string()]);
    let vs = HashSet::from([v.to_string()]);
    match t {
        _ if !term_mentions_any(t, &xs) => true,
        Term::Let(y, Rhs::Op(op), _, b) => {
            if y == x || y == v || (op_mentions_any(op, &xs) && !op_is_fresh_wrt_args(op)) {
                return false;
            }
            if term_mentions_any(b, &xs) {
                borrow_read_then_dead(x, v, b)
            } else {
                term_mentions_any(b, &vs)
            }
        }
        Term::Drop(y, _, _, _, b) => y != x && y != v && borrow_read_then_dead(x, v, b),
        _ => false,
    }
}

fn alias_only_read_fresh(x: &str, t: &Term) -> bool {
    let set = HashSet::from([x.to_string()]);
    let op_ok = |op: &Op| !op_mentions_any(op, &set) || op_is_fresh_wrt_args(op);
    let rhs_ok = |r: &Rhs| match r {
        Rhs::Op(op) => op_ok(op),
        Rhs::If(c, a, b) => {
            !matches!(c, Atom::Var(n) if n == x)
                && alias_only_read_fresh(x, a)
                && alias_only_read_fresh(x, b)
        }
        Rhs::Case(sc, arms) => {
            !matches!(sc, Atom::Var(n) if n == x)
                && arms.iter().all(|(_, a)| alias_only_read_fresh(x, a))
        }
    };
    match t {
        Term::Let(y, r, _, b) => rhs_ok(r) && (y == x || alias_only_read_fresh(x, b)),
        Term::Drop(y, _, _, _, b) => y != x && alias_only_read_fresh(x, b),
        Term::Ret(r, _) => rhs_ok(r),
    }
}

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
pub fn term_mentions_any(t: &Term, set: &HashSet<String>) -> bool {
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

/// `true` if `v` is read via a HEAP-field projection (`field <heapfield> v`) anywhere in
/// `t` — the one borrow position that yields an INTERIOR ALIAS of `v` (the result points
/// into `v`'s payload, e.g. `inner y`), so `v` is NOT dead after it and must not be dropped.
/// A SCALAR-field read (`field v h`, `v :: Int`) is a value copy (safe), and every other
/// use of `v` in a borrow position (bignum/string readers) yields a fresh value.
fn reads_heap_field(v: &str, t: &Term, recinfo: &RecordInfo) -> bool {
    fn op_reads(v: &str, op: &Op, recinfo: &RecordInfo) -> bool {
        matches!(op, Op::Field { name, rec: Atom::Var(r) } if r == v && recinfo.named_field_is_heap(name))
    }
    fn in_rhs(v: &str, rhs: &Rhs, recinfo: &RecordInfo) -> bool {
        match rhs {
            Rhs::Op(op) => op_reads(v, op, recinfo),
            Rhs::If(_, a, b) => reads_heap_field(v, a, recinfo) || reads_heap_field(v, b, recinfo),
            Rhs::Case(_, arms) => arms.iter().any(|(_, b)| reads_heap_field(v, b, recinfo)),
        }
    }
    match t {
        Term::Let(_, rhs, _, body) => in_rhs(v, rhs, recinfo) || reads_heap_field(v, body, recinfo),
        Term::Drop(_, _, _, _, body) => reads_heap_field(v, body, recinfo),
        Term::Ret(rhs, _) => in_rhs(v, rhs, recinfo),
    }
}

/// `true` if `n` is used as the SCRUTINEE of a `case` anywhere in `t` (`case n of …`).
/// A heap field flowing into an inner `case` is CONSUMED by it (the inner case
/// deep/shell-frees the value + moves its fields out), so — for a consumed outer
/// scrutinee — that field must be owned/droppable for the inner case to reclaim it
/// (`mapFst`'s `t`). See the notion-2 pass in `case_arms`.
fn flows_into_inner_case(n: &str, t: &Term) -> bool {
    fn in_rhs(n: &str, rhs: &Rhs) -> bool {
        match rhs {
            Rhs::Op(_) => false,
            Rhs::If(_, a, b) => flows_into_inner_case(n, a) || flows_into_inner_case(n, b),
            Rhs::Case(scrut, arms) => {
                matches!(scrut, Atom::Var(s) if s == n)
                    || arms.iter().any(|(_, b)| flows_into_inner_case(n, b))
            }
        }
    }
    match t {
        Term::Let(_, rhs, _, body) => in_rhs(n, rhs) || flows_into_inner_case(n, body),
        Term::Drop(_, _, _, _, body) => flows_into_inner_case(n, body),
        Term::Ret(rhs, _) => in_rhs(n, rhs),
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
    /// `fv_drop`, with each free borrow (`aliases`) counted as a use of its droppable owners.
    fn fv_drop(&self, t: &Term, out: &mut HashSet<String>) {
        if self.aliases.is_empty() {
            return fv_drop(t, &self.drp, self.ba, out);
        }
        let mut wide = self.drp.clone();
        wide.extend(self.aliases.keys().cloned());
        let mut raw = HashSet::new();
        fv_drop(t, &wide, self.ba, &mut raw);
        self.expand_borrows(raw, out);
    }

    /// `fv_op`, with each borrow it reads counted as a use of its droppable owners.
    fn fv_op(&self, op: &Op, out: &mut HashSet<String>) {
        if self.aliases.is_empty() {
            return fv_op(op, &self.drp, self.ba, out);
        }
        let mut wide = self.drp.clone();
        wide.extend(self.aliases.keys().cloned());
        let mut raw = HashSet::new();
        fv_op(op, &wide, self.ba, &mut raw);
        self.expand_borrows(raw, out);
    }

    fn expand_borrows(&self, raw: HashSet<String>, out: &mut HashSet<String>) {
        for v in raw {
            if let Some(owners) = self.aliases.get(&v) {
                out.extend(owners.iter().filter(|o| self.drp.contains(*o)).cloned());
            }
            if self.drp.contains(&v) {
                out.insert(v);
            }
        }
    }

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

    /// The `(type_key, skip_slots)` for dropping `v`. A by-copy record-update RESULT is
    /// reclaimed by a skip-destructor (`axion_drop_T_skip_N`) that frees only its owned
    /// updated heap slots — the non-updated fields alias the base and are freed by the
    /// base's own drop. Seeds the skip-destructor's generation. Any other value uses its
    /// plain deep/flat destructor. (An empty skip = every field updated, so the whole
    /// value is genuinely owned → its normal deep destructor.)
    fn drop_target(&mut self, v: &str) -> (Option<String>, Vec<usize>) {
        if let Some((ty, skip)) = self.update_skip.get(v) {
            let (ty, skip) = (ty.clone(), skip.clone());
            if !skip.is_empty() {
                self.skip_seeds.push((ty.clone(), skip.clone()));
                return (Some(ty), skip);
            }
            return (Some(ty), Vec::new());
        }
        (self.dty(v), Vec::new())
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
        self.place_deep_drop_skip(t, s, ty, alias, &[])
    }

    /// [`place_deep_drop`] carrying a SKIP set: the scrutinee drop routes to the
    /// skip-variant destructor (`axion_drop_T_skip_N`), reclaiming every heap slot except
    /// the moved-out ones. Placed at each tail exit (after the body's last read), so a
    /// borrowed-then-dead sibling is freed only once its last use has run.
    fn place_deep_drop_skip(
        &mut self,
        t: Term,
        s: &str,
        ty: &Option<String>,
        alias: &HashSet<String>,
        skip: &[usize],
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
                                skip.to_vec(),
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
                            skip.to_vec(),
                            sp,
                            Box::new(Term::Ret(Rhs::Op(op), sp)),
                        )
                    }
                }
                // the exits live in the branches → recurse into each.
                Rhs::If(c, th, el) => {
                    let th = self.place_deep_drop_skip(*th, s, ty, alias, skip);
                    let el = self.place_deep_drop_skip(*el, s, ty, alias, skip);
                    Term::Ret(Rhs::If(c, Box::new(th), Box::new(el)), sp)
                }
                Rhs::Case(sc, arms) => {
                    let arms = arms
                        .into_iter()
                        .map(|(p, b)| (p, self.place_deep_drop_skip(b, s, ty, alias, skip)))
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
                Box::new(self.place_deep_drop_skip(*body, s, ty, alias, skip)),
            ),
            Term::Drop(v, ty2, _, _, body) => Term::Drop(
                v,
                ty2,
                Vec::new(),
                sp,
                Box::new(self.place_deep_drop_skip(*body, s, ty, alias, skip)),
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
                    self.fv_op(&op, &mut u);
                    let dying: Vec<String> =
                        u.into_iter().filter(|v| !live_out.contains(v)).collect();
                    if dying.is_empty() {
                        return Term::Ret(Rhs::Op(op), sp);
                    }
                    // introduces a temporary, frees the dying ones, returns it
                    let tmp = self.fresh();
                    let mut inner = Term::Ret(Rhs::Op(Op::Atom(Atom::Var(tmp.clone()))), sp);
                    for v in dying {
                        let (ty, skip) = self.drop_target(&v);
                        inner = Term::Drop(v, ty, skip, term_span(&inner), Box::new(inner));
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
                    self.fv_drop(&body, &mut fvb);
                    let body2 = self.go(*body, live_out);
                    let mut u = HashSet::new();
                    self.fv_op(&op, &mut u);
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
                        let (ty, skip) = self.drop_target(&v);
                        inner = Term::Drop(v, ty, skip, term_span(&inner), Box::new(inner));
                    }
                    Term::Let(x, Rhs::Op(op), sp, Box::new(inner))
                }
                Rhs::If(c, th, el) => {
                    let mut fvb = HashSet::new();
                    self.fv_drop(&body, &mut fvb);
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
                    self.fv_drop(&body, &mut fvb);
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
        self.fv_drop(&th, &mut fth);
        let mut fel = HashSet::new();
        self.fv_drop(&el, &mut fel);
        let mut th2 = self.go(th, live_out);
        let mut el2 = self.go(el, live_out);
        for v in fth.difference(&fel) {
            if !live_out.contains(v) {
                let sp = term_span(&el2);
                let (ty, skip) = self.drop_target(v);
                el2 = Term::Drop(v.clone(), ty, skip, sp, Box::new(el2));
            }
        }
        for v in fel.difference(&fth) {
            if !live_out.contains(v) {
                let sp = term_span(&th2);
                let (ty, skip) = self.drop_target(v);
                th2 = Term::Drop(v.clone(), ty, skip, sp, Box::new(th2));
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
            .map(|(p, b)| {
                let mut s = HashSet::new();
                self.fv_drop(b, &mut s);
                // the arm's own binders are not free in it (see `fv_rhs_in`)
                let mut binders = Vec::new();
                cpat_binders(p, &mut binders);
                for n in binders {
                    s.remove(&n);
                }
                s
            })
            .collect();
        let mut union: HashSet<String> = fvs.iter().flatten().cloned().collect();
        // a `case` on a borrow uses its owners: an arm that does not use them again frees them
        // at its head (the balancing below), like any droppable another arm still reads.
        if let Atom::Var(b) = scrut {
            if let Some(owners) = self.aliases.get(b) {
                union.extend(
                    owners
                        .iter()
                        .filter(|o| self.drp.contains(*o) && !live_out.contains(*o))
                        .cloned(),
                );
            }
        }

        let scrut_drop = match scrut {
            Atom::Var(n) if self.drp.contains(n) && !live_out.contains(n) => Some(n.clone()),
            _ => None,
        };

        let mut out = Vec::with_capacity(arms.len());
        for (i, (pat, body)) in arms.into_iter().enumerate() {
            let info = &infos[i];
            // A VIEW arm: one that reads its scrutinee again as a whole value (a fall-through to a
            // catch-all row of a compiled nested pattern, or `Cons s rest -> … length xs`). It
            // must not consume the scrutinee at its head, so its pattern binders are views of the
            // scrutinee (never freed or made droppable here) and the scrutinee stays an ordinary
            // live value that `go` frees where it dies in the arm. Moving a view out would be
            // caught by the drop-balance verifier.
            let view_arm = scrut_drop.as_ref().is_some_and(|s| fvs[i].contains(s));

            // make %1-heap binders droppable; collect unused ones for pre-drop
            let mut unused = Vec::new();
            if let (CPat::Con(con, subs), false) = (&pat, view_arm) {
                for (fi, sp) in subs.iter().enumerate() {
                    if let CPat::Var(n) = sp {
                        if self.recinfo.field_is_owned(con, fi)
                            && self.recinfo.field_transfers_heap(con, fi)
                        {
                            self.drp.insert(n.clone());
                            if !term_mentions_any(&body, &[n.clone()].into_iter().collect()) {
                                let key = self.recinfo.field_drop_slot(con, fi);
                                unused.push((n.clone(), key));
                            }
                        }
                    }
                }
            }

            // notion-2: a heap field of a CONSUMED scrutinee that is used but NOT moved out
            // is reclaimed by NOTHING today, so make it droppable (with its resolved concrete
            // element key) and let `go` / the inner case reclaim it at its death point. Two
            // shapes, both currently leaked or mis-dropped:
            //   · BORROWED-then-dead — read via a `Field`/borrowing call then dead (`sumV xs =
            //     case xs of Cons h t -> v h + sumV t`). Auto-Drop must drop `h` AFTER the
            //     read; the scrutinee `Inline` drop instead frees it BEFORE → `UseAfterFree`.
            //   · CONSUMED-BY-INNER-`case` (`mapFst`'s `t = case t of (a,b) -> …`). The outer
            //     drop excludes it (it "escaped" into the inner case) and the inner case can
            //     only free it once owned.
            // A field MOVED into the result or a consuming call (`occurs_nonborrow` but not an
            // inner-`case` scrutinee) escapes — it is NOT made droppable (the result/callee
            // owns it). Unmentioned dead discards stay with the scrutinee drop. So this never
            // double-frees.
            //
            // GUARD: only when the scrutinee drop is NON-deep (`Inline`/`Shallow`, i.e. the
            // arm is NOT `deep_safe`). A `deep_safe` arm deep-drops the WHOLE scrutinee
            // (`axion_drop_List$P`), reclaiming every element — making the element droppable
            // too would double-free it (`firstOr xs = case xs of Cons y ys -> a y`, tail
            // ignored → whole-list deep drop). The non-deep paths (a spine escapes, or a heap
            // result) shell-free the scrutinee and leave the element for us.
            let deep_safe0 = !info.non_owning && !result_may_be_heap(&body, self.recinfo);
            if let (false, false, Some(_), CPat::Con(con, subs), Atom::Var(sname)) =
                (deep_safe0, view_arm, &scrut_drop, &pat, scrut)
            {
                for (fi, sp) in subs.iter().enumerate() {
                    if let CPat::Var(n) = sp {
                        let mentioned = term_mentions_any(&body, &HashSet::from([n.clone()]));
                        // borrowed-then-dead: used but never MOVED out (a borrowing call like
                        // `addI z y` is not a move — `body_moves_var` is `ba`-aware, unlike the
                        // syntactic `occurs_nonborrow` which counts every call arg as an escape),
                        // AND not read via a heap-field projection (which would return an interior
                        // alias of `n`, so `n` is not dead — the `firstInner`/`grab` class).
                        let borrowed_dead = mentioned
                            && !body_moves_var(n, &body, self.ba)
                            && !reads_heap_field(n, &body, self.recinfo);
                        if self.recinfo.field_transfers_heap(con, fi)
                            && !self.recinfo.field_is_owned(con, fi)
                            && !self.drp.contains(n)
                            && (borrowed_dead || flows_into_inner_case(n, &body))
                        {
                            if let Some(key) = self.consumed_elem_key(con, fi, sname) {
                                self.drp.insert(n.clone());
                                self.drop_ty.insert(n.clone(), key);
                            }
                        }
                    }
                }
            }

            // notion-2 for a TUPLE scrutinee: a BORROWED-then-dead heap tuple FIELD (`getFst t =
            // case t of (a,b) -> a + b` — `a`/`b` are read by `+` then dead) is reclaimed by
            // NOTHING (`tuple_discard_drops` frees only the UNMENTIONED fields + shell). Make it
            // droppable with its element key from the tuple mono-key so `go` frees it at its
            // death point. Same guards as the `Con` case: only non-`deep_safe`, borrowed (not
            // moved out), not a heap-field interior alias; scalar/poly fields resolve to no-drop.
            if let (false, false, Some(_), CPat::Tuple(subs), Atom::Var(sname)) =
                (deep_safe0, view_arm, &scrut_drop, &pat, scrut)
            {
                if let Some(keys) = self
                    .dty(sname)
                    .and_then(|k| self.recinfo.tuple_elem_drops(&k, subs.len()))
                {
                    for (fi, sp) in subs.iter().enumerate() {
                        if let CPat::Var(n) = sp {
                            let mentioned = term_mentions_any(&body, &HashSet::from([n.clone()]));
                            let borrowed_dead = mentioned
                                && !body_moves_var(n, &body, self.ba)
                                && !reads_heap_field(n, &body, self.recinfo);
                            if borrowed_dead && !self.drp.contains(n) {
                                if let Some(Some(key)) = keys.get(fi) {
                                    self.drp.insert(n.clone());
                                    self.drop_ty.insert(n.clone(), key.clone());
                                }
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
            let mut mentioned_slots: HashSet<usize> = HashSet::new();
            if let CPat::Con(con, subs) = &pat {
                for (fi, sp) in subs.iter().enumerate() {
                    if let CPat::Var(n) = sp {
                        if self.recinfo.field_transfers_heap(con, fi)
                            && !self.recinfo.field_is_owned(con, fi)
                            && term_mentions_any(&body, &HashSet::from([n.clone()]))
                        {
                            mentioned_heap.insert(n.clone());
                            mentioned_slots.insert(fi);
                        }
                    }
                }
            }
            // Same for a TUPLE scrutinee: a heap tuple field that is USED in the body must be
            // in the alias set so the whole-tuple deep-drop is ordered AFTER the body's last
            // read (`case p of (x, _) -> putStrLn x` — `x` is borrowed by the print, then the
            // tuple frees it). Without this the `Con`-only pass left the alias set empty and the
            // `Deep` path dropped the tuple BEFORE the read — the `uncons`/peel use-after-free.
            if let (CPat::Tuple(subs), Atom::Var(sn)) = (&pat, scrut) {
                if let Some(elems) = self
                    .dty(sn)
                    .and_then(|k| self.recinfo.tuple_elem_drops(&k, subs.len()))
                {
                    for (fi, sp) in subs.iter().enumerate() {
                        if let CPat::Var(n) = sp {
                            if elems.get(fi).is_some_and(Option::is_some)
                                && term_mentions_any(&body, &HashSet::from([n.clone()]))
                            {
                                mentioned_heap.insert(n.clone());
                                mentioned_slots.insert(fi);
                            }
                        }
                    }
                }
            }
            let mut b = self.go(body, live_out);
            for (n, key) in unused {
                b = Term::Drop(n, key, Vec::new(), term_span(&b), Box::new(b));
            }

            if let (Some(s), false) = (&scrut_drop, view_arm) {
                let deep_safe = !info.non_owning && !result_heap;
                // MOVED-OUT heap TUPLE field over an OWNED tuple whose arm result is NON-heap
                // (`deep_safe`, so the fallthrough would `Deep`-drop the WHOLE tuple, freeing the
                // moved-out element → the `uncons`/peel-deconstructor use-after-free: `case p of
                // (x, _) -> putStrLn x` deep-drops `p`, whose destructor `axion_str_drop`s slot 0
                // — the very `x` that escaped into `putStrLn`). Route to a tuple skip-destructor
                // that frees only the REMAINING heap slots (the discarded tail / wildcard sibling)
                // and keeps the moved-out slot alive. `notion-2` does not fire on a `deep_safe`
                // tuple (its guard is `!deep_safe0`), so nothing else drops these slots — no
                // double-free. Placed at the tail so a borrowed-then-dead sibling frees after its
                // last read.
                let tuple_moveout: Option<(String, usize, Vec<usize>)> =
                    if let (true, CPat::Tuple(subs)) = (deep_safe, &pat) {
                        self.dty(s)
                            .and_then(|key| {
                                self.recinfo
                                    .tuple_elem_drops(&key, subs.len())
                                    .map(|elems| {
                                        let skip: Vec<usize> = subs
                                            .iter()
                                            .enumerate()
                                            .filter_map(|(i, sp)| match sp {
                                                CPat::Var(n)
                                                    if elems
                                                        .get(i)
                                                        .is_some_and(Option::is_some)
                                                        && body_moves_var(n, &b, self.ba) =>
                                                {
                                                    Some(i)
                                                }
                                                _ => None,
                                            })
                                            .collect();
                                        (key, subs.len(), skip)
                                    })
                            })
                            .filter(|(_, _, skip)| !skip.is_empty())
                    } else {
                        None
                    };
                // A `%1`-consumed TUPLE scrutinee whose result IS heap (`!deep_safe`): a
                // field escaped into the result, so the whole-tuple deep-drop of the `Deep`
                // path would double-free it. The per-field paths key off `CPat::Con`, so
                // handle the tuple here — free each dead-discarded heap element (from the
                // tuple mono-key) then shell-free the cell, closing the tuple-discard leak.
                // The `deep_safe` tuple case (nothing escapes into a heap result) falls
                // through to `Deep`, which reclaims the whole tuple correctly.
                if let Some((key, arity, skip)) = tuple_moveout {
                    self.tuple_skip_seeds
                        .push((key.clone(), arity, skip.clone()));
                    // keep the moved-out (skipped) bindings in the alias set so the tail op is
                    // computed before the drop when it references one (they survive regardless).
                    let mut alias = HashSet::from([s.clone()]);
                    if let CPat::Tuple(subs) = &pat {
                        for &i in &skip {
                            if let Some(CPat::Var(n)) = subs.get(i) {
                                alias.insert(n.clone());
                            }
                        }
                    }
                    self.collect_payload_aliases(&b, &mut alias);
                    b = self.place_deep_drop_skip(b, s, &Some(key), &alias, &skip);
                } else if let (false, CPat::Tuple(subs), Some(key)) = (deep_safe, &pat, self.dty(s))
                {
                    // A `%1`-consumed TUPLE whose arm result IS heap: a field escaped into the
                    // result, so a whole-tuple deep-drop would double-free it. Reclaim via a
                    // skip-destructor that SKIPS every MENTIONED slot — those either escaped
                    // (survive), were moved into a consuming call (freed by the callee), or are
                    // borrowed-then-dead (freed by `go`/notion-2) — and frees the rest: the
                    // UNMENTIONED heap siblings, INCLUDING a wildcard `_` discard that
                    // `tuple_discard_drops` left leaking (`firstOr xs = … (x, _) -> x`), plus the
                    // shell. Falls back to a plain shell `axion_free` when all heap slots are
                    // skipped (`emit_drop`).
                    //
                    // GUARD: only when the tuple mono-key is SEGMENTABLE (`tuple_elem_drops` Some).
                    // A NESTED-tuple key (`tuple$tuple$String$String$…`) is ambiguous — its inner
                    // arities are not encoded — so neither this skip-destructor nor `mentioned_slots`
                    // can be computed, and an empty skip would deep-drop the WHOLE tuple, freeing a
                    // field that escaped into the heap result (`useB t = case t of (a,b) -> a` over a
                    // nested tuple → UAF). For that case shell-free the outer cell only: the escaping
                    // field survives and any non-escaping heap siblings LEAK (sound — the documented
                    // nested-tuple-in-tuple residual; a leak, never a double-free).
                    if self.recinfo.tuple_elem_drops(&key, subs.len()).is_some() {
                        let skip: Vec<usize> = mentioned_slots.iter().copied().collect();
                        self.tuple_skip_seeds
                            .push((key.clone(), subs.len(), skip.clone()));
                        b = Term::Drop(s.clone(), Some(key), skip, term_span(&b), Box::new(b));
                    } else {
                        // Unparseable nested-tuple key. Only a MENTIONED field can escape into the
                        // heap result (or flow into an inner `case`); a deep-drop of the whole tuple
                        // would then free it → UAF. Shell-free only in that case (escaping field
                        // survives, unclassifiable siblings LEAK — sound). With NO field mentioned
                        // (all dead discards) the whole-tuple deep-drop is correct and frees the
                        // nested inners, so keep it — no needless leak.
                        let any_mentioned = subs.iter().any(|sp| {
                            matches!(sp, CPat::Var(n)
                                if term_mentions_any(&b, &HashSet::from([n.clone()])))
                        });
                        if any_mentioned {
                            b = Term::Drop(s.clone(), None, Vec::new(), term_span(&b), Box::new(b));
                        } else {
                            let ty = self.dty(s);
                            let mut alias = HashSet::from([s.clone()]);
                            self.collect_payload_aliases(&b, &mut alias);
                            b = self.place_deep_drop(b, s, &ty, &alias);
                        }
                    }
                } else if let (false, CPat::Tuple(subs)) = (deep_safe, &pat) {
                    b = self.tuple_discard_drops(b, subs, s);
                    b = Term::Drop(s.clone(), None, Vec::new(), term_span(&b), Box::new(b));
                } else {
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
                                // Skip every MENTIONED heap field, not only the escaping (`non_own`)
                                // ones: a mentioned field is either moved out (escapes), reclaimed
                                // by `go`/the inner case (notion-2, now in `drp`), or a borrowed-
                                // then-dead conservative leak — dropping it here (before the body
                                // that USES it) is the `sumV` `UseAfterFree`. Only UNMENTIONED dead
                                // discards are reclaimed by the scrutinee drop. (Matches `Shallow`.)
                                let skip: HashSet<usize> =
                                    non_own.union(&mentioned_slots).copied().collect();
                                // shell-free the cell FIRST in construction so it runs LAST — a
                                // wildcard-discarded heap field is reclaimed via `loadraw s+off`,
                                // which must read `s` while it is still live. Building the shell
                                // drop innermost puts the loads (and their drops) ahead of it in
                                // execution order (the `grabBox`/case-extraction-escape UAF).
                                b = Term::Drop(
                                    s.clone(),
                                    None,
                                    Vec::new(),
                                    term_span(&b),
                                    Box::new(b),
                                );
                                b = Self::emit_per_field_drops(b, con, subs, s, &skip, self);
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
                                // same ordering as `Inline`: shell-free constructed innermost so
                                // it runs after any `loadraw s+off` of a wildcard-discarded field.
                                b = Term::Drop(
                                    s.clone(),
                                    None,
                                    Vec::new(),
                                    term_span(&b),
                                    Box::new(b),
                                );
                                b = Self::emit_per_field_drops(b, con, subs, s, &skip, self);
                            } else if matches!(pat, CPat::Wild | CPat::Int(_)) {
                                // an arm that binds nothing (and, not being a view arm, does
                                // not read the scrutinee): no part of it escaped, so free it
                                // WHOLE with its key — a shell free leaked its payloads (the
                                // `String` of a `Maybe String` in a `_ -> "z"` arm)
                                let ty = self.dty(s);
                                b = self.place_deep_drop(b, s, &ty, &alias);
                            } else {
                                b = Term::Drop(
                                    s.clone(),
                                    None,
                                    Vec::new(),
                                    term_span(&b),
                                    Box::new(b),
                                );
                            }
                        }
                    }
                }
            }

            for v in union.difference(&fvs[i]) {
                // the scrutinee is reclaimed by this arm's scrutinee drop above (another arm reading
                // it whole — a view arm — does not make it a plain droppable to free here too)
                if !live_out.contains(v) && scrut_drop.as_ref() != Some(v) {
                    let sp = term_span(&b);
                    let (ty, skip) = self.drop_target(v);
                    b = Term::Drop(v.clone(), ty, skip, sp, Box::new(b));
                }
            }
            out.push((pat, b));
        }
        out
    }

    /// The concrete drop key of a heap field `fi` of `con` extracted from a consumed
    /// scrutinee `scrut` (mono key `dty(scrut)`), for the notion-2 reclamation. Outer
    /// `None` = do NOT make it droppable (a scalar/shallow-data/unresolvable element —
    /// leave the prior behaviour, never a wrong free); `Some(key)` = make it droppable
    /// with `key` (`Some("Integer")`/tuple/nested-container mono / deep-data destructor).
    fn consumed_elem_key(&self, con: &str, fi: usize, scrut: &str) -> Option<Option<String>> {
        // a concrete `data`-typed field carries its own destructor key; for the
        // recursive SPINE of a parametric container resolve to the scrutinee's mono key.
        if let Some(k) = self.recinfo.field_drop_slot(con, fi) {
            return Some(match self.dty(scrut) {
                Some(sk) if sk.contains('$') && sk.split('$').next() == Some(k.as_str()) => {
                    Some(sk)
                }
                _ => Some(k),
            });
        }
        // polymorphic field: resolve the field's own type PARAMETER to the matching argument of
        // the scrutinee's instantiation (multi-param-correct: `Left`'s field of
        // `Either$Integer$String` → arg 0 = Integer), then classify. Scalar/shallow/unknown bail.
        let sk = self.dty(scrut)?;
        self.recinfo.poly_field_elem_key(con, fi, &sk)
    }

    /// Frees the DISCARDED heap elements of a `%1`-consumed TUPLE scrutinee `s`,
    /// before the already-elaborated arm body `b`. An element MENTIONED in the body
    /// (moved into the result or borrowed by it) is skipped — it is owned by the
    /// result, or a narrower borrowed-then-dead residual; only a completely-unused
    /// element is a dead discard freed here. Keys come from the tuple mono-key
    /// (`tuple$Integer$Integer`); a non-flat/nested tuple bails (shell-only free —
    /// the prior conservative tuple-discard leak). The tuple SHELL is freed by the
    /// caller (the `Term::Drop(s, None, …)` this wraps).
    fn tuple_discard_drops(&self, b: Term, subs: &[CPat], s: &str) -> Term {
        let Some(key) = self.dty(s) else {
            return b;
        };
        let Some(elems) = self.recinfo.tuple_elem_drops(&key, subs.len()) else {
            return b;
        };
        let mentioned: HashSet<String> = subs
            .iter()
            .filter_map(|p| match p {
                CPat::Var(n) if term_mentions_any(&b, &HashSet::from([n.clone()])) => {
                    Some(n.clone())
                }
                _ => None,
            })
            .collect();
        let mut b = b;
        for (i, sp) in subs.iter().enumerate() {
            let CPat::Var(n) = sp else { continue };
            if mentioned.contains(n) {
                continue; // used by the body → not a dead discard
            }
            if let Some(Some(k)) = elems.get(i) {
                b = Term::Drop(n.clone(), k.clone(), Vec::new(), term_span(&b), Box::new(b));
            }
        }
        b
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
            let key = if let Some(k) = elab.recinfo.field_drop_slot(con, fi) {
                // concrete `data`-typed field → its own destructor. For the RECURSIVE
                // SPINE of a parametric container (`Lst a` inside a `Lst Box` value,
                // same head as the scrutinee), resolve to the scrutinee's monomorphic
                // key (`Lst$Box`) so the ELEMENTS are reclaimed, not the leaky generic
                // head (`Lst`). An absent mono destructor routes to a flat free (safe).
                match elab.dty(s) {
                    Some(sk) if sk.contains('$') && sk.split('$').next() == Some(k.as_str()) => {
                        Some(sk)
                    }
                    _ => Some(k),
                }
            } else {
                // polymorphic field (`a`): resolve the field's own type PARAMETER to the matching
                // argument of the scrutinee's instantiation and classify it. Multi-param-correct
                // (`Right`'s field of `Either$Integer$String` → arg 1 = String → `axion_str_drop`);
                // the old `split_once('$')` took the whole tail (`Integer$String`) as one element
                // → a flat `free` on a boxed Integer/String or a scalar = BAD FREE. `Integer`/
                // `String` route to their tagged reclaimer; a scalar/unresolved poly field is
                // SKIPPED (not flat-freed — a scalar is not heap).
                match elab
                    .dty(s)
                    .and_then(|sk| elab.recinfo.poly_field_elem_key(con, fi, &sk))
                {
                    None => continue,         // scalar / unresolved → nothing to free
                    Some(None) => None,       // shallow heap → flat `free`
                    Some(Some(k)) => Some(k), // Integer/String/nested/deep → keyed reclaimer
                }
            };
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
        Op::MakeClosure {
            func,
            captures,
            owns,
        } => format!(
            "closure {func}{}{}",
            args(captures),
            if *owns { " owning" } else { "" }
        ),
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
            ..
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
        Op::Ffi {
            name,
            args,
            arg_kinds,
            ret_float,
        } => {
            // Default (all-borrow, no float) renders exactly as before, so existing FFI snapshots
            // don't churn; float/own args and a float result add a compact `[..]` suffix.
            let suffix = if *ret_float || arg_kinds.iter().any(|k| k.float || k.own) {
                let flags: String = arg_kinds
                    .iter()
                    .map(|k| match (k.float, k.own) {
                        (true, true) => "fo",
                        (true, false) => "f",
                        (false, true) => "o",
                        _ => "-",
                    })
                    .collect::<Vec<_>>()
                    .join(",");
                format!(" [{flags}{}]", if *ret_float { "->f" } else { "" })
            } else {
                String::new()
            };
            format!("ffi {name}{}{suffix}", self::args(args))
        }
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
    cpat_with(p, &|n| n.to_string())
}

/// [`cpat`] with the source names of renamed binders (`n$1` → `n`), for reports.
pub fn cpat_source(p: &CPat) -> String {
    cpat_with(p, &|n| source_name(n).to_string())
}

fn cpat_with(p: &CPat, name: &dyn Fn(&str) -> String) -> String {
    let sub = |ps: &[CPat]| ps.iter().map(|q| cpat_with(q, name)).collect::<Vec<_>>();
    match p {
        CPat::Int(n) => n.to_string(),
        CPat::Var(n) => name(n),
        CPat::Wild => "_".into(),
        CPat::Tuple(ps) => format!("({})", sub(ps).join(", ")),
        CPat::Con(n, ps) => {
            if ps.is_empty() {
                n.clone()
            } else {
                format!("{n} {}", sub(ps).join(" "))
            }
        }
    }
}

/// A function returning a field of a BORROWED param on some paths and an owned value on others:
/// copy the field on those paths (see the call site).
fn copy_mixed_returns(
    f: &mut CoreFn,
    fn_ret_ty: &HashMap<String, String>,
    module: &ast::Module,
    where_ret_tys: &HashMap<String, Type>,
    copy_seeds: &mut Vec<Type>,
    first: usize,
) {
    // per function: the generated names must not depend on the order functions come in
    // (`first` keeps a second run's names apart from the first's)
    let mut ctr = first;
    let mut container_ret: Option<Type> = None;
    let kind = match fn_ret_ty.get(&f.name).map(String::as_str) {
        Some("String") => CopyKind::Str,
        Some("Integer") => CopyKind::Int,
        // a concrete container result (`firstBox :: List Box -> Box`, or a `where`-local's
        // inferred one), copied by its generated deep copier
        _ => match module
            .funcs
            .iter()
            .find(|g| g.name == f.name)
            .and_then(|g| g.sig.as_ref())
            .map(result_type)
            .or_else(|| where_ret_tys.get(&f.name))
            .and_then(|t| copy_kind_of(t, &module.datas).map(|k| (t, k)))
        {
            Some((t, k @ CopyKind::Container(_))) => {
                container_ret = Some(t.clone());
                k
            }
            _ => return,
        },
    };
    let borrowed: HashSet<String> = f
        .params
        .iter()
        .filter(|p| !f.owned_params.contains(p))
        .cloned()
        .collect();
    let (mut alias, mut other) = (0usize, 0usize);
    count_field_tails(
        &f.body,
        &borrowed,
        &mut HashSet::new(),
        &mut alias,
        &mut other,
    );
    if alias > 0 && other > 0 {
        copy_field_tails(&mut f.body, &borrowed, &mut HashSet::new(), &kind, &mut ctr);
        copy_seeds.extend(container_ret);
    }
}

/// A `where`-local's parameter types as Core has them: its captures first (typed when each is a
/// parameter of the parent with a signature), then its own (inferred). `None` when one is unknown.
fn where_local_param_types(
    f: &CoreFn,
    module: &ast::Module,
    where_captures: &HashMap<String, Vec<String>>,
    where_param_tys: &HashMap<String, Vec<Option<Type>>>,
) -> Option<Vec<Type>> {
    let caps = where_captures
        .get(&f.name)
        .map(Vec::as_slice)
        .unwrap_or(&[]);
    let mut out = Vec::new();
    if !caps.is_empty() {
        let parent_name = f.name.split_once('$')?.0;
        let parent = module.funcs.iter().find(|g| g.name == parent_name)?;
        let ptys = parent.sig.as_ref()?.param_types();
        for cap in caps {
            let i = parent.clauses.iter().find_map(|c| {
                c.pats
                    .iter()
                    .position(|p| matches!(p, ast::Pat::Var(n, _) if n == cap))
            })?;
            out.push((*ptys.get(i)?).clone());
        }
    }
    for t in where_param_tys.get(&f.name)? {
        out.push(t.clone()?);
    }
    (out.len() == f.params.len()).then_some(out)
}

/// `body_moves`, except that returning `v` itself (in tail position) is not counted: `true` when
/// `v` is STORED — put in a new value, handed to a consuming call, bound and moved on.
fn body_stores(v: &str, t: &Term, ba: &BorrowArgs) -> bool {
    match t {
        Term::Ret(Rhs::Op(Op::Atom(Atom::Var(x))), _) if x == v => false,
        Term::Ret(Rhs::If(_, a, b), _) => body_stores(v, a, ba) || body_stores(v, b, ba),
        Term::Ret(Rhs::Case(_, arms), _) => arms.iter().any(|(_, b)| body_stores(v, b, ba)),
        Term::Let(_, rhs, _, body) => rhs_moves(v, rhs, ba) || body_stores(v, body, ba),
        Term::Drop(_, _, _, _, body) => body_stores(v, body, ba),
        Term::Ret(rhs, _) => rhs_moves(v, rhs, ba),
    }
}

/// Whether some exit of `t` returns something other than `v` itself: a local that returns `v`
/// on one path and another value on the next has to copy `v`, since it does not own it and
/// the caller cannot tell which one came back.
fn returns_other(t: &Term, v: &str) -> bool {
    match t {
        Term::Ret(Rhs::Op(Op::Atom(Atom::Var(x))), _) => x != v,
        Term::Ret(Rhs::If(_, a, b), _) => returns_other(a, v) || returns_other(b, v),
        Term::Ret(Rhs::Case(_, arms), _) => arms.iter().any(|(_, b)| returns_other(b, v)),
        Term::Ret(_, _) => true,
        Term::Let(_, _, _, body) | Term::Drop(_, _, _, _, body) => returns_other(body, v),
    }
}

/// The binders that `case`s on `p` (or on a binder one of them brought out) bring into scope,
/// at every depth: the parts of `p` a function body can reach.
fn interior_binders(t: &Term, p: &str, out: &mut HashSet<String>) {
    fn rhs(r: &Rhs, p: &str, out: &mut HashSet<String>) {
        match r {
            Rhs::Op(_) => {}
            Rhs::If(_, a, b) => {
                interior_binders(a, p, out);
                interior_binders(b, p, out);
            }
            Rhs::Case(sc, arms) => {
                let of_p = matches!(sc, Atom::Var(s) if s == p || out.contains(s));
                for (pat, body) in arms {
                    if of_p {
                        if let CPat::Con(_, subs) | CPat::Tuple(subs) = pat {
                            for sp in subs {
                                if let CPat::Var(n) = sp {
                                    out.insert(n.clone());
                                }
                            }
                        }
                    }
                    interior_binders(body, p, out);
                }
            }
        }
    }
    match t {
        Term::Let(_, r, _, b) => {
            rhs(r, p, out);
            interior_binders(b, p, out);
        }
        Term::Drop(_, _, _, _, b) => interior_binders(b, p, out),
        Term::Ret(r, _) => rhs(r, p, out),
    }
}
