//! SIMD vector types (`F64x2`, `F64x4`, `I64x2`, `I64x4`): fixed-width vectors of `Float` or
//! `Int` lanes. They are plain values like `Int` (no heap, nothing to reclaim, freely copied),
//! so they add nothing to the ownership story; what they need is a representation, because
//! every other value is one 64-bit slot.
//!
//! * The interpreter models a vector as its lanes.
//! * Core carries vector operations as [`Op::Vec`]. [`analyze`] works out, over the whole
//!   program, which variables, parameters and results hold vectors (a union-find over the
//!   values that flow into each other: copies, call arguments and results, branch joins).
//!   A vector reaching a place that only holds a 64-bit slot — a tuple, record or constructor
//!   field, a closure capture or a call through a function value, a runtime call, a `case`
//!   scrutinee — is **AX0915**; so is one function used at both a vector and another type.
//! * `--release` (LLVM) gives those values vector types (`<4 x double>`), passed and returned
//!   in vector registers; `--dev` (Cranelift) keeps each vector as its lanes.
//!
//! `loadF64x4 a i` / `storeF64x4 a i v` lower to one range check (`axion_array_range`: every
//! lane index in `[0, len a)`) followed by unchecked element accesses ([`mark_range_lanes`]),
//! which LLVM merges into vector loads and stores. Lane arithmetic is exact IEEE (or wrapping
//! for `Int`) and `sum` adds the lanes left to right, so all backends agree bit for bit.

use crate::ast::Span;
use crate::core::{Atom, CPat, CoreFn, Op, Rhs, Term};
use std::collections::{HashMap, HashSet};

/// A vector type: its lane type and lane count.
#[derive(Clone, Copy, PartialEq, Eq, Hash, Debug)]
pub struct VTy {
    pub float: bool,
    pub lanes: u8,
}

/// Every vector type.
pub const TYPES: [VTy; 4] = [
    VTy {
        float: true,
        lanes: 2,
    },
    VTy {
        float: true,
        lanes: 4,
    },
    VTy {
        float: false,
        lanes: 2,
    },
    VTy {
        float: false,
        lanes: 4,
    },
];

impl VTy {
    pub fn name(self) -> &'static str {
        match (self.float, self.lanes) {
            (true, 2) => "F64x2",
            (true, _) => "F64x4",
            (false, 2) => "I64x2",
            (false, _) => "I64x4",
        }
    }
    pub fn from_name(s: &str) -> Option<VTy> {
        TYPES.into_iter().find(|t| t.name() == s)
    }
    /// The lane type: `Float` or `Int`.
    pub fn elem(self) -> &'static str {
        if self.float {
            "Float"
        } else {
            "Int"
        }
    }
    pub fn n(self) -> usize {
        usize::from(self.lanes)
    }
    /// The LLVM vector type (`<4 x double>`).
    pub fn llvm(self) -> String {
        format!(
            "<{} x {}>",
            self.lanes,
            if self.float { "double" } else { "i64" }
        )
    }
}

/// A vector operation in Core ([`Op::Vec`]). Lane values travel as `i64` (a `Float` as its bit
/// pattern, like everywhere else in Core).
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum VOp {
    /// `n` lanes → vector
    Make,
    /// one lane → every lane
    Splat,
    Add,
    Sub,
    Mul,
    /// `Float` lanes only
    Div,
    /// lane-wise `if a < b then a else b`
    Min,
    /// lane-wise `if a > b then a else b`
    Max,
    /// `a * b + c` rounded once (`Float` lanes only)
    Fma,
    /// `Float` lanes only
    Sqrt,
    /// `(v, i)` → lane `i`; an index out of `[0, n)` aborts (`axion_lane_oob`)
    Lane,
    /// the lanes added left to right
    Sum,
}

impl VOp {
    /// The result is a lane (a scalar), not a vector.
    pub fn scalar_result(self) -> bool {
        matches!(self, VOp::Lane | VOp::Sum)
    }
    /// Which operands are vectors (`true`) and which are lanes / indices (`false`).
    pub fn operand_kinds(self, ty: VTy) -> Vec<bool> {
        match self {
            VOp::Make => vec![false; ty.n()],
            VOp::Splat => vec![false],
            VOp::Add | VOp::Sub | VOp::Mul | VOp::Div | VOp::Min | VOp::Max => vec![true, true],
            VOp::Fma => vec![true, true, true],
            VOp::Sqrt | VOp::Sum => vec![true],
            VOp::Lane => vec![true, false],
        }
    }
    pub fn name(self) -> &'static str {
        match self {
            VOp::Make => "make",
            VOp::Splat => "splat",
            VOp::Add => "add",
            VOp::Sub => "sub",
            VOp::Mul => "mul",
            VOp::Div => "div",
            VOp::Min => "min",
            VOp::Max => "max",
            VOp::Fma => "fma",
            VOp::Sqrt => "sqrt",
            VOp::Lane => "lane",
            VOp::Sum => "sum",
        }
    }
}

/// A SIMD built-in function (operators are separate: [`binop`]).
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Builtin {
    Op(VOp, VTy),
    /// `loadT :: Array e -> Int -> T`
    Load(VTy),
    /// `storeT :: Array e -> Int -> T -> Array e`
    Store(VTy),
}

/// The named functions over each type `T`, with `t` its lower-case name: `t` (the constructor),
/// `splatT`, `laneT`, `sumT`, `minT`, `maxT`, `loadT`, `storeT`, and for `Float` lanes `fmaT`
/// and `sqrtT`.
fn function_table() -> Vec<(String, Builtin)> {
    let mut v = Vec::new();
    for ty in TYPES {
        let n = ty.name();
        v.push((n.to_lowercase(), Builtin::Op(VOp::Make, ty)));
        for op in [VOp::Splat, VOp::Lane, VOp::Sum, VOp::Min, VOp::Max] {
            v.push((format!("{}{n}", op.name()), Builtin::Op(op, ty)));
        }
        if ty.float {
            for op in [VOp::Fma, VOp::Sqrt] {
                v.push((format!("{}{n}", op.name()), Builtin::Op(op, ty)));
            }
        }
        v.push((format!("load{n}"), Builtin::Load(ty)));
        v.push((format!("store{n}"), Builtin::Store(ty)));
    }
    v
}

fn table() -> &'static [(String, Builtin)] {
    static T: std::sync::OnceLock<Vec<(String, Builtin)>> = std::sync::OnceLock::new();
    T.get_or_init(function_table)
}

/// Every SIMD built-in function name, as `'static` strings (the interpreter keys its built-ins
/// by `&'static str`).
pub fn names() -> impl Iterator<Item = &'static str> {
    table().iter().map(|(n, _)| n.as_str())
}

/// The SIMD built-in function `name`, if it is one.
pub fn builtin(name: &str) -> Option<Builtin> {
    table().iter().find(|(n, _)| n == name).map(|(_, b)| *b)
}

/// The `'static` spelling of a SIMD built-in name.
pub fn static_name(name: &str) -> Option<&'static str> {
    names().find(|n| *n == name)
}

pub fn arity(b: Builtin) -> usize {
    match b {
        Builtin::Op(op, ty) => op.operand_kinds(ty).len(),
        Builtin::Load(_) => 2,
        Builtin::Store(_) => 3,
    }
}

/// A position in a built-in's type, for the type checker.
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Slot {
    Vec,
    Elem,
    Int,
    ArrayOfElem,
}

/// The parameter slots and result slot of a built-in function.
pub fn signature(b: Builtin) -> (Vec<Slot>, Slot) {
    match b {
        Builtin::Op(op, ty) => {
            let params = op
                .operand_kinds(ty)
                .into_iter()
                .enumerate()
                .map(|(i, v)| match (v, op) {
                    (true, _) => Slot::Vec,
                    (false, VOp::Lane) if i == 1 => Slot::Int,
                    (false, _) => Slot::Elem,
                })
                .collect();
            (
                params,
                if op.scalar_result() {
                    Slot::Elem
                } else {
                    Slot::Vec
                },
            )
        }
        Builtin::Load(_) => (vec![Slot::ArrayOfElem, Slot::Int], Slot::Vec),
        Builtin::Store(_) => (
            vec![Slot::ArrayOfElem, Slot::Int, Slot::Vec],
            Slot::ArrayOfElem,
        ),
    }
}

/// The type a built-in works on.
pub fn builtin_ty(b: Builtin) -> VTy {
    match b {
        Builtin::Op(_, t) | Builtin::Load(t) | Builtin::Store(t) => t,
    }
}

/// The resolved name of an arithmetic operator over a vector type (`+#F64x4`), which inference
/// substitutes for `+ - * /` over `T` (`/` only for `Float` lanes).
pub fn op_name(method: &str, ty: VTy) -> Option<String> {
    let ok = matches!(method, "+" | "-" | "*") || (method == "/" && ty.float);
    ok.then(|| format!("{method}#{}", ty.name()))
}

/// The operation and type of a resolved vector operator (`+#F64x4`).
pub fn binop(op: &str) -> Option<(VOp, VTy)> {
    let (m, t) = op.split_once('#')?;
    let ty = VTy::from_name(t)?;
    let vop = match m {
        "+" => VOp::Add,
        "-" => VOp::Sub,
        "*" => VOp::Mul,
        "/" if ty.float => VOp::Div,
        _ => return None,
    };
    Some((vop, ty))
}

/// All resolved vector operator names.
#[cfg(test)]
pub fn binop_names() -> Vec<String> {
    TYPES
        .iter()
        .flat_map(|t| ["+", "-", "*", "/"].map(|m| op_name(m, *t)))
        .flatten()
        .collect()
}

// --- lane semantics (shared by the interpreter and the tests) ---

/// One lane of a binary float operation, exactly as every backend computes it.
pub fn float_lane(op: VOp, a: f64, b: f64) -> f64 {
    match op {
        VOp::Add => a + b,
        VOp::Sub => a - b,
        VOp::Mul => a * b,
        VOp::Div => a / b,
        VOp::Min => {
            if a < b {
                a
            } else {
                b
            }
        }
        VOp::Max => {
            if a > b {
                a
            } else {
                b
            }
        }
        _ => f64::NAN,
    }
}

/// One lane of a binary integer operation (wrapping, like `Int`).
pub fn int_lane(op: VOp, a: i64, b: i64) -> i64 {
    match op {
        VOp::Add => a.wrapping_add(b),
        VOp::Sub => a.wrapping_sub(b),
        VOp::Mul => a.wrapping_mul(b),
        VOp::Min => a.min(b),
        VOp::Max => a.max(b),
        _ => 0,
    }
}

/// The message of an out-of-range lane index (the runtime's `axion_lane_oob` prints the same).
pub fn lane_oob_message(idx: i64, n: usize) -> String {
    format!("axion: lane bounds — index {idx} out of range [0, {n})")
}

/// The first index an access to lanes `[i, i + n)` of an array of length `len` fails on, or
/// `None` when all are in range: the index `axion_array_range` reports, which is also the first
/// one a lane-by-lane access would fail on.
pub fn range_fault(i: i64, n: i64, len: i64) -> Option<i64> {
    if i < 0 {
        Some(i)
    } else if i > len - n {
        Some(i.max(len))
    } else {
        None
    }
}

// --- range-checked loads and stores ---

/// The runtime check a vector load or store starts with: `axion_array_range a i n` aborts unless
/// every index of `[i, i + n)` is in bounds, and returns `i`.
pub const RANGE: &str = "axion_array_range";

/// Turns the element accesses of each vector load and store into unchecked ones. The lowering
/// gives a load or store's range check and its element accesses the span of the call, and indexes
/// the elements from the check's result (`i`, `i + 1`, …, below `i + n`), so every element access
/// with the span of a range check is in bounds. Nothing else is lowered with that span.
pub fn mark_range_lanes(fns: &mut [CoreFn]) {
    fn collect(t: &Term, out: &mut HashSet<Span>) {
        match t {
            Term::Let(_, r, sp, k) => {
                rhs(r, *sp, out);
                collect(k, out);
            }
            Term::Drop(_, _, _, _, k) => collect(k, out),
            Term::Ret(r, sp) => rhs(r, *sp, out),
        }
    }
    fn rhs(r: &Rhs, sp: Span, out: &mut HashSet<Span>) {
        match r {
            Rhs::Op(Op::RtCall { func, .. }) if func == RANGE && sp.1 > sp.0 => {
                out.insert(sp);
            }
            Rhs::Op(_) => {}
            Rhs::If(_, t, e) => {
                collect(t, out);
                collect(e, out);
            }
            Rhs::Case(_, arms) => arms.iter().for_each(|(_, b)| collect(b, out)),
        }
    }
    let mut spans = HashSet::new();
    for f in fns.iter() {
        collect(&f.body, &mut spans);
    }
    if spans.is_empty() {
        return;
    }
    crate::refine::apply_proven(fns, &spans.into_iter().collect::<Vec<_>>());
}

// --- which values are vectors ---

/// The vector parts of one function: its parameters, its result, and its vector-valued
/// variables (everything else is a 64-bit slot).
#[derive(Clone, Debug, Default)]
pub struct FnVec {
    pub params: Vec<Option<VTy>>,
    pub ret: Option<VTy>,
    pub vars: HashMap<String, VTy>,
}

impl FnVec {
    pub fn is_empty(&self) -> bool {
        self.ret.is_none() && self.vars.is_empty() && self.params.iter().all(Option::is_none)
    }
}

/// [`analyze`]'s result, by function name. A function with no vectors is absent.
pub type Sigs = HashMap<String, FnVec>;

/// Why a value must be a 64-bit slot.
#[derive(Clone, Copy, Debug)]
enum Why {
    Scalar,
    Stored,
    Captured,
    Indirect,
    Runtime,
    Matched,
    Entry,
}

impl Why {
    fn text(self) -> &'static str {
        match self {
            Why::Scalar => "used where a scalar is expected",
            Why::Stored => "stored in a tuple, record or constructor",
            Why::Captured => "captured by a closure",
            Why::Indirect => "passed to or returned from a function value",
            Why::Runtime => "passed to a runtime operation",
            Why::Matched => "matched by `case`",
            Why::Entry => "the result of `main`",
        }
    }
}

#[derive(Clone, Copy, Debug)]
enum Kind {
    Free,
    Slot(Why, Span),
    Vector(VTy, Span),
}

struct Uf {
    parent: Vec<usize>,
    kind: Vec<Kind>,
    ids: HashMap<(usize, String), usize>,
    err: Option<(String, Span)>,
}

impl Uf {
    fn node(&mut self, f: usize, v: &str) -> usize {
        if let Some(&i) = self.ids.get(&(f, v.to_string())) {
            return i;
        }
        let i = self.parent.len();
        self.parent.push(i);
        self.kind.push(Kind::Free);
        self.ids.insert((f, v.to_string()), i);
        i
    }
    fn fresh(&mut self) -> usize {
        let i = self.parent.len();
        self.parent.push(i);
        self.kind.push(Kind::Free);
        i
    }
    fn find(&mut self, mut i: usize) -> usize {
        while self.parent[i] != i {
            self.parent[i] = self.parent[self.parent[i]];
            i = self.parent[i];
        }
        i
    }
    fn conflict(&mut self, a: Kind, b: Kind, at: Span) {
        if self.err.is_some() {
            return;
        }
        let msg = match (a, b) {
            (Kind::Vector(t, _), Kind::Slot(w, _)) | (Kind::Slot(w, _), Kind::Vector(t, _)) => {
                format!(
                    "a SIMD vector ({}) cannot be {} in native code",
                    t.name(),
                    w.text()
                )
            }
            (Kind::Vector(t, _), Kind::Vector(u, _)) => format!(
                "one function is used at two SIMD vector types ({} and {}) in native code",
                t.name(),
                u.name()
            ),
            _ => return,
        };
        let sp = match (a, b) {
            (_, Kind::Slot(_, s) | Kind::Vector(_, s)) if s.1 > s.0 => s,
            (Kind::Slot(_, s) | Kind::Vector(_, s), _) if s.1 > s.0 => s,
            _ => at,
        };
        self.err = Some((msg, sp));
    }
    fn merge_kind(&mut self, a: Kind, b: Kind, at: Span) -> Kind {
        match (a, b) {
            (Kind::Free, k) | (k, Kind::Free) => k,
            (Kind::Slot(..), Kind::Slot(..)) => a,
            (Kind::Vector(t, _), Kind::Vector(u, _)) if t == u => a,
            _ => {
                self.conflict(a, b, at);
                a
            }
        }
    }
    fn union(&mut self, a: usize, b: usize, at: Span) {
        let (ra, rb) = (self.find(a), self.find(b));
        if ra == rb {
            return;
        }
        let k = self.merge_kind(self.kind[ra], self.kind[rb], at);
        self.parent[rb] = ra;
        self.kind[ra] = k;
    }
    fn set(&mut self, a: usize, k: Kind, at: Span) {
        let r = self.find(a);
        let k = self.merge_kind(self.kind[r], k, at);
        self.kind[r] = k;
    }
}

struct Walk<'a> {
    uf: Uf,
    index: HashMap<&'a str, usize>,
    fns: &'a [CoreFn],
    ret: Vec<usize>,
}

impl Walk<'_> {
    fn var(&mut self, f: usize, a: &Atom) -> Option<usize> {
        match a {
            Atom::Var(v) => Some(self.uf.node(f, v)),
            _ => None,
        }
    }
    fn slot(&mut self, f: usize, a: &Atom, why: Why, sp: Span) {
        if let Some(n) = self.var(f, a) {
            self.uf.set(n, Kind::Slot(why, sp), sp);
        }
    }
    fn term(&mut self, f: usize, t: &Term, target: usize) {
        match t {
            Term::Let(x, r, sp, k) => {
                let n = self.uf.node(f, x);
                self.rhs(f, r, n, *sp);
                self.term(f, k, target);
            }
            Term::Drop(x, _, _, sp, k) => {
                let n = self.uf.node(f, x);
                self.uf.set(n, Kind::Slot(Why::Scalar, *sp), *sp);
                self.term(f, k, target);
            }
            Term::Ret(r, sp) => self.rhs(f, r, target, *sp),
        }
    }
    fn rhs(&mut self, f: usize, r: &Rhs, target: usize, sp: Span) {
        match r {
            Rhs::Op(op) => self.op(f, op, target, sp),
            Rhs::If(c, t, e) => {
                self.slot(f, c, Why::Scalar, sp);
                self.term(f, t, target);
                self.term(f, e, target);
            }
            Rhs::Case(s, arms) => {
                self.slot(f, s, Why::Matched, sp);
                for (p, b) in arms {
                    self.pat(f, p, sp);
                    self.term(f, b, target);
                }
            }
        }
    }
    fn pat(&mut self, f: usize, p: &CPat, sp: Span) {
        match p {
            CPat::Var(v) => {
                let n = self.uf.node(f, v);
                self.uf.set(n, Kind::Slot(Why::Stored, sp), sp);
            }
            CPat::Tuple(ps) | CPat::Con(_, ps) => ps.iter().for_each(|q| self.pat(f, q, sp)),
            CPat::Int(_) | CPat::Wild => {}
        }
    }
    fn op(&mut self, f: usize, op: &Op, target: usize, sp: Span) {
        let scalar = Kind::Slot(Why::Scalar, sp);
        match op {
            Op::Atom(a) => match self.var(f, a) {
                Some(n) => self.uf.union(target, n, sp),
                None => self.uf.set(target, scalar, sp),
            },
            Op::Vec(vop, ty, args) => {
                for (a, is_vec) in args.iter().zip(vop.operand_kinds(*ty)) {
                    if is_vec {
                        match self.var(f, a) {
                            Some(n) => self.uf.set(n, Kind::Vector(*ty, sp), sp),
                            None => {
                                self.uf
                                    .err
                                    .get_or_insert(("a SIMD operand is not a vector".into(), sp));
                            }
                        }
                    } else {
                        self.slot(f, a, Why::Scalar, sp);
                    }
                }
                let k = if vop.scalar_result() {
                    scalar
                } else {
                    Kind::Vector(*ty, sp)
                };
                self.uf.set(target, k, sp);
            }
            Op::CallDirect(g, args, _) => match self.index.get(g.as_str()).copied() {
                Some(gi) if self.fns[gi].params.len() == args.len() => {
                    for (a, p) in args.iter().zip(&self.fns[gi].params) {
                        let pn = self.uf.node(gi, p);
                        match self.var(f, a) {
                            Some(n) => self.uf.union(n, pn, sp),
                            None => self.uf.set(pn, scalar, sp),
                        }
                    }
                    let rn = self.ret[gi];
                    self.uf.union(target, rn, sp);
                }
                _ => {
                    for a in args {
                        self.slot(f, a, Why::Indirect, sp);
                    }
                    self.uf.set(target, Kind::Slot(Why::Indirect, sp), sp);
                }
            },
            _ => {
                let why = match op {
                    Op::MakeTuple(_)
                    | Op::MakeRecord { .. }
                    | Op::MakeCon { .. }
                    | Op::UpdateRecord { .. }
                    | Op::StoreRaw(..)
                    | Op::ArrayNew { .. } => Why::Stored,
                    Op::MakeClosure { .. } => Why::Captured,
                    Op::CallClosure(..) => Why::Indirect,
                    Op::RtCall { .. } | Op::Ffi { .. } => Why::Runtime,
                    _ => Why::Scalar,
                };
                for a in op_atoms(op) {
                    self.slot(f, a, why, sp);
                }
                self.uf.set(target, scalar, sp);
            }
        }
    }
}

/// Every atom an operation reads.
pub fn op_atoms(op: &Op) -> Vec<&Atom> {
    match op {
        Op::Atom(a)
        | Op::Field { rec: a, .. }
        | Op::PutStrLn(a)
        | Op::PutStr(a)
        | Op::ShowInt(a)
        | Op::LoadRaw(a, _)
        | Op::IntToFloat(a)
        | Op::FloatToInt(a)
        | Op::FloatUnary(_, a)
        | Op::ArenaAlloc(a)
        | Op::ArenaMark(a)
        | Op::ArenaRelease(a) => vec![a],
        Op::StoreRaw(p, _, v) => vec![p, v],
        Op::FuncAddr(_) | Op::Unsupported(_) => vec![],
        Op::Prim(_, a, b) | Op::PrimF(_, a, b) | Op::Promote(a, b) => vec![a, b],
        Op::CallDirect(_, xs, _)
        | Op::MakeTuple(xs)
        | Op::MakeCon { args: xs, .. }
        | Op::Vec(_, _, xs) => xs.iter().collect(),
        Op::CallClosure(c, xs) => std::iter::once(c).chain(xs).collect(),
        Op::MakeClosure { captures, .. } => captures.iter().collect(),
        Op::MakeRecord { fields, .. } => fields.iter().map(|(_, a)| a).collect(),
        Op::UpdateRecord { base, fields, .. } => std::iter::once(base)
            .chain(fields.iter().map(|(_, a)| a))
            .collect(),
        Op::WithArena { parent, clos } => parent.iter().chain(std::iter::once(clos)).collect(),
        Op::RtCall { args, .. } | Op::Ffi { args, .. } => args.iter().collect(),
        Op::ArrayNew { len, init, .. } => vec![len, init],
    }
}

fn uses_vectors(t: &Term) -> bool {
    fn rhs(r: &Rhs) -> bool {
        match r {
            Rhs::Op(Op::Vec(..)) => true,
            Rhs::Op(_) => false,
            Rhs::If(_, t, e) => uses_vectors(t) || uses_vectors(e),
            Rhs::Case(_, arms) => arms.iter().any(|(_, b)| uses_vectors(b)),
        }
    }
    match t {
        Term::Let(_, r, _, k) => rhs(r) || uses_vectors(k),
        Term::Drop(_, _, _, _, k) => uses_vectors(k),
        Term::Ret(r, _) => rhs(r),
    }
}

/// Which values of the program are vectors (see the module documentation). `entry` is the
/// program's entry function, whose result must be a slot. An error is **AX0915**'s message and
/// the span of the offending use.
pub fn analyze(fns: &[CoreFn], entry: &str) -> Result<Sigs, (String, Span)> {
    if !fns.iter().any(|f| uses_vectors(&f.body)) {
        return Ok(Sigs::new());
    }
    let mut w = Walk {
        uf: Uf {
            parent: Vec::new(),
            kind: Vec::new(),
            ids: HashMap::new(),
            err: None,
        },
        index: fns
            .iter()
            .enumerate()
            .map(|(i, f)| (f.name.as_str(), i))
            .collect(),
        fns,
        ret: Vec::new(),
    };
    w.ret = (0..fns.len()).map(|_| w.uf.fresh()).collect();
    let none: Span = (0, 0);
    // functions reached through a pointer (closures, spawned tasks) use the uniform slot ABI
    let mut indirect: HashSet<&str> = HashSet::new();
    for f in fns {
        if f.is_closure {
            indirect.insert(f.name.as_str());
        }
    }
    fn addr_taken<'a>(t: &'a Term, out: &mut HashSet<&'a str>) {
        fn rhs<'a>(r: &'a Rhs, out: &mut HashSet<&'a str>) {
            match r {
                Rhs::Op(Op::MakeClosure { func, .. } | Op::FuncAddr(func)) => {
                    out.insert(func.as_str());
                }
                Rhs::Op(_) => {}
                Rhs::If(_, t, e) => {
                    addr_taken(t, out);
                    addr_taken(e, out);
                }
                Rhs::Case(_, arms) => arms.iter().for_each(|(_, b)| addr_taken(b, out)),
            }
        }
        match t {
            Term::Let(_, r, _, k) => {
                rhs(r, out);
                addr_taken(k, out);
            }
            Term::Drop(_, _, _, _, k) => addr_taken(k, out),
            Term::Ret(r, _) => rhs(r, out),
        }
    }
    for f in fns {
        addr_taken(&f.body, &mut indirect);
    }
    for (i, f) in fns.iter().enumerate() {
        let why = if f.name == entry {
            Some(Why::Entry)
        } else if indirect.contains(f.name.as_str()) {
            Some(Why::Indirect)
        } else {
            None
        };
        if let Some(why) = why {
            let r = w.ret[i];
            w.uf.set(r, Kind::Slot(why, none), none);
            for p in &f.params {
                let n = w.uf.node(i, p);
                w.uf.set(n, Kind::Slot(Why::Indirect, none), none);
            }
        }
        for c in &f.captures {
            let n = w.uf.node(i, c);
            w.uf.set(n, Kind::Slot(Why::Captured, none), none);
        }
        let r = w.ret[i];
        w.term(i, &f.body, r);
    }
    if let Some(e) = w.uf.err.take() {
        return Err(e);
    }
    let mut kinds: HashMap<(usize, String), VTy> = HashMap::new();
    let ids: Vec<((usize, String), usize)> =
        w.uf.ids.iter().map(|(k, v)| (k.clone(), *v)).collect();
    for (k, n) in ids {
        let r = w.uf.find(n);
        if let Kind::Vector(t, _) = w.uf.kind[r] {
            kinds.insert(k, t);
        }
    }
    let mut sigs = Sigs::new();
    for (i, f) in fns.iter().enumerate() {
        let r = w.uf.find(w.ret[i]);
        let ret = match w.uf.kind[r] {
            Kind::Vector(t, _) => Some(t),
            _ => None,
        };
        let params = f
            .params
            .iter()
            .map(|p| kinds.get(&(i, p.clone())).copied())
            .collect();
        let vars = kinds
            .iter()
            .filter(|((j, _), _)| *j == i)
            .map(|((_, v), t)| (v.clone(), *t))
            .collect();
        let fv = FnVec { params, ret, vars };
        if !fv.is_empty() {
            sigs.insert(f.name.clone(), fv);
        }
    }
    Ok(sigs)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn names_round_trip() {
        for t in TYPES {
            assert_eq!(VTy::from_name(t.name()), Some(t));
        }
        assert_eq!(
            builtin("splatF64x4"),
            Some(Builtin::Op(VOp::Splat, TYPES[1]))
        );
        assert_eq!(builtin("f64x4"), Some(Builtin::Op(VOp::Make, TYPES[1])));
        assert_eq!(builtin("fmaI64x4"), None);
        assert_eq!(binop("/#I64x4"), None);
        assert_eq!(binop("*#I64x2"), Some((VOp::Mul, TYPES[2])));
        assert_eq!(binop_names().len(), 14);
    }

    #[test]
    fn range_fault_reports_the_first_bad_lane() {
        assert_eq!(range_fault(0, 4, 4), None);
        assert_eq!(range_fault(2, 4, 4), Some(4));
        assert_eq!(range_fault(-1, 4, 10), Some(-1));
        assert_eq!(range_fault(7, 4, 4), Some(7));
        assert_eq!(range_fault(0, 4, 3), Some(3));
        assert_eq!(range_fault(i64::MAX, 4, 10), Some(i64::MAX));
    }
}
