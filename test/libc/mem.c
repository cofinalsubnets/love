/* the mem* five. moonlibc copies WORD-WIDE where the pointers agree and falls to
 * bytes where they do not, so every case here is run at several alignments and
 * across the word boundary -- an off-by-one in the wide lane hides completely at
 * offset 0. this battery is 64-bit only, and the wide lane is written against
 * sizeof(long): what proves the 32-bit stride is the thumb boards booting
 * (test_mps2, test_mps2_t1), since moonlibc is their libc too. */
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
    dest > src must copy BACKWARD or it eats its own tail. --- */
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

 fill(buf, 40, 0);
 memmove(buf, buf, 20);                        /* exactly equal: a no-op */
 say_b("memmove.eq", buf, 24);

 /* --- memcmp: the SIGN only (see say.h), at every alignment, with the
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
 /* INDEPENDENT offsets. the sweep above moves both pointers together, so the
    two always share an alignment and the word lane always takes -- these are
    what reach it when they do not, and the lengths that cross its step. */
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

 /* the bytes compare as UNSIGNED char: 0x80 is ABOVE 0x7f, not below */
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

 /* the WORD LOOP and its corners: memchr reads a word at a time, so every
  * alignment of the start, every length modulo the word, and a needle at each
  * position in it must answer what a byte walk answers -- including the needle
  * sitting one past the searched span, which must not be found. */
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
