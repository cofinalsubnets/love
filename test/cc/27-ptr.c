int main() { int x = 5; int *p = &x; *p = 7; int **pp = &p; **pp = 9; return x*10 + *p - 9; }
