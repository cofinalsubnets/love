/* civil-from-days over a span of timestamps: the divisions by constants lay as wide
 * multiplies, whose high half comes back through rdx, with a ternary's value across a join */
struct tm9 { int year, mon, mday, hour, wday, yday; };

static void civil(long t, struct tm9 *o) {
  long days = t / 86400, secs = t % 86400;
  if (secs < 0) { secs += 86400; days -= 1; }
  o->hour = (int) (secs / 3600);
  o->wday = (int) (((days % 7) + 4 + 7) % 7);
  long z = days + 719468;
  long era = (z >= 0 ? z : z - 146096) / 146097;
  long doe = z - era * 146097;
  long yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
  long y = yoe + era * 400;
  long doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
  long mp = (5 * doy + 2) / 153;
  long d = doy - (153 * mp + 2) / 5 + 1;
  long m = mp < 10 ? mp + 3 : mp - 9;
  y += (m <= 2);
  o->year = (int) (y - 1900);
  o->mon = (int) (m - 1);
  o->mday = (int) d;
  int leap = y % 4 == 0 && (y % 100 != 0 || y % 400 == 0);
  o->yday = (int) (m <= 2 ? doy - 306 : doy + 59 + leap); }

int main(void) {
  unsigned h = 0;
  for (long t = -2000000000L; t < 2000000000L; t += 37777777L) {
    struct tm9 o;
    civil(t, &o);
    h = h * 31 + (unsigned) (o.year * 400 + o.mon * 32 + o.mday + o.hour + o.wday + o.yday); }
  return (int) (h % 251); }
