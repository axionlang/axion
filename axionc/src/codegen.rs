//! Cranelift `--dev` backend (§11/§18): the fast-path JIT. Lowers Core IR to
//! Cranelift IR and runs it in-process, registering the `axion-rt` runtime (the
//! same crate the LLVM `--release` path links) as JIT symbols — one runtime, no
//! reimplementation to drift.
#![allow(unsafe_code)]

use crate::ast;
use crate::ast::Span;
use crate::core::{
    self, is_bool, is_float, is_int, result_type, Atom, CPat, CoreFn, Op, RecordInfo, Rhs, Term,
};
use cranelift::codegen::ir::UserFuncName;
use cranelift::codegen::Context;
use cranelift::prelude::{
    types, AbiParam, Block, Configurable, EntityRef, FloatCC, FunctionBuilder,
    FunctionBuilderContext, InstBuilder, IntCC, MemFlags, Value, Variable,
};
use cranelift_jit::{JITBuilder, JITModule};
use cranelift_module::{DataDescription, DataId, FuncId, Linkage, Module};
use std::collections::HashMap;
use std::collections::HashSet;

// FFI (§18): resolves a symbol already loaded in the process (libc + axionc's
// runtime) via `dlsym(RTLD_DEFAULT, …)`. Serves the JIT's `symbol_lookup_fn`.
extern "C" {
    fn dlsym(
        handle: *mut std::ffi::c_void,
        symbol: *const std::ffi::c_char,
    ) -> *mut std::ffi::c_void;
}

fn resolve_symbol(name: &str) -> Option<*const u8> {
    let cname = std::ffi::CString::new(name).ok()?;
    // RTLD_DEFAULT = null pointer (glibc): searches in the normal resolution order.
    // SAFETY: dlsym with RTLD_DEFAULT reads the process symbol table
    // — pointer is valid or null, both safe to inspect.
    let p = unsafe { dlsym(std::ptr::null_mut(), cname.as_ptr()) };
    (!p.is_null()).then_some(p as *const u8)
}

/// Arena `Cell` size in bytes — must equal the runtime's (`axion-rt`, `ARENA`/`CELL_SIZE`).
const CELL_SIZE: i64 = 16;

/// The stack size for the thread the evaluated program runs on (lazily committed — only touched
/// pages cost memory) so deep non-tail recursion doesn't overflow the small default stack. `pub`
/// so `lib.rs`'s interpreter path reuses the identical size.
pub const EVAL_STACK_SIZE: usize = 2 << 30; // 2 GiB

/// The arena runtime's `FuncId`s (§3).
#[derive(Clone, Copy)]
struct Arena {
    new: FuncId,
    alloc: FuncId,
    reset: FuncId,
    mark: FuncId,
    release: FuncId,
    promote: FuncId,
}

/// Compilation environment: JIT + the `FuncId`/arity of the Core functions.
struct Cg {
    module: JITModule,
    ids: HashMap<String, (FuncId, usize)>,
    strings: HashMap<String, DataId>,
    str_counter: u32,
    println_id: FuncId,
    print_id: FuncId,
    show_id: FuncId,
    alloc_id: FuncId,
    free_id: FuncId,
    arena: Arena,
    rt_fns: HashMap<String, (FuncId, bool)>,
    records: RecordInfo,
}

impl Cg {
    fn new(records: RecordInfo) -> Result<Cg, String> {
        let mut flags = cranelift::codegen::settings::builder();
        drop(flags.set("opt_level", "none"));
        let isa = cranelift_native::builder()
            .map_err(|e| e.to_string())?
            .finish(cranelift::codegen::settings::Flags::new(flags))
            .map_err(|e| e.to_string())?;
        let mut builder = JITBuilder::with_isa(isa, cranelift_module::default_libcall_names());
        // FFI (§18): unregistered symbols resolve via dlsym (libc, …).
        builder.symbol_lookup_fn(Box::new(resolve_symbol));
        // Register the ONE runtime (`axion-rt`, the same crate the `--release` path links) — its
        // symbol table is the single source of truth, so `--dev` and `--release` execute identical
        // runtime code and cannot drift (docs/rust-runtime-port.md).
        for (name, ptr) in axion_rt::runtime_symbols() {
            builder.symbol(name, ptr);
        }
        let mut module = JITModule::new(builder);

        let import = |module: &mut JITModule, name: &str, nparams: usize, ret: bool| {
            let mut sig = module.make_signature();
            for _ in 0..nparams {
                sig.params.push(AbiParam::new(types::I64));
            }
            if ret {
                sig.returns.push(AbiParam::new(types::I64));
            }
            module
                .declare_function(name, Linkage::Import, &sig)
                .map_err(|e| e.to_string())
        };
        let println_id = import(&mut module, "axion_puts", 1, false)?;
        let print_id = import(&mut module, "axion_put", 1, false)?;
        let show_id = import(&mut module, "axion_show_int", 1, true)?;
        let alloc_id = import(&mut module, "axion_alloc", 1, true)?;
        let free_id = import(&mut module, "axion_free", 1, false)?;
        let arena = Arena {
            new: import(&mut module, "axion_arena_new", 0, true)?,
            alloc: import(&mut module, "axion_arena_alloc", 2, true)?,
            reset: import(&mut module, "axion_arena_reset", 1, false)?,
            mark: import(&mut module, "axion_arena_mark", 1, true)?,
            release: import(&mut module, "axion_arena_release", 1, false)?,
            promote: import(&mut module, "axion_arena_promote", 3, true)?,
        };
        // named runtime builtins (Buffer/§4): name → (FuncId, returns a value)
        let mut rt_fns: HashMap<String, (FuncId, bool)> = HashMap::new();
        for (name, nparams, ret) in [
            ("axion_buf_new", 1, true),
            ("axion_buf_iota", 1, true),
            ("axion_buf_xor", 2, true),
            ("axion_buf_sum", 1, true),
            ("axion_buf_free", 1, true),
            ("axion_fold_bytes", 3, true),
            ("axion_array_new", 2, true),
            ("axion_array_get", 2, true),
            ("axion_array_set", 3, true),
            ("axion_array_len", 1, true),
            ("axion_array_free", 1, false),
            // TritVec (§10): base-243 packed ternary array
            ("axion_tritvec_new", 2, true),
            ("axion_tritvec_get", 2, true),
            ("axion_tritvec_set", 3, true),
            ("axion_tritvec_len", 1, true),
            ("axion_tritvec_dot", 2, true),
            ("axion_tritvec_matvec_sum", 3, true),
            ("axion_tritvec_from_buffer", 2, true),
            ("axion_tritvec_iota", 1, true),
            ("axion_array_iota", 1, true),
            ("axion_i8_new", 2, true),
            ("axion_i8_iota", 1, true),
            ("axion_i8_get", 2, true),
            ("axion_i8_set", 3, true),
            ("axion_i8_len", 1, true),
            ("axion_i8_matvec_sum", 3, true),
            ("axion_i8_sum", 1, true),
            ("axion_i8_dot", 2, true),
            ("axion_i8_dot_i8", 2, true),
            ("axion_array_sum", 1, true),
            ("axion_array_dot", 2, true),
            ("axion_i32_new", 2, true),
            ("axion_i32_iota", 1, true),
            ("axion_i32_get", 2, true),
            ("axion_i32_set", 3, true),
            ("axion_i32_len", 1, true),
            ("axion_i32_sum", 1, true),
            ("axion_i32_dot", 2, true),
            ("axion_i32_matvec_sum", 3, true),
            // Show/String builtins (§tc): showFloat and strAppend
            ("axion_show_float", 1, true),
            ("axion_strcat", 2, true),
            // char-level string primitives (§text)
            ("axion_str_len", 1, true),
            ("axion_str_at", 2, true),
            ("axion_str_cmp", 2, true),
            ("axion_substr", 3, true),
            // OS capability layer (§pass)
            ("axion_getenv", 1, true),
            ("axion_run", 1, true),
            ("axion_system", 1, true),
            ("axion_read_file", 1, true),
            ("axion_write_file", 2, true),
            ("axion_file_exists", 1, true),
            ("axion_mkdir_p", 1, true),
            ("axion_unlink", 1, true),
            ("axion_rename", 2, true),
            ("axion_readdir", 1, true),
            ("axion_exec_capture", 2, true),
            ("axion_exec_status", 2, true),
            ("axion_read_line", 1, true),
            ("axion_read_secret", 1, true),
            ("axion_rand_hex", 1, true),
            ("axion_exit", 1, true),
            ("axion_getargs", 1, true),
            ("axion_getarg", 1, true),
            // drops a String: frees a heap string, skips a static literal (§tc)
            ("axion_str_drop", 1, false),
            ("axion_eput", 1, false),
            ("axion_eputs", 1, false),
            ("axion_bignum_from_i64", 1, true),
            ("axion_bignum_from_str", 1, true),
            ("axion_bignum_add", 2, true),
            ("axion_bignum_copy", 1, true),
            ("axion_block_copy", 1, true),
            ("axion_bignum_sub", 2, true),
            ("axion_bignum_mul", 2, true),
            ("axion_bignum_div", 2, true),
            ("axion_bignum_mod", 2, true),
            ("axion_bignum_eq", 2, true),
            ("axion_bignum_lt", 2, true),
            ("axion_bignum_gt", 2, true),
            ("axion_bignum_to_string", 1, true),
            // used by the generated destructors (deep-drop) via RtCall
            ("axion_free", 1, false),
            ("axion_bignum_free", 1, false),
            // cooperative session scheduler (§11)
            ("axion_sess_new", 0, true),
            ("axion_sess_channel", 1, true),
            ("axion_sess_send", 3, false),
            ("axion_sess_pending", 2, true),
            ("axion_sess_recv", 2, true),
            ("axion_sess_alloc", 2, true),
            ("axion_sess_spawn", 3, false),
            ("axion_sess_run", 3, true),
            ("axion_par_map", 4, true),
        ] {
            rt_fns.insert(name.into(), (import(&mut module, name, nparams, ret)?, ret));
        }

        Ok(Cg {
            module,
            ids: HashMap::new(),
            strings: HashMap::new(),
            str_counter: 0,
            println_id,
            print_id,
            show_id,
            alloc_id,
            free_id,
            arena,
            rt_fns,
            records,
        })
    }

    fn declare_all(&mut self, fns: &[CoreFn]) -> Result<(), String> {
        for f in fns {
            let mut sig = self.module.make_signature();
            // closures receive the env pointer as the 1st parameter
            let nparams = f.params.len() + usize::from(f.is_closure);
            for _ in 0..nparams {
                sig.params.push(AbiParam::new(types::I64));
            }
            sig.returns.push(AbiParam::new(types::I64));
            let id = self
                .module
                .declare_function(&f.name, Linkage::Export, &sig)
                .map_err(|e| e.to_string())?;
            self.ids.insert(f.name.clone(), (id, f.params.len()));
        }
        Ok(())
    }

    /// Reclamation-TV symbol maps, keyed by `FuncId` index (the `u0:N` in emitted CLIF, since
    /// `ctx.func.name = UserFuncName::user(0, id)`). `fn_names` maps each DEFINING function's
    /// index → its name (to identify the `function u0:N` a body belongs to); `reclaim_callees`
    /// maps each reclamation CALLEE's index → the token `codegen_tv::expected` uses, so a
    /// `fnK = u0:M` / `call fnK` pair in the CLIF resolves to the same free the Core `Drop` did.
    /// Must be read after `declare_all` (user fns + generated `axion_drop_*` destructors declared).
    fn reclaim_tv_maps(&self) -> (HashMap<u32, String>, HashMap<u32, String>) {
        let mut fn_names = HashMap::new();
        let mut reclaim = HashMap::new();
        for (name, (id, _)) in &self.ids {
            fn_names.insert(id.as_u32(), name.clone());
            // a generated destructor called as reclamation → token `ax_axion_drop_KEY`.
            if name.starts_with("axion_drop_") {
                reclaim.insert(id.as_u32(), format!("ax_{name}"));
            }
        }
        reclaim.insert(self.free_id.as_u32(), "axion_free".to_string());
        for rt in ["axion_str_drop", "axion_bignum_free"] {
            if let Some((id, _)) = self.rt_fns.get(rt) {
                reclaim.insert(id.as_u32(), rt.to_string());
            }
        }
        (fn_names, reclaim)
    }

    /// Builds the body of a Core function and returns the filled `Context`.
    fn build(&mut self, f: &CoreFn) -> Result<Context, String> {
        let (id, _) = self.ids[&f.name];
        let nparams = f.params.len() + usize::from(f.is_closure);
        let mut ctx = self.module.make_context();
        for _ in 0..nparams {
            ctx.func.signature.params.push(AbiParam::new(types::I64));
        }
        ctx.func.signature.returns.push(AbiParam::new(types::I64));
        ctx.func.name = UserFuncName::user(0, id.as_u32());

        let mut fbctx = FunctionBuilderContext::new();
        {
            let mut builder = FunctionBuilder::new(&mut ctx.func, &mut fbctx);
            let entry = builder.create_block();
            builder.append_block_params_for_function_params(entry);
            builder.switch_to_block(entry);
            builder.seal_block(entry);
            let argvals: Vec<Value> = builder.block_params(entry).to_vec();

            let mut fx = Fx {
                builder,
                vars: HashMap::new(),
                next: 0,
                ids: &self.ids,
                module: &mut self.module,
                strings: &mut self.strings,
                str_counter: &mut self.str_counter,
                println_id: self.println_id,
                print_id: self.print_id,
                show_id: self.show_id,
                alloc_id: self.alloc_id,
                free_id: self.free_id,
                arena: self.arena,
                rt_fns: &self.rt_fns,
                records: &self.records,
                tco: None,
            };

            if f.is_closure {
                let env = argvals[0];
                for (i, cap) in f.captures.iter().enumerate() {
                    let v =
                        fx.builder
                            .ins()
                            .load(types::I64, MemFlags::new(), env, (i as i32 + 1) * 8);
                    fx.bind_val(cap, v);
                }
                for (j, p) in f.params.iter().enumerate() {
                    fx.bind_val(p, argvals[j + 1]);
                }
            } else {
                for (j, p) in f.params.iter().enumerate() {
                    fx.bind_val(p, argvals[j]);
                }
            }

            // Tail-call optimization: a self-tail-recursive function loops instead
            // of recursing. The params are already bound to (mutable) Variables; we
            // jump into a header block and each tail self-call reassigns the params
            // and jumps back — no call/return, no stack growth.
            if core::has_tail_self_call(f) {
                let header = fx.builder.create_block();
                fx.builder.ins().jump(header, &[]);
                fx.builder.switch_to_block(header);
                fx.tco = Some((header, f.name.clone(), f.params.clone()));
                fx.emit_term_tail(&f.body)?;
                fx.builder.seal_block(header); // all back-edges emitted
            } else {
                let ret = fx.emit_term(&f.body)?;
                fx.builder.ins().return_(&[ret]);
            }
            fx.builder.finalize();
        }
        Ok(ctx)
    }
}

/// Context of emitting a function.
struct Fx<'a, 'b> {
    builder: FunctionBuilder<'b>,
    vars: HashMap<String, Variable>,
    next: u32,
    ids: &'a HashMap<String, (FuncId, usize)>,
    module: &'a mut JITModule,
    strings: &'a mut HashMap<String, DataId>,
    str_counter: &'a mut u32,
    println_id: FuncId,
    print_id: FuncId,
    show_id: FuncId,
    alloc_id: FuncId,
    free_id: FuncId,
    arena: Arena,
    rt_fns: &'a HashMap<String, (FuncId, bool)>,
    records: &'a RecordInfo,
    /// TCO: `(loop header block, this function's name, its parameter names)`. A
    /// tail self-call reassigns the params and jumps to the header instead of
    /// calling+returning. `None` for non-tail-recursive functions.
    tco: Option<(Block, String, Vec<String>)>,
}

impl Fx<'_, '_> {
    /// Interna um literal de string como objecto de dados (C-string).
    fn intern(&mut self, s: &str) -> Result<DataId, String> {
        if let Some(id) = self.strings.get(s) {
            return Ok(*id);
        }
        let name = format!("str{}", self.str_counter);
        *self.str_counter += 1;
        let id = self
            .module
            .declare_data(&name, Linkage::Local, false, false)
            .map_err(|e| e.to_string())?;
        let mut desc = DataDescription::new();
        // 8-byte ZERO size-header (mirrors `axion_alloc`), then the NUL-terminated
        // bytes. The String VALUE points past the header (see `Atom::Str`), so
        // `axion_str_drop` reads a 0 header and skips the static literal, while heap
        // strings (nonzero header) are freed.
        let mut bytes = vec![0u8; 8];
        bytes.extend_from_slice(s.as_bytes());
        bytes.push(0);
        desc.define(bytes.into_boxed_slice());
        self.module
            .define_data(id, &desc)
            .map_err(|e| e.to_string())?;
        self.strings.insert(s.to_string(), id);
        Ok(id)
    }

    /// Creates a fresh `Variable` already defined with `val`.
    fn fresh_var(&mut self, val: Value) -> Variable {
        let v = Variable::new(self.next as usize);
        self.next += 1;
        self.builder.declare_var(v, types::I64);
        self.builder.def_var(v, val);
        v
    }

    fn bind_val(&mut self, name: &str, val: Value) {
        let v = self.fresh_var(val);
        self.vars.insert(name.to_string(), v);
    }

    /// Allocates a block of `nslots` fields (i64 each) and returns the pointer.
    fn alloc(&mut self, nslots: usize) -> Value {
        let size = self.builder.ins().iconst(types::I64, nslots as i64 * 8);
        let callee = self
            .module
            .declare_func_in_func(self.alloc_id, self.builder.func);
        let call = self.builder.ins().call(callee, &[size]);
        self.builder.inst_results(call)[0]
    }

    /// Writes the constructor tag at offset 0, if the type is a sum (>1 con).
    fn store_tag(&mut self, con: &str, ptr: Value) {
        if let Some(tag) = self.records.tag(con) {
            let t = self.builder.ins().iconst(types::I64, tag as i64);
            self.builder.ins().store(MemFlags::new(), t, ptr, 0);
        }
    }

    /// Indirect call through a closure: `fn_ptr = clos[0]`, then
    /// `fn_ptr(clos, args…)` (the closure is passed as env).
    fn call_closure(&mut self, clos: Value, args: &[Value]) -> Value {
        let fn_ptr = self
            .builder
            .ins()
            .load(types::I64, MemFlags::new(), clos, 0);
        let mut sig = self.module.make_signature();
        sig.params.push(AbiParam::new(types::I64)); // env
        for _ in args {
            sig.params.push(AbiParam::new(types::I64));
        }
        sig.returns.push(AbiParam::new(types::I64));
        let sigref = self.builder.import_signature(sig);
        let mut call_args = Vec::with_capacity(args.len() + 1);
        call_args.push(clos);
        call_args.extend_from_slice(args);
        let call = self.builder.ins().call_indirect(sigref, fn_ptr, &call_args);
        self.builder.inst_results(call)[0]
    }

    /// Value of an atom (a literal or a bound variable).
    fn atom(&mut self, a: &Atom) -> Result<Value, String> {
        match a {
            Atom::Int(n) => Ok(self.builder.ins().iconst(types::I64, *n)),
            // float literal: carry its f64 bit pattern in the i64 ABI slot.
            Atom::Float(f) => Ok(self.builder.ins().iconst(types::I64, f.to_bits() as i64)),
            Atom::Str(s) => {
                let data = self.intern(s)?;
                let gv = self.module.declare_data_in_func(data, self.builder.func);
                let base = self.builder.ins().global_value(types::I64, gv);
                // point past the 8-byte size-header to the C-string bytes.
                let eight = self.builder.ins().iconst(types::I64, 8);
                Ok(self.builder.ins().iadd(base, eight))
            }
            Atom::Var(name) => match self.vars.get(name) {
                Some(v) => Ok(self.builder.use_var(*v)),
                None => Err(format!("variable '{name}' not bound in the Core")),
            },
        }
    }

    fn atoms(&mut self, xs: &[Atom]) -> Result<Vec<Value>, String> {
        xs.iter().map(|a| self.atom(a)).collect()
    }

    fn emit_term(&mut self, t: &Term) -> Result<Value, String> {
        match t {
            Term::Let(name, rhs, _, body) => {
                let v = self.emit_rhs(rhs)?;
                self.bind_val(name, v);
                self.emit_term(body)
            }
            Term::Drop(name, ty, skip, _, body) => {
                self.emit_drop(name, ty.as_deref(), skip)?;
                self.emit_term(body)
            }
            Term::Ret(rhs, _) => self.emit_rhs(rhs),
        }
    }

    /// Auto-Drop: frees the heap object at its death point (deep-drop destructor
    /// if the type owns heap fields, else a flat `free`).
    fn emit_drop(&mut self, name: &str, ty: Option<&str>, skip: &[usize]) -> Result<(), String> {
        let v = self
            .vars
            .get(name)
            .copied()
            .ok_or_else(|| format!("drop of unbound variable '{name}'"))?;
        let ptr = self.builder.use_var(v);
        // a String is reclaimed by the tagged runtime drop (frees a heap string,
        // skips a static literal via its zero size-header) — never the plain
        // `axion_free`, which would free a literal's rodata.
        if ty == Some("String") {
            let (id, _) = self.rt_fns["axion_str_drop"];
            let callee = self.module.declare_func_in_func(id, self.builder.func);
            self.builder.ins().call(callee, &[ptr]);
            return Ok(());
        }
        // an Integer is a boxed BigNum → `axion_bignum_free` (frees struct + limbs);
        // never the plain `axion_free`, which would leak the limb allocation.
        if ty == Some("Integer") {
            let (id, _) = self.rt_fns["axion_bignum_free"];
            let callee = self.module.declare_func_in_func(id, self.builder.func);
            self.builder.ins().call(callee, &[ptr]);
            return Ok(());
        }
        let deep = if skip.is_empty() {
            ty.map(|t| format!("axion_drop_{t}"))
        } else {
            let skip_name: Vec<String> = skip.iter().map(|i| i.to_string()).collect();
            ty.map(|t| format!("axion_drop_{t}_skip_{}", skip_name.join("_")))
        };
        let id = match deep.and_then(|n| self.ids.get(&n).copied()) {
            Some((id, _)) => id,
            None => self.free_id,
        };
        let callee = self.module.declare_func_in_func(id, self.builder.func);
        self.builder.ins().call(callee, &[ptr]);
        Ok(())
    }

    /// Tail-position emission (TCO): every path ends in a terminator — a `return`,
    /// or a `jump` back to the loop header for a tail self-call. Never produces a
    /// value (unlike `emit_term`), so no phi/merge is needed on tail branches.
    fn emit_term_tail(&mut self, t: &Term) -> Result<(), String> {
        match t {
            Term::Let(name, rhs, _, body) => {
                let v = self.emit_rhs(rhs)?;
                self.bind_val(name, v);
                self.emit_term_tail(body)
            }
            Term::Drop(name, ty, skip, _, body) => {
                self.emit_drop(name, ty.as_deref(), skip)?;
                self.emit_term_tail(body)
            }
            Term::Ret(rhs, _) => self.emit_rhs_tail(rhs),
        }
    }

    fn emit_rhs_tail(&mut self, rhs: &Rhs) -> Result<(), String> {
        match rhs {
            // tail self-call → reassign the params, jump to the header (the loop).
            Rhs::Op(Op::CallDirect(g, args, _))
                if self.tco.as_ref().is_some_and(|(_, name, _)| name == g) =>
            {
                let vals: Vec<Value> = args
                    .iter()
                    .map(|a| self.atom(a))
                    .collect::<Result<_, _>>()?;
                let (header, _, params) = self.tco.clone().ok_or("TCO state")?;
                for (p, v) in params.iter().zip(vals) {
                    let var = self.vars[p];
                    self.builder.def_var(var, v);
                }
                self.builder.ins().jump(header, &[]);
                Ok(())
            }
            Rhs::Op(op) => {
                let v = self.emit_op(op)?;
                self.builder.ins().return_(&[v]);
                Ok(())
            }
            Rhs::If(cond, t, e) => {
                let c = self.atom(cond)?;
                let then_b = self.builder.create_block();
                let else_b = self.builder.create_block();
                self.builder.ins().brif(c, then_b, &[], else_b, &[]);
                self.builder.switch_to_block(then_b);
                self.builder.seal_block(then_b);
                self.emit_term_tail(t)?;
                self.builder.switch_to_block(else_b);
                self.builder.seal_block(else_b);
                self.emit_term_tail(e)
            }
            Rhs::Case(scrut, arms) => {
                let s = self.atom(scrut)?;
                self.emit_case_tail(s, arms, 0)
            }
        }
    }

    fn emit_rhs(&mut self, rhs: &Rhs) -> Result<Value, String> {
        match rhs {
            Rhs::Op(op) => self.emit_op(op),
            Rhs::If(cond, t, e) => {
                let c = self.atom(cond)?;
                let then_b = self.builder.create_block();
                let else_b = self.builder.create_block();
                let merge_b = self.builder.create_block();
                self.builder.append_block_param(merge_b, types::I64);
                self.builder.ins().brif(c, then_b, &[], else_b, &[]);

                self.builder.switch_to_block(then_b);
                self.builder.seal_block(then_b);
                let tv = self.emit_term(t)?;
                self.builder.ins().jump(merge_b, &[tv]);

                self.builder.switch_to_block(else_b);
                self.builder.seal_block(else_b);
                let ev = self.emit_term(e)?;
                self.builder.ins().jump(merge_b, &[ev]);

                self.builder.switch_to_block(merge_b);
                self.builder.seal_block(merge_b);
                Ok(self.builder.block_params(merge_b)[0])
            }
            Rhs::Case(scrut, arms) => {
                let s = self.atom(scrut)?;
                self.emit_case(s, arms, 0)
            }
        }
    }

    fn emit_op(&mut self, op: &Op) -> Result<Value, String> {
        match op {
            Op::Atom(a) => self.atom(a),
            Op::Prim(o, l, r) => {
                let a = self.atom(l)?;
                let b = self.atom(r)?;
                // comparisons return I8; extended to I64 so every Core value
                // is uniformly i64 (bindable to an I64 Variable).
                let cmp = |me: &mut Self, cc| {
                    let c = me.builder.ins().icmp(cc, a, b);
                    me.builder.ins().uextend(types::I64, c)
                };
                Ok(match o.as_str() {
                    "+" => self.builder.ins().iadd(a, b),
                    "-" => self.builder.ins().isub(a, b),
                    "*" => self.builder.ins().imul(a, b),
                    "div" => self.builder.ins().sdiv(a, b),
                    "mod" => self.builder.ins().srem(a, b),
                    "band" => self.builder.ins().band(a, b),
                    "==" => cmp(self, IntCC::Equal),
                    "<" => cmp(self, IntCC::SignedLessThan),
                    ">" => cmp(self, IntCC::SignedGreaterThan),
                    other => return Err(format!("operator '{other}' does not compile natively")),
                })
            }
            // float op: bitcast the i64 bit-pattern operands to f64, compute, and
            // bitcast the f64 result back into the i64 ABI slot.
            Op::PrimF(o, l, r) => {
                let a = self.atom(l)?;
                let b = self.atom(r)?;
                let af = self.builder.ins().bitcast(types::F64, MemFlags::new(), a);
                let bf = self.builder.ins().bitcast(types::F64, MemFlags::new(), b);
                // comparisons yield a Bool (i64 0/1); arithmetic yields an f64
                // that is bitcast back into the i64 ABI slot.
                let fcmp = |me: &mut Self, cc| {
                    let c = me.builder.ins().fcmp(cc, af, bf);
                    me.builder.ins().uextend(types::I64, c)
                };
                Ok(match o.as_str() {
                    "+." => {
                        let rf = self.builder.ins().fadd(af, bf);
                        self.builder.ins().bitcast(types::I64, MemFlags::new(), rf)
                    }
                    "-." => {
                        let rf = self.builder.ins().fsub(af, bf);
                        self.builder.ins().bitcast(types::I64, MemFlags::new(), rf)
                    }
                    "*." => {
                        let rf = self.builder.ins().fmul(af, bf);
                        self.builder.ins().bitcast(types::I64, MemFlags::new(), rf)
                    }
                    "/." => {
                        let rf = self.builder.ins().fdiv(af, bf);
                        self.builder.ins().bitcast(types::I64, MemFlags::new(), rf)
                    }
                    "==." => fcmp(self, FloatCC::Equal),
                    "<." => fcmp(self, FloatCC::LessThan),
                    ">." => fcmp(self, FloatCC::GreaterThan),
                    other => {
                        return Err(format!(
                            "float operator '{other}' does not compile natively"
                        ))
                    }
                })
            }
            // Int → Float (signed) and Float → Int (truncating). The f64 is
            // carried as its i64 bit-pattern, so bitcast at the boundaries.
            Op::IntToFloat(a) => {
                let x = self.atom(a)?;
                let f = self.builder.ins().fcvt_from_sint(types::F64, x);
                Ok(self.builder.ins().bitcast(types::I64, MemFlags::new(), f))
            }
            Op::FloatToInt(a) => {
                let x = self.atom(a)?;
                let f = self.builder.ins().bitcast(types::F64, MemFlags::new(), x);
                Ok(self.builder.ins().fcvt_to_sint(types::I64, f))
            }
            // unary Float math via native Cranelift IEEE instructions.
            Op::FloatUnary(o, a) => {
                let x = self.atom(a)?;
                let f = self.builder.ins().bitcast(types::F64, MemFlags::new(), x);
                let r = match o.as_str() {
                    "sqrt" => self.builder.ins().sqrt(f),
                    "floor" => self.builder.ins().floor(f),
                    "abs" => self.builder.ins().fabs(f),
                    other => {
                        return Err(format!("float builtin '{other}' does not compile natively"))
                    }
                };
                Ok(self.builder.ins().bitcast(types::I64, MemFlags::new(), r))
            }
            Op::CallDirect(name, args, _) => {
                let (id, arity) = *self
                    .ids
                    .get(name)
                    .ok_or_else(|| format!("function '{name}' is not natively compilable"))?;
                if args.len() != arity {
                    return Err(format!("'{name}' called with wrong arity"));
                }
                let vals = self.atoms(args)?;
                let callee = self.module.declare_func_in_func(id, self.builder.func);
                let call = self.builder.ins().call(callee, &vals);
                Ok(self.builder.inst_results(call)[0])
            }
            Op::CallClosure(clos, args) => {
                let c = self.atom(clos)?;
                let vals = self.atoms(args)?;
                Ok(self.call_closure(c, &vals))
            }
            Op::MakeClosure { func, captures } => {
                let (lam_id, _) = *self
                    .ids
                    .get(func)
                    .ok_or_else(|| format!("lambda '{func}' not declared"))?;
                let env = self.alloc(1 + captures.len());
                let fref = self.module.declare_func_in_func(lam_id, self.builder.func);
                let faddr = self.builder.ins().func_addr(types::I64, fref);
                self.builder.ins().store(MemFlags::new(), faddr, env, 0);
                for (i, cap) in captures.iter().enumerate() {
                    let cv = self.atom(cap)?;
                    self.builder
                        .ins()
                        .store(MemFlags::new(), cv, env, (i as i32 + 1) * 8);
                }
                Ok(env)
            }
            Op::MakeTuple(xs) => {
                let ptr = self.alloc(xs.len());
                for (i, a) in xs.iter().enumerate() {
                    let v = self.atom(a)?;
                    self.builder
                        .ins()
                        .store(MemFlags::new(), v, ptr, i as i32 * 8);
                }
                Ok(ptr)
            }
            Op::MakeRecord { con, fields, .. } => {
                let slots = self
                    .records
                    .con_slots(con)
                    .ok_or_else(|| format!("unknown constructor '{con}'"))?;
                let ptr = self.alloc(slots);
                self.store_tag(con, ptr);
                for (fname, a) in fields {
                    let off = self
                        .records
                        .field(fname)
                        .map(|(o, _)| o)
                        .ok_or_else(|| format!("unknown field '{fname}'"))?;
                    let v = self.atom(a)?;
                    self.builder.ins().store(MemFlags::new(), v, ptr, off);
                }
                Ok(ptr)
            }
            Op::MakeCon { con, args, .. } => {
                // unboxed enum constructor (all-nullary type): an immediate tag,
                // no allocation.
                if self.records.is_enum_con(con) {
                    let idx = self.records.con_index(con);
                    return Ok(self.builder.ins().iconst(types::I64, idx as i64));
                }
                // nullary constructor of a mixed type: tagged immediate
                // `(index<<1)|1` — distinguishable from an (aligned) heap pointer.
                if self.records.is_tagged_nullary(con) {
                    let imm = ((self.records.con_index(con) as i64) << 1) | 1;
                    return Ok(self.builder.ins().iconst(types::I64, imm));
                }
                // positional `data` value (with a tag if it is a sum type)
                let slots = self
                    .records
                    .con_slots(con)
                    .ok_or_else(|| format!("unknown constructor '{con}'"))?;
                let ptr = self.alloc(slots);
                self.store_tag(con, ptr);
                for (i, a) in args.iter().enumerate() {
                    let off = self.records.field_offset(con, i);
                    let v = self.atom(a)?;
                    self.builder.ins().store(MemFlags::new(), v, ptr, off);
                }
                Ok(ptr)
            }
            Op::UpdateRecord {
                base,
                fields,
                inplace,
            } => {
                let base_ptr = self.atom(base)?;
                // Linear Elision (§2): in-place mutates the base's block and returns it;
                // otherwise allocates a new one and copies the non-updated fields.
                let target = if *inplace {
                    base_ptr
                } else {
                    let first = &fields
                        .first()
                        .ok_or_else(|| "empty record update".to_string())?
                        .0;
                    let nfields = self
                        .records
                        .field(first)
                        .map(|(_, fs)| fs.len())
                        .ok_or_else(|| format!("unknown field '{first}'"))?;
                    let newptr = self.alloc(nfields);
                    for i in 0..nfields {
                        let off = i as i32 * 8;
                        let v = self
                            .builder
                            .ins()
                            .load(types::I64, MemFlags::new(), base_ptr, off);
                        self.builder.ins().store(MemFlags::new(), v, newptr, off);
                    }
                    newptr
                };
                for (fname, a) in fields {
                    let off = self
                        .records
                        .field(fname)
                        .map(|(o, _)| o)
                        .ok_or_else(|| format!("unknown field '{fname}'"))?;
                    let v = self.atom(a)?;
                    self.builder.ins().store(MemFlags::new(), v, target, off);
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
                Ok(self.builder.ins().load(types::I64, MemFlags::new(), r, off))
            }
            Op::LoadRaw(a, off) => {
                let r = self.atom(a)?;
                Ok(self
                    .builder
                    .ins()
                    .load(types::I64, MemFlags::new(), r, *off))
            }
            Op::StoreRaw(ptr, off, val) => {
                let p = self.atom(ptr)?;
                let v = self.atom(val)?;
                self.builder.ins().store(MemFlags::new(), v, p, *off);
                Ok(v)
            }
            Op::FuncAddr(name) => {
                let (id, _) = *self
                    .ids
                    .get(name)
                    .ok_or_else(|| format!("FuncAddr of undeclared function '{name}'"))?;
                let fref = self.module.declare_func_in_func(id, self.builder.func);
                Ok(self.builder.ins().func_addr(types::I64, fref))
            }
            Op::PutStrLn(a) => {
                let v = self.atom(a)?;
                let callee = self
                    .module
                    .declare_func_in_func(self.println_id, self.builder.func);
                self.builder.ins().call(callee, &[v]);
                Ok(self.builder.ins().iconst(types::I64, 0)) // IO () → token
            }
            Op::PutStr(a) => {
                let v = self.atom(a)?;
                let callee = self
                    .module
                    .declare_func_in_func(self.print_id, self.builder.func);
                self.builder.ins().call(callee, &[v]);
                Ok(self.builder.ins().iconst(types::I64, 0)) // IO () → token
            }
            Op::ShowInt(a) => {
                let v = self.atom(a)?;
                let callee = self
                    .module
                    .declare_func_in_func(self.show_id, self.builder.func);
                let call = self.builder.ins().call(callee, &[v]);
                Ok(self.builder.inst_results(call)[0])
            }
            // --- arenas (§3) ---
            Op::WithArena { clos, .. } => {
                // creates the (sub-)arena, runs the closure with it, resets it at the end.
                let cv = self.atom(clos)?;
                let arena = self.rt_call(self.arena.new, &[]).ok_or("arena new")?;
                let r = self.call_closure(cv, &[arena]);
                self.rt_call(self.arena.reset, &[arena]);
                Ok(r)
            }
            Op::ArenaAlloc(a) => {
                let av = self.atom(a)?;
                let sz = self.builder.ins().iconst(types::I64, CELL_SIZE);
                Ok(self
                    .rt_call(self.arena.alloc, &[av, sz])
                    .ok_or("arena call")?)
            }
            Op::Promote(t, c) => {
                let tv = self.atom(t)?;
                let cv = self.atom(c)?;
                let sz = self.builder.ins().iconst(types::I64, CELL_SIZE);
                Ok(self
                    .rt_call(self.arena.promote, &[tv, cv, sz])
                    .ok_or("arena call")?)
            }
            Op::ArenaMark(a) => {
                let av = self.atom(a)?;
                Ok(self.rt_call(self.arena.mark, &[av]).ok_or("arena call")?)
            }
            Op::ArenaRelease(m) => {
                let mv = self.atom(m)?;
                self.rt_call(self.arena.release, &[mv]);
                Ok(self.builder.ins().iconst(types::I64, 0)) // () → token
            }
            Op::RtCall {
                func,
                args,
                returns,
            } => {
                let (id, _) = *self
                    .rt_fns
                    .get(func)
                    .ok_or_else(|| format!("unknown runtime builtin '{func}'"))?;
                let vals = self.atoms(args)?;
                let r = self.rt_call(id, &vals);
                Ok(r.unwrap_or_else(|| {
                    debug_assert!(!returns);
                    self.builder.ins().iconst(types::I64, 0)
                }))
            }
            Op::Ffi { name, args } => {
                // FFI (§18): declares the C function (Int ABI) and calls it; the symbol
                // resolved via dlsym (symbol_lookup_fn).
                let mut sig = self.module.make_signature();
                for _ in args {
                    sig.params.push(AbiParam::new(types::I64));
                }
                sig.returns.push(AbiParam::new(types::I64));
                let id = self
                    .module
                    .declare_function(name, Linkage::Import, &sig)
                    .map_err(|e| e.to_string())?;
                let vals = self.atoms(args)?;
                let callee = self.module.declare_func_in_func(id, self.builder.func);
                let call = self.builder.ins().call(callee, &vals);
                Ok(self.builder.inst_results(call)[0])
            }
            Op::ArrayNew { len, init, .. } => {
                let vals = self.atoms(&[len.clone(), init.clone()])?;
                let (id, _) = *self
                    .rt_fns
                    .get("axion_array_new")
                    .ok_or_else(|| "unknown runtime builtin 'axion_array_new'".to_string())?;
                let r = self.rt_call(id, &vals);
                Ok(r.unwrap_or_else(|| self.builder.ins().iconst(types::I64, 0)))
            }
            Op::Unsupported(m) => Err(format!("{m} does not compile natively (yet)")),
        }
    }

    /// Calls a runtime function by `FuncId`; returns the result if any.
    fn rt_call(&mut self, id: FuncId, args: &[Value]) -> Option<Value> {
        let callee = self.module.declare_func_in_func(id, self.builder.func);
        let call = self.builder.ins().call(callee, args);
        self.builder.inst_results(call).first().copied()
    }

    /// `case s of arms` — an `if` chain over the scrutinee. Patterns: `Int`
    /// (compare), variable/`_` (catch-all), tuple `(a, b)` (destructure by
    /// offset). Requires a catch-all at the end.
    /// The effective constructor tag of a scrutinee, by its type's category:
    /// unboxed enum → the value itself; boxed sum → the tag at offset 0; mixed →
    /// `(v & 1) ? (v >> 1) : load[v]` (immediate nullary vs heap pointer).
    fn case_eff_tag(&mut self, sval: Value, con: &str) -> Value {
        if self.records.is_enum_con(con) {
            return sval;
        }
        if !self.records.is_mixed_con(con) {
            return self
                .builder
                .ins()
                .load(types::I64, MemFlags::new(), sval, 0);
        }
        let bit = self.builder.ins().band_imm(sval, 1);
        let imm_b = self.builder.create_block();
        let ptr_b = self.builder.create_block();
        let merge = self.builder.create_block();
        self.builder.append_block_param(merge, types::I64);
        self.builder.ins().brif(bit, imm_b, &[], ptr_b, &[]);

        self.builder.switch_to_block(imm_b);
        self.builder.seal_block(imm_b);
        let ei = self.builder.ins().ushr_imm(sval, 1);
        self.builder.ins().jump(merge, &[ei]);

        self.builder.switch_to_block(ptr_b);
        self.builder.seal_block(ptr_b);
        let ep = self
            .builder
            .ins()
            .load(types::I64, MemFlags::new(), sval, 0);
        self.builder.ins().jump(merge, &[ep]);

        self.builder.switch_to_block(merge);
        self.builder.seal_block(merge);
        self.builder.block_params(merge)[0]
    }

    /// Tail-position `case`: same tag dispatch as `emit_case`, but each arm body is
    /// emitted in tail position (terminates directly) instead of producing a value
    /// merged by a phi — so a tail self-call inside an arm becomes a loop jump.
    fn emit_case_tail(
        &mut self,
        sval: Value,
        arms: &[(CPat, Term)],
        i: usize,
    ) -> Result<(), String> {
        let (pat, body) = &arms[i];
        match pat {
            CPat::Wild => self.emit_term_tail(body),
            CPat::Var(n) => {
                self.bind_val(n, sval);
                self.emit_term_tail(body)
            }
            CPat::Tuple(ps) => {
                for (j, p) in ps.iter().enumerate() {
                    if let CPat::Var(n) = p {
                        let v = self.builder.ins().load(
                            types::I64,
                            MemFlags::new(),
                            sval,
                            j as i32 * 8,
                        );
                        self.bind_val(n, v);
                    } else if !matches!(p, CPat::Wild) {
                        return Err("nested tuple pattern does not compile natively".into());
                    }
                }
                self.emit_term_tail(body)
            }
            CPat::Int(lit) => {
                if i + 1 >= arms.len() {
                    return Err("case without catch-all does not compile natively (yet)".into());
                }
                let k = self.builder.ins().iconst(types::I64, *lit);
                let cond = self.builder.ins().icmp(IntCC::Equal, sval, k);
                self.branch_arm_tail(cond, |s| s.emit_term_tail(body), sval, arms, i)
            }
            CPat::Con(con, subpats) => match self.records.tag(con) {
                None => {
                    self.destructure_con(con, subpats, sval)?;
                    self.emit_term_tail(body)
                }
                Some(_) if i + 1 >= arms.len() => {
                    self.destructure_con(con, subpats, sval)?;
                    self.emit_term_tail(body)
                }
                Some(tag) => {
                    let ktag = self.case_eff_tag(sval, con);
                    let kt = self.builder.ins().iconst(types::I64, tag as i64);
                    let cond = self.builder.ins().icmp(IntCC::Equal, ktag, kt);
                    self.branch_arm_tail(
                        cond,
                        |s| {
                            s.destructure_con(con, subpats, sval)?;
                            s.emit_term_tail(body)
                        },
                        sval,
                        arms,
                        i,
                    )
                }
            },
        }
    }

    /// A tail-position arm test: `then` (the matched arm) and `else` (the rest of
    /// the chain) each terminate — no merge block.
    fn branch_arm_tail(
        &mut self,
        cond: Value,
        then: impl FnOnce(&mut Self) -> Result<(), String>,
        sval: Value,
        arms: &[(CPat, Term)],
        i: usize,
    ) -> Result<(), String> {
        let then_b = self.builder.create_block();
        let else_b = self.builder.create_block();
        self.builder.ins().brif(cond, then_b, &[], else_b, &[]);
        self.builder.switch_to_block(then_b);
        self.builder.seal_block(then_b);
        then(self)?;
        self.builder.switch_to_block(else_b);
        self.builder.seal_block(else_b);
        self.emit_case_tail(sval, arms, i + 1)
    }

    fn emit_case(&mut self, sval: Value, arms: &[(CPat, Term)], i: usize) -> Result<Value, String> {
        let (pat, body) = &arms[i];
        match pat {
            CPat::Wild => self.emit_term(body),
            CPat::Var(n) => {
                self.bind_val(n, sval);
                self.emit_term(body)
            }
            CPat::Tuple(ps) => {
                for (j, p) in ps.iter().enumerate() {
                    match p {
                        CPat::Wild => {}
                        CPat::Var(n) => {
                            let v = self.builder.ins().load(
                                types::I64,
                                MemFlags::new(),
                                sval,
                                j as i32 * 8,
                            );
                            self.bind_val(n, v);
                        }
                        _ => return Err("nested tuple pattern does not compile natively".into()),
                    }
                }
                self.emit_term(body)
            }
            CPat::Int(lit) => {
                if i + 1 >= arms.len() {
                    return Err("case without catch-all does not compile natively (yet)".into());
                }
                let k = self.builder.ins().iconst(types::I64, *lit);
                let cond = self.builder.ins().icmp(IntCC::Equal, sval, k);
                let then_b = self.builder.create_block();
                let else_b = self.builder.create_block();
                let merge_b = self.builder.create_block();
                self.builder.append_block_param(merge_b, types::I64);
                self.builder.ins().brif(cond, then_b, &[], else_b, &[]);

                self.builder.switch_to_block(then_b);
                self.builder.seal_block(then_b);
                let tv = self.emit_term(body)?;
                self.builder.ins().jump(merge_b, &[tv]);

                self.builder.switch_to_block(else_b);
                self.builder.seal_block(else_b);
                let ev = self.emit_case(sval, arms, i + 1)?;
                self.builder.ins().jump(merge_b, &[ev]);

                self.builder.switch_to_block(merge_b);
                self.builder.seal_block(merge_b);
                Ok(self.builder.block_params(merge_b)[0])
            }
            CPat::Con(con, subpats) => {
                // 1-constructor type (no tag) or last arm: destructure without
                // testing the tag (assumed exhaustive). Otherwise, compare the tag.
                match self.records.tag(con) {
                    None => {
                        self.destructure_con(con, subpats, sval)?;
                        self.emit_term(body)
                    }
                    Some(_) if i + 1 >= arms.len() => {
                        self.destructure_con(con, subpats, sval)?;
                        self.emit_term(body)
                    }
                    Some(tag) => {
                        let ktag = self.case_eff_tag(sval, con);
                        let kt = self.builder.ins().iconst(types::I64, tag as i64);
                        let cond = self.builder.ins().icmp(IntCC::Equal, ktag, kt);
                        let then_b = self.builder.create_block();
                        let else_b = self.builder.create_block();
                        let merge_b = self.builder.create_block();
                        self.builder.append_block_param(merge_b, types::I64);
                        self.builder.ins().brif(cond, then_b, &[], else_b, &[]);

                        self.builder.switch_to_block(then_b);
                        self.builder.seal_block(then_b);
                        self.destructure_con(con, subpats, sval)?;
                        let tv = self.emit_term(body)?;
                        self.builder.ins().jump(merge_b, &[tv]);

                        self.builder.switch_to_block(else_b);
                        self.builder.seal_block(else_b);
                        let ev = self.emit_case(sval, arms, i + 1)?;
                        self.builder.ins().jump(merge_b, &[ev]);

                        self.builder.switch_to_block(merge_b);
                        self.builder.seal_block(merge_b);
                        Ok(self.builder.block_params(merge_b)[0])
                    }
                }
            }
        }
    }

    /// Binds the sub-patterns (variables) of a constructor to its fields.
    fn destructure_con(&mut self, con: &str, subpats: &[CPat], sval: Value) -> Result<(), String> {
        for (j, p) in subpats.iter().enumerate() {
            match p {
                CPat::Wild => {}
                CPat::Var(n) => {
                    let off = self.records.field_offset(con, j);
                    let v = self
                        .builder
                        .ins()
                        .load(types::I64, MemFlags::new(), sval, off);
                    self.bind_val(n, v);
                }
                _ => return Err("nested pattern in a constructor does not compile natively".into()),
            }
        }
        Ok(())
    }
}

/// JIT-compiles the Core and runs `entry` (a parameterless function). Returns `Some(n)`
/// if `entry :: Int` (the caller prints `n`); `None` if `:: IO ()` (the effects
/// have already been executed during the run).
#[allow(clippy::too_many_arguments)]
pub fn run(
    module: &ast::Module,
    entry: &str,
    inplace: &HashSet<Span>,
    fuse: bool,
    makecon_tys: &HashMap<Span, ast::Type>,
    integer_pats: &HashSet<Span>,
    consume_exempt: &HashSet<String>,
    where_ret_tys: &HashMap<String, ast::Type>,
) -> Result<Option<i64>, String> {
    let fns = core::lower_with(
        module,
        inplace,
        makecon_tys,
        &HashMap::new(),
        integer_pats,
        consume_exempt,
        where_ret_tys,
        fuse,
    )
    .fns;
    let entry_ok = fns
        .iter()
        .find(|f| f.name == entry)
        .map(|f| f.params.is_empty())
        .unwrap_or(false);
    if !entry_ok {
        return Err(format!(
            "'{entry}' must be a native function (Int/IO) with no parameters"
        ));
    }

    // FFI (§18): carrega as bibliotecas do utilizador (RTLD_GLOBAL) antes de o
    // JIT to resolve symbols via `dlsym` (`symbol_lookup_fn`).
    crate::ffi::load_libs(&module.foreign_libs())?;

    let mut cg = Cg::new(RecordInfo::build(module))?;
    cg.declare_all(&fns)?;
    for f in &fns {
        let mut ctx = cg.build(f)?;
        let id = cg.ids[&f.name].0;
        cg.module
            .define_function(id, &mut ctx)
            .map_err(|e| e.to_string())?;
        cg.module.clear_context(&mut ctx);
    }
    cg.module
        .finalize_definitions()
        .map_err(|e| e.to_string())?;

    // Bridge the program arguments into the runtime (`axion-rt`'s ARGS). The `--release` path gets
    // them from C `main` via `axion_set_args`; the JIT's `main` takes none, so feed PROG_ARGS here.
    if let Some(args) = crate::PROG_ARGS.get() {
        axion_rt::set_args_rs(args);
    }

    let code = cg.module.get_finalized_function(cg.ids[entry].0);
    // SAFETY: `code` is a finalized JIT function pointer with the declared
    // ABI (extern "C" fn() -> i64); Cranelift guarantees the signature.
    let f: extern "C" fn() -> i64 = unsafe { std::mem::transmute(code) };
    // Run on a thread with a large stack (lazily committed — only touched pages
    // cost memory) so deep NON-tail recursion doesn't overflow the small default
    // stack; it grows toward RAM and, at worst, hits the clean OOM abort.
    let val = std::thread::scope(|s| {
        std::thread::Builder::new()
            .stack_size(EVAL_STACK_SIZE)
            .spawn_scoped(s, || f())
            .map_err(|e| format!("spawn eval thread: {e}"))?
            .join()
            .map_err(|_| "eval thread panicked".to_string())
    });
    let val = val?;

    if std::env::var("AXION_HEAP_STATS").is_ok() {
        // Counters live in the one runtime (`axion-rt`, `heap-stats` feature); reading them here
        // reports the SAME allocator both native backends use.
        let (allocs, frees, news, resets, cells) = axion_rt::heap_stats();
        eprintln!("heap: {allocs} allocs, {frees} frees");
        if news > 0 || cells > 0 {
            eprintln!("arena: {news} news, {resets} resets, {cells} cells");
        }
    }

    let result = module
        .funcs
        .iter()
        .find(|f| f.name == entry)
        .and_then(|f| f.sig.as_ref())
        .map(result_type);
    // `main :: Float` carries its f64 bit-pattern in the i64 ABI: reinterpret
    // and print here (the caller only knows how to print an Int).
    if result.is_some_and(is_float) {
        println!("{}", f64::from_bits(val as u64));
        return Ok(None);
    }
    // `main :: Bool` is an i64 0/1: print like the interpreter (`true`/`false`).
    if result.is_some_and(is_bool) {
        println!("{}", val != 0);
        return Ok(None);
    }
    let returns_int = result.map(is_int).unwrap_or(true);
    Ok(returns_int.then_some(val))
}

/// Emits the Cranelift IR (text) of the Core functions, without JIT
/// (`--emit clif`). The stream-fusion pass runs inside `core::lower`; the
/// `--fuse` flag is threaded through so the dump matches the JIT's code.
pub fn emit_ir(
    module: &ast::Module,
    inplace: &HashSet<Span>,
    fuse: bool,
    makecon_tys: &HashMap<Span, ast::Type>,
    integer_pats: &HashSet<Span>,
    consume_exempt: &HashSet<String>,
    where_ret_tys: &HashMap<String, ast::Type>,
) -> Result<String, String> {
    let fns = core::lower_with(
        module,
        inplace,
        makecon_tys,
        &HashMap::new(),
        integer_pats,
        consume_exempt,
        where_ret_tys,
        fuse,
    )
    .fns;
    if fns.is_empty() {
        return Ok("; no natively compilable function (Int core).\n".into());
    }
    let mut cg = Cg::new(RecordInfo::build(module))?;
    cg.declare_all(&fns)?;
    let mut out = String::new();
    for f in &fns {
        let ctx = cg.build(f)?;
        out.push_str(&format!("{}\n", ctx.func.display()));
    }
    Ok(out)
}

/// Emit the `--dev`/Cranelift CLIF for `lowered` AND the reclamation-TV symbol maps (§6). The CLIF
/// text names functions/callees by `FuncId` index (`u0:N`), not symbol; the maps let
/// `codegen_tv::observed_clif` resolve those indices back to the reclamation tokens
/// `codegen_tv::expected` produces — so the Cranelift backend's emitted frees can be checked 1:1
/// against the Core `Drop` sites, exactly as the LLVM path is. Lowering is done by the caller so
/// EXPECTED and OBSERVED share identical Core.
/// CLIF text + the reclamation-TV symbol maps: `(clif, fn_names, reclaim_callees)`, all keyed by
/// `FuncId` index (see [`Cg::reclaim_tv_maps`]).
pub type TvClif = (String, HashMap<u32, String>, HashMap<u32, String>);

pub fn emit_ir_tv(lowered: &core::Lowered, records: RecordInfo) -> Result<TvClif, String> {
    let mut cg = Cg::new(records)?;
    cg.declare_all(&lowered.fns)?;
    let mut out = String::new();
    for f in &lowered.fns {
        let ctx = cg.build(f)?;
        out.push_str(&format!("{}\n", ctx.func.display()));
    }
    let (fn_names, reclaim) = cg.reclaim_tv_maps();
    Ok((out, fn_names, reclaim))
}
