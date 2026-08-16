/* TritVec decision benchmark (spec §10.B/§14 #07, roadmap Phase 5a gate).
 *
 * The spec is emphatic: base-243 packing (5 trits/byte, 99.1% density) is only
 * worth its radix-3 unpack cost when the workload is genuinely memory-bandwidth
 * bound — the concrete case being ternary-quantized ML weight arrays {-1,0,+1}.
 * MEASURE before committing further (SIMD codecs, default-on).
 *
 * This compares three representations of the SAME N ternary weights, each driving
 * one quantized dot-product  sum_i w_i * a_i  (w_i ∈ {-1,0,+1}, a_i an int8-ish
 * activation).  All three produce the identical sum (correctness gate):
 *
 *   1. base-243/divmod : 5 trits/byte, per-trit radix-3 div/mod.        0.20 B/trit.
 *   2. base-243/LUT-256: 5 trits/byte, byte→5-weights table (§10.C, the
 *                        codec axionc ships). Same footprint, ~2× faster decode.
 *   3. 2-bit           : 1 trit per 2 bits, pure shifts, no radix conv.  0.25 B/trit.
 *   4. 1-byte          : 1 int8 per trit (loose `Array Trit`).           1.00 B/trit.
 *
 * The tradeoff the spec names: 243 has the smallest footprint (fewest cache
 * misses) but the most expensive unpack (div/mod by powers of 3); 1-byte has no
 * unpack but 5× the memory traffic.  Which wins is an empirical question of N vs
 * cache size — exactly what this measures.
 *
 * Build:  clang -O2 bench/tritvec_codec.c -o /tmp/tvbench && /tmp/tvbench
 */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

static const int POW3[5] = {1, 3, 9, 27, 81};

static double now_ms(void) {
  struct timespec t;
  clock_gettime(CLOCK_MONOTONIC, &t);
  return t.tv_sec * 1e3 + t.tv_nsec / 1e6;
}

/* deterministic ternary weight for index i: cycles -1,0,+1,+1,0,-1,… */
static int weight_of(long i) { return (int)(i % 3) - 1; }

int main(int argc, char **argv) {
  long n = (argc > 1) ? atol(argv[1]) : 64L * 1024 * 1024; /* 64M weights */
  int reps = (argc > 2) ? atoi(argv[2]) : 5;

  /* activations: a fixed small int per lane (shared by all three kernels). */
  int8_t *act = malloc((size_t)n);
  for (long i = 0; i < n; i++) act[i] = (int8_t)((i % 7) - 3);

  /* ---- build the three packed representations ---- */
  long nb243 = (n + 4) / 5;
  uint8_t *p243 = calloc((size_t)nb243, 1);
  for (long i = 0; i < n; i++) {
    int d = weight_of(i) + 1; /* digit 0..2 */
    p243[i / 5] = (uint8_t)(p243[i / 5] + d * POW3[i % 5]);
  }
  long nb2 = (n + 3) / 4;
  uint8_t *p2 = calloc((size_t)nb2, 1);
  for (long i = 0; i < n; i++) {
    int d = weight_of(i) + 1; /* 2-bit digit 0..2 */
    p2[i / 4] = (uint8_t)(p2[i / 4] | (d << (2 * (i % 4))));
  }
  int8_t *p1 = malloc((size_t)n);
  for (long i = 0; i < n; i++) p1[i] = (int8_t)weight_of(i);

  printf("N = %ld weights | footprint: 243=%.2f MB  2bit=%.2f MB  1byte=%.2f MB\n",
         n, nb243 / 1048576.0, nb2 / 1048576.0, n / 1048576.0);

  /* decode LUT (§10.C): byte → its 5 packed weights (-1/0/+1). */
  static signed char LUT[256][5];
  for (int b = 0; b < 243; b++) {
    int x = b;
    for (int k = 0; k < 5; k++) { LUT[b][k] = (signed char)((x % 3) - 1); x /= 3; }
  }

  volatile long sink = 0;
  double best243 = 1e18, bestLut = 1e18, best2 = 1e18, best1 = 1e18;
  long s243 = 0, sLut = 0, s2 = 0, s1 = 0;

  for (int r = 0; r < reps; r++) {
    /* base-243 / div-mod: unpack a byte into 5 trits via div/mod by powers of 3. */
    double t0 = now_ms();
    long acc = 0;
    for (long b = 0; b < nb243; b++) {
      long byte = p243[b];
      long base = b * 5;
      for (int k = 0; k < 5 && base + k < n; k++) {
        int w = (int)((byte / POW3[k]) % 3) - 1;
        acc += (long)w * act[base + k];
      }
    }
    double t1 = now_ms();
    s243 = acc;
    if (t1 - t0 < best243) best243 = t1 - t0;

    /* base-243 / LUT-256: one table lookup per byte gives all 5 weights. */
    t0 = now_ms();
    acc = 0;
    for (long b = 0; b < nb243; b++) {
      const signed char *w = LUT[p243[b]];
      long base = b * 5;
      if (base + 5 <= n) {
        acc += (long)w[0] * act[base] + (long)w[1] * act[base + 1]
             + (long)w[2] * act[base + 2] + (long)w[3] * act[base + 3]
             + (long)w[4] * act[base + 4];
      } else {
        for (int k = 0; k < 5 && base + k < n; k++) acc += (long)w[k] * act[base + k];
      }
    }
    t1 = now_ms();
    sLut = acc;
    if (t1 - t0 < bestLut) bestLut = t1 - t0;

    /* 2-bit: unpack via shift+mask, no radix conversion. */
    t0 = now_ms();
    acc = 0;
    for (long b = 0; b < nb2; b++) {
      long byte = p2[b];
      long base = b * 4;
      for (int k = 0; k < 4 && base + k < n; k++) {
        int w = (int)((byte >> (2 * k)) & 3) - 1;
        acc += (long)w * act[base + k];
      }
    }
    t1 = now_ms();
    s2 = acc;
    if (t1 - t0 < best2) best2 = t1 - t0;

    /* 1-byte: direct, no unpack. */
    t0 = now_ms();
    acc = 0;
    for (long i = 0; i < n; i++) acc += (long)p1[i] * act[i];
    t1 = now_ms();
    s1 = acc;
    if (t1 - t0 < best1) best1 = t1 - t0;
    sink += acc;
  }

  printf("dot-product (best of %d):\n", reps);
  printf("  base-243/divmod : %7.1f ms   sum=%ld\n", best243, s243);
  printf("  base-243/LUT256 : %7.1f ms   sum=%ld\n", bestLut, sLut);
  printf("  2-bit           : %7.1f ms   sum=%ld\n", best2, s2);
  printf("  1-byte          : %7.1f ms   sum=%ld\n", best1, s1);
  if (s243 != sLut || sLut != s2 || s2 != s1) {
    printf("MISMATCH — codecs disagree!\n");
    return 1;
  }
  printf("verdict: LUT vs divmod = %.2fx, LUT vs 2-bit = %.2fx, LUT vs 1-byte = %.2fx"
         " (>1 means base-243 slower)\n",
         bestLut / best243, bestLut / best2, bestLut / best1);
  (void)sink;
  free(act); free(p243); free(p2); free(p1);
  return 0;
}
