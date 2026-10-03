/* libgen's basename and dirname (posix's, writing into their argument), isascii and toascii,
 * fgetpos / fsetpos and fseeko / ftello round-tripping a position through a file, and the
 * stdio_ext queries both libcs answer alike: pending output, reading or writing, and a
 * directory stream over an open fd, read twice across a rewind */
#define _GNU_SOURCE
#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include <libgen.h>
#include <stdio_ext.h>
#include <dirent.h>
#include <stdint.h>
#include <sys/mman.h>
#include <stdlib.h>
#include <errno.h>
#include <fcntl.h>
#include <unistd.h>
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
  say_n("fseeko", fseeko(f, 2, SEEK_SET)); say_n("ftello", (long) ftello(f));
  fclose(f);
  FILE *w = fopen("/dev/null", "w");
  say_n("fwriting", __fwriting(w) != 0); say_n("freading.w", __freading(w) != 0);
  fputs("abc", w);
  say_n("fpending", (long) __fpending(w));
  fflush(w); say_n("fpending.flushed", (long) __fpending(w));
  say_n("ferror", ferror(w) != 0);
  fclose(w);
  FILE *r = fopen("/dev/null", "r");
  say_n("freading", __freading(r) != 0); say_n("fwriting.r", __fwriting(r) != 0);
  fclose(r);
  say_n("INT_FAST8_MIN", INT_FAST8_MIN); say_n("INT_FAST16_MIN", INT_FAST16_MIN);
  say_n("INT_FAST32_MAX", INT_FAST32_MAX); say_n("INT_FAST64_MIN", INT_FAST64_MIN);
  say_n("UINT_FAST16_MAX.top", (long) (UINT_FAST16_MAX >> 1)); say_n("UINT_FAST8_MAX", UINT_FAST8_MAX);
  say_n("fast.sizes", (long) (sizeof(int_fast8_t) * 1000 + sizeof(int_fast16_t) * 100 + sizeof(int_fast32_t) * 10 + sizeof(int_fast64_t)));
  { fflush(stdout); say_n("dprintf", dprintf(1, "[%s %d]\n", "fd", 42));
    void *mp = mmap(0, 4096, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    say_n("msync", msync(mp, 4096, MS_SYNC)); say_n("msync.async", msync(mp, 4096, MS_ASYNC));
    say_n("MS_", MS_ASYNC * 100 + MS_INVALIDATE * 10 + MS_SYNC); munmap(mp, 4096); }
  { FILE *a = tmpfile(), *b = tmpfile(); fputs("copied across", a); fflush(a); rewind(a);
    long n = copy_file_range(fileno(a), 0, fileno(b), 0, 100, 0);
    char cb[32] = {0}; pread(fileno(b), cb, sizeof cb - 1, 0);
    say_n("copy_file_range", n); say_s("copied", cb); fclose(a); fclose(b); }
  { char sm[2]; char *g = getcwd(sm, sizeof sm); say_n("getcwd.small", g == 0 && errno == ERANGE);
    errno = 0; g = getcwd(sm, 0); say_n("getcwd.size0", g == 0 && errno == EINVAL);
    g = getcwd(0, 0); char *h = getcwd(0, 4096);
    say_n("getcwd.alloc", g && h && strcmp(g, h) == 0); free(g); free(h); }
  int fd = open("/", O_RDONLY);
  DIR *d = fdopendir(fd);
  say_n("fdopendir", d != 0); say_n("dirfd", dirfd(d) == fd);
  int a = 0, b = 0;
  while (readdir(d)) a++;
  rewinddir(d);
  while (readdir(d)) b++;
  say_n("rewinddir", a > 2 && a == b);
  say_n("closedir", closedir(d));
  int nf = open("/dev/null", O_RDONLY);
  say_n("fdopendir.file", fdopendir(nf) == 0);
  close(nf);
  return 0; }
