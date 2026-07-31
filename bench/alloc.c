#include <stdio.h>
#include <stdlib.h>
/* volatile pointer sink → prevents -O2 from eliminating the malloc/free */
static void * volatile sink;
long allocN(long n){ long s=0; while(n){ char*c=(char*)malloc(16); sink=c; s+=1; free(c); n--; } return s; }
int main(void){ long s=0; for(long k=2000;k;k--) s+=allocN(20000); printf("%ld\n", s); return 0; }
