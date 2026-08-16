// `ternmv` kernel (§10): realistic ternary matvec — the hand-written Rust mirror of
// Axion's tritMatVecSum. M×K packed weights (10 MB) against a small reused
// K-activation (cache-resident); only the packed weights stream. weight(i)=(i mod
// 3)-1, act(k)=k, N=50M, K=8192 — same result as bench/ternmv.rs.
const N: i64 = 50_000_000;
const K: i64 = 8192;
const POW3: [i64; 5] = [1, 3, 9, 27, 81];

const LUT: [[i8; 5]; 256] = {
    let mut t = [[0i8; 5]; 256];
    let mut b = 0;
    while b < 243 {
        let (mut x, mut k) = (b, 0);
        while k < 5 {
            t[b][k] = (x % 3) as i8 - 1;
            x /= 3;
            k += 1;
        }
        b += 1;
    }
    t
};

fn main() {
    let nb = ((N + 4) / 5) as usize;
    let mut w = vec![0u8; nb]; // packed weights: 10 MB
    let mut b = 0usize;
    while b < nb {
        let base = (b * 5) as i64;
        let mut byte: i64 = 0;
        let mut j = 0i64;
        while j < 5 && base + j < N {
            let ww = ((base + j) % 3) - 1;
            byte += (ww + 1) * POW3[j as usize];
            j += 1;
        }
        w[b] = byte as u8;
        b += 1;
    }
    let act: Vec<i64> = (0..K).collect(); // small activation: 64 KB
    let mut acc: i64 = 0;
    let mut k: i64 = 0; // stream 10 MB weights, act[k] cached
    let mut b2: i64 = 0;
    while b2 < nb as i64 {
        let ww = &LUT[w[b2 as usize] as usize];
        let base = b2 * 5;
        let mut j = 0i64;
        while j < 5 && base + j < N {
            acc += ww[j as usize] as i64 * act[k as usize];
            k += 1;
            if k == K {
                k = 0;
            }
            j += 1;
        }
        b2 += 1;
    }
    println!("{}", acc);
}
