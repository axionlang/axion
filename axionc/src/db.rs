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

use crate::ast::{self, Func};
use crate::check::{self, SigEnv};
use crate::diag::{Diagnostic, Diagnostics};
use crate::infer;

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

/// The checker-ready module with function BODIES stripped — the body-independent
/// view that inference setup needs. Being independent of bodies, it is
/// `PartialEq`-equal across body edits, so salsa BACKDATES it and the per-decl
/// `infer_decl` queries that depend on it are not invalidated when an unrelated
/// function's body changes.
#[salsa::tracked]
pub fn sig_view(db: &dyn salsa::Database, file: SourceFile) -> Option<ast::Module> {
    let module = processed_module(db, file).as_ref()?;
    Some(strip_bodies_and_spans(module))
}

const NO_SPAN: ast::Span = (0, 0);

/// A module reduced to what inference SETUP reads: function bodies removed and all
/// spans zeroed. Zeroing spans is essential — editing one body shifts the byte
/// offsets of every later declaration, and without normalization the view would
/// differ on every edit and salsa could not backdate it. Setup never uses these
/// spans (the real diagnostics come from the real function passed to `infer_partial`).
fn strip_bodies_and_spans(m: &ast::Module) -> ast::Module {
    let sig_func = |f: &Func| Func {
        name: f.name.clone(),
        sig: f.sig.clone(),
        clauses: Vec::new(),
        span: NO_SPAN,
        constraints: f.constraints.clone(),
    };
    ast::Module {
        name: m.name.clone(),
        imports: Vec::new(),
        funcs: m.funcs.iter().map(sig_func).collect(),
        datas: m
            .datas
            .iter()
            .map(|d| ast::DataDecl {
                span: NO_SPAN,
                ..d.clone()
            })
            .collect(),
        foreigns: m
            .foreigns
            .iter()
            .map(|fo| ast::Foreign {
                span: NO_SPAN,
                ..fo.clone()
            })
            .collect(),
        classes: m
            .classes
            .iter()
            .map(|c| ast::ClassDecl {
                span: NO_SPAN,
                ..c.clone()
            })
            .collect(),
        instances: m
            .instances
            .iter()
            .map(|i| ast::InstanceDecl {
                methods: i.methods.iter().map(sig_func).collect(),
                span: NO_SPAN,
                ..i.clone()
            })
            .collect(),
        level_ceiling: m.level_ceiling,
    }
}

/// The per-declaration HM inference for an ISOLATED function (annotated + no
/// unannotated callees): its diagnostics reproduce the whole-module result exactly,
/// and depend only on its own `func` and the body-stable `sig_view` — so editing an
/// unrelated body does not re-run it. Non-isolated functions return nothing here;
/// they are covered by [`infer_residual`].
#[salsa::tracked]
pub fn infer_decl<'db>(db: &'db dyn salsa::Database, item: DeclItem<'db>) -> Vec<Diagnostic> {
    let Some(view) = sig_view(db, *item.file(db)) else {
        return Vec::new();
    };
    let unannotated = infer::unannotated_funcs(view);
    if infer::is_isolated(item.func(db), &unannotated) {
        let mut diags = Diagnostics::new();
        infer::infer_partial(view, &[item.func(db)], &mut diags);
        diags.items
    } else {
        Vec::new()
    }
}

/// HM inference for the NON-isolated functions (unannotated, or referencing an
/// unannotated function): they share one monomorphic substitution, so they are
/// inferred together. `no_eq` — re-runs on any edit.
#[salsa::tracked(no_eq)]
pub fn infer_residual(db: &dyn salsa::Database, file: SourceFile) -> Vec<Diagnostic> {
    let Some(module) = processed_module(db, file) else {
        return Vec::new();
    };
    let unannotated = infer::unannotated_funcs(module);
    let residual: Vec<&Func> = module
        .funcs
        .iter()
        .filter(|f| !infer::is_isolated(f, &unannotated))
        .collect();
    let mut diags = Diagnostics::new();
    infer::infer_partial(module, &residual, &mut diags);
    diags.items
}

/// The whole-module checks that are neither per-function linearity nor inference:
/// session-type fidelity, `bound` escapes, instance coherence. `no_eq`.
#[salsa::tracked(no_eq)]
pub fn non_func_diags(db: &dyn salsa::Database, file: SourceFile) -> Vec<Diagnostic> {
    match processed_module(db, file) {
        Some(module) => check::check_non_func(module),
        None => Vec::new(),
    }
}

/// Run the incremental front end for `file` and collect all diagnostics. This is
/// the entry point the LSP uses; on unchanged text the queries are memoized, and on
/// a body edit only the edited declaration's `check_decl`/`infer_decl` re-run — the
/// other declarations' per-decl checks are reused via the backdated `sig_env` /
/// `sig_view`. Inference for unannotated functions stays whole-module (`infer_residual`).
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
    // Per-declaration linearity + isolated inference (each memoized independently).
    for item in decl_items(db, file).clone() {
        out.extend(check_decl(db, item).iter().cloned());
        out.extend(infer_decl(db, item).iter().cloned());
    }
    // Whole-module residual inference + session/bound/instance checks.
    out.extend(infer_residual(db, file).iter().cloned());
    out.extend(non_func_diags(db, file).iter().cloned());
    out
}
