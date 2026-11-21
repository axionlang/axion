//! Structured diagnostics with stable `AXnnnn` codes (§8).
//!
//! A `Diagnostic` carries a code, severity, message, labeled spans and an
//! optional help. It renders as text (rustc style: file:line:column,
//! source line and arrows) or as JSON (`--emit json`), as §8 mandates. The
//! registry of codes lives in `docs/error-codes.md`.

use crate::lexer::LineMap;
use serde::Serialize;

#[derive(Debug, Clone, Copy, PartialEq, Serialize)]
#[cfg_attr(feature = "salsa", derive(salsa::SalsaValue))] // already PartialEq above
#[serde(rename_all = "lowercase")]
pub enum Severity {
    Error,
    Warning,
}

#[derive(Debug, Clone, Serialize)]
#[cfg_attr(feature = "salsa", derive(salsa::SalsaValue, PartialEq))]
pub struct Label {
    pub start: usize,
    pub end: usize,
    pub message: String,
}

/// A machine-applicable fix (§8): replace the source span `start..end` with
/// `replacement`. Emitted in `--emit json` so editors/tools can auto-apply, and
/// rendered as a `suggestion:` line in text output.
#[derive(Debug, Clone, Serialize)]
#[cfg_attr(feature = "salsa", derive(salsa::SalsaValue, PartialEq))]
pub struct Fix {
    pub start: usize,
    pub end: usize,
    pub replacement: String,
    pub message: String,
}

#[derive(Debug, Clone, Serialize)]
#[cfg_attr(feature = "salsa", derive(salsa::SalsaValue, PartialEq))]
pub struct Diagnostic {
    pub code: String, // ex.: "AX0001"
    pub severity: Severity,
    pub message: String,
    pub labels: Vec<Label>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub help: Option<String>,
    // Boxed to keep `Diagnostic` small: it is the `Err` type of several `Result`s,
    // and a large error variant is moved around by value (clippy `result_large_err`).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub fix: Option<Box<Fix>>,
}

impl Diagnostic {
    pub fn error(code: &str, message: impl Into<String>) -> Self {
        Diagnostic {
            code: code.to_string(),
            severity: Severity::Error,
            message: message.into(),
            labels: Vec::new(),
            help: None,
            fix: None,
        }
    }

    pub fn warning(code: &str, message: impl Into<String>) -> Self {
        Diagnostic {
            code: code.to_string(),
            severity: Severity::Warning,
            message: message.into(),
            labels: Vec::new(),
            help: None,
            fix: None,
        }
    }

    pub fn label(mut self, start: usize, end: usize, message: impl Into<String>) -> Self {
        self.labels.push(Label {
            start,
            end,
            message: message.into(),
        });
        self
    }

    pub fn with_help(mut self, help: impl Into<String>) -> Self {
        self.help = Some(help.into());
        self
    }

    /// Attach a machine-applicable fix: replace `start..end` with `replacement`.
    pub fn with_fix(
        mut self,
        start: usize,
        end: usize,
        replacement: impl Into<String>,
        message: impl Into<String>,
    ) -> Self {
        self.fix = Some(Box::new(Fix {
            start,
            end,
            replacement: replacement.into(),
            message: message.into(),
        }));
        self
    }

    /// Text render, in the rustc/§8 style.
    pub fn render(&self, path: &str, src: &str, lines: &LineMap) -> String {
        let sev = match self.severity {
            Severity::Error => "error",
            Severity::Warning => "warning",
        };
        let mut out = format!("{sev}[{}]: {}\n", self.code, self.message);
        for (i, lbl) in self.labels.iter().enumerate() {
            let (start, end) = (lbl.start % CLONE_SPAN_STRIDE, lbl.end % CLONE_SPAN_STRIDE);
            // a span inside an IMPORTED module is rendered against that module's own file
            let imported = imported_file(lbl.start / CLONE_SPAN_STRIDE);
            let other = imported
                .as_ref()
                .map(|(p, s)| (p.as_str(), s.as_str(), LineMap::new(s)));
            let (path, src, lines) = match &other {
                Some((p, s, l)) => (*p, *s, l),
                None => (path, src, lines),
            };
            let (line, col) = lines.pos(start);
            let (_, end_col) = lines.pos(end.max(start));
            let width = (end_col.saturating_sub(col)).max(1);
            let src_line = src.lines().nth(line - 1).unwrap_or("");
            let gutter = format!("{line}");
            let pad = " ".repeat(gutter.len());
            if i == 0 {
                out.push_str(&format!("{pad} --> {path}:{line}:{col}\n"));
            }
            out.push_str(&format!("{pad} |\n"));
            out.push_str(&format!("{gutter} | {src_line}\n"));
            out.push_str(&format!(
                "{pad} | {}{} {}\n",
                " ".repeat(col.saturating_sub(1)),
                "^".repeat(width),
                lbl.message
            ));
        }
        if let Some(help) = &self.help {
            out.push_str(&format!("  = help: {help}\n"));
        }
        if let Some(fix) = &self.fix {
            out.push_str(&format!(
                "  = suggestion: {} (replace with `{}`)\n",
                fix.message, fix.replacement
            ));
        }
        out
    }
}

/// Spans of a specialization clone are its source's spans shifted by a multiple of this stride
/// (so the clones' inference keys stay distinct); `span % CLONE_SPAN_STRIDE` recovers the source
/// span. Source files are far smaller than the stride.
pub const CLONE_SPAN_STRIDE: usize = 10_000_000;

/// Span band of the injected prelude. Its source and every imported module's are parsed from
/// offset 0, like the user's file, so without a band of their own a prelude expression and a user
/// expression at the same byte offsets share every span-keyed inference fact (a call's result type
/// → its drop key). Far above any clone band; kept inside `u32` on 32-bit targets (the wasm
/// playground).
pub const PRELUDE_SPAN_BAND: usize = if usize::BITS >= 64 { 1 << 24 } else { 300 };

/// Span band of the instances `deriving` generates. They are parsed from generated source starting
/// at offset 0, so in the user's band a derived method's expression would share span-keyed
/// inference facts with the user expression at the same offsets (a call's result type, which
/// keys its drop). Just below the prelude band: far above any clone band, and still classified
/// like the user's band everywhere a band is tested.
pub const DERIVED_SPAN_BAND: usize = PRELUDE_SPAN_BAND - 1;

/// Span band of the functions generated for a `foreign struct` (constructor and field selectors),
/// parsed from offset 0 like derived instances, for the same reason.
pub const STRUCT_SPAN_BAND: usize = PRELUDE_SPAN_BAND - 2;

/// The file each imported module's span band came from (`register_import_band`), so a diagnostic
/// inside an imported module names that file and its line instead of the importer's.
static IMPORT_BANDS: std::sync::Mutex<Vec<(usize, String)>> = std::sync::Mutex::new(Vec::new());

/// Records that span band `band` (a multiple of `CLONE_SPAN_STRIDE`, above the prelude's) holds the
/// module parsed from `path`.
pub fn register_import_band(band: usize, path: &str) {
    if let Ok(mut b) = IMPORT_BANDS.lock() {
        b.retain(|(k, _)| *k != band);
        b.push((band, path.to_string()));
    }
}

/// A clone's span mapped back to its source span; an imported module's span keeps its band.
fn unclone_span(x: usize) -> usize {
    let band = x / CLONE_SPAN_STRIDE;
    let imported = band > PRELUDE_SPAN_BAND
        && IMPORT_BANDS
            .lock()
            .is_ok_and(|b| b.iter().any(|(k, _)| *k == band));
    if imported {
        x
    } else {
        x % CLONE_SPAN_STRIDE
    }
}

fn imported_file(band: usize) -> Option<(String, String)> {
    if band <= PRELUDE_SPAN_BAND {
        return None;
    }
    let path = IMPORT_BANDS
        .lock()
        .ok()?
        .iter()
        .find(|(k, _)| *k == band)
        .map(|(_, p)| p.clone())?;
    let src = std::fs::read_to_string(&path).ok()?;
    Some((path, src))
}

/// `keepWith$$hoflamcap0` → `keepWith`: the user-facing name of a specialization clone.
fn unclone_names(s: &str) -> String {
    let mut parts = s.split("$$");
    let mut out = parts.next().unwrap_or_default().to_string();
    for p in parts {
        // drop the closure name that followed `$$` (an identifier, possibly mangled with `$`)
        out.push_str(p.trim_start_matches(|c: char| {
            c.is_alphanumeric() || c == '_' || c == '$' || c == '\''
        }));
    }
    out
}

/// Collection of diagnostics from a compilation.
#[derive(Debug, Default)]
pub struct Diagnostics {
    pub items: Vec<Diagnostic>,
}

impl Diagnostics {
    pub fn new() -> Self {
        Diagnostics { items: Vec::new() }
    }

    pub fn push(&mut self, mut d: Diagnostic) {
        // A diagnostic raised inside a higher-order specialization clone (`keepWith$$gt2`) is
        // reported on the user's source: the clone's spans map back to the original ones, and
        // its name to the function it was cloned from. Once mapped, the same error reported for
        // two clones of one function is shown once.
        // (An IMPORTED module's band is kept: `render` shows such a span in that module's file.)
        for l in &mut d.labels {
            l.start = unclone_span(l.start);
            l.end = unclone_span(l.end);
            l.message = unclone_names(&l.message);
        }
        if let Some(fix) = &mut d.fix {
            fix.start = unclone_span(fix.start);
            fix.end = unclone_span(fix.end);
        }
        d.message = unclone_names(&d.message);
        let same = |o: &Diagnostic| {
            o.code == d.code
                && o.message == d.message
                && o.labels.len() == d.labels.len()
                && o.labels
                    .iter()
                    .zip(&d.labels)
                    .all(|(a, b)| (a.start, a.end, &a.message) == (b.start, b.end, &b.message))
        };
        if !self.items.iter().any(same) {
            self.items.push(d);
        }
    }

    pub fn has_errors(&self) -> bool {
        self.items.iter().any(|d| d.severity == Severity::Error)
    }

    pub fn is_empty(&self) -> bool {
        self.items.is_empty()
    }
}
