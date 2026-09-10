int swap(int *a, int *b) { int t = *a; *a = *b; *b = t; return 0; }
int main() { int x = 3; int y = 39; swap(&x, &y); return x + y*0 + (y == 3)*3; }
