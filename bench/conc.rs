// Concurrency benchmark (Rust, std::thread) — the fork-join baseline: 4 workers
// each compute fib(N), the parent sums. `conc N T`: T<=1 runs them sequentially
// (the 1-thread baseline), else one std::thread per worker. Same workload as
// bench/conc.c and bench/conc.axi. Naive fib so the compute dominates.
use std::thread;

fn fib(n: i64) -> i64 {
    if n < 2 {
        n
    } else {
        fib(n - 1) + fib(n - 2)
    }
}

fn main() {
    let a: Vec<String> = std::env::args().collect();
    let n: i64 = a.get(1).and_then(|s| s.parse().ok()).unwrap_or(34);
    let t: usize = a.get(2).and_then(|s| s.parse().ok()).unwrap_or(4);
    // `black_box` so the optimizer cannot hoist/CSE the four `fib(n)` calls in the
    // sequential path (they must each really run, like the four session workers).
    let sum: i64 = if t <= 1 {
        (0..4).map(|_| fib(std::hint::black_box(n))).sum()
    } else {
        let hs: Vec<_> = (0..4)
            .map(|_| thread::spawn(move || fib(std::hint::black_box(n))))
            .collect();
        hs.into_iter().map(|h| h.join().unwrap()).sum()
    };
    println!("{sum}");
}
