// UEFI entry point for riscv64. Replaces the Limine boot path when built
// with EFI=1. Mirrors the x86_64 and aarch64 efi_main:
//
//   * grab a framebuffer via the Graphics Output Protocol (typically
//     absent on QEMU virt-riscv64; serial-only boot)
//   * grab the memory map via GetMemoryMap
//   * ExitBootServices
//   * mask sstatus.SIE so a stale firmware timer interrupt cannot dispatch
//     through the firmware's stvec before archinit installs ours
//   * hand off to kmain() with kboot[] populated; firmware leaves an
//     identity map covering RAM + device MMIO in place, so khhdm = 0
//     and arch.c's SBI calls work unchanged
//
// Calling convention: UEFI on RISC-V uses the standard psABI lp64, which
// is what our ELF target already emits -- so EFIAPI is empty and no shim
// is needed on the asm-to-C boundary. The trap path (riscv64.S) likewise
// uses ABI-compliant register saves, so it ports across with no change.
//
// We only feed EfiConventionalMemory ranges into kboot.ram. Reclaiming
// EfiBootServicesCode/Data would be tempting, but EDK2's firmware stack
// can live in BootServicesData and meminit's kmallocw carves from the
// tail of each free region -- the same caveat documented in aarch64's
// efi_main.c. SBI (OpenSBI underneath EDK2 in the M-mode payload slot)
// stays available after ExitBootServices, so the SBI console + timer
// in arch.c keep working unchanged.
#include "uefi/efi.h"
#include "k_boot.h"

static EFI_GUID gop_guid = EFI_GRAPHICS_OUTPUT_PROTOCOL_GUID;

// Captures + flag consumed by k/main.c. Zero-initialized in .bss.
struct k_boot kboot;

// Our own stack. EDK2 on QEMU virt-riscv64 places the firmware stack in
// EfiConventionalMemory rather than the BootServicesData region the
// x86_64 and aarch64 OVMF builds use, so grab_memmap below hands that
// range straight into kboot.ram and meminit links it into the kernel
// free list. Once kmallocw carves something from that chunk, every C
// call we make pushes a frame on top of memory we have already given
// away -- which is benign while the call depth stays shallow but
// silently corrupts the heap once gwen's evaluator recurses. The fix is
// to stop using the firmware stack at all: efi_main does the last
// firmware-state operations (GOP, GetMemoryMap, ExitBootServices) on
// the inherited stack, then switches sp to the top of k_stack[] -- a
// .bss buffer that lives inside the kernel image and is never part of
// the free list -- before tail-calling kmain. 64 KiB matches what the
// other ports inherit from their bootloader; deep enough for gwen's
// recursive descent + the worst-case GC walk.
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
    // QEMU's virt-riscv64 puts RAM at 0x80000000. The lowest-page guard
    // is cheap insurance against a single boot-time stub page sneaking
    // through under either type label.
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
  // We own the machine. Mask sstatus.SIE until archinit installs our own
  // trap vector -- the firmware leaves stvec pointing at its handler, and
  // any pending supervisor interrupt (timer, software) would otherwise
  // dispatch through that stale entry point.
  asm volatile ("csrci sstatus, 2");                  // SSTATUS_SIE bit 1
  kboot.hhdm = 0;
  // Switch off the firmware stack onto k_stack[] (see top-of-file note),
  // then tail-call kmain. We never return from this point -- kmain ends
  // in k_reset, which uses SBI SYSTEM_RESET to power the machine off.
  asm volatile ("mv sp, %0\n\t"
                "tail kmain"
                :: "r" (&k_stack[sizeof k_stack])
                : "memory");
  __builtin_unreachable();
}
