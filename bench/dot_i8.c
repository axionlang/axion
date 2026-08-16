/* `dot_i8` kernel: fair dense int8 dot — two stored int8 arrays (~50 MB each),
 * the hand-written C mirror of Axion's i8DotI8. weight(i)=(i mod 3)-1 for both →
 * sum of squares = 33333333. N=50M. */
#include <stdio.h>
#include <stdlib.h>
#define N 50000000L
int main(void){
  signed char *a = malloc((size_t)N), *b = malloc((size_t)N);
  for(long i=0;i<N;i++){ signed char w=(signed char)((i%3)-1); a[i]=w; b[i]=w; }
  long s=0;
  for(long i=0;i<N;i++) s += (long)a[i]*(long)b[i];
  printf("%ld\n", s); free(a); free(b); return 0;
}
