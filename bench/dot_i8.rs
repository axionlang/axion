// `dot_i8` kernel: the SAME ternary-quantized dot product as `tritvec`, but in the
// representation a Rust programmer would actually pick — a dense `Vec<i8>` (1 byte
// per weight, no packing, no unpack). The honest "real world" baseline: on raw
// speed this beats every packed form; it costs 5× the memory of base-243. Weights
// w(i)=(i mod 3)-1, activations a(i)=(i mod 7)-3, N=50M — same result as tritvec.
const N: i64 = 50_000_000;

fn main() {
    let mut w: Vec<i8> = vec![0; N as usize]; // 1 byte per weight
    let mut i: i64 = 0;
    while i < N {
        w[i as usize] = ((i % 3) - 1) as i8;
        i += 1;
    }
    let mut acc: i64 = 0;
    i = 0;
    while i < N {
        acc += w[i as usize] as i64 * ((i % 7) - 3);
        i += 1;
    }
    println!("{}", acc);
}
