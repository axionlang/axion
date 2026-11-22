fn dot(x: &[f64], y: &[f64]) -> f64 { let mut s = 0.0; for i in 0..x.len() { s += x[i] * y[i]; } s }
fn main() { let n = 4096usize;
  let x: Vec<f64> = (0..n).map(|i| (i % 7) as f64).collect();
  let y: Vec<f64> = (0..n).map(|i| (i % 5) as f64).collect();
  let mut t = 0.0; for _ in 0..20000 { t += dot(&x, &y); } println!("{}", t as i64); }
