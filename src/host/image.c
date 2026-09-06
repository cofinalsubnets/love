// src/host/image.c -- file I/O around the stdio-free image codec in snap.c (ai_image_save /
// ai_image_load). that codec rides love_tu, which the port/ boards link with no stdio
// aboard, so stdio stops here. main.c calls image_bake (lay the image back into the
// binary's own .image section), image_dump (write a plain image file) and image_load.
// bake and dump answer 0 ok / <0 error; load answers NULL on any problem, so the caller
// falls back to a normal egg boot.
#define _GNU_SOURCE
#include "love.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <link.h>
// the prefault hint is linux's alone. neither BSD has the flag, and there the wake takes
// its faults as the decode walks -- a slower map, never a different one.
#ifndef MAP_POPULATE
#define MAP_POPULATE 0
#endif


// the scratch beside a bake's target, per-process. two loves bake the same name
// concurrently all the time under `make -jN`, and on one shared name they interleave into
// each other's bytes, the second to rename answering ENOENT. NULL on refusal.
static char *bake_scratch(struct ai *g, char const *path) {
  long pid = (long) getpid();
  int n = snprintf(NULL, 0, "%s.bake.%ld", path, pid);       // measure, then the one exact block
  char *t = n < 0 ? NULL : g->alloc(g, NULL, (size_t) n + 1);
  if (t) snprintf(t, (size_t) n + 1, "%s.bake.%ld", path, pid);
  return t; }

// the one bake to a file, for the nif and the verb alike. the path is sp[0], read after the
// dump: gen_major moves the string and sp[0] is a root, so it rides the move where a C local
// would not. noinline keeps these buffers out of lvm_bake's frame, which would defeat the
// lvm_ ap's tail-jump (make vmret). 0 ok, <0 refused.
ai_noinline static int image_put(struct ai *g) {
  uintptr_t len = 0;
  void *buf = ai_image_save(g, &len, NULL);
  if (!buf) return -2;
  char const *path = txt(str(g->sp[0]));          // a love string ends in a NUL
  // land it beside the target, never on it: "wb" empties the file and only then writes the
  // megabytes back, so a reader in between gets a short image, which wakes with no verbs.
  char *tmp = bake_scratch(g, path);
  int rc = -4;
  if (tmp) {
    FILE *f = fopen(tmp, "wb");
    rc = !f ? -4 : (fwrite(buf, 1, len, f) == len) ? 0 : -4;
    if (f && fclose(f)) rc = -4;
    if (!rc && rename(tmp, path)) rc = -4;        // the adopt: atomic, a whole file or none
    if (rc) remove(tmp);
    g->alloc(g, tmp, 0); }
  return g->alloc(g, buf, 0), rc; }

// `bake PATH`: image_put reads the path off the stack, so the C string goes there first.
// the push can move g, so g comes back out, and the rc rides g->b, written last.
struct ai *image_dump(struct ai *g, char const *path) {
  g = ai_strof(g, path);
  if (!ai_ok(g)) return ai_core_of(g)->b = -2, g;
  int rc = image_put(g);
  ai_core_of(g)->sp++;
  return ai_core_of(g)->b = rc, g; }

// image_bake -- the self-bake: lay the post-warm image into the running binary's own
// .image section on disk. ETXTBSY-proof by the adopt pattern -- copy the file, lay the blob
// in, fsync, rename over the original, so anything still executing keeps the old inode.
// same build = same layout, so the codec's anchor/refsym guards hold by construction.
// .image is laid last, so the blob is appended where the section already sits and only the
// one phdr and shdr that name it are rewritten. no reserve, no ceiling, and no vaddr moves.
// bake_tail reads that requirement off the binary's own section headers rather than a build
// flag, and it is one thing: .image ends the segment carrying it -- true of a section alone
// in the highest PT_LOAD (the Makefile's --section-start) and of one riding the tail of the
// single segment holo lays. any other link is refused loudly: there is nowhere to grow.
// the in-binary home of the post-boot heap image (doc/misc/snapshot.md): the binary loads
// its own dump at startup, identical layout by construction, so the codec's same-binary
// +delta relocation just works. sentinel-initialized rather than {0} so it lands in
// PROGBITS, patchable in place, never .bss. the bake grows the section, so this stub exists
// only to give it an address.
#define ReserveWords 2u
__attribute__((section(".love.image"))) uint64_t ai_baked_image[ReserveWords] = {1};
uintptr_t ai_baked_image_len = ReserveWords * 8u;
// the stub's size is a lie gcc believes: ReserveWords is 2 because the bake grows the
// object, so a read past the second word is out of bounds of the declaration and in bounds
// of the section. main.c's `extern uint64_t ai_baked_image[]` never hears about it.
#if defined(__GNUC__) && !defined(__clang__) && !defined(__mooncc__)
#pragma GCC diagnostic ignored "-Warray-bounds"
#endif
// --- the carried image -------------------------------------------------------
// the section holds one image; its first word is the codec's own magic. an unbaked
// binary carries a stub too short to be one, and the caller boots the egg.
int ai_baked_pick(void const **blob, uintptr_t *blen) {
  return *blob = (void const *) ai_baked_image, *blen = ai_baked_image_len,
         ai_baked_image_len > 0; }

struct bake_at { uintptr_t addr, off; int found; };
static int bake_phdr(struct dl_phdr_info *in, size_t sz, void *d) {
  struct bake_at *b = d;
  for (int i = 0; i < in->dlpi_phnum; i++) {
    const ElfW(Phdr) *p = &in->dlpi_phdr[i];
    uintptr_t lo = in->dlpi_addr + p->p_vaddr;
    if (p->p_type == PT_LOAD && b->addr >= lo && b->addr < lo + p->p_filesz)
      b->off = p->p_offset + (b->addr - lo), b->found = 1; }
  return 1; }                                     // stop after the first object: the main program

#define BakeScratch (64u << 10)                  // the copy/pad window: a bake runs once, so iterations are free
// move n bytes src@soff -> dst@doff through the caller's window. the two lanes only shuttle bytes.
static int bake_move(int src, int dst, uint64_t soff, uint64_t doff, uint64_t n, char *win) {
  for (uint64_t z = 0; z < n; ) {
    size_t w = n - z < BakeScratch ? (size_t)(n - z) : BakeScratch;
    if (pread(src, win, w, (off_t)(soff + z)) != (ssize_t) w) return -6;
    if (pwrite(dst, win, w, (off_t)(doff + z)) != (ssize_t) w) return -6;
    z += w; }
  return 0; }

// lay the image. 0 done, >0 "this binary is not laid for growth", <0 a real failure.
static int bake_tail(struct ai *g, int src, char const *tmp, void const *buf, uintptr_t len,
                     uint64_t lenoff, mode_t mode) {
  Elf64_Ehdr eh;
  Elf64_Shdr *sh = NULL;
  Elf64_Phdr *ph = NULL;
  char *str = NULL, *win = NULL;
  size_t nsh, nph, si = 0, pi;
  uint64_t head, off, cur, al;
  int dst = -1, rc = 1;
  if (pread(src, &eh, sizeof eh, 0) != (ssize_t) sizeof eh) return -6;
  if (memcmp(eh.e_ident, ELFMAG, SELFMAG) || eh.e_ident[EI_CLASS] != ELFCLASS64
      || eh.e_shentsize != sizeof(Elf64_Shdr) || eh.e_phentsize != sizeof(Elf64_Phdr)
      || eh.e_shnum < 2 || !eh.e_phnum || eh.e_shstrndx >= eh.e_shnum) return 1;
  nsh = eh.e_shnum, nph = eh.e_phnum;
  sh = g->alloc(g, NULL, nsh * sizeof *sh), ph = g->alloc(g, NULL, nph * sizeof *ph);
  win = g->alloc(g, NULL, BakeScratch);
  if (!sh || !ph || !win) { rc = -6; goto out; }
  if (pread(src, sh, nsh * sizeof *sh, (off_t) eh.e_shoff) != (ssize_t)(nsh * sizeof *sh)
      || pread(src, ph, nph * sizeof *ph, (off_t) eh.e_phoff) != (ssize_t)(nph * sizeof *ph))
    { rc = -6; goto out; }
  if (!(str = g->alloc(g, NULL, sh[eh.e_shstrndx].sh_size + 1))) { rc = -6; goto out; }
  if (pread(src, str, sh[eh.e_shstrndx].sh_size, (off_t) sh[eh.e_shstrndx].sh_offset)
      != (ssize_t) sh[eh.e_shstrndx].sh_size) { rc = -6; goto out; }
  str[sh[eh.e_shstrndx].sh_size] = 0;
  for (size_t i = 1; i < nsh; i++)
    if (sh[i].sh_name < sh[eh.e_shstrndx].sh_size && !strcmp(str + sh[i].sh_name, ".love.image")) { si = i; break; }
  if (!si) goto out;                              // no .image section at all
  // the blob goes exactly where the section already sits, so the loader's offset/vaddr
  // congruence is inherited rather than recomputed and a rebake lands on its own
  // footprint. all that must hold is that .image is last -- nothing allocated above it,
  // and it ends the segment that carries it, so growing it grows nothing else.
  off = sh[si].sh_offset;
  for (size_t i = 1; i < nsh; i++) {
    if (i == si || sh[i].sh_type == SHT_NOBITS || !(sh[i].sh_flags & SHF_ALLOC)) continue;
    if (sh[i].sh_addr > sh[si].sh_addr || sh[i].sh_offset > off) goto out; }
  for (pi = 0; pi < nph; pi++)
    if (ph[pi].p_type == PT_LOAD && ph[pi].p_vaddr <= sh[si].sh_addr
        && sh[si].sh_addr + sh[si].sh_size == ph[pi].p_vaddr + ph[pi].p_memsz) break;
  if (pi == nph) goto out;                        // .image does not end a segment: not the tail
  for (size_t i = 0; i < nph; i++)                // ..and no other segment lives above it
    if (i != pi && ph[i].p_type == PT_LOAD && ph[i].p_vaddr > ph[pi].p_vaddr) goto out;
  head = off;                                     // everything below the blob stays put, byte for byte
  al = sh[si].sh_addr - ph[pi].p_vaddr;           // the image's own start within its segment
  if ((dst = open(tmp, O_WRONLY | O_CREAT | O_TRUNC, 0700)) < 0) { rc = -6; goto out; }
  if ((rc = bake_move(src, dst, 0, 0, head, win))) goto out;
  if (pwrite(dst, buf, len, (off_t) off) != (ssize_t) len) { rc = -6; goto out; }
  cur = off + len;
  for (size_t i = 1; i < nsh; i++) {              // the non-allocated tail, relaid past the blob
    uint64_t a;
    if (i == si || sh[i].sh_type == SHT_NOBITS || (sh[i].sh_flags & SHF_ALLOC)) continue;
    if (sh[i].sh_offset < head) continue;         // it rode along inside the head
    a = sh[i].sh_addralign ? sh[i].sh_addralign : 1;
    cur = (cur + a - 1) / a * a;
    if ((rc = bake_move(src, dst, sh[i].sh_offset, cur, sh[i].sh_size, win))) goto out;
    sh[i].sh_offset = cur;
    cur += sh[i].sh_size; }
  sh[si].sh_size = len;                           // the two records that now describe the image
  ph[pi].p_filesz = ph[pi].p_memsz = al + len;    // .image ends the segment, so its growth is the segment's
  eh.e_shoff = cur = (cur + 7) & ~(uint64_t) 7;
  { uintptr_t l = len;                            // ai_baked_image_len: what main.c hands the codec
    if (pwrite(dst, sh, nsh * sizeof *sh, (off_t) cur) != (ssize_t)(nsh * sizeof *sh)
        || pwrite(dst, ph, nph * sizeof *ph, (off_t) eh.e_phoff) != (ssize_t)(nph * sizeof *ph)
        || pwrite(dst, &eh, sizeof eh, 0) != (ssize_t) sizeof eh
        || pwrite(dst, &l, sizeof l, (off_t) lenoff) != (ssize_t) sizeof l) rc = -6; }
 out:
  if (dst >= 0) {
    if (!rc && (fchmod(dst, mode) || fsync(dst))) rc = -6;
    if (close(dst)) rc = -6; }
  g->alloc(g, sh, 0), g->alloc(g, ph, 0), g->alloc(g, str, 0), g->alloc(g, win, 0);
  return rc; }

int image_bake(struct ai *g) {
  uintptr_t len = 0;
  void *buf = ai_image_save(g, &len, NULL);
  // the natives ride: their code is a segment of the image, woken as a chunk of the
  // arena. only a refused bake (below) is worth a word.
  if (!buf) return -2;
  // ai_baked_image_len is patched by file offset, taken from the running program's own
  // phdrs -- the one place a live address and a file position name the same byte.
  struct bake_at bl = { (uintptr_t) &ai_baked_image_len, 0, 0 };
  dl_iterate_phdr(bake_phdr, &bl);
  if (!bl.found) return g->alloc(g, buf, 0), -5;
  // exe[4096] is the kernel's own PATH_MAX, not a cap of ours: host_selfpath asks about a
  // real file, and no path an open could name is longer.
  char exe[4096];
  char *tmp = host_selfpath(exe, sizeof exe) ? bake_scratch(g, exe) : NULL;
  struct stat st;
  int rc = -6, src = tmp ? open(exe, O_RDONLY) : -1;
  if (src >= 0 && !fstat(src, &st)) {
    rc = bake_tail(g, src, tmp, buf, len, bl.off, st.st_mode & 07777);
    if (rc > 0) {
      fprintf(stderr, "love: .image is not laid last -- nowhere to grow the image\n");
      rc = -3; }
    if (!rc && rename(tmp, exe)) rc = -6;         // the adopt: atomic, a new inode
    if (rc) unlink(tmp); }
  if (src >= 0) close(src);
  g->alloc(g, tmp, 0);
  return g->alloc(g, buf, 0), rc; }

// the (bake path) nif: `love wake path prog.l ..` boots a session carrying every global
// this one had pinned, a live native closure among them -- its code is bytes the image
// carries. answers 1 | ().
static lvm(lvm_bake) {
 Pack(g);
 ai_word r = strp(g->sp[0]) && !image_put(g) ? putcharm(1) : ai_zero;
 Unpack(g);
 Sp[0] = r;
 ai_musttail return Next(1); }

static union u const nif_bake[] = {{lvm_bake}, {lvm_ret0}};
AiNif("bake", nif_bake);

struct ai *image_load(char const *path) {
  int fd = open(path, O_RDONLY);
  if (fd < 0) return NULL;
  struct stat st;
  struct ai *g = NULL;
  if (!fstat(fd, &st) && st.st_size > 0) {        // map, don't read: the core copies the blob straight
    size_t n = (size_t) st.st_size;               // out of the page cache -- one pass, no file buffer
    void *buf = mmap(NULL, n, PROT_READ, MAP_PRIVATE | MAP_POPULATE, fd, 0);
    if (buf != MAP_FAILED) {
      // step over a shebang if the image wears one -- images written before the line was
      // dropped carry one, padded to a word. a plain image starts at the magic.
      size_t off = 0;
      if (n > 2 && ((char*) buf)[0] == '#' && ((char*) buf)[1] == '!') {
        char *nl = memchr(buf, '\n', n);
        if (nl) off = (size_t)(nl - (char*) buf) + 1; }
      if (off < n) g = ai_image_load((char*) buf + off, (uintptr_t)(n - off));
      munmap(buf, n); } }
  close(fd);
  return g; }
