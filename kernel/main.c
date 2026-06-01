#ifndef K_EFI
#include "limine/limine.h"
#endif
#include "k_boot.h"
#include "i.h"
#include "cb.h"
#include <stdarg.h>
#include <limits.h>

uint64_t kticks;
// Higher-half direct map offset: physical address P is reachable at
// khhdm + P. The Limine build copies this out of the HHDM response; the
// EFI build leaves it 0 (identity-mapped). Set before archinit, so arch
// code can use it for MMIO.
uintptr_t khhdm;

static struct mem {
  struct mem *next;
  uintptr_t len;
  uintptr_t _[];
} *kmem;

struct cb *kcb;

static struct {
  volatile uint32_t *_;
  uint16_t width, height, pitch; } kfb;

// keyboard input. kb_int (interrupt context) decodes scancodes and
// enqueues input bytes -- arrow/Delete keys as the ANSI escape sequences
// the line editor decodes; k_getc and the (key) builtin drain the queue.
// f holds the live modifier flags.
static struct { uint8_t f, q[16], qh, qt; } kkb;
// enqueue one input byte (drop if full). non-static: the COM1 serial
// RX handler (k_uart, in x86_64/arch.c) feeds this same queue.
void kq(uint8_t b) {
  uint8_t n = (kkb.qt + 1) & 15;
  if (n != kkb.qh) kkb.q[kkb.qt] = b, kkb.qt = n; }
static int kqpop(void) {                   // dequeue one byte, -1 if empty
  if (kkb.qh == kkb.qt) return -1;
  int b = kkb.q[kkb.qh];
  return kkb.qh = (kkb.qh + 1) & 15, b; }

static uint32_t palette[256];
static struct font
 kfont = { .glyphs = (uint8_t*) moderndos_8x16, .w = 8, .h = 16, },
 *fonts[16] = { &kfont };

static void palette_init(void) {
  static const uint32_t base[16] = {              // 0..15: the standard 16
    0x000000, 0x800000, 0x008000, 0x808000,
    0x000080, 0x800080, 0x008080, 0xc0c0c0,
    0x808080, 0xff0000, 0x00ff00, 0xffff00,
    0x0000ff, 0xff00ff, 0x00ffff, 0xffffff };
  static const uint8_t cube[6] = { 0, 95, 135, 175, 215, 255 };  // xterm levels

  for (int i = 0; i < 16; i++) palette[i] = base[i];
  for (int i = 0; i < 216; i++) {                  // 16..231: 6x6x6 cube
    int r = i / 36, g = i / 6 % 6, b = i % 6;
    palette[16 + i] = cube[r] << 16 | cube[g] << 8 | cube[b]; }
  for (int i = 0; i < 24; i++) {                   // 232..255: grey ramp
    uint32_t v = 8 + 10 * i;
    palette[232 + i] = v << 16 | v << 8 | v; } }


void k_reset(void), archinit(void), fbdraw(void), serial_init(void), serial_putc(int),
     k_fault_trigger(intptr_t n);

static g_inline void kwait(void) { asm volatile (
#if defined (__x86_64__)
  "hlt"
#elif defined (__aarch64__) || defined (__riscv)
  "wfi"
#elif defined (__loongarch64)
  "idle 0"
#endif
  ); }

#include "cb.h"
#include <stdarg.h>
#ifndef K_EFI
__attribute__((used, section(".limine_requests_start")))
static volatile LIMINE_REQUESTS_START_MARKER;
#define _L __attribute__((used, section(".limine_requests"))) static volatile
_L LIMINE_BASE_REVISION(3);
_L struct limine_memmap_request memmap_req = { .id = LIMINE_MEMMAP_REQUEST, .revision = 0 };
_L struct limine_hhdm_request hhdm_req = { .id = LIMINE_HHDM_REQUEST, .revision = 0 };
_L struct limine_framebuffer_request fb_req = { .id = LIMINE_FRAMEBUFFER_REQUEST, .revision = 0 };
_L struct limine_date_at_boot_request date_req = { .id = LIMINE_DATE_AT_BOOT_REQUEST, .revision = 0 };
_L struct limine_executable_address_request addr_req = { .id = LIMINE_EXECUTABLE_ADDRESS_REQUEST, .revision = 0 };
_L struct limine_efi_system_table_request systbl_req = { .id = LIMINE_EFI_SYSTEM_TABLE_REQUEST, .revision = 0 };
_L struct limine_executable_cmdline_request cmdline_req = { .id = LIMINE_EXECUTABLE_CMDLINE_REQUEST, .revision = 0 };
__attribute__((used, section(".limine_requests_end")))
static volatile LIMINE_REQUESTS_END_MARKER;

// kboot is shared with the EFI backend; defined here for the Limine
// build and populated by limine_to_kboot() at the top of kmain.
struct k_boot kboot;
static void limine_to_kboot(void) {
  if (hhdm_req.response) kboot.hhdm = hhdm_req.response->offset;
  if (memmap_req.response) {
    struct limine_memmap_entry **rr = memmap_req.response->entries;
    uintptr_t n = memmap_req.response->entry_count;
    for (uintptr_t i = 0; i < n && kboot.ram_n < K_BOOT_RAM_MAX; i++)
      if (rr[i]->type == 0)
        kboot.ram[kboot.ram_n].base = rr[i]->base,
        kboot.ram[kboot.ram_n].len  = rr[i]->length,
        kboot.ram_n++; }
  if (fb_req.response && fb_req.response->framebuffer_count) {
    struct limine_framebuffer *f = fb_req.response->framebuffers[0];
    kboot.fb.base     = f->address;
    kboot.fb.w        = f->width;
    kboot.fb.h        = f->height;
    kboot.fb.pitch_px = f->pitch >> 2;
    kboot.has_fb      = true; } }
#endif

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
// k_sources[] holds per-fd vtables. The kernel's g_fd_port_vt is a thin
// shim that routes each call through k_sources[fd]. NULL slots mean
// "no method"; the dispatcher skips them (writes discard, reads return
// EOF, ready returns false). Per-byte methods today -- P3b/later will
// add bulk read/write when ramfs/files start needing them. `state` is
// per-instance scratch (ramfs uses it for the buffer pointer; statics
// like keyboard/serial leave it null).
#define K_SOURCES_MAX 32

struct k_source {
  int  (*getc)(int fd);                 // returns 0..255, -1 = EOF / no data
  void (*putc)(int fd, int c);
  void (*flush)(int fd);
  bool (*ready)(int fd);                // non-blocking probe
  void (*close)(int fd);                // release per-fd state
  void *state;
};

// Slot 0: PS/2 keyboard. Blocks until a byte is queued, pumping the
// framebuffer in between so the cursor keeps blinking. No EOF on bare
// metal -- the kb queue is endless -- so the dispatcher's eof_seen
// latch never trips for slot 0.
static int kb_getc(int fd) {
  (void) fd;
  int b;
  while ((b = kqpop()) < 0) fbdraw(), kwait();
  return b; }
static bool kb_ready(int fd) { (void) fd; return kkb.qh != kkb.qt; }

// Slot 1: serial console. Output goes to the framebuffer when one is
// present and is always mirrored to COM1. Flush triggers a frame draw.
static void serial_putc1(int fd, int c) {
  (void) fd;
  if (kcb) cb_putc(kcb, c);
  serial_putc(c); }
static void serial_flush(int fd) { (void) fd; fbdraw(); }

static struct k_source k_sources[K_SOURCES_MAX] = {
  [0] = { .getc = kb_getc,      .ready = kb_ready    },
  [1] = { .putc = serial_putc1, .flush = serial_flush },
};

// Generic kernel dispatchers. ungetc/eof touch only header fields so
// they're identical across sources; getc/putc/flush route through
// k_sources[fd]. Bounds-checks and NULL-guards keep misuse from
// crashing (read-from-output-fd returns EOF; write-to-input-fd discards).
static struct g *fd_getc(struct g *f) {
  struct g *fc = g_core_of(f);
  struct g_io *i = f->io;
  if (g_getnum(i->ungetc_buf) != EOF) {
    fc->b = g_getnum(i->ungetc_buf);
    i->ungetc_buf = g_putnum(EOF);
    return f; }
  int fd = g_getnum(i->fd);
  int c = -1;
  if (fd >= 0 && fd < K_SOURCES_MAX && k_sources[fd].getc)
    c = k_sources[fd].getc(fd);
  if (c < 0) { i->eof_seen = g_putnum(true); fc->b = EOF; }
  else fc->b = c;
  return f; }
static struct g *fd_ungetc(struct g *f, int c) {
  struct g *fc = g_core_of(f);
  struct g_io *i = fc->io;
  i->ungetc_buf = g_putnum(c);
  i->eof_seen = g_putnum(false);
  return fc->b = c, f; }
static struct g *fd_eof(struct g *f) {
  struct g *fc = g_core_of(f);
  struct g_io *i = fc->io;
  return fc->b = (g_getnum(i->ungetc_buf) == EOF) && g_getnum(i->eof_seen), f; }
static struct g *fd_putc(struct g *f, int c) {
  int fd = g_getnum(f->io->fd);
  if (fd >= 0 && fd < K_SOURCES_MAX && k_sources[fd].putc)
    k_sources[fd].putc(fd, c);
  return f; }
static struct g *fd_flush(struct g *f) {
  int fd = g_getnum(f->io->fd);
  if (fd >= 0 && fd < K_SOURCES_MAX && k_sources[fd].flush)
    k_sources[fd].flush(fd);
  return f; }

struct g_io g_stdin = { .ap = g_vm_port_io,
                        .fd = g_putnum(0), .ungetc_buf = g_putnum(EOF), .eof_seen = g_putnum(false), };
struct g_io g_stdout = { .ap = g_vm_port_io,
                         .fd = g_putnum(1), .ungetc_buf = g_putnum(EOF), .eof_seen = g_putnum(false), };
// No separate error stream; route err to the same fd as out (the console).
struct g_io g_stderr = { .ap = g_vm_port_io,
                         .fd = g_putnum(1), .ungetc_buf = g_putnum(EOF), .eof_seen = g_putnum(false), };

struct g_port_vt const g_fd_port_vt = { fd_getc, fd_ungetc, fd_eof, fd_putc, fd_flush };

// Override the weak g.c default; route close through k_sources[fd].
// Statics (stdin/stdout) have NULL close -- nothing to release.
void g_fd_close(int fd) {
  if (fd >= 0 && fd < K_SOURCES_MAX && k_sources[fd].close)
    k_sources[fd].close(fd); }

bool g_ready(int fd) {
  if (fd < 0) return true;
  if (fd >= K_SOURCES_MAX || !k_sources[fd].ready) return false;
  return k_sources[fd].ready(fd); }

// Multi-source wait. ticks=0 means infinite. Future: program a one-shot
// timer at the deadline instead of waking every tick.
void g_wait_fds(int const *fds, int n, uintptr_t ticks) {
  if (n <= 0) { g_sleep(ticks); return; }
  if (n > G_WAIT_FDS_MAX) __builtin_trap();
  uintptr_t deadline = kticks + ticks;
  for (;;) {
    if (ticks && kticks >= deadline) return;
    for (int i = 0; i < n; i++) if (g_ready(fds[i])) return;
    kwait(); } }
uintptr_t g_clock(void) { return kticks; }

// Pure time-wait. ticks=0 means infinite (caller is expected to pair with an
// input wait via g_in->wait, so this should only be hit when no I/O is intended).
void g_sleep(uintptr_t ticks) {
  uintptr_t deadline = kticks + ticks;
  for (;;) {
    if (ticks && kticks >= deadline) break;
    kwait(); } }

#define show_cursor 1

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

_Static_assert(LEN(kb2ascii) == LEN(shift_kb2ascii));

#define kb_code_left 75
#define kb_code_right 77
#define kb_code_up 72
#define kb_code_down 80
#define kb_code_home 71
#define kb_code_end 79
// decode a PS/2 scancode (interrupt context) and enqueue input bytes.
// arrows, Home, End, and Delete become the ANSI escape sequences the
// line editor decodes; with Ctrl held, Home / End emit the modified
// CSI form (`ESC [ 1 ; 5 H/F`) that the editor reads as buffer top /
// buffer end. Ctrl+letter becomes the matching control byte (so
// Ctrl-A/E reach the editor as home/end, Ctrl-D as quit).
// sysv_abi tag matches what x86_64.S's keyboard_isr passes -- a no-op
// for the Limine build (SysV default), required for the EFI build
// (default is MS x64) so arg0 is read out of rdi rather than rcx.
__attribute__((sysv_abi))
void kb_int(const uint8_t code) {
  if (code == kb_code_extend) { kkb.f |= kb_flag_extend; return; }
  bool ext = kkb.f & kb_flag_extend, up = code & 128;
  uint8_t sc = code & 127;
  kkb.f &= ~kb_flag_extend;
  if (ext) switch (sc) {
    case kb_code_ctl: kkb.f = up ? kkb.f & ~kb_flag_rctl : kkb.f | kb_flag_rctl; return;
    case kb_code_alt: kkb.f = up ? kkb.f & ~kb_flag_ralt : kkb.f | kb_flag_ralt; return;
    case kb_code_delete:
      if (up) return;
      if (kkb.f & kb_flag_ctl && kkb.f & kb_flag_alt) k_reset();
      kq(27), kq('['), kq('3'), kq('~'); return;       // Delete -> CSI 3 ~
    case kb_code_left:  if (!up) kq(27), kq('['), kq('D'); return;
    case kb_code_right: if (!up) kq(27), kq('['), kq('C'); return;
    case kb_code_up:    if (!up) kq(27), kq('['), kq('A'); return;
    case kb_code_down:  if (!up) kq(27), kq('['), kq('B'); return;
    case kb_code_home:
      if (up) return;
      if (kkb.f & kb_flag_ctl) kq(27), kq('['), kq('1'), kq(';'), kq('5'), kq('H');
      else kq(27), kq('['), kq('H');
      return;
    case kb_code_end:
      if (up) return;
      if (kkb.f & kb_flag_ctl) kq(27), kq('['), kq('1'), kq(';'), kq('5'), kq('F');
      else kq(27), kq('['), kq('F');
      return;
    default: return; }
  switch (sc) {
    case kb_code_lshift: kkb.f = up ? kkb.f & ~kb_flag_lshift : kkb.f | kb_flag_lshift; return;
    case kb_code_rshift: kkb.f = up ? kkb.f & ~kb_flag_rshift : kkb.f | kb_flag_rshift; return;
    case kb_code_ctl:    kkb.f = up ? kkb.f & ~kb_flag_lctl : kkb.f | kb_flag_lctl; return;
    case kb_code_alt:    kkb.f = up ? kkb.f & ~kb_flag_lalt : kkb.f | kb_flag_lalt; return;
    default:
      if (up || sc >= LEN(kb2ascii)) return;
      uint8_t a = (kkb.f & kb_flag_shift ? shift_kb2ascii : kb2ascii)[sc];
      if (a && kkb.f & kb_flag_ctl && (a | 32) >= 'a' && (a | 32) <= 'z') a &= 31;
      if (a) kq(a);
      return; } }


static g_inline struct mem *after(struct mem *r) {
  return (struct mem*) ((uintptr_t*) r + r->len); }

static void *kmallocw(uintptr_t n) {
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

static void kfree(void *p) {
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

void *malloc(size_t n) { return kmallocw(b2w(n)); }
void free(void *x) { return kfree(x); }

static g_vm(g_kreset) { return k_reset(), f; }

void fbdraw(void) {
  if (!kcb) return;                    // serial-only: no framebuffer console
  for (uint8_t i = 0, rows = kcb->rows; i < rows; i++)
    for (uint8_t j = 0, cols = kcb->cols; j < cols; j++) {
      uint32_t const
       pos = i * cols + j,
       _g = kcb->cb[pos];
      struct font *ff = fonts[cb_font(_g)];
      uint8_t const
       g = _g,
       *bmp = ff->glyphs + ff->h * (g == '\n' ? 0 : g);
      bool invert = kcb->flag & show_cursor && kcb->wpos == pos && kticks & 64;
      uint32_t fg = palette[cb_fg(_g)], bg = palette[cb_bg(_g)];
      if (invert) fg ^= bg, bg ^= fg, fg ^= bg;
      uintptr_t y = i * ff->h, x = j * ff->w;
      for (uint8_t r = 0; r < ff->h; r++)
        for (uint8_t o = bmp[r], c = ff->w; c--; o >>= 1)
          kfb._[(y + r) * kfb.pitch + x + c] = o & 1 ? fg : bg; } }

static g_vm(draw) {
  fbdraw();
  kwait();
  Ip += 1;
  return Continue(); }


static g_vm(key) {
 int b = kqpop();
 Sp[0] = g_putnum(b < 0 ? 0 : b);
 Ip += 1;
 return Continue(); }

static g_vm(color) {
 uint8_t fg = g_getnum(*Sp++), bg = g_getnum(*Sp++);
 if (kcb) {
  cb_attr(kcb, fg, bg, 0);
  for (uint32_t i = 0, j = kcb->rows * kcb->cols; i < j; i++)
   kcb->cb[i] = cb_cell(cb_ch(kcb->cb[i]), fg, bg, 0); }
 return Ip += 1, Continue(); }

// (fault n) -- deliberately raise a CPU exception to exercise the
// handler in arch.c. k_fault_trigger (in each arch's arch.c) maps n
// to a concrete fault: the cases mirror x86_64 vector numbers, and the
// per-arch implementation picks the analogous fault for that target.
// the handler reports and halts, so k_fault_trigger does not return;
// the post-call statements are reachable only if the fault did not fire.
static g_vm(g_vm_fault) {
  k_fault_trigger(g_getnum(Sp[0]));
  Ip += 1;
  return Continue(); }



static union u
  bif_reset[] = {{g_kreset}},
  bif_draw[] = {{draw}, {g_vm_ret0}},
  bif_key[] = {{key}, {g_vm_ret0}},
  bif_color[] = {{g_vm_cur}, {.x = g_putnum(2)}, {color}, {g_vm_ret0}},
  bif_fault[] = {{g_vm_fault}, {g_vm_ret0}};

// Reads the bootloader-populated kboot struct (Limine or UEFI) and
// links every reported free range into the kernel free list. The
// chained-into-kmem order matches the previous Limine-walk order:
// entries are pushed in array order, so kmem ends up pointing at the
// last entry, with earlier entries linked through ->next.
static bool meminit(void) {
  if (!kboot.ram_n) return false;
  for (uint32_t i = 0; i < kboot.ram_n; i++) {
    struct mem *m = (struct mem*) (kboot.hhdm + kboot.ram[i].base);
    m->len = kboot.ram[i].len / sizeof(uintptr_t);
    m->next = kmem;
    kmem = m; }
  return true; }

static bool fbinit(void) {
  if (!kboot.has_fb) return false;
  kfb._      = kboot.fb.base;
  kfb.width  = kboot.fb.w;
  kfb.height = kboot.fb.h;
  kfb.pitch  = kboot.fb.pitch_px;
  return true; }

static bool cbinit(void) {
  const uintptr_t rows = kfb.height / kfont.h,
                  cols = kfb.width / kfont.w;
  if (!(kcb = malloc(sizeof(struct cb) + rows * cols * sizeof(uint32_t)))) return false;
  kcb->rows = rows;
  kcb->cols = cols;
  kcb->rpos = kcb->wpos = kcb->spos = kcb->esc = 0;
  kcb->flag = show_cursor;
  cb_attr(kcb, 47, 56, 0);
  cb_fill(kcb, 0);
  return true; }

static struct g_def defs[] = {
  {"reset", (intptr_t) bif_reset},
  {"draw", (intptr_t) bif_draw},
  {"key", (intptr_t) bif_key},
  {"fault", (intptr_t) bif_fault},
  {"color", (intptr_t) bif_color},
  {0}, };

void kmain(void) {
#if defined(__x86_64__)
 // Enable x87/SSE before ANY other C runs. Limine doesn't guarantee SSE is
 // on, and clang auto-vectorizes freely on x86_64 -- even the struct copies
 // in limine_to_kboot below compile to movups, which #UDs (-> triple fault,
 // no output) if SSE is still masked. CR0: clear EM (no FPU emulation), set
 // MP; CR4: set OSFXSR | OSXMMEXCPT. The "memory" clobber keeps clang from
 // hoisting any vectorized access above this. This is the single SSE-enable
 // point -- archinit no longer repeats it. (EFI firmware already has SSE on,
 // but re-asserting it here is harmless.)
 asm volatile(
  "mov %%cr0, %%rax\n\t"
  "and $~(1 << 2), %%rax\n\t"          // CR0.EM = 0
  "or  $(1 << 1), %%rax\n\t"           // CR0.MP = 1
  "mov %%rax, %%cr0\n\t"
  "mov %%cr4, %%rax\n\t"
  "or  $((1 << 9) | (1 << 10)), %%rax\n\t"  // CR4.OSFXSR | CR4.OSXMMEXCPT
  "mov %%rax, %%cr4\n\t"
  ::: "rax", "memory");
#endif
#ifndef K_EFI
 // Limine path: copy the requested responses into kboot before anything
 // else reads it. The EFI path has already populated kboot in efi_main.
 limine_to_kboot();
#endif
 khhdm = kboot.hhdm;
 archinit();
 serial_init();
 // the heap (meminit) is the only hard requirement. the framebuffer
 // console is optional: when fbinit/cbinit fail -- no Limine
 // framebuffer, or the console buffer won't allocate -- kcb stays null
 // and the kernel runs headless on the serial console alone.
 if (meminit()) {
  if (fbinit() && cbinit()) palette_init();
  // load the prelude, then run the gwen read-eval-print loop. its line
  // editor (in repl.g) drives the console; PS/2 keyboard and serial
  // input both arrive as ANSI escape sequences the gwen edev decodes.
  g_fin(g_evals_(g_defs(g_ini(), defs),
#include "boot.h"
#include "repl.h"
 "(repl 0 0)"
  )); }
 k_reset(); }
