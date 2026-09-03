//! Arbitrary-precision integers (§ Listing 1.4: `Integer`). Sign-magnitude, base
//! 1e9 limbs (little-endian), so `to_string` is a plain per-limb print and add/sub/
//! mul are schoolbook. Enough for `factorial :: Integer -> Integer` (add, sub, mul,
//! compare, show); division is a later slice. Hand-rolled (no deps) so the same
//! representation can be mirrored in the C runtime for the native backends.

const BASE: u64 = 1_000_000_000; // 1e9 fits two limbs' product in u64

#[derive(Clone, Debug)]
pub struct BigInt {
    neg: bool,     // sign; zero is always non-negative
    mag: Vec<u32>, // base-1e9 limbs, least-significant first, no trailing zeros
}

impl BigInt {
    /// Parses a decimal string (optional leading `-`, else ASCII digits) — the path
    /// for integer literals that exceed i64. The lexer guarantees the digit shape.
    pub fn from_str(s: &str) -> Self {
        let (neg, digits) = s.strip_prefix('-').map_or((false, s), |d| (true, d));
        let mut mag = Vec::new();
        let mut i = digits.len();
        while i > 0 {
            let start = i.saturating_sub(9); // 9 digits fit a base-1e9 limb
            mag.push(
                digits
                    .get(start..i)
                    .and_then(|d| d.parse::<u32>().ok())
                    .unwrap_or(0),
            );
            i = start;
        }
        Self { neg, mag }.norm()
    }

    pub fn from_i64(n: i64) -> Self {
        let neg = n < 0;
        // handle i64::MIN without overflow by accumulating on i128
        let mut v = (n as i128).unsigned_abs();
        let mut mag = Vec::new();
        while v > 0 {
            mag.push((v % BASE as u128) as u32);
            v /= BASE as u128;
        }
        Self {
            neg: neg && !mag.is_empty(),
            mag,
        }
        .norm()
    }

    fn norm(mut self) -> Self {
        while self.mag.last() == Some(&0) {
            self.mag.pop();
        }
        if self.mag.is_empty() {
            self.neg = false;
        }
        self
    }

    pub fn is_zero(&self) -> bool {
        self.mag.is_empty()
    }

    /// Compares magnitudes only.
    fn cmp_mag(a: &[u32], b: &[u32]) -> std::cmp::Ordering {
        a.len()
            .cmp(&b.len())
            .then_with(|| a.iter().rev().cmp(b.iter().rev()))
    }

    fn add_mag(a: &[u32], b: &[u32]) -> Vec<u32> {
        let mut out = Vec::with_capacity(a.len().max(b.len()) + 1);
        let mut carry = 0u64;
        for i in 0..a.len().max(b.len()) {
            let s = carry
                + a.get(i).copied().unwrap_or(0) as u64
                + b.get(i).copied().unwrap_or(0) as u64;
            out.push((s % BASE) as u32);
            carry = s / BASE;
        }
        if carry > 0 {
            out.push(carry as u32);
        }
        out
    }

    /// `a - b`, assuming `a >= b` (magnitudes).
    fn sub_mag(a: &[u32], b: &[u32]) -> Vec<u32> {
        let mut out = Vec::with_capacity(a.len());
        let mut borrow = 0i64;
        for (i, &ai) in a.iter().enumerate() {
            let mut d = ai as i64 - borrow - b.get(i).copied().unwrap_or(0) as i64;
            if d < 0 {
                d += BASE as i64;
                borrow = 1;
            } else {
                borrow = 0;
            }
            out.push(d as u32);
        }
        out
    }

    pub fn add(&self, o: &BigInt) -> BigInt {
        if self.neg == o.neg {
            BigInt {
                neg: self.neg,
                mag: Self::add_mag(&self.mag, &o.mag),
            }
            .norm()
        } else {
            match Self::cmp_mag(&self.mag, &o.mag) {
                std::cmp::Ordering::Equal => BigInt {
                    neg: false,
                    mag: Vec::new(),
                },
                std::cmp::Ordering::Greater => BigInt {
                    neg: self.neg,
                    mag: Self::sub_mag(&self.mag, &o.mag),
                }
                .norm(),
                std::cmp::Ordering::Less => BigInt {
                    neg: o.neg,
                    mag: Self::sub_mag(&o.mag, &self.mag),
                }
                .norm(),
            }
        }
    }

    pub fn sub(&self, o: &BigInt) -> BigInt {
        self.add(&o.negated())
    }

    fn negated(&self) -> BigInt {
        BigInt {
            neg: !self.neg && !self.is_zero(),
            mag: self.mag.clone(),
        }
    }

    pub fn mul(&self, o: &BigInt) -> BigInt {
        if self.is_zero() || o.is_zero() {
            return BigInt {
                neg: false,
                mag: Vec::new(),
            };
        }
        let mut mag = vec![0u64; self.mag.len() + o.mag.len()];
        for (i, &x) in self.mag.iter().enumerate() {
            let mut carry = 0u64;
            for (j, &y) in o.mag.iter().enumerate() {
                let cur = mag[i + j] + x as u64 * y as u64 + carry;
                mag[i + j] = cur % BASE;
                carry = cur / BASE;
            }
            mag[i + o.mag.len()] += carry;
        }
        BigInt {
            neg: self.neg != o.neg,
            mag: mag.into_iter().map(|l| l as u32).collect(),
        }
        .norm()
    }

    pub fn cmp(&self, o: &BigInt) -> std::cmp::Ordering {
        use std::cmp::Ordering::{Greater, Less};
        match (self.neg, o.neg) {
            (false, true) => Greater,
            (true, false) => Less,
            (false, false) => Self::cmp_mag(&self.mag, &o.mag),
            (true, true) => Self::cmp_mag(&o.mag, &self.mag),
        }
    }

    /// Truncated division: `(quotient toward zero, remainder with the dividend's
    /// sign)` — matches Rust/C `/` and `%` (so interp and native agree). `None` if
    /// the divisor is zero. Long division base 1e9, each quotient digit found by
    /// binary search (≤30 multiply-compares); O(n·m·30).
    pub fn divmod(&self, o: &BigInt) -> Option<(BigInt, BigInt)> {
        use std::cmp::Ordering::{Greater, Less};
        if o.is_zero() {
            return None;
        }
        if Self::cmp_mag(&self.mag, &o.mag) == Less {
            return Some((
                BigInt {
                    neg: false,
                    mag: Vec::new(),
                },
                self.clone(),
            ));
        }
        let babs = BigInt {
            neg: false,
            mag: o.mag.clone(),
        };
        let base = BigInt::from_i64(BASE as i64);
        let mut q = vec![0u32; self.mag.len()];
        let mut r = BigInt {
            neg: false,
            mag: Vec::new(),
        };
        for i in (0..self.mag.len()).rev() {
            // bring down the next digit: r = r * BASE + self.mag[i]
            r = r.mul(&base).add(&BigInt::from_i64(i64::from(self.mag[i])));
            // largest digit d with babs*d <= r
            let (mut lo, mut hi, mut d) = (0i64, BASE as i64 - 1, 0i64);
            while lo <= hi {
                let mid = lo + (hi - lo) / 2;
                if babs.mul(&BigInt::from_i64(mid)).cmp(&r) == Greater {
                    hi = mid - 1;
                } else {
                    d = mid;
                    lo = mid + 1;
                }
            }
            q[i] = d as u32;
            r = r.sub(&babs.mul(&BigInt::from_i64(d)));
        }
        let quo = BigInt {
            neg: self.neg != o.neg,
            mag: q,
        }
        .norm();
        let rem = BigInt {
            neg: self.neg,
            mag: r.mag,
        }
        .norm();
        Some((quo, rem))
    }
}

impl std::fmt::Display for BigInt {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        if self.mag.is_empty() {
            return write!(f, "0");
        }
        if self.neg {
            write!(f, "-")?;
        }
        // most-significant limb without padding, the rest zero-padded to 9 digits
        for (i, limb) in self.mag.iter().rev().enumerate() {
            if i == 0 {
                write!(f, "{limb}")?;
            } else {
                write!(f, "{limb:09}")?;
            }
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::BigInt;
    fn b(n: i64) -> BigInt {
        BigInt::from_i64(n)
    }
    fn s(x: &BigInt) -> String {
        x.to_string()
    }
    #[test]
    fn arithmetic_and_divmod() {
        assert_eq!(
            s(&b(1_000_000_000).mul(&b(1_000_000_000))),
            "1000000000000000000"
        );
        assert_eq!(s(&b(7).sub(&b(10))), "-3");
        // factorial 25 by mul, then divide back down
        let mut f = b(1);
        for i in 2..=25 {
            f = f.mul(&b(i));
        }
        assert_eq!(s(&f), "15511210043330985984000000");
        let (q, r) = f.divmod(&b(24)).unwrap();
        // 25! / 24 : exact, remainder 0
        assert_eq!(s(&r), "0");
        assert_eq!(s(&q.mul(&b(24))), s(&f));
        // 100 /% 7 = (14, 2); truncation toward zero for negatives
        let (q, r) = b(100).divmod(&b(7)).unwrap();
        assert_eq!((s(&q), s(&r)), ("14".into(), "2".into()));
        let (q, r) = b(-100).divmod(&b(7)).unwrap();
        assert_eq!((s(&q), s(&r)), ("-14".into(), "-2".into()));
        assert!(b(5).divmod(&b(0)).is_none());
    }
    #[test]
    fn from_str_roundtrips() {
        for lit in ["0", "42", "12345678901234567890", "999999999000000000123"] {
            assert_eq!(BigInt::from_str(lit).to_string(), lit);
        }
        // a big literal times itself, exact
        let x = BigInt::from_str("12345678901234567890");
        assert_eq!(s(&x.mul(&x)), "152415787532388367501905199875019052100");
    }
}
