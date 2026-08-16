//! The salsa incremental query engine (§8).
//!
//! This is the walking-skeleton engine: source files are salsa **inputs**, and the
//! front end runs as **tracked queries** so unchanged work is memoized across
//! edits. The graph is split at the natural pipeline boundary:
//!
//! - [`parse`] depends only on a file's text (lex → layout → parse → `{-# LEVEL #-}`
//!   ceiling). Editing an unrelated file — or re-querying the same text (hover, a
//!   no-op change) — reuses the memoized parse.
//! - [`file_diagnostics`] runs the cross-file downstream (imports + prelude + class
//!   lowering + linearity/Auto-Drop + HM inference) on top of `parse`.
//!
//! Both stages call the SAME functions the CLI uses ([`crate::parse_source`],
//! [`crate::analyze_module`]) — no logic is duplicated.
//!
//! Scope of this increment: file-granularity memoization. Per-declaration
//! invalidation and salsa-tracked cross-file imports (today the downstream reads
//! imported files straight from disk, invisible to salsa) are later increments.
#![allow(missing_docs, missing_debug_implementations)]

use salsa::{Accumulator, Setter};
use std::collections::HashMap;
use std::sync::{Arc, Mutex};

use crate::ast;
use crate::check::{self, SigEnv};
use crate::diag::{Diagnostic, Diagnostics};

/// The salsa database. Holds the query storage plus a registry mapping file paths
/// to their `SourceFile` inputs, so a path can be re-set (edited) in place —
/// preserving salsa's revision tracking — rather than re-created each time.
#[salsa::db]
#[derive(Default, Clone)]
pub struct AxionDb {
    storage: salsa::Storage<Self>,
    files: Arc<Mutex<HashMap<String, SourceFile>>>,
}

#[salsa::db]
impl salsa::Database for AxionDb {}

impl AxionDb {
    /// A database that records every salsa event into `sink` (as `Debug` strings).
    /// Used by tests to observe query execution (memoization); not needed in
    /// production, where the default (no-op) event handler is fine.
    pub fn with_event_logger(sink: Arc<Mutex<Vec<String>>>) -> Self {
        let storage = salsa::Storage::new(Some(Box::new(move |event: salsa::Event| {
            if let Ok(mut s) = sink.lock() {
                s.push(format!("{:?}", event.kind));
            }
        })));
        AxionDb {
            storage,
            files: Arc::default(),
        }
    }

    /// Intern (or update) a file's text, returning its `SourceFile` input. If the
    /// path is already known, its text is set on the existing input so salsa only
    /// invalidates when the text actually changed.
    pub fn set_file(&mut self, path: &str, text: String) -> SourceFile {
        let existing = self.files.lock().ok().and_then(|m| m.get(path).copied());
        match existing {
            Some(file) => {
                if file.text(self) != &text {
                    file.set_text(self).to(text);
                }
                file
            }
            None => {
                let file = SourceFile::new(self, path.to_string(), text);
                if let Ok(mut m) = self.files.lock() {
                    m.insert(path.to_string(), file);
                }
                file
            }
        }
    }
}

/// A source file input: its path (for import resolution) and its text.
#[salsa::input]
pub struct SourceFile {
    #[returns(ref)]
    pub path: String,
    #[returns(ref)]
    pub text: String,
}

/// A diagnostic accumulated by the front-end queries.
#[salsa::accumulator]
#[derive(Debug, Clone)]
pub struct Diag(pub Diagnostic);

/// A single top-level declaration, tracked so salsa can memoize its per-decl check
/// independently. Identified by `name`; its `func` field changes only when THAT
/// declaration is edited, so editing another function's body leaves this one's
/// check memoized.
#[salsa::tracked]
pub struct DeclItem<'db> {
    // `name` + `file` are identity fields: the struct keeps its identity across body
    // edits to OTHER declarations. `func` is a tracked field, compared per edit, so
    // only the edited declaration's `check_decl` is invalidated.
    pub name: String,
    pub file: SourceFile,
    #[tracked]
    #[returns(ref)]
    pub func: ast::Func,
}

/// Parse a single file to its `Module` (memoized per text). Parse-time diagnostics
/// (lex/parse errors, level-ceiling violations) are accumulated. `no_eq`: the AST
/// is not compared for backdating here — the downstream `sig_env` is where
/// body-stable backdating happens.
#[salsa::tracked(no_eq)]
pub fn parse(db: &dyn salsa::Database, file: SourceFile) -> Option<ast::Module> {
    let mut diags = Diagnostics::new();
    let module = crate::parse_source(file.text(db), &mut diags);
    for d in diags.items {
        Diag(d).accumulate(db);
    }
    module
}

/// The checker-ready module: parse + imports + prelude + `deriving` + class
/// lowering + consumed-ownership inference. Re-runs on any edit (the body is in it);
/// import/derive diagnostics are accumulated. `no_eq` — its consumers key off the
/// body-independent `sig_env`, not this whole module.
#[salsa::tracked(no_eq)]
pub fn processed_module(db: &dyn salsa::Database, file: SourceFile) -> Option<ast::Module> {
    let parsed = parse(db, file).as_ref()?.clone();
    let mut diags = Diagnostics::new();
    let (module, _exempt) = crate::prepare_for_check(parsed, file.path(db), &mut diags);
    for d in diags.items {
        Diag(d).accumulate(db);
    }
    Some(module)
}

/// The body-independent signature environment (globals + `Ctx`). Because it never
/// inspects a function's body, salsa BACKDATES it across body edits — so the
/// per-decl `check_decl` queries that depend on it are not invalidated when an
/// unrelated function's body changes. (Default eq: `SigEnv: PartialEq`.)
#[salsa::tracked]
pub fn sig_env(db: &dyn salsa::Database, file: SourceFile) -> Option<SigEnv> {
    processed_module(db, file)
        .as_ref()
        .map(check::signature_env)
}

/// One `DeclItem` per top-level function of the checker-ready module.
#[salsa::tracked]
pub fn decl_items(db: &dyn salsa::Database, file: SourceFile) -> Vec<DeclItem<'_>> {
    let Some(module) = processed_module(db, file) else {
        return Vec::new();
    };
    module
        .funcs
        .iter()
        .map(|f| DeclItem::new(db, f.name.clone(), file, f.clone()))
        .collect()
}

/// The per-declaration linearity/Auto-Drop/name check — the incremental unit.
/// Depends only on this declaration's `func` and the (body-stable) `sig_env`.
#[salsa::tracked]
pub fn check_decl<'db>(db: &'db dyn salsa::Database, item: DeclItem<'db>) -> Vec<Diagnostic> {
    match sig_env(db, *item.file(db)) {
        Some(env) => check::check_one_func(item.func(db), env),
        None => Vec::new(),
    }
}

/// The diagnostics that are NOT per-function: HM inference (cross-function) plus the
/// whole-module session/`bound`/instance checks. `no_eq` — re-runs on any edit.
#[salsa::tracked(no_eq)]
pub fn whole_module_diags(db: &dyn salsa::Database, file: SourceFile) -> Vec<Diagnostic> {
    let mut diags = Diagnostics::new();
    if let Some(module) = processed_module(db, file) {
        crate::whole_module_diags(module, &mut diags);
    }
    diags.items
}

/// Run the incremental front end for `file` and collect all diagnostics. This is
/// the entry point the LSP uses; on unchanged text the queries are memoized, and
/// on a body edit only the edited declaration's `check_decl` re-runs (the other
/// declarations' checks are reused via the backdated `sig_env`).
pub fn diagnostics_of(db: &dyn salsa::Database, file: SourceFile) -> Vec<Diagnostic> {
    let mut out = Vec::new();
    // Parse + prepare diagnostics (accumulated across the processed_module subtree,
    // which includes `parse`).
    let _ = processed_module(db, file);
    out.extend(
        processed_module::accumulated::<Diag>(db, file)
            .into_iter()
            .map(|d| d.0.clone()),
    );
    // Per-declaration linearity checks (each memoized independently).
    for item in decl_items(db, file).clone() {
        out.extend(check_decl(db, item).iter().cloned());
    }
    // Whole-module inference + session/bound/instance checks.
    out.extend(whole_module_diags(db, file).iter().cloned());
    out
}
