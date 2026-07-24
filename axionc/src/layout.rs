//! Regra de layout (indentação) — a versão pragmática do algoritmo do Haskell.
//!
//! Converte a lista de tokens posicionados em tokens com chavetas/pontos-e-vírgula
//! *virtuais* (`VLBrace`/`VSemi`/`VRBrace`), para o parser tratar blocos
//! (o módulo de topo, e os blocos abertos por `where`/`let`/`of`) sem se
//! preocupar com colunas. Cobre o subconjunto L0/L1 dos programas-alvo.

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

fn opens_block(t: &Tok) -> bool {
    matches!(t, Tok::Where | Tok::Let | Tok::Of)
}

/// Aplica o layout. `lines` fornece (linha, coluna) de cada offset.
pub fn layout(tokens: &[Spanned], lines: &LineMap) -> Vec<LSpanned> {
    let mut out: Vec<LSpanned> = Vec::new();
    let mut ctx: Vec<usize> = Vec::new(); // pilha de colunas de indentação
    if tokens.is_empty() {
        return out;
    }

    // abre o bloco implícito de topo (módulo) na coluna do primeiro token
    let (mut last_line, first_col) = {
        let (l, c) = lines.pos(tokens[0].start);
        (l, c)
    };
    push(&mut out, LTok::VLBrace, &tokens[0]);
    ctx.push(first_col);

    let mut expect_open = false;

    for t in tokens {
        let (line, col) = lines.pos(t.start);

        if expect_open {
            // este token inicia o novo bloco (aberto por where/let/of)
            push(&mut out, LTok::VLBrace, t);
            ctx.push(col);
            expect_open = false;
            last_line = line;
        } else if line != last_line {
            // primeiro token de uma nova linha: regra do "offside"
            loop {
                match ctx.last() {
                    Some(&m) if col < m => {
                        push(&mut out, LTok::VRBrace, t);
                        ctx.pop();
                        if ctx.is_empty() {
                            break;
                        }
                    }
                    Some(&m) if col == m => {
                        push(&mut out, LTok::VSemi, t);
                        break;
                    }
                    _ => break, // col > m (continuação) ou pilha vazia
                }
            }
            last_line = line;
        }

        // `in` fecha o bloco `let` mais próximo antes de ser emitido
        if t.tok == Tok::In && !ctx.is_empty() {
            push(&mut out, LTok::VRBrace, t);
            ctx.pop();
        }

        push(&mut out, LTok::Tok(t.tok.clone()), t);

        if opens_block(&t.tok) {
            expect_open = true;
        }
    }

    // fecha todos os blocos ainda abertos no fim do ficheiro
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
