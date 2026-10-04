// srctree.h -- the carried source as a container (src/tools/selfpack.l cuts it): a header, an
// index, and sections of tar that decode into RAM at their first read. the sections joined are
// the exact tar the tree cuts to. the host's /love (src/love/lovefs.c), the carried-source bake
// (main.c) and the kernel's ramfs (src/inle/kmain.c) all read through here, each with its own
// struct and allocator.
//
// little-endian throughout:
//   "lovetree"  u32 nsec  then nsec rows of  name[8] u32 codec, raw, packed, crc32
//   then the packed sections back to back, the index first. an index record is
//   u8 sec, u8 kind ('0' file, '2' link), u16 mode, u32 off, len, mtime  path NUL  target NUL
//   off is where the member's bytes start in its section, path is tree-relative.
#ifndef SRCTREE_H
#define SRCTREE_H
#include <stdint.h>
#include <stdbool.h>

#define TREE_SECS 8
enum { tree_stored, tree_deflate, tree_bzip2, tree_lzma2 };

struct tree_sec { char name[9]; uint32_t codec, raw, packed, crc;
                     unsigned char const *z; unsigned char *bytes; };
// a link row takes its target's place once open has chased it (to NULL); one that dangles drops
struct tree_row { char const *path, *to; uint32_t sec, off, len, mtime, mode; };
struct tree {
  struct tree_sec s[TREE_SECS];
  uint32_t ns;
  struct tree_row *rows;
  uintptr_t n;
  void *(*grab)(uintptr_t); };   // bytes for a decoded section, kept for good

// parse the header, decode the index and lay the rows. false for no container, a torn one,
// or no memory; t is then not to be read.
bool tree_open(struct tree *t, unsigned char const *z, uintptr_t zn, void *(*grab)(uintptr_t));
// section i's bytes, decoded and checked at the first ask -> NULL where that fails
unsigned char const *tree_sec(struct tree *t, uint32_t i);
// a row's bytes, its section decoded on the way -> NULL where that fails
unsigned char const *tree_bytes(struct tree *t, struct tree_row const *r);
// the section of that name -> its number, or -1
intptr_t tree_named(struct tree const *t, char const *name);
// the row at a tree-relative path (n bytes) -> its number, or -1
intptr_t tree_find(struct tree const *t, char const *p, uintptr_t n);
// codec's packed bytes into exactly cap of out -> cap, or -1
intptr_t tree_decode(uint32_t codec, unsigned char const *z, uintptr_t zn,
                        unsigned char *out, uintptr_t cap);
#endif
