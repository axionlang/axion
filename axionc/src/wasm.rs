//! The browser playground entry (`--features wasm`). Compiles and runs a single Axion
//! program through the front-end + interpreter (no native backends, no FFI) and returns
//! the result as JSON for the web UI in `web/`.
//!
//! Build: `cargo build --target wasm32-unknown-unknown --no-default-features --features
//! wasm --release`, then `wasm-bindgen target/…/axionc.wasm --target web --out-dir web/pkg`.

use wasm_bindgen::prelude::wasm_bindgen;

/// Minimal JSON string escaping (the output can hold quotes, newlines, control chars).
fn json_str(s: &str) -> String {
    let mut o = String::with_capacity(s.len() + 2);
    o.push('"');
    for c in s.chars() {
        match c {
            '"' => o.push_str("\\\""),
            '\\' => o.push_str("\\\\"),
            '\n' => o.push_str("\\n"),
            '\r' => o.push_str("\\r"),
            '\t' => o.push_str("\\t"),
            c if (c as u32) < 0x20 => o.push_str(&format!("\\u{:04x}", c as u32)),
            c => o.push(c),
        }
    }
    o.push('"');
    o
}

/// Compile and run `src`, returning a JSON object:
/// `{ "output": string, "diagnostics": [{code,severity,message,line,col}], "error": string|null }`.
/// `output` is the program's captured stdout; `diagnostics` are the compiler's `AXnnnn`
/// findings (with 1-based line/col of the first label); `error` is a runtime error, if any.
/// The program is only run when the front-end produced a module with no error diagnostics.
#[wasm_bindgen]
pub fn compile_and_run(src: &str) -> String {
    use crate::diag::Severity;

    let mut diags = crate::diag::Diagnostics::default();
    // `compile_front` can `panic!` (e.g. a malformed prelude never should, but be safe);
    // catch it so one bad program can't take the whole playground down (effective when
    // built with panic=unwind).
    let module = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        crate::compile_front(src, "playground.axi", &mut diags).0
    }))
    .unwrap_or(None);

    let lines = crate::lexer::LineMap::new(src);
    let mut diag_json = String::new();
    for (i, d) in diags.items.iter().enumerate() {
        if i > 0 {
            diag_json.push(',');
        }
        let (line, col) = d.labels.first().map_or((1, 1), |l| lines.pos(l.start));
        let severity = match d.severity {
            Severity::Error => "error",
            Severity::Warning => "warning",
        };
        diag_json.push_str(&format!(
            "{{\"code\":{},\"severity\":{},\"message\":{},\"line\":{line},\"col\":{col}}}",
            json_str(&d.code),
            json_str(severity),
            json_str(&d.message),
        ));
    }

    let has_error = diags
        .items
        .iter()
        .any(|d| matches!(d.severity, Severity::Error));
    let (output, error) = match (&module, has_error) {
        (Some(m), false) => {
            match std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
                crate::interp::run_capture(m)
            })) {
                Ok(Ok(out)) => (out, None),
                Ok(Err(e)) => (String::new(), Some(e)),
                Err(_) => (String::new(), Some("the interpreter panicked".to_string())),
            }
        }
        _ => (String::new(), None),
    };

    format!(
        "{{\"output\":{},\"diagnostics\":[{diag_json}],\"error\":{}}}",
        json_str(&output),
        error.map_or_else(|| "null".to_string(), |e| json_str(&e)),
    )
}
