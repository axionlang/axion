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
    // The header-carrying allocator/free, still provided by the (remaining) C runtime (Stage 3):
    // `String` results carry the `axion_alloc` size header so `axion_str_drop` reclaims them.
    fn axion_alloc(size: i64) -> i64;
    fn axion_free(ptr: i64);
}

// ─── strings / IO (Stage 2a) ─────────────────────────────────────────────────────────────────
// A `String` is a NUL-terminated byte buffer passed as an i64 pointer; heap ones carry the
// `axion_alloc` size header at offset −8 (so `axion_str_drop` reclaims them and skips `.rodata`
// literals, which have a zero header). All stdout goes through this one path (flushed to match the
// old C `fflush`), so there is no C/Rust buffer interleaving.

/// The bytes of a runtime `String` (excluding the NUL). SAFETY: `s` is a live NUL-terminated String.
#[inline]
unsafe fn str_bytes<'a>(s: i64) -> &'a [u8] {
    std::ffi::CStr::from_ptr(s as *const std::os::raw::c_char).to_bytes()
}

/// Copy `bytes` into a fresh header-carrying (reclaimable) heap String (NUL-terminated).
unsafe fn alloc_str(bytes: &[u8]) -> i64 {
    let p = axion_alloc(bytes.len() as i64 + 1);
    let dst = p as *mut u8;
    std::ptr::copy_nonoverlapping(bytes.as_ptr(), dst, bytes.len());
    *dst.add(bytes.len()) = 0;
    p
}

fn write_out(bytes: &[u8], newline: bool) {
    use std::io::Write;
    let mut o = std::io::stdout().lock();
    let _ = o.write_all(bytes);
    if newline {
        let _ = o.write_all(b"\n");
    }
    let _ = o.flush(); // match the old C `fflush(stdout)` — keeps ordering with any remaining output
}
fn write_err(bytes: &[u8], newline: bool) {
    use std::io::Write;
    let mut e = std::io::stderr().lock();
    let _ = e.write_all(bytes);
    if newline {
        let _ = e.write_all(b"\n");
    }
}

#[no_mangle]
pub unsafe extern "C" fn axion_puts(s: i64) {
    write_out(str_bytes(s), true);
}
#[no_mangle]
pub unsafe extern "C" fn axion_put(s: i64) {
    write_out(str_bytes(s), false);
}
#[no_mangle]
pub unsafe extern "C" fn axion_eput(s: i64) {
    write_err(str_bytes(s), false);
}
#[no_mangle]
pub unsafe extern "C" fn axion_eputs(s: i64) {
    write_err(str_bytes(s), true);
}

/// Drop a `String`: heap strings have a nonzero `axion_alloc` header at −8; literals have a zero
/// header (static `.rodata`) and are skipped.
#[no_mangle]
pub unsafe extern "C" fn axion_str_drop(s: i64) {
    if s != 0 && *((s - 8) as *const i64) != 0 {
        axion_free(s);
    }
}

#[no_mangle]
pub unsafe extern "C" fn axion_show_int(n: i64) -> i64 {
    alloc_str(n.to_string().as_bytes())
}

/// `main :: Float` printer — the shortest round-tripping decimal (Rust's `{}`), matching interp.
#[no_mangle]
pub extern "C" fn axion_print_float(d: f64) {
    write_out(fmt_float(d).as_bytes(), true);
}

/// `show :: Float -> String` — the arg is the f64 bit-pattern in an i64.
#[no_mangle]
pub unsafe extern "C" fn axion_show_float(bits: i64) -> i64 {
    alloc_str(fmt_float(f64::from_bits(bits as u64)).as_bytes())
}

/// Shortest round-tripping decimal. Rust's `{}` for `f64` is already shortest-round-trip, EXCEPT it
/// omits a decimal point for integral values — the old C `%g` path prints e.g. `2` for `2.0`, so
/// match that (whole floats show without a fractional part).
fn fmt_float(d: f64) -> String {
    if d.is_finite() && d == d.trunc() && d.abs() < 1e16 {
        format!("{}", d as i64)
    } else {
        format!("{d}")
    }
}

/// `a ++ b` — concatenate two NUL-terminated Strings into a fresh heap String.
#[no_mangle]
pub unsafe extern "C" fn axion_strcat(a: i64, b: i64) -> i64 {
    let (x, y) = (str_bytes(a), str_bytes(b));
    let mut v = Vec::with_capacity(x.len() + y.len());
    v.extend_from_slice(x);
    v.extend_from_slice(y);
    alloc_str(&v)
}

#[no_mangle]
pub unsafe extern "C" fn axion_str_len(s: i64) -> i64 {
    str_bytes(s).len() as i64
}

/// `charAt i s` — the byte at index `i`, or −1 out of bounds.
#[no_mangle]
pub unsafe extern "C" fn axion_str_at(i: i64, s: i64) -> i64 {
    let x = str_bytes(s);
    if i < 0 || i as usize >= x.len() {
        -1
    } else {
        i64::from(x[i as usize])
    }
}

/// Byte-lexicographic compare, normalised to −1/0/1 (`Eq`/`Ord String`).
#[no_mangle]
pub unsafe extern "C" fn axion_str_cmp(a: i64, b: i64) -> i64 {
    match str_bytes(a).cmp(str_bytes(b)) {
        Ordering::Less => -1,
        Ordering::Equal => 0,
        Ordering::Greater => 1,
    }
}

/// `substr start len s` — `len` bytes from `start`, both clamped to the string's bounds.
#[no_mangle]
pub unsafe extern "C" fn axion_substr(start: i64, len: i64, s: i64) -> i64 {
    let x = str_bytes(s);
    let n = x.len() as i64;
    let start = start.clamp(0, n);
    let avail = n - start;
    let take = len.clamp(0, avail);
    alloc_str(&x[start as usize..(start + take) as usize])
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
