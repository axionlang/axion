fn main(){ let a:[i64;1024]=std::array::from_fn(|i| i as i64);
  let mut s=0i64; for _ in 0..2000000 { for i in 0..1024 { s=s.wrapping_add(a[i]); } }
  println!("{}", s); }
