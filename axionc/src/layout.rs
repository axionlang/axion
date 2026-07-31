//! Layout rule (indentation) — the pragmatic version of Haskell's algorithm.
//!
//! Converts the list of positioned tokens into tokens with *virtual*
//! braces/semicolons (`VLBrace`/`VSemi`/`VRBrace`), so the parser handles blocks
//! (the top-level module, and the blocks opened by `where`/`let`/`of`) without
//! worrying about columns. Covers the L0/L1 subset of the target programs.

use crate::lexer::{LineMap, Spanned, Tok};

#[derive(Debug, Clone, PartialEq)]
pub enum LTok {
    Tok(Tok),
    VLBrace,
    VSemi,
    VRBrace,
}

#[derive(Debug, Clone)]
pub struct LSpanned {
    pub tok: LTok,
    pub start: usize,
    pub end: usize,
}

/// Applies the layout. `lines` provides (line, column) of each offset.
pub fn layout(tokens: &[Spanned], lines: &LineMap) -> Vec<LSpanned> {
    let mut out: Vec<LSpanned> = Vec::new();
    // context stack: (indentation column, was opened by `let`)
    let mut ctx: Vec<(usize, bool)> = Vec::new();
    if tokens.is_empty() {
        return out;
    }

    // opens the implicit top-level block (module) at the first token's column
    let (mut last_line, first_col) = {
        let (l, c) = lines.pos(tokens[0].start);
        (l, c)
    };
    push(&mut out, LTok::VLBrace, &tokens[0]);
    ctx.push((first_col, false));

    // block pending to open: Some(is_let) after where/let/of
    let mut open_kind: Option<bool> = None;

    for t in tokens {
        let (line, col) = lines.pos(t.start);

        if let Some(is_let) = open_kind.take() {
            // this token starts the new block (opened by where/let/of)
            push(&mut out, LTok::VLBrace, t);
            ctx.push((col, is_let));
            last_line = line;
        } else if line != last_line {
            // first token of a new line: the "offside" rule
            loop {
                match ctx.last() {
                    Some(&(m, _)) if col < m => {
                        push(&mut out, LTok::VRBrace, t);
                        ctx.pop();
                        if ctx.is_empty() {
                            break;
                        }
                    }
                    Some(&(m, _)) if col == m => {
                        push(&mut out, LTok::VSemi, t);
                        break;
                    }
                    _ => break, // col > m (continuation) or empty stack
                }
            }
            last_line = line;
        }

        // `in` closes the nearest `let` block — but only if it is still open
        // (on a dedented `in`, the offside rule already closed it).
        if t.tok == Tok::In && matches!(ctx.last(), Some((_, true))) {
            push(&mut out, LTok::VRBrace, t);
            ctx.pop();
        }

        push(&mut out, LTok::Tok(t.tok.clone()), t);

        open_kind = match t.tok {
            Tok::Let => Some(true),
            Tok::Where | Tok::Of | Tok::Do => Some(false),
            _ => open_kind,
        };
    }

    // closes all blocks still open at end of file
    let end = tokens.last().map(|t| t.end).unwrap_or(0);
    while ctx.pop().is_some() {
        out.push(LSpanned {
            tok: LTok::VRBrace,
            start: end,
            end,
        });
    }

    out
}

fn push(out: &mut Vec<LSpanned>, tok: LTok, at: &Spanned) {
    out.push(LSpanned {
        tok,
        start: at.start,
        end: at.end,
    });
}
