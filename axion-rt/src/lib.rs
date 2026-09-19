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

// ─── heap-stats counters (feature `heap-stats`) ──────────────────────────────────────────────
// The Cranelift `--dev` JIT enables this feature to power `AXION_HEAP_STATS` accounting (the
// reclamation tests assert allocs == frees on `--dev`). The `--release` staticlib (built
// separately by axionc's build.rs) is built WITHOUT it, so the hot alloc/free path carries zero
// counter overhead there. Relaxed atomics: exact totals, no ordering needed.
#[cfg(feature = "heap-stats")]
mod stats {
    use std::sync::atomic::AtomicU64;
    pub(crate) static HEAP_ALLOCS: AtomicU64 = AtomicU64::new(0);
    pub(crate) static HEAP_FREES: AtomicU64 = AtomicU64::new(0);
    pub(crate) static ARENA_NEWS: AtomicU64 = AtomicU64::new(0);
    pub(crate) static ARENA_RESETS: AtomicU64 = AtomicU64::new(0);
    pub(crate) static CELL_ALLOCS: AtomicU64 = AtomicU64::new(0);
}

/// One heap-stat increment; a no-op unless built with the `heap-stats` feature.
macro_rules! stat_inc {
    ($c:ident) => {{
        #[cfg(feature = "heap-stats")]
        crate::stats::$c.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
    }};
}

/// `(heap_allocs, heap_frees, arena_news, arena_resets, cell_allocs)` since process start.
/// Populated only when built with the `heap-stats` feature (the `--dev` rlib); all zero otherwise.
#[must_use]
pub fn heap_stats() -> (u64, u64, u64, u64, u64) {
    #[cfg(feature = "heap-stats")]
    {
        use std::sync::atomic::Ordering::Relaxed;
        (
            stats::HEAP_ALLOCS.load(Relaxed),
            stats::HEAP_FREES.load(Relaxed),
            stats::ARENA_NEWS.load(Relaxed),
            stats::ARENA_RESETS.load(Relaxed),
            stats::CELL_ALLOCS.load(Relaxed),
        )
    }
    #[cfg(not(feature = "heap-stats"))]
    (0, 0, 0, 0, 0)
}

// ─── heap allocator with a size header (Stage 3a) ────────────────────────────────────────────
// The Axión heap block: `[total: i64 header][payload…]`, `axion_alloc` returns the payload pointer
// (base+8) and `axion_free` reads the header at −8. Backed by `libc::malloc`/`free`. `unsafe` is
// confined here and mirrors the original C layout exactly (so pre-port blocks stay compatible).

fn oom() -> ! {
    eprintln!("axion: out of memory");
    std::process::exit(1);
}

#[no_mangle]
pub unsafe extern "C" fn axion_alloc(size: i64) -> i64 {
    let total = (if size < 1 { 1 } else { size }) + 8;
    let base = libc::malloc(total as usize) as *mut u8;
    if base.is_null() {
        oom();
    }
    *(base as *mut i64) = total; // size header
    stat_inc!(HEAP_ALLOCS);
    base.add(8) as i64
}

#[no_mangle]
pub unsafe extern "C" fn axion_free(ptr: i64) {
    // a tagged immediate (low bit set: a nullary constructor of a mixed sum type) is not a heap
    // allocation — nothing to free.
    if ptr & 1 != 0 {
        return;
    }
    libc::free((ptr as *mut u8).sub(8) as *mut libc::c_void);
    stat_inc!(HEAP_FREES);
}

/// Shallow byte-copy of an `axion_alloc`'d block, reading its total size from the −8 header (R-5).
/// A tagged immediate (low bit) or null is returned as-is.
#[no_mangle]
pub unsafe extern "C" fn axion_block_copy(ptr: i64) -> i64 {
    if ptr & 1 != 0 || ptr == 0 {
        return ptr;
    }
    let base = (ptr as *mut u8).sub(8);
    let total = *(base as *const i64);
    let nb = libc::malloc(total as usize) as *mut u8;
    if nb.is_null() {
        oom();
    }
    std::ptr::copy_nonoverlapping(base, nb, total as usize);
    stat_inc!(HEAP_ALLOCS);
    nb.add(8) as i64
}

// ─── flat collections (Stage 3c) ─────────────────────────────────────────────────────────────
// Buffers/Arrays are `[len:i64][elems…]` blocks allocated with `libc::malloc` and freed with
// `libc::free` (no −8 header). TritVec/I8/I32 are allocated with `axion_alloc` (header at −8) and
// freed by the generic `axion_free`. Each type keeps its C alloc/free pairing exactly, so blocks
// stay interchangeable during the transition. The reductions are tight slice loops the way the C
// was, so `-O2` autovectorizes them; `unsafe` is confined to the pointer/length reads.

#[inline]
unsafe fn blen(p: i64) -> i64 {
    *(p as *const i64)
}
#[inline]
fn bounds_abort(kind: &str, idx: i64, n: i64) -> ! {
    eprintln!("axion: {kind} bounds — index {idx} out of range [0, {n})");
    std::process::abort();
}
#[inline]
fn len_mismatch(kind: &str, n: i64, m: i64) -> ! {
    eprintln!("axion: {kind} — length mismatch {n} vs {m}");
    std::process::abort();
}

// Balanced-ternary decode LUT (§10.C): TRIT_LUT[byte][k] = weight (−1/0/+1) of the k-th packed trit.
// Computed at compile time (const), replacing the C `__attribute__((constructor))` init.
const fn build_trit_lut() -> [[i8; 5]; 256] {
    let mut lut = [[0i8; 5]; 256];
    let mut b = 0usize;
    while b < 243 {
        let mut x = b;
        let mut k = 0usize;
        while k < 5 {
            lut[b][k] = (x % 3) as i8 - 1;
            x /= 3;
            k += 1;
        }
        b += 1;
    }
    lut
}
const TRIT_LUT: [[i8; 5]; 256] = build_trit_lut();
const POW3: [i64; 5] = [1, 3, 9, 27, 81];

// --- linear U8 Buffer: [len][bytes…], libc-malloc/free ---
#[no_mangle]
pub unsafe extern "C" fn axion_buf_new(n: i64) -> i64 {
    let bytes = if n < 0 { 0 } else { n } as usize;
    let b = libc::malloc(8 + bytes) as *mut u8;
    if b.is_null() {
        oom();
    }
    *(b as *mut i64) = n;
    std::ptr::write_bytes(b.add(8), 0, bytes);
    b as i64
}
#[no_mangle]
pub unsafe extern "C" fn axion_buf_iota(buf: i64) -> i64 {
    let n = blen(buf);
    let d = (buf as *mut u8).add(8);
    for i in 0..n {
        *d.add(i as usize) = (i & 0xFF) as u8;
    }
    buf
}
#[no_mangle]
pub unsafe extern "C" fn axion_buf_xor(buf: i64, key: i64) -> i64 {
    let n = blen(buf);
    let d = (buf as *mut u8).add(8);
    for i in 0..n as usize {
        *d.add(i) ^= key as u8;
    }
    buf
}
#[no_mangle]
pub unsafe extern "C" fn axion_buf_sum(buf: i64) -> i64 {
    let n = blen(buf) as usize;
    let d = std::slice::from_raw_parts((buf as *const u8).add(8), n);
    d.iter().map(|&x| x as i64).sum()
}
#[no_mangle]
pub unsafe extern "C" fn axion_buf_free(buf: i64) -> i64 {
    libc::free(buf as *mut libc::c_void);
    0
}

// --- linear dense Array (i64): [len][elem…], libc-malloc/free ---
#[no_mangle]
pub unsafe extern "C" fn axion_array_new(len: i64, init: i64) -> i64 {
    let n = if len < 0 { 0 } else { len };
    let b = libc::malloc(8 + n as usize * 8) as *mut u8;
    if b.is_null() {
        oom();
    }
    *(b as *mut i64) = n;
    let d = b.add(8) as *mut i64;
    for i in 0..n as usize {
        *d.add(i) = init;
    }
    b as i64
}
#[no_mangle]
pub unsafe extern "C" fn axion_array_get(arr: i64, idx: i64) -> i64 {
    let n = blen(arr);
    if idx < 0 || idx >= n {
        bounds_abort("array", idx, n);
    }
    *(arr as *const u8).add(8).cast::<i64>().add(idx as usize)
}
#[no_mangle]
pub unsafe extern "C" fn axion_array_set(arr: i64, idx: i64, val: i64) -> i64 {
    let n = blen(arr);
    if idx < 0 || idx >= n {
        bounds_abort("array", idx, n);
    }
    *(arr as *mut u8).add(8).cast::<i64>().add(idx as usize) = val;
    arr
}
#[no_mangle]
pub unsafe extern "C" fn axion_array_len(arr: i64) -> i64 {
    blen(arr)
}
#[no_mangle]
pub unsafe extern "C" fn axion_array_free(arr: i64) {
    libc::free(arr as *mut libc::c_void);
}
#[no_mangle]
pub unsafe extern "C" fn axion_array_sum(arr: i64) -> i64 {
    let n = blen(arr) as usize;
    let d = std::slice::from_raw_parts((arr as *const u8).add(8).cast::<i64>(), n);
    d.iter().sum()
}
#[no_mangle]
pub unsafe extern "C" fn axion_array_dot(a: i64, b: i64) -> i64 {
    let (n, m) = (blen(a), blen(b));
    if n != m {
        len_mismatch("array_dot", n, m);
    }
    let da = std::slice::from_raw_parts((a as *const u8).add(8).cast::<i64>(), n as usize);
    let db = std::slice::from_raw_parts((b as *const u8).add(8).cast::<i64>(), n as usize);
    da.iter().zip(db).map(|(&x, &y)| x * y).sum()
}
#[no_mangle]
pub unsafe extern "C" fn axion_array_iota(len: i64) -> i64 {
    let n = if len < 0 { 0 } else { len };
    let b = libc::malloc(8 + n as usize * 8) as *mut u8;
    if b.is_null() {
        oom();
    }
    *(b as *mut i64) = n;
    let d = b.add(8) as *mut i64;
    for i in 0..n {
        *d.add(i as usize) = i;
    }
    b as i64
}

// --- TritVec: base-243 packed balanced ternary, axion_alloc/axion_free ---
#[no_mangle]
pub unsafe extern "C" fn axion_tritvec_new(len: i64, init_weight: i64) -> i64 {
    let n = if len < 0 { 0 } else { len };
    let d = (init_weight + 1).clamp(0, 2);
    let nbytes = (n + 4) / 5;
    let p = axion_alloc(8 + nbytes);
    *(p as *mut i64) = n;
    let data = (p as *mut u8).add(8);
    let packed = (d * 121) as u8; // 121 = 1+3+9+27+81
    for i in 0..nbytes as usize {
        *data.add(i) = packed;
    }
    p
}
#[no_mangle]
pub unsafe extern "C" fn axion_tritvec_get(tv: i64, idx: i64) -> i64 {
    let n = blen(tv);
    if idx < 0 || idx >= n {
        bounds_abort("tritvec", idx, n);
    }
    let data = (tv as *const u8).add(8);
    i64::from(TRIT_LUT[*data.add((idx / 5) as usize) as usize][(idx % 5) as usize])
}
#[no_mangle]
pub unsafe extern "C" fn axion_tritvec_set(tv: i64, idx: i64, weight: i64) -> i64 {
    let n = blen(tv);
    if idx < 0 || idx >= n {
        bounds_abort("tritvec", idx, n);
    }
    let d = (weight + 1).clamp(0, 2);
    let data = (tv as *mut u8).add(8);
    let place = POW3[(idx % 5) as usize];
    let byte = i64::from(*data.add((idx / 5) as usize));
    let old_digit = i64::from(TRIT_LUT[byte as usize][(idx % 5) as usize]) + 1;
    *data.add((idx / 5) as usize) = (byte + (d - old_digit) * place) as u8;
    tv
}
#[no_mangle]
pub unsafe extern "C" fn axion_tritvec_len(tv: i64) -> i64 {
    blen(tv)
}
#[no_mangle]
pub unsafe extern "C" fn axion_tritvec_iota(len: i64) -> i64 {
    let n = if len < 0 { 0 } else { len };
    let nbytes = (n + 4) / 5;
    let p = axion_alloc(8 + nbytes);
    *(p as *mut i64) = n;
    let data = (p as *mut u8).add(8);
    for b in 0..nbytes {
        let base = b * 5;
        let mut byte = 0i64;
        let mut k = 0i64;
        while k < 5 && base + k < n {
            let w = ((base + k) % 3) - 1;
            byte += (w + 1) * POW3[k as usize];
            k += 1;
        }
        *data.add(b as usize) = byte as u8;
    }
    p
}

// --- I8Array: compact signed bytes, axion_alloc/axion_free ---
#[no_mangle]
pub unsafe extern "C" fn axion_i8_new(len: i64, init: i64) -> i64 {
    let n = if len < 0 { 0 } else { len };
    let p = axion_alloc(8 + n);
    *(p as *mut i64) = n;
    let d = (p as *mut i8).byte_add(8);
    for i in 0..n as usize {
        *d.add(i) = init as i8;
    }
    p
}
#[no_mangle]
pub unsafe extern "C" fn axion_i8_iota(len: i64) -> i64 {
    let n = if len < 0 { 0 } else { len };
    let p = axion_alloc(8 + n);
    *(p as *mut i64) = n;
    let d = (p as *mut i8).byte_add(8);
    let mut i = 0i64;
    while i + 3 <= n {
        *d.add(i as usize) = -1;
        *d.add(i as usize + 1) = 0;
        *d.add(i as usize + 2) = 1;
        i += 3;
    }
    while i < n {
        *d.add(i as usize) = ((i % 3) - 1) as i8;
        i += 1;
    }
    p
}
#[no_mangle]
pub unsafe extern "C" fn axion_i8_get(arr: i64, idx: i64) -> i64 {
    let n = blen(arr);
    if idx < 0 || idx >= n {
        bounds_abort("i8", idx, n);
    }
    i64::from(*(arr as *const i8).byte_add(8).add(idx as usize))
}
#[no_mangle]
pub unsafe extern "C" fn axion_i8_set(arr: i64, idx: i64, val: i64) -> i64 {
    let n = blen(arr);
    if idx < 0 || idx >= n {
        bounds_abort("i8", idx, n);
    }
    *(arr as *mut i8).byte_add(8).add(idx as usize) = val as i8;
    arr
}
#[no_mangle]
pub unsafe extern "C" fn axion_i8_len(arr: i64) -> i64 {
    blen(arr)
}
#[no_mangle]
pub unsafe extern "C" fn axion_i8_sum(arr: i64) -> i64 {
    let n = blen(arr) as usize;
    let d = std::slice::from_raw_parts((arr as *const i8).byte_add(8), n);
    d.iter().map(|&x| x as i64).sum()
}
#[no_mangle]
pub unsafe extern "C" fn axion_i8_dot(arr: i64, act_arr: i64) -> i64 {
    let (n, m) = (blen(arr), blen(act_arr));
    if n != m {
        len_mismatch("i8_dot", n, m);
    }
    let w = std::slice::from_raw_parts((arr as *const i8).byte_add(8), n as usize);
    let act = std::slice::from_raw_parts((act_arr as *const u8).add(8).cast::<i64>(), n as usize);
    w.iter().zip(act).map(|(&x, &y)| x as i64 * y).sum()
}
#[no_mangle]
pub unsafe extern "C" fn axion_i8_dot_i8(a: i64, b: i64) -> i64 {
    let (n, m) = (blen(a), blen(b));
    if n != m {
        len_mismatch("i8_dot_i8", n, m);
    }
    let wa = std::slice::from_raw_parts((a as *const i8).byte_add(8), n as usize);
    let wb = std::slice::from_raw_parts((b as *const i8).byte_add(8), n as usize);
    // Blocked: accumulate int8×int8 into an i32 partial within safe chunks (so the inner loop
    // vectorizes — it won't into an i64 acc), then flush. BLK*127*127 < i32::MAX.
    const BLK: usize = 32768;
    let mut acc: i64 = 0;
    for chunk in wa.chunks(BLK).zip(wb.chunks(BLK)) {
        let (ca, cb) = chunk;
        let mut part: i32 = 0;
        for (&x, &y) in ca.iter().zip(cb) {
            part += i32::from(x) * i32::from(y);
        }
        acc += i64::from(part);
    }
    acc
}
#[no_mangle]
pub unsafe extern "C" fn axion_i8_matvec_sum(arr: i64, act_arr: i64, k_width: i64) -> i64 {
    let n = blen(arr);
    let alen = blen(act_arr);
    if k_width <= 0 || alen < k_width {
        len_mismatch("i8_matvec_sum", k_width, alen);
    }
    let w = std::slice::from_raw_parts((arr as *const i8).byte_add(8), n as usize);
    let act = std::slice::from_raw_parts((act_arr as *const u8).add(8).cast::<i64>(), alen as usize);
    let mut acc = 0i64;
    let mut k = 0usize;
    for &wi in w {
        acc += i64::from(wi) * *act.get_unchecked(k);
        k += 1;
        if k == k_width as usize {
            k = 0;
        }
    }
    acc
}

// --- I32Array: compact signed 32-bit, axion_alloc/axion_free ---
#[no_mangle]
pub unsafe extern "C" fn axion_i32_new(len: i64, init: i64) -> i64 {
    let n = if len < 0 { 0 } else { len };
    let p = axion_alloc(8 + n * 4);
    *(p as *mut i64) = n;
    let d = (p as *mut i32).byte_add(8);
    for i in 0..n as usize {
        *d.add(i) = init as i32;
    }
    p
}
#[no_mangle]
pub unsafe extern "C" fn axion_i32_iota(len: i64) -> i64 {
    let n = if len < 0 { 0 } else { len };
    let p = axion_alloc(8 + n * 4);
    *(p as *mut i64) = n;
    let d = (p as *mut i32).byte_add(8);
    for i in 0..n {
        *d.add(i as usize) = i as i32;
    }
    p
}
#[no_mangle]
pub unsafe extern "C" fn axion_i32_get(arr: i64, idx: i64) -> i64 {
    let n = blen(arr);
    if idx < 0 || idx >= n {
        bounds_abort("i32", idx, n);
    }
    i64::from(*(arr as *const i32).byte_add(8).add(idx as usize))
}
#[no_mangle]
pub unsafe extern "C" fn axion_i32_set(arr: i64, idx: i64, val: i64) -> i64 {
    let n = blen(arr);
    if idx < 0 || idx >= n {
        bounds_abort("i32", idx, n);
    }
    *(arr as *mut i32).byte_add(8).add(idx as usize) = val as i32;
    arr
}
#[no_mangle]
pub unsafe extern "C" fn axion_i32_len(arr: i64) -> i64 {
    blen(arr)
}
#[no_mangle]
pub unsafe extern "C" fn axion_i32_sum(arr: i64) -> i64 {
    let n = blen(arr) as usize;
    let d = std::slice::from_raw_parts((arr as *const i32).byte_add(8), n);
    d.iter().map(|&x| x as i64).sum()
}
#[no_mangle]
pub unsafe extern "C" fn axion_i32_dot(arr: i64, act_arr: i64) -> i64 {
    let (n, m) = (blen(arr), blen(act_arr));
    if n != m {
        len_mismatch("i32_dot", n, m);
    }
    let w = std::slice::from_raw_parts((arr as *const i32).byte_add(8), n as usize);
    let act = std::slice::from_raw_parts((act_arr as *const u8).add(8).cast::<i64>(), n as usize);
    w.iter().zip(act).map(|(&x, &y)| i64::from(x) * y).sum()
}
#[no_mangle]
pub unsafe extern "C" fn axion_i32_matvec_sum(arr: i64, act_arr: i64, k_width: i64) -> i64 {
    let n = blen(arr);
    let alen = blen(act_arr);
    if k_width <= 0 || alen < k_width {
        len_mismatch("i32_matvec_sum", k_width, alen);
    }
    let w = std::slice::from_raw_parts((arr as *const i32).byte_add(8), n as usize);
    let act = std::slice::from_raw_parts((act_arr as *const u8).add(8).cast::<i64>(), alen as usize);
    let mut acc = 0i64;
    let mut k = 0usize;
    for &wi in w {
        acc += i64::from(wi) * *act.get_unchecked(k);
        k += 1;
        if k == k_width as usize {
            k = 0;
        }
    }
    acc
}

// --- fused ternary dot / matvec (decode 5 trits/byte via LUT) ---
#[no_mangle]
pub unsafe extern "C" fn axion_tritvec_dot(tv: i64, arr: i64) -> i64 {
    let n = blen(tv);
    let alen = blen(arr);
    if alen < n {
        len_mismatch("tritvec_dot", alen, n);
    }
    let data = std::slice::from_raw_parts((tv as *const u8).add(8), ((n + 4) / 5) as usize);
    let act = std::slice::from_raw_parts((arr as *const u8).add(8).cast::<i64>(), alen as usize);
    let mut acc = 0i64;
    for (b, &byte) in data.iter().enumerate() {
        let w = &TRIT_LUT[byte as usize];
        let base = b * 5;
        if base + 5 <= n as usize {
            acc += i64::from(w[0]) * *act.get_unchecked(base)
                + i64::from(w[1]) * *act.get_unchecked(base + 1)
                + i64::from(w[2]) * *act.get_unchecked(base + 2)
                + i64::from(w[3]) * *act.get_unchecked(base + 3)
                + i64::from(w[4]) * *act.get_unchecked(base + 4);
        } else {
            let mut k = 0;
            while base + k < n as usize {
                acc += i64::from(*w.get_unchecked(k)) * *act.get_unchecked(base + k);
                k += 1;
            }
        }
    }
    acc
}
#[no_mangle]
pub unsafe extern "C" fn axion_tritvec_from_buffer(buf: i64, n: i64) -> i64 {
    let trits = if n < 0 { 0 } else { n };
    let nbytes = (trits + 4) / 5;
    let buflen = blen(buf);
    if buflen < nbytes {
        len_mismatch("tritvec_from_buffer", buflen, nbytes);
    }
    let p = axion_alloc(8 + nbytes);
    *(p as *mut i64) = trits;
    std::ptr::copy_nonoverlapping(
        (buf as *const u8).add(8),
        (p as *mut u8).add(8),
        nbytes as usize,
    );
    p
}
#[no_mangle]
pub unsafe extern "C" fn axion_tritvec_matvec_sum(tv: i64, arr: i64, k_width: i64) -> i64 {
    let n = blen(tv);
    let alen = blen(arr);
    if k_width <= 0 || alen < k_width {
        len_mismatch("tritvec_matvec_sum", k_width, alen);
    }
    let data = std::slice::from_raw_parts((tv as *const u8).add(8), ((n + 4) / 5) as usize);
    let act = std::slice::from_raw_parts((arr as *const u8).add(8).cast::<i64>(), alen as usize);
    let mut acc = 0i64;
    let mut k = 0usize;
    for (b, &byte) in data.iter().enumerate() {
        let w = &TRIT_LUT[byte as usize];
        let base = b * 5;
        let mut j = 0;
        while j < 5 && base + j < n as usize {
            acc += i64::from(*w.get_unchecked(j)) * *act.get_unchecked(k);
            k += 1;
            if k == k_width as usize {
                k = 0;
            }
            j += 1;
        }
    }
    acc
}

// --- List Int ↔ Buffer, foldBytes ---
#[no_mangle]
pub unsafe extern "C" fn axion_list_to_buf(list: i64) -> i64 {
    // Cons: tag=1 at +0, elem @ +8, tail @ +16; Nil = tagged immediate (low bit).
    let mut len = 0i64;
    let mut p = list;
    while p != 0 && p & 1 == 0 {
        if *(p as *const i64) == 1 {
            len += 1;
            p = *((p + 16) as *const i64);
        } else {
            break;
        }
    }
    let buf = axion_buf_new(len);
    let d = (buf as *mut u8).add(8);
    let mut i = 0usize;
    let mut p = list;
    while p != 0 && p & 1 == 0 {
        if *(p as *const i64) == 1 {
            *d.add(i) = (*((p + 8) as *const i64) & 0xFF) as u8;
            i += 1;
            p = *((p + 16) as *const i64);
        } else {
            break;
        }
    }
    buf
}
#[no_mangle]
pub unsafe extern "C" fn axion_buf_to_list(buf: i64) -> i64 {
    let n = blen(buf);
    let d = (buf as *const u8).add(8);
    let mut list = 1i64; // tagged Nil
    let mut i = n - 1;
    while i >= 0 {
        let cell = axion_alloc(24); // tag + elem + tail
        *(cell as *mut i64) = 1; // Cons tag
        *((cell + 8) as *mut i64) = i64::from(*d.add(i as usize));
        *((cell + 16) as *mut i64) = list;
        list = cell;
        i -= 1;
    }
    list
}
#[no_mangle]
pub unsafe extern "C" fn axion_fold_bytes(f: i64, init: i64, buf: i64) -> i64 {
    // `f` is a closure {fn_ptr, captures…}; its first word is fn_ptr(closure, acc, byte).
    let fn_ptr: extern "C" fn(i64, i64, i64) -> i64 = std::mem::transmute(*(f as *const i64));
    let n = blen(buf);
    let d = (buf as *const u8).add(8);
    let mut acc = init;
    for i in 0..n as usize {
        acc = fn_ptr(f, acc, i64::from(*d.add(i)));
    }
    acc
}

// ─── M:N session scheduler (Stage 4b) ────────────────────────────────────────────────────────
// A task is a state machine `step(sched, state) -> 1=done / 2=re-run / 0=blocked`. Tasks run on a
// pool of std::threads; ONE mutex guards the shared state, held only during channel ops — the
// `step` compute runs lock-free in parallel. Session-type linearity makes every channel SPSC, so
// the mutex is the only sync; deadlock-freedom is guaranteed by types (AX0302). Blocked tasks park
// and are woken by any send; a generation counter closes the lost-wakeup window. The `Sched` is
// shared across threads by raw i64 pointer (like the C), sound because every field access is under
// the mutex; `unsafe` covers that shared deref and the raw step-fn / state-pointer calls.

use std::collections::VecDeque;
use std::sync::{Mutex, MutexGuard};

type SessStep = extern "C" fn(i64, i64) -> i64;

struct SessEp {
    q: VecDeque<i64>,
}
struct SessTask {
    step: SessStep,
    state: i64,
}
struct Inner {
    eps: Vec<SessEp>,
    peer: Vec<usize>,
    tasks: Vec<SessTask>,
    ready: VecDeque<usize>,
    blocked: Vec<usize>,
    running: i64,
    gen: u64,
    allocs: Vec<i64>, // task-state blocks, freed in bulk at run end
    budget: i64,
    done: bool,
    result: i64,
    par: bool,        // parMap: finish when ALL tasks are done (no single root)
    ncompleted: usize,
}
struct Sched {
    m: Mutex<Inner>,
}

// panic=abort in this crate ⇒ a mutex can never be poisoned; recover the guard regardless.
#[inline]
fn lock(s: &Sched) -> MutexGuard<'_, Inner> {
    s.m.lock().unwrap_or_else(|e| e.into_inner())
}
#[inline]
unsafe fn sched<'a>(p: i64) -> &'a Sched {
    &*(p as *const Sched)
}

#[no_mangle]
pub extern "C" fn axion_sess_new() -> i64 {
    let s = Box::new(Sched {
        m: Mutex::new(Inner {
            eps: Vec::new(),
            peer: Vec::new(),
            tasks: Vec::new(),
            ready: VecDeque::new(),
            blocked: Vec::new(),
            running: 0,
            gen: 0,
            allocs: Vec::new(),
            budget: 2_000_000_000,
            done: false,
            result: 0,
            par: false,
            ncompleted: 0,
        }),
    });
    Box::into_raw(s) as i64
}

fn new_ep(inner: &mut Inner) -> usize {
    let id = inner.eps.len();
    inner.eps.push(SessEp { q: VecDeque::new() });
    inner.peer.push(0);
    id
}

#[no_mangle]
pub unsafe extern "C" fn axion_sess_channel(sched_p: i64) -> i64 {
    let mut g = lock(sched(sched_p));
    let a = new_ep(&mut g);
    let b = new_ep(&mut g);
    g.peer[a] = b;
    g.peer[b] = a;
    a as i64
}

#[no_mangle]
pub unsafe extern "C" fn axion_sess_send(sched_p: i64, ep: i64, v: i64) {
    let mut g = lock(sched(sched_p));
    let peer = g.peer[ep as usize];
    g.eps[peer].q.push_back(v);
    g.gen += 1;
    // wake every parked task (any send may unblock a receiver).
    let woken = std::mem::take(&mut g.blocked);
    for i in woken {
        g.ready.push_back(i);
    }
}

#[no_mangle]
pub unsafe extern "C" fn axion_sess_pending(sched_p: i64, ep: i64) -> i64 {
    let g = lock(sched(sched_p));
    i64::from(!g.eps[ep as usize].q.is_empty())
}

#[no_mangle]
pub unsafe extern "C" fn axion_sess_recv(sched_p: i64, ep: i64) -> i64 {
    let mut g = lock(sched(sched_p));
    g.eps[ep as usize].q.pop_front().unwrap_or(0)
}

/// A zeroed task-state block owned by the scheduler (freed in bulk at run end).
#[no_mangle]
pub unsafe extern "C" fn axion_sess_alloc(sched_p: i64, nbytes: i64) -> i64 {
    let p = libc::calloc(1, if nbytes < 8 { 8 } else { nbytes } as usize) as i64;
    if p == 0 {
        oom();
    }
    lock(sched(sched_p)).allocs.push(p);
    p
}

#[no_mangle]
pub unsafe extern "C" fn axion_sess_spawn(sched_p: i64, step: i64, state: i64) {
    let mut g = lock(sched(sched_p));
    let i = g.tasks.len();
    g.tasks.push(SessTask {
        step: std::mem::transmute::<i64, SessStep>(step),
        state,
    });
    g.ready.push_back(i);
}

/// One worker: pull a ready task, run its step WITHOUT the lock, then mark done / re-park.
unsafe fn sess_worker(sched_p: i64) {
    let s = sched(sched_p);
    loop {
        let (i, step, st, gen0) = {
            let mut g = lock(s);
            if g.done {
                return;
            }
            if g.ready.is_empty() {
                // nothing runnable: if nothing is running and tasks are parked, deadlock (types forbid).
                let stuck = g.running == 0 && !g.blocked.is_empty();
                drop(g);
                if stuck {
                    eprintln!("session scheduler: no progress (deadlock)");
                    std::process::exit(1);
                }
                std::thread::yield_now();
                continue;
            }
            g.budget -= 1;
            if g.budget <= 0 {
                eprintln!("session scheduler: budget exhausted");
                std::process::exit(1);
            }
            let i = g.ready.pop_front().unwrap_or(0);
            g.running += 1;
            let t = &g.tasks[i];
            (i, t.step, t.state, g.gen)
        };

        let fin = step(sched_p, st); // runs WITHOUT the lock (parallel)

        let mut g = lock(s);
        g.running -= 1;
        if fin == 1 {
            if g.par {
                g.ncompleted += 1;
                if g.ncompleted == g.tasks.len() {
                    g.done = true;
                }
            } else if i == 0 {
                g.result = *(st as *const i64);
                g.done = true;
            }
        } else if fin == 2 || g.gen != gen0 {
            // 2: the task looped (recursion) → re-run. Also the lost-wakeup guard: a send during
            // this step → re-run, don't park.
            g.ready.push_back(i);
        } else {
            g.blocked.push(i);
        }
    }
}

fn sess_nthreads() -> usize {
    if let Ok(env) = std::env::var("AXION_SESS_THREADS") {
        if let Ok(n) = env.parse::<usize>() {
            if n > 0 {
                return n;
            }
        }
    }
    std::thread::available_parallelism().map_or(1, |n| n.get().min(8))
}

/// Run `nthreads` workers over the scheduler until `done`, then join them.
unsafe fn run_pool(sched_p: i64) {
    let n = sess_nthreads();
    let mut handles = Vec::with_capacity(n);
    for _ in 0..n {
        let p = sched_p; // i64 is Send; each thread derefs it under the mutex.
        handles.push(std::thread::spawn(move || unsafe { sess_worker(p) }));
    }
    for h in handles {
        let _ = h.join();
    }
}

/// Free the scheduler's endpoint queues and task-state blocks, then the Sched box.
unsafe fn sess_free(sched_p: i64) -> i64 {
    let boxed = Box::from_raw(sched_p as *mut Sched);
    let inner = lock(&boxed);
    for &a in &inner.allocs {
        libc::free(a as *mut libc::c_void);
    }
    let result = inner.result;
    drop(inner);
    drop(boxed); // Vec/VecDeque fields free themselves
    result
}

/// Run the root task (task 0) on the pool until it finishes; return its result (state[0]).
#[no_mangle]
pub unsafe extern "C" fn axion_sess_run(sched_p: i64, step: i64, state: i64) -> i64 {
    axion_sess_spawn(sched_p, step, state); // root = task 0
    run_pool(sched_p);
    sess_free(sched_p)
}

/// Structured fork-join (parMap): one worker per input, preload each input, run all to completion,
/// then collect replies into a List (Cons/Nil, in input order).
#[no_mangle]
pub unsafe extern "C" fn axion_par_map(step: i64, state_size: i64, ep_slot: i64, inputs: i64) -> i64 {
    let sp = axion_sess_new();
    lock(sched(sp)).par = true;

    // count inputs (Cons chain: tag=1 @ +0, elem @ +8, tail @ +16; Nil = tagged immediate)
    let mut n = 0i64;
    let mut p = inputs;
    while p != 0 && p & 1 == 0 {
        n += 1;
        p = *((p + 16) as *const i64);
    }
    let mut pep: Vec<i64> = Vec::with_capacity(n.max(1) as usize);

    let mut p = inputs;
    while p != 0 && p & 1 == 0 {
        let v = *((p + 8) as *const i64);
        let next = *((p + 16) as *const i64);
        let a = axion_sess_channel(sp); // a = parent end, a+1 = child end
        let st = axion_sess_alloc(sp, state_size);
        *((st + ep_slot) as *mut i64) = a + 1; // the worker's endpoint parameter
        axion_sess_send(sp, a, v); // preload the input → worker's first recv
        axion_sess_spawn(sp, step, st);
        pep.push(a);
        axion_free(p); // parMap owns the input list — free each cons cell
        p = next;
    }

    if n > 0 {
        run_pool(sp);
    }

    // collect replies in input order into a Cons list.
    let mut list = 1i64; // Nil
    let mut j = n - 1;
    while j >= 0 {
        let r = axion_sess_recv(sp, pep[j as usize]);
        let cell = axion_alloc(24);
        *(cell as *mut i64) = 1; // Cons tag
        *((cell + 8) as *mut i64) = r;
        *((cell + 16) as *mut i64) = list;
        list = cell;
        j -= 1;
    }
    sess_free(sp);
    list
}

/// Run `main` (an i64()-returning fn pointer) on a thread with a large (1 GiB) stack, so deep
/// non-tail recursion grows toward RAM instead of overflowing the default stack.
#[no_mangle]
pub unsafe extern "C" fn axion_run_main(fnptr: i64) -> i64 {
    let f = std::mem::transmute::<i64, extern "C" fn() -> i64>(fnptr);
    match std::thread::Builder::new()
        .stack_size(1 << 30)
        .spawn(move || f())
    {
        Ok(h) => h.join().unwrap_or(0),
        Err(_) => f(), // fallback: run on the current stack
    }
}

// ─── networking (Stage 4a) ───────────────────────────────────────────────────────────────────
// Thin TCP syscall wrappers over an fd-based ABI (functions take/return raw fds as i64), so `libc`
// is the faithful backing (std::net's owned-fd model fights the raw-fd contract). `ax_net_recv`
// returns an `axion_alloc`'d, `axion_free`-compatible String.

/// The would-block sentinel returned by the non-blocking net ops (`ax_net_accept`/`recv`/`send`)
/// when the underlying socket is `O_NONBLOCK` and the syscall returned `EAGAIN`/`EWOULDBLOCK`. It is
/// `i64::MIN` so it can never collide with a valid fd (≥0), a byte count (≥0), a real `−errno`
/// (small, `≥ −4095`), or a heap String pointer (a positive address). The scheduler treats it as
/// "park this worker on the fd"; the compiler (Stage 3) compares against `ax_net_wouldblock()`.
pub const AX_NET_WOULDBLOCK: i64 = i64::MIN;

/// Runtime-queryable value of [`AX_NET_WOULDBLOCK`] (single source of truth for the JIT + tests).
#[no_mangle]
pub extern "C" fn ax_net_wouldblock() -> i64 {
    AX_NET_WOULDBLOCK
}

#[inline]
unsafe fn errno_is_wouldblock() -> bool {
    let e = errno();
    e == libc::EAGAIN || e == libc::EWOULDBLOCK
}

/// `ax_net_set_nonblocking(fd)` → 0 on success, `−errno` on failure. Sets `O_NONBLOCK` so the
/// accept/recv/send ops surface [`AX_NET_WOULDBLOCK`] instead of blocking the scheduler thread.
#[no_mangle]
pub unsafe extern "C" fn ax_net_set_nonblocking(fd: i64) -> i64 {
    let flags = libc::fcntl(fd as libc::c_int, libc::F_GETFL, 0);
    if flags < 0 {
        return -i64::from(errno());
    }
    if libc::fcntl(fd as libc::c_int, libc::F_SETFL, flags | libc::O_NONBLOCK) < 0 {
        return -i64::from(errno());
    }
    0
}

/// `ax_net_connect(host, port)` → fd (≥0), or −errno on failure.
#[no_mangle]
pub unsafe extern "C" fn ax_net_connect(host_ptr: i64, port: i64) -> i64 {
    let mut hints: libc::addrinfo = std::mem::zeroed();
    hints.ai_family = libc::AF_UNSPEC;
    hints.ai_socktype = libc::SOCK_STREAM;
    let mut res: *mut libc::addrinfo = std::ptr::null_mut();
    let r = libc::getaddrinfo(host_ptr as *const libc::c_char, std::ptr::null(), &hints, &mut res);
    if r != 0 || res.is_null() {
        return -i64::from(if r != 0 { r } else { libc::EAI_FAIL });
    }
    let mut fd = -1i32;
    let mut rp = res;
    while !rp.is_null() {
        fd = libc::socket((*rp).ai_family, (*rp).ai_socktype, (*rp).ai_protocol);
        if fd >= 0 {
            // patch the port into the resolved sockaddr (getaddrinfo left it 0).
            if (*rp).ai_family == libc::AF_INET {
                (*((*rp).ai_addr as *mut libc::sockaddr_in)).sin_port = (port as u16).to_be();
            } else {
                (*((*rp).ai_addr as *mut libc::sockaddr_in6)).sin6_port = (port as u16).to_be();
            }
            if libc::connect(fd, (*rp).ai_addr, (*rp).ai_addrlen) == 0 {
                break;
            }
            libc::close(fd);
            fd = -1;
        }
        rp = (*rp).ai_next;
    }
    libc::freeaddrinfo(res);
    if fd >= 0 {
        i64::from(fd)
    } else {
        -i64::from(errno())
    }
}

/// `ax_net_listen(port)` → listening fd (≥0), or −errno.
#[no_mangle]
pub unsafe extern "C" fn ax_net_listen(port: i64) -> i64 {
    let fd = libc::socket(libc::AF_INET, libc::SOCK_STREAM, 0);
    if fd < 0 {
        return -i64::from(errno());
    }
    let opt: libc::c_int = 1;
    libc::setsockopt(
        fd,
        libc::SOL_SOCKET,
        libc::SO_REUSEADDR,
        std::ptr::addr_of!(opt).cast(),
        std::mem::size_of::<libc::c_int>() as libc::socklen_t,
    );
    let mut addr: libc::sockaddr_in = std::mem::zeroed();
    addr.sin_family = libc::AF_INET as libc::sa_family_t;
    addr.sin_addr.s_addr = libc::INADDR_ANY.to_be();
    addr.sin_port = (port as u16).to_be();
    if libc::bind(
        fd,
        std::ptr::addr_of!(addr).cast(),
        std::mem::size_of::<libc::sockaddr_in>() as libc::socklen_t,
    ) < 0
        || libc::listen(fd, 128) < 0
    {
        let e = errno();
        libc::close(fd);
        return -i64::from(e);
    }
    i64::from(fd)
}

/// `ax_net_accept(listen_fd)` → client fd (≥0), [`AX_NET_WOULDBLOCK`] if the listen fd is
/// non-blocking and no connection is pending, or −errno. The accepted client fd is left in the
/// listen fd's blocking mode; the caller sets it non-blocking via `ax_net_set_nonblocking`.
#[no_mangle]
pub unsafe extern "C" fn ax_net_accept(listen_fd: i64) -> i64 {
    let c = libc::accept(listen_fd as libc::c_int, std::ptr::null_mut(), std::ptr::null_mut());
    if c >= 0 {
        i64::from(c)
    } else if errno_is_wouldblock() {
        AX_NET_WOULDBLOCK
    } else {
        -i64::from(errno())
    }
}

/// `ax_net_send(fd, data)` → bytes sent (uses strlen), or −errno.
#[no_mangle]
pub unsafe extern "C" fn ax_net_send(fd: i64, data_ptr: i64) -> i64 {
    let bytes = str_bytes(data_ptr);
    let n = libc::send(
        fd as libc::c_int,
        data_ptr as *const libc::c_void,
        bytes.len(),
        libc::MSG_NOSIGNAL,
    );
    if n >= 0 {
        n as i64
    } else if errno_is_wouldblock() {
        AX_NET_WOULDBLOCK
    } else {
        -i64::from(errno())
    }
}

/// `ax_net_recv(fd)` → a fresh `axion_free`-compatible String ("" on orderly close/error), or
/// [`AX_NET_WOULDBLOCK`] if the fd is non-blocking and no data is ready. Note "" (orderly close,
/// `recv` == 0) is DISTINCT from the would-block sentinel, so the caller can tell "peer closed"
/// (stop) from "not ready yet" (park).
#[no_mangle]
pub unsafe extern "C" fn ax_net_recv(fd: i64) -> i64 {
    let mut buf = [0u8; 4096];
    let n = libc::recv(
        fd as libc::c_int,
        buf.as_mut_ptr().cast(),
        buf.len() - 1,
        0,
    );
    if n > 0 {
        alloc_str(&buf[..n as usize])
    } else if n < 0 && errno_is_wouldblock() {
        AX_NET_WOULDBLOCK
    } else {
        alloc_str(b"")
    }
}

#[no_mangle]
pub unsafe extern "C" fn ax_net_close(fd: i64) {
    libc::close(fd as libc::c_int);
}

#[inline]
fn errno() -> i32 {
    // SAFETY: `__errno_location` returns a valid per-thread pointer.
    unsafe { *libc::__errno_location() }
}

// ─── arenas (Stage 3b) ───────────────────────────────────────────────────────────────────────
// Bump allocator over fixed 64 KiB chunks (stable pointers), bulk-reset. `unsafe` mirrors the exact
// C layout: a `Chunk` is `[prev: *mut Chunk][cap: i64][off: i64]` (24-byte header) followed by
// `cap` bytes of `data`; libc-backed so it interoperates with the remaining C heap.

const ARENA_CHUNK: i64 = 64 * 1024;

#[repr(C)]
struct ChunkHdr {
    prev: *mut ChunkHdr,
    cap: i64,
    off: i64,
    // `data[cap]` follows the header (flexible array member in the C).
}
#[repr(C)]
struct Arena {
    cur: *mut ChunkHdr,
}
#[repr(C)]
struct Mark {
    arena: *mut Arena,
    chunk: *mut ChunkHdr,
    off: i64,
}

unsafe fn chunk_new(cap: i64, prev: *mut ChunkHdr) -> *mut ChunkHdr {
    let c = libc::malloc(std::mem::size_of::<ChunkHdr>() + cap as usize) as *mut ChunkHdr;
    if c.is_null() {
        oom();
    }
    (*c).prev = prev;
    (*c).cap = cap;
    (*c).off = 0;
    c
}
#[inline]
unsafe fn chunk_data(c: *mut ChunkHdr) -> *mut u8 {
    (c as *mut u8).add(std::mem::size_of::<ChunkHdr>())
}

#[no_mangle]
pub unsafe extern "C" fn axion_arena_new() -> i64 {
    let a = libc::malloc(std::mem::size_of::<Arena>()) as *mut Arena;
    if a.is_null() {
        oom();
    }
    (*a).cur = chunk_new(ARENA_CHUNK, std::ptr::null_mut());
    stat_inc!(ARENA_NEWS);
    a as i64
}

#[no_mangle]
pub unsafe extern "C" fn axion_arena_alloc(arena: i64, size: i64) -> i64 {
    let a = arena as *mut Arena;
    let mut size = (size + 7) & !7i64;
    if size < 1 {
        size = 8;
    }
    let mut c = (*a).cur;
    if (*c).off + size > (*c).cap {
        let cap = if size > ARENA_CHUNK { size } else { ARENA_CHUNK };
        c = chunk_new(cap, (*a).cur);
        (*a).cur = c;
    }
    let p = chunk_data(c).add((*c).off as usize);
    (*c).off += size;
    stat_inc!(CELL_ALLOCS);
    p as i64
}

/// Bulk reset: free every chunk and the arena itself.
#[no_mangle]
pub unsafe extern "C" fn axion_arena_reset(arena: i64) {
    let a = arena as *mut Arena;
    let mut c = (*a).cur;
    while !c.is_null() {
        let prev = (*c).prev;
        libc::free(c as *mut libc::c_void);
        c = prev;
    }
    libc::free(a as *mut libc::c_void);
    stat_inc!(ARENA_RESETS);
}

#[no_mangle]
pub unsafe extern "C" fn axion_arena_mark(arena: i64) -> i64 {
    let a = arena as *mut Arena;
    let m = libc::malloc(std::mem::size_of::<Mark>()) as *mut Mark;
    if m.is_null() {
        oom();
    }
    (*m).arena = a;
    (*m).chunk = (*a).cur;
    (*m).off = (*(*a).cur).off;
    m as i64
}

/// Restore the bump pointer to the mark (freeing chunks allocated since).
#[no_mangle]
pub unsafe extern "C" fn axion_arena_release(mark: i64) {
    let m = mark as *mut Mark;
    let a = (*m).arena;
    while (*a).cur != (*m).chunk {
        let prev = (*(*a).cur).prev;
        libc::free((*a).cur as *mut libc::c_void);
        (*a).cur = prev;
    }
    (*(*a).cur).off = (*m).off;
    libc::free(m as *mut libc::c_void);
}

#[no_mangle]
pub unsafe extern "C" fn axion_arena_promote(target: i64, cell: i64, size: i64) -> i64 {
    let dst = axion_arena_alloc(target, size);
    std::ptr::copy_nonoverlapping(cell as *const u8, dst as *mut u8, size as usize);
    dst
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
    // A string LITERAL points into `.rodata` at an arbitrary (unaligned) byte offset, so the −8
    // header read must be unaligned; only heap strings (from `axion_alloc`) are 8-aligned there.
    if s != 0 && ((s - 8) as *const i64).read_unaligned() != 0 {
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

// ─── OS capability layer (Stage 2b) ──────────────────────────────────────────────────────────
// Effectful CLI primitives, now on `std::fs`/`std::process`/`std::io` instead of hand-written
// fork/exec/pipe/dirent C. String results are fresh reclaimable heap Strings; args are READ.

use std::ffi::OsStr;
use std::os::unix::ffi::OsStrExt;

/// A runtime `String` (i64) as an `&OsStr` path/command (bytes, not necessarily UTF-8).
#[inline]
unsafe fn os<'a>(s: i64) -> &'a OsStr {
    OsStr::from_bytes(str_bytes(s))
}

/// `getEnv name` — the env var's value, or "".
#[no_mangle]
pub unsafe extern "C" fn axion_getenv(name: i64) -> i64 {
    match std::env::var_os(os(name)) {
        Some(v) => alloc_str(v.as_bytes()),
        None => alloc_str(b""),
    }
}

/// `runCapture cmd` — run via the shell, capture stdout as a String ("" on failure).
#[no_mangle]
pub unsafe extern "C" fn axion_run(cmd: i64) -> i64 {
    match std::process::Command::new("sh").arg("-c").arg(os(cmd)).output() {
        Ok(o) => alloc_str(&o.stdout),
        Err(_) => alloc_str(b""),
    }
}

/// `runStatus cmd` — run via the shell, return the exit status (-1 if it could not run).
#[no_mangle]
pub unsafe extern "C" fn axion_system(cmd: i64) -> i64 {
    match std::process::Command::new("sh").arg("-c").arg(os(cmd)).status() {
        Ok(st) => st.code().map_or(-1, i64::from),
        Err(_) => -1,
    }
}

/// `readFile path` — the file's bytes as a String ("" if unreadable). NUL-terminated, so embedded
/// NULs truncate the text (the String model), matching the old C.
#[no_mangle]
pub unsafe extern "C" fn axion_read_file(path: i64) -> i64 {
    match std::fs::read(os(path)) {
        Ok(bytes) => alloc_str(&bytes),
        Err(_) => alloc_str(b""),
    }
}

/// `writeFile path content` — write `content` (mode 0600), truncating. 0 / -1.
#[no_mangle]
pub unsafe extern "C" fn axion_write_file(path: i64, content: i64) -> i64 {
    use std::io::Write;
    use std::os::unix::fs::OpenOptionsExt;
    let r = std::fs::OpenOptions::new()
        .write(true)
        .create(true)
        .truncate(true)
        .mode(0o600)
        .open(os(path))
        .and_then(|mut f| f.write_all(str_bytes(content)));
    if r.is_err() {
        -1
    } else {
        0
    }
}

/// `fileExists path` — 1 if it exists, else 0.
#[no_mangle]
pub unsafe extern "C" fn axion_file_exists(path: i64) -> i64 {
    i64::from(std::path::Path::new(os(path)).exists())
}

/// `makeDir path` — create `path` and any missing parents (mode 0700). Always 0 (matches the C).
#[no_mangle]
pub unsafe extern "C" fn axion_mkdir_p(path: i64) -> i64 {
    use std::os::unix::fs::DirBuilderExt;
    let _ = std::fs::DirBuilder::new().recursive(true).mode(0o700).create(os(path));
    0
}

/// `removeFile path` — unlink. 0 / -1.
#[no_mangle]
pub unsafe extern "C" fn axion_unlink(path: i64) -> i64 {
    if std::fs::remove_file(os(path)).is_err() {
        -1
    } else {
        0
    }
}

/// `renameFile from to` — rename. 0 / -1.
#[no_mangle]
pub unsafe extern "C" fn axion_rename(from: i64, to: i64) -> i64 {
    if std::fs::rename(os(from), os(to)).is_err() {
        -1
    } else {
        0
    }
}

/// `readDir path` — entries (excluding `.`/`..`, which `read_dir` already omits) joined by '\n',
/// or "" if it can't be opened. Uses the same Rust `read_dir` as the interpreter oracle.
#[no_mangle]
pub unsafe extern "C" fn axion_readdir(path: i64) -> i64 {
    let rd = match std::fs::read_dir(os(path)) {
        Ok(rd) => rd,
        Err(_) => return alloc_str(b""),
    };
    let mut buf: Vec<u8> = Vec::new();
    for ent in rd.flatten() {
        if !buf.is_empty() {
            buf.push(b'\n');
        }
        buf.extend_from_slice(ent.file_name().as_bytes());
    }
    alloc_str(&buf)
}

/// `randHex n` — `n` cryptographically-random bytes from /dev/urandom as 2n lowercase hex chars
/// (empty if n<=0 or the source is unavailable).
#[no_mangle]
pub unsafe extern "C" fn axion_rand_hex(n: i64) -> i64 {
    use std::io::Read;
    if n <= 0 {
        return alloc_str(b"");
    }
    let mut raw = vec![0u8; n as usize];
    match std::fs::File::open("/dev/urandom").and_then(|mut f| f.read_exact(&mut raw)) {
        Ok(()) => {}
        Err(_) => return alloc_str(b""),
    }
    const HX: &[u8; 16] = b"0123456789abcdef";
    let mut hex = Vec::with_capacity(2 * raw.len());
    for b in raw {
        hex.push(HX[(b >> 4) as usize]);
        hex.push(HX[(b & 15) as usize]);
    }
    alloc_str(&hex)
}

/// Read one stdin line (newline stripped, "" at EOF). With `hide` and a tty, echo is disabled for
/// the read (passphrase entry) and a newline is emitted to stderr afterward; on a pipe it degrades
/// to a plain read (so it stays testable).
unsafe fn read_line_impl(hide: bool) -> i64 {
    use std::io::BufRead;
    let mut saved: libc::termios = std::mem::zeroed();
    let is_tty = hide && libc::tcgetattr(0, &mut saved) == 0;
    if is_tty {
        let mut raw = saved;
        raw.c_lflag &= !libc::ECHO;
        libc::tcsetattr(0, libc::TCSAFLUSH, &raw);
    }
    let mut buf: Vec<u8> = Vec::new();
    {
        let mut h = std::io::stdin().lock();
        let _ = h.read_until(b'\n', &mut buf);
    }
    if buf.last() == Some(&b'\n') {
        buf.pop();
    }
    if is_tty {
        libc::tcsetattr(0, libc::TCSAFLUSH, &saved);
        write_err(b"", true); // the user's Enter wasn't echoed — emit a newline
    }
    alloc_str(&buf)
}

/// `readLine _` — one echoed stdin line. The Int arg is an ignored placeholder (forces re-read).
#[no_mangle]
pub unsafe extern "C" fn axion_read_line(_unused: i64) -> i64 {
    read_line_impl(false)
}
/// `readSecret _` — one stdin line with terminal echo OFF (passphrase entry).
#[no_mangle]
pub unsafe extern "C" fn axion_read_secret(_unused: i64) -> i64 {
    read_line_impl(true)
}

/// Shell-free exec (§pass): run `argv_joined` (argv elements '\n'-separated; argv[0] = program) with
/// NO shell — nothing word-split/glob-expanded/injection-prone — feeding `stdin_str` on stdin only
/// when non-empty (else inherit the tty, so a child's pinentry works). `want_stdout` captures the
/// child's stdout as a String; otherwise returns the exit status. "" / -1 if it can't be spawned.
unsafe fn exec_impl(argv_joined: i64, stdin_str: i64, want_stdout: bool) -> i64 {
    use std::io::{Read, Write};
    use std::process::{Command, Stdio};
    let joined = str_bytes(argv_joined);
    let fail = || if want_stdout { unsafe { alloc_str(b"") } } else { -1 };
    if joined.is_empty() || joined[0] == b'\n' {
        return fail();
    }
    let mut parts = joined.split(|&b| b == b'\n');
    let prog = parts.next().unwrap_or(b"");
    let mut cmd = Command::new(OsStr::from_bytes(prog));
    for a in parts {
        cmd.arg(OsStr::from_bytes(a));
    }
    let input = str_bytes(stdin_str);
    let feed = !input.is_empty();
    cmd.stdin(if feed { Stdio::piped() } else { Stdio::inherit() });
    cmd.stdout(if want_stdout { Stdio::piped() } else { Stdio::inherit() });
    let mut child = match cmd.spawn() {
        Ok(c) => c,
        Err(_) => return fail(),
    };
    if feed {
        if let Some(mut si) = child.stdin.take() {
            let _ = si.write_all(input); // dropped here → child sees EOF
        }
    }
    if want_stdout {
        let mut out = Vec::new();
        if let Some(mut so) = child.stdout.take() {
            let _ = so.read_to_end(&mut out);
        }
        let _ = child.wait();
        alloc_str(&out)
    } else {
        match child.wait() {
            Ok(st) => st.code().map_or(-1, i64::from),
            Err(_) => -1,
        }
    }
}

#[no_mangle]
pub unsafe extern "C" fn axion_exec_capture(argv_joined: i64, stdin_str: i64) -> i64 {
    exec_impl(argv_joined, stdin_str, true)
}
#[no_mangle]
pub unsafe extern "C" fn axion_exec_status(argv_joined: i64, stdin_str: i64) -> i64 {
    exec_impl(argv_joined, stdin_str, false)
}

/// `exitWith code` — terminate the process (never returns; the Int return sits in expr position).
#[no_mangle]
pub extern "C" fn axion_exit(code: i64) -> i64 {
    use std::io::Write;
    let _ = std::io::stdout().flush();
    std::process::exit(code as i32);
}

// Command-line arguments: a standalone `--release` binary's `main(argc, argv)` hands them here.
static ARGS: std::sync::OnceLock<Vec<Vec<u8>>> = std::sync::OnceLock::new();

#[no_mangle]
pub unsafe extern "C" fn axion_set_args(argc: i64, argv: i64) {
    let p = argv as *const *const std::os::raw::c_char;
    let mut v = Vec::with_capacity(argc.max(0) as usize);
    for i in 0..argc.max(0) {
        let s = *p.add(i as usize);
        v.push(if s.is_null() {
            Vec::new()
        } else {
            std::ffi::CStr::from_ptr(s).to_bytes().to_vec()
        });
    }
    let _ = ARGS.set(v);
}

/// Set the program arguments from Rust — for the Cranelift `--dev` JIT, whose in-process `main`
/// receives no C `argv` (the `--release` path instead calls `axion_set_args` from C `main`).
/// `args` is argv[1..] (the real arguments, no program name — matching axionc's `PROG_ARGS`); a
/// placeholder argv[0] is prepended so `axion_getarg`/`axion_getargs` index identically on both
/// native backends.
pub fn set_args_rs(args: &[String]) {
    let mut v: Vec<Vec<u8>> = Vec::with_capacity(args.len() + 1);
    v.push(b"axion".to_vec()); // placeholder for the program name (argv[0])
    for a in args {
        v.push(a.as_bytes().to_vec());
    }
    let _ = ARGS.set(v);
}

/// `getArg i` — the i-th program argument (0-based over argv[1..], excluding argv[0]), a FRESH
/// String ("" if out of range).
#[no_mangle]
pub unsafe extern "C" fn axion_getarg(i: i64) -> i64 {
    let args = ARGS.get();
    let idx = i + 1; // skip the program name
    match args {
        Some(a) if i >= 0 && (idx as usize) < a.len() => alloc_str(&a[idx as usize]),
        _ => alloc_str(b""),
    }
}

/// `getArgs _` — argv[1..] joined by '\n', a fresh String.
#[no_mangle]
pub unsafe extern "C" fn axion_getargs(_ignored: i64) -> i64 {
    let mut buf: Vec<u8> = Vec::new();
    if let Some(a) = ARGS.get() {
        for arg in a.iter().skip(1) {
            if !buf.is_empty() {
                buf.push(b'\n');
            }
            buf.extend_from_slice(arg);
        }
    }
    alloc_str(&buf)
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

/// The runtime symbols the Cranelift `--dev` JIT registers, as (name, address).
///
/// SINGLE SOURCE OF TRUTH for the runtime ABI surface: the LLVM `--release` path links these
/// same `#[no_mangle]` symbols from the staticlib, and `--dev` registers these pointers directly
/// with its JIT — so BOTH native backends now execute this one runtime (there is no second,
/// hand-maintained reimplementation to drift out of sync).
#[must_use]
pub fn runtime_symbols() -> Vec<(&'static str, *const u8)> {
    vec![
        ("axion_bignum_to_string", axion_bignum_to_string as *const u8),
        ("axion_tritvec_from_buffer", axion_tritvec_from_buffer as *const u8),
        ("axion_tritvec_matvec_sum", axion_tritvec_matvec_sum as *const u8),
        ("axion_alloc", axion_alloc as *const u8),
        ("axion_arena_alloc", axion_arena_alloc as *const u8),
        ("axion_arena_mark", axion_arena_mark as *const u8),
        ("axion_arena_new", axion_arena_new as *const u8),
        ("axion_arena_promote", axion_arena_promote as *const u8),
        ("axion_arena_release", axion_arena_release as *const u8),
        ("axion_arena_reset", axion_arena_reset as *const u8),
        ("axion_array_dot", axion_array_dot as *const u8),
        ("axion_array_free", axion_array_free as *const u8),
        ("axion_array_get", axion_array_get as *const u8),
        ("axion_array_iota", axion_array_iota as *const u8),
        ("axion_array_len", axion_array_len as *const u8),
        ("axion_array_new", axion_array_new as *const u8),
        ("axion_array_set", axion_array_set as *const u8),
        ("axion_array_sum", axion_array_sum as *const u8),
        ("axion_bignum_add", axion_bignum_add as *const u8),
        ("axion_bignum_copy", axion_bignum_copy as *const u8),
        ("axion_bignum_div", axion_bignum_div as *const u8),
        ("axion_bignum_eq", axion_bignum_eq as *const u8),
        ("axion_bignum_free", axion_bignum_free as *const u8),
        ("axion_bignum_from_i64", axion_bignum_from_i64 as *const u8),
        ("axion_bignum_from_str", axion_bignum_from_str as *const u8),
        ("axion_bignum_gt", axion_bignum_gt as *const u8),
        ("axion_bignum_lt", axion_bignum_lt as *const u8),
        ("axion_bignum_mod", axion_bignum_mod as *const u8),
        ("axion_bignum_mul", axion_bignum_mul as *const u8),
        ("axion_bignum_sub", axion_bignum_sub as *const u8),
        ("axion_block_copy", axion_block_copy as *const u8),
        ("axion_buf_free", axion_buf_free as *const u8),
        ("axion_buf_iota", axion_buf_iota as *const u8),
        ("axion_buf_new", axion_buf_new as *const u8),
        ("axion_buf_sum", axion_buf_sum as *const u8),
        ("axion_buf_xor", axion_buf_xor as *const u8),
        ("axion_eput", axion_eput as *const u8),
        ("axion_eputs", axion_eputs as *const u8),
        ("axion_exec_capture", axion_exec_capture as *const u8),
        ("axion_exec_status", axion_exec_status as *const u8),
        ("axion_exit", axion_exit as *const u8),
        ("axion_file_exists", axion_file_exists as *const u8),
        ("axion_fold_bytes", axion_fold_bytes as *const u8),
        ("axion_free", axion_free as *const u8),
        ("axion_getarg", axion_getarg as *const u8),
        ("axion_getargs", axion_getargs as *const u8),
        ("axion_getenv", axion_getenv as *const u8),
        ("axion_i32_dot", axion_i32_dot as *const u8),
        ("axion_i32_get", axion_i32_get as *const u8),
        ("axion_i32_iota", axion_i32_iota as *const u8),
        ("axion_i32_len", axion_i32_len as *const u8),
        ("axion_i32_matvec_sum", axion_i32_matvec_sum as *const u8),
        ("axion_i32_new", axion_i32_new as *const u8),
        ("axion_i32_set", axion_i32_set as *const u8),
        ("axion_i32_sum", axion_i32_sum as *const u8),
        ("axion_i8_dot", axion_i8_dot as *const u8),
        ("axion_i8_dot_i8", axion_i8_dot_i8 as *const u8),
        ("axion_i8_get", axion_i8_get as *const u8),
        ("axion_i8_iota", axion_i8_iota as *const u8),
        ("axion_i8_len", axion_i8_len as *const u8),
        ("axion_i8_matvec_sum", axion_i8_matvec_sum as *const u8),
        ("axion_i8_new", axion_i8_new as *const u8),
        ("axion_i8_set", axion_i8_set as *const u8),
        ("axion_i8_sum", axion_i8_sum as *const u8),
        ("axion_mkdir_p", axion_mkdir_p as *const u8),
        ("axion_par_map", axion_par_map as *const u8),
        ("axion_put", axion_put as *const u8),
        ("axion_puts", axion_puts as *const u8),
        ("axion_rand_hex", axion_rand_hex as *const u8),
        ("axion_readdir", axion_readdir as *const u8),
        ("axion_read_file", axion_read_file as *const u8),
        ("axion_read_line", axion_read_line as *const u8),
        ("axion_read_secret", axion_read_secret as *const u8),
        ("axion_rename", axion_rename as *const u8),
        ("axion_run", axion_run as *const u8),
        ("axion_sess_alloc", axion_sess_alloc as *const u8),
        ("axion_sess_channel", axion_sess_channel as *const u8),
        ("axion_sess_new", axion_sess_new as *const u8),
        ("axion_sess_pending", axion_sess_pending as *const u8),
        ("axion_sess_recv", axion_sess_recv as *const u8),
        ("axion_sess_run", axion_sess_run as *const u8),
        ("axion_sess_send", axion_sess_send as *const u8),
        ("axion_sess_spawn", axion_sess_spawn as *const u8),
        ("axion_show_float", axion_show_float as *const u8),
        ("axion_show_int", axion_show_int as *const u8),
        ("axion_str_at", axion_str_at as *const u8),
        ("axion_strcat", axion_strcat as *const u8),
        ("axion_str_cmp", axion_str_cmp as *const u8),
        ("axion_str_drop", axion_str_drop as *const u8),
        ("axion_str_len", axion_str_len as *const u8),
        ("axion_substr", axion_substr as *const u8),
        ("axion_system", axion_system as *const u8),
        ("axion_tritvec_dot", axion_tritvec_dot as *const u8),
        ("axion_tritvec_get", axion_tritvec_get as *const u8),
        ("axion_tritvec_iota", axion_tritvec_iota as *const u8),
        ("axion_tritvec_len", axion_tritvec_len as *const u8),
        ("axion_tritvec_new", axion_tritvec_new as *const u8),
        ("axion_tritvec_set", axion_tritvec_set as *const u8),
        ("axion_unlink", axion_unlink as *const u8),
        ("axion_write_file", axion_write_file as *const u8),
        ("ax_net_accept", ax_net_accept as *const u8),
        ("ax_net_close", ax_net_close as *const u8),
        ("ax_net_connect", ax_net_connect as *const u8),
        ("ax_net_listen", ax_net_listen as *const u8),
        ("ax_net_recv", ax_net_recv as *const u8),
        ("ax_net_send", ax_net_send as *const u8),
        ("ax_net_set_nonblocking", ax_net_set_nonblocking as *const u8),
        ("ax_net_wouldblock", ax_net_wouldblock as *const u8),
    ]
}
