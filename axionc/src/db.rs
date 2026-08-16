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

/// Stage 1 (memoized per text): parse a single file to its `Module`. Parse-time
/// diagnostics (lex/parse errors, level-ceiling violations) are accumulated.
/// `no_eq`: the AST is not `PartialEq`, so skip salsa's output-equality backdating
/// — a text edit that changes the parse should invalidate downstream anyway.
#[salsa::tracked(no_eq)]
pub fn parse(db: &dyn salsa::Database, file: SourceFile) -> Option<ast::Module> {
    let mut diags = Diagnostics::new();
    let module = crate::parse_source(file.text(db), &mut diags);
    for d in diags.items {
        Diag(d).accumulate(db);
    }
    module
}

/// Stage 2: the full front end for a file. Reuses the memoized [`parse`] and runs
/// the cross-file downstream, accumulating every diagnostic. Returns whether the
/// front end produced a module (a coarse success flag; the diagnostics are the
/// payload the LSP consumes).
#[salsa::tracked]
pub fn file_diagnostics(db: &dyn salsa::Database, file: SourceFile) -> bool {
    // Re-accumulate parse diagnostics into THIS query's set (accumulators are
    // per-query), reusing the memoized parse result.
    let Some(module) = parse(db, file) else {
        for d in parse::accumulated::<Diag>(db, file) {
            Diag(d.0.clone()).accumulate(db);
        }
        return false;
    };
    for d in parse::accumulated::<Diag>(db, file) {
        Diag(d.0.clone()).accumulate(db);
    }
    let mut diags = Diagnostics::new();
    // salsa returns the tracked value by reference; the downstream consumes it by
    // value (it rewrites the module in place), so clone out of storage.
    let _ = crate::analyze_module(module.clone(), file.path(db), &mut diags);
    for d in diags.items {
        Diag(d).accumulate(db);
    }
    true
}

/// Run the incremental front end for `file` and collect all diagnostics. This is
/// the entry point the LSP uses; on unchanged text the queries are memoized.
pub fn diagnostics_of(db: &dyn salsa::Database, file: SourceFile) -> Vec<Diagnostic> {
    file_diagnostics(db, file);
    file_diagnostics::accumulated::<Diag>(db, file)
        .into_iter()
        .map(|d| d.0.clone())
        .collect()
}
