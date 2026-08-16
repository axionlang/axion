//! Property tests for **preservation** and **progress** (type soundness).
//!
//! - *Progress*: a well-typed term does not get stuck — it evaluates to a value,
//!   never a "stuck" error (applying a non-function, operator on wrong types, …).
//! - *Preservation*: evaluation preserves the type — the final value has the
//!   static type of the term.
//!
//! Strategy: a generator of terms **well-typed by construction** (Int/Bool:
//! literals, arithmetic, comparisons, `if`, `let` + variables). For each term:
//!   1. the typechecker (names + linearity + HM inference) accepts it — which
//!      anchors the generator's notion of "well-typed" to `axionc`'s;
//!   2. evaluation does not get stuck (progress);
//!   3. the value has the expected type (preservation).

use crate::ast::*;
use crate::check;
use crate::diag::Diagnostics;
use crate::infer;
use crate::interp::{self, RtType};

/// Deterministic PRNG (xorshift64*) — no external dependencies.
struct Rng(u64);

impl Rng {
    fn next_u64(&mut self) -> u64 {
        let mut x = self.0;
        x ^= x << 13;
        x ^= x >> 7;
        x ^= x << 17;
        self.0 = x;
        x.wrapping_mul(0x2545_F491_4F6C_DD1D)
    }

    fn below(&mut self, n: u32) -> u32 {
        (self.next_u64() % n as u64) as u32
    }
}

#[derive(Clone, Copy, PartialEq, Eq)]
enum GTy {
    Int,
    Bool,
}

const SP: Span = (0, 0);

/// Generates a well-typed expression of the requested type, with variables in scope.
fn gen(rng: &mut Rng, ty: GTy, depth: u32, vars: &[(String, GTy)]) -> Expr {
    // candidate variables of the right type, in scope
    let usable: Vec<&String> = vars
        .iter()
        .filter(|(_, t)| *t == ty)
        .map(|(n, _)| n)
        .collect();

    if depth == 0 {
        // leaf: a literal, or a variable in scope (half the time)
        if !usable.is_empty() && rng.below(2) == 0 {
            let n = usable[rng.below(usable.len() as u32) as usize].clone();
            return Expr::Var(n, SP);
        }
        return leaf(rng, ty);
    }

    match ty {
        GTy::Int => match rng.below(5) {
            0 => leaf(rng, ty),
            1 => {
                if usable.is_empty() {
                    leaf(rng, ty)
                } else {
                    Expr::Var(usable[rng.below(usable.len() as u32) as usize].clone(), SP)
                }
            }
            2 => {
                let op = ["+", "-", "*"][rng.below(3) as usize].to_string();
                let l = gen(rng, GTy::Int, depth - 1, vars);
                let r = gen(rng, GTy::Int, depth - 1, vars);
                Expr::BinOp(op, Box::new(l), Box::new(r), SP)
            }
            3 => {
                let c = gen(rng, GTy::Bool, depth - 1, vars);
                let t = gen(rng, GTy::Int, depth - 1, vars);
                let e = gen(rng, GTy::Int, depth - 1, vars);
                Expr::If(Box::new(c), Box::new(t), Box::new(e), SP)
            }
            _ => gen_let(rng, GTy::Int, depth, vars),
        },
        GTy::Bool => match rng.below(4) {
            0 => leaf(rng, ty),
            1 => {
                let op = ["==", "<", ">"][rng.below(3) as usize].to_string();
                let l = gen(rng, GTy::Int, depth - 1, vars);
                let r = gen(rng, GTy::Int, depth - 1, vars);
                Expr::BinOp(op, Box::new(l), Box::new(r), SP)
            }
            2 => {
                let c = gen(rng, GTy::Bool, depth - 1, vars);
                let t = gen(rng, GTy::Bool, depth - 1, vars);
                let e = gen(rng, GTy::Bool, depth - 1, vars);
                Expr::If(Box::new(c), Box::new(t), Box::new(e), SP)
            }
            _ => gen_let(rng, GTy::Bool, depth, vars),
        },
    }
}

fn leaf(rng: &mut Rng, ty: GTy) -> Expr {
    match ty {
        GTy::Int => Expr::Int((rng.below(100)) as i64, SP),
        GTy::Bool => Expr::Con(
            if rng.below(2) == 0 { "True" } else { "False" }.to_string(),
            SP,
        ),
    }
}

/// `let v = <bind> in <body>`, with `v` (of type `bind_ty`) in scope in the body.
fn gen_let(rng: &mut Rng, result_ty: GTy, depth: u32, vars: &[(String, GTy)]) -> Expr {
    let bind_ty = if rng.below(2) == 0 {
        GTy::Int
    } else {
        GTy::Bool
    };
    let name = format!("v{}", rng.below(1_000_000));
    let bind_expr = gen(rng, bind_ty, depth - 1, vars);
    let bind = Func {
        name: name.clone(),
        sig: None,
        constraints: vec![],
        clauses: vec![Clause {
            pats: vec![],
            body: Body::Plain(bind_expr),
            wher: vec![],
            span: SP,
        }],
        span: SP,
    };
    let mut inner = vars.to_vec();
    inner.push((name, bind_ty));
    let body = gen(rng, result_ty, depth - 1, &inner);
    Expr::Let(vec![bind], Box::new(body), SP)
}

fn ty_to_ast(ty: GTy) -> Type {
    match ty {
        GTy::Int => Type::Con("Int".to_string()),
        GTy::Bool => Type::Con("Bool".to_string()),
    }
}

fn expected_rt(ty: GTy) -> RtType {
    match ty {
        GTy::Int => RtType::Int,
        GTy::Bool => RtType::Bool,
    }
}

/// Wraps an expression in a top-level definition `test :: T`.
fn wrap(ty: GTy, e: Expr) -> Module {
    Module {
        name: None,
        imports: vec![],
        funcs: vec![Func {
            name: "test".to_string(),
            sig: Some(ty_to_ast(ty)),
            constraints: vec![],
            clauses: vec![Clause {
                pats: vec![],
                body: Body::Plain(e),
                wher: vec![],
                span: SP,
            }],
            span: SP,
        }],
        datas: vec![],
        foreigns: vec![],
        classes: vec![],
        instances: vec![],
        level_ceiling: None,
    }
}

fn run_props(ty: GTy, seed: u64, n: u32) {
    let mut rng = Rng(seed);
    for i in 0..n {
        let e = gen(&mut rng, ty, 4, &[]);
        let module = wrap(ty, e.clone());

        // (1) axionc's typechecker accepts the generated term
        let mut diags = Diagnostics::new();
        check::check(&module, &mut diags);
        infer::infer(&module, &mut diags);
        assert!(
            !diags.has_errors(),
            "iter {i}: the generator produced a term the typechecker REJECTS\n  \
             term: {e:?}\n  diagnostics: {:?}",
            diags.items.iter().map(|d| &d.code).collect::<Vec<_>>()
        );

        // (2) progress + (3) preservation
        match interp::eval_binding(&module, "test") {
            Ok(rt) => assert_eq!(
                rt,
                expected_rt(ty),
                "iter {i}: PRESERVATION failed — value of the wrong type\n  term: {e:?}"
            ),
            Err(err) => {
                panic!("iter {i}: PROGRESS failed — evaluation got stuck: {err}\n  term: {e:?}")
            }
        }
    }
}

#[test]
fn preservation_and_progress_int() {
    run_props(GTy::Int, 0x1234_5678_9ABC_DEF0, 2000);
}

#[test]
fn preservation_and_progress_bool() {
    run_props(GTy::Bool, 0x0FED_CBA9_8765_4321, 2000);
}
