// src/love/pool.c -- the runtime's one thread pool, one per g: fork-join over C kernels.
//   par_run(g, n, fn, ctx)  fn(ctx, i) for each chunk i of 0..n-1, the caller taking chunks
//                           too; back once all are done
//   par_width(g, n)         the width a run of n chunks takes now, for a kernel whose chunks
//                           cost more split than whole: at 1 it runs whole instead
//   (par-width n)           the same from love, for the laws, and (par-cpus m) the rounding
//                           (module pool)
// workers run C only: no love code, no heap, no allocation. the caller sits in its nif until
// the join, so the collector cannot run and nothing moves under them. a chunk is a fixed
// piece of the work, never n / width, so the answer is the same at any width.
// the width: min(LOVE_THREADS, physical cores, chunks, cpus spare). spare is what the box
// left idle over the window since the last read (/proc/stat's idle and iowait), plus what
// we took ourselves, in whole cpus; and 1 whenever /proc/pressure/cpu says tasks waited for a
// cpu over more than PoolPsi of the window. read at most every 50 ms through held fds; it
// drops at once and grows only when two reads in a row allow it, so a loaded box runs serial. LOVE_THREADS is read each call: 1 is off, N a cap, N! exactly N whatever the
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
#include <sys/resource.h>
#include <time.h>
#include <unistd.h>
#else
#define PoolThreads 0
#endif

// the most workers; ns between two reads of the load; the margin a spare's whole cpus are rounded
// with (thousandths: 1.98 spare is two, not one); the share of a window (in thousandths)
// tasks may wait for a cpu before we take none: an idle box shows well under 1%, and past
// 5% someone already queues, so a thread of ours would lengthen a queue rather than fill a gap
enum { PoolMax = 16, PoolTick = 50000000, PoolPsi = 50, PoolMargin = 250 };

struct pool {
 int pid, ncpu, ncore, fd, fp;   // the process it was made in, cpus online, physical cores,
                                 // /proc/stat, /proc/pressure/cpu (-1 where the kernel has none)
 uint64_t idle0, tot0, psi0, self0;   // at the last read: idle and all jiffies, stall us, our cpu us
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

// the whole cpus a spare of m thousandths allows: rounded down past a margin, so a box that left
// two cores idle all but a hair reads as two
static int pool_cpus(uint64_t m) { return (int) ((m + PoolMargin) / 1000); }

#if PoolThreads
static uint64_t pool_ns(void) {
 struct timespec t;
 clock_gettime(CLOCK_MONOTONIC, &t);
 return (uint64_t) t.tv_sec * 1000000000u + (uint64_t) t.tv_nsec; }
// the first unsigned number after `at` in fd's text from its start, or 0 with *ok cleared
static uint64_t pool_num(int fd, char const *at, int skip, int *ok) {
 char b[256];
 if (fd < 0 || lseek(fd, 0, SEEK_SET) != 0) return *ok = 0, 0;
 long k = read(fd, b, sizeof b - 1);
 if (k <= 0) return *ok = 0, 0;
 b[k] = 0;
 char *s = strstr(b, at);
 if (!s) return *ok = 0, 0;
 s += strlen(at);
 uint64_t v = 0;
 for (int f = 0; ; f++) {                      // past `skip` numbers to the one wanted
  while (*s == ' ') s++;
  if (*s < '0' || *s > '9') return *ok = 0, 0;
  for (v = 0; *s >= '0' && *s <= '9'; s++) v = v * 10 + (uint64_t) (*s - '0');
  if (f == skip) return v; } }
// /proc/stat's first line: the idle and iowait jiffies, and all of them through steal
static int pool_stat(int fd, uint64_t *idle, uint64_t *tot) {
 char b[256];
 if (fd < 0 || lseek(fd, 0, SEEK_SET) != 0) return 0;
 long k = read(fd, b, sizeof b - 1);
 if (k <= 4 || strncmp(b, "cpu ", 4)) return 0;
 b[k] = 0;
 char *s = b + 4;
 uint64_t v[8] = {0};
 for (int f = 0; f < 8; f++) {
  while (*s == ' ') s++;
  if (*s < '0' || *s > '9') return 0;
  while (*s >= '0' && *s <= '9') v[f] = v[f] * 10 + (uint64_t) (*s++ - '0'); }
 *idle = v[3] + v[4], *tot = 0;
 for (int f = 0; f < 8; f++) *tot += v[f];
 return 1; }
static uint64_t pool_self(void) {
 struct rusage u;
 if (getrusage(RUSAGE_SELF, &u)) return 0;
 return (uint64_t) (u.ru_utime.tv_sec + u.ru_stime.tv_sec) * 1000000u + (uint64_t) (u.ru_utime.tv_usec + u.ru_stime.tv_usec); }
// the whole cpus the box can spare now, from the window since the last read; 1 at the first
static int pool_ask(struct pool *p, uint64_t t) {
 uint64_t idle, tot, self = pool_self(), psi;
 int ok = 1, ask = 1;
 if (!pool_stat(p->fd, &idle, &tot)) return 1;
 psi = pool_num(p->fp, "total=", 0, &ok);   // the first line is "some": its total, us of stall
 if (p->tot0 && tot > p->tot0 && t > p->at) {
  uint64_t win = (t - p->at) / 1000,           // us
           spare = (idle - p->idle0) * 1000 * (uint64_t) p->ncpu / (tot - p->tot0)   // thousandths of a cpu
                   + (self - p->self0) * 1000 / (win ? win : 1);
  ask = pool_cpus(spare);
  if (ok && p->fp >= 0 && p->psi0 && (psi - p->psi0) * 1000 > PoolPsi * win) ask = 1; }
 p->idle0 = idle, p->tot0 = tot, p->self0 = self, p->psi0 = ok ? psi : 0;
 return ask < 1 ? 1 : ask; }
// the physical cores: the cpus online over the cpus sharing cpu0's core
static int pool_cores(int ncpu) {
 char b[128];
 int fd = open("/sys/devices/system/cpu/cpu0/topology/core_cpus_list", O_RDONLY | O_CLOEXEC);
 if (fd < 0) fd = open("/sys/devices/system/cpu/cpu0/topology/thread_siblings_list", O_RDONLY | O_CLOEXEC);
 if (fd < 0) return ncpu;
 long k = read(fd, b, sizeof b - 1);
 close(fd);
 if (k <= 0) return ncpu;
 b[k] = 0;
 int n = 0;
 for (char *s = b; *s >= '0' && *s <= '9'; ) {   // "0-1" or "0,8": count the cpus it names
  long a = strtol(s, &s, 10), z = a;
  if (*s == '-') z = strtol(s + 1, &s, 10);
  n += (int) (z - a + 1);
  if (*s != ',') break;
  s++; }
 return n > 0 && ncpu / n > 0 ? ncpu / n : ncpu; }

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
  p->ncpu = c < 1 ? 1 : (int) c;
  p->ncore = pool_cores(p->ncpu);
  p->fd = open("/proc/stat", O_RDONLY | O_CLOEXEC);
  p->fp = open("/proc/pressure/cpu", O_RDONLY | O_CLOEXEC);
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
  int ask = pool_ask(p, t);
  // drop at once; grow on two reads in a row, to the lesser; the first read stands alone
  p->width = !p->at || ask < p->width ? ask : p->ask0 > p->width ? (ask < p->ask0 ? ask : p->ask0) : p->width;
  p->ask0 = ask, p->at = t; }
 intptr_t w = p->width;
 if (w > cap) w = cap;
 if (w > p->ncore) w = p->ncore;
 if (w > PoolMax + 1) w = PoolMax + 1;
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
// (par-cpus m) the whole cpus a spare of m thousandths allows, the rounding the width takes: the laws'
love_noinline static struct g *host_par_cpus(struct g *g) {
 word mw = g->sp[0];
 g->sp[0] = putcharm(oddp(mw) && getcharm(mw) >= 0 ? pool_cpus((uint64_t) getcharm(mw)) : 0);
 return g; }
static LvmWrap(lvm_par_cpus, host_par_cpus)
LvDef("par-cpus", par_cpus, 1, "pool");
