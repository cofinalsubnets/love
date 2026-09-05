// ustar.h -- decoding the carried source blob (src/host/src.c's ai_srcgz): a gzip member
// wrapping a ustar archive. two callers WALK it differently and decode it identically --
// the first boot (main.c) mmaps and wants one member, the kernel's ram fs (kmain.c)
// kmallocs and wants every one -- so the walk stays theirs and the header reading is here.
#ifndef AI_USTAR_H
#define AI_USTAR_H
#include <stdint.h>
#include <stdbool.h>

// the gzip frame: check the magic, step the optional fields, and answer where the raw
// deflate stream starts and what ISIZE says it inflates to. the caller allocates.
bool ai_gz_body(unsigned char const *z, uintptr_t zn, uintptr_t *off, uintptr_t *isize);

// a ustar header field, octal, NUL/space terminated -- size at +124, mtime at +136.
uintptr_t ai_ustar_octal(unsigned char const *p, int n);

// is this header one of ours: ustar-branded, and a plain file or a symlink. the
// archive carries directories too and neither caller has a use for them.
bool ai_ustar_member(unsigned char const *h);
#define ai_ustar_islink(h) ((h)[156] == '2')

// the member's path, prefix and name joined, with the archive's TOP component
// stripped -- the tree looks the same from inside as a checkout does. -> the length.
uintptr_t ai_ustar_name(unsigned char const *h, char *out, uintptr_t cap);

// a symlink member's target, verbatim. -> the length.
uintptr_t ai_ustar_link(unsigned char const *h, char *out, uintptr_t cap);

// walk a path (pn bytes) onto the canonical base already in out (n bytes, "" the root):
// "." holds, ".." pops, doubled and trailing slashes fall away. -> the new length, or -1
// for one longer than cap carries (a NUL counted). the ramfs cwd walk and the link join
// below are both this.
intptr_t ai_path_canon(char *out, uintptr_t n, char const *p, uintptr_t pn, uintptr_t cap);

// join a symlink's target against the link's own directory. an explicit base and no cwd,
// because neither caller has one. -> the length; 0 for a target too long to carry, so the
// link resolves to nothing rather than to a truncated name.
uintptr_t ai_lnk_canon(char const *at, char const *ln, char *out, uintptr_t cap);
#endif
