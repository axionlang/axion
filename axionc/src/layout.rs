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
    // context stack: (indentation column, was opened by `let`, bracket depth at open time)
    let mut ctx: Vec<(usize, bool, usize)> = Vec::new();
    // number of unmatched `(`/`[`/`{` currently open. An implicit block opened INSIDE a bracket is
    // closed by that bracket's matching close (the pragmatic slice of Haskell's parse-error rule),
    // so `(case x of A -> e)` and `(do …)`/`(let … in …)` parse without a helper function.
    let mut bracket_depth: usize = 0;
    if tokens.is_empty() {
        return out;
    }

    // opens the implicit top-level block (module) at the first token's column
    let (mut last_line, first_col) = {
        let (l, c) = lines.pos(tokens[0].start);
        (l, c)
    };
    push(&mut out, LTok::VLBrace, &tokens[0]);
    ctx.push((first_col, false, bracket_depth));

    // block pending to open: Some(is_let) after where/let/of
    let mut open_kind: Option<bool> = None;

    for t in tokens {
        let (line, col) = lines.pos(t.start);

        if let Some(is_let) = open_kind.take() {
            // this token starts the new block (opened by where/let/of)
            push(&mut out, LTok::VLBrace, t);
            ctx.push((col, is_let, bracket_depth));
            last_line = line;
        } else if line != last_line {
            // first token of a new line: the "offside" rule
            loop {
                match ctx.last() {
                    Some(&(m, _, _)) if col < m => {
                        push(&mut out, LTok::VRBrace, t);
                        ctx.pop();
                        if ctx.is_empty() {
                            break;
                        }
                    }
                    Some(&(m, _, _)) if col == m => {
                        push(&mut out, LTok::VSemi, t);
                        break;
                    }
                    _ => break, // col > m (continuation) or empty stack
                }
            }
            last_line = line;
        }

        // A close bracket closes every implicit block opened INSIDE it (recorded bracket depth
        // >= the current depth), so the enclosed `case`/`do`/`let` ends before the bracket. Blocks
        // opened outside (lower recorded depth — incl. the depth-0 module) are untouched.
        if matches!(t.tok, Tok::RParen | Tok::RBracket | Tok::RBrace) {
            while matches!(ctx.last(), Some(&(_, _, d)) if d >= bracket_depth && bracket_depth > 0)
            {
                push(&mut out, LTok::VRBrace, t);
                ctx.pop();
            }
            bracket_depth = bracket_depth.saturating_sub(1);
        }

        // `in` closes the nearest `let` block — but only if it is still open (on a dedented
        // `in`, the offside rule already closed it) and was opened at this bracket depth: an `in`
        // inside a bracket opened after the `let` belongs to that bracket's own construct
        // (`let q = a + (borrow b as p in f p) in …`).
        if t.tok == Tok::In && matches!(ctx.last(), Some(&(_, true, d)) if d == bracket_depth) {
            push(&mut out, LTok::VRBrace, t);
            ctx.pop();
        }

        // an explicit `;` is a block-item separator → emit it as a virtual semicolon, which both
        // parsers' block loops already consume (no parser change). It carries no text, so the CST
        // round-trips the `;` as trivia.
        if t.tok == Tok::Semi {
            push(&mut out, LTok::VSemi, t);
        } else {
            push(&mut out, LTok::Tok(t.tok.clone()), t);
        }

        if matches!(t.tok, Tok::LParen | Tok::LBracket | Tok::LBrace) {
            bracket_depth += 1;
        }

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
