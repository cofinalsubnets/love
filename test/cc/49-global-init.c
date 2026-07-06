int tab[4] = {10, 20, 30, 40};
struct S { int a; int b; };
struct S g = {.b = 7, .a = 2};
int n = 5;
int main() { return tab[0] + tab[3] + g.a + g.b + n; }
