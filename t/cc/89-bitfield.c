struct b { unsigned a:1; unsigned n:5; int s:4; unsigned hi:8; char c; };
int main() {
  struct b x;
  x.a = 1; x.n = 21; x.s = -3; x.hi = 200; x.c = 9;
  int t = x.a + x.n;            /* 22 */
  x.n = x.n + 3;               /* 24 */
  if (x.s != -3) return 111;   /* signed read: negative */
  x.s = 5;                     /* signed write: positive */
  return t + x.n + x.s + (x.hi & 3) + (int)x.c;  /* 22+24+5+0+9 = 60 */
}
