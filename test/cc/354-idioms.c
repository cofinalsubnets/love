/* the idioms lo.l reads whole, against every edge: / and % by a literal, a select, min and max, a rotate, a gather */
#include <stdio.h>
__attribute__((noinline)) long id(long x){return x;}
#define S(T,n) do { T x = (T)id(v); printf("%lld %lld ", (long long)(x / n), (long long)(x % n)); } while (0)
int main(void){ long vs[] = {0,1,-1,2,-2,7,-7,8,-8,9,-9,99,-99,100,-100,1000,-1000,2147483647,-2147483648L,4294967295L,4294967296L,-4294967296L,9223372036854775807L,-9223372036854775807L-1,12345678901234L,-12345678901234L};
 for (unsigned i=0;i<sizeof vs/sizeof*vs;i++){ long v=vs[i];
  S(int,1);S(int,2);S(int,3);S(int,7);S(int,8);S(int,10);S(int,16);S(int,100);S(int,1000);S(int,65536);S(int,641);
  S(long,1);S(long,2);S(long,3);S(long,7);S(long,8);S(long,10);S(long,4096);S(long,1000000007L);S(long,4611686018427387904L);S(long,9223372036854775807L);
  S(unsigned,1);S(unsigned,3);S(unsigned,7);S(unsigned,10);S(unsigned,16);S(unsigned,641);S(unsigned,4294967295u);S(unsigned,2147483648u);
  S(unsigned long,1);S(unsigned long,3);S(unsigned long,7);S(unsigned long,10);S(unsigned long,1000000007UL);S(unsigned long,9223372036854775808UL);S(unsigned long,18446744073709551615UL);
  S(short,7);S(unsigned char,5);
  puts("");
  int a=(int)v,b=(int)(v>>3); unsigned u=(unsigned)v; unsigned long w=(unsigned long)v; double d=(double)v,e=(double)b;
  printf("%d %d %d %ld %u %lu %u %lu %g %g %g %g\n", a<b?a:b, a>b?a:b, a?b:7, a==3?v:w, u>3?u:a, (u>>5)|(u<<27)?w:3, (u>>5)|(u<<27), (w<<13)|(w>>51), d<e?d:e, d>e?d:e, d<e?e:d, d>e?e:d);
  int n=(a&31)+1; if(n==32)n=1; printf("%u %u %lu\n",(u>>n)|(u<<(32-n)),(u<<n)|(u>>(32-n)),(w>>n)|(w<<(64-n)));
  unsigned char p[8]; for(int j=0;j<8;j++)p[j]=(unsigned char)(w>>(j*8));
  printf("%u %lu %u\n",(unsigned)p[0]|(unsigned)p[1]<<8|(unsigned)p[2]<<16|(unsigned)p[3]<<24,(unsigned long)p[0]|(unsigned long)p[1]<<8|(unsigned long)p[2]<<16|(unsigned long)p[3]<<24|(unsigned long)p[4]<<32|(unsigned long)p[5]<<40|(unsigned long)p[6]<<48|(unsigned long)p[7]<<56,(unsigned short)((unsigned)p[0]|(unsigned)p[1]<<8));
 }
 printf("%g %g\n",1.5,-0.0); return 0; }
