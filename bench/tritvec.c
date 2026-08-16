/* `tritvec` kernel (§10): ternary-quantized dot product over a base-243 packed
 * TritVec — the hand-written C mirror of Axion's bulk path. Weights are packed
 * the FAST way (each byte written once from its 5 digits, no per-trit
 * read-modify-write), activations filled a[i]=i, and the reduce fuses 5 trits/byte
 * via the LUT. weight(i)=(i mod 3)-1, a[i]=i, N=50M — same result as bench/tritvec.axi. */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#define N 50000000L

static const int POW3[5] = {1, 3, 9, 27, 81};
static signed char LUT[256][5];

int main(void) {
  for (int b = 0; b < 243; b++) {
    int x = b;
    for (int k = 0; k < 5; k++) { LUT[b][k] = (signed char)((x % 3) - 1); x /= 3; }
  }
  long nb = (N + 4) / 5;
  uint8_t *w = malloc((size_t)nb);          /* packed weights, one write per byte */
  for (long b = 0; b < nb; b++) {
    long base = b * 5, byte = 0;
    for (long k = 0; k < 5 && base + k < N; k++) {
      long ww = ((base + k) % 3) - 1;
      byte += (ww + 1) * POW3[k];
    }
    w[b] = (uint8_t)byte;
  }
  long *act = malloc((size_t)N * sizeof(long));
  for (long i = 0; i < N; i++) act[i] = i; /* activations a[i]=i */
  long acc = 0;                             /* fused: 5 trits/byte, MAC in one pass */
  for (long b = 0; b < nb; b++) {
    const signed char *ww = LUT[w[b]];
    long base = b * 5;
    if (base + 5 <= N) {
      acc += (long)ww[0] * act[base] + (long)ww[1] * act[base + 1]
           + (long)ww[2] * act[base + 2] + (long)ww[3] * act[base + 3]
           + (long)ww[4] * act[base + 4];
    } else {
      for (long k = 0; base + k < N; k++) acc += (long)ww[k] * act[base + k];
    }
  }
  printf("%ld\n", acc);
  free(w); free(act);
  return 0;
}
