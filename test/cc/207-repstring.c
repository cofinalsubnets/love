/* the string ops under rep: copy and fill in every width (the kernel's memcpy/memset
 * fallbacks), repne scasb as strlen, repe cmpsb as a compare, lodsb alone, and the port
 * forms with and without rep laid but not run. the asm is x64's. held to gcc. */

#if defined(__x86_64__)
static void cpyb(void *d, const void *s, unsigned long n) {
  asm volatile("rep movsb" : "+D"(d), "+S"(s), "+c"(n) : : "memory");
}
static void cpyq(void *d, const void *s, unsigned long n) {
  asm volatile("rep movsq" : "+D"(d), "+S"(s), "+c"(n) : : "memory");
}
static void cpyw(void *d, const void *s, unsigned long n) {
  asm volatile("rep; movsw" : "+D"(d), "+S"(s), "+c"(n) : : "memory");
}
static void setb(void *d, int v, unsigned long n) {
  asm volatile("rep stosb" : "+D"(d), "+c"(n) : "a"(v) : "memory");
}
static void setl(void *d, unsigned v, unsigned long n) {
  asm volatile("rep stosl" : "+D"(d), "+c"(n) : "a"(v) : "memory");
}
static void setq(void *d, unsigned long v, unsigned long n) {
  asm volatile("rep stosq" : "+D"(d), "+c"(n) : "a"(v) : "memory");
}
static unsigned long slen(const char *s) {
  unsigned long c = ~0UL;
  asm("repne scasb" : "+D"(s), "+c"(c) : "a"(0) : "memory", "cc");
  return ~c - 1;
}
static int same(const char *a, const char *b, unsigned long n) {
  unsigned char r;
  asm("repe cmpsb\n\tsete %0" : "=q"(r), "+S"(a), "+D"(b), "+c"(n) : : "memory", "cc");
  return r;
}
static int first(const char *s) {
  int v = 0;
  asm("lodsb" : "+a"(v), "+S"(s) : : "memory");
  return v;
}
void ports(void *p, unsigned long n) {
  asm volatile("rep outsb" : "+S"(p), "+c"(n) : "d"(0x80) : "memory");
  asm volatile("rep insw" : "+D"(p), "+c"(n) : "d"(0x80) : "memory");
  asm volatile("insl" : "+D"(p) : "d"(0x80) : "memory");
}
#else
static void cpyb(void *d, const void *s, unsigned long n) {
  while (n--) *(char *)d = *(const char *)s, d = (char *)d + 1, s = (const char *)s + 1;
}
static void cpyq(void *d, const void *s, unsigned long n) { cpyb(d, s, n * 8); }
static void cpyw(void *d, const void *s, unsigned long n) { cpyb(d, s, n * 2); }
static void setb(void *d, int v, unsigned long n) { while (n--) *(char *)d = v, d = (char *)d + 1; }
static void setl(void *d, unsigned v, unsigned long n) { unsigned *p = d; while (n--) *p++ = v; }
static void setq(void *d, unsigned long v, unsigned long n) { unsigned long *p = d; while (n--) *p++ = v; }
static unsigned long slen(const char *s) { unsigned long n = 0; while (s[n]) n++; return n; }
static int same(const char *a, const char *b, unsigned long n) {
  while (n--) if (*a++ != *b++) return 0;
  return 1;
}
static int first(const char *s) { return (unsigned char)*s; }
#endif

int main(void) {
  int bad = 0;
  char a[32] = "the quick brown fox", b[32] = {0};
  unsigned long q[4] = {1, 2, 3, 4}, r[4] = {0};
  unsigned short w[3] = {7, 8, 9}, x[3] = {0};
  unsigned l[5] = {0};
  cpyb(b, a, 20);
  if (b[4] != 'q' || b[18] != 'x' || b[19] != 0) bad |= 1;
  cpyq(r, q, 4);
  if (r[0] != 1 || r[3] != 4) bad |= 2;
  cpyw(x, w, 3);
  if (x[0] != 7 || x[2] != 9) bad |= 4;
  setb(b, 'z', 3);
  if (b[0] != 'z' || b[2] != 'z' || b[3] != ' ') bad |= 8;
  setl(l, 0xdeadbeef, 4);
  if (l[0] != 0xdeadbeef || l[3] != 0xdeadbeef || l[4] != 0) bad |= 16;
  setq(r, 5, 3);
  if (r[0] != 5 || r[2] != 5 || r[3] != 4) bad |= 32;
  if (slen(a) != 19 || slen("") != 0) bad |= 64;
  if (!same(a, "the quick", 9) || same(a, "the quack", 9)) bad |= 128;
  if (first("A") != 65) bad |= 3;
  return bad;
}
