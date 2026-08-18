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
    CodeActionResponse, CompletionItem, CompletionItemKind, CompletionOptions, CompletionParams,
    CompletionResponse, Diagnostic, DiagnosticSeverity, DidChangeTextDocumentParams,
    DidOpenTextDocumentParams, DidSaveTextDocumentParams, DocumentSymbol, DocumentSymbolParams,
    DocumentSymbolResponse, FoldingRange, FoldingRangeKind, FoldingRangeParams,
    GotoDefinitionParams, GotoDefinitionResponse, Hover, HoverContents, HoverParams,
    HoverProviderCapability, InitializeParams, InitializeResult, InlayHint, InlayHintKind,
    InlayHintLabel, InlayHintParams, InlayHintTooltip, Location, MarkupContent,
    MarkupKind, MessageType, NumberOrString, OneOf, Position, Range, ReferenceParams,
    RenameParams, SelectionRange, SelectionRangeParams, ServerCapabilities, SymbolKind,
    TextDocumentSyncCapability, TextDocumentSyncKind, TextEdit, Url, WorkspaceEdit,
};
use tower_lsp::{Client, LanguageServer, LspService, Server};

use crate::cst::{self, SyntaxKind, SyntaxNode};
use crate::db::{self, AxionDb};
use crate::diag::{Diagnostic as AxDiagnostic, Severity};
use crate::lexer::LineMap;

/// Byte offset → LSP position (0-based) via the line table.
fn offset_to_position(lines: &LineMap, offset: usize) -> Position {
    let (line, col) = lines.pos(offset);
    Position {
        line: (line.saturating_sub(1)) as u32,
        character: (col.saturating_sub(1)) as u32,
    }
}

/// A rowan `TextRange` (byte offsets) → an LSP `Range`.
fn text_range_to_range(lines: &LineMap, r: rowan::TextRange) -> Range {
    Range {
        start: offset_to_position(lines, usize::from(r.start())),
        end: offset_to_position(lines, usize::from(r.end())),
    }
}

fn is_trivia(k: SyntaxKind) -> bool {
    matches!(k, SyntaxKind::WHITESPACE | SyntaxKind::COMMENT)
}

/// The content span of a node: from its first to its last non-trivia token, so
/// folding/symbol ranges don't include trailing blank lines.
fn content_range(node: &SyntaxNode) -> Option<rowan::TextRange> {
    let mut toks = node
        .descendants_with_tokens()
        .filter_map(|e| e.into_token())
        .filter(|t| !is_trivia(t.kind()));
    let first = toks.next()?;
    let last = toks.last().unwrap_or_else(|| first.clone());
    Some(rowan::TextRange::new(
        first.text_range().start(),
        last.text_range().end(),
    ))
}

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

/// Map one compiler diagnostic to LSP data (diagnostic + optional fix edit),
/// resolving byte spans against `lines`.
fn to_analyzed(d: &AxDiagnostic, lines: &LineMap) -> Analyzed {
    let range = d
        .labels
        .first()
        .map_or_else(Range::default, |l| to_range(lines, l.start, l.end));
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
        range: to_range(lines, f.start, f.end),
        new_text: f.replacement.clone(),
    });
    Analyzed { diagnostic, fix }
}

/// Run the incremental front end for `file` on `db` and map the diagnostics to LSP
/// data. Wrapped in `catch_unwind` so a compiler panic degrades to "no diagnostics"
/// rather than taking the server down.
fn analyze_on(db: &AxionDb, file: db::SourceFile, src: &str) -> Vec<Analyzed> {
    let lines = LineMap::new(src);
    let items = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        db::diagnostics_of(db, file)
    }))
    .unwrap_or_default();
    items.iter().map(|d| to_analyzed(d, &lines)).collect()
}

/// The pure core, testable without any async runtime: compile `src` (from `path`,
/// so imports resolve) through a throwaway salsa database and return the
/// diagnostics as LSP data.
pub fn analyze(path: &str, src: &str) -> Vec<Analyzed> {
    let mut db = AxionDb::default();
    let file = db.set_file(path, src.to_string());
    db.load_imports(path); // pull the import closure into the DB before querying
    analyze_on(&db, file, src)
}

/// One inlay hint's worth of Auto-Drop / ownership information, as pure data
/// (mapped to an LSP `InlayHint` by the handler). The `range` is the source span the
/// hint annotates; `label` is the inline text; `tooltip` is the on-hover explanation.
#[derive(Debug, Clone, PartialEq)]
pub struct OwnershipHint {
    /// The source span the hint annotates (the resource's death point / reuse site).
    pub range: Range,
    /// The inline text shown in the editor, e.g. `⌫ drop xs: List`.
    pub label: String,
    /// The on-hover explanation (why the drop / reuse happens here).
    pub tooltip: String,
}

/// The Auto-Drop / in-place-reuse topology of `src` (compiled from `path` so imports
/// resolve), as inline hints — §8's promise to "draw the graph inline". Surfaces the
/// ownership information the compiler already computes: where each linear resource's
/// `free` is inserted and why (dies at entry / after its last read), and where a record
/// update reuses its base in place. Compiler panics degrade to no hints (never crash the
/// server). A pure function, unit-tested without any async runtime.
pub fn ownership_hints(path: &str, src: &str) -> Vec<OwnershipHint> {
    // The full analysis covers the prelude too, but the prelude is parsed in its OWN
    // coordinate space (see `inject_prelude`), so its spans collide numerically with
    // `src`. Keep only hints for functions the user actually wrote (`user_funcs`,
    // gathered from `src` alone, before prelude injection).
    let (analysis, user_funcs) = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        let mut diags = crate::diag::Diagnostics::default();
        let analysis = crate::compile_front(src, path, &mut diags).1;
        let mut names = std::collections::HashSet::new();
        if let Some(m) = crate::parse_source(src, &mut crate::diag::Diagnostics::default()) {
            names.extend(m.funcs.iter().map(|f| f.name.clone()));
        }
        (analysis, names)
    }))
    .unwrap_or_default();
    let lines = LineMap::new(src);
    let in_src = |s: crate::ast::Span| s != crate::core::NO_SPAN && s.1 <= src.len();
    let span_range = |s: crate::ast::Span| Range {
        start: offset_to_position(&lines, s.0),
        end: offset_to_position(&lines, s.1),
    };

    let mut hints = Vec::new();
    for d in &analysis.drops {
        if !user_funcs.contains(&d.func) || !in_src(d.span) {
            continue; // prelude-owned or compiler-generated: not in this buffer
        }
        hints.push(OwnershipHint {
            range: span_range(d.span),
            label: format!("⌫ drop {}: {}", d.var, d.ty),
            tooltip: format!("Auto-Drop — `{}` (`{}`) {}.", d.var, d.ty, d.reason),
        });
    }
    for ip in &analysis.inplace {
        if !user_funcs.contains(&ip.func) || !in_src(ip.span) {
            continue;
        }
        hints.push(OwnershipHint {
            range: span_range(ip.span),
            label: format!("↻ reuse {}", ip.var),
            tooltip: format!(
                "In-place update — `{}` is linear and this is its last live mention, so the \
                 record is mutated in place (no copy).",
                ip.var
            ),
        });
    }
    for a in &analysis.arenas {
        if !user_funcs.contains(&a.func) || !in_src(a.span) {
            continue;
        }
        hints.push(OwnershipHint {
            range: span_range(a.span),
            label: format!("⤺ reset {}", a.sub),
            tooltip: format!(
                "Arena reset — sub-arena `{}` is reset at the last live mention of `{}` \
                 (NLL, not lexical end).",
                a.sub, a.last_var
            ),
        });
    }
    hints
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
    /// The persistent salsa database: keeping it across edits is what makes the
    /// engine incremental — an edit re-sets one file's text input, and salsa
    /// recomputes only what depends on it (the prelude and unchanged files stay
    /// memoized).
    db: Mutex<AxionDb>,
}

impl Backend {
    fn new(client: Client) -> Self {
        Backend {
            client,
            docs: Mutex::new(HashMap::new()),
            db: Mutex::new(AxionDb::default()),
        }
    }

    /// Recompile `uri`'s buffer (incrementally, via the persistent salsa DB),
    /// cache the analysis, and publish the diagnostics.
    async fn refresh(&self, uri: Url, text: String) {
        let path = uri
            .to_file_path()
            .map_or_else(|()| uri.to_string(), |p| p.display().to_string());
        let analyzed = {
            let mut db = self.db.lock().await;
            let file = db.set_file(&path, text.clone());
            db.load_imports(&path); // ensure imported files are loaded for resolution
            analyze_on(&db, file, &text)
        };
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
                // CST-powered structural features (§8).
                document_symbol_provider: Some(OneOf::Left(true)),
                folding_range_provider: Some(tower_lsp::lsp_types::FoldingRangeProviderCapability::Simple(true)),
                selection_range_provider: Some(tower_lsp::lsp_types::SelectionRangeProviderCapability::Simple(true)),
                definition_provider: Some(OneOf::Left(true)),
                completion_provider: Some(CompletionOptions::default()),
                references_provider: Some(OneOf::Left(true)),
                rename_provider: Some(OneOf::Left(true)),
                // §8's "draw the graph inline": the Auto-Drop / ownership topology.
                inlay_hint_provider: Some(OneOf::Left(true)),
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

    /// Document outline from the CST: one symbol per top-level declaration.
    async fn document_symbol(
        &self,
        params: DocumentSymbolParams,
    ) -> RpcResult<Option<DocumentSymbolResponse>> {
        let docs = self.docs.lock().await;
        let Some(doc) = docs.get(&params.text_document.uri) else {
            return Ok(None);
        };
        Ok(Some(DocumentSymbolResponse::Nested(outline(&doc.text))))
    }

    /// Folding ranges from the CST: each multi-line top-level declaration folds.
    async fn folding_range(
        &self,
        params: FoldingRangeParams,
    ) -> RpcResult<Option<Vec<FoldingRange>>> {
        let docs = self.docs.lock().await;
        let Some(doc) = docs.get(&params.text_document.uri) else {
            return Ok(None);
        };
        Ok(Some(folds(&doc.text)))
    }

    /// Selection ranges from the CST: for each cursor, the token and its enclosing
    /// nodes form the "expand selection" chain.
    async fn selection_range(
        &self,
        params: SelectionRangeParams,
    ) -> RpcResult<Option<Vec<SelectionRange>>> {
        let docs = self.docs.lock().await;
        let Some(doc) = docs.get(&params.text_document.uri) else {
            return Ok(None);
        };
        let lines = LineMap::new(&doc.text);
        let cst = cst::build_cst(&doc.text);
        let ranges = params
            .positions
            .into_iter()
            .map(|p| selection_at(&cst, &lines, lines.offset(p.line, p.character)))
            .collect();
        Ok(Some(ranges))
    }

    /// Go to definition: resolve the identifier under the cursor to the top-level
    /// declaration that introduces it (same file), from the CST.
    async fn goto_definition(
        &self,
        params: GotoDefinitionParams,
    ) -> RpcResult<Option<GotoDefinitionResponse>> {
        let pos = params.text_document_position_params;
        let uri = pos.text_document.uri;
        let docs = self.docs.lock().await;
        let Some(doc) = docs.get(&uri) else {
            return Ok(None);
        };
        let lines = LineMap::new(&doc.text);
        let offset = lines.offset(pos.position.line, pos.position.character);
        let path = uri_to_path(&uri);
        let ws = build_workspace(&path, &doc.text, &docs);
        let Some((def_path, range)) = definition_at(&path, &doc.text, offset, &ws) else {
            return Ok(None);
        };
        let def_uri = if def_path == path {
            uri
        } else {
            Url::from_file_path(&def_path).unwrap_or(uri)
        };
        Ok(Some(GotoDefinitionResponse::Scalar(Location {
            uri: def_uri,
            range,
        })))
    }

    /// Completion: names in scope at the cursor (locals, then top-level declarations
    /// and builtins) plus keywords. The client filters by the typed prefix.
    async fn completion(
        &self,
        params: CompletionParams,
    ) -> RpcResult<Option<CompletionResponse>> {
        let pos = params.text_document_position;
        let docs = self.docs.lock().await;
        let Some(doc) = docs.get(&pos.text_document.uri) else {
            return Ok(None);
        };
        let offset = LineMap::new(&doc.text).offset(pos.position.line, pos.position.character);
        Ok(Some(CompletionResponse::Array(completions(&doc.text, offset))))
    }

    /// Find references: every occurrence that resolves to the same definition as the one
    /// under the cursor — scope-aware and cross-file (a top-level name gathers uses from
    /// every open/imported file in the workspace).
    async fn references(&self, params: ReferenceParams) -> RpcResult<Option<Vec<Location>>> {
        let pos = params.text_document_position;
        let uri = pos.text_document.uri;
        let docs = self.docs.lock().await;
        let Some(doc) = docs.get(&uri) else {
            return Ok(None);
        };
        let offset = LineMap::new(&doc.text).offset(pos.position.line, pos.position.character);
        let path = uri_to_path(&uri);
        let ws = build_workspace(&path, &doc.text, &docs);
        let refs = references_at(&path, &doc.text, offset, &ws, params.context.include_declaration);
        Ok(Some(
            refs.into_iter()
                .filter_map(|(p, range)| {
                    let file_uri = if p == path {
                        uri.clone()
                    } else {
                        Url::from_file_path(&p).ok()?
                    };
                    Some(Location { uri: file_uri, range })
                })
                .collect(),
        ))
    }

    /// Rename: replace every reference (including the declaration) with `new_name`,
    /// across every file in the workspace (a single multi-file `WorkspaceEdit`).
    async fn rename(&self, params: RenameParams) -> RpcResult<Option<WorkspaceEdit>> {
        let pos = params.text_document_position;
        let uri = pos.text_document.uri;
        let docs = self.docs.lock().await;
        let Some(doc) = docs.get(&uri) else {
            return Ok(None);
        };
        let offset = LineMap::new(&doc.text).offset(pos.position.line, pos.position.character);
        let path = uri_to_path(&uri);
        let ws = build_workspace(&path, &doc.text, &docs);
        let refs = references_at(&path, &doc.text, offset, &ws, true);
        if refs.is_empty() {
            return Ok(None);
        }
        let mut changes: HashMap<Url, Vec<TextEdit>> = HashMap::new();
        for (p, range) in refs {
            let file_uri = if p == path {
                uri.clone()
            } else {
                match Url::from_file_path(&p) {
                    Ok(u) => u,
                    Err(()) => continue,
                }
            };
            changes.entry(file_uri).or_default().push(TextEdit {
                range,
                new_text: params.new_name.clone(),
            });
        }
        if changes.is_empty() {
            return Ok(None);
        }
        Ok(Some(WorkspaceEdit {
            changes: Some(changes),
            ..WorkspaceEdit::default()
        }))
    }

    /// Inlay hints: the Auto-Drop / ownership topology drawn inline (§8). Every
    /// linear resource's inserted `free` (where and why it dies) and every in-place
    /// record reuse, shown at its source span — filtered to the client's visible range.
    async fn inlay_hint(&self, params: InlayHintParams) -> RpcResult<Option<Vec<InlayHint>>> {
        let uri = params.text_document.uri;
        let docs = self.docs.lock().await;
        let Some(doc) = docs.get(&uri) else {
            return Ok(None);
        };
        let path = uri_to_path(&uri);
        let hints = ownership_hints(&path, &doc.text)
            .into_iter()
            .filter(|h| h.range.start >= params.range.start && h.range.start <= params.range.end)
            .map(|h| InlayHint {
                position: h.range.start,
                label: InlayHintLabel::String(h.label),
                kind: Some(InlayHintKind::TYPE),
                text_edits: None,
                tooltip: Some(InlayHintTooltip::String(h.tooltip)),
                padding_left: Some(true),
                padding_right: Some(false),
                data: None,
            })
            .collect();
        Ok(Some(hints))
    }
}

/// A filesystem path for `uri` (so imports resolve); falls back to the URL path.
fn uri_to_path(uri: &Url) -> String {
    uri.to_file_path()
        .ok()
        .and_then(|p| p.to_str().map(String::from))
        .unwrap_or_else(|| uri.path().to_string())
}

/// The workspace to resolve cross-file features against: every open buffer, plus the
/// on-disk import closure of the active file (`path`/`src`). Open buffers win over disk
/// (an edited-but-unsaved file is resolved from its buffer). This finds definitions in
/// files the active file imports, and references in any *open* file — the reverse import
/// graph of unopened files is out of scope (they'd need a workspace-wide scan).
fn build_workspace(path: &str, src: &str, open: &HashMap<Url, Doc>) -> Workspace {
    let mut ws: Workspace = open
        .iter()
        .filter_map(|(u, d)| {
            u.to_file_path()
                .ok()
                .and_then(|p| p.to_str().map(|s| (s.to_string(), d.text.clone())))
        })
        .collect();
    ws.entry(path.to_string()).or_insert_with(|| src.to_string());

    // Walk the active file's import closure, reading disk for anything not already open.
    let mut stack = vec![path.to_string()];
    let mut visited = std::collections::HashSet::new();
    while let Some(p) = stack.pop() {
        if !visited.insert(p.clone()) {
            continue;
        }
        let text = match ws.get(&p) {
            Some(t) => t.clone(),
            None => match std::fs::read_to_string(&p) {
                Ok(t) => {
                    ws.insert(p.clone(), t.clone());
                    t
                }
                Err(_) => continue,
            },
        };
        let dir = dir_of(&p);
        for import in crate::module_imports(&text) {
            if let Some(s) = crate::import_target_path(&dir, &import).to_str() {
                stack.push(s.to_string());
            }
        }
    }
    ws
}

/// All references (as LSP ranges) to the binding under the cursor at `offset`, within a
/// single file. A thin wrapper over [`references_at`] with an empty workspace.
pub fn references_of(src: &str, offset: usize, include_declaration: bool) -> Vec<Range> {
    references_at("", src, offset, &Workspace::new(), include_declaration)
        .into_iter()
        .map(|(_, r)| r)
        .collect()
}

/// A workspace: the text of every file the server can resolve across, keyed by path
/// (open buffers plus the on-disk import closure of the active file).
pub type Workspace = HashMap<String, String>;

/// A resolved definition, possibly in another file. `local` marks a binder inside a
/// function (parameter, `let`/`where`, …) — references to it never cross files.
#[derive(Debug, Clone, PartialEq)]
struct DefSite {
    path: String,
    span: (usize, usize),
    local: bool,
}

/// The directory an import in `path` resolves against.
fn dir_of(path: &str) -> std::path::PathBuf {
    std::path::Path::new(path)
        .parent()
        .map_or_else(|| std::path::PathBuf::from("."), std::path::Path::to_path_buf)
}

/// The definition the identifier `name` (used at `offset` in `path`/`src`) resolves to,
/// searching, in order: a local binder in the enclosing function, a top-level
/// declaration in this file, then a top-level declaration in each imported file present
/// in `ws`. `cst`/`module` are `src`'s already-built tree and AST (`module` is `None`
/// when `src` doesn't parse — then only the top-level/imported paths apply).
fn def_site(
    path: &str,
    src: &str,
    cst: &SyntaxNode,
    module: Option<&crate::ast::Module>,
    name: &str,
    offset: usize,
    ws: &Workspace,
) -> Option<DefSite> {
    if let Some(m) = module {
        if let Some(sp) = resolve_local(m, name, offset) {
            return Some(DefSite { path: path.to_string(), span: sp, local: true });
        }
    }
    if let Some(r) = cst::definition_site(cst, name) {
        return Some(DefSite {
            path: path.to_string(),
            span: (usize::from(r.start()), usize::from(r.end())),
            local: false,
        });
    }
    // Not defined here: try each imported file's top-level declarations.
    let dir = dir_of(path);
    for import in crate::module_imports(src) {
        let target = crate::import_target_path(&dir, &import);
        let Some(tpath) = target.to_str() else { continue };
        let Some(text) = ws.get(tpath) else { continue };
        let tcst = cst::build_cst(text);
        if let Some(r) = cst::definition_site(&tcst, name) {
            return Some(DefSite {
                path: tpath.to_string(),
                span: (usize::from(r.start()), usize::from(r.end())),
                local: false,
            });
        }
    }
    None
}

/// Cross-file go-to-definition: the `(file, range)` the identifier at `offset` in
/// `path`/`src` defines to — the definition may live in an imported file present in
/// `ws`. Falls back to the current file when there is no workspace / no import hit.
pub fn definition_at(path: &str, src: &str, offset: usize, ws: &Workspace) -> Option<(String, Range)> {
    let cst = cst::build_cst(src);
    let name = cst::name_at(&cst, offset)?;
    let module = parse_ast(src);
    let def = def_site(path, src, &cst, module.as_ref(), &name, offset, ws)?;
    let text: &str = if def.path == path {
        src
    } else {
        ws.get(&def.path)?
    };
    let lines = LineMap::new(text);
    let range = Range {
        start: offset_to_position(&lines, def.span.0),
        end: offset_to_position(&lines, def.span.1),
    };
    Some((def.path, range))
}

/// Cross-file find-references: every occurrence, across the current file and every file
/// in `ws`, that resolves to the same definition as the identifier under the cursor.
/// A local binder stays within its own file; a top-level name gathers uses from every
/// workspace file that resolves to it (imports included), so shadowing is respected
/// across files. Each result is `(file, range)`.
pub fn references_at(
    path: &str,
    src: &str,
    offset: usize,
    ws: &Workspace,
    include_declaration: bool,
) -> Vec<(String, Range)> {
    let cst = cst::build_cst(src);
    let Some(name) = cst::name_at(&cst, offset) else {
        return Vec::new();
    };
    let module = parse_ast(src);
    let Some(target) = def_site(path, src, &cst, module.as_ref(), &name, offset, ws) else {
        return Vec::new();
    };

    // The files to scan: the active file plus every workspace file. A local binder is
    // confined to its own file (no other file can name it).
    let mut files: Vec<(String, String)> = vec![(path.to_string(), src.to_string())];
    if !target.local {
        for (p, t) in ws {
            if p != path {
                files.push((p.clone(), t.clone()));
            }
        }
    }

    let mut out = Vec::new();
    for (fpath, ftext) in &files {
        let fcst = cst::build_cst(ftext);
        let fmodule = parse_ast(ftext);
        let lines = LineMap::new(ftext);
        for r in cst::name_occurrences(&fcst, &name) {
            let span = (usize::from(r.start()), usize::from(r.end()));
            if def_site(fpath, ftext, &fcst, fmodule.as_ref(), &name, span.0, ws).as_ref()
                != Some(&target)
            {
                continue;
            }
            if !include_declaration && *fpath == target.path && span == target.span {
                continue;
            }
            out.push((fpath.clone(), text_range_to_range(&lines, r)));
        }
    }
    out
}

const KEYWORDS: &[&str] = &[
    "let", "in", "if", "then", "else", "case", "of", "where", "do", "data", "class", "instance",
    "module", "import", "qualified", "as", "deriving", "foreign",
];

fn completion_item(label: impl Into<String>, kind: CompletionItemKind) -> CompletionItem {
    CompletionItem {
        label: label.into(),
        kind: Some(kind),
        ..CompletionItem::default()
    }
}

/// Completion candidates at byte `offset` in `src`: keywords, the module's top-level
/// declarations, the builtins, and the locals in scope — de-duplicated by label
/// (locals and top-level shadow builtins/keywords).
pub fn completions(src: &str, offset: usize) -> Vec<CompletionItem> {
    let mut items: Vec<CompletionItem> = Vec::new();
    let mut seen: std::collections::HashSet<String> = std::collections::HashSet::new();
    let add = |items: &mut Vec<CompletionItem>, seen: &mut std::collections::HashSet<String>, label: String, kind| {
        if seen.insert(label.clone()) {
            items.push(completion_item(label, kind));
        }
    };

    if let Some(module) = parse_ast(src) {
        // Locals first, so they shadow same-named top-level/builtin entries.
        for name in locals_in_scope(&module, offset) {
            add(&mut items, &mut seen, name, CompletionItemKind::VARIABLE);
        }
        for f in &module.funcs {
            add(&mut items, &mut seen, f.name.clone(), CompletionItemKind::FUNCTION);
        }
        for fo in &module.foreigns {
            add(&mut items, &mut seen, fo.name.clone(), CompletionItemKind::FUNCTION);
        }
        for d in &module.datas {
            add(&mut items, &mut seen, d.name.clone(), CompletionItemKind::CLASS);
            for c in &d.cons {
                add(&mut items, &mut seen, c.name.clone(), CompletionItemKind::CONSTRUCTOR);
            }
        }
        for c in &module.classes {
            add(&mut items, &mut seen, c.name.clone(), CompletionItemKind::INTERFACE);
            for (m, _) in &c.methods {
                add(&mut items, &mut seen, m.clone(), CompletionItemKind::METHOD);
            }
        }
    }
    let mut builtins: Vec<String> = crate::check::builtins().into_iter().collect();
    builtins.sort();
    for b in builtins {
        add(&mut items, &mut seen, b, CompletionItemKind::FUNCTION);
    }
    for kw in KEYWORDS {
        add(&mut items, &mut seen, (*kw).to_string(), CompletionItemKind::KEYWORD);
    }
    items
}

/// All local binders in scope at `offset` — the enclosing clause's parameters and
/// `where` names, plus the binders of any `let`/lambda/`case` enclosing the cursor.
fn locals_in_scope(module: &crate::ast::Module, offset: usize) -> Vec<String> {
    let mut out = Vec::new();
    if let Some(c) = module
        .funcs
        .iter()
        .flat_map(|f| &f.clauses)
        .find(|c| span_contains(c.span, offset))
    {
        collect_clause(c, offset, &mut out);
    }
    out
}

fn collect_pat(p: &crate::ast::Pat, out: &mut Vec<String>) {
    use crate::ast::Pat;
    match p {
        Pat::Var(n, _) => out.push(n.clone()),
        Pat::Con(_, ps, _) | Pat::Tuple(ps, _) => ps.iter().for_each(|p| collect_pat(p, out)),
        _ => {}
    }
}

fn collect_clause(c: &crate::ast::Clause, offset: usize, out: &mut Vec<String>) {
    c.pats.iter().for_each(|p| collect_pat(p, out));
    for w in &c.wher {
        out.push(w.name.clone());
        for wc in &w.clauses {
            if span_contains(wc.span, offset) {
                collect_clause(wc, offset, out);
            }
        }
    }
    collect_body(&c.body, offset, out);
}

fn collect_body(b: &crate::ast::Body, offset: usize, out: &mut Vec<String>) {
    use crate::ast::Body;
    match b {
        Body::Plain(e) => collect_expr(e, offset, out),
        Body::Guarded(arms) => {
            for (g, r) in arms {
                for e in [g, r] {
                    if span_contains(e.span(), offset) {
                        collect_expr(e, offset, out);
                    }
                }
            }
        }
    }
}

fn collect_expr(e: &crate::ast::Expr, offset: usize, out: &mut Vec<String>) {
    use crate::ast::Expr;
    match e {
        Expr::Let(funcs, body, _) => {
            funcs.iter().for_each(|f| out.push(f.name.clone()));
            for c in funcs.iter().flat_map(|f| &f.clauses) {
                if span_contains(c.span, offset) {
                    collect_clause(c, offset, out);
                }
            }
            if span_contains(body.span(), offset) {
                collect_expr(body, offset, out);
            }
        }
        Expr::Lam(pats, body, _) => {
            pats.iter().for_each(|p| collect_pat(p, out));
            if span_contains(body.span(), offset) {
                collect_expr(body, offset, out);
            }
        }
        Expr::Case(scrut, arms, _) => {
            if span_contains(scrut.span(), offset) {
                collect_expr(scrut, offset, out);
            }
            for (pat, body) in arms {
                if span_contains(body.span(), offset) {
                    collect_pat(pat, out);
                    collect_expr(body, offset, out);
                }
            }
        }
        _ => {
            for c in child_exprs(e) {
                if span_contains(c.span(), offset) {
                    collect_expr(c, offset, out);
                }
            }
        }
    }
}

/// The definition site (as an LSP range) of the identifier at byte `offset` in
/// `src`. Resolution is scope-aware: a local binder (parameter, `let`/`where`,
/// lambda or `case` pattern) in the enclosing function wins over a top-level name;
/// otherwise the top-level declaration that introduces it (function, `data` type or
/// constructor, `class` name or method, `foreign`) is returned.
pub fn definition(src: &str, offset: usize) -> Option<Range> {
    definition_at("", src, offset, &Workspace::new()).map(|(_, r)| r)
}

/// Parse `src` to a raw `ast::Module` (no prelude/imports) for scope resolution.
fn parse_ast(src: &str) -> Option<crate::ast::Module> {
    let toks = crate::lexer::lex(src).ok()?;
    let lines = LineMap::new(src);
    let ltokens = crate::layout::layout(&toks, &lines);
    Some(crate::parser::parse_module_resilient(&ltokens).0)
}

fn span_contains(sp: crate::ast::Span, off: usize) -> bool {
    sp.0 <= off && off < sp.1
}

/// The span of the pattern variable `name` bound by `p`, if any.
fn pat_binds(p: &crate::ast::Pat, name: &str) -> Option<crate::ast::Span> {
    use crate::ast::Pat;
    match p {
        Pat::Var(n, s) if n == name => Some(*s),
        Pat::Con(_, ps, _) | Pat::Tuple(ps, _) => ps.iter().find_map(|p| pat_binds(p, name)),
        _ => None,
    }
}

/// The nearest local binder of `name` in scope at `offset`, or `None` if it's not a
/// local (so the caller falls back to top-level resolution).
fn resolve_local(module: &crate::ast::Module, name: &str, offset: usize) -> Option<crate::ast::Span> {
    module
        .funcs
        .iter()
        .flat_map(|f| &f.clauses)
        .find(|c| span_contains(c.span, offset))
        .and_then(|c| resolve_clause(c, name, offset))
}

fn resolve_clause(c: &crate::ast::Clause, name: &str, offset: usize) -> Option<crate::ast::Span> {
    // A nested `where` binding whose clause encloses the cursor is the innermost
    // scope; if it doesn't bind `name`, fall through to this clause's own binders.
    for w in &c.wher {
        for wc in &w.clauses {
            if span_contains(wc.span, offset) {
                if let Some(sp) = resolve_clause(wc, name, offset) {
                    return Some(sp);
                }
            }
        }
    }
    if let Some(sp) = resolve_body(&c.body, name, offset) {
        return Some(sp);
    }
    for w in &c.wher {
        if w.name == name {
            return Some(w.span);
        }
    }
    c.pats.iter().find_map(|p| pat_binds(p, name))
}

fn resolve_body(b: &crate::ast::Body, name: &str, offset: usize) -> Option<crate::ast::Span> {
    use crate::ast::Body;
    match b {
        Body::Plain(e) => resolve_expr(e, name, offset),
        Body::Guarded(arms) => arms.iter().find_map(|(g, r)| {
            [g, r]
                .into_iter()
                .find(|e| span_contains(e.span(), offset))
                .and_then(|e| resolve_expr(e, name, offset))
        }),
    }
}

fn resolve_expr(e: &crate::ast::Expr, name: &str, offset: usize) -> Option<crate::ast::Span> {
    use crate::ast::Expr;
    match e {
        Expr::Let(funcs, body, _) => {
            for c in funcs.iter().flat_map(|f| &f.clauses) {
                if span_contains(c.span, offset) {
                    if let Some(sp) = resolve_clause(c, name, offset) {
                        return Some(sp);
                    }
                }
            }
            if span_contains(body.span(), offset) {
                if let Some(sp) = resolve_expr(body, name, offset) {
                    return Some(sp);
                }
            }
            funcs.iter().find(|f| f.name == name).map(|f| f.span)
        }
        Expr::Lam(pats, body, _) => {
            if span_contains(body.span(), offset) {
                if let Some(sp) = resolve_expr(body, name, offset) {
                    return Some(sp);
                }
            }
            pats.iter().find_map(|p| pat_binds(p, name))
        }
        Expr::Case(scrut, arms, _) => {
            if span_contains(scrut.span(), offset) {
                return resolve_expr(scrut, name, offset);
            }
            for (pat, body) in arms {
                if span_contains(body.span(), offset) {
                    if let Some(sp) = resolve_expr(body, name, offset) {
                        return Some(sp);
                    }
                    return pat_binds(pat, name);
                }
            }
            None
        }
        // Non-binders: descend into the sub-expression under the cursor.
        _ => child_exprs(e)
            .into_iter()
            .find(|c| span_contains(c.span(), offset))
            .and_then(|c| resolve_expr(c, name, offset)),
    }
}

fn child_exprs(e: &crate::ast::Expr) -> Vec<&crate::ast::Expr> {
    use crate::ast::Expr;
    match e {
        Expr::App(a, b, _) | Expr::BinOp(_, a, b, _) => vec![a, b],
        Expr::If(a, b, c, _) => vec![a, b, c],
        Expr::Tuple(es, _) => es.iter().collect(),
        Expr::RecordCon(_, fs, _) => fs.iter().map(|(_, e)| e).collect(),
        Expr::RecordUpd(b, fs, _) => {
            let mut v = vec![b.as_ref()];
            v.extend(fs.iter().map(|(_, e)| e));
            v
        }
        _ => Vec::new(),
    }
}

/// Document outline: one symbol per top-level declaration of `src`'s CST.
pub fn outline(src: &str) -> Vec<DocumentSymbol> {
    let lines = LineMap::new(src);
    cst::document_symbols(&cst::build_cst(src))
        .into_iter()
        .map(|(name, r)| {
            let range = text_range_to_range(&lines, r);
            #[allow(deprecated)] // `deprecated` field is required by the struct
            DocumentSymbol {
                name,
                detail: None,
                kind: SymbolKind::FUNCTION,
                tags: None,
                deprecated: None,
                range,
                selection_range: range,
                children: None,
            }
        })
        .collect()
}

/// Folding ranges: each multi-line top-level declaration of `src`'s CST.
pub fn folds(src: &str) -> Vec<FoldingRange> {
    let lines = LineMap::new(src);
    cst::build_cst(src)
        .children()
        .filter_map(|decl| content_range(&decl))
        .filter_map(|r| {
            let start_line = offset_to_position(&lines, usize::from(r.start())).line;
            let end_line = offset_to_position(&lines, usize::from(r.end())).line;
            (end_line > start_line).then_some(FoldingRange {
                start_line,
                start_character: None,
                end_line,
                end_character: None,
                kind: Some(FoldingRangeKind::Region),
                collapsed_text: None,
            })
        })
        .collect()
}

/// The expand-selection chain at a byte `offset` in `src` (builds the CST fresh).
pub fn selection(src: &str, offset: usize) -> SelectionRange {
    let lines = LineMap::new(src);
    selection_at(&cst::build_cst(src), &lines, offset)
}

/// Build the nested "expand selection" range at `offset`: the token there, then each
/// enclosing node, outermost wrapping innermost.
pub fn selection_at(cst: &SyntaxNode, lines: &LineMap, offset: usize) -> SelectionRange {
    let ts = rowan::TextSize::new(u32::try_from(offset).unwrap_or(0));
    let token = cst.token_at_offset(ts).right_biased();
    // innermost → outermost ranges (token, then ancestor nodes), de-duplicating
    // equal ranges so each level strictly grows.
    let mut ranges: Vec<rowan::TextRange> = Vec::new();
    if let Some(tok) = token {
        ranges.push(tok.text_range());
        if let Some(parent) = tok.parent() {
            for node in parent.ancestors() {
                let r = node.text_range();
                if ranges.last() != Some(&r) {
                    ranges.push(r);
                }
            }
        }
    } else {
        ranges.push(cst.text_range());
    }
    // Fold outermost → innermost so each SelectionRange's `parent` is the next-larger.
    let mut parent: Option<Box<SelectionRange>> = None;
    for r in ranges.into_iter().rev() {
        parent = Some(Box::new(SelectionRange {
            range: text_range_to_range(lines, r),
            parent,
        }));
    }
    parent.map_or_else(
        || SelectionRange {
            range: Range::default(),
            parent: None,
        },
        |b| *b,
    )
}

/// Serve the language server over stdin/stdout (the standard LSP transport).
pub async fn run() {
    let stdin = tokio::io::stdin();
    let stdout = tokio::io::stdout();
    let (service, socket) = LspService::new(Backend::new);
    Server::new(stdin, stdout, socket).serve(service).await;
}
