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
    // pattern nodes
    WILD_PAT,
    VAR_PAT,
    LIT_PAT,
    CON_PAT,
    TUPLE_PAT,
}

use SyntaxKind::{
    APP_EXPR, BINOP_EXPR, CASE_EXPR, COMMENT, CON_PAT, CONID, DECL, ERROR, IDENT, IF_EXPR, KEYWORD,
    LAMBDA_EXPR, LET_EXPR, LITERAL, LITERAL_EXPR, LIT_PAT, MODULE, NAME_EXPR, PAREN_EXPR, PUNCT,
    RECORD_EXPR, TUPLE_EXPR, TUPLE_PAT, VAR_PAT, WHITESPACE, WILD_PAT,
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
            WILD_PAT,
            VAR_PAT,
            LIT_PAT,
            CON_PAT,
            TUPLE_PAT,
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
        Expr::RecordCon(_, fields, _) => {
            (RECORD_EXPR, fields.iter().map(|(_, e)| expr_outline(e)).collect())
        }
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
            let kind = if text.contains("--") { COMMENT } else { WHITESPACE };
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
    let toks = lex(src).unwrap_or_default();
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
    toks: &'a [Spanned],
    pos: usize,
    cursor: usize,
    b: GreenNodeBuilder<'static>,
    ok: bool,
}

impl ExprParser<'_> {
    fn cur(&self) -> Option<&Tok> {
        self.toks.get(self.pos).map(|s| &s.tok)
    }

    fn trivia(&mut self, to: usize) {
        let text = self.src.get(self.cursor..to).unwrap_or("");
        if !text.is_empty() {
            let kind = if text.contains("--") { COMMENT } else { WHITESPACE };
            self.b.token(kind.into(), text);
        }
        self.cursor = to;
    }

    /// Emit the current token (with its leading trivia) as a leaf and advance.
    fn bump(&mut self) {
        if let Some(t) = self.toks.get(self.pos) {
            if t.start > self.cursor {
                self.trivia(t.start);
            }
            let text = self.src.get(t.start..t.end).unwrap_or("");
            self.b.token(token_kind(&t.tok).into(), text);
            self.cursor = t.end;
            self.pos += 1;
        }
    }

    fn expr(&mut self) {
        self.cmp();
    }

    fn cmp(&mut self) {
        let cp = self.b.checkpoint();
        self.add();
        while matches!(self.cur(), Some(Tok::EqEq | Tok::Lt | Tok::Gt)) {
            self.b.start_node_at(cp, BINOP_EXPR.into());
            self.bump();
            self.add();
            self.b.finish_node();
        }
    }

    fn add(&mut self) {
        let cp = self.b.checkpoint();
        self.mul();
        while matches!(self.cur(), Some(Tok::Plus | Tok::Minus)) {
            self.b.start_node_at(cp, BINOP_EXPR.into());
            self.bump();
            self.mul();
            self.b.finish_node();
        }
    }

    fn mul(&mut self) {
        let cp = self.b.checkpoint();
        self.app();
        while matches!(self.cur(), Some(Tok::Star)) {
            self.b.start_node_at(cp, BINOP_EXPR.into());
            self.bump();
            self.app();
            self.b.finish_node();
        }
    }

    fn app(&mut self) {
        let cp = self.b.checkpoint();
        self.atom();
        while self.starts_atom() {
            self.b.start_node_at(cp, APP_EXPR.into());
            self.atom();
            self.b.finish_node();
        }
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
            )
        )
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
                self.b.start_node(PAREN_EXPR.into());
                self.bump(); // '('
                self.expr();
                if matches!(self.cur(), Some(Tok::RParen)) {
                    self.bump(); // ')'
                } else {
                    self.ok = false;
                }
                self.b.finish_node();
            }
            _ => self.ok = false,
        }
    }
}

/// Parse `src` as a single expression, token-driven, into a CST. Returns the root
/// `SyntaxNode` and whether the whole input was consumed by the supported subset.
fn parse_expr_cst(src: &str) -> Option<(SyntaxNode, bool)> {
    let toks = lex(src).ok()?;
    let mut p = ExprParser {
        src,
        toks: &toks,
        pos: 0,
        cursor: 0,
        b: GreenNodeBuilder::new(),
        ok: true,
    };
    p.b.start_node(MODULE.into());
    p.expr();
    let full = p.ok && p.pos == p.toks.len();
    let end = p.src.len();
    p.trivia(end);
    p.b.finish_node();
    Some((SyntaxNode::new_root(p.b.finish()), full))
}

/// The first non-trivia token directly under `node`.
fn head_token(node: &SyntaxNode) -> Option<rowan::SyntaxToken<AxionLang>> {
    node.children_with_tokens()
        .filter_map(|e| e.into_token())
        .find(|t| !is_trivia(t.kind()))
}

/// Lower a CST expression node to `ast::Expr`, re-lexing literal/name leaves for
/// their values so the result matches the recursive-descent parser.
fn lower_expr(node: &SyntaxNode) -> Option<Expr> {
    let r = node.text_range();
    let sp = (usize::from(r.start()), usize::from(r.end()));
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
            Some(Expr::App(Box::new(f), Box::new(a), sp))
        }
        BINOP_EXPR => {
            let op = head_token(node)?.text().to_string();
            let mut kids = node.children();
            let l = lower_expr(&kids.next()?)?;
            let rhs = lower_expr(&kids.next()?)?;
            Some(Expr::BinOp(op, Box::new(l), Box::new(rhs), sp))
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
        Expr::Int(_, s) | Expr::Float(_, s) | Expr::Str(_, s) | Expr::Var(_, s) | Expr::Con(_, s) => {
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
        Expr::Lam(_, b, s) | Expr::Let(_, b, s) => {
            *s = z;
            zero_spans(b);
        }
        Expr::Case(sc, arms, s) => {
            *s = z;
            zero_spans(sc);
            arms.iter_mut().for_each(|(_, e)| zero_spans(e));
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
    let Some((cst, full)) = parse_expr_cst(src) else {
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
