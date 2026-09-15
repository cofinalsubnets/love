/* object + function macros, rescan, nested calls */
#define N 10
#define INC(x) ((x) + 1)
#define SQ(x) ((x) * (x))
#define DOUBLE(x) ((x) + (x))
int main() {
  int a = N;              /* 10 */
  int b = INC(a);         /* 11 */
  int c = SQ(INC(2));     /* 9 */
  int d = DOUBLE(SQ(2));  /* 8 */
  return a + b + c + d;   /* 10+11+9+8 = 38 */
}
