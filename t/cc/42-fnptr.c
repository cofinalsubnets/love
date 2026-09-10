int inc(int x) { return x + 1; }
int dbl(int x) { return x * 2; }
int main() { int (*fp)(int); fp = inc; int a = fp(20); fp = dbl; return a + (*fp)(10); }
