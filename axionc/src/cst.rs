//! Lossless concrete syntax tree (§8), built on [`rowan`] — **Stage 2**.
//!
//! A *lossless* green tree (every byte of source, including whitespace and
//! comments, is a leaf — it round-trips exactly) that is now **grammar-structured**:
//! top-level declaration nodes (split at column-1 boundaries, the layout rule) with
//! nested expression and pattern nodes, plus ERROR nodes over regions the parser
//! could not parse (from declaration-level recovery). Regions the current parser
//! keeps opaque — type signatures, `data`/`class` internals — stay as flat token
//! runs inside their declaration; structuring those (and intra-declaration error
//! recovery) is a later refinement.
//!
//! To avoid a second, divergent parser, the structure is derived from the AST that
//! the proven recursive-descent parser already produces: the AST's spans
//! (`Expr`/`Pat`/`Clause`) drive where nodes open and close, while every source
//! token is still emitted as a leaf, so losslessness holds by construction.
//!
//! Still additive: the analysis pipeline runs on `ast::Module`; the CST does not
//! drive checking yet (that flip is Stage 3).

use rowan::{GreenNodeBuilder, Language};

use crate::ast::{Body, Clause, Expr, Func, Pat, Span};
use crate::layout::{self, LSpanned, LTok};
use crate::lexer::{lex, LineMap, Spanned, Tok};

/// Node and token kinds of the Axión CST.
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
    // expression nodes
    LITERAL_EXPR,
    NAME_EXPR,
    APP_EXPR,
    BINOP_EXPR,
    IF_EXPR,
    LET_EXPR,
    CASE_EXPR,
    LAMBDA_EXPR,
    TUPLE_EXPR,
    RECORD_EXPR,
    PAREN_EXPR,
    LIST_EXPR,
    SECTION_EXPR,
    DO_EXPR,
    BIND_STMT,
    EXPR_STMT,
    // pattern nodes
    WILD_PAT,
    VAR_PAT,
    LIT_PAT,
    CON_PAT,
    TUPLE_PAT,
    // type nodes
    TYPE_CON,
    TYPE_VAR,
    TYPE_APP,
    TYPE_ARROW,
    TYPE_TUPLE,
    TYPE_UNIT,
    // declaration nodes
    SIG,
    FUN_CLAUSE,
    GUARD,
    WHERE,
    CONSTRAINT,
    DATA_DECL,
    CON_DECL,
    FIELD,
    CLASS_DECL,
    METHOD_SIG,
    INSTANCE_DECL,
    FOREIGN_DECL,
    IMPORT_DECL,
    MODULE_HEADER,
    // a user-defined symbolic operator token (`<+>`, `|>`, …) — distinct from PUNCT so
    // it can name a function in a `(<+>) x y = …` definition head. Appended last to keep
    // the `repr(u16)` discriminants (and the `KINDS` table) stable.
    OPER,
    // a fixity declaration node (`infixl 6 <+>`) — structurally represented but dropped by
    // `lower_module` (fixities are pre-scanned into the fixity table). Appended last.
    FIXITY_DECL,
}

use SyntaxKind::{
    APP_EXPR, BIND_STMT, BINOP_EXPR, CASE_EXPR, CLASS_DECL, COMMENT, CONID, CONSTRAINT, CON_DECL,
    CON_PAT, DATA_DECL, DECL, DO_EXPR, ERROR, EXPR_STMT, FIELD, FIXITY_DECL, FOREIGN_DECL,
    FUN_CLAUSE, GUARD, IDENT, IF_EXPR, IMPORT_DECL, INSTANCE_DECL, KEYWORD, LAMBDA_EXPR, LET_EXPR,
    LIST_EXPR, LITERAL, LITERAL_EXPR, LIT_PAT, METHOD_SIG, MODULE, MODULE_HEADER, NAME_EXPR, OPER,
    PAREN_EXPR, PUNCT, RECORD_EXPR, SECTION_EXPR, SIG, TUPLE_EXPR, TUPLE_PAT, TYPE_APP, TYPE_ARROW,
    TYPE_CON, TYPE_TUPLE, TYPE_UNIT, TYPE_VAR, VAR_PAT, WHERE, WHITESPACE, WILD_PAT,
};

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
        // Safe: kinds are a small contiguous `repr(u16)` enum and every tree we
        // build uses `kind_to_raw`, so the raw value is always in range.
        const KINDS: &[SyntaxKind] = &[
            WHITESPACE,
            COMMENT,
            IDENT,
            CONID,
            KEYWORD,
            LITERAL,
            PUNCT,
            MODULE,
            DECL,
            ERROR,
            LITERAL_EXPR,
            NAME_EXPR,
            APP_EXPR,
            BINOP_EXPR,
            IF_EXPR,
            LET_EXPR,
            CASE_EXPR,
            LAMBDA_EXPR,
            TUPLE_EXPR,
            RECORD_EXPR,
            PAREN_EXPR,
            LIST_EXPR,
            SECTION_EXPR,
            DO_EXPR,
            BIND_STMT,
            EXPR_STMT,
            WILD_PAT,
            VAR_PAT,
            LIT_PAT,
            CON_PAT,
            TUPLE_PAT,
            TYPE_CON,
            TYPE_VAR,
            TYPE_APP,
            TYPE_ARROW,
            TYPE_TUPLE,
            TYPE_UNIT,
            SIG,
            FUN_CLAUSE,
            GUARD,
            WHERE,
            CONSTRAINT,
            DATA_DECL,
            CON_DECL,
            FIELD,
            CLASS_DECL,
            METHOD_SIG,
            INSTANCE_DECL,
            FOREIGN_DECL,
            IMPORT_DECL,
            MODULE_HEADER,
            OPER,
            FIXITY_DECL,
        ];
        KINDS.get(raw.0 as usize).copied().unwrap_or(ERROR)
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
        Tok::Op(_) => OPER,
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

// --- outline: the structure to overlay on the token stream, from the AST ---

struct Outline {
    kind: SyntaxKind,
    span: Span,
    children: Vec<Outline>,
}

fn pat_span(p: &Pat) -> Span {
    match p {
        Pat::Wild(s) | Pat::Var(_, s) | Pat::Int(_, s) | Pat::Con(_, _, s) | Pat::Tuple(_, s) => *s,
    }
}

fn pat_outline(p: &Pat) -> Outline {
    let (kind, children) = match p {
        Pat::Wild(_) => (WILD_PAT, vec![]),
        Pat::Var(_, _) => (VAR_PAT, vec![]),
        Pat::Int(_, _) => (LIT_PAT, vec![]),
        Pat::Con(_, ps, _) => (CON_PAT, ps.iter().map(pat_outline).collect()),
        Pat::Tuple(ps, _) => (TUPLE_PAT, ps.iter().map(pat_outline).collect()),
    };
    Outline {
        kind,
        span: pat_span(p),
        children,
    }
}

fn expr_outline(e: &Expr) -> Outline {
    let (kind, children) = match e {
        Expr::Int(..) | Expr::Float(..) | Expr::Str(..) => (LITERAL_EXPR, vec![]),
        Expr::Var(..) | Expr::Con(..) => (NAME_EXPR, vec![]),
        Expr::App(f, a, _) => (APP_EXPR, vec![expr_outline(f), expr_outline(a)]),
        Expr::BinOp(_, l, r, _) => (BINOP_EXPR, vec![expr_outline(l), expr_outline(r)]),
        Expr::If(c, t, e, _) => (
            IF_EXPR,
            vec![expr_outline(c), expr_outline(t), expr_outline(e)],
        ),
        Expr::Let(funcs, body, _) => {
            let mut kids: Vec<Outline> = funcs.iter().flat_map(clause_outlines).collect();
            kids.push(expr_outline(body));
            (LET_EXPR, kids)
        }
        Expr::Case(scrut, arms, _) => {
            let mut kids = vec![expr_outline(scrut)];
            for (p, e) in arms {
                kids.push(pat_outline(p));
                kids.push(expr_outline(e));
            }
            (CASE_EXPR, kids)
        }
        Expr::Tuple(es, _) => (TUPLE_EXPR, es.iter().map(expr_outline).collect()),
        Expr::RecordCon(_, fields, _) => (
            RECORD_EXPR,
            fields.iter().map(|(_, e)| expr_outline(e)).collect(),
        ),
        Expr::RecordUpd(base, fields, _) => {
            let mut kids = vec![expr_outline(base)];
            kids.extend(fields.iter().map(|(_, e)| expr_outline(e)));
            (RECORD_EXPR, kids)
        }
        Expr::Lam(pats, body, _) => {
            let mut kids: Vec<Outline> = pats.iter().map(pat_outline).collect();
            kids.push(expr_outline(body));
            (LAMBDA_EXPR, kids)
        }
    };
    Outline {
        kind,
        span: e.span(),
        children,
    }
}

/// The structured children a clause contributes (its parameter patterns, its body
/// expressions, and its `where` bindings), sorted by start offset.
fn clause_children(c: &Clause) -> Vec<Outline> {
    let mut kids: Vec<Outline> = c.pats.iter().map(pat_outline).collect();
    match &c.body {
        Body::Plain(e) => kids.push(expr_outline(e)),
        Body::Guarded(arms) => {
            for (g, r) in arms {
                kids.push(expr_outline(g));
                kids.push(expr_outline(r));
            }
        }
    }
    for w in &c.wher {
        kids.extend(clause_outlines(w));
    }
    kids.sort_by_key(|o| o.span.0);
    kids
}

/// One outline per clause of `f` (a `where`/`let` binding may have several).
fn clause_outlines(f: &Func) -> Vec<Outline> {
    f.clauses
        .iter()
        .map(|c| Outline {
            kind: DECL,
            span: c.span,
            children: clause_children(c),
        })
        .collect()
}

// --- emitter: walk tokens, weaving trivia, applying the outline ---

struct Emitter<'a> {
    src: &'a str,
    toks: &'a [Spanned],
    ti: usize,
    cursor: usize,
    b: GreenNodeBuilder<'static>,
}

impl Emitter<'_> {
    /// Emit tokens (and the trivia before them) until the cursor reaches `target`.
    /// Node boundaries come from token spans, so `target` always lands on a token
    /// edge — no token is ever split.
    fn emit_up_to(&mut self, target: usize) {
        if target <= self.cursor {
            return;
        }
        while self.ti < self.toks.len() && self.toks[self.ti].start < target {
            let t = &self.toks[self.ti];
            if t.start > self.cursor {
                self.trivia(t.start);
            }
            let text = self.src.get(t.start..t.end).unwrap_or("");
            self.b.token(token_kind(&t.tok).into(), text);
            self.cursor = t.end;
            self.ti += 1;
        }
        if self.cursor < target {
            self.trivia(target);
        }
    }

    /// Emit the inter-token run `[cursor, to)` as a single trivia leaf.
    fn trivia(&mut self, to: usize) {
        let text = self.src.get(self.cursor..to).unwrap_or("");
        if !text.is_empty() {
            let kind = if text.contains("--") {
                COMMENT
            } else {
                WHITESPACE
            };
            self.b.token(kind.into(), text);
        }
        self.cursor = to;
    }

    fn build_outline(&mut self, o: &Outline) {
        self.emit_up_to(o.span.0);
        self.b.start_node(o.kind.into());
        for c in &o.children {
            self.build_outline(c);
        }
        self.emit_up_to(o.span.1);
        self.b.finish_node();
    }
}

/// Build the grammar-structured, lossless CST of `src`.
pub fn build_cst(src: &str) -> SyntaxNode {
    // Recovering lex: a stray illegal character is skipped (it lands in trivia) rather
    // than clearing the whole token stream, so editor features survive it.
    let (toks, _lex_errs) = crate::lexer::lex_recover(src);
    let lines = LineMap::new(src);

    // Parse (with declaration-level recovery) to drive the structure.
    let ltokens = crate::layout::layout(&toks, &lines);
    let (module, errors) = crate::parser::parse_module_resilient(&ltokens);

    // Top-level nodes: one DECL per column-1 declaration, ordered by source. Each
    // gets the clause outlines whose span falls inside it, plus an ERROR wrap for a
    // declaration the parser could not parse (a recovered error span).
    let ranges = decl_ranges(&toks, &lines, src.len());
    let mut top: Vec<Outline> = ranges
        .iter()
        .map(|&(lo, hi)| Outline {
            kind: DECL,
            span: (lo, hi),
            children: Vec::new(),
        })
        .collect();

    // Attach each clause's structured children to the DECL that contains it.
    for f in &module.funcs {
        for c in &f.clauses {
            if let Some(o) = top.iter_mut().find(|o| contains(o.span, c.span.0)) {
                o.children.extend(clause_children(c));
            }
        }
    }
    for o in &mut top {
        o.children.sort_by_key(|c| c.span.0);
    }
    // Mark recovered-error regions: the DECL a parse-error span points into becomes
    // an ERROR node (the parser skipped it, so it has no structured children).
    for e in &errors {
        if let Some(span) = e.labels.first().map(|l| (l.start, l.end)) {
            if let Some(o) = top.iter_mut().find(|o| contains(o.span, span.0)) {
                o.kind = ERROR;
            }
        }
    }

    let mut em = Emitter {
        src,
        toks: &toks,
        ti: 0,
        cursor: 0,
        b: GreenNodeBuilder::new(),
    };
    em.b.start_node(MODULE.into());
    for o in &top {
        em.build_outline(o);
    }
    em.emit_up_to(src.len());
    em.b.finish_node();
    SyntaxNode::new_root(em.b.finish())
}

fn contains(range: Span, point: usize) -> bool {
    range.0 <= point && point < range.1
}

/// Column-1 top-level declaration ranges: `[start_i, start_{i+1})`, last to EOF.
/// Leading trivia before the first declaration is left under `MODULE`.
fn decl_ranges(toks: &[Spanned], lines: &LineMap, end: usize) -> Vec<(usize, usize)> {
    let starts: Vec<usize> = toks
        .iter()
        .filter(|t| lines.pos(t.start).1 == 1)
        .map(|t| t.start)
        .collect();
    let mut ranges = Vec::with_capacity(starts.len());
    for (i, &lo) in starts.iter().enumerate() {
        let hi = starts.get(i + 1).copied().unwrap_or(end);
        ranges.push((lo, hi));
    }
    ranges
}

/// Top-level declarations as `(name, text-range)` — the first identifier of each
/// declaration node names it. Powers editor document symbols / outline.
pub fn document_symbols(root: &SyntaxNode) -> Vec<(String, rowan::TextRange)> {
    root.children()
        .filter(|n| matches!(n.kind(), DECL | ERROR))
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

/// Every occurrence of the identifier/constructor `name` in the tree, as text ranges
/// — the candidate set for find-references / rename (filtered to one binding by the
/// caller's scope resolution).
pub fn name_occurrences(root: &SyntaxNode, name: &str) -> Vec<rowan::TextRange> {
    root.descendants_with_tokens()
        .filter_map(|el| el.into_token())
        .filter(|t| matches!(t.kind(), IDENT | CONID) && t.text() == name)
        .map(|t| t.text_range())
        .collect()
}

/// The token-driven CST of `src`, WITH intra-declaration recovery — malformed regions
/// become ERROR nodes and the surrounding declarations survive. Unlike [`build_cst`]
/// (AST-derived, so a broken clause loses its nested structure), this keeps a half-typed
/// declaration's binders as `VAR_PAT` nodes, so the editor can still see the locals in
/// scope while you type. Recovering lex means even a stray illegal character keeps the
/// buffer's structure (the bad byte survives in trivia).
pub fn parse_recover(src: &str) -> SyntaxNode {
    parse_module_cst(src).0
}

/// The names bound within the top-level declaration containing `offset`: every `VAR_PAT`
/// binder (parameters, lambda/`case`/`let` pattern variables) plus each clause name (the
/// function itself and its `let`/`where` bindings). An over-approximation of the locals
/// in scope — robust to a half-typed body, which the AST scope walker would drop — for
/// mid-edit completion (the client filters by the typed prefix). Walk over the recovered
/// token-driven CST ([`parse_recover`]).
pub fn binders_in_decl(root: &SyntaxNode, offset: usize) -> Vec<String> {
    let probe = |off: usize| -> Option<SyntaxNode> {
        let ts = rowan::TextSize::new(u32::try_from(off).unwrap_or(0));
        root.children()
            .find(|n| n.text_range().start() <= ts && ts <= n.text_range().end())
    };
    // Probe the cursor AND the character before it: after typing a hole, the cursor sits
    // in the following declaration's leading trivia, but the binders you want belong to
    // the one you were just editing — `offset - 1` still points into it.
    let mut decls: Vec<SyntaxNode> = Vec::new();
    for off in [Some(offset), offset.checked_sub(1)].into_iter().flatten() {
        if let Some(d) = probe(off) {
            if !decls.iter().any(|x| x.text_range() == d.text_range()) {
                decls.push(d);
            }
        }
    }
    let leading_ident = |n: &SyntaxNode| {
        n.children_with_tokens()
            .filter_map(|el| el.into_token())
            .find(|t| t.kind() == IDENT)
            .map(|t| t.text().to_string())
    };
    let mut out = Vec::new();
    for decl in &decls {
        for node in decl.descendants() {
            if matches!(node.kind(), VAR_PAT | FUN_CLAUSE) {
                if let Some(name) = leading_ident(&node) {
                    if !out.contains(&name) {
                        out.push(name);
                    }
                }
            }
        }
    }
    out
}

/// The name (identifier/constructor) token at `offset`, if any — the target of a
/// go-to-definition or hover request.
pub fn name_at(root: &SyntaxNode, offset: usize) -> Option<String> {
    let ts = rowan::TextSize::new(u32::try_from(offset).unwrap_or(0));
    root.token_at_offset(ts)
        .find(|t| matches!(t.kind(), IDENT | CONID))
        .map(|t| t.text().to_string())
}

/// The defining occurrence of `name` among the top-level declarations: a function
/// name, a `data` type or constructor, a `class` name or method, or a `foreign`
/// name. Powers `textDocument/definition`.
pub fn definition_site(root: &SyntaxNode, name: &str) -> Option<rowan::TextRange> {
    root.children()
        .filter(|n| matches!(n.kind(), DECL | ERROR))
        .find_map(|decl| decl_defines(&decl, name))
}

fn decl_defines(decl: &SyntaxNode, name: &str) -> Option<rowan::TextRange> {
    let toks: Vec<_> = decl
        .children_with_tokens()
        .filter_map(|el| el.into_token())
        .filter(|t| !is_trivia(t.kind()))
        .collect();
    let first = toks.first()?;
    let kw = (first.kind() == KEYWORD).then(|| first.text());
    match kw {
        // `data T p* = C1 f* | C2 f* …`: the type name (after `data`) and each
        // constructor (after `=`/`|`) are defining CONIDs; field-type CONIDs are not.
        Some("data") => {
            let mut defining = false;
            for t in &toks {
                let text = t.text();
                if (t.kind() == KEYWORD && text == "data") || text == "=" || text == "|" {
                    defining = true;
                    continue;
                }
                if defining && t.kind() == CONID {
                    defining = false;
                    if text == name {
                        return Some(t.text_range());
                    }
                    continue;
                }
                defining = false;
            }
            None
        }
        // `class C a where { m :: … ; … }`: the class name, and each method (an
        // identifier immediately before `::`).
        Some("class") => {
            for w in toks.windows(2) {
                if w[0].kind() == IDENT && w[1].text() == "::" && w[0].text() == name {
                    return Some(w[0].text_range());
                }
            }
            toks.iter()
                .find(|t| t.kind() == CONID && t.text() == name)
                .map(rowan::SyntaxToken::<AxionLang>::text_range)
        }
        // instance/import/module headers don't *introduce* a queried name.
        Some("instance" | "import" | "module") => None,
        // function / signature / `foreign`: the declared name is the first identifier.
        _ => {
            let nt = toks.iter().find(|t| matches!(t.kind(), IDENT | CONID))?;
            (nt.text() == name).then(|| nt.text_range())
        }
    }
}

// === Stage 3a: token-driven CST-emitting parser (a subset) + CST→AST lowering ===
//
// The first real slice of the pipeline flip: instead of deriving the CST from the
// AST, this parses TOKENS DIRECTLY into a lossless, grammar-structured CST, then
// LOWERS that CST back to `ast::Expr`. It covers a subset of the expression grammar
// — atoms (literals, names, parenthesised), application, and the `* + - == < >`
// operators — and is proven equivalent to the existing recursive-descent parser by
// `expr_matches_parser` (used in the differential test). Later slices extend the
// grammar; once it covers everything and provably agrees, the default pipeline flips
// onto it. Excluded here (fall through to `None`): `:`/`++`/`.`/`$`/backtick/dotted
// operators, sections, records, lists, and `if`/`let`/`case`/`\`/`do`.

use crate::lexer::IntLit;

fn is_trivia(k: SyntaxKind) -> bool {
    matches!(k, WHITESPACE | COMMENT)
}

struct ExprParser<'a> {
    src: &'a str,
    toks: &'a [LSpanned],
    pos: usize,
    cursor: usize,
    b: GreenNodeBuilder<'static>,
    ok: bool,
    /// Module-wide operator fixities (from `infix*` declarations), pre-scanned — shared
    /// with the recursive-descent parser via [`crate::parser::op_fixity`].
    fixities: crate::parser::FixityTable,
}

impl ExprParser<'_> {
    /// The current REAL token (`None` at a layout-virtual token or end of input), so
    /// the whole operator ladder can match `Tok` variants unchanged.
    fn cur(&self) -> Option<&Tok> {
        match self.toks.get(self.pos).map(|s| &s.tok) {
            Some(LTok::Tok(t)) => Some(t),
            _ => None,
        }
    }

    fn peek_tok(&self, n: usize) -> Option<&Tok> {
        match self.toks.get(self.pos + n).map(|s| &s.tok) {
            Some(LTok::Tok(t)) => Some(t),
            _ => None,
        }
    }

    fn at_v(&self, v: &LTok) -> bool {
        self.toks.get(self.pos).map(|s| &s.tok) == Some(v)
    }

    /// Consume a layout-virtual token (`VLBrace`/`VSemi`/`VRBrace`): advance without
    /// emitting a leaf and without moving the trivia cursor (virtuals carry no text).
    fn eat_v(&mut self, v: &LTok) -> bool {
        if self.at_v(v) {
            self.pos += 1;
            true
        } else {
            false
        }
    }

    fn trivia(&mut self, to: usize) {
        let text = self.src.get(self.cursor..to).unwrap_or("");
        if !text.is_empty() {
            let kind = if text.contains("--") {
                COMMENT
            } else {
                WHITESPACE
            };
            self.b.token(kind.into(), text);
        }
        self.cursor = to;
    }

    /// Emit the current REAL token (with its leading trivia) as a leaf and advance.
    fn bump(&mut self) {
        if let Some(s) = self.toks.get(self.pos) {
            if let LTok::Tok(t) = &s.tok {
                if s.start > self.cursor {
                    self.trivia(s.start);
                }
                let text = self.src.get(s.start..s.end).unwrap_or("");
                self.b.token(token_kind(t).into(), text);
                self.cursor = s.end;
            }
            self.pos += 1;
        }
    }

    /// A layout block: `{ item (; item)* }`, mirroring `parser::block`.
    fn block(&mut self, mut item: impl FnMut(&mut Self)) {
        self.eat_v(&LTok::VLBrace);
        loop {
            while self.eat_v(&LTok::VSemi) {}
            if self.at_v(&LTok::VRBrace) || self.pos >= self.toks.len() {
                break;
            }
            let before = self.pos;
            item(self);
            // Intra-declaration recovery: an item that cannot even start (malformed
            // input) is wrapped in an ERROR node and the block CONTINUES, so a
            // half-typed declaration no longer kills its siblings. `recover_item`
            // guarantees progress, so the loop still terminates.
            if self.pos == before {
                self.recover_item();
            }
            while self.eat_v(&LTok::VSemi) {}
            if self.at_v(&LTok::VRBrace) || self.pos >= self.toks.len() {
                break;
            }
        }
        self.eat_v(&LTok::VRBrace);
    }

    /// Recover from an item the block parser could not start: wrap the un-parseable
    /// tokens — up to the next item boundary (`VSemi`/`VRBrace`) at this block's depth —
    /// in an ERROR node, so the surrounding declarations survive. Nested layout blocks
    /// are skipped whole (depth-tracked). Marks the parse non-`full`; guarantees the
    /// position advances so the enclosing `block` loop always terminates.
    fn recover_item(&mut self) {
        self.ok = false;
        self.b.start_node(ERROR.into());
        let start = self.pos;
        let mut depth = 0i32;
        while let Some(s) = self.toks.get(self.pos) {
            match &s.tok {
                LTok::VLBrace => {
                    depth += 1;
                    self.pos += 1;
                }
                LTok::VRBrace => {
                    if depth == 0 {
                        break;
                    }
                    depth -= 1;
                    self.pos += 1;
                }
                LTok::VSemi => {
                    if depth == 0 {
                        break;
                    }
                    self.pos += 1;
                }
                LTok::Tok(_) => self.bump(),
            }
        }
        // Defensive: the call site never enters on a depth-0 delimiter, but never spin.
        if self.pos == start {
            self.pos += 1;
        }
        self.b.finish_node();
    }

    /// Mirrors `parser::parse_expr`: `if`/`\` prefix forms, else the operator ladder.
    /// (`let`/`case`/`do` need layout blocks — a later slice; here they fall out of
    /// the subset.)
    fn expr(&mut self) {
        match self.cur() {
            Some(Tok::If) => self.if_expr(),
            Some(Tok::Backslash) => self.lam_expr(),
            Some(Tok::Case) => self.case_expr(),
            Some(Tok::Let) => self.let_expr(),
            Some(Tok::Do) => self.do_expr(),
            _ => self.dollar(),
        }
    }

    /// `do { stmt ; … }` — statements desugared to nested `Case` in lowering.
    fn do_expr(&mut self) {
        self.b.start_node(DO_EXPR.into());
        self.bump(); // do
        self.block(Self::stmt);
        self.b.finish_node();
    }

    /// A `do` statement: `pat <- expr` (bind) or `expr`. `<-` is bind-only syntax, so
    /// a lookahead for it at statement depth 0 avoids the reference's backtracking.
    fn stmt(&mut self) {
        if self.stmt_is_bind() {
            self.b.start_node(BIND_STMT.into());
            self.apat();
            self.expect(&Tok::LArrow);
            self.expr();
            self.b.finish_node();
        } else {
            self.b.start_node(EXPR_STMT.into());
            self.expr();
            self.b.finish_node();
        }
    }

    fn stmt_is_bind(&self) -> bool {
        let mut depth = 0i32;
        let mut i = self.pos;
        while let Some(s) = self.toks.get(i) {
            match &s.tok {
                LTok::VLBrace => depth += 1,
                LTok::VRBrace => {
                    if depth == 0 {
                        break;
                    }
                    depth -= 1;
                }
                LTok::VSemi if depth == 0 => break,
                LTok::Tok(Tok::LArrow) if depth == 0 => return true,
                _ => {}
            }
            i += 1;
        }
        false
    }

    /// `case scrut of { pat -> body ; … }`.
    fn case_expr(&mut self) {
        self.b.start_node(CASE_EXPR.into());
        self.bump(); // case
        self.expr(); // scrutinee
        self.expect(&Tok::Of);
        self.block(|p| {
            p.pat();
            p.expect(&Tok::Arrow);
            p.expr();
        });
        self.b.finish_node();
    }

    /// `let { binding ; … } in body`. Bindings are simple clauses `name apat* = e`
    /// (signatures / guards / `where` fall out of the subset).
    fn let_expr(&mut self) {
        self.b.start_node(LET_EXPR.into());
        self.bump(); // let
        self.block(Self::top_decl);
        self.expect(&Tok::In);
        self.expr(); // body
        self.b.finish_node();
    }

    /// `f $ x` (right-assoc, lowest precedence).
    fn dollar(&mut self) {
        let cp = self.b.checkpoint();
        self.ops(0);
        if matches!(self.cur(), Some(Tok::Dollar)) {
            self.b.start_node_at(cp, BINOP_EXPR.into());
            self.bump();
            self.expr(); // rhs is a full expression
            self.b.finish_node();
        }
    }

    /// The whole binary-operator layer, resolved by precedence climbing over
    /// [`crate::parser::op_fixity`] — the same table the recursive-descent parser uses, so
    /// the two stay byte-exact. Application is the tightest primary; `$` is handled by
    /// `dollar`. Built-in operators keep the historical ladder; user operators use the
    /// module's `infix*` declarations. Left/right associativity falls out of the
    /// checkpoint-at-start plus `next_min` recursion.
    fn ops(&mut self, min_prec: u8) {
        let cp = self.b.checkpoint();
        self.app();
        while let Some((name, width)) = self.peek_infix_op() {
            let (prec, assoc) = crate::parser::op_fixity(&name, &self.fixities);
            if prec < min_prec {
                break;
            }
            self.b.start_node_at(cp, BINOP_EXPR.into());
            for _ in 0..width {
                self.bump(); // the operator (a symbolic token, or ` name ` = 3 tokens)
            }
            let next_min = if assoc == crate::parser::Assoc::Right {
                prec
            } else {
                prec + 1
            };
            self.ops(next_min);
            self.b.finish_node();
        }
    }

    /// The infix operator at the cursor and its token width (`` ` name ` `` = 3), without
    /// consuming. Mirrors `parser::peek_infix_op`; `$` is excluded (handled by `dollar`).
    fn peek_infix_op(&self) -> Option<(String, usize)> {
        let name = match self.cur()? {
            Tok::Dot => ".",
            Tok::Star => "*",
            Tok::StarDot => "*.",
            Tok::SlashDot => "/.",
            Tok::Plus => "+",
            Tok::Minus => "-",
            Tok::PlusDot => "+.",
            Tok::MinusDot => "-.",
            Tok::Colon => ":",
            Tok::PlusPlus => "++",
            Tok::EqEq => "==",
            Tok::Lt => "<",
            Tok::Gt => ">",
            Tok::EqEqDot => "==.",
            Tok::LtDot => "<.",
            Tok::GtDot => ">.",
            Tok::Op(s) => return Some((s.clone(), 1)),
            Tok::Backtick => {
                // ` name ` — require the CLOSING backtick; a missing close is malformed, so
                // return `None` and leave the stray ` unconsumed (the old `mul()` flagged
                // it via `ok = false`) rather than blindly bumping the operand as width-3.
                return match (self.peek_tok(1), self.peek_tok(2)) {
                    (Some(Tok::VarId(n)), Some(Tok::Backtick)) => Some((n.clone(), 3)),
                    _ => None,
                };
            }
            _ => return None,
        };
        Some((name.to_string(), 1))
    }

    /// Consume a fixity declaration `infix[l|r] <prec> <op>[, <op>]*` into a `FIXITY_DECL`
    /// node (dropped by `lower_module`; the table is pre-scanned).
    fn fixity_decl(&mut self) {
        self.b.start_node(FIXITY_DECL.into());
        self.bump(); // infixl / infixr / infix
        self.bump(); // precedence integer
        loop {
            match self.cur() {
                Some(Tok::Op(_)) => self.bump(),
                Some(Tok::Backtick) if matches!(self.peek_tok(1), Some(Tok::VarId(_))) => {
                    self.bump(); // `
                    self.bump(); // name
                    if matches!(self.cur(), Some(Tok::Backtick)) {
                        self.bump(); // `
                    } else {
                        self.ok = false;
                    }
                }
                _ => break,
            }
            if matches!(self.cur(), Some(Tok::Comma)) {
                self.bump();
            } else {
                break;
            }
        }
        self.b.finish_node();
    }

    fn app(&mut self) {
        let cp = self.b.checkpoint();
        self.atom_post();
        while self.starts_atom() {
            self.b.start_node_at(cp, APP_EXPR.into());
            self.atom_post();
            self.b.finish_node();
        }
    }

    /// An atom with any trailing record `{ … }` (`Con { f = e }` constructs,
    /// `e { f = e }` updates — records bind tighter than application).
    fn atom_post(&mut self) {
        let cp = self.b.checkpoint();
        self.atom();
        while matches!(self.cur(), Some(Tok::LBrace)) {
            self.b.start_node_at(cp, RECORD_EXPR.into());
            self.record_fields();
            self.b.finish_node();
        }
    }

    fn record_fields(&mut self) {
        self.bump(); // '{'
        if !matches!(self.cur(), Some(Tok::RBrace)) {
            self.field_assign();
            while matches!(self.cur(), Some(Tok::Comma)) {
                self.bump();
                self.field_assign();
            }
        }
        self.expect(&Tok::RBrace);
    }

    fn field_assign(&mut self) {
        if matches!(self.cur(), Some(Tok::VarId(_))) {
            self.bump(); // field name
        } else {
            self.ok = false;
        }
        self.expect(&Tok::Equals);
        self.expr();
    }

    fn starts_atom(&self) -> bool {
        matches!(
            self.cur(),
            Some(
                Tok::Int(_)
                    | Tok::Float(_)
                    | Tok::Str(_)
                    | Tok::VarId(_)
                    | Tok::ConId(_)
                    | Tok::LParen
                    | Tok::LBracket
            )
        )
    }

    /// The operator of a section `(op)` — an operator token immediately followed by
    /// `)` at the current position.
    fn section_op(&self) -> bool {
        let is_op = matches!(
            self.cur(),
            Some(Tok::Plus | Tok::Minus | Tok::Star | Tok::EqEq | Tok::Lt | Tok::Gt | Tok::Op(_))
        );
        is_op && matches!(self.peek_tok(1), Some(Tok::RParen))
    }

    fn atom(&mut self) {
        match self.cur() {
            Some(Tok::Int(_) | Tok::Float(_) | Tok::Str(_)) => {
                self.b.start_node(LITERAL_EXPR.into());
                self.bump();
                self.b.finish_node();
            }
            Some(Tok::VarId(_) | Tok::ConId(_)) => {
                self.b.start_node(NAME_EXPR.into());
                self.bump();
                self.b.finish_node();
            }
            Some(Tok::LParen) => {
                let cp = self.b.checkpoint();
                self.bump(); // '('
                if self.section_op() {
                    self.bump(); // operator
                    self.bump(); // ')'
                    self.b.start_node_at(cp, SECTION_EXPR.into());
                    self.b.finish_node();
                    return;
                }
                // `( e )` is transparent; `( e , e , … )` is a tuple.
                self.expr();
                let mut tuple = false;
                while matches!(self.cur(), Some(Tok::Comma)) {
                    tuple = true;
                    self.bump();
                    self.expr();
                }
                if matches!(self.cur(), Some(Tok::RParen)) {
                    self.bump(); // ')'
                } else {
                    self.ok = false;
                }
                let kind = if tuple { TUPLE_EXPR } else { PAREN_EXPR };
                self.b.start_node_at(cp, kind.into());
                self.b.finish_node();
            }
            Some(Tok::LBracket) => {
                self.b.start_node(LIST_EXPR.into());
                self.bump(); // '['
                if matches!(self.cur(), Some(Tok::RBracket)) {
                    self.bump(); // ']' — empty list
                } else {
                    self.expr();
                    if matches!(self.cur(), Some(Tok::DotDot)) {
                        self.bump(); // '..'
                        self.expr(); // range end
                    } else {
                        while matches!(self.cur(), Some(Tok::Comma)) {
                            self.bump();
                            self.expr();
                        }
                    }
                    self.expect(&Tok::RBracket);
                }
                self.b.finish_node();
            }
            _ => self.ok = false,
        }
    }

    fn if_expr(&mut self) {
        self.b.start_node(IF_EXPR.into());
        self.bump(); // if
        self.expr();
        self.expect(&Tok::Then);
        self.expr();
        self.expect(&Tok::Else);
        self.expr();
        self.b.finish_node();
    }

    fn lam_expr(&mut self) {
        self.b.start_node(LAMBDA_EXPR.into());
        self.bump(); // '\'
        while !matches!(self.cur(), Some(Tok::Arrow) | None) {
            self.apat();
        }
        self.expect(&Tok::Arrow);
        self.expr();
        self.b.finish_node();
    }

    fn expect(&mut self, t: &Tok) {
        if self.cur() == Some(t) {
            self.bump();
        } else {
            self.ok = false;
        }
    }

    fn starts_apat(&self) -> bool {
        matches!(
            self.cur(),
            Some(Tok::Int(_) | Tok::VarId(_) | Tok::ConId(_) | Tok::LParen)
        )
    }

    /// Pattern: applied constructor `Con apat*`, else an atomic pattern.
    fn pat(&mut self) {
        if matches!(self.cur(), Some(Tok::ConId(_))) {
            self.b.start_node(CON_PAT.into());
            self.bump(); // ConId
            while self.starts_apat() {
                self.apat();
            }
            self.b.finish_node();
        } else {
            self.apat();
        }
    }

    fn apat(&mut self) {
        match self.cur() {
            Some(Tok::Int(IntLit::Small(_))) => {
                self.b.start_node(LIT_PAT.into());
                self.bump();
                self.b.finish_node();
            }
            Some(Tok::VarId(name)) => {
                let kind = if name == "_" { WILD_PAT } else { VAR_PAT };
                self.b.start_node(kind.into());
                self.bump();
                self.b.finish_node();
            }
            Some(Tok::ConId(_)) => {
                self.b.start_node(CON_PAT.into()); // nullary
                self.bump();
                self.b.finish_node();
            }
            Some(Tok::LParen) => {
                let cp = self.b.checkpoint();
                self.bump(); // '('
                self.pat();
                while matches!(self.cur(), Some(Tok::Comma)) {
                    self.bump();
                    self.pat();
                }
                if matches!(self.cur(), Some(Tok::RParen)) {
                    self.bump();
                } else {
                    self.ok = false;
                }
                self.b.start_node_at(cp, TUPLE_PAT.into());
                self.b.finish_node();
            }
            _ => self.ok = false,
        }
    }

    // --- declarations, signatures and types (Stage 3f) ---

    fn expect_tok(&mut self, t: &Tok) {
        self.expect(t);
    }

    /// A top-level declaration: a signature `name :: [ctx =>] type` or a function
    /// clause `name apat* rhs [where …]`. Non-function declarations (data/class/
    /// instance/foreign/module/import) fall out of the subset (Stage 3g).
    fn top_decl(&mut self) {
        match self.cur() {
            Some(Tok::Data) => return self.data_decl(),
            Some(Tok::Class) => return self.class_decl(),
            Some(Tok::Instance) => return self.instance_decl(),
            Some(Tok::Foreign) => return self.foreign_decl(),
            Some(Tok::Module) => return self.module_header(),
            Some(Tok::Import) => return self.import_decl(),
            _ => {}
        }
        // fixity declaration `infixl 6 <+>` — a keyword-like VarId then an integer prec
        // (guards against a user function actually named `infixl`).
        if matches!(self.cur(), Some(Tok::VarId(kw)) if matches!(kw.as_str(), "infixl" | "infixr" | "infix"))
            && matches!(self.peek_tok(1), Some(Tok::Int(IntLit::Small(_))))
        {
            return self.fixity_decl();
        }
        let cp = self.b.checkpoint();
        if matches!(self.cur(), Some(Tok::VarId(_))) {
            self.bump(); // name
        } else if matches!(self.cur(), Some(Tok::LParen))
            && matches!(self.peek_tok(1), Some(Tok::Op(_)))
            && matches!(self.peek_tok(2), Some(Tok::RParen))
        {
            // a parenthesized operator names the function: `(<+>) x y = …`
            self.bump(); // (
            self.bump(); // operator
            self.bump(); // )
        } else {
            self.ok = false;
            return;
        }
        if matches!(self.cur(), Some(Tok::ColonColon)) {
            self.bump(); // ::
            self.qualified_type();
            self.b.start_node_at(cp, SIG.into());
            self.b.finish_node();
        } else {
            while !matches!(self.cur(), Some(Tok::Equals | Tok::Bar)) && self.cur().is_some() {
                self.apat();
                if !self.ok {
                    break;
                }
            }
            self.rhs();
            if matches!(self.cur(), Some(Tok::Where)) {
                self.where_block();
            }
            self.b.start_node_at(cp, FUN_CLAUSE.into());
            self.b.finish_node();
        }
    }

    /// The right-hand side: `= expr` (plain) or `(| guard = expr)+` (guarded).
    fn rhs(&mut self) {
        if matches!(self.cur(), Some(Tok::Bar)) {
            while matches!(self.cur(), Some(Tok::Bar)) {
                self.b.start_node(GUARD.into());
                self.bump(); // |
                self.expr(); // guard
                self.expect_tok(&Tok::Equals);
                self.expr(); // result
                self.b.finish_node();
            }
        } else {
            self.expect_tok(&Tok::Equals);
            self.expr(); // plain body
        }
    }

    fn where_block(&mut self) {
        self.b.start_node(WHERE.into());
        self.bump(); // where
        self.block(Self::top_decl);
        self.b.finish_node();
    }

    /// `[context =>] type`. A `=>` at type depth 0 (found by lookahead, avoiding the
    /// reference's backtracking) marks a constraint context.
    fn qualified_type(&mut self) {
        if self.has_fat_arrow() {
            self.b.start_node(CONSTRAINT.into());
            self.btype();
            self.b.finish_node();
            self.expect_tok(&Tok::FatArrow);
        }
        self.type_();
    }

    fn has_fat_arrow(&self) -> bool {
        let mut depth = 0i32;
        let mut i = self.pos;
        while let Some(s) = self.toks.get(i) {
            match &s.tok {
                LTok::Tok(Tok::LParen) => depth += 1,
                LTok::Tok(Tok::RParen) => depth -= 1,
                LTok::Tok(Tok::FatArrow) if depth == 0 => return true,
                LTok::Tok(Tok::Arrow) if depth == 0 => return false, // `->` before any `=>`
                LTok::VSemi | LTok::VRBrace if depth == 0 => return false,
                _ => {}
            }
            i += 1;
        }
        false
    }

    /// A type: `btype` optionally followed by `%mult ->` or `->` (right-assoc).
    fn type_(&mut self) {
        let cp = self.b.checkpoint();
        self.btype();
        if matches!(self.cur(), Some(Tok::Mult(_))) {
            if matches!(self.peek_tok(1), Some(Tok::Arrow)) {
                self.b.start_node_at(cp, TYPE_ARROW.into());
                self.bump(); // %mult
                self.bump(); // ->
                self.type_();
                self.b.finish_node();
            } else {
                self.bump(); // `%mult` on a result type: consumed, no arrow (inert)
            }
        } else if matches!(self.cur(), Some(Tok::Arrow)) {
            self.b.start_node_at(cp, TYPE_ARROW.into());
            self.bump(); // ->
            self.type_();
            self.b.finish_node();
        }
    }

    /// Applied type `atype atype*` (left-assoc).
    fn btype(&mut self) {
        let cp = self.b.checkpoint();
        self.atype();
        while self.starts_atype() {
            self.b.start_node_at(cp, TYPE_APP.into());
            self.atype();
            self.b.finish_node();
        }
    }

    fn starts_atype(&self) -> bool {
        matches!(
            self.cur(),
            Some(Tok::ConId(_) | Tok::VarId(_) | Tok::LParen)
        )
    }

    fn atype(&mut self) {
        match self.cur() {
            Some(Tok::ConId(_)) => {
                self.b.start_node(TYPE_CON.into());
                self.bump();
                self.b.finish_node();
            }
            Some(Tok::VarId(_)) => {
                self.b.start_node(TYPE_VAR.into());
                self.bump();
                self.b.finish_node();
            }
            Some(Tok::LParen) => {
                let cp = self.b.checkpoint();
                self.bump(); // '('
                if matches!(self.cur(), Some(Tok::RParen)) {
                    self.bump(); // ')' — unit
                    self.b.start_node_at(cp, TYPE_UNIT.into());
                    self.b.finish_node();
                    return;
                }
                self.type_();
                let mut tuple = false;
                while matches!(self.cur(), Some(Tok::Comma)) {
                    tuple = true;
                    self.bump();
                    self.type_();
                }
                self.expect_tok(&Tok::RParen);
                if tuple {
                    self.b.start_node_at(cp, TYPE_TUPLE.into());
                    self.b.finish_node();
                }
                // single: transparent (the inner type node stands on its own)
            }
            _ => self.ok = false,
        }
    }

    fn at_kw(&self, kw: &str) -> bool {
        matches!(self.cur(), Some(Tok::VarId(k)) if k == kw)
    }

    fn con_id(&mut self) {
        if matches!(self.cur(), Some(Tok::ConId(_))) {
            self.bump();
        } else {
            self.ok = false;
        }
    }

    fn var_id(&mut self) {
        if matches!(self.cur(), Some(Tok::VarId(_))) {
            self.bump();
        } else {
            self.ok = false;
        }
    }

    /// `data Name p* = Con | … [deriving (C, …)]`.
    fn data_decl(&mut self) {
        self.b.start_node(DATA_DECL.into());
        self.bump(); // data
        self.con_id(); // type name
        while matches!(self.cur(), Some(Tok::VarId(_))) {
            self.bump(); // type parameter
        }
        self.expect_tok(&Tok::Equals);
        self.con_decl();
        while matches!(self.cur(), Some(Tok::Bar)) {
            self.bump();
            self.con_decl();
        }
        if self.at_kw("deriving") {
            self.bump(); // deriving
            self.expect_tok(&Tok::LParen);
            loop {
                self.con_id();
                if !matches!(self.cur(), Some(Tok::Comma)) {
                    break;
                }
                self.bump();
            }
            self.expect_tok(&Tok::RParen);
        }
        self.b.finish_node();
    }

    fn con_decl(&mut self) {
        self.b.start_node(CON_DECL.into());
        self.con_id(); // constructor name
        if matches!(self.cur(), Some(Tok::LBrace)) {
            self.bump(); // {
            if !matches!(self.cur(), Some(Tok::RBrace)) {
                self.record_field();
                while matches!(self.cur(), Some(Tok::Comma)) {
                    self.bump();
                    self.record_field();
                }
            }
            self.expect_tok(&Tok::RBrace);
        } else {
            while self.starts_atype() && !self.at_kw("deriving") {
                self.positional_field();
            }
        }
        self.b.finish_node();
    }

    /// `name :: btype [%mult]`.
    fn record_field(&mut self) {
        self.b.start_node(FIELD.into());
        self.var_id(); // field name
        self.expect_tok(&Tok::ColonColon);
        self.btype();
        if matches!(self.cur(), Some(Tok::Mult(_))) {
            self.bump();
        }
        self.b.finish_node();
    }

    /// `atype [%mult]` or `( btype [%mult] )`.
    fn positional_field(&mut self) {
        self.b.start_node(FIELD.into());
        if matches!(self.cur(), Some(Tok::LParen)) {
            self.bump(); // (
            self.btype();
            if matches!(self.cur(), Some(Tok::Mult(_))) {
                self.bump();
            }
            self.expect_tok(&Tok::RParen);
        } else {
            self.atype();
            if matches!(self.cur(), Some(Tok::Mult(_))) {
                self.bump();
            }
        }
        self.b.finish_node();
    }

    /// `class Name tyvar where { method :: type ; … }`.
    fn class_decl(&mut self) {
        self.b.start_node(CLASS_DECL.into());
        self.bump(); // class
        self.con_id(); // class name
        self.var_id(); // type variable
        self.expect_tok(&Tok::Where);
        self.block(ExprParser::method_sig);
        self.b.finish_node();
    }

    fn method_sig(&mut self) {
        self.b.start_node(METHOD_SIG.into());
        self.var_id(); // method name
        self.expect_tok(&Tok::ColonColon);
        self.type_();
        self.b.finish_node();
    }

    /// `instance [ctx =>] Class head where { methods }`.
    fn instance_decl(&mut self) {
        self.b.start_node(INSTANCE_DECL.into());
        self.bump(); // instance
        if self.has_fat_arrow() {
            self.b.start_node(CONSTRAINT.into());
            self.btype();
            self.b.finish_node();
            self.expect_tok(&Tok::FatArrow);
        }
        self.con_id(); // class name
        self.atype(); // head type
        self.expect_tok(&Tok::Where);
        self.block(ExprParser::top_decl);
        self.b.finish_node();
    }

    /// `foreign ["lib.so"] name :: type`.
    fn foreign_decl(&mut self) {
        self.b.start_node(FOREIGN_DECL.into());
        self.bump(); // foreign
        if matches!(self.cur(), Some(Tok::Str(_))) {
            self.bump(); // library path
        }
        self.var_id(); // name
        self.expect_tok(&Tok::ColonColon);
        self.type_();
        self.b.finish_node();
    }

    /// `import [qualified] A.B [as C]`.
    fn import_decl(&mut self) {
        self.b.start_node(IMPORT_DECL.into());
        self.bump(); // import
        if matches!(self.cur(), Some(Tok::Qualified)) {
            self.bump();
        }
        self.module_path();
        if matches!(self.cur(), Some(Tok::As)) {
            self.bump(); // as
            self.name_ref(); // alias
        }
        self.b.finish_node();
    }

    /// `module A.B where` — consumes the extra `VLBrace` the layout inserts for the
    /// module body, so the outer block then sees the first real declaration.
    fn module_header(&mut self) {
        self.b.start_node(MODULE_HEADER.into());
        self.bump(); // module
        self.module_path();
        self.expect_tok(&Tok::Where);
        self.eat_v(&LTok::VLBrace);
        self.b.finish_node();
    }

    fn module_path(&mut self) {
        self.name_ref();
        while matches!(self.cur(), Some(Tok::Dot)) {
            self.bump();
            self.name_ref();
        }
    }

    fn name_ref(&mut self) {
        if matches!(self.cur(), Some(Tok::ConId(_) | Tok::VarId(_))) {
            self.bump();
        } else {
            self.ok = false;
        }
    }
}

/// Parse `src` as an expression, token-driven, into a CST. `src` is wrapped as
/// `main = src` and run through the real layout algorithm — identical to the
/// reference — so block forms (`case`/`let`) get their virtual braces. Returns the
/// module root and whether the supported subset consumed all REAL tokens (i.e. the
/// only leftovers are layout-virtual closers).
fn parse_expr_cst(wrapped: &str) -> Option<(SyntaxNode, bool)> {
    let raw = lex(wrapped).ok()?;
    let lines = LineMap::new(wrapped);
    let toks = layout::layout(&raw, &lines);
    let mut p = ExprParser {
        src: wrapped,
        toks: &toks,
        pos: 0,
        cursor: 0,
        b: GreenNodeBuilder::new(),
        ok: true,
        fixities: crate::parser::scan_fixities(&toks),
    };
    p.b.start_node(MODULE.into());
    p.eat_v(&LTok::VLBrace); // outer module block
                             // `main =` — leaves, not nodes, so the body expression is MODULE's only node child.
    if matches!(p.cur(), Some(Tok::VarId(n)) if n == "main") {
        p.bump();
    } else {
        p.ok = false;
    }
    p.expect(&Tok::Equals);
    p.expr(); // the body expression
              // Any remaining REAL token means the subset didn't cover the whole expression.
    let leftover_real = p.toks[p.pos..]
        .iter()
        .any(|s| matches!(s.tok, LTok::Tok(_)));
    let full = p.ok && !leftover_real;
    let end = p.src.len();
    p.trivia(end);
    p.b.finish_node();
    Some((SyntaxNode::new_root(p.b.finish()), full))
}

/// The span of a node measured from its first to its last NON-trivia token — so
/// leading/trailing whitespace woven into the node doesn't shift the offsets. This
/// matches the recursive-descent parser, whose spans start/end on real tokens.
/// Like [`node_span`] but the END is the start of the next non-trivia token in the source
/// (or the node's last-token end at end-of-input) — matching `parser.rs`'s
/// `span_here().0` convention, where a node's span runs up to the *next* token and so
/// includes the trailing whitespace/newlines. Used for productions whose recursive-descent
/// span ends that way (clauses, applied-constructor and tuple patterns).
fn span_to_next_token(node: &SyntaxNode) -> Span {
    let (start, last_end) = node_span(node);
    let last_tok = node
        .descendants_with_tokens()
        .filter_map(|e| e.into_token())
        .filter(|t| !is_trivia(t.kind()))
        .last();
    let end = match last_tok {
        Some(t) => {
            let mut next = t.next_token();
            while let Some(tok) = &next {
                if !is_trivia(tok.kind()) {
                    break;
                }
                next = tok.next_token();
            }
            next.map_or(last_end, |tok| usize::from(tok.text_range().start()))
        }
        None => last_end,
    };
    (start, end)
}

fn node_span(node: &SyntaxNode) -> Span {
    let mut toks = node
        .descendants_with_tokens()
        .filter_map(|e| e.into_token())
        .filter(|t| !is_trivia(t.kind()));
    match toks.next() {
        Some(first) => {
            let last = toks.last().unwrap_or_else(|| first.clone());
            (
                usize::from(first.text_range().start()),
                usize::from(last.text_range().end()),
            )
        }
        None => {
            let r = node.text_range();
            (usize::from(r.start()), usize::from(r.end()))
        }
    }
}

/// The first non-trivia token directly under `node`.
fn head_token(node: &SyntaxNode) -> Option<rowan::SyntaxToken<AxionLang>> {
    node.children_with_tokens()
        .filter_map(|e| e.into_token())
        .find(|t| !is_trivia(t.kind()))
}

fn is_expr_kind(k: SyntaxKind) -> bool {
    matches!(
        k,
        LITERAL_EXPR
            | NAME_EXPR
            | APP_EXPR
            | BINOP_EXPR
            | IF_EXPR
            | LAMBDA_EXPR
            | TUPLE_EXPR
            | PAREN_EXPR
            | LET_EXPR
            | CASE_EXPR
            | RECORD_EXPR
            | LIST_EXPR
            | SECTION_EXPR
            | DO_EXPR
    )
}

/// A lowered `do` statement (mirrors the parser's internal `Stmt`).
enum DoStmt {
    Bind(Pat, Expr),
    Expr(Expr),
}

/// `App(App(head, a), b)` — the shared desugaring shape (`:`, `.`, applied cons…).
fn app2(head: Expr, a: Expr, b: Expr, sp: Span) -> Expr {
    Expr::App(
        Box::new(Expr::App(Box::new(head), Box::new(a), sp)),
        Box::new(b),
        sp,
    )
}

/// The operator NAME of a `BINOP_EXPR` node — the single operator token, or the
/// identifier between backticks for `` x `op` y ``.
fn binop_operator(node: &SyntaxNode) -> Option<String> {
    let toks: Vec<_> = node
        .children_with_tokens()
        .filter_map(|e| e.into_token())
        .filter(|t| !is_trivia(t.kind()))
        .collect();
    if toks.first()?.text() == "`" {
        toks.get(1).map(|t| t.text().to_string())
    } else {
        Some(toks.first()?.text().to_string())
    }
}

/// Lower a CST expression node to `ast::Expr`, re-lexing literal/name leaves for
/// their values and applying the same desugarings as the recursive-descent parser.
fn lower_expr(node: &SyntaxNode) -> Option<Expr> {
    // Compound/block forms and bracketed forms end at the NEXT token (parser.rs uses
    // `(s, span_here().0)` for them); atoms and App/BinOp derive their span otherwise.
    let sp = match node.kind() {
        IF_EXPR | LAMBDA_EXPR | TUPLE_EXPR | RECORD_EXPR | CASE_EXPR | LET_EXPR | DO_EXPR
        | LIST_EXPR | SECTION_EXPR => span_to_next_token(node),
        _ => node_span(node),
    };
    match node.kind() {
        LITERAL_EXPR => {
            let text = head_token(node)?.text().to_string();
            match lex(&text).ok()?.first()?.tok.clone() {
                Tok::Int(IntLit::Small(n)) => Some(Expr::Int(n, sp)),
                Tok::Int(IntLit::Big(d)) => Some(Expr::App(
                    Box::new(Expr::Var("bignumFromStr".into(), sp)),
                    Box::new(Expr::Str(d, sp)),
                    sp,
                )),
                Tok::Float(f) => Some(Expr::Float(f, sp)),
                Tok::Str(s) => Some(Expr::Str(s, sp)),
                _ => None,
            }
        }
        NAME_EXPR => {
            let tok = head_token(node)?;
            let name = tok.text().to_string();
            Some(if tok.kind() == CONID {
                Expr::Con(name, sp)
            } else {
                Expr::Var(name, sp)
            })
        }
        PAREN_EXPR => lower_expr(&node.children().next()?), // parens are transparent
        APP_EXPR => {
            let mut kids = node.children();
            let f = lower_expr(&kids.next()?)?;
            let a = lower_expr(&kids.next()?)?;
            // `parser.rs`: App span = (f.start, arg.end), so a parenthesized argument
            // contributes its *inner* span (parens are transparent).
            let sp = (f.span().0, a.span().1);
            Some(Expr::App(Box::new(f), Box::new(a), sp))
        }
        BINOP_EXPR => {
            let op = binop_operator(node)?;
            let mut kids = node.children();
            let l = lower_expr(&kids.next()?)?;
            let rhs = lower_expr(&kids.next()?)?;
            // `parser.rs`: BinOp span = (lhs.start, rhs.end) — operand-derived.
            let sp = (l.span().0, rhs.span().1);
            // The same desugarings as `parser.rs`: `:`→`Cons`, `.`→`compose`, `$`→app.
            Some(match op.as_str() {
                ":" => app2(Expr::Con("Cons".into(), sp), l, rhs, sp),
                "." => app2(Expr::Var("compose".into(), sp), l, rhs, sp),
                "$" => Expr::App(Box::new(l), Box::new(rhs), sp),
                _ => Expr::BinOp(op, Box::new(l), Box::new(rhs), sp),
            })
        }
        IF_EXPR => {
            let mut kids = node.children();
            let c = lower_expr(&kids.next()?)?;
            let t = lower_expr(&kids.next()?)?;
            let e = lower_expr(&kids.next()?)?;
            Some(Expr::If(Box::new(c), Box::new(t), Box::new(e), sp))
        }
        LAMBDA_EXPR => {
            let mut pats = Vec::new();
            let mut body = None;
            for child in node.children() {
                if is_expr_kind(child.kind()) {
                    body = Some(lower_expr(&child)?);
                } else {
                    pats.push(lower_pat(&child)?);
                }
            }
            Some(Expr::Lam(pats, Box::new(body?), sp))
        }
        TUPLE_EXPR => {
            let es: Option<Vec<Expr>> = node.children().map(|c| lower_expr(&c)).collect();
            Some(Expr::Tuple(es?, sp))
        }
        LIST_EXPR => {
            let elems: Vec<Expr> = node
                .children()
                .map(|c| lower_expr(&c))
                .collect::<Option<_>>()?;
            let is_range = node
                .children_with_tokens()
                .filter_map(|e| e.into_token())
                .any(|t| t.text() == "..");
            if is_range && elems.len() == 2 {
                // `[a..b]` → `range a b`
                let mut it = elems.into_iter();
                Some(app2(
                    Expr::Var("range".into(), sp),
                    it.next()?,
                    it.next()?,
                    sp,
                ))
            } else {
                // `[e1, …]` → `Cons e1 (Cons … Nil)`; `[]` → `Nil`.
                let mut list = Expr::Con("Nil".into(), sp);
                for e in elems.into_iter().rev() {
                    list = app2(Expr::Con("Cons".into(), sp), e, list, sp);
                }
                Some(list)
            }
        }
        SECTION_EXPR => {
            // `(op)` → `\_op0 _op1 -> _op0 op _op1`
            let op = node
                .children_with_tokens()
                .filter_map(|e| e.into_token())
                .filter(|t| !is_trivia(t.kind()))
                .nth(1)? // between '(' and ')'
                .text()
                .to_string();
            let body = Expr::BinOp(
                op,
                Box::new(Expr::Var("_op0".into(), sp)),
                Box::new(Expr::Var("_op1".into(), sp)),
                sp,
            );
            Some(Expr::Lam(
                vec![Pat::Var("_op0".into(), sp), Pat::Var("_op1".into(), sp)],
                Box::new(body),
                sp,
            ))
        }
        RECORD_EXPR => {
            let base = lower_expr(&node.children().next()?)?;
            let mut fields = Vec::new();
            let mut pending: Option<String> = None;
            for el in node.children_with_tokens() {
                match el {
                    rowan::NodeOrToken::Token(t) if t.kind() == IDENT => {
                        pending = Some(t.text().to_string());
                    }
                    rowan::NodeOrToken::Node(n) if is_expr_kind(n.kind()) => {
                        if let Some(name) = pending.take() {
                            fields.push((name, lower_expr(&n)?));
                        }
                    }
                    _ => {}
                }
            }
            Some(match base {
                Expr::Con(name, _) => Expr::RecordCon(name, fields, sp),
                other => Expr::RecordUpd(Box::new(other), fields, sp),
            })
        }
        CASE_EXPR => {
            let mut kids = node.children();
            let scrut = lower_expr(&kids.next()?)?;
            let mut arms = Vec::new();
            while let Some(pnode) = kids.next() {
                let enode = kids.next()?;
                arms.push((lower_pat(&pnode)?, lower_expr(&enode)?));
            }
            Some(Expr::Case(Box::new(scrut), arms, sp))
        }
        LET_EXPR => {
            let funcs = assemble_funcs(node.children())?;
            let body = lower_expr(&node.children().find(|c| is_expr_kind(c.kind()))?)?;
            Some(Expr::Let(funcs, Box::new(body), sp))
        }
        DO_EXPR => {
            // Desugar strictly via `case` (same as `parser::parse_do`): `pat <- e;
            // rest` → `case e of pat -> rest`; `e; rest` → `case e of _ -> rest`;
            // the last statement is the block's value.
            let stmts: Vec<DoStmt> = node
                .children()
                .map(|c| lower_stmt(&c))
                .collect::<Option<_>>()?;
            let mut it = stmts.into_iter().rev();
            let mut acc = match it.next()? {
                DoStmt::Expr(e) => e,
                DoStmt::Bind(..) => return None, // a `do` block can't end in `<-`
            };
            for stmt in it {
                let (pat, e) = match stmt {
                    DoStmt::Bind(p, e) => (p, e),
                    DoStmt::Expr(e) => (Pat::Wild(sp), e),
                };
                acc = Expr::Case(Box::new(e), vec![(pat, acc)], sp);
            }
            Some(acc)
        }
        _ => None,
    }
}

fn lower_stmt(node: &SyntaxNode) -> Option<DoStmt> {
    match node.kind() {
        BIND_STMT => {
            let pat = node.children().find(|c| !is_expr_kind(c.kind()))?;
            let e = node.children().find(|c| is_expr_kind(c.kind()))?;
            Some(DoStmt::Bind(lower_pat(&pat)?, lower_expr(&e)?))
        }
        EXPR_STMT => Some(DoStmt::Expr(lower_expr(&node.children().next()?)?)),
        _ => None,
    }
}

/// Lower a CST pattern node to `ast::Pat`.
fn lower_pat(node: &SyntaxNode) -> Option<Pat> {
    let sp = node_span(node);
    match node.kind() {
        WILD_PAT => Some(Pat::Wild(sp)),
        VAR_PAT => Some(Pat::Var(head_token(node)?.text().to_string(), sp)),
        LIT_PAT => {
            let tok = head_token(node)?;
            match lex(tok.text()).ok()?.first()?.tok {
                Tok::Int(IntLit::Small(n)) => Some(Pat::Int(n, sp)),
                _ => None,
            }
        }
        CON_PAT => {
            let name = head_token(node)?.text().to_string();
            let args: Vec<Pat> = node
                .children()
                .map(|c| lower_pat(&c))
                .collect::<Option<_>>()?;
            // `parser.rs`: an APPLIED constructor (only produced by `parse_pat`) spans to
            // the next token. A NULLARY constructor spans to the next token only in
            // *pattern* position (a `case` arm or a tuple element, both `parse_pat`); as a
            // clause/lambda parameter or a constructor argument (`parse_apat`) it is just
            // its token.
            let pattern_pos =
                matches!(node.parent().map(|p| p.kind()), Some(CASE_EXPR | TUPLE_PAT));
            let sp = if args.is_empty() && !pattern_pos {
                node_span(node)
            } else {
                span_to_next_token(node)
            };
            Some(Pat::Con(name, args, sp))
        }
        TUPLE_PAT => {
            let mut ps: Vec<Pat> = node
                .children()
                .map(|c| lower_pat(&c))
                .collect::<Option<_>>()?;
            if ps.len() == 1 {
                ps.pop()
            } else {
                Some(Pat::Tuple(ps, span_to_next_token(node)))
            }
        }
        _ => None,
    }
}

/// Zero every span in an expression, so two ASTs can be compared for STRUCTURAL
/// equality (the token-driven parser and the recursive-descent parser number spans
/// from different origins).
fn zero_spans(e: &mut Expr) {
    let z = (0usize, 0usize);
    match e {
        Expr::Int(_, s)
        | Expr::Float(_, s)
        | Expr::Str(_, s)
        | Expr::Var(_, s)
        | Expr::Con(_, s) => {
            *s = z;
        }
        Expr::App(a, b, s) | Expr::BinOp(_, a, b, s) => {
            *s = z;
            zero_spans(a);
            zero_spans(b);
        }
        Expr::If(a, b, c, s) => {
            *s = z;
            zero_spans(a);
            zero_spans(b);
            zero_spans(c);
        }
        Expr::Tuple(es, s) => {
            *s = z;
            es.iter_mut().for_each(zero_spans);
        }
        Expr::Lam(pats, b, s) => {
            *s = z;
            pats.iter_mut().for_each(zero_pat);
            zero_spans(b);
        }
        Expr::Let(funcs, b, s) => {
            *s = z;
            funcs.iter_mut().for_each(zero_func);
            zero_spans(b);
        }
        Expr::Case(sc, arms, s) => {
            *s = z;
            zero_spans(sc);
            arms.iter_mut().for_each(|(p, e)| {
                zero_pat(p);
                zero_spans(e);
            });
        }
        Expr::RecordCon(_, fs, s) => {
            *s = z;
            fs.iter_mut().for_each(|(_, e)| zero_spans(e));
        }
        Expr::RecordUpd(b, fs, s) => {
            *s = z;
            zero_spans(b);
            fs.iter_mut().for_each(|(_, e)| zero_spans(e));
        }
    }
}

fn zero_pat(p: &mut Pat) {
    let z = (0usize, 0usize);
    match p {
        Pat::Wild(s) | Pat::Var(_, s) | Pat::Int(_, s) => *s = z,
        Pat::Con(_, ps, s) | Pat::Tuple(ps, s) => {
            *s = z;
            ps.iter_mut().for_each(zero_pat);
        }
    }
}

/// Zero the spans of a `let`/`where` binding (its clauses' patterns and bodies).
fn zero_func(f: &mut Func) {
    f.span = (0, 0);
    for c in &mut f.clauses {
        c.span = (0, 0);
        c.pats.iter_mut().for_each(zero_pat);
        match &mut c.body {
            Body::Plain(e) => zero_spans(e),
            Body::Guarded(arms) => arms.iter_mut().for_each(|(g, r)| {
                zero_spans(g);
                zero_spans(r);
            }),
        }
        c.wher.iter_mut().for_each(zero_func);
    }
}

/// The recursive-descent parser's `ast::Expr` for the expression `src` (wrapped as
/// `main = src`), spans zeroed.
fn parser_expr(src: &str) -> Option<Expr> {
    let wrapped = format!("main = {src}\n");
    let toks = lex(&wrapped).ok()?;
    let lines = LineMap::new(&wrapped);
    let lt = crate::layout::layout(&toks, &lines);
    let (module, _errs) = crate::parser::parse_module_resilient(&lt);
    let main = module.funcs.iter().find(|f| f.name == "main")?;
    match &main.clauses.first()?.body {
        crate::ast::Body::Plain(e) => {
            let mut e = e.clone();
            zero_spans(&mut e);
            Some(e)
        }
        crate::ast::Body::Guarded(_) => None,
    }
}

/// Whether the token-driven CST parser + lowering reproduces the recursive-descent
/// parser's AST for the expression `src` (structurally, spans ignored). Used by the
/// differential test that gates the pipeline flip. `false` when `src` uses a
/// construct outside the supported subset (so the corpus stays honest).
pub fn expr_matches_parser(src: &str) -> bool {
    let wrapped = format!("main = {src}\n");
    let Some((cst, full)) = parse_expr_cst(&wrapped) else {
        return false;
    };
    if !full {
        return false;
    }
    let Some(node) = cst.children().next() else {
        return false;
    };
    let Some(mut lowered) = lower_expr(&node) else {
        return false;
    };
    zero_spans(&mut lowered);
    parser_expr(src).is_some_and(|expected| expected == lowered)
}

// === Stage 3f: types + declarations → ast::Module, and the module differential ===

fn is_type_kind(k: SyntaxKind) -> bool {
    matches!(
        k,
        TYPE_CON | TYPE_VAR | TYPE_APP | TYPE_ARROW | TYPE_TUPLE | TYPE_UNIT
    )
}

fn mult_of(text: &str) -> crate::ast::Mult {
    match text.trim_start_matches('%') {
        "1" => crate::ast::Mult::One,
        "0.5" => crate::ast::Mult::Half,
        _ => crate::ast::Mult::Many,
    }
}

fn lower_type(node: &SyntaxNode) -> Option<crate::ast::Type> {
    use crate::ast::Type;
    match node.kind() {
        TYPE_CON => Some(Type::Con(head_token(node)?.text().to_string())),
        TYPE_VAR => Some(Type::Var(head_token(node)?.text().to_string())),
        TYPE_UNIT => Some(Type::Unit),
        TYPE_APP => {
            let mut kids = node.children();
            let f = lower_type(&kids.next()?)?;
            let a = lower_type(&kids.next()?)?;
            Some(Type::App(Box::new(f), Box::new(a)))
        }
        TYPE_TUPLE => {
            let ts: Option<Vec<Type>> = node.children().map(|c| lower_type(&c)).collect();
            Some(Type::Tuple(ts?))
        }
        TYPE_ARROW => {
            let mult = node
                .children_with_tokens()
                .filter_map(|e| e.into_token())
                .find(|t| t.text().starts_with('%'))
                .map_or(crate::ast::Mult::Many, |t| mult_of(t.text()));
            let mut kids = node.children();
            let from = lower_type(&kids.next()?)?;
            let to = lower_type(&kids.next()?)?;
            Some(Type::Arrow {
                mult,
                from: Box::new(from),
                to: Box::new(to),
            })
        }
        _ => None,
    }
}

/// `(class, var)` pairs from a constraint context type (`Eq a` → `[(Eq, a)]`,
/// `(Eq a, Ord b)` → both), mirroring `parser::context_constraints`.
fn constraints_of(t: &crate::ast::Type) -> Vec<(String, String)> {
    use crate::ast::Type;
    let mut out = Vec::new();
    fn one(t: &Type, out: &mut Vec<(String, String)>) {
        match t {
            Type::App(f, a) => {
                if let (Some(c), Type::Var(v)) = (f.head_con(), a.as_ref()) {
                    out.push((c.to_string(), v.clone()));
                }
            }
            Type::Tuple(ts) => ts.iter().for_each(|x| one(x, out)),
            _ => {}
        }
    }
    one(t, &mut out);
    out
}

/// `(name, class constraints, type)` of a signature.
type SigParts = (String, Vec<(String, String)>, crate::ast::Type);

fn lower_sig(node: &SyntaxNode) -> Option<SigParts> {
    let name = node
        .children_with_tokens()
        .filter_map(|e| e.into_token())
        .find(|t| matches!(t.kind(), IDENT | OPER))?
        .text()
        .to_string();
    let constraints = node
        .children()
        .find(|c| c.kind() == CONSTRAINT)
        .and_then(|c| lower_type(&c.children().next()?))
        .map(|t| constraints_of(&t))
        .unwrap_or_default();
    let ty_node = node.children().find(|c| is_type_kind(c.kind()))?;
    Some((name, constraints, lower_type(&ty_node)?))
}

fn lower_clause(node: &SyntaxNode) -> Option<(String, Clause)> {
    let sp = span_to_next_token(node);
    let name = node
        .children_with_tokens()
        .filter_map(|e| e.into_token())
        .find(|t| matches!(t.kind(), IDENT | OPER))?
        .text()
        .to_string();
    let mut pats = Vec::new();
    let mut guards: Vec<(Expr, Expr)> = Vec::new();
    let mut plain: Option<Expr> = None;
    let mut wher: Vec<Func> = Vec::new();
    for c in node.children() {
        match c.kind() {
            GUARD => {
                let mut g = c.children();
                guards.push((lower_expr(&g.next()?)?, lower_expr(&g.next()?)?));
            }
            WHERE => wher = assemble_funcs(c.children())?,
            k if is_expr_kind(k) => plain = Some(lower_expr(&c)?),
            _ => pats.push(lower_pat(&c)?),
        }
    }
    let body = if guards.is_empty() {
        Body::Plain(plain?)
    } else {
        Body::Guarded(guards)
    };
    Some((
        name,
        Clause {
            pats,
            body,
            wher,
            span: sp,
        },
    ))
}

/// The non-trivia tokens directly under `node` (not inside a child node).
fn direct_tokens(node: &SyntaxNode) -> impl Iterator<Item = rowan::SyntaxToken<AxionLang>> + '_ {
    node.children_with_tokens()
        .filter_map(|e| e.into_token())
        .filter(|t| !is_trivia(t.kind()))
}

fn first_kind_token(node: &SyntaxNode, kind: SyntaxKind) -> Option<String> {
    direct_tokens(node)
        .find(|t| t.kind() == kind)
        .map(|t| t.text().to_string())
}

/// Assemble a run of `SIG`/`FUN_CLAUSE` nodes into `Func`s by name and first-mention
/// order, exactly as `parser::assemble` does. Shared by the module and instance bodies.
fn assemble_funcs(decls: impl Iterator<Item = SyntaxNode>) -> Option<Vec<Func>> {
    let mut funcs: Vec<Func> = Vec::new();
    let mut index: std::collections::HashMap<String, usize> = std::collections::HashMap::new();
    for decl in decls {
        let name = match decl.kind() {
            SIG => lower_sig(&decl)?.0,
            FUN_CLAUSE => lower_clause(&decl)?.0,
            _ => continue,
        };
        let i = *index.entry(name.clone()).or_insert_with(|| {
            funcs.push(Func {
                name: name.clone(),
                sig: None,
                clauses: Vec::new(),
                span: (0, 0),
                constraints: Vec::new(),
            });
            funcs.len() - 1
        });
        match decl.kind() {
            SIG => {
                let (_, constraints, ty) = lower_sig(&decl)?;
                funcs[i].sig = Some(ty);
                funcs[i].constraints = constraints;
            }
            FUN_CLAUSE => {
                // `Func.span` mirrors `parser::assemble`: the first clause's span.
                let clause = lower_clause(&decl)?.1;
                if funcs[i].span == (0, 0) {
                    funcs[i].span = clause.span;
                }
                funcs[i].clauses.push(clause);
            }
            _ => {}
        }
    }
    Some(funcs)
}

/// Lower a token-driven module CST to `ast::Module`.
fn lower_module(cst: &SyntaxNode) -> Option<crate::ast::Module> {
    use crate::ast;
    let funcs = assemble_funcs(cst.children())?;
    let mut m = ast::Module {
        name: None,
        imports: Vec::new(),
        funcs,
        datas: Vec::new(),
        foreigns: Vec::new(),
        classes: Vec::new(),
        instances: Vec::new(),
        level_ceiling: None,
    };
    for decl in cst.children() {
        match decl.kind() {
            DATA_DECL => m.datas.push(lower_data(&decl)?),
            CLASS_DECL => m.classes.push(lower_class(&decl)?),
            INSTANCE_DECL => m.instances.push(lower_instance(&decl)?),
            FOREIGN_DECL => m.foreigns.push(lower_foreign(&decl)?),
            IMPORT_DECL => m.imports.push(lower_import(&decl)),
            MODULE_HEADER => m.name = Some(lower_module_name(&decl)),
            _ => {}
        }
    }
    Some(m)
}

fn lower_data(node: &SyntaxNode) -> Option<crate::ast::DataDecl> {
    let mut name = None;
    let mut params = Vec::new();
    let mut deriving = Vec::new();
    let mut seen_eq = false;
    let mut in_deriving = false;
    for t in direct_tokens(node) {
        let text = t.text();
        if !seen_eq {
            match t.kind() {
                CONID if name.is_none() => name = Some(text.to_string()),
                IDENT => params.push(text.to_string()),
                PUNCT if text == "=" => seen_eq = true,
                _ => {}
            }
        } else if in_deriving {
            if t.kind() == CONID {
                deriving.push(text.to_string());
            }
        } else if t.kind() == IDENT && text == "deriving" {
            in_deriving = true;
        }
    }
    let cons: Option<Vec<_>> = node
        .children()
        .filter(|c| c.kind() == CON_DECL)
        .map(|c| lower_con(&c))
        .collect();
    Some(crate::ast::DataDecl {
        name: name?,
        params,
        cons: cons?,
        deriving,
        span: span_to_next_token(node),
    })
}

fn lower_con(node: &SyntaxNode) -> Option<crate::ast::ConDecl> {
    let name = first_kind_token(node, CONID)?;
    let fields: Option<Vec<_>> = node
        .children()
        .filter(|c| c.kind() == FIELD)
        .map(|c| lower_field(&c))
        .collect();
    Some(crate::ast::ConDecl {
        name,
        fields: fields?,
    })
}

fn lower_field(node: &SyntaxNode) -> Option<crate::ast::Field> {
    let name = first_kind_token(node, IDENT).unwrap_or_default(); // "" for positional
    let ty = lower_type(&node.children().find(|c| is_type_kind(c.kind()))?)?;
    let mult = direct_tokens(node)
        .find(|t| t.text().starts_with('%'))
        .map_or(crate::ast::Mult::Many, |t| mult_of(t.text()));
    Some(crate::ast::Field { name, ty, mult })
}

fn lower_class(node: &SyntaxNode) -> Option<crate::ast::ClassDecl> {
    let name = first_kind_token(node, CONID)?;
    let tyvar = first_kind_token(node, IDENT)?;
    let methods: Option<Vec<_>> = node
        .children()
        .filter(|c| c.kind() == METHOD_SIG)
        .map(|m| {
            let mname = first_kind_token(&m, IDENT)?;
            let ty = lower_type(&m.children().find(|c| is_type_kind(c.kind()))?)?;
            Some((mname, ty))
        })
        .collect();
    Some(crate::ast::ClassDecl {
        name,
        tyvar,
        methods: methods?,
        span: span_to_next_token(node),
    })
}

fn lower_instance(node: &SyntaxNode) -> Option<crate::ast::InstanceDecl> {
    let constraints = node
        .children()
        .find(|c| c.kind() == CONSTRAINT)
        .and_then(|c| lower_type(&c.children().next()?))
        .map(|t| constraints_of(&t))
        .unwrap_or_default();
    let class_name = first_kind_token(node, CONID)?;
    let head_ty = lower_type(&node.children().find(|c| is_type_kind(c.kind()))?)?;
    let ty_head = head_ty.head_con()?.to_string();
    let methods = assemble_funcs(node.children())?;
    Some(crate::ast::InstanceDecl {
        class_name,
        ty_head,
        head_ty,
        constraints,
        methods,
        span: span_to_next_token(node),
    })
}

fn lower_foreign(node: &SyntaxNode) -> Option<crate::ast::Foreign> {
    let lib = direct_tokens(node)
        .find(|t| t.kind() == LITERAL)
        .and_then(|t| match lex(t.text()).ok()?.first()?.tok.clone() {
            Tok::Str(s) => Some(s),
            _ => None,
        });
    let name = first_kind_token(node, IDENT)?;
    let sig = lower_type(&node.children().find(|c| is_type_kind(c.kind()))?)?;
    Some(crate::ast::Foreign {
        name,
        sig,
        lib,
        span: span_to_next_token(node),
    })
}

fn lower_import(node: &SyntaxNode) -> crate::ast::ImportDecl {
    let qualified = direct_tokens(node).any(|t| t.text() == "qualified");
    let mut module = Vec::new();
    let mut alias = None;
    let mut after_as = false;
    for t in direct_tokens(node) {
        match t.text() {
            "import" | "qualified" | "." => {}
            "as" => after_as = true,
            _ if matches!(t.kind(), IDENT | CONID) => {
                if after_as {
                    alias = Some(t.text().to_string());
                } else {
                    module.push(t.text().to_string());
                }
            }
            _ => {}
        }
    }
    crate::ast::ImportDecl {
        module,
        qualified,
        alias,
        span: (0, 0),
    }
}

fn lower_module_name(node: &SyntaxNode) -> Vec<String> {
    direct_tokens(node)
        .filter(|t| matches!(t.kind(), IDENT | CONID))
        .map(|t| t.text().to_string())
        .collect()
}

/// Parse a whole module via the token-driven parser and lower it to `ast::Module`,
/// returning `Some` only when the ENTIRE input parsed within the grammar (no leftover
/// real tokens). This is the primary parse path the pipeline is flipped onto; a
/// malformed file yields `None`, and the caller falls back to the recursive-descent
/// parser for error reporting and declaration-level recovery.
pub fn parse_module_full(src: &str) -> Option<crate::ast::Module> {
    let (cst, full) = parse_module_cst(src);
    if !full {
        return None;
    }
    lower_module(&cst)
}

fn parse_module_cst(src: &str) -> (SyntaxNode, bool) {
    // Recovering lex: illegal characters are skipped (they survive as trivia) instead of
    // aborting, so `parse_recover` stays useful on a buffer with a stray bad character.
    let (raw, lex_errs) = crate::lexer::lex_recover(src);
    let lines = LineMap::new(src);
    let toks = layout::layout(&raw, &lines);
    let mut p = ExprParser {
        src,
        toks: &toks,
        pos: 0,
        cursor: 0,
        b: GreenNodeBuilder::new(),
        ok: true,
        fixities: crate::parser::scan_fixities(&toks),
    };
    p.b.start_node(MODULE.into());
    p.block(ExprParser::top_decl);
    let leftover_real = p.toks[p.pos..]
        .iter()
        .any(|s| matches!(s.tok, LTok::Tok(_)));
    // A lex error makes the parse non-`full`, so `module_matches_parser` (the flip's
    // differential gate) still demands a completely clean parse.
    let full = p.ok && !leftover_real && lex_errs.is_empty();
    p.trivia(src.len());
    p.b.finish_node();
    (SyntaxNode::new_root(p.b.finish()), full)
}

fn zero_module(m: &mut crate::ast::Module) {
    m.funcs.iter_mut().for_each(zero_func);
    m.datas.iter_mut().for_each(|d| d.span = (0, 0));
    m.classes.iter_mut().for_each(|c| c.span = (0, 0));
    m.foreigns.iter_mut().for_each(|f| f.span = (0, 0));
    m.imports.iter_mut().for_each(|i| i.span = (0, 0));
    for inst in &mut m.instances {
        inst.span = (0, 0);
        inst.methods.iter_mut().for_each(zero_func);
    }
}

/// Whether the token-driven module parser + lowering reproduces the recursive-descent
/// parser's `ast::Module` for `src` (structurally, spans ignored). The gate that will
/// authorise flipping the pipeline onto the CST. `false` for modules using constructs
/// outside the current subset (declarations other than functions/signatures).
pub fn module_matches_parser(src: &str) -> bool {
    let (cst, full) = parse_module_cst(src);
    if !full {
        return false;
    }
    let Some(mut got) = lower_module(&cst) else {
        return false;
    };
    zero_module(&mut got);

    let Ok(raw) = lex(src) else { return false };
    let lines = LineMap::new(src);
    let lt = layout::layout(&raw, &lines);
    let (mut expected, _errs) = crate::parser::parse_module_resilient(&lt);
    zero_module(&mut expected);

    got == expected
}

/// Collect every AST node's `(kind, span)` in pre-order (same traversal for both parsers,
/// so the two lists align since the trees are structurally identical). Used to pinpoint
/// the first span that differs between the token-driven and recursive-descent ASTs.
fn collect_module_spans(m: &crate::ast::Module) -> Vec<(&'static str, crate::ast::Span)> {
    let mut out = Vec::new();
    for f in &m.funcs {
        for c in &f.clauses {
            collect_clause_spans(c, &mut out);
        }
    }
    // Declaration-level spans are semantic too (diagnostics render them — e.g. AX0400 on
    // an instance), so the exactness gate must cover them.
    for d in &m.datas {
        out.push(("Data", d.span));
    }
    for c in &m.classes {
        out.push(("Class", c.span));
    }
    for i in &m.instances {
        out.push(("Instance", i.span));
        for meth in &i.methods {
            for c in &meth.clauses {
                collect_clause_spans(c, &mut out);
            }
        }
    }
    for fo in &m.foreigns {
        out.push(("Foreign", fo.span));
    }
    out
}

fn collect_clause_spans(c: &crate::ast::Clause, out: &mut Vec<(&'static str, crate::ast::Span)>) {
    for p in &c.pats {
        collect_pat_spans(p, out);
    }
    out.push(("Clause", c.span));
    match &c.body {
        crate::ast::Body::Plain(e) => collect_expr_spans(e, out),
        crate::ast::Body::Guarded(arms) => {
            for (g, r) in arms {
                collect_expr_spans(g, out);
                collect_expr_spans(r, out);
            }
        }
    }
    for w in &c.wher {
        for wc in &w.clauses {
            collect_clause_spans(wc, out);
        }
    }
}

fn collect_pat_spans(p: &crate::ast::Pat, out: &mut Vec<(&'static str, crate::ast::Span)>) {
    use crate::ast::Pat;
    match p {
        Pat::Wild(s) => out.push(("Wild", *s)),
        Pat::Var(_, s) => out.push(("PatVar", *s)),
        Pat::Int(_, s) => out.push(("PatInt", *s)),
        Pat::Con(_, ps, s) => {
            out.push(("PatCon", *s));
            for sub in ps {
                collect_pat_spans(sub, out);
            }
        }
        Pat::Tuple(ps, s) => {
            out.push(("PatTuple", *s));
            for sub in ps {
                collect_pat_spans(sub, out);
            }
        }
    }
}

fn collect_expr_spans(e: &crate::ast::Expr, out: &mut Vec<(&'static str, crate::ast::Span)>) {
    use crate::ast::Expr;
    match e {
        Expr::Int(_, s) => out.push(("Int", *s)),
        Expr::Float(_, s) => out.push(("Float", *s)),
        Expr::Str(_, s) => out.push(("Str", *s)),
        Expr::Var(_, s) => out.push(("Var", *s)),
        Expr::Con(_, s) => out.push(("Con", *s)),
        Expr::App(f, x, s) => {
            out.push(("App", *s));
            collect_expr_spans(f, out);
            collect_expr_spans(x, out);
        }
        Expr::BinOp(_, a, b, s) => {
            out.push(("BinOp", *s));
            collect_expr_spans(a, out);
            collect_expr_spans(b, out);
        }
        Expr::If(c, t, el, s) => {
            out.push(("If", *s));
            collect_expr_spans(c, out);
            collect_expr_spans(t, out);
            collect_expr_spans(el, out);
        }
        Expr::Let(funcs, body, s) => {
            out.push(("Let", *s));
            for f in funcs {
                for c in &f.clauses {
                    collect_clause_spans(c, out);
                }
            }
            collect_expr_spans(body, out);
        }
        Expr::Case(scrut, arms, s) => {
            out.push(("Case", *s));
            collect_expr_spans(scrut, out);
            for (p, r) in arms {
                collect_pat_spans(p, out);
                collect_expr_spans(r, out);
            }
        }
        Expr::Tuple(es, s) => {
            out.push(("Tuple", *s));
            for e in es {
                collect_expr_spans(e, out);
            }
        }
        Expr::RecordCon(_, fields, s) => {
            out.push(("RecordCon", *s));
            for (_, e) in fields {
                collect_expr_spans(e, out);
            }
        }
        Expr::RecordUpd(base, fields, s) => {
            out.push(("RecordUpd", *s));
            collect_expr_spans(base, out);
            for (_, e) in fields {
                collect_expr_spans(e, out);
            }
        }
        Expr::Lam(ps, body, s) => {
            out.push(("Lam", *s));
            for p in ps {
                collect_pat_spans(p, out);
            }
            collect_expr_spans(body, out);
        }
    }
}

/// The first node whose span differs between the token-driven and recursive-descent
/// ASTs, rendered as `kind got(a,b)="text" exp(c,d)="text"` — the precise target for a
/// span fix. `None` when the two are byte-identical (the flip gate). Diagnostic helper.
pub fn first_span_mismatch(src: &str) -> Option<String> {
    let (cst, full) = parse_module_cst(src);
    if !full {
        return Some("<not full>".to_string());
    }
    let got = lower_module(&cst)?;
    let Ok(raw) = lex(src) else { return None };
    let lines = LineMap::new(src);
    let lt = layout::layout(&raw, &lines);
    let (expected, _errs) = crate::parser::parse_module_resilient(&lt);
    let gs = collect_module_spans(&got);
    let es = collect_module_spans(&expected);
    let text = |sp: (usize, usize)| src.get(sp.0..sp.1).unwrap_or("<oob>").to_string();
    for (i, (gk, gsp)) in gs.iter().enumerate() {
        match es.get(i) {
            Some((_, esp)) if gsp == esp => {}
            Some((ek, esp)) => {
                return Some(format!(
                    "{gk}/{ek} got{gsp:?}={:?} exp{esp:?}={:?}",
                    text(*gsp),
                    text(*esp)
                ));
            }
            None => return Some(format!("{gk}/<none> got{gsp:?}={:?}", text(*gsp))),
        }
    }
    None
}

/// Span-EXACT differential: the token-driven AST vs recursive-descent, spans NOT zeroed.
/// `None` when byte-identical; otherwise the two `Debug` renderings (for locating the
/// first differing span). The gate that must pass over every fixture before the flip.
pub fn module_exact_diff(src: &str) -> Option<(String, String)> {
    let (cst, full) = parse_module_cst(src);
    if !full {
        return Some(("<not full>".to_string(), String::new()));
    }
    let Some(got) = lower_module(&cst) else {
        return Some(("<lower failed>".to_string(), String::new()));
    };
    let Ok(raw) = lex(src) else {
        return Some(("<lex failed>".to_string(), String::new()));
    };
    let lines = LineMap::new(src);
    let lt = layout::layout(&raw, &lines);
    let (expected, _errs) = crate::parser::parse_module_resilient(&lt);
    if got == expected {
        None
    } else {
        Some((format!("{got:#?}"), format!("{expected:#?}")))
    }
}
