// port/fdrow.h -- the raw-fd rows, which host/fd.c owns on a hosted seat and no bare port
// can take from it: fd.c is poll.h and signal.h deep. love's io ops speak a bare fd as
// well as a port, and a bare seat has one row, the console -- 0 in, 1 and 2 out, nothing
// else. included once, after the seat spells fd_readn and fd_writen, the two names every
// bare seat's vtable already carries -- the four boards and the wasm host.
// >0 landed, 0 busy, -1 gone is the PORT protocol and not read(2)'s, and a live console is
// never gone: a dry read answers 0, exactly what the vtable's own reader answers.
intptr_t ai_fd_readn(struct ai *g, int fd, unsigned char *dst, uintptr_t n) {
  return fd ? -1 : fd_readn(g, dst, n); }

uintptr_t ai_fd_say(int fd, unsigned char const *src, uintptr_t n) {
  return fd == 1 || fd == 2 ? (uintptr_t) fd_writen(NULL, src, n) : 0; }
