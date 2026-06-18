// virtio-net: the kship kernel's NIC. A minimal LEGACY virtio-net driver
// (transitional device 1af4:1000) over PCI I/O space, FULLY POLLED -- no NIC
// interrupt. The PIT already wakes `hlt` at 100 Hz (port/kship/x86_64/x86_64.S
// timer_isr), so the RX used-ring poll fits the kernel's ai_ready/ai_wait_fds
// model; and stray PCI IRQs reboot (isrs[] 37..47 -> k_reset), so we set the
// PCI Interrupt-Disable bit and never touch INTx/MSI-X.
//
// Stage 2a here: PCI enumerate -> reset/feature handshake -> set up the receive
// (q0) and transmit (q1) virtqueues -> DRIVER_OK -> read the MAC. RX fill, TX,
// and the IP/UDP layer land in later stages (see crew/kship.md). x86-specific for
// now (PIO + PCI mechanism #1); the virtqueue/virtio-net logic is portable and
// will factor out when aarch64 grows a NIC.
#include <stdint.h>
#include <stdbool.h>
#include "k.h"               // khhdm, net_init

extern void serial_putc(int);
extern void *malloc(__SIZE_TYPE__);

// --- bring-up logging on COM1 (serial_putc is the reliable panic channel) ----
static void np_s(char const *s) { while (*s) serial_putc(*s++); }
static void np_x(uint64_t v, int nibbles) {
  for (int i = (nibbles - 1) * 4; i >= 0; i -= 4)
    serial_putc("0123456789abcdef"[(v >> i) & 0xf]); }
static void np_mac(uint8_t const *m) {
  for (int i = 0; i < 6; i++) { if (i) serial_putc(':'); np_x(m[i], 2); } }

// --- x86 port I/O ------------------------------------------------------------
static inline void outb(uint16_t p, uint8_t v)  { asm volatile ("outb %0, %1" :: "a"(v), "Nd"(p)); }
static inline void outw(uint16_t p, uint16_t v) { asm volatile ("outw %0, %1" :: "a"(v), "Nd"(p)); }
static inline void outl(uint16_t p, uint32_t v) { asm volatile ("outl %0, %1" :: "a"(v), "Nd"(p)); }
static inline uint8_t  inb(uint16_t p) { uint8_t  v; asm volatile ("inb %1, %0" : "=a"(v) : "Nd"(p)); return v; }
static inline uint16_t inw(uint16_t p) { uint16_t v; asm volatile ("inw %1, %0" : "=a"(v) : "Nd"(p)); return v; }
static inline uint32_t inl(uint16_t p) { uint32_t v; asm volatile ("inl %1, %0" : "=a"(v) : "Nd"(p)); return v; }

// --- PCI config space, mechanism #1 (ports 0xCF8 address / 0xCFC data) --------
#define PCI_ADDR 0xCF8
#define PCI_DATA 0xCFC
static uint32_t pci_cfg(uint8_t bus, uint8_t dev, uint8_t fn, uint8_t off) {
  outl(PCI_ADDR, 0x80000000u | (uint32_t) bus << 16 | (uint32_t) dev << 11
                 | (uint32_t) fn << 8 | (off & 0xfc));
  return inl(PCI_DATA); }
static void pci_cfg_w(uint8_t bus, uint8_t dev, uint8_t fn, uint8_t off, uint32_t v) {
  outl(PCI_ADDR, 0x80000000u | (uint32_t) bus << 16 | (uint32_t) dev << 11
                 | (uint32_t) fn << 8 | (off & 0xfc));
  outl(PCI_DATA, v); }

// PCI command register bits (offset 0x04, low 16): I/O space, bus master (DMA),
// interrupt disable (we poll, and a stray INTx vector would reboot us).
#define PCI_CMD_IO   0x0001
#define PCI_CMD_BM   0x0004
#define PCI_CMD_INTX 0x0400

// --- legacy virtio I/O registers (offsets into the device's I/O BAR; no MSI-X) -
#define V_HOST_FEAT    0x00     // u32 RO: features the device offers
#define V_GUEST_FEAT   0x04     // u32 RW: features we accept
#define V_QUEUE_PFN    0x08     // u32 RW: ring phys >> 12
#define V_QUEUE_SIZE   0x0c     // u16 RO: this queue's depth
#define V_QUEUE_SEL    0x0e     // u16 RW: which queue the above act on
#define V_QUEUE_NOTIFY 0x10     // u16 RW: kick the device for queue N
#define V_STATUS       0x12     // u8  RW: device status handshake
#define V_ISR          0x13     // u8  RO: interrupt status (read to ack)
#define V_CONFIG       0x14     // device-specific config (MAC at +0)

#define VS_ACK       0x01
#define VS_DRIVER    0x02
#define VS_DRIVER_OK 0x04
#define VS_FAILED    0x80

#define VNET_F_MAC        (1u << 5)    // device-supplied MAC at V_CONFIG

// --- the split virtqueue (legacy layout: one page-aligned contiguous region) --
#define VRING_DESC_F_NEXT  1
#define VRING_DESC_F_WRITE 2          // device writes (an RX buffer)

struct vring_desc { uint64_t addr; uint32_t len; uint16_t flags; uint16_t next; };
struct vring_avail { uint16_t flags, idx; uint16_t ring[]; };
struct vring_used_elem { uint32_t id, len; };
struct vring_used { uint16_t flags, idx; struct vring_used_elem ring[]; };

struct vq {
  uint16_t num;                 // depth
  struct vring_desc *desc;
  struct vring_avail *avail;
  struct vring_used *used;
  uint16_t last_used;           // last used->idx we consumed
};

static struct netdev {
  uint16_t io;                  // I/O BAR base port
  uint8_t mac[6];
  struct vq rx, tx;
  bool up;
} nic;

// guest-physical of a heap pointer (no IOMMU in qemu -> phys == DMA addr).
static uint64_t phys(void *v) { return (uint64_t) ((uintptr_t) v - khhdm); }

// total bytes of a legacy vring of `num` descriptors: desc[] then avail, padded
// to a page, then used.
static unsigned vring_bytes(unsigned num) {
  unsigned a = 16 * num + (6 + 2 * num);       // desc + avail
  return ((a + 4095) & ~4095u) + (6 + 8 * num); // + used (page-aligned)
}

// page-aligned, zeroed DMA region. Over-allocate and round up; the slack base is
// intentionally leaked (the NIC lives for the life of the kernel).
static void *dma_page(unsigned sz) {
  uint8_t *b = malloc(sz + 4096);
  if (!b) return 0;
  uintptr_t a = ((uintptr_t) b + 4095) & ~(uintptr_t) 4095;
  for (unsigned i = 0; i < sz; i++) ((uint8_t *) a)[i] = 0;
  return (void *) a; }

// select queue `sel`, allocate + register its ring, fill the vq struct.
static bool vq_setup(struct vq *q, uint16_t sel) {
  outw(nic.io + V_QUEUE_SEL, sel);
  uint16_t num = inw(nic.io + V_QUEUE_SIZE);
  if (!num) return false;
  void *ring = dma_page(vring_bytes(num));
  if (!ring) return false;
  unsigned used_off = (16 * num + 6 + 2 * num + 4095) & ~4095u;
  q->num = num;
  q->desc = ring;
  q->avail = (struct vring_avail *) ((uint8_t *) ring + 16 * num);
  q->used = (struct vring_used *) ((uint8_t *) ring + used_off);
  q->last_used = 0;
  outl(nic.io + V_QUEUE_PFN, (uint32_t) (phys(ring) >> 12));
  return true; }

// --- RX/TX buffers + a polled UDP-echo server -------------------------------
// Stage 2b-2d. Static config: we are SLIRP's default guest 10.0.2.15. RX is a
// fixed pool of buffers re-posted after each frame; TX is one synchronous buffer
// (post, kick, spin on the used ring). The frame handler answers ARP (so SLIRP
// can address us) and echoes UDP datagrams back (the milestone-2 gate). All
// in-place: an echo reply is built over the received frame in its RX buffer, and
// tx_send copies it into the separate tx buffer before the RX buffer is re-posted.
#define RX_BUFS   16
#define BUF_SZ    2048
#define VNET_HDR  10            // legacy virtio_net_hdr, no MRG_RXBUF

static uint8_t *rx_buf;         // RX_BUFS * BUF_SZ, one descriptor each
static uint8_t *tx_buf;         // BUF_SZ, reused synchronously
static uint8_t const our_ip[4] = { 10, 0, 2, 15 };

static uint16_t be16(uint8_t const *p) { return (uint16_t) (p[0] << 8 | p[1]); }
static void     wr16(uint8_t *p, uint16_t v) { p[0] = (uint8_t) (v >> 8); p[1] = (uint8_t) v; }
static bool ip_is_ours(uint8_t const *p) {
  return p[0] == our_ip[0] && p[1] == our_ip[1] && p[2] == our_ip[2] && p[3] == our_ip[3]; }

// the standard one's-complement IP header checksum.
static uint16_t ip_csum(uint8_t const *p, int n) {
  uint32_t s = 0;
  for (int i = 0; i + 1 < n; i += 2) s += be16(p + i);
  if (n & 1) s += (uint32_t) p[n - 1] << 8;
  while (s >> 16) s = (s & 0xffff) + (s >> 16);
  return (uint16_t) ~s; }

// (re-)post RX descriptor/buffer i to the avail ring as device-writable.
static void rx_post(int i) {
  struct vring_desc *d = &nic.rx.desc[i];
  d->addr = phys(rx_buf + (unsigned) i * BUF_SZ);
  d->len = BUF_SZ;
  d->flags = VRING_DESC_F_WRITE;
  d->next = 0;
  nic.rx.avail->ring[nic.rx.avail->idx % nic.rx.num] = (uint16_t) i;
  __sync_synchronize();
  nic.rx.avail->idx++; }

static void rx_fill(void) {
  for (int i = 0; i < RX_BUFS; i++) rx_post(i);
  __sync_synchronize();
  outw(nic.io + V_QUEUE_NOTIFY, 0); }

// synchronous TX of one ethernet frame: prepend a zeroed virtio hdr, post on the
// transmitq, kick, and spin (bounded) on the used ring so tx_buf is free on return.
static void tx_send(uint8_t const *frame, unsigned len) {
  for (int i = 0; i < VNET_HDR; i++) tx_buf[i] = 0;
  for (unsigned i = 0; i < len && i < BUF_SZ - VNET_HDR; i++) tx_buf[VNET_HDR + i] = frame[i];
  struct vring_desc *d = &nic.tx.desc[0];
  d->addr = phys(tx_buf);
  d->len = VNET_HDR + len;
  d->flags = 0;
  d->next = 0;
  nic.tx.avail->ring[nic.tx.avail->idx % nic.tx.num] = 0;
  __sync_synchronize();
  nic.tx.avail->idx++;
  __sync_synchronize();
  outw(nic.io + V_QUEUE_NOTIFY, 1);
  for (int spin = 0; spin < 10000000 && nic.tx.used->idx == nic.tx.last_used; spin++)
    __sync_synchronize();
  nic.tx.last_used = nic.tx.used->idx; }

// --- the ai stream surface (stage 2e) ----------------------------------------
// A queue of received UDP datagrams (the k_sources[] NIC socket). RX enqueues
// each payload + its peer; nic_getc hands the bytes to ai (blocking, with a -1
// between datagrams so `slurp` reads exactly one); fputs+fflush build a reply
// datagram back to the peer of the datagram currently being read. So an ai agent
// does `(slurp nic)` to perceive and `(fputs nic r) (fflush nic)` to act.
#define DQ      8
#define DG_MAX  1472                   // max UDP payload over standard ethernet
struct dgram { uint16_t len, peer_port, our_port; uint8_t mac[6], ip[4], data[DG_MAX]; };
static struct dgram dgq[DQ];
static int dq_head, dq_tail;           // ring [head, tail) of pending datagrams
static int cur_pos;                    // read cursor within dgq[dq_head]
static bool cur_open;                  // a datagram is mid-read by nic_getc
static struct { uint16_t dport, sport; uint8_t mac[6], ip[4]; } reply;  // fflush target
static uint8_t txq[DG_MAX];            // ai's outgoing payload, filled by nic_putc
static unsigned txn;

// build + transmit one UDP datagram (dmac/dip/dport = peer, sport = our port).
static void nic_send_to(uint8_t const *dmac, uint8_t const *dip, uint16_t dport,
                        uint16_t sport, uint8_t const *p, unsigned n) {
  static uint8_t fr[14 + 20 + 8 + DG_MAX];
  if (n > DG_MAX) n = DG_MAX;
  for (int i = 0; i < 6; i++) { fr[i] = dmac[i]; fr[6 + i] = nic.mac[i]; }
  wr16(fr + 12, 0x0800);
  uint8_t *ip = fr + 14;
  ip[0] = 0x45; ip[1] = 0; wr16(ip + 2, (uint16_t) (20 + 8 + n));
  wr16(ip + 4, 0); wr16(ip + 6, 0); ip[8] = 64; ip[9] = 17; ip[10] = ip[11] = 0;
  for (int i = 0; i < 4; i++) { ip[12 + i] = our_ip[i]; ip[16 + i] = dip[i]; }
  wr16(ip + 10, ip_csum(ip, 20));
  uint8_t *udp = ip + 20;
  wr16(udp + 0, sport); wr16(udp + 2, dport);
  wr16(udp + 4, (uint16_t) (8 + n)); wr16(udp + 6, 0);   // UDP csum 0 = unused
  for (unsigned i = 0; i < n; i++) udp[8 + i] = p[i];
  tx_send(fr, 14 + 20 + 8 + n); }

// handle one received ethernet frame: answer ARP-for-us, enqueue UDP-to-us.
static void handle(uint8_t *f, unsigned len) {
  if (len < 14) return;
  uint16_t et = be16(f + 12);

  if (et == 0x0806 && len >= 42) {              // ARP request for us -> reply (in place)
    uint8_t *a = f + 14;
    if (be16(a + 6) != 1 || !ip_is_ours(a + 24)) return;
    uint8_t req_sha[6], req_spa[4];
    for (int i = 0; i < 6; i++) req_sha[i] = a[8 + i];
    for (int i = 0; i < 4; i++) req_spa[i] = a[14 + i];
    for (int i = 0; i < 6; i++) { f[i] = req_sha[i]; f[6 + i] = nic.mac[i]; }
    wr16(a + 6, 2);
    for (int i = 0; i < 6; i++) a[8 + i] = nic.mac[i];
    for (int i = 0; i < 4; i++) a[14 + i] = our_ip[i];
    for (int i = 0; i < 6; i++) a[18 + i] = req_sha[i];
    for (int i = 0; i < 4; i++) a[24 + i] = req_spa[i];
    tx_send(f, 42);
    return; }

  if (et == 0x0800 && len >= 14 + 20) {          // IPv4 / UDP to us -> enqueue
    uint8_t *ip = f + 14;
    int ihl = (ip[0] & 0xf) * 4;
    if (ip[9] != 17 || !ip_is_ours(ip + 16) || len < (unsigned) (14 + ihl + 8)) return;
    if ((dq_tail + 1) % DQ == dq_head) return;    // queue full: drop
    uint8_t *udp = ip + ihl;
    unsigned avail = len - (unsigned) (14 + ihl + 8);
    unsigned ulen = be16(udp + 4);                // UDP length field = 8 + payload
    unsigned plen = ulen >= 8 ? ulen - 8 : 0;     // authoritative: ignores eth padding
    if (plen > avail) plen = avail;               // but never over-read the frame
    if (plen > DG_MAX) plen = DG_MAX;
    struct dgram *d = &dgq[dq_tail];
    d->len = (uint16_t) plen;
    d->peer_port = be16(udp + 0);                 // sender's source port
    d->our_port = be16(udp + 2);                  // the port it was sent to (ours)
    for (int i = 0; i < 6; i++) d->mac[i] = f[6 + i];
    for (int i = 0; i < 4; i++) d->ip[i] = ip[12 + i];
    for (unsigned i = 0; i < plen; i++) d->data[i] = udp[8 + i];
    dq_tail = (dq_tail + 1) % DQ; } }

// drain the RX used ring, handling each frame, re-posting its buffer.
static void net_poll(void) {
  if (!nic.up) return;
  while (nic.rx.used->idx != nic.rx.last_used) {
    struct vring_used_elem *e = &nic.rx.used->ring[nic.rx.last_used % nic.rx.num];
    uint32_t id = e->id, l = e->len;
    if (l > VNET_HDR && id < RX_BUFS) handle(rx_buf + id * BUF_SZ + VNET_HDR, l - VNET_HDR);
    nic.rx.last_used++;
    rx_post((int) id); }
  __sync_synchronize();
  outw(nic.io + V_QUEUE_NOTIFY, 0); }

// --- the k_sources[] NIC socket methods (slot wired in kmain) ----------------
// ready: a datagram is buffered (feeds ai_ready / ai_wait_fds).
bool nic_ready(int fd) { (void) fd; net_poll(); return cur_open || dq_head != dq_tail; }

// getc: next byte of the head datagram; -1 once at its end (so slurp reads one),
// then BLOCK for the next datagram (the keyboard model -- never a terminal EOF).
int nic_getc(int fd) {
  (void) fd;
  if (!cur_open) {
    while (dq_head == dq_tail) { net_poll(); asm volatile ("hlt"); }
    cur_pos = 0; cur_open = true;
    struct dgram *d = &dgq[dq_head];
    reply.dport = d->peer_port; reply.sport = d->our_port;
    for (int i = 0; i < 6; i++) reply.mac[i] = d->mac[i];
    for (int i = 0; i < 4; i++) reply.ip[i] = d->ip[i]; }
  struct dgram *d = &dgq[dq_head];
  if (cur_pos < d->len) return d->data[cur_pos++];
  cur_open = false; dq_head = (dq_head + 1) % DQ;     // end of datagram
  return -1; }

// putc/flush: buffer reply bytes, then send them as one datagram to the peer of
// the datagram nic_getc is currently reading.
void nic_putc(int fd, int c) { (void) fd; if (txn < DG_MAX) txq[txn++] = (uint8_t) c; }
void nic_flush(int fd) {
  (void) fd;
  if (txn) nic_send_to(reply.mac, reply.ip, reply.dport, reply.sport, txq, txn);
  txn = 0; }

// the blocking C echo server (the `netserve` nif): drain the datagram queue,
// bouncing each payload back to its sender, then hlt until the next tick.
void net_serve(void) {
  np_s("net: echo server on 10.0.2.15 (polled)\r\n");
  for (;;) {
    net_poll();
    while (dq_head != dq_tail) {
      struct dgram *d = &dgq[dq_head];
      nic_send_to(d->mac, d->ip, d->peer_port, d->our_port, d->data, d->len);
      dq_head = (dq_head + 1) % DQ; }
    asm volatile ("hlt"); } }

// Bring the NIC up: PCI enum -> status/feature handshake -> RX+TX rings ->
// DRIVER_OK -> read MAC. A no-op (one log line) when no device is present.
void net_init(void) {
  uint8_t bus = 0, dev;                 // qemu puts virtio on bus 0
  for (dev = 0; dev < 32; dev++) {
    uint32_t id = pci_cfg(bus, dev, 0, 0x00);
    if ((id & 0xffff) != 0x1af4) continue;          // not virtio
    if ((id >> 16) != 0x1000) continue;             // not a transitional virtio-net
    uint32_t bar0 = pci_cfg(bus, dev, 0, 0x10);
    if (!(bar0 & 1)) continue;                       // need the I/O BAR
    nic.io = bar0 & ~0x3u;
    uint32_t cmd = pci_cfg(bus, dev, 0, 0x04) & 0xffff;
    pci_cfg_w(bus, dev, 0, 0x04, cmd | PCI_CMD_IO | PCI_CMD_BM | PCI_CMD_INTX);
    goto found; }
  np_s("net: no virtio-net device\r\n");
  return;

found:
  outb(nic.io + V_STATUS, 0);                        // reset
  outb(nic.io + V_STATUS, VS_ACK);
  outb(nic.io + V_STATUS, VS_ACK | VS_DRIVER);
  // accept only VIRTIO_NET_F_MAC: no MRG_RXBUF (keeps the net hdr 10 bytes), no
  // VERSION_1 (stay legacy).
  outl(nic.io + V_GUEST_FEAT, inl(nic.io + V_HOST_FEAT) & VNET_F_MAC);
  if (!vq_setup(&nic.rx, 0) || !vq_setup(&nic.tx, 1)) {
    outb(nic.io + V_STATUS, VS_FAILED);
    np_s("net: virtqueue setup failed\r\n");
    return; }
  for (int i = 0; i < 6; i++) nic.mac[i] = inb(nic.io + V_CONFIG + i);
  rx_buf = dma_page(RX_BUFS * BUF_SZ);
  tx_buf = dma_page(BUF_SZ);
  if (!rx_buf || !tx_buf) { outb(nic.io + V_STATUS, VS_FAILED); np_s("net: buffer alloc failed\r\n"); return; }
  outb(nic.io + V_STATUS, VS_ACK | VS_DRIVER | VS_DRIVER_OK);
  nic.up = true;
  rx_fill();                             // post receive buffers now that we're live
  np_s("net: virtio-net up io=0x"); np_x(nic.io, 4);
  np_s(" mac="); np_mac(nic.mac);
  np_s(" rxq="); np_x(nic.rx.num, 4);
  np_s(" txq="); np_x(nic.tx.num, 4);
  np_s("\r\n"); }
