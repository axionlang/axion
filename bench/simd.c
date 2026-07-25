#include <stdio.h>
#include <stdlib.h>
long sum_buf(unsigned char*b, long n){ long s=0; for(long i=0;i<n;i++) s+=b[i]; return s; }
int main(void){ long n=40000; unsigned char*b=(unsigned char*)malloc(n);
  for(long i=0;i<n;i++) b[i]=(unsigned char)(i&0xFF);
  long s=0; for(int k=0;k<5000;k++) s+=sum_buf(b,n); printf("%ld\n", s); free(b); return 0; }
