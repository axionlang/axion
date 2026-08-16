/* `i32mv` kernel: int32 matvec — hand-written C mirror of Axion's I32Array path.
 * n int32 weights (200 MB) against a small reused K-activation. weight(i)=i,
 * act(k)=k, N=50M, K=8192 — same result as bench/i32mv.axi. */
#include <stdio.h>
#include <stdlib.h>
#define N 50000000L
#define K 8192L
int main(void){
  int *w = malloc((size_t)N*4);           /* int32 weights: 200 MB */
  for(long i=0;i<N;i++) w[i]=(int)i;
  long *act = malloc((size_t)K*sizeof(long));
  for(long k=0;k<K;k++) act[k]=k;
  long acc=0,k=0;
  for(long i=0;i<N;i++){ acc += (long)w[i]*act[k]; if(++k==K)k=0; }
  printf("%ld\n",acc); free(w); free(act); return 0;
}
