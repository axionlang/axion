// A build script: panicking (via unwrap/expect) IS the correct failure path.
#![allow(clippy::unwrap_used, clippy::expect_used)]
//! Builds the Rust native-runtime staticlib (`axion-rt`, docs/rust-runtime-port.md) and hands its
//! path to the compiler via `AXION_RT_LIB`, so `llvm.rs` can `include_bytes!` it and link it into
//! `--release` executables. `axion-rt` IS the whole runtime now (the C is fully ported + gone), and
//! the `--dev` Cranelift JIT links the same crate as an rlib dependency — one runtime for both
//! backends. This staticlib build is heap-stats-free (zero alloc-path overhead); the `--dev` rlib
//! enables `heap-stats`. Only for native, non-wasm builds — the wasm playground has no backend.

use std::path::PathBuf;
use std::process::Command;

fn main() {
    // Only the native backends link the runtime; the wasm build has none.
    if std::env::var_os("CARGO_FEATURE_NATIVE").is_none() {
        return;
    }
    if std::env::var("CARGO_CFG_TARGET_ARCH").as_deref() == Ok("wasm32") {
        return;
    }

    let manifest = PathBuf::from(std::env::var("CARGO_MANIFEST_DIR").unwrap());
    let rt = manifest.parent().unwrap().join("axion-rt");
    let out = PathBuf::from(std::env::var("OUT_DIR").unwrap());
    let rt_target = out.join("rt-target");
    let cargo = std::env::var("CARGO").unwrap_or_else(|_| "cargo".into());

    let status = Command::new(&cargo)
        .arg("build")
        .arg("--release")
        .arg("--manifest-path")
        .arg(rt.join("Cargo.toml"))
        .arg("--target-dir")
        .arg(&rt_target)
        .status()
        .expect("failed to invoke cargo to build axion-rt");
    assert!(status.success(), "axion-rt staticlib build failed");

    let lib = rt_target.join("release").join("libaxion_rt.a");
    assert!(
        lib.exists(),
        "axion-rt staticlib not found at {}",
        lib.display()
    );
    println!("cargo:rustc-env=AXION_RT_LIB={}", lib.display());

    println!("cargo:rerun-if-changed={}", rt.join("src/lib.rs").display());
    println!("cargo:rerun-if-changed={}", rt.join("Cargo.toml").display());
    println!(
        "cargo:rerun-if-changed={}",
        manifest.join("src/bigint.rs").display()
    );
}
