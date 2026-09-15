int sq(int x) { return x * x; }
int apply(int (*f)(int), int v) { return f(v); }
int main() { return apply(sq, 7); }
