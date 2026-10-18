// qemu -M virt (rv64) frontend, no foreign toolchain: mooncc -t rv64, start.o from holo IR
// (mkstart.l), our linker (-Ttext at 0x80000000, the ROM's jump). all MMIO: ns16550, CLINT
// mtime, the sifive test finisher. exit 42 = the laws hold, 98 = a trap
#include "../../love/love.h"
#include "../bput.h"

#ifndef EOF
#define EOF (-1)
#endif

// --- the metal ------------------------------------------------------------
// ns16550: THR/RBR at +0, LSR at +5 (bit 5 = THR empty, bit 0 = data ready)
#define UART ((volatile uint8_t *) 0x10000000u)
static void v_putc(int c) {
  while (!(UART[5] & 0x20)) ;
  UART[0] = (uint8_t) c; }
static int uart_rx_ready(void) { return UART[5] & 1; }

// mtime runs at 10 MHz
#define MTIME (*(volatile uint64_t *) 0x0200BFF8u)
uintptr_t love_clock(void) { return (uintptr_t) (MTIME / 10000u); }

// FINISHER_FAIL (0x3333) carries the exit status in its high half
#define TESTDEV (*(volatile uint32_t *) 0x100000u)
static void v_exit(uintptr_t code) {
  TESTDEV = ((uint32_t) code << 16) | 0x3333u;
  for (;;) ; }

static void v_puts(char const *s) { bput_s(v_putc, s); }
static void v_hex(uintptr_t v) { bput_x(v_putc, v, 16); }

// every trap vectors here (start.o's mtvec tail: mcause, mepc); exit 98
void fault_report(uintptr_t cause, uintptr_t epc) {
  v_puts("\n; trap cause=");
  v_hex(cause);
  v_puts(" epc=");
  v_hex(epc);
  v_putc('\n');
  v_exit(98); }

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
// the ns16550 is a live wire: a dry read is 0, never EOF
static intptr_t fd_readn(struct g *g, unsigned char *dst, uintptr_t n) {
  uintptr_t k = 0;
  while (k < n && uart_rx_ready()) dst[k++] = UART[0];
  return (intptr_t) k; }

static struct g *fd_writen(struct g *g, unsigned char const *src, uintptr_t n) {
  for (uintptr_t k = 0; k < n; k++) v_putc((char) src[k]);
  return g->b = (intptr_t) n, g; }

static struct g *fd_flush(struct g *g) { return g; }

struct fio love_stdin  = { { .ap = lvm_port_io, .vt = &love_fd_port_vt, .ungetc_buf = putcharm(EOF) }, .fd = putcharm(0) };
struct fio love_stdout = { { .ap = lvm_port_io, .vt = &love_fd_port_vt, .ungetc_buf = putcharm(EOF) }, .fd = putcharm(1) };
struct fio love_stderr = { { .ap = lvm_port_io, .vt = &love_fd_port_vt, .ungetc_buf = putcharm(EOF) }, .fd = putcharm(1) };
struct port_vt const love_fd_port_vt = { fd_flush, fd_writen, fd_readn, NULL };

#include "../../love/fdrow.h"                       // love_fd_readn / love_fd_say off the two above

// --- the exit builtin -----------------------------------------------------
// (vexit code): code becomes qemu's exit status
static lvm(vexit) {
  v_exit(getcharm(Sp[0]));
  return Continue(); }                       // unreached

static union u const nif_vexit[] = {{vexit}, {lvm_ret0}};
static struct def defs[] = { {"vexit", {.k = nif_vexit}} };

// --- the arena ------------------------------------------------------------
// ffalloc over 64 MB of DRAM, the ox64's PSRAM budget; the image sits at 0x80000000 and the
// C stack tops out at the pool's base
#include "../ffalloc.h"

// the seat check: the egg hatched into the self-hosted ev, and a closure runs through the heap
#define SEAT_OK "(lit? ev && map (+ 1) '(1 2 3) = '(2 3 4))"
static struct mem *freelist;

#define POOL ((uint8_t*) 0x82000000u)
#define POOL_BYTES ((64u << 20) - 64)   // a one-past read at the edge stays inside the region

static void *mallocw(uintptr_t n) { return ff_alloc(&freelist, n); }

void *malloc(size_t n) { return mallocw(b2w(n)); }

void free(void *p) { ff_free(&freelist, p); }

// --- entry ----------------------------------------------------------------
// start.o set sp, mstatus.FS and mtvec; fresh RAM is zero, .bss included. bake the egg,
// then the seat check
int main(void) {
  v_puts("\n; src/inle/virt -- baking the egg on the hart\n");
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
    "   _ (putc 10) _ (puts \"; the egg hatched -- love on the hart\") _ (putc 10)"
    "   (vexit (? ok 42 1)))");
  if (code_of(r) == status_scare) scare_face(r);
  fin(r);
  v_exit(2);                                 // fell out of the driver: loud
  return 0; }
