// test/gate/dtb.c -- the device-tree door on trees whose answers are written down here.
// inle/dtb.h is the walk both boot doors ride (a64_dtb.c, rv64_dtb.c), and until
// now the only thing that ever ran it was a qemu boot, which reaches exactly ONE tree:
// virt's, with 2/2 cells and one bank. So this builds trees on the host -- the other
// cell widths, a nested `reg` that is not memory, both clamps, a torn magic, a cmdline
// past the buffer -- and reads kboot back.
//
// The door compiles here exactly as an arch door compiles it, macros and all; k_hhdm 0
// makes a host pointer its own "physical" address.
#define k_hhdm    0ull
#define k_map_top 0x100000000ull
#include "dtb.h"

#include <stdio.h>
#include <string.h>

// the two symbols an arch door borrows: kmain owns kboot, and the projection patches
// k_image_top into the file (tools/kproject.l).
struct k_boot kboot;
uintptr_t const k_image_top = 0x80210000;
#define k1 0x80210000ull                 // ..page-aligned already, so k_image_top is it

// --- a flat tree, built by hand -------------------------------------------------
static unsigned char sbuf[2048]; static unsigned sn;    // the struct block
static char strbuf[512];         static unsigned sr;    // ..and the string block
static unsigned char blob[4096];

static void s32(uint32_t v) {
  sbuf[sn++] = v >> 24; sbuf[sn++] = v >> 16; sbuf[sn++] = v >> 8; sbuf[sn++] = v; }
static void spad(void) { while (sn & 3) sbuf[sn++] = 0; }
static uint32_t sname(char const *s) {                    // intern a property name
  uint32_t at = sr; while (*s) strbuf[sr++] = *s++; strbuf[sr++] = 0; return at; }
static void node(char const *nm) {
  s32(FDT_BEGIN_NODE); while (*nm) sbuf[sn++] = *nm++; sbuf[sn++] = 0; spad(); }
static void endnode(void) { s32(FDT_END_NODE); }
static void nop(void) { s32(FDT_NOP); }
static void prop(char const *nm, void const *v, uint32_t len) {
  s32(FDT_PROP); s32(len); s32(sname(nm));
  memcpy(sbuf + sn, v, len); sn += len; spad(); }
static void prop32(char const *nm, uint32_t v) {
  unsigned char b[4] = { v >> 24, v >> 16, v >> 8, v }; prop(nm, b, 4); }
static void propstr(char const *nm, char const *s) {
  prop(nm, s, (uint32_t) strlen(s) + 1); }
// a reg property: `n` values of `w` bytes each, big-endian, the order given
static void propreg(uint64_t const *v, unsigned n, unsigned w) {
  unsigned char b[64]; unsigned i, j;
  for (i = 0; i < n; i++)
    for (j = 0; j < w; j++) b[i * w + j] = (unsigned char) (v[i] >> (8 * (w - 1 - j)));
  prop("reg", b, n * w); }

static void begin(void) { sn = 0; sr = 0; memset(&kboot, 0, sizeof kboot); }
// assemble header + struct + strings; only magic and the two offsets are ever read
static unsigned char *tree(uint32_t magic) {
  unsigned h = 0, off_s = 64, off_str = 64 + ((sn + 3) & ~3u);
  memset(blob, 0, sizeof blob);
  unsigned char *p = blob;
  uint32_t hdr[10] = { magic, off_str + sr, off_s, off_str, 0, 17, 16, 0, sr, sn };
  for (h = 0; h < 10; h++) {
    p[h*4] = hdr[h] >> 24; p[h*4+1] = hdr[h] >> 16;
    p[h*4+2] = hdr[h] >> 8; p[h*4+3] = hdr[h]; }
  memcpy(blob + off_s, sbuf, sn);
  memcpy(blob + off_str, strbuf, sr);
  return blob; }
static void walk(uint32_t magic) { dtb_to_kboot((uint64_t) (uintptr_t) tree(magic)); }

// --- the answers ----------------------------------------------------------------
static int fails, checks;
static void ck(char const *what, uint64_t want, uint64_t got) {
  checks++;
  if (want == got) return;
  printf("FAIL %s: want 0x%llx got 0x%llx\n", what,
         (unsigned long long) want, (unsigned long long) got);
  fails++; }

// the root every case opens with: 2/2 cells unless the case says otherwise
static void root(unsigned ac, unsigned sc) {
  begin(); node(""); prop32("#address-cells", ac); prop32("#size-cells", sc); }
static void memnode(char const *nm, uint64_t const *v, unsigned n, unsigned w) {
  node(nm); propstr("device_type", "memory"); propreg(v, n, w); endnode(); }
static void close(void) { endnode(); s32(FDT_END); }

int main(void) {
  { // virt's own shape: 2/2 cells, one bank, a cmdline, and a nested reg that is NOT memory
    uint64_t reg[2] = { 0x80000000, 0x08000000 }, uart[2] = { 0x10000000, 0x100 };
    root(2, 2);
    node("chosen"); propstr("bootargs", "test/kernel/all.l"); endnode();
    memnode("memory@80000000", reg, 2, 8);
    node("soc"); node("uart@10000000"); propreg(uart, 2, 8); endnode(); endnode();
    close(); walk(0xd00dfeed);
    ck("virt.ram_n", 1, kboot.ram_n);
    ck("virt.base",  k1, kboot.ram[0].base);
    ck("virt.len",   0x88000000ull - k1, kboot.ram[0].len);
    ck("virt.hhdm",  k_hhdm, kboot.hhdm);
    ck("virt.args",  0, (uint64_t) strcmp(kboot.cmdline, "test/kernel/all.l")); }

  { // 1/1 cells -- the same bank, half the words
    uint64_t reg[2] = { 0x80000000, 0x08000000 };
    root(1, 1); memnode("memory@80000000", reg, 2, 4); close(); walk(0xd00dfeed);
    ck("cells11.ram_n", 1, kboot.ram_n);
    ck("cells11.base",  k1, kboot.ram[0].base);
    ck("cells11.len",   0x88000000ull - k1, kboot.ram[0].len); }

  { // two banks: one ending under the image is not a span at all, the other rides whole
    uint64_t low[2] = { 0x80000000, 0x00100000 }, high[2] = { 0x90000000, 0x01000000 };
    root(2, 2);
    memnode("memory@80000000", low, 2, 8);
    memnode("memory@90000000", high, 2, 8);
    close(); walk(0xd00dfeed);
    ck("banks.ram_n", 1, kboot.ram_n);
    ck("banks.base",  0x90000000, kboot.ram[0].base);
    ck("banks.len",   0x01000000, kboot.ram[0].len); }

  { // two pairs in ONE reg, which is the other way a tree says two banks
    uint64_t two[4] = { 0x90000000, 0x01000000, 0xa0000000, 0x02000000 };
    root(2, 2); memnode("memory@90000000", two, 4, 8); close(); walk(0xd00dfeed);
    ck("pairs.ram_n", 2, kboot.ram_n);
    ck("pairs.base0", 0x90000000, kboot.ram[0].base);
    ck("pairs.base1", 0xa0000000, kboot.ram[1].base);
    ck("pairs.len1",  0x02000000, kboot.ram[1].len); }

  { // past the window the stub mapped: trimmed to its edge, not handed over whole
    uint64_t reg[2] = { 0xf0000000, 0x20000000 };
    root(2, 2); memnode("memory@f0000000", reg, 2, 8); close(); walk(0xd00dfeed);
    ck("clamp.ram_n", 1, kboot.ram_n);
    ck("clamp.base",  0xf0000000, kboot.ram[0].base);
    ck("clamp.len",   k_map_top - 0xf0000000ull, kboot.ram[0].len); }

  { // the window's own edge, from both sides: ending ON it is whole, a byte past is cut
    uint64_t on[2] = { 0xf0000000, 0x10000000 }, past[2] = { 0xf0000000, 0x10000001 };
    root(2, 2); memnode("memory@f0000000", on, 2, 8); close(); walk(0xd00dfeed);
    ck("edge.on.len", 0x10000000, kboot.ram[0].len);
    root(2, 2); memnode("memory@f0000000", past, 2, 8); close(); walk(0xd00dfeed);
    ck("edge.past.len", 0x10000000, kboot.ram[0].len); }

  { // ..and a bank living entirely above it is no span at all
    uint64_t over[2] = { 0x110000000, 0x1000000 };
    root(2, 2); memnode("memory@110000000", over, 2, 8); close(); walk(0xd00dfeed);
    ck("over.ram_n", 0, kboot.ram_n); }

  { // NOPs are legal anywhere a token is, and a tree full of them says the same thing
    uint64_t reg[2] = { 0x80000000, 0x08000000 };
    root(2, 2); nop();
    node("chosen"); nop(); propstr("bootargs", "quiet"); nop(); endnode(); nop();
    memnode("memory@80000000", reg, 2, 8); nop();
    close(); walk(0xd00dfeed);
    ck("nop.ram_n", 1, kboot.ram_n);
    ck("nop.len",   0x88000000ull - k1, kboot.ram[0].len);
    ck("nop.args",  0, (uint64_t) strcmp(kboot.cmdline, "quiet")); }

  { // no chosen node: the cmdline stays empty, which is what a plain boot looks like
    uint64_t reg[2] = { 0x80000000, 0x08000000 };
    root(2, 2); memnode("memory@80000000", reg, 2, 8); close(); walk(0xd00dfeed);
    ck("bare.args", 0, (uint64_t) kboot.cmdline[0]); }

  { // a bootargs longer than the buffer is cut and terminated, never run past
    char big[400]; unsigned i;
    uint64_t reg[2] = { 0x80000000, 0x08000000 };
    for (i = 0; i < sizeof big - 1; i++) big[i] = 'x';
    big[sizeof big - 1] = 0;
    root(2, 2);
    node("chosen"); propstr("bootargs", big); endnode();
    memnode("memory@80000000", reg, 2, 8);
    close(); walk(0xd00dfeed);
    ck("long.cut", sizeof kboot.cmdline - 1, strlen(kboot.cmdline));
    ck("long.ram", 1, kboot.ram_n); }

  { // a torn magic is not a tree: nothing is filled, and the caller still comes back
    uint64_t reg[2] = { 0x80000000, 0x08000000 };
    root(2, 2); memnode("memory@80000000", reg, 2, 8); close(); walk(0xdeadbeef);
    ck("torn.ram_n", 0, kboot.ram_n);
    ck("torn.hhdm",  0, kboot.hhdm);
    ck("torn.args",  0, (uint64_t) kboot.cmdline[0]); }

  printf("test/gate/dtb: %d checks, %d failed\n", checks, fails);
  return fails != 0; }
