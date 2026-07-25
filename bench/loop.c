#include <stdio.h>
long inner(long acc, long n){ while(n){ acc=(acc+n*n)%2147483647L; n--; } return acc; }
long outer(long acc, long k){ while(k){ acc+=inner(k,50000); k--; } return acc; }
int main(void){ printf("%ld\n", outer(0,4000)); return 0; }
