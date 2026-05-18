#include "limine/limine.h"
#include "g.h"
#include "cb.h"
#include <stdarg.h>
#include <limits.h>

uint64_t kticks;

static struct mem {
  struct mem *next;
  uintptr_t len;
  uintptr_t _[];
} *kmem;

struct cb *kcb;

static struct {
  volatile uint32_t *_;
  uint16_t width, height, pitch; } kfb;

static struct { uint8_t k, f; } kkb;

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


void k_reset(void);
void archinit(void);

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

static struct g *_putc(struct g*f, int c, struct g_out*) { return cb_putc(kcb, c), f; }
static struct g* _flush(struct g*f, struct g_out*) { kcb->rpos = kcb->wpos; return f; }
static struct g*_getc(struct g*f, struct g_in*) { return g_core_of(f)->b = cb_getc(kcb), f; }
static struct g* _ungetc(struct g*f, int c, struct g_in*) { return g_core_of(f)->b = cb_ungetc(kcb, c), f; }
static struct g* _eof(struct g*f, struct g_in*) { return g_core_of(f)->b = cb_eof(kcb), f; }
struct g_in _g_stdin = { .getc = _getc, .ungetc = _ungetc, .eof = _eof, },
            *g_stdin = &_g_stdin;
struct g_out _g_stdout = { .putc = _putc, .flush = _flush, },
             *g_stdout = &_g_stdout;
uintptr_t g_clock(void) { return kticks; }

#define show_cursor 1
#define blue 0xff
#define green 0xff00
#define red 0xff0000
#define cyan (blue|green)
#define yellow (red|green)
#define white (yellow|blue)
#define magenta (red|blue)
#define black 0
#define console_bg black
#define console_fg 0xe9edf0
#define console_cur 0x6ba7a2
#define console_sel 0xc3e4e0

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
void kb_int(const uint8_t code) {
  if (code == kb_code_extend) kkb.f |= kb_flag_extend;
  else if (kkb.f & kb_flag_extend) {
    kkb.f &= ~kb_flag_extend;
    uint16_t r = kcb->rpos,
             w = kcb->wpos,
             cs = kcb->cols;
    if (code < 128) switch (code) {
      case kb_code_alt: kkb.f |= kb_flag_ralt; return;
      case kb_code_ctl: kkb.f |= kb_flag_rctl; return;
      case kb_code_delete:
        if (kkb.f & kb_flag_ctl && kkb.f & kb_flag_alt) k_reset();
        return;
      case kb_code_left: w -= 1; goto move_cursor;
      case kb_code_right: w += 1; goto move_cursor;
      case kb_code_up: w -= cs; goto move_cursor;
      case kb_code_down: w += cs; 
      move_cursor:
        w %= kcb->rows * cs;
        w = MAX(w, r);
        kcb->wpos = w;
      default: return; }
    else switch (code - 128) {
      case kb_code_alt: kkb.f &= ~kb_flag_ralt; return;
      case kb_code_ctl: kkb.f &= ~kb_flag_rctl; return;
      default: return; } }
  else {
    if (code < 128) switch (code) {
      case kb_code_lshift: kkb.f |= kb_flag_lshift; return;
      case kb_code_rshift: kkb.f |= kb_flag_rshift; return;
      case kb_code_alt:    kkb.f |= kb_flag_lalt;   return;
      case kb_code_ctl:    kkb.f |= kb_flag_lctl;   return;
      default:
        if (!kkb.k) kkb.k = code >= LEN(kb2ascii) ? code :
          (kkb.f & (kb_flag_lshift | kb_flag_rshift) ? shift_kb2ascii : kb2ascii)[code];
        return; }
    else switch (code - 128) {
      case kb_code_lshift: kkb.f &= ~kb_flag_lshift; return;
      case kb_code_rshift: kkb.f &= ~kb_flag_rshift; return;
      case kb_code_alt:    kkb.f &= ~kb_flag_lalt;   return;
      case kb_code_ctl:    kkb.f &= ~kb_flag_lctl;   return;
      default: return; } } }

#define px_color cyan
#define reg_color magenta
#define mem_color yellow

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
 Sp[0] = g_putnum(kkb.k);
 kkb.k = 0;
 Ip += 1;
 return Continue(); }

static g_vm(color) {
 uint8_t fg = g_getnum(*Sp++), bg = g_getnum(*Sp++);
 cb_attr(kcb, fg, bg, 0);
 for (uint32_t i = 0, j = kcb->rows * kcb->cols; i < j; i++)
  kcb->cb[i] = cb_cell(cb_ch(kcb->cb[i]), fg, bg, 0);
 return Ip += 1, Continue(); }

// (fault n) -- deliberately raise CPU exception n to exercise the
// handler in arch.c. the handler reports and halts, so this does not
// return. n picks the vector: 0 #DE, 3 #BP, 13 #GP, 14 #PF; anything
// else (e.g. 6) raises #UD -- the same path __builtin_trap() takes.
static g_vm(fault) {
  switch (g_getnum(Sp[0])) {
    case 0:   // #DE: integer divide by zero
      asm volatile ("xorl %%edx,%%edx; movl $1,%%eax; xorl %%ecx,%%ecx;"
                    "divl %%ecx" ::: "eax","ecx","edx");
      break;
    case 3:   // #BP: breakpoint
      asm volatile ("int3");
      break;
    case 13:  // #GP: write through a non-canonical address
      *(volatile int*) 0xdeadbeefdeadbeefULL = 0;
      break;
    case 14:  // #PF: write to a canonical but unmapped address
      *(volatile int*) 0x600000000000ULL = 0;
      break;
    default:  // #UD: invalid opcode
      asm volatile ("ud2");
      break; }
  Ip += 1;                 // unreachable unless the fault did not fire
  return Continue(); }



static union u
  bif_reset[] = {{g_kreset}},
  bif_draw[] = {{draw}, {g_vm_ret0}},
  bif_key[] = {{key}, {g_vm_ret0}},
  bif_color[] = {{g_vm_cur}, {.x = g_putnum(2)}, {color}, {g_vm_ret0}},
  bif_fault[] = {{fault}, {g_vm_ret0}};

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
  kcb->rpos = kcb->wpos = 0;
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
 archinit();
 if (fbinit() && meminit() && cbinit())
  palette_init(),
  g_evals_(g_defs(g_ini(), defs),
#include "boot.h"
   "(:(ps1 _)(puts\" ;; \")E(sym()))"
   "(:(rs x)(?(= x E)0(X x(rs(read E)))))"
   "(:(ep x)(: _(.(ev x))(putc 10)))"
   "(puts\"\x02 \")(putn(clock())10)(ps1(putc 10))"
   "(:(go _)(go(draw(: k(key())(? k(: _(putc k)_(?(= k 10)(ps1(each(rs(read E))ep)))k)))))(go()))");
 k_reset(); }
