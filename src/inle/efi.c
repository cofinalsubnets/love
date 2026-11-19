// efi.c -- the kernel as the firmware's guest (love.stay), on x64 and a64: its keys are ConIn's,
// its files the volume's, and kexec is LoadImage. kboot.efi_call is the loader's efi_call6
#if defined(__x86_64__) || defined(__aarch64__)
#include <errno.h>
#include <stdint.h>
#include <string.h>
#include "k.h"
void kq(uint8_t);

// a board's own polled keys, where no firmware holds the console
__attribute__((weak)) void k_kb_board(int room) { (void) room; }

// a guest's keys are ConIn's, the firmware's serial terminal and keyboards alike: a key's
// unicode as utf-8, an arrow or edit key as the vt sequence the console reads
void k_kb_sync(int room) {
  if (!kboot.efi_st) { k_kb_board(room); return; }
  void **st = kboot.efi_st, **in = st[6];
  static char const *const scan[24] = {
    [1] = "\033[A", [2] = "\033[B", [3] = "\033[C", [4] = "\033[D", [5] = "\033[H", [6] = "\033[F",
    [7] = "\033[2~", [8] = "\033[3~", [9] = "\033[5~", [10] = "\033[6~", [23] = "\033" };
  for (struct { uint16_t sc, ch; } key; room >= 4
       && !kboot.efi_call(in[1], (uintptr_t) in, (uintptr_t) &key, 0, 0, 0, 0); ) {
    uint32_t c = key.ch;
    if (c) {
      if (c < 0x80) kq((uint8_t) c), room--;
      else if (c < 0x800) kq((uint8_t) (0xc0 | c >> 6)), kq((uint8_t) (0x80 | (c & 63))), room -= 2;
      else kq((uint8_t) (0xe0 | c >> 12)), kq((uint8_t) (0x80 | (c >> 6 & 63))),
           kq((uint8_t) (0x80 | (c & 63))), room -= 3; }
    else if (key.sc < 24 && scan[key.sc])
      for (char const *s = scan[key.sc]; *s; s++) kq((uint8_t) *s), room--; } }

// a guest's files are the firmware's: the volume it booted us from, '/' its '\\'
typedef uintptr_t (*k_efi_fn)(void *, uintptr_t, uintptr_t, uintptr_t, uintptr_t, uintptr_t, uintptr_t);
static uint8_t const
  lip_g[16] = {0xa1,0x31,0x1b,0x5b,0x62,0x95,0xd2,0x11,0x8e,0x3f,0x00,0xa0,0xc9,0x69,0x72,0x3b},
  dp_g[16]  = {0x91,0x6e,0x57,0x09,0x3f,0x6d,0xd2,0x11,0x8e,0x39,0x00,0xa0,0xc9,0x69,0x72,0x3b},
  sfs_g[16] = {0x22,0x5b,0x4e,0x96,0x59,0x64,0xd2,0x11,0x8e,0x39,0x00,0xa0,0xc9,0x69,0x72,0x3b},
  lf2_g[16] = {0xc1,0xc0,0x06,0x40,0xb3,0xfc,0x3e,0x40,0x99,0x6d,0x4a,0x6c,0x87,0x24,0xe0,0x6d},
  // LINUX_EFI_INITRD_MEDIA_GUID as a vendor media node, and the end: where linux's stub asks
  rd_dp[24] = {4, 3, 20, 0, 0x27,0xe4,0x68,0x55,0xfc,0x68,0x3d,0x4f,0xac,0x74,0xca,0x55,0x52,0x31,0xcc,0x68,
               0x7f, 0xff, 4, 0};

// UCS-2 into w (n + 1 units), nul-terminated
static void k_ucs2(uint8_t *w, char const *p, uintptr_t n) {
  for (uintptr_t i = 0; i <= n; i++) {
    uint16_t c = i < n ? (uint8_t) p[i] : 0;
    if (c == '/') c = '\\';
    w[2 * i] = (uint8_t) c, w[2 * i + 1] = (uint8_t) (c >> 8); } }

// our volume's device handle, or 0
static void *k_efi_vol(void) {
  void **bs = ((void ***) kboot.efi_st)[12], **lip = 0;
  return ((k_efi_fn) kboot.efi_call)(bs[19], (uintptr_t) kboot.efi_image, (uintptr_t) lip_g,
                                     (uintptr_t) &lip, 0, 0, 0) ? 0 : lip[3]; }

// (efi-read path), kmain's two halves: the file opened and sized, then read and closed
// (a null buf only closes) -> the size | -errno
long k_efi_open(char const *p, uintptr_t pn, void **fh) {
  if (!kboot.efi_st) return -ENOSYS;
  if (pn > 255) return -ENAMETOOLONG;
  void **bs = ((void ***) kboot.efi_st)[12], *vol = k_efi_vol(), **sfs = 0, **root = 0, **f = 0;
  k_efi_fn ec = kboot.efi_call;
  uint8_t name[512];
  k_ucs2(name, p, pn);
  uint64_t n = 0;
  if (!vol || ec(bs[19], (uintptr_t) vol, (uintptr_t) sfs_g, (uintptr_t) &sfs, 0, 0, 0)
      || ec(sfs[1], (uintptr_t) sfs, (uintptr_t) &root, 0, 0, 0, 0)) return -ENODEV;
  uintptr_t r = ec(root[1], (uintptr_t) root, (uintptr_t) &f, (uintptr_t) name, 1, 0, 0);   // read
  ec(root[2], (uintptr_t) root, 0, 0, 0, 0, 0);
  if (r) return -ENOENT;
  // the end's position is the size: SetPosition(~0) goes there
  if (ec(f[7], (uintptr_t) f, ~(uintptr_t) 0, 0, 0, 0, 0) || ec(f[6], (uintptr_t) f, (uintptr_t) &n, 0, 0, 0, 0)
      || ec(f[7], (uintptr_t) f, 0, 0, 0, 0, 0) || n > (uint64_t) INTPTR_MAX)
    return ec(f[2], (uintptr_t) f, 0, 0, 0, 0, 0), -EIO;
  return *fh = f, (long) n; }

long k_efi_read(void *fh, void *buf, uintptr_t n) {
  void **f = fh;
  k_efi_fn ec = kboot.efi_call;
  uintptr_t got = n, r = buf ? ec(f[4], (uintptr_t) f, (uintptr_t) &got, (uintptr_t) buf, 0, 0, 0) : 0;
  ec(f[2], (uintptr_t) f, 0, 0, 0, 0, 0);
  return r || got != n ? -EIO : (long) n; }

// the initrd's LoadFile2, as linux's stub calls it: a size asked with no room, then the bytes
struct k_lf2 { void *entry; uintptr_t (*fn)(struct k_lf2 *, void *, uintptr_t, uintptr_t *, void *);
               uint8_t const *b; uintptr_t n; };
static uintptr_t k_lf2_load(struct k_lf2 *l, void *path, uintptr_t boot, uintptr_t *size, void *buf) {
  (void) path, (void) boot;
  if (!size) return 0x8000000000000002ull;                    // EFI_INVALID_PARAMETER
  if (!buf || *size < l->n) return *size = l->n, 0x8000000000000005ull;   // EFI_BUFFER_TOO_SMALL
  memcpy(buf, l->b, l->n);
  return *size = l->n, 0; }

// (kexec path cmd) for a guest, and (kexec-initrd path cmd rd): the firmware loads path off our
// own volume and starts it with cmd as its LoadOptions, rd (when given) on linux's initrd device
// path the while. it answers the status should the image return, a refused load -1000 less its
// EFI status. rd's bytes are a love string's: nothing collects until StartImage is back
long k_kexec_initrd(char const *p, uintptr_t pn, char const *cmd, uintptr_t cn, void const *rd, uintptr_t rn) {
  if (!kboot.efi_st) return -ENOSYS;
  void **bs = ((void ***) kboot.efi_st)[12], *vol = k_efi_vol();
  k_efi_fn ec = kboot.efi_call;
  uint8_t *dp = 0;
  if (!vol || ec(bs[19], (uintptr_t) vol, (uintptr_t) dp_g, (uintptr_t) &dp, 0, 0, 0)) return -ENODEV;
  // the volume's path, then a file node and the end
  uintptr_t vn = 0;
  while (dp[vn] != 0x7f) vn += (uintptr_t) (dp[vn + 2] | dp[vn + 3] << 8);
  uintptr_t fn = 4 + 2 * (pn + 1), n = vn + fn + 4;
  uint8_t *path = 0;
  if (ec(bs[8], 2, n, (uintptr_t) &path, 0, 0, 0)) return -ENOMEM;   // AllocatePool, LoaderData
  memcpy(path, dp, vn);
  uint8_t *f = path + vn;
  f[0] = 4, f[1] = 4, f[2] = (uint8_t) fn, f[3] = (uint8_t) (fn >> 8);
  k_ucs2(f + 4, p, pn);
  f[fn] = 0x7f, f[fn + 1] = 0xff, f[fn + 2] = 4, f[fn + 3] = 0;
  void *h = 0;
  uintptr_t r = ec(bs[25], 0, (uintptr_t) kboot.efi_image, (uintptr_t) path, 0, 0, (uintptr_t) &h);
  ec(bs[9], (uintptr_t) path, 0, 0, 0, 0, 0);
  if (r) return -1000 - (long) (r & 0xffff);         // the EFI status, past -errno's range
  // LoadOptions: cmd as UCS-2, nul-terminated, in pool the child may keep
  uint16_t *o = 0;
  void **cl = 0;
  if (!ec(bs[8], 2, 2 * (cn + 1), (uintptr_t) &o, 0, 0, 0)
      && !ec(bs[19], (uintptr_t) h, (uintptr_t) lip_g, (uintptr_t) &cl, 0, 0, 0)) {
    for (uintptr_t i = 0; i < cn; i++) o[i] = (uint8_t) cmd[i];
    o[cn] = 0;
    ((uint32_t *) cl)[12] = (uint32_t) (2 * (cn + 1));
    cl[7] = o; }
  // the initrd's handle: InstallProtocolInterface, native, once for each protocol
  struct k_lf2 lf = {kboot.efi_back, k_lf2_load, rd, rn};
  void *rh = 0;
  if (rd && (ec(bs[16], (uintptr_t) &rh, (uintptr_t) dp_g, 0, (uintptr_t) rd_dp, 0, 0)
             || ec(bs[16], (uintptr_t) &rh, (uintptr_t) lf2_g, 0, (uintptr_t) &lf, 0, 0))) {
    if (rh) ec(bs[18], (uintptr_t) rh, (uintptr_t) dp_g, (uintptr_t) rd_dp, 0, 0, 0);
    return ec(bs[28], (uintptr_t) h, 0, 0, 0, 0, 0), -EBUSY; }   // UnloadImage: one is there already
  r = ec(bs[26], (uintptr_t) h, 0, 0, 0, 0, 0);
  if (rd) ec(bs[18], (uintptr_t) rh, (uintptr_t) lf2_g, (uintptr_t) &lf, 0, 0, 0),
          ec(bs[18], (uintptr_t) rh, (uintptr_t) dp_g, (uintptr_t) rd_dp, 0, 0, 0);
  return (long) r; }

long k_kexec(char const *p, uintptr_t pn, char const *cmd, uintptr_t cn) {
  return k_kexec_initrd(p, pn, cmd, cn, 0, 0); }
#endif
