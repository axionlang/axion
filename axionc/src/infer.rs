//! Inferência de tipos — Hindley-Milner (Algoritmo W) para o subconjunto L0/L1.
//!
//! Corre a par da análise de linearidade (`check.rs`): a linearidade cuida do
//! *quantas vezes* um recurso é usado (multiplicidades); a inferência cuida do
//! *que tipo* tem. Emite `AX0200` (incompatibilidade de tipos) e `AX0201`
//! (tipo infinito / occurs-check).
//!
//! Suporta: literais, funções (multi-cláusula, pattern matching), aplicação,
//! `let`/`where` com generalização, `if`, `case`, registos (construção,
//! actualização, selectores) e os builtins. As multiplicidades das setas são
//! ignoradas aqui (são o trabalho do `check.rs`).

use crate::ast::*;
use crate::diag::{Diagnostic, Diagnostics};
use std::collections::{HashMap, HashSet};

#[derive(Clone, Debug)]
enum Ty {
    Var(u32),
    Con(String, Vec<Ty>),
    Fun(Box<Ty>, Box<Ty>),
    Tuple(Vec<Ty>),
}

#[derive(Clone)]
struct Scheme {
    vars: Vec<u32>,
    ty: Ty,
}

type Env = HashMap<String, Scheme>;

struct Infer<'a> {
    subst: HashMap<u32, Ty>,
    counter: u32,
    diags: &'a mut Diagnostics,
    /// construtor → (tipo do registo, campos com tipo)
    cons: HashMap<String, (String, Vec<(String, Ty)>)>,
    /// tipo do registo → campos com tipo (para actualização)
    records: HashMap<String, Vec<(String, Ty)>>,
    /// método de typeclasse → (classe, índice do parâmetro de despacho). O índice
    /// é a posição do 1º parâmetro cujo tipo é a variável da classe (fatia 2b).
    method_meta: HashMap<String, (String, Option<usize>)>,
    /// obrigações de instância recolhidas nos usos de método, descarregadas no fim.
    obligations: Vec<Obl>,
    /// usos de funções constrangidas, para a monomorfização (fatia 2b-β).
    spec_obligations: Vec<SpecObl>,
    /// função constrangida → (var de constraint, índice do param de despacho).
    constrained_meta: HashMap<String, (String, Option<usize>)>,
    /// funções que referenciam uma função constrangida não-especializável (var de
    /// constraint sem parâmetro directo) — não podem ser especializadas (β-2).
    refs_unspec: HashSet<String>,
    /// classes com constraint declarado no âmbito da função a ser inferida.
    cur_constraints: Vec<String>,
    /// nome da função a ser inferida (chave das resoluções, com o span).
    cur_fn: String,
}

/// Uma obrigação `classe C sobre o tipo T`, recolhida num uso de método e
/// descarregada no fim (com a substituição resolvida): T concreto → tem de haver
/// instância; T variável → tem de estar coberto por um constraint no âmbito.
struct Obl {
    class: String,
    method: String,
    ty: Ty,
    span: Span,
    scope: Vec<String>,
    /// função onde o uso ocorre — parte da chave da resolução, porque os spans
    /// (offsets de byte) do prelúdio e do ficheiro do utilizador colidem.
    func: String,
}

/// Um uso de uma FUNÇÃO CONSTRANGIDA (`f :: C a => …`) — recolhido para a
/// monomorfização (fatia 2b-β): se a var de constraint resolve para um tipo
/// concreto no call-site, especializa-se `f` a esse tipo.
struct SpecObl {
    target: String, // a função constrangida chamada
    ty: Ty,         // o tipo da var de constraint neste uso
    span: Span,
    func: String, // função onde o uso ocorre (chamador)
}

/// O resultado da inferência para a monomorfização: as reescritas directas
/// (`(função, span) → nome`) e o plano de funções especializadas a materializar.
pub struct Mono {
    pub resolutions: HashMap<(String, Span), String>,
    pub specs: Vec<SpecPlan>,
}

/// Instrução para clonar `src` numa função monomórfica `name`, substituindo a var
/// de constraint `tyvar` pelo tipo `ty_head` na assinatura, e reescrevendo os usos
/// internos (span → nome directo: métodos→`m$T`, auto-recursão→`name`).
pub struct SpecPlan {
    pub src: String,
    pub name: String,
    pub tyvar: String,
    pub ty_head: String,
    pub rewrites: HashMap<Span, String>,
}

/// Ponto de entrada: infere e verifica os tipos do módulo. Devolve as resoluções
/// de método monomórficas (`(função, span do uso) → nome da impl`), para a
/// monomorfização reescrever os usos como chamadas directas (fatia 2b-ii). A
/// chave inclui a função porque os spans do prelúdio e do utilizador colidem.
pub fn infer(module: &Module, diags: &mut Diagnostics) -> Mono {
    let mut inf = Infer {
        subst: HashMap::new(),
        counter: 0,
        diags,
        cons: HashMap::new(),
        records: HashMap::new(),
        method_meta: HashMap::new(),
        obligations: Vec::new(),
        spec_obligations: Vec::new(),
        constrained_meta: HashMap::new(),
        refs_unspec: HashSet::new(),
        cur_constraints: Vec::new(),
        cur_fn: String::new(),
    };
    let mut env: Env = inf.base_env();

    // tipos dos construtores e selectores a partir das declarações `data`. Um
    // mapa de vars PARTILHADO por decl liga os parâmetros de tipo (`a` em
    // `data List a`) ao mesmo `Ty::Var` no resultado (`List a`) e nos campos,
    // e o esquema generaliza-os (`Cons :: forall a. a -> List a -> List a`).
    for d in &module.datas {
        let mut vars: HashMap<String, u32> = HashMap::new();
        let mut next = 2_000_000u32; // banda dos parâmetros de tipo
        let param_args: Vec<Ty> = d
            .params
            .iter()
            .map(|p| ast_ty(&Type::Var(p.clone()), &mut vars, &mut next))
            .collect();
        let result = Ty::Con(d.name.clone(), param_args);
        for c in &d.cons {
            let fields: Vec<(String, Ty)> = c
                .fields
                .iter()
                .enumerate()
                .map(|(i, f)| {
                    let name = if f.name.is_empty() {
                        format!("_{i}")
                    } else {
                        f.name.clone()
                    };
                    (name, ast_ty(&f.ty, &mut vars, &mut next))
                })
                .collect();

            // construtor: campo1 -> ... -> T params, quantificado sobre as vars
            let mut cty = result.clone();
            for (_, ft) in fields.iter().rev() {
                cty = Ty::Fun(Box::new(ft.clone()), Box::new(cty));
            }
            let mut gvars = Vec::new();
            free_ty_vars(&cty, &mut gvars);
            env.insert(
                c.name.clone(),
                Scheme {
                    vars: gvars,
                    ty: cty,
                },
            );

            // selectores: T params -> tipoDoCampo (quantificado)
            for (fname, ft) in &fields {
                if !fname.starts_with('_') {
                    let sty = Ty::Fun(Box::new(result.clone()), Box::new(ft.clone()));
                    let mut svars = Vec::new();
                    free_ty_vars(&sty, &mut svars);
                    env.insert(
                        fname.clone(),
                        Scheme {
                            vars: svars,
                            ty: sty,
                        },
                    );
                }
            }
            inf.cons
                .insert(c.name.clone(), (d.name.clone(), fields.clone()));
            inf.records.insert(d.name.clone(), fields);
        }
    }

    // métodos de typeclasse: cada método é uma função polimórfica cujo esquema é
    // a sua assinatura generalizada sobre a variável da classe (`eq :: forall a.
    // a -> a -> Bool`). O despacho para a instância concreta é dinâmico (interp);
    // aqui o método tipa-se como qualquer função polimórfica (fatia 1: os
    // constraints `Eq a =>` são parseados e ignorados).
    for class in &module.classes {
        for (m, ty) in &class.methods {
            let scheme = inf.scheme_of_sig(ty);
            env.insert(m.clone(), scheme);
            // índice do parâmetro de despacho = 1º cujo tipo é a var da classe
            let idx = ty
                .param_types()
                .iter()
                .position(|p| matches!(p, Type::Var(v) if *v == class.tyvar));
            inf.method_meta.insert(m.clone(), (class.name.clone(), idx));
        }
    }

    // esquemas das funções de topo: a partir da assinatura, ou monótipo fresco
    let mut placeholders: HashMap<String, Ty> = HashMap::new();
    // importações FFI (§18): tipadas pela sua assinatura declarada
    for fo in &module.foreigns {
        let scheme = inf.scheme_of_sig(&fo.sig);
        env.insert(fo.name.clone(), scheme);
    }
    for f in &module.funcs {
        match &f.sig {
            Some(sig) => {
                let scheme = inf.scheme_of_sig(sig);
                env.insert(f.name.clone(), scheme);
            }
            None => {
                let v = inf.fresh();
                placeholders.insert(f.name.clone(), v.clone());
                env.insert(
                    f.name.clone(),
                    Scheme {
                        vars: vec![],
                        ty: v,
                    },
                );
            }
        }
    }

    // metadados das funções constrangidas (fatia 2b-β): var de constraint e
    // índice do 1º parâmetro cujo tipo é essa var (o «despacho» da especialização).
    for f in &module.funcs {
        if let Some((_, cvar)) = f.constraints.first() {
            let idx = f.sig.as_ref().and_then(|s| {
                s.param_types()
                    .iter()
                    .position(|p| matches!(p, Type::Var(v) if v == cvar))
            });
            inf.constrained_meta
                .insert(f.name.clone(), (cvar.clone(), idx));
        }
    }

    // verifica cada função contra o seu tipo (em modo de checking quando há
    // assinatura: os parâmetros herdam os tipos declarados antes do corpo)
    for f in &module.funcs {
        let declared = env.get(&f.name).cloned().map(|s| inf.instantiate(&s));
        // Modo de checking (parâmetros herdam os tipos declarados) SÓ quando há
        // assinatura. Sem assinatura, o `declared` é um placeholder `Var` que o
        // `peel_fun` não sabe partir em setas — inferir livremente e unificar o
        // resultado com o placeholder (isto liga a recursão monomórfica e é o que
        // os métodos de instância, sem assinatura, precisam).
        let expected = if f.sig.is_some() {
            declared.as_ref()
        } else {
            None
        };
        // constraints no âmbito desta função (para descarregar usos polimórficos)
        inf.cur_constraints = f.constraints.iter().map(|(c, _)| c.clone()).collect();
        inf.cur_fn = f.name.clone();
        let inferred = inf.infer_func(&env, f, expected);
        if let Some(d) = &declared {
            inf.unify(&inferred, d, f.span);
        }
    }
    let mono = inf.discharge_obligations(module);
    let _ = placeholders;
    mono
}

/// O `idx`-ésimo tipo de parâmetro de uma cadeia de setas (`a -> b -> c` @ 1 → b).
fn nth_param(ty: &Ty, idx: usize) -> Option<Ty> {
    let mut cur = ty;
    for _ in 0..idx {
        match cur {
            Ty::Fun(_, b) => cur = b,
            _ => return None,
        }
    }
    match cur {
        Ty::Fun(a, _) => Some((**a).clone()),
        _ => None,
    }
}

/// Os inteiros de largura fixa (§4) colapsam para `Int` neste sistema de tipos
/// simplificado (a aritmética é toda `Int`); ex.: `U8`, `U32` → `Int`.
fn normalize_num(n: &str) -> String {
    match n {
        "U8" | "U16" | "U32" | "U64" | "I8" | "I16" | "I32" | "I64" | "Word" | "Byte" => {
            "Int".to_string()
        }
        _ => n.to_string(),
    }
}

/// Converte um `Type` do AST em `Ty`, mapeando variáveis por nome via `vars`
/// (partilhado, para que o mesmo nome — p.ex. o `a` de `data List a` — dê o mesmo
/// `Ty::Var` no resultado e nos campos). Vars novas apanham ids a partir de `next`.
fn ast_ty(t: &Type, vars: &mut HashMap<String, u32>, next: &mut u32) -> Ty {
    match t {
        Type::Con(n) => Ty::Con(normalize_num(n), Vec::new()),
        Type::Var(n) => {
            let id = *vars.entry(n.clone()).or_insert_with(|| {
                let v = *next;
                *next += 1;
                v
            });
            Ty::Var(id)
        }
        Type::App(_, _) => {
            let (head, args) = flatten_app(t);
            Ty::Con(
                normalize_num(&head),
                args.iter().map(|a| ast_ty(a, vars, next)).collect(),
            )
        }
        Type::Arrow { from, to, .. } => Ty::Fun(
            Box::new(ast_ty(from, vars, next)),
            Box::new(ast_ty(to, vars, next)),
        ),
        Type::Tuple(ts) => Ty::Tuple(ts.iter().map(|a| ast_ty(a, vars, next)).collect()),
        Type::Unit => Ty::Con("()".to_string(), Vec::new()),
    }
}

fn ty_of_ast(t: &Type) -> Ty {
    // espaço de nomes local; as variáveis são quantificadas por `scheme_of_sig`
    let mut vars = HashMap::new();
    let mut next = 1_000_000; // banda separada
    ast_ty(t, &mut vars, &mut next)
}

/// Recolhe os ids das variáveis de tipo que ocorrem em `ty` (para generalizar).
fn free_ty_vars(ty: &Ty, out: &mut Vec<u32>) {
    match ty {
        Ty::Var(v) => {
            if !out.contains(v) {
                out.push(*v);
            }
        }
        Ty::Con(_, args) => args.iter().for_each(|a| free_ty_vars(a, out)),
        Ty::Fun(a, b) => {
            free_ty_vars(a, out);
            free_ty_vars(b, out);
        }
        Ty::Tuple(ts) => ts.iter().for_each(|t| free_ty_vars(t, out)),
    }
}

fn flatten_app(t: &Type) -> (String, Vec<Type>) {
    match t {
        Type::App(f, a) => {
            let (head, mut args) = flatten_app(f);
            args.push((**a).clone());
            (head, args)
        }
        Type::Con(n) => (n.clone(), Vec::new()),
        _ => ("?".to_string(), Vec::new()),
    }
}

impl<'a> Infer<'a> {
    fn fresh(&mut self) -> Ty {
        let v = self.counter;
        self.counter += 1;
        Ty::Var(v)
    }

    fn base_env(&mut self) -> Env {
        let io_unit = Ty::Con("IO".into(), vec![Ty::Con("()".into(), vec![])]);
        let int = || Ty::Con("Int".into(), vec![]);
        let string = || Ty::Con("String".into(), vec![]);
        let bool = || Ty::Con("Bool".into(), vec![]);
        let bin = |t: Ty| {
            Ty::Fun(
                Box::new(t.clone()),
                Box::new(Ty::Fun(Box::new(t.clone()), Box::new(t))),
            )
        };
        let mut env = Env::new();
        // putStrLn / putStr :: String -> IO ()
        env.insert(
            "putStrLn".into(),
            mono(Ty::Fun(Box::new(string()), Box::new(io_unit.clone()))),
        );
        env.insert(
            "putStr".into(),
            mono(Ty::Fun(Box::new(string()), Box::new(io_unit))),
        );
        // show :: forall a. a -> String
        env.insert(
            "show".into(),
            Scheme {
                vars: vec![0],
                ty: Ty::Fun(Box::new(Ty::Var(0)), Box::new(string())),
            },
        );
        env.insert("True".into(), mono(bool()));
        env.insert("False".into(), mono(bool()));
        env.insert("otherwise".into(), mono(bool()));
        // aritmética e comparações (monomórficas em Int no subconjunto)
        for op in ["+", "-", "*", "mod"] {
            env.insert(op.into(), mono(bin(int())));
        }
        // ++ :: forall a. a -> a -> a  (concatenação polimórfica; sem typeclasses
        // ainda, o tipo Semigroup-óide só impõe que os dois lados coincidam —
        // listas e strings ambos passam, `"x" ++ [1]` não).
        env.insert(
            "++".into(),
            Scheme {
                vars: vec![0],
                ty: bin(Ty::Var(0)),
            },
        );
        for op in ["==", "<", ">"] {
            env.insert(
                op.into(),
                mono(Ty::Fun(
                    Box::new(int()),
                    Box::new(Ty::Fun(Box::new(int()), Box::new(bool()))),
                )),
            );
        }
        // arenas (§3). O arg da arena é emprestado (não %1): allocateCell e
        // promote lêem a arena para bump-allocate, muitas vezes.
        let arena = || Ty::Con("Arena".into(), vec![]);
        let cell = || Ty::Con("Cell".into(), vec![]);
        // allocateCell :: Arena -> Cell
        env.insert(
            "allocateCell".into(),
            mono(Ty::Fun(Box::new(arena()), Box::new(cell()))),
        );
        // promote :: Arena -> Cell -> Cell
        env.insert(
            "promote".into(),
            mono(Ty::Fun(
                Box::new(arena()),
                Box::new(Ty::Fun(Box::new(cell()), Box::new(cell()))),
            )),
        );
        // withSubArena :: forall a. Arena -> (Arena -> a) -> a
        env.insert(
            "withSubArena".into(),
            Scheme {
                vars: vec![0],
                ty: Ty::Fun(
                    Box::new(arena()),
                    Box::new(Ty::Fun(
                        Box::new(Ty::Fun(Box::new(arena()), Box::new(Ty::Var(0)))),
                        Box::new(Ty::Var(0)),
                    )),
                ),
            },
        );
        // canais / session types (§6). O HM não exprime o avanço de sessão — a
        // fidelidade de protocolo é verificada no passe `check_sessions`; aqui os
        // tipos são permissivos (o endpoint é `Ep S`, a sessão avança de `a`→`c`).
        let ep = |v: u32| Ty::Con("Ep".into(), vec![Ty::Var(v)]);
        // send :: forall a b c. Ep a -> b -> Ep c
        env.insert(
            "send".into(),
            Scheme {
                vars: vec![0, 1, 2],
                ty: Ty::Fun(
                    Box::new(ep(0)),
                    Box::new(Ty::Fun(Box::new(Ty::Var(1)), Box::new(ep(2)))),
                ),
            },
        );
        // recv :: forall a b c. Ep a -> (b, Ep c)
        env.insert(
            "recv".into(),
            Scheme {
                vars: vec![0, 1, 2],
                ty: Ty::Fun(
                    Box::new(ep(0)),
                    Box::new(Ty::Tuple(vec![Ty::Var(1), ep(2)])),
                ),
            },
        );
        // close :: forall a. Ep a -> IO ()  (o fecho é um efeito → casa com `do`)
        env.insert(
            "close".into(),
            Scheme {
                vars: vec![0],
                ty: Ty::Fun(
                    Box::new(ep(0)),
                    Box::new(Ty::Con("IO".into(), vec![Ty::Con("()".into(), vec![])])),
                ),
            },
        );
        // nursery de concorrência estruturada (§9). `bound` abre um nursery cujo
        // corpo é confinado (os endpoints não escapam — `check_bound_escapes`);
        // `newChannel` cria um par de endpoints duais; `spawn` lança um filho que
        // consome um endpoint e devolve ao pai o dual. Tipos permissivos (o HM não
        // exprime a dualidade nem o confinamento).
        // bound :: forall a. a -> a
        env.insert(
            "bound".into(),
            Scheme {
                vars: vec![0],
                ty: Ty::Fun(Box::new(Ty::Var(0)), Box::new(Ty::Var(0))),
            },
        );
        // newChannel :: forall a b. (Ep a, Ep b)
        env.insert(
            "newChannel".into(),
            Scheme {
                vars: vec![0, 1],
                ty: Ty::Tuple(vec![ep(0), ep(1)]),
            },
        );
        // spawn :: forall a b c. (Ep a -> b) -> Ep c
        env.insert(
            "spawn".into(),
            Scheme {
                vars: vec![0, 1, 2],
                ty: Ty::Fun(
                    Box::new(Ty::Fun(Box::new(ep(0)), Box::new(Ty::Var(1)))),
                    Box::new(ep(2)),
                ),
            },
        );
        // escolha de sessão (§6/§9): `select L c` escolhe o rótulo `L` (⊕) e
        // avança; `offer c` recebe a escolha (&) e consome o endpoint. Tipos
        // permissivos — a fidelidade/exaustividade é do `check_sessions`.
        // select :: forall a b c. b -> Ep a -> Ep c
        env.insert(
            "select".into(),
            Scheme {
                vars: vec![0, 1, 2],
                ty: Ty::Fun(
                    Box::new(Ty::Var(1)),
                    Box::new(Ty::Fun(Box::new(ep(0)), Box::new(ep(2)))),
                ),
            },
        );
        // offer :: forall a b. Ep a -> b  (recebe a escolha externa; o resultado é
        // um valor-soma etiquetado — `L (Ep Cont)` — sobre o qual se faz `case`;
        // retorno genérico porque os rótulos/continuações são do programa)
        env.insert(
            "offer".into(),
            Scheme {
                vars: vec![0, 1],
                ty: Ty::Fun(Box::new(ep(0)), Box::new(Ty::Var(1))),
            },
        );
        // cancel :: forall a. Ep a -> IO ()  (§7: descarta o endpoint, avisa o par)
        env.insert(
            "cancel".into(),
            Scheme {
                vars: vec![0],
                ty: Ty::Fun(
                    Box::new(ep(0)),
                    Box::new(Ty::Con("IO".into(), vec![Ty::Con("()".into(), vec![])])),
                ),
            },
        );
        // mapM_ :: forall a. (a -> IO ()) -> List a -> IO ()  (L0; builtin no interp)
        let io_unit = || Ty::Con("IO".into(), vec![Ty::Con("()".into(), vec![])]);
        env.insert(
            "mapM_".into(),
            Scheme {
                vars: vec![0],
                ty: Ty::Fun(
                    Box::new(Ty::Fun(Box::new(Ty::Var(0)), Box::new(io_unit()))),
                    Box::new(Ty::Fun(
                        Box::new(Ty::Con("List".into(), vec![Ty::Var(0)])),
                        Box::new(io_unit()),
                    )),
                ),
            },
        );
        // withArena :: forall a. (Arena -> a) -> a — cria a arena-raiz, corre o
        // corpo e reclama tudo no fim (a entrada para correr programas de arena).
        env.insert(
            "withArena".into(),
            Scheme {
                vars: vec![0],
                ty: Ty::Fun(
                    Box::new(Ty::Fun(Box::new(arena()), Box::new(Ty::Var(0)))),
                    Box::new(Ty::Var(0)),
                ),
            },
        );
        // marcas de arena (Listagem 3.6): reclamação intra-escopo
        let mark = || Ty::Con("Mark".into(), vec![]);
        let unit = || Ty::Con("()".into(), vec![]);
        // arena_mark :: Arena -> Mark
        env.insert(
            "arena_mark".into(),
            mono(Ty::Fun(Box::new(arena()), Box::new(mark()))),
        );
        // arena_release :: Mark -> ()
        env.insert(
            "arena_release".into(),
            mono(Ty::Fun(Box::new(mark()), Box::new(unit()))),
        );
        // Buffer polimórfico no elemento (`Buffer a`, ex.: `Buffer U8`). A
        // linearidade (%1) é imposta pelo check.rs (mapa `consumers` + must-use);
        // aqui são só os tipos HM. `a`=var 0, `b`=var 1 (resultado do withBuffer).
        let bufa = || Ty::Con("Buffer".into(), vec![Ty::Var(0)]);
        let int = || Ty::Con("Int".into(), vec![]);
        let io_unit = || Ty::Con("IO".into(), vec![unit()]);
        // newBuffer :: forall a. Int -> Buffer a
        env.insert(
            "newBuffer".into(),
            Scheme {
                vars: vec![0],
                ty: Ty::Fun(Box::new(int()), Box::new(bufa())),
            },
        );
        // withBuffer :: forall a b. Int -> (Buffer a -> b) -> b
        env.insert(
            "withBuffer".into(),
            Scheme {
                vars: vec![0, 1],
                ty: Ty::Fun(
                    Box::new(int()),
                    Box::new(Ty::Fun(
                        Box::new(Ty::Fun(Box::new(bufa()), Box::new(Ty::Var(1)))),
                        Box::new(Ty::Var(1)),
                    )),
                ),
            },
        );
        // bufIota/xorInPlace :: forall a. Buffer a -> … -> Buffer a (in-place)
        env.insert(
            "bufIota".into(),
            Scheme {
                vars: vec![0],
                ty: Ty::Fun(Box::new(bufa()), Box::new(bufa())),
            },
        );
        env.insert(
            "xorInPlace".into(),
            Scheme {
                vars: vec![0],
                ty: Ty::Fun(
                    Box::new(bufa()),
                    Box::new(Ty::Fun(Box::new(int()), Box::new(bufa()))),
                ),
            },
        );
        // sumBytes :: forall a. Buffer a -> Int; free :: forall a. Buffer a -> IO ()
        env.insert(
            "sumBytes".into(),
            Scheme {
                vars: vec![0],
                ty: Ty::Fun(Box::new(bufa()), Box::new(int())),
            },
        );
        env.insert(
            "free".into(),
            Scheme {
                vars: vec![0],
                ty: Ty::Fun(Box::new(bufa()), Box::new(io_unit())),
            },
        );
        // foldBytes :: forall a e. (a -> Int -> a) -> a -> Buffer e -> a
        // — dobra sobre os bytes (empresta o buffer). O byte é `Int`.
        env.insert(
            "foldBytes".into(),
            Scheme {
                vars: vec![0, 1],
                ty: Ty::Fun(
                    Box::new(Ty::Fun(
                        Box::new(Ty::Var(0)),
                        Box::new(Ty::Fun(Box::new(int()), Box::new(Ty::Var(0)))),
                    )),
                    Box::new(Ty::Fun(
                        Box::new(Ty::Var(0)),
                        Box::new(Ty::Fun(Box::new(bufa()), Box::new(Ty::Var(0)))),
                    )),
                ),
            },
        );
        // imperative :: forall a. a -> a — o bloco imperativo (§5) é identidade.
        env.insert(
            "imperative".into(),
            Scheme {
                vars: vec![0],
                ty: Ty::Fun(Box::new(Ty::Var(0)), Box::new(Ty::Var(0))),
            },
        );
        // permissões fraccionárias (§2). split :: forall a. a -> (a, a);
        // join :: forall a. a -> a -> a. As multiplicidades (%1/%0.5) são
        // rastreadas à parte, pela análise em check.rs.
        env.insert(
            "split".into(),
            Scheme {
                vars: vec![0],
                ty: Ty::Fun(
                    Box::new(Ty::Var(0)),
                    Box::new(Ty::Tuple(vec![Ty::Var(0), Ty::Var(0)])),
                ),
            },
        );
        env.insert(
            "join".into(),
            Scheme {
                vars: vec![0],
                ty: Ty::Fun(
                    Box::new(Ty::Var(0)),
                    Box::new(Ty::Fun(Box::new(Ty::Var(0)), Box::new(Ty::Var(0)))),
                ),
            },
        );
        env
    }

    fn scheme_of_sig(&mut self, sig: &Type) -> Scheme {
        let ty = ty_of_ast(sig);
        // as variáveis da assinatura (banda 1_000_000+) tornam-se quantificadas
        let mut vars = Vec::new();
        collect_sig_vars(&ty, &mut vars);
        // renumera para variáveis frescas normais e quantifica-as
        let mut map = HashMap::new();
        for v in &vars {
            if let Ty::Var(f) = self.fresh() {
                map.insert(*v, f);
            }
        }
        let ty = rename_vars(&ty, &map);
        Scheme {
            vars: map.values().copied().collect(),
            ty,
        }
    }

    // --- substituição / unificação ---
    fn resolve(&self, t: &Ty) -> Ty {
        match t {
            Ty::Var(v) => match self.subst.get(v) {
                Some(u) => self.resolve(u),
                None => t.clone(),
            },
            _ => t.clone(),
        }
    }

    /// Descarrega as obrigações de instância recolhidas (fatia 2b). Para cada uso
    /// de método: se o tipo de despacho resolveu para um tipo CONCRETO sem
    /// instância → **AX0404**; se ficou POLIMÓRFICO e a classe não está coberta
    /// por um constraint no âmbito da função → **AX0405**. (Fun/Tuple: conservador,
    /// não reporta.)
    fn discharge_obligations(&mut self, module: &Module) -> Mono {
        use std::collections::{HashMap as Map, HashSet as Set};
        let instances: Set<(String, String)> = module
            .instances
            .iter()
            .map(|i| (i.class_name.clone(), i.ty_head.clone()))
            .collect();
        let func_names: Set<&str> = module.funcs.iter().map(|f| f.name.as_str()).collect();

        let mut resolutions: Map<(String, Span), String> = Map::new();
        // por função constrangida: usos polimórficos de método (span → método) e
        // chamadas polimórficas a funções constrangidas (span → função, incluindo
        // a auto-recursão) — os pontos que a especialização reescreve para `$T`.
        let mut poly_methods: Map<String, Vec<(Span, String)>> = Map::new();
        let mut poly_calls: Map<String, Vec<(Span, String)>> = Map::new();

        let obls = std::mem::take(&mut self.obligations);
        for o in obls {
            match self.resolve(&o.ty) {
                // tipo concreto COM instância → resolve para a impl directa.
                Ty::Con(name, _) if instances.contains(&(o.class.clone(), name.clone())) => {
                    resolutions.insert(
                        (o.func.clone(), o.span),
                        crate::ast::method_impl_name(&o.method, &name),
                    );
                }
                Ty::Con(name, _) => {
                    self.diags.push(
                        Diagnostic::error(
                            "AX0404",
                            format!("sem instância de `{}` para `{name}`", o.class),
                        )
                        .label(o.span.0, o.span.1, "método usado aqui, sobre este tipo")
                        .with_help(format!(
                            "declare `instance {} {name} where …`, ou use um tipo \
                             que tenha instância desta classe.",
                            o.class
                        )),
                    );
                }
                // polimórfico coberto por constraint → uso especializável (2b-β).
                Ty::Var(_) if o.scope.contains(&o.class) => {
                    poly_methods
                        .entry(o.func.clone())
                        .or_default()
                        .push((o.span, o.method.clone()));
                }
                Ty::Var(_) => {
                    self.diags.push(
                        Diagnostic::error(
                            "AX0405",
                            format!(
                                "método da classe `{}` usado sobre um tipo polimórfico \
                                 sem constraint",
                                o.class
                            ),
                        )
                        .label(o.span.0, o.span.1, "tipo genérico aqui")
                        .with_help(format!(
                            "acrescente `{} a =>` à assinatura da função para permitir \
                             o método sobre um tipo genérico.",
                            o.class
                        )),
                    );
                }
                _ => {}
            }
        }

        // usos de funções constrangidas → sementes de especialização (concretas)
        // e chamadas polimórficas (transitivas, para a var de constraint).
        let mut seeds: Vec<(String, Span, String, String)> = Vec::new(); // caller,span,fn,T
        let specs_obls = std::mem::take(&mut self.spec_obligations);
        for s in specs_obls {
            match self.resolve(&s.ty) {
                // chamada num tipo concreto → semente `(fn, T)` + call-site.
                Ty::Con(t, _) => seeds.push((s.func.clone(), s.span, s.target.clone(), t)),
                // chamada sobre a var genérica → reescreve-se para `$T` quando o
                // chamador for especializado (a auto-recursão é o caso `g == f`).
                Ty::Var(_) => poly_calls
                    .entry(s.func.clone())
                    .or_default()
                    .push((s.span, s.target.clone())),
                _ => {}
            }
        }

        // expande o conjunto de especializações necessárias por worklist: uma
        // `(f, T)` puxa `(g, T)` por cada chamada constrangida polimórfica em `f`
        // (a var de constraint de `g` é a mesma de `f`, logo o mesmo `T`). Fecha a
        // especialização TRANSITIVA (fatia 2b-β-2).
        let mut cands: Set<(String, String)> = Set::new();
        let mut queue: Vec<(String, String)> = Vec::new();
        for (_, _, f, t) in &seeds {
            if cands.insert((f.clone(), t.clone())) {
                queue.push((f.clone(), t.clone()));
            }
        }
        while let Some((f, t)) = queue.pop() {
            for (_, g) in poly_calls.get(&f).into_iter().flatten() {
                let node = (g.clone(), t.clone());
                if cands.insert(node.clone()) {
                    queue.push(node);
                }
            }
        }

        // validade por ponto-fixo: `(f, T)` é válida a menos que `f` seja
        // inespecializável, falte a var de despacho, falte alguma impl de método
        // `m$T`, ou alguma dependência `(g, T)` seja inválida.
        let mut invalid: Set<(String, String)> = Set::new();
        loop {
            let mut changed = false;
            for (f, t) in &cands {
                if invalid.contains(&(f.clone(), t.clone())) {
                    continue;
                }
                let no_spec_var = self
                    .constrained_meta
                    .get(f)
                    .is_none_or(|(_, idx)| idx.is_none());
                let bad = self.refs_unspec.contains(f)
                    || no_spec_var
                    || poly_methods.get(f).into_iter().flatten().any(|(_, m)| {
                        !func_names.contains(crate::ast::method_impl_name(m, t).as_str())
                    })
                    || poly_calls
                        .get(f)
                        .into_iter()
                        .flatten()
                        .any(|(_, g)| invalid.contains(&(g.clone(), t.clone())));
                if bad {
                    invalid.insert((f.clone(), t.clone()));
                    changed = true;
                }
            }
            if !changed {
                break;
            }
        }

        // materializa cada especialização válida.
        let mut specs: Vec<SpecPlan> = Vec::new();
        for (f, t) in &cands {
            if invalid.contains(&(f.clone(), t.clone())) {
                continue;
            }
            let name = crate::ast::method_impl_name(f, t);
            let mut rewrites: HashMap<Span, String> = HashMap::new();
            for (sp, m) in poly_methods.get(f).into_iter().flatten() {
                rewrites.insert(*sp, crate::ast::method_impl_name(m, t));
            }
            for (sp, g) in poly_calls.get(f).into_iter().flatten() {
                rewrites.insert(*sp, crate::ast::method_impl_name(g, t));
            }
            let tyvar = self
                .constrained_meta
                .get(f)
                .map(|(v, _)| v.clone())
                .unwrap_or_default();
            specs.push(SpecPlan {
                src: f.clone(),
                name,
                tyvar,
                ty_head: t.clone(),
                rewrites,
            });
        }
        // reescreve os call-sites-semente cujas especializações são válidas.
        for (caller, span, f, t) in seeds {
            if cands.contains(&(f.clone(), t.clone())) && !invalid.contains(&(f.clone(), t.clone()))
            {
                resolutions.insert((caller, span), crate::ast::method_impl_name(&f, &t));
            }
        }

        Mono { resolutions, specs }
    }

    fn apply(&self, t: &Ty) -> Ty {
        match self.resolve(t) {
            Ty::Con(n, args) => Ty::Con(n, args.iter().map(|a| self.apply(a)).collect()),
            Ty::Fun(a, b) => Ty::Fun(Box::new(self.apply(&a)), Box::new(self.apply(&b))),
            Ty::Tuple(ts) => Ty::Tuple(ts.iter().map(|a| self.apply(a)).collect()),
            other => other,
        }
    }

    fn occurs(&self, v: u32, t: &Ty) -> bool {
        match self.resolve(t) {
            Ty::Var(u) => u == v,
            Ty::Con(_, args) => args.iter().any(|a| self.occurs(v, a)),
            Ty::Fun(a, b) => self.occurs(v, &a) || self.occurs(v, &b),
            Ty::Tuple(ts) => ts.iter().any(|a| self.occurs(v, a)),
        }
    }

    fn unify(&mut self, a: &Ty, b: &Ty, span: Span) -> bool {
        let a = self.resolve(a);
        let b = self.resolve(b);
        match (&a, &b) {
            (Ty::Var(x), Ty::Var(y)) if x == y => true,
            (Ty::Var(x), _) => self.bind(*x, &b, span),
            (_, Ty::Var(y)) => self.bind(*y, &a, span),
            (Ty::Con(n1, a1), Ty::Con(n2, a2)) if n1 == n2 && a1.len() == a2.len() => {
                let mut ok = true;
                for (x, y) in a1.iter().zip(a2) {
                    ok &= self.unify(x, y, span);
                }
                ok
            }
            (Ty::Fun(l1, r1), Ty::Fun(l2, r2)) => {
                let ok1 = self.unify(l1, l2, span);
                let ok2 = self.unify(r1, r2, span);
                ok1 && ok2
            }
            (Ty::Tuple(t1), Ty::Tuple(t2)) if t1.len() == t2.len() => {
                let mut ok = true;
                for (x, y) in t1.iter().zip(t2) {
                    ok &= self.unify(x, y, span);
                }
                ok
            }
            _ => {
                self.err_mismatch(&a, &b, span);
                false
            }
        }
    }

    fn bind(&mut self, v: u32, t: &Ty, span: Span) -> bool {
        if let Ty::Var(u) = t {
            if *u == v {
                return true;
            }
        }
        if self.occurs(v, t) {
            self.diags.push(
                Diagnostic::error("AX0201", "tipo infinito (occurs-check falhou)").label(
                    span.0,
                    span.1,
                    "a inferência formaria um tipo recursivo aqui",
                ),
            );
            return false;
        }
        self.subst.insert(v, t.clone());
        true
    }

    fn err_mismatch(&mut self, a: &Ty, b: &Ty, span: Span) {
        let sa = show_ty(&self.apply(a));
        let sb = show_ty(&self.apply(b));
        self.diags.push(
            Diagnostic::error(
                "AX0200",
                format!("incompatibilidade de tipos: {sa} vs {sb}"),
            )
            .label(span.0, span.1, format!("esperava {sa}, encontrei {sb}"))
            .with_help(
                "a inferência exigia estes dois tipos iguais; verifique a assinatura e os \
                 argumentos da aplicação.",
            ),
        );
    }

    fn instantiate(&mut self, s: &Scheme) -> Ty {
        let mut map = HashMap::new();
        for v in &s.vars {
            if let Ty::Var(f) = self.fresh() {
                map.insert(*v, f);
            }
        }
        rename_vars(&s.ty, &map)
    }

    fn generalize(&self, env: &Env, ty: &Ty) -> Scheme {
        let ty = self.apply(ty);
        let mut env_vars = HashSet::new();
        for s in env.values() {
            let applied = self.apply(&s.ty);
            let mut fv = HashSet::new();
            free_vars(&applied, &mut fv);
            for q in &s.vars {
                fv.remove(q);
            }
            env_vars.extend(fv);
        }
        let mut fv = HashSet::new();
        free_vars(&ty, &mut fv);
        let vars: Vec<u32> = fv.difference(&env_vars).copied().collect();
        Scheme { vars, ty }
    }

    // --- inferência ---
    fn peel_fun(&self, ty: &Ty, n: usize) -> (Vec<Ty>, Ty) {
        let mut params = Vec::new();
        let mut cur = self.resolve(ty);
        for _ in 0..n {
            match cur {
                Ty::Fun(a, b) => {
                    params.push(*a);
                    cur = self.resolve(&b);
                }
                other => {
                    cur = other;
                    break;
                }
            }
        }
        (params, cur)
    }

    fn infer_func(&mut self, env: &Env, f: &Func, expected: Option<&Ty>) -> Ty {
        let mut result: Option<Ty> = None;
        for clause in &f.clauses {
            let t = self.infer_clause(env, clause, expected);
            match &result {
                None => result = Some(t),
                Some(r) => {
                    self.unify(r, &t, clause.span);
                }
            }
        }
        result.unwrap_or_else(|| self.fresh())
    }

    fn infer_clause(&mut self, env: &Env, clause: &Clause, expected: Option<&Ty>) -> Ty {
        let mut local = env.clone();
        let n = clause.pats.len();
        let (exp_params, exp_result) = match expected {
            Some(t) => {
                let (p, r) = self.peel_fun(t, n);
                (p, Some(r))
            }
            None => (Vec::new(), None),
        };
        let mut params = Vec::new();
        for (i, p) in clause.pats.iter().enumerate() {
            let pt = self.infer_pat(&mut local, p);
            if let Some(ep) = exp_params.get(i) {
                self.unify(&pt, ep, clause.span);
            }
            params.push(pt);
        }
        // where: grupo de bindings com generalização
        let local = self.infer_group(&local, &clause.wher);
        let body_ty = match &clause.body {
            Body::Plain(e) => self.infer_expr(&local, e),
            Body::Guarded(arms) => {
                let mut rty: Option<Ty> = None;
                for (g, r) in arms {
                    let gt = self.infer_expr(&local, g);
                    self.unify(&gt, &Ty::Con("Bool".into(), vec![]), g.span());
                    let rt = self.infer_expr(&local, r);
                    match &rty {
                        None => rty = Some(rt),
                        Some(x) => {
                            self.unify(x, &rt, r.span());
                        }
                    }
                }
                rty.unwrap_or_else(|| self.fresh())
            }
        };
        if let Some(er) = &exp_result {
            self.unify(&body_ty, er, clause.span);
        }
        let mut ty = body_ty;
        for p in params.into_iter().rev() {
            ty = Ty::Fun(Box::new(p), Box::new(ty));
        }
        ty
    }

    fn infer_pat(&mut self, env: &mut Env, p: &Pat) -> Ty {
        match p {
            Pat::Wild(_) => self.fresh(),
            Pat::Int(_, _) => Ty::Con("Int".into(), vec![]),
            Pat::Var(n, _) => {
                let t = self.fresh();
                env.insert(n.clone(), mono(t.clone()));
                t
            }
            Pat::Con(name, args, span) => {
                // construtor aplicado: instancia o tipo do construtor
                let cty = match env.get(name) {
                    Some(s) => self.instantiate(s),
                    None => return self.fresh(),
                };
                let mut result = cty;
                for a in args {
                    let at = self.infer_pat(env, a);
                    let r = self.fresh();
                    self.unify(&result, &Ty::Fun(Box::new(at), Box::new(r.clone())), *span);
                    result = r;
                }
                result
            }
            Pat::Tuple(ps, _) => Ty::Tuple(ps.iter().map(|p| self.infer_pat(env, p)).collect()),
        }
    }

    /// Infere um grupo de bindings (`let`/`where`) com generalização e
    /// devolve o env estendido.
    fn infer_group(&mut self, env: &Env, funcs: &[Func]) -> Env {
        if funcs.is_empty() {
            return env.clone();
        }
        // fase monomórfica: cada nome recebe uma var fresca
        let mut mono_env = env.clone();
        let mut vars = HashMap::new();
        for f in funcs {
            let v = self.fresh();
            vars.insert(f.name.clone(), v.clone());
            mono_env.insert(f.name.clone(), mono(v));
        }
        for f in funcs {
            let t = self.infer_func(&mono_env, f, None);
            let v = vars[&f.name].clone();
            self.unify(&v, &t, f.span);
        }
        // fase de generalização: rebind com esquemas fechados sobre o env exterior
        let mut out = env.clone();
        for f in funcs {
            let t = self.apply(&vars[&f.name]);
            let scheme = self.generalize(env, &t);
            out.insert(f.name.clone(), scheme);
        }
        out
    }

    fn infer_expr(&mut self, env: &Env, e: &Expr) -> Ty {
        match e {
            Expr::Int(_, _) => Ty::Con("Int".into(), vec![]),
            Expr::Str(_, _) => Ty::Con("String".into(), vec![]),
            Expr::Var(n, span) => {
                let ty = match env.get(n) {
                    Some(s) => self.instantiate(s),
                    None => self.fresh(), // nome não encontrado: reportado pelo check.rs
                };
                // uso de método: recolhe a obrigação de instância sobre o tipo do
                // parâmetro de despacho (resolvido no fim).
                if let Some((class, Some(idx))) = self.method_meta.get(n).cloned() {
                    if let Some(dispatch) = nth_param(&ty, idx) {
                        self.obligations.push(Obl {
                            class,
                            method: n.clone(),
                            ty: dispatch,
                            span: *span,
                            scope: self.cur_constraints.clone(),
                            func: self.cur_fn.clone(),
                        });
                    }
                }
                // uso de uma função constrangida: recolhe a obrigação de
                // especialização sobre o tipo da var de constraint (fatia 2b-β).
                if let Some((_, idx)) = self.constrained_meta.get(n).cloned() {
                    match idx {
                        Some(i) => {
                            if let Some(dispatch) = nth_param(&ty, i) {
                                self.spec_obligations.push(SpecObl {
                                    target: n.clone(),
                                    ty: dispatch,
                                    span: *span,
                                    func: self.cur_fn.clone(),
                                });
                            }
                        }
                        // constrangida sem parâmetro de despacho → não capturável:
                        // a função que a usa não pode ser especializada.
                        None => {
                            self.refs_unspec.insert(self.cur_fn.clone());
                        }
                    }
                }
                ty
            }
            Expr::Con(n, _) => match env.get(n) {
                Some(s) => self.instantiate(s),
                None => self.fresh(),
            },
            Expr::App(f, x, span) => {
                let tf = self.infer_expr(env, f);
                let tx = self.infer_expr(env, x);
                let r = self.fresh();
                self.unify(&tf, &Ty::Fun(Box::new(tx), Box::new(r.clone())), *span);
                r
            }
            Expr::BinOp(op, l, r, span) => {
                let top = match env.get(op) {
                    Some(s) => self.instantiate(s),
                    None => self.fresh(),
                };
                let tl = self.infer_expr(env, l);
                let tr = self.infer_expr(env, r);
                let res = self.fresh();
                let want = Ty::Fun(
                    Box::new(tl),
                    Box::new(Ty::Fun(Box::new(tr), Box::new(res.clone()))),
                );
                self.unify(&top, &want, *span);
                res
            }
            Expr::If(c, t, el, span) => {
                let tc = self.infer_expr(env, c);
                self.unify(&tc, &Ty::Con("Bool".into(), vec![]), c.span());
                let tt = self.infer_expr(env, t);
                let te = self.infer_expr(env, el);
                self.unify(&tt, &te, *span);
                tt
            }
            Expr::Let(binds, body, _) => {
                let env2 = self.infer_group(env, binds);
                self.infer_expr(&env2, body)
            }
            Expr::Case(scrut, arms, span) => {
                let ts = self.infer_expr(env, scrut);
                let mut rty: Option<Ty> = None;
                for (pat, body) in arms {
                    let mut local = env.clone();
                    let tp = self.infer_pat(&mut local, pat);
                    self.unify(&tp, &ts, *span);
                    let tb = self.infer_expr(&local, body);
                    match &rty {
                        None => rty = Some(tb),
                        Some(x) => {
                            self.unify(x, &tb, body.span());
                        }
                    }
                }
                rty.unwrap_or_else(|| self.fresh())
            }
            Expr::Tuple(es, _) => Ty::Tuple(es.iter().map(|e| self.infer_expr(env, e)).collect()),
            Expr::RecordCon(con, assigns, span) => {
                let (tyname, fields) = match self.cons.get(con) {
                    Some(x) => x.clone(),
                    None => return self.fresh(),
                };
                for (fname, fexpr) in assigns {
                    let fe = self.infer_expr(env, fexpr);
                    if let Some((_, ft)) = fields.iter().find(|(n, _)| n == fname) {
                        self.unify(&fe, ft, *span);
                    }
                }
                Ty::Con(tyname, vec![])
            }
            Expr::RecordUpd(base, assigns, span) => {
                let tb = self.infer_expr(env, base);
                let resolved = self.apply(&tb);
                if let Ty::Con(tyname, _) = &resolved {
                    if let Some(fields) = self.records.get(tyname).cloned() {
                        for (fname, fexpr) in assigns {
                            let fe = self.infer_expr(env, fexpr);
                            if let Some((_, ft)) = fields.iter().find(|(n, _)| n == fname) {
                                self.unify(&fe, ft, *span);
                            }
                        }
                    }
                } else {
                    // base ainda desconhecida: apenas infere os campos
                    for (_, fexpr) in assigns {
                        self.infer_expr(env, fexpr);
                    }
                }
                tb
            }
            Expr::Lam(pats, body, _) => {
                let mut local = env.clone();
                let params: Vec<Ty> = pats.iter().map(|p| self.infer_pat(&mut local, p)).collect();
                let mut ty = self.infer_expr(&local, body);
                for p in params.into_iter().rev() {
                    ty = Ty::Fun(Box::new(p), Box::new(ty));
                }
                ty
            }
        }
    }
}

fn mono(ty: Ty) -> Scheme {
    Scheme { vars: vec![], ty }
}

fn collect_sig_vars(t: &Ty, out: &mut Vec<u32>) {
    match t {
        Ty::Var(v) => {
            if *v >= 1_000_000 && !out.contains(v) {
                out.push(*v);
            }
        }
        Ty::Con(_, args) => args.iter().for_each(|a| collect_sig_vars(a, out)),
        Ty::Fun(a, b) => {
            collect_sig_vars(a, out);
            collect_sig_vars(b, out);
        }
        Ty::Tuple(ts) => ts.iter().for_each(|a| collect_sig_vars(a, out)),
    }
}

fn rename_vars(t: &Ty, map: &HashMap<u32, u32>) -> Ty {
    match t {
        Ty::Var(v) => Ty::Var(*map.get(v).unwrap_or(v)),
        Ty::Con(n, args) => Ty::Con(
            n.clone(),
            args.iter().map(|a| rename_vars(a, map)).collect(),
        ),
        Ty::Fun(a, b) => Ty::Fun(Box::new(rename_vars(a, map)), Box::new(rename_vars(b, map))),
        Ty::Tuple(ts) => Ty::Tuple(ts.iter().map(|a| rename_vars(a, map)).collect()),
    }
}

fn free_vars(t: &Ty, out: &mut HashSet<u32>) {
    match t {
        Ty::Var(v) => {
            out.insert(*v);
        }
        Ty::Con(_, args) => args.iter().for_each(|a| free_vars(a, out)),
        Ty::Fun(a, b) => {
            free_vars(a, out);
            free_vars(b, out);
        }
        Ty::Tuple(ts) => ts.iter().for_each(|a| free_vars(a, out)),
    }
}

fn show_ty(t: &Ty) -> String {
    match t {
        Ty::Var(v) => format!("?{v}"),
        Ty::Con(n, args) if args.is_empty() => n.clone(),
        Ty::Con(n, args) => {
            let inner: Vec<String> = args.iter().map(show_ty).collect();
            format!("{n} {}", inner.join(" "))
        }
        Ty::Fun(a, b) => format!("{} -> {}", show_ty_atom(a), show_ty(b)),
        Ty::Tuple(ts) => {
            let inner: Vec<String> = ts.iter().map(show_ty).collect();
            format!("({})", inner.join(", "))
        }
    }
}

fn show_ty_atom(t: &Ty) -> String {
    match t {
        Ty::Fun(_, _) => format!("({})", show_ty(t)),
        _ => show_ty(t),
    }
}
