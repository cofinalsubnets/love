// hda -- the sound card: Intel HD Audio, polled, one output stream. the body of
// love.h's k_horn_* C face on inle; src/host/horn.c's port stands over it, and
// src/inle/doomsnd.c's mixer calls it directly.
//
// x64 finds the controller by PCI class (04.03 -- every laptop and desktop of the
// last fifteen years, and qemu's `-device intel-hda`); BAR0 is the register file.
// commands ride the CORB/RIRB rings (the immediate registers are optional silicon
// and qemu has none); the codec walk starts at each present codec's audio function
// group, takes every output pin that is wired to something (a speaker, a headphone
// jack, a line out) and routes it back through selectors and mixers to a DAC,
// unmuting as it goes. every DAC found is given stream 1, so speakers and
// headphones play the one ring together.
//
// the stream is a 128K sample ring under a 32-entry buffer descriptor list, and
// the write door is the ring: land what fits behind the DMA head, answer 0 when
// full. the play position comes off the DMA position buffer (LPIB where a
// controller has not written one yet), and everything the head has passed is
// zeroed by k_horn_poll -- a writer that stops leaves silence, not a loop of its
// last second. no interrupts: blk.c's posture, for blk.c's reason.
//
// ⚠ every DMA address the device sees is PHYSICAL: pa = va - khhdm, which holds
// for kmallocw memory and not for image statics, so the rings and the sample
// buffer are all heap.
#include "k.h"
#include "asmops.h"
#include <stdint.h>
#include <string.h>

void serial_putc(int);
static void hputs(char const *s) { while (*s) serial_putc(*s++); }
static void hputn(uint64_t v) {
  char b[20]; int i = 0;
  do b[i++] = (char) ('0' + v % 10), v /= 10; while (v);
  while (i) serial_putc(b[--i]); }

#define hda_ring   (128u << 10)      // 0.68 s at 48k stereo: deep enough that a slow
                                     // frame loop never underruns; a writer wanting less
                                     // lag keeps its lead short (k_horn_lag)
#define hda_bdln   32                // ring / bdl entries = 4K apiece
#define hda_lead   4096u             // the head's prefetch margin: never land closer than this
#define hda_spin   (1u << 24)        // a dead device is a refusal, never a hang

static struct {
  volatile uint8_t *mm;              // BAR0, mapped; NULL = no controller
  volatile uint8_t *corb, *rirb, *bdl, *pos;
  unsigned char *ring;
  uint32_t corbn, rirbn;             // ring depths
  uint16_t corbwp, rirbrp;
  uint32_t sd;                       // the output stream descriptor's register base
  uint32_t vendor;
  uint8_t cad;                       // the codec being spoken to
  int dacs, pins;                    // what the walk found
  int open;
  uint64_t wpos, hw, zpos;           // running byte counts: landed, played, silenced to
} khda;

static inline uint8_t  r8 (volatile uint8_t *p) { return *p; }
static inline uint16_t r16(volatile uint8_t *p) { return *(volatile uint16_t*) p; }
static inline uint32_t r32(volatile uint8_t *p) { return *(volatile uint32_t*) p; }
static inline void w8 (volatile uint8_t *p, uint8_t v)  { *p = v; }
static inline void w16(volatile uint8_t *p, uint16_t v) { *(volatile uint16_t*) p = v; }
static inline void w32(volatile uint8_t *p, uint32_t v) { *(volatile uint32_t*) p = v; }
static inline uintptr_t vtop(volatile void *p) { return (uintptr_t) p - khhdm; }

#if defined(__x86_64__)
// --- PCI config space ------------------------------------------------------
static uint32_t pci_r32(uint32_t bdf, uint32_t off) {
  k_outl(0xcf8, 0x80000000u | bdf << 8 | (off & 0xfc));
  return k_inl(0xcfc); }
static void pci_w32(uint32_t bdf, uint32_t off, uint32_t v) {
  k_outl(0xcf8, 0x80000000u | bdf << 8 | (off & 0xfc));
  k_outl(0xcfc, v); }
static uint32_t pci_r8(uint32_t bdf, uint32_t off) {
  return pci_r32(bdf, off) >> 8 * (off & 3) & 0xff; }
static void pci_w8(uint32_t bdf, uint32_t off, uint32_t v) {
  uint32_t sh = 8 * (off & 3), w = pci_r32(bdf, off) & ~(0xffu << sh);
  pci_w32(bdf, off, w | (v & 0xff) << sh); }

// the controller's memory BAR, 0 when unassigned or beyond the 4G every door maps
static uint64_t pci_bar0(uint32_t bdf) {
  uint32_t lo = pci_r32(bdf, 0x10);
  if (lo & 1) return 0;
  uint64_t a = lo & ~(uint64_t) 0xf;
  if ((lo & 6) == 4) a |= (uint64_t) pci_r32(bdf, 0x14) << 32;
  return khhdm && a >> 32 ? 0 : a; }

// firmware may leave the function in D3; the PM capability's control word says
static void pci_d0(uint32_t bdf) {
  for (uint32_t c = pci_r8(bdf, 0x34) & 0xfc; c; c = pci_r8(bdf, c + 1) & 0xfc)
    if (pci_r8(bdf, c) == 1) {
      uint32_t cs = pci_r32(bdf, c + 4);
      if (cs & 3) {
        pci_w32(bdf, c + 4, cs & ~3u);
        for (uint32_t i = 0; i < 1u << 20; i++) (void) pci_r32(bdf, c + 4); }   // ~10 ms settle
      return; } }

// the first class-04.03 function on bus 0 -> its bdf, or ~0
static uint32_t hda_find(void) {
  for (uint32_t dev = 0; dev < 32; dev++) {
    uint32_t fns = pci_r8(dev << 3, 14) & 0x80 ? 8 : 1;
    for (uint32_t fn = 0; fn < fns; fn++) {
      uint32_t bdf = dev << 3 | fn, id = pci_r32(bdf, 0);
      if (id == 0xffffffffu) continue;
      if ((pci_r32(bdf, 8) >> 8) == 0x040300) return bdf; } }
  return ~0u; }

// --- the command rings -----------------------------------------------------
// one verb to the codec at cad, its response back. an unsolicited response in the
// RIRB is skipped. -> 0, or -1 when nothing answered.
static int hda_cmd(uint32_t nid, uint32_t verb, uint32_t *resp) {
  volatile uint8_t *m = khda.mm;
  uint16_t wp = (uint16_t) ((khda.corbwp + 1) % khda.corbn);
  w32(khda.corb + 4 * wp, (uint32_t) khda.cad << 28 | nid << 20 | verb);
  w16(m + 0x48, wp);
  khda.corbwp = wp;
  for (uint32_t spin = 0; spin < hda_spin; spin++) {
    uint16_t rwp = r16(m + 0x58) & 0xff;
    if (rwp == khda.rirbrp) continue;
    uint16_t rp = (uint16_t) ((khda.rirbrp + 1) % khda.rirbn);
    uint32_t r = r32(khda.rirb + 8 * rp), ex = r32(khda.rirb + 8 * rp + 4);
    khda.rirbrp = rp;
    // the response count is met at every answer (RINTCNT 1): clearing the flag is
    // what lets the next verb through -- qemu holds the CORB until it is
    w8(m + 0x5d, 0x05);
    if (ex & 0x10) continue;                          // unsolicited: not ours
    return *resp = r, 0; }
  return -1; }

static uint32_t param(uint32_t nid, uint32_t p) {
  uint32_t r = 0;
  return hda_cmd(nid, 0xf0000 | p, &r) ? 0 : r; }
static void verb(uint32_t nid, uint32_t v) { uint32_t r; hda_cmd(nid, v, &r); }

// --- the codec walk --------------------------------------------------------
static uint32_t afg_nid;

static int wtype(uint32_t nid) { return (int) (param(nid, 9) >> 20 & 0xf); }

// entry i of nid's connection list; the list is 8-bit (4 per word) or 16-bit (2 per)
static uint32_t conn(uint32_t nid, uint32_t i) {
  uint32_t l = param(nid, 0xe), r = 0;
  if (l & 0x80) {
    hda_cmd(nid, 0xf0200 | (i & ~1u), &r);
    return r >> 16 * (i & 1) & 0x7fff; }
  hda_cmd(nid, 0xf0200 | (i & ~3u), &r);
  return r >> 8 * (i & 3) & 0x7f; }

static uint32_t conn_n(uint32_t nid) { return param(nid, 0xe) & 0x7f; }

// unmute an amp at 0 dB: the caps' offset is the 0 dB step. a widget without the
// override bit wears the function group's caps.
static void unmute(uint32_t nid, int out, uint32_t idx) {
  uint32_t caps = param(nid, 9);
  if (!(caps & (out ? 4 : 2))) return;
  uint32_t ac = param(caps & 8 ? nid : afg_nid, out ? 0x12 : 0x0d), gain = ac & 0x7f;
  verb(nid, 0x30000 | (out ? 0x8000 : 0x4000) | 0x3000 | idx << 8 | gain); }

static void power_up(uint32_t nid) {
  if (param(nid, 9) & 1 << 10) verb(nid, 0x70500); }

// from a pin back to a DAC, depth-first, selecting and unmuting the way home.
// -> 1 when a DAC was reached under nid.
static int route(uint32_t nid, int depth) {
  int t = wtype(nid);
  if (t == 0) {                                     // an audio output: the DAC
    power_up(nid);
    unmute(nid, 1, 0);
    verb(nid, 0x70610);                             // stream 1, channel 0
    khda.dacs++;
    return 1; }
  if (depth > 5 || (t != 2 && t != 3 && t != 4)) return 0;
  uint32_t n = conn_n(nid);
  for (uint32_t i = 0; i < n && i < 16; i++) {
    if (!route(conn(nid, i), depth + 1)) continue;
    power_up(nid);
    if (t != 2) verb(nid, 0x70100 | i);             // a selector or pin picks; a mixer sums
    unmute(nid, 0, i);
    unmute(nid, 1, 0);
    return 1; }
  return 0; }

// a pin worth driving: output-capable, wired to something, and an analogue out
static int pin_out(uint32_t nid) {
  if (!(param(nid, 0xc) & 1 << 4)) return 0;
  uint32_t cfg = 0;
  hda_cmd(nid, 0xf1c00, &cfg);
  return (cfg >> 30 & 3) != 1 && (cfg >> 20 & 0xf) <= 2; }

static void codec_walk(void) {
  uint32_t sub = param(0, 4), fg0 = sub >> 16 & 0xff, fgn = sub & 0xff;
  for (uint32_t fg = fg0; fg < fg0 + fgn; fg++) {
    if ((param(fg, 5) & 0xff) != 1) continue;       // an audio function group
    afg_nid = fg;
    verb(fg, 0x70500);                              // D0
    uint32_t ws = param(fg, 4), w0 = ws >> 16 & 0xff, wn = ws & 0xff;
    for (uint32_t w = w0; w < w0 + wn; w++) {
      if (wtype(w) != 4 || !pin_out(w)) continue;
      if (!route(w, 0)) continue;
      uint32_t cfg = 0;
      hda_cmd(w, 0xf1c00, &cfg);
      verb(w, 0x70700 | (0x40 | ((cfg >> 20 & 0xf) == 2 ? 0x80 : 0)));   // out enable (+ hp)
      if (param(w, 0xc) & 1 << 16) verb(w, 0x70c02);                     // EAPD on
      khda.pins++; } } }

// --- the controller --------------------------------------------------------
static int spin_until(volatile uint8_t *p, uint8_t mask, uint8_t want) {
  for (uint32_t i = 0; i < hda_spin; i++) if ((r8(p) & mask) == want) return 0;
  return -1; }

static int hda_bring_up(uint32_t bdf, void *dma) {
  uint64_t bar = pci_bar0(bdf);
  if (!bar) return hputs("sound: hda BAR unreachable, skipped\r\n"), 0;
  khda.vendor = pci_r32(bdf, 0) & 0xffff;
  pci_d0(bdf);
  pci_w32(bdf, 4, pci_r32(bdf, 4) | 6 | 1 << 10);   // memory + bus master, INTx off
  // the snoop quirks the linux driver carries: DMA that bypasses the cache reads a
  // stale ring. intel: TCSEL to class 0 and DEVC's NOSNOOP off; amd/ati: the SB450 bit
  if (khda.vendor == 0x8086) {
    pci_w8(bdf, 0x44, pci_r8(bdf, 0x44) & ~7u);
    pci_w32(bdf, 0x78, pci_r32(bdf, 0x78) & ~(1u << 11)); }
  else if (khda.vendor == 0x1022 || khda.vendor == 0x1002)
    pci_w8(bdf, 0x42, (pci_r8(bdf, 0x42) & ~7u) | 2);
  volatile uint8_t *m = khda.mm = (volatile uint8_t*) (khhdm + bar);
  // the block: CORB 1K, RIRB 2K, BDL 512, the position buffer 256; all 128-aligned
  uintptr_t a = ((uintptr_t) dma + 127) & ~(uintptr_t) 127;
  khda.corb = (volatile uint8_t*) a;
  khda.rirb = khda.corb + 1024;
  khda.bdl  = khda.corb + 3072;
  khda.pos  = khda.corb + 3584;
  for (uint32_t i = 0; i < 3840; i++) khda.corb[i] = 0;
  // controller reset: CRST low, then high, then the codecs get their 25 frames
  w32(m + 0x08, r32(m + 0x08) & ~1u);
  if (spin_until(m + 0x08, 1, 0)) return 0;
  w32(m + 0x08, r32(m + 0x08) | 1);
  if (spin_until(m + 0x08, 1, 1)) return 0;
  for (uint32_t i = 0; i < 1u << 16; i++) (void) r32(m + 0x08);
  uint16_t gcap = r16(m + 0x00);
  uint32_t iss = gcap >> 8 & 0xf, oss = gcap >> 12 & 0xf;
  if (!oss) return hputs("sound: hda has no output stream\r\n"), 0;
  if (!(gcap & 1) && (vtop(khda.corb) >> 32)) return hputs("sound: hda is 32-bit, dma above 4G\r\n"), 0;
  khda.sd = 0x80 + 0x20 * iss;                      // the first output descriptor
  w32(m + 0x20, 0);                                 // no interrupts, ever
  // CORB: sized to the largest the silicon takes, reset the read pointer, run
  uint8_t cs = r8(m + 0x4e), sz = cs & 0x40 ? 2 : cs & 0x20 ? 1 : 0;
  khda.corbn = sz == 2 ? 256 : sz == 1 ? 16 : 2;
  w8(m + 0x4c, 0);
  w8(m + 0x4e, (uint8_t) ((cs & 0xfc) | sz));
  w32(m + 0x40, (uint32_t) vtop(khda.corb));
  w32(m + 0x44, (uint32_t) (vtop(khda.corb) >> 32));
  w16(m + 0x48, 0);
  w16(m + 0x4a, 0x8000);
  for (uint32_t i = 0; i < 1u << 12; i++) (void) r16(m + 0x4a);
  w16(m + 0x4a, 0);
  for (uint32_t i = 0; i < 1u << 12; i++) (void) r16(m + 0x4a);
  khda.corbwp = 0;
  // RIRB likewise; RINTCNT 1 so the write pointer moves per response
  uint8_t rs = r8(m + 0x5e); sz = rs & 0x40 ? 2 : rs & 0x20 ? 1 : 0;
  khda.rirbn = sz == 2 ? 256 : sz == 1 ? 16 : 2;
  w8(m + 0x5c, 0);
  w8(m + 0x5e, (uint8_t) ((rs & 0xfc) | sz));
  w32(m + 0x50, (uint32_t) vtop(khda.rirb));
  w32(m + 0x54, (uint32_t) (vtop(khda.rirb) >> 32));
  w16(m + 0x58, 0x8000);
  w16(m + 0x5a, 1);
  khda.rirbrp = 0;
  // DMA run + the response interrupt ENABLED: with INTCTL zero it reaches no vector,
  // but it is what raises RIRBSTS's flag, and clearing that flag (hda_cmd) is what
  // re-arms the CORB after every RINTCNT-th response -- qemu drains nothing otherwise
  w8(m + 0x5c, 0x03);
  w8(m + 0x4c, 0x02);
  // the DMA position buffer: 8 bytes per stream, enabled by its low bit
  w32(m + 0x70, (uint32_t) vtop(khda.pos) | 1);
  w32(m + 0x74, (uint32_t) (vtop(khda.pos) >> 32));
  // every codec that answered the reset
  uint16_t present = r16(m + 0x0e);
  for (uint32_t c = 0; c < 15; c++) {
    if (!(present & 1u << c)) continue;
    khda.cad = (uint8_t) c;
    uint32_t id = 0;
    if (hda_cmd(0, 0xf0000, &id)) continue;
    codec_walk(); }
  return khda.dacs > 0; }

static void hda_scan(void *dma) {
  uint32_t bdf = hda_find();
  if (bdf == ~0u) return;
  if (!hda_bring_up(bdf, dma)) {
    hputs("sound: hda at "); hputn(bdf >> 3); hputs(" would not come up: gcap ");
    hputn(khda.mm ? r16(khda.mm) : 0); hputs(" codecs "); hputn(khda.mm ? r16(khda.mm + 0x0e) : 0);
    hputs(" dac "); hputn((uint64_t) khda.dacs); hputs("\r\n");
    khda.mm = NULL; } }

#else
static void hda_scan(void *dma) { }
#endif

// --- the stream: the C face ------------------------------------------------
// the play position as a running count: the position buffer's word, LPIB where it
// is still zero, unwrapped against the last reading
static void hda_head(void) {
  volatile uint8_t *sd = khda.mm + khda.sd;
  uint32_t p = r32(khda.pos + 8 * ((khda.sd - 0x80) / 0x20));
  if (!p) p = r32(sd + 0x04);
  p %= hda_ring;
  uint64_t base = khda.hw - khda.hw % hda_ring, nh = base + p;
  if (nh < khda.hw) nh += hda_ring;
  khda.hw = nh; }

// silence what the head has played: [zpos, hw), at most one ring's worth
static void hda_silence(void) {
  if (khda.hw - khda.zpos > hda_ring) khda.zpos = khda.hw - hda_ring;
  while (khda.zpos < khda.hw) {
    uint32_t o = (uint32_t) (khda.zpos % hda_ring), n = (uint32_t) (khda.hw - khda.zpos);
    if (n > hda_ring - o) n = hda_ring - o;
    memset(khda.ring + o, 0, n);
    khda.zpos += n; } }

void k_horn_poll(void) {
  if (!khda.open) return;
  hda_head();
  hda_silence(); }

// the stream format word, per rate: base 48k or 44.1k, a multiplier, a divisor;
// 16-bit stereo in the low byte
static uint32_t hda_fmt(int rate) {
  switch (rate) {
    case 48000: return 0x0011;
    case 44100: return 0x4011;
    case 96000: return 0x0811;
    case 88200: return 0x4811;
    case 32000: return 0x0a11;                       // 48k * 2 / 3
    case 24000: return 0x0111;
    case 22050: return 0x4111;
    case 16000: return 0x0211;
    case 11025: return 0x4311;
    case 8000:  return 0x0511;
    default: return 0; } }

int k_horn_open(int rate) {
  if (!khda.mm || !khda.ring) return -1;
  uint32_t fmt = hda_fmt(rate);
  if (!fmt) return -1;
  volatile uint8_t *sd = khda.mm + khda.sd;
  // reset the descriptor, then lay the ring under it
  w8(sd + 0, 0);
  w8(sd + 0, 1);
  spin_until(sd + 0, 1, 1);
  w8(sd + 0, 0);
  spin_until(sd + 0, 1, 0);
  memset(khda.ring, 0, hda_ring);
  for (uint32_t i = 0; i < hda_bdln; i++) {
    uint64_t pa = vtop(khda.ring + i * (hda_ring / hda_bdln));
    w32(khda.bdl + 16 * i + 0, (uint32_t) pa);
    w32(khda.bdl + 16 * i + 4, (uint32_t) (pa >> 32));
    w32(khda.bdl + 16 * i + 8, hda_ring / hda_bdln);
    w32(khda.bdl + 16 * i + 12, 0); }
  w32(sd + 0x08, hda_ring);
  w16(sd + 0x0c, hda_bdln - 1);
  w16(sd + 0x12, (uint16_t) fmt);
  w32(sd + 0x18, (uint32_t) vtop(khda.bdl));
  w32(sd + 0x1c, (uint32_t) (vtop(khda.bdl) >> 32));
  w8(sd + 2, 0x10);                                 // stream number 1
  // the DACs take the same format word
  for (uint32_t c = 0; c < 15; c++) {
    if (!(r16(khda.mm + 0x0e) & 1u << c)) continue;
    khda.cad = (uint8_t) c;
    uint32_t sub = param(0, 4), fg0 = sub >> 16 & 0xff, fgn = sub & 0xff;
    for (uint32_t fg = fg0; fg < fg0 + fgn; fg++) {
      if ((param(fg, 5) & 0xff) != 1) continue;
      uint32_t ws = param(fg, 4), w0 = ws >> 16 & 0xff, wn = ws & 0xff;
      for (uint32_t w = w0; w < w0 + wn; w++)
        if (wtype(w) == 0) verb(w, 0x20000 | fmt); } }
  w32(khda.pos + 8 * ((khda.sd - 0x80) / 0x20), 0);
  khda.wpos = khda.hw = khda.zpos = 0;
  khda.open = 1;
  w8(sd + 0, 0x02);                                 // run
  return 0; }

intptr_t k_horn_write(unsigned char const *src, uintptr_t n) {
  if (!khda.open) return -1;
  hda_head();
  hda_silence();
  if (khda.wpos < khda.hw + hda_lead) khda.wpos = khda.hw + hda_lead;   // (re)start ahead of the head
  uint64_t queued = khda.wpos - khda.hw;
  uintptr_t room = queued + hda_lead < hda_ring ? hda_ring - hda_lead - (uintptr_t) queued : 0;
  if (n > room) n = room;
  n &= ~(uintptr_t) 3;
  for (uintptr_t i = 0; i < n;) {
    uint32_t o = (uint32_t) (khda.wpos % hda_ring), k = (uint32_t) (n - i);
    if (k > hda_ring - o) k = hda_ring - o;
    memcpy(khda.ring + o, src + i, k);
    khda.wpos += k; i += k; }
  return (intptr_t) n; }

uintptr_t k_horn_lag(void) {
  if (!khda.open) return 0;
  hda_head();
  return khda.wpos > khda.hw ? (uintptr_t) (khda.wpos - khda.hw) / 4 : 0; }

void k_horn_close(void) {
  if (!khda.open) return;
  w8(khda.mm + khda.sd, 0);
  khda.open = 0; }

// the boot door: dma is one kmallocw block (>= 3840 + 128 bytes) the command rings,
// the buffer list and the position buffer live in for the machine's life
void k_hda_init(void *dma) {
  if (!dma) return;
  void *kmallocw(uintptr_t);
  khda.ring = kmallocw(b2w(hda_ring));
  hda_scan(dma);
  if (khda.mm) {
    hputs("sound: hda, ");
    hputn((uint64_t) khda.dacs);
    hputs(" dac ");
    hputn((uint64_t) khda.pins);
    hputs(" pin\r\n"); } }
