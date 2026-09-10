struct S { long a; long b; };
void copy(struct S *d, struct S *s) { *d = *s; }
int main() {
  struct S x; x.a = 40; x.b = 2;
  struct S y;
  copy(&y, &x);
  return y.a + y.b;
}
