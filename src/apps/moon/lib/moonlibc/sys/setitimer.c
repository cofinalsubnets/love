#include "../impl.h"
#include <sys/time.h>

/* netbsd's and macos's timeval keeps its usec in an int, the word's top half noise */
static void itcut(struct itimerval *v) {
  if (v && __love_osv >= 3)
    v->it_interval.tv_usec = (int) v->it_interval.tv_usec, v->it_value.tv_usec = (int) v->it_value.tv_usec; }
int setitimer(int w, struct itimerval const *v, struct itimerval *old) {
  long r = er(sc3(NR_setitimer, w, (long) v, (long) old));
  if (!r) itcut(old);
  return (int) r; }
int getitimer(int w, struct itimerval *v) {
  long r = er(sc2(NR_getitimer, w, (long) v));
  if (!r) itcut(v);
  return (int) r; }
