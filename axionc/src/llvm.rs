//! Backend `--release` (§18): baixa o **mesmo Axion Core IR** (ver `core.rs`)
//! para **LLVM IR textual** e compila com `clang -O2 -flto`, ligando um pequeno
//! **runtime C** (`axion_rt.c`) — o `-flto` deixa o LLVM inlinar as operações
//! quentes (bump-alloc, alloc) no chamador. Ao contrário do `inkwell`/`llvm-sys`,
//! não acrescenta dependências de build ao `axionc` (compila com `cargo` puro); o
//! `clang` é só dependência de runtime (`AXION_CLANG`, ou no PATH — p.ex. via nix).
//!
//! Cobre o mesmo subconjunto que o `--dev`/Cranelift: núcleo Int, `if`, chamadas
//! (recursão), `let`, **registos/tuplos** na heap, **strings/IO**, **`case`**,
//! **closures** (env + chamada indirecta), **arenas** (§3) e os `drop` do
//! Auto-Drop. Todos os valores são `i64` (Int, ponteiros, tokens).

use crate::ast;
use crate::ast::Span;
use crate::core::{self, is_int, result_type, Atom, CPat, CoreFn, Op, RecordInfo, Rhs, Term};
use std::collections::HashMap;
use std::collections::HashSet;

/// Tamanho de uma `Cell` de arena (bytes), igual ao runtime.
const CELL_SIZE: i64 = 16;

/// Runtime C, embebido e escrito ao lado do `.ll` para o `clang` compilar.
const RUNTIME_C: &str = include_str!("axion_rt.c");

/// Declarações do runtime (as funções C, com ABI i64 uniforme).
const RT_DECLS: &str = "\
declare void @axion_puts(i64)
declare void @axion_put(i64)
declare i64 @axion_show_int(i64)
declare i64 @axion_alloc(i64)
declare void @axion_free(i64)
declare i64 @axion_arena_new()
declare i64 @axion_arena_alloc(i64, i64)
declare void @axion_arena_reset(i64)
declare i64 @axion_arena_mark(i64)
declare void @axion_arena_release(i64)
declare i64 @axion_arena_promote(i64, i64, i64)
declare i64 @axion_buf_new(i64)
declare i64 @axion_buf_iota(i64)
declare i64 @axion_buf_xor(i64, i64)
declare i64 @axion_buf_sum(i64)
declare void @axion_buf_free(i64)
declare i64 @axion_fold_bytes(i64, i64, i64)
declare i32 @printf(ptr, ...)
";

/// `true` se `main :: Int` (o driver imprime); senão `:: IO ()` (já imprimiu).
fn main_returns_int(module: &ast::Module, entry: &str) -> bool {
    module
        .funcs
        .iter()
        .find(|f| f.name == entry)
        .and_then(|f| f.sig.as_ref())
        .map(|s| is_int(result_type(s)))
        .unwrap_or(false)
}

/// Emite o módulo LLVM IR (texto) a partir do Core (`--emit llvm`).
pub fn emit_ir(module: &ast::Module, inplace: &HashSet<Span>) -> Result<String, String> {
    let fns = core::lower(module, inplace);
    let records = RecordInfo::build(module);
    let main_int = main_returns_int(module, "main");

    // pré-passo: interna os literais de string
    let mut strings: HashMap<String, usize> = HashMap::new();
    for f in &fns {
        collect_strings(&f.body, &mut strings);
    }

    let mut out = String::from("; Axion --release (LLVM IR)\n");
    out.push_str(RT_DECLS);
    // declarações das importações FFI (§18): `declare i64 @name(i64, …)`
    let mut ffi: HashMap<String, usize> = HashMap::new();
    for f in &fns {
        collect_ffi(&f.body, &mut ffi);
    }
    let mut ffi_sorted: Vec<(&String, &usize)> = ffi.iter().collect();
    ffi_sorted.sort();
    for (name, arity) in ffi_sorted {
        let params = vec!["i64"; *arity].join(", ");
        out.push_str(&format!("declare i64 @{name}({params})\n"));
    }
    out.push_str("@.fmt = private unnamed_addr constant [5 x i8] c\"%ld\\0A\\00\"\n");
    // globais das strings
    let mut sorted: Vec<(&String, &usize)> = strings.iter().collect();
    sorted.sort_by_key(|(_, i)| **i);
    for (s, i) in sorted {
        let bytes = encode_cstr(s);
        out.push_str(&format!(
            "@.str{i} = private unnamed_addr constant [{} x i8] c\"{bytes}\"\n",
            s.len() + 1
        ));
    }
    out.push('\n');

    for f in &fns {
        out.push_str(&emit_fn(f, &records, &strings)?);
        out.push('\n');
    }

    // driver: chama `ax_main`; imprime o Int, ou nada se for IO ().
    out.push_str("define i32 @main() {\nentry:\n  %r = call i64 @\"ax_main\"()\n");
    if main_int {
        out.push_str("  call i32 (ptr, ...) @printf(ptr @.fmt, i64 %r)\n");
    }
    out.push_str("  ret i32 0\n}\n");
    Ok(out)
}

/// Compila o Core com `clang -O2 -flto` (+ runtime C) e corre o binário.
pub fn build_and_run(
    module: &ast::Module,
    entry: &str,
    inplace: &HashSet<Span>,
) -> Result<(), String> {
    let fns = core::lower(module, inplace);
    if !fns.iter().any(|f| f.name == entry && f.params.is_empty()) {
        return Err(format!(
            "'{entry}' tem de ser uma função nativa sem parâmetros"
        ));
    }
    let ir = emit_ir(module, inplace)?;

    let dir = std::env::temp_dir();
    let pid = std::process::id();
    let ll = dir.join(format!("axion-{pid}.ll"));
    let rt = dir.join(format!("axion-{pid}-rt.c"));
    let exe = dir.join(format!("axion-{pid}.out"));
    std::fs::write(&ll, ir).map_err(|e| e.to_string())?;
    std::fs::write(&rt, RUNTIME_C).map_err(|e| e.to_string())?;

    let clang = std::env::var("AXION_CLANG").unwrap_or_else(|_| "clang".into());
    let mut cmd = std::process::Command::new(&clang);
    cmd.args(["-O2", "-flto", "-w"])
        .arg(&ll)
        .arg(&rt)
        .arg("-o")
        .arg(&exe);
    // FFI (§18): liga as bibliotecas do utilizador (caminho directo) e grava o
    // seu directório em rpath, para o carregador dinâmico as achar em runtime.
    for lib in module.foreign_libs() {
        let path = std::path::Path::new(&lib);
        if let Some(dir) = path.parent().filter(|d| !d.as_os_str().is_empty()) {
            let dir = std::fs::canonicalize(dir).unwrap_or_else(|_| dir.to_path_buf());
            cmd.arg(format!("-Wl,-rpath,{}", dir.display()));
        }
        cmd.arg(&lib);
    }
    let status = cmd.status().map_err(|e| {
        format!("não consegui invocar '{clang}' ({e}); define AXION_CLANG ou usa nix")
    })?;
    if !status.success() {
        return Err("clang falhou a compilar o LLVM IR".into());
    }
    let run = std::process::Command::new(&exe).status();
    let _ = std::fs::remove_file(&ll);
    let _ = std::fs::remove_file(&rt);
    let _ = std::fs::remove_file(&exe);
    match run {
        Ok(s) if s.success() => Ok(()),
        Ok(s) => Err(format!("o binário --release saiu com {s}")),
        Err(e) => Err(e.to_string()),
    }
}

// --- interning de strings ---

fn collect_strings(t: &Term, out: &mut HashMap<String, usize>) {
    let mut atom = |a: &Atom, out: &mut HashMap<String, usize>| {
        if let Atom::Str(s) = a {
            let n = out.len();
            out.entry(s.clone()).or_insert(n);
        }
    };
    match t {
        Term::Let(_, rhs, body) => {
            collect_rhs(rhs, out, &mut atom);
            collect_strings(body, out);
        }
        Term::Drop(_, _, body) => collect_strings(body, out),
        Term::Ret(rhs) => collect_rhs(rhs, out, &mut atom),
    }
}

fn collect_rhs(
    rhs: &Rhs,
    out: &mut HashMap<String, usize>,
    atom: &mut impl FnMut(&Atom, &mut HashMap<String, usize>),
) {
    match rhs {
        Rhs::Op(op) => op_atoms(op).iter().for_each(|a| atom(a, out)),
        Rhs::If(c, t, e) => {
            atom(c, out);
            collect_strings(t, out);
            collect_strings(e, out);
        }
        Rhs::Case(s, arms) => {
            atom(s, out);
            arms.iter().for_each(|(_, b)| collect_strings(b, out));
        }
    }
}

/// Os átomos que aparecem num `Op` (para o interning de strings).
fn op_atoms(op: &Op) -> Vec<&Atom> {
    match op {
        Op::Atom(a)
        | Op::Field { rec: a, .. }
        | Op::PutStrLn(a)
        | Op::PutStr(a)
        | Op::ShowInt(a) => {
            vec![a]
        }
        Op::LoadRaw(a, _) => vec![a],
        Op::Prim(_, a, b) | Op::Promote(a, b) => vec![a, b],
        Op::CallDirect(_, xs) | Op::MakeTuple(xs) | Op::MakeCon { args: xs, .. } => {
            xs.iter().collect()
        }
        Op::CallClosure(c, xs) => std::iter::once(c).chain(xs).collect(),
        Op::MakeClosure { captures, .. } => captures.iter().collect(),
        Op::MakeRecord { fields, .. } => fields.iter().map(|(_, a)| a).collect(),
        Op::UpdateRecord { base, fields, .. } => std::iter::once(base)
            .chain(fields.iter().map(|(_, a)| a))
            .collect(),
        Op::WithArena { parent, clos } => parent.iter().chain(std::iter::once(clos)).collect(),
        Op::ArenaAlloc(a) | Op::ArenaMark(a) | Op::ArenaRelease(a) => vec![a],
        Op::RtCall { args, .. } | Op::Ffi { args, .. } => args.iter().collect(),
        Op::Unsupported(_) => vec![],
    }
}

/// Recolhe as importações FFI usadas (nome → aridade), para as declarar no IR.
fn collect_ffi(t: &Term, out: &mut HashMap<String, usize>) {
    fn rhs(r: &Rhs, out: &mut HashMap<String, usize>) {
        match r {
            Rhs::Op(Op::Ffi { name, args }) => {
                out.insert(name.clone(), args.len());
            }
            Rhs::Op(_) => {}
            Rhs::If(_, t, e) => {
                collect_ffi(t, out);
                collect_ffi(e, out);
            }
            Rhs::Case(_, arms) => arms.iter().for_each(|(_, b)| collect_ffi(b, out)),
        }
    }
    match t {
        Term::Let(_, r, b) => {
            rhs(r, out);
            collect_ffi(b, out);
        }
        Term::Drop(_, _, b) => collect_ffi(b, out),
        Term::Ret(r) => rhs(r, out),
    }
}

/// Codifica uma string para o formato `c"…"` do LLVM (bytes não seguros → `\XX`).
fn encode_cstr(s: &str) -> String {
    let mut out = String::new();
    for &b in s.as_bytes() {
        if b.is_ascii_graphic() && b != b'"' && b != b'\\' {
            out.push(b as char);
        } else {
            out.push_str(&format!("\\{b:02X}"));
        }
    }
    out.push_str("\\00");
    out
}

// --- emissão de uma função ---

fn emit_fn(
    f: &CoreFn,
    records: &RecordInfo,
    strings: &HashMap<String, usize>,
) -> Result<String, String> {
    let mut e = Emit {
        out: String::new(),
        ssa: 0,
        blk: 0,
        cur_block: "entry".into(),
        scope: HashMap::new(),
        records,
        strings,
    };
    let mut params: Vec<String> = Vec::new();
    if f.is_closure {
        params.push("i64 %env".into());
    }
    for (i, p) in f.params.iter().enumerate() {
        let name = format!("%arg{i}");
        e.scope.insert(p.clone(), name.clone());
        params.push(format!("i64 {name}"));
    }
    let header = format!(
        "define i64 @\"ax_{}\"({}) {{\nentry:\n",
        f.name,
        params.join(", ")
    );
    // carrega as capturas de env[(i+1)*8]
    if f.is_closure {
        for (i, cap) in f.captures.iter().enumerate() {
            let v = e.load("%env", (i as i32 + 1) * 8);
            e.scope.insert(cap.clone(), v);
        }
    }
    let ret = e.term(&f.body)?;
    Ok(format!("{header}{}  ret i64 {ret}\n}}\n", e.out))
}

/// Estado da emissão de uma função.
struct Emit<'a> {
    out: String,
    ssa: u32,
    blk: u32,
    cur_block: String,
    scope: HashMap<String, String>,
    records: &'a RecordInfo,
    strings: &'a HashMap<String, usize>,
}

impl Emit<'_> {
    fn val(&mut self) -> String {
        let v = format!("%v{}", self.ssa);
        self.ssa += 1;
        v
    }
    fn label(&mut self, hint: &str) -> String {
        let l = format!("{hint}{}", self.blk);
        self.blk += 1;
        l
    }
    fn ins(&mut self, s: &str) {
        self.out.push_str("  ");
        self.out.push_str(s);
        self.out.push('\n');
    }
    fn block(&mut self, l: &str) {
        self.out.push_str(l);
        self.out.push_str(":\n");
        self.cur_block = l.to_string();
    }

    /// `load i64` de `base + off` (base é um i64-ponteiro).
    fn load(&mut self, base: &str, off: i32) -> String {
        let p = self.val();
        self.ins(&format!("{p} = inttoptr i64 {base} to ptr"));
        let g = self.val();
        self.ins(&format!("{g} = getelementptr i8, ptr {p}, i64 {off}"));
        let v = self.val();
        self.ins(&format!("{v} = load i64, ptr {g}"));
        v
    }
    fn store(&mut self, base: &str, off: i32, val: &str) {
        let p = self.val();
        self.ins(&format!("{p} = inttoptr i64 {base} to ptr"));
        let g = self.val();
        self.ins(&format!("{g} = getelementptr i8, ptr {p}, i64 {off}"));
        self.ins(&format!("store i64 {val}, ptr {g}"));
    }
    /// Chamada a uma função de runtime (`ret` indica se devolve valor).
    fn rt(&mut self, name: &str, ret: bool, args: &[String]) -> String {
        let a = args
            .iter()
            .map(|x| format!("i64 {x}"))
            .collect::<Vec<_>>()
            .join(", ");
        if ret {
            let r = self.val();
            self.ins(&format!("{r} = call i64 @{name}({a})"));
            r
        } else {
            self.ins(&format!("call void @{name}({a})"));
            "0".into()
        }
    }
    /// Aloca `nslots` × 8 bytes na heap; devolve o ponteiro (i64).
    fn alloc(&mut self, nslots: usize) -> String {
        self.rt("axion_alloc", true, &[(nslots as i64 * 8).to_string()])
    }

    /// Escreve o tag do construtor no offset 0, se o tipo for uma soma (>1 con).
    fn store_tag(&mut self, con: &str, ptr: &str) {
        if let Some(tag) = self.records.tag(con) {
            self.store(ptr, 0, &tag.to_string());
        }
    }

    /// Liga os sub-padrões (variáveis) de um construtor aos seus campos.
    fn destructure_con(&mut self, con: &str, subpats: &[CPat], sval: &str) -> Result<(), String> {
        for (j, p) in subpats.iter().enumerate() {
            match p {
                CPat::Wild => {}
                CPat::Var(n) => {
                    let off = self.records.field_offset(con, j);
                    let v = self.load(sval, off);
                    self.scope.insert(n.clone(), v);
                }
                _ => return Err("padrão aninhado num construtor não compila no --release".into()),
            }
        }
        Ok(())
    }

    fn atom(&self, a: &Atom) -> Result<String, String> {
        match a {
            Atom::Int(n) => Ok(n.to_string()),
            Atom::Var(n) => self
                .scope
                .get(n)
                .cloned()
                .ok_or_else(|| format!("variável '{n}' não ligada no LLVM IR")),
            Atom::Str(s) => {
                let i = self.strings.get(s).ok_or("string não internada")?;
                // constante-expressão: o ponteiro da string como i64
                Ok(format!("ptrtoint (ptr @.str{i} to i64)"))
            }
        }
    }
    fn atoms(&self, xs: &[Atom]) -> Result<Vec<String>, String> {
        xs.iter().map(|a| self.atom(a)).collect()
    }

    fn term(&mut self, t: &Term) -> Result<String, String> {
        match t {
            Term::Let(x, rhs, body) => {
                let v = self.rhs(rhs)?;
                self.scope.insert(x.clone(), v);
                self.term(body)
            }
            Term::Drop(x, ty, body) => {
                // deep-drop: destrutor recursivo se o tipo tem campos de heap;
                // senão, `free` plano.
                let v = self.atom(&Atom::Var(x.clone()))?;
                match ty.as_deref().filter(|t| self.records.needs_deep_drop(t)) {
                    Some(t) => {
                        let r = self.val();
                        self.ins(&format!("{r} = call i64 @\"ax_axion_drop_{t}\"(i64 {v})"));
                    }
                    None => {
                        self.rt("axion_free", false, &[v]);
                    }
                }
                self.term(body)
            }
            Term::Ret(rhs) => self.rhs(rhs),
        }
    }

    fn rhs(&mut self, rhs: &Rhs) -> Result<String, String> {
        match rhs {
            Rhs::Op(op) => self.op(op),
            Rhs::If(cond, then, els) => {
                let c = self.atom(cond)?;
                let c1 = self.val();
                self.ins(&format!("{c1} = icmp ne i64 {c}, 0"));
                let (lt, le, lm) = (self.label("then"), self.label("else"), self.label("merge"));
                self.ins(&format!("br i1 {c1}, label %{lt}, label %{le}"));

                self.block(&lt);
                let tv = self.term(then)?;
                let tb = self.cur_block.clone();
                self.ins(&format!("br label %{lm}"));

                self.block(&le);
                let ev = self.term(els)?;
                let eb = self.cur_block.clone();
                self.ins(&format!("br label %{lm}"));

                self.block(&lm);
                let r = self.val();
                self.ins(&format!("{r} = phi i64 [ {tv}, %{tb} ], [ {ev}, %{eb} ]"));
                Ok(r)
            }
            Rhs::Case(scrut, arms) => {
                let s = self.atom(scrut)?;
                self.case(&s, arms, 0)
            }
        }
    }

    /// `case` como cadeia de `if` (padrões Int/var/`_`/tuplo; catch-all no fim).
    fn case(&mut self, sval: &str, arms: &[(CPat, Term)], i: usize) -> Result<String, String> {
        let (pat, body) = &arms[i];
        match pat {
            CPat::Wild => self.term(body),
            CPat::Var(n) => {
                self.scope.insert(n.clone(), sval.to_string());
                self.term(body)
            }
            CPat::Tuple(ps) => {
                for (j, p) in ps.iter().enumerate() {
                    match p {
                        CPat::Wild => {}
                        CPat::Var(n) => {
                            let v = self.load(sval, j as i32 * 8);
                            self.scope.insert(n.clone(), v);
                        }
                        _ => return Err("padrão de tuplo aninhado não compila no --release".into()),
                    }
                }
                self.term(body)
            }
            CPat::Int(lit) => {
                if i + 1 >= arms.len() {
                    return Err("case sem catch-all não compila no --release".into());
                }
                let c1 = self.val();
                self.ins(&format!("{c1} = icmp eq i64 {sval}, {lit}"));
                let (lt, le, lm) = (self.label("then"), self.label("else"), self.label("merge"));
                self.ins(&format!("br i1 {c1}, label %{lt}, label %{le}"));

                self.block(&lt);
                let tv = self.term(body)?;
                let tb = self.cur_block.clone();
                self.ins(&format!("br label %{lm}"));

                self.block(&le);
                let ev = self.case(sval, arms, i + 1)?;
                let eb = self.cur_block.clone();
                self.ins(&format!("br label %{lm}"));

                self.block(&lm);
                let r = self.val();
                self.ins(&format!("{r} = phi i64 [ {tv}, %{tb} ], [ {ev}, %{eb} ]"));
                Ok(r)
            }
            CPat::Con(con, subpats) => {
                // Tipo de 1 construtor (sem tag) ou último braço: destructura sem
                // testar o tag; senão compara o tag (offset 0) com o do construtor.
                let last = i + 1 >= arms.len();
                match self.records.tag(con) {
                    None => {
                        self.destructure_con(con, subpats, sval)?;
                        self.term(body)
                    }
                    Some(_) if last => {
                        self.destructure_con(con, subpats, sval)?;
                        self.term(body)
                    }
                    Some(tag) => {
                        let ktag = self.load(sval, 0);
                        let c1 = self.val();
                        self.ins(&format!("{c1} = icmp eq i64 {ktag}, {tag}"));
                        let (lt, le, lm) =
                            (self.label("then"), self.label("else"), self.label("merge"));
                        self.ins(&format!("br i1 {c1}, label %{lt}, label %{le}"));

                        self.block(&lt);
                        self.destructure_con(con, subpats, sval)?;
                        let tv = self.term(body)?;
                        let tb = self.cur_block.clone();
                        self.ins(&format!("br label %{lm}"));

                        self.block(&le);
                        let ev = self.case(sval, arms, i + 1)?;
                        let eb = self.cur_block.clone();
                        self.ins(&format!("br label %{lm}"));

                        self.block(&lm);
                        let r = self.val();
                        self.ins(&format!("{r} = phi i64 [ {tv}, %{tb} ], [ {ev}, %{eb} ]"));
                        Ok(r)
                    }
                }
            }
        }
    }

    fn op(&mut self, op: &Op) -> Result<String, String> {
        match op {
            Op::Atom(a) => self.atom(a),
            Op::Prim(o, a, b) => {
                let x = self.atom(a)?;
                let y = self.atom(b)?;
                let (expr, is_cmp) = match o.as_str() {
                    "+" => (format!("add i64 {x}, {y}"), false),
                    "-" => (format!("sub i64 {x}, {y}"), false),
                    "*" => (format!("mul i64 {x}, {y}"), false),
                    "mod" => (format!("srem i64 {x}, {y}"), false),
                    "band" => (format!("and i64 {x}, {y}"), false),
                    "==" => (format!("icmp eq i64 {x}, {y}"), true),
                    "<" => (format!("icmp slt i64 {x}, {y}"), true),
                    ">" => (format!("icmp sgt i64 {x}, {y}"), true),
                    other => return Err(format!("operador '{other}' não compila no --release")),
                };
                let r = self.val();
                self.ins(&format!("{r} = {expr}"));
                if is_cmp {
                    let z = self.val();
                    self.ins(&format!("{z} = zext i1 {r} to i64"));
                    Ok(z)
                } else {
                    Ok(r)
                }
            }
            Op::CallDirect(name, args) => {
                let a = self
                    .atoms(args)?
                    .iter()
                    .map(|v| format!("i64 {v}"))
                    .collect::<Vec<_>>()
                    .join(", ");
                let r = self.val();
                self.ins(&format!("{r} = call i64 @\"ax_{name}\"({a})"));
                Ok(r)
            }
            Op::CallClosure(clos, args) => {
                let c = self.atom(clos)?;
                let fp = self.load(&c, 0);
                let f = self.val();
                self.ins(&format!("{f} = inttoptr i64 {fp} to ptr"));
                let mut vals = vec![format!("i64 {c}")];
                for a in self.atoms(args)? {
                    vals.push(format!("i64 {a}"));
                }
                let r = self.val();
                self.ins(&format!("{r} = call i64 {f}({})", vals.join(", ")));
                Ok(r)
            }
            Op::MakeClosure { func, captures } => {
                let caps = self.atoms(captures)?;
                let env = self.alloc(1 + caps.len());
                self.store(&env, 0, &format!("ptrtoint (ptr @\"ax_{func}\" to i64)"));
                for (i, cv) in caps.iter().enumerate() {
                    self.store(&env, (i as i32 + 1) * 8, cv);
                }
                Ok(env)
            }
            Op::MakeTuple(xs) => {
                let vs = self.atoms(xs)?;
                let ptr = self.alloc(vs.len());
                for (i, v) in vs.iter().enumerate() {
                    self.store(&ptr, i as i32 * 8, v);
                }
                Ok(ptr)
            }
            Op::MakeRecord { con, fields } => {
                let slots = self
                    .records
                    .con_slots(con)
                    .ok_or_else(|| format!("construtor '{con}' desconhecido"))?;
                let ptr = self.alloc(slots);
                self.store_tag(con, &ptr);
                for (fname, a) in fields {
                    let off = self
                        .records
                        .field(fname)
                        .map(|(o, _)| o)
                        .ok_or_else(|| format!("campo '{fname}' desconhecido"))?;
                    let v = self.atom(a)?;
                    self.store(&ptr, off, &v);
                }
                Ok(ptr)
            }
            Op::MakeCon { con, args } => {
                let slots = self
                    .records
                    .con_slots(con)
                    .ok_or_else(|| format!("construtor '{con}' desconhecido"))?;
                let ptr = self.alloc(slots);
                self.store_tag(con, &ptr);
                for (i, a) in args.iter().enumerate() {
                    let off = self.records.field_offset(con, i);
                    let v = self.atom(a)?;
                    self.store(&ptr, off, &v);
                }
                Ok(ptr)
            }
            Op::UpdateRecord {
                base,
                fields,
                inplace,
            } => {
                let base_ptr = self.atom(base)?;
                // Linear Elision (§2): in-place muta o bloco do base; senão aloca
                // um novo e copia.
                let target = if *inplace {
                    base_ptr
                } else {
                    let first = &fields.first().ok_or("actualização vazia")?.0;
                    let nfields = self
                        .records
                        .field(first)
                        .map(|(_, fs)| fs.len())
                        .ok_or_else(|| format!("campo '{first}' desconhecido"))?;
                    let ptr = self.alloc(nfields);
                    for i in 0..nfields {
                        let off = i as i32 * 8;
                        let v = self.load(&base_ptr, off);
                        self.store(&ptr, off, &v);
                    }
                    ptr
                };
                for (fname, a) in fields {
                    let off = self
                        .records
                        .field(fname)
                        .map(|(o, _)| o)
                        .ok_or_else(|| format!("campo '{fname}' desconhecido"))?;
                    let v = self.atom(a)?;
                    self.store(&target, off, &v);
                }
                Ok(target)
            }
            Op::Field { name, rec } => {
                let off = self
                    .records
                    .field(name)
                    .map(|(o, _)| o)
                    .ok_or_else(|| format!("campo '{name}' desconhecido"))?;
                let r = self.atom(rec)?;
                Ok(self.load(&r, off))
            }
            Op::LoadRaw(a, off) => {
                let r = self.atom(a)?;
                Ok(self.load(&r, *off))
            }
            Op::PutStrLn(a) => {
                let v = self.atom(a)?;
                self.rt("axion_puts", false, &[v]);
                Ok("0".into()) // IO () → token
            }
            Op::PutStr(a) => {
                let v = self.atom(a)?;
                self.rt("axion_put", false, &[v]);
                Ok("0".into()) // IO () → token
            }
            Op::ShowInt(a) => {
                let v = self.atom(a)?;
                Ok(self.rt("axion_show_int", true, &[v]))
            }
            // --- arenas (§3) ---
            Op::WithArena { clos, .. } => {
                let cv = self.atom(clos)?;
                let arena = self.rt("axion_arena_new", true, &[]);
                let fp = self.load(&cv, 0);
                let f = self.val();
                self.ins(&format!("{f} = inttoptr i64 {fp} to ptr"));
                let r = self.val();
                self.ins(&format!("{r} = call i64 {f}(i64 {cv}, i64 {arena})"));
                self.rt("axion_arena_reset", false, &[arena]);
                Ok(r)
            }
            Op::ArenaAlloc(a) => {
                let av = self.atom(a)?;
                Ok(self.rt("axion_arena_alloc", true, &[av, CELL_SIZE.to_string()]))
            }
            Op::Promote(t, c) => {
                let tv = self.atom(t)?;
                let cv = self.atom(c)?;
                Ok(self.rt(
                    "axion_arena_promote",
                    true,
                    &[tv, cv, CELL_SIZE.to_string()],
                ))
            }
            Op::ArenaMark(a) => {
                let av = self.atom(a)?;
                Ok(self.rt("axion_arena_mark", true, &[av]))
            }
            Op::ArenaRelease(m) => {
                let mv = self.atom(m)?;
                self.rt("axion_arena_release", false, &[mv]);
                Ok("0".into())
            }
            Op::RtCall {
                func,
                args,
                returns,
            } => {
                let vs = self.atoms(args)?;
                Ok(self.rt(func, *returns, &vs))
            }
            Op::Ffi { name, args } => {
                let a = self
                    .atoms(args)?
                    .iter()
                    .map(|v| format!("i64 {v}"))
                    .collect::<Vec<_>>()
                    .join(", ");
                let r = self.val();
                self.ins(&format!("{r} = call i64 @{name}({a})"));
                Ok(r)
            }
            Op::Unsupported(m) => Err(format!("{m} não compila no --release")),
        }
    }
}
