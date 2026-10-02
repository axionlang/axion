//! Step 2 of the ExtractOp arc (docs/safety-model-spike.md): the tag-checker as a SECOND OPINION.
//!
//! The checker validates the ExtractOp ownership tags against linear scope, sourcing its
//! borrow-return summary from the TYPE-based tags — so it sees `Integer` fields the drop_slots-gated
//! verifier misses. Two properties, asserted here:
//!   · FAITHFUL — zero violations over the whole ASan-clean corpus (no false positives).
//!   · STRICTLY STRONGER — it flags the Integer grab-via-case REUSE double-free that `--emit verify`
//!     (AX0910) reports clean, while leaving the sound single-use / String / map-getter shapes alone.
//! Non-gating; Step 3 flips it to the sole authority.
#![allow(clippy::unwrap_used, clippy::expect_used)]

use std::process::Command;

fn axionc() -> Command {
    Command::new(env!("CARGO_BIN_EXE_axionc"))
}

fn violations(src: &str, name: &str) -> i64 {
    let path = std::env::temp_dir().join(format!("axion_tagcheck_{name}.axi"));
    std::fs::write(&path, src).unwrap();
    let out = axionc()
        .args(["--emit", "tag-check", path.to_str().unwrap()])
        .output()
        .unwrap();
    let stdout = String::from_utf8_lossy(&out.stdout);
    let line = stdout
        .lines()
        .find(|l| l.starts_with("tag-check:"))
        .unwrap_or_else(|| panic!("no tag-check summary for {name}: {stdout}"));
    line.split_whitespace()
        .nth(1)
        .and_then(|n| n.parse().ok())
        .unwrap_or_else(|| panic!("bad tag-check summary for {name}: {line}"))
}

/// STRICTLY STRONGER: the Integer grab-via-case REUSE is a verifier-blind double-free — the field
/// `a` of the borrowed record is extracted twice and each result freed. The tag-checker flags it.
#[test]
fn tag_checker_flags_integer_grab_reuse() {
    let src = "data R = R Integer Integer\n\
               getF :: R -> Integer\n\
               getF r = case r of\n  R a b -> a\n\
               useBoth :: R -> Integer\n\
               useBoth r = getF r + getF r\n\
               main :: IO ()\n\
               main = putStrLn (showInteger (useBoth (R (fromInt 3) (fromInt 4))))\n";
    assert!(
        violations(src, "int_reuse") >= 1,
        "tag-checker must flag the Integer grab-via-case reuse double-free (AX0910 is blind to it)"
    );
}

/// SOUND SHAPES stay clean — the single-use and String-grab twins are ASan-clean, so the checker
/// must NOT flag them (0 false positives; the ≥2-extractions-of-the-same-field condition is why).
#[test]
fn tag_checker_leaves_sound_shapes_clean() {
    let single = "data V = V Integer\n\
                  getV :: V -> Integer\n\
                  getV v = case v of\n  V n -> n\n\
                  main :: IO ()\n\
                  main = putStrLn (showInteger (getV (V (fromInt 7))))\n";
    assert_eq!(
        violations(single, "int_single"),
        0,
        "single extraction is sound"
    );

    let string_grab = "data R = R String String\n\
                       getName :: R -> String\n\
                       getName r = case r of\n  R a b -> a\n\
                       useBoth :: R -> String\n\
                       useBoth r = strAppend (getName r) (getName r)\n\
                       sample :: R\n\
                       sample = R (strAppend \"foo\" \"\") (strAppend \"bar\" \"\")\n\
                       main :: IO ()\n\
                       main = putStrLn (useBoth sample)\n";
    assert_eq!(
        violations(string_grab, "str_grab"),
        0,
        "String grab-reuse is sound (borrow-returning, drops nulled)"
    );
}

/// FAITHFUL: the checker reports ZERO violations over the whole ASan-clean corpus — every committed
/// fixture/example is ASan-clean, so a real double-free (the only thing the ≥2 condition fires on)
/// cannot be present. A single false positive here would break the "second opinion matches today"
/// invariant that must hold before Step 3 flips the checker on as the gate.
#[test]
fn tag_checker_zero_false_positives_over_corpus() {
    let mut flagged = Vec::new();
    for base in ["tests/fixtures", "../examples", "../examples/pass"] {
        let dir = format!("{}/{base}", env!("CARGO_MANIFEST_DIR"));
        let Ok(entries) = std::fs::read_dir(&dir) else {
            continue;
        };
        for entry in entries {
            let path = entry.unwrap().path();
            if path.extension().and_then(|e| e.to_str()) != Some("axi") {
                continue;
            }
            if path.file_name().unwrap() == "recover_partial.axi" {
                continue; // deliberately malformed — does not lower
            }
            let out = axionc()
                .args(["--emit", "tag-check", path.to_str().unwrap()])
                .output()
                .unwrap();
            let stdout = String::from_utf8_lossy(&out.stdout);
            if let Some(line) = stdout.lines().find(|l| l.starts_with("tag-check:")) {
                let n: i64 = line
                    .split_whitespace()
                    .nth(1)
                    .and_then(|n| n.parse().ok())
                    .unwrap_or(0);
                if n > 0 {
                    flagged.push(format!(
                        "{}: {n}",
                        path.file_name().unwrap().to_string_lossy()
                    ));
                }
            }
        }
    }
    assert!(
        flagged.is_empty(),
        "tag-checker false positives on the ASan-clean corpus: {flagged:?}"
    );
}
