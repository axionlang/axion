//! Parser recursivo-descendente do subconjunto L0/L1 (ver `docs/grammar.md`).
//!
//! Consome os tokens já com layout ([`crate::layout`]) e produz o AST. Sem
//! recuperação de erros na Fase 1: o primeiro erro de sintaxe é reportado como
//! `AX0100` e a análise pára (o esqueleto ambulante prioriza correr, não a
//! resiliência do LSP — essa vem com o rowan CST na Fase 4).

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
    let (funcs, datas) = assemble(items);
    Ok(Module { funcs, datas })
}

enum TopItem {
    Sig(String, Type),
    Clause(String, Clause),
    Data(DataDecl),
}

/// Junta assinaturas e cláusulas por nome (funções) e separa as `data`.
fn assemble(items: Vec<TopItem>) -> (Vec<Func>, Vec<DataDecl>) {
    let mut funcs: Vec<Func> = Vec::new();
    let mut datas: Vec<DataDecl> = Vec::new();
    let mut index: std::collections::HashMap<String, usize> = std::collections::HashMap::new();
    for it in items {
        match it {
            TopItem::Data(d) => datas.push(d),
            TopItem::Sig(name, ty) => {
                let sp = (0, 0);
                let i = *index.entry(name.clone()).or_insert_with(|| {
                    funcs.push(Func {
                        name: name.clone(),
                        sig: None,
                        clauses: Vec::new(),
                        span: sp,
                    });
                    funcs.len() - 1
                });
                funcs[i].sig = Some(ty);
            }
            TopItem::Clause(name, clause) => {
                let sp = clause.span;
                let i = *index.entry(name.clone()).or_insert_with(|| {
                    funcs.push(Func {
                        name: name.clone(),
                        sig: None,
                        clauses: Vec::new(),
                        span: sp,
                    });
                    funcs.len() - 1
                });
                if funcs[i].span == (0, 0) {
                    funcs[i].span = sp;
                }
                funcs[i].clauses.push(clause);
            }
        }
    }
    (funcs, datas)
}

/// Como `assemble`, mas para blocos `where`/`let` (só funções).
fn merge_funcs(items: Vec<TopItem>) -> Vec<Func> {
    assemble(items).0
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
            Some(LTok::VLBrace) => "início de bloco".into(),
            Some(LTok::VSemi) => "fim de declaração".into(),
            Some(LTok::VRBrace) => "fim de bloco".into(),
            None => "fim do ficheiro".into(),
        };
        Diagnostic::error(
            "AX0100",
            format!("erro de sintaxe: esperava {what}, encontrei {got}"),
        )
        .label(s, e, "inesperado aqui")
    }

    // --- blocos com chavetas virtuais ---
    fn block<T>(&mut self, mut item: impl FnMut(&mut Self) -> PResult<T>) -> PResult<Vec<T>> {
        self.expect_v(&LTok::VLBrace, "início de bloco")?;
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

    // --- declarações de topo (assinatura ou cláusula) ---
    fn top_item(&mut self) -> PResult<TopItem> {
        if self.at(&Tok::Data) {
            return Ok(TopItem::Data(self.parse_data()?));
        }
        let (name, start) = self.var_name("nome de função")?;
        if self.eat(&Tok::ColonColon) {
            let ty = self.parse_type()?;
            Ok(TopItem::Sig(name, ty))
        } else {
            // cláusula: padrões até '=' ou '|'
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
                self.expect(&Tok::Equals, "'=' após a guarda")?;
                let res = self.parse_expr()?;
                arms.push((guard, res));
            }
            Ok(Body::Guarded(arms))
        } else {
            self.expect(&Tok::Equals, "'=' na definição")?;
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

    // --- declarações de dados / registos ---
    fn parse_data(&mut self) -> PResult<DataDecl> {
        let (s, _) = self.span_here();
        self.bump(); // 'data'
        let name = self.con_name("nome do tipo")?;
        // parâmetros de tipo (ex.: `data Maybe a`) — ignorados na Fase 1
        while matches!(self.cur(), Some(LTok::Tok(Tok::VarId(_)))) {
            self.pos += 1;
        }
        self.expect(&Tok::Equals, "'=' na declaração 'data'")?;
        let mut cons = vec![self.parse_con()?];
        while self.eat(&Tok::Bar) {
            cons.push(self.parse_con()?);
        }
        let end = self.span_here().0;
        Ok(DataDecl {
            name,
            cons,
            span: (s, end),
        })
    }

    fn parse_con(&mut self) -> PResult<ConDecl> {
        let name = self.con_name("nome do construtor")?;
        if self.eat(&Tok::LBrace) {
            // construtor com campos nomeados (registo)
            let mut fields = Vec::new();
            if !self.at(&Tok::RBrace) {
                fields.push(self.parse_field()?);
                while self.eat(&Tok::Comma) {
                    fields.push(self.parse_field()?);
                }
            }
            self.expect(&Tok::RBrace, "'}' no registo")?;
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
        let (name, _) = self.var_name("nome do campo")?;
        self.expect(&Tok::ColonColon, "'::' no campo")?;
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
    fn parse_type(&mut self) -> PResult<Type> {
        let from = self.parse_btype()?;
        // multiplicidade: numa seta (`A %1 -> B`) marca o parâmetro; num tipo
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
            // `%1` num tipo de retorno (sem seta a seguir): a análise de
            // parâmetros só olha às setas, por isso a anotação é ignorada aqui.
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
                self.expect(&Tok::RParen, "')' no tipo")?;
                if ts.len() == 1 {
                    Ok(ts.into_iter().next().unwrap())
                } else {
                    Ok(Type::Tuple(ts))
                }
            }
            _ => Err(self.syntax_err("um tipo")),
        }
    }

    // --- padrões ---
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
                self.pos += 1;
                let p = self.parse_pat()?;
                self.expect(&Tok::RParen, "')' no padrão")?;
                Ok(p)
            }
            _ => Err(self.syntax_err("um padrão")),
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

    // --- expressões ---
    fn parse_expr(&mut self) -> PResult<Expr> {
        match self.cur() {
            Some(LTok::Tok(Tok::If)) => self.parse_if(),
            Some(LTok::Tok(Tok::Let)) => self.parse_let(),
            Some(LTok::Tok(Tok::Case)) => self.parse_case(),
            Some(LTok::Tok(Tok::Backslash)) => self.parse_lam(),
            _ => self.parse_cmp(),
        }
    }

    fn parse_lam(&mut self) -> PResult<Expr> {
        let (s, _) = self.span_here();
        self.bump(); // '\'
        let mut pats = Vec::new();
        while !self.at(&Tok::Arrow) {
            pats.push(self.parse_apat()?);
        }
        self.expect(&Tok::Arrow, "'->' na lambda")?;
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
        self.expect(&Tok::In, "'in' após o bloco 'let'")?;
        let body = self.parse_expr()?;
        let end = self.span_here().0;
        Ok(Expr::Let(binds, Box::new(body), (s, end)))
    }

    fn parse_case(&mut self) -> PResult<Expr> {
        let (s, _) = self.span_here();
        self.bump(); // case
        let scrut = self.parse_expr()?;
        self.expect(&Tok::Of, "'of' no case")?;
        let arms = self.block(|p| {
            let pat = p.parse_pat()?;
            p.expect(&Tok::Arrow, "'->' no ramo do case")?;
            let body = p.parse_expr()?;
            Ok((pat, body))
        })?;
        let end = self.span_here().0;
        Ok(Expr::Case(Box::new(scrut), arms, (s, end)))
    }

    fn parse_cmp(&mut self) -> PResult<Expr> {
        let mut lhs = self.parse_add()?;
        while let Some(op) = self.cmp_op() {
            let rhs = self.parse_add()?;
            let sp = (lhs.span().0, rhs.span().1);
            lhs = Expr::BinOp(op, Box::new(lhs), Box::new(rhs), sp);
        }
        Ok(lhs)
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
        let mut lhs = self.parse_app()?;
        loop {
            if self.at(&Tok::Star) {
                self.pos += 1;
                let rhs = self.parse_app()?;
                let sp = (lhs.span().0, rhs.span().1);
                lhs = Expr::BinOp("*".to_string(), Box::new(lhs), Box::new(rhs), sp);
            } else if self.at_v(&LTok::Tok(Tok::Backtick)) {
                self.pos += 1;
                let (op, _) = self.var_name("operador infixo")?;
                self.expect(&Tok::Backtick, "'`' de fecho")?;
                let rhs = self.parse_app()?;
                let sp = (lhs.span().0, rhs.span().1);
                lhs = Expr::BinOp(op, Box::new(lhs), Box::new(rhs), sp);
            } else {
                break;
            }
        }
        Ok(lhs)
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
        )
    }

    fn parse_atom(&mut self) -> PResult<Expr> {
        let (s, _) = self.span_here();
        let mut base = self.parse_atom_base()?;
        // registos ligam mais forte do que a aplicação: `Con { ... }` constrói,
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
        self.expect(&Tok::LBrace, "'{' no registo")?;
        let mut fields = Vec::new();
        if !self.at(&Tok::RBrace) {
            fields.push(self.parse_field_assign()?);
            while self.eat(&Tok::Comma) {
                fields.push(self.parse_field_assign()?);
            }
        }
        self.expect(&Tok::RBrace, "'}' no registo")?;
        Ok(fields)
    }

    fn parse_field_assign(&mut self) -> PResult<(String, Expr)> {
        let (name, _) = self.var_name("nome do campo")?;
        self.expect(&Tok::Equals, "'=' no campo do registo")?;
        let value = self.parse_expr()?;
        Ok((name, value))
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
                let mut es = vec![self.parse_expr()?];
                while self.eat(&Tok::Comma) {
                    es.push(self.parse_expr()?);
                }
                self.expect(&Tok::RParen, "')' na expressão")?;
                let end = self.span_here().0;
                if es.len() == 1 {
                    Ok(es.into_iter().next().unwrap())
                } else {
                    Ok(Expr::Tuple(es, (s, end)))
                }
            }
            _ => Err(self.syntax_err("uma expressão")),
        }
    }
}

fn parse_mult(s: &str) -> Mult {
    match s.trim_start_matches('%') {
        "1" => Mult::One,
        "0.5" => Mult::Half,
        _ => Mult::Many,
    }
}
