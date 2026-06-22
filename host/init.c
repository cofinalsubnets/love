// host/init.c -- the init (pid-1 supervisor) nifs: SPAWN a process without
// waiting + REAP an arbitrary dead child WITH its pid. Host-only, auto-globbed +
// AI_NIF-registered (no ai.c/ai.h/main.c edit), the same discipline as net.c
// (ain) / pty.c (bao). These are the two primitives a supervisor needs that the
// existing nifs miss: run/exec/mind all BLOCK or REPLACE, and pty.c's `gather`
// reaps a KNOWN pid (handing back only the status). init/init.l drives REAL
// processes with these plus bao's generic `still` (kill): spawn returns a pid to
// track, reap is the SIGCHLD core (poll it, map the pid back to a unit, restart
// per policy). On a real pid1 reap also collects reparented orphans (waitpid(-1)).
//
//   (spawn argv)  -> child pid (a fixnum) | a NEGATIVE fixnum (-errno / -1 misuse)
//   (reap _)      -> (pid . status) of one reaped child
//                  | ()                 none pending
//                  | a NEGATIVE fixnum  (-errno, e.g. -ECHILD: no children left)
//
// argv marshaling mirrors host_exec (main.c): a chain of strings -> a NUL-
// terminated char** in the uncommitted heap gap at Hp (GC-invisible, holds no l
// pointers, consumed before any further alloc), valid across the fork. The wait-
// status decode is shared with bao via host/proc.h (proc_status).
#include "ai.h"
#include "proc.h"
#include <unistd.h>     // fork execvp _exit
#include <stdio.h>      // fflush
#include <string.h>     // memcpy
#include <errno.h>

// (spawn argv) -> the child pid, or a negated errno (negative, so a caller tells
// a pid (positive) from a failure (negative) without a second value). fork +
// execvp; the parent returns immediately -- NON-BLOCKING, unlike run (waits +
// captures) and exec (replaces in place). The child inherits init's stdio (a real
// pid1 redirects to the journal); a failed exec _exit(127)s, seen by the next reap.
ai_noinline static struct ai *host_spawn(struct ai *g, ai_word argv) {
  intptr_t argc = 0;
  uintptr_t total = 0;
  for (ai_word p = argv; chainp(p); p = B(p)) {
    if (!ai_strp(A(p))) return ai_push(g, 1, putcharm(-1));   // misuse: non-string argv
    argc++, total += len(A(p)) + 1; }
  if (!argc) return ai_push(g, 1, putcharm(-1));              // empty argv
  if (!ai_ok(g = ai_have(g, (uintptr_t) argc + 1 + b2w(total)))) return g;
  argv = g->sp[0];                                            // re-root post-ai_have
  char **cav = (char**) g->hp;
  char *blob = (char*) (g->hp + (argc + 1));
  { uintptr_t off = 0; intptr_t i = 0;
    for (ai_word p = argv; chainp(p); p = B(p), i++) {
      struct ai_str *s = str(A(p));
      memcpy(blob + off, txt(s), len(s));
      blob[off + len(s)] = 0;
      cav[i] = blob + off;
      off += len(s) + 1; }
    cav[argc] = NULL; }
  fflush(NULL);                                               // flush now, not twice in the child
  pid_t pid = fork();
  if (pid < 0) return ai_push(g, 1, putcharm(-errno));
  if (!pid) { execvp(cav[0], cav); _exit(127); }             // child: exec or die 127
  return ai_push(g, 1, putcharm(pid)); }                      // parent: the live pid

static lvm(lvm_spawn) {
  Pack(g);
  g = host_spawn(g, Sp[0]);
  if (!ai_ok(g)) return ghelp(g);
  Unpack(g);
  Sp[1] = Sp[0];                                              // pid over argv
  Sp += 1; Ip += 1;
  return Continue(); }

// (reap _) -> (pid . status) of one reaped child, () if none are pending, or a
// negated errno (e.g. -ECHILD when no children remain). The pid is the CAR so the
// supervisor maps it back to a unit; status is proc_status (exit code / 128+sig).
// waitpid(-1, WNOHANG) reaps ANY child -- incl. reparented orphans on a real pid1.
// The arg is a dummy (ignored), so a bare (reap) curries; call it (reap 0).
ai_noinline static struct ai *host_reapany(struct ai *g) {
  int st;
  pid_t r = waitpid(-1, &st, WNOHANG);
  if (r == 0) { g->sp[0] = ai_nil; return g; }               // none pending
  if (r < 0)  { g->sp[0] = putcharm(-errno); return g; }     // error (ECHILD = none alive)
  if (!ai_ok(g = ai_have(g, Width(struct ai_chain)))) return g;
  struct ai_chain *w = ini_chain((struct ai_chain*) bump(g, Width(struct ai_chain)),
                                 putcharm(r), putcharm(proc_status(st)));
  g->sp[0] = word(w);
  return g; }

static lvm(lvm_reapany) {
  Pack(g);
  g = host_reapany(g);
  if (!ai_ok(g)) return ghelp(g);
  Unpack(g);
  Ip += 1; return Continue(); }

static union u const
  nif_spawn[]   = {{lvm_spawn}, {lvm_ret0}},
  nif_reapany[] = {{lvm_reapany}, {lvm_ret0}};
AI_NIF("spawn", nif_spawn);
AI_NIF("reap",  nif_reapany);
