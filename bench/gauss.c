/* Dense Gaussian elimination with partial pivoting over double[], solving an N*N system `reps`
 * times — the C comparison tier for bench/gauss.axi. Same fixed diagonally-dominant integer matrix,
 * same per-iteration true solution, same integer checksum. Raw double arrays (malloc) — the
 * baseline the Axion Array Float (bounds-checked get/set) version is measured against. */
#include <stdio.h>
#include <stdlib.h>
#include <math.h>

static double a_entry(int n, int i, int j) {
  return (i == j) ? (double)(4 * n) : (double)(((i * 7 + j * 13) % 3) + 1);
}
static double x_true(int iter, int j) { return (double)(((iter + j) % 7) + 1); }

static long solve_one(int n, int iter) {
  int w = n + 1;
  double *m = (double *)malloc((size_t)n * w * sizeof(double));
  double *x = (double *)calloc((size_t)n, sizeof(double));
  /* fill augmented [A | b] */
  for (int i = 0; i < n; i++) {
    for (int j = 0; j < n; j++) m[i * w + j] = a_entry(n, i, j);
    double b = 0.0;
    for (int j = 0; j < n; j++) b += a_entry(n, i, j) * x_true(iter, j);
    m[i * w + n] = b;
  }
  /* forward elimination with partial pivoting */
  for (int k = 0; k < n; k++) {
    int p = k;
    for (int i = k; i < n; i++)
      if (fabs(m[i * w + k]) > fabs(m[p * w + k])) p = i;
    for (int j = 0; j <= n; j++) {
      double t = m[k * w + j];
      m[k * w + j] = m[p * w + j];
      m[p * w + j] = t;
    }
    for (int i = k + 1; i < n; i++) {
      double factor = m[i * w + k] / m[k * w + k];
      for (int j = k; j <= n; j++) m[i * w + j] -= factor * m[k * w + j];
    }
  }
  /* back-substitution */
  for (int i = n - 1; i >= 0; i--) {
    double s = m[i * w + n];
    for (int j = i + 1; j < n; j++) s -= m[i * w + j] * x[j];
    x[i] = s / m[i * w + i];
  }
  long acc = 0;
  for (int i = 0; i < n; i++) acc += (long)(x[i] + 0.5);
  free(m);
  free(x);
  return acc;
}

int main(void) {
  int n = 64, reps = 1500;
  long acc = 0;
  for (int iter = 0; iter < reps; iter++) acc += solve_one(n, iter);
  printf("%ld\n", acc);
  return 0;
}
