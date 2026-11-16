//! The ownership table of the runtime calls (`Op::RtCall`) the compiler emits — the single
//! place that says, for each `axion_*`/`ax_net_*` function, whether it BORROWS or CONSUMES its
//! arguments and what it returns. `delta::op_delta_effect` reads it (so Auto-Drop and the drop
//! verifier share it), and the tests below keep it honest:
//!
//! * every runtime function `core.rs` can emit has an entry (a new builtin cannot silently fall
//!   back to a default);
//! * every entry names a function the runtime (`axion-rt`) defines;
//! * every built-in name the type checker knows (`infer::builtin_names`) is listed in
//!   [`SURFACE`] with how it lowers.
//!
//! Each entry was checked against the runtime function's body: `Borrow` means the runtime
//! never frees or keeps the argument (the caller still drops it), `Move` means it frees it,
//! stores it, or it is a scalar. `assumes` records what the entry relies on that the type
//! system alone does not guarantee.

/// What a runtime call does with its arguments (all of them: the per-call split never differs
/// for a heap argument — scalars are unaffected either way).
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ArgOwn {
    /// Reads them; the caller keeps ownership and frees them.
    Borrow,
    /// Frees them, keeps them, or they are scalars.
    Move,
}

/// What a runtime call returns.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Out {
    /// A scalar, a handle managed elsewhere, or nothing.
    Scalar,
    /// A fresh heap value the caller owns, reclaimed by the destructor of this key.
    Owned(&'static str),
    /// A fresh flat heap block the caller owns (no keyed destructor: `axion_free`).
    OwnedFlat,
}

pub struct RtEntry {
    pub func: &'static str,
    pub args: ArgOwn,
    pub out: Out,
    /// What the classification relies on beyond the runtime body itself ("" if nothing).
    /// Documentation, checked by the tests.
    #[cfg_attr(not(test), allow(dead_code))]
    pub assumes: &'static str,
}

const fn e(func: &'static str, args: ArgOwn, out: Out) -> RtEntry {
    RtEntry {
        func,
        args,
        out,
        assumes: "",
    }
}

const fn ea(func: &'static str, args: ArgOwn, out: Out, assumes: &'static str) -> RtEntry {
    RtEntry {
        func,
        args,
        out,
        assumes,
    }
}

use ArgOwn::{Borrow as B, Move as M};
use Out::{Owned, OwnedFlat, Scalar};

const STR: Out = Owned("String");
const INTEGER: Out = Owned("Integer");

/// Element types the raw array calls assume: they store raw words and own nothing inside them.
/// An array of heap elements goes through the generated `axion_arrop_*` helpers instead, which
/// copy elements in and out and free replaced ones (core.rs `gen_array_helpers`).
const SCALAR_ELEMS: &str = "raw elements are scalars: heap elements go through the generated \
                            axion_arrop_* helpers (copy in/out); the rest is rejected, AX0914";
const SESSION: &str = "session runtime: payload ownership follows the protocol (SessGen); the \
                       generated steps are verified like any function (corruption and leaks)";

pub const RT_TABLE: &[RtEntry] = &[
    // --- frees (the destructors Auto-Drop and the generated code call) ---
    e("axion_free", M, Scalar),
    e("axion_str_drop", M, Scalar),
    e("axion_bignum_free", M, Scalar),
    e("axion_buf_free", M, Scalar),
    e("axion_array_free", M, Scalar),
    // --- copies (generated `axion_copy_*` copiers and session hand-off) ---
    e("axion_block_copy", B, OwnedFlat),
    // closure cells: dropped/copied through the cell's own destructor/copier when it owns its
    // captures (a closure stored in a structure or returned), else as a flat block
    e("axion_closure_drop", M, Scalar),
    e("axion_closure_copy", B, Owned("Closure")),
    e("axion_buf_copy", B, Owned("Buffer")),
    e("axion_bignum_copy", B, INTEGER),
    // --- strings ---
    e("axion_strcat", B, STR),
    e("axion_substr", B, STR),
    e("axion_show_float", B, STR),
    e("axion_chr", B, STR),
    e("axion_str_len", B, Scalar),
    e("axion_str_at", B, Scalar),
    e("axion_str_cmp", B, Scalar),
    // --- Integer (bignum) ---
    e("axion_bignum_add", B, INTEGER),
    e("axion_bignum_sub", B, INTEGER),
    e("axion_bignum_mul", B, INTEGER),
    e("axion_bignum_div", B, INTEGER),
    e("axion_bignum_mod", B, INTEGER),
    e("axion_bignum_from_str", B, INTEGER),
    e("axion_bignum_from_i64", B, INTEGER),
    e("axion_bignum_to_string", B, STR),
    e("axion_bignum_eq", B, Scalar),
    e("axion_bignum_lt", B, Scalar),
    e("axion_bignum_gt", B, Scalar),
    // --- OS capabilities: read their String args, return a fresh String or a scalar ---
    e("axion_getenv", B, STR),
    e("axion_run", B, STR),
    e("axion_exec_capture", B, STR),
    e("axion_read_file", B, STR),
    e("axion_readdir", B, STR),
    e("axion_readdir_typed", B, STR),
    e("axion_readdir_listing", B, STR),
    e("axion_read_line", B, STR),
    e("axion_read_secret", B, STR),
    e("axion_read_key", B, STR),
    e("axion_read_key_timeout", B, STR),
    e("axion_rand_hex", B, STR),
    e("axion_getargs", B, STR),
    e("axion_getarg", B, STR),
    e("axion_system", B, Scalar),
    e("axion_exec_status", B, Scalar),
    e("axion_eput", B, Scalar),
    e("axion_eputs", B, Scalar),
    e("axion_write_file", B, Scalar),
    e("axion_file_exists", B, Scalar),
    e("axion_mkdir_p", B, Scalar),
    e("axion_unlink", B, Scalar),
    e("axion_rename", B, Scalar),
    e("axion_exit", B, Scalar),
    e("axion_resized", B, Scalar),
    // --- files (an fd or -errno) ---
    e("axion_file_open", B, Scalar),
    e("axion_file_errno", B, Scalar),
    e("axion_file_size", B, Scalar),
    e("axion_file_close", B, Scalar),
    e("axion_file_read", M, Owned("Buffer")),
    // --- Buffer: in-place ops consume the buffer and return the same block ---
    e("axion_buf_new", M, Owned("Buffer")),
    e("axion_buf_iota", M, Owned("Buffer")),
    e("axion_buf_xor", M, Owned("Buffer")),
    e("axion_buf_len", B, Scalar),
    e("axion_buf_sum", B, Scalar),
    e("axion_buf_ptr", B, Scalar),
    e("axion_buf_ptr_n", B, Scalar),
    e("axion_peek_u8", B, Scalar),
    e("axion_peek_u16", B, Scalar),
    e("axion_peek_u32", B, Scalar),
    e("axion_peek_u64", B, Scalar),
    e("axion_peek_f64", B, Scalar),
    e("axion_poke_u8", B, Scalar),
    e("axion_poke_u16", B, Scalar),
    e("axion_poke_u32", B, Scalar),
    e("axion_poke_u64", B, Scalar),
    e("axion_poke_f64", B, Scalar),
    ea(
        "axion_fold_bytes",
        B,
        Scalar,
        "the closure's result is a scalar accumulator",
    ),
    // --- Array (i64 words) ---
    ea("axion_array_new", M, Owned("Array"), SCALAR_ELEMS),
    ea("axion_array_set", M, Owned("Array"), SCALAR_ELEMS),
    ea("axion_array_get", B, Scalar, SCALAR_ELEMS),
    ea(
        "axion_array_get_nobc",
        B,
        Scalar,
        "index proven in bounds for every iteration by the bce.rs entry guard",
    ),
    ea(
        "axion_array_set_nobc",
        M,
        Owned("Array"),
        "index proven in bounds for every iteration by the bce.rs entry guard",
    ),
    e("axion_array_len", B, Scalar),
    e("axion_array_iota", M, Owned("Array")),
    e("axion_array_sum", B, Scalar),
    e("axion_array_dot", B, Scalar),
    // --- I8Array / I32Array / TritVec (monomorphic integer elements) ---
    e("axion_i8_new", M, Owned("I8Array")),
    e("axion_i8_iota", M, Owned("I8Array")),
    e("axion_i8_set", M, Owned("I8Array")),
    e("axion_i8_get", B, Scalar),
    e("axion_i8_len", B, Scalar),
    e("axion_i8_sum", B, Scalar),
    e("axion_i8_dot", B, Scalar),
    e("axion_i8_dot_i8", B, Scalar),
    e("axion_i8_matvec_sum", B, Scalar),
    e("axion_i32_new", M, Owned("I32Array")),
    e("axion_i32_iota", M, Owned("I32Array")),
    e("axion_i32_set", M, Owned("I32Array")),
    e("axion_i32_get", B, Scalar),
    e("axion_i32_len", B, Scalar),
    e("axion_i32_sum", B, Scalar),
    e("axion_i32_dot", B, Scalar),
    e("axion_i32_matvec_sum", B, Scalar),
    e("axion_tritvec_new", M, Owned("TritVec")),
    e("axion_tritvec_iota", M, Owned("TritVec")),
    e("axion_tritvec_set", M, Owned("TritVec")),
    e("axion_tritvec_from_buffer", B, Owned("TritVec")),
    e("axion_tritvec_get", B, Scalar),
    e("axion_tritvec_len", B, Scalar),
    e("axion_tritvec_dot", B, Scalar),
    e("axion_tritvec_matvec_sum", B, Scalar),
    // --- sockets (fds are scalars; data/host strings are only read) ---
    e("ax_net_connect", B, Scalar),
    e("ax_net_listen", B, Scalar),
    e("ax_net_accept", B, Scalar),
    e("ax_net_close", B, Scalar),
    e("ax_net_set_nonblocking", B, Scalar),
    e("ax_net_wouldblock", B, Scalar),
    e("ax_net_send", B, Scalar),
    e("ax_net_send_buf", B, Scalar),
    ea(
        "ax_net_recv",
        B,
        Scalar,
        "returns a fresh String or the would-block sentinel; only SessGen calls it and it frees \
         the String itself",
    ),
    // --- sessions / concurrency ---
    ea("axion_sess_new", M, Scalar, SESSION),
    ea("axion_sess_alloc", M, Scalar, SESSION),
    ea("axion_sess_channel", M, Scalar, SESSION),
    ea("axion_sess_spawn", M, Scalar, SESSION),
    ea("axion_sess_send", M, Scalar, SESSION),
    ea("axion_sess_recv", M, Scalar, SESSION),
    ea("axion_sess_pending", M, Scalar, SESSION),
    ea("axion_sess_park_fd", M, Scalar, SESSION),
    ea("axion_sess_run", M, Scalar, SESSION),
    ea("axion_sess_run_par", M, Scalar, SESSION),
    ea("axion_connect", M, Scalar, SESSION),
    ea("axion_pipe3", M, Scalar, SESSION),
    ea(
        "axion_par_map",
        M,
        Owned("List"),
        "the input list's cells are freed by the runtime driver; a heap reply payload leaks \
         (documented, parMap over a polymorphic List)",
    ),
];

/// The ownership entry of a runtime call, if it has one.
pub fn rt_entry(func: &str) -> Option<&'static RtEntry> {
    RT_TABLE.iter().find(|e| e.func == func)
}

/// Every built-in name the type checker knows (`infer::builtin_names`), with how it lowers.
/// Kept in step by `every_builtin_name_is_in_the_surface_table`: a new built-in must say here
/// what it becomes, and if that is a runtime call, `RT_TABLE` must classify it.
#[cfg_attr(not(test), allow(dead_code))]
pub const SURFACE: &[(&str, &str)] = &[
    // constructors / constants
    ("True", "immediate 1"),
    ("False", "immediate 0"),
    ("otherwise", "immediate 1"),
    ("nullPtr", "immediate 0"),
    // operators: scalar primitives (Op::Prim / Op::PrimF), no heap
    ("+", "Op::Prim"),
    ("-", "Op::Prim"),
    ("*", "Op::Prim"),
    ("/", "Op::Prim (Int div) / Op::PrimF (Float)"),
    ("div", "Op::Prim"),
    ("mod", "Op::Prim"),
    ("abs", "Op::Prim"),
    ("<", "Op::Prim"),
    (">", "Op::Prim"),
    (
        "==",
        "Op::Prim (Int/Float); strings and data go through prelude Eq",
    ),
    ("+.", "Op::PrimF"),
    ("-.", "Op::PrimF"),
    ("*.", "Op::PrimF"),
    ("/.", "Op::PrimF"),
    ("<.", "Op::PrimF"),
    (">.", "Op::PrimF"),
    ("==.", "Op::PrimF"),
    ("sqrt", "Op::FloatUnary"),
    ("floor", "Op::FloatUnary"),
    (
        "++",
        "axion_strcat on String (`++#str`); otherwise the prelude list append",
    ),
    // pure scalar ops
    ("toFloat", "Op::IntToFloat"),
    ("truncate", "Op::FloatToInt"),
    ("intToPtr", "identity (scalar)"),
    ("ptrToInt", "identity (scalar)"),
    ("handleAddr", "identity (scalar)"),
    ("imperative", "its argument"),
    // strings / show / IO
    ("showInt", "Op::ShowInt (borrow, fresh String)"),
    ("showFloat", "axion_show_float"),
    ("showInteger", "axion_bignum_to_string"),
    ("strAppend", "axion_strcat"),
    ("strLen", "axion_str_len"),
    ("charAt", "axion_str_at"),
    ("substr", "axion_substr"),
    ("strCmp", "axion_str_cmp"),
    ("chr", "axion_chr"),
    ("putStr", "Op::PutStr (borrow)"),
    ("putStrLn", "Op::PutStrLn (borrow)"),
    ("ePutStr", "axion_eput"),
    ("ePutStrLn", "axion_eputs"),
    // Integer
    ("fromInt", "axion_bignum_from_i64"),
    ("bignumFromStr", "axion_bignum_from_str"),
    ("divInteger", "axion_bignum_div"),
    ("modInteger", "axion_bignum_mod"),
    // OS capabilities
    ("getEnv", "axion_getenv"),
    ("runCapture", "axion_run"),
    ("runStatus", "axion_system"),
    ("execCapture", "axion_exec_capture"),
    ("execStatus", "axion_exec_status"),
    ("readFile", "axion_read_file"),
    ("writeFile", "axion_write_file"),
    ("fileExists", "axion_file_exists"),
    ("makeDir", "axion_mkdir_p"),
    ("removeFile", "axion_unlink"),
    ("renameFile", "axion_rename"),
    ("readDir", "axion_readdir"),
    ("readDirTyped", "axion_readdir_typed"),
    ("readDirListing", "axion_readdir_listing"),
    ("readLine", "axion_read_line"),
    ("readSecret", "axion_read_secret"),
    ("readKey", "axion_read_key"),
    ("readKeyTimeout", "axion_read_key_timeout"),
    ("resized", "axion_resized"),
    ("randHex", "axion_rand_hex"),
    ("exitWith", "axion_exit"),
    ("getArgs", "axion_getargs"),
    ("getArg", "axion_getarg"),
    // files + buffers
    ("fileOpenRaw", "axion_file_open"),
    ("fileErrno", "axion_file_errno"),
    ("fileSize", "axion_file_size"),
    ("fileRead", "axion_file_read"),
    ("fileClose", "axion_file_close"),
    ("newBuffer", "axion_buf_new"),
    ("bufIota", "axion_buf_iota"),
    ("xorInPlace", "axion_buf_xor"),
    ("sumBytes", "axion_buf_sum"),
    ("bufLen", "axion_buf_len"),
    ("bufPtr", "axion_buf_ptr"),
    ("bufPtrN", "axion_buf_ptr_n"),
    ("free", "axion_buf_free"),
    ("foldBytes", "axion_fold_bytes"),
    ("withBuffer", "newBuffer + its body, freed after"),
    ("peekU8", "axion_peek_u8"),
    ("peekU16", "axion_peek_u16"),
    ("peekU32", "axion_peek_u32"),
    ("peekU64", "axion_peek_u64"),
    ("peekF64", "axion_peek_f64"),
    ("pokeU8", "axion_poke_u8"),
    ("pokeU16", "axion_poke_u16"),
    ("pokeU32", "axion_poke_u32"),
    ("pokeU64", "axion_poke_u64"),
    ("pokeF64", "axion_poke_f64"),
    // arrays (raw scalar elements; heap elements via the axion_arrop_* helpers — AX0914)
    ("newArray", "Op::ArrayNew → axion_array_new"),
    ("getArray", "axion_array_get"),
    ("setArray", "axion_array_set"),
    ("lenArray", "axion_array_len"),
    ("arrayIota", "axion_array_iota"),
    ("arraySum", "axion_array_sum"),
    ("arrayDot", "axion_array_dot"),
    ("newI8Array", "axion_i8_new"),
    ("getI8", "axion_i8_get"),
    ("setI8", "axion_i8_set"),
    ("lenI8", "axion_i8_len"),
    ("i8Iota", "axion_i8_iota"),
    ("i8Sum", "axion_i8_sum"),
    ("i8Dot", "axion_i8_dot"),
    ("i8DotI8", "axion_i8_dot_i8"),
    ("i8MatVecSum", "axion_i8_matvec_sum"),
    ("newI32Array", "axion_i32_new"),
    ("getI32", "axion_i32_get"),
    ("setI32", "axion_i32_set"),
    ("lenI32", "axion_i32_len"),
    ("i32Iota", "axion_i32_iota"),
    ("i32Sum", "axion_i32_sum"),
    ("i32Dot", "axion_i32_dot"),
    ("i32MatVecSum", "axion_i32_matvec_sum"),
    ("newTritVec", "axion_tritvec_new"),
    ("getTritVec", "axion_tritvec_get"),
    ("setTritVec", "axion_tritvec_set"),
    ("lenTritVec", "axion_tritvec_len"),
    ("tritDot", "axion_tritvec_dot"),
    ("tritMatVecSum", "axion_tritvec_matvec_sum"),
    ("tritVecFromBuffer", "axion_tritvec_from_buffer"),
    ("tritVecIota", "axion_tritvec_iota"),
    // arenas
    ("withArena", "Op::WithArena"),
    ("withSubArena", "Op::WithArena"),
    ("allocateCell", "Op::ArenaAlloc"),
    ("promote", "Op::Promote"),
    ("arena_mark", "Op::ArenaMark"),
    ("arena_release", "Op::ArenaRelease"),
    // sessions / concurrency (SessGen: axion_sess_*)
    ("bound", "session nursery (axion_sess_run / _par)"),
    ("spawn", "axion_sess_spawn"),
    ("send", "axion_sess_send"),
    ("recv", "axion_sess_recv"),
    ("newChannel", "axion_sess_channel"),
    ("select", "session branch (axion_sess_send of a tag)"),
    ("offer", "session branch (axion_sess_recv of a tag)"),
    ("cancel", "session close"),
    ("close", "session close"),
    ("join", "session join"),
    ("split", "fractional-permission split (front end only)"),
    ("parMap", "axion_par_map"),
    ("connect", "axion_connect"),
    ("pipe3", "axion_pipe3"),
    // sockets (SessGen suspension points / plain calls)
    ("netListen", "ax_net_listen"),
    ("netAccept", "ax_net_accept"),
    ("netConnect", "ax_net_connect"),
    ("netRecv", "ax_net_recv"),
    ("netSend", "ax_net_send"),
    ("netSendBuf", "ax_net_send_buf"),
    ("netClose", "ax_net_close"),
    ("netCloseL", "ax_net_close"),
];

/// Built-ins the interpreter does not implement on purpose (native-only surfaces: arenas, the
/// packed integer arrays). `every_builtin_runs_on_the_interpreter_or_is_native_only` keeps any
/// other built-in from being native-only by accident (as `bufIota` was).
#[cfg_attr(not(test), allow(dead_code))]
pub const NATIVE_ONLY: &[&str] = &[
    "foldBytes",
    "withBuffer",
    "newI8Array",
    "getI8",
    "setI8",
    "lenI8",
    "i8Iota",
    "i8Sum",
    "i8Dot",
    "i8DotI8",
    "i8MatVecSum",
    "newI32Array",
    "getI32",
    "setI32",
    "lenI32",
    "i32Iota",
    "i32Sum",
    "i32Dot",
    "i32MatVecSum",
    "newTritVec",
    "getTritVec",
    "setTritVec",
    "lenTritVec",
    "tritDot",
    "tritMatVecSum",
    "tritVecFromBuffer",
    "tritVecIota",
    "withArena",
    "withSubArena",
    "allocateCell",
    "promote",
    "arena_mark",
    "arena_release",
];

#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::HashSet;

    /// Every runtime function name `core.rs` mentions (a quoted `axion_*`/`ax_net_*` literal;
    /// prefixes such as `"axion_drop_"` end in `_` and are skipped).
    fn emitted() -> HashSet<String> {
        let src = [include_str!("core.rs"), include_str!("bce.rs")].concat();
        let mut out = HashSet::new();
        // the odd-numbered pieces of a split on `"` are the insides of string literals
        for lit in src.split('"').skip(1).step_by(2) {
            if (lit.starts_with("axion_") || lit.starts_with("ax_net_"))
                && !lit.ends_with('_')
                && lit
                    .chars()
                    .all(|c| c.is_ascii_lowercase() || c.is_ascii_digit() || c == '_')
            {
                out.insert(lit.to_string());
            }
        }
        out
    }

    #[test]
    fn every_emitted_runtime_call_has_an_ownership_entry() {
        let missing: Vec<_> = emitted()
            .into_iter()
            .filter(|f| rt_entry(f).is_none())
            .collect();
        assert!(
            missing.is_empty(),
            "runtime calls with no RT_TABLE entry (say whether they borrow or consume their \
             arguments, and what they return): {missing:?}"
        );
    }

    #[test]
    fn every_ownership_entry_names_a_runtime_function() {
        let rt = include_str!("../../axion-rt/src/lib.rs");
        let missing: Vec<_> = RT_TABLE
            .iter()
            .map(|e| e.func)
            .filter(|f| !rt.contains(&format!("extern \"C\" fn {f}(")))
            .collect();
        assert!(missing.is_empty(), "not defined in axion-rt: {missing:?}");
        let mut seen = HashSet::new();
        for e in RT_TABLE {
            assert!(seen.insert(e.func), "duplicate RT_TABLE entry {}", e.func);
        }
    }

    #[test]
    fn every_builtin_name_is_in_the_surface_table() {
        let listed: HashSet<&str> = SURFACE.iter().map(|(n, _)| *n).collect();
        let missing: Vec<_> = crate::infer::builtin_names()
            .into_iter()
            .filter(|n| !listed.contains(n.as_str()))
            .collect();
        assert!(
            missing.is_empty(),
            "built-ins with no SURFACE entry (say how they lower): {missing:?}"
        );
    }

    #[test]
    fn every_builtin_runs_on_the_interpreter_or_is_native_only() {
        let interp = include_str!("interp.rs");
        let missing: Vec<_> = SURFACE
            .iter()
            .map(|(n, _)| *n)
            // operators are evaluated structurally (`BinOp`), not by name lookup
            .filter(|n| n.chars().next().is_some_and(|c| c.is_alphabetic()))
            .filter(|n| !interp.contains(&format!("\"{n}\"")) && !NATIVE_ONLY.contains(n))
            .collect();
        assert!(
            missing.is_empty(),
            "built-ins the interpreter lacks (implement them, or list them in NATIVE_ONLY): \
             {missing:?}"
        );
    }

    /// The array entries carry their element assumption (the AX0914 gate relies on it).
    #[test]
    fn array_entries_record_the_scalar_element_assumption() {
        for f in ["axion_array_new", "axion_array_set", "axion_array_get"] {
            assert!(
                rt_entry(f).is_some_and(|e| e.assumes.contains("AX0914")),
                "{f}"
            );
        }
    }

    /// A surface entry naming a runtime call must name one that is classified.
    #[test]
    fn surface_runtime_calls_are_classified() {
        for (name, low) in SURFACE {
            for word in low.split(|c: char| !(c.is_ascii_alphanumeric() || c == '_')) {
                if word.starts_with("axion_") || word.starts_with("ax_net_") {
                    assert!(rt_entry(word).is_some(), "{name}: {word} not in RT_TABLE");
                }
            }
        }
    }
}
