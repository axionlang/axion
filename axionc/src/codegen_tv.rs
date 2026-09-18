//! M3 — codegen reclamation-preservation translation validation (metatheory/GUARANTEE.md §6).
//!
//! `verify.rs` proves the drop-inserted **Core** frees every heap resource exactly once, on every
//! path. But the Core → LLVM-IR lowering (`llvm.rs`) is otherwise TRUSTED — and every real
//! historical memory bug (the bignum `bn_divmod` double-free, the curried-CAF miscompile) lived
//! BELOW Core. This pass closes part of that gap by *translation validation*: it checks that the
//! reclamation the backend actually emits corresponds **1:1** to the Core's `Drop` sites — none
//! dropped (→ leak), none duplicated (→ double-free), none invented, none mis-keyed.
//!
//! It is sound *by independence*: the EXPECTED reclamation multiset is computed from the Core (a
//! `Term::Drop` in user functions; the `Op`-level `CallDirect(axion_drop_*)` / `RtCall(axion_free|
//! axion_str_drop|axion_bignum_free)` child-drops and shell free in GENERATED destructor bodies —
//! M3.5); the OBSERVED multiset is parsed from the emitted code. A lowering that loses/dupes/
//! mis-emits a free makes the two disagree.
//!
//! BOTH native backends are validated against the SAME `expected()`: `observed()` parses LLVM IR
//! text (`--emit codegen-tv`), and `observed_clif()` parses Cranelift CLIF (`--emit codegen-tv-clif`).
//! CLIF names functions/callees by `FuncId` index (`u0:N`), not symbol, so the CLIF path resolves
//! those indices through the maps `codegen::emit_ir_tv` returns.
//!
//! Scope note: this validates the Core → IR LOWERING of reclamation (including destructor bodies).
//! It does NOT re-derive whether a destructor's Core matches the type's ownership layout — that
//! generation logic is a direct loop over `RecordInfo`, and the destructors' RUNTIME behavior is
//! gated by ASan/LSan over the corpus. Only the `axion_copy_*` deep-copiers are skipped (they clone,
//! they do not reclaim).

use crate::core::{Lowered, Op, Term};
use std::collections::HashMap;

/// Skip only the hand-written-style `axion_copy_*` deep-copiers (they clone, they do not reclaim).
/// The generated `axion_drop_*` destructors ARE checked (M3.5): their bodies free children at
/// offsets via `Op`-level calls, and we validate that Core → IR lowering emits them faithfully.
fn is_copier(name: &str) -> bool {
    name.starts_with("axion_copy_")
}

/// The reclamation token an `Op` performs directly (destructor bodies free children this way,
/// rather than via `Term::Drop`): a child destructor call, or a flat/str/bignum runtime free.
fn op_free_token(op: &Op) -> Option<String> {
    match op {
        Op::CallDirect(name, _, _) if name.starts_with("axion_drop_") => Some(format!("ax_{name}")),
        Op::RtCall { func, .. }
            if func == "axion_free" || func == "axion_str_drop" || func == "axion_bignum_free" =>
        {
            Some(func.clone())
        }
        _ => None,
    }
}

/// The reclamation runtime function a `Term::Drop(ty, skip)` lowers to — the exact 4-way
/// classification `llvm.rs` uses, re-derived here independently as the SPEC.
fn classify(ty: Option<&str>, skip: &[usize], drop_keys: &std::collections::HashSet<String>) -> String {
    match ty {
        Some("String") => "axion_str_drop".to_string(),
        Some("Integer") => "axion_bignum_free".to_string(),
        Some(t) => {
            let key = if skip.is_empty() {
                t.to_string()
            } else {
                let sn: Vec<String> = skip.iter().map(|i| i.to_string()).collect();
                format!("{t}_skip_{}", sn.join("_"))
            };
            if drop_keys.contains(&key) {
                format!("ax_axion_drop_{key}")
            } else {
                "axion_free".to_string()
            }
        }
        None => "axion_free".to_string(),
    }
}

type Bag = HashMap<String, i64>;

fn bump(bag: &mut Bag, k: String) {
    *bag.entry(k).or_insert(0) += 1;
}

/// Expected reclamation multiset per user function, from the Core `Drop` walk.
fn expected(lowered: &Lowered) -> HashMap<String, Bag> {
    let drop_keys: std::collections::HashSet<String> = lowered
        .fns
        .iter()
        .filter_map(|f| f.name.strip_prefix("axion_drop_").map(String::from))
        .collect();

    fn walk(t: &Term, keys: &std::collections::HashSet<String>, bag: &mut Bag) {
        match t {
            Term::Let(_, rhs, _, body) => {
                walk_rhs(rhs, keys, bag);
                walk(body, keys, bag);
            }
            Term::Drop(_, ty, skip, _, body) => {
                // user-function reclamation: one classified free per Drop.
                bump(bag, classify(ty.as_deref(), skip, keys));
                walk(body, keys, bag);
            }
            Term::Ret(rhs, _) => walk_rhs(rhs, keys, bag),
        }
    }
    fn walk_rhs(rhs: &crate::core::Rhs, keys: &std::collections::HashSet<String>, bag: &mut Bag) {
        use crate::core::Rhs;
        match rhs {
            // destructor-body reclamation: child-drops + shell free are `Op`-level.
            Rhs::Op(op) => {
                if let Some(tok) = op_free_token(op) {
                    bump(bag, tok);
                }
            }
            Rhs::If(_, a, b) => {
                walk(a, keys, bag);
                walk(b, keys, bag);
            }
            Rhs::Case(_, arms) => {
                for (_, b) in arms {
                    walk(b, keys, bag);
                }
            }
        }
    }

    let mut out = HashMap::new();
    for f in &lowered.fns {
        if is_copier(&f.name) {
            continue;
        }
        let mut bag = Bag::new();
        walk(&f.body, &drop_keys, &mut bag);
        out.insert(f.name.clone(), bag);
    }
    out
}

/// The reclamation call token on an IR line, if any (`call ... @<callee>(...)`).
fn call_token(line: &str) -> Option<String> {
    if !line.contains("call ") {
        return None;
    }
    if let Some(rest) = line.split("@\"ax_axion_drop_").nth(1) {
        // deep drop: @"ax_axion_drop_KEY"(...)
        if let Some(key) = rest.split('"').next() {
            return Some(format!("ax_axion_drop_{key}"));
        }
    }
    for name in ["axion_str_drop", "axion_bignum_free", "axion_free"] {
        if line.contains(&format!("@{name}(")) {
            return Some(name.to_string());
        }
    }
    None
}

/// Observed reclamation multiset per user function, parsed from the emitted LLVM IR.
fn observed(ir: &str) -> HashMap<String, Bag> {
    let mut out: HashMap<String, Bag> = HashMap::new();
    let mut cur: Option<String> = None;
    for line in ir.lines() {
        let trimmed = line.trim_start();
        if let Some(rest) = trimmed.strip_prefix("define ") {
            // define i64 @"ax_NAME"(...) {
            if let Some(after) = rest.split("@\"ax_").nth(1) {
                if let Some(name) = after.split('"').next() {
                    cur = if is_copier(name) {
                        None
                    } else {
                        out.entry(name.to_string()).or_default();
                        Some(name.to_string())
                    };
                }
            }
            continue;
        }
        if trimmed == "}" {
            cur = None;
            continue;
        }
        if let Some(name) = &cur {
            if let Some(tok) = call_token(line) {
                if let Some(bag) = out.get_mut(name) {
                    bump(bag, tok);
                }
            }
        }
    }
    out
}

/// Parse the leading run of ASCII digits as a `u32` (e.g. the `N` in `u0:N`, the `K` in `fnK`).
fn lead_u32(s: &str) -> Option<u32> {
    s.split(|c: char| !c.is_ascii_digit())
        .next()
        .filter(|d| !d.is_empty())
        .and_then(|d| d.parse().ok())
}

/// Observed reclamation multiset per user function, parsed from emitted Cranelift CLIF.
///
/// CLIF names functions and callees by `FuncId` index (`u0:N`), not symbol, so we resolve through
/// the maps from `codegen::emit_ir_tv`: `fn_names[N]` identifies the enclosing `function u0:N`, and
/// a `fnK = [colocated] u0:M sig…` line binds the local funcref `fnK` to callee index `M`; a
/// `call fnK(...)` then counts as reclamation iff `reclaim_callees[M]` is a free token.
fn observed_clif(
    clif: &str,
    fn_names: &HashMap<u32, String>,
    reclaim_callees: &HashMap<u32, String>,
) -> HashMap<String, Bag> {
    let mut out: HashMap<String, Bag> = HashMap::new();
    let mut cur: Option<String> = None;
    let mut local: HashMap<u32, String> = HashMap::new(); // fnK index → reclamation token
    for line in clif.lines() {
        let t = line.trim_start();
        if let Some(rest) = t.strip_prefix("function u0:") {
            local.clear();
            cur = lead_u32(rest)
                .and_then(|n| fn_names.get(&n))
                .filter(|name| !is_copier(name))
                .map(|name| {
                    out.entry(name.clone()).or_default();
                    name.clone()
                });
            continue;
        }
        if t == "}" {
            cur = None;
            local.clear();
            continue;
        }
        // `fnK = [colocated] u0:M sig…` — bind a local funcref to its callee index.
        if let Some((lhs, rhs)) = t.split_once('=') {
            if let Some(k) = lhs.trim().strip_prefix("fn").and_then(lead_u32) {
                let rhs = rhs.trim();
                let after = rhs.strip_prefix("colocated ").unwrap_or(rhs);
                if let Some(m) = after.strip_prefix("u0:").and_then(lead_u32) {
                    if let Some(tok) = reclaim_callees.get(&m) {
                        local.insert(k, tok.clone());
                    }
                }
                continue;
            }
        }
        // `call fnK(...)` (possibly `vN = call fnK(...)`) — count if fnK is a reclamation callee.
        if let Some(name) = &cur {
            if let Some(after) = t.split_once("call fn").map(|(_, r)| r) {
                if let Some(k) = lead_u32(after) {
                    if let Some(tok) = local.get(&k).cloned() {
                        if let Some(bag) = out.get_mut(name) {
                            bump(bag, tok);
                        }
                    }
                }
            }
        }
    }
    out
}

/// A reclamation-preservation discrepancy for one function.
#[derive(Debug)]
pub struct TvFinding {
    pub func: String,
    pub kind: String,
    pub expected: i64,
    pub observed: i64,
}

/// Per-function multiset diff between EXPECTED (Core) and OBSERVED (emitted IR) reclamation.
fn diff(exp: &HashMap<String, Bag>, obs: &HashMap<String, Bag>) -> Vec<TvFinding> {
    let mut findings = Vec::new();
    for (func, ebag) in exp {
        let obag = obs.get(func).cloned().unwrap_or_default();
        // union of kinds
        let mut kinds: std::collections::HashSet<&String> = ebag.keys().collect();
        for k in obag.keys() {
            kinds.insert(k);
        }
        for k in kinds {
            let e = *ebag.get(k).unwrap_or(&0);
            let o = *obag.get(k).unwrap_or(&0);
            if e != o {
                findings.push(TvFinding {
                    func: func.clone(),
                    kind: k.clone(),
                    expected: e,
                    observed: o,
                });
            }
        }
    }
    findings.sort_by(|a, b| a.func.cmp(&b.func).then(a.kind.cmp(&b.kind)));
    findings
}

/// Check that the emitted LLVM IR's reclamation matches the Core's drop sites, per function.
pub fn check(lowered: &Lowered, ir: &str) -> Vec<TvFinding> {
    diff(&expected(lowered), &observed(ir))
}

/// Check that the emitted Cranelift CLIF's reclamation matches the Core's drop sites, per function
/// (the `--dev` analogue of [`check`]; needs the `FuncId`→name maps from `codegen::emit_ir_tv`).
pub fn check_clif(
    lowered: &Lowered,
    clif: &str,
    fn_names: &HashMap<u32, String>,
    reclaim_callees: &HashMap<u32, String>,
) -> Vec<TvFinding> {
    diff(&expected(lowered), &observed_clif(clif, fn_names, reclaim_callees))
}

/// Human-readable report for `--emit codegen-tv`.
pub fn report(lowered: &Lowered, ir: &str) -> String {
    let findings = check(lowered, ir);
    let exp = expected(lowered);
    let total: i64 = exp.values().flat_map(|b| b.values()).sum();
    let mut out = format!(
        "codegen-tv: {} reclamation call(s) across {} user function(s); {} discrepancy(ies)\n",
        total,
        exp.len(),
        findings.len()
    );
    for f in &findings {
        out.push_str(&format!(
            "  MISMATCH in `{}`: {} — Core expects {}, IR emits {}\n",
            f.func, f.kind, f.expected, f.observed
        ));
    }
    if findings.is_empty() {
        out.push_str("  OK: emitted reclamation matches Core drop sites 1:1\n");
    }
    out
}

/// Human-readable report for `--emit codegen-tv-clif` (the Cranelift `--dev` path).
pub fn report_clif(
    lowered: &Lowered,
    clif: &str,
    fn_names: &HashMap<u32, String>,
    reclaim_callees: &HashMap<u32, String>,
) -> String {
    let findings = check_clif(lowered, clif, fn_names, reclaim_callees);
    let exp = expected(lowered);
    let total: i64 = exp.values().flat_map(|b| b.values()).sum();
    let mut out = format!(
        "codegen-tv-clif: {} reclamation call(s) across {} user function(s); {} discrepancy(ies)\n",
        total,
        exp.len(),
        findings.len()
    );
    for f in &findings {
        out.push_str(&format!(
            "  MISMATCH in `{}`: {} — Core expects {}, CLIF emits {}\n",
            f.func, f.kind, f.expected, f.observed
        ));
    }
    if findings.is_empty() {
        out.push_str("  OK: emitted reclamation matches Core drop sites 1:1\n");
    }
    out
}

#[cfg(test)]
mod tests {
    #![allow(clippy::unwrap_used)]
    use super::*;
    use crate::core::{Atom, CoreFn, Op, RecordInfo, Rhs, Term, NO_SPAN};

    /// A one-function `Lowered` whose body is `drop x; ret 0` — one flat `axion_free`.
    fn one_free_lowered() -> Lowered {
        let body = Term::Drop(
            "x".into(),
            None,
            vec![],
            NO_SPAN,
            Box::new(Term::Ret(Rhs::Op(Op::Atom(Atom::Int(0))), NO_SPAN)),
        );
        Lowered {
            fns: vec![CoreFn {
                name: "myfn".into(),
                params: vec!["x".into()],
                captures: vec![],
                is_closure: false,
                owned_params: vec!["x".into()],
                owned_drop_ty: vec![],
                body,
            }],
            borrow_args: HashMap::new(),
            recinfo: RecordInfo::default(),
            param_keys: HashMap::new(),
        }
    }

    fn ir_with_frees(n: usize) -> String {
        let mut s = String::from("define i64 @\"ax_myfn\"(i64 %x) {\nentry:\n");
        for _ in 0..n {
            s.push_str("  call void @axion_free(i64 %x)\n");
        }
        s.push_str("  ret i64 0\n}\n");
        s
    }

    #[test]
    fn matching_reclamation_passes() {
        let lo = one_free_lowered();
        assert!(check(&lo, &ir_with_frees(1)).is_empty());
    }

    #[test]
    fn dropped_free_is_caught() {
        // backend LEAK: Core drops once, IR frees zero times.
        let lo = one_free_lowered();
        let f = check(&lo, &ir_with_frees(0));
        assert_eq!(f.len(), 1);
        assert_eq!(f[0].kind, "axion_free");
        assert_eq!((f[0].expected, f[0].observed), (1, 0));
    }

    #[test]
    fn duplicated_free_is_caught() {
        // backend DOUBLE-FREE: Core drops once, IR frees twice.
        let lo = one_free_lowered();
        let f = check(&lo, &ir_with_frees(2));
        assert_eq!(f.len(), 1);
        assert_eq!((f[0].expected, f[0].observed), (1, 2));
    }

    /// A generated destructor whose body frees the shell via an `Op`-level `axion_free` (the M3.5
    /// path). If the IR drops that free, it is caught — a leaking destructor.
    #[test]
    fn destructor_shell_free_is_checked() {
        let body = Term::Let(
            "_r".into(),
            Rhs::Op(Op::RtCall {
                func: "axion_free".into(),
                args: vec![Atom::Var("_p".into())],
                returns: false,
            }),
            NO_SPAN,
            Box::new(Term::Ret(Rhs::Op(Op::Atom(Atom::Int(0))), NO_SPAN)),
        );
        let lo = Lowered {
            fns: vec![CoreFn {
                name: "axion_drop_Foo".into(),
                params: vec!["_p".into()],
                captures: vec![],
                is_closure: false,
                owned_params: vec![],
                owned_drop_ty: vec![],
                body,
            }],
            borrow_args: HashMap::new(),
            recinfo: RecordInfo::default(),
            param_keys: HashMap::new(),
        };
        // destructor IR present → matches
        let ir_ok = "define i64 @\"ax_axion_drop_Foo\"(i64 %_p) {\nentry:\n  call void @axion_free(i64 %_p)\n  ret i64 0\n}\n";
        assert!(check(&lo, ir_ok).is_empty());
        // destructor IR missing the shell free → caught (would leak)
        let ir_leak = "define i64 @\"ax_axion_drop_Foo\"(i64 %_p) {\nentry:\n  ret i64 0\n}\n";
        let f = check(&lo, ir_leak);
        assert_eq!(f.len(), 1);
        assert_eq!((f[0].kind.as_str(), f[0].expected, f[0].observed), ("axion_free", 1, 0));
    }

    // --- CLIF observer (the Cranelift `--dev` path) ---

    /// A CLIF `myfn` (index 100) that calls `axion_free` (callee index 4) `n` times.
    fn clif_with_frees(n: usize) -> String {
        let mut s = String::from(
            "function u0:100(i64) -> i64 system_v {\n    sig0 = (i64) system_v\n    fn0 = u0:4 sig0\nblock0(v0: i64):\n",
        );
        for _ in 0..n {
            s.push_str("    call fn0(v0)\n");
        }
        s.push_str("    v1 = iconst.i64 0\n    return v1\n}\n");
        s
    }

    fn clif_maps() -> (HashMap<u32, String>, HashMap<u32, String>) {
        let fn_names = HashMap::from([(100u32, "myfn".to_string())]);
        let reclaim = HashMap::from([(4u32, "axion_free".to_string())]);
        (fn_names, reclaim)
    }

    #[test]
    fn clif_matching_reclamation_passes() {
        let lo = one_free_lowered();
        let (fnn, rc) = clif_maps();
        assert!(check_clif(&lo, &clif_with_frees(1), &fnn, &rc).is_empty());
    }

    #[test]
    fn clif_dropped_free_is_caught() {
        // backend LEAK: Core drops once, CLIF frees zero times.
        let lo = one_free_lowered();
        let (fnn, rc) = clif_maps();
        let f = check_clif(&lo, &clif_with_frees(0), &fnn, &rc);
        assert_eq!(f.len(), 1);
        assert_eq!((f[0].kind.as_str(), f[0].expected, f[0].observed), ("axion_free", 1, 0));
    }

    #[test]
    fn clif_duplicated_free_is_caught() {
        // backend DOUBLE-FREE: Core drops once, CLIF frees twice.
        let lo = one_free_lowered();
        let (fnn, rc) = clif_maps();
        let f = check_clif(&lo, &clif_with_frees(2), &fnn, &rc);
        assert_eq!(f.len(), 1);
        assert_eq!((f[0].expected, f[0].observed), (1, 2));
    }

    #[test]
    fn clif_colocated_destructor_call_resolves_to_deep_drop_token() {
        // A `Term::Drop` keyed to a generated destructor `axion_drop_Foo` must be OBSERVED as the
        // `ax_axion_drop_Foo` token when the CLIF calls it via `fnK = colocated u0:M`.
        let mut lo = one_free_lowered();
        if let Term::Drop(_, ty, _, _, _) = &mut lo.fns[0].body {
            *ty = Some("Foo".into());
        }
        // register Foo as a destructor so `expected` classifies the drop as `ax_axion_drop_Foo`.
        lo.fns.push(CoreFn {
            name: "axion_drop_Foo".into(),
            params: vec!["_p".into()],
            captures: vec![],
            is_closure: false,
            owned_params: vec![],
            owned_drop_ty: vec![],
            body: Term::Ret(Rhs::Op(Op::Atom(Atom::Int(0))), NO_SPAN),
        });
        // CLIF: myfn (100) calls the destructor (index 7) once; destructor body (u0:7) is empty.
        let clif = "function u0:100(i64) -> i64 system_v {\n    sig0 = (i64) -> i64 system_v\n    fn0 = colocated u0:7 sig0\nblock0(v0: i64):\n    v1 = call fn0(v0)\n    v2 = iconst.i64 0\n    return v2\n}\nfunction u0:7(i64) -> i64 system_v {\nblock0(v0: i64):\n    return v0\n}\n";
        let fnn = HashMap::from([(100u32, "myfn".to_string()), (7u32, "axion_drop_Foo".to_string())]);
        let rc = HashMap::from([(7u32, "ax_axion_drop_Foo".to_string())]);
        assert!(
            check_clif(&lo, clif, &fnn, &rc).is_empty(),
            "the colocated destructor call must be observed as ax_axion_drop_Foo"
        );
    }

    #[test]
    fn miskeyed_free_is_caught() {
        // backend emits the WRONG reclaimer (plain free instead of the String drop).
        let mut lo = one_free_lowered();
        if let Term::Drop(_, ty, _, _, _) = &mut lo.fns[0].body {
            *ty = Some("String".into()); // Core expects axion_str_drop
        }
        let f = check(&lo, &ir_with_frees(1)); // IR emits axion_free
        // one missing str_drop + one spurious free
        assert_eq!(f.len(), 2);
    }
}
