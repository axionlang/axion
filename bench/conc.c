/* Concurrency benchmark (C, pthreads) — the fork-join baseline: 4 workers each
 * compute fib(N), the parent sums. `./conc N T`: T<=1 runs the four sequentially
 * (the 1-thread baseline), else one pthread per worker. Compare against the same
 * workload in Rust (bench/conc.rs) and Axion (bench/conc.axi, session tasks on
 * the M:N scheduler). Naive fib so the compute dominates. */
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>

/* volatile so the optimizer cannot hoist/CSE the four `fib(ARG)` calls in the
 * sequential path (they must each really run, like the four session workers). */
static volatile long ARG;
static long fib(long n) { return n < 2 ? n : fib(n - 1) + fib(n - 2); }
static void *worker(void *r) {
  *(long *)r = fib(ARG);
  return NULL;
}

int main(int argc, char **argv) {
  ARG = argc > 1 ? atol(argv[1]) : 34;
  int t = argc > 2 ? atoi(argv[2]) : 4;
  long res[4];
  if (t <= 1) {
    for (int i = 0; i < 4; i++) res[i] = fib(ARG);
  } else {
    pthread_t th[4];
    for (int i = 0; i < 4; i++) pthread_create(&th[i], NULL, worker, &res[i]);
    for (int i = 0; i < 4; i++) pthread_join(th[i], NULL);
  }
  printf("%ld\n", res[0] + res[1] + res[2] + res[3]);
  return 0;
}
