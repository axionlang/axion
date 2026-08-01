//! Native `--dev` backend (§11/§18): the "Fast-Path Backend" over Cranelift.
//!
//! Emits native code from the **Axion Core IR** (see `core.rs`), not the AST:
//! the Core is already in ANF (each subexpression named), with multi-clause
//! desugaring, `where` *lifting* and closure conversion resolved,
//! so this file is a plain Core→Cranelift emitter. JIT-compiles via
//! `cranelift-jit`. All values are `i64` (Int, pointers, IO tokens).
//! Strings/IO and allocation (records, tuples, closures) via a minimal runtime
//! (`axion_puts`/`axion_show_int`/`axion_alloc`). The same Core serves the
//! LLVM `--release` backend.

use crate::ast;
use crate::ast::Span;
use crate::core::{
    self, is_bool, is_float, is_int, result_type, Atom, CPat, CoreFn, Op, RecordInfo, Rhs, Term,
};
use cranelift::codegen::ir::UserFuncName;
use cranelift::codegen::Context;
use cranelift::prelude::{
    types, AbiParam, Configurable, EntityRef, FloatCC, FunctionBuilder, FunctionBuilderContext,
    InstBuilder, IntCC, MemFlags, Value, Variable,
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
    let p = unsafe { dlsym(std::ptr::null_mut(), cname.as_ptr()) };
    (!p.is_null()).then_some(p as *const u8)
}

// --- minimal native runtime (registered as symbols in the JIT) ---

/// `putStrLn`: prints a C-string with a newline.
extern "C" fn axion_puts(ptr: *const u8) {
    let s = unsafe { std::ffi::CStr::from_ptr(ptr as *const std::ffi::c_char) };
    println!("{}", s.to_string_lossy());
}

/// `putStr`: prints a C-string WITHOUT a newline.
extern "C" fn axion_put(ptr: *const u8) {
    use std::io::Write;
    let s = unsafe { std::ffi::CStr::from_ptr(ptr as *const std::ffi::c_char) };
    print!("{}", s.to_string_lossy());
    let _ = std::io::stdout().flush();
}

/// `show :: Int -> String`: formats an integer and returns a C-string (leaked;
/// lives until the end of the process — acceptable for a single `run`).
extern "C" fn axion_show_int(n: i64) -> *const u8 {
    let s = std::ffi::CString::new(n.to_string()).unwrap();
    s.into_raw() as *const u8
}

/// `show :: Float -> String`: the shortest round-tripping decimal (matching Rust
/// `{}`), as a C-string. The i64 argument is the f64 bit pattern.
extern "C" fn axion_show_float(bits: i64) -> *const u8 {
    let s = std::ffi::CString::new(f64::from_bits(bits as u64).to_string()).unwrap();
    s.into_raw() as *const u8
}

/// String concatenation `a ++ b` into a fresh C-string. Backs `strAppend`.
extern "C" fn axion_strcat(a: *const u8, b: *const u8) -> *const u8 {
    let (x, y) = unsafe {
        (
            std::ffi::CStr::from_ptr(a as *const std::ffi::c_char),
            std::ffi::CStr::from_ptr(b as *const std::ffi::c_char),
        )
    };
    let mut s = x.to_bytes().to_vec();
    s.extend_from_slice(y.to_bytes());
    std::ffi::CString::new(s).unwrap().into_raw() as *const u8
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
    let layout = std::alloc::Layout::from_size_align(total, 8).unwrap();
    unsafe {
        let base = std::alloc::alloc(layout);
        *(base as *mut u64) = total as u64; // header: total size
        HEAP_ALLOCS.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
        base.add(8) // payload
    }
}

/// Frees an object allocated by `axion_alloc` (reads the size from the header).
extern "C" fn axion_free(ptr: *mut u8) {
    unsafe {
        let base = ptr.sub(8);
        let total = *(base as *const u64) as usize;
        let layout = std::alloc::Layout::from_size_align(total, 8).unwrap();
        std::alloc::dealloc(base, layout);
        HEAP_FREES.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
    }
}

// --- arena runtime (§3): bump-allocator with bulk reset ---

static ARENA_NEWS: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(0);
static ARENA_RESETS: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(0);
static CELL_ALLOCS: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(0);

/// Fixed size of a `Cell` (§3). Opaque to the program (`useCell` returns 0).
const CELL_SIZE: i64 = 16;

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

extern "C" fn axion_arena_alloc(arena: *mut u8, size: i64) -> *mut u8 {
    CELL_ALLOCS.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
    let st = unsafe { &mut *(arena as *mut ArenaState) };
    st.alloc(size as usize)
}

/// Bulk reset: drops the whole arena (all chunks at once).
extern "C" fn axion_arena_reset(arena: *mut u8) {
    ARENA_RESETS.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
    unsafe { drop(Box::from_raw(arena as *mut ArenaState)) };
}

extern "C" fn axion_arena_mark(arena: *mut u8) -> *mut u8 {
    let st = unsafe { &*(arena as *mut ArenaState) };
    Box::into_raw(Box::new(MarkState {
        arena: arena as *mut ArenaState,
        chunk: st.chunk,
        off: st.off,
    })) as *mut u8
}

/// Restores the bump-pointer to the mark (reclaims what was allocated since).
extern "C" fn axion_arena_release(mark: *mut u8) {
    let m = unsafe { Box::from_raw(mark as *mut MarkState) };
    let st = unsafe { &mut *m.arena };
    st.chunks.truncate(m.chunk + 1);
    st.chunk = m.chunk;
    st.off = m.off;
}

/// Copies a cell to arena `target` (saves it from the sub-arena reset).
extern "C" fn axion_arena_promote(target: *mut u8, cell: *mut u8, size: i64) -> *mut u8 {
    let st = unsafe { &mut *(target as *mut ArenaState) };
    let dst = st.alloc(size as usize);
    unsafe { std::ptr::copy_nonoverlapping(cell, dst, size as usize) };
    dst
}

// --- Linear Buffer U8 (§4/§5): [len(i64)][bytes…]. The bulk operations are the
// imperative/vectorizable escape-hatch (in --release; in --dev at the speed of
// axionc's Rust runtime). Layout of 8 (header) + n bytes; 8+n is allocated
// rounded up to the `Layout`'s alignment. ---

fn buf_layout(n: usize) -> std::alloc::Layout {
    std::alloc::Layout::from_size_align(8 + n, 8).unwrap()
}

extern "C" fn axion_buf_new(n: i64) -> *mut u8 {
    let n = n.max(0) as usize;
    unsafe {
        let b = std::alloc::alloc_zeroed(buf_layout(n));
        *(b as *mut i64) = n as i64;
        b
    }
}

extern "C" fn axion_buf_iota(buf: *mut u8) -> *mut u8 {
    unsafe {
        let n = *(buf as *const i64) as usize;
        let d = buf.add(8);
        for i in 0..n {
            *d.add(i) = (i & 0xFF) as u8;
        }
    }
    buf
}

extern "C" fn axion_buf_xor(buf: *mut u8, key: i64) -> *mut u8 {
    unsafe {
        let n = *(buf as *const i64) as usize;
        let d = buf.add(8);
        for i in 0..n {
            *d.add(i) ^= key as u8;
        }
    }
    buf
}

extern "C" fn axion_buf_sum(buf: *mut u8) -> i64 {
    unsafe {
        let n = *(buf as *const i64) as usize;
        let d = buf.add(8);
        let mut s = 0i64;
        for i in 0..n {
            s = s.wrapping_add(*d.add(i) as i64);
        }
        s
    }
}

extern "C" fn axion_buf_free(buf: *mut u8) {
    unsafe {
        let n = *(buf as *const i64) as usize;
        std::alloc::dealloc(buf, buf_layout(n));
    }
}

/// `foldBytes f init buf`: folds the closure `f` over the bytes. Reads the `fn_ptr` from
/// `f[0]` and calls `fn_ptr(f, acc, byte)` per byte (the closure is the env).
extern "C" fn axion_fold_bytes(f: *mut u8, init: i64, buf: *mut u8) -> i64 {
    unsafe {
        let fn_ptr = *(f as *const i64);
        let func: extern "C" fn(*mut u8, i64, i64) -> i64 = std::mem::transmute(fn_ptr);
        let n = *(buf as *const i64) as usize;
        let d = buf.add(8);
        let mut acc = init;
        for i in 0..n {
            acc = func(f, acc, *d.add(i) as i64);
        }
        acc
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
}

struct SessSched {
    inner: std::sync::Mutex<SessInner>,
    done: std::sync::atomic::AtomicBool, // root finished
    result: std::sync::atomic::AtomicI64,
    budget: std::sync::atomic::AtomicI64, // safety net against a livelock bug
}

fn sess<'a>(sched: i64) -> &'a SessSched {
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
        }),
        done: AtomicBool::new(false),
        result: AtomicI64::new(0),
        budget: AtomicI64::new(2_000_000_000),
    })) as i64
}

/// Creates a channel: two peer endpoints, `a` and `a+1` (mirrors newChannel).
extern "C" fn axion_sess_channel(sched: i64) -> i64 {
    let mut g = sess(sched).inner.lock().unwrap();
    let a = g.bufs.len();
    g.bufs.push(Default::default());
    g.bufs.push(Default::default());
    g.peer.push(a + 1);
    g.peer.push(a);
    a as i64
}

/// Sends `v` on `ep` → pushes to the peer's input queue and wakes parked receivers.
extern "C" fn axion_sess_send(sched: i64, ep: i64, v: i64) {
    let mut g = sess(sched).inner.lock().unwrap();
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
    let g = sess(sched).inner.lock().unwrap();
    i64::from(!g.bufs[ep as usize].is_empty())
}

/// Pops and returns the message on `ep` (caller guarantees pending; SPSC consumer).
extern "C" fn axion_sess_recv(sched: i64, ep: i64) -> i64 {
    let mut g = sess(sched).inner.lock().unwrap();
    g.bufs[ep as usize].pop_front().unwrap_or(0)
}

/// Allocates a zeroed task-state block owned by the scheduler (the nursery arena);
/// all such blocks are freed in bulk when `axion_sess_run` returns.
extern "C" fn axion_sess_alloc(sched: i64, nbytes: i64) -> i64 {
    let size = nbytes.max(8) as usize;
    let layout = std::alloc::Layout::from_size_align(size, 8).unwrap();
    let p = unsafe { std::alloc::alloc_zeroed(layout) };
    sess(sched)
        .inner
        .lock()
        .unwrap()
        .allocs
        .push((p as usize, layout));
    p as i64
}

extern "C" fn axion_sess_spawn(sched: i64, step: i64, state: i64) {
    let f: SessStep = unsafe { std::mem::transmute::<i64, SessStep>(step) };
    let mut g = sess(sched).inner.lock().unwrap();
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
            let mut g = s.inner.lock().unwrap();
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
        let mut g = s.inner.lock().unwrap();
        g.running -= 1;
        if status == 1 {
            if i == 0 {
                let res = unsafe { *(st as *const i64) };
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
    let boxed = unsafe { Box::from_raw(sched as *mut SessSched) };
    let inner = boxed.inner.into_inner().unwrap();
    for (p, layout) in inner.allocs {
        unsafe { std::alloc::dealloc(p as *mut u8, layout) };
    }
    result
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
    puts_id: FuncId,
    put_id: FuncId,
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
        let _ = flags.set("opt_level", "none"); // fast-path (§11)
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
        builder.symbol("axion_sess_new", axion_sess_new as *const u8);
        builder.symbol("axion_sess_channel", axion_sess_channel as *const u8);
        builder.symbol("axion_sess_send", axion_sess_send as *const u8);
        builder.symbol("axion_sess_pending", axion_sess_pending as *const u8);
        builder.symbol("axion_sess_recv", axion_sess_recv as *const u8);
        builder.symbol("axion_sess_alloc", axion_sess_alloc as *const u8);
        builder.symbol("axion_sess_spawn", axion_sess_spawn as *const u8);
        builder.symbol("axion_sess_run", axion_sess_run as *const u8);
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
        let puts_id = import(&mut module, "axion_puts", 1, false)?;
        let put_id = import(&mut module, "axion_put", 1, false)?;
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
            ("axion_buf_free", 1, false),
            ("axion_fold_bytes", 3, true),
            // Show/String builtins (§tc): showFloat and strAppend
            ("axion_show_float", 1, true),
            ("axion_strcat", 2, true),
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
        ] {
            rt_fns.insert(name.into(), (import(&mut module, name, nparams, ret)?, ret));
        }

        Ok(Cg {
            module,
            ids: HashMap::new(),
            strings: HashMap::new(),
            str_counter: 0,
            puts_id,
            put_id,
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
                puts_id: self.puts_id,
                put_id: self.put_id,
                show_id: self.show_id,
                alloc_id: self.alloc_id,
                free_id: self.free_id,
                arena: self.arena,
                rt_fns: &self.rt_fns,
                records: &self.records,
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

            let ret = fx.emit_term(&f.body)?;
            fx.builder.ins().return_(&[ret]);
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
    puts_id: FuncId,
    put_id: FuncId,
    show_id: FuncId,
    alloc_id: FuncId,
    free_id: FuncId,
    arena: Arena,
    rt_fns: &'a HashMap<String, (FuncId, bool)>,
    records: &'a RecordInfo,
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
        let mut bytes = s.as_bytes().to_vec();
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
                Ok(self.builder.ins().global_value(types::I64, gv))
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
            Term::Let(name, rhs, body) => {
                let v = self.emit_rhs(rhs)?;
                self.bind_val(name, v);
                self.emit_term(body)
            }
            Term::Drop(name, ty, body) => {
                // Auto-Drop: frees the heap object at its death point. If the
                // type owns heap fields, calls the generated recursive destructor
                // (deep-drop); otherwise, a flat `free`.
                let v = self
                    .vars
                    .get(name)
                    .copied()
                    .ok_or_else(|| format!("drop of unbound variable '{name}'"))?;
                let ptr = self.builder.use_var(v);
                let deep = ty
                    .as_deref()
                    .filter(|t| self.records.needs_deep_drop(t))
                    .map(|t| format!("axion_drop_{t}"));
                match deep.and_then(|n| self.ids.get(&n).copied()) {
                    Some((id, _)) => {
                        let callee = self.module.declare_func_in_func(id, self.builder.func);
                        self.builder.ins().call(callee, &[ptr]);
                    }
                    None => {
                        let callee = self
                            .module
                            .declare_func_in_func(self.free_id, self.builder.func);
                        self.builder.ins().call(callee, &[ptr]);
                    }
                }
                self.emit_term(body)
            }
            Term::Ret(rhs) => self.emit_rhs(rhs),
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
                        return Err(format!("float operator '{other}' does not compile natively"))
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
                    other => return Err(format!("float builtin '{other}' does not compile natively")),
                };
                Ok(self.builder.ins().bitcast(types::I64, MemFlags::new(), r))
            }
            Op::CallDirect(name, args) => {
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
            Op::MakeRecord { con, fields } => {
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
            Op::MakeCon { con, args } => {
                // unboxed enum constructor (all-nullary type): an immediate tag,
                // no allocation.
                if self.records.is_enum_con(con) {
                    let idx = self.records.con_index(con);
                    return Ok(self.builder.ins().iconst(types::I64, idx as i64));
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
                    .declare_func_in_func(self.puts_id, self.builder.func);
                self.builder.ins().call(callee, &[v]);
                Ok(self.builder.ins().iconst(types::I64, 0)) // IO () → token
            }
            Op::PutStr(a) => {
                let v = self.atom(a)?;
                let callee = self
                    .module
                    .declare_func_in_func(self.put_id, self.builder.func);
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
                let arena = self.rt_call(self.arena.new, &[]).unwrap();
                let r = self.call_closure(cv, &[arena]);
                self.rt_call(self.arena.reset, &[arena]);
                Ok(r)
            }
            Op::ArenaAlloc(a) => {
                let av = self.atom(a)?;
                let sz = self.builder.ins().iconst(types::I64, CELL_SIZE);
                Ok(self.rt_call(self.arena.alloc, &[av, sz]).unwrap())
            }
            Op::Promote(t, c) => {
                let tv = self.atom(t)?;
                let cv = self.atom(c)?;
                let sz = self.builder.ins().iconst(types::I64, CELL_SIZE);
                Ok(self.rt_call(self.arena.promote, &[tv, cv, sz]).unwrap())
            }
            Op::ArenaMark(a) => {
                let av = self.atom(a)?;
                Ok(self.rt_call(self.arena.mark, &[av]).unwrap())
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
                        // unboxed enum: the value IS the tag (immediate); boxed sum:
                        // the tag lives at offset 0 of the heap object.
                        let ktag = if self.records.is_enum_con(con) {
                            sval
                        } else {
                            self.builder
                                .ins()
                                .load(types::I64, MemFlags::new(), sval, 0)
                        };
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
) -> Result<Option<i64>, String> {
    let fns = core::lower(module, inplace);
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
    let f: extern "C" fn() -> i64 = unsafe { std::mem::transmute(code) };
    let val = f();

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

/// Emits the Cranelift IR (text) of the Core functions, without JIT (`--emit clif`).
pub fn emit_ir(module: &ast::Module, inplace: &HashSet<Span>) -> Result<String, String> {
    let fns = core::lower(module, inplace);
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
