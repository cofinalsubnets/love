int main() {
  int a[5] = {2, 4, 6, 8, 10};
  int s = 0; int i = 0;
  while (i < 5) { s = s + a[i]; i = i + 1; }
  int b[4] = {1};
  return s + b[0] + b[3];
}
