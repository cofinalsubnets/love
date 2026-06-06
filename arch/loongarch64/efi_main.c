// UEFI entry point for loongarch64. Replaces the Limine boot path when
// built with EFI=1. Mirrors the riscv64 efi_main:
//
//   * grab a framebuffer via the Graphics Output Protocol (typically
//     absent on QEMU virt-loongarch64; serial-only boot)
//   * grab the memory map via GetMemoryMap
//   * ExitBootServices
//   * mask CRMD.IE so a stale firmware timer interrupt cannot dispatch
//     through the firmware's EENTRY before archinit installs ours
//   * install DMW0 (uncached, VSEG=8) for MMIO and DMW1 (cached, VSEG=9)
//     for RAM, then point khhdm at the DMW1 base
//   * switch onto a kernel-owned stack and tail-call kmain
//
// Calling convention: UEFI on LoongArch64 uses the standard LP64 psABI,
// which is what our ELF target already emits -- so EFIAPI is empty and
// no shim is needed on the asm-to-C boundary. The trap path
// (loongarch64.S) likewise uses ABI-compliant register saves, so it
// ports across with no change.
//
// DMW state. EDK2 LoongArch64 (at least the osdev0/edk2-ovmf-nightly
// build) runs in CRMD.PG mode with the firmware identity-mapping low
// VAs through its own TLB refill handler -- VSEG=8/9 are NOT exposed
// through DMW windows by default, so any MMIO access through the
// 0x8...... uncached prefix faults with #ADE before we get anywhere.
// We install both windows ourselves the moment we're allowed to (after
// ExitBootServices): DMW0 as the SUC window arch.c expects for MMIO
// (VSEG=8, MAT=0, PLV0) and DMW1 as a CC window for RAM (VSEG=9,
// MAT=1, PLV0), then point khhdm at the DMW1 base so meminit walks
// physical RAM through that window rather than the firmware's TLB.
// Our own code keeps running at the low VAs the firmware loaded us at;
// those resolve through TLB refills against the firmware's still-live
// page tables, and the only firmware memory we leave alone -- because
// we don't reclaim BootServicesCode/Data -- includes the refill handler
// itself, so the mapping stays valid for the lifetime of the kernel.
// archinit later rewrites DMW0 with the same value, which is redundant
// but harmless.
//
// We only feed EfiConventionalMemory ranges into kboot.ram. Reclaiming
// EfiBootServicesCode/Data would be tempting, but EDK2's firmware stack
// can live in BootServicesData and meminit's kmallocw carves from the
// tail of each free region -- the same caveat documented in aarch64's
// and riscv64's efi_main.c.
#include "uefi/efi.h"
#include "k.h"

static EFI_GUID gop_guid = EFI_GRAPHICS_OUTPUT_PROTOCOL_GUID;

// Captures + flag consumed by k/main.c. Zero-initialized in .bss.
struct k_boot kboot;

// Our own stack. Same reasoning as the riscv64 port: EDK2 places the
// firmware stack inside EfiConventionalMemory rather than the
// BootServicesData region the x86_64/aarch64 builds use, so grab_memmap
// below hands that range straight into kboot.ram and meminit links it
// into the kernel free list. Once kmallocw carves something from that
// chunk, every C call we make pushes a frame on top of memory we have
// already given away -- benign while the call depth stays shallow,
// silently corrupting the heap once gwen's evaluator recurses. The fix
// is to stop using the firmware stack at all: efi_main does the last
// firmware-state operations (GOP, GetMemoryMap, ExitBootServices) on
// the inherited stack, then switches sp to the top of k_stack[] -- a
// .bss buffer that lives inside the kernel image and is never part of
// the free list -- before tail-calling kmain.
static char k_stack[64 * 1024] __attribute__((aligned(16)));

static void grab_fb(EFI_SYSTEM_TABLE *st) {
  EFI_GRAPHICS_OUTPUT_PROTOCOL *gop;
  if (EFI_ERROR(st->BootServices->LocateProtocol(&gop_guid, NULL, (void**)&gop)))
    return;                                           // headless: serial-only
  EFI_GRAPHICS_OUTPUT_PROTOCOL_MODE *m = gop->Mode;
  kboot.fb.base     = (void*)(uintptr_t) m->FrameBufferBase;
  kboot.fb.w        = m->Info->HorizontalResolution;
  kboot.fb.h        = m->Info->VerticalResolution;
  kboot.fb.pitch_px = m->Info->PixelsPerScanLine;
  kboot.has_fb      = true;
}

// Static scratch sized for QEMU's OVMF (typically <2 KiB of map). Same
// caveat as the other arches: a future pass should AllocatePool for the
// firmware-reported size on real hardware.
static char mmap_buf[16 * 1024] __attribute__((aligned(8)));

static UINTN grab_memmap(EFI_SYSTEM_TABLE *st) {
  UINTN size = sizeof mmap_buf, key = 0, dsize = 0;
  uint32_t dver = 0;
  EFI_STATUS s = st->BootServices->GetMemoryMap(
    &size, (EFI_MEMORY_DESCRIPTOR*) mmap_buf, &key, &dsize, &dver);
  if (EFI_ERROR(s) || !dsize) return 0;
  for (UINTN off = 0; off < size && kboot.ram_n < K_BOOT_RAM_MAX; off += dsize) {
    EFI_MEMORY_DESCRIPTOR *d = (EFI_MEMORY_DESCRIPTOR*) (mmap_buf + off);
    // Reclaiming BootServicesCode/Data here would overwrite the stack
    // we're standing on -- see the file-header comment.
    if (d->Type != EfiConventionalMemory) continue;
    // QEMU's virt-loongarch64 puts RAM at 0x00000000. The lowest-page
    // guard is cheap insurance against a single boot-time stub page
    // sneaking through.
    if (d->PhysicalStart < 0x1000) continue;
    kboot.ram[kboot.ram_n].base = d->PhysicalStart;
    kboot.ram[kboot.ram_n].len  = d->NumberOfPages * 4096ULL;
    kboot.ram_n++;
  }
  return key;
}

void kmain(void);

EFI_STATUS efi_main(EFI_HANDLE image_handle, EFI_SYSTEM_TABLE *st) {
  grab_fb(st);
  UINTN key = grab_memmap(st);
  // ExitBootServices requires the most recent map key; one retry covers
  // the case where firmware events have advanced the map underneath us.
  EFI_STATUS s = st->BootServices->ExitBootServices(image_handle, key);
  if (EFI_ERROR(s)) {
    kboot.ram_n = 0;
    key = grab_memmap(st);
    s = st->BootServices->ExitBootServices(image_handle, key);
    if (EFI_ERROR(s)) return s;                       // give up; firmware reports
  }
  // We own the machine. Clear CRMD.IE (bit 2) until archinit installs
  // our own EENTRY -- the firmware leaves its handler in place and any
  // pending interrupt (timer especially) would dispatch through that
  // stale entry point. csrxchg lets us touch only bit 2 without
  // clobbering PLV / DA / PG.
  {
    uint64_t v = 0, m = 1ULL << 2;
    asm volatile ("csrxchg %0, %1, %2"
                  : "+r"(v) : "r"(m), "i"(0x0) : "memory");
  }
  // Install our direct-map windows. EDK2 leaves the VSEG=8/9 prefixes
  // unmapped (see the top-of-file note), so the very first MMIO access
  // through 0x8...|UART_PHYS would fault if we deferred this to
  // archinit. DMW0 = SUC@VSEG=8 (PLV0) for MMIO; DMW1 = CC@VSEG=9
  // (PLV0) for RAM. CSR_DMW0 = 0x180, CSR_DMW1 = 0x181.
  {
    uint64_t dmw0 = 0x8000000000000001ULL;            // valid | MAT=SUC | VSEG=8
    uint64_t dmw1 = 0x9000000000000011ULL;            // valid | MAT=CC  | VSEG=9
    asm volatile ("csrwr %0, %1" : "+r"(dmw0) : "i"(0x180) : "memory");
    asm volatile ("csrwr %0, %1" : "+r"(dmw1) : "i"(0x181) : "memory");
  }
  // RAM physical P now lives at khhdm + P via DMW1 -- the same contract
  // the Limine path establishes through TLB-mapped page tables.
  kboot.hhdm = 0x9000000000000000ULL;
  // Switch off the firmware stack onto k_stack[] (see top-of-file note),
  // then tail-call kmain. We never return -- kmain ends in k_reset,
  // which on loongarch64 spins on `idle 0` (no PSCI/SBI equivalent).
  asm volatile ("move $sp, %0\n\t"
                "b kmain"
                :: "r" (&k_stack[sizeof k_stack])
                : "memory");
  __builtin_unreachable();
}
