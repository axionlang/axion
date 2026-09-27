// Load generator for the echo-server benchmark. Opens N concurrent KEEP-ALIVE connections; each
// does R request/echo round-trips of a fixed message; records per-request latency. Reports
// throughput (echoes/sec over wall time) and p50/p99 latency. Identical client for all four
// servers, so the comparison is apples-to-apples. Usage: loadgen <port> <N> <R> [msgbytes]
use std::io::{Read, Write};
use std::net::TcpStream;
use std::time::Instant;

fn main() {
    let a: Vec<String> = std::env::args().collect();
    let port: u16 = a[1].parse().unwrap();
    let n: usize = a.get(2).and_then(|s| s.parse().ok()).unwrap_or(50);
    let r: usize = a.get(3).and_then(|s| s.parse().ok()).unwrap_or(200);
    let sz: usize = a.get(4).and_then(|s| s.parse().ok()).unwrap_or(32);
    let msg = vec![b'x'; sz];

    let start = Instant::now();
    let handles: Vec<_> = (0..n)
        .map(|_| {
            let msg = msg.clone();
            std::thread::spawn(move || {
                let mut lat = Vec::with_capacity(r);
                let mut s = TcpStream::connect(("127.0.0.1", port)).expect("connect");
                s.set_nodelay(true).ok();
                let mut buf = vec![0u8; msg.len()];
                for _ in 0..r {
                    let t = Instant::now();
                    s.write_all(&msg).expect("write");
                    s.read_exact(&mut buf).expect("read"); // echo returns exactly msg.len() bytes
                    lat.push(t.elapsed().as_micros() as u64);
                }
                lat
            })
        })
        .collect();

    let mut all = Vec::new();
    for h in handles {
        all.extend(h.join().expect("join"));
    }
    let elapsed = start.elapsed().as_secs_f64();
    all.sort_unstable();
    let total = all.len();
    let pct = |q: f64| all[(((total as f64) * q) as usize).min(total - 1)];
    // machine-parseable one-liner.
    println!(
        "THROUGHPUT {:.0} P50 {} P99 {} TOTAL {} ELAPSED {:.3}",
        total as f64 / elapsed,
        pct(0.50),
        pct(0.99),
        total,
        elapsed
    );
}
