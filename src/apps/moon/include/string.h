#pragma once
#ifndef NULL
#define NULL ((void*)0)
#endif
typedef unsigned long size_t;
void *memcpy(void*, void const*, size_t), *memmove(void*, void const*, size_t),
     *memset(void*, int, size_t);
int   memcmp(void const*, void const*, size_t);
void *memchr(void const*, int, size_t);
void *mempcpy(void*, void const*, size_t);      /* gnu: memcpy answering the end */
void *rawmemchr(void const*, int);              /* gnu: memchr with no bound */
void *memmem(void const*, size_t, void const*, size_t);   /* gnu: the first needle */
void *memccpy(void*, void const*, int, size_t);
size_t strlen(char const*);
int strcmp(char const*, char const*), strncmp(char const*, char const*, size_t),
    strcasecmp(char const*, char const*), strncasecmp(char const*, char const*, size_t);
int   ffs(int);           /* strings.h's, which glibc's string.h reaches too */
int ffsl(long), ffsll(long long);
char *strcasestr(char const*, char const*), *strcpy(char*, char const*),
     *strncpy(char*, char const*, size_t), *strcat(char*, char const*), *strchr(char const*, int),
     *strrchr(char const*, int), *strstr(char const*, char const*), *strdup(char const*),
     *strndup(char const*, size_t);
size_t strnlen(char const*, size_t);
char *strerror(int);
int   strerror_r(int, char*, size_t);          /* xsi: 0 or ERANGE */
size_t strlcpy(char*, char const*, size_t), strlcat(char*, char const*, size_t),
       strspn(char const*, char const*), strcspn(char const*, char const*);
char *strpbrk(char const*, char const*), *strtok(char*, char const*),
     *strtok_r(char*, char const*, char**), *strsep(char**, char const*),
     *strchrnul(char const*, int), *strncat(char*, char const*, size_t);
int strcoll(char const*, char const*);
