/* the mem* five. the copies run word-wide where the pointers agree and bytewise where
 * they do not, so each case runs at several alignments and across the word boundary:
 * an off-by-one in the wide lane hides at offset 0. the stride is sizeof(long). */
#include <string.h>
#include "say.h"

static char buf[80], b2[80];

static void fill(char *p, size_t n, int seed) {
  for (size_t i = 0; i < n; i++) p[i] = (char) ('a' + (int) ((i + (size_t) seed) % 26)); }

int main(void) {
 /* --- memset: every alignment, and a byte with the high bit set (it is an
    int argument converted to unsigned char, not a signed one) --- */
 for (int off = 0; off < 9; off++) {
  memset(buf, '.', sizeof buf);
  memset(buf + off, 'Z', 17);
  say_b("memset.17", buf, 32); }
 memset(buf, 0, sizeof buf);
 memset(buf, 0xff, 5);
 say_b("memset.ff", buf, 8);
 memset(buf, 'x', 0);                          /* zero length touches nothing */
 say_b("memset.0", buf, 8);

 /* --- memcpy: aligned, misaligned source, misaligned dest, both --- */
 for (int off = 0; off < 9; off++) {
  fill(b2, sizeof b2, 3);
  memset(buf, '.', sizeof buf);
  memcpy(buf + off, b2, 23);
  say_b("memcpy.d", buf, 34);
  memset(buf, '.', sizeof buf);
  memcpy(buf, b2 + off, 23);
  say_b("memcpy.s", buf, 26);
  memset(buf, '.', sizeof buf);
  memcpy(buf + off, b2 + off, 23);
  say_b("memcpy.b", buf, 34); }
 memcpy(buf, b2, 0);
 say_n("memcpy.0", 1);

 /* --- memcpy past the quad: every pair of offsets that disagree rides the
    shifting lane, checked byte for byte against the source with guards either side --- */
 { static char const lens[] = {32, 33, 39, 40, 47, 63, 64, 65};
  long bad = 0;
  for (unsigned li = 0; li < sizeof lens; li++)
   for (int so = 0; so < 8; so++)
    for (int dof = 0; dof < 8; dof++) {
     int n = lens[li];
     fill(b2, sizeof b2, so + li);
     memset(buf, '.', sizeof buf);
     memcpy(buf + dof + 1, b2 + so, (size_t) n);
     for (int i = 0; i < n; i++) bad += buf[dof + 1 + i] != b2[so + i];
     bad += buf[dof] != '.';
     bad += buf[dof + 1 + n] != '.'; }
  say_n("memcpy.shift.bad", bad); }

 /* --- memmove: the overlap both directions, adjacent and by a word.
    dest > src must copy backward or it eats its own tail. --- */
 for (int d = 1; d <= 9; d++) {
  fill(buf, 40, 0);
  memmove(buf + d, buf, 24);                /* forward overlap */
  say_b("memmove.up", buf, 40);
  fill(buf, 40, 0);
  memmove(buf, buf + d, 24);                /* backward overlap */
  say_b("memmove.dn", buf, 40); }

 /* --- memmove backward past the quad: every overlap shift a word and a half
    either way of agreement, at every source offset, against a byte-copied reference --- */
 { static char const lens[] = {32, 33, 39, 40, 47, 63, 64, 65};
  static char mb[112], ref[112];
  long bad = 0;
  for (unsigned li = 0; li < sizeof lens; li++)
   for (int so = 0; so < 8; so++)
    for (int sh = 1; sh < 16; sh++) {
     int n = lens[li];
     fill(mb, sizeof mb, so + sh);
     for (int i = 0; i < (int) sizeof mb; i++) ref[i] = mb[i];
     for (int i = n - 1; i >= 0; i--) ref[so + sh + i] = ref[so + i];
     memmove(mb + so + sh, mb + so, (size_t) n);
     for (int i = 0; i < (int) sizeof mb; i++) bad += mb[i] != ref[i]; }
  say_n("memmove.shift.bad", bad); }

 /* --- the vector lanes past 64: blocks of 64, then 16s, then a last 16 over what they left;
    every length mod 64 and 16, every offset of a vector, both overlaps, near and far --- */
 { static unsigned short const lens[] = {64, 65, 79, 80, 95, 111, 127, 128, 129, 143, 191, 200, 255, 256, 257, 300};
  static char va[420], vb[420], vr[420];
  long bad = 0;
  for (unsigned li = 0; li < sizeof lens / sizeof *lens; li++)
   for (int so = 0; so < 16; so++)
    for (int dof = 0; dof < 16; dof++) {
     int n = lens[li];
     fill(vb, sizeof vb, so + dof + (int) li);
     memset(va, '.', sizeof va);
     memcpy(va + dof + 1, vb + so, (size_t) n);
     for (int i = 0; i < n; i++) bad += va[dof + 1 + i] != vb[so + i];
     bad += va[dof] != '.';
     bad += va[dof + 1 + n] != '.';
     memset(va + dof + 1, (int) (0x80 + li), (size_t) n);
     for (int i = 0; i < n; i++) bad += va[dof + 1 + i] != (char) (0x80 + li);
     bad += va[dof] != '.';
     bad += va[dof + 1 + n] != '.'; }
  say_n("vec.copy.set.bad", bad);
  bad = 0;
  static short const shs[] = {1, 7, 15, 16, 17, 31, 63, 64, 65, 100};
  for (unsigned li = 0; li < sizeof lens / sizeof *lens; li++)
   for (int so = 0; so < 16; so += 3)
    for (unsigned si = 0; si < sizeof shs / sizeof *shs; si++)
     for (int up = 0; up < 2; up++) {
      int n = lens[li], sh = shs[si], s0 = up ? so : so + sh, d0 = up ? so + sh : so;
      fill(va, sizeof va, so + sh);
      for (int i = 0; i < (int) sizeof va; i++) vr[i] = va[i];
      if (up) for (int i = n - 1; i >= 0; i--) vr[d0 + i] = vr[s0 + i];
      else for (int i = 0; i < n; i++) vr[d0 + i] = vr[s0 + i];
      memmove(va + d0, va + s0, (size_t) n);
      for (int i = 0; i < (int) sizeof va; i++) bad += va[i] != vr[i]; }
  say_n("vec.move.bad", bad); }

 fill(buf, 40, 0);
 memmove(buf, buf, 20);                        /* exactly equal: a no-op */
 say_b("memmove.eq", buf, 24);

 /* --- memcmp: the sign only (see say.h), at every alignment, with the
    difference in the first, middle and last byte --- */
 for (int off = 0; off < 9; off++) {
  fill(buf, sizeof buf, 0);
  fill(b2, sizeof b2, 0);
  say_c("memcmp.eq", memcmp(buf + off, b2 + off, 24));
  b2[off] = 'A';
  say_c("memcmp.first", memcmp(buf + off, b2 + off, 24));
  say_c("memcmp.rev", memcmp(b2 + off, buf + off, 24));
  fill(b2, sizeof b2, 0);
  b2[off + 12] = '~';
  say_c("memcmp.mid", memcmp(buf + off, b2 + off, 24));
  fill(b2, sizeof b2, 0);
  b2[off + 23] = '~';
  say_c("memcmp.last", memcmp(buf + off, b2 + off, 24));
  say_c("memcmp.short", memcmp(buf + off, b2 + off, 23)); } /* one shy: equal */

 say_c("memcmp.0", memcmp("a", "b", 0));       /* zero length is always equal */
 /* independent offsets: the sweep above keeps both pointers aligned alike, these do not,
    and their lengths cross the word step */
 for (int ox = 0; ox < 9; ox++)
  for (int oy = 0; oy < 9; oy++) {
   fill(buf, sizeof buf, 0);
   fill(b2, sizeof b2, 0);
   for (size_t n = 0; n <= 20; n++) {
    say_c("memcmp.mix.eq", memcmp(buf + ox, b2 + oy, n));
    for (size_t d = 0; d < n; d++) {
     b2[oy + d] ^= 0x80;           /* the high bit: unsigned ordering too */
     say_c("memcmp.mix", memcmp(buf + ox, b2 + oy, n));
     say_c("memcmp.mix.rev", memcmp(b2 + oy, buf + ox, n));
     b2[oy + d] ^= 0x80; } } }

 /* the bytes compare as unsigned char: 0x80 is above 0x7f, not below */
 unsigned char hi[2], lo[2];
 hi[0] = 0x80; hi[1] = 0; lo[0] = 0x7f; lo[1] = 0;
 say_c("memcmp.unsigned", memcmp(hi, lo, 1));

 /* --- memchr: the offset, or -1 --- */
 fill(buf, sizeof buf, 0);
 say_p("memchr.hit", buf, memchr(buf, 'a', 40));
 say_p("memchr.late", buf, memchr(buf, 'z', 40));
 say_p("memchr.miss", buf, memchr(buf, '!', 40));
 say_p("memchr.past", buf, memchr(buf, 'b', 1));   /* out of the searched span */
 say_p("memchr.0", buf, memchr(buf, 'a', 0));
 buf[7] = 0;
 say_p("memchr.nul", buf, memchr(buf, 0, 40));     /* a NUL is a byte like any other */

 unsigned char u[4]; u[0] = 1; u[1] = 0xc3; u[2] = 2; u[3] = 3;
 say_p("memchr.high", u, memchr(u, 0xc3, 4)); /* the int arg is taken as unsigned char */

 /* the word loop's corners: every start alignment, length mod the word and needle position
  * answers as a byte walk, and a needle one past the span is not found */
  static unsigned char big[160];
  unsigned i, off, len;
  for (i = 0; i < sizeof big; i++) big[i] = 'a' + (i % 23);
  for (off = 0; off < 16; off++)
    for (len = 0; len < 40; len++) {
      say_p("memchr.miss.sweep", big, memchr(big + off, '!', len));
      for (i = 0; i < len + 2 && off + i < sizeof big; i++) {
        unsigned char save = big[off + i];
        big[off + i] = '!';
        say_p("memchr.sweep", big, memchr(big + off, '!', len));
        big[off + i] = save; } }

 return 0; }
