//! Axión native runtime (Rust) — docs/rust-runtime-port.md.
//!
//! Stage 1: arbitrary-precision Integer (bignum). REUSES axionc's tested, dependency-free
//! `src/bigint.rs` (its doc-comment already anticipates "the same representation … mirrored in the
//! C runtime"), replacing the hand-written C `bn_divmod` et al. — the one place a real memory bug
//! (double-free / unfreed long-division scratch) ever shipped. `BigInt`'s `Vec`-backed limbs mean
//! that whole bug class (manual `malloc`/`free` of intermediates) cannot occur.
//!
//! An `Integer` value is an OPAQUE boxed `BigInt` passed across the FFI as an i64 handle; only these
//! `axion_bignum_*` functions ever create, inspect, or free it, so the box layout need not match the
//! old C `BigNum` struct. All bignum symbols live here (the C runtime's bignum section is removed),
//! so a handle is never mixed between the two representations.

#![allow(clippy::missing_safety_doc)]

// Share axionc's bignum source verbatim (it is dependency-free — no `crate::` references), so the
// runtime and the interpreter compute Integers with the exact same, already-tested code.
#[path = "../../axionc/src/bigint.rs"]
mod bigint;
use bigint::BigInt;
use std::cmp::Ordering;

extern "C" {
    // The header-carrying allocator, still provided by the (remaining) C runtime: `String` results
    // carry the `axion_alloc` size header so `axion_str_drop` reclaims them (like `show_int`).
    fn axion_alloc(size: i64) -> i64;
}

#[inline]
fn box_bn(b: BigInt) -> i64 {
    Box::into_raw(Box::new(b)) as i64
}

/// SAFETY: `p` is a handle previously returned by an `axion_bignum_*` producer and not yet freed.
#[inline]
unsafe fn bn<'a>(p: i64) -> &'a BigInt {
    &*(p as *const BigInt)
}

fn div_by_zero() -> ! {
    eprintln!("Integer: divide by zero");
    std::process::exit(1);
}

#[no_mangle]
pub extern "C" fn axion_bignum_from_i64(n: i64) -> i64 {
    box_bn(BigInt::from_i64(n))
}

#[no_mangle]
pub unsafe extern "C" fn axion_bignum_from_str(sp: i64) -> i64 {
    let cs = std::ffi::CStr::from_ptr(sp as *const std::os::raw::c_char);
    box_bn(BigInt::from_str(cs.to_str().unwrap_or("0")))
}

/// Reclaim a boxed Integer (a no-op on a null handle, matching the C).
#[no_mangle]
pub unsafe extern "C" fn axion_bignum_free(p: i64) {
    if p != 0 {
        drop(Box::from_raw(p as *mut BigInt));
    }
}

#[no_mangle]
pub unsafe extern "C" fn axion_bignum_copy(a: i64) -> i64 {
    box_bn(bn(a).clone())
}

#[no_mangle]
pub unsafe extern "C" fn axion_bignum_add(a: i64, b: i64) -> i64 {
    box_bn(bn(a).add(bn(b)))
}
#[no_mangle]
pub unsafe extern "C" fn axion_bignum_sub(a: i64, b: i64) -> i64 {
    box_bn(bn(a).sub(bn(b)))
}
#[no_mangle]
pub unsafe extern "C" fn axion_bignum_mul(a: i64, b: i64) -> i64 {
    box_bn(bn(a).mul(bn(b)))
}

/// Truncated division (quotient toward zero) — `divmod` returns `None` only on a zero divisor.
#[no_mangle]
pub unsafe extern "C" fn axion_bignum_div(a: i64, b: i64) -> i64 {
    match bn(a).divmod(bn(b)) {
        Some((q, _)) => box_bn(q),
        None => div_by_zero(),
    }
}
#[no_mangle]
pub unsafe extern "C" fn axion_bignum_mod(a: i64, b: i64) -> i64 {
    match bn(a).divmod(bn(b)) {
        Some((_, r)) => box_bn(r),
        None => div_by_zero(),
    }
}

#[no_mangle]
pub unsafe extern "C" fn axion_bignum_eq(a: i64, b: i64) -> i64 {
    i64::from(bn(a).cmp(bn(b)) == Ordering::Equal)
}
#[no_mangle]
pub unsafe extern "C" fn axion_bignum_lt(a: i64, b: i64) -> i64 {
    i64::from(bn(a).cmp(bn(b)) == Ordering::Less)
}
#[no_mangle]
pub unsafe extern "C" fn axion_bignum_gt(a: i64, b: i64) -> i64 {
    i64::from(bn(a).cmp(bn(b)) == Ordering::Greater)
}

/// `showInteger` — the shortest decimal, into a fresh header-carrying (reclaimable) heap String.
#[no_mangle]
pub unsafe extern "C" fn axion_bignum_to_string(p: i64) -> i64 {
    let s = bn(p).to_string(); // Display: optional leading '-', then digits, no leading zeros
    let bytes = s.as_bytes();
    let buf = axion_alloc(bytes.len() as i64 + 1) as *mut u8;
    std::ptr::copy_nonoverlapping(bytes.as_ptr(), buf, bytes.len());
    *buf.add(bytes.len()) = 0; // NUL terminator
    buf as i64
}
