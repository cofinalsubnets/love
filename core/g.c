#include "i.h"

enum g_status g_fin(struct g *f) {
 enum g_status s = g_code_of(f);
 if ((f = g_core_of(f))) {
   for (struct g_fz *fz = f->fz; fz; fz->fn(fz->p), fz = fz->next); // run finalizers
   f->free(f, f->pool); }
 return s; }

struct g *g_defn(struct g*f, struct g_def const*defs, uintptr_t n) {
 for (f = g_push(f, 1, g_core_of(f)->dict); n--; 
  f = g_tput(intern(g_strof(g_push(f, 1, defs[n].x), defs[n].n))));
 g_core_of(f)->sp++;
 return f; }

#define S1(i) {{i}, {g_vm_ret0}}
#define S2(i) {{g_vm_cur},{.x=putnum(2)},{i}, {g_vm_ret0}}
#define S3(i) {{g_vm_cur},{.x=putnum(3)},{i}, {g_vm_ret0}}
#define S5(i) {{g_vm_cur},{.x=putnum(5)},{i}, {g_vm_ret0}}
#define bifs(_) \
 _(bif_clock, "clock", S1(g_vm_clock)) _(bif_addr, "vminfo", S1(g_vm_info))\
 _(bif_add, "+", S2(g_vm_add)) _(bif_sub, "-", S2(g_vm_sub)) _(bif_mul, "*", S2(g_vm_mul))\
 _(bif_quot, "/", S2(g_vm_quot)) _(bif_rem, "%", S2(g_vm_rem)) \
 _(bif_lt, "<", S2(g_vm_lt))  _(bif_le, "<=", S2(g_vm_le)) _(bif_eq, "=", S2(g_vm_eq))\
 _(bif_ge, ">=", S2(g_vm_ge))  _(bif_gt, ">", S2(g_vm_gt)) \
 _(bif_bnot, "~", S1(g_vm_bnot)) _(bif_bsl, "<<", S2(g_vm_bsl)) _(bif_bsr, ">>", S2(g_vm_bsr))\
 _(bif_band, "&", S2(g_vm_band)) _(bif_bor, "|", S2(g_vm_bor)) _(bif_bxor, "^", S2(g_vm_bxor))\
 _(bif_cons, "X", S2(g_vm_cons)) _(bif_car, "A", S1(g_vm_car)) _(bif_cdr, "B", S1(g_vm_cdr)) \
 _(bif_cons2, "cons", S2(g_vm_cons)) _(bif_car2, "car", S1(g_vm_car)) _(bif_cdr2, "cdr", S1(g_vm_cdr)) \
 _(bif_ssub, "ssub", S3(g_vm_ssub)) _(bif_scat, "scat", S2(g_vm_scat)) \
 _(bif_fread, "fread", S2(g_vm_fread))\
 _(bif_str, "str", S1(g_vm_str))\
 _(bif_sym, "sym", S1(g_vm_gensym)) _(bif_nom, "nom", S1(g_vm_symnom)) _(bif_thd, "thd", S1(g_vm_thda))\
 _(bif_peek, "peek", S2(g_vm_peek2)) _(bif_poke, "poke", S3(g_vm_poke2)) _(bif_trim, "trim", S1(g_vm_trim))\
 _(bif_seek, "seek", S2(g_vm_seek)) _(bif_len, "len", S1(g_vm_len)) _(bif_get, "get", S3(g_vm_get))\
 _(bif_put, "put", S3(g_vm_put)) _(bif_tnew, "new", S1(g_vm_tnew)) _(bif_tabkeys, "tkeys", S1(g_vm_tkeys))\
 _(bif_bufnew, "bufnew", S1(g_vm_bufnew)) _(bif_bcopy, "bcopy", S5(g_vm_bcopy))\
 _(bif_tabdel, "tdel", S3(g_vm_tdel)) _(bif_twop, "twop", S1(g_vm_twop)) _(bif_strp, "strp", S1(g_vm_strp))\
 _(bif_flo, "flo", S1(g_vm_flo)) _(bif_flop, "flop", S1(g_vm_flop))\
 _(bif_sin, "sin", S1(g_vm_sin)) _(bif_cos, "cos", S1(g_vm_cos)) _(bif_tan, "tan", S1(g_vm_tan)) _(bif_atan, "atan", S1(g_vm_atan))\
 _(bif_sqrt, "sqrt", S1(g_vm_sqrt)) _(bif_exp, "exp", S1(g_vm_exp)) _(bif_log, "log", S1(g_vm_log))\
 _(bif_atan2, "atan2", S2(g_vm_atan2)) _(bif_pow, "pow", S2(g_vm_pow))\
 _(bif_arr, "arr", S2(g_vm_arr)) _(bif_arrl, "arrl", S3(g_vm_arrl))\
 _(bif_arank, "arank", S1(g_vm_arank))\
 _(bif_alen, "alen", S1(g_vm_alen)) _(bif_ashape, "ashape", S1(g_vm_ashape))\
 _(bif_atype, "atype", S1(g_vm_atype))\
 _(bif_asum, "asum", S1(g_vm_asum)) _(bif_aprod, "aprod", S1(g_vm_aprod))\
 _(bif_amax, "amax", S1(g_vm_amax)) _(bif_amin, "amin", S1(g_vm_amin))\
 _(bif_aall, "aall", S1(g_vm_aall)) _(bif_aany, "aany", S1(g_vm_aany))\
 _(bif_symp, "symp", S1(g_vm_symp)) _(bif_tblp, "tblp", S1(g_vm_tblp)) _(bif_nump, "nump", S1(g_vm_nump))\
 _(bif_nilp, "nilp", S1(g_vm_nilp)) _(bif_ev, "ev", S1(g_vm_eval))\
 _(bif_callk, "call_cc", S1(g_vm_callk)) _(bif_yield, "yield", S1(g_vm_yield_bif)) \
 _(bif_spawn, "spawn", S2(g_vm_spawn)) _(bif_wait, "wait", S1(g_vm_wait)) \
 _(bif_sleep, "sleep", S1(g_vm_sleep)) _(bif_donep, "done?", S1(g_vm_donep)) \
 _(bif_kill, "kill", S1(g_vm_kill)) \
 _(bif_key, "key?", S1(g_vm_key)) \
 _(bif_fputn, "fputn", S3(g_vm_fputn))\
 _(bif_fputx, "fputx", S2(g_vm_fputx))\
 _(bif_fgetc, "fgetc", S1(g_vm_fgetc)) _(bif_fungetc, "fungetc", S2(g_vm_fungetc)) _(bif_feof, "feof", S1(g_vm_feof))\
 _(bif_fputc, "fputc", S2(g_vm_fputc)) _(bif_fputs, "fputs", S2(g_vm_fputs))  _(bif_fflush, "fflush", S1(g_vm_fflush))
#define built_in_function(n, _, d) static union u const n[] = d;
bifs(built_in_function);
#define insts(_) _(g_vm_unc) _(g_vm_freev) _(g_vm_ret) _(g_vm_ap) _(g_vm_tap) _(g_vm_apn) _(g_vm_tapn)\
  _(g_vm_jump) _(g_vm_cond) _(g_vm_arg) _(g_vm_quote) _(g_vm_defglob) _(g_vm_lazyb)
#define biff(b, n, _) {n, (intptr_t) b},
#define i_entry(i) {#i, (intptr_t) i},

static g_vm(_g_vm_yield_c) { return Pack(f), f; }
static union u yield_c[] = { {_g_vm_yield_c} };
static struct g_def const def1[] = { bifs(biff) insts(i_entry)};
static struct g *g_trap_default(struct g *f) { return f; }

static struct g *g_ini_0(struct g*f, uintptr_t len0, void *(*ma)(struct g*, size_t), void (*fr)(struct g*, void*)) {
 memset(f, 0, sizeof(struct g));
 f->len = len0, f->pool = (void*) f, f->malloc = ma, f->free = fr;
 f->hp = f->end, f->sp = (word*) f + len0, f->ip = yield_c, f->t0 = g_clock();
 f->trap = g_trap_default;
 uintptr_t const req = 2 * (Width(struct g_tab) + 1) + 6; // two tables plus main task thread
 if (g_ok(f = g_have(f, req))) {
  struct g_tab *d = bump(f, req),      *m = d + 1;
  struct g_kvs **b1 = (void*) (m + 1), **b2 = b1 + 1;
  union u *M = (void*) (b2 + 1);
  *b1 = *b2 = 0;
  f->dict = ini_tab(d, 0, 1, b1);
  f->macro = ini_tab(m, 0, 1, b2);
  M[0].m = M;
  M[1].x = nil;   // sentinel; replaced on first yield
  M[2].x = nil;   // main pid
  M[3].x = nil;   // wake_at: nil means "always runnable"
  M[4].x = putnum(-1);  // wait_fd: -1 = not waiting on I/O (slot value -1, non-zero)
  f->tasks = tagthd(M, 5);
  struct g_def def0[] = {
   {"globals", (word) d, },
   {"in", (word) &g_stdin},
   {"out", (word) &g_stdout},
   {"err", (word) &g_stderr}, };
  f = g_defn(f, def0, LEN(def0));
  f = g_push(f, 3, nil, m, d);
  f = g_tput(f);
  f = g_pop(f, 1);
  f = g_defn(f, def1, LEN(def1)); }
 return f; }

struct g *g_ini_m(void *(*ma)(struct g*, size_t), void (*fr)(struct g*, void*)) {
 uintptr_t const len0 = 1 << 10;
 struct g *f = ma(NULL, 2 * len0 * sizeof(word));
 return f == NULL ? encode(f, g_status_oom) : g_ini_0(f, len0, ma, fr); }

static void *g_no_malloc(struct g*f, uintptr_t n) { return NULL; }
static void g_no_free(struct g*f, void *p) { }
struct g *g_ini_s(void *mem, uintptr_t nbytes) {
 uintptr_t len0 = nbytes / (2 * sizeof(word));
 return len0 <= Width(struct g) ? encode(mem, g_status_oom) :
   g_ini_0(mem, len0, g_no_malloc, g_no_free); }

static void *g_libc_malloc(struct g*f, size_t n) { return malloc(n); }
static void g_libc_free(struct g*f, void *x) { free(x); }
struct g *g_ini(void) { return g_ini_m(g_libc_malloc, g_libc_free); }
