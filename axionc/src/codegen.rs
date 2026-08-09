//! LLVM `--release` backend.
#![allow(unsafe_code)]

use crate::ast;
use crate::ast::Span;
use crate::core::{
    self, is_bool, is_float, is_int, result_type, Atom, CPat, CoreFn, Op, RecordInfo, Rhs, Term,
};
use cranelift::codegen::ir::UserFuncName;
use cranelift::codegen::Context;
use cranelift::prelude::{
    types, AbiParam, Block, Configurable, EntityRef, FloatCC, FunctionBuilder,
    FunctionBuilderContext, InstBuilder, IntCC, MemFlags, Value, Variable,
};
use cranelift_jit::{JITBuilder, JITModule};
use cranelift_module::{DataDescription, DataId, FuncId, Linkage, Module};
use std::collections::HashMap;
use std::collections::HashSet;

// FFI (§18): resolves a symbol already loaded in the process (libc + axionc's
// runtime) via `dlsym(RTLD_DEFAULT, …)`. Serves the JIT's `symbol_lookup_fn`.
extern "C" {
    fn dlsym(
        handle: *mut std::ffi::c_void,
        symbol: *const std::ffi::c_char,
    ) -> *mut std::ffi::c_void;
}

fn resolve_symbol(name: &str) -> Option<*const u8> {
    let cname = std::ffi::CString::new(name).ok()?;
    // RTLD_DEFAULT = null pointer (glibc): searches in the normal resolution order.
    // SAFETY: dlsym with RTLD_DEFAULT reads the process symbol table
    // — pointer is valid or null, both safe to inspect.
    let p = unsafe { dlsym(std::ptr::null_mut(), cname.as_ptr()) };
    (!p.is_null()).then_some(p as *const u8)
}

// --- minimal native runtime (registered as symbols in the JIT) ---

/// `putStrLn`: prints a C-string with a newline.
extern "C" fn axion_puts(ptr: *const u8) {
    // SAFETY: the caller (JIT-compiled code) passed a valid NUL-terminated
    // C-string allocated by axion_show_int / axion_strcat.
    let s = unsafe { std::ffi::CStr::from_ptr(ptr as *const std::ffi::c_char) };
    println!("{}", s.to_string_lossy());
}

/// `putStr`: prints a C-string WITHOUT a newline.
extern "C" fn axion_put(ptr: *const u8) {
    use std::io::Write;
    // SAFETY: caller passed a valid NUL-terminated C-string.
    let s = unsafe { std::ffi::CStr::from_ptr(ptr as *const std::ffi::c_char) };
    print!("{}", s.to_string_lossy());
    drop(std::io::stdout().flush());
}

/// Copies `bytes` + a NUL into an `axion_alloc` buffer (8-byte size header), so the
/// resulting String is reclaimable by `axion_str_drop`/`axion_free` and counted in
/// the heap stats (unlike a leaked `CString`). Returns the payload C-string pointer.
fn axion_str_alloc(bytes: &[u8]) -> *const u8 {
    let p = axion_alloc(bytes.len() as i64 + 1);
    // SAFETY: `axion_alloc(n+1)` returns a payload of at least `n+1` bytes.
    unsafe {
        std::ptr::copy_nonoverlapping(bytes.as_ptr(), p, bytes.len());
        *p.add(bytes.len()) = 0;
    }
    p.cast_const()
}

/// Drops a `String`: heap strings carry the `axion_alloc` size header (nonzero at
/// `s-8`); literals are emitted with a ZERO header, so this frees the former and
/// skips the latter. Mirrors `axion_str_drop` in axion_rt.c.
extern "C" fn axion_str_drop(s: *mut u8) {
    if s.is_null() {
        return;
    }
    // SAFETY: a valid String points 8 bytes past a size-header word.
    let hdr = unsafe { s.sub(8).cast::<u64>().read_unaligned() };
    if hdr != 0 {
        axion_free(s);
    }
}

/// `show :: Int -> String`: formats an integer as a reclaimable heap C-string.
extern "C" fn axion_show_int(n: i64) -> *const u8 {
    axion_str_alloc(n.to_string().as_bytes())
}

/// `show :: Float -> String`: the shortest round-tripping decimal (matching Rust
/// `{}`), as a reclaimable heap C-string. The i64 argument is the f64 bit pattern.
extern "C" fn axion_show_float(bits: i64) -> *const u8 {
    axion_str_alloc(f64::from_bits(bits as u64).to_string().as_bytes())
}

// --- arbitrary-precision Integer (§Listing 1.4): an `i64` is `*mut BigInt` (boxed).
// Conservative reclamation: the boxes are never freed — Integer values are shared and
// immutable, so a GC-free scheme (refcount/linearity) is a later slice. Same behaviour
// as the C runtime's bignum (axion_rt.c); the two backends never share memory.
fn bignum<'a>(p: i64) -> &'a crate::bigint::BigInt {
    // SAFETY: `p` was produced by a bignum runtime fn (Box::into_raw of a BigInt).
    unsafe { &*(p as *const crate::bigint::BigInt) }
}
fn bignum_box(v: crate::bigint::BigInt) -> i64 {
    Box::into_raw(Box::new(v)) as i64
}
extern "C" fn axion_bignum_from_i64(n: i64) -> i64 {
    bignum_box(crate::bigint::BigInt::from_i64(n))
}
extern "C" fn axion_bignum_from_str(s: i64) -> i64 {
    // SAFETY: `s` is a NUL-terminated Axion String (C-string) of decimal digits.
    let text = unsafe { std::ffi::CStr::from_ptr(s as *const std::os::raw::c_char) };
    bignum_box(crate::bigint::BigInt::from_str(text.to_str().unwrap_or("0")))
}
extern "C" fn axion_bignum_add(a: i64, b: i64) -> i64 {
    bignum_box(bignum(a).add(bignum(b)))
}
extern "C" fn axion_bignum_sub(a: i64, b: i64) -> i64 {
    bignum_box(bignum(a).sub(bignum(b)))
}
extern "C" fn axion_bignum_mul(a: i64, b: i64) -> i64 {
    bignum_box(bignum(a).mul(bignum(b)))
}
extern "C" fn axion_bignum_div(a: i64, b: i64) -> i64 {
    match bignum(a).divmod(bignum(b)) {
        Some((q, _)) => bignum_box(q),
        None => {
            eprintln!("Integer: divide by zero");
            std::process::exit(1);
        }
    }
}
extern "C" fn axion_bignum_mod(a: i64, b: i64) -> i64 {
    match bignum(a).divmod(bignum(b)) {
        Some((_, r)) => bignum_box(r),
        None => {
            eprintln!("Integer: divide by zero");
            std::process::exit(1);
        }
    }
}
extern "C" fn axion_bignum_eq(a: i64, b: i64) -> i64 {
    i64::from(bignum(a).cmp(bignum(b)) == std::cmp::Ordering::Equal)
}
extern "C" fn axion_bignum_lt(a: i64, b: i64) -> i64 {
    i64::from(bignum(a).cmp(bignum(b)) == std::cmp::Ordering::Less)
}
extern "C" fn axion_bignum_gt(a: i64, b: i64) -> i64 {
    i64::from(bignum(a).cmp(bignum(b)) == std::cmp::Ordering::Greater)
}
extern "C" fn axion_bignum_to_string(a: i64) -> *const u8 {
    axion_str_alloc(bignum(a).to_string().as_bytes())
}

/// String concatenation `a ++ b` into a fresh reclaimable heap C-string. Backs
/// `strAppend`. Reads (borrows) both operands; the caller still owns/drops them.
extern "C" fn axion_strcat(a: *const u8, b: *const u8) -> *const u8 {
    // SAFETY: caller passed two valid NUL-terminated C-strings.
    let (x, y) = unsafe {
        (
            std::ffi::CStr::from_ptr(a as *const std::ffi::c_char),
            std::ffi::CStr::from_ptr(b as *const std::ffi::c_char),
        )
    };
    let mut s = x.to_bytes().to_vec();
    s.extend_from_slice(y.to_bytes());
    axion_str_alloc(&s)
}

// Heap counters (§13): how many allocations and frees occurred. With
// `AXION_HEAP_STATS=1` the `run` prints them at the end — evidence that Auto-Drop
// actually reclaims (not just static analysis).
static HEAP_ALLOCS: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(0);
static HEAP_FREES: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(0);

/// Allocates `size` bytes of *payload* on the heap. Prefixes an 8-byte header with
/// the total size, so `axion_free` can reconstruct the `Layout`; returns the
/// pointer to the payload (right after the header).
extern "C" fn axion_alloc(size: i64) -> *mut u8 {
    let total = size.max(1) as usize + 8;
    let layout =
        std::alloc::Layout::from_size_align(total, 8).unwrap_or_else(|_| panic!("layout error"));
    // SAFETY: layout is well-formed (8-aligned, non-zero); null-check
    // handles OOM via `handle_alloc_error` before any dereference.
    // SAFETY: POSIX getaddrinfo/socket/connect — well-known C socket API.
    unsafe {
        let base = std::alloc::alloc(layout);
        // out-of-memory → abort cleanly (the std OOM handler) instead of
        // dereferencing NULL. Resource exhaustion, not a memory bug — but a clear
        // failure, not a SIGSEGV.
        if base.is_null() {
            std::alloc::handle_alloc_error(layout);
        }
        base.cast::<u64>().write_unaligned(total as u64); // header: total size
        HEAP_ALLOCS.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
        base.add(8) // payload
    }
}

/// Frees an object allocated by `axion_alloc` (reads the size from the header).
extern "C" fn axion_free(ptr: *mut u8) {
    // a tagged immediate (low bit set — a nullary constructor of a mixed sum
    // type) is not a heap allocation: nothing to free.
    if (ptr as usize) & 1 != 0 {
        return;
    }
    // SAFETY: only called after axion_alloc, so ptr is a valid
    // allocation with an 8-byte size header at offset -8.
    // SAFETY: POSIX getaddrinfo/socket/connect — well-known C socket API.
    unsafe {
        let base = ptr.sub(8);
        let total = base.cast::<u64>().read_unaligned() as usize;
        let layout = std::alloc::Layout::from_size_align(total, 8)
            .unwrap_or_else(|_| panic!("layout error"));
        std::alloc::dealloc(base, layout);
        HEAP_FREES.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
    }
}

/* --- networking runtime (see axion_rt.c for the C version) --- */

#[repr(C)]
struct SockAddrIn {
    family: u16,
    port: u16,
    addr: u32,
    zero: [u8; 8],
}
#[repr(C)]
struct AddrInfo {
    flags: i32,
    family: i32,
    socktype: i32,
    protocol: i32,
    addrlen: u32,
    addr: *mut SockAddrIn,
    canonname: *const u8,
    next: *mut AddrInfo,
}
const AF_UNSPEC: i32 = 0;
const AF_INET: i32 = 2;
const SOCK_STREAM: i32 = 1;
const SOL_SOCKET: i32 = 1;
const SO_REUSEADDR: i32 = 2;
const MSG_NOSIGNAL: i32 = 0x4000;

extern "C" fn ax_net_connect(host: i64, port: i64) -> i64 {
    use std::os::raw::c_char;
    extern "C" {
        fn getaddrinfo(
            node: *const c_char,
            service: *const c_char,
            hints: *const AddrInfo,
            res: *mut *mut AddrInfo,
        ) -> i32;
        fn freeaddrinfo(res: *mut AddrInfo);
        fn socket(domain: i32, ty: i32, protocol: i32) -> i32;
        fn connect(fd: i32, addr: *const SockAddrIn, len: u32) -> i32;
        fn close(fd: i32) -> i32;
    }
    // SAFETY: POSIX getaddrinfo/socket/connect — well-known C socket API.
    unsafe {
        let host = host as *const u8 as *const c_char;
        let mut hints: AddrInfo = std::mem::zeroed();
        hints.family = AF_UNSPEC;
        hints.socktype = SOCK_STREAM;
        let mut res: *mut AddrInfo = std::ptr::null_mut();
        if getaddrinfo(host, std::ptr::null(), &raw const hints, &raw mut res) != 0 || res.is_null()
        {
            return -1;
        }
        let mut fd = -1;
        let mut rp = res;
        while !rp.is_null() {
            let ai = &*rp;
            fd = socket(ai.family, ai.socktype, ai.protocol);
            if fd < 0 {
                rp = ai.next;
                continue;
            }
            let mut sa = std::ptr::read(ai.addr);
            sa.port = (port as u16).to_be();
            if connect(fd, &raw const sa, std::mem::size_of::<SockAddrIn>() as u32) == 0 {
                break;
            }
            close(fd);
            fd = -1;
            rp = ai.next;
        }
        freeaddrinfo(res);
        fd as i64
    }
}

extern "C" fn ax_net_listen(port: i64) -> i64 {
    extern "C" {
        fn socket(domain: i32, ty: i32, protocol: i32) -> i32;
        fn setsockopt(fd: i32, level: i32, opt: i32, val: *const i32, len: u32) -> i32;
        fn bind(fd: i32, addr: *const SockAddrIn, len: u32) -> i32;
        fn listen(fd: i32, backlog: i32) -> i32;
        fn close(fd: i32) -> i32;
    }
    // SAFETY: POSIX getaddrinfo/socket/connect — well-known C socket API.
    unsafe {
        let fd = socket(AF_INET, SOCK_STREAM, 0);
        if fd < 0 {
            return -1;
        }
        let opt: i32 = 1;
        setsockopt(
            fd,
            SOL_SOCKET,
            SO_REUSEADDR,
            &raw const opt,
            std::mem::size_of::<i32>() as u32,
        );
        let addr = SockAddrIn {
            family: AF_INET as u16,
            port: (port as u16).to_be(),
            addr: 0,
            zero: [0; 8],
        };
        if bind(
            fd,
            &raw const addr,
            std::mem::size_of::<SockAddrIn>() as u32,
        ) < 0
        {
            close(fd);
            return -1;
        }
        if listen(fd, 128) < 0 {
            close(fd);
            return -1;
        }
        fd as i64
    }
}

extern "C" fn ax_net_accept(fd: i64) -> i64 {
    extern "C" {
        fn accept(fd: i32, addr: *mut SockAddrIn, len: *mut u32) -> i32;
    }
    // SAFETY: POSIX getaddrinfo/socket/connect — well-known C socket API.
    unsafe { accept(fd as i32, std::ptr::null_mut(), std::ptr::null_mut()) as i64 }
}

extern "C" fn ax_net_send(fd: i64, data: i64) -> i64 {
    use std::os::raw::c_char;
    extern "C" {
        fn send(fd: i32, buf: *const c_char, len: usize, flags: i32) -> isize;
    }
    // SAFETY: POSIX getaddrinfo/socket/connect — well-known C socket API.
    unsafe {
        let s = data as *const u8 as *const c_char;
        let mut len = 0usize;
        while *s.add(len) != 0 {
            len += 1;
        }
        send(fd as i32, s, len, MSG_NOSIGNAL) as i64
    }
}

extern "C" fn ax_net_recv(fd: i64) -> i64 {
    use std::os::raw::c_char;
    extern "C" {
        fn recv(fd: i32, buf: *mut c_char, len: usize, flags: i32) -> isize;
    }
    // SAFETY: POSIX getaddrinfo/socket/connect — well-known C socket API.
    unsafe {
        let mut buf = [0u8; 4096];
        let n = recv(fd as i32, buf.as_mut_ptr() as *mut c_char, buf.len() - 1, 0);
        if n <= 0 {
            return 0;
        }
        let p = axion_alloc(n as i64 + 1);
        std::ptr::copy_nonoverlapping(buf.as_ptr(), p, n as usize);
        *p.add(n as usize) = 0;
        p as i64
    }
}

extern "C" fn ax_net_close(fd: i64) {
    extern "C" {
        fn close(fd: i32) -> i32;
    }
    // SAFETY: POSIX getaddrinfo/socket/connect — well-known C socket API.
    unsafe {
        close(fd as i32);
    }
}

// --- arena runtime (§3): bump-allocator with bulk reset ---

static ARENA_NEWS: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(0);
static ARENA_RESETS: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(0);
static CELL_ALLOCS: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(0);

/// Fixed size of a `Cell` (§3). Opaque to the program (`useCell` returns 0).
const CELL_SIZE: i64 = 16;

/// Stack size (bytes) for the thread that runs `main` — large so deep recursion
/// does not overflow the small default stack. Lazily committed: reserving it
/// costs no RAM until the recursion actually goes that deep.
pub const EVAL_STACK_SIZE: usize = 2 << 30; // 2 GiB

/// State of an arena: fixed *chunks* (don't move → stable pointers) with a
/// bump-pointer. The reset drops all the chunks at once.
struct ArenaState {
    chunks: Vec<Box<[u8]>>,
    chunk: usize,
    off: usize,
}
const ARENA_CHUNK: usize = 64 * 1024;

impl ArenaState {
    fn new() -> Box<ArenaState> {
        Box::new(ArenaState {
            chunks: vec![vec![0u8; ARENA_CHUNK].into_boxed_slice()],
            chunk: 0,
            off: 0,
        })
    }
    fn alloc(&mut self, size: usize) -> *mut u8 {
        let size = size.max(1).next_multiple_of(8); // aligned to 8
        if self.off + size > self.chunks[self.chunk].len() {
            let cap = ARENA_CHUNK.max(size);
            self.chunks.push(vec![0u8; cap].into_boxed_slice());
            self.chunk = self.chunks.len() - 1;
            self.off = 0;
        }
        // SAFETY: the chunk is a Box<[u8]> with at least (off + size) bytes
        // remaining; as_mut_ptr().add(off) returns a pointer within the allocation.
        let out = unsafe { self.chunks[self.chunk].as_mut_ptr().add(self.off) };
        self.off += size;
        out
    }
}

/// A mark: the arena and the bump-pointer position at the moment of creating it.
struct MarkState {
    arena: *mut ArenaState,
    chunk: usize,
    off: usize,
}

extern "C" fn axion_arena_new() -> *mut u8 {
    ARENA_NEWS.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
    Box::into_raw(ArenaState::new()) as *mut u8
}

/// Allocates `size` bytes of arena memory.
#[allow(clippy::cast_ptr_alignment)]
extern "C" fn axion_arena_alloc(arena: *mut u8, size: i64) -> *mut u8 {
    CELL_ALLOCS.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
    // SAFETY: arena was allocated by axion_arena_new and is a valid
    // Box<ArenaState>; the pointer is properly aligned for ArenaState.
    let st = unsafe { &mut *(arena as *mut ArenaState) };
    st.alloc(size as usize)
}

/// Bulk reset: drops the whole arena (all chunks at once).
#[allow(clippy::cast_ptr_alignment)]
extern "C" fn axion_arena_reset(arena: *mut u8) {
    ARENA_RESETS.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
    // SAFETY: arena was allocated by axion_arena_new and was never freed;
    // Box::from_raw reconstructs the owning pointer for safe deallocation.
    // SAFETY: POSIX getaddrinfo/socket/connect — well-known C socket API.
    unsafe { drop(Box::from_raw(arena as *mut ArenaState)) };
}

/// Creates a mark snapshot: arena pointer + bump-pointer position.
#[allow(clippy::cast_ptr_alignment)]
extern "C" fn axion_arena_mark(arena: *mut u8) -> *mut u8 {
    // SAFETY: arena is a live ArenaState pointer from axion_arena_new;
    // we read its chunk/off fields (no mutation) to snapshot the bump-pointer.
    let st = unsafe { &*(arena as *mut ArenaState) };
    Box::into_raw(Box::new(MarkState {
        arena: arena as *mut ArenaState,
        chunk: st.chunk,
        off: st.off,
    })) as *mut u8
}

/// Restores the bump-pointer to the mark (reclaims what was allocated since).
#[allow(clippy::cast_ptr_alignment)]
extern "C" fn axion_arena_release(mark: *mut u8) {
    // SAFETY: mark was created by axion_arena_mark and is a valid
    // Box<MarkState>; the arena pointer inside it is still live.
    let m = unsafe { Box::from_raw(mark as *mut MarkState) };
    // SAFETY: m.arena was written by axion_arena_mark and points to a
    // live ArenaState.
    let st = unsafe { &mut *m.arena };
    st.chunks.truncate(m.chunk + 1);
    st.chunk = m.chunk;
    st.off = m.off;
}

/// Copies a cell to arena `target` (saves it from the sub-arena reset).
#[allow(clippy::cast_ptr_alignment)]
extern "C" fn axion_arena_promote(target: *mut u8, cell: *mut u8, size: i64) -> *mut u8 {
    // SAFETY: target is a live ArenaState pointer.
    let st = unsafe { &mut *(target as *mut ArenaState) };
    let dst = st.alloc(size as usize);
    // SAFETY: cell and dst are within valid allocations of at least `size`
    // bytes, and they do not overlap (dst is freshly allocated).
    // SAFETY: POSIX getaddrinfo/socket/connect — well-known C socket API.
    unsafe { std::ptr::copy_nonoverlapping(cell, dst, size as usize) };
    dst
}

// --- Linear Buffer U8 (§4/§5): [len(i64)][bytes…]. The bulk operations are the
// imperative/vectorizable escape-hatch (in --release; in --dev at the speed of
// axionc's Rust runtime). Layout of 8 (header) + n bytes; 8+n is allocated
// rounded up to the `Layout`'s alignment. ---

fn buf_layout(n: usize) -> std::alloc::Layout {
    std::alloc::Layout::from_size_align(8 + n, 8).unwrap_or_else(|_| panic!("layout error"))
}

extern "C" fn axion_buf_new(n: i64) -> *mut u8 {
    let n = n.max(0) as usize;
    let layout = buf_layout(n);
    // SAFETY: layout is well-formed; null-check before any dereference.
    // SAFETY: POSIX getaddrinfo/socket/connect — well-known C socket API.
    unsafe {
        let b = std::alloc::alloc_zeroed(layout);
        if b.is_null() {
            std::alloc::handle_alloc_error(layout);
        }
        b.cast::<i64>().write_unaligned(n as i64);
        b
    }
}

extern "C" fn axion_buf_iota(buf: *mut u8) -> *mut u8 {
    // SAFETY: buf was allocated by axion_buf_new — valid for reads/writes
    // within [0, n) at buf+8, where n = read from buf[0..8].
    // SAFETY: POSIX getaddrinfo/socket/connect — well-known C socket API.
    unsafe {
        let n = buf.cast::<i64>().read_unaligned() as usize;
        let d = buf.add(8);
        for i in 0..n {
            *d.add(i) = (i & 0xFF) as u8;
        }
    }
    buf
}

extern "C" fn axion_buf_xor(buf: *mut u8, key: i64) -> *mut u8 {
    // SAFETY: buf was allocated by axion_buf_new — reads/writes within bounds.
    // SAFETY: POSIX getaddrinfo/socket/connect — well-known C socket API.
    unsafe {
        let n = buf.cast::<i64>().read_unaligned() as usize;
        let d = buf.add(8);
        for i in 0..n {
            *d.add(i) ^= key as u8;
        }
    }
    buf
}

extern "C" fn axion_buf_sum(buf: *mut u8) -> i64 {
    // SAFETY: buf was allocated by axion_buf_new — reads within bounds.
    // SAFETY: POSIX getaddrinfo/socket/connect — well-known C socket API.
    unsafe {
        let n = buf.cast::<i64>().read_unaligned() as usize;
        let d = buf.add(8);
        let mut s = 0i64;
        for i in 0..n {
            s = s.wrapping_add(*d.add(i) as i64);
        }
        s
    }
}

extern "C" fn axion_buf_free(buf: *mut u8) {
    // SAFETY: buf was allocated by axion_buf_new with a matching layout
    // computed from the size header.
    // SAFETY: POSIX getaddrinfo/socket/connect — well-known C socket API.
    unsafe {
        let n = buf.cast::<i64>().read_unaligned() as usize;
        std::alloc::dealloc(buf, buf_layout(n));
    }
}

/// `foldBytes f init buf`: folds the closure `f` over the bytes. Reads the `fn_ptr` from
/// `f[0]` and calls `fn_ptr(f, acc, byte)` per byte (the closure is the env).
extern "C" fn axion_fold_bytes(f: *mut u8, init: i64, buf: *mut u8) -> i64 {
    // SAFETY: the closure fn_ptr and buf were allocated by Axion — valid reads.
    // SAFETY: POSIX getaddrinfo/socket/connect — well-known C socket API.
    unsafe {
        let n = buf.cast::<i64>().read_unaligned() as usize;
        let d = buf.add(8);
        let fn_ptr: extern "C" fn(*mut u8, i64, u8) -> i64 =
            std::mem::transmute(f.cast::<i64>().read_unaligned() as *const ());
        let mut acc = init;
        for i in 0..n {
            acc = fn_ptr(f, acc, *d.add(i));
        }
        acc
    }
}

/* --- linear dense Array: [len(i64)][elem_0(i64)]… --- */

extern "C" fn axion_array_new(len: i64, init: i64) -> i64 {
    let n = len.max(0) as usize;
    let layout = std::alloc::Layout::from_size_align(8 + n * 8, 8)
        .unwrap_or_else(|_| panic!("layout error"));
    // SAFETY: layout is well-formed; the memset fills all n elements.
    unsafe {
        let b = std::alloc::alloc_zeroed(layout);
        if b.is_null() {
            std::alloc::handle_alloc_error(layout);
        }
        b.cast::<i64>().write_unaligned(n as i64);
        // `b` is 8-aligned (layout align 8), so `b + 8` is a valid `*mut i64`.
        #[allow(clippy::cast_ptr_alignment)]
        let d = b.add(8).cast::<i64>();
        for i in 0..n {
            *d.add(i) = init;
        }
        b as i64
    }
}

extern "C" fn axion_array_get(arr: i64, idx: i64) -> i64 {
    // SAFETY: arr is a valid Array allocation — reads within bounds or aborts.
    unsafe {
        let n = (arr as *const i64).read_unaligned();
        if idx < 0 || idx >= n {
            std::process::abort();
        }
        (arr as *const i64).add(idx as usize + 1).read_unaligned()
    }
}

extern "C" fn axion_array_set(arr: i64, idx: i64, val: i64) -> i64 {
    // SAFETY: arr is a valid Array allocation — writes within bounds or aborts.
    unsafe {
        let n = (arr as *const i64).read_unaligned();
        if idx < 0 || idx >= n {
            std::process::abort();
        }
        (arr as *mut i64).add(idx as usize + 1).write_unaligned(val);
        arr
    }
}

extern "C" fn axion_array_len(arr: i64) -> i64 {
    // SAFETY: arr is a valid Array allocation — reads the length header.
    unsafe { (arr as *const i64).read_unaligned() }
}

extern "C" fn axion_array_free(arr: i64) {
    // SAFETY: arr was allocated by axion_array_new with a matching layout.
    unsafe {
        let n = (arr as *const i64).read_unaligned() as usize;
        let layout = std::alloc::Layout::from_size_align(8 + n * 8, 8)
            .unwrap_or_else(|_| panic!("layout error"));
        std::alloc::dealloc(arr as *mut u8, layout);
    }
}

// --- M:N session scheduler (§11): the --dev mirror of the C runtime
// (axion_rt.c). Same ABI: a task is a state machine `long step(sched, state)`
// returning 1=done / 0=blocked, storing its result into state[0] when done. Tasks
// run on a pool of worker threads. The shared state is behind one `Mutex` held
// only during runtime ops (channel/send/recv/spawn/alloc) — NOT during the compute
// between them, which is what runs in parallel. Session-type linearity makes every
// channel a single-producer/single-consumer queue, so the mutex is the only
// synchronization needed; deadlock-freedom is guaranteed by types (AX0302).
// Blocked tasks sleep in `blocked` and are woken (moved to `ready`) by any `send`,
// so there is no hard spin. ---

type SessStep = extern "C" fn(i64, i64) -> i64;

struct SessInner {
    bufs: Vec<std::collections::VecDeque<i64>>, // input queue per endpoint (SPSC)
    peer: Vec<usize>,                           // peer[ep]
    tasks: Vec<(SessStep, i64)>,                // (step, state) by index
    ready: std::collections::VecDeque<usize>,   // runnable task indices
    blocked: Vec<usize>,                        // tasks parked on an empty `recv`
    running: usize,                             // tasks currently being stepped
    allocs: Vec<(usize, std::alloc::Layout)>,   // task states (freed at run end)
    gen: u64,                                   // bumped on every `send` (wakeups)
    par: bool,                                  // §9 parMap: finish when ALL tasks done
    ncompleted: usize,                          // §9 parMap: tasks completed so far
}

struct SessSched {
    inner: std::sync::Mutex<SessInner>,
    done: std::sync::atomic::AtomicBool, // root finished
    result: std::sync::atomic::AtomicI64,
    budget: std::sync::atomic::AtomicI64, // safety net against a livelock bug
}

fn sess<'a>(sched: i64) -> &'a SessSched {
    // SAFETY: sched was created by axion_sess_new which returns a Box pointer;
    // the cast reconstructs the reference for the duration of this call only.
    // SAFETY: POSIX getaddrinfo/socket/connect — well-known C socket API.
    unsafe { &*(sched as *const SessSched) }
}

extern "C" fn axion_sess_new() -> i64 {
    use std::sync::atomic::{AtomicBool, AtomicI64};
    Box::into_raw(Box::new(SessSched {
        inner: std::sync::Mutex::new(SessInner {
            bufs: Vec::new(),
            peer: Vec::new(),
            tasks: Vec::new(),
            ready: std::collections::VecDeque::new(),
            blocked: Vec::new(),
            running: 0,
            allocs: Vec::new(),
            gen: 0,
            par: false,
            ncompleted: 0,
        }),
        done: AtomicBool::new(false),
        result: AtomicI64::new(0),
        budget: AtomicI64::new(2_000_000_000),
    })) as i64
}

/// Creates a channel: two peer endpoints, `a` and `a+1` (mirrors newChannel).
extern "C" fn axion_sess_channel(sched: i64) -> i64 {
    let mut g = sess(sched)
        .inner
        .lock()
        .unwrap_or_else(|_| panic!("mutex poisoned"));
    let a = g.bufs.len();
    g.bufs.push(Default::default());
    g.bufs.push(Default::default());
    g.peer.push(a + 1);
    g.peer.push(a);
    a as i64
}

/// Sends `v` on `ep` → pushes to the peer's input queue and wakes parked receivers.
extern "C" fn axion_sess_send(sched: i64, ep: i64, v: i64) {
    let mut g = sess(sched)
        .inner
        .lock()
        .unwrap_or_else(|_| panic!("mutex poisoned"));
    let p = g.peer[ep as usize];
    g.bufs[p].push_back(v);
    // a message arrived → wake parked tasks and bump the generation so that a task
    // about to park (having just seen its channel empty) re-checks instead — this
    // closes the lost-wakeup window between a step returning blocked and the worker
    // recording it in `blocked`.
    g.gen = g.gen.wrapping_add(1);
    let woken: Vec<usize> = g.blocked.drain(..).collect();
    g.ready.extend(woken);
}

/// 1 if a message is waiting on `ep`, 0 if empty (would block).
extern "C" fn axion_sess_pending(sched: i64, ep: i64) -> i64 {
    let g = sess(sched)
        .inner
        .lock()
        .unwrap_or_else(|_| panic!("mutex poisoned"));
    i64::from(!g.bufs[ep as usize].is_empty())
}

/// Pops and returns the message on `ep` (caller guarantees pending; SPSC consumer).
extern "C" fn axion_sess_recv(sched: i64, ep: i64) -> i64 {
    let mut g = sess(sched)
        .inner
        .lock()
        .unwrap_or_else(|_| panic!("mutex poisoned"));
    g.bufs[ep as usize].pop_front().unwrap_or(0)
}

/// Allocates a zeroed task-state block owned by the scheduler (the nursery arena);
/// all such blocks are freed in bulk when `axion_sess_run` returns.
extern "C" fn axion_sess_alloc(sched: i64, nbytes: i64) -> i64 {
    let size = nbytes.max(8) as usize;
    let layout =
        std::alloc::Layout::from_size_align(size, 8).unwrap_or_else(|_| panic!("layout error"));
    // SAFETY: layout is well-formed; null-check before dereference.
    let p = unsafe { std::alloc::alloc_zeroed(layout) };
    sess(sched)
        .inner
        .lock()
        .unwrap_or_else(|_| panic!("mutex poisoned"))
        .allocs
        .push((p as usize, layout));
    p as i64
}

extern "C" fn axion_sess_spawn(sched: i64, step: i64, state: i64) {
    // SAFETY: step is a function pointer cast to i64 during codegen;
    // both i64 and SessStep are the same width on all supported targets.
    let f: SessStep = unsafe { std::mem::transmute::<i64, SessStep>(step) };
    let mut g = sess(sched)
        .inner
        .lock()
        .unwrap_or_else(|_| panic!("mutex poisoned"));
    let i = g.tasks.len();
    g.tasks.push((f, state));
    g.ready.push_back(i);
}

/// One worker thread: pull a ready task, run its step without the lock, then mark
/// it done / re-park it. Exits when the root task finishes.
fn sess_worker(sched: i64) {
    use std::sync::atomic::Ordering::{Acquire, Relaxed, Release};
    let s = sess(sched);
    loop {
        if s.done.load(Acquire) {
            return;
        }
        let picked = {
            let mut g = s.inner.lock().unwrap_or_else(|_| panic!("mutex poisoned"));
            match g.ready.pop_front() {
                Some(i) => {
                    g.running += 1;
                    let (step, st) = g.tasks[i];
                    Some((i, step, st, g.gen))
                }
                None => {
                    // nothing runnable: if nothing is running either, and tasks are
                    // parked, no one can wake them — a deadlock (types forbid it).
                    if g.running == 0 && !g.blocked.is_empty() {
                        eprintln!("session scheduler: no progress (deadlock)");
                        std::process::exit(1);
                    }
                    None
                }
            }
        };
        let Some((i, step, st, gen0)) = picked else {
            std::thread::yield_now();
            continue;
        };
        if s.budget.fetch_sub(1, Relaxed) <= 0 {
            eprintln!("session scheduler: budget exhausted");
            std::process::exit(1);
        }
        // step status: 1 = done, 2 = re-queue (a recursive session loop iterated),
        // 0 = blocked on an empty recv.
        let status = step(sched, st); // runs WITHOUT the lock (parallel)
        let mut g = s.inner.lock().unwrap_or_else(|_| panic!("mutex poisoned"));
        g.running -= 1;
        if status == 1 {
            if g.par {
                // §9 parMap: no distinguished root — finish once every worker is done.
                g.ncompleted += 1;
                if g.ncompleted == g.tasks.len() {
                    s.done.store(true, Release);
                }
            } else if i == 0 {
                // SAFETY: st is the task-state pointer cast from i64; it was
                // zero-allocated by axion_sess_alloc and the root task's
                // first word holds the result value.
                let res = unsafe { (st as *const i64).read_unaligned() };
                s.result.store(res, Release);
                s.done.store(true, Release);
            }
        } else if status == 2 || g.gen != gen0 {
            // 2: the task looped (§6 recursion) → re-run at the loop head. Also the
            // lost-wakeup guard: a `send` during this step → re-run, don't park.
            g.ready.push_back(i);
        } else {
            g.blocked.push(i); // parked until a `send` wakes it
        }
    }
}

/// Runs the root task (task 0) and its children on a thread pool until the root
/// finishes; returns the root's result (read from `state[0]`).
extern "C" fn axion_sess_run(sched: i64, step: i64, state: i64) -> i64 {
    use std::sync::atomic::Ordering::Acquire;
    axion_sess_spawn(sched, step, state); // root = task 0
                                          // worker threads: `AXION_SESS_THREADS` overrides (for scaling benchmarks),
                                          // else min(available parallelism, 8).
    let nthreads = std::env::var("AXION_SESS_THREADS")
        .ok()
        .and_then(|v| v.parse::<usize>().ok())
        .filter(|&n| n > 0)
        .unwrap_or_else(|| {
            std::thread::available_parallelism()
                .map(|n| n.get())
                .unwrap_or(1)
                .clamp(1, 8)
        });
    let sp = sched; // i64 is Send; the box is alive until the scope joins below
    std::thread::scope(|scope| {
        for _ in 0..nthreads {
            scope.spawn(move || sess_worker(sp));
        }
    });
    let s = sess(sched);
    let result = s.result.load(Acquire);
    // free the task states (the nursery arena) and the scheduler
    // SAFETY: sched was created by axion_sess_new which wraps a Box;
    // the thread pool has joined — no outstanding references remain.
    let boxed = unsafe { Box::from_raw(sched as *mut SessSched) };
    let inner = boxed
        .inner
        .into_inner()
        .unwrap_or_else(|_| panic!("Arc still referenced"));
    for (p, layout) in inner.allocs {
        // SAFETY: each (p, layout) was recorded by axion_sess_alloc
        // with the exact same layout used during allocation.
        // SAFETY: POSIX getaddrinfo/socket/connect — well-known C socket API.
        unsafe { std::alloc::dealloc(p as *mut u8, layout) };
    }
    result
}

/// §9 structured fork-join (`parMap`): spawns one worker per input-list element,
/// preloads each input, runs every worker to completion on the thread pool, and
/// collects the replies into a `List` (Cons/Nil, in input order). The N endpoints
/// live entirely inside this scheduler — they never enter the linear world.
/// `step` = the worker's state-machine step fn; `state_size` = its state-block size;
/// `ep_slot` = the byte offset of its endpoint parameter within that block.
extern "C" fn axion_par_map(step: i64, state_size: i64, ep_slot: i64, inputs: i64) -> i64 {
    let sched = axion_sess_new();
    // spawn a worker per input, preloading the input into the child's queue
    let mut peps: Vec<i64> = Vec::new();
    let mut p = inputs;
    while p != 0 && (p & 1) == 0 {
        // SAFETY: `p` is a Cons cell (tag@0, head@+8, tail@+16) from axion_alloc.
        let v = unsafe { ((p + 8) as *const i64).read_unaligned() };
        // SAFETY: tail pointer at offset 16.
        let next = unsafe { ((p + 16) as *const i64).read_unaligned() };
        let a = axion_sess_channel(sched);
        let st = axion_sess_alloc(sched, state_size);
        // SAFETY: `st` is a zeroed block of `state_size` bytes; `ep_slot` is in range.
        unsafe { ((st + ep_slot) as *mut i64).write_unaligned(a + 1) };
        axion_sess_send(sched, a, v); // preload input → the worker's first `recv`
        axion_sess_spawn(sched, step, st);
        peps.push(a);
        // parMap owns the input list (moved in) — free each cons cell now that its
        // element has been handed to the worker.
        axion_free(p as *mut u8);
        p = next;
    }
    if !peps.is_empty() {
        sess(sched)
            .inner
            .lock()
            .unwrap_or_else(|_| panic!("mutex poisoned"))
            .par = true;
        let nthreads = std::env::var("AXION_SESS_THREADS")
            .ok()
            .and_then(|v| v.parse::<usize>().ok())
            .filter(|&n| n > 0)
            .unwrap_or_else(|| {
                std::thread::available_parallelism()
                    .map(|n| n.get())
                    .unwrap_or(1)
                    .clamp(1, 8)
            });
        let sp = sched;
        std::thread::scope(|scope| {
            for _ in 0..nthreads {
                scope.spawn(move || sess_worker(sp));
            }
        });
    }
    // drain each worker's reply (sent back on the parent end) into a List, in order
    let mut list: i64 = 1; // Nil (tagged)
    for &a in peps.iter().rev() {
        let r = axion_sess_recv(sched, a);
        let cell = axion_alloc(24) as i64;
        // SAFETY: axion_alloc(24) returns a 24-byte payload — laid out as a Cons cell.
        unsafe {
            (cell as *mut i64).write_unaligned(1); // Cons tag
            ((cell + 8) as *mut i64).write_unaligned(r); // head
            ((cell + 16) as *mut i64).write_unaligned(list); // tail
        }
        list = cell;
    }
    // free the scheduler (task states + the box); the thread pool has joined.
    // SAFETY: sched came from axion_sess_new (a Box); no references remain.
    let boxed = unsafe { Box::from_raw(sched as *mut SessSched) };
    let inner = boxed
        .inner
        .into_inner()
        .unwrap_or_else(|_| panic!("mutex poisoned"));
    for (pp, layout) in inner.allocs {
        // SAFETY: each (pp, layout) was recorded by axion_sess_alloc with that layout.
        unsafe { std::alloc::dealloc(pp as *mut u8, layout) };
    }
    list
}

/// The arena runtime's `FuncId`s (§3).
#[derive(Clone, Copy)]
struct Arena {
    new: FuncId,
    alloc: FuncId,
    reset: FuncId,
    mark: FuncId,
    release: FuncId,
    promote: FuncId,
}

/// Compilation environment: JIT + the `FuncId`/arity of the Core functions.
struct Cg {
    module: JITModule,
    ids: HashMap<String, (FuncId, usize)>,
    strings: HashMap<String, DataId>,
    str_counter: u32,
    println_id: FuncId,
    print_id: FuncId,
    show_id: FuncId,
    alloc_id: FuncId,
    free_id: FuncId,
    arena: Arena,
    rt_fns: HashMap<String, (FuncId, bool)>,
    records: RecordInfo,
}

impl Cg {
    fn new(records: RecordInfo) -> Result<Cg, String> {
        let mut flags = cranelift::codegen::settings::builder();
        drop(flags.set("opt_level", "none"));
        let isa = cranelift_native::builder()
            .map_err(|e| e.to_string())?
            .finish(cranelift::codegen::settings::Flags::new(flags))
            .map_err(|e| e.to_string())?;
        let mut builder = JITBuilder::with_isa(isa, cranelift_module::default_libcall_names());
        // FFI (§18): unregistered symbols resolve via dlsym (libc, …).
        builder.symbol_lookup_fn(Box::new(resolve_symbol));
        builder.symbol("axion_puts", axion_puts as *const u8);
        builder.symbol("axion_put", axion_put as *const u8);
        builder.symbol("axion_show_int", axion_show_int as *const u8);
        builder.symbol("axion_show_float", axion_show_float as *const u8);
        builder.symbol("axion_strcat", axion_strcat as *const u8);
        builder.symbol("axion_str_drop", axion_str_drop as *const u8);
        builder.symbol("axion_bignum_from_i64", axion_bignum_from_i64 as *const u8);
        builder.symbol("axion_bignum_from_str", axion_bignum_from_str as *const u8);
        builder.symbol("axion_bignum_add", axion_bignum_add as *const u8);
        builder.symbol("axion_bignum_sub", axion_bignum_sub as *const u8);
        builder.symbol("axion_bignum_mul", axion_bignum_mul as *const u8);
        builder.symbol("axion_bignum_div", axion_bignum_div as *const u8);
        builder.symbol("axion_bignum_mod", axion_bignum_mod as *const u8);
        builder.symbol("axion_bignum_eq", axion_bignum_eq as *const u8);
        builder.symbol("axion_bignum_lt", axion_bignum_lt as *const u8);
        builder.symbol("axion_bignum_gt", axion_bignum_gt as *const u8);
        builder.symbol("axion_bignum_to_string", axion_bignum_to_string as *const u8);
        builder.symbol("axion_alloc", axion_alloc as *const u8);
        builder.symbol("axion_free", axion_free as *const u8);
        builder.symbol("axion_arena_new", axion_arena_new as *const u8);
        builder.symbol("axion_arena_alloc", axion_arena_alloc as *const u8);
        builder.symbol("axion_arena_reset", axion_arena_reset as *const u8);
        builder.symbol("axion_arena_mark", axion_arena_mark as *const u8);
        builder.symbol("axion_arena_release", axion_arena_release as *const u8);
        builder.symbol("axion_arena_promote", axion_arena_promote as *const u8);
        builder.symbol("axion_buf_new", axion_buf_new as *const u8);
        builder.symbol("axion_buf_iota", axion_buf_iota as *const u8);
        builder.symbol("axion_buf_xor", axion_buf_xor as *const u8);
        builder.symbol("axion_buf_sum", axion_buf_sum as *const u8);
        builder.symbol("axion_buf_free", axion_buf_free as *const u8);
        builder.symbol("axion_fold_bytes", axion_fold_bytes as *const u8);
        // Array
        builder.symbol("axion_array_new", axion_array_new as *const u8);
        builder.symbol("axion_array_get", axion_array_get as *const u8);
        builder.symbol("axion_array_set", axion_array_set as *const u8);
        builder.symbol("axion_array_len", axion_array_len as *const u8);
        builder.symbol("axion_array_free", axion_array_free as *const u8);
        builder.symbol("axion_sess_new", axion_sess_new as *const u8);
        builder.symbol("axion_sess_channel", axion_sess_channel as *const u8);
        builder.symbol("axion_sess_send", axion_sess_send as *const u8);
        builder.symbol("axion_sess_pending", axion_sess_pending as *const u8);
        builder.symbol("axion_sess_recv", axion_sess_recv as *const u8);
        builder.symbol("axion_sess_alloc", axion_sess_alloc as *const u8);
        builder.symbol("axion_sess_spawn", axion_sess_spawn as *const u8);
        builder.symbol("axion_sess_run", axion_sess_run as *const u8);
        builder.symbol("axion_par_map", axion_par_map as *const u8);
        // networking
        builder.symbol("ax_net_connect", ax_net_connect as *const u8);
        builder.symbol("ax_net_listen", ax_net_listen as *const u8);
        builder.symbol("ax_net_accept", ax_net_accept as *const u8);
        builder.symbol("ax_net_send", ax_net_send as *const u8);
        builder.symbol("ax_net_recv", ax_net_recv as *const u8);
        builder.symbol("ax_net_close", ax_net_close as *const u8);
        let mut module = JITModule::new(builder);

        let import = |module: &mut JITModule, name: &str, nparams: usize, ret: bool| {
            let mut sig = module.make_signature();
            for _ in 0..nparams {
                sig.params.push(AbiParam::new(types::I64));
            }
            if ret {
                sig.returns.push(AbiParam::new(types::I64));
            }
            module
                .declare_function(name, Linkage::Import, &sig)
                .map_err(|e| e.to_string())
        };
        let println_id = import(&mut module, "axion_puts", 1, false)?;
        let print_id = import(&mut module, "axion_put", 1, false)?;
        let show_id = import(&mut module, "axion_show_int", 1, true)?;
        let alloc_id = import(&mut module, "axion_alloc", 1, true)?;
        let free_id = import(&mut module, "axion_free", 1, false)?;
        let arena = Arena {
            new: import(&mut module, "axion_arena_new", 0, true)?,
            alloc: import(&mut module, "axion_arena_alloc", 2, true)?,
            reset: import(&mut module, "axion_arena_reset", 1, false)?,
            mark: import(&mut module, "axion_arena_mark", 1, true)?,
            release: import(&mut module, "axion_arena_release", 1, false)?,
            promote: import(&mut module, "axion_arena_promote", 3, true)?,
        };
        // named runtime builtins (Buffer/§4): name → (FuncId, returns a value)
        let mut rt_fns: HashMap<String, (FuncId, bool)> = HashMap::new();
        for (name, nparams, ret) in [
            ("axion_buf_new", 1, true),
            ("axion_buf_iota", 1, true),
            ("axion_buf_xor", 2, true),
            ("axion_buf_sum", 1, true),
            ("axion_buf_free", 1, true),
            ("axion_fold_bytes", 3, true),
            ("axion_array_new", 2, true),
            ("axion_array_get", 2, true),
            ("axion_array_set", 3, true),
            ("axion_array_len", 1, true),
            ("axion_array_free", 1, false),
            // Show/String builtins (§tc): showFloat and strAppend
            ("axion_show_float", 1, true),
            ("axion_strcat", 2, true),
            // drops a String: frees a heap string, skips a static literal (§tc)
            ("axion_str_drop", 1, false),
            ("axion_bignum_from_i64", 1, true),
            ("axion_bignum_from_str", 1, true),
            ("axion_bignum_add", 2, true),
            ("axion_bignum_sub", 2, true),
            ("axion_bignum_mul", 2, true),
            ("axion_bignum_div", 2, true),
            ("axion_bignum_mod", 2, true),
            ("axion_bignum_eq", 2, true),
            ("axion_bignum_lt", 2, true),
            ("axion_bignum_gt", 2, true),
            ("axion_bignum_to_string", 1, true),
            // used by the generated destructors (deep-drop) via RtCall
            ("axion_free", 1, false),
            // cooperative session scheduler (§11)
            ("axion_sess_new", 0, true),
            ("axion_sess_channel", 1, true),
            ("axion_sess_send", 3, false),
            ("axion_sess_pending", 2, true),
            ("axion_sess_recv", 2, true),
            ("axion_sess_alloc", 2, true),
            ("axion_sess_spawn", 3, false),
            ("axion_sess_run", 3, true),
            ("axion_par_map", 4, true),
        ] {
            rt_fns.insert(name.into(), (import(&mut module, name, nparams, ret)?, ret));
        }

        Ok(Cg {
            module,
            ids: HashMap::new(),
            strings: HashMap::new(),
            str_counter: 0,
            println_id,
            print_id,
            show_id,
            alloc_id,
            free_id,
            arena,
            rt_fns,
            records,
        })
    }

    fn declare_all(&mut self, fns: &[CoreFn]) -> Result<(), String> {
        for f in fns {
            let mut sig = self.module.make_signature();
            // closures receive the env pointer as the 1st parameter
            let nparams = f.params.len() + usize::from(f.is_closure);
            for _ in 0..nparams {
                sig.params.push(AbiParam::new(types::I64));
            }
            sig.returns.push(AbiParam::new(types::I64));
            let id = self
                .module
                .declare_function(&f.name, Linkage::Export, &sig)
                .map_err(|e| e.to_string())?;
            self.ids.insert(f.name.clone(), (id, f.params.len()));
        }
        Ok(())
    }

    /// Builds the body of a Core function and returns the filled `Context`.
    fn build(&mut self, f: &CoreFn) -> Result<Context, String> {
        let (id, _) = self.ids[&f.name];
        let nparams = f.params.len() + usize::from(f.is_closure);
        let mut ctx = self.module.make_context();
        for _ in 0..nparams {
            ctx.func.signature.params.push(AbiParam::new(types::I64));
        }
        ctx.func.signature.returns.push(AbiParam::new(types::I64));
        ctx.func.name = UserFuncName::user(0, id.as_u32());

        let mut fbctx = FunctionBuilderContext::new();
        {
            let mut builder = FunctionBuilder::new(&mut ctx.func, &mut fbctx);
            let entry = builder.create_block();
            builder.append_block_params_for_function_params(entry);
            builder.switch_to_block(entry);
            builder.seal_block(entry);
            let argvals: Vec<Value> = builder.block_params(entry).to_vec();

            let mut fx = Fx {
                builder,
                vars: HashMap::new(),
                next: 0,
                ids: &self.ids,
                module: &mut self.module,
                strings: &mut self.strings,
                str_counter: &mut self.str_counter,
                println_id: self.println_id,
                print_id: self.print_id,
                show_id: self.show_id,
                alloc_id: self.alloc_id,
                free_id: self.free_id,
                arena: self.arena,
                rt_fns: &self.rt_fns,
                records: &self.records,
                tco: None,
            };

            if f.is_closure {
                let env = argvals[0];
                for (i, cap) in f.captures.iter().enumerate() {
                    let v =
                        fx.builder
                            .ins()
                            .load(types::I64, MemFlags::new(), env, (i as i32 + 1) * 8);
                    fx.bind_val(cap, v);
                }
                for (j, p) in f.params.iter().enumerate() {
                    fx.bind_val(p, argvals[j + 1]);
                }
            } else {
                for (j, p) in f.params.iter().enumerate() {
                    fx.bind_val(p, argvals[j]);
                }
            }

            // Tail-call optimization: a self-tail-recursive function loops instead
            // of recursing. The params are already bound to (mutable) Variables; we
            // jump into a header block and each tail self-call reassigns the params
            // and jumps back — no call/return, no stack growth.
            if core::has_tail_self_call(f) {
                let header = fx.builder.create_block();
                fx.builder.ins().jump(header, &[]);
                fx.builder.switch_to_block(header);
                fx.tco = Some((header, f.name.clone(), f.params.clone()));
                fx.emit_term_tail(&f.body)?;
                fx.builder.seal_block(header); // all back-edges emitted
            } else {
                let ret = fx.emit_term(&f.body)?;
                fx.builder.ins().return_(&[ret]);
            }
            fx.builder.finalize();
        }
        Ok(ctx)
    }
}

/// Context of emitting a function.
struct Fx<'a, 'b> {
    builder: FunctionBuilder<'b>,
    vars: HashMap<String, Variable>,
    next: u32,
    ids: &'a HashMap<String, (FuncId, usize)>,
    module: &'a mut JITModule,
    strings: &'a mut HashMap<String, DataId>,
    str_counter: &'a mut u32,
    println_id: FuncId,
    print_id: FuncId,
    show_id: FuncId,
    alloc_id: FuncId,
    free_id: FuncId,
    arena: Arena,
    rt_fns: &'a HashMap<String, (FuncId, bool)>,
    records: &'a RecordInfo,
    /// TCO: `(loop header block, this function's name, its parameter names)`. A
    /// tail self-call reassigns the params and jumps to the header instead of
    /// calling+returning. `None` for non-tail-recursive functions.
    tco: Option<(Block, String, Vec<String>)>,
}

impl Fx<'_, '_> {
    /// Interna um literal de string como objecto de dados (C-string).
    fn intern(&mut self, s: &str) -> Result<DataId, String> {
        if let Some(id) = self.strings.get(s) {
            return Ok(*id);
        }
        let name = format!("str{}", self.str_counter);
        *self.str_counter += 1;
        let id = self
            .module
            .declare_data(&name, Linkage::Local, false, false)
            .map_err(|e| e.to_string())?;
        let mut desc = DataDescription::new();
        // 8-byte ZERO size-header (mirrors `axion_alloc`), then the NUL-terminated
        // bytes. The String VALUE points past the header (see `Atom::Str`), so
        // `axion_str_drop` reads a 0 header and skips the static literal, while heap
        // strings (nonzero header) are freed.
        let mut bytes = vec![0u8; 8];
        bytes.extend_from_slice(s.as_bytes());
        bytes.push(0);
        desc.define(bytes.into_boxed_slice());
        self.module
            .define_data(id, &desc)
            .map_err(|e| e.to_string())?;
        self.strings.insert(s.to_string(), id);
        Ok(id)
    }

    /// Creates a fresh `Variable` already defined with `val`.
    fn fresh_var(&mut self, val: Value) -> Variable {
        let v = Variable::new(self.next as usize);
        self.next += 1;
        self.builder.declare_var(v, types::I64);
        self.builder.def_var(v, val);
        v
    }

    fn bind_val(&mut self, name: &str, val: Value) {
        let v = self.fresh_var(val);
        self.vars.insert(name.to_string(), v);
    }

    /// Allocates a block of `nslots` fields (i64 each) and returns the pointer.
    fn alloc(&mut self, nslots: usize) -> Value {
        let size = self.builder.ins().iconst(types::I64, nslots as i64 * 8);
        let callee = self
            .module
            .declare_func_in_func(self.alloc_id, self.builder.func);
        let call = self.builder.ins().call(callee, &[size]);
        self.builder.inst_results(call)[0]
    }

    /// Writes the constructor tag at offset 0, if the type is a sum (>1 con).
    fn store_tag(&mut self, con: &str, ptr: Value) {
        if let Some(tag) = self.records.tag(con) {
            let t = self.builder.ins().iconst(types::I64, tag as i64);
            self.builder.ins().store(MemFlags::new(), t, ptr, 0);
        }
    }

    /// Indirect call through a closure: `fn_ptr = clos[0]`, then
    /// `fn_ptr(clos, args…)` (the closure is passed as env).
    fn call_closure(&mut self, clos: Value, args: &[Value]) -> Value {
        let fn_ptr = self
            .builder
            .ins()
            .load(types::I64, MemFlags::new(), clos, 0);
        let mut sig = self.module.make_signature();
        sig.params.push(AbiParam::new(types::I64)); // env
        for _ in args {
            sig.params.push(AbiParam::new(types::I64));
        }
        sig.returns.push(AbiParam::new(types::I64));
        let sigref = self.builder.import_signature(sig);
        let mut call_args = Vec::with_capacity(args.len() + 1);
        call_args.push(clos);
        call_args.extend_from_slice(args);
        let call = self.builder.ins().call_indirect(sigref, fn_ptr, &call_args);
        self.builder.inst_results(call)[0]
    }

    /// Value of an atom (a literal or a bound variable).
    fn atom(&mut self, a: &Atom) -> Result<Value, String> {
        match a {
            Atom::Int(n) => Ok(self.builder.ins().iconst(types::I64, *n)),
            // float literal: carry its f64 bit pattern in the i64 ABI slot.
            Atom::Float(f) => Ok(self.builder.ins().iconst(types::I64, f.to_bits() as i64)),
            Atom::Str(s) => {
                let data = self.intern(s)?;
                let gv = self.module.declare_data_in_func(data, self.builder.func);
                let base = self.builder.ins().global_value(types::I64, gv);
                // point past the 8-byte size-header to the C-string bytes.
                let eight = self.builder.ins().iconst(types::I64, 8);
                Ok(self.builder.ins().iadd(base, eight))
            }
            Atom::Var(name) => match self.vars.get(name) {
                Some(v) => Ok(self.builder.use_var(*v)),
                None => Err(format!("variable '{name}' not bound in the Core")),
            },
        }
    }

    fn atoms(&mut self, xs: &[Atom]) -> Result<Vec<Value>, String> {
        xs.iter().map(|a| self.atom(a)).collect()
    }

    fn emit_term(&mut self, t: &Term) -> Result<Value, String> {
        match t {
            Term::Let(name, rhs, _, body) => {
                let v = self.emit_rhs(rhs)?;
                self.bind_val(name, v);
                self.emit_term(body)
            }
            Term::Drop(name, ty, skip, _, body) => {
                self.emit_drop(name, ty.as_deref(), skip)?;
                self.emit_term(body)
            }
            Term::Ret(rhs, _) => self.emit_rhs(rhs),
        }
    }

    /// Auto-Drop: frees the heap object at its death point (deep-drop destructor
    /// if the type owns heap fields, else a flat `free`).
    fn emit_drop(&mut self, name: &str, ty: Option<&str>, skip: &[usize]) -> Result<(), String> {
        let v = self
            .vars
            .get(name)
            .copied()
            .ok_or_else(|| format!("drop of unbound variable '{name}'"))?;
        let ptr = self.builder.use_var(v);
        // a String is reclaimed by the tagged runtime drop (frees a heap string,
        // skips a static literal via its zero size-header) — never the plain
        // `axion_free`, which would free a literal's rodata.
        if ty == Some("String") {
            let (id, _) = self.rt_fns["axion_str_drop"];
            let callee = self.module.declare_func_in_func(id, self.builder.func);
            self.builder.ins().call(callee, &[ptr]);
            return Ok(());
        }
        let deep = if skip.is_empty() {
            ty.map(|t| format!("axion_drop_{t}"))
        } else {
            let skip_name: Vec<String> = skip.iter().map(|i| i.to_string()).collect();
            ty.map(|t| format!("axion_drop_{t}_skip_{}", skip_name.join("_")))
        };
        let id = match deep.and_then(|n| self.ids.get(&n).copied()) {
            Some((id, _)) => id,
            None => self.free_id,
        };
        let callee = self.module.declare_func_in_func(id, self.builder.func);
        self.builder.ins().call(callee, &[ptr]);
        Ok(())
    }

    /// Tail-position emission (TCO): every path ends in a terminator — a `return`,
    /// or a `jump` back to the loop header for a tail self-call. Never produces a
    /// value (unlike `emit_term`), so no phi/merge is needed on tail branches.
    fn emit_term_tail(&mut self, t: &Term) -> Result<(), String> {
        match t {
            Term::Let(name, rhs, _, body) => {
                let v = self.emit_rhs(rhs)?;
                self.bind_val(name, v);
                self.emit_term_tail(body)
            }
            Term::Drop(name, ty, skip, _, body) => {
                self.emit_drop(name, ty.as_deref(), skip)?;
                self.emit_term_tail(body)
            }
            Term::Ret(rhs, _) => self.emit_rhs_tail(rhs),
        }
    }

    fn emit_rhs_tail(&mut self, rhs: &Rhs) -> Result<(), String> {
        match rhs {
            // tail self-call → reassign the params, jump to the header (the loop).
            Rhs::Op(Op::CallDirect(g, args, _))
                if self.tco.as_ref().is_some_and(|(_, name, _)| name == g) =>
            {
                let vals: Vec<Value> = args
                    .iter()
                    .map(|a| self.atom(a))
                    .collect::<Result<_, _>>()?;
                let (header, _, params) = self.tco.clone().ok_or("TCO state")?;
                for (p, v) in params.iter().zip(vals) {
                    let var = self.vars[p];
                    self.builder.def_var(var, v);
                }
                self.builder.ins().jump(header, &[]);
                Ok(())
            }
            Rhs::Op(op) => {
                let v = self.emit_op(op)?;
                self.builder.ins().return_(&[v]);
                Ok(())
            }
            Rhs::If(cond, t, e) => {
                let c = self.atom(cond)?;
                let then_b = self.builder.create_block();
                let else_b = self.builder.create_block();
                self.builder.ins().brif(c, then_b, &[], else_b, &[]);
                self.builder.switch_to_block(then_b);
                self.builder.seal_block(then_b);
                self.emit_term_tail(t)?;
                self.builder.switch_to_block(else_b);
                self.builder.seal_block(else_b);
                self.emit_term_tail(e)
            }
            Rhs::Case(scrut, arms) => {
                let s = self.atom(scrut)?;
                self.emit_case_tail(s, arms, 0)
            }
        }
    }

    fn emit_rhs(&mut self, rhs: &Rhs) -> Result<Value, String> {
        match rhs {
            Rhs::Op(op) => self.emit_op(op),
            Rhs::If(cond, t, e) => {
                let c = self.atom(cond)?;
                let then_b = self.builder.create_block();
                let else_b = self.builder.create_block();
                let merge_b = self.builder.create_block();
                self.builder.append_block_param(merge_b, types::I64);
                self.builder.ins().brif(c, then_b, &[], else_b, &[]);

                self.builder.switch_to_block(then_b);
                self.builder.seal_block(then_b);
                let tv = self.emit_term(t)?;
                self.builder.ins().jump(merge_b, &[tv]);

                self.builder.switch_to_block(else_b);
                self.builder.seal_block(else_b);
                let ev = self.emit_term(e)?;
                self.builder.ins().jump(merge_b, &[ev]);

                self.builder.switch_to_block(merge_b);
                self.builder.seal_block(merge_b);
                Ok(self.builder.block_params(merge_b)[0])
            }
            Rhs::Case(scrut, arms) => {
                let s = self.atom(scrut)?;
                self.emit_case(s, arms, 0)
            }
        }
    }

    fn emit_op(&mut self, op: &Op) -> Result<Value, String> {
        match op {
            Op::Atom(a) => self.atom(a),
            Op::Prim(o, l, r) => {
                let a = self.atom(l)?;
                let b = self.atom(r)?;
                // comparisons return I8; extended to I64 so every Core value
                // is uniformly i64 (bindable to an I64 Variable).
                let cmp = |me: &mut Self, cc| {
                    let c = me.builder.ins().icmp(cc, a, b);
                    me.builder.ins().uextend(types::I64, c)
                };
                Ok(match o.as_str() {
                    "+" => self.builder.ins().iadd(a, b),
                    "-" => self.builder.ins().isub(a, b),
                    "*" => self.builder.ins().imul(a, b),
                    "div" => self.builder.ins().sdiv(a, b),
                    "mod" => self.builder.ins().srem(a, b),
                    "band" => self.builder.ins().band(a, b),
                    "==" => cmp(self, IntCC::Equal),
                    "<" => cmp(self, IntCC::SignedLessThan),
                    ">" => cmp(self, IntCC::SignedGreaterThan),
                    other => return Err(format!("operator '{other}' does not compile natively")),
                })
            }
            // float op: bitcast the i64 bit-pattern operands to f64, compute, and
            // bitcast the f64 result back into the i64 ABI slot.
            Op::PrimF(o, l, r) => {
                let a = self.atom(l)?;
                let b = self.atom(r)?;
                let af = self.builder.ins().bitcast(types::F64, MemFlags::new(), a);
                let bf = self.builder.ins().bitcast(types::F64, MemFlags::new(), b);
                // comparisons yield a Bool (i64 0/1); arithmetic yields an f64
                // that is bitcast back into the i64 ABI slot.
                let fcmp = |me: &mut Self, cc| {
                    let c = me.builder.ins().fcmp(cc, af, bf);
                    me.builder.ins().uextend(types::I64, c)
                };
                Ok(match o.as_str() {
                    "+." => {
                        let rf = self.builder.ins().fadd(af, bf);
                        self.builder.ins().bitcast(types::I64, MemFlags::new(), rf)
                    }
                    "-." => {
                        let rf = self.builder.ins().fsub(af, bf);
                        self.builder.ins().bitcast(types::I64, MemFlags::new(), rf)
                    }
                    "*." => {
                        let rf = self.builder.ins().fmul(af, bf);
                        self.builder.ins().bitcast(types::I64, MemFlags::new(), rf)
                    }
                    "/." => {
                        let rf = self.builder.ins().fdiv(af, bf);
                        self.builder.ins().bitcast(types::I64, MemFlags::new(), rf)
                    }
                    "==." => fcmp(self, FloatCC::Equal),
                    "<." => fcmp(self, FloatCC::LessThan),
                    ">." => fcmp(self, FloatCC::GreaterThan),
                    other => {
                        return Err(format!(
                            "float operator '{other}' does not compile natively"
                        ))
                    }
                })
            }
            // Int → Float (signed) and Float → Int (truncating). The f64 is
            // carried as its i64 bit-pattern, so bitcast at the boundaries.
            Op::IntToFloat(a) => {
                let x = self.atom(a)?;
                let f = self.builder.ins().fcvt_from_sint(types::F64, x);
                Ok(self.builder.ins().bitcast(types::I64, MemFlags::new(), f))
            }
            Op::FloatToInt(a) => {
                let x = self.atom(a)?;
                let f = self.builder.ins().bitcast(types::F64, MemFlags::new(), x);
                Ok(self.builder.ins().fcvt_to_sint(types::I64, f))
            }
            // unary Float math via native Cranelift IEEE instructions.
            Op::FloatUnary(o, a) => {
                let x = self.atom(a)?;
                let f = self.builder.ins().bitcast(types::F64, MemFlags::new(), x);
                let r = match o.as_str() {
                    "sqrt" => self.builder.ins().sqrt(f),
                    "floor" => self.builder.ins().floor(f),
                    "abs" => self.builder.ins().fabs(f),
                    other => {
                        return Err(format!("float builtin '{other}' does not compile natively"))
                    }
                };
                Ok(self.builder.ins().bitcast(types::I64, MemFlags::new(), r))
            }
            Op::CallDirect(name, args, _) => {
                let (id, arity) = *self
                    .ids
                    .get(name)
                    .ok_or_else(|| format!("function '{name}' is not natively compilable"))?;
                if args.len() != arity {
                    return Err(format!("'{name}' called with wrong arity"));
                }
                let vals = self.atoms(args)?;
                let callee = self.module.declare_func_in_func(id, self.builder.func);
                let call = self.builder.ins().call(callee, &vals);
                Ok(self.builder.inst_results(call)[0])
            }
            Op::CallClosure(clos, args) => {
                let c = self.atom(clos)?;
                let vals = self.atoms(args)?;
                Ok(self.call_closure(c, &vals))
            }
            Op::MakeClosure { func, captures } => {
                let (lam_id, _) = *self
                    .ids
                    .get(func)
                    .ok_or_else(|| format!("lambda '{func}' not declared"))?;
                let env = self.alloc(1 + captures.len());
                let fref = self.module.declare_func_in_func(lam_id, self.builder.func);
                let faddr = self.builder.ins().func_addr(types::I64, fref);
                self.builder.ins().store(MemFlags::new(), faddr, env, 0);
                for (i, cap) in captures.iter().enumerate() {
                    let cv = self.atom(cap)?;
                    self.builder
                        .ins()
                        .store(MemFlags::new(), cv, env, (i as i32 + 1) * 8);
                }
                Ok(env)
            }
            Op::MakeTuple(xs) => {
                let ptr = self.alloc(xs.len());
                for (i, a) in xs.iter().enumerate() {
                    let v = self.atom(a)?;
                    self.builder
                        .ins()
                        .store(MemFlags::new(), v, ptr, i as i32 * 8);
                }
                Ok(ptr)
            }
            Op::MakeRecord { con, fields, .. } => {
                let slots = self
                    .records
                    .con_slots(con)
                    .ok_or_else(|| format!("unknown constructor '{con}'"))?;
                let ptr = self.alloc(slots);
                self.store_tag(con, ptr);
                for (fname, a) in fields {
                    let off = self
                        .records
                        .field(fname)
                        .map(|(o, _)| o)
                        .ok_or_else(|| format!("unknown field '{fname}'"))?;
                    let v = self.atom(a)?;
                    self.builder.ins().store(MemFlags::new(), v, ptr, off);
                }
                Ok(ptr)
            }
            Op::MakeCon { con, args, .. } => {
                // unboxed enum constructor (all-nullary type): an immediate tag,
                // no allocation.
                if self.records.is_enum_con(con) {
                    let idx = self.records.con_index(con);
                    return Ok(self.builder.ins().iconst(types::I64, idx as i64));
                }
                // nullary constructor of a mixed type: tagged immediate
                // `(index<<1)|1` — distinguishable from an (aligned) heap pointer.
                if self.records.is_tagged_nullary(con) {
                    let imm = ((self.records.con_index(con) as i64) << 1) | 1;
                    return Ok(self.builder.ins().iconst(types::I64, imm));
                }
                // positional `data` value (with a tag if it is a sum type)
                let slots = self
                    .records
                    .con_slots(con)
                    .ok_or_else(|| format!("unknown constructor '{con}'"))?;
                let ptr = self.alloc(slots);
                self.store_tag(con, ptr);
                for (i, a) in args.iter().enumerate() {
                    let off = self.records.field_offset(con, i);
                    let v = self.atom(a)?;
                    self.builder.ins().store(MemFlags::new(), v, ptr, off);
                }
                Ok(ptr)
            }
            Op::UpdateRecord {
                base,
                fields,
                inplace,
            } => {
                let base_ptr = self.atom(base)?;
                // Linear Elision (§2): in-place mutates the base's block and returns it;
                // otherwise allocates a new one and copies the non-updated fields.
                let target = if *inplace {
                    base_ptr
                } else {
                    let first = &fields
                        .first()
                        .ok_or_else(|| "empty record update".to_string())?
                        .0;
                    let nfields = self
                        .records
                        .field(first)
                        .map(|(_, fs)| fs.len())
                        .ok_or_else(|| format!("unknown field '{first}'"))?;
                    let newptr = self.alloc(nfields);
                    for i in 0..nfields {
                        let off = i as i32 * 8;
                        let v = self
                            .builder
                            .ins()
                            .load(types::I64, MemFlags::new(), base_ptr, off);
                        self.builder.ins().store(MemFlags::new(), v, newptr, off);
                    }
                    newptr
                };
                for (fname, a) in fields {
                    let off = self
                        .records
                        .field(fname)
                        .map(|(o, _)| o)
                        .ok_or_else(|| format!("unknown field '{fname}'"))?;
                    let v = self.atom(a)?;
                    self.builder.ins().store(MemFlags::new(), v, target, off);
                }
                Ok(target)
            }
            Op::Field { name, rec } => {
                let off = self
                    .records
                    .field(name)
                    .map(|(o, _)| o)
                    .ok_or_else(|| format!("unknown field '{name}'"))?;
                let r = self.atom(rec)?;
                Ok(self.builder.ins().load(types::I64, MemFlags::new(), r, off))
            }
            Op::LoadRaw(a, off) => {
                let r = self.atom(a)?;
                Ok(self
                    .builder
                    .ins()
                    .load(types::I64, MemFlags::new(), r, *off))
            }
            Op::StoreRaw(ptr, off, val) => {
                let p = self.atom(ptr)?;
                let v = self.atom(val)?;
                self.builder.ins().store(MemFlags::new(), v, p, *off);
                Ok(v)
            }
            Op::FuncAddr(name) => {
                let (id, _) = *self
                    .ids
                    .get(name)
                    .ok_or_else(|| format!("FuncAddr of undeclared function '{name}'"))?;
                let fref = self.module.declare_func_in_func(id, self.builder.func);
                Ok(self.builder.ins().func_addr(types::I64, fref))
            }
            Op::PutStrLn(a) => {
                let v = self.atom(a)?;
                let callee = self
                    .module
                    .declare_func_in_func(self.println_id, self.builder.func);
                self.builder.ins().call(callee, &[v]);
                Ok(self.builder.ins().iconst(types::I64, 0)) // IO () → token
            }
            Op::PutStr(a) => {
                let v = self.atom(a)?;
                let callee = self
                    .module
                    .declare_func_in_func(self.print_id, self.builder.func);
                self.builder.ins().call(callee, &[v]);
                Ok(self.builder.ins().iconst(types::I64, 0)) // IO () → token
            }
            Op::ShowInt(a) => {
                let v = self.atom(a)?;
                let callee = self
                    .module
                    .declare_func_in_func(self.show_id, self.builder.func);
                let call = self.builder.ins().call(callee, &[v]);
                Ok(self.builder.inst_results(call)[0])
            }
            // --- arenas (§3) ---
            Op::WithArena { clos, .. } => {
                // creates the (sub-)arena, runs the closure with it, resets it at the end.
                let cv = self.atom(clos)?;
                let arena = self.rt_call(self.arena.new, &[]).ok_or("arena new")?;
                let r = self.call_closure(cv, &[arena]);
                self.rt_call(self.arena.reset, &[arena]);
                Ok(r)
            }
            Op::ArenaAlloc(a) => {
                let av = self.atom(a)?;
                let sz = self.builder.ins().iconst(types::I64, CELL_SIZE);
                Ok(self
                    .rt_call(self.arena.alloc, &[av, sz])
                    .ok_or("arena call")?)
            }
            Op::Promote(t, c) => {
                let tv = self.atom(t)?;
                let cv = self.atom(c)?;
                let sz = self.builder.ins().iconst(types::I64, CELL_SIZE);
                Ok(self
                    .rt_call(self.arena.promote, &[tv, cv, sz])
                    .ok_or("arena call")?)
            }
            Op::ArenaMark(a) => {
                let av = self.atom(a)?;
                Ok(self.rt_call(self.arena.mark, &[av]).ok_or("arena call")?)
            }
            Op::ArenaRelease(m) => {
                let mv = self.atom(m)?;
                self.rt_call(self.arena.release, &[mv]);
                Ok(self.builder.ins().iconst(types::I64, 0)) // () → token
            }
            Op::RtCall {
                func,
                args,
                returns,
            } => {
                let (id, _) = *self
                    .rt_fns
                    .get(func)
                    .ok_or_else(|| format!("unknown runtime builtin '{func}'"))?;
                let vals = self.atoms(args)?;
                let r = self.rt_call(id, &vals);
                Ok(r.unwrap_or_else(|| {
                    debug_assert!(!returns);
                    self.builder.ins().iconst(types::I64, 0)
                }))
            }
            Op::Ffi { name, args } => {
                // FFI (§18): declares the C function (Int ABI) and calls it; the symbol
                // resolved via dlsym (symbol_lookup_fn).
                let mut sig = self.module.make_signature();
                for _ in args {
                    sig.params.push(AbiParam::new(types::I64));
                }
                sig.returns.push(AbiParam::new(types::I64));
                let id = self
                    .module
                    .declare_function(name, Linkage::Import, &sig)
                    .map_err(|e| e.to_string())?;
                let vals = self.atoms(args)?;
                let callee = self.module.declare_func_in_func(id, self.builder.func);
                let call = self.builder.ins().call(callee, &vals);
                Ok(self.builder.inst_results(call)[0])
            }
            Op::ArrayNew { len, init, .. } => {
                let vals = self.atoms(&[len.clone(), init.clone()])?;
                let (id, _) = *self
                    .rt_fns
                    .get("axion_array_new")
                    .ok_or_else(|| "unknown runtime builtin 'axion_array_new'".to_string())?;
                let r = self.rt_call(id, &vals);
                Ok(r.unwrap_or_else(|| self.builder.ins().iconst(types::I64, 0)))
            }
            Op::Unsupported(m) => Err(format!("{m} does not compile natively (yet)")),
        }
    }

    /// Calls a runtime function by `FuncId`; returns the result if any.
    fn rt_call(&mut self, id: FuncId, args: &[Value]) -> Option<Value> {
        let callee = self.module.declare_func_in_func(id, self.builder.func);
        let call = self.builder.ins().call(callee, args);
        self.builder.inst_results(call).first().copied()
    }

    /// `case s of arms` — an `if` chain over the scrutinee. Patterns: `Int`
    /// (compare), variable/`_` (catch-all), tuple `(a, b)` (destructure by
    /// offset). Requires a catch-all at the end.
    /// The effective constructor tag of a scrutinee, by its type's category:
    /// unboxed enum → the value itself; boxed sum → the tag at offset 0; mixed →
    /// `(v & 1) ? (v >> 1) : load[v]` (immediate nullary vs heap pointer).
    fn case_eff_tag(&mut self, sval: Value, con: &str) -> Value {
        if self.records.is_enum_con(con) {
            return sval;
        }
        if !self.records.is_mixed_con(con) {
            return self
                .builder
                .ins()
                .load(types::I64, MemFlags::new(), sval, 0);
        }
        let bit = self.builder.ins().band_imm(sval, 1);
        let imm_b = self.builder.create_block();
        let ptr_b = self.builder.create_block();
        let merge = self.builder.create_block();
        self.builder.append_block_param(merge, types::I64);
        self.builder.ins().brif(bit, imm_b, &[], ptr_b, &[]);

        self.builder.switch_to_block(imm_b);
        self.builder.seal_block(imm_b);
        let ei = self.builder.ins().ushr_imm(sval, 1);
        self.builder.ins().jump(merge, &[ei]);

        self.builder.switch_to_block(ptr_b);
        self.builder.seal_block(ptr_b);
        let ep = self
            .builder
            .ins()
            .load(types::I64, MemFlags::new(), sval, 0);
        self.builder.ins().jump(merge, &[ep]);

        self.builder.switch_to_block(merge);
        self.builder.seal_block(merge);
        self.builder.block_params(merge)[0]
    }

    /// Tail-position `case`: same tag dispatch as `emit_case`, but each arm body is
    /// emitted in tail position (terminates directly) instead of producing a value
    /// merged by a phi — so a tail self-call inside an arm becomes a loop jump.
    fn emit_case_tail(
        &mut self,
        sval: Value,
        arms: &[(CPat, Term)],
        i: usize,
    ) -> Result<(), String> {
        let (pat, body) = &arms[i];
        match pat {
            CPat::Wild => self.emit_term_tail(body),
            CPat::Var(n) => {
                self.bind_val(n, sval);
                self.emit_term_tail(body)
            }
            CPat::Tuple(ps) => {
                for (j, p) in ps.iter().enumerate() {
                    if let CPat::Var(n) = p {
                        let v = self.builder.ins().load(
                            types::I64,
                            MemFlags::new(),
                            sval,
                            j as i32 * 8,
                        );
                        self.bind_val(n, v);
                    } else if !matches!(p, CPat::Wild) {
                        return Err("nested tuple pattern does not compile natively".into());
                    }
                }
                self.emit_term_tail(body)
            }
            CPat::Int(lit) => {
                if i + 1 >= arms.len() {
                    return Err("case without catch-all does not compile natively (yet)".into());
                }
                let k = self.builder.ins().iconst(types::I64, *lit);
                let cond = self.builder.ins().icmp(IntCC::Equal, sval, k);
                self.branch_arm_tail(cond, |s| s.emit_term_tail(body), sval, arms, i)
            }
            CPat::Con(con, subpats) => match self.records.tag(con) {
                None => {
                    self.destructure_con(con, subpats, sval)?;
                    self.emit_term_tail(body)
                }
                Some(_) if i + 1 >= arms.len() => {
                    self.destructure_con(con, subpats, sval)?;
                    self.emit_term_tail(body)
                }
                Some(tag) => {
                    let ktag = self.case_eff_tag(sval, con);
                    let kt = self.builder.ins().iconst(types::I64, tag as i64);
                    let cond = self.builder.ins().icmp(IntCC::Equal, ktag, kt);
                    self.branch_arm_tail(
                        cond,
                        |s| {
                            s.destructure_con(con, subpats, sval)?;
                            s.emit_term_tail(body)
                        },
                        sval,
                        arms,
                        i,
                    )
                }
            },
        }
    }

    /// A tail-position arm test: `then` (the matched arm) and `else` (the rest of
    /// the chain) each terminate — no merge block.
    fn branch_arm_tail(
        &mut self,
        cond: Value,
        then: impl FnOnce(&mut Self) -> Result<(), String>,
        sval: Value,
        arms: &[(CPat, Term)],
        i: usize,
    ) -> Result<(), String> {
        let then_b = self.builder.create_block();
        let else_b = self.builder.create_block();
        self.builder.ins().brif(cond, then_b, &[], else_b, &[]);
        self.builder.switch_to_block(then_b);
        self.builder.seal_block(then_b);
        then(self)?;
        self.builder.switch_to_block(else_b);
        self.builder.seal_block(else_b);
        self.emit_case_tail(sval, arms, i + 1)
    }

    fn emit_case(&mut self, sval: Value, arms: &[(CPat, Term)], i: usize) -> Result<Value, String> {
        let (pat, body) = &arms[i];
        match pat {
            CPat::Wild => self.emit_term(body),
            CPat::Var(n) => {
                self.bind_val(n, sval);
                self.emit_term(body)
            }
            CPat::Tuple(ps) => {
                for (j, p) in ps.iter().enumerate() {
                    match p {
                        CPat::Wild => {}
                        CPat::Var(n) => {
                            let v = self.builder.ins().load(
                                types::I64,
                                MemFlags::new(),
                                sval,
                                j as i32 * 8,
                            );
                            self.bind_val(n, v);
                        }
                        _ => return Err("nested tuple pattern does not compile natively".into()),
                    }
                }
                self.emit_term(body)
            }
            CPat::Int(lit) => {
                if i + 1 >= arms.len() {
                    return Err("case without catch-all does not compile natively (yet)".into());
                }
                let k = self.builder.ins().iconst(types::I64, *lit);
                let cond = self.builder.ins().icmp(IntCC::Equal, sval, k);
                let then_b = self.builder.create_block();
                let else_b = self.builder.create_block();
                let merge_b = self.builder.create_block();
                self.builder.append_block_param(merge_b, types::I64);
                self.builder.ins().brif(cond, then_b, &[], else_b, &[]);

                self.builder.switch_to_block(then_b);
                self.builder.seal_block(then_b);
                let tv = self.emit_term(body)?;
                self.builder.ins().jump(merge_b, &[tv]);

                self.builder.switch_to_block(else_b);
                self.builder.seal_block(else_b);
                let ev = self.emit_case(sval, arms, i + 1)?;
                self.builder.ins().jump(merge_b, &[ev]);

                self.builder.switch_to_block(merge_b);
                self.builder.seal_block(merge_b);
                Ok(self.builder.block_params(merge_b)[0])
            }
            CPat::Con(con, subpats) => {
                // 1-constructor type (no tag) or last arm: destructure without
                // testing the tag (assumed exhaustive). Otherwise, compare the tag.
                match self.records.tag(con) {
                    None => {
                        self.destructure_con(con, subpats, sval)?;
                        self.emit_term(body)
                    }
                    Some(_) if i + 1 >= arms.len() => {
                        self.destructure_con(con, subpats, sval)?;
                        self.emit_term(body)
                    }
                    Some(tag) => {
                        let ktag = self.case_eff_tag(sval, con);
                        let kt = self.builder.ins().iconst(types::I64, tag as i64);
                        let cond = self.builder.ins().icmp(IntCC::Equal, ktag, kt);
                        let then_b = self.builder.create_block();
                        let else_b = self.builder.create_block();
                        let merge_b = self.builder.create_block();
                        self.builder.append_block_param(merge_b, types::I64);
                        self.builder.ins().brif(cond, then_b, &[], else_b, &[]);

                        self.builder.switch_to_block(then_b);
                        self.builder.seal_block(then_b);
                        self.destructure_con(con, subpats, sval)?;
                        let tv = self.emit_term(body)?;
                        self.builder.ins().jump(merge_b, &[tv]);

                        self.builder.switch_to_block(else_b);
                        self.builder.seal_block(else_b);
                        let ev = self.emit_case(sval, arms, i + 1)?;
                        self.builder.ins().jump(merge_b, &[ev]);

                        self.builder.switch_to_block(merge_b);
                        self.builder.seal_block(merge_b);
                        Ok(self.builder.block_params(merge_b)[0])
                    }
                }
            }
        }
    }

    /// Binds the sub-patterns (variables) of a constructor to its fields.
    fn destructure_con(&mut self, con: &str, subpats: &[CPat], sval: Value) -> Result<(), String> {
        for (j, p) in subpats.iter().enumerate() {
            match p {
                CPat::Wild => {}
                CPat::Var(n) => {
                    let off = self.records.field_offset(con, j);
                    let v = self
                        .builder
                        .ins()
                        .load(types::I64, MemFlags::new(), sval, off);
                    self.bind_val(n, v);
                }
                _ => return Err("nested pattern in a constructor does not compile natively".into()),
            }
        }
        Ok(())
    }
}

/// JIT-compiles the Core and runs `entry` (a parameterless function). Returns `Some(n)`
/// if `entry :: Int` (the caller prints `n`); `None` if `:: IO ()` (the effects
/// have already been executed during the run).
pub fn run(
    module: &ast::Module,
    entry: &str,
    inplace: &HashSet<Span>,
    fuse: bool,
    makecon_tys: &HashMap<Span, ast::Type>,
    integer_pats: &HashSet<Span>,
    consume_exempt: &HashSet<String>,
) -> Result<Option<i64>, String> {
    let fns = core::lower_with(module, inplace, makecon_tys, &HashMap::new(), integer_pats, consume_exempt, fuse).fns;
    let entry_ok = fns
        .iter()
        .find(|f| f.name == entry)
        .map(|f| f.params.is_empty())
        .unwrap_or(false);
    if !entry_ok {
        return Err(format!(
            "'{entry}' must be a native function (Int/IO) with no parameters"
        ));
    }

    // FFI (§18): carrega as bibliotecas do utilizador (RTLD_GLOBAL) antes de o
    // JIT to resolve symbols via `dlsym` (`symbol_lookup_fn`).
    crate::ffi::load_libs(&module.foreign_libs())?;

    let mut cg = Cg::new(RecordInfo::build(module))?;
    cg.declare_all(&fns)?;
    for f in &fns {
        let mut ctx = cg.build(f)?;
        let id = cg.ids[&f.name].0;
        cg.module
            .define_function(id, &mut ctx)
            .map_err(|e| e.to_string())?;
        cg.module.clear_context(&mut ctx);
    }
    cg.module
        .finalize_definitions()
        .map_err(|e| e.to_string())?;

    let code = cg.module.get_finalized_function(cg.ids[entry].0);
    // SAFETY: `code` is a finalized JIT function pointer with the declared
    // ABI (extern "C" fn() -> i64); Cranelift guarantees the signature.
    let f: extern "C" fn() -> i64 = unsafe { std::mem::transmute(code) };
    // Run on a thread with a large stack (lazily committed — only touched pages
    // cost memory) so deep NON-tail recursion doesn't overflow the small default
    // stack; it grows toward RAM and, at worst, hits the clean OOM abort.
    let val = std::thread::scope(|s| {
        std::thread::Builder::new()
            .stack_size(EVAL_STACK_SIZE)
            .spawn_scoped(s, || f())
            .map_err(|e| format!("spawn eval thread: {e}"))?
            .join()
            .map_err(|_| "eval thread panicked".to_string())
    });
    let val = val?;

    if std::env::var("AXION_HEAP_STATS").is_ok() {
        use std::sync::atomic::Ordering::Relaxed;
        eprintln!(
            "heap: {} allocs, {} frees",
            HEAP_ALLOCS.load(Relaxed),
            HEAP_FREES.load(Relaxed)
        );
        let (news, resets, cells) = (
            ARENA_NEWS.load(Relaxed),
            ARENA_RESETS.load(Relaxed),
            CELL_ALLOCS.load(Relaxed),
        );
        if news > 0 || cells > 0 {
            eprintln!("arena: {news} news, {resets} resets, {cells} cells");
        }
    }

    let result = module
        .funcs
        .iter()
        .find(|f| f.name == entry)
        .and_then(|f| f.sig.as_ref())
        .map(result_type);
    // `main :: Float` carries its f64 bit-pattern in the i64 ABI: reinterpret
    // and print here (the caller only knows how to print an Int).
    if result.is_some_and(is_float) {
        println!("{}", f64::from_bits(val as u64));
        return Ok(None);
    }
    // `main :: Bool` is an i64 0/1: print like the interpreter (`true`/`false`).
    if result.is_some_and(is_bool) {
        println!("{}", val != 0);
        return Ok(None);
    }
    let returns_int = result.map(is_int).unwrap_or(true);
    Ok(returns_int.then_some(val))
}

/// Emits the Cranelift IR (text) of the Core functions, without JIT
/// (`--emit clif`). The stream-fusion pass runs inside `core::lower`; the
/// `--fuse` flag is threaded through so the dump matches the JIT's code.
pub fn emit_ir(
    module: &ast::Module,
    inplace: &HashSet<Span>,
    fuse: bool,
    makecon_tys: &HashMap<Span, ast::Type>,
    integer_pats: &HashSet<Span>,
    consume_exempt: &HashSet<String>,
) -> Result<String, String> {
    let fns = core::lower_with(module, inplace, makecon_tys, &HashMap::new(), integer_pats, consume_exempt, fuse).fns;
    if fns.is_empty() {
        return Ok("; no natively compilable function (Int core).\n".into());
    }
    let mut cg = Cg::new(RecordInfo::build(module))?;
    cg.declare_all(&fns)?;
    let mut out = String::new();
    for f in &fns {
        let ctx = cg.build(f)?;
        out.push_str(&format!("{}\n", ctx.func.display()));
    }
    Ok(out)
}
