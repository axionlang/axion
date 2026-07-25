fn sum_buf(b:&[i64])->i64{ let mut s=0i64; for &x in b { s=s.wrapping_add(x); } s }
fn main(){ let n=40000i64; let b:Vec<i64>=(0..n).collect();
  let mut s=0i64; for _ in 0..5000 { s=s.wrapping_add(sum_buf(&b)); } println!("{}", s); }
