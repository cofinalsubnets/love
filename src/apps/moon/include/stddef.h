#ifndef _LOVE_STDDEF_H
#define _LOVE_STDDEF_H
typedef unsigned long size_t;
typedef long ssize_t;
typedef long ptrdiff_t;
#ifdef __WCHAR_TYPE__
typedef __WCHAR_TYPE__ wchar_t;   /* the ABI's, or -fshort-wchar's unsigned short */
#else
typedef int  wchar_t;
#endif
#define NULL ((void*)0)
#define offsetof(t, m) ((size_t) &(((t*)0)->m))
#endif
