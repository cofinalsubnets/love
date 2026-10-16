// FIXME this file is too short
// fdrow.h -- the raw-fd rows for a bare build, where fd.c can't go: the console alone, 0 in,
// 1 and 2 out. included once, after the board spells fd_readn and fd_writen.
// answers are the port protocol (>0 landed, 0 busy, -1 gone), not read(2)'s: a dry console reads 0
intptr_t love_fd_readn(struct g *g, int fd, unsigned char *dst, uintptr_t n) {
  return fd ? -1 : fd_readn(g, dst, n); }

uintptr_t love_fd_say(int fd, unsigned char const *src, uintptr_t n) {
  return fd == 1 || fd == 2 ? (uintptr_t) fd_writen(NULL, src, n) : 0; }
