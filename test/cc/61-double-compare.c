/* the six double comparisons, ordered results, in conditions */
int main() {
  double a = 2.0;
  double b = 3.5;
  int r = 0;
  if (a < b) r = r + 1;
  if (a <= b) r = r + 2;
  if (b > a) r = r + 4;
  if (b >= a) r = r + 8;
  if (a == 2.0) r = r + 16;
  if (a != b) r = r + 32;
  return r;    /* all true -> 63 */
}
