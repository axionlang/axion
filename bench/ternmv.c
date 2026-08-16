/* `ternmv` kernel (§10): realistic ternary matvec — the hand-written C mirror of
 * Axion's tritMatVecSum. M×K packed weights (10 MB) against a small reused
 * K-activation (cache-resident); only the packed weights stream. weight(i)=(i mod
 * 3)-1, act(k)=k, N=50M, K=8192 — same result as bench/ternmv.axi. */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#define N 50000000L
#define K 8192L

static const int POW3[5] = {1, 3, 9, 27, 81};
static signed char LUT[256][5];

int main(void) {
  for (int b = 0; b < 243; b++) {
    int x = b;
    for (int k = 0; k < 5; k++) { LUT[b][k] = (signed char)((x % 3) - 1); x /= 3; }
  }
  long nb = (N + 4) / 5;
  uint8_t *w = malloc((size_t)nb); /* packed weights: 10 MB */
  for (long b = 0; b < nb; b++) {
    long base = b * 5, byte = 0;
    for (long j = 0; j < 5 && base + j < N; j++) {
      long ww = ((base + j) % 3) - 1;
      byte += (ww + 1) * POW3[j];
    }
    w[b] = (uint8_t)byte;
  }
  long *act = malloc((size_t)K * sizeof(long)); /* small activation: 64 KB */
  for (long k = 0; k < K; k++) act[k] = k;
  long acc = 0, k = 0;                           /* stream 10 MB weights, act[k] cached */
  for (long b = 0; b < nb; b++) {
    const signed char *ww = LUT[w[b]];
    long base = b * 5;
    for (long j = 0; j < 5 && base + j < N; j++) {
      acc += (long)ww[j] * act[k];
      if (++k == K) k = 0;
    }
  }
  printf("%ld\n", acc);
  free(w); free(act);
  return 0;
}
