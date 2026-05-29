#include <stddef.h>
void *memchr(void const*, int, size_t);
static char const spaces[] = " \n\t\v\r\f";
int isspace(int c) { return !!memchr(spaces, c, 6); }
int tolower(int c) { return c + ('A' <= c && c <= 'Z' ? 'a' - 'A' : 0); }
int toupper(int c) { return c + ('a' <= c && c <= 'z' ? 'A' - 'a' : 0); }
