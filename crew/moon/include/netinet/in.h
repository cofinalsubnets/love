#ifndef _AI_NETINET_IN_H
#define _AI_NETINET_IN_H
#include <sys/socket.h>
typedef unsigned short in_port_t;
struct in_addr { unsigned int s_addr; };
struct sockaddr_in {
  sa_family_t    sin_family;
  in_port_t      sin_port;      /* network byte order */
  struct in_addr sin_addr;
  char           sin_zero[8];
};
struct in6_addr { unsigned char s6_addr[16]; };
struct sockaddr_in6 {
  sa_family_t     sin6_family;
  in_port_t       sin6_port;
  unsigned int    sin6_flowinfo;
  struct in6_addr sin6_addr;
  unsigned int    sin6_scope_id;
};
#define INADDR_ANY       0
#define INADDR_LOOPBACK  2130706433
#define IPPROTO_TCP 6
#define IPPROTO_UDP 17
unsigned short htons(unsigned short);
unsigned short ntohs(unsigned short);
unsigned int   htonl(unsigned int);
unsigned int   ntohl(unsigned int);
#endif
