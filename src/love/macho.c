// macho.c -- image_lay for a mach-o: its link alone takes this over elfbake.c
#define _GNU_SOURCE
#include "love.h"
#include "bytes.h"
#include <string.h>
#include <unistd.h>
#include <link.h>

// a mach-o's .image is its __IMAGE segment, last mapped, grown to hold the blob. dyld wants
// __LINKEDIT last, so it and every offset into it move past the image. segments map a linked
// address (dyld's slide off) to its offset. 0 done, >0 not a mach-o laid for growth, <0 failed
struct macho_seg { uint32_t cmd, size; char name[16]; uint64_t addr, vsz, off, fsz;
                   uint32_t maxp, initp, nsect, flags; };
static void macho_slide(char *c, uint32_t lo, uint32_t hi, uint64_t from, uint64_t d) {
  for (uint32_t k = lo; k + 4 <= hi; k += 8) {        // (offset, size) pairs: one into it moves
    uint32_t o;
    memcpy(&o, c + k, 4);
    if (o && o >= from) o += (uint32_t) d, memcpy(c + k, &o, 4); } }
// the ad-hoc signature again over the grown file: the link's code directory head, its
// identifier kept, then a sha-256 a page below the signature, which closes __LINKEDIT
static int macho_sign(int src, int dst, char *cmds, uint32_t ncb, long li, struct macho_seg *ls,
                      long ci, uint32_t from, uint8_t *win) {
  uint8_t sb[20], cd[88], *blob = NULL;
  uint32_t at;
  int rc = 1;
  memcpy(&at, cmds + ci + 8, 4);
  if (pread(src, sb, sizeof sb, from) != (ssize_t) sizeof sb || ld32be(sb) != 0xfade0cc0u || ld32be(sb + 8) != 1
      || pread(src, cd, sizeof cd, from + ld32be(sb + 16)) != (ssize_t) sizeof cd
      || ld32be(cd) != 0xfade0c02u || ld32be(cd + 24) || cd[37] != 2 || cd[39] != 12) return 1;
  uint32_t ho = ld32be(cd + 16), ns = (at + 4095) / 4096, cdsz = ho + 32 * ns,
           ssz = (20 + cdsz + 15) & ~15u;
  if (ho < sizeof cd || ho > 4096 || !(blob = alloc(NULL, ssz))) goto out;
  rc = -6;
  memset(blob, 0, ssz);
  memcpy(blob, sb, sizeof sb);
  st32be(blob + 4, 20 + cdsz), st32be(blob + 16, 20);
  if (pread(src, blob + 20, ho, from + ld32be(sb + 16)) != (ssize_t) ho) goto out;
  st32be(blob + 24, cdsz), st32be(blob + 48, ns), st32be(blob + 52, at);   // length, slots, code limit
  memcpy(cmds + ci + 12, &ssz, 4);
  ls->fsz = at + ssz - ls->off, ls->vsz = (ls->fsz + 4095) & ~(uint64_t) 4095;
  memcpy(cmds + li, ls, sizeof *ls);
  if (pwrite(dst, cmds, ncb, 32) != (ssize_t) ncb) goto out;
  for (uint32_t k = 0; k < ns; k++) {
    uint32_t n = at - 4096 * k < 4096 ? at - 4096 * k : 4096;
    if (pread(dst, win, n, (off_t) 4096 * k) != (ssize_t) n) goto out;
    sha256_of(win, n, blob + 20 + ho + 32 * k); }
  rc = pwrite(dst, blob, ssz, at) == (ssize_t) ssz ? 0 : -6;
 out:
  alloc(blob, 0);
  return rc; }
static int macho_slideof(struct dl_phdr_info *in, size_t sz, void *d) {
  return *(uintptr_t*) d = in->dlpi_addr, 1; }
int image_lay(int src, int dst, void const *buf, uintptr_t len, char *win) {
  uintptr_t slide = 0;
  dl_iterate_phdr(macho_slideof, &slide);
  uintptr_t lenaddr = (uintptr_t) &baked_image_len - slide, imgaddr = (uintptr_t) baked_image - slide;
  uint32_t h[8];
  if (pread(src, h, sizeof h, 0) != (ssize_t) sizeof h || h[0] != 0xfeedfacfu) return 1;
  struct macho_seg is, ls;
  uint64_t lenoff = 0, imgoff = 0, last = 0;
  long si = -1, li = -1, ci = -1;
  uint32_t sfrom = 0;
  int rc = -6;
  char *cmds = alloc(NULL, h[5]);
  if (!cmds || pread(src, cmds, h[5], 32) != (ssize_t) h[5]) goto out;
  for (uint32_t i = 0, at = 0, c[2]; i < h[4] && at + 8 <= h[5]; i++, at += c[1]) {
    memcpy(c, cmds + at, sizeof c);
    if (!c[1]) break;
    if (c[0] == 0x1d && at + 16 <= h[5]) ci = at, memcpy(&sfrom, cmds + at + 8, 4);   // lc_code_signature
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
      || (li >= 0 && ls.off < last) || (ci >= 0 && li < 0)) goto out;
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
  if (pwrite(dst, buf, len, (off_t) imgoff) != (ssize_t) len
      || pwrite(dst, cmds, h[5], 32) != (ssize_t) h[5]
      || pwrite(dst, &len, sizeof len, (off_t) lenoff) != (ssize_t) sizeof len) rc = -6;
  if (!rc && ci >= 0) rc = macho_sign(src, dst, cmds, h[5], li, &ls, ci, sfrom, (uint8_t*) win);
 out:
  alloc(cmds, 0);
  return rc; }
