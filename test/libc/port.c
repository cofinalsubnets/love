/* the small gaps a ported tool reaches for: div and its kin truncating, the SCN family
 * through sscanf and back out through PRI, ffs, the sync and delay open bits read back off a file, TCP_NODELAY set
 * and read on a socket, termios's cflag bits and numeric speeds on a pty, alarm's seconds left
 * and its signal, gethostname against uname, gethostbyname's one answer and its _r, wcscmp/wcsstr, the passwd and group files by
 * name, id and walk with their _r forms, ptsname_r, rand_r's sequence, and tmpnam_r */
#define _GNU_SOURCE
#include <stdlib.h>
#include <inttypes.h>
#include <stdio.h>
#include <strings.h>
#include <string.h>
#include <fcntl.h>
#include <errno.h>
#include <unistd.h>
#include <signal.h>
#include <termios.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <sys/utsname.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <netdb.h>
#include <arpa/inet.h>
#include <wchar.h>
#include <pwd.h>
#include <grp.h>
#include "say.h"

#define S(m, pr, t, s) do { t v = 0; char b[32] = "none"; if (sscanf(s, "%" m, &v) == 1) snprintf(b, sizeof b, "%" pr, v); say_s(#m, b); } while (0)

static volatile sig_atomic_t rang;
static void on_alrm(int s) { rang = s; }

int main(void) {
  div_t d = div(7, -2); say_n("div.q", d.quot); say_n("div.r", d.rem);
  d = div(-7, 2); say_n("div.nq", d.quot); say_n("div.nr", d.rem);
  ldiv_t l = ldiv(-1000000007L, 10); say_n("ldiv.q", l.quot); say_n("ldiv.r", l.rem);
  lldiv_t ll = lldiv(-(1LL << 40) - 3, 1 << 20); say_n("lldiv.q", (long) ll.quot); say_n("lldiv.r", (long) ll.rem);

  S(SCNd8, PRId8, int8_t, "-12"); S(SCNx8, PRIx8, uint8_t, "fe"); S(SCNu16, PRIu16, uint16_t, "65535"); S(SCNx16, PRIx16, uint16_t, "beef");
  S(SCNd32, PRId32, int32_t, "-2147483648"); S(SCNx32, PRIx32, uint32_t, "deadbeef"); S(SCNo32, PRIo32, uint32_t, "777");
  S(SCNd64, PRId64, int64_t, "-1099511627776"); S(SCNx64, PRIx64, uint64_t, "7fffffffffff"); S(SCNu64, PRIu64, uint64_t, "123456789012");
  S(SCNxLEAST32, PRIxLEAST32, uint_least32_t, "ff"); S(SCNdFAST16, PRIdFAST16, int_fast16_t, "-3"); S(SCNxFAST32, PRIxFAST32, uint_fast32_t, "10");
  S(SCNdMAX, PRIdMAX, intmax_t, "-77"); S(SCNxPTR, PRIxPTR, uintptr_t, "1000");

  say_n("ffs.0", ffs(0)); say_n("ffs.1", ffs(1)); say_n("ffs.8", ffs(8)); say_n("ffs.min", ffs(INT32_MIN));
  say_n("ffsl", ffsl(1L << 30)); say_n("_SC_PAGE_SIZE", sysconf(_SC_PAGE_SIZE) == sysconf(_SC_PAGESIZE)); say_n("ffsll", ffsll(INT64_MIN));

  /* the open bits: their spellings, then a file asked for each, its F_GETFL masked */
  say_n("O_SYNC", O_SYNC); say_n("O_DSYNC", O_DSYNC); say_n("O_NDELAY", O_NDELAY == O_NONBLOCK);
  char p[] = "/tmp/libc-port-XXXXXX";
  int fd = mkstemp(p);
  int fs = open(p, O_WRONLY | O_SYNC), fn = open(p, O_WRONLY | O_NDELAY), fy = open(p, O_WRONLY | O_DSYNC);
  say_n("fl.sync", (fcntl(fs, F_GETFL) & O_SYNC) == O_SYNC);
  say_n("fl.ndelay", (fcntl(fn, F_GETFL) & O_NONBLOCK) != 0);
  say_n("fl.dsync", (fcntl(fy, F_GETFL) & (O_SYNC | O_DSYNC)) == O_DSYNC);
  close(fs); close(fn); close(fy); close(fd); unlink(p);

  int so = socket(AF_INET, SOCK_STREAM, 0), on = 1, got = 0;
  socklen_t gl = sizeof got;
  say_n("TCP_NODELAY", TCP_NODELAY);
  say_n("nodelay.set", setsockopt(so, IPPROTO_TCP, TCP_NODELAY, &on, sizeof on));
  say_n("nodelay.get", getsockopt(so, IPPROTO_TCP, TCP_NODELAY, &got, &gl) == 0 && got != 0);
  close(so);

  /* termios: the words in memory, then a pty's master holding what was set */
  struct termios t;
  memset(&t, 0, sizeof t);
  say_n("CS8", CS8); say_n("CSIZE", CSIZE); say_n("PARENB", PARENB); say_n("CSTOPB", CSTOPB);
  say_n("CREAD", CREAD); say_n("CLOCAL", CLOCAL); say_n("HUPCL", HUPCL); say_n("PARODD", PARODD);
  say_n("B9600", B9600); say_n("B115200", B115200); say_n("B4000000", B4000000);
  say_n("cfset.o", cfsetospeed(&t, B115200)); say_n("cfset.i", cfsetispeed(&t, B115200));
  say_n("cfget.o", cfgetospeed(&t) == B115200); say_n("cfget.i", cfgetispeed(&t) == B115200);
  say_n("cfset.odd", cfsetospeed(&t, 12345)); say_n("cfget.odd", (long) cfgetospeed(&t));
  cfsetspeed(&t, B115200);
  t.c_iflag = ICRNL | IXON | ISTRIP; t.c_oflag = OPOST | ONLCR; t.c_lflag = ECHO | ICANON | ISIG | IEXTEN;
  t.c_cflag |= PARENB | CS7;
  cfmakeraw(&t);
  say_n("raw.i", (long) t.c_iflag); say_n("raw.o", (long) t.c_oflag); say_n("raw.l", (long) t.c_lflag);
  say_n("raw.size", (long) (t.c_cflag & CSIZE)); say_n("raw.parenb", (long) (t.c_cflag & PARENB));
  say_n("raw.min", t.c_cc[VMIN]); say_n("raw.time", t.c_cc[VTIME]);
  int m = posix_openpt(O_RDWR | O_NOCTTY);
  struct termios a, b;
  say_n("pty.get", tcgetattr(m, &a));
  a.c_cflag = (a.c_cflag & ~(tcflag_t) (CSIZE | PARODD)) | CS7 | PARENB | CSTOPB;
  cfsetospeed(&a, B9600); cfsetispeed(&a, B9600);
  say_n("pty.set", tcsetattr(m, TCSANOW, &a));
  tcgetattr(m, &b);
  say_n("pty.size", (long) (b.c_cflag & CSIZE)); say_n("pty.parenb", (b.c_cflag & PARENB) != 0);
  char pn[64], pt[4], *pp = ptsname(m);
  say_n("ptsname_r", ptsname_r(m, pn, sizeof pn)); say_n("ptsname_r.same", pp && !strcmp(pn, pp));
  say_n("ptsname_r.short", ptsname_r(m, pt, sizeof pt) == ERANGE); say_n("ptsname_r.notty", ptsname_r(1 << 20, pn, sizeof pn) != 0);
  say_n("pty.cstopb", (b.c_cflag & CSTOPB) != 0); say_n("pty.speed", cfgetospeed(&b) == B9600);
  cfsetspeed(&a, 12345); tcsetattr(m, TCSANOW, &a); tcgetattr(m, &b);
  say_n("pty.odd.o", (long) cfgetospeed(&b)); say_n("pty.odd.i", (long) cfgetispeed(&b));
  close(m);

  /* alarm: none pending answers 0, a pending one its seconds rounded, then a short one rings */
  say_n("alarm.none", alarm(5)); say_n("alarm.left", alarm(0));
  signal(SIGALRM, on_alrm);
  struct itimerval it = { { 0, 0 }, { 0, 20000 } }, cur;
  say_n("itimer.set", setitimer(ITIMER_REAL, &it, 0));
  say_n("itimer.get", getitimer(ITIMER_REAL, &cur) == 0 && cur.it_value.tv_sec == 0 && cur.it_value.tv_usec <= 20000);
  while (!rang) pause();
  say_n("alarm.rang", rang == SIGALRM);

  struct utsname u;
  char h[256], sh[2];
  uname(&u);
  say_n("hostname", gethostname(h, sizeof h) == 0 && strcmp(h, u.nodename) == 0);
  errno = 0; say_n("hostname.short", gethostname(sh, sizeof sh) < 0 && errno == ENAMETOOLONG);

  struct hostent *he = gethostbyname("127.0.0.1");
  char ab[16];
  say_n("hbn.quad", he != 0);
  if (he) {
    say_s("hbn.name", he->h_name); say_n("hbn.type", he->h_addrtype); say_n("hbn.len", he->h_length);
    say_s("hbn.addr", inet_ntop(AF_INET, he->h_addr, ab, sizeof ab)); say_n("hbn.second", he->h_addr_list[1] != 0);
    say_n("hbn.aliases", he->h_aliases[0] != 0); }
  struct hostent hr, *hp = 0;
  char hb[256], tiny[8];
  int he_r = 0;
  say_n("hbn_r", gethostbyname_r("10.1.2.3", &hr, hb, sizeof hb, &hp, &he_r));
  say_s("hbn_r.addr", hp == &hr ? inet_ntop(AF_INET, hr.h_addr_list[0], ab, sizeof ab) : "none");
  say_s("hbn_r.name", hp ? hr.h_name : "none");
  say_n("hbn_r.short", gethostbyname_r("10.1.2.3", &hr, tiny, sizeof tiny, &hp, &he_r) == ERANGE && !hp);
  he = gethostbyname("localhost");
  say_s("hbn.local", he ? inet_ntop(AF_INET, he->h_addr_list[0], ab, sizeof ab) : "none");

  wchar_t const *w = L"stlink-v2 nulink";
  say_c("wcscmp.eq", wcscmp(L"abc", L"abc")); say_c("wcscmp.lt", wcscmp(L"abc", L"abd"));
  say_c("wcscmp.prefix", wcscmp(L"ab", L"abc")); say_c("wcscmp.high", wcscmp(L"\x7fffffff", L"a"));
  say_p("wcsstr", w, wcsstr(w, L"nulink")); say_p("wcsstr.none", w, wcsstr(w, L"cmsis"));
  say_p("wcsstr.empty", w, wcsstr(w, L"")); say_p("wcsstr.tail", w, wcsstr(w, L"linkx"));

  struct passwd *pw = getpwnam("root");
  say_s("pw.name", pw ? pw->pw_name : "none"); say_n("pw.uid", pw ? (long) pw->pw_uid : -1);
  say_s("pw.dir", pw ? pw->pw_dir : "none"); say_s("pw.shell", pw ? pw->pw_shell : "none");
  pw = getpwuid(1);
  say_s("pw.uid1", pw ? pw->pw_name : "none");
  say_n("pw.miss", getpwnam("no-such-user-port") == 0);
  struct passwd pr, *prp = 0;
  char pb[1024], ps[8];
  say_n("pw_r", getpwuid_r(0, &pr, pb, sizeof pb, &prp)); say_s("pw_r.name", prp ? pr.pw_name : "none");
  say_n("pw_r.miss", getpwnam_r("no-such-user-port", &pr, pb, sizeof pb, &prp)); say_n("pw_r.miss.res", prp == 0);
  say_n("pw_r.short", getpwuid_r(0, &pr, ps, sizeof ps, &prp) == ERANGE && !prp);
  setpwent(); pw = getpwent(); say_s("pwent.first", pw ? pw->pw_name : "none");
  setpwent(); pw = getpwent(); say_s("pwent.again", pw ? pw->pw_name : "none"); endpwent();
  struct group *gr = getgrgid(0);
  say_s("gr.name", gr ? gr->gr_name : "none"); say_n("gr.gid", gr ? (long) gr->gr_gid : -1);
  if (gr) for (int i = 0; gr->gr_mem[i]; i++) say_s("gr.mem", gr->gr_mem[i]);
  gr = getgrnam("root"); say_n("gr.byname", gr && gr->gr_gid == 0);
  struct group grr, *grp = 0;
  say_n("gr_r", getgrnam_r("root", &grr, pb, sizeof pb, &grp)); say_n("gr_r.gid", grp ? (long) grr.gr_gid : -1);
  say_n("gr_r.short", getgrgid_r(0, &grr, ps, sizeof ps, &grp) == ERANGE && !grp);
  setgrent(); gr = getgrent(); say_s("grent.first", gr ? gr->gr_name : "none"); endgrent();
  FILE *fe = fopen("/etc/passwd", "re");
  say_n("fopen.e", fe && (fcntl(fileno(fe), F_GETFD) & FD_CLOEXEC) != 0);
  if (fe) fclose(fe);
  unsigned int sd = 1, sh2 = 0;
  for (int i = 0; i < 1000; i++) sh2 = sh2 * 31 + (unsigned) rand_r(&sd);
  say_u("rand_r.1000", sh2); say_u("rand_r.seed", sd);
  sd = 0; say_n("rand_r.zero", rand_r(&sd)); sd = 4294967295u; say_n("rand_r.max", rand_r(&sd));
  char tn[L_tmpnam];
  say_n("tmpnam_r.null", tmpnam_r(0) == 0);
  char *tp = tmpnam_r(tn);
  say_n("tmpnam_r", tp == tn && strncmp(tn, "/tmp/", 5) == 0 && strlen(tn) < L_tmpnam && access(tn, F_OK) < 0);
  return 0; }
