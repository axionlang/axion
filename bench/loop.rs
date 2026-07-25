fn inner(mut acc:i64, mut n:i64)->i64{ while n!=0 { acc=(acc+n.wrapping_mul(n))%2147483647; n-=1; } acc }
fn outer(mut acc:i64, mut k:i64)->i64{ while k!=0 { acc=acc.wrapping_add(inner(k,50000)); k-=1; } acc }
fn main(){ println!("{}", outer(0,4000)); }
