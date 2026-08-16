/* `i8mv` kernel (Phase B): int8 matvec baseline — the hand-written C mirror of
 * Axion's I8Array path. n int8 weights (50 MB) against a small reused
 * K-activation (cache-resident); only the int8 weights stream. weight(i)=(i mod
 * 3)-1, act(k)=k, N=50M, K=8192 — same result as bench/i8mv.axi. */
#include <stdio.h>
#include <stdlib.h>

#define N 50000000L
#define K 8192L

int main(void) {
  signed char *w = malloc((size_t)N);          /* int8 weights: 50 MB */
  for (long i = 0; i < N; i++) w[i] = (signed char)((i % 3) - 1);
  long *act = malloc((size_t)K * sizeof(long)); /* small activation: 64 KB */
  for (long k = 0; k < K; k++) act[k] = k;
  long acc = 0, k = 0;                          /* stream 50 MB weights, act[k] cached */
  for (long i = 0; i < N; i++) {
    acc += (long)w[i] * act[k];
    if (++k == K) k = 0;
  }
  printf("%ld\n", acc);
  free(w); free(act);
  return 0;
}
