#include "limine/limine.h"
#include "g.h"
#include "cb.h"
#include <stdarg.h>
#include <limits.h>

uint64_t kticks;
// Limine higher-half direct map offset: physical address P is reachable
// at khhdm + P. set in kmain before archinit, so arch code can map MMIO.
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

// console output goes to the framebuffer when one is present, and is
// always mirrored to the COM1 serial console.
static struct g *_putc(struct g*f, int c, struct g_out*) {
  if (kcb) cb_putc(kcb, c);
  return serial_putc(c), f; }
static struct g *_flush(struct g*f, struct g_out*) { return fbdraw(), f; }
// the keystroke source the line editor reads: block until a byte is
// queued, pumping the framebuffer meanwhile so the cursor keeps
// blinking. it never allocates, so f stays valid across the call.
static struct g *k_getc(struct g*f, struct g_in*) {
  int b;
  while ((b = kqpop()) < 0) fbdraw(), kwait();
  return g_core_of(f)->b = b, f; }
// (key?) backend: non-consuming check on the kb queue. No EOF state on bare
// metal, so this is just "queue non-empty".
bool g_key(void) { return kkb.qh != kkb.qt; }
static struct g *k_ungetc(struct g*f, int c, struct g_in*) { return f; }
static struct g *k_eof(struct g*f, struct g_in*) { return g_core_of(f)->b = 0, f; }
struct g_in _g_stdin = { .getc = k_getc, .ungetc = k_ungetc, .eof = k_eof, },
            *g_stdin = &_g_stdin;
struct g_out _g_stdout = { .putc = _putc, .flush = _flush, },
             *g_stdout = &_g_stdout;
uintptr_t g_clock(void) { return kticks; }

// Deep wait: the timer ISR ticks kticks and the keyboard ISR queues bytes;
// kwait halts until any interrupt fires. Loop until either the deadline
// passes or input becomes available, so a task suspended in g_vm_getc can
// resume without waiting out the full deadline. Future optimization: program
// a one-shot timer at the deadline so we wake exactly once instead of on
// every tick in between.
void g_wait(uintptr_t ticks) {
  uintptr_t deadline = kticks + ticks;
  while (kticks < deadline && !g_key()) kwait(); }

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

static bool meminit(void) {
  if (!memmap_req.response || !hhdm_req.response) return false;
  struct mem *m;
  struct limine_memmap_entry *r, **rr = memmap_req.response->entries;
  uintptr_t hhdm = hhdm_req.response->offset,
            n = memmap_req.response->entry_count;
  while (n--) if ((r = rr[n])->type == 0)
    m = (struct mem*) (hhdm + r->base),
    m->len = r->length / sizeof(uintptr_t),
    m->next = kmem,
    kmem = m;
  return true; }

static bool fbinit(void) {
  if (!fb_req.response || !fb_req.response->framebuffer_count) return false;
  struct limine_framebuffer *f = fb_req.response->framebuffers[0];
  kfb._ = f->address;
  kfb.width = f->width;
  kfb.height = f->height;
  kfb.pitch = f->pitch >> 2;
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
 khhdm = hhdm_req.response ? hhdm_req.response->offset : 0;
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
  struct g *f = g_defs(g_ini(), defs);
  f = g_evals_(f,
#include "boot.h"
  );
  f = g_evals_(f,
#include "repl.h"
  );
  g_evals_(f, "(repl 0 0)"); }
 k_reset(); }
