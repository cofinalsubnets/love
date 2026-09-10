char *greeting = "hello";
int slen(char *s) { int n = 0; while (s[n]) n = n + 1; return n; }
int main() { return slen(greeting) + greeting[0] - 100; }
