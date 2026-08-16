// `tritvec` kernel (§10): ternary-quantized dot product over a base-243 packed
// TritVec — the hand-written Rust mirror of Axion's bulk path. Weights are packed
// the FAST way (each byte written once from its 5 digits, no per-trit
// read-modify-write), activations filled a[i]=i, and the reduce fuses 5 trits/byte
// via the LUT. weight(i)=(i mod 3)-1, a[i]=i, N=50M — same result as bench/tritvec.rs.
const N: i64 = 50_000_000;
const POW3: [i64; 5] = [1, 3, 9, 27, 81];

const LUT: [[i8; 5]; 256] = {
    let mut t = [[0i8; 5]; 256];
    let mut b = 0;
    while b < 243 {
        let (mut x, mut k) = (b, 0);
        while k < 5 {
            t[b][k] = (x % 3) as i8 - 1;
            x /= 3;
            k += 1;
        }
        b += 1;
    }
    t
};

fn main() {
    let nb = ((N + 4) / 5) as usize;
    let mut w = vec![0u8; nb]; // packed weights, one write per byte
    let mut b = 0usize;
    while b < nb {
        let base = (b * 5) as i64;
        let mut byte: i64 = 0;
        let mut k = 0i64;
        while k < 5 && base + k < N {
            let ww = ((base + k) % 3) - 1;
            byte += (ww + 1) * POW3[k as usize];
            k += 1;
        }
        w[b] = byte as u8;
        b += 1;
    }
    let mut act = vec![0i64; N as usize];
    let mut i = 0i64;
    while i < N {
        act[i as usize] = i; // activations a[i]=i
        i += 1;
    }
    let mut acc: i64 = 0; // fused: 5 trits/byte, MAC in one pass
    let mut b2: i64 = 0;
    while b2 < nb as i64 {
        let ww = &LUT[w[b2 as usize] as usize];
        let base = b2 * 5;
        if base + 5 <= N {
            acc += ww[0] as i64 * act[base as usize]
                + ww[1] as i64 * act[(base + 1) as usize]
                + ww[2] as i64 * act[(base + 2) as usize]
                + ww[3] as i64 * act[(base + 3) as usize]
                + ww[4] as i64 * act[(base + 4) as usize];
        } else {
            let mut k = 0i64;
            while base + k < N {
                acc += ww[k as usize] as i64 * act[(base + k) as usize];
                k += 1;
            }
        }
        b2 += 1;
    }
    println!("{}", acc);
}
