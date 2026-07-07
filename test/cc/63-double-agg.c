/* doubles in arrays and structs, pointer walk, global double table */
struct V { double x; double y; };
double table[3] = {1.5, 2.5, 4.0};
int main() {
  struct V v = {3.0, 0.25};
  double a[2];
  a[0] = v.x + v.y;         /* 3.25 */
  a[1] = table[0] + table[2];  /* 5.5 */
  double *p = a;
  return (int)(*p + *(p + 1));  /* 3.25 + 5.5 = 8.75 -> 8 */
}
