#include <stdio.h>
#include <stdlib.h>
static double dot(const double *x, const double *y, long n) {
  double s = 0; for (long i = 0; i < n; i++) s += x[i] * y[i]; return s; }
int main(void) { long n = 4096; double *x = malloc(n * sizeof *x), *y = malloc(n * sizeof *y);
  for (long i = 0; i < n; i++) { x[i] = (double)(i % 7); y[i] = (double)(i % 5); }
  double t = 0; for (int k = 0; k < 20000; k++) t += dot(x, y, n);
  printf("%ld\n", (long)t); free(x); free(y); return 0; }
