// host/fs.c -- the rest of the POSIX fs surface: the effect ops the fs tools
// (mv, ln, touch, chmod, chown) still miss. Host-only, auto-globbed +
// AI_NIF-registered (no love.c/love.h/main.c edit), the same discipline as the
// posix_ lane in host/init.c, whose conventions these keep:
//   effect ops answer () ok | a POSITIVE errno | EINVAL misuse
//   value ops answer the value | () absence
//
//   (rename old new)      -> () | errno | EINVAL   (mv's heart; same filesystem)
//   (symlink target path) -> () | errno | EINVAL   (path becomes a link TO target)
//   (readlink path)       -> the target string | ()
//   (chmod path mode)     -> () | errno | EINVAL   (mode the raw permission charm)
//   (chown path uid gid)  -> () | errno | EINVAL   (-1 leaves that id alone)
//   (utime path ms)       -> () | errno | EINVAL   (mtime AND atime on the stat
//                            scale, MILLISECONDS; a non-charm ms reads "now")
//   (umask mask)          -> the PREVIOUS mask | -1 misuse (always succeeds)
//   (rmdir path)          -> () | errno | EINVAL   (the empty-directory unlink)
//   (hardlink old new)    -> () | errno | EINVAL   (link(2); `link` the word is
//                            the chain ctor, the most spoken name in the prel,
//                            so the nif wears the long form)
#include "love.h"
#include <unistd.h>     // symlink readlink chown
#include <string.h>     // memcpy
#include <errno.h>
#include <stdio.h>      // rename
#include <fcntl.h>      // AT_FDCWD
#include <sys/stat.h>   // chmod umask utimensat UTIME_NOW

// arg string -> a NUL-terminated C buffer (the init.c shape, file-local there too)
static bool str_cbuf(ai_word x, char *buf, size_t cap) {
 if (!ai_strp(x)) return false;
 struct ai_str *s = (struct ai_str*) x;
 if ((size_t) s->len >= cap) return false;
 memcpy(buf, s->bytes, s->len);
 buf[s->len] = 0;
 return true; }

ai_noinline static ai_word host_posix_rename(ai_word ow, ai_word nw) {
 char o[4096], n[4096];
 if (!str_cbuf(ow, o, sizeof o) || !str_cbuf(nw, n, sizeof n)) return putcharm(EINVAL);
 return rename(o, n) ? putcharm(errno) : ZeroPoint; }
static lvm(lvm_posix_rename) {
 Sp[1] = host_posix_rename(Sp[0], Sp[1]);
 Sp += 1; return Ip++, Continue(); }

ai_noinline static ai_word host_posix_symlink(ai_word tw, ai_word pw) {
 char t[4096], p[4096];
 if (!str_cbuf(tw, t, sizeof t) || !str_cbuf(pw, p, sizeof p)) return putcharm(EINVAL);
 return symlink(t, p) ? putcharm(errno) : ZeroPoint; }
static lvm(lvm_posix_symlink) {
 Sp[1] = host_posix_symlink(Sp[0], Sp[1]);
 Sp += 1; return Ip++, Continue(); }

ai_noinline static struct ai *host_posix_readlink(struct ai *g) {
 char p[4096], b[4096];
 if (!str_cbuf(g->sp[0], p, sizeof p)) return g->sp[0] = ZeroPoint, g;
 ssize_t n = readlink(p, b, sizeof b - 1);
 if (n < 0) return g->sp[0] = ZeroPoint, g;
 b[n] = 0;
 if (!ai_ok(g = ai_strof(g, b))) return g;                    // pushes: target over path
 g->sp[1] = g->sp[0];
 g->sp += 1;
 return g; }
static lvm(lvm_posix_readlink) {
 Pack(g); g = host_posix_readlink(g);
 if (!ai_ok(g)) return ghelp(g);
 Unpack(g);
 return Ip++, Continue(); }

ai_noinline static ai_word host_posix_chmod(ai_word pw, ai_word mw) {
 char p[4096];
 if (!str_cbuf(pw, p, sizeof p) || !(mw & 1)) return putcharm(EINVAL);
 return chmod(p, (mode_t) getcharm(mw)) ? putcharm(errno) : ZeroPoint; }
static lvm(lvm_posix_chmod) {
 Sp[1] = host_posix_chmod(Sp[0], Sp[1]);
 Sp += 1; return Ip++, Continue(); }

ai_noinline static ai_word host_posix_chown(ai_word pw, ai_word uw, ai_word gw) {
 char p[4096];
 if (!str_cbuf(pw, p, sizeof p) || !(uw & 1) || !(gw & 1)) return putcharm(EINVAL);
 return chown(p, (uid_t) getcharm(uw), (gid_t) getcharm(gw)) ? putcharm(errno) : ZeroPoint; }
static lvm(lvm_posix_chown) {
 Sp[2] = host_posix_chown(Sp[0], Sp[1], Sp[2]);
 Sp += 2; return Ip++, Continue(); }

ai_noinline static ai_word host_posix_utime(ai_word pw, ai_word msw) {
 char p[4096];
 if (!str_cbuf(pw, p, sizeof p)) return putcharm(EINVAL);
 struct timespec ts[2];
 if (msw & 1) {
  intptr_t ms = getcharm(msw);
  ts[0].tv_sec = ts[1].tv_sec = (time_t) (ms / 1000);
  ts[0].tv_nsec = ts[1].tv_nsec = (long) (ms % 1000) * 1000000;
 } else
  ts[0].tv_sec = ts[1].tv_sec = 0, ts[0].tv_nsec = ts[1].tv_nsec = UTIME_NOW;
 return utimensat(AT_FDCWD, p, ts, 0) ? putcharm(errno) : ZeroPoint; }
static lvm(lvm_posix_utime) {
 Sp[1] = host_posix_utime(Sp[0], Sp[1]);
 Sp += 1; return Ip++, Continue(); }

ai_noinline static ai_word host_posix_rmdir(ai_word pw) {
 char p[4096];
 if (!str_cbuf(pw, p, sizeof p)) return putcharm(EINVAL);
 return rmdir(p) ? putcharm(errno) : ZeroPoint; }
static lvm(lvm_posix_rmdir) { Sp[0] = host_posix_rmdir(Sp[0]); return Ip++, Continue(); }

ai_noinline static ai_word host_posix_hardlink(ai_word ow, ai_word nw) {
 char o[4096], n[4096];
 if (!str_cbuf(ow, o, sizeof o) || !str_cbuf(nw, n, sizeof n)) return putcharm(EINVAL);
 return link(o, n) ? putcharm(errno) : ZeroPoint; }
static lvm(lvm_posix_hardlink) {
 Sp[1] = host_posix_hardlink(Sp[0], Sp[1]);
 Sp += 1; return Ip++, Continue(); }

static lvm(lvm_posix_umask) {
 Sp[0] = (Sp[0] & 1) ? putcharm((intptr_t) umask((mode_t) getcharm(Sp[0])))
                     : putcharm(-1);
 return Ip++, Continue(); }

static union u const
  nif_posix_rename[]   = {{lvm_cur}, {.x = putcharm(2)}, {lvm_posix_rename}, {lvm_ret0}},
  nif_posix_symlink[]  = {{lvm_cur}, {.x = putcharm(2)}, {lvm_posix_symlink}, {lvm_ret0}},
  nif_posix_readlink[] = {{lvm_posix_readlink}, {lvm_ret0}},
  nif_posix_chmod[]    = {{lvm_cur}, {.x = putcharm(2)}, {lvm_posix_chmod}, {lvm_ret0}},
  nif_posix_chown[]    = {{lvm_cur}, {.x = putcharm(3)}, {lvm_posix_chown}, {lvm_ret0}},
  nif_posix_utime[]    = {{lvm_cur}, {.x = putcharm(2)}, {lvm_posix_utime}, {lvm_ret0}},
  nif_posix_umask[]    = {{lvm_posix_umask}, {lvm_ret0}},
  nif_posix_rmdir[]    = {{lvm_posix_rmdir}, {lvm_ret0}},
  nif_posix_hardlink[] = {{lvm_cur}, {.x = putcharm(2)}, {lvm_posix_hardlink}, {lvm_ret0}};
AI_NIF("rename",   nif_posix_rename);
AI_NIF("symlink",  nif_posix_symlink);
AI_NIF("readlink", nif_posix_readlink);
AI_NIF("chmod",    nif_posix_chmod);
AI_NIF("chown",    nif_posix_chown);
AI_NIF("utime",    nif_posix_utime);
AI_NIF("umask",    nif_posix_umask);
AI_NIF("rmdir",    nif_posix_rmdir);
AI_NIF("hardlink", nif_posix_hardlink);
