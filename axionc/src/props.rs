//! Property tests de **preservação** e **progresso** (solidez de tipos).
//!
//! - *Progresso*: um termo bem-tipado não encrava — avalia para um valor, nunca
//!   um erro de "stuck" (aplicar um não-função, operador em tipos errados, …).
//! - *Preservação*: a avaliação preserva o tipo — o valor final tem o tipo
//!   estático do termo.
//!
//! Estratégia: um gerador de termos **bem-tipados por construção** (Int/Bool:
//! literais, aritmética, comparações, `if`, `let` + variáveis). Para cada termo:
//!   1. o typechecker (nomes + linearidade + inferência HM) aceita-o — o que
//!      ancora a noção de "bem-tipado" do gerador à do `axionc`;
//!   2. a avaliação não encrava (progresso);
//!   3. o valor tem o tipo esperado (preservação).

use crate::ast::*;
use crate::check;
use crate::diag::Diagnostics;
use crate::infer;
use crate::interp::{self, RtType};

/// PRNG determinístico (xorshift64*) — sem dependências externas.
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

/// Gera uma expressão bem-tipada do tipo pedido, com variáveis em âmbito.
fn gen(rng: &mut Rng, ty: GTy, depth: u32, vars: &[(String, GTy)]) -> Expr {
    // hipóteses de variável do tipo certo, em âmbito
    let usable: Vec<&String> = vars
        .iter()
        .filter(|(_, t)| *t == ty)
        .map(|(n, _)| n)
        .collect();

    if depth == 0 {
        // folha: literal, ou uma variável em âmbito (metade das vezes)
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

/// `let v = <bind> in <corpo>`, com `v` (de tipo `bind_ty`) em âmbito no corpo.
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

/// Embrulha uma expressão numa definição de topo `test :: T`.
fn wrap(ty: GTy, e: Expr) -> Module {
    Module {
        funcs: vec![Func {
            name: "test".to_string(),
            sig: Some(ty_to_ast(ty)),
            clauses: vec![Clause {
                pats: vec![],
                body: Body::Plain(e),
                wher: vec![],
                span: SP,
            }],
            span: SP,
        }],
        datas: vec![],
    }
}

fn run_props(ty: GTy, seed: u64, n: u32) {
    let mut rng = Rng(seed);
    for i in 0..n {
        let e = gen(&mut rng, ty, 4, &[]);
        let module = wrap(ty, e.clone());

        // (1) o typechecker do axionc aceita o termo gerado
        let mut diags = Diagnostics::new();
        check::check(&module, &mut diags);
        infer::infer(&module, &mut diags);
        assert!(
            !diags.has_errors(),
            "iter {i}: o gerador produziu um termo que o typechecker REJEITA\n  \
             termo: {e:?}\n  diagnósticos: {:?}",
            diags.items.iter().map(|d| &d.code).collect::<Vec<_>>()
        );

        // (2) progresso + (3) preservação
        match interp::eval_binding(&module, "test") {
            Ok(rt) => assert_eq!(
                rt,
                expected_rt(ty),
                "iter {i}: PRESERVAÇÃO falhou — valor de tipo errado\n  termo: {e:?}"
            ),
            Err(err) => {
                panic!("iter {i}: PROGRESSO falhou — a avaliação encravou: {err}\n  termo: {e:?}")
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
