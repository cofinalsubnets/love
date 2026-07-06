struct Nif { char *name; int (*fn)(int); };
int inc(int x) { return x + 1; }
int dbl(int x) { return x * 2; }
int neg(int x) { return -x; }
struct Nif tab[3] = {{"inc", inc}, {"dbl", dbl}, {.fn = neg, .name = "neg"}};
int main() {
  int s = 0; int i = 0;
  while (i < 3) { s = s + tab[i].fn(10); i = i + 1; }
  return s + 100;
}
