// src/inle/uefi/slot.c -- hearts' boot chooser, a BOOTAA64.EFI that picks a slot and starts
// that slot's EFI-stub kernel. its volume (the ESP) carries hearts.st and a directory per slot:
//   hearts.st      three bytes: the active slot, the slot to try once or '-', a newline
//   a/Image a/cmd  the kernel and its command line, likewise b/
// a pending try is spent before it boots -- the file rewritten in place -- so a trial that never
// says it is well comes back, at its next reset, on the active slot. the kernel's line gets
// " hearts.slot=X", and " hearts.try=1" on a trial.

typedef unsigned long long u64;
typedef unsigned int u32;
typedef unsigned short u16;
typedef unsigned char u8;

extern u64 efi_call(void *fn, u64 a, u64 b, u64 c, u64 d, u64 e);
extern u64 efi_call6(void *fn, u64 a, u64 b, u64 c, u64 d, u64 e, u64 f);

static u8
 lip_guid[16] = {0xa1,0x31,0x1b,0x5b,0x62,0x95,0xd2,0x11,0x8e,0x3f,0x00,0xa0,0xc9,0x69,0x72,0x3b},
 sfs_guid[16] = {0x22,0x5b,0x4e,0x96,0x59,0x64,0xd2,0x11,0x8e,0x39,0x00,0xa0,0xc9,0x69,0x72,0x3b},
 nfo_guid[16] = {0x92,0x6e,0x57,0x09,0x3f,0x6d,0xd2,0x11,0x8e,0x39,0x00,0xa0,0xc9,0x69,0x72,0x3b};

static void **sys, **bs;               // SystemTable / BootServices, u64-slot views

static void say(char const *s) {
 u16 w[128];
 int i = 0;
 for (; s[i] && i < 126; i++) w[i] = (u16) (unsigned char) s[i];
 w[i] = 0;
 efi_call(((void **) sys[8])[1], (u64) sys[8], (u64) w, 0, 0, 0); }

static u64 die(char const *s) { say("hearts: "); say(s); say("\r\n"); return 1; }

// a file on the ESP by its path, opened with mode (1 read, 3 read+write); 0 when absent
static void *fopen_(void *root, char const *path, u64 mode) {
 u16 w[64];
 int i = 0;
 for (; path[i] && i < 63; i++) w[i] = (u16) (path[i] == '/' ? '\\' : (unsigned char) path[i]);
 w[i] = 0;
 void *f = 0;
 return efi_call(((void**) root)[1], (u64) root, (u64) &f, (u64) w, mode, 0) ? 0 : f; }

static void fclose_(void *f) { efi_call(((void**) f)[2], (u64) f, 0, 0, 0, 0); }

// the whole file into pool memory; its size through *n
static u8 *slurp(void *root, char const *path, u64 *n) {
 void *f = fopen_(root, path, 1);
 if (!f) return 0;
 static u8 nfo[512];
 u64 nsz = sizeof nfo, b = 0;
 u8 *out = 0;
 if (!efi_call(((void**) f)[8], (u64) f, (u64) nfo_guid, (u64) &nsz, (u64) nfo, 0)) {
  u64 sz = *(u64*) (nfo + 8), got = sz;
  if (!efi_call(bs[8], 2, sz + 1, (u64) &b, 0, 0)          // AllocatePool, LoaderData
      && !efi_call(((void**) f)[4], (u64) f, (u64) &got, b, 0, 0) && got == sz) {
   out = (u8*) b; out[sz] = 0; *n = sz; } }
 fclose_(f);
 return out; }

u64 efi_main(void *handle, void *st) {
 sys = (void**) st;
 bs = (void**) sys[12];

 void *lip = 0, *sfs = 0, *root = 0;
 if (efi_call(bs[19], (u64) handle, (u64) lip_guid, (u64) &lip, 0, 0))
  return die("no LoadedImage protocol");
 if (efi_call(bs[19], (u64) ((void**) lip)[3], (u64) sfs_guid, (u64) &sfs, 0, 0))
  return die("no filesystem on the boot volume");
 if (efi_call(((void**) sfs)[1], (u64) sfs, (u64) &root, 0, 0, 0))
  return die("cannot open the boot volume");

 // the state: a trial is spent here, before it runs
 void *sf = fopen_(root, "hearts.st", 3);
 if (!sf) return die("no hearts.st");
 u8 s[3];
 u64 sn = 3;
 if (efi_call(((void**) sf)[4], (u64) sf, (u64) &sn, (u64) s, 0, 0) || sn != 3
     || (s[0] != 'a' && s[0] != 'b') || (s[1] != '-' && s[1] != 'a' && s[1] != 'b'))
  return die("hearts.st is not a state");
 u8 slot = s[0], trial = s[1] != '-' && s[1] != s[0];
 if (s[1] != '-') {
  if (trial) slot = s[1];
  u8 w[3] = {s[0], '-', '\n'};
  u64 wn = 3;
  if (efi_call(((void**) sf)[7], (u64) sf, 0, 0, 0, 0)       // SetPosition 0
      || efi_call(((void**) sf)[5], (u64) sf, (u64) &wn, (u64) w, 0, 0) || wn != 3
      || efi_call(((void**) sf)[10], (u64) sf, 0, 0, 0, 0))  // Flush
   return die("cannot spend the trial in hearts.st"); }
 fclose_(sf);

 char kp[] = "x/Image", cp[] = "x/cmd";
 kp[0] = cp[0] = (char) slot;
 u64 kn = 0, cn = 0;
 u8 *k = slurp(root, kp, &kn), *c = slurp(root, cp, &cn);
 if (!k) return die("the slot has no Image");
 say("hearts: slot "); say(slot == 'a' ? "a" : "b"); say(trial ? ", a trial\r\n" : "\r\n");

 // the kernel's line, as UCS-2: the slot's cmd to its first control byte, then ours
 static u16 line[512];
 u32 n = 0;
 for (u64 i = 0; c && i < cn && c[i] >= 32 && n < 400; i++) line[n++] = c[i];
 char const *tail = trial ? " hearts.slot=x hearts.try=1" : " hearts.slot=x";
 for (u32 i = 0; tail[i]; i++) line[n++] = (u16) (tail[i] == 'x' ? slot : (unsigned char) tail[i]);
 line[n++] = 0;

 void *child = 0, *clip = 0;
 if (efi_call6(bs[25], 0, (u64) handle, 0, (u64) k, kn, (u64) &child))   // LoadImage
  return die("the firmware will not load the Image");
 if (efi_call(bs[19], (u64) child, (u64) lip_guid, (u64) &clip, 0, 0))
  return die("the Image has no LoadedImage protocol");
 *(u32*) ((u8*) clip + 48) = n * 2;                         // LoadOptionsSize
 *(void**) ((u8*) clip + 56) = line;                        // LoadOptions
 efi_call(bs[26], (u64) child, 0, 0, 0, 0);                 // StartImage: no return when well
 return die("the kernel came back"); }
