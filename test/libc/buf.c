/* stdio's buffering edges: the fill boundary at every alignment. an overrun still writes
 * the right bytes (the run past the buffer is what gets flushed), so a guard after the
 * buffer is read back: its count names the fault, the payload cannot. setvbuf once, small,
 * puts the boundary 128 times in 20 kB. the law: a full buffer is drained at once, or a
 * `len == cap` test never matches again; fputc drains on the filling byte, so the sweep
 * pairs it with fwrite/fputs landing flush against the end. */
#include <stdio.h>
#include <string.h>
#include "say.h"

#define CAP 64
#define GUARD 64

/* adjacency is the instrument: all-char members, so no padding may come between */
static struct { char buf[CAP]; char guard[GUARD]; } G;

static int touched(void) {
 int n = 0;
 for (int i = 0; i < GUARD; i++)
  if (G.guard[i]) n++;
 memset(G.guard, 0, GUARD);
 return n; }

int main(void) {
 int over = 0;

 setvbuf(stdout, G.buf, _IOFBF, CAP);
 memset(G.guard, 0, GUARD);

 /* the exact-fill matrix: k single bytes, then a w-byte block. some (k,w)
    lands the buffer flush against its end, which is the whole point. */
 for (int k = 0; k <= CAP + 4; k++)
  for (int w = 1; w <= 8; w++) {
   char blk[8];
   for (int i = 0; i < w; i++) blk[i] = (char) ('A' + i);
   for (int i = 0; i < k; i++) putchar('a' + i % 26);
   fwrite(blk, 1, (size_t) w, stdout);
   putchar('!');            /* the byte that would land past the end */
   putchar('\n');
   fflush(stdout);
   over += touched(); }

 /* the same boundary through fputs, whose length the caller never states */
 for (int k = 0; k <= CAP + 4; k++) {
  for (int i = 0; i < k; i++) putchar('.');
  fputs("wxyz", stdout);
  putchar('!');
  putchar('\n');
  fflush(stdout);
  over += touched(); }

 /* the direct lane: a block at or over the capacity bypasses the buffer,
    and must still order itself behind whatever is already sitting in it */
 for (int k = 0; k <= 3; k++) {
  char big[CAP * 2];
  for (int i = 0; i < CAP * 2; i++) big[i] = (char) ('0' + i % 10);
  for (int i = 0; i < k; i++) putchar('<');
  say_u("direct.items", (unsigned long) fwrite(big, 1, CAP, stdout));
  say_u("direct.items", (unsigned long) fwrite(big, 1, CAP * 2, stdout));
  say_u("direct.items", (unsigned long) fwrite(big, CAP, 2, stdout));
  putchar('\n');
  fflush(stdout);
  over += touched(); }

 /* the answers the standard does fix, at the edges around the boundary */
 say_u("fwrite.zero.count", (unsigned long) fwrite("x", 1, 0, stdout));
 say_u("fwrite.zero.size", (unsigned long) fwrite("x", 0, 1, stdout));
 say_n("fputs.ok", fputs("", stdout) >= 0 ? 0 : -1);
 say_n("fflush.ok", fflush(stdout));
 say_n("ferror", ferror(stdout) ? 1 : 0);

 /* the real verdict. zero under any correct libc; nonzero says the stream
    wrote past the buffer it was handed, whatever the payload above looked like. */
 say_n("guard.bytes.written", over);

 return 0; }
