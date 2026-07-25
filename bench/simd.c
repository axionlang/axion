#include <stdio.h>
static long a[1024];
int main(void){ for(int i=0;i<1024;i++) a[i]=i;
  long s=0; for(int r=0;r<2000000;r++) for(int i=0;i<1024;i++) s+=a[i];
  printf("%ld\n", s); return 0; }
