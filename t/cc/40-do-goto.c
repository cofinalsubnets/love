int main() { int i = 0; int s = 0;
  do { s += i; i++; } while (i < 5);
  int j = 0;
again: j += s;
  if (j < 30) goto again;
  return j; }
