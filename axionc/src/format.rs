//! `axionc fmt` — a native formatter over the lossless rowan CST (`cst::build_cst`).
//!
//! Safety principle: format a file only when it parses with NO error node AND the printer handled
//! every node/token it met; otherwise return `None` (leave the file untouched). The formatter never
//! reorders tokens and never drops comments; semantic preservation is gated by the oracle (a
//! formatted file must lower to byte-identical Core).

use crate::cst::{build_cst, build_lossless_cst, SyntaxKind, SyntaxNode};
use rowan::NodeOrToken;

/// DEBUG: a readable dump of the CST (kinds + token text), for developing the printer.
pub fn debug_tree(src: &str) -> String {
    fn go(n: &SyntaxNode, d: usize, out: &mut String) {
        for el in n.children_with_tokens() {
            let pad = "  ".repeat(d);
            match el {
                NodeOrToken::Node(c) => {
                    out.push_str(&format!("{pad}{:?}\n", c.kind()));
                    go(&c, d + 1, out);
                }
                NodeOrToken::Token(t) => {
                    out.push_str(&format!("{pad}{:?} {:?}\n", t.kind(), t.text()));
                }
            }
        }
    }
    let root = build_lossless_cst(src).unwrap_or_else(|| build_cst(src));
    let mut s = String::new();
    s.push_str(&format!("{:?}\n", root.kind()));
    go(&root, 1, &mut s);
    s
}

/// Spaces per block-nesting level.
const UNIT: i32 = 2;

/// A block construct whose body `axionc fmt` re-indents: its items (statements / alternatives /
/// let-bindings) get one indent level per enclosing modeled block. These are exactly the expression
/// blocks whose item boundaries the CST exposes (`do`→BIND/EXPR/LET_STMT, `case`→CASE_ALT,
/// `let`→FUN_CLAUSE).
fn is_modeled_block(k: SyntaxKind) -> bool {
    use SyntaxKind::{CASE_EXPR, DO_EXPR, LET_EXPR};
    matches!(k, DO_EXPR | CASE_EXPR | LET_EXPR)
}

/// A block whose body we deliberately leave exactly as authored (its own layout rules differ, or we
/// have not modeled its indentation): `where`, class/instance bodies, data/foreign declarations. An
/// item with any such ancestor is skipped — never re-indented — so those regions are byte-stable.
fn is_unmodeled_block(k: SyntaxKind) -> bool {
    use SyntaxKind::{
        CLASS_DECL, DATA_DECL, FOREIGN_ENUM, FOREIGN_STRUCT, INSTANCE_DECL, WHERE,
    };
    matches!(
        k,
        WHERE | CLASS_DECL | INSTANCE_DECL | DATA_DECL | FOREIGN_STRUCT | FOREIGN_ENUM
    )
}

/// A node that begins a logical "item" (a line we may re-indent to its canonical column): top-level
/// declarations and the items of a modeled block.
fn is_item(k: SyntaxKind) -> bool {
    use SyntaxKind::{
        BIND_STMT, CASE_ALT, CLASS_DECL, DATA_DECL, EXPR_STMT, FIXITY_DECL, FOREIGN_DECL,
        FOREIGN_ENUM, FOREIGN_STRUCT, FUN_CLAUSE, IMPORT_DECL, INSTANCE_DECL, LET_STMT, SIG,
    };
    matches!(
        k,
        SIG | FUN_CLAUSE
            | BIND_STMT
            | EXPR_STMT
            | LET_STMT
            | CASE_ALT
            | DATA_DECL
            | CLASS_DECL
            | INSTANCE_DECL
            | FOREIGN_DECL
            | FOREIGN_STRUCT
            | FOREIGN_ENUM
            | IMPORT_DECL
            | FIXITY_DECL
    )
}

fn is_trivia(k: SyntaxKind) -> bool {
    use SyntaxKind::{COMMENT, WHITESPACE};
    matches!(k, WHITESPACE | COMMENT)
}

/// Byte offset of a node's first non-trivia token (where its content actually starts).
fn first_token_offset(node: &SyntaxNode) -> Option<usize> {
    node.descendants_with_tokens()
        .filter_map(|e| e.into_token())
        .find(|t| !is_trivia(t.kind()))
        .map(|t| usize::from(t.text_range().start()))
}

/// The indent level of an item = number of enclosing modeled blocks — unless it lies inside an
/// unmodeled block (`where`/instance/…), in which case `None` means "leave this line alone".
fn item_depth(node: &SyntaxNode) -> Option<i32> {
    let mut depth = 0;
    let mut p = node.parent();
    while let Some(n) = p {
        if is_unmodeled_block(n.kind()) {
            return None;
        }
        if is_modeled_block(n.kind()) {
            depth += 1;
        }
        p = n.parent();
    }
    Some(depth)
}

/// The nearest enclosing modeled block (`do`/`case`/`let`) of an item, if any (else it is top-level).
fn nearest_modeled_block(node: &SyntaxNode) -> Option<SyntaxNode> {
    node.ancestors().skip(1).find(|n| is_modeled_block(n.kind()))
}

/// A block's first item child (its first statement / alternative / binding).
fn block_first_item(block: &SyntaxNode) -> Option<SyntaxNode> {
    block.children().find(|c| is_item(c.kind()))
}

/// Number of leading space characters on a line (counts spaces only; a leading tab makes the line
/// un-normalizable — see `format_src`).
fn leading_spaces(line: &str) -> usize {
    line.len() - line.trim_start_matches(' ').len()
}

/// Format `src`, or `None` if it can't be formatted safely (does not parse cleanly, or uses tab
/// indentation we don't model — leave it untouched rather than risk mangling it).
///
/// The printer is a STRUCTURE-DRIVEN line re-indenter. It never touches a line's content (everything
/// after the leading whitespace is byte-preserved — so operators, literals, spacing, and comments are
/// never rewritten); it only recomputes each line's leading indentation, normalizing the per-level
/// INDENT WIDTH to `UNIT`. In a layout language sibling items of a block are already column-aligned
/// (the offside rule requires it to parse), so the useful, safe transform is making each INDENTED
/// block sit exactly `UNIT` past its opener LINE's indent — anchoring to the opener line, not to an
/// abstract block depth, so expression nesting (`if/then`, `let` body, lambda, a long RHS) is captured
/// and the block stays strictly inside its opener (offside-valid by construction). Each block's shift
/// is recorded at its first item and re-applied to the siblings; continuation lines carry their item's
/// shift, so multi-line expressions move as a unit. ALIGNED blocks (first item sharing the opener's
/// line, `let s = …` / `case x of A -> …`) keep the author's column, and items inside an unmodeled
/// block (`where`, class/instance, data/foreign) are left exactly as written. Finally trailing
/// whitespace is stripped, runs of blank lines collapse to one, and the file ends in a single newline.
/// Column moves can change the offside parse, so semantic preservation is enforced by the oracle gate
/// (`scripts/fmt-check.sh`: a formatted file must lower to byte-identical Core).
pub fn format_src(src: &str) -> Option<String> {
    // The LOSSLESS, token-driven whole-module CST (real block structure + real source offsets). `None`
    // when the file isn't fully covered by the token-driven subset — then we leave it untouched.
    let root = build_lossless_cst(src)?;
    if root.descendants().any(|n| n.kind() == SyntaxKind::ERROR) {
        return None;
    }
    // Defensive: the tree must round-trip to the exact source (every byte a token or trivia) for the
    // offsets we key indentation on to be real. If not, bail rather than risk mangling.
    if root.text() != src {
        return None;
    }
    let lines: Vec<&str> = src.lines().collect();
    // A tab anywhere in a line's leading whitespace means our space-based indent math would rewrite
    // it — bail out and leave the file untouched.
    if lines
        .iter()
        .any(|l| l.chars().take_while(|c| c.is_whitespace()).any(|c| c == '\t'))
    {
        return None;
    }
    // Byte offset at which each source line starts (to map a token offset → line index).
    let mut line_start = Vec::with_capacity(lines.len() + 1);
    {
        let mut off = 0usize;
        for l in &lines {
            line_start.push(off);
            off += l.len() + 1; // +1 for the '\n' that `str::lines` stripped
        }
    }
    let line_of = |off: usize| -> usize {
        match line_start.binary_search(&off) {
            Ok(i) => i,
            Err(i) => i.saturating_sub(1),
        }
    };
    // Is a node's first token the first non-blank thing on its line (a true line head)?
    let is_line_head = |node: &SyntaxNode| -> Option<bool> {
        let off = first_token_offset(node)?;
        let li = line_of(off);
        Some(off - line_start[li] == leading_spaces(lines.get(li)?))
    };

    // Column (leading spaces) of a node's head line.
    let col_of = |node: &SyntaxNode| -> Option<i32> {
        let off = first_token_offset(node)?;
        Some(leading_spaces(lines.get(line_of(off))?) as i32)
    };

    // A re-indentable item head, anchored to the FIRST item of its block. `block_key` identifies the
    // block (its first-token offset; the sentinel `usize::MAX` = module top level). `is_first` marks
    // the block's first item (it moves with its parent via `carry`, and pins the block's shift);
    // siblings align to `first_col` plus that recorded shift.
    struct ItemRec {
        block_key: usize,
        is_first: bool,
        first_col: i32,
        own_col: i32,
        anchor_line: usize, // the block's opener line; its items sit at that line's indent + UNIT
    }
    const TOP: usize = usize::MAX;
    let mut rec: Vec<Option<ItemRec>> = (0..lines.len()).map(|_| None).collect();
    for node in root.descendants() {
        if !is_item(node.kind()) {
            continue;
        }
        let Some(off) = first_token_offset(&node) else {
            continue;
        };
        let li = line_of(off);
        if rec[li].is_some() {
            continue; // one head per line; pre-order gives the outermost item first
        }
        let own_col = leading_spaces(lines.get(li)?) as i32;
        // the item's first token must be the first non-blank thing on its line (a true head)
        if (off - line_start[li]) as i32 != own_col {
            continue;
        }
        if item_depth(&node).is_none() {
            continue; // inside an unmodeled block (where/class/instance/data) → leave as authored
        }
        match nearest_modeled_block(&node) {
            None => {
                // top level: every declaration aligns to column 0 (shift fixed at 0), which also
                // RESETS the running carry when we return to the top level between nested blocks.
                rec[li] = Some(ItemRec {
                    block_key: TOP,
                    is_first: false,
                    first_col: 0,
                    own_col,
                    anchor_line: 0,
                });
            }
            Some(block) => {
                let Some(first) = block_first_item(&block) else {
                    continue;
                };
                // ALIGNED block (first item shares the opener's line, e.g. `let s = …` / `case x of A
                // -> …`): its offside column is pinned to that first item, so siblings must shift WITH
                // the block (carry-forward), never re-anchor. Only an INDENTED block participates.
                if is_line_head(&first) != Some(true) {
                    continue;
                }
                let Some(first_col) = col_of(&first) else {
                    continue;
                };
                let Some(block_off) = first_token_offset(&block) else {
                    continue;
                };
                rec[li] = Some(ItemRec {
                    block_key: block_off,
                    is_first: first == node,
                    first_col,
                    own_col,
                    anchor_line: line_of(block_off),
                });
            }
        }
    }

    // Emit in line order. `carry` is the delta applied to the current item's lines (continuation lines
    // inherit it). At a block's first item we record its shift; siblings re-anchor to that first item's
    // NEW column (`first_col + shift`) — so blocks nested in expressions keep their real depth while
    // ragged siblings get aligned. Trailing whitespace is stripped and blank runs collapse to one.
    let mut block_shift: std::collections::HashMap<usize, i32> = std::collections::HashMap::new();
    block_shift.insert(TOP, 0);
    let mut new_indent_of = vec![0i32; lines.len()];
    let mut out = String::new();
    let mut carry = 0i32;
    let mut pending_blank = false;
    let mut seen = false;
    for (i, raw) in lines.iter().enumerate() {
        let content = raw.trim_start_matches(' ').trim_end();
        if content.is_empty() {
            pending_blank = true;
            continue;
        }
        if pending_blank && seen {
            out.push('\n');
        }
        pending_blank = false;
        seen = true;
        let old = leading_spaces(raw) as i32;
        let delta = match &rec[i] {
            None => carry,
            Some(r) if r.is_first => {
                // first item of an INDENTED block → anchor the block one UNIT past its opener line's
                // (already-emitted) indent. This captures expression nesting (if/then, let-body,
                // lambda) that block-depth alone misses, and keeps the block strictly inside its
                // opener — so the offside parse is preserved.
                let target = new_indent_of[r.anchor_line] + UNIT;
                let shift = target - r.first_col;
                block_shift.insert(r.block_key, shift);
                carry = shift;
                shift
            }
            Some(r) => {
                // a sibling item: re-anchor to the block's first item at its new column
                let shift = *block_shift.get(&r.block_key).unwrap_or(&0);
                let d = r.first_col + shift - r.own_col;
                carry = d;
                d
            }
        };
        let new_indent = (old + delta).max(0);
        new_indent_of[i] = new_indent;
        out.push_str(&" ".repeat(new_indent as usize));
        out.push_str(content);
        out.push('\n');
    }
    Some(out)
}
