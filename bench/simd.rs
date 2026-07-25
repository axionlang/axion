fn sum_buf(b:&[u8])->i64{ let mut s=0i64; for &x in b { s+=x as i64; } s }
fn main(){ let n=40000usize; let b:Vec<u8>=(0..n).map(|i|(i&0xFF) as u8).collect();
  let mut s=0i64; for _ in 0..5000 { s+=sum_buf(&b); } println!("{}", s); }
