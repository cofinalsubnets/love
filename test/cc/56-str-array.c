char *words[] = {"a", "bb", "ccc", "dddd"};
int slen(char *s) { int n = 0; while (s[n]) n = n + 1; return n; }
int main() {
  int s = 0; int i = 0;
  while (i < 4) { s = s + slen(words[i]); i = i + 1; }
  return s;
}
