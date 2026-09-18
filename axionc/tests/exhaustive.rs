//! M4 — bounded-exhaustive checking (metatheory/GUARANTEE.md §5, roadmap M4).
//!
//! The differential fuzzer (`scripts/fuzz.py`) samples the program space randomly. This gate
//! ENUMERATES it: every program in a bounded reclamation fragment up to size *k* is generated and
//! checked, turning "~9000 random cases, none failed" into "provably none missed up to *k*".
//!
//! The fragment is the `AxionDrop` owned-set model's shape (alloc / moveOut / drop / branch): a
//! function allocates *k* heap locals, then each is disposed either by **move** (consumed by a `%1`
//! callee) or by **drop** (left unused → Auto-Drop reclaims it), optionally under a two-armed branch
//! whose arms dispose them differently. The arm-fate combinations sweep the verifier's branch-merge
//! decision boundary — historically the buggy area (drop-balance across arms).
//!
//! What is checked, exhaustively over the family: **the verifier's ACCEPT verdict is sound** — every
//! program `verify.rs` accepts (`--emit llvm` succeeds) runs under AddressSanitizer + LeakSanitizer
//! with zero corruption and zero leaks. Programs the verifier rejects (AX0910/AX0911) are *not*
//! compiled (a sound-but-conservative rejection is allowed; the model agrees — see
//! `metatheory/exhaustive.sh` for the exhaustive verifier==model half). This directly exercises the
//! trusted, un-proven `verify.rs` against runtime ground truth on every program up to size *k*.

#![allow(clippy::unwrap_used, clippy::expect_used)]

use std::process::Command;

/// The largest number of heap locals to enumerate. Branch programs are `(2^k)^2` per k, so the
/// family size is `Σ_k (2^k + 4^k)`; k=3 ⇒ 98 programs (28 accepted, compiled under ASan).
const K_MAX: usize = 3;

const PREAMBLE: &str = "\
data N = N { v :: Int }
mk :: Int -> N
mk n = N { v = n }
eat :: N %1 -> Int
eat x = v x
";

/// Build one arm/body: for each local i, if `moves[i]` consume it (`let _ = eat xi in`), else leave
/// it unused (Auto-Drop reclaims it). Returns a constant so no field is aliased (stays in-fragment).
fn body(moves: &[bool], tag: &str) -> String {
    let mut s = String::new();
    for (i, &mv) in moves.iter().enumerate() {
        if mv {
            s.push_str(&format!("let _{tag}{i} = eat x{i} in "));
        }
    }
    s.push('0');
    s
}

/// All `2^k` boolean fate-vectors of length k.
fn fate_vectors(k: usize) -> Vec<Vec<bool>> {
    (0..(1u32 << k))
        .map(|m| (0..k).map(|i| (m >> i) & 1 == 1).collect())
        .collect()
}

fn bits(v: &[bool]) -> String {
    v.iter().map(|&b| if b { 'm' } else { 'd' }).collect()
}

/// The whole bounded-exhaustive family, as `(name, source)`.
fn programs() -> Vec<(String, String)> {
    let mut out = Vec::new();
    for k in 1..=K_MAX {
        let mut allocs = String::new();
        for i in 0..k {
            allocs.push_str(&format!("  let x{i} = mk {i} in\n"));
        }
        // straight-line: one fate vector; all such programs are balanced (each local freed once).
        for f in fate_vectors(k) {
            let src = format!(
                "{PREAMBLE}test :: Int -> Int\ntest c =\n{allocs}  {body}\nmain :: Int\nmain = test 1\n",
                body = body(&f, "s"),
            );
            out.push((format!("s_k{k}_{}", bits(&f)), src));
        }
        // two-armed branch: the arms dispose the locals independently — the merge is where
        // drop-balance is decided (and where real bugs lived).
        for fa in fate_vectors(k) {
            for fb in fate_vectors(k) {
                let src = format!(
                    "{PREAMBLE}test :: Int -> Int\ntest c =\n{allocs}  if c > 0\n    then {a}\n    else {b}\nmain :: Int\nmain = test 1\n",
                    a = body(&fa, "a"),
                    b = body(&fb, "b"),
                );
                out.push((format!("b_k{k}_{}_{}", bits(&fa), bits(&fb)), src));
            }
        }
    }
    out
}

/// Optional: materialize the family to `$AXION_M4_DUMP` for the Lean verifier==model half
/// (`metatheory/exhaustive.sh`). Ignored by default so the single generator has one home.
#[test]
#[ignore = "materializes the corpus for metatheory/exhaustive.sh; run explicitly with AXION_M4_DUMP set"]
fn dump_exhaustive_corpus() {
    let dir = std::env::var("AXION_M4_DUMP").expect("set AXION_M4_DUMP=<dir>");
    std::fs::create_dir_all(&dir).unwrap();
    for (name, src) in programs() {
        std::fs::write(format!("{dir}/{name}.axi"), src).unwrap();
    }
}

#[test]
fn verifier_accept_is_sanitizer_sound_over_the_bounded_family() {
    let clang = std::env::var("AXION_CLANG").unwrap_or_else(|_| "clang".into());
    let have_clang = Command::new(&clang).arg("--version").output().is_ok();

    let dir = std::env::temp_dir().join(format!("axion-m4-{}", std::process::id()));
    std::fs::create_dir_all(&dir).unwrap();

    let (mut accepted, mut rejected, mut sanitized) = (0usize, 0usize, 0usize);
    let progs = programs();
    let total = progs.len();

    for (name, src) in progs {
        let axi = dir.join(format!("{name}.axi"));
        std::fs::write(&axi, &src).unwrap();

        // `--emit llvm` runs the default-on verifier gate (AX0910/AX0911): success ⇒ ACCEPTED
        // (we get the IR); failure with an AX09xx diagnostic ⇒ a genuine verifier REJECT.
        let ir = Command::new(env!("CARGO_BIN_EXE_axionc"))
            .args(["--emit", "llvm"])
            .arg(&axi)
            .output()
            .unwrap();

        if !ir.status.success() {
            let err = String::from_utf8_lossy(&ir.stderr);
            assert!(
                err.contains("AX0910") || err.contains("AX0911"),
                "`{name}` failed for a non-verifier reason (generator bug):\n{err}\n--- src ---\n{src}"
            );
            rejected += 1;
            continue;
        }
        accepted += 1;

        // ACCEPTED ⇒ must be runtime-safe. Compile the emitted IR with ASan+LSan and run it.
        if !have_clang {
            continue;
        }
        let ll = dir.join(format!("{name}.ll"));
        std::fs::write(&ll, &ir.stdout).unwrap();
        let exe = dir.join(format!("{name}.san"));
        let cc = Command::new(&clang)
            .args(["-fsanitize=address,leak", "-pthread", "-O1", "-w"])
            .arg(&ll)
            .arg(env!("AXION_RT_LIB"))
            .args(["-ldl", "-lm", "-o"])
            .arg(&exe)
            .status()
            .unwrap();
        assert!(cc.success(), "`{name}`: clang+sanitizer link failed");
        let run = Command::new(&exe)
            .env("ASAN_OPTIONS", "detect_leaks=1")
            .output()
            .unwrap();
        assert!(
            run.status.success(),
            "SOUNDNESS VIOLATION: verifier ACCEPTED `{name}` but ASan/LSan reported an error:\n{}\n--- src ---\n{src}",
            String::from_utf8_lossy(&run.stderr)
        );
        sanitized += 1;
    }

    drop(std::fs::remove_dir_all(&dir));

    // Sanity: the family is non-trivial and exercised BOTH sides of the decision boundary.
    assert_eq!(accepted + rejected, total);
    assert!(accepted > 0 && rejected > 0, "family must span accept AND reject: {accepted} acc / {rejected} rej");
    if have_clang {
        assert_eq!(
            sanitized, accepted,
            "every accepted program must have been ASan/LSan-checked"
        );
        eprintln!(
            "M4: {total} programs (k≤{K_MAX}); {accepted} accepted (all ASan/LSan-clean), {rejected} rejected"
        );
    } else {
        eprintln!("M4: {total} programs; {accepted} accepted / {rejected} rejected (clang absent — sanitizer half skipped)");
    }
}
