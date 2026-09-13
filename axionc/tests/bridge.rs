//! Faithfulness bridge — Track 2: does the Lean metatheory MODEL match the real verifier?
//!
//! `metatheory/*.lean` prove soundness of a hand-written model of `verify.rs`. On their own they
//! only guarantee the MODEL is sound; a proof of a model that drifts from the code proves little.
//! This bridge ties the two together: for each canonical memory-safety shape, it asserts that the
//! REAL verifier's verdict on a real `.axi` program equals the verdict the corresponding Lean
//! theorem proves. `metatheory/check.sh` establishes the Lean side (each theorem's verdict is a
//! machine-checked proof); this test establishes the code side (the verifier agrees), and the
//! `lean_theorem` field is the explicit link between them. See `metatheory/bridge.md`.
//!
//! The unsafe shapes are produced with the same default-off hooks Track 1 used to prove the
//! verifier is a sound net (`AXION_NO_ALIAS_COPY` regenerates the conditional-alias-return Core
//! R-1..R-5 copies away; `AXION_NAIVE_ELEM_KEY` regenerates the multi-param mis-key Core the
//! `cond_elem_key` fix removed) — so the real verifier sees exactly the Core the Lean model's
//! `borrow`/mis-key shapes abstract.
#![allow(clippy::unwrap_used, clippy::expect_used)]

use std::process::Command;

fn axionc() -> Command {
    Command::new(env!("CARGO_BIN_EXE_axionc"))
}

/// The verifier's verdict on one program: `Clean`, or a corruption finding of a given kind.
#[derive(Debug, PartialEq, Eq)]
enum Verdict {
    Clean,
    DropOfAlias,
    UseAfterFree,
    WrongDropKey,
    OtherCorruption,
}

fn verdict(fixture: &str, env: Option<(&str, &str)>) -> Verdict {
    let path = format!("{}/tests/fixtures/{fixture}", env!("CARGO_MANIFEST_DIR"));
    let mut cmd = axionc();
    cmd.args(["--emit", "verify", &path]);
    if let Some((k, v)) = env {
        cmd.env(k, v);
    }
    let out = cmd.output().unwrap();
    let s = String::from_utf8_lossy(&out.stdout);
    if s.contains("no corruption") {
        Verdict::Clean
    } else if s.contains("DropOfAlias") {
        Verdict::DropOfAlias
    } else if s.contains("UseAfterFree") {
        Verdict::UseAfterFree
    } else if s.contains("WrongDropKey") {
        Verdict::WrongDropKey
    } else {
        Verdict::OtherCorruption
    }
}

/// One row of the bridge: an abstract shape, the Lean theorem that fixes its verdict, and the real
/// program (plus optional unsafe-Core hook) whose verifier verdict must match.
struct Row {
    shape: &'static str,
    lean_theorem: &'static str, // in metatheory/*.lean, proved by check.sh
    lean_accepts: bool,         // the verdict that theorem proves (accept vs reject)
    fixture: &'static str,
    env: Option<(&'static str, &'static str)>,
    /// For a REJECT row, the specific corruption kind the model's rule predicts (None ⇒ any).
    expect_kind: Option<Verdict>,
}

fn rows() -> Vec<Row> {
    vec![
        // ── accept shapes (model `accepts` ⟺ verifier clean) ───────────────────────────────
        Row {
            shape: "balanced linear program (alloc; use; drop)",
            lean_theorem: "AxionDrop: balanced branching program accepted",
            lean_accepts: true,
            fixture: "list_heap_reclaim.axi",
            env: None,
            expect_kind: None,
        },
        Row {
            shape: "conditional-param-return, copy on (R-5) — arms balance",
            lean_theorem: "AxionAlias.v1_copy_fixed_accepted",
            lean_accepts: true,
            fixture: "alias_return_net.axi",
            env: None,
            expect_kind: None,
        },
        Row {
            shape: "conditional container-return, copy on (R-5)",
            lean_theorem: "AxionAlias.v1_copy_fixed_accepted",
            lean_accepts: true,
            fixture: "container_copy_reclaim.axi",
            env: None,
            expect_kind: None,
        },
        Row {
            shape: "multi-param sum, correct key",
            lean_theorem: "AxionKey.correct_key_accepted",
            lean_accepts: true,
            fixture: "either_map_reclaim.axi",
            env: None,
            expect_kind: None,
        },
        Row {
            shape: "safe borrow then owner freed",
            lean_theorem: "AxionAlias.safe_borrow_accepted",
            lean_accepts: true,
            fixture: "dead_binding_reclaim.axi",
            env: None,
            expect_kind: None,
        },
        // ── reject shapes (model rejects ⟺ verifier flags corruption) ──────────────────────
        Row {
            shape: "conditional-param-return alias, copy off (V-1)",
            lean_theorem: "AxionAlias.v1_conditional_alias_return_rejected",
            lean_accepts: false,
            fixture: "alias_return_net.axi",
            env: Some(("AXION_NO_ALIAS_COPY", "1")),
            expect_kind: Some(Verdict::DropOfAlias),
        },
        Row {
            shape: "conditional container-return alias, copy off (V-1 over a container)",
            lean_theorem: "AxionAlias.v1_conditional_alias_return_rejected",
            lean_accepts: false,
            fixture: "container_copy_reclaim.axi",
            env: Some(("AXION_NO_ALIAS_COPY", "1")),
            expect_kind: Some(Verdict::DropOfAlias),
        },
        Row {
            shape: "multi-param sum, wrong reclaimer key (V-2)",
            lean_theorem: "AxionKey.wrong_key_drop_rejected",
            lean_accepts: false,
            fixture: "either_map_reclaim.axi",
            env: Some(("AXION_NAIVE_ELEM_KEY", "1")),
            expect_kind: Some(Verdict::WrongDropKey),
        },
    ]
}

#[test]
fn lean_model_and_verifier_agree_on_every_canonical_shape() {
    let mut disagreements = Vec::new();
    let mut agreed = 0;
    for r in rows() {
        let v = verdict(r.fixture, r.env);
        let verifier_accepts = v == Verdict::Clean;
        // 1. accept/reject must agree with the Lean theorem's verdict.
        if verifier_accepts != r.lean_accepts {
            disagreements.push(format!(
                "shape {:?}: Lean {} => {}, but verifier {:?} on {} {:?}",
                r.shape,
                r.lean_theorem,
                if r.lean_accepts { "accepts" } else { "rejects" },
                v,
                r.fixture,
                r.env,
            ));
            continue;
        }
        // 2. for a reject, the corruption KIND must match the model rule the theorem is about.
        if let Some(kind) = r.expect_kind {
            if v != kind {
                disagreements.push(format!(
                    "shape {:?}: expected {:?} (per {}), got {:?} on {}",
                    r.shape, kind, r.lean_theorem, v, r.fixture
                ));
                continue;
            }
        }
        agreed += 1;
    }
    assert!(
        disagreements.is_empty(),
        "Lean model and verifier disagree:\n{}",
        disagreements.join("\n")
    );
    assert!(agreed >= 8, "expected all canonical shapes to be checked, got {agreed}");
}
