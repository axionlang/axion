//! Recursive-descent parser for the L0/L1 subset (see `docs/grammar.md`).
//!
//! Consumes the already-laid-out tokens ([`crate::layout`]) and produces the AST.
//! [`parse_module`] fails on the first syntax error (used for the prelude/imports,
//! which are trusted). [`parse_module_resilient`] recovers at top-level declaration
//! boundaries — a malformed declaration is reported but the others still parse — so
//! the LSP keeps analysing the rest of a half-typed file (§8).

use crate::ast::{
    Body, ClassDecl, Clause, ConDecl, DataDecl, Expr, Field, Foreign, Func, ImportDecl,
    InstanceDecl, Module, Mult, Pat, Span, Type,
};
use crate::diag::Diagnostic;
use crate::layout::{LSpanned, LTok};
use crate::lexer::{IntLit, Tok};
use std::collections::HashMap;

/// Operator associativity for infix resolution (`infixl`/`infixr`/`infix`).
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Assoc {
    Left,
    Right,
    /// `infix N` — non-associative; treated left-grouping here (no chaining error yet).
    Non,
}

/// A module's user-declared operator fixities: operator/backtick-name → (precedence 0–9,
/// associativity). Built-in operators are NOT stored here (they are fixed in [`op_fixity`]).
pub type FixityTable = HashMap<String, (u8, Assoc)>;

/// The (precedence, associativity) of a binary operator, driving the precedence-climbing
/// expression parser shared by both front ends. Built-in operators keep the historical
/// ladder (`.`=9r, `*`=7l, `+`=6l, `:`/`++`=5r, comparisons=4l); a user operator or
/// backtick function uses the module's `infix*` declarations, defaulting to `infixl 9`
/// for a symbolic operator and `infixl 7` for an (undeclared) backtick name — the level
/// backtick infix has always had, so existing code is unaffected. `$` (0r) is parsed
/// separately (its rhs is a full expression, so `f $ \x -> …` works).
pub fn op_fixity(op: &str, user: &FixityTable) -> (u8, Assoc) {
    match op {
        "." => (9, Assoc::Right),
        "*" | "*." | "/." => (7, Assoc::Left),
        "+" | "-" | "+." | "-." => (6, Assoc::Left),
        ":" | "++" => (5, Assoc::Right),
        "==" | "<" | ">" | "==." | "<." | ">." => (4, Assoc::Left),
        _ => user.get(op).copied().unwrap_or_else(|| {
            let symbolic = op.chars().next().is_some_and(|c| !c.is_alphabetic() && c != '_');
            if symbolic {
                (9, Assoc::Left)
            } else {
                (7, Assoc::Left)
            }
        }),
    }
}

/// Pre-scan the laid-out token stream for `infixl`/`infixr`/`infix N op[, op…]`
/// declarations, building the module's fixity table. A pre-scan (rather than
/// threading state through the parse) mirrors Haskell: a fixity declaration applies
/// module-wide regardless of where it appears relative to the operator's uses.
pub fn scan_fixities(toks: &[LSpanned]) -> FixityTable {
    let mut table = FixityTable::new();
    let mut i = 0;
    while i < toks.len() {
        let assoc = match &toks[i].tok {
            LTok::Tok(Tok::VarId(kw)) => match kw.as_str() {
                "infixl" => Some(Assoc::Left),
                "infixr" => Some(Assoc::Right),
                "infix" => Some(Assoc::Non),
                _ => None,
            },
            _ => None,
        };
        let Some(assoc) = assoc else {
            i += 1;
            continue;
        };
        let Some(LTok::Tok(Tok::Int(IntLit::Small(p)))) = toks.get(i + 1).map(|s| &s.tok) else {
            i += 1;
            continue;
        };
        let prec = (*p).clamp(0, 9) as u8;
        let mut j = i + 2;
        loop {
            match toks.get(j).map(|s| &s.tok) {
                Some(LTok::Tok(Tok::Op(o))) => {
                    table.insert(o.clone(), (prec, assoc));
                    j += 1;
                }
                Some(LTok::Tok(Tok::Backtick)) => {
                    if let Some(LTok::Tok(Tok::VarId(n))) = toks.get(j + 1).map(|s| &s.tok) {
                        table.insert(n.clone(), (prec, assoc));
                        j += 3; // ` name `
                    } else {
                        break;
                    }
                }
                _ => break,
            }
            if matches!(toks.get(j).map(|s| &s.tok), Some(LTok::Tok(Tok::Comma))) {
                j += 1;
            } else {
                break;
            }
        }
        i = j;
    }
    table
}

pub struct Parser<'a> {
    toks: &'a [LSpanned],
    pos: usize,
    /// Errors recovered at declaration boundaries (resilient parse only).
    errors: Vec<Diagnostic>,
    /// Module-wide operator fixities (from `infix*` declarations), pre-scanned.
    fixities: FixityTable,
}

type PResult<T> = Result<T, Diagnostic>;

fn build_module(items: Vec<TopItem>) -> Module {
    let mut mod_name = None;
    let mut imports = Vec::new();
    let mut decls = Vec::with_capacity(items.len());
    for it in items {
        match it {
            TopItem::ModuleName(n) => mod_name = Some(n),
            TopItem::Import(i) => imports.push(i),
            other => decls.push(other),
        }
    }
    let asm = assemble(decls);
    Module {
        name: mod_name,
        imports,
        funcs: asm.funcs,
        datas: asm.datas,
        foreigns: asm.foreigns,
        classes: asm.classes,
        instances: asm.instances,
        level_ceiling: None, // filled from the source pragma in main.rs
    }
}

pub fn parse_module(toks: &[LSpanned]) -> Result<Module, Diagnostic> {
    let mut p = Parser {
        toks,
        pos: 0,
        errors: Vec::new(),
        fixities: scan_fixities(toks),
    };
    let items = p.block(Parser::top_item)?;
    Ok(build_module(items))
}

/// Parse a module with declaration-level error recovery: a top-level declaration
/// that fails to parse is skipped (its error collected), and parsing resumes at the
/// next declaration boundary. Returns the partial module plus the recovered errors,
/// so downstream analysis still runs over the well-formed declarations.
pub fn parse_module_resilient(toks: &[LSpanned]) -> (Module, Vec<Diagnostic>) {
    let mut p = Parser {
        toks,
        pos: 0,
        errors: Vec::new(),
        fixities: scan_fixities(toks),
    };
    let items = p.block_recover(Parser::top_item);
    let errors = std::mem::take(&mut p.errors);
    (build_module(items), errors)
}

enum TopItem {
    ModuleName(Vec<String>),
    Import(ImportDecl),
    Sig(String, Vec<(String, String)>, Type),
    Clause(String, Clause),
    Data(DataDecl),
    Foreign(Foreign),
    Class(ClassDecl),
    Instance(InstanceDecl),
    /// A fixity declaration (`infixl 6 <+>`) — consumed so it isn't mis-parsed as a
    /// function; the actual table is built by the [`scan_fixities`] pre-scan.
    Fixity,
}

#[derive(Default)]
struct Assembled {
    funcs: Vec<Func>,
    datas: Vec<DataDecl>,
    foreigns: Vec<Foreign>,
    classes: Vec<ClassDecl>,
    instances: Vec<InstanceDecl>,
}

/// Joins signatures and clauses by name (functions) and separates the
/// `data`/`foreign`/`class`/`instance`.
fn assemble(items: Vec<TopItem>) -> Assembled {
    let mut asm = Assembled::default();
    let mut index: std::collections::HashMap<String, usize> = std::collections::HashMap::new();
    for it in items {
        match it {
            TopItem::ModuleName(_) | TopItem::Import(_) | TopItem::Fixity => {} // collected/ignored
            TopItem::Foreign(f) => asm.foreigns.push(f),
            TopItem::Data(d) => asm.datas.push(d),
            TopItem::Class(c) => asm.classes.push(c),
            TopItem::Instance(i) => asm.instances.push(i),
            TopItem::Sig(name, constraints, ty) => {
                let sp = (0, 0);
                let i = *index.entry(name.clone()).or_insert_with(|| {
                    asm.funcs.push(Func {
                        name: name.clone(),
                        sig: None,
                        constraints: Vec::new(),
                        clauses: Vec::new(),
                        span: sp,
                    });
                    asm.funcs.len() - 1
                });
                asm.funcs[i].sig = Some(ty);
                asm.funcs[i].constraints = constraints;
            }
            TopItem::Clause(name, clause) => {
                let sp = clause.span;
                let i = *index.entry(name.clone()).or_insert_with(|| {
                    asm.funcs.push(Func {
                        name: name.clone(),
                        sig: None,
                        constraints: Vec::new(),
                        clauses: Vec::new(),
                        span: sp,
                    });
                    asm.funcs.len() - 1
                });
                if asm.funcs[i].span == (0, 0) {
                    asm.funcs[i].span = sp;
                }
                asm.funcs[i].clauses.push(clause);
            }
        }
    }
    asm
}

/// Like `assemble`, but for `where`/`let` blocks (functions only).
fn merge_funcs(items: Vec<TopItem>) -> Vec<Func> {
    assemble(items).funcs
}

/// Extracts the `(class, var)` constraints from a class context: `Eq a` →
/// `[(Eq, a)]`; `(Eq a, Ord b)` → `[(Eq, a), (Ord, b)]`. Unexpected forms are
/// ignored (the context is advice for the discharge, not critical).
fn context_constraints(t: &Type) -> Vec<(String, String)> {
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
    let mut out = Vec::new();
    one(t, &mut out);
    out
}

/// A statement of a `do` block.
enum Stmt {
    Bind(Pat, Expr), // `pat <- e`  (var ou tuplo, p.ex. `(x, c) <- recv c`)
    Expr(Expr),      // `e`
}

impl<'a> Parser<'a> {
    // --- primitivas ---
    fn cur(&self) -> Option<&LTok> {
        self.toks.get(self.pos).map(|s| &s.tok)
    }

    fn span_here(&self) -> Span {
        match self.toks.get(self.pos) {
            Some(s) => (s.start, s.end),
            None => self.toks.last().map(|s| (s.end, s.end)).unwrap_or((0, 0)),
        }
    }

    fn bump(&mut self) -> Option<&'a LSpanned> {
        let t = self.toks.get(self.pos);
        if t.is_some() {
            self.pos += 1;
        }
        t
    }

    fn at(&self, t: &Tok) -> bool {
        matches!(self.cur(), Some(LTok::Tok(x)) if x == t)
    }

    fn eat(&mut self, t: &Tok) -> bool {
        if self.at(t) {
            self.pos += 1;
            true
        } else {
            false
        }
    }

    fn at_v(&self, v: &LTok) -> bool {
        matches!(self.cur(), Some(x) if x == v)
    }

    /// The current token is the contextual keyword `kw` (a lowercase identifier
    /// that is not a real reserved token, e.g. `deriving`).
    fn at_kw(&self, kw: &str) -> bool {
        matches!(self.cur(), Some(LTok::Tok(Tok::VarId(k))) if k == kw)
    }

    fn expect(&mut self, t: &Tok, what: &str) -> PResult<()> {
        if self.eat(t) {
            Ok(())
        } else {
            Err(self.syntax_err(what))
        }
    }

    fn syntax_err(&self, what: &str) -> Diagnostic {
        let (s, e) = self.span_here();
        let got = match self.cur() {
            Some(LTok::Tok(t)) => format!("{t:?}"),
            Some(LTok::VLBrace) => "start of block".into(),
            Some(LTok::VSemi) => "end of declaration".into(),
            Some(LTok::VRBrace) => "end of block".into(),
            None => "end of file".into(),
        };
        Diagnostic::error(
            "AX0100",
            format!("syntax error: expected {what}, found {got}"),
        )
        .label(s, e, "unexpected here")
    }

    // --- blocks with virtual braces ---
    fn block<T>(&mut self, mut item: impl FnMut(&mut Self) -> PResult<T>) -> PResult<Vec<T>> {
        self.expect_v(&LTok::VLBrace, "start of block")?;
        let mut items = Vec::new();
        loop {
            while self.at_v(&LTok::VSemi) {
                self.pos += 1;
            }
            if self.at_v(&LTok::VRBrace) || self.cur().is_none() {
                break;
            }
            items.push(item(self)?);
            while self.at_v(&LTok::VSemi) {
                self.pos += 1;
            }
            if self.at_v(&LTok::VRBrace) || self.cur().is_none() {
                break;
            }
        }
        self.eat_v(&LTok::VRBrace);
        Ok(items)
    }

    /// Like [`Parser::block`] but recovers: when an item fails, its error is
    /// collected and parsing skips to the next declaration boundary (a layout
    /// `VSemi`/`VRBrace`) instead of aborting the whole block. Used for the
    /// top-level module so one broken declaration does not discard the rest.
    fn block_recover<T>(&mut self, mut item: impl FnMut(&mut Self) -> PResult<T>) -> Vec<T> {
        if !self.eat_v(&LTok::VLBrace) {
            return Vec::new();
        }
        let mut items = Vec::new();
        loop {
            while self.at_v(&LTok::VSemi) {
                self.pos += 1;
            }
            if self.at_v(&LTok::VRBrace) || self.cur().is_none() {
                break;
            }
            let start = self.pos;
            match item(self) {
                Ok(it) => items.push(it),
                Err(e) => {
                    self.errors.push(e);
                    // Guarantee progress even if the item consumed nothing.
                    if self.pos == start {
                        self.pos += 1;
                    }
                    self.recover_to_decl_boundary();
                }
            }
            while self.at_v(&LTok::VSemi) {
                self.pos += 1;
            }
            if self.at_v(&LTok::VRBrace) || self.cur().is_none() {
                break;
            }
        }
        self.eat_v(&LTok::VRBrace);
        items
    }

    /// Skip tokens up to (not past) the next top-level declaration boundary.
    fn recover_to_decl_boundary(&mut self) {
        while self.cur().is_some() && !self.at_v(&LTok::VSemi) && !self.at_v(&LTok::VRBrace) {
            self.pos += 1;
        }
    }

    fn expect_v(&mut self, v: &LTok, what: &str) -> PResult<()> {
        if self.eat_v(v) {
            Ok(())
        } else {
            Err(self.syntax_err(what))
        }
    }

    fn eat_v(&mut self, v: &LTok) -> bool {
        if self.at_v(v) {
            self.pos += 1;
            true
        } else {
            false
        }
    }

    // --- top-level declarations (signature or clause) ---
    fn top_item(&mut self) -> PResult<TopItem> {
        if self.at(&Tok::Module) {
            return Ok(TopItem::ModuleName(self.parse_module_name()?));
        }
        if self.at(&Tok::Import) {
            return Ok(TopItem::Import(self.parse_import()?));
        }
        if self.at(&Tok::Data) {
            return Ok(TopItem::Data(self.parse_data()?));
        }
        if self.at(&Tok::Class) {
            return Ok(TopItem::Class(self.parse_class()?));
        }
        if self.at(&Tok::Instance) {
            return Ok(TopItem::Instance(self.parse_instance()?));
        }
        if self.at(&Tok::Foreign) {
            let start = self.span_here().0;
            self.bump(); // foreign
                         // caminho de biblioteca opcional: `foreign "libfoo.so" nome :: …`
            let lib = if let Some(LTok::Tok(Tok::Str(v))) = self.cur() {
                let v = v.clone();
                self.bump();
                Some(v)
            } else {
                None
            };
            let (name, _) = self.var_name("name of the foreign import")?;
            self.expect(&Tok::ColonColon, "'::' in the foreign import")?;
            let sig = self.parse_type()?;
            let end = self.span_here().0;
            return Ok(TopItem::Foreign(Foreign {
                name,
                sig,
                lib,
                span: (start, end),
            }));
        }
        // fixity declaration: `infixl 6 <+>` / `infixr 5 <>, <|>`. Recognized by a
        // keyword-like leading `VarId` immediately followed by an integer precedence (so a
        // user function named `infixl` is not shadowed). Consumed and ignored — the table
        // was already built by the `scan_fixities` pre-scan.
        if let Some(LTok::Tok(Tok::VarId(kw))) = self.cur() {
            if matches!(kw.as_str(), "infixl" | "infixr" | "infix")
                && matches!(
                    self.toks.get(self.pos + 1).map(|t| &t.tok),
                    Some(LTok::Tok(Tok::Int(IntLit::Small(_))))
                )
            {
                self.parse_fixity_decl();
                return Ok(TopItem::Fixity);
            }
        }
        // a parenthesized operator names a function: `(<+>) :: …` / `(<+>) x y = …`.
        let (name, start) = match self.paren_op_name() {
            Some(nm) => nm,
            None => self.var_name("function name")?,
        };
        if self.eat(&Tok::ColonColon) {
            let (constraints, ty) = self.parse_qualified_type()?;
            Ok(TopItem::Sig(name, constraints, ty))
        } else {
            // clause: patterns up to '=' or '|'
            let mut pats = Vec::new();
            while !self.at(&Tok::Equals) && !self.at(&Tok::Bar) {
                pats.push(self.parse_apat()?);
            }
            let body = self.parse_rhs()?;
            let wher = if self.at(&Tok::Where) {
                self.bump();
                self.block(Parser::top_item).map(merge_funcs)?
            } else {
                Vec::new()
            };
            let end = self.span_here().0;
            Ok(TopItem::Clause(
                name,
                Clause {
                    pats,
                    body,
                    wher,
                    span: (start, end),
                },
            ))
        }
    }

    fn parse_module_name(&mut self) -> PResult<Vec<String>> {
        self.bump(); // module
        let mut path = Vec::new();
        loop {
            let name = match self.cur() {
                Some(LTok::Tok(Tok::ConId(n) | Tok::VarId(n))) => {
                    let n = n.clone();
                    self.bump();
                    n
                }
                _ => {
                    return Err(self.syntax_err("module name"));
                }
            };
            path.push(name);
            if !self.eat(&Tok::Dot) {
                break;
            }
        }
        self.expect(&Tok::Where, "'where' after module declaration")?;
        // consume the nested VLBrace that the layout rule inserts for the
        // module body (a `where` block); the outer `block()` loop will then
        // see the first real item as expected.
        self.eat_v(&LTok::VLBrace);
        Ok(path)
    }

    fn parse_import(&mut self) -> PResult<ImportDecl> {
        self.bump(); // import
        let qualified = self.eat(&Tok::Qualified);
        let mut module = Vec::new();
        loop {
            let name = match self.cur() {
                Some(LTok::Tok(Tok::ConId(n) | Tok::VarId(n))) => {
                    let n = n.clone();
                    self.bump();
                    n
                }
                _ => {
                    return Err(self.syntax_err("module name in import"));
                }
            };
            module.push(name);
            if !self.eat(&Tok::Dot) {
                break;
            }
        }
        let alias = if self.eat(&Tok::As) {
            let name = match self.cur() {
                Some(LTok::Tok(Tok::ConId(n) | Tok::VarId(n))) => {
                    let n = n.clone();
                    self.bump();
                    n
                }
                _ => return Err(self.syntax_err("alias name")),
            };
            Some(name)
        } else {
            None
        };
        let end = self.span_here().0;
        Ok(ImportDecl {
            module,
            qualified,
            alias,
            span: (0, end),
        })
    }

    fn parse_rhs(&mut self) -> PResult<Body> {
        if self.at(&Tok::Bar) {
            let mut arms = Vec::new();
            while self.eat(&Tok::Bar) {
                let guard = self.parse_expr()?;
                self.expect(&Tok::Equals, "'=' after the guard")?;
                let res = self.parse_expr()?;
                arms.push((guard, res));
            }
            Ok(Body::Guarded(arms))
        } else {
            self.expect(&Tok::Equals, "'=' in the definition")?;
            Ok(Body::Plain(self.parse_expr()?))
        }
    }

    fn var_name(&mut self, what: &str) -> PResult<(String, usize)> {
        let start = self.span_here().0;
        match self.cur() {
            Some(LTok::Tok(Tok::VarId(n))) => {
                let n = n.clone();
                self.pos += 1;
                Ok((n, start))
            }
            _ => Err(self.syntax_err(what)),
        }
    }

    fn con_name(&mut self, what: &str) -> PResult<String> {
        match self.cur() {
            Some(LTok::Tok(Tok::ConId(n))) => {
                let n = n.clone();
                self.pos += 1;
                Ok(n)
            }
            _ => Err(self.syntax_err(what)),
        }
    }

    // --- data / record declarations ---
    fn parse_data(&mut self) -> PResult<DataDecl> {
        let (s, _) = self.span_here();
        self.bump(); // 'data'
        let name = self.con_name("type name")?;
        // type parameters (e.g. `a` in `data List a`)
        let mut params = Vec::new();
        while let Some(LTok::Tok(Tok::VarId(p))) = self.cur() {
            params.push(p.clone());
            self.pos += 1;
        }
        self.expect(&Tok::Equals, "'=' in the 'data' declaration")?;
        let mut cons = vec![self.parse_con()?];
        while self.eat(&Tok::Bar) {
            cons.push(self.parse_con()?);
        }
        // optional `deriving (C1, C2, …)` clause.
        let mut deriving = Vec::new();
        if matches!(self.cur(), Some(LTok::Tok(Tok::VarId(k))) if k == "deriving") {
            self.pos += 1;
            self.expect(&Tok::LParen, "'(' after 'deriving'")?;
            loop {
                deriving.push(self.con_name("class name in 'deriving'")?);
                if !self.eat(&Tok::Comma) {
                    break;
                }
            }
            self.expect(&Tok::RParen, "')' to close 'deriving'")?;
        }
        let end = self.span_here().0;
        Ok(DataDecl {
            name,
            params,
            cons,
            deriving,
            span: (s, end),
        })
    }

    /// `class C a where { m :: T ; … }` — method signatures only in the body.
    fn parse_class(&mut self) -> PResult<ClassDecl> {
        let (s, _) = self.span_here();
        self.bump(); // 'class'
        let name = self.con_name("class name")?;
        let (tyvar, _) = self.var_name("class type variable")?;
        self.expect(&Tok::Where, "'where' in the class")?;
        let methods = self.block(|p| {
            let (m, _) = p.var_name("method name")?;
            p.expect(&Tok::ColonColon, "'::' in the method signature")?;
            let ty = p.parse_type()?;
            Ok((m, ty))
        })?;
        let end = self.span_here().0;
        Ok(ClassDecl {
            name,
            tyvar,
            methods,
            span: (s, end),
        })
    }

    /// `instance C T where { clauses }` — `T` is the type head (a ConId, or an
    /// applied/parenthesized type from which the head is extracted: `Maybe`, `List`, …).
    fn parse_instance(&mut self) -> PResult<InstanceDecl> {
        let (s, _) = self.span_here();
        self.bump(); // 'instance'
                     // optional context: `Eq a =>` (as in `instance Eq a => Eq (Maybe a)`).
        let save = self.pos;
        let ctx = self.parse_btype()?;
        let constraints = if self.eat(&Tok::FatArrow) {
            context_constraints(&ctx)
        } else {
            self.pos = save;
            Vec::new()
        };
        let class_name = self.con_name("class name in the instance")?;
        let head_ty = self.parse_atype()?;
        let ty_head = head_ty
            .head_con()
            .ok_or_else(|| self.syntax_err("type head in the instance"))?
            .to_string();
        self.expect(&Tok::Where, "'where' in the instance")?;
        let methods = self.block(Parser::top_item).map(merge_funcs)?;
        let end = self.span_here().0;
        Ok(InstanceDecl {
            class_name,
            ty_head,
            head_ty,
            constraints,
            methods,
            span: (s, end),
        })
    }

    fn parse_con(&mut self) -> PResult<ConDecl> {
        let name = self.con_name("constructor name")?;
        if self.eat(&Tok::LBrace) {
            // constructor with named fields (record)
            let mut fields = Vec::new();
            if !self.at(&Tok::RBrace) {
                fields.push(self.parse_field()?);
                while self.eat(&Tok::Comma) {
                    fields.push(self.parse_field()?);
                }
            }
            self.expect(&Tok::RBrace, "'}' in the record")?;
            Ok(ConDecl { name, fields })
        } else {
            // positional constructor: Con atype*.  A positional field
            // wrapped in parens `(Box %1)` has the `%1` consumed inside
            // `parse_type` (the LParen branch of `parse_atype`) — walk
            // the parens manually so the multiplicities are visible.
            let mut fields = Vec::new();
            while self.starts_atype() && !self.at_kw("deriving") {
                let (ty, mult) = if self.at(&Tok::LParen) {
                    self.bump(); // (
                    let t = self.parse_btype()?;
                    let m = if let Some(LTok::Tok(Tok::Mult(mul))) = self.cur() {
                        let m = parse_mult(mul);
                        self.pos += 1;
                        m
                    } else {
                        Mult::Many
                    };
                    self.expect(&Tok::RParen, "')' in the field type")?;
                    (t, m)
                } else {
                    let t = self.parse_atype()?;
                    let m = if let Some(LTok::Tok(Tok::Mult(mul))) = self.cur() {
                        let m = parse_mult(mul);
                        self.pos += 1;
                        m
                    } else {
                        Mult::Many
                    };
                    (t, m)
                };
                fields.push(Field {
                    name: String::new(),
                    ty,
                    mult,
                });
            }
            Ok(ConDecl { name, fields })
        }
    }

    fn parse_field(&mut self) -> PResult<Field> {
        let (name, _) = self.var_name("field name")?;
        self.expect(&Tok::ColonColon, "'::' in the field")?;
        let ty = self.parse_btype()?;
        // field multiplicity: `field :: Buffer U8 %1` marks a linear field
        let mult = if let Some(LTok::Tok(Tok::Mult(m))) = self.cur() {
            let m = parse_mult(m);
            self.pos += 1;
            m
        } else {
            Mult::Many
        };
        Ok(Field { name, ty, mult })
    }

    // --- types ---
    /// Possibly qualified signature: `[Context =>] Type`. The context
    /// (`C a` or `(C a, D b)`) is RETAINED as a list of constraints, to
    /// discharge the method obligations. Backtracks if there is no `=>`.
    fn parse_qualified_type(&mut self) -> PResult<(Vec<(String, String)>, Type)> {
        let save = self.pos;
        let ctx = self.parse_btype()?;
        if self.eat(&Tok::FatArrow) {
            let cs = context_constraints(&ctx);
            let ty = self.parse_type()?;
            Ok((cs, ty))
        } else {
            self.pos = save;
            Ok((Vec::new(), self.parse_type()?))
        }
    }

    fn parse_type(&mut self) -> PResult<Type> {
        let from = self.parse_btype()?;
        // multiplicity: on an arrow (`A %1 -> B`) it marks the parameter; on a
        // terminal (`... -> Process %1`) marks the linear result.
        if let Some(LTok::Tok(Tok::Mult(m))) = self.cur() {
            let mult = parse_mult(m);
            self.pos += 1;
            if self.eat(&Tok::Arrow) {
                let to = self.parse_type()?;
                return Ok(Type::Arrow {
                    mult,
                    from: Box::new(from),
                    to: Box::new(to),
                });
            }
            // `%1` on a return type (no arrow following): parameter analysis
            // only looks at arrows, so the annotation is ignored here.
            return Ok(from);
        }
        if self.eat(&Tok::Arrow) {
            let to = self.parse_type()?;
            return Ok(Type::Arrow {
                mult: Mult::Many,
                from: Box::new(from),
                to: Box::new(to),
            });
        }
        Ok(from)
    }

    fn parse_btype(&mut self) -> PResult<Type> {
        let mut t = self.parse_atype()?;
        while self.starts_atype() {
            let arg = self.parse_atype()?;
            t = Type::App(Box::new(t), Box::new(arg));
        }
        Ok(t)
    }

    fn starts_atype(&self) -> bool {
        matches!(
            self.cur(),
            Some(LTok::Tok(Tok::ConId(_) | Tok::VarId(_) | Tok::LParen))
        )
    }

    fn parse_atype(&mut self) -> PResult<Type> {
        match self.cur() {
            Some(LTok::Tok(Tok::ConId(n))) => {
                let n = n.clone();
                self.pos += 1;
                Ok(Type::Con(n))
            }
            Some(LTok::Tok(Tok::VarId(n))) => {
                let n = n.clone();
                self.pos += 1;
                Ok(Type::Var(n))
            }
            Some(LTok::Tok(Tok::LParen)) => {
                self.pos += 1;
                if self.eat(&Tok::RParen) {
                    return Ok(Type::Unit);
                }
                let mut ts = vec![self.parse_type()?];
                while self.eat(&Tok::Comma) {
                    ts.push(self.parse_type()?);
                }
                self.expect(&Tok::RParen, "')' in the type")?;
                if ts.len() == 1 {
                    Ok(ts
                        .into_iter()
                        .next()
                        .ok_or_else(|| self.syntax_err("empty"))?)
                } else {
                    Ok(Type::Tuple(ts))
                }
            }
            _ => Err(self.syntax_err("a type")),
        }
    }

    // --- patterns ---
    fn parse_apat(&mut self) -> PResult<Pat> {
        let (s, e) = self.span_here();
        match self.cur() {
            Some(LTok::Tok(Tok::Int(crate::lexer::IntLit::Small(n)))) => {
                let n = *n;
                self.pos += 1;
                Ok(Pat::Int(n, (s, e)))
            }
            Some(LTok::Tok(Tok::Int(crate::lexer::IntLit::Big(_)))) => {
                Err(self.syntax_err("an integer within Int (a literal exceeding Int \
                                     can't appear in a pattern — use a guard)"))
            }
            Some(LTok::Tok(Tok::VarId(name))) => {
                let name = name.clone();
                self.pos += 1;
                if name == "_" {
                    Ok(Pat::Wild((s, e)))
                } else {
                    Ok(Pat::Var(name, (s, e)))
                }
            }
            Some(LTok::Tok(Tok::ConId(name))) => {
                let name = name.clone();
                self.pos += 1;
                Ok(Pat::Con(name, Vec::new(), (s, e)))
            }
            Some(LTok::Tok(Tok::LParen)) => {
                let (s, _) = self.span_here();
                self.pos += 1;
                let mut ps = vec![self.parse_pat()?];
                while self.eat(&Tok::Comma) {
                    ps.push(self.parse_pat()?);
                }
                self.expect(&Tok::RParen, "')' in the pattern")?;
                let end = self.span_here().0;
                if ps.len() == 1 {
                    Ok(ps
                        .into_iter()
                        .next()
                        .ok_or_else(|| self.syntax_err("empty"))?)
                } else {
                    Ok(Pat::Tuple(ps, (s, end)))
                }
            }
            _ => Err(self.syntax_err("a pattern")),
        }
    }

    fn parse_pat(&mut self) -> PResult<Pat> {
        // applied constructor: Con apat*
        if let Some(LTok::Tok(Tok::ConId(name))) = self.cur() {
            let name = name.clone();
            let (s, _) = self.span_here();
            self.pos += 1;
            let mut args = Vec::new();
            while matches!(
                self.cur(),
                Some(LTok::Tok(
                    Tok::Int(_) | Tok::VarId(_) | Tok::ConId(_) | Tok::LParen
                ))
            ) {
                args.push(self.parse_apat()?);
            }
            let e = self.span_here().0;
            Ok(Pat::Con(name, args, (s, e)))
        } else {
            self.parse_apat()
        }
    }

    // --- expressions ---
    fn parse_expr(&mut self) -> PResult<Expr> {
        match self.cur() {
            Some(LTok::Tok(Tok::If)) => self.parse_if(),
            Some(LTok::Tok(Tok::Let)) => self.parse_let(),
            Some(LTok::Tok(Tok::Case)) => self.parse_case(),
            Some(LTok::Tok(Tok::Backslash)) => self.parse_lam(),
            Some(LTok::Tok(Tok::Do)) => self.parse_do(),
            _ => self.parse_dollar(),
        }
    }

    /// `f $ x` = `f x` — low-precedence application, right-associative.
    fn parse_dollar(&mut self) -> PResult<Expr> {
        let lhs = self.parse_ops(0)?;
        if self.at(&Tok::Dollar) {
            self.bump();
            let rhs = self.parse_expr()?;
            let sp = (lhs.span().0, rhs.span().1);
            Ok(Expr::App(Box::new(lhs), Box::new(rhs), sp))
        } else {
            Ok(lhs)
        }
    }

    /// `do` block: sequential (strict) desugaring via `case` — the `case`
    /// scrutinee is evaluated strictly (forces the effect), unlike a `let`.
    /// `x <- e; resto` → `case e of x -> resto`; `e; resto` → `case e of _ ->
    /// rest`; the last statement is the block's value.
    fn parse_do(&mut self) -> PResult<Expr> {
        let (s, _) = self.span_here();
        self.bump(); // do
        let stmts = self.block(Parser::parse_stmt)?;
        let sp = (s, self.span_here().0);
        if stmts.is_empty() {
            return Err(self.syntax_err("empty do block"));
        }
        let mut iter = stmts.into_iter().rev();
        let mut acc = match iter
            .next()
            .ok_or_else(|| self.syntax_err("empty do block"))?
        {
            Stmt::Expr(e) => e,
            Stmt::Bind(..) => return Err(self.syntax_err("do block ending in <-")),
        };
        for stmt in iter {
            let (pat, e) = match stmt {
                Stmt::Bind(pat, e) => (pat, e),
                Stmt::Expr(e) => (Pat::Wild(sp), e),
            };
            acc = Expr::Case(Box::new(e), vec![(pat, acc)], sp);
        }
        Ok(acc)
    }

    /// A `do` statement: `pat <- expr` (bind; `pat` is a var or tuple) or
    /// `expr` (effect/value). Tries the pattern speculatively and backtracks if
    /// houver `<-`.
    fn parse_stmt(&mut self) -> PResult<Stmt> {
        let save = self.pos;
        if let Ok(pat) = self.parse_apat() {
            if self.eat(&Tok::LArrow) {
                return Ok(Stmt::Bind(pat, self.parse_expr()?));
            }
        }
        self.pos = save; // backtrack: it was an expression, not a bind
        Ok(Stmt::Expr(self.parse_expr()?))
    }

    fn parse_lam(&mut self) -> PResult<Expr> {
        let (s, _) = self.span_here();
        self.bump(); // '\'
        let mut pats = Vec::new();
        while !self.at(&Tok::Arrow) {
            pats.push(self.parse_apat()?);
        }
        self.expect(&Tok::Arrow, "'->' in the lambda")?;
        let body = self.parse_expr()?;
        let end = self.span_here().0;
        Ok(Expr::Lam(pats, Box::new(body), (s, end)))
    }

    fn parse_if(&mut self) -> PResult<Expr> {
        let (s, _) = self.span_here();
        self.bump(); // if
        let c = self.parse_expr()?;
        self.expect(&Tok::Then, "'then'")?;
        let t = self.parse_expr()?;
        self.expect(&Tok::Else, "'else'")?;
        let e = self.parse_expr()?;
        let end = self.span_here().0;
        Ok(Expr::If(Box::new(c), Box::new(t), Box::new(e), (s, end)))
    }

    fn parse_let(&mut self) -> PResult<Expr> {
        let (s, _) = self.span_here();
        self.bump(); // let
        let binds = self.block(Parser::top_item).map(merge_funcs)?;
        self.expect(&Tok::In, "'in' after the 'let' block")?;
        let body = self.parse_expr()?;
        let end = self.span_here().0;
        Ok(Expr::Let(binds, Box::new(body), (s, end)))
    }

    fn parse_case(&mut self) -> PResult<Expr> {
        let (s, _) = self.span_here();
        self.bump(); // case
        let scrut = self.parse_expr()?;
        self.expect(&Tok::Of, "'of' in the case")?;
        let arms = self.block(|p| {
            let pat = p.parse_pat()?;
            p.expect(&Tok::Arrow, "'->' in the case arm")?;
            let body = p.parse_expr()?;
            Ok((pat, body))
        })?;
        let end = self.span_here().0;
        Ok(Expr::Case(Box::new(scrut), arms, (s, end)))
    }

    /// The whole binary-operator layer (everything between `$` and application),
    /// resolved by precedence climbing over [`op_fixity`] — built-in operators keep the
    /// historical ladder and user operators use the module's `infix*` declarations. Cons
    /// `:` and compose `.` desugar exactly as before; `++`/arithmetic/comparison stay
    /// `BinOp`. Application is the tightest primary; `$` is handled above (in
    /// `parse_dollar`) so its right-hand side can be a full expression.
    fn parse_ops(&mut self, min_prec: u8) -> PResult<Expr> {
        let mut lhs = self.parse_app()?;
        while let Some((op, width)) = self.peek_infix_op() {
            let (prec, assoc) = op_fixity(&op, &self.fixities);
            if prec < min_prec {
                break;
            }
            self.pos += width;
            let next_min = if assoc == Assoc::Right { prec } else { prec + 1 };
            let rhs = self.parse_ops(next_min)?;
            let sp = (lhs.span().0, rhs.span().1);
            lhs = make_binop(op, lhs, rhs, sp);
        }
        Ok(lhs)
    }

    /// The infix operator at the cursor (built-in symbolic token, user `Op`, or a
    /// `` `name` `` backtick function) and how many tokens it spans — without consuming.
    /// `.`/`$` note: `$` is intentionally excluded (parsed in `parse_dollar`); `.` (Dot)
    /// is the compose operator.
    fn peek_infix_op(&self) -> Option<(String, usize)> {
        let name = match self.cur()? {
            LTok::Tok(Tok::Dot) => ".",
            LTok::Tok(Tok::Star) => "*",
            LTok::Tok(Tok::StarDot) => "*.",
            LTok::Tok(Tok::SlashDot) => "/.",
            LTok::Tok(Tok::Plus) => "+",
            LTok::Tok(Tok::Minus) => "-",
            LTok::Tok(Tok::PlusDot) => "+.",
            LTok::Tok(Tok::MinusDot) => "-.",
            LTok::Tok(Tok::Colon) => ":",
            LTok::Tok(Tok::PlusPlus) => "++",
            LTok::Tok(Tok::EqEq) => "==",
            LTok::Tok(Tok::Lt) => "<",
            LTok::Tok(Tok::Gt) => ">",
            LTok::Tok(Tok::EqEqDot) => "==.",
            LTok::Tok(Tok::LtDot) => "<.",
            LTok::Tok(Tok::GtDot) => ">.",
            LTok::Tok(Tok::Op(s)) => return Some((s.clone(), 1)),
            LTok::Tok(Tok::Backtick) => {
                // ` name ` — require the CLOSING backtick, else this is malformed: return
                // `None` so the climber leaves the stray ` for the surrounding parser to
                // flag (the fixed ladder used to set `ok`/error on a missing close).
                return match (
                    self.toks.get(self.pos + 1).map(|t| &t.tok),
                    self.toks.get(self.pos + 2).map(|t| &t.tok),
                ) {
                    (Some(LTok::Tok(Tok::VarId(n))), Some(LTok::Tok(Tok::Backtick))) => {
                        Some((n.clone(), 3))
                    }
                    _ => None,
                };
            }
            _ => return None,
        };
        Some((name.to_string(), 1))
    }

    fn parse_app(&mut self) -> PResult<Expr> {
        let mut f = self.parse_atom()?;
        while self.starts_atom() {
            let arg = self.parse_atom()?;
            let sp = (f.span().0, arg.span().1);
            f = Expr::App(Box::new(f), Box::new(arg), sp);
        }
        Ok(f)
    }

    fn starts_atom(&self) -> bool {
        matches!(
            self.cur(),
            Some(LTok::Tok(
                Tok::Int(_)
                    | Tok::Float(_)
                    | Tok::Str(_)
                    | Tok::VarId(_)
                    | Tok::ConId(_)
                    | Tok::LParen
                    | Tok::LBracket
            ))
        )
    }

    fn parse_atom(&mut self) -> PResult<Expr> {
        let (s, _) = self.span_here();
        let mut base = self.parse_atom_base()?;
        // records bind tighter than application: `Con { ... }` constructs,
        // `expr { ... }` actualiza (Listagem 2.1).
        while self.at(&Tok::LBrace) {
            let fields = self.parse_record_fields()?;
            let end = self.span_here().0;
            base = match base {
                Expr::Con(name, _) => Expr::RecordCon(name, fields, (s, end)),
                other => Expr::RecordUpd(Box::new(other), fields, (s, end)),
            };
        }
        Ok(base)
    }

    fn parse_record_fields(&mut self) -> PResult<Vec<(String, Expr)>> {
        self.expect(&Tok::LBrace, "'{' in the record")?;
        let mut fields = Vec::new();
        if !self.at(&Tok::RBrace) {
            fields.push(self.parse_field_assign()?);
            while self.eat(&Tok::Comma) {
                fields.push(self.parse_field_assign()?);
            }
        }
        self.expect(&Tok::RBrace, "'}' in the record")?;
        Ok(fields)
    }

    fn parse_field_assign(&mut self) -> PResult<(String, Expr)> {
        let (name, _) = self.var_name("field name")?;
        self.expect(&Tok::Equals, "'=' in the record field")?;
        let value = self.parse_expr()?;
        Ok((name, value))
    }

    /// The operator name if the token at `self.pos + off` is an operator — a
    /// built-in symbolic token or a user-defined `Op` (`<+>`, `>>>`, …) — without
    /// consuming anything. The single source of truth for "which tokens are operators".
    fn peek_operator(&self, off: usize) -> Option<String> {
        match self.toks.get(self.pos + off).map(|t| &t.tok) {
            Some(LTok::Tok(Tok::Plus)) => Some("+".into()),
            Some(LTok::Tok(Tok::Minus)) => Some("-".into()),
            Some(LTok::Tok(Tok::Star)) => Some("*".into()),
            Some(LTok::Tok(Tok::EqEq)) => Some("==".into()),
            Some(LTok::Tok(Tok::Lt)) => Some("<".into()),
            Some(LTok::Tok(Tok::Gt)) => Some(">".into()),
            Some(LTok::Tok(Tok::Op(s))) => Some(s.clone()),
            _ => None,
        }
    }

    /// Recognizes an operator section `(op)` — if the current token is an
    /// operator followed by `)`, consumes both and returns the operator name.
    fn op_section(&mut self) -> Option<String> {
        let op = self.peek_operator(0)?;
        if matches!(
            self.toks.get(self.pos + 1).map(|t| &t.tok),
            Some(LTok::Tok(Tok::RParen))
        ) {
            self.pos += 2; // op + ')'
            Some(op)
        } else {
            None
        }
    }

    /// A parenthesized operator used as a name — the head of an operator
    /// definition or signature: `(<+>) :: …` / `(<+>) x y = …`. Consumes `( op )`.
    fn paren_op_name(&mut self) -> Option<(String, usize)> {
        let start = self.span_here().0;
        if !self.at_v(&LTok::Tok(Tok::LParen)) {
            return None;
        }
        // only USER operators name a definition (`(<+>) x y = …`); the built-in
        // operators (`+`, `<`, …) are reserved, so they aren't accepted here (this
        // mirrors the CST parser's `top_decl`, keeping the two parsers in lock-step).
        let op = match self.toks.get(self.pos + 1).map(|t| &t.tok) {
            Some(LTok::Tok(Tok::Op(s))) => s.clone(),
            _ => return None,
        };
        if matches!(
            self.toks.get(self.pos + 2).map(|t| &t.tok),
            Some(LTok::Tok(Tok::RParen))
        ) {
            self.pos += 3; // '(' op ')'
            Some((op, start))
        } else {
            None
        }
    }

    /// Consume a fixity declaration `infix[l|r] <prec> <op>[, <op>]*` (the operators are
    /// `Op` tokens or `` `name` `` backtick names). The data was captured by the pre-scan,
    /// so this only advances past the tokens; mirrors [`scan_fixities`]'s consumption.
    fn parse_fixity_decl(&mut self) {
        self.pos += 2; // keyword + precedence int
        loop {
            match self.toks.get(self.pos).map(|t| &t.tok) {
                Some(LTok::Tok(Tok::Op(_))) => self.pos += 1,
                Some(LTok::Tok(Tok::Backtick))
                    if matches!(
                        self.toks.get(self.pos + 1).map(|t| &t.tok),
                        Some(LTok::Tok(Tok::VarId(_)))
                    ) =>
                {
                    self.pos += 3; // ` name `
                }
                _ => break,
            }
            if matches!(self.cur(), Some(LTok::Tok(Tok::Comma))) {
                self.pos += 1;
            } else {
                break;
            }
        }
    }

    fn parse_atom_base(&mut self) -> PResult<Expr> {
        let (s, e) = self.span_here();
        match self.cur() {
            Some(LTok::Tok(Tok::Int(crate::lexer::IntLit::Small(n)))) => {
                let n = *n;
                self.pos += 1;
                Ok(Expr::Int(n, (s, e)))
            }
            // a literal exceeding i64 → an arbitrary-precision Integer, desugared to
            // `bignumFromStr "digits"` (reuses the String literal + builtin machinery).
            Some(LTok::Tok(Tok::Int(crate::lexer::IntLit::Big(digits)))) => {
                let digits = digits.clone();
                self.pos += 1;
                Ok(Expr::App(
                    Box::new(Expr::Var("bignumFromStr".into(), (s, e))),
                    Box::new(Expr::Str(digits, (s, e))),
                    (s, e),
                ))
            }
            Some(LTok::Tok(Tok::Float(f))) => {
                let f = *f;
                self.pos += 1;
                Ok(Expr::Float(f, (s, e)))
            }
            Some(LTok::Tok(Tok::Str(v))) => {
                let v = v.clone();
                self.pos += 1;
                Ok(Expr::Str(v, (s, e)))
            }
            Some(LTok::Tok(Tok::VarId(n))) => {
                let n = n.clone();
                self.pos += 1;
                Ok(Expr::Var(n, (s, e)))
            }
            Some(LTok::Tok(Tok::ConId(n))) => {
                let n = n.clone();
                self.pos += 1;
                Ok(Expr::Con(n, (s, e)))
            }
            Some(LTok::Tok(Tok::LParen)) => {
                self.pos += 1;
                // operator section `(+)` `(-)` `(*)` `(==)` `(<)` `(>)` →
                // `\a b -> a op b` (a first-class function value).
                if let Some(op) = self.op_section() {
                    let end = self.span_here().0;
                    let sp = (s, end);
                    let (a, b) = ("_op0".to_string(), "_op1".to_string());
                    let body = Expr::BinOp(
                        op,
                        Box::new(Expr::Var(a.clone(), sp)),
                        Box::new(Expr::Var(b.clone(), sp)),
                        sp,
                    );
                    return Ok(Expr::Lam(
                        vec![Pat::Var(a, sp), Pat::Var(b, sp)],
                        Box::new(body),
                        sp,
                    ));
                }
                let mut es = vec![self.parse_expr()?];
                while self.eat(&Tok::Comma) {
                    es.push(self.parse_expr()?);
                }
                self.expect(&Tok::RParen, "')' in the expression")?;
                let end = self.span_here().0;
                if es.len() == 1 {
                    Ok(es
                        .into_iter()
                        .next()
                        .ok_or_else(|| self.syntax_err("empty"))?)
                } else {
                    Ok(Expr::Tuple(es, (s, end)))
                }
            }
            Some(LTok::Tok(Tok::LBracket)) => {
                self.pos += 1;
                // `[]` → Nil
                if self.eat(&Tok::RBracket) {
                    return Ok(Expr::Con("Nil".to_string(), (s, self.span_here().0)));
                }
                let first = self.parse_expr()?;
                // intervalo `[a..b]` → `range a b`
                if self.eat(&Tok::DotDot) {
                    let hi = self.parse_expr()?;
                    self.expect(&Tok::RBracket, "']' in the range")?;
                    let sp = (s, self.span_here().0);
                    return Ok(app2(Expr::Var("range".to_string(), sp), first, hi, sp));
                }
                // literal `[e1, e2, …]` → `Cons e1 (Cons e2 … Nil)`
                let mut elems = vec![first];
                while self.eat(&Tok::Comma) {
                    elems.push(self.parse_expr()?);
                }
                self.expect(&Tok::RBracket, "']' in the list")?;
                let sp = (s, self.span_here().0);
                let mut list = Expr::Con("Nil".to_string(), sp);
                for e in elems.into_iter().rev() {
                    list = cons_expr(e, list, sp);
                }
                Ok(list)
            }
            _ => Err(self.syntax_err("an expression")),
        }
    }
}

/// `App(App(head, a), b)` — binary application.
fn app2(head: Expr, a: Expr, b: Expr, sp: Span) -> Expr {
    Expr::App(
        Box::new(Expr::App(Box::new(head), Box::new(a), sp)),
        Box::new(b),
        sp,
    )
}

/// `x : xs` → `Cons x xs`.
fn cons_expr(x: Expr, xs: Expr, sp: Span) -> Expr {
    app2(Expr::Con("Cons".to_string(), sp), x, xs, sp)
}

/// Combine an infix operator with its operands, applying the same desugars the fixed
/// ladder used: `:` → `Cons`, `.` → `compose`, everything else (`++`, arithmetic,
/// comparisons, user operators, backtick functions) → `BinOp`. `$` never reaches here.
fn make_binop(op: String, l: Expr, r: Expr, sp: Span) -> Expr {
    match op.as_str() {
        ":" => cons_expr(l, r, sp),
        "." => app2(Expr::Var("compose".to_string(), sp), l, r, sp),
        _ => Expr::BinOp(op, Box::new(l), Box::new(r), sp),
    }
}

fn parse_mult(s: &str) -> Mult {
    match s.trim_start_matches('%') {
        "1" => Mult::One,
        "0.5" => Mult::Half,
        _ => Mult::Many,
    }
}
