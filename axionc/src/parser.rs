//! Recursive-descent parser for the L0/L1 subset (see `docs/grammar.md`).
//!
//! Consumes the already-laid-out tokens ([`crate::layout`]) and produces the AST.
//! No error recovery in Phase 1: the first syntax error is reported as
//! `AX0100` and analysis stops (the walking skeleton prioritizes running, not
//! LSP resilience — that comes with the rowan CST in Phase 4).

use crate::ast::*;
use crate::diag::Diagnostic;
use crate::layout::{LSpanned, LTok};
use crate::lexer::Tok;

pub struct Parser<'a> {
    toks: &'a [LSpanned],
    pos: usize,
}

type PResult<T> = Result<T, Diagnostic>;

pub fn parse_module(toks: &[LSpanned]) -> Result<Module, Diagnostic> {
    let mut p = Parser { toks, pos: 0 };
    let items = p.block(Parser::top_item)?;
    let asm = assemble(items);
    Ok(Module {
        funcs: asm.funcs,
        datas: asm.datas,
        foreigns: asm.foreigns,
        classes: asm.classes,
        instances: asm.instances,
    })
}

enum TopItem {
    Sig(String, Vec<(String, String)>, Type),
    Clause(String, Clause),
    Data(DataDecl),
    Foreign(Foreign),
    Class(ClassDecl),
    Instance(InstanceDecl),
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

    // --- blocos com chavetas virtuais ---
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
        let (name, start) = self.var_name("function name")?;
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
        let end = self.span_here().0;
        Ok(DataDecl {
            name,
            params,
            cons,
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
            methods,
            span: (s, end),
        })
    }

    fn parse_con(&mut self) -> PResult<ConDecl> {
        let name = self.con_name("constructor name")?;
        if self.eat(&Tok::LBrace) {
            // construtor com campos nomeados (registo)
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
            // construtor posicional: Con atype*
            let mut fields = Vec::new();
            while self.starts_atype() {
                let ty = self.parse_atype()?;
                fields.push(Field {
                    name: String::new(),
                    ty,
                    mult: Mult::Many,
                });
            }
            Ok(ConDecl { name, fields })
        }
    }

    fn parse_field(&mut self) -> PResult<Field> {
        let (name, _) = self.var_name("field name")?;
        self.expect(&Tok::ColonColon, "'::' in the field")?;
        let ty = self.parse_btype()?;
        // multiplicidade do campo: `campo :: Buffer U8 %1` marca campo linear
        let mult = if let Some(LTok::Tok(Tok::Mult(m))) = self.cur() {
            let m = parse_mult(m);
            self.pos += 1;
            m
        } else {
            Mult::Many
        };
        Ok(Field { name, ty, mult })
    }

    // --- tipos ---
    /// Assinatura possivelmente qualificada: `[Contexto =>] Tipo`. O contexto
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
        // terminal (`... -> Process %1`) marca o resultado linear.
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
            Some(LTok::Tok(Tok::ConId(_)))
                | Some(LTok::Tok(Tok::VarId(_)))
                | Some(LTok::Tok(Tok::LParen))
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
                    Ok(ts.into_iter().next().unwrap())
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
            Some(LTok::Tok(Tok::Int(n))) => {
                let n = *n;
                self.pos += 1;
                Ok(Pat::Int(n, (s, e)))
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
                    Ok(ps.into_iter().next().unwrap())
                } else {
                    Ok(Pat::Tuple(ps, (s, end)))
                }
            }
            _ => Err(self.syntax_err("a pattern")),
        }
    }

    fn parse_pat(&mut self) -> PResult<Pat> {
        // construtor aplicado: Con apat*
        if let Some(LTok::Tok(Tok::ConId(name))) = self.cur() {
            let name = name.clone();
            let (s, _) = self.span_here();
            self.pos += 1;
            let mut args = Vec::new();
            while matches!(
                self.cur(),
                Some(LTok::Tok(Tok::Int(_)))
                    | Some(LTok::Tok(Tok::VarId(_)))
                    | Some(LTok::Tok(Tok::ConId(_)))
                    | Some(LTok::Tok(Tok::LParen))
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
        let lhs = self.parse_cmp()?;
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
        let mut acc = match iter.next().unwrap() {
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

    fn parse_cmp(&mut self) -> PResult<Expr> {
        let mut lhs = self.parse_cons()?;
        while let Some(op) = self.cmp_op() {
            let rhs = self.parse_cons()?;
            let sp = (lhs.span().0, rhs.span().1);
            lhs = Expr::BinOp(op, Box::new(lhs), Box::new(rhs), sp);
        }
        Ok(lhs)
    }

    /// Cons `x : xs` and concatenation `xs ++ ys` (both infixr 5, between `==` and
    /// `+`) → `Cons x xs` / `BinOp "++"`. `++` is polymorphic: lists (append) and
    /// strings (concat) — ver `interp`/`core`.
    fn parse_cons(&mut self) -> PResult<Expr> {
        let lhs = self.parse_add()?;
        if self.at(&Tok::Colon) {
            self.pos += 1;
            let rhs = self.parse_cons()?; // right-associative
            let sp = (lhs.span().0, rhs.span().1);
            Ok(cons_expr(lhs, rhs, sp))
        } else if self.at(&Tok::PlusPlus) {
            self.pos += 1;
            let rhs = self.parse_cons()?; // right-associative
            let sp = (lhs.span().0, rhs.span().1);
            Ok(Expr::BinOp(
                "++".to_string(),
                Box::new(lhs),
                Box::new(rhs),
                sp,
            ))
        } else {
            Ok(lhs)
        }
    }

    fn cmp_op(&mut self) -> Option<String> {
        let op = match self.cur() {
            Some(LTok::Tok(Tok::EqEq)) => "==",
            Some(LTok::Tok(Tok::Lt)) => "<",
            Some(LTok::Tok(Tok::Gt)) => ">",
            _ => return None,
        };
        self.pos += 1;
        Some(op.to_string())
    }

    fn parse_add(&mut self) -> PResult<Expr> {
        let mut lhs = self.parse_mul()?;
        loop {
            let op = if self.at(&Tok::Plus) {
                "+"
            } else if self.at(&Tok::Minus) {
                "-"
            } else {
                break;
            };
            self.pos += 1;
            let rhs = self.parse_mul()?;
            let sp = (lhs.span().0, rhs.span().1);
            lhs = Expr::BinOp(op.to_string(), Box::new(lhs), Box::new(rhs), sp);
        }
        Ok(lhs)
    }

    fn parse_mul(&mut self) -> PResult<Expr> {
        let mut lhs = self.parse_compose()?;
        loop {
            if self.at(&Tok::Star) {
                self.pos += 1;
                let rhs = self.parse_compose()?;
                let sp = (lhs.span().0, rhs.span().1);
                lhs = Expr::BinOp("*".to_string(), Box::new(lhs), Box::new(rhs), sp);
            } else if self.at_v(&LTok::Tok(Tok::Backtick)) {
                self.pos += 1;
                let (op, _) = self.var_name("infix operator")?;
                self.expect(&Tok::Backtick, "closing '`'")?;
                let rhs = self.parse_compose()?;
                let sp = (lhs.span().0, rhs.span().1);
                lhs = Expr::BinOp(op, Box::new(lhs), Box::new(rhs), sp);
            } else {
                break;
            }
        }
        Ok(lhs)
    }

    /// Function composition `f . g` (infixr, almost as tight as application)
    /// → `compose f g`.
    fn parse_compose(&mut self) -> PResult<Expr> {
        let lhs = self.parse_app()?;
        if self.at(&Tok::Dot) {
            self.pos += 1;
            let rhs = self.parse_compose()?; // right-associative
            let sp = (lhs.span().0, rhs.span().1);
            Ok(app2(Expr::Var("compose".to_string(), sp), lhs, rhs, sp))
        } else {
            Ok(lhs)
        }
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
            Some(LTok::Tok(Tok::Int(_)))
                | Some(LTok::Tok(Tok::Str(_)))
                | Some(LTok::Tok(Tok::VarId(_)))
                | Some(LTok::Tok(Tok::ConId(_)))
                | Some(LTok::Tok(Tok::LParen))
                | Some(LTok::Tok(Tok::LBracket))
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

    /// Recognizes an operator section `(op)` — if the current token is an
    /// operador seguido de `)`, consome ambos e devolve o nome do operador.
    fn op_section(&mut self) -> Option<String> {
        let op = match self.cur() {
            Some(LTok::Tok(Tok::Plus)) => "+",
            Some(LTok::Tok(Tok::Minus)) => "-",
            Some(LTok::Tok(Tok::Star)) => "*",
            Some(LTok::Tok(Tok::EqEq)) => "==",
            Some(LTok::Tok(Tok::Lt)) => "<",
            Some(LTok::Tok(Tok::Gt)) => ">",
            _ => return None,
        };
        if matches!(
            self.toks.get(self.pos + 1).map(|t| &t.tok),
            Some(LTok::Tok(Tok::RParen))
        ) {
            self.pos += 2; // op + ')'
            Some(op.to_string())
        } else {
            None
        }
    }

    fn parse_atom_base(&mut self) -> PResult<Expr> {
        let (s, e) = self.span_here();
        match self.cur() {
            Some(LTok::Tok(Tok::Int(n))) => {
                let n = *n;
                self.pos += 1;
                Ok(Expr::Int(n, (s, e)))
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
                    Ok(es.into_iter().next().unwrap())
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

fn parse_mult(s: &str) -> Mult {
    match s.trim_start_matches('%') {
        "1" => Mult::One,
        "0.5" => Mult::Half,
        _ => Mult::Many,
    }
}
