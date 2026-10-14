/* test/kernel/c/cat.c -- cat in C, read(2) and write(2) alone: each file named, or stdin */
#include <fcntl.h>
#include <unistd.h>

static int pour(int fd) {
  char b[4096];
  for (long n; (n = read(fd, b, sizeof b)) != 0;) {
    if (n < 0) return 1;
    for (long at = 0, w; at < n; at += w)
      if ((w = write(1, b + at, (size_t) (n - at))) <= 0) return 1; }
  return 0; }

int main(int argc, char **argv) {
  if (argc < 2) return pour(0);
  int r = 0;
  for (int i = 1; i < argc; i++) {
    int fd = open(argv[i], O_RDONLY);
    if (fd < 0) { write(2, "cat: cannot open\n", 17); r = 1; continue; }
    r |= pour(fd);
    close(fd); }
  return r; }
