//! Análise léxica do `.axi` com `logos` (§18) + tabela de linhas para spans.
//!
//! O lexer ignora espaços, novas-linhas e comentários; a posição (linha,
//! coluna) de cada token é recuperada do offset de bytes contra uma tabela de
//! inícios de linha. A regra de layout (indentação) é aplicada à parte, em
//! [`crate::layout`], sobre estes tokens já posicionados.

use logos::Logos;

#[derive(Logos, Debug, Clone, PartialEq)]
#[logos(skip r"[ \t\r\n\f]+")]
#[logos(skip r"--[^\n]*")]
pub enum Tok {
    // --- palavras-chave (prioridade sobre VarId por serem literais) ---
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

    // --- pontuação e símbolos ---
    #[token("::")]
    ColonColon,
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

    // multiplicidade: %1 (linear), %0.5 (fraccionária) — a marca de L1
    #[regex(r"%[0-9]+(\.[0-9]+)?", |lex| lex.slice().to_string())]
    Mult(String),

    // operadores
    #[token("+")]
    Plus,
    #[token("-")]
    Minus,
    #[token("*")]
    Star,
    #[token("==")]
    EqEq,
    #[token("<")]
    Lt,
    #[token(">")]
    Gt,

    // literais (decimal e hexadecimal `0x…`; logos escolhe a correspondência
    // mais longa, logo `0x5A` casa o hex, não `0`)
    #[regex(r"[0-9]+", |lex| lex.slice().parse::<i64>().ok())]
    #[regex(r"0x[0-9a-fA-F]+", |lex| i64::from_str_radix(&lex.slice()[2..], 16).ok())]
    Int(i64),
    #[regex(r#""([^"\\]|\\.)*""#, |lex| unquote(lex.slice()))]
    Str(String),

    // identificadores
    #[regex(r"[a-z_][A-Za-z0-9_']*", |lex| lex.slice().to_string())]
    VarId(String),
    #[regex(r"[A-Z][A-Za-z0-9_']*", |lex| lex.slice().to_string())]
    ConId(String),
}

fn unquote(s: &str) -> String {
    // remove aspas e resolve escapes simples
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

/// Um token com o seu intervalo de bytes na fonte.
#[derive(Debug, Clone)]
pub struct Spanned {
    pub tok: Tok,
    pub start: usize,
    pub end: usize,
}

/// Mapa de offsets → (linha, coluna), ambos 1-based.
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

    /// (linha, coluna) 1-based do offset dado.
    pub fn pos(&self, offset: usize) -> (usize, usize) {
        let line = match self.line_starts.binary_search(&offset) {
            Ok(i) => i,
            Err(i) => i - 1,
        };
        let col = offset - self.line_starts[line] + 1;
        (line + 1, col)
    }
}

/// Erro léxico (caractere inesperado): reportado como AX0100.
#[derive(Debug, Clone)]
pub struct LexError {
    pub start: usize,
    pub end: usize,
}

/// Tokeniza a fonte inteira. Devolve os tokens posicionados ou o primeiro erro.
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
            Err(_) => {
                return Err(LexError {
                    start: span.start,
                    end: span.end,
                })
            }
        }
    }
    Ok(out)
}
