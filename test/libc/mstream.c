/* open_memstream: the pointer and size follow every flush and close, the buffer grows past
 * any first guess, stays nul-terminated, and is the caller's after fclose */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "say.h"

int main(void) {
  char *b = 0;
  size_t n = 99;
  FILE *f = open_memstream(&b, &n);
  say_n("open", f != 0);
  fflush(f);
  say_u("empty.size", (unsigned long) n);
  say_s("empty", b);
  fprintf(f, "hello %d %s", 42, "there");
  fflush(f);
  say_u("size", (unsigned long) n);
  say_s("text", b);
  unsigned long sum = 0;
  for (int i = 0; i < 5000; i++) fputc('a' + i % 26, f);
  fwrite("tail", 1, 4, f);
  say_n("tell", ftell(f));
  fclose(f);
  for (size_t i = 0; i < n; i++) sum = sum * 31 + (unsigned char) b[i];
  say_u("grown.size", (unsigned long) n);
  say_u("grown.sum", sum);
  say_n("nul", b[n] == 0);
  say_s("end", b + n - 4);
  free(b);
  /* one fputs bigger than every buffer so far */
  char big[20000];
  memset(big, 'z', sizeof big - 1); big[sizeof big - 1] = 0;
  f = open_memstream(&b, &n);
  fputs(big, f); fputc('!', f);
  fclose(f);
  say_u("big.size", (unsigned long) n);
  say_n("big.last", b[n - 1]);
  say_n("big.same", memcmp(b, big, sizeof big - 1) == 0);
  free(b);
  return 0; }
