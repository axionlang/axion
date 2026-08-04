#![allow(clippy::string_slice)]
//! Lexical analysis of `.axi` with `logos` (§18) + a line table for spans.
//!
//! The lexer ignores spaces, newlines and comments; the (line, column) position
//! of each token is recovered from the byte offset against a table of
//! line starts. The layout rule (indentation) is applied separately, in
//! [`crate::layout`], over these already-positioned tokens.

use logos::Logos;

#[derive(Logos, Debug, Clone, PartialEq)]
#[logos(skip r"[ \t\r\n\f]+")]
#[logos(skip r"--[^\n]*")]
pub enum Tok {
    // --- keywords (priority over VarId since they are literals) ---
    #[token("where")]
    Where,
    #[token("let")]
    Let,
    #[token("in")]
    In,
    #[token("of")]
    Of,
    #[token("if")]
    If,
    #[token("then")]
    Then,
    #[token("else")]
    Else,
    #[token("case")]
    Case,
    #[token("data")]
    Data,
    #[token("do")]
    Do,
    #[token("foreign")]
    Foreign,
    #[token("class")]
    Class,
    #[token("instance")]
    Instance,

    // --- punctuation and symbols ---
    #[token("::")]
    ColonColon,
    #[token("=>")]
    FatArrow,
    #[token("$")]
    Dollar,
    #[token("<-")]
    LArrow,
    #[token("=")]
    Equals,
    #[token("->")]
    Arrow,
    #[token("..")]
    DotDot,
    #[token(":")]
    Colon,
    #[token(".")]
    Dot,
    #[token("(")]
    LParen,
    #[token(")")]
    RParen,
    #[token("[")]
    LBracket,
    #[token("]")]
    RBracket,
    #[token("{")]
    LBrace,
    #[token("}")]
    RBrace,
    #[token(",")]
    Comma,
    #[token("|")]
    Bar,
    #[token("\\")]
    Backslash,
    #[token("`")]
    Backtick,

    // multiplicity: %1 (linear), %0.5 (fractional) — the L1 mark
    #[regex(r"%[0-9]+(\.[0-9]+)?", |lex| lex.slice().to_string())]
    Mult(String),

    // operators
    #[token("++")]
    PlusPlus,
    // float arithmetic (§4): `+.` `-.` `*.` `/.` — distinct from the Int operators
    // (OCaml-style), so codegen is not type-directed. Longer than `+`/`-`/`*`, so
    // logos picks them (and `2.0 *. 3.0` splits as Float StarDot Float).
    #[token("+.")]
    PlusDot,
    #[token("-.")]
    MinusDot,
    #[token("*.")]
    StarDot,
    #[token("/.")]
    SlashDot,
    #[token("+")]
    Plus,
    #[token("-")]
    Minus,
    #[token("*")]
    Star,
    #[token("==.")]
    EqEqDot,
    #[token("<.")]
    LtDot,
    #[token(">.")]
    GtDot,
    #[token("==")]
    EqEq,
    #[token("<")]
    Lt,
    #[token(">")]
    Gt,

    // literals (decimal and hexadecimal `0x…`; logos picks the longest
    // match, so `0x5A` matches the hex, not `0`). A `Float` needs a fractional
    // part (`3.14`) so it wins over `Int` `.` `Int`.
    #[regex(r"[0-9]+\.[0-9]+", |lex| lex.slice().parse::<f64>().ok())]
    Float(f64),
    #[regex(r"[0-9]+", |lex| lex.slice().parse::<i64>().ok())]
    #[regex(r"0x[0-9a-fA-F]+", |lex| i64::from_str_radix(&lex.slice()[2..], 16).ok())]
    Int(i64),
    #[regex(r#""([^"\\]|\\.)*""#, |lex| unquote(lex.slice()))]
    Str(String),

    // identifiers
    #[regex(r"[a-z_][A-Za-z0-9_']*", |lex| lex.slice().to_string())]
    VarId(String),
    #[regex(r"[A-Z][A-Za-z0-9_']*", |lex| lex.slice().to_string())]
    ConId(String),
}

fn unquote(s: &str) -> String {
    // strip quotes and resolve simple escapes
    let inner = &s[1..s.len() - 1];
    let mut out = String::with_capacity(inner.len());
    let mut chars = inner.chars();
    while let Some(c) = chars.next() {
        if c == '\\' {
            match chars.next() {
                Some('n') => out.push('\n'),
                Some('t') => out.push('\t'),
                Some('\\') => out.push('\\'),
                Some('"') => out.push('"'),
                Some(other) => out.push(other),
                None => {}
            }
        } else {
            out.push(c);
        }
    }
    out
}

/// A token with its byte range in the source.
#[derive(Debug, Clone)]
pub struct Spanned {
    pub tok: Tok,
    pub start: usize,
    pub end: usize,
}

/// Map of offsets → (line, column), both 1-based.
pub struct LineMap {
    line_starts: Vec<usize>,
}

impl LineMap {
    pub fn new(src: &str) -> Self {
        let mut line_starts = vec![0];
        for (i, b) in src.bytes().enumerate() {
            if b == b'\n' {
                line_starts.push(i + 1);
            }
        }
        LineMap { line_starts }
    }

    /// 1-based (line, column) of the given offset.
    pub fn pos(&self, offset: usize) -> (usize, usize) {
        let line = match self.line_starts.binary_search(&offset) {
            Ok(i) => i,
            Err(i) => i - 1,
        };
        let col = offset - self.line_starts[line] + 1;
        (line + 1, col)
    }
}

/// Lexical error (unexpected character): reported as AX0100.
#[derive(Debug, Clone)]
pub struct LexError {
    pub start: usize,
    pub end: usize,
}

/// Tokenizes the whole source. Returns the positioned tokens or the first error.
pub fn lex(src: &str) -> Result<Vec<Spanned>, LexError> {
    let mut out = Vec::new();
    let mut lexer = Tok::lexer(src);
    while let Some(res) = lexer.next() {
        let span = lexer.span();
        match res {
            Ok(tok) => out.push(Spanned {
                tok,
                start: span.start,
                end: span.end,
            }),
            Err(()) => {
                return Err(LexError {
                    start: span.start,
                    end: span.end,
                })
            }
        }
    }
    Ok(out)
}
