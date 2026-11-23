//! Loading shared libraries for the FFI (§18).
//!
//! `foreign "lib.so" name :: …` loads `lib.so` with `RTLD_NOW | RTLD_GLOBAL`,
#![allow(unsafe_code)]
//! making its symbols visible to the `dlsym(RTLD_DEFAULT)` resolution the
//! three executors use (interp, `--dev`/JIT, `--release`/clang). Without a
//! string → only symbols **already** loaded resolve (libc + axionc runtime).

use std::ffi::{c_char, c_int, c_void, CStr, CString};

const RTLD_NOW: c_int = 2;
const RTLD_GLOBAL: c_int = 0x100;

extern "C" {
    fn dlopen(filename: *const c_char, flag: c_int) -> *mut c_void;
    fn dlerror() -> *const c_char;
}

/// Is `lib` one of glibc's core C-runtime sonames (`libc.so.6`, `libm.so.6`, …)? On glibc they are
/// loaded/linked as written (unchanged behaviour). Elsewhere (FreeBSD: `libc.so.7`, `libm.so.5`,
/// dl/pthread folded into libc/libthr) those filenames don't exist, so they are mapped to the
/// platform's own C runtime — letting the same program (`foreign "libm.so.6" sin :: …`) run on
/// both. `--release` always links `-lc -lm`, so it can skip every one of them.
pub fn is_system_c_runtime(lib: &str) -> bool {
    if cfg!(all(target_os = "linux", target_env = "gnu")) {
        return false;
    }
    let base = lib.rsplit('/').next().unwrap_or(lib);
    matches!(
        base,
        "libc.so.6" | "libm.so.6" | "libdl.so.2" | "libpthread.so.0" | "librt.so.1"
    )
}

/// The name to `dlopen` for `lib` on this platform, or `None` when there is nothing to load (a
/// glibc C-runtime soname whose symbols are already in the process). libm is the exception: off
/// glibc it is usually a separate library the process need not have loaded, so it is opened by
/// the platform's unversioned dev name (`libm.so` → `libm.so.5` on FreeBSD); macOS's is libSystem.
fn dlopen_name(lib: &str) -> Option<&str> {
    if !is_system_c_runtime(lib) {
        return Some(lib);
    }
    let is_libm = lib.rsplit('/').next() == Some("libm.so.6");
    (is_libm && !cfg!(any(target_os = "macos", target_os = "ios"))).then_some("libm.so")
}

/// Loads each library into the **global** symbol space. `RTLD_GLOBAL` makes them
/// appear in the subsequent `dlsym(RTLD_DEFAULT)` resolutions (interp and `--dev`);
/// idempotent per path (`dlopen` reuses the handle). The handles stay
/// open for the whole run (no `dlclose`). Fails with the `dlerror` message.
pub fn load_libs(libs: &[String]) -> Result<(), String> {
    for lib in libs.iter().filter_map(|l| dlopen_name(l)) {
        let c = CString::new(lib).map_err(|_| format!("invalid FFI library path: '{lib}'"))?;
        // SAFETY: `dlopen` loads a shared library; `c` is a valid
        // NUL-terminated C string, and the flags are POSIX-conforming.
        let h = unsafe { dlopen(c.as_ptr(), RTLD_NOW | RTLD_GLOBAL) };
        if h.is_null() {
            // SAFETY: `dlerror` returns a static error string; the null
            // check guards against the rare case where it returns NULL.
            let err = unsafe {
                let e = dlerror();
                if e.is_null() {
                    String::new()
                } else {
                    CStr::from_ptr(e).to_string_lossy().into_owned()
                }
            };
            return Err(format!("could not load FFI library '{lib}': {err}"));
        }
    }
    Ok(())
}
