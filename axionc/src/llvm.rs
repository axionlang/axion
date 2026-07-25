//! Backend `--release` (§18): baixa o **mesmo Axión Core IR** (ver `core.rs`)
//! para **LLVM IR textual** e compila com `clang -O2` (otimizações a sério — o
//! que fecha o gap do `-O2` face ao `--dev`/Cranelift). Ao contrário do
//! `inkwell`/`llvm-sys`, isto **não** acrescenta dependências de build ao
//! `axionc` (compila com `cargo` puro); o `clang` é só dependência de runtime
//! (via `AXION_CLANG`, ou no PATH — p.ex. dentro de `nix develop`).
//!
//! **Primeiro corte:** o núcleo **Int** (funções de topo, `Int` params/retorno,
//! aritmética/comparações, `if`, chamadas com recursão, `let`), que não precisa
//! de runtime — suficiente para o benchmark `fib`. Registos/closures/strings/
//! arenas (que precisam do runtime C) crescem a seguir, do mesmo Core.

use crate::ast;
use crate::core::{self, is_int, result_type, Atom, CoreFn, Op, Rhs, Term};
use std::collections::HashMap;

/// Emite o módulo LLVM IR (texto) a partir do Core (`--emit llvm`).
pub fn emit_ir(module: &ast::Module) -> Result<String, String> {
    let fns = core::lower(module);
    let mut out = String::from("; Axión --release (LLVM IR)\n");
    out.push_str("declare i32 @printf(ptr, ...)\n");
    out.push_str("@.fmt = private unnamed_addr constant [5 x i8] c\"%ld\\0A\\00\"\n\n");
    for f in &fns {
        out.push_str(&emit_fn(f)?);
        out.push('\n');
    }
    // driver: chama `ax_main` e imprime o Int (o núcleo suporta main :: Int)
    out.push_str(
        "define i32 @main() {\nentry:\n  %r = call i64 @\"ax_main\"()\n  \
         call i32 (ptr, ...) @printf(ptr @.fmt, i64 %r)\n  ret i32 0\n}\n",
    );
    Ok(out)
}

/// Compila o Core com `clang -O2` e corre o binário resultante (que imprime o
/// resultado de `main :: Int`). Devolve o código de saída do binário.
pub fn build_and_run(module: &ast::Module, entry: &str) -> Result<(), String> {
    let fns = core::lower(module);
    let is_main_int = module
        .funcs
        .iter()
        .find(|f| f.name == entry)
        .and_then(|f| f.sig.as_ref())
        .map(|s| is_int(result_type(s)))
        .unwrap_or(false);
    if !is_main_int {
        return Err("o backend --release só suporta 'main :: Int' (ainda)".into());
    }
    if !fns.iter().any(|f| f.name == entry && f.params.is_empty()) {
        return Err(format!(
            "'{entry}' tem de ser uma função nativa sem parâmetros"
        ));
    }

    let ir = emit_ir(module)?;
    let dir = std::env::temp_dir();
    let ll = dir.join(format!("axion-{}.ll", std::process::id()));
    let exe = dir.join(format!("axion-{}.out", std::process::id()));
    std::fs::write(&ll, ir).map_err(|e| e.to_string())?;

    let clang = std::env::var("AXION_CLANG").unwrap_or_else(|_| "clang".into());
    let status = std::process::Command::new(&clang)
        .args(["-O2", "-w"])
        .arg(&ll)
        .arg("-o")
        .arg(&exe)
        .status()
        .map_err(|e| {
            format!("não consegui invocar '{clang}' ({e}); define AXION_CLANG ou usa nix")
        })?;
    if !status.success() {
        return Err("clang falhou a compilar o LLVM IR".into());
    }
    let run = std::process::Command::new(&exe)
        .status()
        .map_err(|e| e.to_string())?;
    let _ = std::fs::remove_file(&ll);
    let _ = std::fs::remove_file(&exe);
    if !run.success() {
        return Err(format!("o binário --release saiu com {run}"));
    }
    Ok(())
}

/// Emite uma função do Core para LLVM IR (só o núcleo Int).
fn emit_fn(f: &CoreFn) -> Result<String, String> {
    if f.is_closure {
        return Err("closures ainda não compilam no --release".into());
    }
    let mut e = Emit {
        out: String::new(),
        ssa: 0,
        blk: 0,
        cur_block: "entry".into(),
        scope: HashMap::new(),
    };
    // parâmetros: %arg0, %arg1, …
    let params: Vec<String> = f
        .params
        .iter()
        .enumerate()
        .map(|(i, p)| {
            let name = format!("%arg{i}");
            e.scope.insert(p.clone(), name.clone());
            format!("i64 {name}")
        })
        .collect();
    let header = format!(
        "define i64 @\"ax_{}\"({}) {{\nentry:\n",
        f.name,
        params.join(", ")
    );
    let ret = e.term(&f.body)?;
    Ok(format!("{header}{}  ret i64 {ret}\n}}\n", e.out))
}

/// Estado da emissão de uma função.
struct Emit {
    out: String,
    ssa: u32,
    blk: u32,
    cur_block: String,
    scope: HashMap<String, String>,
}

impl Emit {
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

    fn atom(&self, a: &Atom) -> Result<String, String> {
        match a {
            Atom::Int(n) => Ok(n.to_string()),
            Atom::Var(n) => self
                .scope
                .get(n)
                .cloned()
                .ok_or_else(|| format!("variável '{n}' não ligada no LLVM IR")),
            Atom::Str(_) => Err("strings ainda não compilam no --release".into()),
        }
    }

    /// Emite um `Term` e devolve o operando (string) com o seu resultado.
    fn term(&mut self, t: &Term) -> Result<String, String> {
        match t {
            Term::Let(x, rhs, body) => {
                let v = self.rhs(rhs)?;
                self.scope.insert(x.clone(), v);
                self.term(body)
            }
            Term::Drop(_, body) => self.term(body), // núcleo Int não aloca heap
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
            Rhs::Case(_, _) => Err("case ainda não compila no --release".into()),
        }
    }

    fn op(&mut self, op: &Op) -> Result<String, String> {
        match op {
            Op::Atom(a) => self.atom(a),
            Op::Prim(o, a, b) => {
                let x = self.atom(a)?;
                let y = self.atom(b)?;
                let bin = |op: &str| format!("{op} i64 {x}, {y}");
                let cmp = |cc: &str| format!("icmp {cc} i64 {x}, {y}");
                let (expr, is_cmp) = match o.as_str() {
                    "+" => (bin("add"), false),
                    "-" => (bin("sub"), false),
                    "*" => (bin("mul"), false),
                    "mod" => (bin("srem"), false),
                    "band" => (bin("and"), false),
                    "==" => (cmp("eq"), true),
                    "<" => (cmp("slt"), true),
                    ">" => (cmp("sgt"), true),
                    other => return Err(format!("operador '{other}' não compila no --release")),
                };
                let r = self.val();
                self.ins(&format!("{r} = {expr}"));
                if is_cmp {
                    // comparações dão i1; estende-se a i64 (convenção do Core)
                    let z = self.val();
                    self.ins(&format!("{z} = zext i1 {r} to i64"));
                    Ok(z)
                } else {
                    Ok(r)
                }
            }
            Op::CallDirect(name, args) => {
                let avs: Vec<String> = args
                    .iter()
                    .map(|a| self.atom(a).map(|v| format!("i64 {v}")))
                    .collect::<Result<_, _>>()?;
                let r = self.val();
                self.ins(&format!(
                    "{r} = call i64 @\"ax_{name}\"({})",
                    avs.join(", ")
                ));
                Ok(r)
            }
            other => Err(format!(
                "'{}' ainda não compila no --release (só o núcleo Int)",
                core::op_kind(other)
            )),
        }
    }
}
