// bput.h -- text and numbers onto a byte sink, for the doors that talk on the wire alone:
// the kernel's probes and panic console, the boards' fault reports and batteries. put is
// the sink, one byte a call. no division wider than a word, so a thumb board needs no helper.
#pragma once
#include <stdint.h>

static inline void bput_s(void (*put)(int), char const *s) { while (*s) put(*s++); }

// v in base 2..16, no padding
static inline void bput_n(void (*put)(int), uintptr_t v, unsigned base) {
  char b[8 * sizeof v]; int i = 0;
  do b[i++] = "0123456789abcdef"[v % base], v /= base; while (v);
  while (i) put(b[--i]); }

// the low nd hex digits of v, zeros kept: a register's full width
static inline void bput_x(void (*put)(int), uintptr_t v, int nd) {
  while (nd--) put("0123456789abcdef"[(v >> 4 * nd) & 15]); }
