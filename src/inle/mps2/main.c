// qemu MPS2+ AN500 (Cortex-M7) frontend: console and clock over ARM semihosting. all C is
// mooncc -t thumb2; only start.S and the final ld are arm-none-eabi. exit 42 = the laws hold
#include "../../love/love.h"
#include "../bput.h"

#ifndef EOF
#define EOF (-1)
#endif

// --- semihosting ----------------------------------------------------------
// start.S: op/arg in r0/r1, bkpt 0xAB, the answer in r0
uintptr_t sh_call(uintptr_t op, uintptr_t arg);
#define SH_WRITEC 0x03           // arg = &byte
#define SH_CLOCK  0x10           // centiseconds since start
#define SH_EXIT_X 0x20           // arg = {0x20026, code}: qemu exits with code

static void m7_exit(uintptr_t code) {
  uintptr_t blk[2] = { 0x20026, code };   // ADP_Stopped_ApplicationExit
  sh_call(SH_EXIT_X, (uintptr_t) blk);
  for (;;) ; }

static void sh_putc(int c) { char b = (char) c; sh_call(SH_WRITEC, (uintptr_t) &b); }

uintptr_t love_clock(void) { return sh_call(SH_CLOCK, 0) * 10; }   // cs -> ms

// every fault vectors here (start.S): name the stacked pc/lr, exit 98
static void sh_hex(uintptr_t v) { bput_x(sh_putc, v, 8); }

void fault_report(uintptr_t *frame) {    // frame: r0 r1 r2 r3 r12 lr pc xPSR
  bput_s(sh_putc, "\n; fault pc=");
  sh_hex(frame[6]);
  bput_s(sh_putc, " lr=");
  sh_hex(frame[5]);
  sh_putc('\n');
  m7_exit(98); }

// --- console input: CMSDK APB UART0 ---------------------------------------
// output rides semihosting, input UART0: semihosting READC blocks the vm with no readiness probe
#define UART0_BASE 0x40004000u
#define UREG(o) (*(volatile uint32_t *)(UART0_BASE + (o)))
static void uart_init(void) { UREG(0x10) = 16; UREG(0x08) = 3; }   // min bauddiv; TX+RX enable
static int uart_rx_ready(void) { return !!(UREG(0x04) & 2); }      // STATE bit1 = RX full

// --- cooperative waits ----------------------------------------------------
// no IRQs: spin against a love_clock deadline (ms; 0 = forever)
void love_sleep(uintptr_t ms) {
  if (!ms) { for (;;) if (uart_rx_ready()) return; }   // wait forever -- but wake on input
  uintptr_t start = love_clock();
  while (love_clock() - start < ms) ; }

// a negative fd (a string port) is always ready, or its task parks on a wait nothing
// satisfies; fd 0 is the real poll
bool ready(int fd, int events) { return fd || events != wait_in ? 1 : uart_rx_ready(); }

void wait_fds(struct wait_fd *fds, int n, uintptr_t ms) {
  if (n <= 0) { love_sleep(ms); return; }
  uintptr_t start = love_clock();
  for (;;) {
    for (int i = 0; i < n; i++) if (ready(fds[i].fd, fds[i].events)) return;
    if (ms && love_clock() - start >= ms) return; } }

// --- port vtable ----------------------------------------------------------
// in from UART0, a live wire: a dry read is 0, never EOF. out through semihosting
static intptr_t fd_readn(struct g *g, unsigned char *dst, uintptr_t n) {
  uintptr_t k = 0;
  while (k < n && uart_rx_ready()) dst[k++] = (unsigned char) (UREG(0x00) & 0xff);
  return (intptr_t) k; }

static struct g *fd_writen(struct g *g, unsigned char const *src, uintptr_t n) {
  for (uintptr_t k = 0; k < n; k++) sh_putc((char) src[k]);
  return g->b = (intptr_t) n, g; }

static struct g *fd_flush(struct g *g) { return g; }

struct fio love_stdin  = { { .ap = lvm_port_io, .vt = &love_fd_port_vt, .ungetc_buf = putcharm(EOF) }, .fd = putcharm(0) };
struct fio love_stdout = { { .ap = lvm_port_io, .vt = &love_fd_port_vt, .ungetc_buf = putcharm(EOF) }, .fd = putcharm(1) };
struct fio love_stderr = { { .ap = lvm_port_io, .vt = &love_fd_port_vt, .ungetc_buf = putcharm(EOF) }, .fd = putcharm(1) };
struct port_vt const love_fd_port_vt = { fd_flush, fd_writen, fd_readn, NULL };

#include "../../love/fdrow.h"                       // love_fd_readn / love_fd_say off the two above

// --- the exit builtin -----------------------------------------------------
// (m7exit code): code becomes qemu's exit status
static lvm(m7exit) {
  m7_exit(getcharm(Sp[0]));
  return Continue(); }                       // unreached

static union u const nif_m7exit[] = {{m7exit}, {lvm_ret0}};
static struct def defs[] = { {"m7exit", {.k = nif_m7exit}} };

// --- the arena ------------------------------------------------------------
// ffalloc over the AN500's 16 MB PSRAM at 0x60000000, by address: no linker section
#include "../ffalloc.h"

// the seat check: the egg hatched into the self-hosted ev, and a closure runs through the heap
#define SEAT_OK "(lit? ev && map (+ 1) '(1 2 3) = '(2 3 4))"
static struct mem *freelist;

#define POOL ((uint8_t*) 0x60000000u)
#define POOL_BYTES ((16u << 20) - 64)   // a one-past read at the edge stays inside PSRAM

static void *mallocw(uintptr_t n) { return ff_alloc(&freelist, n); }

void *malloc(size_t n) { return mallocw(b2w(n)); }

void free(void *p) { ff_free(&freelist, p); }

#ifdef BAKER_STONES
// the device's horn.c rides the baker and the waker for its rows; qemu has no speaker, so it refuses
int k_horn_open(int rate) { return -1; }
intptr_t k_horn_write(unsigned char const *src, uintptr_t n) { return -1; }
uintptr_t k_horn_lag(void) { return 0; }
void k_horn_close(void) {}
#endif
#if defined(BAKER_STONES)
#define IMPATH "out/mps2/love-pds.img"
#elif defined(BAKER_RUNE)
#define IMPATH "out/mps2/love-pd.img"
#else
#define IMPATH "out/mps2/love.img"
#endif

#ifdef WAKER
// --- the waker (-D WAKER): wakes the baker's love.img in a different binary; 42 = it woke
#define SH_OPEN  0x01
#define SH_CLOSE 0x02
#define SH_READ  0x06
#define SH_FLEN  0x0C
static void sh_puts(const char *s) { while (*s) sh_putc(*s++); }
// off the baker's base, so a value depending on the old pool address dies here; an offset,
// not a half, so a corpus that fits the bake fits the wake
#define WAKE_OFF (1u << 20)
int main(void) {
  sh_puts("\n; src/inle/mps2 waker -- cross-binary wake\n");
  freelist = (struct mem*) (POOL + WAKE_OFF);
  freelist->next = NULL;
  freelist->len = (POOL_BYTES - WAKE_OFF) / sizeof(uintptr_t);
  static const char impath[] = IMPATH;
  uintptr_t o[3] = { (uintptr_t) impath, 1, sizeof impath - 1 };   // mode 1 = "rb"
  intptr_t fd = (intptr_t) sh_call(SH_OPEN, (uintptr_t) o);
  if (fd < 0) { sh_puts("; no love.img\n"); m7_exit(3); }
  uintptr_t fl[1] = { (uintptr_t) fd };
  uintptr_t len = sh_call(SH_FLEN, (uintptr_t) fl);
  sh_puts("; image bytes "); sh_hex(len); sh_putc('\n');
  // the read buffer off the top of the pool
  char *buf = (char*) POOL + POOL_BYTES - ((len + 63u) & ~63u);
  freelist->len = (POOL_BYTES - WAKE_OFF - ((len + 63u) & ~63u)) / sizeof(uintptr_t);
  uintptr_t rd[3] = { (uintptr_t) fd, (uintptr_t) buf, len };
  if (sh_call(SH_READ, (uintptr_t) rd)) { sh_puts("; short read\n"); m7_exit(4); }
  uintptr_t cl[1] = { (uintptr_t) fd };
  sh_call(SH_CLOSE, (uintptr_t) cl);
  uintptr_t t0 = love_clock();
  struct g *g = love_image_load(buf, len, 0);
  if (!g) { sh_puts("; wake REFUSED\n"); m7_exit(5); }
  g = defn(g, defs, countof(defs));
  if (ok(g = push(g, 1, putcharm((intptr_t) (love_clock() - t0))))) {   // born: this wake's cost
    g = defv(g, "born");
    if (ok(g)) g->sp++; }
  if (ok(g)) g->budget = freelist->len / 4;
#ifdef BAKER_STONES
  sh_puts("; woke words: pool "); sh_hex(g->len); sh_puts(" major "); sh_hex(g->major_len);
  sh_puts(" live "); sh_hex(g->major_live0); sh_putc('\n');
  // as the device's: most of it, and a major at once so the woken pool is sized under that
  if (ok(g)) g->budget = (10u << 20) / sizeof(word);
  if (ok(g) && ok(g = gen_major(g, 0, NULL))) g->major_live0 = (uintptr_t) (g->major_hp - g->major_base);
  // the device's nifs, stood in for: up held, the crank turning, the picture only counted
  g = evals_(g, "(: (held _) 4 (pushed _) 0 (crank _) 10 (lcd f w h) (#f = w * h) (cur_set r c) 0)");
#endif
  struct g *r = evals_(g,
    "(: ok (&& "
    SEAT_OK
#if defined(BAKER_STONES)
    "          (tablet? (pd-at 'st))"           // the land built and kept, and ten frames walked
    "          (: t0 (clock 0) _ (each ^10 (_ \\ pd-frame ())) t1 (clock 0)"
    "             _ (puts (\"; ten frames, ms \" + show (t1 - t0) + \"\\n\"))"
    "             (0 < (pd-at 'st) 'pz)))"
#elif defined(BAKER_RUNE)
    "          (! ((cite ()) = ())))"           // rune registered
#else
    "          1)"
#endif
    "   _ (putc 10) _ (puts \"; the image woke -- love on the M7\") _ (putc 10)"
    "   (m7exit (? ok 42 1)))");
  if (code_of(r) == status_scare) scare_face(r);
  fin(r);
  m7_exit(2);
  return 0; }
#else
#ifdef BAKER
// --- the baker (-D BAKER): bake the corpus, dump the image to a host file (the teensy's flash
// blob). no port nifs before the dump, so the image is symbolic: wakeable by any same-word build
#define SH_OPEN  0x01
#define SH_WRITE 0x05
#define SH_CLOSE 0x02
static void sh_puts(const char *s) { while (*s) sh_putc(*s++); }
// rune is a plain text consumers borrow, so its module wrapper is here
static char const src_mods[] =
#ifdef BAKER_RUNE
"(module 'rune "
#include "rune.h"
")"
#else
""
#endif
;
int main(void) {
  sh_puts("\n; src/inle/mps2 baker -- baking the corpus\n");
  freelist = (struct mem*) POOL;
  freelist->next = NULL;
  freelist->len = POOL_BYTES / sizeof(uintptr_t);
  struct g *g = ini();          // no defn: a port nif would ride into the image as an absolute
#ifdef BAKER_STONES
  // ..but the love_nifs rows ride it by position: the stones' land is drawn at bake
  g = defn(g, __start_love_nifs, __stop_love_nifs - __start_love_nifs);
#endif
  if (ok(g)) g->budget = POOL_BYTES / sizeof(word) / 4;
#ifdef BAKER_STONES
  if (ok(g)) g->budget = POOL_BYTES / sizeof(word) * 3 / 8;   // the land outgrows a quarter
#endif
  struct g *r = egg(g,
#include "egg.h"
    ,
#include "prel.h"
    " "
#include "ev.h"
    ,
#include "post.h"
    );
  r = evals_(r, src_mods);
  r = evals_(r,
#if defined(BAKER_STONES)
    // the playdate's stones: the lore libraries and the glue, one text
#include "stones.h"
#elif defined(BAKER_RUNE)
    // the playdate corpus: rune + cas; cas's crank/pushed/cur_set stay unbound until the device defn's them
    "(borrow 'rune)"
    " "
#include "cas.h"
#else
    "(borrow 'cli)"
#endif
    "(: _ (pull book 'born 0)"            // this boot's cost, not the image's
    "   _ (putc 10) _ (puts \"; corpus baked -- dumping\") _ (putc 10) 0)");
  if (!ok(r)) {
    if (code_of(r) == status_scare) scare_face(r);
    m7_exit(3); }
  struct image_bad bad = { {0}, 0, 0 };               // an unencodable word refuses the dump
  uintptr_t len = 0;
  void *img = image_save(r, &len, &bad);
  if (!img) {
    sh_puts("; dump REFUSED at stage "); sh_hex((uintptr_t) bad.why);
    sh_puts(" -- (off, val, ap):\n");
    for (int i = 0; i < bad.n; i++) {
      sh_hex(bad.q[3 * i]); sh_putc(' ');
      sh_hex(bad.q[3 * i + 1]); sh_putc(' ');
      sh_hex(bad.q[3 * i + 2]); sh_putc('\n'); }
    m7_exit(4); }
  // r goes before the round trip: on 16 MB the wake's second pool needs the room
  fin(r);
  // a same-binary round trip before the file exists: catches a codec desync
  struct g *g2 = love_image_load(img, len, 0);
  if (!g2) { sh_puts("; round-trip load FAILED\n"); m7_exit(7); }
  struct g *r2 = evals_(g2,
    "(: _ (? "
    SEAT_OK
    " (puts \"; round-trip ok\") (puts \"; ROUND-TRIP BROKEN\"))"
    "   _ (putc 10) 0)");
  if (!ok(r2)) { sh_puts("; round-trip eval FAILED\n"); m7_exit(8); }
  static const char impath[] = IMPATH;
  uintptr_t o[3] = { (uintptr_t) impath, 5, sizeof impath - 1 };
  intptr_t fd = (intptr_t) sh_call(SH_OPEN, (uintptr_t) o);
  if (fd < 0) { sh_puts("; SYS_OPEN failed: "); sh_hex((uintptr_t) fd);
                sh_puts(" len "); sh_hex(len); sh_putc('\n'); m7_exit(5); }
  uintptr_t w[3] = { (uintptr_t) fd, (uintptr_t) img, len };
  if (sh_call(SH_WRITE, (uintptr_t) w)) m7_exit(6);
  uintptr_t c[1] = { (uintptr_t) fd };
  sh_call(SH_CLOSE, (uintptr_t) c);
  sh_puts("; image dumped\n");
  m7_exit(0);
  return 0; }
#else

// --- entry ----------------------------------------------------------------
// start.S enabled the FPU; qemu loaded .data/.bss. bake the egg, then the seat check
int main(void) {
  uart_init();
  for (char const *s = "\n; src/inle/mps2 -- baking the egg on the M7\n"; *s; s++)
    sh_putc(*s);
  freelist = (struct mem*) POOL;
  freelist->next = NULL;
  freelist->len = POOL_BYTES / sizeof(uintptr_t);
  struct g *g = defn(ini(), defs, countof(defs));
  if (ok(g)) g->budget = POOL_BYTES / sizeof(word) / 4;
  struct g *r = egg(g,
#include "egg.h"
    ,
#include "prel.h"
    " "
#include "ev.h"
    ,
#include "post.h"
    );
  r = evals_(r,
    "(: ok "
    SEAT_OK
    "   _ (putc 10) _ (puts \"; the egg hatched -- love on the M7\") _ (putc 10)"
    "   (m7exit (? ok 42 1)))");
  if (code_of(r) == status_scare) scare_face(r);
  fin(r);
  m7_exit(2);                                // fell out of the driver: loud
  return 0; }
#endif
#endif
