// dtb -> kboot, for every arch booting off a flat device tree: included once per arch, which
// spells k_hhdm and k_map_top first, so the constants fold into the one function
#include "k.h"
#include "../love/bytes.h"

#if !defined(k_hhdm) || !defined(k_map_top)
#error "dtb.h: spell k_hhdm (the stub's window) and k_map_top (its far edge) first"
#endif

// RAM below the image's far edge is spoken for, and nothing else reserves it: handed to the
// heap, the kernel eats itself. a value transpose.l patches into the file
extern uintptr_t const k_image_top;


// flat-tree tokens (all fields big-endian, everything 4-aligned)
#define FDT_BEGIN_NODE 1
#define FDT_END_NODE   2
#define FDT_PROP       3
#define FDT_NOP        4
#define FDT_END        9

static int is(char const *a, char const *b) {
  while (*a && *a == *b) { a++; b++; }
  return *a == *b; }

// a property's one value, 32 bits or 64
static uint64_t dtb_cell(uint8_t const *p, uint32_t len) { return len == 8 ? ld64be(p) : ld32be(p); }

// RAM a..b given to the heap, but the initrd's pages m0..m1, kept as the image's are
static void dtb_give(uint64_t a, uint64_t b, uint64_t m0, uint64_t m1) {
  if (m0 < m1 && a < m1 && m0 < b) {
    if (a < m0) k_ram_give(a, m0 - a);
    if (m1 < b) k_ram_give(m1, b - m1);
    return; }
  k_ram_give(a, b - a); }

#ifdef k_fwcfg
// qemu's fw_cfg (an arch's dtb.c spells k_fwcfg, its mmio base): opt/love/initrd laid at the
// image's far edge, where the heap is never given -> its length, 0 with no such file. the
// data port reads a byte at a time, the selector takes a big-endian key
static uint64_t dtb_fwcfg(uint64_t at) {
  volatile uint8_t const *dp = (volatile uint8_t const *) (k_hhdm + k_fwcfg);
  volatile uint16_t *sel = (volatile uint16_t *) (k_hhdm + k_fwcfg + 8);
  *sel = 0x1900;                                     // the file directory, key 0x19
  uint32_t n = 0;
  for (int i = 0; i < 4; i++) n = n << 8 | *dp;
  if (n > 4096) return 0;
  for (uint32_t i = 0; i < n; i++) {
    uint8_t e[64];
    for (int j = 0; j < 64; j++) e[j] = *dp;
    if (!is((char const *) e + 8, "opt/love/initrd")) continue;
    uint64_t len = (uint64_t) e[0] << 24 | e[1] << 16 | e[2] << 8 | e[3];
    if (at + len > k_map_top) return 0;
    *sel = (uint16_t) (e[5] << 8 | e[4]);           // its key, big-endian as the directory has it
    uint8_t *to = (uint8_t *) (k_hhdm + at);
    for (uint64_t j = 0; j < len; j++) to[j] = *dp;
    return len; }
  return 0; }
#endif

// two walks: /chosen first (the boot line, the initrd), then the memory, which gives around it
void dtb_to_kboot(uint64_t dtb_pa) {
  uint8_t const *f = (uint8_t const *) (k_hhdm + dtb_pa);
  if (ld32be(f) != 0xd00dfeed) return;
  char const *str    = (char const *) (f + ld32be(f + 12));   // off_dt_strings
  uint64_t k1 = (k_image_top + 0xfff) & ~0xfffull;   // page-rounded physical far edge
  uint64_t r0 = 0, r1 = 0, m0 = 0, m1 = 0;           // the initrd, and its pages
  kboot.hhdm = k_hhdm;
  for (int pass = 0; pass < 2; pass++) {
  uint8_t const *p   = f + ld32be(f + 8);            // off_dt_struct
  uint32_t ac = 2, sc = 2;                         // root's cell counts (virt: 2/2)
  int depth = 0, memd = 0, chos = 0;               // the depth of the memory / chosen node we are in
#ifdef k_fwcfg
  if (pass && !(r0 < r1)) r0 = k1, r1 = k1 + dtb_fwcfg(k1);
#endif
  if (pass && r0 < r1 && r1 <= k_map_top)
    m0 = r0 & ~0xfffull, m1 = (r1 + 0xfff) & ~0xfffull,
    kboot.initrd = (void const *) (k_hhdm + r0), kboot.initrd_len = r1 - r0;
  for (;;) {
    uint32_t tok = ld32be(p); p += 4;
    if (tok == FDT_END) break;
    if (tok == FDT_NOP) continue;
    if (tok == FDT_BEGIN_NODE) {
      char const *nm = (char const *) p;
      uint32_t n = 0; while (nm[n]) n++;
      p += (n + 1 + 3) & ~3u;
      depth++;
      // a memory bank is a child of root named memory or memory@...
      if (depth == 2 && nm[0]=='m' && nm[1]=='e' && nm[2]=='m' && nm[3]=='o'
          && nm[4]=='r' && nm[5]=='y' && (nm[6] == 0 || nm[6] == '@'))
        memd = depth;
      if (depth == 2 && is(nm, "chosen")) chos = depth;
      continue; }
    if (tok == FDT_END_NODE) {
      if (depth == memd) memd = 0;
      if (depth == chos) chos = 0;
      depth--;
      continue; }
    if (tok != FDT_PROP) break;                    // a malformed tree: stop, keep what we have
    uint32_t len = ld32be(p), nameoff = ld32be(p + 4);
    p += 8;
    char const *pn = str + nameoff;
    if (depth == 1 && is(pn, "#address-cells")) ac = ld32be(p);
    if (depth == 1 && is(pn, "#size-cells"))    sc = ld32be(p);
    if (!pass && chos && depth == chos && is(pn, "bootargs") && len)
      k_cmdline((char const *) p, len);
    if (!pass && chos && depth == chos && is(pn, "linux,initrd-start")) r0 = dtb_cell(p, len);
    if (!pass && chos && depth == chos && is(pn, "linux,initrd-end"))   r1 = dtb_cell(p, len);

    if (pass && memd && depth == memd && is(pn, "reg")) {
      uint32_t step = (ac + sc) * 4;
      for (uint32_t o = 0; step && o + step <= len; o += step) {
        uint64_t a = ac == 2 ? ld64be(p + o) : ld32be(p + o);
        uint64_t s = sc == 2 ? ld64be(p + o + ac*4) : ld32be(p + o + ac*4);
        uint64_t b = a + s;
        if (a < k1) a = k1;                        // firmware + dtb + hole + image, one span
        if (b > k_map_top) b = k_map_top;          // above the mapped window
        if (b > a) dtb_give(a, b, m0, m1); } }
    p += (len + 3) & ~3u; } } }
