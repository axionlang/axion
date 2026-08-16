// `i32mv` kernel: int32 matvec — hand-written Rust mirror of Axion's I32Array path.
// n int32 weights (200 MB) against a small reused K-activation. weight(i)=i,
// act(k)=k, N=50M, K=8192 — same result as bench/i32mv.rs.
const N: i64 = 50_000_000;
const K: i64 = 8192;
fn main() {
    let w: Vec<i32> = (0..N as i32).collect();
    let act: Vec<i64> = (0..K).collect();
    let mut acc: i64 = 0; let mut k: i64 = 0;
    let mut i = 0i64;
    while i < N { acc += w[i as usize] as i64 * act[k as usize]; k += 1; if k == K { k = 0; } i += 1; }
    println!("{}", acc);
}
