#!/bin/sh
# test/gate/osbox.sh -- the multi-os gate: one default-lane binary answers linux and a bsd
# box with the same text and status, leg by leg; *_SEED=1 adds `love seed` on the box.
# macos meets no ELF: each leg links a mach-o twin for the box, and the two answer alike.
# the box: *_SSH, else bee's host with the cap OS-ARCH; skips without one
# usage: osbox.sh OUTDIR LOVE0 freebsd|netbsd|macos [x64|a64|rv64|arm|i386]
. test/gate/skip.sh
set -u

ho=$1
love0=$2
os=${3:-freebsd}
arch=${4:-x64}
case "$os-$arch" in
  netbsd-x64)    box=${NBSD_SSH:-};       sd=${NBSD_SEED:-} ;;
  freebsd-x64)   box=${FBSD_SSH:-};       sd=${FBSD_SEED:-} ;;
  freebsd-a64) box=${FBSD_ARM64_SSH:-}; sd=${FBSD_ARM64_SEED:-} ;;
  netbsd-a64)  box=${NBSD_ARM64_SSH:-}; sd=${NBSD_ARM64_SEED:-} ;;
  freebsd-rv64) box=${FBSD_RV64_SSH:-}; sd= ;;    # the trophy ships an x64 love; none for rv64 yet
  netbsd-rv64)  box=${NBSD_RV64_SSH:-}; sd= ;;
  freebsd-arm) box=${FBSD_ARM_SSH:-${FBSD_ARM64_SSH:-}}; sd= ;;
  netbsd-arm)  box=${NBSD_ARM_SSH:-${NBSD_ARM64_SSH:-}}; sd= ;;
  freebsd-i386) box=${FBSD_I386_SSH:-${FBSD_SSH:-}}; sd= ;;
  netbsd-i386)  box=${NBSD_I386_SSH:-${NBSD_SSH:-}}; sd= ;;
  macos-x64)    box=${MAC_SSH:-}; sd= ;;
  *) echo "osbox: no box is defined for $os on $arch" >&2; exit 1 ;;
esac
[ -n "$box" ] || box=$("$ho/love" bee --on "$os-$arch" --ssh 2>/dev/null) || box=
# an arm64 BSD runs armv7 binaries in its 32-bit lane, so an a64 box answers for arm too, and
# an amd64 one for i386
[ -n "$box" ] || [ "$arch" != arm ] || box=$("$ho/love" bee --on "$os-a64" --ssh 2>/dev/null) || box=
[ -n "$box" ] || [ "$arch" != i386 ] || box=$("$ho/love" bee --on "$os-x64" --ssh 2>/dev/null) || box=
t=test_$os; [ "$arch" = x64 ] || t=test_${os}_${arch}
d=$ho/$os-$arch

[ -n "$box" ] || gate_skip "$t: skipped (no box in the env)"

# the local half is linux: native, an a64 host, or qemu-aarch64
if [ "$arch" = a64 ]; then
  . test/gate/a64run.sh
  a64_how "$ho/love"
  [ -n "$a64_via" ] || gate_skip "$t: skipped (no qemu-aarch64 and no a64 host for the local half)"
  run() { a64_one "$ho/love" "$@"; }
elif [ "$arch" = rv64 ]; then
  command -v qemu-riscv64 > /dev/null || gate_skip "$t: skipped (no qemu-riscv64 for the local half)"
  run() { qemu-riscv64 "$@"; }
elif [ "$arch" = arm ]; then
  command -v qemu-arm >/dev/null 2>&1 || gate_skip "$t: skipped (no qemu-arm for the local half)"
  run() { qemu-arm "$@"; }
else
  run() { "$@"; }
fi

fail() { echo "FAIL $t: $*" >&2; exit 1; }

mkdir -p "$d"
cat > "$d/rung2.c" <<'EOF'
#include <unistd.h>
#include <fcntl.h>
#include <time.h>
#include <errno.h>
#include <setjmp.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dirent.h>
#include <sys/stat.h>
#include <sys/wait.h>

static int step = 0;
static void ok(int cond) {
  step++;
  if (!cond) { char b[3] = {'F', (char)('A' + step - 1), '\n'}; write(2, b, 3); _exit(step); } }

static volatile sig_atomic_t got = 0;
static void take(int sig) { got = sig; }

int main(void) {
  /* rung 2: the raw floor */
  ok(write(1, "hello, freebsd\n", 15) == 15);
  ok(getpid() > 0 && kill(getpid(), 0) == 0);
  ok(write(-1, "x", 1) == -1 && errno == EBADF);      /* er() saw the carry */
  struct timespec ts;
  ok(clock_gettime(0, &ts) == 0 && ts.tv_sec > 0);
  struct timespec tn = {0, 1000000};
  ok(nanosleep(&tn, 0) == 0);
  int fds[2]; char c = 0;
  ok(pipe(fds) == 0 && write(fds[1], "x", 1) == 1 && read(fds[0], &c, 1) == 1 && c == 'x');
  sigjmp_buf env;
  int r = sigsetjmp(env, 1);
  if (r == 0) siglongjmp(env, 7);
  ok(r == 7);

  /* rung 3: the forked tables */
  ok(open("/no/such/file", O_RDONLY) == -1 && errno == ENOENT);
  unlink("/tmp/rung3.txt");            /* O_CREAT on a leftover TRUNCATES, and that is no birth */
  int fd = open("/tmp/rung3.txt", O_CREAT | O_WRONLY | O_TRUNC, 0644);   /* O_* freebsd's now */
  ok(fd >= 0 && write(fd, "five!", 5) == 5 && close(fd) == 0);
  struct stat st;
  ok(stat("/tmp/rung3.txt", &st) == 0 && st.st_size == 5 && S_ISREG(st.st_mode));
  /* the birth door: the BSDs answer it out of this very stat, linux wants statx, and
     each spells "none" as a READABLE DATE -- freebsd VNOVAL (1969), netbsd 0 (1970,
     an FFSv1 root having no field at all). so: kept and recent, or honestly none. */
  struct timespec bt;
  int br = __love_birth("/tmp/rung3.txt", 1, &bt);
  ok(br >= 0);
  ok(br == 1 || (bt.tv_sec > 1600000000 && bt.tv_sec <= ts.tv_sec + 60));
  /* the nofollow bit is 0x200 on a BSD where linux's is 0x100, and a regular file must
     read the same either way. freebsd convicts a wrong one; netbsd's FFSv1 root answers
     "none" down both paths and cannot, so read this leg as freebsd's. */
  ok(__love_birth("/tmp/rung3.txt", 0, &bt) == br);
  ok(__love_birth("/no/such/file", 1, &bt) < 0 && errno == ENOENT);
  fd = open("/tmp/rung3.txt", O_RDONLY); char buf[8];
  ok(fd >= 0 && read(fd, buf, 8) == 5 && memcmp(buf, "five!", 5) == 0);
  int fd2 = dup2(fd, 17);
  ok(fd2 == 17 && lseek(17, 0, 0) == 0 && close(17) == 0 && close(fd) == 0);
  ok(unlink("/tmp/rung3.txt") == 0);
  ok(mkdir("/tmp/rung3.d", 0755) == 0 && rmdir("/tmp/rung3.d") == 0);   /* AT_REMOVEDIR freebsd's */
  char *m = malloc(100000);                          /* mmap MAP_ANON freebsd's */
  ok(m != 0 && (m[0] = 1) && (m[99999] = 2));
  char cwd[256];
  ok(getcwd(cwd, sizeof cwd) != 0 && cwd[0] == '/');
  DIR *dp = opendir("/etc"); int n = 0;
  struct dirent *e;
  while (dp && (e = readdir(dp))) if (e->d_name[0]) n++;
  ok(dp != 0 && closedir(dp) == 0 && n > 2);         /* getdirentries fills our dirent */
  ok(isatty(0) == 0);                                /* stdin is ssh's pipe */
  printf("printf rides: %d\n", 42);                  /* stdio over the freebsd floor */
  fflush(stdout);

  /* signals: sigaction without a restorer, the mask through the C door */
  struct sigaction sa; memset(&sa, 0, sizeof sa);
  sa.sa_handler = take;
  ok(sigaction(SIGUSR1, &sa, 0) == 0);
  ok(kill(getpid(), SIGUSR1) == 0 && got == SIGUSR1);   /* the kernel's own trampoline returned */
  got = 0;
  sigset_t bs; sigemptyset(&bs); sigaddset(&bs, SIGUSR1);
  ok(sigprocmask(SIG_BLOCK, &bs, 0) == 0);
  ok(kill(getpid(), SIGUSR1) == 0 && got == 0);         /* parked */
  ok(sigprocmask(SIG_UNBLOCK, &bs, 0) == 0 && got == SIGUSR1);   /* lands on unblock */

  /* fork is real here */
  int pid = fork();
  if (pid == 0) _exit(5);
  int stx = 0;
  ok(pid > 0 && waitpid(pid, &stx, 0) == pid && WIFEXITED(stx) && WEXITSTATUS(stx) == 5);

  write(1, "all\n", 4);
  return 42;
}
EOF

moon0() { "$love0" wake "$ho/mooncc0.image" mooncc "$@"; }
# a leg's binary for the box: the local one, or its mach-o twin linked beside it
twin() { [ "$os" != macos ] || moon0 -os macos "$d/$1.c" -o "$d/$2.mac"; }
boxbin() { if [ "$os" = macos ]; then echo "$d/$1.mac"; else echo "$d/$1"; fi; }

# uv1: entry, errno, sigsetjmp, and the EI_OSABI=9 brand freebsd's loader needs.
# run four times: a crt0 reading argv wrong flips by stack address
cat > "$d/uv1.c" <<'EOF'
#include <unistd.h>
#include <errno.h>
#include <signal.h>
#include <setjmp.h>
#include <string.h>
#include <stdio.h>

int main(int argc, char **argv) {
  (void) argv;
  sigjmp_buf b;
  int j = sigsetjmp(b, 1);
  if (!j) siglongjmp(b, 7);
  int bad = write(-1, "x", 1) == -1 && errno == EBADF;
  int k = kill(getpid(), 0) == 0;
  char m[96];
  sprintf(m, "uv1: argc=%d jmp=%d ebadf=%s kill=%s\n",
          argc, j, bad ? "ok" : "NO", k ? "ok" : "NO");
  write(1, m, strlen(m));
  return 42; }
EOF
moon0 -t "$arch" "$d/uv1.c" -o "$d/uv1" || fail "uv1: the default-lane compile"
twin uv1 uv1 || fail "uv1: the mach-o compile"
[ "$(dd if="$d/uv1" bs=1 skip=7 count=1 2>/dev/null | od -An -tu1 | tr -d ' ')" = 9 ] \
  || fail "uv1: not born branded EI_OSABI=9"
lout=$(for i in 1 2 3 4; do run "$d/uv1" one two; echo "rc=$?"; done)
fout=$($box 'cat > /tmp/uv1 && chmod +x /tmp/uv1 && for i in 1 2 3 4; do /tmp/uv1 one two; echo "rc=$?"; done' < "$(boxbin uv1)") \
  || fail "uv1: the box could not take or run it"
[ "$lout" = "$fout" ] || fail "uv1: the kernels disagree -- linux[$lout] $os[$fout]"
echo "$lout" | grep -q "uv1: argc=3 jmp=7 ebadf=ok kill=ok" || fail "uv1 body -- got: $lout"
echo "$lout" | grep -q "rc=42" || fail "uv1 exit -- got: $lout"

echo "$t: UV1 -- ONE default-lane binary answered both kernels the same"

# uv2: rung2.c -- open flags, stat, dirent, mmap, signals, fork, translated at runtime
moon0 -t "$arch" "$d/rung2.c" -o "$d/uv2" || fail "uv2: the default-lane compile"
twin rung2 uv2 || fail "uv2: the mach-o compile"
l2=$(run "$d/uv2" < /dev/null; echo "rc=$?")   # rung2.c asserts isatty(0)==0
f2=$($box 'cat > /tmp/uv2 && chmod +x /tmp/uv2 && /tmp/uv2; echo "rc=$?"' < "$(boxbin uv2)") \
  || fail "uv2: the box could not take or run it"
[ "$l2" = "$f2" ] || fail "uv2: the kernels disagree -- linux[$l2] $os[$f2]"
echo "$l2" | grep -q "rc=42" || fail "uv2 exit -- got: $l2"
echo "$l2" | grep -q "all" || fail "uv2 battery -- got: $l2"

echo "$t: UV2 -- the whole rung2 battery, one binary, both kernels"

# uv-net: sockaddr heads, sockopt names, msg flags over loopback tcp, udp, unix, SCM_RIGHTS
cat > "$d/uvnet.c" <<'EOF'
#include <unistd.h>
#include <errno.h>
#include <string.h>
#include <stdio.h>
#include <sys/socket.h>
#include <sys/wait.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <sys/un.h>

static int step = 0;
static void ok(int cond) {
  step++;
  if (!cond) { char b[3] = {'F', (char)('A' + step - 1), '\n'}; write(2, b, 3); _exit(step); } }

int main(void) {
  /* TCP over loopback: the whole shape */
  int ls = socket(AF_INET, SOCK_STREAM, 0);
  ok(ls >= 0);
  int one = 1;
  ok(setsockopt(ls, SOL_SOCKET, SO_REUSEADDR, &one, sizeof one) == 0);
  struct sockaddr_in a; memset(&a, 0, sizeof a);
  a.sin_family = AF_INET; a.sin_port = 0; a.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
  ok(bind(ls, (struct sockaddr*) &a, sizeof a) == 0 && listen(ls, 4) == 0);
  struct sockaddr_in got; socklen_t gn = sizeof got; memset(&got, 0, sizeof got);
  ok(getsockname(ls, (struct sockaddr*) &got, &gn) == 0 && got.sin_family == AF_INET && got.sin_port != 0);
  int pid = fork();
  if (pid == 0) {
    int c = socket(AF_INET, SOCK_STREAM, 0);
    struct sockaddr_in t; memset(&t, 0, sizeof t);
    t.sin_family = AF_INET; t.sin_port = got.sin_port; t.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    if (c < 0 || connect(c, (struct sockaddr*) &t, sizeof t)) _exit(99);
    char m[8];
    if (write(c, "ping", 4) != 4 || read(c, m, 8) != 4 || memcmp(m, "pong", 4)) _exit(98);
    _exit(5); }
  struct sockaddr_in peer; socklen_t pn = sizeof peer; memset(&peer, 0, sizeof peer);
  int cf = accept(ls, (struct sockaddr*) &peer, &pn);
  ok(cf >= 0 && peer.sin_family == AF_INET);
  char m[8];
  ok(read(cf, m, 8) == 4 && memcmp(m, "ping", 4) == 0 && write(cf, "pong", 4) == 4);
  int err = -1; socklen_t el = sizeof err;
  ok(getsockopt(cf, SOL_SOCKET, SO_ERROR, &err, &el) == 0 && err == 0);
  int stx = 0;
  ok(waitpid(pid, &stx, 0) == pid && WIFEXITED(stx) && WEXITSTATUS(stx) == 5);
  ok(close(cf) == 0 && close(ls) == 0);

  /* UDP: sendto/recvfrom, the peer head translated on the way out */
  int u = socket(AF_INET, SOCK_DGRAM, 0);
  memset(&a, 0, sizeof a);
  a.sin_family = AF_INET; a.sin_port = 0; a.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
  ok(u >= 0 && bind(u, (struct sockaddr*) &a, sizeof a) == 0);
  gn = sizeof got; memset(&got, 0, sizeof got);
  ok(getsockname(u, (struct sockaddr*) &got, &gn) == 0 && got.sin_port != 0);
  ok(sendto(u, "dgram", 5, 0, (struct sockaddr*) &got, sizeof got) == 5);
  pn = sizeof peer; memset(&peer, 0, sizeof peer);
  char db[8];
  ok(recvfrom(u, db, 8, 0, (struct sockaddr*) &peer, &pn) == 5
     && memcmp(db, "dgram", 5) == 0 && peer.sin_family == AF_INET && peer.sin_port == got.sin_port);
  ok(recvfrom(u, db, 8, MSG_DONTWAIT, 0, 0) == -1 && errno == EAGAIN);   /* the flag moved, the errno came back canonical */
  ok(close(u) == 0);

  /* a unix-path pair */
  unlink("/tmp/uvnet.sock");
  int us = socket(AF_UNIX, SOCK_STREAM, 0);
  struct sockaddr_un ua; memset(&ua, 0, sizeof ua);
  ua.sun_family = AF_UNIX; strcpy(ua.sun_path, "/tmp/uvnet.sock");
  ok(us >= 0 && bind(us, (struct sockaddr*) &ua, sizeof ua) == 0 && listen(us, 2) == 0);
  int uc = socket(AF_UNIX, SOCK_STREAM, 0);
  ok(uc >= 0 && connect(uc, (struct sockaddr*) &ua, sizeof ua) == 0);
  int ua2 = accept(us, 0, 0);
  ok(ua2 >= 0 && write(uc, "x", 1) == 1 && read(ua2, m, 1) == 1 && m[0] == 'x');
  int sp[2];
  ok(socketpair(AF_UNIX, SOCK_STREAM, 0, sp) == 0 && write(sp[0], "y", 1) == 1
     && read(sp[1], m, 1) == 1 && m[0] == 'y');

  /* SCM_RIGHTS through the pair: a pipe's write end crosses the socket and
     still writes -- sendmsg/recvmsg's translated msghdr + cmsg heads */
  int pp[2];
  ok(pipe(pp) == 0);
  { union { struct cmsghdr c; unsigned char b[64]; } cu; memset(&cu, 0, sizeof cu);
    struct iovec io = { (void*) "f", 1 };
    struct msghdr mh; memset(&mh, 0, sizeof mh);
    mh.msg_iov = &io; mh.msg_iovlen = 1;
    mh.msg_control = cu.b; mh.msg_controllen = CMSG_SPACE(sizeof (int));
    struct cmsghdr *c = CMSG_FIRSTHDR(&mh);
    c->cmsg_level = SOL_SOCKET; c->cmsg_type = SCM_RIGHTS; c->cmsg_len = CMSG_LEN(sizeof (int));
    memcpy(CMSG_DATA(c), &pp[1], sizeof (int));
    ok(sendmsg(uc, &mh, 0) == 1);
    char fb2[4]; struct iovec io2 = { fb2, 1 };
    struct msghdr m2; memset(&m2, 0, sizeof m2); memset(&cu, 0, sizeof cu);
    m2.msg_iov = &io2; m2.msg_iovlen = 1;
    m2.msg_control = cu.b; m2.msg_controllen = sizeof cu.b;
    ok(recvmsg(ua2, &m2, 0) == 1 && fb2[0] == 'f' && !(m2.msg_flags & MSG_CTRUNC));
    c = CMSG_FIRSTHDR(&m2);
    ok(c && c->cmsg_level == SOL_SOCKET && c->cmsg_type == SCM_RIGHTS
       && c->cmsg_len == CMSG_LEN(sizeof (int)));
    int xfd; memcpy(&xfd, CMSG_DATA(c), sizeof xfd);
    char rb[8];
    ok(write(xfd, "far", 3) == 3 && read(pp[0], rb, 8) == 3 && memcmp(rb, "far", 3) == 0);
    ok(close(xfd) == 0 && close(pp[0]) == 0 && close(pp[1]) == 0); }
  ok(close(uc) == 0 && close(ua2) == 0 && close(us) == 0 && unlink("/tmp/uvnet.sock") == 0);

  write(1, "net all\n", 8);
  return 42;
}
EOF
moon0 -t "$arch" "$d/uvnet.c" -o "$d/uvnet" || fail "uvnet: the default-lane compile"
twin uvnet uvnet || fail "uvnet: the mach-o compile"
ln=$(run "$d/uvnet" < /dev/null; echo "rc=$?")
fn=$($box 'cat > /tmp/uvnet && chmod +x /tmp/uvnet && /tmp/uvnet; echo "rc=$?"' < "$(boxbin uvnet)") \
  || fail "uvnet: the box could not take or run it"
[ "$ln" = "$fn" ] || fail "uvnet: the kernels disagree -- linux[$ln] $os[$fn]"
echo "$ln" | grep -q "net all" || fail "uvnet battery -- got: $ln"
echo "$ln" | grep -q "rc=42" || fail "uvnet exit -- got: $ln"

echo "$t: UV-net -- the socket family, one binary, both kernels"

# uv-sig: signalfd, or kqueue's EVFILT_SIGNAL on its ENOSYS, in canonical numbers,
# fired by a blocked signal, the child still waitable after
cat > "$d/uvsig.c" <<'EOF'
#include <unistd.h>
#include <errno.h>
#include <string.h>
#include <stdio.h>
#include <time.h>
#include <signal.h>
#include <sys/wait.h>
#include <sys/signalfd.h>
#include <sys/event.h>

static int step = 0;
static void ok(int cond) {
  step++;
  if (!cond) { char b[3] = {'F', (char)('A' + step - 1), '\n'}; write(2, b, 3); _exit(step); } }

static int take(int sfd, int kq) {
  if (kq >= 0) {
    struct kevent ev; struct timespec z = {0, 0};
    return kevent(kq, 0, 0, &ev, 1, &z) == 1 ? (int) ev.ident : 0; }
  struct signalfd_siginfo si;
  return read(sfd, &si, sizeof si) == (int) sizeof si ? (int) si.ssi_signo : 0; }

int main(void) {
  sigset_t m; sigemptyset(&m);
  sigaddset(&m, SIGUSR1); sigaddset(&m, SIGCHLD);
  ok(sigprocmask(SIG_BLOCK, &m, 0) == 0);
  int sfd = signalfd(-1, &m, SFD_NONBLOCK | SFD_CLOEXEC), kq = -1;
  if (sfd < 0) {                       /* a BSD kernel: the kqueue door */
    ok(errno == ENOSYS);
    kq = kqueue();
    ok(kq >= 0);
    struct kevent ch;
    EV_SET(&ch, SIGUSR1, EVFILT_SIGNAL, EV_ADD, 0, 0, 0);
    ok(kevent(kq, &ch, 1, 0, 0, 0) == 0);
    EV_SET(&ch, SIGCHLD, EVFILT_SIGNAL, EV_ADD, 0, 0, 0);
    ok(kevent(kq, &ch, 1, 0, 0, 0) == 0);
  } else {                             /* linux: the kqueue door refuses */
    ok(kqueue() == -1 && errno == ENOSYS);
    ok(sfd >= 0); ok(1); ok(1); }
  ok(kill(getpid(), SIGUSR1) == 0);    /* BLOCKED, and it still fires the source */
  ok(take(sfd, kq) == SIGUSR1);
  int pid = fork();
  if (pid == 0) _exit(3);
  int signo = 0;
  for (int i = 0; i < 200 && !(signo = take(sfd, kq)); i++) {
    struct timespec t = {0, 10000000}; nanosleep(&t, 0); }
  ok(signo == SIGCHLD);
  int st = 0;
  ok(waitpid(pid, &st, 0) == pid && WIFEXITED(st) && WEXITSTATUS(st) == 3);
  printf("uvsig: usr1=%d chld=%d canonical\n", SIGUSR1, SIGCHLD);
  fflush(stdout);
  write(1, "sig all\n", 8);
  return 42;
}
EOF
moon0 -t "$arch" "$d/uvsig.c" -o "$d/uvsig" || fail "uvsig: the default-lane compile"
twin uvsig uvsig || fail "uvsig: the mach-o compile"
ls2=$(run "$d/uvsig" < /dev/null; echo "rc=$?")
fs2=$($box 'cat > /tmp/uvsig && chmod +x /tmp/uvsig && /tmp/uvsig; echo "rc=$?"' < "$(boxbin uvsig)") \
  || fail "uvsig: the box could not take or run it"
[ "$ls2" = "$fs2" ] || fail "uvsig: the kernels disagree -- linux[$ls2] $os[$fs2]"
echo "$ls2" | grep -q "uvsig: usr1=10 chld=17 canonical" || fail "uvsig body -- got: $ls2"
echo "$ls2" | grep -q "rc=42" || fail "uvsig exit -- got: $ls2"

echo "$t: UV-sig -- the signal source, signalfd or kqueue, both kernels"

# uv-pty: posix_openpt, grantpt, unlockpt, ptsname, then the slave carries a line.
# pty names differ per kernel, so none is printed
cat > "$d/uvpty.c" <<'EOF'
#include <unistd.h>
#include <errno.h>
#include <string.h>
#include <stdlib.h>
#include <fcntl.h>
#include <termios.h>

static int step = 0;
static void ok(int cond) {
  step++;
  if (!cond) { char b[3] = {'F', (char)('A' + step - 1), '\n'}; write(2, b, 3); _exit(step); } }

int main(void) {
  int m = posix_openpt(O_RDWR | O_NOCTTY);
  ok(m >= 0);
  ok(grantpt(m) == 0 && unlockpt(m) == 0);
  char *sn = ptsname(m);
  ok(sn != 0 && sn[0] == '/');
  int s = open(sn, O_RDWR | O_NOCTTY);
  ok(s >= 0);
  ok(isatty(s) == 1);
  struct termios t;
  ok(tcgetattr(s, &t) == 0);
  char b[4] = {0};
  ok(write(m, "h\n", 2) == 2 && read(s, b, 4) == 2 && memcmp(b, "h\n", 2) == 0);
  ok(close(s) == 0 && close(m) == 0);
  write(1, "pty all\n", 8);
  return 42;
}
EOF
moon0 -t "$arch" "$d/uvpty.c" -o "$d/uvpty" || fail "uvpty: the default-lane compile"
twin uvpty uvpty || fail "uvpty: the mach-o compile"
lp=$(run "$d/uvpty" < /dev/null; echo "rc=$?")
fp=$($box 'cat > /tmp/uvpty && chmod +x /tmp/uvpty && /tmp/uvpty; echo "rc=$?"' < "$(boxbin uvpty)") \
  || fail "uvpty: the box could not take or run it"
[ "$lp" = "$fp" ] || fail "uvpty: the kernels disagree -- linux[$lp] $os[$fp]"
echo "$lp" | grep -q "pty all" || fail "uvpty battery -- got: $lp"
echo "$lp" | grep -q "rc=42" || fail "uvpty exit -- got: $lp"

echo "$t: UV-pty -- the quartet, one binary, both kernels"

# uv-siginfo: each kernel lays siginfo its own way; the same binary must read the same
# record. pids are reported as a match, since they differ between machines
cat > "$d/uvsi.c" <<'EOF'
#include <unistd.h>
#include <signal.h>
#include <string.h>
#include <stdio.h>
#include <setjmp.h>
#include <stdlib.h>
#include <sys/wait.h>

static volatile sig_atomic_t c_signo, c_code, c_status, c_pidok;
static volatile sig_atomic_t u_signo, u_code, u_pidok;
static volatile sig_atomic_t s_signo, s_code;
static volatile unsigned long s_addr;
static volatile sig_atomic_t b_signo, b_code, b_pidok;
static sigjmp_buf segv_back;
static int self;

static void on_chld(int s, siginfo_t *si, void *c) {
  (void) s; (void) c;
  c_signo = si->si_signo; c_code = si->si_code;
  c_status = si->si_status; c_pidok = si->si_pid > 0; }

static void on_usr(int s, siginfo_t *si, void *c) {
  (void) s; (void) c;
  u_signo = si->si_signo; u_code = si->si_code;
  u_pidok = si->si_pid == self; }

static void on_segv(int s, siginfo_t *si, void *c) {
  (void) s; (void) c;
  s_signo = si->si_signo; s_code = si->si_code;
  s_addr = (unsigned long) si->si_addr;
  siglongjmp(segv_back, 1); }

/* a FAULT signal that was SENT: which lane the record carries is the CODE's
   question and not the signal's, so this one holds a sender and no address */
static void on_bus(int s, siginfo_t *si, void *c) {
  (void) s; (void) c;
  b_signo = si->si_signo; b_code = si->si_code; b_pidok = si->si_pid == self; }

static void arm(int sig, void (*h)(int, siginfo_t *, void *)) {
  struct sigaction sa;
  memset(&sa, 0, sizeof sa);
  sa.sa_sigaction = h;
  sa.sa_flags = SA_SIGINFO;
  sigemptyset(&sa.sa_mask);
  if (sigaction(sig, &sa, 0)) { write(2, "arm\n", 4); _exit(9); } }

int main(void) {
  char m[256];
  self = (int) getpid();

  /* the child lane: pid, status and CLD_EXITED all come from the kernel */
  arm(SIGCHLD, on_chld);
  int kid = fork();
  if (!kid) _exit(7);
  int st = 0;
  while (waitpid(kid, &st, 0) < 0) ;

  /* the sender band: kill(2) is SI_USER, which is 0 canonically and 0x10001
     on freebsd -- the one code that must be translated rather than ridden */
  arm(SIGUSR1, on_usr);
  kill(self, SIGUSR1);

  /* the fault lane: a known unmapped address, so si_addr is a constant */
  arm(SIGSEGV, on_segv);
  if (sigsetjmp(segv_back, 1) == 0)
    *(volatile int *) 0x12340000UL = 1;

  arm(SIGBUS, on_bus);
  kill(self, SIGBUS);

  sprintf(m, "uvsi: chld signo=%d code=%d status=%d pid=%d\n"
             "uvsi: usr1 signo=%d code=%d pid=%d\n"
             "uvsi: segv signo=%d code=%d addr=0x%lx\n"
             "uvsi: sbus signo=%d code=%d pid=%d\n",
          (int) c_signo, (int) c_code, (int) c_status, (int) c_pidok,
          (int) u_signo, (int) u_code, (int) u_pidok,
          (int) s_signo, (int) s_code, s_addr,
          (int) b_signo, (int) b_code, (int) b_pidok);
  write(1, m, strlen(m));
  return 42; }
EOF
moon0 -t "$arch" "$d/uvsi.c" -o "$d/uvsi" || fail "uvsi: the default-lane compile"
twin uvsi uvsi || fail "uvsi: the mach-o compile"
lout=$(run "$d/uvsi"; echo "rc=$?")
fout=$($box 'cat > /tmp/uvsi && chmod +x /tmp/uvsi && /tmp/uvsi; echo "rc=$?"' < "$(boxbin uvsi)") \
  || fail "uvsi: the box could not take or run it"
# xnu fills a sent SIGBUS as a fault of its own (BUS_ADRERR, no sender), its libc's
# handlers reading the same: there is no sender to give back, so that line is not compared
if [ "$os" = macos ]; then
  echo "$fout" | grep -q "uvsi: sbus signo=7 code=2 pid=0" || fail "uvsi: xnu's sent bus fault -- got: $fout"
  lout=$(echo "$lout" | grep -v "uvsi: sbus"); fout=$(echo "$fout" | grep -v "uvsi: sbus")
fi
[ "$lout" = "$fout" ] || fail "uvsi: the kernels disagree -- linux[$lout] $os[$fout]"
echo "$lout" | grep -q "uvsi: chld signo=17 code=1 status=7 pid=1" \
  || fail "uvsi child lane -- got: $lout"
echo "$lout" | grep -q "uvsi: usr1 signo=10 code=0 pid=1" \
  || fail "uvsi sender band -- got: $lout"
echo "$lout" | grep -q "uvsi: segv signo=11 code=1 addr=0x12340000" \
  || fail "uvsi fault lane -- got: $lout"
[ "$os" = macos ] || echo "$lout" | grep -q "uvsi: sbus signo=7 code=0 pid=1" \
  || fail "uvsi sent-fault lane -- got: $lout"
echo "$lout" | grep -q "rc=42" || fail "uvsi exit -- got: $lout"

echo "$t: UV-siginfo -- one SA_SIGINFO record read the same on both kernels"

# the seed leg (*_SEED=1, minutes): the seed builds itself on the box to the tree's bytes
if [ -n "$sd" ]; then
  $box 'rm -rf /tmp/seedrun && mkdir /tmp/seedrun && cd /tmp/seedrun \
    && cat > love && chmod +x love' < "$ho/love" \
    || fail "trophy: the box could not take the seed"
  # love's sigfd over kqueue: the pending take, then the parked one
  cat > "$d/sigkq.l" <<'EOF'
; sigfd and sigtake are the posix module's rows, not the bare book's. a corpus
; file inherits 00-init's borrow; this one is handed straight to love and owes
; its own, or the whole leg dies on `;; missing sigfd` before it asks anything.
(borrow 'posix)
(: sp (sigfd [10 17])
   me (getpid 0)
   _  (still me 10)
   ev (sigtake sp)
   _  (assert (hot? sp) (two? ev) (= 10 (cap ev)))
   p  (spawn ["sh" "-c" "sleep 0.3; exit 0"])
   _  (await sp)
   e2 (sigtake sp)
   _  (assert (two? e2) (= 17 (cap e2)))
   (puts "sigkq ok\n"))
EOF
  sout=$($box 'cd /tmp/seedrun && cat > sigkq.l && ./love sigkq.l; echo "rc=$?"' < "$d/sigkq.l") \
    || fail "trophy: the box could not run sigkq.l"
  { echo "$sout" | grep -q "sigkq ok" && echo "$sout" | grep -q "rc=0"; } \
    || fail "trophy: love's sigfd missed on the box -- got: $sout"
  echo "$t: sigfd rode kqueue -- the pending and the parked take, on the box"
  # love cc from a bare cwd, off its carried source; HOME must stay empty
  cat > "$d/hicc.c" <<'EOF'
#include <stdio.h>
int main(void) { printf("hi from the bare door\n"); return 0; }
EOF
  bout=$($box 'rm -rf /tmp/ccbare && mkdir -p /tmp/ccbare/home && cd /tmp/ccbare && cat > hi.c \
    && env HOME=/tmp/ccbare/home /tmp/seedrun/love cc hi.c && ./a.out; echo "rc=$?"; ls -A /tmp/ccbare/home' < "$d/hicc.c") \
    || fail "trophy: the bare cc door did not answer"
  { echo "$bout" | grep -q "hi from the bare door" && echo "$bout" | grep -q "rc=0"; } \
    || fail "trophy: bare cc -- got: $bout"
  echo "$bout" | grep -q "\.love" && fail "trophy: bare cc wrote into HOME -- got: $bout"
  echo "$t: love cc -- the bare binary compiled from its carried source, on the box"
  out=$($box 'cd /tmp/seedrun \
    && env LOVE_BUDGET_MB=512 ./love seed > seed.log 2>&1; tail -3 seed.log') \
    || fail "trophy: the box could not run the seed"
  echo "$out" | grep -q "fixpoint ok" || fail "trophy: the on-box seed missed the fixpoint -- got: $out"
  echo "$t: THE TROPHY -- the seed built the seed on $os, to the byte"
fi
