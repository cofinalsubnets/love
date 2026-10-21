/* a constant mask or compare against the same constant read through memory: thumb2 lays the
 * first as a modified immediate (a byte, 00XY00XY, XY00XY00, XYXYXYXY, a rotated byte), and/or
 * the complement's as bic/orn, cmp/cmn either sign; the second stays a register */
typedef unsigned u32;
static volatile u32 m[] = { 0xff, 0x00ab00ab, 0xab00ab00, 0xabababab, 0x3fc, 0x80000000, 0x7fffffff,
  0xfffffeff, 0x81000000, 0xff00ff00, 0x000fffff, 0x7ff, 0x10000 };
static volatile u32 xs[] = { 0, 1, 0x7fe, 0x7ff, 0x10000, 0x8000ffff, 0xdeadbeef, 0xffffffff, 0x1fe00, 0xfffe0200 };

int main(void)
{
  int bad = 0;
  for (unsigned i = 0; i < sizeof xs / sizeof xs[0]; i++) {
    u32 x = xs[i];
    int s = (int) x;
    bad += (x & 0xff) != (x & m[0]);
    bad += (x | 0x00ab00ab) != (x | m[1]);
    bad += (x ^ 0xab00ab00) != (x ^ m[2]);
    bad += (x & 0xabababab) != (x & m[3]);
    bad += (x & 0x3fc) != (x & m[4]);
    bad += (x | 0x80000000) != (x | m[5]);
    bad += (x & 0x7fffffff) != (x & m[6]);
    bad += (x | 0xfffffeff) != (x | m[7]);
    bad += !!(x & 0x81000000) != !!(x & m[8]);
    bad += (x & 0xff00ff00) != (x & m[9]);
    bad += (x & 0x000fffff) != (x & m[10]);
    bad += ((x >> 20) & 0x7ff) != ((x >> 20) & m[11]);
    bad += (x < 0x10000) != (x < m[12]);
    bad += (s < 0x10000) != (s < (int) m[12]);
    bad += (s == -0x1fe00) != (x == 0xfffe0200);
    bad += (s > -0x10000) != (s > -(int) m[12]);
    bad += (x << 3 >> 5) != ((x * 8) / 32);
    bad += (u32) (unsigned char) (x >> 4) != ((x >> 4) & 0xff);
    bad += (u32) (unsigned short) (x >> 3) != ((x >> 3) & 0xffff);
    bad += (u32) (int) (signed char) (x >> 2) != (((x >> 2) & 0x80) ? ((x >> 2) | 0xffffff00) : ((x >> 2) & 0xff));
    bad += (u32) ~(x >> 1) != (0xffffffff - (x >> 1));
  }
  return 42 + bad;   /* 42 */
}
