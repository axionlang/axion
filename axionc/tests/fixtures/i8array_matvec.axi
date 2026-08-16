-- I8Array (Phase B): a compact SIGNED-BYTE array (1 byte/elem vs Array's 8), the
-- dense int8 counterpart to TritVec. i8Iota builds ternary weights as bytes;
-- i8MatVecSum runs the int8 matvec against a small reused K-activation (streams
-- the int8 weights). Same numbers as the packed matvec (weight(i)=(i mod 3)-1,
-- act(k)=k, N=10, K=4) → -3. Both operands Auto-Dropped once.
main :: Int
main = i8MatVecSum (i8Iota 10) (arrayIota 4) 4
