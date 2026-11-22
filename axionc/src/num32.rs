//! 32-bit number types (docs/numbers32.md): `Int32` and `Float32`.
//!
//! They are plain values like `Int` and `Float`, in the same 64-bit slot every value has: an
//! `Int32` is kept sign-extended (so the `Int` comparisons and `case` on literals work unchanged),
//! a `Float32` is the bit pattern of an IEEE single in the low 32 bits. Arithmetic wraps at 32 bits
//! (`Int32`) or rounds to single precision once per operation (`Float32`), on every backend: this
//! module is the reference the interpreter runs, and both native backends emit the same.
//!
//! The overloaded operators (`+ - * / div mod == < >`, so also `<= >= /=`) resolve to the
//! primitives below (`infer.rs`, `op_name`); integer literals take the type `Int32` where it is
//! expected, and float literals `Float32` (a literal that does not fit an `Int32` is an error).
//! Conversions are explicit (`toInt32`, `fromInt32`, `toFloat32`, `fromFloat32`).

/// A 32-bit operation, after operator resolution.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Op {
    AddI,
    SubI,
    MulI,
    DivI,
    ModI,
    AddF,
    SubF,
    MulF,
    DivF,
    EqF,
    LtF,
    GtF,
}

impl Op {
    pub fn is_float(self) -> bool {
        !matches!(self, Op::AddI | Op::SubI | Op::MulI | Op::DivI | Op::ModI)
    }
    /// A comparison: its result is a `Bool`.
    pub fn is_cmp(self) -> bool {
        matches!(self, Op::EqF | Op::LtF | Op::GtF)
    }
}

const OPS: &[(&str, Op)] = &[
    ("+#i32", Op::AddI),
    ("-#i32", Op::SubI),
    ("*#i32", Op::MulI),
    ("div#i32", Op::DivI),
    ("mod#i32", Op::ModI),
    ("+#f32", Op::AddF),
    ("-#f32", Op::SubF),
    ("*#f32", Op::MulF),
    ("/#f32", Op::DivF),
    ("==#f32", Op::EqF),
    ("<#f32", Op::LtF),
    (">#f32", Op::GtF),
];

/// The 32-bit operation an operator name stands for.
pub fn binop(name: &str) -> Option<Op> {
    OPS.iter().find(|(n, _)| *n == name).map(|(_, o)| *o)
}

/// A type this module defines.
pub fn is_type(name: &str) -> bool {
    matches!(name, "Int32" | "Float32")
}

/// What an overloaded operator over a 32-bit type resolves to.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Resolved {
    /// the `Int` operator itself (an `Int32` comparison: its values are sign-extended)
    Keep,
    /// a 32-bit primitive
    Prim(&'static str),
}

/// What an overloaded operator (a `Num`/`Ord`/`Division`/`Integral` method) over `ty` resolves
/// to, or `None` when `ty` is not 32-bit or has no such operator (`div` over `Float32`).
pub fn op_name(method: &str, ty: &str) -> Option<Resolved> {
    use Resolved::{Keep, Prim};
    Some(match (ty, method) {
        ("Int32", "+") => Prim("+#i32"),
        ("Int32", "-") => Prim("-#i32"),
        ("Int32", "*") => Prim("*#i32"),
        ("Int32", "div" | "/") => Prim("div#i32"),
        ("Int32", "mod") => Prim("mod#i32"),
        ("Int32", "==" | "<" | ">") => Keep,
        ("Float32", "+") => Prim("+#f32"),
        ("Float32", "-") => Prim("-#f32"),
        ("Float32", "*") => Prim("*#f32"),
        ("Float32", "/") => Prim("/#f32"),
        ("Float32", "==") => Prim("==#f32"),
        ("Float32", "<") => Prim("<#f32"),
        ("Float32", ">") => Prim(">#f32"),
        _ => return None,
    })
}

/// The built-in functions: name, parameter type, result type.
pub const BUILTINS: &[(&str, &str, &str)] = &[
    ("toInt32", "Int", "Int32"),
    ("fromInt32", "Int32", "Int"),
    ("toFloat32", "Float", "Float32"),
    ("fromFloat32", "Float32", "Float"),
    ("int32ToFloat32", "Int32", "Float32"),
    ("truncateF32", "Float32", "Int32"),
    ("sqrtF32", "Float32", "Float32"),
    ("showFloat32", "Float32", "String"),
];

pub fn is_builtin(name: &str) -> bool {
    BUILTINS.iter().any(|(n, _, _)| *n == name)
}

/// The built-ins that are numeric conversions or math (lowered to `Op::FloatUnary`), as opposed
/// to `fromInt32` (the identity) and `showFloat32` (a runtime call).
pub fn is_unary(name: &str) -> bool {
    matches!(
        name,
        "toInt32" | "toFloat32" | "fromFloat32" | "int32ToFloat32" | "truncateF32" | "sqrtF32"
    )
}

/// The `Int32` an `Int` wraps to: its low 32 bits, sign-extended.
pub fn wrap32(x: i64) -> i64 {
    i64::from(x as i32)
}

/// A `Float32` as the `f64` the interpreter holds (exactly representable).
pub fn f32_of(x: f64) -> f32 {
    x as f32
}

/// The 32-bit integer operations. `None` for a zero divisor (the program stops).
pub fn int_op(op: Op, a: i64, b: i64) -> Option<i64> {
    let (a, b) = (a as i32, b as i32);
    Some(i64::from(match op {
        Op::AddI => a.wrapping_add(b),
        Op::SubI => a.wrapping_sub(b),
        Op::MulI => a.wrapping_mul(b),
        Op::DivI if b == 0 => return None,
        Op::DivI => a.wrapping_div(b),
        Op::ModI if b == 0 => return None,
        Op::ModI => a.wrapping_rem(b),
        _ => return None,
    }))
}

/// The single-precision operations, each rounded once: an `f64` holding a `Float32` value, or a
/// `Bool` for a comparison (`Err`).
pub fn float_op(op: Op, a: f64, b: f64) -> Result<f64, bool> {
    let (a, b) = (a as f32, b as f32);
    match op {
        Op::AddF => Ok(f64::from(a + b)),
        Op::SubF => Ok(f64::from(a - b)),
        Op::MulF => Ok(f64::from(a * b)),
        Op::DivF => Ok(f64::from(a / b)),
        // IEEE equality: NaN equals nothing, and -0 equals 0
        Op::EqF => Err(a.partial_cmp(&b) == Some(std::cmp::Ordering::Equal)),
        Op::LtF => Err(a < b),
        Op::GtF => Err(a > b),
        _ => Ok(f64::NAN),
    }
}

/// How a `Float32` is shown: the shortest decimal that reads back as the same single.
pub fn show_f32(x: f32) -> String {
    format!("{x}")
}
