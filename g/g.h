#ifndef _g_h
#define _g_h
#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>
#include <stdarg.h>

#define Width(_) b2w(sizeof(_))
#define g_width Width
#define g_core_of(f) ((struct g*)((intptr_t)(f)&~(sizeof(intptr_t)-1)))
#define g_code_of(f) ((enum g_status)((intptr_t)(f)&(sizeof(intptr_t)-1)))
#define g_ok(f) (g_code_of(f) == g_status_ok)

#define g_putnum(_) (((g_word)(_)<<1)|1)
#define g_getnum(_) ((g_word)(_)>>1)

#define g_nil g_putnum(0)
#define g_inline inline __attribute__((always_inline))
#define g_noinline __attribute__((noinline))
#define g_digits "0123456789abcdefghijklmnopqrstuvwxyz"
#define LEN(_) (sizeof(_)/sizeof(*_))
#define MIN(p,q) ((p)<(q)?(p):(q))
#define MAX(p,q) ((p)>(q)?(p):(q))

#ifndef g_tco
#define g_tco 1
#endif

#if g_tco
#define g_vm(n, ...) struct g *n(struct g *restrict f, union u *Ip, g_word *Hp, g_word *restrict Sp, ##__VA_ARGS__)
#define Ap(g, f, ...) g(f, Ip, Hp, Sp, ##__VA_ARGS__)
#define Continue() Ap(Ip->ap, f)
#define Pack(f) (f->ip = Ip, f->hp = Hp, f->sp = Sp)
#define Unpack(f) (Ip = f->ip, Hp = f->hp, Sp = f->sp)
#else
#define g_vm(n, ...) struct g *n(struct g *restrict f, ##__VA_ARGS__)
#define Ap(g, f, ...) g(f, ##__VA_ARGS__)
#define Continue() f
#define Hp f->hp
#define Sp f->sp
#define Ip f->ip
#define Pack(f) ((void)0)
#define Unpack(f) ((void)0)
#endif

// ok thanks
typedef intptr_t g_word;
union u;
typedef g_vm(g_vm_t);
typedef void *g_malloc_t(struct g*, size_t);
typedef void g_free_t(struct g*, void*);
struct g {
 union u {
  g_vm_t *ap;
  g_word x, typ;
  union u *m; } *ip;
 g_word *hp, *sp;
 struct g_atom {
  g_vm_t *ap;
  g_word typ;
  uintptr_t code;
  struct g_vec {
   g_vm_t *ap;
   uintptr_t typ, type, rank, shape[]; } *nom;
  struct g_atom *l, *r; } *symbols;
 uintptr_t len;
 struct g *pool;
 struct g_r { g_word *x; struct g_r *n; } *root;
 union { uintptr_t t0; g_word *cp; };
 g_malloc_t *malloc;
 g_free_t *free;
 uintptr_t b;
 union {
  intptr_t v0;
  struct {
   struct g_tab {
    g_vm_t *ap;
    intptr_t typ;
    uintptr_t len, cap;
    struct g_kvs {
     intptr_t key, val;
     struct g_kvs *next; } **tab;
   } *dict, *macro; }; };
 g_word edl, edr;
 struct g_in *in;
 struct g_out *out;
 intptr_t end[]; };

struct g_def { char const *n; intptr_t x; };

struct g_in {
 struct g*(*getc)(struct g*, struct g_in*),
         *(*ungetc)(struct g*, int, struct g_in*),
         *(*eof)(struct g*, struct g_in*); };

struct g_out {
 struct g*(*putc)(struct g*, int, struct g_out*),
         *(*flush)(struct g*, struct g_out*); }; // FIXME should take g_out arg


enum g_status {
 g_status_ok  = 0,
 g_status_oom = 1,
 g_status_err = 2,
 g_status_eof = 3,
 g_status_more = 4,   // EOF inside an unfinished form -- defer, retry later
} g_fin(struct g*);

// input editor key events; g_edit takes one of these or, for any value
// > 0, a character code to insert at the cursor.
enum g_edit_ev {
 g_ed_left  = -1,  // move the focus one item left
 g_ed_right = -2,  // move the focus one item right
 g_ed_bsp   = -3,  // delete the item left of the cursor
 g_ed_del   = -4,  // delete the focused item
 g_ed_home  = -5,  // move the focus to the first item of this level
 g_ed_end   = -6,  // move the focus to the last item of this level
 g_ed_up    = -7,  // ascend: close this level into its parent's focus
 g_ed_down  = -8,  // descend: open the focused sublist as the level
};

static g_inline intptr_t g_pop1(struct g*f) { return *f->sp++; }
static g_inline size_t b2w(size_t b) {
 size_t q = b / sizeof(g_word), r = b % sizeof(g_word);
 return q + (r ? 1 : 0); }

g_vm_t g_vm_ret0, g_vm_cur;

uintptr_t g_clock(void); // used by garbage collector

struct g
 *ggetc(struct g*),
 *gungetc(struct g*, int),
 *geof(struct g*),

 *gputc(struct g*, int),
 *gflush(struct g*),

 *gputx(struct g*, intptr_t),
 *gputn(struct g*, intptr_t, uint8_t),
 *gputs(struct g*, char const*);

struct g
 *g_ini_m(g_malloc_t*, g_free_t*),
 *g_eval(struct g*),
 *g_evals(struct g*, const char*),
 *g_read(struct g*, struct g_in*),
 *g_read_edit(struct g*),
 *g_feed(struct g*),
 *g_defs(struct g*, struct g_def const*),
 *g_push(struct g*, uintptr_t, ...),
 *g_strof(struct g*, const char*),
 *g_pop(struct g*, uintptr_t),
 *g_edit(struct g*, int),
 *gxl(struct g*),
 *gxr(struct g*);

g_malloc_t g_libc_malloc;
g_free_t g_libc_free;
static g_inline struct g *g_ini(void) { return g_ini_m(g_libc_malloc, g_libc_free); }
static g_inline struct g *g_evals_(struct g *f, char const *s) {
  return g_pop(g_evals(f, s), 1); }
extern struct g_in *g_stdin;
extern struct g_out *g_stdout, *g_stderr;

#endif
