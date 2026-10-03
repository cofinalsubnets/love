/* a read stream reads ahead of its fd, and the stream's position is still the one a program sees:
 * ftell and fseek count the read-ahead and the pushback, an input fflush puts the fd back where
 * the stream stands (gnulib's fflush probe, whole), and fread, getc, ungetc and fgets interleave */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdio_ext.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include "say.h"

int main(void) {
  char path[] = "/tmp/rbufXXXXXX";
  int w = mkstemp(path);
  if (w < 0) return 1;
  char text[10000];
  for (int i = 0; i < (int) sizeof text; i++) text[i] = 'a' + i % 23;
  if (write(w, text, sizeof text) != (long) sizeof text) return 1;
  close(w);
  FILE *f = fopen(path, "r");
  int fd = fileno(f);
  char b[16] = {0};
  say_n("fread", (long) fread(b, 1, 5, f)); say_s("got", b);
  say_n("ahead.fd", lseek(fd, 0, SEEK_CUR) > 5);
  say_n("ftell", ftell(f));
  say_n("fflush", fflush(f)); say_n("fseek.cur", fseek(f, 0, SEEK_CUR));
  say_n("fd.after", lseek(fd, 0, SEEK_CUR));
  int c = fgetc(f); ungetc(c, f); fflush(f);
  say_n("backup.ungetc", fgetc(f) == c);
  c = fgetc(f); ungetc('@', f); fflush(f);
  say_n("other.ungetc", fgetc(f) == c);
  say_n("ftell.2", ftell(f));
  ungetc('#', f); say_n("ftell.unget", ftell(f)); say_n("getc.unget", fgetc(f));
  say_n("fseek.set", fseek(f, 4090, SEEK_SET));
  memset(b, 0, sizeof b); say_n("fread.edge", (long) fread(b, 1, 12, f)); say_s("edge", b);
  say_n("fseek.back", fseek(f, -6, SEEK_CUR)); say_n("getc.back", fgetc(f)); say_n("ftell.back", ftell(f));
  static char big[3000];
  say_n("fread.big", (long) fread(big, 1, sizeof big, f)); say_n("big.ok", memcmp(big, text + 4097, sizeof big) == 0);
  say_n("ftell.big", ftell(f));
  char line[64];
  say_n("fgets", fgets(line, 20, f) != 0); say_n("fgets.len", (long) strlen(line));
  while (fgetc(f) != EOF) ;
  say_n("feof", feof(f) != 0); say_n("ftell.end", ftell(f));
  rewind(f); say_n("rewound", fgetc(f)); say_n("feof.cleared", feof(f));
  fclose(f);
  int fds[2];
  if (pipe(fds)) return 1;
  if (write(fds[1], "pipe text\n", 10) != 10) return 1;
  close(fds[1]);
  FILE *p = fdopen(fds[0], "r");
  say_n("pipe.getc", fgetc(p)); say_n("pipe.fflush", fflush(p)); say_n("pipe.next", fgetc(p));
  fclose(p);
  unlink(path);
  return 0; }
