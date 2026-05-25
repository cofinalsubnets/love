#!/usr/bin/env python3
"""elf2efi.py -- wrap a statically-linked ELF into a PE32+ EFI image.

The x86_64 and aarch64 EFI builds drive lld-link via clang's MS-COFF
targets, which lays out a PE32+ container and synthesises the base
relocation table on the fly. LLVM's COFF backend has no RISC-V or
LoongArch port, so we cannot take that path on either arch. Instead
those EFI builds link a plain static ELF (with --emit-relocs to
preserve the relocation records that ld would otherwise drop), and
this tool stamps out the PE32+ wrapper around the same loadable bytes:

    +-------------------------------------------------+
    |  DOS stub + PE signature + COFF + Optional Hdr  |  (RVA 0..)
    |  Section table (.text, .data, .reloc)           |
    +-------------------------------------------------+
    |  .text  -- code + rodata from the ELF           |  (RVA 0x1000..)
    +-------------------------------------------------+
    |  .data  -- writable data; VirtualSize > raw     |
    |            so the UEFI loader zeroes .bss tail  |
    +-------------------------------------------------+
    |  .reloc -- one IMAGE_REL_BASED_DIR64 per ELF    |
    |            abs-64 record, grouped per page      |
    +-------------------------------------------------+

The linker script lines PT_LOAD segments up on 4 KiB boundaries starting
at RVA 0x1000, so PE FileAlignment == PE SectionAlignment == 0x1000 and
each section's file offset matches its RVA. That keeps the conversion
boring: copy each PT_LOAD verbatim, then append the generated .reloc.

The two supported ELF machines (RISC-V, LoongArch64) both encode their
absolute-64 relocation as type 2 in r_info, so the per-arch table just
picks the right PE machine code; the reloc walk is identical.

Usage: elf2efi.py INPUT.elf OUTPUT.efi
"""
import struct, sys

# --- ELF constants ---------------------------------------------------
EM_RISCV    = 243
EM_LOONGARCH= 258
PT_LOAD     = 1
PF_X        = 1
PF_W        = 2
SHT_RELA    = 4
SHF_ALLOC   = 2
R_RISCV_64  = 2
R_LARCH_64  = 2

# --- PE/COFF constants -----------------------------------------------
IMAGE_FILE_MACHINE_RISCV64        = 0x5064
IMAGE_FILE_MACHINE_LOONGARCH64    = 0x6264

# Per-arch dispatch. Each entry maps an ELF e_machine to the PE machine
# code we stamp into the COFF header and the absolute-64 r_type we lift
# into IMAGE_REL_BASED_DIR64 records.
ARCHES = {
    EM_RISCV:     ("riscv64",     IMAGE_FILE_MACHINE_RISCV64,     R_RISCV_64),
    EM_LOONGARCH: ("loongarch64", IMAGE_FILE_MACHINE_LOONGARCH64, R_LARCH_64),
}
IMAGE_FILE_EXECUTABLE_IMAGE       = 0x0002
IMAGE_FILE_LINE_NUMS_STRIPPED     = 0x0004
IMAGE_FILE_LOCAL_SYMS_STRIPPED    = 0x0008
IMAGE_FILE_DEBUG_STRIPPED         = 0x0200
IMAGE_FILE_LARGE_ADDRESS_AWARE    = 0x0020
IMAGE_NT_OPTIONAL_HDR64_MAGIC     = 0x20b
IMAGE_SUBSYSTEM_EFI_APPLICATION   = 10
IMAGE_DIRECTORY_ENTRY_BASERELOC   = 5

IMAGE_SCN_CNT_CODE                = 0x00000020
IMAGE_SCN_CNT_INITIALIZED_DATA    = 0x00000040
IMAGE_SCN_MEM_DISCARDABLE         = 0x02000000
IMAGE_SCN_MEM_EXECUTE             = 0x20000000
IMAGE_SCN_MEM_READ                = 0x40000000
IMAGE_SCN_MEM_WRITE               = 0x80000000

IMAGE_REL_BASED_ABSOLUTE          = 0
IMAGE_REL_BASED_DIR64             = 10

SECTION_ALIGN  = 0x1000
FILE_ALIGN     = 0x1000
HEADER_SIZE    = 0x1000                # one page reserved for headers

def align_up(x, a):
    return (x + a - 1) & ~(a - 1)

def fail(msg):
    sys.stderr.write("elf2efi: " + msg + "\n"); sys.exit(1)

# --- ELF reader ------------------------------------------------------
class Elf:
    def __init__(self, path):
        with open(path, "rb") as f:
            self.buf = f.read()
        b = self.buf
        if b[:4] != b"\x7fELF":           fail(path + ": not an ELF file")
        if b[4] != 2 or b[5] != 1:        fail(path + ": not ELF64 little-endian")
        (self.e_type, self.e_machine, _, self.e_entry, self.e_phoff, self.e_shoff,
         _, _, self.e_phentsize, self.e_phnum,
         self.e_shentsize, self.e_shnum, self.e_shstrndx) = \
            struct.unpack_from("<HHIQQQIHHHHHH", b, 16)
        if self.e_machine not in ARCHES:
            fail(path + ": unsupported e_machine 0x%x" % self.e_machine)
        # program headers
        self.phdrs = []
        for i in range(self.e_phnum):
            off = self.e_phoff + i * self.e_phentsize
            self.phdrs.append(struct.unpack_from("<IIQQQQQQ", b, off))
        # section headers
        self.shdrs = []
        for i in range(self.e_shnum):
            off = self.e_shoff + i * self.e_shentsize
            (sh_name, sh_type, sh_flags, sh_addr, sh_offset, sh_size,
             sh_link, sh_info, sh_addralign, sh_entsize) = \
                struct.unpack_from("<IIQQQQIIQQ", b, off)
            self.shdrs.append({
                "name_off": sh_name, "type": sh_type, "flags": sh_flags,
                "addr": sh_addr, "offset": sh_offset, "size": sh_size,
                "link": sh_link, "info": sh_info, "entsize": sh_entsize,
            })
        # resolve section names
        shstr = self.shdrs[self.e_shstrndx]
        def name_at(o):
            end = b.index(b"\x00", shstr["offset"] + o)
            return b[shstr["offset"] + o : end].decode()
        for s in self.shdrs:
            s["name"] = name_at(s["name_off"])

# --- collect absolute-64 RVAs that need PE base-relocation -----------
def collect_relocs(elf, abs64_type):
    out = []
    for s in elf.shdrs:
        if s["type"] != SHT_RELA: continue
        if not s["name"].startswith(".rela"): continue
        # The reloc section .rela.foo describes patches to section .foo;
        # we only care if .foo is allocated (lives in the loaded image).
        target_name = s["name"][len(".rela"):]
        target = next((t for t in elf.shdrs if t["name"] == target_name), None)
        if not target or not (target["flags"] & SHF_ALLOC):
            continue
        n = s["size"] // 24
        for i in range(n):
            r_offset, r_info, _r_addend = struct.unpack_from(
                "<QQq", elf.buf, s["offset"] + i * 24)
            r_type = r_info & 0xffffffff
            if r_type == abs64_type:
                out.append(r_offset)
    out.sort()
    return out

# --- build the PE .reloc section payload -----------------------------
def build_reloc_blob(rvas):
    """Each block: <page RVA><block size> followed by 16-bit entries
    (type:4 | offset:12). Block size includes the 8-byte header and is
    padded to a 4-byte multiple by appending IMAGE_REL_BASED_ABSOLUTE
    (type 0) entries, which the loader treats as no-ops."""
    blob = bytearray()
    i = 0
    while i < len(rvas):
        page = rvas[i] & ~0xfff
        entries = []
        while i < len(rvas) and (rvas[i] & ~0xfff) == page:
            entries.append((IMAGE_REL_BASED_DIR64 << 12) | (rvas[i] & 0xfff))
            i += 1
        if len(entries) & 1:
            entries.append(IMAGE_REL_BASED_ABSOLUTE << 12)  # 4-byte pad
        size = 8 + 2 * len(entries)
        blob += struct.pack("<II", page, size)
        for e in entries:
            blob += struct.pack("<H", e)
    return bytes(blob)

# --- main ------------------------------------------------------------
def main():
    if len(sys.argv) != 3:
        fail("usage: elf2efi.py INPUT.elf OUTPUT.efi")
    elf = Elf(sys.argv[1])
    _arch_name, pe_machine, abs64_type = ARCHES[elf.e_machine]

    # Pick the loadable PT_LOAD segments and classify by writability.
    # phdr fields (struct <IIQQQQQQ): 0 p_type, 1 p_flags, 2 p_offset,
    # 3 p_vaddr, 4 p_paddr, 5 p_filesz, 6 p_memsz, 7 p_align.
    loads = [p for p in elf.phdrs if p[0] == PT_LOAD and p[6] > 0]
    if not loads:
        fail("no PT_LOAD program headers")
    # Sort by VMA so the section table comes out in image order.
    loads.sort(key=lambda p: p[3])

    # Expect exactly two loads (one R+X, one R+W) -- matches our linker
    # script. Anything else would mean the script was changed and the
    # tool needs to re-learn the layout; bail rather than ship garbage.
    if len(loads) != 2:
        fail("expected 2 PT_LOADs, got %d" % len(loads))
    text_seg, data_seg = loads
    if text_seg[1] & PF_W:
        fail("first PT_LOAD is writable; section ordering is wrong")
    if not (data_seg[1] & PF_W):
        fail("second PT_LOAD is not writable; section ordering is wrong")

    # Each PT_LOAD is laid out so VMA == file offset in the PE image.
    text_va    = text_seg[3]
    text_fsize = text_seg[5]
    text_msize = text_seg[6]
    data_va    = data_seg[3]
    data_fsize = data_seg[5]
    data_msize = data_seg[6]                          # includes .bss tail

    if text_va < HEADER_SIZE:
        fail("text VA 0x%x overlaps PE header span" % text_va)
    if text_va % SECTION_ALIGN or data_va % SECTION_ALIGN:
        fail("PT_LOAD VAs are not page-aligned")

    text_raw = align_up(text_fsize, FILE_ALIGN)
    data_raw = align_up(data_fsize, FILE_ALIGN)

    # .reloc goes after .data in both file and image. Its VA is one
    # SectionAlignment boundary past data's VirtualSize range.
    reloc_blob = build_reloc_blob(collect_relocs(elf, abs64_type))
    reloc_va   = align_up(data_va + data_msize, SECTION_ALIGN)
    reloc_off  = align_up(data_va + data_raw, FILE_ALIGN)
    reloc_size = len(reloc_blob)
    reloc_raw  = align_up(reloc_size, FILE_ALIGN) if reloc_size else 0
    image_size = align_up(reloc_va + max(reloc_size, 0), SECTION_ALIGN)

    # --- PE/COFF headers --------------------------------------------
    dos = bytearray(0x40)
    dos[0:2] = b"MZ"
    struct.pack_into("<I", dos, 0x3c, 0x40)           # e_lfanew

    coff = struct.pack("<HHIIIHH",
        pe_machine,
        3,                                            # NumberOfSections
        0, 0, 0,                                      # TimeDateStamp, sym ptr/cnt
        240,                                          # SizeOfOptionalHeader
        IMAGE_FILE_EXECUTABLE_IMAGE
        | IMAGE_FILE_LINE_NUMS_STRIPPED
        | IMAGE_FILE_LOCAL_SYMS_STRIPPED
        | IMAGE_FILE_DEBUG_STRIPPED
        | IMAGE_FILE_LARGE_ADDRESS_AWARE)

    opt = bytearray()
    opt += struct.pack("<HBB", IMAGE_NT_OPTIONAL_HDR64_MAGIC, 2, 20)
    opt += struct.pack("<III", text_raw, data_raw, data_msize - data_fsize)
    opt += struct.pack("<I",  elf.e_entry)             # AddressOfEntryPoint
    opt += struct.pack("<I",  text_va)                 # BaseOfCode
    opt += struct.pack("<Q",  0)                       # ImageBase
    opt += struct.pack("<II", SECTION_ALIGN, FILE_ALIGN)
    opt += struct.pack("<HHHHHH", 0,0, 0,0, 0,0)       # OS/Image/Subsystem ver
    opt += struct.pack("<I",  0)                       # Win32VersionValue
    opt += struct.pack("<I",  image_size)
    opt += struct.pack("<I",  HEADER_SIZE)             # SizeOfHeaders
    opt += struct.pack("<I",  0)                       # CheckSum
    opt += struct.pack("<HH", IMAGE_SUBSYSTEM_EFI_APPLICATION, 0)
    opt += struct.pack("<QQQQ", 0,0,0,0)               # stack/heap reserve/commit
    opt += struct.pack("<II", 0, 16)                   # LoaderFlags, #DataDirs
    # 16 data directories; entry 5 = BaseRelocationTable
    for i in range(16):
        if i == IMAGE_DIRECTORY_ENTRY_BASERELOC and reloc_size:
            opt += struct.pack("<II", reloc_va, reloc_size)
        else:
            opt += struct.pack("<II", 0, 0)
    if len(opt) != 240:
        fail("optional header size = %d (expected 240)" % len(opt))

    def section_entry(name, vsize, vaddr, rsize, raddr, flags):
        n = name.encode()
        if len(n) > 8: fail("section name too long: " + name)
        n = n + b"\x00" * (8 - len(n))
        return n + struct.pack("<IIIIIIHHI",
            vsize, vaddr, rsize, raddr,
            0, 0, 0, 0, flags)

    sects  = section_entry(".text", text_msize, text_va, text_raw, text_va,
                           IMAGE_SCN_CNT_CODE | IMAGE_SCN_MEM_EXECUTE
                           | IMAGE_SCN_MEM_READ)
    sects += section_entry(".data", data_msize, data_va, data_raw, data_va,
                           IMAGE_SCN_CNT_INITIALIZED_DATA
                           | IMAGE_SCN_MEM_READ | IMAGE_SCN_MEM_WRITE)
    sects += section_entry(".reloc",
                           reloc_size or 0, reloc_va, reloc_raw, reloc_off,
                           IMAGE_SCN_CNT_INITIALIZED_DATA
                           | IMAGE_SCN_MEM_DISCARDABLE | IMAGE_SCN_MEM_READ)

    pe_sig = b"PE\x00\x00"
    header_bytes = bytes(dos) + pe_sig + coff + bytes(opt) + sects
    if len(header_bytes) > HEADER_SIZE:
        fail("PE header (%d B) overruns reserved %d B" % (
            len(header_bytes), HEADER_SIZE))

    # --- assemble the file ------------------------------------------
    out = bytearray(reloc_off + reloc_raw if reloc_size else data_va + data_raw)
    out[:len(header_bytes)] = header_bytes
    def blit_seg(seg, file_off):
        n = seg[5]                                    # p_filesz
        out[file_off:file_off + n] = elf.buf[seg[2]:seg[2] + n]
    blit_seg(text_seg, text_va)
    blit_seg(data_seg, data_va)
    if reloc_size:
        out[reloc_off:reloc_off + reloc_size] = reloc_blob

    with open(sys.argv[2], "wb") as f:
        f.write(out)

if __name__ == "__main__":
    main()
