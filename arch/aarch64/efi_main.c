// UEFI entry point for aarch64. Replaces the Limine boot path when built
// with EFI=1. Mirrors the x86_64 efi_main:
//
//   * grab a framebuffer via the Graphics Output Protocol (if any)
//   * grab the memory map via GetMemoryMap
//   * ExitBootServices
//   * mask all DAIF interrupt sources until archinit installs our own
//     vector table -- the firmware leaves the timer + UART configured
//     to raise IRQs and any in-flight one would have no handler
//   * hand off to kmain() with kboot[] populated; firmware leaves an
//     identity map covering RAM + device MMIO in place, so khhdm = 0
//     and arch.c's MMIO accesses go straight to physical addresses
//
// EFIAPI is empty on aarch64 -- UEFI uses AAPCS64, which is also what
// clang's aarch64-unknown-windows target uses for scalar args. The
// asm-to-C boundary callees (k_irq, k_fault) take only scalar args,
// so no sysv_abi shim is needed on this arch.
//
// We only feed EfiConventionalMemory ranges into kboot.ram. Reclaiming
// EfiBootServicesCode/Data would be tempting (~30 MB on QEMU/virt),
// but the firmware's stack lives in BootServicesData on EDK2 aarch64
// and meminit's kmallocw carves from the tail of each free region --
// which would overwrite the live stack we're using to call kmain.
#include "uefi/efi.h"
#include "k.h"

static EFI_GUID gop_guid = EFI_GRAPHICS_OUTPUT_PROTOCOL_GUID;

// Captures + flag consumed by k/main.c. Zero-initialized in .bss.
struct k_boot kboot;

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

// Static scratch sized for QEMU's OVMF (typically <2 KiB of map).
// Same caveat as x86_64: a future pass should AllocatePool for the
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
    // QEMU's virt machine puts RAM at 0x40000000; the 0x100000 cutoff
    // we use on x86_64 (BIOS data area below 1 MiB) is moot here, but
    // dropping the lowest page is still cheap insurance against any
    // descriptor that names a single boot-time stub page.
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
  // We own the machine. Mask every DAIF interrupt source (Debug, SError,
  // IRQ, FIQ) until archinit installs our own vector table -- the
  // firmware leaves the architected timer and GIC configured, so a stale
  // IRQ would otherwise dispatch through whatever VBAR_EL1 happens to
  // hold. archinit selects EL1h and clears DAIF.I once it is ready.
  asm volatile ("msr daifset, #0xf");
  kboot.hhdm = 0;
  kmain();
  for (;;) asm volatile ("wfi");
}
