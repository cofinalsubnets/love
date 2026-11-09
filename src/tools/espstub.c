/* espstub -- an esp32 flash reader and writer run from RAM by esprom -x: the rom's slip frames,
 * its uart and SPI1 by register, as the rom left them after spi_attach. op 0xD2 [off len]
 * answers len bytes and their crc32, off and len by 64, len at most 32K; op 0xD4 [off] + 4K,
 * the request's checksum their crc32, erases that sector and programs it.
 *   love mooncc -t xtensa -nostdlib -Ttext 0x40080000 -Tdata 0x3FFB0000 -o espstub.elf src/tools/espstub.c */
typedef unsigned u32;
typedef unsigned char u8;
#define R(a) (*(volatile u32 *)(a))
#define UFIFO 0x3FF40000
#define USTAT 0x3FF4001C
#define SPI1 0x3FF42000
static void tx(int c) { while ((R(USTAT) >> 16 & 0xff) >= 120) ; R(UFIFO) = (u32)c; }
static int rx(void) { while (!(R(USTAT) & 0xff)) ; return (int)(R(UFIFO) & 0xff); }
static void stx(int c) { if (c == 0xC0) tx(0xDB), tx(0xDC); else if (c == 0xDB) tx(0xDB), tx(0xDD); else tx(c); }
static void stx32(u32 v) { for (int i = 0; i < 4; i++) stx((int)(v >> 8 * i & 0xff)); }
static u32 crc(u32 c, u32 w) {
  for (int i = 0; i < 32; i++) c = (c ^ (w >> i & 1)) & 1 ? c >> 1 ^ 0xEDB88320u : c >> 1;
  return c;
}
/* a frame's bytes into b, at most n; its length, or -1 past n */
static int frame(u8 *b, int n) {
  int k = 0, c;
  while (rx() != 0xC0) ;
  while ((c = rx()) != 0xC0) {
    if (c == 0xDB) c = rx() == 0xDC ? 0xC0 : 0xDB;
    if (k < n) b[k] = (u8)c;
    k++;
  }
  return k <= n ? k : -1;
}
/* a reply: direction 1, the op, the size, a value; the data and two status bytes follow */
static void head(int op, int n, u32 v) { tx(0xC0), stx(1), stx(op), stx(n & 0xff), stx(n >> 8), stx32(v); }
static void reply(int op, int st) { head(op, 2, 0), stx(st), stx(0), tx(0xC0); }
/* 64 bytes as the rom reads them: the byte count over the address, then go */
static void spiread(u32 a, u32 *w) {
  while (R(SPI1)) ;
  R(SPI1 + 0x04) = a | 64u << 24;
  R(SPI1) = 1u << 31;
  while (R(SPI1)) ;
  for (int i = 0; i < 16; i++) w[i] = R(SPI1 + 0x80 + 4 * i);
}
/* the flash's status by RDSR until its busy bit clears */
static void idle(void) {
  do { R(SPI1 + 0x10) = 0, R(SPI1) = 1u << 27; while (R(SPI1)) ; } while (R(SPI1 + 0x10) & 1);
}
/* a command bit after WREN, the address under a byte count, then the flash idle again */
static void wcmd(u32 bit, u32 a) {
  idle();
  R(SPI1) = 1u << 30;
  while (R(SPI1)) ;
  R(SPI1 + 0x04) = a;
  R(SPI1) = bit;
  while (R(SPI1)) ;
  idle();
}
static u32 rd32(const u8 *b) { return b[0] | b[1] << 8 | b[2] << 16 | (u32)b[3] << 24; }
static u32 crcb(const u8 *b, int n) {
  u32 c = ~0u;
  for (int i = 0; i < n; i++)
    for (int k = 0; k < 8; k++) c = (c ^ (b[i] >> k & 1)) & 1 ? c >> 1 ^ 0xEDB88320u : c >> 1;
  return ~c;
}
/* a sector erased (SE), then 32 bytes a page program (PP), as the rom writes */
static int wsector(u32 a, const u8 *d) {
  if (a & 4095) return 1;
  wcmd(1u << 24, a & 0xffffff);
  for (u32 i = 0; i < 4096; i += 32) {
    idle();
    for (int j = 0; j < 8; j++) R(SPI1 + 0x80 + 4 * j) = rd32(d + i + 4 * j);
    wcmd(1u << 25, (a + i & 0xffffff) | 32u << 24);
  }
  return 0;
}
void _start(void) {
  static u8 b[4096 + 16];                             /* a write's frame: too big for the rom's stack */
  u32 w[16];
  head(0xD0, 6, 0), stx('O'), stx('H'), stx('A'), stx('I'), stx(0), stx(0), tx(0xC0);
  for (;;) {
    int n = frame(b, sizeof b), op = b[1];
    if (n < 8 || b[0] != 0) continue;
    if (op == 0xD2 && n == 16) {
      u32 a = rd32(b + 8), l = rd32(b + 12), c = ~0u;
      if (a & 63 || l & 63 || l > 32768) { reply(op, 1); continue; }
      head(op, (int)l + 6, 0);
      for (u32 i = 0; i < l; i += 64) {
        spiread(a + i, w);
        for (int j = 0; j < 16; j++) c = crc(c, w[j]), stx32(w[j]);
      }
      stx32(~c), stx(0), stx(0), tx(0xC0);
    } else if (op == 0xD4 && n == 8 + 4 + 4096)
      reply(op, crcb(b + 12, 4096) != rd32(b + 4) ? 3 : wsector(rd32(b + 8), b + 12));
    else reply(op, 2);
  }
}
