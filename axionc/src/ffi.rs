//! Carregamento de bibliotecas partilhadas para o FFI (§18).
//!
//! `foreign "lib.so" nome :: …` carrega `lib.so` com `RTLD_NOW | RTLD_GLOBAL`,
//! tornando os seus símbolos visíveis à resolução por `dlsym(RTLD_DEFAULT)` que
//! os três executores usam (interp, `--dev`/JIT, `--release`/clang). Sem string
//! → só se resolvem símbolos **já** carregados (libc + runtime do axionc).

use std::ffi::{c_char, c_int, c_void, CStr, CString};

const RTLD_NOW: c_int = 2;
const RTLD_GLOBAL: c_int = 0x100;

extern "C" {
    fn dlopen(filename: *const c_char, flag: c_int) -> *mut c_void;
    fn dlerror() -> *const c_char;
}

/// Carrega cada biblioteca no espaço **global** de símbolos. `RTLD_GLOBAL` fá-los
/// aparecer nas resoluções `dlsym(RTLD_DEFAULT)` seguintes (interp e `--dev`);
/// idempotente por caminho (o `dlopen` reaproveita o handle). Os handles ficam
/// abertos toda a execução (sem `dlclose`). Falha com a mensagem de `dlerror`.
pub fn load_libs(libs: &[String]) -> Result<(), String> {
    for lib in libs {
        let c = CString::new(lib.as_str())
            .map_err(|_| format!("caminho de biblioteca FFI inválido: '{lib}'"))?;
        let h = unsafe { dlopen(c.as_ptr(), RTLD_NOW | RTLD_GLOBAL) };
        if h.is_null() {
            let err = unsafe {
                let e = dlerror();
                if e.is_null() {
                    String::new()
                } else {
                    CStr::from_ptr(e).to_string_lossy().into_owned()
                }
            };
            return Err(format!(
                "não consegui carregar a biblioteca FFI '{lib}': {err}"
            ));
        }
    }
    Ok(())
}
