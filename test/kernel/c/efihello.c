/* test/kernel/c/efihello.c -- an EFI image for the boot menu to start (test/kernel/stay.l): it says
 * its LoadOptions on ConOut and gives 42 back to its parent. mkboot links it as it does the loader */
typedef unsigned long long u64;
typedef unsigned short u16;
extern u64 efi_call(void *fn, u64 a, u64 b, u64 c, u64 d, u64 e);

u64 efi_main(void *handle, void *st) {
 void **sys = st, **bs = sys[12], *lip = 0;
 static unsigned char const lip_g[16] = {0xa1,0x31,0x1b,0x5b,0x62,0x95,0xd2,0x11,0x8e,0x3f,0x00,0xa0,0xc9,0x69,0x72,0x3b};
 u16 w[64];
 char const *m = "efihello: ";
 int i = 0;
 for (; m[i]; i++) w[i] = (u16) m[i];
 if (!efi_call(bs[19], (u64) handle, (u64) lip_g, (u64) &lip, 0, 0)) {   // HandleProtocol
  u16 const *o = ((u16 **) lip)[7];                                      // LoadOptions
  for (int j = 0; o && o[j] && i < 60; j++) w[i++] = o[j]; }
 w[i++] = '\r', w[i++] = '\n', w[i] = 0;
 efi_call(((void **) sys[8])[1], (u64) sys[8], (u64) w, 0, 0, 0);        // ConOut OutputString
 return 42; }
