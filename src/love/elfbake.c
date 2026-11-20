// elfbake.c -- image_lay's ELF writer; macho.c is the other
#define _GNU_SOURCE
#include "love.h"
#include <string.h>
#include <unistd.h>
#include <link.h>

// a link address's file offset by the target's own load segments, 0 for none
static uint64_t bake_off(ElfW(Phdr) const *ph, size_t nph, uintptr_t a) {
  for (size_t i = 0; i < nph; i++)
    if (ph[i].p_type == PT_LOAD && a >= ph[i].p_vaddr && a < ph[i].p_vaddr + ph[i].p_filesz)
      return ph[i].p_offset + (a - ph[i].p_vaddr);
  return 0; }

// lay the image into .image, which must end the last segment: append where it sits, rewrite
// its one phdr and shdr, fsync, rename. 0 done, >0 not laid for growth, <0 a failure
int image_lay_elf(int src, int dst, void const *buf, uintptr_t len, char *win) {
  ElfW(Ehdr) eh;
  ElfW(Shdr) *sh = NULL;
  ElfW(Phdr) *ph = NULL;
  char *str = NULL;
  size_t nsh, nph, si = 0, pi;
  uint64_t head, off, cur, al, pad;
  int rc = 1;
  if (pread(src, &eh, sizeof eh, 0) != (ssize_t) sizeof eh) return -6;
  if (memcmp(eh.e_ident, ELFMAG, SELFMAG) || eh.e_ident[EI_CLASS] != (sizeof(void *) == 8 ? ELFCLASS64 : ELFCLASS32)
      || eh.e_shentsize != sizeof *sh || eh.e_phentsize != sizeof *ph
      || eh.e_shnum < 2 || !eh.e_phnum || eh.e_shstrndx >= eh.e_shnum) return 1;
  nsh = eh.e_shnum, nph = eh.e_phnum;
  sh = alloc(NULL, nsh * sizeof *sh), ph = alloc(NULL, nph * sizeof *ph);
  if (!sh || !ph) { rc = -6; goto out; }
  if (pread(src, sh, nsh * sizeof *sh, (off_t) eh.e_shoff) != (ssize_t)(nsh * sizeof *sh)
      || pread(src, ph, nph * sizeof *ph, (off_t) eh.e_phoff) != (ssize_t)(nph * sizeof *ph))
    { rc = -6; goto out; }
  // the running link's addresses, slid back, in the target's segments: a copy shares the head,
  // and another container of this link lays its code where this one does
  uintptr_t slide = bake_slide();
  uint64_t lenoff = bake_off(ph, nph, (uintptr_t) &baked_image_len - slide),
           imgoff = bake_off(ph, nph, (uintptr_t) baked_image - slide),   // the blob goes where that symbol reads
           codeoff = bake_off(ph, nph, (uintptr_t) image_lay - slide);
  if (!lenoff || !imgoff) { rc = -5; goto out; }
  if (!bake_same(src, codeoff, win)) { rc = -7; goto out; }
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
  if (pwrite(dst, sh, nsh * sizeof *sh, (off_t) cur) != (ssize_t)(nsh * sizeof *sh)
      || pwrite(dst, ph, nph * sizeof *ph, (off_t) eh.e_phoff) != (ssize_t)(nph * sizeof *ph)
      || pwrite(dst, &eh, sizeof eh, 0) != (ssize_t) sizeof eh
      || pwrite(dst, &len, sizeof len, (off_t) lenoff) != (ssize_t) sizeof len) rc = -6;   // baked_image_len: what main.c hands the codec
 out:
  alloc(sh, 0), alloc(ph, 0), alloc(str, 0);
  return rc; }
