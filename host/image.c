// host/image.c -- file I/O around the core's stdio-free image codec (ai_image_save /
// ai_image_load, ai.c). The CORE owns the heap serialization (compact + range-encode a
// {header, blob} buffer, and its inverse); the HOST owns stdio -- so ai.c stays
// freestanding-clean. main.c calls image_bake (--bake: lay the image back into the
// binary's own .image section), image_dump (--bake PATH: write a plain image file), and
// image_load (--wake PATH). Conventions: bake/dump 0 ok / <0 error; load NULL on any
// problem so the caller falls back to a normal egg boot.
#define _GNU_SOURCE
#include "ai.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <link.h>

// the wake-safety guard (doc/wake-storm.md): a kept-absolute pointer only survives a
// wake if it aims inside the MAIN PROGRAM's load segments (one ASLR base delta shifts
// them all). Anything else -- a JIT W^X page, an mmap, a shared library -- dies with
// the bake process, and every post-wake use is a hardware fault the barrier eats per
// call: the storm. Collect the segments once, install the predicate before any dump,
// and on a refused bake print the offenders so the survivor names itself.
extern uintptr_t (*ai_image_absguard)(uintptr_t);
extern uintptr_t ai_image_bad[8];
extern uintptr_t ai_image_nbad;
static struct { uintptr_t lo, hi; } image_segs[16];
static int image_nsegs = 0;
static int image_seg_phdr(struct dl_phdr_info *in, size_t sz, void *d) {
  for (int i = 0; i < in->dlpi_phnum && image_nsegs < 16; i++) {
    const ElfW(Phdr) *p = &in->dlpi_phdr[i];
    if (p->p_type == PT_LOAD) {
      image_segs[image_nsegs].lo = in->dlpi_addr + p->p_vaddr;
      image_segs[image_nsegs].hi = in->dlpi_addr + p->p_vaddr + p->p_memsz;
      image_nsegs++; } }
  return 1;                                       // first object only: the main program
}
static uintptr_t image_abs_ok(uintptr_t v) {
  for (int i = 0; i < image_nsegs; i++)
    if (v >= image_segs[i].lo && v < image_segs[i].hi) return 1;
  return 0;
}
static void image_guard_arm(void) {
  if (!image_nsegs) dl_iterate_phdr(image_seg_phdr, NULL);
  ai_image_nbad = 0;
  ai_image_absguard = image_abs_ok;
}
extern uintptr_t ai_image_redir[8];
extern uintptr_t ai_image_nredir;
static void image_redir_report(void) {
  for (uintptr_t i = 0; i < ai_image_nredir && i < 4; i++)
    fprintf(stderr, "ai: bake reverted a dead-native cell %p -> its bytecode twin %p (doc/wake-storm.md)\n",
            (void*) ai_image_redir[2 * i], (void*) ai_image_redir[2 * i + 1]);
}
static void image_guard_report(void) {
  if (!ai_image_nbad) return;
  fprintf(stderr, "ai: bake refused -- %lu un-wakeable absolute pointer(s) in the live heap\n",
          (unsigned long) ai_image_nbad);
  for (uintptr_t i = 0; i < ai_image_nbad && i < 2; i++)
    fprintf(stderr, "ai:   offender %lu: value %p in object at heap word %lu (object hot %p) -- JIT/W^X/mmap; see doc/wake-storm.md\n",
            (unsigned long) i, (void*) ai_image_bad[4 * i + 1],
            (unsigned long) ai_image_bad[4 * i], (void*) ai_image_bad[4 * i + 2]);
}

int image_dump(struct ai *g, char const *path) {
  image_guard_arm();
  uintptr_t len = 0;
  void *buf = ai_image_save(g, &len);             // g->alloc'd; --bake exits right after, so we don't free it
  if (!buf) { image_guard_report(); return -2; }
  FILE *f = fopen(path, "wb");
  int rc = !f ? -4 : (fwrite(buf, 1, len, f) == len) ? 0 : -4;
  if (f) fclose(f);
  return rc;
}

// image_bake -- the SELF-bake: lay the post-warm image into the running binary's own
// .image section on disk (what the Makefile's objdump/truncate/objcopy pipeline did).
// The reserve's file offset comes from the program headers (dl_iterate_phdr: the first
// entry is the main program; the reserve is PROGBITS, so it sits inside a PT_LOAD's
// filesz). ETXTBSY-proof by the adopt pattern (port/inle/serve.l): you cannot write your
// own executing file, so copy it, pwrite the blob at the offset (zero-padding the rest of
// the reserve, like the old truncate pad), fsync, and atomically RENAME over the original
// -- a new inode, so anything still executing keeps the old one. Same build = same
// layout, so the codec's anchor/refsym guards hold by construction.
extern uint64_t ai_baked_image[];
extern uintptr_t ai_baked_image_len;
struct bake_at { uintptr_t addr, off; int found; };
static int bake_phdr(struct dl_phdr_info *in, size_t sz, void *d) {
  struct bake_at *b = d;
  for (int i = 0; i < in->dlpi_phnum; i++) {
    const ElfW(Phdr) *p = &in->dlpi_phdr[i];
    uintptr_t lo = in->dlpi_addr + p->p_vaddr;
    if (p->p_type == PT_LOAD && b->addr >= lo && b->addr < lo + p->p_filesz)
      b->off = p->p_offset + (b->addr - lo), b->found = 1; }
  return 1;                                       // stop after the first object: the main program
}
int image_bake(struct ai *g) {
  image_guard_arm();
  uintptr_t len = 0;
  void *buf = ai_image_save(g, &len);
  image_redir_report();
  if (!buf) { image_guard_report(); return -2; }
  if (len > ai_baked_image_len) {
    fprintf(stderr, "ai: image %lu > .image reserve %lu -- bump RESERVE_WORDS in host/image_baked.c\n",
            (unsigned long) len, (unsigned long) ai_baked_image_len);
    return -3; }
  struct bake_at b = { (uintptr_t) ai_baked_image, 0, 0 };
  dl_iterate_phdr(bake_phdr, &b);
  if (!b.found) return -5;
  char exe[4096], tmp[4104];
  ssize_t n = readlink("/proc/self/exe", exe, sizeof exe - 1);
  if (n <= 0) return -6;
  exe[n] = 0;
  snprintf(tmp, sizeof tmp, "%s.bake", exe);
  struct stat st;
  int src = open(exe, O_RDONLY);
  if (src < 0 || fstat(src, &st)) { if (src >= 0) close(src); return -6; }
  int dst = open(tmp, O_WRONLY | O_CREAT | O_TRUNC, 0700);
  if (dst < 0) return close(src), -6;
  static char cbuf[1 << 20];                      // copy the whole exe; the running inode stays untouched
  for (ssize_t r; (r = read(src, cbuf, sizeof cbuf)) > 0;)
    if (write(dst, cbuf, (size_t) r) != r) return close(src), close(dst), unlink(tmp), -6;
  close(src);
  int rc = pwrite(dst, buf, len, (off_t) b.off) == (ssize_t) len ? 0 : -6;
  for (uintptr_t z = len; !rc && z < ai_baked_image_len; ) {          // zero the rest of the reserve
    size_t w = ai_baked_image_len - z < sizeof cbuf ? (size_t)(ai_baked_image_len - z) : sizeof cbuf;
    memset(cbuf, 0, w);
    if (pwrite(dst, cbuf, w, (off_t)(b.off + z)) != (ssize_t) w) rc = -6;
    z += w; }
  if (!rc && (fchmod(dst, st.st_mode & 07777) || fsync(dst))) rc = -6;
  if (close(dst)) rc = -6;
  if (!rc && rename(tmp, exe)) rc = -6;           // the adopt: atomic, a new inode
  if (rc) unlink(tmp);
  return rc;
}

// (bake path) -- snapshot the LIVE session to an image file, mid-eval: the running
// stack's objects ride into the blob as wake-unreachable ballast and the load side
// resets sp/ip, so `ai --wake path prog.l ..` boots a session carrying every global
// this one had pinned (an app baked warm: the mooncc image erases its per-run load).
// natives cannot serialize -- the post.l wrapper empties the glaze compile cache
// first (they re-JIT lazily in the woken session); any OTHER live native closure at
// bake time is on the caller. answers 1 | ().
// the frame-heavy body lives in a plain helper: path[4096] + &len escape (to
// fopen / ai_image_save_) and pin the frame, which would defeat the lvm_ ap's
// tail-jump (make vmret). the helper runs after Pack(g), on g->sp; the wrapper
// stays a thin sibcall. answers the result word (1 | ()).
static ai_noinline ai_word image_bake_do(struct ai *g) {
 if (!ai_strp(g->sp[0])) return ai_nil;
 struct ai_str *s = (struct ai_str*) g->sp[0];
 char path[4096];
 if (s->len >= sizeof path) return ai_nil;
 memcpy(path, s->bytes, s->len);                 // copy OUT first: the dump's gen_major moves the string
 path[s->len] = 0;
 image_guard_arm();
 uintptr_t len = 0;
 void *buf = ai_image_save_(g, &len);
 if (!buf) { image_guard_report(); return ai_nil; }
 FILE *f = fopen(path, "wb");
 int rc = !f ? -1 : (fwrite(buf, 1, len, f) == len) ? 0 : -1;
 if (f) fclose(f);
 g->alloc(g, buf, 0);                            // a session lives on after a bake: no leak
 return rc ? ai_nil : putcharm(1); }
static lvm(lvm_bake) {
 Pack(g);
 ai_word r = image_bake_do(g);
 Unpack(g);
 Sp[0] = r; Ip += 1;
 return Continue(); }
static union u const nif_bake[] = {{lvm_bake}, {lvm_ret0}};
AI_NIF("bake", nif_bake);

struct ai *image_load(char const *path) {
  FILE *f = fopen(path, "rb");
  if (!f) return NULL;
  struct ai *g = NULL;
  if (!fseek(f, 0, SEEK_END)) {
    long n = ftell(f);
    if (n > 0 && !fseek(f, 0, SEEK_SET)) {
      void *buf = malloc((size_t) n);             // the host owns the file buffer; the core copies the blob out
      if (buf && fread(buf, 1, (size_t) n, f) == (size_t) n) g = ai_image_load(buf, (uintptr_t) n);
      free(buf);
    }
  }
  fclose(f);
  return g;
}
