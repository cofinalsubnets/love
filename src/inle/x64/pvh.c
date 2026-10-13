// PVH -> kboot: the C half of mkboot.l's hand-off. Runs high, paging on, with
// the stub's hhdm window (0xffff8000_00000000 over physical 0..4G) already
// mapped; reads qemu's hvm_start_info (the e820 map) and fills kboot, the way
// every door fills it before kmain reads it. Headless by construction -- PVH
// hands over no framebuffer, so has_fb stays false and kmain runs on serial.
#include "k.h"

#define pvh_hhdm 0xffff800000000000ull

struct hvm_start_info {
  uint32_t magic;                     // 0x336ec578 ("xEn3")
  uint32_t version, flags, nr_modules;
  uint64_t modlist_paddr, cmdline_paddr, rsdp_paddr, memmap_paddr;
  uint32_t memmap_entries, reserved; };

struct hvm_memmap_entry { uint64_t addr, size; uint32_t type, reserved; };
struct hvm_modlist_entry { uint64_t paddr, size, cmdline_paddr, reserved; };

// the physical footprint qemu loaded us into -- which e820 still calls usable
// RAM (the PVH loader reserves nothing). hand it to the heap and the kernel
// eats itself. a VALUE the projection patches into the file (src/tools/kproject.l),
// where the flat link's kimage_end symbol used to stand.
extern uintptr_t const k_image_top;


// a..b to the heap, less the spans x0..x1 and y0..y1 (the image, the module)
static void pvh_give(uint64_t a, uint64_t b, uint64_t x0, uint64_t x1, uint64_t y0, uint64_t y1) {
  if (b <= a) return;
  if (b <= x0 || a >= x1) {
    if (y0 < y1) pvh_give(a, b, y0, y1, 0, 0);
    else k_ram_give(a, b - a);
    return; }
  pvh_give(a, x0, y0, y1, 0, 0);                     // the piece under the span
  pvh_give(x1, b, y0, y1, 0, 0); }                   // and the piece past it

void pvh_to_kboot(uint32_t si_paddr) {
  struct hvm_start_info *si = (void *) (pvh_hhdm + si_paddr);
  if (si->magic != 0x336ec578 || si->version < 1 || !si->memmap_paddr) return;
  struct hvm_memmap_entry *mm = (void *) (pvh_hhdm + si->memmap_paddr);
  uint64_t k0 = 0x200000,             // k1 page-rounded: meminit lays a struct
           k1 = (k_image_top + 0xfff) & ~0xfffull;
  kboot.hhdm = pvh_hhdm;
  if (si->cmdline_paddr) k_cmdline((char const *) (pvh_hhdm + si->cmdline_paddr), (uintptr_t) ~0);
  // the first module is /proc/initrd, and its pages are kept from the heap as the image's are
  uint64_t m0 = 0, m1 = 0;
  if (si->nr_modules && si->modlist_paddr) {
    struct hvm_modlist_entry *ml = (void *) (pvh_hhdm + si->modlist_paddr);
    if (ml->size && ml->paddr + ml->size <= 0x100000000ull) {
      m0 = ml->paddr & ~0xfffull, m1 = (ml->paddr + ml->size + 0xfff) & ~0xfffull;
      kboot.initrd = (void const *) (pvh_hhdm + ml->paddr), kboot.initrd_len = ml->size; } }
  for (uint32_t i = 0; i < si->memmap_entries; i++) {
    if (mm[i].type != 1) continue;                   // 1 = usable RAM
    uint64_t a = mm[i].addr, b = a + mm[i].size;
    if (a < 0x100000) a = 0x100000;                  // low memory: the IVT, the
    if (b > 0x100000000ull) b = 0x100000000ull;      // start_info itself; >4G: unmapped
    pvh_give(a, b, k0, k1, m0, m1); } }
