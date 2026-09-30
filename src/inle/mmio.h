// mmio.h -- device memory, one copy for the drivers and the arch seats. every access is
// volatile so the compiler keeps program order; every target is little-endian, so a
// typed load is the LE read. the pci doors want asmops.h's k_outl/k_inl, and asmops.h
// has no guard, so the includer brings it in first.
#pragma once
#include "k.h"
#include <stdint.h>

static inline uint8_t  r8 (volatile uint8_t *p) { return *p; }
static inline uint16_t r16(volatile uint8_t *p) { return *(volatile uint16_t*) p; }
static inline uint32_t r32(volatile uint8_t *p) { return *(volatile uint32_t*) p; }
static inline void w8 (volatile uint8_t *p, uint8_t v)  { *p = v; }
static inline void w16(volatile uint8_t *p, uint16_t v) { *(volatile uint16_t*) p = v; }
static inline void w32(volatile uint8_t *p, uint32_t v) { *(volatile uint32_t*) p = v; }
static inline void w64(volatile uint8_t *p, uint64_t v) {   // two 32-bit halves: the
  w32(p, (uint32_t) v); w32(p + 4, (uint32_t) (v >> 32)); } // width every transport takes

// the address a device sees: exact for kmallocw memory, never for an image static
static inline uintptr_t vtop(volatile void *p) { return (uintptr_t) p - khhdm; }

// a register at a device's physical base, through the direct map
static inline uint8_t mmio_rd8(uintptr_t phys, uintptr_t off) {
  return *(volatile uint8_t*) (khhdm + phys + off); }
static inline void mmio_wr8(uintptr_t phys, uintptr_t off, uint8_t v) {
  *(volatile uint8_t*) (khhdm + phys + off) = v; }
static inline uint32_t mmio_rd(uintptr_t phys, uintptr_t off) {
  return *(volatile uint32_t*) (khhdm + phys + off); }
static inline void mmio_wr(uintptr_t phys, uintptr_t off, uint32_t v) {
  *(volatile uint32_t*) (khhdm + phys + off) = v; }

#if defined(__x86_64__)
// PCI config space through CF8/CFC
static inline uint32_t pci_r32(uint32_t bdf, uint32_t off) {
  k_outl(0xcf8, 0x80000000u | bdf << 8 | (off & 0xfc));
  return k_inl(0xcfc); }
static inline void pci_w32(uint32_t bdf, uint32_t off, uint32_t v) {
  k_outl(0xcf8, 0x80000000u | bdf << 8 | (off & 0xfc));
  k_outl(0xcfc, v); }
static inline uint32_t pci_r8(uint32_t bdf, uint32_t off) {
  return pci_r32(bdf, off) >> 8 * (off & 3) & 0xff; }
#endif
