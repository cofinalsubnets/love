/* the filesystem's names: glob over a small tree laid in a fresh directory, with marks, a
 * trailing /, hidden names, escapes, nocheck, offsets and appends; realpath through symlinks,
 * . and .., and its errors. every path is printed relative to the tree */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <unistd.h>
#include <fcntl.h>
#include <glob.h>
#include <sys/stat.h>
#include "say.h"

static char top[64];
static void touch(char const *p) { int fd = open(p, O_WRONLY | O_CREAT, 0644); if (fd >= 0) close(fd); }
static void gl(char const *p, int f) {
  glob_t g;
  memset(&g, 0, sizeof g);
  int r = glob(p, f, 0, &g);
  s_put("glob "); s_put(p); say_n(" rc", r);
  for (size_t i = 0; r == 0 && i < g.gl_pathc; i++) say_s("  ", g.gl_pathv[i]);
  if (!r) globfree(&g); }
static void rp(char const *p) {
  char b[4096];
  errno = 0;
  char *r = realpath(p, b);
  size_t n = strlen(top);
  s_put("realpath "); s_put(p);
  say_s("", !r ? 0 : strncmp(r, top, n) ? r : r + n);
  say_n("  errno", r ? 0 : errno); }

int main(void) {
  strcpy(top, "/tmp/lpathXXXXXX");
  if (!mkdtemp(top) || chdir(top)) { say_n("mkdtemp", -1); return 1; }
  char real[4096];
  if (realpath(".", real)) strcpy(top, real);             /* /tmp may itself be a link */
  mkdir("a", 0755); mkdir("a/b", 0755); mkdir("c", 0755); mkdir(".h", 0755);
  touch("a/x.c"); touch("a/y.c"); touch("a/b/z.c"); touch("c/w.c"); touch(".h/q.c"); touch("k"); touch("a*b");
  symlink("a", "la"); symlink("../c", "a/up"); symlink("loop2", "loop1"); symlink("loop1", "loop2");
  gl("*", 0); gl("*", GLOB_MARK); gl("*/*.c", 0); gl(".*", 0); gl("*/", 0); gl("[ab]*/*", 0);
  gl("zz*", 0); gl("zz*", GLOB_NOCHECK); gl("a/x.c", 0); gl("a/q.c", 0); gl("la/*", 0);
  gl("\\a/*", 0); gl("a\\*b", 0); gl("a\\*b", GLOB_NOESCAPE); gl("*/b/*", 0); gl("c/?.c", GLOB_NOSORT);
  { glob_t g; memset(&g, 0, sizeof g); g.gl_offs = 2;
    glob("c/*", GLOB_DOOFFS, 0, &g); glob("a/*.c", GLOB_DOOFFS | GLOB_APPEND, 0, &g);
    say_u("offs.count", (unsigned long) g.gl_pathc);
    say_n("offs.nulls", !g.gl_pathv[0] && !g.gl_pathv[1]);
    for (size_t i = 0; i < g.gl_pathc; i++) say_s("  ", g.gl_pathv[2 + i]);
    say_n("offs.end", !g.gl_pathv[2 + g.gl_pathc]);
    globfree(&g); }
  rp("la/up/w.c"); rp("a/../la/./b//z.c"); rp("la"); rp("nope"); rp("a/nope"); rp("k/x"); rp("loop1");
  rp("/"); rp("."); rp("a/b/../../c/"); rp("");
  { char *m = realpath("a/b", 0); say_s("realpath.alloc", m ? m + strlen(top) : 0); free(m); }
  /* the tree goes away again */
  char const *rm[] = { "a/x.c", "a/y.c", "a/b/z.c", "c/w.c", ".h/q.c", "k", "a*b", "la", "a/up", "loop1", "loop2", 0 };
  for (int i = 0; rm[i]; i++) unlink(rm[i]);
  rmdir("a/b"); rmdir("a"); rmdir("c"); rmdir(".h");
  chdir("/"); say_n("cleanup", rmdir(top));
  return 0; }
