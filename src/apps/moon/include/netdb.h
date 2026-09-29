#ifndef _AI_NETDB_H
#define _AI_NETDB_H
#include <sys/socket.h>
/* glibc field order: the four ints, addrlen, then ADDR before canonname */
struct addrinfo {
  int ai_flags;
  int ai_family;
  int ai_socktype;
  int ai_protocol;
  socklen_t ai_addrlen;
  struct sockaddr *ai_addr;
  char *ai_canonname;
  struct addrinfo *ai_next;
};
#define AI_PASSIVE     1
#define AI_CANONNAME   2
#define AI_NUMERICHOST 4
int  getaddrinfo(char const*, char const*, struct addrinfo const*, struct addrinfo**);
void freeaddrinfo(struct addrinfo*);
char const *gai_strerror(int);
#endif
