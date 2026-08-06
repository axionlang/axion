//! **Generative** property tests of the memory analyses (Auto-Drop §2).
//!
//! Generates random linear programs (flat records, field reads, borrows, `%1`
//! moves, `if`/`let`, arithmetic) — the *fully reclaimable* fragment — and, for
//! each one, requires three invariants in the native backend:
//!
//!   1. **No corruption:** `--backend cranelift` compiles and runs without crashing
//!      (a use-after-free/double-free would blow up).
//!   2. **No leaks / double-free:** `AXION_HEAP_STATS` gives `allocs == frees` —
//!      each allocated record is freed exactly once.
//!   3. **Executor agreement:** the native result == the interpreter's.
//!
//! Covers exactly the hardened analyses (pure `BorrowArgs` borrow, structural Drop,
//! `if`/`case` balancing, cross-function reclamation). The fragment deliberately
//! avoids what still leaks by conservative choice (nested records, `show`,
//! returned closures) — see docs/backend.md.
//!
//! Test code uses `unwrap`/`expect` and `let _` on process handles; relax the
//! crate-wide restriction lints (`Cargo.toml [lints]`) that don't fit tests.
#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::cast_possible_truncation,
    clippy::cast_possible_wrap,
    unused_qualifications,
    let_underscore_drop
)]

use std::process::Command;

fn axionc() -> Command {
    Command::new(env!("CARGO_BIN_EXE_axionc"))
}

/// Deterministic PRNG (xorshift64*), no dependencies — same as in `props.rs`.
struct Gen {
    state: u64,
    fresh: u32,
}

impl Gen {
    fn next_u64(&mut self) -> u64 {
        let mut x = self.state;
        x ^= x >> 12;
        x ^= x << 25;
        x ^= x >> 27;
        self.state = x;
        x.wrapping_mul(0x2545_F491_4F6C_DD1D)
    }

    fn below(&mut self, n: u32) -> u32 {
        (self.next_u64() % n as u64) as u32
    }

    fn fresh_name(&mut self, prefix: char) -> String {
        let n = self.fresh;
        self.fresh += 1;
        format!("{prefix}{n}")
    }

    /// An expression of type `Int`, well-typed and fully reclaimable, in the
    /// given environment (`ints`/`ps` = Int / record-`P` variables in scope).
    fn int_expr(&mut self, depth: u32, ints: &[String], ps: &[String]) -> String {
        // leaf: with high probability near the bottom
        if depth == 0 || self.below(100) < 35 {
            return self.leaf(ints, ps);
        }
        match self.below(7) {
            0 => {
                let op = ["+", "-", "*"][self.below(3) as usize];
                let l = self.int_expr(depth - 1, ints, ps);
                let r = self.int_expr(depth - 1, ints, ps);
                format!("({l} {op} {r})")
            }
            1 => {
                let cmp = ["<", ">", "=="][self.below(3) as usize];
                let cl = self.int_expr(depth - 1, ints, ps);
                let cr = self.int_expr(depth - 1, ints, ps);
                let th = self.int_expr(depth - 1, ints, ps);
                let el = self.int_expr(depth - 1, ints, ps);
                format!("(if {cl} {cmp} {cr} then {th} else {el})")
            }
            2 => {
                // let-Int: binds a new Int and continues
                let e = self.int_expr(depth - 1, ints, ps);
                let name = self.fresh_name('x');
                let mut ints2 = ints.to_vec();
                ints2.push(name.clone());
                let body = self.int_expr(depth - 1, &ints2, ps);
                format!("(let {name} = {e} in {body})")
            }
            3 => {
                // let-P: allocates a flat record and continues (may read/borrow it
                // or not — Auto-Drop reclaims it either way)
                let ea = self.int_expr(depth - 1, ints, ps);
                let eb = self.int_expr(depth - 1, ints, ps);
                let name = self.fresh_name('p');
                let mut ps2 = ps.to_vec();
                ps2.push(name.clone());
                let body = self.int_expr(depth - 1, ints, &ps2);
                format!("(let {name} = P {{ a = {ea}, b = {eb} }} in {body})")
            }
            4 if !ps.is_empty() => {
                // a call that borrows a record in scope
                let f = ["sumP", "fstP"][self.below(2) as usize];
                let p = &ps[self.below(ps.len() as u32) as usize];
                format!("({f} {p})")
            }
            5 => {
                // move: builds a fresh record and consumes it (%1 → the callee frees it)
                let ea = self.int_expr(depth - 1, ints, ps);
                let eb = self.int_expr(depth - 1, ints, ps);
                format!("(useP (P {{ a = {ea}, b = {eb} }}))")
            }
            _ => {
                // nesting: a `Box` that owns a `P` → exercises deep-drop
                // (the destructor frees the inner `P` and then the `Box`).
                let ea = self.int_expr(depth - 1, ints, ps);
                let eb = self.int_expr(depth - 1, ints, ps);
                let et = self.int_expr(depth - 1, ints, ps);
                format!("(boxSum (Box {{ inner = P {{ a = {ea}, b = {eb} }}, tag = {et} }}))")
            }
        }
    }

    fn leaf(&mut self, ints: &[String], ps: &[String]) -> String {
        let mut choices = 1u32; // literal
        if !ints.is_empty() {
            choices += 1;
        }
        if !ps.is_empty() {
            choices += 1;
        }
        match self.below(choices) {
            0 => format!("{}", self.below(20)),
            1 if !ints.is_empty() => ints[self.below(ints.len() as u32) as usize].clone(),
            _ => {
                let field = if self.below(2) == 0 { "a" } else { "b" };
                let p = &ps[self.below(ps.len() as u32) as usize];
                format!("({field} {p})")
            }
        }
    }
}

/// Fixed prelude: a flat record + readers that borrow it + a `%1` consumer.
const PRELUDE: &str = "\
data P = P { a :: Int, b :: Int }
data Box = Box { inner :: P, tag :: Int }
sumP :: P -> Int
sumP p = a p + b p
fstP :: P -> Int
fstP p = a p
useP :: P %1 -> Int
useP p = a p + b p
boxSum :: Box -> Int
boxSum x = a (inner x) + b (inner x) + tag x
main :: Int
main = ";

fn program(seed: u64) -> String {
    let mut g = Gen {
        state: seed | 1,
        fresh: 0,
    };
    let body = g.int_expr(5, &[], &[]);
    format!("{PRELUDE}{body}\n")
}

#[test]
fn generated_linear_programs_reclaim_exactly() {
    let dir = std::env::temp_dir().join(format!("axion-propmem-{}", std::process::id()));
    std::fs::create_dir_all(&dir).unwrap();

    let n = 300u64;
    for seed in 1..=n {
        let src = program(seed.wrapping_mul(0x9E37_79B9_7F4A_7C15));
        let path = dir.join(format!("g{seed}.axi"));
        std::fs::write(&path, &src).unwrap();
        let p = path.to_str().unwrap();

        // native (--dev) with heap counters
        let native = axionc()
            .args(["--backend", "cranelift", p])
            .env("AXION_HEAP_STATS", "1")
            .output()
            .unwrap();
        assert!(
            native.status.success(),
            "seed {seed}: native failed (possible corruption)\n--- program ---\n{src}\n--- stderr ---\n{}",
            String::from_utf8_lossy(&native.stderr)
        );
        let nres = String::from_utf8_lossy(&native.stdout).trim().to_string();
        let stats = String::from_utf8_lossy(&native.stderr);
        let line = stats
            .lines()
            .find(|l| l.contains("heap:"))
            .unwrap_or_else(|| panic!("seed {seed}: no heap stats"));
        // "heap: N allocs, M frees"
        let nums: Vec<u64> = line
            .split(|c: char| !c.is_ascii_digit())
            .filter(|s| !s.is_empty())
            .map(|s| s.parse().unwrap())
            .collect();
        assert_eq!(
            nums[0], nums[1],
            "seed {seed}: leak/double-free ({} allocs != {} frees)\n{src}",
            nums[0], nums[1]
        );

        // agreement with the interpreter
        let interp = axionc().arg(p).output().unwrap();
        assert!(interp.status.success(), "seed {seed}: interp failed\n{src}");
        let ires = String::from_utf8_lossy(&interp.stdout).trim().to_string();
        assert_eq!(
            nres, ires,
            "seed {seed}: native={nres} != interp={ires}\n{src}"
        );
    }
    let _ = std::fs::remove_dir_all(&dir);
}
