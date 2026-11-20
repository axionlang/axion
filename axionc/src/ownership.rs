//! `--emit ownership`: what the compiler decided about each heap value, at source lines.
//!
//! The decisions are read off the FINAL Core (after Auto-Drop and every copy pass) through the
//! same Δ judgment the drop-balance verifier is cross-checked against (`delta::ownership_trace`),
//! so the report shows what the native code does, not a front-end approximation: where a value
//! is created, lent, moved, copied (and why), returned and freed — including frees on one branch
//! only and frees that leave a shared field alone.

use crate::ast::Span;
use crate::delta::{MoveTo, OwnEvent, OwnFn, OwnKind, Who};
use crate::diag::{CLONE_SPAN_STRIDE, PRELUDE_SPAN_BAND};
use crate::lexer::LineMap;

/// Is `sp` a span of the user's own file (not the prelude, an import or generated code)?
fn user_span(sp: Span) -> bool {
    sp != crate::core::NO_SPAN && sp.0 / CLONE_SPAN_STRIDE < PRELUDE_SPAN_BAND
}

fn unclone(sp: Span) -> Span {
    (sp.0 % CLONE_SPAN_STRIDE, sp.1 % CLONE_SPAN_STRIDE)
}

/// Generated functions that are not the user's code even when they carry user spans.
fn generated(name: &str) -> bool {
    name.starts_with("axion_")
        || name.starts_with("sess$")
        || name.ends_with("$step")
        || name.starts_with(crate::core::ARROP)
}

/// A drop key as a type: `tuple2$Closure$Int` → `(Closure, Int)`, `List$P` → `List P`.
fn pretty_ty(k: &str) -> String {
    let parts: Vec<&str> = k.split('$').filter(|p| !p.is_empty()).collect();
    match parts.split_first() {
        Some((h, rest)) if h.starts_with("tuple") && !rest.is_empty() => {
            format!("({})", rest.join(", "))
        }
        Some((h, rest)) if !rest.is_empty() => format!("{h} {}", rest.join(" ")),
        Some((h, _)) => h.to_string(),
        None => k.to_string(),
    }
}

fn pretty_fn(name: &str) -> String {
    crate::delta::fn_label(name)
}

/// The character just before byte `at` (`None` at the start or off a char boundary).
fn char_before(src: &str, at: usize) -> Option<char> {
    src.get(..at)?.chars().next_back()
}

/// The character at byte `at` (`None` at the end or off a char boundary).
fn char_at(src: &str, at: usize) -> Option<char> {
    src.get(at..)?.chars().next()
}

/// The first whole-word `w` in `src[from..to]`.
fn find_word(src: &str, w: &str, from: usize, to: usize) -> Option<usize> {
    let word = |c: char| c.is_alphanumeric() || c == '_' || c == '\'';
    let hay = src.get(from..to.min(src.len()))?;
    hay.match_indices(w).map(|(k, _)| from + k).find(|&at| {
        char_before(src, at).is_none_or(|c| !word(c))
            && char_at(src, at + w.len()).is_none_or(|c| !word(c))
    })
}

/// Where `n` is bound at or after byte `from`: `let n =`, `n <-`, a `where`/top-level `n =`.
/// (For a binding whose Core node carries a synthesized span.)
fn find_binding(src: &str, n: &str, from: usize) -> Option<usize> {
    let word = |c: char| c.is_alphanumeric() || c == '_' || c == '\'';
    let mut i = from.min(src.len());
    while let Some(k) = src.get(i..)?.find(n) {
        let at = i + k;
        let end = at + n.len();
        let before_ok = char_before(src, at).is_none_or(|c| !word(c));
        let after_ok = char_at(src, end).is_none_or(|c| !word(c));
        if before_ok && after_ok {
            let rest = src.get(end..)?.trim_start_matches([' ', '\t']);
            if (rest.starts_with('=') && !rest.starts_with("==")) || rest.starts_with("<-") {
                return Some(at);
            }
        }
        i = end;
    }
    None
}

/// One ownership event, positioned and worded for the programmer.
#[derive(Debug, Clone)]
pub struct Line {
    /// byte offset in the user's file (`None`: no source position)
    pub at: Option<usize>,
    /// the branch it happens in (`then`, `else`, a `case` pattern; outermost first)
    pub branch: Vec<String>,
    /// who it is about, as text (`` `cs` ``, `a copy of `cs``, `the result of `pick``)
    pub who: String,
    /// what happens to it
    pub what: String,
    /// the source names the line is about (the subject, what it was copied from, its new name)
    pub names: Vec<String>,
    /// a copy the compiler inserted (an inlay hint in the editor)
    pub copy: bool,
    /// a free that leaves some fields alone (an inlay hint in the editor)
    pub partial_free: bool,
}

/// One user function's ownership story.
#[derive(Debug, Clone)]
pub struct Section {
    /// its Core name (`idG$Closure`, `lam$2`)
    pub name: String,
    /// its heading (`usePair f k`, `idG x   (specialized for Closure)`, `lambda at 3:9`)
    pub head: String,
    /// byte offset where its definition starts
    pub start: usize,
    /// its events, in evaluation order
    pub lines: Vec<Line>,
}

/// The ownership report of a program's own functions.
#[derive(Debug, Clone, Default)]
pub struct Report {
    /// the functions with heap values, in Core order
    pub sections: Vec<Section>,
    /// user functions with no heap values
    pub plain: Vec<String>,
}

impl Report {
    /// The story of `name` around byte `at`: the lines about it in the nearest function that
    /// starts at or before `at` and mentions it (for an editor hover).
    pub fn story(&self, name: &str, at: usize) -> Option<(&Section, Vec<&Line>)> {
        self.sections
            .iter()
            .filter(|s| s.start <= at && s.lines.iter().any(|l| l.names.iter().any(|n| n == name)))
            .max_by_key(|s| s.start)
            .map(|s| {
                let lines = s
                    .lines
                    .iter()
                    .filter(|l| l.names.iter().any(|n| n == name))
                    .collect();
                (s, lines)
            })
    }
}

struct Ctx<'a> {
    src: &'a str,
    /// the current function's first source offset (where a binding search starts)
    fn_start: usize,
    /// the previous event's position: an event whose span covers several lines (a whole `do`
    /// block) is shown there instead
    last: Option<Span>,
}

fn who_names(w: &Who, out: &mut Vec<String>) {
    match w {
        Who::Name(n) => out.push(crate::core::source_name(n).to_string()),
        Who::CopyOf(inner) => who_names(inner, out),
        Who::Expr(..) | Who::Made(_) => {}
    }
}

impl Ctx<'_> {
    fn snippet(&self, sp: Span) -> String {
        let (a, b) = unclone(sp);
        let text = self.src.get(a..b.min(self.src.len())).unwrap_or("…");
        if text.contains('\n') {
            return "an intermediate value".into();
        }
        let mut one: String = text.split_whitespace().collect::<Vec<_>>().join(" ");
        // an application's span ends at its last argument: close what it opened
        let open = one
            .matches('(')
            .count()
            .saturating_sub(one.matches(')').count());
        one.push_str(&")".repeat(open));
        if one.chars().count() > 40 {
            let cut: String = one.chars().take(38).collect();
            format!("`{cut}…`")
        } else {
            format!("`{one}`")
        }
    }

    fn who(&self, w: &Who) -> String {
        match w {
            Who::Name(n) => format!("`{}`", crate::core::source_name(n)),
            Who::Expr(sp, _) if user_span(*sp) => self.snippet(*sp),
            Who::Expr(..) => "an intermediate value".into(),
            Who::CopyOf(inner) => format!("a copy of {}", self.who(inner)),
            Who::Made(d) => d.clone(),
        }
    }

    fn what(&self, k: &OwnKind) -> String {
        match k {
            OwnKind::Param { owned: true } => {
                "parameter, owned: this function frees it or passes it on".into()
            }
            OwnKind::Param { owned: false } => {
                "parameter, borrowed: the caller keeps it and frees it".into()
            }
            OwnKind::New { ty: Some(t) } => format!("new {}, owned here", pretty_ty(t)),
            OwnKind::New { ty: None } => "created, owned here".into(),
            OwnKind::Copy { why } => format!("made by the compiler: {why}"),
            OwnKind::Moved { to } => match to {
                MoveTo::Callee(g) => format!("moved into {} (it frees it now)", pretty_fn(g)),
                MoveTo::ClosureCall => "moved into the closure call".into(),
                MoveTo::StoredIn(w) => format!("stored in {} (freed with it)", self.who(w)),
                MoveTo::Renamed(y) => format!("now called `{y}`"),
            },
            OwnKind::Lent { to } => format!("lent to {} (still owned here)", pretty_fn(to)),
            OwnKind::Returned => "returned: the caller owns it now".into(),
            OwnKind::FieldOut { from, slot } => format!(
                "taken out of {} (field {slot}), owned on its own",
                self.who(from)
            ),
            OwnKind::Freed { ty, skip } if skip.is_empty() => match ty {
                Some(t) => format!("freed ({})", pretty_ty(t)),
                None => "freed".into(),
            },
            OwnKind::Freed { skip, .. } => {
                let s: Vec<String> = skip.iter().map(|i| i.to_string()).collect();
                format!(
                    "freed, except field{} {} (moved out, or shared with another value)",
                    if skip.len() > 1 { "s" } else { "" },
                    s.join(", ")
                )
            }
        }
    }

    /// The event's source position: its span, or — for a synthesized binding — the binding in
    /// the source, or — for a span covering a whole block — the callee's mention in it.
    fn place(&mut self, e: &OwnEvent) -> Span {
        let mut span = match &e.who {
            Who::Name(n) if e.span == crate::core::NO_SPAN => {
                let n = crate::core::source_name(n);
                find_binding(self.src, n, self.fn_start).map_or(e.span, |a| (a, a + n.len()))
            }
            _ => e.span,
        };
        let (a, b) = unclone(span);
        let multi_line = user_span(span) && self.src.get(a..b).is_some_and(|t| t.contains('\n'));
        if multi_line {
            // a call: its callee's next mention inside the block, after the previous event
            let callee = match &e.kind {
                OwnKind::Moved {
                    to: MoveTo::Callee(g),
                }
                | OwnKind::Lent { to: g } => Some(g.split('$').next().unwrap_or(g).to_string()),
                _ => match &e.who {
                    Who::Made(d) => d.split('`').nth(1).map(str::to_string),
                    _ => None,
                },
            };
            let from = self.last.map_or(a, |l| unclone(l).0.max(a));
            let found =
                callee.and_then(|g| find_word(self.src, &g, from, b).map(|at| (at, at + g.len())));
            if let Some(f) = found {
                span = f;
                self.last = Some(f);
            } else if let Some(l) = self.last {
                span = l;
            }
        } else if user_span(span) {
            self.last = Some(span);
        }
        span
    }

    fn line(&mut self, e: &OwnEvent) -> Line {
        let span = self.place(e);
        let mut names = Vec::new();
        who_names(&e.who, &mut names);
        match &e.kind {
            OwnKind::Moved {
                to: MoveTo::Renamed(y),
            } => names.push(y.clone()),
            OwnKind::FieldOut { from, .. } => who_names(from, &mut names),
            _ => {}
        }
        Line {
            at: user_span(span).then(|| unclone(span).0),
            branch: e.branch.clone(),
            who: self.who(&e.who),
            what: self.what(&e.kind),
            names,
            copy: matches!(e.kind, OwnKind::Copy { .. }),
            partial_free: matches!(&e.kind, OwnKind::Freed { skip, .. } if !skip.is_empty()),
        }
    }
}

/// The report for the user's own functions in `fns` (prelude, imports and generated code left
/// out). `first_spans[i]` is `fns[i]`'s first source span (`delta::first_span`).
pub fn report(fns: &[OwnFn], first_spans: &[Span], src: &str) -> Report {
    let mut cx = Ctx {
        src,
        fn_start: 0,
        last: None,
    };
    let mut rep = Report::default();
    for (f, sp) in fns.iter().zip(first_spans) {
        if generated(&f.name) || !user_span(*sp) {
            continue;
        }
        if f.events.is_empty() {
            if !f.name.starts_with("lam$") {
                rep.plain.push(f.name.clone());
            }
            continue;
        }
        // a function's spans start inside its body: the binding search starts at its definition
        // (the last line before its first span that starts with its name)
        let start = unclone(*sp).0.min(src.len());
        let base = f.name.split('$').next().unwrap_or(&f.name);
        let head_src = src.get(..start).unwrap_or("");
        cx.fn_start = head_src
            .match_indices(&format!("\n{base}"))
            .last()
            .map_or_else(|| head_src.rfind('\n').map_or(0, |i| i + 1), |(i, _)| i + 1);
        cx.last = None;
        let head = if f.name.starts_with("lam$") {
            "a lambda".to_string()
        } else {
            let params: String = f.params.iter().flat_map(|p| [" ", p.as_str()]).collect();
            match f.name.split_once('$') {
                Some((base, inst)) => format!(
                    "{base}{params}   (specialized for {})",
                    inst.trim_start_matches('$').replace('$', " ")
                ),
                None => format!("{}{params}", f.name),
            }
        };
        let lines = f.events.iter().map(|e| cx.line(e)).collect();
        rep.sections.push(Section {
            name: f.name.clone(),
            head,
            start: if f.name.starts_with("lam$") {
                start
            } else {
                cx.fn_start
            },
            lines,
        });
    }
    rep
}

fn pos(lines: &LineMap, at: Option<usize>) -> String {
    match at {
        Some(o) => {
            let (l, c) = lines.pos(o);
            format!("{l}:{c}")
        }
        None => String::new(),
    }
}

/// `--emit ownership`'s text: one block per function, one line per event, then the functions
/// without heap values.
pub fn render(rep: &Report, lines: &LineMap) -> String {
    let mut out = String::new();
    for s in &rep.sections {
        if s.name.starts_with("lam$") {
            out.push_str(&format!("lambda at {}\n", pos(lines, Some(s.start))));
        } else {
            out.push_str(&format!("{}\n", s.head));
        }
        for l in &s.lines {
            let branch = if l.branch.is_empty() {
                String::new()
            } else {
                format!("[{}] ", l.branch.join(" › "))
            };
            out.push_str(&format!(
                "  {:<7} {branch}{} — {}\n",
                pos(lines, l.at),
                l.who,
                l.what
            ));
        }
        out.push('\n');
    }
    if !rep.plain.is_empty() {
        out.push_str(&format!("no heap values: {}\n", rep.plain.join(", ")));
    }
    out
}
