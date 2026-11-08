// teensy 4.1 (i.MX RT1062) frontend for love, bare metal: the love.h frontend contract and a
// few GPIO nifs. the console is LPUART6 on pins 0/1 at 115200 8N1 (USB CDC is a TODO, see
// README); teensy41.c owns boot image, startup, clocks, uart, timer and GPIO
#include "../../love/love.h"
#include "teensy41.h"
#include "../bput.h"
#include "psram.h"

#ifndef EOF
#define EOF (-1)
#endif

// cooperative waits spin against love_clock (ms; 0 forever): no IRQs, so nothing to WFE on
void love_sleep(uintptr_t ms) {
  if (!ms) { for (;;) if (serial_rx_ready()) return; }   // forever, but wake on input
  uintptr_t start = love_clock();
  while (love_clock() - start < ms) ; }

// the readiness law (main.c, kmain.c): a negative fd, a string port, is always ready, or its
// task parks on a wait nothing satisfies. fd 0 is the honest poll; other fds are nominal
bool ready(int fd, int events) { return fd || events != wait_in ? 1 : serial_rx_ready(); }

void wait_fds(struct wait_fd *fds, int n, uintptr_t ms) {
  if (n <= 0) { love_sleep(ms); return; }
  uintptr_t start = love_clock();
  for (;;) {
    for (int i = 0; i < n; i++) if (ready(fds[i].fd, fds[i].events)) return;
    if (ms && love_clock() - start >= ms) return; } }

// both ports ride LPUART6, the fd nominal. serial never reaches EOF: a dry read is 0, and
// serial_getc is called only behind serial_rx_ready, so an empty ring never spins the vm
static intptr_t fd_readn(struct g *g, unsigned char *dst, uintptr_t n) {
  uintptr_t k = 0;
  while (k < n && serial_rx_ready()) dst[k++] = (unsigned char) serial_getc();
  return (intptr_t) k; }

static struct g *fd_writen(struct g *g, unsigned char const *src, uintptr_t n) {
  for (uintptr_t k = 0; k < n; k++) {
    if (src[k] == '\n') serial_putc('\r');
    serial_putc(src[k]); }
  return g->b = (intptr_t) n, g; }

// nothing to push: a flush is where to say what the inbound ring dropped (teensy41.c's rx_put)
static struct g *fd_flush(struct g *g) {
  uint32_t lost = serial_rx_lost();
  if (lost) {
    bput_s(serial_putc, "\r\n; input lost: ");
    bput_n(serial_putc, lost, 10);
    bput_s(serial_putc, " bytes\r\n"); }
  return g; }

struct fio love_stdin  = { { .ap = lvm_port_io, .vt = &love_fd_port_vt, .ungetc_buf = putcharm(EOF) }, .fd = putcharm(0) };
struct fio love_stdout = { { .ap = lvm_port_io, .vt = &love_fd_port_vt, .ungetc_buf = putcharm(EOF) }, .fd = putcharm(1) };
struct fio love_stderr = { { .ap = lvm_port_io, .vt = &love_fd_port_vt, .ungetc_buf = putcharm(EOF) }, .fd = putcharm(1) };
struct port_vt const love_fd_port_vt = { fd_flush, fd_writen, fd_readn, NULL };

#include "../../love/fdrow.h"                       // love_fd_readn / love_fd_say off the two above

// (gpio_init pin)    -- claim a GPIO2 bit (pin 13 also gets its pad muxed); returns the pin
// (gpio_dir pin out) -- out non-zero => output; returns out
// (gpio_put pin val) -- val non-zero => high; returns val
// (gpio_get pin)     -- 1 high, 0 low
static lvm(love_gpio_init) {
  gpio_init(getcharm(Sp[0]));           // Sp[0], the pin, is the result
  Ip += 1;
  return Continue(); }

static lvm(love_gpio_get) {
  Sp[0] = putcharm(gpio_get(getcharm(Sp[0])));
  Ip += 1;
  return Continue(); }

static lvm(love_gpio_dir) {
  unsigned pin = getcharm(Sp[0]);
  int out = getcharm(Sp[1]) != 0;
  gpio_set_dir(pin, out);
  Sp[1] = putcharm(out);
  Sp += 1;
  Ip += 1;
  return Continue(); }

static lvm(love_gpio_put) {
  unsigned pin = getcharm(Sp[0]);
  int val = getcharm(Sp[1]) != 0;
  gpio_put(pin, val);
  Sp[1] = putcharm(val);
  Sp += 1;
  Ip += 1;
  return Continue(); }

// a 2-arg nif leads with lvm_cur, as the host's nif_open does
static union u const
  nif_gpio_init[] = {{love_gpio_init}, {lvm_ret0}},
  nif_gpio_get[]  = {{love_gpio_get}, {lvm_ret0}},
  nif_gpio_dir[]  = {{lvm_cur}, {.x = putcharm(2)}, {love_gpio_dir}, {lvm_ret0}},
  nif_gpio_put[]  = {{lvm_cur}, {.x = putcharm(2)}, {love_gpio_put}, {lvm_ret0}};

// the baked image (ld -b binary, teensy41.lds's .image). file scope: mooncc emits no
// relocation for a block-scope extern array
extern const char _binary_love_img_start[], _binary_love_img_end[];

static struct def defs[] = {
  {"gpio_init", {.k = nif_gpio_init}},
  {"gpio_dir",  {.k = nif_gpio_dir}},
  {"gpio_put",  {.k = nif_gpio_put}},
  {"gpio_get",  {.k = nif_gpio_get}}, };

// malloc/free for alloc's default: a first-fit free list (ffalloc.h) over the arena
#include "../ffalloc.h"

// the seat check: the egg hatched into the self-hosted ev, and a closure runs through the heap
#define SEAT_OK "(lit? ev && map (+ 1) '(1 2 3) = '(2 3 4))"
static struct mem *freelist;

static void *mallocw(uintptr_t n) { return ff_alloc(&freelist, n); }

void *malloc(size_t n) { return mallocw(b2w(n)); }

void free(void *p) { ff_free(&freelist, p); }

// the arena is the 16 MB PSRAM (psram.c), the qemu-M7 port's size; this OCRAM pool, too small
// to bake in, is the fallback
static uintptr_t pool[384 * (1 << 10) / sizeof(uintptr_t)];   // word-typed for alignment: mooncc parses no post-declarator attribute


int main(void) {
  // first light before any love runs; gpio_* indexes GPIO2 bits (the pin-13 LED is GPIO2_IO03)
  gpio_init(LED_BIT); gpio_set_dir(LED_BIT, 1); gpio_put(LED_BIT, 1);
  for (char const *s = "\r\n; inle/teensy41\r\n"; *s; s++)
    serial_putc(*s);
  // the core clock from the live mux state, so a failed retune shows on every boot
  { uint32_t mhz = 0;
    if (!(REG(CCM_CBCDR) & CBCDR_PERIPH_CLK_SEL)
        && (REG(CCM_CBCMR) & CBCMR_PRE_PERIPH_MASK) == CBCMR_PRE_PERIPH_PLL1
        && !(REG(CCM_CCSR) & CCSR_PLL1_SW_CLK_SEL))
      mhz = 24u * (REG(CCM_ANALOG_PLL_ARM) & 0x7Fu) / 2u
          / ((REG(CCM_CACRR) & 7u) + 1u)
          / (((REG(CCM_CBCDR) >> 10) & 7u) + 1u);
    bput_s(serial_putc, "; core ");
    if (mhz) { bput_n(serial_putc, mhz, 10);
      bput_s(serial_putc, " MHz\r\n"); }
    else bput_s(serial_putc, "on the ROM path\r\n"); }
  uint32_t psram_mb = psram_init();
  { char const *s = psram_mb ? "; psram arena up\r\n" : "; NO psram -- ocram fallback\r\n";
    for (; *s; s++) serial_putc(*s); }
  uintptr_t arena_words;
  if (psram_mb) {
    // 64 B shy of the edge: a one-past read at a block boundary must stay inside
    freelist = (struct mem*) 0x70000000u;
    arena_words = ((psram_mb << 20) - 64u) / sizeof(uintptr_t); }
  else {
    freelist = (struct mem*) pool;
    arena_words = sizeof pool / sizeof(uintptr_t); }
  freelist->next = NULL;
  freelist->len = arena_words;
  // wake first: the flash's image is baked by src/inle/mps2's qemu baker; NULL bakes the egg
  uintptr_t t0 = love_clock();
  struct g *g = love_image_load(_binary_love_img_start,
                               (uintptr_t)(_binary_love_img_end - _binary_love_img_start), 0);
  int woke = g != NULL;
  { char const *s = woke ? "; image awake\r\n" : "; no image -- baking the egg\r\n";
    for (; *s; s++) serial_putc(*s); }
  if (!woke) g = ini();
  g = defn(g, defs, countof(defs));
  // born: this wake's cost, as main.c defines it; the egg lane's egg.l pins its own
  if (woke && ok(g = push(g, 1, putcharm((intptr_t) (love_clock() - t0))))) {
    g = defv(g, "born");
    if (ok(g)) g->sp++; }
  // a budget, or the collector ooms inside a major; a quarter leaves a resize's two blocks and
  // fragmentation their room
  if (ok(g)) g->budget = arena_words / 4;
  // the LED: on while baking or waking, off at the prompt, fast blink fatal. 3 is LED_BIT
#define TE_TAIL(banner) \
    "   _ (gpio_init 3) _ (gpio_dir 3 1) _ (gpio_put 3 0)" \
    "   _ (putc 10)" \
    "   _ (puts (? ok \"" banner "\" \"; SEAT CHECK FAILED -- shell up anyway\"))" \
    "   _ (putc 10) ((cite 'cli 'shell) 0))"
  if (!woke) {
    // the on-device bake; cli is a module, borrowed below
    g = egg(g,
#include "egg.h"
    ,
#include "prel.h"
    " "
#include "ev.h"
    ,
#include "post.h"
    );
    g = evals_(g, "(borrow 'cli) 0"); }
  // the session: a fresh writable layer for the shell's defglobs, never the base
  g = love_open(g);
  // the seat check answers first: this board has no exit code to say it with
  struct g *r = evals_(g, woke ?
    "(: ok "
    SEAT_OK
    TE_TAIL("; image hatched -- shell up")
    :
    "(: ok "
    SEAT_OK
    TE_TAIL("; egg hatched -- shell up"));
  // the shell returns only on a fatal error
  if (code_of(r) == status_scare) scare_face(r);
  fin(r);
  for (;;) {
    gpio_put(LED_BIT, 1); love_sleep(120);
    gpio_put(LED_BIT, 0); love_sleep(120); } }
