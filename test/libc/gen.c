/* libgen's basename and dirname (posix's, writing into their argument), isascii and toascii,
 * and fgetpos / fsetpos round-tripping a position through a file */
#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include <libgen.h>
#include "say.h"

int main(void) {
  char const *c[] = {"", "/", "//", "///", "a", "a/", "a//", "/a", "//a", "///a", "a/b", "a/b/", "/a/b//",
                     "./x", "../", "a//b", "/usr/lib/x.so", ".", ".."};
  for (unsigned i = 0; i < sizeof c / sizeof *c; i++) {
    char b[64], d[64];
    strcpy(b, c[i]); strcpy(d, c[i]);
    say_s("path", c[i]); say_s("  basename", basename(b)); say_s("  dirname", dirname(d)); }
  say_s("basename.null", basename(0)); say_s("dirname.null", dirname(0));
  for (int k = -2; k < 260; k += 7) { say_n("isascii", isascii(k) != 0); say_n("toascii", toascii(k)); }
  FILE *f = tmpfile();
  if (!f) { say_s("tmpfile", "none"); return 1; }
  fputs("hello, positions\n", f);
  fpos_t p;
  fseek(f, 7, SEEK_SET);
  say_n("fgetpos", fgetpos(f, &p));
  fseek(f, 0, SEEK_END);
  say_n("fsetpos", fsetpos(f, &p));
  char buf[16] = {0};
  say_n("fread", (long) fread(buf, 1, 9, f)); say_s("read", buf);
  say_n("ftell", ftell(f));
  fclose(f);
  return 0; }
