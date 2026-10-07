// task.c -- the tasks and their scheduler: twirl, wait, done?, scoop, hush, sleep, and the
// switch every one of them yields through. one translation unit of the runtime; the shared
// layouts and the cross-TU seam are src/love/love.h.
#include "love.h"

// (heard x) -> the installed help (x ignored): the live read of hook 5, what
// prel's cellread and bao's launcher ask before choosing to raise or install.
op11(lvm_heard, (intptr_t) *task_help(g))
// (worn x) -> the stdio this task wears (x ignored): the live read of hook 6, the
// () when it wears the console. what a caller saves before re-seating.
op11(lvm_worn, (intptr_t) *task_io(g))
// (myself x) -> the running task's own id (x ignored): the charm `twirl` answered for it,
// and the zero point for the task nobody twirled. the run ring's head is the running
// task, so this is a read of its pid slot. what a per-task escape compares against
// before it jumps -- a help is inherited at spawn, so a child can hold a continuation
// captured in its parent's stack, and landing there tears both.
op11(lvm_myself, (intptr_t) g->tasks[2].x)

// lvm_yield_sw_mono can't call wait_fds directly with a stack record
static love_noinline void wait_one(int fd, int events, uintptr_t ms) {
  struct wait_fd w = { .fd = fd, .events = (short) events };
  wait_fds(&w, 1, ms); }

// monotask fast path
static lvm(lvm_yield_sw_mono) { uintptr_t my_wake = g->next_wake_at;
 int my_wait_fd = g->next_wait_fd, my_events = g->next_wait_events;
 g->next_wake_at = 0;
 g->next_wait_fd = -1;
 g->next_wait_events = wait_in;
 g->yield_ctr = 0;
 if (my_wake) for (uintptr_t now; my_wake > (now = love_clock());)
  my_wait_fd >= 0 ? wait_one(my_wait_fd, my_events, my_wake - now) : love_sleep(my_wake - now);
 else if (my_wait_fd >= 0)
  while (!ready(my_wait_fd, my_events)) wait_one(my_wait_fd, my_events, 0);
 love_musttail return Continue(); }

// the parked ring by pid; the predecessor comes back too (singly linked, and an
// unsplice cannot go looking for it twice)
static love_inline union u *parked_find(struct g *g, intptr_t pid, union u **prevp) {
 union u *head = g->parked;
 if (!head) return NULL;
 union u *prev = head;
 do { union u *n = prev->m;
      if (getcharm(n[2].x) == pid) return *prevp = prev, n;
      prev = n; } while (prev != head);
 return NULL; }

// take `n` off the parked ring. called with g packed: gen_wb reads g->hp to tell
// young from old, and the live Hp runs ahead of the last Pack.
static love_inline void parked_drop(struct g *g, union u *prev, union u *n) {
 if (prev == n) return (void) (g->parked = NULL);   // it was the whole ring
 prev->m = n->m;
 gen_wb(g, (word) prev, (word) prev->m);            // an old node now links to a (maybe young) successor
 if (g->parked == n) g->parked = prev; }

// ...and onto the run ring behind `tail`, so a park-and-wake task queues behind its
// peers. answers the new tail, so a many-task wake walks the run ring once
// (finding the tail inside made a 200-client wake quadratic). the wait_fd is
// cleared on the way in -- the run ring's whole invariant: nothing there is fd-parked.
static love_inline union u *run_splice_at(struct g *g, union u *tail, union u *n) {
 n[0].m = g->tasks;
 n[4].x = putcharm(-1);
 gen_wb(g, (word) n, (word) n[0].m);
 tail->m = n;
 gen_wb(g, (word) tail, (word) tail->m);
 return n; }

// a held task (pause) keeps its deadline negated: never due, and back whole at resume
static love_inline int held(union u const *n) { return getcharm(n[3].x) < 0; }

// is the task named by pid still live? the ring head is the running task, whose
// saved ip is stale -- me_live carries its own yield's answer. a pid with no node
// is gone, not live: a catcher must not wait on a ghost.
static love_inline int task_live(struct g *g, union u *head, intptr_t pid, int me_live) {
 if (getcharm(head[2].x) == pid) return me_live;
 for (union u *n = head->m; n != head; n = n->m)
  if (getcharm(n[2].x) == pid) return n[1].m->ap != lvm_task_exit && !held(n);
 union u *prev;   // and the parked ring: a caught task blocked on an fd is live, and
 union u *p = parked_find(g, pid, &prev);   // a catcher told otherwise stops waiting.
 return p ? p[1].m->ap != lvm_task_exit && !held(p) : 0; }

// readiness the wait already answered: poll(2) reports every ready fd in its set.
// -> 1 ready, 0 not, -1 don't know (no block, or fd not in it). match on the
// (fd, events) pair -- two tasks can park on one fd in opposite directions. any
// nonzero revents is ready: a hung-up fd wants waking to read the end. the cursor
// is speed, not correctness.
static love_inline int polled_ready(struct wait_fd const *fds, int nfds, int *cur, int fd, int ev) {
 for (int i = 0; i < nfds; i++) {
  int j = *cur + i < nfds ? *cur + i : *cur + i - nfds;
  if (fds[j].fd == fd && fds[j].events == (short) ev)
   return *cur = j + 1 < nfds ? j + 1 : 0, fds[j].revents != 0; }
 return -1; }

// first runnable peer, run ring only: nothing here is fd-parked, so the walk
// issues no syscall. the catch clause matters -- without it a catcher is always
// runnable and the scheduler never reaches its wait (the catch park carries no
// state: Ip is unadvanced, so the saved ip is the catch, the pid its stack top).
// the wait_fd arm is a floor, not a path: a slipped invariant costs a re-park.
static union u *find_runnable(struct g *g, union u *head, uintptr_t now, int me_live) {
 for (union u *n = head->m; n != head; n = n->m)
  if (n[1].m->ap != lvm_task_exit && (uintptr_t) getcharm(n[3].x) <= now) {
   if (n[1].m->ap == lvm_wait && task_live(g, head, getcharm(n[8].x), me_live)) continue;
   int wf = (int) getcharm(n[4].x);
   if (wf < 0 || wait_buffered(g, n[1].m->ap, n[8].x, wf)
       || ready(wf, (int) getcharm(n[5].x))) return n; }
 return NULL; }

// can this parked task run again? deadline come, port holding bytes, or fd ready
// (off the filled block, else ask). `ask` is whether the kernel may be asked:
// with it clear only the syscall-free terms count -- the pass yield_sw_wait makes
// before it builds a wait.
static love_inline int parked_ready(struct g *g, union u *n, uintptr_t now,
                                  struct wait_fd const *fds, int nfds, int *cur, int ask) {
 if (n[1].m->ap == lvm_task_exit || (uintptr_t) getcharm(n[3].x) > now) return 0;
 int wf = (int) getcharm(n[4].x), ev = (int) getcharm(n[5].x);
 if (wf < 0 || wait_buffered(g, n[1].m->ap, n[8].x, wf)) return 1;
 int pr = polled_ready(fds, nfds, cur, wf, ev);
 return pr < 0 ? (ask && ready(wf, ev)) : pr; }

// the wake pass: every parked task that can run again moves to the run ring; answers
// how many. walked by count -- a waking task is unspliced under the cursor, and the
// head is as free to leave as anyone. called with g packed (every relink barriers).
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

// the fairness path's ask: one sweep of every parked fd, then the wake. the block
// rides the [hp, sp) gap (called with g packed). the block is authoritative
// here, unlike the wait's: all-zero means "none ready", never "nobody said".
static love_noinline int poll_parked(struct g *g, uintptr_t now) {
 int n = 1;
 for (union u *q = g->parked->m; q != g->parked; q = q->m) n++;
 struct wait_fd *fds = (struct wait_fd*) g->hp;
 // no gap to lay them in (the heap at its fullest, a collection pending): ask the old
 // way rather than skip the sweep, which would leave a ready peer parked.
 if (avail(g) < b2w((uintptr_t) n * sizeof *fds)) return wake_parked(g, now, NULL, 0, 1);
 int k = 0;
 union u *q = g->parked;
 do { int wf = (int) getcharm(q[4].x);
      if (wf >= 0) fds[k].fd = wf, fds[k].revents = 0, fds[k++].events = (short) getcharm(q[5].x);
      q = q->m; } while (q != g->parked);
 ready_fds(fds, k);
 return wake_parked(g, now, fds, k, 0); }

// the fd set is sized by the count, never a constant (kiosko parks a task per
// client); the block rides the uncommitted heap gap, so counting first retires the
// cap by construction. called with g packed. both rings are walked: the run
// ring holds the sleepers, the parked ring the fds -- one ring's terms alone
// oversleep the other's.
static love_noinline union u *yield_sw_wait(struct g *g, uintptr_t my_wake, int my_wait_fd, int my_events, int me_live) {
 // the syscall-free wakes first, load-bearing: a parked task whose port already
 // holds bytes is runnable over an fd with nothing left to say -- a wait built
 // while it is parked never returns and `catch` hangs (test/host/parked.l, law 2).
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
 if (!min_wake && !nfds) return NULL;
 uintptr_t now = love_clock(), ticks = min_wake ? min_wake - now : 0;
 // the filled block, once the wait answers it; stays NULL unless some entry came
 // back nonzero, so a frontend that fills nothing keeps working the old way
 struct wait_fd const *pol = NULL;
 int npol = 0;
 if (!min_wake || min_wake > now) {
  struct wait_fd *fds = (struct wait_fd*) g->hp;
  // no gap to lay them in (the heap at its fullest, a collection pending): wait
  // on the clock alone and come straight back, rather than on a set we already
  // know is short -- the one thing this rung exists to stop.
  if (avail(g) < b2w((uintptr_t) nfds * sizeof *fds)) wait_fds(NULL, 0, ticks ? ticks : 1);
  else {
   int k = 0;
   // revents is zeroed here and nowhere else. the block is raw heap gap, so an
   // unwritten slot would otherwise read as whatever the last allocation left, and
   // "ready" is exactly the wrong way to guess.
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
 // the monotask door needs both rings empty. a lone runnable task with parked peers
 // reads as a self-ring now, and the mono path waits on its own fd only -- the peers
 // would sleep through every wake they were owed.
 if (g->tasks->m == g->tasks && !g->parked) love_musttail return Ap(lvm_yield_sw_mono, g);
 // a task on its way out is not live, and its own node cannot say so yet -- the
 // snapshot that records the exit is written at the foot of this op.
 int me_live = Ip->ap != lvm_task_exit;
 uintptr_t my_wake = g->next_wake_at;
 int my_wait_fd = g->next_wait_fd, my_events = g->next_wait_events;
 // a fairness yield never reaches yield_sw_wait, so this counter is the only thing
 // asking on its behalf whether a parked peer woke; sweeping is a syscall, so it
 // rides sweep_interval. it must fire even with a runnable peer to hand the cpu
 // to -- two compute tasks trading turns would starve every parked peer for good.
 // ..and neither op that yields WITHOUT advancing Ip may take the fairness arm below:
 // it answers Continue(), which lands back on the same op, so "keep running" is a spin.
 // a catcher is one; a task on its way out is the other, and it has no work left to keep.
 int fair = !my_wake && my_wait_fd < 0 && Ip->ap != lvm_wait && Ip->ap != lvm_task_exit;
 // the clock rides the same tick: on wasm a read is a trip out to the host, and between
 // ticks a peer's deadline is late by at most sweep_interval fairness yields.
 uintptr_t now = g->clock_at;
 if (!fair || ++g->sweep_ctr >= sweep_interval) {
  now = g->clock_at = love_clock();
  if (fair && (g->sweep_ctr = 0, g->parked)) {
   Pack(g);                    // the sweep lays its fd block in the [hp, sp) gap
   poll_parked(g, now);
   Unpack(g); } }              // nothing allocated, so these come back unchanged
 union u *next = find_runnable(g, g->tasks, now, me_live);
 if (!next) {
  // a fairness yield with no runnable peer just keeps running: falling into
  // yield_sw_wait would throttle compute to the slowest sleeping peer's period.
  // a blocked task still waits below, and so does a dead one: it waits on its peers'
  // behalf until one of them can run, which is what leaves it a collectable zombie.
  if (fair) { g->yield_ctr = 0; love_musttail return Continue(); }
  Pack(g);                     // the wait lays its fd block in the [hp, sp) gap
  next = yield_sw_wait(g, my_wake, my_wait_fd, my_events, me_live);
  Unpack(g);                   // nothing allocated, so these come back unchanged
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
 // the snapshot's ring is decided by its wait_fd. a task giving up its turn for an fd
 // is not runnable and must not be walked as though it were -- it leaves the run ring
 // here, which is the whole rung, and comes back through wake_parked.
 int parking = my_wait_fd >= 0;
 N[0].m = parking ? (g->parked ? g->parked->m : N) : g->tasks->m;
 N[1].m = Ip;
 N[2].x = g->tasks[2].x;
 N[3].x = putcharm((intptr_t) my_wake);
 N[4].x = putcharm(my_wait_fd);
 N[5].x = putcharm(my_events);
 N[6].x = g->tasks[6].x;          // the help the departing task heard..
 N[7].x = g->tasks[7].x;          // ..and the stdio it wears ride the snapshot
 memcpy(N + 8, Sp, my_height * sizeof(word));
 tagthread(N, 8 + my_height);
 // the run ring closes over the departing head either way: onto the snapshot when it
 // stays, or over it entirely when it parks.
 prev->m = parking ? g->tasks->m : N;
 // Pack first: young reads g->hp, and the live Hp runs ahead of the last Pack --
 // against a stale g->hp the fresh node reads as old, the barrier drops the edge, and
 // the next minor eats the ring (mitty+ink froze in seconds on exactly this).
 Pack(g);
 gen_wb(g, (word) prev, (word) prev->m);   // task ring: an old node now links to the fresh (young) yield snapshot
 if (parking) {
  // N already points into the parked ring (or at itself): only the ring's own link
  // in is left, and only that one is an old->young edge worth a barrier.
  if (g->parked) { g->parked->m = N; gen_wb(g, (word) g->parked, (word) g->parked->m); }
  else g->parked = N; }
 g->yield_ctr = 0;
 g->tasks = next;
 Sp = memmove(topof(g) - restore_h, next_stack, restore_h * sizeof(word));
 Ip = next[1].m;
 love_musttail return Continue(); }

lvm(lvm_yield_nif) { Ip++; love_musttail return Ap(lvm_yield_sw, g); }
lvm(lvm_task_exit) { love_musttail return Ap(lvm_yield_sw, g); }
static union u const spawn_body[] = { {lvm_ap}, {.ap = lvm_task_exit} };
lvm(lvm_twirl) {
 Have(11);
 // new task node N: [next, saved_ip=spawn_body, pid, wake_at, wait_fd, wait_events, help, stdio, stack[0..1]=x,fn, tag]
 union u *N = (union u*) Hp;
 Hp += 11;
 word fn = Sp[0], x = Sp[1];
 uintptr_t pid = ++g->next_serial;   // a pid is a fresh identity: drawn from the mint stream
 N[0].m = g->tasks->m;
 N[1].m = (union u*) spawn_body;
 N[2].x = Sp[1] = putcharm(pid);
 N[3].x = zero;         // wake_at: sentinel for "always runnable"
 N[4].x = putcharm(-1);  // wait_fd: -1 = not waiting on I/O
 N[5].x = putcharm(wait_in);   // wait_events: the read direction, the default
 N[6].x = g->tasks[6].x;   // inherited: a child starts under its parent's help, never without one
 N[7].x = g->tasks[7].x;   // ...and under its parent's stdio, the console until it wears its own
 N[8].x = x;
 N[9].x = fn;
 g->tasks->m = tagthread(N, 10);
 Pack(g);   // sync: young reads g->hp (see lvm_yield_sw)
 gen_wb(g, (word) g->tasks, (word) g->tasks->m);   // task ring: an old node now links to the fresh (young) spawned task
 love_musttail return Nextp(1, 1); }

lvm(lvm_wait) {
 word pid_arg = Sp[0], ret = zero;
 intptr_t target = getcharm(pid_arg);
 for (union u *node = g->tasks->m; node != g->tasks; node = node->m) {
  if (getcharm(node[2].x) != target) continue;
  if (node[1].m->ap == lvm_task_exit) {
   // dormant: dormant task's stack is just [retval] at node[8]
   ret = node[8].x;
   union u *prev = node;
   while (prev->m != node) prev = prev->m;
   prev->m = node->m;
   Pack(g);   // sync: young reads g->hp (see lvm_yield_sw)
   gen_wb(g, (word) prev, (word) prev->m);   // task ring: unsplicing relinks an old node to a (maybe young) successor
   break; }
  if (held(node)) break;   // held: the catcher hears now, and the zero point
   // still running: yield without advancing Ip -- both halves of the park (the
   // re-entry on resume, and the record: Ip here says "parked in catch", Sp[0]
   // names the peer). clear both wait intentions: a stale fd would gate the park.
   g->next_wake_at = 0;
   g->next_wait_fd = -1;
  love_musttail return Ap(lvm_yield_sw, g); }
 // and the parked ring, or catching a task merely blocked on an fd answers the
 // zero point at once; it is live, so park exactly as above.
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
 // an unfound pid reads landed, so a task merely parked on an fd would report finished --
 // a collector would drop a live session's handle mid-request.
 { union u *prev;
   if (parked_find(g, target, &prev)) result = zero; }
 Sp[0] = result;
 Ip += 1;
 love_musttail return Continue(); }

// (scoop _) -> (pid . retval) of one finished task, or () when none have -- the
// task-side twin of `glean` (src/love/posix.c). presence rides the pair, never the
// net: a retval is legitimately (), so `two?` is the test and ZeroPoint the empty
// answer. only the run ring is walked (parked = blocked = unfinished); the arg is
// a dummy, so a bare (scoop) curries -- call it (scoop 0).
lvm(lvm_scoop) {
 Have(Width(struct chain));
 for (union u *prev = g->tasks, *node = prev->m; node != g->tasks; prev = node, node = node->m) {
  if (node[1].m->ap != lvm_task_exit) continue;
  word pid = node[2].x, ret = node[8].x;   // dormant: the stack is just [retval] at node[8]
  struct chain *p = (struct chain*) Hp;
  Hp += Width(struct chain);
  ini_chain(p, pid, ret);
  prev->m = node->m;
  Pack(g);   // sync: young reads g->hp (see lvm_yield_sw)
  gen_wb(g, (word) prev, (word) prev->m);   // task ring: unsplicing relinks an old node to a (maybe young) successor
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
   Pack(g);   // sync: young reads g->hp (see lvm_yield_sw)
   gen_wb(g, (word) prev, (word) prev->m);   // unsplice relinks an old node to a (maybe young) successor
   Sp[0] = putcharm(1), Ip += 1;
   love_musttail return Continue(); }
 // freeze reaches the parked ring too -- a task blocked on a quiet fd is exactly the one
 // a caller most wants to be able to stop.
 { union u *pp, *p = parked_find(g, target, &pp);
   if (p) { Pack(g); parked_drop(g, pp, p); result = putcharm(1); } }
 Sp[0] = result;
 Ip += 1;
 love_musttail return Continue(); }

// (pause pid) -- a task held where it stands, on whichever ring it is: off the clock until
// resume, catch answering its catcher at once. never the running task. -> 1, or () when there
// is no such task to hold. (resume pid) puts it back with the deadline it had.
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
 // rest waits on the clock alone: a lingering next_wait_fd would gate the timer on
 // that fd firing (a painter slept forever on a quiet port)
 g->next_wait_fd = -1;
 if (!charmp(n) || getcharm(n) <= 0) { g->next_wake_at = 0; love_musttail return Ap(lvm_yield_sw, g); }
 g->next_wake_at = (uintptr_t) love_clock() + getcharm(n);
 love_musttail return Ap(lvm_yield_sw, g); }
