//! `axion-lsp` — the Language Server (§8), a walking skeleton.
//!
//! It reuses the compiler front end ([`crate::compile_front`]) directly: on every
//! edit it recompiles the whole buffer and republishes diagnostics. No salsa
//! (incrementality) and no rowan (resilient CST) yet — those are later increments;
//! at this scale a full reparse is sub-perceptible and is the honest baseline they
//! will be measured against.
//!
//! What it offers today, all from infra that already exists:
//! - **diagnostics** — every `AXnnnn` [`crate::diag::Diagnostic`] as an LSP
//!   diagnostic (code + span + message);
//! - **hover** — the long-form [`crate::explain_text`] for the code under the
//!   cursor (the same text as `axionc --explain`);
//! - **quick fixes** — the machine-applicable [`crate::diag::Fix`] (e.g. the
//!   AX0101 "did you mean" rename) as a one-click code action.

use std::collections::HashMap;

use tokio::sync::Mutex;
use tower_lsp::jsonrpc::Result as RpcResult;
use tower_lsp::lsp_types::{
    CodeAction, CodeActionKind, CodeActionOrCommand, CodeActionParams, CodeActionProviderCapability,
    CodeActionResponse, Diagnostic, DiagnosticSeverity, DidChangeTextDocumentParams,
    DidOpenTextDocumentParams, DidSaveTextDocumentParams, Hover, HoverContents, HoverParams,
    HoverProviderCapability, InitializeParams, InitializeResult, MarkupContent, MarkupKind,
    MessageType, NumberOrString, Position, Range, ServerCapabilities, TextDocumentSyncCapability,
    TextDocumentSyncKind, TextEdit, Url, WorkspaceEdit,
};
use tower_lsp::{Client, LanguageServer, LspService, Server};

use crate::diag::{Diagnostics, Severity};
use crate::lexer::LineMap;

/// One analyzed diagnostic: the LSP diagnostic plus the optional edit that fixes
/// it (kept so `code_action` can turn it into a `WorkspaceEdit`).
#[derive(Debug, Clone)]
pub struct Analyzed {
    /// The LSP diagnostic to publish.
    pub diagnostic: Diagnostic,
    /// A machine-applicable fix, if the compiler suggested one.
    pub fix: Option<FixEdit>,
}

/// A machine-applicable edit: replace `range` with `new_text`.
#[derive(Debug, Clone)]
pub struct FixEdit {
    /// The range to replace.
    pub range: Range,
    /// The replacement text.
    pub new_text: String,
}

/// Byte offset → 0-based LSP position. `LineMap::pos` is 1-based `(line, col)`.
/// NOTE: LSP counts characters in UTF-16 code units; this uses the column as-is,
/// which is correct for ASCII source (Axion's today). A UTF-16 remap is a
/// documented follow-up.
fn to_position(lines: &LineMap, offset: usize) -> Position {
    let (line, col) = lines.pos(offset);
    Position {
        line: (line.saturating_sub(1)) as u32,
        character: (col.saturating_sub(1)) as u32,
    }
}

fn to_range(lines: &LineMap, start: usize, end: usize) -> Range {
    Range {
        start: to_position(lines, start),
        end: to_position(lines, end.max(start)),
    }
}

/// The pure core, testable without any async runtime: compile `src` (from `path`,
/// so imports resolve) and return the diagnostics as LSP data. The front end is
/// wrapped in `catch_unwind` so a compiler panic degrades to "no diagnostics"
/// rather than taking the server down.
pub fn analyze(path: &str, src: &str) -> Vec<Analyzed> {
    let lines = LineMap::new(src);
    let items = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        let mut diags = Diagnostics::new();
        let _ = crate::compile_front(src, path, &mut diags);
        diags.items
    }))
    .unwrap_or_default();

    items
        .iter()
        .map(|d| {
            let range = d
                .labels
                .first()
                .map_or_else(Range::default, |l| to_range(&lines, l.start, l.end));
            let severity = match d.severity {
                Severity::Error => DiagnosticSeverity::ERROR,
                Severity::Warning => DiagnosticSeverity::WARNING,
            };
            let message = match &d.help {
                Some(h) => format!("{}\n\nhelp: {h}", d.message),
                None => d.message.clone(),
            };
            let diagnostic = Diagnostic {
                range,
                severity: Some(severity),
                code: Some(NumberOrString::String(d.code.clone())),
                source: Some("axion".to_string()),
                message,
                ..Diagnostic::default()
            };
            let fix = d.fix.as_ref().map(|f| FixEdit {
                range: to_range(&lines, f.start, f.end),
                new_text: f.replacement.clone(),
            });
            Analyzed { diagnostic, fix }
        })
        .collect()
}

/// Per-document state: the current text and its last analysis.
#[derive(Debug, Default)]
struct Doc {
    text: String,
    analyzed: Vec<Analyzed>,
}

struct Backend {
    client: Client,
    docs: Mutex<HashMap<Url, Doc>>,
}

impl Backend {
    fn new(client: Client) -> Self {
        Backend {
            client,
            docs: Mutex::new(HashMap::new()),
        }
    }

    /// Recompile `uri`'s buffer, cache the analysis, and publish the diagnostics.
    async fn refresh(&self, uri: Url, text: String) {
        let path = uri.to_file_path().map_or_else(|()| uri.to_string(), |p| p.display().to_string());
        let analyzed = analyze(&path, &text);
        let diags: Vec<Diagnostic> = analyzed.iter().map(|a| a.diagnostic.clone()).collect();
        self.docs
            .lock()
            .await
            .insert(uri.clone(), Doc { text, analyzed });
        self.client.publish_diagnostics(uri, diags, None).await;
    }
}

fn range_contains(range: &Range, pos: Position) -> bool {
    (range.start <= pos) && (pos <= range.end)
}

#[tower_lsp::async_trait]
impl LanguageServer for Backend {
    async fn initialize(&self, _: InitializeParams) -> RpcResult<InitializeResult> {
        Ok(InitializeResult {
            capabilities: ServerCapabilities {
                text_document_sync: Some(TextDocumentSyncCapability::Kind(
                    TextDocumentSyncKind::FULL,
                )),
                hover_provider: Some(HoverProviderCapability::Simple(true)),
                code_action_provider: Some(CodeActionProviderCapability::Simple(true)),
                ..ServerCapabilities::default()
            },
            ..InitializeResult::default()
        })
    }

    async fn initialized(&self, _: tower_lsp::lsp_types::InitializedParams) {
        self.client
            .log_message(MessageType::INFO, "axion-lsp ready")
            .await;
    }

    async fn shutdown(&self) -> RpcResult<()> {
        Ok(())
    }

    async fn did_open(&self, params: DidOpenTextDocumentParams) {
        let doc = params.text_document;
        self.refresh(doc.uri, doc.text).await;
    }

    async fn did_change(&self, params: DidChangeTextDocumentParams) {
        // FULL sync: the last content change carries the whole document.
        if let Some(change) = params.content_changes.into_iter().last() {
            self.refresh(params.text_document.uri, change.text).await;
        }
    }

    async fn did_save(&self, params: DidSaveTextDocumentParams) {
        // Re-analyze from the cached buffer (or the saved text, if provided).
        let uri = params.text_document.uri;
        let text = match params.text {
            Some(t) => t,
            None => match self.docs.lock().await.get(&uri) {
                Some(d) => d.text.clone(),
                None => return,
            },
        };
        self.refresh(uri, text).await;
    }

    async fn hover(&self, params: HoverParams) -> RpcResult<Option<Hover>> {
        let pos = params.text_document_position_params.position;
        let uri = params.text_document_position_params.text_document.uri;
        let docs = self.docs.lock().await;
        let Some(doc) = docs.get(&uri) else {
            return Ok(None);
        };
        for a in &doc.analyzed {
            if !range_contains(&a.diagnostic.range, pos) {
                continue;
            }
            let Some(NumberOrString::String(code)) = &a.diagnostic.code else {
                continue;
            };
            if let Some(text) = crate::explain_text(code) {
                return Ok(Some(Hover {
                    contents: HoverContents::Markup(MarkupContent {
                        kind: MarkupKind::Markdown,
                        value: format!("**{code}**\n\n{text}"),
                    }),
                    range: Some(a.diagnostic.range),
                }));
            }
        }
        Ok(None)
    }

    async fn code_action(&self, params: CodeActionParams) -> RpcResult<Option<CodeActionResponse>> {
        let uri = params.text_document.uri;
        let docs = self.docs.lock().await;
        let Some(doc) = docs.get(&uri) else {
            return Ok(None);
        };
        let mut actions: CodeActionResponse = Vec::new();
        for a in &doc.analyzed {
            let Some(fix) = &a.fix else { continue };
            // Offer the fix when its diagnostic overlaps the requested range.
            if a.diagnostic.range.end < params.range.start
                || params.range.end < a.diagnostic.range.start
            {
                continue;
            }
            let mut changes = HashMap::new();
            changes.insert(
                uri.clone(),
                vec![TextEdit {
                    range: fix.range,
                    new_text: fix.new_text.clone(),
                }],
            );
            let title = match &a.diagnostic.code {
                Some(NumberOrString::String(c)) => format!("{c}: apply suggested fix"),
                _ => "apply suggested fix".to_string(),
            };
            actions.push(CodeActionOrCommand::CodeAction(CodeAction {
                title,
                kind: Some(CodeActionKind::QUICKFIX),
                diagnostics: Some(vec![a.diagnostic.clone()]),
                edit: Some(WorkspaceEdit {
                    changes: Some(changes),
                    ..WorkspaceEdit::default()
                }),
                ..CodeAction::default()
            }));
        }
        if actions.is_empty() {
            Ok(None)
        } else {
            Ok(Some(actions))
        }
    }
}

/// Serve the language server over stdin/stdout (the standard LSP transport).
pub async fn run() {
    let stdin = tokio::io::stdin();
    let stdout = tokio::io::stdout();
    let (service, socket) = LspService::new(Backend::new);
    Server::new(stdin, stdout, socket).serve(service).await;
}
