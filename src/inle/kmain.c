#include "k.h"
#include "love.h"
#include "cats.h"
#include "quay.h"
#include "asmops.h"                    // the privileged instructions, both spellings
#include "bput.h"
#include <stdarg.h>
#include <limits.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>      // the E numbers only: no errno variable down here

uint64_t kticks;
// 100 Hz on every arch (mkvec.l's PIT divisor, a64's cntfrq/100): every deadline rounds up to it
#define k_tick_ms 10
static uintptr_t k_ticks_for(uintptr_t ms) { return (ms + k_tick_ms - 1) / k_tick_ms; }
// physical P is at khhdm + P; set before archinit, so arch code can use it for MMIO
uintptr_t khhdm;
// the hhdm is NX throughout (mkboot.l), so code runs through the image window k_xw;
// hosted, khhdm is 0
char *code_window(char *p) { return khhdm ? (char*)((uintptr_t) p - khhdm + k_xw) : p; }

#include "ffalloc.h"
static struct mem *kmem;

// free RAM in words, summed by meminit: it bounds the collector
static uintptr_t kram_words;

static struct cb *kcb;
// the picture store: three screenfuls, 8 MB at least, a dense screen's capped
static uint32_t k_sn(uintptr_t rows, uintptr_t cols) {
  uint32_t const n = rows * cols <= 16384u ? (uint32_t) (rows * cols) : 16384u, sn = 3u * n * 512u;
  return (uint32_t) cb_shead + (sn > 8u << 20 ? sn : 8u << 20); }
// five hundred lines of history, fewer past 1 MB
static uint32_t k_hl(uintptr_t cols) {
  uint32_t const most = (uint32_t) ((1u << 20) / cb_hsize(1, cols));
  return most < 500u ? most : 500u; }
static uint8_t *kqf;   // the loaded font (/proc/vt/font), vetted, or 0


static struct {
  volatile uint32_t *_;
  uint16_t width, height, pitch;
  uint8_t scale;
  uint32_t cap_px; } kfb;            // scale = px per glyph px; cap_px = the paper's bound

// kb_int decodes into q/qh/qt; g the modifiers; raw arms the scancode tap r/rh/rt. peer and
// snap ask for history scroll. a paste streams through q (pasting, pbr, pprev); a press anchors
// a selection (anchor, tp, clicks; at the cell). a window holding the paper (hold) takes the
// pointer on pq/pqh/pqt and hears the paper's size (sw, sh)
static struct { uint8_t g, q[64], qh, qt; uint16_t lost;
                uint8_t raw, r[64], rh, rt;
                int16_t peer; uint8_t snap;          // shift+pgup/pgdn asks, a key snaps back
                uint8_t pasting, pbr, pprev, clicks;
                intptr_t anchor; uint64_t tp; uint32_t at;
                uint8_t hold, pqh, pqt; uint16_t pq[16][4], sw, sh; } kkb;
// k_uart feeds the same queue; an interrupt cannot wait, so a drop is counted, saturating
void kq(uint8_t b) {
  uint8_t n = (kkb.qt + 1) & 63;
  if (n != kkb.qh) kkb.q[kkb.qt] = b, kkb.qt = n;
  else if (kkb.lost != (uint16_t) -1) kkb.lost++; }
static int kqpop(void) {                   // dequeue one byte, -1 if empty
  if (kkb.qh == kkb.qt) return -1;
  int b = kkb.q[kkb.qh];
  return kkb.qh = (kkb.qh + 1) & 63, b; }

// kfb.scale says how large, paint.c the palette
static struct font const kface = { (uint8_t const*) cleat_8x16, 8, 16 };

// fd.c branches to these on a negative osv
void k_row_close(int fd), k_sleep(uintptr_t ms), k_wait_fds(struct wait_fd*, int, uintptr_t),
     k_seat_init(void);                // sys.c: environ and the std streams
bool k_ready(int fd, int events);

// the panic-time console: no l state, so it runs from a fault handler
void kputc(int c) { if (kcb) cb_putc(kcb, (char) c); serial_putc(c); }
void kputs(char const *s) { bput_s(kputc, s); }
void kputn(uintptr_t n, int base) { bput_n(kputc, n, (unsigned) base); }
// the kernel-only nifs (defs[] below), bracketed by the linker
extern struct def const __start_knifs[], __stop_knifs[];
// for the image codec's nif slice
uintptr_t knifs_slice(struct def const **s) {
  return *s = __start_knifs, (uintptr_t)(__stop_knifs - __start_knifs); }
// the metal image's far edge, patched in by kproject.l; unpatched, the heap eats the image
uintptr_t const k_image_top = 1;
// where the pie's base landed and its data copy, for x64/proc.c; unpatched, none
uintptr_t const k_pie_base = 0, k_pie_data = 0;

#include "quay.h"
#include <stdarg.h>
// the machine as the door found it (pvh, uefi, a64's dtb), filled before kmain reads it
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

// the source table: each fd's row of methods, a NULL one skipped (writes discard, reads
// the end, ready false); state is per row. grows through k_source_open to k_fd_most
void *kmallocw(uintptr_t n), *kmallocwa(uintptr_t n, uintptr_t a), *k_grab(uintptr_t n);
void kfree(void *p), k_drop(void *p);

struct k_source {
  // love.h's readn, one fd deeper: >0 bytes, 0 nothing, -1 end
  intptr_t (*readn)(int fd, unsigned char *dst, uintptr_t n),
  // >0 taken, 0 busy, -1 gone; asked before putc, so the ramfs can refuse a byte, not drop it
           (*writen)(int fd, unsigned char const *src, uintptr_t n);
  bool (*ready)(int fd);                // non-blocking probe
  void (*putc)(int fd, int c),
       (*flush)(int fd),
       (*close)(int fd),                // release per-fd state
       *state; };

// a seat with no keyboard interrupt (wasm) is asked whenever a task wants a key, told the room
__attribute__((weak)) void k_kb_sync(int room) { (void) room; }
void k_kb_poll(void) { k_kb_sync(63 - ((kkb.qt - kkb.qh) & 63)); }

// a seat's paste in pieces: the bracket around the whole when the program asked, the view
// brought home; k_paste_end once it runs dry
void k_paste_in(uint8_t const *s, long n) {
  if (!kkb.pasting) {
    kkb.pasting = 1, kkb.pprev = 0, kkb.pbr = kcb && kcb->flag & cb_paste, kkb.snap = 1;
    if (kkb.pbr) for (char const *p = cb_popen; *p; p++) kq((uint8_t) *p); }
  for (long i = 0; i < n; i++) {
    int const b = cb_paste1(kkb.pprev, s[i]);
    kkb.pprev = s[i];
    if (b >= 0) kq((uint8_t) b); } }
void k_paste_end(void) {
  if (!kkb.pasting) return;
  if (kkb.pbr) for (char const *p = cb_pshut; *p; p++) kq((uint8_t) *p);
  kkb.pasting = 0; }

// to a seat's clipboard; metal has none
__attribute__((weak)) void k_copy_out(uint8_t const *s, uintptr_t n) { (void) s, (void) n; }

// how 0 press, 1 release, 2 move; b the button (0 1 2, 64 65 the wheel, 3 none) | 4 shift
// 8 meta 16 ctrl. a window holding the paper takes it whole; else the console cell under it,
// a move once a cell: the mouse report if asked (cb_mouse), else (or with shift) the left
// button selects (a second, third quick press the word, the line), the wheel scrolls
void k_pointer(uint32_t how, uint32_t b, uint32_t y, uint32_t x) {
  if (kkb.hold) {
    uint8_t const n = (kkb.pqt + 1) & 15;
    uint16_t *const p = kkb.pq[kkb.pqt];
    if (n != kkb.pqh) p[0] = (uint16_t) how, p[1] = (uint16_t) b, p[2] = (uint16_t) x, p[3] = (uint16_t) y, kkb.pqt = n;
    return; }
  if (!kcb || !kfb.scale) return;
  uint32_t const row = y / (kface.h * kfb.scale), col = x / (kface.w * kfb.scale), at = row << 16 | col;
  if (how == 2 && at == kkb.at) return;
  kkb.at = at;
  if (row >= kcb->rows || col >= kcb->cols) return;
  uint32_t const btn = b & ~28u;
  if (!(b & 4) && kcb->flag & cb_mice) {
    uint8_t o[cb_mousen];
    for (uint32_t i = 0, n = cb_mouse(kcb, o, b, row, col, how); i < n; i++) kq(o[i]);
    return; }
  if (btn == 64 || btn == 65) {
    if (how) return;
    if (kcb->flag & cb_alt) for (int k = 0; k < 3; k++) kq(27), kq('['), kq(btn == 64 ? 'A' : 'B');
    else {
      intptr_t const v = (intptr_t) kcb->view + (btn == 64 ? 3 : -3);
      cb_peer(kcb, v < 0 ? 0u : (uint32_t) v), fbdraw(); }
    return; }
  if (btn) return;
  intptr_t const gi = ((intptr_t) row - (intptr_t) kcb->view) * kcb->cols + col;
  if (how == 0) {
    kkb.clicks = kticks - kkb.tp < 40 && gi == kkb.anchor && kkb.clicks < 3 ? kkb.clicks + 1 : 1;
    kkb.tp = kticks, kkb.anchor = gi;
    cb_select(kcb, gi, gi, kkb.clicks > 1 ? kkb.clicks - 1u : 3u); }
  else if (how == 2) cb_select(kcb, kkb.anchor, gi, kkb.clicks - 1u);
  else if (kcb->sel0 < kcb->sel1) {
    uintptr_t const n = cb_copied(kcb, 0, kcb->sel0, kcb->sel1);
    uint8_t *t = k_grab(n + 1);
    if (t) cb_copied(kcb, t, kcb->sel0, kcb->sel1), k_copy_out(t, n), k_drop(t); }
  fbdraw(); }

// slot 0: the keyboard; 0 when empty, never the end
static intptr_t kb_readn(int fd, unsigned char *dst, uintptr_t n) {
  k_kb_poll();
  uintptr_t k = 0;
  for (int b; k < n && (b = kqpop()) >= 0; ) dst[k++] = (unsigned char) b;
  return (intptr_t) k; }

static bool kb_ready(int fd) { return k_kb_poll(), kkb.qh != kkb.qt; }

// the cluster pool doubled when full; kputc, which may run from a fault, never grows it
static void k_cb_grow(void) {
  uint32_t const most = cb_clumax - cb_nclu, add = kcb->cx ? kcb->cx : cb_nclu,
                 cx = add < most - kcb->cx ? kcb->cx + add : most;
  uintptr_t const n = cb_laid(kcb);
  struct cb *c = kmallocw(b2w(n + cb_xsize(cx - kcb->cx)));
  if (!c) return;
  memcpy(c, kcb, n);
  cb_xclu(c, cx);
  struct cb *const old = kcb;
  kcb = c, kfree(old); }   // published whole before the old goes

// slot 1: the console, mirrored to COM1
static void serial_putc1(int fd, int c) {
  if (kcb) cb_putc(kcb, c);
  if (kcb && kcb->cfull && kcb->cx < cb_clumax - cb_nclu) k_cb_grow();
  serial_putc(c); }

// kq's drops, said before the frame goes up
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
  if (!kkb.hold) fbdraw(); }

// static: the console is how an allocation failure is said. err has its own fd, so out
// can ride a pipe while a scare stays here
static struct k_source k_boot[] = {
  [0] = { .readn = kb_readn,    .ready = kb_ready    },
  [1] = { .putc = serial_putc1, .flush = serial_flush },
  [2] = { .putc = serial_putc1, .flush = serial_flush }, };
static struct k_source *k_sources = k_boot;
static int k_sources_n = (int) countof(k_boot);

// the file's one bounds check
static love_inline struct k_source *k_source(int fd) {
 return fd >= 0 && fd < k_sources_n ? &k_sources[fd] : NULL; }

// a closed row is zeroed in place, never removed: any method at all is live
static love_inline bool k_row_live(int fd) {
 struct k_source const *s = k_source(fd);
 return s && (s->readn || s->writen || s->putc || s->flush || s->ready || s->close); }

// fd's row, doubling the table first (no realloc down here; the boot table is never freed).
// NULL must be read; the ceiling keeps the doubling inside an int
#define k_fd_most (1 << 16)
static struct k_source *k_source_open(int fd) {
 if (fd < 0 || fd >= k_fd_most) return NULL;
 if (fd >= k_sources_n) {
  int m = k_sources_n;
  while (m <= fd) m *= 2;
  if (m > k_fd_most) m = k_fd_most;
  struct k_source *t = k_grab((uintptr_t) m * sizeof *t);
  if (!t) return NULL;
  for (int i = 0; i < m; i++)
    t[i] = i < k_sources_n ? k_sources[i] : (struct k_source) {0};
  if (k_sources != k_boot) k_drop(k_sources);
  k_sources = t, k_sources_n = m; }
 return &k_sources[fd]; }

// a task wears (i o e) real ports (prel's wear) and io_route swaps them in, so io_fd is the row

// the run ring's head runs (love.c), its pid at node[2]; the main task reads 0
static love_inline intptr_t k_cur_pid(struct g *g) {
 union u *t = core_of(g)->tasks;
 return t && (t[2].x & 1) ? getcharm(t[2].x) : 0; }

// on a resolved fd: the syscall door and the raw-fd lanes skip the seat
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

// fd.c's port lanes on a negative osv: busy and end are distinct, as read(2) cannot say
intptr_t k_port_readn(struct g *g, unsigned char *dst, uintptr_t n) {
 return k_row_read((int) io_fd(g->io), dst, n); }

struct g *k_port_writen(struct g *g, unsigned char const *src, uintptr_t n) {
 return g->b = k_row_write((int) io_fd(g->io), src, n), g; }

// sys.c's posix door: read(2) says end with 0, the rows with -1
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

struct g *k_port_flush(struct g *g) {
 int fd = (int) io_fd(g->io);
 struct k_source *s = k_source(fd);
 if (s && s->flush) s->flush(fd);
 return g; }

// fd.c's love_fd_close on inle; the boot rows have no close
void k_row_close(int fd) {
 struct k_source *s = k_source(fd);
 if (s && s->close) s->close(fd); }

// a row that can take a byte always can: out is always ready
bool k_ready(int fd, int events) {
 if (fd < 0) return true;
 if (events != wait_in) return true;
 struct k_source *s = k_source(fd);
 return s && s->ready && s->ready(fd); }

// a file always reads
bool k_fd_blocks(int fd) {
 struct k_source *s = k_source(fd);
 return s && s->ready && !s->ready(fd); }

// a seat with no timer interrupt (wasm) catches kticks up here
__attribute__((weak)) void k_tick_sync(void) { }

// a frame before the machine stops, or an idle screen holds half a cursor blink
static void k_park(void) {
  if (!kkb.hold) fbdraw();
  k_horn_poll();
  k_wait(); }

void k_wait_fds(struct wait_fd *fds, int n, uintptr_t ms) {
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

// ms since the epoch, for deadlines, (clock t) and mtimes; with no date in kboot, since boot
uintptr_t k_clock_ms(void) {
  k_tick_sync();
  return (uintptr_t) (kboot.date * 1000 + kticks * k_tick_ms); }

// ms 0 is forever. a seat that sleeps finer than the tick (wasm) answers true; metal rounds up
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
#define kb_code_pgup 73
#define kb_code_pgdn 81
// a code is the PS/2 byte, an 0xe0 prefix folded into 0x100 on the next (bit 7 the break)
void k_scan_arm(int on) { kkb.raw = on ? 1 : 0, kkb.rh = kkb.rt = 0; }
// a seat handed its codes asks before leaving a lane full that nothing would empty
bool k_scan_armed(void) { return kkb.raw != 0; }
// a seat whose codes are polled (wasm) fills the tap here
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
// a code whose text arrives on its own lane (wasm's scan ring)
void k_scan_put(uint8_t b) { if (kkb.raw) kraw(b); }
// the paper drawn by a writer of its own (doom.c): a page showing it wants to hear (wasm)
__attribute__((weak)) void k_fb_touch(void) { }

// interrupt context: arrows, Home, End, PgUp, PgDn, Delete as ANSI escapes, Ctrl+Home/End as
// `ESC [ 1 ; 5 H/F`, Ctrl+letter its control byte; Shift+PgUp/PgDn scroll half a screen
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
    case kb_code_pgup: case kb_code_pgdn:
      if (up) return;
      if (kkb.g & kb_flag_shift) { kkb.peer += sc == kb_code_pgup ? 1 : -1; return; }
      kq(27), kq('['), kq(sc == kb_code_pgup ? '5' : '6'), kq('~');
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
      if (a) kq(a), kkb.snap = 1;
      return; } }


void *kmallocw(uintptr_t n) { return ff_alloc(&kmem, n); }

// n words aligned to a bytes, freed by kfree
void *kmallocwa(uintptr_t n, uintptr_t a) { return ff_alloc_aligned(&kmem, n, a); }

void kfree(void *p) { ff_free(&kmem, p); }

// small objects ride malloc; kmallocw keeps the pages and regions
void *k_grab(uintptr_t n) { return malloc(n); }
void k_drop(void *p) { free(p); }


// the ramfs: the initrd (srctree through vfs.c) lays one row per file at boot, each section
// decoding at its first read; the first write copies a file into the heap. k_grab, not alloc:
// a vt method has no g. ms is the baked mtime
#include "archive/ustar.h"
#include "archive/srctree.h"
#include "vfs.h"
// the tree lives read-only under /love, so a module loads bytes the shell cannot have edited;
// the root holds src/inle/rootfs/, a second tar with no prefix
static char const k_home[] = "home";
static char const k_tree[] = "love";

// a strong k_baked bakes this link's own files: asked for the count, then to fill
__attribute__((weak)) int k_baked(struct vfs_file *rows, int cap) {
  return (void) rows, (void) cap, 0; }

// /proc/vt: the colours as xterm-256 indices, refreshed at open, applied at close; font
// takes a font.l font for the code points the built-in lacks, an empty write drops it
static char const k_vtfg[] = "proc/vt/fg", k_vtbg[] = "proc/vt/bg",
                  k_vtscale[] = "proc/vt/scale", k_vtfont[] = "proc/vt/font";
// /proc/lift: a path written asks the seat to carry that file out (the page's download)
static char const k_plift[] = "proc/lift";
__attribute__((weak)) void k_lift_ask(unsigned char const *p, uintptr_t n) { (void) p; (void) n; }
// filled at open from the running machine, below the grow door they need
static char const k_pmem[] = "proc/meminfo", k_pgauge[] = "proc/gauge";
static char const k_pcmd[] = "proc/cmdline";
// the image the door handed in, for a process to wake from
static char const k_pimg[] = "proc/image";
// the file the door carried in beside the kernel
static char const k_pinitrd[] = "proc/initrd";
// null is the table's empty slot, zero that slot with a read door: entries only for stat and dents
static char const k_dnull[] = "dev/null", k_dzero[] = "dev/zero";
// 0 neither, 1 null, 2 zero
static int k_dev_slot(char const *p, uintptr_t n) {
  if (n == sizeof k_dnull - 1 && !memcmp(p, k_dnull, n)) return 1;
  if (n == sizeof k_dzero - 1 && !memcmp(p, k_dzero, n)) return 2;
  return 0; }
static intptr_t k_zero_readn(int fd, unsigned char *dst, uintptr_t n) {
  return memset(dst, 0, n), (intptr_t) n; }
// a row with no hook is no row (k_dup_row refuses it), and 2>/dev/null dups this one
static intptr_t k_null_writen(int fd, unsigned char const *src, uintptr_t n) {
  return (intptr_t) n; }
static bool k_dev_ready(int fd) { return true; }

// 0 neither, 1 fg, 2 bg, 3 the glyph scale, 4 the lift, 5 the font
static int k_vt_slot(char const *p, uintptr_t n) {
  if (n == sizeof k_vtfg - 1 && !memcmp(p, k_vtfg, n)) return 1;
  if (n == sizeof k_vtbg - 1 && !memcmp(p, k_vtbg, n)) return 2;
  if (n == sizeof k_vtscale - 1 && !memcmp(p, k_vtscale, n)) return 3;
  if (n == sizeof k_plift - 1 && !memcmp(p, k_plift, n)) return 4;
  if (n == sizeof k_vtfont - 1 && !memcmp(p, k_vtfont, n)) return 5;
  return 0; }

static bool k_vt_rescale(unsigned v);                // below, with fbdraw's cached cursor
static void fbwash(void);                            // below: the whole paper again

// /mnt/host: a seat with files of its own (the page's storage, a node directory) answers
// k_host, one call an operation, the path relative to the mount; metal's kh_here is 0, no mount
enum { kh_here, kh_stat, kh_open, kh_pread, kh_pwrite, kh_trunc, kh_close, kh_fstat,
       kh_list, kh_mkdir, kh_rmdir, kh_unlink, kh_rename };
__attribute__((weak)) long k_host(long op, long a, long b, long c, long d, long e) {
  (void) a, (void) b, (void) c, (void) d, (void) e;
  return op == kh_here ? 0 : -ENODEV; }
static char const k_mnt[] = "mnt/host";
#define k_mnt_n (sizeof k_mnt - 1)
static bool k_mnt_up;                          // k_fs_init laid the mount
// where a path's tail under the mount starts, k_mnt_n for the mount itself, -1 elsewhere
static intptr_t k_hosted(char const *cp, uintptr_t cn) {
  if (!k_mnt_up || cn < k_mnt_n || memcmp(cp, k_mnt, k_mnt_n)) return -1;
  if (cn == k_mnt_n) return (intptr_t) cn;
  return cp[k_mnt_n] == '/' ? (intptr_t) k_mnt_n + 1 : -1; }

// a move or a removal leaves these be: a special row, and every directory above one
static char const *const k_pins[] = { k_vtfg, k_vtbg, k_vtscale, k_vtfont, k_plift,
                                      k_pmem, k_pgauge, k_pcmd, k_dnull, k_dzero, k_mnt };
// one entry per baked row, growing with create and mkdir. the cwd is canonical ("" the root)
static struct vfs k_fs = { .cwd = "home", .cwd_n = 4, .ro = k_tree, .pins = k_pins,
                           .npins = countof(k_pins), .grab = k_grab, .drop = k_drop, .now = k_clock_ms };

// laid on first use, idempotent; a refusal leaves the console standing (ENOMEM)
static bool k_fs_init(void) {
  if (k_fs.ents) return true;
  if (!k_fs.bakes && !vfs_untar(&k_fs, k_tree, srctree, srctree_len, rootfs, rootfs_len)) return false;
  int bn = k_fs.extra ? 0 : k_baked(NULL, 0),
      xn = bn + (!k_fs.extra && kboot.image_len) + (!k_fs.extra && kboot.initrd_len);
  if (xn > 0) {
    struct vfs_file *xr = k_grab((uintptr_t) xn * sizeof *xr);
    if (!xr) return false;
    int m = bn ? k_baked(xr, bn) : 0;
    if (kboot.image_len) xr[m++] = (struct vfs_file) { k_pimg, kboot.image, kboot.image_len, 0 };
    if (kboot.initrd_len) xr[m++] = (struct vfs_file) { k_pinitrd, kboot.initrd, kboot.initrd_len, 0 };
    k_fs.extra = xr, k_fs.extra_n = m; }
  // laid empty and owned; one with `to` is a link, its target heap since k_ent_gc frees it
  static struct { char const *path, *to; uintptr_t mode; bool dir; } const rows[] = {
    { "tmp", NULL, 0755, true },
    { k_vtfg, NULL, 0644, false }, { k_vtbg, NULL, 0644, false },     // the console's colours
    { k_pmem, NULL, 0444, false }, { k_pgauge, NULL, 0444, false },   // filled at each open
    { k_dnull, NULL, 0666, false }, { k_dzero, NULL, 0666, false },   // always empty (k_dev_slot)
    { "usr/bin", NULL, 0755, true },
    { k_vtscale, NULL, 0644, false },                                  // the glyph scale
    { k_pcmd, NULL, 0444, false },                                     // the boot line, at each open
    { k_plift, NULL, 0644, false },                                    // written, never read
    { "bin", "/usr/bin", 0777, false }, { "sbin", "/usr/bin", 0777, false },
    { "usr/sbin", "/usr/bin", 0777, false },
    { k_home, NULL, 0755, true },                                      // where the shell starts
    { k_vtfont, NULL, 0644, false },                                   // written, never read
    { "proc/src", "/love", 0777, false },                              // the tree's old name
    { k_mnt, NULL, 0755, true } };                                     // the seat's own files: last
  int n = vfs_lay(&k_fs, (int) countof(rows));
  if (n < 0) return false;
  struct vfs_ent *t = k_fs.ents;
  // the mount only where the seat has files; else its slot stays zero, the next create's
  k_mnt_up = k_host(kh_here, 0, 0, 0, 0, 0) > 0;
  for (uintptr_t k = 0; k < countof(rows) - !k_mnt_up; k++) {
    char *to = rows[k].to ? vfs_strdup(&k_fs, rows[k].to, strlen(rows[k].to)) : NULL;
    t[n + k] = (struct vfs_ent) { .path = rows[k].path, .bake = -1, .ms = k_clock_ms(),
                                .mode = rows[k].mode, .own = true, .live = true,
                                .dir = rows[k].dir || (rows[k].to && !to), .to = to }; }
  return true; }

// one open file, on the row's state, which the close frees
struct k_fh { int i, vt, refs; uintptr_t pos; bool w; };   // refs: the rows a dup shares it across

static intptr_t ram_readn(int fd, unsigned char *dst, uintptr_t n);

// the handle behind an fd, NULL for a non-ramfs row: the readn method says what state is
static love_inline struct k_fh *k_fh(int fd) {
  struct k_source *s = k_source(fd);
  return s && s->readn == ram_readn ? s->state : NULL; }


// sys.c's seek, -errno on failure; whence is SEEK_*
static struct k_hf *k_hf(int fd);
static long k_host_lseek(struct k_hf *f, long off, int whence);
long k_fd_lseek(int fd, long off, int whence) {
  if (!k_row_live(fd)) return -9;                        // EBADF
  if (k_hf(fd)) return k_host_lseek(k_hf(fd), off, whence);
  struct k_fh *h = k_fh(fd);
  if (!h) return -29;                                    // ESPIPE: a console or a pipe
  if (whence < 0 || whence > 2) return -22;              // EINVAL
  uintptr_t len = vfs_size(&k_fs, h->i);
  intptr_t at = off + (whence == 1 ? (intptr_t) h->pos
                     : whence == 2 ? (intptr_t) len : 0);
  if (at < 0) return -22;
  return (long) (h->pos = (uintptr_t) at); }

// truncate: cut, or stretched with zeros; a reader's row is refused, as linux does
long k_fd_truncate(int fd, long n) {
  if (!k_row_live(fd)) return -9;                        // EBADF
  struct k_hf *hf = k_hf(fd);
  if (hf) return !hf->w ? -9 : n < 0 ? -22 : k_host(kh_trunc, hf->h, n, 0, 0, 0);
  struct k_fh *h = k_fh(fd);
  if (!h) return -22;                                    // EINVAL: a console or a pipe
  if (!h->w) return -9;
  if (n < 0) return -22;
  if (!vfs_fit(&k_fs, h->i, (uintptr_t) n)) return -12;           // ENOMEM
  struct vfs_ent *e = &k_fs.ents[h->i];
  if ((uintptr_t) n > e->len) memset(e->bytes + e->len, 0, (uintptr_t) n - e->len);
  e->len = (uintptr_t) n, e->ms = k_clock_ms();
  return 0; }

// at the open of a read; memory refusing leaves the last content, a stale number answerable
static void k_vt_read(int i, int slot) {
  // serial-only: empty rather than the last write
  if (!kcb || slot >= 4) { k_fs.ents[i].len = 0; return; }   // the lift and the font are written, never read
  // the colours come off the pen, the scale off the paper
  unsigned v = slot == 3 ? kfb.scale : cb_val(slot == 1 ? kcb->def_fg : kcb->def_bg) & 255u;
  char d[4]; int n = 0;
  if (v >= 100) d[n++] = (char) ('0' + v / 100);
  if (v >= 10)  d[n++] = (char) ('0' + v / 10 % 10);
  d[n++] = (char) ('0' + v % 10);
  d[n++] = '\n';
  if (!vfs_fit(&k_fs, i, (uintptr_t) n)) return;
  memcpy(k_fs.ents[i].bytes, d, (uintptr_t) n);
  k_fs.ents[i].len = (uintptr_t) n; }

// vetted, then copied out of the entry, whose bytes move on the next write; a failure keeps the old
static void k_vt_font(unsigned char const *b, uintptr_t n) {
  uint8_t *q = 0;
  if (n) {
    if (!cb_font_ok(b, n) || !(q = k_grab(n))) return;
    memcpy(q, b, n); }
  if (kqf) k_drop(kqf);
  kqf = q;
  if (kcb) fbwash(); }

// at the close of a write: a leading number is the grammar, past 256 or none leaves the console
static void k_vt_write(int i, int slot) {
  unsigned char const *b = k_fs.ents[i].bytes;
  uintptr_t len = k_fs.ents[i].len, j = 0;
  // the lift takes the bytes as a path, less a trailing newline, and needs no console
  if (slot == 4) {
    while (len && (b[len - 1] == '\n' || b[len - 1] == '\r')) len--;
    if (len) k_lift_ask(b, len);
    return; }
  if (slot == 5) return k_vt_font(b, len);
  if (!kcb) return;
  unsigned v = 0;
  while (j < len && b[j] >= '0' && b[j] <= '9' && v < 256) v = v * 10 + (unsigned) (b[j++] - '0');
  if (!j || v > 255) return;
  if (slot == 3) { k_vt_rescale(v); return; }   // a scale is a new grid, not a new pen
  cb_recolor(kcb, slot == 1 ? cb_ink(cb_idx, v) : kcb->def_fg,
                  slot == 1 ? kcb->def_bg : cb_ink(cb_idx, v)); }

// /proc's live rows, filled at open from the free list and the collector: `key value` lines, in words
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
  uintptr_t free = 0, blocks = 0, big = 0, up = 1;
  for (struct mem const *m = kmem; m; m = m->next)
    free += m->len, blocks++, big = m->len > big ? m->len : big,
    up &= !m->next || after((struct mem*) m) < m->next;      // ascending, no two touching
  int at = k_row(b, 0, "ram-words", kram_words);
  at = k_row(b, at, "free-words", free);
  at = k_row(b, at, "free-blocks", blocks);
  at = k_row(b, at, "free-largest", big);
  at = k_row(b, at, "free-ordered", up);
  // heap bytes only: a baked row costs the image, not the RAM
  uintptr_t ents = 0, bytes = 0;
  for (int i = 0; i < k_fs.n; i++)
    if (k_fs.ents[i].live) ents++, bytes += k_fs.ents[i].own ? k_fs.ents[i].cap : 0;
  at = k_row(b, at, "fs-entries", ents);
  return k_row(b, at, "fs-heap-bytes", bytes); }

// love.c's lvm_gauge roster, named
static int k_gauge(char *b, struct g const *g) {
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
  at = k_row(b, at, "major-cap", g->major_len);
  at = k_row(b, at, "rem-miss", g->rem_miss);
  at = k_row(b, at, "rem-peak", g->rem_hi);
  at = k_row(b, at, "resizes", g->n_resize);
  at = k_row(b, at, "minor-peak", g->minor_hi);
  return k_row(b, at, "major-peak", g->major_hi); }

// the program word, then the raw boot line, as linux writes its own
static int k_bootline(char *b) {
  int at = 0;
  for (char const *k = "love"; *k; k++) b[at++] = *k;
  if (kboot.cmdline[0]) {
    b[at++] = ' ';
    for (char const *s = kboot.cmdline; *s; s++) b[at++] = *s; }
  b[at++] = '\n';
  return at; }

// at the open of a read; a refusal leaves the last content
static void k_proc_read(int i, int slot) {
  if (slot == 2 && !love_system) return;          // no process to ask; meminfo is ours alone
  char b[768];
  int n = slot == 1 ? k_meminfo(b) : slot == 3 ? k_bootline(b) : k_gauge(b, love_system);
  if (!vfs_fit(&k_fs, i, (uintptr_t) n)) return;
  memcpy(k_fs.ents[i].bytes, b, (uintptr_t) n);
  k_fs.ents[i].len = (uintptr_t) n; }

static intptr_t ram_readn(int fd, unsigned char *dst, uintptr_t n) {
  struct k_fh *h = k_fh(fd);
  if (!h) return -1;
  uintptr_t len;
  unsigned char const *p = vfs_blob(&k_fs, h->i, &len);
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
  if (n > (uintptr_t) INTPTR_MAX - h->pos) return -1;
  if (!vfs_fit(&k_fs, h->i, h->pos + n)) return -1;
  struct vfs_ent *e = &k_fs.ents[h->i];
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
  *s = (struct k_source) {0};                 // the row is free again
  if (h && --h->refs > 0) return;             // the handle stays with its other rows
  if (h && h->vt && h->w) k_vt_write(h->i, h->vt);   // the write lands when the writer is done
  if (h && k_fs.ents[h->i].refs) k_fs.ents[h->i].refs--, vfs_gc(&k_fs, h->i);
  k_drop(h); }

// the lowest free row at or past floor (F_DUPFD's, else 0): POSIX's rule, which scripts lean on
static int k_fd_free_at(int at) {
  int lo = at > (int) countof(k_boot) ? at : (int) countof(k_boot);
  for (int i = lo; i < k_sources_n; i++)
    if (!k_row_live(i)) return i;
  return k_sources_n > lo ? k_sources_n : lo; }
static int k_fd_free(void) { return k_fd_free_at(0); }

// shared by its dups, so the offset is too, as POSIX has it
struct k_hf { long h; uintptr_t pos; int refs; bool w; };
static intptr_t host_readn(int fd, unsigned char *dst, uintptr_t n) {
  struct k_hf *f = k_source(fd)->state;
  long k = k_host(kh_pread, f->h, (long) dst, (long) n, (long) f->pos, 0);
  if (k <= 0) return -1;                       // the end, never 0: that would park the reader
  f->pos += (uintptr_t) k;
  return k; }
static intptr_t host_writen(int fd, unsigned char const *src, uintptr_t n) {
  struct k_hf *f = k_source(fd)->state;
  if (!f->w) return -1;
  if (!n) return 0;
  long k = k_host(kh_pwrite, f->h, (long) src, (long) n, (long) f->pos, 0);
  if (k <= 0) return -1;
  f->pos += (uintptr_t) k;
  return k; }
static void host_close(int fd) {
  struct k_source *s = k_source(fd);
  if (!s) return;
  struct k_hf *f = s->state;
  if (f && --f->refs <= 0) k_host(kh_close, f->h, 0, 0, 0, 0), k_drop(f);
  *s = (struct k_source) {0}; }
static struct k_hf *k_hf(int fd) {
  struct k_source *s = k_source(fd);
  return s && s->readn == host_readn ? s->state : NULL; }
static long k_host_lseek(struct k_hf *f, long off, int whence) {
  if (whence < 0 || whence > 2) return -EINVAL;
  long st[3] = { 0, 0, 0 };
  if (whence == 2) {
    long e = k_host(kh_fstat, f->h, (long) st, 0, 0, 0);
    if (e) return e; }
  long at = off + (whence == 1 ? (long) f->pos : whence == 2 ? st[0] : 0);
  if (at < 0) return -EINVAL;
  return (long) (f->pos = (uintptr_t) at); }
// the seat's stat -> size, ms, mode with the kind over the bits
static int k_host_stat(char const *p, uintptr_t n, uintptr_t *st3) {
  long r[3] = { 0, 0, 0 };
  long e = k_host(kh_stat, (long) p, (long) n, (long) r, 0, 0);
  if (e) return (int) e;
  st3[0] = (uintptr_t) r[0], st3[1] = (uintptr_t) r[1], st3[2] = (uintptr_t) r[2];
  return 0; }
static int k_host_open(char const *p, uintptr_t n, char m) {
  if (!n) return -EISDIR;                      // the mount is a directory
  long h = k_host(kh_open, (long) p, (long) n, m, 0, 0);
  if (h < 0) return (int) h;
  int fd = k_fd_free();
  struct k_hf *f = k_grab(sizeof *f);
  struct k_source *s = f ? k_source_open(fd) : NULL;
  if (!s) { k_drop(f); k_host(kh_close, h, 0, 0, 0, 0); return -ENOMEM; }
  long st[3] = { 0, 0, 0 };
  if (m == 'a') k_host(kh_fstat, h, (long) st, 0, 0, 0);
  *f = (struct k_hf) { .h = h, .pos = (uintptr_t) st[0], .refs = 1, .w = m != 'r' };
  *s = (struct k_source) { .readn = host_readn, .writen = host_writen,
                           .ready = ram_ready, .close = host_close, .state = f };
  return fd; }

// -> an fd | -errno. m: r read, w truncate, a append, c and o in place from the start; w a c
// create under a directory parent. a directory does not open: readdir is its read door
love_noinline int k_fs_open(char const *p, uintptr_t pn, char m) {
  if (m != 'r' && m != 'w' && m != 'a' && m != 'c' && m != 'o') return -EINVAL;
  if (!k_fs_init()) return -ENOMEM;
  char cp[256];
  intptr_t cn = vfs_walk(&k_fs, p, pn, cp, true);
  if (cn < 0) return (int) cn;
  intptr_t ho = k_hosted(cp, (uintptr_t) cn);
  if (ho >= 0) return k_host_open(cp + ho, (uintptr_t) (cn - ho), m);
  if (vfs_ro(&k_fs, cp, (uintptr_t) cn)) {                // the tree is read only, the mount a directory
    if (m != 'r') return -EROFS;
    if (cn == (intptr_t) sizeof k_tree - 1) return -EISDIR; }
  // the ramfs reads no mode bits: 0444 is a label, and this the refusal
  if (k_proc_slot(cp, (uintptr_t) cn) && m != 'r') return -EROFS;
  if (!cn) return -EISDIR;                       // the root is a directory
  { int dv = k_dev_slot(cp, (uintptr_t) cn);     // no handle, no bytes, no entry
    if (dv) {
      int dfd = k_fd_free();
      struct k_source *ds = k_source_open(dfd);
      if (!ds) return -ENOMEM;
      // null has no readn (k_row_read answers the end) but says ready, or its reader parks for good
      *ds = dv == 2 ? (struct k_source) { .readn = k_zero_readn, .ready = k_dev_ready }
                    : (struct k_source) { .writen = k_null_writen, .ready = k_dev_ready };
      return dfd; } }
  int i = vfs_find(&k_fs, cp, (uintptr_t) cn);
  if (i >= 0 && k_fs.ents[i].dir) return -EISDIR;
  bool made = false;
  if (i < 0) {
    // an 'r' miss stays one vfs_find; only a create pays vfs_dirp, so a file never shadows a directory
    if (m == 'r' || m == 'o') return -ENOENT;
    if (vfs_dirp(&k_fs, cp, (uintptr_t) cn)) return -EISDIR;
    int e = vfs_parent_ok(&k_fs, cp, (uintptr_t) cn);
    if (e) return e;
    if ((i = vfs_create(&k_fs, cp, (uintptr_t) cn, false, 0644)) < 0) return -ENOMEM;
    made = true; }
  int fd = k_fd_free();
  struct k_fh *h = k_grab(sizeof *h);
  struct k_source *s = h ? k_source_open(fd) : NULL;   // the grow door; NULL is no memory
  if (!s) {
    k_drop(h);
    // a refused open leaves the tree as it was: a file it minted goes too
    if (made) k_fs.ents[i].live = false, vfs_gc(&k_fs, i);
    return -ENOMEM; }
  // the truncate lands last, past every way this can still fail
  uintptr_t len = 0;
  struct vfs_ent *e = &k_fs.ents[i];
  int vt = k_vt_slot(cp, (uintptr_t) cn);
  if (vt && m == 'r') k_vt_read(i, vt);          // the pen, as of this open
  int ps = m != 'r' ? 0 : k_proc_slot(cp, (uintptr_t) cn);
  if (ps) k_proc_read(i, ps);                    // and the machine, as of this open
  if (m == 'w') e->own = true, e->len = 0, e->ms = k_clock_ms();
  if (m == 'a') len = vfs_size(&k_fs, i);
  e->refs++;
  *h = (struct k_fh) { .i = i, .vt = vt, .refs = 1, .pos = len, .w = m != 'r' };
  *s = (struct k_source) { .readn = ram_readn, .writen = ram_writen,
                           .ready = ram_ready, .close = ram_close, .state = h };
  return fd; }
// open and close are posix.c's, through sys.c's arms: a directory opens as a dents row

// the file nifs: doc/misc/posix.md's shapes exactly, which kore reads in silence
#define k_mode_file 0100000            // (& mode 61440) = 32768: a regular file
#define k_mode_dir  0040000            //                = 16384: a directory
#define k_mode_lnk  0120000            //                = 40960: a symlink

// (stat path) -> (size mtime-ms mode ns) | (); ns is the ms date times a million. ino, nlink,
// uid and dev are sys.c's to invent
struct k_st { uintptr_t size, ms, mode; };

// -> 0 | -ENOENT. fills a struct, not an index: a synthesized directory (the root, a bare
// prefix) has no row
love_noinline int k_fs_stat(char const *p, uintptr_t pn, struct k_st *st, bool follow) {
  char cp[256];
  intptr_t cn;
  if (!k_fs_init()) return -ENOMEM;
  if ((cn = vfs_walk(&k_fs, p, pn, cp, follow)) < 0) return (int) cn;
  *st = (struct k_st) { 0, 0, 0 };
  intptr_t ho = k_hosted(cp, (uintptr_t) cn);
  if (ho >= 0) {
    uintptr_t r[3];
    int e = k_host_stat(cp + ho, (uintptr_t) (cn - ho), r);
    if (!e) *st = (struct k_st) { r[0], r[1], r[2] };
    return e; }
  int i = vfs_find(&k_fs, cp, (uintptr_t) cn);
  uintptr_t kid;
  // lstat: the link itself, sized by its target as stat(2) has it
  if (!follow && i >= 0 && k_fs.ents[i].to)
    return *st = (struct k_st) { strlen(k_fs.ents[i].to), k_fs.ents[i].ms,
                                 k_mode_lnk | 0777 }, 0;
  if (i >= 0 && !k_fs.ents[i].dir) {
    int vt = k_vt_slot(cp, (uintptr_t) cn);
    if (vt) k_vt_read(i, vt);                        // a size is the pen's, not the last read's
    int ps = k_proc_slot(cp, (uintptr_t) cn);
    if (ps) k_proc_read(i, ps);
    st->size = vfs_size(&k_fs, i), st->ms = k_fs.ents[i].ms,
    st->mode = k_mode_file | k_fs.ents[i].mode; }
  else if (i >= 0) {
    st->mode = k_mode_dir | k_fs.ents[i].mode;     // an explicit directory: its own date,
    st->ms = k_fs.ents[i].ms;                      // or its newest child's if newer
    if (vfs_kids(&k_fs, cp, (uintptr_t) cn, &kid) && kid > st->ms) st->ms = kid; }
  else if (vfs_kids(&k_fs, cp, (uintptr_t) cn, &st->ms) || !cn) st->mode = k_mode_dir | 0755;
  else return -ENOENT;
  return 0; }

// pipes: a k_source pair over one heap queue, each end counting holders. the read end answers
// 0 while a writer is open, -1 after; the queue grows, and a refused grow drops the byte
struct k_pipe { unsigned char *buf; uintptr_t cap, rp, wp; int rrefs, wrefs; };

static struct k_pipe *k_pipe_of(int fd) {
  struct k_source *s = k_source(fd);
  return s ? s->state : NULL; }

// the pipe's and the pty's: up to n out (0 empty), n in (-1 when memory refuses)
static intptr_t q_get(struct k_pipe *p, unsigned char *dst, uintptr_t n) {
  uintptr_t a = p->wp - p->rp;
  if (!a) return 0;
  if (a > n) a = n;
  memcpy(dst, p->buf + p->rp, a);
  p->rp += a;
  if (p->rp == p->wp) p->rp = p->wp = 0;        // drained: the queue restarts at the front
  return (intptr_t) a; }

static intptr_t q_put(struct k_pipe *p, unsigned char const *src, uintptr_t n) {
  if (n > (uintptr_t) INTPTR_MAX - p->wp) return -1;   // the doubling below stays in range
  if (p->wp + n > p->cap) {
    if (p->rp) {                                // compact before growing
      memmove(p->buf, p->buf + p->rp, p->wp - p->rp);
      p->wp -= p->rp, p->rp = 0; }
    if (p->wp + n > p->cap) {
      uintptr_t cap = p->cap ? p->cap : 4096;
      while (cap < p->wp + n) cap *= 2;
      unsigned char *b = k_grab(cap);
      if (!b) return -1;                        // memory refusing, said out loud
      if (p->wp) memcpy(b, p->buf, p->wp);
      k_drop(p->buf);
      p->buf = b, p->cap = cap; } }
  memcpy(p->buf + p->wp, src, n);
  p->wp += n;
  return (intptr_t) n; }

// a queue's read: its bytes, else 0 (park) while a writer holds the other end, -1 (the end) after
static intptr_t q_read(struct k_pipe *q, int writers, unsigned char *dst, uintptr_t n) {
  return q->wp > q->rp ? q_get(q, dst, n) : writers ? 0 : -1; }
static bool q_ready(struct k_pipe const *q, int writers) { return q->wp > q->rp || !writers; }   // bytes, or the end

// a stateless dup (a console twin) still owes k_fd_free a way back to empty
static void k_row_zero(int fd) {
  struct k_source *s = k_source(fd);
  if (s) *s = (struct k_source) {0}; }

static intptr_t pipe_readn(int fd, unsigned char *dst, uintptr_t n) {
  struct k_pipe *p = k_pipe_of(fd);
  return p ? q_read(p, p->wrefs, dst, n) : -1; }

static intptr_t pipe_writen(int fd, unsigned char const *src, uintptr_t n) {
  struct k_pipe *p = k_pipe_of(fd);
  // no readers is gone; with no SIGPIPE the run drops as on EPIPE, and a `yes` into a dead pipe spins
  if (!p || !p->rrefs) return -1;
  return q_put(p, src, n); }

static bool pipe_rready(int fd) {
  struct k_pipe *p = k_pipe_of(fd);
  return p && q_ready(p, p->wrefs); }

static void pipe_free(struct k_pipe *p) {
  if (p->rrefs || p->wrefs) return;
  k_drop(p->buf);
  k_drop(p); }

static void pipe_rclose(int fd) {
  struct k_pipe *p = k_pipe_of(fd);
  k_row_zero(fd);
  if (p) p->rrefs--, pipe_free(p); }

static void pipe_wclose(int fd) {
  struct k_pipe *p = k_pipe_of(fd);
  k_row_zero(fd);
  if (p) p->wrefs--, pipe_free(p); }

// the pty: master, slave and signal rows over one k_pty. the master (a mitty pane) writes keys
// through the line discipline into in and reads out; the slave the other way, \n as \r\n under
// opost. ^C ^\ ^Z put a signal on the signal row for the tethering task to answer with still.
// cooked, a read takes at most one whole line, ^D on an empty one the end; raw as the host's
enum { pt_icanon = 1, pt_echo = 2, pt_isig = 4, pt_icrnl = 8, pt_opost = 16 };
struct k_pty { struct k_pipe in, out, ed, sig; int mrefs, srefs, grefs, eofs;
               unsigned flags; uint16_t rows, cols; intptr_t fg; };

static struct k_pty *k_pty_of(int fd) {
  struct k_source *s = k_source(fd);
  return s ? s->state : NULL; }

static void pty_free(struct k_pty *t) {
  if (t->mrefs || t->srefs || t->grefs) return;
  k_drop(t->in.buf), k_drop(t->out.buf), k_drop(t->ed.buf), k_drop(t->sig.buf);
  k_drop(t); }

// what the program writes, and what the discipline echoes: \n as \r\n under opost
static void pty_out(struct k_pty *t, unsigned char const *s, uintptr_t n) {
  uintptr_t i = 0;
  if (t->flags & pt_opost)
    for (uintptr_t j = 0; j < n; j++)
      if (s[j] == '\n') q_put(&t->out, s + i, j - i), q_put(&t->out, (unsigned char const*) "\r\n", 2), i = j + 1;
  q_put(&t->out, s + i, n - i); }

// a control key echoes as ^X, two columns
static void pty_echo(struct k_pty *t, unsigned char c) {
  if (!(t->flags & pt_echo)) return;
  unsigned char e[2] = {'^', c == 127 ? '?' : c + 64};
  if (c == 127 || (c < 32 && c != '\n' && c != '\t')) pty_out(t, e, 2);
  else pty_out(t, &c, 1); }

// the line's last character off, a whole utf-8 sequence, and off the glass too
static bool pty_rub(struct k_pty *t) {
  struct k_pipe *e = &t->ed;
  if (e->wp == e->rp) return false;
  do e->wp--; while (e->wp > e->rp && (e->buf[e->wp] & 0xc0) == 0x80);
  unsigned char c = e->buf[e->wp];
  for (int w = c < 32 && c != '\t' ? 2 : 1; w && t->flags & pt_echo; w--)
    pty_out(t, (unsigned char const*) "\b \b", 3);
  return true; }

static unsigned char pty_last(struct k_pty *t) {
  return t->ed.wp > t->ed.rp ? t->ed.buf[t->ed.wp - 1] : 0; }

static void pty_commit(struct k_pty *t) {
  q_put(&t->in, t->ed.buf + t->ed.rp, t->ed.wp - t->ed.rp);
  t->ed.rp = t->ed.wp = 0; }

static void pty_key(struct k_pty *t, unsigned char c) {
  if (c == '\r' && t->flags & pt_icrnl) c = '\n';
  if (t->flags & pt_isig && (c == 3 || c == 28 || c == 26)) {
    unsigned char sg = c == 3 ? 2 : c == 28 ? 3 : 20;
    t->ed.rp = t->ed.wp = 0, t->in.rp = t->in.wp = 0;   // what was typed goes with it
    pty_echo(t, c);
    if (t->fg) q_put(&t->sig, &sg, 1);
    return; }
  if (!(t->flags & pt_icanon)) { q_put(&t->in, &c, 1), pty_echo(t, c); return; }
  if (c == 127 || c == 8) { pty_rub(t); return; }
  if (c == 21) { while (pty_rub(t)) {} return; }               // ^U the line
  if (c == 23) {                                                // ^W the word
    while (pty_last(t) == ' ' && pty_rub(t)) {}
    while (pty_last(t) && pty_last(t) != ' ' && pty_rub(t)) {}
    return; }
  if (c == 4) { if (t->ed.wp == t->ed.rp) t->eofs++; else pty_commit(t); return; }
  q_put(&t->ed, &c, 1), pty_echo(t, c);
  if (c == '\n') pty_commit(t); }

static intptr_t pty_mreadn(int fd, unsigned char *dst, uintptr_t n) {
  struct k_pty *t = k_pty_of(fd);
  return t ? q_read(&t->out, t->srefs, dst, n) : -1; }

static intptr_t pty_mwriten(int fd, unsigned char const *src, uintptr_t n) {
  struct k_pty *t = k_pty_of(fd);
  if (!t || !t->srefs) return -1;
  for (uintptr_t i = 0; i < n; i++) pty_key(t, src[i]);
  return (intptr_t) n; }

static bool pty_mready(int fd) {
  struct k_pty *t = k_pty_of(fd);
  return t && q_ready(&t->out, t->srefs); }

static intptr_t pty_sreadn(int fd, unsigned char *dst, uintptr_t n) {
  struct k_pty *t = k_pty_of(fd);
  if (!t) return -1;
  uintptr_t a = t->in.wp - t->in.rp;
  if (a) {
    unsigned char const *b = t->in.buf + t->in.rp, *nl = t->flags & pt_icanon ? memchr(b, '\n', a) : NULL;
    if (nl) a = (uintptr_t) (nl - b) + 1;                      // one line at most
    return q_get(&t->in, dst, a < n ? a : n); }
  if (t->eofs) return t->eofs--, -1;
  return t->mrefs ? 0 : -1; }

static intptr_t pty_swriten(int fd, unsigned char const *src, uintptr_t n) {
  struct k_pty *t = k_pty_of(fd);
  if (!t || !t->mrefs) return -1;
  pty_out(t, src, n);
  return (intptr_t) n; }

static bool pty_sready(int fd) {
  struct k_pty *t = k_pty_of(fd);
  return t && (t->in.wp > t->in.rp || t->eofs || !t->mrefs); }

static intptr_t pty_greadn(int fd, unsigned char *dst, uintptr_t n) {
  struct k_pty *t = k_pty_of(fd);
  return t ? q_read(&t->sig, t->mrefs, dst, n) : -1; }

static bool pty_gready(int fd) {
  struct k_pty *t = k_pty_of(fd);
  return t && q_ready(&t->sig, t->mrefs); }

// the terminal gone is a hangup: SIGHUP onto the signal row, before the row's end
static void pty_mclose(int fd) {
  struct k_pty *t = k_pty_of(fd);
  k_row_zero(fd);
  if (t && !--t->mrefs && t->srefs && t->grefs) q_put(&t->sig, (unsigned char const*) "\1", 1);
  if (t) pty_free(t); }
static void pty_sclose(int fd) {
  struct k_pty *t = k_pty_of(fd);
  k_row_zero(fd);
  if (t) t->srefs--, pty_free(t); }
static void pty_gclose(int fd) {
  struct k_pty *t = k_pty_of(fd);
  k_row_zero(fd);
  if (t) t->grefs--, pty_free(t); }

// the pty under a master or slave row, or NULL
static struct k_pty *k_pty_row(intptr_t fd) {
  struct k_source const *s = fd < 0 ? NULL : k_source((int) fd);
  return s && (s->readn == pty_mreadn || s->readn == pty_sreadn) ? s->state : NULL; }

// three fresh rows -- master, slave, signal -- cooked at 24x80
static int k_fd_pty(int fds[3]) {
  struct k_pty *t = k_grab(sizeof *t);
  if (!t) return -ENOMEM;
  *t = (struct k_pty) { .mrefs = 1, .srefs = 1, .grefs = 1, .rows = 24, .cols = 80,
                        .flags = pt_icanon | pt_echo | pt_isig | pt_icrnl | pt_opost };
  struct k_source const rows[3] = {
    { .readn = pty_mreadn, .writen = pty_mwriten, .ready = pty_mready, .close = pty_mclose, .state = t },
    { .readn = pty_sreadn, .writen = pty_swriten, .ready = pty_sready, .close = pty_sclose, .state = t },
    { .readn = pty_greadn, .ready = pty_gready, .close = pty_gclose, .state = t } };
  for (int i = 0; i < 3; i++) {
    int fd = k_fd_free();
    struct k_source *r = k_source_open(fd);
    if (!r) {
      for (int j = 0; j < i; j++) k_row_zero(fds[j]);
      k_drop(t);
      return -ENOMEM; }
    *r = rows[i], fds[i] = fd; }
  return 0; }

// a pipe end shares the queue and counts its side; a ramfs fd shares the handle; a boot twin
// gets k_row_zero so its close frees the row
love_noinline static int k_dup_row(int src, int at) {
  struct k_source *s = k_source(src);
  if (!s || !(s->readn || s->writen || s->putc)) return -1;
  int fd = k_fd_free_at(at);
  if (s->readn == ram_readn && !s->state) return -1;
  struct k_source *t = k_source_open(fd);
  if (!t) return -1;
  s = k_source(src);                            // the grow may have moved the table
  *t = *s;
  // a dup shares the open file, its offset with it, as POSIX's does
  if (s->readn == ram_readn) ((struct k_fh*) s->state)->refs++;
  else if (s->readn == host_readn) ((struct k_hf*) s->state)->refs++;
  else if (s->readn == pipe_readn) ((struct k_pipe*) s->state)->rrefs++;
  else if (s->writen == pipe_writen) ((struct k_pipe*) s->state)->wrefs++;
  else if (s->readn == pty_mreadn) ((struct k_pty*) s->state)->mrefs++;
  else if (s->readn == pty_sreadn) ((struct k_pty*) s->state)->srefs++;
  else if (s->readn == pty_greadn) ((struct k_pty*) s->state)->grefs++;
  else if (!t->close) t->close = k_row_zero;
  return fd; }
// sys.c's F_DUPFD (at the floor) and dup3; src == dst is dup3's refusal
long k_fd_dup(int src, int at) {
  if (at < 0 || at >= k_fd_most) return -EINVAL;
  int fd = k_dup_row(src, at);
  return fd < 0 ? -EBADF : fd; }
long k_fd_dup3(int src, int dst) {
  if (src == dst || dst < 0) return -EINVAL;
  if (dst >= k_fd_most) return -EBADF;           // past the table's ceiling, as dup2(2) says
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

// pipe(2)'s rows, g-free, for sys.c's pipe2
long k_fd_pipe(int fds[2]) {
  struct k_pipe *p = k_grab(sizeof *p);
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
    k_drop(p);
    return -ENOMEM; }
  *ws = (struct k_source) { .writen = pipe_writen, .close = pipe_wclose, .state = p };
  fds[0] = rfd, fds[1] = wfd;
  return 0; }

// directory rows, for sys.c's opendir: a close and a dents cursor (read is EISDIR); the cursor
// is where the next scan starts, the only state between calls
struct k_dh { uintptr_t pn; int at; char p[256]; };
static void k_dir_close(int fd) {
 struct k_source *s = k_source(fd);
 if (!s) return;
 k_drop(s->state);
 *s = (struct k_source) {0}; }

// a host directory's whole listing, taken once: a kind byte (d f), the name, a NUL each
struct k_hd { char *b; long n, at, k; };
static void k_hdir_close(int fd) {
 struct k_source *s = k_source(fd);
 if (!s) return;
 struct k_hd *h = s->state;
 if (h) k_drop(h->b), k_drop(h);
 *s = (struct k_source) {0}; }
static long k_host_opendir(char const *p, uintptr_t n) {
 for (long cap = 4096; ; ) {
  char *b = k_grab((uintptr_t) cap);
  if (!b) return -ENOMEM;
  long k = k_host(kh_list, (long) p, (long) n, (long) b, cap, 0);
  if (k < 0) return k_drop(b), k;
  if (k > cap) { k_drop(b); cap = k; continue; }        // the seat said how much room it wants
  int fd = k_fd_free();
  struct k_hd *h = k_grab(sizeof *h);
  struct k_source *s = h ? k_source_open(fd) : NULL;
  if (!s) { k_drop(h), k_drop(b); return -ENOMEM; }
  *h = (struct k_hd) { b, k, 0, 0 };
  *s = (struct k_source) { .close = k_hdir_close, .state = h };
  return fd; } }

long k_fs_opendir(char const *p, uintptr_t pn) {
 char cp[256];
 intptr_t cn;
 if (!k_fs_init()) return -ENOMEM;
 if ((cn = vfs_walk(&k_fs, p, pn, cp, true)) < 0) return cn;
 intptr_t ho = k_hosted(cp, (uintptr_t) cn);
 if (ho >= 0) return k_host_opendir(cp + ho, (uintptr_t) (cn - ho));
 if (!vfs_dirp(&k_fs, cp, (uintptr_t) cn))
  return vfs_find(&k_fs, cp, (uintptr_t) cn) >= 0 ? -ENOTDIR : -ENOENT;
 int fd = k_fd_free();
 struct k_dh *h = k_grab(sizeof *h);
 struct k_source *s = h ? k_source_open(fd) : NULL;
 if (!s) { k_drop(h); return -ENOMEM; }
 h->pn = (uintptr_t) cn, h->at = 0;
 memcpy(h->p, cp, (uintptr_t) cn);
 *s = (struct k_source) { .close = k_dir_close, .state = h };
 return fd; }

// linux_dirent64: 19 header bytes, the name with its NUL, rounded to 8
struct k_dent { unsigned long ino; long off; unsigned short reclen;
                unsigned char type; char name[]; };
static long k_host_dents(struct k_hd *h, void *buf, long cap) {
 long off = 0;
 while (h->at < h->n) {
  char const *e = h->b + h->at;
  uintptr_t k = strlen(e + 1);
  long rl = (long) ((19 + k + 1 + 7) & ~(uintptr_t) 7);
  if (off + rl > cap) return off ? off : -EINVAL;
  struct k_dent *d = (struct k_dent*) ((char*) buf + off);
  d->ino = (unsigned long) h->k + 1;            // fabricated: the place in the listing
  d->off = h->k + 1;
  d->reclen = (unsigned short) rl;
  d->type = e[0] == 'd' ? 4 : 8;                // DT_DIR : DT_REG
  memcpy(d->name, e + 1, k + 1);
  off += rl, h->k++, h->at += (long) k + 2; }
 return off; }
long k_fd_dents(int fd, void *buf, long cap) {
 if (!k_row_live(fd)) return -EBADF;
 struct k_source *s = k_source(fd);
 if (s->close == k_hdir_close) return k_host_dents(s->state, buf, cap);
 if (s->close != k_dir_close) return -ENOTDIR;
 struct k_dh *h = s->state;
 long off = 0;
 char const *e;
 uintptr_t k;
 bool dir;
 for (int cur = h->at, i; (i = vfs_child(&k_fs, h->p, h->pn, &cur, &e, &k, &dir)) >= 0; ) {
  long rl = (long) ((19 + k + 1 + 7) & ~(uintptr_t) 7);
  if (off + rl > cap) return off ? off : -EINVAL;
  struct k_dent *d = (struct k_dent*) ((char*) buf + off);
  d->ino = (unsigned long) i + 1;             // fabricated: the first carrier's row
  d->off = cur;
  d->reclen = (unsigned short) rl;
  d->type = dir ? 4 : 8;                      // DT_DIR : DT_REG
  memcpy(d->name, e, k);
  d->name[k] = 0;
  off += rl;
  h->at = cur; }
 return off; }

// fstat(2): a ramfs handle its entry, a pipe a fifo, a directory row its tree, the boot rows
// a character device; struct stat is sys.c's
long k_fd_stat(int fd, struct k_st *st) {
  if (!k_row_live(fd)) return -EBADF;
  struct k_source *s = k_source(fd);
  *st = (struct k_st) { 0, 0, 0 };
  if (s->readn == ram_readn) {
    struct k_fh *h = s->state;
    st->size = vfs_size(&k_fs, h->i);
    st->ms = k_fs.ents[h->i].ms;
    st->mode = k_mode_file | k_fs.ents[h->i].mode;
    return 0; }
  if (s->readn == host_readn) {
    long r[3] = { 0, 0, 0 };
    long e = k_host(kh_fstat, ((struct k_hf*) s->state)->h, (long) r, 0, 0, 0);
    if (e) return e;
    *st = (struct k_st) { (uintptr_t) r[0], (uintptr_t) r[1], (uintptr_t) r[2] };
    return 0; }
  if (s->readn == pipe_readn || s->writen == pipe_writen) {
    st->mode = 0010000 | 0600;                  // a fifo
    return 0; }
  if (s->close == k_hdir_close) return st->mode = k_mode_dir | 0755, 0;
  if (s->close == k_dir_close) {
    struct k_dh *h = s->state;
    int i = vfs_find(&k_fs, h->p, h->pn);
    st->mode = k_mode_dir | (i >= 0 ? k_fs.ents[i].mode : 0755);
    st->ms = i >= 0 ? k_fs.ents[i].ms : 0;
    uintptr_t kid;
    if (vfs_kids(&k_fs, h->p, h->pn, &kid) && kid > st->ms) st->ms = kid;
    return 0; }
  st->mode = 0020000 | 0620;                    // the console twins: a character device
  return 0; }

// (getpid _): the main task reads 0; main.c's getpid branches here on a negative osv
lvm(k_lvm_getpid) {
  Sp[0] = putcharm(k_cur_pid(g));
  love_musttail return Next(1); }

// the disk, fat.l's block door over blk.c. DMA rides a love string's own bytes: nothing
// allocates between post and completion, so the collector cannot move them
// (disk _)         -> the sector count, 0 when no disk.
// (disk-read l n)  -> a string of n*512 bytes off sector l | ().
// (disk-write l s) -> the sectors written | () (s must be whole sectors).
void k_blk_init(void *dma);
uint64_t k_blk_sectors(void);
int k_blk_rw(uint64_t lba, uint32_t n, void *buf, int wr);

static lvm(lvm_disk) {
  Sp[0] = putcharm((intptr_t) k_blk_sectors());
  love_musttail return Next(1); }

love_noinline static struct g *k_disk_read(struct g *g) {
  word lw = g->sp[0], nw = g->sp[1];
  intptr_t lba = (lw & 1) ? getcharm(lw) : -1,
           n   = (nw & 1) ? getcharm(nw) : -1;
  if (lba < 0 || n <= 0 || n > 1 << 24) return g->sp[1] = ZeroPoint, g->sp += 1, g;
  if (!ok(g = str0(g, (uintptr_t) n * 512))) return g;   // OOM: the wrapper ghelps
  if (k_blk_rw((uint64_t) lba, (uint32_t) n, txt(g->sp[0]), 0) < 0)
    g->sp[0] = ZeroPoint;
  return g->sp[2] = g->sp[0], g->sp += 2, g; }

static lvm(lvm_disk_read) {
 LvmCall(g, k_disk_read) }

love_noinline static word k_disk_write(word lw, word sw) {
 intptr_t lba = (lw & 1) ? getcharm(lw) : -1;
 if (lba < 0 || !strp(sw)) return ZeroPoint;
 struct str *s = (struct str*) sw;
 if (!s->len || s->len % 512) return ZeroPoint;
 if (k_blk_rw((uint64_t) lba, (uint32_t) (s->len / 512), s->bytes, 1) < 0)
  return ZeroPoint;
 return putcharm((intptr_t) (s->len / 512)); }

static lvm(lvm_disk_write) {
  Sp[1] = k_disk_write(Sp[0], Sp[1]);
  love_musttail return Nextp(1, 1); }

// (fetch url path): url laid as the ramfs file at path where a seat has a network (wasm),
// 0 | -errno
__attribute__((weak)) long k_fetch(char const *url, uintptr_t un, char const *path, uintptr_t pn) {
  return (void) url, (void) un, (void) path, (void) pn, -ENOSYS; }
love_noinline static word k_lvm_fetch(word uw, word pw) {
  if (!strp(uw) || !strp(pw)) return ZeroPoint;
  struct str *u = (struct str*) uw, *p = (struct str*) pw;
  return putcharm((intptr_t) k_fetch(u->bytes, u->len, p->bytes, p->len)); }
static lvm(lvm_fetch) {
  Sp[1] = k_lvm_fetch(Sp[0], Sp[1]);
  love_musttail return Nextp(1, 1); }

// (kexec path cmd): boot the ramfs module at path with cmd, in place of this one (wasm only);
// answers -errno on refusal
__attribute__((weak)) long k_kexec(char const *p, uintptr_t pn, char const *cmd, uintptr_t cn) {
  return (void) p, (void) pn, (void) cmd, (void) cn, -ENOSYS; }
love_noinline static word k_lvm_kexec(word pw, word cw) {
  if (!strp(pw) || !strp(cw)) return ZeroPoint;
  struct str *p = (struct str*) pw, *c = (struct str*) cw;
  return putcharm((intptr_t) k_kexec(p->bytes, p->len, c->bytes, c->len)); }
static lvm(lvm_kexec) {
  Sp[1] = k_lvm_kexec(Sp[0], Sp[1]);
  love_musttail return Nextp(1, 1); }

// the svm spike (x64/svm.c): (svm ()) the capability, (svm-run ()) one guest -> (exitcode rax rip) | ()
#if defined(__x86_64__) && !defined(INLE_DROID)

static lvm(lvm_svm) {
  Sp[0] = k_svm_ok() ? putcharm(1) : ZeroPoint;
  love_musttail return Next(1); }

love_noinline static struct g *k_svm_run(struct g *g) {
  uint64_t code = 0, rax = 0, rip = 0;
  if (!k_svm_ok()) return g->sp[0] = ZeroPoint, g;
  // the pages ride a string's bytes, as blk.c's: nothing allocates before the vmrun
  if (!ok(g = str0(g, k_svm_need()))) return g;      // OOM: the wrapper ghelps
  if (k_svm_spike(txt(g->sp[0]), &code, &rax, &rip) < 0)
    return g->sp[1] = ZeroPoint, g->sp += 1, g;
  if (!ok(g = have(g, 3 * Width(struct chain)))) return g;
  struct chain *c = ini_chain((struct chain*) bump(g, Width(struct chain)),
                                 putcharm((intptr_t) rip), ZeroPoint);
  c = ini_chain((struct chain*) bump(g, Width(struct chain)),
                putcharm((intptr_t) rax), word(c));
  c = ini_chain((struct chain*) bump(g, Width(struct chain)),
                putcharm((intptr_t) code), word(c));
  return g->sp[1] = word(c), g->sp += 1, g; }

static lvm(lvm_svm_run) {
  LvmCall(g, k_svm_run) }

// x64/vmx.c's twin: a fourth number, the VM-instruction error, all a refused entry can say

static lvm(lvm_vmx) {
  Sp[0] = k_vmx_ok() ? putcharm(1) : ZeroPoint;
  love_musttail return Next(1); }

love_noinline static struct g *k_vmx_run(struct g *g) {
  uint64_t reason = 0, rax = 0, rip = 0, err = 0;
  if (!k_vmx_ok()) return g->sp[0] = ZeroPoint, g;
  if (!ok(g = str0(g, k_vmx_need()))) return g;       // OOM: the wrapper ghelps
  if (k_vmx_spike(txt(g->sp[0]), &reason, &rax, &rip, &err) < 0)
    return g->sp[1] = ZeroPoint, g->sp += 1, g;
  if (!ok(g = have(g, 4 * Width(struct chain)))) return g;
  struct chain *c = ini_chain((struct chain*) bump(g, Width(struct chain)),
                                 putcharm((intptr_t) err), ZeroPoint);
  c = ini_chain(bump(g, Width(struct chain)), putcharm(rip), word(c));
  c = ini_chain(bump(g, Width(struct chain)), putcharm(rax), word(c));
  c = ini_chain(bump(g, Width(struct chain)), putcharm(reason), word(c));
  return g->sp[1] = word(c), g->sp += 1, g; }
static lvm(lvm_vmx_run) {
  LvmCall(g, k_vmx_run) }
#endif

// the writable tree, posix.md's shapes: an effect 0 | -errno | EINVAL on misuse, cwd the string | ()

// k_fs_* take (bytes, len) -> 0 | -errno, the sign sys.c hands out unflipped. love_noinline
// is load-bearing: cp[256] in an lvm's own frame would block its musttail
love_noinline int k_fs_mkdir(char const *p, uintptr_t pn, uintptr_t mode) {
  char cp[256];
  intptr_t cn;
  if (!k_fs_init()) return -ENOMEM;
  if ((cn = vfs_walk(&k_fs, p, pn, cp, false)) < 0) return (int) cn;
  intptr_t ho = k_hosted(cp, (uintptr_t) cn);
  if (ho >= 0) return cn == ho ? -EEXIST : (int) k_host(kh_mkdir, (long) (cp + ho), cn - ho, 0, 0, 0);
  if (vfs_ro(&k_fs, cp, (uintptr_t) cn)) return -EROFS;
  uintptr_t junk;
  if (!cn || vfs_find(&k_fs, cp, (uintptr_t) cn) >= 0 || vfs_kids(&k_fs, cp, (uintptr_t) cn, &junk))
    return -EEXIST;
  int e = vfs_parent_ok(&k_fs, cp, (uintptr_t) cn);
  if (e) return e;
  return vfs_create(&k_fs, cp, (uintptr_t) cn, true, mode) < 0 ? -ENOMEM : 0; }

love_noinline int k_fs_rmdir(char const *p, uintptr_t pn) {
  char cp[256];
  intptr_t cn;
  if (!k_fs_init()) return -ENOMEM;
  if ((cn = vfs_walk(&k_fs, p, pn, cp, false)) < 0) return (int) cn;
  intptr_t ho = k_hosted(cp, (uintptr_t) cn);
  if (ho > (intptr_t) k_mnt_n) return (int) k_host(kh_rmdir, (long) (cp + ho), cn - ho, 0, 0, 0);
  if (vfs_pinned(&k_fs, cp, (uintptr_t) cn)) return -EROFS;
  if (!cn) return -EBUSY;                         // the root stays
  int i = vfs_find(&k_fs, cp, (uintptr_t) cn);
  if (i >= 0 && !k_fs.ents[i].dir) return -ENOTDIR;
  uintptr_t junk;
  if (vfs_kids(&k_fs, cp, (uintptr_t) cn, &junk)) return -ENOTEMPTY;
  if (i < 0) return -ENOENT;
  k_fs.ents[i].live = false;
  vfs_gc(&k_fs, i);
  return 0; }

love_noinline int k_fs_unlink(char const *p, uintptr_t pn) {
  char cp[256];
  intptr_t cn;
  if (!k_fs_init()) return -ENOMEM;
  if ((cn = vfs_walk(&k_fs, p, pn, cp, false)) < 0) return (int) cn;
  intptr_t ho = k_hosted(cp, (uintptr_t) cn);
  if (ho >= 0) return cn == ho ? -EISDIR : (int) k_host(kh_unlink, (long) (cp + ho), cn - ho, 0, 0, 0);
  if (vfs_ro(&k_fs, cp, (uintptr_t) cn)) return -EROFS;
  int i = cn ? vfs_find(&k_fs, cp, (uintptr_t) cn) : -1;
  if (i < 0) return vfs_dirp(&k_fs, cp, (uintptr_t) cn) ? -EISDIR : -ENOENT;
  if (k_fs.ents[i].dir) return -EISDIR;
  k_fs.ents[i].live = false;                        // an open fd keeps the bytes; the
  vfs_gc(&k_fs, i);                                   // last close frees them
  return 0; }

// the target is stored as given, canonicalized against the link's place only when followed
love_noinline int k_fs_symlink(char const *t, uintptr_t tn, char const *p, uintptr_t pn) {
  char cp[256];
  intptr_t cn;
  if (!k_fs_init()) return -ENOMEM;
  if (!tn || tn >= 256) return -ENAMETOOLONG;
  if ((cn = vfs_walk(&k_fs, p, pn, cp, false)) < 0) return (int) cn;
  if (k_hosted(cp, (uintptr_t) cn) >= 0) return -EPERM;   // the seat keeps no links
  if (vfs_ro(&k_fs, cp, (uintptr_t) cn)) return -EROFS;
  uintptr_t junk;
  if (!cn || vfs_find(&k_fs, cp, (uintptr_t) cn) >= 0 || vfs_kids(&k_fs, cp, (uintptr_t) cn, &junk))
    return -EEXIST;
  int e = vfs_parent_ok(&k_fs, cp, (uintptr_t) cn);
  if (e) return e;
  char *q = vfs_strdup(&k_fs, t, tn);
  if (!q) return -ENOMEM;
  int i = vfs_create(&k_fs, cp, (uintptr_t) cn, false, 0777);
  if (i < 0) return k_drop(q), -ENOMEM;
  k_fs.ents[i].to = q;
  return 0; }

// (readlink path): the target unfollowed, the byte count back; -EINVAL for a non-link
love_noinline intptr_t k_fs_readlink(char const *p, uintptr_t pn, char *b, uintptr_t n) {
  char cp[256];
  intptr_t cn;
  if (!k_fs_init()) return -ENOMEM;
  if ((cn = vfs_walk(&k_fs, p, pn, cp, false)) < 0) return cn;
  intptr_t ho = k_hosted(cp, (uintptr_t) cn);
  if (ho >= 0) { uintptr_t r[3]; int e = k_host_stat(cp + ho, (uintptr_t) (cn - ho), r); return e ? e : -EINVAL; }
  int i = cn > 0 ? vfs_find(&k_fs, cp, (uintptr_t) cn) : -1;
  if (i < 0) return -ENOENT;
  if (!k_fs.ents[i].to) return -EINVAL;
  uintptr_t tn = strlen(k_fs.ents[i].to);
  if (!n) return -EINVAL;
  if (tn > n) tn = n;                            // readlink(2) truncates and does not say so
  memcpy(b, k_fs.ents[i].to, tn);
  return (intptr_t) tn; }

// (rename old new): a target file is unlinked under it; a directory's copies are staged
// first, so a refusal leaves the tree whole
struct k_ren { struct k_ren *next; int i; char *q; };
love_noinline int k_fs_rename(char const *o, uintptr_t olen,
                                   char const *n, uintptr_t nlen) {
  char op[256], np[256];
  intptr_t on, nn;
  if (!k_fs_init()) return -ENOMEM;
  if ((on = vfs_walk(&k_fs, o, olen, op, false)) < 0) return (int) on;
  if ((nn = vfs_walk(&k_fs, n, nlen, np, false)) < 0) return (int) nn;
  intptr_t ho = k_hosted(op, (uintptr_t) on), hn = k_hosted(np, (uintptr_t) nn);
  if (ho > (intptr_t) k_mnt_n && hn > (intptr_t) k_mnt_n)
    return (int) k_host(kh_rename, (long) (op + ho), on - ho, (long) (np + hn), nn - hn, 0);
  if ((ho > (intptr_t) k_mnt_n) != (hn > (intptr_t) k_mnt_n)) return -EXDEV;   // across the mount
  if (vfs_pinned(&k_fs, op, (uintptr_t) on) || vfs_pinned(&k_fs, np, (uintptr_t) nn)) return -EROFS;
  if (!on) return -EBUSY;                         // the root does not move
  if (on == nn && !memcmp(op, np, (uintptr_t) on)) return 0;           // itself: done
  if (!nn) return -EEXIST;                        // onto the root
  int e = vfs_parent_ok(&k_fs, np, (uintptr_t) nn);
  if (e) return e;
  int si = vfs_find(&k_fs, op, (uintptr_t) on), di = vfs_find(&k_fs, np, (uintptr_t) nn);
  uintptr_t junk;
  bool sdir = si >= 0 ? k_fs.ents[si].dir : vfs_kids(&k_fs, op, (uintptr_t) on, &junk);
  if (si < 0 && !sdir) return -ENOENT;
  if (!sdir) {
    if (di >= 0 ? k_fs.ents[di].dir : vfs_kids(&k_fs, np, (uintptr_t) nn, &junk))
      return -EISDIR;                             // a file does not land on a directory
    char *q = vfs_strdup(&k_fs, np, (uintptr_t) nn);
    if (!q) return -ENOMEM;
    if (di >= 0) k_fs.ents[di].live = false, vfs_gc(&k_fs, di);
    if (k_fs.ents[si].heap) k_drop((void*) k_fs.ents[si].path);
    k_fs.ents[si].path = q, k_fs.ents[si].heap = true;
    return 0; }
  // the directory lane
  if ((uintptr_t) nn > (uintptr_t) on && !memcmp(np, op, (uintptr_t) on) && np[on] == '/')
    return -EINVAL;                               // never into itself
  if (di >= 0 || vfs_kids(&k_fs, np, (uintptr_t) nn, &junk)) return -EEXIST;
  struct k_ren *st = NULL;
  for (int i = 0; i < k_fs.n; i++) {
    struct vfs_ent const *t = &k_fs.ents[i];
    if (!t->live || !t->path) continue;
    uintptr_t tl = strlen(t->path);
    if (tl < (uintptr_t) on || memcmp(t->path, op, (uintptr_t) on)
        || (tl > (uintptr_t) on && t->path[on] != '/')) continue;
    char *q = k_grab((uintptr_t) nn + tl - (uintptr_t) on + 1);
    struct k_ren *r = q ? k_grab(sizeof *r) : NULL;
    if (!r) {                                    // roll the staging back whole
      k_drop(q);
      while (st) { struct k_ren *x = st; st = st->next; k_drop(x->q), k_drop(x); }
      return -ENOMEM; }
    memcpy(q, np, (uintptr_t) nn);
    memcpy(q + nn, t->path + on, tl - (uintptr_t) on);
    q[(uintptr_t) nn + tl - (uintptr_t) on] = 0;
    *r = (struct k_ren) { st, i, q };
    st = r; }
  while (st) {
    struct vfs_ent *t = &k_fs.ents[st->i];
    if (t->heap) k_drop((void*) t->path);
    t->path = st->q, t->heap = true;
    struct k_ren *x = st;
    st = st->next;
    k_drop(x); }
  return 0; }

love_noinline int k_fs_chdir(char const *p, uintptr_t pn) {
  char cp[256];
  intptr_t cn;
  if (!k_fs_init()) return -ENOMEM;
  if ((cn = vfs_walk(&k_fs, p, pn, cp, true)) < 0) return (int) cn;
  intptr_t ho = k_hosted(cp, (uintptr_t) cn);
  if (ho >= 0) {
    uintptr_t r[3];
    int e = k_host_stat(cp + ho, (uintptr_t) (cn - ho), r);
    if (e) return e;
    if ((r[2] & 0170000) != k_mode_dir) return -ENOTDIR; }
  else if (cn) {
    int i = vfs_find(&k_fs, cp, (uintptr_t) cn);
    if (i >= 0 && !k_fs.ents[i].dir) return -ENOTDIR;
    uintptr_t junk;
    if (i < 0 && !vfs_kids(&k_fs, cp, (uintptr_t) cn, &junk)) return -ENOENT; }
  memcpy(k_fs.cwd, cp, (uintptr_t) cn), k_fs.cwd_n = (uintptr_t) cn;
  return 0; }

// getcwd(2): 0 | -ERANGE
int k_fs_getcwd(char *b, uintptr_t n) {
  if (n < k_fs.cwd_n + 2) return -ERANGE;            // '/' + the seat + the NUL
  b[0] = '/';
  memcpy(b + 1, k_fs.cwd, k_fs.cwd_n);
  b[1 + k_fs.cwd_n] = 0;
  return 0; }

// a process's cwd and the fs's trade places around one of its calls (sys.c)
void k_fs_cwd_swap(char *cwd, uintptr_t *n) {
  char t[sizeof k_fs.cwd];
  uintptr_t tn = k_fs.cwd_n;
  memcpy(t, k_fs.cwd, tn);
  memcpy(k_fs.cwd, cwd, *n), k_fs.cwd_n = *n;
  memcpy(cwd, t, tn), *n = tn; }

// on the entry: a synthesized directory takes either as a no-op, having no row
love_noinline int k_fs_chmod(char const *p, uintptr_t pn, uintptr_t mode) {
  char cp[256];
  intptr_t cn;
  if (!k_fs_init()) return -ENOMEM;
  if ((cn = vfs_walk(&k_fs, p, pn, cp, true)) < 0) return (int) cn;
  intptr_t ho = k_hosted(cp, (uintptr_t) cn);     // the seat keeps no bits or dates of ours:
  if (ho >= 0) { uintptr_t r[3]; return k_host_stat(cp + ho, (uintptr_t) (cn - ho), r); }   // there is all
  if (vfs_ro(&k_fs, cp, (uintptr_t) cn)) return -EROFS;
  int i = vfs_find(&k_fs, cp, (uintptr_t) cn);
  if (i < 0) return vfs_dirp(&k_fs, cp, (uintptr_t) cn) ? 0 : -ENOENT;
  k_fs.ents[i].mode = mode & 07777;
  return 0; }

love_noinline int k_fs_utime(char const *p, uintptr_t pn, uintptr_t ms) {
  char cp[256];
  intptr_t cn;
  if (!k_fs_init()) return -ENOMEM;
  if ((cn = vfs_walk(&k_fs, p, pn, cp, true)) < 0) return (int) cn;
  intptr_t ho = k_hosted(cp, (uintptr_t) cn);     // the seat keeps no bits or dates of ours:
  if (ho >= 0) { uintptr_t r[3]; return k_host_stat(cp + ho, (uintptr_t) (cn - ho), r); }   // there is all
  if (vfs_ro(&k_fs, cp, (uintptr_t) cn)) return -EROFS;
  int i = vfs_find(&k_fs, cp, (uintptr_t) cn);
  if (i < 0) return vfs_dirp(&k_fs, cp, (uintptr_t) cn) ? 0 : -ENOENT;
  k_fs.ents[i].ms = ms;
  return 0; }

static lvm(kreset) { return k_reset(), g; }

// quay marks no row for the cursor, so the renderer owns it
static uint32_t fbcur = ~0u, fbview;   // the cursor last painted, and the view it was under
static bool fbblink;

// repaint the rows quay marked in cb->dmg, reading and clearing them
void fbdraw(void) {
  if (!kcb) return;                    // serial-only: no framebuffer console
  uint16_t const rows = kcb->rows, cols = kcb->cols;
  int32_t const ask = kkb.peer, back = kkb.snap ? 0 : (int32_t) kcb->view + ask * (rows / 2 ? rows / 2 : 1);
  if (ask || kkb.snap) kkb.peer = 0, kkb.snap = 0, cb_peer(kcb, back < 0 ? 0u : (uint32_t) back);
  bool const blink = (kticks & 64) != 0;
  uint32_t const cur = kcb->flag & cb_show ? kcb->wpos : ~0u;
  // a hidden cursor's row is ~0u, matching nothing
  uint32_t const was = fbcur == ~0u ? ~0u : fbcur / cols + fbview,
                 now = cur == ~0u ? ~0u : cur / cols + kcb->view;
  bool const moved = cur != fbcur || blink != fbblink;
  // the blink phase read once a frame: kticks moves under the timer ISR
  struct cb_paper const paper = { kfb._, kfb.pitch, kfb.width, kfb.height, kfb.scale };
  bool painted = false;
  for (uint16_t i = 0; i < rows; i++) {
    uint32_t const r = i > 255 ? 255 : i;   // quay's fold: bit 255 stands for 255-and-past
    if (kcb->dmg[r >> 5] >> (r & 31) & 1 || (moved && (i == was || i == now)))
      cb_paint(&paper, kcb, &kface, kqf, i, 0, 0, blink ? cur : ~0u), painted = true; }
  for (int k = 0; k < 8; k++) kcb->dmg[k] = 0;
  fbcur = cur, fbblink = blink, fbview = kcb->view;
  // a seat showing this paper hears here, not at the write: the serial bytes leave before the
  // glyphs land. only when something was drawn
  if (painted) k_fb_touch(); }

// the pixels moved under the grid: every row dirty, the strip past the last row cleared
static void fbwash(void) {
  fbcur = ~0u;                         // the cached cursor indexed the grid as it was
  for (int k = 0; k < 8; k++) kcb->dmg[k] = ~(uint32_t) 0;
  for (uintptr_t y = 0; y < kfb.height; y++)
    for (uintptr_t x = 0; x < kfb.width; x++) kfb._[y * kfb.pitch + x] = 0;
  if (!kkb.hold) fbdraw(); }

// the console re-made for kfb, text and pictures across by cb_regrid. kcb is published only
// once whole and the old freed after (fbdraw may run from a fault); a refusal keeps the old
static bool k_cb_remake(void) {
  uintptr_t const rows = kfb.height / (kface.h * kfb.scale),
                  cols = kfb.width / (kface.w * kfb.scale);
  if (!rows || !cols) return false;
  struct cb *const old = kcb;
  uint16_t const orows = old->rows, ocols = old->cols;
  if (rows == orows && cols == ocols) return fbwash(), true;  // same grid, new pixels
  uint32_t sn = k_sn(rows, cols), hl = k_hl(cols), tw = 1;
  uintptr_t const xs = cb_xsize(old->cx);   // the grown cluster slots come along
  struct cb *c = kmallocw(b2w(cb_size(rows, cols, sn) + cb_hsize(hl, cols) + cb_tsize(rows, cols) + xs));
  if (!c) sn = hl = tw = 0, c = kmallocw(b2w(cb_size(rows, cols, 0) + xs));   // no room: the grid alone
  if (!c) return false;
  cb_regrid(c, old, (uint16_t) rows, (uint16_t) cols, sn, hl, tw);
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

// a canvas the reader resized: it must land inside fbinit's reservation, the rest is the heap's
bool k_fb_reseat(unsigned w, unsigned h, unsigned pitch, unsigned scale) {
  if (!kcb || !kfb._ || !w || !h) return false;
  if ((uintptr_t) pitch * h > kfb.cap_px) return false;
  // every field here is 16 bits wide: the bound is the type's
  if (w > 0xffffu || h > 0xffffu || pitch > 0xffffu || w > pitch) return false;
  if (scale > 8) return false;
  uint16_t const ow = kfb.width, oh = kfb.height, op = kfb.pitch;
  uint8_t const os = kfb.scale;
  kfb.width = (uint16_t) w, kfb.height = (uint16_t) h, kfb.pitch = (uint16_t) pitch;
  if (scale) kfb.scale = (uint8_t) scale;
  if (k_cb_remake()) return true;
  kfb.width = ow, kfb.height = oh, kfb.pitch = op, kfb.scale = os;
  return false; }

// the framebuffer whole for a program: base, size, stride in pixels; false with none (PVH),
// the cue to want the ESP door
bool k_fb(volatile uint32_t **p, int *w, int *h, int *pitch) {
  if (!kfb._) return false;
  *p = kfb._, *w = kfb.width, *h = kfb.height, *pitch = kfb.pitch;
  return true; }

// the console's glyph scale, 0 with no framebuffer
uintptr_t k_fb_scale(void) { return kfb._ ? kfb.scale : 0; }

// (tty fd) -> (rows . cols), off the pixels and the glyph scale | ENOTTY's nom serial-only.
// 0 1 2 route as every io op's, so a task wearing a pipe is asked about the pipe; only a
// charm past 2 is a raw row
static intptr_t k_ttyfd(struct g *g, word x) {
  if (charmp(x) && getcharm(x) >= 0 && getcharm(x) <= 2)
    x = word(getcharm(x) == 0 ? &love_stdin : getcharm(x) == 1 ? &love_stdout : &love_stderr);
  if (*task_io(g) != zero) x = io_route(g, x);
  return charmp(x) ? getcharm(x) : port_fd(x); }

love_noinline static struct g *k_tty(struct g *g) {
  intptr_t fd = k_ttyfd(g, g->sp[0]);
  if (fd < 0) return g->sp[0] = badarg(g), g;
  struct k_source const *s = k_source((int) fd);
  struct k_pty const *t = k_pty_row(fd);
  uintptr_t rows = t ? t->rows : kcb ? kcb->rows : 0, cols = t ? t->cols : kcb ? kcb->cols : 0;
  if (!rows || !s || !(t || s->putc == serial_putc1 || s->readn == kb_readn))
   return g->sp[0] = love_err(g, ENOTTY), g;
  if (!ok(g = have(g, Width(struct chain)))) return g;
  struct chain *w = ini_chain((struct chain*) bump(g, Width(struct chain)),
                                 putcharm(rows), putcharm(cols));
  return g->sp[0] = word(w), g; }

// (settty fd rows cols) -- a pty's size, from either side (TIOCSWINSZ)
static lvm(lvm_ksettty) {
  intptr_t r = charmp(Sp[1]) ? getcharm(Sp[1]) : 0, c = charmp(Sp[2]) ? getcharm(Sp[2]) : 0;
  struct k_pty *t = k_pty_row(k_ttyfd(g, Sp[0]));
  bool ok = t && 0 < r && r <= UINT16_MAX && 0 < c && c <= UINT16_MAX;
  if (ok) t->rows = (uint16_t) r, t->cols = (uint16_t) c;
  Sp[2] = ok ? ZeroPoint : love_err(g, ENOTTY);
  love_musttail return Nextp(1, 2); }

// the console answers the terminal doors and keeps nothing: its keys are its own
static bool k_console_in(intptr_t fd) {
  struct k_source const *s = fd < 0 ? NULL : k_source((int) fd);
  return s && s->readn == kb_readn; }

// (ttyfg pg) -- the group that owns the terminal on fd 0 from here, the one its ^C ends: a
// task id, or 0 or less for the shell itself, which takes no signal
static lvm(lvm_kttyfg) {
  intptr_t fd = k_ttyfd(g, putcharm(0)), pg = charmp(Sp[0]) ? getcharm(Sp[0]) : 0;
  struct k_pty *t = k_pty_row(fd);
  if (t) t->fg = pg > 0 ? pg : 0;
  Sp[0] = t || k_console_in(fd) ? ZeroPoint : love_err(g, ENOTTY);
  love_musttail return Next(1); }

// (ttypg fd) -- the terminal's foreground group, () when the shell holds it; the signal
// row answers too, so its reader can ask after the master is gone
static lvm(lvm_kttypg) {
  intptr_t fd = k_ttyfd(g, Sp[0]);
  struct k_source const *s = fd < 0 ? NULL : k_source((int) fd);
  struct k_pty *t = s && s->readn == pty_greadn ? s->state : k_pty_row(fd);
  Sp[0] = !t ? love_err(g, ENOTTY) : t->fg ? putcharm(t->fg) : ZeroPoint;
  love_musttail return Next(1); }

// (raw on) -- the terminal on fd 0 raw (1) or cooked (0); () when there is one to set
static lvm(lvm_kraw) {
  intptr_t fd = k_ttyfd(g, putcharm(0));
  struct k_pty *t = k_pty_row(fd);
  unsigned const cooked = pt_icanon | pt_echo | pt_isig | pt_icrnl;
  if (t) t->flags = charmp(Sp[0]) && getcharm(Sp[0]) ? t->flags & ~cooked : t->flags | cooked;
  Sp[0] = t || k_console_in(fd) ? ZeroPoint : love_err(g, ENOTTY);
  love_musttail return Next(1); }

// sys.c's ioctl: 0 | -ENOTTY. set 1 or 0 makes input raw or cooked first; the console keeps
// no discipline, only the answer
static bool k_con_raw;
int k_fd_term(int fd, int set, int *raw, uintptr_t *rows, uintptr_t *cols) {
  struct k_source const *s = k_source(fd);
  struct k_pty *t = k_pty_row(fd);
  if (!s || !(t || s->putc == serial_putc1 || s->readn == kb_readn)) return -ENOTTY;
  unsigned const cooked = pt_icanon | pt_echo | pt_isig | pt_icrnl;
  if (set >= 0 && t) t->flags = set ? t->flags & ~cooked : t->flags | cooked;
  else if (set >= 0) k_con_raw = set;
  *raw = t ? !(t->flags & pt_icanon) : k_con_raw;
  *rows = t ? t->rows : kcb ? kcb->rows : 24;
  *cols = t ? t->cols : kcb ? kcb->cols : 80;
  return 0; }

// (kproc argv env): a process of its own (sys.c), argv and env NUL-separated, this task's
// stdio -> (pid . a pipe's read end that ends with it) | the refusal
long k_proc_new(char const *av, uintptr_t an, char const *ev, uintptr_t en, int const fds[3], int *wr);
long k_proc_reap(long pid);
love_noinline static struct g *k_kproc(struct g *g) {
  word aw = g->sp[0], ew = g->sp[1];
  if (!strp(aw) || !strp(ew)) return g->sp[0] = badarg(g), g;
  int fds[3], wr = -1;
  for (int i = 0; i < 3; i++) fds[i] = (int) k_ttyfd(g, putcharm(i));
  struct str *a = (struct str*) aw, *e = (struct str*) ew;
  long pid = k_proc_new(a->bytes, a->len, e->bytes, e->len, fds, &wr);
  if (pid < 0) return g->sp[0] = love_err(g, (int) -pid), g;
  if (!ok(g = have(g, Width(struct chain)))) return g;
  struct chain *w = ini_chain((struct chain*) bump(g, Width(struct chain)), putcharm(pid), putcharm(wr));
  return g->sp[0] = word(w), g; }
static lvm(lvm_kproc) {
  LvmCallp(g, 1, k_kproc) }

// (kreap pid) -- an ended process's status, its slot freed; () while it runs
static lvm(lvm_kreap) {
  long r = charmp(Sp[0]) ? k_proc_reap(getcharm(Sp[0])) : -EINVAL;
  Sp[0] = r == -EAGAIN ? ZeroPoint : r < 0 ? love_err(g, (int) -r) : putcharm(r);
  love_musttail return Next(1); }

// (kpump _): a turn for each process the kernel runs (sys.c's k_proc_pump): 0 none, 1 all
// waiting on a call, 2 one wants another turn
long k_proc_pump(void);
static lvm(lvm_kpump) {
  Sp[0] = putcharm(k_proc_pump());
  love_musttail return Next(1); }

// (openpty _) -- a fresh pty as its rows: (master slave signal)
love_noinline static struct g *k_openpty(struct g *g) {
  int fds[3];
  int e = k_fd_pty(fds);
  if (e) return g->sp[0] = love_err(g, -e), g;
  if (!ok(g = have(g, 3 * Width(struct chain)))) {
    for (int i = 0; i < 3; i++) k_row_close(fds[i]);
    return g; }
  word l = ZeroPoint;
  for (int i = 2; i >= 0; i--)
    l = word(ini_chain((struct chain*) bump(g, Width(struct chain)), putcharm(fds[i]), l));
  return g->sp[0] = l, g; }

static lvm(lvm_kopenpty) {
  LvmCall(g, k_openpty) }

// the paper for a window of its own: held away from the console, which repaints when it comes
// back; the keys as set-1 codes off the tap beside their text
static struct g *k_charms(struct g *g, intptr_t const *v, int n) {
  if (!ok(g = have(g, n * Width(struct chain)))) return g;
  word l = ZeroPoint;
  for (int i = n - 1; i >= 0; i--)
    l = word(ini_chain((struct chain*) bump(g, Width(struct chain)), putcharm(v[i]), l));
  return g->sp[0] = l, g; }
// (kpaper 1) holds it and arms the taps -> (w h), () with no paper; (kpaper 0) gives it back
love_noinline static struct g *k_paper(struct g *g) {
  if (!(charmp(g->sp[0]) && getcharm(g->sp[0]))) {
    if (kkb.hold) kkb.hold = 0, k_scan_arm(0), fbwash();
    return g->sp[0] = ZeroPoint, g; }
  if (!kfb._ || !kcb) return g->sp[0] = ZeroPoint, g;
  kkb.hold = 1, kkb.pqh = kkb.pqt = 0, k_scan_arm(1);
  kkb.sw = kfb.width, kkb.sh = kfb.height;
  intptr_t const v[2] = { kfb.width, kfb.height };
  return k_charms(g, v, 2); }
// (kshow cask y0 y1): rows y0..y1 of a screen-sized paper (32-bit pixels, as paint.c lays them)
// -> the rows shown; 0 when the paper is not held or no longer fits
love_noinline static struct g *k_show(struct g *g) {
  uintptr_t n = 0;
  uint8_t const *s = cask_bytes(g->sp[0], &n);
  uintptr_t const w = kfb.width, h = kfb.height;
  intptr_t y0 = charmp(g->sp[1]) ? getcharm(g->sp[1]) : 0, y1 = charmp(g->sp[2]) ? getcharm(g->sp[2]) : 0;
  if (y0 < 0) y0 = 0;
  if (y1 > (intptr_t) h) y1 = (intptr_t) h;
  if (!kkb.hold || !s || n != w * h * 4 || y1 <= y0) return g->sp[0] = putcharm(0), g;
  for (intptr_t y = y0; y < y1; y++) {
    volatile uint32_t *d = kfb._ + (uintptr_t) y * kfb.pitch;
    uint32_t const *r = (uint32_t const*) s + (uintptr_t) y * w;
    for (uintptr_t x = 0; x < w; x++) d[x] = r[x]; }
  k_fb_touch();
  return g->sp[0] = putcharm(y1 - y0), g; }
// (kscan _) -- the held paper's next event: a key's set-1 code (bit 7 the break, 0x100 the
// extended keys), (how b x y) for the pointer, (w h) when the paper changed size; () for none
love_noinline static struct g *k_scanev(struct g *g) {
  if (!kkb.hold) return g->sp[0] = ZeroPoint, g;
  k_kb_poll();
  if (kfb.width != kkb.sw || kfb.height != kkb.sh) {
    kkb.sw = kfb.width, kkb.sh = kfb.height;
    intptr_t const v[2] = { kkb.sw, kkb.sh };
    return k_charms(g, v, 2); }
  if (kkb.pqh != kkb.pqt) {
    uint16_t const *p = kkb.pq[kkb.pqh];
    intptr_t const v[4] = { p[0], p[1], p[2], p[3] };
    kkb.pqh = (kkb.pqh + 1) & 15;
    return k_charms(g, v, 4); }
  int const c = k_scan_pop();
  return g->sp[0] = c < 0 ? ZeroPoint : putcharm(c), g; }
static lvm(lvm_kpaper) {
  LvmCall(g, k_paper) }
static lvm(lvm_kshow) {
  LvmCallp(g, 2, k_show) }
static lvm(lvm_kscan) {
  LvmCall(g, k_scanev) }

static lvm(lvm_tty) {
  LvmCall(g, k_tty) }

static lvm(draw) {
 if (!kkb.hold) fbdraw();
 k_wait();
 love_musttail return Next(1); }


static lvm(key) {
 int b = kqpop();
 Sp[0] = putcharm(b < 0 ? 0 : b);
 love_musttail return Next(1); }

// (color fg bg): xterm-256 indices, the attribute and every cell on screen; two in, one out
static lvm(color) {
 uint8_t fg = getcharm(Sp[0]), bg = getcharm(Sp[1]);
 if (kcb) cb_recolor(kcb, cb_ink(cb_idx, fg), cb_ink(cb_idx, bg));
 Sp[1] = ZeroPoint;
 love_musttail return Nextp(1, 1); }

// (fault n): a CPU exception for arch.c's ap, n x64's vector numbers; what follows runs only on a miss
static lvm(lvm_fault) {
  k_fault_trigger(getcharm(Sp[0]));
  love_musttail return Next(1); }

// (quit code): a task with a pid quits as _exit (task.c), the code what `wait` answers; else
// the machine resets (test/kernel/kore0.l). main.c's quit branches here on a negative osv
lvm(k_lvm_quit) {
  if (k_cur_pid(g)) love_musttail return Ap(lvm_task_quit, g);
  k_reset();
  love_musttail return Next(1); }

static union u
  nif_reset[] = {{kreset}},
  nif_draw[] = {{draw}, {lvm_ret0}},
  nif_key[] = {{key}, {lvm_ret0}},
  nif_color[] = {{lvm_cur}, {.x = putcharm(2)}, {color}, {lvm_ret0}},
  nif_disk[] = {{lvm_disk}, {lvm_ret0}},
  nif_disk_read[] = {{lvm_cur}, {.x = putcharm(2)}, {lvm_disk_read}, {lvm_ret0}},
  nif_disk_write[] = {{lvm_cur}, {.x = putcharm(2)}, {lvm_disk_write}, {lvm_ret0}},
  nif_fetch[] = {{lvm_cur}, {.x = putcharm(2)}, {lvm_fetch}, {lvm_ret0}},
  nif_kexec[] = {{lvm_cur}, {.x = putcharm(2)}, {lvm_kexec}, {lvm_ret0}},
#if defined(__x86_64__) && !defined(INLE_DROID)
  nif_svm[] = {{lvm_svm}, {lvm_ret0}},
  nif_svm_run[] = {{lvm_svm_run}, {lvm_ret0}},
  nif_vmx[] = {{lvm_vmx}, {lvm_ret0}},
  nif_vmx_run[] = {{lvm_vmx_run}, {lvm_ret0}},
#endif
  nif_fault[] = {{lvm_fault}, {lvm_ret0}},
  nif_tty[] = {{lvm_tty}, {lvm_ret0}},
  nif_ksettty[] = {{lvm_cur}, {.x = putcharm(3)}, {lvm_ksettty}, {lvm_ret0}},
  nif_kttyfg[] = {{lvm_kttyfg}, {lvm_ret0}},
  nif_kttypg[] = {{lvm_kttypg}, {lvm_ret0}},
  nif_kraw[] = {{lvm_kraw}, {lvm_ret0}},
  nif_kopenpty[] = {{lvm_kopenpty}, {lvm_ret0}},
  nif_kproc[] = {{lvm_cur}, {.x = putcharm(2)}, {lvm_kproc}, {lvm_ret0}},
  nif_kreap[] = {{lvm_kreap}, {lvm_ret0}},
  nif_kpump[] = {{lvm_kpump}, {lvm_ret0}},
  nif_kpaper[] = {{lvm_kpaper}, {lvm_ret0}},
  nif_kshow[] = {{lvm_cur}, {.x = putcharm(3)}, {lvm_kshow}, {lvm_ret0}},
  nif_kscan[] = {{lvm_kscan}, {lvm_ret0}};

// in address order and merged, whatever order the map gave
static bool meminit(void) {
  if (!kboot.ram_n) return false;
  for (uint32_t i = 0; i < kboot.ram_n; i++) {
    struct mem *m = (struct mem*) (kboot.hhdm + kboot.ram[i].base);
    m->len = kboot.ram[i].len / sizeof(uintptr_t);
    kram_words += m->len;
    ff_free(&kmem, ff_body(m)); }
  return true; }

// the door's scale where it knows the screen better, else the largest leaving 80x24
static uint8_t fbscale(void) {
  uint8_t s = 1;
  while (s < 8 && kfb.width / (kface.w * (s + 1u)) >= 80
               && kfb.height / (kface.h * (s + 1u)) >= 24) s++;
  return s; }

static bool fbinit(void) {
  if (!kboot.has_fb) return false;
  kfb._      = (void*) ((uintptr_t) kboot.fb.base + (k_xw ? khhdm : 0));   // the lower half is a process's
  kfb.width  = kboot.fb.w;
  kfb.height = kboot.fb.h;
  kfb.pitch  = kboot.fb.pitch_px;
  kfb.scale  = kboot.fb.scale ? kboot.fb.scale : fbscale();
  // with no reservation the paper cannot be resized
  kfb.cap_px = kboot.fb.cap_px ? kboot.fb.cap_px : (uint32_t) kfb.width * kfb.height;
  return true; }

static bool cbinit(void) {
  const uintptr_t rows = kfb.height / (kface.h * kfb.scale),
                  cols = kfb.width / (kface.w * kfb.scale);
  // kmallocw, not alloc: cbinit runs before ini, so no g exists yet
  uint32_t sn = k_sn(rows, cols), hl = k_hl(cols), tw = 1;
  if (!(kcb = kmallocw(b2w(cb_size(rows, cols, sn) + cb_hsize(hl, cols) + cb_tsize(rows, cols)))))
    sn = hl = tw = 0, kcb = kmallocw(b2w(cb_size(rows, cols, 0)));   // no room: the grid alone
  if (!kcb) return false;
  cb_open(kcb, rows, cols, sn);
  cb_hist(kcb, hl), cb_twin(kcb, tw);
  kcb->flag |= cb_lnm;  // the kernel console's discipline: a bare \n is a newline
  cb_attr(kcb, cb_ink(cb_idx, 15), cb_ink(cb_idx, 0));   // white on black: xterm-256's 15 and 0, what a terminal is
  cb_fill(kcb, 0);
  return true; }

// knifs, apart from love_nifs: the hosted book must not carry reset, fault, the disk or the
// virt doors. indexed by position after love_nifs, so append only
static struct def const __attribute__((section("knifs"), used)) defs[] = {
  {"reset", {.k = nif_reset}},
  {"draw", {.k = nif_draw}},
  {"key", {.k = nif_key}},
  {"fault", {.k = nif_fault}},
  // posix.c's and main.c's nifs land in love_nifs; quit and getpid branch here on a negative osv.
  // the raw disk has no host twin: absence and refusal answer (), presence the sector count
  {"disk", {.k = nif_disk}},
  {"disk-read", {.k = nif_disk_read}},
  {"disk-write", {.k = nif_disk_write}},
  // x64 only: ask (elem 'svm (names ())) first, else the read is missing, not absence
#if defined(__x86_64__) && !defined(INLE_DROID)
  {"svm", {.k = nif_svm}},
  {"svm-run", {.k = nif_svm_run}},
  {"vmx", {.k = nif_vmx}},
  {"vmx-run", {.k = nif_vmx_run}},
#endif
  {"color", {.k = nif_color}},
  // the no-op roster below pins tty only where a seat lacks it
  {"tty", {.k = nif_tty}},
  {"settty", {.k = nif_ksettty}},
  {"ttyfg", {.k = nif_kttyfg}},
  {"ttypg", {.k = nif_kttypg}},
  {"raw", {.k = nif_kraw}},
  {"openpty", {.k = nif_kopenpty}},
  {"fetch", {.k = nif_fetch}},
  {"kexec", {.k = nif_kexec}},
  // where a seat can run them (sys.c)
  {"kproc", {.k = nif_kproc}},
  {"kreap", {.k = nif_kreap}},
  {"kpump", {.k = nif_kpump}},
  // seat.l's kwin-events
  {"kpaper", {.k = nif_kpaper}},
  {"kshow", {.k = nif_kshow}},
  {"kscan", {.k = nif_kscan}} };

// the kore cat is read off the ramfs at boot: only the order is baked
static char const src_korelist[] =
#include "korelist.h"
;
static char const src_seat[] =
#include "seat.h"
;
// tasks.l: a woken image carries it, from main.c's bake
static char const src_tasks[] =
#include "tasks.h"
;
// the crew's order, its members read off /love at the first ask; paths, as a module's name
// does not say its file and sb spans three, loaded in order
static char const src_crewlist[] =
#include "crewlist.h"
;

void kmain(void) {
#if defined(__x86_64__) && !defined(INLE_DROID)
 // before any other C: a struct copy may be movups, a silent triple fault while SSE is masked
 k_sse_enable();
#endif
 // -1, we are the kernel: written before any libc member asks, or its lazy probe issues a real
 // syscall into our own #UD handler. the seat arms with it (sys.c)
 __love_osv = -1;
 k_seat_init();
 khhdm = kboot.hhdm;
 archinit();
 // the door's date, else the RTC, reachable once archinit has mapped it
 if (!kboot.date) kboot.date = k_rtc();
 serial_init();
 // only meminit is required: without fbinit or cbinit the kernel runs on serial alone
 if (meminit()) {
  if (fbinit()) cbinit();        // the framebuffer console
 // kmallocw memory, so pa = va - khhdm holds for everything the device reads
  k_blk_init(kmallocwa(b2w(320), 16));
 // hda: rings, buffer list and position buffer in one 128-aligned block; the sample ring apart
  k_hda_init(kmallocwa(b2w(3840), 128));
 // baked_pick reads the projection's re-based image as the hosted start does; NULL bakes the egg
  struct g *g = NULL;
  uintptr_t blen = 0;
  void const *bimg = NULL;
  if (kboot.image_len) bimg = kboot.image, blen = kboot.image_len;
  else if (!baked_pick(&bimg, &blen)) blen = 0;
  if (blen) g = love_image_load(bimg, blen, 0);
  bool woke = g != NULL;
  char const *s = woke ? "; inle -- image awake\n" : "; inle -- baking the egg\n";
  for (; *s; s++) serial_putc(*s);
  if (!woke) g = ini();
  // a woken book has them, mopped as the hosted bake left it
  if (!woke) g = defn(g, __start_love_nifs,
                         (uintptr_t)(__stop_love_nifs - __start_love_nifs));
  // then the kernel's own, on both lanes, so a kernel row wins any name it shares
  g = defn(g, __start_knifs,
              (uintptr_t)(__stop_knifs - __start_knifs));
  // the budget counts every pool but not a resize, which holds the old pair beside the new;
  // a third of RAM leaves room for that
  if (ok(g)) g->budget = kram_words / 3;
  // the kore roster; the cat itself is read off the ramfs below
  g = strof(g, src_korelist);
  struct def kd[] = {{"korelist", {.x = pop1(g)}}};
  g = defn(g, kd, countof(kd));
  g = strof(g, src_crewlist);
  struct def cd[] = {{"crewlist", {.x = pop1(g)}}};
  g = defn(g, cd, countof(cd));
  // the boot cmdline, raw; the boot text splits it into argv
  g = strof(g, kboot.cmdline);
  struct def bd[] = {{"bootline", {.x = pop1(g)}}};
  g = defn(g, bd, countof(bd));
  // the egg lane; the seat text below runs on both
  struct g *r = g;
  if (!woke) {
   r = cats_egg(g);
   r = cats_lib(r);                                  // the uses below are splices
   r = evals_(r,
    // verbs first: the cat's apps pin into its table, and the cmdline's program word reads it
    "(borrow 'verbs)"
    "(borrow 'uu) (: uu (cite 'uu))"                         // the uu kernel the corpus's uu files drive
    "(borrow 'cli)");
   r = evals_(r, src_tasks); }
  // seat.l: what this machine is that a host is not, shadowing a woken book's bindings
  r = evals_(r, src_seat);
  // a woken crew's seat-doors wrappers (main.c) read the door off the tablet: aim them here
  r = evals_(r,
   "(? (elem 'seat-doors (names ()))"
   "   (: _ (pin seat-doors 0 spawn) _ (pin seat-doors 1 spawnio)"
   "      _ (pin seat-doors 2 spawnmap) _ (pin seat-doors 3 wait)"
   "      _ (pin seat-doors 4 tether) _ (pin seat-doors 5 still) _ (pin seat-doors 6 tty)"
   "      _ (pin seat-doors 7 settty) _ (pin seat-doors 8 raw) _ (pin seat-doors 9 ttyfg)"
   "      (pin seat-doors 10 ttypg))"
   "   0)");
  // a fresh writable layer, so the shell's defglobs never land in the base
  r = love_open(r);
  // one absent nif the cat mentions would raise missing and bao's file-help quits the machine:
  // pin a no-op for each this seat lacks, retiring as the real nif lands. signal ignores
  r = evals_(r,
   "(: (signal n h) ())"
   "(map (\\ n (? (elem n (names ())) () (ev [': [n 'x] ()])))"
   "     '(hardlink spawn spawnmap fork exec herald wait still"
   "       getpid getuid seal ttyfg setpg umask rusage rlimit setrlimit glean pipe fdopen dup dup2 connect listen"
   "       bind accept recv send farend hark tty))");
  // the kore cat through the stream shell, seatless so the whole userland lands. egg lane
  // only: re-loading over a woken image re-pins every sealed verb
  if (!woke) {
  r = evals_(r,
   "(: (kwords s i j acc)"
   "    (? (< j (tally s))"
   "       (? (= 32 (peep s j 0))"
   "          (? (< i j) (kwords s (+ j 1) (+ j 1) (. (snip s i j) acc)) (kwords s (+ j 1) (+ j 1) acc))"
   "          (kwords s i (+ j 1) acc))"
   "       (? (< i j) (rev (. (snip s i j) acc)) (rev acc)))"
   "   open (cite 'posix 'open) close (cite 'posix 'close)"    // by value, as above
   "   (kslurp p) (: h (open (+ \"/love/\" p) \"r\") s (slurp h) _ (close h) s)"
   "   (kcat l) (? (two? l) (+ (kslurp (cap l)) (kcat (cup l))) \"\")"
   "   korecat (kcat (kwords korelist 0 0 ())))");
  r = evals_(r, "(reads (tap ((: (g i) (? (< i (tally korecat)) (. (peep korecat i 0) (g (+ 1 i))))) 0)))");
  }
  // the crew off the registry's miss, every boot: the load is idempotent, its source row the guard
  r = evals_(r, "((cite 'verbs 'fills) crewload)");
  // the program word dispatches off the registry. an empty line is a mitty, lush in its
  // first pane; once that ends or fails, the console shell
  r = evals_(r, "(: cmdline (. \"love\" bootargv) argv cmdline)");
  r = evals_(r,
   "(? (two? bootargv)"
   "   (: _ (hear (\\ a b (? (== a 'leave) (quit b)"
   "                        (: _ (say err \";; \") _ (print err a) _ (say err \" \") _ (print err b)"
   "                           _ (put err 10) (quit 1)))))"
   "      pr (k-prog bootargv)"
   "      r (? (two? pr) ((cap pr) (cup pr))"
   "           (: _ (say err (+ (cap bootargv) \": not found\")) _ (put err 10) 127))"
   "      (quit (? (charm? r) r 0)))"
   "   0)");
  r = evals_(r,
   "(: pr (k-prog (. \"mitty\" (. \"--here\" ())))"
   "   (? (two? pr) (trap (\\ _ ((cap pr) (cup pr))) () (\\ a b 0)) 0))");
  r = evals_(r, "(cite 'cli 'shell 0)");
  // a terminal scare's face on serial before reset
  if (code_of(r) == status_scare) scare_face(r);
  fin(r); }
 k_reset(); }
