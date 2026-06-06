#include "i.h"

#define YIELD_INTERVAL 64
#define YieldCheck() \
  if (f->tasks->m != f->tasks && ++f->yield_ctr >= YIELD_INTERVAL) \
    return Ap(g_vm_yield_sw, f)

// (set-numap fn): install the gwen handler for fixnum-as-function application.
// Called once from prelude.g; the value stays as the bif's result.
g_word g_numap;
g_vm(g_vm_set_numap) { g_numap = Sp[0]; return Ip++, Continue(); }

// Fixnum-as-function application. A fixnum operator n applied to x is dispatched
// to the gwen handler in g_numap as (num-ap n x): numeric x -> x**n, a function
// x -> x iterated n times (Church numerals). prelude.g installs num-ap before any
// fixnum apply can run (boot itself applies none), so there is no fallback path.
//
// The driver mirrors the pair driver: with the stack laid out [n, num-ap, x, ret]
// it applies num-ap to n (a partial), swaps so that partial becomes the operator,
// applies it to x, and ret0s the result to ret. The five apply sites divert here as
// a tail jump (no extra args -> stays a sibcall, cf. vmret): g_vm_numap is the
// non-tail form (frame below Sp, resume at Ip+1), g_vm_numtap the tail form (frame
// in the popped region, deliver to the caller's ret at Sp[fs+2]). The fused arg/quote
// variants first push their argument under the operator and bump Ip by one word so
// the canonical [.. x n] layout and resume/frame-size operand line up, then divert.
static g_vm(numap_swap) {
 word t = Sp[0]; Sp[0] = Sp[1], Sp[1] = t;
 return Ap(g_vm_ap, f); }
static union u numap_drive[] = { {g_vm_ap}, {.ap = numap_swap}, {.ap = g_vm_ret0} };
static g_vm(g_vm_numap) {
 Have(2);
 word n = Sp[1], x = Sp[0], *dst = Sp - 2, ret = word(Ip + 1);
 dst[0] = n, dst[1] = g_numap, dst[2] = x, dst[3] = ret;
 return Sp = dst, Ip = numap_drive, Continue(); }
static g_vm(g_vm_numtap) {
 Have(2);
 word fs = getnum(Ip[1].x), n = Sp[1], x = Sp[0], *dst = &Sp[fs + 2] - 3, ret = Sp[fs + 2];
 dst[0] = n, dst[1] = g_numap, dst[2] = x, dst[3] = ret;
 return Sp = dst, Ip = numap_drive, Continue(); }

// apply function to one argument
g_vm(g_vm_ap) {
 union u *k;
 if (oddp(Sp[1])) return Ap(g_vm_numap, f);
 k = cell(Sp[1]), Sp[1] = word(Ip + 1), Ip = k;
 YieldCheck();
 return Continue(); }

// tail call
g_vm(g_vm_tap) {
 if (oddp(Sp[1])) return Ap(g_vm_numtap, f);         // fixnum operator -> num-ap, deliver to caller
 intptr_t x = Sp[0], j = Sp[1];
 Sp += getnum(Ip[1].x) + 1;
 Ip = cell(j), Sp[0] = x;
 YieldCheck();
 return Continue(); }

// apply to multiple arguments
g_vm(g_vm_apn) {
 size_t n = getnum(Ip[1].x);
 union u *r = Ip + 2; // return address
 // this instruction is only emitted when the callee is known to be a function
 // so putting a value off the stack into Ip is safe. the +2 is cause we leave
 // the currying instruction in there... should be skipped in compiler instead FIXME
 Ip = cell(Sp[n]) + 2;
 Sp[n] = word(r); // store return address
 YieldCheck();
 return Continue(); }

// tail call
g_vm(g_vm_tapn) {
 size_t n = getnum(Ip[1].x),
        r = getnum(Ip[2].x);
 Ip = cell(Sp[n]) + 2;
 word *o = Sp;
 for (Sp += r + 1; n--; Sp[n] = o[n]);
 YieldCheck();
 return Continue(); }

// return
g_vm(g_vm_ret) {
 word n = getnum(Ip[1].x) + 1;
 return Ip = cell(Sp[n]), Sp[n] = Sp[0], Sp += n, Continue(); }

g_vm(g_vm_ret0) { return
 Ip = cell(Sp[1]),
 Sp[1] = Sp[0],
 Sp += 1,
 Continue(); }


// kcall : x = Sp[0], k = Ip[1] -> Ip = k, Sp[0] = x
g_vm(g_vm_kcall) {
 word x = Sp[0];
 union u *stack = Ip + 2, *end = (union u*) ttag(f, stack);
 uintptr_t height = end - stack;
 Have(height);
 *(Sp = memmove(topof(f) - height, stack, height * sizeof(word))) = x;
 Ip = Ip[1].m;
 return Continue(); }

// callk : i = Sp[0], k = Ip + 1 -> Ip = i, Sp[0] = k
g_vm(g_vm_callk) {
 word f_val = Sp[0];                         // f, the call_cc arg
 if (oddp(f_val)) return Ip += 1, Continue();
 word height = topof(f) - Sp;
 uintptr_t n = 2 + height;                   // g_vm_kcall + (ip + 1) + stack = thread_contents
 Have(n + Width(struct g_tag) + 1);          // thread_contents + thread_tag + 1 stack = _mem_req
 union u *k = (union u*) Hp;
 Hp += n + Width(struct g_tag);              // thread_contents + thread_tag = _heap_alloc
 k[0].ap = g_vm_kcall;                       // 
 k[1].m  = Ip + 1;                           // resume at next instruction
 memcpy(k + 2, Sp, height * sizeof(word));
 Sp -= 1;
 Sp[0] = word(tagthd(k, n));
 Sp[1] = f_val;
 return Ap(g_vm_ap, f); }

// g_vm_yield_sw_mono can't call g_wait_fds directly with a stack pointer
static g_noinline void g_wait_fd(int const fd, int n, uintptr_t ms) {
  g_wait_fds(&fd, n, ms); }

// monotask fast path
static g_vm(g_vm_yield_sw_mono) { uintptr_t my_wake = f->next_wake_at;
 int my_wait_fd = f->next_wait_fd;
 f->next_wake_at = 0;
 f->next_wait_fd = -1;
 f->yield_ctr = 0;
 if (my_wake) for (uintptr_t now; my_wake > (now = g_clock());)
  my_wait_fd >= 0 ? g_wait_fd(my_wait_fd, 1, my_wake - now) : g_sleep(my_wake - now);
 else if (my_wait_fd >= 0)
  while (!g_ready(my_wait_fd)) g_wait_fd(my_wait_fd, 1, 0);
 return Continue(); }

// First non-dormant peer in the ring whose wake_at <= now and whose
// wait_fd is either unset or actually ready. Without the wait_fd check
// a task parked on stdin would be scheduled immediately, busy-looping
// through yield_sw and filling the heap with stale task nodes.
static g_inline union u *find_runnable(union u *head, uintptr_t now) {
 for (union u *n = head->m; n != head; n = n->m)
  if (n[1].m->ap != g_vm_task_exit && (uintptr_t) getnum(n[3].x) <= now) {
   int wf = (int) getnum(n[4].x);
   if (wf < 0 || g_ready(wf)) return n; }
 return NULL; }

static g_noinline union u *yield_sw_wait(struct g *f, uintptr_t my_wake, int my_wait_fd) {
 uintptr_t min_wake = my_wake;
 int fds[G_WAIT_FDS_MAX], nfds = 0;
 if (my_wait_fd >= 0) fds[nfds++] = my_wait_fd;
 for (union u *n = f->tasks->m; n != f->tasks; n = n->m)
  if (n[1].m->ap != g_vm_task_exit) {
   uintptr_t wa = (uintptr_t) getnum(n[3].x);
   if (wa && (!min_wake || wa < min_wake)) min_wake = wa;
   int wf = (int) getnum(n[4].x);
   if (wf >= 0 && nfds < G_WAIT_FDS_MAX) fds[nfds++] = wf; }
 if (!min_wake && !nfds) return NULL;
 uintptr_t now = g_clock();
 if (!min_wake) g_wait_fds(fds, nfds, 0);
 else if (min_wake > now) g_wait_fds(fds, nfds, min_wake - now);
 now = g_clock();
 if (my_wait_fd >= 0 && g_ready(my_wait_fd)) return NULL;
 return find_runnable(f->tasks, now); }

g_vm(g_vm_yield_sw) {
 if (f->tasks->m == f->tasks) return Ap(g_vm_yield_sw_mono, f);
 union u *next = find_runnable(f->tasks, g_clock());
 uintptr_t my_wake = f->next_wake_at;
 int my_wait_fd = f->next_wait_fd;
 if (!next) {
  next = yield_sw_wait(f, my_wake, my_wait_fd);
  if (!next) {
   f->next_wake_at = 0;
   f->next_wait_fd = -1;
   if (f->yield_ctr >= YIELD_INTERVAL) f->yield_ctr = 0;
   return Continue(); } }
 word my_height = topof(f) - Sp;
 union u *next_stack = next + 5,
       *end = (union u*) ttag(f, next_stack);
 uintptr_t restore_h = end - next_stack,
           need = my_height + restore_h + 6;
 if (Sp < Hp + need) {
  Pack(f);
  if (!g_ok(f = g_please(g_push(f, 1, next), need))) return gtrap(f);
  next = cell(pop1(f));
  Unpack(f);
  next_stack = next + 5; }   // recompute: next was forwarded by gc
 f->next_wake_at = 0;
 f->next_wait_fd = -1;
 union u *prev = next;
 while (prev->m != f->tasks) prev = prev->m;
 union u *N = (union u*) Hp;
 Hp += need - restore_h;
 N[0].m = f->tasks->m;
 N[1].m = Ip;
 N[2].x = f->tasks[2].x;
 N[3].x = putnum((intptr_t) my_wake);
 N[4].x = putnum(my_wait_fd);
 memcpy(N + 5, Sp, my_height * sizeof(word));
 prev->m = tagthd(N, 5 + my_height);
 f->yield_ctr = 0;
 f->tasks = next;
 Sp = memmove(topof(f) - restore_h, next_stack, restore_h * sizeof(word));
 Ip = next[1].m;
 return Continue(); }

g_vm(g_vm_yield_bif) { return Ip++, Ap(g_vm_yield_sw, f); }
g_vm(g_vm_task_exit) { return Ap(g_vm_yield_sw, f); }
static union u spawn_body[] = { {g_vm_ap}, {.ap = g_vm_task_exit} };
g_vm(g_vm_spawn) {
 Have(8);
 // New task node N: [next, saved_ip=spawn_body, pid, wake_at=0, wait_io=0, stack[0..1]=x,fn, tag]
 union u *N = (union u*) Hp;
 Hp += 8;
 word fn = Sp[0], x = Sp[1];
 uintptr_t pid = ++f->next_pid;
 N[0].m = f->tasks->m;
 N[1].m = (union u*) spawn_body;
 N[2].x = Sp[1] = putnum(pid);
 N[3].x = nil;         // wake_at: sentinel for "always runnable"
 N[4].x = putnum(-1);  // wait_fd: -1 = not waiting on I/O
 N[5].x = x;
 N[6].x = fn;
 f->tasks->m = tagthd(N, 7);
 return Sp++, Ip++, Continue(); }

g_vm(g_vm_wait) {
 word pid_arg = Sp[0], ret = nil;
 intptr_t target = getnum(pid_arg);
 for (union u *node = f->tasks->m; node != f->tasks; node = node->m) {
  if (getnum(node[2].x) != target) continue;
  if (node[1].m->ap == g_vm_task_exit) {
   // dormant: dormant task's stack is just [retval] at node[5]
   ret = node[5].x;
   union u *prev = node;
   while (prev->m != node) prev = prev->m;
   prev->m = node->m;
   break; }
   // still running: yield without advancing Ip (re-enter wait on resume)
  return Ap(g_vm_yield_sw, f); }
 return *Sp = ret, Ip++, Continue(); }

g_vm(g_vm_donep) {
 word pid_arg = Sp[0], result = putnum(-1);
 intptr_t target = getnum(pid_arg);
 for (union u *node = f->tasks->m; node != f->tasks; node = node->m)
  if (getnum(node[2].x) == target) {
   if (node[1].m->ap != g_vm_task_exit) result = nil;
   break; }
 Sp[0] = result;
 Ip += 1;
 return Continue(); }

g_vm(g_vm_kill) {
 word pid_arg = Sp[0], result = nil;
 intptr_t target = getnum(pid_arg);
 union u *prev = f->tasks;
 for (union u *node = prev->m; node != f->tasks; prev = node, node = node->m)
  if (getnum(node[2].x) == target) {
   prev->m = node->m;
   result = putnum(-1);
   break; }
 Sp[0] = result;
 Ip += 1;
 return Continue(); }

g_vm(g_vm_sleep) {
 word n = Sp[0];
 Sp[0] = nil;
 Ip += 1;
 if (!nump(n) || getnum(n) <= 0) return Continue();
 f->next_wake_at = (uintptr_t) g_clock() + getnum(n);
 return Ap(g_vm_yield_sw, f); }


g_vm(g_vm_jump) { return Ip = Ip[1].m, Continue(); }
// The only compiled truthiness branch (`?`, and the `&&`/`||` macros). Uses the
// language falsy predicate so an all-zero vec (boxed 0.0, zero int box,
// all-zero array) takes the false arm, lifting "0 is the only false scalar".
g_vm(g_vm_cond) { return Ip = g_false(*Sp++) ? Ip[1].m : Ip + 2, Continue(); }
g_vm(g_vm_unc) {
 Have1();
 *--Sp = Ip[1].x;
 Ip = Ip[2].m;
 return Continue(); }

g_vm(g_vm_cur) {
 size_t const S = 3 + Width(struct g_tag);
 Have(S + 2);
 union u *k = (union u*) Hp, *j = k;
 Hp += S;
 size_t n = getnum(Ip[1].x);
 // FIXME this does not always need to be a runtime check
 if (n > 2) Hp += 2,
            j += 2,
            k[0].ap = g_vm_cur,
            k[1].x = putnum(n - 1);
 return
  j[0].ap = g_vm_unc,
  j[1].x = *Sp++,
  j[2].m = Ip + 2,
  Ip = cell(*Sp),
  Sp[0] = (word) tagthd(k, j + 3 - k),
  Continue(); }

// load instructions
//
g_vm(g_vm_quote) {
 Have1();
 Sp -= 1;
 Sp[0] = Ip[1].x;
 Ip += 2;
 return Continue(); }

g_vm(g_vm_port_io) {
  word x = word(Ip);
  Ip = cell(*++Sp);
  *Sp = x;
  return Continue(); }

// push a value from the stack
g_vm(g_vm_arg) {
 Have1();
 Sp[-1] = Sp[getnum(Ip[1].x)];
 Sp -= 1;
 Ip += 2;
 return Continue(); }

// fused (g_vm_arg <idx> ; g_vm_ap): push local at <idx>, then apply. A 2-word op
// emitted by the compiler's `karg` when an arg ref is immediately followed by a
// non-tail ap (the dominant "call a function on a local" shape). Saves one
// dispatch + the standalone ap word vs. the unfused pair. The post-pattern
// resume address is Ip+2 (cf. g_vm_ap's Ip+1, since the op is one word longer).
g_vm(g_vm_argap) {
 if (oddp(Sp[0])) {                                  // fixnum operator -> num-ap, resume at Ip+2
  Have1();
  Sp[-1] = Sp[getnum(Ip[1].x)], Sp -= 1, Ip += 1;   // push local under operator; resume now Ip+2
  return Ap(g_vm_numap, f); }
 Have1();
 Sp[-1] = Sp[getnum(Ip[1].x)];
 Sp -= 1;
 union u *k = cell(Sp[1]); Sp[1] = word(Ip + 2), Ip = k;
 YieldCheck();
 return Continue(); }

// fused (g_vm_quote <v> ; g_vm_ap): push constant <v>, then apply. Emitted by
// kim when a quote is immediately followed by a non-tail ap (a call with a
// constant arg, e.g. (k 0)). Resume at Ip+2 (2-word op), cf. g_vm_argap.
g_vm(g_vm_quoteap) {
 if (oddp(Sp[0])) {                                  // fixnum operator -> num-ap, resume at Ip+2
  Have1();
  Sp[-1] = Ip[1].x, Sp -= 1, Ip += 1;               // push const under operator; resume now Ip+2
  return Ap(g_vm_numap, f); }
 Have1();
 Sp -= 1;
 Sp[0] = Ip[1].x;
 union u *k = cell(Sp[1]); Sp[1] = word(Ip + 2), Ip = k;
 YieldCheck();
 return Continue(); }

// fused (g_vm_arg <idx> ; g_vm_tap <fs>): push local <idx>, then tail-call,
// popping frame size <fs> at Ip[2] (tap's operand, kept in place by the fused
// emit). The single-arg tail-call shape, e.g. a tail (loop x) or cont (k v).
g_vm(g_vm_argtap) {
 if (oddp(Sp[0])) {                                  // fixnum operator -> num-ap, deliver to caller
  Have1();
  Sp[-1] = Sp[getnum(Ip[1].x)], Sp -= 1, Ip += 1;   // push local under operator; fs operand now Ip[1]
  return Ap(g_vm_numtap, f); }
 Have1();
 Sp[-1] = Sp[getnum(Ip[1].x)];
 Sp -= 1;
 intptr_t x = Sp[0], j = Sp[1];
 Sp += getnum(Ip[2].x) + 1;
 Ip = cell(j), Sp[0] = x;
 YieldCheck();
 return Continue(); }

// operand-value-specialized arg/quote: 1-word ops with the index/constant baked
// into the handler (no Ip[1] operand fetch). Emitted by the compiler's spa/spq for
// the hottest indices {0..3} / constants {0,1,2,3,-1,-2}.
#define ARGN(nom, i) g_vm(nom) { Have1(); Sp[-1] = Sp[i]; Sp -= 1; Ip += 1; return Continue(); }
#define QUON(nom, v) g_vm(nom) { Have1(); Sp -= 1; Sp[0] = putnum(v); Ip += 1; return Continue(); }
ARGN(g_vm_arg0, 0) ARGN(g_vm_arg1, 1) ARGN(g_vm_arg2, 2) ARGN(g_vm_arg3, 3)
QUON(g_vm_quo0, 0) QUON(g_vm_quo1, 1) QUON(g_vm_quo2, 2) QUON(g_vm_quo3, 3)
QUON(g_vm_quom1, -1) QUON(g_vm_quom2, -2)

g_vm(g_vm_trim) { return
 clip(f, cell(Sp[0])), Ip++, Continue(); }

g_vm(g_vm_seek) { return
 Sp[1] = word(cell(Sp[1]) + getnum(Sp[0])),
 Sp++, Ip++, Continue(); }

g_vm(g_vm_peek2) { return
 Sp[1] = (cell(Sp[1]) + getnum(Sp[0]))->x,
 Sp++, Ip++, Continue(); }

g_vm(g_vm_poke2) {
 union u *c = cell(Sp[2]) + getnum(Sp[0]);
 return c->x = Sp[1], *(Sp += 2) = word(c), Ip++, Continue(); }

g_vm(g_vm_thda) {
 size_t n = getnum(Sp[0]);
 Have(n + Width(struct g_tag));
 union u *k = (union u*) Hp;
 Hp += n + Width(struct g_tag);
 Sp[0] = word(memset(tagthd(k, n), -1, n * sizeof(word)));
 return Ip++, Continue(); }

g_vm(g_vm_len) {
  word x = Sp[0], l = 0;
  if (bufp(x)) l = len(buf_str(x));              // mutable byte string
  else if (!nump(x) && datp(x)) switch (typ(x)) {
    default: break;                              // vec_q, sym_q have no length
    case hash_q: l = hsh(x)->len; break;
    case text_q: l = len(x); break;
    case two_q: do l++, x = B(x); while (twop(x)); }
  Sp[0] = putnum(l);
  Ip += 1;
  return Continue(); }
