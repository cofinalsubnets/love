// task.c -- the tasks and their scheduler: twirl, wait, done?, scoop, hush, sleep, and the
// switch they all yield through. a node: [next, ip, pid, wake_at, wait_fd, events, help, stdio, stack..]
#include "love.h"

// (heard x) -> the installed help, hook 5 (x ignored)
op11(lvm_heard, (intptr_t) *task_help(g))
// (worn x) -> the stdio this task wears, hook 6, () for the console (x ignored)
op11(lvm_worn, (intptr_t) *task_io(g))
// (myself x) -> the running task's pid, the zero point for the root (x ignored). an escape
// checks it before it jumps: a child inherits its parent's help, continuation and all
op11(lvm_myself, (intptr_t) g->tasks[2].x)

// lvm_yield_sw_mono can't call wait_fds directly with a stack record
static love_noinline void wait_one(int fd, int events, uintptr_t ms) {
  struct wait_fd w = { .fd = fd, .events = (short) events };
  wait_fds(&w, 1, ms); }

// catch and a task's exit yield without advancing, so with nothing to wake they would spin
static love_inline int stays(union u const *ip) { return ip->ap == lvm_wait || ip->ap == lvm_task_exit; }

// monotask fast path
static lvm(lvm_yield_sw_mono) { uintptr_t my_wake = g->next_wake_at;
 int my_wait_fd = g->next_wait_fd, my_events = g->next_wait_events;
 if (!my_wake && my_wait_fd < 0 && stays(Ip)) love_musttail return Ap(lvm_deadlock, g);   // the last task, ending or waiting on none
 g->next_wake_at = 0;
 g->next_wait_fd = -1;
 g->next_wait_events = wait_in;
 g->yield_ctr = 0;
 if (my_wake) for (uintptr_t now; my_wake > (now = love_clock());)
  my_wait_fd >= 0 ? wait_one(my_wait_fd, my_events, my_wake - now) : love_sleep(my_wake - now);
 else if (my_wait_fd >= 0)
  while (!ready(my_wait_fd, my_events)) wait_one(my_wait_fd, my_events, 0);
 love_musttail return Continue(); }

// the parked ring by pid, and its predecessor for an unsplice
static love_inline union u *parked_find(struct g *g, intptr_t pid, union u **prevp) {
 union u *head = g->parked;
 if (!head) return NULL;
 union u *prev = head;
 do { union u *n = prev->m;
      if (getcharm(n[2].x) == pid) return *prevp = prev, n;
      prev = n; } while (prev != head);
 return NULL; }

// called with g packed: gen_wb reads g->hp, and the live Hp runs ahead of the last Pack
static love_inline void parked_drop(struct g *g, union u *prev, union u *n) {
 if (prev == n) return (void) (g->parked = NULL);   // it was the whole ring
 prev->m = n->m;
 gen_wb(g, (word) prev, (word) prev->m);
 if (g->parked == n) g->parked = prev; }

// onto the run ring behind tail, answering the new tail so a many-task wake walks once.
// wait_fd cleared: nothing on the run ring is fd-parked
static love_inline union u *run_splice_at(struct g *g, union u *tail, union u *n) {
 n[0].m = g->tasks;
 n[4].x = putcharm(-1);
 gen_wb(g, (word) n, (word) n[0].m);
 tail->m = n;
 gen_wb(g, (word) tail, (word) tail->m);
 return n; }

// a held task (pause) keeps its deadline negated: never due, and back whole at resume
static love_inline int held(union u const *n) { return getcharm(n[3].x) < 0; }

// the head's saved ip is stale, so me_live answers for it; a pid with no node is gone
static love_inline int task_live(struct g *g, union u *head, intptr_t pid, int me_live) {
 if (getcharm(head[2].x) == pid) return me_live;
 for (union u *n = head->m; n != head; n = n->m)
  if (getcharm(n[2].x) == pid) return n[1].m->ap != lvm_task_exit && !held(n);
 union u *prev;   // the parked ring too: a task blocked on an fd is live
 union u *p = parked_find(g, pid, &prev);
 return p ? p[1].m->ap != lvm_task_exit && !held(p) : 0; }

// readiness the wait already answered: 1, 0, -1 unknown. by (fd, events), as two tasks may
// park on one fd both ways; any revents is ready, a hangup too. the cursor is only speed
static love_inline int polled_ready(struct wait_fd const *fds, int nfds, int *cur, int fd, int ev) {
 for (int i = 0; i < nfds; i++) {
  int j = *cur + i < nfds ? *cur + i : *cur + i - nfds;
  if (fds[j].fd == fd && fds[j].events == (short) ev)
   return *cur = j + 1 < nfds ? j + 1 : 0, fds[j].revents != 0; }
 return -1; }

// the first runnable peer on the run ring. without the catch clause a catcher is always
// runnable and the wait is never reached; the wait_fd arm is a floor, not a path
static union u *find_runnable(struct g *g, union u *head, uintptr_t now, int me_live) {
 for (union u *n = head->m; n != head; n = n->m)
  if (n[1].m->ap != lvm_task_exit && (uintptr_t) getcharm(n[3].x) <= now) {
   if (n[1].m->ap == lvm_wait && task_live(g, head, getcharm(n[8].x), me_live)) continue;
   int wf = (int) getcharm(n[4].x);
   if (wf < 0 || wait_buffered(g, n[1].m->ap, n[8].x, wf)
       || ready(wf, (int) getcharm(n[5].x))) return n; }
 return NULL; }

// deadline come, port holding bytes, or fd ready; with ask clear, only syscall-free terms
static love_inline int parked_ready(struct g *g, union u *n, uintptr_t now,
                                  struct wait_fd const *fds, int nfds, int *cur, int ask) {
 if (n[1].m->ap == lvm_task_exit || (uintptr_t) getcharm(n[3].x) > now) return 0;
 int wf = (int) getcharm(n[4].x), ev = (int) getcharm(n[5].x);
 if (wf < 0 || wait_buffered(g, n[1].m->ap, n[8].x, wf)) return 1;
 int pr = polled_ready(fds, nfds, cur, wf, ev);
 return pr < 0 ? (ask && ready(wf, ev)) : pr; }

// every parked task that can run moves to the run ring; how many. walked by count, as a
// waker is unspliced under the cursor, the head too. g packed
static love_noinline int wake_parked(struct g *g, uintptr_t now,
                                   struct wait_fd const *fds, int nfds, int ask) {
 if (!g->parked) return 0;
 int n = 1, cur = 0, woke = 0;
 for (union u *q = g->parked->m; q != g->parked; q = q->m) n++;
 union u *prev = g->parked, *tail = NULL;
 for (int i = 0; i < n && g->parked; i++) {
  union u *t = prev->m;
  if (!parked_ready(g, t, now, fds, nfds, &cur, ask)) { prev = t; continue; }
  if (!tail) for (tail = g->tasks; tail->m != g->tasks; tail = tail->m);   // once, on the first wake
  parked_drop(g, prev, t);
  tail = run_splice_at(g, tail, t);
  woke++; }
 return woke; }

// the fairness sweep of every parked fd, the block in the [hp, sp) gap (g packed); here
// all-zero means none ready
static love_noinline int poll_parked(struct g *g, uintptr_t now) {
 int n = 1;
 for (union u *q = g->parked->m; q != g->parked; q = q->m) n++;
 struct wait_fd *fds = (struct wait_fd*) g->hp;
 // no gap for the block: ask one by one, as a skipped sweep leaves a ready peer parked
 if (avail(g) < b2w((uintptr_t) n * sizeof *fds)) return wake_parked(g, now, NULL, 0, 1);
 int k = 0;
 union u *q = g->parked;
 do { int wf = (int) getcharm(q[4].x);
      if (wf >= 0) fds[k].fd = wf, fds[k].revents = 0, fds[k++].events = (short) getcharm(q[5].x);
      q = q->m; } while (q != g->parked);
 ready_fds(fds, k);
 return wake_parked(g, now, fds, k, 0); }

// the fd block is counted, never a constant, and rides the heap gap (g packed). both rings
// walk: the run ring holds the sleepers, the parked ring the fds
static love_noinline union u *yield_sw_wait(struct g *g, uintptr_t my_wake, int my_wait_fd, int my_events, int me_live, int *stuck) {
 // syscall-free wakes first: a port holding bytes over a quiet fd would wait forever
 // (test/host/parked.l, law 2)
 if (wake_parked(g, love_clock(), NULL, 0, 0)) {
  union u *n = find_runnable(g, g->tasks, love_clock(), me_live);
  if (n) return n; }
 uintptr_t min_wake = my_wake;
 int nfds = my_wait_fd >= 0;
 for (union u *n = g->tasks->m; n != g->tasks; n = n->m)
  if (n[1].m->ap != lvm_task_exit && !held(n)) {
   uintptr_t wa = (uintptr_t) getcharm(n[3].x);
   if (wa && (!min_wake || wa < min_wake)) min_wake = wa; }
 if (g->parked) {
  union u *q = g->parked;
  do { uintptr_t wa = (uintptr_t) getcharm(q[3].x);
       if (!held(q) && wa && (!min_wake || wa < min_wake)) min_wake = wa;
       if (!held(q) && getcharm(q[4].x) >= 0) nfds++;
       q = q->m; } while (q != g->parked); }
 if (!min_wake && !nfds) return *stuck = 1, NULL;   // no clock and no fd: nothing can wake
 uintptr_t now = love_clock(), ticks = min_wake ? min_wake - now : 0;
 // the filled block, NULL unless an entry came back nonzero: a frontend may fill nothing
 struct wait_fd const *pol = NULL;
 int npol = 0;
 if (!min_wake || min_wake > now) {
  struct wait_fd *fds = (struct wait_fd*) g->hp;
  // no gap for the block: wait on the clock alone, never on a short set
  if (avail(g) < b2w((uintptr_t) nfds * sizeof *fds)) wait_fds(NULL, 0, ticks ? ticks : 1);
  else {
   int k = 0;
   // revents zeroed here alone: the block is raw heap gap
   if (my_wait_fd >= 0)
    fds[k].fd = my_wait_fd, fds[k].revents = 0, fds[k++].events = (short) my_events;
   if (g->parked) {
    union u *q = g->parked;
    do { int wf = (int) getcharm(q[4].x);
         if (wf >= 0 && !held(q))
          fds[k].fd = wf, fds[k].revents = 0, fds[k++].events = (short) getcharm(q[5].x);
         q = q->m; } while (q != g->parked); }
   wait_fds(fds, k, ticks);
   for (int i = 0; i < k; i++) if (fds[i].revents) { pol = fds, npol = k; break; } }
  now = love_clock(); }
 if (my_wait_fd >= 0) {
  int cur = 0, pr = polled_ready(pol, npol, &cur, my_wait_fd, my_events);
  if (pr < 0 ? ready(my_wait_fd, my_events) : pr) return NULL; }
 wake_parked(g, now, pol, npol, 1);   // the wait answered the whole parked ring: collect it
 return find_runnable(g, g->tasks, now, me_live); }

lvm(lvm_yield_sw) {
 // mono needs both rings empty: it waits on its own fd only
 if (g->tasks->m == g->tasks && !g->parked) love_musttail return Ap(lvm_yield_sw_mono, g);
 // its node cannot say so yet: the exit's snapshot is written at the foot of this op
 int me_live = Ip->ap != lvm_task_exit;
 uintptr_t my_wake = g->next_wake_at;
 int my_wait_fd = g->next_wait_fd, my_events = g->next_wait_events;
 // a fairness yield sweeps the parked ring every sweep_interval, even with a runnable peer,
 // or compute tasks starve it. catch and exit never take it: Continue() would spin on them
 int fair = !my_wake && my_wait_fd < 0 && Ip->ap != lvm_wait && Ip->ap != lvm_task_exit;
 g->ticks += (uintptr_t) fair;   // one per 64 calls and jumps, the clock-free cost (gauge [16])
 // the clock rides the same tick (on wasm a read is a host trip)
 uintptr_t now = g->clock_at;
 if (!fair || ++g->sweep_ctr >= sweep_interval) {
  now = g->clock_at = love_clock();
  if (fair && (g->sweep_ctr = 0, g->parked)) {
   Pack(g);                    // the fd block goes in the [hp, sp) gap
   poll_parked(g, now);
   Unpack(g); } }
 union u *next = find_runnable(g, g->tasks, now, me_live);
 if (!next) {
  // a fairness yield keeps running; a blocked or dead task waits for a peer, so the dead
  // one is left a collectable zombie
  if (fair) { g->yield_ctr = 0; love_musttail return Continue(); }
  int stuck = 0;
  Pack(g);                     // the fd block goes in the [hp, sp) gap
  next = yield_sw_wait(g, my_wake, my_wait_fd, my_events, me_live, &stuck);
  Unpack(g);
  if (!next && stuck && stays(Ip)) love_musttail return Ap(lvm_deadlock, g);
  if (!next) {
   g->next_wake_at = 0;
   g->next_wait_fd = -1;
   g->next_wait_events = wait_in;
   if (g->yield_ctr >= yield_interval) g->yield_ctr = 0;
   love_musttail return Continue(); } }
 word my_height = topof(g) - Sp;
 union u *next_stack = next + 8,
       *end = (union u*) ttag(g, next_stack);
 uintptr_t restore_h = end - next_stack,
           need = my_height + restore_h + 9;
 if (room(Hp, Sp) < need) {
  Pack(g);
  if (!ok(g = please(push(g, 1, next), need))) love_musttail return Ap(_lvm_ghelp, g);
  next = cell(pop1(g));
  Unpack(g);
  next_stack = next + 8; }   // recompute: next was forwarded by gc
 g->next_wake_at = 0;
 g->next_wait_fd = -1;
 g->next_wait_events = wait_in;
 union u *prev = next;
 while (prev->m != g->tasks) prev = prev->m;
 union u *N = (union u*) Hp;
 Hp += need - restore_h;
 // a task yielding for an fd leaves the run ring for the parked one, back via wake_parked
 int parking = my_wait_fd >= 0;
 N[0].m = parking ? (g->parked ? g->parked->m : N) : g->tasks->m;
 N[1].m = Ip;
 N[2].x = g->tasks[2].x;
 N[3].x = putcharm((intptr_t) my_wake);
 N[4].x = putcharm(my_wait_fd);
 N[5].x = putcharm(my_events);
 N[6].x = g->tasks[6].x;          // help
 N[7].x = g->tasks[7].x;          // stdio
 memcpy(N + 8, Sp, my_height * sizeof(word));
 tagthread(N, 8 + my_height);
 prev->m = parking ? g->tasks->m : N;
 // Pack first: against a stale g->hp the fresh node reads old and the barrier drops it
 Pack(g);
 gen_wb(g, (word) prev, (word) prev->m);
 if (parking) {
  // N already links in: only the ring's own link is an old->young edge
  if (g->parked) { g->parked->m = N; gen_wb(g, (word) g->parked, (word) g->parked->m); }
  else g->parked = N; }
 g->yield_ctr = 0;
 g->tasks = next;
 Sp = memmove(topof(g) - restore_h, next_stack, restore_h * sizeof(word));
 Ip = next[1].m;
 love_musttail return Continue(); }

lvm(lvm_yield_nif) { Ip++; love_musttail return Ap(lvm_yield_sw, g); }
lvm(lvm_task_exit) { love_musttail return Ap(lvm_yield_sw, g); }

// whether a task other than the running one wears port x
static bool wears(word l, word x) {
  for (int i = 0; i < 3 && chainp(l); i++, l = B(l)) if (A(l) == x) return true;
  return false; }
static bool worn_elsewhere(struct g *g, word x) {
  union u *me = g->tasks, *h = g->parked;
  for (union u *n = me[0].m; n && n != me; n = n[0].m) if (wears(n[7].x, x)) return true;
  if (h) { union u *n = h; do { if (wears(n[7].x, x)) return true; n = n[0].m; } while (n != h); }
  return false; }
// (quit code): _exit at task size (inle). its worn fds close, so a pipe's reader sees EOF,
// save one another task still wears; the task lands dormant with code as its retval
static union u const quit_body[] = { {lvm_task_exit} };
lvm(lvm_task_quit) {
  word l = *task_io(g);
  for (int i = 0; i < 3 && chainp(l); i++, l = B(l)) {
    word x = A(l);
    if (!iop(x) || worn_elsewhere(g, x)) continue;
    struct fio *f = (struct fio*) x;
    intptr_t fd = io_fd(&f->io);
    if (fd > 2) love_fd_close((int) fd), f->fd = putcharm(-1); }
  g->next_wake_at = 0;
  g->next_wait_fd = -1;
  word code = (Sp[0] & 1) ? Sp[0] : putcharm(0);
  Sp = (word*) g + g->len - 1;
  Sp[0] = code;
  Ip = (union u*) quit_body;
  love_musttail return Ap(lvm_task_exit, g); }
static union u const spawn_body[] = { {lvm_ap}, {.ap = lvm_task_exit} };
lvm(lvm_twirl) {
 Have(11);
 union u *N = (union u*) Hp;
 Hp += 11;
 word fn = Sp[0], x = Sp[1];
 uintptr_t pid = ++g->next_serial;   // from the mint stream
 N[0].m = g->tasks->m;
 N[1].m = (union u*) spawn_body;
 N[2].x = Sp[1] = putcharm(pid);
 N[3].x = zero;         // always runnable
 N[4].x = putcharm(-1);  // no fd
 N[5].x = putcharm(wait_in);
 N[6].x = g->tasks[6].x;   // the parent's help
 N[7].x = g->tasks[7].x;   // and stdio
 N[8].x = x;
 N[9].x = fn;
 g->tasks->m = tagthread(N, 10);
 Pack(g);   // young reads g->hp
 gen_wb(g, (word) g->tasks, (word) g->tasks->m);
 love_musttail return Nextp(1, 1); }

lvm(lvm_wait) {
 word pid_arg = Sp[0], ret = zero;
 intptr_t target = getcharm(pid_arg);
 for (union u *node = g->tasks->m; node != g->tasks; node = node->m) {
  if (getcharm(node[2].x) != target) continue;
  if (node[1].m->ap == lvm_task_exit) {
   ret = node[8].x;                    // dormant: the stack is [retval]
   union u *prev = node;
   while (prev->m != node) prev = prev->m;
   prev->m = node->m;
   Pack(g);   // young reads g->hp
   gen_wb(g, (word) prev, (word) prev->m);
   break; }
  if (held(node)) break;   // held: the catcher hears now, and the zero point
   // still running: yield without advancing Ip, Sp[0] the peer; a stale fd would gate the park
   g->next_wake_at = 0;
   g->next_wait_fd = -1;
  love_musttail return Ap(lvm_yield_sw, g); }
 // a task blocked on an fd is live too
 { union u *prev, *p = parked_find(g, target, &prev);
   if (p && !held(p)) { g->next_wake_at = 0; g->next_wait_fd = -1; love_musttail return Ap(lvm_yield_sw, g); } }
 love_musttail return Answer(ret); }

lvm(lvm_donep) {
 word pid_arg = Sp[0], result = putcharm(1);
 intptr_t target = getcharm(pid_arg);
 for (union u *node = g->tasks->m; node != g->tasks; node = node->m)
  if (getcharm(node[2].x) == target) {
   if (node[1].m->ap != lvm_task_exit) result = zero;
   Sp[0] = result, Ip += 1;
   love_musttail return Continue(); }
 // an unfound pid reads landed, so the parked ring is asked too
 { union u *prev;
   if (parked_find(g, target, &prev)) result = zero; }
 Sp[0] = result;
 Ip += 1;
 love_musttail return Continue(); }

// (scoop _) -> (pid . retval) of one finished task, or (); a retval may be (), so two? tests.
// the run ring only: parked is unfinished
lvm(lvm_scoop) {
 Have(Width(struct chain));
 for (union u *prev = g->tasks, *node = prev->m; node != g->tasks; prev = node, node = node->m) {
  if (node[1].m->ap != lvm_task_exit) continue;
  word pid = node[2].x, ret = node[8].x;
  struct chain *p = (struct chain*) Hp;
  Hp += Width(struct chain);
  ini_chain(p, pid, ret);
  prev->m = node->m;
  Pack(g);   // young reads g->hp
  gen_wb(g, (word) prev, (word) prev->m);
  Sp[0] = (word) p, Ip += 1;
  love_musttail return Continue(); }
 Sp[0] = ZeroPoint, Ip += 1;
 love_musttail return Continue(); }

lvm(lvm_hush) {
 word pid_arg = Sp[0], result = zero;
 intptr_t target = getcharm(pid_arg);
 union u *prev = g->tasks;
 for (union u *node = prev->m; node != g->tasks; prev = node, node = node->m)
  if (getcharm(node[2].x) == target) {
   prev->m = node->m;
   Pack(g);   // young reads g->hp
   gen_wb(g, (word) prev, (word) prev->m);
   Sp[0] = putcharm(1), Ip += 1;
   love_musttail return Continue(); }
 // the parked ring too: a task blocked on a quiet fd is the one most wanted stopped
 { union u *pp, *p = parked_find(g, target, &pp);
   if (p) { Pack(g); parked_drop(g, pp, p); result = putcharm(1); } }
 Sp[0] = result;
 Ip += 1;
 love_musttail return Continue(); }

// (pause pid): held on its ring, off the clock, its catcher answered at once; never the
// running task. 1 | (). (resume pid) restores the deadline
static union u *task_node(struct g *g, intptr_t pid) {
 for (union u *n = g->tasks->m; n != g->tasks; n = n->m)
  if (getcharm(n[2].x) == pid) return n;
 union u *prev;
 return parked_find(g, pid, &prev); }

static lvm(lvm_pause) {
 union u *n = charmp(Sp[0]) ? task_node(g, getcharm(Sp[0])) : NULL;
 int ok = n && n[1].m->ap != lvm_task_exit && !held(n);
 if (ok) n[3].x = putcharm(-getcharm(n[3].x) - 1);
 Sp[0] = ok ? putcharm(1) : ZeroPoint;
 love_musttail return Next(1); }

static lvm(lvm_resume) {
 union u *n = charmp(Sp[0]) ? task_node(g, getcharm(Sp[0])) : NULL;
 int ok = n && held(n);
 if (ok) n[3].x = putcharm(-getcharm(n[3].x) - 1);
 Sp[0] = ok ? putcharm(1) : ZeroPoint;
 love_musttail return Next(1); }

LvDef("pause", pause, 1, NULL);
LvDef("resume", resume, 1, NULL);

lvm(lvm_sleep) {
 word n = Sp[0];
 Sp[0] = zero;
 Ip += 1;
 // the clock alone: a lingering next_wait_fd would gate the timer on that fd
 g->next_wait_fd = -1;
 if (!charmp(n) || getcharm(n) <= 0) { g->next_wake_at = 0; love_musttail return Ap(lvm_yield_sw, g); }
 g->next_wake_at = (uintptr_t) love_clock() + getcharm(n);
 love_musttail return Ap(lvm_yield_sw, g); }
