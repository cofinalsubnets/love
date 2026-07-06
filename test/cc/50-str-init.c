int slen(char *s) { int n = 0; while (s[n]) n = n + 1; return n; }
int main() {
  char buf[8] = "hello";
  char two[] = "ab";
  return slen(buf) + slen(two) + buf[0] - 100;
}
