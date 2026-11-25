/* stdarg.h for mooncc: the target's real va_list, laid as gcc's so variadics link across
 * compilers: an array of one on x64 and a64, a struct on arm, a pointer on i386, riscv and mips. */
#pragma once

typedef __builtin_va_list __gnuc_va_list;

/* glibc headers we do not carry spell the type __gnuc_va_list */
#ifndef __GNUC_VA_LIST
#define __GNUC_VA_LIST
#endif
typedef __gnuc_va_list va_list;

#define va_start(ap, last) __builtin_va_start(ap, last)
#define va_arg(ap, type)   __builtin_va_arg(ap, type)
#define va_end(ap)         __builtin_va_end(ap)
#define va_copy(dst, src)  __builtin_va_copy(dst, src)
