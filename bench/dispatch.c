#include <stdio.h>
static long step(long x) { return (x + 7) % 1000000; }
static long inner(long x, long n) { while (n-- > 0) x = step(x); return x; }
static long outer(long acc, long k) {
  while (k > 0) { acc = (acc + inner(k, 50000)) % 2147483647; k--; }
  return acc;
}
int main(void) { printf("%ld\n", outer(0, 4000)); return 0; }
