// Freestanding-kernel glue shared by kmain.c and the per-arch backends.
// Combines the former free/k.h (kernel logging) and free/k_boot.h (the boot
// hand-off struct).
#pragma once
#include "love.h"

void
 k_logf(char const*, ...),
 k_vlogf(char const*, va_list),
 k_log_clear(void),
 k_log_char(char);

// k_boot -- the small struct the bootloader hand-off populates before
// kmain() runs. kmain.c reads this in meminit/fbinit; the Limine path
// fills it in limine_to_kboot(). Adding a new backend is just "write
// something that fills kboot, then jump to kmain."
#include <stdint.h>
#include <stdbool.h>

// khhdm -- the higher-half direct-map offset (physical P is reachable at
// khhdm + P). Defined in kmain.c; the virtio-net driver reads it to turn heap
// pointers into the guest-physical DMA addresses the device's rings need
// (phys = virt - khhdm). 0 means identity-mapped.
extern uintptr_t khhdm;

// net.c (port/inle/<a>/): the virtio-net driver. net_init brings the NIC up
// (PCI enum -> virtqueues -> DRIVER_OK); a no-op when no device is present.
void net_init(void);

// net_serve -- the polled UDP echo server (the `netserve` nif body; `net` is the
// prel content measure): answer ARP for 10.0.2.15 and echo UDP datagrams back.
// Blocks (hlt between polls).
void net_serve(void);

// The k_sources[] NIC-socket methods (stage 2e): a UDP datagram queue exposed as
// a byte stream so love `(slurp nic)` perceives one datagram and `(fputs nic r)
// (fflush nic)` replies to its sender. kmain wires these into a k_sources slot +
// a port bound to the `nic` global.
int  nic_getc(int fd);
void nic_putc(int fd, int c);
void nic_flush(int fd);
bool nic_ready(int fd);

// nic_aim -- point the nic at an arbitrary destination (ipword = a.b.c.d packed,
// oport its UDP port) for the next say/flush, resolving the route by ARP. lets the
// love brain INITIATE an outbound datagram (the `aim` nif, milestone 5). 1 = routed.
int  nic_aim(uint32_t ipword, uint16_t oport);

#define k_boot_ram_max 64

struct k_boot {
  uint32_t ram_n;
  struct { uintptr_t base, len; } ram[k_boot_ram_max];
  uintptr_t hhdm;                     // 0 means identity-mapped (UEFI path)
  struct {
    void    *base;                    // framebuffer linear address
    uint16_t w, h;                    // pixels
    uint32_t pitch_px;                // pixels per scanline (not bytes)
  } fb;
  bool has_fb;
};

extern struct k_boot kboot;
