// Genérico via trait — o Rust monomorfiza (o mesmo mecanismo que a Axión).
trait Stepper { fn step(self) -> Self; }
impl Stepper for i64 { fn step(self) -> i64 { (self + 7) % 1000000 } }
fn inner<T: Stepper + Copy>(mut x: T, mut n: i64) -> T { while n > 0 { x = x.step(); n -= 1; } x }
fn outer(mut acc: i64, mut k: i64) -> i64 {
    while k > 0 { acc = (acc + inner(k, 50000)) % 2147483647; k -= 1; }
    acc
}
fn main() { println!("{}", outer(0, 4000)); }
