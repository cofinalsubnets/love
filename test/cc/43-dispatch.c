int add1(int x) { return x + 1; }
int mul3(int x) { return x * 3; }
int neg(int x) { return -x; }
int main() {
  int (*t[3])(int);
  t[0] = add1; t[1] = mul3; t[2] = neg;
  int s = 0; int i = 0;
  while (i < 3) { s = s + t[i](10); i = i + 1; }
  return s + 100;
}
