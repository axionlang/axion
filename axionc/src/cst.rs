//! Lossless concrete syntax tree (§8), built on [`rowan`] — **Stage 1**.
//!
//! This is the foundation of the rowan migration: a *lossless* green tree (every
//! byte of the source, including whitespace and comments, is a leaf) with a coarse
//! grammar structure — the module splits into top-level **declaration** nodes at
//! column-1 boundaries (the same rule the layout algorithm uses). It round-trips
//! exactly (`node.text() == src`) and supports document-symbol extraction.
//!
//! What Stage 1 does NOT do yet: structure expressions/patterns/types, emit ERROR
//! nodes from grammar-level recovery, or drive analysis (the pipeline still runs on
//! `ast::Module` via the recursive-descent parser). Those are later stages; this
//! layer is additive and feature-gated so the CLI/default builds are unaffected.

use rowan::{GreenNodeBuilder, Language};

use crate::lexer::{lex, LineMap, Tok};

/// Node and token kinds of the Axión CST. Token kinds are coarse (enough to find a
/// declaration's name and to classify trivia); later stages refine them.
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash)]
#[repr(u16)]
#[allow(non_camel_case_types, missing_docs)] // the variant names are self-documenting
pub enum SyntaxKind {
    // --- trivia + tokens ---
    WHITESPACE = 0,
    COMMENT,
    IDENT,
    CONID,
    KEYWORD,
    LITERAL,
    PUNCT,
    // --- nodes ---
    MODULE,
    DECL,
    ERROR,
}

use SyntaxKind::{COMMENT, CONID, DECL, IDENT, KEYWORD, LITERAL, MODULE, PUNCT, WHITESPACE};

impl From<SyntaxKind> for rowan::SyntaxKind {
    fn from(k: SyntaxKind) -> Self {
        rowan::SyntaxKind(k as u16)
    }
}

/// The rowan [`Language`] binding for Axión.
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub enum AxionLang {}

impl Language for AxionLang {
    type Kind = SyntaxKind;

    fn kind_from_raw(raw: rowan::SyntaxKind) -> SyntaxKind {
        match raw.0 {
            0 => WHITESPACE,
            1 => COMMENT,
            2 => IDENT,
            3 => CONID,
            4 => KEYWORD,
            5 => LITERAL,
            6 => PUNCT,
            7 => MODULE,
            8 => DECL,
            _ => SyntaxKind::ERROR,
        }
    }

    fn kind_to_raw(kind: SyntaxKind) -> rowan::SyntaxKind {
        kind.into()
    }
}

/// A typed syntax node over the Axión CST.
pub type SyntaxNode = rowan::SyntaxNode<AxionLang>;

/// The CST token kind of a lexer token.
fn token_kind(t: &Tok) -> SyntaxKind {
    match t {
        Tok::VarId(_) => IDENT,
        Tok::ConId(_) => CONID,
        Tok::Int(_) | Tok::Float(_) | Tok::Str(_) => LITERAL,
        Tok::Where
        | Tok::Let
        | Tok::In
        | Tok::Of
        | Tok::If
        | Tok::Then
        | Tok::Else
        | Tok::Case
        | Tok::Data
        | Tok::Do
        | Tok::Foreign
        | Tok::Class
        | Tok::Instance
        | Tok::Module
        | Tok::Import
        | Tok::Qualified
        | Tok::As => KEYWORD,
        _ => PUNCT,
    }
}

/// Emit a run of inter-token source text (whitespace and/or a line comment) as a
/// single trivia leaf. `--` anywhere marks it a comment; otherwise whitespace.
/// Either way the text is preserved verbatim, so the tree stays lossless.
fn emit_trivia(b: &mut GreenNodeBuilder, text: &str) {
    if text.is_empty() {
        return;
    }
    let kind = if text.contains("--") { COMMENT } else { WHITESPACE };
    b.token(kind.into(), text);
}

/// Build the lossless CST of `src`. On a lex error the tree is truncated at the bad
/// character (the prefix still round-trips); grammar-level recovery arrives with the
/// later stages.
pub fn build_cst(src: &str) -> SyntaxNode {
    let tokens = lex(src).unwrap_or_default();
    let lines = LineMap::new(src);
    let mut b = GreenNodeBuilder::new();
    b.start_node(MODULE.into());
    let mut cursor = 0usize;
    let mut decl_open = false;
    for t in &tokens {
        // Inter-token trivia belongs to the currently-open node (trailing on the
        // previous declaration, or leading under MODULE before the first one).
        if t.start > cursor {
            emit_trivia(&mut b, src.get(cursor..t.start).unwrap_or(""));
        }
        // A token at column 1 starts a new top-level declaration (layout rule).
        let (_, col) = lines.pos(t.start);
        if col == 1 || !decl_open {
            if decl_open {
                b.finish_node();
            }
            b.start_node(DECL.into());
            decl_open = true;
        }
        b.token(token_kind(&t.tok).into(), src.get(t.start..t.end).unwrap_or(""));
        cursor = t.end;
    }
    if cursor < src.len() {
        emit_trivia(&mut b, src.get(cursor..).unwrap_or(""));
    }
    if decl_open {
        b.finish_node();
    }
    b.finish_node(); // MODULE
    SyntaxNode::new_root(b.finish())
}

/// Top-level declarations as `(name, text-range)` — the first identifier of each
/// `DECL` node names it. Powers editor document symbols / outline.
pub fn document_symbols(root: &SyntaxNode) -> Vec<(String, rowan::TextRange)> {
    root.children()
        .filter(|n| n.kind() == DECL)
        .filter_map(|decl| {
            let name = decl
                .children_with_tokens()
                .filter_map(|el| el.into_token())
                .find(|t| matches!(t.kind(), IDENT | CONID))
                .map(|t| t.text().to_string())?;
            Some((name, decl.text_range()))
        })
        .collect()
}
