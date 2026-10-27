/* the calendar in UTC: gmtime_r against gmtime, year days and week days over four centuries
 * around the epoch, the reentrant asctime_r and ctime_r, and getppid across a fork */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <sys/wait.h>
#include "say.h"

int main(void) {
  setenv("TZ", "UTC", 1);                                /* ctime is local time; moonlibc's is UTC */
  tzset();
  struct tm a, *b;
  unsigned long h = 0;
  long bad = 0;
  for (long long t = -6311520000LL; t < 6311520000LL; t += 86400 * 3 + 3607) {
    time_t q = (time_t) t;
    gmtime_r(&q, &a);
    b = gmtime(&q);
    bad += memcmp(&a, b, sizeof a) != 0;
    h = h * 1000003 + (unsigned long) (a.tm_yday + 400 * a.tm_wday + 3000 * a.tm_mday + 100000 * a.tm_mon);
    h ^= (unsigned long) (a.tm_year * 7 + a.tm_hour * 60 + a.tm_min); }
  say_n("gmtime_r.same", bad);
  say_u("calendar.hash", h);
  time_t t = 1700000000;
  char buf[26];
  say_s("ctime_r", ctime_r(&t, buf));
  gmtime_r(&t, &a);
  say_n("yday", a.tm_yday);
  say_s("asctime_r", asctime_r(&a, buf));
  t = 951782400;                                         /* 2000-02-29 */
  say_n("leap.yday", gmtime_r(&t, &a)->tm_yday);
  t = 978220800;                                         /* 2000-12-31 */
  say_n("leap.last", gmtime_r(&t, &a)->tm_yday);
  fflush(stdout);
  int fd[2];
  pipe(fd);
  pid_t me = getpid(), c = fork();
  if (c == 0) { int ok = getppid() == me; write(fd[1], &ok, sizeof ok); _exit(0); }
  int ok = -1;
  read(fd[0], &ok, sizeof ok);
  waitpid(c, 0, 0);
  say_n("getppid.child", ok);
  say_n("getppid.self", getppid() > 0);
  return 0; }
