// `i8mv` kernel (Phase B): int8 matvec baseline — the hand-written Rust mirror of
// Axion's I8Array path. n int8 weights (50 MB) against a small reused
// K-activation (cache-resident); only the int8 weights stream. weight(i)=(i mod
// 3)-1, act(k)=k, N=50M, K=8192 — same result as bench/i8mv.axi.
const N: i64 = 50_000_000;
const K: i64 = 8192;

fn main() {
    let mut w = vec![0i8; N as usize]; // int8 weights: 50 MB
    let mut i = 0i64;
    while i < N {
        w[i as usize] = ((i % 3) - 1) as i8;
        i += 1;
    }
    let act: Vec<i64> = (0..K).collect(); // small activation: 64 KB
    let mut acc: i64 = 0;
    let mut k: i64 = 0; // stream 50 MB weights, act[k] cached
    i = 0;
    while i < N {
        acc += w[i as usize] as i64 * act[k as usize];
        k += 1;
        if k == K {
            k = 0;
        }
        i += 1;
    }
    println!("{}", acc);
}
