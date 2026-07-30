//! Interpretador de referência do **Axión Session Core (ASC)** — a semântica
//! executável do cálculo de sessões (ver `docs/phase-3-calculus.md`), para
//! validar os teoremas T1–T5 por execução ANTES de o compilador de produção
//! ganhar canais. Não é o backend: é o oráculo contra o qual o typechecker de
//! sessões da Fase 3 será depois cruzado (como o GHC é o oráculo da linearidade).
//!
//! Modela **configurações**: threads (cada uma um `Proc` — uma continuação
//! defuncionalizada) + buffers de canal assíncronos + a árvore de `spawn`. Um
//! gerador determinístico produz protocolos **bem-tipados por construção** (um
//! lado segue `S`, o outro `dual(S)`) com topologia em **árvore** (nursery), e
//! os testes verificam: termina sem deadlock (T2/T4), a fidelidade de sessão
//! aguenta (T3), e um pânico cancela sem órfãos (T5).
#![cfg(test)]

use std::collections::{HashMap, VecDeque};

// --- tipos de sessão + dualidade (§2) ---

#[derive(Clone, Debug, PartialEq, Eq, Hash)]
enum Session {
    End,
    Send(Box<Session>),   // !T.S  (payload abstraído: um valor)
    Recv(Box<Session>),   // ?T.S
    Select(Vec<Session>), // ⊕ — escolhe um ramo (lado interno)
    Offer(Vec<Session>),  // & — oferece todos os ramos (lado externo)
}

fn dual(s: &Session) -> Session {
    match s {
        Session::End => Session::End,
        Session::Send(k) => Session::Recv(Box::new(dual(k))),
        Session::Recv(k) => Session::Send(Box::new(dual(k))),
        Session::Select(bs) => Session::Offer(bs.iter().map(dual).collect()),
        Session::Offer(bs) => Session::Select(bs.iter().map(dual).collect()),
    }
}

// --- programa de uma thread: uma continuação defuncionalizada sobre endpoints ---

type EpId = u32;

#[derive(Clone, Debug)]
enum Proc {
    Done,
    Send(EpId, i64, Box<Proc>),
    Recv(EpId, Box<Proc>),
    Close(EpId, Box<Proc>),
    Sel(EpId, usize, Box<Proc>),
    Off(EpId, Vec<Proc>),
    /// cria um canal (my_ep ↔ child_ep), lança o filho e continua
    Spawn {
        my_ep: EpId,
        child_ep: EpId,
        child: Box<Proc>,
        cont: Box<Proc>,
    },
    /// pânico (§7): o Linear Unwinding cancela os endpoints vivos da thread
    Raise,
}

// --- gerador determinístico de protocolos bem-tipados em árvore ---

struct Rng(u64);
impl Rng {
    fn next_u64(&mut self) -> u64 {
        let mut x = self.0;
        x ^= x >> 12;
        x ^= x << 25;
        x ^= x >> 27;
        self.0 = x;
        x.wrapping_mul(0x2545_F491_4F6C_DD1D)
    }
    fn below(&mut self, n: u32) -> u32 {
        (self.next_u64() % n as u64) as u32
    }
}

fn gen_session(rng: &mut Rng, depth: u32) -> Session {
    if depth == 0 || rng.below(100) < 30 {
        return Session::End;
    }
    match rng.below(4) {
        0 => Session::Send(Box::new(gen_session(rng, depth - 1))),
        1 => Session::Recv(Box::new(gen_session(rng, depth - 1))),
        2 => {
            let n = 1 + rng.below(2) as usize; // 1..2 ramos
            Session::Select((0..n).map(|_| gen_session(rng, depth - 1)).collect())
        }
        _ => {
            let n = 1 + rng.below(2) as usize;
            Session::Offer((0..n).map(|_| gen_session(rng, depth - 1)).collect())
        }
    }
}

/// Constrói o `Proc` que executa `s` no endpoint `ep` e depois continua com `cont`.
fn follow(rng: &mut Rng, s: &Session, ep: EpId, cont: Proc) -> Proc {
    match s {
        Session::End => Proc::Close(ep, Box::new(cont)),
        Session::Send(k) => {
            let v = rng.below(1000) as i64;
            Proc::Send(ep, v, Box::new(follow(rng, k, ep, cont)))
        }
        Session::Recv(k) => Proc::Recv(ep, Box::new(follow(rng, k, ep, cont))),
        Session::Select(bs) => {
            let j = rng.below(bs.len() as u32) as usize; // escolhe um ramo
            Proc::Sel(ep, j, Box::new(follow(rng, &bs[j], ep, cont)))
        }
        Session::Offer(bs) => {
            // oferece todos os ramos; cada um continua para `cont`
            let arms = bs
                .iter()
                .map(|b| follow(rng, b, ep, cont.clone()))
                .collect();
            Proc::Off(ep, arms)
        }
    }
}

/// Gera o `Proc` de uma thread: 0..2 filhos (cada um um sub-protocolo), depois
/// (se tiver) o protocolo do canal para o pai. `up` = (sessão, endpoint) do pai.
fn gen_thread(rng: &mut Rng, up: Option<(Session, EpId)>, depth: u32, ctr: &mut EpId) -> Proc {
    let tail = match up {
        Some((s, ep)) => follow(rng, &s, ep, Proc::Done),
        None => Proc::Done,
    };
    let nchild = if depth == 0 { 0 } else { rng.below(3) }; // 0..2
    let mut proc = tail;
    for _ in 0..nchild {
        let s2 = gen_session(rng, depth - 1);
        let my_ep = {
            *ctr += 1;
            *ctr
        };
        let child_ep = {
            *ctr += 1;
            *ctr
        };
        let child = gen_thread(rng, Some((dual(&s2), child_ep)), depth - 1, ctr);
        // o pai faz `s2` no seu lado e depois continua com o que já tinha
        let after = follow(rng, &s2, my_ep, proc);
        proc = Proc::Spawn {
            my_ep,
            child_ep,
            child: Box::new(child),
            cont: Box::new(after),
        };
    }
    proc
}

fn gen_program(seed: u64, depth: u32) -> Proc {
    let mut rng = Rng(seed | 1);
    let mut ctr = 0;
    gen_thread(&mut rng, None, depth, &mut ctr)
}

// --- interpretador de configurações (semântica operacional §5) ---

#[derive(Clone, Copy, Debug, PartialEq)]
enum Msg {
    Val(i64),
    Label(usize),
    Closed, // sinal de cancelamento (§7): o par entregou `Closed`
}

struct Thread {
    proc: Option<Proc>,                   // None = terminada
    eps: std::collections::HashSet<EpId>, // endpoints vivos (para cancelar no pânico)
}

struct Config {
    threads: Vec<Thread>,
    buf: HashMap<EpId, VecDeque<Msg>>, // fila de entrada de cada endpoint
    peer: HashMap<EpId, EpId>,         // a ponta dual
}

#[derive(Debug, PartialEq)]
enum RunResult {
    Ok,               // todas as threads terminaram
    Deadlock,         // sweep sem progresso com threads vivas (viola T2/T4)
    Fidelity(String), // mensagem recebida não casa com o protocolo (viola T3)
    StepCap,          // orçamento esgotado (indício de não-terminação)
}

enum Step {
    Went,
    Blocked,
    Done,
    Cancelled,
    Fidelity,
}

impl Config {
    fn new(root: Proc) -> Config {
        Config {
            threads: vec![Thread {
                proc: Some(root),
                eps: std::collections::HashSet::new(),
            }],
            buf: HashMap::new(),
            peer: HashMap::new(),
        }
    }

    fn send_to_peer(&mut self, ep: EpId, m: Msg) {
        if let Some(&p) = self.peer.get(&ep) {
            self.buf.entry(p).or_default().push_back(m);
        }
    }

    /// Pânico / cancelamento (§7): entrega `Closed` ao par de cada endpoint vivo
    /// e termina a thread. O(filhos) em mensagens; sem órfãos.
    fn cancel(&mut self, tid: usize) {
        let eps: Vec<EpId> = self.threads[tid].eps.drain().collect();
        for ep in eps {
            self.send_to_peer(ep, Msg::Closed);
        }
        self.threads[tid].proc = None;
    }

    fn step(&mut self, tid: usize) -> Step {
        let proc = match self.threads[tid].proc.take() {
            Some(p) => p,
            None => return Step::Done,
        };
        match proc {
            Proc::Done => Step::Done,
            Proc::Close(ep, k) => {
                self.threads[tid].eps.remove(&ep);
                self.threads[tid].proc = Some(*k);
                Step::Went
            }
            Proc::Send(ep, v, k) => {
                self.send_to_peer(ep, Msg::Val(v));
                self.threads[tid].proc = Some(*k);
                Step::Went
            }
            Proc::Sel(ep, j, k) => {
                self.send_to_peer(ep, Msg::Label(j));
                self.threads[tid].proc = Some(*k);
                Step::Went
            }
            Proc::Spawn {
                my_ep,
                child_ep,
                child,
                cont,
            } => {
                self.peer.insert(my_ep, child_ep);
                self.peer.insert(child_ep, my_ep);
                self.buf.entry(my_ep).or_default();
                self.buf.entry(child_ep).or_default();
                self.threads[tid].eps.insert(my_ep);
                self.threads.push(Thread {
                    proc: Some(*child),
                    eps: std::collections::HashSet::from([child_ep]),
                });
                self.threads[tid].proc = Some(*cont);
                Step::Went
            }
            Proc::Recv(ep, k) => match self.buf.get(&ep).and_then(|q| q.front()).copied() {
                None => {
                    self.threads[tid].proc = Some(Proc::Recv(ep, k));
                    Step::Blocked
                }
                Some(Msg::Val(_)) => {
                    self.buf.get_mut(&ep).unwrap().pop_front();
                    self.threads[tid].proc = Some(*k);
                    Step::Went
                }
                Some(Msg::Closed) => {
                    self.buf.get_mut(&ep).unwrap().pop_front();
                    self.cancel(tid); // par cancelou → propaga (§7)
                    Step::Cancelled
                }
                Some(Msg::Label(_)) => Step::Fidelity, // esperava valor, veio rótulo
            },
            Proc::Off(ep, arms) => match self.buf.get(&ep).and_then(|q| q.front()).copied() {
                None => {
                    self.threads[tid].proc = Some(Proc::Off(ep, arms));
                    Step::Blocked
                }
                Some(Msg::Label(j)) if j < arms.len() => {
                    self.buf.get_mut(&ep).unwrap().pop_front();
                    self.threads[tid].proc = Some(arms.into_iter().nth(j).unwrap());
                    Step::Went
                }
                Some(Msg::Closed) => {
                    self.buf.get_mut(&ep).unwrap().pop_front();
                    self.cancel(tid);
                    Step::Cancelled
                }
                Some(_) => Step::Fidelity, // rótulo fora do intervalo, ou veio valor
            },
            Proc::Raise => {
                self.cancel(tid);
                Step::Cancelled
            }
        }
    }

    fn run(&mut self) -> RunResult {
        let mut budget = 500_000u32;
        loop {
            let mut progressed = false;
            let n = self.threads.len();
            for tid in 0..n {
                loop {
                    if budget == 0 {
                        return RunResult::StepCap;
                    }
                    budget -= 1;
                    if self.threads[tid].proc.is_none() {
                        break;
                    }
                    match self.step(tid) {
                        Step::Went => progressed = true,
                        Step::Done => {
                            progressed = true;
                            break;
                        }
                        Step::Cancelled => {
                            progressed = true;
                            break;
                        }
                        Step::Blocked => break,
                        Step::Fidelity => return RunResult::Fidelity(format!("thread {tid}")),
                    }
                }
            }
            if self.threads.iter().all(|t| t.proc.is_none()) {
                return RunResult::Ok;
            }
            if !progressed {
                return RunResult::Deadlock;
            }
        }
    }
}

/// Injecta um `raise` (pânico) numa posição aleatória do programa, para testar o
/// cancelamento (T5). Só substitui continuações (nunca em `Done`).
fn inject_raise(p: Proc, rng: &mut Rng) -> Proc {
    if !matches!(p, Proc::Done | Proc::Raise) && rng.below(100) < 20 {
        return Proc::Raise;
    }
    match p {
        Proc::Send(e, v, k) => Proc::Send(e, v, Box::new(inject_raise(*k, rng))),
        Proc::Recv(e, k) => Proc::Recv(e, Box::new(inject_raise(*k, rng))),
        Proc::Close(e, k) => Proc::Close(e, Box::new(inject_raise(*k, rng))),
        Proc::Sel(e, j, k) => Proc::Sel(e, j, Box::new(inject_raise(*k, rng))),
        Proc::Off(e, arms) => {
            Proc::Off(e, arms.into_iter().map(|a| inject_raise(a, rng)).collect())
        }
        Proc::Spawn {
            my_ep,
            child_ep,
            child,
            cont,
        } => Proc::Spawn {
            my_ep,
            child_ep,
            child: Box::new(inject_raise(*child, rng)),
            cont: Box::new(inject_raise(*cont, rng)),
        },
        other => other, // Done | Raise
    }
}

// --- property tests dos teoremas T1–T5 (§6 do cálculo) ---

#[test]
fn t1_duality_is_involutive() {
    // A base da preservação (T1): a dualidade dos canais é involutiva, logo a
    // tipagem das duas pontas mantém-se coerente sob redução.
    for seed in 1..=500u64 {
        let s = gen_session(&mut Rng(seed | 1), 6);
        assert_eq!(dual(&dual(&s)), s, "dual não-involutivo para {s:?}");
    }
}

#[test]
fn t2_t3_t4_welltyped_trees_run_to_completion() {
    // T2/T4 (progresso + deadlock-freedom): todo o programa bem-tipado com
    // topologia em árvore (nursery) corre até ao fim sem encravar. T3 (fidelidade
    // de sessão): nenhuma mensagem recebida contradiz o protocolo.
    for seed in 1..=2000u64 {
        let p = gen_program(seed.wrapping_mul(0x9E37_79B9_7F4A_7C15), 5);
        let mut cfg = Config::new(p);
        match cfg.run() {
            RunResult::Ok => {}
            other => panic!("seed {seed}: esperava Ok, obtive {other:?}"),
        }
    }
}

#[test]
fn t5_panic_cancels_without_orphans() {
    // T5 (segurança do cancelamento): um pânico injectado propaga `Closed` pela
    // árvore e a configuração DRENA — todas as threads terminam, sem deadlock nem
    // órfãos (o `Closed` é um ramo de 1.ª classe, tratado por todos os pares).
    for seed in 1..=2000u64 {
        let base = gen_program(seed.wrapping_mul(0x9E37_79B9_7F4A_7C15), 5);
        let mut rng = Rng(seed.wrapping_mul(0xD1B5_4A32_D192_ED03) | 1);
        let p = inject_raise(base, &mut rng);
        let mut cfg = Config::new(p);
        match cfg.run() {
            RunResult::Ok => {}
            other => panic!("seed {seed}: pânico não drenou ({other:?})"),
        }
    }
}

// --- não-vacuidade: o interpretador TEM de apanhar violações reais ---

#[test]
fn detector_catches_a_real_deadlock() {
    // Espera cíclica (a topologia que o `bound`/árvore torna inexprimível, mas que
    // construímos à mão): A espera em ch1, B espera em ch2, nenhum envia primeiro.
    // Prova que T2/T4 não é vácuo — o detetor de deadlock dispara.
    use std::collections::HashSet;
    let a = Proc::Recv(1, Box::new(Proc::Send(2, 0, Box::new(Proc::Done))));
    let b = Proc::Recv(4, Box::new(Proc::Send(3, 0, Box::new(Proc::Done))));
    let mut cfg = Config {
        threads: vec![
            Thread {
                proc: Some(a),
                eps: HashSet::from([1, 2]),
            },
            Thread {
                proc: Some(b),
                eps: HashSet::from([3, 4]),
            },
        ],
        peer: HashMap::from([(1, 3), (3, 1), (2, 4), (4, 2)]),
        buf: HashMap::from([
            (1, [].into()),
            (2, [].into()),
            (3, [].into()),
            (4, [].into()),
        ]),
    };
    assert_eq!(cfg.run(), RunResult::Deadlock);
}

#[test]
fn detector_catches_a_fidelity_violation() {
    // A envia um VALOR; B faz `offer` (espera um RÓTULO). O par não segue o
    // protocolo dual → viola a Fidelidade de Sessão. Prova que T3 não é vácuo.
    use std::collections::HashSet;
    let a = Proc::Send(1, 42, Box::new(Proc::Done));
    let b = Proc::Off(2, vec![Proc::Done]);
    let mut cfg = Config {
        threads: vec![
            Thread {
                proc: Some(a),
                eps: HashSet::from([1]),
            },
            Thread {
                proc: Some(b),
                eps: HashSet::from([2]),
            },
        ],
        peer: HashMap::from([(1, 2), (2, 1)]),
        buf: HashMap::from([(1, [].into()), (2, [].into())]),
    };
    assert!(matches!(cfg.run(), RunResult::Fidelity(_)));
}

#[test]
fn generated_programs_are_nontrivial() {
    // sanidade: os programas gerados exercitam MESMO concorrência (várias threads
    // e trocas), senão os testes T2–T5 passariam vaziamente.
    let mut max_threads = 0;
    for seed in 1..=200u64 {
        let p = gen_program(seed.wrapping_mul(0x9E37_79B9_7F4A_7C15), 5);
        let mut cfg = Config::new(p);
        assert_eq!(cfg.run(), RunResult::Ok);
        max_threads = max_threads.max(cfg.threads.len());
    }
    assert!(
        max_threads >= 3,
        "gerador trivial: só {max_threads} threads no máximo"
    );
}

// --- model-checking de CFSMs (Deniélou & Yoshida, ESOP 2012) ---
//
// Projeta cada sessão numa máquina de estados comunicante: o ESTADO é a sessão
// restante; as transições são `!` (enviar valor/rótulo) e `?` (receber). Duas
// máquinas duais comunicam por dois canais FIFO assíncronos (um por sentido).
// Explora-se EXAUSTIVAMENTE o espaço de estados global alcançável — cobertura
// que o teste aleatório (interpretador) não dá — e verifica-se:
//   · deadlock-freedom: nenhum estado alcançável fica preso (sem transições e
//     não-terminal);
//   · compatibilidade (sem receção não-especificada): a cabeça da fila casa
//     sempre com o que o recetor espera;
//   · sem órfãos: no estado terminal, as filas estão vazias.
// Para um par dual, a teoria garante tudo isto; aqui prova-se por enumeração.

#[derive(Clone, Copy, PartialEq, Eq, Hash, Debug)]
enum Move {
    Val,
    Lab(usize),
}

// Estado global: (sessão restante de M, de N, fila M→N, fila N→M).
type Gs = (Session, Session, Vec<Move>, Vec<Move>);
// Transição de um lado: (sessão-seguinte, fila de saída, fila de entrada).
type SideMove = (Session, Vec<Move>, Vec<Move>);

#[derive(Debug, PartialEq)]
enum Check {
    Ok,
    Deadlock,
    Unspecified, // receção não-especificada (viola compatibilidade/fidelidade)
    Orphan,      // terminou com mensagens por consumir
    TooBig,      // espaço de estados excedeu o limite (indício de não-terminação)
}

/// Transições de um lado com sessão `s`: envia para `out`, recebe de `inp`.
/// Devolve os pares (sessão-seguinte, out', inp') e se houve receção
/// não-especificada (cabeça da fila incompatível com o esperado).
fn side_moves(s: &Session, out: &[Move], inp: &[Move]) -> (Vec<SideMove>, bool) {
    let push = |q: &[Move], m: Move| {
        let mut v = q.to_vec();
        v.push(m);
        v
    };
    let pop = |q: &[Move]| q[1..].to_vec();
    match s {
        Session::End => (vec![], false),
        Session::Send(k) => (
            vec![((**k).clone(), push(out, Move::Val), inp.to_vec())],
            false,
        ),
        Session::Select(bs) => (
            bs.iter()
                .enumerate()
                .map(|(j, b)| (b.clone(), push(out, Move::Lab(j)), inp.to_vec()))
                .collect(),
            false,
        ),
        Session::Recv(k) => match inp.first() {
            None => (vec![], false), // bloqueado (fila vazia)
            Some(Move::Val) => (vec![((**k).clone(), out.to_vec(), pop(inp))], false),
            Some(Move::Lab(_)) => (vec![], true), // esperava valor, veio rótulo
        },
        Session::Offer(bs) => match inp.first() {
            None => (vec![], false),
            Some(Move::Lab(j)) if *j < bs.len() => {
                (vec![(bs[*j].clone(), out.to_vec(), pop(inp))], false)
            }
            Some(_) => (vec![], true), // rótulo fora do intervalo, ou veio valor
        },
    }
}

fn successors(gs: &Gs) -> (Vec<Gs>, bool) {
    let (m, n, qmn, qnm) = gs;
    let mut out = Vec::new();
    // M: envia para qmn, recebe de qnm
    let (mm, mu) = side_moves(m, qmn, qnm);
    for (m2, qmn2, qnm2) in mm {
        out.push((m2, n.clone(), qmn2, qnm2));
    }
    // N: envia para qnm, recebe de qmn
    let (nm, nu) = side_moves(n, qnm, qmn);
    for (n2, qnm2, qmn2) in nm {
        out.push((m.clone(), n2, qmn2, qnm2));
    }
    (out, mu || nu)
}

fn is_terminal(gs: &Gs) -> bool {
    gs.0 == Session::End && gs.1 == Session::End && gs.2.is_empty() && gs.3.is_empty()
}

/// Explora exaustivamente o produto das duas CFSMs a partir do estado inicial.
fn model_check(m0: &Session, n0: &Session) -> Check {
    use std::collections::HashSet;
    let mut seen: HashSet<Gs> = HashSet::new();
    let mut stack: Vec<Gs> = vec![(m0.clone(), n0.clone(), vec![], vec![])];
    while let Some(gs) = stack.pop() {
        if !seen.insert(gs.clone()) {
            continue;
        }
        if seen.len() > 500_000 {
            return Check::TooBig;
        }
        let (succs, unspecified) = successors(&gs);
        if unspecified {
            return Check::Unspecified;
        }
        if succs.is_empty() && !is_terminal(&gs) {
            // preso: ambos terminados com filas por consumir = órfão; senão deadlock
            return if gs.0 == Session::End && gs.1 == Session::End {
                Check::Orphan
            } else {
                Check::Deadlock
            };
        }
        for s in succs {
            if !seen.contains(&s) {
                stack.push(s);
            }
        }
    }
    Check::Ok
}

/// Enumera EXAUSTIVAMENTE todas as sessões até `depth` (conjunto finito).
fn enum_sessions(depth: u32) -> Vec<Session> {
    if depth == 0 {
        return vec![Session::End];
    }
    let subs = enum_sessions(depth - 1);
    let mut out = vec![Session::End];
    for s in &subs {
        out.push(Session::Send(Box::new(s.clone())));
        out.push(Session::Recv(Box::new(s.clone())));
    }
    // ramos: 1 ou 2 (o suficiente para exercitar ⊕/& sem explosão)
    for a in &subs {
        out.push(Session::Select(vec![a.clone()]));
        out.push(Session::Offer(vec![a.clone()]));
        for b in &subs {
            out.push(Session::Select(vec![a.clone(), b.clone()]));
            out.push(Session::Offer(vec![a.clone(), b.clone()]));
        }
    }
    out
}

#[test]
fn cfsm_exhaustive_dual_pairs_are_deadlock_free() {
    // TODA a sessão até profundidade 3, projetada com a sua dual, dá um sistema de
    // CFSMs sem deadlock, compatível e sem órfãos — verificado por exploração
    // EXAUSTIVA do espaço de estados (não amostragem).
    let sessions = enum_sessions(3);
    assert!(sessions.len() > 1000, "cobertura fraca: {}", sessions.len());
    for s in &sessions {
        let d = dual(s);
        assert_eq!(
            model_check(s, &d),
            Check::Ok,
            "par dual não-limpo para {s:?}"
        );
    }
}

#[test]
fn cfsm_random_large_dual_pairs_ok() {
    // complemento em PROFUNDIDADE: protocolos grandes (depth 6) aleatórios, cada
    // um exaustivamente explorado.
    for seed in 1..=2000u64 {
        let s = gen_session(&mut Rng(seed.wrapping_mul(0x9E37_79B9_7F4A_7C15) | 1), 6);
        let d = dual(&s);
        assert_eq!(model_check(&s, &d), Check::Ok, "seed {seed}: {s:?}");
    }
}

#[test]
fn cfsm_detectors_are_nonvacuous() {
    // O model-checker TEM de apanhar violações reais em pares NÃO-duais.
    let end = || Session::End;
    // ambos recebem primeiro, filas vazias → espera cíclica → deadlock
    assert_eq!(
        model_check(
            &Session::Recv(Box::new(end())),
            &Session::Recv(Box::new(end()))
        ),
        Check::Deadlock
    );
    // ambos enviam e terminam → chegam a End com filas por consumir → órfão
    assert_eq!(
        model_check(
            &Session::Send(Box::new(end())),
            &Session::Send(Box::new(end()))
        ),
        Check::Orphan
    );
    // M envia um VALOR, N faz `offer` (espera um RÓTULO) → receção não-especificada
    assert_eq!(
        model_check(
            &Session::Send(Box::new(end())),
            &Session::Offer(vec![end()])
        ),
        Check::Unspecified
    );
}

// --- diferencial superfície→ASC (valida o typechecker contra o oráculo) ---
//
// O typechecker de sessões (`check.rs`, AX0300–AX0305) foi construído por
// raciocínio + fixtures. Este diferencial ancora-o à referência: extrai a sessão
// de cada fixture ACEITE (pelo mesmo pipeline lex→layout→parse que o compilador
// usa), traduz para o `Session` do ASC, e cruza-a com o oráculo CFSM (exploração
// exaustiva de estados) — como o GHC é o oráculo da linearidade. As sessões que
// o compilador aceita têm de ser deadlock-free/compatíveis segundo a referência.

/// Cabeça e argumentos de um `ast::Type` (espinha de `App`).
fn ast_ty_spine(t: &crate::ast::Type) -> (Option<&str>, Vec<&crate::ast::Type>) {
    use crate::ast::Type;
    let mut args = Vec::new();
    let mut cur = t;
    loop {
        match cur {
            Type::App(f, a) => {
                args.push(a.as_ref());
                cur = f;
            }
            Type::Con(n) => {
                args.reverse();
                return (Some(n.as_str()), args);
            }
            _ => return (None, vec![]),
        }
    }
}

/// Traduz um tipo de sessão de superfície (`Send`/`Recv`/`End`/`Select`/`Offer`
/// com ramos `Label Cont`) para o `Session` do ASC. Espelha `check::parse_sess`.
fn from_surface_type(t: &crate::ast::Type) -> Option<Session> {
    let (h, args) = ast_ty_spine(t);
    match (h?, args.len()) {
        ("End", 0) => Some(Session::End),
        ("Send", 2) => Some(Session::Send(Box::new(from_surface_type(args[1])?))),
        ("Recv", 2) => Some(Session::Recv(Box::new(from_surface_type(args[1])?))),
        ("Select", n) if n >= 1 => Some(Session::Select(from_surface_branches(&args)?)),
        ("Offer", n) if n >= 1 => Some(Session::Offer(from_surface_branches(&args)?)),
        _ => None,
    }
}

fn from_surface_branches(args: &[&crate::ast::Type]) -> Option<Vec<Session>> {
    // o ASC abstrai os rótulos (posicional); só a continuação de cada ramo importa
    // para a compatibilidade/deadlock — o `Closed`-como-rótulo é regra do check.rs.
    args.iter()
        .map(|a| {
            let (_, bargs) = ast_ty_spine(a);
            if bargs.is_empty() {
                Some(Session::End)
            } else {
                from_surface_type(bargs[0])
            }
        })
        .collect()
}

/// Se `t` é um endpoint `Ep S` (ou `Channel`/`Chan`/`Endpoint`), devolve a sessão S.
fn endpoint_of(t: &crate::ast::Type) -> Option<&crate::ast::Type> {
    let (h, args) = ast_ty_spine(t);
    match h? {
        "Ep" | "Channel" | "Chan" | "Endpoint" if args.len() == 1 => Some(args[0]),
        _ => None,
    }
}

/// Parseia uma fixture pelo pipeline real do compilador → `Module`.
fn parse_fixture(name: &str) -> crate::ast::Module {
    let path = format!("{}/tests/fixtures/{name}", env!("CARGO_MANIFEST_DIR"));
    let src = std::fs::read_to_string(&path).expect("ler fixture");
    let tokens = crate::lexer::lex(&src).expect("lex");
    let lines = crate::lexer::LineMap::new(&src);
    let lt = crate::layout::layout(&tokens, &lines);
    crate::parser::parse_module(&lt).expect("parse")
}

#[test]
fn surface_sessions_agree_with_asc_cfsm_oracle() {
    // Para cada fixture de sessão ACEITE, toda a sessão que aparece numa
    // assinatura (extraída pelo pipeline real) é deadlock-free/compatível segundo
    // o oráculo CFSM da referência — o cruzamento superfície→ASC.
    let accepted = [
        "session_ok.axi",
        "session_recv_ok.axi",
        "session_offer_ok.axi",
        "session_select_ok.axi",
        "session_run_pingpong.axi",
        "session_run_offer.axi",
        "session_run_cancel.axi",
    ];
    let mut checked = 0;
    for fx in accepted {
        let module = parse_fixture(fx);
        for f in &module.funcs {
            let Some(sig) = &f.sig else { continue };
            for pty in sig.param_types() {
                if let Some(sess_ty) = endpoint_of(pty) {
                    let asc = from_surface_type(sess_ty)
                        .unwrap_or_else(|| panic!("{fx}: sessão não traduzível: {sess_ty:?}"));
                    assert_eq!(
                        model_check(&asc, &dual(&asc)),
                        Check::Ok,
                        "{fx}: a sessão {asc:?} que o compilador aceita NÃO é limpa no oráculo CFSM"
                    );
                    checked += 1;
                }
            }
        }
    }
    assert!(
        checked >= 4,
        "cobertura fraca do diferencial: só {checked} sessões"
    );
}
