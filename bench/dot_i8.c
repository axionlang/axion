/* `dot_i8` kernel: the SAME ternary-quantized dot product as `tritvec`, but in the
 * representation a C programmer would actually pick — a dense int8 array (1 byte
 * per weight, no packing, no unpack). The honest "real world" baseline: on raw
 * speed this beats every packed form; it costs 5× the memory of base-243. Weights
 * w(i)=(i mod 3)-1, activations a(i)=(i mod 7)-3, N=50M — same result as tritvec. */
#include <stdio.h>
#include <stdlib.h>

#define N 50000000L

int main(void) {
  signed char *w = malloc((size_t)N); /* 1 byte per weight */
  for (long i = 0; i < N; i++) w[i] = (signed char)((i % 3) - 1);
  long acc = 0;
  for (long i = 0; i < N; i++) acc += (long)w[i] * ((i % 7) - 3);
  printf("%ld\n", acc);
  free(w);
  return 0;
}
