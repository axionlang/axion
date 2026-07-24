//! Diagnósticos estruturados com códigos `AXnnnn` estáveis (§8).
//!
//! Um `Diagnostic` carrega código, severidade, mensagem, spans rotulados e uma
//! ajuda opcional. Renderiza-se em texto (estilo rustc: ficheiro:linha:coluna,
//! linha-fonte e setas) ou em JSON (`--emit json`), como manda a §8. O registo
//! dos códigos vive em `docs/error-codes.md`.

use crate::lexer::LineMap;
use serde::Serialize;

#[derive(Debug, Clone, Copy, PartialEq, Serialize)]
#[serde(rename_all = "lowercase")]
pub enum Severity {
    Error,
    Warning,
}

#[derive(Debug, Clone, Serialize)]
pub struct Label {
    pub start: usize,
    pub end: usize,
    pub message: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct Diagnostic {
    pub code: String, // ex.: "AX0001"
    pub severity: Severity,
    pub message: String,
    pub labels: Vec<Label>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub help: Option<String>,
}

impl Diagnostic {
    pub fn error(code: &str, message: impl Into<String>) -> Self {
        Diagnostic {
            code: code.to_string(),
            severity: Severity::Error,
            message: message.into(),
            labels: Vec::new(),
            help: None,
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

    /// Render em texto, no estilo rustc/§8.
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
            out.push_str(&format!("  = ajuda: {help}\n"));
        }
        out
    }
}

/// Coleção de diagnósticos de uma compilação.
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
