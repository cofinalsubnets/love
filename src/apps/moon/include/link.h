#ifndef _LOVE_LINK_H
#define _LOVE_LINK_H
/* just enough elf for dl_iterate_phdr and the file headers the bake rewrites */
typedef unsigned long  Elf64_Addr;
typedef unsigned long  Elf64_Off;
typedef unsigned long  Elf64_Xword;
typedef unsigned int   Elf64_Word;
typedef unsigned short Elf64_Half;
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
typedef unsigned int   Elf32_Addr;
typedef unsigned int   Elf32_Off;
typedef unsigned int   Elf32_Word;
typedef unsigned short Elf32_Half;
typedef struct {
  Elf32_Word p_type;
  Elf32_Off  p_offset;
  Elf32_Addr p_vaddr;
  Elf32_Addr p_paddr;
  Elf32_Word p_filesz;
  Elf32_Word p_memsz;
  Elf32_Word p_flags;
  Elf32_Word p_align;
} Elf32_Phdr;
typedef struct {
  unsigned char e_ident[16];
  Elf32_Half  e_type, e_machine;
  Elf32_Word  e_version;
  Elf32_Addr  e_entry;
  Elf32_Off   e_phoff, e_shoff;
  Elf32_Word  e_flags;
  Elf32_Half  e_ehsize, e_phentsize, e_phnum, e_shentsize, e_shnum, e_shstrndx;
} Elf32_Ehdr;
#ifdef __ILP32__
#define ElfW(t) Elf32_##t
#else
#define ElfW(t) Elf64_##t
#endif
#define PT_LOAD 1
#define PT_TLS 7
#define EI_NIDENT 16
#define EI_CLASS 4
#define ELFCLASS64 2
#define ELFMAG "\177ELF"
#define SELFMAG 4
#define SHT_NOBITS 8
#define SHF_ALLOC 2
typedef struct {
  unsigned char e_ident[EI_NIDENT];
  Elf64_Half  e_type, e_machine;
  Elf64_Word  e_version;
  Elf64_Addr  e_entry;
  Elf64_Off   e_phoff, e_shoff;
  Elf64_Word  e_flags;
  Elf64_Half  e_ehsize, e_phentsize, e_phnum, e_shentsize, e_shnum, e_shstrndx;
} Elf64_Ehdr;
typedef struct {
  Elf64_Word  sh_name, sh_type;
  Elf64_Xword sh_flags;
  Elf64_Addr  sh_addr;
  Elf64_Off   sh_offset;
  Elf64_Xword sh_size;
  Elf64_Word  sh_link, sh_info;
  Elf64_Xword sh_addralign, sh_entsize;
} Elf64_Shdr;
struct dl_phdr_info {
  ElfW(Addr)        dlpi_addr;
  char const       *dlpi_name;
  ElfW(Phdr) const *dlpi_phdr;
  ElfW(Half)        dlpi_phnum;
};
int dl_iterate_phdr(int (*)(struct dl_phdr_info*, unsigned long, void*), void*);
#endif
