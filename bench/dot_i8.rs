// `dot_i8` kernel: fair dense int8 dot — two stored int8 arrays (~50 MB each),
// the hand-written Rust mirror of Axion's i8DotI8. weight(i)=(i mod 3)-1 for both
// → sum of squares = 33333333. N=50M.
const N: i64 = 50_000_000;
fn main() {
    let mut a = vec![0i8; N as usize];
    let mut b = vec![0i8; N as usize];
    let mut i = 0i64;
    while i < N { let w = ((i % 3) - 1) as i8; a[i as usize] = w; b[i as usize] = w; i += 1; }
    let mut s: i64 = 0;
    i = 0;
    while i < N { s += a[i as usize] as i64 * b[i as usize] as i64; i += 1; }
    println!("{}", s);
}
