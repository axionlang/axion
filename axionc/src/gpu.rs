//! GPU kernels (`gpuFor`, docs/gpu.md): which Core functions a `gpuFor` runs on the device.
//!
//! `gpuFor a k` lowers to `rtcall axion_gpu_for a k` where `k` is a closure. Under `--release`
//! the closure's lifted function, and every function it calls, are compiled a second time for the
//! GPU (`llvm.rs`, `device_ptx`), and the call becomes `axion_gpu_launch`. This module finds those
//! functions, checks that the device can run them (`check`, AX0802: the front end's check in
//! `par.rs` reads the source; this one reads the final Core, which also sees what overloading and
//! specialization made of it), and works out which of the closure's captures are arrays (the
//! runtime copies those to the device).

use crate::core::{Atom, CPat, CoreFn, Op, Rhs, Term};
use std::collections::{HashMap, HashSet};

/// The runtime call a `gpuFor` lowers to.
pub const RT: &str = "axion_gpu_for";

/// A kernel: the closure function it runs, how many captures it has, and which are arrays.
#[derive(Clone, Debug)]
pub struct Kernel {
    pub lam: String,
    pub ncaps: usize,
    pub mask: u64,
}

/// What every closure variable of `body` is made from: variable → lifted function.
pub fn closures(body: &Term) -> HashMap<String, String> {
    let mut out = HashMap::new();
    fn go(t: &Term, out: &mut HashMap<String, String>) {
        match t {
            Term::Let(x, rhs, _, rest) => {
                if let Rhs::Op(Op::MakeClosure { func, .. }) = rhs {
                    out.insert(x.clone(), func.clone());
                }
                if let Rhs::Op(Op::Atom(Atom::Var(y))) = rhs {
                    if let Some(f) = out.get(y).cloned() {
                        out.insert(x.clone(), f);
                    }
                }
                rhs_terms(rhs).into_iter().for_each(|b| go(b, out));
                go(rest, out);
            }
            Term::Drop(_, _, _, _, rest) => go(rest, out),
            Term::Ret(rhs, _) => rhs_terms(rhs).into_iter().for_each(|b| go(b, out)),
        }
    }
    go(body, &mut out);
    out
}

fn rhs_terms(r: &Rhs) -> Vec<&Term> {
    match r {
        Rhs::Op(_) => Vec::new(),
        Rhs::If(_, t, e) => vec![&**t, &**e],
        Rhs::Case(_, arms) => arms.iter().map(|(_, b)| b).collect(),
    }
}

/// A branch that ends in a contract failure (`contracts.rs`): it only builds the message and
/// aborts. On the device it is a trap, so what it does is not device code.
pub fn fails(t: &Term) -> bool {
    let is_fail =
        |r: &Rhs| matches!(r, Rhs::Op(Op::RtCall { func, .. }) if func == "axion_contract_fail");
    match t {
        Term::Let(_, rhs, _, rest) => is_fail(rhs) || fails(rest),
        Term::Drop(_, _, _, _, rest) => fails(rest),
        Term::Ret(rhs, _) => is_fail(rhs),
    }
}

/// The branches of `r` the device runs (all but the contract failures).
fn live_terms(r: &Rhs) -> Vec<&Term> {
    rhs_terms(r).into_iter().filter(|t| !fails(t)).collect()
}

/// Every op of a term the device would run (contract failures left out), with the variable it
/// is bound to (`None` in a `ret`).
fn ops<'t>(t: &'t Term, out: &mut Vec<(Option<&'t str>, &'t Op)>) {
    if fails(t) {
        return;
    }
    match t {
        Term::Let(x, rhs, _, rest) => {
            match rhs {
                Rhs::Op(op) => out.push((Some(x), op)),
                _ => live_terms(rhs).into_iter().for_each(|b| ops(b, out)),
            }
            ops(rest, out);
        }
        Term::Drop(_, _, _, _, rest) => ops(rest, out),
        Term::Ret(rhs, _) => match rhs {
            Rhs::Op(op) => out.push((None, op)),
            _ => live_terms(rhs).into_iter().for_each(|b| ops(b, out)),
        },
    }
}

/// The kernels of the program, in a fixed order, each once.
pub fn kernels(fns: &[CoreFn]) -> Vec<Kernel> {
    let by_name: HashMap<&str, &CoreFn> = fns.iter().map(|f| (f.name.as_str(), f)).collect();
    let arrays = array_vars(fns);
    let mut out: Vec<Kernel> = Vec::new();
    for f in fns {
        let clos = closures(&f.body);
        let mut v = Vec::new();
        ops(&f.body, &mut v);
        for (_, op) in v {
            if let Op::RtCall { func, args, .. } = op {
                if func != RT {
                    continue;
                }
                let Some(Atom::Var(c)) = args.get(1) else {
                    continue;
                };
                let Some(lam) = clos.get(c) else {
                    continue;
                };
                if out.iter().any(|k| &k.lam == lam) {
                    continue;
                }
                let Some(lf) = by_name.get(lam.as_str()) else {
                    continue;
                };
                let mine = arrays.get(lam.as_str());
                let mut mask = 0u64;
                for (i, cap) in lf.captures.iter().enumerate() {
                    if i < 63 && mine.is_some_and(|s| s.contains(cap)) {
                        mask |= 1 << i;
                    }
                }
                out.push(Kernel {
                    lam: lam.clone(),
                    ncaps: lf.captures.len(),
                    mask,
                });
            }
        }
    }
    out
}

/// The runtime calls a device function may make: array reads and lengths, and the aborts of the
/// inline checks (which become traps on the device).
const DEVICE_RT: &[&str] = &[
    "axion_array_get",
    "axion_array_len",
    "axion_array_oob",
    crate::bce::GET_NOBC,
];

/// The functions the kernels run on the device (their closure functions and everything those
/// call), or the first thing a device cannot run: a description and the function it is in.
pub fn device_fns<'f>(
    fns: &'f [CoreFn],
    kernels: &[Kernel],
) -> Result<Vec<&'f CoreFn>, (String, String)> {
    let by_name: HashMap<&str, &CoreFn> = fns.iter().map(|f| (f.name.as_str(), f)).collect();
    let mut seen: HashSet<&str> = HashSet::new();
    let mut todo: Vec<&str> = kernels.iter().map(|k| k.lam.as_str()).collect();
    let mut out = Vec::new();
    while let Some(n) = todo.pop() {
        if !seen.insert(n) {
            continue;
        }
        let Some(f) = by_name.get(n).copied() else {
            return Err((
                format!("`{n}`, which is not compiled natively"),
                n.to_string(),
            ));
        };
        let mut v = Vec::new();
        ops(&f.body, &mut v);
        for (_, op) in v {
            let bad = match op {
                Op::Atom(Atom::Str(_)) => Some("a String".to_string()),
                Op::Atom(_)
                | Op::Prim(..)
                | Op::PrimF(..)
                | Op::IntToFloat(_)
                | Op::FloatToInt(_)
                | Op::FloatUnary(..) => None,
                Op::CallDirect(g, _, _) => {
                    todo.push(g.as_str());
                    None
                }
                Op::RtCall { func, .. } if DEVICE_RT.contains(&func.as_str()) => None,
                Op::RtCall { func, .. } => Some(format!("the run-time call `{func}`")),
                Op::CallClosure(..) => Some("a call through a function value".into()),
                Op::MakeClosure { .. } => Some("a function value".into()),
                Op::MakeTuple(_) => Some("a tuple".into()),
                Op::MakeRecord { con, .. } | Op::MakeCon { con, .. } => {
                    Some(format!("the data value `{con}`"))
                }
                Op::Vec(..) => Some("a SIMD vector".into()),
                _ => Some("a heap value".into()),
            };
            if let Some(b) = bad {
                return Err((b, n.to_string()));
            }
        }
        if let Some(b) = term_unfit(&f.body) {
            return Err((b, n.to_string()));
        }
        out.push(f);
    }
    out.sort_by(|a, b| a.name.cmp(&b.name));
    Ok(out)
}

/// A `drop` (a heap value) or a `case` on a data value: the device has no heap.
fn term_unfit(t: &Term) -> Option<String> {
    if fails(t) {
        return None;
    }
    match t {
        Term::Let(_, rhs, _, rest) => rhs_unfit(rhs).or_else(|| term_unfit(rest)),
        Term::Drop(x, ..) => Some(format!("a heap value (`{x}` is freed)")),
        Term::Ret(rhs, _) => rhs_unfit(rhs),
    }
}

fn rhs_unfit(r: &Rhs) -> Option<String> {
    match r {
        Rhs::Op(_) => None,
        Rhs::If(_, t, e) => term_unfit(t).or_else(|| term_unfit(e)),
        Rhs::Case(_, arms) => arms.iter().find_map(|(p, b)| {
            let pat = match p {
                CPat::Int(_) | CPat::Var(_) | CPat::Wild => None,
                CPat::Con(c, _) => Some(format!("a pattern on the data value `{c}`")),
                CPat::Tuple(_) => Some("a tuple pattern".to_string()),
            };
            pat.or_else(|| term_unfit(b))
        }),
    }
}

/// For each function, the variables (parameters, captures, locals) it uses as arrays: read with
/// `getArray`/`lenArray`, or passed where a function it calls uses an array.
pub fn array_vars(fns: &[CoreFn]) -> HashMap<String, HashSet<String>> {
    let mut arr: HashMap<String, HashSet<String>> = HashMap::new();
    let params: HashMap<&str, &[String]> = fns
        .iter()
        .map(|f| (f.name.as_str(), f.params.as_slice()))
        .collect();
    loop {
        let mut grew = false;
        for f in fns {
            let mut v = Vec::new();
            ops(&f.body, &mut v);
            let mut mine = arr.get(&f.name).cloned().unwrap_or_default();
            let before = mine.len();
            // aliases: `let y = x` — an array either way
            let mut alias: Vec<(&str, &str)> = Vec::new();
            for (x, op) in &v {
                match op {
                    Op::RtCall { func, args, .. }
                        if func.starts_with("axion_array_")
                            || func == crate::bce::GET_NOBC
                            || func == crate::bce::SET_NOBC =>
                    {
                        if let Some(Atom::Var(a)) = args.first() {
                            mine.insert(a.clone());
                        }
                    }
                    Op::CallDirect(g, args, _) => {
                        let callee = arr.get(g);
                        let ps = params.get(g.as_str()).copied().unwrap_or(&[]);
                        for (i, a) in args.iter().enumerate() {
                            if let (Atom::Var(a), Some(p)) = (a, ps.get(i)) {
                                if callee.is_some_and(|s| s.contains(p)) {
                                    mine.insert(a.clone());
                                }
                            }
                        }
                    }
                    Op::Atom(Atom::Var(y)) => {
                        if let Some(x) = x {
                            alias.push((x, y));
                        }
                    }
                    _ => {}
                }
            }
            loop {
                let n = mine.len();
                for (x, y) in &alias {
                    if mine.contains(*x) {
                        mine.insert((*y).to_string());
                    }
                    if mine.contains(*y) {
                        mine.insert((*x).to_string());
                    }
                }
                if mine.len() == n {
                    break;
                }
            }
            if mine.len() != before {
                grew = true;
                arr.insert(f.name.clone(), mine);
            }
        }
        if !grew {
            return arr;
        }
    }
}
