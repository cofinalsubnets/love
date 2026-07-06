int add(int a, int b) { return a+b; }
int twice(int x) { return add(x, x); }
int main() { return add(twice(10), add(20, 2)); }
