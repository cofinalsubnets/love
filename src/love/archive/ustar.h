// ustar.h -- reading ustar headers and walking paths: the kernel's rootfs (src/inle/kmain.c)
// and the carried source's links (src/love/archive/srctree.c). the walks stay their callers'.
#pragma once
#include <stdint.h>
#include <stdbool.h>

// a ustar header field, octal, NUL/space terminated -- size at +124, mtime at +136
uintptr_t ustar_octal(unsigned char const *p, int n);

// ustar-branded, and a plain file or a symlink: directories are skipped
bool ustar_member(unsigned char const *h);
#define ustar_islink(h) ((h)[156] == '2')

// prefix and name joined, the archive's top component stripped -> the length
uintptr_t ustar_name(unsigned char const *h, char *out, uintptr_t cap);

// a symlink member's target, verbatim -> the length
uintptr_t ustar_link(unsigned char const *h, char *out, uintptr_t cap);

// walk p (pn bytes) onto the canonical base in out (n bytes, "" the root): "." holds, ".." pops,
// extra slashes fall away -> the new length, or -1 past cap (a NUL counted)
intptr_t path_canon(char *out, uintptr_t n, char const *p, uintptr_t pn, uintptr_t cap);

// a symlink's target joined against the link's directory -> the length; 0 when too long,
// so the link resolves to nothing rather than a truncated name
uintptr_t lnk_canon(char const *at, char const *ln, char *out, uintptr_t cap);
