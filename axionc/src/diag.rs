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
            let (line, col) = lines.pos(lbl.start);
            let (_, end_col) = lines.pos(lbl.end.max(lbl.start));
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

/// Collection of diagnostics from a compilation.
#[derive(Debug, Default)]
pub struct Diagnostics {
    pub items: Vec<Diagnostic>,
}

impl Diagnostics {
    pub fn new() -> Self {
        Diagnostics { items: Vec::new() }
    }

    pub fn push(&mut self, d: Diagnostic) {
        self.items.push(d);
    }

    pub fn has_errors(&self) -> bool {
        self.items.iter().any(|d| d.severity == Severity::Error)
    }

    pub fn is_empty(&self) -> bool {
        self.items.is_empty()
    }
}
