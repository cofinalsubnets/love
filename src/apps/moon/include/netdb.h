#pragma once
#include <stddef.h>
#include <sys/socket.h>
/* glibc's field order: ai_addr before ai_canonname */
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
/* glibc's error numbers */
#define EAI_BADFLAGS (-1)
#define EAI_NONAME   (-2)
#define EAI_AGAIN    (-3)
#define EAI_FAIL     (-4)
#define EAI_FAMILY   (-6)
#define EAI_SOCKTYPE (-7)
#define EAI_SERVICE  (-8)
#define EAI_MEMORY   (-10)
#define EAI_SYSTEM   (-11)
int  getaddrinfo(char const*, char const*, struct addrinfo const*, struct addrinfo**);
void freeaddrinfo(struct addrinfo*);
char const *gai_strerror(int);
/* the old resolver: _r lays its answer in the caller's buffer, the plain one in libc's,
 * the next call's to overwrite */
struct hostent {
  char *h_name;
  char **h_aliases;
  int h_addrtype;
  int h_length;
  char **h_addr_list;
};
#define h_addr h_addr_list[0]
#define HOST_NOT_FOUND 1
#define TRY_AGAIN      2
#define NO_RECOVERY    3
#define NO_DATA        4
extern int h_errno;
struct hostent *gethostbyname(char const*);
int gethostbyname_r(char const*, struct hostent*, char*, size_t, struct hostent**, int*);
