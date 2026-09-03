//! L0–L3 progressive-disclosure levels (§8).
//!
//! A module may declare a ceiling with `{-# LEVEL Ln #-}`; the ceiling only
//! *tightens* what each declaration in the module may **write** — its own
//! multiplicities, the level-defining types in its signature, and the
//! level-defining builtins in its body. It does **not** constrain what a
//! declaration *calls*: a user (or imported) function is an ordinary `Var`, not
//! a level-defining builtin, so an L0 module may still depend on an L3 library.
//!
//! - **L0** — plain strict-Haskell: no linearity/regions written (they may be
//!   inferred, but stay invisible). Guarantee: no GC, no leaks.
//! - **L1** — linear resources (`%1`/`%0.5`) and arenas.
//! - **L2** — channels and session types (`bound`, `spawn`, …).
//! - **L3** — coupling (`~`/`Maybe~`) and the `Trit` type (`observe`, `TritVec`).
//!
//! A declaration whose written level exceeds the module ceiling is **AX0500**.

use crate::ast::{Body, Expr, Func, Module, Mult, Type};
use crate::diag::{Diagnostic, Diagnostics};

// Level-defining builtins (mirror of the categories in `check::builtins`). A
// bare use of one of these keeps the caller at ≥ that level. User-function calls
// are never in these sets, which is exactly the "governs what you write, not what
// you call" rule.
const L1_BUILTINS: &[&str] = &[
    // arenas (§3)
    "withArena",
    "withSubArena",
    "allocateCell",
    "promote",
    "arena_mark",
    "arena_release",
    // fractional permissions (§2)
    "split",
    "join",
    // Buffer U8 linear (§4/§5)
    "newBuffer",
    "withBuffer",
    "bufIota",
    "xorInPlace",
    "sumBytes",
    "free",
    "foldBytes",
    "imperative",
    // linear dense Array + compact arrays (Phase B)
    "newArray",
    "getArray",
    "setArray",
    "lenArray",
    "arrayIota",
    "arraySum",
    "arrayDot",
    "newI8Array",
    "i8Iota",
    "getI8",
    "setI8",
    "lenI8",
    "i8MatVecSum",
    "i8Sum",
    "i8Dot",
    "i8DotI8",
    "newI32Array",
    "i32Iota",
    "getI32",
    "setI32",
    "lenI32",
    "i32Sum",
    "i32Dot",
    "i32MatVecSum",
];

const L2_BUILTINS: &[&str] = &[
    // channels / session types (§6)
    "send",
    "recv",
    "close",
    "newChannel",
    "select",
    "offer",
    "cancel",
    // structured-concurrency nursery (§9)
    "bound",
    "spawn",
    "parMap",
];

const L3_BUILTINS: &[&str] = &[
    // ternary (§10)
    "newTritVec",
    "getTritVec",
    "setTritVec",
    "lenTritVec",
    "tritDot",
    "tritMatVecSum",
    "tritVecFromBuffer",
    "tritVecIota",
    "observe",
    "superpose",
];

// Level-defining type heads that may appear in a signature.
const L1_TYPES: &[&str] = &[
    "Buffer", "Array", "I8Array", "I32Array", "Arena", "Cell", "Mark",
];
const L2_TYPES: &[&str] = &["Ep", "Endpoint", "Chan", "Bound"];
const L3_TYPES: &[&str] = &["Trit", "TritVec"];

// Level-defining operators (L3 coupling — reserved for when they land).
const L3_OPS: &[&str] = &["~", "Maybe~"];

fn builtin_level(name: &str) -> u8 {
    if L3_BUILTINS.contains(&name) {
        3
    } else if L2_BUILTINS.contains(&name) {
        2
    } else {
        u8::from(L1_BUILTINS.contains(&name))
    }
}

fn type_name_level(name: &str) -> u8 {
    if L3_TYPES.contains(&name) {
        3
    } else if L2_TYPES.contains(&name) {
        2
    } else {
        u8::from(L1_TYPES.contains(&name))
    }
}

fn op_level(op: &str) -> u8 {
    u8::from(L3_OPS.contains(&op)) * 3
}

/// The level a declaration *writes*: the max over its signature (multiplicities +
/// level-defining type heads) and its body (level-defining builtins/operators).
pub fn func_level(f: &Func) -> u8 {
    let mut lvl = 0u8;
    if let Some(ty) = &f.sig {
        walk_type(ty, &mut lvl);
    }
    for clause in &f.clauses {
        walk_body(&clause.body, &mut lvl);
        for w in &clause.wher {
            lvl = lvl.max(func_level(w));
        }
    }
    lvl
}

fn walk_type(t: &Type, lvl: &mut u8) {
    match t {
        Type::Con(n) => *lvl = (*lvl).max(type_name_level(n)),
        Type::Var(_) | Type::Unit => {}
        Type::App(f, a) => {
            walk_type(f, lvl);
            walk_type(a, lvl);
        }
        Type::Arrow { mult, from, to } => {
            if matches!(mult, Mult::One | Mult::Half) {
                *lvl = (*lvl).max(1);
            }
            walk_type(from, lvl);
            walk_type(to, lvl);
        }
        Type::Tuple(ts) => {
            for t in ts {
                walk_type(t, lvl);
            }
        }
    }
}

fn walk_body(b: &Body, lvl: &mut u8) {
    match b {
        Body::Plain(e) => walk_expr(e, lvl),
        Body::Guarded(arms) => {
            for (g, r) in arms {
                walk_expr(g, lvl);
                walk_expr(r, lvl);
            }
        }
    }
}

fn walk_expr(e: &Expr, lvl: &mut u8) {
    match e {
        Expr::Var(n, _) | Expr::Con(n, _) => *lvl = (*lvl).max(builtin_level(n)),
        Expr::Int(..) | Expr::Float(..) | Expr::Str(..) => {}
        Expr::App(f, a, _) => {
            walk_expr(f, lvl);
            walk_expr(a, lvl);
        }
        Expr::BinOp(op, a, b, _) => {
            *lvl = (*lvl).max(op_level(op));
            walk_expr(a, lvl);
            walk_expr(b, lvl);
        }
        Expr::If(c, t, e, _) => {
            walk_expr(c, lvl);
            walk_expr(t, lvl);
            walk_expr(e, lvl);
        }
        Expr::Let(funcs, body, _) => {
            for f in funcs {
                *lvl = (*lvl).max(func_level(f));
            }
            walk_expr(body, lvl);
        }
        Expr::Case(scrut, arms, _) => {
            walk_expr(scrut, lvl);
            for (_, e) in arms {
                walk_expr(e, lvl);
            }
        }
        Expr::Tuple(es, _) => {
            for e in es {
                walk_expr(e, lvl);
            }
        }
        Expr::RecordCon(_, fields, _) => {
            for (_, e) in fields {
                walk_expr(e, lvl);
            }
        }
        Expr::RecordUpd(base, fields, _) => {
            walk_expr(base, lvl);
            for (_, e) in fields {
                walk_expr(e, lvl);
            }
        }
        Expr::Lam(_, body, _) => walk_expr(body, lvl),
    }
}

fn level_name(n: u8) -> &'static str {
    match n {
        0 => "L0",
        1 => "L1",
        2 => "L2",
        _ => "L3",
    }
}

fn feature_hint(n: u8) -> &'static str {
    match n {
        1 => "linear resources (`%1`/`%0.5`), arenas, or dense/compact arrays",
        2 => "channels, session types, or the `bound`/`spawn` nursery",
        _ => "the `Trit`/`TritVec` type or coupling (`~`/`Maybe~`)",
    }
}

/// Enforce the module's `{-# LEVEL Ln #-}` ceiling: a declaration whose written
/// level exceeds it is **AX0500**. No ceiling → nothing to check.
pub fn check_levels(module: &Module, diags: &mut Diagnostics) {
    let Some(ceiling) = module.level_ceiling else {
        return;
    };
    for f in &module.funcs {
        let lvl = func_level(f);
        if lvl > ceiling {
            diags.push(
                Diagnostic::error(
                    "AX0500",
                    format!(
                        "declaration `{}` is {} but this module's `{{-# LEVEL {} #-}}` ceiling forbids it",
                        f.name,
                        level_name(lvl),
                        level_name(ceiling),
                    ),
                )
                .label(
                    f.span.0,
                    f.span.1,
                    format!("this uses {} features", level_name(lvl)),
                )
                .with_help(format!(
                    "{} needs {}; raise the ceiling to `{{-# LEVEL {} #-}}` or remove the feature",
                    level_name(lvl),
                    feature_hint(lvl),
                    level_name(lvl),
                )),
            );
        }
    }
}
