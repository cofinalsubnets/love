// image.c -- file I/O around snap.c's stdio-free image codec, which the boards link: stdio
// stops here. bake and dump answer 0 or <0; load answers NULL and the caller boots the egg
#define _GNU_SOURCE
#include "love.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <sys/mman.h>

// the scratch beside a bake's target, per process: make -jN bakes one name concurrently
static char *bake_scratch(struct g *g, char const *path) {
  long pid = (long) getpid();
  int n = snprintf(NULL, 0, "%s.bake.%ld", path, pid);
  char *t = n < 0 ? NULL : alloc(NULL, (size_t) n + 1);
  if (t) snprintf(t, (size_t) n + 1, "%s.bake.%ld", path, pid);
  return t; }

// a profile's text -> its numbers in order: hot.prof's "a b" word ranges, hot.calls's "index
// count" rows. *n of them, NULL for none
uint64_t *image_nums(unsigned char const *s, uintptr_t sn, uintptr_t *n) {
  uint64_t *r = NULL, v = 0;
  uintptr_t cap = 0;
  int in = 0;
  *n = 0;
  for (uintptr_t i = 0; i <= sn; i++) {
    int c = i < sn ? s[i] : -1;
    if (c >= '0' && c <= '9') { v = 10 * v + (uint64_t) (c - '0'), in = 1; continue; }
    if (!in) continue;
    if (*n + 1 > cap) {
      uint64_t *t = alloc(NULL, (cap = cap ? 2 * cap : 1024) * sizeof *t);
      if (!t) break;
      if (r) memcpy(t, r, *n * sizeof *t), alloc(r, 0);
      r = t; }
    r[(*n)++] = v, v = 0, in = 0; }
  return r; }

// the one bake to a file. the path is sp[0], a root, read after the dump moves it; noinline
// keeps these buffers out of lvm_bake's frame, which would defeat its tail-jump (make vmret)
love_noinline static int image_put(struct g *g, struct image_opt const *o) {
  uintptr_t len = 0;
  void *buf = image_save2(g, &len, NULL, o);
  if (!buf) return -2;
  char const *path = txt(str(g->sp[0]));          // a love string ends in a NUL
  // beside the target, never on it: a reader mid-write would wake a short image
  char *tmp = bake_scratch(g, path);
  int rc = -4;
  if (tmp) {
    FILE *f = fopen(tmp, "wb");
    rc = !f ? -4 : (fwrite(buf, 1, len, f) == len) ? 0 : -4;
    if (f && fclose(f)) rc = -4;
    if (!rc && rename(tmp, path)) rc = -4;        // atomic: a whole file or none
    if (rc) remove(tmp);
    alloc(tmp, 0); }
  return alloc(buf, 0), rc; }

// `bake PATH`: the path goes on the stack for image_put; the rc rides g->b
struct g *image_dump(struct g *g, char const *path, struct image_opt const *o) {
  g = strof(g, path);
  if (!ok(g)) return core_of(g)->b = -2, g;
  int rc = image_put(g, o);
  g->sp++;
  return g->b = rc, g; }

// the binary's own heap image (doc/misc/snapshot.md). {1}, not {0}, so it lands in PROGBITS,
// never .bss; the bake grows the section, and this stub only gives it an address
#define ReserveWords 2u
__attribute__((section(".love.image"))) uint64_t baked_image[ReserveWords] = {1};
uintptr_t baked_image_len = ReserveWords * 8u;
// a read past the stub's two words is out of the declaration's bounds, in the section's
#if defined(__GNUC__) && !defined(__clang__) && !defined(__mooncc__)
#pragma GCC diagnostic ignored "-Warray-bounds"
#endif
// an unbaked binary's stub is too short to be an image, and the caller boots the egg
int baked_pick(void const **blob, uintptr_t *blen) {
  return *blob = (void const *) baked_image, *blen = baked_image_len,
         baked_image_len > 0; }

#define BakeScratch (64u << 10)                  // the copy window
// n bytes src@soff -> dst@doff through the window
int bake_move(int src, int dst, uint64_t soff, uint64_t doff, uint64_t n, char *win) {
  for (uint64_t z = 0; z < n; ) {
    size_t w = n - z < BakeScratch ? (size_t)(n - z) : BakeScratch;
    if (pread(src, win, w, (off_t)(soff + z)) != (ssize_t) w) return -6;
    if (pwrite(dst, win, w, (off_t)(doff + z)) != (ssize_t) w) return -6;
    z += w; }
  return 0; }

// out NULL bakes in place, a path writes a copy; bare lays the stub back, an imageless binary
int image_bake(struct g *g, char const *out, int bare, struct image_opt const *o) {
  uint64_t stub[ReserveWords] = {1};
  uintptr_t len = sizeof stub;
  void *buf = bare ? NULL : image_save2(g, &len, NULL, o);
  if (!bare && !buf) return -2;
  // the kernel's PATH_MAX
  char exe[4096];
  if (!host_selfpath(exe, sizeof exe)) return alloc(buf, 0), -6;
  char const *to = out ? out : exe;
  char *tmp = bake_scratch(g, to), *win = alloc(NULL, BakeScratch);
  struct stat st;
  int rc = -6, src = tmp ? open(exe, O_RDONLY) : -1, dst;
  if (win && src >= 0 && !fstat(src, &st) && (dst = open(tmp, O_RDWR | O_CREAT | O_TRUNC, 0700)) >= 0) {
    rc = image_lay(src, dst, bare ? (void const *) stub : buf, len, win);
    if (rc > 0) {
      fprintf(stderr, "love: .image is not laid last -- nowhere to grow the image\n");
      rc = -3; }
    if (!rc && (fchmod(dst, st.st_mode & 07777) || fsync(dst))) rc = -6;
    if (close(dst)) rc = -6;
    if (!rc && rename(tmp, to)) rc = -6;          // a new inode: ETXTBSY-proof
    if (rc) unlink(tmp); }
  if (src >= 0) close(src);
  alloc(tmp, 0), alloc(win, 0);
  return alloc(buf, 0), rc; }

// (bake path): `love wake path ..` boots with every global this one pinned. 1 | ()
// FIXME extend LvmCall macro to handle this.
static lvm(lvm_bake) {
 Pack(g);
 word r = cstrp(g->sp[0]) && !image_put(g, NULL) ? putcharm(1) : zero;
 Unpack(g);
 Sp[0] = r;
 love_musttail return Next(1); }

LvDef("bake", bake, 1, NULL);

// why: image_why's answer for a file that does not wake (0 when it is torn past the header)
struct g *image_load(char const *path, int *why) {
  int fd = open(path, O_RDONLY);
  if (fd < 0) return NULL;
  struct stat st;
  struct g *g = NULL;
  if (!fstat(fd, &st) && st.st_size > 0) {        // mapped: no file buffer
    size_t n = (size_t) st.st_size;
    void *buf = mmap(NULL, n, PROT_READ, MAP_PRIVATE, fd, 0);
    if (buf != MAP_FAILED) {
      // older images wear a shebang, padded to a word
      size_t off = 0;
      if (n > 2 && ((char*) buf)[0] == '#' && ((char*) buf)[1] == '!') {
        char *nl = memchr(buf, '\n', n);
        if (nl) off = (size_t)(nl - (char*) buf) + 1; }
      // kept: a woken session keeps the map, so its code and heap chunks wake as first touched
      if (off < n) g = love_image_load((char*) buf + off, (uintptr_t)(n - off), 2);
      if (!g) *why = off < n ? image_why((char*) buf + off, (uintptr_t)(n - off)) : 1, munmap(buf, n); } }
  close(fd);
  return g; }
