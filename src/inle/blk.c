// blk -- the disk: virtio-blk, polled, one request in flight, over modern virtio-pci (x64)
// or qemu virt's version-2 virtio-mmio slots. a request spins on the used ring, bounded, so a
// dead device is a refusal, never a hang. every DMA address is pa = va - khhdm, which holds for
// heap memory but not image statics: ring and header live in kmain's block, data in the heap
#include "k.h"
#include "asmops.h"
#include "mmio.h"
#include "bput.h"
#include <stdint.h>

void serial_putc(int);
static void bputs(char const *s) { bput_s(serial_putc, s); }
static void bputn(uintptr_t v) { bput_n(serial_putc, v, 10); }

// per request: 64K keeps one data descriptor under every qemu bound
#define k_blk_chunk 128

static struct {
  uint64_t sectors;                  // 0 = no disk
  volatile uint8_t *desc, *avail, *used, *hdr, *sts;
  uint16_t qsz, avail_idx;
  // mmio notifies at base + 0x50
  volatile uint16_t *notify16;       // pci writes the queue index here
  volatile uint32_t *notify32;       // mmio writes it here
  volatile uint8_t *devst;           // device_status: pci's byte, mmio's word
} kblk;

// the DMA fence around the avail publish and the used read: x86's TSO and volatile suffice,
// a64 reorders Normal against Device
static inline void dma_fence(void) {
#if defined(INLE_DROID)
#elif defined(__aarch64__)
  k_dsb_ish();
#elif defined(__riscv)
  k_fence();
#endif
}

// the split virtqueue, header and status byte, 16-aligned in the DMA block
static int vq_lay(void *dma) {
  kblk.qsz = 8;
  kblk.desc  = dma;
  kblk.avail = kblk.desc + 128;
  kblk.used  = kblk.desc + 192;
  kblk.hdr   = kblk.desc + 288;
  kblk.sts   = kblk.desc + 304;
  for (int i = 0; i < 320; i++) kblk.desc[i] = 0;
  // VRING_AVAIL_F_NO_INTERRUPT, or the completion's INTx resets the machine in silence
  w16(kblk.avail + 0, 1);
  return 1; }

// a request the device never answered may still land: reset the device, which ends its
// DMA, and take the disk away, so no later buffer is one it could still be writing
static void vq_dead(void) {
  if (kblk.notify16) w8(kblk.devst, 0); else w32(kblk.devst, 0);
  for (uint32_t spin = 0; spin < (uint32_t) 1 << 20; spin++)
    if (!(kblk.notify16 ? r8(kblk.devst) : r32(kblk.devst))) break;
  kblk.sectors = 0;
  bputs("disk: virtio-blk stopped answering, reset and dropped\r\n"); }

// type 0 read, 1 write. -> 0 ok, -1 refused, failed or timed out
static int vq_go(uint32_t type, uint64_t lba, void *data, uint32_t bytes) {
  volatile uint8_t *d = kblk.desc;
  w32(kblk.hdr + 0, type);
  w32(kblk.hdr + 4, 0);
  w64(kblk.hdr + 8, lba);
  w8(kblk.sts, 0xff);                          // poison: the device must write 0
  // desc 0: the header
  w64(d + 0, vtop(kblk.hdr)); w32(d + 8, 16); w16(d + 12, 1); w16(d + 14, 1);
  // desc 1: the data, device-writable on a read
  w64(d + 16, vtop(data)); w32(d + 24, bytes);
  w16(d + 28, (uint16_t) (1 | (type ? 0 : 2))); w16(d + 30, 2);
  // desc 2: the status byte, always device-writable
  w64(d + 32, vtop(kblk.sts)); w32(d + 40, 1); w16(d + 44, 2); w16(d + 46, 0);
  w16(kblk.avail + 4 + 2 * (kblk.avail_idx & (kblk.qsz - 1)), 0);
  dma_fence();
  w16(kblk.avail + 2, ++kblk.avail_idx);
  dma_fence();
  if (kblk.notify16) w16((volatile uint8_t*) kblk.notify16, 0);
  else w32((volatile uint8_t*) kblk.notify32, 0);
  for (uint32_t spin = 0; r16(kblk.used + 2) != kblk.avail_idx; spin++)
    if (spin == (uint32_t) 1 << 28) return vq_dead(), -1;   // a refusal, not a hang
  dma_fence();
  return r8(kblk.sts) == 0 ? 0 : -1; }

#if defined(INLE_DROID)
static void blk_scan(void *dma) { }
#elif defined(__x86_64__)
// the modern virtio-pci transport

// a memory BAR's address, 0 when empty or io
static uint64_t pci_bar(uint32_t bdf, uint32_t bar) {
  uint32_t lo = pci_r32(bdf, 0x10 + 4 * bar);
  if (lo & 1) return 0;                        // io-space BAR: not this transport
  uint64_t a = lo & ~(uint64_t) 0xf;
  if ((lo & 6) == 4) a |= (uint64_t) pci_r32(bdf, 0x14 + 4 * bar) << 32;
  return a; }

static int blk_pci(uint32_t bdf, void *dma) {
  // the vendor capability walk: cfg_type 1 = common, 2 = notify, 4 = device
  uint64_t common = 0, notify = 0, devcfg = 0;
  uint32_t nmult = 0;
  // bounded: 48 is all 256 bytes can hold, so a looping list ends
  uint32_t hops = 0;
  for (uint32_t c = pci_r8(bdf, 0x34) & 0xfc; c && hops < 48; c = pci_r8(bdf, c + 1) & 0xfc, hops++) {
    if (pci_r8(bdf, c) != 9) continue;         // 9 = vendor-specific (virtio's)
    uint32_t type = pci_r8(bdf, c + 3);
    uint64_t at = pci_bar(bdf, pci_r8(bdf, c + 4)) + pci_r32(bdf, c + 8);
    if (type == 1) common = at;
    else if (type == 2) notify = at, nmult = pci_r32(bdf, c + 16);
    else if (type == 4) devcfg = at; }
  if (!common || !notify || !devcfg) return 0; // legacy-only device: not driven
  // every x64 door maps only 0..4G; OVMF parks 64-bit BARs above unless ktest.l pins them low
  if (khhdm && (common >> 32 || notify >> 32 || devcfg >> 32))
    return bputs("disk: virtio-blk BAR above 4G, skipped\r\n"), 0;
  // memory decode + bus master on, INTx off (bit 10)
  pci_w32(bdf, 4, pci_r32(bdf, 4) | 6 | 1 << 10);
  volatile uint8_t *cc = (volatile uint8_t*) (khhdm + common);
  kblk.devst = cc + 20;
  w8(cc + 20, 0);                              // device_status: reset
  w8(cc + 20, 1); w8(cc + 20, 1 | 2);          // ACKNOWLEDGE, DRIVER
  w32(cc + 0, 1);                              // device_feature_select: high word
  if (!(r32(cc + 4) & 1)) return 0;            // no VIRTIO_F_VERSION_1: not modern
  w32(cc + 8, 1); w32(cc + 12, 1);             // driver features: VERSION_1 only
  w32(cc + 8, 0); w32(cc + 12, 0);
  w8(cc + 20, 1 | 2 | 8);                      // FEATURES_OK...
  if (!(r8(cc + 20) & 8)) return 0;            // ...must stick
  w16(cc + 22, 0);                             // queue_select 0
  uint16_t qm = r16(cc + 24);
  if (!qm) return 0;
  if (!vq_lay(dma)) return 0;
  if (qm > kblk.qsz) w16(cc + 24, kblk.qsz); else kblk.qsz = qm;
  w64(cc + 32, vtop(kblk.desc));
  w64(cc + 40, vtop(kblk.avail));
  w64(cc + 48, vtop(kblk.used));
  w16(cc + 28, 1);                             // queue_enable
  kblk.notify16 = (volatile uint16_t*)
    (khhdm + notify + (uint64_t) r16(cc + 30) * nmult);
  w8(cc + 20, 1 | 2 | 8 | 4);                  // DRIVER_OK: the device is live
  volatile uint8_t *dc = (volatile uint8_t*) (khhdm + devcfg);
  kblk.sectors = r32(dc) | (uint64_t) r32(dc + 4) << 32;
  return 1; }

static void blk_scan(void *dma) {
  for (uint32_t dev = 0; dev < 32; dev++) {
    uint32_t fns = pci_r8(dev << 3, 14) & 0x80 ? 8 : 1;
    for (uint32_t fn = 0; fn < fns; fn++) {
      uint32_t bdf = dev << 3 | fn, id = pci_r32(bdf, 0);
      if (id == 0xffffffffu) continue;
      // virtio vendor 1af4; 1042 the modern blk id, 1001 the transitional one
      if ((id & 0xffff) != 0x1af4) continue;
      uint32_t d = id >> 16;
      if (d != 0x1042 && d != 0x1001) continue;
      if (blk_pci(bdf, dma)) return; } } }

#elif defined(__aarch64__) || defined(__riscv)
// qemu virt's virtio-mmio slots (32 on arm, 8 on riscv), version 2 under
// force-legacy=false; a version-1 slot is skipped with a word, a configuration face
#if defined(__aarch64__)
#define VIRTIO_MMIO_PHYS 0x0a000000
#define VIRTIO_MMIO_N    32
#define VIRTIO_MMIO_STEP 0x200
#else
#define VIRTIO_MMIO_PHYS 0x10001000
#define VIRTIO_MMIO_N    8
#define VIRTIO_MMIO_STEP 0x1000
#endif

static int blk_mmio(volatile uint8_t *m, void *dma) {
  kblk.devst = m + 0x70;
  w32(m + 0x70, 0);                            // status: reset
  w32(m + 0x70, 1); w32(m + 0x70, 1 | 2);      // ACKNOWLEDGE, DRIVER
  w32(m + 0x14, 1);                            // device_features_sel: high word
  if (!(r32(m + 0x10) & 1)) return 0;          // no VIRTIO_F_VERSION_1
  w32(m + 0x24, 1); w32(m + 0x20, 1);          // driver features: VERSION_1 only
  w32(m + 0x24, 0); w32(m + 0x20, 0);
  w32(m + 0x70, 1 | 2 | 8);                    // FEATURES_OK...
  if (!(r32(m + 0x70) & 8)) return 0;          // ...must stick
  w32(m + 0x30, 0);                            // queue_sel 0
  uint32_t qm = r32(m + 0x34);
  if (!qm) return 0;
  if (!vq_lay(dma)) return 0;
  if (qm < kblk.qsz) kblk.qsz = (uint16_t) qm;
  w32(m + 0x38, kblk.qsz);
  w64(m + 0x80, vtop(kblk.desc));
  w64(m + 0x90, vtop(kblk.avail));
  w64(m + 0xa0, vtop(kblk.used));
  w32(m + 0x44, 1);                            // queue_ready
  kblk.notify32 = (volatile uint32_t*) (m + 0x50);
  w32(m + 0x70, 1 | 2 | 8 | 4);                // DRIVER_OK
  kblk.sectors = r32(m + 0x100) | (uint64_t) r32(m + 0x104) << 32;
  return 1; }

static void blk_scan(void *dma) {
  for (uint32_t i = 0; i < VIRTIO_MMIO_N; i++) {
    volatile uint8_t *m =
      (volatile uint8_t*) (khhdm + VIRTIO_MMIO_PHYS + i * VIRTIO_MMIO_STEP);
    if (r32(m + 0) != 0x74726976 || r32(m + 8) != 2) continue;
    uint32_t v = r32(m + 4);
    if (v != 2) { bputs("disk: legacy virtio-mmio, skipped\r\n"); continue; }
    if (blk_mmio(m, dma)) return; } }

#else
static void blk_scan(void *dma) { }
#endif

// dma: one kmallocw block (>= 320 bytes, 16-aligned) held for the machine's life
void k_blk_init(void *dma) {
  if (!dma) return;
  blk_scan(dma);
  if (kblk.sectors) {
    bputs("disk: virtio-blk, ");
    bputn(kblk.sectors);
    bputs(" sectors\r\n"); } }

uint64_t k_blk_sectors(void) { return kblk.sectors; }

// wr 0 read, 1 write; buf is heap memory. -> 0 ok, -1 refused
int k_blk_rw(uint64_t lba, uint32_t n, void *buf, int wr) {
  if (!kblk.sectors || lba + n < lba || lba + n > kblk.sectors) return -1;
  uint8_t *p = buf;
  while (n) {
    uint32_t c = n > k_blk_chunk ? k_blk_chunk : n;
    if (vq_go(wr ? 1 : 0, lba, p, c * 512) < 0) return -1;
    lba += c; p += (uintptr_t) c * 512; n -= c; }
  return 0; }
