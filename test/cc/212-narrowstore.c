/* narrow stores through a pointer from a register-riding value: the store truncates on its own,
 * so an integer cast at least as wide as the stored type drops and no extend runs first; the
 * assignment's answer keeps its conversion wherever it is read -- chained, compared, returned,
 * or through a comma. held to gcc. */

typedef unsigned char u8;
typedef signed char s8;

static int noinl(int x) { return x; }

__attribute__((noinline)) static unsigned lit(u8 *op, const unsigned *sy, int n) {
  u8 *o = op;
  for (int i = 0; i < n; i++) *op++ = (u8) sy[i];
  unsigned h = 0;
  for (u8 *p = o; p < op; p++) h = h * 31 + *p;
  return h;
}

__attribute__((noinline)) static int chains(int v, long w) {
  int bad = 0;
  u8 b[4]; s8 c[4]; short s[4]; unsigned short us[4]; int in[2];
  u8 *pb = b; s8 *pc = c; short *ps = s; unsigned short *pu = us;
  int x = (*pb = v);                      /* the answer converts: 300 -> 44 */
  if (x != (u8) v || b[0] != (u8) v) bad |= 1;
  int y = (*pc = (s8) v);                 /* a cast as wide as the store */
  if (y != (s8) v || c[0] != (s8) v) bad |= 2;
  if ((*ps = (int) w) != (short) w || s[0] != (short) w) bad |= 4;
  if ((*pu = (unsigned) w) != (unsigned short) w) bad |= 8;
  *(pb + 1) = (int) w;                    /* a wider cast over a long */
  if (b[1] != (u8) w) bad |= 16;
  *(pc + 1) = (short) v;                  /* short -> signed char: truncates twice, same byte */
  if (c[1] != (s8) (short) v) bad |= 32;
  *(pc + 2) = (u8) v;                     /* unsigned then signed store: the byte, sign read back */
  if (c[2] != (s8) (u8) v) bad |= 64;
  int z = (b[2] = 7, *(pb + 2) = v + 1);  /* through a comma */
  if (z != (u8) (v + 1)) bad |= 128;
  *(in + 1) = (int) w;                    /* int store from a long: sx4 was the bridge */
  if (in[1] != (int) w) bad |= 256;
  u8 k = *(pb + 3) = noinl(v);            /* a callish right keeps the shuttle */
  if (k != (u8) v || b[3] != (u8) v) bad |= 512;
  return bad;
}

int main(void) {
  unsigned sy[6] = {65, 300, 255, 256, 511, 0x1234};
  u8 buf[8];
  if (lit(buf, sy, 6) != 1909134401u) return 1 + (int) (lit(buf, sy, 6) & 63);
  int bad = chains(300, 0x12345678abcdLL) | chains(-129, -70000) | chains(127, 65535);
  return bad ? 64 + (bad & 63) + (bad >> 6 ? 100 : 0) : 0;
}
