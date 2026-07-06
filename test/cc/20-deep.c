int dec(int n) { return n - 1; }
int mul(int a, int b) { return a * b; }
int main() { int i = 6; return mul(dec(i), dec(dec(i))) + mul(2, 3) * (0 - 1) + dec(28); }
