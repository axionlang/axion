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

/// Loads each library into the **global** symbol space. `RTLD_GLOBAL` makes them
/// appear in the subsequent `dlsym(RTLD_DEFAULT)` resolutions (interp and `--dev`);
/// idempotent per path (`dlopen` reuses the handle). The handles stay
/// open for the whole run (no `dlclose`). Fails with the `dlerror` message.
pub fn load_libs(libs: &[String]) -> Result<(), String> {
    for lib in libs {
        let c =
            CString::new(lib.as_str()).map_err(|_| format!("invalid FFI library path: '{lib}'"))?;
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
