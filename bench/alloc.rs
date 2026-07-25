fn alloc_n(n:i64)->i64{ let mut s=0; let mut n=n; while n!=0 { let b=Box::new([0u8;16]); std::hint::black_box(&b); s+=1; n-=1; } s }
fn main(){ let mut s=0i64; for _ in 0..2000 { s+=alloc_n(20000); } println!("{}", s); }
