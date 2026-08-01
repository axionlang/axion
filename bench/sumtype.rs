#[derive(Clone, Copy)]
enum Dir { North, East, South, West }
fn turn(d: Dir) -> Dir { match d { Dir::North=>Dir::East, Dir::East=>Dir::South, Dir::South=>Dir::West, Dir::West=>Dir::North } }
fn val(d: Dir) -> i64 { match d { Dir::North=>0, Dir::East=>1, Dir::South=>2, Dir::West=>3 } }
fn from_int(n: i64) -> Dir { match n % 4 { 0=>Dir::North, 1=>Dir::East, 2=>Dir::South, _=>Dir::West } }
fn inner(mut d: Dir, mut acc: i64, mut n: i64) -> i64 { while n != 0 { acc = (acc + val(d)) % 1000000; d = turn(d); n -= 1; } acc }
fn main() { let mut acc: i64 = 0; let mut k: i64 = 4000; while k != 0 { acc = (acc + inner(from_int(k), 0, 50000)) % 2147483647; k -= 1; } println!("{}", acc); }
