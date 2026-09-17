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
