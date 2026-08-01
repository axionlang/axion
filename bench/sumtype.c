#include <stdio.h>
typedef enum { North, East, South, West } Dir;
static Dir turn(Dir d){ switch(d){ case North:return East; case East:return South; case South:return West; default:return North; } }
static long val(Dir d){ switch(d){ case North:return 0; case East:return 1; case South:return 2; default:return 3; } }
static Dir from_int(long n){ switch(n%4){ case 0:return North; case 1:return East; case 2:return South; default:return West; } }
static long inner(Dir d, long acc, long n){ while(n){ acc=(acc+val(d))%1000000L; d=turn(d); n--; } return acc; }
int main(void){ long acc=0; for(long k=4000;k;k--) acc=(acc+inner(from_int(k),0,50000))%2147483647L; printf("%ld\n", acc); return 0; }
