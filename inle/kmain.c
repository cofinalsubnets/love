#include "k.h"
#include "love.h"
#include "cats.h"
#include "quay.h"
#include "asmops.h"                    // the privileged instructions, both spellings
#include <stdarg.h>
#include <limits.h>
#include <string.h>
#include <errno.h>      // the E numbers only (the host's, linux's) -- no errno variable down here

uint64_t kticks;
// the timer runs at 100 Hz on both arches (mkvec.l's PIT divisor, a64's cntfrq/100),
// so one tick is this many ms -- what every deadline below rounds up to.
#define k_tick_ms 10
static uintptr_t k_ticks_for(uintptr_t ms) { return (ms + k_tick_ms - 1) / k_tick_ms; }
// higher-half direct map offset: physical P is at khhdm + P, off kboot's hhdm. set
// before archinit, so arch code can use it for MMIO.
uintptr_t khhdm;
// the window that runs: the hhdm carries NX for the whole higher half (inle/mkboot.l),
// so the identity map is the same pages without the bit, which is what code needs.
char *ai_code_window(char *p) { return (char*)((uintptr_t) p - khhdm); }

static struct mem {
  struct mem *next;
  uintptr_t len;
  uintptr_t _[];
} *kmem;

// total free RAM in kmem, in words -- meminit sums it; it bounds the collector (g->budget).
static uintptr_t kram_words;

static struct cb *kcb;


static struct {
  volatile uint32_t *_;
  uint16_t width, height, pitch;
  uint8_t scale;
  uint32_t cap_px; } kfb;            // scale = px per glyph px; cap_px = the paper's bound

// keyboard input: kb_int decodes scancodes into the ascii queue (q/qh/qt) kb_readn and
// (key) drain, g holds the modifier flags, `raw` arms the scancode tap (r/rh/rt) beside it.
static struct { uint8_t g, q[16], qh, qt; uint16_t lost;
                uint8_t raw, r[64], rh, rt; } kkb;
// enqueue one input byte; the COM1 serial RX ap (k_uart) feeds the same queue. an interrupt
// cannot wait, so the ring is bounded: a drop is counted (serial_flush says how many fell)
// and the count saturates rather than wrapping.
void kq(uint8_t b) {
  uint8_t n = (kkb.qt + 1) & 15;
  if (n != kkb.qh) kkb.q[kkb.qt] = b, kkb.qt = n;
  else if (kkb.lost != (uint16_t) -1) kkb.lost++; }
static int kqpop(void) {                   // dequeue one byte, -1 if empty
  if (kkb.qh == kkb.qt) return -1;
  int b = kkb.q[kkb.qh];
  return kkb.qh = (kkb.qh + 1) & 15, b; }

// the console's face: glyphs and their size; kfb.scale says how large, paint.c the palette.
static struct font const kface = { (uint8_t const*) cleat_8x16, 8, 16 };



// the seat hooks inle/fd.c branches to on a negative osv (weak no-ops there)
void k_row_close(int fd), k_sleep(uintptr_t ms), k_wait_fds(struct ai_wait_fd*, int, uintptr_t),
     k_seat_init(void);                // inle/sys.c: arm environ + the std streams
bool k_ready(int fd, int events);

// the panic-time console: the ring buffer (kcb) when there is one, mirrored to serial.
// takes no l state, so it runs from a fault handler with no live `struct g`.
void kputc(int c) { if (kcb) cb_putc(kcb, (char) c); serial_putc(c); }
void kputs(char const *s) { while (*s) kputc(*s++); }
void kputn(uintptr_t n, int base) {
 static char const d[] = "0123456789abcdef";
 char buf[24]; int i = 0;
 do buf[i++] = d[n % base], n /= base; while (n);
 while (i) kputc(buf[--i]); }
// the kernel-only nif bracket (defs[] below); the linker synthesizes the pair
extern struct ai_def const __start_ai_knifs[], __stop_ai_knifs[];
// the bracket, for the image codec's nif slice (love/snap.c's weak default answers none)
uintptr_t ai_knifs_slice(struct ai_def const **s) {
  return *s = __start_ai_knifs, (uintptr_t)(__stop_ai_knifs - __start_ai_knifs); }
// the metal image's far edge, patched into the file by the projection (tools/kproject.l):
// the flat link's kimage_end. unpatched, the memmap excludes nothing and the heap eats it.
uintptr_t const k_image_top = 1;

#include "quay.h"
#include <stdarg.h>
// kboot -- the machine as the door found it, filled before kmain reads it (pvh_to_kboot off
// hvm_start_info, the UEFI loader off the firmware, the a64 stub off the DTB). nothing below
// asks which door answered.
struct k_boot kboot;

#define kb_code_lshift 0x2a
#define kb_code_rshift 0x36
#define kb_code_extend 0xe0
#define kb_code_delete 0x53
#define kb_code_ctl 0x1d
#define kb_code_alt 0x38
#define kb_flag_rshift 1
#define kb_flag_lshift 2
#define kb_flag_rctl   4
#define kb_flag_lctl   8
#define kb_flag_ralt   16
#define kb_flag_lalt   32
#define kb_flag_extend 128
#define kb_flag_alt (kb_flag_lalt|kb_flag_ralt)
#define kb_flag_ctl (kb_flag_lctl|kb_flag_rctl)
#define kb_flag_shift (kb_flag_lshift|kb_flag_rshift)

// --- vfs-shaped source table ----------------------------------------------
// k_sources[] holds per-fd vtables and ai_fd_port_vt routes each call through k_sources[fd].
// a NULL slot is "no method" and the dispatcher skips it: writes discard, reads answer the
// end, ready answers false. `state` is per-instance scratch, a ramfs fd's handle. the table
// grows in the kernel's own heap through k_source_open, so nothing is refused at a ceiling.
void *kmallocw(uintptr_t n);
void kfree(void *p);

struct k_source {
  // the read door (love.h's readn contract, one fd deeper): >0 bytes, 0 nothing, -1 end
  intptr_t (*readn)(int fd, unsigned char *dst, uintptr_t n),
  // the same contract mirrored: >0 = bytes taken, 0 = busy, -1 = gone. a row carrying one
  // is asked instead of putc, so the ramfs can refuse rather than drop a byte in silence.
           (*writen)(int fd, unsigned char const *src, uintptr_t n);
  bool (*ready)(int fd);                // non-blocking probe
  void (*putc)(int fd, int c),
       (*flush)(int fd),
       (*close)(int fd),                // release per-fd state
       *state; };

// a seat with no keyboard interrupt (wasm) looks here whenever a task asks after a key,
// and is told the room left, so a burst waits in its own buffer. metal has nothing to do.
__attribute__((weak)) void k_kb_sync(int room) { (void) room; }
void k_kb_poll(void) { k_kb_sync(15 - ((kkb.qt - kkb.qh) & 15)); }

// slot 0: PS/2 keyboard. drains what the interrupt queued and answers 0 when there is
// nothing -- never the end, the kb queue being endless. the scheduler owns the wait.
static intptr_t kb_readn(int fd, unsigned char *dst, uintptr_t n) {
  k_kb_poll();
  uintptr_t k = 0;
  for (int b; k < n && (b = kqpop()) >= 0; ) dst[k++] = (unsigned char) b;
  return (intptr_t) k; }

static bool kb_ready(int fd) { return k_kb_poll(), kkb.qh != kkb.qt; }

// slot 1: serial console -- the framebuffer when there is one, always mirrored to COM1.
static void serial_putc1(int fd, int c) {
  if (kcb) cb_putc(kcb, c);
  serial_putc(c); }

// kq's drops, said before the frame goes up.
static void serial_flush(int fd) {
  if (kkb.lost) {
    char d[6];
    int i = 0;
    unsigned v = kkb.lost;
    kkb.lost = 0;
    for (char const *s = "\n; input lost: "; *s; s++) serial_putc1(1, *s);
    do d[i++] = (char) ('0' + v % 10); while ((v /= 10));
    while (i) serial_putc1(1, d[--i]);
    for (char const *s = " bytes\n"; *s; s++) serial_putc1(1, *s); }
  fbdraw(); }

// the boot rows stay static: the console is how the kernel says an allocation failed, so it
// cannot need one. err carries its own fd, so out can ride a pipe while a scare stays here.
static struct k_source k_boot[] = {
  [0] = { .readn = kb_readn,    .ready = kb_ready    },
  [1] = { .putc = serial_putc1, .flush = serial_flush },
  [2] = { .putc = serial_putc1, .flush = serial_flush }, };
static struct k_source *k_sources = k_boot;
static int k_sources_n = (int) countof(k_boot);

// the row for fd, or NULL -- the file's one bounds check; no dispatcher carries a limit.
static ai_inline struct k_source *k_source(int fd) {
 return fd >= 0 && fd < k_sources_n ? &k_sources[fd] : NULL; }

// in range is not open: a closed row is zeroed where it stands, never removed, so k_source
// keeps answering it. carrying any method at all is what live means.
static ai_inline bool k_row_live(int fd) {
 struct k_source const *s = k_source(fd);
 return s && (s->readn || s->writen || s->putc || s->flush || s->ready || s->close); }

// answer fd's row, doubling the table first if need be (no realloc down here, and the
// static boot table is never freed). NULL is no memory, a refusal the caller must read.
static struct k_source *k_source_open(int fd) {
 if (fd < 0) return NULL;
 if (fd >= k_sources_n) {
  int m = k_sources_n;
  while (m <= fd) m *= 2;
  struct k_source *t = kmallocw(b2w((uintptr_t) m * sizeof *t));
  if (!t) return NULL;
  for (int i = 0; i < m; i++)
    t[i] = i < k_sources_n ? k_sources[i] : (struct k_source) {0};
  if (k_sources != k_boot) kfree(k_sources);
  k_sources = t, k_sources_n = m; }
 return &k_sources[fd]; }

// --- rung 4: a task's stdio ---------------------------------------------------
// a task wears a chain (i o e) of real ports (prel's `wear`, hook 6) and io_route swaps
// the folded in/b/err for them, so ai_io_fd already answers the row: nothing to translate.

// the running task's pid: the run ring's head is the running task (love.c), its pid at
// node[2]. the main task wears the zero point and reads 0, which no spawned pid can be.
static ai_inline intptr_t k_cur_pid(struct ai *g) {
 union u *t = ai_core_of(g)->tasks;
 return t && (t[2].x & 1) ? getcharm(t[2].x) : 0; }

// the row-level motions, on an already-resolved fd -- the port dispatchers below resolve
// through the seat first, where the syscall door and the raw-fd lanes do not.
intptr_t k_row_read(int fd, unsigned char *dst, uintptr_t n) {
 struct k_source *s = k_source(fd);
 if (!s || !s->readn) return -1;
 return s->readn(fd, dst, n); }

intptr_t k_row_write(int fd, unsigned char const *src, uintptr_t n) {
 struct k_source *s = k_source(fd);
 if (!s) return (intptr_t) n;
 if (s->writen) return s->writen(fd, src, n);
 if (!s->putc) return (intptr_t) n;
 for (uintptr_t k = 0; k < n; k++) s->putc(fd, src[k]);
 return (intptr_t) n; }

// the port lanes ai_fd_port_vt (inle/fd.c) takes on a negative osv: the seat translation,
// then the rows. busy and end are distinct here, which read(2) cannot carry.
intptr_t k_port_readn(struct ai *g, unsigned char *dst, uintptr_t n) {
 return k_row_read((int) ai_io_fd(g->io), dst, n); }

struct ai *k_port_writen(struct ai *g, unsigned char const *src, uintptr_t n) {
 return g->b = k_row_write((int) ai_io_fd(g->io), src, n), g; }

// inle/sys.c's door: the POSIX shapes over the same rows. the port layer says end with -1
// and read(2) with 0, so the ends are translated here and not in the syscall table.
long k_fd_write(int fd, void const *b, long n) { return
 n < 0 ? -22 : (long) k_row_write(fd, (unsigned char const *) b, (uintptr_t) n); }

static void k_dir_close(int fd);       // the directory row's close, and its brand

long k_fd_read(int fd, void *b, long n) {
 if (n < 0) return -22;
 struct k_source *s = k_source(fd);
 if (s && s->close == k_dir_close) return -21;          // EISDIR: a directory reads via getdents
 intptr_t r = k_row_read(fd, (unsigned char *) b, (uintptr_t) n);
 return r < 0 ? 0 : (long) r; }

long k_fd_close(int fd) {
 if (!k_row_live(fd)) return -9;                        // EBADF
 k_row_close(fd);
 return 0; }

struct ai *k_port_flush(struct ai *g) {
 int fd = (int) ai_io_fd(g->io);
 struct k_source *s = k_source(fd);
 if (s && s->flush) s->flush(fd);
 return g; }

// ai_fd_close's inle lane (inle/fd.c). statics have NULL close -- nothing to release.
void k_row_close(int fd) {
 struct k_source *s = k_source(fd);
 if (s && s->close) s->close(fd); }

// no write-direction probe: a row that can take a byte can always take one, so out is ready
bool k_ready(int fd, int events) {
 if (fd < 0) return true;
 if (events != ai_wait_in) return true;
 struct k_source *s = k_source(fd);
 return s && s->ready && s->ready(fd); }

// multi-source wait; ms=0 is infinite, and every answer is recorded in `revents` so the
// scheduler skips re-asking. a seat with no timer interrupt (wasm) catches kticks up here.
__attribute__((weak)) void k_tick_sync(void) { }

// parked: the console takes a frame before the machine stops, or an idle screen would hold
// one half of the cursor blink (fbdraw's phase is kticks & 64) for as long as it sat.
static void k_park(void) {
  fbdraw();
  k_horn_poll();
  k_wait(); }

void k_wait_fds(struct ai_wait_fd *fds, int n, uintptr_t ms) {
  if (n <= 0) { k_sleep(ms); return; }
  k_tick_sync();
  uintptr_t deadline = kticks + k_ticks_for(ms);
  for (;;) {
    int any = 0;
    for (int i = 0; i < n; i++) {
      int r = k_ready(fds[i].fd, fds[i].events);
      fds[i].revents = r ? fds[i].events : 0;
      any |= r; }
    if (any || (ms && kticks >= deadline)) return;
    k_park(); } }

// milliseconds since the epoch: one scale for deadlines, (clock t) and every mtime. the
// date rides kboot; where nobody knew it this is ms since boot and says so by reading 1970.
uintptr_t k_clock_ms(void) {
  k_tick_sync();
  return (uintptr_t) (kboot.date * 1000 + kticks * k_tick_ms); }

// pure time-wait; ms=0 is infinite. a seat that can sleep finer than the tick (inle/wasm's
// nanosleep) takes a short sleep whole and answers true; metal rounds up to the tick.
__attribute__((weak)) bool k_nap(uintptr_t ms) { return (void) ms, false; }
void k_sleep(uintptr_t ms) {
  if (ms && ms < k_tick_ms && k_nap(ms)) return;
  k_tick_sync();
  uintptr_t deadline = kticks + k_ticks_for(ms);
  for (;;) {
    if (ms && kticks >= deadline) break;
    k_park(); } }

static const uint8_t
  kb2ascii[] = {
     0,  27, '1',  '2', '3', '4', '5', '6',
   '7', '8', '9',  '0', '-', '=',   8,   9,
   'q', 'w', 'e',  'r', 't', 'y', 'u', 'i',
   'o', 'p', '[',  ']',  10,   0, 'a', 's',
   'd', 'f', 'g',  'h', 'j', 'k', 'l', ';',
  '\'', '`',   0, '\\', 'z', 'x', 'c', 'v',
   'b', 'n', 'm',  ',', '.', '/',   0, '*',
     0, ' ' },
  shift_kb2ascii[] = {
     0,  27, '!',  '@', '#', '$', '%', '^',
   '&', '*', '(',  ')', '_', '+',   8,   9,
   'Q', 'W', 'E',  'R', 'T', 'Y', 'U', 'I',
   'O', 'P', '{',  '}',  10,   0, 'A', 'S',
   'D', 'F', 'G',  'H', 'J', 'K', 'L', ':',
   '"', '~',   0,  '|', 'Z', 'X', 'C', 'V',
   'B', 'N', 'M',  '<', '>', '?',   0, '*',
     0, ' ' };

_Static_assert(countof(kb2ascii) == countof(shift_kb2ascii), "one scancode table, two faces");

#define kb_code_left 75
#define kb_code_right 77
#define kb_code_up 72
#define kb_code_down 80
#define kb_code_home 71
#define kb_code_end 79
// the scancode tap: arm it, then drain. a code is the PS/2 byte with the 0xe0 prefix
// folded onto the one that follows (bit 7 is the break bit, so an extended key wears 0x100).
void k_scan_arm(int on) { kkb.raw = on ? 1 : 0, kkb.rh = kkb.rt = 0; }
// ..and whether anything is listening. a seat that is HANDED codes rather than interrupted
// by them asks before it leaves a lane full: nothing reads it, so nothing empties it.
bool k_scan_armed(void) { return kkb.raw != 0; }
// a seat whose codes are polled rather than interrupted (inle/wasm) fills the tap here
__attribute__((weak)) void k_scan_sync(void) { }
int k_scan_pop(void) {
  if (kkb.rh == kkb.rt) k_scan_sync();
  if (kkb.rh == kkb.rt) return -1;
  int b = kkb.r[kkb.rh];
  kkb.rh = (kkb.rh + 1) & 63;
  if (b != kb_code_extend) return b;
  if (kkb.rh == kkb.rt) return -1;         // the pair is not whole yet
  b = kkb.r[kkb.rh], kkb.rh = (kkb.rh + 1) & 63;
  return b | 0x100; }
static void kraw(uint8_t b) {
  uint8_t n = (kkb.rt + 1) & 63;
  if (n != kkb.rh) kkb.r[kkb.rt] = b, kkb.rt = n; }
// the tap alone: a code whose text arrives on its own lane (inle/wasm's scan ring)
void k_scan_put(uint8_t b) { if (kkb.raw) kraw(b); }
// the paper changed under a writer of its own (inle/doom.c's frame): a seat whose paper a
// page shows, rather than a display scanning it out, wants to hear (inle/wasm).
__attribute__((weak)) void k_fb_touch(void) { }

// decode a PS/2 scancode (interrupt context) into input bytes: arrows, Home, End and Delete
// as ANSI escapes, Ctrl+Home/End as `ESC [ 1 ; 5 H/F`, Ctrl+letter as the control byte.
void kb_int(const uint8_t code) {
  if (kkb.raw) kraw(code);
  if (code == kb_code_extend) { kkb.g |= kb_flag_extend; return; }
  bool ext = kkb.g & kb_flag_extend, up = code & 128;
  uint8_t sc = code & 127;
  kkb.g &= ~kb_flag_extend;
  if (ext) switch (sc) {
    case kb_code_ctl: kkb.g = up ? kkb.g & ~kb_flag_rctl : kkb.g | kb_flag_rctl; return;
    case kb_code_alt: kkb.g = up ? kkb.g & ~kb_flag_ralt : kkb.g | kb_flag_ralt; return;
    case kb_code_delete:
      if (up) return;
      if (kkb.g & kb_flag_ctl && kkb.g & kb_flag_alt) k_reset();
      kq(27), kq('['), kq('3'), kq('~'); return;       // Delete -> CSI 3 ~
    case kb_code_left:  if (!up) kq(27), kq('['), kq('D'); return;
    case kb_code_right: if (!up) kq(27), kq('['), kq('C'); return;
    case kb_code_up:    if (!up) kq(27), kq('['), kq('A'); return;
    case kb_code_down:  if (!up) kq(27), kq('['), kq('B'); return;
    case kb_code_home:
      if (up) return;
      if (kkb.g & kb_flag_ctl) kq(27), kq('['), kq('1'), kq(';'), kq('5'), kq('H');
      else kq(27), kq('['), kq('H');
      return;
    case kb_code_end:
      if (up) return;
      if (kkb.g & kb_flag_ctl) kq(27), kq('['), kq('1'), kq(';'), kq('5'), kq('F');
      else kq(27), kq('['), kq('F');
      return;
    default: return; }
  switch (sc) {
    case kb_code_lshift: kkb.g = up ? kkb.g & ~kb_flag_lshift : kkb.g | kb_flag_lshift; return;
    case kb_code_rshift: kkb.g = up ? kkb.g & ~kb_flag_rshift : kkb.g | kb_flag_rshift; return;
    case kb_code_ctl:    kkb.g = up ? kkb.g & ~kb_flag_lctl : kkb.g | kb_flag_lctl; return;
    case kb_code_alt:    kkb.g = up ? kkb.g & ~kb_flag_lalt : kkb.g | kb_flag_lalt; return;
    default:
      if (up || sc >= countof(kb2ascii)) return;
      uint8_t a = (kkb.g & kb_flag_shift ? shift_kb2ascii : kb2ascii)[sc];
      if (a && kkb.g & kb_flag_ctl && (a | 32) >= 'a' && (a | 32) <= 'z') a &= 31;
      if (a) kq(a);
      return; } }


static ai_inline struct mem *after(struct mem *r) {
  return (struct mem*) ((uintptr_t*) r + r->len); }

void *kmallocw(uintptr_t n) {
  if (!n) return NULL;
  void *p = NULL;
  struct mem *r = NULL, *t;
  while (kmem && kmem->len < n + 2 * Width(struct mem))
    t = kmem,
    kmem = t->next,
    t->next = r,
    r = t;
  if (kmem)
    kmem->len -= n + Width(struct mem),
    t = after(kmem),
    t->len = Width(struct mem) + n,
    p = t->_;
  while (r)
    t = r,
    r = t->next,
    t->next = kmem,
    kmem = t;
  return p; }

void kfree(void *p) {
  if (!p) return;
  struct mem *m = (struct mem*)p - 1, *r = NULL, *t;
  while (kmem && kmem < m)
    t = kmem,
    kmem = t->next,
    t->next = r,
    r = t;
  for (;; m = r, r = r->next) {
    if (kmem != after(m)) m->next = kmem;
    else m->len += kmem->len,
         m->next = kmem->next;
    kmem = m;
    if (!r) return; } }


// --- the ramfs: the baked tree, and the copies writes make -----------------
// the initrd is read-only bytes and one row per file. reads come straight off it; the first
// write copies that file into the kernel heap and the entry reads the copy ever after.
// kmallocw/kfree rather than ai_alloc: a vt method is handed an fd and nothing else, so g
// is out of reach at the door that grows a file. ms is the source's baked mtime.
struct k_file { char const *path, *bytes; uintptr_t len, ms; };
// the initrd is the source blob: the artifact carries its whole tree as ai_srcgz, so the
// kernel inflates that and walks the tar; rows point into the inflated block.
static struct k_file const *k_bakes;
static int k_bakes_n;
#include "ustar.h"
// the tree's rows live under /proc/src, read-only, so a module loads from bytes the shell
// cannot have edited. the root holds inle/rootfs/, a second tar walked with no prefix.
static char const k_home[] = "home";
static char const k_tree[] = "proc/src";
#define k_tree_n (sizeof k_tree - 1)
// one ustar pass: count with rows NULL, fill on the second. paths re-home below the archive's
// top and under pre. a symlink lands as a row whose target rides lnks[k] -- lib/'s door to
// the crew modules is symlinks, and dropping them would lose every module behind it.
static int k_tar_walk(unsigned char const *t, uintptr_t n, struct k_file *rows, char **lnks,
                      char const *pre, uintptr_t pn) {
  int k = 0;
  for (uintptr_t o = 0; o + 512 <= n && t[o];) {
    unsigned char const *h = t + o;
    uintptr_t sz = ai_ustar_octal(h + 124, 12);
    if (ai_ustar_member(h)) {
      if (rows) {
        char nm[256];
        uintptr_t ln = ai_ustar_name(h, nm, sizeof nm);      // TOP stripped
        uintptr_t at = pn ? pn + 1 : 0;
        char *p = kmallocw(b2w(at + ln + 1));
        if (!p) return -1;
        if (pn) memcpy(p, pre, pn), p[pn] = '/';
        memcpy(p + at, nm, ln);
        p[at + ln] = 0;
        rows[k] = (struct k_file) { .path = p, .bytes = (char const *) t + o + 512,
                                    .len = sz, .ms = 1000 * ai_ustar_octal(h + 136, 12) };
        if (ai_ustar_islink(h)) {
          char tgt[101], cn[256];
          tgt[ai_ustar_link(h, tgt, sizeof tgt - 1)] = 0;
          uintptr_t cl = ai_lnk_canon(p, tgt, cn, sizeof cn);
          char *q = kmallocw(b2w(cl + 1));
          if (!q) return -1;
          memcpy(q, cn, cl);
          q[cl] = 0;
          lnks[k] = q; } }
      k++; }
    o += 512 + ((sz + 511) & ~511ull); }
  return k; }
static bool k_untar(void) {
  uintptr_t o = 0, un = 0;
  if (!ai_gz_body(ai_srcgz, ai_srcgz_len, &o, &un)) return false;
  unsigned char *t = kmallocw(b2w(un + 1));
  if (!t || ai_inflate_raw(ai_srcgz + o, ai_srcgz_len - o - 8, t, un) != (intptr_t) un)
    return false;
  int n1 = k_tar_walk(t, un, NULL, NULL, k_tree, k_tree_n);
  if (n1 <= 0) return false;
  // the machine's own rows ride a second, plain tar (inle/rootfs/ through tools/mkrootfs.l)
  int n2 = ai_rootfs_len ? k_tar_walk(ai_rootfs, ai_rootfs_len, NULL, NULL, "", 0) : 0;
  if (n2 < 0) return false;
  int n = n1 + n2;
  struct k_file *rows = kmallocw(b2w((uintptr_t) n * sizeof *rows));
  char **lnks = kmallocw(b2w((uintptr_t) n * sizeof *lnks));
  if (!rows || !lnks) return false;
  memset(lnks, 0, (uintptr_t) n * sizeof *lnks);
  if (k_tar_walk(t, un, rows, lnks, k_tree, k_tree_n) != n1) return false;
  if (n2 && k_tar_walk(ai_rootfs, ai_rootfs_len, rows + n1, lnks + n1, "", 0) != n2) return false;
  // resolve the symlinks against the rows (two passes cover a link to a link), then compact:
  // a dangling or directory link has no bytes to serve.
  for (int pass = 0; pass < 2; pass++)
    for (int i = 0; i < n; i++)
      if (lnks[i])
        for (int j = 0; j < n; j++)
          if (!lnks[j] && !strcmp(rows[j].path, lnks[i])) {
            rows[i].bytes = rows[j].bytes, rows[i].len = rows[j].len;
            rows[i].ms = rows[j].ms;
            lnks[i] = NULL;
            break; }
  int m = 0;
  for (int i = 0; i < n; i++)
    if (!lnks[i]) rows[m++] = rows[i];
  kfree(lnks);
  k_bakes = rows, k_bakes_n = m;
  return true; }

// an object in this link may bake files of its own: a strong k_baked overrides this weak
// nothing. asked twice -- with no room for the count, then to fill -- so the table is ours.
__attribute__((weak)) int k_baked(struct k_file *rows, int cap) {
  return (void) rows, (void) cap, 0; }
static struct k_file const *k_extra;
static int k_extra_n;
// what bake row i is: the initrd's, then the linked-in ones behind it.
static struct k_file const *k_bake_row(int i) {
  return i < k_bakes_n ? &k_bakes[i] : &k_extra[i - k_bakes_n]; }

// the tree (rung 2): entries in the kernel heap, one per baked row at first touch, growing
// as create and mkdir add paths. `own` has to be a bit: an emptied file is {NULL, 0}, what
// one still in .rodata looks like. `heap` is that bit for the path; a NULL path is retired.
struct k_ent {
  char const *path;                 // the canonical key
  int bake;                         // the kfiles row backing reads until the first write; -1 none
  unsigned char *bytes;
  uintptr_t len, cap, ms, mode;     // mode is the permission bits; stat lays the kind over them
  int refs;                         // open fds; an unlinked entry frees at the last close
  char const *to;                   // a symlink's target, canonical and heap; NULL is not one
  bool own, heap, dir, live;
};
static struct k_ent *k_ents;
static int k_ents_n, k_ents_cap;

// /proc/vt -- the console's colours as files, xterm-256 indices in decimal. an ordinary
// entry each: the open refreshes a read off the live pen, the close applies a write.
static char const k_vtfg[] = "proc/vt/fg", k_vtbg[] = "proc/vt/bg",
                  k_vtscale[] = "proc/vt/scale";
// /proc/lift -- a path written here asks the seat to carry that file out of the machine
// (the page saves a download); a seat with nowhere to put it does nothing.
static char const k_plift[] = "proc/lift";
__attribute__((weak)) void k_lift_ask(unsigned char const *p, uintptr_t n) { (void) p; (void) n; }
// and the two the open fills from the running machine, below the grow door they need
static char const k_pmem[] = "proc/meminfo", k_pgauge[] = "proc/gauge";
// and the boot line, the one row that answers what this machine was asked to run.
static char const k_pcmd[] = "proc/cmdline";
// /dev/{null,zero}: neither holds bytes -- null is the source table's empty slot, zero that
// slot with a read door. the entries below exist only so stat and dents can see them.
static char const k_dnull[] = "dev/null", k_dzero[] = "dev/zero";
// 0 is neither, 1 null, 2 zero.
static int k_dev_slot(char const *p, uintptr_t n) {
  if (n == sizeof k_dnull - 1 && !memcmp(p, k_dnull, n)) return 1;
  if (n == sizeof k_dzero - 1 && !memcmp(p, k_dzero, n)) return 2;
  return 0; }
static intptr_t k_zero_readn(int fd, unsigned char *dst, uintptr_t n) {
  return memset(dst, 0, n), (intptr_t) n; }
// null takes every byte. a row with no hook at all is not a row: k_dup_row refuses to clone
// one, and `2>/dev/null` is a dup of exactly that onto a child's stderr.
static intptr_t k_null_writen(int fd, unsigned char const *src, uintptr_t n) {
  return (intptr_t) n; }
static bool k_dev_ready(int fd) { return true; }

// 0 is neither, 1 the foreground, 2 the background, 3 the glyph scale, 4 the lift.
static int k_vt_slot(char const *p, uintptr_t n) {
  if (n == sizeof k_vtfg - 1 && !memcmp(p, k_vtfg, n)) return 1;
  if (n == sizeof k_vtbg - 1 && !memcmp(p, k_vtbg, n)) return 2;
  if (n == sizeof k_vtscale - 1 && !memcmp(p, k_vtscale, n)) return 3;
  if (n == sizeof k_plift - 1 && !memcmp(p, k_plift, n)) return 4;
  return 0; }

static char *k_strdup(char const *p, uintptr_t n);   // below, with the entry doors
static bool k_vt_rescale(unsigned v);                // below, with fbdraw's cached cursor

// lay the table on first use: every baked row live off .rodata, plus tmp and the home.
// idempotent, and a refusal leaves the console standing (the caller answers ENOMEM).
static bool k_fs_init(void) {
  if (k_ents) return true;
  if (!k_bakes && !k_untar()) return false;
  int xn = k_baked(NULL, 0);
  if (xn > 0) {
    struct k_file *xr = kmallocw(b2w((uintptr_t) xn * sizeof *xr));
    if (!xr) return false;
    k_extra = xr, k_extra_n = k_baked(xr, xn); }
  int n = k_bakes_n + k_extra_n, cap = n + 15;
  struct k_ent *t = kmallocw(b2w((uintptr_t) cap * sizeof *t));
  if (!t) return false;
  for (int i = 0; i < n; i++) {
    struct k_file const *f = k_bake_row(i);
    // a dateless blob row reads as this boot: the dist tarball stamps mtime 0, and 0 is
    // how a stat says "not there" -- cook then refuses to make a leaf that is right there.
    t[i] = (struct k_ent) { .path = f->path, .bake = i,
                            .ms = f->ms ? f->ms : k_clock_ms(), .mode = 0644, .live = true }; }
  t[n] = (struct k_ent) { .path = "tmp", .bake = -1, .ms = k_clock_ms(),
                          .mode = 0755, .own = true, .dir = true, .live = true };
  // the home, empty, is where the shell starts
  t[n + 14] = (struct k_ent) { .path = k_home, .bake = -1, .ms = k_clock_ms(),
                               .mode = 0755, .own = true, .dir = true, .live = true };
  // the console's two colours, as files: own with no bytes until the first read. `proc`
  // and `proc/vt` come free -- a name baked paths lie under is a directory already.
  t[n + 1] = (struct k_ent) { .path = k_vtfg, .bake = -1, .ms = k_clock_ms(),
                              .mode = 0644, .own = true, .live = true };
  t[n + 2] = (struct k_ent) { .path = k_vtbg, .bake = -1, .ms = k_clock_ms(),
                              .mode = 0644, .own = true, .live = true };
  // ..the glyph scale, the one vt file that is not a colour. n + 8 and not n + 3: the
  // compat loop below starts where the numbered rows stop.
  t[n + 8] = (struct k_ent) { .path = k_vtscale, .bake = -1, .ms = k_clock_ms(),
                              .mode = 0644, .own = true, .live = true };
  // and the two the open fills: read-only, since nothing here is anyone's to set.
  t[n + 3] = (struct k_ent) { .path = k_pmem, .bake = -1, .ms = k_clock_ms(),
                              .mode = 0444, .own = true, .live = true };
  t[n + 4] = (struct k_ent) { .path = k_pgauge, .bake = -1, .ms = k_clock_ms(),
                              .mode = 0444, .own = true, .live = true };
  // the boot line, read-only and filled at every open, so a reset onto another line
  // changes what it answers. n + 9, past the numbered rows.
  t[n + 9] = (struct k_ent) { .path = k_pcmd, .bake = -1, .ms = k_clock_ms(),
                              .mode = 0444, .own = true, .live = true };
  // and the lift, a file written and never read, at n + 10 past the boot line
  t[n + 10] = (struct k_ent) { .path = k_plift, .bake = -1, .ms = k_clock_ms(),
                               .mode = 0644, .own = true, .live = true };
  // the two devices, 0666 and always empty; the open never touches these rows (k_dev_slot)
  t[n + 5] = (struct k_ent) { .path = k_dnull, .bake = -1, .ms = k_clock_ms(),
                              .mode = 0666, .own = true, .live = true };
  t[n + 6] = (struct k_ent) { .path = k_dzero, .bake = -1, .ms = k_clock_ms(),
                              .mode = 0666, .own = true, .live = true };
  // the compat names. `to` is heap because k_ent_gc frees it; a strdup that refuses
  // leaves a plain empty directory rather than a link that cannot be followed.
  t[n + 7] = (struct k_ent) { .path = "usr/bin", .bake = -1, .ms = k_clock_ms(),
                              .mode = 0755, .own = true, .dir = true, .live = true };
  static char const *const compat[] = { "bin", "sbin", "usr/sbin" };
  int m = n + 11;
  for (uintptr_t c = 0; c < countof(compat); c++) {
    char *to = k_strdup("/usr/bin", 8);
    t[m] = (struct k_ent) { .path = compat[c], .bake = -1, .ms = k_clock_ms(),
                            .mode = 0777, .own = true, .live = true,
                            .dir = !to, .to = to };
    m++; }
  k_ents = t, k_ents_n = m + 1, k_ents_cap = cap;
  return true; }

// the cwd, canonical ("" is the root), what k_canon resolves relative paths against.
// chdir writes it; cwd wears the leading slash. the boot seat is the home.
static char k_cwd[256] = "home";
static uintptr_t k_cwd_n = 4;

// resolve a path against the cwd into out (cap 256): absolute starts at the root.
// -> the canonical length (0 is the root), or -1 for one longer than any entry could carry.
static intptr_t k_canon(char const *p, uintptr_t pn, char *out) {
  uintptr_t n = 0;
  if (!(pn && p[0] == '/')) memcpy(out, k_cwd, n = k_cwd_n);
  return ai_path_canon(out, n, p, pn, 256); }

// the tree is nobody's to write: every mutating door refuses the mount and what lies under
static bool k_ro(char const *cp, uintptr_t cn) {
  return cn >= k_tree_n && !memcmp(cp, k_tree, k_tree_n)
      && (cn == k_tree_n || cp[k_tree_n] == '/'); }

// one open file: which entry, where in it, whether writes are allowed. rides the row's
// `state`, which the close door frees.
struct k_fh { int i, vt; uintptr_t pos; bool w; };

static intptr_t ram_readn(int fd, unsigned char *dst, uintptr_t n);

// the handle behind an fd, NULL for a row that is not the ramfs's: `state` is scratch of
// whatever kind, so the readn method is what says it means a file handle.
static ai_inline struct k_fh *k_fh(int fd) {
  struct k_source *s = k_source(fd);
  return s && s->readn == ram_readn ? s->state : NULL; }

// what entry i reads as: the heap copy once there is one, the baked blob until then.
static unsigned char const *k_blob(int i, uintptr_t *len) {
  struct k_ent const *e = &k_ents[i];
  if (e->own) return *len = e->len, e->bytes;
  struct k_file const *f = k_bake_row(e->bake);
  return *len = f->len, (unsigned char const*) f->bytes; }

// inle/sys.c's seek: a negative errno, the sign every C face here wears; whence is SEEK_*.
long k_fd_lseek(int fd, long off, int whence) {
  if (!k_row_live(fd)) return -9;                        // EBADF
  struct k_fh *h = k_fh(fd);
  if (!h) return -29;                                    // ESPIPE: a console or a pipe
  if (whence < 0 || whence > 2) return -22;              // EINVAL
  uintptr_t len;
  k_blob(h->i, &len);
  intptr_t at = off + (whence == 1 ? (intptr_t) h->pos
                     : whence == 2 ? (intptr_t) len : 0);
  if (at < 0) return -22;
  return (long) (h->pos = (uintptr_t) at); }

// canonical path -> its live entry. linear: the tree is a few dozen entries.
static int k_find(char const *p, uintptr_t n) {
  for (int i = 0; i < k_ents_n; i++)
    if (k_ents[i].live && k_ents[i].path
        && strlen(k_ents[i].path) == n && !memcmp(k_ents[i].path, p, n)) return i;
  return -1; }

// resolve a path against the cwd, links followed at every component. `leaf` false leaves a
// final link unresolved -- what readlink, unlink, rmdir, mkdir's and symlink's new name and
// both sides of rename want. -> the canonical length (0 is the root), -ENAMETOOLONG, -ELOOP.
// an expansion restarts the walk rather than splicing, and the budget is spent per
// resolution, so a chain and a deep path draw on the same 32.
#define k_hops 32
static intptr_t k_walk(char const *p, uintptr_t pn, char *out, bool leaf) {
  char in[256], nx[256];
  if (pn >= sizeof in) return -ENAMETOOLONG;
  memcpy(in, p, pn);
  uintptr_t inn = pn;
  for (int hop = 0; ; ) {
    uintptr_t n = 0;
    if (!(inn && in[0] == '/')) memcpy(out, k_cwd, n = k_cwd_n);
    bool again = false;
    for (uintptr_t i = 0; i < inn; ) {
      while (i < inn && in[i] == '/') i++;
      uintptr_t j = i;
      while (j < inn && in[j] != '/') j++;
      if (j == i) break;
      intptr_t r = ai_path_canon(out, n, in + i, j - i, 256);   // "." and ".." included,
      if (r < 0) return -ENAMETOOLONG;                          // so ".." lands on the
      n = (uintptr_t) r;                                        // RESOLVED path
      i = j;
      uintptr_t k = i;
      while (k < inn && in[k] == '/') k++;
      if (k >= inn && !leaf) break;                // the last name, kept as written
      int e = n ? k_find(out, n) : -1;
      if (e < 0 || !k_ents[e].to) continue;
      if (++hop > k_hops) return -ELOOP;
      // the target is held as written, so it is canonicalized here and loses the leading
      // slash entry paths lack; the rebuilt line wears one, or the walk seeds from the cwd.
      uintptr_t tn = ai_lnk_canon(out, k_ents[e].to, nx + 1, sizeof nx - 1) + 1;
      nx[0] = '/';
      uintptr_t rest = inn - k;
      if (tn + 1 + rest >= sizeof nx) return -ENAMETOOLONG;
      if (rest) nx[tn++] = '/', memcpy(nx + tn, in + k, rest), tn += rest;
      memcpy(in, nx, inn = tn);
      again = true;
      break; }
    if (!again) return (intptr_t) n; } }

// a slot for a fresh entry: a retired one first, else the table doubles. -1 is a refusal.
static int k_ent_slot(void) {
  for (int i = 0; i < k_ents_n; i++) if (!k_ents[i].path) return i;
  if (k_ents_n == k_ents_cap) {
    int cap = k_ents_cap * 2;
    struct k_ent *t = kmallocw(b2w((uintptr_t) cap * sizeof *t));
    if (!t) return -1;
    memcpy(t, k_ents, (uintptr_t) k_ents_n * sizeof *t);
    kfree(k_ents);
    k_ents = t, k_ents_cap = cap; }
  return k_ents_n++; }

static char *k_strdup(char const *p, uintptr_t n) {
  char *q = kmallocw(b2w(n + 1));
  if (q) memcpy(q, p, n), q[n] = 0;
  return q; }

// free a dead, unheld entry's storage and retire the slot. unlink and the last close both
// land here, so an open fd keeps its file until it lets go.
static void k_ent_gc(int i) {
  struct k_ent *e = &k_ents[i];
  if (e->live || e->refs || !e->path) return;
  if (e->own) kfree(e->bytes);
  if (e->heap) kfree((void*) e->path);
  if (e->to) kfree((void*) e->to);
  *e = (struct k_ent) {0}; }

// a fresh live entry at canonical path p; the caller has asked k_parent_ok. -1 is memory.
static int k_create(char const *p, uintptr_t n, bool dir, uintptr_t mode) {
  char *q = k_strdup(p, n);
  if (!q) return -1;
  int i = k_ent_slot();
  if (i < 0) return kfree(q), -1;
  k_ents[i] = (struct k_ent) { .path = q, .bake = -1, .ms = k_clock_ms(),
                               .mode = mode, .own = true, .heap = true,
                               .dir = dir, .live = true };
  return i; }

// a directory can be a prefix: the initrd is flat, so a name baked paths lie under is a
// directory with no entry of its own -- synthesized, 0755, wearing its newest child's date.

// entry i's name under a prefix of pn bytes, NULL when it does not lie under it. an entry
// deeper than one level answers its next component, so a subdirectory is named by its paths.
static char const *k_entry(int i, char const *p, uintptr_t pn, uintptr_t *len) {
  if (!k_ents[i].live || !k_ents[i].path) return NULL;
  char const *q = k_ents[i].path;
  uintptr_t ql = strlen(q);
  if (pn) {
    if (ql <= pn + 1 || memcmp(q, p, pn) || q[pn] != '/') return NULL;
    q += pn + 1, ql -= pn + 1; }
  uintptr_t k = 0;
  while (k < ql && q[k] != '/') k++;
  return *len = k, q; }

// anything live under the prefix? -> and the newest date beneath it, the only
// date a synthesized directory can honestly wear.
static bool k_kids(char const *p, uintptr_t pn, uintptr_t *ms) {
  bool any = false;
  *ms = 0;
  for (int i = 0; i < k_ents_n; i++) {
    uintptr_t k;
    if (!k_entry(i, p, pn, &k)) continue;
    any = true;
    if (k_ents[i].ms > *ms) *ms = k_ents[i].ms; }
  return any; }

// is the canonical path a directory: the root always, an entry that says so, or a
// prefix something lives under.
static bool k_dirp(char const *p, uintptr_t pn) {
  if (!pn) return true;
  int i = k_find(p, pn);
  if (i >= 0) return k_ents[i].dir;
  uintptr_t junk;
  return k_kids(p, pn, &junk); }

// the parent a path wants to land in: 0 when it is a directory, else the errno
// the host would say (a hole ENOENT, a file in the way ENOTDIR).
static int k_parent_ok(char const *p, uintptr_t n) {
  uintptr_t dn = n;
  while (dn && p[dn - 1] != '/') dn--;
  if (dn) dn--;
  if (!dn) return 0;
  int i = k_find(p, dn);
  if (i >= 0) return k_ents[i].dir ? 0 : -ENOTDIR;
  uintptr_t junk;
  return k_kids(p, dn, &junk) ? 0 : -ENOENT; }

// make room for `need` bytes in entry i's heap copy, bringing the baked blob across on the
// first write. false is a refusal the caller must read and say; nothing is dropped quietly.
static bool k_fit(int i, uintptr_t need) {
  struct k_ent *e = &k_ents[i];
  if (!e->own) {
    struct k_file const *f = k_bake_row(e->bake);
    uintptr_t n = f->len, cap = n > need ? n : need;
    unsigned char *p = cap ? kmallocw(b2w(cap)) : NULL;
    if (cap && !p) return false;
    if (n) memcpy(p, f->bytes, n);
    e->bytes = p, e->len = n, e->cap = cap, e->own = true;
    return true; }
  if (e->cap >= need) return true;
  uintptr_t cap = e->cap ? e->cap : 64;
  while (cap < need) cap *= 2;
  unsigned char *p = kmallocw(b2w(cap));
  if (!p) return false;
  if (e->len) memcpy(p, e->bytes, e->len);
  kfree(e->bytes);
  e->bytes = p, e->cap = cap;
  return true; }

// entry i's bytes <- the pen, at the open of a read. memory refusing leaves the last
// content standing: a stale number is answerable, an open that failed here would not be.
static void k_vt_read(int i, int slot) {
  // serial-only: no console to ask, so the file reads empty rather than the last write
  if (!kcb || slot == 4) { k_ents[i].len = 0; return; }   // ..and the lift is written, never read
  // the colours come off the pen, the scale off the paper
  unsigned v = slot == 3 ? kfb.scale : slot == 1 ? kcb->def_fg : kcb->def_bg;
  char d[4]; int n = 0;
  if (v >= 100) d[n++] = (char) ('0' + v / 100);
  if (v >= 10)  d[n++] = (char) ('0' + v / 10 % 10);
  d[n++] = (char) ('0' + v % 10);
  d[n++] = '\n';
  if (!k_fit(i, (uintptr_t) n)) return;
  memcpy(k_ents[i].bytes, d, (uintptr_t) n);
  k_ents[i].len = (uintptr_t) n; }

// the pen <- entry i's bytes, at the close of a write. a leading number is the whole
// grammar; no number, or one past the palette's 256, leaves the console alone.
static void k_vt_write(int i, int slot) {
  unsigned char const *b = k_ents[i].bytes;
  uintptr_t len = k_ents[i].len, j = 0;
  // the lift takes the bytes as a path, less a trailing newline, and needs no console
  if (slot == 4) {
    while (len && (b[len - 1] == '\n' || b[len - 1] == '\r')) len--;
    if (len) k_lift_ask(b, len);
    return; }
  if (!kcb) return;
  unsigned v = 0;
  while (j < len && b[j] >= '0' && b[j] <= '9' && v < 256) v = v * 10 + (unsigned) (b[j++] - '0');
  if (!j || v > 255) return;
  if (slot == 3) { k_vt_rescale(v); return; }   // a scale is a new grid, not a new pen
  cb_recolor(kcb, slot == 1 ? (uint8_t) v : kcb->def_fg,
                  slot == 1 ? kcb->def_bg : (uint8_t) v); }

// --- /proc's live rows ------------------------------------------------------------
// filled at the open, off state only this side of the door can see: the kernel's own free
// list and the collector's counters. `key value` lines, words throughout.
static int k_proc_slot(char const *p, uintptr_t n) {
  if (n == sizeof k_pmem - 1 && !memcmp(p, k_pmem, n)) return 1;
  if (n == sizeof k_pgauge - 1 && !memcmp(p, k_pgauge, n)) return 2;
  if (n == sizeof k_pcmd - 1 && !memcmp(p, k_pcmd, n)) return 3;
  return 0; }

static int k_dec(char *b, int at, uintptr_t v) {
  char d[24]; int n = 0;
  do d[n++] = (char) ('0' + v % 10); while (v /= 10);
  while (n) b[at++] = d[--n];
  return at; }
static int k_row(char *b, int at, char const *k, uintptr_t v) {
  while (*k) b[at++] = *k++;
  b[at++] = ' ';
  at = k_dec(b, at, v);
  b[at++] = '\n';
  return at; }

static int k_meminfo(char *b) {
  uintptr_t free = 0, blocks = 0, big = 0;
  for (struct mem const *m = kmem; m; m = m->next)
    free += m->len, blocks++, big = m->len > big ? m->len : big;
  int at = k_row(b, 0, "ram-words", kram_words);
  at = k_row(b, at, "free-words", free);
  at = k_row(b, at, "free-blocks", blocks);
  at = k_row(b, at, "free-largest", big);
  // heap bytes only: a baked row costs the image, not the RAM this file is about.
  uintptr_t ents = 0, bytes = 0;
  for (int i = 0; i < k_ents_n; i++)
    if (k_ents[i].live) ents++, bytes += k_ents[i].own ? k_ents[i].cap : 0;
  at = k_row(b, at, "fs-entries", ents);
  return k_row(b, at, "fs-heap-bytes", bytes); }

// love/love.c's lvm_gauge roster, spelled out: the same sixteen, named rather than indexed.
static int k_gauge(char *b, struct ai const *g) {
  int at = k_row(b, 0, "pool-words", g->len);
  at = k_row(b, at, "heap-words", (uintptr_t) (g->hp - ptr(g)));
  at = k_row(b, at, "stack-words", (uintptr_t) (ptr(g) + g->len - g->sp));
  at = k_row(b, at, "collections", g->n_gc);
  at = k_row(b, at, "minors", g->n_minor);
  at = k_row(b, at, "pool-peak", g->max_len);
  at = k_row(b, at, "heap-peak", g->max_heap);
  at = k_row(b, at, "seen-words", g->n_seen);
  at = k_row(b, at, "evac-words", g->n_evac);
  at = k_row(b, at, "old-words", (uintptr_t) (g->major_hp - g->major_base));
  at = k_row(b, at, "major-cap", g->major_pool ? 2 * g->major_len : 0);
  at = k_row(b, at, "rem-miss", g->rem_miss);
  at = k_row(b, at, "rem-peak", g->rem_hi);
  at = k_row(b, at, "resizes", g->n_resize);
  at = k_row(b, at, "minor-peak", g->minor_hi);
  return k_row(b, at, "major-peak", g->major_hi); }

// the boot line as love spells it: the program word, then the raw boot line, the way linux
// writes its own, so the quoting a reader sees is the quoting the boot handed over.
static int k_bootline(char *b) {
  int at = 0;
  for (char const *k = "love"; *k; k++) b[at++] = *k;
  if (kboot.cmdline[0]) {
    b[at++] = ' ';
    for (char const *s = kboot.cmdline; *s; s++) b[at++] = *s; }
  b[at++] = '\n';
  return at; }

// entry i's bytes <- the machine, at the open of a read; a refusal leaves the last content
// standing, a stale row being answerable where a failed open is not.
static void k_proc_read(int i, int slot) {
  if (slot == 2 && !ai_system) return;          // no process to ask; meminfo is ours alone
  char b[768];
  int n = slot == 1 ? k_meminfo(b) : slot == 3 ? k_bootline(b) : k_gauge(b, ai_system);
  if (!k_fit(i, (uintptr_t) n)) return;
  memcpy(k_ents[i].bytes, b, (uintptr_t) n);
  k_ents[i].len = (uintptr_t) n; }

static intptr_t ram_readn(int fd, unsigned char *dst, uintptr_t n) {
  struct k_fh *h = k_fh(fd);
  if (!h) return -1;
  uintptr_t len;
  unsigned char const *p = k_blob(h->i, &len);
  // the end, never 0: a file does not grow under its reader, so 0 would park the scheduler
  if (h->pos >= len) return -1;
  uintptr_t k = len - h->pos;
  if (k > n) k = n;
  memcpy(dst, p + h->pos, k);
  h->pos += k;
  return (intptr_t) k; }

static intptr_t ram_writen(int fd, unsigned char const *src, uintptr_t n) {
  struct k_fh *h = k_fh(fd);
  if (!h || !h->w) return -1;                  // read-only: gone, not silently taken
  if (!n) return 0;
  if (!k_fit(h->i, h->pos + n)) return -1;
  struct k_ent *e = &k_ents[h->i];
  // a gap (a truncate under an append fd) reads as zeros, never the last tenant's bytes
  if (h->pos > e->len)
    memset(e->bytes + e->len, 0, h->pos - e->len);
  memcpy(e->bytes + h->pos, src, n);
  h->pos += n;
  if (h->pos > e->len) e->len = h->pos;
  e->ms = k_clock_ms();
  return (intptr_t) n; }

static bool ram_ready(int fd) { return true; }

static void ram_close(int fd) {
  struct k_source *s = k_source(fd);
  if (!s) return;
  struct k_fh *h = s->state;
  if (h && h->vt && h->w) k_vt_write(h->i, h->vt);   // the write lands when the writer is done
  if (h && k_ents[h->i].refs) k_ents[h->i].refs--, k_ent_gc(h->i);
  kfree(s->state);
  *s = (struct k_source) {0}; }               // and the row is free again

// the lowest free row at or past the boot rows -- POSIX's rule, which scripts lean on. a row
// is free when it carries no method at all. the floor is F_DUPFD's; every caller else passes 0.
static int k_fd_free_at(int at) {
  int lo = at > (int) countof(k_boot) ? at : (int) countof(k_boot);
  for (int i = lo; i < k_sources_n; i++)
    if (!k_row_live(i)) return i;
  return k_sources_n > lo ? k_sources_n : lo; }
static int k_fd_free(void) { return k_fd_free_at(0); }

// open a path -> an fd or a negative errno. m is r read, w truncate, a append; w and a create
// an absent path whose parent is a directory, for r absence stays absence. a directory does
// not open: readdir is its read door. the love doors flatten the errno in the marshaling.
ai_noinline int k_fs_open(char const *p, uintptr_t pn, char m) {
  if (m != 'r' && m != 'w' && m != 'a') return -EINVAL;
  if (!k_fs_init()) return -ENOMEM;
  char cp[256];
  intptr_t cn = k_walk(p, pn, cp, true);
  if (cn < 0) return (int) cn;
  if (k_ro(cp, (uintptr_t) cn)) {                // the tree: read only, and the mount a directory
    if (m != 'r') return -EROFS;
    if (cn == (intptr_t) k_tree_n) return -EISDIR; }
  // the ramfs does not read its own mode bits, so 0444 is a label and this is the refusal
  if (k_proc_slot(cp, (uintptr_t) cn) && m != 'r') return -EROFS;
  if (!cn) return -EISDIR;                       // the root is a directory
  { int dv = k_dev_slot(cp, (uintptr_t) cn);     // no handle, no bytes, no entry
    if (dv) {
      int dfd = k_fd_free();
      struct k_source *ds = k_source_open(dfd);
      if (!ds) return -ENOMEM;
      // null keeps no readn (k_row_read answers end for want of one) but still says
      // ready: a source that never answers ready parks its reader for good.
      *ds = dv == 2 ? (struct k_source) { .readn = k_zero_readn, .ready = k_dev_ready }
                    : (struct k_source) { .writen = k_null_writen, .ready = k_dev_ready };
      return dfd; } }
  int i = k_find(cp, (uintptr_t) cn);
  if (i >= 0 && k_ents[i].dir) return -EISDIR;
  bool made = false;
  if (i < 0) {
    // 'r' misses stay one k_find, the load path's probe lane; only a create pays k_dirp,
    // so a file never shadows a synthesized directory.
    if (m == 'r') return -ENOENT;
    if (k_dirp(cp, (uintptr_t) cn)) return -EISDIR;
    int e = k_parent_ok(cp, (uintptr_t) cn);
    if (e) return e;
    if ((i = k_create(cp, (uintptr_t) cn, false, 0644)) < 0) return -ENOMEM;
    made = true; }
  int fd = k_fd_free();
  struct k_fh *h = kmallocw(b2w(sizeof *h));
  struct k_source *s = h ? k_source_open(fd) : NULL;   // the grow door; NULL is no memory
  if (!s) {
    kfree(h);
    // an open that refuses leaves the tree as it found it -- a file it minted goes too
    if (made) k_ents[i].live = false, k_ent_gc(i);
    return -ENOMEM; }
  // the truncate lands last, past every way this can still fail (same law).
  uintptr_t len = 0;
  struct k_ent *e = &k_ents[i];
  int vt = k_vt_slot(cp, (uintptr_t) cn);
  if (vt && m == 'r') k_vt_read(i, vt);          // the pen, as of this open
  int ps = m != 'r' ? 0 : k_proc_slot(cp, (uintptr_t) cn);
  if (ps) k_proc_read(i, ps);                    // and the machine, as of this open
  if (m == 'w') e->own = true, e->len = 0, e->ms = k_clock_ms();
  if (m == 'a') k_blob(i, &len);
  e->refs++;
  *h = (struct k_fh) { .i = i, .vt = vt, .pos = len, .w = m != 'r' };
  *s = (struct k_source) { .readn = ram_readn, .writen = ram_writen,
                           .ready = ram_ready, .close = ram_close, .state = h };
  return fd; }
// the open/close nifs are inle/posix.c's: its open(2)/close(2) land in inle/sys.c's arms,
// so the ramfs answers the same door and a directory opens as a dents row.

// --- the file nifs: stat, readdir, lseek, openfd ---------------------------
// doc/misc/posix.md's conventions exactly: kore reads these shapes and a wrong one is silent
#define k_mode_file 0100000            // (& mode 61440) = 32768: a regular file
#define k_mode_dir  0040000            //                = 16384: a directory
#define k_mode_lnk  0120000            //                = 40960: a symlink

// (stat path) -> (size mtime-ms mode ns) | (). ns is the ms date times a million, this
// clock's last hand being the millisecond. ino, nlink, uid and dev are inle/sys.c's to invent.
struct k_st { uintptr_t size, ms, mode; };

// -> 0, or -ENOENT. a synthesized directory -- a prefix with children but no entry of its
// own, and the root -- answers like any other, which is why this fills a struct and not an
// entry index: it has no row to point at.
ai_noinline int k_fs_stat(char const *p, uintptr_t pn, struct k_st *st, bool follow) {
  char cp[256];
  intptr_t cn;
  if (!k_fs_init()) return -ENOMEM;
  if ((cn = k_walk(p, pn, cp, follow)) < 0) return (int) cn;
  int i = k_find(cp, (uintptr_t) cn);
  uintptr_t kid;
  *st = (struct k_st) { 0, 0, 0 };
  // lstat, the only reason the walk left the last name alone: the link itself, sized by
  // its target the way stat(2) has it.
  if (!follow && i >= 0 && k_ents[i].to)
    return *st = (struct k_st) { strlen(k_ents[i].to), k_ents[i].ms,
                                 k_mode_lnk | 0777 }, 0;
  if (i >= 0 && !k_ents[i].dir) {
    int vt = k_vt_slot(cp, (uintptr_t) cn);
    if (vt) k_vt_read(i, vt);                        // so a size is the pen's, not the last read's
    int ps = k_proc_slot(cp, (uintptr_t) cn);
    if (ps) k_proc_read(i, ps);
    k_blob(i, &st->size), st->ms = k_ents[i].ms,
    st->mode = k_mode_file | k_ents[i].mode; }
  else if (i >= 0) {
    st->mode = k_mode_dir | k_ents[i].mode;     // an explicit directory: its own date,
    st->ms = k_ents[i].ms;                      // or its newest child's if newer
    if (k_kids(cp, (uintptr_t) cn, &kid) && kid > st->ms) st->ms = kid; }
  else if (k_kids(cp, (uintptr_t) cn, &st->ms) || !cn) st->mode = k_mode_dir | 0755;
  else return -ENOENT;
  return 0; }

// --- rung 4: pipes, and the fd plumbing over them ---------------------------
// a pipe is a k_source pair over one byte queue in the kernel heap: the read end answers 0
// while a writer is open and -1 when the last one closes, which is what the scheduler parks
// on, and each end counts its holders so the queue frees when both reach zero. the queue
// grows rather than capping: the writer's zputc retries once and then drops the byte.
struct k_pipe { unsigned char *buf; uintptr_t cap, rp, wp; int rrefs, wrefs; };

static struct k_pipe *k_pipe_of(int fd) {
  struct k_source *s = k_source(fd);
  return s ? s->state : NULL; }

static intptr_t pipe_readn(int fd, unsigned char *dst, uintptr_t n) {
  struct k_pipe *p = k_pipe_of(fd);
  if (!p) return -1;
  uintptr_t a = p->wp - p->rp;
  if (!a) return p->wrefs ? 0 : -1;             // quiet with a writer: park; else the end
  if (a > n) a = n;
  memcpy(dst, p->buf + p->rp, a);
  p->rp += a;
  if (p->rp == p->wp) p->rp = p->wp = 0;        // drained: the queue restarts at the front
  return (intptr_t) a; }

static intptr_t pipe_writen(int fd, unsigned char const *src, uintptr_t n) {
  struct k_pipe *p = k_pipe_of(fd);
  // no readers is gone, not busy; with no SIGPIPE the writer only learns if it looks, so
  // the run is dropped as the host drops one on EPIPE and a `yes` into a dead pipe spins.
  if (!p || !p->rrefs) return -1;
  if (p->wp + n > p->cap) {
    if (p->rp) {                                // compact before growing
      memmove(p->buf, p->buf + p->rp, p->wp - p->rp);
      p->wp -= p->rp, p->rp = 0; }
    if (p->wp + n > p->cap) {
      uintptr_t cap = p->cap ? p->cap : 4096;
      while (cap < p->wp + n) cap *= 2;
      unsigned char *b = kmallocw(b2w(cap));
      if (!b) return -1;                        // memory refusing, said out loud
      if (p->wp) memcpy(b, p->buf, p->wp);
      kfree(p->buf);
      p->buf = b, p->cap = cap; } }
  memcpy(p->buf + p->wp, src, n);
  p->wp += n;
  return (intptr_t) n; }

static bool pipe_rready(int fd) {
  struct k_pipe *p = k_pipe_of(fd);
  return p && (p->wp > p->rp || !p->wrefs); }   // bytes, or the end -- both wake a reader

static void pipe_free(struct k_pipe *p) {
  if (p->rrefs || p->wrefs) return;
  kfree(p->buf);
  kfree(p); }

static void pipe_rclose(int fd) {
  struct k_pipe *p = k_pipe_of(fd);
  struct k_source *s = k_source(fd);
  if (s) *s = (struct k_source) {0};
  if (p) p->rrefs--, pipe_free(p); }

static void pipe_wclose(int fd) {
  struct k_pipe *p = k_pipe_of(fd);
  struct k_source *s = k_source(fd);
  if (s) *s = (struct k_source) {0};
  if (p) p->wrefs--, pipe_free(p); }

// a duped row that carries no state of its own (a console twin) still owes
// k_fd_free a way back to empty.
static void k_row_zero(int fd) {
  struct k_source *s = k_source(fd);
  if (s) *s = (struct k_source) {0}; }

// clone src's row into a fresh fd. a pipe end shares the queue and bumps its side's count; a
// ramfs fd clones the handle, so the offset diverges where POSIX shares it; a boot twin gets
// k_row_zero so its close frees the row.
ai_noinline static int k_dup_row(int src, int at) {
  struct k_source *s = k_source(src);
  if (!s || !(s->readn || s->writen || s->putc)) return -1;
  int fd = k_fd_free_at(at);
  struct k_fh *h = NULL;
  if (s->readn == ram_readn) {
    struct k_fh *o = s->state;
    if (!o || !(h = kmallocw(b2w(sizeof *h)))) return -1;
    *h = *o; }
  struct k_source *t = k_source_open(fd);
  if (!t) { kfree(h); return -1; }
  s = k_source(src);                            // the grow may have moved the table
  *t = *s;
  if (h) t->state = h, k_ents[h->i].refs++;
  else if (s->readn == pipe_readn) ((struct k_pipe*) s->state)->rrefs++;
  else if (s->writen == pipe_writen) ((struct k_pipe*) s->state)->wrefs++;
  else if (!t->close) t->close = k_row_zero;
  return fd; }
// inle/sys.c's doors over the same motions: fcntl's F_DUPFD (at = the floor)
// and dup3. src == dst is dup3's own refusal; the love face answers () there.
long k_fd_dup(int src, int at) {
  if (at < 0) return -EINVAL;
  int fd = k_dup_row(src, at);
  return fd < 0 ? -EBADF : fd; }
long k_fd_dup3(int src, int dst) {
  if (src == dst || dst < 0) return -EINVAL;
  int nfd = k_dup_row(src, 0);
  if (nfd < 0) return -EBADF;
  struct k_source *d = k_source_open(dst);
  if (!d) { k_row_close(nfd); k_row_zero(nfd); return -ENOMEM; }
  if (d->close) d->close(dst);
  d = k_source(dst);                            // close zeroes through the live table
  struct k_source *n = k_source(nfd);
  *d = *n;
  *n = (struct k_source) {0};                   // the temp row retires; its state moved whole
  return dst; }

// the row mechanics of pipe(2), g-free: two rows over one queue. inle/sys.c's
// pipe2 arm calls it with the caller's own int pair.
long k_fd_pipe(int fds[2]) {
  struct k_pipe *p = kmallocw(b2w(sizeof *p));
  if (!p) return -ENOMEM;
  *p = (struct k_pipe) { .rrefs = 1, .wrefs = 1 };
  int rfd = k_fd_free();
  struct k_source *rs = k_source_open(rfd);
  if (rs) *rs = (struct k_source) { .readn = pipe_readn, .ready = pipe_rready,
                                    .close = pipe_rclose, .state = p };
  int wfd = rs ? k_fd_free() : -1;
  struct k_source *ws = rs ? k_source_open(wfd) : NULL;
  if (!ws) {
    if (rs) k_row_zero(rfd);
    kfree(p);
    return -ENOMEM; }
  *ws = (struct k_source) { .writen = pipe_writen, .close = pipe_wclose, .state = p };
  fds[0] = rfd, fds[1] = wfd;
  return 0; }

// --- directory rows: opendir(2)'s door, inle/sys.c's only caller ------------
// a directory opens as a row with a close and a dents cursor: read(2) on it is EISDIR. the
// cursor counts the names handed out and the scan re-walks, so no state outlives the call.
struct k_dh { uintptr_t pn; int at; char p[256]; };
static void k_dir_close(int fd) {
 struct k_source *s = k_source(fd);
 if (!s) return;
 kfree(s->state);
 *s = (struct k_source) {0}; }

long k_fs_opendir(char const *p, uintptr_t pn) {
 char cp[256];
 intptr_t cn;
 if (!k_fs_init()) return -ENOMEM;
 if ((cn = k_walk(p, pn, cp, true)) < 0) return cn;
 if (!k_dirp(cp, (uintptr_t) cn))
  return k_find(cp, (uintptr_t) cn) >= 0 ? -ENOTDIR : -ENOENT;
 int fd = k_fd_free();
 struct k_dh *h = kmallocw(b2w(sizeof *h));
 struct k_source *s = h ? k_source_open(fd) : NULL;
 if (!s) { kfree(h); return -ENOMEM; }
 h->pn = (uintptr_t) cn, h->at = 0;
 memcpy(h->p, cp, (uintptr_t) cn);
 *s = (struct k_source) { .close = k_dir_close, .state = h };
 return fd; }

// linux_dirent64: 19 header bytes then the name, NUL kept, the record rounded
// to 8 -- so every record stays 8-aligned in the caller's buffer.
struct k_dent { unsigned long ino; long off; unsigned short reclen;
                unsigned char type; char name[]; };
long k_fd_dents(int fd, void *buf, long cap) {
 if (!k_row_live(fd)) return -EBADF;
 struct k_source *s = k_source(fd);
 if (s->close != k_dir_close) return -ENOTDIR;
 struct k_dh *h = s->state;
 long off = 0;
 int walked = 0;                               // distinct names passed this scan
 for (int i = 0; i < k_ents_n; i++) {
  uintptr_t k;
  char const *e = k_entry(i, h->p, h->pn, &k);
  if (!e) continue;
  bool seen = false;                          // one name per entry, k_readdir's rule
  for (int j = 0; j < i && !seen; j++) {
   uintptr_t k2;
   char const *e2 = k_entry(j, h->p, h->pn, &k2);
   seen = e2 && k2 == k && !memcmp(e, e2, k); }
  if (seen) continue;
  if (walked++ < h->at) continue;             // already handed out
  long rl = (long) ((19 + k + 1 + 7) & ~(uintptr_t) 7);
  if (off + rl > cap) return off ? off : -EINVAL;
  struct k_dent *d = (struct k_dent*) ((char*) buf + off);
  d->ino = (unsigned long) i + 1;             // fabricated: the first carrier's row
  d->off = h->at + 1;
  d->reclen = (unsigned short) rl;
  d->type = (e[k] == '/' || k_ents[i].dir) ? 4 : 8;   // DT_DIR : DT_REG
  memcpy(d->name, e, k);
  d->name[k] = 0;
  off += rl;
  h->at++; }
 return off; }

// fstat(2)'s row face: the ramfs handle answers its entry, a pipe end is a fifo, a
// directory row its tree, the boot rows a character device. struct stat is inle/sys.c's.
long k_fd_stat(int fd, struct k_st *st) {
  if (!k_row_live(fd)) return -EBADF;
  struct k_source *s = k_source(fd);
  *st = (struct k_st) { 0, 0, 0 };
  if (s->readn == ram_readn) {
    struct k_fh *h = s->state;
    k_blob(h->i, &st->size);
    st->ms = k_ents[h->i].ms;
    st->mode = k_mode_file | k_ents[h->i].mode;
    return 0; }
  if (s->readn == pipe_readn || s->writen == pipe_writen) {
    st->mode = 0010000 | 0600;                  // a fifo
    return 0; }
  if (s->close == k_dir_close) {
    struct k_dh *h = s->state;
    int i = k_find(h->p, h->pn);
    st->mode = k_mode_dir | (i >= 0 ? k_ents[i].mode : 0755);
    st->ms = i >= 0 ? k_ents[i].ms : 0;
    uintptr_t kid;
    if (k_kids(h->p, h->pn, &kid) && kid > st->ms) st->ms = kid;
    return 0; }
  st->mode = 0020000 | 0620;                    // the console twins: a character device
  return 0; }

// (getpid _) -> the running task's pid, a charm; the main task reads 0. inle/main.c's
// getpid nif branches here on a negative osv, its own answer being the constant 1.
lvm(k_lvm_getpid) {
  Sp[0] = putcharm(k_cur_pid(g));
  ai_musttail return Next(1); }

// --- rung 5: the disk -- the block door apps/fat.l rides, driven by inle/blk.c. DMA
// rides a love string's own heap bytes: nothing allocates between post and completion, so
// the collector cannot move the buffer under the device.
// (disk _)         -> the sector count, 0 when no disk.
// (disk-read l n)  -> a string of n*512 bytes off sector l | ().
// (disk-write l s) -> the sectors written | () (s must be whole sectors).
void k_blk_init(void *dma);
uint64_t k_blk_sectors(void);
int k_blk_rw(uint64_t lba, uint32_t n, void *buf, int wr);

static lvm(lvm_disk) {
  Sp[0] = putcharm((intptr_t) k_blk_sectors());
  ai_musttail return Next(1); }

ai_noinline static struct ai *k_disk_read(struct ai *g) {
  word lw = g->sp[0], nw = g->sp[1];
  intptr_t lba = (lw & 1) ? getcharm(lw) : -1,
           n   = (nw & 1) ? getcharm(nw) : -1;
  if (lba < 0 || n <= 0 || n > 1 << 24) return g->sp[1] = ZeroPoint, g->sp += 1, g;
  if (!ai_ok(g = str0(g, (uintptr_t) n * 512))) return g;   // OOM: the wrapper ghelps
  if (k_blk_rw((uint64_t) lba, (uint32_t) n, txt(g->sp[0]), 0) < 0)
    g->sp[0] = ZeroPoint;
  return g->sp[2] = g->sp[0], g->sp += 2, g; }

static lvm(lvm_disk_read) {
 LvmCall(g, k_disk_read) }

ai_noinline static word k_disk_write(word lw, word sw) {
 intptr_t lba = (lw & 1) ? getcharm(lw) : -1;
 if (lba < 0 || !strp(sw)) return ZeroPoint;
 struct ai_str *s = (struct ai_str*) sw;
 if (!s->len || s->len % 512) return ZeroPoint;
 if (k_blk_rw((uint64_t) lba, (uint32_t) (s->len / 512), s->bytes, 1) < 0)
  return ZeroPoint;
 return putcharm((intptr_t) (s->len / 512)); }

static lvm(lvm_disk_write) {
  Sp[1] = k_disk_write(Sp[0], Sp[1]);
  ai_musttail return Nextp(1, 1); }

// (fetch url path): the page's network where a seat has one (inle/wasm) -- the bytes at
// URL laid as the ramfs file at PATH, 0 or -errno; metal has no door and says so
__attribute__((weak)) long k_fetch(char const *url, uintptr_t un, char const *path, uintptr_t pn) {
  return (void) url, (void) un, (void) path, (void) pn, -ENOSYS; }
ai_noinline static word k_lvm_fetch(word uw, word pw) {
  if (!strp(uw) || !strp(pw)) return ZeroPoint;
  struct ai_str *u = (struct ai_str*) uw, *p = (struct ai_str*) pw;
  return putcharm((intptr_t) k_fetch(u->bytes, u->len, p->bytes, p->len)); }
static lvm(lvm_fetch) {
  Sp[1] = k_lvm_fetch(Sp[0], Sp[1]);
  ai_musttail return Nextp(1, 1); }

// (kexec path cmd): boot the ramfs module at path with cmd as its boot line, in place of this
// one -- inle/wasm can, metal cannot yet. answers only on refusal, -errno.
__attribute__((weak)) long k_kexec(char const *p, uintptr_t pn, char const *cmd, uintptr_t cn) {
  return (void) p, (void) pn, (void) cmd, (void) cn, -ENOSYS; }
ai_noinline static word k_lvm_kexec(word pw, word cw) {
  if (!strp(pw) || !strp(cw)) return ZeroPoint;
  struct ai_str *p = (struct ai_str*) pw, *c = (struct ai_str*) cw;
  return putcharm((intptr_t) k_kexec(p->bytes, p->len, c->bytes, c->len)); }
static lvm(lvm_kexec) {
  Sp[1] = k_lvm_kexec(Sp[0], Sp[1]);
  ai_musttail return Nextp(1, 1); }

// the bake door: the heap as image bytes, written whole to one ramfs file
static void k_bake(struct ai *g, char const *path) {
  uintptr_t n = 0;
  struct ai_image_bad bad = {0};
  void *b = ai_image_save(g, &n, &bad);
  int fd = b ? k_fs_open(path, strlen(path), 'w') : -1;
  long w = fd < 0 ? -1 : k_fd_write(fd, b, (long) n);
  if (fd >= 0) k_fd_close(fd);
  if (w == (long) n) kputs("; inle -- baked\n");
  else {                                          // the codec's step and its offending words
    kputs("; inle -- bake refused: why "); kputn((uintptr_t) bad.why, 10);
    kputs(" n "); kputn((uintptr_t) bad.n, 10);
    for (int i = 0; i < 3 * bad.n && i < 6; i++) { kputs(" "); kputn(bad.q[i], 16); }
    kputs(" fd "); kputn((uintptr_t) fd, 10); kputs(" w "); kputn((uintptr_t) w, 10); kputs("\n"); }
  k_reset(); }

// --- the SVM spike (x64 only; inle/x64/svm.c). (svm ()) is the capability, (svm-run ())
// runs one guest, answering (exitcode rax rip) or ().
#if defined(__x86_64__)

static lvm(lvm_svm) {
  Sp[0] = k_svm_ok() ? putcharm(1) : ZeroPoint;
  ai_musttail return Next(1); }

ai_noinline static struct ai *k_svm_run(struct ai *g) {
  uint64_t code = 0, rax = 0, rip = 0;
  if (!k_svm_ok()) return g->sp[0] = ZeroPoint, g;
  // the spike's pages ride a love string's own bytes, safe for blk.c's reason: nothing
  // allocates between the carve and the vmrun, so the VMCB cannot move under the CPU.
  if (!ai_ok(g = str0(g, k_svm_need()))) return g;      // OOM: the wrapper ghelps
  if (k_svm_spike(txt(g->sp[0]), &code, &rax, &rip) < 0)
    return g->sp[1] = ZeroPoint, g->sp += 1, g;
  if (!ai_ok(g = ai_have(g, 3 * Width(struct ai_chain)))) return g;
  struct ai_chain *c = ini_chain((struct ai_chain*) bump(g, Width(struct ai_chain)),
                                 putcharm((intptr_t) rip), ZeroPoint);
  c = ini_chain((struct ai_chain*) bump(g, Width(struct ai_chain)),
                putcharm((intptr_t) rax), word(c));
  c = ini_chain((struct ai_chain*) bump(g, Width(struct ai_chain)),
                putcharm((intptr_t) code), word(c));
  return g->sp[1] = word(c), g->sp += 1, g; }

static lvm(lvm_svm_run) {
  LvmCall(g, k_svm_run) }

// ..and its Intel twin (inle/x64/vmx.c). (vmx-run ()) answers four numbers where the SVM
// door answers three: the last is the VM-instruction error, all a refused entry has to say.

static lvm(lvm_vmx) {
  Sp[0] = k_vmx_ok() ? putcharm(1) : ZeroPoint;
  ai_musttail return Next(1); }

ai_noinline static struct ai *k_vmx_run(struct ai *g) {
  uint64_t reason = 0, rax = 0, rip = 0, err = 0;
  if (!k_vmx_ok()) return g->sp[0] = ZeroPoint, g;
  if (!ai_ok(g = str0(g, k_vmx_need()))) return g;       // OOM: the wrapper ghelps
  if (k_vmx_spike(txt(g->sp[0]), &reason, &rax, &rip, &err) < 0)
    return g->sp[1] = ZeroPoint, g->sp += 1, g;
  if (!ai_ok(g = ai_have(g, 4 * Width(struct ai_chain)))) return g;
  struct ai_chain *c = ini_chain((struct ai_chain*) bump(g, Width(struct ai_chain)),
                                 putcharm((intptr_t) err), ZeroPoint);
  c = ini_chain(bump(g, Width(struct ai_chain)), putcharm(rip), word(c));
  c = ini_chain(bump(g, Width(struct ai_chain)), putcharm(rax), word(c));
  c = ini_chain(bump(g, Width(struct ai_chain)), putcharm(reason), word(c));
  return g->sp[1] = word(c), g->sp += 1, g; }
static lvm(lvm_vmx_run) {
  LvmCall(g, k_vmx_run) }
#endif

// --- rung 2: the writable tree -- mkdir, rmdir, unlink, rename, chdir/cwd, chmod, utime.
// doc/misc/posix.md's conventions: an effect answers 0 | -errno (the host's numbers negated)
// | EINVAL on misuse, cwd the string | (). the environment is a tablet in the boot text.

// --- the path faces ------------------------------------------------------
// k_fs_* take (bytes, len) and answer 0 or a negative errno, as k_fd_* and k_parent_ok do --
// the one sign __ai_inle owes its caller, so inle/sys.c hands these out with no flip.
// ai_noinline is load-bearing: cp[256] in an lvm's own frame would block its musttail.
ai_noinline int k_fs_mkdir(char const *p, uintptr_t pn, uintptr_t mode) {
  char cp[256];
  intptr_t cn;
  if (!k_fs_init()) return -ENOMEM;
  if ((cn = k_walk(p, pn, cp, false)) < 0) return (int) cn;
  if (k_ro(cp, (uintptr_t) cn)) return -EROFS;
  uintptr_t junk;
  if (!cn || k_find(cp, (uintptr_t) cn) >= 0 || k_kids(cp, (uintptr_t) cn, &junk))
    return -EEXIST;
  int e = k_parent_ok(cp, (uintptr_t) cn);
  if (e) return e;
  return k_create(cp, (uintptr_t) cn, true, mode) < 0 ? -ENOMEM : 0; }

ai_noinline int k_fs_rmdir(char const *p, uintptr_t pn) {
  char cp[256];
  intptr_t cn;
  if (!k_fs_init()) return -ENOMEM;
  if ((cn = k_walk(p, pn, cp, false)) < 0) return (int) cn;
  if (k_ro(cp, (uintptr_t) cn)) return -EROFS;
  if (!cn) return -EBUSY;                         // the root stays
  int i = k_find(cp, (uintptr_t) cn);
  if (i >= 0 && !k_ents[i].dir) return -ENOTDIR;
  uintptr_t junk;
  if (k_kids(cp, (uintptr_t) cn, &junk)) return -ENOTEMPTY;
  if (i < 0) return -ENOENT;
  k_ents[i].live = false;
  k_ent_gc(i);
  return 0; }

ai_noinline int k_fs_unlink(char const *p, uintptr_t pn) {
  char cp[256];
  intptr_t cn;
  if (!k_fs_init()) return -ENOMEM;
  if ((cn = k_walk(p, pn, cp, false)) < 0) return (int) cn;
  if (k_ro(cp, (uintptr_t) cn)) return -EROFS;
  int i = cn ? k_find(cp, (uintptr_t) cn) : -1;
  if (i < 0) return k_dirp(cp, (uintptr_t) cn) ? -EISDIR : -ENOENT;
  if (k_ents[i].dir) return -EISDIR;
  k_ents[i].live = false;                        // an open fd keeps the bytes; the
  k_ent_gc(i);                                   // last close frees them
  return 0; }

// (symlink target path). the target is stored as given, the way readlink(2) owes it back,
// and canonicalized against the link's own place only when k_walk follows it.
ai_noinline int k_fs_symlink(char const *t, uintptr_t tn, char const *p, uintptr_t pn) {
  char cp[256];
  intptr_t cn;
  if (!k_fs_init()) return -ENOMEM;
  if (!tn || tn >= 256) return -ENAMETOOLONG;
  if ((cn = k_walk(p, pn, cp, false)) < 0) return (int) cn;
  if (k_ro(cp, (uintptr_t) cn)) return -EROFS;
  uintptr_t junk;
  if (!cn || k_find(cp, (uintptr_t) cn) >= 0 || k_kids(cp, (uintptr_t) cn, &junk))
    return -EEXIST;
  int e = k_parent_ok(cp, (uintptr_t) cn);
  if (e) return e;
  char *q = k_strdup(t, tn);
  if (!q) return -ENOMEM;
  int i = k_create(cp, (uintptr_t) cn, false, 0777);
  if (i < 0) return kfree(q), -ENOMEM;
  k_ents[i].to = q;
  return 0; }

// (readlink path): the target, unfollowed and untruncated -- the byte count back, as
// readlink(2) answers it, and -EINVAL where the path is not a link at all.
ai_noinline intptr_t k_fs_readlink(char const *p, uintptr_t pn, char *b, uintptr_t n) {
  char cp[256];
  intptr_t cn;
  if (!k_fs_init()) return -ENOMEM;
  if ((cn = k_walk(p, pn, cp, false)) < 0) return cn;
  int i = cn > 0 ? k_find(cp, (uintptr_t) cn) : -1;
  if (i < 0) return -ENOENT;
  if (!k_ents[i].to) return -EINVAL;
  uintptr_t tn = strlen(k_ents[i].to);
  if (!n) return -EINVAL;
  if (tn > n) tn = n;                            // readlink(2) truncates and does not say so
  memcpy(b, k_ents[i].to, tn);
  return (intptr_t) tn; }

// (rename old new): a file moves whole, a target file unlinked under it; a directory
// carries everything beneath it, the copies staged first so a refusal leaves the tree whole.
struct k_ren { struct k_ren *next; int i; char *q; };
ai_noinline int k_fs_rename(char const *o, uintptr_t olen,
                                   char const *n, uintptr_t nlen) {
  char op[256], np[256];
  intptr_t on, nn;
  if (!k_fs_init()) return -ENOMEM;
  if ((on = k_walk(o, olen, op, false)) < 0) return (int) on;
  if ((nn = k_walk(n, nlen, np, false)) < 0) return (int) nn;
  if (k_ro(op, (uintptr_t) on) || k_ro(np, (uintptr_t) nn)) return -EROFS;
  if (!on) return -EBUSY;                         // the root does not move
  if (on == nn && !memcmp(op, np, (uintptr_t) on)) return 0;           // itself: done
  if (!nn) return -EEXIST;                        // onto the root
  int e = k_parent_ok(np, (uintptr_t) nn);
  if (e) return e;
  int si = k_find(op, (uintptr_t) on), di = k_find(np, (uintptr_t) nn);
  uintptr_t junk;
  bool sdir = si >= 0 ? k_ents[si].dir : k_kids(op, (uintptr_t) on, &junk);
  if (si < 0 && !sdir) return -ENOENT;
  if (!sdir) {
    if (di >= 0 ? k_ents[di].dir : k_kids(np, (uintptr_t) nn, &junk))
      return -EISDIR;                             // a file does not land on a directory
    char *q = k_strdup(np, (uintptr_t) nn);
    if (!q) return -ENOMEM;
    if (di >= 0) k_ents[di].live = false, k_ent_gc(di);
    if (k_ents[si].heap) kfree((void*) k_ents[si].path);
    k_ents[si].path = q, k_ents[si].heap = true;
    return 0; }
  // the directory lane
  if ((uintptr_t) nn > (uintptr_t) on && !memcmp(np, op, (uintptr_t) on) && np[on] == '/')
    return -EINVAL;                               // never into itself
  if (di >= 0 || k_kids(np, (uintptr_t) nn, &junk)) return -EEXIST;
  struct k_ren *st = NULL;
  for (int i = 0; i < k_ents_n; i++) {
    struct k_ent const *t = &k_ents[i];
    if (!t->live || !t->path) continue;
    uintptr_t tl = strlen(t->path);
    if (tl < (uintptr_t) on || memcmp(t->path, op, (uintptr_t) on)
        || (tl > (uintptr_t) on && t->path[on] != '/')) continue;
    char *q = kmallocw(b2w((uintptr_t) nn + tl - (uintptr_t) on + 1));
    struct k_ren *r = q ? kmallocw(b2w(sizeof *r)) : NULL;
    if (!r) {                                    // roll the staging back whole
      kfree(q);
      while (st) { struct k_ren *x = st; st = st->next; kfree(x->q), kfree(x); }
      return -ENOMEM; }
    memcpy(q, np, (uintptr_t) nn);
    memcpy(q + nn, t->path + on, tl - (uintptr_t) on);
    q[(uintptr_t) nn + tl - (uintptr_t) on] = 0;
    *r = (struct k_ren) { st, i, q };
    st = r; }
  while (st) {
    struct k_ent *t = &k_ents[st->i];
    if (t->heap) kfree((void*) t->path);
    t->path = st->q, t->heap = true;
    struct k_ren *x = st;
    st = st->next;
    kfree(x); }
  return 0; }

ai_noinline int k_fs_chdir(char const *p, uintptr_t pn) {
  char cp[256];
  intptr_t cn;
  if (!k_fs_init()) return -ENOMEM;
  if ((cn = k_walk(p, pn, cp, true)) < 0) return (int) cn;
  if (cn) {
    int i = k_find(cp, (uintptr_t) cn);
    if (i >= 0 && !k_ents[i].dir) return -ENOTDIR;
    uintptr_t junk;
    if (i < 0 && !k_kids(cp, (uintptr_t) cn, &junk)) return -ENOENT; }
  memcpy(k_cwd, cp, (uintptr_t) cn), k_cwd_n = (uintptr_t) cn;
  return 0; }

// the seat into a caller's buffer, 0 ok or -ERANGE -- getcwd(2)'s own refusal
int k_fs_getcwd(char *b, uintptr_t n) {
  if (n < k_cwd_n + 2) return -ERANGE;            // '/' + the seat + the NUL
  b[0] = '/';
  memcpy(b + 1, k_cwd, k_cwd_n);
  b[1 + k_cwd_n] = 0;
  return 0; }

// the two attribute writers land on the entry, so a synthesized directory takes either as
// a no-op: it has no row to keep bits on, and its date is its children's.
ai_noinline int k_fs_chmod(char const *p, uintptr_t pn, uintptr_t mode) {
  char cp[256];
  intptr_t cn;
  if (!k_fs_init()) return -ENOMEM;
  if ((cn = k_walk(p, pn, cp, true)) < 0) return (int) cn;
  if (k_ro(cp, (uintptr_t) cn)) return -EROFS;
  int i = k_find(cp, (uintptr_t) cn);
  if (i < 0) return k_dirp(cp, (uintptr_t) cn) ? 0 : -ENOENT;
  k_ents[i].mode = mode & 07777;
  return 0; }

ai_noinline int k_fs_utime(char const *p, uintptr_t pn, uintptr_t ms) {
  char cp[256];
  intptr_t cn;
  if (!k_fs_init()) return -ENOMEM;
  if ((cn = k_walk(p, pn, cp, true)) < 0) return (int) cn;
  if (k_ro(cp, (uintptr_t) cn)) return -EROFS;
  int i = k_find(cp, (uintptr_t) cn);
  if (i < 0) return k_dirp(cp, (uintptr_t) cn) ? 0 : -ENOENT;
  k_ents[i].ms = ms;
  return 0; }

static lvm(ai_kreset) { return k_reset(), g; }

// the cursor as last painted. quay marks the row of every grid write and the cursor is not
// one, so the renderer owns it or the block stays where it last was.
static uint32_t fbcur = ~0u;
static bool fbblink;

// repaint what moved: quay marks each written row in cb->dmg and a renderer reads-and-clears
// (quay.h). love flushes per write, so painting it all here is a blit per character printed.
void fbdraw(void) {
  if (!kcb) return;                    // serial-only: no framebuffer console
  uint16_t const rows = kcb->rows, cols = kcb->cols;
  bool const blink = (kticks & 64) != 0;
  uint32_t const cur = kcb->flag & cb_show ? kcb->wpos : ~0u;
  // a hidden cursor's row is ~0u, which no row index equals, so it matches nothing.
  uint32_t const was = fbcur == ~0u ? ~0u : fbcur / cols,
                 now = cur == ~0u ? ~0u : cur / cols;
  bool const moved = cur != fbcur || blink != fbblink;
  // the paper is minted per frame, never per row: kticks moves under the timer ISR, so a
  // re-read of the blink phase mid-frame could paint one row lit and the next dark.
  struct cb_paper const paper = { kfb._, kfb.pitch, kfb.width, kfb.height, kfb.scale };
  bool painted = false;
  for (uint16_t i = 0; i < rows; i++) {
    uint32_t const r = i > 255 ? 255 : i;   // quay's fold: bit 255 stands for 255-and-past
    if (kcb->dmg[r >> 5] >> (r & 31) & 1 || (moved && (i == was || i == now)))
      cb_paint(&paper, kcb, &kface, i, 0, 0, blink ? cur : ~0u), painted = true; }
  for (int k = 0; k < 8; k++) kcb->dmg[k] = 0;
  fbcur = cur, fbblink = blink;
  // a seat that SHOWS this paper rather than scanning it out hears about it here, and here
  // is the only honest place: the console's bytes leave by the serial door BEFORE the
  // glyphs land, so a seat that took the write for its cue would carry the screen from
  // just before it. only when something was actually drawn -- an idle park paints nothing.
  if (painted) k_fb_touch(); }

// the whole paper down, and the screen owed back in full. the pixels moved under the grid
// -- a new stride, or a new size -- so every row is dirty and the strip past the last row
// is no cell's to paint.
static void fbwash(void) {
  fbcur = ~0u;                         // the cached cursor indexed the grid as it was
  for (int k = 0; k < 8; k++) kcb->dmg[k] = ~(uint32_t) 0;
  for (uintptr_t y = 0; y < kfb.height; y++)
    for (uintptr_t x = 0; x < kfb.width; x++) kfb._[y * kfb.pitch + x] = 0;
  fbdraw(); }

// a cell index carried from a grid `ocols` wide, its rows shifted up by `from` -- the
// cursor's and DECSC's. what falls outside the new grid lands on its edge.
static uint32_t cb_carry(uint32_t pos, uint16_t ocols, uintptr_t from,
                         uintptr_t rows, uintptr_t cols) {
  uintptr_t r = pos / ocols, k = pos % ocols;
  r = r > from ? r - from : 0;
  if (r >= rows) r = rows - 1u;
  if (k >= cols) k = cols - 1u;
  return (uint32_t) (r * cols + k); }

// the console re-made for whatever kfb now says -- both doors below want exactly this. the
// text comes ACROSS: cells row for row, clipped where the new grid is narrower, scrolled up
// only as far as the cursor's row needs, so shrinking spends the blank tail under a prompt
// before it touches a line. nothing reflows -- a line wrapped at the old width stays broken
// where it was, which is the one-buffer bargain.
// kcb is published only once the new grid is whole, and the old buffer freed after, fbdraw
// being able to run from a fault handler; a refusal leaves the console standing, so the
// allocation comes first.
static bool k_cb_remake(void) {
  uintptr_t const rows = kfb.height / (kface.h * kfb.scale),
                  cols = kfb.width / (kface.w * kfb.scale);
  if (!rows || !cols) return false;
  struct cb *const old = kcb;
  uint16_t const orows = old->rows, ocols = old->cols;
  if (rows == orows && cols == ocols) return fbwash(), true;  // same grid, new pixels
  struct cb *c = kmallocw(b2w(sizeof *c + rows * cols * sizeof(uint32_t)));
  if (!c) return false;
  *c = *old;                           // the pen, the modes, a parser mid-sequence
  c->rows = (uint16_t) rows, c->cols = (uint16_t) cols;
  c->top = 0, c->bot = (uint16_t) (rows - 1u);   // the old region addressed the old rows
  c->flag &= (uint16_t) ~cb_pend;      // a pending wrap named the old last column
  uintptr_t const cr = old->wpos / ocols, from = cr >= rows ? cr - rows + 1u : 0,
                  w = cols < ocols ? cols : ocols;
  uint32_t const blank = cb_cell(0, c->def_fg, c->def_bg, 0);   // new ground in the DEFAULT pen
  for (uintptr_t i = 0, n = rows * cols; i < n; i++) c->cb[i] = blank;
  for (uintptr_t r = from, dr = 0; r < orows && dr < rows; r++, dr++)
    for (uintptr_t k = 0; k < w; k++) c->cb[dr * cols + k] = old->cb[r * ocols + k];
  c->wpos = cb_carry(old->wpos, ocols, from, rows, cols);
  c->spos = cb_carry(old->spos, ocols, from, rows, cols);
  kcb = c;
  kfree(old);
  fbwash();
  return true; }

static bool k_vt_rescale(unsigned v) {
  if (!kcb || !kfb._ || v < 1 || v > 8 || v == kfb.scale) return false;
  uint8_t const was = kfb.scale;
  kfb.scale = (uint8_t) v;
  if (k_cb_remake()) return true;
  return kfb.scale = was, false; }

// the paper itself moved: a canvas the reader resized. the pixels have to land inside the
// reservation fbinit was given -- everything below it went to the heap at boot.
bool k_fb_reseat(unsigned w, unsigned h, unsigned pitch, unsigned scale) {
  if (!kcb || !kfb._ || !w || !h) return false;
  if ((uintptr_t) pitch * h > kfb.cap_px) return false;
  // every field here is 16 bits wide, so the bound is the type's and not a policy.
  if (w > 0xffffu || h > 0xffffu || pitch > 0xffffu || w > pitch) return false;
  if (scale > 8) return false;
  uint16_t const ow = kfb.width, oh = kfb.height, op = kfb.pitch;
  uint8_t const os = kfb.scale;
  kfb.width = (uint16_t) w, kfb.height = (uint16_t) h, kfb.pitch = (uint16_t) pitch;
  if (scale) kfb.scale = (uint8_t) scale;
  if (k_cb_remake()) return true;
  kfb.width = ow, kfb.height = oh, kfb.pitch = op, kfb.scale = os;
  return false; }

// the framebuffer as a program may borrow it whole: base, size, stride in pixels. false
// where the door handed over none (PVH), the caller's cue to want the ESP door instead.
bool k_fb(volatile uint32_t **p, int *w, int *h, int *pitch) {
  if (!kfb._) return false;
  *p = kfb._, *w = kfb.width, *h = kfb.height, *pitch = kfb.pitch;
  return true; }

// (tty fd) -- the console as (rows . cols), off the framebuffer's pixels and the glyph scale
// (cbinit); it is not 80x25 here. serial-only there is no grid and the answer is ENOTTY's
// nom. the operand routes as every io op's does: the rows are one table shared by every
// task, and 0 1 2 are the numeric spellings of in/out/err, so a task wearing a pipe is
// asked about the pipe. only a charm past 2 is a raw row.
ai_noinline static struct ai *k_tty(struct ai *g) {
  word x = g->sp[0];
  if (charmp(x) && getcharm(x) >= 0 && getcharm(x) <= 2)
    x = word(getcharm(x) == 0 ? &ai_stdin : getcharm(x) == 1 ? &ai_stdout : &ai_stderr);
  if (*task_io(g) != zero) x = io_route(g, x);
  intptr_t fd = charmp(x) ? getcharm(x) : ai_port_fd(x);
  if (fd < 0) return g->sp[0] = ai_badarg(g), g;
  struct k_source const *s = k_source((int) fd);
  if (!kcb || !s || !(s->putc == serial_putc1 || s->readn == kb_readn))
   return g->sp[0] = ai_err(g, ENOTTY), g;
  if (!ai_ok(g = ai_have(g, Width(struct ai_chain)))) return g;
  struct ai_chain *w = ini_chain((struct ai_chain*) bump(g, Width(struct ai_chain)),
                                 putcharm(kcb->rows), putcharm(kcb->cols));
  return g->sp[0] = word(w), g; }

static lvm(lvm_tty) {
  LvmCall(g, k_tty) }

static lvm(draw) {
 fbdraw();
 k_wait();
 ai_musttail return Next(1); }


static lvm(key) {
 int b = kqpop();
 Sp[0] = putcharm(b < 0 ? 0 : b);
 ai_musttail return Next(1); }

// (color fg bg) -- xterm-256 indices, the attribute and every cell already on the screen.
// two in and one out, so the answer lands in the deeper slot and Sp moves by one.
static lvm(color) {
 uint8_t fg = getcharm(Sp[0]), bg = getcharm(Sp[1]);
 if (kcb) cb_recolor(kcb, fg, bg);
 Sp[1] = ZeroPoint;
 ai_musttail return Nextp(1, 1); }

// (fault n) -- raise a CPU exception to exercise the ap in arch.c; n mirrors the x64 vector
// numbers. the ap halts, so what follows the call is reachable only if the fault missed.
static lvm(lvm_fault) {
  k_fault_trigger(getcharm(Sp[0]));
  ai_musttail return Next(1); }

// (quit code) -- the exit door, with two rooms behind it. a seated task quits as _exit: its
// seated fds close (a write end's close is the reader's EOF), the seat retires, and the task
// lands dormant with the code as its retval, which is what `wait` (catch) answers. unseated,
// the exit is the machine's: reset -- test/kernel/kore0.l pins (: (quit n) n) one door deeper.
static union u const k_exit_body[] = { {lvm_task_exit} };
// the spawned half: shut the rows this task's worn stdio names -- a pipe's write end has to
// close here for the reader to see EOF -- and clear the yield intentions. the port is
// neutered as its row goes. -> nonzero when the task has a pid, so the wrapper knows the room.
ai_noinline static int k_task_exit(struct ai *g) {
  if (!k_cur_pid(g)) return 0;
  word l = *task_io(g);
  for (int i = 0; i < 3 && chainp(l); i++, l = B(l)) {
    word x = A(l);
    if (!iop(x)) continue;
    struct ai_fio *f = (struct ai_fio*) x;
    intptr_t fd = ai_io_fd(&f->io);
    if (fd > 2) k_row_close((int) fd), f->fd = putcharm(-1); }
  g->next_wake_at = 0;                          // a stale intention would gate the park
  g->next_wait_fd = -1;
  return 1; }

// inle/main.c's quit nif branches here on a negative osv: the task/machine door.
lvm(k_lvm_quit) {
  if (k_task_exit(g)) {
    // the love-machine _exit: the stack becomes just [code] and Ip a task-exit cell, the
    // shape lvm_task_exit leaves. the frame below Sp is abandoned whole.
    word code = (Sp[0] & 1) ? Sp[0] : putcharm(0);
    Sp = (word*) g + g->len - 1;
    Sp[0] = code;
    Ip = (union u*) k_exit_body;
    ai_musttail return Ap(lvm_task_exit, g); }
  k_reset();
  ai_musttail return Next(1); }



static union u
  nif_reset[] = {{ai_kreset}},
  nif_draw[] = {{draw}, {lvm_ret0}},
  nif_key[] = {{key}, {lvm_ret0}},
  nif_color[] = {{lvm_cur}, {.x = putcharm(2)}, {color}, {lvm_ret0}},
  nif_disk[] = {{lvm_disk}, {lvm_ret0}},
  nif_disk_read[] = {{lvm_cur}, {.x = putcharm(2)}, {lvm_disk_read}, {lvm_ret0}},
  nif_disk_write[] = {{lvm_cur}, {.x = putcharm(2)}, {lvm_disk_write}, {lvm_ret0}},
  nif_fetch[] = {{lvm_cur}, {.x = putcharm(2)}, {lvm_fetch}, {lvm_ret0}},
  nif_kexec[] = {{lvm_cur}, {.x = putcharm(2)}, {lvm_kexec}, {lvm_ret0}},
#if defined(__x86_64__)
  nif_svm[] = {{lvm_svm}, {lvm_ret0}},
  nif_svm_run[] = {{lvm_svm_run}, {lvm_ret0}},
  nif_vmx[] = {{lvm_vmx}, {lvm_ret0}},
  nif_vmx_run[] = {{lvm_vmx_run}, {lvm_ret0}},
#endif
  nif_fault[] = {{lvm_fault}, {lvm_ret0}},
  nif_tty[] = {{lvm_tty}, {lvm_ret0}};

// link every free range kboot reports into the free list, in array order: kmem is the last
// and the earlier ones link through ->next.
static bool meminit(void) {
  if (!kboot.ram_n) return false;
  for (uint32_t i = 0; i < kboot.ram_n; i++) {
    struct mem *m = (struct mem*) (kboot.hhdm + kboot.ram[i].base);
    m->len = kboot.ram[i].len / sizeof(uintptr_t);
    kram_words += m->len;
    m->next = kmem;
    kmem = m; }
  return true; }

// how many pixels a glyph pixel gets: the door's, where it knows the screen better than
// the pixel count does, else the largest that still leaves 80 columns and 24 rows.
static uint8_t fbscale(void) {
  uint8_t s = 1;
  while (s < 8 && kfb.width / (kface.w * (s + 1u)) >= 80
               && kfb.height / (kface.h * (s + 1u)) >= 24) s++;
  return s; }

static bool fbinit(void) {
  if (!kboot.has_fb) return false;
  kfb._      = kboot.fb.base;
  kfb.width  = kboot.fb.w;
  kfb.height = kboot.fb.h;
  kfb.pitch  = kboot.fb.pitch_px;
  kfb.scale  = kboot.fb.scale ? kboot.fb.scale : fbscale();
  // a door that named no reservation cannot be resized, so its paper is its own size.
  kfb.cap_px = kboot.fb.cap_px ? kboot.fb.cap_px : (uint32_t) kfb.width * kfb.height;
  return true; }

static bool cbinit(void) {
  const uintptr_t rows = kfb.height / (kface.h * kfb.scale),
                  cols = kfb.width / (kface.w * kfb.scale);
  // kmallocw, not ai_alloc: cbinit runs before ai_ini, so no g exists yet
  if (!(kcb = kmallocw(b2w(sizeof(struct cb) + rows * cols * sizeof(uint32_t))))) return false;
  cb_open(kcb, rows, cols);
  kcb->flag |= cb_lnm;  // the kernel console's discipline: a bare \n is a newline
  cb_attr(kcb, 15, 0, 0);   // white on black: xterm-256's 15 and 0, what a terminal is
  cb_fill(kcb, 0);
  return true; }

// the kernel's own nifs ride ai_knifs, a section apart: the one binary is also the hosted
// love, whose book must not carry reset, fault, the disk or the virt doors. kmain drains
// love_nifs and then this bracket, indexed by position -- so the order is append-only.
static struct ai_def const __attribute__((section("ai_knifs"), used)) defs[] = {
  {"reset", {.k = nif_reset}},
  {"draw", {.k = nif_draw}},
  {"key", {.k = nif_key}},
  {"fault", {.k = nif_fault}},
  // the posix surface is inle/posix.c's and inle/main.c's, linked whole: their nifs land in
  // this section and quit/getpid branch to k_lvm_quit / k_lvm_getpid on a negative osv.
  // rung 5: the raw block door. no host twin (the host has no raw disk), so the shapes are
  // love's: absence and refusal answer (), presence is the green sector count.
  {"disk", {.k = nif_disk}},
  {"disk-read", {.k = nif_disk_read}},
  {"disk-write", {.k = nif_disk_write}},
  // x64 only, so a reader asks (elem 'svm (names ())) first: elsewhere the nom is not in
  // the book, and reading it is missing rather than absence.
#if defined(__x86_64__)
  {"svm", {.k = nif_svm}},
  {"svm-run", {.k = nif_svm_run}},
  {"vmx", {.k = nif_vmx}},
  {"vmx-run", {.k = nif_vmx_run}},
#endif
  {"color", {.k = nif_color}},
  // the console's own size; the no-op roster below pins `tty` only where a seat lacks it
  {"tty", {.k = nif_tty}},
  {"fetch", {.k = nif_fetch}},
  {"kexec", {.k = nif_kexec}} };

// the kore cat is catted from the ramfs at boot, so only the order is baked: one roster line
static char const src_korelist[] =
#include "korelist.h"
;
// the crew roster: not in the kernel's cat, so the kernel carries the order and the members
// are read off /proc/src at the first ask. a path list, because a module's name does not say
// which file holds it and sb spans three that load in the order given.
static char const src_crewlist[] =
#include "crewlist.h"
;

void kmain(void) {
#if defined(__x86_64__)
 // enable x87/SSE before any other C runs: a compiler vectorizes freely on x64 (even a struct
 // copy is movups) and that #UDs into a triple fault with no output while SSE is masked.
 k_sse_enable();
#endif
 // which kernel: -1, we are it. on metal __ai_start is not the entry, so the value is written
 // here before any libc member can ask -- unwritten, the lazy probe issues a real `syscall`
 // into our own #UD handler. the seat arming rides with it (inle/sys.c).
 __ai_osv = -1;
 k_seat_init();
 khhdm = kboot.hhdm;
 archinit();
 // the wall date: whatever the door left in kboot, else the RTC, which archinit has just
 // made reachable (the a64 read is device memory, and mmio_map lays it).
 if (!kboot.date) kboot.date = k_rtc();
 serial_init();
 // the heap (meminit) is the only hard requirement: with fbinit or cbinit failing, kcb
 // stays null and the kernel runs headless on the serial console alone.
 if (meminit()) {
  if (fbinit()) cbinit();        // the framebuffer console; the palette is a table now
  // the disk (rung 5): probe the bus, and hand the driver its one DMA block --
  // kmallocw memory, so pa = va - khhdm holds for everything the device reads.
  k_blk_init(kmallocw(b2w(352)));
  // the sound card: command rings, buffer list and position buffer in one block, 128-aligned
  // inside (hda.c lays it); the sample ring is its own
  k_hda_init(kmallocw(b2w(4096 + 128)));
  // the wake: ai_baked_pick reads the projection's re-based image off the same two symbols
  // the hosted start does; any problem answers NULL and the egg bakes from source below.
  struct ai *g = NULL;
  uintptr_t blen = 0;
  void const *bimg = NULL;
  if (kboot.image_len) bimg = kboot.image, blen = kboot.image_len;
  else if (!ai_baked_pick(&bimg, &blen)) blen = 0;
  if (blen) g = ai_image_load(bimg, blen);
  bool woke = g != NULL;
  char const *s = woke ? "; inle -- image awake\n" : "; inle -- baking the egg\n";
  for (; *s; s++) serial_putc(*s);
  if (!woke) g = ai_ini();
  // the nif drains re-pin over a woken book too: the section rides this binary
  g = ai_defn(g, __start_love_nifs,
              (uintptr_t)(__stop_love_nifs - __start_love_nifs));
  // ..then the kernel's own bracket, so a kernel row wins any name it shares
  g = ai_defn(g, __start_ai_knifs,
              (uintptr_t)(__stop_ai_knifs - __start_ai_knifs));
  // bound the generational collector to the device's RAM (the Appel knob): unbounded, the
  // nursery's resizer grows and gen_major's all-survive sizing asks kmallocw for a block
  // bigger than physical RAM. an eighth leaves headroom for the major's double-buffered
  // resize, the free list and fragmentation; the host, with virtual memory, runs unbounded.
  if (ai_ok(g)) ai_core_of(g)->budget = kram_words / 8;
  // the kore ROSTER (rung 3): the cat itself is read off the ramfs below.
  g = ai_strof(g, src_korelist);
  struct ai_def kd[] = {{"korelist", {.x = ai_pop1(g)}}};
  g = ai_defn(g, kd, countof(kd));
  g = ai_strof(g, src_crewlist);
  struct ai_def cd[] = {{"crewlist", {.x = ai_pop1(g)}}};
  g = ai_defn(g, cd, countof(cd));
  // the boot cmdline, raw; the boot text below splits it into the argv shape.
  g = ai_strof(g, kboot.cmdline);
  struct ai_def bd[] = {{"bootline", {.x = ai_pop1(g)}}};
  g = ai_defn(g, bd, countof(bd));
  // the egg lane: the prel and the module layers; the seat text below runs on both lanes
  struct ai *r = g;
  if (!woke) {
   r = ai_cats_egg(g);
   r = ai_cats_lib(r);                                  // register every baked module; the uses below are splices
   r = ai_evals_(r,
    // verbs first: this machine's userland is a verb table the cat's apps pin into as they
    // load, and the boot cmdline's program seat reads the registry.
    "(borrow 'verbs)"
    "(borrow 'uu) (: uu (cite 'uu))"                         // the uu kernel: the corpus's uu files drive it through the
    "(borrow 'cli)"); }                                      //   one-name `uu` surface on this target too
  // FIXME waaaaay too much code in here, old style too. also, this gets eval'd by c0, right? not ideal.
  // FIXME again, waaaaaaaaaaaaaaaaaaaaaaaaaaay too much code in string literals! ridiculous!
  //
  // the seat text, both lanes: what this machine is that a host is not. over a woken book
  // these shadow the hosted bindings -- getenv reads envt here, not an empty environ.
  r = ai_evals_(r,
 // which kernel this is: nothing to probe here, so it is said outright. kore's uname
 // respells it through the prel's os-uname.
 "(: love-os 'inle)"
 // the environment: a tablet, the pairs on slot 0, closures over it wearing the host's names
 // -- getenv the value | (), setenv () | 'badarg (a non-string value unsets), environ the
 // raw "NAME=value" strings.
 "(: envt (tablet 0)"
 "   _ (pin envt 0 (. (. \"HOME\" \"/home\") ()))"
 "   (envget l n) (? (two? l) (? (= n (cap (cap l))) (cup (cap l)) (envget (cup l) n)) ())"
 "   (envcut l n) (? (two? l) (? (= n (cap (cap l))) (envcut (cup l) n)"
 "                              (. (cap l) (envcut (cup l) n))) ())"
 "   (getenv n) (? (string? n) (envget (peep envt 0 ()) n) ())"
 "   (setenv n v) (? (string? n)"
 "                   (: c (envcut (peep envt 0 ()) n)"
 "                      _ (pin envt 0 (? (string? v) (. (. n v) c) c)) ())"
 "                   'badarg)"
 "   (environ u) (map (\\ e (+ (cap e) (+ \"=\" (cup e)))) (peep envt 0 ())))"
 // `bootargv` = (word..) off the raw boot line, split quote-aware. `cmdline` stays seatless
 // until the cat is in: a member's seat fires as its own file is read and lush sits mid-cat,
 // so it would take the machine with kore's applets unread. the foot wears the real line.
 "(: bootargv"
 "     (: (kw i w s acc) (? (<= (tally bootline) i) (rev (? (tally w) (. w acc) acc))"
 "                          (: c (bootline i)"
 // a char joins a string as a string of one: (+ w c) on mixed bands degenerates to w
 // alone, so a bare charm would drop every word's letters.
 "                             (? s (? (= c s) (kw (+ i 1) w 0 acc) (kw (+ i 1) (+ w (string c)) s acc))"
 "                                (= c 32) (kw (+ i 1) \"\" 0 (? (tally w) (. w acc) acc))"
 "                                (|| (= c 34) (= c 39)) (kw (+ i 1) w c acc)"
 "                                (kw (+ i 1) (+ w (string c)) 0 acc))))"
 "        (kw 0 \"\" 0 ()))"
 "   cmdline (. \"love\" ())"
 "   argv cmdline)"
 // rung 4: spawn/wait as a love-side shim over the core task ops. a process here is a task:
 // k-prog maps argv onto a love main -- a registry verb, a tool's own <name>-main, or a .l
 // path off the ramfs evaled form by form (no fresh layer, so its defglobs land in the
 // session). k-spawn1 seats the pid's stdio in the parent, twirl not switching, so the seat
 // is laid before the child's first read. wait is catch; pg/fg/closes are ignored.
  // the fs doors by value, off their module: a splice would sit above the kernel's own
  // shadows (raw, signal, setenv, environ, the no-op roster below), and those are why
  // this seat can run a crew written for a host.
 "(: open (cite 'posix 'open) close (cite 'posix 'close) stat (cite 'posix 'stat)"
 "   unlink (cite 'posix 'unlink)"
 "   (k-bn p) (: n (tally p)"
 "     (go i r) (? (< i n) (go (+ i 1) (? (= (p i) 47) (+ i 1) r)) (snip p r n))"
 "     (go 0 0))"
 "   (k-slurp p) (: q (open p \"r\") (? (port? q) (: t (slurp q) _ (close q) t) ()))"
 "   (k-run-text t) (\\ as"
 "     ((: (go cl) (: r (sound cl) (? (two? r) (: _ (ev (cap r)) (go (cup r))) 0))) t))"
 "   (k-tool nm as) (? (elem nm (names ())) (. (ev nm) as) ())"
  // the crew load reads the roster's files off /proc/src and each file's own (module ..)
  // form registers it. it hangs off the registry's miss (verbs' fills, installed below), the
  // one place every asker walks -- lush answers "not found" from its lookup, so a retry at
  // the spawn never runs. `source` is the witness that the load already happened.
 "   (cwords s i j acc)"
 "    (? (< j (tally s))"
 "       (? (= 32 (peep s j 0))"
 "          (? (< i j) (cwords s (+ j 1) (+ j 1) (. (snip s i j) acc)) (cwords s (+ j 1) (+ j 1) acc))"
 "          (cwords s i (+ j 1) acc))"
 "       (? (< i j) (rev (. (snip s i j) acc)) (rev acc)))"
 "   (cload p) (: q (open (+ \"/proc/src/\" p) \"r\")"
 "     (? (port? q)"
 "        (: t (slurp q) _ (close q)"
 "           (go cl) (: r (sound cl) (? (two? r) (: _ (ev (cap r)) (go (cup r))) 0))"
 "           (go t))"
 "        0))"
 "   (crewload _) (? (cite 'source) 0 (: _ (each (cwords crewlist 0 0 ()) cload) 0))"
 // the registry is the PATH here: apps pin their names into (cite 'verbs 'tab) and `word`
 // applies the shadow rules -- a slashed word or a .l name is a file and never a verb, which
 // is what leaves the two lanes below reachable. a verb takes the args after its name.
 "   (k-prog argv) (k-proga argv 1)"
 // a script says who reads it: `#!`, the words after it, then this path and the args. the
 // reader is taken by basename -- usr/bin is empty, so /bin/sh is sh. one hop.
 "   (k-bangv t p as)"
 "    (? (! (&& (string? t) (&& (< 2 (tally t)) (= \"#!\" (snip t 0 2))))) ()"
 "       (: n (tally t)"
 "          (go i) (? (< i n) (? (= 10 (peep t i 0)) i (go (+ i 1))) n)"
 "          w (cwords (snip t 2 (go 0)) 0 0 ())"
 "          (? (two? w) (. (k-bn (cap w)) (+ (cup w) (. p as))) ())))"
 "   (k-proga argv h) (: a0 (cap argv) b (k-bn a0) as (cup argv)"
 "     v (cite 'verbs 'word a0)"
 "     (? !(nil? v) (. v as)"
 "        (: k (k-tool (intern (+ b \"-main\")) as)"
 "           (? (two? k) k"
 // `kore TOOL ..` where no dispatcher registered one: the test kernel bakes the applets
 "              (&& (= b \"kore\") (two? as))"
 "                (k-tool (intern (+ (cap as) \"-main\")) (cup as))"
 "              (two? (stat a0)) (k-progf a0 as h)"
 // a path the seat has not got is looked for on the tarball, so `love test/kernel/all.l`
 // names the corpus from any seat, off the bake's own rows and never a tree somebody edited
 "              (&& (! (= 47 (peep a0 0 0))) (two? (stat (+ \"/proc/src/\" a0))))"
 "                (k-progf (+ \"/proc/src/\" a0) as h)"
 "              ()))))"
 "   (k-progf a0 as h) (: t (k-slurp a0)"
 "                 g (? (< 0 h) (k-bangv t a0 as) ())"
 "                 (? (two? g) (k-proga g (- h 1))"
 "                    (string? t) (. (k-run-text t) as)"
 "                    ()))"
 "   (k-slot w n) (? (! (two? w)) () (n = 0) (cap w) (k-slot (cup w) (n - 1)))"
 // a console-numbered fd means the parent's view of it, so 2>&1 follows what the parent
 // wears; anything higher is duped, the port owning the copy from there.
 "   (k-port w n f) (? (! (charm? f)) (k-slot w n) (f < 0) (k-slot w n)"
 "                     (f < 3) (k-slot w f) (fdopen (dup f)))"
 "   (k-spawn1 argv f0 f1 f2) (: pr (k-prog argv)"
 "     w (worn ())"
 "     kw [(k-port w 0 f0) (k-port w 1 f1) (k-port w 2 f2)]"
 // worn across the twirl, which does not switch tasks: the child inherits node[7] and
 // nothing of ours runs in between, so the parent takes its own back on the next line.
 "     _ (wear kw)"
 // the help is the exit door too: a kore main leaves deep by scaring 'leave with its status
 // (apps/kore/core.l), and a plain scare would flatten every usage code to 1.
 "     p (twirl (\\ _ (: _ (hear (\\ a b (? (== a 'leave) (quit b)"
 "                                        (: _ (say err \";; \") _ (print err a)"
 "                                           _ (say err \" \") _ (print err b)"
 "                                           _ (put err 10) (quit 1)))))"
 "                     r (? (two? pr) ((cap pr) (cup pr))"
 "                          (: _ (say err (+ (cap argv) \": not found\"))"
 "                             _ (put err 10) 127))"
 "                     (quit (? (charm? r) r 0))))"
 "              0)"
 "     _ (wear w)"
 "     p)"
 "   (k-fdw x) (? (charm? x) (? (< x 0) (- 0 1) x) (- 0 1))"
 "   (spawn argv) (k-spawn1 argv (- 0 1) (- 0 1) (- 0 1))"
 // exec at task granularity: this task becomes the program and never comes back
 "   (exec argv) (: pr (k-prog argv)"
 "     (? (two? pr) (: r ((cap pr) (cup pr)) (quit (? (charm? r) r 0)))"
 "        (: _ (say err (+ (cap argv) \": not found\")) _ (put err 10) (quit 127))))"
 "   (spawnio argv i o e cl pg fg) (k-spawn1 argv (k-fdw i) (k-fdw o) (k-fdw e))"
 "   (spawnmap argv fdm cl pg fg)"
 "     ((: (go m a b c)"
 "          (? (one? m) (k-spawn1 argv a b c)"
 "             (: e (cap m) cf (cap e) sf (cup e)"
 "                v (? (charm? sf)"
 "                     (? (&& (<= 0 sf) (< sf 3))"
 "                        (: w (? (= sf 0) a (= sf 1) b c) (? (< w 0) sf w))"
 "                        sf)"
 "                     (- 0 2))"
 "                (? (= cf 0) (go (cup m) v b c)"
 "                   (= cf 1) (go (cup m) a v c)"
 "                   (= cf 2) (go (cup m) a b v)"
 "                   (go (cup m) a b c))))"
 "        go)"
 "      fdm (- 0 1) (- 0 1) (- 0 1))"
 "   (wait p) (catch p)"
 // hark and herald on a seat with no fork: the capture is a scratch file worn as the child's
 // stdout and herald's relay is a dump at the end. stderr stays on the console.
 "   hark-n {}"
 // a word nothing answers is an answer here, never a line on the console -- what a hosted
 // hark's errno is, and `$(shell command -v cc)` is the caller asking.
 "   (hark1 argv tee) (? (! (two? (k-prog argv))) ()"
 "      (: w (worn ())"
 "         k (+ 1 (peep hark-n 0 0))"
 "         _ (pin hark-n 0 k)"
 "         p (+ \"/tmp/.hark\" (show k))"
 "         q (open p \"w\")"
 "         (? (! (port? q)) ()"
 // the child reads nothing, the way a hosted hark hands its own /dev/null
 "            (: z (open \"/dev/null\" \"r\")"
 "               _ (wear [(? (port? z) z (k-slot w 0)) q (k-slot w 2)])"
 "               d (spawn argv)"
 "               st (? (&& (charm? d) (<= 0 d)) (wait d) 127)"
 "               _ (wear w)"
 "               _ (close q)"
 "               _ (? (port? z) (close z) 0)"
 "               r (open p \"r\")"
 "               t (? (port? r) (: b (slurp r) _ (close r) b) \"\")"
 "               _ (unlink p)"
 "               _ (? tee (puts t) 0)"
 "               (. (? (charm? st) st 0) t)))))"
 "   (hark argv) (hark1 argv 0)"
 "   (herald argv) (hark1 argv 1))"
  );
  // a woken image's crew captured the seat-doors wrappers (inle/main.c), which read the live
  // door off the tablet -- aim them at this seat's shim. the egg book has no tablet.
  r = ai_evals_(r,
   "(? (elem 'seat-doors (names ()))"
   "   (: _ (pin seat-doors 0 spawn) _ (pin seat-doors 1 spawnio)"
   "      _ (pin seat-doors 2 spawnmap) (pin seat-doors 3 wait))"
   "   0)");
  // the session: a fresh writable layer, so the shell's defglobs never land in the base
  r = ai_open_(r);
  // an unbound mention raises missing at every define that names one, and bao's file-help
  // folds a real quit, so one absent nif in the cat resets the machine at load. pin a no-op
  // for whichever host nifs the cat mentions and this seat lacks -- self-retiring, since a
  // rung landing the real nif takes its name off by existing. raw answers (), signal ignores.
  r = ai_evals_(r,
   "(: (raw m) () (signal n h) ())"
   "(map (\\ n (? (elem n (names ())) () (ev [': [n 'x] ()])))"
   "     '(hardlink spawn spawnmap fork exec herald wait still"
   "       getpid getuid seal ttyfg glean pipe fdopen dup dup2 connect listen"
   "       accept udp-bind udp-send udp-recv hark tty))");
  // then the kore cat through the stream shell: the line is seatless here, so every member's
  // own seat sits out and the whole userland lands. built off /proc/src, korelist being the
  // baked roster. egg lane only: re-loading over a woken image re-pins every sealed verb.
  if (!woke) {
  r = ai_evals_(r,
   "(: (kwords s i j acc)"
   "    (? (< j (tally s))"
   "       (? (= 32 (peep s j 0))"
   "          (? (< i j) (kwords s (+ j 1) (+ j 1) (. (snip s i j) acc)) (kwords s (+ j 1) (+ j 1) acc))"
   "          (kwords s i (+ j 1) acc))"
   "       (? (< i j) (rev (. (snip s i j) acc)) (rev acc)))"
   "   open (cite 'posix 'open) close (cite 'posix 'close)"    // by value, as above
   "   (kslurp p) (: h (open (+ \"/proc/src/\" p) \"r\") s (slurp h) _ (close h) s)"
   "   (kcat l) (? (two? l) (+ (kslurp (cap l)) (kcat (cup l))) \"\")"
   "   korecat (kcat (kwords korelist 0 0 ())))");
  r = ai_evals_(r, "(reads (tap ((: (g i) (? (< i (tally korecat)) (. (peep korecat i 0) (g (+ 1 i))))) 0)))");
  }
  // the crew hangs off the registry's miss, re-armed on every boot including a woken
  // image's: the load is idempotent, its own `source` row the guard.
  r = ai_evals_(r, "((cite 'verbs 'fills) crewload)");
  // `bake PATH` on the boot line: the warm heap -- the crew in, the seat text run -- as an
  // image file on the ramfs, then reset; the wasm lift hands it to the next boot as
  // kboot.image. the crew is pulled aboard first: left to the filler it is not in the heap
  // that gets written, and every boot of that image pays the whole load at its first miss.
  if (!memcmp(kboot.cmdline, "bake ", 5)) {
    r = ai_evals_(r, "(crewload 0)");
    k_bake(r, kboot.cmdline + 5); }
  // now the line wears its real shape and the program word dispatches off the registry.
  // an empty line falls to the console shell, the toolbox warm.
  r = ai_evals_(r, "(: cmdline (. \"love\" bootargv) argv cmdline)");
  r = ai_evals_(r,
   "(? (two? bootargv)"
   "   (: _ (hear (\\ a b (? (== a 'leave) (quit b)"
   "                        (: _ (say err \";; \") _ (print err a) _ (say err \" \") _ (print err b)"
   "                           _ (put err 10) (quit 1)))))"
   "      pr (k-prog bootargv)"
   "      r (? (two? pr) ((cap pr) (cup pr))"
   "           (: _ (say err (+ (cap bootargv) \": not found\")) _ (put err 10) 127))"
   "      (quit (? (charm? r) r 0)))"
   "   0)");
  r = ai_evals_(r, "(cite 'cli 'shell 0)");
  // a terminal scare gets the honest face on the serial console before reset
  if (ai_code_of(r) == ai_status_scare) ai_scare_face_(r);
  ai_fin(r); }
 k_reset(); }
