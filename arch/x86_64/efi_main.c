// UEFI entry point for x86_64. Replaces the Limine boot path when built
// with EFI=1. Mirrors what Limine used to do for us, but directly against
// UEFI Boot Services:
//
//   * grab a framebuffer via the Graphics Output Protocol
//   * grab the memory map via GetMemoryMap
//   * ExitBootServices
//   * hand off to kmain() with kboot[] populated; identity-mapped, so
//     khhdm = 0
//
// What we deliberately DO NOT do here yet (deferred for the next pass):
//   * install an IDT, PIC, or PIT  -- no interrupts in the prototype
//   * any virtual remap           -- we stay on UEFI's identity map
//   * the asm exception stubs     -- triple-fault on (fault N) is fine
//
// Without IRQs, input has to come from polling the UART; see efi_arch.c
// for the polled k_idle/k_uart pair that drives the editor's read loop.
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

// Static scratch: a 16 KiB memory map covers anything QEMU's OVMF hands
// us (typically <2 KiB). Real hardware can be larger; if GetMemoryMap
// returns EFI_BUFFER_TOO_SMALL we just give up and boot headless on the
// stub heap below. A future pass should AllocatePool for the real size.
static char mmap_buf[16 * 1024] __attribute__((aligned(8)));

static UINTN grab_memmap(EFI_SYSTEM_TABLE *st) {
  UINTN size = sizeof mmap_buf, key = 0, dsize = 0;
  uint32_t dver = 0;
  EFI_STATUS s = st->BootServices->GetMemoryMap(
    &size, (EFI_MEMORY_DESCRIPTOR*) mmap_buf, &key, &dsize, &dver);
  if (EFI_ERROR(s) || !dsize) return 0;
  for (UINTN off = 0; off < size && kboot.ram_n < K_BOOT_RAM_MAX; off += dsize) {
    EFI_MEMORY_DESCRIPTOR *d = (EFI_MEMORY_DESCRIPTOR*) (mmap_buf + off);
    // After ExitBootServices we may reclaim BootServicesCode/Data too;
    // ConventionalMemory is already free. Skip RuntimeServices, ACPI,
    // MMIO, and anything below 1 MiB (BIOS data area, IVT, etc.).
    if (d->Type != EfiConventionalMemory
     && d->Type != EfiBootServicesCode
     && d->Type != EfiBootServicesData) continue;
    if (d->PhysicalStart < 0x100000) continue;
    kboot.ram[kboot.ram_n].base = d->PhysicalStart;
    kboot.ram[kboot.ram_n].len  = d->NumberOfPages * 4096ULL;
    kboot.ram_n++;
  }
  return key;
}

void kmain(void);

EFIAPI EFI_STATUS efi_main(EFI_HANDLE image_handle, EFI_SYSTEM_TABLE *st) {
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
  // We own the machine. UEFI left identity-mapped paging on, so VA == PA
  // for everything in the memory map and the framebuffer. Mask any
  // pending IRQs until archinit installs our own IDT -- otherwise a
  // stale UEFI handler entry might run with our context.
  asm volatile ("cli");
  kboot.hhdm = 0;
  kmain();
  for (;;) asm volatile ("cli; hlt");
}
