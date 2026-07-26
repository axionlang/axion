//! Property tests **generativos** das análises de memória (Auto-Drop §2).
//!
//! Gera programas lineares aleatórios (registos planos, leituras de campo,
//! empréstimos, moves `%1`, `if`/`let`, aritmética) — o fragmento *totalmente
//! reclamável* — e, para cada um, exige três invariantes no backend nativo:
//!
//!   1. **Sem corrupção:** o `--backend cranelift` compila e corre sem crashar
//!      (um uso-após-livre/dupla-free rebentaria).
//!   2. **Sem fugas / dupla-free:** `AXION_HEAP_STATS` dá `allocs == frees` —
//!      cada registo alocado é libertado exactamente uma vez.
//!   3. **Concordância de executores:** o resultado nativo == o do interpretador.
//!
//! Cobre exactamente as análises endurecidas (empréstimo puro `BorrowArgs`, Drop
//! estrutural, equilíbrio de `if`/`case`, reclamação entre funções). O fragmento
//! evita de propósito o que ainda vaza por opção conservadora (registos
//! aninhados, `show`, closures devolvidas) — ver docs/backend.md.

use std::process::Command;

fn axionc() -> Command {
    Command::new(env!("CARGO_BIN_EXE_axionc"))
}

/// PRNG determinístico (xorshift64*), sem dependências — igual ao de `props.rs`.
struct Gen {
    state: u64,
    fresh: u32,
}

impl Gen {
    fn next_u64(&mut self) -> u64 {
        let mut x = self.state;
        x ^= x >> 12;
        x ^= x << 25;
        x ^= x >> 27;
        self.state = x;
        x.wrapping_mul(0x2545_F491_4F6C_DD1D)
    }

    fn below(&mut self, n: u32) -> u32 {
        (self.next_u64() % n as u64) as u32
    }

    fn fresh_name(&mut self, prefix: char) -> String {
        let n = self.fresh;
        self.fresh += 1;
        format!("{prefix}{n}")
    }

    /// Uma expressão de tipo `Int`, bem-tipada e totalmente reclamável, no
    /// ambiente dado (`ints`/`ps` = variáveis Int / de registo `P` em escopo).
    fn int_expr(&mut self, depth: u32, ints: &[String], ps: &[String]) -> String {
        // folha: com prob. alta perto do fundo
        if depth == 0 || self.below(100) < 35 {
            return self.leaf(ints, ps);
        }
        match self.below(6) {
            0 => {
                let op = ["+", "-", "*"][self.below(3) as usize];
                let l = self.int_expr(depth - 1, ints, ps);
                let r = self.int_expr(depth - 1, ints, ps);
                format!("({l} {op} {r})")
            }
            1 => {
                let cmp = ["<", ">", "=="][self.below(3) as usize];
                let cl = self.int_expr(depth - 1, ints, ps);
                let cr = self.int_expr(depth - 1, ints, ps);
                let th = self.int_expr(depth - 1, ints, ps);
                let el = self.int_expr(depth - 1, ints, ps);
                format!("(if {cl} {cmp} {cr} then {th} else {el})")
            }
            2 => {
                // let-Int: liga um novo Int e continua
                let e = self.int_expr(depth - 1, ints, ps);
                let name = self.fresh_name('x');
                let mut ints2 = ints.to_vec();
                ints2.push(name.clone());
                let body = self.int_expr(depth - 1, &ints2, ps);
                format!("(let {name} = {e} in {body})")
            }
            3 => {
                // let-P: aloca um registo plano e continua (pode lê-lo/emprestá-lo
                // ou não — Auto-Drop reclama-o de qualquer forma)
                let ea = self.int_expr(depth - 1, ints, ps);
                let eb = self.int_expr(depth - 1, ints, ps);
                let name = self.fresh_name('p');
                let mut ps2 = ps.to_vec();
                ps2.push(name.clone());
                let body = self.int_expr(depth - 1, ints, &ps2);
                format!("(let {name} = P {{ a = {ea}, b = {eb} }} in {body})")
            }
            4 if !ps.is_empty() => {
                // chamada que empresta um registo em escopo
                let f = ["sumP", "fstP"][self.below(2) as usize];
                let p = &ps[self.below(ps.len() as u32) as usize];
                format!("({f} {p})")
            }
            _ => {
                // move: constrói um registo fresco e consome-o (%1 → o callee liberta)
                let ea = self.int_expr(depth - 1, ints, ps);
                let eb = self.int_expr(depth - 1, ints, ps);
                format!("(useP (P {{ a = {ea}, b = {eb} }}))")
            }
        }
    }

    fn leaf(&mut self, ints: &[String], ps: &[String]) -> String {
        let mut choices = 1u32; // literal
        if !ints.is_empty() {
            choices += 1;
        }
        if !ps.is_empty() {
            choices += 1;
        }
        match self.below(choices) {
            0 => format!("{}", self.below(20)),
            1 if !ints.is_empty() => ints[self.below(ints.len() as u32) as usize].clone(),
            _ => {
                let field = if self.below(2) == 0 { "a" } else { "b" };
                let p = &ps[self.below(ps.len() as u32) as usize];
                format!("({field} {p})")
            }
        }
    }
}

/// Prelúdio fixo: um registo plano + leitores que o emprestam + um consumidor `%1`.
const PRELUDE: &str = "\
data P = P { a :: Int, b :: Int }
sumP :: P -> Int
sumP p = a p + b p
fstP :: P -> Int
fstP p = a p
useP :: P %1 -> Int
useP p = a p + b p
main :: Int
main = ";

fn program(seed: u64) -> String {
    let mut g = Gen {
        state: seed | 1,
        fresh: 0,
    };
    let body = g.int_expr(5, &[], &[]);
    format!("{PRELUDE}{body}\n")
}

#[test]
fn generated_linear_programs_reclaim_exactly() {
    let dir = std::env::temp_dir().join(format!("axion-propmem-{}", std::process::id()));
    std::fs::create_dir_all(&dir).unwrap();

    let n = 300u64;
    for seed in 1..=n {
        let src = program(seed.wrapping_mul(0x9E37_79B9_7F4A_7C15));
        let path = dir.join(format!("g{seed}.axi"));
        std::fs::write(&path, &src).unwrap();
        let p = path.to_str().unwrap();

        // nativo (--dev) com contadores de heap
        let native = axionc()
            .args(["--backend", "cranelift", p])
            .env("AXION_HEAP_STATS", "1")
            .output()
            .unwrap();
        assert!(
            native.status.success(),
            "seed {seed}: nativo falhou (possível corrupção)\n--- programa ---\n{src}\n--- stderr ---\n{}",
            String::from_utf8_lossy(&native.stderr)
        );
        let nres = String::from_utf8_lossy(&native.stdout).trim().to_string();
        let stats = String::from_utf8_lossy(&native.stderr);
        let line = stats
            .lines()
            .find(|l| l.contains("heap:"))
            .unwrap_or_else(|| panic!("seed {seed}: sem stats de heap"));
        // "heap: N allocs, M frees"
        let nums: Vec<u64> = line
            .split(|c: char| !c.is_ascii_digit())
            .filter(|s| !s.is_empty())
            .map(|s| s.parse().unwrap())
            .collect();
        assert_eq!(
            nums[0], nums[1],
            "seed {seed}: fuga/dupla-free ({} allocs != {} frees)\n{src}",
            nums[0], nums[1]
        );

        // concordância com o interpretador
        let interp = axionc().arg(p).output().unwrap();
        assert!(interp.status.success(), "seed {seed}: interp falhou\n{src}");
        let ires = String::from_utf8_lossy(&interp.stdout).trim().to_string();
        assert_eq!(
            nres, ires,
            "seed {seed}: nativo={nres} != interp={ires}\n{src}"
        );
    }
    let _ = std::fs::remove_dir_all(&dir);
}
