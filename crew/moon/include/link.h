#ifndef _AI_LINK_H
#define _AI_LINK_H
/* just enough ELF for dl_iterate_phdr (image.c's bake_phdr walk) */
typedef unsigned long  Elf64_Addr;
typedef unsigned long  Elf64_Off;
typedef unsigned long  Elf64_Xword;
typedef unsigned int   Elf64_Word;
typedef unsigned short Elf64_Half;
#define ElfW(t) Elf64_##t
typedef struct {
  Elf64_Word  p_type;
  Elf64_Word  p_flags;
  Elf64_Off   p_offset;
  Elf64_Addr  p_vaddr;
  Elf64_Addr  p_paddr;
  Elf64_Xword p_filesz;
  Elf64_Xword p_memsz;
  Elf64_Xword p_align;
} Elf64_Phdr;
#define PT_LOAD 1
struct dl_phdr_info {
  Elf64_Addr        dlpi_addr;
  char const       *dlpi_name;
  Elf64_Phdr const *dlpi_phdr;
  Elf64_Half        dlpi_phnum;
};
int dl_iterate_phdr(int (*)(struct dl_phdr_info*, unsigned long, void*), void*);
#endif
