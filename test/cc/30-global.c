int g = 7;
long big;
int bump() { g = g + 1; big = big + 2; return g; }
int main() { bump(); bump(); return g*10 + big; }
