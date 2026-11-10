// the Teensy 4.1's microSD slot: uSDHC1 on GPIO_SD_B0_00..05, 4-bit, polled, one block per
// command, the data by PIO so the D-cache never stands between card and string. SD v2 cards
// only (SDHC/SDXC block addressing, SDSC byte addressing)
#include <stdint.h>
#include "teensy41.h"

uintptr_t te_ms(void);

#define SD_BASE 0x402C0000u
#define SD_BLK  (SD_BASE + 0x04u)   // BLKSIZE[12:0], BLKCNT[31:16]
#define SD_ARG  (SD_BASE + 0x08u)
#define SD_XFR  (SD_BASE + 0x0Cu)
#define SD_RSP0 (SD_BASE + 0x10u)
#define SD_DATA (SD_BASE + 0x20u)
#define SD_PRES (SD_BASE + 0x24u)   // CIHB 0, CDIHB 1, SDSTB 3, BWEN 10, BREN 11, DAT0 24
#define SD_PROT (SD_BASE + 0x28u)   // DTW[2:1], EMODE[5:4]
#define SD_SYS  (SD_BASE + 0x2Cu)   // DVS[7:4], SDCLKFS[15:8], DTOCV[19:16], RSTA 24, INITA 27
#define SD_INT  (SD_BASE + 0x30u)   // CC 0, TC 1, BWR 4, BRR 5, errors 16..22
#define SD_INTE (SD_BASE + 0x34u)
#define SD_SIGE (SD_BASE + 0x38u)
#define SD_WML  (SD_BASE + 0x44u)
#define SD_MIX  (SD_BASE + 0x48u)   // DTDSEL 4: card to host
#define SD_VEND (SD_BASE + 0xC0u)

#define INT_ERR 0x007F0000u
#define CCM_CCGR6  (CCM_BASE + 0x80u)
#define CCM_CSCMR1 (CCM_BASE + 0x1Cu)
#define PFD_528_SET (CCM_ANALOG_BASE + 0x104u)
#define PFD_528_CLR (CCM_ANALOG_BASE + 0x108u)

// response kinds, as CMD_XFR_TYP's RSPTYP | CCCEN | CICEN
enum { R0 = 0, R2 = 1u << 16 | 1u << 19, R3 = 2u << 16, R1 = 2u << 16 | 3u << 19, R1B = 3u << 16 | 3u << 19,
       DATA = 1u << 21 };

static struct { uint32_t n, rca, hc; } sd;

static int until(uint32_t a, uint32_t m, uint32_t want, uint32_t ms) {
  uintptr_t t = te_ms();
  while ((REG(a) & m) != want) if (te_ms() - t > ms) return 0;
  return 1; }

// one command; 0 on a response, -1 on an error or a timeout
static int cmd(uint32_t i, uint32_t arg, uint32_t kind) {
  if (!until(SD_PRES, kind & DATA ? 3u : 1u, 0, 500)) return -1;
  REG(SD_INT) = ~0u;
  REG(SD_ARG) = arg;
  REG(SD_XFR) = i << 24 | kind;
  uintptr_t t = te_ms();
  for (;;) {
    uint32_t s = REG(SD_INT);
    if (s & INT_ERR) { REG(SD_SYS) |= 1u << 25; until(SD_SYS, 1u << 25, 0, 100); return -1; }   // RSTC
    if (s & 1u) { REG(SD_INT) = 1u; break; }
    if (te_ms() - t > 500) return -1; }
  return (kind & 3u << 16) == 3u << 16 && !until(SD_PRES, 1u << 24, 1u << 24, 500) ? -1 : 0; }

static int acmd(uint32_t i, uint32_t arg, uint32_t kind) {
  return cmd(55, sd.rca << 16, R1) < 0 ? -1 : cmd(i, arg, kind); }

// SDCLK = 198 MHz / (2 * fs) / (dvs + 1), fs a power of two
static void clk(uint32_t fs, uint32_t dvs) {
  REG(SD_SYS) = (REG(SD_SYS) & ~0x000FFFF0u) | 0xEu << 16 | fs << 8 | dvs << 4;
  until(SD_PRES, 1u << 3, 1u << 3, 10); }

static void pads(void) {
  for (uint32_t k = 0; k < 6; k++) {
    REG(IOMUXC_BASE + 0x1BCu + 4 * k) = 0;                         // ALT0, uSDHC1
    REG(IOMUXC_BASE + 0x3ACu + 4 * k) = k == 1 ? 0x10B8u : 0x70B8u; } }   // clock bare, the rest pulled up

// the card brought up, answering its sector count; 0 for no card
static uint32_t sd_up(void) {
  sd.n = sd.rca = sd.hc = 0;
  REG(PFD_528_SET) = 1u << 7;                                      // PLL2 PFD0 = 528 * 18 / 24 = 396 MHz
  REG(PFD_528_CLR) = 0x3Fu;
  REG(PFD_528_SET) = 24u;
  REG(PFD_528_CLR) = 1u << 7;
  REG(CCM_CCGR6) |= CCGR_ON(1);
  REG(CCM_CSCMR1) |= 1u << 16;                                     // uSDHC1 off PFD0
  REG(CCM_CSCDR1) = (REG(CCM_CSCDR1) & ~(7u << 11)) | 1u << 11;   // /2: 198 MHz
  pads();
  REG(SD_SYS) |= 1u << 24;
  if (!until(SD_SYS, 1u << 24, 0, 100)) return 0;
  REG(SD_VEND) = 0x2000F801u;                                      // 3.3 V signalling
  REG(SD_MIX) |= 1u << 31;
  REG(SD_PROT) = 2u << 4;                                          // little endian, 1 bit
  REG(SD_WML) = 128u << 16 | 128u;                                 // a block per watermark
  REG(SD_INTE) = 0x117F003Fu;
  REG(SD_SIGE) = 0;
  clk(0x40, 3);                                                    // ~390 kHz
  REG(SD_SYS) |= 1u << 27;                                         // 80 clocks
  until(SD_SYS, 1u << 27, 0, 10);
  if (cmd(0, 0, R0) < 0) return 0;
  if (cmd(8, 0x1AAu, R1) < 0 || (REG(SD_RSP0) & 0xFFFu) != 0x1AAu) return 0;
  uint32_t ocr = 0;
  for (uintptr_t t = te_ms(); !(ocr & 1u << 31); ) {
    if (acmd(41, 0x40300000u, R3) < 0 || te_ms() - t > 1000) return 0;
    ocr = REG(SD_RSP0); }
  sd.hc = ocr >> 30 & 1;
  if (cmd(2, 0, R2) < 0 || cmd(3, 0, R1) < 0) return 0;
  sd.rca = REG(SD_RSP0) >> 16;
  if (cmd(9, sd.rca << 16, R2) < 0) return 0;
  // the CSD sits in RSP0..3 with its CRC byte shed; v2's C_SIZE[69:48] is RSP1[29:8]
  uint32_t csd3 = REG(SD_RSP0 + 12), csd1 = REG(SD_RSP0 + 4), csd2 = REG(SD_RSP0 + 8), n;
  if (csd3 >> 22 == 1) n = ((csd1 >> 8 & 0x3FFFFFu) + 1) * 1024;
  else {                                                           // v1: (C_SIZE+1) << (C_SIZE_MULT+2+READ_BL_LEN-9)
    uint32_t cs = (csd2 & 0x3u) << 10 | csd1 >> 22, mult = csd1 >> 7 & 7, bl = csd2 >> 8 & 15;
    n = (cs + 1) << (mult + 2 + bl - 9); }
  if (cmd(7, sd.rca << 16, R1B) < 0) return 0;
  if (acmd(6, 2, R1) < 0) return 0;                                // 4 bit
  REG(SD_PROT) = (REG(SD_PROT) & ~6u) | 1u << 1;
  if (!sd.hc && cmd(16, 512, R1) < 0) return 0;
  clk(1, 3);                                                       // ~25 MHz
  return sd.n = n; }

uint32_t sd_sectors(void) { return sd.n ? sd.n : sd_up(); }

// n blocks from lba, one command each; 0 ok, -1 failed
int sd_rw(uint32_t lba, uint32_t n, void *buf, int wr) {
  if (!sd.n || lba + n > sd.n || lba + n < lba) return -1;
  uint8_t *p = buf;
  for (uint32_t b = 0; b < n; b++, p += 512) {
    REG(SD_BLK) = 1u << 16 | 512u;
    REG(SD_MIX) = (REG(SD_MIX) & ~0x3Fu) | (wr ? 0 : 1u << 4);
    if (cmd(wr ? 24 : 17, sd.hc ? lba + b : (lba + b) * 512, R1 | DATA) < 0) return -1;
    uint32_t want = wr ? 1u << 4 : 1u << 5;
    uintptr_t t = te_ms();
    while (!(REG(SD_INT) & (want | INT_ERR))) if (te_ms() - t > 500) return -1;
    if (REG(SD_INT) & INT_ERR) return -1;
    REG(SD_INT) = want;
    for (uint32_t k = 0; k < 512; k += 4) {
      if (wr) REG(SD_DATA) = p[k] | p[k + 1] << 8 | p[k + 2] << 16 | (uint32_t) p[k + 3] << 24;
      else { uint32_t v = REG(SD_DATA); p[k] = (uint8_t) v, p[k + 1] = (uint8_t) (v >> 8),
                                         p[k + 2] = (uint8_t) (v >> 16), p[k + 3] = (uint8_t) (v >> 24); } }
    if (!until(SD_INT, 1u << 1 | INT_ERR, 1u << 1, 1000)) return -1;
    REG(SD_INT) = 1u << 1;
    if (wr && !until(SD_PRES, 1u << 24, 1u << 24, 1000)) return -1; }   // programming done
  return 0; }
