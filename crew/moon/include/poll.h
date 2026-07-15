#ifndef _AI_POLL_H
#define _AI_POLL_H
struct pollfd { int fd; short events; short revents; };
typedef unsigned long nfds_t;
#define POLLIN   1
#define POLLPRI  2
#define POLLOUT  4
#define POLLERR  8
#define POLLHUP 16
#define POLLNVAL 32
int poll(struct pollfd*, nfds_t, int);
#endif
