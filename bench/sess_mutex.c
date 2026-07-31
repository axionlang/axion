/* Mutex-throughput ceiling of the M:N session scheduler's design (§11).
 *
 * The scheduler guards all shared state (channel buffers + the ready/blocked
 * queues) with ONE global mutex, held for each channel op (send/recv/spawn/...).
 * This microbenchmark isolates that ceiling: N threads each run a tight loop of
 * (lock; a tiny queue push+pop; unlock) — the exact shape of a channel op with
 * zero compute between ops. It reports the *contended* ops/sec, i.e. the rate at
 * which the global lock would cap a channel-bound workload and the rate a
 * lock-free work-stealing scheduler would have to beat to be worth building.
 *
 *   cc -O2 -pthread bench/sess_mutex.c -o mb && ./mb <threads> <ops-per-thread>
 */
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

static pthread_mutex_t mtx = PTHREAD_MUTEX_INITIALIZER;
static long shared_q[64];
static int qi = 0;
static long OPS;

static void *hammer(void *arg) {
  (void)arg;
  for (long i = 0; i < OPS; i++) {
    pthread_mutex_lock(&mtx);
    shared_q[qi & 63] = i; /* a push, like ready_push */
    qi++;
    long v = shared_q[(qi - 1) & 63]; /* a read, like a pop */
    (void)v;
    pthread_mutex_unlock(&mtx);
  }
  return NULL;
}

int main(int argc, char **argv) {
  int nt = argc > 1 ? atoi(argv[1]) : 4;
  OPS = argc > 2 ? atol(argv[2]) : 5000000;
  if (nt < 1) nt = 1;
  if (nt > 64) nt = 64;
  pthread_t th[64];
  struct timespec a, b;
  clock_gettime(CLOCK_MONOTONIC, &a);
  for (int t = 0; t < nt; t++) pthread_create(&th[t], NULL, hammer, NULL);
  for (int t = 0; t < nt; t++) pthread_join(th[t], NULL);
  clock_gettime(CLOCK_MONOTONIC, &b);
  double sec = (b.tv_sec - a.tv_sec) + (b.tv_nsec - a.tv_nsec) / 1e9;
  double total = (double)OPS * nt;
  printf("  threads=%d  ops=%.0f  wall=%.3fs  %6.1f M ops/s  (%.1f ns/op)\n", nt,
         total, sec, total / sec / 1e6, sec / total * 1e9);
  return 0;
}
