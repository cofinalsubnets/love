// src/inle/uefi/loader.c -- BOOTX64.EFI / BOOTAA64.EFI: load love.elf off our volume, fill its
// kboot, lay the page tables, ExitBootServices, jump. mkefi.l's thunks are efi_call and efi_go.
// integer-only: the x86 entry thunk saves only rsi/rdi, so ms_abi's xmm6..15 must stay untouched

typedef unsigned long long u64;
typedef unsigned int u32;
typedef unsigned short u16;
typedef unsigned char u8;

extern u64 efi_call(void *fn, u64 a, u64 b, u64 c, u64 d, u64 e);
extern void efi_go(u64 pml4, u64 entry);

#define HHDM 0xffff800000000000ull

static u8
 lip_guid[16] = {0xa1,0x31,0x1b,0x5b,0x62,0x95,0xd2,0x11,0x8e,0x3f,0x00,0xa0,0xc9,0x69,0x72,0x3b},
 sfs_guid[16] = {0x22,0x5b,0x4e,0x96,0x59,0x64,0xd2,0x11,0x8e,0x39,0x00,0xa0,0xc9,0x69,0x72,0x3b},
 nfo_guid[16] = {0x92,0x6e,0x57,0x09,0x3f,0x6d,0xd2,0x11,0x8e,0x39,0x00,0xa0,0xc9,0x69,0x72,0x3b},
 gop_guid[16] = {0xde,0xa9,0x42,0x90,0xdc,0x23,0x38,0x4a,0x96,0xfb,0x7a,0xde,0xd0,0x80,0x51,0x6a};

static void **sys, **bs;               // SystemTable / BootServices, u64-slot views

static void say(char *s) {
 u16 w[128];
 int i = 0;
 for (; s[i] && i < 126; i++) w[i] = (u16) (unsigned char) s[i];
 w[i] = 0;
 efi_call(((void **) sys[8])[1], (u64) sys[8], (u64) w, 0, 0, 0); }

static u64 die(char *s) { say("uefi: "); say(s); say("\r\n"); return 1; }

// k.h's k_boot, copied by hand (this compiles before out/lib exists): every field through the
// last one written here must match k.h's layout
#define ram_max 64
struct k_boot {
 u32 ram_n;
 struct { u64 base, len; } ram[ram_max];
 u64 hhdm;
 struct { u64 base; u16 w, h; u32 pitch_px; u8 scale; } fb;
 u8 has_fb;
 u64 date;                             // no door here answers it; kmain's rtc does
 char cmdline[256]; };

static u8 mmap[32768];                 // the UEFI memory map, GetMemoryMap-filled
// pml4, a pdpt per window, four pds, and a spare pd for a relocated kernel; a table's low
// 12 bits are its flags, so the alignment is the contract
static u64 pt[8 * 512] __attribute__((aligned(4096)));

// love.cmd beside love.elf is the boot line, the firmware door's -append; absent is ordinary
static void kcmdline(void *root, struct k_boot *kb) {
 void *cf = 0;
 static u16 cname[9] = {'l','o','v','e','.','c','m','d',0};
 if (efi_call(((void**) root)[1], (u64) root, (u64) &cf, (u64) cname, 1, 0)) return;
 static u8 cbuf[256];
 u64 csz = sizeof cbuf;
 if (efi_call(((void**) cf)[4], (u64) cf, (u64) &csz, (u64) cbuf, 0, 0)) return;
 u64 i = 0;
 for (; i < csz && i + 1 < sizeof kb->cmdline && cbuf[i] >= 32; i++)
  kb->cmdline[i] = (char) cbuf[i];                // stops at the trailing newline
 kb->cmdline[i] = 0; }

// a link address's physical one: x64's image is linked high and loaded low (kproject.l)
static u64 kpa(u8 *e, u64 va) {
 u64 phoff = *(u64*) (e + 32);
 u16 phn = *(u16*) (e + 56), phsz = *(u16*) (e + 54);
 for (u16 i = 0; i < phn; i++) {
  u8 *p = e + phoff + (u64) i * phsz;
  u64 v = *(u64*) (p + 16);
  if (*(u32*) p == 1 && v <= va && va < v + *(u64*) (p + 40)) return *(u64*) (p + 24) + (va - v); }
 return va; }

u64 efi_main(void *handle, void *st) {
 sys = (void**) st;
 bs = (void**) sys[12];

 // our volume: LoadedImage->DeviceHandle -> SimpleFileSystem -> the root dir
 void *lip = 0, *sfs = 0, *root = 0, *f = 0;
 if (efi_call(bs[19], (u64) handle, (u64) lip_guid, (u64) &lip, 0, 0))
  return die("no LoadedImage protocol");
 if (efi_call(bs[19], (u64) ((void**) lip)[3], (u64) sfs_guid, (u64) &sfs, 0, 0))
  return die("no filesystem on the boot volume");
 if (efi_call(((void**) sfs)[1], (u64) sfs, (u64) &root, 0, 0, 0))
  return die("cannot open the boot volume");
 static u16 name[9] = {'l','o','v','e','.','e','l','f',0};
 if (efi_call(((void**) root)[1], (u64) root, (u64) &f, (u64) name, 1, 0))
  return die("no love.elf beside BOOTX64.EFI");

 // size it (FILE_INFO.FileSize at +8), take pages, read it whole
 static u8 nfo[512];
 u64 nsz = sizeof nfo;
 if (efi_call(((void**) f)[8], (u64) f, (u64) nfo_guid, (u64) &nsz, (u64) nfo, 0))
  return die("GetInfo failed on love.elf");
 u64 fsz = *(u64*) (nfo + 8), buf = 0;
 if (efi_call(bs[5], 0, 2, (fsz + 4095) / 4096, (u64) &buf, 0))
  return die("no pages for love.elf");
 u64 rsz = fsz;
 if (efi_call(((void**) f)[4], (u64) f, (u64) &rsz, buf, 0, 0) || rsz != fsz)
  return die("short read on love.elf");

 // a PT_LOAD's paddr is the physical address it wants
 u8 *e = (u8 *) buf;
 if (*(u32 *) e != 0x464c457f) return die("love.elf is not an ELF");
 u64 phoff = *(u64*) (e + 32), entry = *(u64*) (e + 24);
 u16 phn = *(u16*) (e + 56), phsz = *(u16*) (e + 54);
 u64 lo = ~0ull, hi = 0;
 for (u16 i = 0; i < phn; i++) {
  u8 *p = e + phoff + (u64) i * phsz;
  if (*(u32*) p != 1) continue;                       // PT_LOAD
  u64 pa = *(u64*) (p + 24), msz = *(u64*) (p + 40);
  if (pa < lo) lo = pa;
  if (pa + msz > hi) hi = pa + msz; }
 if (hi <= lo) return die("love.elf carries no load segments");
 // the window is laid in 2M pages
 lo &= ~0x1fffffull;
 u64 npg = (hi - lo + 4095) / 4096, span = lo, kbase = lo;
 // at the link address if firmware parts with it, else anywhere 2M-aligned
 if (efi_call(bs[5], 2, 2, npg, (u64) &span, 0)) {
  span = 0;
  if (efi_call(bs[5], 0, 2, npg + 512, (u64) &span, 0))   // + 2M of alignment slack
   return die("no pages for the kernel");
  kbase = (span + 0x1fffff) & ~0x1fffffull;
  // relocating shadows virtual lo..hi, where efi_go still fetches code and uses the stack
  u64 imb = ((u64*) lip)[8], ims = ((u64*) lip)[9], sp = (u64) &span;
#if defined(__aarch64__)
  // the override splits only the first RAM gig's block
  if (lo < 0x40000000ull || hi > 0x80000000ull)
   return die("the kernel wants to live outside the first RAM gig");
#else
  if (hi > 0x40000000ull)
   return die("the kernel wants more than the first GiB");
#endif
  if ((imb < hi && lo < imb + ims) || (sp >= lo && sp < hi))
   return die("firmware placed us inside the kernel's own window"); }
 for (u16 i = 0; i < phn; i++) {
  u8 *p = e + phoff + (u64) i * phsz;
  if (*(u32*) p != 1) continue;
  u64 off = *(u64*) (p + 8), pa = *(u64*) (p + 24);
  u64 flz = *(u64*) (p + 32), msz = *(u64*) (p + 40);
  u8 *d = (u8*) (kbase + (pa - lo));
  for (u64 j = 0; j < flz; j++) d[j] = e[off + j];
  for (u64 j = flz; j < msz; j++) d[j] = 0; }

 // kboot's home: the kernel symtab (sh_type 2), symbol "kboot"
 u64 shoff = *(u64*) (e + 40);
 u16 shn = *(u16*) (e + 60), shsz = *(u16*) (e + 58);
 struct k_boot *kb = 0;
 for (u16 i = 0; i < shn && !kb; i++) {
  u8 *sh = e + shoff + (u64) i * shsz;
  if (*(u32*) (sh + 4) != 2) continue;                // SHT_SYMTAB
  u8 *lnk = e + shoff + (u64) (*(u32*) (sh + 40)) * shsz;
  u8 *str = e + *(u64 *) (lnk + 24);
  u64 so = *(u64*) (sh + 24), sn = *(u64*) (sh + 32) / 24;
  for (u64 j = 0; j < sn; j++) {
   u8 *sy = e + so + j * 24;
   char *nm = (char*) (str + *(u32 *) sy);
   if (nm[0] == 'k' && nm[1] == 'b' && nm[2] == 'o' && nm[3] == 'o'
       && nm[4] == 't' && !nm[5]) {
    kb = (struct k_boot*) (kbase + (kpa(e, *(u64*) (sy + 8)) - lo));   // its load, then wherever we landed
    break; } } }
 if (!kb) return die("no kboot symbol in love.elf");
 kb->hhdm = HHDM;
 kcmdline(root, kb);

 // a GOP is not a framebuffer: PixelBltOnly (format 3, virtio-gpu under edk2) has no address,
 // so the base and the format are the test
 void *gop = 0;
 if (!efi_call(bs[40], (u64) gop_guid, 0, (u64) &gop, 0, 0) && gop) {
  u8 *m = (u8*) ((void**) gop)[3];
  u8 *info = (u8*) *(u64*) (m + 8);
  u64 fb = *(u64*) (m + 24);
  u32 fmt = *(u32*) (info + 12);
  if (fb && fmt < 3) {                                 // 0/1 are the 32-bit orders, 2 a bitmask
   kb->fb.base = fb;
   kb->fb.w = (u16) *(u32*) (info + 4);
   kb->fb.h = (u16) *(u32*) (info + 8);
   kb->fb.pitch_px = *(u32*) (info + 32);
   kb->has_fb = 1; } }

 // tables before ExitBootServices, while say works: identity to run in, the hhdm (no-execute)
 // as a true direct map -- only the low window bends, since blk.c's vtop inverts khhdm + P
 for (u64 i = 0; i < 8 * 512; i++) pt[i] = 0;
#if defined(__aarch64__)
 // l0_lo, l0_hi, two L1s, l2_dev, l2_ram. table 3, block 1: 0x705 Normal, 0x401 Device
 for (u64 i = 0; i < 512; i++) pt[4 * 512 + i] = (i << 21) | 0x401;   // MMIO, phys 0..1G
 for (u64 i = 1; i < 4; i++) {                                        // RAM, 1G blocks
  pt[2 * 512 + i] = (i << 30) | 0x705;
  pt[3 * 512 + i] = (i << 30) | 0x705; }
 pt[2 * 512] = (u64) &pt[4 * 512] | 3;
 pt[3 * 512] = (u64) &pt[4 * 512] | 3;
 if (kbase != lo) {
  u64 *l2 = pt + 5 * 512;                        // the low window's RAM gig, in 2M blocks
  for (u64 i = 0; i < 512; i++) l2[i] = (0x40000000ull + (i << 21)) | 0x705;
  for (u64 v = lo; v < hi; v += 0x200000)
   l2[(v - 0x40000000ull) >> 21] = (kbase + (v - lo)) | 0x705;
  pt[2 * 512 + 1] = (u64) l2 | 3; }
 pt[0] = (u64) &pt[2 * 512] | 3;                                  // TTBR0[0]
 // PXNTable | UXNTable: no fetch under the hhdm. efi_go reads TTBR1's root at pt + 4096
 pt[512 + 256] = (u64) &pt[3 * 512] | 3 | (3ull << 59);            // TTBR1[256]
#else
 for (u64 i = 0; i < 2048; i++) pt[3 * 512 + i] = (i << 21) | 0x83;
 for (u64 i = 0; i < 4; i++) pt[2 * 512 + i] = (u64) &pt[(3 + i) * 512] | 3;
 for (u64 i = 0; i < 4; i++) pt[1 * 512 + i] = (u64) &pt[(3 + i) * 512] | 3;
 if (kbase != lo) {
  u64 *kpd = pt + 7 * 512;                       // the low window's first GiB, in 2M pages
  for (u64 i = 0; i < 512; i++) kpd[i] = (i << 21) | 0x83;
  for (u64 v = lo; v < hi; v += 0x200000) kpd[v >> 21] = (kbase + (v - lo)) | 0x83;
  pt[512] = (u64) kpd | 3; }
 pt[0] = (u64) &pt[512] | 3;
 // NX on the hhdm's top entry covers it all; identity keeps X for efi_go, and [511], the
 // image window, is identity's twin
 pt[256] = (u64) &pt[2 * 512] | 3 | (1ull << 63);
 pt[511] = (u64) &pt[512] | 3;
#endif

 // kboot.ram: conventional (7) only, so the heap never eats this stack, the tables or the kernel
 u64 msz = sizeof mmap, key = 0, dsz = 0, dvr = 0;
 if (efi_call(bs[7], (u64) &msz, (u64) mmap, (u64) &key, (u64) &dsz, (u64) &dvr))
  return die("GetMemoryMap failed");
 if (efi_call(bs[29], (u64) handle, key, 0, 0, 0)) {
  msz = sizeof mmap;
  if (efi_call(bs[7], (u64) &msz, (u64) mmap, (u64) &key, (u64) &dsz, (u64) &dvr)
      || efi_call(bs[29], (u64) handle, key, 0, 0, 0))
   return die("ExitBootServices refused twice"); }
 for (u64 o = 0; o + dsz <= msz; o += dsz) {
  u8 *d = mmap + o;
  if (*(u32 *) d != 7) continue;
  u64 pa = *(u64 *) (d + 8), np = *(u64 *) (d + 24);
  if (pa < 0x100000) continue;                         // low memory stays the firmware's
  if (pa >= 0x100000000ull) continue;                  // above the mapped 4G
  if (kb->ram_n >= ram_max) break;
  kb->ram[kb->ram_n].base = pa;
  kb->ram[kb->ram_n].len = np * 4096;
  kb->ram_n++; }

 efi_go((u64) pt, entry);
 return 1; }
