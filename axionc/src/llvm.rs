//! `--release` backend (§18): lowers the **same Axion Core IR** (see `core.rs`)
//! to **textual LLVM IR** and compiles with `clang -O2 -flto`, linking a small
//! **C runtime** (`axion_rt.c`) — `-flto` lets LLVM inline the hot
//! operations (bump-alloc, alloc) into the caller. Unlike `inkwell`/`llvm-sys`,
//! it adds no build dependencies to `axionc` (builds with pure `cargo`);
//! `clang` is only a runtime dependency (`AXION_CLANG`, or on PATH — e.g. via nix).
//!
//! Covers the same subset as `--dev`/Cranelift: Int core, `if`, calls
//! (recursion), `let`, **records/tuples** on the heap, **strings/IO**, **`case`**,
//! **closures** (env + indirect call), **arenas** (§3) and the Auto-Drop
//! `drop`s. All values are `i64` (Int, pointers, tokens).

use crate::ast;
use crate::ast::Span;
use crate::core::{
    self, is_bool, is_float, is_int, result_type, Atom, CPat, CoreFn, Op, RecordInfo, Rhs, Term,
};
use std::collections::HashMap;
use std::collections::HashSet;

/// Size of an arena `Cell` (bytes), equal to the runtime.
const CELL_SIZE: i64 = 16;

/// C runtime, embedded and written next to the `.ll` for `clang` to compile.
const RUNTIME_C: &str = include_str!("axion_rt.c");

/// Runtime declarations (the C functions, with a uniform i64 ABI).
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
declare i64 @axion_sess_new()
declare i64 @axion_sess_channel(i64)
declare void @axion_sess_send(i64, i64, i64)
declare i64 @axion_sess_pending(i64, i64)
declare i64 @axion_sess_recv(i64, i64)
declare i64 @axion_sess_alloc(i64, i64)
declare void @axion_sess_spawn(i64, i64, i64)
declare i64 @axion_sess_run(i64, i64, i64)
declare i32 @printf(ptr, ...)
";

/// `true` if `main :: Int` (the driver prints); otherwise `:: IO ()` (already printed).
fn main_returns_int(module: &ast::Module, entry: &str) -> bool {
    module
        .funcs
        .iter()
        .find(|f| f.name == entry)
        .and_then(|f| f.sig.as_ref())
        .map(|s| is_int(result_type(s)))
        .unwrap_or(false)
}

/// `true` if `main :: Float` — the driver reinterprets the i64 ABI value as a
/// double and prints it (`%g`).
fn main_returns_float(module: &ast::Module, entry: &str) -> bool {
    module
        .funcs
        .iter()
        .find(|f| f.name == entry)
        .and_then(|f| f.sig.as_ref())
        .map(|s| is_float(result_type(s)))
        .unwrap_or(false)
}

/// `true` if `main :: Bool` — the driver prints `true`/`false` (like the
/// interpreter) by selecting between two string constants.
fn main_returns_bool(module: &ast::Module, entry: &str) -> bool {
    module
        .funcs
        .iter()
        .find(|f| f.name == entry)
        .and_then(|f| f.sig.as_ref())
        .map(|s| is_bool(result_type(s)))
        .unwrap_or(false)
}

/// Emits the LLVM IR module (text) from the Core (`--emit llvm`).
pub fn emit_ir(module: &ast::Module, inplace: &HashSet<Span>) -> Result<String, String> {
    let fns = core::lower(module, inplace);
    let records = RecordInfo::build(module);
    let main_int = main_returns_int(module, "main");
    let main_float = main_returns_float(module, "main");
    let main_bool = main_returns_bool(module, "main");

    // pre-pass: interns the string literals
    let mut strings: HashMap<String, usize> = HashMap::new();
    for f in &fns {
        collect_strings(&f.body, &mut strings);
    }

    let mut out = String::from("; Axion --release (LLVM IR)\n");
    out.push_str(RT_DECLS);
    // declarations of the FFI imports (§18): `declare i64 @name(i64, …)`
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
    out.push_str("@.ffmt = private unnamed_addr constant [4 x i8] c\"%g\\0A\\00\"\n");
    if main_bool {
        out.push_str("@.sfmt = private unnamed_addr constant [4 x i8] c\"%s\\0A\\00\"\n");
        out.push_str("@.true = private unnamed_addr constant [5 x i8] c\"true\\00\"\n");
        out.push_str("@.false = private unnamed_addr constant [6 x i8] c\"false\\00\"\n");
    }
    // string globals
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

    // driver: calls `ax_main`; prints the Int, or nothing if it is IO ().
    out.push_str("define i32 @main() {\nentry:\n  %r = call i64 @\"ax_main\"()\n");
    if main_int {
        out.push_str("  call i32 (ptr, ...) @printf(ptr @.fmt, i64 %r)\n");
    } else if main_float {
        // reinterpret the i64 ABI value as a double and print it (`%g`).
        out.push_str("  %rf = bitcast i64 %r to double\n");
        out.push_str("  call i32 (ptr, ...) @printf(ptr @.ffmt, double %rf)\n");
    } else if main_bool {
        // i64 0/1 → select "true"/"false" and print (like the interpreter).
        out.push_str("  %b = icmp ne i64 %r, 0\n");
        out.push_str("  %s = select i1 %b, ptr @.true, ptr @.false\n");
        out.push_str("  call i32 (ptr, ...) @printf(ptr @.sfmt, ptr %s)\n");
    }
    out.push_str("  ret i32 0\n}\n");
    Ok(out)
}

/// Compiles the Core with `clang -O2 -flto` (+ C runtime) and runs the binary.
pub fn build_and_run(
    module: &ast::Module,
    entry: &str,
    inplace: &HashSet<Span>,
) -> Result<(), String> {
    let fns = core::lower(module, inplace);
    if !fns.iter().any(|f| f.name == entry && f.params.is_empty()) {
        return Err(format!(
            "'{entry}' must be a native function with no parameters"
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
    // `-pthread`: the session scheduler (§11) runs tasks on a thread pool.
    cmd.args(["-O2", "-flto", "-w", "-pthread"])
        .arg(&ll)
        .arg(&rt)
        .arg("-o")
        .arg(&exe);
    // FFI (§18): links the user's libraries (direct path) and records their
    // directory in rpath, so the dynamic loader finds them at runtime.
    for lib in module.foreign_libs() {
        let path = std::path::Path::new(&lib);
        if let Some(dir) = path.parent().filter(|d| !d.as_os_str().is_empty()) {
            let dir = std::fs::canonicalize(dir).unwrap_or_else(|_| dir.to_path_buf());
            cmd.arg(format!("-Wl,-rpath,{}", dir.display()));
        }
        cmd.arg(&lib);
    }
    let status = cmd
        .status()
        .map_err(|e| format!("could not invoke '{clang}' ({e}); set AXION_CLANG or use nix"))?;
    if !status.success() {
        return Err("clang failed to compile the LLVM IR".into());
    }
    let run = std::process::Command::new(&exe).status();
    let _ = std::fs::remove_file(&ll);
    let _ = std::fs::remove_file(&rt);
    let _ = std::fs::remove_file(&exe);
    match run {
        Ok(s) if s.success() => Ok(()),
        Ok(s) => Err(format!("the --release binary exited with {s}")),
        Err(e) => Err(e.to_string()),
    }
}

// --- string interning ---

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

/// The atoms that appear in an `Op` (for string interning).
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
        Op::StoreRaw(p, _, v) => vec![p, v],
        Op::FuncAddr(_) => vec![],
        Op::Prim(_, a, b) | Op::PrimF(_, a, b) | Op::Promote(a, b) => vec![a, b],
        Op::IntToFloat(a) | Op::FloatToInt(a) => vec![a],
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

/// Collects the used FFI imports (name → arity), to declare them in the IR.
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

/// Encodes a string to LLVM's `c"…"` format (unsafe bytes → `\XX`).
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

// --- emitting a function ---

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
    // loads the captures from env[(i+1)*8]
    if f.is_closure {
        for (i, cap) in f.captures.iter().enumerate() {
            let v = e.load("%env", (i as i32 + 1) * 8);
            e.scope.insert(cap.clone(), v);
        }
    }
    let ret = e.term(&f.body)?;
    Ok(format!("{header}{}  ret i64 {ret}\n}}\n", e.out))
}

/// State of emitting a function.
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

    /// `load i64` from `base + off` (base is an i64-pointer).
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
    /// Call to a runtime function (`ret` indicates whether it returns a value).
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
    /// Allocates `nslots` × 8 bytes on the heap; returns the pointer (i64).
    fn alloc(&mut self, nslots: usize) -> String {
        self.rt("axion_alloc", true, &[(nslots as i64 * 8).to_string()])
    }

    /// Writes the constructor tag at offset 0, if the type is a sum (>1 con).
    fn store_tag(&mut self, con: &str, ptr: &str) {
        if let Some(tag) = self.records.tag(con) {
            self.store(ptr, 0, &tag.to_string());
        }
    }

    /// Binds the sub-patterns (variables) of a constructor to its fields.
    fn destructure_con(&mut self, con: &str, subpats: &[CPat], sval: &str) -> Result<(), String> {
        for (j, p) in subpats.iter().enumerate() {
            match p {
                CPat::Wild => {}
                CPat::Var(n) => {
                    let off = self.records.field_offset(con, j);
                    let v = self.load(sval, off);
                    self.scope.insert(n.clone(), v);
                }
                _ => {
                    return Err(
                        "nested pattern in a constructor does not compile under --release".into(),
                    )
                }
            }
        }
        Ok(())
    }

    fn atom(&self, a: &Atom) -> Result<String, String> {
        match a {
            Atom::Int(n) => Ok(n.to_string()),
            // float literal: its f64 bit pattern as an i64 immediate.
            Atom::Float(f) => Ok((f.to_bits() as i64).to_string()),
            Atom::Var(n) => self
                .scope
                .get(n)
                .cloned()
                .ok_or_else(|| format!("variable '{n}' not bound in the LLVM IR")),
            Atom::Str(s) => {
                let i = self.strings.get(s).ok_or("string not interned")?;
                // constant expression: the string pointer as i64
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
                // deep-drop: recursive destructor if the type has heap fields;
                // otherwise, flat `free`.
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

    /// `case` as an `if` chain (Int/var/`_`/tuple patterns; catch-all at the end).
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
                        _ => {
                            return Err(
                                "nested tuple pattern does not compile under --release".into()
                            )
                        }
                    }
                }
                self.term(body)
            }
            CPat::Int(lit) => {
                if i + 1 >= arms.len() {
                    return Err("case without catch-all does not compile under --release".into());
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
                // 1-constructor type (no tag) or last arm: destructure without
                // testing the tag; otherwise compare the tag (offset 0) with the constructor's.
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
                    other => {
                        return Err(format!(
                            "operator '{other}' does not compile under --release"
                        ))
                    }
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
            // float op: bitcast i64 bit-patterns to double, compute; arithmetic
            // bitcasts the double result back to i64, a comparison zext's the i1.
            Op::PrimF(o, a, b) => {
                let x = self.atom(a)?;
                let y = self.atom(b)?;
                let (xf, yf) = (self.val(), self.val());
                self.ins(&format!("{xf} = bitcast i64 {x} to double"));
                self.ins(&format!("{yf} = bitcast i64 {y} to double"));
                // ordered comparisons (`o*`): false if either operand is NaN.
                let cmp = match o.as_str() {
                    "==." => Some("oeq"),
                    "<." => Some("olt"),
                    ">." => Some("ogt"),
                    _ => None,
                };
                if let Some(pred) = cmp {
                    let (r, z) = (self.val(), self.val());
                    self.ins(&format!("{r} = fcmp {pred} double {xf}, {yf}"));
                    self.ins(&format!("{z} = zext i1 {r} to i64"));
                    return Ok(z);
                }
                let fop = match o.as_str() {
                    "+." => "fadd",
                    "-." => "fsub",
                    "*." => "fmul",
                    "/." => "fdiv",
                    other => {
                        return Err(format!("float operator '{other}' does not compile under --release"))
                    }
                };
                let (rf, z) = (self.val(), self.val());
                self.ins(&format!("{rf} = {fop} double {xf}, {yf}"));
                self.ins(&format!("{z} = bitcast double {rf} to i64"));
                Ok(z)
            }
            // Int → Float (signed) and Float → Int (truncating). The f64 is
            // carried as its i64 bit-pattern, so bitcast at the boundaries.
            Op::IntToFloat(a) => {
                let x = self.atom(a)?;
                let (f, z) = (self.val(), self.val());
                self.ins(&format!("{f} = sitofp i64 {x} to double"));
                self.ins(&format!("{z} = bitcast double {f} to i64"));
                Ok(z)
            }
            Op::FloatToInt(a) => {
                let x = self.atom(a)?;
                let (f, z) = (self.val(), self.val());
                self.ins(&format!("{f} = bitcast i64 {x} to double"));
                self.ins(&format!("{z} = fptosi double {f} to i64"));
                Ok(z)
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
                    .ok_or_else(|| format!("unknown constructor '{con}'"))?;
                let ptr = self.alloc(slots);
                self.store_tag(con, &ptr);
                for (fname, a) in fields {
                    let off = self
                        .records
                        .field(fname)
                        .map(|(o, _)| o)
                        .ok_or_else(|| format!("unknown field '{fname}'"))?;
                    let v = self.atom(a)?;
                    self.store(&ptr, off, &v);
                }
                Ok(ptr)
            }
            Op::MakeCon { con, args } => {
                let slots = self
                    .records
                    .con_slots(con)
                    .ok_or_else(|| format!("unknown constructor '{con}'"))?;
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
                // Linear Elision (§2): in-place mutates the base's block; otherwise allocates
                // um novo e copia.
                let target = if *inplace {
                    base_ptr
                } else {
                    let first = &fields.first().ok_or("empty update")?.0;
                    let nfields = self
                        .records
                        .field(first)
                        .map(|(_, fs)| fs.len())
                        .ok_or_else(|| format!("unknown field '{first}'"))?;
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
                        .ok_or_else(|| format!("unknown field '{fname}'"))?;
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
                    .ok_or_else(|| format!("unknown field '{name}'"))?;
                let r = self.atom(rec)?;
                Ok(self.load(&r, off))
            }
            Op::LoadRaw(a, off) => {
                let r = self.atom(a)?;
                Ok(self.load(&r, *off))
            }
            Op::StoreRaw(ptr, off, val) => {
                let p = self.atom(ptr)?;
                let v = self.atom(val)?;
                self.store(&p, *off, &v);
                Ok(v)
            }
            Op::FuncAddr(name) => {
                let r = self.val();
                self.ins(&format!("{r} = ptrtoint ptr @\"ax_{name}\" to i64"));
                Ok(r)
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
            Op::Unsupported(m) => Err(format!("{m} does not compile under --release")),
        }
    }
}
