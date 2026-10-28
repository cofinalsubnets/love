// vfs.h -- the tree under inle's namespace (kmain.c) and the host's /love (lovefs.c): entries
// over baked rows, copied to the heap at the first write. paths are canonical, "" the root; a
// directory is an entry that says so, or a prefix something lives under
#pragma once
#include <stdint.h>
#include <stdbool.h>
#include "archive/srctree.h"

struct vfs_file { char const *path, *bytes; uintptr_t len, ms; };   // a baked row
struct vfs_brow { struct vfs_file f; struct tree_row const *tree; };
struct vfs_ent {
 char const *path;                 // the canonical key
 int bake;                         // the baked row backing reads until the first write; -1 none
 unsigned char *bytes;
 uintptr_t len, cap, ms, mode;     // mode is the permission bits; stat lays the kind over them
 int refs;                         // open fds; an unlinked entry frees at the last close
 char const *to;                   // a symlink's target, canonical and heap; NULL is not one
 bool own, heap, dir, live; };     // own: bytes are a heap copy (or empty); heap: so is path
struct vfs {
 struct tree src;                  // the carried tree
 struct vfs_brow const *bakes;     // its rows under the seat's prefix, then a plain tar's
 int bakes_n;
 struct vfs_file const *extra;     // rows a seat links in, behind the baked ones
 int extra_n;
 struct vfs_ent *ents;
 int n, cap;
 char cwd[256];                    // canonical, what relative paths resolve against
 uintptr_t cwd_n;
 char const *ro;                   // the read-only mount, its name canonical; NULL none
 char const *const *pins;          // specials a move or removal leaves be
 uintptr_t npins;
 void *(*grab)(uintptr_t);         // bytes, kept until drop
 void (*drop)(void*);
 uintptr_t (*now)(void); };        // ms, for what a write or create stamps

// the carried source's rows under pre ("love"), then a plain ustar's, unprefixed -> false on memory
bool vfs_untar(struct vfs *v, char const *pre, unsigned char const *z, uintptr_t zn,
               unsigned char const *tar, uintptr_t tn);
// the table: one entry per baked and extra row, and room for `more` the seat lays itself,
// zeroed -> the first of those (the count of rows), or -1 on memory
int vfs_lay(struct vfs *v, int more);

struct vfs_file const *vfs_bake_row(struct vfs const *v, int i);
unsigned char const *vfs_bake_bytes(struct vfs *v, int i);
// entry i's bytes: its heap copy, else the baked ones ("" where a section won't decode);
// vfs_size decodes nothing
unsigned char const *vfs_blob(struct vfs *v, int i, uintptr_t *len);
uintptr_t vfs_size(struct vfs const *v, int i);

// a path against the cwd into out (cap 256) -> its canonical length, -1 too long
intptr_t vfs_canon(struct vfs const *v, char const *p, uintptr_t pn, char *out);
// links followed at every component, the last only when leaf -> the canonical length,
// -ENAMETOOLONG or -ELOOP
intptr_t vfs_walk(struct vfs const *v, char const *p, uintptr_t pn, char *out, bool leaf);
bool vfs_ro(struct vfs const *v, char const *cp, uintptr_t cn);
bool vfs_pinned(struct vfs const *v, char const *cp, uintptr_t cn);
int vfs_find(struct vfs const *v, char const *p, uintptr_t n);

// entry i's next component under a prefix of pn bytes, NULL when it does not lie under it
char const *vfs_entry(struct vfs const *v, int i, char const *p, uintptr_t pn, uintptr_t *len);
// anything live under the prefix, and the newest date beneath it
bool vfs_kids(struct vfs const *v, char const *p, uintptr_t pn, uintptr_t *ms);
bool vfs_dirp(struct vfs const *v, char const *p, uintptr_t pn);
// the next distinct name under a directory from entry *cur on (0 to start) -> its first
// entry, *cur past it; -1 after the last. a whole listing walks the table once
int vfs_child(struct vfs const *v, char const *p, uintptr_t pn, int *cur, char const **name,
              uintptr_t *len, bool *dir);
// a path's kind and stamp: 0 none, 1 a file, 2 a directory, 3 a link; *i its entry or -1
struct vfs_st { int i, kind; uintptr_t size, mode, ms; };
int vfs_stat(struct vfs *v, char const *cp, uintptr_t cn, struct vfs_st *st);

int vfs_parent_ok(struct vfs const *v, char const *p, uintptr_t n);
int vfs_slot(struct vfs *v);
char *vfs_strdup(struct vfs *v, char const *p, uintptr_t n);
void vfs_gc(struct vfs *v, int i);
int vfs_create(struct vfs *v, char const *p, uintptr_t n, bool dir, uintptr_t mode);
bool vfs_fit(struct vfs *v, int i, uintptr_t need);
