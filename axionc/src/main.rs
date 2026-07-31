//! `axionc` — Axion's compiler (§17–18).
//!
//! Pipeline: source `.axi` → lexer (logos) → layout → parser → checking
//! (names + linearity + Auto-Drop) → type inference (HM) → interpreter.
//! Diagnostics with stable `AXnnnn` codes (§8), as text or JSON.
//!
//! Usage:
//!   axionc <file.axi>                compile and run
//!   axionc --check <file.axi>        compile only (parse + typecheck)
//!   axionc --emit json <file>        diagnostics as JSON
//!   axionc --explain AX0001          explain an error code

// The AST model and some diagnostic utilities are deliberately ahead
// of what the walking skeleton consumes (they grow in later phases).
#[allow(dead_code)]
mod ast;
mod check;
mod codegen;
mod core;
#[allow(dead_code)]
mod diag;
mod ffi;
mod infer;
mod interp;
mod layout;
mod lexer;
mod llvm;
mod parser;

#[cfg(test)]
mod props;
#[cfg(test)]
mod session;

use diag::{Diagnostic, Diagnostics};
use lexer::LineMap;
use std::process::ExitCode;

#[derive(PartialEq)]
enum Emit {
    Text,
    Json,
    Drops,
    InPlace,
    Arenas,
    Core,
    Clif,
    Llvm,
}

#[derive(PartialEq)]
enum Backend {
    Interp,
    Cranelift,
    Llvm,
}

fn main() -> ExitCode {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let mut check_only = false;
    let mut backend = Backend::Interp;
    let mut emit = Emit::Text;
    let mut path: Option<String> = None;

    let mut i = 0;
    while i < args.len() {
        match args[i].as_str() {
            "--check" => check_only = true,
            "--release" => backend = Backend::Llvm,
            "--backend" => {
                i += 1;
                match args.get(i).map(|s| s.as_str()) {
                    Some("cranelift") => backend = Backend::Cranelift,
                    Some("llvm") => backend = Backend::Llvm,
                    Some("interp") => backend = Backend::Interp,
                    _ => {
                        eprintln!("--backend expects 'cranelift', 'llvm' or 'interp'");
                        return ExitCode::from(2);
                    }
                }
            }
            "--emit" => {
                i += 1;
                match args.get(i).map(|s| s.as_str()) {
                    Some("json") => emit = Emit::Json,
                    Some("drops") => emit = Emit::Drops,
                    Some("inplace") => emit = Emit::InPlace,
                    Some("arenas") => emit = Emit::Arenas,
                    Some("core") => emit = Emit::Core,
                    Some("clif") => emit = Emit::Clif,
                    Some("llvm") => emit = Emit::Llvm,
                    _ => {
                        eprintln!(
                            "--emit expects 'json', 'drops', 'inplace', 'arenas', 'core', 'clif' or 'llvm'"
                        );
                        return ExitCode::from(2);
                    }
                }
            }
            "--explain" => {
                i += 1;
                let code = args.get(i).cloned().unwrap_or_default();
                return explain(&code);
            }
            "-h" | "--help" => {
                print_usage();
                return ExitCode::SUCCESS;
            }
            other => {
                if other.starts_with('-') {
                    eprintln!("unknown option: {other}");
                    return ExitCode::from(2);
                }
                path = Some(other.to_string());
            }
        }
        i += 1;
    }

    let path = match path {
        Some(p) => p,
        None => {
            print_usage();
            return ExitCode::from(2);
        }
    };

    let src = match std::fs::read_to_string(&path) {
        Ok(s) => s,
        Err(e) => {
            eprintln!("could not read {path}: {e}");
            return ExitCode::from(2);
        }
    };

    let lines = LineMap::new(&src);
    let mut diags = Diagnostics::new();
    let (module, analysis) = compile_front(&src, &mut diags);

    // report diagnostics
    if emit == Emit::Json {
        println!("{}", serde_json::to_string_pretty(&diags.items).unwrap());
    } else {
        for d in &diags.items {
            print!("{}", d.render(&path, &src, &lines));
        }
    }

    if diags.has_errors() {
        return ExitCode::FAILURE;
    }

    if emit == Emit::Drops {
        print_drops(&analysis.drops, &path, &lines);
        return ExitCode::SUCCESS;
    }
    if emit == Emit::InPlace {
        print_inplace(&analysis.inplace, &path, &lines);
        return ExitCode::SUCCESS;
    }
    if emit == Emit::Arenas {
        print_arenas(&analysis.arenas, &path, &lines);
        return ExitCode::SUCCESS;
    }

    let module = match module {
        Some(m) => m,
        None => return ExitCode::FAILURE,
    };

    // spans of the `RecordUpd`s eligible for in-place mutation (Linear Elision, §2),
    // which the backends use to mutate the block instead of alloc+copy.
    let inplace: std::collections::HashSet<(usize, usize)> =
        analysis.inplace.iter().map(|ip| ip.span).collect();

    // --- Axion Core IR: dump da baixada ANF (partilhada pelos backends) ---
    if emit == Emit::Core {
        print!("{}", core::dump(&core::lower(&module, &inplace)));
        return ExitCode::SUCCESS;
    }

    // --- native --dev backend (Cranelift): IR dump or JIT+run main::Int ---
    if emit == Emit::Clif {
        match codegen::emit_ir(&module, &inplace) {
            Ok(ir) => {
                print!("{ir}");
                return ExitCode::SUCCESS;
            }
            Err(e) => {
                eprintln!("codegen: {e}");
                return ExitCode::FAILURE;
            }
        }
    }
    // --- backend --release (LLVM): dump do IR ou compilar+correr ---
    if emit == Emit::Llvm {
        match llvm::emit_ir(&module, &inplace) {
            Ok(ir) => {
                print!("{ir}");
                return ExitCode::SUCCESS;
            }
            Err(e) => {
                eprintln!("llvm: {e}");
                return ExitCode::FAILURE;
            }
        }
    }
    if backend == Backend::Cranelift {
        return match codegen::run(&module, "main", &inplace) {
            Ok(Some(n)) => {
                println!("{n}");
                ExitCode::SUCCESS
            }
            Ok(None) => ExitCode::SUCCESS, // main :: IO () — already printed
            Err(e) => {
                eprintln!("cranelift backend: {e}");
                ExitCode::FAILURE
            }
        };
    }
    if backend == Backend::Llvm {
        return match llvm::build_and_run(&module, "main", &inplace) {
            Ok(()) => ExitCode::SUCCESS, // the binary already printed the result
            Err(e) => {
                eprintln!("llvm backend (--release): {e}");
                ExitCode::FAILURE
            }
        };
    }

    if check_only {
        if emit == Emit::Text {
            eprintln!("ok: {path} compiles (parse + typecheck + linearity + Auto-Drop).");
        }
        return ExitCode::SUCCESS;
    }

    match interp::run(&module) {
        Ok(()) => ExitCode::SUCCESS,
        Err(e) => {
            eprintln!("runtime error: {e}");
            ExitCode::FAILURE
        }
    }
}

/// Runs the front-end (lex → layout → parse → check → infer), accumulating
/// diagnostics and returning the `free`s inserted by Auto-Drop.
fn compile_front(src: &str, diags: &mut Diagnostics) -> (Option<ast::Module>, check::Analysis) {
    let tokens = match lexer::lex(src) {
        Ok(t) => t,
        Err(e) => {
            diags.push(Diagnostic::error("AX0100", "unexpected character").label(
                e.start,
                e.end,
                "not part of any token",
            ));
            return (None, check::Analysis::default());
        }
    };
    let lines = LineMap::new(src);
    let ltokens = layout::layout(&tokens, &lines);
    let mut module = match parser::parse_module(&ltokens) {
        Ok(m) => m,
        Err(d) => {
            diags.push(d);
            return (None, check::Analysis::default());
        }
    };
    inject_prelude(&mut module);
    lower_classes(&mut module);
    let analysis = check::check(&module, diags);
    // Inference returns the monomorphic method resolutions (use span →
    // concrete instance implementation). We rewrite them as direct
    // calls (`eq 3 3` → `eq$Int 3 3`): monomorphization — the use
    // stops being a method (dynamic dispatch) and now compiles natively.
    let mono = infer::infer(&module, diags);
    resolve_methods(&mut module, &mono.resolutions);
    materialize_specs(&mut module, &mono.specs);
    (Some(module), analysis)
}

/// Materializes the specialized constrained functions: clones each
/// `src` (already rewritten by the direct resolutions), specializes the signature
/// (constraint var → concrete type), rewrites the internal uses (methods→`m$T`,
/// self-recursion→`f$T`), and appends to the module. So constrained polymorphism
/// compiles natively (Rust-style monomorphization).
fn materialize_specs(module: &mut ast::Module, specs: &[infer::SpecPlan]) {
    if specs.is_empty() {
        return;
    }
    let by_name: std::collections::HashMap<&str, ast::Func> = module
        .funcs
        .iter()
        .map(|f| (f.name.as_str(), f.clone()))
        .collect();
    let mut new_funcs = Vec::new();
    for plan in specs {
        let Some(src) = by_name.get(plan.src.as_str()) else {
            continue;
        };
        let mut clone = src.clone();
        clone.name = plan.name.clone();
        clone.constraints = Vec::new();
        // specialized signature: constraint var → concrete type
        if let Some(sig) = &clone.sig {
            let templ = subst_head(sig, &plan.tyvar);
            clone.sig = Some(specialize(&templ, &plan.ty_head));
        }
        // rewrites the internal uses (span → direct name) in the clone's body
        let mut res: Resolutions = std::collections::HashMap::new();
        for (span, name) in &plan.rewrites {
            res.insert((plan.name.clone(), *span), name.clone());
        }
        rewrite_func(&mut clone, &plan.name.clone(), &res);
        new_funcs.push(clone);
    }
    module.funcs.extend(new_funcs);
}

/// Rewrites the monomorphic method uses to direct calls to the instance
/// impl, per inference's `span → impl-name` map. Walks all
/// bodies (top-level functions, `where`, lambdas, `case` arms, `let`).
type Resolutions = std::collections::HashMap<(String, ast::Span), String>;

fn resolve_methods(module: &mut ast::Module, res: &Resolutions) {
    if res.is_empty() {
        return;
    }
    for f in &mut module.funcs {
        let fname = f.name.clone();
        rewrite_func(f, &fname, res);
    }
}

fn rewrite_func(f: &mut ast::Func, fname: &str, res: &Resolutions) {
    for c in &mut f.clauses {
        match &mut c.body {
            ast::Body::Plain(e) => rewrite_expr(e, fname, res),
            ast::Body::Guarded(arms) => {
                for (g, r) in arms {
                    rewrite_expr(g, fname, res);
                    rewrite_expr(r, fname, res);
                }
            }
        }
        // `where` functions are inferred with the PARENT's name as `cur_fn`
        // (they are part of its body), so they are rewritten with `fname`.
        for w in &mut c.wher {
            rewrite_func_body(w, fname, res);
        }
    }
}

/// Like `rewrite_func`, but keeps the key name (`fname`) — for `where`, whose
/// `cur_fn` in inference is the parent function's.
fn rewrite_func_body(f: &mut ast::Func, fname: &str, res: &Resolutions) {
    for c in &mut f.clauses {
        match &mut c.body {
            ast::Body::Plain(e) => rewrite_expr(e, fname, res),
            ast::Body::Guarded(arms) => {
                for (g, r) in arms {
                    rewrite_expr(g, fname, res);
                    rewrite_expr(r, fname, res);
                }
            }
        }
        for w in &mut c.wher {
            rewrite_func_body(w, fname, res);
        }
    }
}

fn rewrite_expr(e: &mut ast::Expr, fname: &str, res: &Resolutions) {
    use ast::Expr::*;
    if let Var(name, span) = e {
        if let Some(impl_name) = res.get(&(fname.to_string(), *span)) {
            *name = impl_name.clone();
        }
        return;
    }
    match e {
        Int(_, _) | Str(_, _) | Con(_, _) => {}
        App(a, b, _) | BinOp(_, a, b, _) => {
            rewrite_expr(a, fname, res);
            rewrite_expr(b, fname, res);
        }
        If(c, t, el, _) => {
            rewrite_expr(c, fname, res);
            rewrite_expr(t, fname, res);
            rewrite_expr(el, fname, res);
        }
        Let(binds, body, _) => {
            for b in binds {
                rewrite_func_body(b, fname, res);
            }
            rewrite_expr(body, fname, res);
        }
        Case(scrut, arms, _) => {
            rewrite_expr(scrut, fname, res);
            for (_, body) in arms {
                rewrite_expr(body, fname, res);
            }
        }
        Tuple(es, _) => es.iter_mut().for_each(|x| rewrite_expr(x, fname, res)),
        RecordCon(_, fs, _) => {
            for (_, x) in fs {
                rewrite_expr(x, fname, res);
            }
        }
        RecordUpd(base, fs, _) => {
            rewrite_expr(base, fname, res);
            for (_, x) in fs {
                rewrite_expr(x, fname, res);
            }
        }
        Lam(_, body, _) => rewrite_expr(body, fname, res),
        Var(_, _) => unreachable!(),
    }
}

/// Built-in L0 prelude: the `List` type and the basic list functions. It is
/// prepended to every module (only the names the user doesn't redefine), so that
/// `[1..100]`/`:`/`.` (which desugar to `range`/`Cons`/`compose`) and `map`
/// they work without import. `mapM_` is a prelude function too.
const PRELUDE: &str = "\
data List a = Nil | Cons a (List a)
compose :: (b -> c) -> (a -> b) -> a -> c
compose f g x = f (g x)
range :: Int -> Int -> List Int
range lo hi = if lo > hi then Nil else Cons lo (range (lo + 1) hi)
map :: (a -> b) -> List a -> List b
map f xs = case xs of
  Nil -> Nil
  Cons y ys -> Cons (f y) (map f ys)
length :: List a -> Int
length xs = case xs of
  Nil -> 0
  Cons y ys -> 1 + length ys
append :: List a -> List a -> List a
append xs ys = case xs of
  Nil -> ys
  Cons z zs -> Cons z (append zs ys)
reverse :: List a -> List a
reverse xs = case xs of
  Nil -> Nil
  Cons y ys -> append (reverse ys) (Cons y Nil)
filter :: (a -> Bool) -> List a -> List a
filter p xs = case xs of
  Nil -> Nil
  Cons y ys -> if p y then Cons y (filter p ys) else filter p ys
foldr :: (a -> b -> b) -> b -> List a -> b
foldr f z xs = case xs of
  Nil -> z
  Cons y ys -> f y (foldr f z ys)
foldl :: (b -> a -> b) -> b -> List a -> b
foldl f z xs = case xs of
  Nil -> z
  Cons y ys -> foldl f (f z y) ys
take :: Int -> List a -> List a
take n xs = case xs of
  Nil -> Nil
  Cons y ys -> if n < 1 then Nil else Cons y (take (n - 1) ys)
drop :: Int -> List a -> List a
drop n xs = case xs of
  Nil -> Nil
  Cons y ys -> if n < 1 then Cons y ys else drop (n - 1) ys
null :: List a -> Bool
null xs = case xs of
  Nil -> True
  Cons y ys -> False
sum :: List Int -> Int
sum xs = case xs of
  Nil -> 0
  Cons y ys -> y + sum ys
elem :: Int -> List Int -> Bool
elem x xs = case xs of
  Nil -> False
  Cons y ys -> if x == y then True else elem x ys
concat :: List (List a) -> List a
concat xs = case xs of
  Nil -> Nil
  Cons y ys -> append y (concat ys)
zipWith :: (a -> b -> c) -> List a -> List b -> List c
zipWith f xs ys = case xs of
  Nil -> Nil
  Cons a as -> case ys of
    Nil -> Nil
    Cons b bs -> Cons (f a b) (zipWith f as bs)
zip :: List a -> List b -> List (a, b)
zip xs ys = zipWith (\\a b -> (a, b)) xs ys
unlines :: List String -> String
unlines xs = case xs of
  Nil -> \"\"
  Cons s ss -> s ++ \"\\n\" ++ unlines ss
unwords :: List String -> String
unwords xs = case xs of
  Nil -> \"\"
  Cons s ss -> case ss of
    Nil -> s
    Cons t ts -> s ++ \" \" ++ unwords ss
class Eq a where
  eq :: a -> a -> Bool
class Ord a where
  le :: a -> a -> Bool
instance Eq Int where
  eq x y = x == y
instance Ord Int where
  le x y = if x < y then True else x == y
instance Eq Bool where
  eq x y = if x then y else if y then False else True
maxOr :: Ord a => a -> List a -> a
maxOr d xs = case xs of
  Nil -> d
  Cons y ys -> if le d y then maxOr y ys else maxOr d ys
minOr :: Ord a => a -> List a -> a
minOr d xs = case xs of
  Nil -> d
  Cons y ys -> if le y d then minOr y ys else minOr d ys
nub :: Eq a => List a -> List a
nub xs = case xs of
  Nil -> Nil
  Cons y ys -> Cons y (nub (filter (\\z -> if eq y z then False else True) ys))
mapM_ :: (a -> IO ()) -> List a -> IO ()
mapM_ f xs = case xs of
  Nil -> putStr \"\"
  Cons y ys -> case f y of
    _ -> mapM_ f ys
";

/// Lowers the typeclass instances: each method of each `instance`
/// becomes a top-level function with a mangled name (`eq$Int`), which the
/// interpreter's dynamic dispatch calls by the 1st argument's type head. The
/// `ClassDecl`s stay in the module (they give the overloaded method names to check,
/// infer e interp).
fn lower_classes(module: &mut ast::Module) {
    // (class, method) → template signature (class var marked) to specialize
    let mut sigs: std::collections::HashMap<(String, String), ast::Type> =
        std::collections::HashMap::new();
    for c in &module.classes {
        for (m, ty) in &c.methods {
            sigs.insert((c.name.clone(), m.clone()), subst_head(ty, &c.tyvar));
        }
    }
    let mut impls = Vec::new();
    for inst in &module.instances {
        for m in &inst.methods {
            let mut impl_fn = m.clone();
            impl_fn.name = ast::method_impl_name(&m.name, &inst.ty_head);
            // specialized signature: the class's, with the var replaced by the
            // instance type (`eq :: a->a->Bool` @ Shape → `Shape->Shape->Bool`).
            // Without this, the instance body (unsigned) would look polymorphic
            // and its method uses would fire false "no constraint" errors.
            if let Some(tmpl) = sigs.get(&(inst.class_name.clone(), m.name.clone())) {
                impl_fn.sig = Some(specialize(tmpl, &inst.ty_head));
            }
            impls.push(impl_fn);
        }
    }
    module.funcs.extend(impls);
}

/// Marks the class variable in a type, replacing it with a unique sentinel
/// (`$cls`) so that `specialize` later swaps it for the instance's concrete type.
fn subst_head(ty: &ast::Type, tyvar: &str) -> ast::Type {
    match ty {
        ast::Type::Var(v) if v == tyvar => ast::Type::Var("$cls".to_string()),
        ast::Type::Var(_) | ast::Type::Con(_) | ast::Type::Unit => ty.clone(),
        ast::Type::App(f, a) => ast::Type::App(
            Box::new(subst_head(f, tyvar)),
            Box::new(subst_head(a, tyvar)),
        ),
        ast::Type::Arrow { mult, from, to } => ast::Type::Arrow {
            mult: *mult,
            from: Box::new(subst_head(from, tyvar)),
            to: Box::new(subst_head(to, tyvar)),
        },
        ast::Type::Tuple(ts) => ast::Type::Tuple(ts.iter().map(|t| subst_head(t, tyvar)).collect()),
    }
}

/// Swaps the `$cls` sentinel for the instance's concrete type head.
fn specialize(ty: &ast::Type, ty_head: &str) -> ast::Type {
    match ty {
        ast::Type::Var(v) if v == "$cls" => ast::Type::Con(ty_head.to_string()),
        ast::Type::Var(_) | ast::Type::Con(_) | ast::Type::Unit => ty.clone(),
        ast::Type::App(f, a) => ast::Type::App(
            Box::new(specialize(f, ty_head)),
            Box::new(specialize(a, ty_head)),
        ),
        ast::Type::Arrow { mult, from, to } => ast::Type::Arrow {
            mult: *mult,
            from: Box::new(specialize(from, ty_head)),
            to: Box::new(specialize(to, ty_head)),
        },
        ast::Type::Tuple(ts) => {
            ast::Type::Tuple(ts.iter().map(|t| specialize(t, ty_head)).collect())
        }
    }
}

fn inject_prelude(module: &mut ast::Module) {
    let lines = LineMap::new(PRELUDE);
    let tokens = lexer::lex(PRELUDE).expect("prelude: lex");
    let lt = layout::layout(&tokens, &lines);
    let prelude = parser::parse_module(&lt).expect("prelude: parse");
    let has_data: std::collections::HashSet<String> =
        module.datas.iter().map(|d| d.name.clone()).collect();
    let has_func: std::collections::HashSet<String> =
        module.funcs.iter().map(|f| f.name.clone()).collect();
    // prepend only what the user doesn't redefine (no clashes)
    for d in prelude.datas.into_iter().rev() {
        if !has_data.contains(&d.name) {
            module.datas.insert(0, d);
        }
    }
    for f in prelude.funcs.into_iter().rev() {
        if !has_func.contains(&f.name) {
            module.funcs.insert(0, f);
        }
    }
    // prelude classes and instances: inject only those the user doesn't
    // redefine — a class by name, an instance by the (class, type) pair —
    // so redeclaring `class Eq` or `instance Eq Int` replaces the prelude's
    // without clashing (duplicate method/impl names).
    let has_class: std::collections::HashSet<String> =
        module.classes.iter().map(|c| c.name.clone()).collect();
    let has_inst: std::collections::HashSet<(String, String)> = module
        .instances
        .iter()
        .map(|i| (i.class_name.clone(), i.ty_head.clone()))
        .collect();
    for c in prelude.classes.into_iter().rev() {
        if !has_class.contains(&c.name) {
            module.classes.insert(0, c);
        }
    }
    for i in prelude.instances.into_iter().rev() {
        if !has_inst.contains(&(i.class_name.clone(), i.ty_head.clone())) {
            module.instances.insert(0, i);
        }
    }
}

/// Prints the Auto-Drop report (`--emit drops`).
fn print_drops(drops: &[check::DropPoint], path: &str, lines: &LineMap) {
    if drops.is_empty() {
        println!("Auto-Drop: no 'free' inserted.");
        return;
    }
    println!("Auto-Drop — {} 'free'(s) inserted:", drops.len());
    for d in drops {
        let (l, c) = lines.pos(d.span.0);
        println!(
            "  free({}) : {} %1  @ {path}:{l}:{c}  (in '{}', {})",
            d.var, d.ty, d.func, d.reason
        );
    }
}

/// Prints the record updates eligible for in-place mutation (`--emit inplace`).
fn print_inplace(sites: &[check::InPlace], path: &str, lines: &LineMap) {
    if sites.is_empty() {
        println!("Linear Elision: no in-place update.");
        return;
    }
    println!("Linear Elision — {} in-place update(s):", sites.len());
    for s in sites {
        let (l, c) = lines.pos(s.span.0);
        println!(
            "  '{}' mutated in-place  @ {path}:{l}:{c}  (in '{}': last live mention)",
            s.var, s.func
        );
    }
}

/// Prints the NLL reset points of sub-arenas (`--emit arenas`).
fn print_arenas(resets: &[check::ArenaReset], path: &str, lines: &LineMap) {
    if resets.is_empty() {
        println!("NLL reset: no sub-arena.");
        return;
    }
    println!("NLL reset — {} sub-arena(s):", resets.len());
    for r in resets {
        let (l, c) = lines.pos(r.span.0);
        println!(
            "  reset '{}' @ {path}:{l}:{c}  (in '{}': after the last mention of '{}')",
            r.sub, r.func, r.last_var
        );
    }
}

fn explain(code: &str) -> ExitCode {
    let text = match code.to_uppercase().as_str() {
        "AX0001" => {
            "AX0001 — contraction of a linear resource (consumed more than once).\n\
             READING (borrowing) a %1 is free and unlimited — Borrow Elision.\n\
             CONSUMING (moving ownership: a %1 argument, %1 field, or return) may\n\
             only happen once. To share it by ownership, use 'split' into two\n\
             %0.5 halves (§2)."
        }
        "AX0002" => {
            "AX0002 — must-use resource dropped without being consumed.\n\
             Types WITHOUT Drop (Ep, Token, handles) are must-use: they must be\n\
             consumed or returned. Droppable types, by contrast, are managed by\n\
             Auto-Drop (the compiler inserts 'free' at the death point). Only\n\
             forgetting a must-use is an error (§2)."
        }
        "AX0100" => {
            "AX0100 — syntax error. The parser could not recognize the\n\
             construct. Check parentheses, '=' and indentation."
        }
        "AX0003" => {
            "AX0003 — sub-arena escape. A value allocated in a sub-arena\n\
             (allocateCell sub) cannot be returned from withSubArena — on reset\n\
             the sub-arena's RAM is reclaimed and the value would dangle. Move it\n\
             to the parent arena before the reset with 'promote parent value' (§3)."
        }
        "AX0004" => {
            "AX0004 — use-after-move. Once you move ownership of a %1 (consume:\n\
             a %1 argument, %1 field, or return), you cannot read or consume it\n\
             again. Reading BEFORE consuming is free; reading AFTER is an error (§2)."
        }
        "AX0005" => {
            "AX0005 — use-after-release of an arena mark. 'arena_release mark'\n\
             reclaims everything allocated after 'arena_mark'; using one of those\n\
             values after the release is an error (the memory is already reclaimed).\n\
             Consume it before the release, or don't allocate it under the mark\n\
             (§3, Listing 3.6)."
        }
        "AX0006" => {
            "AX0006 — write through a %0.5 half. 'split' divides a %1 into two\n\
             shared-read %0.5 halves; a half can only be read, never written. To\n\
             recover write access, recombine the two halves with 'join a b' (which\n\
             returns the %1) (§2, Listing 2.3)."
        }
        "AX0101" => {
            "AX0101 — name not found. The identifier is not in scope\n\
             (not a parameter, local, top-level function, nor a builtin)."
        }
        "AX0200" => {
            "AX0200 — type mismatch. Unification (HM inference, Algorithm W)\n\
             failed: two types that would have to be equal are not. Check the\n\
             signatures and the arguments of applications (§16)."
        }
        "AX0201" => {
            "AX0201 — infinite type (occurs-check). Unification would require a\n\
             recursive type (a variable occurring inside the type it would be bound\n\
             to), which HM inference rejects."
        }
        "AX0300" => {
            "AX0300 — channel operation does not follow the session type. 'send'\n\
             requires an endpoint at 'Send', 'recv' at 'Recv', 'close' at 'End', and\n\
             the label of 'select' must belong to the 'Select'. Protocol fidelity is\n\
             checked statically (§6)."
        }
        "AX0301" => {
            "AX0301 — incomplete session protocol. An endpoint must be carried all\n\
             the way to 'close' (or consumed by 'offer'/'cancel'); dropping it\n\
             midway leaves the protocol unfinished (§6)."
        }
        "AX0302" => {
            "AX0302 — endpoint escape from the 'bound' nursery. Endpoints are born\n\
             confined to the 'bound' so the communication graph is a tree\n\
             (deadlock-freedom, §9); they cannot be returned from the block. Consume\n\
             them inside (close/send/recv). It is the analog of arena escape (AX0003)."
        }
        "AX0303" => {
            "AX0303 — external choice ('Offer') without the 'Closed' branch. Every\n\
             '&' must offer 'Closed' — the label that Linear Unwinding sends when\n\
             cancelling (§7); without it, cancellation of a panicking peer would go\n\
             unhandled."
        }
        "AX0304" => {
            "AX0304 — non-exhaustive 'case offer c'. A 'case' over an external choice\n\
             must handle ALL branches the 'Offer' provides (including 'Closed').\n\
             Add an arm for each label (§6/§7)."
        }
        "AX0305" => {
            "AX0305 — the 'spawn' closure captures an endpoint from outside. A\n\
             spawned child communicates with the parent only through its endpoint\n\
             parameter (parent↔child edge); capturing outside channels could form a\n\
             cycle → deadlock. The topology must be a tree (§9)."
        }
        "AX0400" => {
            "AX0400 — instance of an unknown class. 'instance C T' requires class\n\
             'C' to have been declared with 'class C a where …'. Check the spelling\n\
             of the class name."
        }
        "AX0401" => {
            "AX0401 — incomplete instance: a class method is not implemented.\n\
             An 'instance C T' must implement ALL methods declared in 'class C'\n\
             (there are no default methods yet)."
        }
        "AX0402" => {
            "AX0402 — the instance implements a method the class does not declare.\n\
             Only the methods of 'class C' may appear in an 'instance C T'. Check\n\
             the name, or add the method signature to the class."
        }
        "AX0403" => {
            "AX0403 — duplicate instance (incoherence). There can be only ONE\n\
             'instance C T' for each (class, type) pair, otherwise method resolution\n\
             would be ambiguous. Remove the repeated instance."
        }
        "AX0404" => {
            "AX0404 — method over a concrete type without an instance. A class\n\
             method used over a type T requires 'instance C T'. Declare the missing\n\
             instance, or use a type that already has one (use-site constraint\n\
             checking)."
        }
        "AX0405" => {
            "AX0405 — method used over a polymorphic type without a constraint. If a\n\
             function applies a class-C method to a value of generic type 'a', its\n\
             signature must declare 'C a =>' (otherwise there is no guarantee an\n\
             instance exists at the call site)."
        }
        other => {
            eprintln!("unknown code: {other}");
            return ExitCode::from(2);
        }
    };
    println!("{text}");
    ExitCode::SUCCESS
}

fn print_usage() {
    eprintln!(
        "axionc — the Axion compiler\n\n\
         usage:\n  \
         axionc <file.axi>              compile and run\n  \
         axionc --check <file>          compile only (parse + typecheck + Auto-Drop)\n  \
         axionc --emit json <file>      diagnostics as JSON\n  \
         axionc --emit drops <file>     'free's inserted by Auto-Drop\n  \
         axionc --emit inplace <file>   in-place updates (Linear Elision)\n  \
         axionc --emit arenas <file>    NLL reset points of sub-arenas (static)\n  \
         axionc --emit core <file>      Axion Core IR (ANF) — the shared lowering\n  \
         axionc --emit clif <file>      Cranelift IR of the Int core (--dev backend)\n  \
         axionc --emit llvm <file>      LLVM IR of the Int core (--release backend)\n  \
         axionc --backend cranelift <f> JIT-compile and run main :: Int (--dev)\n  \
         axionc --release <file>        compile with clang -O2 and run (--release)\n  \
         axionc --explain AX0001        explain an error code"
    );
}
