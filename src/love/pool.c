// src/love/pool.c -- the runtime's one thread pool, one per g: fork-join over C kernels.
//   par_run(g, n, fn, ctx)  fn(ctx, i) for each chunk i of 0..n-1, the caller taking chunks
//                           too; back once all are done
//   par_width(g, n)         the width a run of n chunks takes now, for a kernel whose chunks
//                           cost more split than whole: at 1 it runs whole instead
//   (par-width n)           the same from love, for the laws
// workers run C only: no love code, no heap, no allocation. the caller sits in its nif until
// the join, so the collector cannot run and nothing moves under them. a chunk is a fixed
// piece of the work, never n / width, so the answer is the same at any width.
// the width: min(LOVE_THREADS, cores online, chunks, cores idle). idle is the cores less
// what /proc/loadavg says is runnable now (R of R/T, ours counted), read at most every
// 50 ms; it drops at once and grows only when two reads in a row allow it, so a loaded box
// runs serial. LOVE_THREADS is read each call: 1 is off, N a cap, N! exactly N whatever the
// load (the laws, and the measure's forced widths). where it is unset, the row (threads N)
// in ~/.love/etc/love.l says the same, read on the load's tick: the salt pattern, data only.
// serial where there are no threads (inle, wasm, the BSDs, love0), inside a worker, and in
// a fork's child until the pool is made again there.
#include "love.h"
#if defined(__mooncc__) && !defined(__wasm__)
#define PoolThreads 1
#include <fcntl.h>
#include <pthread.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#else
#define PoolThreads 0
#endif

enum { PoolMax = 16, PoolTick = 50000000 };   // the most workers; ns between two reads of the load

struct pool {
 int pid, ncpu, fd;              // the process it was made in, cores online, /proc/loadavg
 int width, ask0, busy;          // the width the load allows, the last read's ask; a job is out
 uint64_t at;                    // when the load was last read, 0 never
 char salt[16];                  // (threads ..) from ~/.love/etc/love.l as last read, "" none
#if PoolThreads
 int nw;                         // workers up
 pthread_mutex_t mu;
 pthread_cond_t go, done;
 unsigned gen;                   // the job's number: a worker waits for it to move
 int part, left;                 // workers taking part in the job, and still in it
 void (*fn)(void *, intptr_t);
 void *ctx;
 intptr_t n, next;               // the chunks, and the next one unclaimed
 pthread_t th[PoolMax];
 struct pool_w { struct pool *p; int i; } w[PoolMax];
#endif
};

static void pool_serial(intptr_t n, void (*fn)(void *, intptr_t), void *ctx) {
 for (intptr_t i = 0; i < n; i++) fn(ctx, i); }

#if PoolThreads
static uint64_t pool_ns(void) {
 struct timespec t;
 clock_gettime(CLOCK_MONOTONIC, &t);
 return (uint64_t) t.tv_sec * 1000000000u + (uint64_t) t.tv_nsec; }
// the tasks runnable now, the R of loadavg's R/T, or -1
static int pool_runnable(struct pool *p) {
 char b[96];
 if (p->fd < 0 || lseek(p->fd, 0, SEEK_SET) != 0) return -1;
 long k = read(p->fd, b, sizeof b - 1);
 if (k <= 0) return -1;
 b[k] = 0;
 char *s = b;
 for (int f = 0; f < 3; f++) {                 // past the three averages
  while (*s && *s != ' ') s++;
  while (*s == ' ') s++; }
 int r = 0;
 if (*s < '0' || *s > '9') return -1;
 while (*s >= '0' && *s <= '9') r = r * 10 + (*s++ - '0');
 return r; }

// the operand of a (threads ..) row in ~/.love/etc/love.l into p->salt, or "": a form is
// read only where it starts a line, past a comment's ;
static void pool_salt(struct pool *p) {
 char const *h = getenv("HOME");
 char path[256], b[4096];
 p->salt[0] = 0;
 if (!h || strlen(h) > sizeof path - 20) return;
 strcpy(path, h), strcat(path, "/.love/etc/love.l");
 int fd = open(path, O_RDONLY | O_CLOEXEC);
 if (fd < 0) return;
 long k = read(fd, b, sizeof b - 1);
 close(fd);
 if (k <= 0) return;
 b[k] = 0;
 for (char *s = b; *s; ) {
  while (*s == ' ' || *s == '\t') s++;
  if (!strncmp(s, "(threads", 8) && (s[8] == ' ' || s[8] == '\t')) {
   s += 8;
   while (*s == ' ' || *s == '\t') s++;
   unsigned i = 0;
   while (*s && *s != ')' && *s != ' ' && *s != '\n' && i < sizeof p->salt - 1) p->salt[i++] = *s++;
   p->salt[i] = 0; }
  while (*s && *s != '\n') s++;
  if (*s) s++; } }

static void pool_chunks(struct pool *p) {
 for (intptr_t i; (i = __atomic_fetch_add(&p->next, 1, __ATOMIC_RELAXED)) < p->n; ) p->fn(p->ctx, i); }
static void *pool_work(void *a) {
 struct pool_w *w = a;
 struct pool *p = w->p;
 unsigned seen = 0;
 for (;;) {
  pthread_mutex_lock(&p->mu);
  while (p->gen == seen) pthread_cond_wait(&p->go, &p->mu);
  seen = p->gen;
  int in = w->i < p->part;
  pthread_mutex_unlock(&p->mu);
  if (!in) continue;
  pool_chunks(p);
  pthread_mutex_lock(&p->mu);
  if (!--p->left) pthread_cond_signal(&p->done);
  pthread_mutex_unlock(&p->mu); }
 return a; }

// the pool's state as made: in a fork's child too, where no worker came along
static void pool_fresh(struct pool *p) {
 p->pid = getpid(), p->nw = 0, p->busy = 0, p->gen = 0;
 pthread_mutex_init(&p->mu, 0), pthread_cond_init(&p->go, 0), pthread_cond_init(&p->done, 0); }
#endif

#if PoolThreads
// g's pool, made at the first ask; NULL off linux or with no memory
static struct pool *pool_of(struct g *g) {
 struct pool *p = g->pool;
 if (__love_osv != 1) return NULL;             // linux alone: moonlibc's threads are clone's
 if (!p) {
  if (!(p = alloc(NULL, sizeof *p))) return NULL;
  memset(p, 0, sizeof *p);
  long c = sysconf(_SC_NPROCESSORS_ONLN);
  p->ncpu = c < 1 ? 1 : c > PoolMax ? PoolMax : (int) c;
  p->fd = open("/proc/loadavg", O_RDONLY | O_CLOEXEC);
  p->width = 1;
  pool_fresh(p);
  g->pool = p; }
 else if (p->pid != getpid()) pool_fresh(p);  // a fork's child: the workers stayed behind
 return p; }
#endif

intptr_t par_width(struct g *g, intptr_t n) {
#if PoolThreads
 struct pool *p = n > 1 ? pool_of(g) : NULL;
 if (!p || p->busy || p->ncpu < 2) return 1;
 uint64_t t = pool_ns();
 int tick = !p->at || t - p->at >= PoolTick;
 if (tick) pool_salt(p);
 char const *e = getenv("LOVE_THREADS");
 if (!e || !*e) e = p->salt;
 char *x = 0;
 long cap = *e ? strtol(e, &x, 10) : PoolMax;
 if (cap < 2) return 1;
 if (x && *x == '!') return cap < n ? (cap < PoolMax + 1 ? cap : PoolMax + 1) : n;
 if (tick) {
  int r = pool_runnable(p), ask = r < 0 ? 1 : p->ncpu - r + 1;   // the caller's own core is ours
  // drop at once; grow on two reads in a row, to the lesser; the first read stands alone
  p->width = !p->at || ask < p->width ? ask : p->ask0 > p->width ? (ask < p->ask0 ? ask : p->ask0) : p->width;
  p->ask0 = ask, p->at = t; }
 intptr_t w = p->width;
 if (w > cap) w = cap;
 if (w > p->ncpu) w = p->ncpu;
 if (w > n) w = n;
 return w < 1 ? 1 : w;
#else
 (void) g, (void) n;
 return 1;
#endif
}

void par_run(struct g *g, intptr_t n, void (*fn)(void *, intptr_t), void *ctx) {
#if PoolThreads
 intptr_t w = par_width(g, n);
 struct pool *p = w > 1 ? g->pool : NULL;
 if (p && p->nw < w - 1) {                     // workers made as a width first wants them
  sigset_t all, was;                           // ..each with every signal blocked: they are the caller's
  memset(&all, 0xff, sizeof all);
  sigprocmask(SIG_BLOCK, &all, &was);
  while (p->nw < w - 1 && p->nw < PoolMax) {
   p->w[p->nw].p = p, p->w[p->nw].i = p->nw;
   if (pthread_create(p->th + p->nw, 0, pool_work, p->w + p->nw)) break;
   p->nw++; }
  sigprocmask(SIG_SETMASK, &was, 0);
  if (w > p->nw + 1) w = p->nw + 1; }
 if (w < 2) { pool_serial(n, fn, ctx); return; }
 pthread_mutex_lock(&p->mu);
 p->fn = fn, p->ctx = ctx, p->n = n, p->next = 0, p->part = (int) w - 1, p->left = (int) w - 1, p->busy = 1;
 p->gen++;
 pthread_cond_broadcast(&p->go);
 pthread_mutex_unlock(&p->mu);
 pool_chunks(p);
 pthread_mutex_lock(&p->mu);
 while (p->left) pthread_cond_wait(&p->done, &p->mu);
 p->busy = 0;
 pthread_mutex_unlock(&p->mu);
#else
 (void) g;
 pool_serial(n, fn, ctx);
#endif
}

love_noinline static struct g *host_par_width(struct g *g) {
 word nw = g->sp[0];
 g->sp[0] = putcharm(oddp(nw) ? par_width(g, getcharm(nw)) : 1);
 return g; }
static LvmWrap(lvm_par_width, host_par_width)
LvDef("par-width", par_width, 1, NULL);
