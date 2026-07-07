#ifndef _AI_SYS_MMAN_H
#define _AI_SYS_MMAN_H
#define PROT_NONE  0
#define PROT_READ  1
#define PROT_WRITE 2
#define PROT_EXEC  4
#define MAP_PRIVATE   2
#define MAP_ANONYMOUS 32
#define MAP_ANON      32
#define MAP_FAILED ((void*)(-1))
void *mmap(void*, long, int, int, int, long);
int munmap(void*, long);
int mprotect(void*, long, int);
#endif
