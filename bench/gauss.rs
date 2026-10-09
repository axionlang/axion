// Dense Gaussian elimination with partial pivoting over Vec<f64>, solving an N*N system `reps`
// times — the Rust comparison tier for bench/gauss.axi. Same fixed diagonally-dominant integer
// matrix, same per-iteration true solution, same integer checksum.
fn a_entry(n: i64, i: i64, j: i64) -> f64 {
    if i == j { (4 * n) as f64 } else { (((i * 7 + j * 13) % 3) + 1) as f64 }
}
fn x_true(iter: i64, j: i64) -> f64 { (((iter + j) % 7) + 1) as f64 }

fn solve_one(n: usize, iter: i64) -> i64 {
    let w = n + 1;
    let mut m = vec![0.0f64; n * w];
    let mut x = vec![0.0f64; n];
    for i in 0..n {
        for j in 0..n {
            m[i * w + j] = a_entry(n as i64, i as i64, j as i64);
        }
        let mut b = 0.0;
        for j in 0..n {
            b += a_entry(n as i64, i as i64, j as i64) * x_true(iter, j as i64);
        }
        m[i * w + n] = b;
    }
    for k in 0..n {
        let mut p = k;
        for i in k..n {
            if m[i * w + k].abs() > m[p * w + k].abs() {
                p = i;
            }
        }
        for j in 0..=n {
            m.swap(k * w + j, p * w + j);
        }
        for i in (k + 1)..n {
            let factor = m[i * w + k] / m[k * w + k];
            for j in k..=n {
                m[i * w + j] -= factor * m[k * w + j];
            }
        }
    }
    for i in (0..n).rev() {
        let mut s = m[i * w + n];
        for j in (i + 1)..n {
            s -= m[i * w + j] * x[j];
        }
        x[i] = s / m[i * w + i];
    }
    let mut acc: i64 = 0;
    for i in 0..n {
        acc += (x[i] + 0.5) as i64;
    }
    acc
}

fn main() {
    let n: usize = 64;
    let reps: i64 = 1500;
    let mut acc: i64 = 0;
    for iter in 0..reps {
        acc += solve_one(n, iter);
    }
    println!("{}", acc);
}
