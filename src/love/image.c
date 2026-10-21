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
#include <link.h>
// linux's alone: on the BSDs the wake faults as it decodes
#ifndef MAP_POPULATE
#define MAP_POPULATE 0
#endif

// the scratch beside a bake's target, per process: make -jN bakes one name concurrently
static char *bake_scratch(struct g *g, char const *path) {
  long pid = (long) getpid();
  int n = snprintf(NULL, 0, "%s.bake.%ld", path, pid);
  char *t = n < 0 ? NULL : alloc(NULL, (size_t) n + 1);
  if (t) snprintf(t, (size_t) n + 1, "%s.bake.%ld", path, pid);
  return t; }

// LOVE_BAKE_CHUNK the words of a stream chunk, LOVE_BAKE_HOT a file of "a b" word ranges a profile touched
static void *image_save_env(struct g *g, uintptr_t *len) {
  struct image_opt o = { 0, NULL, 0 };
  char const *c = getenv("LOVE_BAKE_CHUNK"), *h = getenv("LOVE_BAKE_HOT");
  uint64_t *r = NULL;
  if (c && *c) o.chunk = (uintptr_t) strtoul(c, NULL, 10);
  FILE *f = h && *h ? fopen(h, "r") : NULL;
  if (f) {                                        // numbers by hand: moonlibc's scanf takes no %llu
    uintptr_t cap = 0, n = 0;
    uint64_t v = 0;
    int c, in = 0;
    while ((c = fgetc(f)) != EOF || in) {
      if (c >= '0' && c <= '9') { v = 10 * v + (uint64_t) (c - '0'), in = 1; continue; }
      if (!in) continue;
      if (n + 1 > cap) {
        uint64_t *t = alloc(NULL, (cap = cap ? 2 * cap : 1024) * sizeof *t);
        if (!t) break;
        if (r) memcpy(t, r, n * sizeof *t), alloc(r, 0);
        r = t; }
      r[n++] = v, v = 0, in = 0;
      if (c == EOF) break; }
    fclose(f);
    o.hot = r, o.nhot = n / 2; }
  void *buf = image_save2(g, len, NULL, &o);
  if (r) alloc(r, 0);
  return buf; }

// the one bake to a file. the path is sp[0], a root, read after the dump moves it; noinline
// keeps these buffers out of lvm_bake's frame, which would defeat its tail-jump (make vmret)
love_noinline static int image_put(struct g *g) {
  uintptr_t len = 0;
  void *buf = image_save_env(g, &len);
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
struct g *image_dump(struct g *g, char const *path) {
  g = strof(g, path);
  if (!ok(g)) return core_of(g)->b = -2, g;
  int rc = image_put(g);
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

struct bake_at { uintptr_t addr, off, bias; int found; };
static int bake_phdr(struct dl_phdr_info *in, size_t sz, void *d) {
  struct bake_at *b = d;
  b->bias = in->dlpi_addr;
  for (int i = 0; i < in->dlpi_phnum; i++) {
    const ElfW(Phdr) *p = &in->dlpi_phdr[i];
    uintptr_t lo = in->dlpi_addr + p->p_vaddr;
    if (p->p_type == PT_LOAD && b->addr >= lo && b->addr < lo + p->p_filesz)
      b->off = p->p_offset + (b->addr - lo), b->found = 1; }
  return 1; }                                     // stop after the first object: the main program

#define BakeScratch (64u << 10)                  // the copy window
// n bytes src@soff -> dst@doff through the window
static int bake_move(int src, int dst, uint64_t soff, uint64_t doff, uint64_t n, char *win) {
  for (uint64_t z = 0; z < n; ) {
    size_t w = n - z < BakeScratch ? (size_t)(n - z) : BakeScratch;
    if (pread(src, win, w, (off_t)(soff + z)) != (ssize_t) w) return -6;
    if (pwrite(dst, win, w, (off_t)(doff + z)) != (ssize_t) w) return -6;
    z += w; }
  return 0; }

// lay the image into .image, which must end the last segment: append where it sits, rewrite
// its one phdr and shdr, fsync, rename. 0 done, >0 not laid for growth, <0 a failure
static int bake_tail(struct g *g, int src, char const *tmp, void const *buf, uintptr_t len,
                     uint64_t lenoff, uint64_t imgoff, mode_t mode) {
  Elf64_Ehdr eh;
  Elf64_Shdr *sh = NULL;
  Elf64_Phdr *ph = NULL;
  char *str = NULL, *win = NULL;
  size_t nsh, nph, si = 0, pi;
  uint64_t head, off, cur, al, pad;
  int dst = -1, rc = 1;
  if (pread(src, &eh, sizeof eh, 0) != (ssize_t) sizeof eh) return -6;
  if (memcmp(eh.e_ident, ELFMAG, SELFMAG) || eh.e_ident[EI_CLASS] != ELFCLASS64
      || eh.e_shentsize != sizeof(Elf64_Shdr) || eh.e_phentsize != sizeof(Elf64_Phdr)
      || eh.e_shnum < 2 || !eh.e_phnum || eh.e_shstrndx >= eh.e_shnum) return 1;
  nsh = eh.e_shnum, nph = eh.e_phnum;
  sh = alloc(NULL, nsh * sizeof *sh), ph = alloc(NULL, nph * sizeof *ph);
  win = alloc(NULL, BakeScratch);
  if (!sh || !ph || !win) { rc = -6; goto out; }
  if (pread(src, sh, nsh * sizeof *sh, (off_t) eh.e_shoff) != (ssize_t)(nsh * sizeof *sh)
      || pread(src, ph, nph * sizeof *ph, (off_t) eh.e_phoff) != (ssize_t)(nph * sizeof *ph))
    { rc = -6; goto out; }
  if (!(str = alloc(NULL, sh[eh.e_shstrndx].sh_size + 1))) { rc = -6; goto out; }
  if (pread(src, str, sh[eh.e_shstrndx].sh_size, (off_t) sh[eh.e_shstrndx].sh_offset)
      != (ssize_t) sh[eh.e_shstrndx].sh_size) { rc = -6; goto out; }
  str[sh[eh.e_shstrndx].sh_size] = 0;
  for (size_t i = 1; i < nsh; i++)
    if (sh[i].sh_name < sh[eh.e_shstrndx].sh_size && !strcmp(str + sh[i].sh_name, ".love.image")) { si = i; break; }
  if (!si) goto out;                              // no .image section at all
  // where the section sits, so offset/vaddr congruence is inherited: nothing allocated above it
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
  // the blob goes at baked_image, not the section's start: pad is alignment a link may lay
  // before the symbol, and the two records below carry it
  if (imgoff < off || imgoff - off >= sh[si].sh_size) goto out;   // the symbol is not in the section
  pad = imgoff - off;
  head = imgoff;                                  // everything below the blob stays put, byte for byte
  al = sh[si].sh_addr - ph[pi].p_vaddr;           // the image's own start within its segment
  if ((dst = open(tmp, O_WRONLY | O_CREAT | O_TRUNC, 0700)) < 0) { rc = -6; goto out; }
  if ((rc = bake_move(src, dst, 0, 0, head, win))) goto out;
  if (pwrite(dst, buf, len, (off_t) imgoff) != (ssize_t) len) { rc = -6; goto out; }
  cur = imgoff + len;
  for (size_t i = 1; i < nsh; i++) {              // the non-allocated tail, relaid past the blob
    uint64_t a;
    if (i == si || sh[i].sh_type == SHT_NOBITS || (sh[i].sh_flags & SHF_ALLOC)) continue;
    if (sh[i].sh_offset < head) continue;         // it rode along inside the head
    a = sh[i].sh_addralign ? sh[i].sh_addralign : 1;
    cur = (cur + a - 1) / a * a;
    if ((rc = bake_move(src, dst, sh[i].sh_offset, cur, sh[i].sh_size, win))) goto out;
    sh[i].sh_offset = cur;
    cur += sh[i].sh_size; }
  sh[si].sh_size = pad + len;                     // the two records that now describe the image
  ph[pi].p_filesz = ph[pi].p_memsz = al + pad + len;   // .image ends the segment, so its growth is the segment's
  eh.e_shoff = cur = (cur + 7) & ~(uint64_t) 7;
  // FIXME remove bare block delimiters like this, rename scoped variables if needed
  { uintptr_t l = len;                            // baked_image_len: what main.c hands the codec
    if (pwrite(dst, sh, nsh * sizeof *sh, (off_t) cur) != (ssize_t)(nsh * sizeof *sh)
        || pwrite(dst, ph, nph * sizeof *ph, (off_t) eh.e_phoff) != (ssize_t)(nph * sizeof *ph)
        || pwrite(dst, &eh, sizeof eh, 0) != (ssize_t) sizeof eh
        || pwrite(dst, &l, sizeof l, (off_t) lenoff) != (ssize_t) sizeof l) rc = -6; }
 out:
  if (dst >= 0) {
    if (!rc && (fchmod(dst, mode) || fsync(dst))) rc = -6;
    if (close(dst)) rc = -6; }
  alloc(sh, 0), alloc(ph, 0), alloc(str, 0), alloc(win, 0);
  return rc; }

// a mach-o's .image is its __IMAGE segment, last mapped, grown to hold the blob. dyld wants
// __LINKEDIT last, so it and every offset into it move past the image. segments map a linked
// address (the caller takes dyld's slide off) to its offset. 0 done, >0 not a mach-o laid for
// growth, <0 failed
struct macho_seg { uint32_t cmd, size; char name[16]; uint64_t addr, vsz, off, fsz;
                   uint32_t maxp, initp, nsect, flags; };
static void macho_slide(char *c, uint32_t lo, uint32_t hi, uint64_t from, uint64_t d) {
  for (uint32_t k = lo; k + 4 <= hi; k += 8) {        // (offset, size) pairs: one into it moves
    uint32_t o;
    memcpy(&o, c + k, 4);
    if (o && o >= from) o += (uint32_t) d, memcpy(c + k, &o, 4); } }
static int bake_macho(int src, char const *tmp, void const *buf, uintptr_t len,
                      uintptr_t lenaddr, uintptr_t imgaddr, mode_t mode) {
  uint32_t h[8];
  if (pread(src, h, sizeof h, 0) != (ssize_t) sizeof h || h[0] != 0xfeedfacfu) return 1;
  struct macho_seg is, ls;
  uint64_t lenoff = 0, imgoff = 0, last = 0;
  long si = -1, li = -1;
  int dst = -1, rc = -6;
  char *cmds = alloc(NULL, h[5]), *win = alloc(NULL, BakeScratch);
  if (!cmds || !win || pread(src, cmds, h[5], 32) != (ssize_t) h[5]) goto out;
  for (uint32_t i = 0, at = 0, c[2]; i < h[4] && at + 8 <= h[5]; i++, at += c[1]) {
    memcpy(c, cmds + at, sizeof c);
    if (!c[1]) break;
    if (c[0] != 25 || at + sizeof is > h[5]) continue;    // lc_segment_64
    struct macho_seg sg;
    memcpy(&sg, cmds + at, sizeof sg);
    if (!strncmp(sg.name, "__LINKEDIT", sizeof sg.name)) { li = at, ls = sg; continue; }
    if (lenaddr >= sg.addr && lenaddr < sg.addr + sg.fsz) lenoff = sg.off + (lenaddr - sg.addr);
    if (imgaddr >= sg.addr && imgaddr < sg.addr + sg.fsz) imgoff = sg.off + (imgaddr - sg.addr);
    if (!strncmp(sg.name, "__IMAGE", sizeof sg.name)) si = at, is = sg;
    if (sg.off + sg.fsz > last) last = sg.off + sg.fsz; }
  rc = 1;
  if (si < 0 || !lenoff || !imgoff || imgoff < is.off || is.off + is.fsz != last
      || (li >= 0 && ls.off < last)) goto out;
  if ((dst = open(tmp, O_WRONLY | O_CREAT | O_TRUNC, 0700)) < 0) { rc = -6; goto out; }
  if ((rc = bake_move(src, dst, 0, 0, imgoff, win))) goto out;
  is.fsz = imgoff - is.off + len;
  is.vsz = (is.fsz + 4095) & ~(uint64_t) 4095;
  memcpy(cmds + si, &is, sizeof is);
  if (li >= 0) {                                        // __LINKEDIT on past the image
    uint64_t off = (is.off + is.fsz + 4095) & ~(uint64_t) 4095, from = ls.off, d = off - ls.off;
    if ((rc = bake_move(src, dst, ls.off, off, ls.fsz, win))) goto out;
    ls.off = off, ls.addr = is.addr + is.vsz;
    memcpy(cmds + li, &ls, sizeof ls);
    for (uint32_t i = 0, at = 0, c[2]; i < h[4] && at + 8 <= h[5]; i++, at += c[1]) {
      memcpy(c, cmds + at, sizeof c);
      if (!c[1]) break;
      if (c[0] == 0x80000022 || c[0] == 0x22) macho_slide(cmds + at, 8, 48, from, d);   // dyld_info: five pairs
      else if (c[0] == 2) macho_slide(cmds + at, 8, 24, from, d);                      // symtab: (sym n) (str size)
      else if (c[0] == 11) {                                                           // dysymtab: six (off n) from 32
        for (uint32_t k = 32; k + 8 <= 80; k += 8) macho_slide(cmds + at, k, k + 8, from, d); }
      else if (c[0] == 0x1d || c[0] == 0x26 || c[0] == 0x29 || c[0] == 0x80000033 || c[0] == 0x80000034)
        macho_slide(cmds + at, 8, 16, from, d); } }   // linkedit_data: signature, starts, data in code, fixups
  { uintptr_t l = len;
    if (pwrite(dst, buf, len, (off_t) imgoff) != (ssize_t) len
        || pwrite(dst, cmds, h[5], 32) != (ssize_t) h[5]
        || pwrite(dst, &l, sizeof l, (off_t) lenoff) != (ssize_t) sizeof l) rc = -6; }
 out:
  if (dst >= 0) {
    if (!rc && (fchmod(dst, mode) || fsync(dst))) rc = -6;
    if (close(dst)) rc = -6; }
  alloc(cmds, 0), alloc(win, 0);
  return rc; }

// out NULL bakes in place, a path writes a copy; bare lays the stub back, an imageless binary
int image_bake(struct g *g, char const *out, int bare) {
  uint64_t stub[ReserveWords] = {1};
  uintptr_t len = sizeof stub;
  void *buf = bare ? NULL : image_save_env(g, &len);
  if (!bare && !buf) return -2;
  // baked_image_len patched by the file offset the running phdrs give; a copy shares the head
  struct bake_at bl = { (uintptr_t) &baked_image_len, 0, 0, 0 },
                 bi = { (uintptr_t) baked_image, 0, 0, 0 };     // ..and the blob goes where that symbol reads
  dl_iterate_phdr(bake_phdr, &bl);
  dl_iterate_phdr(bake_phdr, &bi);
  // the kernel's PATH_MAX
  char exe[4096];
  if (!host_selfpath(exe, sizeof exe)) return alloc(buf, 0), -6;
  char const *dst = out ? out : exe;
  char *tmp = bake_scratch(g, dst);
  struct stat st;
  int rc = -6, src = tmp ? open(exe, O_RDONLY) : -1;
  if (src >= 0 && !fstat(src, &st)) {
    void const *blob = bare ? (void const *) stub : buf;
    rc = bake_macho(src, tmp, blob, len, bl.addr - bl.bias, bi.addr - bi.bias, st.st_mode & 07777);
    if (rc > 0 && !(bl.found && bi.found)) rc = -5;      // an ELF the phdrs cannot place
    else if (rc > 0) rc = bake_tail(g, src, tmp, blob, len, bl.off, bi.off, st.st_mode & 07777);
    if (rc > 0) {
      fprintf(stderr, "love: .image is not laid last -- nowhere to grow the image\n");
      rc = -3; }
    if (!rc && rename(tmp, dst)) rc = -6;         // a new inode: ETXTBSY-proof
    if (rc) unlink(tmp); }
  if (src >= 0) close(src);
  alloc(tmp, 0);
  return alloc(buf, 0), rc; }

// (bake path): `love wake path ..` boots with every global this one pinned. 1 | ()
// FIXME extend LvmCall macro to handle this.
static lvm(lvm_bake) {
 Pack(g);
 word r = cstrp(g->sp[0]) && !image_put(g) ? putcharm(1) : zero;
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
