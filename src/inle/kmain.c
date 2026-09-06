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
// the timer runs at 100 Hz on both arches (mkvec.l's PIT divisor, a64's
// cntfrq/100), so one tick is this many milliseconds -- the granularity every
// deadline below rounds up to.
#define k_tick_ms 10
static uintptr_t k_ticks_for(uintptr_t ms) { return (ms + k_tick_ms - 1) / k_tick_ms; }
// higher-half direct map offset: physical P is reachable at khhdm + P, off kboot's hhdm.
// set before archinit, so arch code can use it for MMIO.
uintptr_t khhdm;
// the window that runs: the hhdm carries NX for the whole higher half (src/inle/mkboot.l), so
// heap is reachable there and not executable. the identity map is the same pages without
// the bit, which is what the image's code needs.
char *ai_code_window(char *p) { return (char*)((uintptr_t) p - khhdm); }

static struct mem {
  struct mem *next;
  uintptr_t len;
  uintptr_t _[];
} *kmem;

// total free RAM linked into kmem, in words -- summed in meminit, and the bound on the
// generational collector (g->budget) so its two pools stay within the device's RAM.
static uintptr_t kram_words;

static struct cb *kcb;

static struct {
  volatile uint32_t *_;
  uint16_t width, height, pitch; } kfb;

// keyboard input. kb_int (interrupt context) decodes scancodes into input bytes -- arrow
// and Delete as the ANSI escapes the line editor decodes -- and kb_readn and (key) drain
// the queue; g holds the live modifier flags. `raw` is the scancode tap beside it, for a
// program that wants make and break; the ascii queue still fills under it, unread.
static struct { uint8_t g, q[16], qh, qt; uint16_t lost;
                uint8_t raw, r[64], rh, rt; } kkb;
// enqueue one input byte. non-static: the COM1 serial RX ap (k_uart) feeds the same queue.
// a dropped keystroke says so. an interrupt cannot wait, so the ring is bounded and a fast
// paste can outrun it -- but a byte vanishing in silence is the one input failure a user
// cannot diagnose. the drop is counted, serial_flush says how many fell, and the count
// saturates rather than wrapping: "65535" understates where 0 would lie.
void kq(uint8_t b) {
  uint8_t n = (kkb.qt + 1) & 15;
  if (n != kkb.qh) kkb.q[kkb.qt] = b, kkb.qt = n;
  else if (kkb.lost != (uint16_t) -1) kkb.lost++; }
static int kqpop(void) {                   // dequeue one byte, -1 if empty
  if (kkb.qh == kkb.qt) return -1;
  int b = kkb.q[kkb.qh];
  return kkb.qh = (kkb.qh + 1) & 15, b; }

// the console's font. the palette that goes with it lives in src/core/quay/paint.c,
// which is the one place a cell becomes pixels.
static struct font const kfont = { .glyphs = (uint8_t*) moderndos_8x16, .w = 8, .h = 16 };



// the seat hooks src/host/fd.c branches to on a negative osv (weak no-ops there)
void k_row_close(int fd), k_sleep(uintptr_t ms), k_wait_fds(struct ai_wait_fd*, int, uintptr_t),
     k_seat_init(void);                // src/inle/sys.c: arm environ + the std streams
bool k_ready(int fd, int events);

// the panic-time console: the ring buffer (kcb) when there is one, mirrored to
// serial. takes no l state, so it runs from a fault handler with no live `struct g`
// -- which is what both arch backends want it for. serial_putc is theirs.
void kputc(int c) { if (kcb) cb_putc(kcb, (char) c); serial_putc(c); }
void kputs(char const *s) { while (*s) kputc(*s++); }
void kputn(uintptr_t n, int base) {
 static char const d[] = "0123456789abcdef";
 char buf[24]; int i = 0;
 do buf[i++] = d[n % base], n /= base; while (n);
 while (i) kputc(buf[--i]); }
// the kernel-only nif bracket (defs[] below); the linker synthesizes the pair
extern struct ai_def const __start_ai_knifs[], __stop_ai_knifs[];
// the metal image's far edge, PATCHED INTO THE FILE by the projection
// (tools/kproject.l) -- the flat link's kimage_end, as a value the one binary
// can carry. the sentinel is loud: unpatched, the memmap excludes nothing and
// the heap eats the kernel at once.
uintptr_t const k_image_top = 1;
// the baked-image door (src/host/image.c): a pure read off two symbols the
// projection re-bases, so the wake needs no finding on this seat either

#include "quay.h"
#include <stdarg.h>
// kboot -- the machine as the door found it, filled BEFORE kmain reads it:
// pvh_to_kboot off qemu's hvm_start_info, the UEFI loader off the firmware
// memmap and GOP, the a64 stub off the DTB. nothing below asks which door
// answered, which is the whole point of the struct.
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
// k_sources[] holds per-fd vtables, and the kernel's ai_fd_port_vt routes each call through
// k_sources[fd]. a NULL slot is "no method" and the dispatcher skips it: writes discard,
// reads answer the end, ready answers false. both directions can be bulk, and a row with no
// writen is written a byte at a time, which is all a console takes either way. `state` is
// per-instance scratch -- a ramfs fd holds its handle there, statics leave it null.
// the table grows and does not cap: k_source_open is the one door in, and it grows the
// table in the kernel's own heap, so nothing is silently refused at a ceiling.
// malloc is nolibc's, running its mmap arenas over src/inle/sys.c's page arm, which kmallocw
// supplies. so the door here stays kmallocw where g cannot be reached and g->alloc
// everywhere it can: one page supply under both.
void *kmallocw(uintptr_t n);
void kfree(void *p);

struct k_source {
  // the read door (love.h's readn contract, one fd deeper): >0 = bytes,
  // 0 = nothing waiting, -1 = end. it USED to be a per-byte getc answering
  // "-1 = EOF / no data" -- one sentinel, two meanings -- and the keyboard paid
  // for it by spinning the whole vm on an empty queue.
  intptr_t (*readn)(int fd, unsigned char *dst, uintptr_t n),
  // the bulk write door, the same contract mirrored: >0 = bytes taken, 0 = busy,
  // -1 = gone. a row carrying one is asked instead of putc -- which is how the
  // ramfs REFUSES an allocation it could not get, where a void putc could only
  // drop the byte in silence.
           (*writen)(int fd, unsigned char const *src, uintptr_t n);
  bool (*ready)(int fd);                // non-blocking probe
  void (*putc)(int fd, int c),
       (*flush)(int fd),
       (*close)(int fd),                // release per-fd state
       *state; };

// slot 0: PS/2 keyboard. drains what the interrupt queued and answers 0 when there is
// nothing -- never the end, the kb queue being endless on bare metal. the scheduler owns
// the wait.
static intptr_t kb_readn(int fd, unsigned char *dst, uintptr_t n) {
  uintptr_t k = 0;
  for (int b; k < n && (b = kqpop()) >= 0; ) dst[k++] = (unsigned char) b;
  return (intptr_t) k; }

static bool kb_ready(int fd) { return kkb.qh != kkb.qt; }

// Slot 1: serial console. Output goes to the framebuffer when one is
// present and is always mirrored to COM1. Flush triggers a frame draw.
static void serial_putc1(int fd, int c) {
  if (kcb) cb_putc(kcb, c);
  serial_putc(c); }

// the loud edge for kq's drops: the console is about to be shown, so say what
// the keyboard ring could not hold before the frame goes up.
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

// the boot rows are static on purpose and must stay that way: the console is how the kernel
// says anything at all, including that an allocation failed, so it cannot be the first thing
// that needs one. everything past them is heap. err carries its own fd, so the seat remap
// below tells 1 from 2 and a stage's out can ride a pipe while its scare stays on console.
static struct k_source k_boot[] = {
  [0] = { .readn = kb_readn,    .ready = kb_ready    },
  [1] = { .putc = serial_putc1, .flush = serial_flush },
  [2] = { .putc = serial_putc1, .flush = serial_flush }, };
static struct k_source *k_sources = k_boot;
static int k_sources_n = (int) countof(k_boot);

// the row for fd, or NULL -- the ONE bounds check in the file, so no dispatcher
// carries a limit of its own.
static ai_inline struct k_source *k_source(int fd) {
 return fd >= 0 && fd < k_sources_n ? &k_sources[fd] : NULL; }

// in range is not open, and a syscall face is the caller that has to care: a closed row is
// zeroed where it stands, never removed, so k_source keeps answering it. carrying any
// method at all is what live means -- k_fd_free's rule read the other way round.
static ai_inline bool k_row_live(int fd) {
 struct k_source const *s = k_source(fd);
 return s && (s->readn || s->writen || s->putc || s->flush || s->ready || s->close); }

// the door in: answer fd's row, making room for it first -- doubling from the boot rows,
// copying, and freeing the old table unless it is the static one, there being no realloc
// down here. NULL when there is no memory, a refusal the caller must read. the ramfs is
// the caller, so the grow branch runs on the first open file (test/kernel/ramfs.l).
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
// the love machine's dup2-in-the-child, and it is the port itself: a task wears a chain
// (i o e) of real ports (prel's `wear`, hook 6) and io_route swaps the folded in/out/err
// for them at every op, so ai_io_fd already answers the row and there is nothing here to
// translate. src/inle/sys.c's raw-fd door names absolute rows for the same reason.

// the running task's pid: the run ring's head IS the running task (love.c's law),
// its pid at node[2]. the main task wears the zero point there, and reads as 0 --
// which no spawned pid can be (the mint stream pre-increments).
static ai_inline intptr_t k_cur_pid(struct ai *g) {
 union u *t = ai_core_of(g)->tasks;
 return t && (t[2].x & 1) ? getcharm(t[2].x) : 0; }

// generic kernel dispatchers: readn/putc/flush route through k_sources[fd], the fd first
// read through the running task's seat. the NULL guards keep misuse from crashing.
// these are the row-level motions, on an already-resolved fd -- the port dispatchers below
// resolve through the seat first, where the syscall door and the raw-fd lanes do not.
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

// the port lanes ai_fd_port_vt (src/host/fd.c) takes on a negative osv: the seat
// translation, then the rows -- a protocol read(2) cannot carry (busy and end
// are distinct answers), which is why these do not ride the syscall door.
intptr_t k_port_readn(struct ai *g, unsigned char *dst, uintptr_t n) {
 return k_row_read((int) ai_io_fd(g->io), dst, n); }

struct ai *k_port_writen(struct ai *g, unsigned char const *src, uintptr_t n) {
 return g->b = k_row_write((int) ai_io_fd(g->io), src, n), g; }

// src/inle/sys.c's door: the POSIX shapes over the same rows. the port layer says end with -1 and
// read(2) says it with 0, so the ends are translated here rather than in the syscall table,
// where every future row would have to remember.
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

// ai_fd_close's inle lane (src/host/fd.c): close through k_sources[fd].
// Statics (stdin/stdout) have NULL close -- nothing to release.
void k_row_close(int fd) {
 struct k_source *s = k_source(fd);
 if (s && s->close) s->close(fd); }

// the kernel has no write-direction probe: a k_source that can take a byte can always take
// one, so an out park is ready by definition. a reader parks on the row its own worn port
// names, so the question is only ever about that row.
bool k_ready(int fd, int events) {
 if (fd < 0) return true;
 if (events != ai_wait_in) return true;
 struct k_source *s = k_source(fd);
 return s && s->ready && s->ready(fd); }

// multi-source wait; ticks=0 is infinite. a one-shot timer at the deadline would beat
// waking every tick. record which source answered rather than returning on the first: the
// scheduler reads `revents` back and skips re-asking about every fd it names, so a sweep
// costs one flag read per source and saves a walk of the ring per parked task.
void k_wait_fds(struct ai_wait_fd *fds, int n, uintptr_t ms) {
  if (n <= 0) { k_sleep(ms); return; }
  uintptr_t deadline = kticks + k_ticks_for(ms);
  for (;;) {
    int any = 0;
    for (int i = 0; i < n; i++) {
      int r = k_ready(fds[i].fd, fds[i].events);
      fds[i].revents = r ? fds[i].events : 0;
      any |= r; }
    if (any || (ms && kticks >= deadline)) return;
    k_wait(); } }

// milliseconds since the epoch: one scale for the scheduler's deadlines, for (clock t) and
// for every mtime. ai_clock is one body (src/host/posix.c) and src/inle/sys.c's arm serves it from
// here. the date rides kboot, and where nobody knew it this degrades to milliseconds since
// boot and says so by reading as 1970.
uintptr_t k_clock_ms(void) { return (uintptr_t) (kboot.date * 1000 + kticks * k_tick_ms); }

// Pure time-wait. ms=0 means infinite (caller is expected to chain with an
// input wait via ai_in->wait, so this should only be hit when no I/O is intended).
void k_sleep(uintptr_t ms) {
  uintptr_t deadline = kticks + k_ticks_for(ms);
  for (;;) {
    if (ms && kticks >= deadline) break;
    k_wait(); } }

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
// the scancode tap: arm it, then drain. a code is the PS/2 byte with the 0xe0
// prefix folded onto the one that follows it (bit 7 is the break bit, so an
// extended key wears 0x100) -- one word out, no state for the reader to keep.
void k_scan_arm(int on) { kkb.raw = on ? 1 : 0, kkb.rh = kkb.rt = 0; }
int k_scan_pop(void) {
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

// decode a PS/2 scancode (interrupt context) and enqueue input bytes. arrows, Home, End and
// Delete become the ANSI escapes the line editor decodes, and with Ctrl held Home/End emit
// the modified CSI form (`ESC [ 1 ; 5 H/F`) the editor reads as buffer top and end.
// Ctrl+letter becomes the matching control byte.
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
// the initrd is read-only bytes and one {path, bytes, len} row per file. reads come straight
// off it and the first write copies that file into the kernel heap, so the entry reads from
// the copy ever after: a file nobody writes costs a row and not one word of the bounded
// heap, and two opens of one path see each other's writes, the copy being per file.
// kmallocw/kfree rather than g->alloc, because a vt method is handed an fd and nothing else
// and g is out of reach at the door that grows a file. on this seat they are one heap.
// ms is the source's mtime, baked: the initrd carries no directory, so the date a file was
// last written on the machine that built it exists nowhere else.
struct k_file { char const *path, *bytes; uintptr_t len, ms; };
// THE INITRD IS THE SOURCE BLOB (plan D's first step): the artifact already
// carries its whole tree as ai_srcgz, so the shipped kernel inflates that and
// walks the tar instead of baking a second plain-text copy of anything. rows
// point into the inflated block, which lives as long as the kernel does.
static struct k_file const *k_bakes;
static int k_bakes_n;
#include "ustar.h"
// one ustar pass: count on the first, fill on the second. paths re-home below the archive's
// top, so the tree looks the same from inside as a checkout. plain files land whole; a
// symlink lands as a row whose target rides lnks[k] for the caller to resolve -- lib/'s door
// to the crew modules is symlinks, and dropping them would lose every module behind it.
static int k_tar_walk(unsigned char const *t, uintptr_t n, struct k_file *rows, char **lnks) {
  int k = 0;
  for (uintptr_t o = 0; o + 512 <= n && t[o];) {
    unsigned char const *h = t + o;
    uintptr_t sz = ai_ustar_octal(h + 124, 12);
    if (ai_ustar_member(h)) {
      if (rows) {
        char nm[256];
        uintptr_t ln = ai_ustar_name(h, nm, sizeof nm);      // TOP stripped
        char *p = kmallocw(b2w(ln + 1));
        if (!p) return -1;
        memcpy(p, nm, ln);
        p[ln] = 0;
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
  int n = k_tar_walk(t, un, NULL, NULL);
  if (n <= 0) return false;
  struct k_file *rows = kmallocw(b2w((uintptr_t) n * sizeof *rows));
  char **lnks = kmallocw(b2w((uintptr_t) n * sizeof *lnks));
  if (!rows || !lnks) return false;
  memset(lnks, 0, (uintptr_t) n * sizeof *lnks);
  if (k_tar_walk(t, un, rows, lnks) != n) return false;
  // resolve the symlinks against the rows (two passes cover a link to a link),
  // then compact: a dangling or directory link has no bytes to serve and the
  // old bake never carried one either.
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

// an object in this link may bake files of its own beside the initrd's: a strong k_baked
// overrides the weak nothing here and k_fs_init lays a row apiece (src/inle/doom.c's WAD is the
// first). the rows are read-only .rodata, so a write copies them into the heap the same way.
// it is asked twice -- with no room, for the count, then to fill -- so the table is the
// kernel's memory and the definer keeps no state of its own.
__attribute__((weak)) int k_baked(struct k_file *rows, int cap) {
  return (void) rows, (void) cap, 0; }
static struct k_file const *k_extra;
static int k_extra_n;
// what bake row i is: the initrd's, then the linked-in ones behind it.
static struct k_file const *k_bake_row(int i) {
  return i < k_bakes_n ? &k_bakes[i] : &k_extra[i - k_bakes_n]; }

// the tree itself (rung 2): a table of entries in the kernel heap, one per baked row at
// first touch, growing as create and mkdir add paths the bake never knew.
// `own` is the presence bit and has to be one: a file written and then emptied is {NULL, 0},
// which is what one still in .rodata looks like, so the flag is all that says which blob to
// read. `heap` is the same bit for the path, and a NULL path is a retired slot.
struct k_ent {
  char const *path;                 // the canonical key
  int bake;                         // the kfiles row backing reads until the first write; -1 none
  unsigned char *bytes;
  uintptr_t len, cap, ms, mode;     // mode is the permission bits; stat lays the kind over them
  int refs;                         // open fds; an unlinked entry frees at the last close
  char const *to;                   // a symlink's target, canonical and heap; NULL is not one.
                                    // no flag beside it: a link's target is never empty, so
                                    // the pointer is the presence bit `own` could not be.
  bool own, heap, dir, live;
};
static struct k_ent *k_ents;
static int k_ents_n, k_ents_cap;

// lay the table on first use: every baked row, live, reading off .rodata -- plus
// tmp, the scratch a POSIX machine promises and no initrd carries. idempotent, and
// a refusal leaves the console standing (the caller answers absence or ENOMEM).
static bool k_fs_init(void) {
  if (k_ents) return true;
  if (!k_bakes && !k_untar()) return false;
  int xn = k_baked(NULL, 0);
  if (xn > 0) {
    struct k_file *xr = kmallocw(b2w((uintptr_t) xn * sizeof *xr));
    if (!xr) return false;
    k_extra = xr, k_extra_n = k_baked(xr, xn); }
  int n = k_bakes_n + k_extra_n, cap = n + 8;
  struct k_ent *t = kmallocw(b2w((uintptr_t) cap * sizeof *t));
  if (!t) return false;
  for (int i = 0; i < n; i++) {
    struct k_file const *f = k_bake_row(i);
    t[i] = (struct k_ent) { .path = f->path, .bake = i,
                            .ms = f->ms, .mode = 0644, .live = true }; }
  t[n] = (struct k_ent) { .path = "tmp", .bake = -1, .ms = k_clock_ms(),
                          .mode = 0755, .own = true, .dir = true, .live = true };
  k_ents = t, k_ents_n = n + 1, k_ents_cap = cap;
  return true; }

// the cwd, a kernel string -- canonical ("" is the root), what k_canon resolves
// every relative path against. chdir writes it; cwd wears the leading slash.
static char k_cwd[256];
static uintptr_t k_cwd_n;

// resolve a path against the cwd into out (cap 256): absolute starts at the root.
// -> the canonical length (0 is the root), or -1 for one longer than any entry could carry.
static intptr_t k_canon(char const *p, uintptr_t pn, char *out) {
  uintptr_t n = 0;
  if (!(pn && p[0] == '/')) memcpy(out, k_cwd, n = k_cwd_n);
  return ai_path_canon(out, n, p, pn, 256); }

// one open file: which entry, where in it, and whether writes are allowed. rides
// the k_source row's `state`; the close door frees it.
struct k_fh { int i; uintptr_t pos; bool w; };

static intptr_t ram_readn(int fd, unsigned char *dst, uintptr_t n);

// the handle behind an fd, and nothing for a row that is not the ramfs's: `state` is
// per-instance scratch of whatever kind its row's methods please, so the read door is what
// says it means a file handle. lseek reaches fds it did not open.
static ai_inline struct k_fh *k_fh(int fd) {
  struct k_source *s = k_source(fd);
  return s && s->readn == ram_readn ? s->state : NULL; }

// what entry i reads as: the heap copy once there is one, the baked blob until then.
static unsigned char const *k_blob(int i, uintptr_t *len) {
  struct k_ent const *e = &k_ents[i];
  if (e->own) return *len = e->len, e->bytes;
  struct k_file const *f = k_bake_row(e->bake);
  return *len = f->len, (unsigned char const*) f->bytes; }

// src/inle/sys.c's seek. it answers a NEGATIVE errno, the one sign every C face in
// this kernel wears; the love door upstairs names it (ai_err). whence 0/1/2
// is SEEK_SET/CUR/END -- what the love door already meant by them.
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

// canonical path -> its live entry. LINEAR and unapologetic: the tree is a few
// dozen entries, and a hash would cost a table the boot has to build before it can
// open the file that would have justified it.
static int k_find(char const *p, uintptr_t n) {
  for (int i = 0; i < k_ents_n; i++)
    if (k_ents[i].live && k_ents[i].path
        && strlen(k_ents[i].path) == n && !memcmp(k_ents[i].path, p, n)) return i;
  return -1; }

// follow a symlink at the END of a canonical path, in place. LEAF ONLY: a link
// standing mid-path is not resolved, this tree having no directory that is a link.
// bounded, because a link may name another and a pair may name each other.
// -> the new length, or -ELOOP. a path that is not a link comes back untouched.
#define k_hops 8
static intptr_t k_deref(char *cp, intptr_t cn) {
  for (int hop = 0; hop < k_hops; hop++) {
    int i = cn > 0 ? k_find(cp, (uintptr_t) cn) : -1;
    if (i < 0 || !k_ents[i].to) return cn;
    // the target is held as WRITTEN, so it is canonicalized here and not at the
    // store: relative to the link's own directory, absolute from the root, and
    // either way losing the leading slash every entry path is spelled without.
    char nx[256];
    uintptr_t n = ai_lnk_canon(cp, k_ents[i].to, nx, sizeof nx);
    if (n >= sizeof nx) return -ELOOP;
    memcpy(cp, nx, n);
    cp[n] = 0;
    cn = (intptr_t) n; }
  return -ELOOP; }

// a slot for a fresh entry: a retired one first, else the table doubles. -1 is a
// refusal the caller reads.
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

// free a dead, unheld entry's storage and retire the slot. unlink and the last
// close both land here, so an open fd keeps its file until it lets go -- POSIX's
// rule, and the one that keeps a live handle off freed bytes.
static void k_ent_gc(int i) {
  struct k_ent *e = &k_ents[i];
  if (e->live || e->refs || !e->path) return;
  if (e->own) kfree(e->bytes);
  if (e->heap) kfree((void*) e->path);
  if (e->to) kfree((void*) e->to);
  *e = (struct k_ent) {0}; }

// a fresh live entry at canonical path p -- rung 2's create. the caller has
// already asked k_parent_ok; -1 is memory refusing.
static int k_create(char const *p, uintptr_t n, bool dir, uintptr_t mode) {
  char *q = k_strdup(p, n);
  if (!q) return -1;
  int i = k_ent_slot();
  if (i < 0) return kfree(q), -1;
  k_ents[i] = (struct k_ent) { .path = q, .bake = -1, .ms = k_clock_ms(),
                               .mode = mode, .own = true, .heap = true,
                               .dir = dir, .live = true };
  return i; }

// a directory can be a prefix: the initrd is flat ("src/apps/json/json.l" and no row for "lib"), so a
// name baked paths lie under is a directory with no entry of its own -- synthesized, 0755,
// wearing its newest child's date. mkdir is what gives one an entry of its own.

// entry i's name under a prefix of pn bytes -- NULL when it does not lie under it.
// An entry deeper than one level answers its next COMPONENT, so a subdirectory is
// named by the paths inside it as much as by any entry of its own.
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

// make room for `need` bytes in entry i's heap copy, bringing the baked blob
// across on the first write. -> false is a REFUSAL the caller must read and say;
// nothing is ever dropped quietly.
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

static intptr_t ram_readn(int fd, unsigned char *dst, uintptr_t n) {
  struct k_fh *h = k_fh(fd);
  if (!h) return -1;
  uintptr_t len;
  unsigned char const *p = k_blob(h->i, &len);
  // the end, never 0: a file does not grow under its reader, so "nothing waiting"
  // would park the scheduler on a source that will never speak.
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
  // a gap (a truncate under an append fd) reads as zeros, never as the bytes the
  // last tenant of that block left there.
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
  if (h && k_ents[h->i].refs) k_ents[h->i].refs--, k_ent_gc(h->i);
  kfree(s->state);
  *s = (struct k_source) {0}; }               // and the row is free again

// the lowest free row at or past the boot two -- POSIX's rule, which scripts lean
// on. A row is free when it carries no method at all, which is what k_source_open
// zeroes a fresh one to and what ram_close puts one back to. the floor is
// F_DUPFD's "lowest >= arg"; every other caller passes 0.
static int k_fd_free_at(int at) {
  int lo = at > (int) countof(k_boot) ? at : (int) countof(k_boot);
  for (int i = lo; i < k_sources_n; i++)
    if (!k_row_live(i)) return i;
  return k_sources_n > lo ? k_sources_n : lo; }
static int k_fd_free(void) { return k_fd_free_at(0); }

// open a path -> its fd, or -1. m is r read, w truncate, a append -- the one door under both
// `open` and `openfd`. w and a create an absent path whose parent is a directory; for r
// absence stays absence. a directory does not open: readdir is its read door.
// the path face answers an fd or a negative errno. the love doors above flatten every
// failure to -1 / (), so the reasons src/inle/sys.c's openat needs are told apart here and
// flattened in the marshaling, never the other way round.
ai_noinline int k_fs_open(char const *p, uintptr_t pn, char m) {
  if (m != 'r' && m != 'w' && m != 'a') return -EINVAL;
  if (!k_fs_init()) return -ENOMEM;
  char cp[256];
  intptr_t cn = k_canon(p, pn, cp);
  if (cn < 0) return -ENAMETOOLONG;
  if ((cn = k_deref(cp, cn)) < 0) return (int) cn;
  if (!cn) return -EISDIR;                       // the root is a directory
  int i = k_find(cp, (uintptr_t) cn);
  if (i >= 0 && k_ents[i].dir) return -EISDIR;
  bool made = false;
  if (i < 0) {
    // 'r' misses stay one k_find: they are the load path's probe lane. only a create pays
    // k_dirp, so a file never shadows a synthesized directory.
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
    // an open that refuses must leave the tree exactly as it found it -- a file
    // this call minted leaves with it.
    if (made) k_ents[i].live = false, k_ent_gc(i);
    return -ENOMEM; }
  // the truncate lands last, past every way this can still fail (same law).
  uintptr_t len = 0;
  struct k_ent *e = &k_ents[i];
  if (m == 'w') e->own = true, e->len = 0, e->ms = k_clock_ms();
  if (m == 'a') k_blob(i, &len);
  e->refs++;
  *h = (struct k_fh) { .i = i, .pos = len, .w = m != 'r' };
  *s = (struct k_source) { .readn = ram_readn, .writen = ram_writen,
                           .ready = ram_ready, .close = ram_close, .state = h };
  return fd; }
// the open/close nifs are src/host/posix.c's now (plan C2): its open(2)/close(2)
// land in src/inle/sys.c's arms, so the ramfs answers the same door -- and a
// directory opens as a dents row there, where the old ramfs-only nif said ().

// --- the file nifs: stat, readdir, lseek, openfd ---------------------------
// doc/misc/posix.md's conventions exactly, because kore reads these shapes and a wrong
// one is silent.
#define k_mode_file 0100000            // (& mode 61440) = 32768: a regular file
#define k_mode_dir  0040000            //                = 16384: a directory

// (stat path) -> (size mtime-ms mode ns) | (). ns is the ms date times a million, not a
// finer reading of it: this clock's last hand is the millisecond, and digits it does not
// have would be the wrong honesty. this answers what the ramfs knows and nothing it would
// have to invent -- ino, nlink, uid and dev are src/inle/sys.c's fabrication to make in the open,
// rather than this face's to bury.
struct k_st { uintptr_t size, ms, mode; };

// -> 0, or -ENOENT for a path that is not there. a synthesized directory -- a prefix with
// children but no entry of its own, and the root -- answers like any other, the initrd
// carrying no directories. that case is also why this fills a struct rather than handing
// back an entry index: it has no row to point at.
ai_noinline int k_fs_stat(char const *p, uintptr_t pn, struct k_st *st) {
  char cp[256];
  intptr_t cn;
  if (!k_fs_init()) return -ENOMEM;
  if ((cn = k_canon(p, pn, cp)) < 0) return -ENOENT;
  if ((cn = k_deref(cp, cn)) < 0) return (int) cn;  // stat(2), not lstat: readlink
  int i = k_find(cp, (uintptr_t) cn);               // is the door to the link itself
  uintptr_t kid;
  *st = (struct k_st) { 0, 0, 0 };
  if (i >= 0 && !k_ents[i].dir)
    k_blob(i, &st->size), st->ms = k_ents[i].ms,
    st->mode = k_mode_file | k_ents[i].mode;
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
// on. each end counts its holders and the queue frees when both counts reach zero.
// the queue grows rather than refusing at a cap -- the writer's lane is the static port's
// unbuffered zputc, which retries once and then drops the byte, so a bounded ring would shed
// bytes in silence under exactly the load it exists for (doc/misc/inle.md).
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
  // no readers is gone, not busy -- but with no SIGPIPE here the writer only learns if it
  // looks: the run is dropped, as the host drops one on EPIPE. a `yes` into a dead pipe spins.
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

// clone src's row into a fresh fd -- POSIX dup as a row alias. a pipe end shares the queue
// and bumps its side's count; a ramfs fd clones the handle, so the offset diverges where
// POSIX shares it (the shell's save/restore never seeks, and a shared-offset handle costs a
// refcounted box nothing asks for yet); a boot twin gets k_row_zero so its close frees it.
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
// src/inle/sys.c's doors over the same motions: fcntl's F_DUPFD (at = the floor)
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

// the row mechanics of pipe(2), g-free: two rows over one queue. src/inle/sys.c's
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

// --- directory rows: opendir(2)'s door, src/inle/sys.c's only caller ------------
// a directory opens as a row with a close and a dents cursor and nothing else: read(2) on it
// is EISDIR, and the love doors never make one. the cursor is the count of names already
// handed out, and the scan re-walks and skips, so no enumeration state outlives the call.
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
 if ((cn = k_canon(p, pn, cp)) < 0) return -ENAMETOOLONG;
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

// fstat(2)'s row face: what each row kind knows. the ramfs handle answers its
// entry, a pipe end is a fifo, a directory row its tree, the boot rows a
// character device. the struct stat fabrication stays src/inle/sys.c's.
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

// (getpid _) -> the running task's pid, a charm; the main task reads 0. the
// TASK pid: src/host/main.c's getpid nif branches here on a negative osv, where
// its own answer would be the machine's constant 1.
lvm(k_lvm_getpid) {
  Sp[0] = putcharm(k_cur_pid(g));
  ai_musttail return Next(1); }

// --- rung 5: the disk -- the block door love's filesystem (src/apps/fat/fat.l) rides.
// the driver is src/inle/blk.c (virtio-blk, polled, synchronous), and DMA rides the love string's
// own heap bytes -- nothing allocates between post and completion, so the collector cannot
// move the buffer under the device.
// (disk _)         -> the sector count, 0 when no disk: presence by the green.
// (disk-read l n)  -> a string of n*512 bytes off sector l | ().
// (disk-write l s) -> the sectors written | () (s must be whole sectors).
void k_blk_init(void *dma);
uint64_t k_blk_sectors(void);
int k_blk_rw(uint64_t lba, uint32_t n, void *buf, int wr);

static lvm(lvm_disk) {
  Sp[0] = putcharm((intptr_t) k_blk_sectors());
  ai_musttail return Next(1); }

ai_noinline static struct ai *k_disk_read(struct ai *g) {
  ai_word lw = g->sp[0], nw = g->sp[1];
  intptr_t lba = (lw & 1) ? getcharm(lw) : -1,
           n   = (nw & 1) ? getcharm(nw) : -1;
  if (lba < 0 || n <= 0 || n > 1 << 24) return g->sp[1] = ZeroPoint, g->sp += 1, g;
  if (!ai_ok(g = str0(g, (uintptr_t) n * 512))) return g;   // OOM: the wrapper ghelps
  if (k_blk_rw((uint64_t) lba, (uint32_t) n, txt(g->sp[0]), 0) < 0)
    g->sp[0] = ZeroPoint;
  return g->sp[2] = g->sp[0], g->sp += 2, g; }

static lvm(lvm_disk_read) {
 LvmCall(g, k_disk_read) }

ai_noinline static ai_word k_disk_write(ai_word lw, ai_word sw) {
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

// --- the SVM spike (x64 only; src/inle/x64/svm.c). (svm ()) is the capability and
// (svm-run ()) runs one guest, answering (exitcode rax rip) or (). nothing else asks for a
// guest yet: these two rows prove a guest can run and that the exit lands back in plain C.
#if defined(__x86_64__)

static lvm(lvm_svm) {
  Sp[0] = k_svm_ok() ? putcharm(1) : ZeroPoint;
  ai_musttail return Next(1); }

ai_noinline static struct ai *k_svm_run(struct ai *g) {
  uint64_t code = 0, rax = 0, rip = 0;
  if (!k_svm_ok()) return g->sp[0] = ZeroPoint, g;
  // the spike's pages ride a love string's own bytes -- blk.c's trick for DMA,
  // and safe for the same reason: nothing allocates between the carve and the
  // vmrun, so the collector cannot move the VMCB out from under the CPU. It
  // also keeps the machine from spending a page on a guest nobody asked for.
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

// ..and its Intel twin (src/inle/x64/vmx.c). (vmx-run ())
// answers FOUR numbers where the SVM door answers three: the last is the
// VM-instruction error, which is the only thing a refused entry has to say and
// is worth carrying out to where a human reads it.

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
// doc/misc/posix.md's conventions exactly: an effect answers 0 | -errno (the host's numbers
// negated) | EINVAL on misuse, and cwd answers the string | (). the environment is not
// here -- it is a tablet in the boot text below, as doc/misc/inle.md says.

// --- the path faces ------------------------------------------------------
// k_fs_* take (bytes, len) and answer 0 or a negative errno, as k_fd_* and k_parent_ok do --
// one sign for every C face in this kernel, and the one __ai_inle owes its caller, so
// src/inle/sys.c hands these answers straight out with no flip. the love side wears the same
// shape, so an answer crosses every seam untouched and () is absence and nothing else.
// ai_noinline is load-bearing: cp[256] in an lvm's own frame would block its musttail.
ai_noinline int k_fs_mkdir(char const *p, uintptr_t pn, uintptr_t mode) {
  char cp[256];
  intptr_t cn;
  if (!k_fs_init()) return -ENOMEM;
  if ((cn = k_canon(p, pn, cp)) < 0) return -ENAMETOOLONG;
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
  if ((cn = k_canon(p, pn, cp)) < 0) return -ENOENT;
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
  if ((cn = k_canon(p, pn, cp)) < 0) return -ENOENT;
  int i = cn ? k_find(cp, (uintptr_t) cn) : -1;
  if (i < 0) return k_dirp(cp, (uintptr_t) cn) ? -EISDIR : -ENOENT;
  if (k_ents[i].dir) return -EISDIR;
  k_ents[i].live = false;                        // an open fd keeps the bytes; the
  k_ent_gc(i);                                   // last close frees them
  return 0; }

// (symlink target path): an entry that is a name for another name. the target is
// stored as GIVEN -- relative or absolute, the way readlink(2) owes it back -- and
// canonicalized against the link's own place only when k_deref follows it.
ai_noinline int k_fs_symlink(char const *t, uintptr_t tn, char const *p, uintptr_t pn) {
  char cp[256];
  intptr_t cn;
  if (!k_fs_init()) return -ENOMEM;
  if (!tn || tn >= 256) return -ENAMETOOLONG;
  if ((cn = k_canon(p, pn, cp)) < 0) return -ENAMETOOLONG;
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
  if ((cn = k_canon(p, pn, cp)) < 0) return -ENOENT;
  int i = cn > 0 ? k_find(cp, (uintptr_t) cn) : -1;
  if (i < 0) return -ENOENT;
  if (!k_ents[i].to) return -EINVAL;
  uintptr_t tn = strlen(k_ents[i].to);
  if (!n) return -EINVAL;
  if (tn > n) tn = n;                            // readlink(2) truncates and does not say so
  memcpy(b, k_ents[i].to, tn);
  return (intptr_t) tn; }

// (rename old new): a file moves whole, a target file unlinked under it; a
// directory carries everything beneath it -- every live path at or under the
// prefix respelled, the copies staged FIRST so a refusal leaves the tree whole.
struct k_ren { struct k_ren *next; int i; char *q; };
ai_noinline int k_fs_rename(char const *o, uintptr_t olen,
                                   char const *n, uintptr_t nlen) {
  char op[256], np[256];
  intptr_t on, nn;
  if (!k_fs_init()) return -ENOMEM;
  if ((on = k_canon(o, olen, op)) < 0
   || (nn = k_canon(n, nlen, np)) < 0) return -ENAMETOOLONG;
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
  if ((cn = k_canon(p, pn, cp)) < 0) return -ENAMETOOLONG;
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

// the two attribute writers land on the ENTRY, so a synthesized (prefix)
// directory takes either as a no-op: it has no row to keep bits on, and its date
// is its children's. absence stays loud.
ai_noinline int k_fs_chmod(char const *p, uintptr_t pn, uintptr_t mode) {
  char cp[256];
  intptr_t cn;
  if (!k_fs_init()) return -ENOMEM;
  if ((cn = k_canon(p, pn, cp)) < 0) return -ENOENT;
  int i = k_find(cp, (uintptr_t) cn);
  if (i < 0) return k_dirp(cp, (uintptr_t) cn) ? 0 : -ENOENT;
  k_ents[i].mode = mode & 07777;
  return 0; }

ai_noinline int k_fs_utime(char const *p, uintptr_t pn, uintptr_t ms) {
  char cp[256];
  intptr_t cn;
  if (!k_fs_init()) return -ENOMEM;
  if ((cn = k_canon(p, pn, cp)) < 0) return -ENOENT;
  int i = k_find(cp, (uintptr_t) cn);
  if (i < 0) return k_dirp(cp, (uintptr_t) cn) ? 0 : -ENOENT;
  k_ents[i].ms = ms;
  return 0; }

static lvm(ai_kreset) { return k_reset(), g; }

// the cursor as last PAINTED. quay marks the row of every grid WRITE, and the cursor
// is not one: cb_cur moves wpos in silence and the blink is a function of the clock.
// So the renderer owns the cursor, or the block stays where it last was.
static uint32_t fbcur = ~0u;
static bool fbblink;

// repaint what moved: quay marks each written row in cb->dmg and the contract is that a
// renderer reads-and-clears (quay.h). this runs from serial_flush and love flushes per
// write, so painting the whole screen here cost a full-screen blit per character printed --
// 180s against 61s over the corpus under qemu, and a PCI write per cell on metal.
void fbdraw(void) {
  if (!kcb) return;                    // serial-only: no framebuffer console
  uint16_t const rows = kcb->rows, cols = kcb->cols;
  bool const blink = (kticks & 64) != 0;
  uint32_t const cur = kcb->flag & cb_show ? kcb->wpos : ~0u;
  // a hidden cursor's row is ~0u, which no row index equals, so it matches nothing.
  uint32_t const was = fbcur == ~0u ? ~0u : fbcur / cols,
                 now = cur == ~0u ? ~0u : cur / cols;
  bool const moved = cur != fbcur || blink != fbblink;
  // the paper is minted per FRAME, never per row: kticks is bumped by the timer ISR,
  // so re-reading the blink phase mid-frame could paint one row lit and the next dark.
  struct cb_paper const paper = { kfb._, kfb.pitch, kfb.width, kfb.height };
  for (uint16_t i = 0; i < rows; i++) {
    uint32_t const r = i > 255 ? 255 : i;   // quay's fold: bit 255 stands for 255-and-past
    if (kcb->dmg[r >> 5] >> (r & 31) & 1 || (moved && (i == was || i == now)))
      cb_paint(&paper, kcb, &kfont, i, 0, 0, blink ? cur : ~0u); }
  for (int k = 0; k < 8; k++) kcb->dmg[k] = 0;
  fbcur = cur, fbblink = blink; }

// the framebuffer as a program may borrow it whole: the base, the size, and the
// stride in PIXELS. false where the door handed over none (PVH has nothing to
// hand), which is the caller's cue to want the ESP door instead.
bool k_fb(volatile uint32_t **p, int *w, int *h, int *pitch) {
  if (!kfb._) return false;
  *p = kfb._, *w = kfb.width, *h = kfb.height, *pitch = kfb.pitch;
  return true; }

static lvm(draw) {
 fbdraw();
 k_wait();
 ai_musttail return Next(1); }


static lvm(key) {
 int b = kqpop();
 Sp[0] = putcharm(b < 0 ? 0 : b);
 ai_musttail return Next(1); }

static lvm(color) {
 uint8_t fg = getcharm(*Sp++), bg = getcharm(*Sp++);
 if (kcb) {
  cb_attr(kcb, fg, bg, 0);
  for (uint32_t i = 0, j = kcb->rows * kcb->cols; i < j; i++)
   kcb->cb[i] = cb_cell(cb_ch(kcb->cb[i]), fg, bg, 0); }
 ai_musttail return Next(1); }

// (fault n) -- deliberately raise a CPU exception to exercise the ap in arch.c.
// k_fault_trigger maps n to a concrete fault, the cases mirroring x64 vector numbers and
// each arch picking its analogue. the ap reports and halts, so k_fault_trigger does not
// return and the statements after the call are reachable only if the fault did not fire.
static lvm(lvm_fault) {
  k_fault_trigger(getcharm(Sp[0]));
  ai_musttail return Next(1); }

// (quit code) -- the exit door, and since rung 4 the door with two rooms behind
// it. a SEATED task (a spawned process) quits as _exit: its seated fds close --
// the write end's close is the downstream reader's EOF -- the seat retires, and
// the TASK lands dormant with the code as its retval, which is what `wait`
// (catch) answers. every program exit funnels here: the shim's wrapper quits the
// main's answer, its help quits a scare, and a folded (quit 0) inside a kore
// main was always going to arrive on its own feet.
// unseated, the exit is the MACHINE's, as rung 3 laid it: reset. a corpus that
// wants its own code answers it in love -- test/kernel/kore0.l pins (: (quit n) n)
// before the cat loads, one door deeper, and every tool then reads as its status.
static union u const k_exit_body[] = { {lvm_task_exit} };
// the spawned half: shut the rows this task's worn stdio names -- a pipe's write end has
// to close here for the downstream reader to see EOF, where the port's own finalizer would
// wait for a collection -- and clear the yield intentions. the port is neutered as its row
// goes, or io_close would shut the row a second time. a console row is nobody's to close.
// -> nonzero when the task has a pid, so the wrapper knows which room it is in.
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

// src/host/main.c's quit nif branches here on a negative osv: the task/machine door.
lvm(k_lvm_quit) {
  if (k_task_exit(g)) {
    // the love-machine _exit: the stack becomes just [code] and Ip a task-exit
    // cell, exactly the shape lvm_task_exit leaves -- catch reads node[7], donep
    // and scoop read the saved ap. the frame below Sp is abandoned whole.
    ai_word code = (Sp[0] & 1) ? Sp[0] : putcharm(0);
    Sp = (ai_word*) g + g->len - 1;
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
#if defined(__x86_64__)
  nif_svm[] = {{lvm_svm}, {lvm_ret0}},
  nif_svm_run[] = {{lvm_svm_run}, {lvm_ret0}},
  nif_vmx[] = {{lvm_vmx}, {lvm_ret0}},
  nif_vmx_run[] = {{lvm_vmx_run}, {lvm_ret0}},
#endif
  nif_fault[] = {{lvm_fault}, {lvm_ret0}};

// reads the door-populated kboot struct and links every reported free range into the kernel
// free list. entries are pushed in array order, so kmem points at the last and the earlier
// ones link through ->next.
static bool meminit(void) {
  if (!kboot.ram_n) return false;
  for (uint32_t i = 0; i < kboot.ram_n; i++) {
    struct mem *m = (struct mem*) (kboot.hhdm + kboot.ram[i].base);
    m->len = kboot.ram[i].len / sizeof(uintptr_t);
    kram_words += m->len;
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
  // kmallocw, not g->alloc: kmain runs cbinit before ai_ini, the console being how a failure
  // in ai_ini would be said. no g exists yet, so this names the kernel heap directly.
  if (!(kcb = kmallocw(b2w(sizeof(struct cb) + rows * cols * sizeof(uint32_t))))) return false;
  cb_open(kcb, rows, cols);
  kcb->flag |= cb_lnm;  // the kernel console's discipline: a bare \n is a newline
  cb_attr(kcb, 47, 56, 0);
  cb_fill(kcb, 0);
  return true; }

// the kernel's own nifs ride ai_knifs, a section apart: the one binary is also the hosted
// love, whose book must not carry reset, fault, the disk or the virt doors -- machinery that
// would misbehave under an OS rather than refuse. kmain drains love_nifs and then this
// bracket, so the kernel book carries both where the hosted main sees only love_nifs. the
// linker synthesizes the bracket, so there is no registration line anywhere. indexed by
// position like its sibling, so this order is part of an image's contract: append only.
static struct ai_def const __attribute__((section("ai_knifs"), used)) defs[] = {
  {"reset", (intptr_t) nif_reset},
  {"draw", (intptr_t) nif_draw},
  {"key", (intptr_t) nif_key},
  {"fault", (intptr_t) nif_fault},
  // the posix surface, open/close/quit/getpid included, is src/host/posix.c's and src/host/main.c's,
  // linked whole: their nifs land in this section, libc calls bottom out in src/inle/sys.c's
  // table, and quit and getpid branch to k_lvm_quit / k_lvm_getpid on a negative osv. what
  // stays below has no host twin.
  // rung 5: the disk -- the raw block door src/apps/fat/fat.l's filesystem rides. these
  // three are OURS (no host twin: the host has no raw disk), so the shapes are
  // love's -- absence and refusal answer (), presence is the green sector count.
  {"disk", (intptr_t) nif_disk},
  {"disk-read", (intptr_t) nif_disk_read},
  {"disk-write", (intptr_t) nif_disk_write},
  // x64 only, so a love-side reader asks (member? 'svm (names ())) before (svm ()): on
  // the a64 seat the nom is not in the book, so reading it is missing, not absence.
#if defined(__x86_64__)
  {"svm", (intptr_t) nif_svm},
  {"svm-run", (intptr_t) nif_svm_run},
  {"vmx", (intptr_t) nif_vmx},
  {"vmx-run", (intptr_t) nif_vmx_run},
#endif
  {"color", (intptr_t) nif_color} };

// the kore cat is CATTED FROM THE RAMFS at boot -- the blob initrd carries every
// member, so only the ORDER is baked: the korefiles roster, one line.
static char const src_korelist[] =
#include "korelist.h"
;

void kmain(void) {
#if defined(__x86_64__)
 // Enable x87/SSE before ANY other C runs -- a compiler vectorizes freely on
 // x64 (even a struct copy compiles to movups), and that #UDs into a triple
 // fault with no output while SSE is masked. This is the single SSE-enable
 // point; archinit no longer repeats it.
 k_sse_enable();
#endif
 // which kernel: -1, we ARE it. on metal __ai_start is not the entry, so the
 // value is written here, before any libc member can ask -- unwritten, the
 // lazy probe would issue a real `syscall` into our own #UD handler. the seat
 // arming rides with it: what a hosted start would set (src/inle/sys.c).
 __ai_osv = -1;
 k_seat_init();
 khhdm = kboot.hhdm;
 archinit();
 // the wall date, in the one order that can answer on every door: whatever the
 // door left in kboot if it had one, else the machine's RTC -- which archinit has
 // just made reachable (the a64 read is device memory, and mmio_map lays it).
 if (!kboot.date) kboot.date = k_rtc();
 serial_init();
 // the heap (meminit) is the only hard requirement. the framebuffer
 // console is optional: when fbinit/cbinit fail -- the door handed over no
 // framebuffer, or the console buffer won't allocate -- kcb stays null
 // and the kernel runs headless on the serial console alone.
 if (meminit()) {
  if (fbinit()) cbinit();        // the framebuffer console; the palette is a table now
  // the disk (rung 5): probe the bus, and hand the driver its one DMA block --
  // kmallocw memory, so pa = va - khhdm holds for everything the device reads.
  k_blk_init(kmallocw(b2w(352)));
  // the wake (phase D): the projection carries the artifact's baked image at its re-based
  // address, and ai_baked_pick reads it off the same two symbols the hosted start does.
  // any problem answers NULL and the egg bakes from source below, the host's own law.
  struct ai *g = NULL;
  uintptr_t blen = 0;
  void const *bimg = NULL;
  if (ai_baked_pick(&bimg, &blen)) g = ai_image_load(bimg, blen);
  bool woke = g != NULL;
  char const *s = woke ? "; inle -- image awake\n" : "; inle -- baking the egg\n";
  for (; *s; s++) serial_putc(*s);
  if (!woke) g = ai_ini();
  // the nif drains re-pin over a woken book too (the host's law, main.c): the
  // section rides this binary, so the addresses are the image's own.
  g = ai_defn(g, __start_love_nifs,
              (uintptr_t)(__stop_love_nifs - __start_love_nifs));
  // ..then the kernel's own bracket, so a kernel row wins any name it shares
  g = ai_defn(g, __start_ai_knifs,
              (uintptr_t)(__stop_ai_knifs - __start_ai_knifs));
  // bound the generational collector to the device's RAM (the Appel knob): without it the
  // nursery's copy-overhead resizer grows unbounded and gen_major's all-survive sizing asks
  // kmallocw for a block bigger than physical RAM. an eighth of free RAM leaves headroom for
  // the major's double-buffered resize, the free list and kmallocw fragmentation. the host
  // runs unbounded -- it has virtual memory and a fragmentation-proof malloc.
  if (ai_ok(g)) ai_core_of(g)->budget = kram_words / 8;
  // the kore ROSTER (rung 3): the cat itself is read off the ramfs below.
  g = ai_strof(g, src_korelist);
  struct ai_def kd[] = {{"korelist", ai_pop1(g)}};
  g = ai_defn(g, kd, countof(kd));
  // the boot cmdline, raw; the boot text below splits it into the argv shape.
  g = ai_strof(g, kboot.cmdline);
  struct ai_def bd[] = {{"bootline", ai_pop1(g)}};
  g = ai_defn(g, bd, countof(bd));
  // the EGG lane: load the prel, warm the module layers -- everything a woken
  // image already carries. the seat text below runs on BOTH lanes.
  struct ai *r = g;
  if (!woke) {
   r = ai_cats_egg(g);
   r = ai_cats_mods(r);                                  // register every baked module; the uses below are splices
   r = ai_evals_(r,
    // verbs FIRST: this machine's userland IS a verb table -- the cat's apps pin their
    // own names as they load, and the boot cmdline's program seat reads the registry.
    "(use 'verbs)"
    "(use 'uu) (: uu (from 'uu))"                         // the uu kernel: the corpus's uu files drive it through the
    "(use 'cli)"); }                                      //   one-name `uu` surface on this target too
  // FIXME waaaaay too much code in here, old style too. also, this gets eval'd by c0, right? not ideal.
  // FIXME again, waaaaaaaaaaaaaaaaaaaaaaaaaaay too much code in string literals! ridiculous!
  //
  // the seat text, both lanes: what this machine is that a host is not. over a woken book
  // these shadow the hosted bindings -- getenv reads envt here, not an empty environ.
  r = ai_evals_(r,
 // which kernel this is. main.c pins the same name off __ai_osv on a hosted seat;
 // here there is nothing to probe -- this IS the kernel -- so it is said outright.
 // kore's uname respells it through the prel's os-uname.
 "(: love-os 'inle)"
 // the environment (rung 2): a TABLET, the pairs on slot 0, closures over it
 // wearing the host's names and shapes -- getenv the value | () absent/misused,
 // setenv () | 'badarg misuse (a non-string value UNSETS, the absence lane),
 // environ the raw "NAME=value" strings.
 "(: envt (tablet 0)"
 "   (envget l n) (? (two? l) (? (= n (cap (cap l))) (cup (cap l)) (envget (cup l) n)) ())"
 "   (envcut l n) (? (two? l) (? (= n (cap (cap l))) (envcut (cup l) n)"
 "                              (link (cap l) (envcut (cup l) n))) ())"
 "   (getenv n) (? (string? n) (envget (peep envt 0 ()) n) ())"
 "   (setenv n v) (? (string? n)"
 "                   (: c (envcut (peep envt 0 ()) n)"
 "                      _ (pin envt 0 (? (string? v) (link (link n v) c) c)) ())"
 "                   'badarg)"
 "   (environ u) (map (\\ e (+ (cap e) (+ \"=\" (cup e)))) (peep envt 0 ())))"
 // the command line (rung 3): `bootargv` = (word..) off the raw boot line, split
 // quote-aware, so -append 'sh -c "cd lib; pwd"' reaches the shell as one command.
 // `cmdline` stays seatless until the cat is in: a member's seat fires as its own file is
 // read, and lush sits mid-cat, so it would take the machine with kore's applets still
 // unread. the boot dispatch at the foot wears the real line.
 "(: bootargv"
 "     (: (kw i w s acc) (? (<= (tally bootline) i) (rev (? (tally w) (link w acc) acc))"
 "                          (: c (bootline i)"
 // a char joins a string as a string of one: (+ w c) on mixed bands degenerates to w
 // alone, so a bare charm would drop every word's letters.
 "                             (? s (? (= c s) (kw (+ i 1) w 0 acc) (kw (+ i 1) (+ w (string c)) s acc))"
 "                                (= c 32) (kw (+ i 1) \"\" 0 (? (tally w) (link w acc) acc))"
 "                                (|| (= c 34) (= c 39)) (kw (+ i 1) w c acc)"
 "                                (kw (+ i 1) (+ w (string c)) 0 acc))))"
 "        (kw 0 \"\" 0 ()))"
 "   cmdline (link \"love\" ())"
 "   argv cmdline)"
 // rung 4: spawn/wait as a love-side shim over the core task ops. a process on this machine
 // is a task: k-prog maps argv onto a love main -- a verb off the registry, a tool's own
 // <name>-main where nothing registered one, or a .l path off the ramfs evaled form by form
 // (no fresh layer from here, so its defglobs land in the session -- the shim's honest
 // divergence). k-spawn1 twirls it under a help that quits any scare, then seats the pid's
 // stdio in the parent, twirl not switching, so the seat is laid before the child's first
 // read. every exit funnels through the seat-aware quit; wait is catch, the pid is the task
 // pid. pg/fg/closes are accepted and ignored: no process groups, no ^Z, and the seat dups
 // its own ends so there is nothing for a child to leak.
 "(: (k-bn p) (: n (tally p)"
 "     (go i r) (? (< i n) (go (+ i 1) (? (= (p i) 47) (+ i 1) r)) (snip p r n))"
 "     (go 0 0))"
 "   (k-run-file p) (\\ as (: q (open p \"r\")"
 "     (? (port? q)"
 "        (: t (slurp q) _ (close q)"
 "           (go cl) (: r (sound cl) (? (two? r) (: _ (ev (cap r)) (go (cup r))) 0))"
 "           (go t))"
 "        127)))"
 "   (k-tool nm as) (? (member? nm (names ())) (link (ev nm) as) ())"
 // the registry is the PATH on this machine: every app pins its own names into
 // (from 'verbs 'tab), and `word` applies the shadow rules -- a slashed word or
 // a .l name is a file and never a verb, which is what leaves the two lanes
 // below reachable. a verb takes the args AFTER its name, kore's convention.
 "   (k-prog argv) (: a0 (cap argv) b (k-bn a0) as (cup argv)"
 "     v ((from 'verbs 'word) a0)"
 "     (? !(nil? v) (link v as)"
 "        (: k (k-tool (intern (+ b \"-main\")) as)"
 "           (? (two? k) k"
 // `kore TOOL ..` where no dispatcher registered one -- the test kernel's seat,
 // which bakes the applet files and not kore.l
 "              (&& (= b \"kore\") (two? as))"
 "                (k-tool (intern (+ (cap as) \"-main\")) (cup as))"
 "              (two? (stat a0)) (link (k-run-file a0) as)"
 "              ()))))"
 "   (k-slot w n) (? (! (two? w)) () (n = 0) (cap w) (k-slot (cup w) (n - 1)))"
 // a console-numbered fd means the PARENT's view of it, so 2>&1 follows what the parent
 // wears; anything higher is duped, the port owning the copy from there.
 "   (k-port w n f) (? (! (charm? f)) (k-slot w n) (f < 0) (k-slot w n)"
 "                     (f < 3) (k-slot w f) (fdopen (dup f)))"
 "   (k-spawn1 argv f0 f1 f2) (: pr (k-prog argv)"
 "     w (worn ())"
 "     kw [(k-port w 0 f0) (k-port w 1 f1) (k-port w 2 f2)]"
 // worn across the twirl, which does not switch tasks: the child inherits node[7] and
 // nothing of ours runs in between, so the parent takes its own back on the next line.
 "     _ (wear kw)"
 // the help is the exit door too: a kore main leaves deep by scaring 'leave with its
 // status (src/apps/kore/core.l), and taking that as a plain scare would flatten every usage
 // code to 1. every other condition is the died-child face.
 "     p (twirl (\\ _ (: _ (hear (\\ a b (? (id? a 'leave) (quit b)"
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
 "   (spawnio argv i o e cl pg fg) (k-spawn1 argv (k-fdw i) (k-fdw o) (k-fdw e))"
 "   (spawnmap argv fdm cl pg fg)"
 "     ((: (go m a b c)"
 "          (? (! (two? m)) (k-spawn1 argv a b c)"
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
 "   (wait p) (catch p))"
  );
  // a woken image's crew captured the seat-doors wrappers (src/host/main.c), which
  // read the live door off the tablet -- aim them at this seat's task shim, so
  // a baked lush or cook spawns tasks here. the egg book has no tablet (its cat
  // captures the shim directly below), and the probe answers that.
  r = ai_evals_(r,
   "(? (member? 'seat-doors (names ()))"
   "   (: _ (pin seat-doors 0 spawn) _ (pin seat-doors 1 spawnio)"
   "      _ (pin seat-doors 2 spawnmap) (pin seat-doors 3 wait))"
   "   0)");
  // THE SESSION: a fresh writable layer, C-side (the host's run_program shape) --
  // the shell's defglobs (and the corpus stream's) land here, never in the base.
  r = ai_layer_(r);
  // rung 3: the userland. first test/00-init.l's move, for its reason: an unbound mention
  // raises missing at every define that names one, and bao's file-help folds a real quit,
  // so one absent nif in the cat resets the machine at load. pin a no-op fallback for
  // whichever host nifs the cat mentions and this seat lacks -- self-retiring, since a rung
  // that lands the real nif takes its name off by existing. raw answers (), the console
  // always being a raw tty, and signal accepts and ignores; lush's entry rides both.
  r = ai_evals_(r,
   "(: (raw m) () (signal n h) ())"
   "(map (\\ n (? (member? n (names ())) () (ev [': [n 'x] ()])))"
   "     '(hardlink spawn spawnmap fork exec herald wait still"
   "       getpid getuid seal ttyfg glean pipe fdopen dup dup2 connect listen"
   "       accept udp-bind udp-send udp-recv hark winsize))");
  // then the kore cat through the stream shell, quietly: the line is seatless here, so every
  // member's own seat sits out and the whole userland lands. the cat is built here member by
  // member off the blob initrd, korelist being the baked space-separated roster.
  // egg lane only: a woken image carries the crew baked, and re-loading over it would re-pin
  // every verb the bake sealed.
  if (!woke) {
  r = ai_evals_(r,
   "(: (kwords s i j acc)"
   "    (? (< j (tally s))"
   "       (? (= 32 (peep s j 0))"
   "          (? (< i j) (kwords s (+ j 1) (+ j 1) (link (snip s i j) acc)) (kwords s (+ j 1) (+ j 1) acc))"
   "          (kwords s i (+ j 1) acc))"
   "       (? (< i j) (rev (link (snip s i j) acc)) (rev acc)))"
   "   (kslurp p) (: h (open p \"r\") s (slurp h) _ (close h) s)"
   "   (kcat l) (? (two? l) (+ (kslurp (cap l)) (kcat (cup l))) \"\")"
   "   korecat (kcat (kwords korelist 0 0 ())))");
  r = ai_evals_(r, "(reads (tap ((: (g i) (? (< i (tally korecat)) (link (peep korecat i 0) (g (+ 1 i))))) 0)))");
  }
  // now the line wears its real shape and the program word dispatches off the
  // registry -- spawn's own door. a seated program quits with its status (the
  // reset door); an empty line falls to the console shell, the toolbox warm.
  r = ai_evals_(r, "(: cmdline (link \"love\" bootargv) argv cmdline)");
  r = ai_evals_(r,
   "(? (two? bootargv)"
   "   (: _ (hear (\\ a b (? (id? a 'leave) (quit b)"
   "                        (: _ (say err \";; \") _ (print err a) _ (say err \" \") _ (print err b)"
   "                           _ (put err 10) (quit 1)))))"
   "      pr (k-prog bootargv)"
   "      r (? (two? pr) ((cap pr) (cup pr))"
   "           (: _ (say err (+ (cap bootargv) \": not found\")) _ (put err 10) 127))"
   "      (quit (? (charm? r) r 0)))"
   "   0)");
  r = ai_evals_(r, "((from 'cli 'shell) 0)");
  // a terminal scare gets the honest face on the serial console before reset
  if (ai_code_of(r) == ai_status_scare) ai_scare_face_(r);
  ai_fin(r); }
 k_reset(); }
