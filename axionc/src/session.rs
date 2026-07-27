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

#[derive(Clone, Debug, PartialEq)]
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
